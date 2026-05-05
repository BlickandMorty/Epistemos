//! SQLite-backed universal undo log recovered from the Quick Capture salvage
//! track.

use std::path::Path;
use std::sync::Mutex;
use std::time::Duration;

use chrono::{DateTime, Utc};
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};

use crate::format::Intent;

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

pub const DEFAULT_TTL: Duration = Duration::from_secs(24 * 60 * 60);
pub const AUTO_RESEARCH_TTL: Duration = Duration::from_secs(7 * 24 * 60 * 60);

#[derive(Debug, thiserror::Error)]
pub enum UndoLogError {
    #[error("sqlite error: {0}")]
    Sqlite(#[from] rusqlite::Error),

    #[error("io error: {0}")]
    Io(#[from] std::io::Error),

    #[error("serialize error: {0}")]
    Serialize(String),

    #[error("entry not found: id={0}")]
    NotFound(i64),

    #[error("entry already undone: id={0}")]
    AlreadyUndone(i64),

    #[error("entry expired (ttl_until {ttl_until} < now)")]
    Expired { ttl_until: String },
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct UndoEntry {
    pub id: Option<i64>,
    pub ts: DateTime<Utc>,
    pub session_id: String,
    pub intent: Intent,
    pub effect: serde_json::Value,
    pub inverse: serde_json::Value,
    pub ttl_until: DateTime<Utc>,
    pub undone: bool,
}

impl UndoEntry {
    pub fn new(
        session_id: String,
        intent: Intent,
        effect: serde_json::Value,
        inverse: serde_json::Value,
    ) -> Self {
        Self::with_ttl(session_id, intent, effect, inverse, DEFAULT_TTL)
    }

    pub fn with_ttl(
        session_id: String,
        intent: Intent,
        effect: serde_json::Value,
        inverse: serde_json::Value,
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

pub struct UndoLog {
    conn: Mutex<Connection>,
}

impl UndoLog {
    pub fn open(path: &Path) -> Result<Self, UndoLogError> {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let conn = Connection::open(path)?;
        conn.execute_batch(SCHEMA_SQL)?;
        Ok(Self {
            conn: Mutex::new(conn),
        })
    }

    pub fn open_in_memory() -> Result<Self, UndoLogError> {
        let conn = Connection::open_in_memory()?;
        conn.execute_batch(SCHEMA_SQL)?;
        Ok(Self {
            conn: Mutex::new(conn),
        })
    }

    pub fn append(&self, entry: &UndoEntry) -> Result<i64, UndoLogError> {
        let intent_json = serde_json::to_string(&entry.intent)
            .map_err(|error| UndoLogError::Serialize(error.to_string()))?;
        let effect_json = serde_json::to_string(&entry.effect)
            .map_err(|error| UndoLogError::Serialize(error.to_string()))?;
        let inverse_json = serde_json::to_string(&entry.inverse)
            .map_err(|error| UndoLogError::Serialize(error.to_string()))?;

        let guard = self.conn.lock().expect("undo_events mutex poisoned");
        guard.execute(
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
        Ok(guard.last_insert_rowid())
    }

    pub fn get(&self, id: i64) -> Result<UndoEntry, UndoLogError> {
        let guard = self.conn.lock().expect("undo_events mutex poisoned");
        let mut statement = guard.prepare(
            "SELECT id, ts, session_id, intent, effect, inverse, ttl_until, undone
             FROM undo_events WHERE id = ?1",
        )?;
        let mut rows = statement.query(params![id])?;
        match rows.next()? {
            Some(row) => row_to_entry(row),
            None => Err(UndoLogError::NotFound(id)),
        }
    }

    pub fn recent(&self, session_id: &str, limit: usize) -> Result<Vec<UndoEntry>, UndoLogError> {
        let guard = self.conn.lock().expect("undo_events mutex poisoned");
        let mut statement = guard.prepare(
            "SELECT id, ts, session_id, intent, effect, inverse, ttl_until, undone
             FROM undo_events
             WHERE session_id = ?1
             ORDER BY ts DESC, id DESC
             LIMIT ?2",
        )?;
        let mut rows = statement.query(params![session_id, limit as i64])?;
        let mut entries = Vec::with_capacity(limit);
        while let Some(row) = rows.next()? {
            entries.push(row_to_entry(row)?);
        }
        Ok(entries)
    }

    pub fn mark_undone(&self, id: i64) -> Result<serde_json::Value, UndoLogError> {
        let entry = self.get(id)?;
        if entry.undone {
            return Err(UndoLogError::AlreadyUndone(id));
        }
        if entry.ttl_until < Utc::now() {
            return Err(UndoLogError::Expired {
                ttl_until: entry.ttl_until.to_rfc3339(),
            });
        }

        let guard = self.conn.lock().expect("undo_events mutex poisoned");
        guard.execute(
            "UPDATE undo_events SET undone = 1 WHERE id = ?1",
            params![id],
        )?;
        Ok(entry.inverse)
    }

    pub fn has_undo_since(
        &self,
        session_id: &str,
        since: DateTime<Utc>,
    ) -> Result<bool, UndoLogError> {
        let guard = self.conn.lock().expect("undo_events mutex poisoned");
        let count: i64 = guard.query_row(
            "SELECT COUNT(*)
             FROM undo_events
             WHERE session_id = ?1 AND undone = 1 AND ts >= ?2",
            params![session_id, since.to_rfc3339()],
            |row| row.get(0),
        )?;
        Ok(count > 0)
    }

    pub fn evict_expired(&self) -> Result<usize, UndoLogError> {
        let guard = self.conn.lock().expect("undo_events mutex poisoned");
        let deleted = guard.execute(
            "DELETE FROM undo_events WHERE ttl_until < ?1",
            params![Utc::now().to_rfc3339()],
        )?;
        Ok(deleted)
    }

    pub fn len(&self) -> Result<usize, UndoLogError> {
        let guard = self.conn.lock().expect("undo_events mutex poisoned");
        let count: i64 =
            guard.query_row("SELECT COUNT(*) FROM undo_events", [], |row| row.get(0))?;
        Ok(count as usize)
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

    Ok(UndoEntry {
        id: Some(id),
        ts: parse_time(&ts_str, "ts")?,
        session_id,
        intent: serde_json::from_str(&intent_json)
            .map_err(|error| UndoLogError::Serialize(format!("parse intent: {error}")))?,
        effect: serde_json::from_str(&effect_json)
            .map_err(|error| UndoLogError::Serialize(format!("parse effect: {error}")))?,
        inverse: serde_json::from_str(&inverse_json)
            .map_err(|error| UndoLogError::Serialize(format!("parse inverse: {error}")))?,
        ttl_until: parse_time(&ttl_str, "ttl_until")?,
        undone: undone != 0,
    })
}

fn parse_time(value: &str, label: &str) -> Result<DateTime<Utc>, UndoLogError> {
    DateTime::parse_from_rfc3339(value)
        .map(|time| time.with_timezone(&Utc))
        .map_err(|error| UndoLogError::Serialize(format!("parse {label}: {error}")))
}
