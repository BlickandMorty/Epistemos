//! Unified [`MutationEnvelope`] — the typed delivery vehicle for every
//! durable state change in Epistemos.
//!
//! T+4.8 of `docs/audits/deliberation/T+4_cognitive_artifact_spine_deliberation_20260427.md`.
//!
//! Resolves Drift Q1 from `docs/audits/T+1_RECONCILIATION_2026-04-27.md`
//! by satisfying BOTH:
//!
//!   - `MASTER_FUSION.md` §3.5 four-layer event hierarchy contract:
//!     14 fields including `id`, `run_id`, `sequence`, `caused_by_event_id`,
//!     `actor`, `approval_id`, `status`, `created_at_ms`, `committed_at_ms`,
//!     `op`, `sensitivity`, `reversibility`, `integrity_hash`, `schema_version`.
//!
//!   - `COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §9 query-fingerprint
//!     matching: `touched_artifacts`, `touched_blocks`, `relation_changes`
//!     plus six `affects_*` boolean fast-paths so a Swift query can
//!     decide in O(1) whether to refresh.
//!
//! The type ships in T+4.8 — but call-site rewiring (replacing
//! `NotificationCenter.default.post(name: .vaultChanged, ...)` style
//! invalidation with typed envelope delivery) is **deferred to T+13
//! master hardening** so this slice is purely additive.

use serde::{Deserialize, Serialize};

use crate::artifacts::ArtifactRef;

use super::types::{
    BlockRef, MutationActor, MutationStatus, RelationChange, Reversibility, Sensitivity, SourceOp,
};

/// One typed mutation delivered through the four-layer event hierarchy.
///
/// Wire-format is byte-equal to Swift's `MutationEnvelope` mirror at
/// `Epistemos/Models/MutationEnvelope.swift`. Field order matches the
/// Swift `CodingKeys`. Optional fields use
/// `#[serde(skip_serializing_if = "Option::is_none")]` so older
/// envelopes round-trip cleanly through newer readers.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MutationEnvelope {
    // -----------------------------------------------------------------
    // §3.5 four-layer event hierarchy contract (14 required fields).
    // -----------------------------------------------------------------
    /// Unique mutation id. Treated opaquely — the generation strategy
    /// (UUID v4 / v7 / ULID) is decided by the caller and matches the
    /// rest of the codebase's id convention.
    pub mutation_id: String,

    /// Optional run id when the mutation was triggered by an agent run.
    /// Matches the Raw Thoughts `manifest.json:run_id`.
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub run_id: Option<String>,

    /// Append-only ordering within the same run (or globally when
    /// `run_id` is `None`). Drives the BLAKE3 chain link computation.
    pub sequence: u64,

    /// Optional event id this mutation was caused by — used to thread
    /// a chain of derived mutations back to the originating user
    /// gesture or tool call.
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub caused_by_event_id: Option<String>,

    /// Initiator. See [`MutationActor`].
    pub actor: MutationActor,

    /// Optional approval id for approval-gated mutations (per the
    /// Approval modal flow). `None` for auto-approved mutations.
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub approval_id: Option<String>,

    /// Lifecycle status. See [`MutationStatus`].
    pub status: MutationStatus,

    /// Unix milliseconds at envelope creation.
    pub created_at_ms: i64,

    /// Unix milliseconds at commit. `None` for `Pending` / `Failed`
    /// envelopes; `Some` for `Committed` / `Reverted`.
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub committed_at_ms: Option<i64>,

    /// Categorical operation descriptor. See [`SourceOp`].
    pub op: SourceOp,

    /// Sensitivity bucket — drives redaction policy. See [`Sensitivity`].
    pub sensitivity: Sensitivity,

    /// Reversibility classification. See [`Reversibility`].
    pub reversibility: Reversibility,

    /// BLAKE3 chain link computed AFTER any secret redaction. Encoded
    /// as a 64-character lowercase hex string (32 bytes). Empty string
    /// is allowed only on a `Pending` envelope before the chain is
    /// closed.
    pub integrity_hash: String,

    /// Schema version. Bumped on every backwards-incompatible field
    /// change; readers MUST tolerate higher values by ignoring unknown
    /// fields.
    pub schema_version: u32,

    // -----------------------------------------------------------------
    // Implementation-plan addendum: query-fingerprint matching.
    // (Six `affects_*` flags + three `touched_*` lists let a Swift
    // consumer decide in O(1) whether the mutation invalidates its
    // cached view, without parsing `op` or scanning the whole graph.)
    // -----------------------------------------------------------------
    /// Artifacts whose content/metadata is touched by this mutation.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub touched_artifacts: Vec<ArtifactRef>,

    /// Blocks whose body changed (per Tiptap UniqueID block ids).
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub touched_blocks: Vec<BlockRef>,

    /// Graph edge deltas. See [`RelationChange`].
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub relation_changes: Vec<RelationChange>,

    /// Whether this mutation invalidates the per-artifact summary view.
    #[serde(default)]
    pub affects_summary: bool,

    /// Whether this mutation invalidates per-document outline views.
    #[serde(default)]
    pub affects_outline: bool,

    /// Whether this mutation invalidates backlink/wikilink projections.
    #[serde(default)]
    pub affects_backlinks: bool,

    /// Whether this mutation invalidates the FTS5 search projection
    /// (per T+4.4 `readable_blocks_fts`).
    #[serde(default)]
    pub affects_search_projection: bool,

    /// Whether this mutation invalidates the Metal graph render state.
    #[serde(default)]
    pub affects_graph: bool,

    /// Whether this mutation changed the canonical body of an artifact
    /// (vs. metadata-only tweak).
    #[serde(default)]
    pub affects_body: bool,
}

