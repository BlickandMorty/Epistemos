//! Supporting types for [`super::MutationEnvelope`].
//!
//! T+4.8 of `docs/audits/deliberation/T+4_cognitive_artifact_spine_deliberation_20260427.md`
//! (cross-ref `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §9 +
//! `docs/_consolidated/00_canonical_authority/MASTER_FUSION.md` §3.5).
//!
//! Each type here is a small leaf used by the envelope. Wire-format is
//! lower-snake-case JSON; Swift mirrors live in
//! `Epistemos/Models/MutationEnvelope.swift`.

use serde::{Deserialize, Serialize};

// ---------------------------------------------------------------------------
// MutationStatus
// ---------------------------------------------------------------------------

/// Lifecycle state of a mutation. Matches MASTER_FUSION §3.5's required
/// `status` field on the durable envelope (pending → committed → failed
/// → reverted).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MutationStatus {
    /// Created but not yet applied. Most envelopes start here.
    Pending,
    /// Applied successfully and durably persisted.
    Committed,
    /// Attempted but failed; the envelope records the failure for audit.
    Failed,
    /// Previously committed, now undone via a reverting mutation.
    Reverted,
}

// ---------------------------------------------------------------------------
// MutationActor
// ---------------------------------------------------------------------------

/// Who or what initiated the mutation. Mirrors the §3.5 `actor` field.
///
/// Wire format uses an internally-tagged enum (`{"kind": "agent", "run_id": "..."}`)
/// so adding new actor kinds doesn't require a wrapping struct change.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case", tag = "kind")]
pub enum MutationActor {
    /// A human user via UI gesture (typing, button press, drag).
    User,
    /// An agent run with a specific run id.
    Agent {
        /// Run id matching the Raw Thoughts `manifest.json:run_id`.
        run_id: String,
    },
    /// The app or runtime itself — background tasks, migrations, GC.
    System,
}

// ---------------------------------------------------------------------------
// Sensitivity
// ---------------------------------------------------------------------------

/// Coarse sensitivity bucket. Drives redaction policy (which fields get
/// scrubbed before BLAKE3 hashing in the integrity chain), retention
/// policy, and export gating. Mirrors the §3.5 `sensitivity` field.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Sensitivity {
    /// Default — the user's notes, settings, normal app state.
    Internal,
    /// Contains user-secret material (API keys, OAuth tokens, passwords).
    /// Must be redacted in event logs and BEFORE the integrity hash is
    /// computed (per MASTER_FUSION §3.5).
    Secret,
    /// Public-by-design (a shared link payload, public export).
    Public,
}

// ---------------------------------------------------------------------------
// Reversibility
// ---------------------------------------------------------------------------

/// How recoverable is this mutation. Mirrors the §3.5 `reversibility`
/// field. Used by the approval modal to inform the user before they
/// authorize an irreversible action.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Reversibility {
    /// Can be undone via the inverse mutation (most local edits).
    Reversible,
    /// External effect with no automatic undo (cloud post, file delete
    /// without backup, terminal command).
    Irreversible,
    /// Has a defined compensating mutation but isn't a pure undo
    /// (e.g. a refund for a charge).
    Compensable,
}

// ---------------------------------------------------------------------------
// BlockRef
// ---------------------------------------------------------------------------

/// Stable pointer to a content block within an artifact. Used by
/// [`super::MutationEnvelope::touched_blocks`] for query-fingerprint
/// matching at the block-level granularity required by Halo + Concept
/// Door surfaces.
///
/// Block IDs are produced by the Tiptap UniqueID extension (T+4.6) and
/// stay stable across edit / split / merge / undo / redo.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct BlockRef {
    /// Owning artifact id.
    pub artifact_id: String,
    /// Stable block id within the artifact.
    pub block_id: String,
}

impl BlockRef {
    pub fn new<A: Into<String>, B: Into<String>>(artifact_id: A, block_id: B) -> Self {
        Self {
            artifact_id: artifact_id.into(),
            block_id: block_id.into(),
        }
    }
}

// ---------------------------------------------------------------------------
// SourceOp
// ---------------------------------------------------------------------------

/// Categorical descriptor of WHAT the mutation does. Higher-level than
/// the `oplog::OpPayload` (which is graph-mutation only); SourceOp lets
/// the envelope cover artifact-level operations as well.
///
/// Wire format is internally-tagged (`{"kind": "artifact_create", ...}`).
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case", tag = "kind")]
pub enum SourceOp {
    /// Pure graph node/edge mutation. Detail lives in the OpLog
    /// `OpPayload` (oplog.rs:71); the envelope just records that one
    /// happened so downstream consumers can refresh.
    GraphMutation,
    /// New artifact created.
    ArtifactCreate {
        artifact_id: String,
        /// `ArtifactKind::as_str()` value (lower-snake-case). Named
        /// `artifact_kind` to avoid colliding with the enum's internal
        /// `tag = "kind"` discriminator.
        artifact_kind: String,
    },
    /// Existing artifact body or metadata updated.
    ArtifactUpdate { artifact_id: String },
    /// Artifact removed from the workspace.
    ArtifactDelete { artifact_id: String },
    /// Escape hatch for not-yet-categorized mutations. Should be
    /// replaced with a typed variant before T+13 hardening lands.
    Other { label: String },
}

