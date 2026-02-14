import ActivityKit
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
    @State private var showingSummary = false
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
        .navigationDestination(isPresented: $showingSummary) {
            SessionSummaryView(sessionId: sessionId)
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

        // End Live Activity
        let wl = waterlineValue(for: session)
        LiveActivityManager.endActivity(
            waterlineValue: wl,
            drinkCount: drinkCount(for: session),
            waterCount: waterCount(for: session),
            isWarning: wl >= Double(warningThreshold)
        )

        // Mark for sync and persist
        session.needsSync = true
        try? modelContext.save()

        // Sync to Convex
        syncService.triggerSync()

        // Reload widgets
        WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")

        // Navigate to summary
        showingSummary = true
    }

    private func computeSummary(for session: Session) {
        session.computedSummary = WaterlineEngine.computeSummary(
            from: session.logEntries,
            startTime: session.startTime,
            endTime: session.endTime,
            waterEveryN: userSettings.waterEveryNDrinks,
            warningThreshold: warningThreshold
        )
    }

    // MARK: - Live Activity

    private func updateLiveActivity(for session: Session) {
        let wl = waterlineValue(for: session)
        LiveActivityManager.updateActivity(
            waterlineValue: wl,
            drinkCount: drinkCount(for: session),
            waterCount: waterCount(for: session),
            isWarning: wl >= Double(warningThreshold)
        )
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
        WaterlineEngine.computeState(from: session.logEntries, warningThreshold: warningThreshold).alcoholCountSinceLastWater
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
        updateLiveActivity(for: session)
    }

    // MARK: - Waterline Computation

    private func waterlineState(for session: Session) -> WaterlineEngine.WaterlineState {
        WaterlineEngine.computeState(from: session.logEntries, warningThreshold: warningThreshold)
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
        updateLiveActivity(for: session)
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
                updateLiveActivity(for: session)
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
        updateLiveActivity(for: session)
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
        ReminderService.schedulePerDrinkReminder(drinkCount: drinkCount, discreetMode: userSettings.discreetNotifications)
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
