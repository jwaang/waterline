import SwiftUI

/// Subtle cloud icon indicating sync status.
/// Shows different states: synced, syncing, offline, error with pending count.
struct SyncStatusIndicator: View {
    let status: SyncStatus
    let pendingCount: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.caption2)
                .foregroundStyle(iconColor)
                .symbolEffect(.pulse, isActive: status == .syncing)

            if pendingCount > 0 && status != .syncing {
                Text("\(pendingCount)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var iconName: String {
        switch status {
        case .idle:
            return "checkmark.icloud"
        case .syncing:
            return "arrow.triangle.2.circlepath.icloud"
        case .offline:
            return "icloud.slash"
        case .error:
            return "exclamationmark.icloud"
        }
    }

    private var iconColor: Color {
        switch status {
        case .idle:
            return .secondary
        case .syncing:
            return .blue
        case .offline:
            return .secondary
        case .error:
            return .orange
        }
    }

    private var accessibilityText: String {
        switch status {
        case .idle:
            return "Synced"
        case .syncing:
            return "Syncing \(pendingCount) items"
        case .offline:
            return "Offline, \(pendingCount) items pending"
        case .error(let msg):
            return "Sync error: \(msg), \(pendingCount) items pending"
        }
    }
}
