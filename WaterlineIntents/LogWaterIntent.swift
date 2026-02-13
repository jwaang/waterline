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
        let defaultAmount = (try? context.fetch(userDescriptor).first)?.settings.defaultWaterAmountOz ?? 8

        let entry = LogEntry(
            type: .water,
            waterMeta: WaterMeta(amountOz: Double(defaultAmount)),
            source: .widget
        )
        entry.session = session
        context.insert(entry)
        try context.save()

        WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")

        return .result()
    }
}
