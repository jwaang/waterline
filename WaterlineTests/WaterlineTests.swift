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
