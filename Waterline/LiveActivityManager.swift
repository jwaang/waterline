import ActivityKit
import Foundation
import WidgetKit

/// Manages the Live Activity lifecycle for active drinking sessions.
/// Call from main app whenever session state changes.
@MainActor
enum LiveActivityManager {

    // MARK: - Start

    /// Starts a Live Activity for the given session. No-op if ActivityKit is unavailable.
    static func startActivity(sessionId: UUID, startTime: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = SessionActivityAttributes(
            sessionId: sessionId.uuidString,
            startTime: startTime
        )
        let initialState = SessionActivityAttributes.ContentState(
            waterlineValue: 0,
            drinkCount: 0,
            waterCount: 0,
            isWarning: false
        )
        let content = ActivityContent(state: initialState, staleDate: nil)

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            // Silently fail — Live Activity is a nice-to-have, not critical
        }
    }

    // MARK: - Update

    /// Updates all running Live Activities with new session state.
    static func updateActivity(
        waterlineValue: Double,
        drinkCount: Int,
        waterCount: Int,
        isWarning: Bool
    ) {
        let state = SessionActivityAttributes.ContentState(
            waterlineValue: waterlineValue,
            drinkCount: drinkCount,
            waterCount: waterCount,
            isWarning: isWarning
        )
        let content = ActivityContent(state: state, staleDate: nil)

        for activity in Activity<SessionActivityAttributes>.activities {
            Task {
                await activity.update(content)
            }
        }
    }

    // MARK: - End

    /// Ends all running Live Activities with final state.
    static func endActivity(
        waterlineValue: Double,
        drinkCount: Int,
        waterCount: Int,
        isWarning: Bool
    ) {
        let finalState = SessionActivityAttributes.ContentState(
            waterlineValue: waterlineValue,
            drinkCount: drinkCount,
            waterCount: waterCount,
            isWarning: isWarning
        )
        let content = ActivityContent(state: finalState, staleDate: nil)

        for activity in Activity<SessionActivityAttributes>.activities {
            Task {
                await activity.end(content, dismissalPolicy: .default)
            }
        }
    }

    /// Ends all running Live Activities immediately (e.g., abandoned session).
    static func endAllActivities() {
        for activity in Activity<SessionActivityAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
