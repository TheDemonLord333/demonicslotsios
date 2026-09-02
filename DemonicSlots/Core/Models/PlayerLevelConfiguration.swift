//
//  PlayerLevelConfiguration.swift
//  DemonicSlots
//
//  Single source of truth for every level-driven number in the app: the
//  per-level win-chance bonus and the shared stake ladder every game's own
//  bet-tier progression is a slice of. `PlayerProgressionService` is the
//  only code that reads this table - no view or game engine ever branches
//  on `player.level` directly (see that service's header comment for why).
//
//  Balancing note: this is a starting configuration ("erste Balancing-
//  Vorgabe"), not a measured result - same caveat as Infernal Forge's reel
//  weights and Risk Ladder's level odds. Retune by editing the values below;
//  nothing else needs to change.
//
import Foundation

nonisolated enum PlayerLevelConfiguration {
    static let minimumLevel = 1
    static let maximumLevel = 100

    /// XP cost of the step from level N to level N+1 is `xpStep * N` (see
    /// `PlayerProgressionService.cumulativeXPRequired(forLevel:)` for the
    /// closed-form total) - a plain triangular ramp, cheap early on and
    /// steadily more expensive later, with no further tuning per level
    /// needed. 1 XP is earned per Soul Coin wagered (see
    /// `WalletService.awardXP`), so at this starting configuration: level 2
    /// costs 500 total wagered, level 10 (the win-bonus table's cap above)
    /// costs 22,500, level 30 (the top bet tier below) costs 217,500, and
    /// the absolute level 100 cap costs 2,475,000 - a long-term ceiling by
    /// design. Starting configuration, not a measured result - retune this
    /// one number to make the whole curve faster/slower.
    static let xpStep: Int64 = 500

    /// Win-chance bonus per level, dense from level 1 through the last
    /// explicitly tuned level. A level above the table's highest entry
    /// keeps that entry's multiplier (`PlayerProgressionService.
    /// levelWinMultiplier(forLevel:)` finds the highest entry at or below
    /// the player's level) - i.e. in this starting configuration, the win
    /// bonus stops growing past level 10, while the bet-tier max bet below
    /// keeps climbing all the way to level 30. Extend this array to add
    /// further per-level tuning later; nothing else needs to change.
    static let levels: [PlayerLevelDefinition] = [
        PlayerLevelDefinition(level: 1, winMultiplier: 1.00),
        PlayerLevelDefinition(level: 2, winMultiplier: 1.01),
        PlayerLevelDefinition(level: 3, winMultiplier: 1.02),
        PlayerLevelDefinition(level: 4, winMultiplier: 1.03),
        PlayerLevelDefinition(level: 5, winMultiplier: 1.04),
        PlayerLevelDefinition(level: 6, winMultiplier: 1.045),
        PlayerLevelDefinition(level: 7, winMultiplier: 1.05),
        PlayerLevelDefinition(level: 8, winMultiplier: 1.055),
        PlayerLevelDefinition(level: 9, winMultiplier: 1.06),
        PlayerLevelDefinition(level: 10, winMultiplier: 1.07),
    ]

    /// Every `levelsPerBetTierStep` levels, a game's max bet advances one
    /// step up the shared stake ladder (see `PlayerProgressionService.
    /// stakeSequenceValue(atIndex:)`) - flat in between, same "milestone,
    /// not a ramp" shape the old single global bet-tier table had. Level 1
    /// itself is a game's own starting point in that ladder (its
    /// `betTierStartIndex`, see `SlotGameDefinition`), never level 0 - so
    /// every player, even freshly registered, already has *a* max bet, and
    /// the first actual step up lands at level `levelsPerBetTierStep`
    /// itself (10 in this starting configuration), not one level later.
    static let levelsPerBetTierStep = 10
}
