import SwiftUI
import SwiftData
import Combine
import UserNotifications

struct ActiveSessionView: View {
    let sessionId: UUID

    @Query private var sessions: [Session]
    @Query private var users: [User]
    @Query private var presets: [DrinkPreset]
    @Environment(\.modelContext) private var modelContext

    @State private var now = Date()
    @State private var showingDrinkSheet = false
    @State private var entryToEdit: LogEntry?

    private var session: Session? { sessions.first }
    private var userSettings: UserSettings { users.first?.settings ?? UserSettings() }
    private var warningThreshold: Int { userSettings.warningThreshold }

    init(sessionId: UUID) {
        self.sessionId = sessionId
        _sessions = Query(filter: #Predicate<Session> { $0.id == sessionId })
    }

    var body: some View {
        Group {
            if let session {
                sessionContent(session)
            } else {
                ContentUnavailableView("Session not found", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { time in
            now = time
        }
    }

    // MARK: - Session Content

    private func sessionContent(_ session: Session) -> some View {
        VStack(spacing: 16) {
            WaterlineIndicator(value: waterlineValue(for: session), warningThreshold: warningThreshold)

            countsSection(for: session)

            reminderStatusSection(for: session)

            if !presets.isEmpty {
                presetChips(for: session)
            }

            quickAddButtons(for: session)

            logTimeline(for: session)
        }
        .padding(.horizontal, 24)
        .sheet(item: $entryToEdit) { entry in
            EditLogEntryView(entry: entry)
        }
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

    // MARK: - Pacing Computation

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

    // MARK: - Log Timeline

    private func logTimeline(for session: Session) -> some View {
        let sorted = session.logEntries.sorted(by: { $0.timestamp > $1.timestamp })
        return Group {
            if sorted.isEmpty {
                Text("No entries yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                List {
                    Section("Timeline") {
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
                .listStyle(.insetGrouped)
                .frame(maxHeight: 300)
            }
        }
    }

    private func deleteEntries(_ offsets: IndexSet, from sorted: [LogEntry], session: Session) {
        for index in offsets {
            let entry = sorted[index]
            modelContext.delete(entry)
        }
        try? modelContext.save()
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
}

#Preview {
    NavigationStack {
        ActiveSessionView(sessionId: UUID())
            .modelContainer(for: [User.self, Session.self, LogEntry.self, DrinkPreset.self], inMemory: true)
    }
}
