import SwiftUI

/// Filter screen built on the tree of life: kingdom › phylum › class › order › family.
/// Picking any branch limits the feed to species inside it.
struct TaxonomyPickerView: View {
    let root: Taxon
    @Environment(PreferencesStore.self) private var prefs
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var prefs = prefs
        NavigationStack {
            List {
                Section {
                    Toggle("Include extinct species", isOn: $prefs.includeExtinct)
                    if prefs.includeExtinct {
                        Toggle("Extinct species only", isOn: $prefs.extinctOnly)
                        Toggle("Show artist reconstructions", isOn: $prefs.showArtwork)
                    }
                    Toggle("Surprise me with other species", isOn: $prefs.surpriseMe)
                } footer: {
                    Text("Extinct animals show fossils, specimens and photos, plus labelled reconstructions vetted on Wikipedia when that's on. Surprise picks mix in about 3 in 10 species from outside your branches.")
                }

                Section {
                    OutlineGroup(root.outlineChildren ?? [], children: \.outlineChildren) { taxon in
                        TaxonRow(taxon: taxon, root: root)
                    }
                } header: {
                    Text("Tree of life")
                } footer: {
                    Text(prefs.selectedTaxonIDs.isEmpty
                         ? "Nothing picked: you'll see species from the whole animal kingdom."
                         : "\(root.species(selectedIDs: prefs.selectedTaxonIDs).count) species in your branches.")
                }
            }
            .navigationTitle("Choose animals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") { prefs.selectedTaxonIDs = [] }
                        .disabled(prefs.selectedTaxonIDs.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.bold()
                }
            }
        }
    }
}

private struct TaxonRow: View {
    let taxon: Taxon
    let root: Taxon
    @Environment(PreferencesStore.self) private var prefs

    private var isSelected: Bool { prefs.selectedTaxonIDs.contains(taxon.id) }
    /// Covered because a parent branch is selected.
    private var isInherited: Bool {
        !isSelected && prefs.selectedTaxonIDs.contains { id in
            id != taxon.id && root.find(id)?.contains(id: taxon.id) == true
        }
    }
    private var hasSelectedDescendant: Bool { !prefs.selectedTaxonIDs.isDisjoint(with: taxon.descendantIDs) }

    var body: some View {
        Button { prefs.toggle(taxon) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(taxon.name).font(.body.weight(.semibold))
                    HStack(spacing: 6) {
                        Text(taxon.rank.rawValue.capitalized)
                        if let sci = taxon.scientificName { Text(sci).italic() }
                        Text("· \(taxon.allSpecies().count) species")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: icon)
                    .foregroundStyle(isSelected || isInherited ? Theme.amber : .secondary)
                    .font(.title3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isInherited)
    }

    private var icon: String {
        if isSelected || isInherited { return "checkmark.circle.fill" }
        if hasSelectedDescendant { return "minus.circle.fill" }
        return "circle"
    }
}

extension Taxon {
    func find(_ id: String) -> Taxon? {
        if self.id == id { return self }
        for child in children ?? [] { if let hit = child.find(id) { return hit } }
        return nil
    }
}
