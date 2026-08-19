//
//  SpinTransactionServiceTests.swift
//  DemonicSlotsTests
//
//  Covers requirements 8 (single stake deduction), 9 (single payout
//  credit) and 12 (recovering an interrupted `PendingSpin`).
//
import Foundation
import SwiftData
import Testing
@testable import DemonicSlots

@MainActor
struct SpinTransactionServiceTests {
    private func makeContext() -> ModelContext {
        ModelContext(PersistenceController.makeInMemoryModelContainer())
    }

    @Test func prepareSpinDebitsStakeExactlyOnceAndFinalizeCreditsPayoutExactlyOnce() {
        let context = makeContext()
        let wallet = WalletService(context: context)
        let engine = SlotEngine()
        let service = SpinTransactionService(context: context, wallet: wallet, engine: engine)
        let definition = InfernalForgeDefinition.definition
        var random: any RandomNumberSource = SeededRandomSource(seed: 99)

        let startBalance = wallet.balance
        let result = service.prepareSpin(definition: definition, betPerLine: 10, isFreeSpin: false, freeSpinMultiplier: 1, randomSource: &random)

        guard case .prepared(let pending, let evaluation) = result else {
            Issue.record("Expected the spin to prepare successfully")
            return
        }

        let totalBet = definition.totalBet(betPerLine: 10)
        #expect(wallet.balance == startBalance - totalBet)
        #expect(pending.stakeDebited)
        #expect(!pending.payoutCredited)

        let statistics = GameStatistics(gameID: definition.id.rawValue)
        context.insert(statistics)

        let payout = service.finalizeSpin(pending: pending, evaluation: evaluation, statistics: statistics)
        #expect(payout == evaluation.totalPayout)
        #expect(wallet.balance == startBalance - totalBet + evaluation.totalPayout)
        #expect(statistics.totalSpins == 1)

        // Finalizing the same pending spin again must not pay out twice.
        let secondPayout = service.finalizeSpin(pending: pending, evaluation: evaluation, statistics: statistics)
        #expect(secondPayout == 0)
        #expect(wallet.balance == startBalance - totalBet + evaluation.totalPayout)
        #expect(statistics.totalSpins == 1)
    }

    @Test func insufficientFundsNeverDebitsTheWallet() {
        let context = makeContext()
        let wallet = WalletService(context: context)
        let engine = SlotEngine()
        let service = SpinTransactionService(context: context, wallet: wallet, engine: engine)
        let definition = InfernalForgeDefinition.definition
        var random: any RandomNumberSource = SeededRandomSource(seed: 1)

        _ = wallet.debit(wallet.balance) // drain the wallet to zero

        let result = service.prepareSpin(definition: definition, betPerLine: 1, isFreeSpin: false, freeSpinMultiplier: 1, randomSource: &random)
        guard case .insufficientFunds = result else {
            Issue.record("Expected insufficientFunds")
            return
        }
        #expect(wallet.balance == 0)
    }

    @Test func eachPendingSpinGetsAUniqueTransactionID() {
        let context = makeContext()
        let wallet = WalletService(context: context)
        let engine = SlotEngine()
        let service = SpinTransactionService(context: context, wallet: wallet, engine: engine)
        let definition = InfernalForgeDefinition.definition
        let statistics = GameStatistics(gameID: definition.id.rawValue)
        context.insert(statistics)

        var randomA: any RandomNumberSource = SeededRandomSource(seed: 1)
        guard case .prepared(let pendingA, let evalA) = service.prepareSpin(definition: definition, betPerLine: 1, isFreeSpin: false, freeSpinMultiplier: 1, randomSource: &randomA) else {
            Issue.record("Expected first spin to prepare")
            return
        }
        service.finalizeSpin(pending: pendingA, evaluation: evalA, statistics: statistics)

        var randomB: any RandomNumberSource = SeededRandomSource(seed: 2)
        guard case .prepared(let pendingB, _) = service.prepareSpin(definition: definition, betPerLine: 1, isFreeSpin: false, freeSpinMultiplier: 1, randomSource: &randomB) else {
            Issue.record("Expected second spin to prepare")
            return
        }
        #expect(pendingA.transactionID != pendingB.transactionID)
    }

    @Test func recoveringAnInterruptedSpinCreditsItExactlyOnceWithoutReDebiting() throws {
        let context = makeContext()
        let wallet = WalletService(context: context)
        let engine = SlotEngine()
        let service = SpinTransactionService(context: context, wallet: wallet, engine: engine)
        let definition = InfernalForgeDefinition.definition
        var random: any RandomNumberSource = SeededRandomSource(seed: 5)

        let startBalance = wallet.balance
        let result = service.prepareSpin(definition: definition, betPerLine: 10, isFreeSpin: false, freeSpinMultiplier: 1, randomSource: &random)
        guard case .prepared(_, let evaluation) = result else {
            Issue.record("Expected prepared spin")
            return
        }
        let totalBet = definition.totalBet(betPerLine: 10)
        #expect(wallet.balance == startBalance - totalBet)

        // Simulate the app being killed right after the stake was debited:
        // `finalizeSpin` is never called. On the next launch, only the
        // persisted `PendingSpin` record is used to recover - the outcome
        // is never rerolled.
        let statistics = GameStatistics(gameID: definition.id.rawValue)
        context.insert(statistics)
        service.recoverPendingSpins(gameID: definition.id, statistics: statistics)

        #expect(wallet.balance == startBalance - totalBet + evaluation.totalPayout)
        #expect(statistics.totalSpins == 1)

        let remaining = try context.fetch(FetchDescriptor<PendingSpin>())
        #expect(remaining.isEmpty)

        // Recovering again (e.g. a second relaunch) must be a no-op.
        service.recoverPendingSpins(gameID: definition.id, statistics: statistics)
        #expect(wallet.balance == startBalance - totalBet + evaluation.totalPayout)
        #expect(statistics.totalSpins == 1)
    }

    @Test func recoveringASpinWhoseStakeWasNeverDebitedNeverChargesTheWallet() throws {
        let context = makeContext()
        let wallet = WalletService(context: context)
        let definition = InfernalForgeDefinition.definition

        let evaluation = SpinEvaluation(
            spinResult: SpinResult(stopIndices: [0, 0, 0, 0, 0], grid: Array(repeating: [SymbolID("x")], count: 5)),
            lineWins: [],
            scatterWin: nil,
            totalPayout: 999,
            isBonusTriggering: false
        )
        let pending = PendingSpin(
            gameID: definition.id.rawValue,
            betPerLine: 10,
            totalBet: 100,
            isFreeSpin: false,
            freeSpinMultiplier: 1,
            evaluationData: try PendingSpin.encode(evaluation),
            stakeDebited: false,
            payoutCredited: false
        )
        context.insert(pending)
        try context.save()

        let engine = SlotEngine()
        let service = SpinTransactionService(context: context, wallet: wallet, engine: engine)
        let statistics = GameStatistics(gameID: definition.id.rawValue)
        context.insert(statistics)

        let startBalance = wallet.balance
        service.recoverPendingSpins(gameID: definition.id, statistics: statistics)

        #expect(wallet.balance == startBalance) // never charged, never paid out
        let remaining = try context.fetch(FetchDescriptor<PendingSpin>())
        #expect(remaining.isEmpty)
    }
}
