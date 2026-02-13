import Foundation
import WatchConnectivity
import WatchKit

/// Manages WatchConnectivity on the watchOS side.
/// Receives water reminders from the phone and plays haptic.
/// Sends log water commands back to the phone.
@MainActor
final class WatchSessionManager: NSObject, ObservableObject, @unchecked Sendable {

    // MARK: - Published State

    @Published var waterlineValue: Double = 0
    @Published var drinkCount: Int = 0
    @Published var waterCount: Int = 0
    @Published var isSessionActive: Bool = false
    @Published var pendingReminder: WaterReminder?

    struct WaterReminder: Identifiable {
        let id = UUID()
        let title: String
        let body: String
        let receivedAt: Date
    }

    private var wcSession: WCSession?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.wcSession = session
    }

    // MARK: - Send Commands to Phone

    /// Sends a "log water" command to the phone.
    func sendLogWaterCommand() {
        guard let session = wcSession, session.isReachable else { return }
        let message: [String: Any] = [
            "type": "logWater",
            "timestamp": Date().timeIntervalSince1970,
        ]
        session.sendMessage(message, replyHandler: nil)
    }

    // MARK: - Handle Incoming Data

    private func handleMessage(_ data: [String: Any]) {
        guard let type = data["type"] as? String else { return }

        switch type {
        case "waterReminder":
            let title = data["title"] as? String ?? "Time for water"
            let body = data["body"] as? String ?? "Take a break and have some water"
            handleWaterReminder(title: title, body: body)

        case "sessionState":
            handleSessionState(data)

        default:
            break
        }
    }

    private func handleWaterReminder(title: String, body: String) {
        // Play haptic on watch — gentle notification pattern
        WKInterfaceDevice.current().play(.notification)

        // Store the reminder for UI display
        pendingReminder = WaterReminder(
            title: title,
            body: body,
            receivedAt: Date()
        )
    }

    private func handleSessionState(_ data: [String: Any]) {
        if let wl = data["waterlineValue"] as? Double {
            waterlineValue = wl
        }
        if let dc = data["drinkCount"] as? Int {
            drinkCount = dc
        }
        if let wc = data["waterCount"] as? Int {
            waterCount = wc
        }
        if let active = data["isActive"] as? Bool {
            isSessionActive = active
        }
    }

    /// Dismisses the current pending reminder.
    func dismissReminder() {
        pendingReminder = nil
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // On activation, read any existing application context
        if activationState == .activated {
            let context = session.receivedApplicationContext
            if !context.isEmpty {
                Task { @MainActor in
                    self.handleMessage(context)
                }
            }
        }
    }

    /// Receives real-time messages from phone (water reminders when reachable).
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            self.handleMessage(message)
        }
    }

    /// Receives application context updates (session state).
    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            self.handleMessage(applicationContext)
        }
    }

    /// Receives transferred user info (water reminders sent when watch was not reachable).
    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        Task { @MainActor in
            self.handleMessage(userInfo)
        }
    }
}
