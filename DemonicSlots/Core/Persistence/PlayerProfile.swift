//
//  PlayerProfile.swift
//  DemonicSlots
//
//  The single shared wallet used by every slot game in the collection.
//  There is exactly one `PlayerProfile` row per install; `WalletService`
//  is responsible for creating it on first launch and for every balance
//  mutation afterwards (never mutate `soulCoinBalance` directly from a view).
//
import Foundation
import SwiftData

@Model
final class PlayerProfile {
    /// Fixed identifier so the single row can always be located.
    @Attribute(.unique) var profileID: String
    var soulCoinBalance: Int64
    var createdAt: Date
    var lastSoulRescueDate: Date?
    var hasSeenEntertainmentDisclaimer: Bool

    init(
        profileID: String = PlayerProfile.singletonID,
        soulCoinBalance: Int64 = 5_000,
        createdAt: Date = .now,
        lastSoulRescueDate: Date? = nil,
        hasSeenEntertainmentDisclaimer: Bool = false
    ) {
        self.profileID = profileID
        self.soulCoinBalance = soulCoinBalance
        self.createdAt = createdAt
        self.lastSoulRescueDate = lastSoulRescueDate
        self.hasSeenEntertainmentDisclaimer = hasSeenEntertainmentDisclaimer
    }

    static let singletonID = "player.singleton"
    static let startingBalance: Int64 = 5_000
    static let soulRescueThreshold: Int64 = 10
    static let soulRescueAmount: Int64 = 1_000
}
