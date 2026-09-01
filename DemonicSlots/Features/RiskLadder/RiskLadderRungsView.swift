//
//  RiskLadderRungsView.swift
//  DemonicSlots
//
//  The vertical ladder itself: one row per rung, highest at the top. Purely
//  presentational - reads `currentLevel`/`isRisking` to decide how each rung
//  looks, never touches game logic. Colors intensify from a faint red glow
//  at the bottom to gold/flame at the jackpot rung, per the design brief.
//
import SwiftUI

struct RiskLadderRungsView: View {
    let levels: [RiskLevel]
    /// 0 = still at START (no rung reached yet).
    let currentLevel: Int
    /// True while a climb attempt's suspense animation is playing - the
    /// next rung above the current one pulses to build tension.
    let isRisking: Bool
    let reduceMotion: Bool

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 8) {
            ForEach(levels.reversed()) { level in
                rung(for: level)
            }
            startRung
        }
        .onAppear { startPulseIfNeeded() }
        .onChange(of: isRisking) { _, _ in startPulseIfNeeded() }
    }

    private func startPulseIfNeeded() {
        guard !reduceMotion else {
            pulse = false
            return
        }
        if isRisking {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                pulse = false
            }
        }
    }

    @ViewBuilder
    private func rung(for level: RiskLevel) -> some View {
        let reached = level.level <= currentLevel
        let isCurrent = level.level == currentLevel
        let isNextTarget = isRisking && level.level == currentLevel + 1
        let intensity = Double(level.level) / Double(levels.count)
        let color = rungColor(level: level, intensity: intensity)
        let isHighlighted = isCurrent || isNextTarget

        HStack(spacing: 10) {
            Text(level.isJackpot ? "JACKPOT" : "x\(formattedMultiplier(level.multiplier))")
                .font(.subheadline.weight(level.isJackpot ? .black : .bold))
                .foregroundStyle(reached || isCurrent ? DemonicPalette.boneIvory : DemonicPalette.boneIvory.opacity(0.55))

            Spacer()

            if isCurrent {
                Image(systemName: "flame.fill")
                    .foregroundStyle(color)
                    .scaleEffect(pulse && !reduceMotion ? 1.25 : 1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, level.isJackpot ? 14 : 9)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHighlighted ? color.opacity(0.28) : (reached ? DemonicPalette.darkViolet.opacity(0.6) : DemonicPalette.obsidianBlack.opacity(0.6)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(color.opacity(isHighlighted ? 0.9 : 0.3), lineWidth: isCurrent ? 2 : 1)
        )
        .shadow(color: color.opacity(isCurrent && pulse && !reduceMotion ? 0.8 : (isCurrent ? 0.5 : 0)), radius: isCurrent ? 14 : 0)
        .opacity(isNextTarget && pulse && !reduceMotion ? 0.55 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: level, reached: reached, isCurrent: isCurrent))
    }

    private var startRung: some View {
        HStack {
            Text("START")
                .font(.caption.weight(.heavy))
                .tracking(1.5)
                .foregroundStyle(DemonicPalette.boneIvory.opacity(0.7))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(DemonicPalette.obsidianBlack))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(DemonicPalette.boneIvory.opacity(0.25), lineWidth: 1))
    }

    private func rungColor(level: RiskLevel, intensity: Double) -> Color {
        if level.isJackpot { return DemonicPalette.emberOrange }
        if intensity > 0.6 { return DemonicPalette.emberOrange }
        if intensity > 0.3 { return DemonicPalette.hellfireRed }
        return DemonicPalette.hellfireRed.opacity(0.6)
    }

    private func formattedMultiplier(_ multiplier: Double) -> String {
        multiplier.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", multiplier)
            : String(format: "%.1f", multiplier)
    }

    private func accessibilityLabel(for level: RiskLevel, reached: Bool, isCurrent: Bool) -> String {
        let name = level.isJackpot ? "Jackpot" : "Stufe \(level.level), Multiplikator \(formattedMultiplier(level.multiplier))"
        if isCurrent { return "\(name), aktuelle Position" }
        if reached { return "\(name), erreicht" }
        return "\(name), noch nicht erreicht"
    }
}
