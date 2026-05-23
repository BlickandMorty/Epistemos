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
    private var totalQueries: UInt64 = 0
    private var lastErrorDescription: String?
    private var lastErrorAt: Date?

    private init() {}

    public func record(latencyMs: Double, citationCount: Int) {
        lock.lock()
        samples.append(latencyMs)
        if samples.count > Self.bufferCap {
            samples.removeFirst(samples.count - Self.bufferCap)
        }
        lastLatencyMs = latencyMs
        lastQueryAt = Date()
        lastCitationCount = citationCount
        totalQueries &+= 1
        lastErrorDescription = nil
        lock.unlock()
        notifyDidChange()
    }

    public func recordError(_ error: Error) {
        lock.lock()
        lastErrorDescription = String(describing: error)
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

    /// Run a lexical Eidos search and return the decoded packet. Records
    /// latency + citation count into `EidosMetrics` on success. Returns
    /// `nil` on any error (caller falls back to FTS / RRF path).
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
            EidosMetrics.shared.record(
                latencyMs: latencyMs,
                citationCount: packet.hits.count
            )
            log.info("Eidos path active for query=\"\(query, privacy: .public)\" hits=\(packet.hits.count, privacy: .public) latency_ms=\(latencyMs, privacy: .public)")
            return packet
        } catch {
            EidosMetrics.shared.recordError(error)
            log.error("Eidos search failed for query=\"\(query, privacy: .public)\": \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
