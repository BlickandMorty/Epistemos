//! Applier: `palette_unlock` — surface a new palette option
//! for the companion. Per DOCTRINE §7.5 V1 unlocks DON'T auto-
//! apply (the user picks the palette in the customisation
//! sheet); we record the unlock in the audit ledger for the
//! Audit View. Cosmetic-only at the row level — the actual
//! palette switch happens via a separate `update_companion`
//! call when the user accepts.

use serde_json::json;

use super::{
    preflight, ApplierError, ApplyOutcome, EpBoxContent, EpBoxManifest, EpBoxType,
};
use crate::adapters::applier::Applier;
use crate::companions::audit::AuditEventKind;
use crate::companions::registry::CompanionRegistry;
use crate::companions::CompanionId;
use crate::events::ConfigDiff;

pub struct PaletteUnlockApplier;

impl Applier for PaletteUnlockApplier {
    fn type_tag() -> EpBoxType { EpBoxType::PaletteUnlock }

    fn apply(
        registry: &mut CompanionRegistry,
        companion_id: CompanionId,
        manifest: &EpBoxManifest,
        content: &EpBoxContent,
    ) -> Result<ApplyOutcome, ApplierError> {
        let _companion = preflight(
            registry, companion_id, manifest, content, EpBoxType::PaletteUnlock
        )?;
        let palette_ref = match content {
            EpBoxContent::PaletteUnlock { palette_ref } => palette_ref.clone(),
            _ => unreachable!("type_tag matched in preflight"),
        };
        let diff = ConfigDiff::empty();
        // We DON'T mutate the row — palette unlocks surface in
        // customisation. Just record the audit row directly.
        let now = registry.connection().query_row(
            "SELECT strftime('%Y-%m-%dT%H:%M:%fZ', 'now')",
            [],
            |row| row.get::<_, String>(0),
        )?;
        let audit_payload = json!({
            "epbox_id": manifest.id,
            "epbox_type": manifest.r#type.as_str(),
            "palette_ref": palette_ref,
            "unlock_only": true,
        });
        registry.connection().execute(
            "INSERT INTO companion_audit_log
                (companion_id, event_type, payload, created_at)
             VALUES (?1, ?2, ?3, ?4)",
            rusqlite::params![
                companion_id.to_string(),
                AuditEventKind::GiftBoxUnwrapped.as_str(),
                audit_payload.to_string(),
                &now,
            ],
        )?;
        Ok(ApplyOutcome {
            epbox_id: manifest.id.clone(),
            epbox_type: manifest.r#type,
            diff,
            revert_blob: json!({ "unlocked_palette": palette_ref }),
        })
    }

    fn revert(
        registry: &mut CompanionRegistry,
        companion_id: CompanionId,
        applied: &ApplyOutcome,
    ) -> Result<(), ApplierError> {
        // Unlocks don't mutate the row — revert is a no-op at
        // the data layer. We DO write a `reverted: true` audit
        // entry so the timeline shows the user undid the unlock.
        let now = registry.connection().query_row(
            "SELECT strftime('%Y-%m-%dT%H:%M:%fZ', 'now')",
            [],
            |row| row.get::<_, String>(0),
        )?;
        let audit_payload = json!({
            "epbox_id": applied.epbox_id,
            "epbox_type": applied.epbox_type.as_str(),
            "reverted": true,
            "unlock_only": true,
        });
        registry.connection().execute(
            "INSERT INTO companion_audit_log
                (companion_id, event_type, payload, created_at)
             VALUES (?1, ?2, ?3, ?4)",
            rusqlite::params![
                companion_id.to_string(),
                AuditEventKind::GiftBoxUnwrapped.as_str(),
                audit_payload.to_string(),
                &now,
            ],
        )?;
        Ok(())
    }
}
