//
//  PaytableEntry.swift
//  DemonicSlots
//

import Foundation

/// Payout multipliers for one symbol, keyed by the number of matching
/// symbols in a payline run (3, 4, 5, ...). Values are whole-number
/// multipliers of the *per-line* bet, e.g. `3 -> 2` means "3 of a kind pays
/// 2x the bet per line".
nonisolated struct PaytableEntry: Codable, Equatable, Sendable {
    var symbolID: SymbolID
    var payoutByMatchCount: [Int: Int64]

    init(symbolID: SymbolID, payoutByMatchCount: [Int: Int64]) {
        self.symbolID = symbolID
        self.payoutByMatchCount = payoutByMatchCount
    }

    func multiplier(forMatchCount count: Int) -> Int64? {
        payoutByMatchCount[count]
    }
}
