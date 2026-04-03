// Ω18 — Instant Recall Service
// Swift bridge to the Rust binary-quantized vector index.
// Provides <3ms vault-wide semantic search for note recall as you type.
//
// Data flow:
//   App startup / vault rebuild / note save → indexNote() or rebuildIndex() → Rust binary index
//   Note chat query → search() → top relevant notes
//
// The service manages a single index handle ("vault") backed by
// epistemos-core's flat binary index with two-phase retrieval.

import Foundation
import os.log

private let log = Logger(subsystem: "com.epistemos.app", category: "InstantRecall")

private struct InstantRecallRebuildSummary: Sendable {
    let insertedCount: Int
    let documentCount: Int
    let elapsedMs: Double
}

/// Result from an instant recall search.
struct InstantRecallResult: Identifiable, Sendable {
    let id: String  // doc_id
    let text: String
    let score: Double

    var docId: String { id }
}

/// Manages the binary-quantized vector index for instant vault recall.
@MainActor @Observable
final class InstantRecallService {

    /// Whether the index has been initialized.
    private(set) var isReady = false

    /// Number of documents currently indexed.
    private(set) var documentCount: Int = 0

    /// Most recent search results (updated on each query).
    private(set) var lastResults: [InstantRecallResult] = []

    /// Latency of the last search in milliseconds.
    private(set) var lastSearchLatencyMs: Double = 0

    /// Number of successful recall searches performed since initialization.
    private(set) var searchCount: Int = 0

    /// Average latency across successful recall searches.
    private(set) var averageSearchLatencyMs: Double = 0

    /// Maximum observed latency across successful recall searches.
    private(set) var maxSearchLatencyMs: Double = 0

    private let handle = "vault"
    private var initialSnapshotProvider: (() -> [(id: String, text: String)])?
    private var hasHydratedInitialSnapshot = false

    private func ensureInitialized() {
        guard !isReady else { return }
        initialize()
    }

    private func hydrateInitialSnapshotIfNeeded() {
        guard !hasHydratedInitialSnapshot else { return }
        hasHydratedInitialSnapshot = true
        guard let initialSnapshotProvider else { return }
        rebuildIndex(notes: initialSnapshotProvider())
    }

    func configureInitialSnapshotProvider(
        _ provider: @escaping () -> [(id: String, text: String)]
    ) {
        initialSnapshotProvider = provider
        hasHydratedInitialSnapshot = false
    }

    /// Initialize and create the Rust index.
    func initialize() {
        let success = instantRecallCreate(handle: handle)
        isReady = success
        documentCount = success ? Int(instantRecallCount(handle: handle)) : 0
        lastResults = []
        lastSearchLatencyMs = 0
        searchCount = 0
        averageSearchLatencyMs = 0
        maxSearchLatencyMs = 0
        if success {
            log.info("InstantRecall: index created (handle: \(self.handle))")
        } else {
            log.error("InstantRecall: failed to create index")
        }
    }

