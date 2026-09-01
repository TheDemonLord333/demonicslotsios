//
//  RiskLadderResultOverlayView.swift
//  DemonicSlots
//
//  Terminal-result overlays shown while `RiskLadderSessionController.state`
//  is `.lost` / `.cashedOut` / `.jackpot`, styled after `WinCelebrationView`/
//  `BonusEntryOverlayView` so it reads as the same app, not a different one.
//
import SwiftUI

struct RiskLadderLossOverlayView: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("VERLOREN")
                .font(.headline.weight(.heavy))
                .tracking(1.5)
                .foregroundStyle(DemonicPalette.hellfireRed)
            Text("Die Leiter ist eingestürzt")
                .font(.subheadline)
                .foregroundStyle(DemonicPalette.boneIvory.opacity(0.8))
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(DemonicPalette.hellfireRed.opacity(0.7), lineWidth: 1.5)
        )
        .shadow(color: DemonicPalette.hellfireRed.opacity(0.6), radius: 20)
        .transition(.scale.combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Verloren, Einsatz ist weg")
    }
}

struct RiskLadderCashOutOverlayView: View {
    let amount: Int64

    var body: some View {
        VStack(spacing: 6) {
            Text("GEWINN GENOMMEN")
                .font(.headline.weight(.heavy))
                .tracking(1.5)
                .foregroundStyle(DemonicPalette.emberOrange)
            Text("+\(amount) Soul Coins")
                .font(.system(size: 30, weight: .black, design: .rounded))
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
        .accessibilityLabel("Gewinn genommen: \(amount) Soul Coins")
    }
}

struct RiskLadderJackpotOverlayView: View {
    let amount: Int64

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "crown.fill")
                .font(.system(size: 52))
                .foregroundStyle(DemonicPalette.emberOrange)
            Text("JACKPOT!")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(DemonicPalette.emberOrange)
            Text("+\(amount) Soul Coins")
                .font(.title2.weight(.heavy))
                .foregroundStyle(DemonicPalette.boneIvory)
                .contentTransition(.numericText())
        }
        .padding(30)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(DemonicPalette.emberOrange.opacity(0.8), lineWidth: 2)
        )
        .shadow(color: DemonicPalette.emberOrange.opacity(0.7), radius: 30)
        .transition(.scale.combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Jackpot! \(amount) Soul Coins gewonnen")
    }
}
