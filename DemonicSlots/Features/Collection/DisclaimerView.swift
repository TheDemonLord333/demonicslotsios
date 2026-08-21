//
//  DisclaimerView.swift
//  DemonicSlots
//
//  The entertainment-only disclaimer, shown on first launch and always
//  reachable from the Info screen. Wording is fixed per spec.
//
import SwiftUI

struct DisclaimerView: View {
    var onAcknowledge: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "flame.fill")
                .font(.system(size: 48))
                .foregroundStyle(DemonicPalette.emberOrange)
                .accessibilityHidden(true)

            Text("Nur zur Unterhaltung.\nKein Echtgeld, keine Gewinne und keine Auszahlung möglich.")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(DemonicPalette.boneIvory)

            Text("„Demonic Slots“ verwendet ausschließlich virtuelle Soul Coins ohne echten Geldwert. Es gibt keine Echtgeld-Einsätze, keine Auszahlungen, keine In-App-Käufe und keine Werbung.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(DemonicPalette.boneIvory.opacity(0.75))

            if let onAcknowledge {
                Button(action: onAcknowledge) {
                    Text("Verstanden")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(DemonicPalette.hellfireRed)
                .frame(minHeight: 44)
                .accessibilityHint("Bestätigt den Hinweis und öffnet die Spielhalle")
            }
        }
        .padding(28)
        .background(DemonicPalette.obsidianBlack.ignoresSafeArea())
    }
}

#Preview {
    DisclaimerView(onAcknowledge: {})
}
