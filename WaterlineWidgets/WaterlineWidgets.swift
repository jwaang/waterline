import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Lock Screen: Accessory Circular

struct AccessoryCircularView: View {
    let entry: WaterlineTimelineEntry

    var body: some View {
        if entry.hasActiveSession {
            Gauge(value: clampedFraction, in: 0...1) {
                Image(systemName: "drop.fill")
            } currentValueLabel: {
                Text(String(format: "%.0f", entry.waterlineValue))
                    .font(.system(.body, design: .rounded).bold())
            }
            .gaugeStyle(.accessoryCircular)
            .tint(entry.isWarning ? .red : .blue)
        } else {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Image(systemName: "drop")
                        .font(.caption)
                    Text("—")
                        .font(.caption2)
                }
            }
        }
    }

    private var clampedFraction: Double {
        let clamped = min(max(entry.waterlineValue, 0), 5)
        return clamped / 5.0
    }
}

// MARK: - Lock Screen: Accessory Rectangular

struct AccessoryRectangularView: View {
    let entry: WaterlineTimelineEntry

    var body: some View {
        if entry.hasActiveSession {
            HStack(spacing: 8) {
                // Mini waterline gauge
                Gauge(value: clampedFraction, in: 0...1) {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinear)
                .tint(entry.isWarning ? .red : .blue)
                .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("WL \(String(format: "%.1f", entry.waterlineValue))")
                        .font(.headline)
                        .widgetAccentable()
                    HStack(spacing: 6) {
                        Label("\(entry.drinkCount)", systemImage: "wineglass")
                        Label("\(entry.waterCount)", systemImage: "drop.fill")
                    }
                    .font(.caption)
                }
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "drop")
                    .font(.title3)
                Text("No Session")
                    .font(.headline)
            }
        }
    }

    private var clampedFraction: Double {
        let clamped = min(max(entry.waterlineValue, 0), 5)
        return clamped / 5.0
    }
}

// MARK: - Lock Screen: Accessory Inline

struct AccessoryInlineView: View {
    let entry: WaterlineTimelineEntry

    var body: some View {
        if entry.hasActiveSession {
            Label {
                Text("WL \(String(format: "%.1f", entry.waterlineValue)) | \(entry.drinkCount)D \(entry.waterCount)W")
            } icon: {
                Image(systemName: "drop.fill")
            }
        } else {
            Label("No Session", systemImage: "drop")
        }
    }
}

// MARK: - System Small (Home Screen)

struct SystemSmallView: View {
    let entry: WaterlineTimelineEntry

    var body: some View {
        if entry.hasActiveSession {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(entry.isWarning ? .red : .blue)
                    Spacer()
                    Text(String(format: "%.1f", entry.waterlineValue))
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(entry.isWarning ? .red : .primary)
                }

                Spacer()

                HStack(spacing: 12) {
                    Label("\(entry.drinkCount)", systemImage: "wineglass")
                        .font(.caption.weight(.medium))
                    Label("\(entry.waterCount)", systemImage: "drop.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.blue)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(intent: LogDrinkIntent()) {
                        Label("Drink", systemImage: "plus")
                            .font(.caption2.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    Button(intent: LogWaterIntent()) {
                        Label("Water", systemImage: "plus")
                            .font(.caption2.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "drop")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No Session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

// MARK: - Widget Entry View (Dispatches by Family)

struct WaterlineWidgetsEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: WaterlineTimelineProvider.Entry

    var body: some View {
        switch family {
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        case .accessoryInline:
            AccessoryInlineView(entry: entry)
        case .systemSmall:
            SystemSmallView(entry: entry)
        default:
            SystemSmallView(entry: entry)
        }
    }
}

// MARK: - Widget Configuration

struct WaterlineWidgets: Widget {
    let kind: String = "WaterlineWidgets"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WaterlineTimelineProvider()) { entry in
            WaterlineWidgetsEntryView(entry: entry)
        }
        .configurationDisplayName("Waterline")
        .description("Track your session status.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .systemSmall,
        ])
    }
}

// MARK: - Widget Bundle

@main
struct WaterlineWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WaterlineWidgets()
    }
}

// MARK: - Previews

#Preview("Circular - Active", as: .accessoryCircular) {
    WaterlineWidgets()
} timeline: {
    WaterlineTimelineEntry.placeholder
}

#Preview("Circular - No Session", as: .accessoryCircular) {
    WaterlineWidgets()
} timeline: {
    WaterlineTimelineEntry.noSession
}

#Preview("Rectangular - Active", as: .accessoryRectangular) {
    WaterlineWidgets()
} timeline: {
    WaterlineTimelineEntry.placeholder
}

#Preview("Inline - Active", as: .accessoryInline) {
    WaterlineWidgets()
} timeline: {
    WaterlineTimelineEntry.placeholder
}

#Preview("Small - Active", as: .systemSmall) {
    WaterlineWidgets()
} timeline: {
    WaterlineTimelineEntry.placeholder
}

#Preview("Small - No Session", as: .systemSmall) {
    WaterlineWidgets()
} timeline: {
    WaterlineTimelineEntry.noSession
}
