import Foundation
import Observation
import os

// MARK: - RuntimeRouter (Phase 2 Terminal T1 — 2026-05-24)
//
// The multi-lane router that replaces the single-lane `ConfidenceRouter`.
// MLX is **one lane among several** here — the router picks among
// MLX, GGUF/llama.cpp, Apple Intelligence, and cloud providers using a
// per-role policy table (`localPolicyTable`) + a per-role model
// preference table (`modelPreferenceTable`). When a lane is disabled
// (Settings → Inference → Runtime Lanes) the router falls through to
// the next lane and **logs an honest escalation entry** — never a
// silent fallback.
//
// 7-Law alignment lives in `RuntimeExecutor.swift`. This file owns the
// dispatch policy, the lane-toggle persistence, and the observable
// metrics surfaced by `RuntimeRouterHealthRow`.

// MARK: - LocalPolicy

/// Per-role local-routing policy. Mirrors the shape
/// `ConfidenceRouter` used (uncertaintyThreshold, maxComplexity,
/// maxToolCount) and extends it with per-role idle-unload + minimum
/// context window the role needs to feel honest.
nonisolated public struct LocalPolicy: Sendable, Equatable, Codable, Hashable {
    public let role: RuntimeRole
    public let minimumConfidence: Double
    public let maximumComplexity: Double
    public let maximumToolCount: Int
    public let minimumContextWindow: Int
    public let allowsVisionFallthrough: Bool
    public let idleUnloadDelaySeconds: Int
    public let idleUnloadMode: String

    public init(
        role: RuntimeRole,
        minimumConfidence: Double,
        maximumComplexity: Double,
        maximumToolCount: Int,
        minimumContextWindow: Int,
        allowsVisionFallthrough: Bool,
        idleUnloadDelaySeconds: Int,
        idleUnloadMode: String
    ) {
        self.role = role
        self.minimumConfidence = minimumConfidence
        self.maximumComplexity = maximumComplexity
        self.maximumToolCount = maximumToolCount
        self.minimumContextWindow = minimumContextWindow
        self.allowsVisionFallthrough = allowsVisionFallthrough
        self.idleUnloadDelaySeconds = idleUnloadDelaySeconds
        self.idleUnloadMode = idleUnloadMode
    }
}

// MARK: - RouteProfile

