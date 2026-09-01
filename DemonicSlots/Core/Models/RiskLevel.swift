//
//  RiskLevel.swift
//  DemonicSlots
//
//  One climbable rung of a risk ladder. Kept as plain, Codable data so the
//  odds/payouts for `RiskLadderEngine` live entirely in
//  `RiskLadderConfiguration` and never get hardcoded into a view.
//
import Foundation

nonisolated struct RiskLevel: Codable, Hashable, Sendable, Identifiable {
    /// 1-based rung number, matching the order climbed in.
    let level: Int
    /// Payout multiplier applied to the stake if the player cashes out (or
    /// is auto-paid, at the top rung) while standing on this level.
    let multiplier: Double
    /// Probability, in `0...1`, that attempting to climb *from* the level
    /// below this one succeeds and lands the player here.
    let successProbability: Double
    /// Whether reaching this level ends the round automatically with the
    /// big top-rung payout, rather than leaving the choice of "Risiko" vs.
    /// "Gewinn nehmen" to the player.
    let isJackpot: Bool

    var id: Int { level }
}
