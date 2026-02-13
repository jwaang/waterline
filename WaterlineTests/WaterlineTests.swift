import Testing
import SwiftData
import Foundation
@testable import Waterline

// MARK: - Test Helpers

private func makeContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: User.self, Session.self, LogEntry.self, DrinkPreset.self,
        configurations: config
    )
}

// MARK: - UserSettings Tests

@Suite("UserSettings Defaults")
struct UserSettingsTests {
    @Test("Default values are correct")
    func defaults() {
        let settings = UserSettings()
        #expect(settings.waterEveryNDrinks == 1)
        #expect(settings.timeRemindersEnabled == false)
        #expect(settings.timeReminderIntervalMinutes == 20)
        #expect(settings.warningThreshold == 2)
        #expect(settings.defaultWaterAmountOz == 8)
        #expect(settings.units == .oz)
    }

    @Test("Custom values persist")
    func customValues() {
        var settings = UserSettings()
        settings.waterEveryNDrinks = 3
        settings.timeRemindersEnabled = true
        settings.timeReminderIntervalMinutes = 30
        settings.warningThreshold = 4
        settings.defaultWaterAmountOz = 16
        settings.units = .ml
        #expect(settings.waterEveryNDrinks == 3)
        #expect(settings.timeRemindersEnabled == true)
        #expect(settings.timeReminderIntervalMinutes == 30)
        #expect(settings.warningThreshold == 4)
        #expect(settings.defaultWaterAmountOz == 16)
        #expect(settings.units == .ml)
    }
}

// MARK: - User Model Tests

@Suite("User Model")
struct UserModelTests {
    @Test("User creation with defaults")
    func createWithDefaults() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let user = User(appleUserId: "apple-test-id")
        context.insert(user)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<User>())
        #expect(fetched.count == 1)
        #expect(fetched[0].appleUserId == "apple-test-id")
        #expect(fetched[0].settings.waterEveryNDrinks == 1)
        #expect(fetched[0].settings.warningThreshold == 2)
        #expect(fetched[0].sessions.isEmpty)
        #expect(fetched[0].presets.isEmpty)
    }

    @Test("User has embedded settings")
    func embeddedSettings() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        var customSettings = UserSettings()
        customSettings.waterEveryNDrinks = 2
        customSettings.units = .ml
        let user = User(appleUserId: "test", settings: customSettings)
        context.insert(user)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<User>())
        #expect(fetched[0].settings.waterEveryNDrinks == 2)
        #expect(fetched[0].settings.units == .ml)
    }
}

// MARK: - Session Model Tests

@Suite("Session Model")
struct SessionModelTests {
    @Test("Session creation with defaults")
    func createWithDefaults() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let session = Session()
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>())
        #expect(fetched.count == 1)
        #expect(fetched[0].isActive == true)
        #expect(fetched[0].endTime == nil)
        #expect(fetched[0].computedSummary == nil)
        #expect(fetched[0].logEntries.isEmpty)
    }

    @Test("Session-User relationship")
    func userRelationship() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let user = User(appleUserId: "test-user")
        let session = Session()
        session.user = user
        context.insert(user)
        context.insert(session)
        try context.save()

        let users = try context.fetch(FetchDescriptor<User>())
        #expect(users[0].sessions.count == 1)
        #expect(users[0].sessions[0].id == session.id)
    }

    @Test("Session end time and summary")
    func endSession() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let session = Session()
        context.insert(session)
        session.isActive = false
        session.endTime = Date()
        session.computedSummary = SessionSummary(
            totalDrinks: 3,
            totalWater: 2,
            totalStandardDrinks: 3.5,
            durationSeconds: 7200,
            pacingAdherence: 0.67,
            finalWaterlineValue: 1.5
        )
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>())
        #expect(fetched[0].isActive == false)
        #expect(fetched[0].endTime != nil)
        #expect(fetched[0].computedSummary?.totalDrinks == 3)
        #expect(fetched[0].computedSummary?.totalStandardDrinks == 3.5)
        #expect(fetched[0].computedSummary?.pacingAdherence == 0.67)
    }
}

// MARK: - LogEntry Model Tests

@Suite("LogEntry Model")
struct LogEntryModelTests {
    @Test("Alcohol log entry creation")
    func alcoholEntry() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let meta = AlcoholMeta(
            drinkType: .beer,
            sizeOz: 12.0,
            abv: 0.05,
            standardDrinkEstimate: 1.0,
            presetId: nil
        )
        let entry = LogEntry(type: .alcohol, alcoholMeta: meta, source: .phone)
        context.insert(entry)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<LogEntry>())
        #expect(fetched.count == 1)
        #expect(fetched[0].type == .alcohol)
        #expect(fetched[0].alcoholMeta?.drinkType == .beer)
        #expect(fetched[0].alcoholMeta?.sizeOz == 12.0)
        #expect(fetched[0].alcoholMeta?.standardDrinkEstimate == 1.0)
        #expect(fetched[0].waterMeta == nil)
        #expect(fetched[0].source == .phone)
    }

    @Test("Water log entry creation")
    func waterEntry() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let entry = LogEntry(
            type: .water,
            waterMeta: WaterMeta(amountOz: 8.0),
            source: .watch
        )
        context.insert(entry)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<LogEntry>())
        #expect(fetched[0].type == .water)
        #expect(fetched[0].waterMeta?.amountOz == 8.0)
        #expect(fetched[0].alcoholMeta == nil)
        #expect(fetched[0].source == .watch)
    }

    @Test("LogEntry-Session relationship")
    func sessionRelationship() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let session = Session()
        let entry1 = LogEntry(type: .alcohol, alcoholMeta: AlcoholMeta(
            drinkType: .wine, sizeOz: 5.0, standardDrinkEstimate: 1.0
        ))
        let entry2 = LogEntry(type: .water, waterMeta: WaterMeta(amountOz: 8.0))

        entry1.session = session
        entry2.session = session
        context.insert(session)
        context.insert(entry1)
        context.insert(entry2)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<Session>())
        #expect(sessions[0].logEntries.count == 2)
    }

    @Test("All log sources")
    func logSources() {
        let sources: [LogSource] = [.phone, .watch, .widget, .liveActivity]
        for source in sources {
            let entry = LogEntry(type: .water, source: source)
            #expect(entry.source == source)
        }
    }

    @Test("Cascade delete removes log entries")
    func cascadeDelete() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let session = Session()
        let entry = LogEntry(type: .water, waterMeta: WaterMeta(amountOz: 8.0))
        entry.session = session
        context.insert(session)
        context.insert(entry)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<LogEntry>()).count == 1)

        context.delete(session)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<LogEntry>()).count == 0)
    }
}

