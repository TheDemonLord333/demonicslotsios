# Demonic Risk Ladder Assets

This folder holds real audio for **Demonic Risk Ladder**. Nothing in the
controller or UI hard-codes a dependency on any file here - every sound is
looked up by a stable key from `RiskLadderAudioKeys` and resolved at runtime
by `AudioService.playEffect`/`stopEffect`. A key that doesn't resolve to a
bundled file is a silent no-op, never a crash - this game has no art assets
yet either (the ladder itself is drawn entirely in SwiftUI shapes/gradients
by `RiskLadderRungsView`, no image assets needed).

## Audio (`Audio/`)

Six procedurally synthesized `.wav` files (pure waveform synthesis, same
technique as Infernal Forge's `Audio/` folder - no third-party samples),
matching `RiskLadderAudioKeys` one-to-one:

| File | Key | Played by |
|---|---|---|
| `riskLadder.roundStart.wav` | `RiskLadderAudioKeys.roundStart` | `START` pressed, a new round begins |
| `riskLadder.risking.wav` | `RiskLadderAudioKeys.risking` | `RiskLadderSessionController.state == .risking` (climb suspense) |
| `riskLadder.success.wav` | `RiskLadderAudioKeys.success` | `.wonLevel` (a rung was reached) |
| `riskLadder.loss.wav` | `RiskLadderAudioKeys.loss` | `.lost` (a climb failed) |
| `riskLadder.jackpot.wav` | `RiskLadderAudioKeys.jackpot` | `.jackpot` (top rung reached, auto-paid) |
| `riskLadder.cashOut.wav` | `RiskLadderAudioKeys.cashOut` | `.cashedOut` (player took the win) |

All mono 16-bit PCM WAV, which `AudioService` already resolves (it checks
`m4a`/`caf`/`mp3`/`wav`). Swap any file for higher-fidelity artist-made audio
at any time by replacing it under the same filename - no code changes
needed. Regenerate/tweak them with `python3` + `numpy` (same approach as
Infernal Forge's audio - ask for the synthesis script again if it's not
around; only its output is checked into the repo).
