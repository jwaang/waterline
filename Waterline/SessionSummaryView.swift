import SwiftUI
import SwiftData

struct SessionSummaryView: View {
    let sessionId: UUID

    @Query private var sessions: [Session]
    @Query private var users: [User]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var entryToEdit: LogEntry?

    private var userSettings: UserSettings { users.first?.settings ?? UserSettings() }

    init(sessionId: UUID) {
        self.sessionId = sessionId
        _sessions = Query(filter: #Predicate<Session> { $0.id == sessionId })
    }

    private var session: Session? {
        sessions.first
    }

    var body: some View {
        Group {
            if let session {
                sessionContent(session)
            } else {
                ContentUnavailableView("Session Not Found", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("Session Summary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private func sessionContent(_ session: Session) -> some View {
        List {
            overviewSection(for: session)
            timelineSection(for: session)
        }
        .sheet(item: $entryToEdit, onDismiss: {
            // Recompute summary when edit sheet dismisses
            if let session = self.session {
                recomputeSummary(for: session)
            }
        }) { entry in
            EditLogEntryView(entry: entry)
        }
    }

    // MARK: - Overview

    private func overviewSection(for session: Session) -> some View {
        Section("Overview") {
            LabeledContent("Date", value: session.startTime, format: .dateTime.month().day().year())
            LabeledContent("Duration", value: durationText(for: session))
            LabeledContent("Drinks", value: "\(drinkCount(for: session))")
            LabeledContent("Standard Drinks", value: String(format: "%.1f", totalStandardDrinks(for: session)))
            LabeledContent("Water", value: "\(waterCount(for: session)) (\(totalWaterVolume(for: session)) oz)")

            LabeledContent("Pacing Adherence", value: String(format: "%.0f%%", computePacingAdherence(for: session) * 100))
            LabeledContent("Final Waterline", value: String(format: "%.1f", waterlineValue(for: session)))
        }
    }

    // MARK: - Timeline

    private func timelineSection(for session: Session) -> some View {
        let sorted = session.logEntries.sorted(by: { $0.timestamp < $1.timestamp })
        return Section("Timeline") {
            if sorted.isEmpty {
                Text("No entries")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sorted) { entry in
                    LogEntryRow(entry: entry)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            entryToEdit = entry
                        }
                }
                .onDelete { offsets in
                    deleteEntries(offsets, from: sorted, session: session)
                }
            }
        }
    }

    private func deleteEntries(_ offsets: IndexSet, from sorted: [LogEntry], session: Session) {
        for index in offsets {
            let entry = sorted[index]
            modelContext.delete(entry)
        }
        try? modelContext.save()

        // Recompute summary after delete
        recomputeSummary(for: session)
    }

    // MARK: - Recompute Summary

    private func recomputeSummary(for session: Session) {
        let entries = session.logEntries.sorted(by: { $0.timestamp < $1.timestamp })

        let totalDrinks = entries.filter { $0.type == .alcohol }.count
        let totalWater = entries.filter { $0.type == .water }.count
        let totalStdDrinks = entries.compactMap { $0.alcoholMeta?.standardDrinkEstimate }.reduce(0, +)

        let duration: TimeInterval
        if let endTime = session.endTime {
            duration = endTime.timeIntervalSince(session.startTime)
        } else {
            duration = Date().timeIntervalSince(session.startTime)
        }

        let adherence = computePacingAdherence(for: session)

        var wlValue: Double = 0
        for entry in entries {
            if entry.type == .alcohol, let meta = entry.alcoholMeta {
                wlValue += meta.standardDrinkEstimate
            } else if entry.type == .water {
                wlValue -= 1
            }
        }

        session.computedSummary = SessionSummary(
            totalDrinks: totalDrinks,
            totalWater: totalWater,
            totalStandardDrinks: totalStdDrinks,
            durationSeconds: duration,
            pacingAdherence: adherence,
            finalWaterlineValue: wlValue
        )
        try? modelContext.save()
    }

    // MARK: - Computation

    private func waterlineValue(for session: Session) -> Double {
        var value: Double = 0
        for entry in session.logEntries.sorted(by: { $0.timestamp < $1.timestamp }) {
            if entry.type == .alcohol, let meta = entry.alcoholMeta {
                value += meta.standardDrinkEstimate
            } else if entry.type == .water {
                value -= 1
            }
        }
        return value
    }

    private func drinkCount(for session: Session) -> Int {
        session.logEntries.filter { $0.type == .alcohol }.count
    }

    private func waterCount(for session: Session) -> Int {
        session.logEntries.filter { $0.type == .water }.count
    }

    private func totalStandardDrinks(for session: Session) -> Double {
        session.logEntries.compactMap { $0.alcoholMeta?.standardDrinkEstimate }.reduce(0, +)
    }

    private func totalWaterVolume(for session: Session) -> Int {
        Int(session.logEntries.filter { $0.type == .water }.compactMap { $0.waterMeta?.amountOz }.reduce(0, +))
    }

    /// Chunk-based pacing adherence: walks entries in order, tracking groups of N drinks.
    /// When drinksSinceWater reaches waterEveryN, a water opportunity is due.
    /// Water entries logged when there are outstanding opportunities count as adherence.
    private func computePacingAdherence(for session: Session) -> Double {
        let waterEveryN = userSettings.waterEveryNDrinks
        let entries = session.logEntries.sorted(by: { $0.timestamp < $1.timestamp })

        var waterDueCount = 0
        var waterLoggedCount = 0
        var drinksSinceWater = 0

        for entry in entries {
            if entry.type == .alcohol {
                drinksSinceWater += 1
                if drinksSinceWater >= waterEveryN {
                    waterDueCount += 1
                    drinksSinceWater = 0
                }
            } else if entry.type == .water {
                if waterDueCount > waterLoggedCount {
                    waterLoggedCount += 1
                }
                drinksSinceWater = 0
            }
        }

        guard waterDueCount > 0 else { return 1.0 }
        return min(Double(waterLoggedCount) / Double(waterDueCount), 1.0)
    }

    private func durationText(for session: Session) -> String {
        if let summary = session.computedSummary {
            let hours = Int(summary.durationSeconds) / 3600
            let minutes = (Int(summary.durationSeconds) % 3600) / 60
            return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
        }
        guard let endTime = session.endTime else { return "—" }
        let seconds = endTime.timeIntervalSince(session.startTime)
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
