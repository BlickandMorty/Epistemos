//! Applier: `prop_unlock` — set the companion's held prop.
//! Per DOCTRINE §7.5 the unlock makes the prop available in
//! customisation; if `auto_apply: true`, the prop is also set
//! immediately. Reversible.

use rusqlite::types::Value;
use serde_json::json;

use super::{
    field_change, preflight, ApplierError, ApplyOutcome, EpBoxContent,
    EpBoxManifest, EpBoxType,
};
use crate::adapters::applier::Applier;
use crate::companions::audit::AuditEventKind;
use crate::companions::registry::CompanionRegistry;
use crate::companions::{CompanionId, PropKind};
use crate::events::{ChangeCategory, ConfigDiff};

pub struct PropUnlockApplier;

impl Applier for PropUnlockApplier {
    fn type_tag() -> EpBoxType { EpBoxType::PropUnlock }

    fn apply(
        registry: &mut CompanionRegistry,
        companion_id: CompanionId,
        manifest: &EpBoxManifest,
        content: &EpBoxContent,
    ) -> Result<ApplyOutcome, ApplierError> {
        let companion = preflight(
            registry, companion_id, manifest, content, EpBoxType::PropUnlock
        )?;
        let (prop_slug, auto_apply) = match content {
            EpBoxContent::PropUnlock { prop, auto_apply } => (prop.clone(), *auto_apply),
            _ => unreachable!("type_tag matched in preflight"),
        };
        let prop_kind = PropKind::parse(&prop_slug).ok_or_else(|| {
            ApplierError::Validation(format!("unknown prop slug '{prop_slug}'"))
        })?;
        let prior = companion.prop;

        let diff_category = ChangeCategory::Config; // prop drives tool_affinities
        let diff = ConfigDiff {
            field_changes: vec![field_change(
                "prop",
                json!(prior.map(|p| p.as_str().to_string())),
                json!(prop_kind.as_str()),
                diff_category,
            )],
        };
        let audit_payload = json!({
            "epbox_id": manifest.id,
            "epbox_type": manifest.r#type.as_str(),
            "prop": prop_slug,
            "auto_apply": auto_apply,
            "field_changes": diff.field_changes,
        });
        // V1 always sets the prop column (the unlock surfaces the
        // option AND, when auto_apply is true, immediately holds
        // it). The Mailroom UX layer can branch on `auto_apply`
        // for messaging — at the data layer the change is the
        // same row mutation.
        registry.update_companion_fields(
            companion_id,
            &[("prop_ref", Value::Text(prop_kind.as_str().to_string()))],
            AuditEventKind::GiftBoxUnwrapped,
            audit_payload,
        )?;
        Ok(ApplyOutcome {
            epbox_id: manifest.id.clone(),
            epbox_type: manifest.r#type,
            diff,
            revert_blob: json!({
                "prior_prop": prior.map(|p| p.as_str().to_string())
            }),
        })
    }

    fn revert(
        registry: &mut CompanionRegistry,
        companion_id: CompanionId,
        applied: &ApplyOutcome,
    ) -> Result<(), ApplierError> {
        let prior_slug = applied.revert_blob["prior_prop"].clone();
        let prior_value = if prior_slug.is_null() {
            Value::Null
        } else {
            Value::Text(
                prior_slug
                    .as_str()
                    .ok_or_else(|| ApplierError::Validation(
                        "revert_blob.prior_prop neither null nor string".to_string()
                    ))?
                    .to_string(),
            )
        };
        let companion = registry
            .get(companion_id)?
            .ok_or_else(|| ApplierError::Validation(
                format!("unknown companion {}", companion_id)
            ))?;
        let current = companion.prop.map(|p| p.as_str().to_string());
        let diff = ConfigDiff {
            field_changes: vec![field_change(
                "prop",
                json!(current),
                prior_slug.clone(),
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
            &[("prop_ref", prior_value)],
            AuditEventKind::GiftBoxUnwrapped,
            audit_payload,
        )?;
        Ok(())
    }
}
