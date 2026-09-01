//
//  SpinTransactionService.swift
//  DemonicSlots
//
//  The transaction-safe core of a spin, deliberately kept free of any
//  animation timing so it can be tested (and reasoned about) in isolation:
//
//   1. state is checked by the caller (`SpinSessionController`)
//   2. balance is checked here
//   3. the outcome is computed by `SlotEngine` before anything is persisted
//   4. a `PendingSpin` is written with a unique transaction id
//   5. the stake is debited exactly once
//   6. (animation plays in the caller)
//   7. the payout is credited exactly once
//   8. statistics are updated
//   9. the transaction is closed by deleting the `PendingSpin`
//
//  If the app is killed between steps 4-9, `recoverPendingSpins` finishes
//  (or safely discards) the interrupted spin the next time it runs, using
//  the outcome recorded in step 4 rather than rerolling anything.
//
import Foundation
import SwiftData

@MainActor
final class SpinTransactionService {
    enum PrepareResult {
        case prepared(PendingSpin, SpinEvaluation)
        case insufficientFunds
        case invalidDefinition(String)
    }

    private let context: ModelContext
    private let wallet: WalletService
    private let engine: SlotEngine

    init(context: ModelContext, wallet: WalletService, engine: SlotEngine) {
        self.context = context
        self.wallet = wallet
        self.engine = engine
    }

    /// Steps 1-5: validates funds, computes the outcome, persists a
    /// `PendingSpin`, and debits the stake (unless this is a free spin).
    func prepareSpin(
        definition: SlotGameDefinition,
        betPerLine: Int64,
        isFreeSpin: Bool,
        freeSpinMultiplier: Int64,
        probabilityContext: GameProbabilityContext = .neutral,
        randomSource: inout any RandomNumberSource
    ) -> PrepareResult {
        let totalBet = definition.totalBet(betPerLine: betPerLine)

        if !isFreeSpin, !wallet.canAfford(totalBet) {
            return .insufficientFunds
        }

        let evaluation: SpinEvaluation
        do {
            evaluation = try engine.spin(
                definition: definition,
                betPerLine: betPerLine,
                isFreeSpin: isFreeSpin,
                freeSpinMultiplier: freeSpinMultiplier,
                probabilityContext: probabilityContext,
                randomSource: &randomSource
            )
        } catch {
            return .invalidDefinition(error.localizedDescription)
        }

        let encodedEvaluation = (try? PendingSpin.encode(evaluation)) ?? Data()
        let pending = PendingSpin(
            gameID: definition.id.rawValue,
            betPerLine: betPerLine,
            totalBet: totalBet,
            isFreeSpin: isFreeSpin,
            freeSpinMultiplier: freeSpinMultiplier,
            evaluationData: encodedEvaluation
        )
        context.insert(pending)
        try? context.save()

        if !isFreeSpin {
            guard wallet.debit(totalBet) else {
                context.delete(pending)
                try? context.save()
                return .insufficientFunds
            }
        }
        pending.stakeDebited = true
        try? context.save()

        return .prepared(pending, evaluation)
    }

    /// Steps 7-9: credits the payout exactly once, updates statistics, and
    /// closes the transaction. Idempotent - calling it twice for the same
    /// `PendingSpin` only pays out once.
    @discardableResult
    func finalizeSpin(pending: PendingSpin, evaluation: SpinEvaluation, statistics: GameStatistics) -> Int64 {
        guard !pending.payoutCredited else {
            context.delete(pending)
            try? context.save()
            return 0
        }

        if evaluation.totalPayout > 0 {
            wallet.credit(evaluation.totalPayout)
        }
        pending.payoutCredited = true

        let wager = pending.isFreeSpin ? 0 : pending.totalBet
        statistics.record(wager: wager, payout: evaluation.totalPayout, triggeredBonus: evaluation.isBonusTriggering)

        context.delete(pending)
        try? context.save()
        return evaluation.totalPayout
    }

    /// Reconciles every `PendingSpin` left over from a previous run for one
    /// game. Must run before that game accepts a new spin.
    func recoverPendingSpins(gameID: GameID, statistics: GameStatistics) {
        let rawID = gameID.rawValue
        let descriptor = FetchDescriptor<PendingSpin>(predicate: #Predicate { $0.gameID == rawID })
        guard let stalePendingSpins = try? context.fetch(descriptor), !stalePendingSpins.isEmpty else { return }

        for pending in stalePendingSpins {
            if !pending.stakeDebited {
                // Nothing was ever taken; the spin never really happened.
                context.delete(pending)
                continue
            }
            if !pending.payoutCredited {
                if let evaluation = pending.decodedEvaluation() {
                    finalizeSpin(pending: pending, evaluation: evaluation, statistics: statistics)
                } else {
                    // Stake is already gone and the exact result can't be
                    // recovered; drop the record rather than guessing.
                    context.delete(pending)
                }
                continue
            }
            // Already fully settled, just never cleaned up.
            context.delete(pending)
        }
        try? context.save()
    }
}
