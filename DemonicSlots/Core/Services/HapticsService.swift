//
//  HapticsService.swift
//  DemonicSlots
//
//  Thin wrapper over UIKit's native feedback generators. Fully mutable via
//  `UserSettings.isHapticsEnabled` and safe to call from anywhere - it never
//  crashes if haptics are unsupported on the current device.
//
import UIKit

enum WinIntensity {
    case small
    case medium
    case big
}

@MainActor
final class HapticsService {
    private let isEnabledProvider: () -> Bool

    init(isEnabledProvider: @escaping () -> Bool) {
        self.isEnabledProvider = isEnabledProvider
    }

    func reelStop() {
        guard isEnabledProvider() else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func win(intensity: WinIntensity) {
        guard isEnabledProvider() else { return }
        switch intensity {
        case .small:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .big:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    func selection() {
        guard isEnabledProvider() else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// A failure/loss moment (e.g. a missed Risk Ladder climb). Distinct
    /// from `win(intensity: .big)`, which uses the `.success` notification
    /// feedback - this is the `.error` one.
    func loss() {
        guard isEnabledProvider() else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
