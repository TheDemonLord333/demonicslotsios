//
//  ReelView.swift
//  DemonicSlots
//
//  One reusable reel column. Purely a *player* of an already-computed
//  result: the final symbols never change because of this view - it only
//  decides how long to visually cycle before revealing them. Reels stop
//  left to right because each reel's own cycle duration grows with its
//  index (`SpinTiming.spinDuration(reelCount: reelIndex + 1)`), not because
//  outcomes differ.
//
import SwiftUI

struct ReelView: View {
    let reelIndex: Int
    let finalSymbols: [SlotSymbol?]
    let cyclingPool: [SlotSymbol]
    let visibleRows: Int
    let spinToken: Int
    let cellSize: CGFloat
    let reduceMotion: Bool
    let highlightedRows: Set<Int>
    var onReelSettled: (() -> Void)?

    @State private var isSpinning = false
    @State private var cycleFrame: [SlotSymbol?] = []

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<visibleRows, id: \.self) { row in
                SymbolArtworkView(symbol: displaySymbol(at: row))
                    .frame(width: cellSize, height: cellSize)
                    .scaleEffect(shouldPulse(row: row) ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 0.35).repeatCount(4, autoreverses: true), value: shouldPulse(row: row))
            }
        }
        .blur(radius: (isSpinning && !reduceMotion) ? 2.5 : 0)
        .opacity(isSpinning ? 0.85 : 1)
        .animation(.easeInOut(duration: 0.2), value: isSpinning)
        .task(id: spinToken) {
            await runSpinCycle()
        }
    }

    private func shouldPulse(row: Int) -> Bool {
        !isSpinning && highlightedRows.contains(row)
    }

    private func displaySymbol(at row: Int) -> SlotSymbol? {
        if isSpinning {
            return cycleFrame.indices.contains(row) ? cycleFrame[row] : nil
        }
        return finalSymbols.indices.contains(row) ? finalSymbols[row] : nil
    }

    private func runSpinCycle() async {
        guard spinToken > 0, !cyclingPool.isEmpty else { return }
        isSpinning = true
        let duration = reduceMotion ? 0.18 : SpinTiming.spinDuration(reelCount: reelIndex + 1)
        let frameIntervalNanos: UInt64 = 70_000_000
        let totalNanos = UInt64((duration * 1_000_000_000).rounded())
        var elapsed: UInt64 = 0
        while elapsed < totalNanos {
            if Task.isCancelled { return }
            cycleFrame = (0..<visibleRows).map { _ in cyclingPool.randomElement() }
            try? await Task.sleep(nanoseconds: frameIntervalNanos)
            elapsed += frameIntervalNanos
        }
        guard !Task.isCancelled else { return }
        isSpinning = false
        onReelSettled?()
    }
}
