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
    /// Toggled by holding the spin button (see `SlotMachineView`) - while
    /// on, a new spin is queued automatically every time the machine
    /// becomes ready again, including through every free spin of a bonus
    /// round, so the player never has to keep tapping to clear one. Never
    /// persisted - always starts off for a freshly created controller
    /// (leaving the screen, relaunching the app), deliberately, so autospin
    /// never silently resumes without the player re-engaging it.
    private(set) var isAutoSpinning = false

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
        let restoredBet = progress.lastBetPerLine > 0 ? progress.lastBetPerLine : firstBetLevel
        self.isInBonusRound = progress.isInBonusRound
        self.remainingFreeSpins = progress.remainingFreeSpins
        self.totalFreeSpinsInRound = progress.totalFreeSpinsGrantedInRound
        self.bonusAccumulatedPayout = progress.bonusAccumulatedPayout

        transactionService.recoverPendingSpins(gameID: definition.id, statistics: statistics)

        // Defensive: a previously-selected bet might no longer be unlocked
        // (the player's level could have been lowered by an admin edit
        // since the last session) - fall back to the highest bet that's
        // still available rather than silently letting a locked bet stand.
        self.selectedBetPerLine = restoredBet
        let unlocked = self.availableBetLevels.map(\.perLine)
        if !unlocked.contains(restoredBet) {
            self.selectedBetPerLine = unlocked.last ?? firstBetLevel
        }
    }

    var canSpin: Bool {
        state == .idle
    }

    /// This player's current level/win-chance multiplier/admin jackpot
    /// flag, straight from the shared `PlayerProfile` (level/multiplier
    /// validated again here regardless of whether `AccountSyncController`
    /// already validated them on the way in - see `PlayerProgressionService`'s
    /// header comment on why that's cheap insurance, not redundant).
    private var progressionInputs: (level: Int, playerMultiplier: Double, guaranteesJackpot: Bool) {
        let profile = wallet.currentProfile()
        return (Int(profile.level), profile.winChanceMultiplier, profile.hasGuaranteedJackpot)
    }

    /// The win-chance context this player currently has for any game,
    /// computed once per read from `PlayerProgressionService` rather than
    /// every mechanic loading `PlayerProfile`/the backend itself.
    var probabilityContext: GameProbabilityContext {
        let inputs = progressionInputs
        return PlayerProgressionService.probabilityContext(
            level: inputs.level,
            playerMultiplier: inputs.playerMultiplier,
            guaranteesJackpot: inputs.guaranteesJackpot
        )
    }

    /// This game's own bet levels, filtered down to what the player's
    /// current level actually unlocks - `min(playerLevelMaxBet,
    /// gameMaximumBet)` applied to `definition.betLevels`. Never mutates
    /// `definition.betLevels` itself.
    ///
    /// Compares `definition.totalBet(betPerLine:)` (the actual Soul Coins
    /// wagered per spin at that bet level - `perLine * activeLineCount`),
    /// never bare `perLine`, against the ladder-derived limit: the shared
    /// stake ladder's numbers (see `PlayerProgressionService.
    /// stakeSequenceValue(atIndex:)`/`SlotGameDefinition.
    /// betTierStartIndex`'s doc comments) are a "Max Einsatz" a player
    /// would recognize - the total risked in one spin - which for a
    /// multi-payline game like Infernal Forge is *not* the same number as
    /// its `perLine` bet levels. Risk Ladder has exactly one "line", so
    /// `totalBet(betPerLine:) == betPerLine` there and this is a no-op -
    /// one formula, correct for both without a second special case.
    var availableBetLevels: [BetLevel] {
        let gameMaximumBet = definition.betLevels.map { definition.totalBet(betPerLine: $0.perLine) }.max() ?? 0
        let limit = PlayerProgressionService.effectiveMaxBet(
            level: progressionInputs.level,
            gameMaximumBet: gameMaximumBet,
            betTierStartIndex: definition.betTierStartIndex
        )
        return definition.betLevels.filter { definition.totalBet(betPerLine: $0.perLine) <= limit }
    }

    /// Bet levels this game supports but the player's level doesn't unlock
    /// yet, paired with the level that *would* unlock each one - for a
    /// "🔒 Level X" hint in the bet control. `nil` for a bet no configured
    /// tier ever unlocks.
    var lockedBetLevels: [(bet: BetLevel, unlockLevel: Int?)] {
        let unlocked = Set(availableBetLevels.map(\.perLine))
        return definition.betLevels
            .filter { !unlocked.contains($0.perLine) }
            .map {
                (
                    $0,
                    PlayerProgressionService.unlockLevel(
                        forBet: definition.totalBet(betPerLine: $0.perLine),
                        betTierStartIndex: definition.betTierStartIndex
                    )
                )
            }
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

    /// Only accepts a bet this game supports *and* the player's level has
    /// unlocked (see `availableBetLevels`) - never just `definition.
    /// betLevels`, so a locked bet can't be selected by calling this
    /// directly even if a view somehow offered it.
    func selectBet(perLine: Int64) {
        guard canSpin, !isInBonusRound else { return }
        guard availableBetLevels.contains(where: { $0.perLine == perLine }) else { return }
        selectedBetPerLine = perLine
        progress.lastBetPerLine = perLine
        try? context.save()
    }

    func selectMaxBet() {
        guard let maxLevel = availableBetLevels.map(\.perLine).max() else { return }
        selectBet(perLine: maxLevel)
    }

    func dismissError() {
        guard case .error = state else { return }
        errorMessage = nil
        isAutoSpinning = false
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
        continueAutoSpinIfNeeded()
    }

    /// Engages/disengages autospin (see `isAutoSpinning`'s doc comment).
    /// Turning it on immediately queues a spin if the machine is currently
    /// ready; turning it off just stops future spins from being queued -
    /// a spin already in flight always finishes normally.
    func toggleAutoSpin() {
        isAutoSpinning.toggle()
        if isAutoSpinning {
            continueAutoSpinIfNeeded()
        }
    }

    /// Queues the next automatic spin after a short pause, if autospin is
    /// engaged and the machine is actually ready. A no-op otherwise -
    /// safe to call speculatively from anywhere `state` might have just
    /// become `.idle`. `spin()` itself is what turns `isAutoSpinning` back
    /// off the moment an attempt is actually refused (insufficient funds,
    /// a now-locked bet, ...), so this never needs to duplicate that
    /// validation - it only ever has to decide *when* to try again.
    private func continueAutoSpinIfNeeded() {
        guard isAutoSpinning, canSpin else { return }
        Task { [weak self] in
            await self?.sleep(SpinTiming.autoSpinPause)
            guard let self, self.isAutoSpinning, self.canSpin else { return }
            self.spin()
        }
    }

    func spin() {
        guard canSpin else { return }

        let isFreeSpin = progress.isInBonusRound
        let betPerLine = isFreeSpin ? progress.bonusTriggerBetPerLine : selectedBetPerLine

        // Defensive re-check, not just the picker's own guard: a background
        // sync could have lowered the player's level (hence their bet
        // limit) between selecting this bet and pressing spin. A regular
        // stake spin with a now-locked bet is refused outright rather than
        // silently spun at a different amount than the player chose; a free
        // spin's stake was already fixed when its bonus round started and
        // is never re-validated against the *current* limit.
        if !isFreeSpin, !availableBetLevels.contains(where: { $0.perLine == betPerLine }) {
            errorMessage = "Dieser Einsatz ist mit deinem aktuellen Level nicht mehr freigeschaltet."
            state = .error(message: errorMessage!)
            isAutoSpinning = false
            return
        }

        state = .preparing
        errorMessage = nil

        let freeSpinMultiplier = definition.freeSpinsRules?.winMultiplier ?? 1

        let result = transactionService.prepareSpin(
            definition: definition,
            betPerLine: betPerLine,
            isFreeSpin: isFreeSpin,
            freeSpinMultiplier: freeSpinMultiplier,
            probabilityContext: probabilityContext,
            randomSource: &randomSource
        )

        switch result {
        case .insufficientFunds:
            errorMessage = "Nicht genug Soul Coins für diesen Einsatz."
            state = .idle
            isAutoSpinning = false
        case .invalidDefinition(let message):
            errorMessage = message
            state = .error(message: message)
            isAutoSpinning = false
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
        continueAutoSpinIfNeeded()
    }

    private func sleep(_ seconds: Double) async {
        guard seconds > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
