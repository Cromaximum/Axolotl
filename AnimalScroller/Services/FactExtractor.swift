import Foundation
import NaturalLanguage

/// Picks short, self-contained "Did you know?" sentences out of a plain-text
/// Wikipedia article (as returned by TextExtracts with exsectionformat=wiki).
enum FactExtractor {

    struct Fact: Hashable, Codable {
        let topic: String?
        let text: String
    }

    /// Sections that tend to hold the interesting, zoo-sign kind of facts.
    static let preferredSections: Set<String> = [
        "description", "characteristics", "appearance", "anatomy", "physiology",
        "behaviour", "behavior", "behaviour and ecology", "behavior and ecology", "ecology",
        "diet", "feeding", "diet and feeding", "hunting", "hunting and diet",
        "reproduction", "life cycle", "lifespan", "breeding", "communication",
        "intelligence", "distribution and habitat", "habitat", "adaptations",
        "paleobiology", "palaeobiology", "extinction", "evolution", "discovery",
        "size", "senses", "locomotion", "social structure",
    ]

    /// Sections never worth mining.
    static let skippedSections: Set<String> = [
        "references", "external links", "see also", "further reading", "notes",
        "bibliography", "sources", "citations", "footnotes", "gallery",
        "in popular culture", "in culture", "cultural significance", "etymology",
        "taxonomy", "classification", "nomenclature", "synonyms", "subspecies",
    ]

    /// Openers that only make sense after the previous sentence.
    private static let danglingOpeners = [
        "it ", "its ", "it's ", "this ", "these ", "those ", "that ", "they ", "their ", "them ",
        "he ", "she ", "his ", "her ", "however", "also", "in addition", "additionally",
        "furthermore", "moreover", "such ", "both ", "the latter", "the former", "there ",
        "another ", "other ", "others ", "the other ", "one of these", "some of these",
        "many of these", "most of these", "all of these", "each of these", "the same ",
        "as a result", "as such", "thus", "therefore", "hence", "consequently", "similarly",
        "likewise", "instead", "in contrast", "by contrast", "on the other hand", "nevertheless",
        "nonetheless", "despite this", "because of this", "for example", "for instance",
        "in this ", "at this ", "after this", "before this", "later ", "later,", "afterwards", "then ",
        "the two ", "which ", "and ", "but ", "or ", "so ", "yet ",
    ]

    /// Fragments that mark citation residue or text pointing elsewhere in the article.
    private static let referenceMarkers = [
        "et al", "pp.", " p. ", "isbn", "doi:", "doi.org", "retrieved", "ibid", "op. cit",
        "see below", "see above", "shown below", "shown above", "described below",
        "described above", "mentioned above", "mentioned below", "(see ", "figure ", "fig.",
        "table ", "http", "www.",
    ]

    /// Sentences that only restate the taxonomy, which the intro board already shows.
    private static let taxonomyPhrases = [
        "is a species of", "is a genus of", "is a family of", "was a species of",
        "was a genus of", "is the only species", "was first described", "was described by",
        "was named by", "binomial name", "specific epithet", "type species", "synonym",
        "subspecies are recognised", "subspecies are recognized",
    ]

    /// Units that make a number concrete: sizes, weights, speeds, ages, temperatures.
    private static let unitPattern = try! NSRegularExpression(
        pattern: #"\d[\d,.]*\s?(%|°|mm|cm|m|km|ft|mi|g|kg|t|lb|lbs|oz|tonnes?|tons?|metres?|meters?|kilometres?|kilometers?|centimetres?|centimeters?|feet|foot|inches|miles?|kilograms?|grams?|pounds?|years?|months?|weeks?|days?|hours?|minutes?|seconds?|km/h|mph|eggs?)(?![A-Za-z])"#,
        options: [.caseInsensitive]
    )

    static func facts(from article: String, max: Int = 8, perSection: Int = 2) -> [Fact] {
        var scored: [(score: Double, order: Int, fact: Fact)] = []
        var order = 0

        for (heading, body) in sections(of: article) {
            let key = heading?.lowercased()
            if let key, skippedSections.contains(key) { continue }
            let sectionBonus = key.map { preferredSections.contains($0) ? 2.0 : 0.0 } ?? 0.5

            for sentence in sentences(in: body) {
                order += 1
                guard let s = score(sentence) else { continue }
                scored.append((s + sectionBonus, order, Fact(topic: heading, text: sentence)))
            }
        }

        var perSectionCount: [String: Int] = [:]
        var picked: [(order: Int, fact: Fact)] = []
        for item in scored.sorted(by: { $0.score > $1.score }) {
            let key = item.fact.topic ?? ""
            guard perSectionCount[key, default: 0] < perSection else { continue }
            // Two sentences that say nearly the same thing make the set feel repetitive.
            guard !picked.contains(where: { isNearDuplicate($0.fact.text, item.fact.text) }) else { continue }
            perSectionCount[key, default: 0] += 1
            picked.append((item.order, item.fact))
            if picked.count == max { break }
        }
        // Present in article order so the story flows (description before extinction, etc).
        return picked.sorted { $0.order < $1.order }.map(\.fact)
    }

