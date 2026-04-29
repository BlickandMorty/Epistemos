//! Plan §8.5 — Universal undo log.
//!
//! Every applied `Effect` is appended to `undo_events.sqlite` with the
//! pre-computed inverse. ⌘Z within 24h reverses any auto-decision in
//! <100ms. The inverse is computed at intent-apply time per §8.5 so
//! undo always works even if the world has moved on.
//!
//! Schema (verbatim §8.5):
//!
//! ```sql
//! CREATE TABLE undo_events (
//!   id INTEGER PRIMARY KEY,
//!   ts TEXT NOT NULL,
//!   session_id TEXT NOT NULL,
//!   intent JSON NOT NULL,
//!   effect JSON NOT NULL,
//!   inverse JSON NOT NULL,
//!   ttl_until TEXT NOT NULL,
//!   undone INTEGER NOT NULL DEFAULT 0
//! );
//! CREATE INDEX undo_ttl ON undo_events (ttl_until);
//! ```
//!
//! TTL: 24h for routine Effects (FINAL_SYNTHESIS §6 D3); 7 days for
//! auto-research wins from Wave 8 NightBrain. Default 24h.

use std::path::Path;
use std::sync::Mutex;
use std::time::Duration;

use chrono::{DateTime, Utc};
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use thiserror::Error;

use crate::effect::{Effect, Inverse};
use crate::format::intent::Intent;

const SCHEMA_SQL: &str = r#"
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;

