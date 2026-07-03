// EidosWiring.swift
//
// Wiring #1 (T10 Eidos → QueryRuntime) — Swift-side glue.
//
// Pieces in this file:
//
//   - `EidosFlags`        — UserDefaults gate for `EPISTEMOS_EIDOS_V0`.
//                            Default OFF; flipping it routes search through
//                            `RetrievalRuntime.fullText`'s Eidos branch.
//   - `EidosMetrics`      — bounded ring-buffer observability mirror of
//                            `SearchFusionMetrics`. Read by the Settings
//                            health row.
//   - `EidosBridge`       — sync wrapper around the UniFFI export
//                            `eidosSearchLexicalJson(query:topK:)`. Decodes
//                            the returned JSON into the existing
//                            `EidosContextPacket` Codable mirror in
//                            `Eidos.swift` so the closed-citation contract
//                            stays end-to-end testable from Swift.
//
// **Scope lock**: the Rust side seeds a small fixture corpus on first call.
// Real vault binding (W-46.1) swaps the corpus without touching this file —
// the JSON wire shape is pinned by the Eidos types.

import Foundation
import os

// MARK: - Backend honesty
//
// The Rust side currently seeds a fixture corpus on first call
// (`agent_core::eidos::wiring::seed_fixture_corpus`). Until Terminal 2
// swaps that fixture for a real vault-backed `EidosRetriever` (W-46.1 in
// CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md), every packet that
// reaches Swift is fixture data. The hardening bar says the UI must not
// claim "working" against fixture data, so we surface backend origin
// alongside latency + citation count and the EidosHealthRow shows the
// fixture state prominently.
//
// **Detection contract** (forward-compatible with Terminal 2's real
// vault binding, no Rust change required to flip Swift to `.real`):
//
//   - `eidos-fixture-*` manifest_id → `.fixture`
//   - `vault-*`         manifest_id → `.real`
//   - anything else                 → `.unknown`
//
// When Terminal 2 lands the real vault binding, the Rust side already
// emits a `vault-<sha256-of-vault-path>` manifest_id (per the W-46
// design doc in `docs/EIDOS_V0_CLOSED_CITATION_DESIGN_2026_05_18.md`),
// so this heuristic flips to `.real` automatically. If Terminal 2 needs
// a stronger signal (e.g. a corpus-stats sidecar field on
// `EidosContextPacket`), the snapshot already carries `lastBackend` and
// the row already renders it — Swift-side change is then a one-line
// update of `detectedBackend(from:)` to read the new field.
nonisolated public enum EidosBackend: String, Sendable, Hashable {
    /// Rust side returned data from the seeded fixture corpus. UI must
    /// not claim "working" — fall-through to RRF/legacy is expected.
    case fixture
    /// Rust side returned data from a real vault-bound `EidosRetriever`.
    /// Closed-citation contract holds end-to-end against production
    /// content.
    case real
    /// No search has run yet, the manifest_id prefix did not match either
    /// known shape, or the JSON did not decode.
    case unknown
}

nonisolated public enum EidosFlags {
    /// UserDefaults key for the Wiring #1 feature gate. Default OFF.
    public static let userDefaultsKey = "EPISTEMOS_EIDOS_V0"

    /// `true` when `UserDefaults.standard.bool(forKey: "EPISTEMOS_EIDOS_V0")`
    /// is set. Falls back to the env-var of the same name so dev/test
    /// fixtures can toggle without writing to user defaults.
    public static var isEnabled: Bool {
        if UserDefaults.standard.bool(forKey: userDefaultsKey) {
            return true
        }
        return ProcessInfo.processInfo.environment[userDefaultsKey] == "1"
    }
}

