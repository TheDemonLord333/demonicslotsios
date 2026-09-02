//
//  GuaranteedJackpotModeTests.swift
//  DemonicSlotsTests
//
//  Covers the admin "garantierter Jackpot" mode's slot-machine half:
//  `ReelSpinner.highestValueSymbol` and `SlotEngine.spin`'s grid override.
//  The Demonic Risk Ladder half (`RiskLadderEngine.attemptClimb`'s bypass)
//  is covered in RiskLadderEngineTests.swift.
//
import Testing
@testable import DemonicSlots

struct GuaranteedJackpotModeTests {
    @Test func neutralContextDoesNotGuaranteeAJackpot() {
        #expect(!GameProbabilityContext.neutral.guaranteesJackpot)
    }

    @Test func omittingGuaranteesJackpotDefaultsToFalse() {
        // Every pre-existing call site that only ever passed
        // finalWinMultiplier must keep behaving exactly as before this
        // feature existed.
        let context = GameProbabilityContext(finalWinMultiplier: 1.5)
        #expect(!context.guaranteesJackpot)
    }

    @Test func highestValueSymbolIsInfernalForgesWildSinceItsAlsoTheTopPayingSymbol() {
        let definition = InfernalForgeDefinition.definition
        // infernalCrown pays 300 at 5-of-a-kind - higher than every other
        // regular symbol's 5-match payout and higher than the scatter's
        // best total-bet multiplier (50), so it must win `max(by:)`.
        #expect(ReelSpinner.highestValueSymbol(definition: definition) == InfernalForgeSymbols.infernalCrown)
    }

    @Test func highestValueSymbolIsNilForADefinitionWithNoPaytableEntries() {
        var definition = InfernalForgeDefinition.definition
        definition.paytable = []
        definition.freeSpinsRules = nil
        #expect(ReelSpinner.highestValueSymbol(definition: definition) == nil)
    }

    @Test func guaranteedJackpotFillsEveryCellWithTheHighestValueSymbol() throws {
        let definition = InfernalForgeDefinition.definition
        var random: any RandomNumberSource = SeededRandomSource(seed: 11)
        let context = GameProbabilityContext(finalWinMultiplier: 1.0, guaranteesJackpot: true)

        let evaluation = try SlotEngine().spin(
            definition: definition,
            betPerLine: 1,
            isFreeSpin: false,
            freeSpinMultiplier: 1,
            probabilityContext: context,
            randomSource: &random
        )

        let topSymbol = try #require(ReelSpinner.highestValueSymbol(definition: definition))
        for column in evaluation.spinResult.grid {
            for symbol in column {
                #expect(symbol == topSymbol)
            }
        }
        // Every payline now matches the wild across all 5 reels - the
        // maximum possible line win for this game, with zero changes to
        // PaylineEvaluator needed to make that true.
        #expect(evaluation.lineWins.count == definition.paylines.count)
        #expect(evaluation.totalPayout > 0)
    }

    @Test func neutralContextNeverOverridesTheRolledGrid() throws {
        let definition = InfernalForgeDefinition.definition
        var withOverride: any RandomNumberSource = SeededRandomSource(seed: 5)
        var withoutOverride: any RandomNumberSource = SeededRandomSource(seed: 5)

        let neutralEvaluation = try SlotEngine().spin(
            definition: definition,
            betPerLine: 1,
            isFreeSpin: false,
            freeSpinMultiplier: 1,
            probabilityContext: .neutral,
            randomSource: &withOverride
        )
        let noContextEvaluation = try SlotEngine().spin(
            definition: definition,
            betPerLine: 1,
            isFreeSpin: false,
            freeSpinMultiplier: 1,
            randomSource: &withoutOverride
        )

        #expect(neutralEvaluation.spinResult.grid == noContextEvaluation.spinResult.grid)
    }
}
