import Foundation
import os

// MARK: - RuntimeRouter

/// Pure routing policy for the MAS-safe runtime substrate. The router makes
/// cloud-first/local-second capability decisions visible as RouteVerdict
/// witnesses; it does not execute model bytes or provide a hidden fallback.
public final class RuntimeRouter: @unchecked Sendable {
    public static let shared = RuntimeRouter()
    public static let laneEnabledDefaultsKeyPrefix = "epistemos.runtimeRouter.lane.enabled."

    private static let log = Logger(subsystem: "com.epistemos.app", category: "RuntimeRouter")

    #if EPISTEMOS_APP_STORE || MAS_SANDBOX
    nonisolated public static let modelPreferenceTable: [String: [RuntimeLane]] = [
        "june.cloud-first.agent": [
            .cloud(provider: "openai"),
            .cloud(provider: "claude"),
            .appleIntelligence,
            .gguf,
            .stub,
        ],
        "june.cloud-first.reasoning": [
            .cloud(provider: "claude"),
            .cloud(provider: "openai"),
            .appleIntelligence,
            .gguf,
            .stub,
        ],
        "june.cloud-first.quick": [
            .cloud(provider: "openai"),
            .cloud(provider: "claude"),
            .appleIntelligence,
            .gguf,
            .stub,
        ],
        "june.cloud-first.vision": [
            .cloud(provider: "openai"),
            .cloud(provider: "claude"),
            .stub,
        ],
    ]
    #else
    nonisolated public static let modelPreferenceTable: [String: [RuntimeLane]] = [
        "june.cloud-first.agent": [
            .cloud(provider: "openai"),
            .cloud(provider: "claude"),
            .appleIntelligence,
            .gguf,
            .stub,
        ],
        "june.cloud-first.reasoning": [
            .cloud(provider: "claude"),
            .cloud(provider: "openai"),
            .appleIntelligence,
            .gguf,
            .stub,
        ],
        "june.cloud-first.quick": [
            .cloud(provider: "openai"),
            .cloud(provider: "claude"),
            .appleIntelligence,
            .gguf,
            .stub,
        ],
        "june.cloud-first.vision": [
            .cloud(provider: "openai"),
            .cloud(provider: "claude"),
            .stub,
        ],
    ]
    #endif

    nonisolated public static let localPolicyTable: [RuntimeRole: RoutePolicy] = [
        .code: .init(minimumConfidence: 0.74, maximumComplexity: 0.54, maximumToolCount: 0, minimumContextWindow: 16_384),
        .reasoning: .init(minimumConfidence: 0.78, maximumComplexity: 0.50, maximumToolCount: 0, minimumContextWindow: 16_384),
        .quick: .init(minimumConfidence: 0.62, maximumComplexity: 0.42, maximumToolCount: 0, minimumContextWindow: 8_192),
        .toolCaller: .init(minimumConfidence: 0.92, maximumComplexity: 0.18, maximumToolCount: 0, minimumContextWindow: 16_384),
        .trivial: .init(minimumConfidence: 0.55, maximumComplexity: 0.24, maximumToolCount: 0, minimumContextWindow: 4_096),
        .vision: .init(minimumConfidence: 0.86, maximumComplexity: 0.30, maximumToolCount: 0, minimumContextWindow: 16_384),
    ]

    private let metricsLock = NSLock()
    private var snapshot = RuntimeRouterMetricsSnapshot()
    private var laneEnabledOverrides: [RuntimeLane: Bool] = [:]

    public init() {
        for lane in RuntimeLane.knownLanes {
            let key = Self.laneEnabledDefaultsKeyPrefix + lane.stableID
            if let enabled = UserDefaults.standard.object(forKey: key) as? Bool {
                laneEnabledOverrides[lane] = enabled
            }
        }
    }

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
        let lanes = Self.defaultExecutors

        if let rejectReason = invalidPolicyRejectReason(for: packet) {
            return recordReject(role: packet.role, reason: rejectReason)
        }

        if packet.privacySensitive {
            let hasEnabledLocalLane = preferredChain.contains { lane in
                lane.isLocal && lane != .stub && isLaneEnabled(lane)
            }
            if !hasEnabledLocalLane {
                return recordReject(role: packet.role, reason: .privacySensitiveNoLocal)
            }
        }

