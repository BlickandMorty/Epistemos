//! Plan §8 — concrete `IntentApplier` for the concept graph.
//!
//! Handles `Intent::ConceptCreate` and `Intent::ConceptAlias`.
//! Concepts live as `.alias.json` files under
//! `<vault>/.epistemos/concepts/<canonical>.alias.json` per the
//! existing `AliasTable` shape from Phase 3D-2.
//!
//! Reversibility per §8.5:
//!   - concept.create → reverse: tombstone (the alias.json file)
//!   - concept.alias  → reverse: remove the alias entry
//!
//! Both inverses are computed from the Effect alone — no PriorState
//! needed because the alias-table file is the source of truth (the
//! `aliases[]` array stores everything inline; removing the last
//! entry by name is sufficient).

use std::path::PathBuf;

use async_trait::async_trait;
use chrono::Utc;

use crate::canon::alias::{AliasEntry, AliasProvenance, AliasTable};
use crate::effect::{ApplyError, Effect, IntentApplier, PriorState};
use crate::format::intent::Intent;
use crate::format::FormatError;

const CONCEPTS_DIR: &str = ".epistemos/concepts";

pub struct ConceptGraphApplier {
    concepts_dir: PathBuf,
}

impl ConceptGraphApplier {
    /// Pass the vault root; concepts live under `<vault>/.epistemos/concepts/`.
    pub fn new(vault_root: impl Into<PathBuf>) -> Self {
        let concepts_dir = vault_root.into().join(CONCEPTS_DIR);
        Self { concepts_dir }
    }

    fn ensure_dir(&self) -> Result<(), ApplyError> {
        std::fs::create_dir_all(&self.concepts_dir)
            .map_err(|e| ApplyError::IoError(e.to_string()))
    }
}

#[async_trait]
impl IntentApplier for ConceptGraphApplier {
    async fn apply(
        &self,
        intent: Intent,
    ) -> Result<(Effect, Option<PriorState>), ApplyError> {
        self.ensure_dir()?;
        match intent {
            Intent::ConceptCreate {
                canonical_name,
                definition,
            } => {
                let path = AliasTable::path_for(&self.concepts_dir, &canonical_name);
                if path.exists() {
                    return Err(ApplyError::Conflict(format!(
                        "concept '{canonical_name}' already exists"
                    )));
                }
                let mut table = AliasTable::fresh(canonical_name.clone());
                if !definition.trim().is_empty() {
                    table.definition = Some(definition);
                }
                table.last_modified = Some(Utc::now());
                table.save(&path).map_err(map_format_err)?;
                Ok((Effect::ConceptCreated { canonical_name }, None))
            }

            Intent::ConceptAlias {
                canonical_name,
                alias,
            } => {
                let path = AliasTable::path_for(&self.concepts_dir, &canonical_name);
                let mut table = if path.exists() {
                    AliasTable::load(&path).map_err(map_format_err)?
                } else {
                    AliasTable::fresh(canonical_name.clone())
                };
                let alias_clone = alias.clone();
                table.append_alias(AliasEntry {
                    name: alias,
                    added_at: Utc::now(),
                    via: AliasProvenance::ManualSeed,
                    confidence: None,
                });
                table.save(&path).map_err(map_format_err)?;
                Ok((
                    Effect::ConceptAliased {
                        canonical_name,
                        alias: alias_clone,
                    },
                    None,
                ))
            }

            other => Err(ApplyError::Permanent(format!(
                "ConceptGraphApplier doesn't handle {other:?} — wrong applier"
            ))),
        }
    }
}

