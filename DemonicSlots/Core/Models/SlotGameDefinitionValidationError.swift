//
//  SlotGameDefinitionValidationError.swift
//  DemonicSlots
//
//  A malformed `SlotGameDefinition` (bad symbol IDs, invalid paylines,
//  missing reels, ...) must never crash the app. `validate()` collects every
//  problem it finds so the engine/UI can refuse to run the game and show a
//  clear error instead.
//

import Foundation

nonisolated enum SlotGameDefinitionValidationError: Error, Hashable, Sendable, LocalizedError {
    case noReels
    case reelStripEmpty(reelIndex: Int)
    case noPaylines
    case duplicatePaylineID(Int)
    case paylineLengthMismatch(paylineID: Int, expected: Int, found: Int)
    case paylineRowOutOfBounds(paylineID: Int, row: Int, visibleRows: Int)
    case noSymbols
    case duplicateSymbolID(SymbolID)
    case unknownSymbolInReelStrip(SymbolID, reelIndex: Int)
    case unknownSymbolInPaytable(SymbolID)
    case noPaytableEntries
    case invalidPaytableMatchCount(symbolID: SymbolID, matchCount: Int)
    case nonPositivePaytableMultiplier(symbolID: SymbolID, matchCount: Int)
    case noBetLevels
    case nonPositiveBetLevel(Int64)
    case unknownWildSymbol(SymbolID)
    case unknownScatterSymbol(SymbolID)
    case wildEqualsScatter(SymbolID)
    case scatterMissingFreeSpinsRules
    case invalidFreeSpinsRules(reason: String)

    var errorDescription: String? {
        switch self {
        case .noReels:
            return "The game defines no reel strips."
        case .reelStripEmpty(let reelIndex):
            return "Reel \(reelIndex) has an empty strip."
        case .noPaylines:
            return "The game defines no paylines."
        case .duplicatePaylineID(let id):
            return "Payline id \(id) is defined more than once."
        case .paylineLengthMismatch(let paylineID, let expected, let found):
            return "Payline \(paylineID) has \(found) row entries, expected \(expected) (one per reel)."
        case .paylineRowOutOfBounds(let paylineID, let row, let visibleRows):
            return "Payline \(paylineID) references row \(row), but only \(visibleRows) rows are visible."
        case .noSymbols:
            return "The game defines no symbols."
        case .duplicateSymbolID(let id):
            return "Symbol id \(id.rawValue) is defined more than once."
        case .unknownSymbolInReelStrip(let id, let reelIndex):
            return "Reel \(reelIndex) references unknown symbol \(id.rawValue)."
        case .unknownSymbolInPaytable(let id):
            return "Paytable references unknown symbol \(id.rawValue)."
        case .noPaytableEntries:
            return "The game defines no paytable entries."
        case .invalidPaytableMatchCount(let symbolID, let matchCount):
            return "Paytable entry for \(symbolID.rawValue) has an invalid match count \(matchCount)."
        case .nonPositivePaytableMultiplier(let symbolID, let matchCount):
            return "Paytable entry for \(symbolID.rawValue) at \(matchCount) matches has a non-positive multiplier."
        case .noBetLevels:
            return "The game defines no bet levels."
        case .nonPositiveBetLevel(let value):
            return "Bet level \(value) must be positive."
        case .unknownWildSymbol(let id):
            return "Wild symbol \(id.rawValue) is not part of the symbol list."
        case .unknownScatterSymbol(let id):
            return "Scatter symbol \(id.rawValue) is not part of the symbol list."
        case .wildEqualsScatter(let id):
            return "Symbol \(id.rawValue) cannot be both wild and scatter."
        case .scatterMissingFreeSpinsRules:
            return "A scatter symbol is defined but free spin rules are missing."
        case .invalidFreeSpinsRules(let reason):
            return "Free spin rules are invalid: \(reason)"
        }
    }
}
