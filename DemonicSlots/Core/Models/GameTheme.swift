//
//  GameTheme.swift
//  DemonicSlots
//

import Foundation

/// Per-game color and asset theming. Colors are stored as `#RRGGBB` hex
/// strings so the definition stays a plain, Codable value type; the UI
/// layer resolves them to `Color` via `Color(hex:)`.
nonisolated struct GameTheme: Codable, Hashable, Sendable {
    var primaryColorHex: String
    var secondaryColorHex: String
    var accentColorHex: String
    var backgroundColorHex: String
    var glowColorHex: String
    /// Lookup key for a background asset/placeholder gradient.
    var backgroundAssetKey: String
    /// Lookup key for the reel frame asset/placeholder.
    var frameAssetKey: String

    init(
        primaryColorHex: String,
        secondaryColorHex: String,
        accentColorHex: String,
        backgroundColorHex: String,
        glowColorHex: String,
        backgroundAssetKey: String,
        frameAssetKey: String
    ) {
        self.primaryColorHex = primaryColorHex
        self.secondaryColorHex = secondaryColorHex
        self.accentColorHex = accentColorHex
        self.backgroundColorHex = backgroundColorHex
        self.glowColorHex = glowColorHex
        self.backgroundAssetKey = backgroundAssetKey
        self.frameAssetKey = frameAssetKey
    }
}

/// Stable audio lookup keys for one game. Missing/unresolvable keys are
/// handled silently by `AudioService` (no crash, no sound).
nonisolated struct SlotAudioKeys: Codable, Hashable, Sendable {
    var reelStop: String
    var spinLoop: String
    var lineWin: String
    var bigWin: String
    var scatterHit: String
    var bonusEnter: String
    var background: String

    init(
        reelStop: String,
        spinLoop: String,
        lineWin: String,
        bigWin: String,
        scatterHit: String,
        bonusEnter: String,
        background: String
    ) {
        self.reelStop = reelStop
        self.spinLoop = spinLoop
        self.lineWin = lineWin
        self.bigWin = bigWin
        self.scatterHit = scatterHit
        self.bonusEnter = bonusEnter
        self.background = background
    }
}

/// Stable animation/particle lookup keys for one game.
nonisolated struct SlotAnimationKeys: Codable, Hashable, Sendable {
    var smokeParticle: String
    var emberParticle: String
    var winParticle: String
    var riftTransition: String

    init(
        smokeParticle: String,
        emberParticle: String,
        winParticle: String,
        riftTransition: String
    ) {
        self.smokeParticle = smokeParticle
        self.emberParticle = emberParticle
        self.winParticle = winParticle
        self.riftTransition = riftTransition
    }
}
