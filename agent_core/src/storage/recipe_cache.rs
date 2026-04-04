//! # Recipe Cache
//!
//! Caches tool execution results to avoid re-running identical tool calls.
//! Backed by SQLite (rusqlite) for persistence across sessions.
//!
//! Key structure: (tool_name, input_hash) → (output, timestamp, hit_count)
//! Input hash is SHA-256 of the canonical JSON input.
//!
//! TTL-based expiration: entries older than `max_age` are evicted on lookup.
//! Size cap: oldest entries are evicted when cache exceeds `max_entries`.

use std::path::{Path, PathBuf};
use std::time::Duration;

use rusqlite::{params, Connection, OptionalExtension};
use sha2::{Digest, Sha256};

/// Default maximum cache entries before eviction.
const DEFAULT_MAX_ENTRIES: usize = 10_000;
/// Default maximum age of a cache entry (7 days).
const DEFAULT_MAX_AGE: Duration = Duration::from_secs(7 * 24 * 3600);

#[derive(Debug, thiserror::Error)]
pub enum CacheError {
    #[error("database error: {0}")]
    Db(#[from] rusqlite::Error),
    #[error("serialization error: {0}")]
    Serialization(#[from] serde_json::Error),
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),
}

/// A cached tool execution result.
#[derive(Debug, Clone)]
pub struct CacheEntry {
    /// The tool output text.
    pub output: String,
    /// Whether the original execution was an error.
    pub is_error: bool,
    /// Unix timestamp when the entry was created.
    pub created_at: i64,
    /// Number of times this entry has been served from cache.
    pub hit_count: u32,
}

/// Configuration for the recipe cache.
#[derive(Debug, Clone)]
pub struct CacheConfig {
    /// Maximum number of entries before oldest are evicted.
    pub max_entries: usize,
    /// Maximum age of a cache entry before it expires.
    pub max_age: Duration,
    /// Tool names that should NEVER be cached (side-effectful tools).
    pub uncacheable_tools: Vec<String>,
}

impl Default for CacheConfig {
    fn default() -> Self {
        Self {
            max_entries: DEFAULT_MAX_ENTRIES,
            max_age: DEFAULT_MAX_AGE,
            // Tools with side effects must never be cached.
            uncacheable_tools: vec![
                "bash".into(),
                "write_file".into(),
                "delete_file".into(),
                "terminal".into(),
                "computer_use".into(),
            ],
        }
    }
}

/// Persistent cache for tool execution results.
///
/// Thread-safe: uses a `Mutex<Connection>` internally. Designed to be shared
/// via `Arc<RecipeCache>` across async tasks.
pub struct RecipeCache {
    conn: std::sync::Mutex<Connection>,
    config: CacheConfig,
}

impl RecipeCache {
    /// Open or create a recipe cache at the given path.
    /// Creates the SQLite database and table if they don't exist.
    pub fn open(path: impl AsRef<Path>) -> Result<Self, CacheError> {
        Self::open_with_config(path, CacheConfig::default())
    }

    /// Open with custom configuration.
    pub fn open_with_config(path: impl AsRef<Path>, config: CacheConfig) -> Result<Self, CacheError> {
        // Ensure parent directory exists.
        if let Some(parent) = path.as_ref().parent() {
            std::fs::create_dir_all(parent)?;
        }

        let conn = Connection::open(path)?;
        conn.execute_batch(
            "PRAGMA journal_mode = WAL;
             PRAGMA synchronous = NORMAL;
             CREATE TABLE IF NOT EXISTS recipe_cache (
                 tool_name TEXT NOT NULL,
                 input_hash TEXT NOT NULL,
                 output TEXT NOT NULL,
                 is_error INTEGER NOT NULL DEFAULT 0,
                 created_at INTEGER NOT NULL,
                 hit_count INTEGER NOT NULL DEFAULT 0,
                 PRIMARY KEY (tool_name, input_hash)
             );
             CREATE INDEX IF NOT EXISTS idx_recipe_cache_created
                 ON recipe_cache(created_at);",
        )?;

        Ok(Self {
            conn: std::sync::Mutex::new(conn),
            config,
        })
    }

