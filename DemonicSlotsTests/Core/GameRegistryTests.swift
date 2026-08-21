//
//  GameRegistryTests.swift
//  DemonicSlotsTests
//
//  Covers requirement 15: a second, ad-hoc game can be registered and
//  played through the shared engine without any change to `SlotEngine`,
//  `PaylineEvaluator` or `ScatterEvaluator`.
//
import Testing
@testable import DemonicSlots

@MainActor
struct GameRegistryTests {
    @Test func builtInGamesAreRegisteredByDefault() {
        let registry = GameRegistry(registerBuiltIns: true)
        #expect(registry.definition(for: InfernalForgeDefinition.gameID) != nil)
        #expect(registry.availableDefinitions.contains { $0.id == InfernalForgeDefinition.gameID })
    }

    @Test func secondMockGameCanBeRegisteredAndSpunWithoutEngineChanges() throws {
        let registry = GameRegistry(registerBuiltIns: false)
        #expect(registry.allDefinitions.isEmpty)

        let mockDefinition = TestSupport.makeMockDefinition()
        registry.register(definition: mockDefinition)

        #expect(registry.definition(for: mockDefinition.id) != nil)
        #expect(registry.allDefinitions.count == 1)
        #expect(mockDefinition.isValid)

        let engine = SlotEngine(plugin: registry.plugin(for: mockDefinition.id))
        var random: any RandomNumberSource = SeededRandomSource(seed: 11)
        let evaluation = try engine.spin(
            definition: mockDefinition,
            betPerLine: 1,
            isFreeSpin: false,
            freeSpinMultiplier: 1,
            randomSource: &random
        )
        #expect(evaluation.totalPayout >= 0)
    }

    @Test func registeringTwoGamesKeepsThemIndependent() {
        let registry = GameRegistry(registerBuiltIns: false)
        registry.register(definition: TestSupport.makeMockDefinition(id: "mock_one"))
        registry.register(definition: TestSupport.makeMockDefinition(id: "mock_two"))
        #expect(registry.allDefinitions.count == 2)
        #expect(registry.definition(for: "mock_one")?.id == GameID("mock_one"))
        #expect(registry.definition(for: "mock_two")?.id == GameID("mock_two"))
    }
}
