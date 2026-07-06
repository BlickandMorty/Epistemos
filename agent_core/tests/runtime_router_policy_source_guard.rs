//! Source guard for the Swift RuntimeRouter policy-table dispatch path.
//!
//! The architecture manifest requires `RuntimeRouter.route(_:)` to consume the
//! same per-role policy table that backs diagnostics. This guard is intentionally
//! light because the unattended loop must avoid Xcode/full-app test runs.

const RUNTIME_EXECUTOR_SOURCE: &str = include_str!("../../Epistemos/Engine/RuntimeExecutor.swift");
const CONFIDENCE_ROUTER_SOURCE: &str =
    include_str!("../../Epistemos/LocalAgent/ConfidenceRouter.swift");
const RUNTIME_ROUTER_SOURCE: &str = include_str!("../../Epistemos/LocalAgent/RuntimeRouter.swift");
const RUNTIME_LANES_SECTION_SOURCE: &str =
    include_str!("../../Epistemos/Views/Settings/RuntimeLanesSection.swift");
const INFERENCE_ROUTE_PROFILES_SOURCE: &str =
    include_str!("../../Epistemos/State/InferenceState+RouteProfiles.swift");

#[test]
fn mission_packet_carries_policy_inputs() {
    for field in [
        "public let residencyCeiling: ResidencyTier",
        "public let requiresTools: Bool",
        "public let requiresVision: Bool",
        "public let requiresGrammar: Bool",
        "public let privacySensitive: Bool",
        "public let classificationConfidence: Double?",
        "public let estimatedComplexity: Double?",
        "public let toolCountEstimate: Int?",
        "public let estimatedInputTokens: Int?",
        "public let preferredLane: RuntimeLane?",
    ] {
        assert!(
            RUNTIME_EXECUTOR_SOURCE.contains(field),
            "MissionPacket must expose policy input field `{field}`"
        );
    }
}

#[test]
fn route_verdict_exposes_policy_escalation_reasons() {
    for reason in [
        "case classificationUncertain = \"classification_uncertain\"",
        "case taskTooComplex = \"task_too_complex\"",
        "case tooManyToolCalls = \"too_many_tool_calls\"",
        "case contextWindowExceeded = \"context_window_exceeded\"",
        "case toolCallGrammarUnsupported = \"tool_call_grammar_unsupported\"",
        "case residencyTierExceeded = \"residency_tier_exceeded\"",
        "case privacyPolicyMismatch = \"privacy_policy_mismatch\"",
        "case privacySensitiveNoLocal = \"privacy_sensitive_no_local\"",
    ] {
        assert!(
            RUNTIME_EXECUTOR_SOURCE.contains(reason),
            "RouteVerdict must expose policy escalation reason `{reason}`"
        );
    }
}

#[test]
fn runtime_router_treats_preferred_lane_as_a_governed_hint() {
    for snippet in [
        "if let preferred = packet.preferredLane",
        "var chain = [preferred]",
        "for lane in Self.defaultPreferredLanes(for: packet.role) where lane != preferred",
        "chain.append(lane)",
        "return chain",
    ] {
        assert!(
            RUNTIME_ROUTER_SOURCE.contains(snippet),
            "RuntimeRouter must build a governed preferred-lane chain with `{snippet}`"
        );
    }
}

#[test]
fn runtime_router_keeps_residency_ceiling_from_current_app_lanes() {
    for snippet in [
        "request.residencyCeiling == .capabilityCeiling && capability.tier == .currentApp",
        "return .escalate(from: id, to: id, reason: .residencyTierExceeded)",
        "tier: agenticCloud ? .capabilityCeiling : .verifiedFloor",
    ] {
        assert!(
            RUNTIME_ROUTER_SOURCE.contains(snippet),
            "RuntimeRouter must preserve the residency-ceiling guard with `{snippet}`"
        );
    }
}

#[test]
fn stub_executor_gates_estimated_context_against_lane_capability() {
    for snippet in [
        "estimatedInputTokens",
        "capability.contextWindow",
        "estimatedInputTokens > capability.contextWindow",
        "return .escalate(from: id, to: id, reason: .contextWindowExceeded)",
    ] {
        assert!(
            RUNTIME_ROUTER_SOURCE.contains(snippet),
            "StubRuntimeExecutor must gate context-window routing with `{snippet}`"
        );
    }
}

#[test]
fn stub_executor_gates_tool_and_grammar_demands_against_lane_capability() {
    for snippet in [
        "if request.requiresGrammar && capability.toolCallMode == .none",
        "return .escalate(from: id, to: id, reason: .toolCallGrammarUnsupported)",
        "if request.requiresTools && capability.toolCallMode == .none",
    ] {
        assert!(
            RUNTIME_ROUTER_SOURCE.contains(snippet),
            "StubRuntimeExecutor must gate tool/grammar demands with `{snippet}`"
        );
    }
}