        for lane in preferredChain {
            if !isLaneEnabled(lane) {
                let verdict = RouteVerdict.escalate(from: lane, to: lane, reason: .laneDisabled)
                recordEscalation(verdict, role: packet.role)
                continue
            }

            if packet.privacySensitive && !lane.isLocal {
                let verdict = RouteVerdict.escalate(from: lane, to: lane, reason: .privacyPolicyMismatch)
                recordEscalation(verdict, role: packet.role)
                continue
            }

            if let policyReason = localPolicyEscalationReason(for: packet, lane: lane) {
                let verdict = RouteVerdict.escalate(from: lane, to: lane, reason: policyReason)
                recordEscalation(verdict, role: packet.role)
                continue
            }

            if let executor = lanes[lane] {
                let verdict = executor.canHandle(packet)
                switch verdict {
                case .accept:
                    return recordAccept(verdict, role: packet.role)
                case .escalate:
                    recordEscalation(verdict, role: packet.role)
                case .reject(let reason):
                    return recordReject(role: packet.role, reason: reason)
                }
            } else {
                let verdict = RouteVerdict.escalate(from: lane, to: lane, reason: .capabilityMissing)
                recordEscalation(verdict, role: packet.role)
            }
        }

        let allDisabled = preferredChain.allSatisfy { !isLaneEnabled($0) }
        let reason: RouteVerdict.RejectReason = allDisabled ? .allLanesDisabled : .noLaneAvailable
        return recordReject(role: packet.role, reason: reason)
    }

    public func isLaneEnabled(_ lane: RuntimeLane) -> Bool {
        if let override = laneEnabledOverrides[lane] {
            return override
        }
        return lane != .stub
    }

    public func setLaneEnabled(_ lane: RuntimeLane, _ enabled: Bool) {
        laneEnabledOverrides[lane] = enabled
        let key = Self.laneEnabledDefaultsKeyPrefix + lane.stableID
        UserDefaults.standard.set(enabled, forKey: key)
    }

    public func metricsSnapshot() -> RuntimeRouterMetricsSnapshot {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        return snapshot
    }

    nonisolated public static func defaultRouteProfiles() -> [RouteProfile] {
        RuntimeRole.allCases.map { role in
            let policy = localPolicyTable[role] ?? defaultLocalPolicy(for: role)
            return RouteProfile(
                id: role.rawValue,
                role: role,
                preferredLanes: defaultPreferredLanes(for: role),
                minimumConfidence: policy.minimumConfidence,
                maximumComplexity: policy.maximumComplexity,
                maximumToolCount: policy.maximumToolCount,
                minimumContextWindow: policy.minimumContextWindow
            )
        }
    }

    nonisolated private static var openAIFirstFallbackLanes: [RuntimeLane] {
        var lanes: [RuntimeLane] = [
            .cloud(provider: "openai"),
            .cloud(provider: "claude"),
            .appleIntelligence,
        ]
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        lanes.append(.gguf)
        #endif
        lanes.append(.stub)
        return lanes
    }

    nonisolated private static var claudeFirstFallbackLanes: [RuntimeLane] {
        var lanes: [RuntimeLane] = [
            .cloud(provider: "claude"),
            .cloud(provider: "openai"),
            .appleIntelligence,
        ]
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        lanes.append(.gguf)
        #endif
        lanes.append(.stub)
        return lanes
    }

    nonisolated public static func defaultPreferredLanes(for role: RuntimeRole) -> [RuntimeLane] {
        switch role {
        case .code:
            return Self.modelPreferenceTable["june.cloud-first.agent"] ?? Self.openAIFirstFallbackLanes
        case .reasoning:
            return Self.modelPreferenceTable["june.cloud-first.reasoning"] ?? Self.claudeFirstFallbackLanes
        case .quick:
            return Self.modelPreferenceTable["june.cloud-first.quick"] ?? Self.openAIFirstFallbackLanes
        case .toolCaller:
            return Self.modelPreferenceTable["june.cloud-first.agent"] ?? Self.openAIFirstFallbackLanes
        case .trivial:
            return Self.modelPreferenceTable["june.cloud-first.quick"] ?? Self.openAIFirstFallbackLanes
        case .vision:
            return Self.modelPreferenceTable["june.cloud-first.vision"] ?? [.cloud(provider: "openai"), .cloud(provider: "claude"), .stub]
        }
    }

    nonisolated private static func defaultLocalPolicy(for role: RuntimeRole) -> RoutePolicy {
        switch role {
        case .code:
            return .init(minimumConfidence: 0.74, maximumComplexity: 0.54, maximumToolCount: 0, minimumContextWindow: 16_384)
        case .reasoning:
            return .init(minimumConfidence: 0.78, maximumComplexity: 0.50, maximumToolCount: 0, minimumContextWindow: 16_384)
        case .quick:
            return .init(minimumConfidence: 0.62, maximumComplexity: 0.42, maximumToolCount: 0, minimumContextWindow: 8_192)
        case .toolCaller:
            return .init(minimumConfidence: 0.92, maximumComplexity: 0.18, maximumToolCount: 0, minimumContextWindow: 16_384)
        case .trivial:
            return .init(minimumConfidence: 0.55, maximumComplexity: 0.24, maximumToolCount: 0, minimumContextWindow: 4_096)
        case .vision:
            return .init(minimumConfidence: 0.86, maximumComplexity: 0.30, maximumToolCount: 0, minimumContextWindow: 16_384)
        }
    }

    private func invalidPolicyRejectReason(for packet: MissionPacket) -> RouteVerdict.RejectReason? {
        if let classificationConfidence = packet.classificationConfidence,
           !Self.isUnitInterval(classificationConfidence) {
            return .invalidPolicyInput
        }
        if let estimatedComplexity = packet.estimatedComplexity,
           !Self.isUnitInterval(estimatedComplexity) {
            return .invalidPolicyInput
        }
        if let toolCountEstimate = packet.toolCountEstimate,
           toolCountEstimate < 0 {
            return .invalidPolicyInput
        }
        if let estimatedInputTokens = packet.estimatedInputTokens,
           estimatedInputTokens < 0 {
            return .invalidPolicyInput
        }
        return nil
    }

    nonisolated private static func isUnitInterval(_ value: Double) -> Bool {
        value.isFinite && value >= 0 && value <= 1
    }

    private func localPolicyEscalationReason(
        for packet: MissionPacket,
        lane: RuntimeLane
    ) -> RouteVerdict.EscalationReason? {
        guard lane.isLocal, lane != .stub else { return nil }
        let policy = Self.localPolicyTable[packet.role] ?? Self.defaultLocalPolicy(for: packet.role)
        let laneContextWindow = Self.defaultCapability(for: lane)?.contextWindow ?? 0

        if laneContextWindow < policy.minimumContextWindow {
            return .contextWindowExceeded
        }
        if let classificationConfidence = packet.classificationConfidence,
           classificationConfidence < policy.minimumConfidence {
            return .classificationUncertain
        }
        if let estimatedComplexity = packet.estimatedComplexity,
           estimatedComplexity > policy.maximumComplexity {
            return .taskTooComplex
        }
        if let toolCountEstimate = packet.toolCountEstimate,
           toolCountEstimate > policy.maximumToolCount {
            return .tooManyToolCalls
        }
        return nil
    }

    // MARK: - Metrics recording

    private func recordAccept(_ verdict: RouteVerdict, role: RuntimeRole) -> RouteVerdict {
        if case .accept(let lane, _) = verdict {
            metricsLock.lock()
            snapshot.record(.init(role: role, lane: lane, kind: .accept, detail: "accepted"))
            metricsLock.unlock()
        }
        return verdict
    }

    private func recordEscalation(_ verdict: RouteVerdict, role: RuntimeRole) {
        if case .escalate(let from, _, let reason) = verdict {
            metricsLock.lock()
            snapshot.record(.init(role: role, lane: from, kind: .escalate, detail: reason.rawValue))
            metricsLock.unlock()
        }
    }

    private func recordReject(role: RuntimeRole, reason: RouteVerdict.RejectReason) -> RouteVerdict {
        metricsLock.lock()
        snapshot.record(.init(role: role, lane: .stub, kind: .reject, detail: reason.rawValue))
        metricsLock.unlock()
        Self.log.error("RuntimeRouter reject role=\(role.rawValue) reason=\(reason.rawValue)")
        return .reject(reason: reason)
    }
}

