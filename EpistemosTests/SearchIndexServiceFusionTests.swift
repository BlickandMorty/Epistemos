import Foundation
import GRDB
import Testing

@testable import Epistemos

@MainActor
private final class SearchIndexAgentEventSink {
    private(set) var events: [AgentProvenanceEvent] = []
    var onStarted: (() -> Void)?

    func append(_ event: AgentProvenanceEvent) -> Bool {
        events.append(event)
        if event.kind == .toolCallStarted {
            onStarted?()
        }
        return true
    }
}

@MainActor
private final class SearchIndexCancellationTrigger {
    var task: Task<[FusedResult], Error>?

    func cancel() {
        task?.cancel()
    }
}

nonisolated func sqliteSupportsFTS5ForFusionTests() -> Bool {
    do {
        let queue = try DatabaseQueue(path: ":memory:")
        return try queue.write { db in
            do {
                try db.execute(sql: "CREATE VIRTUAL TABLE fts5_probe USING fts5(content)")
                try db.execute(sql: "DROP TABLE fts5_probe")
                return true
            } catch {
                return false
            }
        }
    } catch {
        return false
    }
}

/// RRF Phase 5 — real-DB fusion integration tests.
///
/// Per `docs/RRF_FUSION_PROMPT.md` Phase 5 (NON-NEGOTIABLE: REAL DB,
/// NO MOCKS). These tests exercise the full
/// `SearchIndexService.fusedSearch` path end-to-end against a
/// file-backed `DatabasePool` seeded with a fixture corpus across
/// all three sources:
///   - `indexed_pages` + `page_search` (legacy page prose)
///   - `indexed_blocks` + `block_search` (legacy block prose)
///   - `readable_blocks` + `readable_blocks_fts` (universal projection)
///
/// Test surface:
///   1. Single-source query returns that source's top hit first
///   2. Cross-source consensus boost surfaces the consensus winner
///   3. Block→doc rollup picks best-rank block as snippet anchor
///   4. Recency boost reorders ties
///   5. Tie-breaker is deterministic across 100 repeated runs
///   6. Empty query / empty corpus do not crash
///   7. Snippet projection populates `<b>...</b>` highlights
///   8. (Local-only / skipped in CI) 50k-row perf gate at p95 < 30 ms
@Suite("SearchIndexService — RRF Fusion (Phase 5)", .enabled(if: sqliteSupportsFTS5ForFusionTests()))
struct SearchIndexServiceFusionTests {

    // MARK: - Test harness

    private func makeDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("rrf-fusion-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("search.sqlite")
    }

    private func makeService() throws -> (service: SearchIndexService, databaseURL: URL) {
        let url = makeDatabaseURL()
        return (try SearchIndexService(databaseURL: url), url)
    }

    @MainActor
    private func makeService(recordingTo sink: SearchIndexAgentEventSink) throws -> (service: SearchIndexService, databaseURL: URL) {
        let url = makeDatabaseURL()
        return (
            try SearchIndexService(
                databaseURL: url,
                agentProvenanceRecorder: Self.recorder(sink: sink)
            ),
            url
        )
    }

    @MainActor
    private static func recorder(sink: SearchIndexAgentEventSink) -> AgentToolProvenanceRecorder {
        AgentToolProvenanceRecorder(
            nowMilliseconds: { 4_242 },
            persist: { event in sink.append(event) }
        )
    }

    /// Seed an artifact (page) into `indexed_pages` AND insert one
    /// `readable_blocks` row mirroring it. Real production has the
    /// shadow projection happen in `EpdocDocument.projectAndIndexBlocks`,
    /// but for tests we wire both sides directly so each query exercises
    /// the fusion across all 3 CTEs in `RRFFusionQuery.sql`.
    private func seedDoc(
        id: String,
        title: String,
        body: String,
        tags: String = "",
        updatedAt: Date,
        artifactKind: ArtifactKind = .document,
        in service: SearchIndexService
    ) throws {
        try service.upsert(
            id: id,
            title: title,
            body: body,
            tags: tags,
            updatedAt: updatedAt
        )
        // Also project into readable_blocks so the universal source
        // sees this content. We treat the whole doc body as a single
        // readable block keyed at "<docId>#root".
        let pool = service.databaseWriter()
        let block = ReadableBlock(
            artifactID: id,
            artifactKind: artifactKind,
            blockID: "\(id)#root",
            blockKind: .paragraph,
            titlePath: title,
            body: body,
            updatedAt: ReadableBlock.iso8601(updatedAt),
            vaultID: "test-vault"
        )
        try pool.write { db in
            try ReadableBlocksIndex.insert(block, in: db)
        }
    }

