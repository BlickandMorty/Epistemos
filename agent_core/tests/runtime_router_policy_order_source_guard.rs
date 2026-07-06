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

fn default_preferred_lanes_body() -> &'static str {
    let start = index_of(
        RUNTIME_ROUTER_SOURCE,
        "nonisolated public static func defaultPreferredLanes(for role: RuntimeRole) -> [RuntimeLane]",
    );
    let end = index_of(
        RUNTIME_ROUTER_SOURCE,
        "nonisolated private static func defaultLocalPolicy(for role: RuntimeRole)",
    );
    &RUNTIME_ROUTER_SOURCE[start..end]
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
fn tool_caller_chain_keeps_agentic_cloud_before_local_chat_fallback() {
    let lanes = default_preferred_lanes_body();
    let tool_caller = {
        let start = index_of(lanes, "case .toolCaller:");
        let end = index_of(&lanes[start..], "case .trivial:");
        &lanes[start..start + end]
    };
    let cloud_openai = index_of(tool_caller, ".cloud(provider: \"openai\")");
    let cloud_claude = index_of(tool_caller, ".cloud(provider: \"claude\")");
    let apple = index_of(tool_caller, ".appleIntelligence");
    let gguf = index_of(tool_caller, ".gguf");
    let stub = index_of(tool_caller, ".stub");

    assert!(
        cloud_openai < apple && cloud_claude < apple && cloud_openai < gguf && cloud_claude < gguf,
        "tool-caller routes must try agentic cloud lanes before local chat fallback"
    );
    assert!(
        apple < gguf && gguf < stub,
        "local chat fallbacks must stay ordered before the internal stub reject bucket"
    );
    assert!(
        !tool_caller.contains(".mlx"),
        "current MAS routing must not reintroduce local MLX tool lanes without an admitted deterministic grammar lane"
    );
}
