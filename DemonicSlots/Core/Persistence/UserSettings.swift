//
//  UserSettings.swift
//  DemonicSlots
//
//  Durable app-wide preferences. There is exactly one row per install.
//
import Foundation
import SwiftData

@Model
final class UserSettings {
    @Attribute(.unique) var settingsID: String
    var isAudioEnabled: Bool
    var isMusicEnabled: Bool
    var isHapticsEnabled: Bool
    /// User-requested reduced motion, honored in addition to the system
    /// "Reduce Motion" accessibility setting.
    var prefersReducedMotion: Bool

    init(
        settingsID: String = UserSettings.singletonID,
        isAudioEnabled: Bool = true,
        isMusicEnabled: Bool = true,
        isHapticsEnabled: Bool = true,
        prefersReducedMotion: Bool = false
    ) {
        self.settingsID = settingsID
        self.isAudioEnabled = isAudioEnabled
        self.isMusicEnabled = isMusicEnabled
        self.isHapticsEnabled = isHapticsEnabled
        self.prefersReducedMotion = prefersReducedMotion
    }

    static let singletonID = "settings.singleton"
}
