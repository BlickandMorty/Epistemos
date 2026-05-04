//! Plan §8 — concrete `IntentApplier` for the vault subsystem.
//!
//! Handles `Intent::VaultWrite` / `VaultMove` / `VaultDelete` against
//! a `VaultBackend`. Captures the `PriorState` at apply-time so the
//! undo log can compute exact-restore inverses per §8.5.
//!
//! Per §8.5 reversibility classification:
//!   - vault.write  → reverse: delete or restore prior content
//!   - vault.move   → reverse: move back
//!   - vault.delete → 24h shadow copy restore
//!
//! Shadow copies for delete live under
//! `<vault>/.epistemos/shadows/<YYYY-MM-DD>/<basename>`. The 24h
//! retention is enforced by a NightBrain task that's wired in
//! parallel to UndoEvictionTask (§7.1: "rotate heal_log/action_trace").

use std::path::PathBuf;
use std::sync::Arc;

use async_trait::async_trait;
use chrono::Utc;
use sha2::{Digest, Sha256};

use crate::effect::{ApplyError, Effect, IntentApplier, PriorState};
use crate::format::intent::Intent;
use crate::storage::vault::{VaultBackend, VaultError};

/// Subdirectory under the vault root where shadow copies of deleted
/// notes live. Each delete writes one file; a NightBrain task evicts
/// after the 24h §8.5 retention window.
const SHADOW_DIR: &str = ".epistemos/shadows";

/// Concrete `IntentApplier` for vault Intents.
///
/// Holds an `Arc<dyn VaultBackend>` (so the same vault can be shared
/// with the tool registry + the route pipeline) plus the on-disk
/// `vault_root` for shadow-copy management.
pub struct VaultIntentApplier {
    backend: Arc<dyn VaultBackend>,
    vault_root: PathBuf,
}

impl VaultIntentApplier {
    pub fn new(backend: Arc<dyn VaultBackend>, vault_root: impl Into<PathBuf>) -> Self {
        Self {
            backend,
            vault_root: vault_root.into(),
        }
    }

    /// Compute today's shadow directory: `<vault>/.epistemos/shadows/2026-04-29/`.
    /// Per §8.5 the 24h TTL means at most two daily directories ever
    /// exist on disk.
    fn shadow_dir_today(&self) -> PathBuf {
        let day = Utc::now().format("%Y-%m-%d").to_string();
        self.vault_root.join(SHADOW_DIR).join(day)
    }

    /// Copy a vault file to the shadow tree before deletion. Returns
    /// the absolute shadow path so the inverse can find it later.
    async fn write_shadow(&self, path: &str, body: &str) -> Result<PathBuf, ApplyError> {
        let dir = self.shadow_dir_today();
        std::fs::create_dir_all(&dir).map_err(|e| ApplyError::IoError(e.to_string()))?;
        // Replace path separators with `__` so we can flatten the
        // shadow filename without colliding on basenames from
        // different folders.
        let flat = path.replace('/', "__");
        let shadow_path = dir.join(flat);
        crate::util::atomic_write_bytes(&shadow_path, body.as_bytes())
            .map_err(|e| ApplyError::IoError(e.to_string()))?;
        Ok(shadow_path)
    }
}

