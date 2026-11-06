import SwiftUI

/// First run: a welcome screen, then "Where should we start?" photo tiles.
/// The full tree of life stays on the Tree tab; these tiles are a quick way in.
struct OnboardingView: View {
    @Environment(PreferencesStore.self) private var prefs
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model: OnboardingViewModel

    init(index: TaxonomyIndex, provider: any SpeciesContentProvider) {
        _model = State(initialValue: OnboardingViewModel(index: index, provider: provider))
    }

    var body: some View {
        ZStack {
            if model.step == 0 {
                WelcomeView(model: model) {
                    if reduceMotion { model.step = 1 } else { withAnimation { model.step = 1 } }
                }
                .transition(.opacity)
            } else {
                StartingPointView(model: model) { model.finish(into: prefs) }
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing))
            }
        }
        .background(Theme.forest)
        .task { await model.loadHeroes() }
    }
}

/// One photo tile on the starting-point screen.
enum StartingPoint: String, CaseIterable, Identifiable, Hashable {
    case mammals, birds, reptiles, amphibians, insects, crustaceans, fossils, surprise

    var id: String { rawValue }

    /// Tile name. Animal-group names come from the taxonomy (D-011); only the two non-branch
    /// tiles have UI labels.
    func title(in index: TaxonomyIndex) -> String {
        switch self {
        case .fossils: "Fossil life"
        case .surprise: "Surprise me"
        default: taxonID.flatMap { index.node($0)?.name } ?? ""
        }
    }

    func subtitle(in index: TaxonomyIndex) -> String {
        switch self {
        case .fossils: "Extinct species"
        case .surprise: "Anything goes"
        default: taxonID.flatMap { index.node($0)?.scientificName } ?? ""
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
        case .fossils: "Woolly mammoth"
        case .surprise: "Okapi"
        }
    }
}

struct WelcomeView: View {
    let model: OnboardingViewModel
    let onStart: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let hero = model.welcomeHero { FullBleedImage(image: hero, wideCenter: 0.5) } else { ShimmerFill() }
            }
            .ignoresSafeArea()
            LowerThirdScrim().ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                if let hero = model.welcomeHero {
                    CreditChip(attribution: hero.attribution)
                }
                Text("WELCOME").font(Theme.label(12)).tracking(1.5).foregroundStyle(Theme.amber)
                Text("Meet a new species every swipe.")
                    .font(Theme.heading(40))
                    .foregroundStyle(Theme.parchment)
                    .accessibilityAddTraits(.isHeader)
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
    let model: OnboardingViewModel
    let onContinue: () -> Void
    @State private var showingCredits = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Step 1 of 2").font(Theme.body(12)).foregroundStyle(Theme.mist)
            Text("Where should we start?").font(Theme.heading(30)).foregroundStyle(Theme.parchment)
                .accessibilityAddTraits(.isHeader)
            Text("Pick a few branches. You can change this any time on the Tree tab, and we'll still surprise you now and then.")
                .font(Theme.body(14)).foregroundStyle(Theme.mist)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                    ForEach(StartingPoint.allCases) { point in
                        Button { model.toggle(point) } label: {
                            StartingPointTile(point: point, model: model, selected: model.picked.contains(point))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button("Photo credits") { showingCredits = true }
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.mist)
                    .frame(minHeight: 44)
                    .disabled(model.credits.isEmpty)
            }
            Button(action: onContinue) {
                Text(model.picked.isEmpty ? "Continue · show me everything" : "Continue · \(model.picked.count) picked")
                    .font(Theme.label(17))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Theme.amber, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Theme.ink)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Theme.forest)
        .sheet(isPresented: $showingCredits) { PhotoCreditsList(images: model.credits) }
    }
}

private struct StartingPointTile: View {
    let point: StartingPoint
    let model: OnboardingViewModel
    let selected: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let species = model.species(for: point.photoSpecies) {
                SpeciesThumbnail(species: species)
            } else {
                Theme.boardGreen
            }
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text(point.title(in: model.index)).font(Theme.heading(18)).foregroundStyle(Theme.parchment)
                Text(point.subtitle(in: model.index)).font(Theme.body(11)).foregroundStyle(Theme.mist)
            }
            .padding(10)
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(selected ? Theme.amber : Theme.parchment)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 120)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? Theme.amber : .clear, lineWidth: 3))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Author, licence and source for each onboarding photo (non-negotiable rule 3).
private struct PhotoCreditsList: View {
    let images: [LicensedImage]

    var body: some View {
        NavigationStack {
            List(images) { image in
                CreditChip(attribution: image.attribution)
                    .listRowBackground(Theme.forest)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.forest)
            .navigationTitle("Photo credits")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}
