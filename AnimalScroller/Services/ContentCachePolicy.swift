import Foundation

/// Rules for the on-disk species content cache. Pure logic; `CachingContentProvider` does the I/O.
enum ContentCachePolicy {
    /// Bump with `directoryName` whenever `SpeciesContent` changes shape (data-model.md).
    static let schema = 2
    /// Folder under the app's Caches directory. iOS may purge it; nothing breaks if it does.
    static let directoryName = "species-content.v2"
    /// Older cache folders, deleted on launch.
    static let directoryPrefix = "species-content.v"
    /// Cached content is refetched after a week so corrected articles reach the device (D-011).
    static let freshFor: TimeInterval = 7 * 24 * 60 * 60

    /// One cached species, as stored on disk.
    struct Entry: Codable {
        let schema: Int
        /// The key the entry was stored under, checked on read so a hash collision is a miss.
        let wikiTitle: String
        let fetchedAt: Date
        let content: SpeciesContent
    }

    /// Fresh enough to use without asking the network. A date in the future (clock changed) is stale.
    static func isFresh(fetchedAt: Date, now: Date, freshFor: TimeInterval = freshFor) -> Bool {
        let age = now.timeIntervalSince(fetchedAt)
        return age >= -60 && age < freshFor
    }

    /// Entry is usable at all (right schema, right species). Stale entries are still usable offline.
    static func isUsable(_ entry: Entry, wikiTitle: String) -> Bool {
        entry.schema == schema && entry.wikiTitle == wikiTitle
    }

    /// File name for a wiki title: a stable 64-bit FNV-1a hash in hex, so any title (slashes,
    /// spaces, non-ASCII, long names) maps to a short, safe name.
    static func fileName(forWikiTitle title: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in title.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        let hex = String(hash, radix: 16)
        return String(repeating: "0", count: 16 - hex.count) + hex + ".json"
    }

    /// Cache folders left by older schema versions.
    static func isOutdatedDirectory(named name: String) -> Bool {
        name.hasPrefix(directoryPrefix) && name != directoryName
    }
}
