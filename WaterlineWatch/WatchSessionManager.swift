import Foundation
import WatchConnectivity
import WatchKit

/// Manages WatchConnectivity on the watchOS side.
/// Receives session state, presets, and water reminders from the phone.
/// Sends log water, log drink, and start session commands back to the phone.
@MainActor
final class WatchSessionManager: NSObject, ObservableObject, @unchecked Sendable {

    // MARK: - Published State

    @Published var waterlineValue: Double = 0
    @Published var drinkCount: Int = 0
    @Published var waterCount: Int = 0
    @Published var isSessionActive: Bool = false
    @Published var pendingReminder: WaterReminder?
    @Published var presets: [WatchPreset] = []

    struct WaterReminder: Identifiable {
        let id = UUID()
        let title: String
        let body: String
        let receivedAt: Date
    }

    /// Lightweight preset representation for the watch (no SwiftData dependency).
    struct WatchPreset: Identifiable {
        let id = UUID()
        let name: String
        let drinkType: String
        let sizeOz: Double
        let standardDrinkEstimate: Double
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

    /// Sends a "log water" command to the phone with haptic confirmation.
    func sendLogWaterCommand() {
        guard let session = wcSession, session.isReachable else { return }
        let message: [String: Any] = [
            "type": "logWater",
            "timestamp": Date().timeIntervalSince1970,
        ]
        session.sendMessage(message, replyHandler: nil)
        WKInterfaceDevice.current().play(.click)
    }

    /// Sends a "log drink" command to the phone with preset data and haptic confirmation.
    func sendLogDrinkCommand(preset: WatchPreset) {
        guard let session = wcSession, session.isReachable else { return }
        let message: [String: Any] = [
            "type": "logDrink",
            "presetName": preset.name,
            "drinkType": preset.drinkType,
            "sizeOz": preset.sizeOz,
            "standardDrinkEstimate": preset.standardDrinkEstimate,
            "timestamp": Date().timeIntervalSince1970,
        ]
        session.sendMessage(message, replyHandler: nil)
        WKInterfaceDevice.current().play(.click)
    }

    /// Sends an "end session" command to the phone with haptic confirmation.
    func sendEndSessionCommand() {
        guard let session = wcSession, session.isReachable else { return }
        let message: [String: Any] = [
            "type": "endSession",
            "timestamp": Date().timeIntervalSince1970,
        ]
        session.sendMessage(message, replyHandler: nil)
        WKInterfaceDevice.current().play(.success)
    }

    /// Sends a "start session" command to the phone with haptic confirmation.
    func sendStartSessionCommand() {
        guard let session = wcSession, session.isReachable else { return }
        let message: [String: Any] = [
            "type": "startSession",
            "timestamp": Date().timeIntervalSince1970,
        ]
        session.sendMessage(message, replyHandler: nil)
        WKInterfaceDevice.current().play(.success)
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

        case "presets":
            handlePresets(data)

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

    private func handlePresets(_ data: [String: Any]) {
        guard let presetDicts = data["presets"] as? [[String: Any]] else { return }
        presets = presetDicts.compactMap { dict in
            guard let name = dict["name"] as? String,
                  let drinkType = dict["drinkType"] as? String,
                  let sizeOz = dict["sizeOz"] as? Double,
                  let estimate = dict["standardDrinkEstimate"] as? Double
            else { return nil }
            return WatchPreset(
                name: name,
                drinkType: drinkType,
                sizeOz: sizeOz,
                standardDrinkEstimate: estimate
            )
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
                let data = Self.encodeMessage(context)
                Task { @MainActor in
                    if let decoded = Self.decodeMessage(data) {
                        self.handleMessage(decoded)
                    }
                }
            }
        }
    }

    /// Receives real-time messages from phone (water reminders, presets when reachable).
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        let data = Self.encodeMessage(message)
        Task { @MainActor in
            if let decoded = Self.decodeMessage(data) {
                self.handleMessage(decoded)
            }
        }
    }

    /// Receives application context updates (session state).
    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        let data = Self.encodeMessage(applicationContext)
        Task { @MainActor in
            if let decoded = Self.decodeMessage(data) {
                self.handleMessage(decoded)
            }
        }
    }

    /// Receives transferred user info (water reminders or presets sent when watch was not reachable).
    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        let data = Self.encodeMessage(userInfo)
        Task { @MainActor in
            if let decoded = Self.decodeMessage(data) {
                self.handleMessage(decoded)
            }
        }
    }

    // MARK: - Sendable Bridge

    /// Encodes a dictionary to JSON Data (Sendable) for safe cross-isolation transfer.
    private nonisolated static func encodeMessage(_ dict: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
    }

    /// Decodes JSON Data back to a dictionary.
    private nonisolated static func decodeMessage(_ data: Data) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
