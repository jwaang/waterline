import Foundation
import SwiftData

// MARK: - Enums

enum VolumeUnit: String, Codable, CaseIterable {
    case oz
    case ml
}

enum DrinkType: String, Codable, CaseIterable {
    case beer
    case wine
    case liquor
    case cocktail
}

enum LogEntryType: String, Codable {
    case alcohol
    case water
}

enum LogSource: String, Codable {
    case phone
    case watch
    case widget
    case liveActivity
}

// MARK: - Embedded Models

struct AlcoholMeta: Codable, Equatable {
    var drinkType: DrinkType
    var sizeOz: Double
    var abv: Double?
    var standardDrinkEstimate: Double
    var presetId: UUID?
}

struct WaterMeta: Codable, Equatable {
    var amountOz: Double
}

struct SessionSummary: Codable, Equatable {
    var totalDrinks: Int
    var totalWater: Int
    var totalStandardDrinks: Double
    var durationSeconds: TimeInterval
    var pacingAdherence: Double
    var finalWaterlineValue: Double
}

// MARK: - UserSettings (embedded in User)

struct UserSettings: Codable, Equatable {
    var waterEveryNDrinks: Int = 1
    var timeRemindersEnabled: Bool = false
    var timeReminderIntervalMinutes: Int = 20
    var warningThreshold: Int = 2
    var defaultWaterAmountOz: Int = 8
    var units: VolumeUnit = .oz
    var discreetNotifications: Bool = true
}

// MARK: - User

@Model
final class User {
    @Attribute(.unique) var id: UUID
    var appleUserId: String
    var createdAt: Date
    var settings: UserSettings

    @Relationship(deleteRule: .cascade, inverse: \Session.user)
    var sessions: [Session] = []

    @Relationship(deleteRule: .cascade, inverse: \DrinkPreset.user)
    var presets: [DrinkPreset] = []

    init(
        id: UUID = UUID(),
        appleUserId: String,
        createdAt: Date = Date(),
        settings: UserSettings = UserSettings()
    ) {
        self.id = id
        self.appleUserId = appleUserId
        self.createdAt = createdAt
        self.settings = settings
    }
}

// MARK: - Session

@Model
final class Session {
    @Attribute(.unique) var id: UUID
    var startTime: Date
    var endTime: Date?
    var isActive: Bool
    var computedSummary: SessionSummary?
    var needsSync: Bool = true

    var user: User?

    @Relationship(deleteRule: .cascade, inverse: \LogEntry.session)
    var logEntries: [LogEntry] = []

    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        isActive: Bool = true,
        computedSummary: SessionSummary? = nil,
        needsSync: Bool = true
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.isActive = isActive
        self.computedSummary = computedSummary
        self.needsSync = needsSync
    }
}

// MARK: - LogEntry

@Model
final class LogEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var type: LogEntryType
    var alcoholMeta: AlcoholMeta?
    var waterMeta: WaterMeta?
    var source: LogSource
    var needsSync: Bool = true

    var session: Session?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: LogEntryType,
        alcoholMeta: AlcoholMeta? = nil,
        waterMeta: WaterMeta? = nil,
        source: LogSource = .phone,
        needsSync: Bool = true
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.alcoholMeta = alcoholMeta
        self.waterMeta = waterMeta
        self.source = source
        self.needsSync = needsSync
    }
}

// MARK: - DrinkPreset

@Model
final class DrinkPreset {
    @Attribute(.unique) var id: UUID
    var name: String
    var drinkType: DrinkType
    var sizeOz: Double
    var abv: Double?
    var standardDrinkEstimate: Double
    var needsSync: Bool = true

    var user: User?

    init(
        id: UUID = UUID(),
        name: String,
        drinkType: DrinkType,
        sizeOz: Double,
        abv: Double? = nil,
        standardDrinkEstimate: Double,
        needsSync: Bool = true
    ) {
        self.id = id
        self.name = name
        self.drinkType = drinkType
        self.sizeOz = sizeOz
        self.abv = abv
        self.standardDrinkEstimate = standardDrinkEstimate
        self.needsSync = needsSync
    }
}
