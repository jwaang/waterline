import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Session> { !$0.isActive },
        sort: \Session.startTime,
        order: .reverse
    ) private var pastSessions: [Session]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                startSessionSection

                Spacer()

                pastSessionsSection
            }
            .navigationTitle("Waterline")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Settings navigation — implemented in US-024
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
    }

    // MARK: - Start Session

    private var startSessionSection: some View {
        Button {
            // Session start — implemented in US-009
        } label: {
            Label("Start Session", systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
    }

    // MARK: - Past Sessions

    private var pastSessionsSection: some View {
        Group {
            if pastSessions.isEmpty {
                emptyState
            } else {
                pastSessionsList
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No past sessions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Start a session to begin tracking.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var pastSessionsList: some View {
        List {
            Section {
                ForEach(pastSessions.prefix(5)) { session in
                    NavigationLink(value: session.id) {
                        PastSessionRow(session: session)
                    }
                }
            } header: {
                Text("Past Sessions")
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: UUID.self) { sessionId in
            SessionSummaryView(sessionId: sessionId)
        }
    }
}

// MARK: - Past Session Row

struct PastSessionRow: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.startTime, style: .date)
                .font(.subheadline.weight(.medium))

            HStack(spacing: 16) {
                Label(durationText, systemImage: "clock")
                Label("\(drinkCount) drinks", systemImage: "wineglass")
                Label("\(waterCount) water", systemImage: "drop")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var durationText: String {
        if let summary = session.computedSummary {
            return formatDuration(summary.durationSeconds)
        }
        guard let endTime = session.endTime else { return "—" }
        return formatDuration(endTime.timeIntervalSince(session.startTime))
    }

    private var drinkCount: Int {
        if let summary = session.computedSummary {
            return summary.totalDrinks
        }
        return session.logEntries.filter { $0.type == .alcohol }.count
    }

    private var waterCount: Int {
        if let summary = session.computedSummary {
            return summary.totalWater
        }
        return session.logEntries.filter { $0.type == .water }.count
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [User.self, Session.self, LogEntry.self, DrinkPreset.self], inMemory: true)
}
