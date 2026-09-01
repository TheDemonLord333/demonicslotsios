//
//  PlayerProgressionService.swift
//  DemonicSlots
//
//  The single place every game/view asks "what does this player's level
//  and win-chance multiplier actually mean right now" - never
//  `if player.level >= 10 { ... }` scattered across views or games. Reads
//  `PlayerLevelConfiguration` (level win-bonus table + bet tiers) and
//  combines it with the player's own backend-set `winChanceMultiplier`.
//  Pure and stateless: every method is a plain function of its arguments,
//  so it needs no `@MainActor`/`@Observable` and is trivially testable.
//
//  Server as source of truth: `level`/`winChanceMultiplier` themselves live
//  on `PlayerProfile`, written only by `AccountSyncController` from a
//  register/sync response (see that file) - this service never reads
//  `PlayerProfile` or the backend directly, it only computes from whatever
//  raw values it's handed, validating them itself as a second, independent
//  line of defense on top of the backend's own validation (routes/admin.js).
//
import Foundation

nonisolated enum PlayerProgressionService {
    static let minimumLevel = PlayerLevelConfiguration.minimumLevel
    static let maximumLevel = PlayerLevelConfiguration.maximumLevel
    static let minimumWinChanceMultiplier = 0.10
    static let maximumWinChanceMultiplier = 2.00
    /// No mechanic's effective win chance may exceed this, no matter how
    /// large a (validated) multiplier is in play - a single central number
    /// so "high multipliers can never produce a practically guaranteed win"
    /// is enforced in one place. An individual mechanic may still pass a
    /// *lower* cap of its own via `GameProbabilityContext.adjustedProbability(cap:)`.
    static let maximumEffectiveWinChance = 0.95

    // MARK: - Validation

    /// Clamps a raw (possibly backend-sourced) level into `1...100`,
    /// falling back to `1` for anything below that range (including `0` or
    /// negative). The backend already rejects an out-of-range level before
    /// it's ever stored (see `backend/src/routes/admin.js`) - this is a
    /// second, independent line of defense on the client, so a corrupted
    /// local cache or an unexpected sync response can never crash a game or
    /// hand out a nonsensical bonus.
    static func validatedLevel(_ rawLevel: Int) -> Int {
        guard rawLevel >= minimumLevel else { return minimumLevel }
        return min(rawLevel, maximumLevel)
    }

    /// Clamps a raw (possibly backend-sourced) win-chance multiplier into
    /// `0.10...2.00`, falling back to `1.0` (neutral, no bonus or penalty)
    /// for anything that isn't even a finite number - a `NaN`/`Infinity`
    /// value can never reach the probability math below.
    static func validatedWinChanceMultiplier(_ rawMultiplier: Double) -> Double {
        guard rawMultiplier.isFinite else { return 1.0 }
        return min(max(rawMultiplier, minimumWinChanceMultiplier), maximumWinChanceMultiplier)
    }

    // MARK: - Win multiplier

    /// The level-based win-chance bonus for `level` - the highest
    /// configured level at or below it (so a level above the table's
    /// highest entry keeps that entry's value; see
    /// `PlayerLevelConfiguration.levels`'s header comment). Falls back to
    /// `1.0` if the table were ever emptied by mistake.
    static func levelWinMultiplier(forLevel level: Int) -> Double {
        let safeLevel = validatedLevel(level)
        let applicable = PlayerLevelConfiguration.levels
            .filter { $0.level <= safeLevel }
            .max { $0.level < $1.level }
        return applicable?.winMultiplier ?? 1.0
    }

    /// `levelWinMultiplier * playerWinChanceMultiplier`, both validated
    /// first - the one number a game engine actually multiplies its own
    /// base probability/RNG weighting by. Example: level 20 (1.08) and an
    /// admin-set multiplier of 1.10 combine to `1.188`, matching the task's
    /// own worked example.
    static func finalWinMultiplier(level: Int, playerMultiplier: Double) -> Double {
        levelWinMultiplier(forLevel: level) * validatedWinChanceMultiplier(playerMultiplier)
    }

    /// Builds the `GameProbabilityContext` a game engine actually consumes,
    /// from raw level/multiplier values - the one call
    /// `SpinSessionController`/`RiskLadderSessionController` make once per
    /// spin/round instead of every mechanic loading these values itself
    /// (see that type's header comment on why that centralization matters).
    static func probabilityContext(level: Int, playerMultiplier: Double) -> GameProbabilityContext {
        GameProbabilityContext(finalWinMultiplier: finalWinMultiplier(level: level, playerMultiplier: playerMultiplier))
    }

    /// The literal `effectiveProbability = baseProbability * multiplier`
    /// formula, clamped to `0...cap`. Equivalent to calling
    /// `GameProbabilityContext(finalWinMultiplier: multiplier)
    /// .adjustedProbability(base:cap:)` - kept as a standalone function too
    /// since it reads more directly at a call site that already has a
    /// multiplier in hand rather than a context value.
    static func effectiveProbability(base: Double, multiplier: Double, cap: Double = maximumEffectiveWinChance) -> Double {
        GameProbabilityContext(finalWinMultiplier: multiplier).adjustedProbability(base: base, cap: cap)
    }

    /// A multiplier expressed as a signed percent bonus/penalty, e.g. `1.07`
    /// -> `7.0`, `0.9` -> `-10.0`. For display only ("Level Bonus: +7 %") -
    /// never derived by adding percentages when multipliers combine, since
    /// `1.07 * 1.10` is not the same number as `7% + 10%`.
    static func percentBonus(fromMultiplier multiplier: Double) -> Double {
        (multiplier - 1) * 100
    }

    // MARK: - XP / leveling

    /// Cumulative total XP required to have reached `level` (`level 1`
    /// needs `0` - everyone starts there). Triangular growth: the step
    /// from N to N+1 costs `xpStep * N`, so the sum for 1...level-1 is
    /// `xpStep * level * (level - 1) / 2`. See `PlayerLevelConfiguration.
    /// xpStep`'s comment for what this looks like at a few levels.
    static func cumulativeXPRequired(forLevel level: Int) -> Int64 {
        let safeLevel = Int64(validatedLevel(level))
        let step = PlayerLevelConfiguration.xpStep
        return step * safeLevel * (safeLevel - 1) / 2
    }

    /// The highest level `totalXP` alone would justify, clamped to
    /// `1...maximumLevel` - purely "what has this player earned by
    /// playing", independent of whatever `level` is actually stored right
    /// now (which might be higher, from an admin boost). `AccountSyncController`
    /// is the only caller that compares this against the stored level to
    /// decide whether to ask the backend for a level-up.
    static func level(forTotalXP totalXP: Int64) -> Int {
        let safeXP = max(totalXP, 0)
        var candidate = minimumLevel
        while candidate < maximumLevel, cumulativeXPRequired(forLevel: candidate + 1) <= safeXP {
            candidate += 1
        }
        return candidate
    }

    /// Progress toward the level *above* `currentLevel`, for a progress
    /// bar: how much XP has been earned since reaching `currentLevel`
    /// (`xpIntoLevel`), how much the next level costs from there
    /// (`xpForNextLevel`), and the resulting `0...1` fraction. `nil` at
    /// `maximumLevel` (nothing left to progress toward).
    ///
    /// Deliberately keyed off the *stored* `currentLevel` - which might sit
    /// above what `totalXP` alone would earn, after an admin boost - not
    /// `level(forTotalXP:)`. That keeps the bar meaning "progress toward
    /// the next level above what this player's level actually is right
    /// now", never a confusing "already 400% past this bar" reading right
    /// after a boost: `xpIntoLevel` clamps to `0` until real play XP
    /// actually catches back up to the boosted level's own threshold.
    static func xpProgress(totalXP: Int64, currentLevel: Int) -> (xpIntoLevel: Int64, xpForNextLevel: Int64, fraction: Double)? {
        let safeLevel = validatedLevel(currentLevel)
        guard safeLevel < maximumLevel else { return nil }
        let safeXP = max(totalXP, 0)
        let floor = cumulativeXPRequired(forLevel: safeLevel)
        let ceiling = cumulativeXPRequired(forLevel: safeLevel + 1)
        let span = max(ceiling - floor, 1)
        let into = min(max(safeXP - floor, 0), span)
        return (xpIntoLevel: into, xpForNextLevel: span, fraction: Double(into) / Double(span))
    }

    // MARK: - Bet limits

    /// The global max bet unlocked at `level` - the highest bet tier whose
    /// `minimumLevel` the player has reached. Falls back to the lowest
    /// configured tier's limit if `PlayerLevelConfiguration.betTiers` were
    /// ever emptied by mistake, rather than allowing an unlimited bet.
    static func maxBet(forLevel level: Int) -> Int64 {
        let safeLevel = validatedLevel(level)
        let applicable = PlayerLevelConfiguration.betTiers
            .filter { $0.minimumLevel <= safeLevel }
            .max { $0.minimumLevel < $1.minimumLevel }
        if let applicable { return applicable.maxBet }
        return PlayerLevelConfiguration.betTiers.map(\.maxBet).min() ?? 0
    }

    /// A game's own maximum bet can only ever further restrict the
    /// player's global limit, never widen it:
    /// `effectiveMaxBet = min(playerLevelMaxBet, gameMaximumBet)`.
    static func effectiveMaxBet(level: Int, gameMaximumBet: Int64) -> Int64 {
        min(maxBet(forLevel: level), max(gameMaximumBet, 0))
    }

    /// Every bet a game supports (`gameBets`) that the player's current
    /// level actually unlocks, preserving `gameBets`' original order. Never
    /// mutates `gameBets` itself - a game's own bet list (e.g.
    /// `SlotGameDefinition.betLevels`, `RiskLadderConfiguration.stakeLevels`)
    /// stays the single source of truth for "what this game supports at
    /// all"; this only filters it down to what's currently unlocked.
    static func availableBets(gameBets: [Int64], level: Int) -> [Int64] {
        let limit = maxBet(forLevel: level)
        return gameBets.filter { $0 <= limit }
    }

    /// The lowest level that would unlock `bet`, for showing a locked bet's
    /// "🔒 Level X" caption - `nil` if no configured tier ever unlocks it
    /// (the value exceeds even the highest tier's limit).
    static func unlockLevel(forBet bet: Int64) -> Int? {
        PlayerLevelConfiguration.betTiers
            .filter { $0.maxBet >= bet }
            .min { $0.minimumLevel < $1.minimumLevel }?
            .minimumLevel
    }
}
