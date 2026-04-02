import Foundation
import CryptoKit
import SwiftData

// MARK: - SDPage
// The Intelligence Index for a note page. SwiftData is the source of truth during editing.
// Vault .md files are a secondary export — updated on manual Save or auto-save interval.
// SwiftData enables relational queries at O(log n) via #Predicate — impossible in v2.
//
// CloudKit-compatible: all properties optional or defaulted, no @Attribute(.unique),
// all @Relationship optional, no .deny delete rules.

@Model
final class SDPage {
    // MARK: - Indexes
    // Every #Predicate query that filters these fields benefits from B-tree indexing.
    // Without this, SwiftData does full table scans on every fetch.
    #Index<SDPage>(
        [\.id], [\.isJournal], [\.isArchived], [\.updatedAt], [\.filePath],
        [\.isPinned], [\.subfolder], [\.templateId])

    // MARK: - Identity
    var id: String = UUID().uuidString

    // MARK: - Content
    var title: String = ""
    var emoji: String = ""
    var body: String = ""  // Legacy inline body — cleared after saveBody(); loadBody() still falls back for pre-migration records.
    var summary: String = ""  // AI-generated summary (TriageService)

    // MARK: - Metadata
    var researchStage: Int = 0  // 0-5, maps to pipeline stage
    var tags: [String] = []  // Native array — SwiftData encodes Codable arrays
    var wordCount: Int = 0
    /// Legacy compatibility field. Current notes always use markdown storage.
    var format: String = "markdown"

    var isJournal: Bool = false  // Journal entries (JournalIntents)
    var journalDate: String?  // ISO date string for journal entries

    // MARK: - Organization
    var isPinned: Bool = false
    var isArchived: Bool = false
    var isFavorite: Bool = false
    var isLocked: Bool = false
    var sortOrder: Int = 0

    // MARK: - File System (Hybrid Persistence)
    var filePath: String?  // Absolute path to .md source of truth
    var subfolder: String?  // Relative subfolder from vault root (e.g. "Projects/2026")

    // MARK: - Front-matter
    // Stored as JSON-encoded Data for flexibility (arbitrary key-value pairs beyond typed fields)
    var frontMatterData: Data? {
        didSet {
            if frontMatterData != oldValue {
                _frontMatterCache = nil
            }
        }
    }

    // MARK: - Ideas & Brain Dumps
    // JSON-encoded array of NoteIdea — ideas and brain dumps registered to this page.
    var ideasData: Data? {
        didSet {
            if ideasData != oldValue {
                _ideasCache = nil
            }
        }
    }

    // MARK: - Timestamps
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    // MARK: - Vault Sync State (Apple Notes Hybrid)
    var lastSyncedBodyHash: String?  // SHA256 prefix of body at last vault save
    var lastSyncedAt: Date?          // When this page was last written to / read from vault
    /// Lightweight dirty flag — set true when body changes, cleared after vault export.
    /// Avoids the O(n) SHA256 recompute of isDirtyVault across all pages.
    var needsVaultSync: Bool = false

    /// Persistent cache of outgoing block references ((blockId)).
    /// Extracted during saveBody() to avoid O(N) disk I/O in the graph builder.
    var blockReferences: [String] = []

    // MARK: - Relationships
    // Note: .cascade delete rules work through SwiftData's managed context.
    // Direct batch deletes (e.g. try context.delete(model:where:)) bypass cascade
    // and will orphan related objects. Always use context.delete(object) for cascades.
    var folder: SDFolder?

    // MARK: - Nested Pages (Notion-style)
    // A page can contain child pages (sub-notes). Mirrors SDFolder's parent-child pattern.
    // Cascade: deleting a parent page deletes all its children (same as Notion).
    @Relationship(deleteRule: .cascade, inverse: \SDPage.parentPage)
    var childPages: [SDPage]? = []

    var parentPage: SDPage?

    /// Denormalized parent ID for #Predicate queries.
    /// SwiftData can't traverse optional relationships in predicates,
    /// so we keep a plain String? for indexed filtering.
    var parentPageId: String?

    /// Non-nil = this page is a template definition (hidden from normal views).
    var templateId: String?

    // MARK: - Init

    init(
        title: String,
        emoji: String = "",
        isJournal: Bool = false,
        journalDate: String? = nil
    ) {
        self.id = UUID().uuidString
        self.title = title
        self.emoji = emoji
        self.isJournal = isJournal
        self.journalDate = journalDate
        self.createdAt = .now
        self.updatedAt = .now
        self.blockReferences = []
    }

    // MARK: - Computed Accessors

    /// Cached front-matter dictionary — avoids JSON decode/encode on every access.
    /// Invalidated on set; lazily decoded on first get after Data changes.
    @Transient private var _frontMatterCache: [String: String]?
    @Transient private var _frontMatterCacheData: Data?

    var frontMatter: [String: String] {
        get {
            if let cached = _frontMatterCache, _frontMatterCacheData == frontMatterData {
                return cached
            }
            guard let data = frontMatterData else { return [:] }
            let decoded = (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
            _frontMatterCache = decoded
            _frontMatterCacheData = data
            return decoded
        }
        set {
            let encoded = try? JSONEncoder().encode(newValue)
            frontMatterData = encoded
            _frontMatterCache = newValue
            _frontMatterCacheData = encoded
        }
    }

    /// Whether this page is a template definition.
    var isTemplate: Bool {
        templateId != nil
    }

    /// Cached ideas array — avoids JSON decode/encode on every access.
    @Transient private var _ideasCache: [NoteIdea]?
    @Transient private var _ideasCacheData: Data?

    var ideas: [NoteIdea] {
        get {
            if let cached = _ideasCache, _ideasCacheData == ideasData {
                return cached
            }
            guard let data = ideasData else { return [] }
            let decoded = (try? JSONDecoder().decode([NoteIdea].self, from: data)) ?? []
            _ideasCache = decoded
            _ideasCacheData = data
            return decoded
        }
        set {
            let encoded = try? JSONEncoder().encode(newValue)
            ideasData = encoded
            _ideasCache = newValue
            _ideasCacheData = encoded
        }
    }

    // MARK: - File-Based Body Access

    /// Load the note body from disk (or fall back to inline body for pre-migration data).
    ///
    /// - Parameter mapped: When `true`, reads through a file-mapped `Data` path before decoding to `String`.
    ///   This reduces intermediate copying for bulk operations, but the returned `String` is still materialized.
    ///   Default `false` for interactive use (editing, display) where the String is long-lived.
    func loadBody(mapped: Bool = false) -> String {
        let hasManagedBody = NoteFileStorage.bodyExists(pageId: id)
        let diskBody: String
        if mapped {
            diskBody = autoreleasepool {
                NoteFileStorage.readBody(pageId: id, mapped: true, fast: false)
            }
        } else {
            diskBody = NoteFileStorage.readBody(pageId: id, mapped: false, fast: true)
        }
        if !diskBody.isEmpty || hasManagedBody {
            return diskBody
        }
        // Fallback: if no managed file exists but inline body has content (pre-migration), use inline.
        if !body.isEmpty {
            return body
        }
        if let filePath,
           !filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let fileURL = URL(fileURLWithPath: filePath)
            if let readableVaultBody = VaultIndexActor.decodedBodyFromReadableVaultFile(at: fileURL) {
                return readableVaultBody
            }
        }
        return ""
    }

    func bodyPrefix(_ limit: Int, mapped: Bool = false) -> String {
        guard limit > 0 else { return "" }
        return String(loadBody(mapped: mapped).prefix(limit))
    }

    func normalizedBodySnippet(limit: Int, mapped: Bool = false) -> String {
        bodyPrefix(limit, mapped: mapped)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Save the note body to disk. Also clears the inline body (post-migration).
    func saveBody(_ content: String) {
        NoteFileStorage.writeBody(pageId: id, content: content)
        updateBodyDerivedState(from: content)
    }

    func clearInlineBodyIfNeeded() {
        if !body.isEmpty { body = "" }
    }

    func applyInteractiveDerivedState(from content: String) {
        clearInlineBodyIfNeeded()
        guard content.contains("((") else {
            if !blockReferences.isEmpty {
                blockReferences.removeAll(keepingCapacity: true)
            }
            return
        }
        blockReferences = Self.extractBlockReferences(from: content)
    }

    func updateBodyDerivedState(from content: String) {
        clearInlineBodyIfNeeded()
        blockReferences = Self.extractBlockReferences(from: content)
    }

    static func extractBlockReferences(from content: String) -> [String] {
        guard let initialSearchStart = content.range(of: "((")?.lowerBound else { return [] }

        var refs: [String] = []
        refs.reserveCapacity(4)
        var searchStart = initialSearchStart

        while searchStart < content.endIndex,
              let openRange = content.range(of: "((", range: searchStart..<content.endIndex) {
            let candidateStart = openRange.upperBound
            var cursor = candidateStart
            var matched = false

            while cursor < content.endIndex {
                if content[cursor] == ")" {
                    let next = content.index(after: cursor)
                    if next < content.endIndex, content[next] == ")" {
                        let raw = String(content[candidateStart..<cursor])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !raw.isEmpty {
                            refs.append(raw)
                        }
                        searchStart = content.index(after: next)
                        matched = true
                    }
                    break
                }
                cursor = content.index(after: cursor)
            }

            if matched { continue }
            searchStart = content.index(after: openRange.lowerBound)
        }

        return refs
    }

    /// SHA256 hash prefix (16 hex chars) for dirty detection.
    static func bodyHash(_ body: String) -> String {
        let digest = SHA256.hash(data: Data(body.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    /// Whether this page has edits not yet saved to the vault .md file.
    /// Fast path: uses the stored `needsVaultSync` flag (O(1), no disk I/O).
    /// Fallback: computes SHA256 if never synced (first launch only).
    var isDirtyVault: Bool {
        if needsVaultSync { return true }
        guard lastSyncedBodyHash != nil else { return true }
        return false
    }

}

// MARK: - Note Idea / Brain Dump

/// An idea or brain dump registered to a note page.
/// Persisted as JSON array in SDPage.ideasData.
/// Each idea is anchored to a specific line in the note for inline context.
struct NoteIdea: Identifiable, Codable, Sendable {
    var id: String = UUID().uuidString
    var type: IdeaType
    var title: String
    var body: String
    /// AI-formatted version of the body (brain dumps only).
    var formattedBody: String?
    /// 1-based line number in the note body where this idea is anchored.
    var lineAnchor: Int?
    /// Snippet of the anchor line for display context (first 80 chars).
    var lineContext: String?
    var createdAt: Date = .now

    enum IdeaType: String, Codable, Sendable {
        case idea
        case brainDump
    }
}