    /// Splits "== Heading ==" style plain text into (heading, body) pairs.
    /// Sub-headings are folded into their top-level section's name.
    static func sections(of article: String) -> [(String?, String)] {
        var result: [(String?, String)] = []
        var currentHeading: String? = nil
        var currentTop: String? = nil
        var buffer: [String] = []

        func flush() {
            let body = buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !body.isEmpty { result.append((currentHeading, body)) }
            buffer.removeAll()
        }

        for line in article.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("=="), trimmed.hasSuffix("==") {
                flush()
                let level = trimmed.prefix { $0 == "=" }.count
                let title = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "= "))
                if level <= 2 { currentTop = title; currentHeading = title }
                else {
                    // Keep the subsection name when it is itself a good topic (e.g. "Diet").
                    currentHeading = preferredSections.contains(title.lowercased()) ? title : currentTop
                    if let top = currentTop, skippedSections.contains(top.lowercased()) { currentHeading = top }
                }
            } else {
                buffer.append(line)
            }
        }
        flush()
        return result
    }

    static func sentences(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex).map {
            text[$0].trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// nil means "not usable as a standalone fact". Only ever chooses sentences; it never
    /// changes their text (D-011).
    static func score(_ sentence: String) -> Double? {
        let length = sentence.count
        guard (60...230).contains(length), isStandalone(sentence) else { return nil }
        let lower = sentence.lowercased()

        var score = 0.0
        if sentence.rangeOfCharacter(from: .decimalDigits) != nil { score += 1.5 } // sizes, speeds, ages
        if hasMeasurement(sentence) { score += 1.0 }
        let hooks = ["largest", "smallest", "fastest", "only", "longest", "heaviest", "unique",
                     "unlike", "can ", "up to", "able to", "first", "oldest", "record"]
        score += Double(hooks.filter { lower.contains($0) }.count) * 0.75
        // Vague or hedged sentences make weak "Did you know?" cards.
        let hedges = ["may ", "might ", "possibly", "perhaps", "unclear", "uncertain", "is thought",
                      "are thought", "is believed", "are believed", "it is unknown"]
        if hedges.contains(where: { lower.contains($0) }) { score -= 0.75 }
        if (90...170).contains(length) { score += 0.5 } // fits a card comfortably
        return score
    }

    /// Reads on its own: no context-dependent opener, citation residue, taxonomy restatement or
    /// list, and a whole sentence. Length is up to the caller.
    static func isStandalone(_ sentence: String) -> Bool {
        let lower = sentence.lowercased()
        if danglingOpeners.contains(where: { lower.hasPrefix($0) }) { return false }
        guard sentence.first.map({ $0.isUppercase || $0.isNumber }) == true else { return false }
        guard sentence.last.map({ ".!".contains($0) }) == true else { return false }
        if sentence.contains("[") || sentence.contains("{") || sentence.contains("^") { return false }
        if sentence.filter({ $0 == "(" }).count > 1 { return false }
        if referenceMarkers.contains(where: { lower.contains($0) }) { return false }
        if taxonomyPhrases.contains(where: { lower.contains($0) }) { return false }
        return !isListLike(sentence)
    }

    /// Enumerations ("a, b, c, d and e") and anything introduced by a colon read badly on a card.
    static func isListLike(_ sentence: String) -> Bool {
        if sentence.contains(":") { return true }
        return sentence.filter { $0 == "," }.count >= 4
    }

    /// A number followed by a unit, e.g. "105 cm", "30 kg", "12 years", "40%".
    static func hasMeasurement(_ sentence: String) -> Bool {
        let range = NSRange(sentence.startIndex..., in: sentence)
        return unitPattern.firstMatch(in: sentence, range: range) != nil
    }

    /// True when two sentences share most of their content words (Jaccard overlap ≥ `threshold`).
    static func isNearDuplicate(_ a: String, _ b: String, threshold: Double = 0.6) -> Bool {
        let wa = contentWords(a), wb = contentWords(b)
        guard !wa.isEmpty, !wb.isEmpty else { return a == b }
        let overlap = Double(wa.intersection(wb).count) / Double(wa.union(wb).count)
        return overlap >= threshold
    }

    private static let stopWords: Set<String> = [
        "the", "a", "an", "and", "or", "of", "in", "on", "to", "is", "are", "was", "were", "it",
        "its", "as", "by", "for", "with", "at", "from", "that", "this", "be", "has", "have", "had",
    ]

    private static func contentWords(_ text: String) -> Set<String> {
        let words = text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
        return Set(words.filter { $0.count > 1 && !stopWords.contains($0) })
    }
}
