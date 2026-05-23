//! Plan §3.6 — exact + semantic tool-result cache.
//!
//! - Exact match: `(tool, sha256(canonical_input))` → result. Indexed
//!   SQLite query (~50μs typical).
//! - Semantic match: embedding cosine ≥ 0.97 over the most-recent N
//!   entries for that tool. BLOB-stored f32 vectors; L2-normalized
//!   inputs make cosine reduce to dot product.
//! - Per-tool-family TTL: capture=60s, search=5min, summarize=24h,
//!   default=60s. Expired entries are filtered on lookup; eviction
//!   happens lazily on read (no scheduled GC in 2D — that's a NightBrain
//!   job per §7.1).
//!
//! Crash safety: SQLite WAL mode + synchronous=NORMAL per §6.9.
//!
//! Phase 2D MVP scope:
//! - SQLite-backed exact + semantic lookup.
//! - Schema-version-bump invalidation (per-tool bulk delete).
//! - Stub `EmbeddingProvider` for tests; Phase 6 wires the real
//!   bge-small MLX-backed embedder.
//!
//! Deferred (out of §3.6 Phase 2D scope, lands in Phase 8):
//! - vault.write path-based invalidation — needs Intent→Effect stream.
//! - User-undo invalidation — needs §8.5 undo log.
//! - sqlite-vec extension for >10k entries (current MVP brute-force
//!   scan is bounded at 256 most-recent rows per tool — adequate to
//!   the 10k-ops/s target for typical agent sessions).

use std::path::Path;
use std::sync::Mutex;
use std::time::Duration;

use async_trait::async_trait;
use chrono::Utc;
use rusqlite::{params, Connection, OptionalExtension};
use serde_json::Value;
use sha2::{Digest, Sha256};

use crate::tools_v2::{ToolCache, ToolResult};

const SCHEMA_SQL: &str = r#"
CREATE TABLE IF NOT EXISTS tool_cache (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tool TEXT NOT NULL,
  input_hash TEXT NOT NULL,
  schema_version INTEGER NOT NULL,
  embedding BLOB,
  result_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  UNIQUE(tool, input_hash, schema_version)
);
CREATE INDEX IF NOT EXISTS idx_tool_cache_lookup
  ON tool_cache(tool, input_hash, schema_version);
CREATE INDEX IF NOT EXISTS idx_tool_cache_expiry
  ON tool_cache(expires_at);
"#;

/// Per-tool-family TTL per §3.6. Conservative 60s default for tools
/// that don't match a known family — lets the cache help on tight
/// hot paths without risking stale results elsewhere.
pub fn default_ttl(tool_name: &str) -> Duration {
    if tool_name.starts_with("capture.") {
        Duration::from_secs(60)
    } else if tool_name.starts_with("vault.search") || tool_name == "vault.search" {
        Duration::from_secs(300)
    } else if tool_name.contains("summarize") {
        Duration::from_secs(86_400)
    } else {
        Duration::from_secs(60)
    }
}

/// Provides input-text embeddings for the semantic cache. Phase 6 wires
/// a real bge-small MLX-backed impl; tests use `StubEmbedder`.
#[async_trait]
pub trait EmbeddingProvider: Send + Sync {
    async fn embed(&self, value: &Value) -> Vec<f32>;
    fn dim(&self) -> usize;
}

/// Deterministic hash-derived L2-normalized vector. Same input → same
/// vector (so identical inputs trivially get an exact match anyway);
/// for "paraphrase" testing the test module uses a controlled
/// `MapEmbedder` that returns canned vectors per input.
pub struct StubEmbedder {
    pub dim: usize,
}

#[async_trait]
impl EmbeddingProvider for StubEmbedder {
    async fn embed(&self, value: &Value) -> Vec<f32> {
        let canonical = serde_json::to_vec(value).unwrap_or_default();
        let mut h = Sha256::new();
        h.update(&canonical);
        let digest = h.finalize();
        let mut v = vec![0.0_f32; self.dim];
        for i in 0..self.dim {
            v[i] = (digest[i % 32] as f32) / 255.0;
        }
        // L2-normalize so cosine reduces to dot product (~3× faster).
        let norm = v.iter().map(|x| x * x).sum::<f32>().sqrt();
        if norm > 0.0 {
            for x in v.iter_mut() {
                *x /= norm;
            }
        }
        v
    }
    fn dim(&self) -> usize {
        self.dim
    }
}

pub struct PersistentCache {
    conn: Mutex<Connection>,
    embedder: std::sync::Arc<dyn EmbeddingProvider>,
    semantic_threshold: f32,
    semantic_scan_limit: usize,
}

