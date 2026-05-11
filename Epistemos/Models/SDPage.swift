import Foundation
import CryptoKit
import OSLog
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
    /// Persistent cache of outgoing Obsidian-style wikilinks.
    /// Stored as canonical destinations ("folder/note", "note") so graph
    /// rebuilds can materialize note→note edges without rescanning every body.
    var wikilinkReferences: [String] = []
    /// Body/fingerprint signature used when the wikilink cache was last refreshed.
    /// Lets vault imports distinguish "no wikilinks" from "not scanned yet".
    var wikilinkReferenceScanSignature: String?

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

    private static let log = Logger(subsystem: "com.epistemos", category: "SDPage")

    var frontMatter: [String: String] {
        get {
            if let cached = _frontMatterCache, _frontMatterCacheData == frontMatterData {
                return cached
            }
            guard let data = frontMatterData else { return [:] }
            do {
                let decoded = try JSONDecoder().decode([String: String].self, from: data)
                _frontMatterCache = decoded
                _frontMatterCacheData = data
                return decoded
            } catch {
                Self.log.error("SDPage: frontMatter decode failed: \(error.localizedDescription, privacy: .public)")
                return [:]
            }
        }
        set {
            do {
                let encoded = try JSONEncoder().encode(newValue)
                frontMatterData = encoded
                _frontMatterCache = newValue
                _frontMatterCacheData = encoded
            } catch {
                Self.log.error("SDPage: frontMatter encode failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Whether this page is a template definition.
    var isTemplate: Bool {
        templateId != nil
    }

    var vaultRelativeNotePath: String? {
        guard let filePath else { return nil }
        let trimmedFilePath = filePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFilePath.isEmpty else { return nil }

        let fileName = URL(fileURLWithPath: trimmedFilePath)
            .lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fileName.isEmpty else { return nil }

        let trimmedSubfolder = subfolder?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedSubfolder.isEmpty {
            return fileName
        }
        return "\(trimmedSubfolder)/\(fileName)"
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
            do {
                let decoded = try JSONDecoder().decode([NoteIdea].self, from: data)
                _ideasCache = decoded
                _ideasCacheData = data
                return decoded
            } catch {
                Self.log.error("SDPage: ideas decode failed: \(error.localizedDescription, privacy: .public)")
                return []
            }
        }
        set {
            do {
                let encoded = try JSONEncoder().encode(newValue)
                ideasData = encoded
                _ideasCache = newValue
                _ideasCacheData = encoded
            } catch {
                Self.log.error("SDPage: ideas encode failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - File-Based Body Access

    /// Load the note body from disk (or fall back to inline body for pre-migration data).
    ///
    /// - Parameter mapped: When `true`, reads through a file-mapped `Data` path before decoding to `String`.
    ///   This reduces intermediate copying for bulk operations, but the returned `String` is still materialized.
    ///   Default `false` for interactive use (editing, display) where the String is long-lived.
    func loadBody(mapped: Bool = false, fast: Bool = false) -> String {
        let hasManagedBody = NoteFileStorage.bodyExists(pageId: id)
        let diskBody: String
        if mapped {
            diskBody = autoreleasepool {
                NoteFileStorage.readBody(pageId: id, mapped: true, fast: fast)
            }
        } else {
            diskBody = NoteFileStorage.readBody(pageId: id, mapped: false, fast: fast)
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

    /// Async variant of ``loadBody(mapped:fast:)``. It preserves the same
    /// source-of-truth order as the synchronous path: managed sidecar body
    /// first, then the Phase R.3 unified `VaultResourceService` gateway
    /// when it is ready, then inline/vault-file fallback data.
    ///
    /// The gateway path produces byte-identical output to ``loadBody``
    /// for notes that resolve to a `ResourceId::VaultNote` — verified in
    /// `PhaseR3BodyReadParityTests`. Callers in async contexts should
    /// prefer this entry point; once the strangler-fig migration
    /// completes, the sync `loadBody` will become a shim around this.
    ///
    /// Plan refs: docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md §Phase R.3,
    /// docs/AUDIT_REFLECTION_2026_04_23.md §2 (I-002 / I-003 OPEN).
    func loadBodyAsync(mapped: Bool = false, fast: Bool = false) async -> String {
        await Self.loadBodyAsyncFromPrimitives(
            pageId: id,
            filePath: filePath,
            inlineBody: body,
            mapped: mapped,
            fast: fast
        )
    }

    /// Build the canonical R.3 reference string for a page. Strategy:
    /// 1. Absolute `filePath` if present (most specific).
    /// 2. Page `id` otherwise (the resolver falls back to alias lookup).
    static func r3Reference(for page: SDPage) -> String {
        if let absolute = page.filePath,
           !absolute.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return absolute
        }
        return page.id
    }

    /// Sendable-primitive async body read. Use this when the caller is
    /// inside a detached `Task` that can't safely capture an `SDPage`
    /// reference (e.g. `@MainActor` call sites that need to dispatch
    /// indexing off the sync call stack without SwiftData's non-Sendable
    /// `@Model` flowing across the Task boundary).
    ///
    /// Behaviour matches ``loadBodyAsync(mapped:fast:)`` and
    /// ``loadBody(mapped:fast:)``:
    /// 1. `NoteFileStorage.readBody` (managed-body sidecar file).
    ///    An existing managed body, even a blank one, is authoritative.
    /// 2. R.3 gateway resolve + read when the gateway is ready.
    /// 3. Inline `body` when no managed sidecar exists (pre-migration).
    /// 4. Raw vault file via `VaultIndexActor.decodedBodyFromReadableVaultFile`
    ///    when both managed-body and inline are empty.
    ///
    /// Takes only Sendable primitives so it can be called freely from
    /// detached Tasks. Always returns a `String` — never throws; all
    /// errors fall through to the next step in the fallback chain.
    static func loadBodyAsyncFromPrimitives(
        pageId: String,
        filePath: String?,
        inlineBody: String = "",
        mapped: Bool = false,
        fast: Bool = false
    ) async -> String {
        let hasManagedBody = NoteFileStorage.bodyExists(pageId: pageId)
        let diskBody = NoteFileStorage.readBody(pageId: pageId, mapped: mapped, fast: fast)
        if !diskBody.isEmpty || hasManagedBody {
            return diskBody
        }

        if resourceServiceIsReady() {
            let trimmedPath = filePath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let reference = trimmedPath.isEmpty ? pageId : trimmedPath
            do {
                let resourceId = try await resourceResolve(reference: reference)
                let content = try await resourceRead(id: resourceId)
                if let decoded = String(data: content.bytes, encoding: .utf8) {
                    if !trimmedPath.isEmpty {
                        let fileURL = URL(fileURLWithPath: trimmedPath)
                        return VaultIndexActor.shouldWriteMarkdownFrontMatter(to: fileURL)
                            ? VaultIndexActor.parseFrontMatter(decoded).1
                            : decoded
                    }
                    return decoded
                }
            } catch {
                // Expected during vault-switch races or when the page
                // is inline-body-only. Fall through to legacy path.
            }
        }

        if !inlineBody.isEmpty {
            return inlineBody
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
        if content.contains("[[") {
            wikilinkReferences = WikilinkResolver.extractDestinations(from: content)
        } else if !wikilinkReferences.isEmpty {
            wikilinkReferences.removeAll(keepingCapacity: true)
        }
        wikilinkReferenceScanSignature = Self.bodyHash(content)

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
        wikilinkReferences = WikilinkResolver.extractDestinations(from: content)
        wikilinkReferenceScanSignature = Self.bodyHash(content)
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
