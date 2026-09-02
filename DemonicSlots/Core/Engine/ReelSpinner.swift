//
//  ReelSpinner.swift
//  DemonicSlots
//
//  Pure computation of a spin's stop indices and the resulting visible
//  grid. Contains no timing, animation or UI concerns whatsoever - the
//  entire outcome exists before a single frame of animation plays.
//
//  Win-chance multiplier (see `PlayerProgressionService`/
//  `GameProbabilityContext`): a slot has no single scalar "probability of
//  winning this spin" to multiply the way Demonic Risk Ladder's per-level
//  `successProbability` does - a spin's outcome emerges from which symbols
//  land across every reel, each drawn independently from its own strip.
//  The honest, "within the existing RNG/reel logic" way to apply a bonus
//  here is to bias *which stop index gets picked*, not to reroll or inject
//  a win after the fact:
//
//   - Every symbol's own paytable value (its best per-line payout, or its
//     best scatter payout for the scatter symbol) becomes a selection
//     *weight* for that stop, normalized against the game's own
//     highest-paying symbol. A `finalWinMultiplier > 1` raises higher-value
//     symbols' weight more than lower-value ones (never below a small
//     floor, so nothing's weight ever hits zero); `< 1` (an admin penalty)
//     lowers it the same way. This nudges the whole distribution of what
//     lands - including scatter frequency - without touching payline
//     evaluation, payout math, or ever picking an outcome outside what the
//     strip could already produce.
//   - At `finalWinMultiplier == 1.0` (the default for any player without an
//     active bonus/penalty - i.e. the pre-existing behavior for everyone
//     until this feature shipped) this take the *exact* original code path:
//     a single uniform `nextInt(0..<strip.count)` roll, byte-for-byte
//     identical to before this feature existed. Every pre-existing test
//     (`ReelSpinnerTests`, `SlotSimulatorTests`, the RTP tuning in
//     `InfernalForgeSymbols`) keeps passing unchanged for exactly that
//     reason - this only ever engages for a player who actually has a
//     level bonus or an admin-set multiplier.
//
//  Admin "garantierter Jackpot" mode (`GameProbabilityContext.
//  guaranteesJackpot`) is a different, harder case: forcing an actual
//  landed *grid* full of the highest-value symbol can't be done by biasing
//  which `stopIndex` gets picked the way a normal bonus is - the strips are
//  shuffled once at startup (`InfernalForgeSymbols.buildReelStrips`) and
//  nothing guarantees the top symbol appears `visibleRows` times in a row
//  anywhere in a given strip, so no `stopIndex` might even exist that reads
//  out an all-top-symbol column. `SlotEngine.spin` handles this the honest
//  way instead: it still calls `stopIndices`/`visibleGrid` normally (so the
//  reel-stop animation has real indices to land on), then overwrites the
//  resulting grid outright when this mode is on - see that file.
//
import Foundation

