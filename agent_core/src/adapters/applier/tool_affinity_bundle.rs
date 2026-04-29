//! Applier: `tool_affinity_bundle` — enable / disable specific
//! tools in the companion's `tool_affinities` bitset. Reversible.
//!
//! DOCTRINE §5.5 Category A: tool_affinities is a real config
//! knob — it gates which MCP tools the companion is allowed to
//! invoke per §6.2 + §6.4.

use rusqlite::types::Value;
use serde_json::json;

use super::{
    field_change, preflight, ApplierError, ApplyOutcome, EpBoxContent,
    EpBoxManifest, EpBoxType,
};
use crate::adapters::applier::Applier;
use crate::companions::audit::AuditEventKind;
use crate::companions::registry::CompanionRegistry;
use crate::companions::{CompanionId, ToolAffinities, ToolKind};
use crate::events::{ChangeCategory, ConfigDiff};

pub struct ToolAffinityBundleApplier;

/// Map a tool slug string back to the typed `ToolKind` enum so
/// `ToolAffinities::add` / `remove` stays type-safe.
fn parse_tool(slug: &str) -> Option<ToolKind> {
    match slug {
        "code_edit" => Some(ToolKind::CodeEdit),
        "code_read" => Some(ToolKind::CodeRead),
        "test_run" => Some(ToolKind::TestRun),
        "git" => Some(ToolKind::Git),
        "note_create" => Some(ToolKind::NoteCreate),
        "note_read" => Some(ToolKind::NoteRead),
        "note_update" => Some(ToolKind::NoteUpdate),
        "web_search" => Some(ToolKind::WebSearch),
        "graph_search" => Some(ToolKind::GraphSearch),
        "vault_read" => Some(ToolKind::VaultRead),
        "vault_write" => Some(ToolKind::VaultWrite),
        "routing" => Some(ToolKind::Routing),
        "delegate" => Some(ToolKind::Delegate),
        "deep_think" => Some(ToolKind::DeepThink),
        "plan" => Some(ToolKind::Plan),
        _ => None,
    }
}

impl Applier for ToolAffinityBundleApplier {
    fn type_tag() -> EpBoxType { EpBoxType::ToolAffinityBundle }

    fn apply(
        registry: &mut CompanionRegistry,
        companion_id: CompanionId,
        manifest: &EpBoxManifest,
        content: &EpBoxContent,
    ) -> Result<ApplyOutcome, ApplierError> {
        let companion = preflight(
            registry, companion_id, manifest, content, EpBoxType::ToolAffinityBundle
        )?;
        let (enable, disable) = match content {
            EpBoxContent::ToolAffinityBundle { enable, disable } => (enable, disable),
            _ => unreachable!("type_tag matched in preflight"),
        };
        let prior = companion.tool_affinities;
        let mut next = prior;
        for slug in enable {
            let kind = parse_tool(slug).ok_or_else(|| {
                ApplierError::Validation(format!("unknown tool slug '{slug}'"))
            })?;
            next.add(kind);
        }
        for slug in disable {
            let kind = parse_tool(slug).ok_or_else(|| {
                ApplierError::Validation(format!("unknown tool slug '{slug}'"))
            })?;
            next.remove(kind);
        }
        let diff = ConfigDiff {
            field_changes: vec![field_change(
                "tool_affinities",
                json!(prior.bits()),
                json!(next.bits()),
                ChangeCategory::Config,
            )],
        };
        let audit_payload = json!({
            "epbox_id": manifest.id,
            "epbox_type": manifest.r#type.as_str(),
            "enable": enable,
            "disable": disable,
            "field_changes": diff.field_changes,
        });
        registry.update_companion_fields(
            companion_id,
            &[("tool_affinities", Value::Blob(next.bits().to_le_bytes().to_vec()))],
            AuditEventKind::GiftBoxUnwrapped,
            audit_payload,
        )?;
        Ok(ApplyOutcome {
            epbox_id: manifest.id.clone(),
            epbox_type: manifest.r#type,
            diff,
            revert_blob: json!({ "prior_tool_affinities": prior.bits() }),
        })
    }

    fn revert(
        registry: &mut CompanionRegistry,
        companion_id: CompanionId,
        applied: &ApplyOutcome,
    ) -> Result<(), ApplierError> {
        let prior_bits = applied.revert_blob["prior_tool_affinities"]
            .as_u64()
            .ok_or_else(|| ApplierError::Validation(
                "revert_blob missing prior_tool_affinities".to_string()
            ))?;
        let prior = ToolAffinities::from_bits(prior_bits);
        let companion = registry
            .get(companion_id)?
            .ok_or_else(|| ApplierError::Validation(
                format!("unknown companion {}", companion_id)
            ))?;
        let current = companion.tool_affinities;
        let diff = ConfigDiff {
            field_changes: vec![field_change(
                "tool_affinities",
                json!(current.bits()),
                json!(prior.bits()),
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
            &[("tool_affinities", Value::Blob(prior.bits().to_le_bytes().to_vec()))],
            AuditEventKind::GiftBoxUnwrapped,
            audit_payload,
        )?;
        Ok(())
    }
}
