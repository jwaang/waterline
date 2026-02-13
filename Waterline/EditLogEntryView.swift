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
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
            Text("Type")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Picker("Drink Type", selection: $selectedType) {
                ForEach(DrinkType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var sizePresetPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Size")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(presets) { preset in
                    Button {
                        selectedPreset = preset
                        adjustedEstimate = preset.standardDrinkEstimate
                    } label: {
                        VStack(spacing: 4) {
                            Text(preset.label)
                                .font(.subheadline.weight(.medium))
                            Text("\(preset.standardDrinkEstimate, specifier: "%.1f") std")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedPreset?.id == preset.id
                                      ? Color.accentColor.opacity(0.15)
                                      : Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(selectedPreset?.id == preset.id
                                              ? Color.accentColor
                                              : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var estimateAdjuster: some View {
        VStack(spacing: 8) {
            Text("Standard Drink Estimate")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button {
                    adjustedEstimate = max(0.5, adjustedEstimate - 0.5)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                Text("\(adjustedEstimate, specifier: "%.1f")")
                    .font(.title.weight(.bold).monospacedDigit())
                    .frame(minWidth: 60)

                Button {
                    adjustedEstimate = min(5.0, adjustedEstimate + 0.5)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Water Editor

    private var waterEditor: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Amount (oz)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    Button {
                        waterAmountOz = max(1, waterAmountOz - 1)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }

                    Text("\(Int(waterAmountOz)) oz")
                        .font(.title.weight(.bold).monospacedDigit())
                        .frame(minWidth: 80)

                    Button {
                        waterAmountOz = min(32, waterAmountOz + 1)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
            saveButton
        }
        .padding(24)
    }

    // MARK: - Save

    private var saveButton: some View {
        Button {
            saveChanges()
        } label: {
            Label("Save Changes", systemImage: "checkmark")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
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
            // Find matching size preset
            let matchingPreset = presets.first { $0.sizeOz == meta.sizeOz }
            selectedPreset = matchingPreset ?? presets.first
        }
        if let meta = entry.waterMeta {
            waterAmountOz = meta.amountOz
        }
    }
}
