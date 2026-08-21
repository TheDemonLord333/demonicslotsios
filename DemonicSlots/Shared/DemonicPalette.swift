//
//  DemonicPalette.swift
//  DemonicSlots
//
//  App-wide color palette plus a `Color(hex:)` helper so games can store
//  their theme as plain hex strings in a Codable `GameTheme`.
//
import SwiftUI

nonisolated enum DemonicPalette {
    static let obsidianBlack = Color(hex: "#08070B")
    static let darkViolet = Color(hex: "#190E24")
    static let hellfireRed = Color(hex: "#E22D3D")
    static let glowingViolet = Color(hex: "#6E43FF")
    static let emberOrange = Color(hex: "#FF7A1A")
    static let boneIvory = Color(hex: "#E8DEC9")

    /// Resolves a symbol's `tintColorKey` to a concrete color. Unknown keys
    /// fall back to bone ivory rather than crashing or rendering invisibly.
    static func color(forKey key: String) -> Color {
        switch key {
        case "obsidianBlack": return obsidianBlack
        case "darkViolet": return darkViolet
        case "hellfireRed": return hellfireRed
        case "glowingViolet": return glowingViolet
        case "emberOrange": return emberOrange
        case "boneIvory": return boneIvory
        default: return boneIvory
        }
    }
}

extension Color {
    /// Creates a color from a `#RRGGBB` or `#RRGGBBAA` hex string. Malformed
    /// input falls back to bone ivory instead of crashing.
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized.removeAll { $0 == "#" }

        var value: UInt64 = 0
        guard Scanner(string: sanitized).scanHexInt64(&value), sanitized.count == 6 || sanitized.count == 8 else {
            self = Color(red: 0.91, green: 0.87, blue: 0.79)
            return
        }

        let alpha: Double
        let red: Double
        let green: Double
        let blue: Double

        if sanitized.count == 8 {
            red = Double((value & 0xFF00_0000) >> 24) / 255
            green = Double((value & 0x00FF_0000) >> 16) / 255
            blue = Double((value & 0x0000_FF00) >> 8) / 255
            alpha = Double(value & 0x0000_00FF) / 255
        } else {
            red = Double((value & 0xFF_0000) >> 16) / 255
            green = Double((value & 0x00_FF00) >> 8) / 255
            blue = Double(value & 0x00_00FF) / 255
            alpha = 1
        }

        self = Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}
