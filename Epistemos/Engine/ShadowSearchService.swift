import Foundation
import OSLog

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
    private let log = Logger(subsystem: "com.epistemos", category: "ShadowSearchService")

    public init(client: any ShadowFFIClient) {
        self.client = client
    }

    /// Conforms to the `ShadowSearchServicing` protocol used by
    /// HaloController. Errors from the FFI are logged and converted
    /// into an empty result set so the controller's hot path never
    /// throws (it just transitions to `.dormant` when no hits).
    public func search(text: String, domain: ShadowDomain, limit: Int) async -> [ShadowHit] {
        do {
            return try client.search(query: text, domain: domain, limit: limit)
        } catch {
            log.warning("shadow search failed: \(String(describing: error), privacy: .public)")
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
}
