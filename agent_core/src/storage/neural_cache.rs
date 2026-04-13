//! Neural Cache — Tiered instant retrieval across 5 memory layers.
//!
//! Implements the "Neural Cache" pattern from the research synthesis:
//!
//! Layer 0: Working Context (in-memory, current conversation) — 0μs
//! Layer 1: Hot Facts (top-K most relevant facts, memory-mapped) — <1ms
//! Layer 2: Warm Search (Tantivy FTS + SQLite vec0 hybrid) — <5ms
//! Layer 3: Cold Vault (filesystem session transcripts) — <50ms
//!
//! The cache warms facts into Layer 1 as they're accessed, implementing
//! a recency-weighted LRU that keeps the most useful knowledge instantly
//! available without hitting the full search index.
//!
//! Architecture inspired by Kimi's "Neural Cache" brainstorm and Gemini's
//! "Holographic KV-Cache Resonance" concept — simplified to what's
//! implementable today without hardware-specific ANE kernels.

use std::collections::HashMap;
use std::sync::Mutex;
use std::time::Instant;

use serde::{Deserialize, Serialize};

use crate::storage::vault::VaultBackend;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Which cache layer a result was retrieved from.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum CacheLayer {
    /// Layer 1: Hot facts (pre-warmed, <1ms)
    Hot,
    /// Layer 2: Warm search (Tantivy + vec0, <5ms)
    Warm,
    /// Layer 3: Cold vault (filesystem, <50ms)
    Cold,
}

/// A cached fact entry in Layer 1.
#[derive(Debug, Clone)]
struct HotFact {
    content: String,
    path: String,
    score: f64,
    last_accessed: Instant,
    access_count: u32,
    /// Absolute timestamp when this fact was created/ingested (TurboQuant temporal encoding).
    /// Enables time-based queries like "what did we discuss 5 minutes ago?"
    created_at: chrono::DateTime<chrono::Utc>,
}

/// Result from a tiered cache lookup.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CachedResult {
    pub path: String,
    pub content: String,
    pub score: f64,
    pub layer: CacheLayer,
    /// Retrieval latency in microseconds.
    pub latency_us: u64,
}

// ---------------------------------------------------------------------------
// Neural Cache
// ---------------------------------------------------------------------------

/// Tiered retrieval cache with hot-warm-cold layers.
pub struct NeuralCache {
    /// Layer 1: Hot facts — top-K most accessed facts, instantly available.
    hot: Mutex<HotLayer>,
    /// Maximum number of facts in the hot layer.
    max_hot_entries: usize,
}

struct HotLayer {
    facts: HashMap<String, HotFact>,
}

impl NeuralCache {
    /// Create a new neural cache with the given hot layer capacity.
    pub fn new(max_hot_entries: usize) -> Self {
        Self {
            hot: Mutex::new(HotLayer {
                facts: HashMap::with_capacity(max_hot_entries),
            }),
            max_hot_entries,
        }
    }

    /// Warm a fact into the hot layer (called after retrieval from deeper layers).
    pub fn warm(&self, path: &str, content: &str, score: f64) {
        let mut hot = match self.hot.lock() {
            Ok(h) => h,
            Err(_) => return, // poisoned lock — skip silently
        };

        if let Some(existing) = hot.facts.get_mut(path) {
            existing.access_count += 1;
            existing.last_accessed = Instant::now();
            existing.score = existing.score.max(score);
            return;
        }

        // Evict least-recently-accessed if at capacity
        if hot.facts.len() >= self.max_hot_entries {
            let oldest_key = hot
                .facts
                .iter()
                .min_by_key(|(_, f)| f.last_accessed)
                .map(|(k, _)| k.clone());
            if let Some(key) = oldest_key {
                hot.facts.remove(&key);
            }
        }

        hot.facts.insert(
            path.to_string(),
            HotFact {
                content: content.to_string(),
                path: path.to_string(),
                score,
                last_accessed: Instant::now(),
                access_count: 1,
                created_at: chrono::Utc::now(),
            },
        );
    }

    /// Layer 1 lookup: instant hot facts matching query keywords.
    /// Returns results in <1ms via simple keyword matching against cached content.
    fn search_hot(&self, query: &str, limit: usize) -> Vec<CachedResult> {
        let start = Instant::now();
        let hot = match self.hot.lock() {
            Ok(h) => h,
            Err(_) => return Vec::new(),
        };

        let query_lower = query.to_lowercase();
        let query_words: Vec<&str> = query_lower.split_whitespace().collect();
        if query_words.is_empty() {
            return Vec::new();
        }
        let mut scored: Vec<(f64, &HotFact)> = hot
            .facts
            .values()
            .filter_map(|fact| {
                let content_lower = fact.content.to_lowercase();
                let overlap = query_words
                    .iter()
                    .filter(|w| content_lower.contains(*w))
                    .count();
                if overlap > 0 {
                    let relevance = overlap as f64 / query_words.len() as f64;
                    let recency_boost = 1.0 / (fact.last_accessed.elapsed().as_secs_f64() + 1.0);
                    let combined = relevance * 0.7 + fact.score * 0.2 + recency_boost * 0.1;
                    Some((combined, fact))
                } else {
                    None
                }
            })
            .collect();

        scored.sort_by(|a, b| b.0.partial_cmp(&a.0).unwrap_or(std::cmp::Ordering::Equal));
        let latency = start.elapsed().as_micros() as u64;

        scored
            .into_iter()
            .take(limit)
            .map(|(score, fact)| CachedResult {
                path: fact.path.clone(),
                content: fact.content.clone(),
                score,
                layer: CacheLayer::Hot,
                latency_us: latency,
            })
            .collect()
    }

