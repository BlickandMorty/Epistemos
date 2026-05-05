use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use agent_core::effect::{
    Capability, Effect, ExecutionReceipt, HmacSha256SigningKey, IntentApplier, IntentDispatcher,
    Inverse, PriorState, VaultIntentApplier,
};
use agent_core::format::Intent;
use agent_core::storage::vault::{SearchResult, VaultBackend, VaultError};
use async_trait::async_trait;

struct MemVault {
    files: Mutex<HashMap<String, String>>,
}

impl MemVault {
    fn new() -> Arc<Self> {
        Arc::new(Self {
            files: Mutex::new(HashMap::new()),
        })
    }
}

#[async_trait]
impl VaultBackend for MemVault {
    async fn hybrid_search(
        &self,
        _query: &str,
        _limit: usize,
        _tag_filter: &[String],
    ) -> Result<Vec<SearchResult>, VaultError> {
        Ok(Vec::new())
    }

    async fn read(&self, path: &str) -> Result<String, VaultError> {
        self.files
            .lock()
            .expect("vault mutex")
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
            .expect("vault mutex")
            .insert(path.to_string(), content.to_string());
        Ok(())
    }

    async fn list(&self, _path_prefix: &str) -> Result<Vec<String>, VaultError> {
        Ok(self
            .files
            .lock()
            .expect("vault mutex")
            .keys()
            .cloned()
            .collect())
    }

    async fn exists(&self, path: &str) -> Result<bool, VaultError> {
        Ok(self.files.lock().expect("vault mutex").contains_key(path))
    }

    async fn delete(&self, path: &str) -> Result<bool, VaultError> {
        Ok(self
            .files
            .lock()
            .expect("vault mutex")
            .remove(path)
            .is_some())
    }
}

#[test]
fn effect_inverses_are_precomputed_from_apply_time_state() {
    let fresh_write = Effect::VaultWrote {
        path: "notes/new.md".to_string(),
        body_sha256: "sha".to_string(),
        bytes_written: 3,
    };
    assert_eq!(
        fresh_write.compute_inverse(None),
        Inverse::DeleteVault {
            path: "notes/new.md".to_string()
        }
    );

    let overwrite = Effect::VaultWrote {
        path: "notes/existing.md".to_string(),
        body_sha256: "sha".to_string(),
        bytes_written: 3,
    };
    let prior = PriorState::WroteOverExisting {
        body_before: "original".to_string(),
        body_before_sha256: "oldsha".to_string(),
    };
    assert_eq!(
        overwrite.compute_inverse(Some(&prior)),
        Inverse::RestoreVaultContent {
            path: "notes/existing.md".to_string(),
            body: "original".to_string()
        }
    );
}

#[tokio::test]
async fn dispatcher_vault_write_round_trips_through_inverse() {
    let temp = tempfile::tempdir().expect("tempdir");
    let vault = MemVault::new();
    vault
        .write("notes/a.md", "old", None, false)
        .await
        .expect("seed");

    let vault_applier: Arc<dyn IntentApplier> = Arc::new(VaultIntentApplier::new(
        Arc::clone(&vault) as Arc<dyn VaultBackend>,
        temp.path(),
    ));
    let dispatcher = IntentDispatcher::new().with_vault(vault_applier);

    let (effect, prior) = dispatcher
        .apply(Intent::VaultWrite {
            path: "notes/a.md".to_string(),
            body: "new".to_string(),
            frontmatter: serde_json::json!({}),
        })
        .await
        .expect("apply");

    assert_eq!(vault.read("notes/a.md").await.expect("read"), "new");

    match effect.compute_inverse(prior.as_ref()) {
        Inverse::RestoreVaultContent { path, body } => {
            vault.write(&path, &body, None, false).await.expect("undo");
        }
        other => panic!("expected restore inverse, got {other:?}"),
    }
    assert_eq!(vault.read("notes/a.md").await.expect("read"), "old");
}

#[test]
fn execution_receipt_verifies_and_rejects_tampering() {
    let key = HmacSha256SigningKey::new([7; 32]);
    let receipt = ExecutionReceipt::sign(
        "01HX42KQM3R7N9PVK0X8Z3W5MQ",
        "plan-hash",
        "vault.write",
        br#"{"action":"vault.write"}"#,
        br#"{"kind":"vault_wrote"}"#,
        vec![Capability::VaultPath {
            path: "notes/a.md".to_string(),
            verb: "write".to_string(),
        }],
        &key,
    );
    assert!(receipt.verify(&key));

    let mut tampered = receipt.clone();
    tampered.tool = "vault.delete".to_string();
    assert!(!tampered.verify(&key));
}
