use std::path::PathBuf;

use async_trait::async_trait;
use chrono::Utc;

use crate::canon::{AliasEntry, AliasProvenance, AliasTable};
use crate::effect::{ApplyError, Effect, IntentApplier, PriorState};
use crate::format::{FormatError, Intent};

const CONCEPTS_DIR: &str = ".epistemos/concepts";

pub struct ConceptGraphApplier {
    concepts_dir: PathBuf,
}

impl ConceptGraphApplier {
    pub fn new(vault_root: impl Into<PathBuf>) -> Self {
        Self {
            concepts_dir: vault_root.into().join(CONCEPTS_DIR),
        }
    }

    fn ensure_dir(&self) -> Result<(), ApplyError> {
        std::fs::create_dir_all(&self.concepts_dir)
            .map_err(|error| ApplyError::IoError(error.to_string()))
    }
}

#[async_trait]
impl IntentApplier for ConceptGraphApplier {
    async fn apply(&self, intent: Intent) -> Result<(Effect, Option<PriorState>), ApplyError> {
        self.ensure_dir()?;
        match intent {
            Intent::ConceptCreate {
                canonical_name,
                definition,
            } => {
                let path = AliasTable::path_for(&self.concepts_dir, &canonical_name);
                if path.exists() {
                    return Err(ApplyError::Conflict(format!(
                        "concept {canonical_name} already exists"
                    )));
                }
                let mut table = AliasTable::fresh(canonical_name.clone());
                if !definition.trim().is_empty() {
                    table.definition = Some(definition);
                }
                table.last_modified = Some(Utc::now());
                table.save(&path).map_err(map_format_error)?;
                Ok((Effect::ConceptCreated { canonical_name }, None))
            }
            Intent::ConceptAlias {
                canonical_name,
                alias,
            } => {
                let path = AliasTable::path_for(&self.concepts_dir, &canonical_name);
                let mut table = if path.exists() {
                    AliasTable::load(&path).map_err(map_format_error)?
                } else {
                    AliasTable::fresh(canonical_name.clone())
                };
                table.append_alias(AliasEntry {
                    name: alias.clone(),
                    added_at: Utc::now(),
                    via: AliasProvenance::ManualSeed,
                    confidence: None,
                });
                table.save(&path).map_err(map_format_error)?;
                Ok((
                    Effect::ConceptAliased {
                        canonical_name,
                        alias,
                    },
                    None,
                ))
            }
            other => Err(ApplyError::Permanent(format!(
                "concept applier received unsupported intent {other:?}"
            ))),
        }
    }
}

fn map_format_error(error: FormatError) -> ApplyError {
    ApplyError::IoError(format!("alias table: {error}"))
}
