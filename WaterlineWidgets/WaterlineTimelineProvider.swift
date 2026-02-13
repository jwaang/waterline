import WidgetKit
import SwiftData

struct WaterlineTimelineEntry: TimelineEntry {
    let date: Date
    let hasActiveSession: Bool
    let waterlineValue: Double
    let drinkCount: Int
    let waterCount: Int
    let isWarning: Bool

    static var noSession: WaterlineTimelineEntry {
        WaterlineTimelineEntry(
            date: .now,
            hasActiveSession: false,
            waterlineValue: 0,
            drinkCount: 0,
            waterCount: 0,
            isWarning: false
        )
    }

    static var placeholder: WaterlineTimelineEntry {
        WaterlineTimelineEntry(
            date: .now,
            hasActiveSession: true,
            waterlineValue: 1.5,
            drinkCount: 3,
            waterCount: 1,
            isWarning: false
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

        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        )
        guard let session = try? context.fetch(descriptor).first else {
            return .noSession
        }

        let logDescriptor = FetchDescriptor<LogEntry>()
        let allLogs = (try? context.fetch(logDescriptor)) ?? []
        let sessionLogs = allLogs.filter { $0.session?.id == session.id }

        var waterlineValue: Double = 0
        var drinkCount = 0
        var waterCount = 0
        for entry in sessionLogs.sorted(by: { $0.timestamp < $1.timestamp }) {
            if entry.type == .alcohol, let meta = entry.alcoholMeta {
                waterlineValue += meta.standardDrinkEstimate
                drinkCount += 1
            } else if entry.type == .water {
                waterlineValue -= 1
                waterCount += 1
            }
        }

        let userDescriptor = FetchDescriptor<User>()
        let warningThreshold = (try? context.fetch(userDescriptor).first)?.settings.warningThreshold ?? 2

        return WaterlineTimelineEntry(
            date: .now,
            hasActiveSession: true,
            waterlineValue: waterlineValue,
            drinkCount: drinkCount,
            waterCount: waterCount,
            isWarning: waterlineValue >= Double(warningThreshold)
        )
    }
}
