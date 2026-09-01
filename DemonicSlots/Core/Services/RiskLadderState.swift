//
//  RiskLadderState.swift
//  DemonicSlots
//
//  Explicit state machine driving one Demonic Risk Ladder round, mirroring
//  `SlotMachineState`'s role for the slot: `RiskLadderSessionController` is
//  the single source of truth for the current state, and the stake picker
//  and RISIKO/GEWINN NEHMEN buttons are only enabled in the states that
//  legitimately allow them - a rapid double-tap can never fire twice.
//
import Foundation

enum RiskLadderState: Equatable, Sendable {
    /// No round active; the player is choosing a stake.
    case idle
    /// A round is active and waiting on a RISIKO/GEWINN NEHMEN decision.
    case ready
    /// A climb attempt's outcome has already been decided and is only
    /// being animated - no input allowed until it settles.
    case risking
    /// Brief "reached a new rung" celebration before returning to `.ready`.
    case wonLevel
    /// The round ended in a failed climb; about to reset to `.idle`.
    case lost
    /// The player cashed out; about to reset to `.idle`.
    case cashedOut
    /// The top rung was reached and paid out automatically; about to reset
    /// to `.idle`.
    case jackpot
    case error(message: String)

    /// Whether user-initiated actions (stake change, RISIKO, GEWINN NEHMEN,
    /// navigation away) are allowed while in this state.
    var allowsUserInteraction: Bool {
        switch self {
        case .idle, .ready, .error:
            return true
        case .risking, .wonLevel, .lost, .cashedOut, .jackpot:
            return false
        }
    }
}
