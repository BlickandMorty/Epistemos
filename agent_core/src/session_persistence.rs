//! Session Persistence — Checkpoint and Restore for Agent Sessions
//!
//! Saves session state after each turn to enable crash recovery.
//! Checkpoints are stored in the vault's SQLite database.
//!
//! Reference: Hermes `agent/session_persistence.py`

use std::path::Path;

use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};

use crate::agent_loop::AgentError;
use crate::types::{Message, TokenUsage};

/// A saved checkpoint of an agent session at a specific turn.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionCheckpoint {
    /// Unique session identifier.
    pub session_id: String,
    /// Which turn this checkpoint represents (1-indexed).
    pub turn_number: u32,
    /// Full message history up to this turn.
    pub messages: Vec<Message>,
    /// Cumulative token usage.
    pub total_usage: TokenUsage,
    /// When the checkpoint was created.
    pub created_at: String,
    /// Optional: which provider was active.
    pub active_provider: Option<String>,
    /// Optional: which API key index was active.
    pub active_key_index: Option<usize>,
}

/// Manages session checkpoints in a SQLite database.
pub struct SessionPersistence {
    db: Connection,
}

impl SessionPersistence {
    /// Open or create the session persistence database.
    /// The database is stored in the vault's `.epistemos/sessions.db`.
    pub fn open(vault_root: &Path) -> Result<Self, AgentError> {
        let meta_dir = vault_root.join(".epistemos");
        std::fs::create_dir_all(&meta_dir).map_err(|e| {
            AgentError::Vault(format!("Failed to create meta directory: {e}"))
        })?;

        let db_path = meta_dir.join("sessions.db");
        let db = Connection::open(&db_path).map_err(|e| {
            AgentError::Vault(format!("Failed to open session DB: {e}"))
        })?;

        // Create tables
        db.execute_batch(
            "
            CREATE TABLE IF NOT EXISTS checkpoints (
                session_id TEXT NOT NULL,
                turn_number INTEGER NOT NULL,
                messages_json TEXT NOT NULL,
                usage_json TEXT NOT NULL,
                created_at TEXT NOT NULL DEFAULT (datetime('now')),
                active_provider TEXT,
                active_key_index INTEGER,
                PRIMARY KEY (session_id, turn_number)
            );
            CREATE INDEX IF NOT EXISTS idx_checkpoints_session ON checkpoints(session_id);
            CREATE INDEX IF NOT EXISTS idx_checkpoints_turn ON checkpoints(session_id, turn_number DESC);

            CREATE TABLE IF NOT EXISTS session_metadata (
                session_id TEXT PRIMARY KEY,
                objective TEXT NOT NULL,
                provider_name TEXT NOT NULL,
                started_at TEXT NOT NULL DEFAULT (datetime('now')),
                completed_at TEXT,
                final_status TEXT,
                total_turns INTEGER,
                total_input_tokens INTEGER,
                total_output_tokens INTEGER
            );
            "
        ).map_err(|e| AgentError::Vault(format!("Failed to create session tables: {e}")))?;

        Ok(Self { db })
    }

    /// Record the start of a new session.
    pub fn record_session_start(
        &mut self,
        session_id: &str,
        objective: &str,
        provider_name: &str,
    ) -> Result<(), AgentError> {
        self.db.execute(
            "INSERT INTO session_metadata (session_id, objective, provider_name)
             VALUES (?1, ?2, ?3)
             ON CONFLICT(session_id) DO UPDATE SET
               objective = ?2,
               provider_name = ?3,
               started_at = datetime('now')",
            params![session_id, objective, provider_name],
        ).map_err(|e| AgentError::Vault(format!("Failed to record session start: {e}")))?;
        Ok(())
    }

