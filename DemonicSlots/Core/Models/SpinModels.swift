//
//  SpinModels.swift
//  DemonicSlots
//
//  Value types describing a fully pre-computed spin outcome. A `SpinResult`
//  is produced once, before any animation runs; the UI layer only ever
//  *plays back* it, so timing, device performance and tap timestamps can
//  never influence the outcome.
//

import Foundation

/// One cell on the 5x3 (or larger) visible grid.
nonisolated struct GridPosition: Codable, Hashable, Sendable {
    var reel: Int
    var row: Int

    init(reel: Int, row: Int) {
        self.reel = reel
        self.row = row
    }
}

/// The raw randomized outcome of a spin: which stop index each reel landed
/// on, and the resulting visible symbol grid (`grid[reelIndex][rowIndex]`).
nonisolated struct SpinResult: Codable, Hashable, Sendable {
    var stopIndices: [Int]
    var grid: [[SymbolID]]

    init(stopIndices: [Int], grid: [[SymbolID]]) {
        self.stopIndices = stopIndices
        self.grid = grid
    }

    var reelCount: Int { grid.count }
    var visibleRows: Int { grid.first?.count ?? 0 }

    func symbol(reel: Int, row: Int) -> SymbolID? {
        guard reel >= 0, reel < grid.count else { return nil }
        let column = grid[reel]
        guard row >= 0, row < column.count else { return nil }
        return column[row]
    }
}

/// A single payline's winning combination, if any.
nonisolated struct LineWin: Codable, Hashable, Sendable, Identifiable {
    var paylineID: Int
    var symbolID: SymbolID
    var matchCount: Int
    /// Multiplier of the per-line bet (paytable value, already scaled by any
    /// active free-spin multiplier).
    var multiplier: Int64
    var positions: [GridPosition]

    var id: Int { paylineID }

    init(paylineID: Int, symbolID: SymbolID, matchCount: Int, multiplier: Int64, positions: [GridPosition]) {
        self.paylineID = paylineID
        self.symbolID = symbolID
        self.matchCount = matchCount
        self.multiplier = multiplier
        self.positions = positions
    }

    /// Coin payout of this single line, given the per-line bet used for the spin.
    func coinPayout(betPerLine: Int64) -> Int64 {
        multiplier * betPerLine
    }
}

/// Result of the scatter evaluation, independent of paylines.
nonisolated struct ScatterWin: Codable, Hashable, Sendable {
    var count: Int
    /// Coin payout already resolved against the total stake.
    var payout: Int64
    var freeSpinsAwarded: Int
    var positions: [GridPosition]

    init(count: Int, payout: Int64, freeSpinsAwarded: Int, positions: [GridPosition]) {
        self.count = count
        self.payout = payout
        self.freeSpinsAwarded = freeSpinsAwarded
        self.positions = positions
    }
}

/// The fully evaluated outcome of one spin: the raw grid plus every line
/// win, the scatter result, and the total coin payout. Animation and
/// bookkeeping both read from this same value so they can never disagree.
nonisolated struct SpinEvaluation: Codable, Hashable, Sendable {
    var spinResult: SpinResult
    var lineWins: [LineWin]
    var scatterWin: ScatterWin?
    var totalPayout: Int64
    var isBonusTriggering: Bool

    init(
        spinResult: SpinResult,
        lineWins: [LineWin],
        scatterWin: ScatterWin?,
        totalPayout: Int64,
        isBonusTriggering: Bool
    ) {
        self.spinResult = spinResult
        self.lineWins = lineWins
        self.scatterWin = scatterWin
        self.totalPayout = totalPayout
        self.isBonusTriggering = isBonusTriggering
    }

    var hasAnyWin: Bool { totalPayout > 0 }
}
