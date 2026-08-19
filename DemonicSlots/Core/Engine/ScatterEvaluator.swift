//
//  ScatterEvaluator.swift
//  DemonicSlots
//
//  Scatter symbols are counted anywhere on the visible grid, independent of
//  paylines. The evaluator returns the best matching tier from the game's
//  `FreeSpinsRules`, or `nil` if the game has no scatter/free-spin bonus or
//  too few scatters landed.
//
import Foundation

nonisolated enum ScatterEvaluator {
    static func evaluate(grid: [[SymbolID]], definition: SlotGameDefinition, totalBet: Int64) -> ScatterWin? {
        guard let scatterID = definition.scatterSymbolID, let rules = definition.freeSpinsRules else { return nil }

        var positions: [GridPosition] = []
        for (reelIndex, column) in grid.enumerated() {
            for (rowIndex, symbol) in column.enumerated() where symbol == scatterID {
                positions.append(GridPosition(reel: reelIndex, row: rowIndex))
            }
        }

        guard let payoutTier = rules.payout(forScatterCount: positions.count) else { return nil }
        let payout = payoutTier.totalBetMultiplier * totalBet
        return ScatterWin(
            count: positions.count,
            payout: payout,
            freeSpinsAwarded: payoutTier.freeSpinsAwarded,
            positions: positions
        )
    }

    /// Whether a scatter count landed during an active free-spin round is
    /// enough to retrigger extra spins.
    static func qualifiesForRetrigger(scatterCount: Int, rules: FreeSpinsRules) -> Bool {
        scatterCount >= rules.retriggerMinimumScatterCount
    }
}
