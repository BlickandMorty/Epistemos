// VaultRecallWiring.swift
//
// Wiring #2 (T21 Vault Recall Contract -> ResourceService).
//
// Three pieces:
//
//   - Swift Codable mirrors for the T21 `VaultRecallTrace` substrate
//     (`agent_core/src/storage/retrieval_trace.rs`). Wire shape pinned
//     by the Rust serde derives; JSON round-trips byte-equal both ways.
//
//   - `VaultRecallFlags` — UserDefaults gate for
//     `EPISTEMOS_VAULT_RECALL_CONTRACT_V1` (default OFF).
//
//   - `VaultRecallMetrics` + `VaultRecallBridge` — bounded ring-buffer
//     observability mirror of `EidosMetrics` / `SearchFusionMetrics`
//     so the Settings -> Vault recall health row renders in the same
//     vocabulary as the other diagnostics.
//
// The Rust bridge still exposes a stub trace builder for callers that
// have no vault handle. Live Swift vault retrieval installs a
// `SearchIndexService` trace provider and records production traces
// through the same Codable wire shape.

import Foundation
import os

// MARK: - Backend honesty
//
// The fallback Rust bridge currently builds a scaffold trace inside
// `agent_core::bridge::vault_recall_trace_json`: hardcoded
// `notes/sample.md` + `notes/decoy.md` candidates with
// `ladder_tier = "scaffold-lexical"`. Swift live retrieval emits
// `vault-*` traces from the installed `SearchIndexService` provider;
// a future Rust `VaultBackend` FFI can reuse the same prefix when it
// gains a shared backend handle.
//
// **Detection contract** (forward-compatible with Terminal 2's real
// VaultBackend wire, no Rust change required to flip Swift to `.real`):
//
//   - `scaffold-lexical` ladder tier         → `.stub`
//   - `eidos-fixture-*` ladder tier          → `.stub`
//   - any `vault-*` / `helios-*` ladder tier → `.real`
//   - missing or unrecognized                → `.unknown`
//
// When Terminal 2 lands the real backend, the Rust side emits a tier
// name keyed off the deployed retriever ("vault-hybrid-v1",
// "helios-fanout-v2", etc.), so this heuristic flips to `.real`
// automatically. If Terminal 2 needs a stronger signal (e.g. a
// dedicated `backend_origin` field on `RetrievalTrace`), the Snapshot
// already carries `lastBackend` and the row already renders it —
// Swift-side change is then a one-line update of
// `detectedBackend(from:)` to read the new field.
nonisolated public enum VaultRecallBackend: String, Sendable, Hashable {
    /// Rust side returned the hardcoded scaffold trace. UI must not
    /// claim "working" — the candidates do not reflect the user's vault.
    case stub
    /// Rust side returned a trace from a real `VaultBackend`. The 5-
    /// signal contract holds against production content.
    case real
    /// No trace has run yet, the ladder tier was nil, or the prefix did
    /// not match a known shape.
    case unknown
}

// MARK: - VaultRecallTrace mirrors

/// Mirrors Rust `VaultRecallSignal` (`agent_core/src/storage/retrieval_trace.rs`).
/// `#[serde(rename_all = "lowercase")]` on the Rust side, so we use
/// lowercase raw values here.
nonisolated public enum VaultRecallSignal: String, Codable, Hashable, Sendable, CaseIterable {
    case lexical
    case semantic
    case graph
    case recency
    case mmr
}

nonisolated public struct VaultRecallSignalScore: Codable, Hashable, Sendable {
    public let signal: VaultRecallSignal
    public let raw: Double
    public let normalized: Double
}

nonisolated public struct VaultRecallCandidate: Codable, Hashable, Sendable {
    public let path: String
    public let title: String?
    public let snippet: String?
    public let fusedScore: Double
    public let signals: [VaultRecallSignalScore]
    public let selectionReason: String
    public let uasAddress: UasAddress?

    public init(
        path: String,
        title: String?,
        snippet: String?,
        fusedScore: Double,
        signals: [VaultRecallSignalScore],
        selectionReason: String,
        uasAddress: UasAddress? = nil
    ) {
        self.path = path
        self.title = title
        self.snippet = snippet
        self.fusedScore = fusedScore
        self.signals = signals
        self.selectionReason = selectionReason
        self.uasAddress = uasAddress
    }

    enum CodingKeys: String, CodingKey {
        case path
        case title
        case snippet
        case fusedScore = "fused_score"
        case signals
        case selectionReason = "selection_reason"
        case uasAddress = "uas_address"
    }
}