fn map_format_err(e: FormatError) -> ApplyError {
    ApplyError::IoError(format!("alias-table format: {e}"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::effect::Inverse;
    use tempfile::TempDir;

    fn fresh_applier() -> (TempDir, ConceptGraphApplier) {
        let tmp = TempDir::new().expect("tempdir");
        let applier = ConceptGraphApplier::new(tmp.path());
        (tmp, applier)
    }

    #[tokio::test]
    async fn concept_create_writes_alias_table_with_definition() {
        let (tmp, applier) = fresh_applier();
        let (effect, prior) = applier
            .apply(Intent::ConceptCreate {
                canonical_name: "checkpoint-gradient".into(),
                definition: "recompute forward to save memory".into(),
            })
            .await
            .expect("apply");
        assert!(prior.is_none());
        match effect {
            Effect::ConceptCreated { canonical_name } => {
                assert_eq!(canonical_name, "checkpoint-gradient");
            }
            other => panic!("expected ConceptCreated, got {other:?}"),
        }
        // The .alias.json file lives where AliasTable::path_for says.
        let path = AliasTable::path_for(
            &tmp.path().join(CONCEPTS_DIR),
            "checkpoint-gradient",
        );
        assert!(path.is_file(), "concept file must exist on disk");
        let table = AliasTable::load(&path).unwrap();
        assert_eq!(table.canonical_name, "checkpoint-gradient");
        assert_eq!(
            table.definition.as_deref(),
            Some("recompute forward to save memory")
        );
    }

    #[tokio::test]
    async fn concept_create_rejects_existing_concept() {
        let (_tmp, applier) = fresh_applier();
        applier
            .apply(Intent::ConceptCreate {
                canonical_name: "x".into(),
                definition: "first".into(),
            })
            .await
            .unwrap();
        let err = applier
            .apply(Intent::ConceptCreate {
                canonical_name: "x".into(),
                definition: "second".into(),
            })
            .await
            .unwrap_err();
        assert!(matches!(err, ApplyError::Conflict(_)));
    }

    #[tokio::test]
    async fn concept_alias_appends_to_existing_table_and_creates_if_absent() {
        let (tmp, applier) = fresh_applier();
        // Start without a concept file — the alias intent creates it.
        let (effect, _) = applier
            .apply(Intent::ConceptAlias {
                canonical_name: "checkpoint-gradient".into(),
                alias: "rematerialization".into(),
            })
            .await
            .expect("apply");
        match effect {
            Effect::ConceptAliased {
                canonical_name,
                alias,
            } => {
                assert_eq!(canonical_name, "checkpoint-gradient");
                assert_eq!(alias, "rematerialization");
            }
            other => panic!("expected ConceptAliased, got {other:?}"),
        }
        let path = AliasTable::path_for(
            &tmp.path().join(CONCEPTS_DIR),
            "checkpoint-gradient",
        );
        let table = AliasTable::load(&path).unwrap();
        assert_eq!(table.aliases.len(), 1);
        assert_eq!(table.aliases[0].name, "rematerialization");
    }

    #[tokio::test]
    async fn concept_create_inverse_retracts() {
        let effect = Effect::ConceptCreated {
            canonical_name: "x".into(),
        };
        match effect.compute_inverse(None) {
            Inverse::RetractConcept { canonical_name } => {
                assert_eq!(canonical_name, "x");
            }
            other => panic!("expected RetractConcept, got {other:?}"),
        }
    }

    #[tokio::test]
    async fn concept_alias_inverse_removes_alias() {
        let effect = Effect::ConceptAliased {
            canonical_name: "x".into(),
            alias: "y".into(),
        };
        match effect.compute_inverse(None) {
            Inverse::RemoveConceptAlias {
                canonical_name,
                alias,
            } => {
                assert_eq!(canonical_name, "x");
                assert_eq!(alias, "y");
            }
            other => panic!("expected RemoveConceptAlias, got {other:?}"),
        }
    }

    #[tokio::test]
    async fn non_concept_intents_surface_permanent_failure() {
        let (_tmp, applier) = fresh_applier();
        let cases = [
            Intent::VaultWrite {
                path: "x".into(),
                body: "y".into(),
                frontmatter: serde_json::json!({}),
            },
            Intent::MemoryWrite {
                entry: serde_json::json!({}),
            },
            Intent::Noop {
                reason: "n".into(),
            },
        ];
        for intent in cases {
            let err = applier.apply(intent).await.unwrap_err();
            assert!(matches!(err, ApplyError::Permanent(_)));
        }
    }
}
