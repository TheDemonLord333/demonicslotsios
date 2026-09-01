//
//  SlotMachineView.swift
//  DemonicSlots
//
//  The reusable slot machine screen. Everything game-specific comes from
//  the injected `SlotGameDefinition`/`SlotGamePlugin` - this view never
//  hard-codes "Infernal Forge". All game logic lives in
//  `SpinSessionController`; this view only reads its state and forwards
//  user intents.
//
import SwiftUI
import SwiftData

struct SlotMachineView: View {
    @Environment(\.modelContext) private var modelContext

    let definition: SlotGameDefinition
    let plugin: (any SlotGamePlugin)?

    @State private var controller: SpinSessionController?

    var body: some View {
        Group {
            if let controller {
                SlotMachineContentView(definition: definition, controller: controller)
            } else {
                ZStack {
                    DemonicPalette.obsidianBlack.ignoresSafeArea()
                    ProgressView().tint(DemonicPalette.boneIvory)
                }
            }
        }
        .onAppear {
            guard controller == nil else { return }
            controller = SpinSessionController(definition: definition, plugin: plugin, context: modelContext)
        }
    }
}

private struct SlotMachineContentView: View {
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
    @Bindable var controller: SpinSessionController

    @State private var spinToken = 0
    @State private var showPaytable = false
    @State private var particleScene = SlotParticleScene(size: CGSize(width: 360, height: 480))
    @State private var hapticsService: HapticsService?
    @State private var audioService: AudioService?
    @State private var accountSync: AccountSyncController?

    private var balance: Int64 { profiles.first?.soulCoinBalance ?? 0 }
    private var settings: UserSettings? { settingsRows.first }
    private var reduceMotion: Bool { systemReduceMotion || (settings?.prefersReducedMotion ?? false) }
    private var showLines: Bool {
        controller.state == .evaluating || controller.state == .celebrating || controller.state == .enteringBonus
    }