nonisolated enum ReelSpinner {
    /// Picks one random stop index per reel. An empty strip defensively
    /// yields stop `0` rather than crashing (the definition should have
    /// already been validated by this point).
    ///
    /// `definition`/`probabilityContext` are optional/defaulted so every
    /// pre-existing call site (tests included) is unaffected; `SlotEngine`
    /// is the one caller that passes both for real.
    static func stopIndices(
        for reelStrips: [[SymbolID]],
        definition: SlotGameDefinition? = nil,
        probabilityContext: GameProbabilityContext = .neutral,
        randomSource: inout any RandomNumberSource
    ) -> [Int] {
        let multiplierDelta = probabilityContext.finalWinMultiplier - 1
        guard multiplierDelta != 0, let definition else {
            return reelStrips.map { strip in
                guard !strip.isEmpty else { return 0 }
                return randomSource.nextInt(in: 0..<strip.count)
            }
        }

        let boostWeights = symbolBoostWeights(definition: definition, multiplierDelta: multiplierDelta)
        return reelStrips.map { strip in
            guard !strip.isEmpty else { return 0 }
            guard !boostWeights.isEmpty else {
                return randomSource.nextInt(in: 0..<strip.count)
            }
            let weights = strip.map { boostWeights[$0] ?? 1 }
            return weightedIndex(weights: weights, randomSource: &randomSource)
        }
    }

    /// The single highest-value symbol in `definition`'s paytable/scatter
    /// rules (by best per-line payout, or best scatter-trigger multiplier
    /// for the scatter symbol) - the same symbol `symbolBoostWeights`
    /// already biases hardest toward, and what "garantierter Jackpot" mode
    /// forces onto every visible cell (see `SlotEngine.spin`). `nil` only
    /// if the game defines no positive-value symbol at all (never true for
    /// a validated definition).
    static func highestValueSymbol(definition: SlotGameDefinition) -> SymbolID? {
        rawSymbolValues(definition: definition).max { $0.value < $1.value }?.key
    }

    /// Computes the visible symbol grid from stop indices. `grid[reel][row]`
    /// is read cyclically from that reel's strip starting at its stop index,
    /// so the strip acts as a circular buffer.
    static func visibleGrid(
        stopIndices: [Int],
        reelStrips: [[SymbolID]],
        visibleRows: Int,
        placeholderSymbol: SymbolID
    ) -> [[SymbolID]] {
        zip(stopIndices, reelStrips).map { stopIndex, strip in
            guard !strip.isEmpty else {
                return Array(repeating: placeholderSymbol, count: visibleRows)
            }
            return (0..<visibleRows).map { rowOffset in
                strip[(stopIndex + rowOffset) % strip.count]
            }
        }
    }

    // MARK: - Weighted selection (win-chance multiplier only)

    /// Per-symbol RNG selection weight for one game's own paytable/scatter
    /// rules, normalized to that game's own highest-value symbol - so this
    /// adapts to any game's paytable without hardcoding symbol names.
    /// Empty when the game has nothing to rank against (defensively falls
    /// back to the original uniform roll at the call site above).
    private static func symbolBoostWeights(definition: SlotGameDefinition, multiplierDelta: Double) -> [SymbolID: Double] {
        let rawValues = rawSymbolValues(definition: definition)
        guard let maxValue = rawValues.values.max(), maxValue > 0 else { return [:] }

        return rawValues.mapValues { value in
            let normalizedValue = value / maxValue // > 0, up to 1.0 for the single best symbol
            // Floor at 0.01 rather than 0: even a harsh admin penalty must
            // never make a symbol literally impossible to land.
            return max(1 + multiplierDelta * normalizedValue, 0.01)
        }
    }

    /// Raw per-symbol value (best per-line paytable payout, or best
    /// scatter-trigger multiplier for the scatter symbol) - unnormalized,
    /// shared by both `symbolBoostWeights` (which normalizes it into
    /// weights) and `highestValueSymbol` (which just wants the max).
    private static func rawSymbolValues(definition: SlotGameDefinition) -> [SymbolID: Double] {
        var rawValues: [SymbolID: Double] = [:]
        for entry in definition.paytable {
            guard let best = entry.payoutByMatchCount.values.max(), best > 0 else { continue }
            rawValues[entry.symbolID] = Double(best)
        }
        if let scatterID = definition.scatterSymbolID, let rules = definition.freeSpinsRules {
            if let bestScatterMultiplier = rules.triggerPayouts.map(\.totalBetMultiplier).max(), bestScatterMultiplier > 0 {
                rawValues[scatterID] = Double(bestScatterMultiplier)
            }
        }
        return rawValues
    }

    /// Weighted discrete sampling over `weights` (one entry per strip
    /// index), using only the shared `RandomNumberSource.nextInt(in:)`
    /// primitive - the classic cumulative-weight-plus-threshold-roll
    /// technique, scaled to a fixed resolution for precision without
    /// needing a `Double`-producing RNG primitive.
    private static func weightedIndex(weights: [Double], randomSource: inout any RandomNumberSource) -> Int {
        let total = weights.reduce(0, +)
        guard total > 0 else { return 0 }
        let resolution = 1_000_000
        let roll = Double(randomSource.nextInt(in: 0..<resolution)) / Double(resolution) * total
        var cumulative = 0.0
        for (index, weight) in weights.enumerated() {
            cumulative += weight
            if roll < cumulative { return index }
        }
        return weights.count - 1
    }
}