CREATE TABLE IF NOT EXISTS undo_events (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    ts          TEXT NOT NULL,
    session_id  TEXT NOT NULL,
    intent      TEXT NOT NULL,
    effect      TEXT NOT NULL,
    inverse     TEXT NOT NULL,
    ttl_until   TEXT NOT NULL,
    undone      INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS undo_ttl ON undo_events (ttl_until);
CREATE INDEX IF NOT EXISTS undo_session ON undo_events (session_id, ts);
"#;

/// Default per §8.5: routine Effects are reversible for 24h.
pub const DEFAULT_TTL: Duration = Duration::from_secs(24 * 60 * 60);

/// Auto-research wins (Wave 8) get 7 days per FINAL_SYNTHESIS §6 D3.
pub const AUTO_RESEARCH_TTL: Duration = Duration::from_secs(7 * 24 * 60 * 60);

#[derive(Debug, Error)]
pub enum UndoLogError {
    #[error("sqlite error: {0}")]
    Sqlite(#[from] rusqlite::Error),
    #[error("serialize error: {0}")]
    Serialize(String),
    #[error("entry not found: id={0}")]
    NotFound(i64),
    #[error("entry already undone: id={0}")]
    AlreadyUndone(i64),
    #[error("entry expired (ttl_until {ttl_until} < now)")]
    Expired { ttl_until: String },
}

/// One row in `undo_events`. Carries everything needed to render the
/// undo HUD and to apply the inverse at ⌘Z time without any
/// intent-time foreign-key lookup.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct UndoEntry {
    /// `None` on insert (assigned by SQLite).
    pub id: Option<i64>,
    pub ts: DateTime<Utc>,
    pub session_id: String,
    pub intent: Intent,
    pub effect: Effect,
    pub inverse: Inverse,
    pub ttl_until: DateTime<Utc>,
    pub undone: bool,
}

impl UndoEntry {
    /// Build an entry from an Intent + applied Effect + computed
    /// Inverse. Sets `ts` to now, `ttl_until` to now + DEFAULT_TTL,
    /// `undone` to false.
    pub fn new(
        session_id: String,
        intent: Intent,
        effect: Effect,
        inverse: Inverse,
    ) -> Self {
        Self::with_ttl(session_id, intent, effect, inverse, DEFAULT_TTL)
    }

    pub fn with_ttl(
        session_id: String,
        intent: Intent,
        effect: Effect,
        inverse: Inverse,
        ttl: Duration,
    ) -> Self {
        let now = Utc::now();
        let ttl_chrono = chrono::Duration::from_std(ttl).unwrap_or(chrono::Duration::hours(24));
        Self {
            id: None,
            ts: now,
            session_id,
            intent,
            effect,
            inverse,
            ttl_until: now + ttl_chrono,
            undone: false,
        }
    }
}

/// SQLite-backed undo event log per §8.5.
pub struct UndoLog {
    conn: Mutex<Connection>,
}

impl UndoLog {
    /// Open at the canonical path under the vault: `<vault>/.epistemos/undo_events.sqlite`.
    pub fn open(path: &Path) -> Result<Self, UndoLogError> {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).map_err(|e| {
                UndoLogError::Sqlite(rusqlite::Error::ToSqlConversionFailure(Box::new(e)))
            })?;
        }
        let conn = Connection::open(path)?;
        conn.execute_batch(SCHEMA_SQL)?;
        Ok(Self {
            conn: Mutex::new(conn),
        })
    }

    /// In-memory backend for tests; matches `open()` schema exactly.
    pub fn open_in_memory() -> Result<Self, UndoLogError> {
        let conn = Connection::open(":memory:")?;
        conn.execute_batch(SCHEMA_SQL)?;
        Ok(Self {
            conn: Mutex::new(conn),
        })
    }

    /// Append one undo event. Returns the assigned row id.
    pub fn append(&self, entry: &UndoEntry) -> Result<i64, UndoLogError> {
        let intent_json = serde_json::to_string(&entry.intent)
            .map_err(|e| UndoLogError::Serialize(e.to_string()))?;
        let effect_json = serde_json::to_string(&entry.effect)
            .map_err(|e| UndoLogError::Serialize(e.to_string()))?;
        let inverse_json = serde_json::to_string(&entry.inverse)
            .map_err(|e| UndoLogError::Serialize(e.to_string()))?;

        let g = self.conn.lock().expect("undo_events mutex poisoned");
        g.execute(
            "INSERT INTO undo_events
             (ts, session_id, intent, effect, inverse, ttl_until, undone)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![
                entry.ts.to_rfc3339(),
                entry.session_id,
                intent_json,
                effect_json,
                inverse_json,
                entry.ttl_until.to_rfc3339(),
                entry.undone as i32,
            ],
        )?;
        Ok(g.last_insert_rowid())
    }

    /// Fetch a single entry by id. Returns `NotFound` if absent.
    pub fn get(&self, id: i64) -> Result<UndoEntry, UndoLogError> {
        let g = self.conn.lock().expect("undo_events mutex poisoned");
        let mut stmt = g.prepare(
            "SELECT id, ts, session_id, intent, effect, inverse, ttl_until, undone
             FROM undo_events WHERE id = ?1",
        )?;
        let mut rows = stmt.query(params![id])?;
        match rows.next()? {
            Some(row) => row_to_entry(row),
            None => Err(UndoLogError::NotFound(id)),
        }
    }

    /// List the last `limit` entries for `session_id`, newest first.
    /// Used by the ⌘Z HUD per §8.5: "lists the last N reversible
    /// effects."
    pub fn recent(
        &self,
        session_id: &str,
        limit: usize,
    ) -> Result<Vec<UndoEntry>, UndoLogError> {
        let g = self.conn.lock().expect("undo_events mutex poisoned");
        let mut stmt = g.prepare(
            "SELECT id, ts, session_id, intent, effect, inverse, ttl_until, undone
             FROM undo_events
             WHERE session_id = ?1
             ORDER BY ts DESC
             LIMIT ?2",
        )?;
        let mut rows = stmt.query(params![session_id, limit as i64])?;
        let mut out = Vec::new();
        while let Some(row) = rows.next()? {
            out.push(row_to_entry(row)?);
        }
        Ok(out)
    }

    /// Mark an entry as undone. Validates: not already undone, TTL not
    /// expired. Returns the `Inverse` to apply.
    pub fn mark_undone(&self, id: i64) -> Result<Inverse, UndoLogError> {
        let entry = self.get(id)?;
        if entry.undone {
            return Err(UndoLogError::AlreadyUndone(id));
        }
        if entry.ttl_until < Utc::now() {
            return Err(UndoLogError::Expired {
                ttl_until: entry.ttl_until.to_rfc3339(),
            });
        }
        let g = self.conn.lock().expect("undo_events mutex poisoned");
        g.execute(
            "UPDATE undo_events SET undone = 1 WHERE id = ?1",
            params![id],
        )?;
        Ok(entry.inverse)
    }

    /// NightBrain eviction job (§8.5). Deletes entries past their
    /// `ttl_until`. Returns the number deleted.
    pub fn evict_expired(&self) -> Result<usize, UndoLogError> {
        let g = self.conn.lock().expect("undo_events mutex poisoned");
        let n = g.execute(
            "DELETE FROM undo_events WHERE ttl_until < ?1",
            params![Utc::now().to_rfc3339()],
        )?;
        Ok(n)
    }

    /// Total row count (test/diagnostic).
    pub fn len(&self) -> Result<usize, UndoLogError> {
        let g = self.conn.lock().expect("undo_events mutex poisoned");
        let n: i64 = g.query_row("SELECT COUNT(*) FROM undo_events", [], |r| r.get(0))?;
        Ok(n as usize)
    }

    pub fn is_empty(&self) -> Result<bool, UndoLogError> {
        Ok(self.len()? == 0)
    }
}

