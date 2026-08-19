//
//  PaylineOverlayView.swift
//  DemonicSlots
//
//  Draws every winning payline over the reel grid. Lines are distinguished
//  by more than color alone (alternating solid/dashed strokes) so a
//  color-blind player can still tell separate wins apart.
//
import SwiftUI

struct PaylineOverlayView: View {
    let definition: SlotGameDefinition
    let evaluation: SpinEvaluation
    let cellSize: CGFloat
    let spacing: CGFloat

    var body: some View {
        Canvas { context, _ in
            for (index, win) in evaluation.lineWins.enumerated() {
                guard let payline = definition.paylines.first(where: { $0.id == win.paylineID }) else { continue }
                var path = Path()
                for reelIndex in 0..<min(win.matchCount, payline.rowIndices.count) {
                    let point = center(reel: reelIndex, row: payline.rowIndices[reelIndex])
                    if reelIndex == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
                let style = StrokeStyle(
                    lineWidth: 4,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: index.isMultiple(of: 2) ? [] : [7, 5]
                )
                context.stroke(path, with: .color(lineColor(index: index)), style: style)
            }
        }
        .frame(width: totalWidth, height: totalHeight)
        .accessibilityHidden(true)
    }

    private var totalWidth: CGFloat {
        CGFloat(definition.reelCount) * cellSize + CGFloat(max(definition.reelCount - 1, 0)) * spacing
    }

    private var totalHeight: CGFloat {
        CGFloat(definition.visibleRows) * cellSize + CGFloat(max(definition.visibleRows - 1, 0)) * spacing
    }

    private func center(reel: Int, row: Int) -> CGPoint {
        CGPoint(
            x: CGFloat(reel) * (cellSize + spacing) + cellSize / 2,
            y: CGFloat(row) * (cellSize + spacing) + cellSize / 2
        )
    }

    private func lineColor(index: Int) -> Color {
        let palette: [Color] = [
            DemonicPalette.emberOrange,
            DemonicPalette.glowingViolet,
            DemonicPalette.hellfireRed,
            DemonicPalette.boneIvory,
        ]
        return palette[index % palette.count]
    }
}
