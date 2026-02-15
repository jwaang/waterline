import ActivityKit
import Foundation

struct SessionActivityAttributes: ActivityAttributes {
    /// Static data that doesn't change during the Live Activity's lifetime.
    let sessionId: String
    let startTime: Date
    let warningThreshold: Int

    /// Dynamic data updated throughout the session.
    struct ContentState: Codable, Hashable {
        var waterlineValue: Double
        var drinkCount: Int
        var waterCount: Int
        var isWarning: Bool
    }
}
