import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]

    let authManager: AuthenticationManager

    @State private var showDeleteConfirmation = false
    @State private var showSignOutConfirmation = false

    private var user: User? { users.first }
    private var settings: UserSettings { user?.settings ?? UserSettings() }

    private let intervalOptions = [10, 15, 20, 30, 45, 60]

    var body: some View {
        List {
            remindersSection
            waterlineSection
            defaultsSection
            presetsSection
            accountSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Reminders

    private var remindersSection: some View {
        Section {
            Toggle("Time-based reminders", isOn: Binding(
                get: { settings.timeRemindersEnabled },
                set: { newValue in
                    user?.settings.timeRemindersEnabled = newValue
                    save()
                }
            ))

            if settings.timeRemindersEnabled {
                HStack {
                    Text("Remind every")
                    Spacer()
                    Picker("Interval", selection: Binding(
                        get: { settings.timeReminderIntervalMinutes },
                        set: { newValue in
                            user?.settings.timeReminderIntervalMinutes = newValue
                            save()
                        }
                    )) {
                        ForEach(intervalOptions, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            HStack {
                Text("Water every")
                Spacer()
                Stepper(
                    "\(settings.waterEveryNDrinks) drink\(settings.waterEveryNDrinks == 1 ? "" : "s")",
                    value: Binding(
                        get: { settings.waterEveryNDrinks },
                        set: { newValue in
                            user?.settings.waterEveryNDrinks = newValue
                            save()
                        }
                    ),
                    in: 1...10
                )
            }
        } header: {
            Text("Reminders")
        }
        .animation(.easeInOut(duration: 0.2), value: settings.timeRemindersEnabled)
    }

    // MARK: - Waterline

    private var waterlineSection: some View {
        Section {
            HStack {
                Text("Warning threshold")
                Spacer()
                Stepper(
                    "\(settings.warningThreshold)",
                    value: Binding(
                        get: { settings.warningThreshold },
                        set: { newValue in
                            user?.settings.warningThreshold = newValue
                            save()
                        }
                    ),
                    in: 1...10
                )
            }
        } header: {
            Text("Waterline")
        }
    }

    // MARK: - Defaults

    private var defaultsSection: some View {
        Section {
            HStack {
                Text("Default water amount")
                Spacer()
                Stepper(
                    "\(settings.defaultWaterAmountOz) \(settings.units.rawValue)",
                    value: Binding(
                        get: { settings.defaultWaterAmountOz },
                        set: { newValue in
                            user?.settings.defaultWaterAmountOz = newValue
                            save()
                        }
                    ),
                    in: 1...32
                )
            }

            Picker("Units", selection: Binding(
                get: { settings.units },
                set: { newValue in
                    user?.settings.units = newValue
                    save()
                }
            )) {
                Text("oz").tag(VolumeUnit.oz)
                Text("ml").tag(VolumeUnit.ml)
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Defaults")
        }
    }

    // MARK: - Presets

    private var presetsSection: some View {
        Section {
            NavigationLink {
                PresetsListView()
            } label: {
                HStack {
                    Text("Manage Quick Drinks")
                    Spacer()
                    Text("\(user?.presets.count ?? 0)")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Presets")
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        Section {
            Button("Sign Out") {
                showSignOutConfirmation = true
            }
            .confirmationDialog("Sign out?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                }
            }

            Button("Delete Account", role: .destructive) {
                showDeleteConfirmation = true
            }
            .confirmationDialog(
                "Delete your account?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("This will permanently remove all your data. This action cannot be undone.")
            }
        } header: {
            Text("Account")
        }
    }

    // MARK: - Helpers

    private func save() {
        try? modelContext.save()
    }

    private func deleteAccount() {
        let presetDescriptor = FetchDescriptor<DrinkPreset>()
        if let presets = try? modelContext.fetch(presetDescriptor) {
            for preset in presets { modelContext.delete(preset) }
        }

        let entryDescriptor = FetchDescriptor<LogEntry>()
        if let entries = try? modelContext.fetch(entryDescriptor) {
            for entry in entries { modelContext.delete(entry) }
        }

        let sessionDescriptor = FetchDescriptor<Session>()
        if let sessions = try? modelContext.fetch(sessionDescriptor) {
            for session in sessions { modelContext.delete(session) }
        }

        let userDescriptor = FetchDescriptor<User>()
        if let fetchedUsers = try? modelContext.fetch(userDescriptor) {
            for u in fetchedUsers { modelContext.delete(u) }
        }

        try? modelContext.save()

        ReminderService.cancelAllTimeReminders()

        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")

        authManager.signOut()
    }
}

#Preview {
    NavigationStack {
        SettingsView(authManager: AuthenticationManager(store: InMemoryCredentialStore()))
            .modelContainer(for: [User.self, Session.self, LogEntry.self, DrinkPreset.self], inMemory: true)
    }
}