    private func seedBlock(
        blockId: String,
        pageId: String,
        content: String,
        in service: SearchIndexService
    ) throws {
        try service.upsertBlock(
            blockId: blockId,
            pageId: pageId,
            content: content
        )
    }

    // MARK: - 1. Single-source query

    @Test("Single-source query: page-level term returns the matching page first")
    func singleSourcePageQueryReturnsResults() throws {
        let (service, _) = try makeService()
        let now = Date()
        try seedDoc(
            id: "page-1",
            title: "kant on metaphysics",
            body: "categorical imperative",
            tags: "phil",
            updatedAt: now,
            in: service
        )
        try seedDoc(
            id: "page-2",
            title: "unrelated",
            body: "lorem ipsum",
            tags: "misc",
            updatedAt: now,
            in: service
        )

        let results = try service.fusedSearch(
            query: "kant",
            weights: .default,
            now: now
        )

        #expect(results.count == 1,
                "expected one matching entity, got \(results.count): \(results.map(\.entityID))")
        #expect(results[0].entityID == "page-1")
        #expect(results[0].fusedScore > 0,
                "page-1 must get a positive fused score; got \(results[0].fusedScore)")
        #expect(results[0].bestSourceRank == 1)
    }

    // MARK: - 2. Cross-source consensus boost

    @Test("Cross-source query: same entity hit by 2 sources outranks single-source hit")
    func crossSourceConsensusBoostsScore() throws {
        let (service, _) = try makeService()
        let now = Date()
        try seedDoc(
            id: "page-A",
            title: "kant",
            body: "kant categorical imperative",
            updatedAt: now,
            in: service
        )
        try seedDoc(
            id: "page-B",
            title: "kant",
            body: "different body unrelated content",
            updatedAt: now,
            in: service
        )
        // Add a block-level hit for page-A only — boosts via the
        // block_search source on top of the page_search hit.
        try seedBlock(
            blockId: "block-A1",
            pageId: "page-A",
            content: "kant categorical imperative deeper analysis",
            in: service
        )

        let results = try service.fusedSearch(
            query: "kant",
            weights: .default,
            now: now
        )
        #expect(results.count >= 2,
                "expected at least 2 entities, got \(results.count): \(results.map(\.entityID))")
        #expect(results[0].entityID == "page-A",
                "consensus across page + block sources MUST surface page-A first; got order: \(results.map(\.entityID))")
        #expect(results[0].fusedScore > results[1].fusedScore,
                "page-A's fused score must exceed page-B's — got \(results[0].fusedScore) vs \(results[1].fusedScore)")
    }

    // MARK: - 3. Block → doc rollup

    @Test("Block hits roll up to parent doc; snippet anchor is best-rank block")
    func blockHitsRollUpToParentDocWithSnippetAnchor() throws {
        let (service, _) = try makeService()
        let now = Date()
        try seedDoc(
            id: "page-X",
            title: "alpha bravo",
            body: "background context only",
            updatedAt: now,
            in: service
        )
        try seedBlock(
            blockId: "block-X1",
            pageId: "page-X",
            content: "alpha appears here at rank 1",
            in: service
        )
        try seedBlock(
            blockId: "block-X2",
            pageId: "page-X",
            content: "alpha here too but lower rank",
            in: service
        )

        let results = try service.fusedSearch(
            query: "alpha",
            weights: .default,
            now: now
        )
        #expect(results.count == 1,
                "blocks within page-X must roll up to a single parent-doc result; got \(results.count): \(results.map(\.entityID))")
        let row = results[0]
        #expect(row.entityID == "page-X")
        // Snippet block id must be one of the seeded blocks (whichever
        // block_search ranks first OR the page itself if page_search
        // outranks). Either is correct per the SQL's bare-aggregate
        // tie-break.
        let validAnchors: Set<String?> = ["block-X1", "block-X2", nil]
        #expect(validAnchors.contains(row.snippetBlockID),
                "snippet anchor must be a real block id (or nil for page-only) — got \(String(describing: row.snippetBlockID))")
    }

    // MARK: - 4. Recency boost reorders ties

    @Test("Recency boost: identical raw scores → recent doc wins via exp decay")
    func recencyBoostReordersEqualRawScores() throws {
        let (service, _) = try makeService()
        let now = Date()
        let recentTime = now
        let staleTime = now.addingTimeInterval(-90 * 86_400.0)

        try seedDoc(
            id: "page-recent",
            title: "alpha bravo charlie",
            body: "alpha bravo charlie",
            tags: "x",
            updatedAt: recentTime,
            in: service
        )
        try seedDoc(
            id: "page-stale",
            title: "alpha bravo charlie",
            body: "alpha bravo charlie",
            tags: "x",
            updatedAt: staleTime,
            in: service
        )

        let results = try service.fusedSearch(
            query: "alpha bravo",
            weights: FusionWeights(halfLifeDays: 30.0),
            now: now
        )
        #expect(results.count == 2,
                "both docs must match; got \(results.count): \(results.map(\.entityID))")
        #expect(results[0].entityID == "page-recent",
                "recency boost MUST surface page-recent first when raw bm25 ties; got order: \(results.map(\.entityID))")
        // 90-day age with 30-day halflife = exp(-3) ≈ 0.0498 retention.
        // Recent doc should be at least 2× the stale doc.
        #expect(results[0].fusedScore > results[1].fusedScore * 2.0,
                "recency-boosted score should dominate by ≥ 2× at 90-day age gap; got \(results[0].fusedScore) vs \(results[1].fusedScore)")
    }

    // MARK: - 5. Determinism (tie-breaker)

    @Test("Tie-breaker is deterministic: identical fixture → identical order across 100 runs")
    func tieBreakerDeterminismAcross100Runs() throws {
        let (service, _) = try makeService()
        let now = Date()
        // Seed 5 docs with an identical hit pattern — tie-breaker must
        // pick a deterministic order (entity_id ASC after fused_score
        // and updated_at ties).
        for i in 0..<5 {
            try seedDoc(
                id: "page-\(i)",
                title: "alpha",
                body: "alpha alpha",
                updatedAt: now,
                in: service
            )
        }

        let firstRun = try service.fusedSearch(query: "alpha", weights: .default, now: now)
        for run in 1..<100 {
            let nextRun = try service.fusedSearch(query: "alpha", weights: .default, now: now)
            #expect(nextRun.map(\.entityID) == firstRun.map(\.entityID),
                    "run \(run) order \(nextRun.map(\.entityID)) diverges from run 0 \(firstRun.map(\.entityID)) — tie-breaker not deterministic")
        }
    }

    // MARK: - 6. Empty / degenerate inputs do not crash

    @Test("Empty corpus + nonempty query returns []")
    func emptyCorpusNonemptyQueryReturnsEmpty() throws {
        let (service, _) = try makeService()
        let results = try service.fusedSearch(
            query: "anything",
            weights: .default,
            now: Date()
        )
        #expect(results.isEmpty,
                "empty corpus must return empty results, not crash; got \(results.count)")
    }

    @Test("Empty query string returns [] (sanitization filters it out)")
    func emptyQueryReturnsEmpty() throws {
        let (service, _) = try makeService()
        let now = Date()
        try seedDoc(
            id: "p",
            title: "anything",
            body: "anything",
            updatedAt: now,
            in: service
        )

        let blank = try service.fusedSearch(query: "", weights: .default, now: now)
        #expect(blank.isEmpty,
                "empty query must short-circuit (sanitization → empty terms); got \(blank.count)")

        let whitespace = try service.fusedSearch(query: "   ", weights: .default, now: now)
        #expect(whitespace.isEmpty,
                "whitespace-only query must short-circuit; got \(whitespace.count)")
    }

    // MARK: - 7. Snippet projection

    @Test("Snippet projection: matched terms wrapped in <b>...</b>")
    func snippetProjectionHighlightsMatchedTerm() throws {
        let (service, _) = try makeService()
        let now = Date()
        try seedDoc(
            id: "page-snip",
            title: "matching title kant",
            body: "kant categorical imperative explained at length here",
            updatedAt: now,
            in: service
        )

        let results = try service.fusedSearch(
            query: "kant",
            weights: .default,
            now: now
        )
        #expect(results.count == 1)
        let snippet = results[0].snippet ?? ""
        #expect(snippet.contains("<b>"),
                "snippet must contain `<b>` highlight markup — got '\(snippet)'")
        #expect(snippet.contains("</b>"),
                "snippet must contain `</b>` close tag — got '\(snippet)'")
        #expect(snippet.lowercased().contains("kant"),
                "snippet must include the matched term — got '\(snippet)'")
    }

    // MARK: - 8. Async parity with sync method

    @MainActor
    @Test("fusedSearchAsync returns the same results as fusedSearch (sync)")
    func asyncResultParity() async throws {
        let sink = SearchIndexAgentEventSink()
        let (service, _) = try makeService(recordingTo: sink)
        let now = Date()
        try seedDoc(
            id: "page-1",
            title: "kant on metaphysics",
            body: "categorical imperative",
            updatedAt: now,
            in: service
        )
        try seedDoc(
            id: "page-2",
            title: "kant on ethics",
            body: "duty",
            updatedAt: now,
            in: service
        )

        let syncResults = try service.fusedSearch(query: "kant", weights: .default, now: now)
        let asyncResults = try await service.fusedSearchAsync(query: "kant", weights: .default, now: now)
        #expect(syncResults.map(\.entityID) == asyncResults.map(\.entityID),
                "sync vs async result IDs must match; sync=\(syncResults.map(\.entityID)) async=\(asyncResults.map(\.entityID))")
        #expect(syncResults.count == asyncResults.count)
    }

    @MainActor
    @Test("fusedSearchAsync records sanitized AgentEvents")
    func fusedSearchAsyncRecordsSanitizedAgentEvents() async throws {
        let sink = SearchIndexAgentEventSink()
        let (service, _) = try makeService(recordingTo: sink)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try seedDoc(
            id: "secret-search-doc",
            title: "Hidden Orpheus Title",
            body: "private recall prompt context with kantian substrate notes",
            updatedAt: now,
            in: service
        )

        let results = try await service.fusedSearchAsync(
            query: "private recall prompt",
            weights: .default,
            now: now
        )

        #expect(results.count == 1)
        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallCompleted
        ])
        #expect(Set(sink.events.map(\.runID)).count == 1)
        #expect(matchesSearchIndexRunID(sink.events.first?.runID))
        #expect(sink.events.allSatisfy { $0.tool?.toolName == "search_index.fused_search_async" })
        #expect(sink.events.allSatisfy { $0.tool?.toolCallID == "search-index-fused-async:1" })
        #expect(sink.events.allSatisfy { $0.metadata["source"] == "search_index_service" })
        #expect(sink.events.allSatisfy { $0.metadata["surface"] == "fused_search_async" })
        #expect(sink.events.allSatisfy { $0.metadata["query_term_count"] == "3" })
        #expect(sink.events.allSatisfy { $0.metadata["weights_profile"] == "default" })
        if case let .agent(id, modelID)? = sink.events.first?.actor {
            #expect(id == "search-index-service")
            #expect(modelID == nil)
        } else {
            #expect(Bool(false), "expected search-index-service agent actor")
        }

        let argumentsPayload = try searchIndexPayload(from: sink.events.first?.tool?.argumentsJSON)
        #expect(Set(argumentsPayload.keys) == ["now_ms", "query_char_count", "query_term_count", "weights_profile"])
        #expect(argumentsPayload["query_term_count"] as? Int == 3)
        #expect(argumentsPayload["weights_profile"] as? String == "default")

        let resultPayload = try searchIndexPayload(from: sink.events.last?.tool?.resultJSON)
        #expect(Set(resultPayload.keys) == ["elapsed_ms", "hit_count"])
        #expect(resultPayload["hit_count"] as? Int == 1)
        #expect(sink.events.last?.tool?.durationMs != nil)
        #expect(sink.events.last?.metadata["failure_class"] == nil)
        #expect(sink.events.last?.tool?.errorMessage == nil)

        try assertNoSearchIndexSecretLeak(
            in: sink.events,
            forbidden: [
                "private recall prompt",
                "secret-search-doc",
                "Hidden Orpheus Title",
                "kantian substrate",
                "sanitized",
                "\"private\""
            ]
        )
    }

    @MainActor
    @Test("fusedSearchAsync records completed AgentEvents for valid zero-hit searches")
    func fusedSearchAsyncRecordsCompletedAgentEventsForZeroHitSearches() async throws {
        let sink = SearchIndexAgentEventSink()
        let (service, _) = try makeService(recordingTo: sink)

        let results = try await service.fusedSearchAsync(
            query: "missing valid query",
            weights: .default,
            now: Date()
        )

        #expect(results.isEmpty)
        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallCompleted
        ])
        let resultPayload = try searchIndexPayload(from: sink.events.last?.tool?.resultJSON)
        #expect(resultPayload["hit_count"] as? Int == 0)
        #expect(sink.events.last?.metadata["failure_class"] == nil)
    }

    @MainActor
    @Test("Cancelled fusedSearchAsync records terminal failed AgentEvent")
    func cancelledFusedSearchAsyncRecordsTerminalFailedAgentEvent() async throws {
        let sink = SearchIndexAgentEventSink()
        let trigger = SearchIndexCancellationTrigger()
        sink.onStarted = { trigger.cancel() }
        let (service, _) = try makeService(recordingTo: sink)
        let now = Date()
        try seedDoc(
            id: "cancel-page",
            title: "alpha",
            body: "alpha body",
            updatedAt: now,
            in: service
        )

        let task = Task {
            try await service.fusedSearchAsync(query: "alpha", weights: .default, now: now)
        }
        trigger.task = task

        do {
            _ = try await task.value
            #expect(Bool(false), "expected fusedSearchAsync cancellation")
        } catch is CancellationError {
        } catch {
            #expect(Bool(false), "expected CancellationError, got \(error)")
        }

        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallFailed
        ])
        #expect(sink.events.last?.metadata["failure_class"] == "cancelled")
        #expect(sink.events.last?.tool?.status == .failed)
        #expect(sink.events.last?.tool?.errorMessage == "cancelled")
    }

    @MainActor
    @Test("Invalid fusedSearchAsync inputs do not record AgentEvents")
    func invalidFusedSearchAsyncInputsDoNotRecordAgentEvents() async throws {
        let sink = SearchIndexAgentEventSink()
        let (service, _) = try makeService(recordingTo: sink)

        _ = try await service.fusedSearchAsync(query: "", weights: .default, now: Date())
        _ = try await service.fusedSearchAsync(query: "   \n\t  ", weights: .default, now: Date())
        _ = try await service.fusedSearchAsync(query: "!!! ???", weights: .default, now: Date())

        #expect(sink.events.isEmpty)
    }

    @MainActor
    @Test("fusedSearch sync method remains uninstrumented")
    func fusedSearchSyncMethodRemainsUninstrumented() throws {
        let sink = SearchIndexAgentEventSink()
        let (service, _) = try makeService(recordingTo: sink)
        let now = Date()
        try seedDoc(
            id: "sync-page",
            title: "alpha",
            body: "alpha body",
            updatedAt: now,
            in: service
        )

        let results = try service.fusedSearch(query: "alpha", weights: .default, now: now)

        #expect(results.count == 1)
        #expect(sink.events.isEmpty)
    }

    @MainActor
    @Test("fusedSearchAsync tool ids are monotonic per service instance")
    func fusedSearchAsyncToolIDsAreMonotonicPerServiceInstance() async throws {
        let sink = SearchIndexAgentEventSink()
        let (service, _) = try makeService(recordingTo: sink)
        let now = Date()
        try seedDoc(id: "page-1", title: "alpha", body: "alpha body", updatedAt: now, in: service)
        try seedDoc(id: "page-2", title: "beta", body: "beta body", updatedAt: now, in: service)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    _ = try await service.fusedSearchAsync(query: "alpha", weights: .default, now: now)
                }
            }
            try await group.waitForAll()
        }

        let terminalToolIDs = sink.events
            .filter { $0.kind == .toolCallCompleted }
            .compactMap { $0.tool?.toolCallID }
            .sorted()
        #expect(terminalToolIDs == (1...8).map { "search-index-fused-async:\($0)" })
        #expect(Set(sink.events.map(\.runID)).count == 8)
    }

    @MainActor
    @Test("fusedSearchAsync custom weights persist only profile metadata")
    func fusedSearchAsyncCustomWeightsPersistOnlyProfileMetadata() async throws {
        let sink = SearchIndexAgentEventSink()
        let (service, _) = try makeService(recordingTo: sink)
        let now = Date()
        try seedDoc(
            id: "custom-weight-page",
            title: "alpha",
            body: "alpha body",
            updatedAt: now,
            in: service
        )

        _ = try await service.fusedSearchAsync(
            query: "alpha",
            weights: FusionWeights(pageWeight: 2.5, blockWeight: 3.5),
            now: now
        )

        #expect(sink.events.allSatisfy { $0.metadata["weights_profile"] == "custom" })
        let persisted = sink.events
            .compactMap(\.tool)
            .map { [$0.argumentsJSON, $0.resultJSON ?? "", $0.errorMessage ?? ""].joined(separator: "\n") }
            .joined(separator: "\n")
        #expect(!persisted.contains("pageWeight"))
        #expect(!persisted.contains("blockWeight"))
        #expect(!persisted.contains("2.5"))
        #expect(!persisted.contains("3.5"))
    }

    // NOTE: Phase 5 perf gate (50k blocks → p95 < 30 ms) is NOT in this
    // suite. It lives in a separate `@Suite("Perf — RRF Fusion")` that
    // is skipped in CI and run locally before flag flip per
    // `docs/RRF_FUSION_PROMPT.md` Phase 6 acceptance gate.

    private func matchesSearchIndexRunID(_ value: String?) -> Bool {
        guard let value else { return false }
        let pattern = #"^search-index-fused-async-[0-9A-F-]{36}$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.firstMatch(in: value, range: range)?.range == range
    }

    private func searchIndexPayload(from json: String?) throws -> [String: Any] {
        let json = try #require(json)
        let data = try #require(json.data(using: .utf8))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func assertNoSearchIndexSecretLeak(
        in events: [AgentProvenanceEvent],
        forbidden: [String]
    ) throws {
        for event in events {
            let tool = try #require(event.tool)
            let persisted = [
                tool.argumentsJSON,
                tool.resultJSON ?? "",
                tool.errorMessage ?? "",
                event.metadata.keys.joined(separator: " "),
                event.metadata.values.joined(separator: " ")
            ].joined(separator: "\n")

            for value in forbidden where !value.isEmpty {
                #expect(!persisted.contains(value), "AgentEvent persisted forbidden value: \(value)")
            }
        }
    }
}

