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
    // `= 0` here (not just in `init` below) matters: SwiftData's automatic
    // lightweight migration needs a default *on the property declaration*
    // to add a new non-optional column to an existing on-disk store -
    // without it, opening a store created before this field existed throws
    // and `PersistenceController.makeModelContainer()` crashes via
    // `fatalError`. The optional fields around it don't need this since a
    // missing optional column just migrates to nil.
    var lastKnownAdminRevision: Int64 = 0
    var lastSyncedAt: Date?

    /// Server-authoritative player progression (see
    /// `PlayerProgressionService`/`AccountSyncController`): the level and
    /// win-chance multiplier the backend has for this player. Neither is
    /// ever written by gameplay code - only a successful register/sync sets
    /// them, always through `PlayerProgressionService`'s validation first,
    /// so a corrupted or out-of-range backend value never lands here
    /// unclamped. A player who never registers an online profile simply
    /// keeps the defaults below forever (`level = 1`, `winChanceMultiplier
    /// = 1.0`, i.e. no bonus) - coins/level/multiplier are independent
    /// values, level is never derived from the coin balance.
    // `= 1`/`= 1.0` here (not just in `init` below) matter for the same
    // reason `lastKnownAdminRevision`'s does: SwiftData needs a
    // property-level default to add a new non-optional column to a store
    // created before this field existed.
    var level: Int64 = 1
    var winChanceMultiplier: Double = 1.0

    /// Cumulative XP earned by wagering, purely client-side (see
    /// `WalletService.awardXP`/`PlayerProgressionService`). Unlike `level`
    /// itself, this is never server-authoritative and never overwritten by
    /// a sync response - it only ever grows, forever, from real play. It's
    /// what actually drives leveling up: `AccountSyncController` compares
    /// `PlayerProgressionService.level(forTotalXP:)` against the currently
    /// known `level` on every sync and, if XP has earned a higher one,
    /// asks the backend to raise it (never lower it - an admin-set level
    /// above the player's own XP pace is never walked back by playing).
    // `= 0` here for the same lightweight-migration reason as
    // `lastKnownAdminRevision`/`level` above.
    var totalXP: Int64 = 0

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
        lastSyncedAt: Date? = nil,
        level: Int64 = 1,
        winChanceMultiplier: Double = 1.0,
        totalXP: Int64 = 0
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
        self.level = level
        self.winChanceMultiplier = winChanceMultiplier
        self.totalXP = totalXP
    }

    static let singletonID = "player.singleton"
    static let startingBalance: Int64 = 5_000
    static let soulRescueThreshold: Int64 = 10
    static let soulRescueAmount: Int64 = 1_000
}