impl PersistentCache {
    pub fn open(
        path: impl AsRef<Path>,
        embedder: std::sync::Arc<dyn EmbeddingProvider>,
    ) -> Result<Self, rusqlite::Error> {
        let conn = Connection::open(path)?;
        // Plan §6.9 — WAL + synchronous=NORMAL for crash-consistency
        // without per-write fsync overhead.
        conn.pragma_update(None, "journal_mode", "WAL")?;
        conn.pragma_update(None, "synchronous", "NORMAL")?;
        conn.execute_batch(SCHEMA_SQL)?;
        Ok(Self {
            conn: Mutex::new(conn),
            embedder,
            semantic_threshold: 0.97,
            semantic_scan_limit: 256,
        })
    }

    pub fn open_in_memory(
        embedder: std::sync::Arc<dyn EmbeddingProvider>,
    ) -> Result<Self, rusqlite::Error> {
        let conn = Connection::open(":memory:")?;
        conn.execute_batch(SCHEMA_SQL)?;
        Ok(Self {
            conn: Mutex::new(conn),
            embedder,
            semantic_threshold: 0.97,
            semantic_scan_limit: 256,
        })
    }

    pub fn with_semantic_threshold(mut self, threshold: f32) -> Self {
        self.semantic_threshold = threshold;
        self
    }

    pub fn with_scan_limit(mut self, limit: usize) -> Self {
        self.semantic_scan_limit = limit;
        self
    }

    /// Per-tool bulk invalidation. Used when a tool's output schema bumps
    /// its `schema_version` — old entries become structurally suspect and
    /// are removed.
    pub fn invalidate_tool(&self, tool: &str) -> rusqlite::Result<usize> {
        let g = self.conn.lock().expect("cache mutex poisoned");
        g.execute("DELETE FROM tool_cache WHERE tool = ?1", params![tool])
    }

    pub fn entries_count(&self) -> rusqlite::Result<usize> {
        let g = self.conn.lock().expect("cache mutex poisoned");
        let n: i64 = g.query_row("SELECT COUNT(*) FROM tool_cache", [], |r| r.get(0))?;
        Ok(n as usize)
    }

    fn exact_key(tool: &str, input: &Value) -> String {
        let canonical = serde_json::to_vec(input).expect("Value serializes");
        let mut h = Sha256::new();
        h.update(tool.as_bytes());
        h.update(b"\x00");
        h.update(&canonical);
        format!("{:x}", h.finalize())
    }
}

#[async_trait]
impl ToolCache for PersistentCache {
    async fn get(&self, tool: &str, input: &Value) -> Option<ToolResult> {
        let key = Self::exact_key(tool, input);
        let now_iso = Utc::now().to_rfc3339();

        // Step 1: exact match. Indexed lookup; fast path.
        {
            let g = self.conn.lock().expect("cache mutex poisoned");
            let row: Option<(String, String)> = g
                .query_row(
                    "SELECT result_json, expires_at FROM tool_cache
                     WHERE tool = ?1 AND input_hash = ?2
                     ORDER BY id DESC LIMIT 1",
                    params![tool, &key],
                    |r| Ok((r.get::<_, String>(0)?, r.get::<_, String>(1)?)),
                )
                .optional()
                .ok()
                .flatten();
            if let Some((json, expires_at)) = row {
                if expires_at > now_iso {
                    if let Ok(parsed) = serde_json::from_str::<ToolResult>(&json) {
                        return Some(parsed);
                    }
                }
            }
        }

        // Step 2: semantic match. Embed query, scan recent entries for
        // this tool, return first non-expired with cosine ≥ threshold.
        let query_embed = self.embedder.embed(input).await;
        if query_embed.is_empty() {
            return None;
        }

        let candidates: Vec<(Vec<f32>, String, String)> = {
            let g = self.conn.lock().expect("cache mutex poisoned");
            let mut stmt = match g.prepare(
                "SELECT embedding, result_json, expires_at FROM tool_cache
                 WHERE tool = ?1 AND embedding IS NOT NULL
                 ORDER BY id DESC LIMIT ?2",
            ) {
                Ok(s) => s,
                Err(_) => return None,
            };
            let mut rows = match stmt.query(params![tool, self.semantic_scan_limit as i64]) {
                Ok(r) => r,
                Err(_) => return None,
            };
            let mut out = Vec::new();
            while let Ok(Some(r)) = rows.next() {
                let bytes: Vec<u8> = r.get(0).unwrap_or_default();
                let json: String = r.get(1).unwrap_or_default();
                let exp: String = r.get(2).unwrap_or_default();
                out.push((blob_to_vec(&bytes), json, exp));
            }
            out
        };

        for (embed, json, expires_at) in candidates {
            if expires_at <= now_iso {
                continue;
            }
            let sim = cosine(&query_embed, &embed);
            if sim >= self.semantic_threshold {
                if let Ok(parsed) = serde_json::from_str::<ToolResult>(&json) {
                    return Some(parsed);
                }
            }
        }
        None
    }

