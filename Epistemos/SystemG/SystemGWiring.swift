// SystemGWiring.swift
//
// Wiring #4 (T11 System G / Agent Runtime v2 → LocalAgentLoop) Swift glue.
//
// Three pieces:
//
//   - Swift Codable mirror for the Rust
//     `AgentRuntimeV2Mode` enum + `SystemGRuntimeStatus` shape (serde
//     `rename_all = "snake_case"` on the Rust side).
//   - `SystemGFlags` — UserDefaults gate for `EPISTEMOS_SYSTEM_G_V0`
//     (default OFF). Even when on, MAS bundles still see `mode =
//     disabled` from Rust per the doctrine tier-locking.
//   - `SystemGBridge` — sync wrapper around the UniFFI export
//     `systemGRuntimeStatusJson()`. Records the last good snapshot
//     into `SystemGMetrics` so the Settings -> Diagnostics health row
//     can render without a re-fetch on every paint.
//
// Scope lock: this is **status read only**. The full
// `AgentBlueprint → MissionPacket → SystemGAgentEvent stream → approval →
// MutationEnvelope → RunEventLog → AnswerPacket` flow lands in
// follow-up W-rows (W-11..W-18 + W-44/W-45). Swift wire shape pinned
// by the Rust serde derive.

import Foundation
import os

// MARK: - Mode + status mirrors

/// Mirrors Rust `AgentRuntimeV2Mode` (`agent_core::agent_runtime_v2::mode`).
/// `#[serde(rename_all = "snake_case")]` on the Rust side, so we use
/// snake_case raw values.
nonisolated public enum SystemGMode: String, Codable, Hashable, Sendable, CaseIterable {
    case disabled
    case ipcBounded = "ipc_bounded"
    case subprocess
}

/// Mirrors Rust `SystemGRuntimeStatus`.
nonisolated public struct SystemGRuntimeStatus: Codable, Hashable, Sendable {
    public let mode: SystemGMode
    public let allowsExecution: Bool
    public let allowsSubprocess: Bool
    public let buildTier: String

    enum CodingKeys: String, CodingKey {
        case mode
        case allowsExecution = "allows_execution"
        case allowsSubprocess = "allows_subprocess"
        case buildTier = "build_tier"
    }
}

/// Mirrors the JSON shape returned by Rust
/// `bridge::system_g_registry_stats_json` (Terminal C / P5).
/// `total` includes terminated runs still inside the
/// `TERMINATED_RUN_RETENTION` window; `inFlight` is just the runs
/// whose terminal event has not yet been drained.
nonisolated public struct SystemGRegistryStats: Codable, Hashable, Sendable {
    public let total: Int
    public let inFlight: Int
    public let maxConcurrentRuns: Int

    enum CodingKeys: String, CodingKey {
        case total
        case inFlight = "in_flight"
        case maxConcurrentRuns = "max_concurrent_runs"
    }
}

// MARK: - Feature flag

nonisolated public enum SystemGFlags {
    public static let userDefaultsKey = "EPISTEMOS_SYSTEM_G_V0"

    public static var isEnabled: Bool {
        if UserDefaults.standard.bool(forKey: userDefaultsKey) {
            return true
        }
        return ProcessInfo.processInfo.environment[userDefaultsKey] == "1"
    }
}

// MARK: - Metrics (last-good snapshot + read count)

nonisolated public final class SystemGMetrics: @unchecked Sendable {
    public static let shared = SystemGMetrics()
    public static let didChangeNotification = Notification.Name(
        "epistemos.systemGMetrics.didChange"
    )

    private let lock = NSLock()
    private var lastStatus: SystemGRuntimeStatus?
    private var lastReadAt: Date?
    private var totalReads: UInt64 = 0
    private var lastErrorDescription: String?
    private var lastErrorAt: Date?

    private init() {}

    public func recordRead(_ status: SystemGRuntimeStatus) {
        lock.lock()
        lastStatus = status
        lastReadAt = Date()
        totalReads &+= 1
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
            isFlagEnabled:        SystemGFlags.isEnabled,
            lastStatus:           lastStatus,
            lastReadAt:           lastReadAt,
            totalReads:           totalReads,
            lastErrorDescription: lastErrorDescription,
            lastErrorAt:          lastErrorAt
        )
    }

    public func reset() {
        lock.lock()
        lastStatus = nil
        lastReadAt = nil
        totalReads = 0
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
        public let lastStatus: SystemGRuntimeStatus?
        public let lastReadAt: Date?
        public let totalReads: UInt64
        public let lastErrorDescription: String?
        public let lastErrorAt: Date?
    }
}

// MARK: - Bridge

nonisolated public enum SystemGBridge {
    private static let log = Logger(subsystem: "com.epistemos", category: "system-g")

    /// Read the live runtime status from Rust. Returns `nil` on FFI
    /// error (LocalAgentLoop's flag-gated breadcrumb falls back to
    /// silent / the health row keeps its last-good snapshot).
    @discardableResult
    public static func status() -> SystemGRuntimeStatus? {
        do {
            let raw = try systemGRuntimeStatusJson()
            guard let data = raw.data(using: .utf8) else {
                let err = NSError(domain: "SystemGBridge", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "non-utf8 JSON"])
                SystemGMetrics.shared.recordError(err)
                return nil
            }
            let status = try JSONDecoder().decode(SystemGRuntimeStatus.self, from: data)
            SystemGMetrics.shared.recordRead(status)
            log.info("System G status: mode=\(status.mode.rawValue, privacy: .public) build_tier=\(status.buildTier, privacy: .public) allows_execution=\(status.allowsExecution, privacy: .public)")
            return status
        } catch {
            SystemGMetrics.shared.recordError(error)
            log.error("System G status read failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Read the dispatch-registry stats from Rust (Terminal C / P5).
    /// Returns `.success(stats)` on a clean decode, `.failure(error)`
    /// otherwise. The Rust FFI cannot throw (returns a JSON String
    /// directly); failure here means JSON decode failed.
    public static func registryStats() -> Result<SystemGRegistryStats, Error> {
        let raw = systemGRegistryStatsJson()
        guard let data = raw.data(using: .utf8) else {
            return .failure(NSError(
                domain: "SystemGBridge", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "registry stats JSON not utf-8"]
            ))
        }
        do {
            let stats = try JSONDecoder().decode(SystemGRegistryStats.self, from: data)
            return .success(stats)
        } catch {
            return .failure(error)
        }
    }
}
