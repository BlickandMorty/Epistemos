import Foundation
import Testing

@testable import Epistemos

@MainActor
private final class ShadowSearchAgentEventSink {
    private(set) var events: [AgentProvenanceEvent] = []

    func append(_ event: AgentProvenanceEvent) -> Bool {
        events.append(event)
        return true
    }
}

nonisolated private final class ThrowingShadowFFIClient: ShadowFFIClient, @unchecked Sendable {
    private let error: ShadowFFIError

    init(error: ShadowFFIError) {
        self.error = error
    }

    func insert(document: ShadowDocumentDTO) throws {}
    func remove(docId: String) throws {}
    func search(query: String, domain: ShadowDomain, limit: Int) throws -> [ShadowHit] { throw error }
    func flush() throws {}
    func warm() throws {}
    func stats() throws -> ShadowStatsDTO {
        ShadowStatsDTO(noteCount: 0, chatCount: 0, indexSizeBytes: 0, lastFlushMsAgo: UInt64.max)
    }
}

nonisolated private final class SlowShadowFFIClient: ShadowFFIClient, @unchecked Sendable {
    func insert(document: ShadowDocumentDTO) throws {}
    func remove(docId: String) throws {}

    func search(query: String, domain: ShadowDomain, limit: Int) throws -> [ShadowHit] {
        Thread.sleep(forTimeInterval: 0.05)
        return [
            ShadowHit(
                id: "slow-secret-doc",
                title: "Slow Secret Title",
                snippet: "Slow secret snippet",
                score: 1.0,
                domain: domain,
                source: "slow-test"
            )
        ]
    }

    func flush() throws {}
    func warm() throws {}
    func stats() throws -> ShadowStatsDTO {
        ShadowStatsDTO(noteCount: 0, chatCount: 0, indexSizeBytes: 0, lastFlushMsAgo: UInt64.max)
    }
}

/// Wave 8.3 source-guard for the shadow service actors
/// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 8.3,
///  cross-ref `ambient/EPISTEMOS_V1_DECISION.md` §"Concurrency").
///
/// The actors bridge the @MainActor HaloController to the synchronous
/// `ShadowFFIClient` so the FFI hop stays off the main thread. Tests
/// drive the actors through an `InMemoryShadowFFIClient` so the contract
/// is covered without depending on the Rust dylib being loadable.
@MainActor
@Suite("Shadow service actors (Wave 8.3)", .serialized)
struct ShadowServicesTests {

    private static func inMemoryClient() -> InMemoryShadowFFIClient {
        InMemoryShadowFFIClient()
    }

    private static func note(_ id: String, title: String = "title", body: String = "body") -> ShadowDocumentDTO {
        ShadowDocumentDTO(docId: id, title: title, body: body, domain: .notes)
    }

    private static func recorder(sink: ShadowSearchAgentEventSink) -> AgentToolProvenanceRecorder {
        AgentToolProvenanceRecorder(
            nowMilliseconds: { 2_318 },
            persist: { event in sink.append(event) }
        )
    }

    // MARK: - InMemoryShadowFFIClient sanity

    @Test("In-memory client round-trips a single document via insert + search")
    func inMemoryClientInsertSearchRoundTrip() throws {
        let client = Self.inMemoryClient()
        try client.insert(document: Self.note("n1", title: "Kant on duty", body: "Categorical imperative"))
        let hits = try client.search(query: "kant", domain: .notes, limit: 10)
        #expect(hits.count == 1)
        #expect(hits.first?.id == "n1")
        #expect(hits.first?.score ?? 0 > 0)
        #expect(hits.first?.source == "in-memory-substring")
    }

