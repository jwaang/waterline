import AppIntents

struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Water"
    static let description = IntentDescription("Log water to your active session.")

    func perform() async throws -> some IntentResult {
        // TODO: Implement water logging via shared data store
        return .result()
    }
}
