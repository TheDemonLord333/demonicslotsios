//
//  StatisticsView.swift
//  DemonicSlots
//
//  Global balance plus per-game aggregated statistics. Reads SwiftData
//  directly via `@Query` - there is no mutation logic on this screen.
//
import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var allStatistics: [GameStatistics]
    // Literal ID, not `PlayerProfile.singletonID`: #Predicate can't
    // type-check a bare `Type.staticMember` access inside its closure. Must
    // stay in sync with that constant.
    @Query(filter: #Predicate<PlayerProfile> { profile in
        profile.profileID == "player.singleton"
    })
    private var profiles: [PlayerProfile]

    private let registry = GameRegistry.shared

    var body: some View {
        NavigationStack {
            List {
                Section("Gesamt") {
                    LabeledContent("Guthaben", value: "\(profiles.first?.soulCoinBalance ?? 0) Soul Coins")
                }

                ForEach(sortedStatistics) { stats in
                    Section(displayName(forRawGameID: stats.gameID)) {
                        LabeledContent("Spins", value: "\(stats.totalSpins)")
                        LabeledContent("Gewinnquote", value: percent(stats.winRate))
                        LabeledContent("Gesamteinsatz", value: "\(stats.totalWagered) Soul Coins")
                        LabeledContent("Gesamtgewinn", value: "\(stats.totalWon) Soul Coins")
                        LabeledContent("Größter Einzelgewinn", value: "\(stats.largestSingleWin) Soul Coins")
                        LabeledContent("Bonusrunden ausgelöst", value: "\(stats.bonusRoundsTriggered)")
                    }
                }

                if allStatistics.isEmpty {
                    Text("Noch keine Spins gespielt.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Statistiken")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                        .frame(minHeight: 44)
                }
            }
        }
    }

    private var sortedStatistics: [GameStatistics] {
        allStatistics.sorted { $0.gameID < $1.gameID }
    }

    private func displayName(forRawGameID rawID: String) -> String {
        registry.definition(for: GameID(rawID))?.displayName ?? rawID
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }
}

#Preview {
    StatisticsView()
        .modelContainer(PersistenceController.makeInMemoryModelContainer())
}
