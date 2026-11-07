import Foundation

/// Builds the intro fact sheet (`SpeciesProfile`) from Wikidata statements, falling back to one
/// short verbatim sentence from the matching Wikipedia section when Wikidata has nothing
/// (Maxwell approved the fallback, 2026-11-06). Pure: `WikidataClient` fetches the input.
/// Never rewrites a value or sentence (D-011): it only picks, orders and joins them.
enum SpeciesProfileBuilder {

    /// One Wikidata statement, reduced to what the profile needs.
    struct Claim: Hashable, Sendable {
        var itemID: String? = nil
        /// Wikidata quantity amount as sent, e.g. "+32.5".
        var amount: String? = nil
        /// Unit item id, e.g. "Q11570" (kilogram).
        var unitID: String? = nil
        /// Values of the "object has role" qualifier (P3831), e.g. newborn or adult male.
        var roleIDs: [String] = []
        var rank: String = "normal"
    }

    struct Input: Sendable {
        var wikidataID: String?
        /// Statements by property id.
        var claims: [String: [Claim]]
        /// English labels of the items the statements point to.
        var labels: [String: String]
    }

    static let rangeProperties = ["P9714", "P183"]       // taxon range, endemic to
    static let dietProperty = "P1034"                     // main food source
    static let sizeProperties: [(String, SpeciesProfile.Kind)] = [
        ("P2043", .length), ("P2048", .height), ("P2050", .wingspan),
    ]
    static let massProperty = "P2067"
    /// Every property `WikidataClient` should fetch.
    static var properties: [String] {
        rangeProperties + [dietProperty] + sizeProperties.map(\.0) + [massProperty]
    }

    /// Places or foods shown per row, so the sheet stays short.
    static let maxListItems = 3
    /// Longest fallback sentence, so a row never turns into a paragraph.
    static let maxSentenceLength = 90

    /// Unit symbols (UI formatting of Wikidata units, not animal content).
    static let unitSymbols: [String: String] = [
        "Q11570": "kg", "Q41803": "g", "Q191118": "t", "Q100995": "lb", "Q48013": "oz",
        "Q11573": "m", "Q174728": "cm", "Q174789": "mm", "Q828224": "km", "Q3710": "ft",
        "Q218593": "in",
    ]
    static let massUnits: Set<String> = ["Q11570", "Q41803", "Q191118", "Q100995", "Q48013"]
    static let lengthUnits: Set<String> = ["Q11573", "Q174728", "Q174789", "Q828224", "Q3710", "Q218593"]

    /// Role labels that mark a value as not describing a grown animal.
    private static let notAdultWords = [
        "newborn", "birth", "juvenile", "infant", "young", "egg", "larva", "chick", "hatchling",
        "neonate", "calf", "cub", "pup", "foal", "fledgling",
    ]

    static func profile(input: Input?, article: String) -> SpeciesProfile? {
        var rows: [SpeciesProfile.Row] = []
        if let input {
            if let text = itemList(rangeProperties, input) { rows.append(.init(kind: .livesIn, text: text, source: .wikidata)) }
            if let text = itemList([dietProperty], input) { rows.append(.init(kind: .eats, text: text, source: .wikidata)) }
            for (property, kind) in sizeProperties {
                if let text = quantity(property, units: lengthUnits, input) {
                    rows.append(.init(kind: kind, text: text, source: .wikidata))
                    break
                }
            }
            if let text = quantity(massProperty, units: massUnits, input) {
                rows.append(.init(kind: .weight, text: text, source: .wikidata))
            }
        }
        rows += fallbackRows(missing: rows, article: article)
        guard !rows.isEmpty else { return nil }
        let order = SpeciesProfile.Kind.allCases
        let sorted = rows.sorted { order.firstIndex(of: $0.kind)! < order.firstIndex(of: $1.kind)! }
        return SpeciesProfile(rows: sorted, wikidataID: input?.wikidataID)
    }

    // MARK: Wikidata values

    /// Statements to use: preferred ones if any, otherwise normal ones; never deprecated.
    static func usable(_ claims: [Claim]) -> [Claim] {
        let preferred = claims.filter { $0.rank == "preferred" }
        return preferred.isEmpty ? claims.filter { $0.rank != "deprecated" } : preferred
    }

    /// Labels of the first property that has labelled items, at most `maxListItems`, in order.
    static func itemList(_ properties: [String], _ input: Input) -> String? {
        for property in properties {
            var seen = Set<String>()
            let names = usable(input.claims[property] ?? [])
                .compactMap { $0.itemID.flatMap { input.labels[$0] } }
                .filter { seen.insert($0).inserted }
            if !names.isEmpty { return names.prefix(maxListItems).joined(separator: ", ") }
        }
        return nil
    }

