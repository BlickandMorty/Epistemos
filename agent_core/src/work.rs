//! Goose=WORK seam (R-GOOSE, Seam B). The Rust-side seam the Swift `WorkBackend`
//! drives via UniFFI once block/goose (Apache-2.0) is vendored into agent_core as the
//! Work engine. ISOLATED by construction: nothing in the `agent_loop` / `agent_runtime`
//! (Chat / Act) path references this module, so the GOOSE GUARDRAIL (Chat/Act
//! UNCHANGED) holds. Always-compiled + INERT; the real Goose engine is the gated
//! vendor (the heavy follow-on). REAL APIs ONLY — no fake capability, no silent
//! fallback to the Chat/Act engine.

/// Flag that arms the Goose Work seam (mirrors the Swift `EPISTEMOS_WORK_GOOSE_V0`).
pub const WORK_GOOSE_FLAG: &str = "EPISTEMOS_WORK_GOOSE_V0";

/// ProvenanceGate posture for the vendored block/goose source (Goose S2).
pub const GOOSE_VENDOR_LICENSE: &str = "Apache-2.0";
pub const GOOSE_VENDOR_SOURCE: &str = "block/goose";

/// Vendored block/goose types (Apache-2.0, ProvenanceGate `direct_import`) — the
/// FIRST real extraction of block/goose's Rust core into agent_core (Goose S2).
/// Isolated under the `work` module, so the GOOSE GUARDRAIL (Chat/Act unchanged)
/// holds. Leaf-first: only self-contained (std-only) types so far.
pub mod vendored_goose {
    //! Provenance: github.com/block/goose (Apache-2.0), crates/goose/src/source_roots.rs.
    //! `direct_import` — the type body between the VERBATIM markers is byte-for-byte
    //! from upstream; the `pub mod` wrapper + this header are the only additions.
    //! See docs/GOOSE_S2_EXTRACTION_PLAN_2026_06_19.md.

    // --- BEGIN VERBATIM (block/goose, Apache-2.0) ---
    use std::path::PathBuf;

    #[derive(Debug, Clone, PartialEq, Eq)]
    pub struct SourceRoot {
        pub path: PathBuf,
        pub writable: bool,
    }

    impl SourceRoot {
        pub fn read_only(path: PathBuf) -> Self {
            Self {
                path,
                writable: false,
            }
        }
    }
    // --- END VERBATIM ---
}

/// Honest errors for a Work session — no engine wired, or the run failed. The caller
/// surfaces these; the seam NEVER silently falls back to the Chat/Act engine.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum WorkError {
    EngineNotWired,
    RunFailed(String),
}

impl std::fmt::Display for WorkError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            WorkError::EngineNotWired => write!(f, "Goose Work engine not wired"),
            WorkError::RunFailed(m) => write!(f, "Work run failed: {m}"),
        }
    }
}
impl std::error::Error for WorkError {}

fn flag_is_armed(raw: Option<&str>) -> bool {
    matches!(
        raw.map(|s| s.trim().to_ascii_lowercase()).as_deref(),
        Some("1") | Some("true") | Some("yes") | Some("on")
    )
}

/// Whether the Goose Work seam is armed (the env flag is set). Arming only opts in;
/// it does NOT wire an engine — the engine is the gated vendor.
pub fn is_armed() -> bool {
    flag_is_armed(std::env::var(WORK_GOOSE_FLAG).ok().as_deref())
}

/// The honest seam: run a Work session against the Goose engine over the given
/// `source_roots` (the workspace it indexes / diffs — the first vendored block/goose
/// type). Until the engine layer is vendored, this is INERT — it returns
/// `EngineNotWired` (NEVER a silent fallback to Chat/Act). The real engine replaces
/// this body.
pub fn run_work_session(
    _objective: &str,
    _source_roots: &[vendored_goose::SourceRoot],
) -> Result<String, WorkError> {
    Err(WorkError::EngineNotWired)
}

/// FFI: the Work-seam status as JSON, for the Swift `WorkBackend` to read across the
/// UniFFI boundary. Honest — reports armed (the flag) + that the engine is not yet
/// wired. This is the first concrete UniFFI seam for the Goose Work extraction.
#[uniffi::export]
pub fn work_backend_status_json() -> String {
    format!(
        "{{\"armed\":{},\"engine_wired\":false,\"flag\":\"{}\"}}",
        is_armed(),
        WORK_GOOSE_FLAG
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn flag_parsing_is_honest() {
        assert!(flag_is_armed(Some("1")));
        assert!(flag_is_armed(Some(" On ")));
        assert!(flag_is_armed(Some("true")));
        assert!(!flag_is_armed(None));
        assert!(!flag_is_armed(Some("0")));
        assert!(!flag_is_armed(Some("")));
    }

    #[test]
    fn inert_seam_refuses_honestly_never_falls_back() {
        // No engine wired → honest EngineNotWired, NEVER a silent fallback to Chat/Act.
        let roots = [vendored_goose::SourceRoot::read_only(std::path::PathBuf::from("/tmp/ws"))];
        assert_eq!(
            run_work_session("do a thing", &roots),
            Err(WorkError::EngineNotWired)
        );
    }

    #[test]
    fn vendored_goose_source_root_is_usable() {
        // The first vendored block/goose type compiles + behaves (read_only → !writable).
        let root = vendored_goose::SourceRoot::read_only(std::path::PathBuf::from("/repo"));
        assert_eq!(root.path, std::path::PathBuf::from("/repo"));
        assert!(!root.writable);
        assert_eq!(GOOSE_VENDOR_LICENSE, "Apache-2.0");
        assert_eq!(GOOSE_VENDOR_SOURCE, "block/goose");
    }

    #[test]
    fn status_json_reports_engine_not_wired() {
        let json = work_backend_status_json();
        assert!(json.contains("\"engine_wired\":false"));
        assert!(json.contains(WORK_GOOSE_FLAG));
    }
}
