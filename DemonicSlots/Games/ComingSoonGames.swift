//
//  ComingSoonGames.swift
//  DemonicSlots
//
//  Lightweight, structurally-valid placeholder definitions for the slot
//  games planned beyond version 1. They exist purely so the collection
//  screen can render their cards (marked "Bald verfügbar") straight from
//  `GameRegistry` - none of them are ever opened as a playable machine.
//  Replace each with a full `SlotGameDefinition` (its own symbols, reels,
//  paytable, theme...) under `Games/<Name>` when that game ships.
//
import Foundation

nonisolated enum ComingSoonGames {
    static var placeholders: [SlotGameDefinition] {
        [
            makePlaceholder(
                rawID: "blood_cathedral",
                displayName: "Blood Cathedral",
                shortDescription: "Ein gotisches Kathedralen-Ritual mit blutroten Fenstern.",
                theme: GameTheme(
                    primaryColorHex: "#190E24",
                    secondaryColorHex: "#08070B",
                    accentColorHex: "#E22D3D",
                    backgroundColorHex: "#08070B",
                    glowColorHex: "#E22D3D",
                    backgroundAssetKey: "bloodCathedral.background",
                    frameAssetKey: "bloodCathedral.frame"
                )
            ),
            makePlaceholder(
                rawID: "abyssal_crypt",
                displayName: "Abyssal Crypt",
                shortDescription: "Versunkene Gruft voller verlorener Seelen.",
                theme: GameTheme(
                    primaryColorHex: "#08070B",
                    secondaryColorHex: "#190E24",
                    accentColorHex: "#6E43FF",
                    backgroundColorHex: "#08070B",
                    glowColorHex: "#6E43FF",
                    backgroundAssetKey: "abyssalCrypt.background",
                    frameAssetKey: "abyssalCrypt.frame"
                )
            ),
            makePlaceholder(
                rawID: "cursed_carnival",
                displayName: "Cursed Carnival",
                shortDescription: "Ein verfluchter Jahrmarkt, der niemals schließt.",
                theme: GameTheme(
                    primaryColorHex: "#190E24",
                    secondaryColorHex: "#08070B",
                    accentColorHex: "#FF7A1A",
                    backgroundColorHex: "#08070B",
                    glowColorHex: "#FF7A1A",
                    backgroundAssetKey: "cursedCarnival.background",
                    frameAssetKey: "cursedCarnival.frame"
                )
            ),
        ]
    }

    private static func makePlaceholder(
        rawID: String,
        displayName: String,
        shortDescription: String,
        theme: GameTheme
    ) -> SlotGameDefinition {
        let symbolID = SymbolID("placeholder")
        let symbol = SlotSymbol(
            id: symbolID,
            displayName: "?",
            kind: .regular,
            assetKey: "\(rawID).placeholderSymbol",
            systemImageFallback: "questionmark.circle",
            tintColorKey: "boneIvory"
        )
        let reelStrips = Array(repeating: [symbolID, symbolID, symbolID], count: 5)
        let payline = Payline(id: 1, rowIndices: [1, 1, 1, 1, 1])
        let paytableEntry = PaytableEntry(symbolID: symbolID, payoutByMatchCount: [3: 1, 4: 1, 5: 1])

        return SlotGameDefinition(
            id: GameID(rawID),
            displayName: displayName,
            shortDescription: shortDescription,
            availability: .comingSoon,
            theme: theme,
            symbols: [symbol],
            reelStrips: reelStrips,
            visibleRows: 3,
            paylines: [payline],
            paytable: [paytableEntry],
            betLevels: [BetLevel(perLine: 1)],
            wildSymbolID: nil,
            scatterSymbolID: nil,
            freeSpinsRules: nil,
            cardAssetKey: "\(rawID).card",
            audioKeys: SlotAudioKeys(reelStop: "", spinLoop: "", lineWin: "", bigWin: "", scatterHit: "", bonusEnter: "", background: ""),
            animationKeys: SlotAnimationKeys(smokeParticle: "", emberParticle: "", winParticle: "", riftTransition: "")
        )
    }
}
