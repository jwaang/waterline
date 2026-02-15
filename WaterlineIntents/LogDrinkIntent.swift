import AppIntents
import os
import SwiftData
import WidgetKit

private let log = Logger(subsystem: "com.waterline.app", category: "LogDrinkIntent")

struct LogDrinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Drink"
    static let description = IntentDescription("Log an alcoholic drink to your active session.")

    @Parameter(title: "Preset ID", description: "Optional drink preset ID to use instead of default standard drink.")
    var presetId: String?

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

        // Resolve preset if provided
        var drinkType: DrinkType = .beer
        var sizeOz: Double = 12
        var standardDrinkEstimate: Double = 1.0
        var resolvedPresetId: UUID?

        if let presetIdString = presetId, let presetUUID = UUID(uuidString: presetIdString) {
            let presetDescriptor = FetchDescriptor<DrinkPreset>(
                predicate: #Predicate { $0.id == presetUUID }
            )
            if let preset = try? context.fetch(presetDescriptor).first {
                drinkType = preset.drinkType
                sizeOz = preset.sizeOz
                standardDrinkEstimate = preset.standardDrinkEstimate
                resolvedPresetId = preset.id
            }
        }

        let entry = LogEntry(
            type: .alcohol,
            alcoholMeta: AlcoholMeta(
                drinkType: drinkType,
                sizeOz: sizeOz,
                standardDrinkEstimate: standardDrinkEstimate,
                presetId: resolvedPresetId
            ),
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

        let userDescriptor = FetchDescriptor<User>()
        let threshold = (try? context.fetch(userDescriptor).first)?.settings.warningThreshold ?? 2
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
