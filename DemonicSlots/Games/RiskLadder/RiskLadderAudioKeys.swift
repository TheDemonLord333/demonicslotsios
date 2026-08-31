//
//  RiskLadderAudioKeys.swift
//  DemonicSlots
//
//  Stable `AudioService` lookup keys for Demonic Risk Ladder. Not
//  `SlotAudioKeys` - that type's fields (reelStop, spinLoop, scatterHit...)
//  are slot-specific and don't map to this game's start/risk/success/loss/
//  jackpot/cash-out sounds, so `RiskLadderDefinition.audioKeys` is left
//  empty and this game reads these keys directly instead. A key that
//  resolves to no bundled file is a silent no-op in `AudioService`, never a
//  crash - real audio assets can be dropped in under
//  `Resources/Games/RiskLadder/Audio/<key>.wav` at any time without any
//  code change.
//
import Foundation

nonisolated enum RiskLadderAudioKeys {
    static let roundStart = "riskLadder.roundStart"
    static let risking = "riskLadder.risking"
    static let success = "riskLadder.success"
    static let loss = "riskLadder.loss"
    static let jackpot = "riskLadder.jackpot"
    static let cashOut = "riskLadder.cashOut"
}
