import SwiftUI
import SwiftData
import UserNotifications

@main
struct WaterlineApp: App {
    @State private var authManager = AuthenticationManager()
    private let notificationDelegate = NotificationDelegate()
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

        // Register notification categories (time reminders, per-drink reminders)
        ReminderService.registerCategory()

        // Set notification delegate for action handling
        let delegate = notificationDelegate
        delegate.modelContainer = container
        UNUserNotificationCenter.current().delegate = delegate
    }

    var body: some Scene {
        WindowGroup {
            RootView(authManager: authManager)
                .onAppear {
                    authManager.restoreSession()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
