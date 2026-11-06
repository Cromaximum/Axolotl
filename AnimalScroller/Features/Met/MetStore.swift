import Foundation
import Observation

/// Every species the user has scrolled past, plus the ones they saved. Persisted in UserDefaults
/// under `met.v2`.
///
/// Keeps ids, dates and flags only. Names, statuses and lineage of bundled species are looked up
/// in `taxonomy.json` when shown, so regenerated data (D-011) never leaves stale text on a device.
/// Live-catalogue species can't be looked up offline, so they keep the `Species` the catalogue
/// built from its sources, plus the bundled branch ids above it.
@Observable
final class MetStore {
    struct LiveRecord: Codable, Hashable {
        var species: Species
        var lineageIDs: [String]
    }

    struct Entry: Codable, Identifiable, Hashable {
        /// Species.wikiTitle
        let id: String
        var firstMet: Date
        var lastMet: Date
        var saved: Bool
        var savedAt: Date?
        /// Only for species that aren't in the bundled taxonomy.
        var live: LiveRecord?
        /// Fetch-only cache hint for the tile photo. Transitional: removed once the content
        /// provider has a disk cache (W1). Never shown as content.
        var imageURL: URL?

        init(id: String, firstMet: Date, lastMet: Date, saved: Bool = false, savedAt: Date? = nil,
             live: LiveRecord? = nil, imageURL: URL? = nil) {
            self.id = id
            self.firstMet = firstMet
            self.lastMet = lastMet
            self.saved = saved
            self.savedAt = savedAt
            self.live = live
            self.imageURL = imageURL
        }

        // Tolerant: every field except id and firstMet is optional on decode, so adding a field
        // never wipes the collection.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            firstMet = try c.decode(Date.self, forKey: .firstMet)
            lastMet = try c.decodeIfPresent(Date.self, forKey: .lastMet) ?? firstMet
            saved = try c.decodeIfPresent(Bool.self, forKey: .saved) ?? false
            savedAt = try c.decodeIfPresent(Date.self, forKey: .savedAt)
            live = try c.decodeIfPresent(LiveRecord.self, forKey: .live)
            imageURL = try c.decodeIfPresent(URL.self, forKey: .imageURL)
        }
    }

    /// Most recently first met first.
    private(set) var entries: [Entry] = []

    private let defaults: UserDefaults
    private let now: () -> Date
    static let key = "met.v2"
    static let legacyKey = "met.v1"

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = { Date() }) {
        self.defaults = defaults
        self.now = now
        if let data = defaults.data(forKey: Self.key) {
            entries = Self.decodeTolerantly(data)
        } else if let legacy = defaults.data(forKey: Self.legacyKey) {
            entries = Self.migrate(v1: legacy)
            save()
            defaults.removeObject(forKey: Self.legacyKey)
        }
    }

    func isSaved(_ id: String) -> Bool { entries.first { $0.id == id }?.saved ?? false }

    /// Called when a species' intro card is shown. Keeps the first-met date and saved flag.
    func recordMet(_ entry: SpeciesEntry, imageURL: URL?) {
        let date = now()
        if let i = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[i].lastMet = date
            if entries[i].imageURL == nil { entries[i].imageURL = imageURL }
            // The deprecated forwarders pass no lineage; don't let them erase a known one.
            if entry.species.isLive, !(entry.lineage.isEmpty && entries[i].live != nil) {
                entries[i].live = Self.liveRecord(entry)
            }
        } else {
            entries.insert(Entry(id: entry.id, firstMet: date, lastMet: date,
                                 live: entry.species.isLive ? Self.liveRecord(entry) : nil,
                                 imageURL: imageURL), at: 0)
        }
        save()
    }

    func toggleSaved(_ entry: SpeciesEntry, imageURL: URL?) {
        if !entries.contains(where: { $0.id == entry.id }) { recordMet(entry, imageURL: imageURL) }
        guard let i = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[i].saved.toggle()
        entries[i].savedAt = entries[i].saved ? now() : nil
        save()
    }

    @available(*, deprecated, message: "Pass the SpeciesEntry so live species keep their lineage.")
    func recordMet(_ species: Species, imageURL: URL?) {
        recordMet(SpeciesEntry(species: species, lineage: []), imageURL: imageURL)
    }

    @available(*, deprecated, message: "Pass the SpeciesEntry so live species keep their lineage.")
    func toggleSaved(_ species: Species, imageURL: URL?) {
        toggleSaved(SpeciesEntry(species: species, lineage: []), imageURL: imageURL)
    }

    /// Drops stored live records for species the bundled taxonomy now covers, so the bundled
    /// data is the only copy. Called once at launch from `RootView`.
    func forgetCopies(of bundledIDs: Set<String>) {
        var changed = false
        for i in entries.indices where entries[i].live != nil && bundledIDs.contains(entries[i].id) {
            entries[i].live = nil
            changed = true
        }
        if changed { save() }
    }

    // MARK: Persistence

    private static func liveRecord(_ entry: SpeciesEntry) -> LiveRecord {
        LiveRecord(species: entry.species, lineageIDs: entry.lineageIDs)
    }

    /// Decodes entry by entry, so one bad entry doesn't lose the rest.
    static func decodeTolerantly(_ data: Data) -> [Entry] {
        guard let raw = try? JSONDecoder().decode([FailableDecodable<Entry>].self, from: data) else { return [] }
        return raw.compactMap(\.value)
    }

    /// The `met.v1` shape, read only for migration.
    private struct V1Entry: Decodable {
        let id: String
        let commonName: String?
        let scientificName: String?
        let isExtinct: Bool?
        let imageURL: URL?
        let firstMet: Date
        let saved: Bool?
    }

    /// v1 copied names onto every entry and can't tell bundled from live species. Every entry keeps
    /// a live record built only from its own v1 fields; `forgetCopies(of:)` then drops the ones the
    /// bundled taxonomy covers. Status is Extinct only if v1 said so, otherwise Not Evaluated: a
    /// status is never inferred (D-012).
    static func migrate(v1 data: Data) -> [Entry] {
        guard let raw = try? JSONDecoder().decode([FailableDecodable<V1Entry>].self, from: data) else { return [] }
        return raw.compactMap(\.value).map { old in
            let species = Species(wikiTitle: old.id,
                                  commonName: old.commonName ?? old.id,
                                  scientificName: old.scientificName ?? "",
                                  status: old.isExtinct == true ? .extinct : .notEvaluated)
            return Entry(id: old.id, firstMet: old.firstMet, lastMet: old.firstMet,
                         saved: old.saved ?? false, savedAt: nil,
                         live: LiveRecord(species: species, lineageIDs: []), imageURL: old.imageURL)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) { defaults.set(data, forKey: Self.key) }
    }
}

/// Decodes a value or nil, so one malformed array element doesn't fail the whole array.
private struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}
