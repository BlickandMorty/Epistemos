import Foundation
import Observation
import OSLog

// MARK: - QuarantineArchive (Phase 15 / W10.15)
//
// Master plan Phase 15 / Wave 13 §"Phase 15": deterministic-core
// vs ambient-retrieval split. Raw, unstructured user thoughts —
// brain dumps, voice notes, pasted walls of text — sit in a
// QUARANTINED archive by default; the cloud agent never sees them
// unless the user explicitly toggles ambient-retrieval ON.
//
// Doc 2 amendment honoured: this is the "messy sandbox" the user
// can opt into for creative cross-disciplinary connections, NOT the
// default runtime. The cognitive architecture's deterministic core
// (structured sidecars, ontology-classified notes, session
// telemetry) is what the agent sees by default; the quarantine is
// the explicit-opt-in second layer.
//
// Master plan §15 contract:
//   1. Deterministic Core (default)  — structured JSON only;
//      ambient retrieval toggle OFF; cloud agent only ever reads
//      sidecar-enriched content
//   2. Ambient Retrieval Protocol (toggle ON) — cloud agent gains
//      read-access to QuarantineArchive content; tool result names
//      MUST tag everything as `raw:` so the model attention is
//      grounded by source provenance (compass: "Tag every retrieved
//      chunk with `curated:` or `raw:` prefix in the tool result
//      name itself, not just metadata")
//
// Storage layout (compass spec):
//   ~/Library/Containers/<app>/Data/
//   ├── Curated.sqlite       ← deterministic, schema-versioned
//   └── Quarantine.sqlite    ← raw, append-only, separate vector index
//
//   ~/PKM/Vault/             ← curated, iCloud-synced
//   ~/PKM/RawThoughtsArchive/← excluded from iCloud via
//                              isExcludedFromBackupKey = true
//
// This module is the Swift surface; the SQLite-backed persistence
// layer follows in a Rust-side commit.

// MARK: - Quarantine entry kinds

nonisolated public enum QuarantineKind: String, Sendable, Codable, CaseIterable {
    case rawThought       // typed-into-the-app brain dump
    case voiceTranscript  // SpeechAnalyzer-captured dictation
    case ambientPaste     // pasted wall of unstructured text
}

// MARK: - Quarantine entry

nonisolated public struct QuarantineEntry: Sendable, Codable, Equatable, Identifiable {
    /// 26-char Crockford-base32 ULID — same shape as
    /// EpistemosSidecar.entityId so cross-references work.
    public var id: String

    /// What kind of raw thought is this.
    public var kind: QuarantineKind

    /// Unix timestamp (seconds) of capture.
    public var capturedAt: TimeInterval

    /// The raw, unstructured text the user dumped. NEVER edited by
    /// the system — append-only.
    public var body: String

    /// Optional context anchor — `chat_id`, `note_id`, `session_id`
    /// the user was looking at when they captured. Fed into the
    /// ambient-retrieval surface so the agent knows "this brain dump
    /// was in the context of THIS chat".
    public var anchor: QuarantineAnchor?

    public init(
        id: String,
        kind: QuarantineKind,
        capturedAt: TimeInterval = Date().timeIntervalSince1970,
        body: String,
        anchor: QuarantineAnchor? = nil
    ) {
        self.id = id
        self.kind = kind
        self.capturedAt = capturedAt
        self.body = body
        self.anchor = anchor
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, body, anchor
        case capturedAt = "captured_at"
    }
}

nonisolated public struct QuarantineAnchor: Sendable, Codable, Equatable, Hashable {
    public var contextKind: String   // "chat" | "note" | "session" | "agent"
    public var contextId: String     // opaque id of the surface

    public init(contextKind: String, contextId: String) {
        self.contextKind = contextKind
        self.contextId = contextId
    }

    enum CodingKeys: String, CodingKey {
        case contextKind = "context_kind"
        case contextId = "context_id"
    }
}

// MARK: - QuarantineArchive

/// Append-only store for raw / unstructured user thoughts. The agent
/// only sees this content when `AmbientRetrievalToggle` is ON.
///
/// Today this is an in-memory store with on-disk JSONL append-mode
/// fallback; the SQLite-backed Quarantine.sqlite (compass spec)
/// lands as a separate Rust commit. The Swift contract here is
/// stable so call sites don't need to change when the storage
/// backend swaps.
@MainActor
public final class QuarantineArchive {

    public static let shared = QuarantineArchive()

    nonisolated private static let log = Logger(
        subsystem: "com.epistemos",
        category: "QuarantineArchive"
    )

