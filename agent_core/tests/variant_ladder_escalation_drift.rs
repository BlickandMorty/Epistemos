//! Variant Ladder doctrine drift gate (Master Fusion Plan §B / Wave A.A3).
//!
//! Doctrine: `EscalationPolicy::Never` is the default. Any call site that
//! opts into `EscalationPolicy::Always` or `EscalationPolicy::OnEmpty`
//! must carry an explicit `// VARIANT-LADDER-DEFER:` source marker so a
//! grep audit can find every escalation path. The marker is a contract
//! with the user — Tier 4+ runs are billable / network-dependent, and
//! the marker forces the author to name the deferred risk before the PR
//! lands.
//!
//! This test fails CI if a new caller adds escalation without the
//! marker. It walks `agent_core/src/**/*.rs`, finds every line that
//! constructs a ladder with `.with_escalation_policy(EscalationPolicy::
//! Always)` or `.with_escalation_policy(EscalationPolicy::OnEmpty)`,
//! and asserts a `VARIANT-LADDER-DEFER:` marker appears in the 6
//! preceding lines (typical comment-then-call pattern).
//!
//! What the test deliberately does NOT flag:
//! - Bare `EscalationPolicy::OnEmpty` / `Always` references in doc
//!   comments, type-name strings, or serde round-trip tests (they don't
//!   construct an escalating ladder).
//! - Test fixtures that build a ladder via `VariantLadder::new()` with
//!   the default `Never` policy and never call `with_escalation_policy`.

use std::fs;
use std::path::{Path, PathBuf};

const ESCALATION_CALL_SUBSTRINGS: &[&str] = &[
    ".with_escalation_policy(EscalationPolicy::Always",
    ".with_escalation_policy(EscalationPolicy::OnEmpty",
];

const DEFER_MARKER: &str = "VARIANT-LADDER-DEFER:";

/// Walk `agent_core/src` and collect every Rust source file.
fn rust_source_files(root: &Path) -> Vec<PathBuf> {
    let mut out = Vec::new();
    let entries = match fs::read_dir(root) {
        Ok(entries) => entries,
        Err(_) => return out,
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            out.extend(rust_source_files(&path));
        } else if path.extension().is_some_and(|ext| ext == "rs") {
            out.push(path);
        }
    }
    out
}

/// Lookback window. Six lines is enough to cover a typical
/// "comment marker + blank + let ladder = ladder.with_…(...)" pattern
/// without straying into unrelated context.
const MARKER_LOOKBACK_LINES: usize = 6;

#[test]
fn every_escalation_policy_call_site_carries_a_defer_marker() {
    // Resolve the agent_core/src directory relative to CARGO_MANIFEST_DIR
    // so the test works regardless of where cargo invokes it from.
    let manifest_dir = env!("CARGO_MANIFEST_DIR");
    let src_root = Path::new(manifest_dir).join("src");
    assert!(
        src_root.exists(),
        "expected agent_core/src to exist at {src_root:?}"
    );

    let mut offenders: Vec<String> = Vec::new();

    for file in rust_source_files(&src_root) {
        let Ok(contents) = fs::read_to_string(&file) else {
            continue;
        };
        let lines: Vec<&str> = contents.lines().collect();
        for (idx, line) in lines.iter().enumerate() {
            // Skip doc-comment lines (`///` / `//!`) — those describe the
            // contract rather than invoke it, and they legitimately
            // reference the substring while explaining the doctrine.
            let trimmed = line.trim_start();
            if trimmed.starts_with("///") || trimmed.starts_with("//!") {
                continue;
            }
            let matches_escalation = ESCALATION_CALL_SUBSTRINGS
                .iter()
                .any(|needle| line.contains(needle));
            if !matches_escalation {
                continue;
            }
            // Marker on the same line counts (e.g. trailing comment).
            if line.contains(DEFER_MARKER) {
                continue;
            }
            // Otherwise look back up to MARKER_LOOKBACK_LINES.
            let start = idx.saturating_sub(MARKER_LOOKBACK_LINES);
            let has_marker = (start..idx).any(|i| {
                lines
                    .get(i)
                    .is_some_and(|prev| prev.contains(DEFER_MARKER))
            });
            if !has_marker {
                offenders.push(format!(
                    "{}:{} — escalation policy call without `// {DEFER_MARKER}` marker within {MARKER_LOOKBACK_LINES} preceding lines:\n    {}",
                    file.strip_prefix(manifest_dir).unwrap_or(&file).display(),
                    idx + 1,
                    line.trim()
                ));
            }
        }
    }

    assert!(
        offenders.is_empty(),
        "Variant Ladder doctrine §B.3 drift detected. Add a `// {DEFER_MARKER} <why>` comment within {MARKER_LOOKBACK_LINES} lines of each escalation call:\n\n{}",
        offenders.join("\n\n")
    );
}

#[test]
fn drift_gate_self_check_finds_escalation_calls() {
    // Self-check: the gate above is only useful if the underlying
    // walker actually finds the known escalation call sites. The
    // variant_ladder tests deliberately construct `Always` / `OnEmpty`
    // ladders with `VARIANT-LADDER-DEFER` markers — we should see at
    // least one such marked line in the codebase. If this drops to
    // zero, either the test files moved or the substring pattern
    // changed; either way the drift gate above silently passes for the
    // wrong reason and needs human review.
    let manifest_dir = env!("CARGO_MANIFEST_DIR");
    let src_root = Path::new(manifest_dir).join("src");

    let mut found_marked_escalation = false;
    for file in rust_source_files(&src_root) {
        let Ok(contents) = fs::read_to_string(&file) else {
            continue;
        };
        let lines: Vec<&str> = contents.lines().collect();
        for (idx, line) in lines.iter().enumerate() {
            let trimmed = line.trim_start();
            if trimmed.starts_with("///") || trimmed.starts_with("//!") {
                continue;
            }
            let is_escalation = ESCALATION_CALL_SUBSTRINGS
                .iter()
                .any(|needle| line.contains(needle));
            if !is_escalation {
                continue;
            }
            let start = idx.saturating_sub(MARKER_LOOKBACK_LINES);
            let has_marker = line.contains(DEFER_MARKER)
                || (start..idx).any(|i| {
                    lines
                        .get(i)
                        .is_some_and(|prev| prev.contains(DEFER_MARKER))
                });
            if has_marker {
                found_marked_escalation = true;
                break;
            }
        }
        if found_marked_escalation {
            break;
        }
    }
    assert!(
        found_marked_escalation,
        "drift gate self-check failed: no escalation call with a `{DEFER_MARKER}` marker found in agent_core/src. Either the variant_ladder tests moved or the substring pattern drifted."
    );
}
