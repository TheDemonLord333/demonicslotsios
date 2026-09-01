//
//  RiskLadderRoundState.swift
//  DemonicSlots
//
//  Durable record of the one Risk Ladder round that can be active at a
//  time, keyed by `gameID` the same way `GameProgress` tracks per-game
//  state. `isActive`/`stakeDebited` mirror `PendingSpin`'s two-flag
//  transaction pattern so a killed app can never duplicate a stake or a
//  payout:
//
//   - `isActive == false`: no round in progress, safe to start a new one.
//   - `isActive == true, stakeDebited == false`: the stake was *about* to
//     be taken but the debit itself never completed/saved - nothing was
//     actually charged, so recovery just discards this row.
//   - `isActive == true, stakeDebited == true`: the stake was taken and
//     nothing has been paid out yet - recovery resumes the round exactly
//     at `currentLevel`, exactly like a resumed free-spin bonus round.
//
//  Every path that ends a round (loss, cash-out, jackpot) resets this row
//  to `isActive == false` in the same save as the payout, so a relaunch
//  after the round has already been settled sees nothing left to recover.
//
import Foundation
import SwiftData

@Model
final class RiskLadderRoundState {
    @Attribute(.unique) var gameID: String
    var isActive: Bool
    var stakeDebited: Bool
    var stake: Int64
    /// 0 = standing at START, nothing climbed yet. 1...`maxLevel` = the
    /// highest rung successfully reached so far this round.
    var currentLevel: Int

    init(
        gameID: String,
        isActive: Bool = false,
        stakeDebited: Bool = false,
        stake: Int64 = 0,
        currentLevel: Int = 0
    ) {
        self.gameID = gameID
        self.isActive = isActive
        self.stakeDebited = stakeDebited
        self.stake = stake
        self.currentLevel = currentLevel
    }

    /// Clears the row back to "no round in progress". Called once a round
    /// is fully settled (lost, cashed out, or jackpotted) - always in the
    /// same save as the payout/no-payout decision, never separately, so
    /// there's no window where a settled round still looks recoverable.
    func reset() {
        isActive = false
        stakeDebited = false
        stake = 0
        currentLevel = 0
    }
}
