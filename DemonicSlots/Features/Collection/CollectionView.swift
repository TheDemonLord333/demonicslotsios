//
//  CollectionView.swift
//  DemonicSlots
//
//  The app's home screen: a demonic gambling hall, not a slot machine.
//  Reads its games from `GameRegistry` - it never hard-codes "Infernal
//  Forge" or any other title.
//
import SwiftUI
import SwiftData

struct CollectionView: View {
    @Environment(\.modelContext) private var modelContext
    // Literal ID, not `PlayerProfile.singletonID`: #Predicate can't
    // type-check a bare `Type.staticMember` access inside its closure. Must
    // stay in sync with that constant.
    @Query(filter: #Predicate<PlayerProfile> { profile in
        profile.profileID == "player.singleton"
    })
    private var profiles: [PlayerProfile]

    @State private var viewModel: CollectionViewModel?
    @State private var showStatistics = false
    @State private var showSettings = false
    @State private var showInfo = false
    @State private var showProfile = false

    private var balance: Int64 { profiles.first?.soulCoinBalance ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    if let viewModel, viewModel.isSoulRescueAvailable {
                        soulRescueBanner(viewModel: viewModel)
                    }

                    if let viewModel {
                        gameGrid(viewModel: viewModel)
                    }
                }
                .padding(20)
            }
            .background(demonicBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("DEMONIC SLOTS")
                        .font(.headline.weight(.heavy))
                        .tracking(2)
                        .foregroundStyle(DemonicPalette.boneIvory)
                }
            }
            .sheet(isPresented: Binding(
                get: { viewModel?.showFirstLaunchDisclaimer ?? false },
                set: { newValue in viewModel?.showFirstLaunchDisclaimer = newValue }
            )) {
                DisclaimerView {
                    viewModel?.acknowledgeDisclaimer()
                }
                .interactiveDismissDisabled()
            }
            .sheet(isPresented: $showStatistics) { StatisticsView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showInfo) { InfoView() }
            .sheet(isPresented: $showProfile) {
                if let viewModel {
                    ProfileSheetView(accountSync: viewModel.accountSync)
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = CollectionViewModel(context: modelContext)
                }
                // Opportunistic: does nothing if offline or no account is
                // registered yet, per BackendSyncService's contract.
                Task { await viewModel?.accountSync.syncSilently() }
            }
        }
        .tint(DemonicPalette.emberOrange)
        .preferredColorScheme(.dark)
    }

    private var demonicBackground: some View {
        LinearGradient(
            colors: [DemonicPalette.obsidianBlack, DemonicPalette.darkViolet, DemonicPalette.obsidianBlack],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Demonic Slots")
                        .font(.largeTitle.weight(.heavy))
                        .foregroundStyle(DemonicPalette.boneIvory)
                    Text("Deine dämonische Spielhalle")
                        .font(.subheadline)
                        .foregroundStyle(DemonicPalette.boneIvory.opacity(0.6))
                }
                Spacer()
                profileButton
            }

            HStack(spacing: 10) {
                Image(systemName: "flame.circle.fill")
                    .foregroundStyle(DemonicPalette.emberOrange)
                Text("\(balance) Soul Coins")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DemonicPalette.boneIvory)
                    .contentTransition(.numericText())
                    .animation(.default, value: balance)
                Spacer()
                toolbarButtons
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Kontostand: \(balance) Soul Coins")
        }
    }

    private var profileButton: some View {
        let isRegistered = viewModel?.accountSync.isRegistered ?? false
        return Button {
            showProfile = true
        } label: {
            Image(systemName: isRegistered ? "person.crop.circle.fill" : "person.crop.circle")
                .font(.title2)
                .frame(width: 44, height: 44)
        }
        .foregroundStyle(DemonicPalette.boneIvory)
        .background(.white.opacity(0.06), in: Circle())
        .accessibilityLabel(isRegistered ? "Profil: \(viewModel?.accountSync.username ?? "")" : "Profil einrichten")
    }

    private var toolbarButtons: some View {
        HStack(spacing: 8) {
            iconButton(system: "chart.bar.fill", label: "Statistiken") { showStatistics = true }
            iconButton(system: "gearshape.fill", label: "Einstellungen") { showSettings = true }
            iconButton(system: "info.circle.fill", label: "Info") { showInfo = true }
        }
    }

    private func iconButton(system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.title3)
                .frame(width: 44, height: 44)
        }
        .foregroundStyle(DemonicPalette.boneIvory)
        .background(.white.opacity(0.06), in: Circle())
        .accessibilityLabel(label)
    }

    private func soulRescueBanner(viewModel: CollectionViewModel) -> some View {
        Button {
            viewModel.claimSoulRescue()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Soul Rescue verfügbar")
                        .font(.headline)
                    Text("Erhalte einmal pro Tag 1.000 Soul Coins geschenkt.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
            .background(DemonicPalette.glowingViolet.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(DemonicPalette.glowingViolet, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .foregroundStyle(DemonicPalette.boneIvory)
        .frame(minHeight: 44)
        .accessibilityHint("Holt eine kostenlose Gutschrift von 1.000 Soul Coins ab")
    }

    private func gameGrid(viewModel: CollectionViewModel) -> some View {
        let games = viewModel.games
        let featured = games.first
        let rest = games.dropFirst()
        let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

        return VStack(alignment: .leading, spacing: 16) {
            if let featured {
                NavigationLink(value: featured.id) {
                    GameCardView(definition: featured, isFeatured: true)
                }
                .buttonStyle(.plain)
                .disabled(featured.availability != .available)
            }

            Text("Weitere Spiele")
                .font(.headline)
                .foregroundStyle(DemonicPalette.boneIvory.opacity(0.8))

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(rest)) { game in
                    NavigationLink(value: game.id) {
                        GameCardView(definition: game)
                    }
                    .buttonStyle(.plain)
                    .disabled(game.availability != .available)
                }
            }
        }
        .navigationDestination(for: GameID.self) { gameID in
            if let definition = viewModel.registry.definition(for: gameID), definition.availability == .available {
                SlotMachineView(definition: definition, plugin: viewModel.registry.plugin(for: gameID))
            }
        }
    }
}

#Preview {
    CollectionView()
        .modelContainer(PersistenceController.makeInMemoryModelContainer())
}
