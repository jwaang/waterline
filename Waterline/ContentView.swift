import SwiftUI

struct RootView: View {
    let authManager: AuthenticationManager
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
                    ContentView()
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

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "drop.fill")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Waterline")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
