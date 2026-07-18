import Foundation
import OSLog

/// Closed failure-class taxonomy for Shadow backend init failures
/// (distinct from per-search failures captured by `ShadowSearchFailureClass`).
/// Public so the AppBootstrap init paths can call `recordInitFailure`
/// without a private-access escape hatch.
public enum ShadowInitFailureClass: String, Sendable {
    /// `RustShadowFFIClient(path:)` threw — tantivy lexical index open failed
    /// (corruption / format mismatch / `create_dir_all` permission denied / IO).
    case handleOpen = "handle_open"
}

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

// MARK: - ShadowSearchDiagnostics

/// Process-local health snapshot for the Halo/Shadow search bridge.
///
/// The hot path still returns `[]` on backend errors so Halo does not
/// throw during typing. This diagnostic surface records only closed
/// failure classes and counters, never raw backend detail strings.
nonisolated public final class ShadowSearchDiagnostics: @unchecked Sendable {
    public struct Snapshot: Equatable, Sendable {
        public let totalSearches: UInt64
        public let totalFailures: UInt64
        public let consecutiveFailures: UInt64
        public let lastDomain: String?
        public let lastHitCount: Int?
        public let lastLatencyMs: Double?
        public let lastSuccessAt: Date?
        public let lastFailureAt: Date?
        public let lastFailureClass: String?
        /// Last init-time failure class.
        /// Cleared on a subsequent successful search so a fixed launch
        /// flips the surface back to operational without app restart.
        public let lastInitFailureClass: String?
        public let lastInitFailureAt: Date?
        /// SS-IR install preconditions (recorded by AppBootstrap at shadow-backend init), so
        /// "why is Instant Recall empty?" is answerable without Console: is a vault active, did
        /// the Rust FFI open + the search service install, and how many documents are indexed.
        /// `serviceInstalled == false` is the #1 cause of "I don't see recall" (no vault / FFI
        /// open failed → no search service → no chrome).
        public let vaultPresent: Bool
        public let serviceInstalled: Bool
        public let indexedDocumentCount: Int?

        public var isDegraded: Bool {
            if lastInitFailureAt != nil, lastInitFailureClass != nil {
                if let lastSuccessAt, let lastInitFailureAt, lastSuccessAt > lastInitFailureAt {
                    // Search succeeded after init failed — backend recovered.
                } else {
                    return true
                }
            }
            guard let lastFailureAt, lastFailureClass != ShadowSearchFailureClass.cancelled.rawValue else {
                return false
            }
            guard let lastSuccessAt else { return true }
            return lastFailureAt >= lastSuccessAt
        }

        public static let empty = Snapshot(
            totalSearches: 0,
            totalFailures: 0,
            consecutiveFailures: 0,
            lastDomain: nil,
            lastHitCount: nil,
            lastLatencyMs: nil,
            lastSuccessAt: nil,
            lastFailureAt: nil,
            lastFailureClass: nil,
            lastInitFailureClass: nil,
            lastInitFailureAt: nil,
            vaultPresent: false,
            serviceInstalled: false,
            indexedDocumentCount: nil
        )
    }

    public static let shared = ShadowSearchDiagnostics()
    public static let didChangeNotification = Notification.Name("EpistemosShadowSearchDiagnosticsDidChange")

    private let lock = NSLock()
    private var current: Snapshot = .empty

    public func snapshot() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    public func reset() {
        update(.empty)
    }

    fileprivate func recordSuccess(domain: ShadowDomain, hitCount: Int, latencyMs: Double) {
        lock.lock()
        let next = Snapshot(
            totalSearches: current.totalSearches + 1,
            totalFailures: current.totalFailures,
            consecutiveFailures: 0,
            lastDomain: domain.wireValue,
            lastHitCount: hitCount,
            lastLatencyMs: Self.safeLatency(latencyMs),
            lastSuccessAt: Date(),
            lastFailureAt: current.lastFailureAt,
            lastFailureClass: nil,
            lastInitFailureClass: current.lastInitFailureClass,
            lastInitFailureAt: current.lastInitFailureAt,
            vaultPresent: current.vaultPresent,
            serviceInstalled: current.serviceInstalled,
            indexedDocumentCount: current.indexedDocumentCount
        )
        current = next
        lock.unlock()
        postChange()
    }

    fileprivate func recordFailure(domain: ShadowDomain, failureClass: ShadowSearchFailureClass, latencyMs: Double) {
        lock.lock()
        let next = Snapshot(
            totalSearches: current.totalSearches + 1,
            totalFailures: current.totalFailures + 1,
            consecutiveFailures: current.consecutiveFailures + 1,
            lastDomain: domain.wireValue,
            lastHitCount: 0,
            lastLatencyMs: Self.safeLatency(latencyMs),
            lastSuccessAt: current.lastSuccessAt,
            lastFailureAt: Date(),
            lastFailureClass: failureClass.rawValue,
            lastInitFailureClass: current.lastInitFailureClass,
            lastInitFailureAt: current.lastInitFailureAt,
            vaultPresent: current.vaultPresent,
            serviceInstalled: current.serviceInstalled,
            indexedDocumentCount: current.indexedDocumentCount
        )
        current = next
        lock.unlock()
        postChange()
    }

    /// Record a Shadow-backend init failure (handle-open or embedder-warm)
    /// observed by the AppBootstrap launch path. Public so any actor can
    /// call from the catch site. Surfaces in `ShadowSearchHealthRow` so
    /// users can diagnose "Halo doesn't work" without Console.app.
    public func recordInitFailure(class failureClass: ShadowInitFailureClass) {
        lock.lock()
        let next = Snapshot(
            totalSearches: current.totalSearches,
            totalFailures: current.totalFailures,
            consecutiveFailures: current.consecutiveFailures,
            lastDomain: current.lastDomain,
            lastHitCount: current.lastHitCount,
            lastLatencyMs: current.lastLatencyMs,
            lastSuccessAt: current.lastSuccessAt,
            lastFailureAt: current.lastFailureAt,
            lastFailureClass: current.lastFailureClass,
            lastInitFailureClass: failureClass.rawValue,
            lastInitFailureAt: Date(),
            vaultPresent: current.vaultPresent,
            serviceInstalled: current.serviceInstalled,
            indexedDocumentCount: current.indexedDocumentCount
        )
        current = next
        lock.unlock()
        postChange()
    }

    /// SS-IR (owner 2026-06-20): record the shadow-backend install preconditions the owner needs
    /// to answer "I don't see Instant Recall — is it working?". Called by AppBootstrap after the
    /// active-vault check + Rust FFI open + search-service install. Preserves all telemetry fields.
    public func recordInstall(vaultPresent: Bool, serviceInstalled: Bool, indexedDocumentCount: Int?) {
        lock.lock()
        let next = Snapshot(
            totalSearches: current.totalSearches,
            totalFailures: current.totalFailures,
            consecutiveFailures: current.consecutiveFailures,
            lastDomain: current.lastDomain,
            lastHitCount: current.lastHitCount,
            lastLatencyMs: current.lastLatencyMs,
            lastSuccessAt: current.lastSuccessAt,
            lastFailureAt: current.lastFailureAt,
            lastFailureClass: current.lastFailureClass,
            lastInitFailureClass: current.lastInitFailureClass,
            lastInitFailureAt: current.lastInitFailureAt,
            vaultPresent: vaultPresent,
            serviceInstalled: serviceInstalled,
            indexedDocumentCount: indexedDocumentCount
        )
        current = next
        lock.unlock()
        postChange()
    }

    private func update(_ snapshot: Snapshot) {
        lock.lock()
        current = snapshot
        lock.unlock()
        postChange()
    }

    private func postChange() {
        NotificationCenter.default.post(
            name: Self.didChangeNotification,
            object: self
        )
    }

    private static func safeLatency(_ value: Double) -> Double {
        guard value.isFinite, value >= 0 else { return 0 }
        return value
    }
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
    private let log = Logger(subsystem: "com.epistemos", category: "ShadowSearchService")

    @MainActor
    public init(client: any ShadowFFIClient) {
        self.client = client
    }

    /// Conforms to the `ShadowSearchServicing` protocol used by
    /// HaloController. Errors from the FFI are logged and converted
    /// into an empty result set so the controller's hot path never
    /// throws (it just transitions to `.dormant` when no hits).
    public func search(text: String, limit: Int) async -> [ShadowHit] {
        guard let checkedLimit = try? SearchRequestBounds.validatedResultLimit(limit) else { return [] }
        guard let checkedQuery = try? SearchRequestBounds.validatedQuery(text) else { return [] }
        let normalizedText = checkedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return [] }
        let domain: ShadowDomain = .notes

        if Task.isCancelled {
            ShadowSearchDiagnostics.shared.recordFailure(
                domain: domain,
                failureClass: .cancelled,
                latencyMs: 0
            )
            return []
        }

        let start = CFAbsoluteTimeGetCurrent()
        // The lexical search interval remains useful deterministic
        // performance telemetry without exporting model-stage timings.
        let totalSignpostId = Sig.storage.makeSignpostID()
        let totalSignpostState = Sig.storage.beginInterval(
            "shadow.search.total.ms",
            id: totalSignpostId,
            "domain=\(domain.wireValue)"
        )
        do {
            // SS-2: send the TRIMMED query to the FFI — the guard + all metrics above already use
            // normalizedText; passing raw `text` leaked leading/trailing whitespace into the index
            // query (inconsistent with what we validated and measured).
            let hits = try client.search(query: normalizedText, limit: checkedLimit)
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1_000
            Sig.storage.endInterval("shadow.search.total.ms", totalSignpostState)

            if Task.isCancelled {
                ShadowSearchDiagnostics.shared.recordFailure(
                    domain: domain,
                    failureClass: .cancelled,
                    latencyMs: elapsed
                )
                return []
            }

            ShadowSearchDiagnostics.shared.recordSuccess(
                domain: domain,
                hitCount: hits.count,
                latencyMs: elapsed
            )
            return hits
        } catch {
            Sig.storage.endInterval("shadow.search.total.ms", totalSignpostState)
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1_000
            let failureClass: ShadowSearchFailureClass = Task.isCancelled
                ? .cancelled
                : shadowSearchFailureClass(for: error)
            let message = EngineLogDiagnostics.logMessage(
                for: error,
                fallback: "shadow search failed"
            )
            log.warning("\(message, privacy: .public)")
            ShadowSearchDiagnostics.shared.recordFailure(
                domain: domain,
                failureClass: failureClass,
                latencyMs: elapsed
            )
            return []
        }
    }

    /// Per RCA13 P5: the controller-facing variant catches the same
    /// FFI errors as `search` but reports them up the stack so the
    /// Halo UI can surface "Search backend unavailable" instead of
    /// silently treating a crashed backend as "no results." The
    /// default protocol implementation in HaloController.swift wraps
    /// `search` and reports nil error; this override does the real
    /// catch + message-shaping.
    public func searchReportingErrors(
        text: String,
        limit: Int
    ) async -> (hits: [ShadowHit], errorMessage: String?) {
        guard let checkedLimit = try? SearchRequestBounds.validatedResultLimit(limit) else {
            return (hits: [], errorMessage: nil)
        }
        guard let checkedQuery = try? SearchRequestBounds.validatedQuery(text) else {
            return (hits: [], errorMessage: nil)
        }
        let normalizedText = checkedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return (hits: [], errorMessage: nil) }
        let domain: ShadowDomain = .notes
        let start = CFAbsoluteTimeGetCurrent()
        do {
            // SS-2: trimmed query to the FFI (consistent with the guard above).
            let hits = try client.search(query: normalizedText, limit: checkedLimit)
            ShadowSearchDiagnostics.shared.recordSuccess(
                domain: domain,
                hitCount: hits.count,
                latencyMs: (CFAbsoluteTimeGetCurrent() - start) * 1_000
            )
            return (hits: hits, errorMessage: nil)
        } catch {
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1_000
            let message = EngineLogDiagnostics.logMessage(
                for: error,
                fallback: "shadow searchReportingErrors failed"
            )
            log.warning(
                "\(message, privacy: .public)"
            )
            ShadowSearchDiagnostics.shared.recordFailure(
                domain: domain,
                failureClass: shadowSearchFailureClass(for: error),
                latencyMs: elapsed
            )
            return (
                hits: [],
                errorMessage: "Search backend unavailable. Try reopening the vault."
            )
        }
    }

    /// Direct typed search — used by callers that want to surface the
    /// underlying error (e.g. the developer panel).
    public func searchOrThrow(text: String, limit: Int) throws -> [ShadowHit] {
        let checkedLimit = try SearchRequestBounds.validatedResultLimit(limit)
        guard let checkedQuery = try SearchRequestBounds.validatedQuery(text) else { return [] }
        let domain: ShadowDomain = .notes
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let hits = try client.search(query: checkedQuery, limit: checkedLimit)
            ShadowSearchDiagnostics.shared.recordSuccess(
                domain: domain,
                hitCount: hits.count,
                latencyMs: (CFAbsoluteTimeGetCurrent() - start) * 1_000
            )
            return hits
        } catch {
            ShadowSearchDiagnostics.shared.recordFailure(
                domain: domain,
                failureClass: shadowSearchFailureClass(for: error),
                latencyMs: (CFAbsoluteTimeGetCurrent() - start) * 1_000
            )
            throw error
        }
    }

    /// Read-only stats snapshot for the developer panel.
    public func stats() async throws -> ShadowStatsDTO {
        try client.stats()
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

}
