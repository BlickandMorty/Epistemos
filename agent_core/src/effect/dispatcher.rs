//! Plan §8 — `IntentDispatcher`: single entry point for the agent_loop.
//!
//! Routes each `Intent` variant to the right sub-applier (vault,
//! concept-graph, memory). Holds them as `Arc<dyn IntentApplier>` so
//! one dispatcher serves the whole runtime; sub-appliers can be
//! shared across the route pipeline + heal loop + Workspace runner
//! without re-construction.
//!
//! `noop` and `abort` Intents short-circuit here without a sub-applier
//! call — they're trace-only state transitions, not real mutations.
//!
//! Per FINAL_SYNTHESIS §2 layer 5 (Motor): every tool call's input
//! is grammar-bound, output schema-validated, every capability is
//! pre-authorized, every irreversible action requires explicit user
//! consent. The dispatcher is the funnel through which all those
//! invariants must already hold by the time we reach apply().

use std::sync::Arc;

use async_trait::async_trait;

use crate::effect::{ApplyError, Effect, IntentApplier, PriorState};
use crate::format::intent::Intent;

/// Composite IntentApplier that dispatches by Intent::action variant.
/// Concrete sub-appliers can be set in any subset; missing ones
/// surface ApplyError::Permanent so the heal loop gives up rather
/// than retrying forever.
pub struct IntentDispatcher {
    pub vault: Option<Arc<dyn IntentApplier>>,
    pub concept: Option<Arc<dyn IntentApplier>>,
    pub memory: Option<Arc<dyn IntentApplier>>,
}

impl IntentDispatcher {
    pub fn new() -> Self {
        Self {
            vault: None,
            concept: None,
            memory: None,
        }
    }

    pub fn with_vault(mut self, vault: Arc<dyn IntentApplier>) -> Self {
        self.vault = Some(vault);
        self
    }

    pub fn with_concept(mut self, concept: Arc<dyn IntentApplier>) -> Self {
        self.concept = Some(concept);
        self
    }

    pub fn with_memory(mut self, memory: Arc<dyn IntentApplier>) -> Self {
        self.memory = Some(memory);
        self
    }
}