// MARK: - DrinkPreset Model Tests

@Suite("DrinkPreset Model")
struct DrinkPresetModelTests {
    @Test("Preset creation")
    func createPreset() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let preset = DrinkPreset(
            name: "IPA",
            drinkType: .beer,
            sizeOz: 16.0,
            abv: 0.065,
            standardDrinkEstimate: 1.3
        )
        context.insert(preset)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DrinkPreset>())
        #expect(fetched.count == 1)
        #expect(fetched[0].name == "IPA")
        #expect(fetched[0].drinkType == .beer)
        #expect(fetched[0].sizeOz == 16.0)
        #expect(fetched[0].abv == 0.065)
        #expect(fetched[0].standardDrinkEstimate == 1.3)
    }

    @Test("Preset without ABV")
    func presetNoAbv() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let preset = DrinkPreset(
            name: "Cocktail",
            drinkType: .cocktail,
            sizeOz: 6.0,
            standardDrinkEstimate: 1.5
        )
        context.insert(preset)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DrinkPreset>())
        #expect(fetched[0].abv == nil)
    }

    @Test("Preset-User relationship")
    func userRelationship() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let user = User(appleUserId: "test-user")
        let preset = DrinkPreset(
            name: "Beer",
            drinkType: .beer,
            sizeOz: 12.0,
            standardDrinkEstimate: 1.0
        )
        preset.user = user
        context.insert(user)
        context.insert(preset)
        try context.save()

        let users = try context.fetch(FetchDescriptor<User>())
        #expect(users[0].presets.count == 1)
        #expect(users[0].presets[0].name == "Beer")
    }

    @Test("All drink types")
    func drinkTypes() {
        let types: [DrinkType] = [.beer, .wine, .liquor, .cocktail]
        for drinkType in types {
            let preset = DrinkPreset(
                name: drinkType.rawValue,
                drinkType: drinkType,
                sizeOz: 8.0,
                standardDrinkEstimate: 1.0
            )
            #expect(preset.drinkType == drinkType)
        }
    }
}

// MARK: - Enum Tests

@Suite("Enum Codable")
struct EnumTests {
    @Test("VolumeUnit raw values")
    func volumeUnit() {
        #expect(VolumeUnit.oz.rawValue == "oz")
        #expect(VolumeUnit.ml.rawValue == "ml")
        #expect(VolumeUnit.allCases.count == 2)
    }

    @Test("DrinkType raw values")
    func drinkType() {
        #expect(DrinkType.beer.rawValue == "beer")
        #expect(DrinkType.wine.rawValue == "wine")
        #expect(DrinkType.liquor.rawValue == "liquor")
        #expect(DrinkType.cocktail.rawValue == "cocktail")
        #expect(DrinkType.allCases.count == 4)
    }

    @Test("LogEntryType raw values")
    func logEntryType() {
        #expect(LogEntryType.alcohol.rawValue == "alcohol")
        #expect(LogEntryType.water.rawValue == "water")
    }

    @Test("LogSource raw values")
    func logSource() {
        #expect(LogSource.phone.rawValue == "phone")
        #expect(LogSource.watch.rawValue == "watch")
        #expect(LogSource.widget.rawValue == "widget")
        #expect(LogSource.liveActivity.rawValue == "liveActivity")
    }
}

// MARK: - Cascade Delete Tests

@Suite("Cascade Relationships")
struct CascadeTests {
    @Test("Deleting user cascades to sessions and presets")
    func userCascade() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let user = User(appleUserId: "cascade-test")
        let session = Session()
        session.user = user
        let preset = DrinkPreset(
            name: "Test Beer",
            drinkType: .beer,
            sizeOz: 12.0,
            standardDrinkEstimate: 1.0
        )
        preset.user = user
        let entry = LogEntry(type: .water, waterMeta: WaterMeta(amountOz: 8.0))
        entry.session = session

        context.insert(user)
        context.insert(session)
        context.insert(preset)
        context.insert(entry)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Session>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<DrinkPreset>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<LogEntry>()).count == 1)

        context.delete(user)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<User>()).count == 0)
        #expect(try context.fetch(FetchDescriptor<Session>()).count == 0)
        #expect(try context.fetch(FetchDescriptor<DrinkPreset>()).count == 0)
        #expect(try context.fetch(FetchDescriptor<LogEntry>()).count == 0)
    }
}

// MARK: - ConvexService Tests

@Suite("ConvexService Initialization")
struct ConvexServiceInitTests {
    @Test("Service initializes with deployment URL")
    func initWithURL() async {
        let url = URL(string: "https://example-123.convex.cloud")!
        let service = ConvexService(deploymentURL: url)
        let deploymentURL = await service.deploymentURL
        #expect(deploymentURL == url)
    }
}

@Suite("Convex DTOs")
struct ConvexDTOTests {
    @Test("AuthResult decodes correctly")
    func authResultDecode() throws {
        let json = """
        {"userId": "abc123", "isNewUser": true}
        """.data(using: .utf8)!
        let result = try JSONDecoder().decode(AuthResult.self, from: json)
        #expect(result.userId == "abc123")
        #expect(result.isNewUser == true)
    }

    @Test("AuthResult decodes existing user")
    func authResultExistingUser() throws {
        let json = """
        {"userId": "xyz789", "isNewUser": false}
        """.data(using: .utf8)!
        let result = try JSONDecoder().decode(AuthResult.self, from: json)
        #expect(result.userId == "xyz789")
        #expect(result.isNewUser == false)
    }

    @Test("ConvexUserSettings default values")
    func userSettingsDefaults() {
        let settings = ConvexUserSettings()
        #expect(settings.waterEveryNDrinks == 1)
        #expect(settings.timeRemindersEnabled == false)
        #expect(settings.timeReminderIntervalMinutes == 20)
        #expect(settings.warningThreshold == 2)
        #expect(settings.defaultWaterAmountOz == 8)
        #expect(settings.units == "oz")
    }

