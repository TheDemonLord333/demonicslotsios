//
//  PendingSpin.swift
//  DemonicSlots
//
//  Durable record of an in-flight spin transaction. The full outcome is
//  computed and persisted here *before* any coins move, so if the app is
//  killed mid-spin, the next launch can finish exactly that spin - crediting
//  a win it owes, or discarding a spin whose stake was never taken - without
//  ever charging or paying out twice.
//
import Foundation
import SwiftData

@Model
final class PendingSpin {
    @Attribute(.unique) var transactionID: UUID
    var gameID: String
    var betPerLine: Int64
    var totalBet: Int64
    var isFreeSpin: Bool
    var freeSpinMultiplier: Int64
    var createdAt: Date
    /// JSON-encoded `SpinEvaluation`, computed once up front and replayed on
    /// recovery - the outcome is never re-rolled.
    var evaluationData: Data
    var stakeDebited: Bool
    var payoutCredited: Bool

    init(
        transactionID: UUID = UUID(),
        gameID: String,
        betPerLine: Int64,
        totalBet: Int64,
        isFreeSpin: Bool,
        freeSpinMultiplier: Int64,
        createdAt: Date = .now,
        evaluationData: Data,
        stakeDebited: Bool = false,
        payoutCredited: Bool = false
    ) {
        self.transactionID = transactionID
        self.gameID = gameID
        self.betPerLine = betPerLine
        self.totalBet = totalBet
        self.isFreeSpin = isFreeSpin
        self.freeSpinMultiplier = freeSpinMultiplier
        self.createdAt = createdAt
        self.evaluationData = evaluationData
        self.stakeDebited = stakeDebited
        self.payoutCredited = payoutCredited
    }

    func decodedEvaluation() -> SpinEvaluation? {
        try? JSONDecoder().decode(SpinEvaluation.self, from: evaluationData)
    }

    static func encode(_ evaluation: SpinEvaluation) throws -> Data {
        try JSONEncoder().encode(evaluation)
    }
}
