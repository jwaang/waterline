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

    // MARK: - Computation Helpers

    private static func waterlineValue(session: Session) -> Double {
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

    private static func alcoholCountSinceLastWater(session: Session) -> Int {
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
}
