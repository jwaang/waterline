import SwiftUI
import SwiftData

struct EditLogEntryView: View {
    let entry: LogEntry

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: DrinkType = .beer
    @State private var selectedPreset: SizePreset?
    @State private var adjustedEstimate: Double = 1.0
    @State private var waterAmountOz: Double = 8.0

    private var isAlcohol: Bool { entry.type == .alcohol }

    private var presets: [SizePreset] {
        DrinkSizePresets.presets(for: selectedType)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isAlcohol {
                    alcoholEditor
                } else {
                    waterEditor
                }
            }
            .background(Color.wlBase)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("EDIT ENTRY")
                        .font(.wlHeadline)
                        .foregroundStyle(Color.wlInk)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.wlSecondary)
                }
            }
            .onAppear {
                loadEntryData()
            }
        }
    }

    // MARK: - Alcohol Editor

    private var alcoholEditor: some View {
        VStack(spacing: 24) {
            drinkTypePicker
            sizePresetPicker
            estimateAdjuster
            Spacer()
            saveButton
        }
        .padding(24)
    }

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
                }
            }
        }
    }

    private var estimateAdjuster: some View {
        WLDoubleStepper(
            label: "STANDARD DRINK ESTIMATE",
            value: $adjustedEstimate,
            range: 0.5...5.0,
            step: 0.5
        )
    }

    // MARK: - Water Editor

    private var waterEditor: some View {
        VStack(spacing: 24) {
            WLDoubleStepper(
                label: "AMOUNT (OZ)",
                value: $waterAmountOz,
                range: 1...32,
                step: 1,
                format: "%.0f",
                displaySuffix: " oz"
            )

            Spacer()
            saveButton
        }
        .padding(24)
    }

    // MARK: - Save

    private var saveButton: some View {
        WLActionBlock(label: "Save") {
            saveChanges()
        }
    }

    private func saveChanges() {
        if isAlcohol {
            entry.alcoholMeta = AlcoholMeta(
                drinkType: selectedType,
                sizeOz: selectedPreset?.sizeOz ?? entry.alcoholMeta?.sizeOz ?? 0,
                abv: entry.alcoholMeta?.abv,
                standardDrinkEstimate: adjustedEstimate,
                presetId: entry.alcoholMeta?.presetId
            )
        } else {
            entry.waterMeta = WaterMeta(amountOz: waterAmountOz)
        }

        try? modelContext.save()
        dismiss()
    }

    // MARK: - Load

    private func loadEntryData() {
        if let meta = entry.alcoholMeta {
            selectedType = meta.drinkType
            adjustedEstimate = meta.standardDrinkEstimate
            let matchingPreset = presets.first { $0.sizeOz == meta.sizeOz }
            selectedPreset = matchingPreset ?? presets.first
        }
        if let meta = entry.waterMeta {
            waterAmountOz = meta.amountOz
        }
    }
}
