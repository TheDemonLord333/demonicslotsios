//
//  RandomNumberSource.swift
//  DemonicSlots
//
//  Injectable randomness for the slot engine. Production code uses
//  `SystemRandomSource`, a thin wrapper around `SystemRandomNumberGenerator`.
//  Tests (and the RTP simulator) use `SeededRandomSource` to get
//  reproducible sequences. Both sequence generation and the visible-grid
//  math are pure value operations with no dependency on any actor, so they
//  can run on any thread, including a background `Task` during simulation.
//
import Foundation

/// Abstraction over a source of uniformly distributed integers, so the
/// engine never depends directly on `SystemRandomNumberGenerator`.
protocol RandomNumberSource: Sendable {
    /// Returns a value in `range` (upper bound excluded).
    mutating func nextInt(in range: Range<Int>) -> Int
}

/// Production randomness backed by `SystemRandomNumberGenerator`, Apple's
/// CSPRNG-backed generator.
nonisolated struct SystemRandomSource: RandomNumberSource {
    private var generator = SystemRandomNumberGenerator()

    init() {}

    mutating func nextInt(in range: Range<Int>) -> Int {
        guard range.count > 0 else { return range.lowerBound }
        return Int.random(in: range, using: &generator)
    }
}

/// Deterministic randomness for unit tests and the RTP simulator. Uses the
/// SplitMix64 algorithm: fast, well distributed, and trivial to seed.
nonisolated struct SeededRandomSource: RandomNumberSource {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed &+ 0x9E3779B97F4A7C15
    }

    private mutating func nextUInt64() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z = z ^ (z >> 31)
        return z
    }

    mutating func nextInt(in range: Range<Int>) -> Int {
        let span = UInt64(range.count)
        guard span > 0 else { return range.lowerBound }
        let value = nextUInt64() % span
        return range.lowerBound + Int(value)
    }
}
