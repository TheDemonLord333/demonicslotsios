//
//  RiskLadderTiming.swift
//  DemonicSlots
//
//  Central timing constants for the Risk Ladder suspense/result animation
//  sequence, kept out of any SwiftUI view so both the view layer and
//  `RiskLadderSessionController` agree on the same numbers - same role as
//  `SpinTiming` for the slot.
//
import Foundation

enum RiskLadderTiming {
    /// How long the ladder pulses/builds tension after RISIKO is pressed
    /// before the already-decided outcome is revealed.
    static let suspenseDuration: Double = 1.2
    /// How long the brief "new rung reached" flash holds before returning
    /// to `.ready` for the next decision.
    static let levelWinFlashDuration: Double = 0.9
    /// How long a terminal result (lost / cashed out / jackpot) stays on
    /// screen before the round resets to `.idle`.
    static let resultDisplayDuration: Double = 1.8
}
