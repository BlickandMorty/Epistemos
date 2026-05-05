use serde::{Deserialize, Serialize};
use thiserror::Error;

use crate::format::Intent;

pub mod concept_applier;
pub mod dispatcher;
pub mod memory_applier;
pub mod receipt;
pub mod vault_applier;

pub use concept_applier::ConceptGraphApplier;
pub use dispatcher::IntentDispatcher;
pub use memory_applier::MemoryApplier;
pub use receipt::{Capability, ExecutionReceipt, HmacSha256SigningKey, SigningKey};
pub use vault_applier::VaultIntentApplier;

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum Effect {
    VaultWrote {
        path: String,
        body_sha256: String,
        bytes_written: u64,
    },
    VaultMoved {
        from: String,
        to: String,
    },
    VaultDeleted {
        path: String,
        shadow_path: String,
    },
    ConceptCreated {
        canonical_name: String,
    },
    ConceptAliased {
        canonical_name: String,
        alias: String,
    },
    MemoryWrote {
        entry_id: String,
    },
    NoopApplied {
        reason: String,
    },
    Aborted {
        reason: String,
    },
    Reversed {
        original_effect_id: String,
    },
}

impl Effect {
    pub fn compute_inverse(&self, prior_state: Option<&PriorState>) -> Inverse {
        match self {
            Self::VaultWrote { path, .. } => match prior_state {
                Some(PriorState::WroteOverExisting { body_before, .. }) => {
                    Inverse::RestoreVaultContent {
                        path: path.clone(),
                        body: body_before.clone(),
                    }
                }
                _ => Inverse::DeleteVault { path: path.clone() },
            },
            Self::VaultMoved { from, to } => Inverse::MoveVault {
                from: to.clone(),
                to: from.clone(),
            },
            Self::VaultDeleted { path, shadow_path } => Inverse::RestoreVaultFromShadow {
                path: path.clone(),
                shadow_path: shadow_path.clone(),
            },
            Self::ConceptCreated { canonical_name } => Inverse::RetractConcept {
                canonical_name: canonical_name.clone(),
            },
            Self::ConceptAliased {
                canonical_name,
                alias,
            } => Inverse::RemoveConceptAlias {
                canonical_name: canonical_name.clone(),
                alias: alias.clone(),
            },
            Self::MemoryWrote { entry_id } => Inverse::TombstoneMemory {
                entry_id: entry_id.clone(),
            },
            Self::NoopApplied { .. } | Self::Aborted { .. } | Self::Reversed { .. } => {
                Inverse::NotReversible
            }
        }
    }
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub enum PriorState {
    WroteOverExisting {
        body_before: String,
        body_before_sha256: String,
    },
    ConceptAlreadyExisted,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(tag = "inverse", rename_all = "snake_case")]
pub enum Inverse {
    DeleteVault {
        path: String,
    },
    RestoreVaultContent {
        path: String,
        body: String,
    },
    MoveVault {
        from: String,
        to: String,
    },
    RestoreVaultFromShadow {
        path: String,
        shadow_path: String,
    },
    RetractConcept {
        canonical_name: String,
    },
    RemoveConceptAlias {
        canonical_name: String,
        alias: String,
    },
    TombstoneMemory {
        entry_id: String,
    },
    NotReversible,
}

impl Inverse {
    pub fn is_reversible(&self) -> bool {
        !matches!(self, Self::NotReversible)
    }
}

#[derive(Serialize, Deserialize, Clone, Debug, Error, PartialEq)]
#[serde(tag = "kind", content = "context", rename_all = "snake_case")]
pub enum ApplyError {
    #[error("invalid intent: {0}")]
    InvalidIntent(String),
    #[error("io error: {0}")]
    IoError(String),
    #[error("permission denied: {0}")]
    PermissionDenied(String),
    #[error("conflict: {0}")]
    Conflict(String),
    #[error("circuit breaker is open")]
    BreakerOpen,
    #[error("permanent failure: {0}")]
    Permanent(String),
}

#[async_trait::async_trait]
pub trait IntentApplier: Send + Sync {
    async fn apply(&self, intent: Intent) -> Result<(Effect, Option<PriorState>), ApplyError>;
}
