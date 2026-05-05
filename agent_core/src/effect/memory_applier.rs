use std::path::{Path, PathBuf};

use async_trait::async_trait;

use crate::effect::{ApplyError, Effect, IntentApplier, PriorState};
use crate::format::{is_ulid_like, Intent};

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

    fn path_for(&self, id: &str) -> PathBuf {
        self.memory_dir.join(format!("{id}.mem"))
    }
}

#[async_trait]
impl IntentApplier for MemoryApplier {
    async fn apply(&self, intent: Intent) -> Result<(Effect, Option<PriorState>), ApplyError> {
        match intent {
            Intent::MemoryWrite { entry } => {
                let mut entry_object = entry
                    .as_object()
                    .ok_or_else(|| {
                        ApplyError::InvalidIntent(
                            "memory.write entry must be an object".to_string(),
                        )
                    })?
                    .clone();
                let id = entry_object
                    .get("id")
                    .and_then(|value| value.as_str())
                    .ok_or_else(|| {
                        ApplyError::InvalidIntent("memory.write entry must include id".to_string())
                    })?
                    .to_string();
                if !is_ulid_like(&id) {
                    return Err(ApplyError::InvalidIntent(format!(
                        "memory.write id must be a canonical ULID, got {id}"
                    )));
                }
                let body = entry_object
                    .remove("body")
                    .and_then(|value| value.as_str().map(ToOwned::to_owned))
                    .unwrap_or_default();
                let header = serde_json::Value::Object(entry_object);
                let header_json = serde_json::to_string(&header)
                    .map_err(|error| ApplyError::IoError(error.to_string()))?;
                let rendered = format!("---{header_json}---\n\n{body}");
                atomic_write_bytes(&self.path_for(&id), rendered.as_bytes())
                    .map_err(|error| ApplyError::IoError(error.to_string()))?;
                Ok((Effect::MemoryWrote { entry_id: id }, None))
            }
            other => Err(ApplyError::Permanent(format!(
                "memory applier received unsupported intent {other:?}"
            ))),
        }
    }
}

fn atomic_write_bytes(path: &Path, bytes: &[u8]) -> std::io::Result<()> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let tmp_path = path.with_extension(format!(
        "{}.tmp",
        path.extension()
            .and_then(|extension| extension.to_str())
            .unwrap_or("mem")
    ));
    std::fs::write(&tmp_path, bytes)?;
    std::fs::rename(tmp_path, path)
}
