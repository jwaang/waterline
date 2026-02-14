import ActivityKit
import AppIntents
import SwiftData
import WidgetKit

struct LogDrinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Drink"
    static let description = IntentDescription("Log a standard alcoholic drink to your active session.")

    func perform() async throws -> some IntentResult {
        let container = try ModelContainer(for: User.self, Session.self, LogEntry.self, DrinkPreset.self)
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        )
        guard let session = try? context.fetch(descriptor).first else {
            return .result()
        }

        let entry = LogEntry(
            type: .alcohol,
            alcoholMeta: AlcoholMeta(
                drinkType: .beer,
                sizeOz: 12,
                standardDrinkEstimate: 1.0
            ),
            source: .widget
        )
        entry.session = session
        context.insert(entry)
        try context.save()

        // Recompute state for Live Activity update
        let logs = session.logEntries.sorted(by: { $0.timestamp < $1.timestamp })
        var wl: Double = 0
        var dc = 0
        var wc = 0
        for log in logs {
            if log.type == .alcohol, let meta = log.alcoholMeta {
                wl += meta.standardDrinkEstimate
                dc += 1
            } else if log.type == .water {
                wl -= 1
                wc += 1
            }
        }

        let userDescriptor = FetchDescriptor<User>()
        let threshold = (try? context.fetch(userDescriptor).first)?.settings.warningThreshold ?? 2

        let state = SessionActivityAttributes.ContentState(
            waterlineValue: wl,
            drinkCount: dc,
            waterCount: wc,
            isWarning: wl >= Double(threshold)
        )
        let content = ActivityContent(state: state, staleDate: nil)
        for activity in Activity<SessionActivityAttributes>.activities {
            await activity.update(content)
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")

        return .result()
    }
}