nonisolated public enum PageGatherEscalationStatus: String, Codable, Hashable, Sendable {
    case vaultEscalated = "vault_escalated"
}

nonisolated public enum PageGatherMeasurementStatus: String, Codable, Hashable, Sendable {
    case deferred
}

nonisolated public enum PageGatherScheduleClass: String, Codable, Hashable, Sendable {
    case blockSorted = "block_sorted"
    case localWindow = "local_window"
    case fullCoverageRandom = "full_coverage_random"
}

nonisolated public struct PageGatherEscalationTrace: Codable, Hashable, Sendable {
    public static let defaultLocalityBlockElements = 8_192

    public let status: PageGatherEscalationStatus
    public let measurementStatus: PageGatherMeasurementStatus
    public let source: String
    public let candidatePoolSize: Int
    public let candidatesRetained: Int
    public let deferredFalsifier: String
    public let scheduleClass: PageGatherScheduleClass?
    public let localityBlockElements: Int?
    public let packetizedCallerConsumed: Bool
    public let packetsEmitted: Int
    public let denseRestoreDeferred: Bool

    enum CodingKeys: String, CodingKey {
        case status
        case measurementStatus = "measurement_status"
        case source
        case candidatePoolSize = "candidate_pool_size"
        case candidatesRetained = "candidates_retained"
        case deferredFalsifier = "deferred_falsifier"
        case scheduleClass = "schedule_class"
        case localityBlockElements = "locality_block_elements"
        case packetizedCallerConsumed = "packetized_caller_consumed"
        case packetsEmitted = "packets_emitted"
        case denseRestoreDeferred = "dense_restore_deferred"
    }

    public init(
        status: PageGatherEscalationStatus = .vaultEscalated,
        measurementStatus: PageGatherMeasurementStatus = .deferred,
        source: String,
        candidatePoolSize: Int,
        candidatesRetained: Int,
        deferredFalsifier: String = "F-PageGather-Scatter",
        scheduleClass: PageGatherScheduleClass? = .blockSorted,
        localityBlockElements: Int? = PageGatherEscalationTrace.defaultLocalityBlockElements,
        packetizedCallerConsumed: Bool = false,
        packetsEmitted: Int = 0,
        denseRestoreDeferred: Bool = false
    ) {
        self.status = status
        self.measurementStatus = measurementStatus
        self.source = source
        self.candidatePoolSize = candidatePoolSize
        self.candidatesRetained = candidatesRetained
        self.deferredFalsifier = deferredFalsifier
        self.scheduleClass = scheduleClass
        self.localityBlockElements = localityBlockElements
        self.packetizedCallerConsumed = packetizedCallerConsumed
        self.packetsEmitted = packetsEmitted
        self.denseRestoreDeferred = denseRestoreDeferred
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(PageGatherEscalationStatus.self, forKey: .status)
        measurementStatus = try container.decode(PageGatherMeasurementStatus.self, forKey: .measurementStatus)
        source = try container.decode(String.self, forKey: .source)
        candidatePoolSize = try container.decode(Int.self, forKey: .candidatePoolSize)
        candidatesRetained = try container.decode(Int.self, forKey: .candidatesRetained)
        deferredFalsifier = try container.decode(String.self, forKey: .deferredFalsifier)
        scheduleClass = try container.decodeIfPresent(PageGatherScheduleClass.self, forKey: .scheduleClass)
        localityBlockElements = try container.decodeIfPresent(Int.self, forKey: .localityBlockElements)
        packetizedCallerConsumed = try container.decodeIfPresent(Bool.self, forKey: .packetizedCallerConsumed) ?? false
        packetsEmitted = try container.decodeIfPresent(Int.self, forKey: .packetsEmitted) ?? 0
        denseRestoreDeferred = try container.decodeIfPresent(Bool.self, forKey: .denseRestoreDeferred) ?? false
    }

    public var scheduleLabel: String? {
        guard let scheduleClass else { return nil }
        switch scheduleClass {
        case .blockSorted:
            if let localityBlockElements {
                return "block_sorted \(localityBlockElements)"
            }
            return "block_sorted"
        case .localWindow:
            return "local_window"
        case .fullCoverageRandom:
            return "random stressor"
        }
    }
}

