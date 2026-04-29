//! Companion registry — SQLite-backed persistence for the canonical
//! `CompanionRegistry` per DOCTRINE §3.1 + §3.5 + §6.
//!
//! Schema lives inline (`CREATE TABLE IF NOT EXISTS`) at registry
//! open time, idempotent across launches. Three tables:
//!
//!   companions          — registry record per §3.1 + denormalized
//!                         model-profile fields (base_model,
//!                         system_prompt_preset, tool_affinities)
//!                         per §5.5
//!   companion_audit_log — one row per audit event per §6.4
//!   companion_adapters  — gift-box adapter applications (forward
//!                         reference for S11; schema lives here so
//!                         later slices add rows without migration)
//!
//! Per DOCTRINE I-7 Swift never mutates this — every change goes
//! through `CompanionRegistry`'s API. Per I-13 no `Date::now()` /
//! `arc4random` is used inside the simulation reducer; this module
//! is outside the reducer (creation flow runs as a control-plane
//! transaction, not a per-event reduce step), so SQLite's `datetime
//! ('now')` is acceptable for the persisted timestamp columns.

use std::path::{Path, PathBuf};

use rusqlite::{params, Connection, OptionalExtension};

use super::audit::{AuditEntry, AuditEventKind};
use super::{
    ArmStyle, ActivityTracker, Companion, CompanionId, EyeStyle, HeadShape, PropKind,
    ProviderRole, ToolAffinities,
};

