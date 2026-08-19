//
//  DateProvider.swift
//  DemonicSlots
//
//  Testable indirection over "now", so calendar-day logic (Soul Rescue)
//  can be exercised deterministically in unit tests.
//
import Foundation

protocol DateProvider: Sendable {
    func now() -> Date
}

struct SystemDateProvider: DateProvider {
    func now() -> Date { Date() }
}

struct FixedDateProvider: DateProvider {
    let fixedDate: Date
    func now() -> Date { fixedDate }
}
