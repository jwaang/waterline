import SwiftUI
import SwiftData

struct RootView: View {
    let authManager: AuthenticationManager
    let syncService: SyncService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            switch authManager.authState {
            case .unknown:
                ProgressView()
            case .signedOut:
                if hasCompletedOnboarding {
                    SignInView(authManager: authManager)
                } else {
                    OnboardingView(authManager: authManager)
                }
            case .signedIn:
                if hasCompletedOnboarding {
                    HomeView(authManager: authManager, syncService: syncService)
                } else {
                    ConfigureDefaultsView(authManager: authManager) {
                        hasCompletedOnboarding = true
                    }
                }
            }
        }
        .animation(.default, value: authManager.authState)
        .animation(.default, value: hasCompletedOnboarding)
    }
}

#Preview {
    let store = InMemoryCredentialStore()
    let manager = AuthenticationManager(store: store)
    let container = try! ModelContainer(for: User.self, Session.self, LogEntry.self, DrinkPreset.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let sync = SyncService(convexService: nil, modelContainer: container)
    RootView(authManager: manager, syncService: sync)
}