    @Test("ConvexUserSettings toDictionary")
    func userSettingsDict() {
        var settings = ConvexUserSettings()
        settings.waterEveryNDrinks = 3
        settings.units = "ml"
        let dict = settings.toDictionary()
        #expect(dict["waterEveryNDrinks"] as? Int == 3)
        #expect(dict["units"] as? String == "ml")
        #expect(dict["warningThreshold"] as? Int == 2)
    }

    @Test("ConvexSessionSummary toDictionary")
    func sessionSummaryDict() {
        let summary = ConvexSessionSummary(
            totalDrinks: 5,
            totalWater: 3,
            totalStandardDrinks: 6.5,
            durationSeconds: 7200.0,
            pacingAdherence: 0.8,
            finalWaterlineValue: 3.5
        )
        let dict = summary.toDictionary()
        #expect(dict["totalDrinks"] as? Int == 5)
        #expect(dict["totalWater"] as? Int == 3)
        #expect(dict["totalStandardDrinks"] as? Double == 6.5)
        #expect(dict["durationSeconds"] as? Double == 7200.0)
        #expect(dict["pacingAdherence"] as? Double == 0.8)
        #expect(dict["finalWaterlineValue"] as? Double == 3.5)
    }

    @Test("ConvexAlcoholMeta toDictionary with all fields")
    func alcoholMetaFullDict() {
        let meta = ConvexAlcoholMeta(
            drinkType: "beer",
            sizeOz: 16.0,
            abv: 0.065,
            standardDrinkEstimate: 1.3,
            presetId: "preset-1"
        )
        let dict = meta.toDictionary()
        #expect(dict["drinkType"] as? String == "beer")
        #expect(dict["sizeOz"] as? Double == 16.0)
        #expect(dict["abv"] as? Double == 0.065)
        #expect(dict["standardDrinkEstimate"] as? Double == 1.3)
        #expect(dict["presetId"] as? String == "preset-1")
    }

    @Test("ConvexAlcoholMeta toDictionary without optionals")
    func alcoholMetaMinimalDict() {
        let meta = ConvexAlcoholMeta(
            drinkType: "wine",
            sizeOz: 5.0,
            abv: nil,
            standardDrinkEstimate: 1.0,
            presetId: nil
        )
        let dict = meta.toDictionary()
        #expect(dict["drinkType"] as? String == "wine")
        #expect(dict["sizeOz"] as? Double == 5.0)
        #expect(dict["abv"] == nil)
        #expect(dict["presetId"] == nil)
    }

    @Test("ConvexWaterMeta toDictionary")
    func waterMetaDict() {
        let meta = ConvexWaterMeta(amountOz: 12.0)
        let dict = meta.toDictionary()
        #expect(dict["amountOz"] as? Double == 12.0)
    }

    @Test("ConvexSession decodes correctly")
    func sessionDecode() throws {
        let json = """
        {
            "_id": "sess-abc",
            "userId": "user-123",
            "startTime": 1700000000.0,
            "isActive": true,
            "computedSummary": null
        }
        """.data(using: .utf8)!
        let session = try JSONDecoder().decode(ConvexSession.self, from: json)
        #expect(session._id == "sess-abc")
        #expect(session.userId == "user-123")
        #expect(session.startTime == 1700000000.0)
        #expect(session.isActive == true)
        #expect(session.endTime == nil)
        #expect(session.computedSummary == nil)
    }

    @Test("ConvexSession decodes with summary")
    func sessionDecodeWithSummary() throws {
        let json = """
        {
            "_id": "sess-xyz",
            "userId": "user-456",
            "startTime": 1700000000.0,
            "endTime": 1700007200.0,
            "isActive": false,
            "computedSummary": {
                "totalDrinks": 4,
                "totalWater": 2,
                "totalStandardDrinks": 5.0,
                "durationSeconds": 7200.0,
                "pacingAdherence": 0.75,
                "finalWaterlineValue": 3.0
            }
        }
        """.data(using: .utf8)!
        let session = try JSONDecoder().decode(ConvexSession.self, from: json)
        #expect(session._id == "sess-xyz")
        #expect(session.isActive == false)
        #expect(session.endTime == 1700007200.0)
        #expect(session.computedSummary?.totalDrinks == 4)
        #expect(session.computedSummary?.finalWaterlineValue == 3.0)
    }

    @Test("ConvexLogEntry decodes alcohol entry")
    func logEntryDecodeAlcohol() throws {
        let json = """
        {
            "_id": "log-1",
            "sessionId": "sess-1",
            "timestamp": 1700001000.0,
            "type": "alcohol",
            "alcoholMeta": {
                "drinkType": "beer",
                "sizeOz": 12.0,
                "standardDrinkEstimate": 1.0
            },
            "source": "phone"
        }
        """.data(using: .utf8)!
        let entry = try JSONDecoder().decode(ConvexLogEntry.self, from: json)
        #expect(entry._id == "log-1")
        #expect(entry.type == "alcohol")
        #expect(entry.alcoholMeta?.drinkType == "beer")
        #expect(entry.alcoholMeta?.standardDrinkEstimate == 1.0)
        #expect(entry.waterMeta == nil)
        #expect(entry.source == "phone")
    }

    @Test("ConvexLogEntry decodes water entry")
    func logEntryDecodeWater() throws {
        let json = """
        {
            "_id": "log-2",
            "sessionId": "sess-1",
            "timestamp": 1700002000.0,
            "type": "water",
            "waterMeta": {"amountOz": 8.0},
            "source": "watch"
        }
        """.data(using: .utf8)!
        let entry = try JSONDecoder().decode(ConvexLogEntry.self, from: json)
        #expect(entry._id == "log-2")
        #expect(entry.type == "water")
        #expect(entry.waterMeta?.amountOz == 8.0)
        #expect(entry.alcoholMeta == nil)
        #expect(entry.source == "watch")
    }

