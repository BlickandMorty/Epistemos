// ACSAdmissionWiring.swift
//
// Wiring #6 (T18B ACS dispatch admission gate) — HIGH RISK Swift glue.
//
// Per the mission spec, this wiring is flagged "HIGH RISK — gates
// everything; ship with extra care". The initial Swift surface is
// therefore **status read only**: we expose the strict policy summary
// (id, version, capability + threshold counts, canonical verdict
// labels) so Settings -> Diagnostics surfaces the substrate as live.
//
// **No production dispatch hooks are installed by this PR.** The
// actual admission gating remains in `agent_core::acs_admission` and
// production callers (oplog mutations, tool actions, kernel
// promotions) opt into the gate explicitly in follow-up wirings.
//
//   - `ACSAdmissionFlags` — UserDefaults gate
//     `EPISTEMOS_ACS_ADMISSION_V0` (default OFF). Flag-on only changes
//     the health row's status chip; it does NOT enable any production
//     gating.
//   - `ACSAdmissionMetrics` — last-good policy snapshot + read count.
//   - `ACSAdmissionBridge` — sync wrapper around the UniFFI export
//     `acsAdmissionStrictPolicySummaryJson()`.

import Foundation
import os

// MARK: - Policy summary mirror

nonisolated public struct ACSAdmissionPolicySummary: Codable, Hashable, Sendable {
    public let policyId: String
    public let version: UInt32
    public let validFromMs: Int64
    public let expiresAtMs: Int64?
    public let capabilityRulesCount: Int
    public let operationThresholdRulesCount: Int
    public let canonicalVerdicts: [String]

    enum CodingKeys: String, CodingKey {
        case policyId = "policy_id"
        case version
        case validFromMs = "valid_from_ms"
        case expiresAtMs = "expires_at_ms"
        case capabilityRulesCount = "capability_rules_count"
        case operationThresholdRulesCount = "operation_threshold_rules_count"
        case canonicalVerdicts = "canonical_verdicts"
    }
}

// MARK: - Feature flag

nonisolated public enum ACSAdmissionFlags {
    public static let userDefaultsKey = "EPISTEMOS_ACS_ADMISSION_V0"

    public static var isEnabled: Bool {
        if UserDefaults.standard.bool(forKey: userDefaultsKey) {
            return true
        }
        return ProcessInfo.processInfo.environment[userDefaultsKey] == "1"
    }
}

// MARK: - Metrics

nonisolated public final class ACSAdmissionMetrics: @unchecked Sendable {
    public static let shared = ACSAdmissionMetrics()
    public static let didChangeNotification = Notification.Name(
        "epistemos.acsAdmissionMetrics.didChange"
    )

    private let lock = NSLock()
    private var lastPolicy: ACSAdmissionPolicySummary?
    private var lastReadAt: Date?
    private var totalReads: UInt64 = 0
    private var lastErrorDescription: String?
    private var lastErrorAt: Date?

    private init() {}

    public func recordRead(_ summary: ACSAdmissionPolicySummary) {
        lock.lock()
        lastPolicy = summary
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
            isFlagEnabled:        ACSAdmissionFlags.isEnabled,
            lastPolicy:           lastPolicy,
            lastReadAt:           lastReadAt,
            totalReads:           totalReads,
            lastErrorDescription: lastErrorDescription,
            lastErrorAt:          lastErrorAt
        )
    }

    public func reset() {
        lock.lock()
        lastPolicy = nil
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
        public let lastPolicy: ACSAdmissionPolicySummary?
        public let lastReadAt: Date?
        public let totalReads: UInt64
        public let lastErrorDescription: String?
        public let lastErrorAt: Date?
    }
}

// MARK: - Bridge

nonisolated public enum ACSAdmissionBridge {
    private static let log = Logger(subsystem: "com.epistemos", category: "acs-admission")

    /// Read the strict ACS policy summary from Rust. Returns `nil` on
    /// FFI error.
    @discardableResult
    public static func strictPolicySummary() -> ACSAdmissionPolicySummary? {
        do {
            let raw = try acsAdmissionStrictPolicySummaryJson()
            guard let data = raw.data(using: .utf8) else {
                let err = NSError(domain: "ACSAdmissionBridge", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "non-utf8 JSON"])
                ACSAdmissionMetrics.shared.recordError(err)
                return nil
            }
            let summary = try JSONDecoder().decode(ACSAdmissionPolicySummary.self, from: data)
            ACSAdmissionMetrics.shared.recordRead(summary)
            log.info("ACS strict policy summary: id=\(summary.policyId, privacy: .public) version=\(summary.version, privacy: .public) cap_rules=\(summary.capabilityRulesCount, privacy: .public)")
            return summary
        } catch {
            ACSAdmissionMetrics.shared.recordError(error)
            log.error("ACS admission policy read failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
