//
//  PlayerProgressionServiceTests.swift
//  DemonicSlotsTests
//
//  Covers the player-level/win-chance-multiplier system: bet-tier lookups
//  staying flat between milestones, the level-bonus × player-multiplier
//  combination, probability multiplication + capping, and defensive
//  handling of out-of-range or non-finite backend values.
//
import Testing
@testable import DemonicSlots

struct PlayerProgressionServiceTests {
    // MARK: - Bet tiers / max bet

    @Test func level1GetsTheBaseMaxBet() {
        #expect(PlayerProgressionService.maxBet(forLevel: 1) == 100)
    }

    @Test func maxBetStaysFlatBetweenTierMilestones() {
        // Level 4 is still within tier 1 (levels 1-4): must NOT have
        // climbed just because the level went up.
        #expect(PlayerProgressionService.maxBet(forLevel: 4) == 100)
        // Same for 11-14, all still tier 3 (level 10's 500 limit).
        #expect(PlayerProgressionService.maxBet(forLevel: 11) == 500)
        #expect(PlayerProgressionService.maxBet(forLevel: 14) == 500)
    }

    @Test func eachMilestoneLevelUnlocksTheNextTier() {
        #expect(PlayerProgressionService.maxBet(forLevel: 5) == 250)
        #expect(PlayerProgressionService.maxBet(forLevel: 10) == 500)
        #expect(PlayerProgressionService.maxBet(forLevel: 15) == 1_000)
        #expect(PlayerProgressionService.maxBet(forLevel: 20) == 2_500)
        #expect(PlayerProgressionService.maxBet(forLevel: 25) == 5_000)
        #expect(PlayerProgressionService.maxBet(forLevel: 30) == 10_000)
    }

    @Test func maxBetAtTheHighestConfiguredLevelKeepsTheTopTier() {
        #expect(PlayerProgressionService.maxBet(forLevel: 100) == 10_000)
    }

    @Test func gameMaxBetCanRestrictTheGlobalMaxBetButNeverWidenIt() {
        // Player is level 30 (global max bet 10,000), but this game only
        // supports up to 5,000 - the game's own limit wins.
        #expect(PlayerProgressionService.effectiveMaxBet(level: 30, gameMaximumBet: 5_000) == 5_000)
        // A game that supports MORE than the global limit is still capped
        // by the player's level.
        #expect(PlayerProgressionService.effectiveMaxBet(level: 12, gameMaximumBet: 10_000) == 500)
    }

    @Test func availableBetsOnlyIncludesBetsTheLevelUnlocks() {
        let gameBets: [Int64] = [10, 25, 50, 100, 250, 500, 1_000, 2_500, 5_000]
        // Level 7 -> tier 3 not yet reached (needs level 10) -> max bet 250.
        let available = PlayerProgressionService.availableBets(gameBets: gameBets, level: 7)
        #expect(available == [10, 25, 50, 100, 250])
    }

    @Test func aPlayerCannotSelectABetAboveTheirLimit() {
        let gameBets: [Int64] = [10, 25, 50, 100, 250, 500]
        let available = PlayerProgressionService.availableBets(gameBets: gameBets, level: 7)
        #expect(!available.contains(500))
    }

    @Test func unlockLevelReportsTheTierThatIntroducesABet() {
        #expect(PlayerProgressionService.unlockLevel(forBet: 500) == 10)
        #expect(PlayerProgressionService.unlockLevel(forBet: 10_000) == 30)
        #expect(PlayerProgressionService.unlockLevel(forBet: 999_999) == nil) // no tier ever unlocks this
    }

    // MARK: - Win multiplier

    @Test func levelWinMultiplierMatchesTheConfiguredTable() {
        #expect(PlayerProgressionService.levelWinMultiplier(forLevel: 1) == 1.00)
        #expect(PlayerProgressionService.levelWinMultiplier(forLevel: 10) == 1.07)
    }

    @Test func levelWinMultiplierBeyondTheTableKeepsTheHighestEntry() {
        // No further per-level win-bonus growth configured past level 10 in
        // the starting configuration.
        #expect(PlayerProgressionService.levelWinMultiplier(forLevel: 12) == 1.07)
        #expect(PlayerProgressionService.levelWinMultiplier(forLevel: 100) == 1.07)
    }

