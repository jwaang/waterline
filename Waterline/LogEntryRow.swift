import SwiftUI

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.type == .alcohol ? "ALC" : "H2O")
                .font(.wlTechnical)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Color.wlInk)
                .frame(width: 32, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                if entry.type == .alcohol, let meta = entry.alcoholMeta {
                    Text(meta.drinkType.displayName)
                        .font(.wlBody)
                        .foregroundStyle(Color.wlInk)
                    Text("\(meta.sizeOz, specifier: "%.0f") oz · \(meta.standardDrinkEstimate, specifier: "%.1f") std")
                        .font(.wlTechnicalMono)
                        .foregroundStyle(Color.wlSecondary)
                } else if let meta = entry.waterMeta {
                    Text("Water")
                        .font(.wlBody)
                        .foregroundStyle(Color.wlInk)
                    Text("\(Int(meta.amountOz)) oz")
                        .font(.wlTechnicalMono)
                        .foregroundStyle(Color.wlSecondary)
                }
            }

            Spacer()

            Text(entry.timestamp, format: .dateTime.hour().minute())
                .font(.wlTechnicalMono)
                .foregroundStyle(Color.wlSecondary)
        }
        .padding(.vertical, 2)
    }
}
