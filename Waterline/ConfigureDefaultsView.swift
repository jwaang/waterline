import SwiftUI
import SwiftData
import UserNotifications

// MARK: - ConfigureDefaultsView

struct ConfigureDefaultsView: View {
    @Environment(\.modelContext) private var modelContext
    let authManager: AuthenticationManager
    let onComplete: () -> Void

    @State private var waterEveryNDrinks: Int = 1
    @State private var timeRemindersEnabled: Bool = false
    @State private var timeReminderIntervalMinutes: Int = 20
    @State private var warningThreshold: Int = 2
    @State private var units: VolumeUnit = .oz
    @State private var showNotificationExplanation = false

    private let intervalOptions = [10, 15, 20, 30, 45, 60]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(.blue.opacity(0.8))

                        Text("Set Your Pace")
                            .font(.title2.bold())

                        Text("Configure how Waterline reminds you to drink water.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 24)

                    // Settings sections
                    VStack(spacing: 24) {
                        waterFrequencySection
                        timeReminderSection
                        warningSection
                        unitsSection
                    }
                    .padding(.horizontal, 24)
                }
            }

            // Done button
            Button(action: saveAndComplete) {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
            .padding(.bottom, 48)
            .padding(.top, 16)
        }
        .sheet(isPresented: $showNotificationExplanation) {
            NotificationPermissionView {
                showNotificationExplanation = false
                completeOnboarding()
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Sections

    private var waterFrequencySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Water Frequency")
                .font(.headline)

            HStack {
                Text("Drink water every")
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper(
                    "\(waterEveryNDrinks) drink\(waterEveryNDrinks == 1 ? "" : "s")",
                    value: $waterEveryNDrinks,
                    in: 1...10
                )
            }
        }
        .padding(16)
        .background(.fill.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var timeReminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Reminders")
                .font(.headline)

            Toggle("Enable time-based reminders", isOn: $timeRemindersEnabled)

            if timeRemindersEnabled {
                HStack {
                    Text("Remind every")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Interval", selection: $timeReminderIntervalMinutes) {
                        ForEach(intervalOptions, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .padding(16)
        .background(.fill.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: timeRemindersEnabled)
    }

    private var warningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Warning Threshold")
                .font(.headline)

            HStack {
                Text("Warn when Waterline reaches")
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper(
                    "\(warningThreshold)",
                    value: $warningThreshold,
                    in: 1...10
                )
            }
        }
        .padding(16)
        .background(.fill.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var unitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Units")
                .font(.headline)

            Picker("Volume units", selection: $units) {
                Text("oz").tag(VolumeUnit.oz)
                Text("ml").tag(VolumeUnit.ml)
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(.fill.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func saveAndComplete() {
        saveSettings()
        showNotificationExplanation = true
    }

    private func saveSettings() {
        guard let appleUserId = authManager.currentAppleUserId else { return }

        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.appleUserId == appleUserId }
        )
        guard let user = try? modelContext.fetch(descriptor).first else { return }

        user.settings.waterEveryNDrinks = waterEveryNDrinks
        user.settings.timeRemindersEnabled = timeRemindersEnabled
        user.settings.timeReminderIntervalMinutes = timeReminderIntervalMinutes
        user.settings.warningThreshold = warningThreshold
        user.settings.units = units

        try? modelContext.save()
    }

    private func completeOnboarding() {
        createDefaultPresets()
        onComplete()
    }

    private func createDefaultPresets() {
        guard let appleUserId = authManager.currentAppleUserId else { return }

        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.appleUserId == appleUserId }
        )
        guard let user = try? modelContext.fetch(descriptor).first else { return }

        // Skip if user already has presets (e.g. restored from Convex sync)
        if !user.presets.isEmpty { return }

        let defaults: [(String, DrinkType, Double, Double)] = [
            ("Beer", .beer, 12, 1.0),
            ("Glass of Wine", .wine, 5, 1.0),
            ("Shot", .liquor, 1.5, 1.0),
            ("Cocktail", .cocktail, 6, 1.0),
            ("Double", .liquor, 3, 2.0),
        ]

        for (name, drinkType, sizeOz, estimate) in defaults {
            let preset = DrinkPreset(
                name: name,
                drinkType: drinkType,
                sizeOz: sizeOz,
                standardDrinkEstimate: estimate
            )
            preset.user = user
            modelContext.insert(preset)
        }

        try? modelContext.save()
    }
}

// MARK: - NotificationPermissionView

struct NotificationPermissionView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.blue.opacity(0.8))

            VStack(spacing: 12) {
                Text("Stay on Track")
                    .font(.title3.bold())

                Text("Waterline sends gentle reminders to drink water during your session. Allow notifications to get pacing nudges.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: requestNotifications) {
                    Text("Enable Notifications")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onDismiss) {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 48)
        }
    }

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, _ in
            DispatchQueue.main.async {
                onDismiss()
            }
        }
    }
}
