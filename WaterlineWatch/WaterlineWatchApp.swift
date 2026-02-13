import SwiftUI

@main
struct WaterlineWatchApp: App {
    @StateObject private var sessionManager = WatchSessionManager()

    var body: some Scene {
        WindowGroup {
            WatchContentView(sessionManager: sessionManager)
        }
    }
}
