// HARDENING ENFORCEMENT: this CLI is the doctrine-enforcement contract
// surface. A panic during lint means `epistemos-doctrine-lint` exits
// non-zero with uncaught-panic in stderr, which a CI consumer would
// interpret as a system failure rather than a doctrine violation.
// Every error path returns a typed exit code instead. No
// unwrap/expect/panic in production paths.
#![cfg_attr(
    not(test),
    deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)
)]

//! `epistemos-doctrine-lint` — Phase 8.G doctrine enforcement.
//!
//! Doctrine reference: `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` §5.
//!
//! This binary codifies the four grep-based verification gates from
//! doctrine §5 ("verification gates additional to kernel doctrine §10")
//! into a single CI-runnable check. The two test-based gates (5.5
//! Merkle reproducibility + 5.6 replay round-trip) are already
//! enforced by `cargo test`; this binary covers the four gates that
//! are awkward to express as `#[test]`s because they reach across the
//! workspace tree.
//!
//! ## Gates checked (verbatim from doctrine §5)
//!
//! - **5.1** — DAG schema is closed. Exactly one `enum EdgeKind`
//!   definition, in `agent_core/src/cognitive_dag/`.
//! - **5.2** — All edges signature-checked at insertion. The `put_edge`
//!   body in `cognitive_dag/storage.rs` must contain explicit
//!   signature verification before the put.
//! - **5.3** — Content-addressing enforced. The `put_node` body in
//!   `cognitive_dag/storage.rs` must compute the node id from content
//!   and reject pre-set mismatched ids.
//! - **5.4** — No DAG storage outside the kernel. Swift + XPC code
//!   must contain zero CODE references to `DagStore`, `put_node`, or
//!   `put_edge`. Doc-comment / prose mentions are reported as INFO
//!   (doctrine intent honored: Swift does not hold or call the DAG
//!   directly; documentation that NAMES the types is fine).
//!
//! Gate 4.x anti-patterns from doctrine §4 (no edges without
//! signatures, no nodes without content addresses, no ad-hoc edge
//! types, no DAG state outside kernel, no retroactive mutation) are
//! all enforced by gates 5.1-5.4 above. Gate 4.5 ("no retroactive
//! mutation") is structurally enforced by content-addressing — a
//! mutated node has a different id, so "in-place edit" is impossible
//! by construction.
//!
//! ## Usage
//!
//!   epistemos-doctrine-lint                 # lint the current directory
//!   epistemos-doctrine-lint <repo-root>     # lint a specific path
//!   epistemos-doctrine-lint --version
//!   epistemos-doctrine-lint --help
//!
//! ## Exit codes
//!
//!   0  — all gates passed
//!   1  — usage error (missing arg, bad subcommand)
//!   2  — io error (could not walk the tree)
//!   3  — doctrine violation (one or more gates failed)

use std::fs;
use std::path::{Path, PathBuf};
use std::process::ExitCode;

const USAGE: &str = "\
epistemos-doctrine-lint — DAG doctrine §5 verification gates

USAGE:
  epistemos-doctrine-lint              Lint the current directory.
  epistemos-doctrine-lint <repo-root>  Lint a specific path.
  epistemos-doctrine-lint --version    Print version and exit.
  epistemos-doctrine-lint --help       Print this help and exit.

EXIT CODES:
  0  all gates passed
  1  usage error
  2  io error (cannot walk the tree)
  3  doctrine violation (one or more gates failed)

GATES (from cognitive DAG doctrine §5):
  5.1  exactly one `enum EdgeKind {` in agent_core/src/cognitive_dag/
  5.2  put_edge body in storage.rs verifies signature before insert
  5.3  put_node body in storage.rs computes id from content
  5.4  Swift / XPC zero CODE references to DagStore / put_node / put_edge
       (doc-comment / prose mentions reported as INFO, not failure)