    /// Open an in-memory cache (for testing).
    pub fn in_memory() -> Result<Self, CacheError> {
        Self::open_with_config(":memory:", CacheConfig::default())
    }

    /// Look up a cached result for the given tool call.
    /// Returns `None` if not cached or if the entry has expired.
    pub fn get(&self, tool_name: &str, input: &serde_json::Value) -> Result<Option<CacheEntry>, CacheError> {
        if self.is_uncacheable(tool_name) {
            return Ok(None);
        }

        let hash = Self::hash_input(input);
        let now = chrono::Utc::now().timestamp();
        let max_age_secs = self.config.max_age.as_secs() as i64;

        let conn = self.conn.lock().expect("recipe cache mutex poisoned");
        let entry: Option<CacheEntry> = conn
            .query_row(
                "SELECT output, is_error, created_at, hit_count
                 FROM recipe_cache
                 WHERE tool_name = ?1 AND input_hash = ?2 AND created_at > ?3",
                params![tool_name, hash, now - max_age_secs],
                |row| {
                    Ok(CacheEntry {
                        output: row.get(0)?,
                        is_error: row.get::<_, i32>(1)? != 0,
                        created_at: row.get(2)?,
                        hit_count: row.get(3)?,
                    })
                },
            )
            .optional()?;

        // Increment hit count on successful lookup.
        if entry.is_some() {
            let _ = conn.execute(
                "UPDATE recipe_cache SET hit_count = hit_count + 1
                 WHERE tool_name = ?1 AND input_hash = ?2",
                params![tool_name, hash],
            );
        }

        Ok(entry)
    }

    /// Store a tool execution result in the cache.
    /// Overwrites any existing entry for the same (tool_name, input_hash).
    pub fn put(
        &self,
        tool_name: &str,
        input: &serde_json::Value,
        output: &str,
        is_error: bool,
    ) -> Result<(), CacheError> {
        if self.is_uncacheable(tool_name) {
            return Ok(());
        }

        let hash = Self::hash_input(input);
        let now = chrono::Utc::now().timestamp();

        let conn = self.conn.lock().expect("recipe cache mutex poisoned");
        conn.execute(
            "INSERT OR REPLACE INTO recipe_cache (tool_name, input_hash, output, is_error, created_at, hit_count)
             VALUES (?1, ?2, ?3, ?4, ?5, 0)",
            params![tool_name, hash, output, is_error as i32, now],
        )?;

        // Evict oldest entries if over capacity.
        self.evict_if_needed(&conn)?;

        Ok(())
    }

    /// Remove all entries for a specific tool.
    pub fn invalidate_tool(&self, tool_name: &str) -> Result<u64, CacheError> {
        let conn = self.conn.lock().expect("recipe cache mutex poisoned");
        let count = conn.execute(
            "DELETE FROM recipe_cache WHERE tool_name = ?1",
            params![tool_name],
        )?;
        Ok(count as u64)
    }

    /// Remove all expired entries.
    pub fn gc(&self) -> Result<u64, CacheError> {
        let now = chrono::Utc::now().timestamp();
        let max_age_secs = self.config.max_age.as_secs() as i64;
        let conn = self.conn.lock().expect("recipe cache mutex poisoned");
        let count = conn.execute(
            "DELETE FROM recipe_cache WHERE created_at <= ?1",
            params![now - max_age_secs],
        )?;
        Ok(count as u64)
    }

    /// Clear the entire cache.
    pub fn clear(&self) -> Result<(), CacheError> {
        let conn = self.conn.lock().expect("recipe cache mutex poisoned");
        conn.execute("DELETE FROM recipe_cache", [])?;
        Ok(())
    }

    /// Number of entries currently in the cache.
    pub fn len(&self) -> Result<usize, CacheError> {
        let conn = self.conn.lock().expect("recipe cache mutex poisoned");
        let count: i64 = conn.query_row("SELECT COUNT(*) FROM recipe_cache", [], |row| row.get(0))?;
        Ok(count as usize)
    }

    /// Whether the cache is empty.
    pub fn is_empty(&self) -> Result<bool, CacheError> {
        Ok(self.len()? == 0)
    }

