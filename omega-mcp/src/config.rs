// App configuration: model selection, permission states, feature flags.
// Stored in a separate SQLite table for atomic reads/writes from Rust.

use rusqlite::{Connection, params};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum ConfigError {
    #[error("SQLite error: {0}")]
    Sqlite(#[from] rusqlite::Error),
}

/// Key-value configuration store backed by SQLite.
pub struct ConfigStore {
    conn: Connection,
}

impl ConfigStore {
    pub fn open(path: &str) -> Result<Self, ConfigError> {
        let conn = Connection::open(path)?;
        conn.execute_batch("PRAGMA journal_mode=WAL;")?;
        conn.execute(
            "CREATE TABLE IF NOT EXISTS config (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )",
            [],
        )?;
        Ok(ConfigStore { conn })
    }

    pub fn open_in_memory() -> Result<Self, ConfigError> {
        let conn = Connection::open_in_memory()?;
        conn.execute(
            "CREATE TABLE IF NOT EXISTS config (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )",
            [],
        )?;
        Ok(ConfigStore { conn })
    }

    /// Get a config value by key.
    pub fn get(&self, key: &str) -> Option<String> {
        self.conn.query_row(
            "SELECT value FROM config WHERE key = ?1",
            params![key],
            |row| row.get(0),
        ).ok()
    }

    /// Set a config value (upsert).
    pub fn set(&self, key: &str, value: &str) -> Result<(), ConfigError> {
        let now = chrono::Utc::now().to_rfc3339();
        self.conn.execute(
            "INSERT INTO config (key, value, updated_at) VALUES (?1, ?2, ?3)
             ON CONFLICT(key) DO UPDATE SET value = ?2, updated_at = ?3",
            params![key, value, now],
        )?;
        Ok(())
    }

    /// Delete a config key.
    pub fn delete(&self, key: &str) -> Result<bool, ConfigError> {
        let rows = self.conn.execute("DELETE FROM config WHERE key = ?1", params![key])?;
        Ok(rows > 0)
    }

    /// List all config keys.
    pub fn keys(&self) -> Result<Vec<String>, ConfigError> {
        let mut stmt = self.conn.prepare("SELECT key FROM config ORDER BY key")?;
        let rows = stmt.query_map([], |row| row.get::<_, String>(0))?;
        let mut keys = Vec::new();
        for row in rows {
            keys.push(row?);
        }
        Ok(keys)
    }
}

// Well-known config keys
pub mod keys {
    pub const MODEL_SELECTION: &str = "omega.model_selection";
    pub const CLOUD_PROVIDER: &str = "omega.cloud_provider";
    pub const AGENT_AUTO_EXECUTE: &str = "omega.agent_auto_execute";
    pub const MAX_RETRIES: &str = "omega.max_retries";
    pub const RETRY_BASE_DELAY_MS: &str = "omega.retry_base_delay_ms";
    pub const CONFIRMATION_THRESHOLD: &str = "omega.confirmation_threshold";
    pub const SCREEN2AX_ENABLED: &str = "omega.screen2ax_enabled";
    pub const TRAINING_OVERNIGHT: &str = "omega.training_overnight";
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_set_and_get() {
        let store = ConfigStore::open_in_memory().unwrap();
        store.set("key1", "value1").unwrap();
        assert_eq!(store.get("key1"), Some("value1".to_string()));
    }

    #[test]
    fn test_get_nonexistent() {
        let store = ConfigStore::open_in_memory().unwrap();
        assert_eq!(store.get("nope"), None);
    }

    #[test]
    fn test_upsert() {
        let store = ConfigStore::open_in_memory().unwrap();
        store.set("k", "v1").unwrap();
        store.set("k", "v2").unwrap();
        assert_eq!(store.get("k"), Some("v2".to_string()));
    }

    #[test]
    fn test_delete() {
        let store = ConfigStore::open_in_memory().unwrap();
        store.set("k", "v").unwrap();
        assert!(store.delete("k").unwrap());
        assert_eq!(store.get("k"), None);
        assert!(!store.delete("k").unwrap());
    }

    #[test]
    fn test_keys() {
        let store = ConfigStore::open_in_memory().unwrap();
        store.set("b", "2").unwrap();
        store.set("a", "1").unwrap();
        let keys = store.keys().unwrap();
        assert_eq!(keys, vec!["a", "b"]);
    }
}
