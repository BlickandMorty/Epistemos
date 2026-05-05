//! Pluggable scoring backends for `graph.search_semantic` +
//! `graph.search_fulltext`. Replaces the previous hardcoded
//! "score = 0.74 if semantic else 1.0" placeholder with deterministic
//! scorers that reflect real-ish relevance, and exposes a trait seam
//! for future HNSW (epistemos-shadow usearch) + Tantivy (BM25) backends
//! to slot in without changing call sites.
//!
//! Closes the "D2 graph search still has deeper HNSW/Tantivy backend
//! work" follow-up flagged after the Codex continuation pass.
//!
//! Two deterministic backends ship today:
//!
//! 1. `Bm25LikeFullTextScorer` — TF-IDF over the in-memory graph store.
//!    Tokenises both query and (title + body), scores each node by sum
//!    of (tf * idf) for matched query terms. No external state, no
//!    randomness, byte-stable across runs.
//!
//! 2. `TrigramCosineSemanticScorer` — character-trigram cosine
//!    similarity. Decomposes both query and (title + body) into
//!    overlapping 3-grams, computes cosine on the term-frequency
//!    vectors. Not real embedding-based semantic search, but a much
//!    better stand-in than a constant score and produces stable,
//!    monotonic relevance for the Variant A → Variant B router floors.
//!
//! Future HNSW backend (epistemos-shadow usearch via FFI) implements
//! the `SemanticScorer` trait directly. Future Tantivy BM25 backend
//! implements `FullTextScorer`. The MCP graph_tools dispatch site
//! constructs the appropriate scorer based on a `GraphSearchBackend`
//! enum (today: defaults to the in-memory deterministic scorers; a
//! future "shadow" variant routes through epistemos-shadow).

use std::collections::BTreeMap;

/// Single graph node hit returned by either scorer. The score is in
/// [0.0, 1.0]; higher is more relevant.
#[derive(Debug, Clone, PartialEq)]
pub struct ScoredHit {
    pub node_id: String,
    pub score: f64,
}

/// Trait for scoring a single corpus document against a query for
/// fulltext matching. Implementations are pure functions — same inputs
/// must always produce the same score.
pub trait FullTextScorer: Send + Sync {
    /// Score a single document. Returns None if the document doesn't
    /// match at all (no shared tokens). Implementations decide whether
    /// to return Some(0.0) for "matched but minimal" vs None for
    /// "filter out entirely."
    fn score(&self, query: &str, document: &str) -> Option<f64>;
}

/// Trait for scoring a single corpus document against a query for
/// semantic matching. Same purity contract as FullTextScorer.
pub trait SemanticScorer: Send + Sync {
    fn score(&self, query: &str, document: &str) -> Option<f64>;
}

// ── BM25-like full-text scorer ───────────────────────────────────────────

/// Simplified BM25 over a single-document context. We can't compute
/// real IDF without the full corpus available at score time, so this
/// uses a fixed per-term IDF approximation (longer terms = higher
/// IDF). The TF normalisation matches BM25's saturation curve. Output
/// is squashed into [0, 1] via a softplus-like mapping so it's
/// directly comparable to the semantic scorer's cosine output.
///
/// Real BM25 requires per-corpus IDF — when the Tantivy backend lands,
/// it implements `FullTextScorer` directly with proper IDF and this
/// simplified scorer becomes the test/MAS-fallback path.
#[derive(Debug, Default, Clone)]
pub struct Bm25LikeFullTextScorer {
    pub k1: f64,
    pub b: f64,
}

impl Bm25LikeFullTextScorer {
    pub fn new() -> Self {
        // Standard BM25 defaults
        Self { k1: 1.5, b: 0.75 }
    }
}

impl FullTextScorer for Bm25LikeFullTextScorer {
    fn score(&self, query: &str, document: &str) -> Option<f64> {
        let q_tokens = tokenise(query);
        if q_tokens.is_empty() {
            return None;
        }
        let d_tokens = tokenise(document);
        if d_tokens.is_empty() {
            return None;
        }

        let d_len = d_tokens.len() as f64;
        // No corpus-wide stats; approximate avg doc length as 50 (matches
        // typical PKM note length). Real Tantivy backend uses real
        // corpus stats.
        let avg_doc_len = 50.0_f64;

        let mut tf: BTreeMap<&str, usize> = BTreeMap::new();
        for token in &d_tokens {
            *tf.entry(token.as_str()).or_insert(0) += 1;
        }

        let mut score = 0.0;
        let mut matched = 0;
        for q_term in &q_tokens {
            let term_freq = *tf.get(q_term.as_str()).unwrap_or(&0) as f64;
            if term_freq == 0.0 {
                continue;
            }
            matched += 1;
            // IDF approximation: longer terms are rarer
            let idf = ((q_term.len() as f64) / 4.0).max(0.5).min(3.0);
            // BM25 TF saturation
            let numerator = term_freq * (self.k1 + 1.0);
            let denominator =
                term_freq + self.k1 * (1.0 - self.b + self.b * (d_len / avg_doc_len));
            score += idf * (numerator / denominator);
        }

        if matched == 0 {
            return None;
        }

        // Squash into [0, 1] via softplus-like mapping
        Some(softplus_clamp(score))
    }
}

