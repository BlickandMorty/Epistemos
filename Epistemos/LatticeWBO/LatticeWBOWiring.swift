// LatticeWBOWiring.swift
//
// Wiring #3 (T17B lattice/WBO → oplog write path) — Swift-side glue.
//
// NO FEATURE FLAG. The Rust-side accounting hook in `OpLog::append`
// runs on every mutation by design (per the T17B contract that hidden
// mutations are inadmissible to the WBO ledger). This file ships the
// read-only Swift mirror of the accountant snapshot + a bridge wrapper
// the `LatticeWBOHealthRow` polls on view-appear and on demand.

import Foundation
import os

// MARK: - Stats mirror

/// Read-only Swift mirror of `agent_core::oplog_lattice_wbo::LatticeWboOplogStats`.
/// Wire shape pinned by the Rust serde derives; JSON round-trips byte-equal.
nonisolated public struct LatticeWBOStats: Codable, Hashable, Sendable {
    public let appendsAccounted: UInt64
    public let tier: String
    public let falsifier: String
    public let lastActorId: String?
    public let lastTsUnixMs: Int64?

    enum CodingKeys: String, CodingKey {
        case appendsAccounted = "appends_accounted"
        case tier
        case falsifier
        case lastActorId = "last_actor_id"
        case lastTsUnixMs = "last_ts_unix_ms"
    }

    /// All-zero baseline before the first read.
    public static let empty = LatticeWBOStats(
        appendsAccounted: 0,
        tier: "—",
        falsifier: "—",
        lastActorId: nil,
        lastTsUnixMs: nil
    )
}

// MARK: - Bridge

nonisolated public enum LatticeWBOBridge {
    private static let log = Logger(subsystem: "com.epistemos", category: "lattice-wbo")

    /// Read the live accountant snapshot from Rust. Returns `nil` on
    /// FFI error (the health row falls back to the last good snapshot).
    public static func snapshot() -> LatticeWBOStats? {
        do {
            let raw = try oplogLatticeWboStatsJson()
            guard let data = raw.data(using: .utf8) else {
                log.error("LatticeWBO stats: non-utf8 JSON")
                return nil
            }
            let stats = try JSONDecoder().decode(LatticeWBOStats.self, from: data)
            return stats
        } catch {
            log.error("LatticeWBO stats fetch failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