nonisolated public struct VaultRecallTrace: Codable, Hashable, Sendable {
    public let query: String
    public let effectiveQuery: String
    public let ladderTier: String?
    public let candidatePoolSize: Int
    public let candidatesRetained: Int
    public let candidates: [VaultRecallCandidate]
    public let signalSummary: [VaultRecallSignal]
    public let generatedAtMs: UInt64
    public let notes: [String]
    public let allChatterFallback: Bool
    public let pageGather: PageGatherEscalationTrace?

    enum CodingKeys: String, CodingKey {
        case query
        case effectiveQuery = "effective_query"
        case ladderTier = "ladder_tier"
        case candidatePoolSize = "candidate_pool_size"
        case candidatesRetained = "candidates_retained"
        case candidates
        case signalSummary = "signal_summary"
        case generatedAtMs = "generated_at_ms"
        case notes
        case allChatterFallback = "all_chatter_fallback"
        case pageGather = "page_gather"
    }

    public init(
        query: String,
        effectiveQuery: String,
        ladderTier: String?,
        candidatePoolSize: Int,
        candidatesRetained: Int,
        candidates: [VaultRecallCandidate],
        signalSummary: [VaultRecallSignal],
        generatedAtMs: UInt64,
        notes: [String],
        allChatterFallback: Bool,
        pageGather: PageGatherEscalationTrace? = nil
    ) {
        self.query = query
        self.effectiveQuery = effectiveQuery
        self.ladderTier = ladderTier
        self.candidatePoolSize = candidatePoolSize
        self.candidatesRetained = candidatesRetained
        self.candidates = candidates
        self.signalSummary = signalSummary
        self.generatedAtMs = generatedAtMs
        self.notes = notes
        self.allChatterFallback = allChatterFallback
        self.pageGather = pageGather
    }
}

// MARK: - Feature flag

nonisolated public enum VaultRecallFlags {
    public static let userDefaultsKey = "EPISTEMOS_VAULT_RECALL_CONTRACT_V1"

    public static var isEnabled: Bool {
        if UserDefaults.standard.bool(forKey: userDefaultsKey) {
            return true
        }
        return ProcessInfo.processInfo.environment[userDefaultsKey] == "1"
    }
}

// MARK: - Metrics

