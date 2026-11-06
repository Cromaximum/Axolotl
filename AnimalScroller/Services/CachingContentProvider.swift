import Foundation

/// Wraps another `SpeciesContentProvider` with a memory cache, a disk cache, and one shared
/// in-flight fetch per species, so the feed, onboarding and detail sheets never fetch the same
/// species twice and relaunching is instant. Created once in `App/`.
///
/// The disk copy is the already-filtered `SpeciesContent` from the wrapped provider (which ran
/// `ContentPolicy`), so this is a cache of sourced content, never a new source.
actor CachingContentProvider: SpeciesContentProvider {
    private let upstream: SpeciesContentProvider
    /// Nil disables the disk cache (memory only).
    private let directory: URL?
    private let now: @Sendable () -> Date
    private var memory: [String: SpeciesContent] = [:]
    private var inFlight: [String: Task<SpeciesContent, Error>] = [:]

    init(upstream: SpeciesContentProvider, directory: URL?,
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.upstream = upstream
        self.directory = directory
        self.now = now
    }

    func content(for species: Species) async throws -> SpeciesContent {
        let key = species.wikiTitle
        if let hit = memory[key] { return hit }
        if let running = inFlight[key] { return try await running.value }

        let task = Task { try await self.load(species) }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        let content = try await task.value
        memory[key] = content
        return content
    }

    /// Fresh disk copy, else the network, else a stale disk copy (offline beats empty).
    private func load(_ species: Species) async throws -> SpeciesContent {
        let cached = readEntry(for: species.wikiTitle)
        if let cached, ContentCachePolicy.isFresh(fetchedAt: cached.fetchedAt, now: now()) {
            return cached.content
        }
        do {
            let fresh = try await upstream.content(for: species)
            writeEntry(fresh, for: species.wikiTitle)
            return fresh
        } catch {
            if let cached { return cached.content }
            throw error
        }
    }

    // MARK: Disk

    private func fileURL(for wikiTitle: String) -> URL? {
        directory?.appendingPathComponent(ContentCachePolicy.fileName(forWikiTitle: wikiTitle))
    }

    /// A missing, unreadable or mismatched file is a cache miss (documented fallback: fetch).
    private func readEntry(for wikiTitle: String) -> ContentCachePolicy.Entry? {
        guard let url = fileURL(for: wikiTitle),
              let data = try? Data(contentsOf: url),
              let entry = try? JSONDecoder().decode(ContentCachePolicy.Entry.self, from: data),
              ContentCachePolicy.isUsable(entry, wikiTitle: wikiTitle) else { return nil }
        return entry
    }

    /// Atomic, so two instances writing the same folder never leave a half-written file.
    /// A failed write only costs a refetch later, so it is ignored.
    private func writeEntry(_ content: SpeciesContent, for wikiTitle: String) {
        guard let url = fileURL(for: wikiTitle) else { return }
        let entry = ContentCachePolicy.Entry(schema: ContentCachePolicy.schema, wikiTitle: wikiTitle,
                                             fetchedAt: now(), content: content)
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Creates `<cachesRoot>/species-content.vN/` and deletes folders from older versions.
    /// Returns nil if the folder can't be made, which turns the disk cache off.
    static func prepareDirectory(in cachesRoot: URL, fileManager: FileManager) -> URL? {
        if let names = try? fileManager.contentsOfDirectory(atPath: cachesRoot.path) {
            for name in names where ContentCachePolicy.isOutdatedDirectory(named: name) {
                try? fileManager.removeItem(at: cachesRoot.appendingPathComponent(name))
            }
        }
        let directory = cachesRoot.appendingPathComponent(ContentCachePolicy.directoryName, isDirectory: true)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            return nil
        }
    }
}
