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

    /// Vendored block/goose permission types (Goose S3) — the engine's permission
    /// posture for a tool/extension call. A self-contained (serde-only) leaf, the next
    /// step inward from `SourceRoot` per the leaf-first plan.
    pub mod permission {
        //! Provenance: github.com/block/goose (Apache-2.0),
        //! crates/goose-providers/src/permission.rs.
        //! `direct_import` with ONE documented adaptation: the upstream `#[derive(…,
        //! ToSchema)]` + `use utoipa::ToSchema;` are DROPPED — agent_core has no
        //! `utoipa`, and `ToSchema` is an OpenAPI-doc derive irrelevant to the Work
        //! seam. Every enum variant + struct field below is byte-for-byte upstream;
        //! the serde derives + `rename_all = "snake_case"` are preserved verbatim, so
        //! the wire form is identical to block/goose.

        // --- BEGIN VERBATIM (block/goose, Apache-2.0; ToSchema derive trimmed) ---
        use serde::{Deserialize, Serialize};

        #[derive(Debug, Serialize, Deserialize, Clone, PartialEq, Eq)]
        #[serde(rename_all = "snake_case")]
        pub enum Permission {
            AlwaysAllow,
            AllowOnce,
            Cancel,
            DenyOnce,
            AlwaysDeny,
        }

        #[derive(Debug, Serialize, Deserialize, Clone, PartialEq, Eq)]
        pub enum PrincipalType {
            Extension,
            Tool,
        }

        #[derive(Debug, Serialize, Deserialize, Clone, PartialEq, Eq)]
        pub struct PermissionConfirmation {
            pub principal_type: PrincipalType,
            pub permission: Permission,
        }
        // --- END VERBATIM ---
    }
}

/// First-party typed Work REQUEST (NOT vendored — the seam contract the Swift
/// `WorkBackend` hands across UniFFI). Carries the objective, the workspace roots the
/// engine operates on (the vendored block/goose `SourceRoot`), and the default
/// permission posture (the vendored block/goose `Permission`). The engine layer (S4+)
/// consumes this; until then `run_work_session` stays inert.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WorkRequest {
    pub objective: String,
    pub source_roots: Vec<vendored_goose::SourceRoot>,
    pub default_permission: vendored_goose::permission::Permission,
}

impl WorkRequest {
    /// A read-only request over the given roots with the safest default posture
    /// (`AllowOnce` — never `AlwaysAllow`; the engine asks per action).
    pub fn read_only(objective: impl Into<String>, roots: Vec<vendored_goose::SourceRoot>) -> Self {
        Self {
            objective: objective.into(),
            source_roots: roots,
            default_permission: vendored_goose::permission::Permission::AllowOnce,
        }
    }
}

/// First-party typed Work RESULT (NOT vendored) — what a completed Work session
/// returns: an honest summary + the files the engine touched.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WorkResult {
    pub summary: String,
    pub files_touched: Vec<std::path::PathBuf>,
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

/// The honest seam: run a Work session against the Goose engine for the given typed
/// `WorkRequest` (objective + the workspace roots it indexes / diffs + the default
/// permission posture — all real vendored/first-party types). Until the engine layer
/// is vendored, this is INERT — it returns `EngineNotWired` (NEVER a silent fallback
/// to Chat/Act). The real engine replaces this body and returns a `WorkResult`.
pub fn run_work_session(_request: &WorkRequest) -> Result<WorkResult, WorkError> {
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
        let req = WorkRequest::read_only(
            "do a thing",
            vec![vendored_goose::SourceRoot::read_only(std::path::PathBuf::from("/tmp/ws"))],
        );
        assert_eq!(run_work_session(&req), Err(WorkError::EngineNotWired));
    }

    #[test]
    fn vendored_permission_matches_upstream_variants_and_wire_form() {
        use vendored_goose::permission::{Permission, PermissionConfirmation, PrincipalType};
        // All five upstream Permission variants present (byte-for-byte vendor).
        let all = [
            Permission::AlwaysAllow,
            Permission::AllowOnce,
            Permission::Cancel,
            Permission::DenyOnce,
            Permission::AlwaysDeny,
        ];
        assert_eq!(all.len(), 5);
        // serde snake_case wire form is byte-identical to upstream (the derive is preserved).
        assert_eq!(
            serde_json::to_string(&Permission::AlwaysAllow).unwrap(),
            "\"always_allow\""
        );
        assert_eq!(
            serde_json::to_string(&Permission::AllowOnce).unwrap(),
            "\"allow_once\""
        );
        assert_eq!(
            serde_json::to_string(&Permission::DenyOnce).unwrap(),
            "\"deny_once\""
        );
        // PermissionConfirmation round-trips through serde unchanged.
        let conf = PermissionConfirmation {
            principal_type: PrincipalType::Tool,
            permission: Permission::DenyOnce,
        };
        let json = serde_json::to_string(&conf).unwrap();
        let back: PermissionConfirmation = serde_json::from_str(&json).unwrap();
        assert_eq!(back, conf);
    }

    #[test]
    fn work_request_default_posture_is_never_always_allow() {
        // The first-party request defaults to the SAFEST posture — the engine asks per
        // action; it never silently grants AlwaysAllow.
        let req = WorkRequest::read_only("x", vec![]);
        assert_eq!(
            req.default_permission,
            vendored_goose::permission::Permission::AllowOnce
        );
        assert_ne!(
            req.default_permission,
            vendored_goose::permission::Permission::AlwaysAllow
        );
        assert_eq!(req.objective, "x");
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
