import Foundation
import UserNotifications

/// Manages time-based water reminder notifications during active sessions.
///
/// Responsibilities:
/// - Schedule repeating reminders at the user's configured interval
/// - Cancel all reminders when a session ends
/// - Track last activity time and cancel reminders after 90 minutes of inactivity
/// - Register the notification category with "Log Water" and "Dismiss" actions
enum ReminderService {

    // MARK: - Constants

    static let categoryIdentifier = "WATER_REMINDER"
    static let logWaterActionIdentifier = "LOG_WATER_ACTION"
    static let dismissActionIdentifier = "DISMISS_ACTION"
    static let reminderIdentifierPrefix = "timeReminder-"
    static let inactivityCheckIdentifier = "inactivityCheck"
    static let inactivityThresholdSeconds: TimeInterval = 90 * 60 // 90 minutes

    // MARK: - Category Registration

    /// Registers the notification category with "Log Water" and "Dismiss" actions.
    /// Call once at app launch.
    static func registerCategory() {
        let logWaterAction = UNNotificationAction(
            identifier: logWaterActionIdentifier,
            title: "Log Water",
            options: [.foreground]
        )
        let dismissAction = UNNotificationAction(
            identifier: dismissActionIdentifier,
            title: "Dismiss",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [logWaterAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Schedule Time-Based Reminders

    /// Schedules repeating time-based water reminders at the given interval.
    /// Each reminder fires once; we schedule the next one from the trigger time.
    /// Also schedules the inactivity check.
    static func scheduleTimeReminders(intervalMinutes: Int) {
        let intervalSeconds = TimeInterval(intervalMinutes * 60)

        let content = UNMutableNotificationContent()
        content.title = "Time for water"
        content.body = "Take a break and have some water"
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier

        // UNTimeIntervalNotificationTrigger with repeats: true handles recurring delivery
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: intervalSeconds,
            repeats: true
        )
        let request = UNNotificationRequest(
            identifier: "\(reminderIdentifierPrefix)recurring",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)

        // Schedule inactivity check
        scheduleInactivityCheck()
    }

    // MARK: - Cancel All Time Reminders

    /// Cancels all time-based reminders and the inactivity check.
    /// Call when session ends.
    static func cancelAllTimeReminders() {
        let center = UNUserNotificationCenter.current()
        // Remove pending time reminders and inactivity check
        center.removePendingNotificationRequests(withIdentifiers: [
            "\(reminderIdentifierPrefix)recurring",
            inactivityCheckIdentifier,
        ])
        // Also remove any delivered time reminders from notification center
        center.removeDeliveredNotifications(withIdentifiers: [
            "\(reminderIdentifierPrefix)recurring",
        ])
    }

    // MARK: - Inactivity Tracking

    /// Reschedules the inactivity check from now. Call after each log entry.
    /// If no further logs happen within 90 minutes, the check fires and cancels reminders.
    static func rescheduleInactivityCheck() {
        let center = UNUserNotificationCenter.current()
        // Cancel existing inactivity check
        center.removePendingNotificationRequests(withIdentifiers: [inactivityCheckIdentifier])
        // Schedule a new one
        scheduleInactivityCheck()
    }

    /// Schedules a silent local notification at 90 minutes from now.
    /// When it fires, the delegate cancels all time reminders.
    private static func scheduleInactivityCheck() {
        let content = UNMutableNotificationContent()
        content.title = "Session paused"
        content.body = "No activity for 90 minutes — reminders paused"
        content.sound = nil
        content.categoryIdentifier = categoryIdentifier

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: inactivityThresholdSeconds,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: inactivityCheckIdentifier,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Called when the inactivity check fires. Cancels all time-based reminders.
    static func handleInactivityTimeout() {
        cancelAllTimeReminders()
    }

    // MARK: - Pacing Warning

    /// Fires a pacing warning notification when waterline crosses the warning threshold.
    /// Only call when `previousValue < threshold` and `newValue >= threshold` to ensure
    /// the notification fires once per crossing.
    static func schedulePacingWarning() {
        let content = UNMutableNotificationContent()
        content.title = "Waterline is high"
        content.body = "Your Waterline is high — drink water to return to center"
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "pacingWarning-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}
