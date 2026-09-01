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

        // Level 1 (the default) unlocks bets up to 100 - Infernal Forge's
        // own bet levels are 1/2/5/10/25, all well under that, so every one
        // of them should already be available and normal play is
        // unaffected by this feature.
        #expect(controller.availableBetLevels.map(\.perLine) == definition.betLevels.map(\.perLine))
        #expect(controller.lockedBetLevels.isEmpty)
    }

    @Test func aPlayerCannotSelectOrSpinABetAboveTheirCurrentLevelLimit() {
        let context = makeContext()
        let definition = TestSupport.makeMockDefinition() // bet levels: [1]... extend below
        var widerDefinition = definition
        widerDefinition.betLevels = [BetLevel(perLine: 1), BetLevel(perLine: 1_000)]
        let controller = SpinSessionController(definition: widerDefinition, plugin: nil, context: context)

        // Level 1's global max bet is 100, so this game's own 1,000-coin
        // bet level is not actually selectable yet.
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
}
