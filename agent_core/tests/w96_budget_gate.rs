use agent_core::providers::pricing::{
    budget_gate_payload_json, estimate_usage_cost_usd, pricing_for, PRICING_LAST_VERIFIED_ISO8601,
};
use agent_core::types::TokenUsage;
use serde_json::Value;

#[test]
fn canonical_pricing_table_names_required_w96_providers() {
    assert_eq!(PRICING_LAST_VERIFIED_ISO8601, "2026-05-04");

    for provider in [
        "claude-sonnet-4-6",
        "claude-opus-4-6",
        "sonar-pro",
        "codex-mini-latest",
        "gemini-2.5-flash",
        "kimi-k2.5",
        "moonshot",
    ] {
        let pricing = pricing_for(provider).expect("provider should be priced");
        assert_eq!(pricing.last_verified_iso8601, PRICING_LAST_VERIFIED_ISO8601);
    }
}

#[test]
fn usage_estimate_applies_cache_read_and_creation_rates() {
    let usage = TokenUsage {
        input_tokens: 1_000,
        output_tokens: 500,
        cache_creation_input_tokens: 100,
        cache_read_input_tokens: 200,
    };

    let cost = estimate_usage_cost_usd("claude-sonnet-4-6", &usage);
    let expected = 0.003 + 0.0075 + 0.000375 + 0.00006;
    assert!((cost - expected).abs() < 1e-9);
}

#[test]
fn budget_gate_payload_carries_current_spend_cap_and_next_gate() {
    let payload = budget_gate_payload_json("session-1", "claude-sonnet-4-6", 0.51, 0.50, 1.00);
    let value: Value = serde_json::from_str(&payload).expect("budget gate JSON");

    assert_eq!(value["session_id"], "session-1");
    assert_eq!(value["tool_name"], "budget_gate");
    assert_eq!(value["provider"], "claude-sonnet-4-6");
    assert_eq!(value["current_spend_usd"], 0.51);
    assert_eq!(value["cap_usd"], 0.50);
    assert_eq!(value["next_gate_usd"], 1.00);
}
