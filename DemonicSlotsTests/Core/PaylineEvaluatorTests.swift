//
//  PaylineEvaluatorTests.swift
//  DemonicSlotsTests
//
//  Covers requirements 2 (all ten paylines), 3 (3/4/5-of-a-kind payouts),
//  4 (wild substitution) and 5 (highest wild combination per line).
//
import Testing
@testable import DemonicSlots

struct PaylineEvaluatorTests {
    private let definition = InfernalForgeDefinition.definition
    private let target = InfernalForgeSymbols.cursedRune // 3:5, 4:12, 5:25
    private let filler = InfernalForgeSymbols.boneIdol // 3:3, 4:8, 5:15
    private let wild = InfernalForgeSymbols.infernalCrown // 3:25, 4:100, 5:300

    private func grid(withTarget target: SymbolID, along payline: Payline, fill filler: SymbolID) -> [[SymbolID]] {
        (0..<5).map { reel in
            var column = [SymbolID](repeating: filler, count: 3)
            column[payline.rowIndices[reel]] = target
            return column
        }
    }

    @Test func everyDefinedPaylineProducesAFiveOfAKindWin() {
        for payline in definition.paylines {
            let testGrid = grid(withTarget: target, along: payline, fill: filler)
            let wins = PaylineEvaluator.evaluate(grid: testGrid, definition: definition)
            let win = wins.first { $0.paylineID == payline.id }
            #expect(win != nil, "Payline \(payline.id) should win")
            #expect(win?.matchCount == 5)
            #expect(win?.multiplier == 25)
        }
    }

    @Test func threeOfAKindPaysTheThreeCountMultiplier() {
        let payline = definition.paylines[0]
        var testGrid = grid(withTarget: filler, along: payline, fill: filler)
        for reel in 0..<3 { testGrid[reel][payline.rowIndices[reel]] = target }
        // reels 3 and 4 stay filler, breaking the run at 3.
        let wins = PaylineEvaluator.evaluate(grid: testGrid, definition: definition)
        let win = wins.first { $0.paylineID == payline.id }
        #expect(win?.matchCount == 3)
        #expect(win?.multiplier == 5)
    }

    @Test func fourOfAKindPaysTheFourCountMultiplier() {
        let payline = definition.paylines[0]
        var testGrid = grid(withTarget: filler, along: payline, fill: filler)
        for reel in 0..<4 { testGrid[reel][payline.rowIndices[reel]] = target }
        let wins = PaylineEvaluator.evaluate(grid: testGrid, definition: definition)
        let win = wins.first { $0.paylineID == payline.id }
        #expect(win?.matchCount == 4)
        #expect(win?.multiplier == 12)
    }

    @Test func fiveOfAKindPaysTheFiveCountMultiplier() {
        let payline = definition.paylines[0]
        let testGrid = grid(withTarget: target, along: payline, fill: filler)
        let wins = PaylineEvaluator.evaluate(grid: testGrid, definition: definition)
        let win = wins.first { $0.paylineID == payline.id }
        #expect(win?.matchCount == 5)
        #expect(win?.multiplier == 25)
    }

    @Test func wildSubstitutesForRegularSymbols() {
        let payline = definition.paylines[0] // [1,1,1,1,1]
        var testGrid = [[SymbolID]](repeating: [filler, filler, filler], count: 5)
        testGrid[0][1] = wild
        testGrid[1][1] = wild
        testGrid[2][1] = target
        testGrid[3][1] = target
        testGrid[4][1] = filler // breaks the run at 4

        let wins = PaylineEvaluator.evaluate(grid: testGrid, definition: definition)
        let win = wins.first { $0.paylineID == payline.id }
        #expect(win?.symbolID == target)
        #expect(win?.matchCount == 4)
        #expect(win?.multiplier == 12) // Cursed Rune 4-of-a-kind
    }

    @Test func pureWildRunCanWinOnItsOwn() {
        let payline = definition.paylines[1] // [0,0,0,0,0]
        var testGrid = [[SymbolID]](repeating: [filler, filler, filler], count: 5)
        for reel in 0..<5 { testGrid[reel][0] = wild }

        let wins = PaylineEvaluator.evaluate(grid: testGrid, definition: definition)
        let win = wins.first { $0.paylineID == payline.id }
        #expect(win?.symbolID == wild)
        #expect(win?.matchCount == 5)
        #expect(win?.multiplier == 300) // Infernal Crown 5-of-a-kind
    }

    @Test func onlyTheHighestPayingWildCombinationCountsPerLine() {
        // 4 wilds followed by a low-value regular symbol: the all-wild
        // 4-of-a-kind (100x) beats the 5-of-a-kind resolved against the
        // trailing regular symbol (15x).
        let payline = definition.paylines[1] // [0,0,0,0,0]
        var testGrid = [[SymbolID]](repeating: [filler, filler, filler], count: 5)
        for reel in 0..<4 { testGrid[reel][0] = wild }
        testGrid[4][0] = filler // Bone Idol, 5x = 15

        let wins = PaylineEvaluator.evaluate(grid: testGrid, definition: definition)
        let win = wins.first { $0.paylineID == payline.id }
        #expect(win?.symbolID == wild)
        #expect(win?.matchCount == 4)
        #expect(win?.multiplier == 100)
    }

    @Test func scatterSymbolsNeverParticipateInPaylineRuns() {
        let payline = definition.paylines[0]
        var testGrid = [[SymbolID]](repeating: [filler, filler, filler], count: 5)
        testGrid[0][1] = target
        testGrid[1][1] = target
        testGrid[2][1] = InfernalForgeSymbols.riftPortal // scatter breaks the run
        testGrid[3][1] = target
        testGrid[4][1] = target

        let wins = PaylineEvaluator.evaluate(grid: testGrid, definition: definition)
        let win = wins.first { $0.paylineID == payline.id }
        // Only 2 matching symbols before the scatter breaks the run - too
        // short to pay, so there should be no win at all on this line.
        #expect(win == nil)
    }
}
