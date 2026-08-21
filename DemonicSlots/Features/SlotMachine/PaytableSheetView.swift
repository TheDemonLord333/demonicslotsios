//
//  PaytableSheetView.swift
//  DemonicSlots
//
//  Native SwiftUI sheet listing symbols, multipliers, paylines, and the
//  wild/scatter/free-spin rules for one game.
//
import SwiftUI

struct PaytableSheetView: View {
    let definition: SlotGameDefinition
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Symbole") {
                    ForEach(definition.symbols) { symbol in
                        symbolRow(symbol)
                    }
                }

                if let wildID = definition.wildSymbolID, let wild = definition.symbol(for: wildID) {
                    Section("Wild-Symbol") {
                        Text("\(wild.displayName) ersetzt alle regulären Symbole, niemals den Scatter. Eine reine Wild-Kombination kann selbst gewinnen. Bei mehreren möglichen Kombinationen zählt pro Linie nur die höchste Auszahlung.")
                            .font(.callout)
                    }
                }

                if let scatterID = definition.scatterSymbolID,
                   let scatter = definition.symbol(for: scatterID),
                   let rules = definition.freeSpinsRules {
                    Section("Scatter & Freispiele") {
                        Text("\(scatter.displayName) zählt überall im Feld, unabhängig von Gewinnlinien.")
                            .font(.callout)
                        ForEach(rules.triggerPayouts, id: \.scatterCount) { payout in
                            Text("\(payout.scatterCount)× \(scatter.displayName): \(payout.totalBetMultiplier)× Gesamteinsatz, \(payout.freeSpinsAwarded) Freispiele")
                                .font(.callout)
                        }
                        Text("Retrigger: ab \(rules.retriggerMinimumScatterCount) neuen Scattern +\(rules.retriggerFreeSpinsAwarded) Freispiele, maximal \(rules.maxFreeSpins) Freispiele pro Runde.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("Während der Freispiele werden alle Liniengewinne mit \(rules.winMultiplier)× multipliziert. Der auslösende Einsatz bleibt für die gesamte Runde gespeichert.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Gewinnlinien (\(definition.paylines.count))") {
                    ForEach(definition.paylines) { payline in
                        paylineRow(payline)
                    }
                }
            }
            .navigationTitle("Auszahlungstabelle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                        .frame(minHeight: 44)
                }
            }
        }
    }

    private func symbolRow(_ symbol: SlotSymbol) -> some View {
        HStack(spacing: 12) {
            SymbolArtworkView(symbol: symbol)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(symbol.displayName)
                    .font(.subheadline.weight(.semibold))
                if let entry = definition.paytableEntry(for: symbol.id) {
                    Text(entry.payoutByMatchCount
                        .sorted { $0.key < $1.key }
                        .map { "\($0.key)×: \($0.value)×" }
                        .joined(separator: "   "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if symbol.kind == .scatter {
                    Text("Scatter – siehe Regeln unten")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func paylineRow(_ payline: Payline) -> some View {
        HStack(spacing: 12) {
            Text("Linie \(payline.id)")
                .font(.caption.weight(.semibold))
                .frame(width: 56, alignment: .leading)
            MiniPaylineDiagram(rowIndices: payline.rowIndices, visibleRows: definition.visibleRows)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Linie \(payline.id): Reihen \(payline.rowIndices.map(String.init).joined(separator: ", "))")
    }
}

private struct MiniPaylineDiagram: View {
    let rowIndices: [Int]
    let visibleRows: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(rowIndices.enumerated()), id: \.offset) { _, activeRow in
                VStack(spacing: 2) {
                    ForEach(0..<visibleRows, id: \.self) { row in
                        Circle()
                            .fill(row == activeRow ? DemonicPalette.emberOrange : Color.gray.opacity(0.25))
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
    }
}

#Preview {
    PaytableSheetView(definition: InfernalForgeDefinition.definition)
}