impl MutationEnvelope {
    /// Current schema version. Bump on every backwards-incompatible
    /// field change AND simultaneously update the Swift mirror at
    /// `Epistemos/Models/MutationEnvelope.swift`.
    pub const CURRENT_SCHEMA_VERSION: u32 = 1;

    /// Construct a `Pending` envelope with all required fields and
    /// reasonable defaults for the optional ones. Caller is expected
    /// to populate `touched_*` and `affects_*` based on the operation.
    pub fn pending(
        mutation_id: String,
        sequence: u64,
        actor: MutationActor,
        op: SourceOp,
        sensitivity: Sensitivity,
        reversibility: Reversibility,
        created_at_ms: i64,
    ) -> Self {
        Self {
            mutation_id,
            run_id: None,
            sequence,
            caused_by_event_id: None,
            actor,
            approval_id: None,
            status: MutationStatus::Pending,
            created_at_ms,
            committed_at_ms: None,
            op,
            sensitivity,
            reversibility,
            integrity_hash: String::new(),
            schema_version: Self::CURRENT_SCHEMA_VERSION,
            touched_artifacts: Vec::new(),
            touched_blocks: Vec::new(),
            relation_changes: Vec::new(),
            affects_summary: false,
            affects_outline: false,
            affects_backlinks: false,
            affects_search_projection: false,
            affects_graph: false,
            affects_body: false,
        }
    }

