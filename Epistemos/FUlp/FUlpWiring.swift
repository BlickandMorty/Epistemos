// FUlpWiring.swift
//
// Wiring #5 (T12 F-ULP -> EML witness emission path) Swift glue.
//
// The F-ULP oracle gates the EML witness arithmetic floor (≤2 ULP
// fp16 over `[0.5, 2]` across exp/ln/eml; ~412k stratified + 2k
// adversarial points; `AnswerPacket schema freeze blocked until this
// gate is green` per DECK:266). This file ships:
//
//   - `FUlpFlags` — UserDefaults gate `EPISTEMOS_F_ULP_ORACLE_V0`.
//     Default OFF.
//   - `FUlpMetrics` — last-good witness snapshot + verdict.
//   - `FUlpBridge` — sync wrapper around the UniFFI export
//     `fulpOracleAcceptanceWitnessJson()`. Triggered on demand from
//     the Settings -> Diagnostics health row's "Run F-ULP acceptance"
//     button.
//
// Scope lock: status read only. EML witness emission paths (e.g.
// AnswerPacketEmitter) consume `FUlpBridge.lastWitness` indirectly
// through the metrics surface; deeper hooks land in W-44/W-45.
//
// **Important**: the underlying Rust FFI is `research`-feature only.
// On MAS bundles the call returns an `AgentError` that explains the
// gating; the Swift surface degrades gracefully — `FUlpBridge.run()`
// records the error and `FUlpHealthRow` shows the gate as
// `research-only` rather than red.

import Foundation
import os

// MARK: - Witness mirrors

nonisolated public struct FUlpHardwarePin: Codable, Hashable, Sendable {
    public let cpu: String
    public let m_series_chip: String?

    enum CodingKeys: String, CodingKey {
        case cpu
        case m_series_chip = "m_series_chip"
    }
}

nonisolated public struct FUlpRunConfig: Codable, Hashable, Sendable {
    public let stratified_points: UInt64?
    public let adversarial_points: UInt64?
    public let ulp_tolerance: Double?

    enum CodingKeys: String, CodingKey {
        case stratified_points
        case adversarial_points
        case ulp_tolerance
    }
}

nonisolated public struct FUlpOperationStats: Codable, Hashable, Sendable {
    public let operation: String?
    public let evaluations: UInt64?
    public let max_ulp: Double?
    public let worst_case: FUlpWorstCase?
}

nonisolated public struct FUlpWorstCase: Codable, Hashable, Sendable {
    public let x: Double?
    public let y: Double?
    public let reference: Double?
    public let evaluated: Double?
    public let ulp_distance: Double?
}

nonisolated public struct FUlpWitness: Codable, Hashable, Sendable {
    public let schema_version: UInt32
    public let mission: String
    public let hardware: FUlpHardwarePin
    public let budget_target_seconds: UInt32
    public let config: FUlpRunConfig
    public let evaluator_variant: String
    public let point_count: UInt64
    public let operation_evaluations: UInt64
    public let grid_fingerprint: String
    public let stats: [FUlpOperationStats]
    public let pass: Bool
}

// MARK: - Feature flag

nonisolated public enum FUlpFlags {
    public static let userDefaultsKey = "EPISTEMOS_F_ULP_ORACLE_V0"

    public static var isEnabled: Bool {
        if UserDefaults.standard.bool(forKey: userDefaultsKey) {
            return true
        }
        return ProcessInfo.processInfo.environment[userDefaultsKey] == "1"
    }
}

// MARK: - Metrics

nonisolated public final class FUlpMetrics: @unchecked Sendable {
    public static let shared = FUlpMetrics()
    public static let didChangeNotification = Notification.Name(
        "epistemos.fUlpMetrics.didChange"
    )

    private let lock = NSLock()
    private var lastWitness: FUlpWitness?
    private var lastRunAt: Date?
    private var totalRuns: UInt64 = 0
    private var lastErrorDescription: String?
    private var lastErrorAt: Date?

    private init() {}

    public func recordRun(_ witness: FUlpWitness) {
        lock.lock()
        lastWitness = witness
        lastRunAt = Date()
        totalRuns &+= 1
        lastErrorDescription = nil
        lock.unlock()
        notifyDidChange()
    }

    public func recordError(_ error: Error) {
        lock.lock()
        lastErrorDescription = RetrievalDiagnostics.statusMessage(
            for: error,
            fallback: "F-ULP acceptance witness failed"
        )
        lastErrorAt = Date()
        lock.unlock()
        notifyDidChange()
    }

    public func snapshot() -> Snapshot {
        lock.lock(); defer { lock.unlock() }
        return Snapshot(
            isFlagEnabled:        FUlpFlags.isEnabled,
            lastWitness:          lastWitness,
            lastRunAt:            lastRunAt,
            totalRuns:            totalRuns,
            lastErrorDescription: lastErrorDescription,
            lastErrorAt:          lastErrorAt
        )
    }

    public func reset() {
        lock.lock()
        lastWitness = nil
        lastRunAt = nil
        totalRuns = 0
        lastErrorDescription = nil
        lastErrorAt = nil
        lock.unlock()
        notifyDidChange()
    }

    private func notifyDidChange() {
        if Thread.isMainThread {
            NotificationCenter.default.post(
                name: Self.didChangeNotification,
                object: self
            )
        } else {
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: Self.didChangeNotification,
                    object: self
                )
            }
        }
    }

    public struct Snapshot: Sendable {
        public let isFlagEnabled: Bool
        public let lastWitness: FUlpWitness?
        public let lastRunAt: Date?
        public let totalRuns: UInt64
        public let lastErrorDescription: String?
        public let lastErrorAt: Date?
    }
}

// MARK: - Bridge

nonisolated public enum FUlpBridge {
    private static let log = Logger(subsystem: "com.epistemos", category: "f-ulp")

    /// Run the F-ULP acceptance witness via Rust. Records latency +
    /// witness into `FUlpMetrics`. Returns `nil` on FFI error (e.g.
    /// MAS build without research feature compiled in).
    @discardableResult
    public static func run() -> FUlpWitness? {
        let started = Date()
        do {
            let raw = try fulpOracleAcceptanceWitnessJson()
            guard let data = raw.data(using: .utf8) else {
                let err = NSError(domain: "FUlpBridge", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "non-utf8 JSON"])
                FUlpMetrics.shared.recordError(err)
                return nil
            }
            let witness = try JSONDecoder().decode(FUlpWitness.self, from: data)
            let latencyMs = Date().timeIntervalSince(started) * 1000
            FUlpMetrics.shared.recordRun(witness)
            log.info("F-ULP acceptance witness pass=\(witness.pass, privacy: .public) points=\(witness.point_count, privacy: .public) latency_ms=\(latencyMs, privacy: .public)")
            return witness
        } catch {
            FUlpMetrics.shared.recordError(error)
            let message = RetrievalDiagnostics.statusMessage(
                for: error,
                fallback: "F-ULP acceptance witness failed"
            )
            log.error("\(message, privacy: .public)")
            return nil
        }
    }
}
