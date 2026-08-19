//
//  SlotGameDefinition.swift
//  DemonicSlots
//
//  Declarative, Codable description of one slot game: symbols, reel strips,
//  paylines, paytable, bet levels, wild/scatter roles, bonus rules and
//  theming/asset keys. The shared `SlotEngine` and every SwiftUI feature
//  view operate purely in terms of this struct, so a new slot game can be
//  added by authoring a new definition (plus, optionally, a `SlotGamePlugin`
//  for bespoke bonus mechanics) without touching the engine or navigation.
//
nonisolated struct SlotGameDefinition: Codable, Equatable, Sendable, Identifiable {
    var id: GameID
    var displayName: String
    var shortDescription: String
    var availability: GameAvailability
    var theme: GameTheme
    var symbols: [SlotSymbol]
    /// One strip of symbol IDs per reel, read cyclically.
    var reelStrips: [[SymbolID]]
    var visibleRows: Int
    var paylines: [Payline]
    var paytable: [PaytableEntry]
    /// Selectable per-line stakes, ascending.
    var betLevels: [BetLevel]
    var wildSymbolID: SymbolID?
    var scatterSymbolID: SymbolID?
    var freeSpinsRules: FreeSpinsRules?
    /// Lookup key for the game's card/portal artwork in the collection.
    var cardAssetKey: String
    var audioKeys: SlotAudioKeys
    var animationKeys: SlotAnimationKeys

    init(
        id: GameID,
        displayName: String,
        shortDescription: String,
        availability: GameAvailability,
        theme: GameTheme,
        symbols: [SlotSymbol],
        reelStrips: [[SymbolID]],
        visibleRows: Int,
        paylines: [Payline],
        paytable: [PaytableEntry],
        betLevels: [BetLevel],
        wildSymbolID: SymbolID?,
        scatterSymbolID: SymbolID?,
        freeSpinsRules: FreeSpinsRules?,
        cardAssetKey: String,
        audioKeys: SlotAudioKeys,
        animationKeys: SlotAnimationKeys
    ) {
        self.id = id
        self.displayName = displayName
        self.shortDescription = shortDescription
        self.availability = availability
        self.theme = theme
        self.symbols = symbols
        self.reelStrips = reelStrips
        self.visibleRows = visibleRows
        self.paylines = paylines
        self.paytable = paytable
        self.betLevels = betLevels
        self.wildSymbolID = wildSymbolID
        self.scatterSymbolID = scatterSymbolID
        self.freeSpinsRules = freeSpinsRules
        self.cardAssetKey = cardAssetKey
        self.audioKeys = audioKeys
        self.animationKeys = animationKeys
    }

    var reelCount: Int { reelStrips.count }

    var activeLineCount: Int { paylines.count }

    func symbol(for id: SymbolID) -> SlotSymbol? {
        symbols.first { $0.id == id }
    }

    func paytableEntry(for id: SymbolID) -> PaytableEntry? {
        paytable.first { $0.symbolID == id }
    }

    /// Total stake for a given per-line bet, across all active paylines.
    func totalBet(betPerLine: Int64) -> Int64 {
        betPerLine * Int64(activeLineCount)
    }

    // MARK: - Validation

    /// Collects every structural problem with this definition. An empty
    /// result means the definition is safe to hand to `SlotEngine`. Invalid
    /// symbol IDs, malformed paylines or missing reels are reported here
    /// rather than causing a crash later during evaluation.
    func validate() -> [SlotGameDefinitionValidationError] {
        var problems: [SlotGameDefinitionValidationError] = []

        if symbols.isEmpty {
            problems.append(.noSymbols)
        }
        var seenSymbolIDs: Set<SymbolID> = []
        for symbol in symbols {
            if !seenSymbolIDs.insert(symbol.id).inserted {
                problems.append(.duplicateSymbolID(symbol.id))
            }
        }
        let knownSymbolIDs = Set(symbols.map(\.id))

        if reelStrips.isEmpty {
            problems.append(.noReels)
        }
        for (reelIndex, strip) in reelStrips.enumerated() {
            if strip.isEmpty {
                problems.append(.reelStripEmpty(reelIndex: reelIndex))
                continue
            }
            for symbolID in strip where !knownSymbolIDs.contains(symbolID) {
                problems.append(.unknownSymbolInReelStrip(symbolID, reelIndex: reelIndex))
            }
        }

        if paylines.isEmpty {
            problems.append(.noPaylines)
        }
        var seenPaylineIDs: Set<Int> = []
        for payline in paylines {
            if !seenPaylineIDs.insert(payline.id).inserted {
                problems.append(.duplicatePaylineID(payline.id))
            }
            if payline.rowIndices.count != reelCount {
                problems.append(.paylineLengthMismatch(paylineID: payline.id, expected: reelCount, found: payline.rowIndices.count))
            }
            for row in payline.rowIndices where row < 0 || row >= visibleRows {
                problems.append(.paylineRowOutOfBounds(paylineID: payline.id, row: row, visibleRows: visibleRows))
            }
        }

        if paytable.isEmpty {
            problems.append(.noPaytableEntries)
        }
        for entry in paytable {
            if !knownSymbolIDs.contains(entry.symbolID) {
                problems.append(.unknownSymbolInPaytable(entry.symbolID))
            }
            for (matchCount, multiplier) in entry.payoutByMatchCount {
                if matchCount < 1 || matchCount > reelCount {
                    problems.append(.invalidPaytableMatchCount(symbolID: entry.symbolID, matchCount: matchCount))
                }
                if multiplier <= 0 {
                    problems.append(.nonPositivePaytableMultiplier(symbolID: entry.symbolID, matchCount: matchCount))
                }
            }
        }

        if betLevels.isEmpty {
            problems.append(.noBetLevels)
        }
        for level in betLevels where level.perLine <= 0 {
            problems.append(.nonPositiveBetLevel(level.perLine))
        }

        if let wildSymbolID {
            if !knownSymbolIDs.contains(wildSymbolID) {
                problems.append(.unknownWildSymbol(wildSymbolID))
            }
            if wildSymbolID == scatterSymbolID {
                problems.append(.wildEqualsScatter(wildSymbolID))
            }
        }

        if let scatterSymbolID {
            if !knownSymbolIDs.contains(scatterSymbolID) {
                problems.append(.unknownScatterSymbol(scatterSymbolID))
            }
            if freeSpinsRules == nil {
                problems.append(.scatterMissingFreeSpinsRules)
            }
        }

        if let freeSpinsRules {
            if freeSpinsRules.triggerPayouts.isEmpty {
                problems.append(.invalidFreeSpinsRules(reason: "no trigger payouts defined"))
            }
            if freeSpinsRules.maxFreeSpins <= 0 {
                problems.append(.invalidFreeSpinsRules(reason: "maxFreeSpins must be positive"))
            }
            if freeSpinsRules.winMultiplier <= 0 {
                problems.append(.invalidFreeSpinsRules(reason: "winMultiplier must be positive"))
            }
            for payout in freeSpinsRules.triggerPayouts where payout.scatterCount <= 0 || payout.scatterCount > reelCount * visibleRows {
                problems.append(.invalidFreeSpinsRules(reason: "scatter count \(payout.scatterCount) is out of range"))
            }
        }

        return problems
    }

    var isValid: Bool { validate().isEmpty }
}
