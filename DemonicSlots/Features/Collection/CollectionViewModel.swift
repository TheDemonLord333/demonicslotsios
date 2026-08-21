//
//  CollectionViewModel.swift
//  DemonicSlots
//
//  Non-visual logic for the demonic hall / game collection screen: wallet
//  mutations (Soul Rescue) and the first-launch disclaimer flag. Balance
//  display itself is read reactively via `@Query` in `CollectionView` so it
//  always reflects live SwiftData state.
//
import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class CollectionViewModel {
    private let context: ModelContext
    let wallet: WalletService
    let registry: GameRegistry
    let accountSync: AccountSyncController

    var showFirstLaunchDisclaimer: Bool

    // `registry` defaults to `nil` rather than `= .shared` directly: default
    // parameter expressions are evaluated in a nonisolated context, so they
    // can't reference a MainActor-isolated static property. Resolving the
    // default inside the (MainActor) init body instead avoids that.
    init(context: ModelContext, registry: GameRegistry? = nil) {
        self.context = context
        self.registry = registry ?? .shared
        self.wallet = WalletService(context: context)
        self.accountSync = AccountSyncController(context: context, wallet: wallet)
        let profile = wallet.currentProfile()
        self.showFirstLaunchDisclaimer = !profile.hasSeenEntertainmentDisclaimer
        try? context.save()
    }

    var games: [SlotGameDefinition] { registry.allDefinitions }

    func acknowledgeDisclaimer() {
        let profile = wallet.currentProfile()
        profile.hasSeenEntertainmentDisclaimer = true
        try? context.save()
        showFirstLaunchDisclaimer = false
    }

    var isSoulRescueAvailable: Bool {
        wallet.isSoulRescueAvailable()
    }

    @discardableResult
    func claimSoulRescue() -> Bool {
        wallet.claimSoulRescue()
    }
}