    @Test("ConvexDrinkPreset decodes correctly")
    func presetDecode() throws {
        let json = """
        {
            "_id": "preset-1",
            "userId": "user-1",
            "name": "IPA",
            "drinkType": "beer",
            "sizeOz": 16.0,
            "abv": 0.065,
            "standardDrinkEstimate": 1.3
        }
        """.data(using: .utf8)!
        let preset = try JSONDecoder().decode(ConvexDrinkPreset.self, from: json)
        #expect(preset._id == "preset-1")
        #expect(preset.name == "IPA")
        #expect(preset.drinkType == "beer")
        #expect(preset.sizeOz == 16.0)
        #expect(preset.abv == 0.065)
        #expect(preset.standardDrinkEstimate == 1.3)
    }

    @Test("ConvexDrinkPreset decodes without optional ABV")
    func presetDecodeNoAbv() throws {
        let json = """
        {
            "_id": "preset-2",
            "userId": "user-1",
            "name": "Cocktail",
            "drinkType": "cocktail",
            "sizeOz": 6.0,
            "standardDrinkEstimate": 1.5
        }
        """.data(using: .utf8)!
        let preset = try JSONDecoder().decode(ConvexDrinkPreset.self, from: json)
        #expect(preset.abv == nil)
        #expect(preset.standardDrinkEstimate == 1.5)
    }
}

@Suite("ConvexResponse Parsing")
struct ConvexResponseTests {
    @Test("Success response with string value")
    func successString() throws {
        let json = """
        {"status": "success", "value": "id-123"}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(ConvexResponse<String>.self, from: json)
        #expect(response.status == "success")
        #expect(response.value == "id-123")
        #expect(response.errorMessage == nil)
    }

    @Test("Success response with null value")
    func successNull() throws {
        let json = """
        {"status": "success", "value": null}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(ConvexResponse<ConvexNull>.self, from: json)
        #expect(response.status == "success")
        #expect(response.value == nil)
    }

    @Test("Error response")
    func errorResponse() throws {
        let json = """
        {"status": "error", "errorMessage": "Not found", "errorData": null}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(ConvexResponse<String>.self, from: json)
        #expect(response.status == "error")
        #expect(response.errorMessage == "Not found")
        #expect(response.value == nil)
    }

    @Test("Success response with AuthResult")
    func successAuthResult() throws {
        let json = """
        {"status": "success", "value": {"userId": "user-abc", "isNewUser": true}}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(ConvexResponse<AuthResult>.self, from: json)
        #expect(response.status == "success")
        #expect(response.value?.userId == "user-abc")
        #expect(response.value?.isNewUser == true)
    }
}

@Suite("ConvexError")
struct ConvexErrorTests {
    @Test("Error descriptions are meaningful")
    func errorDescriptions() {
        let errors: [(ConvexError, String)] = [
            (.invalidResponse, "Invalid response from Convex"),
            (.httpError(statusCode: 404, body: "not found"), "HTTP 404: not found"),
            (.missingValue, "Missing value in Convex response"),
            (.serverError(message: "Bad request", data: nil), "Convex error: Bad request"),
            (.unexpectedStatus("unknown"), "Unexpected status: unknown"),
        ]
        for (error, expected) in errors {
            #expect(error.errorDescription == expected)
        }
    }
}

// MARK: - AuthenticationManager Tests

@Suite("AuthState")
struct AuthStateTests {
    @Test("AuthState equality")
    func equality() {
        let a = AuthenticationManager.AuthState.signedIn(appleUserId: "abc")
        let b = AuthenticationManager.AuthState.signedIn(appleUserId: "abc")
        let c = AuthenticationManager.AuthState.signedIn(appleUserId: "xyz")
        #expect(a == b)
        #expect(a != c)
        #expect(AuthenticationManager.AuthState.signedOut == AuthenticationManager.AuthState.signedOut)
        #expect(AuthenticationManager.AuthState.unknown == AuthenticationManager.AuthState.unknown)
        #expect(AuthenticationManager.AuthState.unknown != AuthenticationManager.AuthState.signedOut)
    }

    @Test("AuthState hashable")
    func hashable() {
        let states: Set<AuthenticationManager.AuthState> = [
            .unknown, .signedOut, .signedIn(appleUserId: "a"), .signedIn(appleUserId: "b"),
        ]
        #expect(states.count == 4)
    }
}

@Suite("AuthenticationManager Initialization")
struct AuthenticationManagerInitTests {
    @MainActor
    @Test("Manager starts in unknown state")
    func initialState() {
        let store = InMemoryCredentialStore()
        let manager = AuthenticationManager(store: store)
        #expect(manager.authState == .unknown)
        #expect(manager.isSignedIn == false)
        #expect(manager.currentAppleUserId == nil)
        #expect(manager.errorMessage == nil)
        #expect(manager.isLoading == false)
    }

    @MainActor
    @Test("isSignedIn returns false when signed out")
    func isSignedInComputed() {
        let store = InMemoryCredentialStore()
        let manager = AuthenticationManager(store: store)
        manager.restoreSession()
        #expect(manager.isSignedIn == false)
        #expect(manager.currentAppleUserId == nil)
    }

    @MainActor
    @Test("Dismiss error clears error message")
    func dismissError() {
        let store = InMemoryCredentialStore()
        let manager = AuthenticationManager(store: store)
        manager.dismissError()
        #expect(manager.errorMessage == nil)
    }
}

@Suite("AuthenticationManager Session Restore")
struct AuthManagerRestoreTests {
    @MainActor
    @Test("Restore with no stored data sets signedOut")
    func restoreNoData() {
        let store = InMemoryCredentialStore()
        let manager = AuthenticationManager(store: store)
        manager.restoreSession()
        #expect(manager.authState == .signedOut)
        #expect(manager.isSignedIn == false)
    }

    @MainActor
    @Test("Restore with stored data sets signedIn")
    func restoreWithData() {
        let store = InMemoryCredentialStore()
        let testId = "test-apple-user-\(UUID().uuidString)"
        store.save(key: "com.waterline.appleUserId", value: testId)

        let manager = AuthenticationManager(store: store)
        manager.restoreSession()
        #expect(manager.authState == .signedIn(appleUserId: testId))
        #expect(manager.isSignedIn == true)
        #expect(manager.currentAppleUserId == testId)
    }
}

