import AppIntents

struct LogDrinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Drink"
    static let description = IntentDescription("Log an alcoholic drink to your active session.")

    func perform() async throws -> some IntentResult {
        // TODO: Implement drink logging via shared data store
        return .result()
    }
}
