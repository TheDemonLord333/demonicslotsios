//
//  SpinSessionController.swift
//  DemonicSlots
//
//  Drives one game's explicit state machine and owns everything a
//  `SlotMachineView` needs to render: current state, bet, last evaluation,
//  free-spin/bonus progress and error messages. All game logic lives here
//  (via `SlotEngine` and `SpinTransactionService`) - views only read
//  published state and call `spin()` / `selectBet(perLine:)`.
//
//  This type is reused unchanged for every slot game; only the injected
//  `SlotGameDefinition` and `SlotGamePlugin` differ per game.
//
import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class SpinSessionController {
    let definition: SlotGameDefinition
    let wallet: WalletService

    private let context: ModelContext
    private let engine: SlotEngine
    private let transactionService: SpinTransactionService
    private let progress: GameProgress
    private let statistics: GameStatistics
    private var randomSource: any RandomNumberSource

    private(set) var state: SlotMachineState = .idle
    var selectedBetPerLine: Int64
    private(set) var currentEvaluation: SpinEvaluation?
    /// Result of the most recently *completed* spin - updated after every
    /// spin, including to `0` for a non-winning round. This is "Aktueller
    /// Gewinn" in the UI.
    private(set) var lastWinAmount: Int64 = 0
    /// The most recent payout that was actually greater than `0`, sticky
    /// across non-winning rounds in between. This is "Letzter Gewinn" in
    /// the UI - deliberately distinct from `lastWinAmount`, which does
    /// reset to `0`.
    private(set) var lastNonZeroWinAmount: Int64 = 0
    private(set) var lastBetPerLineUsed: Int64 = 0
    private(set) var isInBonusRound: Bool = false
    private(set) var remainingFreeSpins: Int = 0
    private(set) var totalFreeSpinsInRound: Int = 0
    private(set) var bonusAccumulatedPayout: Int64 = 0
    private(set) var errorMessage: String?

    init(
        definition: SlotGameDefinition,
        plugin: (any SlotGamePlugin)?,
        context: ModelContext,
        randomSource: any RandomNumberSource = SystemRandomSource()
    ) {
        self.definition = definition
        self.context = context
        self.engine = SlotEngine(plugin: plugin)
        self.wallet = WalletService(context: context)
        self.progress = ProfileStore.fetchOrCreateProgress(for: definition.id, in: context)
        self.statistics = ProfileStore.fetchOrCreateStatistics(for: definition.id, in: context)
        self.transactionService = SpinTransactionService(context: context, wallet: wallet, engine: engine)
        self.randomSource = randomSource

        let firstBetLevel = definition.betLevels.first?.perLine ?? 1
        self.selectedBetPerLine = progress.lastBetPerLine > 0 ? progress.lastBetPerLine : firstBetLevel
        self.isInBonusRound = progress.isInBonusRound
        self.remainingFreeSpins = progress.remainingFreeSpins
        self.totalFreeSpinsInRound = progress.totalFreeSpinsGrantedInRound
        self.bonusAccumulatedPayout = progress.bonusAccumulatedPayout

        transactionService.recoverPendingSpins(gameID: definition.id, statistics: statistics)
    }

    var canSpin: Bool {
        state == .idle
    }

    /// The largest single-round payout ever recorded for this game,
    /// persisted via `GameStatistics` so it survives an app restart. This
    /// is "Gewinn-Highscore" in the UI.
    var highScoreWin: Int64 {
        statistics.largestSingleWin
    }

    var totalBet: Int64 {
        definition.totalBet(betPerLine: selectedBetPerLine)
    }

    func selectBet(perLine: Int64) {
        guard canSpin, !isInBonusRound else { return }
        guard definition.betLevels.contains(where: { $0.perLine == perLine }) else { return }
        selectedBetPerLine = perLine
        progress.lastBetPerLine = perLine
        try? context.save()
    }

    func selectMaxBet() {
        guard let maxLevel = definition.betLevels.map(\.perLine).max() else { return }
        selectBet(perLine: maxLevel)
    }

    func dismissError() {
        guard case .error = state else { return }
        errorMessage = nil
        state = .idle
    }

    /// Called by the UI once the bonus summary screen has been shown.
    func acknowledgeBonusSummary() {
        guard state == .bonusSummary else { return }
        progress.endBonusRound()
        isInBonusRound = false
        remainingFreeSpins = 0
        totalFreeSpinsInRound = 0
        bonusAccumulatedPayout = 0
        try? context.save()
        state = .idle
    }

    func spin() {
        guard canSpin else { return }
        state = .preparing
        errorMessage = nil

        let isFreeSpin = progress.isInBonusRound
        let betPerLine = isFreeSpin ? progress.bonusTriggerBetPerLine : selectedBetPerLine
        let freeSpinMultiplier = definition.freeSpinsRules?.winMultiplier ?? 1

        let result = transactionService.prepareSpin(
            definition: definition,
            betPerLine: betPerLine,
            isFreeSpin: isFreeSpin,
            freeSpinMultiplier: freeSpinMultiplier,
            randomSource: &randomSource
        )

        switch result {
        case .insufficientFunds:
            errorMessage = "Nicht genug Soul Coins für diesen Einsatz."
            state = .idle
        case .invalidDefinition(let message):
            errorMessage = message
            state = .error(message: message)
        case .prepared(let pending, let evaluation):
            currentEvaluation = evaluation
            lastBetPerLineUsed = betPerLine
            Task { [weak self] in
                await self?.runSpinSequence(
                    pending: pending,
                    evaluation: evaluation,
                    isFreeSpin: isFreeSpin,
                    betPerLine: betPerLine
                )
            }
        }
    }

    // MARK: - Animation sequencing

    private func runSpinSequence(
        pending: PendingSpin,
        evaluation: SpinEvaluation,
        isFreeSpin: Bool,
        betPerLine: Int64
    ) async {
        state = .spinning
        await sleep(SpinTiming.spinDuration(reelCount: definition.reelCount))

        state = .stopping
        await sleep(SpinTiming.settleDuration)

        state = .evaluating
        let payout = transactionService.finalizeSpin(pending: pending, evaluation: evaluation, statistics: statistics)
        lastWinAmount = payout
        if payout > 0 { lastNonZeroWinAmount = payout }

        var enteredBonus = false
        var bonusEnded = false

        if isFreeSpin {
            progress.remainingFreeSpins = max(progress.remainingFreeSpins - 1, 0)
            progress.bonusAccumulatedPayout += payout
            if let scatterWin = evaluation.scatterWin, let rules = definition.freeSpinsRules,
               ScatterEvaluator.qualifiesForRetrigger(scatterCount: scatterWin.count, rules: rules) {
                let grant = rules.retriggerGrant(totalAlreadyGranted: progress.totalFreeSpinsGrantedInRound)
                progress.remainingFreeSpins += grant
                progress.totalFreeSpinsGrantedInRound += grant
            }
            if progress.remainingFreeSpins <= 0 {
                bonusEnded = true
            }
        } else if evaluation.isBonusTriggering, let scatterWin = evaluation.scatterWin {
            progress.startBonusRound(freeSpins: scatterWin.freeSpinsAwarded, betPerLine: betPerLine)
            enteredBonus = true
        }

        isInBonusRound = progress.isInBonusRound
        remainingFreeSpins = progress.remainingFreeSpins
        totalFreeSpinsInRound = progress.totalFreeSpinsGrantedInRound
        bonusAccumulatedPayout = progress.bonusAccumulatedPayout
        try? context.save()

        if enteredBonus {
            state = .enteringBonus
            await sleep(SpinTiming.bonusTransitionDuration)
        } else if evaluation.hasAnyWin {
            state = .celebrating
            await sleep(SpinTiming.celebrationDuration(payout: payout, totalBet: definition.totalBet(betPerLine: betPerLine)))
        }

        if bonusEnded {
            state = .bonusSummary
            return
        }

        state = .idle
    }

    private func sleep(_ seconds: Double) async {
        guard seconds > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
