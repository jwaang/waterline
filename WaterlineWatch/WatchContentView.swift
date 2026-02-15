import SwiftUI

// MARK: - Watch Design Tokens

private extension Color {
    static let wlInk = Color.white
    static let wlSecondary = Color.secondary
    static let wlWarning = Color(red: 0.75, green: 0.22, blue: 0.17)
}

private extension Font {
    static let wlWatchNumeral: Font = .system(size: 20, weight: .bold, design: .monospaced)
    static let wlWatchTechnical: Font = .system(size: 10, weight: .medium)
    static let wlWatchBody: Font = .system(size: 15, weight: .regular)
}

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
                waterlineGauge

                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("\(sessionManager.drinkCount)")
                            .font(.wlWatchNumeral)
                        Text("DRINKS")
                            .font(.wlWatchTechnical)
                            .foregroundStyle(Color.wlSecondary)
                    }
                    VStack(spacing: 2) {
                        Text("\(sessionManager.waterCount)")
                            .font(.wlWatchNumeral)
                        Text("WATER")
                            .font(.wlWatchTechnical)
                            .foregroundStyle(Color.wlSecondary)
                    }
                }

                quickAddButtons

                Rectangle()
                    .fill(Color.wlSecondary.opacity(0.3))
                    .frame(height: 1)

                Button(role: .destructive) {
                    showingEndConfirmation = true
                } label: {
                    Text("End Session")
                        .font(.footnote)
                        .foregroundStyle(Color.wlWarning)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color.wlWarning)
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
        let isWarning = value >= 2

        return VStack(spacing: 4) {
            Gauge(value: normalizedFraction, in: -1...1) {
                Text("WL")
                    .font(.wlWatchTechnical)
            } currentValueLabel: {
                Text(String(format: "%.1f", value))
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(isWarning ? Color.wlWarning : Color.wlInk)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(isWarning ? Color.wlWarning : Color.wlInk)
        }
    }

    // MARK: - Quick Add Buttons

    private var quickAddButtons: some View {
        VStack(spacing: 8) {
            Button {
                showingDrinkPicker = true
            } label: {
                Text("+ Drink")
                    .font(.headline)
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.wlInk)

            Button {
                sessionManager.sendLogWaterCommand()
            } label: {
                Text("+ Water")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.wlInk)
        }
    }

    // MARK: - Drink Preset Picker

    private var drinkPresetPicker: some View {
        NavigationStack {
            List {
                if sessionManager.presets.isEmpty {
                    defaultDrinkOptions
                } else {
                    ForEach(sessionManager.presets) { preset in
                        Button {
                            sessionManager.sendLogDrinkCommand(preset: preset)
                            showingDrinkPicker = false
                        } label: {
                            HStack {
                                Text(preset.name)
                                    .font(.wlWatchBody)
                                Spacer()
                                Text("\(preset.standardDrinkEstimate, specifier: "%.1f") std")
                                    .font(.wlWatchTechnical)
                                    .foregroundStyle(Color.wlSecondary)
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
                        .font(.wlWatchBody)
                    Spacer()
                    Text("\(estimate, specifier: "%.1f") std")
                        .font(.wlWatchTechnical)
                        .foregroundStyle(Color.wlSecondary)
                }
            }
        }
    }

    // MARK: - No Session

    private var noSessionView: some View {
        VStack(spacing: 12) {
            Text("WATERLINE")
                .font(.system(size: 16, weight: .bold))
                .tracking(2)

            Button {
                sessionManager.sendStartSessionCommand()
            } label: {
                Text("Start Session")
                    .font(.headline)
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.wlInk)
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
                Text("REMINDER")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .tracking(1)

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
                    Text("+ Water")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.primary)

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
