//
//  SlotEngine.swift
//  DemonicSlots
//
//  The single shared engine every slot game runs through. Spinning a game
//  never touches SwiftUI: the full outcome (grid, line wins, scatter win,
//  total payout) is computed synchronously and returned as one
//  `SpinEvaluation`, before any animation begins. Odds are derived purely
//  from `definition.reelStrips` and the injected `RandomNumberSource` -
//  never from balance, loss streak or bet size.
//
import Foundation

nonisolated enum SlotEngineError: Error, Hashable, Sendable, LocalizedError {
    case invalidDefinition([SlotGameDefinitionValidationError])

    var errorDescription: String? {
        switch self {
        case .invalidDefinition(let problems):
            let details = problems.map { "- " + ($0.errorDescription ?? "unknown problem") }.joined(separator: "\n")
            return "This game's configuration is invalid and cannot be played:\n\(details)"
        }
    }
}

nonisolated struct SlotEngine: Sendable {
    private let plugin: (any SlotGamePlugin)?

    init(plugin: (any SlotGamePlugin)? = nil) {
        self.plugin = plugin
    }

    /// Computes one complete spin outcome. Throws `SlotEngineError` for a
    /// malformed definition instead of crashing or producing garbage.
    func spin(
        definition: SlotGameDefinition,
        betPerLine: Int64,
        isFreeSpin: Bool,
        freeSpinMultiplier: Int64,
        randomSource: inout any RandomNumberSource
    ) throws -> SpinEvaluation {
        let problems = definition.validate()
        guard problems.isEmpty else { throw SlotEngineError.invalidDefinition(problems) }

        let placeholder = definition.symbols[0].id
        let stopIndices = ReelSpinner.stopIndices(for: definition.reelStrips, randomSource: &randomSource)
        let grid = ReelSpinner.visibleGrid(
            stopIndices: stopIndices,
            reelStrips: definition.reelStrips,
            visibleRows: definition.visibleRows,
            placeholderSymbol: placeholder
        )
        let spinResult = SpinResult(stopIndices: stopIndices, grid: grid)

        let totalBet = definition.totalBet(betPerLine: betPerLine)
        let effectiveMultiplier = isFreeSpin ? max(freeSpinMultiplier, 1) : 1

        var lineWins = PaylineEvaluator.evaluate(grid: grid, definition: definition)
        if effectiveMultiplier > 1 {
            lineWins = lineWins.map { win in
                var scaled = win
                scaled.multiplier *= effectiveMultiplier
                return scaled
            }
        }

        let scatterWin = ScatterEvaluator.evaluate(grid: grid, definition: definition, totalBet: totalBet)

        let lineCoinTotal = lineWins.reduce(Int64(0)) { partial, win in
            partial + win.coinPayout(betPerLine: betPerLine)
        }
        let totalPayout = lineCoinTotal + (scatterWin?.payout ?? 0)

        var evaluation = SpinEvaluation(
            spinResult: spinResult,
            lineWins: lineWins,
            scatterWin: scatterWin,
            totalPayout: totalPayout,
            isBonusTriggering: (scatterWin?.freeSpinsAwarded ?? 0) > 0
        )

        if let plugin, !plugin.features.isEmpty {
            let context = SlotFeatureContext(
                definition: definition,
                betPerLine: betPerLine,
                totalBet: totalBet,
                isFreeSpin: isFreeSpin,
                freeSpinMultiplier: effectiveMultiplier
            )
            for feature in plugin.features {
                evaluation = feature.adjust(evaluation: evaluation, context: context)
            }
        }

        return evaluation
    }
}
