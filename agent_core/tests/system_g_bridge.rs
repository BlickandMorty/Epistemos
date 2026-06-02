//! Integration smoke test for the Wiring #4 (T11 System G →
//! LocalAgentLoop) FFI `bridge::system_g_runtime_status_json`.
//!
//! Verifies that the JSON status shape matches the canon doctrine:
//! - The mode comes from the build's tier default (MAS = Disabled,
//!   Pro = IpcBounded).
//! - `allows_execution` mirrors the substrate's `mode.allows_execution()`.
//! - `allows_subprocess` is `false` outside Pro Research builds.
//!
//! Lives in `tests/` (separate test binary) to avoid the pre-existing
//! lib-test compile errors in unrelated modules (cache/, tools_v2/,
//! skill_discovery/) — `cargo check --lib` is clean on origin/main;
//! only `cargo test --lib` is red, pre-existing.

use agent_core::agent_runtime_v2::AgentRuntimeV2Mode;
use agent_core::bridge::system_g_runtime_status_json;

#[test]
fn system_g_runtime_status_json_returns_well_formed_status() {
    let raw = system_g_runtime_status_json().expect("FFI must not error on a snapshot read");

    let value: serde_json::Value = serde_json::from_str(&raw).expect("status JSON must decode");
    assert!(value.is_object(), "status must be a JSON object");

    let mode_str = value
        .get("mode")
        .and_then(|m| m.as_str())
        .expect("mode field must be a string");
    assert!(
        matches!(mode_str, "disabled" | "ipc_bounded" | "subprocess"),
        "mode must be one of the three canonical snake_case variants; got {mode_str}"
    );

    let allows_execution = value
        .get("allows_execution")
        .and_then(|v| v.as_bool())
        .expect("allows_execution field must be a bool");
    let allows_subprocess = value
        .get("allows_subprocess")
        .and_then(|v| v.as_bool())
        .expect("allows_subprocess field must be a bool");

    // MAS test build uses the Disabled default; allows_execution must
    // be false there. Pro test build flips to IpcBounded.
    #[cfg(not(feature = "pro-build"))]
    {
        assert_eq!(mode_str, "disabled", "MAS build must observe Disabled");
        assert!(!allows_execution, "MAS Disabled never allows execution");
        assert!(!allows_subprocess, "MAS Disabled never allows subprocess");
    }
    #[cfg(feature = "pro-build")]
    {
        assert_eq!(mode_str, "ipc_bounded", "Pro build defaults to IpcBounded");
        assert!(
            allows_execution,
            "Pro IpcBounded permits in-process execution"
        );
        assert!(
            !allows_subprocess,
            "Pro IpcBounded must not enable subprocess by default"
        );
    }

    let build_tier = value
        .get("build_tier")
        .and_then(|t| t.as_str())
        .expect("build_tier must be a string");
    #[cfg(feature = "pro-build")]
    assert_eq!(build_tier, "pro");
    #[cfg(not(feature = "pro-build"))]
    assert_eq!(build_tier, "mas");
}

#[test]
fn mas_default_is_disabled() {
    // Pin the canon's MAS default at the substrate layer so the FFI
    // contract cannot drift without a substrate change being noticed.
    assert_eq!(
        AgentRuntimeV2Mode::mas_default(),
        AgentRuntimeV2Mode::Disabled
    );
    assert!(!AgentRuntimeV2Mode::mas_default().allows_execution());
    assert!(!AgentRuntimeV2Mode::mas_default().allows_subprocess());
}