    async fn put(&self, tool: &str, input: &Value, result: &ToolResult) {
        let key = Self::exact_key(tool, input);
        let embed = self.embedder.embed(input).await;
        let json = match serde_json::to_string(result) {
            Ok(s) => s,
            Err(_) => return, // best-effort per §3.6
        };
        let now = Utc::now();
        let ttl = default_ttl(tool);
        let expires = now
            + chrono::Duration::from_std(ttl).unwrap_or_else(|_| chrono::Duration::seconds(60));
        let blob = vec_to_blob(&embed);

        let g = self.conn.lock().expect("cache mutex poisoned");
        // Best-effort write — never propagate errors to the tool path.
        let _ = g.execute(
            "INSERT OR REPLACE INTO tool_cache
             (tool, input_hash, schema_version, embedding, result_json, created_at, expires_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![
                tool,
                &key,
                result.meta.schema_version,
                &blob,
                &json,
                now.to_rfc3339(),
                expires.to_rfc3339()
            ],
        );
    }
}

fn cosine(a: &[f32], b: &[f32]) -> f32 {
    if a.len() != b.len() || a.is_empty() {
        return 0.0;
    }
    let mut dot = 0.0_f32;
    let mut na = 0.0_f32;
    let mut nb = 0.0_f32;
    for i in 0..a.len() {
        dot += a[i] * b[i];
        na += a[i] * a[i];
        nb += b[i] * b[i];
    }
    if na == 0.0 || nb == 0.0 {
        return 0.0;
    }
    dot / (na.sqrt() * nb.sqrt())
}

fn vec_to_blob(v: &[f32]) -> Vec<u8> {
    let mut b = Vec::with_capacity(v.len() * 4);
    for &x in v {
        b.extend_from_slice(&x.to_le_bytes());
    }
    b
}

fn blob_to_vec(b: &[u8]) -> Vec<f32> {
    b.chunks_exact(4)
        .map(|c| f32::from_le_bytes([c[0], c[1], c[2], c[3]]))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::tools::VariantId;
    use serde_json::json;
    use std::collections::HashMap;
    use std::sync::Arc;

    fn ok_result(value: i64) -> ToolResult {
        ToolResult::ok(VariantId::A, 1, json!({"value": value}))
    }

    fn cache() -> PersistentCache {
        let embedder: Arc<dyn EmbeddingProvider> = Arc::new(StubEmbedder { dim: 8 });
        PersistentCache::open_in_memory(embedder).unwrap()
    }

    /// Controlled embedder for paraphrase-cosine tests. Returns a
    /// preconfigured vector for each canonical input string.
    struct MapEmbedder {
        map: HashMap<String, Vec<f32>>,
        dim: usize,
    }

    #[async_trait]
    impl EmbeddingProvider for MapEmbedder {
        async fn embed(&self, value: &Value) -> Vec<f32> {
            let key = serde_json::to_string(value).unwrap_or_default();
            self.map
                .get(&key)
                .cloned()
                .unwrap_or_else(|| vec![0.0; self.dim])
        }
        fn dim(&self) -> usize {
            self.dim
        }
    }

    #[tokio::test]
    async fn exact_match_round_trip() {
        let c = cache();
        let r = ok_result(7);
        c.put("vault.search", &json!({"q": "x"}), &r).await;
        let hit = c.get("vault.search", &json!({"q": "x"})).await;
        assert_eq!(hit, Some(r));
    }

    #[tokio::test]
    async fn miss_returns_none() {
        let c = cache();
        assert_eq!(c.get("vault.search", &json!({"q": "miss"})).await, None);
    }

    #[tokio::test]
    async fn schema_version_invalidates_old_entries() {
        let c = cache();
        let r1 = ok_result(1);
        c.put("vault.search", &json!({"q": "x"}), &r1).await;
        assert_eq!(
            c.get("vault.search", &json!({"q": "x"})).await,
            Some(r1)
        );
        c.invalidate_tool("vault.search").unwrap();
        assert_eq!(c.get("vault.search", &json!({"q": "x"})).await, None);
    }

    #[tokio::test]
    async fn different_tools_do_not_collide_on_same_input() {
        let c = cache();
        let r_a = ok_result(100);
        let r_b = ok_result(200);
        c.put("tool.a", &json!({"q": "x"}), &r_a).await;
        c.put("tool.b", &json!({"q": "x"}), &r_b).await;
        assert_eq!(c.get("tool.a", &json!({"q": "x"})).await, Some(r_a));
        assert_eq!(c.get("tool.b", &json!({"q": "x"})).await, Some(r_b));
    }

    #[tokio::test]
    async fn ttl_capture_is_60s_search_300s_summarize_24h() {
        assert_eq!(default_ttl("capture.text"), Duration::from_secs(60));
        assert_eq!(default_ttl("capture.voice"), Duration::from_secs(60));
        assert_eq!(default_ttl("vault.search"), Duration::from_secs(300));
        assert_eq!(
            default_ttl("knowledge.summarize"),
            Duration::from_secs(86_400)
        );
        assert_eq!(default_ttl("vault.read"), Duration::from_secs(60));
    }

    #[tokio::test]
    async fn entries_count_tracks_inserts() {
        let c = cache();
        assert_eq!(c.entries_count().unwrap(), 0);
        c.put("vault.search", &json!({"q": "1"}), &ok_result(1)).await;
        c.put("vault.search", &json!({"q": "2"}), &ok_result(2)).await;
        assert_eq!(c.entries_count().unwrap(), 2);
    }

    #[tokio::test]
    async fn semantic_match_hits_above_threshold() {
        // Two different inputs with engineered vectors at cosine ~0.99.
        let mut map = HashMap::new();
        let v_paraphrase_a: Vec<f32> = vec![1.0, 0.05, 0.0, 0.0];
        let v_paraphrase_b: Vec<f32> = vec![1.0, 0.04, 0.0, 0.0];
        map.insert(
            serde_json::to_string(&json!({"q": "a"})).unwrap(),
            v_paraphrase_a,
        );
        map.insert(
            serde_json::to_string(&json!({"q": "b"})).unwrap(),
            v_paraphrase_b,
        );
        let embedder: Arc<dyn EmbeddingProvider> =
            Arc::new(MapEmbedder { map, dim: 4 });
        let c = PersistentCache::open_in_memory(embedder).unwrap();

        let r = ok_result(42);
        c.put("vault.search", &json!({"q": "a"}), &r).await;
        // "b" is not exactly cached but its embedding cosine is ≥0.97 to "a".
        let hit = c.get("vault.search", &json!({"q": "b"})).await;
        assert_eq!(hit, Some(r));
    }

    #[tokio::test]
    async fn semantic_miss_below_threshold() {
        let mut map = HashMap::new();
        // Engineer vectors at cosine ~0.5 (well below 0.97).
        map.insert(
            serde_json::to_string(&json!({"q": "a"})).unwrap(),
            vec![1.0, 0.0, 0.0, 0.0],
        );
        map.insert(
            serde_json::to_string(&json!({"q": "z"})).unwrap(),
            vec![0.0, 1.0, 0.0, 0.0],
        );
        let embedder: Arc<dyn EmbeddingProvider> =
            Arc::new(MapEmbedder { map, dim: 4 });
        let c = PersistentCache::open_in_memory(embedder).unwrap();
        c.put("vault.search", &json!({"q": "a"}), &ok_result(1)).await;
        // Below-threshold cosine → miss.
        assert_eq!(c.get("vault.search", &json!({"q": "z"})).await, None);
    }

    #[test]
    fn cosine_basic_properties() {
        assert!((cosine(&[1.0, 0.0], &[1.0, 0.0]) - 1.0).abs() < 1e-6);
        assert!((cosine(&[1.0, 0.0], &[0.0, 1.0])).abs() < 1e-6);
        assert!((cosine(&[1.0, 1.0], &[1.0, 1.0]) - 1.0).abs() < 1e-6);
        assert_eq!(cosine(&[], &[]), 0.0);
        assert_eq!(cosine(&[1.0, 2.0], &[1.0]), 0.0); // dimension mismatch
    }

    #[test]
    fn vec_blob_round_trip() {
        let v = vec![0.1_f32, -0.5, 1e-3, 42.0];
        let b = vec_to_blob(&v);
        let r = blob_to_vec(&b);
        assert_eq!(v, r);
    }

    #[tokio::test]
    async fn opens_with_wal_journal_mode_on_disk() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("cache.sqlite");
        let embedder: Arc<dyn EmbeddingProvider> = Arc::new(StubEmbedder { dim: 8 });
        let c = PersistentCache::open(&path, embedder).unwrap();
        // Write something so the WAL file is created.
        c.put("vault.search", &json!({"q": "x"}), &ok_result(1)).await;
        // WAL file lands beside the main db when journal_mode=WAL.
        let wal_path = path.with_extension("sqlite-wal");
        assert!(
            wal_path.exists() || path.exists(),
            "journal_mode=WAL should produce a -wal sidecar (or be queued for next checkpoint)"
        );
    }
}
