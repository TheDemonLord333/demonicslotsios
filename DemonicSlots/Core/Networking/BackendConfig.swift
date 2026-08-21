//
//  BackendConfig.swift
//  DemonicSlots
//
//  Address of the optional Demonic Slots backend (see /backend in the
//  repo). The app is fully playable offline without it; every call
//  through `BackendSyncService` degrades to a silent no-op when this host
//  is unreachable, so an unset/wrong value never breaks gameplay - it
//  just means the username/coin sync feature does nothing.
//
import Foundation

enum BackendConfig {
    /// TODO: point this at your deployed backend (see backend/README.md).
    /// Must be `https://` - the backend sits behind an nginx + Let's
    /// Encrypt reverse proxy, not exposed directly on port 3007.
    static let baseURL = URL(string: "https://YOUR-DOMAIN-HERE.example.com")!
}
