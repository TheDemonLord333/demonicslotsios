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
}
