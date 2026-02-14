import ActivityKit
import AppIntents
import SwiftData
import WidgetKit

struct StartSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Session"
    static let description = IntentDescription("Start a new Waterline drinking session.")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let container = try ModelContainer(for: User.self, Session.self, LogEntry.self, DrinkPreset.self)
        let context = ModelContext(container)

        // Only one active session allowed
        let activeDescriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        )
        if let _ = try? context.fetch(activeDescriptor).first {
            return .result()
        }

        let session = Session()
        context.insert(session)

        // Associate with user if one exists
        let userDescriptor = FetchDescriptor<User>()
        if let user = try? context.fetch(userDescriptor).first {
            session.user = user
        }

        try context.save()

        // Start Live Activity
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")
            return .result()
        }

        let attributes = SessionActivityAttributes(
            sessionId: session.id.uuidString,
            startTime: session.startTime
        )
        let initialState = SessionActivityAttributes.ContentState(
            waterlineValue: 0,
            drinkCount: 0,
            waterCount: 0,
            isWarning: false
        )
        let content = ActivityContent(state: initialState, staleDate: nil)
        _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)

        WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")

        return .result()
    }
}