// ---------------------------------------------------------------------------
// RelationChange
// ---------------------------------------------------------------------------

/// One delta to the artifact-relationship graph. Kept structured so
/// [`super::MutationEnvelope`] can carry a list of edge changes that
/// downstream consumers (the Metal graph renderer, the search index)
/// can apply incrementally without scanning the whole graph.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case", tag = "op")]
pub enum RelationChange {
    /// New edge from `from_id` → `to_id` with `label`.
    Added {
        from_id: String,
        to_id: String,
        label: String,
    },
    /// Edge removed.
    Removed {
        from_id: String,
        to_id: String,
        label: String,
    },
    /// Edge label changed (semantically: removed-then-added, but
    /// expressed as a single delta so consumers can animate the
    /// transition).
    Updated {
        from_id: String,
        to_id: String,
        old_label: String,
        new_label: String,
    },
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mutation_status_round_trips_snake_case() {
        for variant in [
            MutationStatus::Pending,
            MutationStatus::Committed,
            MutationStatus::Failed,
            MutationStatus::Reverted,
        ] {
            let json = serde_json::to_string(&variant).expect("serialize");
            let recovered: MutationStatus = serde_json::from_str(&json).expect("deserialize");
            assert_eq!(recovered, variant);
        }
        // Wire-format guard.
        assert_eq!(
            serde_json::to_string(&MutationStatus::Pending).unwrap(),
            "\"pending\""
        );
        assert_eq!(
            serde_json::to_string(&MutationStatus::Committed).unwrap(),
            "\"committed\""
        );
        assert_eq!(
            serde_json::to_string(&MutationStatus::Failed).unwrap(),
            "\"failed\""
        );
        assert_eq!(
            serde_json::to_string(&MutationStatus::Reverted).unwrap(),
            "\"reverted\""
        );
    }

    #[test]
    fn mutation_actor_user_serializes_kind_only() {
        let a = MutationActor::User;
        assert_eq!(serde_json::to_string(&a).unwrap(), r#"{"kind":"user"}"#);
    }

    #[test]
    fn mutation_actor_agent_carries_run_id() {
        let a = MutationActor::Agent {
            run_id: "run-2026-04-27".to_string(),
        };
        let json = serde_json::to_string(&a).unwrap();
        assert!(json.contains(r#""kind":"agent""#));
        assert!(json.contains(r#""run_id":"run-2026-04-27""#));
        let recovered: MutationActor = serde_json::from_str(&json).unwrap();
        assert_eq!(recovered, a);
    }

    #[test]
    fn sensitivity_round_trips() {
        for variant in [
            Sensitivity::Internal,
            Sensitivity::Secret,
            Sensitivity::Public,
        ] {
            let json = serde_json::to_string(&variant).expect("serialize");
            let recovered: Sensitivity = serde_json::from_str(&json).expect("deserialize");
            assert_eq!(recovered, variant);
        }
    }

    #[test]
    fn reversibility_round_trips() {
        for variant in [
            Reversibility::Reversible,
            Reversibility::Irreversible,
            Reversibility::Compensable,
        ] {
            let json = serde_json::to_string(&variant).expect("serialize");
            let recovered: Reversibility = serde_json::from_str(&json).expect("deserialize");
            assert_eq!(recovered, variant);
        }
    }

    #[test]
    fn block_ref_round_trips() {
        let r = BlockRef::new("artifact-1", "block-abc");
        let json = serde_json::to_string(&r).unwrap();
        let recovered: BlockRef = serde_json::from_str(&json).unwrap();
        assert_eq!(r, recovered);
        // Wire keys MUST be snake_case so Swift mirror matches.
        assert!(json.contains(r#""artifact_id":"artifact-1""#));
        assert!(json.contains(r#""block_id":"block-abc""#));
    }

    #[test]
    fn source_op_artifact_create_serializes_with_kind_tag() {
        let op = SourceOp::ArtifactCreate {
            artifact_id: "doc-1".to_string(),
            artifact_kind: "document".to_string(),
        };
        let json = serde_json::to_string(&op).unwrap();
        assert!(json.contains(r#""kind":"artifact_create""#));
        assert!(json.contains(r#""artifact_id":"doc-1""#));
        assert!(json.contains(r#""artifact_kind":"document""#));
        let recovered: SourceOp = serde_json::from_str(&json).unwrap();
        assert_eq!(recovered, op);
    }

    #[test]
    fn relation_change_round_trips() {
        let c = RelationChange::Added {
            from_id: "a".to_string(),
            to_id: "b".to_string(),
            label: "cites".to_string(),
        };
        let json = serde_json::to_string(&c).unwrap();
        assert!(json.contains(r#""op":"added""#));
        let recovered: RelationChange = serde_json::from_str(&json).unwrap();
        assert_eq!(recovered, c);
    }
}
