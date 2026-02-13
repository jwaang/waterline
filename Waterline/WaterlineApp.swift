import SwiftUI
import SwiftData

@main
struct WaterlineApp: App {
    @State private var authManager = AuthenticationManager()

    var body: some Scene {
        WindowGroup {
            RootView(authManager: authManager)
                .onAppear {
                    authManager.restoreSession()
                }
        }
        .modelContainer(for: [
            User.self,
            Session.self,
            LogEntry.self,
            DrinkPreset.self,
        ])
    }
}
