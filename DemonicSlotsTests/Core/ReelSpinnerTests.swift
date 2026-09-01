//
//  ReelSpinnerTests.swift
//  DemonicSlotsTests
//
//  Covers requirement 1: computing visible symbols from stop indices.
//
import Testing
@testable import DemonicSlots

struct ReelSpinnerTests {
    @Test func visibleGridReadsCyclicallyFromStopIndex() {
        let strip: [SymbolID] = ["a", "b", "c", "d"]
        let grid = ReelSpinner.visibleGrid(
            stopIndices: [3],
            reelStrips: [strip],
            visibleRows: 3,
            placeholderSymbol: "placeholder"
        )
        #expect(grid == [["d", "a", "b"]])
    }

    @Test func visibleGridHandlesEmptyStripWithoutCrashing() {
        let grid = ReelSpinner.visibleGrid(
            stopIndices: [0],
            reelStrips: [[]],
            visibleRows: 3,
            placeholderSymbol: "placeholder"
        )
        #expect(grid == [["placeholder", "placeholder", "placeholder"]])
    }

    @Test func stopIndicesStayWithinEachStripsBounds() {
        var random: any RandomNumberSource = SeededRandomSource(seed: 42)
        let strips: [[SymbolID]] = [["a", "b", "c"], ["a", "b", "c", "d", "e"]]
        let stops = ReelSpinner.stopIndices(for: strips, randomSource: &random)
        #expect(stops.count == 2)
        #expect(stops[0] >= 0 && stops[0] < 3)
        #expect(stops[1] >= 0 && stops[1] < 5)
    }

    @Test func seededRandomSourceIsFullyDeterministic() {
        var a: any RandomNumberSource = SeededRandomSource(seed: 7)
        var b: any RandomNumberSource = SeededRandomSource(seed: 7)
        let sequenceA = (0..<25).map { _ in a.nextInt(in: 0..<1_000) }
        let sequenceB = (0..<25).map { _ in b.nextInt(in: 0..<1_000) }
        #expect(sequenceA == sequenceB)
    }

    // MARK: - Win-chance multiplier (see ReelSpinner's header comment)

    @Test func neutralProbabilityContextIsByteForByteIdenticalToTheOriginalRoll() {
        var withContext: any RandomNumberSource = SeededRandomSource(seed: 99)
        var withoutContext: any RandomNumberSource = SeededRandomSource(seed: 99)
        let strips = InfernalForgeSymbols.buildReelStrips(reelCount: 5)
        let definition = InfernalForgeDefinition.definition

        let stopsWithNeutralContext = ReelSpinner.stopIndices(
            for: strips,
            definition: definition,
            probabilityContext: .neutral,
            randomSource: &withContext
        )
        let stopsWithNoContextAtAll = ReelSpinner.stopIndices(for: strips, randomSource: &withoutContext)

        #expect(stopsWithNeutralContext == stopsWithNoContextAtAll)
    }

    @Test func aWinBonusShiftsTheDistributionTowardHigherValueSymbols() {
        let definition = InfernalForgeDefinition.definition
        let strip = definition.reelStrips[0]
        let bonusContext = GameProbabilityContext(finalWinMultiplier: 1.5)

        func landRate(of symbolID: SymbolID, context: GameProbabilityContext, seed: UInt64) -> Double {
            var random: any RandomNumberSource = SeededRandomSource(seed: seed)
            let trials = 20_000
            var hits = 0
            for _ in 0..<trials {
                let stops = ReelSpinner.stopIndices(for: [strip], definition: definition, probabilityContext: context, randomSource: &random)
                if strip[stops[0]] == symbolID { hits += 1 }
            }
            return Double(hits) / Double(trials)
        }

        // forgeDemon is Infernal Forge's highest-paying regular symbol - a
        // win bonus should make it land noticeably more often than at
        // baseline, without ever exceeding what the strip could produce.
        let baselineRate = landRate(of: InfernalForgeSymbols.forgeDemon, context: .neutral, seed: 1)
        let boostedRate = landRate(of: InfernalForgeSymbols.forgeDemon, context: bonusContext, seed: 1)
        #expect(boostedRate > baselineRate)

        // The lowest-paying symbol should land less often under the same bonus.
        let baselineLowRate = landRate(of: InfernalForgeSymbols.emberSigil, context: .neutral, seed: 2)
        let boostedLowRate = landRate(of: InfernalForgeSymbols.emberSigil, context: bonusContext, seed: 2)
        #expect(boostedLowRate < baselineLowRate)
    }

    @Test func stopIndicesStayWithinBoundsEvenWithAWinBonusApplied() {
        let definition = InfernalForgeDefinition.definition
        var random: any RandomNumberSource = SeededRandomSource(seed: 3)
        let context = GameProbabilityContext(finalWinMultiplier: 1.9)
        for _ in 0..<200 {
            let stops = ReelSpinner.stopIndices(for: definition.reelStrips, definition: definition, probabilityContext: context, randomSource: &random)
            for (index, stop) in stops.enumerated() {
                #expect(stop >= 0 && stop < definition.reelStrips[index].count)
            }
        }
    }
}
