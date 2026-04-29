//! Appliers — one per V1 content type. Each applier mutates the
//! companion record + emits the §6.4 audit ledger entry per
//! DOCTRINE §7.5.
//!
//! All appliers share the `Applier` trait so the bridge can
//! dispatch by content tag.

use serde_json::Value as JsonValue;

use crate::companions::registry::{CompanionRegistry, RegistryError};
use crate::companions::{Companion, CompanionId};
use crate::events::{ChangeCategory, ConfigDiff, FieldChange};

use super::epbox::{EpBoxContent, EpBoxManifest, EpBoxType};

pub mod accessory_unlock;
pub mod palette_unlock;
pub mod prop_unlock;
pub mod system_prompt_preset;
pub mod tool_affinity_bundle;

/// Applier trait — every content type implements `apply` and
/// (when reversible) `revert`.
pub trait Applier {
    fn type_tag() -> EpBoxType
    where
        Self: Sized;

    fn apply(
        registry: &mut CompanionRegistry,
        companion_id: CompanionId,
        manifest: &EpBoxManifest,
        content: &EpBoxContent,
    ) -> Result<ApplyOutcome, ApplierError>;

    fn revert(
        registry: &mut CompanionRegistry,
        companion_id: CompanionId,
        applied: &ApplyOutcome,
    ) -> Result<(), ApplierError>;
}

/// Result of a successful apply. Carries the diff for the audit
/// ledger + the (cosmetic) revert payload so reversible adapters
/// can be undone via the Mailroom UI.
#[derive(Debug, Clone, PartialEq)]
pub struct ApplyOutcome {
    pub epbox_id: String,
    pub epbox_type: EpBoxType,
    pub diff: ConfigDiff,
    pub revert_blob: JsonValue,
}

#[derive(Debug, thiserror::Error)]
pub enum ApplierError {
    #[error("registry: {0}")]
    Registry(#[from] RegistryError),
    #[error("sqlite: {0}")]
    Sqlite(#[from] rusqlite::Error),
    #[error("type mismatch: applier for {expected:?}, manifest declares {actual:?}")]
    TypeMismatch {
        expected: EpBoxType,
        actual: EpBoxType,
    },
    #[error("applies_to: companion role {role:?} or model {model:?} not allowed by manifest")]
    AppliesToMismatch {
        role: String,
        model: String,
    },
    #[error("validation: {0}")]
    Validation(String),
}

/// Shared pre-flight: load the companion + assert applies_to
/// matches + assert manifest type matches the applier's type.
pub fn preflight(
    registry: &mut CompanionRegistry,
    companion_id: CompanionId,
    manifest: &EpBoxManifest,
    content: &EpBoxContent,
    expected_type: EpBoxType,
) -> Result<Companion, ApplierError> {
    if manifest.r#type != expected_type {
        return Err(ApplierError::TypeMismatch {
            expected: expected_type,
            actual: manifest.r#type,
        });
    }
    if content.type_tag() != expected_type {
        return Err(ApplierError::TypeMismatch {
            expected: expected_type,
            actual: content.type_tag(),
        });
    }
    let companion = registry
        .get(companion_id)?
        .ok_or_else(|| {
            ApplierError::Validation(format!(
                "unknown companion {}",
                companion_id
            ))
        })?;
    if !manifest
        .applies_to
        .matches(companion.role.as_str(), &companion.base_model)
    {
        return Err(ApplierError::AppliesToMismatch {
            role: companion.role.as_str().to_string(),
            model: companion.base_model.clone(),
        });
    }
    Ok(companion)
}

/// Helper: build a `FieldChange` with `from` / `to` JSON values.
pub fn field_change(
    field: &str,
    from: JsonValue,
    to: JsonValue,
    category: ChangeCategory,
) -> FieldChange {
    FieldChange {
        field: field.to_string(),
        from,
        to,
        category,
    }
}