fn row_to_entry(row: &rusqlite::Row<'_>) -> Result<UndoEntry, UndoLogError> {
    let id: i64 = row.get(0)?;
    let ts_str: String = row.get(1)?;
    let session_id: String = row.get(2)?;
    let intent_json: String = row.get(3)?;
    let effect_json: String = row.get(4)?;
    let inverse_json: String = row.get(5)?;
    let ttl_str: String = row.get(6)?;
    let undone: i32 = row.get(7)?;

    let ts = DateTime::parse_from_rfc3339(&ts_str)
        .map_err(|e| UndoLogError::Serialize(format!("parse ts: {e}")))?
        .with_timezone(&Utc);
    let ttl_until = DateTime::parse_from_rfc3339(&ttl_str)
        .map_err(|e| UndoLogError::Serialize(format!("parse ttl_until: {e}")))?
        .with_timezone(&Utc);
    let intent: Intent = serde_json::from_str(&intent_json)
        .map_err(|e| UndoLogError::Serialize(format!("parse intent: {e}")))?;
    let effect: Effect = serde_json::from_str(&effect_json)
        .map_err(|e| UndoLogError::Serialize(format!("parse effect: {e}")))?;
    let inverse: Inverse = serde_json::from_str(&inverse_json)
        .map_err(|e| UndoLogError::Serialize(format!("parse inverse: {e}")))?;

    Ok(UndoEntry {
        id: Some(id),
        ts,
        session_id,
        intent,
        effect,
        inverse,
        ttl_until,
        undone: undone != 0,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::effect::PriorState;

    fn write_intent() -> Intent {
        Intent::VaultWrite {
            path: "notes/x.md".to_string(),
            body: "hello".to_string(),
            frontmatter: serde_json::json!({}),
        }
    }

    fn write_effect() -> Effect {
        Effect::VaultWrote {
            path: "notes/x.md".to_string(),
            body_sha256: "deadbeef".to_string(),
            bytes_written: 5,
        }
    }

    #[test]
    fn append_then_get_roundtrips_full_entry() {
        let log = UndoLog::open_in_memory().expect("open");
        let entry = UndoEntry::new(
            "session-1".to_string(),
            write_intent(),
            write_effect(),
            write_effect().compute_inverse(None),
        );
        let id = log.append(&entry).expect("append");
        let fetched = log.get(id).expect("get");
        assert_eq!(fetched.session_id, "session-1");
        assert_eq!(fetched.intent, entry.intent);
        assert_eq!(fetched.effect, entry.effect);
        assert_eq!(fetched.inverse, entry.inverse);
        assert!(!fetched.undone);
    }

    #[test]
    fn recent_returns_newest_first_and_filters_by_session() {
        let log = UndoLog::open_in_memory().expect("open");
        for sid in ["s1", "s1", "s2", "s1"] {
            let entry = UndoEntry::new(
                sid.to_string(),
                write_intent(),
                write_effect(),
                write_effect().compute_inverse(None),
            );
            log.append(&entry).expect("append");
            // Sleep a millisecond so the ts ordering is stable.
            std::thread::sleep(std::time::Duration::from_millis(2));
        }
        let s1_entries = log.recent("s1", 10).expect("recent");
        assert_eq!(s1_entries.len(), 3, "session s1 has 3 entries");
        // newest first
        for window in s1_entries.windows(2) {
            assert!(window[0].ts >= window[1].ts);
        }
    }

    #[test]
    fn mark_undone_returns_inverse_and_flips_flag() {
        let log = UndoLog::open_in_memory().expect("open");
        let entry = UndoEntry::new(
            "s".to_string(),
            write_intent(),
            write_effect(),
            write_effect().compute_inverse(None),
        );
        let id = log.append(&entry).expect("append");
        let inv = log.mark_undone(id).expect("undo");
        assert!(matches!(inv, Inverse::DeleteVault { .. }));
        let fetched = log.get(id).expect("get");
        assert!(fetched.undone);
        // Second undo attempt errors.
        assert!(matches!(
            log.mark_undone(id),
            Err(UndoLogError::AlreadyUndone(_))
        ));
    }

    #[test]
    fn mark_undone_rejects_expired_entries() {
        let log = UndoLog::open_in_memory().expect("open");
        let mut entry = UndoEntry::new(
            "s".to_string(),
            write_intent(),
            write_effect(),
            write_effect().compute_inverse(None),
        );
        // Force ttl into the past.
        entry.ttl_until = Utc::now() - chrono::Duration::seconds(1);
        let id = log.append(&entry).expect("append");
        assert!(matches!(
            log.mark_undone(id),
            Err(UndoLogError::Expired { .. })
        ));
    }

    #[test]
    fn evict_expired_drops_only_past_ttl() {
        let log = UndoLog::open_in_memory().expect("open");
        // alive
        log.append(&UndoEntry::new(
            "s".to_string(),
            write_intent(),
            write_effect(),
            write_effect().compute_inverse(None),
        ))
        .expect("append");
        // expired
        let mut expired = UndoEntry::new(
            "s".to_string(),
            write_intent(),
            write_effect(),
            write_effect().compute_inverse(None),
        );
        expired.ttl_until = Utc::now() - chrono::Duration::seconds(1);
        log.append(&expired).expect("append");

        let dropped = log.evict_expired().expect("evict");
        assert_eq!(dropped, 1);
        assert_eq!(log.len().unwrap(), 1);
    }

    #[test]
    fn restore_inverse_carries_prior_body_for_overwrite() {
        // Plan §8.5: undo for a vault.write that overwrote existing
        // content must restore the prior body — the inverse is a
        // RestoreVaultContent, not a DeleteVault.
        let log = UndoLog::open_in_memory().expect("open");
        let prior = PriorState::WroteOverExisting {
            body_before: "previous text".to_string(),
            body_before_sha256: "abc".to_string(),
        };
        let inverse = write_effect().compute_inverse(Some(&prior));
        let entry = UndoEntry::new("s".to_string(), write_intent(), write_effect(), inverse);
        let id = log.append(&entry).expect("append");

        let inv = log.mark_undone(id).expect("undo");
        match inv {
            Inverse::RestoreVaultContent { path, body } => {
                assert_eq!(path, "notes/x.md");
                assert_eq!(body, "previous text");
            }
            other => panic!("expected RestoreVaultContent, got {other:?}"),
        }
    }

    #[test]
    fn ttl_default_is_24h() {
        let entry = UndoEntry::new(
            "s".to_string(),
            write_intent(),
            write_effect(),
            write_effect().compute_inverse(None),
        );
        let elapsed = entry.ttl_until - entry.ts;
        // Allow a 5-second slop for test execution time.
        let target = chrono::Duration::hours(24);
        let diff = (elapsed - target).num_seconds().abs();
        assert!(
            diff < 5,
            "TTL should be ~24h; got {} seconds off target",
            diff
        );
    }

    #[test]
    fn ttl_auto_research_is_7_days() {
        let entry = UndoEntry::with_ttl(
            "s".to_string(),
            write_intent(),
            write_effect(),
            write_effect().compute_inverse(None),
            AUTO_RESEARCH_TTL,
        );
        let elapsed = entry.ttl_until - entry.ts;
        let target = chrono::Duration::days(7);
        let diff = (elapsed - target).num_seconds().abs();
        assert!(
            diff < 5,
            "auto-research TTL should be 7d; got {} seconds off target",
            diff
        );
    }
}
