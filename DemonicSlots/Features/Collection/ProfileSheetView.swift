//
//  ProfileSheetView.swift
//  DemonicSlots
//
//  Popup behind the profile icon on the collection screen. Two states:
//  no username claimed yet (a short form), or already registered (status +
//  a manual "sync now" action). All logic lives in `AccountSyncController` -
//  this view only reads its state and forwards the username the player typed.
//
import SwiftUI
import SwiftData

struct ProfileSheetView: View {
    @Bindable var accountSync: AccountSyncController
    @Environment(\.dismiss) private var dismiss
    @State private var usernameInput = ""
    @FocusState private var usernameFieldFocused: Bool

    // Literal ID, not `PlayerProfile.singletonID`: #Predicate can't
    // type-check a bare `Type.staticMember` access inside its closure. Must
    // stay in sync with that constant.
    @Query(filter: #Predicate<PlayerProfile> { profile in
        profile.profileID == "player.singleton"
    })
    private var profiles: [PlayerProfile]

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                progressionSummary
                if let username = accountSync.username {
                    registeredView(username: username)
                } else {
                    registrationView
                }
                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .top)
            .background(DemonicPalette.obsidianBlack.ignoresSafeArea())
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                        .frame(minHeight: 44)
                }
            }
        }
        .presentationDetents([.medium])
    }

    /// Level/win-bonus breakdown - always shown, online or fully offline,
    /// since level and the win-chance multiplier are independent of
    /// registration (an unregistered player just has the defaults: level 1,
    /// no player multiplier). Shows both contributing multipliers plus the
    /// combined one, computed via `PlayerProgressionService` - never adds
    /// the two percentages together, since the underlying math is a
    /// product of multipliers (see that service's header comment).
    private var progressionSummary: some View {
        let profile = profiles.first
        let level = Int(profile?.level ?? 1)
        let playerMultiplier = profile?.winChanceMultiplier ?? 1.0
        let levelMultiplier = PlayerProgressionService.levelWinMultiplier(forLevel: level)
        let validatedPlayerMultiplier = PlayerProgressionService.validatedWinChanceMultiplier(playerMultiplier)
        let finalMultiplier = levelMultiplier * validatedPlayerMultiplier

        return VStack(spacing: 6) {
            Text("Level \(level)")
                .font(.headline)
                .foregroundStyle(DemonicPalette.boneIvory)
            HStack(spacing: 16) {
                progressionStat(title: "Level-Bonus", multiplier: levelMultiplier)
                progressionStat(title: "Spieler-Bonus", multiplier: validatedPlayerMultiplier)
                progressionStat(title: "Gesamtbonus", multiplier: finalMultiplier, emphasized: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func progressionStat(title: String, multiplier: Double, emphasized: Bool = false) -> some View {
        let percent = PlayerProgressionService.percentBonus(fromMultiplier: multiplier)
        return VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(DemonicPalette.boneIvory.opacity(0.6))
            Text(String(format: "%@%.1f%%", percent >= 0 ? "+" : "", percent))
                .font(emphasized ? .subheadline.weight(.heavy) : .subheadline.weight(.semibold))
                .foregroundStyle(emphasized ? DemonicPalette.emberOrange : DemonicPalette.boneIvory)
        }
        .frame(maxWidth: .infinity)
    }

    private var registrationView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 44))
                .foregroundStyle(DemonicPalette.glowingViolet)

            Text("Online-Profil einrichten")
                .font(.headline)
                .foregroundStyle(DemonicPalette.boneIvory)

            Text("Optional: Wähle einen einmaligen Benutzernamen, um dein Soul-Coin-Guthaben bei bestehender Internetverbindung mit dem Server zu sichern. Das Spiel funktioniert auch weiterhin komplett offline.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(DemonicPalette.boneIvory.opacity(0.7))

            TextField("Benutzername", text: $usernameInput)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($usernameFieldFocused)
                .submitLabel(.done)
                .onSubmit(submitRegistration)
                .frame(minHeight: 44)
                .accessibilityLabel("Benutzername eingeben, 3 bis 20 Zeichen")

            if case .error(let message) = accountSync.state {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(DemonicPalette.hellfireRed)
                    .multilineTextAlignment(.center)
            }

            Button(action: submitRegistration) {
                if accountSync.state == .working {
                    ProgressView().tint(.white)
                } else {
                    Text("Registrieren")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(DemonicPalette.hellfireRed)
            .frame(maxWidth: .infinity, minHeight: 44)
            .disabled(trimmedUsername.isEmpty || accountSync.state == .working)
        }
    }

    private func registeredView(username: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(DemonicPalette.emberOrange)

            Text(username)
                .font(.title3.weight(.bold))
                .foregroundStyle(DemonicPalette.boneIvory)

            if let lastSyncedAt = accountSync.lastSyncedAt {
                Text("Zuletzt synchronisiert: \(lastSyncedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(DemonicPalette.boneIvory.opacity(0.6))
            } else {
                Text("Noch nicht synchronisiert.")
                    .font(.footnote)
                    .foregroundStyle(DemonicPalette.boneIvory.opacity(0.6))
            }

            if case .error(let message) = accountSync.state {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(DemonicPalette.hellfireRed)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await accountSync.syncSilently(reportErrors: true) }
            } label: {
                if accountSync.state == .working {
                    ProgressView().tint(.white)
                } else {
                    Label("Jetzt synchronisieren", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .tint(DemonicPalette.glowingViolet)
            .frame(maxWidth: .infinity, minHeight: 44)
            .disabled(accountSync.state == .working)
        }
    }

    private var trimmedUsername: String {
        usernameInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submitRegistration() {
        guard !trimmedUsername.isEmpty, accountSync.state != .working else { return }
        usernameFieldFocused = false
        Task { await accountSync.register(username: trimmedUsername) }
    }
}
