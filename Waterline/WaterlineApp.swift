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

        // Wire WatchConnectivity for forwarding water reminders to watch
        let watchManager = watchConnectivityManager
        let containerRef = container
        watchManager.onWatchLogWater = {
            WaterlineApp.handleWatchLogWater(container: containerRef)
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
                }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Handles "log water" command received from Apple Watch.
    /// Creates a water LogEntry in the active session.
    @MainActor
    private static func handleWatchLogWater(container: ModelContainer) {
        let context = container.mainContext

        // Find active session
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        )
        guard let session = try? context.fetch(descriptor).first else { return }

        // Get default water amount from user settings
        let userDescriptor = FetchDescriptor<User>()
        let defaultAmount = (try? context.fetch(userDescriptor).first)?.settings.defaultWaterAmountOz ?? 8

        // Create water log entry with watch source
        let entry = LogEntry(
            type: .water,
            waterMeta: WaterMeta(amountOz: Double(defaultAmount)),
            source: .watch
        )
        entry.session = session
        context.insert(entry)
        try? context.save()

        // Reset inactivity timer
        ReminderService.rescheduleInactivityCheck()
        WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")
    }
}