";

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().collect();
    let argv = args.iter().map(String::as_str).collect::<Vec<_>>();

    let repo_root: PathBuf = match argv.as_slice() {
        [_] => match std::env::current_dir() {
            Ok(p) => p,
            Err(e) => {
                eprintln!("error: cannot read current directory: {e}");
                return ExitCode::from(2);
            }
        },
        [_, "--help" | "-h" | "help"] => {
            println!("{USAGE}");
            return ExitCode::SUCCESS;
        }
        [_, "--version" | "-V"] => {
            println!("epistemos-doctrine-lint {}", env!("CARGO_PKG_VERSION"));
            return ExitCode::SUCCESS;
        }
        [_, path] => PathBuf::from(path),
        _ => {
            eprintln!("error: unknown invocation\n\n{USAGE}");
            return ExitCode::from(1);
        }
    };

    if !repo_root.is_dir() {
        eprintln!("error: `{}` is not a directory", repo_root.display());
        return ExitCode::from(2);
    }

    match run_all_gates(&repo_root) {
        Ok(report) => {
            print_report(&report);
            if report.violations() > 0 {
                ExitCode::from(3)
            } else {
                ExitCode::SUCCESS
            }
        }
        Err(e) => {
            eprintln!("error: {e}");
            ExitCode::from(2)
        }
    }
}

// ── Gate runner ────────────────────────────────────────────────────────────

#[derive(Debug, Default)]
struct LintReport {
    gate_5_1: GateOutcome,
    gate_5_2: GateOutcome,
    gate_5_3: GateOutcome,
    gate_5_4: GateOutcome,
}

#[derive(Debug, Default)]
struct GateOutcome {
    name: &'static str,
    detail: String,
    violation: bool,
    info_lines: Vec<String>,
}

impl LintReport {
    fn violations(&self) -> usize {
        [
            self.gate_5_1.violation,
            self.gate_5_2.violation,
            self.gate_5_3.violation,
            self.gate_5_4.violation,
        ]
        .iter()
        .filter(|v| **v)
        .count()
    }
}

fn run_all_gates(root: &Path) -> Result<LintReport, String> {
    Ok(LintReport {
        gate_5_1: check_gate_5_1(root)?,
        gate_5_2: check_gate_5_2(root)?,
        gate_5_3: check_gate_5_3(root)?,
        gate_5_4: check_gate_5_4(root)?,
    })
}

// ── 5.1 — exactly one `enum EdgeKind {` in cognitive_dag/ ──────────────────

fn check_gate_5_1(root: &Path) -> Result<GateOutcome, String> {
    let dir = root.join("agent_core/src/cognitive_dag");
    if !dir.is_dir() {
        return Ok(GateOutcome {
            name: "5.1 EdgeKind enum closed",
            detail: format!("cognitive_dag dir not found at {}", dir.display()),
            violation: true,
            info_lines: vec![],
        });
    }
    // Match the literal opening of the EdgeKind enum (with brace) so we
    // don't accidentally count `EdgeKindSelector`, the sibling type that
    // shares the prefix.
    let mut hits: Vec<(PathBuf, usize, String)> = Vec::new();
    walk_rs_files(&dir, &mut |path, line_num, line| {
        if line.contains("pub enum EdgeKind {") || line.starts_with("enum EdgeKind {") {
            hits.push((path.to_path_buf(), line_num, line.to_string()));
        }
    })?;
    let violation = hits.len() != 1;
    let detail = if violation {
        format!(
            "expected exactly 1 `enum EdgeKind {{` definition, found {}: {}",
            hits.len(),
            hits.iter()
                .map(|(p, n, _)| format!("{}:{}", p.display(), n))
                .collect::<Vec<_>>()
                .join(", ")
        )
    } else {
        format!("ok ({}:{})", hits[0].0.display(), hits[0].1)
    };
    Ok(GateOutcome {
        name: "5.1 EdgeKind enum closed",
        detail,
        violation,
        info_lines: vec![],
    })
}

// ── 5.2 — put_edge body verifies signature before insert ───────────────────