    /// Get cache statistics.
    pub fn stats(&self) -> Result<CacheStats, CacheError> {
        let conn = self.conn.lock().expect("recipe cache mutex poisoned");
        let entry_count: i64 =
            conn.query_row("SELECT COUNT(*) FROM recipe_cache", [], |row| row.get(0))?;
        let total_hits: i64 = conn
            .query_row(
                "SELECT COALESCE(SUM(hit_count), 0) FROM recipe_cache",
                [],
                |row| row.get(0),
            )?;
        let distinct_tools: i64 = conn.query_row(
            "SELECT COUNT(DISTINCT tool_name) FROM recipe_cache",
            [],
            |row| row.get(0),
        )?;
        Ok(CacheStats {
            entry_count: entry_count as usize,
            total_hits: total_hits as u64,
            distinct_tools: distinct_tools as usize,
            max_entries: self.config.max_entries,
        })
    }

    // ── Private helpers ──────────────────────────────────────────────

    fn is_uncacheable(&self, tool_name: &str) -> bool {
        self.config
            .uncacheable_tools
            .iter()
            .any(|t| t == tool_name)
    }

    fn hash_input(input: &serde_json::Value) -> String {
        // Canonical JSON: sorted keys, no extra whitespace.
        // serde_json::to_string produces deterministic output for the same Value.
        let canonical = serde_json::to_string(input).unwrap_or_default();
        let mut hasher = Sha256::new();
        hasher.update(canonical.as_bytes());
        let digest = hasher.finalize();
        // Format as hex without pulling in the `hex` crate.
        digest.iter().fold(String::with_capacity(64), |mut s, b| {
            use std::fmt::Write;
            let _ = write!(s, "{b:02x}");
            s
        })
    }

    fn evict_if_needed(&self, conn: &Connection) -> Result<(), CacheError> {
        let count: i64 = conn.query_row("SELECT COUNT(*) FROM recipe_cache", [], |row| row.get(0))?;
        if (count as usize) <= self.config.max_entries {
            return Ok(());
        }
        // Delete oldest entries to bring count to 90% of max.
        let target = (self.config.max_entries * 9) / 10;
        let to_delete = count as usize - target;
        conn.execute(
            "DELETE FROM recipe_cache WHERE rowid IN (
                SELECT rowid FROM recipe_cache ORDER BY created_at ASC LIMIT ?1
            )",
            params![to_delete as i64],
        )?;
        Ok(())
    }
}

/// Cache statistics.
#[derive(Debug, Clone)]
pub struct CacheStats {
    pub entry_count: usize,
    pub total_hits: u64,
    pub distinct_tools: usize,
    pub max_entries: usize,
}

/// Resolve the default cache path for recipe storage.
/// Uses `~/.epistemos/cache/recipe_cache.db`.
pub fn default_cache_path() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".into());
    PathBuf::from(home)
        .join(".epistemos")
        .join("cache")
        .join("recipe_cache.db")
}

