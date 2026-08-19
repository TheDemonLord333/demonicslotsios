//
//  SlotSymbol.swift
//  DemonicSlots
//

import Foundation

/// The role a symbol plays during evaluation.
nonisolated enum SymbolKind: String, Codable, Hashable, Sendable {
    case regular
    case wild
    case scatter
}

/// Declarative description of one symbol belonging to a `SlotGameDefinition`.
///
/// `assetKey` and `tintColorKey` are stable lookup keys, not literal asset
/// catalog names. The rendering layer resolves them to either a real asset
/// (once art exists) or a SwiftUI placeholder shape/SF Symbol, so a missing
/// asset never crashes the app.
nonisolated struct SlotSymbol: Codable, Hashable, Sendable, Identifiable {
    var id: SymbolID
    var displayName: String
    var kind: SymbolKind
    /// Lookup key for the symbol's artwork (asset catalog name or placeholder key).
    var assetKey: String
    /// SF Symbol fallback shown when no artwork exists for `assetKey`.
    var systemImageFallback: String
    /// Key into `DemonicPalette` used to tint the placeholder representation.
    var tintColorKey: String

    init(
        id: SymbolID,
        displayName: String,
        kind: SymbolKind,
        assetKey: String,
        systemImageFallback: String,
        tintColorKey: String
    ) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.assetKey = assetKey
        self.systemImageFallback = systemImageFallback
        self.tintColorKey = tintColorKey
    }
}
