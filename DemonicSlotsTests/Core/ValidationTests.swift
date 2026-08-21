//
//  ValidationTests.swift
//  DemonicSlotsTests
//
//  Covers requirement 16: malformed configurations (bad symbol IDs,
//  invalid paylines, missing reels) are reported clearly and never crash
//  the engine.
//
import Testing
@testable import DemonicSlots

struct ValidationTests {
    @Test func validInfernalForgeDefinitionHasNoProblems() {
        #expect(InfernalForgeDefinition.definition.validate().isEmpty)
        #expect(InfernalForgeDefinition.definition.isValid)
    }

    @Test func detectsPaylineLengthMismatch() {
        var definition = InfernalForgeDefinition.definition
        definition.paylines = [Payline(id: 1, rowIndices: [0, 0])] // only 2 entries for 5 reels
        let problems = definition.validate()
        #expect(problems.contains {
            if case .paylineLengthMismatch(let paylineID, let expected, let found) = $0 {
                return paylineID == 1 && expected == 5 && found == 2
            }
            return false
        })
    }

    @Test func detectsPaylineRowOutOfBounds() {
        var definition = InfernalForgeDefinition.definition
        definition.paylines = [Payline(id: 1, rowIndices: [0, 0, 0, 0, 9])]
        let problems = definition.validate()
        #expect(problems.contains { if case .paylineRowOutOfBounds = $0 { return true } else { return false } })
    }

    @Test func detectsUnknownSymbolInReelStrip() {
        var definition = InfernalForgeDefinition.definition
        definition.reelStrips[0] = [SymbolID("does_not_exist")]
        let problems = definition.validate()
        #expect(problems.contains { if case .unknownSymbolInReelStrip = $0 { return true } else { return false } })
    }

    @Test func detectsEmptyReelStrip() {
        var definition = InfernalForgeDefinition.definition
        definition.reelStrips[2] = []
        let problems = definition.validate()
        #expect(problems.contains { if case .reelStripEmpty(let reelIndex) = $0 { return reelIndex == 2 } else { return false } })
    }

    @Test func detectsWildAndScatterBeingTheSameSymbol() {
        var definition = InfernalForgeDefinition.definition
        definition.scatterSymbolID = definition.wildSymbolID
        let problems = definition.validate()
        #expect(problems.contains { if case .wildEqualsScatter = $0 { return true } else { return false } })
    }

    @Test func everyValidationProblemHasAHumanReadableDescription() {
        let empty = SlotGameDefinition(
            id: "empty",
            displayName: "Empty",
            shortDescription: "",
            availability: .comingSoon,
            theme: InfernalForgeDefinition.theme,
            symbols: [],
            reelStrips: [],
            visibleRows: 3,
            paylines: [],
            paytable: [],
            betLevels: [],
            wildSymbolID: nil,
            scatterSymbolID: nil,
            freeSpinsRules: nil,
            cardAssetKey: "",
            audioKeys: InfernalForgeDefinition.audioKeys,
            animationKeys: InfernalForgeDefinition.animationKeys
        )
        let problems = empty.validate()
        #expect(!problems.isEmpty)
        #expect(problems.allSatisfy { $0.errorDescription != nil && !($0.errorDescription!.isEmpty) })
    }

    @Test func engineRefusesToSpinAnInvalidDefinitionInsteadOfCrashing() {
        var definition = InfernalForgeDefinition.definition
        definition.reelStrips = [] // no reels at all
        let engine = SlotEngine()
        var random: any RandomNumberSource = SeededRandomSource(seed: 1)
        #expect(throws: SlotEngineError.self) {
            _ = try engine.spin(definition: definition, betPerLine: 1, isFreeSpin: false, freeSpinMultiplier: 1, randomSource: &random)
        }
    }
}
