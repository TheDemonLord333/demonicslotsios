//
//  FreeSpinsRules.swift
//  DemonicSlots
//

import Foundation

/// Payout/free-spin award for a specific scatter count.
nonisolated struct ScatterPayout: Codable, Hashable, Sendable {
    var scatterCount: Int
    /// Multiplier of the *total* stake (all lines), not the per-line stake.
    var totalBetMultiplier: Int64
    var freeSpinsAwarded: Int

    init(scatterCount: Int, totalBetMultiplier: Int64, freeSpinsAwarded: Int) {
        self.scatterCount = scatterCount
        self.totalBetMultiplier = totalBetMultiplier
        self.freeSpinsAwarded = freeSpinsAwarded
    }
}

/// Free spin bonus configuration for a game. `nil` on a `SlotGameDefinition`
/// means the game has no scatter/free-spin bonus at all.
nonisolated struct FreeSpinsRules: Codable, Hashable, Sendable {
    /// Scatter counts that trigger the bonus, e.g. 3/4/5 scatters.
    var triggerPayouts: [ScatterPayout]
    /// Minimum scatter count needed to retrigger extra spins while the
    /// bonus round is already active.
    var retriggerMinimumScatterCount: Int
    /// Flat number of extra spins granted on a retrigger, regardless of how
    /// many scatters above the minimum landed.
    var retriggerFreeSpinsAwarded: Int
    /// Hard cap on the number of free spins a single bonus round may hold,
    /// including retriggers.
    var maxFreeSpins: Int
    /// Multiplier applied to every payline win while free spins are active.
    var winMultiplier: Int64

    init(
        triggerPayouts: [ScatterPayout],
        retriggerMinimumScatterCount: Int,
        retriggerFreeSpinsAwarded: Int,
        maxFreeSpins: Int,
        winMultiplier: Int64
    ) {
        self.triggerPayouts = triggerPayouts
        self.retriggerMinimumScatterCount = retriggerMinimumScatterCount
        self.retriggerFreeSpinsAwarded = retriggerFreeSpinsAwarded
        self.maxFreeSpins = maxFreeSpins
        self.winMultiplier = winMultiplier
    }

    /// Best matching trigger payout for a given scatter count (highest
    /// qualifying tier), or `nil` if the count doesn't qualify for any tier.
    func payout(forScatterCount count: Int) -> ScatterPayout? {
        triggerPayouts
            .filter { $0.scatterCount <= count }
            .max { $0.scatterCount < $1.scatterCount }
    }

    /// How many extra free spins a retrigger grants right now, respecting
    /// `maxFreeSpins`. Shared by `SpinSessionController` and `SlotSimulator`
    /// so the cap is enforced identically in both places.
    func retriggerGrant(totalAlreadyGranted: Int) -> Int {
        max(0, min(retriggerFreeSpinsAwarded, maxFreeSpins - totalAlreadyGranted))
    }
}