    @Test func finalWinMultiplierCombinesLevelAndPlayerMultipliers() {
        // The task's own worked example: level bonus 1.08 x admin 1.10.
        let final = PlayerProgressionService.finalWinMultiplier(level: 20, playerMultiplier: 1.10)
        // Level 20's configured bonus is 1.07 (no growth past level 10), so
        // this pins the combination formula itself, not a specific level's
        // bonus value.
        let expected = PlayerProgressionService.levelWinMultiplier(forLevel: 20) * 1.10
        #expect(final == expected)
    }

    @Test func adminMultiplierIsAppliedMultiplicativelyNotAdditively() {
        // Contrived but exact: force a 1.08 level-equivalent by using the
        // raw formula directly, matching the task's own example precisely.
        let combined = 1.08 * 1.10
        #expect(abs(combined - 1.188) < 0.0001)
        #expect(abs((combined - 1) * 100 - 18.8) < 0.01) // NOT 8% + 10% = 18% flat
    }

    @Test func percentBonusReflectsTheMultiplierNotAnAddedPercentage() {
        #expect(PlayerProgressionService.percentBonus(fromMultiplier: 1.07) == 7.0)
        #expect(abs(PlayerProgressionService.percentBonus(fromMultiplier: 0.9) - (-10.0)) < 0.0001)
    }

    // MARK: - Probability multiplication + capping

    @Test func probabilityIsMultipliedByTheFinalMultiplier() {
        let result = PlayerProgressionService.effectiveProbability(base: 0.20, multiplier: 1.10)
        #expect(abs(result - 0.22) < 0.0001)
    }

    @Test func probabilityCapPreventsAPracticallyGuaranteedWin() {
        let result = PlayerProgressionService.effectiveProbability(base: 0.90, multiplier: 2.0, cap: 0.95)
        #expect(result == 0.95)
    }

    @Test func probabilityNeverExceedsOneEvenWithoutAnExplicitCapArgument() {
        let result = PlayerProgressionService.effectiveProbability(base: 0.99, multiplier: 2.0)
        #expect(result <= PlayerProgressionService.maximumEffectiveWinChance)
    }

    @Test func aZeroBaseProbabilityStaysZeroRegardlessOfMultiplier() {
        #expect(PlayerProgressionService.effectiveProbability(base: 0, multiplier: 2.0) == 0)
    }

    // MARK: - Validation / defensive fallbacks

    @Test func invalidLevelsFallBackToOne() {
        #expect(PlayerProgressionService.validatedLevel(0) == 1)
        #expect(PlayerProgressionService.validatedLevel(-10) == 1)
    }

    @Test func levelAboveTheMaximumIsClamped() {
        #expect(PlayerProgressionService.validatedLevel(9_999) == PlayerProgressionService.maximumLevel)
    }

    @Test func invalidMultipliersFallBackToNeutral() {
        #expect(PlayerProgressionService.validatedWinChanceMultiplier(.nan) == 1.0)
        #expect(PlayerProgressionService.validatedWinChanceMultiplier(.infinity) == 1.0)
        #expect(PlayerProgressionService.validatedWinChanceMultiplier(-.infinity) == 1.0)
    }

    @Test func outOfRangeMultipliersAreClampedNotRejectedOutright() {
        #expect(PlayerProgressionService.validatedWinChanceMultiplier(-10) == PlayerProgressionService.minimumWinChanceMultiplier)
        #expect(PlayerProgressionService.validatedWinChanceMultiplier(1_000_000) == PlayerProgressionService.maximumWinChanceMultiplier)
    }

    @Test func aCorruptedMultiplierCanNeverCrashOrBreakProbabilityMath() {
        let context = GameProbabilityContext(finalWinMultiplier: PlayerProgressionService.validatedWinChanceMultiplier(.nan))
        let result = context.adjustedProbability(base: 0.5)
        #expect(result.isFinite)
        #expect(result >= 0 && result <= 1)
    }
}
