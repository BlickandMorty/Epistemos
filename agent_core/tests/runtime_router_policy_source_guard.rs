//! Source guard for the Swift RuntimeRouter policy-table dispatch path.
//!
//! The architecture manifest requires `RuntimeRouter.route(_:)` to consume the
//! same per-role policy table that backs diagnostics. This guard is intentionally
//! light because the unattended loop must avoid Xcode/full-app test runs.

const RUNTIME_EXECUTOR_SOURCE: &str =
    include_str!("../../Epistemos/Engine/RuntimeExecutor.swift");
const CONFIDENCE_ROUTER_SOURCE: &str =
    include_str!("../../Epistemos/LocalAgent/ConfidenceRouter.swift");
const RUNTIME_ROUTER_SOURCE: &str =
    include_str!("../../Epistemos/LocalAgent/RuntimeRouter.swift");
const RUNTIME_LANES_SECTION_SOURCE: &str =
    include_str!("../../Epistemos/Views/Settings/RuntimeLanesSection.swift");
const INFERENCE_ROUTE_PROFILES_SOURCE: &str =
    include_str!("../../Epistemos/State/InferenceState+RouteProfiles.swift");

#[test]
fn mission_packet_carries_policy_inputs() {
    for field in [
        "public let classificationConfidence: Double?",
        "public let estimatedComplexity: Double?",
        "public let toolCountEstimate: Int?",
        "public let estimatedInputTokens: Int?",
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
        RUNTIME_ROUTER_SOURCE.contains("snapshot.record(.init(role: role, lane: .stub, kind: .reject"),
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
        !CONFIDENCE_ROUTER_SOURCE.contains("static func routeProfiles() -> [RouteProfile] {\n        []\n    }"),
        "ConfidenceRouter.routeProfiles must not regress to the old empty placeholder"
    );
}
