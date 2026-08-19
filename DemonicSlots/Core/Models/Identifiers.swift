//
//  Identifiers.swift
//  DemonicSlots
//
//  Stable, type-safe identifiers used throughout the slot engine.
//  Wrapping raw strings keeps game/symbol IDs from being confused with
//  arbitrary text at the call site while still being trivially Codable.
//

import Foundation

/// Stable identifier for a slot game inside the `GameRegistry`.
nonisolated struct GameID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension GameID: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.rawValue = value
    }
}

extension GameID: CustomStringConvertible {
    var description: String { rawValue }
}

/// Stable identifier for a symbol within a single `SlotGameDefinition`.
/// Symbol IDs are only unique within their owning game.
nonisolated struct SymbolID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension SymbolID: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.rawValue = value
    }
}

extension SymbolID: CustomStringConvertible {
    var description: String { rawValue }
}