#[async_trait]
impl IntentApplier for VaultIntentApplier {
    async fn apply(
        &self,
        intent: Intent,
    ) -> Result<(Effect, Option<PriorState>), ApplyError> {
        match intent {
            Intent::VaultWrite {
                path,
                body,
                frontmatter: _,
            } => {
                // Capture prior state if the file already exists so the
                // inverse can restore exactly what was overwritten.
                let prior = match self.backend.read(&path).await {
                    Ok(body_before) => {
                        let hash = format!("{:x}", Sha256::digest(body_before.as_bytes()));
                        Some(PriorState::WroteOverExisting {
                            body_before,
                            body_before_sha256: hash,
                        })
                    }
                    Err(VaultError::NotFound(_)) => None,
                    Err(other) => return Err(map_vault_err(other)),
                };

                self.backend
                    .write(&path, &body, None, false)
                    .await
                    .map_err(map_vault_err)?;

                let body_sha256 = format!("{:x}", Sha256::digest(body.as_bytes()));
                let bytes_written = body.as_bytes().len() as u64;
                Ok((
                    Effect::VaultWrote {
                        path,
                        body_sha256,
                        bytes_written,
                    },
                    prior,
                ))
            }

            Intent::VaultMove { from, to } => {
                // Read source, write target, delete source. The
                // VaultBackend doesn't expose an atomic rename, so we
                // emulate it with read+write+delete and let the inverse
                // (MoveVault) reverse the same way.
                let body = self.backend.read(&from).await.map_err(map_vault_err)?;
                self.backend
                    .write(&to, &body, None, false)
                    .await
                    .map_err(map_vault_err)?;
                let removed = self.backend.delete(&from).await.map_err(map_vault_err)?;
                if !removed {
                    return Err(ApplyError::Conflict(format!(
                        "vault.move: source {from} disappeared mid-operation; \
                         target was created at {to} but source delete returned false"
                    )));
                }
                Ok((Effect::VaultMoved { from, to }, None))
            }

            Intent::VaultDelete { path } => {
                // Read body, write to today's shadow, then delete from
                // the live vault. The shadow path is the inverse's
                // input — undo restores from there.
                let body = self.backend.read(&path).await.map_err(map_vault_err)?;
                let shadow_path = self.write_shadow(&path, &body).await?;
                let removed = self.backend.delete(&path).await.map_err(map_vault_err)?;
                if !removed {
                    return Err(ApplyError::Conflict(format!(
                        "vault.delete: backend returned false for {path}"
                    )));
                }
                Ok((
                    Effect::VaultDeleted {
                        path,
                        shadow_path: shadow_path.display().to_string(),
                    },
                    None,
                ))
            }

            // Concept / memory / noop / abort intents go through
            // their own appliers; signaling a permanent failure here
            // makes the heal loop give up rather than retry forever.
            other => Err(ApplyError::Permanent(format!(
                "VaultIntentApplier doesn't handle {other:?} — wrong applier"
            ))),
        }
    }
}

