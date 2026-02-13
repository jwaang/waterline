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
        List {
            Section {
                if presets.isEmpty {
                    Text("No presets yet. Add one to log drinks with a single tap.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(presets) { preset in
                        presetRow(preset)
                    }
                    .onDelete(perform: deletePresets)
                }
            } header: {
                Text("Quick Drinks")
            } footer: {
                Text("Presets appear on the active session screen for single-tap logging.")
            }
        }
        .navigationTitle("Presets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Preset")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddEditPresetView(existingPreset: nil, user: user)
        }
        .sheet(item: $presetToEdit) { preset in
            AddEditPresetView(existingPreset: preset, user: user)
        }
    }

    private func presetRow(_ preset: DrinkPreset) -> some View {
        Button {
            presetToEdit = preset
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        Text(preset.drinkType.displayName)
                        Text("\(preset.sizeOz, specifier: "%.0f") oz")
                        Text("\(preset.standardDrinkEstimate, specifier: "%.1f") std")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
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
