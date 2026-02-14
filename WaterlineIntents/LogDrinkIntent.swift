import ActivityKit
import AppIntents
import SwiftData
import WidgetKit

struct LogDrinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Drink"
    static let description = IntentDescription("Log an alcoholic drink to your active session.")

    @Parameter(title: "Preset ID", description: "Optional drink preset ID to use instead of default standard drink.")
    var presetId: String?

    func perform() async throws -> some IntentResult {
        let container = try ModelContainer(for: User.self, Session.self, LogEntry.self, DrinkPreset.self)
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        )
        guard let session = try? context.fetch(descriptor).first else {
            return .result()
        }

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

        // Recompute state for Live Activity update
        let userDescriptor = FetchDescriptor<User>()
        let threshold = (try? context.fetch(userDescriptor).first)?.settings.warningThreshold ?? 2
        let engineState = WaterlineEngine.computeState(from: session.logEntries, warningThreshold: threshold)

        let state = SessionActivityAttributes.ContentState(
            waterlineValue: engineState.waterlineValue,
            drinkCount: engineState.totalAlcoholCount,
            waterCount: engineState.totalWaterCount,
            isWarning: engineState.isWarning
        )
        let content = ActivityContent(state: state, staleDate: nil)
        for activity in Activity<SessionActivityAttributes>.activities {
            await activity.update(content)
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")

        return .result()
    }
}