    private nonisolated static func normalizedIndexableText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : text
    }

    private func normalizedQuery(_ queryText: String) -> String {
        queryText
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func rebuildSnapshot(
        handle: String,
        notes: [(id: String, text: String)]
    ) -> InstantRecallRebuildSummary {
        let start = CFAbsoluteTimeGetCurrent()
        let _ = instantRecallClear(handle: handle)

        var insertedCount = 0
        for note in notes {
            guard let indexableText = Self.normalizedIndexableText(note.text) else { continue }
            let _ = instantRecallInsert(handle: handle, docId: note.id, text: indexableText)
            insertedCount += 1
        }

        let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
        let documentCount = Int(instantRecallCount(handle: handle))
        return InstantRecallRebuildSummary(
            insertedCount: insertedCount,
            documentCount: documentCount,
            elapsedMs: elapsedMs
        )
    }

    private func finishRebuild(
        _ summary: InstantRecallRebuildSummary,
        candidateCount: Int
    ) {
        documentCount = summary.documentCount
        lastResults = []
        lastSearchLatencyMs = 0
        searchCount = 0
        averageSearchLatencyMs = 0
        maxSearchLatencyMs = 0

        log.info(
            "InstantRecall: rebuilt index with \(summary.insertedCount) notes from \(candidateCount) candidates in \(String(format: "%.1f", summary.elapsedMs))ms"
        )
    }

    /// Index a note's content. Call on note save or edit (debounced).
    func indexNote(noteId: String, text: String) {
        ensureInitialized()
        guard isReady else { return }
        guard let indexableText = Self.normalizedIndexableText(text) else {
            removeNote(noteId: noteId)
            return
        }

        let _ = instantRecallInsert(handle: handle, docId: noteId, text: indexableText)
        documentCount = Int(instantRecallCount(handle: handle))
    }

    /// Remove a note from the index (on note deletion).
    func removeNote(noteId: String) {
        ensureInitialized()
        guard isReady else { return }
        let _ = instantRecallRemove(handle: handle, docId: noteId)
        documentCount = Int(instantRecallCount(handle: handle))
        lastResults.removeAll { $0.docId == noteId }
    }

    /// Search for notes similar to the query text.
    /// Updates `lastResults` and `lastSearchLatencyMs`.
    func search(queryText: String, topK: Int = 5) -> [InstantRecallResult] {
        ensureInitialized()
        guard isReady else {
            lastResults = []
            lastSearchLatencyMs = 0
            return []
        }

        let normalizedQueryText = normalizedQuery(queryText)
        guard !normalizedQueryText.isEmpty, topK > 0 else {
            lastResults = []
            lastSearchLatencyMs = 0
            return []
        }

        hydrateInitialSnapshotIfNeeded()

        let start = CFAbsoluteTimeGetCurrent()
        let json = instantRecallSearch(handle: handle, queryText: normalizedQueryText, topK: UInt32(topK))
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0

        lastSearchLatencyMs = elapsed

        guard let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            lastResults = []
            return []
        }

        let results = array.compactMap { dict -> InstantRecallResult? in
            guard let docId = dict["doc_id"] as? String,
                  let text = dict["text"] as? String,
                  let score = dict["score"] as? Double else { return nil }
            return InstantRecallResult(id: docId, text: text, score: score)
        }

        lastResults = results
        documentCount = Int(instantRecallCount(handle: handle))
        searchCount += 1
        averageSearchLatencyMs += (elapsed - averageSearchLatencyMs) / Double(searchCount)
        maxSearchLatencyMs = max(maxSearchLatencyMs, elapsed)

        if elapsed > 10.0 {
            log.warning("InstantRecall: search took \(String(format: "%.1f", elapsed))ms (target <3ms)")
        }

        return results
    }

    /// Index all notes from a vault scan. Call during app startup.
    func indexBatch(notes: [(id: String, text: String)]) {
        ensureInitialized()
        guard isReady else { return }
        hasHydratedInitialSnapshot = true

        let start = CFAbsoluteTimeGetCurrent()

        for note in notes {
            guard let indexableText = Self.normalizedIndexableText(note.text) else { continue }
            let _ = instantRecallInsert(handle: handle, docId: note.id, text: indexableText)
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
        documentCount = Int(instantRecallCount(handle: handle))
        lastResults = []
        lastSearchLatencyMs = 0

        log.info("InstantRecall: indexed \(self.documentCount) notes from \(notes.count) candidates in \(String(format: "%.1f", elapsed))ms")
    }

    /// Replace the entire index with a fresh note snapshot.
    func rebuildIndex(notes: [(id: String, text: String)]) {
        ensureInitialized()
        guard isReady else { return }
        hasHydratedInitialSnapshot = true

        let summary = Self.rebuildSnapshot(handle: handle, notes: notes)
        finishRebuild(summary, candidateCount: notes.count)
    }

    func rebuildIndexAsync(notes: [(id: String, text: String)]) async {
        ensureInitialized()
        guard isReady else { return }
        hasHydratedInitialSnapshot = true

        let handle = self.handle
        let summary = await Task.detached(priority: .utility) {
            Self.rebuildSnapshot(handle: handle, notes: notes)
        }.value

        finishRebuild(summary, candidateCount: notes.count)
    }

    /// Clear the entire index.
    func clearIndex() {
        ensureInitialized()
        guard isReady else { return }
        let _ = instantRecallClear(handle: handle)
        documentCount = 0
        lastResults = []
        lastSearchLatencyMs = 0
        searchCount = 0
        averageSearchLatencyMs = 0
        maxSearchLatencyMs = 0
        log.info("InstantRecall: index cleared")
    }
}
