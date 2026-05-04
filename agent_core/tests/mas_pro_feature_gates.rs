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
