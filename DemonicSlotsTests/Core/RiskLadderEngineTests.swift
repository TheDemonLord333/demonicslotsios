//
//  RiskLadderEngineTests.swift
//  DemonicSlotsTests
//
//  Pure game-logic tests for Demonic Risk Ladder: multiplier/payout math
//  and climb-attempt resolution, fully deterministic via
//  `ScriptedRandomSource`/`SeededRandomSource` - no view, no persistence.
//
import Testing
@testable import DemonicSlots

struct RiskLadderEngineTests {
    private let levels = RiskLadderConfiguration.levels

    @Test func payoutIsStakeTimesMultiplierRoundedToWholeCoins() {
        // Level 1 multiplier is x1.5.
        #expect(RiskLadderEngine.payout(stake: 100, level: 1, configuration: levels) == 150)
        // 33 * 1.5 = 49.5, rounds to 50.
        #expect(RiskLadderEngine.payout(stake: 33, level: 1, configuration: levels) == 50)
    }

    @Test func payoutAtLevelZeroOrBeyondMaxIsZero() {
        #expect(RiskLadderEngine.payout(stake: 100, level: 0, configuration: levels) == 0)
        #expect(RiskLadderEngine.payout(stake: 100, level: levels.count + 1, configuration: levels) == 0)
    }

    @Test func topLevelIsTheJackpot() {
        #expect(RiskLadderEngine.isJackpotLevel(levels.count, configuration: levels))
        #expect(!RiskLadderEngine.isJackpotLevel(1, configuration: levels))
    }

    @Test func multiplierPercentIsFixedPointTimesOneHundred() {
        // Level 1 is x1.5 -> 150.
        #expect(RiskLadderEngine.multiplierPercent(level: 1, configuration: levels) == 150)
    }

    @Test func aRollBelowThresholdSucceeds() {
        var random: any RandomNumberSource = ScriptedRandomSource(values: [0])
        #expect(RiskLadderEngine.attemptClimb(fromLevel: 0, configuration: levels, randomSource: &random))
    }

    @Test func aRollAtOrAboveThresholdFails() {
        // successProbability for level 1 (index 0) is 0.85 -> threshold 850_000.
        var random: any RandomNumberSource = ScriptedRandomSource(values: [999_999])
        #expect(!RiskLadderEngine.attemptClimb(fromLevel: 0, configuration: levels, randomSource: &random))
    }

    @Test func climbingFromAnOutOfRangeLevelNeverSucceeds() {
        var random: any RandomNumberSource = ScriptedRandomSource(values: [0])
        #expect(!RiskLadderEngine.attemptClimb(fromLevel: levels.count, configuration: levels, randomSource: &random))
    }

    @Test func repeatedSimulationLandsWithinAWideBandOfTheConfiguredProbability() {
        var random: any RandomNumberSource = SeededRandomSource(seed: 42)
        let trials = 20_000
        var successes = 0
        for _ in 0..<trials {
            if RiskLadderEngine.attemptClimb(fromLevel: 0, configuration: levels, randomSource: &random) {
                successes += 1
            }
        }
        let observedRate = Double(successes) / Double(trials)
        // Configured probability is 0.85; a wide tolerance keeps this test
        // from flaking while still catching a badly broken roll.
        #expect(abs(observedRate - 0.85) < 0.03)
    }
}