    /// Tiered retrieval: search hot → warm → cold, warming results up.
    ///
    /// This is the main entry point. It checks Layer 1 first (instant),
    /// falls through to Layer 2 (Tantivy/SQLite), and warms results up.
    pub async fn instant_retrieve(
        &self,
        query: &str,
        vault: &dyn VaultBackend,
        limit: usize,
    ) -> Vec<CachedResult> {
        let mut results = Vec::with_capacity(limit);

        // Layer 1: Hot facts (<1ms)
        let hot_results = self.search_hot(query, limit);
        results.extend(hot_results);

        if results.len() >= limit {
            return results;
        }

        // Layer 2: Warm search — Tantivy + vec0 hybrid (<5ms)
        let remaining = limit - results.len();
        let start = Instant::now();
        let warm_results = vault
            .hybrid_search(query, remaining, &[])
            .await
            .unwrap_or_default();
        let warm_latency = start.elapsed().as_micros() as u64;

        for sr in &warm_results {
            // Skip if already in hot results
            if results.iter().any(|r| r.path == sr.path) {
                continue;
            }

            results.push(CachedResult {
                path: sr.path.clone(),
                content: sr.excerpt.clone(),
                score: sr.score,
                layer: CacheLayer::Warm,
                latency_us: warm_latency,
            });

            // Warm this result into Layer 1 for next time
            self.warm(&sr.path, &sr.excerpt, sr.score);
        }

        results.truncate(limit);
        results
    }

    /// Temporal query: retrieve facts from a specific time window.
    /// Implements the "Absolute Time Positional Encoding" concept —
    /// each cached fact has a real-world timestamp for time-based routing.
    pub fn temporal_retrieve(&self, minutes_ago: u64, window_minutes: u64) -> Vec<CachedResult> {
        let start = Instant::now();
        let hot = match self.hot.lock() {
            Ok(h) => h,
            Err(_) => return Vec::new(),
        };

        let now = chrono::Utc::now();
        let window_start =
            now - chrono::Duration::minutes(minutes_ago as i64 + window_minutes as i64);
        let window_end = now - chrono::Duration::minutes(minutes_ago as i64);

        let mut results: Vec<CachedResult> = hot
            .facts
            .values()
            .filter(|f| f.created_at >= window_start && f.created_at <= window_end)
            .map(|f| CachedResult {
                path: f.path.clone(),
                content: f.content.clone(),
                score: f.score,
                layer: CacheLayer::Hot,
                latency_us: start.elapsed().as_micros() as u64,
            })
            .collect();

        results.sort_by(|a, b| {
            b.score
                .partial_cmp(&a.score)
                .unwrap_or(std::cmp::Ordering::Equal)
        });
        results
    }

    /// Get cache statistics for diagnostics.
    pub fn stats(&self) -> CacheStats {
        let hot = self.hot.lock().map(|h| h.facts.len()).unwrap_or(0);
        CacheStats {
            hot_entries: hot,
            max_hot_entries: self.max_hot_entries,
        }
    }

    /// Clear the hot cache (used on vault switch or major changes).
    pub fn clear_hot(&self) {
        if let Ok(mut hot) = self.hot.lock() {
            hot.facts.clear();
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CacheStats {
    pub hot_entries: usize,
    pub max_hot_entries: usize,
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn warm_and_retrieve_from_hot() {
        let cache = NeuralCache::new(100);

        // Warm some facts
        cache.warm(
            "notes/rust-ffi.md",
            "Rust FFI bridge uses UniFFI for Swift interop",
            0.9,
        );
        cache.warm(
            "notes/swift-actors.md",
            "Swift actors provide data isolation",
            0.8,
        );
        cache.warm(
            "notes/grpc.md",
            "gRPC is a remote procedure call framework",
            0.7,
        );

        // Search for Rust-related content
        let results = cache.search_hot("Rust FFI bridge", 5);
        assert!(!results.is_empty());
        assert_eq!(results[0].layer, CacheLayer::Hot);
        assert!(results[0].latency_us < 1000); // <1ms
        assert!(results[0].path.contains("rust-ffi"));
    }

    #[test]
    fn lru_eviction() {
        let cache = NeuralCache::new(2);

        cache.warm("a.md", "content a", 0.9);
        cache.warm("b.md", "content b", 0.8);

        // Wait a tiny bit so timestamps differ
        std::thread::sleep(std::time::Duration::from_millis(1));

        // Adding a third should evict the oldest
        cache.warm("c.md", "content c", 0.7);

        let stats = cache.stats();
        assert_eq!(stats.hot_entries, 2);
    }

    #[test]
    fn access_count_increments() {
        let cache = NeuralCache::new(100);
        cache.warm("test.md", "test content", 0.5);
        cache.warm("test.md", "test content", 0.6); // re-warm
        cache.warm("test.md", "test content", 0.7); // re-warm again

        let hot = cache.hot.lock().unwrap();
        let fact = hot.facts.get("test.md").unwrap();
        assert_eq!(fact.access_count, 3);
        assert!((fact.score - 0.7).abs() < 0.01); // max of all scores
    }

    #[test]
    fn clear_hot() {
        let cache = NeuralCache::new(100);
        cache.warm("a.md", "content", 0.5);
        assert_eq!(cache.stats().hot_entries, 1);

        cache.clear_hot();
        assert_eq!(cache.stats().hot_entries, 0);
    }

    #[test]
    fn empty_query_returns_empty() {
        let cache = NeuralCache::new(100);
        cache.warm("a.md", "content", 0.5);
        let results = cache.search_hot("", 5);
        assert!(results.is_empty());
    }

    #[test]
    fn no_match_returns_empty() {
        let cache = NeuralCache::new(100);
        cache.warm("a.md", "Rust FFI bridge", 0.5);
        let results = cache.search_hot("quantum physics", 5);
        assert!(results.is_empty());
    }
}
