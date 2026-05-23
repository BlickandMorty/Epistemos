//! Integration smoke test for the Wiring #2 (T21 Vault Recall Contract
//! -> ResourceService) FFI entry point `bridge::vault_recall_trace_json`.
//!
//! Lives in `tests/` (separate test binary) so the broken pre-existing
//! lib-test compilation (cache/, tools_v2/, skill_discovery/, ulid)
//! does not block verification of the bridge function. `cargo check
//! --lib` is clean on origin/main; only `cargo test --lib` is red on
//! main, pre-existing.

use agent_core::bridge::vault_recall_trace_json;
use agent_core::storage::retrieval_trace::{RetrievalSignal, RetrievalTrace};

#[test]
fn vault_recall_trace_json_returns_lexical_trace_for_nonempty_query() {
    let raw = vault_recall_trace_json("residency governance".to_string())
        .expect("vault_recall_trace_json should not error on a normal query");
    let trace: RetrievalTrace =
        serde_json::from_str(&raw).expect("trace JSON should decode against the T21 mirror");

    assert_eq!(trace.query, "residency governance");
    assert!(
        trace.signal_summary.contains(&RetrievalSignal::Lexical),
        "Lexical signal must be recorded for a non-empty query"
    );
    assert!(
        trace.candidates_retained > 0,
        "scaffold trace should retain >= 1 candidate; got {}",
        trace.candidates_retained
    );
    assert_eq!(trace.candidates.len(), trace.candidates_retained);
}

#[test]
fn vault_recall_trace_json_records_all_chatter_fallback_for_empty_effective() {
    // strip_query_chatter reduces this to empty, so the bridge sets the
    // all-chatter fallback flag and downstream consumers must treat the
    // result as Weak evidence.
    let raw = vault_recall_trace_json("show me my notes".to_string())
        .expect("vault_recall_trace_json should succeed on chatter-only queries");
    let trace: RetrievalTrace = serde_json::from_str(&raw).expect("trace decodes");

    assert!(
        trace.all_chatter_fallback,
        "all-chatter fallback must fire when strip_query_chatter empties the input"
    );
}

#[test]
fn vault_recall_trace_json_produces_empty_candidates_for_blank_query() {
    let raw = vault_recall_trace_json("   ".to_string()).expect("blank query is non-error");
    let trace: RetrievalTrace = serde_json::from_str(&raw).expect("trace decodes");
    assert_eq!(trace.candidates.len(), 0);
    assert!(trace.signal_summary.is_empty());
}
