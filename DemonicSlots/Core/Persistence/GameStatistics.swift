//
//  GameStatistics.swift
//  DemonicSlots
//
//  Aggregated per-game statistics. Individual spins are never stored
//  indefinitely - only running totals are kept, updated once per completed
//  spin.
//
import Foundation
import SwiftData

@Model
final class GameStatistics {
    @Attribute(.unique) var gameID: String
    var totalSpins: Int64
    var winningSpins: Int64
    var totalWagered: Int64
    var totalWon: Int64
    var largestSingleWin: Int64
    var bonusRoundsTriggered: Int64

    init(
        gameID: String,
        totalSpins: Int64 = 0,
        winningSpins: Int64 = 0,
        totalWagered: Int64 = 0,
        totalWon: Int64 = 0,
        largestSingleWin: Int64 = 0,
        bonusRoundsTriggered: Int64 = 0
    ) {
        self.gameID = gameID
        self.totalSpins = totalSpins
        self.winningSpins = winningSpins
        self.totalWagered = totalWagered
        self.totalWon = totalWon
        self.largestSingleWin = largestSingleWin
        self.bonusRoundsTriggered = bonusRoundsTriggered
    }

    var winRate: Double {
        guard totalSpins > 0 else { return 0 }
        return Double(winningSpins) / Double(totalSpins)
    }

    /// Records the outcome of one completed spin. `wager` is `0` for free
    /// spins (no stake is deducted during bonus rounds).
    func record(wager: Int64, payout: Int64, triggeredBonus: Bool) {
        totalSpins &+= 1
        totalWagered &+= wager
        totalWon &+= payout
        if payout > 0 { winningSpins &+= 1 }
        if payout > largestSingleWin { largestSingleWin = payout }
        if triggeredBonus { bonusRoundsTriggered &+= 1 }
    }

    func reset() {
        totalSpins = 0
        winningSpins = 0
        totalWagered = 0
        totalWon = 0
        largestSingleWin = 0
        bonusRoundsTriggered = 0
    }
}