    /// In-memory entries. Replaced by SQLite-backed iteration when the
    /// Rust persistence layer lands.
    ///
    /// Capped at `maxInMemoryEntries` via sliding-window eviction in
    /// `capture(_:)` so a long-running session that brain-dumps
    /// thousands of entries doesn't grow this array unbounded. The
    /// on-disk JSONL archive (`entries.jsonl`) retains the full
    /// history; the in-memory copy is just the recent-tail working
    /// set for `snapshot()` / `entries(in:)`.
    private var entries: [QuarantineEntry] = []
    /// Sliding-window cap on `entries`. 5000 ≈ ~10 MB of
    /// `QuarantineEntry`s in the worst case (long markdown bodies
    /// + URLs); a typical brain-dumper hits this cap only after
    /// thousands of paste/voice events. The on-disk JSONL is the
    /// source of truth past this window.
    private let maxInMemoryEntries: Int = 5_000

    /// Append the entry to the in-memory log AND atomically append a
    /// JSONL line to the on-disk archive file. The on-disk write is
    /// best-effort — failure is logged but doesn't block the in-
    /// memory append (the user shouldn't lose their thought because
    /// of a transient I/O error).
    ///
    /// Wave 15 perf-fix #3: disk write is dispatched OFF the MainActor
    /// onto a background queue so the user-visible action that
    /// triggered the capture (paste, brain-dump dictate, voice tap)
    /// doesn't stall on file I/O. Previously the write was sync on
    /// MainActor (~8-12 ms for a 50 KB paste — visible jank on the
    /// next frame). The append-to-end semantics are still safe under
    /// the dispatch because diskQueue is serial.
    @discardableResult
    public func capture(
        _ entry: QuarantineEntry
    ) -> QuarantineEntry {
        entries.append(entry)
        // Sliding-window eviction — keep only the most recent
        // `maxInMemoryEntries`. Historical entries remain in the
        // on-disk JSONL archive.
        if entries.count > maxInMemoryEntries {
            let overflow = entries.count - maxInMemoryEntries
            entries.removeFirst(overflow)
        }
        diskQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.appendToDisk(entry)
            } catch {
                Self.log.warning(
                    "quarantine disk append failed (in-memory copy retained): \(error.localizedDescription, privacy: .public)"
                )
                // Edge-case mitigation: surface the failure so the UI
                // can show a non-blocking toast. The toast is opt-in
                // by call sites that observe the Notification.
                NotificationCenter.default.post(
                    name: Self.diskWriteFailedNotification,
                    object: nil,
                    userInfo: [
                        "entryId": entry.id,
                        "error": error.localizedDescription,
                    ]
                )
            }
        }
        return entry
    }

    /// Notification posted when the on-disk append fails (typically
    /// disk-full). UI can subscribe to surface a toast; the in-memory
    /// log is preserved either way.
    nonisolated public static let diskWriteFailedNotification = Notification.Name(
        "com.epistemos.quarantine.diskWriteFailed"
    )

    /// Serial background queue for disk writes — keeps append
    /// ordering stable while taking the I/O off the MainActor.
    private let diskQueue = DispatchQueue(
        label: "com.epistemos.quarantine.disk",
        qos: .userInitiated
    )

    /// Convenience capture — most call sites have a body + a
    /// QuarantineKind. Anchor is optional but encouraged for
    /// chat-context brain dumps. Mints the ULID id internally.
    @discardableResult
    public func capture(
        body: String,
        kind: QuarantineKind,
        anchor: QuarantineAnchor? = nil
    ) -> QuarantineEntry {
        let entry = QuarantineEntry(
            id: Self.makeEntryId(),
            kind: kind,
            body: body,
            anchor: anchor
        )
        return capture(entry)
    }

    public func snapshot() -> [QuarantineEntry] { entries }

    public func entries(in range: Range<TimeInterval>) -> [QuarantineEntry] {
        entries.filter { range.contains($0.capturedAt) }
    }

    public func reset() { entries.removeAll() }

    // MARK: - On-disk JSONL archive

    /// Path to the quarantine JSONL log under Application Support.
    /// Excluded from iCloud + Time Machine via
    /// `isExcludedFromBackupKey` per the compass storage spec.
    nonisolated private var archiveURL: URL? {
        let fm = FileManager.default
        guard let support = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        let bundle = Bundle.main.bundleIdentifier ?? "com.epistemos.Epistemos"
        let dir = support
            .appendingPathComponent(bundle, isDirectory: true)
            .appendingPathComponent("Quarantine", isDirectory: true)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            // Apply the backup-exclude flag once (idempotent — repeated
            // setResourceValues calls just rewrite the same xattr).
            var resourceURL = dir
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try? resourceURL.setResourceValues(resourceValues)
        } catch {
            return nil
        }
        return dir.appendingPathComponent("entries.jsonl")
    }

    nonisolated private func appendToDisk(_ entry: QuarantineEntry) throws {
        guard let url = archiveURL else { return }
        let data = try Self.encoder.encode(entry)
        var line = data
        line.append(0x0A)  // newline
        if let handle = try? FileHandle(forWritingTo: url) {
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
            try handle.close()
        } else {
            // File doesn't exist yet — atomic create.
            try line.write(to: url, options: [.atomic])
        }
    }

    /// Generate the same 26-char Crockford-base32 ULID shape as
    /// EpistemosSidecar.entityId so the two namespaces are
    /// interchangeable. Marked nonisolated so it can be called as a
    /// default-value expression from `nonisolated` contexts (e.g.
    /// the public `QuarantineEntry` initialisers).
    nonisolated public static func makeEntryId() -> String {
        EpistemosSidecarStore.makeEntityId()
    }

    nonisolated private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        // JSONL: one entry per line — NOT pretty-printed.
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return e
    }()
}

