//
//  RiskLadderDefinition.swift
//  DemonicSlots
//
//  The catalog entry Demonic Risk Ladder registers in `GameRegistry`,
//  mirroring `InfernalForgeDefinition`'s role for the slot. `kind ==
//  .riskLadder` tells `CollectionView` to open `RiskLadderView` instead of
//  `SlotMachineView`; every reel/payline/symbol field below only exists to
//  satisfy `SlotGameDefinition`'s shape and is never read by that view -
//  same pattern `ComingSoonGames` already uses for its placeholder cards.
//  `betLevels` is the one field that *is* real: it's reused as-is for the
//  stake picker, exactly like a slot's per-line bet levels.
//
import Foundation

nonisolated enum RiskLadderDefinition {
    static let gameID = GameID("risk_ladder")

    static let theme = GameTheme(
        primaryColorHex: "#190E24",
        secondaryColorHex: "#08070B",
        accentColorHex: "#E22D3D",
        backgroundColorHex: "#08070B",
        glowColorHex: "#FF7A1A",
        backgroundAssetKey: "riskLadder.background",
        frameAssetKey: "riskLadder.frame"
    )

    static var definition: SlotGameDefinition {
        let symbolID = SymbolID("placeholder")
        let symbol = SlotSymbol(
            id: symbolID,
            displayName: "?",
            kind: .regular,
            assetKey: "riskLadder.placeholderSymbol",
            systemImageFallback: "questionmark.circle",
            tintColorKey: "boneIvory"
        )
        let payline = Payline(id: 1, rowIndices: [0])
        let paytableEntry = PaytableEntry(symbolID: symbolID, payoutByMatchCount: [1: 1])

        return SlotGameDefinition(
            id: gameID,
            displayName: "Demonic Risk Ladder",
            shortDescription: "Klettere die dämonische Risikoleiter hinauf - oder verliere alles an die Tiefe.",
            availability: .available,
            theme: theme,
            symbols: [symbol],
            reelStrips: [[symbolID]],
            visibleRows: 1,
            paylines: [payline],
            paytable: [paytableEntry],
            betLevels: RiskLadderConfiguration.stakeLevels,
            wildSymbolID: nil,
            scatterSymbolID: nil,
            freeSpinsRules: nil,
            cardAssetKey: "riskLadder.card",
            audioKeys: SlotAudioKeys(reelStop: "", spinLoop: "", lineWin: "", bigWin: "", scatterHit: "", bonusEnter: "", background: ""),
            animationKeys: SlotAnimationKeys(smokeParticle: "", emberParticle: "", winParticle: "", riftTransition: ""),
            kind: .riskLadder,
            betTierStartIndex: RiskLadderConfiguration.betTierStartIndex
        )
    }
}