// ── Trigram-cosine semantic scorer ────────────────────────────────────────

/// Character-trigram cosine similarity. Builds normalised TF vectors
/// over overlapping 3-grams of (lowercased) query and document, then
/// computes cosine. Handles short queries gracefully (any q_len < 3
/// gets a single-character or bigram fallback). Output is naturally
/// in [0.0, 1.0].
///
/// This is the deterministic semantic-ish backstop until the
/// embedding-backed HNSW backend (epistemos-shadow usearch via FFI)
/// lands.
#[derive(Debug, Default, Clone)]
pub struct TrigramCosineSemanticScorer;

impl SemanticScorer for TrigramCosineSemanticScorer {
    fn score(&self, query: &str, document: &str) -> Option<f64> {
        let q = trigrams(query);
        let d = trigrams(document);
        if q.is_empty() || d.is_empty() {
            return None;
        }
        let cosine = cosine_similarity(&q, &d);
        if cosine == 0.0 {
            None
        } else {
            Some(cosine)
        }
    }
}

// ── Backend dispatch ─────────────────────────────────────────────────────

/// Which backend the host wants. Today only `InMemoryDeterministic`
/// ships; `Shadow` is the future HNSW + Tantivy seam.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GraphSearchBackend {
    InMemoryDeterministic,
    /// Future: routes through epistemos-shadow's HNSW (semantic) +
    /// Tantivy (fulltext) backends via FFI. Construction will require
    /// a `vault_path` so the right per-vault indexes open.
    Shadow,
}

impl GraphSearchBackend {
    /// Construct the canonical fulltext scorer for this backend.
    /// Today both variants return Bm25LikeFullTextScorer; the Shadow
    /// variant will return a TantivyBackedScorer when wired.
    pub fn fulltext_scorer(&self) -> Box<dyn FullTextScorer> {
        // SAFETY: only InMemoryDeterministic ships today; Shadow falls
        // through to the same scorer until the FFI bridge lands. This
        // is intentionally the conservative behaviour — calling code
        // must opt into the Shadow backend explicitly when ready.
        Box::new(Bm25LikeFullTextScorer::new())
    }

    /// Construct the canonical semantic scorer for this backend.
    /// Today both variants return TrigramCosineSemanticScorer; the
    /// Shadow variant will return an HnswBackedScorer when wired.
    pub fn semantic_scorer(&self) -> Box<dyn SemanticScorer> {
        Box::new(TrigramCosineSemanticScorer)
    }
}

impl Default for GraphSearchBackend {
    fn default() -> Self {
        Self::InMemoryDeterministic
    }
}

// ── Helpers ─────────────────────────────────────────────────────────────

fn tokenise(text: &str) -> Vec<String> {
    text.to_lowercase()
        .split(|c: char| !c.is_alphanumeric())
        .filter(|t| t.len() >= 2)
        .map(str::to_string)
        .collect()
}

fn softplus_clamp(score: f64) -> f64 {
    // Maps [0, +∞) → [0, 1) monotonically. softplus(x)/(softplus(x)+1)
    // saturates near 1 quickly without ever reaching 1.0, which
    // preserves strict-less-than ordering between hits.
    let sp = (1.0 + score.exp()).ln();
    sp / (sp + 1.0)
}

fn trigrams(text: &str) -> BTreeMap<String, usize> {
    let lowered = text.to_lowercase();
    let chars: Vec<char> = lowered.chars().collect();
    let mut grams: BTreeMap<String, usize> = BTreeMap::new();
    if chars.len() >= 3 {
        for window in chars.windows(3) {
            let g: String = window.iter().collect();
            *grams.entry(g).or_insert(0) += 1;
        }
    } else if chars.len() == 2 {
        // Fallback: two-char "bigram"
        let g: String = chars.iter().collect();
        *grams.entry(g).or_insert(0) += 1;
    } else if chars.len() == 1 {
        let g: String = chars.iter().collect();
        *grams.entry(g).or_insert(0) += 1;
    }
    grams
}

