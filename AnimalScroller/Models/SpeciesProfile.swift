import Foundation

/// The short fact sheet on a species' intro board: where it lives, what it eats, how big it is
/// (Maxwell, 2026-11-06). Every row is a value from Wikidata or one verbatim sentence from the
/// species' English Wikipedia article (D-011); rows with no sourced data are simply absent.
struct SpeciesProfile: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Hashable, Sendable, CaseIterable {
        case livesIn, eats, length, height, wingspan, size, weight

        /// Row label (UI chrome, not animal content).
        var label: String {
            switch self {
            case .livesIn: "Lives in"
            case .eats: "Eats"
            case .length: "Length"
            case .height: "Height"
            case .wingspan: "Wingspan"
            case .size: "Size"
            case .weight: "Weight"
            }
        }

        var isSize: Bool { self == .length || self == .height || self == .wingspan || self == .size }
    }

    enum Source: String, Codable, Hashable, Sendable {
        /// A Wikidata statement (CC0), shown as its value or item labels.
        case wikidata
        /// One whole sentence copied from the species' Wikipedia article (CC BY-SA).
        case wikipedia
    }

    struct Row: Codable, Hashable, Sendable {
        let kind: Kind
        let text: String
        let source: Source
    }

    let rows: [Row]
    /// Wikidata item the values came from, for the credit line.
    let wikidataID: String?

    var usesWikidata: Bool { rows.contains { $0.source == .wikidata } }
}

extension Attribution {
    /// Credit for values taken from a Wikidata item (CC0).
    static func wikidata(itemID: String) -> Attribution {
        Attribution(
            title: "Wikidata \(itemID)",
            author: "Wikidata contributors",
            license: "CC0 1.0",
            licenseURL: URL(string: "https://creativecommons.org/publicdomain/zero/1.0/"),
            sourceURL: URL(string: "https://www.wikidata.org/wiki/\(itemID)")!
        )
    }
}
