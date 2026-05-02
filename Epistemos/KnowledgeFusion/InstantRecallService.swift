// Ω18 — Instant Recall Service
// Swift bridge to the Rust binary-quantized vector index.
// Provides <3ms vault-wide semantic search for note recall as you type.
//
// Data flow:
//   App startup / vault rebuild / note save → indexNote() or rebuildIndexAsync() → Rust binary index
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

private enum InstantRecallAsyncFailureClass: String, Sendable {
    case nonUTF8JSON = "non_utf8_json"
    case unexpectedJSONShape = "unexpected_json_shape"
    case jsonDecodeFailure = "json_decode_failure"
    case cancelled
}

private struct InstantRecallAsyncSearchOutcome: Sendable {
    let results: [InstantRecallResult]
    let elapsedMs: Double
    let failureClass: InstantRecallAsyncFailureClass?
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
    private let agentProvenanceRecorder: AgentToolProvenanceRecorder
    private var initialSnapshotProvider: (() -> [(id: String, text: String)])?
    private var hasHydratedInitialSnapshot = false
    private var searchSequence: UInt64 = 0
    private var asyncSearchSequence: UInt64 = 0

    init(agentProvenanceRecorder: AgentToolProvenanceRecorder = AgentToolProvenanceRecorder()) {
        self.agentProvenanceRecorder = agentProvenanceRecorder
    }

    private func ensureInitialized() {
        guard !isReady else { return }
        initialize()
    }

