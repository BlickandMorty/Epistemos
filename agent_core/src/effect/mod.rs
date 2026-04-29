//! Plan §8 — Intent-to-Effect state pattern.
//!
//! The LLM emits an `Intent`. The runtime applies it and emits an
//! `Effect`. Swift observes the resulting `Effect` via UniFFI async
//! stream and re-renders.
//!
//! This module provides:
//! - `Effect` — what the runtime emits after applying an Intent.
//! - `ApplyError` — typed failure surface; feeds the heal loop (§5.2).
//! - `Inverse` — pre-computed reverse Effect, persisted alongside the
//!   Effect for `⌘Z` universal undo (§8.5).
//! - `IntentApplier` — trait for the concrete vault/concept/memory
//!   appliers; impls land in their respective subsystems.
//!
//! Per FINAL_SYNTHESIS §2 layer 6 (memory): every Effect persisted
//! with provenance, hash, signed receipt. The signing path lands in
//! Wave 5 stabilize alongside the Ed25519 ExecutionReceipt for
//! heal_events.sqlite (D1 TODO from CATCHUP).

use serde::{Deserialize, Serialize};
use thiserror::Error;

use crate::format::intent::Intent;

pub mod concept_applier;
pub mod dispatcher;
pub mod memory_applier;
pub mod vault_applier;
pub use concept_applier::ConceptGraphApplier;
pub use dispatcher::IntentDispatcher;
pub use memory_applier::MemoryApplier;
pub use vault_applier::VaultIntentApplier;

/// What the runtime emits after applying an Intent. Mirrors `Intent`'s
/// shape but carries the post-apply state (timestamps, content hashes,
/// resolved paths) that Swift renders.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum Effect {
    /// `vault.write` succeeded; resolved path + content hash so Swift
    /// can deduplicate observations and the undo log can verify the
    /// inverse against the actual on-disk state.
    VaultWrote {
        path: String,
        body_sha256: String,
        bytes_written: u64,
    },

    /// `vault.move` succeeded.
    VaultMoved { from: String, to: String },

    /// `vault.delete` soft-deleted the file (24h shadow copy is alive).
    /// `shadow_path` is the location of the shadow copy; the inverse
    /// (restore) reads it back.
    VaultDeleted {
        path: String,
        shadow_path: String,
    },

    /// `concept.create` registered a new canonical name.
    ConceptCreated {
        canonical_name: String,
    },

    /// `concept.alias` linked an alias to a canonical name.
    ConceptAliased {
        canonical_name: String,
        alias: String,
    },

    /// `memory.write` appended an entry; `entry_id` is the ULID for
    /// undo (which tombstones by id).
    MemoryWrote {
        entry_id: String,
    },

    /// `noop` — no state change; recorded for trace completeness.
    NoopApplied { reason: String },

    /// `abort` — the heal loop chose to stop; recorded for trace.
    Aborted { reason: String },

    /// User-driven `Effect::Reverse` against an undo entry. Carries
    /// the original `effect_id` so the trace can render the chain.
    Reversed { original_effect_id: String },
}

impl Effect {
    /// Compute the inverse Effect at apply-time per §8.5: "The inverse
    /// is computed at intent-apply time, not at undo time — this
    /// guarantees undo always works even if the world has moved on
    /// (e.g. the file was deleted by the user)."
    ///
    /// `prior_state` carries the pre-apply state the inverse needs:
    /// for `vault.write` overwriting an existing file, the prior
    /// content hash + body so we can restore. For a fresh write,
    /// `None` and the inverse is a delete.
    pub fn compute_inverse(&self, prior_state: Option<&PriorState>) -> Inverse {
        match self {
            Effect::VaultWrote { path, .. } => match prior_state {
                Some(PriorState::WroteOverExisting { body_before, .. }) => {
                    Inverse::RestoreVaultContent {
                        path: path.clone(),
                        body: body_before.clone(),
                    }
                }
                _ => Inverse::DeleteVault { path: path.clone() },
            },
            Effect::VaultMoved { from, to } => Inverse::MoveVault {
                from: to.clone(),
                to: from.clone(),
            },
            Effect::VaultDeleted { path, shadow_path } => Inverse::RestoreVaultFromShadow {
                path: path.clone(),
                shadow_path: shadow_path.clone(),
            },
            Effect::ConceptCreated { canonical_name } => Inverse::RetractConcept {
                canonical_name: canonical_name.clone(),
            },
            Effect::ConceptAliased {
                canonical_name,
                alias,
            } => Inverse::RemoveConceptAlias {
                canonical_name: canonical_name.clone(),
                alias: alias.clone(),
            },
            Effect::MemoryWrote { entry_id } => Inverse::TombstoneMemory {
                entry_id: entry_id.clone(),
            },
            // Noop / Abort / Reversed are themselves no-op inverses;
            // ⌘Z over them is a no-op (recorded as such in the trace).
            Effect::NoopApplied { .. }
            | Effect::Aborted { .. }
            | Effect::Reversed { .. } => Inverse::NotReversible,
        }
    }
}

