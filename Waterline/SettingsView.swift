import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]

    let authManager: AuthenticationManager
    let syncService: SyncService

    @State private var showDeleteConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var notificationsAuthorized = true

    private var user: User? { users.first }
    private var settings: UserSettings { user?.settings ?? UserSettings() }

    private let reminderRange = 1...60

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                remindersSection
                waterlineSection
                defaultsSection
                presetsSection
                accountSection
            }
        }
        .background(Color.wlBase)
        .wlScreen()
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("SETTINGS")
                    .font(.wlHeadline)
                    .foregroundStyle(Color.wlInk)
            }
        }
        .onAppear {
            checkNotificationStatus()
        }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let isAuthorized = settings.authorizationStatus == .authorized
            DispatchQueue.main.async {
                notificationsAuthorized = isAuthorized
            }
        }
    }

    // MARK: - Reminders

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            WLSectionHeader(title: "REMINDERS")

            VStack(spacing: 16) {
                if !notificationsAuthorized {
                    HStack {
                        Text("NOTIFICATIONS DISABLED")
                            .wlTechnical()
                            .foregroundStyle(Color.wlWarning)
                        Spacer()
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            Button("Settings") {
                                UIApplication.shared.open(settingsURL)
                            }
                            .font(.wlTechnicalMono)
                            .foregroundStyle(Color.wlInk)
                        }
                    }
                }

                WLToggle(label: "Time-based reminders", isOn: Binding(
                    get: { settings.timeRemindersEnabled },
                    set: { newValue in
                        user?.settings.timeRemindersEnabled = newValue
                        save()
                    }
                ))

                if settings.timeRemindersEnabled {
                    WLStepper(
                        label: "Remind every",
                        value: Binding(
                            get: { settings.timeReminderIntervalMinutes },
                            set: { newValue in
                                user?.settings.timeReminderIntervalMinutes = newValue
                                save()
                            }
                        ),
                        range: reminderRange,
                        step: 5,
                        displaySuffix: " min",
                        snapStops: [1, 5]
                    )
                }

                WLToggle(label: "Discreet notifications", isOn: Binding(
                    get: { settings.discreetNotifications },
                    set: { newValue in
                        user?.settings.discreetNotifications = newValue
                        save()
                    }
                ))

                Text("Hides specific drink counts in notifications")
                    .font(.caption)
                    .foregroundStyle(Color.wlSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                WLStepper(
                    label: "Water every",
                    value: Binding(
                        get: { settings.waterEveryNDrinks },
                        set: { newValue in
                            user?.settings.waterEveryNDrinks = newValue
                            save()
                        }
                    ),
                    range: 1...10,
                    displaySuffix: settings.waterEveryNDrinks == 1 ? " drink" : " drinks"
                )
            }
            .padding(WLSpacing.sectionPadding)
        }
        .animation(.easeInOut(duration: 0.15), value: settings.timeRemindersEnabled)
    }

    // MARK: - Waterline

    private var waterlineSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            WLSectionHeader(title: "WATERLINE")

            VStack(spacing: 16) {
                WLStepper(
                    label: "Warning threshold",
                    value: Binding(
                        get: { settings.warningThreshold },
                        set: { newValue in
                            user?.settings.warningThreshold = newValue
                            save()
                        }
                    ),
                    range: 1...10
                )
            }
            .padding(WLSpacing.sectionPadding)
        }
    }

    // MARK: - Defaults

    private var defaultsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            WLSectionHeader(title: "DEFAULTS")

            VStack(spacing: 16) {
                WLStepper(
                    label: "Default water amount",
                    value: Binding(
                        get: { settings.defaultWaterAmountOz },
                        set: { newValue in
                            user?.settings.defaultWaterAmountOz = newValue
                            save()
                        }
                    ),
                    range: 1...32,
                    displaySuffix: " oz"
                )
            }
            .padding(WLSpacing.sectionPadding)
        }
    }

    // MARK: - Presets

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            WLSectionHeader(title: "PRESETS")

            NavigationLink {
                PresetsListView()
            } label: {
                HStack {
                    Text("Manage Quick Drinks")
                        .font(.wlBody)
                        .foregroundStyle(Color.wlInk)
                    Spacer()
                    Text("\(user?.presets.count ?? 0)")
                        .font(.wlTechnicalMono)
                        .foregroundStyle(Color.wlSecondary)
                    Text(">>")
                        .font(.wlTechnicalMono)
                        .foregroundStyle(Color.wlTertiary)
                }
                .padding(WLSpacing.sectionPadding)
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            WLSectionHeader(title: "ACCOUNT")

            VStack(spacing: 12) {
                WLActionBlock(label: "Sign Out", style: .secondary) {
                    showSignOutConfirmation = true
                }

                Button {
                    showDeleteConfirmation = true
                } label: {
                    Text("Delete Account")
                        .font(.wlControl)
                        .foregroundStyle(Color.wlWarning)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .padding(WLSpacing.sectionPadding)
            .alert("Sign out?", isPresented: $showSignOutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Delete your account?", isPresented: $showDeleteConfirmation) {
                Button("Delete Account", role: .destructive) {
                    deleteAccount()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove all your data. This action cannot be undone.")
            }
        }
    }

    // MARK: - Helpers

    private func save() {
        try? modelContext.save()
        syncService.triggerSync()
    }

    private func deleteAccount() {
        let appleUserId = user?.appleUserId

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

        if let appleUserId {
            Task {
                await syncService.deleteRemoteAccount(appleUserId: appleUserId)
            }
        }

        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")

        authManager.signOut()
    }
}

#Preview {
    let container = try! ModelContainer(for: User.self, Session.self, LogEntry.self, DrinkPreset.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    NavigationStack {
        SettingsView(
            authManager: AuthenticationManager(store: InMemoryCredentialStore()),
            syncService: SyncService(convexService: nil, modelContainer: container)
        )
        .modelContainer(container)
    }
}