fn check_gate_5_2(root: &Path) -> Result<GateOutcome, String> {
    let path = root.join("agent_core/src/cognitive_dag/storage.rs");
    // Missing file → doctrine violation (storage.rs is the canonical
    // location per doctrine §1.3). Same UX as gate 5.1's cognitive_dag
    // dir-not-found path, so callers always see a structured violation
    // report rather than an io error.
    let src = match fs::read_to_string(&path) {
        Ok(s) => s,
        Err(e) => {
            return Ok(GateOutcome {
                name: "5.2 put_edge signature-check",
                detail: format!("storage.rs not found at {}: {e}", path.display()),
                violation: true,
                info_lines: vec![],
            });
        }
    };
    // Find the `put_edge` impl body and check it references the canonical
    // signature verification helper. Doctrine §4.1: "An unsigned edge
    // means an unauthorized mutation; the kernel must reject it at the
    // storage layer (`put_edge` returns `DagError::UnsignedEdge`)."
    //
    // The current impl uses `Edge::verify_signature(...)`; a future
    // refactor that drops the verify call without replacing it with an
    // equivalent macaroon-validated check would be a doctrine violation.
    // Search for ANY of the canonical verification idioms.
    let put_edge_section = extract_fn_body(&src, "fn put_edge");
    let body = match put_edge_section {
        Some(b) => b,
        None => {
            return Ok(GateOutcome {
                name: "5.2 put_edge signature-check",
                detail: format!("`fn put_edge` not found in {}", path.display()),
                violation: true,
                info_lines: vec![],
            });
        }
    };
    let verifies = body.contains("verify_signature")
        || body.contains("InvalidSignature")
        || body.contains("verify_macaroon");
    Ok(GateOutcome {
        name: "5.2 put_edge signature-check",
        detail: if verifies {
            "ok (`put_edge` body references signature verification)".to_string()
        } else {
            "VIOLATION: `put_edge` body does not reference verify_signature, \
             verify_macaroon, or InvalidSignature — every edge must be \
             validated before insertion (doctrine §4.1)"
                .to_string()
        },
        violation: !verifies,
        info_lines: vec![],
    })
}

// ── 5.3 — put_node body computes id from content ───────────────────────────

fn check_gate_5_3(root: &Path) -> Result<GateOutcome, String> {
    let path = root.join("agent_core/src/cognitive_dag/storage.rs");
    let src = match fs::read_to_string(&path) {
        Ok(s) => s,
        Err(e) => {
            return Ok(GateOutcome {
                name: "5.3 put_node content-addressing",
                detail: format!("storage.rs not found at {}: {e}", path.display()),
                violation: true,
                info_lines: vec![],
            });
        }
    };
    let put_node_section = extract_fn_body(&src, "fn put_node");
    let body = match put_node_section {
        Some(b) => b,
        None => {
            return Ok(GateOutcome {
                name: "5.3 put_node content-addressing",
                detail: format!("`fn put_node` not found in {}", path.display()),
                violation: true,
                info_lines: vec![],
            });
        }
    };
    // The put_node implementation must derive the id from content.
    // Canonical idioms: `compute_id`, `Node::new`, `Node::new_at`, or
    // an explicit content-hash assertion. A bare `node.id` insert
    // without recomputation would mean the caller's id is trusted —
    // doctrine §4.2 violation.
    let computes = body.contains("compute_id")
        || body.contains("Node::new")
        || body.contains("Self::compute_id")
        || body.contains("expected_id");
    Ok(GateOutcome {
        name: "5.3 put_node content-addressing",
        detail: if computes {
            "ok (`put_node` body computes node id from content)".to_string()
        } else {
            "VIOLATION: `put_node` body does not reference compute_id / \
             Node::new / expected_id — node ids must be derived from \
             content (doctrine §4.2)"
                .to_string()
        },
        violation: !computes,
        info_lines: vec![],
    })
}

// ── 5.4 — no Swift / XPC code references to DagStore / put_node / put_edge ─

fn check_gate_5_4(root: &Path) -> Result<GateOutcome, String> {
    let mut code_violations: Vec<String> = Vec::new();
    let mut info_hits: Vec<String> = Vec::new();

    for sub in ["Epistemos", "XPCServices"] {
        let dir = root.join(sub);
        if !dir.is_dir() {
            continue;
        }
        walk_swift_files(&dir, &mut |path, line_num, raw_line| {
            if !line_mentions_forbidden(raw_line) {
                return;
            }
            // Doctrine intent: no Swift code that HOLDS or CALLS DAG
            // storage. Doc-comment / prose mentions of the type names
            // are documentation, not violations. We classify by the
            // line's leading non-whitespace prefix:
            //   - "//" or "///" → comment
            //   - "/*" or "*"   → block-comment line
            //   - anything else → code reference
            let trimmed = raw_line.trim_start();
            let is_comment =
                trimmed.starts_with("//") || trimmed.starts_with("/*") || trimmed.starts_with("*");
            let entry = format!("{}:{}: {}", path.display(), line_num, trimmed.trim_end());
            if is_comment {
                info_hits.push(entry);
            } else {
                code_violations.push(entry);
            }
        })?;
    }

    let violation = !code_violations.is_empty();
    let detail = if violation {
        format!(
            "VIOLATION: {} Swift / XPC CODE reference(s) to DagStore / \
             put_node / put_edge (doctrine §4.4 + §5.4 — Swift is a \
             VIEWER, not a DAG owner):\n  {}",
            code_violations.len(),
            code_violations.join("\n  ")
        )
    } else if info_hits.is_empty() {
        "ok (no Swift / XPC references at all)".to_string()
    } else {
        format!(
            "ok ({} doc-comment / prose mention(s) — documentation OK \
             per doctrine intent)",
            info_hits.len()
        )
    };
    Ok(GateOutcome {
        name: "5.4 no Swift DAG storage",
        detail,
        violation,
        info_lines: info_hits,
    })
}

