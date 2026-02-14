import WidgetKit
import SwiftData

// MARK: - Log Entry Snapshot (lightweight struct for widget display)

struct LogEntrySnapshot: Identifiable {
    let id: UUID
    let timestamp: Date
    let isAlcohol: Bool
    let label: String // e.g. "Beer 12oz" or "Water 8oz"
}

// MARK: - Last Session Snapshot (for no-session state)

struct LastSessionSnapshot {
    let date: Date
    let duration: TimeInterval
    let drinkCount: Int
    let waterCount: Int
    let finalWaterline: Double
}

struct WaterlineTimelineEntry: TimelineEntry {
    let date: Date
    let hasActiveSession: Bool
    let waterlineValue: Double
    let drinkCount: Int
    let waterCount: Int
    let isWarning: Bool
    // Medium widget: next reminder countdown
    let nextReminderText: String?
    let sessionStartTime: Date?
    // Large widget: recent log entries
    let recentEntries: [LogEntrySnapshot]
    // No-session state: last session summary
    let lastSession: LastSessionSnapshot?

    static var noSession: WaterlineTimelineEntry {
        WaterlineTimelineEntry(
            date: .now,
            hasActiveSession: false,
            waterlineValue: 0,
            drinkCount: 0,
            waterCount: 0,
            isWarning: false,
            nextReminderText: nil,
            sessionStartTime: nil,
            recentEntries: [],
            lastSession: nil
        )
    }

    static var placeholder: WaterlineTimelineEntry {
        WaterlineTimelineEntry(
            date: .now,
            hasActiveSession: true,
            waterlineValue: 1.5,
            drinkCount: 3,
            waterCount: 1,
            isWarning: false,
            nextReminderText: "12:30",
            sessionStartTime: Date().addingTimeInterval(-3600),
            recentEntries: [
                LogEntrySnapshot(id: UUID(), timestamp: Date().addingTimeInterval(-600), isAlcohol: true, label: "Beer 12oz"),
                LogEntrySnapshot(id: UUID(), timestamp: Date().addingTimeInterval(-300), isAlcohol: false, label: "Water 8oz"),
                LogEntrySnapshot(id: UUID(), timestamp: Date().addingTimeInterval(-60), isAlcohol: true, label: "Wine 5oz"),
            ],
            lastSession: nil
        )
    }
}

struct WaterlineTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WaterlineTimelineEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WaterlineTimelineEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        completion(fetchCurrentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WaterlineTimelineEntry>) -> Void) {
        let entry = fetchCurrentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: entry.date)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchCurrentEntry() -> WaterlineTimelineEntry {
        guard let container = try? ModelContainer(for: User.self, Session.self, LogEntry.self, DrinkPreset.self) else {
            return .noSession
        }
        let context = ModelContext(container)

        // Fetch user settings
        let userDescriptor = FetchDescriptor<User>()
        let user = try? context.fetch(userDescriptor).first
        let settings = user?.settings ?? UserSettings()

        // Try to find active session
        let activeDescriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        )
        if let session = try? context.fetch(activeDescriptor).first {
            return buildActiveEntry(session: session, settings: settings, context: context)
        }

        // No active session — try to find last completed session for summary
        let pastDescriptor = FetchDescriptor<Session>(
            predicate: #Predicate { !$0.isActive },
            sortBy: [SortDescriptor(\Session.startTime, order: .reverse)]
        )
        let lastSession = try? context.fetch(pastDescriptor).first

        var lastSessionSnapshot: LastSessionSnapshot?
        if let last = lastSession {
            let duration = (last.endTime ?? last.startTime).timeIntervalSince(last.startTime)
            if let summary = last.computedSummary {
                lastSessionSnapshot = LastSessionSnapshot(
                    date: last.startTime,
                    duration: duration,
                    drinkCount: summary.totalDrinks,
                    waterCount: summary.totalWater,
                    finalWaterline: summary.finalWaterlineValue
                )
            } else {
                // Compute from log entries
                let logDescriptor = FetchDescriptor<LogEntry>()
                let allLogs = (try? context.fetch(logDescriptor)) ?? []
                let sessionLogs = allLogs.filter { $0.session?.id == last.id }
                let state = WaterlineEngine.computeState(from: sessionLogs)
                lastSessionSnapshot = LastSessionSnapshot(
                    date: last.startTime,
                    duration: duration,
                    drinkCount: state.totalAlcoholCount,
                    waterCount: state.totalWaterCount,
                    finalWaterline: state.waterlineValue
                )
            }
        }

        return WaterlineTimelineEntry(
            date: .now,
            hasActiveSession: false,
            waterlineValue: 0,
            drinkCount: 0,
            waterCount: 0,
            isWarning: false,
            nextReminderText: nil,
            sessionStartTime: nil,
            recentEntries: [],
            lastSession: lastSessionSnapshot
        )
    }

    private func buildActiveEntry(session: Session, settings: UserSettings, context: ModelContext) -> WaterlineTimelineEntry {
        let logDescriptor = FetchDescriptor<LogEntry>()
        let allLogs = (try? context.fetch(logDescriptor)) ?? []
        let sessionLogs = allLogs.filter { $0.session?.id == session.id }
        let sortedLogs = sessionLogs.sorted(by: { $0.timestamp < $1.timestamp })

        let engineState = WaterlineEngine.computeState(from: sortedLogs, warningThreshold: settings.warningThreshold)
        let waterlineValue = engineState.waterlineValue
        let drinkCount = engineState.totalAlcoholCount
        let waterCount = engineState.totalWaterCount

        // Next reminder countdown
        var nextReminderText: String?
        if settings.timeRemindersEnabled {
            let anchor = sortedLogs.last?.timestamp ?? session.startTime
            let intervalSeconds = TimeInterval(settings.timeReminderIntervalMinutes * 60)
            let nextReminder = anchor.addingTimeInterval(intervalSeconds)
            let remaining = nextReminder.timeIntervalSince(.now)
            if remaining > 0 {
                let minutes = Int(remaining) / 60
                let seconds = Int(remaining) % 60
                nextReminderText = String(format: "%d:%02d", minutes, seconds)
            } else {
                nextReminderText = "now"
            }
        }

        // Recent 3 entries (most recent first for display)
        let recentLogs = sortedLogs.suffix(3).reversed()
        let recentEntries = recentLogs.map { log -> LogEntrySnapshot in
            let label: String
            if log.type == .alcohol, let meta = log.alcoholMeta {
                label = "\(meta.drinkType.rawValue.capitalized) \(Int(meta.sizeOz))oz"
            } else if let water = log.waterMeta {
                label = "Water \(Int(water.amountOz))oz"
            } else {
                label = log.type == .alcohol ? "Drink" : "Water"
            }
            return LogEntrySnapshot(
                id: log.id,
                timestamp: log.timestamp,
                isAlcohol: log.type == .alcohol,
                label: label
            )
        }

        return WaterlineTimelineEntry(
            date: .now,
            hasActiveSession: true,
            waterlineValue: waterlineValue,
            drinkCount: drinkCount,
            waterCount: waterCount,
            isWarning: waterlineValue >= Double(settings.warningThreshold),
            nextReminderText: nextReminderText,
            sessionStartTime: session.startTime,
            recentEntries: Array(recentEntries),
            lastSession: nil
        )
    }
}