    private func hydrateInitialSnapshotIfNeeded() {
        guard !hasHydratedInitialSnapshot else { return }
        hasHydratedInitialSnapshot = true
        guard let initialSnapshotProvider else { return }
        // The provider closure is MainActor-isolated by virtue of being installed
        // by the AppBootstrap (also @MainActor). We must invoke it here on the
        // current actor so SwiftData reads stay safe, but the heavy FFI rebuild
        // — which dominates wall-clock for 1000+ note vaults — runs off-main on
        // a detached utility task. The final state mutation hops back to main.
        let snapshot = initialSnapshotProvider()
        let handle = self.handle
        Task.detached(priority: .utility) { [weak self] in
            let summary = Self.rebuildSnapshot(handle: handle, notes: snapshot)
            await MainActor.run {
                self?.finishRebuild(summary, candidateCount: snapshot.count)
            }
        }
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

        let runID = "instant-recall-\(UUID().uuidString)"
        let toolCallID = nextInstantRecallToolCallID()
        let actor = AgentProvenanceActor.agent(id: "instant-recall-service", modelID: nil)
        let queryCharacterCount = normalizedQueryText.count
        let queryTermCount = instantRecallQueryTermCount(normalizedQueryText)
        let argumentsJSON = instantRecallSearchArgumentsJSON(
            queryCharacterCount: queryCharacterCount,
            queryTermCount: queryTermCount,
            topK: topK
        )
        let baseMetadata = instantRecallSearchMetadata(
            queryCharacterCount: queryCharacterCount,
            queryTermCount: queryTermCount,
            topK: topK,
            surface: "instant_recall"
        )
        recordInstantRecallSearchEvent(
            runID: runID,
            kind: .toolCallRequested,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            status: .requested,
            metadata: baseMetadata
        )
        recordInstantRecallSearchEvent(
            runID: runID,
            kind: .toolCallStarted,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            status: .started,
            metadata: baseMetadata
        )
        let startedAt = Date()
        let start = CFAbsoluteTimeGetCurrent()
        let json = instantRecallSearch(handle: handle, queryText: normalizedQueryText, topK: UInt32(topK))
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0

        lastSearchLatencyMs = elapsed

        guard let data = json.data(using: .utf8) else {
            var metadata = baseMetadata
            metadata["failure_class"] = "non_utf8_json"
            log.error("InstantRecall: search returned non-UTF8 JSON payload")
            lastResults = []
            recordInstantRecallSearchEvent(
                runID: runID,
                kind: .toolCallFailed,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                resultJSON: instantRecallSearchResultJSON(
                    hitCount: 0,
                    documentCount: documentCount,
                    elapsedMs: elapsed
                ),
                durationMs: instantRecallDurationMilliseconds(since: startedAt),
                status: .failed,
                errorMessage: "non_utf8_json",
                metadata: metadata
            )
            return []
        }

        let array: [[String: Any]]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                var metadata = baseMetadata
                metadata["failure_class"] = "unexpected_json_shape"
                log.error("InstantRecall: search returned unexpected JSON shape")
                lastResults = []
                recordInstantRecallSearchEvent(
                    runID: runID,
                    kind: .toolCallFailed,
                    actor: actor,
                    toolCallID: toolCallID,
                    argumentsJSON: argumentsJSON,
                    resultJSON: instantRecallSearchResultJSON(
                        hitCount: 0,
                        documentCount: documentCount,
                        elapsedMs: elapsed
                    ),
                    durationMs: instantRecallDurationMilliseconds(since: startedAt),
                    status: .failed,
                    errorMessage: "unexpected_json_shape",
                    metadata: metadata
                )
                return []
            }
            array = parsed
        } catch {
            var metadata = baseMetadata
            metadata["failure_class"] = "json_decode_failure"
            log.error(
                "InstantRecall: failed to decode search payload: \(error.localizedDescription, privacy: .public)"
            )
            lastResults = []
            recordInstantRecallSearchEvent(
                runID: runID,
                kind: .toolCallFailed,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                resultJSON: instantRecallSearchResultJSON(
                    hitCount: 0,
                    documentCount: documentCount,
                    elapsedMs: elapsed
                ),
                durationMs: instantRecallDurationMilliseconds(since: startedAt),
                status: .failed,
                errorMessage: "json_decode_failure",
                metadata: metadata
            )
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

        var completedMetadata = baseMetadata
        completedMetadata["hit_count"] = String(results.count)
        completedMetadata["document_count"] = String(documentCount)
        recordInstantRecallSearchEvent(
            runID: runID,
            kind: .toolCallCompleted,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            resultJSON: instantRecallSearchResultJSON(
                hitCount: results.count,
                documentCount: documentCount,
                elapsedMs: elapsed
            ),
            durationMs: instantRecallDurationMilliseconds(since: startedAt),
            status: .completed,
            metadata: completedMetadata
        )

        if elapsed > 10.0 {
            log.warning("InstantRecall: search took \(String(format: "%.1f", elapsed))ms (target <3ms)")
        }

        return results
    }

    /// Unavailable sync vault-scan entrypoint retained for compile-time diagnostics.
    @available(*, unavailable, message: "Use rebuildIndexAsync(notes:) so vault-wide indexing runs off the MainActor.")
    func indexBatch(notes: [(id: String, text: String)]) {
    }

    /// Unavailable sync full-index rebuild retained for compile-time diagnostics.
    @available(*, unavailable, message: "Use rebuildIndexAsync(notes:) so vault-wide indexing runs off the MainActor.")
    func rebuildIndex(notes: [(id: String, text: String)]) {
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

    private func nextInstantRecallToolCallID() -> String {
        searchSequence = searchSequence == UInt64.max ? 1 : searchSequence + 1
        return "instant-recall-search:\(searchSequence)"
    }

    private func nextInstantRecallAsyncToolCallID() -> String {
        asyncSearchSequence = asyncSearchSequence == UInt64.max ? 1 : asyncSearchSequence + 1
        return "instant-recall-search-async:\(asyncSearchSequence)"
    }

    private func recordInstantRecallSearchEvent(
        runID: String,
        kind: AgentProvenanceEventKind,
        actor: AgentProvenanceActor,
        toolCallID: String,
        argumentsJSON: String,
        resultJSON: String? = nil,
        durationMs: UInt64? = nil,
        status: AgentToolEventStatus,
        errorMessage: String? = nil,
        metadata: [String: String]
    ) {
        agentProvenanceRecorder.recordToolEvent(
            runID: runID,
            traceID: nil,
            kind: kind,
            actor: actor,
            toolCallID: toolCallID,
            toolName: "instant_recall.search",
            argumentsJSON: argumentsJSON,
            resultJSON: resultJSON,
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
            metadata: metadata
        )
    }

    private func instantRecallSearchArgumentsJSON(
        queryCharacterCount: Int,
        queryTermCount: Int,
        topK: Int
    ) -> String {
        """
        {"query_char_count":\(queryCharacterCount),"query_term_count":\(queryTermCount),"top_k":\(topK)}
        """
    }

    private func instantRecallSearchResultJSON(
        hitCount: Int,
        documentCount: Int,
        elapsedMs: Double
    ) -> String {
        """
        {"hit_count":\(hitCount),"document_count":\(documentCount),"elapsed_ms":\(instantRecallJSONPayload(elapsedMs))}
        """
    }

    private func instantRecallSearchMetadata(
        queryCharacterCount: Int,
        queryTermCount: Int,
        topK: Int,
        surface: String
    ) -> [String: String] {
        [
            "source": "instant_recall_service",
            "surface": surface,
            "top_k": String(topK),
            "query_char_count": String(queryCharacterCount),
            "query_term_count": String(queryTermCount)
        ]
    }

    private func instantRecallDurationMilliseconds(since startedAt: Date) -> UInt64 {
        let elapsed = Date().timeIntervalSince(startedAt) * 1_000
        guard elapsed.isFinite, elapsed >= 0 else { return 0 }
        return UInt64(elapsed.rounded())
    }

    private func instantRecallJSONPayload(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        return String(format: "%.3f", value)
    }

    private func instantRecallQueryTermCount(_ value: String) -> Int {
        value.split(whereSeparator: { $0.isWhitespace }).count
    }

    // MARK: - Async search (Patch 7 / AMBIENT_RECALL_WIRING_PLAN §5)
    // Off-MainActor wrapper around the existing FFI search. The Contextual
    // Shadows V0 path uses this so the encoder + HNSW query never touches the
    // @MainActor boundary; only the `currentResults` mutation in the caller's
    // `await MainActor.run { ... }` block stays on main.
    //
    // We do NOT mutate any of the @MainActor metrics fields here — the
    // ambient hot path runs many times per session and bumping
    // `searchCount` / `lastSearchLatencyMs` from a detached task would
    // require either a hop back to main per call (expensive) or unsafe
    // cross-actor writes. Metrics belong to the explicit `search(...)` path.
    func searchAsync(query: String, topK: Int = 5) async -> [InstantRecallResult] {
        ensureInitialized()
        guard isReady else { return [] }
        let normalizedQueryText = normalizedQuery(query)
        guard !normalizedQueryText.isEmpty, topK > 0 else { return [] }
        hydrateInitialSnapshotIfNeeded()

        let runID = "instant-recall-async-\(UUID().uuidString)"
        let toolCallID = nextInstantRecallAsyncToolCallID()
        let actor = AgentProvenanceActor.agent(id: "instant-recall-service", modelID: nil)
        let queryCharacterCount = normalizedQueryText.count
        let queryTermCount = instantRecallQueryTermCount(normalizedQueryText)
        let argumentsJSON = instantRecallSearchArgumentsJSON(
            queryCharacterCount: queryCharacterCount,
            queryTermCount: queryTermCount,
            topK: topK
        )
        let baseMetadata = instantRecallSearchMetadata(
            queryCharacterCount: queryCharacterCount,
            queryTermCount: queryTermCount,
            topK: topK,
            surface: "instant_recall_async"
        )
        recordInstantRecallSearchEvent(
            runID: runID,
            kind: .toolCallRequested,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            status: .requested,
            metadata: baseMetadata
        )
        recordInstantRecallSearchEvent(
            runID: runID,
            kind: .toolCallStarted,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            status: .started,
            metadata: baseMetadata
        )

        let startedAt = Date()
        if Task.isCancelled {
            recordInstantRecallAsyncFailure(
                runID: runID,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                resultJSON: instantRecallSearchResultJSON(
                    hitCount: 0,
                    documentCount: documentCount,
                    elapsedMs: 0
                ),
                durationMs: instantRecallDurationMilliseconds(since: startedAt),
                metadata: baseMetadata,
                failureClass: .cancelled
            )
            return []
        }

        let handle = self.handle
        let outcome = await Task.detached(priority: .utility) {
            Self.runSearch(handle: handle, query: normalizedQueryText, topK: topK)
        }.value

        if Task.isCancelled {
            recordInstantRecallAsyncFailure(
                runID: runID,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                resultJSON: instantRecallSearchResultJSON(
                    hitCount: 0,
                    documentCount: documentCount,
                    elapsedMs: outcome.elapsedMs
                ),
                durationMs: instantRecallDurationMilliseconds(since: startedAt),
                metadata: baseMetadata,
                failureClass: .cancelled
            )
            return []
        }

        if let failureClass = outcome.failureClass {
            recordInstantRecallAsyncFailure(
                runID: runID,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                resultJSON: instantRecallSearchResultJSON(
                    hitCount: 0,
                    documentCount: documentCount,
                    elapsedMs: outcome.elapsedMs
                ),
                durationMs: instantRecallDurationMilliseconds(since: startedAt),
                metadata: baseMetadata,
                failureClass: failureClass
            )
            return []
        }

        var completedMetadata = baseMetadata
        completedMetadata["hit_count"] = String(outcome.results.count)
        completedMetadata["document_count"] = String(documentCount)
        recordInstantRecallSearchEvent(
            runID: runID,
            kind: .toolCallCompleted,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            resultJSON: instantRecallSearchResultJSON(
                hitCount: outcome.results.count,
                documentCount: documentCount,
                elapsedMs: outcome.elapsedMs
            ),
            durationMs: instantRecallDurationMilliseconds(since: startedAt),
            status: .completed,
            metadata: completedMetadata
        )

        return outcome.results
    }

    nonisolated private static let asyncLog = Logger(subsystem: "com.epistemos.app", category: "InstantRecall")

    private nonisolated static func runSearch(
        handle: String,
        query: String,
        topK: Int
    ) -> InstantRecallAsyncSearchOutcome {
        let start = CFAbsoluteTimeGetCurrent()
        let json = instantRecallSearch(handle: handle, queryText: query, topK: UInt32(topK))
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0

        guard let data = json.data(using: .utf8) else {
            asyncLog.error("InstantRecall: searchAsync returned non-UTF8 JSON payload")
            return InstantRecallAsyncSearchOutcome(
                results: [],
                elapsedMs: elapsed,
                failureClass: .nonUTF8JSON
            )
        }
        let array: [[String: Any]]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                asyncLog.error("InstantRecall: searchAsync returned unexpected JSON shape")
                return InstantRecallAsyncSearchOutcome(
                    results: [],
                    elapsedMs: elapsed,
                    failureClass: .unexpectedJSONShape
                )
            }
            array = parsed
        } catch {
            asyncLog.error(
                "InstantRecall: failed to decode searchAsync payload: \(error.localizedDescription, privacy: .public)"
            )
            return InstantRecallAsyncSearchOutcome(
                results: [],
                elapsedMs: elapsed,
                failureClass: .jsonDecodeFailure
            )
        }
        let results = array.compactMap { dict -> InstantRecallResult? in
            guard let docId = dict["doc_id"] as? String,
                  let text = dict["text"] as? String,
                  let score = dict["score"] as? Double else { return nil }
            return InstantRecallResult(id: docId, text: text, score: score)
        }
        return InstantRecallAsyncSearchOutcome(
            results: results,
            elapsedMs: elapsed,
            failureClass: nil
        )
    }

    private func recordInstantRecallAsyncFailure(
        runID: String,
        actor: AgentProvenanceActor,
        toolCallID: String,
        argumentsJSON: String,
        resultJSON: String,
        durationMs: UInt64,
        metadata: [String: String],
        failureClass: InstantRecallAsyncFailureClass
    ) {
        var failureMetadata = metadata
        failureMetadata["failure_class"] = failureClass.rawValue
        recordInstantRecallSearchEvent(
            runID: runID,
            kind: .toolCallFailed,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            resultJSON: resultJSON,
            durationMs: durationMs,
            status: .failed,
            errorMessage: failureClass.rawValue,
            metadata: failureMetadata
        )
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
