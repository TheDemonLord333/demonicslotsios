//
//  SlotSimulatorTests.swift
//  DemonicSlotsTests
//
//  A fast sanity check that `SlotSimulator` runs cleanly and produces
//  internally consistent numbers. The real >= 1,000,000 spin RTP
//  measurement used to tune Infernal Forge is run from the DEBUG-only
//  `RTPSimulationDebugView` (Settings > Entwicklung), not as part of the
//  normal test suite, since that scale of run is meant for tuning, not CI.
//
#if DEBUG
import Testing
@testable import DemonicSlots

struct SlotSimulatorTests {
    @Test func simulationProducesInternallyConsistentStatistics() {
        let definition = InfernalForgeDefinition.definition
        let spinCount = 20_000
        let report = SlotSimulator.run(definition: definition, betPerLine: 1, spinCount: spinCount, seed: 123)

        #expect(report.spinCount == spinCount)
        #expect(report.totalWagered == Int64(spinCount) * definition.totalBet(betPerLine: 1))
        #expect(report.totalPaidOut >= 0)
        #expect(report.rtp >= 0)
        #expect(report.hitRate >= 0 && report.hitRate <= 1)
        #expect(report.bonusRate >= 0 && report.bonusRate <= 1)
        #expect(report.maxSinglePayout >= 0)
        #expect(!report.summary.isEmpty)
    }

    @Test func simulationIsReproducibleForTheSameSeed() {
        let definition = InfernalForgeDefinition.definition
        let reportA = SlotSimulator.run(definition: definition, betPerLine: 1, spinCount: 5_000, seed: 55)
        let reportB = SlotSimulator.run(definition: definition, betPerLine: 1, spinCount: 5_000, seed: 55)
        #expect(reportA.totalPaidOut == reportB.totalPaidOut)
        #expect(reportA.winningSpinCount == reportB.winningSpinCount)
        #expect(reportA.bonusTriggerCount == reportB.bonusTriggerCount)
    }
}
#endif
