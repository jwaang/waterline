import WidgetKit

struct WaterlineTimelineEntry: TimelineEntry {
    let date: Date
}

struct WaterlineTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WaterlineTimelineEntry {
        WaterlineTimelineEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (WaterlineTimelineEntry) -> Void) {
        completion(WaterlineTimelineEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WaterlineTimelineEntry>) -> Void) {
        let entry = WaterlineTimelineEntry(date: .now)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}
