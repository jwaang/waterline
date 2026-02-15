import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Design Tokens

private extension Color {
    static let wlWidgetInk = Color.primary
    static let wlWidgetSecondary = Color.secondary
    static let wlWidgetWarning = Color(red: 0.75, green: 0.22, blue: 0.17)
    static let wlWidgetButton = Color.accentColor
}

// MARK: - Lock Screen: Accessory Circular

struct AccessoryCircularView: View {
    let entry: WaterlineTimelineEntry

    var body: some View {
        if entry.hasActiveSession {
            Gauge(value: clampedFraction, in: 0...1) {
                Text("WL")
            } currentValueLabel: {
                Text(String(format: "%.0f", entry.waterlineValue))
                    .font(.system(.body, design: .monospaced).bold())
            }
            .gaugeStyle(.accessoryCircular)
            .tint(entry.isWarning ? Color.wlWidgetWarning : Color.wlWidgetInk)
        } else {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Text("WL")
                        .font(.system(size: 10, weight: .bold))
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
                Gauge(value: clampedFraction, in: 0...1) {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinear)
                .tint(entry.isWarning ? Color.wlWidgetWarning : Color.wlWidgetInk)
                .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("WL \(String(format: "%.1f", entry.waterlineValue))")
                        .font(.system(.headline, design: .monospaced))
                        .widgetAccentable()
                    Text("\(entry.drinkCount)D  \(entry.waterCount)W")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
            }
        } else {
            HStack(spacing: 6) {
                Text("WL")
                    .font(.system(.title3, design: .monospaced).bold())
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
            Text("WL \(String(format: "%.1f", entry.waterlineValue)) | \(entry.drinkCount)D \(entry.waterCount)W")
        } else {
            Text("WL — No Session")
        }
    }
}

// MARK: - Home Screen: System Small

struct SystemSmallView: View {
    let entry: WaterlineTimelineEntry

    var body: some View {
        if entry.hasActiveSession {
            VStack(spacing: 8) {
                HStack {
                    Text("WL")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.wlWidgetSecondary)
                    Spacer()
                    Text(String(format: "%.1f", entry.waterlineValue))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(entry.isWarning ? Color.wlWidgetWarning : Color.wlWidgetInk)
                }

                Spacer()

                HStack(spacing: 12) {
                    VStack(spacing: 2) {
                        Text("\(entry.drinkCount)")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                        Text("DRINKS")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.wlWidgetSecondary)
                    }
                    VStack(spacing: 2) {
                        Text("\(entry.waterCount)")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                        Text("WATER")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.wlWidgetSecondary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(intent: LogDrinkIntent()) {
                        Text("+ Drink")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.wlWidgetButton)

                    Button(intent: LogWaterIntent()) {
                        Text("+ Water")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.wlWidgetButton)
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            smallNoSessionView
        }
    }

    private var smallNoSessionView: some View {
        VStack(spacing: 6) {
            if let last = entry.lastSession {
                Text("LAST SESSION")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.wlWidgetSecondary)
                Text(last.date, style: .date)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.wlWidgetSecondary)
                HStack(spacing: 8) {
                    Text("\(last.drinkCount)D")
                    Text("\(last.waterCount)W")
                }
                .font(.system(size: 13, weight: .bold, design: .monospaced))
            } else {
                Text("WL")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.wlWidgetSecondary)
                Text("NO SESSION")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.wlWidgetSecondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Home Screen: System Medium

struct SystemMediumView: View {
    let entry: WaterlineTimelineEntry

    var body: some View {
        if entry.hasActiveSession {
            HStack(spacing: 16) {
                // Left side: Waterline value
                VStack(spacing: 6) {
                    ZStack {
                        Rectangle()
                            .strokeBorder(Color.wlWidgetSecondary.opacity(0.2), lineWidth: 2)
                            .frame(width: 56, height: 56)

                        Text(String(format: "%.1f", entry.waterlineValue))
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(entry.isWarning ? Color.wlWidgetWarning : Color.wlWidgetInk)
                    }

                    Text("WL")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.wlWidgetSecondary)
                }

                // Right side
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        VStack(spacing: 2) {
                            Text("\(entry.drinkCount)")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                            Text("DRINKS")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.wlWidgetSecondary)
                        }
                        VStack(spacing: 2) {
                            Text("\(entry.waterCount)")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                            Text("WATER")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.wlWidgetSecondary)
                        }
                    }

                    if let reminder = entry.nextReminderText {
                        Text("NEXT: \(reminder.uppercased())")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.wlWidgetSecondary)
                    } else if let startTime = entry.sessionStartTime {
                        Text(startTime, style: .relative)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.wlWidgetSecondary)
                    }

                    HStack(spacing: 8) {
                        Button(intent: LogDrinkIntent()) {
                            Text("+ Drink")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.wlWidgetButton)

                        Button(intent: LogWaterIntent()) {
                            Text("+ Water")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.wlWidgetButton)
                    }
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            mediumNoSessionView
        }
    }

    private var mediumNoSessionView: some View {
        HStack(spacing: 16) {
            Text("WL")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.wlWidgetSecondary)

            if let last = entry.lastSession {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LAST SESSION")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.wlWidgetSecondary)
                    Text(last.date, style: .date)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.wlWidgetSecondary)
                    Text("\(last.drinkCount)D  \(last.waterCount)W")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WATERLINE")
                        .font(.system(size: 15, weight: .bold))
                    Text("START A SESSION TO TRACK")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.wlWidgetSecondary)
                }
            }

            Spacer()
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var clampedFraction: Double {
        let clamped = min(max(entry.waterlineValue, 0), 5)
        return clamped / 5.0
    }
}

