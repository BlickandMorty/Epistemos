//! Companion audit ledger (S1; DOCTRINE §6.4, §10 honesty doctrine).
//!
//! Every companion lifecycle event — created, updated, archived,
//! adapter applied, palette changed — writes a row here. The ledger
//! is the canonical record per DOCTRINE §10: every cosmetic edit
//! either maps to a real config knob or is explicitly labeled
//! `cosmetic`. The audit row carries a JSON payload describing the
//! exact change so the Audit View (S14) can render "what changed,
//! when, and why" for any companion.
//!
//! S1 implements only `CompanionRegistered` and `CompanionArchived`
//! events — the rest of the variants are forward-references, defined
//! here so later slices (S6 workspace focus, S8 customization edits,
//! S11 adapter unwrap) can extend without churn to the schema.

use serde::{Deserialize, Serialize};

use super::CompanionId;

/// Discriminator for audit-log rows. Persisted as the `event_type`
/// column so the Audit View can filter without parsing the JSON
/// payload.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AuditEventKind {
    /// Companion created via the §6 creation transaction.
    CompanionRegistered,
    /// Cosmetic or config delta to an existing companion (§5.5
    /// Category A or B). Payload describes which fields changed.
    CompanionUpdated,
    /// Companion soft-archived (§3.5). Vault preserved on disk.
    CompanionArchived,
    /// Pro-only hard delete to `_trash` with TTL (§3.5).
    CompanionDeleted,
    /// `companion_activity_state_changed` (§3.2 transitions). Logged
    /// for completeness of the timeline; can be dense, so the Audit
    /// View may summarise.
    ActivityStateChanged,
    /// Workspace selection changed (§3.4 sidebar skin). Payload
    /// records old + new workspace id.
    WorkspaceFocused,
    /// Gift-box unwrapped (§7) with config diff — forward-ref for
    /// S11.
    GiftBoxUnwrapped,
}

impl AuditEventKind {
    pub fn as_str(self) -> &'static str {
        match self {
            AuditEventKind::CompanionRegistered => "companion_registered",
            AuditEventKind::CompanionUpdated => "companion_updated",
            AuditEventKind::CompanionArchived => "companion_archived",
            AuditEventKind::CompanionDeleted => "companion_deleted",
            AuditEventKind::ActivityStateChanged => "activity_state_changed",
            AuditEventKind::WorkspaceFocused => "workspace_focused",
            AuditEventKind::GiftBoxUnwrapped => "gift_box_unwrapped",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        match s {
            "companion_registered" => Some(AuditEventKind::CompanionRegistered),
            "companion_updated" => Some(AuditEventKind::CompanionUpdated),
            "companion_archived" => Some(AuditEventKind::CompanionArchived),
            "companion_deleted" => Some(AuditEventKind::CompanionDeleted),
            "activity_state_changed" => Some(AuditEventKind::ActivityStateChanged),
            "workspace_focused" => Some(AuditEventKind::WorkspaceFocused),
            "gift_box_unwrapped" => Some(AuditEventKind::GiftBoxUnwrapped),
            _ => None,
        }
    }
}

/// One audit-log row, as returned to callers reading the ledger.
/// Persisted JSON payload is parsed lazily — at S1 there is exactly
/// one shape (`CompanionRegisteredPayload`); later slices add more.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuditEntry {
    /// Auto-incrementing rowid. Stable for the lifetime of the DB.
    pub id: i64,
    pub companion_id: CompanionId,
    pub event_kind: AuditEventKind,
    /// Raw JSON payload. Use `payload_as::<T>()` for typed access.
    pub payload: serde_json::Value,
    pub created_at: String,
}

impl AuditEntry {
    /// Typed deserialisation of the payload. Returns `None` if the
    /// payload doesn't conform to `T`'s shape.
    pub fn payload_as<T: serde::de::DeserializeOwned>(&self) -> Option<T> {
        serde_json::from_value(self.payload.clone()).ok()
    }
}

/// Payload shape for `CompanionRegistered` audit rows. Mirrors the
/// DOCTRINE §6.4 example.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct CompanionRegisteredPayload {
    pub name: String,
    pub head_shape: String,
    pub palette: String,
    pub eyes: String,
    pub arms: String,
    pub prop: Option<String>,
    pub role: String,
    pub base_model: String,
    pub system_prompt_preset: String,
    pub tool_affinities: Vec<String>,
    pub vault_path: String,
    pub graph_slice: String,
    /// Optional preset label — the user may have started from
    /// "Claude Code worker (Block-Wide)" or arrived through Custom.
    pub preset: Option<String>,
    /// Wall-time elapsed for the §6.3 transaction in milliseconds.
    /// Bound by DOCTRINE §12 — should be ≤ 300 ms p95.
    pub registration_duration_ms: u64,
    /// Always `"user"` for V1; auto-generated companions land in V3.
    pub created_by: String,
}

/// Payload shape for `CompanionArchived` audit rows.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct CompanionArchivedPayload {
    pub reason: Option<String>,
    pub archived_at: String,
}
