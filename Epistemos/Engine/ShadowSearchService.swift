import Foundation
import OSLog

private enum ShadowSearchFailureClass: String, Sendable {
    case invalidInput = "invalid_input"
    case notFound = "not_found"
    case ioFailure = "io_failure"
    case backendFailure = "backend_failure"
    case rustPanic = "rust_panic"
    case unknownCode = "unknown_code"
    case cancelled
    case unknownError = "unknown_error"
}

// MARK: - ShadowSearchService
//
// Wave 8.3 of the Extended Program Plan
// (cross-ref `ambient/EPISTEMOS_V1_DECISION.md` §"Concurrency").
//
// Per the V1 decision: "Search service: actor with default cooperative
// executor. Calls nonisolated UniFFI bindings. Returns plain
// [ShadowHit]." This is the actor that bridges between the @MainActor
// HaloController and the synchronous ShadowFFIClient — keeping the
// FFI hop off the main thread and the controller's editorTextDidChange
// path under the V1 budget (<1 ms MainActor work per recall update).

/// Actor-isolated search service that delegates to a `ShadowFFIClient`.
/// The actor's cooperative executor lets multiple search calls
/// interleave on the same thread pool without main-thread contention.
public actor ShadowSearchService: ShadowSearchServicing {
    private let client: any ShadowFFIClient
    private let agentProvenanceRecorder: AgentToolProvenanceRecorder
    private let log = Logger(subsystem: "com.epistemos", category: "ShadowSearchService")
    private var searchSequence: UInt64 = 0

    @MainActor
    public init(client: any ShadowFFIClient) {
        self.client = client
        self.agentProvenanceRecorder = AgentToolProvenanceRecorder()
    }

    @MainActor
    init(client: any ShadowFFIClient, agentProvenanceRecorder: AgentToolProvenanceRecorder) {
        self.client = client
        self.agentProvenanceRecorder = agentProvenanceRecorder
    }

    /// Conforms to the `ShadowSearchServicing` protocol used by
    /// HaloController. Errors from the FFI are logged and converted
    /// into an empty result set so the controller's hot path never
    /// throws (it just transitions to `.dormant` when no hits).
    public func search(text: String, domain: ShadowDomain, limit: Int) async -> [ShadowHit] {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty, limit > 0 else { return [] }

        let runID = "shadow-search-\(UUID().uuidString)"
        let toolCallID = nextShadowSearchToolCallID()
        let actor = AgentProvenanceActor.agent(id: "shadow-search-service", modelID: nil)
        let queryCharacterCount = normalizedText.count
        let queryTermCount = shadowSearchQueryTermCount(normalizedText)
        let argumentsJSON = shadowSearchArgumentsJSON(
            domain: domain,
            limit: limit,
            queryCharacterCount: queryCharacterCount,
            queryTermCount: queryTermCount
        )
        let baseMetadata = shadowSearchMetadata(
            domain: domain,
            limit: limit,
            queryCharacterCount: queryCharacterCount,
            queryTermCount: queryTermCount
        )

        await recordShadowSearchEvent(
            runID: runID,
            kind: .toolCallRequested,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            status: .requested,
            metadata: baseMetadata
        )
        await recordShadowSearchEvent(
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
            await recordShadowSearchFailure(
                runID: runID,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                resultJSON: shadowSearchResultJSON(domain: domain, hitCount: 0, elapsedMs: 0),
                durationMs: shadowSearchDurationMilliseconds(since: startedAt),
                metadata: baseMetadata,
                failureClass: .cancelled
            )
            return []
        }

        let start = CFAbsoluteTimeGetCurrent()
        do {
            let hits = try client.search(query: text, domain: domain, limit: limit)
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1_000

            if Task.isCancelled {
                await recordShadowSearchFailure(
                    runID: runID,
                    actor: actor,
                    toolCallID: toolCallID,
                    argumentsJSON: argumentsJSON,
                    resultJSON: shadowSearchResultJSON(domain: domain, hitCount: 0, elapsedMs: elapsed),
                    durationMs: shadowSearchDurationMilliseconds(since: startedAt),
                    metadata: baseMetadata,
                    failureClass: .cancelled
                )
                return []
            }

            var completedMetadata = baseMetadata
            completedMetadata["hit_count"] = String(hits.count)
            await recordShadowSearchEvent(
                runID: runID,
                kind: .toolCallCompleted,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                resultJSON: shadowSearchResultJSON(
                    domain: domain,
                    hitCount: hits.count,
                    elapsedMs: elapsed
                ),
                durationMs: shadowSearchDurationMilliseconds(since: startedAt),
                status: .completed,
                metadata: completedMetadata
            )
            return hits
        } catch {
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1_000
            let failureClass: ShadowSearchFailureClass = Task.isCancelled
                ? .cancelled
                : shadowSearchFailureClass(for: error)
            log.warning("shadow search failed: \(String(describing: error), privacy: .public)")
            await recordShadowSearchFailure(
                runID: runID,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                resultJSON: shadowSearchResultJSON(domain: domain, hitCount: 0, elapsedMs: elapsed),
                durationMs: shadowSearchDurationMilliseconds(since: startedAt),
                metadata: baseMetadata,
                failureClass: failureClass
            )
            return []
        }
    }

    /// Direct typed search — used by callers that want to surface the
    /// underlying error (e.g. the developer panel).
    public func searchOrThrow(text: String, domain: ShadowDomain, limit: Int) throws -> [ShadowHit] {
        try client.search(query: text, domain: domain, limit: limit)
    }

    /// Read-only stats snapshot for the developer panel.
    public func stats() async throws -> ShadowStatsDTO {
        try client.stats()
    }

    private func nextShadowSearchToolCallID() -> String {
        searchSequence = searchSequence == UInt64.max ? 1 : searchSequence + 1
        return "shadow-search:\(searchSequence)"
    }

    @discardableResult
    private func recordShadowSearchEvent(
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
    ) async -> Bool {
        await agentProvenanceRecorder.recordToolEvent(
            runID: runID,
            traceID: nil,
            kind: kind,
            actor: actor,
            toolCallID: toolCallID,
            toolName: "shadow_search.search",
            argumentsJSON: argumentsJSON,
            resultJSON: resultJSON,
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
            metadata: metadata
        )
    }

    private func recordShadowSearchFailure(
        runID: String,
        actor: AgentProvenanceActor,
        toolCallID: String,
        argumentsJSON: String,
        resultJSON: String,
        durationMs: UInt64,
        metadata: [String: String],
        failureClass: ShadowSearchFailureClass
    ) async {
        var failureMetadata = metadata
        failureMetadata["failure_class"] = failureClass.rawValue
        await recordShadowSearchEvent(
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

    private func shadowSearchFailureClass(for error: any Error) -> ShadowSearchFailureClass {
        guard let ffiError = error as? ShadowFFIError else { return .unknownError }
        switch ffiError {
        case .invalidInput: return .invalidInput
        case .notFound: return .notFound
        case .ioFailure: return .ioFailure
        case .backendFailure: return .backendFailure
        case .rustPanic: return .rustPanic
        case .unknownCode: return .unknownCode
        }
    }

    private func shadowSearchArgumentsJSON(
        domain: ShadowDomain,
        limit: Int,
        queryCharacterCount: Int,
        queryTermCount: Int
    ) -> String {
        """
        {"domain":"\(domain.wireValue)","limit":\(limit),"query_char_count":\(queryCharacterCount),"query_term_count":\(queryTermCount)}
        """
    }

    private func shadowSearchResultJSON(
        domain: ShadowDomain,
        hitCount: Int,
        elapsedMs: Double
    ) -> String {
        """
        {"domain":"\(domain.wireValue)","hit_count":\(hitCount),"elapsed_ms":\(shadowSearchJSONPayload(elapsedMs))}
        """
    }

    private func shadowSearchMetadata(
        domain: ShadowDomain,
        limit: Int,
        queryCharacterCount: Int,
        queryTermCount: Int
    ) -> [String: String] {
        [
            "source": "shadow_search_service",
            "surface": "shadow_search",
            "domain": domain.wireValue,
            "limit": String(limit),
            "query_char_count": String(queryCharacterCount),
            "query_term_count": String(queryTermCount)
        ]
    }

    private func shadowSearchDurationMilliseconds(since startedAt: Date) -> UInt64 {
        let elapsed = Date().timeIntervalSince(startedAt) * 1_000
        guard elapsed.isFinite, elapsed >= 0 else { return 0 }
        return UInt64(elapsed.rounded())
    }

    private func shadowSearchJSONPayload(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        return String(format: "%.3f", value)
    }

    private func shadowSearchQueryTermCount(_ value: String) -> Int {
        value.split(whereSeparator: { $0.isWhitespace }).count
    }
}
