import SwiftUI

struct WatchContentView: View {
    @ObservedObject var sessionManager: WatchSessionManager

    var body: some View {
        ZStack {
            if sessionManager.isSessionActive {
                activeSessionView
            } else {
                noSessionView
            }
        }
        .sheet(item: $sessionManager.pendingReminder) { reminder in
            WaterReminderSheet(
                reminder: reminder,
                onLogWater: {
                    sessionManager.sendLogWaterCommand()
                    sessionManager.dismissReminder()
                },
                onDismiss: {
                    sessionManager.dismissReminder()
                }
            )
        }
    }

    // MARK: - Active Session

    private var activeSessionView: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Compact waterline indicator
                waterlineGauge

                // Counts
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("\(sessionManager.drinkCount)")
                            .font(.title3.bold())
                        Text("Drinks")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 2) {
                        Text("\(sessionManager.waterCount)")
                            .font(.title3.bold())
                        Text("Water")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var waterlineGauge: some View {
        let value = sessionManager.waterlineValue
        let clamped = min(max(value, -5), 5)
        let normalizedFraction = clamped / 5.0

        return VStack(spacing: 4) {
            Gauge(value: normalizedFraction, in: -1...1) {
                Text("WL")
            } currentValueLabel: {
                Text(String(format: "%.1f", value))
                    .font(.caption.monospacedDigit())
            }
            .gaugeStyle(.accessoryCircular)
            .tint(value >= 2 ? .red : (value > 0 ? .orange : .blue))
        }
    }

    // MARK: - No Session

    private var noSessionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "drop.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text("Waterline")
                .font(.headline)
            Text("No active session")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Water Reminder Sheet

struct WaterReminderSheet: View {
    let reminder: WatchSessionManager.WaterReminder
    let onLogWater: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "drop.fill")
                    .font(.title)
                    .foregroundStyle(.blue)

                Text(reminder.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(reminder.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    onLogWater()
                } label: {
                    Label("Log Water", systemImage: "drop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Button("Dismiss", role: .cancel) {
                    onDismiss()
                }
                .font(.caption)
            }
            .padding()
        }
    }
}

#Preview {
    WatchContentView(sessionManager: WatchSessionManager())
}
