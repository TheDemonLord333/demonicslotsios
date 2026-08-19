# Infernal Forge Assets

This folder is where real artwork/audio for **Infernal Forge** belongs once
it exists. Nothing in the engine or UI hard-codes a dependency on real
files being present here - every asset is looked up by a stable *key*
(`assetKey`, `cardAssetKey`, entries in `SlotAudioKeys` / `SlotAnimationKeys`
on `InfernalForgeDefinition`), and every lookup falls back to a SwiftUI
shape/gradient/SF Symbol placeholder when the key doesn't resolve to a real
asset. Missing files here never crash the app.

## Expected keys

| Key | Used for |
|---|---|
| `infernalForge.background` | Slot machine background art |
| `infernalForge.frame` | Reel frame art |
| `infernalForge.card` | Collection screen game card art |
| `infernalForge.emberSigil` ... `infernalForge.infernalCrown`, `infernalForge.riftPortal` | Symbol artwork (see `InfernalForgeSymbols`) |
| `infernalForge.reelStop`, `spinLoop`, `lineWin`, `bigWin`, `scatterHit`, `bonusEnter` | Sound effects (AVFoundation, resolved by `AudioService`) |
| `infernalForge.smoke`, `ember`, `winSpark`, `riftTransition` | SpriteKit particle/animation keys (resolved by `SlotParticleScene`) |

## Adding real art

1. Drop image/audio files into this folder (or the app's Asset Catalog,
   using the same key as the asset name).
2. Update the placeholder-resolution helpers in
   `Features/SlotMachine/SymbolArtwork.swift` and `DemonicPalette.swift` to
   prefer the real asset when present - they already check for it first.
3. No other code changes are required; the definition's keys don't change.
