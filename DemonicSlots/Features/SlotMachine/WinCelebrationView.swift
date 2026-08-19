//
//  WinCelebrationView.swift
//  DemonicSlots
//
//  Overlay shown while `SpinSessionController.state == .celebrating`.
//
import SwiftUI

struct WinCelebrationView: View {
    let amount: Int64
    let isBigWin: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(isBigWin ? "GROSSER GEWINN!" : "GEWINN!")
                .font(.headline.weight(.heavy))
                .tracking(1.5)
                .foregroundStyle(DemonicPalette.emberOrange)
            Text("+\(amount) Soul Coins")
                .font(.system(size: isBigWin ? 36 : 26, weight: .black, design: .rounded))
                .foregroundStyle(DemonicPalette.boneIvory)
                .contentTransition(.numericText())
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(DemonicPalette.emberOrange.opacity(0.6), lineWidth: 1.5)
        )
        .shadow(color: DemonicPalette.emberOrange.opacity(0.5), radius: 20)
        .transition(.scale.combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Gewinn: \(amount) Soul Coins")
    }
}

struct BonusEntryOverlayView: View {
    let freeSpinsAwarded: Int

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "circle.hexagongrid.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(DemonicPalette.glowingViolet)
            Text("RIFT PORTAL GEÖFFNET")
                .font(.title3.weight(.heavy))
                .tracking(1.2)
            Text("\(freeSpinsAwarded) Freispiele")
                .font(.system(size: 30, weight: .black, design: .rounded))
        }
        .foregroundStyle(DemonicPalette.boneIvory)
        .padding(30)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(DemonicPalette.glowingViolet.opacity(0.7), lineWidth: 1.5)
        )
        .shadow(color: DemonicPalette.glowingViolet.opacity(0.6), radius: 28)
        .transition(.scale.combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bonusrunde gestartet mit \(freeSpinsAwarded) Freispielen")
    }
}

struct BonusSummaryOverlayView: View {
    let totalPayout: Int64
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("FREISPIELE BEENDET")
                .font(.title3.weight(.heavy))
                .tracking(1.2)
            Text("Gesamtgewinn: \(totalPayout) Soul Coins")
                .font(.title2.weight(.bold))
            Button("Weiter", action: onContinue)
                .buttonStyle(.borderedProminent)
                .tint(DemonicPalette.hellfireRed)
                .frame(minHeight: 44)
                .accessibilityHint("Kehrt zur Spielansicht zurück")
        }
        .foregroundStyle(DemonicPalette.boneIvory)
        .padding(30)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(DemonicPalette.hellfireRed.opacity(0.7), lineWidth: 1.5)
        )
        .shadow(color: DemonicPalette.hellfireRed.opacity(0.6), radius: 28)
        .accessibilityElement(children: .combine)
    }
}
