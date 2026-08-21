//
//  BetLevel.swift
//  DemonicSlots
//

import Foundation

/// One selectable stake, expressed as Soul Coins wagered on each active
/// payline. Total stake for a spin is always `perLine * activeLineCount`.
nonisolated struct BetLevel: Codable, Hashable, Sendable, Identifiable {
    var perLine: Int64
    var id: Int64 { perLine }

    init(perLine: Int64) {
        self.perLine = perLine
    }
}
