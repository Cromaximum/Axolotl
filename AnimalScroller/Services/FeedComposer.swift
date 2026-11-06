import Foundation

/// Turns one species' content into a "species set": an intro board followed by
/// up to 8 photos and facts, alternating so two facts never sit back to back and no more
/// than two photos follow each other.
enum FeedComposer {
    static let maxItems = 8
    /// Never more than this many photo cards back to back (W4: no three photos in a row).
    static let maxPhotoRun = 2

    private enum Slot {
        case photo(LicensedImage), fact(FactExtractor.Fact)

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
        // The lead is already on the intro board, so drop facts that repeat it.
        var facts = content.facts.filter {
            $0.text != content.lead && !FactExtractor.isNearDuplicate($0.text, content.lead)
        }
        // The intro board's "Did you know?" box gets the first fact.
        let headlineFact = facts.isEmpty ? nil : facts.removeFirst()

        var cards: [FeedCard] = [.intro(IntroCard(
            entry: entry,
            sequence: sequence,
            tagline: content.tagline,
            lead: content.lead,
            didYouKnow: headlineFact?.text,
            hero: hero,
            textAttribution: textCredit
        ))]

        let plan = plan(photos: photos, facts: facts)
        let backdrops = factBackdrops(plan: plan, hero: hero, photos: photos)
        let factTotal = plan.filter(\.isFact).count
        var factIndex = 0
        for (position, slot) in plan.enumerated() {
            switch slot {
            case .photo(let image):
                cards.append(.photo(PhotoCard(entry: entry, sequence: sequence, image: image)))
            case .fact(let fact):
                factIndex += 1
                cards.append(.fact(FactCard(entry: entry, sequence: sequence, index: factIndex,
                                            total: factTotal, topic: fact.topic, text: fact.text,
                                            attribution: textCredit, image: backdrops[position])))
            }
        }
        return cards
    }

    /// Photo, fact, photo, fact... Two facts never touch, and once facts run out at most
    /// `maxPhotoRun` photos follow each other. Photos that don't fit become fact backdrops.
    private static func plan(photos: [LicensedImage], facts: [FactExtractor.Fact]) -> [Slot] {
        var photos = photos[...]
        var facts = facts[...]
        var plan: [Slot] = []
        var lastWasFact = false
        var photoRun = 0
        while plan.count < maxItems {
            let wantPhoto = lastWasFact || plan.isEmpty   // start on a photo when there is one
            if wantPhoto, let photo = photos.popFirst() {
                plan.append(.photo(photo)); photoRun += 1; lastWasFact = false
            } else if !lastWasFact, let fact = facts.popFirst() {
                plan.append(.fact(fact)); photoRun = 0; lastWasFact = true
            } else if !lastWasFact, photoRun < maxPhotoRun, let photo = photos.popFirst() {
                plan.append(.photo(photo)); photoRun += 1
            } else {
                break
            }
        }
        return plan
    }

    /// Photo kept above each fact board (D-010), keyed by plan position. Prefers the hero and
    /// photos that got no card of their own, spreads them out, and never repeats the photo of
    /// the card right before or after.
    private static func factBackdrops(plan: [Slot], hero: LicensedImage?,
                                      photos: [LicensedImage]) -> [Int: LicensedImage] {
        let placed = plan.compactMap { slot -> LicensedImage? in
            if case .photo(let image) = slot { return image }
            return nil
        }
        let placedSet = Set(placed)
        let pool = [hero].compactMap { $0 } + photos.filter { !placedSet.contains($0) } + placed
        var uses: [LicensedImage: Int] = [:]
        var out: [Int: LicensedImage] = [:]
        for (position, slot) in plan.enumerated() {
            guard case .fact = slot else { continue }
            let neighbours = Set([position - 1, position + 1].compactMap { i -> LicensedImage? in
                guard plan.indices.contains(i), case .photo(let image) = plan[i] else { return nil }
                return image
            })
            let candidates = pool.filter { !neighbours.contains($0) }
            let choice = (candidates.isEmpty ? pool : candidates)
                .enumerated()
                .min { (uses[$0.element, default: 0], $0.offset) < (uses[$1.element, default: 0], $1.offset) }?
                .element
            if let choice {
                uses[choice, default: 0] += 1
                out[position] = choice
            }
        }
        return out
    }
}