fn line_mentions_forbidden(line: &str) -> bool {
    line.contains("DagStore") || line.contains("put_node") || line.contains("put_edge")
}

// ── Filesystem walkers ─────────────────────────────────────────────────────

fn walk_rs_files(dir: &Path, cb: &mut dyn FnMut(&Path, usize, &str)) -> Result<(), String> {
    walk_files_with_ext(dir, "rs", cb)
}

fn walk_swift_files(dir: &Path, cb: &mut dyn FnMut(&Path, usize, &str)) -> Result<(), String> {
    walk_files_with_ext(dir, "swift", cb)
}

fn walk_files_with_ext(
    dir: &Path,
    ext: &str,
    cb: &mut dyn FnMut(&Path, usize, &str),
) -> Result<(), String> {
    let entries =
        fs::read_dir(dir).map_err(|e| format!("read_dir {} failed: {e}", dir.display()))?;
    for entry in entries {
        let entry = entry.map_err(|e| format!("dir entry error in {}: {e}", dir.display()))?;
        let path = entry.path();
        if path.is_dir() {
            // Skip noisy dirs that aren't doctrine-bearing.
            let name = entry.file_name();
            let name_str = name.to_string_lossy();
            if matches!(
                name_str.as_ref(),
                "target" | "build" | ".git" | ".build" | "DerivedData" | "Pods"
            ) {
                continue;
            }
            walk_files_with_ext(&path, ext, cb)?;
            continue;
        }
        let path_ext = path.extension().and_then(|e| e.to_str()).unwrap_or("");
        if path_ext != ext {
            continue;
        }
        let src = match fs::read_to_string(&path) {
            Ok(s) => s,
            Err(_) => continue, // binary file or permission issue — skip
        };
        for (i, line) in src.lines().enumerate() {
            cb(&path, i + 1, line);
        }
    }
    Ok(())
}

/// Extract the source text between the opening brace of a function and
/// its matching closing brace. Used to scope grep-like checks to a
/// specific function body. Returns None if the function isn't found
/// or the braces don't balance.
///
/// **Trait-declaration handling.** The cognitive_dag/storage.rs file
/// has BOTH a trait declaration (`fn put_node(...) -> ...;`) and an
/// impl body (`fn put_node(...) -> ... { ... }`). We want the impl
/// body. So for each occurrence of the prefix, we scan forward to the
/// next `{` or `;` (whichever comes first) and accept only the
/// occurrence whose signature ends in `{`. The first impl wins.
///
/// Brace-depth tracking does NOT respect block comments or string-
/// literal braces — those would need a real parser. The
/// cognitive_dag/storage.rs source is hand-written enough that this
/// heuristic is reliable; if a future refactor adds odd brace
/// patterns, the linter falls back to "function body not found" + a
/// violation, which is the safe failure mode (the linter never
/// silently passes a bad signature).
fn extract_fn_body(src: &str, fn_signature_prefix: &str) -> Option<String> {
    let mut search_offset = 0usize;
    while let Some(rel_idx) = src[search_offset..].find(fn_signature_prefix) {
        let start_idx = search_offset + rel_idx;
        let tail = &src[start_idx..];
        // Find the first `{` or `;` after the signature.
        let next_brace = tail.find('{');
        let next_semi = tail.find(';');
        match (next_brace, next_semi) {
            (Some(b), Some(s)) if b < s => {
                // Brace comes first — this is the impl body.
                return read_balanced_braces(src, start_idx + b);
            }
            (Some(b), None) => {
                return read_balanced_braces(src, start_idx + b);
            }
            (Some(_), Some(_)) | (None, Some(_)) => {
                // Trait declaration (`fn foo(...) -> ...;`) — skip.
                search_offset = start_idx + fn_signature_prefix.len();
                continue;
            }
            (None, None) => return None,
        }
    }
    None
}

