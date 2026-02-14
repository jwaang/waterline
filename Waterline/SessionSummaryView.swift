import SwiftUI
import SwiftData

struct SessionSummaryView: View {
    let sessionId: UUID
    let allowsEditing: Bool

    @Query private var sessions: [Session]
    @Query private var users: [User]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var entryToEdit: LogEntry?

    private var userSettings: UserSettings { users.first?.settings ?? UserSettings() }

    init(sessionId: UUID, allowsEditing: Bool = true) {
        self.sessionId = sessionId
        self.allowsEditing = allowsEditing
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
                            if allowsEditing {
                                entryToEdit = entry
                            }
                        }
                }
                .onDelete { offsets in
                    if allowsEditing {
                        deleteEntries(offsets, from: sorted, session: session)
                    }
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
        session.computedSummary = WaterlineEngine.computeSummary(
            from: session.logEntries,
            startTime: session.startTime,
            endTime: session.endTime,
            waterEveryN: userSettings.waterEveryNDrinks,
            warningThreshold: userSettings.warningThreshold
        )
        try? modelContext.save()
    }

    // MARK: - Computation

    private func waterlineState(for session: Session) -> WaterlineEngine.WaterlineState {
        WaterlineEngine.computeState(from: session.logEntries, warningThreshold: userSettings.warningThreshold)
    }

    private func waterlineValue(for session: Session) -> Double {
        waterlineState(for: session).waterlineValue
    }

    private func drinkCount(for session: Session) -> Int {
        waterlineState(for: session).totalAlcoholCount
    }

    private func waterCount(for session: Session) -> Int {
        waterlineState(for: session).totalWaterCount
    }

    private func totalStandardDrinks(for session: Session) -> Double {
        waterlineState(for: session).totalStandardDrinks
    }

    private func totalWaterVolume(for session: Session) -> Int {
        Int(waterlineState(for: session).totalWaterVolumeOz)
    }

    private func computePacingAdherence(for session: Session) -> Double {
        WaterlineEngine.computePacingAdherence(from: session.logEntries, waterEveryN: userSettings.waterEveryNDrinks)
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
