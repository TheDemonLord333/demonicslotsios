//
//  BetControlView.swift
//  DemonicSlots
//
//  Bet-per-line stepper plus MAX BET. All it does is report the player's
//  choice up via `onSelect`/`onMaxBet` - `SpinSessionController` decides
//  whether the choice is currently allowed.
//
import SwiftUI

struct BetControlView: View {
    let betLevels: [BetLevel]
    let selectedBetPerLine: Int64
    let lineCount: Int
    let isEnabled: Bool
    let onSelect: (Int64) -> Void
    let onMaxBet: () -> Void

    private var currentIndex: Int {
        betLevels.firstIndex(where: { $0.perLine == selectedBetPerLine }) ?? 0
    }

    private var totalBet: Int64 { selectedBetPerLine * Int64(lineCount) }

    var body: some View {
        HStack(spacing: 14) {
            Button(action: stepDown) {
                Image(systemName: "minus.circle.fill").font(.title2)
            }
            .frame(minWidth: 44, minHeight: 44)
            .disabled(!isEnabled || currentIndex <= 0)
            .accessibilityLabel("Einsatz verringern")

            VStack(spacing: 2) {
                Text("Einsatz/Linie: \(selectedBetPerLine)")
                    .font(.caption)
                    .foregroundStyle(DemonicPalette.boneIvory.opacity(0.7))
                Text("Gesamt: \(totalBet)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(DemonicPalette.boneIvory)
            }
            .frame(minWidth: 130)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Einsatz pro Linie \(selectedBetPerLine), Gesamteinsatz \(totalBet) Soul Coins")

            Button(action: stepUp) {
                Image(systemName: "plus.circle.fill").font(.title2)
            }
            .frame(minWidth: 44, minHeight: 44)
            .disabled(!isEnabled || currentIndex >= betLevels.count - 1)
            .accessibilityLabel("Einsatz erhöhen")

            Button("MAX BET", action: onMaxBet)
                .buttonStyle(.bordered)
                .tint(DemonicPalette.hellfireRed)
                .frame(minHeight: 44)
                .disabled(!isEnabled)
        }
        .foregroundStyle(DemonicPalette.boneIvory)
    }

    private func stepDown() {
        guard currentIndex > 0 else { return }
        onSelect(betLevels[currentIndex - 1].perLine)
    }

    private func stepUp() {
        guard currentIndex < betLevels.count - 1 else { return }
        onSelect(betLevels[currentIndex + 1].perLine)
    }
}