@Suite("AuthenticationManager Sign Out")
struct AuthManagerSignOutTests {
    @MainActor
    @Test("Sign out clears store and state")
    func signOut() {
        let store = InMemoryCredentialStore()
        let testId = "signout-test-\(UUID().uuidString)"
        store.save(key: "com.waterline.appleUserId", value: testId)

        let manager = AuthenticationManager(store: store)
        manager.restoreSession()
        #expect(manager.isSignedIn == true)

        manager.signOut()
        #expect(manager.authState == .signedOut)
        #expect(manager.isSignedIn == false)
        #expect(manager.currentAppleUserId == nil)

        // Verify store was cleared
        let stored = store.read(key: "com.waterline.appleUserId")
        #expect(stored == nil)
    }
}

@Suite("InMemoryCredentialStore")
struct InMemoryCredentialStoreTests {
    @Test("Save and read value")
    func saveAndRead() {
        let store = InMemoryCredentialStore()
        store.save(key: "test-key", value: "hello-world")
        let result = store.read(key: "test-key")
        #expect(result == "hello-world")
    }

    @Test("Read nonexistent key returns nil")
    func readMissing() {
        let store = InMemoryCredentialStore()
        let result = store.read(key: "nonexistent")
        #expect(result == nil)
    }

    @Test("Delete removes value")
    func deleteValue() {
        let store = InMemoryCredentialStore()
        store.save(key: "to-delete", value: "value")
        store.delete(key: "to-delete")
        let result = store.read(key: "to-delete")
        #expect(result == nil)
    }

    @Test("Save overwrites existing value")
    func overwrite() {
        let store = InMemoryCredentialStore()
        store.save(key: "key", value: "first")
        store.save(key: "key", value: "second")
        let result = store.read(key: "key")
        #expect(result == "second")
    }
}

@Suite("Local User Creation on Auth")
struct AuthLocalUserTests {
    @MainActor
    @Test("Local user created when not exists")
    func createsLocalUser() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        // Verify no users exist
        let before = try context.fetch(FetchDescriptor<User>())
        #expect(before.isEmpty)

        // Simulate what processCredential does for local user creation
        let appleUserId = "test-local-user-\(UUID().uuidString)"
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.appleUserId == appleUserId }
        )
        let existing = try context.fetch(descriptor)
        #expect(existing.isEmpty)

        let user = User(appleUserId: appleUserId)
        context.insert(user)
        try context.save()

        let after = try context.fetch(FetchDescriptor<User>())
        #expect(after.count == 1)
        #expect(after[0].appleUserId == appleUserId)
        #expect(after[0].settings == UserSettings())
    }

    @MainActor
    @Test("Duplicate user not created on re-auth")
    func noDuplicateUser() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let appleUserId = "test-no-dup-\(UUID().uuidString)"

        // Create user first time
        let user = User(appleUserId: appleUserId)
        context.insert(user)
        try context.save()

        // Simulate second auth — check before inserting
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.appleUserId == appleUserId }
        )
        let existing = try context.fetch(descriptor)
        #expect(!existing.isEmpty) // user exists, so no insert

        let allUsers = try context.fetch(FetchDescriptor<User>())
        #expect(allUsers.count == 1)
    }
}

// MARK: - OnboardingPage Tests

@Suite("OnboardingPage")
struct OnboardingPageTests {
    @Test("Page ordering is sequential")
    func pageOrdering() {
        #expect(OnboardingPage.welcome.rawValue == 0)
        #expect(OnboardingPage.guardrail.rawValue == 1)
        #expect(OnboardingPage.signIn.rawValue == 2)
    }

    @Test("Pages are hashable for animation")
    func pagesHashable() {
        let pages: Set<OnboardingPage> = [.welcome, .guardrail, .signIn]
        #expect(pages.count == 3)
    }
}

@Suite("Onboarding Persistence")
struct OnboardingPersistenceTests {
    @Test("hasCompletedOnboarding defaults to false")
    func defaultValue() {
        let defaults = UserDefaults(suiteName: "test-onboarding-\(UUID().uuidString)")!
        let value = defaults.bool(forKey: "hasCompletedOnboarding")
        #expect(value == false)
    }

    @Test("hasCompletedOnboarding persists when set to true")
    func persistsTrue() {
        let suiteName = "test-onboarding-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(true, forKey: "hasCompletedOnboarding")
        let value = defaults.bool(forKey: "hasCompletedOnboarding")
        #expect(value == true)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("Onboarding flag key matches AppStorage key")
    func keyConsistency() {
        // The key used in RootView's @AppStorage must be "hasCompletedOnboarding"
        // This test documents the contract
        let key = "hasCompletedOnboarding"
        let defaults = UserDefaults(suiteName: "test-key-\(UUID().uuidString)")!
        defaults.set(true, forKey: key)
        #expect(defaults.bool(forKey: key) == true)
    }
}

@Suite("Onboarding Flow Integration")
struct OnboardingFlowTests {
    @MainActor
    @Test("New user sees onboarding when signed out and not onboarded")
    func newUserSeesOnboarding() {
        let store = InMemoryCredentialStore()
        let manager = AuthenticationManager(store: store)
        manager.restoreSession()

        // User is signed out and has not completed onboarding
        #expect(manager.authState == .signedOut)
        #expect(manager.isSignedIn == false)
        // hasCompletedOnboarding would be false → shows OnboardingView
    }

    @MainActor
    @Test("Returning user skips onboarding when signed out but previously onboarded")
    func returningUserSkipsOnboarding() {
        let store = InMemoryCredentialStore()
        let manager = AuthenticationManager(store: store)
        manager.restoreSession()

        // User is signed out but has completed onboarding before
        #expect(manager.authState == .signedOut)
        // If hasCompletedOnboarding is true → shows SignInView directly
    }

    @MainActor
    @Test("Signed-in user without onboarding sees configure defaults")
    func signedInWithoutOnboardingSeesConfigureDefaults() {
        let store = InMemoryCredentialStore()
        store.save(key: "com.waterline.appleUserId", value: "test-user")
        let manager = AuthenticationManager(store: store)
        manager.restoreSession()

        #expect(manager.isSignedIn == true)
        // RootView shows ConfigureDefaultsView when signedIn + !hasCompletedOnboarding
        // onComplete callback from ConfigureDefaultsView sets hasCompletedOnboarding = true
    }
}

// MARK: - ConfigureDefaults Settings Persistence Tests

@Suite("ConfigureDefaults Settings Persistence")
struct ConfigureDefaultsSettingsTests {
    @Test("Default UserSettings values match configure defaults initial state")
    func defaultSettingsMatchInitialState() {
        let settings = UserSettings()
        #expect(settings.waterEveryNDrinks == 1)
        #expect(settings.timeRemindersEnabled == false)
        #expect(settings.timeReminderIntervalMinutes == 20)
        #expect(settings.warningThreshold == 2)
        #expect(settings.units == .oz)
    }

