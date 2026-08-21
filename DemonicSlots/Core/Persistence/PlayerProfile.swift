//
//  PlayerProfile.swift
//  DemonicSlots
//
//  The single shared wallet used by every slot game in the collection.
//  There is exactly one `PlayerProfile` row per install; `WalletService`
//  is responsible for creating it on first launch and for every balance
//  mutation afterwards (never mutate `soulCoinBalance` directly from a view).
//
//  The `online*`/`lastKnownAdminRevision` fields are for the optional
//  backend sync (see `AccountSyncController`/`BackendSyncService`): they
//  stay nil/0 for a purely offline player and are only ever written by
//  that sync code, never read/written by gameplay code directly.
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

    /// The username claimed on the backend, if any. Nil means this player
    /// has never registered an online profile - the app remains fully
    /// playable offline either way.
    var onlineUsername: String?
    /// Secret issued by the backend at registration; proves this device
    /// owns `onlineUsername` on every sync call. Never shown in the UI.
    var deviceToken: String?
    /// The backend's `admin_revision` counter as of the last successful
    /// sync. A mismatch on the next sync means an admin changed the
    /// balance directly, which must win over anything played offline.
    var lastKnownAdminRevision: Int64
    var lastSyncedAt: Date?

    // `profileID` defaults to the literal, not `PlayerProfile.singletonID`:
    // default parameter expressions are evaluated in a nonisolated context
    // and can't reference a MainActor-isolated static property. Must stay
    // in sync with `singletonID` below.
    init(
        profileID: String = "player.singleton",
        soulCoinBalance: Int64 = 5_000,
        createdAt: Date = .now,
        lastSoulRescueDate: Date? = nil,
        hasSeenEntertainmentDisclaimer: Bool = false,
        onlineUsername: String? = nil,
        deviceToken: String? = nil,
        lastKnownAdminRevision: Int64 = 0,
        lastSyncedAt: Date? = nil
    ) {
        self.profileID = profileID
        self.soulCoinBalance = soulCoinBalance
        self.createdAt = createdAt
        self.lastSoulRescueDate = lastSoulRescueDate
        self.hasSeenEntertainmentDisclaimer = hasSeenEntertainmentDisclaimer
        self.onlineUsername = onlineUsername
        self.deviceToken = deviceToken
        self.lastKnownAdminRevision = lastKnownAdminRevision
        self.lastSyncedAt = lastSyncedAt
    }

    static let singletonID = "player.singleton"
    static let startingBalance: Int64 = 5_000
    static let soulRescueThreshold: Int64 = 10
    static let soulRescueAmount: Int64 = 1_000
}
