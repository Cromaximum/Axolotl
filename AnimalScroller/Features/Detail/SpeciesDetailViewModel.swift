import Foundation
import Observation

/// State for the species detail sheet: loads content through the injected provider, picks the
/// hero image, and builds the facts and the sources list. The view only draws.
@Observable @MainActor
final class SpeciesDetailViewModel {
    enum Phase { case loading, loaded(SpeciesContent), failed }

    /// One line in the Sources section. `url` nil means plain text.
    struct Source: Identifiable, Hashable {
        let label: String
        let url: URL?
        var id: String { label }
    }

    let entry: SpeciesEntry
    private(set) var phase: Phase = .loading

    init(entry: SpeciesEntry) { self.entry = entry }

    var species: Species { entry.species }

    var content: SpeciesContent? {
        if case .loaded(let c) = phase { return c }
        return nil
    }

    var lineageText: String {
        entry.lineage.compactMap { $0.scientificName ?? $0.name }.joined(separator: " › ")
    }

    func load(using provider: any SpeciesContentProvider) async {
        if content != nil { return }
        phase = .loading
        do {
            let c = try await provider.content(for: species)
            guard !Task.isCancelled else { return }
            phase = .loaded(c)
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failed
        }
    }

    func hero(showArtwork: Bool) -> LicensedImage? {
        content.flatMap { HeroImage.pick(from: $0, species: species, allowArtwork: showArtwork) }
    }

    /// The headline "Did you know?" fact, then the rest.
    var headlineFact: String? { content?.facts.first?.text }
    var moreFacts: [String] { Array(content?.facts.dropFirst().map(\.text) ?? []) }

    /// Credits for every image this species may show under the artwork setting.
    func imageCredits(showArtwork: Bool) -> [LicensedImage] {
        content.map { HeroImage.usableImages($0, species: species, allowArtwork: showArtwork) } ?? []
    }

    /// Where the text, names and status came from, in reading order.
    var textSources: [Source] {
        Self.sources(for: species, content: content)
    }

    nonisolated static func sources(for species: Species, content: SpeciesContent?) -> [Source] {
        var out: [Source] = []
        if let content {
            out.append(Source(label: "Text: Wikipedia, \"\(content.title)\", CC BY-SA 4.0", url: content.pageURL))
        }
        if let key = species.gbifKey {
            out.append(Source(label: "Name and classification: GBIF Backbone Taxonomy, CC BY 4.0",
                              url: URL(string: "https://www.gbif.org/species/\(key)")))
            out.append(Source(label: "Conservation status: Wikidata (CC0), when listed. Otherwise shown as Unknown.",
                              url: nil))
        } else {
            out.append(Source(label: "Names, classification and conservation status: Wikidata (CC0) and Wikipedia",
                              url: nil))
        }
        return out
    }
}
