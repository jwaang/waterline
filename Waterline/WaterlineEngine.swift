import Foundation

/// Pure computation module for Waterline state.
/// Used everywhere state is needed: active session, summary, after edits,
/// widgets, Live Activity, App Intents, and watch command handlers.
struct WaterlineEngine {

    /// Computed state from replaying log entries in timestamp order.
    struct WaterlineState {
        var waterlineValue: Double = 0
        var alcoholCountSinceLastWater: Int = 0
        var totalAlcoholCount: Int = 0
        var totalWaterCount: Int = 0
        var totalStandardDrinks: Double = 0
        var totalWaterVolumeOz: Double = 0
        var isWarning: Bool = false
    }

    /// Computes Waterline state by replaying all log entries in timestamp order.
    /// - Parameters:
    ///   - logs: The session's log entries (will be sorted by timestamp).
    ///   - warningThreshold: The user's warning threshold setting.
    /// - Returns: The computed `WaterlineState`.
    static func computeState(from logs: [LogEntry], warningThreshold: Int = 2) -> WaterlineState {
        let sorted = logs.sorted(by: { $0.timestamp < $1.timestamp })
        var state = WaterlineState()

        for entry in sorted {
            switch entry.type {
            case .alcohol:
                let estimate = entry.alcoholMeta?.standardDrinkEstimate ?? 1.0
                state.waterlineValue += estimate
                state.totalStandardDrinks += estimate
                state.totalAlcoholCount += 1
                state.alcoholCountSinceLastWater += 1
            case .water:
                state.waterlineValue -= 1
                state.totalWaterCount += 1
                state.alcoholCountSinceLastWater = 0
                state.totalWaterVolumeOz += entry.waterMeta?.amountOz ?? 0
            }
        }

        state.isWarning = state.waterlineValue >= Double(warningThreshold)
        return state
    }

    /// Computes pacing adherence: the percentage of N-drink intervals where the user
    /// logged water before the next group started.
    /// - Parameters:
    ///   - logs: The session's log entries (will be sorted by timestamp).
    ///   - waterEveryN: How many drinks between required water breaks.
    /// - Returns: Adherence as 0.0–1.0. Returns 1.0 if no water was ever due.
    static func computePacingAdherence(from logs: [LogEntry], waterEveryN: Int) -> Double {
        let sorted = logs.sorted(by: { $0.timestamp < $1.timestamp })
        var drinksSinceWater = 0
        var waterDueCount = 0
        var waterLoggedCount = 0

        for entry in sorted {
            switch entry.type {
            case .alcohol:
                drinksSinceWater += 1
                if drinksSinceWater >= waterEveryN {
                    waterDueCount += 1
                    drinksSinceWater = 0
                }
            case .water:
                if waterDueCount > waterLoggedCount {
                    waterLoggedCount += 1
                }
                drinksSinceWater = 0
            }
        }

        guard waterDueCount > 0 else { return 1.0 }
        return min(Double(waterLoggedCount) / Double(waterDueCount), 1.0)
    }

    /// Computes a full SessionSummary for an ended (or ending) session.
    /// - Parameters:
    ///   - logs: The session's log entries.
    ///   - startTime: Session start time.
    ///   - endTime: Session end time (uses current time if nil).
    ///   - waterEveryN: The user's waterEveryNDrinks setting.
    ///   - warningThreshold: The user's warning threshold setting.
    /// - Returns: A populated `SessionSummary`.
    static func computeSummary(
        from logs: [LogEntry],
        startTime: Date,
        endTime: Date?,
        waterEveryN: Int,
        warningThreshold: Int = 2
    ) -> SessionSummary {
        let state = computeState(from: logs, warningThreshold: warningThreshold)
        let adherence = computePacingAdherence(from: logs, waterEveryN: waterEveryN)
        let duration = (endTime ?? Date()).timeIntervalSince(startTime)

        return SessionSummary(
            totalDrinks: state.totalAlcoholCount,
            totalWater: state.totalWaterCount,
            totalStandardDrinks: state.totalStandardDrinks,
            durationSeconds: duration,
            pacingAdherence: adherence,
            finalWaterlineValue: state.waterlineValue
        )
    }
}
