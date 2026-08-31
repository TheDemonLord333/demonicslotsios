//
//  RiskLadderSessionControllerTests.swift
//  DemonicSlotsTests
//
//  Covers the Demonic Risk Ladder equivalents of the slot's transaction-
//  safety requirements: the stake is debited exactly once, a win/loss/
//  jackpot pays out exactly once, insufficient funds blocks the start, a
//  rapid double-tap can't double-process, and a simulated relaunch mid-round
//  can't duplicate a stake refund or a payout.
//
import Foundation
import SwiftData
import Testing
@testable import DemonicSlots

@MainActor
struct RiskLadderSessionControllerTests {
    private func makeContext() -> ModelContext {
        ModelContext(PersistenceController.makeInMemoryModelContainer())
    }

    /// A tiny 2-rung configuration (rung 2 is the jackpot) so tests that
    /// need to reach the top don't have to wait through nine real climb
    /// animations.
    private let shortLevels: [RiskLevel] = [
        RiskLevel(level: 1, multiplier: 2, successProbability: 0.5, isJackpot: false),
        RiskLevel(level: 2, multiplier: 5, successProbability: 0.5, isJackpot: true),
    ]

    private func sleepPast(_ seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64((seconds + 0.5) * 1_000_000_000))
    }

    @Test func startingARoundDebitsTheStakeExactlyOnce() {
        let context = makeContext()
        let definition = RiskLadderDefinition.definition
        let controller = RiskLadderSessionController(definition: definition, context: context)
        let startBalance = controller.wallet.balance
        let stake = controller.selectedStake

        controller.startRound()
        #expect(controller.wallet.balance == startBalance - stake)

        // Rapid repeated taps: state is already `.ready`, so every further
        // call is a no-op - never a second debit.
        controller.startRound()
        controller.startRound()
        #expect(controller.wallet.balance == startBalance - stake)
        #expect(controller.activeStake == stake)
    }

    @Test func insufficientFundsPreventsStartAndNeverDebits() {
        let context = makeContext()
        let definition = RiskLadderDefinition.definition
        let controller = RiskLadderSessionController(definition: definition, context: context)
        _ = controller.wallet.debit(controller.wallet.balance) // drain to zero

        controller.startRound()

        #expect(controller.wallet.balance == 0)
        #expect(controller.state == .error(message: "Nicht genug Soul Coins für diesen Einsatz."))
        #expect(controller.activeStake == 0)
    }

    @Test func successfulClimbIncreasesLevelAndComputesTheConfiguredMultiplier() async throws {
        let context = makeContext()
        let definition = RiskLadderDefinition.definition
        let random: any RandomNumberSource = ScriptedRandomSource(values: [0]) // always succeeds
        let controller = RiskLadderSessionController(definition: definition, context: context, randomSource: random, levels: shortLevels)
        controller.startRound()
        let stake = controller.activeStake

        controller.risk()
        #expect(controller.state == .risking) // locked immediately, before the outcome even reveals
        try await sleepPast(RiskLadderTiming.suspenseDuration + RiskLadderTiming.levelWinFlashDuration)

        #expect(controller.currentLevel == 1)
        #expect(controller.currentMultiplier == 2)
        #expect(controller.currentPayout == stake * 2)
        #expect(controller.state == .ready)
    }

    @Test func lossEndsTheRoundAndPaysOutNothing() async throws {
        let context = makeContext()
        let definition = RiskLadderDefinition.definition
        let random: any RandomNumberSource = ScriptedRandomSource(values: [999_999]) // always fails
        let controller = RiskLadderSessionController(definition: definition, context: context, randomSource: random, levels: shortLevels)
        let startBalance = controller.wallet.balance
        controller.startRound()
        let stake = controller.activeStake

        controller.risk()
        #expect(controller.state == .risking)
        try await sleepPast(RiskLadderTiming.suspenseDuration + RiskLadderTiming.resultDisplayDuration)

        #expect(controller.state == .idle)
        #expect(controller.lastRoundPayout == 0)
        // The stake was already taken at start and is never refunded on a loss.
        #expect(controller.wallet.balance == startBalance - stake)
    }

    @Test func cashOutPaysExactlyOnceEvenWithARapidDoubleTap() async throws {
        let context = makeContext()
        let definition = RiskLadderDefinition.definition
        let random: any RandomNumberSource = ScriptedRandomSource(values: [0]) // one guaranteed successful climb
        let controller = RiskLadderSessionController(definition: definition, context: context, randomSource: random, levels: shortLevels)
        let startBalance = controller.wallet.balance
        controller.startRound()
        let stake = controller.activeStake

        controller.risk()
        try await sleepPast(RiskLadderTiming.suspenseDuration + RiskLadderTiming.levelWinFlashDuration)
        #expect(controller.currentLevel == 1)

        let expectedPayout = stake * 2 // level 1 multiplier in shortLevels
        controller.cashOut()
        // Immediately locked out - a second rapid tap must be a no-op, not
        // a second payout.
        controller.cashOut()
        controller.cashOut()

        try await sleepPast(RiskLadderTiming.resultDisplayDuration)

        #expect(controller.state == .idle)
        #expect(controller.wallet.balance == startBalance - stake + expectedPayout)
    }

    @Test func reachingTheTopRungAutoPaysTheJackpotExactlyOnce() async throws {
        let context = makeContext()
        let definition = RiskLadderDefinition.definition
        let random: any RandomNumberSource = ScriptedRandomSource(values: [0, 0]) // two guaranteed successful climbs
        let controller = RiskLadderSessionController(definition: definition, context: context, randomSource: random, levels: shortLevels)
        let startBalance = controller.wallet.balance
        controller.startRound()
        let stake = controller.activeStake

        controller.risk() // -> level 1
        try await sleepPast(RiskLadderTiming.suspenseDuration + RiskLadderTiming.levelWinFlashDuration)
        #expect(controller.state == .ready)

        controller.risk() // -> level 2, the jackpot rung: auto-settles
        try await sleepPast(RiskLadderTiming.suspenseDuration + RiskLadderTiming.resultDisplayDuration)

        let expectedPayout = stake * 5 // jackpot multiplier in shortLevels
        #expect(controller.state == .idle)
        #expect(controller.wallet.balance == startBalance - stake + expectedPayout)
    }

    @Test func riskCannotFireAgainWhileAPreviousAttemptIsStillAnimating() async throws {
        let context = makeContext()
        let definition = RiskLadderDefinition.definition
        let random: any RandomNumberSource = ScriptedRandomSource(values: [0, 0, 0]) // would succeed every time, if called
        let controller = RiskLadderSessionController(definition: definition, context: context, randomSource: random, levels: shortLevels)
        controller.startRound()

        controller.risk()
        let stateRightAfterFirstTap = controller.state
        // Rapid repeated taps before the first attempt settles.
        controller.risk()
        controller.risk()
        controller.risk()
        #expect(controller.state == stateRightAfterFirstTap)

        try await sleepPast(RiskLadderTiming.suspenseDuration + RiskLadderTiming.levelWinFlashDuration)
        // Only one climb happened, not four.
        #expect(controller.currentLevel == 1)
    }

    @Test func relaunchingMidRoundResumesWithoutRefundingOrReDebitingTheStake() {
        let context = makeContext()
        let definition = RiskLadderDefinition.definition
        let firstController = RiskLadderSessionController(definition: definition, context: context, levels: shortLevels)
        let startBalance = firstController.wallet.balance
        firstController.startRound()
        let stake = firstController.activeStake
        let balanceAfterStart = firstController.wallet.balance
        #expect(balanceAfterStart == startBalance - stake)

        // Simulate the app being killed and relaunched: a brand-new
        // controller instance reads the same persisted `ModelContext`.
        let secondController = RiskLadderSessionController(definition: definition, context: context, levels: shortLevels)

        // The round resumed exactly where it left off - the stake was not
        // refunded, and starting a new round is correctly blocked since one
        // is already active.
        #expect(secondController.state == .ready)
        #expect(secondController.activeStake == stake)
        #expect(secondController.currentLevel == 0)
        #expect(secondController.wallet.balance == balanceAfterStart)
        #expect(!secondController.canStart)
    }

    @Test func aRoundNeverActuallyDebitedLeavesNothingToRecoverOnRelaunch() {
        let context = makeContext()
        let definition = RiskLadderDefinition.definition
        // Simulate the narrow crash window: `isActive` was saved but the
        // debit itself never completed (`stakeDebited` stayed false).
        let roundState = ProfileStore.fetchOrCreateRiskLadderRoundState(for: definition.id, in: context)
        roundState.isActive = true
        roundState.stakeDebited = false
        roundState.stake = 500
        try? context.save()

        let wallet = WalletService(context: context)
        let startBalance = wallet.balance

        let controller = RiskLadderSessionController(definition: definition, context: context, levels: shortLevels)

        #expect(controller.state == .idle)
        #expect(controller.canStart)
        #expect(wallet.balance == startBalance) // nothing was ever charged
    }
}