// ── Tests ──────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn open_and_put_get_roundtrip() {
        let cache = RecipeCache::in_memory().unwrap();
        let input = json!({"path": "/Users/test/file.txt"});

        // Initially empty.
        assert!(cache.get("read_file", &input).unwrap().is_none());

        // Put an entry.
        cache
            .put("read_file", &input, "file contents here", false)
            .unwrap();

        // Get it back. First get returns hit_count=0 (before increment).
        let entry = cache.get("read_file", &input).unwrap().unwrap();
        assert_eq!(entry.output, "file contents here");
        assert!(!entry.is_error);
        assert_eq!(entry.hit_count, 0);

        // Second get sees hit_count=1 (incremented by first get).
        let entry2 = cache.get("read_file", &input).unwrap().unwrap();
        assert_eq!(entry2.hit_count, 1);
    }

    #[test]
    fn uncacheable_tools_are_skipped() {
        let cache = RecipeCache::in_memory().unwrap();
        let input = json!({"command": "rm -rf /"});

        // Put should silently succeed (no-op).
        cache.put("bash", &input, "done", false).unwrap();

        // Get should return None.
        assert!(cache.get("bash", &input).unwrap().is_none());
        assert_eq!(cache.len().unwrap(), 0);
    }

    #[test]
    fn different_inputs_produce_different_entries() {
        let cache = RecipeCache::in_memory().unwrap();
        let input_a = json!({"query": "rust async"});
        let input_b = json!({"query": "swift concurrency"});

        cache.put("search", &input_a, "result A", false).unwrap();
        cache.put("search", &input_b, "result B", false).unwrap();

        assert_eq!(
            cache.get("search", &input_a).unwrap().unwrap().output,
            "result A"
        );
        assert_eq!(
            cache.get("search", &input_b).unwrap().unwrap().output,
            "result B"
        );
        assert_eq!(cache.len().unwrap(), 2);
    }

    #[test]
    fn eviction_removes_oldest_entries() {
        let config = CacheConfig {
            max_entries: 5,
            ..Default::default()
        };
        let cache = RecipeCache::open_with_config(":memory:", config).unwrap();

        // Insert 7 entries.
        for i in 0..7 {
            let input = json!({"n": i});
            cache
                .put("tool", &input, &format!("result {i}"), false)
                .unwrap();
        }

        // Should have evicted to ~90% of 5 = 4 entries.
        let len = cache.len().unwrap();
        assert!(len <= 5, "expected <= 5 entries, got {len}");
    }

    #[test]
    fn invalidate_tool_removes_only_that_tool() {
        let cache = RecipeCache::in_memory().unwrap();
        cache
            .put("search", &json!({"q": "a"}), "r1", false)
            .unwrap();
        cache
            .put("read_file", &json!({"p": "b"}), "r2", false)
            .unwrap();
        cache
            .put("search", &json!({"q": "c"}), "r3", false)
            .unwrap();

        assert_eq!(cache.len().unwrap(), 3);

        let deleted = cache.invalidate_tool("search").unwrap();
        assert_eq!(deleted, 2);
        assert_eq!(cache.len().unwrap(), 1);
    }

    #[test]
    fn clear_removes_everything() {
        let cache = RecipeCache::in_memory().unwrap();
        for i in 0..10 {
            cache
                .put("tool", &json!({"n": i}), "r", false)
                .unwrap();
        }
        assert_eq!(cache.len().unwrap(), 10);
        cache.clear().unwrap();
        assert_eq!(cache.len().unwrap(), 0);
    }

    #[test]
    fn stats_reports_correctly() {
        let cache = RecipeCache::in_memory().unwrap();
        cache
            .put("search", &json!({"q": "a"}), "r1", false)
            .unwrap();
        cache
            .put("read_file", &json!({"p": "b"}), "r2", false)
            .unwrap();
        // Hit search once.
        let _ = cache.get("search", &json!({"q": "a"})).unwrap();

        let stats = cache.stats().unwrap();
        assert_eq!(stats.entry_count, 2);
        // Hit count is incremented AFTER the select, so the DB shows 1 after one get.
        assert!(stats.total_hits >= 1);
        assert_eq!(stats.distinct_tools, 2);
    }

    #[test]
    fn error_results_are_cached() {
        let cache = RecipeCache::in_memory().unwrap();
        let input = json!({"path": "/nonexistent"});

        cache
            .put("read_file", &input, "file not found", true)
            .unwrap();

        let entry = cache.get("read_file", &input).unwrap().unwrap();
        assert!(entry.is_error);
        assert_eq!(entry.output, "file not found");
    }

    #[test]
    fn hash_is_deterministic() {
        let a = RecipeCache::hash_input(&json!({"b": 2, "a": 1}));
        let b = RecipeCache::hash_input(&json!({"b": 2, "a": 1}));
        assert_eq!(a, b);
    }

    #[test]
    fn overwrite_replaces_existing() {
        let cache = RecipeCache::in_memory().unwrap();
        let input = json!({"path": "test.txt"});

        cache.put("read_file", &input, "old content", false).unwrap();
        cache.put("read_file", &input, "new content", false).unwrap();

        let entry = cache.get("read_file", &input).unwrap().unwrap();
        assert_eq!(entry.output, "new content");
        assert_eq!(cache.len().unwrap(), 1);
    }
}
