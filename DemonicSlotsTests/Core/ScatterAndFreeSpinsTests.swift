//
//  ScatterAndFreeSpinsTests.swift
//  DemonicSlotsTests
//
//  Covers requirements 6 (scatter evaluation) and 7 (free spins, win
//  multiplier, retrigger, and the 50-spin cap).
//
import Testing
@testable import DemonicSlots

struct ScatterAndFreeSpinsTests {
    private let definition = InfernalForgeDefinition.definition
    private let filler = InfernalForgeSymbols.boneIdol
    private let scatter = InfernalForgeSymbols.riftPortal

    private func grid(scatterCount: Int) -> [[SymbolID]] {
        var flatPositions: [(Int, Int)] = []
        for reel in 0..<5 {
            for row in 0..<3 {
                flatPositions.append((reel, row))
            }
        }
        var testGrid = [[SymbolID]](repeating: [filler, filler, filler], count: 5)
        for index in 0..<scatterCount {
            let (reel, row) = flatPositions[index]
            testGrid[reel][row] = scatter
        }
        return testGrid
    }

    @Test func fewerThanThreeScattersDoesNotTrigger() {
        let win = ScatterEvaluator.evaluate(grid: grid(scatterCount: 2), definition: definition, totalBet: 100)
        #expect(win == nil)
    }

    @Test func threeScattersAwardTheThreeTierPayout() {
        let win = ScatterEvaluator.evaluate(grid: grid(scatterCount: 3), definition: definition, totalBet: 100)
        #expect(win?.count == 3)
        #expect(win?.payout == 200) // 2x total bet
        #expect(win?.freeSpinsAwarded == 8)
    }

    @Test func fourScattersAwardTheFourTierPayout() {
        let win = ScatterEvaluator.evaluate(grid: grid(scatterCount: 4), definition: definition, totalBet: 100)
        #expect(win?.count == 4)
        #expect(win?.payout == 1_000) // 10x total bet
        #expect(win?.freeSpinsAwarded == 12)
    }

    @Test func fiveScattersAwardTheFiveTierPayout() {
        let win = ScatterEvaluator.evaluate(grid: grid(scatterCount: 5), definition: definition, totalBet: 100)
        #expect(win?.count == 5)
        #expect(win?.payout == 5_000) // 50x total bet
        #expect(win?.freeSpinsAwarded == 20)
    }

    @Test func retriggerRequiresTheConfiguredMinimumScatterCount() {
        let rules = InfernalForgeDefinition.freeSpinsRules
        #expect(!ScatterEvaluator.qualifiesForRetrigger(scatterCount: 2, rules: rules))
        #expect(ScatterEvaluator.qualifiesForRetrigger(scatterCount: 3, rules: rules))
        #expect(ScatterEvaluator.qualifiesForRetrigger(scatterCount: 5, rules: rules))
    }

    @Test func retriggerGrantIsCappedByMaxFreeSpins() {
        let rules = InfernalForgeDefinition.freeSpinsRules // retrigger +5, max 50
        #expect(rules.retriggerGrant(totalAlreadyGranted: 8) == 5)
        #expect(rules.retriggerGrant(totalAlreadyGranted: 47) == 3)
        #expect(rules.retriggerGrant(totalAlreadyGranted: 50) == 0)
        #expect(rules.retriggerGrant(totalAlreadyGranted: 200) == 0) // never negative
    }

    @Test func freeSpinWinMultiplierDoublesLinePayouts() throws {
        let payline = definition.paylines[0]
        let target = InfernalForgeSymbols.cursedRune
        var testGrid = [[SymbolID]](repeating: [filler, filler, filler], count: 5)
        for reel in 0..<5 { testGrid[reel][payline.rowIndices[reel]] = target }
        let variant = TestSupport.infernalForgeVariant(grid: testGrid)

        let engine = SlotEngine()
        var stops: any RandomNumberSource = TestSupport.zeroStops(count: 5)
        let baseEvaluation = try engine.spin(definition: variant, betPerLine: 1, isFreeSpin: false, freeSpinMultiplier: 1, randomSource: &stops)

        var stopsForFreeSpin: any RandomNumberSource = TestSupport.zeroStops(count: 5)
        let freeSpinEvaluation = try engine.spin(definition: variant, betPerLine: 1, isFreeSpin: true, freeSpinMultiplier: 2, randomSource: &stopsForFreeSpin)

        let baseWin = try #require(baseEvaluation.lineWins.first { $0.paylineID == payline.id })
        let freeSpinWin = try #require(freeSpinEvaluation.lineWins.first { $0.paylineID == payline.id })
        #expect(freeSpinWin.multiplier == baseWin.multiplier * 2)
    }
}
