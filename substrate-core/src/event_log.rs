//! SQLite-backed event log.
//!
//! Append-only table of serialized `AppAction` rows. On app start, the store
//! calls `load_all` and feeds the result to `Store::replay`. During runtime,
//! each `Store::apply` success should be followed by `EventLog::append`.
//!
//! Schema is intentionally tiny — the authoritative data lives in the
//! decoded action stream. We keep `seq` as a monotonic integer for ordering
//! and `ts` for human debugging only.

use rusqlite::{params, Connection};
use std::path::Path;
use thiserror::Error;

use crate::action::AppAction;

pub struct EventLog {
    conn: Connection,
}

#[derive(Debug, Error)]
pub enum EventLogError {
    #[error("sqlite: {0}")]
    Sqlite(#[from] rusqlite::Error),
    #[error("serde: {0}")]
    Serde(#[from] serde_json::Error),
}

impl EventLog {
    pub fn open<P: AsRef<Path>>(path: P) -> Result<Self, EventLogError> {
        let conn = Connection::open(path)?;
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS action_log (
                 seq INTEGER PRIMARY KEY AUTOINCREMENT,
                 ts  INTEGER NOT NULL,
                 payload TEXT NOT NULL
             );
             CREATE INDEX IF NOT EXISTS idx_action_log_ts ON action_log(ts);",
        )?;
        // Per CLAUDE.md: "F_FULLFSYNC for any new persistent data."
        // macOS SQLite honours `fullfsync=1` to issue fcntl(F_FULLFSYNC)
        // instead of fsync() on commit — the difference matters on Apple
        // SSDs for crash durability. Combined with synchronous=FULL for the
        // authoritative truth-of-record.
        conn.pragma_update(None, "journal_mode", &"WAL")?;
        conn.pragma_update(None, "synchronous", &"FULL")?;
        conn.pragma_update(None, "fullfsync", &1)?;
        Ok(Self { conn })
    }

    pub fn open_in_memory() -> Result<Self, EventLogError> {
        let conn = Connection::open_in_memory()?;
        conn.execute_batch(
            "CREATE TABLE action_log (
                 seq INTEGER PRIMARY KEY AUTOINCREMENT,
                 ts  INTEGER NOT NULL,
                 payload TEXT NOT NULL
             );",
        )?;
        Ok(Self { conn })
    }

    pub fn append(&self, action: &AppAction) -> Result<i64, EventLogError> {
        let payload = serde_json::to_string(action)?;
        self.conn.execute(
            "INSERT INTO action_log (ts, payload) VALUES (?1, ?2)",
            params![action.timestamp(), payload],
        )?;
        Ok(self.conn.last_insert_rowid())
    }

    pub fn load_all(&self) -> Result<Vec<AppAction>, EventLogError> {
        let mut stmt = self
            .conn
            .prepare("SELECT payload FROM action_log ORDER BY seq ASC")?;
        let rows = stmt.query_map([], |row| row.get::<_, String>(0))?;
        let mut out = Vec::new();
        for row in rows {
            let payload = row?;
            let action: AppAction = serde_json::from_str(&payload)?;
            out.push(action);
        }
        Ok(out)
    }

    pub fn len(&self) -> Result<i64, EventLogError> {
        let n: i64 = self
            .conn
            .query_row("SELECT COUNT(*) FROM action_log", [], |row| row.get(0))?;
        Ok(n)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::entity::EntityId;

    #[test]
    fn append_and_load_roundtrip() {
        let log = EventLog::open_in_memory().unwrap();
        let a = AppAction::CreateNote {
            id: EntityId(1),
            title: "t".into(),
            body: "b".into(),
            at: 42,
        };
        log.append(&a).unwrap();
        let all = log.load_all().unwrap();
        assert_eq!(all.len(), 1);
        assert_eq!(all[0], a);
    }

    #[test]
    fn preserves_order() {
        let log = EventLog::open_in_memory().unwrap();
        for i in 0..10 {
            log.append(&AppAction::CreateNote {
                id: EntityId(i as u64 + 1),
                title: format!("t{i}"),
                body: "".into(),
                at: i as i64,
            })
            .unwrap();
        }
        let all = log.load_all().unwrap();
        assert_eq!(all.len(), 10);
        for (i, a) in all.iter().enumerate() {
            assert_eq!(a.timestamp(), i as i64);
        }
    }
}
