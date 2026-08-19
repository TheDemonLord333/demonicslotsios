//
//  ReelsGridView.swift
//  DemonicSlots
//
//  Assembles the framed 5x3 (or game-defined) reel field: one `ReelView`
//  per reel plus the payline overlay, inside a dark metal frame with
//  glowing edges.
//
import SwiftUI

struct ReelsGridView: View {
    let definition: SlotGameDefinition
    let evaluation: SpinEvaluation?
    let spinToken: Int
    let reduceMotion: Bool
    let showPaylines: Bool
    var onReelSettled: (() -> Void)?

    private let cellSize: CGFloat = 62
    private let cellSpacing: CGFloat = 8

    var body: some View {
        ZStack {
            HStack(spacing: cellSpacing) {
                ForEach(0..<definition.reelCount, id: \.self) { reelIndex in
                    ReelView(
                        reelIndex: reelIndex,
                        finalSymbols: finalSymbols(reelIndex: reelIndex),
                        cyclingPool: definition.symbols,
                        visibleRows: definition.visibleRows,
                        spinToken: spinToken,
                        cellSize: cellSize,
                        reduceMotion: reduceMotion,
                        highlightedRows: highlightedRows(reelIndex: reelIndex),
                        onReelSettled: onReelSettled
                    )
                }
            }

            if showPaylines, let evaluation, !evaluation.lineWins.isEmpty {
                PaylineOverlayView(definition: definition, evaluation: evaluation, cellSize: cellSize, spacing: cellSpacing)
                    .allowsHitTesting(false)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DemonicPalette.obsidianBlack.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: definition.theme.glowColorHex), DemonicPalette.obsidianBlack],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
        )
        .shadow(color: Color(hex: definition.theme.glowColorHex).opacity(0.4), radius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private func finalSymbols(reelIndex: Int) -> [SlotSymbol?] {
        if let evaluation, evaluation.spinResult.grid.indices.contains(reelIndex) {
            return evaluation.spinResult.grid[reelIndex].map { definition.symbol(for: $0) }
        }
        // Idle resting state before the first spin: show the strip's own
        // first symbols so the frame never appears empty.
        guard definition.reelStrips.indices.contains(reelIndex) else { return [] }
        let strip = definition.reelStrips[reelIndex]
        guard !strip.isEmpty else { return [] }
        return (0..<definition.visibleRows).map { row in
            definition.symbol(for: strip[row % strip.count])
        }
    }

    private func highlightedRows(reelIndex: Int) -> Set<Int> {
        guard showPaylines, let evaluation else { return [] }
        var rows: Set<Int> = []
        for win in evaluation.lineWins {
            for position in win.positions where position.reel == reelIndex {
                rows.insert(position.row)
            }
        }
        if let scatterWin = evaluation.scatterWin {
            for position in scatterWin.positions where position.reel == reelIndex {
                rows.insert(position.row)
            }
        }
        return rows
    }

    private var accessibilitySummary: String {
        guard let evaluation else { return "Walzenfeld, bereit zum Drehen" }
        if evaluation.hasAnyWin {
            return "Walzenfeld, Gewinn von \(evaluation.totalPayout) Soul Coins"
        }
        return "Walzenfeld, kein Gewinn"
    }
}