    /// Save a checkpoint after a completed turn.
    pub fn save_checkpoint(&mut self, checkpoint: &SessionCheckpoint) -> Result<(), AgentError> {
        let messages_json = serde_json::to_string(&checkpoint.messages).map_err(|e| {
            AgentError::Serialization(format!("Failed to serialize messages: {e}"))
        })?;
        let usage_json = serde_json::to_string(&checkpoint.total_usage).map_err(|e| {
            AgentError::Serialization(format!("Failed to serialize usage: {e}"))
        })?;

        self.db.execute(
            "INSERT INTO checkpoints
             (session_id, turn_number, messages_json, usage_json, created_at, active_provider, active_key_index)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
             ON CONFLICT(session_id, turn_number) DO UPDATE SET
               messages_json = ?3,
               usage_json = ?4,
               created_at = ?5,
               active_provider = ?6,
               active_key_index = ?7",
            params![
                &checkpoint.session_id,
                checkpoint.turn_number as i64,
                messages_json,
                usage_json,
                &checkpoint.created_at,
                checkpoint.active_provider.as_ref(),
                checkpoint.active_key_index.map(|i| i as i64),
            ],
        ).map_err(|e| AgentError::Vault(format!("Failed to save checkpoint: {e}")))?;

        tracing::info!(
            session_id = %checkpoint.session_id,
            turn = checkpoint.turn_number,
            "Session checkpoint saved"
        );
        Ok(())
    }

