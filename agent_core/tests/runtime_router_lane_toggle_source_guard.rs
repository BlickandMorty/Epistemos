//! Source guard for RuntimeRouter lane-toggle persistence and ordering.
//!
//! This proves the settings-visible lane toggles remain part of the governed
//! route path without requiring a full Xcode test run from the unattended loop.

const RUNTIME_ROUTER_SOURCE: &str = include_str!("../../Epistemos/LocalAgent/RuntimeRouter.swift");
const RUNTIME_LANES_SECTION_SOURCE: &str =
    include_str!("../../Epistemos/Views/Settings/RuntimeLanesSection.swift");

fn index_of(haystack: &str, needle: &str) -> usize {
    haystack
        .find(needle)
        .unwrap_or_else(|| panic!("source is missing `{needle}`"))
}

fn route_body() -> &'static str {
    let start = index_of(
        RUNTIME_ROUTER_SOURCE,
        "public func route(_ packet: MissionPacket)",
    );
    let end = index_of(RUNTIME_ROUTER_SOURCE, "// MARK: - Metrics recording");
    &RUNTIME_ROUTER_SOURCE[start..end]
}

#[test]
fn router_persists_lane_toggles_under_stable_lane_keys() {
    for snippet in [
        "public static let laneEnabledDefaultsKeyPrefix",
        "for lane in RuntimeLane.knownLanes",
        "let key = Self.laneEnabledDefaultsKeyPrefix + lane.stableID",
        "UserDefaults.standard.object(forKey: key) as? Bool",
        "UserDefaults.standard.set(enabled, forKey: key)",
    ] {
        assert!(
            RUNTIME_ROUTER_SOURCE.contains(snippet),
            "RuntimeRouter lane persistence must keep snippet `{snippet}`"
        );
    }
}

#[test]
fn settings_surface_reads_and_writes_the_router_lane_state() {
    for snippet in [
        "RuntimeLanesSection.userVisibleLanes()",
        "RuntimeLane.knownLanes.filter { $0 != .stub }",
        "RuntimeRouter.shared.isLaneEnabled($0)",
        "get: { laneStates[lane.stableID] ?? router.isLaneEnabled(lane) }",
        "router.setLaneEnabled(lane, newValue)",
    ] {
        assert!(
            RUNTIME_LANES_SECTION_SOURCE.contains(snippet),
            "RuntimeLanesSection must keep router-backed lane toggle snippet `{snippet}`"
        );
    }
}

#[test]
fn route_checks_disabled_lanes_before_policy_and_executor_acceptance() {
    let route = route_body();
    let disabled_gate = index_of(route, "if !isLaneEnabled(lane)");
    let policy_gate = index_of(
        route,
        "if let policyReason = localPolicyEscalationReason(for: packet, lane: lane)",
    );
    let executor_lookup = index_of(route, "if let executor = lanes[lane]");
    let accept_path = index_of(route, "recordAccept(verdict, role: packet.role)");

    assert!(
        disabled_gate < policy_gate,
        "A disabled lane must emit laneDisabled before local policy evaluation can mask it"
    );
    assert!(
        disabled_gate < executor_lookup,
        "A disabled lane must not reach executor capability checks"
    );
    assert!(
        disabled_gate < accept_path,
        "A disabled lane must not accept before the lane toggle gate runs"
    );
}

#[test]
fn route_keeps_all_disabled_reject_after_the_governed_lane_walk() {
    let route = route_body();
    let lane_walk = index_of(route, "for lane in preferredChain {");
    let all_disabled = index_of(route, "let allDisabled = preferredChain.allSatisfy");
    let reject = index_of(
        route,
        "let reason: RouteVerdict.RejectReason = allDisabled ? .allLanesDisabled : .noLaneAvailable",
    );

    assert!(
        lane_walk < all_disabled,
        "All-disabled rejection must be computed after walking the governed chain"
    );
    assert!(
        all_disabled < reject,
        "All-disabled computation must feed the visible reject reason"
    );
}
