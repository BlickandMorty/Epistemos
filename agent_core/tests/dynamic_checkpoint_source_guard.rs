use std::fs;

#[test]
fn dynamic_compute_checkpoint_constructor_stays_log_bound() {
    let source = fs::read_to_string("src/agent_runtime_v2/dynamic_checkpoint.rs")
        .expect("dynamic checkpoint source should be readable");

    assert!(
        source.contains("pub fn from_visible_run_event("),
        "dynamic checkpoints must expose the constructor that binds a concrete RunEventLog event"
    );
    assert!(
        !source.contains("pub fn new("),
        "dynamic checkpoints must not expose a public constructor that accepts only a run_event_log:<ordinal> string"
    );
}
