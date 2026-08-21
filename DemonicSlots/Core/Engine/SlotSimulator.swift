//
//  SlotSimulator.swift
//  DemonicSlots
//
//  Debug-only bulk simulation used to measure a game's actual RTP, hit
//  rate, bonus rate and maximum single-spin payout before it ships. The
//  finished app never displays a fixed RTP figure - only a number this
//  simulator has actually produced should ever be shown to a player, and
//  today it isn't wired into any player-facing UI. Run it from a debug
//  menu (`SettingsView` exposes one in DEBUG builds) or a unit test.
//
#if DEBUG
import Foundation

struct SlotSimulationReport: Sendable {
    var spinCount: Int
    var totalWagered: Int64
    var totalPaidOut: Int64
    var winningSpinCount: Int
    var bonusTriggerCount: Int
    var maxSinglePayout: Int64

    var rtp: Double {
        guard totalWagered > 0 else { return 0 }
        return Double(totalPaidOut) / Double(totalWagered)
    }

    var hitRate: Double {
        guard spinCount > 0 else { return 0 }
        return Double(winningSpinCount) / Double(spinCount)
    }

    var bonusRate: Double {
        guard spinCount > 0 else { return 0 }
        return Double(bonusTriggerCount) / Double(spinCount)
    }

    var summary: String {
        """
        Spins: \(spinCount)
        RTP: \(String(format: "%.2f", rtp * 100))%
        Hit rate: \(String(format: "%.2f", hitRate * 100))%
        Bonus rate: 1 in \(bonusTriggerCount > 0 ? spinCount / bonusTriggerCount : 0)
        Max single payout: \(maxSinglePayout) coins
        """
    }
}

nonisolated enum SlotSimulator {
    /// Runs `spinCount` base-game spins at a fixed bet, playing through any
    /// triggered free-spin bonus rounds (including retriggers, capped by
    /// `maxFreeSpins`) so the reported RTP reflects the bonus contribution
    /// too. Uses a seeded RNG so results are reproducible run to run; pass a
    /// different seed to sample a different sequence. Base-game spin count
    /// is what `spinCount` controls; bonus spins are additional and not
    /// counted against it or against `totalWagered` (they cost no stake).
    static func run(
        definition: SlotGameDefinition,
        betPerLine: Int64,
        spinCount: Int,
        seed: UInt64 = 1
    ) -> SlotSimulationReport {
        var randomSource: any RandomNumberSource = SeededRandomSource(seed: seed)
        let engine = SlotEngine()
        let totalBet = definition.totalBet(betPerLine: betPerLine)

        var totalWagered: Int64 = 0
        var totalPaidOut: Int64 = 0
        var winningSpinCount = 0
        var bonusTriggerCount = 0
        var maxSinglePayout: Int64 = 0

        for _ in 0..<spinCount {
            guard let evaluation = try? engine.spin(
                definition: definition,
                betPerLine: betPerLine,
                isFreeSpin: false,
                freeSpinMultiplier: 1,
                randomSource: &randomSource
            ) else { break }

            totalWagered += totalBet
            totalPaidOut += evaluation.totalPayout
            if evaluation.totalPayout > 0 { winningSpinCount += 1 }
            maxSinglePayout = max(maxSinglePayout, evaluation.totalPayout)

            if evaluation.isBonusTriggering, let rules = definition.freeSpinsRules {
                bonusTriggerCount += 1
                let bonusPayout = simulateBonusRound(
                    definition: definition,
                    rules: rules,
                    betPerLine: betPerLine,
                    initialFreeSpins: evaluation.scatterWin?.freeSpinsAwarded ?? 0,
                    engine: engine,
                    randomSource: &randomSource
                )
                totalPaidOut += bonusPayout
                maxSinglePayout = max(maxSinglePayout, bonusPayout)
            }
        }

        return SlotSimulationReport(
            spinCount: spinCount,
            totalWagered: totalWagered,
            totalPaidOut: totalPaidOut,
            winningSpinCount: winningSpinCount,
            bonusTriggerCount: bonusTriggerCount,
            maxSinglePayout: maxSinglePayout
        )
    }

    /// Plays a full free-spin bonus round to completion and returns its
    /// total coin payout. Mirrors the retrigger/cap rules `SpinSessionController`
    /// applies interactively, but as a tight synchronous loop suited to bulk
    /// simulation.
    private static func simulateBonusRound(
        definition: SlotGameDefinition,
        rules: FreeSpinsRules,
        betPerLine: Int64,
        initialFreeSpins: Int,
        engine: SlotEngine,
        randomSource: inout any RandomNumberSource
    ) -> Int64 {
        var remainingSpins = min(initialFreeSpins, rules.maxFreeSpins)
        var spinsPlayed = 0
        var totalSpinsGranted = remainingSpins
        var payout: Int64 = 0

        while remainingSpins > 0 {
            guard let evaluation = try? engine.spin(
                definition: definition,
                betPerLine: betPerLine,
                isFreeSpin: true,
                freeSpinMultiplier: rules.winMultiplier,
                randomSource: &randomSource
            ) else { break }

            payout += evaluation.totalPayout
            remainingSpins -= 1
            spinsPlayed += 1

            let scatterCount = evaluation.scatterWin?.count ?? 0
            if ScatterEvaluator.qualifiesForRetrigger(scatterCount: scatterCount, rules: rules) {
                let grant = rules.retriggerGrant(totalAlreadyGranted: totalSpinsGranted)
                remainingSpins += grant
                totalSpinsGranted += grant
            }
        }

        return payout
    }
}
#endif
