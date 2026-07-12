//! Source guard for RuntimeRouter policy-gate ordering.
//!
//! The route policy row is only meaningful if caller hints and executor
//! capabilities cannot bypass policy validation. This stays source-only so the
//! unattended loop avoids full Xcode runs.

const RUNTIME_ROUTER_SOURCE: &str = include_str!("../../Epistemos/LocalAgent/RuntimeRouter.swift");

fn index_of(haystack: &str, needle: &str) -> usize {
    haystack
        .find(needle)
        .unwrap_or_else(|| panic!("RuntimeRouter source is missing `{needle}`"))
}

fn route_body() -> &'static str {
    let start = index_of(
        RUNTIME_ROUTER_SOURCE,
        "public func route(_ packet: MissionPacket)",
    );
    let end = index_of(RUNTIME_ROUTER_SOURCE, "// MARK: - Metrics recording");
    &RUNTIME_ROUTER_SOURCE[start..end]
}

fn mas_model_preference_table_body() -> &'static str {
    let start = index_of(
        RUNTIME_ROUTER_SOURCE,
        "#if EPISTEMOS_APP_STORE || MAS_SANDBOX\n    nonisolated public static let modelPreferenceTable",
    );
    let end = index_of(&RUNTIME_ROUTER_SOURCE[start..], "    #else");
    &RUNTIME_ROUTER_SOURCE[start..start + end]
}

#[test]
fn route_rejects_invalid_policy_inputs_before_any_lane_walk() {
    let route = route_body();
    let invalid_gate = index_of(
        route,
        "if let rejectReason = invalidPolicyRejectReason(for: packet)",
    );
    let privacy_gate = index_of(route, "if packet.privacySensitive {");
    let lane_walk = index_of(route, "for lane in preferredChain {");

    assert!(
        invalid_gate < privacy_gate,
        "Malformed policy hints must reject before privacy-local lane probing"
    );
    assert!(
        invalid_gate < lane_walk,
        "Malformed policy hints must reject before any executor lane walk"
    );
}

#[test]
fn route_applies_local_policy_before_executor_capability_acceptance() {
    let route = route_body();
    let policy_gate = index_of(
        route,
        "if let policyReason = localPolicyEscalationReason(for: packet, lane: lane)",
    );
    let executor_lookup = index_of(route, "if let executor = lanes[lane]");
    let accept_path = index_of(route, "recordAccept(verdict, role: packet.role)");

    assert!(
        policy_gate < executor_lookup,
        "RuntimeRouter must apply role policy before consulting executor capability"
    );
    assert!(
        policy_gate < accept_path,
        "RuntimeRouter must not accept a lane before the local policy gate runs"
    );
}

#[test]
fn preferred_lane_hint_only_reorders_the_governed_chain() {
    let route = route_body();
    let preferred_hint = index_of(route, "if let preferred = packet.preferredLane");
    let default_append = index_of(
        route,
        "for lane in Self.defaultPreferredLanes(for: packet.role) where lane != preferred",
    );
    let invalid_gate = index_of(route, "invalidPolicyRejectReason(for: packet)");
    let lane_walk = index_of(route, "for lane in preferredChain {");

    assert!(
        preferred_hint < default_append,
        "Preferred lane must seed, not replace, the governed lane chain"
    );
    assert!(
        default_append < invalid_gate,
        "Preferred lane chain construction must still flow into policy validation"
    );
    assert!(
        invalid_gate < lane_walk,
        "Preferred lane hints must not start executor routing before policy validation"
    );
}

#[test]
fn mas_agent_chain_keeps_agentic_cloud_before_local_chat_fallbacks() {
    let lanes = mas_model_preference_table_body();
    let agent = {
        let start = index_of(lanes, "\"june.cloud-first.agent\": [");
        let end = index_of(&lanes[start..], "\"june.cloud-first.reasoning\": [");
        &lanes[start..start + end]
    };
    let cloud_openai = index_of(agent, ".cloud(provider: \"openai\")");
    let cloud_claude = index_of(agent, ".cloud(provider: \"claude\")");
    let apple = index_of(agent, ".appleIntelligence");
    let gguf = index_of(agent, ".gguf");
    let stub = index_of(agent, ".stub");

    assert!(
        cloud_openai < apple && cloud_claude < apple,
        "MAS agent routes must try agentic cloud lanes before Apple Intelligence chat fallback"
    );
    assert!(
        apple < gguf && gguf < stub,
        "GGUF must stay after Apple Intelligence and before the internal stub reject bucket"
    );
    assert!(
        !lanes.contains(".mlx"),
        "current MAS routing must not introduce the parked local MLX lane"
    );
}
