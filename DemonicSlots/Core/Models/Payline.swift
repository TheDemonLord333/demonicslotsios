//
//  Payline.swift
//  DemonicSlots
//

import Foundation

/// One fixed payline expressed as the visible row index used on every reel,
/// left to right. Row `0` is the top row.
nonisolated struct Payline: Codable, Hashable, Sendable, Identifiable {
    var id: Int
    var rowIndices: [Int]

    init(id: Int, rowIndices: [Int]) {
        self.id = id
        self.rowIndices = rowIndices
    }
}
