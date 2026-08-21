//
//  SlotMachineState.swift
//  DemonicSlots
//
//  Explicit state machine driving a single slot machine session. The spin
//  button, bet controls, navigation and game switching are only enabled in
//  the states that legitimately allow them - `SpinSessionController` is the
//  single source of truth for the current state.
//
import Foundation

enum SlotMachineState: Equatable, Sendable {
    case idle
    case preparing
    case spinning
    case stopping
    case evaluating
    case celebrating
    case enteringBonus
    case bonusSummary
    case error(message: String)

    /// Whether user-initiated actions (spin, bet change, navigation away)
    /// are allowed while in this state.
    var allowsUserInteraction: Bool {
        switch self {
        case .idle, .bonusSummary, .error:
            return true
        case .preparing, .spinning, .stopping, .evaluating, .celebrating, .enteringBonus:
            return false
        }
    }
}