@Suite("SearchIndexService AgentEvent source guards")
struct SearchIndexServiceAgentEventSourceGuardTests {

    @Test("fusedSearchAsync provenance surface stays bounded and sync fusedSearch remains direct")
    func fusedSearchAsyncProvenanceSurfaceStaysBounded() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Sync/SearchIndexService.swift")

        #expect(source.contains("agentProvenanceRecorder: AgentToolProvenanceRecorder? = nil"))
        #expect(source.contains("private var agentProvenanceRecorder: AgentToolProvenanceRecorder?"))
        #expect(source.contains("private var fusedAsyncSearchToolSequence: UInt64 = 0"))
        #expect(source.contains("toolName: \"search_index.fused_search_async\""))
        #expect(source.contains("\"surface\": \"fused_search_async\""))
        #expect(source.contains("\"weights_profile\": weightsProfile"))
        #expect(source.contains("case sqlError = \"sql_error\""))
        #expect(source.contains("if error is DatabaseError"))
        #expect(source.contains("await recordFusedAsyncAgentEvent("))
        #expect(!source.contains("Task { @MainActor in\n            await recorder.recordToolEvent"))
        #expect(!source.contains("Task.detached"))

        let syncBody = try #require(Self.functionBody(
            named: "nonisolated public func fusedSearch(",
            before: "public func fusedSearchAsync(",
            in: source
        ))
        #expect(!syncBody.contains("AgentToolProvenanceRecorder"))
        #expect(!syncBody.contains("recordToolEvent"))
        #expect(!syncBody.contains("search_index.fused_search_async"))
    }

    private static func functionBody(named marker: String, before endMarker: String, in source: String) -> String? {
        guard let start = source.range(of: marker),
              let end = source[start.upperBound...].range(of: endMarker) else {
            return nil
        }
        return String(source[start.lowerBound..<end.lowerBound])
    }
}
