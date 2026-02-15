import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Live Activity Design Tokens

private extension Color {
    static let wlLAInk = Color.white
    static let wlLASecondary = Color.secondary
    static let wlLAWarning = Color(red: 0.75, green: 0.22, blue: 0.17)
    static let wlLAButton = Color(white: 0.45)
}

struct SessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
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
                Text("WL")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(context.state.isWarning ? Color.wlLAWarning : Color.wlLAInk)
            } compactTrailing: {
                Text(String(format: "%.1f", context.state.waterlineValue))
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(context.state.isWarning ? Color.wlLAWarning : Color.wlLAInk)
            } minimal: {
                Text(String(format: "%.0f", context.state.waterlineValue))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(context.state.isWarning ? Color.wlLAWarning : Color.wlLAInk)
            }
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<SessionActivityAttributes>) -> some View {
        HStack(spacing: 16) {
            // Waterline value
            VStack(spacing: 2) {
                Text("WATERLINE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.wlLASecondary)
                Text(String(format: "%.1f", context.state.waterlineValue))
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(context.state.isWarning ? Color.wlLAWarning : Color.wlLAInk)
            }

            // Separator
            Rectangle()
                .fill(Color.wlLASecondary.opacity(0.3))
                .frame(width: 1, height: 40)

            // Counts
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("\(context.state.drinkCount)")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                        Text("DRINKS")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.wlLASecondary)
                    }
                    Text("/")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.wlLASecondary)
                    HStack(spacing: 4) {
                        Text("\(context.state.waterCount)")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                        Text("WATER")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.wlLASecondary)
                    }
                }

                Text(context.attributes.startTime, style: .relative)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.wlLASecondary)
            }

            Spacer()

            // Quick-add buttons
            VStack(spacing: 6) {
                Button(intent: LogDrinkIntent()) {
                    Text("+ DRINK")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 56, height: 28)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.wlLAButton)

                Button(intent: LogWaterIntent()) {
                    Text("+ WATER")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 56, height: 28)
                }
                .buttonStyle(.bordered)
                .tint(Color.wlLAButton)
            }
        }
        .padding(16)
        .activityBackgroundTint(.black.opacity(0.7))
    }

    // MARK: - Dynamic Island Expanded

    @ViewBuilder
    private func expandedLeading(context: ActivityViewContext<SessionActivityAttributes>) -> some View {
        VStack(spacing: 2) {
            Text("WATERLINE")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.wlLASecondary)
            Text(String(format: "%.1f", context.state.waterlineValue))
                .font(.system(.title3, design: .monospaced).bold())
                .foregroundStyle(context.state.isWarning ? Color.wlLAWarning : Color.wlLAInk)
        }
    }

    @ViewBuilder
    private func expandedTrailing(context: ActivityViewContext<SessionActivityAttributes>) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(context.state.drinkCount) DRINKS")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
            Text("\(context.state.waterCount) WATER")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.wlLASecondary)
        }
    }

    @ViewBuilder
    private func expandedCenter(context: ActivityViewContext<SessionActivityAttributes>) -> some View {
        Text(context.attributes.startTime, style: .relative)
            .font(.caption)
            .foregroundStyle(Color.wlLASecondary)
    }

    @ViewBuilder
    private func expandedBottom() -> some View {
        HStack(spacing: 12) {
            Button(intent: LogDrinkIntent()) {
                Text("+ Drink")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.wlLAButton)

            Button(intent: LogWaterIntent()) {
                Text("+ Water")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.wlLAButton)
        }
    }
}