impl Default for IntentDispatcher {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait]
impl IntentApplier for IntentDispatcher {
    async fn apply(
        &self,
        intent: Intent,
    ) -> Result<(Effect, Option<PriorState>), ApplyError> {
        match &intent {
            // Vault subsystem
            Intent::VaultWrite { .. }
            | Intent::VaultMove { .. }
            | Intent::VaultDelete { .. } => match &self.vault {
                Some(applier) => applier.apply(intent).await,
                None => Err(ApplyError::Permanent(
                    "vault Intent received but no vault applier wired into IntentDispatcher".into(),
                )),
            },
            // Concept-graph subsystem
            Intent::ConceptCreate { .. } | Intent::ConceptAlias { .. } => match &self.concept {
                Some(applier) => applier.apply(intent).await,
                None => Err(ApplyError::Permanent(
                    "concept Intent received but no concept applier wired into IntentDispatcher"
                        .into(),
                )),
            },
            // Memory subsystem
            Intent::MemoryWrite { .. } => match &self.memory {
                Some(applier) => applier.apply(intent).await,
                None => Err(ApplyError::Permanent(
                    "memory Intent received but no memory applier wired into IntentDispatcher"
                        .into(),
                )),
            },
            // Trace-only: noop / abort produce Effects but mutate no
            // state. Handled inline so the dispatcher can run without
            // any sub-applier wired (useful for the heal-loop tests
            // that exercise pure-control-flow Intents).
            Intent::Noop { reason } => Ok((
                Effect::NoopApplied {
                    reason: reason.clone(),
                },
                None,
            )),
            Intent::Abort { reason } => Ok((
                Effect::Aborted {
                    reason: reason.clone(),
                },
                None,
            )),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Stub applier that returns a canned Effect for every Intent it
    /// receives. Used to verify the dispatcher routes to the right
    /// sub-applier based on Intent::action.
    struct StubApplier {
        marker: &'static str,
    }

    #[async_trait]
    impl IntentApplier for StubApplier {
        async fn apply(
            &self,
            _intent: Intent,
        ) -> Result<(Effect, Option<PriorState>), ApplyError> {
            Ok((
                Effect::NoopApplied {
                    reason: self.marker.to_string(),
                },
                None,
            ))
        }
    }

    fn write_intent() -> Intent {
        Intent::VaultWrite {
            path: "x.md".into(),
            body: "y".into(),
            frontmatter: serde_json::json!({}),
        }
    }

    #[tokio::test]
    async fn vault_intent_routes_to_vault_applier() {
        let vault: Arc<dyn IntentApplier> = Arc::new(StubApplier { marker: "vault" });
        let concept: Arc<dyn IntentApplier> = Arc::new(StubApplier { marker: "concept" });
        let dispatcher = IntentDispatcher::new()
            .with_vault(vault)
            .with_concept(concept);

        for intent in [
            write_intent(),
            Intent::VaultMove {
                from: "a".into(),
                to: "b".into(),
            },
            Intent::VaultDelete {
                path: "x.md".into(),
            },
        ] {
            let (effect, _) = dispatcher.apply(intent).await.expect("apply");
            match effect {
                Effect::NoopApplied { reason } => assert_eq!(reason, "vault"),
                other => panic!("expected vault stub marker, got {other:?}"),
            }
        }
    }

    #[tokio::test]
    async fn concept_intent_routes_to_concept_applier() {
        let vault: Arc<dyn IntentApplier> = Arc::new(StubApplier { marker: "vault" });
        let concept: Arc<dyn IntentApplier> = Arc::new(StubApplier { marker: "concept" });
        let dispatcher = IntentDispatcher::new()
            .with_vault(vault)
            .with_concept(concept);

        for intent in [
            Intent::ConceptCreate {
                canonical_name: "k".into(),
                definition: "d".into(),
            },
            Intent::ConceptAlias {
                canonical_name: "k".into(),
                alias: "a".into(),
            },
        ] {
            let (effect, _) = dispatcher.apply(intent).await.expect("apply");
            match effect {
                Effect::NoopApplied { reason } => assert_eq!(reason, "concept"),
                other => panic!("expected concept stub marker, got {other:?}"),
            }
        }
    }

    #[tokio::test]
    async fn memory_intent_routes_to_memory_applier() {
        let memory: Arc<dyn IntentApplier> = Arc::new(StubApplier { marker: "memory" });
        let dispatcher = IntentDispatcher::new().with_memory(memory);
        let intent = Intent::MemoryWrite {
            entry: serde_json::json!({"id": "01HX42KQM3R7N9PVK0X8Z3W5MQ"}),
        };
        let (effect, _) = dispatcher.apply(intent).await.expect("apply");
        match effect {
            Effect::NoopApplied { reason } => assert_eq!(reason, "memory"),
            other => panic!("expected memory stub marker, got {other:?}"),
        }
    }

    #[tokio::test]
    async fn noop_intent_returns_noop_effect_inline() {
        // No appliers wired — noop must still work because it's
        // trace-only and never reaches a sub-applier.
        let dispatcher = IntentDispatcher::new();
        let intent = Intent::Noop {
            reason: "no action needed".into(),
        };
        let (effect, prior) = dispatcher.apply(intent).await.expect("apply");
        match effect {
            Effect::NoopApplied { reason } => assert_eq!(reason, "no action needed"),
            other => panic!("expected NoopApplied, got {other:?}"),
        }
        assert!(prior.is_none());
    }

    #[tokio::test]
    async fn abort_intent_returns_aborted_effect_inline() {
        let dispatcher = IntentDispatcher::new();
        let intent = Intent::Abort {
            reason: "unrecoverable".into(),
        };
        let (effect, _) = dispatcher.apply(intent).await.expect("apply");
        match effect {
            Effect::Aborted { reason } => assert_eq!(reason, "unrecoverable"),
            other => panic!("expected Aborted, got {other:?}"),
        }
    }

    #[tokio::test]
    async fn missing_vault_applier_surfaces_permanent_failure() {
        let dispatcher = IntentDispatcher::new(); // no vault wired
        let err = dispatcher.apply(write_intent()).await.unwrap_err();
        assert!(matches!(err, ApplyError::Permanent(_)),
            "missing applier must surface Permanent so heal loop gives up, got {err:?}");
    }

    #[tokio::test]
    async fn missing_concept_applier_surfaces_permanent_failure() {
        let dispatcher = IntentDispatcher::new();
        let err = dispatcher
            .apply(Intent::ConceptCreate {
                canonical_name: "k".into(),
                definition: "d".into(),
            })
            .await
            .unwrap_err();
        assert!(matches!(err, ApplyError::Permanent(_)));
    }

    #[tokio::test]
    async fn missing_memory_applier_surfaces_permanent_failure() {
        let dispatcher = IntentDispatcher::new();
        let err = dispatcher
            .apply(Intent::MemoryWrite {
                entry: serde_json::json!({"id": "x"}),
            })
            .await
            .unwrap_err();
        assert!(matches!(err, ApplyError::Permanent(_)));
    }

    #[tokio::test]
    async fn end_to_end_dispatcher_with_real_vault_applier_and_undo() {
        // Plan §8 + §8.5 round-trip: dispatcher → VaultIntentApplier
        // → Effect + PriorState → compute inverse → reverse →
        // original state restored. Tests the full agent-loop entry
        // path against a concrete sub-applier.
        use crate::effect::VaultIntentApplier;
        use crate::storage::vault::{SearchResult, VaultBackend, VaultError};
        use std::sync::Mutex;
        use tempfile::TempDir;

        struct MemVault {
            files: Mutex<std::collections::HashMap<String, String>>,
        }
        #[async_trait]
        impl VaultBackend for MemVault {
            async fn hybrid_search(
                &self,
                _: &str,
                _: usize,
                _: &[String],
            ) -> Result<Vec<SearchResult>, VaultError> {
                Ok(Vec::new())
            }
            async fn read(&self, p: &str) -> Result<String, VaultError> {
                self.files
                    .lock()
                    .unwrap()
                    .get(p)
                    .cloned()
                    .ok_or_else(|| VaultError::NotFound(p.to_string()))
            }
            async fn write(
                &self,
                p: &str,
                c: &str,
                _: Option<&[String]>,
                _: bool,
            ) -> Result<(), VaultError> {
                self.files.lock().unwrap().insert(p.into(), c.into());
                Ok(())
            }
            async fn list(&self, _: &str) -> Result<Vec<String>, VaultError> {
                Ok(Vec::new())
            }
            async fn exists(&self, p: &str) -> Result<bool, VaultError> {
                Ok(self.files.lock().unwrap().contains_key(p))
            }
            async fn delete(&self, p: &str) -> Result<bool, VaultError> {
                Ok(self.files.lock().unwrap().remove(p).is_some())
            }
        }

        let tmp = TempDir::new().unwrap();
        let vault: Arc<MemVault> = Arc::new(MemVault {
            files: Mutex::new(std::collections::HashMap::new()),
        });
        vault
            .write("notes/x.md", "original", None, false)
            .await
            .unwrap();

        let vault_applier: Arc<dyn IntentApplier> = Arc::new(VaultIntentApplier::new(
            Arc::clone(&vault) as Arc<dyn VaultBackend>,
            tmp.path().to_path_buf(),
        ));
        let dispatcher = IntentDispatcher::new().with_vault(vault_applier);

        // Apply a vault.write that overwrites.
        let (effect, prior) = dispatcher
            .apply(Intent::VaultWrite {
                path: "notes/x.md".into(),
                body: "new".into(),
                frontmatter: serde_json::json!({}),
            })
            .await
            .expect("apply");
        assert_eq!(vault.read("notes/x.md").await.unwrap(), "new");

        // Compute inverse and replay it.
        let inv = effect.compute_inverse(prior.as_ref());
        match inv {
            crate::effect::Inverse::RestoreVaultContent { path, body } => {
                vault.write(&path, &body, None, false).await.unwrap();
            }
            other => panic!("expected RestoreVaultContent, got {other:?}"),
        }

        assert_eq!(
            vault.read("notes/x.md").await.unwrap(),
            "original",
            "dispatcher → applier → inverse → restore must round-trip exactly"
        );
    }
}