/// Optional pre-apply state captured at intent-apply time so the
/// inverse can restore exactly what was overwritten.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub enum PriorState {
    /// The vault.write overwrote an existing file; the body that was
    /// there before is captured here verbatim so restoration is exact.
    WroteOverExisting {
        body_before: String,
        body_before_sha256: String,
    },
    /// The concept already existed when create was called; the inverse
    /// should leave it alone (idempotent restore).
    ConceptAlreadyExisted,
}

/// Pre-computed reverse Effect persisted in `undo_events.inverse`.
/// Per §8.5: applies even when the world has moved on. Each variant
/// is fully self-contained — no foreign-key lookups at undo time.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(tag = "inverse", rename_all = "snake_case")]
pub enum Inverse {
    DeleteVault { path: String },
    RestoreVaultContent { path: String, body: String },
    MoveVault { from: String, to: String },
    RestoreVaultFromShadow { path: String, shadow_path: String },
    RetractConcept { canonical_name: String },
    RemoveConceptAlias { canonical_name: String, alias: String },
    TombstoneMemory { entry_id: String },
    /// Noop / Abort / Reversed effects produce this — ⌘Z over them
    /// records the attempt in the trace and surfaces a "nothing to
    /// undo here" toast in the UI.
    NotReversible,
}

impl Inverse {
    /// Plan §8.5 reversibility classification: which Intent variants
    /// produce undoable effects, which need shadow-copy restore, and
    /// which are forbidden from undo entirely (`action.shell` Pro-only).
    pub fn is_reversible(&self) -> bool {
        !matches!(self, Inverse::NotReversible)
    }
}

/// Typed failure surface from `IntentApplier::apply`. The heal loop
/// (§5.2) reads `kind` to decide whether to retry, ask the
/// Diagnostician for a corrected Intent, or give up.
#[derive(Serialize, Deserialize, Clone, Debug, Error, PartialEq)]
#[serde(tag = "kind", content = "context", rename_all = "snake_case")]
pub enum ApplyError {
    /// Path traversal, missing required field, schema violation.
    #[error("invalid intent: {0}")]
    InvalidIntent(String),

    /// Filesystem / database error.
    #[error("io error: {0}")]
    IoError(String),

    /// Vault-policy refusal (e.g. write outside allowed paths).
    #[error("permission denied: {0}")]
    PermissionDenied(String),

    /// Concept already exists / alias already linked / memory entry
    /// already present at id. Idempotent re-apply errors.
    #[error("conflict: {0}")]
    Conflict(String),

    /// Intent is unrecoverable from the heal loop; the loop returns
    /// the original error to the caller without further retries.
    #[error("permanent failure: {0}")]
    Permanent(String),
}

/// Concrete appliers (vault, concept graph, memory) implement this to
/// turn an `Intent` into an applied `Effect` + the `PriorState` needed
/// to compute the inverse.
#[async_trait::async_trait]
pub trait IntentApplier: Send + Sync {
    /// Apply the Intent. On success, return the resulting Effect plus
    /// any pre-apply state the undo log needs to compute the inverse.
    async fn apply(
        &self,
        intent: Intent,
    ) -> Result<(Effect, Option<PriorState>), ApplyError>;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn vault_wrote_inverse_is_delete_when_no_prior() {
        let effect = Effect::VaultWrote {
            path: "notes/a.md".to_string(),
            body_sha256: "deadbeef".to_string(),
            bytes_written: 4,
        };
        match effect.compute_inverse(None) {
            Inverse::DeleteVault { path } => assert_eq!(path, "notes/a.md"),
            other => panic!("expected DeleteVault inverse, got {other:?}"),
        }
    }

