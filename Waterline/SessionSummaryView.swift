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
                ZStack {
                    Color.wlBase.ignoresSafeArea()
                    VStack(spacing: 8) {
                        Text("ERROR")
                            .wlTechnical()
                            .foregroundStyle(Color.wlWarning)
                        Text("Session not found")
                            .font(.wlBody)
                            .foregroundStyle(Color.wlSecondary)
                    }
                }
            }
        }
        .wlScreen()
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("SESSION SUMMARY")
                    .font(.wlHeadline)
                    .foregroundStyle(Color.wlInk)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .font(.wlControl)
                .foregroundStyle(Color.wlInk)
            }
        }
    }

    @ViewBuilder
    private func sessionContent(_ session: Session) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                overviewSection(for: session)
                timelineSection(for: session)
            }
            .padding(.vertical, 8)
        }
        .background(Color.wlBase)
        .sheet(item: $entryToEdit, onDismiss: {
            if let session = self.session {
                recomputeSummary(for: session)
            }
        }) { entry in
            EditLogEntryView(entry: entry)
                .presentationCornerRadius(0)
        }
    }

    // MARK: - Overview

    private func overviewSection(for session: Session) -> some View {
        VStack(spacing: 0) {
            WLSectionHeader(title: "OVERVIEW")

            // Metrics grid
            HStack(spacing: 16) {
                WLGridCell(value: "\(drinkCount(for: session))", label: "DRINKS")
                WLGridCell(value: "\(waterCount(for: session))", label: "WATER")
            }
            .padding(.horizontal, WLSpacing.screenMargin)
            .padding(.vertical, 12)

            HStack(spacing: 16) {
                WLGridCell(value: String(format: "%.1f", totalStandardDrinks(for: session)), label: "STD DRINKS")
                WLGridCell(value: String(format: "%.1f", waterlineValue(for: session)), label: "FINAL WL")
            }
            .padding(.horizontal, WLSpacing.screenMargin)
            .padding(.bottom, 12)

            // Detail rows
            VStack(spacing: 0) {
                summaryRow(label: "DATE", value: session.startTime.formatted(.dateTime.month().day().year()))
                WLRule()
                summaryRow(label: "DURATION", value: durationText(for: session))
                WLRule()
                summaryRow(label: "WATER VOLUME", value: "\(totalWaterVolume(for: session)) OZ")
                WLRule()
                summaryRow(label: "PACING", value: String(format: "%.0f%%", computePacingAdherence(for: session) * 100))
            }
            .padding(.horizontal, WLSpacing.screenMargin)
            .padding(.bottom, 16)
        }
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .wlTechnical()
            Spacer()
            Text(value)
                .font(.wlTechnicalMono)
                .foregroundStyle(Color.wlInk)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Timeline

    private func timelineSection(for session: Session) -> some View {
        let sorted = session.logEntries.sorted(by: { $0.timestamp < $1.timestamp })
        return VStack(alignment: .leading, spacing: 0) {
            WLSectionHeader(title: "TIMELINE")

            if sorted.isEmpty {
                Text("NO ENTRIES")
                    .wlTechnical()
                    .padding(.horizontal, WLSpacing.screenMargin)
                    .padding(.vertical, 16)
            } else {
                ForEach(sorted) { entry in
                    LogEntryRow(entry: entry)
                        .padding(.horizontal, WLSpacing.screenMargin)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if allowsEditing {
                                entryToEdit = entry
                            }
                        }

                    if entry.id != sorted.last?.id {
                        WLRule()
                            .padding(.leading, WLSpacing.screenMargin)
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
            return hours > 0 ? "\(hours)H \(minutes)M" : "\(minutes)M"
        }
        guard let endTime = session.endTime else { return "—" }
        let seconds = endTime.timeIntervalSince(session.startTime)
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return hours > 0 ? "\(hours)H \(minutes)M" : "\(minutes)M"
    }
}
