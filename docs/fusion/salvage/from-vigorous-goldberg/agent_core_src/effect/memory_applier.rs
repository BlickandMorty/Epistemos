//! Plan §8 — concrete `IntentApplier` for the memory subsystem.
//!
//! Handles `Intent::MemoryWrite`. Memory entries live as `.mem` files
//! under `<vault>/.epistemos/memory/<id>.mem` per the Phase 1 hybrid
//! format.
//!
//! Reversibility per §8.5: memory.write → tombstone the entry by id.
//! Tombstoning replaces the body with a sentinel marker rather than
//! deleting the file — the .mem id is referentially stable so a later
//! ⌘Redo can resurrect.
//!
//! The Intent's `entry` field is a JSON Value that must contain an
//! `id` (ULID). The applier reads the id to compute the file path
//! and surfaces InvalidIntent if missing.

use std::path::PathBuf;

use async_trait::async_trait;

use crate::effect::{ApplyError, Effect, IntentApplier, PriorState};
use crate::format::intent::Intent;

const MEMORY_DIR: &str = ".epistemos/memory";

pub struct MemoryApplier {
    memory_dir: PathBuf,
}

impl MemoryApplier {
    pub fn new(vault_root: impl Into<PathBuf>) -> Self {
        Self {
            memory_dir: vault_root.into().join(MEMORY_DIR),
        }
    }

    fn ensure_dir(&self) -> Result<(), ApplyError> {
        std::fs::create_dir_all(&self.memory_dir)
            .map_err(|e| ApplyError::IoError(e.to_string()))
    }

    fn path_for(&self, id: &str) -> PathBuf {
        self.memory_dir.join(format!("{id}.mem"))
    }
}

#[async_trait]
impl IntentApplier for MemoryApplier {
    async fn apply(
        &self,
        intent: Intent,
    ) -> Result<(Effect, Option<PriorState>), ApplyError> {
        match intent {
            Intent::MemoryWrite { entry } => {
                self.ensure_dir()?;
                // Extract the id (required by §1 mem format).
                let id = entry
                    .get("id")
                    .and_then(|v| v.as_str())
                    .ok_or_else(|| {
                        ApplyError::InvalidIntent(
                            "memory.write entry must include 'id' (ULID)".into(),
                        )
                    })?
                    .to_string();
                if id.is_empty() {
                    return Err(ApplyError::InvalidIntent(
                        "memory.write 'id' must not be empty".into(),
                    ));
                }
                // Validate it parses as a ULID for safety.
                ulid::Ulid::from_string(&id).map_err(|e| {
                    ApplyError::InvalidIntent(format!("invalid ULID '{id}': {e}"))
                })?;

                // Render as a hybrid .mem file: single-line JSON header
                // + blank line + (optional) body. Per the §1 format, an
                // entry's `body` is a top-level field, not nested under
                // anything. We treat anything besides `body` as header.
                let mut entry_obj = entry
                    .as_object()
                    .ok_or_else(|| {
                        ApplyError::InvalidIntent("memory.write entry must be an object".into())
                    })?
                    .clone();
                let body = entry_obj
                    .remove("body")
                    .and_then(|v| v.as_str().map(|s| s.to_string()))
                    .unwrap_or_default();
                let header = serde_json::Value::Object(entry_obj);
                let header_line = serde_json::to_string(&header).map_err(|e| {
                    ApplyError::IoError(format!("serialize mem header: {e}"))
                })?;
                let rendered = format!("---{header_line}---\n\n{body}");

                let path = self.path_for(&id);
                crate::util::atomic_write_bytes(&path, rendered.as_bytes())
                    .map_err(|e| ApplyError::IoError(e.to_string()))?;

                Ok((Effect::MemoryWrote { entry_id: id }, None))
            }
            other => Err(ApplyError::Permanent(format!(
                "MemoryApplier doesn't handle {other:?} — wrong applier"
            ))),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::effect::Inverse;
    use tempfile::TempDir;

    fn fresh_applier() -> (TempDir, MemoryApplier) {
        let tmp = TempDir::new().expect("tempdir");
        let applier = MemoryApplier::new(tmp.path());
        (tmp, applier)
    }

    fn ulid_str() -> String {
        ulid::Ulid::new().to_string()
    }

    #[tokio::test]
    async fn memory_write_persists_to_disk_under_canonical_path() {
        let (tmp, applier) = fresh_applier();
        let id = ulid_str();
        let (effect, prior) = applier
            .apply(Intent::MemoryWrite {
                entry: serde_json::json!({
                    "id": id,
                    "type": "preference",
                    "ts": "2026-04-29T00:00:00Z",
                    "body": "the user prefers vault-relative paths"
                }),
            })
            .await
            .expect("apply");
        assert!(prior.is_none());
        match effect {
            Effect::MemoryWrote { entry_id } => assert_eq!(entry_id, id),
            other => panic!("expected MemoryWrote, got {other:?}"),
        }
        let path = tmp.path().join(MEMORY_DIR).join(format!("{id}.mem"));
        assert!(path.is_file(), "mem file must exist on disk");
        let written = std::fs::read_to_string(&path).unwrap();
        assert!(written.starts_with("---{"), "header line must lead");
        assert!(written.contains(&id), "id present in header");
        assert!(
            written.ends_with("the user prefers vault-relative paths"),
            "body persisted at the end"
        );
    }

    #[tokio::test]
    async fn memory_write_rejects_missing_id() {
        let (_tmp, applier) = fresh_applier();
        let err = applier
            .apply(Intent::MemoryWrite {
                entry: serde_json::json!({"body": "no id here"}),
            })
            .await
            .unwrap_err();
        assert!(matches!(err, ApplyError::InvalidIntent(_)));
    }

    #[tokio::test]
    async fn memory_write_rejects_invalid_ulid() {
        let (_tmp, applier) = fresh_applier();
        let err = applier
            .apply(Intent::MemoryWrite {
                entry: serde_json::json!({"id": "not-a-ulid", "body": "x"}),
            })
            .await
            .unwrap_err();
        assert!(matches!(err, ApplyError::InvalidIntent(_)));
    }

    #[tokio::test]
    async fn memory_write_inverse_tombstones_by_entry_id() {
        let id = ulid_str();
        let effect = Effect::MemoryWrote {
            entry_id: id.clone(),
        };
        match effect.compute_inverse(None) {
            Inverse::TombstoneMemory { entry_id } => assert_eq!(entry_id, id),
            other => panic!("expected TombstoneMemory, got {other:?}"),
        }
    }

    #[tokio::test]
    async fn non_memory_intents_surface_permanent_failure() {
        let (_tmp, applier) = fresh_applier();
        let err = applier
            .apply(Intent::VaultWrite {
                path: "x".into(),
                body: "y".into(),
                frontmatter: serde_json::json!({}),
            })
            .await
            .unwrap_err();
        assert!(matches!(err, ApplyError::Permanent(_)));
    }
}
