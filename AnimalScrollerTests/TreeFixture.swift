@testable import AnimalScroller

/// A small hand-made tree for index and collection tests. Test data only, never shown in the app.
enum TreeFixture {
    static func species(_ title: String, _ sci: String, _ status: ConservationStatus = .leastConcern) -> Species {
        Species(wikiTitle: title, commonName: title, scientificName: sci, status: status)
    }

    static let felidae = Taxon(id: "felidae", name: "Cats", scientificName: "Felidae", rank: .family, children: nil,
                               species: [species("Snow leopard", "Panthera uncia", .vulnerable),
                                         species("Smilodon fatalis", "Smilodon fatalis", .extinct)])
    static let canidae = Taxon(id: "canidae", name: "Dogs", scientificName: "Canidae", rank: .family, children: nil,
                               species: [species("Fennec fox", "Vulpes zerda")])
    static let carnivora = Taxon(id: "carnivora", name: "Carnivorans", scientificName: "Carnivora", rank: .order,
                                 children: [felidae, canidae], species: nil)
    static let mammalia = Taxon(id: "mammalia", name: "Mammals", scientificName: "Mammalia", rank: .class,
                                children: [carnivora], species: nil)
    static let ambystomatidae = Taxon(id: "ambystomatidae", name: "Mole salamanders", scientificName: "Ambystomatidae",
                                      rank: .family, children: nil,
                                      species: [species("Axolotl", "Ambystoma mexicanum", .criticallyEndangered)])
    static let amphibia = Taxon(id: "amphibia", name: "Amphibians", scientificName: "Amphibia", rank: .class,
                                children: [ambystomatidae], species: nil)
    static let root = Taxon(id: "animalia", name: "Animals", scientificName: "Animalia", rank: .kingdom,
                            children: [mammalia, amphibia], species: nil)
}
