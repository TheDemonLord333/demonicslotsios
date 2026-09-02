//
//  SpinSessionControllerTests.swift
//  DemonicSlotsTests
//
//  Covers requirement 11: rapid repeated taps on Spin must never start a
//  second spin or produce a double charge.
//
import Foundation
import SwiftData
import Testing
@testable import DemonicSlots

@MainActor
struct SpinSessionControllerTests {
    private func makeContext() -> ModelContext {
        ModelContext(PersistenceController.makeInMemoryModelContainer())
    }

    @Test func rapidRepeatedTapsOnlyStartOneSpinAndDebitOnce() async throws {
        let context = makeContext()
        let definition = InfernalForgeDefinition.definition
        let controller = SpinSessionController(
            definition: definition,
            plugin: nil,
            context: context,
            randomSource: SeededRandomSource(seed: 3)
        )

        let startBalance = controller.wallet.balance
        let totalBet = definition.totalBet(betPerLine: controller.selectedBetPerLine)

        #expect(controller.canSpin)
        controller.spin()
        #expect(!controller.canSpin) // the button must already be disabled

        let stateRightAfterFirstTap = controller.state
        // Simulate several more rapid taps before the first spin settles.
        controller.spin()
        controller.spin()
        controller.spin()
        #expect(controller.state == stateRightAfterFirstTap) // no-ops, nothing changed

        // The stake for a single spin was withdrawn exactly once.
        #expect(controller.wallet.balance == startBalance - totalBet)

        // Let the animation sequence run to completion.
        try await Task.sleep(nanoseconds: 6_000_000_000)

        #expect(controller.canSpin)
        // Balance only ever reflects one spin's stake and payout, never more.
        let expectedBalance = startBalance - totalBet + controller.lastWinAmount
        #expect(controller.wallet.balance == expectedBalance)
    }

    @Test func betSelectionIsRestrictedToWhatThePlayersLevelUnlocks() {
        let context = makeContext()
        let definition = InfernalForgeDefinition.definition
        let controller = SpinSessionController(definition: definition, plugin: nil, context: context)

        // Level 1 (the default) unlocks a total bet up to 250 Soul Coins -
        // `InfernalForgeDefinition.betTierStartIndex`'s stake-ladder value,
        // unchanged from the game's own long-standing top bet. The
        // original 5 hand-picked bet levels (perLine 1/2/5/10/25 - up to
        // 250 total across the game's 10 paylines) all fit under that and
        // stay available; `betLevels` also now carries the higher tiers
        // that levels 10/20/... unlock, which aren't yet.
        let originalBetLevels: [Int64] = [1, 2, 5, 10, 25]
        #expect(controller.availableBetLevels.map(\.perLine) == originalBetLevels)
        #expect(!controller.lockedBetLevels.isEmpty)
        #expect(controller.lockedBetLevels.allSatisfy { !originalBetLevels.contains($0.bet.perLine) })
    }

    @Test func aPlayerCannotSelectOrSpinABetAboveTheirCurrentLevelLimit() {
        let context = makeContext()
        let definition = TestSupport.makeMockDefinition() // bet levels: [1]... extend below
        var widerDefinition = definition
        widerDefinition.betLevels = [BetLevel(perLine: 1), BetLevel(perLine: 1_000)]
        let controller = SpinSessionController(definition: widerDefinition, plugin: nil, context: context)

        // The mock definition doesn't opt into a higher `betTierStartIndex`,
        // so its level-1 max total bet is the stake ladder's own floor
        // (10 Soul Coins) - this game's own 1,000-coin bet level is nowhere
        // near that and isn't selectable yet.
        #expect(!controller.availableBetLevels.contains { $0.perLine == 1_000 })
        controller.selectBet(perLine: 1_000)
        #expect(controller.selectedBetPerLine != 1_000)
        #expect(controller.lockedBetLevels.contains { $0.bet.perLine == 1_000 })
    }

    @Test func spinRefusesALockedBetEvenIfSomehowSelectedDirectly() {
        let context = makeContext()
        let definition = TestSupport.makeMockDefinition()
        var widerDefinition = definition
        widerDefinition.betLevels = [BetLevel(perLine: 1), BetLevel(perLine: 1_000)]
        let controller = SpinSessionController(definition: widerDefinition, plugin: nil, context: context)
        let startBalance = controller.wallet.balance

        // Bypass `selectBet`'s own guard entirely (simulating some future
        // code path that sets the property directly) - `spin()` must still
        // catch it with its own independent re-check before any money moves.
        controller.selectedBetPerLine = 1_000
        controller.spin()

        #expect(controller.wallet.balance == startBalance) // nothing was ever debited
        if case .error = controller.state {
            // expected
        } else {
            Issue.record("Expected spin() to refuse a locked bet with an error state, got \(controller.state)")
        }
    }