    #[test]
    fn vault_wrote_inverse_is_restore_when_overwrote_existing() {
        let effect = Effect::VaultWrote {
            path: "notes/a.md".to_string(),
            body_sha256: "deadbeef".to_string(),
            bytes_written: 4,
        };
        let prior = PriorState::WroteOverExisting {
            body_before: "old content".to_string(),
            body_before_sha256: "abcd".to_string(),
        };
        match effect.compute_inverse(Some(&prior)) {
            Inverse::RestoreVaultContent { path, body } => {
                assert_eq!(path, "notes/a.md");
                assert_eq!(body, "old content");
            }
            other => panic!("expected RestoreVaultContent inverse, got {other:?}"),
        }
    }

    #[test]
    fn vault_move_inverse_swaps_from_and_to() {
        let effect = Effect::VaultMoved {
            from: "a.md".to_string(),
            to: "b.md".to_string(),
        };
        match effect.compute_inverse(None) {
            Inverse::MoveVault { from, to } => {
                assert_eq!(from, "b.md");
                assert_eq!(to, "a.md");
            }
            other => panic!("expected MoveVault inverse, got {other:?}"),
        }
    }

    #[test]
    fn vault_delete_inverse_uses_shadow_copy() {
        let effect = Effect::VaultDeleted {
            path: "notes/old.md".to_string(),
            shadow_path: ".epistemos/shadows/2026-04/old.md".to_string(),
        };
        assert!(matches!(
            effect.compute_inverse(None),
            Inverse::RestoreVaultFromShadow { .. }
        ));
    }

    #[test]
    fn concept_aliased_inverse_removes_alias() {
        let effect = Effect::ConceptAliased {
            canonical_name: "gradient-checkpointing".to_string(),
            alias: "rematerialization".to_string(),
        };
        match effect.compute_inverse(None) {
            Inverse::RemoveConceptAlias {
                canonical_name,
                alias,
            } => {
                assert_eq!(canonical_name, "gradient-checkpointing");
                assert_eq!(alias, "rematerialization");
            }
            other => panic!("expected RemoveConceptAlias inverse, got {other:?}"),
        }
    }

    #[test]
    fn memory_wrote_inverse_tombstones_by_entry_id() {
        let effect = Effect::MemoryWrote {
            entry_id: "01HX42KQM3R7N9PVK0X8Z3W5MQ".to_string(),
        };
        match effect.compute_inverse(None) {
            Inverse::TombstoneMemory { entry_id } => {
                assert_eq!(entry_id, "01HX42KQM3R7N9PVK0X8Z3W5MQ");
            }
            other => panic!("expected TombstoneMemory inverse, got {other:?}"),
        }
    }

    #[test]
    fn noop_and_abort_and_reversed_are_not_reversible() {
        let cases = [
            Effect::NoopApplied {
                reason: "x".into(),
            },
            Effect::Aborted {
                reason: "y".into(),
            },
            Effect::Reversed {
                original_effect_id: "z".into(),
            },
        ];
        for effect in &cases {
            assert_eq!(effect.compute_inverse(None), Inverse::NotReversible);
            assert!(!effect.compute_inverse(None).is_reversible());
        }
    }

    #[test]
    fn inverse_round_trips_through_json() {
        let inverses = [
            Inverse::DeleteVault {
                path: "x.md".into(),
            },
            Inverse::RestoreVaultContent {
                path: "x.md".into(),
                body: "abc".into(),
            },
            Inverse::MoveVault {
                from: "a".into(),
                to: "b".into(),
            },
            Inverse::RestoreVaultFromShadow {
                path: "x.md".into(),
                shadow_path: ".shadow/x.md".into(),
            },
            Inverse::RetractConcept {
                canonical_name: "k".into(),
            },
            Inverse::RemoveConceptAlias {
                canonical_name: "k".into(),
                alias: "a".into(),
            },
            Inverse::TombstoneMemory {
                entry_id: "01HX42KQM3R7N9PVK0X8Z3W5MQ".into(),
            },
            Inverse::NotReversible,
        ];
        for inv in &inverses {
            let s = serde_json::to_string(inv).expect("serialize");
            let p: Inverse = serde_json::from_str(&s).expect("deserialize");
            assert_eq!(&p, inv);
        }
    }

    #[test]
    fn apply_error_carries_kind_discriminator_in_json() {
        let err = ApplyError::PermissionDenied("path outside allowed".into());
        let s = serde_json::to_string(&err).expect("serialize");
        assert!(s.contains("permission_denied"));
        let p: ApplyError = serde_json::from_str(&s).expect("deserialize");
        assert_eq!(p, err);
    }
}
