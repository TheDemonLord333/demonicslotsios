//
//  WalletService.swift
//  DemonicSlots
//
//  The only code allowed to mutate `PlayerProfile.soulCoinBalance`. Balance
//  can never go negative and never silently overflows `Int64`; every
//  mutation is saved to the SwiftData store immediately so a killed process
//  never loses a committed change.
//
import Foundation
import SwiftData

@MainActor
final class WalletService {
    private let context: ModelContext
    private let dateProvider: any DateProvider

    init(context: ModelContext, dateProvider: any DateProvider = SystemDateProvider()) {
        self.context = context
        self.dateProvider = dateProvider
    }

    func currentProfile() -> PlayerProfile {
        ProfileStore.fetchOrCreateProfile(in: context)
    }

    var balance: Int64 { currentProfile().soulCoinBalance }

    func canAfford(_ amount: Int64) -> Bool {
        amount >= 0 && currentProfile().soulCoinBalance >= amount
    }

    /// Debits `amount` if, and only if, the balance can cover it. Returns
    /// whether the debit happened.
    @discardableResult
    func debit(_ amount: Int64) -> Bool {
        guard amount >= 0 else { return false }
        let profile = currentProfile()
        guard profile.soulCoinBalance >= amount else { return false }
        profile.soulCoinBalance -= amount
        save()
        return true
    }

    /// Credits `amount`, clamping at `Int64.max` instead of overflowing.
    func credit(_ amount: Int64) {
        guard amount > 0 else { return }
        let profile = currentProfile()
        let (sum, overflowed) = profile.soulCoinBalance.addingReportingOverflow(amount)
        profile.soulCoinBalance = overflowed ? Int64.max : sum
        save()
    }

    /// Force-sets the balance to an exact value, bypassing debit/credit
    /// semantics entirely. Used only by `AccountSyncController` when the
    /// backend's admin-authoritative balance must overwrite whatever is
    /// stored locally - never call this from gameplay code.
    func setBalance(_ amount: Int64) {
        let profile = currentProfile()
        profile.soulCoinBalance = max(0, amount)
        save()
    }

    // MARK: - Soul Rescue

    func isSoulRescueAvailable() -> Bool {
        let profile = currentProfile()
        guard profile.soulCoinBalance < PlayerProfile.soulRescueThreshold else { return false }
        guard let lastClaim = profile.lastSoulRescueDate else { return true }
        return !Calendar.current.isDate(lastClaim, inSameDayAs: dateProvider.now())
    }

    @discardableResult
    func claimSoulRescue() -> Bool {
        guard isSoulRescueAvailable() else { return false }
        let profile = currentProfile()
        let (sum, overflowed) = profile.soulCoinBalance.addingReportingOverflow(PlayerProfile.soulRescueAmount)
        profile.soulCoinBalance = overflowed ? Int64.max : sum
        profile.lastSoulRescueDate = dateProvider.now()
        save()
        return true
    }

    private func save() {
        try? context.save()
    }
}
