//
//  GameCardView.swift
//  DemonicSlots
//
//  One portal-styled card in the collection grid. Purely presentational -
//  all it needs is the `SlotGameDefinition` to render.
//
import SwiftUI

struct GameCardView: View {
    let definition: SlotGameDefinition
    var isFeatured: Bool = false

    private var accent: Color { Color(hex: definition.theme.accentColorHex) }
    private var glow: Color { Color(hex: definition.theme.glowColorHex) }
    private var background: Color { Color(hex: definition.theme.backgroundColorHex) }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(0.55), background, DemonicPalette.obsidianBlack],
                        center: .center,
                        startRadius: 4,
                        endRadius: isFeatured ? 260 : 160
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(glow.opacity(0.7), lineWidth: 1.5)
                )
                .shadow(color: glow.opacity(0.35), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                if definition.availability == .comingSoon {
                    Text("BALD VERFÜGBAR")
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundStyle(DemonicPalette.boneIvory)
                }
                Text(definition.displayName)
                    .font(isFeatured ? .title2.weight(.heavy) : .headline.weight(.bold))
                    .foregroundStyle(DemonicPalette.boneIvory)
                if isFeatured {
                    Text(definition.shortDescription)
                        .font(.subheadline)
                        .foregroundStyle(DemonicPalette.boneIvory.opacity(0.8))
                        .lineLimit(2)
                }
            }
            .padding(16)

            Image(systemName: portalSymbolName)
                .font(.system(size: isFeatured ? 64 : 40))
                .foregroundStyle(glow.opacity(0.35))
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(minHeight: isFeatured ? 200 : 140)
        .opacity(definition.availability == .available ? 1 : 0.6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityAddTraits(definition.availability == .available ? [.isButton] : [])
    }

    private var portalSymbolName: String {
        switch definition.id {
        case InfernalForgeDefinition.gameID: return "flame.circle.fill"
        default: return "circle.hexagongrid.circle.fill"
        }
    }

    private var accessibilityLabel: String {
        if definition.availability == .comingSoon {
            return "\(definition.displayName), bald verfügbar"
        }
        return definition.displayName
    }
}
