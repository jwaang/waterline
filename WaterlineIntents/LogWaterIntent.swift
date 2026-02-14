import ActivityKit
import AppIntents
import SwiftData
import WidgetKit

struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Water"
    static let description = IntentDescription("Log water to your active session.")

    func perform() async throws -> some IntentResult {
        let container = try ModelContainer(for: User.self, Session.self, LogEntry.self, DrinkPreset.self)
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        )
        guard let session = try? context.fetch(descriptor).first else {
            return .result()
        }

        // Read default water amount from user settings
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

        // Recompute state for Live Activity update
        let threshold = user?.settings.warningThreshold ?? 2
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
