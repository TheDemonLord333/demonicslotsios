//
//  InfernalForgeSymbols.swift
//  DemonicSlots
//
//  Symbol catalog and reel-strip construction for "Infernal Forge". Reel
//  strips are built from a weight table and a deterministic shuffle so the
//  distribution is easy to read and retune - see the note in
//  `InfernalForgeDefinition` about running `SlotSimulator` to hit the
//  94-96% RTP target.
//
import Foundation

nonisolated enum InfernalForgeSymbols {
    static let emberSigil = SymbolID("infernal_forge.ember_sigil")
    static let boneIdol = SymbolID("infernal_forge.bone_idol")
    static let cursedRune = SymbolID("infernal_forge.cursed_rune")
    static let demonEye = SymbolID("infernal_forge.demon_eye")
    static let hellhound = SymbolID("infernal_forge.hellhound")
    static let forgeDemon = SymbolID("infernal_forge.forge_demon")
    static let infernalCrown = SymbolID("infernal_forge.infernal_crown") // wild
    static let riftPortal = SymbolID("infernal_forge.rift_portal") // scatter

    static var all: [SlotSymbol] {
        [
            SlotSymbol(
                id: emberSigil, displayName: "Ember Sigil", kind: .regular,
                assetKey: "infernalForge.emberSigil", systemImageFallback: "flame",
                tintColorKey: "emberOrange"
            ),
            SlotSymbol(
                id: boneIdol, displayName: "Bone Idol", kind: .regular,
                assetKey: "infernalForge.boneIdol", systemImageFallback: "figure.stand",
                tintColorKey: "boneIvory"
            ),
            SlotSymbol(
                id: cursedRune, displayName: "Cursed Rune", kind: .regular,
                assetKey: "infernalForge.cursedRune", systemImageFallback: "circle.hexagongrid",
                tintColorKey: "glowingViolet"
            ),
            SlotSymbol(
                id: demonEye, displayName: "Demon Eye", kind: .regular,
                assetKey: "infernalForge.demonEye", systemImageFallback: "eye",
                tintColorKey: "hellfireRed"
            ),
            SlotSymbol(
                id: hellhound, displayName: "Hellhound", kind: .regular,
                assetKey: "infernalForge.hellhound", systemImageFallback: "pawprint",
                tintColorKey: "hellfireRed"
            ),
            SlotSymbol(
                id: forgeDemon, displayName: "Forge Demon", kind: .regular,
                assetKey: "infernalForge.forgeDemon", systemImageFallback: "flame.fill",
                tintColorKey: "emberOrange"
            ),
            SlotSymbol(
                id: infernalCrown, displayName: "Infernal Crown", kind: .wild,
                assetKey: "infernalForge.infernalCrown", systemImageFallback: "crown.fill",
                tintColorKey: "glowingViolet"
            ),
            SlotSymbol(
                id: riftPortal, displayName: "Rift Portal", kind: .scatter,
                assetKey: "infernalForge.riftPortal", systemImageFallback: "sparkles",
                tintColorKey: "glowingViolet"
            ),
        ]
    }

    /// Symbol frequency per reel strip, before shuffling. Weighted so the
    /// lowest-paying symbols land most often and the wild/scatter are rare.
    private static let weights: [(SymbolID, Int)] = [
        (emberSigil, 8),
        (boneIdol, 7),
        (cursedRune, 6),
        (demonEye, 5),
        (hellhound, 4),
        (forgeDemon, 3),
        (infernalCrown, 3),
        (riftPortal, 1),
    ]

    /// Builds all 5 reel strips. Each reel uses the same symbol frequency
    /// but a different deterministic shuffle so reels don't look identical.
    static func buildReelStrips(reelCount: Int) -> [[SymbolID]] {
        (0..<reelCount).map { reelIndex in
            buildStrip(seed: UInt64(1_000 + reelIndex))
        }
    }

    private static func buildStrip(seed: UInt64) -> [SymbolID] {
        var strip: [SymbolID] = []
        for (symbol, count) in weights {
            strip.append(contentsOf: Array(repeating: symbol, count: count))
        }
        var rng = SeededRandomSource(seed: seed)
        guard strip.count > 1 else { return strip }
        for index in stride(from: strip.count - 1, to: 0, by: -1) {
            let swapIndex = rng.nextInt(in: 0..<(index + 1))
            strip.swapAt(index, swapIndex)
        }
        return strip
    }
}
