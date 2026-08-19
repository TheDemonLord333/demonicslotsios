//
//  InfoView.swift
//  DemonicSlots
//
//  About/disclaimer screen, always reachable from the collection hub.
//
import SwiftUI

struct InfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    DisclaimerView(onAcknowledge: nil)

                    infoSection(
                        title: "Über Demonic Slots",
                        text: "Eine Sammlung dämonisch-thematischer Slot-Spiele. Alle Einsätze und Gewinne bestehen ausschließlich aus virtuellen Soul Coins ohne realen Geldwert."
                    )
                    infoSection(
                        title: "Datenschutz",
                        text: "Demonic Slots läuft vollständig offline, ohne Login, ohne Backend, ohne Werbung und ohne Erfassung personenbezogener Daten."
                    )
                    infoSection(
                        title: "Soul Rescue",
                        text: "Fällt dein Guthaben unter 10 Soul Coins, kannst du einmal pro Kalendertag kostenlos 1.000 Soul Coins abholen."
                    )
                }
                .padding(20)
            }
            .background(DemonicPalette.obsidianBlack.ignoresSafeArea())
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                        .frame(minHeight: 44)
                }
            }
        }
    }

    private func infoSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(DemonicPalette.boneIvory)
            Text(text)
                .font(.callout)
                .foregroundStyle(DemonicPalette.boneIvory.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    InfoView()
}