// MARK: - AmbientRetrievalToggle

/// Per-conversation toggle gating whether the agent gains read-
/// access to the QuarantineArchive. Master plan §15 contract:
/// default OFF for deterministic-core mode; user explicitly opts in
/// for the "messy sandbox" via a header chip in the chat UI.
///
/// Persistence is per-conversation so a user can have one
/// conversation in deterministic-only mode and another with ambient
/// retrieval ON for creative work.
@MainActor
@Observable
public final class AmbientRetrievalToggle {

    public static let shared = AmbientRetrievalToggle()

    /// Default for new conversations. Conservative: OFF.
    public var defaultForNewConversations: Bool = false {
        didSet {
            guard !isLoadingFromDefaults else { return }
            userDefaults.set(
                defaultForNewConversations,
                forKey: Self.defaultForNewConversationsKey
            )
        }
    }

    /// Explicit per-conversation enable map. Keys are conversation
    /// IDs; absence means "use default".
    private var perConversation: [String: Bool] = [:]

    @ObservationIgnored
    private var userDefaults: UserDefaults

    @ObservationIgnored
    private var isLoadingFromDefaults = false

    nonisolated private static let defaultForNewConversationsKey =
        "com.epistemos.ambientRetrieval.defaultForNewConversations"

    nonisolated private static let perConversationKey =
        "com.epistemos.ambientRetrieval.perConversation"

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadFromUserDefaults()
    }

    public func isEnabled(for conversationId: String) -> Bool {
        perConversation[conversationId] ?? defaultForNewConversations
    }

    public func setEnabled(_ enabled: Bool, for conversationId: String) {
        perConversation[conversationId] = enabled
        persistPerConversation()
    }

    public func reset(_ conversationId: String) {
        perConversation.removeValue(forKey: conversationId)
        persistPerConversation()
    }

    private func loadFromUserDefaults() {
        isLoadingFromDefaults = true
        defer { isLoadingFromDefaults = false }

        defaultForNewConversations =
            userDefaults.object(forKey: Self.defaultForNewConversationsKey) as? Bool
            ?? false

        let storedMap = userDefaults.dictionary(forKey: Self.perConversationKey) ?? [:]
        perConversation = storedMap.reduce(into: [String: Bool]()) { result, entry in
            if let enabled = entry.value as? Bool {
                result[entry.key] = enabled
            }
        }
    }

    private func persistPerConversation() {
        if perConversation.isEmpty {
            userDefaults.removeObject(forKey: Self.perConversationKey)
        } else {
            userDefaults.set(perConversation, forKey: Self.perConversationKey)
        }
    }

    #if DEBUG
    func setUserDefaultsForTesting(_ defaults: UserDefaults) {
        userDefaults = defaults
        loadFromUserDefaults()
    }

    func reloadFromUserDefaultsForTesting() {
        loadFromUserDefaults()
    }

    func resetForTesting() {
        isLoadingFromDefaults = true
        defaultForNewConversations = false
        perConversation.removeAll()
        isLoadingFromDefaults = false
        userDefaults = .standard
        loadFromUserDefaults()
    }
    #endif

    /// Per the compass spec: when ambient retrieval is enabled, every
    /// quarantine-sourced tool result must carry a `raw:` prefix in
    /// the result NAME (not just metadata) so the model's attention
    /// is grounded by source provenance.
    public static func toolResultPrefix(forQuarantineKind: QuarantineKind) -> String {
        "raw:"
    }

    /// Symmetric prefix for curated content so call sites can tag
    /// uniformly.
    public static let curatedToolResultPrefix: String = "curated:"
}
