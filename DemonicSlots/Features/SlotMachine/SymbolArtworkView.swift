//
//  SymbolArtworkView.swift
//  DemonicSlots
//
//  Renders one slot symbol. Prefers a real asset catalog image named after
//  `assetKey`; falls back to a themed SF Symbol placeholder so the game is
//  fully playable before any real art exists, and never crashes on a
//  missing asset.
//
import SwiftUI
import UIKit

struct SymbolArtworkView: View {
    let symbol: SlotSymbol?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundGradient)
            if let symbol {
                if UIImage(named: symbol.assetKey) != nil {
                    Image(symbol.assetKey)
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                } else {
                    Image(systemName: symbol.systemImageFallback)
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                        .foregroundStyle(tint)
                }
            } else {
                Image(systemName: "questionmark")
                    .foregroundStyle(DemonicPalette.boneIvory.opacity(0.5))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tint.opacity(0.5), lineWidth: 1)
        )
        .accessibilityLabel(symbol?.displayName ?? "Unbekanntes Symbol")
    }

    private var tint: Color {
        DemonicPalette.color(forKey: symbol?.tintColorKey ?? "boneIvory")
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [DemonicPalette.darkViolet.opacity(0.9), DemonicPalette.obsidianBlack],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#Preview {
    SymbolArtworkView(symbol: InfernalForgeSymbols.all.first)
        .frame(width: 72, height: 72)
        .padding()
        .background(Color.black)
}
