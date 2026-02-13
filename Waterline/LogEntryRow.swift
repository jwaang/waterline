import SwiftUI

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.type == .alcohol ? "wineglass" : "drop.fill")
                .foregroundStyle(entry.type == .alcohol ? .orange : .blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                if entry.type == .alcohol, let meta = entry.alcoholMeta {
                    Text(meta.drinkType.displayName)
                        .font(.subheadline.weight(.medium))
                    Text("\(meta.sizeOz, specifier: "%.0f") oz · \(meta.standardDrinkEstimate, specifier: "%.1f") std")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let meta = entry.waterMeta {
                    Text("Water")
                        .font(.subheadline.weight(.medium))
                    Text("\(Int(meta.amountOz)) oz")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(entry.timestamp, format: .dateTime.hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
