//
//  RiskLadderConfiguration.swift
//  DemonicSlots
//
//  Single source of truth for every tunable number in Demonic Risk Ladder:
//  stakes, rung count, multipliers and success probabilities. Nothing in
//  `RiskLadderEngine` or the feature views hardcodes any of this - retuning
//  the game (more rungs, different odds, different stakes) only ever means
//  editing this file.
//
//  Balancing note: these probabilities/multipliers are a starting
//  configuration, not a measured result - same caveat as the RTP note on
//  `InfernalForgeDefinition`. The expected-value-per-coin-staked at each
//  rung is `multiplier * successProbability` relative to the rung below;
//  tune before shipping if a target house edge matters.
//
import Foundation

nonisolated enum RiskLadderConfiguration {
    /// Flat stake options, reusing `BetLevel` exactly as the slot bet
    /// picker does rather than inventing a second stake type - `perLine`
    /// here just means "the stake", since a risk ladder round has no
    /// paylines to multiply it by.
    static let stakeLevels: [BetLevel] = [10, 25, 50, 100, 250, 500].map(BetLevel.init(perLine:))

    /// Rungs 1...8 are regular climbs; the top rung (9) is the jackpot and
    /// pays out automatically the moment it's reached.
    static let levels: [RiskLevel] = [
        RiskLevel(level: 1, multiplier: 1.5, successProbability: 0.85, isJackpot: false),
        RiskLevel(level: 2, multiplier: 2, successProbability: 0.75, isJackpot: false),
        RiskLevel(level: 3, multiplier: 3, successProbability: 0.65, isJackpot: false),
        RiskLevel(level: 4, multiplier: 5, successProbability: 0.55, isJackpot: false),
        RiskLevel(level: 5, multiplier: 10, successProbability: 0.45, isJackpot: false),
        RiskLevel(level: 6, multiplier: 15, successProbability: 0.35, isJackpot: false),
        RiskLevel(level: 7, multiplier: 25, successProbability: 0.25, isJackpot: false),
        RiskLevel(level: 8, multiplier: 50, successProbability: 0.15, isJackpot: false),
        RiskLevel(level: 9, multiplier: 100, successProbability: 0.08, isJackpot: true),
    ]

    static var maxLevel: Int { levels.count }

    static func level(_ number: Int) -> RiskLevel? {
        guard number >= 1, number <= levels.count else { return nil }
        return levels[number - 1]
    }
}
