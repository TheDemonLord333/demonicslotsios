//
//  BetTier.swift
//  DemonicSlots
//
//  One milestone in the global bet-limit ladder: reaching `minimumLevel`
//  unlocks `maxBet`. Kept as its own small table (see
//  `PlayerLevelConfiguration.betTiers`), deliberately sparse - the whole
//  point is that the limit does NOT rise on every single level, only at a
//  tier's threshold, staying flat in between.
//
import Foundation

nonisolated struct BetTier: Codable, Hashable, Sendable, Identifiable {
    let minimumLevel: Int
    let maxBet: Int64

    var id: Int { minimumLevel }
}