    @Test func betCanOnlyBeChangedWhileIdle() {
        let context = makeContext()
        let definition = InfernalForgeDefinition.definition
        let controller = SpinSessionController(definition: definition, plugin: nil, context: context)

        let originalBet = controller.selectedBetPerLine
        let otherLevel = definition.betLevels.first { $0.perLine != originalBet }!.perLine

        controller.selectBet(perLine: otherLevel)
        #expect(controller.selectedBetPerLine == otherLevel)

        controller.spin()
        let duringSpinLevel = controller.selectedBetPerLine
        controller.selectBet(perLine: originalBet) // must be ignored while not idle
        #expect(controller.selectedBetPerLine == duringSpinLevel)
    }

    // MARK: - Autospin (hold-to-engage, tap-to-disengage)

    @Test func togglingAutoSpinOnQueuesASpinWithoutAnyManualSpinCall() async throws {
        let context = makeContext()
        let definition = TestSupport.makeMockDefinition() // single bet level: 1
        let controller = SpinSessionController(
            definition: definition,
            plugin: nil,
            context: context,
            randomSource: SeededRandomSource(seed: 20)
        )
        let startBalance = controller.wallet.balance

        controller.toggleAutoSpin()
        #expect(controller.isAutoSpinning)
        #expect(controller.canSpin) // still idle - the spin is queued, not immediate

        // Wait past the pause, one full spin sequence, and a generous
        // buffer for a possible celebration state.
        let reelCount = definition.reelCount
        let waitSeconds = SpinTiming.autoSpinPause + SpinTiming.spinDuration(reelCount: reelCount) + SpinTiming.settleDuration + 2.0
        try await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))

        // A spin fired on its own - the stake was debited (and possibly
        // paid back out) without a single explicit spin() call from this test.
        #expect(controller.wallet.balance != startBalance)
        #expect(controller.isAutoSpinning) // nothing failed, so it's still engaged
        #expect(controller.canSpin) // settled back to idle, ready for the next queued spin
    }

    @Test func tappingDuringTheAutoSpinPauseCancelsTheQueuedSpin() async throws {
        let context = makeContext()
        let definition = TestSupport.makeMockDefinition()
        let controller = SpinSessionController(
            definition: definition,
            plugin: nil,
            context: context,
            randomSource: SeededRandomSource(seed: 21)
        )
        let startBalance = controller.wallet.balance

        controller.toggleAutoSpin() // hold: engages, queues a spin after the pause
        #expect(controller.isAutoSpinning)
        controller.toggleAutoSpin() // tap, before the pause elapses: disengages again
        #expect(!controller.isAutoSpinning)

        // Wait past when the now-cancelled spin would have fired.
        let waitSeconds = SpinTiming.autoSpinPause + SpinTiming.spinDuration(reelCount: definition.reelCount) + 1.0
        try await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))

        #expect(!controller.isAutoSpinning)
        #expect(controller.state == .idle)
        #expect(controller.wallet.balance == startBalance) // the queued spin never actually ran
    }

    @Test func autoSpinDisengagesItselfWhenTheQueuedSpinsBetIsNoLongerUnlocked() async throws {
        let context = makeContext()
        let definition = TestSupport.makeMockDefinition()
        var widerDefinition = definition
        widerDefinition.betLevels = [BetLevel(perLine: 1), BetLevel(perLine: 1_000)]
        let controller = SpinSessionController(
            definition: widerDefinition,
            plugin: nil,
            context: context,
            randomSource: SeededRandomSource(seed: 22)
        )
        let startBalance = controller.wallet.balance

        controller.toggleAutoSpin()
        // Simulate the player's level (hence bet limit) dropping between
        // engaging autospin and its queued spin actually firing - same
        // race `spinRefusesALockedBetEvenIfSomehowSelectedDirectly` covers
        // for a single manual spin.
        controller.selectedBetPerLine = 1_000

        let waitSeconds = SpinTiming.autoSpinPause + 1.0
        try await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))

        #expect(!controller.isAutoSpinning) // spin()'s own guard turned it off
        #expect(controller.wallet.balance == startBalance) // nothing was ever debited
        if case .error = controller.state {
            // expected
        } else {
            Issue.record("Expected the queued autospin to refuse a locked bet with an error state, got \(controller.state)")
        }
    }

    @Test func dismissingAnErrorAlsoDisengagesAutoSpin() async throws {
        let context = makeContext()
        let definition = TestSupport.makeMockDefinition()
        var widerDefinition = definition
        widerDefinition.betLevels = [BetLevel(perLine: 1), BetLevel(perLine: 1_000)]
        let controller = SpinSessionController(
            definition: widerDefinition,
            plugin: nil,
            context: context,
            randomSource: SeededRandomSource(seed: 23)
        )

        controller.toggleAutoSpin()
        controller.selectedBetPerLine = 1_000
        let waitSeconds = SpinTiming.autoSpinPause + 1.0
        try await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))
        #expect(!controller.isAutoSpinning)

        // Even if something re-engaged it while the error was still showing,
        // dismissing the error must always leave autospin off.
        controller.selectedBetPerLine = 1 // back to a valid bet
        if case .error = controller.state {
            controller.dismissError()
        }
        #expect(controller.state == .idle)
        #expect(!controller.isAutoSpinning)
    }
}