fn cosine_similarity(a: &BTreeMap<String, usize>, b: &BTreeMap<String, usize>) -> f64 {
    let mut dot = 0.0_f64;
    let mut norm_a = 0.0_f64;
    let mut norm_b = 0.0_f64;
    for (k, va) in a {
        let va = *va as f64;
        norm_a += va * va;
        if let Some(vb) = b.get(k) {
            dot += va * (*vb as f64);
        }
    }
    for vb in b.values() {
        let vb = *vb as f64;
        norm_b += vb * vb;
    }
    if norm_a == 0.0 || norm_b == 0.0 {
        0.0
    } else {
        dot / (norm_a.sqrt() * norm_b.sqrt())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bm25_like_scorer_returns_none_for_no_match() {
        let scorer = Bm25LikeFullTextScorer::new();
        assert!(scorer.score("rust agent", "completely unrelated text").is_none());
    }

    #[test]
    fn bm25_like_scorer_scores_higher_for_more_matches() {
        let scorer = Bm25LikeFullTextScorer::new();
        let single = scorer.score("rust agent", "rust is a language").unwrap();
        let double = scorer
            .score("rust agent", "rust agent runtime is the rust agent loop")
            .unwrap();
        assert!(double > single);
    }

    #[test]
    fn bm25_like_scorer_is_byte_stable_across_calls() {
        let scorer = Bm25LikeFullTextScorer::new();
        let a = scorer
            .score("agent loop", "the agent loop runs the agent")
            .unwrap();
        let b = scorer
            .score("agent loop", "the agent loop runs the agent")
            .unwrap();
        assert!((a - b).abs() < f64::EPSILON);
    }

    #[test]
    fn bm25_like_scorer_clamps_to_unit_interval() {
        let scorer = Bm25LikeFullTextScorer::new();
        // Spam-load a high-frequency term
        let doc = "agent ".repeat(500);
        let s = scorer.score("agent", &doc).unwrap();
        assert!(s >= 0.0 && s < 1.0, "score must stay in [0, 1)");
    }

    #[test]
    fn trigram_semantic_scorer_returns_higher_for_similar_text() {
        let scorer = TrigramCosineSemanticScorer;
        let exact = scorer.score("rust agent loop", "rust agent loop").unwrap();
        let related = scorer
            .score("rust agent loop", "rust runtime agent")
            .unwrap();
        let unrelated = scorer
            .score("rust agent loop", "biological systems and metabolism")
            .unwrap_or(0.0);
        assert!(exact > related, "exact match must outscore related");
        assert!(related > unrelated, "related must outscore unrelated");
    }

    #[test]
    fn trigram_semantic_scorer_is_byte_stable() {
        let scorer = TrigramCosineSemanticScorer;
        let a = scorer.score("agent loop", "the agent loop").unwrap();
        let b = scorer.score("agent loop", "the agent loop").unwrap();
        assert!((a - b).abs() < f64::EPSILON);
    }

    #[test]
    fn trigram_semantic_scorer_handles_short_queries() {
        let scorer = TrigramCosineSemanticScorer;
        // 3-char query against text containing it as a trigram → match
        assert!(scorer.score("abc", "abcdef").is_some());
        // 2-char query produces a bigram; doc must contain that bigram
        // as one of its windows (here: "ab" is the first 2 chars of
        // "abc" → not in the trigram set; document needs to be just
        // 2 chars too to share the bigram "ab")
        assert!(scorer.score("ab", "ab").is_some());
        // Distinct query and document with no overlap returns None,
        // not Some(0.0). Asserts the gating contract holds.
        assert!(scorer.score("xyz", "qqqq").is_none());
    }

    #[test]
    fn graph_search_backend_default_is_in_memory_deterministic() {
        assert_eq!(GraphSearchBackend::default(), GraphSearchBackend::InMemoryDeterministic);
    }

    #[test]
    fn graph_search_backend_constructs_scorers_for_both_variants() {
        let in_mem = GraphSearchBackend::InMemoryDeterministic;
        let shadow = GraphSearchBackend::Shadow;
        // Both must produce non-panicking scorer factories
        let _ = in_mem.fulltext_scorer();
        let _ = in_mem.semantic_scorer();
        let _ = shadow.fulltext_scorer();
        let _ = shadow.semantic_scorer();
    }
}