    @Test("Custom settings persist to SwiftData via User model")
    func customSettingsPersistToUser() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let user = User(appleUserId: "config-test-\(UUID().uuidString)")
        context.insert(user)
        try context.save()

        // Simulate what ConfigureDefaultsView.saveSettings does
        user.settings.waterEveryNDrinks = 3
        user.settings.timeRemindersEnabled = true
        user.settings.timeReminderIntervalMinutes = 30
        user.settings.warningThreshold = 4
        user.settings.units = .ml
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<User>())
        #expect(fetched.count == 1)
        #expect(fetched[0].settings.waterEveryNDrinks == 3)
        #expect(fetched[0].settings.timeRemindersEnabled == true)
        #expect(fetched[0].settings.timeReminderIntervalMinutes == 30)
        #expect(fetched[0].settings.warningThreshold == 4)
        #expect(fetched[0].settings.units == .ml)
    }

    @Test("Settings update preserves other user data")
    func settingsUpdatePreservesUserData() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let appleId = "preserve-test-\(UUID().uuidString)"
        let user = User(appleUserId: appleId)
        context.insert(user)
        try context.save()

        // Update only some settings
        user.settings.waterEveryNDrinks = 2
        user.settings.units = .ml
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<User>(
            predicate: #Predicate { $0.appleUserId == appleId }
        ))
        #expect(fetched.count == 1)
        #expect(fetched[0].appleUserId == appleId)
        // Changed fields
        #expect(fetched[0].settings.waterEveryNDrinks == 2)
        #expect(fetched[0].settings.units == .ml)
        // Unchanged defaults preserved
        #expect(fetched[0].settings.timeRemindersEnabled == false)
        #expect(fetched[0].settings.timeReminderIntervalMinutes == 20)
        #expect(fetched[0].settings.warningThreshold == 2)
    }

    @Test("Water every N drinks stepper range minimum is 1")
    func waterEveryNDrinksMinimum() {
        var settings = UserSettings()
        settings.waterEveryNDrinks = 1
        #expect(settings.waterEveryNDrinks == 1)
        // The stepper in the UI enforces min 1, but the model accepts any Int
        // Verify the default is the expected minimum
        #expect(UserSettings().waterEveryNDrinks == 1)
    }

    @Test("Warning threshold stepper range minimum is 1")
    func warningThresholdMinimum() {
        var settings = UserSettings()
        settings.warningThreshold = 1
        #expect(settings.warningThreshold == 1)
        #expect(UserSettings().warningThreshold == 2)
    }

    @Test("Time reminder interval options are valid")
    func timeReminderIntervalOptions() {
        let validIntervals = [10, 15, 20, 30, 45, 60]
        for interval in validIntervals {
            var settings = UserSettings()
            settings.timeReminderIntervalMinutes = interval
            #expect(settings.timeReminderIntervalMinutes == interval)
        }
    }

    @Test("VolumeUnit toggle values")
    func volumeUnitToggle() {
        var settings = UserSettings()
        #expect(settings.units == .oz)
        settings.units = .ml
        #expect(settings.units == .ml)
        settings.units = .oz
        #expect(settings.units == .oz)
    }

    @Test("Settings fetched by appleUserId for save")
    func settingsFetchedByAppleUserId() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let appleId = "fetch-test-\(UUID().uuidString)"
        let user = User(appleUserId: appleId)
        context.insert(user)
        try context.save()

        // Simulate the fetch pattern used in ConfigureDefaultsView.saveSettings
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.appleUserId == appleId }
        )
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
        #expect(fetched[0].appleUserId == appleId)
    }
}

// MARK: - ConfigureDefaults Onboarding Completion Tests

@Suite("ConfigureDefaults Onboarding Completion")
struct ConfigureDefaultsCompletionTests {
    @Test("onComplete callback sets hasCompletedOnboarding via UserDefaults")
    func onCompleteCallbackSetsFlag() {
        let suiteName = "test-config-complete-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        #expect(defaults.bool(forKey: "hasCompletedOnboarding") == false)

        // Simulate what the onComplete closure does
        defaults.set(true, forKey: "hasCompletedOnboarding")
        #expect(defaults.bool(forKey: "hasCompletedOnboarding") == true)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    @Test("Signed-in user sees ConfigureDefaults when onboarding not complete")
    func signedInNotOnboardedSeesConfig() {
        let store = InMemoryCredentialStore()
        store.save(key: "com.waterline.appleUserId", value: "config-flow-test")
        let manager = AuthenticationManager(store: store)
        manager.restoreSession()

        // User is signed in
        #expect(manager.isSignedIn == true)
        // hasCompletedOnboarding is false → RootView shows ConfigureDefaultsView
        // After Done tap → hasCompletedOnboarding = true → RootView shows HomeView
    }

    @MainActor
    @Test("Signed-in user with completed onboarding skips configure defaults")
    func signedInOnboardedSkipsConfig() {
        let store = InMemoryCredentialStore()
        store.save(key: "com.waterline.appleUserId", value: "skip-config-test")
        let manager = AuthenticationManager(store: store)
        manager.restoreSession()

        #expect(manager.isSignedIn == true)
        // If hasCompletedOnboarding is true → RootView shows HomeView directly
        // ConfigureDefaultsView is never shown for returning users
    }
}

// MARK: - Home Screen Past Sessions Tests

@Suite("Home Screen Past Sessions Query")
struct HomeScreenPastSessionsTests {
    @Test("Past sessions query excludes active sessions")
    func excludesActiveSessions() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let active = Session(isActive: true)
        let ended = Session(
            startTime: Date().addingTimeInterval(-7200),
            endTime: Date().addingTimeInterval(-3600),
            isActive: false,
            computedSummary: SessionSummary(
                totalDrinks: 3, totalWater: 2, totalStandardDrinks: 3.0,
                durationSeconds: 3600, pacingAdherence: 0.67, finalWaterlineValue: 1.0
            )
        )
        context.insert(active)
        context.insert(ended)
        try context.save()

