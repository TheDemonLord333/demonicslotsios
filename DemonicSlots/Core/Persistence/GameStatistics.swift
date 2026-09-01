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
    /// `multiplier * 100` (e.g. x1.5 -> 150) of the best payout multiplier
    /// ever hit in a single round - only meaningful for a multiplier-based
    /// game like Demonic Risk Ladder, always `0` for a slot. Kept as a
    /// fixed-point `Int64`, not a `Double`, to match every other stat here.
    // `= 0` at the declaration (not just in `init` below) matters: SwiftData
    // needs a property-level default to add a new non-optional column to a
    // store created before this field existed - see the identical note on
    // `PlayerProfile.lastKnownAdminRevision`, which is exactly the launch
    // crash this avoids.
    var highestMultiplierPercent: Int64 = 0

    init(
        gameID: String,
        totalSpins: Int64 = 0,
        winningSpins: Int64 = 0,
        totalWagered: Int64 = 0,
        totalWon: Int64 = 0,
        largestSingleWin: Int64 = 0,
        bonusRoundsTriggered: Int64 = 0,
        highestMultiplierPercent: Int64 = 0
    ) {
        self.gameID = gameID
        self.totalSpins = totalSpins
        self.winningSpins = winningSpins
        self.totalWagered = totalWagered
        self.totalWon = totalWon
        self.largestSingleWin = largestSingleWin
        self.bonusRoundsTriggered = bonusRoundsTriggered
        self.highestMultiplierPercent = highestMultiplierPercent
    }

    var winRate: Double {
        guard totalSpins > 0 else { return 0 }
        return Double(winningSpins) / Double(totalSpins)
    }

    /// Records the outcome of one completed round for any game that stakes
    /// coins and pays out a coin amount - a slot spin or a Risk Ladder
    /// round alike. `wager` is `0` for free spins (no stake is deducted
    /// during bonus rounds). `triggeredBonus` means "a slot bonus round
    /// started" for a slot, or "the round reached the jackpot rung" for
    /// Risk Ladder - both are the same shape of "rare, big event" stat.
    /// `multiplierPercent` is Risk-Ladder-only (see
    /// `highestMultiplierPercent`); slots never pass it, so it always
    /// defaults to `nil` there and this method's slot behavior is
    /// unchanged from before this field existed.
    func record(wager: Int64, payout: Int64, triggeredBonus: Bool, multiplierPercent: Int64? = nil) {
        totalSpins &+= 1
        totalWagered &+= wager
        totalWon &+= payout
        if payout > 0 { winningSpins &+= 1 }
        if payout > largestSingleWin { largestSingleWin = payout }
        if triggeredBonus { bonusRoundsTriggered &+= 1 }
        if let multiplierPercent, multiplierPercent > highestMultiplierPercent {
            highestMultiplierPercent = multiplierPercent
        }
    }

    func reset() {
        totalSpins = 0
        winningSpins = 0
        totalWagered = 0
        totalWon = 0
        largestSingleWin = 0
        bonusRoundsTriggered = 0
        highestMultiplierPercent = 0
    }
}
