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
