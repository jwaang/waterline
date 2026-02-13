import SwiftUI
import SwiftData
import UserNotifications

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

    @Query private var users: [User]
    @Query private var presets: [DrinkPreset]

    @State private var navigationPath = NavigationPath()
    @State private var now = Date()
    @State private var showingDrinkSheet = false

    private var activeSession: Session? { activeSessions.first }
    private var userSettings: UserSettings { users.first?.settings ?? UserSettings() }
    private var warningThreshold: Int { userSettings.warningThreshold }

    var body: some View {
        NavigationStack(path: $navigationPath) {
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
                    NavigationLink {
                        PresetsListView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .navigationDestination(for: UUID.self) { sessionId in
                sessionDestination(for: sessionId)
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { time in
                now = time
            }
        }
    }

    // MARK: - Active Session State

    @ViewBuilder
    private func activeSessionContent(_ session: Session) -> some View {
        VStack(spacing: 24) {
            Spacer()

            WaterlineIndicator(value: waterlineValue(for: session), warningThreshold: warningThreshold)

            countsSection(for: session)

            reminderStatusSection(for: session)

            if !presets.isEmpty {
                presetChips(for: session)
            }

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

    // MARK: - Reminder Status

    private func reminderStatusSection(for session: Session) -> some View {
        VStack(spacing: 8) {
            waterDueText(for: session)
            nextReminderText(for: session)
        }
    }

    private func waterDueText(for session: Session) -> some View {
        let sinceLastWater = alcoholCountSinceLastWater(for: session)
        let waterEveryN = userSettings.waterEveryNDrinks
        let remaining = max(waterEveryN - sinceLastWater, 0)

        return HStack(spacing: 4) {
            Image(systemName: "drop")
                .foregroundStyle(.blue)
            if remaining == 0 {
                Text("Water due now")
                    .foregroundStyle(.orange)
            } else {
                Text("Water due in: \(remaining) drink\(remaining == 1 ? "" : "s")")
            }
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func nextReminderText(for session: Session) -> some View {
        if userSettings.timeRemindersEnabled {
            let countdown = nextReminderCountdown(for: session)
            HStack(spacing: 4) {
                Image(systemName: "bell")
                    .foregroundStyle(.purple)
                Text("Next reminder: \(countdown)")
            }
            .font(.subheadline)
            .accessibilityElement(children: .combine)
        }
    }

    private func alcoholCountSinceLastWater(for session: Session) -> Int {
        var count = 0
        for entry in session.logEntries.sorted(by: { $0.timestamp < $1.timestamp }) {
            if entry.type == .alcohol {
                count += 1
            } else if entry.type == .water {
                count = 0
            }
        }
        return count
    }

    private func nextReminderCountdown(for session: Session) -> String {
        let intervalSeconds = Double(userSettings.timeReminderIntervalMinutes) * 60
        let sortedEntries = session.logEntries.sorted(by: { $0.timestamp < $1.timestamp })
        let lastLogTime = sortedEntries.last?.timestamp ?? session.startTime
        let nextReminderTime = lastLogTime.addingTimeInterval(intervalSeconds)
        let remaining = nextReminderTime.timeIntervalSince(now)

        if remaining <= 0 {
            return "now"
        }

        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Preset Chips

    private func presetChips(for session: Session) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(presets) { preset in
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        logPreset(preset, for: session)
                    } label: {
                        VStack(spacing: 2) {
                            Text(preset.name)
                                .font(.subheadline.weight(.medium))
                            Text("\(preset.standardDrinkEstimate, specifier: "%.1f") std")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.15))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(preset.name), \(preset.standardDrinkEstimate) standard drinks")
                }
            }
        }
    }

    private func logPreset(_ preset: DrinkPreset, for session: Session) {
        let entry = LogEntry(
            timestamp: Date(),
            type: .alcohol,
            alcoholMeta: AlcoholMeta(
                drinkType: preset.drinkType,
                sizeOz: preset.sizeOz,
                abv: preset.abv,
                standardDrinkEstimate: preset.standardDrinkEstimate,
                presetId: preset.id
            ),
            source: .phone
        )
        entry.session = session
        modelContext.insert(entry)
        try? modelContext.save()

        // Reset inactivity timer on activity
        ReminderService.rescheduleInactivityCheck()
        checkPerDrinkReminder(for: session)
    }

    // MARK: - Quick Add Buttons

    private func quickAddButtons(for session: Session) -> some View {
        HStack(spacing: 16) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showingDrinkSheet = true
            } label: {
                Label("Drink", systemImage: "wineglass")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .accessibilityLabel("Add Drink")

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                logWater(for: session)
            } label: {
                Label("Water", systemImage: "drop.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .accessibilityLabel("Add Water")
        }
        .sheet(isPresented: $showingDrinkSheet) {
            LogDrinkView(session: session) {
                ReminderService.rescheduleInactivityCheck()
                checkPerDrinkReminder(for: session)
            }
        }
    }

    // MARK: - Log Water

    private func logWater(for session: Session) {
        let entry = LogEntry(
            type: .water,
            waterMeta: WaterMeta(amountOz: Double(userSettings.defaultWaterAmountOz)),
            source: .phone
        )
        entry.session = session
        modelContext.insert(entry)
        try? modelContext.save()

        // Reset inactivity timer on activity
        ReminderService.rescheduleInactivityCheck()
    }

    // MARK: - Per-Drink Water Reminder

    private func checkPerDrinkReminder(for session: Session) {
        let sinceLastWater = alcoholCountSinceLastWater(for: session)
        let waterEveryN = userSettings.waterEveryNDrinks
        if sinceLastWater >= waterEveryN {
            schedulePerDrinkWaterReminder(drinkCount: sinceLastWater)
        }
    }

    private func schedulePerDrinkWaterReminder(drinkCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Time for water"
        content.body = "You've had \(drinkCount) drink\(drinkCount == 1 ? "" : "s") — time for water"
        content.sound = .default
        content.categoryIdentifier = ReminderService.categoryIdentifier

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "perDrinkReminder-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func viewSessionButton(for session: Session) -> some View {
        NavigationLink(value: session.id) {
            Label("View Session", systemImage: "arrow.right.circle")
                .font(.subheadline.weight(.medium))
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
            startSession()
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

    private func startSession() {
        // Single-active constraint: if one exists, navigate to it
        if let existing = activeSession {
            navigationPath.append(existing.id)
            return
        }

        let session = Session(startTime: Date(), isActive: true)
        modelContext.insert(session)
        try? modelContext.save()

        navigationPath.append(session.id)

        // Schedule time-based reminders if enabled
        if userSettings.timeRemindersEnabled {
            ReminderService.scheduleTimeReminders(intervalMinutes: userSettings.timeReminderIntervalMinutes)
        }

        // Background Convex sync — fire-and-forget
        syncSessionToConvex(session)

        // Live Activity — handled in US-032
    }

    private func syncSessionToConvex(_ session: Session) {
        // Convex sync requires user context; find user to get Convex userId
        // For now, sync using the session data — ConvexService integration
        // will be connected when ConvexService is injected via environment
        Task.detached { @Sendable in
            // Placeholder for Convex sync — will be wired when ConvexService
            // is available in the environment (US-026 offline-first sync)
        }
    }

    // MARK: - Navigation Routing

    @ViewBuilder
    private func sessionDestination(for sessionId: UUID) -> some View {
        if activeSessions.contains(where: { $0.id == sessionId }) {
            ActiveSessionView(sessionId: sessionId)
        } else {
            SessionSummaryView(sessionId: sessionId)
        }
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
    }
}

// MARK: - Waterline Indicator

struct WaterlineIndicator: View {
    let value: Double
    var warningThreshold: Int = 2

    private var isWarning: Bool { value >= Double(warningThreshold) }

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
