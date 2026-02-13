import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Session> { !$0.isActive },
        sort: \Session.startTime,
        order: .reverse
    ) private var pastSessions: [Session]

    @Query(
        filter: #Predicate<Session> { $0.isActive }
    ) private var activeSessions: [Session]

    private var activeSession: Session? { activeSessions.first }

    var body: some View {
        NavigationStack {
            Group {
                if let session = activeSession {
                    activeSessionContent(session)
                } else {
                    noSessionContent
                }
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

    // MARK: - Active Session State

    @ViewBuilder
    private func activeSessionContent(_ session: Session) -> some View {
        VStack(spacing: 24) {
            Spacer()

            WaterlineIndicator(value: waterlineValue(for: session))

            countsSection(for: session)

            quickAddButtons(for: session)

            viewSessionButton(for: session)

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func countsSection(for session: Session) -> some View {
        HStack(spacing: 32) {
            VStack(spacing: 4) {
                Text("\(drinkCount(for: session))")
                    .font(.title2.weight(.bold))
                Text("Drinks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 4) {
                Text("\(waterCount(for: session))")
                    .font(.title2.weight(.bold))
                Text("Water")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func quickAddButtons(for session: Session) -> some View {
        HStack(spacing: 16) {
            Button {
                // Drink logging — implemented in US-012/US-014
            } label: {
                Label("Drink", systemImage: "wineglass")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .accessibilityLabel("Add Drink")

            Button {
                // Water logging — implemented in US-013/US-014
            } label: {
                Label("Water", systemImage: "drop.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .accessibilityLabel("Add Water")
        }
    }

    private func viewSessionButton(for session: Session) -> some View {
        NavigationLink(value: session.id) {
            Label("View Session", systemImage: "arrow.right.circle")
                .font(.subheadline.weight(.medium))
        }
        .navigationDestination(for: UUID.self) { sessionId in
            SessionSummaryView(sessionId: sessionId)
        }
    }

    // MARK: - Waterline Computation

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

    // MARK: - No Session State

    private var noSessionContent: some View {
        VStack(spacing: 0) {
            Spacer()

            startSessionSection

            Spacer()

            pastSessionsSection
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

// MARK: - Waterline Indicator

struct WaterlineIndicator: View {
    let value: Double

    private var isWarning: Bool { value >= 2 }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background track
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 200)

                // Center line
                Rectangle()
                    .fill(Color(.systemGray3))
                    .frame(width: 60, height: 2)

                // Fill from center
                GeometryReader { geo in
                    let midY = geo.size.height / 2
                    let maxOffset: CGFloat = geo.size.height / 2 - 8
                    let clampedValue = min(max(value, -5), 5)
                    let fillHeight = abs(clampedValue) / 5.0 * maxOffset
                    let fillColor: Color = isWarning ? .red : (value > 0 ? .orange : .blue)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(fillColor.opacity(0.7))
                        .frame(width: 44, height: fillHeight)
                        .position(
                            x: geo.size.width / 2,
                            y: value >= 0
                                ? midY - fillHeight / 2
                                : midY + fillHeight / 2
                        )
                }
                .frame(width: 60, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text(String(format: "%.1f", value))
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(isWarning ? .red : .primary)

            if isWarning {
                Text("Drink water to return to center")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Waterline level \(String(format: "%.1f", value))")
        .accessibilityValue(isWarning ? "Warning: drink water" : "Normal")
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