    @Test("Shadow fallback provenance labels are honest")
    func shadowFallbackProvenanceLabelsAreHonest() throws {
        let checkedPaths = [
            "epistemos-shadow/src/state.rs",
            "epistemos-shadow/src/lib.rs",
            "epistemos-shadow/src/backend/mod.rs",
            "Epistemos/Engine/ShadowFFIClient.swift",
            "Epistemos/Models/HaloState.swift",
        ]

        for path in checkedPaths {
            let source = try loadMirroredSourceTextFile(path)
            #expect(!source.contains("stub-substring"), "\(path) must not emit stale stub provenance")
            #expect(!source.contains("W8.1 stub"), "\(path) must not describe Shadow fallback as the shipped backend")
            #expect(!source.contains("ShadowState stub"), "\(path) must use fallback wording")
            #expect(!source.contains("STUB_FALLBACK"), "\(path) must use fallback wording")
        }

        let rustState = try loadMirroredSourceTextFile("epistemos-shadow/src/state.rs")
        let swiftClient = try loadMirroredSourceTextFile("Epistemos/Engine/ShadowFFIClient.swift")
        let haloState = try loadMirroredSourceTextFile("Epistemos/Models/HaloState.swift")

        #expect(rustState.contains("IN_MEMORY_FALLBACK"))
        #expect(rustState.contains("source: \"in-memory-substring\""))
        #expect(swiftClient.contains("source: \"in-memory-substring\""))
        #expect(swiftClient.contains("InMemoryShadowFFIClient"))
        #expect(swiftClient.contains("com.epistemos.shadow.in-memory"))
        #expect(!swiftClient.contains("StubShadowFFIClient"))
        #expect(!swiftClient.contains("com.epistemos.shadow.stub"))
        #expect(haloState.contains("\"in-memory-substring\""))
    }

    @Test("In-memory client filters search by domain")
    func inMemoryClientDomainFilter() throws {
        let client = Self.inMemoryClient()
        try client.insert(document: ShadowDocumentDTO(docId: "n1", title: "kant", body: "kant", domain: .notes))
        try client.insert(document: ShadowDocumentDTO(docId: "c1", title: "kant", body: "kant", domain: .chats))
        let notesHits = try client.search(query: "kant", domain: .notes, limit: 10)
        let chatsHits = try client.search(query: "kant", domain: .chats, limit: 10)
        #expect(notesHits.count == 1)
        #expect(chatsHits.count == 1)
        #expect(notesHits.first?.id == "n1")
        #expect(chatsHits.first?.id == "c1")
    }

    @Test("In-memory client throws .invalidInput on empty doc_id")
    func inMemoryClientRejectsEmptyDocId() {
        let client = Self.inMemoryClient()
        do {
            try client.insert(document: Self.note(""))
            #expect(Bool(false), "must throw on empty doc_id")
        } catch let error as ShadowFFIError {
            switch error {
            case .invalidInput: break
            default: #expect(Bool(false), "wrong error case: \(error)")
            }
        } catch {
            #expect(Bool(false), "wrong error type: \(error)")
        }
    }

    @Test("In-memory client throws .notFound when removing an unknown doc")
    func inMemoryClientRemoveUnknown() {
        let client = Self.inMemoryClient()
        do {
            try client.remove(docId: "missing")
            #expect(Bool(false), "must throw on unknown doc")
        } catch let error as ShadowFFIError {
            switch error {
            case .notFound: break
            default: #expect(Bool(false), "wrong error case: \(error)")
            }
        } catch {
            #expect(Bool(false), "wrong error type: \(error)")
        }
    }

    // MARK: - ShadowDocumentDTO sidecar wire format

    @Test("ShadowDocumentDTO omits origin_vault_key when nil (pre-sidecar byte-identical contract)")
    func shadowDocumentDTOOmitsNilOriginVaultKey() throws {
        // Pre-sidecar consumers (vaults indexed before 2026-05-15) must
        // see byte-identical document JSON. The Rust side enforces this
        // via `skip_serializing_if = "Option::is_none"`; the Swift side
        // mirrors it through a custom `encode(to:)` that uses
        // `encodeIfPresent` for the field. Without this, every
        // document JSON would gain a `"origin_vault_key": null` entry
        // and break wire-format parity.
        let doc = ShadowDocumentDTO(
            docId: "n1",
            title: "Kant on duty",
            body: "Categorical imperative",
            domain: .notes
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let bytes = try encoder.encode(doc)
        let json = String(data: bytes, encoding: .utf8) ?? ""
        #expect(!json.contains("origin_vault_key"),
                "nil originVaultKey MUST NOT serialize an `origin_vault_key` field; got: \(json)")
    }