/// One per-role row published by `routeProfiles()`. Mirrors
/// `ConfidenceRouter.RouteProfile` so `LocalAgentDiagnostics` and
/// `RuntimeRouterHealthRow` can render either source. The lane-aware
/// fields (`preferredLanes`) are new — they are the reason this
/// profile replaces the single-lane one.
nonisolated struct RouteProfile: Sendable, Equatable, Identifiable {
    let role: RuntimeRole
    let preferredLanes: [RuntimeLane]
    let preferredModelIDs: [String]
    let primaryModelID: String?
    let primaryModelName: String
    let nativeGrammar: LocalToolGrammar.NativeToolGrammar
    let minimumConfidence: Double
    let maximumComplexity: Double
    let maximumToolCount: Int
    let idleUnloadDelaySeconds: Int
    let idleUnloadMode: String

    var id: String { role.rawValue }

    var displayName: String { role.displayName }

    var fallbackCount: Int {
        max(0, preferredModelIDs.count - 1)
    }

    var laneCount: Int { preferredLanes.count }

    var policySummary: String {
        "conf \(formatted(minimumConfidence)) · complexity \(formatted(maximumComplexity)) · tools \(maximumToolCount)"
    }

    var idleUnloadSummary: String {
        "idle \(idleUnloadDelaySeconds)s \(idleUnloadMode)"
    }

    var laneSummary: String {
        preferredLanes.map { $0.stableID }.joined(separator: " → ")
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

// MARK: - RuntimeRouterMetrics

/// Ring-buffered metrics published to `RuntimeRouterHealthRow`. The
/// ring covers the last 100 verdicts emitted by the router; the
/// escalation tally is monotonic for the session lifetime.
nonisolated public struct RuntimeRouterMetrics: Sendable, Equatable, Codable {
    public static let ringCapacity: Int = 100

    public struct VerdictEntry: Sendable, Equatable, Codable, Hashable, Identifiable {
        public let id: String
        public let timestamp: Date
        public let role: RuntimeRole
        public let lane: RuntimeLane
        public let kind: Kind
        /// Optional human-readable detail (e.g. escalation reason).
        public let detail: String?

        public enum Kind: String, Sendable, Equatable, Codable {
            case accept
            case escalate
            case reject
        }

        public init(
            id: String = UUID().uuidString,
            timestamp: Date = Date(),
            role: RuntimeRole,
            lane: RuntimeLane,
            kind: Kind,
            detail: String? = nil
        ) {
            self.id = id
            self.timestamp = timestamp
            self.role = role
            self.lane = lane
            self.kind = kind
            self.detail = detail
        }
    }

    public private(set) var ring: [VerdictEntry]
    public private(set) var escalationsByLane: [String: Int]
    public private(set) var acceptsByLane: [String: Int]
    public private(set) var rejectCount: Int

    public init() {
        self.ring = []
        self.escalationsByLane = [:]
        self.acceptsByLane = [:]
        self.rejectCount = 0
    }

    public mutating func record(_ entry: VerdictEntry) {
        ring.append(entry)
        if ring.count > Self.ringCapacity {
            ring.removeFirst(ring.count - Self.ringCapacity)
        }
        switch entry.kind {
        case .accept:
            acceptsByLane[entry.lane.stableID, default: 0] += 1
        case .escalate:
            escalationsByLane[entry.lane.stableID, default: 0] += 1
        case .reject:
            rejectCount += 1
        }
    }

    public var totalCount: Int { ring.count }

    /// Lane-keyed accept/escalation tally — what the chip strip renders.
    public func tally(for lane: RuntimeLane) -> (accepts: Int, escalations: Int) {
        (acceptsByLane[lane.stableID] ?? 0, escalationsByLane[lane.stableID] ?? 0)
    }
}

// MARK: - RuntimeAgentCapabilityBadgeData

nonisolated enum RuntimeAgentCapabilityState: String, Sendable, Codable, Hashable, CaseIterable {
    case honest = "HONEST"
    case experimental = "EXPERIMENTAL"
    case off = "OFF"
}

nonisolated struct RuntimeAgentCapabilityBadgeData: Sendable, Equatable {
    let state: RuntimeAgentCapabilityState
    let lane: RuntimeLane
    let nativeGrammar: LocalToolGrammar.NativeToolGrammar
    let toolCallMode: RuntimeToolCallMode
    let witness: String
    let falsifier: String
    let reason: String

    var title: String { state.rawValue }
}

// MARK: - RuntimeRouter

/// Observable, MainActor-isolated multi-lane router. The router is
/// the single dispatch policy the rest of the app calls into — there
/// is no second routing surface.
@MainActor
@Observable
public final class RuntimeRouter {
    private static let log = Logger(subsystem: "ai.epistemos", category: "RuntimeRouter")

    /// Persisted-lane-enabled key prefix. Each lane stores its
    /// boolean toggle under `<prefix><lane.stableID>`.
    public static let laneEnabledDefaultsKeyPrefix = "epistemos.runtimeRouter.laneEnabled."

    /// Singleton used by the app. Tests construct their own router
    /// via `init(initialLanes:)` to avoid touching UserDefaults.
    public static let shared: RuntimeRouter = RuntimeRouter(initialLanes: RuntimeRouter.defaultStubLanes())

    /// Registered lanes keyed by lane identity. Tests can swap
    /// executors in without rebuilding the router.
    public private(set) var lanes: [RuntimeLane: any RuntimeExecutor]

    /// Per-lane enable flag. Read from UserDefaults at init; written
    /// back when `setLaneEnabled(_:_:)` is called from Settings.
    public private(set) var laneEnabled: [RuntimeLane: Bool]

    /// Observable metrics for the last 100 verdicts + escalation count.
    public private(set) var metrics: RuntimeRouterMetrics

    /// In-memory log of escalation events for the audit trail. The
    /// ring (`metrics.ring`) is the surface the UI reads; this is the
    /// long-form text log the diagnostics row pages through.
    public private(set) var escalationLog: [String]

    /// When `false`, the router neither reads nor writes UserDefaults
    /// for lane-enable persistence. Tests pass `false` so parallel
    /// suites cannot race through the global UserDefaults state.
    /// The production singleton uses `true`.
    private let usesPersistence: Bool

    public init(initialLanes: [any RuntimeExecutor] = [], persistsToUserDefaults: Bool = true) {
        var laneMap: [RuntimeLane: any RuntimeExecutor] = [:]
        for executor in initialLanes {
            laneMap[executor.id] = executor
        }
        self.lanes = laneMap
        self.usesPersistence = persistsToUserDefaults

        var enabled: [RuntimeLane: Bool] = [:]
        for lane in RuntimeLane.knownLanes {
            if persistsToUserDefaults {
                let key = Self.laneEnabledDefaultsKeyPrefix + lane.stableID
                if let value = UserDefaults.standard.object(forKey: key) as? Bool {
                    enabled[lane] = value
                } else {
                    enabled[lane] = true
                }
            } else {
                enabled[lane] = true
            }
        }
        // Lanes registered post-init that aren't in knownLanes default to enabled.
        for lane in laneMap.keys where enabled[lane] == nil {
            enabled[lane] = true
        }
        self.laneEnabled = enabled
        self.metrics = RuntimeRouterMetrics()
        self.escalationLog = []
    }

    // MARK: - Lane registration

    public func register(_ executor: any RuntimeExecutor) {
        lanes[executor.id] = executor
        if laneEnabled[executor.id] == nil {
            laneEnabled[executor.id] = true
        }
    }

    public func unregister(_ lane: RuntimeLane) async {
        if let executor = lanes.removeValue(forKey: lane) {
            await executor.teardown()
        }
    }

    public func executor(for lane: RuntimeLane) -> (any RuntimeExecutor)? {
        lanes[lane]
    }

    public func isLaneEnabled(_ lane: RuntimeLane) -> Bool {
        laneEnabled[lane] ?? true
    }

    /// Flip a lane on/off. Persists the choice in UserDefaults and
    /// — critically — does NOT silently drop in-flight requests. The
    /// next `route(_:)` call will produce an honest escalation
    /// `.escalate(from: lane, to: …, reason: .laneDisabled)`.
    public func setLaneEnabled(_ lane: RuntimeLane, _ enabled: Bool) {
        laneEnabled[lane] = enabled
        if usesPersistence {
            let key = Self.laneEnabledDefaultsKeyPrefix + lane.stableID
            UserDefaults.standard.set(enabled, forKey: key)
        }
        let entry = "[\(Date().formatted(.iso8601))] lane=\(lane.stableID) enabled=\(enabled)"
        escalationLog.append(entry)
        Self.log.info("RuntimeRouter lane=\(lane.stableID) enabled=\(enabled)")
    }

    // MARK: - routeProfiles (≥ 6 non-empty per-role rows)

    /// **Acceptance gate:** returns ≥ 6 non-empty per-role profiles —
    /// one row per `RuntimeRole`. The data is composed by joining
    /// the `localPolicyTable` (per-role policy) with the
    /// `modelPreferenceTable` (per-role preferred model IDs).
    func routeProfiles() -> [RouteProfile] {
        Self.defaultRouteProfiles()
    }

    nonisolated static func defaultRouteProfiles() -> [RouteProfile] {
        RuntimeRole.allCases.map { role in
            let policy = localPolicyTable[role] ?? defaultLocalPolicy(for: role)
            let preferred = modelPreferenceTable[role] ?? []
            let lanes = defaultPreferredLanes(for: role)
            let primaryID = preferred.first
            let primaryName: String
            if let primaryID, !primaryID.isEmpty {
                primaryName = displayName(forModelID: primaryID)
            } else {
                primaryName = lanes.first?.displayName ?? "—"
            }
            return RouteProfile(
                role: role,
                preferredLanes: lanes,
                preferredModelIDs: preferred,
                primaryModelID: primaryID,
                primaryModelName: primaryName,
                nativeGrammar: LocalToolGrammar.nativeGrammar(forModelID: primaryID),
                minimumConfidence: policy.minimumConfidence,
                maximumComplexity: policy.maximumComplexity,
                maximumToolCount: policy.maximumToolCount,
                idleUnloadDelaySeconds: policy.idleUnloadDelaySeconds,
                idleUnloadMode: policy.idleUnloadMode
            )
        }
    }

    // MARK: - localPolicyTable + modelPreferenceTable (per-role tables)

    /// Per-role local routing policy. The router reads this when it
    /// has to decide whether the local lane (MLX/GGUF) can serve the
    /// request or must escalate to cloud.
    nonisolated public static let localPolicyTable: [RuntimeRole: LocalPolicy] = [
        .code: LocalPolicy(
            role: .code,
            minimumConfidence: 0.70,
            maximumComplexity: 0.80,
            maximumToolCount: 4,
            minimumContextWindow: 16_000,
            allowsVisionFallthrough: false,
            idleUnloadDelaySeconds: 30,
            idleUnloadMode: "deep"
        ),
        .reasoning: LocalPolicy(
            role: .reasoning,
            minimumConfidence: 0.65,
            maximumComplexity: 0.85,
            maximumToolCount: 2,
            minimumContextWindow: 8_000,
            allowsVisionFallthrough: false,
            idleUnloadDelaySeconds: 45,
            idleUnloadMode: "deep"
        ),
        .quick: LocalPolicy(
            role: .quick,
            minimumConfidence: 0.55,
            maximumComplexity: 0.45,
            maximumToolCount: 1,
            minimumContextWindow: 4_000,
            allowsVisionFallthrough: false,
            idleUnloadDelaySeconds: 15,
            idleUnloadMode: "shallow"
        ),
        .toolCaller: LocalPolicy(
            role: .toolCaller,
            minimumConfidence: 0.70,
            maximumComplexity: 0.60,
            maximumToolCount: 6,
            minimumContextWindow: 16_000,
            allowsVisionFallthrough: false,
            idleUnloadDelaySeconds: 30,
            idleUnloadMode: "deep"
        ),
        .trivial: LocalPolicy(
            role: .trivial,
            minimumConfidence: 0.40,
            maximumComplexity: 0.25,
            maximumToolCount: 0,
            minimumContextWindow: 2_000,
            allowsVisionFallthrough: false,
            idleUnloadDelaySeconds: 10,
            idleUnloadMode: "shallow"
        ),
        .vision: LocalPolicy(
            role: .vision,
            minimumConfidence: 0.55,
            maximumComplexity: 0.60,
            maximumToolCount: 1,
            minimumContextWindow: 8_000,
            allowsVisionFallthrough: true,
            idleUnloadDelaySeconds: 30,
            idleUnloadMode: "deep"
        ),
    ]

    /// Per-role preferred local model IDs (priority order). Cloud
    /// lanes don't appear here — they are reached through the
    /// `preferredLanes` chain. The IDs reference `LocalTextModelID`
    /// raw values from `Epistemos/State/InferenceState.swift`.
    nonisolated public static let modelPreferenceTable: [RuntimeRole: [String]] = [
        .code: [
            "mlx-community/Qwen3-Coder-Next-4bit",
            "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit",
            "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit",
        ],
        .reasoning: [
            "mlx-community/QwQ-32B-4bit",
            "mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit",
            "mlx-community/Qwen3-4B-Thinking-2507-4bit",
        ],
        .quick: [
            "Qwen/Qwen3-4B-MLX-4bit",
            "Qwen/Qwen3-8B-MLX-4bit",
            "LiquidAI/LFM2.5-1.2B-Instruct-MLX-4bit",
        ],
        .toolCaller: [
            "leonsarmiento/Hermes-4.3-36B-4bit-mlx",
            "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit",
            "Qwen/Qwen3-8B-MLX-4bit",
        ],
        .trivial: [
            "LiquidAI/LFM2.5-350M-MLX-4bit",
            "LiquidAI/LFM2.5-1.2B-Instruct-MLX-4bit",
            "mlx-community/SmolLM3-3B-4bit",
        ],
        .vision: [
            "mlx-community/LFM2.5-VL-1.6B-4bit",
        ],
    ]

    /// Per-role preferred lane ordering. The first lane the router
    /// finds that is both enabled AND can serve the request wins.
    /// Apple Intelligence is present in every chain even though its
    /// capability surface is initially narrow — this is the honest
    /// "lane exists" signal the acceptance criterion mandates.
    nonisolated public static func defaultPreferredLanes(for role: RuntimeRole) -> [RuntimeLane] {
        switch role {
        case .code:
            return [.mlx, .gguf, .cloud(provider: "claude"), .cloud(provider: "openai"), .appleIntelligence, .stub]
        case .reasoning:
            return [.mlx, .gguf, .cloud(provider: "claude"), .cloud(provider: "openai"), .appleIntelligence, .stub]
        case .quick:
            return [.appleIntelligence, .mlx, .gguf, .cloud(provider: "claude"), .stub]
        case .toolCaller:
            return [.mlx, .cloud(provider: "claude"), .cloud(provider: "openai"), .gguf, .appleIntelligence, .stub]
        case .trivial:
            return [.appleIntelligence, .mlx, .gguf, .stub]
        case .vision:
            return [.mlx, .cloud(provider: "claude"), .cloud(provider: "openai"), .appleIntelligence, .stub]
        }
    }

    nonisolated private static func defaultLocalPolicy(for role: RuntimeRole) -> LocalPolicy {
        LocalPolicy(
            role: role,
            minimumConfidence: 0.60,
            maximumComplexity: 0.50,
            maximumToolCount: 2,
            minimumContextWindow: 4_000,
            allowsVisionFallthrough: false,
            idleUnloadDelaySeconds: 30,
            idleUnloadMode: "deep"
        )
    }

    nonisolated private static func displayName(forModelID modelID: String) -> String {
        if let lastSegment = modelID.split(separator: "/").last {
            return String(lastSegment)
        }
        return modelID
    }

    nonisolated static func agentCapabilityBadgeData(
        forLocalModelID modelID: String
    ) -> RuntimeAgentCapabilityBadgeData {
        let model = LocalTextModelID(rawValue: modelID)
        let lane = localLane(for: model)
        let laneCapability = defaultStubCapability(for: lane)
        let grammar = LocalToolGrammar.nativeGrammar(forModelID: modelID)
        let witness = "RuntimeRouter \(lane.stableID) lane capability + LocalTextModelID witness"

        guard laneCapability.toolCallMode != .none else {
            return RuntimeAgentCapabilityBadgeData(
                state: .off,
                lane: lane,
                nativeGrammar: grammar,
                toolCallMode: .none,
                witness: witness,
                falsifier: "F-LocalToolUse unavailable",
                reason: "Lane does not expose a local tool-call path."
            )
        }

        let laneHonorsGrammar = laneCapability.grammarSupport.contains(grammar.rawValue)
            || laneCapability.toolCallMode == .softGuidance

        if model?.canActAsAgent == true, laneHonorsGrammar {
            return RuntimeAgentCapabilityBadgeData(
                state: .honest,
                lane: lane,
                nativeGrammar: grammar,
                toolCallMode: laneCapability.toolCallMode,
                witness: witness,
                falsifier: "F-LocalToolUse",
                reason: "Model and lane have a witnessed local tool path."
            )
        }

        if model?.supportsNativeToolCalling == true || grammar != .canonicalXML {
            return RuntimeAgentCapabilityBadgeData(
                state: .experimental,
                lane: lane,
                nativeGrammar: grammar,
                toolCallMode: .softGuidance,
                witness: witness,
                falsifier: "F-LocalToolUse pending",
                reason: "Model has tool-use signals, but no named local falsifier witness yet."
            )
        }

        return RuntimeAgentCapabilityBadgeData(
            state: .off,
            lane: lane,
            nativeGrammar: grammar,
            toolCallMode: .none,
            witness: witness,
            falsifier: "F-LocalToolUse absent",
            reason: "No model witness or experimental grammar support is present."
        )
    }

    nonisolated private static func localLane(for model: LocalTextModelID?) -> RuntimeLane {
        switch model?.runtimeKind {
        case .some(.gguf):
            return .gguf
        case .some(.mlx), .some(.remote), .none:
            return .mlx
        }
    }

    // MARK: - route(_:) — multi-lane decision

    /// Resolve a verdict for the request by walking the preferred
    /// lane chain. The first `.accept` wins. Every disabled or
    /// incapable lane along the way produces an `.escalate` entry
    /// recorded in `metrics` and `escalationLog` — never a silent
    /// fallback.
    @discardableResult
    public func route(_ packet: MissionPacket) -> RouteVerdict {
        let preferredChain: [RuntimeLane] = {
            if let preferred = packet.preferredLane {
                var chain = [preferred]
                for lane in Self.defaultPreferredLanes(for: packet.role) where lane != preferred {
                    chain.append(lane)
                }
                return chain
            }
            return Self.defaultPreferredLanes(for: packet.role)
        }()

        guard !preferredChain.isEmpty else {
            return recordReject(role: packet.role, reason: .noLaneAvailable)
        }

        // Privacy-sensitive requests must not escalate to a networked
        // (cloud) lane. If every executable local lane is disabled,
        // reject honestly; `.stub` is in-process but cannot execute.
        if packet.privacySensitive {
            let hasEnabledExecutableLocalLane = preferredChain.contains { lane in
                lane.isLocal && lane != .stub && isLaneEnabled(lane)
            }
            if !hasEnabledExecutableLocalLane {
                return recordReject(role: packet.role, reason: .privacySensitiveNoLocal)
            }
        }

        for lane in preferredChain {
            if packet.privacySensitive && !lane.isLocal {
                let escalation = RouteVerdict.escalate(
                    from: lane,
                    to: nextLane(after: lane, in: preferredChain) ?? lane,
                    reason: .privacyPolicyMismatch
                )
                recordEscalation(escalation, role: packet.role)
                continue
            }

            if !isLaneEnabled(lane) {
                let escalation = RouteVerdict.escalate(
                    from: lane,
                    to: nextLane(after: lane, in: preferredChain) ?? lane,
                    reason: .laneDisabled
                )
                recordEscalation(escalation, role: packet.role)
                continue
            }

            if let policyReason = localPolicyEscalationReason(for: packet, lane: lane) {
                let escalation = RouteVerdict.escalate(
                    from: lane,
                    to: nextLane(after: lane, in: preferredChain) ?? lane,
                    reason: policyReason
                )
                recordEscalation(escalation, role: packet.role)
                continue
            }

            if let executor = lanes[lane] {
                let verdict = executor.canHandle(packet)
                switch verdict {
                case .accept:
                    recordAccept(verdict, role: packet.role)
                    return verdict
                case .escalate(let from, _, let reason):
                    let bumped = RouteVerdict.escalate(
                        from: from,
                        to: nextLane(after: from, in: preferredChain) ?? from,
                        reason: reason
                    )
                    recordEscalation(bumped, role: packet.role)
                    continue
                case .reject(let reason):
                    return recordReject(role: packet.role, reason: reason)
                }
            } else {
                // No executor registered for the lane — escalate
                // (honest "lane absent" rather than silent skip).
                let escalation = RouteVerdict.escalate(
                    from: lane,
                    to: nextLane(after: lane, in: preferredChain) ?? lane,
                    reason: .capabilityMissing
                )
                recordEscalation(escalation, role: packet.role)
                continue
            }
        }

        // No lane along the preferred chain accepted. Reject honestly.
        let allDisabled = preferredChain.allSatisfy { !isLaneEnabled($0) }
        let reason: RouteVerdict.RejectReason = allDisabled ? .allLanesDisabled : .noLaneAvailable
        return recordReject(role: packet.role, reason: reason)
    }

    // MARK: - Metrics recording

    @discardableResult
    private func recordAccept(_ verdict: RouteVerdict, role: RuntimeRole) -> RouteVerdict {
        guard case .accept(let lane, _) = verdict else { return verdict }
        var snapshot = metrics
        snapshot.record(.init(role: role, lane: lane, kind: .accept))
        metrics = snapshot
        return verdict
    }

    @discardableResult
    private func recordEscalation(_ verdict: RouteVerdict, role: RuntimeRole) -> RouteVerdict {
        guard case .escalate(let from, let to, let reason) = verdict else { return verdict }
        var snapshot = metrics
        snapshot.record(.init(role: role, lane: from, kind: .escalate, detail: reason.rawValue))
        metrics = snapshot
        let entry = "[\(Date().formatted(.iso8601))] role=\(role.rawValue) from=\(from.stableID) to=\(to.stableID) reason=\(reason.rawValue)"
        escalationLog.append(entry)
        if escalationLog.count > 500 {
            escalationLog.removeFirst(escalationLog.count - 500)
        }
        Self.log.info("RuntimeRouter escalation \(role.rawValue) from=\(from.stableID) to=\(to.stableID) reason=\(reason.rawValue)")
        return verdict
    }

    @discardableResult
    private func recordReject(role: RuntimeRole, reason: RouteVerdict.RejectReason) -> RouteVerdict {
        let verdict = RouteVerdict.reject(reason: reason)
        var snapshot = metrics
        // A reject is keyed under .stub so the chip strip can group
        // "no lane" verdicts without polluting any real lane's tally.
        snapshot.record(.init(role: role, lane: .stub, kind: .reject, detail: reason.rawValue))
        metrics = snapshot
        Self.log.error("RuntimeRouter reject role=\(role.rawValue) reason=\(reason.rawValue)")
        return verdict
    }

    private func localPolicyEscalationReason(
        for packet: MissionPacket,
        lane: RuntimeLane
    ) -> RouteVerdict.EscalationReason? {
        switch lane {
        case .mlx, .gguf:
            break
        case .appleIntelligence, .cloud(_), .stub:
            return nil
        }

        let policy = Self.localPolicyTable[packet.role] ?? Self.defaultLocalPolicy(for: packet.role)

        if let classificationConfidence = packet.classificationConfidence,
           !classificationConfidence.isFinite || classificationConfidence < policy.minimumConfidence {
            return .classificationUncertain
        }

        if let estimatedComplexity = packet.estimatedComplexity,
           !estimatedComplexity.isFinite || estimatedComplexity > policy.maximumComplexity {
            return .taskTooComplex
        }

        if let toolCountEstimate = packet.toolCountEstimate,
           toolCountEstimate > policy.maximumToolCount {
            return .tooManyToolCalls
        }

        return nil
    }

    private func nextLane(after lane: RuntimeLane, in chain: [RuntimeLane]) -> RuntimeLane? {
        guard let idx = chain.firstIndex(of: lane), idx + 1 < chain.count else { return nil }
        return chain[idx + 1]
    }

    // MARK: - Test seam

    /// Reset the metrics ring + escalation log. Test-only — the
    /// production surface should not call this; metrics are intended
    /// to last the session lifetime.
    public func _testResetMetrics() {
        metrics = RuntimeRouterMetrics()
        escalationLog.removeAll()
    }

    /// Default stub-lane registration used by the singleton. Every
    /// known lane gets a `StubRuntimeExecutor` so routing always has
    /// something to call into during boot — production code swaps
    /// the stubs out once the real executors are ready. The stubs
    /// honor the request only when the lane's capability surface
    /// matches; otherwise they emit `.escalate(...)` so the chain
    /// keeps moving.
    public static func defaultStubLanes() -> [any RuntimeExecutor] {
        RuntimeLane.knownLanes.map { lane in
            StubRuntimeExecutor(lane: lane, capability: defaultStubCapability(for: lane))
        }
    }

    nonisolated public static func defaultStubCapability(for lane: RuntimeLane) -> RuntimeCapability {
        switch lane {
        case .mlx:
            return RuntimeCapability(
                tier: .currentApp,
                contextWindow: 32_000,
                grammarSupport: ["qwen_xml", "hermes_json", "canonical_xml"],
                vision: false,
                costClass: .free,
                latencyClass: .local,
                toolCallMode: .native
            )
        case .gguf:
            return RuntimeCapability(
                tier: .currentApp,
                contextWindow: 16_000,
                grammarSupport: ["canonical_xml", "hermes_json"],
                vision: false,
                costClass: .free,
                latencyClass: .local,
                toolCallMode: .softGuidance
            )
        case .appleIntelligence:
            return RuntimeCapability(
                tier: .currentApp,
                contextWindow: 4_096,
                grammarSupport: [],
                vision: false,
                costClass: .free,
                latencyClass: .local,
                toolCallMode: .none
            )
        case .cloud(let provider):
            let supportsGrammar: Set<String> = provider == "claude" || provider == "openai"
                ? ["canonical_xml", "hermes_json", "qwen_xml"]
                : ["canonical_xml"]
            return RuntimeCapability(
                tier: .capabilityCeiling,
                contextWindow: 200_000,
                grammarSupport: supportsGrammar,
                vision: provider == "claude" || provider == "openai" || provider == "gemini",
                costClass: .premium,
                latencyClass: .networked,
                toolCallMode: .native
            )
        case .stub:
            return RuntimeCapability(
                tier: .currentApp,
                contextWindow: 0,
                grammarSupport: [],
                vision: false,
                costClass: .free,
                latencyClass: .local,
                toolCallMode: .none
            )
        }
    }
}

// MARK: - RuntimeLane local helper

nonisolated extension RuntimeLane {
    /// MLX, GGUF, Apple Intelligence, and stub run in-process. Cloud
    /// lanes go over the wire.
    public var isLocal: Bool {
        switch self {
        case .mlx, .gguf, .appleIntelligence, .stub:
            return true
        case .cloud:
            return false
        }
    }
}

// MARK: - StubRuntimeExecutor

/// Lightweight executor used as the default registration for every
/// `RuntimeLane.knownLanes` entry. The stub honors `canHandle` based
/// purely on the capability surface comparison — `execute(_:)` is
/// **never called in production**; real lanes replace stubs at boot.
/// The stub is what F-LocalToolUse and the router unit tests bind to.
nonisolated public struct StubRuntimeExecutor: RuntimeExecutor {
    public let id: RuntimeLane
    public let capability: RuntimeCapability

    public init(lane: RuntimeLane, capability: RuntimeCapability) {
        self.id = lane
        self.capability = capability
    }

    public func canHandle(_ request: MissionPacket) -> RouteVerdict {
        // The stub knows nothing about model weights or context
        // length beyond what its capability surface advertises.
        if request.requiresVision && !capability.vision {
            return .escalate(from: id, to: id, reason: .visionUnsupported)
        }
        if let estimatedInputTokens = request.estimatedInputTokens,
           estimatedInputTokens > 0,
           capability.contextWindow > 0,
           estimatedInputTokens > capability.contextWindow {
            return .escalate(from: id, to: id, reason: .contextWindowExceeded)
        }
        if request.requiresGrammar && capability.toolCallMode == .none {
            return .escalate(from: id, to: id, reason: .toolCallGrammarUnsupported)
        }
        if request.requiresTools && capability.toolCallMode == .none {
            return .escalate(from: id, to: id, reason: .toolCallGrammarUnsupported)
        }
        if request.residencyCeiling == .capabilityCeiling && capability.tier == .currentApp {
            // CurrentApp lane cannot serve a capability-ceiling request.
            return .escalate(from: id, to: id, reason: .residencyTierExceeded)
        }
        // Stub lane (the literal `.stub` case) intentionally refuses
        // everything — it is the "no real executor present" marker.
        if id == .stub {
            return .escalate(from: id, to: id, reason: .capabilityMissing)
        }
        return .accept(lane: id, capability: capability)
    }

    public func execute(_ request: MissionPacket) async throws -> RuntimeAnswerPacket {
        throw RuntimeExecutorError(
            lane: id,
            message: "StubRuntimeExecutor cannot execute — production lane must register before dispatch"
        )
    }

    public func teardown() async {
        // No-op. The stub holds no resources.
    }
}
