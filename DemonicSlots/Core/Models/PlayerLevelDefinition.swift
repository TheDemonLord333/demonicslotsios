//
//  PlayerLevelDefinition.swift
//  DemonicSlots
//
//  One entry in the central level-progression table (see
//  `PlayerLevelConfiguration`): the win-chance bonus a player gets simply
//  for having reached `level`. Deliberately separate from bet limits
//  (`BetTier`) - the task that introduced this asked for the two to stay
//  independently configurable.
//
import Foundation

nonisolated struct PlayerLevelDefinition: Codable, Hashable, Sendable, Identifiable {
    let level: Int
    /// Multiplier applied on top of a game's base win probability/RNG
    /// weighting - `1.0` = no bonus, `1.07` = +7%.
    let winMultiplier: Double

    var id: Int { level }
}
