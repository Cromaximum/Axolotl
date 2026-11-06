import Foundation

/// Turns one species' content into a "species set": an intro board followed by up to
/// `maxItems` photos and facts. Two facts never sit back to back, no more than two photos follow
/// each other, and no image appears twice in a set (Maxwell's feedback, 2026-11-06).
enum FeedComposer {
    /// Cards after the intro. Kept short so the feed moves on to the next animal quickly.
    static let maxItems = 4
    /// Never more than this many photo cards back to back (no three photos in a row).
    static let maxPhotoRun = 2

    private enum Slot {
        case photo(LicensedImage)
        /// A fact with its own photo above the board (D-010), never shown elsewhere in the set.
        case fact(FactExtractor.Fact, backdrop: LicensedImage)

        var isFact: Bool {
            if case .fact = self { return true }
            return false
        }
    }

    static func cards(
        for entry: SpeciesEntry,
        content: SpeciesContent,
        sequence: Int,
        allowArtwork: Bool
    ) -> [FeedCard] {
        // Reconstructions only ever appear for extinct species, and only ones already used on the
        // species' Wikipedia article, where paleoart is reviewed for accuracy by editors.
        // Living animals always get real photos.
        let artworkOK = allowArtwork && entry.species.isExtinct
        let usable = ContentPolicy.distinctImages(
            content.images.filter { artworkOK || !$0.isArtwork },
            preferring: content.leadImageFileTitle
        )
        let hero = usable.first { $0.fileTitle == content.leadImageFileTitle }
            ?? usable.first { !$0.isArtwork }
            ?? usable.first
        let photos = usable.filter { $0 != hero }

        let textCredit = Attribution.wikipediaText(title: content.title, pageURL: content.pageURL)
        let profile = content.profile.flatMap { $0.rows.isEmpty ? nil : $0 }
        let sheetTexts = Set(profile?.rows.map(\.text) ?? [])
        // Drop facts that repeat the lead or a fact-sheet row.
        var facts = content.facts.filter {
            $0.text != content.lead && !FactExtractor.isNearDuplicate($0.text, content.lead)
                && !sheetTexts.contains($0.text)
        }
        // With a fact sheet the intro shows the sheet, and every fact gets its own card.
        // Without one, the intro board's "Did you know?" box gets the first fact as before.
        let headlineFact = (profile != nil || facts.isEmpty) ? nil : facts.removeFirst()

        var intro = IntroCard(
            entry: entry,
            sequence: sequence,
            tagline: content.tagline,
            lead: content.lead,
            didYouKnow: headlineFact?.text,
            hero: hero,
            textAttribution: textCredit
        )
        intro.profile = profile
        var cards: [FeedCard] = [.intro(intro)]

        let plan = plan(photos: photos, facts: facts)
        let factTotal = plan.filter(\.isFact).count
        var factIndex = 0
        for slot in plan {
            switch slot {
            case .photo(let image):
                cards.append(.photo(PhotoCard(entry: entry, sequence: sequence, image: image)))
            case .fact(let fact, let backdrop):
                factIndex += 1
                cards.append(.fact(FactCard(entry: entry, sequence: sequence, index: factIndex,
                                            total: factTotal, topic: fact.topic, text: fact.text,
                                            attribution: textCredit, image: backdrop)))
            }
        }
        return cards
    }

    /// Every photo is used once: as a photo card or above one fact. k facts need k backdrops and
    /// k - 1 photo cards between them, so spare photos cap the number of fact cards. Any photo
    /// left over opens the set (so it starts on a photo) and then closes it, at most
    /// `maxPhotoRun` in a row, within `maxItems`.
    private static func plan(photos: [LicensedImage], facts: [FactExtractor.Fact]) -> [Slot] {
        let maxFactsByLength = (maxItems + 1) / 2      // fact, photo, fact... fits in maxItems
        let factCount = min(facts.count, (photos.count + 1) / 2, maxFactsByLength)
        var images = photos[...]
        var plan: [Slot] = []

        // Lead with a photo card when there is a spare one beyond what the facts need.
        let needed = factCount == 0 ? 0 : 2 * factCount - 1
        if images.count > needed, needed + 1 <= maxItems, let first = images.popFirst() {
            plan.append(.photo(first))
        }
        for (i, fact) in facts.prefix(factCount).enumerated() {
            if i > 0, let between = images.popFirst() { plan.append(.photo(between)) }
            guard let backdrop = images.popFirst() else { break }
            plan.append(.fact(fact, backdrop: backdrop))
        }
        // Trailing photos: never more than maxPhotoRun in a row, counting a leading run.
        var run = plan.reversed().prefix { !$0.isFact }.count
        while plan.count < maxItems, run < maxPhotoRun, let photo = images.popFirst() {
            plan.append(.photo(photo))
            run += 1
        }
        return plan
    }
}
