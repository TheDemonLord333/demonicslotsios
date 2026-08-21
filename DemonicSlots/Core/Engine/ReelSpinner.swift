//
//  ReelSpinner.swift
//  DemonicSlots
//
//  Pure computation of a spin's stop indices and the resulting visible
//  grid. Contains no timing, animation or UI concerns whatsoever - the
//  entire outcome exists before a single frame of animation plays.
//
import Foundation

nonisolated enum ReelSpinner {
    /// Picks one random stop index per reel. An empty strip defensively
    /// yields stop `0` rather than crashing (the definition should have
    /// already been validated by this point).
    static func stopIndices(
        for reelStrips: [[SymbolID]],
        randomSource: inout any RandomNumberSource
    ) -> [Int] {
        reelStrips.map { strip in
            guard !strip.isEmpty else { return 0 }
            return randomSource.nextInt(in: 0..<strip.count)
        }
    }

    /// Computes the visible symbol grid from stop indices. `grid[reel][row]`
    /// is read cyclically from that reel's strip starting at its stop index,
    /// so the strip acts as a circular buffer.
    static func visibleGrid(
        stopIndices: [Int],
        reelStrips: [[SymbolID]],
        visibleRows: Int,
        placeholderSymbol: SymbolID
    ) -> [[SymbolID]] {
        zip(stopIndices, reelStrips).map { stopIndex, strip in
            guard !strip.isEmpty else {
                return Array(repeating: placeholderSymbol, count: visibleRows)
            }
            return (0..<visibleRows).map { rowOffset in
                strip[(stopIndex + rowOffset) % strip.count]
            }
        }
    }
}
