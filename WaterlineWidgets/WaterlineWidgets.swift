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

// MARK: - Home Screen: System Small

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
            smallNoSessionView
        }
    }

    private var smallNoSessionView: some View {
        VStack(spacing: 6) {
            if let last = entry.lastSession {
                Text("Last Session")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(last.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Label("\(last.drinkCount)", systemImage: "wineglass")
                    Label("\(last.waterCount)", systemImage: "drop.fill")
                        .foregroundStyle(.blue)
                }
                .font(.caption.weight(.medium))
            } else {
                Image(systemName: "drop")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No Session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                // Left side: Waterline gauge
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: clampedFraction)
                            .stroke(entry.isWarning ? Color.red : Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text(String(format: "%.1f", entry.waterlineValue))
                            .font(.system(.title3, design: .rounded).bold().monospacedDigit())
                            .foregroundStyle(entry.isWarning ? .red : .primary)
                    }
                    .frame(width: 56, height: 56)

                    Text("Waterline")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Right side: counts + reminder + buttons
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        Label("\(entry.drinkCount)", systemImage: "wineglass")
                            .font(.subheadline.weight(.medium))
                        Label("\(entry.waterCount)", systemImage: "drop.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.blue)
                    }

                    if let reminder = entry.nextReminderText {
                        Label("Next: \(reminder)", systemImage: "bell")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let startTime = entry.sessionStartTime {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text(startTime, style: .relative)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        Button(intent: LogDrinkIntent()) {
                            Label("Drink", systemImage: "plus")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)

                        Button(intent: LogWaterIntent()) {
                            Label("Water", systemImage: "plus")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
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
            Image(systemName: "drop")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            if let last = entry.lastSession {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Session")
                        .font(.subheadline.weight(.semibold))
                    Text(last.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Label("\(last.drinkCount) drinks", systemImage: "wineglass")
                        Label("\(last.waterCount) water", systemImage: "drop.fill")
                            .foregroundStyle(.blue)
                    }
                    .font(.caption)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Waterline")
                        .font(.subheadline.weight(.semibold))
                    Text("Start a session to track your pacing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                // Top row: waterline value + counts
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(entry.isWarning ? .red : .blue)
                            .font(.title3)
                        Text(String(format: "%.1f", entry.waterlineValue))
                            .font(.system(.title, design: .rounded).bold().monospacedDigit())
                            .foregroundStyle(entry.isWarning ? .red : .primary)
                    }
                    Spacer()
                    HStack(spacing: 16) {
                        Label("\(entry.drinkCount)", systemImage: "wineglass")
                            .font(.subheadline.weight(.medium))
                        Label("\(entry.waterCount)", systemImage: "drop.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.blue)
                    }
                }

                // Waterline linear gauge
                Gauge(value: clampedFraction, in: 0...1) {
                    EmptyView()
                }
                .gaugeStyle(.linearCapacity)
                .tint(entry.isWarning ? .red : .blue)

                // Next reminder
                if let reminder = entry.nextReminderText {
                    HStack {
                        Label("Next reminder: \(reminder)", systemImage: "bell")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }

                // Recent log entries
                if !entry.recentEntries.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(entry.recentEntries) { log in
                            HStack {
                                Image(systemName: log.isAlcohol ? "wineglass" : "drop.fill")
                                    .foregroundStyle(log.isAlcohol ? .orange : .blue)
                                    .font(.caption)
                                    .frame(width: 20)
                                Text(log.label)
                                    .font(.caption)
                                Spacer()
                                Text(log.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                            if log.id != entry.recentEntries.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }

                Spacer()

                // Quick-add buttons
                HStack(spacing: 8) {
                    Button(intent: LogDrinkIntent()) {
                        Label("Log Drink", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    Button(intent: LogWaterIntent()) {
                        Label("Log Water", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
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

            Image(systemName: "drop")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            if let last = entry.lastSession {
                VStack(spacing: 8) {
                    Text("Last Session")
                        .font(.headline)
                    Text(last.date, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 20) {
                        VStack {
                            Text("\(last.drinkCount)")
                                .font(.title2.bold().monospacedDigit())
                            Text("Drinks")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        VStack {
                            Text("\(last.waterCount)")
                                .font(.title2.bold().monospacedDigit())
                                .foregroundStyle(.blue)
                            Text("Water")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        VStack {
                            Text(String(format: "%.1f", last.finalWaterline))
                                .font(.title2.bold().monospacedDigit())
                                .foregroundStyle(last.finalWaterline >= 2 ? .red : .primary)
                            Text("Final WL")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(formatDuration(last.duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Waterline")
                    .font(.headline)
                Text("Start a session to begin tracking your pacing")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
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
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
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