fn read_balanced_braces(src: &str, body_start: usize) -> Option<String> {
    let mut depth = 0i32;
    let mut end_idx = None;
    for (i, ch) in src[body_start..].char_indices() {
        match ch {
            '{' => depth += 1,
            '}' => {
                depth -= 1;
                if depth == 0 {
                    end_idx = Some(body_start + i + 1);
                    break;
                }
            }
            _ => {}
        }
    }
    end_idx.map(|end| src[body_start..end].to_string())
}

// ── Reporter ───────────────────────────────────────────────────────────────

fn print_report(report: &LintReport) {
    println!("epistemos-doctrine-lint v{}", env!("CARGO_PKG_VERSION"));
    println!();
    for gate in [
        &report.gate_5_1,
        &report.gate_5_2,
        &report.gate_5_3,
        &report.gate_5_4,
    ] {
        let prefix = if gate.violation { "FAIL" } else { "PASS" };
        println!("[{prefix}] {} — {}", gate.name, gate.detail);
        for info in &gate.info_lines {
            println!("    INFO: {info}");
        }
    }
    println!();
    let v = report.violations();
    if v == 0 {
        println!("ALL GATES PASS — doctrine §5 verified.");
    } else {
        println!("DOCTRINE VIOLATION — {v} gate(s) failed.");
    }
}

// ── Tests ──────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extract_fn_body_finds_simple_body() {
        let src = "fn foo() { let x = 1; let y = 2; x + y }\nfn bar() {}";
        let body = extract_fn_body(src, "fn foo").unwrap();
        assert!(body.starts_with('{'));
        assert!(body.ends_with('}'));
        assert!(body.contains("let x = 1"));
        assert!(body.contains("x + y"));
        // Must not bleed into the next function.
        assert!(!body.contains("fn bar"));
    }

    #[test]
    fn extract_fn_body_handles_nested_braces() {
        let src = "fn outer() { if true { let z = { 1 + 2 }; z } else { 0 } }";
        let body = extract_fn_body(src, "fn outer").unwrap();
        // Body must include both inner blocks.
        assert!(body.contains("let z = { 1 + 2 }"));
        assert!(body.contains("else { 0 }"));
    }

    #[test]
    fn extract_fn_body_returns_none_for_missing_fn() {
        let src = "fn foo() {}";
        assert!(extract_fn_body(src, "fn nonexistent").is_none());
    }

    #[test]
    fn extract_fn_body_skips_trait_declaration_and_finds_impl() {
        // The cognitive_dag/storage.rs file has both a trait declaration
        // (`fn put_node(...) -> ...;`) and an impl body. We must skip
        // the declaration and find the impl.
        let src = "\
trait DagStore {
    fn put_node(&self, node: Node) -> Result<NodeId, DagError>;
    fn get_node(&self, id: NodeId) -> Result<Option<Node>, DagError>;
}

impl DagStore for InMemoryDagStore {
    fn put_node(&self, node: Node) -> Result<NodeId, DagError> {
        let expected = compute_id(&node.kind);
        Ok(node.id)
    }
}";
        let body = extract_fn_body(src, "fn put_node").expect("must find impl body");
        assert!(body.contains("compute_id"), "found body: {body}");
        // Must NOT match the trait declaration's `;`-terminated signature.
        assert!(!body.contains("fn get_node"));
    }

    #[test]
    fn line_mentions_forbidden_catches_each_pattern() {
        assert!(line_mentions_forbidden("let store: DagStore = ..."));
        assert!(line_mentions_forbidden("store.put_node(node)"));
        assert!(line_mentions_forbidden("put_edge(edge)"));
        assert!(!line_mentions_forbidden("let x = 1"));
        assert!(!line_mentions_forbidden("InMemorySomething"));
    }
}