    /// "25–55 kg": the smallest and largest adult values in the first statement's unit. The
    /// amounts are shown as Wikidata gives them, only without the leading "+".
    static func quantity(_ property: String, units: Set<String>, _ input: Input) -> String? {
        let values = usable(input.claims[property] ?? []).filter { claim in
            guard let unit = claim.unitID, units.contains(unit), claim.amount != nil else { return false }
            let roles = claim.roleIDs.compactMap { input.labels[$0]?.lowercased() }
            return !roles.contains { role in notAdultWords.contains { role.contains($0) } }
        }
        guard let unit = values.first?.unitID, let symbol = unitSymbols[unit] else { return nil }
        let amounts = values.filter { $0.unitID == unit }.compactMap { claim -> (String, Double)? in
            guard let raw = claim.amount else { return nil }
            let text = raw.hasPrefix("+") ? String(raw.dropFirst()) : raw
            return Double(text).map { (text, $0) }
        }
        guard let low = amounts.min(by: { $0.1 < $1.1 }), let high = amounts.max(by: { $0.1 < $1.1 }) else { return nil }
        return low.1 == high.1 ? "\(low.0) \(symbol)" : "\(low.0)–\(high.0) \(symbol)"
    }

    // MARK: Wikipedia fallback sentences

    static let rangeHeadings: Set<String> = [
        "distribution and habitat", "distribution", "habitat", "range", "range and habitat",
        "geographic range", "habitat and distribution", "distribution and ecology",
    ]
    static let dietHeadings: Set<String> = [
        "diet", "feeding", "diet and feeding", "feeding and diet", "feeding ecology", "hunting and diet",
        "diet and hunting", "prey", "food", "foraging", "diet and foraging",
    ]
    static let descriptionHeadings: Set<String> = [
        "description", "characteristics", "physical characteristics", "appearance", "size",
        "anatomy", "morphology", "anatomy and morphology",
    ]
    private static let lengthPattern = try! NSRegularExpression(
        pattern: #"\d[\d,.]*\s?(mm|cm|m|km|ft|feet|foot|inches|metres?|meters?|centimetres?|centimeters?|millimetres?|millimeters?)(?![A-Za-z])"#,
        options: [.caseInsensitive])
    private static let massPattern = try! NSRegularExpression(
        pattern: #"\d[\d,.]*\s?(g|kg|t|lb|lbs|oz|grams?|kilograms?|tonnes?|tons?|pounds?|ounces?)(?![A-Za-z])"#,
        options: [.caseInsensitive])

    static func fallbackRows(missing existing: [SpeciesProfile.Row], article: String) -> [SpeciesProfile.Row] {
        guard !article.isEmpty else { return [] }
        let sections = FactExtractor.sections(of: article)
        var used = Set<String>()
        var out: [SpeciesProfile.Row] = []
        func add(_ kind: SpeciesProfile.Kind, headings: Set<String>, pattern: NSRegularExpression?) {
            guard let text = sentence(in: sections, headings: headings, pattern: pattern, excluding: used) else { return }
            used.insert(text)
            out.append(.init(kind: kind, text: text, source: .wikipedia))
        }
        func has(_ test: (SpeciesProfile.Kind) -> Bool) -> Bool { existing.contains { test($0.kind) } }
        if !has({ $0 == .livesIn }) { add(.livesIn, headings: rangeHeadings, pattern: nil) }
        if !has({ $0 == .eats }) { add(.eats, headings: dietHeadings, pattern: nil) }
        if !has({ $0.isSize }) { add(.size, headings: descriptionHeadings, pattern: lengthPattern) }
        if !has({ $0 == .weight }) { add(.weight, headings: descriptionHeadings, pattern: massPattern) }
        return out
    }

    /// First short, self-contained sentence in a matching section (and matching `pattern`).
    static func sentence(in sections: [(String?, String)], headings: Set<String>,
                         pattern: NSRegularExpression?, excluding used: Set<String>) -> String? {
        for (heading, body) in sections {
            guard let heading, headings.contains(heading.lowercased()) else { continue }
            for sentence in FactExtractor.sentences(in: body) where !used.contains(sentence) {
                guard (20...maxSentenceLength).contains(sentence.count),
                      FactExtractor.isStandalone(sentence) else { continue }
                if let pattern {
                    let range = NSRange(sentence.startIndex..., in: sentence)
                    guard pattern.firstMatch(in: sentence, range: range) != nil else { continue }
                }
                return sentence
            }
        }
        return nil
    }
}
