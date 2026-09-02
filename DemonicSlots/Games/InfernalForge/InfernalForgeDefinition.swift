//
//  InfernalForgeDefinition.swift
//  DemonicSlots
//
//  The only fully playable game in v1: 5 reels, 3 rows, 10 fixed paylines.
//  Everything about the game - symbols, reels, paylines, paytable, bet
//  levels, wild/scatter roles, free-spin rules and theming - lives in this
//  one `SlotGameDefinition`. It uses `StandardSlotGamePlugin`, i.e. no
//  custom bonus mechanics beyond what the shared engine already provides.
//
//  RTP note: reel strip weights in `InfernalForgeSymbols` are a starting
//  configuration, not a measured result. Run `SlotSimulator.run(...)` for
//  >= 1,000,000 spins in a DEBUG build (see `SettingsView`'s debug section,
//  which calls into `RTPSimulationDebugView`) and retune the weights until
//  observed RTP lands in the 94-96% target band before shipping.
//
import Foundation

nonisolated enum InfernalForgeDefinition {
    static let gameID = GameID("infernal_forge")

    static let paylines: [Payline] = [
        Payline(id: 1, rowIndices: [1, 1, 1, 1, 1]),
        Payline(id: 2, rowIndices: [0, 0, 0, 0, 0]),
        Payline(id: 3, rowIndices: [2, 2, 2, 2, 2]),
        Payline(id: 4, rowIndices: [0, 1, 2, 1, 0]),
        Payline(id: 5, rowIndices: [2, 1, 0, 1, 2]),
        Payline(id: 6, rowIndices: [0, 0, 1, 2, 2]),
        Payline(id: 7, rowIndices: [2, 2, 1, 0, 0]),
        Payline(id: 8, rowIndices: [1, 0, 0, 0, 1]),
        Payline(id: 9, rowIndices: [1, 2, 2, 2, 1]),
        Payline(id: 10, rowIndices: [0, 1, 1, 1, 0]),
    ]

    /// Index 4 in the shared stake ladder (`PlayerProgressionService.
    /// stakeSequenceValue(atIndex:)`) - 250 Soul Coins total bet
    /// (`perLine: 25` × 10 paylines), the game's own long-standing top bet,
    /// becomes the level-1 floor of its bet-tier progression. See
    /// `betLevels`' comment for how the higher tiers are derived from this
    /// same number.
    static let betTierStartIndex = 4

    /// The original 5 hand-picked bet levels, plus one more `perLine`
    /// entry for every bet-tier step level 10, 20, ... `maximumLevel`
    /// unlocks (see `PlayerLevelConfiguration.levelsPerBetTierStep`) -
    /// computed from the shared stake ladder rather than hand-typed, so it
    /// can never drift out of sync with what `betTierStartIndex` actually
    /// promises. `/ 10` converts a ladder value (a *total* bet) back to
    /// `perLine` for this game's 10 fixed paylines.
    static let betLevels: [BetLevel] = {
        let original: [Int64] = [1, 2, 5, 10, 25]
        let tierStepCount = PlayerLevelConfiguration.maximumLevel / PlayerLevelConfiguration.levelsPerBetTierStep
        let higherTiers = (1...tierStepCount).map { step in
            PlayerProgressionService.stakeSequenceValue(atIndex: betTierStartIndex + step) / 10
        }
        return (original + higherTiers).map(BetLevel.init(perLine:))
    }()

    static let paytable: [PaytableEntry] = [
        PaytableEntry(symbolID: InfernalForgeSymbols.emberSigil, payoutByMatchCount: [3: 2, 4: 5, 5: 10]),
        PaytableEntry(symbolID: InfernalForgeSymbols.boneIdol, payoutByMatchCount: [3: 3, 4: 8, 5: 15]),
        PaytableEntry(symbolID: InfernalForgeSymbols.cursedRune, payoutByMatchCount: [3: 5, 4: 12, 5: 25]),
        PaytableEntry(symbolID: InfernalForgeSymbols.demonEye, payoutByMatchCount: [3: 8, 4: 20, 5: 50]),
        PaytableEntry(symbolID: InfernalForgeSymbols.hellhound, payoutByMatchCount: [3: 10, 4: 30, 5: 75]),
        PaytableEntry(symbolID: InfernalForgeSymbols.forgeDemon, payoutByMatchCount: [3: 15, 4: 50, 5: 120]),
        PaytableEntry(symbolID: InfernalForgeSymbols.infernalCrown, payoutByMatchCount: [3: 25, 4: 100, 5: 300]),
    ]

    static let freeSpinsRules = FreeSpinsRules(
        triggerPayouts: [
            ScatterPayout(scatterCount: 3, totalBetMultiplier: 2, freeSpinsAwarded: 8),
            ScatterPayout(scatterCount: 4, totalBetMultiplier: 10, freeSpinsAwarded: 12),
            ScatterPayout(scatterCount: 5, totalBetMultiplier: 50, freeSpinsAwarded: 20),
        ],
        retriggerMinimumScatterCount: 3,
        retriggerFreeSpinsAwarded: 5,
        maxFreeSpins: 50,
        winMultiplier: 2
    )

    static let theme = GameTheme(
        primaryColorHex: "#190E24",
        secondaryColorHex: "#08070B",
        accentColorHex: "#FF7A1A",
        backgroundColorHex: "#08070B",
        glowColorHex: "#E22D3D",
        backgroundAssetKey: "infernalForge.background",
        frameAssetKey: "infernalForge.frame"
    )

    static let audioKeys = SlotAudioKeys(
        reelStop: "infernalForge.reelStop",
        spinLoop: "infernalForge.spinLoop",
        lineWin: "infernalForge.lineWin",
        bigWin: "infernalForge.bigWin",
        scatterHit: "infernalForge.scatterHit",
        bonusEnter: "infernalForge.bonusEnter",
        background: "infernalForge.background"
    )

    static let animationKeys = SlotAnimationKeys(
        smokeParticle: "infernalForge.smoke",
        emberParticle: "infernalForge.ember",
        winParticle: "infernalForge.winSpark",
        riftTransition: "infernalForge.riftTransition"
    )

    static var definition: SlotGameDefinition {
        let reelCount = 5
        return SlotGameDefinition(
            id: gameID,
            displayName: "Infernal Forge",
            shortDescription: "Schmiede dein Glück an den Feuern der Unterwelt.",
            availability: .available,
            theme: theme,
            symbols: InfernalForgeSymbols.all,
            reelStrips: InfernalForgeSymbols.buildReelStrips(reelCount: reelCount),
            visibleRows: 3,
            paylines: paylines,
            paytable: paytable,
            betLevels: betLevels,
            wildSymbolID: InfernalForgeSymbols.infernalCrown,
            scatterSymbolID: InfernalForgeSymbols.riftPortal,
            freeSpinsRules: freeSpinsRules,
            cardAssetKey: "infernalForge.card",
            audioKeys: audioKeys,
            animationKeys: animationKeys,
            betTierStartIndex: betTierStartIndex
        )
    }
}