// MARK: - Route policy/profile

nonisolated public struct RoutePolicy: Sendable, Equatable, Hashable, Codable {
    public let minimumConfidence: Double
    public let maximumComplexity: Double
    public let maximumToolCount: Int
    public let minimumContextWindow: Int

    public init(
        minimumConfidence: Double,
        maximumComplexity: Double,
        maximumToolCount: Int,
        minimumContextWindow: Int
    ) {
        self.minimumConfidence = minimumConfidence
        self.maximumComplexity = maximumComplexity
        self.maximumToolCount = maximumToolCount
        self.minimumContextWindow = minimumContextWindow
    }
}

nonisolated public struct RouteProfile: Sendable, Identifiable, Equatable, Hashable, Codable {
    public let id: String
    public let role: RuntimeRole
    public let preferredLanes: [RuntimeLane]
    public let minimumConfidence: Double
    public let maximumComplexity: Double
    public let maximumToolCount: Int
    public let minimumContextWindow: Int

    public init(
        id: String,
        role: RuntimeRole,
        preferredLanes: [RuntimeLane],
        minimumConfidence: Double,
        maximumComplexity: Double,
        maximumToolCount: Int,
        minimumContextWindow: Int
    ) {
        self.id = id
        self.role = role
        self.preferredLanes = preferredLanes
        self.minimumConfidence = minimumConfidence
        self.maximumComplexity = maximumComplexity
        self.maximumToolCount = maximumToolCount
        self.minimumContextWindow = minimumContextWindow
    }
}

