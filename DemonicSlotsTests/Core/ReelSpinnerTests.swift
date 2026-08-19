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
}
