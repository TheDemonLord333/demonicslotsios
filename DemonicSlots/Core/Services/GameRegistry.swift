//
//  GameRegistry.swift
//  DemonicSlots
//
//  Central catalog of every slot game the app knows about. The collection
//  screen reads its cards from here - it never hard-codes "Infernal Forge"
//  or any other game. Adding a game means authoring a `SlotGameDefinition`
//  (plus an optional `SlotGamePlugin` for bespoke bonus mechanics) and
//  registering it here; nothing about the shared engine or navigation
//  changes.
//
import Foundation

@MainActor
final class GameRegistry {
    /// Shared instance used by the running app.
    static let shared = GameRegistry()

    private var definitionsByID: [GameID: SlotGameDefinition] = [:]
    private var pluginsByID: [GameID: any SlotGamePlugin] = [:]
    private(set) var orderedGameIDs: [GameID] = []

    /// `registerBuiltIns: false` gives tests an empty registry so they can
    /// verify a second, ad-hoc game can be registered and played without any
    /// engine changes.
    init(registerBuiltIns: Bool = true) {
        guard registerBuiltIns else { return }
        register(definition: InfernalForgeDefinition.definition)
        register(definition: RiskLadderDefinition.definition)
        for placeholder in ComingSoonGames.placeholders {
            register(definition: placeholder)
        }
    }

    func register(definition: SlotGameDefinition, plugin: (any SlotGamePlugin)? = nil) {
        definitionsByID[definition.id] = definition
        pluginsByID[definition.id] = plugin ?? StandardSlotGamePlugin(gameID: definition.id)
        if !orderedGameIDs.contains(definition.id) {
            orderedGameIDs.append(definition.id)
        }
    }

    func definition(for id: GameID) -> SlotGameDefinition? {
        definitionsByID[id]
    }

    func plugin(for id: GameID) -> (any SlotGamePlugin)? {
        pluginsByID[id]
    }

    var allDefinitions: [SlotGameDefinition] {
        orderedGameIDs.compactMap { definitionsByID[$0] }
    }

    var availableDefinitions: [SlotGameDefinition] {
        allDefinitions.filter { $0.availability == .available }
    }
}
