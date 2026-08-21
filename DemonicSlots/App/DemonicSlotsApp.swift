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
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            CollectionView()
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            // Opportunistic account sync on every foreground - a silent
            // no-op offline or without a registered online profile, see
            // AccountSyncController/BackendSyncService.
            let context = sharedModelContainer.mainContext
            let wallet = WalletService(context: context)
            let sync = AccountSyncController(context: context, wallet: wallet)
            Task { await sync.syncSilently() }
        }
    }
}
