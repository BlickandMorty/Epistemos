#[test]
fn rust_feature_gates_use_pro_build_not_legacy_mas_sandbox() {
    let sources = [
        include_str!("../src/lib.rs"),
        include_str!("../src/agent_loop.rs"),
        include_str!("../src/approval.rs"),
        include_str!("../src/bridge.rs"),
        include_str!("../src/routing.rs"),
        include_str!("../src/security.rs"),
        include_str!("../src/session.rs"),
        include_str!("../src/tools/registry.rs"),
    ];

    let joined = sources.join("\n");

    assert!(
        !joined.contains("feature = \"mas-sandbox\""),
        "MAS/Pro Rust gates must use canonical mas-build/pro-build features, not legacy mas-sandbox"
    );
    assert!(
        joined.contains("feature = \"pro-build\""),
        "Pro-only Rust surfaces must be explicitly gated by pro-build"
    );
}

#[test]
fn xcode_agent_core_build_script_uses_canonical_mas_pro_features() {
    let script = include_str!("../../build-agent-core.sh");

    assert!(
        !script.contains("mas-sandbox"),
        "build-agent-core.sh must not compile the legacy mas-sandbox alias"
    );
    assert!(
        script.contains("mas-build"),
        "App Store agent_core builds must name the canonical mas-build feature"
    );
    assert!(
        script.contains("pro-build"),
        "direct agent_core builds must explicitly enable pro-build"
    );
    assert!(
        script.contains("--no-default-features"),
        "direct pro-build agent_core builds must disable the default MAS feature set"
    );
}

#[cfg(not(feature = "pro-build"))]
#[test]
fn mas_legacy_aliases_do_not_embed_pro_subprocess_tool_names() {
    use agent_core::tools::registry::{legacy_name_for_v2, v2_name_for_legacy};

    for name in [
        "bash_execute",
        "terminal",
        "process",
        "claude_code",
        "codex",
        "gemini",
        "kimi",
        "mcp_discover",
    ] {
        assert!(
            v2_name_for_legacy(name).is_none(),
            "MAS agent_core alias table must not embed Pro-only tool name {name}"
        );
    }

    for name in [
        "action.bash",
        "action.terminal",
        "system.process",
        "discovery.mcp_discover",
    ] {
        assert!(
            legacy_name_for_v2(name).is_none(),
            "MAS agent_core alias table must not embed Pro-only dotted tool name {name}"
        );
    }
}