    /// True if any of the `affects_*` flags is set. A cheap pre-check
    /// for downstream consumers deciding whether to look closer at
    /// the envelope.
    pub fn affects_anything(&self) -> bool {
        self.affects_summary
            || self.affects_outline
            || self.affects_backlinks
            || self.affects_search_projection
            || self.affects_graph
            || self.affects_body
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fixture() -> MutationEnvelope {
        MutationEnvelope::pending(
            "mut-2026-04-27-001".to_string(),
            42,
            MutationActor::User,
            SourceOp::ArtifactUpdate {
                artifact_id: "doc-1".to_string(),
            },
            Sensitivity::Internal,
            Reversibility::Reversible,
            1_745_788_800_000,
        )
    }

    #[test]
    fn pending_envelope_has_canonical_defaults() {
        let e = fixture();
        assert_eq!(e.status, MutationStatus::Pending);
        assert_eq!(e.run_id, None);
        assert_eq!(e.committed_at_ms, None);
        assert_eq!(e.integrity_hash, "");
        assert_eq!(e.schema_version, MutationEnvelope::CURRENT_SCHEMA_VERSION);
        assert!(e.touched_artifacts.is_empty());
        assert!(!e.affects_anything());
    }

    #[test]
    fn round_trips_through_json() {
        let e = fixture();
        let json = serde_json::to_string(&e).expect("serialize");
        let recovered: MutationEnvelope = serde_json::from_str(&json).expect("deserialize");
        assert_eq!(e, recovered, "JSON round-trip must be identity");
    }

    #[test]
    fn schema_version_constant_is_one() {
        // Pre-cutoff: Swift mirror also ships `1`. Bump as a 4-step
        // ritual: Rust constant + Swift constant + parity test +
        // implementation plan §9 doc.
        assert_eq!(MutationEnvelope::CURRENT_SCHEMA_VERSION, 1);
    }

    #[test]
    fn wire_format_keys_match_doctrine_contract() {
        // Parity guard: the 14 required §3.5 fields plus the 9
        // implementation-plan-addendum fields MUST be present on the
        // wire when populated. Optional fields skip when empty so old
        // envelopes round-trip cleanly.
        let e = fixture();
        let v: serde_json::Value = serde_json::to_value(&e).expect("serialize to value");
        let obj = v.as_object().expect("envelope is a JSON object");

        // §3.5 required fields — actor / op are objects, the rest are scalars.
        let required = [
            "mutation_id",
            "sequence",
            "actor",
            "status",
            "created_at_ms",
            "op",
            "sensitivity",
            "reversibility",
            "integrity_hash",
            "schema_version",
        ];
        for key in required {
            assert!(
                obj.contains_key(key),
                "MutationEnvelope wire format missing required §3.5 field `{key}`. Found keys: {:?}",
                obj.keys().collect::<Vec<_>>()
            );
        }

        // Optional fields that skip when None must be ABSENT in the
        // pending fixture (no run_id, no caused_by_event_id, no
        // approval_id, no committed_at_ms, no touched_*).
        for absent in [
            "run_id",
            "caused_by_event_id",
            "approval_id",
            "committed_at_ms",
            "touched_artifacts",
            "touched_blocks",
            "relation_changes",
        ] {
            assert!(
                !obj.contains_key(absent),
                "Optional field `{absent}` should skip serialization on the pending fixture, but appeared in the JSON object. Drift could break legacy envelope readers."
            );
        }
    }

    #[test]
    fn affects_anything_reports_set_flags() {
        let mut e = fixture();
        assert!(!e.affects_anything());
        e.affects_search_projection = true;
        assert!(e.affects_anything());
    }

    #[test]
    fn touched_blocks_serialize_when_populated() {
        let mut e = fixture();
        e.touched_blocks.push(BlockRef::new("doc-1", "block-abc"));
        let json = serde_json::to_string(&e).expect("serialize");
        assert!(
            json.contains(r#""touched_blocks":[{"artifact_id":"doc-1","block_id":"block-abc"}]"#),
            "touched_blocks must serialize with snake_case keys; got {json}"
        );
        let recovered: MutationEnvelope = serde_json::from_str(&json).expect("deserialize");
        assert_eq!(recovered, e);
    }

    #[test]
    fn agent_run_envelope_carries_run_id() {
        let mut e = fixture();
        e.actor = MutationActor::Agent {
            run_id: "run-99".to_string(),
        };
        e.run_id = Some("run-99".to_string());
        let json = serde_json::to_string(&e).expect("serialize");
        assert!(json.contains(r#""run_id":"run-99""#));
        assert!(json.contains(r#""kind":"agent""#));
    }
}
