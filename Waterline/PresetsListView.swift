import SwiftUI
import SwiftData

struct PresetsListView: View {
    @Query private var presets: [DrinkPreset]
    @Query private var users: [User]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddSheet = false
    @State private var presetToEdit: DrinkPreset?

    private var user: User? { users.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                WLSectionHeader(title: "QUICK DRINKS")

                if presets.isEmpty {
                    VStack(spacing: 8) {
                        Text("NO PRESETS CONFIGURED")
                            .wlTechnical()
                        Text("Add one to log drinks with a single tap.")
                            .font(.wlBody)
                            .foregroundStyle(Color.wlSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    ForEach(presets) { preset in
                        presetRow(preset)

                        if preset.id != presets.last?.id {
                            WLRule()
                                .padding(.leading, WLSpacing.screenMargin)
                        }
                    }
                }

                Text("PRESETS APPEAR ON THE ACTIVE SESSION SCREEN")
                    .wlTechnical()
                    .foregroundStyle(Color.wlSecondary)
                    .padding(.horizontal, WLSpacing.screenMargin)
                    .padding(.vertical, 12)
            }
        }
        .background(Color.wlBase)
        .wlScreen()
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("PRESETS")
                    .font(.wlHeadline)
                    .foregroundStyle(Color.wlInk)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Text("+")
                        .font(.wlControl)
                        .foregroundStyle(Color.wlInk)
                }
                .accessibilityLabel("Add Preset")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddEditPresetView(existingPreset: nil, user: user)
                .presentationCornerRadius(0)
        }
        .sheet(item: $presetToEdit) { preset in
            AddEditPresetView(existingPreset: preset, user: user)
                .presentationCornerRadius(0)
        }
    }

    private func presetRow(_ preset: DrinkPreset) -> some View {
        Button {
            presetToEdit = preset
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(.wlBody)
                        .foregroundStyle(Color.wlInk)
                    HStack(spacing: 8) {
                        Text(preset.drinkType.displayName.uppercased())
                        Text("\(preset.sizeOz, specifier: "%.0f") OZ")
                        Text("\(preset.standardDrinkEstimate, specifier: "%.1f") STD")
                    }
                    .font(.wlTechnicalMono)
                    .foregroundStyle(Color.wlSecondary)
                }
                Spacer()
                Text(">>")
                    .font(.wlTechnicalMono)
                    .foregroundStyle(Color.wlTertiary)
            }
            .padding(.horizontal, WLSpacing.screenMargin)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func deletePresets(at offsets: IndexSet) {
        for index in offsets {
            let preset = presets[index]
            modelContext.delete(preset)
        }
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        PresetsListView()
            .modelContainer(for: [User.self, DrinkPreset.self], inMemory: true)
    }
}
