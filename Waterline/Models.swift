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

// MARK: - Shared Model Container

enum SharedModelContainer {
    static let appGroupID = "group.com.waterline.app.shared"
    static func create() throws -> ModelContainer {
        if let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let url = groupURL.appending(path: "Waterline.store")
            let config = ModelConfiguration(url: url)
            return try ModelContainer(
                for: User.self, Session.self, LogEntry.self, DrinkPreset.self,
                configurations: config
            )
        }
        // Fallback: App Group not available (entitlement not provisioned yet)
        return try ModelContainer(
            for: User.self, Session.self, LogEntry.self, DrinkPreset.self
        )
    }
}

// MARK: - Live Activity Bridge (cross-process IPC via Darwin notifications)

enum LiveActivityBridge {
    private static nonisolated(unsafe) let darwinName = "com.waterline.app.liveActivityUpdate" as CFString
    private static let stateKey = "liveActivityPendingState"

    private static nonisolated(unsafe) var handler: (@Sendable () -> Void)?

    /// Called from intents: write new state to App Group UserDefaults and notify main app.
    static func postUpdate(waterlineValue: Double, drinkCount: Int, waterCount: Int, isWarning: Bool) {
        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupID)
        defaults?.set([
            "wl": waterlineValue,
            "drinks": drinkCount,
            "water": waterCount,
            "warning": isWarning,
        ], forKey: stateKey)
        defaults?.synchronize()

        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(darwinName),
            nil, nil, true
        )
    }

    /// Called from main app: read pending state written by an intent.
    static func readPendingState() -> (waterlineValue: Double, drinkCount: Int, waterCount: Int, isWarning: Bool)? {
        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupID)
        guard let dict = defaults?.dictionary(forKey: stateKey),
              let wl = dict["wl"] as? Double,
              let drinks = dict["drinks"] as? Int,
              let water = dict["water"] as? Int,
              let warning = dict["warning"] as? Bool else { return nil }
        return (wl, drinks, water, warning)
    }

    /// Called once from main app init: register Darwin notification observer.
    static func startObserving(onUpdate: @escaping @Sendable () -> Void) {
        handler = onUpdate
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                LiveActivityBridge.handler?()
            },
            darwinName,
            nil,
            .deliverImmediately
        )
    }
}
