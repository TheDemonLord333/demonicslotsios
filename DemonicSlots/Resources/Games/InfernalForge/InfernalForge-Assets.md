# Infernal Forge Assets

This folder holds real artwork/audio for **Infernal Forge**. Nothing in the
engine or UI hard-codes a dependency on any file here - every asset is
looked up by a stable *key* (`assetKey`, `cardAssetKey`, entries in
`SlotAudioKeys` / `SlotAnimationKeys` on `InfernalForgeDefinition`), and
every lookup falls back to a SwiftUI shape/gradient/SF Symbol placeholder
(for art) or stays silent (for audio) when the key doesn't resolve. Missing
files here never crash the app.

## Audio (`Audio/`)

Seven procedurally synthesized `.wav` files (pure waveform synthesis - no
samples/loops from third parties), matching `InfernalForgeDefinition.audioKeys`
one-to-one and resolved at runtime by `AudioService.playEffect`/
`startBackgroundMusic` via `Bundle.main.url(forResource:withExtension:)`:

| File | Key | Played by |
|---|---|---|
| `infernalForge.reelStop.wav` | `audioKeys.reelStop` | Each reel settling (`SlotMachineView.onReelSettled`) |
| `infernalForge.spinLoop.wav` | `audioKeys.spinLoop` | Start of `.spinning`, stopped on `.stopping` |
| `infernalForge.lineWin.wav` | `audioKeys.lineWin` | `.celebrating`, small/medium win |
| `infernalForge.bigWin.wav` | `audioKeys.bigWin` | `.celebrating`, big win (>= 20x bet) |
| `infernalForge.scatterHit.wav` | `audioKeys.scatterHit` | `.celebrating`/`.enteringBonus` when a scatter win landed |
| `infernalForge.bonusEnter.wav` | `audioKeys.bonusEnter` | `.enteringBonus` (Rift Portal opening) |
| `infernalForge.background.wav` | `audioKeys.background` | Looped ambient bed, started when the machine appears |

Regenerate/tweak them with `python3` + `numpy` (see the DSP synthesis
script used to create them - ask for it again if it's not around; it's not
checked into the repo, only its output is). All are mono 16-bit PCM WAV,
which `AudioService` already resolves (it checks `m4a`/`caf`/`mp3`/`wav`).
Swap any file for higher-fidelity artist-made audio at any time by
replacing it under the same filename - no code changes needed.

## Other expected keys (art/animation - not yet filled in)

| Key | Used for |
|---|---|
| `infernalForge.background` (theme asset key) | Slot machine background art - **note:** shares its string with the `audioKeys.background` music key above; they live in separate lookup systems (Asset Catalog image vs. bundled audio file) so this doesn't collide today, but pick a different name if you add art here to avoid confusion. |
| `infernalForge.frame` | Reel frame art |
| `infernalForge.card` | Collection screen game card art |
| `infernalForge.emberSigil` ... `infernalForge.infernalCrown`, `infernalForge.riftPortal` | Symbol artwork (see `InfernalForgeSymbols`) |
| `infernalForge.smoke`, `ember`, `winSpark`, `riftTransition` | SpriteKit particle/animation keys (resolved by `SlotParticleScene`) |

## Adding real art

1. Drop image files into the app's Asset Catalog, using the same key as
   the asset name.
2. Update the placeholder-resolution helpers in
   `Features/SlotMachine/SymbolArtworkView.swift` and `DemonicPalette.swift`
   to prefer the real asset when present - they already check for it first.
3. No other code changes are required; the definition's keys don't change.
