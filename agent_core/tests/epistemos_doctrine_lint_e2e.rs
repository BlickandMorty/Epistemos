//! End-to-end integration test for the `epistemos-doctrine-lint` CLI
//! binary (Phase 8.G).
//!
//! Exercises the full doctrine §5 contract:
//!
//!   1. Run the linter against the real repo root and assert exit 0.
//!      This is the canonical CI gate — if any of the four gates
//!      regresses (e.g. a future PR adds a second `enum EdgeKind` or
//!      drops the `put_node` content-addressing check), this test
//!      fails and the PR is blocked.
//!   2. Run against a fabricated tree that intentionally violates each
//!      gate, one at a time, and assert the matching exit codes.
//!
//! Why a real-repo test: the linter exists to catch doctrine drift.
//! The most useful regression signal is "does the actual codebase
//! pass." If we only tested against synthetic violation fixtures, a
//! drift in the real source would land silently. This integration
//! test gives us that high-signal gate.
//!
//! Lives in `tests/` so cargo treats it as an integration test that
//! builds the binary first. CI runs it with the rest of `cargo test`.

use std::process::{Command, Stdio};

fn cli_path() -> String {
    env!("CARGO_BIN_EXE_epistemos_doctrine_lint").to_string()
}

/// The repo root for this workspace. The integration binary is built
/// at `<repo>/agent_core/target/.../epistemos_doctrine_lint`; we
/// derive the repo root from the cargo manifest dir.
fn repo_root() -> std::path::PathBuf {
    let manifest_dir = env!("CARGO_MANIFEST_DIR");
    std::path::Path::new(manifest_dir)
        .parent()
        .expect("agent_core must have a parent (the workspace root)")
        .to_path_buf()
}

#[test]
fn lints_real_repo_and_passes_all_gates() {
    let output = Command::new(cli_path())
        .arg(repo_root())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .expect("CLI must run");
    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        output.status.success(),
        "real repo must pass doctrine §5; got exit {:?}\n--- STDOUT ---\n{}\n--- STDERR ---\n{}",
        output.status.code(),
        stdout,
        stderr,
    );
    // Sanity: stdout must mention all four gates as PASS.
    for gate in [
        "5.1 EdgeKind enum closed",
        "5.2 put_edge signature-check",
        "5.3 put_node content-addressing",
        "5.4 no Swift DAG storage",
    ] {
        assert!(
            stdout.contains(&format!("[PASS] {}", gate)),
            "expected gate `{gate}` to PASS; stdout:\n{stdout}"
        );
    }
    assert!(stdout.contains("ALL GATES PASS"));
}

#[test]
fn no_args_lints_current_directory_or_errors_cleanly() {
    // No-args mode should attempt to lint cwd. The cwd at test time is
    // typically the cargo manifest dir (agent_core), which doesn't
    // contain `agent_core/src/cognitive_dag/` at that path — so we
    // expect either a violation (gate 5.1 says cognitive_dag dir not
    // found) or success if cwd happens to be the workspace root.
    let output = Command::new(cli_path())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .expect("CLI must run");
    // Either exit 0 (cwd is workspace root) or exit 3 (cwd is
    // somewhere else and the dir-not-found violation fires). NEVER
    // exit 1 (usage) or 2 (io) — those are configuration bugs.
    let code = output.status.code().unwrap_or(-1);
    assert!(
        code == 0 || code == 3,
        "no-args mode must exit 0 or 3, got {code}"
    );
}

#[test]
fn nonexistent_path_exits_two() {
    let output = Command::new(cli_path())
        .arg("/path/that/cannot/possibly/exist")
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .expect("CLI must run");
    assert_eq!(output.status.code(), Some(2));
}

#[test]
fn help_advertises_all_four_gates() {
    let output = Command::new(cli_path())
        .arg("--help")
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .expect("CLI must run");
    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    for marker in ["5.1", "5.2", "5.3", "5.4"] {
        assert!(
            stdout.contains(marker),
            "help text must reference gate {marker}: {stdout}"
        );
    }
}

#[test]
fn synthetic_violation_5_1_extra_edgekind_enum_fails() {
    // Build a temp dir that mirrors the cognitive_dag layout and
    // intentionally adds a SECOND `enum EdgeKind {` definition.
    let tmp = tempfile::tempdir().unwrap();
    let cd_dir = tmp.path().join("agent_core/src/cognitive_dag");
    std::fs::create_dir_all(&cd_dir).unwrap();

    // First file: the canonical EdgeKind enum.
    std::fs::write(
        cd_dir.join("edge.rs"),
        "pub enum EdgeKind {\n    DerivesFrom,\n}\n",
    )
    .unwrap();
    // Second file: an illegal extra EdgeKind enum.
    std::fs::write(
        cd_dir.join("rogue.rs"),
        "pub enum EdgeKind {\n    Forbidden,\n}\n",
    )
    .unwrap();

    // Provide a minimal storage.rs so gates 5.2 / 5.3 don't fail
    // before 5.1 even runs (they're independent gates but we want a
    // clean signal).
    std::fs::write(
        cd_dir.join("storage.rs"),
        "fn put_node(&self) { Node::new(...); }\nfn put_edge(&self) { verify_signature(...); }\n",
    )
    .unwrap();

    let output = Command::new(cli_path())
        .arg(tmp.path())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .expect("CLI must run");
    assert_eq!(
        output.status.code(),
        Some(3),
        "two EdgeKind enums must trigger doctrine violation (exit 3)"
    );
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("[FAIL] 5.1"));
    assert!(stdout.contains("expected exactly 1"));
}

#[test]
fn synthetic_violation_5_3_put_node_without_compute_id_fails() {
    let tmp = tempfile::tempdir().unwrap();
    let cd_dir = tmp.path().join("agent_core/src/cognitive_dag");
    std::fs::create_dir_all(&cd_dir).unwrap();
    std::fs::write(cd_dir.join("edge.rs"), "pub enum EdgeKind {}\n").unwrap();
    // put_node body that bypasses content-addressing — caller's id is
    // trusted blindly. Doctrine §4.2 violation.
    std::fs::write(
        cd_dir.join("storage.rs"),
        "fn put_node(&self, node: Node) { self.nodes.insert(node.id, node); }\n\
         fn put_edge(&self, edge: Edge) { verify_signature(&edge); }\n",
    )
    .unwrap();

    let output = Command::new(cli_path())
        .arg(tmp.path())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .expect("CLI must run");
    assert_eq!(output.status.code(), Some(3));
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("[FAIL] 5.3"));
}
