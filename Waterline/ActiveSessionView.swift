import SwiftUI
import SwiftData
import Combine
import UserNotifications
import WidgetKit

struct ActiveSessionView: View {
    let sessionId: UUID
    let syncService: SyncService

    @Query private var sessions: [Session]
    @Query private var users: [User]
    @Query private var presets: [DrinkPreset]
    @Environment(\.modelContext) private var modelContext

    @State private var now = Date()
    @State private var showingDrinkSheet = false
    @State private var showingEndConfirmation = false
    @State private var entryToEdit: LogEntry?

    private var session: Session? { sessions.first }
    private var userSettings: UserSettings { users.first?.settings ?? UserSettings() }
    private var warningThreshold: Int { userSettings.warningThreshold }

    init(sessionId: UUID, syncService: SyncService) {
        self.sessionId = sessionId
        self.syncService = syncService
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SyncStatusIndicator(
                    status: syncService.status,
                    pendingCount: syncService.pendingCount
                )
            }
        }
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

            endSessionButton
        }
        .padding(.horizontal, 24)
        .sheet(item: $entryToEdit) { entry in
            EditLogEntryView(entry: entry)
        }
        .confirmationDialog("End this session?", isPresented: $showingEndConfirmation, titleVisibility: .visible) {
            Button("End Session", role: .destructive) {
                endSession(session)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - End Session

    private var endSessionButton: some View {
        Button(role: .destructive) {
            showingEndConfirmation = true
        } label: {
            Label("End Session", systemImage: "stop.circle")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .padding(.top, 8)
    }

    private func endSession(_ session: Session) {
        // Set endTime and deactivate
        session.endTime = Date()
        session.isActive = false

        // Compute and store summary
        computeSummary(for: session)

        // Cancel all active reminders
        ReminderService.cancelAllTimeReminders()

        // End Live Activity — handled in US-032

        // Mark session for re-sync (fields changed since last sync)
        session.needsSync = true
        try? modelContext.save()

        syncService.triggerSync()
        WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")
    }

    private func computeSummary(for session: Session) {
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

        // Pacing adherence: % of times water was logged within the N-drink rule
        // Walk through entries in order, tracking "opportunities" where water was due
        // and how many times the user actually logged water before exceeding the threshold
        let waterEveryN = userSettings.waterEveryNDrinks
        let adherence = computePacingAdherence(entries: entries, waterEveryN: waterEveryN)

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
    }

    /// Computes pacing adherence as the percentage of N-drink intervals where the user
    /// logged water before exceeding the threshold.
    /// For each group of N consecutive alcoholic drinks, if water was logged before the
    /// next drink group started, that counts as adherent. Returns 1.0 if no drinks or no
    /// expected water breaks.
    private func computePacingAdherence(entries: [LogEntry], waterEveryN: Int) -> Double {
        var drinksSinceWater = 0
        var waterDueCount = 0
        var waterLoggedCount = 0

        for entry in entries {
            if entry.type == .alcohol {
                drinksSinceWater += 1
                if drinksSinceWater >= waterEveryN {
                    waterDueCount += 1
                    drinksSinceWater = 0
                }
            } else if entry.type == .water {
                if waterDueCount > waterLoggedCount {
                    waterLoggedCount = min(waterLoggedCount + 1, waterDueCount)
                }
                drinksSinceWater = 0
            }
        }

        guard waterDueCount > 0 else { return 1.0 }
        return Double(waterLoggedCount) / Double(waterDueCount)
    }

    // MARK: - Counts

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
        syncService.triggerSync()
        WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")
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
        checkPacingWarning(for: session, addedEstimate: preset.standardDrinkEstimate)
        syncService.triggerSync()
        WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")
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
            LogDrinkView(session: session) { estimate in
                ReminderService.rescheduleInactivityCheck()
                checkPerDrinkReminder(for: session)
                checkPacingWarning(for: session, addedEstimate: estimate)
                syncService.triggerSync()
                WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")
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
        syncService.triggerSync()
        WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")
    }

    // MARK: - Per-Drink Water Reminder

    private func checkPerDrinkReminder(for session: Session) {
        let sinceLastWater = alcoholCountSinceLastWater(for: session)
        let waterEveryN = userSettings.waterEveryNDrinks
        if sinceLastWater >= waterEveryN {
            schedulePerDrinkWaterReminder(drinkCount: sinceLastWater)
        }
    }

    // MARK: - Pacing Warning

    /// Checks if the waterline just crossed the warning threshold after logging a drink.
    /// Fires a notification only once per crossing (was below, now at/above).
    private func checkPacingWarning(for session: Session, addedEstimate: Double) {
        let currentValue = waterlineValue(for: session)
        let previousValue = currentValue - addedEstimate
        let threshold = Double(warningThreshold)
        if previousValue < threshold && currentValue >= threshold {
            ReminderService.schedulePacingWarning()
        }
    }

    private func schedulePerDrinkWaterReminder(drinkCount: Int) {
        ReminderService.schedulePerDrinkReminder(drinkCount: drinkCount)
    }
}

#Preview {
    let container = try! ModelContainer(for: User.self, Session.self, LogEntry.self, DrinkPreset.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    NavigationStack {
        ActiveSessionView(
            sessionId: UUID(),
            syncService: SyncService(convexService: nil, modelContainer: container)
        )
        .modelContainer(container)
    }
}
