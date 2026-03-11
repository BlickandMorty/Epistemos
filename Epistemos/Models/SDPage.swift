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
    var body: String = ""  // Legacy inline body — post-migration always "". Use loadBody()/saveBody().
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
    var frontMatterData: Data?

    // MARK: - Ideas & Brain Dumps
    // JSON-encoded array of NoteIdea — ideas and brain dumps registered to this page.
    var ideasData: Data?

    // MARK: - Timestamps
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    // MARK: - Vault Sync State (Apple Notes Hybrid)
    var lastSyncedBodyHash: String?  // SHA256 prefix of body at last vault save
    var lastSyncedAt: Date?          // When this page was last written to / read from vault
    /// Lightweight dirty flag — set true when body changes, cleared after vault export.
    /// Avoids the O(n) SHA256 recompute of isDirtyVault across all pages.
    var needsVaultSync: Bool = false

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
    }

    // MARK: - Computed Accessors

    /// Cached front-matter dictionary — avoids JSON decode/encode on every access.
    /// Invalidated on set; lazily decoded on first get after Data changes.
    @Transient private var _frontMatterCache: [String: String]?

    var frontMatter: [String: String] {
        get {
            if let cached = _frontMatterCache { return cached }
            guard let data = frontMatterData else { return [:] }
            let decoded = (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
            _frontMatterCache = decoded
            return decoded
        }
        set {
            _frontMatterCache = newValue
            frontMatterData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Whether this page is a template definition.
    var isTemplate: Bool {
        templateId != nil
    }

    /// Cached ideas array — avoids JSON decode/encode on every access.
    @Transient private var _ideasCache: [NoteIdea]?

    var ideas: [NoteIdea] {
        get {
            if let cached = _ideasCache { return cached }
            guard let data = ideasData else { return [] }
            let decoded = (try? JSONDecoder().decode([NoteIdea].self, from: data)) ?? []
            _ideasCache = decoded
            return decoded
        }
        set {
            _ideasCache = newValue
            ideasData = try? JSONEncoder().encode(newValue)
        }
    }

    // MARK: - File-Based Body Access

    /// Load the note body from disk (or fall back to inline body for pre-migration data).
    ///
    /// - Parameter mapped: When `true`, uses mmap for zero-copy reading.
    ///   Use for bulk operations (indexing, hashing, search) that read many notes in a loop.
    ///   Default `false` for interactive use (editing, display) where the String is long-lived.
    func loadBody(mapped: Bool = false) -> String {
        let diskBody = NoteFileStorage.readBody(pageId: id, mapped: mapped)
        // Fallback: if no file exists but inline body has content (pre-migration), use inline.
        if diskBody.isEmpty && !body.isEmpty {
            return body
        }
        return diskBody
    }

    /// Save the note body to disk. Also clears the inline body (post-migration).
    func saveBody(_ content: String) {
        NoteFileStorage.writeBody(pageId: id, content: content)
        // Clear inline body to keep SQLite rows small.
        if !body.isEmpty { body = "" }
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