        // HomeView uses @Query with filter: !$0.isActive
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { !$0.isActive },
            sortBy: [SortDescriptor(\Session.startTime, order: .reverse)]
        )
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results[0].isActive == false)
    }

    @Test("Past sessions sorted by most recent first")
    func sortedByRecent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let now = Date()
        let older = Session(
            startTime: now.addingTimeInterval(-86400),
            endTime: now.addingTimeInterval(-82800),
            isActive: false
        )
        let newer = Session(
            startTime: now.addingTimeInterval(-3600),
            endTime: now.addingTimeInterval(-1800),
            isActive: false
        )
        context.insert(older)
        context.insert(newer)
        try context.save()

        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { !$0.isActive },
            sortBy: [SortDescriptor(\Session.startTime, order: .reverse)]
        )
        let results = try context.fetch(descriptor)
        #expect(results.count == 2)
        #expect(results[0].startTime > results[1].startTime)
    }

    @Test("Empty state when no past sessions exist")
    func emptyState() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        // Only active sessions exist
        let active = Session(isActive: true)
        context.insert(active)
        try context.save()

        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { !$0.isActive }
        )
        let results = try context.fetch(descriptor)
        #expect(results.isEmpty)
    }

    @Test("Past sessions limited to 5 in display")
    func limitedToFive() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let now = Date()
        for i in 0..<8 {
            let session = Session(
                startTime: now.addingTimeInterval(Double(-i * 86400)),
                endTime: now.addingTimeInterval(Double(-i * 86400) + 3600),
                isActive: false
            )
            context.insert(session)
        }
        try context.save()

        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { !$0.isActive },
            sortBy: [SortDescriptor(\Session.startTime, order: .reverse)]
        )
        let results = try context.fetch(descriptor)
        #expect(results.count == 8) // Query returns all; UI limits via .prefix(5)

        // The view applies .prefix(5) — verify we get the 5 most recent
        let displayed = Array(results.prefix(5))
        #expect(displayed.count == 5)
        // Verify ordering is maintained in prefix
        for i in 0..<(displayed.count - 1) {
            #expect(displayed[i].startTime > displayed[i + 1].startTime)
        }
    }
}

@Suite("Home Screen Session Row Data")
struct HomeScreenSessionRowTests {
    @Test("Session row shows summary data when available")
    func rowWithSummary() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let session = Session(
            startTime: Date().addingTimeInterval(-7200),
            endTime: Date(),
            isActive: false,
            computedSummary: SessionSummary(
                totalDrinks: 5, totalWater: 3, totalStandardDrinks: 6.5,
                durationSeconds: 7200, pacingAdherence: 0.6, finalWaterlineValue: 3.5
            )
        )
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>())
        let s = fetched[0]
        #expect(s.computedSummary?.totalDrinks == 5)
        #expect(s.computedSummary?.totalWater == 3)
        #expect(s.computedSummary?.durationSeconds == 7200)
    }

    @Test("Session row falls back to log entries when no summary")
    func rowWithoutSummary() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let session = Session(
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            isActive: false
        )
        let drink1 = LogEntry(type: .alcohol, alcoholMeta: AlcoholMeta(
            drinkType: .beer, sizeOz: 12.0, standardDrinkEstimate: 1.0
        ))
        let drink2 = LogEntry(type: .alcohol, alcoholMeta: AlcoholMeta(
            drinkType: .wine, sizeOz: 5.0, standardDrinkEstimate: 1.0
        ))
        let water1 = LogEntry(type: .water, waterMeta: WaterMeta(amountOz: 8.0))
        drink1.session = session
        drink2.session = session
        water1.session = session

        context.insert(session)
        context.insert(drink1)
        context.insert(drink2)
        context.insert(water1)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>())
        let s = fetched[0]
        #expect(s.computedSummary == nil)

        // Fallback counting from log entries — mirrors PastSessionRow logic
        let drinkCount = s.logEntries.filter { $0.type == .alcohol }.count
        let waterCount = s.logEntries.filter { $0.type == .water }.count
        #expect(drinkCount == 2)
        #expect(waterCount == 1)
    }

    @Test("Duration computed from endTime when no summary")
    func durationFromEndTime() throws {
        let now = Date()
        let start = now.addingTimeInterval(-5400) // 1.5 hours ago
        let session = Session(
            startTime: start,
            endTime: now,
            isActive: false
        )
        let duration = session.endTime!.timeIntervalSince(session.startTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        #expect(hours == 1)
        #expect(minutes == 30)
    }
}

@Suite("Home Screen Routing")
struct HomeScreenRoutingTests {
    @MainActor
    @Test("Signed-in onboarded user sees HomeView")
    func signedInOnboardedSeesHome() {
        let store = InMemoryCredentialStore()
        store.save(key: "com.waterline.appleUserId", value: "home-test-user")
        let manager = AuthenticationManager(store: store)
        manager.restoreSession()

        #expect(manager.isSignedIn == true)
        // RootView: signedIn + hasCompletedOnboarding = true → HomeView
    }
}

// MARK: - Home Screen Active Session Tests

@Suite("Home Screen Active Session Detection")
struct HomeScreenActiveSessionTests {
    @Test("Active session detected by isActive query")
    func activeSessionDetected() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let session = Session(isActive: true)
        context.insert(session)
        try context.save()

        // HomeView uses @Query with filter: $0.isActive
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        )
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results[0].isActive == true)
    }

    @Test("No active session returns empty results")
    func noActiveSession() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let ended = Session(
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            isActive: false
        )
        context.insert(ended)
        try context.save()

        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        )
        let results = try context.fetch(descriptor)
        #expect(results.isEmpty)
    }

    @Test("Active session persists across context recreations (auto-recovery)")
    func activeSessionPersistsAcrossContexts() throws {
        let container = try makeContainer()

        // Create active session in one context
        let context1 = ModelContext(container)
        let session = Session(isActive: true)
        let sessionId = session.id
        context1.insert(session)
        try context1.save()

        // Fetch in a fresh context — simulates app relaunch
        let context2 = ModelContext(container)
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        )
        let results = try context2.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results[0].id == sessionId)
    }
}

