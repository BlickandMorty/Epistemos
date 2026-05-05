// Execution logger: persists every tool invocation to SQLite with WAL mode.
// High-frequency, append-heavy — separate from SwiftData to avoid @Query cascade.

use crate::types::ExecutionRecord;
use rusqlite::{params, Connection};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum LoggerError {
    #[error("SQLite error: {0}")]
    Sqlite(#[from] rusqlite::Error),
    #[error("Serialization error: {0}")]
    Serde(#[from] serde_json::Error),
}

/// SQLite-backed execution logger with WAL mode for concurrent access.
pub struct ExecutionLogger {
    conn: Connection,
}

impl ExecutionLogger {
    /// Open or create the execution log database at the given path.
    pub fn open(path: &str) -> Result<Self, LoggerError> {
        let conn = Connection::open(path)?;
        conn.execute_batch("PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;")?;
        conn.execute(
            "CREATE TABLE IF NOT EXISTS tool_executions (
                id TEXT PRIMARY KEY,
                timestamp TEXT NOT NULL,
                tool_name TEXT NOT NULL,
                arguments_json TEXT NOT NULL,
                result_json TEXT NOT NULL,
                duration_ms INTEGER NOT NULL,
                success INTEGER NOT NULL
            )",
            [],
        )?;
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_tool_executions_name ON tool_executions(tool_name)",
            [],
        )?;
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_tool_executions_ts ON tool_executions(timestamp)",
            [],
        )?;
        Ok(ExecutionLogger { conn })
    }

    /// Open an in-memory database (for testing).
    pub fn open_in_memory() -> Result<Self, LoggerError> {
        let conn = Connection::open_in_memory()?;
        conn.execute_batch("PRAGMA journal_mode=WAL;")?;
        conn.execute(
            "CREATE TABLE IF NOT EXISTS tool_executions (
                id TEXT PRIMARY KEY,
                timestamp TEXT NOT NULL,
                tool_name TEXT NOT NULL,
                arguments_json TEXT NOT NULL,
                result_json TEXT NOT NULL,
                duration_ms INTEGER NOT NULL,
                success INTEGER NOT NULL
            )",
            [],
        )?;
        Ok(ExecutionLogger { conn })
    }

    /// Log a tool execution record.
    pub fn log(&self, record: &ExecutionRecord) -> Result<(), LoggerError> {
        self.conn.execute(
            "INSERT INTO tool_executions (id, timestamp, tool_name, arguments_json, result_json, duration_ms, success)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![
                record.id,
                record.timestamp,
                record.tool_name,
                record.arguments_json,
                record.result_json,
                record.duration_ms,
                record.success as i32,
            ],
        )?;
        Ok(())
    }

    /// Query recent executions, most recent first.
    pub fn recent(&self, limit: usize) -> Result<Vec<ExecutionRecord>, LoggerError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, timestamp, tool_name, arguments_json, result_json, duration_ms, success
             FROM tool_executions ORDER BY timestamp DESC LIMIT ?1",
        )?;
        let rows = stmt.query_map(params![limit as i64], |row| {
            Ok(ExecutionRecord {
                id: row.get(0)?,
                timestamp: row.get(1)?,
                tool_name: row.get(2)?,
                arguments_json: row.get(3)?,
                result_json: row.get(4)?,
                duration_ms: row.get::<_, i64>(5)? as u64,
                success: row.get::<_, i32>(6)? != 0,
            })
        })?;
        let mut records = Vec::with_capacity(limit);
        for row in rows {
            records.push(row?);
        }
        Ok(records)
    }

    /// Query executions by tool name.
    pub fn by_tool(
        &self,
        tool_name: &str,
        limit: usize,
    ) -> Result<Vec<ExecutionRecord>, LoggerError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, timestamp, tool_name, arguments_json, result_json, duration_ms, success
             FROM tool_executions WHERE tool_name = ?1 ORDER BY timestamp DESC LIMIT ?2",
        )?;
        let rows = stmt.query_map(params![tool_name, limit as i64], |row| {
            Ok(ExecutionRecord {
                id: row.get(0)?,
                timestamp: row.get(1)?,
                tool_name: row.get(2)?,
                arguments_json: row.get(3)?,
                result_json: row.get(4)?,
                duration_ms: row.get::<_, i64>(5)? as u64,
                success: row.get::<_, i32>(6)? != 0,
            })
        })?;
        let mut records = Vec::with_capacity(limit);
        for row in rows {
            records.push(row?);
        }
        Ok(records)
    }

    /// Count total executions.
    pub fn count(&self) -> Result<u64, LoggerError> {
        let count: i64 =
            self.conn
                .query_row("SELECT COUNT(*) FROM tool_executions", [], |row| row.get(0))?;
        Ok(count as u64)
    }

    /// Count successful executions.
    pub fn count_successful(&self) -> Result<u64, LoggerError> {
        let count: i64 = self.conn.query_row(
            "SELECT COUNT(*) FROM tool_executions WHERE success = 1",
            [],
            |row| row.get(0),
        )?;
        Ok(count as u64)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_record(name: &str, success: bool) -> ExecutionRecord {
        ExecutionRecord {
            id: uuid::Uuid::new_v4().to_string(),
            timestamp: chrono::Utc::now().to_rfc3339(),
            tool_name: name.to_string(),
            arguments_json: r#"{"input":"test"}"#.to_string(),
            result_json: r#"{"data":"ok"}"#.to_string(),
            duration_ms: 42,
            success,
        }
    }

    #[test]
    fn test_open_in_memory() {
        let logger = ExecutionLogger::open_in_memory().unwrap();
        assert_eq!(logger.count().unwrap(), 0);
    }

    #[test]
    fn test_log_and_retrieve() {
        let logger = ExecutionLogger::open_in_memory().unwrap();
        logger.log(&make_record("tool_a", true)).unwrap();
        logger.log(&make_record("tool_b", false)).unwrap();
        assert_eq!(logger.count().unwrap(), 2);
        assert_eq!(logger.count_successful().unwrap(), 1);
    }

    #[test]
    fn test_recent_ordering() {
        let logger = ExecutionLogger::open_in_memory().unwrap();
        for i in 0..5 {
            let mut rec = make_record("tool", true);
            rec.id = format!("id-{i}");
            // Slightly increasing timestamps
            rec.timestamp = format!("2026-03-24T10:00:0{i}Z");
            logger.log(&rec).unwrap();
        }
        let recent = logger.recent(3).unwrap();
        assert_eq!(recent.len(), 3);
        // Most recent first
        assert!(recent[0].timestamp > recent[1].timestamp);
    }

    #[test]
    fn test_by_tool_filter() {
        let logger = ExecutionLogger::open_in_memory().unwrap();
        logger.log(&make_record("alpha", true)).unwrap();
        logger.log(&make_record("beta", true)).unwrap();
        logger.log(&make_record("alpha", false)).unwrap();
        let alpha = logger.by_tool("alpha", 10).unwrap();
        assert_eq!(alpha.len(), 2);
        let beta = logger.by_tool("beta", 10).unwrap();
        assert_eq!(beta.len(), 1);
    }

    #[test]
    fn test_empty_queries() {
        let logger = ExecutionLogger::open_in_memory().unwrap();
        assert_eq!(logger.recent(10).unwrap().len(), 0);
        assert_eq!(logger.by_tool("nothing", 10).unwrap().len(), 0);
    }
}
