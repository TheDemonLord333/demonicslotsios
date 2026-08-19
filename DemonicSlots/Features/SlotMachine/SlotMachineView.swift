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
                    betLevels: definition.betLevels,
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
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Letzter Gewinn")
                    .font(.caption2)
                    .foregroundStyle(DemonicPalette.boneIvory.opacity(0.6))
                Text("\(controller.lastWinAmount)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DemonicPalette.boneIvory)
            }
            Spacer()
            if controller.isInBonusRound {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Freispiele")
                        .font(.caption2)
                        .foregroundStyle(DemonicPalette.boneIvory.opacity(0.6))
                    Text("\(controller.remainingFreeSpins)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DemonicPalette.glowingViolet)
                }
            }
        }
        .accessibilityElement(children: .combine)
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
            break
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
