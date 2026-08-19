//
//  RTPSimulationDebugView.swift
//  DemonicSlots
//
//  DEBUG-only screen that runs `SlotSimulator` for >= 1,000,000 spins and
//  reports observed RTP, hit rate, bonus rate and max payout. Never
//  compiled into a Release build, and never shown outside `SettingsView`'s
//  debug section - the finished app must not display a fixed RTP figure
//  until a simulation like this has actually confirmed one.
//
#if DEBUG
import SwiftUI

struct RTPSimulationDebugView: View {
    @State private var report: SlotSimulationReport?
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 20) {
            Group {
                if let report {
                    Text(report.summary)
                        .font(.system(.body, design: .monospaced))
                } else if isRunning {
                    ProgressView("Simuliere 1.000.000 Spins…")
                } else {
                    Text("Noch keine Simulation ausgeführt.")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("1.000.000 Spins simulieren") {
                runSimulation()
            }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: 44)
            .disabled(isRunning)
        }
        .padding()
        .navigationTitle("RTP-Simulation")
    }

    private func runSimulation() {
        isRunning = true
        report = nil
        Task.detached(priority: .userInitiated) {
            let result = SlotSimulator.run(
                definition: InfernalForgeDefinition.definition,
                betPerLine: 1,
                spinCount: 1_000_000
            )
            await MainActor.run {
                report = result
                isRunning = false
            }
        }
    }
}
#endif
