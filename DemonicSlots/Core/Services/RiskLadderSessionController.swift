//
//  RiskLadderSessionController.swift
//  DemonicSlots
//
//  Drives one Demonic Risk Ladder round: current state, stake, level and
//  error messages. All game logic lives here (via `RiskLadderEngine` and
//  the wallet/statistics/round-state persistence) - `RiskLadderView` only
//  reads published state and calls `startRound()` / `risk()` / `cashOut()`.
//  Mirrors `SpinSessionController`'s separation of concerns for the slot:
//  the outcome of a climb is decided *before* any animation plays, and
//  every coin movement is guarded by `RiskLadderRoundState` so a killed
//  app, a rapid double-tap, or a view re-appearance can never duplicate a
//  stake debit or a payout.
//
import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class RiskLadderSessionController {
    let definition: SlotGameDefinition

    private let context: ModelContext
    let wallet: WalletService
    private let roundState: RiskLadderRoundState
    private let statistics: GameStatistics
    private var randomSource: any RandomNumberSource
    private let levels: [RiskLevel]

    private(set) var state: RiskLadderState = .idle
    var selectedStake: Int64
    /// The stake actually committed to the active round - distinct from
    /// `selectedStake`, which is just the picker's pending choice and stays
    /// changeable again once the round ends.
    private(set) var activeStake: Int64 = 0
    /// 0 = standing at START. 1...`RiskLadderConfiguration.maxLevel` = the
    /// highest rung reached so far this round.
    private(set) var currentLevel: Int = 0
    /// The payout of the round that just ended (loss = `0`), shown by the
    /// result overlay while `state` is `.lost`/`.cashedOut`/`.jackpot`.
    private(set) var lastRoundPayout: Int64 = 0
    private(set) var errorMessage: String?

    init(
        definition: SlotGameDefinition,
        context: ModelContext,
        randomSource: any RandomNumberSource = SystemRandomSource(),
        levels: [RiskLevel] = RiskLadderConfiguration.levels
    ) {
        self.definition = definition
        self.context = context
        self.wallet = WalletService(context: context)
        self.roundState = ProfileStore.fetchOrCreateRiskLadderRoundState(for: definition.id, in: context)
        self.statistics = ProfileStore.fetchOrCreateStatistics(for: definition.id, in: context)
        self.randomSource = randomSource
        self.levels = levels

        if roundState.isActive, roundState.stakeDebited {
            // The app was killed mid-round after the stake was taken but
            // before any payout - resume exactly where it left off. Safe:
            // nothing has been credited yet, and the stake was already
            // debited exactly once, so resuming duplicates nothing.
            activeStake = roundState.stake
            currentLevel = roundState.currentLevel
            state = .ready
        } else if roundState.isActive {
            // isActive but the debit itself never completed/saved: nothing
            // was actually charged, so there's nothing to recover.
            roundState.reset()
            try? context.save()
        }

        // Defensive, same reasoning as `SpinSessionController`: fall back to
        // the highest still-unlocked stake if the player's level was
        // lowered since the last session left a higher one selected.
        let firstStake = definition.betLevels.first?.perLine ?? 10
        self.selectedStake = firstStake
        let unlocked = self.availableStakeLevels.map(\.perLine)
        if !unlocked.isEmpty, !unlocked.contains(firstStake) {
            self.selectedStake = unlocked.last ?? firstStake
        }
    }

    var maxLevel: Int { levels.count }

    var canSelectStake: Bool { state == .idle }
    var canStart: Bool { state == .idle }
    var canRisk: Bool { state == .ready }
    var canCashOut: Bool { state == .ready && currentLevel > 0 }

    /// This player's current level/win-chance multiplier/admin jackpot flag
    /// - same source and same reasoning as
    /// `SpinSessionController.progressionInputs`.
    private var progressionInputs: (level: Int, playerMultiplier: Double, guaranteesJackpot: Bool) {
        let profile = wallet.currentProfile()
        return (Int(profile.level), profile.winChanceMultiplier, profile.hasGuaranteedJackpot)
    }

    /// The win-chance context this player currently has, applied to each
    /// climb attempt's base probability - see `RiskLadderEngine.attemptClimb`.
    var probabilityContext: GameProbabilityContext {
        let inputs = progressionInputs
        return PlayerProgressionService.probabilityContext(
            level: inputs.level,
            playerMultiplier: inputs.playerMultiplier,
            guaranteesJackpot: inputs.guaranteesJackpot
        )
    }

    /// This game's own stakes, filtered down to what the player's current
    /// level actually unlocks - reuses the exact same shared stake-ladder
    /// logic the slot uses, per the task's explicit "no second
    /// special-case solution" ask, just with this game's own
    /// `betTierStartIndex`.
    ///
    /// Compares `definition.totalBet(betPerLine:)`, not bare `perLine` -
    /// see `SpinSessionController.availableBetLevels`'s doc comment for
    /// why. A no-op here specifically (Demonic Risk Ladder's definition has
    /// exactly one placeholder payline, so `totalBet(betPerLine:) ==
    /// betPerLine` always), but using the same formula both places means
    /// this stays correct even if that ever changed, with nothing to
    /// remember to update.
    var availableStakeLevels: [BetLevel] {
        let gameMaximumBet = definition.betLevels.map { definition.totalBet(betPerLine: $0.perLine) }.max() ?? 0
        let limit = PlayerProgressionService.effectiveMaxBet(
            level: progressionInputs.level,
            gameMaximumBet: gameMaximumBet,
            betTierStartIndex: definition.betTierStartIndex
        )
        return definition.betLevels.filter { definition.totalBet(betPerLine: $0.perLine) <= limit }
    }

    /// Stakes this game supports but the player's level doesn't unlock yet,
    /// paired with the level that would unlock each one.
    var lockedStakeLevels: [(bet: BetLevel, unlockLevel: Int?)] {
        let unlocked = Set(availableStakeLevels.map(\.perLine))
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

    /// The multiplier for the rung currently stood on (`0` while at START).
    var currentMultiplier: Double {
        guard currentLevel >= 1, currentLevel <= levels.count else { return 0 }
        return levels[currentLevel - 1].multiplier
    }

    /// What cashing out right now would pay (`0` while at START).
    var currentPayout: Int64 {
        RiskLadderEngine.payout(stake: activeStake, level: currentLevel, configuration: levels)
    }

    /// The *effective* (bonus-adjusted) success probability of the next
    /// climb, for UI display (e.g. hinting how risky the next rung really
    /// is for this player) - not the raw configured base value, so the hint
    /// stays honest once a win-chance bonus is in play. `nil` once at the
    /// top.
    var nextClimbProbability: Double? {
        guard currentLevel < levels.count else { return nil }
        return probabilityContext.adjustedProbability(base: levels[currentLevel].successProbability)
    }

    /// Only accepts a stake this game supports *and* the player's level has
    /// unlocked - never just `definition.betLevels` (see
    /// `availableStakeLevels`).
    func selectStake(_ amount: Int64) {
        guard canSelectStake else { return }
        guard availableStakeLevels.contains(where: { $0.perLine == amount }) else { return }
        selectedStake = amount
    }

    func selectMaxStake() {
        guard let maxStake = availableStakeLevels.map(\.perLine).max() else { return }
        selectStake(maxStake)
    }

    func dismissError() {
        guard case .error = state else { return }
        errorMessage = nil
        state = .idle
    }

    /// Debits the stake exactly once and activates the round. Guarded by
    /// `state == .idle`, so a rapid double-tap on START is a no-op the
    /// second time (the first call already moved `state` off `.idle`).
    func startRound() {
        guard canStart else { return }

        // Defensive re-check, same reasoning as `SpinSessionController.spin()`:
        // a background sync could have lowered the player's level (hence
        // their stake limit) between selecting this stake and pressing
        // START.
        guard availableStakeLevels.contains(where: { $0.perLine == selectedStake }) else {
            let message = "Dieser Einsatz ist mit deinem aktuellen Level nicht mehr freigeschaltet."
            errorMessage = message
            state = .error(message: message)
            return
        }

        guard wallet.canAfford(selectedStake) else {
            let message = "Nicht genug Soul Coins für diesen Einsatz."
            errorMessage = message
            state = .error(message: message)
            return
        }

        roundState.isActive = true
        roundState.stakeDebited = false
        roundState.stake = selectedStake
        roundState.currentLevel = 0
        try? context.save()

        guard wallet.debit(selectedStake) else {
            // Shouldn't happen since canAfford was just checked, but never
            // leave a round marked active if the debit didn't actually go
            // through.
            roundState.reset()
            try? context.save()
            let message = "Nicht genug Soul Coins für diesen Einsatz."
            errorMessage = message
            state = .error(message: message)
            return
        }
        roundState.stakeDebited = true
        try? context.save()

        activeStake = selectedStake
        currentLevel = 0
        lastRoundPayout = 0
        state = .ready
    }

    /// Attempts to climb one rung. The outcome is rolled immediately, before
    /// any animation - `RiskLadderView` only plays back what already
    /// happened. Guarded by `state == .ready`, so it cannot fire again
    /// while a previous attempt is still animating.
    func risk() {
        guard canRisk else { return }
        state = .risking
        let succeeded = RiskLadderEngine.attemptClimb(
            fromLevel: currentLevel,
            configuration: levels,
            probabilityContext: probabilityContext,
            randomSource: &randomSource
        )
        Task { [weak self] in
            await self?.playOutcome(succeeded: succeeded)
        }
    }

    private func playOutcome(succeeded: Bool) async {
        await sleep(RiskLadderTiming.suspenseDuration)

        if succeeded {
            currentLevel += 1
            roundState.currentLevel = currentLevel
            try? context.save()

            if currentLevel >= maxLevel {
                await settleRound(outcomeState: .jackpot, reachedJackpot: true)
                return
            }

            state = .wonLevel
            await sleep(RiskLadderTiming.levelWinFlashDuration)
            state = .ready
        } else {
            await settleRound(outcomeState: .lost, reachedJackpot: false)
        }
    }

    /// Credits whatever `currentLevel` is worth and ends the round. Guarded
    /// by `state == .ready && currentLevel > 0`; `state` is moved off
    /// `.ready` *synchronously*, before the `Task` even starts, so two
    /// rapid taps can't both pass the guard and pay out twice - the same
    /// reason `risk()` sets `state = .risking` before its own `Task`.
    func cashOut() {
        guard canCashOut else { return }
        state = .cashedOut
        Task { [weak self] in
            await self?.settleRound(outcomeState: .cashedOut, reachedJackpot: false)
        }
    }

    /// Pays out (or not, for a loss), records statistics, resets the
    /// persisted round state, and shows the terminal result briefly before
    /// returning to `.idle`. Called for exactly one of loss/cash-out/
    /// jackpot per round, and only ever once per round: it's reached either
    /// from `risk()` (loss/jackpot) or `cashOut()`, both of which already
    /// guard on the round still being active before getting here.
    private func settleRound(outcomeState: RiskLadderState, reachedJackpot: Bool) async {
        let payout = RiskLadderEngine.payout(stake: activeStake, level: currentLevel, configuration: levels)
        if payout > 0 {
            wallet.credit(payout)
        }
        let multiplierPercent: Int64? = currentLevel > 0 ? RiskLadderEngine.multiplierPercent(level: currentLevel, configuration: levels) : nil
        statistics.record(wager: activeStake, payout: payout, triggeredBonus: reachedJackpot, multiplierPercent: multiplierPercent)
        wallet.awardXP(activeStake)

        roundState.reset()
        try? context.save()

        lastRoundPayout = payout
        state = outcomeState
        await sleep(RiskLadderTiming.resultDisplayDuration)

        currentLevel = 0
        activeStake = 0
        state = .idle
    }

    private func sleep(_ seconds: Double) async {
        guard seconds > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