/// Map `VaultError` to `ApplyError` per the canonical taxonomy
/// (path traversal → PermissionDenied; not-found → InvalidIntent;
/// rest → IoError).
fn map_vault_err(err: VaultError) -> ApplyError {
    match err {
        VaultError::NotFound(path) => ApplyError::InvalidIntent(format!("not found: {path}")),
        VaultError::PathTraversal(path) => {
            ApplyError::PermissionDenied(format!("path traversal denied: {path}"))
        }
        VaultError::IoError(e) => ApplyError::IoError(e.to_string()),
        VaultError::DatabaseError(msg) => ApplyError::IoError(format!("db: {msg}")),
        VaultError::IndexError(msg) => ApplyError::IoError(format!("index: {msg}")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::effect::Inverse;
    use crate::storage::vault::SearchResult;
    use std::sync::Mutex;
    use tempfile::TempDir;

    /// In-memory vault backend with a HashMap so tests don't need disk.
    struct MemVault {
        files: Mutex<std::collections::HashMap<String, String>>,
    }

    impl MemVault {
        fn new() -> Arc<Self> {
            Arc::new(Self {
                files: Mutex::new(std::collections::HashMap::new()),
            })
        }
    }

    #[async_trait]
    impl VaultBackend for MemVault {
        async fn hybrid_search(
            &self,
            _q: &str,
            _l: usize,
            _t: &[String],
        ) -> Result<Vec<SearchResult>, VaultError> {
            Ok(Vec::new())
        }
        async fn read(&self, path: &str) -> Result<String, VaultError> {
            self.files
                .lock()
                .unwrap()
                .get(path)
                .cloned()
                .ok_or_else(|| VaultError::NotFound(path.to_string()))
        }
        async fn write(
            &self,
            path: &str,
            content: &str,
            _tags: Option<&[String]>,
            _append: bool,
        ) -> Result<(), VaultError> {
            self.files
                .lock()
                .unwrap()
                .insert(path.to_string(), content.to_string());
            Ok(())
        }
        async fn list(&self, _p: &str) -> Result<Vec<String>, VaultError> {
            Ok(self.files.lock().unwrap().keys().cloned().collect())
        }
        async fn exists(&self, path: &str) -> Result<bool, VaultError> {
            Ok(self.files.lock().unwrap().contains_key(path))
        }
        async fn delete(&self, path: &str) -> Result<bool, VaultError> {
            Ok(self.files.lock().unwrap().remove(path).is_some())
        }
    }

    fn fresh_applier() -> (TempDir, VaultIntentApplier, Arc<MemVault>) {
        let tmp = TempDir::new().expect("tempdir");
        let vault = MemVault::new();
        let applier = VaultIntentApplier::new(
            Arc::clone(&vault) as Arc<dyn VaultBackend>,
            tmp.path().to_path_buf(),
        );
        (tmp, applier, vault)
    }

    #[tokio::test]
    async fn vault_write_to_fresh_path_returns_no_prior_state() {
        let (_tmp, applier, _vault) = fresh_applier();
        let intent = Intent::VaultWrite {
            path: "notes/new.md".to_string(),
            body: "hello".to_string(),
            frontmatter: serde_json::json!({}),
        };
        let (effect, prior) = applier.apply(intent).await.expect("apply");
        match &effect {
            Effect::VaultWrote {
                path,
                body_sha256,
                bytes_written,
            } => {
                assert_eq!(path, "notes/new.md");
                assert_eq!(*bytes_written, 5);
                // sha256("hello") = 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
                assert_eq!(
                    body_sha256,
                    "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
                );
            }
            other => panic!("expected VaultWrote, got {other:?}"),
        }
        assert!(prior.is_none(), "fresh write has no prior state");

        // The inverse for this Effect is DeleteVault.
        let inv = effect.compute_inverse(prior.as_ref());
        assert!(matches!(inv, Inverse::DeleteVault { .. }));
    }

    #[tokio::test]
    async fn vault_write_overwriting_captures_prior_for_exact_restore() {
        let (_tmp, applier, vault) = fresh_applier();
        // Seed an existing file.
        vault
            .write("notes/x.md", "original content", None, false)
            .await
            .unwrap();

        let intent = Intent::VaultWrite {
            path: "notes/x.md".to_string(),
            body: "new content".to_string(),
            frontmatter: serde_json::json!({}),
        };
        let (effect, prior) = applier.apply(intent).await.expect("apply");
        let prior = prior.expect("overwrite must capture prior state");
        match prior {
            PriorState::WroteOverExisting {
                body_before,
                body_before_sha256,
            } => {
                assert_eq!(body_before, "original content");
                assert!(!body_before_sha256.is_empty());
            }
            other => panic!("expected WroteOverExisting, got {other:?}"),
        }

        // The inverse is RestoreVaultContent with the captured body.
        let inv = effect.compute_inverse(Some(&PriorState::WroteOverExisting {
            body_before: "original content".to_string(),
            body_before_sha256: "abc".to_string(),
        }));
        match inv {
            Inverse::RestoreVaultContent { path, body } => {
                assert_eq!(path, "notes/x.md");
                assert_eq!(body, "original content");
            }
            other => panic!("expected RestoreVaultContent, got {other:?}"),
        }
    }

    #[tokio::test]
    async fn vault_move_swaps_locations() {
        let (_tmp, applier, vault) = fresh_applier();
        vault
            .write("a.md", "the body", None, false)
            .await
            .unwrap();

        let intent = Intent::VaultMove {
            from: "a.md".to_string(),
            to: "b.md".to_string(),
        };
        let (effect, _) = applier.apply(intent).await.expect("apply");
        match &effect {
            Effect::VaultMoved { from, to } => {
                assert_eq!(from, "a.md");
                assert_eq!(to, "b.md");
            }
            other => panic!("expected VaultMoved, got {other:?}"),
        }
        assert!(!vault.exists("a.md").await.unwrap(), "source removed");
        assert!(vault.exists("b.md").await.unwrap(), "target written");
        assert_eq!(vault.read("b.md").await.unwrap(), "the body");
    }

    #[tokio::test]
    async fn vault_delete_writes_shadow_copy_then_removes() {
        let (tmp, applier, vault) = fresh_applier();
        vault
            .write("notes/old.md", "ephemeral", None, false)
            .await
            .unwrap();

        let intent = Intent::VaultDelete {
            path: "notes/old.md".to_string(),
        };
        let (effect, prior) = applier.apply(intent).await.expect("apply");
        assert!(prior.is_none());

        // Live vault no longer has the file.
        assert!(!vault.exists("notes/old.md").await.unwrap());
        // Shadow file exists under .epistemos/shadows/<date>/.
        let (path_field, shadow_path_field) = match &effect {
            Effect::VaultDeleted { path, shadow_path } => (path.clone(), shadow_path.clone()),
            other => panic!("expected VaultDeleted, got {other:?}"),
        };
        let shadow_path_pb = std::path::PathBuf::from(&shadow_path_field);
        assert!(shadow_path_pb.is_file(), "shadow copy must exist on disk");
        let shadow_body = std::fs::read_to_string(&shadow_path_pb).unwrap();
        assert_eq!(shadow_body, "ephemeral");
        assert!(
            shadow_path_pb.starts_with(tmp.path().join(SHADOW_DIR)),
            "shadow path must live under .epistemos/shadows/"
        );

        // The inverse restores from the shadow path.
        let inv = effect.compute_inverse(None);
        match inv {
            Inverse::RestoreVaultFromShadow {
                path,
                shadow_path: inv_shadow,
            } => {
                assert_eq!(path, path_field);
                assert_eq!(inv_shadow, shadow_path_field);
            }
            other => panic!("expected RestoreVaultFromShadow, got {other:?}"),
        }
    }

    #[tokio::test]
    async fn vault_write_propagates_path_traversal_as_permission_denied() {
        struct DenyingVault;
        #[async_trait]
        impl VaultBackend for DenyingVault {
            async fn hybrid_search(
                &self,
                _: &str,
                _: usize,
                _: &[String],
            ) -> Result<Vec<SearchResult>, VaultError> {
                Ok(Vec::new())
            }
            async fn read(&self, path: &str) -> Result<String, VaultError> {
                Err(VaultError::PathTraversal(path.to_string()))
            }
            async fn write(
                &self,
                path: &str,
                _: &str,
                _: Option<&[String]>,
                _: bool,
            ) -> Result<(), VaultError> {
                Err(VaultError::PathTraversal(path.to_string()))
            }
            async fn list(&self, _: &str) -> Result<Vec<String>, VaultError> {
                Ok(Vec::new())
            }
            async fn exists(&self, _: &str) -> Result<bool, VaultError> {
                Ok(false)
            }
            async fn delete(&self, _: &str) -> Result<bool, VaultError> {
                Ok(false)
            }
        }
        let tmp = TempDir::new().unwrap();
        let applier = VaultIntentApplier::new(
            Arc::new(DenyingVault) as Arc<dyn VaultBackend>,
            tmp.path().to_path_buf(),
        );
        let intent = Intent::VaultWrite {
            path: "../escape.md".to_string(),
            body: "hi".to_string(),
            frontmatter: serde_json::json!({}),
        };
        let err = applier.apply(intent).await.unwrap_err();
        assert!(
            matches!(err, ApplyError::PermissionDenied(_)),
            "path traversal must surface as PermissionDenied, got {err:?}"
        );
    }

    #[tokio::test]
    async fn non_vault_intents_surface_permanent_failure() {
        let (_tmp, applier, _) = fresh_applier();
        let cases = [
            Intent::ConceptCreate {
                canonical_name: "x".to_string(),
                definition: "y".to_string(),
            },
            Intent::ConceptAlias {
                canonical_name: "x".to_string(),
                alias: "y".to_string(),
            },
            Intent::MemoryWrite {
                entry: serde_json::json!({}),
            },
            Intent::Noop {
                reason: "n".to_string(),
            },
            Intent::Abort {
                reason: "a".to_string(),
            },
        ];
        for intent in cases {
            let err = applier.apply(intent.clone()).await.unwrap_err();
            assert!(
                matches!(err, ApplyError::Permanent(_)),
                "non-vault intent {intent:?} must surface Permanent, got {err:?}"
            );
        }
    }

    #[tokio::test]
    async fn end_to_end_apply_then_undo_restores_overwritten_body() {
        // Plan §8.5 invariant: ⌘Z over a vault.write that overwrote
        // an existing file restores the prior body byte-for-byte.
        let (_tmp, applier, vault) = fresh_applier();
        vault.write("notes/x.md", "original", None, false).await.unwrap();

        let (effect, prior) = applier
            .apply(Intent::VaultWrite {
                path: "notes/x.md".to_string(),
                body: "new".to_string(),
                frontmatter: serde_json::json!({}),
            })
            .await
            .expect("apply");

        // Compute inverse.
        let inv = effect.compute_inverse(prior.as_ref());

        // Replay the inverse: write the prior body back.
        match inv {
            Inverse::RestoreVaultContent { path, body } => {
                vault
                    .write(&path, &body, None, false)
                    .await
                    .expect("restore");
            }
            other => panic!("expected RestoreVaultContent, got {other:?}"),
        }
        assert_eq!(
            vault.read("notes/x.md").await.unwrap(),
            "original",
            "undo must restore the exact prior body"
        );
    }
}
