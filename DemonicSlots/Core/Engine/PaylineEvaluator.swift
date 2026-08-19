//
//  PaylineEvaluator.swift
//  DemonicSlots
//
//  Evaluates every payline of a definition against a visible grid.
//  Winning runs must start at reel 0 and be contiguous left to right.
//  The wild symbol substitutes for any regular symbol (never for the
//  scatter). When more than one winning combination is possible on a line
//  because of wilds, only the highest-paying combination is reported; ties
//  favor the non-wild combination for determinism.
//
import Foundation

nonisolated enum PaylineEvaluator {
    static func evaluate(grid: [[SymbolID]], definition: SlotGameDefinition) -> [LineWin] {
        definition.paylines.compactMap { payline in
            evaluate(payline: payline, grid: grid, definition: definition)
        }
    }

    private static func evaluate(payline: Payline, grid: [[SymbolID]], definition: SlotGameDefinition) -> LineWin? {
        let reelCount = grid.count
        guard reelCount > 0, payline.rowIndices.count == reelCount else { return nil }

        var lineSymbols: [SymbolID] = []
        lineSymbols.reserveCapacity(reelCount)
        for reelIndex in 0..<reelCount {
            let row = payline.rowIndices[reelIndex]
            let column = grid[reelIndex]
            guard row >= 0, row < column.count else { return nil }
            lineSymbols.append(column[row])
        }

        let wildID = definition.wildSymbolID
        let scatterID = definition.scatterSymbolID

        // Candidates are evaluated in order: the first non-wild, non-scatter
        // symbol on the line, then the wild itself (an all-wild run). Order
        // matters only for tie-breaking, see header comment.
        var candidates: [SymbolID] = []
        if let firstRegular = lineSymbols.first(where: { $0 != wildID && $0 != scatterID }) {
            candidates.append(firstRegular)
        }
        if let wildID, !candidates.contains(wildID) {
            candidates.append(wildID)
        }

        var best: LineWin?
        for candidate in candidates {
            guard let entry = definition.paytableEntry(for: candidate) else { continue }
            var matchCount = 0
            for symbol in lineSymbols {
                if symbol == candidate || (wildID != nil && symbol == wildID) {
                    matchCount += 1
                } else {
                    break
                }
            }
            guard matchCount >= 3, let multiplier = entry.multiplier(forMatchCount: matchCount) else { continue }
            if let currentBest = best, multiplier <= currentBest.multiplier {
                continue
            }
            let positions = (0..<matchCount).map { GridPosition(reel: $0, row: payline.rowIndices[$0]) }
            best = LineWin(paylineID: payline.id, symbolID: candidate, matchCount: matchCount, multiplier: multiplier, positions: positions)
        }
        return best
    }
}
