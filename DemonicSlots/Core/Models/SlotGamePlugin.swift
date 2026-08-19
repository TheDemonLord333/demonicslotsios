//
//  SlotGamePlugin.swift
//  DemonicSlots
//
//  Extension point for future, game-specific bonus mechanics.
//
//  Standard mechanics (payline evaluation, wild substitution, scatter/free
//  spins) are handled entirely by the shared `SlotEngine` and never need to
//  be re-implemented per game. A new slot game only needs a `SlotGamePlugin`
//  when it introduces a mechanic the shared engine doesn't already model
//  (e.g. a symbol-collection meter, a pick-a-prize bonus screen, expanding
//  wilds with a custom trigger). The engine calls every registered
//  `SlotGameFeature.adjust(evaluation:context:)` after standard evaluation,
//  letting the feature enrich or override the `SpinEvaluation` without
//  touching `SlotEngine`, `PaylineEvaluator` or `ScatterEvaluator`.
//
//  `SlotGameDefinition` stays a plain Codable/validatable data value; the
//  plugin (behavior) is looked up separately by `GameID` through the
//  `GameRegistry`, so definitions can be serialized, diffed and unit tested
//  without ever touching executable code.
//

import Foundation

/// Immutable context handed to every `SlotGameFeature` during evaluation.
nonisolated struct SlotFeatureContext: Sendable {
    var definition: SlotGameDefinition
    var betPerLine: Int64
    var totalBet: Int64
    var isFreeSpin: Bool
    var freeSpinMultiplier: Int64

    init(
        definition: SlotGameDefinition,
        betPerLine: Int64,
        totalBet: Int64,
        isFreeSpin: Bool,
        freeSpinMultiplier: Int64
    ) {
        self.definition = definition
        self.betPerLine = betPerLine
        self.totalBet = totalBet
        self.isFreeSpin = isFreeSpin
        self.freeSpinMultiplier = freeSpinMultiplier
    }
}

/// A single, self-contained bonus mechanic that can post-process a
/// `SpinEvaluation`. Implementations must be pure and deterministic given
/// the same evaluation/context so replaying a `PendingSpin` after an app
/// relaunch always produces the same result.
protocol SlotGameFeature: Sendable {
    /// Stable identifier, unique within the owning plugin.
    var featureID: String { get }

    /// Returns an adjusted evaluation. Implementations that don't apply to
    /// the current spin should return `evaluation` unchanged.
    func adjust(evaluation: SpinEvaluation, context: SlotFeatureContext) -> SpinEvaluation
}

/// Bundles the runtime behavior (features) for one game. Registered in the
/// `GameRegistry` alongside, but separately from, that game's
/// `SlotGameDefinition`.
protocol SlotGamePlugin: Sendable {
    var gameID: GameID { get }
    var features: [any SlotGameFeature] { get }
}

/// Default plugin used by games that only need the shared engine's standard
/// mechanics.
nonisolated struct StandardSlotGamePlugin: SlotGamePlugin {
    let gameID: GameID
    let features: [any SlotGameFeature] = []

    init(gameID: GameID) {
        self.gameID = gameID
    }
}
