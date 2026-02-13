import SwiftUI
import SwiftData

struct AddEditPresetView: View {
    let existingPreset: DrinkPreset?
    let user: User?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var drinkType: DrinkType = .beer
    @State private var sizeOz: Double = 12
    @State private var abv: String = ""
    @State private var standardDrinkEstimate: Double = 1.0

    private var isEditing: Bool { existingPreset != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. My IPA", text: $name)
                }

                Section("Type") {
                    Picker("Drink Type", selection: $drinkType) {
                        ForEach(DrinkType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Size") {
                    HStack {
                        Text("Size (oz)")
                        Spacer()
                        TextField("oz", value: $sizeOz, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Section("ABV (optional)") {
                    TextField("e.g. 5.0", text: $abv)
                        .keyboardType(.decimalPad)
                }

                Section("Standard Drink Estimate") {
                    HStack(spacing: 16) {
                        Button {
                            standardDrinkEstimate = max(0.5, standardDrinkEstimate - 0.5)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Text("\(standardDrinkEstimate, specifier: "%.1f")")
                            .font(.title2.weight(.bold).monospacedDigit())
                            .frame(minWidth: 60)

                        Button {
                            standardDrinkEstimate = min(5.0, standardDrinkEstimate + 0.5)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(isEditing ? "Edit Preset" : "Add Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { savePreset() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let preset = existingPreset {
                    name = preset.name
                    drinkType = preset.drinkType
                    sizeOz = preset.sizeOz
                    if let existingAbv = preset.abv {
                        abv = String(format: "%.1f", existingAbv)
                    }
                    standardDrinkEstimate = preset.standardDrinkEstimate
                }
            }
        }
    }

    private func savePreset() {
        let parsedAbv = Double(abv)

        if let preset = existingPreset {
            preset.name = name.trimmingCharacters(in: .whitespaces)
            preset.drinkType = drinkType
            preset.sizeOz = sizeOz
            preset.abv = parsedAbv
            preset.standardDrinkEstimate = standardDrinkEstimate
        } else {
            let preset = DrinkPreset(
                name: name.trimmingCharacters(in: .whitespaces),
                drinkType: drinkType,
                sizeOz: sizeOz,
                abv: parsedAbv,
                standardDrinkEstimate: standardDrinkEstimate
            )
            preset.user = user
            modelContext.insert(preset)
        }

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddEditPresetView(existingPreset: nil, user: nil)
        .modelContainer(for: [User.self, DrinkPreset.self], inMemory: true)
}
