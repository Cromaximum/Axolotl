import SwiftUI

/// Filter screen built on the tree of life: kingdom › phylum › class › order › family.
/// Picking any branch limits the feed to species inside it. Search finds branches and species by
/// common or scientific name; a species hit picks the branch it sits in.
struct TaxonomyPickerView: View {
    @Environment(PreferencesStore.self) private var prefs
    @State private var model: TaxonomyPickerViewModel

    init(index: TaxonomyIndex) {
        _model = State(initialValue: TaxonomyPickerViewModel(index: index))
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            List {
                if model.isSearching {
                    SearchResultsSection(model: model)
                } else {
                    SelectionSummarySection(model: model)
                    OptionsSection()
                    Section {
                        OutlineGroup(model.topLevel, children: \.outlineChildren) { taxon in
                            TaxonRow(taxon: taxon, model: model)
                        }
                    } header: {
                        Text("Tree of life").accessibilityAddTraits(.isHeader)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.forest)
            .navigationTitle("Tree of life")
            .searchable(text: $model.query, prompt: "Search names, common or scientific")
            .autocorrectionDisabled()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") { prefs.reset() }
                        .disabled(prefs.showsEverything)
                        .accessibilityHint("Show species from the whole tree, living and extinct")
                }
            }
        }
    }
}

/// What the feed shows right now, with one-tap removal and "Reset to everything".
private struct SelectionSummarySection: View {
    let model: TaxonomyPickerViewModel
    @Environment(PreferencesStore.self) private var prefs

    var body: some View {
        let picked = model.summary(selection: prefs.selectedTaxonIDs)
        Section {
            if picked.isEmpty {
                Label("Everything in the tree", systemImage: "globe")
                    .foregroundStyle(Theme.parchment)
            } else {
                ForEach(picked) { taxon in
                    Button { prefs.toggle(taxon) } label: {
                        HStack {
                            Text(taxon.name).foregroundStyle(Theme.parchment)
                            Text("\(model.speciesCount(taxon.id))").foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(taxon.name), \(model.speciesCount(taxon.id)) species")
                    .accessibilityHint("Remove from your branches")
                }
            }
            if !prefs.showsEverything {
                Button("Reset to everything", systemImage: "arrow.counterclockwise") { prefs.reset() }
                    .foregroundStyle(Theme.amber)
            }
        } header: {
            Text("Showing").accessibilityAddTraits(.isHeader)
        } footer: {
            Text(model.coverageText(selection: prefs.selectedTaxonIDs, liveCatalog: prefs.liveCatalog))
        }
    }
}

private struct OptionsSection: View {
    @Environment(PreferencesStore.self) private var prefs

    var body: some View {
        @Bindable var prefs = prefs
        Section {
            Picker("Extinct species", selection: $prefs.extinctMode) {
                ForEach(PreferencesStore.ExtinctMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            if prefs.includeExtinct {
                Toggle("Show artist reconstructions", isOn: $prefs.showArtwork)
            }
            Toggle("Surprise picks", isOn: $prefs.surpriseMe)
            Toggle("Explore the full species catalogue", isOn: $prefs.liveCatalog)
        } footer: {
            Text("Extinct animals show fossils, specimens and photos, plus labelled reconstructions vetted on Wikipedia when that's on. Surprise picks mix in about 3 in 10 species from outside your branches. The full catalogue finds more species in your branches from the GBIF Backbone Taxonomy, keeping only ones with a well-illustrated Wikipedia article. Species you like steer which ones come next.")
        }
    }
}

private struct SearchResultsSection: View {
    let model: TaxonomyPickerViewModel
    @Environment(PreferencesStore.self) private var prefs

    var body: some View {
        Section {
            if model.results.isEmpty {
                Text("No branch or species by that name in the tree yet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(model.results) { hit in
                let state = model.state(of: hit.branchID, selection: prefs.selectedTaxonIDs)
                Button { model.toggle(hit.branchID, in: prefs) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hit.name).font(.body.weight(.semibold))
                            HStack(spacing: 6) {
                                if let sci = hit.scientificName { Text(sci).italic() }
                                Text(model.pathText(hit))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        }
                        Spacer()
                        SelectionIcon(state: state)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(state.isCovered)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(hit.accessibilityLabel(path: model.pathText(hit)))
                .accessibilityValue(state.accessibilityValue(model: model))
                .accessibilityAddTraits(.isButton)
            }
        } header: {
            Text("Results").accessibilityAddTraits(.isHeader)
        } footer: {
            Text("Tapping a species picks the branch it belongs to.")
        }
    }
}

private struct TaxonRow: View {
    let taxon: Taxon
    let model: TaxonomyPickerViewModel
    @Environment(PreferencesStore.self) private var prefs

    var body: some View {
        let state = model.state(of: taxon.id, selection: prefs.selectedTaxonIDs)
        let count = model.speciesCount(taxon.id)
        Button { prefs.toggle(taxon) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(taxon.name).font(.body.weight(.semibold))
                    HStack(spacing: 6) {
                        Text(taxon.rank.rawValue.capitalized)
                        if let sci = taxon.scientificName { Text(sci).italic() }
                        Text("· \(count) species")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                SelectionIcon(state: state)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(state.isCovered)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(taxon.name), \(taxon.rank.rawValue), \(count) species")
        .accessibilityValue(state.accessibilityValue(model: model))
        .accessibilityAddTraits(.isButton)
    }
}

private struct SelectionIcon: View {
    let state: TaxonomyIndex.SelectionState

    var body: some View {
        Image(systemName: name)
            .foregroundStyle(state == .unselected || state == .partial ? Color.secondary : Theme.amber)
            .font(.title3)
            .accessibilityHidden(true)
    }

    private var name: String {
        switch state {
        case .selected, .covered: "checkmark.circle.fill"
        case .partial: "minus.circle.fill"
        case .unselected: "circle"
        }
    }
}

private extension TaxonomyIndex.SelectionState {
    var isCovered: Bool {
        if case .covered = self { return true }
        return false
    }

    @MainActor func accessibilityValue(model: TaxonomyPickerViewModel) -> String {
        switch self {
        case .selected: "Selected"
        case .covered(let id): "Included by \(model.name(of: id))"
        case .partial: "Partly selected"
        case .unselected: "Not selected"
        }
    }
}

private extension TaxonomyIndex.SearchHit {
    func accessibilityLabel(path: String) -> String {
        [name, scientificName, path.isEmpty ? nil : "in \(path)"].compactMap { $0 }.joined(separator: ", ")
    }
}
