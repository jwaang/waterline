import AppIntents
import os
import SwiftData
import WidgetKit

private let log = Logger(subsystem: "com.waterline.app", category: "LogWaterIntent")

struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Water"
    static let description = IntentDescription("Log water to your active session.")

    func perform() async throws -> some IntentResult {
        log.info("perform() called")

        let container = try SharedModelContainer.create()
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        )
        guard let session = try? context.fetch(descriptor).first else {
            log.warning("No active session found")
            return .result()
        }

        log.info("Found active session")

        let userDescriptor = FetchDescriptor<User>()
        let user = try? context.fetch(userDescriptor).first
        let defaultAmount = user?.settings.defaultWaterAmountOz ?? 8

        let entry = LogEntry(
            type: .water,
            waterMeta: WaterMeta(amountOz: Double(defaultAmount)),
            source: .widget
        )
        entry.session = session
        context.insert(entry)
        try context.save()
        log.info("Entry saved")

        // Re-fetch log entries to include the just-inserted entry
        let sessionId = session.id
        let logDescriptor = FetchDescriptor<LogEntry>(
            predicate: #Predicate { $0.session?.id == sessionId }
        )
        let allLogs = (try? context.fetch(logDescriptor)) ?? []

        let threshold = user?.settings.warningThreshold ?? 2
        let engineState = WaterlineEngine.computeState(from: allLogs, warningThreshold: threshold)
        log.info("State: wl=\(engineState.waterlineValue) drinks=\(engineState.totalAlcoholCount) water=\(engineState.totalWaterCount)")

        // Notify main app to update Live Activity
        LiveActivityBridge.postUpdate(
            waterlineValue: engineState.waterlineValue,
            drinkCount: engineState.totalAlcoholCount,
            waterCount: engineState.totalWaterCount,
            isWarning: engineState.isWarning
        )
        log.info("Bridge update posted")

        WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")

        return .result()
    }
}
