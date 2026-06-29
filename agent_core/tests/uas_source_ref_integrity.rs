//! Meta-integrity guard for the `uas/` gate family.
//!
//! The `*_release_blocker_card` / `*_source_guard` / route-policy gates assert
//! "these named Swift/Rust files are THE surface for capability X". Their own
//! unit tests only check that the ref *strings* are present in the list — so if
//! one of those files is renamed or deleted, the gate keeps passing while its
//! safety claim silently becomes fiction.
//!
//! This single test scans the production (non-test) portion of every `src/uas`
//! gate, extracts the `Epistemos/...` and `agent_core/...` `.swift`/`.rs` file
//! refs, and asserts each resolves on disk. It guards the whole family plus any
//! future gate, with no per-gate boilerplate.
//!
//! It caught `Epistemos/Engine/QueryTypes.swift` (the file had moved to
//! `Epistemos/Models/`) in `search_index_release_blocker_card` when it landed.

use std::fs;
use std::path::{Path, PathBuf};

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("agent_core has a parent (the repo root)")
        .to_path_buf()
}

/// Pull repo-relative source-file refs from the NON-test portion of a gate.
///
/// Scanning stops at the first `#[cfg(test)]` so test fixtures — which
/// deliberately use bogus paths for rejection/path-traversal tests — are not
/// flagged. Refs containing `{` (format placeholders) or `:` (file:symbol
/// pointers) are skipped; only clean `Epistemos/...`/`agent_core/...` paths
/// ending in `.swift`/`.rs` are returned.
fn extract_source_refs(src: &str) -> Vec<String> {
    let body = match src.find("#[cfg(test)]") {
        Some(idx) => &src[..idx],
        None => src,
    };

    let mut refs = Vec::new();
    let mut rest = body;
    while let Some(open) = rest.find('"') {
        rest = &rest[open + 1..];
        let Some(close) = rest.find('"') else { break };
        let literal = &rest[..close];
        rest = &rest[close + 1..];

        let is_repo_path = literal.starts_with("Epistemos/") || literal.starts_with("agent_core/");
        let is_source_file = literal.ends_with(".swift") || literal.ends_with(".rs");
        let is_clean = !literal.contains('{') && !literal.contains(':');
        if is_repo_path && is_source_file && is_clean {
            refs.push(literal.to_string());
        }
    }
    refs
}

#[test]
fn uas_gate_source_refs_resolve_to_real_files() {
    let root = repo_root();
    let uas_dir = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("src")
        .join("uas");

    let mut missing: Vec<String> = Vec::new();
    let mut checked = 0usize;

    for entry in fs::read_dir(&uas_dir).expect("read src/uas") {
        let path = entry.expect("dir entry").path();
        if path.extension().and_then(|e| e.to_str()) != Some("rs") {
            continue;
        }
        let src = fs::read_to_string(&path).expect("read gate source");
        let file = path.file_name().unwrap().to_string_lossy().to_string();
        for source_ref in extract_source_refs(&src) {
            checked += 1;
            if !root.join(&source_ref).exists() {
                missing.push(format!("{file}: {source_ref}"));
            }
        }
    }

    // Guard against the matcher silently breaking and scanning nothing.
    assert!(
        checked > 20,
        "expected to scan many uas/ source refs, only saw {checked} — matcher likely broke"
    );
    assert!(
        missing.is_empty(),
        "uas/ gates name source files that no longer exist (rename/delete drift):\n  {}",
        missing.join("\n  ")
    );
}

/// Cursors that are intentional terminal states of the witness chain rather
/// than gate files (the chain "exits" to product-route review).
const TERMINAL_CURSORS: &[&str] = &[
    "ready_for_product_route_review",
    // The synthetic-fixture owner-approval gate's successor (the actual staged
    // write) is the owner-gated frontier — intentionally unbuilt until
    // owner-approved on-device bytes exist.
    "synthetic_fixture_staged_write_owner_gated_frontier",
    // The runtime-plural owner-approval gate's successor (the actual E2B GGUF
    // same-fixture runtime probe) is the owner-gated frontier — needs real
    // on-device bytes + a signed run.
    "runtime_plural_e2b_gguf_same_fixture_owner_gated_runtime_probe_frontier",
    // The small-compressed owner-approved runtime probe's successor (the actual
    // first-token execution + retained-token receipt) is the owner-gated
    // frontier — needs explicit owner approval, a real local model path, and a
    // signed on-device run that produces real (redacted) bytes.
    "small_compressed_model_owner_approved_runtime_probe_first_token_owner_gated_frontier",
];

/// Extract every `*_NEXT_CURSOR: &str = "..."` target from the non-test portion.
fn extract_next_cursors(src: &str) -> Vec<String> {
    let body = match src.find("#[cfg(test)]") {
        Some(idx) => &src[..idx],
        None => src,
    };
    let mut out = Vec::new();
    for line in body.lines() {
        let Some(pos) = line.find("NEXT_CURSOR") else {
            continue;
        };
        let after = &line[pos..];
        // Only `... NEXT_CURSOR...: &str = "value"` const declarations.
        if !after.contains(": &str") {
            continue;
        }
        let Some(eq) = after.find('=') else { continue };
        let rhs = &after[eq + 1..];
        let Some(q1) = rhs.find('"') else { continue };
        let Some(q2) = rhs[q1 + 1..].find('"') else {
            continue;
        };
        out.push(rhs[q1 + 1..q1 + 1 + q2].to_string());
    }
    out
}

#[test]
fn uas_next_cursors_resolve_to_gates_or_terminal() {
    // The witness chain advances gate -> NEXT_CURSOR -> next gate. A dangling
    // NEXT_CURSOR (typo or a gate renamed without updating its referrers) breaks
    // the chain silently. Pin every link to a real gate file or a known terminal.
    let uas_dir = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("src")
        .join("uas");

    let mut dangling: Vec<String> = Vec::new();
    let mut checked = 0usize;

    for entry in fs::read_dir(&uas_dir).expect("read src/uas") {
        let path = entry.expect("dir entry").path();
        if path.extension().and_then(|e| e.to_str()) != Some("rs") {
            continue;
        }
        let src = fs::read_to_string(&path).expect("read gate source");
        let file = path.file_name().unwrap().to_string_lossy().to_string();
        for cursor in extract_next_cursors(&src) {
            checked += 1;
            let resolves = uas_dir.join(format!("{cursor}.rs")).exists()
                || TERMINAL_CURSORS.contains(&cursor.as_str());
            if !resolves {
                dangling.push(format!("{file}: NEXT_CURSOR -> {cursor}"));
            }
        }
    }

    assert!(
        checked > 5,
        "expected several NEXT_CURSOR chain links, saw {checked} — matcher likely broke"
    );
    assert!(
        dangling.is_empty(),
        "uas/ witness-chain links point to gates that don't exist:\n  {}",
        dangling.join("\n  ")
    );
}
