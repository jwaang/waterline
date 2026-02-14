import ActivityKit
import SwiftUI
import WidgetKit

struct SessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            // Lock Screen / notification banner Live Activity view
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.leading) {
                    expandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    expandedCenter(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom()
                }
            } compactLeading: {
                // Compact: left side of Dynamic Island
                Image(systemName: "drop.fill")
                    .foregroundStyle(context.state.isWarning ? .red : .blue)
                    .font(.caption)
            } compactTrailing: {
                // Compact: right side of Dynamic Island
                Text(String(format: "%.1f", context.state.waterlineValue))
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(context.state.isWarning ? .red : .primary)
            } minimal: {
                // Minimal: single element when multiple Live Activities exist
                Image(systemName: "drop.fill")
                    .foregroundStyle(context.state.isWarning ? .red : .blue)
            }
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<SessionActivityAttributes>) -> some View {
        HStack(spacing: 16) {
            // Waterline value
            VStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(.title3)
                    .foregroundStyle(context.state.isWarning ? .red : .blue)
                Text(String(format: "%.1f", context.state.waterlineValue))
                    .font(.system(.title2, design: .rounded).bold().monospacedDigit())
                    .foregroundStyle(context.state.isWarning ? .red : .primary)
            }

            // Counts
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Label("\(context.state.drinkCount)", systemImage: "wineglass")
                        .font(.subheadline.weight(.medium))
                    Label("\(context.state.waterCount)", systemImage: "drop.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.blue)
                }

                // Session duration
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(context.attributes.startTime, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Quick-add buttons
            VStack(spacing: 6) {
                Button(intent: LogDrinkIntent()) {
                    Image(systemName: "wineglass")
                        .font(.caption.bold())
                        .frame(width: 36, height: 28)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button(intent: LogWaterIntent()) {
                    Image(systemName: "drop.fill")
                        .font(.caption.bold())
                        .frame(width: 36, height: 28)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
        }
        .padding(16)
        .activityBackgroundTint(.black.opacity(0.7))
    }

    // MARK: - Dynamic Island Expanded

    @ViewBuilder
    private func expandedLeading(context: ActivityViewContext<SessionActivityAttributes>) -> some View {
        VStack(spacing: 2) {
            Image(systemName: "drop.fill")
                .foregroundStyle(context.state.isWarning ? .red : .blue)
            Text(String(format: "%.1f", context.state.waterlineValue))
                .font(.system(.title3, design: .rounded).bold().monospacedDigit())
                .foregroundStyle(context.state.isWarning ? .red : .primary)
        }
    }

    @ViewBuilder
    private func expandedTrailing(context: ActivityViewContext<SessionActivityAttributes>) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Label("\(context.state.drinkCount)", systemImage: "wineglass")
                .font(.caption.weight(.medium))
            Label("\(context.state.waterCount)", systemImage: "drop.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.blue)
        }
    }

    @ViewBuilder
    private func expandedCenter(context: ActivityViewContext<SessionActivityAttributes>) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.caption2)
            Text(context.attributes.startTime, style: .relative)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func expandedBottom() -> some View {
        HStack(spacing: 12) {
            Button(intent: LogDrinkIntent()) {
                Label("Drink", systemImage: "plus")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            Button(intent: LogWaterIntent()) {
                Label("Water", systemImage: "plus")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
    }
}
