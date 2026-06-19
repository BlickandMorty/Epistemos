import Foundation

// DATA + FINETUNE part (5) MARKETPLACE — cross-launch PERSISTENCE for imported packs.
// The import affordance (FineTunePackImporter) validates a pack through the
// ProvenanceGate and registers it into the session registry; this store makes those
// imports SURVIVE a relaunch by persisting the descriptors to the app's Application
// Support container (MAS-safe — descriptors only, never runtime code, never the pack's
// bytes). Pure + unit-tested with an injectable location. The actual byte download is
// still the separate, gated on-device step.
struct FineTunePackStore {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    /// The default on-disk location inside the sandbox container's Application Support.
    /// Honest fallback to a temporary directory if Application Support can't be resolved.
    static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("finetune_imported_packs.json", isDirectory: false)
    }

    /// Load the persisted imported packs. Honest: a missing or corrupt file yields an
    /// empty list (never a crash, never a fake entry).
    func load() -> [FineTunePack] {
        guard
            let data = try? Data(contentsOf: url),
            let packs = try? JSONDecoder().decode([FineTunePack].self, from: data)
        else {
            return []
        }
        return packs
    }

    /// Persist the full set of imported packs (atomic write; creates the directory).
    func save(_ packs: [FineTunePack]) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(packs)
        try data.write(to: url, options: .atomic)
    }

    /// Append one imported pack and persist. Deduped by id (case-insensitive) so
    /// re-importing the same source never double-stores. Returns the full stored set.
    @discardableResult
    func append(_ pack: FineTunePack) throws -> [FineTunePack] {
        var packs = load()
        let id = pack.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !packs.contains(where: { $0.id.caseInsensitiveCompare(id) == .orderedSame }) else {
            return packs
        }
        packs.append(pack)
        try save(packs)
        return packs
    }
}
