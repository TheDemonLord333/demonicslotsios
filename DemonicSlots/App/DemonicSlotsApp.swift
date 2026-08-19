//
//  DemonicSlotsApp.swift
//  DemonicSlots
//
//  App entry point. The root view is the demonic hall (`CollectionView`),
//  not a slot machine - see Features/Collection.
//
import SwiftUI
import SwiftData

@main
struct DemonicSlotsApp: App {
    let sharedModelContainer: ModelContainer = PersistenceController.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            CollectionView()
        }
        .modelContainer(sharedModelContainer)
    }
}
