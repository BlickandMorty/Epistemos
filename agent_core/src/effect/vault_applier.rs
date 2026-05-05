use std::path::{Path, PathBuf};
use std::sync::Arc;

use async_trait::async_trait;
use chrono::Utc;
use sha2::{Digest, Sha256};

use crate::effect::{ApplyError, Effect, IntentApplier, PriorState};
use crate::format::Intent;
use crate::storage::vault::{VaultBackend, VaultError};

const SHADOW_DIR: &str = ".epistemos/shadows";

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

    fn shadow_dir_today(&self) -> PathBuf {
        self.vault_root
            .join(SHADOW_DIR)
            .join(Utc::now().format("%Y-%m-%d").to_string())
    }

    async fn write_shadow(&self, path: &str, body: &str) -> Result<PathBuf, ApplyError> {
        let shadow_dir = self.shadow_dir_today();
        std::fs::create_dir_all(&shadow_dir)
            .map_err(|error| ApplyError::IoError(error.to_string()))?;
        let shadow_path = shadow_dir.join(path.replace('/', "__"));
        atomic_write_bytes(&shadow_path, body.as_bytes())
            .map_err(|error| ApplyError::IoError(error.to_string()))?;
        Ok(shadow_path)
    }
}

#[async_trait]
impl IntentApplier for VaultIntentApplier {
    async fn apply(&self, intent: Intent) -> Result<(Effect, Option<PriorState>), ApplyError> {
        match intent {
            Intent::VaultWrite {
                path,
                body,
                frontmatter: _,
            } => {
                let prior = match self.backend.read(&path).await {
                    Ok(body_before) => Some(PriorState::WroteOverExisting {
                        body_before_sha256: sha256_hex(body_before.as_bytes()),
                        body_before,
                    }),
                    Err(VaultError::NotFound(_)) => None,
                    Err(error) => return Err(map_vault_error(error)),
                };
                self.backend
                    .write(&path, &body, None, false)
                    .await
                    .map_err(map_vault_error)?;
                Ok((
                    Effect::VaultWrote {
                        path,
                        body_sha256: sha256_hex(body.as_bytes()),
                        bytes_written: body.len() as u64,
                    },
                    prior,
                ))
            }
            Intent::VaultMove { from, to } => {
                let body = self.backend.read(&from).await.map_err(map_vault_error)?;
                self.backend
                    .write(&to, &body, None, false)
                    .await
                    .map_err(map_vault_error)?;
                if !self.backend.delete(&from).await.map_err(map_vault_error)? {
                    return Err(ApplyError::Conflict(format!(
                        "vault.move source {from} disappeared during delete"
                    )));
                }
                Ok((Effect::VaultMoved { from, to }, None))
            }
            Intent::VaultDelete { path } => {
                let body = self.backend.read(&path).await.map_err(map_vault_error)?;
                let shadow_path = self.write_shadow(&path, &body).await?;
                if !self.backend.delete(&path).await.map_err(map_vault_error)? {
                    return Err(ApplyError::Conflict(format!(
                        "vault.delete backend returned false for {path}"
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
            other => Err(ApplyError::Permanent(format!(
                "vault applier received unsupported intent {other:?}"
            ))),
        }
    }
}

fn map_vault_error(error: VaultError) -> ApplyError {
    match error {
        VaultError::NotFound(path) => ApplyError::InvalidIntent(format!("not found: {path}")),
        VaultError::PathTraversal(path) => {
            ApplyError::PermissionDenied(format!("path traversal denied: {path}"))
        }
        VaultError::IoError(error) => ApplyError::IoError(error.to_string()),
        VaultError::DatabaseError(message) => ApplyError::IoError(format!("db: {message}")),
        VaultError::IndexError(message) => ApplyError::IoError(format!("index: {message}")),
    }
}

fn sha256_hex(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}

fn atomic_write_bytes(path: &Path, bytes: &[u8]) -> std::io::Result<()> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let tmp_path = path.with_extension(format!(
        "{}.tmp",
        path.extension()
            .and_then(|extension| extension.to_str())
            .unwrap_or("shadow")
    ));
    std::fs::write(&tmp_path, bytes)?;
    std::fs::rename(tmp_path, path)
}
