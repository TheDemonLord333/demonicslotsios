//
//  SettingsView.swift
//  DemonicSlots
//
//  Audio/haptics/reduced-motion preferences and a confirmation-gated reset
//  of progress and statistics. Balance is never affected by a reset.
//
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    // Literal ID, not `UserSettings.singletonID`: #Predicate can't type-check
    // a bare `Type.staticMember` access inside its closure. Must stay in
    // sync with that constant.
    @Query(filter: #Predicate<UserSettings> { settings in
        settings.settingsID == "settings.singleton"
    })
    private var settingsRows: [UserSettings]

    @State private var showResetConfirmation = false

    private var settings: UserSettings? { settingsRows.first }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ton & Haptik") {
                    Toggle("Soundeffekte", isOn: binding(\.isAudioEnabled))
                    Toggle("Musik", isOn: binding(\.isMusicEnabled))
                    Toggle("Haptisches Feedback", isOn: binding(\.isHapticsEnabled))
                }

                Section("Barrierefreiheit") {
                    Toggle("Bewegung reduzieren", isOn: binding(\.prefersReducedMotion))
                }

                Section {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Text("Fortschritt & Statistiken zurücksetzen")
                    }
                    .frame(minHeight: 44)
                } footer: {
                    Text("Setzt alle Statistiken und laufenden Bonusfortschritt zurück. Dein Soul-Coin-Guthaben bleibt erhalten.")
                }

                #if DEBUG
                Section("Entwicklung") {
                    NavigationLink("RTP-Simulation (Infernal Forge)") {
                        RTPSimulationDebugView()
                    }
                }
                #endif
            }
            .navigationTitle("Einstellungen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                        .frame(minHeight: 44)
                }
            }
            .confirmationDialog(
                "Fortschritt wirklich zurücksetzen?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Zurücksetzen", role: .destructive) { resetProgress() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Diese Aktion kann nicht rückgängig gemacht werden.")
            }
            .onAppear {
                _ = ProfileStore.fetchOrCreateSettings(in: modelContext)
                try? modelContext.save()
            }
        }
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<UserSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings?[keyPath: keyPath] ?? false },
            set: { newValue in
                let liveSettings = ProfileStore.fetchOrCreateSettings(in: modelContext)
                liveSettings[keyPath: keyPath] = newValue
                try? modelContext.save()
            }
        )
    }

    private func resetProgress() {
        if let allStatistics = try? modelContext.fetch(FetchDescriptor<GameStatistics>()) {
            for statistics in allStatistics { statistics.reset() }
        }
        if let allProgress = try? modelContext.fetch(FetchDescriptor<GameProgress>()) {
            for progress in allProgress { progress.endBonusRound() }
        }
        try? modelContext.save()
    }
}

#Preview {
    SettingsView()
        .modelContainer(PersistenceController.makeInMemoryModelContainer())
}
