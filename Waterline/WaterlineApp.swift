import SwiftUI
import SwiftData

@main
struct WaterlineApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            User.self,
            Session.self,
            LogEntry.self,
            DrinkPreset.self,
        ])
    }
}
