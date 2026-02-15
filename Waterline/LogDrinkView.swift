import SwiftUI
import SwiftData

// MARK: - Size Preset Data

struct SizePreset: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let sizeOz: Double
    let standardDrinkEstimate: Double
}

enum DrinkSizePresets {
    static func presets(for type: DrinkType) -> [SizePreset] {
        switch type {
        case .beer:
            return [
                SizePreset(label: "12 oz", sizeOz: 12, standardDrinkEstimate: 1.0),
                SizePreset(label: "16 oz", sizeOz: 16, standardDrinkEstimate: 1.3),
                SizePreset(label: "Pint (20 oz)", sizeOz: 20, standardDrinkEstimate: 1.7),
            ]
        case .wine:
            return [
                SizePreset(label: "5 oz", sizeOz: 5, standardDrinkEstimate: 1.0),
                SizePreset(label: "Glass (6 oz)", sizeOz: 6, standardDrinkEstimate: 1.2),
            ]
        case .liquor:
            return [
                SizePreset(label: "1.5 oz", sizeOz: 1.5, standardDrinkEstimate: 1.0),
                SizePreset(label: "Double (3 oz)", sizeOz: 3, standardDrinkEstimate: 2.0),
            ]
        case .cocktail:
            return [
                SizePreset(label: "Standard", sizeOz: 6, standardDrinkEstimate: 1.0),
                SizePreset(label: "Strong", sizeOz: 6, standardDrinkEstimate: 1.5),
            ]
        }
    }
}

// MARK: - LogDrinkView

struct LogDrinkView: View {
    let session: Session
    let onLogged: (Double) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: DrinkType = .beer
    @State private var selectedPreset: SizePreset?
    @State private var adjustedEstimate: Double = 1.0

    private var presets: [SizePreset] {
        DrinkSizePresets.presets(for: selectedType)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                drinkTypePicker
                sizePresetPicker
                estimateAdjuster
                Spacer()
                confirmButton
            }
            .padding(24)
            .background(Color.wlBase)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("LOG DRINK")
                        .font(.wlHeadline)
                        .foregroundStyle(Color.wlInk)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.wlSecondary)
                }
            }
            .onChange(of: selectedType) {
                let first = presets.first
                selectedPreset = first
                adjustedEstimate = first?.standardDrinkEstimate ?? 1.0
            }
            .onAppear {
                let first = presets.first
                selectedPreset = first
                adjustedEstimate = first?.standardDrinkEstimate ?? 1.0
            }
        }
    }

    // MARK: - Drink Type Picker

    private var drinkTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TYPE")
                .wlTechnical()

            WLSegmentedPicker(
                options: DrinkType.allCases.map { ($0.displayName.uppercased(), $0) },
                selection: $selectedType
            )
        }
    }

    // MARK: - Size Preset Picker

    private var sizePresetPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SIZE")
                .wlTechnical()

            HStack(spacing: 8) {
                ForEach(presets) { preset in
                    Button {
                        selectedPreset = preset
                        adjustedEstimate = preset.standardDrinkEstimate
                    } label: {
                        VStack(spacing: 4) {
                            Text(preset.label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(selectedPreset?.id == preset.id ? Color.wlBase : Color.wlInk)
                            Text("\(preset.standardDrinkEstimate, specifier: "%.1f") std")
                                .font(.wlTechnicalMono)
                                .foregroundStyle(selectedPreset?.id == preset.id ? Color.wlBase.opacity(0.7) : Color.wlSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedPreset?.id == preset.id ? Color.wlInk : Color.clear)
                        .overlay(
                            Rectangle()
                                .strokeBorder(selectedPreset?.id == preset.id ? Color.clear : Color.wlTertiary, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(preset.label), \(preset.standardDrinkEstimate) standard drinks")
                }
            }
        }
    }

    // MARK: - Estimate Adjuster

    private var estimateAdjuster: some View {
        WLDoubleStepper(
            label: "STANDARD DRINK ESTIMATE",
            value: $adjustedEstimate,
            range: 0.5...5.0,
            step: 0.5
        )
    }

    // MARK: - Confirm

    private var confirmButton: some View {
        WLActionBlock(label: "+ Log Drink") {
            logDrink()
        }
        .opacity(selectedPreset == nil ? 0.4 : 1.0)
        .disabled(selectedPreset == nil)
    }

    private func logDrink() {
        guard let preset = selectedPreset else { return }

        let entry = LogEntry(
            timestamp: Date(),
            type: .alcohol,
            alcoholMeta: AlcoholMeta(
                drinkType: selectedType,
                sizeOz: preset.sizeOz,
                standardDrinkEstimate: adjustedEstimate
            ),
            source: .phone
        )
        entry.session = session
        modelContext.insert(entry)

        Task { try? modelContext.save() }

        onLogged(adjustedEstimate)
        dismiss()
    }
}

// MARK: - DrinkType Display

extension DrinkType {
    var displayName: String {
        switch self {
        case .beer: return "Beer"
        case .wine: return "Wine"
        case .liquor: return "Liquor"
        case .cocktail: return "Cocktail"
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Session.self, LogEntry.self, configurations: config)
    let session = Session()
    container.mainContext.insert(session)

    return LogDrinkView(session: session, onLogged: { _ in })
        .modelContainer(container)
}
