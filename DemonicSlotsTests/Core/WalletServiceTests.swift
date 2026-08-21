//
//  WalletServiceTests.swift
//  DemonicSlotsTests
//
//  Covers requirements 10 (insufficient funds) and 13 (never negative,
//  never overflowing Int64), plus the daily Soul Rescue rule.
//
import Foundation
import SwiftData
import Testing
@testable import DemonicSlots

@MainActor
struct WalletServiceTests {
    private func makeContext() -> ModelContext {
        ModelContext(PersistenceController.makeInMemoryModelContainer())
    }

    @Test func newPlayerStartsWithFiveThousandCoins() {
        let wallet = WalletService(context: makeContext())
        #expect(wallet.balance == 5_000)
    }

    @Test func debitSucceedsAndReducesBalanceExactly() {
        let wallet = WalletService(context: makeContext())
        let start = wallet.balance
        #expect(wallet.debit(500))
        #expect(wallet.balance == start - 500)
    }

    @Test func debitFailsWhenBalanceIsInsufficient() {
        let wallet = WalletService(context: makeContext())
        let tooMuch = wallet.balance + 1
        #expect(!wallet.debit(tooMuch))
        #expect(wallet.balance == 5_000) // unchanged
    }

    @Test func balanceNeverGoesNegative() {
        let wallet = WalletService(context: makeContext())
        #expect(!wallet.debit(-10))
        #expect(!wallet.debit(wallet.balance + 1_000_000))
        #expect(wallet.balance >= 0)
    }

    @Test func creditClampsAtInt64MaxInsteadOfOverflowing() {
        let wallet = WalletService(context: makeContext())
        wallet.credit(Int64.max)
        #expect(wallet.balance == Int64.max)
        wallet.credit(1_000) // must not wrap around to a negative number
        #expect(wallet.balance == Int64.max)
        #expect(wallet.balance >= 0)
    }

    @Test func soulRescueIsOnlyAvailableBelowThresholdAndOncePerCalendarDay() {
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
        let wallet = WalletService(context: makeContext(), dateProvider: FixedDateProvider(fixedDate: fixedNow))

        #expect(!wallet.isSoulRescueAvailable()) // balance starts at 5,000

        _ = wallet.debit(wallet.balance - 5) // leave 5 coins, below the threshold of 10
        #expect(wallet.isSoulRescueAvailable())

        #expect(wallet.claimSoulRescue())
        #expect(wallet.balance == 1_005)
        #expect(!wallet.isSoulRescueAvailable())
        #expect(!wallet.claimSoulRescue()) // same day, already claimed
        #expect(wallet.balance == 1_005)
    }

    @Test func soulRescueBecomesAvailableAgainOnANewCalendarDay() {
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = day1.addingTimeInterval(60 * 60 * 24)
        let context = makeContext()

        let walletDay1 = WalletService(context: context, dateProvider: FixedDateProvider(fixedDate: day1))
        _ = walletDay1.debit(walletDay1.balance - 5)
        #expect(walletDay1.claimSoulRescue())

        let walletDay2 = WalletService(context: context, dateProvider: FixedDateProvider(fixedDate: day2))
        _ = walletDay2.debit(walletDay2.balance - 5)
        #expect(walletDay2.isSoulRescueAvailable())
    }
}
