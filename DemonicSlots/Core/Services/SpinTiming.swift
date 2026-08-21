//
//  SpinTiming.swift
//  DemonicSlots
//
//  Central timing constants for the spin animation sequence, kept out of
//  any SwiftUI view so both the view layer and `SpinSessionController`
//  agree on the same numbers. Total duration targets ~1.8-2.4s with a
//  0.12-0.20s stagger between reel stops, per the design spec.
//
import Foundation

enum SpinTiming {
    static let baseSpinDuration: Double = 1.3
    static let perReelStagger: Double = 0.15
    static let settleDuration: Double = 0.25
    static let bonusTransitionDuration: Double = 1.1

    static func spinDuration(reelCount: Int) -> Double {
        baseSpinDuration + Double(max(reelCount - 1, 0)) * perReelStagger
    }

    static func reelStopDelay(reelIndex: Int) -> Double {
        Double(reelIndex) * perReelStagger
    }

    static func celebrationDuration(payout: Int64, totalBet: Int64) -> Double {
        guard totalBet > 0, payout > 0 else { return 0.6 }
        let ratio = Double(payout) / Double(totalBet)
        switch ratio {
        case ..<5:
            return 1.0
        case 5..<20:
            return 1.6
        default:
            return 2.4
        }
    }
}