    /// Load the latest checkpoint for a session.
    pub fn load_latest_checkpoint(
        &self,
        session_id: &str,
    ) -> Result<Option<SessionCheckpoint>, AgentError> {
        let mut stmt = self.db.prepare(
            "SELECT turn_number, messages_json, usage_json, created_at, active_provider, active_key_index
             FROM checkpoints
             WHERE session_id = ?1
             ORDER BY turn_number DESC
             LIMIT 1"
        ).map_err(|e| AgentError::Vault(format!("Failed to prepare checkpoint query: {e}")))?;

        let row = stmt.query_row(params![session_id], |row| {
            let turn_number: i64 = row.get(0)?;
            let messages_json: String = row.get(1)?;
            let usage_json: String = row.get(2)?;
            let created_at: String = row.get(3)?;
            let active_provider: Option<String> = row.get(4)?;
            let active_key_index: Option<i64> = row.get(5)?;

            let messages: Vec<Message> = serde_json::from_str(&messages_json).map_err(|e| {
                rusqlite::Error::FromSqlConversionFailure(
                    1,
                    rusqlite::types::Type::Text,
                    Box::new(e),
                )
            })?;
            let total_usage: TokenUsage = serde_json::from_str(&usage_json).map_err(|e| {
                rusqlite::Error::FromSqlConversionFailure(
                    2,
                    rusqlite::types::Type::Text,
                    Box::new(e),
                )
            })?;

            Ok(SessionCheckpoint {
                session_id: session_id.to_string(),
                turn_number: turn_number as u32,
                messages,
                total_usage,
                created_at,
                active_provider,
                active_key_index: active_key_index.map(|i| i as usize),
            })
        });

        match row {
            Ok(checkpoint) => Ok(Some(checkpoint)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(AgentError::Vault(format!("Failed to load checkpoint: {e}"))),
        }
    }

    /// Check if a session has any checkpoints (for resume prompt).
    pub fn has_checkpoints(&self, session_id: &str) -> Result<bool, AgentError> {
        let count: i64 = self.db.query_row(
            "SELECT COUNT(*) FROM checkpoints WHERE session_id = ?1",
            params![session_id],
            |row| row.get(0),
        ).map_err(|e| AgentError::Vault(format!("Failed to check checkpoints: {e}")))?;
        Ok(count > 0)
    }

    /// List all incomplete sessions (for recovery UI).
    pub fn list_incomplete_sessions(&self) -> Result<Vec<SessionSummary>, AgentError> {
        let mut stmt = self.db.prepare(
            "SELECT session_id, objective, provider_name, started_at, total_turns
             FROM session_metadata
             WHERE completed_at IS NULL
             ORDER BY started_at DESC"
        ).map_err(|e| AgentError::Vault(format!("Failed to query sessions: {e}")))?;

        let sessions = stmt.query_map([], |row| {
            Ok(SessionSummary {
                session_id: row.get(0)?,
                objective: row.get(1)?,
                provider_name: row.get(2)?,
                started_at: row.get(3)?,
                last_turn: row.get(4)?,
            })
        }).map_err(|e| AgentError::Vault(format!("Failed to map sessions: {e}")))?;

        sessions.collect::<Result<Vec<_>, _>>()
            .map_err(|e| AgentError::Vault(format!("Failed to collect sessions: {e}")))
    }

    /// Mark a session as completed.
    pub fn record_session_complete(
        &mut self,
        session_id: &str,
        turns: u32,
        input_tokens: u32,
        output_tokens: u32,
        status: &str,
    ) -> Result<(), AgentError> {
        self.db.execute(
            "UPDATE session_metadata
             SET completed_at = datetime('now'),
                 final_status = ?2,
                 total_turns = ?3,
                 total_input_tokens = ?4,
                 total_output_tokens = ?5
             WHERE session_id = ?1",
            params![session_id, status, turns as i64, input_tokens as i64, output_tokens as i64],
        ).map_err(|e| AgentError::Vault(format!("Failed to record session complete: {e}")))?;
        Ok(())
    }

    /// Clean up old checkpoints (keep last N per session, or older than X days).
    pub fn prune_old_checkpoints(&mut self, keep_per_session: usize, max_age_days: i64) -> Result<u32, AgentError> {
        // Delete checkpoints older than max_age_days except the most recent per session
        let deleted = self.db.execute(
            "DELETE FROM checkpoints
             WHERE created_at < datetime('now', ?1 || ' days')
               AND turn_number NOT IN (
                 SELECT turn_number FROM checkpoints AS c2
                 WHERE c2.session_id = checkpoints.session_id
                 ORDER BY turn_number DESC
                 LIMIT ?2
               )",
            params![-max_age_days, keep_per_session as i64],
        ).map_err(|e| AgentError::Vault(format!("Failed to prune checkpoints: {e}")))?;

        Ok(deleted as u32)
    }

    /// Delete all checkpoints for a session (e.g., after successful completion).
    pub fn delete_session_checkpoints(&mut self, session_id: &str) -> Result<u32, AgentError> {
        let deleted = self.db.execute(
            "DELETE FROM checkpoints WHERE session_id = ?1",
            params![session_id],
        ).map_err(|e| AgentError::Vault(format!("Failed to delete checkpoints: {e}")))?;
        Ok(deleted as u32)
    }
}

/// Summary of an incomplete session (for UI display).
#[derive(Debug, Clone)]
pub struct SessionSummary {
    pub session_id: String,
    pub objective: String,
    pub provider_name: String,
    pub started_at: String,
    pub last_turn: Option<i64>,
}

/// Helper to build a checkpoint from the current agent state.
pub fn build_checkpoint(
    session_id: &str,
    turn_number: u32,
    messages: &[Message],
    total_usage: &TokenUsage,
    active_provider: Option<&str>,
    active_key_index: Option<usize>,
) -> SessionCheckpoint {
    SessionCheckpoint {
        session_id: session_id.to_string(),
        turn_number,
        messages: messages.to_vec(),
        total_usage: total_usage.clone(),
        created_at: chrono::Utc::now().to_rfc3339(),
        active_provider: active_provider.map(|s| s.to_string()),
        active_key_index,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::{Message, TokenUsage, UserContent};

    fn test_checkpoint(session_id: &str, turn: u32) -> SessionCheckpoint {
        SessionCheckpoint {
            session_id: session_id.to_string(),
            turn_number: turn,
            messages: vec![Message::user_text("test")],
            total_usage: TokenUsage {
                input_tokens: turn * 10,
                output_tokens: turn * 5,
                cache_creation_input_tokens: 0,
                cache_read_input_tokens: 0,
            },
            created_at: chrono::Utc::now().to_rfc3339(),
            active_provider: Some("claude".to_string()),
            active_key_index: Some(0),
        }
    }

    #[test]
    fn save_and_load_checkpoint() {
        let tmp_dir = tempfile::tempdir().unwrap();
        let mut persistence = SessionPersistence::open(tmp_dir.path()).unwrap();

        let checkpoint = test_checkpoint("session_1", 3);
        persistence.save_checkpoint(&checkpoint).unwrap();

        let loaded = persistence.load_latest_checkpoint("session_1").unwrap();
        assert!(loaded.is_some());
        let loaded = loaded.unwrap();
        assert_eq!(loaded.turn_number, 3);
        assert_eq!(loaded.messages.len(), 1);
        assert_eq!(loaded.total_usage.input_tokens, 30);
    }

    #[test]
    fn load_nonexistent_checkpoint() {
        let tmp_dir = tempfile::tempdir().unwrap();
        let persistence = SessionPersistence::open(tmp_dir.path()).unwrap();

        let loaded = persistence.load_latest_checkpoint("no_such_session").unwrap();
        assert!(loaded.is_none());
    }

    #[test]
    fn overwrite_checkpoint() {
        let tmp_dir = tempfile::tempdir().unwrap();
        let mut persistence = SessionPersistence::open(tmp_dir.path()).unwrap();

        let cp1 = test_checkpoint("session_1", 1);
        persistence.save_checkpoint(&cp1).unwrap();

        let cp2 = test_checkpoint("session_1", 1);
        persistence.save_checkpoint(&cp2).unwrap();

        let loaded = persistence.load_latest_checkpoint("session_1").unwrap().unwrap();
        assert_eq!(loaded.total_usage.input_tokens, 10);
    }

    #[test]
    fn session_lifecycle() {
        let tmp_dir = tempfile::tempdir().unwrap();
        let mut persistence = SessionPersistence::open(tmp_dir.path()).unwrap();

        // Start session
        persistence.record_session_start("sess_1", "test objective", "claude").unwrap();

        // Save checkpoints
        for turn in 1..=3 {
            let cp = test_checkpoint("sess_1", turn);
            persistence.save_checkpoint(&cp).unwrap();
        }

        // Check incomplete sessions
        let incomplete = persistence.list_incomplete_sessions().unwrap();
        assert_eq!(incomplete.len(), 1);
        assert_eq!(incomplete[0].session_id, "sess_1");

        // Complete session
        persistence.record_session_complete("sess_1", 3, 100, 50, "success").unwrap();

        // Now it should not appear in incomplete
        let incomplete = persistence.list_incomplete_sessions().unwrap();
        assert!(incomplete.is_empty());
    }

    #[test]
    fn has_checkpoints() {
        let tmp_dir = tempfile::tempdir().unwrap();
        let mut persistence = SessionPersistence::open(tmp_dir.path()).unwrap();

        assert!(!persistence.has_checkpoints("new_session").unwrap());

        let cp = test_checkpoint("new_session", 1);
        persistence.save_checkpoint(&cp).unwrap();

        assert!(persistence.has_checkpoints("new_session").unwrap());
    }

    #[test]
    fn prune_old_checkpoints() {
        let tmp_dir = tempfile::tempdir().unwrap();
        let mut persistence = SessionPersistence::open(tmp_dir.path()).unwrap();

        // Save 5 checkpoints
        for turn in 1..=5 {
            let cp = test_checkpoint("sess", turn);
            persistence.save_checkpoint(&cp).unwrap();
        }

        // Verify all 5 exist
        assert!(persistence.load_latest_checkpoint("sess").unwrap().unwrap().turn_number == 5);

        // Prune: keep 2 per session, delete anything older than 1 day
        // All checkpoints are from "now", so none are older than 1 day.
        // But the subquery protects the 2 most recent per session.
        let deleted = persistence.prune_old_checkpoints(2, 1).unwrap();
        // With max_age_days=1 and all rows being recent, the age filter doesn't match.
        // So nothing is deleted. This is correct behavior.
        assert_eq!(deleted, 0);

        // The most recent checkpoint is still there
        let loaded = persistence.load_latest_checkpoint("sess").unwrap().unwrap();
        assert_eq!(loaded.turn_number, 5);
    }

    #[test]
    fn delete_session_checkpoints() {
        let tmp_dir = tempfile::tempdir().unwrap();
        let mut persistence = SessionPersistence::open(tmp_dir.path()).unwrap();

        let cp = test_checkpoint("sess", 1);
        persistence.save_checkpoint(&cp).unwrap();
        assert!(persistence.has_checkpoints("sess").unwrap());

        let deleted = persistence.delete_session_checkpoints("sess").unwrap();
        assert_eq!(deleted, 1);
        assert!(!persistence.has_checkpoints("sess").unwrap());
    }
}
