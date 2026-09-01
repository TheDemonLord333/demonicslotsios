//
//  PlayerLevelConfiguration.swift
//  DemonicSlots
//
//  Single source of truth for every level-driven number in the app: the
//  per-level win-chance bonus and the bet-tier milestones that unlock a
//  higher global max bet. `PlayerProgressionService` is the only code that
//  reads this table - no view or game engine ever branches on `player.level`
//  directly (see that service's header comment for why).
//
//  Balancing note: this is a starting configuration ("erste Balancing-
//  Vorgabe"), not a measured result - same caveat as Infernal Forge's reel
//  weights and Risk Ladder's level odds. Retune by editing the arrays below;
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

    /// Bet-tier milestones. The global max bet only changes at one of these
    /// levels and stays flat in between (e.g. levels 11-14 keep level 10's
    /// 500-coin limit) - deliberately a separate table from `levels` above,
    /// per the task that introduced this, so new tiers can be added without
    /// touching the win-bonus table or any game engine.
    static let betTiers: [BetTier] = [
        BetTier(minimumLevel: 1, maxBet: 100),
        BetTier(minimumLevel: 5, maxBet: 250),
        BetTier(minimumLevel: 10, maxBet: 500),
        BetTier(minimumLevel: 15, maxBet: 1_000),
        BetTier(minimumLevel: 20, maxBet: 2_500),
        BetTier(minimumLevel: 25, maxBet: 5_000),
        BetTier(minimumLevel: 30, maxBet: 10_000),
    ]
}