    var body: some View {
        ZStack {
            backgroundView
            SlotParticleLayerView(scene: particleScene)

            VStack(spacing: 16) {
                ReelsGridView(
                    definition: definition,
                    evaluation: controller.currentEvaluation,
                    spinToken: spinToken,
                    reduceMotion: reduceMotion,
                    showPaylines: showLines,
                    onReelSettled: {
                        hapticsService?.reelStop()
                        audioService?.playEffect(key: definition.audioKeys.reelStop)
                    }
                )

                infoRow

                BetControlView(
                    betLevels: controller.availableBetLevels,
                    selectedBetPerLine: controller.selectedBetPerLine,
                    lineCount: definition.activeLineCount,
                    isEnabled: controller.canSpin && !controller.isInBonusRound,
                    onSelect: { perLine in
                        controller.selectBet(perLine: perLine)
                        hapticsService?.selection()
                    },
                    onMaxBet: {
                        controller.selectMaxBet()
                        hapticsService?.selection()
                    }
                )
                if let nextLocked = controller.lockedBetLevels.first {
                    lockedBetHint(for: nextLocked)
                }

                spinButton
                footerButtons
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 16)

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
        }
        .onAppear(perform: setUp)
        .onChange(of: controller.state) { _, newState in
            handleStateChange(newState)
        }
        .sheet(isPresented: $showPaytable) {
            PaytableSheetView(definition: definition)
        }
        .task {
            await ambientSmokeLoop()
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

    private var infoRow: some View {
        VStack(spacing: 8) {
            winStatsRow
            if controller.isInBonusRound {
                freeSpinsBadge
            }
        }
    }

    /// Three win figures side by side: the sticky last non-zero win on the
    /// left, this round's result emphasized in the middle, and the
    /// all-time single-spin high score on the right.
    private var winStatsRow: some View {
        // The side columns get a fixed width and the center one is the only
        // `.frame(maxWidth: .infinity)` view in the row, so it alone claims
        // the remaining space - giving it *also* a competing flexible frame
        // (as an earlier version of this did, via `.layoutPriority`) made it
        // greedily take the whole row's width before the sides were even
        // asked, squeezing "Letzter Gewinn"/"Highscore" down to nothing.
        HStack(alignment: .bottom, spacing: 8) {
            winStatColumn(
                title: "Letzter Gewinn",
                value: controller.lastNonZeroWinAmount,
                frameAlignment: .leading,
                fixedWidth: 92,
                valueFont: .subheadline.weight(.semibold),
                valueColor: DemonicPalette.boneIvory.opacity(0.85)
            )

            winStatColumn(
                title: "Aktueller Gewinn",
                value: controller.lastWinAmount,
                frameAlignment: .center,
                fixedWidth: nil,
                valueFont: .title.weight(.heavy),
                valueColor: controller.lastWinAmount > 0 ? DemonicPalette.emberOrange : DemonicPalette.boneIvory
            )
            .shadow(color: (controller.lastWinAmount > 0 ? DemonicPalette.emberOrange : .clear).opacity(0.7), radius: 10)

            winStatColumn(
                title: "Highscore",
                value: controller.highScoreWin,
                frameAlignment: .trailing,
                fixedWidth: 92,
                valueFont: .subheadline.weight(.semibold),
                valueColor: DemonicPalette.glowingViolet
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Letzter Gewinn \(controller.lastNonZeroWinAmount) Coins, " +
            "aktueller Gewinn \(controller.lastWinAmount) Coins, " +
            "Highscore \(controller.highScoreWin) Coins"
        )
    }

    @ViewBuilder
    private func winStatColumn(
        title: String,
        value: Int64,
        frameAlignment: Alignment,
        fixedWidth: CGFloat?,
        valueFont: Font,
        valueColor: Color
    ) -> some View {
        let label = VStack(alignment: frameAlignment.horizontal, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(DemonicPalette.boneIvory.opacity(0.6))
            Text("\(value)")
                .font(valueFont)
                .foregroundStyle(valueColor)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        if let fixedWidth {
            label.frame(width: fixedWidth, alignment: frameAlignment)
        } else {
            label.frame(maxWidth: .infinity, alignment: frameAlignment)
        }
    }

    /// Small "🔒 Level X schaltet Y Coins frei" hint for the next bet the
    /// player hasn't unlocked yet - keeps `BetControlView` itself unchanged
    /// (it simply never offers a locked bet) while still showing the player
    /// that higher levels unlock more, per the task's "locked bets" ask.
    private func lockedBetHint(for locked: (bet: BetLevel, unlockLevel: Int?)) -> some View {
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

    private var freeSpinsBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
            Text("Freispiele: \(controller.remainingFreeSpins)")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(DemonicPalette.glowingViolet)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(DemonicPalette.glowingViolet.opacity(0.15), in: Capsule())
    }

    private var spinButton: some View {
        Button(action: performSpin) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [DemonicPalette.emberOrange, DemonicPalette.hellfireRed],
                            center: .center, startRadius: 4, endRadius: 60
                        )
                    )
                    .overlay(Circle().strokeBorder(DemonicPalette.boneIvory.opacity(0.6), lineWidth: 2))
                if controller.state == .spinning || controller.state == .stopping || controller.state == .preparing {
                    ProgressView().tint(.white)
                } else {
                    Text(controller.isInBonusRound ? "FREISPIEL" : "SPIN")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 88, height: 88)
        }
        .disabled(!controller.canSpin)
        .opacity(controller.canSpin ? 1 : 0.6)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(controller.isInBonusRound ? "Freispiel starten" : "Drehen")
        .accessibilityHint("Setzt \(controller.totalBet) Soul Coins ein und dreht die Walzen")
    }

    private var footerButtons: some View {
        HStack(spacing: 20) {
            footerButton(system: "book.closed.fill", label: "Auszahlungstabelle") {
                showPaytable = true
            }
            footerButton(system: (settings?.isAudioEnabled ?? true) ? "speaker.wave.2.fill" : "speaker.slash.fill", label: "Audio umschalten") {
                toggleAudio()
            }
        }
    }

    private func footerButton(system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.title3)
                .frame(width: 44, height: 44)
        }
        .foregroundStyle(DemonicPalette.boneIvory)
        .background(.white.opacity(0.06), in: Circle())
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var overlay: some View {
        switch controller.state {
        case .celebrating:
            WinCelebrationView(amount: controller.lastWinAmount, isBigWin: isBigWin)
        case .enteringBonus:
            BonusEntryOverlayView(freeSpinsAwarded: controller.remainingFreeSpins)
        case .bonusSummary:
            BonusSummaryOverlayView(totalPayout: controller.bonusAccumulatedPayout) {
                controller.acknowledgeBonusSummary()
            }
        case .error(let message):
            errorOverlay(message: message)
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
    }

    private var isBigWin: Bool {
        let bet = definition.totalBet(betPerLine: controller.selectedBetPerLine)
        guard bet > 0 else { return false }
        return Double(controller.lastWinAmount) / Double(bet) >= 20
    }

    private func performSpin() {
        guard controller.canSpin else { return }
        hapticsService?.selection()
        spinToken += 1
        controller.spin()
    }

    private func setUp() {
        let context = modelContext
        hapticsService = HapticsService(isEnabledProvider: {
            ProfileStore.fetchOrCreateSettings(in: context).isHapticsEnabled
        })
        let audio = AudioService(
            isSoundEnabledProvider: {
                ProfileStore.fetchOrCreateSettings(in: context).isAudioEnabled
            },
            isMusicEnabledProvider: {
                ProfileStore.fetchOrCreateSettings(in: context).isMusicEnabled
            }
        )
        audioService = audio
        audio.startBackgroundMusic(key: definition.audioKeys.background)
        accountSync = AccountSyncController(context: context, wallet: controller.wallet)
    }

    private func toggleAudio() {
        let userSettings = ProfileStore.fetchOrCreateSettings(in: modelContext)
        userSettings.isAudioEnabled.toggle()
        try? modelContext.save()
    }

    private func handleStateChange(_ newState: SlotMachineState) {
        switch newState {
        case .spinning:
            audioService?.playEffect(key: definition.audioKeys.spinLoop)
        case .stopping:
            audioService?.stopEffect(key: definition.audioKeys.spinLoop)
        case .celebrating:
            if let scatterWin = controller.currentEvaluation?.scatterWin, scatterWin.count > 0 {
                audioService?.playEffect(key: definition.audioKeys.scatterHit)
            }
            audioService?.playEffect(key: isBigWin ? definition.audioKeys.bigWin : definition.audioKeys.lineWin)
            hapticsService?.win(intensity: isBigWin ? .big : .medium)
            particleScene.emitEmbers(intensity: isBigWin ? .big : .medium)
        case .enteringBonus:
            audioService?.playEffect(key: definition.audioKeys.scatterHit)
            audioService?.playEffect(key: definition.audioKeys.bonusEnter)
            hapticsService?.win(intensity: .big)
            particleScene.emitRiftBurst()
        case .idle:
            // A spin (or a bonus round) just finished resolving. Opportunistic
            // and silent: no-ops offline or without a registered account.
            Task { await accountSync?.syncSilently() }
        default:
            break
        }
    }

    private func ambientSmokeLoop() async {
        while !Task.isCancelled {
            if !reduceMotion {
                particleScene.emitAmbientSmoke()
            }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
        }
    }
}

#Preview {
    NavigationStack {
        SlotMachineView(definition: InfernalForgeDefinition.definition, plugin: nil)
    }
    .modelContainer(PersistenceController.makeInMemoryModelContainer())
}
