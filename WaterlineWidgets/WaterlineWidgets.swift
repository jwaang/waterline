import WidgetKit
import SwiftUI

struct WaterlineWidgetsEntryView: View {
    var entry: WaterlineTimelineProvider.Entry

    var body: some View {
        VStack {
            Image(systemName: "drop.fill")
                .foregroundStyle(.tint)
            Text("Waterline")
                .font(.caption)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct WaterlineWidgets: Widget {
    let kind: String = "WaterlineWidgets"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WaterlineTimelineProvider()) { entry in
            WaterlineWidgetsEntryView(entry: entry)
        }
        .configurationDisplayName("Waterline")
        .description("Track your session status.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct WaterlineWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WaterlineWidgets()
    }
}
