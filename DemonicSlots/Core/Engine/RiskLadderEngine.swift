//
//  RiskLadderEngine.swift
//  DemonicSlots
//
//  Pure, UI-free game logic for Demonic Risk Ladder: whether a climb
//  attempt succeeds, and what a level is worth. Mirrors the separation
//  already used for the slot engine (`SlotEngine` decides, the view only
//  animates) - `RiskLadderSessionController` calls this to get a result
//  *before* playing any suspense animation, and randomness is injected via
//  the same `RandomNumberSource` protocol the slot engine uses, so tests
//  can drive it deterministically with `SeededRandomSource`.
//
import Foundation

nonisolated enum RiskLadderEngine {
    /// Fixed-point resolution used to turn a `Double` probability into an
    /// integer roll via `RandomNumberSource.nextInt(in:)`, since that's the
    /// only primitive the shared randomness protocol exposes.
    private static let probabilityResolution = 1_000_000

    /// Rolls whether climbing from `currentLevel` (0 = still standing at
    /// START, having climbed nothing yet) to the next rung succeeds.
    static func attemptClimb(
        fromLevel currentLevel: Int,
        configuration: [RiskLevel] = RiskLadderConfiguration.levels,
        randomSource: inout any RandomNumberSource
    ) -> Bool {
        guard currentLevel >= 0, currentLevel < configuration.count else { return false }
        let probability = min(max(configuration[currentLevel].successProbability, 0), 1)
        let threshold = Int((probability * Double(probabilityResolution)).rounded())
        let roll = randomSource.nextInt(in: 0..<probabilityResolution)
        return roll < threshold
    }

    /// The coin value of standing on `level` (1-based; `0` - still at
    /// START - is always worth `0`), rounded to the nearest whole coin to
    /// match the app's integer coin balance.
    static func payout(stake: Int64, level: Int, configuration: [RiskLevel] = RiskLadderConfiguration.levels) -> Int64 {
        guard level >= 1, level <= configuration.count, stake > 0 else { return 0 }
        let multiplier = configuration[level - 1].multiplier
        return Int64((Double(stake) * multiplier).rounded())
    }

    /// `multiplier * 100` as an integer (e.g. x1.5 -> 150, x100 -> 10000),
    /// the fixed-point representation `GameStatistics.highestMultiplierPercent`
    /// stores so the persisted stat stays an `Int64` like every other one.
    static func multiplierPercent(level: Int, configuration: [RiskLevel] = RiskLadderConfiguration.levels) -> Int64 {
        guard level >= 1, level <= configuration.count else { return 0 }
        return Int64((configuration[level - 1].multiplier * 100).rounded())
    }

    static func isJackpotLevel(_ level: Int, configuration: [RiskLevel] = RiskLadderConfiguration.levels) -> Bool {
        guard level >= 1, level <= configuration.count else { return false }
        return configuration[level - 1].isJackpot
    }
}
