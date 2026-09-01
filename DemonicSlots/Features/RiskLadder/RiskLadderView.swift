//
//  RiskLadderView.swift
//  DemonicSlots
//
//  The Demonic Risk Ladder screen, opened from `CollectionView` exactly
//  like `SlotMachineView` is for the slot - same toolbar/balance pattern,
//  same audio/haptics/account-sync wiring, same "controller owns state,
//  view only reacts" split. `RiskLadderSessionController` decides every
//  outcome; this view's job is purely to animate what already happened.
//
import SwiftUI
import SwiftData

struct RiskLadderView: View {
    @Environment(\.modelContext) private var modelContext

    let definition: SlotGameDefinition

    @State private var controller: RiskLadderSessionController?

    var body: some View {
        Group {
            if let controller {
                RiskLadderContentView(definition: definition, controller: controller)
            } else {
                ZStack {
                    DemonicPalette.obsidianBlack.ignoresSafeArea()
                    ProgressView().tint(DemonicPalette.boneIvory)
                }
            }
        }
        .onAppear {
            guard controller == nil else { return }
            controller = RiskLadderSessionController(definition: definition, context: modelContext)
        }
    }
}

private struct RiskLadderContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    // Literal IDs, not `UserSettings.singletonID`/`PlayerProfile.singletonID`:
    // #Predicate can't type-check a bare `Type.staticMember` access inside
    // its closure. Must stay in sync with those constants.
    @Query(filter: #Predicate<UserSettings> { settings in
        settings.settingsID == "settings.singleton"
    })
    private var settingsRows: [UserSettings]
    @Query(filter: #Predicate<PlayerProfile> { profile in
        profile.profileID == "player.singleton"
    })
    private var profiles: [PlayerProfile]

    let definition: SlotGameDefinition
    @Bindable var controller: RiskLadderSessionController

    @State private var hapticsService: HapticsService?
    @State private var audioService: AudioService?
    @State private var accountSync: AccountSyncController?

    private var balance: Int64 { profiles.first?.soulCoinBalance ?? 0 }
    private var settings: UserSettings? { settingsRows.first }
    private var reduceMotion: Bool { systemReduceMotion || (settings?.prefersReducedMotion ?? false) }

    var body: some View {
        ZStack {
            backgroundView

            ScrollView {
                VStack(spacing: 18) {
                    winInfoRow

                    RiskLadderRungsView(
                        levels: RiskLadderConfiguration.levels,
                        currentLevel: controller.currentLevel,
                        isRisking: controller.state == .risking,
                        reduceMotion: reduceMotion
                    )
                    .padding(.horizontal, 4)

                    if controller.state == .idle {
                        RiskLadderStakeControlView(
                            stakeLevels: controller.availableStakeLevels,
                            selectedStake: controller.selectedStake,
                            isEnabled: controller.canSelectStake,
                            onSelect: { stake in
                                controller.selectStake(stake)
                                hapticsService?.selection()
                            },
                            onMaxStake: {
                                controller.selectMaxStake()
                                hapticsService?.selection()
                            }
                        )
                        if let nextLocked = controller.lockedStakeLevels.first {
                            lockedStakeHint(for: nextLocked)
                        }
                    }

                    controlButtons
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }

            overlay
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(!controller.state.allowsUserInteraction)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(definition.displayName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(DemonicPalette.boneIvory)
                    Text("\(balance) Soul Coins")
                        .font(.caption)
                        .foregroundStyle(DemonicPalette.boneIvory.opacity(0.7))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    toggleAudio()
                } label: {
                    Image(systemName: (settings?.isAudioEnabled ?? true) ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                .accessibilityLabel("Audio umschalten")
            }
        }
        .onAppear(perform: setUp)
        .onChange(of: controller.state) { _, newState in
            handleStateChange(newState)
        }
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(hex: definition.theme.backgroundColorHex),
                DemonicPalette.darkViolet,
                DemonicPalette.obsidianBlack,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    /// EINSATZ / AKTUELLER GEWINN / MULTIPLIKATOR, per the spec - "aktueller
    /// Gewinn" doubles as the round's live payout-if-you-cash-out-now value.
    private var winInfoRow: some View {
        HStack {
            infoColumn(title: "Einsatz", value: "\(controller.activeStake)", alignment: .leading)
            Spacer()
            infoColumn(title: "Aktueller Gewinn", value: "\(controller.currentPayout)", alignment: .center, emphasized: true)
            Spacer()
            infoColumn(title: "Multiplikator", value: multiplierText, alignment: .trailing)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var multiplierText: String {
        guard controller.currentLevel > 0 else { return "x0" }
        let value = controller.currentMultiplier
        return value.truncatingRemainder(dividingBy: 1) == 0 ? "x\(Int(value))" : String(format: "x%.1f", value)
    }

    /// Small "🔒 Level X schaltet Y Coins frei" hint for the next stake the
    /// player hasn't unlocked yet - keeps the existing stake stepper
    /// unchanged (it simply never offers a locked stake) while still
    /// showing the player that higher levels unlock more, per the task's
    /// "locked bets" ask.
    private func lockedStakeHint(for locked: (bet: BetLevel, unlockLevel: Int?)) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
            if let unlockLevel = locked.unlockLevel {
                Text("Level \(unlockLevel) schaltet \(locked.bet.perLine) Coins Einsatz frei")
            } else {
                Text("\(locked.bet.perLine) Coins Einsatz noch nicht freigeschaltet")
            }
        }
        .font(.caption)
        .foregroundStyle(DemonicPalette.boneIvory.opacity(0.6))
    }

    private func infoColumn(title: String, value: String, alignment: HorizontalAlignment, emphasized: Bool = false) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(DemonicPalette.boneIvory.opacity(0.6))
            Text(value)
                .font(emphasized ? .title2.weight(.heavy) : .subheadline.weight(.semibold))
                .foregroundStyle(emphasized ? DemonicPalette.emberOrange : DemonicPalette.boneIvory)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    @ViewBuilder
    private var controlButtons: some View {
        switch controller.state {
        case .idle:
            Button(action: startRound) {
                Text("START")
                    .font(.headline.weight(.heavy))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(DemonicPalette.hellfireRed)
            .disabled(!controller.canStart)
            .accessibilityHint("Setzt \(controller.selectedStake) Soul Coins ein und startet eine neue Runde")

        case .error(let message):
            errorOverlay(message: message)

        default:
            VStack(spacing: 12) {
                Button(action: risk) {
                    HStack {
                        Image(systemName: "flame.fill")
                        Text("RISIKO")
                            .font(.headline.weight(.heavy))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(DemonicPalette.hellfireRed)
                .disabled(!controller.canRisk)
                .accessibilityHint(riskAccessibilityHint)

                Button(action: cashOut) {
                    Text("GEWINN NEHMEN")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                }
                .buttonStyle(.bordered)
                .tint(.yellow)
                .disabled(!controller.canCashOut)
                .accessibilityHint("Nimmt \(controller.currentPayout) Soul Coins und beendet die Runde")
            }
        }
    }

    private var riskAccessibilityHint: String {
        guard let probability = controller.nextClimbProbability else { return "Keine weitere Stufe verfügbar" }
        return "Erfolgschance \(Int((probability * 100).rounded())) Prozent"
    }

    @ViewBuilder
    private var overlay: some View {
        switch controller.state {
        case .lost:
            RiskLadderLossOverlayView()
        case .cashedOut:
            RiskLadderCashOutOverlayView(amount: controller.lastRoundPayout)
        case .jackpot:
            RiskLadderJackpotOverlayView(amount: controller.lastRoundPayout)
        default:
            EmptyView()
        }
    }

    private func errorOverlay(message: String) -> some View {
        VStack(spacing: 14) {
            Text("Etwas ist schiefgelaufen")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
            Button("OK") { controller.dismissError() }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
        }
        .foregroundStyle(DemonicPalette.boneIvory)
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .frame(maxWidth: .infinity)
    }

    private func startRound() {
        guard controller.canStart else { return }
        hapticsService?.selection()
        controller.startRound()
        if controller.state == .ready {
            audioService?.playEffect(key: RiskLadderAudioKeys.roundStart)
        }
    }

    private func risk() {
        guard controller.canRisk else { return }
        controller.risk()
    }

    private func cashOut() {
        guard controller.canCashOut else { return }
        controller.cashOut()
    }

    private func setUp() {
        let context = modelContext
        hapticsService = HapticsService(isEnabledProvider: {
            ProfileStore.fetchOrCreateSettings(in: context).isHapticsEnabled
        })
        audioService = AudioService(
            isSoundEnabledProvider: {
                ProfileStore.fetchOrCreateSettings(in: context).isAudioEnabled
            },
            isMusicEnabledProvider: {
                ProfileStore.fetchOrCreateSettings(in: context).isMusicEnabled
            }
        )
        accountSync = AccountSyncController(context: context, wallet: controller.wallet)
    }

    private func toggleAudio() {
        let userSettings = ProfileStore.fetchOrCreateSettings(in: modelContext)
        userSettings.isAudioEnabled.toggle()
        try? modelContext.save()
    }

    private func handleStateChange(_ newState: RiskLadderState) {
        switch newState {
        case .ready:
            break
        case .risking:
            audioService?.playEffect(key: RiskLadderAudioKeys.risking)
        case .wonLevel:
            audioService?.stopEffect(key: RiskLadderAudioKeys.risking)
            audioService?.playEffect(key: RiskLadderAudioKeys.success)
            hapticsService?.win(intensity: controller.currentLevel >= controller.maxLevel - 2 ? .big : .medium)
        case .lost:
            audioService?.stopEffect(key: RiskLadderAudioKeys.risking)
            audioService?.playEffect(key: RiskLadderAudioKeys.loss)
            hapticsService?.loss()
        case .cashedOut:
            audioService?.playEffect(key: RiskLadderAudioKeys.cashOut)
            hapticsService?.win(intensity: .medium)
        case .jackpot:
            audioService?.stopEffect(key: RiskLadderAudioKeys.risking)
            audioService?.playEffect(key: RiskLadderAudioKeys.jackpot)
            hapticsService?.win(intensity: .big)
        case .idle:
            // A round just finished resolving. Opportunistic and silent: no-op
            // offline or without a registered account.
            Task { await accountSync?.syncSilently() }
        case .error:
            break
        }
    }
}

#Preview {
    NavigationStack {
        RiskLadderView(definition: RiskLadderDefinition.definition)
    }
    .modelContainer(PersistenceController.makeInMemoryModelContainer())
}