    @Test("ShadowDocumentDTO round-trips origin_vault_key when populated")
    func shadowDocumentDTORoundTripsOriginVaultKey() throws {
        // Populated case: the field encodes as `"origin_vault_key"`
        // (snake_case per Rust contract) and decodes back to the same
        // value. This is the load-bearing wire-format parity the
        // shadow sidecar work (commit 2add62b8e) depends on.
        let original = ShadowDocumentDTO(
            docId: "n2",
            title: "vault-alpha note",
            body: "body",
            domain: .notes,
            originVaultKey: "vault-alpha"
        )
        let encoder = JSONEncoder()
        let bytes = try encoder.encode(original)
        let json = String(data: bytes, encoding: .utf8) ?? ""
        #expect(json.contains("\"origin_vault_key\""))
        #expect(json.contains("\"vault-alpha\""))

        let decoded = try JSONDecoder().decode(ShadowDocumentDTO.self, from: bytes)
        #expect(decoded.originVaultKey == "vault-alpha")
        #expect(decoded.docId == original.docId)
        #expect(decoded.title == original.title)
        #expect(decoded.body == original.body)
    }

    @Test("InMemoryShadowFFIClient echoes origin_vault_key from doc to hit (Rust state.rs parity)")
    func inMemoryClientEchoesOriginVaultKey() throws {
        // The Rust `state.rs` in-memory fallback copies the document's
        // `origin_vault_key` onto the matching `ShadowHit`. The Swift
        // `InMemoryShadowFFIClient` must mirror that contract so tests
        // exercising the fallback path see the field round-trip — without
        // it, the lenient nil-passthrough vault filter would silently
        // drop the key on the Swift side and the two backends would
        // diverge.
        let client = Self.inMemoryClient()
        try client.insert(document: ShadowDocumentDTO(
            docId: "vault-alpha-n1",
            title: "Kant",
            body: "duty",
            domain: .notes,
            originVaultKey: "vault-alpha"
        ))
        try client.insert(document: ShadowDocumentDTO(
            docId: "no-key-n2",
            title: "Kant",
            body: "duty alt",
            domain: .notes
        ))
        let hits = try client.search(query: "kant", domain: .notes, limit: 10)
        #expect(hits.count == 2)
        let alphaHit = hits.first { $0.id == "vault-alpha-n1" }
        let nilKeyHit = hits.first { $0.id == "no-key-n2" }
        #expect(alphaHit?.originVaultKey == "vault-alpha",
                "in-memory client MUST echo originVaultKey from doc to hit")
        #expect(nilKeyHit?.originVaultKey == nil,
                "doc inserted without originVaultKey MUST produce a hit with originVaultKey == nil")
    }

    @Test("ShadowDocumentDTO decodes pre-sidecar JSON without origin_vault_key field")
    func shadowDocumentDTODecodesPreSidecarJSON() throws {
        // The other half of byte-identical: a document JSON that
        // predates the field must still decode cleanly with
        // `originVaultKey == nil`. Without this, the rollout
        // would break every doc indexed before 2026-05-15.
        let preSidecarJSON = """
        {"doc_id":"old-n1","title":"Old","body":"body","domain":"note"}
        """
        let data = Data(preSidecarJSON.utf8)
        let decoded = try JSONDecoder().decode(ShadowDocumentDTO.self, from: data)
        #expect(decoded.originVaultKey == nil)
        #expect(decoded.docId == "old-n1")
    }

    // MARK: - ShadowFFIError code mapping

    @Test("ShadowFFIError mirrors the Rust ShadowError numeric discriminants")
    func ffiErrorCodeMapping() {
        // Match the Rust `ShadowError::as_code()` table 1:1.
        #expect(ShadowFFIError.from(rustCode: 0) == nil, "0 is success, not an error")
        if case let .invalidInput(detail)? = ShadowFFIError.from(rustCode: -1, detail: "x") {
            #expect(detail == "x")
        } else { #expect(Bool(false)) }
        if case let .notFound(id)? = ShadowFFIError.from(rustCode: -2, detail: "n1") {
            #expect(id == "n1")
        } else { #expect(Bool(false)) }
        if case .ioFailure? = ShadowFFIError.from(rustCode: -3) {} else { #expect(Bool(false)) }
        if case .backendFailure? = ShadowFFIError.from(rustCode: -4) {} else { #expect(Bool(false)) }
        if case .rustPanic? = ShadowFFIError.from(rustCode: -99) {} else { #expect(Bool(false)) }
        if case let .unknownCode(c)? = ShadowFFIError.from(rustCode: -123) {
            #expect(c == -123, "forward-compat: unknown numeric codes round-trip via .unknownCode")
        } else { #expect(Bool(false)) }
    }

    // MARK: - ShadowSearchService

    @Test("ShadowSearchService.search returns hits from the underlying client")
    func searchServiceReturnsHits() async throws {
        let sink = ShadowSearchAgentEventSink()
        let client = Self.inMemoryClient()
        try client.insert(document: Self.note("n1", title: "Kant", body: "duty"))
        let service = ShadowSearchService(client: client, agentProvenanceRecorder: Self.recorder(sink: sink))
        let hits = await service.search(text: "kant", domain: .notes, limit: 10)
        #expect(hits.count == 1)
        #expect(hits.first?.id == "n1")
    }

    @Test("ShadowSearchService.search swallows errors into an empty result")
    func searchServiceSwallowsErrors() async {
        let sink = ShadowSearchAgentEventSink()
        // Domain mismatch in the client raises an error in the real
        // backend; the service wrapper logs + returns []. The in-memory
        // fallback doesn't error on unknown domain (our enum already
        // constrains to the two allowed values), so this asserts the
        // .notes happy-path stays consistent.
        let client = Self.inMemoryClient()
        let service = ShadowSearchService(client: client, agentProvenanceRecorder: Self.recorder(sink: sink))
        let hits = await service.search(text: "anything", domain: .notes, limit: 10)
        #expect(hits.isEmpty,
                "empty index returns empty hits without throwing on the controller's hot path")
    }

    @Test("ShadowSearchService.searchOrThrow surfaces the underlying error")
    func searchServiceSearchOrThrowSurfacesError() async throws {
        let sink = ShadowSearchAgentEventSink()
        // Force an empty-query case that returns an empty result;
        // searchOrThrow should not throw, just return [].
        let client = Self.inMemoryClient()
        let service = ShadowSearchService(client: client, agentProvenanceRecorder: Self.recorder(sink: sink))
        let hits = try await service.searchOrThrow(text: "", domain: .notes, limit: 5)
        #expect(hits.isEmpty)
    }

    @Test("ShadowSearchService.search records sanitized AgentEvents")
    func searchServiceRecordsSanitizedAgentEvents() async throws {
        let sink = ShadowSearchAgentEventSink()
        let client = Self.inMemoryClient()
        try client.insert(document: Self.note(
            "secret-shadow-doc",
            title: "Hidden Orpheus Title",
            body: "Forbidden shadow body with private recall prompt context"
        ))
        let service = ShadowSearchService(client: client, agentProvenanceRecorder: Self.recorder(sink: sink))

        let hits = await service.search(text: "private recall prompt", domain: .notes, limit: 10)

        #expect(hits.count == 1)
        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallCompleted
        ])
        #expect(Set(sink.events.map(\.runID)).count == 1)
        #expect(sink.events.first?.runID.hasPrefix("shadow-search-") == true)
        #expect(sink.events.allSatisfy { $0.tool?.toolName == "shadow_search.search" })
        #expect(sink.events.allSatisfy { $0.tool?.toolCallID == "shadow-search:1" })
        #expect(sink.events.allSatisfy { $0.metadata["source"] == "shadow_search_service" })
        #expect(sink.events.allSatisfy { $0.metadata["surface"] == "shadow_search" })
        #expect(sink.events.allSatisfy { $0.metadata["domain"] == "note" })
        #expect(sink.events.allSatisfy { $0.metadata["limit"] == "10" })

        let argumentsPayload = try shadowSearchPayload(from: sink.events.first?.tool?.argumentsJSON)
        #expect(Set(argumentsPayload.keys) == ["domain", "limit", "query_char_count", "query_term_count"])
        #expect(argumentsPayload["domain"] as? String == "note")
        #expect(argumentsPayload["limit"] as? Int == 10)

        let resultPayload = try shadowSearchPayload(from: sink.events.last?.tool?.resultJSON)
        #expect(Set(resultPayload.keys) == ["domain", "hit_count", "elapsed_ms"])
        #expect(resultPayload["domain"] as? String == "note")
        #expect(resultPayload["hit_count"] as? Int == 1)
        #expect(sink.events.last?.tool?.durationMs != nil)
        #expect(sink.events.last?.metadata["failure_class"] == nil)
        #expect(sink.events.last?.tool?.errorMessage == nil)

        try assertNoShadowSearchSecretLeak(
            in: sink.events,
            forbidden: [
                "private recall prompt",
                "secret-shadow-doc",
                "Hidden Orpheus Title",
                "Forbidden shadow body",
                "in-memory-substring"
            ]
        )
    }

    @Test("ShadowSearchService.search records completed AgentEvents for valid zero-hit results")
    func searchServiceRecordsCompletedAgentEventsForZeroHitResults() async throws {
        let sink = ShadowSearchAgentEventSink()
        let service = ShadowSearchService(
            client: Self.inMemoryClient(),
            agentProvenanceRecorder: Self.recorder(sink: sink)
        )

        let hits = await service.search(text: "missing valid query", domain: .notes, limit: 5)

        #expect(hits.isEmpty)
        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallCompleted
        ])
        let resultPayload = try shadowSearchPayload(from: sink.events.last?.tool?.resultJSON)
        #expect(Set(resultPayload.keys) == ["domain", "hit_count", "elapsed_ms"])
        #expect(resultPayload["hit_count"] as? Int == 0)
        #expect(sink.events.last?.metadata["failure_class"] == nil)
    }

    @Test("ShadowSearchService.search records failed AgentEvents with closed failure classes")
    func searchServiceRecordsFailedAgentEventsWithClosedFailureClasses() async throws {
        ShadowSearchDiagnostics.shared.reset()
        defer { ShadowSearchDiagnostics.shared.reset() }

        let sink = ShadowSearchAgentEventSink()
        let service = ShadowSearchService(
            client: ThrowingShadowFFIClient(error: .backendFailure(detail: "secret backend detail")),
            agentProvenanceRecorder: Self.recorder(sink: sink)
        )

        let hits = await service.search(text: "private recall prompt", domain: .notes, limit: 5)

        #expect(hits.isEmpty)
        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallFailed
        ])
        #expect(sink.events.last?.metadata["failure_class"] == "backend_failure")
        #expect(sink.events.last?.tool?.status == .failed)
        #expect(sink.events.last?.tool?.errorMessage == "backend_failure")
        #expect(Self.allowedShadowSearchFailureClasses.contains(sink.events.last?.tool?.errorMessage ?? ""))

        let resultPayload = try shadowSearchPayload(from: sink.events.last?.tool?.resultJSON)
        #expect(Set(resultPayload.keys) == ["domain", "hit_count", "elapsed_ms"])
        #expect(resultPayload["hit_count"] as? Int == 0)

        try assertNoShadowSearchSecretLeak(
            in: sink.events,
            forbidden: ["private recall prompt", "secret backend detail", "backendFailure"]
        )

        let snapshot = ShadowSearchDiagnostics.shared.snapshot()
        #expect(snapshot.isDegraded)
        #expect(snapshot.totalSearches == 1)
        #expect(snapshot.totalFailures == 1)
        #expect(snapshot.consecutiveFailures == 1)
        #expect(snapshot.lastDomain == "note")
        #expect(snapshot.lastHitCount == 0)
        #expect(snapshot.lastFailureClass == "backend_failure")
        #expect(!String(describing: snapshot).contains("secret backend detail"))
    }

    @Test("ShadowSearchDiagnostics recovers after a successful Shadow search")
    func shadowSearchDiagnosticsRecoversAfterSuccessfulSearch() async throws {
        ShadowSearchDiagnostics.shared.reset()
        defer { ShadowSearchDiagnostics.shared.reset() }

        let failingService = ShadowSearchService(
            client: ThrowingShadowFFIClient(error: .backendFailure(detail: "secret backend detail")),
            agentProvenanceRecorder: Self.recorder(sink: ShadowSearchAgentEventSink())
        )
        _ = await failingService.search(text: "private recall prompt", domain: .notes, limit: 5)
        #expect(ShadowSearchDiagnostics.shared.snapshot().isDegraded)

        let client = Self.inMemoryClient()
        try client.insert(document: Self.note("n1", title: "Kant", body: "duty"))
        let recoveringService = ShadowSearchService(
            client: client,
            agentProvenanceRecorder: Self.recorder(sink: ShadowSearchAgentEventSink())
        )
        let hits = await recoveringService.search(text: "kant", domain: .notes, limit: 5)

        let snapshot = ShadowSearchDiagnostics.shared.snapshot()
        #expect(hits.count == 1)
        #expect(!snapshot.isDegraded)
        #expect(snapshot.totalSearches == 2)
        #expect(snapshot.totalFailures == 1)
        #expect(snapshot.consecutiveFailures == 0)
        #expect(snapshot.lastDomain == "note")
        #expect(snapshot.lastHitCount == 1)
        #expect(snapshot.lastFailureClass == nil)
    }

    @Test("Cancelled ShadowSearchService.search records terminal failed AgentEvent")
    func cancelledSearchServiceRecordsTerminalFailedAgentEvent() async throws {
        let sink = ShadowSearchAgentEventSink()
        let service = ShadowSearchService(
            client: SlowShadowFFIClient(),
            agentProvenanceRecorder: Self.recorder(sink: sink)
        )

        let task = Task {
            await service.search(text: "private recall prompt", domain: .notes, limit: 5)
        }
        for _ in 0..<100 {
            if sink.events.count >= 2 { break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        #expect(sink.events.count >= 2)

        task.cancel()
        let hits = await task.value

        #expect(hits.isEmpty)
        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallFailed
        ])
        #expect(sink.events.last?.metadata["failure_class"] == "cancelled")
        #expect(sink.events.last?.tool?.status == .failed)
        #expect(sink.events.last?.tool?.errorMessage == "cancelled")
    }

    @Test("Invalid ShadowSearchService.search inputs do not record AgentEvents")
    func invalidSearchServiceInputsDoNotRecordAgentEvents() async {
        let sink = ShadowSearchAgentEventSink()
        let service = ShadowSearchService(
            client: Self.inMemoryClient(),
            agentProvenanceRecorder: Self.recorder(sink: sink)
        )

        _ = await service.search(text: "", domain: .notes, limit: 5)
        _ = await service.search(text: "   \n\t  ", domain: .notes, limit: 5)
        _ = await service.search(text: "private recall prompt", domain: .notes, limit: 0)
        _ = await service.search(text: "private recall prompt", domain: .notes, limit: -1)

        #expect(sink.events.isEmpty)
    }

    @Test("ShadowSearchService tool ids are monotonic per service instance")
    func shadowSearchToolIDsAreMonotonicPerServiceInstance() async throws {
        let sink = ShadowSearchAgentEventSink()
        let recorder = Self.recorder(sink: sink)
        let firstClient = Self.inMemoryClient()
        let secondClient = Self.inMemoryClient()
        try firstClient.insert(document: Self.note("first", title: "Alpha", body: "alpha body"))
        try secondClient.insert(document: Self.note("second", title: "Beta", body: "beta body"))
        let firstService = ShadowSearchService(client: firstClient, agentProvenanceRecorder: recorder)
        let secondService = ShadowSearchService(client: secondClient, agentProvenanceRecorder: recorder)

        _ = await firstService.search(text: "alpha", domain: .notes, limit: 5)
        _ = await firstService.search(text: "alpha", domain: .notes, limit: 5)
        _ = await secondService.search(text: "beta", domain: .notes, limit: 5)

        let terminalToolIDs = sink.events
            .filter { $0.kind == .toolCallCompleted }
            .compactMap { $0.tool?.toolCallID }

        #expect(terminalToolIDs == [
            "shadow-search:1",
            "shadow-search:2",
            "shadow-search:1"
        ])
        #expect(Set(sink.events.map(\.runID)).count == 3)
    }

    @Test("ShadowSearchService.searchOrThrow and stats stay direct")
    func searchOrThrowAndStatsStayDirect() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/ShadowSearchService.swift")
        #expect(source.contains("public func searchOrThrow(text: String, domain: ShadowDomain, limit: Int) throws -> [ShadowHit] {"))
        #expect(source.contains("let hits = try client.search(query: text, domain: domain, limit: limit)"))
        #expect(source.contains("ShadowSearchDiagnostics.shared.recordSuccess("))
        #expect(source.contains("ShadowSearchDiagnostics.shared.recordFailure("))
        #expect(!source.contains("searchOrThrow(text: String, domain: ShadowDomain, limit: Int) async"))
        #expect(source.contains("""
    public func stats() async throws -> ShadowStatsDTO {
        try client.stats()
    }
