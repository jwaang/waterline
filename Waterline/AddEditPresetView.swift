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
            ScrollView {
                VStack(spacing: 24) {
                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NAME")
                            .wlTechnical()
                        TextField("e.g. My IPA", text: $name)
                            .font(.wlBody)
                            .foregroundStyle(Color.wlInk)
                            .padding(.vertical, 10)
                            .overlay(alignment: .bottom) {
                                WLRule()
                            }
                    }

                    // Type
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TYPE")
                            .wlTechnical()
                        WLSegmentedPicker(
                            options: DrinkType.allCases.map { ($0.displayName.uppercased(), $0) },
                            selection: $drinkType
                        )
                    }

                    // Size
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SIZE (OZ)")
                            .wlTechnical()
                        HStack {
                            TextField("oz", value: $sizeOz, format: .number)
                                .font(.wlNumeral)
                                .foregroundStyle(Color.wlInk)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .overlay(
                                    Rectangle()
                                        .strokeBorder(Color.wlTertiary, lineWidth: 1)
                                )
                        }
                    }

                    // ABV
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ABV (OPTIONAL)")
                            .wlTechnical()
                        TextField("e.g. 5.0", text: $abv)
                            .font(.wlBody)
                            .foregroundStyle(Color.wlInk)
                            .keyboardType(.decimalPad)
                            .padding(.vertical, 10)
                            .overlay(alignment: .bottom) {
                                WLRule()
                            }
                    }

                    // Standard Drink Estimate
                    WLDoubleStepper(
                        label: "STANDARD DRINK ESTIMATE",
                        value: $standardDrinkEstimate,
                        range: 0.5...5.0,
                        step: 0.5
                    )

                    Spacer()

                    WLActionBlock(label: "Save") {
                        savePreset()
                    }
                    .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1.0)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(24)
            }
            .background(Color.wlBase)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(isEditing ? "EDIT PRESET" : "ADD PRESET")
                        .font(.wlHeadline)
                        .foregroundStyle(Color.wlInk)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.wlSecondary)
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