// MARK: - Metrics

public struct RuntimeRouterMetricsSnapshot: Sendable, Equatable, Codable {
    public private(set) var records: [RuntimeRouterRouteRecord] = []

    public init(records: [RuntimeRouterRouteRecord] = []) {
        self.records = records
    }

    public mutating func record(_ record: RuntimeRouterRouteRecord) {
        records.append(record)
        if records.count > 256 {
            records.removeFirst(records.count - 256)
        }
    }
}

public struct RuntimeRouterRouteRecord: Sendable, Equatable, Codable {
    public enum Kind: String, Sendable, Codable {
        case accept
        case escalate
        case reject
    }

    public let role: RuntimeRole
    public let lane: RuntimeLane
    public let kind: Kind
    public let detail: String

    public init(role: RuntimeRole, lane: RuntimeLane, kind: Kind, detail: String) {
        self.role = role
        self.lane = lane
        self.kind = kind
        self.detail = detail
    }
}

// MARK: - Capability table

private struct StubRuntimeExecutor: RuntimeExecutor {
    let id: RuntimeLane
    let capability: RuntimeCapability

    func canHandle(_ request: MissionPacket) -> RouteVerdict {
        if request.residencyCeiling == .capabilityCeiling && capability.tier == .currentApp {
            return .escalate(from: id, to: id, reason: .residencyTierExceeded)
        }
        if let estimatedInputTokens = request.estimatedInputTokens,
           estimatedInputTokens > capability.contextWindow {
            return .escalate(from: id, to: id, reason: .contextWindowExceeded)
        }
        if request.requiresGrammar && capability.toolCallMode == .none {
            return .escalate(from: id, to: id, reason: .toolCallGrammarUnsupported)
        }
        if request.requiresTools && capability.toolCallMode == .none {
            return .escalate(from: id, to: id, reason: .toolCallGrammarUnsupported)
        }
        if request.requiresVision && !capability.vision {
            return .escalate(from: id, to: id, reason: .visionUnsupported)
        }
        return .accept(lane: id, capability: capability)
    }

    func execute(_ request: MissionPacket) async throws -> RuntimeAnswerPacket {
        throw RuntimeExecutorError(lane: id, message: "RuntimeRouter witness lanes do not execute model requests.")
    }

    func teardown() async {}
}

private extension RuntimeRouter {
    nonisolated static var defaultExecutors: [RuntimeLane: any RuntimeExecutor] {
        Dictionary(
            uniqueKeysWithValues: RuntimeLane.knownLanes.compactMap { lane in
                guard let capability = defaultCapability(for: lane) else { return nil }
                return (lane, StubRuntimeExecutor(id: lane, capability: capability))
            }
        )
    }

    nonisolated static func defaultCapability(for lane: RuntimeLane) -> RuntimeCapability? {
        switch lane {
        case .cloud(let provider):
            let agenticCloud = provider == "openai" || provider == "claude"
            return RuntimeCapability(
                tier: agenticCloud ? .capabilityCeiling : .verifiedFloor,
                contextWindow: 200_000,
                grammarSupport: agenticCloud ? ["provider_native_tools"] : [],
                vision: agenticCloud || provider == "gemini",
                costClass: .standard,
                latencyClass: .networked,
                toolCallMode: agenticCloud ? .native : .none
            )
        case .appleIntelligence:
            return RuntimeCapability(
                tier: .currentApp,
                contextWindow: 32_768,
                grammarSupport: [],
                vision: false,
                costClass: .free,
                latencyClass: .local,
                toolCallMode: .none
            )
        case .gguf:
            return RuntimeCapability(
                tier: .currentApp,
                contextWindow: 4_096,
                grammarSupport: [],
                vision: false,
                costClass: .free,
                latencyClass: .local,
                toolCallMode: .none
            )
        case .stub:
            return nil
        }
    }
}

public extension RuntimeLane {
    var isLocal: Bool {
        switch self {
        case .appleIntelligence, .gguf, .stub:
            return true
        case .cloud:
            return false
        }
    }
}