"""))
    }

    // MARK: - ShadowIndexingService

    @Test("Indexing service batches inserts into one flush after debounce")
    func indexingBatchesInserts() async throws {
        let client = Self.inMemoryClient()
        let policy = ShadowIndexingPolicy(flushDebounceMs: 50, maxBatchSize: 256)
        let svc = ShadowIndexingService(client: client, policy: policy)

        for i in 0..<5 {
            await svc.enqueueInsert(Self.note("n\(i)"))
        }
        // Wait for the debounce + drain.
        try await Task.sleep(nanoseconds: 200_000_000)
        let stats = try client.stats()
        #expect(stats.noteCount == 5,
                "all 5 enqueued inserts must have landed via the FFI client after the debounce")

        let totalInserts = await svc.totalInserts
        let totalFlushes = await svc.totalFlushes
        #expect(totalInserts == 5)
        #expect(totalFlushes >= 1, "exactly one flush should have run for a contiguous burst")
    }

    @Test("Indexing service coalesces back-to-back ops on the same doc_id")
    func indexingCoalescesSameDocId() async throws {
        let client = Self.inMemoryClient()
        let policy = ShadowIndexingPolicy(flushDebounceMs: 50, maxBatchSize: 256)
        let svc = ShadowIndexingService(client: client, policy: policy)

        // Three updates to the same doc inside the debounce window.
        await svc.enqueueInsert(Self.note("n1", body: "first"))
        await svc.enqueueInsert(Self.note("n1", body: "second"))
        await svc.enqueueInsert(Self.note("n1", body: "third"))
        try await Task.sleep(nanoseconds: 200_000_000)

        let totalInserts = await svc.totalInserts
        #expect(totalInserts == 1,
                "three back-to-back updates on the same doc_id must coalesce into ONE FFI insert (last write wins)")

        let stats = try client.stats()
        #expect(stats.noteCount == 1)
    }

    @Test("Indexing service handles insert-then-remove coalescing")
    func indexingCoalescesInsertThenRemove() async throws {
        let client = Self.inMemoryClient()
        let policy = ShadowIndexingPolicy(flushDebounceMs: 50, maxBatchSize: 256)
        let svc = ShadowIndexingService(client: client, policy: policy)

        await svc.enqueueInsert(Self.note("n1"))
        await svc.enqueueRemove(docId: "n1")
        try await Task.sleep(nanoseconds: 200_000_000)

        let totalInserts = await svc.totalInserts
        let totalRemoves = await svc.totalRemoves
        #expect(totalInserts == 0,
                "insert superseded by remove on same doc_id must NOT hit the FFI")
        #expect(totalRemoves == 1,
                "remove should still run via the FFI even after coalescing")

        let stats = try client.stats()
        #expect(stats.noteCount == 0)
    }

    @Test("Indexing service flushes immediately when the batch hits maxBatchSize")
    func indexingForcesFlushAtMaxBatchSize() async throws {
        let client = Self.inMemoryClient()
        let policy = ShadowIndexingPolicy(flushDebounceMs: 10_000, maxBatchSize: 4)
        let svc = ShadowIndexingService(client: client, policy: policy)

        for i in 0..<4 {
            await svc.enqueueInsert(Self.note("n\(i)"))
        }
        // Wait briefly — far less than the 10s debounce.
        try await Task.sleep(nanoseconds: 200_000_000)

        let totalInserts = await svc.totalInserts
        #expect(totalInserts == 4,
                "back-pressure: hitting maxBatchSize must force an immediate flush even with a long debounce")
    }

    @Test("flushNow drains the queue regardless of debounce timer")
    func indexingFlushNowDrainsImmediately() async throws {
        let client = Self.inMemoryClient()
        let policy = ShadowIndexingPolicy(flushDebounceMs: 10_000, maxBatchSize: 256)
        let svc = ShadowIndexingService(client: client, policy: policy)

        await svc.enqueueInsert(Self.note("n1"))
        await svc.enqueueInsert(Self.note("n2"))
        await svc.flushNow()

        let totalInserts = await svc.totalInserts
        let totalFlushes = await svc.totalFlushes
        #expect(totalInserts == 2)
        #expect(totalFlushes >= 1)
    }

    private static let allowedShadowSearchFailureClasses: Set<String> = [
        "invalid_input",
        "not_found",
        "io_failure",
        "backend_failure",
        "rust_panic",
        "unknown_code",
        "cancelled",
        "unknown_error"
    ]

    private func shadowSearchPayload(from json: String?) throws -> [String: Any] {
        let json = try #require(json)
        let data = try #require(json.data(using: .utf8))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func assertNoShadowSearchSecretLeak(
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

/// W9.21 PR4 guard: the Rust honest-handle foundation is only useful
/// once the Swift consumer stops using the legacy global `shadow_*`
/// surface. Keep this as a source-level test so it fails before we
/// accidentally regress back to orphan scaffolding.
@Suite("Shadow honest-handle source guards")
struct ShadowHonestHandleSourceGuardTests {

    @Test("RustShadowFFIClient owns a shadow_handle pointer and AppBootstrap constructs it directly")
    func swiftConsumerUsesOwnedShadowHandle() throws {
        let client = try loadMirroredSourceTextFile("Epistemos/Engine/RustShadowFFIClient.swift")
        let bootstrap = try loadMirroredSourceTextFile("Epistemos/App/AppBootstrap.swift")

        for symbol in [
            "shadow_handle_open_at",
            "shadow_handle_release",
            "shadow_handle_search",
            "shadow_handle_insert",
            "shadow_handle_remove",
            "shadow_handle_flush",
            "shadow_handle_stats",
            "shadow_handle_last_timings_json",
            "shadow_handle_free_string"
        ] {
            #expect(client.contains("@_silgen_name(\"\(symbol)\")"))
        }

        #expect(client.contains("private let handle: UnsafePointer<UInt8>"))
        #expect(client.contains("public init(path: String) throws"))
        #expect(client.contains("deinit"))
        #expect(!client.contains("public init() {}"))
        #expect(!client.contains("public static func openAt"))
        #expect(!client.contains("@_silgen_name(\"shadow_search_json\")"))

        #expect(bootstrap.contains("RustShadowFFIClient(path: shadowRoot.path)"))
        #expect(!bootstrap.contains("RustShadowFFIClient.openAt(path: shadowRoot.path)"))
        #expect(!bootstrap.contains("let client = RustShadowFFIClient()"))
    }

    @Test("epistemos-shadow exports the complete panic-safe shadow_handle operation surface")
    func rustHandleSurfaceIsCompleteAndPanicSafe() throws {
        let rust = try loadMirroredSourceTextFile("epistemos-shadow/src/honest_handle.rs")

        for symbol in [
            "shadow_handle_open_at",
            "shadow_handle_retain",
            "shadow_handle_release",
            "shadow_handle_search",
            "shadow_handle_insert",
            "shadow_handle_remove",
            "shadow_handle_flush",
            "shadow_handle_stats",
            "shadow_handle_free_string"
        ] {
            let export = "#[unsafe(no_mangle)]\npub unsafe extern \"C\" fn \(symbol)"
            #expect(rust.contains(export), "\(symbol) must remain an exported C ABI symbol")
        }

        #expect(Self.countOccurrences(of: "pub unsafe extern \"C\" fn shadow_handle_", in: rust) == 10)
        #expect(rust.contains("panic::catch_unwind"))
        #expect(rust.contains("AssertUnwindSafe"))
        #expect(rust.contains("CString::from_raw"))
        #expect(rust.contains("unsafe fn read_c_str"))
        #expect(rust.contains("ShadowDocument"))
    }

    private static func countOccurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }
}
