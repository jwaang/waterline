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

    private let reminderRange = 5...60

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        WLSectionHeader(title: "CONFIGURE PROTOCOL")

                        Text("Configure how Waterline reminds you to drink water.")
                            .font(.wlBody)
                            .foregroundStyle(Color.wlSecondary)
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
                    .padding(.horizontal, WLSpacing.screenMargin)
                }
            }

            // Done button
            WLActionBlock(label: "Confirm", action: saveAndComplete)
                .padding(.horizontal, 40)
                .padding(.bottom, 48)
                .padding(.top, 16)
        }
        .background(Color.wlBase)
        .sheet(isPresented: $showNotificationExplanation) {
            NotificationPermissionView {
                showNotificationExplanation = false
                completeOnboarding()
            }
            .presentationDetents([.medium])
            .presentationCornerRadius(0)
        }
    }

    // MARK: - Sections

    private var waterFrequencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WATER FREQUENCY")
                .wlTechnical()

            WLStepper(
                label: "Drink water every",
                value: $waterEveryNDrinks,
                range: 1...10,
                displaySuffix: waterEveryNDrinks == 1 ? " drink" : " drinks"
            )
        }
        .padding(WLSpacing.sectionPadding)
        .overlay(
            Rectangle()
                .strokeBorder(Color.wlTertiary, lineWidth: 1)
        )
    }

    private var timeReminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TIME REMINDERS")
                .wlTechnical()

            WLToggle(label: "Enable time-based reminders", isOn: $timeRemindersEnabled)

            if timeRemindersEnabled {
                WLStepper(
                    label: "Remind every",
                    value: $timeReminderIntervalMinutes,
                    range: reminderRange,
                    step: 5,
                    displaySuffix: " min"
                )
            }
        }
        .padding(WLSpacing.sectionPadding)
        .overlay(
            Rectangle()
                .strokeBorder(Color.wlTertiary, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.15), value: timeRemindersEnabled)
    }

    private var warningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WARNING THRESHOLD")
                .wlTechnical()

            WLStepper(
                label: "Warn when Waterline reaches",
                value: $warningThreshold,
                range: 1...10
            )
        }
        .padding(WLSpacing.sectionPadding)
        .overlay(
            Rectangle()
                .strokeBorder(Color.wlTertiary, lineWidth: 1)
        )
    }

    private var unitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UNITS")
                .wlTechnical()

            WLSegmentedPicker(
                options: [("OZ", VolumeUnit.oz), ("ML", VolumeUnit.ml)],
                selection: $units
            )
        }
        .padding(WLSpacing.sectionPadding)
        .overlay(
            Rectangle()
                .strokeBorder(Color.wlTertiary, lineWidth: 1)
        )
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

            Text("NOTIFICATIONS")
                .wlTechnical()

            VStack(spacing: 12) {
                Text("Stay on Track")
                    .font(.wlHeadline)
                    .foregroundStyle(Color.wlInk)

                Text("Waterline sends gentle reminders to drink water during your session. Allow notifications to get pacing nudges.")
                    .font(.wlBody)
                    .foregroundStyle(Color.wlSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                WLActionBlock(label: "Enable Notifications", action: requestNotifications)

                Button(action: onDismiss) {
                    Text("Skip")
                        .font(.wlBody)
                        .foregroundStyle(Color.wlSecondary)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 48)
        }
        .background(Color.wlBase)
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
