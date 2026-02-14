import SwiftUI

struct WatchContentView: View {
    @ObservedObject var sessionManager: WatchSessionManager
    @State private var showingDrinkPicker = false
    @State private var showingEndConfirmation = false

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

                // Quick-add buttons
                quickAddButtons

                Divider()

                // End session
                Button(role: .destructive) {
                    showingEndConfirmation = true
                } label: {
                    Label("End Session", systemImage: "stop.fill")
                        .font(.footnote)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .confirmationDialog("End this session?", isPresented: $showingEndConfirmation, titleVisibility: .visible) {
            Button("End Session", role: .destructive) {
                sessionManager.sendEndSessionCommand()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingDrinkPicker) {
            drinkPresetPicker
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

    // MARK: - Quick Add Buttons

    private var quickAddButtons: some View {
        VStack(spacing: 8) {
            Button {
                showingDrinkPicker = true
            } label: {
                Label("Drink", systemImage: "wineglass")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            Button {
                sessionManager.sendLogWaterCommand()
            } label: {
                Label("Water", systemImage: "drop.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
    }

    // MARK: - Drink Preset Picker

    private var drinkPresetPicker: some View {
        NavigationStack {
            List {
                if sessionManager.presets.isEmpty {
                    // Default quick options when no presets synced
                    defaultDrinkOptions
                } else {
                    ForEach(sessionManager.presets) { preset in
                        Button {
                            sessionManager.sendLogDrinkCommand(preset: preset)
                            showingDrinkPicker = false
                        } label: {
                            HStack {
                                Text(preset.name)
                                    .font(.body)
                                Spacer()
                                Text("\(preset.standardDrinkEstimate, specifier: "%.1f") std")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Log Drink")
        }
    }

    private var defaultDrinkOptions: some View {
        let defaults: [(String, String, Double, Double)] = [
            ("Beer", "beer", 12.0, 1.0),
            ("Wine", "wine", 5.0, 1.0),
            ("Shot", "liquor", 1.5, 1.0),
            ("Cocktail", "cocktail", 6.0, 1.0),
            ("Double", "liquor", 3.0, 2.0),
        ]
        return ForEach(defaults, id: \.0) { name, drinkType, sizeOz, estimate in
            Button {
                let preset = WatchSessionManager.WatchPreset(
                    name: name,
                    drinkType: drinkType,
                    sizeOz: sizeOz,
                    standardDrinkEstimate: estimate
                )
                sessionManager.sendLogDrinkCommand(preset: preset)
                showingDrinkPicker = false
            } label: {
                HStack {
                    Text(name)
                        .font(.body)
                    Spacer()
                    Text("\(estimate, specifier: "%.1f") std")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
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

            Button {
                sessionManager.sendStartSessionCommand()
            } label: {
                Label("Start Session", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
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
