//
//  BackendConfig.swift
//  DemonicSlots
//
//  Address of the optional Demonic Slots backend (see /backend in the
//  repo). The app is fully playable offline without it; every call
//  through `BackendSyncService` degrades to a silent no-op when this host
//  is unreachable, so an unreachable/misconfigured value never breaks
//  gameplay - it just means the username/coin sync feature does nothing.
//
//  Marked `nonisolated`: `baseURL` is used as a default parameter value in
//  `BackendSyncService.init`, and default parameter expressions are
//  evaluated in a nonisolated context - they can't reference a
//  MainActor-isolated static property (this app target defaults
//  unannotated declarations to MainActor). Same fix as
//  PlayerProfile.singletonID/GameRegistry.shared elsewhere in the codebase.
//
import Foundation

nonisolated enum BackendConfig {
    /// nginx + Let's Encrypt reverse-proxies HTTPS on this domain through
    /// to the backend's plain-HTTP port 3007 - see backend/README.md.
    static let baseURL = URL(string: "https://demonicslots.thedemonlord333.me")!
}
