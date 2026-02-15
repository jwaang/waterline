import ActivityKit
import SwiftUI
import SwiftData
import UserNotifications
import WidgetKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.startTime, order: .reverse)
    private var allSessions: [Session]

    @Query private var users: [User]
    @Query private var presets: [DrinkPreset]

    let authManager: AuthenticationManager
    let syncService: SyncService

    @State private var navigationPath = NavigationPath()
    @State private var showingDrinkSheet = false
    @State private var showingAbandonedSessionAlert = false
    @State private var abandonedSessionHours: Int = 0
    @State private var showingEndConfirmation = false
    @State private var entryToEdit: LogEntry?

    @State private var activeSession: Session?
    private var pastSessions: [Session] { allSessions.filter { !$0.isActive } }
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
            .wlScreen()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("WATERLINE")
                        .font(.wlHeadline)
                        .foregroundStyle(Color.wlInk)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(authManager: authManager, syncService: syncService)
                    } label: {
                        Text(">>")
                            .font(.wlTechnicalMono)
                            .foregroundStyle(Color.wlInk)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .navigationDestination(for: UUID.self) { sessionId in
                sessionDestination(for: sessionId)
            }
            .onAppear {
                activeSession = allSessions.first(where: { $0.isActive })
                checkForAbandonedSession()
            }
            .onChange(of: allSessions) { _, newValue in
                activeSession = newValue.first(where: { $0.isActive })
            }
            .onReceive(NotificationCenter.default.publisher(for: .watchDidModifySession)) { _ in
                activeSession = allSessions.first(where: { $0.isActive })
            }
            .alert("Session Still Running", isPresented: $showingAbandonedSessionAlert) {
                Button("End Now", role: .destructive) {
                    if let session = activeSession {
                        endAbandonedSession(session)
                    }
                }
                Button("Keep Going", role: .cancel) {}
            } message: {
                Text("Your session has been running for \(abandonedSessionHours) hours. End it?")
            }
        }
    }

    // MARK: - Active Session State

    @ViewBuilder
    private func activeSessionContent(_ session: Session) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                WLGauge(value: waterlineValue(for: session), warningThreshold: warningThreshold)

                // Counts
                HStack(spacing: 16) {
                    WLGridCell(value: "\(drinkCount(for: session))", label: "DRINKS")
                    WLGridCell(value: "\(waterCount(for: session))", label: "WATER")
                }

                reminderStatusSection(for: session)

                if !presets.isEmpty {
                    presetChips(for: session)
                }

                quickAddButtons(for: session)

                logTimeline(for: session)

                WLActionBlock(label: "End Session", style: .secondary, warningText: true) {
                    showingEndConfirmation = true
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, WLSpacing.screenMargin)
            .padding(.vertical, WLSpacing.sectionPadding)
        }
        .sheet(item: $entryToEdit) { entry in
            EditLogEntryView(entry: entry)
                .presentationCornerRadius(0)
        }
        .alert("End this session?", isPresented: $showingEndConfirmation) {
            Button("End Session", role: .destructive) {
                endSession(session)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Reminder Status

    private func reminderStatusSection(for session: Session) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 4) {
                waterDueText(for: session)
                nextReminderText(for: session, now: context.date)
            }
        }
    }

    private func waterDueText(for session: Session) -> some View {
        let sinceLastWater = alcoholCountSinceLastWater(for: session)
        let waterEveryN = userSettings.waterEveryNDrinks
        let remaining = max(waterEveryN - sinceLastWater, 0)

        return Group {
            if remaining == 0 {
                Text("WATER DUE NOW")
                    .wlTechnical()
                    .foregroundStyle(Color.wlWarning)
            } else {
                Text("WATER DUE IN: \(remaining) DRINK\(remaining == 1 ? "" : "S")")
                    .wlTechnical()
                    .foregroundStyle(Color.wlInk)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func nextReminderText(for session: Session, now: Date) -> some View {
        if userSettings.timeRemindersEnabled {
            let countdown = nextReminderCountdown(for: session, now: now)
            Text("NEXT REMINDER: \(countdown.uppercased())")
                .wlTechnical()
                .accessibilityElement(children: .combine)
        }
    }

    private func alcoholCountSinceLastWater(for session: Session) -> Int {
        WaterlineEngine.computeState(from: session.logEntries, warningThreshold: warningThreshold).alcoholCountSinceLastWater
    }

    private func nextReminderCountdown(for session: Session, now: Date) -> String {
        let intervalMinutes = userSettings.timeReminderIntervalMinutes
        let intervalSeconds = Double(intervalMinutes) * 60
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
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(presets) { preset in
                    WLChip(
                        label: preset.name,
                        detail: String(format: "%.1f std", preset.standardDrinkEstimate)
                    ) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        logPreset(preset, for: session)
                    }
                    .accessibilityLabel("\(preset.name), \(preset.standardDrinkEstimate) standard drinks")
                }
            }
        }
        .scrollIndicators(.hidden)
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

        Task {
            try? modelContext.save()
            ReminderService.rescheduleInactivityCheck()
            checkPerDrinkReminder(for: session)
            checkPacingWarning(for: session, addedEstimate: preset.standardDrinkEstimate)
            syncService.triggerSync()
            WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")
            updateLiveActivity(for: session)
            NotificationCenter.default.post(name: .phoneSessionDidChange, object: nil)
        }
    }

    // MARK: - Quick Add Buttons

    private func quickAddButtons(for session: Session) -> some View {
        HStack(spacing: 16) {
            WLActionBlock(label: "+ Drink") {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showingDrinkSheet = true
            }
            .accessibilityLabel("Add Drink")

            WLActionBlock(label: "+ Water", style: .secondary) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                logWater(for: session)
            }
            .accessibilityLabel("Add Water")
        }
        .sheet(isPresented: $showingDrinkSheet) {
            LogDrinkView(session: session) { estimate in
                Task {
                    ReminderService.rescheduleInactivityCheck()
                    checkPerDrinkReminder(for: session)
                    checkPacingWarning(for: session, addedEstimate: estimate)
                    syncService.triggerSync()
                    WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")
                    updateLiveActivity(for: session)
                    NotificationCenter.default.post(name: .phoneSessionDidChange, object: nil)
                }
            }
            .presentationCornerRadius(0)
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

        Task {
            try? modelContext.save()
            ReminderService.rescheduleInactivityCheck()
            syncService.triggerSync()
            WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")
            updateLiveActivity(for: session)
            NotificationCenter.default.post(name: .phoneSessionDidChange, object: nil)
        }
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

    // MARK: - Log Timeline

    private func logTimeline(for session: Session) -> some View {
        let sorted = session.logEntries.sorted(by: { $0.timestamp > $1.timestamp })
        return Group {
            if sorted.isEmpty {
                Text("NO ENTRIES YET")
                    .wlTechnical()
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    WLSectionHeader(title: "EVENT LOG")

                    ForEach(sorted) { entry in
                        LogEntryRow(entry: entry)
                            .padding(.horizontal, WLSpacing.screenMargin)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                entryToEdit = entry
                            }

                        if entry.id != sorted.last?.id {
                            WLRule()
                                .padding(.leading, WLSpacing.screenMargin)
                        }
                    }
                }
            }
        }
    }

    // MARK: - End Session

    private func endSession(_ session: Session) {
        session.endTime = Date()
        session.isActive = false
        activeSession = nil

        session.computedSummary = WaterlineEngine.computeSummary(
            from: session.logEntries,
            startTime: session.startTime,
            endTime: session.endTime,
            waterEveryN: userSettings.waterEveryNDrinks,
            warningThreshold: warningThreshold
        )

        navigationPath.append(session.id)

        Task {
            ReminderService.cancelAllTimeReminders()

            let wl = waterlineValue(for: session)
            LiveActivityManager.endActivity(
                waterlineValue: wl,
                drinkCount: drinkCount(for: session),
                waterCount: waterCount(for: session),
                isWarning: wl >= Double(warningThreshold)
            )

            session.needsSync = true
            try? modelContext.save()

            syncService.triggerSync()
            WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")
            NotificationCenter.default.post(name: .phoneSessionDidChange, object: nil)
        }
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

    // MARK: - No Session State

    private var noSessionContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                startSessionSection
                    .padding(.top, 40)

                pastSessionsSection
            }
        }
    }

    // MARK: - Start Session

    private var startSessionSection: some View {
        WLActionBlock(label: "Begin Session") {
            startSession()
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
    }

    private func startSession() {
        if activeSession != nil { return }

        let session = Session(startTime: Date(), isActive: true)
        modelContext.insert(session)
        activeSession = session

        Task {
            try? modelContext.save()

            if userSettings.timeRemindersEnabled {
                ReminderService.scheduleTimeReminders(intervalMinutes: userSettings.timeReminderIntervalMinutes)
            }

            syncService.triggerSync()
            WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")
            LiveActivityManager.startActivity(sessionId: session.id, startTime: session.startTime, warningThreshold: userSettings.warningThreshold)
            NotificationCenter.default.post(name: .phoneSessionDidChange, object: nil)
        }
    }

    // MARK: - Abandoned Session Handling

    private func checkForAbandonedSession() {
        guard let session = activeSession else { return }
        let elapsed = Date().timeIntervalSince(session.startTime)
        let hours = Int(elapsed / 3600)
        if hours >= 12 {
            abandonedSessionHours = hours
            showingAbandonedSessionAlert = true
        }
    }

    private func endAbandonedSession(_ session: Session) {
        session.endTime = Date()
        session.isActive = false
        activeSession = nil

        session.computedSummary = WaterlineEngine.computeSummary(
            from: session.logEntries,
            startTime: session.startTime,
            endTime: session.endTime,
            waterEveryN: userSettings.waterEveryNDrinks,
            warningThreshold: warningThreshold
        )

        Task {
            let state = WaterlineEngine.computeState(from: session.logEntries, warningThreshold: warningThreshold)

            ReminderService.cancelAllTimeReminders()
            LiveActivityManager.endActivity(
                waterlineValue: state.waterlineValue,
                drinkCount: state.totalAlcoholCount,
                waterCount: state.totalWaterCount,
                isWarning: state.isWarning
            )
            try? modelContext.save()
            syncService.triggerSync()
            WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")
            NotificationCenter.default.post(name: .phoneSessionDidChange, object: nil)
        }
    }

    // MARK: - Navigation Routing

    @ViewBuilder
    private func sessionDestination(for sessionId: UUID) -> some View {
        SessionSummaryView(sessionId: sessionId)
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
        Text("NO SESSIONS RECORDED")
            .wlTechnical()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }

    private var pastSessionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            WLSectionHeader(title: "HISTORY")

            ForEach(pastSessions.prefix(5)) { session in
                NavigationLink(value: session.id) {
                    PastSessionRow(session: session)
                }
                .padding(.horizontal, WLSpacing.screenMargin)
                .padding(.vertical, 10)

                if session.id != pastSessions.prefix(5).last?.id {
                    WLRule()
                        .padding(.leading, WLSpacing.screenMargin)
                }
            }
        }
    }
}