/// In-memory observability for the Eidos retrieval path. Mirrors the shape
/// of `SearchFusionMetrics` (ring-buffer latency + p95 + last error) so the
/// Settings health row can render in the same vocabulary as RRF Fusion's
/// existing diagnostic surface.
nonisolated public final class EidosMetrics: @unchecked Sendable {
    public static let shared = EidosMetrics()
    public static let didChangeNotification = Notification.Name(
        "epistemos.eidosMetrics.didChange"
    )

    /// Sample-buffer cap (same as SearchFusionMetrics; ~40 KB peak).
    public static let bufferCap = 200

    private let lock = NSLock()
    private var samples: [Double] = []
    private var lastLatencyMs: Double = 0
    private var lastQueryAt: Date?
    private var lastCitationCount: Int = 0
    private var lastBackendValue: EidosBackend = .unknown
    private var totalQueries: UInt64 = 0
    private var lastErrorDescription: String?
    private var lastErrorAt: Date?

    private init() {}

    public func record(latencyMs: Double, citationCount: Int, backend: EidosBackend) {
        lock.lock()
        samples.append(latencyMs)
        if samples.count > Self.bufferCap {
            samples.removeFirst(samples.count - Self.bufferCap)
        }
        lastLatencyMs = latencyMs
        lastQueryAt = Date()
        lastCitationCount = citationCount
        lastBackendValue = backend
        totalQueries &+= 1
        lastErrorDescription = nil
        lock.unlock()
        notifyDidChange()
    }

    public func recordError(_ error: Error) {
        lock.lock()
        lastErrorDescription = RetrievalDiagnostics.statusMessage(
            for: error,
            fallback: "Eidos retrieval failed"
        )
        lastErrorAt = Date()
        lock.unlock()
        notifyDidChange()
    }

    public func snapshot() -> Snapshot {
        lock.lock(); defer { lock.unlock() }
        return Snapshot(
            isFlagEnabled:        EidosFlags.isEnabled,
            lastQueryAt:          lastQueryAt,
            lastLatencyMs:        lastLatencyMs,
            p95LatencyMs:         Self.percentile(samples, 0.95),
            sampleCount:          samples.count,
            totalQueries:         totalQueries,
            lastCitationCount:    lastCitationCount,
            lastBackend:          lastBackendValue,
            lastErrorDescription: lastErrorDescription,
            lastErrorAt:          lastErrorAt
        )
    }

    public func reset() {
        lock.lock()
        samples.removeAll(keepingCapacity: true)
        lastLatencyMs = 0
        lastQueryAt = nil
        lastCitationCount = 0
        lastBackendValue = .unknown
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

    public struct Snapshot: Sendable {
        public let isFlagEnabled: Bool
        public let lastQueryAt: Date?
        public let lastLatencyMs: Double
        public let p95LatencyMs: Double
        public let sampleCount: Int
        public let totalQueries: UInt64
        public let lastCitationCount: Int
        public let lastBackend: EidosBackend
        public let lastErrorDescription: String?
        public let lastErrorAt: Date?
    }

    nonisolated private static func percentile(_ values: [Double], _ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let idx = max(0, min(sorted.count - 1, Int((p * Double(sorted.count)).rounded(.up)) - 1))
        return sorted[idx]
    }
}

/// Sync Swift wrapper around the UniFFI export `eidosSearchLexicalJson`.
/// Returns a decoded `EidosContextPacket` and records timing into
/// `EidosMetrics.shared`. On error, records the error and returns nil so
/// callers can fall through to the legacy retrieval path.
nonisolated public enum EidosBridge {
    /// `os_log` channel for the Wiring #1 breadcrumb requested by the WRV
    /// "Reachable" bar — a single info-level log per Eidos-routed query.
    private static let log = Logger(subsystem: "com.epistemos", category: "eidos")

    /// Inspect an `EidosContextPacket` and report whether it came from the
    /// fixture corpus or a real vault-backed retriever. See the file-head
    /// "Backend honesty" comment for the contract.
    public static func detectedBackend(from packet: EidosContextPacket) -> EidosBackend {
        let manifest = packet.manifestId.raw
        if manifest.hasPrefix("eidos-fixture-") { return .fixture }
        if manifest.hasPrefix("vault-")         { return .real }
        return .unknown
    }

    /// Run a lexical Eidos search and return the decoded packet. Records
    /// latency + citation count + backend origin into `EidosMetrics` on
    /// success. Returns `nil` on any error (caller falls back to FTS /
    /// RRF path).
    public static func search(query: String, topK: UInt32 = 12) -> EidosContextPacket? {
        let started = Date()
        do {
            let raw = try eidosSearchLexicalJson(query: query, topK: topK)
            guard let data = raw.data(using: .utf8) else {
                EidosMetrics.shared.recordError(
                    NSError(domain: "EidosBridge", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "non-utf8 JSON"])
                )
                return nil
            }
            let packet = try JSONDecoder().decode(EidosContextPacket.self, from: data)
            let latencyMs = Date().timeIntervalSince(started) * 1000
            let backend = detectedBackend(from: packet)
            EidosMetrics.shared.record(
                latencyMs: latencyMs,
                citationCount: packet.hits.count,
                backend: backend
            )
            switch backend {
            case .fixture:
                log.info("Eidos FIXTURE path active for query=\"\(query, privacy: .private)\" hits=\(packet.hits.count, privacy: .public) latency_ms=\(latencyMs, privacy: .public) (Terminal 2 real-vault binding pending W-46.1; fall-through to RRF/legacy expected)")
            case .real:
                log.info("Eidos real-vault path active for query=\"\(query, privacy: .private)\" hits=\(packet.hits.count, privacy: .public) latency_ms=\(latencyMs, privacy: .public) manifest=\(packet.manifestId.raw, privacy: .public)")
            case .unknown:
                log.info("Eidos path returned unknown-backend packet for query=\"\(query, privacy: .private)\" manifest=\(packet.manifestId.raw, privacy: .public) hits=\(packet.hits.count, privacy: .public) latency_ms=\(latencyMs, privacy: .public)")
            }
            return packet
        } catch {
            EidosMetrics.shared.recordError(error)
            let message = RetrievalDiagnostics.statusMessage(
                for: error,
                fallback: "Eidos search failed"
            )
            log.error("\(message, privacy: .public)")
            return nil
        }
    }
}
