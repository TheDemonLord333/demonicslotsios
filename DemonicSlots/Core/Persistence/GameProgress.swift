//
//  GameProgress.swift
//  DemonicSlots
//
//  Per-game persisted progress: the last bet level chosen, and the state of
//  an in-progress free-spin bonus round. Bonus state must survive an app
//  relaunch, including the stake that originally triggered it.
//
import Foundation
import SwiftData

@Model
final class GameProgress {
    @Attribute(.unique) var gameID: String
    var lastBetPerLine: Int64

    // MARK: Bonus round state
    var isInBonusRound: Bool
    var remainingFreeSpins: Int
    var totalFreeSpinsGrantedInRound: Int
    /// The per-line stake active when the bonus was triggered. Free spins
    /// never deduct stake, but wins are still computed against this value.
    var bonusTriggerBetPerLine: Int64
    var bonusAccumulatedPayout: Int64

    init(
        gameID: String,
        lastBetPerLine: Int64,
        isInBonusRound: Bool = false,
        remainingFreeSpins: Int = 0,
        totalFreeSpinsGrantedInRound: Int = 0,
        bonusTriggerBetPerLine: Int64 = 0,
        bonusAccumulatedPayout: Int64 = 0
    ) {
        self.gameID = gameID
        self.lastBetPerLine = lastBetPerLine
        self.isInBonusRound = isInBonusRound
        self.remainingFreeSpins = remainingFreeSpins
        self.totalFreeSpinsGrantedInRound = totalFreeSpinsGrantedInRound
        self.bonusTriggerBetPerLine = bonusTriggerBetPerLine
        self.bonusAccumulatedPayout = bonusAccumulatedPayout
    }

    func startBonusRound(freeSpins: Int, betPerLine: Int64) {
        isInBonusRound = true
        remainingFreeSpins = freeSpins
        totalFreeSpinsGrantedInRound = freeSpins
        bonusTriggerBetPerLine = betPerLine
        bonusAccumulatedPayout = 0
    }

    func endBonusRound() {
        isInBonusRound = false
        remainingFreeSpins = 0
        totalFreeSpinsGrantedInRound = 0
        bonusTriggerBetPerLine = 0
        bonusAccumulatedPayout = 0
    }
}
