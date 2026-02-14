import ActivityKit
import SwiftUI
import SwiftData
import UserNotifications
import WidgetKit

@main
struct WaterlineApp: App {
    @State private var authManager = AuthenticationManager()
    @State private var syncService: SyncService
    private let notificationDelegate = NotificationDelegate()
    private let watchConnectivityManager = WatchConnectivityManager()
    private let sharedModelContainer: ModelContainer

    init() {
        // Create a shared model container
        let container: ModelContainer
        do {
            container = try ModelContainer(for: User.self, Session.self, LogEntry.self, DrinkPreset.self)
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
        self.sharedModelContainer = container

        // Create sync service (ConvexService is nil until deployment URL is configured)
        _syncService = State(initialValue: SyncService(convexService: nil, modelContainer: container))

        // Register notification categories (time reminders, per-drink reminders)
        ReminderService.registerCategory()

        // Set notification delegate for action handling
        let delegate = notificationDelegate
        delegate.modelContainer = container
        UNUserNotificationCenter.current().delegate = delegate

        // Wire WatchConnectivity for watch commands
        let watchManager = watchConnectivityManager
        let containerRef = container
        watchManager.onWatchLogWater = {
            WaterlineApp.handleWatchLogWater(container: containerRef, watchManager: watchManager)
        }
        watchManager.onWatchLogDrink = { presetName, drinkType, sizeOz, standardDrinkEstimate in
            WaterlineApp.handleWatchLogDrink(
                container: containerRef,
                watchManager: watchManager,
                presetName: presetName,
                drinkType: drinkType,
                sizeOz: sizeOz,
                standardDrinkEstimate: standardDrinkEstimate
            )
        }
        watchManager.onWatchStartSession = {
            WaterlineApp.handleWatchStartSession(container: containerRef, watchManager: watchManager)
        }
        watchManager.onWatchEndSession = {
            WaterlineApp.handleWatchEndSession(container: containerRef, watchManager: watchManager)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(authManager: authManager, syncService: syncService)
                .onAppear {
                    authManager.restoreSession()
                    syncService.start()
                    // Set watch manager on ReminderService for forwarding reminders
                    ReminderService.watchManager = watchConnectivityManager
                    // Send initial session state and presets to watch
                    WaterlineApp.sendWatchUpdate(container: sharedModelContainer, watchManager: watchConnectivityManager)
                }
        }
        .modelContainer(sharedModelContainer)
    }

    // MARK: - Watch Command Handlers

    /// Handles "log water" command received from Apple Watch.
    @MainActor
    private static func handleWatchLogWater(container: ModelContainer, watchManager: WatchConnectivityManager) {
        let context = container.mainContext

        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        )
        guard let session = try? context.fetch(descriptor).first else { return }

        let userDescriptor = FetchDescriptor<User>()
        let defaultAmount = (try? context.fetch(userDescriptor).first)?.settings.defaultWaterAmountOz ?? 8

        let entry = LogEntry(
            type: .water,
            waterMeta: WaterMeta(amountOz: Double(defaultAmount)),
            source: .watch
        )
        entry.session = session
        context.insert(entry)
        try? context.save()

        ReminderService.rescheduleInactivityCheck()
        WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")
        updateLiveActivityFromSession(session)
        sendWatchUpdate(container: container, watchManager: watchManager)
    }

    /// Handles "log drink" command received from Apple Watch with preset data.
    @MainActor
    private static func handleWatchLogDrink(
        container: ModelContainer,
        watchManager: WatchConnectivityManager,
        presetName: String,
        drinkType: String,
        sizeOz: Double,
        standardDrinkEstimate: Double
    ) {
        let context = container.mainContext

        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        )
        guard let session = try? context.fetch(descriptor).first else { return }

        let parsedDrinkType = DrinkType(rawValue: drinkType) ?? .beer

        let entry = LogEntry(
            type: .alcohol,
            alcoholMeta: AlcoholMeta(
                drinkType: parsedDrinkType,
                sizeOz: sizeOz,
                standardDrinkEstimate: standardDrinkEstimate
            ),
            source: .watch
        )
        entry.session = session
        context.insert(entry)
        try? context.save()

        ReminderService.rescheduleInactivityCheck()
        WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")

        // Check per-drink reminder
        let userDescriptor = FetchDescriptor<User>()
        let settings = (try? context.fetch(userDescriptor).first)?.settings ?? UserSettings()
        let sinceLastWater = alcoholCountSinceLastWater(session: session)
        if sinceLastWater >= settings.waterEveryNDrinks {
            ReminderService.schedulePerDrinkReminder(drinkCount: sinceLastWater)
        }

        // Check pacing warning
        let currentWL = waterlineValue(session: session)
        let previousWL = currentWL - standardDrinkEstimate
        if previousWL < Double(settings.warningThreshold) && currentWL >= Double(settings.warningThreshold) {
            ReminderService.schedulePacingWarning()
        }

