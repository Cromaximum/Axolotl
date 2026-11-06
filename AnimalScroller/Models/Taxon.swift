import Foundation

/// A node in the animal-kingdom tree (kingdom → phylum → class → order → family).
/// Only *species* are ever shown in the feed; tree nodes exist purely for filtering.
struct Taxon: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let scientificName: String?
    let rank: Rank
    let children: [Taxon]?
    let species: [Species]?

    enum Rank: String, Codable, Hashable {
        case kingdom, phylum, `class`, order, family, genus
    }

    /// Children for `List(children:)`; nil marks a leaf so no disclosure arrow is drawn.
    var outlineChildren: [Taxon]? {
        guard let children, !children.isEmpty else { return nil }
        return children
    }
}

/// A specific species. This is the unit of content in the feed.
struct Species: Identifiable, Codable, Hashable {
    /// English Wikipedia article title, e.g. "Snow leopard".
    let wikiTitle: String
    let commonName: String
    let scientificName: String
    /// IUCN Red List category: LC, NT, VU, EN, CR, EW, EX, or DD/NE.
    let status: ConservationStatus
    /// GBIF Backbone key, set only for species that came from the live catalogue.
    var gbifKey: Int? = nil

    var id: String { wikiTitle }
    var isLive: Bool { gbifKey != nil }
    var isExtinct: Bool { status == .extinct }
}

enum ConservationStatus: String, Codable, Hashable, CaseIterable {
    case leastConcern = "LC"
    case nearThreatened = "NT"
    case vulnerable = "VU"
    case endangered = "EN"
    case criticallyEndangered = "CR"
    case extinctInWild = "EW"
    case extinct = "EX"
    case dataDeficient = "DD"
    case notEvaluated = "NE"

    var label: String {
        switch self {
        case .leastConcern: "Least Concern"
        case .nearThreatened: "Near Threatened"
        case .vulnerable: "Vulnerable"
        case .endangered: "Endangered"
        case .criticallyEndangered: "Critically Endangered"
        case .extinctInWild: "Extinct in the Wild"
        case .extinct: "Extinct"
        case .dataDeficient: "Data Deficient"
        case .notEvaluated: "Not Evaluated"
        }
    }

    /// The seven steps of the familiar zoo-sign status scale, LC → EX.
    static let scale: [ConservationStatus] = [
        .leastConcern, .nearThreatened, .vulnerable, .endangered,
        .criticallyEndangered, .extinctInWild, .extinct,
    ]
}

/// A species together with the path of tree nodes above it.
struct SpeciesEntry: Identifiable, Hashable {
    let species: Species
    /// Ancestor taxa from the root down, e.g. [Animals, Chordates, Mammals, Carnivorans, Cats].
    let lineage: [Taxon]

    var id: String { species.id }
    var lineageIDs: [String] { lineage.map(\.id) }
    var className: String? { lineage.first { $0.rank == .class }?.name }
    var orderName: String? { lineage.first { $0.rank == .order }?.name }
    var familyName: String? { lineage.first { $0.rank == .family }?.name }
}

extension Taxon {
    /// Every species under this node, each with its lineage.
    func allSpecies(ancestors: [Taxon] = []) -> [SpeciesEntry] {
        let path = ancestors + [self]
        let own = (species ?? []).map { SpeciesEntry(species: $0, lineage: path) }
        let nested = (children ?? []).flatMap { $0.allSpecies(ancestors: path) }
        return own + nested
    }

    /// Species covered by a selection. A selected node covers its whole subtree.
    /// An empty selection means "everything".
    func species(selectedIDs: Set<String>) -> [SpeciesEntry] {
        let all = allSpecies()
        guard !selectedIDs.isEmpty else { return all }
        return all.filter { !selectedIDs.isDisjoint(with: $0.lineageIDs) }
    }

    func contains(id: String) -> Bool {
        if self.id == id { return true }
        return children?.contains { $0.contains(id: id) } ?? false
    }

    /// Ids of all nodes beneath (not including) this one.
    var descendantIDs: Set<String> {
        Set((children ?? []).flatMap { [$0.id] + $0.descendantIDs })
    }
}

enum TaxonomyLoader {
    static func loadBundled() -> Taxon {
        guard let url = Bundle.main.url(forResource: "taxonomy", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONDecoder().decode(Taxon.self, from: data)
        else {
            fatalError("taxonomy.json is missing or malformed")
        }
        return root
    }
}
