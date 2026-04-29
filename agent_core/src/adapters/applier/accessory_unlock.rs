//! Applier: `accessory_unlock` — set the companion's
//! `accessory_ref` column. DOCTRINE §5.5 Category B (cosmetic).
//! Reversible.

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

pub struct AccessoryUnlockApplier;

impl Applier for AccessoryUnlockApplier {
    fn type_tag() -> EpBoxType { EpBoxType::AccessoryUnlock }

    fn apply(
        registry: &mut CompanionRegistry,
        companion_id: CompanionId,
        manifest: &EpBoxManifest,
        content: &EpBoxContent,
    ) -> Result<ApplyOutcome, ApplierError> {
        let companion = preflight(
            registry, companion_id, manifest, content, EpBoxType::AccessoryUnlock
        )?;
        let new_acc = match content {
            EpBoxContent::AccessoryUnlock { accessory } => accessory.clone(),
            _ => unreachable!("type_tag matched in preflight"),
        };
        let prior = companion.accessory_ref.clone();
        let diff = ConfigDiff {
            field_changes: vec![field_change(
                "accessory_ref",
                json!(prior.clone()),
                json!(new_acc.clone()),
                ChangeCategory::Cosmetic,
            )],
        };
        let audit_payload = json!({
            "epbox_id": manifest.id,
            "epbox_type": manifest.r#type.as_str(),
            "accessory": new_acc,
            "field_changes": diff.field_changes,
        });
        registry.update_companion_fields(
            companion_id,
            &[("accessory_ref", Value::Text(new_acc))],
            AuditEventKind::GiftBoxUnwrapped,
            audit_payload,
        )?;
        Ok(ApplyOutcome {
            epbox_id: manifest.id.clone(),
            epbox_type: manifest.r#type,
            diff,
            revert_blob: json!({ "prior_accessory_ref": prior }),
        })
    }

    fn revert(
        registry: &mut CompanionRegistry,
        companion_id: CompanionId,
        applied: &ApplyOutcome,
    ) -> Result<(), ApplierError> {
        let prior = applied.revert_blob["prior_accessory_ref"].clone();
        let prior_value = if prior.is_null() {
            Value::Null
        } else {
            Value::Text(
                prior
                    .as_str()
                    .ok_or_else(|| ApplierError::Validation(
                        "revert_blob.prior_accessory_ref neither null nor string".to_string()
                    ))?
                    .to_string(),
            )
        };
        let companion = registry
            .get(companion_id)?
            .ok_or_else(|| ApplierError::Validation(
                format!("unknown companion {}", companion_id)
            ))?;
        let current = companion.accessory_ref.clone();
        let diff = ConfigDiff {
            field_changes: vec![field_change(
                "accessory_ref",
                json!(current),
                prior.clone(),
                ChangeCategory::Cosmetic,
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
            &[("accessory_ref", prior_value)],
            AuditEventKind::GiftBoxUnwrapped,
            audit_payload,
        )?;
        Ok(())
    }
}