// MARK: - Past Session Row

struct PastSessionRow: View {
    let session: Session

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(session.startTime, format: .dateTime.month(.abbreviated).day().year())
                    .font(.wlTechnicalMono)
                    .foregroundStyle(Color.wlInk)
                Spacer()
                Text("\(drinkCount) drinks / \(waterCount) water")
                    .font(.wlTechnicalMono)
                    .foregroundStyle(Color.wlSecondary)
            }
            HStack {
                Text(timeRangeText)
                    .font(.wlTechnicalMono)
                    .foregroundStyle(Color.wlSecondary)
                Spacer()
                Text(durationText)
                    .font(.wlTechnicalMono)
                    .foregroundStyle(Color.wlSecondary)
            }
        }
    }

    private var timeRangeText: String {
        let startFormatted = session.startTime.formatted(.dateTime.hour().minute())
        guard let endTime = session.endTime else {
            return "\(startFormatted) – —"
        }
        let endFormatted = endTime.formatted(.dateTime.hour().minute())
        return "\(startFormatted) – \(endFormatted)"
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
            return "\(hours)H \(minutes)M"
        }
        return "\(minutes)M"
    }
}

#Preview {
    let container = try! ModelContainer(for: User.self, Session.self, LogEntry.self, DrinkPreset.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    HomeView(
        authManager: AuthenticationManager(store: InMemoryCredentialStore()),
        syncService: SyncService(convexService: nil, modelContainer: container)
    )
    .modelContainer(container)
}
