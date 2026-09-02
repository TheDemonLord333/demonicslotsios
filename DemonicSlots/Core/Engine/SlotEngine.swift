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
    /// `probabilityContext` defaults to `.neutral` (no bonus/penalty) so
    /// every existing caller/test is unaffected; `SpinSessionController` is
    /// the one caller that computes and passes a real one, from the
    /// player's level/win-chance multiplier via `PlayerProgressionService`.
    func spin(
        definition: SlotGameDefinition,
        betPerLine: Int64,
        isFreeSpin: Bool,
        freeSpinMultiplier: Int64,
        probabilityContext: GameProbabilityContext = .neutral,
        randomSource: inout any RandomNumberSource
    ) throws -> SpinEvaluation {
        let problems = definition.validate()
        guard problems.isEmpty else { throw SlotEngineError.invalidDefinition(problems) }

        let placeholder = definition.symbols[0].id
        let stopIndices = ReelSpinner.stopIndices(
            for: definition.reelStrips,
            definition: definition,
            probabilityContext: probabilityContext,
            randomSource: &randomSource
        )
        var grid = ReelSpinner.visibleGrid(
            stopIndices: stopIndices,
            reelStrips: definition.reelStrips,
            visibleRows: definition.visibleRows,
            placeholderSymbol: placeholder
        )
        // Admin "garantierter Jackpot" mode: overwrite the landed grid
        // outright with the game's highest-value symbol in every cell,
        // maximizing every payline's match count/payout simultaneously -
        // see ReelSpinner.swift's header comment for why this can't be
        // done by biasing stopIndices the way a normal bonus is.
        // `stopIndices`/the reel-stop animation are unaffected (still a
        // real roll), only the grid the player actually sees/scores is
        // overridden - `ReelsGridView` reads `spinResult.grid`, never
        // re-derives it from `stopIndices` itself.
        if probabilityContext.guaranteesJackpot, let topSymbol = ReelSpinner.highestValueSymbol(definition: definition) {
            grid = Array(repeating: Array(repeating: topSymbol, count: definition.visibleRows), count: definition.reelCount)
        }
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
