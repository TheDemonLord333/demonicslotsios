//
//  PersistenceController.swift
//  DemonicSlots
//
//  Builds the single `ModelContainer` shared by the whole app, and provides
//  fetch-or-create helpers for the app's singleton rows (`PlayerProfile`,
//  `UserSettings`) and per-game rows (`GameProgress`, `GameStatistics`).
//
import Foundation
import SwiftData

enum PersistenceController {
    static var schema: Schema {
        Schema([
            PlayerProfile.self,
            GameProgress.self,
            GameStatistics.self,
            PendingSpin.self,
            UserSettings.self,
        ])
    }

    /// Production container, persisted to disk.
    static func makeModelContainer() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    /// In-memory container for previews and tests.
    static func makeInMemoryModelContainer() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create in-memory ModelContainer: \(error)")
        }
    }
}

@MainActor
enum ProfileStore {
    static func fetchOrCreateProfile(in context: ModelContext) -> PlayerProfile {
        let id = PlayerProfile.singletonID
        let descriptor = FetchDescriptor<PlayerProfile>(
            predicate: #Predicate { $0.profileID == id }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = PlayerProfile()
        context.insert(created)
        return created
    }

    static func fetchOrCreateSettings(in context: ModelContext) -> UserSettings {
        let id = UserSettings.singletonID
        let descriptor = FetchDescriptor<UserSettings>(
            predicate: #Predicate { $0.settingsID == id }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = UserSettings()
        context.insert(created)
        return created
    }

    static func fetchOrCreateProgress(for gameID: GameID, in context: ModelContext) -> GameProgress {
        let rawID = gameID.rawValue
        let descriptor = FetchDescriptor<GameProgress>(
            predicate: #Predicate { $0.gameID == rawID }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = GameProgress(gameID: rawID, lastBetPerLine: 0)
        context.insert(created)
        return created
    }

    static func fetchOrCreateStatistics(for gameID: GameID, in context: ModelContext) -> GameStatistics {
        let rawID = gameID.rawValue
        let descriptor = FetchDescriptor<GameStatistics>(
            predicate: #Predicate { $0.gameID == rawID }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = GameStatistics(gameID: rawID)
        context.insert(created)
        return created
    }
}