/// Errors emitted by registry operations. Distinct from the
/// transaction-level `CreationError` which classifies which §6.3
/// step failed; this enum covers query / persistence / decode paths
/// that span multiple transactional flows.
#[derive(Debug, thiserror::Error)]
pub enum RegistryError {
    #[error("sqlite: {0}")]
    Sqlite(#[from] rusqlite::Error),
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("decode: column '{column}' had unexpected value '{value}'")]
    Decode { column: &'static str, value: String },
    #[error("not found: companion {0}")]
    NotFound(CompanionId),
    #[error("serde: {0}")]
    Serde(#[from] serde_json::Error),
    #[error("schema/validation: {0}")]
    Schema(String),
}

/// SQLite-backed companion registry. Single-threaded access via
/// `&mut self` — matches the existing `SessionPersistence` pattern
/// in this crate. Concurrent readers go through a `Mutex<Self>` at
/// the outer ownership layer (added by S5/S7 view-models when they
/// stream snapshots).
pub struct CompanionRegistry {
    db: Connection,
    activity: ActivityTracker,
}

impl CompanionRegistry {
    /// Open or create the registry's SQLite database. Idempotent
    /// across launches — running this on an existing DB applies
    /// `CREATE TABLE IF NOT EXISTS` and re-uses the existing rows.
    pub fn open(db_path: &Path) -> Result<Self, RegistryError> {
        if let Some(parent) = db_path.parent() {
            if !parent.as_os_str().is_empty() {
                std::fs::create_dir_all(parent)?;
            }
        }
        let db = Connection::open(db_path)?;
        Self::init_schema(&db)?;
        let activity = Self::seed_activity_from_persisted(&db)?;
        Ok(Self { db, activity })
    }

    /// Open an in-memory registry for tests.
    #[cfg(test)]
    pub fn open_in_memory() -> Result<Self, RegistryError> {
        let db = Connection::open_in_memory()?;
        Self::init_schema(&db)?;
        // Empty DB → no companions to restore → tracker stays
        // empty; new companions get registered as JustAcquired
        // via the creation flow.
        Ok(Self {
            db,
            activity: ActivityTracker::new(),
        })
    }

    /// Audit Finding #4 fix: restore activity state for every
    /// non-archived companion when the DB re-opens. Companions
    /// existing before this process started are seeded `Dormant`
    /// (DOCTRINE §3.2 "Dormant ≠ deleted") rather than
    /// `JustAcquired`, so the rainbow-flash entrance only fires
    /// for genuinely-new companions, never on every launch.
    fn seed_activity_from_persisted(db: &Connection) -> Result<ActivityTracker, RegistryError> {
        let mut tracker = ActivityTracker::new();
        let mut stmt = db.prepare(
            "SELECT id FROM companions WHERE archived_at IS NULL",
        )?;
        let mut rows = stmt.query([])?;
        while let Some(row) = rows.next()? {
            let id_s: String = row.get(0)?;
            if let Some(id) = CompanionId::parse(&id_s) {
                tracker.register_existing(id);
            }
            // If id parse fails the row is unrecoverable — log
            // via tracing rather than panicking; the audit
            // ledger will still surface the original creation
            // event for forensic recovery.
        }
        Ok(tracker)
    }

    fn init_schema(db: &Connection) -> Result<(), RegistryError> {
        db.execute_batch(
            "
            CREATE TABLE IF NOT EXISTS companions (
                id                    TEXT PRIMARY KEY,
                name                  TEXT NOT NULL UNIQUE,
                head_shape            TEXT NOT NULL,
                palette_ref           TEXT NOT NULL,
                eyes                  TEXT NOT NULL,
                arms                  TEXT NOT NULL,
                prop_ref              TEXT,
                accessory_ref         TEXT,
                role                  TEXT NOT NULL,
                base_model            TEXT NOT NULL,
                system_prompt_preset  TEXT NOT NULL,
                tool_affinities       BLOB NOT NULL,
                vault_path            TEXT NOT NULL UNIQUE,
                graph_slice           TEXT NOT NULL UNIQUE,
                created_at            TEXT NOT NULL,
                updated_at            TEXT NOT NULL,
                archived_at           TEXT,
                farm_position_x       REAL NOT NULL DEFAULT 0,
                farm_position_y       REAL NOT NULL DEFAULT 0,
                config_version        INTEGER NOT NULL DEFAULT 1
            );

            CREATE INDEX IF NOT EXISTS idx_companions_archived
                ON companions(archived_at) WHERE archived_at IS NULL;

            CREATE TABLE IF NOT EXISTS companion_audit_log (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                companion_id  TEXT NOT NULL,
                event_type    TEXT NOT NULL,
                payload       TEXT NOT NULL,
                created_at    TEXT NOT NULL,
                FOREIGN KEY(companion_id) REFERENCES companions(id)
            );

            CREATE INDEX IF NOT EXISTS idx_companion_audit_companion
                ON companion_audit_log(companion_id, created_at);

            CREATE TABLE IF NOT EXISTS companion_adapters (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                companion_id  TEXT NOT NULL,
                epbox_id      TEXT NOT NULL,
                epbox_type    TEXT NOT NULL,
                applied_at    TEXT NOT NULL,
                config_diff   TEXT NOT NULL,
                reversible    INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY(companion_id) REFERENCES companions(id)
            );

            CREATE INDEX IF NOT EXISTS idx_companion_adapters_companion
                ON companion_adapters(companion_id, applied_at);
            ",
        )?;
        Ok(())
    }

    pub fn connection(&self) -> &Connection {
        &self.db
    }

    pub(crate) fn connection_mut(&mut self) -> &mut Connection {
        &mut self.db
    }

    pub fn activity(&self) -> &ActivityTracker {
        &self.activity
    }

    pub fn activity_mut(&mut self) -> &mut ActivityTracker {
        &mut self.activity
    }

    /// Look up a companion by id. Returns `Ok(None)` if not present.
    pub fn get(&self, id: CompanionId) -> Result<Option<Companion>, RegistryError> {
        let row = self
            .db
            .query_row(
                "SELECT id, name, head_shape, palette_ref, eyes, arms, prop_ref, accessory_ref,
                        role, base_model, system_prompt_preset, tool_affinities,
                        vault_path, graph_slice, created_at, updated_at, archived_at,
                        farm_position_x, farm_position_y, config_version
                 FROM companions
                 WHERE id = ?1",
                params![id.to_string()],
                row_to_companion,
            )
            .optional()?;
        match row {
            Some(Ok(c)) => Ok(Some(c)),
            Some(Err(e)) => Err(e),
            None => Ok(None),
        }
    }

    /// List every active (non-archived) companion. Used by the
    /// Landing Farm view-model in S5; per DOCTRINE §3.2 the farm
    /// shows "ALL companions in the registry … regardless of
    /// activity state," so this is the canonical source.
    pub fn list_active(&self) -> Result<Vec<Companion>, RegistryError> {
        self.list_with_filter("archived_at IS NULL")
    }

    /// List every companion, including archived ones. Used by the
    /// Audit View (S14) and disaster-recovery flows.
    pub fn list_all(&self) -> Result<Vec<Companion>, RegistryError> {
        self.list_with_filter("1 = 1")
    }

    fn list_with_filter(&self, filter: &str) -> Result<Vec<Companion>, RegistryError> {
        let sql = format!(
            "SELECT id, name, head_shape, palette_ref, eyes, arms, prop_ref, accessory_ref,
                    role, base_model, system_prompt_preset, tool_affinities,
                    vault_path, graph_slice, created_at, updated_at, archived_at,
                    farm_position_x, farm_position_y, config_version
             FROM companions
             WHERE {filter}
             ORDER BY created_at"
        );
        let mut stmt = self.db.prepare(&sql)?;
        let mut out = Vec::new();
        let mut rows = stmt.query([])?;
        while let Some(row) = rows.next()? {
            out.push(row_to_companion(row)??);
        }
        Ok(out)
    }

    /// Soft-archive a companion. Per DOCTRINE §3.5 the row stays in
    /// SQLite, vault is preserved on disk, and the entry is removed
    /// from all three placement views via the activity tracker.
    pub fn archive(
        &mut self,
        id: CompanionId,
        reason: Option<&str>,
    ) -> Result<(), RegistryError> {
        let now = sqlite_now(&self.db)?;
        let updated = self.db.execute(
            "UPDATE companions
             SET archived_at = ?2, updated_at = ?2
             WHERE id = ?1 AND archived_at IS NULL",
            params![id.to_string(), &now],
        )?;
        if updated == 0 {
            // Either the companion doesn't exist or it was already
            // archived — both are no-ops, but we surface NotFound if
            // truly missing so callers can distinguish.
            if self.get(id)?.is_none() {
                return Err(RegistryError::NotFound(id));
            }
            return Ok(());
        }
        // Audit row.
        let payload = serde_json::json!({
            "reason": reason,
            "archived_at": &now,
        });
        self.db.execute(
            "INSERT INTO companion_audit_log
                (companion_id, event_type, payload, created_at)
             VALUES (?1, ?2, ?3, ?4)",
            params![
                id.to_string(),
                AuditEventKind::CompanionArchived.as_str(),
                payload.to_string(),
                &now,
            ],
        )?;
        // Drop from the activity tracker — Active/Recent/Dormant/
        // Parked is meaningless for archived companions.
        self.activity.unregister(id);
        Ok(())
    }

    /// Update one or more columns on a companion row + write the
    /// matching `CompanionUpdated` audit entry. Used by the S11
    /// adapter appliers to atomically mutate a companion's
    /// `system_prompt_preset` / `tool_affinities` / `prop` /
    /// `palette_ref` / `accessory_ref` columns.
    ///
    /// `setters` is a list of `(column_name, sqlite_value)`
    /// pairs. The column allowlist is hard-coded — any column
    /// name not in the allowlist is rejected as a validation
    /// error so callers can't smuggle a SQL fragment in.
    pub fn update_companion_fields(
        &mut self,
        id: CompanionId,
        setters: &[(&'static str, rusqlite::types::Value)],
        audit_kind: AuditEventKind,
        audit_payload: serde_json::Value,
    ) -> Result<(), RegistryError> {
        const ALLOWED: &[&str] = &[
            "system_prompt_preset",
            "tool_affinities",
            "prop_ref",
            "palette_ref",
            "accessory_ref",
        ];
        for (col, _) in setters {
            if !ALLOWED.contains(col) {
                return Err(RegistryError::Schema(format!(
                    "column '{col}' not in allowlist"
                )));
            }
        }
        if setters.is_empty() {
            return Ok(());
        }
        let now = sqlite_now(&self.db)?;

        // Placeholder layout: ?1..?N for column values, ?N+1 for
        // the new updated_at timestamp, ?N+2 for the WHERE id.
        let assignments: String = setters
            .iter()
            .enumerate()
            .map(|(i, (col, _))| format!("{col} = ?{}", i + 1))
            .collect::<Vec<_>>()
            .join(", ");
        let now_index = setters.len() + 1;
        let id_index = setters.len() + 2;
        let sql = format!(
            "UPDATE companions
             SET {assignments}, updated_at = ?{now_index}, config_version = config_version + 1
             WHERE id = ?{id_index} AND archived_at IS NULL"
        );
        let mut params_vec: Vec<rusqlite::types::Value> = Vec::with_capacity(setters.len() + 2);
        for (_, v) in setters {
            params_vec.push(v.clone());
        }
        params_vec.push(rusqlite::types::Value::Text(now.clone()));
        params_vec.push(rusqlite::types::Value::Text(id.to_string()));
        let updated = self.db.execute(
            &sql,
            rusqlite::params_from_iter(params_vec.iter()),
        )?;
        if updated == 0 {
            if self.get(id)?.is_none() {
                return Err(RegistryError::NotFound(id));
            }
            // Archived — refuse to mutate.
            return Err(RegistryError::Schema(format!(
                "companion {} is archived; cannot apply update",
                id
            )));
        }
        self.db.execute(
            "INSERT INTO companion_audit_log
                (companion_id, event_type, payload, created_at)
             VALUES (?1, ?2, ?3, ?4)",
            params![
                id.to_string(),
                audit_kind.as_str(),
                audit_payload.to_string(),
                &now,
            ],
        )?;
        Ok(())
    }

    /// Read the full audit log for a companion in chronological
    /// order. Used by the Audit View "Why is this happening?"
    /// surface (DOCTRINE §9.3).
    pub fn audit_log(&self, id: CompanionId) -> Result<Vec<AuditEntry>, RegistryError> {
        let mut stmt = self.db.prepare(
            "SELECT id, companion_id, event_type, payload, created_at
             FROM companion_audit_log
             WHERE companion_id = ?1
             ORDER BY id",
        )?;
        let mut rows = stmt.query(params![id.to_string()])?;
        let mut out = Vec::new();
        while let Some(row) = rows.next()? {
            let row_id: i64 = row.get(0)?;
            let cid: String = row.get(1)?;
            let kind_s: String = row.get(2)?;
            let payload_s: String = row.get(3)?;
            let created_at: String = row.get(4)?;
            let companion_id = CompanionId::parse(&cid).ok_or_else(|| {
                RegistryError::Decode {
                    column: "companion_id",
                    value: cid.clone(),
                }
            })?;
            let event_kind = AuditEventKind::parse(&kind_s).ok_or_else(|| {
                RegistryError::Decode {
                    column: "event_type",
                    value: kind_s.clone(),
                }
            })?;
            let payload: serde_json::Value = serde_json::from_str(&payload_s)?;
            out.push(AuditEntry {
                id: row_id,
                companion_id,
                event_kind,
                payload,
                created_at,
            });
        }
        Ok(out)
    }
}

/// Helper: ask SQLite for its UTC timestamp. Used for both
/// `created_at`/`updated_at` row inserts and audit-log timestamps.
/// Per I-13, the simulation reducer never calls this — registry
/// operations are control-plane only.
pub(crate) fn sqlite_now(db: &Connection) -> Result<String, RegistryError> {
    let s: String = db.query_row("SELECT datetime('now')", [], |row| row.get(0))?;
    Ok(s)
}

/// Decode one row of the `companions` table into a `Companion`.
/// Returns `Ok(Err(_))` for decode failures so the caller can
/// distinguish row-decode errors from row-not-found.
pub(crate) fn row_to_companion(
    row: &rusqlite::Row<'_>,
) -> rusqlite::Result<Result<Companion, RegistryError>> {
    let id_s: String = row.get(0)?;
    let id = match CompanionId::parse(&id_s) {
        Some(v) => v,
        None => {
            return Ok(Err(RegistryError::Decode {
                column: "id",
                value: id_s,
            }))
        }
    };
    let name: String = row.get(1)?;
    let head_shape_s: String = row.get(2)?;
    let head_shape = match HeadShape::parse(&head_shape_s) {
        Some(v) => v,
        None => {
            return Ok(Err(RegistryError::Decode {
                column: "head_shape",
                value: head_shape_s,
            }))
        }
    };
    let palette_ref: String = row.get(3)?;
    let eyes_s: String = row.get(4)?;
    let eyes = match EyeStyle::parse(&eyes_s) {
        Some(v) => v,
        None => {
            return Ok(Err(RegistryError::Decode {
                column: "eyes",
                value: eyes_s,
            }))
        }
    };
    let arms_s: String = row.get(5)?;
    let arms = match ArmStyle::parse(&arms_s) {
        Some(v) => v,
        None => {
            return Ok(Err(RegistryError::Decode {
                column: "arms",
                value: arms_s,
            }))
        }
    };
    let prop_ref_s: Option<String> = row.get(6)?;
    let prop = match prop_ref_s {
        Some(s) => match PropKind::parse(&s) {
            Some(v) => Some(v),
            None => {
                return Ok(Err(RegistryError::Decode {
                    column: "prop_ref",
                    value: s,
                }))
            }
        },
        None => None,
    };
    let accessory_ref: Option<String> = row.get(7)?;
    let role_s: String = row.get(8)?;
    let role = match ProviderRole::parse(&role_s) {
        Some(v) => v,
        None => {
            return Ok(Err(RegistryError::Decode {
                column: "role",
                value: role_s,
            }))
        }
    };
    let base_model: String = row.get(9)?;
    let system_prompt_preset: String = row.get(10)?;
    let tool_affinities_blob: Vec<u8> = row.get(11)?;
    let tool_affinities = if tool_affinities_blob.len() == 8 {
        let mut bytes = [0u8; 8];
        bytes.copy_from_slice(&tool_affinities_blob);
        ToolAffinities::from_le_bytes(bytes)
    } else {
        return Ok(Err(RegistryError::Decode {
            column: "tool_affinities",
            value: format!("{} bytes", tool_affinities_blob.len()),
        }));
    };
    let vault_path: String = row.get(12)?;
    let graph_slice: String = row.get(13)?;
    let created_at: String = row.get(14)?;
    let updated_at: String = row.get(15)?;
    let archived_at: Option<String> = row.get(16)?;
    let farm_x: f64 = row.get(17)?;
    let farm_y: f64 = row.get(18)?;
    let config_version: i64 = row.get(19)?;

    Ok(Ok(Companion {
        id,
        name,
        head_shape,
        palette_ref,
        eyes,
        arms,
        prop,
        accessory_ref,
        role,
        base_model,
        system_prompt_preset,
        tool_affinities,
        vault_path: PathBuf::from(vault_path),
        graph_slice,
        created_at,
        updated_at,
        archived_at,
        farm_position: (farm_x as f32, farm_y as f32),
        config_version: config_version as u32,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fresh_registry_has_no_companions() {
        let r = CompanionRegistry::open_in_memory().unwrap();
        assert!(r.list_active().unwrap().is_empty());
        assert!(r.list_all().unwrap().is_empty());
    }

    #[test]
    fn schema_init_is_idempotent() {
        // Open a registry, close it, re-open the same DB file —
        // schema should still be intact, no errors.
        let tmp = tempfile::tempdir().unwrap();
        let db_path = tmp.path().join("registry.db");
        {
            let _r = CompanionRegistry::open(&db_path).unwrap();
        }
        // Re-open. Should not error and should still be empty.
        let r2 = CompanionRegistry::open(&db_path).unwrap();
        assert!(r2.list_active().unwrap().is_empty());
        // Tables should be present — verify via a query.
        let count: i64 = r2
            .db
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master
                 WHERE type='table' AND name IN
                   ('companions','companion_audit_log','companion_adapters')",
                [],
                |row| row.get(0),
            )
            .unwrap();
        assert_eq!(count, 3);
    }

    #[test]
    fn missing_companion_returns_none() {
        let r = CompanionRegistry::open_in_memory().unwrap();
        let id = CompanionId::new_ulid();
        assert!(r.get(id).unwrap().is_none());
    }

    #[test]
    fn archive_missing_companion_returns_not_found() {
        let mut r = CompanionRegistry::open_in_memory().unwrap();
        let id = CompanionId::new_ulid();
        let err = r.archive(id, None).unwrap_err();
        assert!(matches!(err, RegistryError::NotFound(_)));
    }

    #[test]
    fn reopen_seeds_existing_companions_as_dormant() {
        // Audit Finding #4: across a process restart, existing
        // companions should restore as Dormant (NOT JustAcquired,
        // which would flash a rainbow entrance every launch).
        use crate::companions::{
            ActivityState, ArmStyle, CompanionSpec, EyeStyle, HeadShape, PropKind,
            ProviderRole, ToolAffinities,
        };
        use crate::companions::transaction::create_companion;

        let tmp = tempfile::tempdir().unwrap();
        let db_path = tmp.path().join("registry.db");
        let vault_root = tmp.path();

        // First-run: create two companions through the canonical
        // flow. They land as JustAcquired in this session.
        let alice_id;
        {
            let mut r = CompanionRegistry::open(&db_path).unwrap();
            let spec = |name: &str| CompanionSpec {
                name: name.to_string(),
                head_shape: HeadShape::Block,
                palette_ref: "claude_warm_v1".to_string(),
                eyes: EyeStyle::NegativeSpace,
                arms: ArmStyle::None,
                prop: Some(PropKind::Wrench),
                accessory_ref: None,
                role: ProviderRole::CodeWorker,
                base_model: "claude-sonnet-4-6".to_string(),
                system_prompt_preset: "careful_reviewer_v1".to_string(),
                tool_affinities: ToolAffinities::from_prop(PropKind::Wrench),
                vault_path: vault_root.join("Companions").join(name),
                farm_position: (0.0, 0.0),
            };
            let alice = create_companion(&mut r, spec("Alice"), vault_root).unwrap();
            let _bob = create_companion(&mut r, spec("Bob"), vault_root).unwrap();
            alice_id = alice.id;
            assert_eq!(
                r.activity().state(alice_id),
                Some(ActivityState::JustAcquired),
                "first-session creates as JustAcquired"
            );
        }

        // Second-run: reopen the same DB. Companions should
        // restore as Dormant.
        let r = CompanionRegistry::open(&db_path).unwrap();
        assert_eq!(
            r.activity().state(alice_id),
            Some(ActivityState::Dormant),
            "post-restart restoration seeds Dormant per Finding #4"
        );
        // Both companions tracked.
        assert_eq!(r.activity().iter().count(), 2);
    }

    #[test]
    fn reopen_does_not_restore_archived_companions() {
        use crate::companions::transaction::create_companion;
        use crate::companions::{
            ArmStyle, CompanionSpec, EyeStyle, HeadShape, PropKind, ProviderRole,
            ToolAffinities,
        };

        let tmp = tempfile::tempdir().unwrap();
        let db_path = tmp.path().join("registry.db");
        let vault_root = tmp.path();

        let archived_id;
        {
            let mut r = CompanionRegistry::open(&db_path).unwrap();
            let spec = CompanionSpec {
                name: "Archived".to_string(),
                head_shape: HeadShape::Block,
                palette_ref: "claude_warm_v1".to_string(),
                eyes: EyeStyle::Round,
                arms: ArmStyle::None,
                prop: None,
                accessory_ref: None,
                role: ProviderRole::Worker,
                base_model: "m".to_string(),
                system_prompt_preset: "p".to_string(),
                tool_affinities: ToolAffinities::empty(),
                vault_path: vault_root.join("Companions").join("Archived"),
                farm_position: (0.0, 0.0),
            };
            let companion = create_companion(&mut r, spec, vault_root).unwrap();
            archived_id = companion.id;
            r.archive(archived_id, None).unwrap();
        }

        // Reopen: the archived companion must not reappear in
        // the activity tracker.
        let r = CompanionRegistry::open(&db_path).unwrap();
        assert!(r.activity().state(archived_id).is_none());
    }
}
