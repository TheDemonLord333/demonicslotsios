//
//  TestSupport.swift
//  DemonicSlotsTests
//
//  Shared test helpers: a scripted random source for fully deterministic
//  spins, and small definition builders.
//
import Foundation
@testable import DemonicSlots

/// A `RandomNumberSource` that returns a caller-supplied sequence of exact
/// values (one per call) instead of anything random. Lets tests pin down
/// every reel's stop index precisely.
struct ScriptedRandomSource: RandomNumberSource {
    private let values: [Int]
    private var index = 0

    init(values: [Int]) {
        self.values = values
    }

    mutating func nextInt(in range: Range<Int>) -> Int {
        defer { index += 1 }
        guard index < values.count else { return range.lowerBound }
        let value = values[index]
        return range.contains(value) ? value : range.lowerBound
    }
}

enum TestSupport {
    /// Builds a definition identical to Infernal Forge except each reel's
    /// strip is replaced by an exact 3-row column the caller specifies.
    /// Paired with `ScriptedRandomSource(values: [0, 0, 0, 0, 0])` (stop
    /// index 0 everywhere), `grid[reel][row]` lands exactly as given.
    static func infernalForgeVariant(grid: [[SymbolID]]) -> SlotGameDefinition {
        var definition = InfernalForgeDefinition.definition
        definition.reelStrips = grid
        return definition
    }

    static func zeroStops(count: Int) -> ScriptedRandomSource {
        ScriptedRandomSource(values: Array(repeating: 0, count: count))
    }

    /// A minimal, independent game definition used to prove a second game
    /// can be registered and spun without any change to the shared engine.
    static func makeMockDefinition(id: String = "mock_game") -> SlotGameDefinition {
        let cherry = SymbolID("mock.cherry")
        let bell = SymbolID("mock.bell")
        let symbols = [
            SlotSymbol(id: cherry, displayName: "Cherry", kind: .regular, assetKey: "mock.cherry", systemImageFallback: "circle.fill", tintColorKey: "hellfireRed"),
            SlotSymbol(id: bell, displayName: "Bell", kind: .regular, assetKey: "mock.bell", systemImageFallback: "bell.fill", tintColorKey: "emberOrange"),
        ]
        let reelStrips: [[SymbolID]] = [[cherry, bell], [cherry, bell], [cherry, bell]]
        let payline = Payline(id: 1, rowIndices: [0, 0, 0])
        let paytable = [
            PaytableEntry(symbolID: cherry, payoutByMatchCount: [3: 4]),
            PaytableEntry(symbolID: bell, payoutByMatchCount: [3: 6]),
        ]
        return SlotGameDefinition(
            id: GameID(id),
            displayName: "Mock Game",
            shortDescription: "Test-only game",
            availability: .available,
            theme: InfernalForgeDefinition.theme,
            symbols: symbols,
            reelStrips: reelStrips,
            visibleRows: 1,
            paylines: [payline],
            paytable: paytable,
            betLevels: [BetLevel(perLine: 1)],
            wildSymbolID: nil,
            scatterSymbolID: nil,
            freeSpinsRules: nil,
            cardAssetKey: "mock.card",
            audioKeys: InfernalForgeDefinition.audioKeys,
            animationKeys: InfernalForgeDefinition.animationKeys
        )
    }
}
