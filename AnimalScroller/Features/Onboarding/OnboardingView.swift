import SwiftUI

/// First run: a welcome screen, then "Where should we start?" photo tiles.
/// The full tree of life stays on the Tree tab; these tiles are a quick way in.
struct OnboardingView: View {
    let taxonomy: Taxon
    @Environment(PreferencesStore.self) private var prefs
    @State private var step = 0

    var body: some View {
        ZStack {
            if step == 0 {
                WelcomeView(taxonomy: taxonomy) { withAnimation { step = 1 } }
                    .transition(.opacity)
            } else {
                StartingPointView(taxonomy: taxonomy) { picks in
                    apply(picks)
                    prefs.hasOnboarded = true
                }
                .transition(.move(edge: .trailing))
            }
        }
        .background(Theme.forest)
    }

    private func apply(_ picks: Set<StartingPoint>) {
        let branches = picks.compactMap(\.taxonID)
        let wantsFossils = picks.contains(.fossils)
        prefs.selectedTaxonIDs = Set(branches)
        prefs.includeExtinct = true
        // Only "Fossil life" picked: show extinct species from the whole tree.
        prefs.extinctOnly = wantsFossils && branches.isEmpty && !picks.contains(.surprise)
        prefs.surpriseMe = true
    }
}

/// One photo tile on the starting-point screen.
enum StartingPoint: String, CaseIterable, Identifiable, Hashable {
    case mammals, birds, reptiles, amphibians, insects, crustaceans, fossils, surprise

    var id: String { rawValue }

    /// Tile name. Animal-group names come from the taxonomy (D-011); only the two non-branch
    /// tiles have UI labels.
    func title(in taxonomy: Taxon) -> String {
        switch self {
        case .fossils: "Fossil life"
        case .surprise: "Surprise me"
        default: taxonID.flatMap { taxonomy.find($0)?.name } ?? ""
        }
    }

    func subtitle(in taxonomy: Taxon) -> String {
        switch self {
        case .fossils: "Extinct species"
        case .surprise: "Anything goes"
        default: taxonID.flatMap { taxonomy.find($0)?.scientificName } ?? ""
        }
    }

    /// Branch of the tree this tile selects. nil means "not a branch" (fossils, surprise).
    var taxonID: String? {
        switch self {
        case .mammals: "mammalia"
        case .birds: "aves"
        case .reptiles: "reptilia"
        case .amphibians: "amphibia"
        case .insects: "insecta"
        case .crustaceans: "malacostraca"
        case .fossils, .surprise: nil
        }
    }

    /// Species whose licensed lead photo illustrates the tile.
    var photoSpecies: String {
        switch self {
        case .mammals: "Snow leopard"
        case .birds: "Shoebill"
        case .reptiles: "Komodo dragon"
        case .amphibians: "Axolotl"
        case .insects: "Hymenopus coronatus"
        case .crustaceans: "Odontodactylus scyllarus"
        case .fossils: "Smilodon"
        case .surprise: "Okapi"
        }
    }
}

/// Loads the licensed hero photo for a species from the shared content cache.
struct SpeciesPhoto: View {
    let wikiTitle: String
    let taxonomy: Taxon
    var allowArtwork = false
    @State private var image: LicensedImage?

    var body: some View {
        ZStack {
            if let image { FullBleedImage(image: image, wideCenter: 0.5) } else { Theme.boardGreen }
        }
        .task(id: wikiTitle) {
            guard let entry = taxonomy.allSpecies().first(where: { $0.id == wikiTitle }),
                  let content = try? await WikipediaContentProvider.shared.content(for: entry.species)
            else { return }
            let usable = content.images.filter { allowArtwork || !$0.isArtwork }
            image = usable.first { $0.fileTitle == content.leadImageFileTitle } ?? usable.first
        }
    }
}

struct WelcomeView: View {
    let taxonomy: Taxon
    let onStart: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            SpeciesPhoto(wikiTitle: "Shoebill", taxonomy: taxonomy)
                .ignoresSafeArea()
            LowerThirdScrim().ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text("WELCOME").font(Theme.label(12)).tracking(1.5).foregroundStyle(Theme.amber)
                Text("Meet a new species every swipe.")
                    .font(Theme.heading(40))
                    .foregroundStyle(Theme.parchment)
                Text("Real photos and Wikipedia facts, from every branch of the tree of life.")
                    .font(Theme.body(16))
                    .foregroundStyle(Theme.parchment.opacity(0.9))
                Button(action: onStart) {
                    Text("Start exploring")
                        .font(Theme.label(17))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Theme.amber, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(Theme.ink)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(20)
            .padding(.bottom, 8)
        }
    }
}

struct StartingPointView: View {
    let taxonomy: Taxon
    let onContinue: (Set<StartingPoint>) -> Void
    @State private var picked: Set<StartingPoint> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Step 1 of 2").font(Theme.body(12)).foregroundStyle(Theme.mist)
            Text("Where should we start?").font(Theme.heading(30)).foregroundStyle(Theme.parchment)
            Text("Pick a few branches. You can change this any time on the Tree tab, and we'll still surprise you now and then.")
                .font(Theme.body(14)).foregroundStyle(Theme.mist)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                    ForEach(StartingPoint.allCases) { point in
                        Button { toggle(point) } label: { tile(point) }
                            .buttonStyle(.plain)
                    }
                }
            }
            Button { onContinue(picked) } label: {
                Text(picked.isEmpty ? "Continue · show me everything" : "Continue · \(picked.count) picked")
                    .font(Theme.label(17))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Theme.amber, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Theme.ink)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Theme.forest)
    }

    private func toggle(_ point: StartingPoint) {
        if picked.contains(point) { picked.remove(point) } else { picked.insert(point) }
    }

    private func tile(_ point: StartingPoint) -> some View {
        let selected = picked.contains(point)
        return ZStack(alignment: .bottomLeading) {
            SpeciesPhoto(wikiTitle: point.photoSpecies, taxonomy: taxonomy)
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text(point.title(in: taxonomy)).font(Theme.heading(18)).foregroundStyle(Theme.parchment)
                Text(point.subtitle(in: taxonomy)).font(Theme.body(11)).foregroundStyle(Theme.mist)
            }
            .padding(10)
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(selected ? Theme.amber : Theme.parchment)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? Theme.amber : .clear, lineWidth: 3))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
