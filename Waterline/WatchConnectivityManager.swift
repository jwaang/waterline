import Foundation
import WatchConnectivity

/// Manages WatchConnectivity on the iOS side.
/// Sends session state and water reminders to the watch.
/// Receives commands (log water) from the watch.
@MainActor
final class WatchConnectivityManager: NSObject, @unchecked Sendable {

    // Callback for when watch requests water logging
    var onWatchLogWater: (() -> Void)?

    private var wcSession: WCSession?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.wcSession = session
    }

    // MARK: - Send Water Reminder to Watch

    /// Sends a water reminder message to the watch for haptic nudge.
    /// Called when the phone fires a time-based, per-drink, or pacing warning notification.
    func sendWaterReminder(title: String, body: String) {
        guard let session = wcSession, session.isReachable else {
            // Watch not reachable — try transferUserInfo as fallback
            sendWaterReminderViaTransfer(title: title, body: body)
            return
        }
        let message: [String: Any] = [
            "type": "waterReminder",
            "title": title,
            "body": body,
            "timestamp": Date().timeIntervalSince1970,
        ]
        session.sendMessage(message, replyHandler: nil)
    }

    /// Sends session state to watch for display (waterline value, counts).
    func sendSessionState(
        waterlineValue: Double,
        drinkCount: Int,
        waterCount: Int,
        isActive: Bool
    ) {
        guard let session = wcSession, session.activationState == .activated else { return }
        let context: [String: Any] = [
            "type": "sessionState",
            "waterlineValue": waterlineValue,
            "drinkCount": drinkCount,
            "waterCount": waterCount,
            "isActive": isActive,
            "timestamp": Date().timeIntervalSince1970,
        ]
        // Application context is queued and delivered when watch is available
        try? session.updateApplicationContext(context)
    }

    // MARK: - Private

    private func sendWaterReminderViaTransfer(title: String, body: String) {
        guard let session = wcSession, session.activationState == .activated else { return }
        let info: [String: Any] = [
            "type": "waterReminder",
            "title": title,
            "body": body,
            "timestamp": Date().timeIntervalSince1970,
        ]
        session.transferUserInfo(info)
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // No-op; activation is automatic
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate for multi-watch support
        session.activate()
    }

    /// Receives messages from watch (e.g., "logWater" command).
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        guard let type = message["type"] as? String else { return }
        if type == "logWater" {
            Task { @MainActor in
                self.onWatchLogWater?()
            }
        }
    }
}
