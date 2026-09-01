//
//  RiskLadderStakeControlView.swift
//  DemonicSlots
//
//  Stake stepper plus MAX, shown only while choosing a stake before a round
//  starts. Reuses `BetLevel` (the same type the slot's bet picker uses) so
//  there's no second stake data model - only the copy differs from
//  `BetControlView`, since "Einsatz/Linie" and a per-line total don't apply
//  to a flat Risk Ladder stake.
//
import SwiftUI

struct RiskLadderStakeControlView: View {
    let stakeLevels: [BetLevel]
    let selectedStake: Int64
    let isEnabled: Bool
    let onSelect: (Int64) -> Void
    let onMaxStake: () -> Void

    private var currentIndex: Int {
        stakeLevels.firstIndex(where: { $0.perLine == selectedStake }) ?? 0
    }

    var body: some View {
        HStack(spacing: 14) {
            Button(action: stepDown) {
                Image(systemName: "minus.circle.fill").font(.title2)
            }
            .frame(minWidth: 44, minHeight: 44)
            .disabled(!isEnabled || currentIndex <= 0)
            .accessibilityLabel("Einsatz verringern")

            VStack(spacing: 2) {
                Text("Einsatz")
                    .font(.caption)
                    .foregroundStyle(DemonicPalette.boneIvory.opacity(0.7))
                Text("\(selectedStake)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(DemonicPalette.boneIvory)
            }
            .frame(minWidth: 90)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Einsatz \(selectedStake) Soul Coins")

            Button(action: stepUp) {
                Image(systemName: "plus.circle.fill").font(.title2)
            }
            .frame(minWidth: 44, minHeight: 44)
            .disabled(!isEnabled || currentIndex >= stakeLevels.count - 1)
            .accessibilityLabel("Einsatz erhöhen")

            Button("MAX", action: onMaxStake)
                .buttonStyle(.bordered)
                .tint(DemonicPalette.hellfireRed)
                .frame(minHeight: 44)
                .disabled(!isEnabled)
        }
        .foregroundStyle(DemonicPalette.boneIvory)
    }

    private func stepDown() {
        guard currentIndex > 0 else { return }
        onSelect(stakeLevels[currentIndex - 1].perLine)
    }

    private func stepUp() {
        guard currentIndex < stakeLevels.count - 1 else { return }
        onSelect(stakeLevels[currentIndex + 1].perLine)
    }
}
