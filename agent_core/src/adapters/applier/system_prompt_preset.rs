//! Applier: `system_prompt_preset` — swap the companion's
//! `system_prompt_preset` column. Reversible.
//!
//! DOCTRINE §5.5 Category A: this IS a real config knob — every
//! session prepends the new prompt preset. The audit ledger
//! records both the prior + new preset id so revert is exact.

use rusqlite::types::Value;
use serde_json::json;

use super::{
    field_change, preflight, ApplierError, ApplyOutcome, EpBoxContent,
    EpBoxManifest, EpBoxType,
};
use crate::adapters::applier::Applier;
use crate::companions::audit::AuditEventKind;
use crate::companions::registry::CompanionRegistry;
use crate::companions::CompanionId;
use crate::events::{ChangeCategory, ConfigDiff};

pub struct SystemPromptPresetApplier;

impl Applier for SystemPromptPresetApplier {
    fn type_tag() -> EpBoxType { EpBoxType::SystemPromptPreset }

    fn apply(
        registry: &mut CompanionRegistry,
        companion_id: CompanionId,
        manifest: &EpBoxManifest,
        content: &EpBoxContent,
    ) -> Result<ApplyOutcome, ApplierError> {
        let companion = preflight(
            registry, companion_id, manifest, content, EpBoxType::SystemPromptPreset
        )?;
        let new_preset = match content {
            EpBoxContent::SystemPromptPreset { preset_id, .. } => preset_id.clone(),
            _ => unreachable!("type_tag matched in preflight"),
        };
        let prior = companion.system_prompt_preset.clone();
        let diff = ConfigDiff {
            field_changes: vec![field_change(
                "system_prompt_preset",
                json!(prior.clone()),
                json!(new_preset.clone()),
                ChangeCategory::Config,
            )],
        };
        let audit_payload = json!({
            "epbox_id": manifest.id,
            "epbox_type": manifest.r#type.as_str(),
            "field_changes": diff.field_changes,
        });
        registry.update_companion_fields(
            companion_id,
            &[("system_prompt_preset", Value::Text(new_preset.clone()))],
            AuditEventKind::GiftBoxUnwrapped,
            audit_payload,
        )?;
        Ok(ApplyOutcome {
            epbox_id: manifest.id.clone(),
            epbox_type: manifest.r#type,
            diff,
            revert_blob: json!({ "prior_system_prompt_preset": prior }),
        })
    }

    fn revert(
        registry: &mut CompanionRegistry,
        companion_id: CompanionId,
        applied: &ApplyOutcome,
    ) -> Result<(), ApplierError> {
        let prior = applied.revert_blob["prior_system_prompt_preset"]
            .as_str()
            .ok_or_else(|| ApplierError::Validation(
                "revert_blob missing prior_system_prompt_preset".to_string()
            ))?
            .to_string();
        let companion = registry
            .get(companion_id)?
            .ok_or_else(|| ApplierError::Validation(
                format!("unknown companion {}", companion_id)
            ))?;
        let current = companion.system_prompt_preset.clone();
        let diff = ConfigDiff {
            field_changes: vec![field_change(
                "system_prompt_preset",
                json!(current),
                json!(prior.clone()),
                ChangeCategory::Config,
            )],
        };
        let audit_payload = json!({
            "epbox_id": applied.epbox_id,
            "epbox_type": applied.epbox_type.as_str(),
            "reverted": true,
            "field_changes": diff.field_changes,
        });
        registry.update_companion_fields(
            companion_id,
            &[("system_prompt_preset", Value::Text(prior))],
            AuditEventKind::GiftBoxUnwrapped,
            audit_payload,
        )?;
        Ok(())
    }
}
