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
        "it ", "its ", "this ", "these ", "they ", "their ", "he ", "she ", "however",
        "also", "in addition", "furthermore", "moreover", "such ", "both ", "the latter",
        "the former", "there ", "another ",
    ]

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

    /// nil means "not usable as a standalone fact".
    static func score(_ sentence: String) -> Double? {
        let length = sentence.count
        guard (60...230).contains(length) else { return nil }
        let lower = sentence.lowercased()
        if danglingOpeners.contains(where: { lower.hasPrefix($0) }) { return nil }
        guard sentence.last.map({ ".!".contains($0) }) == true else { return nil }
        if sentence.contains("[") || sentence.contains("{") || sentence.contains("^") { return nil }
        if sentence.filter({ $0 == "(" }).count > 1 { return nil }

        var score = 0.0
        if sentence.rangeOfCharacter(from: .decimalDigits) != nil { score += 1.5 } // sizes, speeds, ages
        let hooks = ["largest", "smallest", "fastest", "only", "longest", "heaviest", "unique",
                     "unlike", "can ", "up to", "able to", "first", "oldest", "record"]
        score += Double(hooks.filter { lower.contains($0) }.count) * 0.75
        if (90...170).contains(length) { score += 0.5 } // fits a card comfortably
        return score
    }
}
