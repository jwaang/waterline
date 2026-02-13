import SwiftUI
import SwiftData

struct SessionSummaryView: View {
    let sessionId: UUID

    @Query private var sessions: [Session]

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
    }

    @ViewBuilder
    private func sessionContent(_ session: Session) -> some View {
        List {
            Section("Overview") {
                LabeledContent("Date", value: session.startTime, format: .dateTime.month().day().year())
                LabeledContent("Duration", value: durationText(for: session))

                if let summary = session.computedSummary {
                    LabeledContent("Drinks", value: "\(summary.totalDrinks)")
                    LabeledContent("Standard Drinks", value: String(format: "%.1f", summary.totalStandardDrinks))
                    LabeledContent("Water", value: "\(summary.totalWater)")
                    LabeledContent("Pacing Adherence", value: String(format: "%.0f%%", summary.pacingAdherence * 100))
                    LabeledContent("Final Waterline", value: String(format: "%.1f", summary.finalWaterlineValue))
                }
            }
        }
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
