import Foundation
import WatchConnectivity

/// Manages WatchConnectivity on the iOS side.
/// Sends session state, presets, and water reminders to the watch.
/// Receives commands (log water, log drink, start session) from the watch.
@MainActor
final class WatchConnectivityManager: NSObject, @unchecked Sendable {

    // Callbacks for watch commands
    var onWatchLogWater: (() -> Void)?
    var onWatchLogDrink: ((_ presetName: String, _ drinkType: String, _ sizeOz: Double, _ standardDrinkEstimate: Double) -> Void)?
    var onWatchStartSession: (() -> Void)?

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

    /// Sends drink presets to the watch for the preset picker.
    /// Each preset is serialized as a dictionary with name, drinkType, sizeOz, standardDrinkEstimate.
    func sendPresets(_ presets: [[String: Any]]) {
        guard let session = wcSession, session.activationState == .activated else { return }
        let message: [String: Any] = [
            "type": "presets",
            "presets": presets,
            "timestamp": Date().timeIntervalSince1970,
        ]
        // Use sendMessage for immediate delivery if reachable, otherwise transferUserInfo
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
        } else {
            session.transferUserInfo(message)
        }
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

    /// Receives messages from watch (e.g., "logWater", "logDrink", "startSession" commands).
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        guard let type = message["type"] as? String else { return }
        switch type {
        case "logWater":
            Task { @MainActor in
                self.onWatchLogWater?()
            }
        case "logDrink":
            let name = message["presetName"] as? String ?? "Drink"
            let drinkType = message["drinkType"] as? String ?? "beer"
            let sizeOz = message["sizeOz"] as? Double ?? 12.0
            let estimate = message["standardDrinkEstimate"] as? Double ?? 1.0
            Task { @MainActor in
                self.onWatchLogDrink?(name, drinkType, sizeOz, estimate)
            }
        case "startSession":
            Task { @MainActor in
                self.onWatchStartSession?()
            }
        default:
            break
        }
    }
}
