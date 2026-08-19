//
//  GameAvailability.swift
//  DemonicSlots
//

import Foundation

/// Whether a game listed in the collection can actually be opened yet.
nonisolated enum GameAvailability: String, Codable, Hashable, Sendable {
    case available
    case comingSoon
}