// MARK: - Home Screen: System Large

struct SystemLargeView: View {
    let entry: WaterlineTimelineEntry

    var body: some View {
        if entry.hasActiveSession {
            VStack(spacing: 12) {
                // Top row
                HStack {
                    Text("WL")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.wlWidgetSecondary)
                    Spacer()
                    Text(String(format: "%.1f", entry.waterlineValue))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(entry.isWarning ? Color.wlWidgetWarning : Color.wlWidgetInk)
                }

                // Linear gauge
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.wlWidgetSecondary.opacity(0.15))
                        Rectangle()
                            .fill(entry.isWarning ? Color.wlWidgetWarning : Color.wlWidgetInk)
                            .frame(width: geo.size.width * clampedFraction)
                    }
                }
                .frame(height: 6)

                // Counts
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("\(entry.drinkCount)")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                        Text("DRINKS")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.wlWidgetSecondary)
                    }
                    VStack(spacing: 2) {
                        Text("\(entry.waterCount)")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                        Text("WATER")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.wlWidgetSecondary)
                    }
                    Spacer()
                }

                // Next reminder
                if let reminder = entry.nextReminderText {
                    HStack {
                        Text("NEXT REMINDER: \(reminder.uppercased())")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.wlWidgetSecondary)
                        Spacer()
                    }
                }

                // Recent log entries
                if !entry.recentEntries.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(entry.recentEntries) { log in
                            HStack {
                                Text(log.isAlcohol ? "ALC" : "H2O")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(log.isAlcohol ? Color.wlWidgetInk : Color.wlWidgetSecondary)
                                    .frame(width: 28, alignment: .leading)
                                Text(log.label)
                                    .font(.system(size: 12))
                                Spacer()
                                Text(log.timestamp, style: .time)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color.wlWidgetSecondary)
                            }
                            .padding(.vertical, 4)
                            if log.id != entry.recentEntries.last?.id {
                                Rectangle()
                                    .fill(Color.wlWidgetSecondary.opacity(0.15))
                                    .frame(height: 1)
                            }
                        }
                    }
                }

                Spacer()

                // Quick-add buttons
                HStack(spacing: 8) {
                    Button(intent: LogDrinkIntent()) {
                        Text("+ Drink")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.wlWidgetButton)

                    Button(intent: LogWaterIntent()) {
                        Text("+ Water")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.wlWidgetButton)
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            largeNoSessionView
        }
    }

    private var largeNoSessionView: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("WATERLINE")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.wlWidgetSecondary)

            if let last = entry.lastSession {
                VStack(spacing: 8) {
                    Text("LAST SESSION")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.wlWidgetSecondary)
                    Text(last.date, style: .date)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.wlWidgetSecondary)

                    HStack(spacing: 20) {
                        VStack(spacing: 2) {
                            Text("\(last.drinkCount)")
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                            Text("DRINKS")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.wlWidgetSecondary)
                        }
                        VStack(spacing: 2) {
                            Text("\(last.waterCount)")
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                            Text("WATER")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.wlWidgetSecondary)
                        }
                        VStack(spacing: 2) {
                            Text(String(format: "%.1f", last.finalWaterline))
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundStyle(last.finalWaterline >= 2 ? Color.wlWidgetWarning : Color.wlWidgetInk)
                            Text("FINAL WL")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.wlWidgetSecondary)
                        }
                    }

                    Text(formatDuration(last.duration))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.wlWidgetSecondary)
                }
            } else {
                Text("START A SESSION TO BEGIN TRACKING")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.wlWidgetSecondary)
            }

            Spacer()
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var clampedFraction: Double {
        let clamped = min(max(entry.waterlineValue, 0), 5)
        return clamped / 5.0
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)H \(minutes)M"
        }
        return "\(minutes)M"
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
        case .systemMedium:
            SystemMediumView(entry: entry)
        case .systemLarge:
            SystemLargeView(entry: entry)
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
            .systemMedium,
            .systemLarge,
        ])
    }
}

// MARK: - Widget Bundle

@main
struct WaterlineWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WaterlineWidgets()
        SessionLiveActivity()
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

#Preview("Medium - Active", as: .systemMedium) {
    WaterlineWidgets()
} timeline: {
    WaterlineTimelineEntry.placeholder
}

#Preview("Medium - No Session", as: .systemMedium) {
    WaterlineWidgets()
} timeline: {
    WaterlineTimelineEntry.noSession
}

#Preview("Large - Active", as: .systemLarge) {
    WaterlineWidgets()
} timeline: {
    WaterlineTimelineEntry.placeholder
}

#Preview("Large - No Session", as: .systemLarge) {
    WaterlineWidgets()
} timeline: {
    WaterlineTimelineEntry.noSession
}
