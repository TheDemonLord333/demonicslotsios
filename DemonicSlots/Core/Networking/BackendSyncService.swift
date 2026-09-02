//
//  BackendSyncService.swift
//  DemonicSlots
//
//  Thin URLSession client for the optional backend in /backend. Every
//  method degrades to a `.networkError` outcome (never throws, never
//  crashes) when offline or the server is unreachable - callers treat
//  that the same as "try again later", keeping the app fully playable
//  without any connection.
//
import Foundation

// Declared at top level (not nested in BackendSyncService) and explicitly
// `nonisolated`, matching the pattern already used for SlotEngineError -
// keeps these plain outcome values callable from any isolation context
// without relying on nested-type isolation inference.
nonisolated enum RegisterOutcome: Equatable, Sendable {
    case success(username: String, deviceToken: String, coinBalance: Int64, adminRevision: Int64, level: Int64, winChanceMultiplier: Double, guaranteedJackpot: Bool)
    case usernameTaken
    case invalidUsername
    case networkError(String)
}

nonisolated enum SyncOutcome: Equatable, Sendable {
    case serverWins(coinBalance: Int64, adminRevision: Int64, level: Int64, winChanceMultiplier: Double, guaranteedJackpot: Bool)
    case clientApplied(adminRevision: Int64, level: Int64, winChanceMultiplier: Double, guaranteedJackpot: Bool)
    case notRegistered
    case invalidDeviceToken
    case networkError(String)
}

nonisolated struct BackendSyncService: Sendable {
    private let session: URLSession
    private let baseURL: URL

    init(session: URLSession = .shared, baseURL: URL = BackendConfig.baseURL) {
        self.session = session
        self.baseURL = baseURL
    }

    func register(username: String, initialBalance: Int64) async -> RegisterOutcome {
        guard let request = makeRequest(
            path: "api/players/register",
            body: ["username": username, "initialBalance": initialBalance]
        ) else {
            return .networkError("Ungültige Anfrage.")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .networkError("Ungültige Serverantwort.")
            }
            switch http.statusCode {
            case 201:
                guard
                    let json = decodeJSONObject(data),
                    let returnedUsername = json["username"] as? String,
                    let deviceToken = json["deviceToken"] as? String,
                    let coinBalance = int64Value(json["coinBalance"]),
                    let adminRevision = int64Value(json["adminRevision"]),
                    let level = int64Value(json["level"]),
                    let winChanceMultiplier = doubleValue(json["winChanceMultiplier"])
                else {
                    return .networkError("Unerwartete Serverantwort.")
                }
                return .success(
                    username: returnedUsername,
                    deviceToken: deviceToken,
                    coinBalance: coinBalance,
                    adminRevision: adminRevision,
                    level: level,
                    winChanceMultiplier: winChanceMultiplier,
                    guaranteedJackpot: (json["guaranteedJackpot"] as? Bool) ?? false
                )
            case 409:
                return .usernameTaken
            case 400:
                return .invalidUsername
            default:
                return .networkError("Serverfehler (\(http.statusCode)).")
            }
        } catch {
            return .networkError(error.localizedDescription)
        }
    }

    /// `earnedLevel`: the level `PlayerProgressionService.level(forTotalXP:)`
    /// currently justifies from local play, passed only when it's above
    /// what this device last knew the server to have (see
    /// `AccountSyncController.syncSilently` - never sent otherwise, since
    /// the server would just no-op it anyway). The server only ever raises
    /// its stored level from this, never lowers it - an admin-set level
    /// above the player's own XP pace is never walked back by playing.
    func sync(
        username: String,
        deviceToken: String,
        localBalance: Int64,
        lastKnownAdminRevision: Int64,
        earnedLevel: Int64? = nil
    ) async -> SyncOutcome {
        var body: [String: Any] = [
            "username": username,
            "deviceToken": deviceToken,
            "localBalance": localBalance,
            "lastKnownAdminRevision": lastKnownAdminRevision,
        ]
        if let earnedLevel {
            body["earnedLevel"] = earnedLevel
        }
        guard let request = makeRequest(path: "api/players/sync", body: body) else {
            return .networkError("Ungültige Anfrage.")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .networkError("Ungültige Serverantwort.")
            }
            switch http.statusCode {
            case 200:
                guard
                    let json = decodeJSONObject(data),
                    let resolution = json["resolution"] as? String,
                    let coinBalance = int64Value(json["coinBalance"]),
                    let adminRevision = int64Value(json["adminRevision"]),
                    let level = int64Value(json["level"]),
                    let winChanceMultiplier = doubleValue(json["winChanceMultiplier"])
                else {
                    return .networkError("Unerwartete Serverantwort.")
                }
                let guaranteedJackpot = (json["guaranteedJackpot"] as? Bool) ?? false
                if resolution == "server_wins" {
                    return .serverWins(coinBalance: coinBalance, adminRevision: adminRevision, level: level, winChanceMultiplier: winChanceMultiplier, guaranteedJackpot: guaranteedJackpot)
                }
                return .clientApplied(adminRevision: adminRevision, level: level, winChanceMultiplier: winChanceMultiplier, guaranteedJackpot: guaranteedJackpot)
            case 403:
                return .invalidDeviceToken
            case 404:
                return .notRegistered
            default:
                return .networkError("Serverfehler (\(http.statusCode)).")
            }
        } catch {
            return .networkError(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func makeRequest(path: String, body: [String: Any]) -> URLRequest? {
        guard JSONSerialization.isValidJSONObject(body),
              let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            return nil
        }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        request.timeoutInterval = 10
        return request
    }

    private func decodeJSONObject(_ data: Data) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private func int64Value(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber { return number.int64Value }
        return nil
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        return nil
    }
}