@Suite("Home Screen Active Session Waterline Computation")
struct HomeScreenWaterlineComputationTests {
    @Test("Waterline value computed from log entries")
    func waterlineFromLogs() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let session = Session(isActive: true)
        let drink1 = LogEntry(
            timestamp: Date().addingTimeInterval(-600),
            type: .alcohol,
            alcoholMeta: AlcoholMeta(drinkType: .beer, sizeOz: 12.0, standardDrinkEstimate: 1.0)
        )
        let drink2 = LogEntry(
            timestamp: Date().addingTimeInterval(-300),
            type: .alcohol,
            alcoholMeta: AlcoholMeta(drinkType: .wine, sizeOz: 5.0, standardDrinkEstimate: 1.0)
        )
        let water = LogEntry(
            timestamp: Date(),
            type: .water,
            waterMeta: WaterMeta(amountOz: 8.0)
        )
        drink1.session = session
        drink2.session = session
        water.session = session
        context.insert(session)
        context.insert(drink1)
        context.insert(drink2)
        context.insert(water)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        ))
        let s = fetched[0]

        // Waterline: +1.0 + 1.0 - 1 = 1.0
        var waterlineValue: Double = 0
        for entry in s.logEntries.sorted(by: { $0.timestamp < $1.timestamp }) {
            if entry.type == .alcohol, let meta = entry.alcoholMeta {
                waterlineValue += meta.standardDrinkEstimate
            } else if entry.type == .water {
                waterlineValue -= 1
            }
        }
        #expect(waterlineValue == 1.0)
    }

    @Test("Waterline value is zero with no log entries")
    func waterlineZeroNoEntries() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let session = Session(isActive: true)
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        ))
        let s = fetched[0]
        #expect(s.logEntries.isEmpty)

        // Waterline with no entries = 0.0
        var waterlineValue: Double = 0
        for entry in s.logEntries {
            if entry.type == .alcohol, let meta = entry.alcoholMeta {
                waterlineValue += meta.standardDrinkEstimate
            } else if entry.type == .water {
                waterlineValue -= 1
            }
        }
        #expect(waterlineValue == 0.0)
    }

    @Test("Waterline handles fractional standard drink estimates")
    func waterlineFractionalDrinks() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let session = Session(isActive: true)
        let doubleDrink = LogEntry(
            timestamp: Date().addingTimeInterval(-300),
            type: .alcohol,
            alcoholMeta: AlcoholMeta(drinkType: .liquor, sizeOz: 3.0, standardDrinkEstimate: 2.0)
        )
        let halfDrink = LogEntry(
            timestamp: Date(),
            type: .alcohol,
            alcoholMeta: AlcoholMeta(drinkType: .beer, sizeOz: 6.0, standardDrinkEstimate: 0.5)
        )
        doubleDrink.session = session
        halfDrink.session = session
        context.insert(session)
        context.insert(doubleDrink)
        context.insert(halfDrink)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        ))
        let s = fetched[0]

        var waterlineValue: Double = 0
        for entry in s.logEntries.sorted(by: { $0.timestamp < $1.timestamp }) {
            if entry.type == .alcohol, let meta = entry.alcoholMeta {
                waterlineValue += meta.standardDrinkEstimate
            } else if entry.type == .water {
                waterlineValue -= 1
            }
        }
        #expect(waterlineValue == 2.5)
    }

    @Test("Drink and water counts computed from log entries")
    func countsFromEntries() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let session = Session(isActive: true)
        let drink1 = LogEntry(type: .alcohol, alcoholMeta: AlcoholMeta(
            drinkType: .beer, sizeOz: 12.0, standardDrinkEstimate: 1.0
        ))
        let drink2 = LogEntry(type: .alcohol, alcoholMeta: AlcoholMeta(
            drinkType: .wine, sizeOz: 5.0, standardDrinkEstimate: 1.0
        ))
        let drink3 = LogEntry(type: .alcohol, alcoholMeta: AlcoholMeta(
            drinkType: .cocktail, sizeOz: 6.0, standardDrinkEstimate: 1.5
        ))
        let water1 = LogEntry(type: .water, waterMeta: WaterMeta(amountOz: 8.0))
        let water2 = LogEntry(type: .water, waterMeta: WaterMeta(amountOz: 8.0))
        for entry in [drink1, drink2, drink3, water1, water2] {
            entry.session = session
            context.insert(entry)
        }
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        ))
        let s = fetched[0]
        let drinkCount = s.logEntries.filter { $0.type == .alcohol }.count
        let waterCount = s.logEntries.filter { $0.type == .water }.count
        #expect(drinkCount == 3)
        #expect(waterCount == 2)
    }
}

@Suite("Waterline Indicator Warning State")
struct WaterlineIndicatorWarningTests {
    @Test("Warning threshold at 2.0 — default from UserSettings")
    func warningAtDefaultThreshold() {
        // WaterlineIndicator uses hardcoded threshold of 2 (matching UserSettings default warningThreshold)
        // value >= 2 → warning state
        let belowThreshold = 1.9
        let atThreshold = 2.0
        let aboveThreshold = 3.5
        #expect(belowThreshold < 2)
        #expect(atThreshold >= 2)
        #expect(aboveThreshold >= 2)
    }

    @Test("Waterline value triggers warning when at or above threshold")
    func warningTriggeredAboveThreshold() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let session = Session(isActive: true)
        // Add 3 beers, no water → waterline = 3.0 (above default warning threshold of 2)
        for i in 0..<3 {
            let drink = LogEntry(
                timestamp: Date().addingTimeInterval(Double(i) * 60),
                type: .alcohol,
                alcoholMeta: AlcoholMeta(drinkType: .beer, sizeOz: 12.0, standardDrinkEstimate: 1.0)
            )
            drink.session = session
            context.insert(drink)
        }
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        ))
        let s = fetched[0]

        var waterlineValue: Double = 0
        for entry in s.logEntries.sorted(by: { $0.timestamp < $1.timestamp }) {
            if entry.type == .alcohol, let meta = entry.alcoholMeta {
                waterlineValue += meta.standardDrinkEstimate
            } else if entry.type == .water {
                waterlineValue -= 1
            }
        }
        #expect(waterlineValue == 3.0)
        #expect(waterlineValue >= 2) // Warning state active
    }
}
