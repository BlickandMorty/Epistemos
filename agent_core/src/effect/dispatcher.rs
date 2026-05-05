use std::sync::Arc;

use async_trait::async_trait;

use crate::effect::{ApplyError, Effect, IntentApplier, PriorState};
use crate::format::Intent;

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
    async fn apply(&self, intent: Intent) -> Result<(Effect, Option<PriorState>), ApplyError> {
        match &intent {
            Intent::VaultWrite { .. } | Intent::VaultMove { .. } | Intent::VaultDelete { .. } => {
                match &self.vault {
                    Some(applier) => applier.apply(intent).await,
                    None => Err(ApplyError::Permanent(
                        "vault intent received with no vault applier".to_string(),
                    )),
                }
            }
            Intent::ConceptCreate { .. } | Intent::ConceptAlias { .. } => match &self.concept {
                Some(applier) => applier.apply(intent).await,
                None => Err(ApplyError::Permanent(
                    "concept intent received with no concept applier".to_string(),
                )),
            },
            Intent::MemoryWrite { .. } => match &self.memory {
                Some(applier) => applier.apply(intent).await,
                None => Err(ApplyError::Permanent(
                    "memory intent received with no memory applier".to_string(),
                )),
            },
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
