//
//  CasinoGameKind.swift
//  DemonicSlots
//
//  `SlotGameDefinition` doubles as the catalog entry for every game in
//  `GameRegistry`, slot machine or not - most of its fields (reels,
//  paylines, symbols, wild/scatter, free-spin rules) only mean something
//  for `.slotMachine`. `kind` is what `CollectionView`'s single navigation
//  stack reads to route a tapped card to the right feature view
//  (`SlotMachineView` vs. `RiskLadderView`) without a second, parallel
//  navigation system.
//
import Foundation

nonisolated enum CasinoGameKind: String, Codable, Hashable, Sendable {
    case slotMachine
    case riskLadder
}
