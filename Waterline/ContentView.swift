import SwiftUI

struct RootView: View {
    let authManager: AuthenticationManager

    var body: some View {
        Group {
            switch authManager.authState {
            case .unknown:
                ProgressView()
            case .signedOut:
                SignInView(authManager: authManager)
            case .signedIn:
                ContentView()
            }
        }
        .animation(.default, value: authManager.authState)
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
