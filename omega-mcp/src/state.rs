// SQLite state manager: conversations, tool call history, execution traces.
// Uses WAL mode for concurrent reads during agent execution.
// FTS5 index on conversation content for fast full-text search.

use rusqlite::{params, Connection};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum StateError {
    #[error("SQLite error: {0}")]
    Sqlite(#[from] rusqlite::Error),
    #[error("Serialization error: {0}")]
    Serde(#[from] serde_json::Error),
}

/// Central SQLite state manager for all Omega persistent data.
pub struct StateManager {
    conn: Connection,
}

impl StateManager {
    /// Open or create the state database at the given path.
    pub fn open(path: &str) -> Result<Self, StateError> {
        let conn = Connection::open(path)?;
        // Zero-corruption spec §3.2: WAL + FULL synchronous + integrity check on open
        conn.execute_batch(
            "PRAGMA journal_mode=WAL;
             PRAGMA synchronous=FULL;
             PRAGMA foreign_keys=ON;",
        )?;
        // Integrity check on open — catches corruption immediately
        let integrity: String = conn.query_row("PRAGMA integrity_check;", [], |row| row.get(0))?;
        if integrity != "ok" {
            return Err(StateError::Sqlite(rusqlite::Error::SqliteFailure(
                rusqlite::ffi::Error::new(11), // SQLITE_CORRUPT
                Some(format!("integrity_check failed: {}", integrity)),
            )));
        }
        let mgr = StateManager { conn };
        mgr.create_tables()?;
        Ok(mgr)
    }

    /// Open an in-memory database (for testing).
    pub fn open_in_memory() -> Result<Self, StateError> {
        let conn = Connection::open_in_memory()?;
        let mgr = StateManager { conn };
        mgr.create_tables()?;
        Ok(mgr)
    }

    fn create_tables(&self) -> Result<(), StateError> {
        self.conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS conversations (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                metadata_json TEXT NOT NULL DEFAULT '{}'
            );

            CREATE TABLE IF NOT EXISTS messages (
                id TEXT PRIMARY KEY,
                conversation_id TEXT NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                tool_calls_json TEXT,
                timestamp TEXT NOT NULL,
                FOREIGN KEY (conversation_id) REFERENCES conversations(id)
            );

            CREATE TABLE IF NOT EXISTS traces (
                id TEXT PRIMARY KEY,
                conversation_id TEXT,
                request TEXT NOT NULL,
                plan_json TEXT,
                tool_calls_json TEXT NOT NULL DEFAULT '[]',
                results_json TEXT NOT NULL DEFAULT '[]',
                feedback TEXT,
                timestamp TEXT NOT NULL,
                duration_ms INTEGER NOT NULL DEFAULT 0,
                success INTEGER NOT NULL DEFAULT 0
            );

            CREATE INDEX IF NOT EXISTS idx_messages_conv ON messages(conversation_id);
            CREATE INDEX IF NOT EXISTS idx_traces_conv ON traces(conversation_id);
            CREATE INDEX IF NOT EXISTS idx_traces_ts ON traces(timestamp);

            -- FTS5 virtual table for full-text search across messages
            CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(
                content, conversation_id UNINDEXED, role UNINDEXED,
                content=messages, content_rowid=rowid
            );

            -- Triggers to keep FTS5 in sync
            CREATE TRIGGER IF NOT EXISTS messages_ai AFTER INSERT ON messages BEGIN
                INSERT INTO messages_fts(rowid, content, conversation_id, role)
                VALUES (new.rowid, new.content, new.conversation_id, new.role);
            END;

            CREATE TRIGGER IF NOT EXISTS messages_ad AFTER DELETE ON messages BEGIN
                INSERT INTO messages_fts(messages_fts, rowid, content, conversation_id, role)
                VALUES ('delete', old.rowid, old.content, old.conversation_id, old.role);
            END;",
        )?;
        Ok(())
    }

    // ── Conversations ────────────────────────────────────────────────────

    /// Create a new conversation. Returns the conversation ID.
    pub fn create_conversation(&self, id: &str, title: &str) -> Result<(), StateError> {
        let now = chrono::Utc::now().to_rfc3339();
        self.conn.execute(
            "INSERT INTO conversations (id, title, created_at, updated_at) VALUES (?1, ?2, ?3, ?4)",
            params![id, title, now, now],
        )?;
        Ok(())
    }

    /// Add a message to a conversation.
    pub fn add_message(
        &self,
        id: &str,
        conversation_id: &str,
        role: &str,
        content: &str,
        tool_calls_json: Option<&str>,
        timestamp: &str,
    ) -> Result<(), StateError> {
        self.conn.execute(
            "INSERT INTO messages (id, conversation_id, role, content, tool_calls_json, timestamp)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![
                id,
                conversation_id,
                role,
                content,
                tool_calls_json,
                timestamp
            ],
        )?;
        Ok(())
    }

    /// Full-text search across all messages. Returns matching message IDs + snippets.
    pub fn search_messages(
        &self,
        query: &str,
        limit: usize,
    ) -> Result<Vec<(String, String)>, StateError> {
        let mut stmt = self.conn.prepare(
            "SELECT conversation_id, snippet(messages_fts, 0, '<b>', '</b>', '...', 32)
             FROM messages_fts WHERE content MATCH ?1 LIMIT ?2",
        )?;
        let rows = stmt.query_map(params![query, limit as i64], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
        })?;
        let mut results = Vec::with_capacity(limit);
        for row in rows {
            results.push(row?);
        }
        Ok(results)
    }

    /// List recent conversations.
    pub fn recent_conversations(&self, limit: usize) -> Result<Vec<String>, StateError> {
        let mut stmt = self
            .conn
            .prepare("SELECT id FROM conversations ORDER BY updated_at DESC LIMIT ?1")?;
        let rows = stmt.query_map(params![limit as i64], |row| row.get::<_, String>(0))?;
        let mut ids = Vec::with_capacity(limit);
        for row in rows {
            ids.push(row?);
        }
        Ok(ids)
    }

    // ── Traces ───────────────────────────────────────────────────────────

    /// Log a full execution trace.
    #[allow(clippy::too_many_arguments)]
    pub fn log_trace(
        &self,
        id: &str,
        conversation_id: Option<&str>,
        request: &str,
        plan_json: Option<&str>,
        tool_calls_json: &str,
        results_json: &str,
        feedback: Option<&str>,
        duration_ms: u64,
        success: bool,
    ) -> Result<(), StateError> {
        let now = chrono::Utc::now().to_rfc3339();
        self.conn.execute(
            "INSERT INTO traces (id, conversation_id, request, plan_json, tool_calls_json, results_json, feedback, timestamp, duration_ms, success)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
            params![id, conversation_id, request, plan_json, tool_calls_json, results_json, feedback, now, duration_ms, success as i32],
        )?;
        Ok(())
    }

    /// Query successful traces for training data extraction.
    pub fn successful_traces(&self, limit: usize) -> Result<Vec<String>, StateError> {
        let mut stmt = self
            .conn
            .prepare("SELECT id FROM traces WHERE success = 1 ORDER BY timestamp DESC LIMIT ?1")?;
        let rows = stmt.query_map(params![limit as i64], |row| row.get::<_, String>(0))?;
        let mut ids = Vec::with_capacity(limit);
        for row in rows {
            ids.push(row?);
        }
        Ok(ids)
    }

    /// Count total traces.
    pub fn trace_count(&self) -> Result<u64, StateError> {
        let count: i64 = self
            .conn
            .query_row("SELECT COUNT(*) FROM traces", [], |row| row.get(0))?;
        Ok(count as u64)
    }

    /// Count conversations.
    pub fn conversation_count(&self) -> Result<u64, StateError> {
        let count: i64 = self
            .conn
            .query_row("SELECT COUNT(*) FROM conversations", [], |row| row.get(0))?;
        Ok(count as u64)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_and_query_conversation() {
        let mgr = StateManager::open_in_memory().unwrap();
        mgr.create_conversation("conv-1", "Test Chat").unwrap();
        assert_eq!(mgr.conversation_count().unwrap(), 1);
        let recent = mgr.recent_conversations(10).unwrap();
        assert_eq!(recent.len(), 1);
        assert_eq!(recent[0], "conv-1");
    }

    #[test]
    fn test_add_and_search_messages() {
        let mgr = StateManager::open_in_memory().unwrap();
        mgr.create_conversation("conv-1", "Test").unwrap();
        mgr.add_message(
            "msg-1",
            "conv-1",
            "user",
            "Hello world from Epistemos",
            None,
            "2026-03-24T12:00:00Z",
        )
        .unwrap();
        mgr.add_message(
            "msg-2",
            "conv-1",
            "assistant",
            "I can help with macOS automation",
            None,
            "2026-03-24T12:00:01Z",
        )
        .unwrap();

        let results = mgr.search_messages("Epistemos", 10).unwrap();
        assert!(!results.is_empty());
        assert_eq!(results[0].0, "conv-1");
    }

    #[test]
    fn test_fts5_search_no_results() {
        let mgr = StateManager::open_in_memory().unwrap();
        let results = mgr.search_messages("nonexistent", 10).unwrap();
        assert!(results.is_empty());
    }

    #[test]
    fn test_log_and_query_traces() {
        let mgr = StateManager::open_in_memory().unwrap();
        mgr.log_trace(
            "t-1",
            None,
            "Open Safari",
            None,
            "[]",
            "[]",
            None,
            100,
            true,
        )
        .unwrap();
        mgr.log_trace(
            "t-2",
            None,
            "Delete files",
            None,
            "[]",
            "[]",
            None,
            50,
            false,
        )
        .unwrap();
        assert_eq!(mgr.trace_count().unwrap(), 2);

        let successful = mgr.successful_traces(10).unwrap();
        assert_eq!(successful.len(), 1);
        assert_eq!(successful[0], "t-1");
    }

    #[test]
    fn test_empty_state() {
        let mgr = StateManager::open_in_memory().unwrap();
        assert_eq!(mgr.conversation_count().unwrap(), 0);
        assert_eq!(mgr.trace_count().unwrap(), 0);
    }
}
