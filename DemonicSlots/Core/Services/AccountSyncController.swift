//
//  AccountSyncController.swift
//  DemonicSlots
//
//  Owns the optional online-profile flow: claiming a unique username and
//  keeping the local Soul Coin balance and the backend's balance in sync
//  whenever there's a connection. Registration is the only user-initiated
//  action; every sync afterwards is opportunistic and silent by default -
//  callers just fire `syncSilently()` whenever it's convenient (app
//  foreground, after a spin, ...) and it quietly does nothing if there's
//  no connection or no registered account.
//
//  Conflict resolution mirrors the backend exactly (see backend/README.md):
//  a mismatched `adminRevision` means the balance was changed directly on
//  the server, which always overwrites the local value; otherwise the
//  local (gameplay-driven) balance is pushed up.
//
//  Every sync also carries this device's locally-earned level (from
//  `PlayerProfile.totalXP` via `PlayerProgressionService.level(forTotalXP:)`)
//  when it's above what the server last had, and always applies whatever
//  `level`/`winChanceMultiplier` the server responds with - level itself
//  stays server-authoritative either way, this only ever proposes raising
//  it, never lowers it locally.
//
import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class AccountSyncController {
    enum State: Equatable {
        case idle
        case working
        case error(String)
    }

    private let context: ModelContext
    private let wallet: WalletService
    private let backend: BackendSyncService

    private(set) var state: State = .idle
    private(set) var username: String?
    private(set) var lastSyncedAt: Date?
    /// Guards against two overlapping sync calls on *this* controller
    /// instance (e.g. a double-tap on "sync now") racing each other's
    /// read-then-write of `lastKnownAdminRevision`. Each screen that syncs
    /// (collection hub, a slot machine, app-foreground) currently owns its
    /// own controller instance, so this doesn't fully serialize sync calls
    /// that happen to fire from two different screens at the exact same
    /// moment - a narrow, self-healing edge case (the next sync round trip
    /// reconciles it) that a shared/singleton controller would close
    /// entirely if it's ever worth the extra plumbing.
    private var isSyncing = false

    init(context: ModelContext, wallet: WalletService, backend: BackendSyncService = BackendSyncService()) {
        self.context = context
        self.wallet = wallet
        self.backend = backend
        let profile = wallet.currentProfile()
        self.username = profile.onlineUsername
        self.lastSyncedAt = profile.lastSyncedAt
    }

    var isRegistered: Bool { username != nil }

    /// Claims `rawUsername` for this device. On success the player's
    /// current local balance becomes the backend's starting balance.
    func register(username rawUsername: String) async {
        let trimmed = rawUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidUsernameFormat(trimmed) else {
            state = .error("Benutzername muss 3-20 Zeichen lang sein (Buchstaben, Zahlen, _).")
            return
        }

        state = .working
        let profile = wallet.currentProfile()
        let outcome = await backend.register(username: trimmed, initialBalance: profile.soulCoinBalance)

        switch outcome {
        case .success(let returnedUsername, let deviceToken, let coinBalance, let adminRevision, let level, let winChanceMultiplier):
            profile.onlineUsername = returnedUsername
            profile.deviceToken = deviceToken
            profile.lastKnownAdminRevision = adminRevision
            profile.soulCoinBalance = max(0, coinBalance)
            // Validated here (not just trusted from the wire) even though
            // the backend itself already rejects an out-of-range value at
            // the source - a second, independent line of defense per
            // PlayerProgressionService's own header comment.
            profile.level = Int64(PlayerProgressionService.validatedLevel(Int(level)))
            profile.winChanceMultiplier = PlayerProgressionService.validatedWinChanceMultiplier(winChanceMultiplier)
            profile.lastSyncedAt = .now
            try? context.save()
            username = returnedUsername
            lastSyncedAt = profile.lastSyncedAt
            state = .idle
        case .usernameTaken:
            state = .error("Dieser Benutzername ist bereits vergeben.")
        case .invalidUsername:
            state = .error("Ungültiger Benutzername.")
        case .networkError(let message):
            state = .error("Keine Verbindung zum Server (\(message)). Versuch es später erneut.")
        }
    }

    /// Pushes/pulls the balance if this device has a registered account and
    /// a connection. Safe to call anytime, as often as you like - it's a
    /// silent no-op otherwise. Pass `reportErrors: true` only for a
    /// user-initiated "sync now" action where feedback makes sense.
    @discardableResult
    func syncSilently(reportErrors: Bool = false) async -> Bool {
        guard !isSyncing else { return false }
        let profile = wallet.currentProfile()
        guard let username = profile.onlineUsername, let deviceToken = profile.deviceToken else {
            return false
        }

        isSyncing = true
        defer { isSyncing = false }

        if reportErrors { state = .working }

        // Only claim a level-up when local XP actually justifies one above
        // what this device last knew the server to have - never send a
        // lower or equal value, the server would just ignore it anyway
        // (see BackendSyncService.sync's doc comment).
        let xpLevel = PlayerProgressionService.level(forTotalXP: profile.totalXP)
        let earnedLevel: Int64? = Int64(xpLevel) > profile.level ? Int64(xpLevel) : nil

        let outcome = await backend.sync(
            username: username,
            deviceToken: deviceToken,
            localBalance: profile.soulCoinBalance,
            lastKnownAdminRevision: profile.lastKnownAdminRevision,
            earnedLevel: earnedLevel
        )

        switch outcome {
        case .serverWins(let coinBalance, let adminRevision, let level, let winChanceMultiplier):
            wallet.setBalance(coinBalance)
            profile.lastKnownAdminRevision = adminRevision
            profile.level = Int64(PlayerProgressionService.validatedLevel(Int(level)))
            profile.winChanceMultiplier = PlayerProgressionService.validatedWinChanceMultiplier(winChanceMultiplier)
            profile.lastSyncedAt = .now
            try? context.save()
            lastSyncedAt = profile.lastSyncedAt
            if reportErrors { state = .idle }
            return true
        case .clientApplied(let adminRevision, let level, let winChanceMultiplier):
            profile.lastKnownAdminRevision = adminRevision
            profile.level = Int64(PlayerProgressionService.validatedLevel(Int(level)))
            profile.winChanceMultiplier = PlayerProgressionService.validatedWinChanceMultiplier(winChanceMultiplier)
            profile.lastSyncedAt = .now
            try? context.save()
            lastSyncedAt = profile.lastSyncedAt
            if reportErrors { state = .idle }
            return true
        case .invalidDeviceToken:
            // The server no longer recognizes this device for this
            // username (e.g. its database was reset). Clear the local
            // registration so the player can claim a username again
            // instead of silently failing forever.
            profile.onlineUsername = nil
            profile.deviceToken = nil
            profile.lastKnownAdminRevision = 0
            try? context.save()
            self.username = nil
            if reportErrors { state = .error("Account nicht mehr gültig. Bitte erneut registrieren.") }
            return false
        case .notRegistered:
            if reportErrors { state = .error("Account nicht gefunden. Bitte erneut registrieren.") }
            return false
        case .networkError(let message):
            if reportErrors { state = .error("Keine Verbindung zum Server (\(message)).") }
            return false
        }
    }

    private static func isValidUsernameFormat(_ value: String) -> Bool {
        guard value.count >= 3, value.count <= 20 else { return false }
        return value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}
