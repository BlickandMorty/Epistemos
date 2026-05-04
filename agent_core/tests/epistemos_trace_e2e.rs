//! End-to-end integration test for the `epistemos-trace` CLI binary.
//!
//! Exercises the full Phase-1 / parallel-track contract:
//!
//!   1. Build a `ReplayBundle` programmatically (mirrors what the
//!      Swift app's "Export bundle" button will do via UniFFI).
//!   2. Write the bundle to a temp `.epbundle` file on disk.
//!   3. Run the `epistemos-trace verify` binary against it.
//!   4. Assert exit code 0 + the success line on stdout.
//!   5. Tamper with one byte and re-run; assert exit code 4.
//!
//! Lives in `tests/` (not `src/`) so cargo treats it as an integration
//! test that builds the binary first. CI runs it with the rest of
//! `cargo test`.

use std::process::{Command, Stdio};

use agent_core::mutations::{
    types::{MutationActor, Reversibility, Sensitivity, SourceOp},
    MutationEnvelope,
};
use agent_core::provenance::{Claim, ClaimId, ClaimLedger, Evidence, EvidenceId, ReplayBundle};

fn t() -> i64 {
    1_745_000_000_000
}

fn seed_bundle() -> ReplayBundle {
    let mut l = ClaimLedger::new();
    l.commit_evidence(Evidence::new(EvidenceId::new("ev-1"), "arxiv://1234", t()))
        .unwrap();
    l.commit_claim(
        Claim::new(ClaimId::new("c1"), "ground truth", t()),
        vec![],
        vec![EvidenceId::new("ev-1")],
    )
    .unwrap();
    let m = MutationEnvelope::pending(
        "m-1".into(),
        1,
        MutationActor::User,
        SourceOp::ArtifactUpdate {
            artifact_id: "doc-1".into(),
        },
        Sensitivity::Internal,
        Reversibility::Reversible,
        t(),
    );
    ReplayBundle::build(
        "bundle-e2e".into(),
        Some("run-e2e".into()),
        t(),
        &l,
        vec![m],
    )
    .unwrap()
}

/// Locate the freshly-built `epistemos_trace` binary. Cargo sets
/// `CARGO_BIN_EXE_<name>` for integration tests so we don't have to
/// guess the host triple's debug subdirectory.
fn cli_path() -> String {
    env!("CARGO_BIN_EXE_epistemos_trace").to_string()
}

#[test]
fn cli_verify_clean_bundle_exits_zero() {
    let bundle = seed_bundle();
    let bytes = bundle.to_epbundle_bytes().unwrap();
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("clean.epbundle");
    std::fs::write(&path, &bytes).unwrap();

    let output = Command::new(cli_path())
        .arg("verify")
        .arg(&path)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .expect("CLI must run");
    assert!(
        output.status.success(),
        "expected exit 0, got status={:?}\nstdout={}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr),
    );
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(
        stdout.starts_with("ok  bundle_id=bundle-e2e"),
        "stdout must start with success line; got: {stdout}"
    );
}

#[test]
fn cli_verify_tampered_bundle_exits_four() {
    let bundle = seed_bundle();
    let mut bytes = bundle.to_epbundle_bytes().unwrap();
    // Flip one byte INSIDE the JSON content (away from the integrity
    // hash field itself, so we hit the integrity check rather than a
    // parse error).
    let claim_text_marker = b"ground truth";
    let pos = bytes
        .windows(claim_text_marker.len())
        .position(|w| w == claim_text_marker)
        .expect("seed bundle must contain the marker text");
    bytes[pos] = b'X';

    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("tampered.epbundle");
    std::fs::write(&path, &bytes).unwrap();

    let output = Command::new(cli_path())
        .arg("verify")
        .arg(&path)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .expect("CLI must run");
    assert_eq!(
        output.status.code(),
        Some(4),
        "tampered bundle must exit 4; got {:?}\nstderr={}",
        output.status.code(),
        String::from_utf8_lossy(&output.stderr),
    );
}

#[test]
fn cli_verify_missing_file_exits_two() {
    let output = Command::new(cli_path())
        .arg("verify")
        .arg("/path/that/cannot/possibly/exist/bundle.epbundle")
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .expect("CLI must run");
    assert_eq!(output.status.code(), Some(2));
}

#[test]
fn cli_verify_malformed_bundle_exits_three() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("garbage.epbundle");
    std::fs::write(&path, b"this is not json").unwrap();
    let output = Command::new(cli_path())
        .arg("verify")
        .arg(&path)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .expect("CLI must run");
    assert_eq!(output.status.code(), Some(3));
}

#[test]
fn cli_no_args_exits_one() {
    let output = Command::new(cli_path())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .expect("CLI must run");
    assert_eq!(output.status.code(), Some(1));
}

#[test]
fn cli_help_exits_zero() {
    let output = Command::new(cli_path())
        .arg("--help")
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .expect("CLI must run");
    assert!(output.status.success());
    assert!(String::from_utf8_lossy(&output.stdout).contains("epistemos-trace"));
}