#[test]
fn runtime_router_gates_local_lanes_with_policy_table() {
    for snippet in [
        "private func localPolicyEscalationReason",
        "Self.localPolicyTable[packet.role]",
        "classificationConfidence",
        "policy.minimumConfidence",
        "estimatedComplexity",
        "policy.maximumComplexity",
        "toolCountEstimate",
        "policy.maximumToolCount",
        "if let policyReason = localPolicyEscalationReason(for: packet, lane: lane)",
    ] {
        assert!(
            RUNTIME_ROUTER_SOURCE.contains(snippet),
            "RuntimeRouter route path must include policy-table snippet `{snippet}`"
        );
    }
}

#[test]
fn runtime_router_consumes_policy_context_window_floor() {
    for snippet in [
        "let minimumContextWindow: Int",
        "minimumContextWindow: policy.minimumContextWindow",
        "laneContextWindow < policy.minimumContextWindow",
        "return .contextWindowExceeded",
    ] {
        assert!(
            RUNTIME_ROUTER_SOURCE.contains(snippet),
            "RuntimeRouter policy path must expose and consume minimumContextWindow snippet `{snippet}`"
        );
    }
}

#[test]
fn runtime_router_rejects_malformed_policy_hints_before_local_acceptance() {
    for snippet in [
        "case invalidPolicyInput = \"invalid_policy_input\"",
        "private func invalidPolicyRejectReason(for packet: MissionPacket) -> RouteVerdict.RejectReason?",
        "if let rejectReason = invalidPolicyRejectReason(for: packet)",
        "return recordReject(role: packet.role, reason: rejectReason)",
        "!Self.isUnitInterval(classificationConfidence)",
        "!Self.isUnitInterval(estimatedComplexity)",
        "toolCountEstimate < 0",
        "estimatedInputTokens < 0",
        "return .invalidPolicyInput",
    ] {
        assert!(
            RUNTIME_ROUTER_SOURCE.contains(snippet) || RUNTIME_EXECUTOR_SOURCE.contains(snippet),
            "RuntimeRouter must reject malformed policy hint snippet `{snippet}` before local acceptance"
        );
    }
}

#[test]
fn runtime_router_keeps_privacy_sensitive_routes_off_cloud_lanes() {
    for snippet in [
        "if packet.privacySensitive",
        "lane.isLocal && lane != .stub && isLaneEnabled(lane)",
        "return recordReject(role: packet.role, reason: .privacySensitiveNoLocal)",
        "if packet.privacySensitive && !lane.isLocal",
        "reason: .privacyPolicyMismatch",
    ] {
        assert!(
            RUNTIME_ROUTER_SOURCE.contains(snippet),
            "RuntimeRouter route path must include privacy guard snippet `{snippet}`"
        );
    }
}

#[test]
fn runtime_lane_settings_hide_internal_stub_lane() {
    for snippet in [
        "RuntimeLanesSection.userVisibleLanes()",
        "public static func userVisibleLanes() -> [RuntimeLane]",
        "RuntimeLane.knownLanes.filter { $0 != .stub }",
        "is an internal \"no real executor present\" marker",
    ] {
        assert!(
            RUNTIME_LANES_SECTION_SOURCE.contains(snippet),
            "Runtime lane settings must hide the internal stub lane with `{snippet}`"
        );
    }
    assert!(
        RUNTIME_ROUTER_SOURCE
            .contains("snapshot.record(.init(role: role, lane: .stub, kind: .reject"),
        "RuntimeRouter may still use .stub internally to group no-lane reject metrics"
    );
}

#[test]
fn diagnostics_route_profiles_delegate_to_runtime_router_table() {
    assert!(
        CONFIDENCE_ROUTER_SOURCE.contains("RuntimeRouter.defaultRouteProfiles().map"),
        "ConfidenceRouter.routeProfiles must adapt RuntimeRouter.defaultRouteProfiles instead of a placeholder table"
    );
    assert!(
        INFERENCE_ROUTE_PROFILES_SOURCE.contains("RuntimeRouter.defaultRouteProfiles()"),
        "InferenceState.routeProfiles must delegate to RuntimeRouter.defaultRouteProfiles"
    );
    assert!(
        !CONFIDENCE_ROUTER_SOURCE
            .contains("static func routeProfiles() -> [RouteProfile] {\n        []\n    }"),
        "ConfidenceRouter.routeProfiles must not regress to the old empty placeholder"
    );
}
