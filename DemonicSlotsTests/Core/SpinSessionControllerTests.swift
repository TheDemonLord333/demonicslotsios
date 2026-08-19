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
