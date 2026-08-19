//
//  SettingsPersistenceTests.swift
//  DemonicSlotsTests
//
//  Covers requirement 14: settings and the last-selected bet level persist.
//
import SwiftData
import Testing
@testable import DemonicSlots

@MainActor
struct SettingsPersistenceTests {
    @Test func userSettingsPersistAcrossFetches() throws {
        let container = PersistenceController.makeInMemoryModelContainer()
        let context = ModelContext(container)

        let settings = ProfileStore.fetchOrCreateSettings(in: context)
        settings.isAudioEnabled = false
        settings.isMusicEnabled = false
        settings.isHapticsEnabled = false
        settings.prefersReducedMotion = true
        try context.save()

        let refetched = ProfileStore.fetchOrCreateSettings(in: context)
        #expect(refetched.isAudioEnabled == false)
        #expect(refetched.isMusicEnabled == false)
        #expect(refetched.isHapticsEnabled == false)
        #expect(refetched.prefersReducedMotion == true)
    }

    @Test func onlyOneSettingsRowIsEverCreated() throws {
        let container = PersistenceController.makeInMemoryModelContainer()
        let context = ModelContext(container)

        _ = ProfileStore.fetchOrCreateSettings(in: context)
        _ = ProfileStore.fetchOrCreateSettings(in: context)
        try context.save()

        let all = try context.fetch(FetchDescriptor<UserSettings>())
        #expect(all.count == 1)
    }

    @Test func lastSelectedBetLevelPersistsPerGame() throws {
        let container = PersistenceController.makeInMemoryModelContainer()
        let context = ModelContext(container)

        let progress = ProfileStore.fetchOrCreateProgress(for: InfernalForgeDefinition.gameID, in: context)
        progress.lastBetPerLine = 25
        try context.save()

        let refetched = ProfileStore.fetchOrCreateProgress(for: InfernalForgeDefinition.gameID, in: context)
        #expect(refetched.lastBetPerLine == 25)
    }

    @Test func spinSessionControllerRestoresTheLastSelectedBetLevel() {
        let container = PersistenceController.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let definition = InfernalForgeDefinition.definition

        let progress = ProfileStore.fetchOrCreateProgress(for: definition.id, in: context)
        progress.lastBetPerLine = 10
        try? context.save()

        let controller = SpinSessionController(definition: definition, plugin: nil, context: context)
        #expect(controller.selectedBetPerLine == 10)
    }
}
