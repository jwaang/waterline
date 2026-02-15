import ActivityKit
import AppIntents
import SwiftData
import WidgetKit

struct EndSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "End Session"
    static let description = IntentDescription("End the active Waterline drinking session.")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isActive }
        )
        guard let session = try? context.fetch(descriptor).first else {
            return .result()
        }

        // End session
        session.endTime = Date()
        session.isActive = false
        session.needsSync = true

        // Compute summary
        let logs = session.logEntries.sorted(by: { $0.timestamp < $1.timestamp })
        var wl: Double = 0
        var dc = 0
        var wc = 0
        var totalStdDrinks: Double = 0
        var totalWaterOz: Double = 0
        var alcoholSinceLastWater = 0
        var waterOnTime = 0
        var waterOpportunities = 0

        let userDescriptor = FetchDescriptor<User>()
        let user = try? context.fetch(userDescriptor).first
        let waterEveryN = user?.settings.waterEveryNDrinks ?? 1

        for log in logs {
            if log.type == .alcohol, let meta = log.alcoholMeta {
                wl += meta.standardDrinkEstimate
                dc += 1
                totalStdDrinks += meta.standardDrinkEstimate
                alcoholSinceLastWater += 1
                if alcoholSinceLastWater >= waterEveryN {
                    waterOpportunities += 1
                }
            } else if log.type == .water {
                wl -= 1
                wc += 1
                if let meta = log.waterMeta {
                    totalWaterOz += meta.amountOz
                }
                if alcoholSinceLastWater >= waterEveryN {
                    waterOnTime += 1
                }
                alcoholSinceLastWater = 0
            }
        }

        let duration = (session.endTime ?? Date()).timeIntervalSince(session.startTime)
        let adherence = waterOpportunities > 0 ? Double(waterOnTime) / Double(waterOpportunities) : 1.0

        session.computedSummary = SessionSummary(
            totalDrinks: dc,
            totalWater: wc,
            totalStandardDrinks: totalStdDrinks,
            durationSeconds: duration,
            pacingAdherence: adherence,
            finalWaterlineValue: wl
        )

        try context.save()

        // End Live Activity with final state
        let threshold = user?.settings.warningThreshold ?? 2
        let finalState = SessionActivityAttributes.ContentState(
            waterlineValue: wl,
            drinkCount: dc,
            waterCount: wc,
            isWarning: wl >= Double(threshold)
        )
        let finalContent = ActivityContent(state: finalState, staleDate: nil)
        for activity in Activity<SessionActivityAttributes>.activities {
            await activity.end(finalContent, dismissalPolicy: .default)
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "WaterlineWidgets")

        return .result()
    }
}
