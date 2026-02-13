import Foundation
import UserNotifications
import SwiftData

/// Handles notification actions (e.g., "Log Water" from time-based reminders).
/// Set as `UNUserNotificationCenter.current().delegate` at app launch.
@MainActor
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    var modelContainer: ModelContainer?

    // MARK: - Foreground Presentation

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show banner + sound even when app is in foreground
        [.banner, .sound]
    }

    // MARK: - Action Handling

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let actionIdentifier = response.actionIdentifier
        let notificationIdentifier = response.notification.request.identifier

        // Handle inactivity timeout
        if notificationIdentifier == ReminderService.inactivityCheckIdentifier {
            if actionIdentifier == UNNotificationDefaultActionIdentifier {
                // User tapped the inactivity notification — cancel reminders
                ReminderService.handleInactivityTimeout()
            }
            return
        }

        // Handle "Log Water" action from time-based or per-drink reminders
        if actionIdentifier == ReminderService.logWaterActionIdentifier {
            await logWaterFromNotification()
        }
    }

    // MARK: - Log Water

    @MainActor
    private func logWaterFromNotification() {
        guard let container = modelContainer else { return }

        let context = container.mainContext

        // Find the active session
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        )
        guard let session = try? context.fetch(descriptor).first else { return }

        // Find user settings for default water amount
        let userDescriptor = FetchDescriptor<User>()
        let defaultAmount = (try? context.fetch(userDescriptor).first)?.settings.defaultWaterAmountOz ?? 8

        // Create water log entry
        let entry = LogEntry(
            type: .water,
            waterMeta: WaterMeta(amountOz: Double(defaultAmount)),
            source: .phone
        )
        entry.session = session
        context.insert(entry)
        try? context.save()

        // Reset inactivity timer since user just interacted
        ReminderService.rescheduleInactivityCheck()
    }
}
