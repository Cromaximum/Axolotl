import Foundation

/// Turns one species' content into a "species set": an intro board followed by
/// 3 to 8 photos and facts, alternating so two facts never sit back to back.
enum FeedComposer {
    static let maxItems = 8

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
        let usable = content.images.filter { artworkOK || !$0.isArtwork }
        let hero = usable.first { $0.fileTitle == content.leadImageFileTitle }
            ?? usable.first { !$0.isArtwork }
            ?? usable.first
        var photos = usable.filter { $0 != hero }

        let textCredit = Attribution.wikipediaText(title: content.title, pageURL: content.pageURL)
        var facts = content.facts.filter { $0.text != content.lead }
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

        // Plan the order first: photo, fact, photo, fact... Leftover photos may run on
        // together at the end; leftover facts are dropped so two facts never touch.
        enum Slot { case photo(LicensedImage), fact(FactExtractor.Fact) }
        var plan: [Slot] = []
        var factIterator = facts.makeIterator()
        var lastWasFact = !photos.isEmpty   // start on a photo when there is one
        while plan.count < maxItems {
            if lastWasFact {
                guard !photos.isEmpty else { break }
                plan.append(.photo(photos.removeFirst()))
                lastWasFact = false
            } else if let fact = factIterator.next() {
                plan.append(.fact(fact))
                lastWasFact = true
            } else if !photos.isEmpty {
                plan.append(.photo(photos.removeFirst()))
            } else {
                break
            }
        }

        // Each fact card keeps a photo of the animal above the board: cycle through the set's images.
        let factPhotos = ([hero].compactMap { $0 } + usable.filter { $0 != hero })
        var factPhotoIndex = 0

        let factTotal = plan.filter { slot in
            if case .fact = slot { return true }
            return false
        }.count
        var factIndex = 0
        for slot in plan {
            switch slot {
            case .photo(let image):
                cards.append(.photo(PhotoCard(entry: entry, sequence: sequence, image: image)))
            case .fact(let fact):
                factIndex += 1
                let photo = factPhotos.isEmpty ? nil : factPhotos[factPhotoIndex % factPhotos.count]
                factPhotoIndex += 1
                cards.append(.fact(FactCard(entry: entry, sequence: sequence, index: factIndex,
                                            total: factTotal, topic: fact.topic, text: fact.text,
                                            attribution: textCredit, image: photo)))
            }
        }
        return cards
    }
}