        updateLiveActivityFromSession(session)
        sendWatchUpdate(container: container, watchManager: watchManager)
    }

    /// Handles "start session" command received from Apple Watch.
    @MainActor
    private static func handleWatchStartSession(container: ModelContainer, watchManager: WatchConnectivityManager) {
        let context = container.mainContext

        // Check if a session is already active
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        )
        if let existing = try? context.fetch(descriptor).first, existing.isActive {
            // Already active — just send current state to watch
            sendWatchUpdate(container: container, watchManager: watchManager)
            return
        }

        // Create new session
        let session = Session()

        // Associate with user
        let userDescriptor = FetchDescriptor<User>()
        if let user = try? context.fetch(userDescriptor).first {
            session.user = user
        }

        context.insert(session)
        try? context.save()

        // Schedule time-based reminders if enabled
        let settings = (try? context.fetch(FetchDescriptor<User>()).first)?.settings ?? UserSettings()
        if settings.timeRemindersEnabled {
            ReminderService.scheduleTimeReminders(intervalMinutes: settings.timeReminderIntervalMinutes)
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")
        LiveActivityManager.startActivity(sessionId: session.id, startTime: session.startTime)
        sendWatchUpdate(container: container, watchManager: watchManager)
    }

    /// Handles "end session" command received from Apple Watch.
    @MainActor
    private static func handleWatchEndSession(container: ModelContainer, watchManager: WatchConnectivityManager) {
        let context = container.mainContext

        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        )
        guard let session = try? context.fetch(descriptor).first else {
            // No active session — just update watch state
            sendWatchUpdate(container: container, watchManager: watchManager)
            return
        }

        // End the session
        session.endTime = Date()
        session.isActive = false

        // Compute summary via WaterlineEngine
        let userDescriptor = FetchDescriptor<User>()
        let settings = (try? context.fetch(userDescriptor).first)?.settings ?? UserSettings()

        session.computedSummary = WaterlineEngine.computeSummary(
            from: session.logEntries,
            startTime: session.startTime,
            endTime: session.endTime,
            waterEveryN: settings.waterEveryNDrinks,
            warningThreshold: settings.warningThreshold
        )

        let state = WaterlineEngine.computeState(from: session.logEntries, warningThreshold: settings.warningThreshold)

        // Cancel reminders
        ReminderService.cancelAllTimeReminders()

        // End Live Activity
        LiveActivityManager.endActivity(
            waterlineValue: state.waterlineValue,
            drinkCount: state.totalAlcoholCount,
            waterCount: state.totalWaterCount,
            isWarning: state.isWarning
        )

        // Mark for sync and save
        session.needsSync = true
        try? context.save()

        // Reload widgets
        WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")

        // Send updated state to watch (isActive will now be false)
        sendWatchUpdate(container: container, watchManager: watchManager)
    }

    // MARK: - Watch State Sync

    /// Sends current session state and presets to the watch.
    @MainActor
    private static func sendWatchUpdate(container: ModelContainer, watchManager: WatchConnectivityManager) {
        let context = container.mainContext

        let sessionDescriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        )
        let activeSession = try? context.fetch(sessionDescriptor).first

        let wl = activeSession.map { waterlineValue(session: $0) } ?? 0
        let dc = activeSession?.logEntries.filter { $0.type == .alcohol }.count ?? 0
        let wc = activeSession?.logEntries.filter { $0.type == .water }.count ?? 0
        let isActive = activeSession?.isActive ?? false

        watchManager.sendSessionState(
            waterlineValue: wl,
            drinkCount: dc,
            waterCount: wc,
            isActive: isActive
        )

        // Send presets
        let presetDescriptor = FetchDescriptor<DrinkPreset>()
        if let presets = try? context.fetch(presetDescriptor) {
            let presetDicts: [[String: Any]] = presets.map { preset in
                [
                    "name": preset.name,
                    "drinkType": preset.drinkType.rawValue,
                    "sizeOz": preset.sizeOz,
                    "standardDrinkEstimate": preset.standardDrinkEstimate,
                ]
            }
            watchManager.sendPresets(presetDicts)
        }
    }

    // MARK: - Live Activity Helper

    private static func updateLiveActivityFromSession(_ session: Session, warningThreshold: Int = 2) {
        let state = WaterlineEngine.computeState(from: session.logEntries, warningThreshold: warningThreshold)
        LiveActivityManager.updateActivity(
            waterlineValue: state.waterlineValue,
            drinkCount: state.totalAlcoholCount,
            waterCount: state.totalWaterCount,
            isWarning: state.isWarning
        )
    }

    // MARK: - Computation Helpers

    private static func waterlineValue(session: Session) -> Double {
        WaterlineEngine.computeState(from: session.logEntries).waterlineValue
    }

    private static func alcoholCountSinceLastWater(session: Session) -> Int {
        WaterlineEngine.computeState(from: session.logEntries).alcoholCountSinceLastWater
    }
}
