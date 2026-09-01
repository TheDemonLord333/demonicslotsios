//
//  GameProbabilityContext.swift
//  DemonicSlots
//
//  The one value `PlayerProgressionService` hands down to a game engine so
//  no engine has to know about `PlayerProfile`, the backend, or level
//  configuration at all - it just receives an already-computed, already-
//  validated multiplier and applies it to its own probability/RNG logic.
//  Computed once per spin/round by the owning session controller (see
//  `SpinSessionController`/`RiskLadderSessionController`), not re-derived
//  by every mechanic inside a single engine call.
//
import Foundation

nonisolated struct GameProbabilityContext: Sendable, Equatable {
    /// `levelWinMultiplier * playerWinChanceMultiplier`, already clamped by
    /// `PlayerProgressionService`. `1.0` means "no bonus or penalty at all".
    let finalWinMultiplier: Double

    /// No bonus/penalty - every mechanic behaves exactly as if this feature
    /// didn't exist. The default everywhere, so every pre-existing call
    /// site/test that doesn't pass a context explicitly is unaffected.
    static let neutral = GameProbabilityContext(finalWinMultiplier: 1.0)

    /// The literal `effectiveProbability = baseProbability * multiplier`
    /// formula, clamped to `0...cap`. Used directly by mechanics that
    /// already expose a single scalar probability (Demonic Risk Ladder's
    /// per-level `successProbability`). The slot has no single such scalar -
    /// a spin's outcome emerges from which symbols land across every reel -
    /// so it applies `finalWinMultiplier` as an RNG selection-weight bias in
    /// `ReelSpinner` instead; see that file's header comment for why that's
    /// the equivalent, "nachvollziehbare" adaptation for a reel-strip engine.
    func adjustedProbability(base: Double, cap: Double = PlayerProgressionService.maximumEffectiveWinChance) -> Double {
        guard base.isFinite, base > 0 else { return max(base, 0) }
        let effectiveCap = min(max(cap, 0), 1)
        return min(max(base * finalWinMultiplier, 0), effectiveCap)
    }
}
