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

    var showFirstLaunchDisclaimer: Bool

    init(context: ModelContext, registry: GameRegistry = .shared) {
        self.context = context
        self.registry = registry
        self.wallet = WalletService(context: context)
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
