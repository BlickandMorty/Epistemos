//! Source guard for RuntimeRouter's all-disabled-lanes rejection path.
//!
//! The runtime policy row requires lane toggles to produce visible, honest
//! routing outcomes. If every lane in a preferred chain is disabled, the router
//! must reject explicitly instead of falling through to stub or cloud behavior.

const RUNTIME_EXECUTOR_SOURCE: &str = include_str!("../../Epistemos/Engine/RuntimeExecutor.swift");
const RUNTIME_ROUTER_SOURCE: &str = include_str!("../../Epistemos/LocalAgent/RuntimeRouter.swift");

#[test]
fn route_verdict_exposes_all_lanes_disabled_reject_reason() {
    assert!(
        RUNTIME_EXECUTOR_SOURCE.contains("case allLanesDisabled = \"all_lanes_disabled\""),
        "RouteVerdict must expose an explicit all-lanes-disabled reject reason"
    );
    assert!(
        RUNTIME_EXECUTOR_SOURCE.contains("case .allLanesDisabled: return \"All lanes disabled\""),
        "RouteVerdict all-lanes-disabled rejection should stay user-readable"
    );
}

#[test]
fn runtime_router_rejects_disabled_chain_after_policy_walk() {
    for snippet in [
        "let allDisabled = preferredChain.allSatisfy { !isLaneEnabled($0) }",
        "let reason: RouteVerdict.RejectReason = allDisabled ? .allLanesDisabled : .noLaneAvailable",
        "return recordReject(role: packet.role, reason: reason)",
    ] {
        assert!(
            RUNTIME_ROUTER_SOURCE.contains(snippet),
            "RuntimeRouter must preserve disabled-chain rejection snippet `{snippet}`"
        );
    }
}

#[test]
fn runtime_router_records_reject_reason_for_visible_diagnostics() {
    for snippet in [
        "snapshot.record(.init(role: role, lane: .stub, kind: .reject, detail: reason.rawValue))",
        "Self.log.error(\"RuntimeRouter reject role=\\(role.rawValue) reason=\\(reason.rawValue)\")",
    ] {
        assert!(
            RUNTIME_ROUTER_SOURCE.contains(snippet),
            "RuntimeRouter reject path must keep diagnostic witness snippet `{snippet}`"
        );
    }
}