nonisolated public final class VaultRecallMetrics: @unchecked Sendable {
    public static let shared = VaultRecallMetrics()
    public static let didChangeNotification = Notification.Name(
        "epistemos.vaultRecallMetrics.didChange"
    )

    public static let bufferCap = 200
    public static let candidatePreviewLimit = 5
    public static let candidatePreviewTextLimit = 160

    private let lock = NSLock()
    private var samples: [Double] = []
    private var lastLatencyMs: Double = 0
    private var lastQueryAt: Date?
    private var lastCandidatesRetained: Int = 0
    private var lastSignalSummary: [VaultRecallSignal] = []
    private var lastAllChatterFallback: Bool = false
    private var lastBackendValue: VaultRecallBackend = .unknown
    private var lastPageGatherValue: PageGatherEscalationTrace?
    private var lastCandidatePreviewsValue: [RetrievedCandidatePreview] = []
    private var lastRetrievedByEidosValue = false
    private var totalQueries: UInt64 = 0
    private var lastErrorDescription: String?
    private var lastErrorAt: Date?

    private init() {}

    public func record(latencyMs: Double, trace: VaultRecallTrace, backend: VaultRecallBackend) {
        let candidatePreviews = Self.candidatePreviews(from: trace)
        let retrievedByEidos = Self.traceWasRetrievedByEidos(trace)
        lock.lock()
        samples.append(latencyMs)
        if samples.count > Self.bufferCap {
            samples.removeFirst(samples.count - Self.bufferCap)
        }
        lastLatencyMs = latencyMs
        lastQueryAt = Date()
        lastCandidatesRetained = trace.candidatesRetained
        lastSignalSummary = trace.signalSummary
        lastAllChatterFallback = trace.allChatterFallback
        lastBackendValue = backend
        lastPageGatherValue = trace.pageGather
        lastCandidatePreviewsValue = candidatePreviews
        lastRetrievedByEidosValue = retrievedByEidos
        totalQueries &+= 1
        lastErrorDescription = nil
        lock.unlock()
        notifyDidChange()
    }

    public func recordError(_ error: Error) {
        lock.lock()
        lastErrorDescription = RetrievalDiagnostics.statusMessage(
            for: error,
            fallback: "Vault recall trace failed"
        )
        lastErrorAt = Date()
        lastCandidatePreviewsValue = []
        lastRetrievedByEidosValue = false
        lock.unlock()
        notifyDidChange()
    }

    public func snapshot() -> Snapshot {
        lock.lock(); defer { lock.unlock() }
        return Snapshot(
            isFlagEnabled:           VaultRecallFlags.isEnabled,
            lastQueryAt:             lastQueryAt,
            lastLatencyMs:           lastLatencyMs,
            p95LatencyMs:            Self.percentile(samples, 0.95),
            sampleCount:             samples.count,
            totalQueries:            totalQueries,
            lastCandidatesRetained:  lastCandidatesRetained,
            lastSignalSummary:       lastSignalSummary,
            lastAllChatterFallback:  lastAllChatterFallback,
            lastBackend:             lastBackendValue,
            lastPageGather:          lastPageGatherValue,
            lastCandidatePreviews:   lastCandidatePreviewsValue,
            lastRetrievedByEidos:    lastRetrievedByEidosValue,
            lastErrorDescription:    lastErrorDescription,
            lastErrorAt:             lastErrorAt
        )
    }

    public func reset() {
        lock.lock()
        samples.removeAll(keepingCapacity: true)
        lastLatencyMs = 0
        lastQueryAt = nil
        lastCandidatesRetained = 0
        lastSignalSummary = []
        lastAllChatterFallback = false
        lastBackendValue = .unknown
        lastPageGatherValue = nil
        lastCandidatePreviewsValue = []
        lastRetrievedByEidosValue = false
        totalQueries = 0
        lastErrorDescription = nil
        lastErrorAt = nil
        lock.unlock()
        notifyDidChange()
    }

    private func notifyDidChange() {
        NotificationCenter.default.post(
            name: Self.didChangeNotification,
            object: self
        )
    }

    public struct RetrievedCandidatePreview: Sendable, Hashable {
        public let path: String
        public let title: String?
        public let selectionReason: String
        public let fusedScore: Double

        public init(path: String, title: String?, selectionReason: String, fusedScore: Double) {
            self.path = path
            self.title = title
            self.selectionReason = selectionReason
            self.fusedScore = fusedScore
        }
    }

    public struct Snapshot: Sendable {
        public let isFlagEnabled: Bool
        public let lastQueryAt: Date?
        public let lastLatencyMs: Double
        public let p95LatencyMs: Double
        public let sampleCount: Int
        public let totalQueries: UInt64
        public let lastCandidatesRetained: Int
        public let lastSignalSummary: [VaultRecallSignal]
        public let lastAllChatterFallback: Bool
        public let lastBackend: VaultRecallBackend
        public let lastPageGather: PageGatherEscalationTrace?
        public let lastCandidatePreviews: [RetrievedCandidatePreview]
        public let lastRetrievedByEidos: Bool
        public let lastErrorDescription: String?
        public let lastErrorAt: Date?

        /// W-21 benchmark surface — added 2026-05-24 to back the
        /// `VaultRecallHealthRow` chip-strip the unify-substrate-health
        /// commit shipped. All four fields default to `nil` (no
        /// measurement yet) so `vaultRecallBenchmarkPassing` returns
        /// false and the chip strip stays orange ("trace scaffold")
        /// per WRV honesty — never green without a real measurement
        /// from F-VaultRecall-50.
        public let recallBenchmark: VaultRecallBenchmark

        public init(
            isFlagEnabled: Bool,
            lastQueryAt: Date?,
            lastLatencyMs: Double,
            p95LatencyMs: Double,
            sampleCount: Int,
            totalQueries: UInt64,
            lastCandidatesRetained: Int,
            lastSignalSummary: [VaultRecallSignal],
            lastAllChatterFallback: Bool,
            lastBackend: VaultRecallBackend,
            lastPageGather: PageGatherEscalationTrace? = nil,
            lastCandidatePreviews: [RetrievedCandidatePreview] = [],
            lastRetrievedByEidos: Bool = false,
            lastErrorDescription: String?,
            lastErrorAt: Date?,
            recallBenchmark: VaultRecallBenchmark = VaultRecallBenchmark()
        ) {
            self.isFlagEnabled = isFlagEnabled
            self.lastQueryAt = lastQueryAt
            self.lastLatencyMs = lastLatencyMs
            self.p95LatencyMs = p95LatencyMs
            self.sampleCount = sampleCount
            self.totalQueries = totalQueries
            self.lastCandidatesRetained = lastCandidatesRetained
            self.lastSignalSummary = lastSignalSummary
            self.lastAllChatterFallback = lastAllChatterFallback
            self.lastBackend = lastBackend
            self.lastPageGather = lastPageGather
            self.lastCandidatePreviews = lastCandidatePreviews
            self.lastRetrievedByEidos = lastRetrievedByEidos
            self.lastErrorDescription = lastErrorDescription
            self.lastErrorAt = lastErrorAt
            self.recallBenchmark = recallBenchmark
        }
    }

    /// W-21 acceptance metrics (top-1 exact-title · top-5 paraphrase ·
    /// synthesis 2-note citation · adversarial reject). Each field is
    /// `nil` until the F-VaultRecall-50 falsifier harness produces a
    /// measured rate. The chip strip in `VaultRecallHealthRow` displays
    /// each as a benchmark chip vs the 0.95 threshold.
    public struct VaultRecallBenchmark: Sendable {
        public let top1ExactTitleRate: Double?
        public let top5ParaphraseRate: Double?
        public let synthesisTwoNoteCitationRate: Double?
        public let adversarialRejectRate: Double?

        public init(
            top1ExactTitleRate: Double? = nil,
            top5ParaphraseRate: Double? = nil,
            synthesisTwoNoteCitationRate: Double? = nil,
            adversarialRejectRate: Double? = nil
        ) {
            self.top1ExactTitleRate = top1ExactTitleRate
            self.top5ParaphraseRate = top5ParaphraseRate
            self.synthesisTwoNoteCitationRate = synthesisTwoNoteCitationRate
            self.adversarialRejectRate = adversarialRejectRate
        }
    }

    nonisolated private static func percentile(_ values: [Double], _ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let idx = max(0, min(sorted.count - 1, Int((p * Double(sorted.count)).rounded(.up)) - 1))
        return sorted[idx]
    }

    nonisolated private static func candidatePreviews(from trace: VaultRecallTrace) -> [RetrievedCandidatePreview] {
        trace.candidates.prefix(Self.candidatePreviewLimit).map { candidate in
            RetrievedCandidatePreview(
                path: Self.boundedCandidateText(candidate.path),
                title: candidate.title.map(Self.boundedCandidateText),
                selectionReason: Self.boundedCandidateText(candidate.selectionReason),
                fusedScore: Self.boundedUnitScore(candidate.fusedScore)
            )
        }
    }

    nonisolated private static func traceWasRetrievedByEidos(_ trace: VaultRecallTrace) -> Bool {
        trace.pageGather?.source == "QueryRuntime.Eidos"
            || trace.notes.contains(where: Self.containsEidos)
            || trace.candidates.contains { Self.containsEidos($0.selectionReason) }
    }

    nonisolated private static func containsEidos(_ value: String) -> Bool {
        value.range(of: "Eidos", options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    nonisolated private static func boundedCandidateText(_ value: String) -> String {
        let bounded = String(value.prefix(Self.candidatePreviewTextLimit + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > Self.candidatePreviewTextLimit else { return trimmed }
        return String(trimmed.prefix(Self.candidatePreviewTextLimit - 3)) + "..."
    }

    nonisolated private static func boundedUnitScore(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }
}

// MARK: - Bridge wrapper

nonisolated public enum VaultRecallBridge {
    public typealias TraceProvider = (String) throws -> VaultRecallTrace?

    private final class TraceProviderStore: @unchecked Sendable {
        private let lock = NSLock()
        private var provider: TraceProvider?

        func install(_ provider: TraceProvider?) {
            lock.lock()
            self.provider = provider
            lock.unlock()
        }

        func current() -> TraceProvider? {
            lock.lock()
            defer { lock.unlock() }
            return provider
        }
    }

    private static let log = Logger(subsystem: "com.epistemos", category: "vault-recall")
    private static let traceProviderStore = TraceProviderStore()

    public static func installTraceProvider(_ provider: TraceProvider?) {
        traceProviderStore.install(provider)
    }

    /// Inspect a `VaultRecallTrace` and report whether it came from the
    /// scaffold-lexical stub or a real `VaultBackend`. See the file-head
    /// "Backend honesty" comment for the contract.
    public static func detectedBackend(from trace: VaultRecallTrace) -> VaultRecallBackend {
        guard let tier = trace.ladderTier else { return .unknown }
        if tier == "scaffold-lexical" { return .stub }
        if tier.hasPrefix("eidos-fixture-") { return .stub }
        if tier.hasPrefix("vault-")   { return .real }
        if tier.hasPrefix("helios-")  { return .real }
        return .unknown
    }

    /// Build a `VaultRecallTrace` for `query` via the installed app-side
    /// search provider. Falls back to the Rust T21 scaffold only when no
    /// production provider is installed.
    /// Records latency + signal summary + backend origin into
    /// `VaultRecallMetrics`. Returns `nil` on error (caller's retrieval
    /// path is unaffected; the breadcrumb just goes silent).
    public static func trace(query: String) -> VaultRecallTrace? {
        let started = Date()
        if let provider = traceProviderStore.current() {
            do {
                if let trace = try provider(query) {
                    return recordTrace(trace, query: query, started: started)
                }
                log.info("VaultRecall production provider returned nil for query=\"\(query, privacy: .public)\"; falling back to scaffold")
            } catch {
                VaultRecallMetrics.shared.recordError(error)
                let message = RetrievalDiagnostics.statusMessage(
                    for: error,
                    fallback: "VaultRecall production provider failed"
                )
                log.error("\(message, privacy: .public)")
                return nil
            }
        }

        do {
            let raw = try vaultRecallTraceJson(query: query)
            guard let data = raw.data(using: .utf8) else {
                VaultRecallMetrics.shared.recordError(
                    NSError(domain: "VaultRecallBridge", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "non-utf8 JSON"])
                )
                return nil
            }
            let trace = try JSONDecoder().decode(VaultRecallTrace.self, from: data)
            return recordTrace(trace, query: query, started: started)
        } catch {
            VaultRecallMetrics.shared.recordError(error)
            let message = RetrievalDiagnostics.statusMessage(
                for: error,
                fallback: "VaultRecall trace failed"
            )
            log.error("\(message, privacy: .public)")
            return nil
        }
    }

    public static func recordProductionTrace(_ trace: VaultRecallTrace, latencyMs: Double) {
        let backend = detectedBackend(from: trace)
        VaultRecallMetrics.shared.record(latencyMs: latencyMs, trace: trace, backend: backend)
        log.info("VaultRecall production trace recorded query=\"\(trace.query, privacy: .public)\" tier=\(trace.ladderTier ?? "(nil)", privacy: .public) signals=\(trace.signalSummary.count, privacy: .public) retained=\(trace.candidatesRetained, privacy: .public) latency_ms=\(latencyMs, privacy: .public) backend=\(backend.rawValue, privacy: .public)")
    }

    private static func recordTrace(
        _ trace: VaultRecallTrace,
        query: String,
        started: Date
    ) -> VaultRecallTrace {
        let latencyMs = Date().timeIntervalSince(started) * 1000
        let backend = detectedBackend(from: trace)
        VaultRecallMetrics.shared.record(latencyMs: latencyMs, trace: trace, backend: backend)
        switch backend {
        case .stub:
            log.info("VaultRecall STUB path active for query=\"\(query, privacy: .public)\" tier=\(trace.ladderTier ?? "(nil)", privacy: .public) signals=\(trace.signalSummary.count, privacy: .public) retained=\(trace.candidatesRetained, privacy: .public) latency_ms=\(latencyMs, privacy: .public) (no production provider installed; candidates do not reflect user vault)")
        case .real:
            log.info("VaultRecall real-backend path active for query=\"\(query, privacy: .public)\" tier=\(trace.ladderTier ?? "(nil)", privacy: .public) signals=\(trace.signalSummary.count, privacy: .public) retained=\(trace.candidatesRetained, privacy: .public) latency_ms=\(latencyMs, privacy: .public)")
        case .unknown:
            log.info("VaultRecall path returned unknown-backend trace for query=\"\(query, privacy: .public)\" tier=\(trace.ladderTier ?? "(nil)", privacy: .public) retained=\(trace.candidatesRetained, privacy: .public) latency_ms=\(latencyMs, privacy: .public)")
        }
        return trace
    }
}
