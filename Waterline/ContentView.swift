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
                ContentView()
            }
        }
        .animation(.default, value: authManager.authState)
        .onChange(of: authManager.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                hasCompletedOnboarding = true
            }
        }
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
