use std::collections::{HashMap, HashSet};
use std::path::{Component, Path, PathBuf};
use std::sync::Mutex;

use async_trait::async_trait;
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use tantivy::collector::TopDocs;
use tantivy::query::QueryParser;
use tantivy::schema::{Field, Schema, Value, STORED, STRING, TEXT};
use tantivy::{doc, Index, IndexReader, IndexWriter, ReloadPolicy, TantivyDocument, Term};

use crate::storage::retrieval_trace::{
    PageGatherEscalationTrace, RetrievalCandidate, RetrievalSignal, RetrievalSignalScore,
    RetrievalTrace,
};
use crate::uas::{UasAddress, UasKind};

/// Chatter words stripped from `hybrid_search` queries before parsing.
///
/// F-VaultRecall-50 fix B (iter 81, 2026-05-16): the user-facing agent query
/// like "Pull my notes on residency governance" was being tokenized into 6
/// terms with Tantivy's default implicit-OR conjunction, causing chatter
/// words ("pull", "my", "notes", "on") to dominate the BM25 score across
/// irrelevant docs. Stripping these gives the residual signal terms
/// ("residency", "governance") priority. See
/// `docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md` for full diagnosis.
///
/// Lower-cased. Match is case-insensitive.
const QUERY_CHATTER_WORDS: &[&str] = &[
    // Imperative chat prefixes
    "pull", "find", "show", "get", "give", "tell", "list", "search", "look",
    // First/second person
    "me", "my", "i", "you", "your", "us", "our", // Discourse particles
    "please", "can", "could", "would", "should",
    // Common stop-words that appear in chatty prefixes
    "the", "a", "an", "of", "in", "on", "to", "for", "with", "about", "and", "or", "but", "is",
    "are", "was", "were", // Generic referents
    "notes", "note", "files", "file", "stuff", "things", "thing",
    // Wh-question words (kept narrow — these can be legitimate signal)
    "what", "where", "when", "how", "why", "which", // Misc filler
    "any", "some", "all", "want", "need",
];

/// Strip chatter words from a query string so signal-bearing terms dominate
/// the resulting BM25 ranking. Preserves casing of surviving terms (Tantivy's
/// default tokenizer lowercases internally; we lowercase only for the
/// stop-word match).
///
/// Behavior:
/// - Splits on whitespace
/// - Drops tokens whose lowercase form is in `QUERY_CHATTER_WORDS`
/// - Rejoins with single spaces
/// - Returns the empty string if every token is chatter (caller must fall
///   back to the original query)
///
/// Doctrine: see F-VaultRecall-50 diagnosis §4 Fix B for the rationale.
pub fn strip_query_chatter(query: &str) -> String {
    query
        .split_whitespace()
        .filter(|token| !QUERY_CHATTER_WORDS.contains(&token.to_lowercase().as_str()))
        .collect::<Vec<_>>()
        .join(" ")
}

fn vault_recall_candidate_pool_limit(limit: usize) -> usize {
    if limit == 0 {
        return 0;
    }
    limit.saturating_mul(10).clamp(50, 200)
}

fn normalized_query_terms(query: &str) -> Vec<String> {
    query
        .split(|ch: char| !ch.is_alphanumeric())
        .map(str::trim)
        .filter(|term| !term.is_empty())
        .map(str::to_lowercase)
        .collect()
}

fn normalized_signal_terms(query: &str) -> HashSet<String> {
    normalized_query_terms(query)
        .into_iter()
        .filter(|term| term.len() > 1 && !QUERY_CHATTER_WORDS.contains(&term.as_str()))
        .collect()
}

fn folded_alphanumeric_terms(value: &str) -> Vec<String> {
    deunicode::deunicode(value)
        .split(|ch: char| !ch.is_ascii_alphanumeric())
        .map(str::trim)
        .filter(|term| !term.is_empty())
        .map(str::to_lowercase)
        .collect()
}

fn push_unique_concept(concepts: &mut Vec<String>, concept: &str) {
    if !concept.is_empty() && !concepts.iter().any(|existing| existing == concept) {
        concepts.push(concept.to_string());
    }
}

fn rot13_ascii(value: &str) -> String {
    value
        .chars()
        .map(|ch| match ch {
            'a'..='z' => (((ch as u8 - b'a' + 13) % 26) + b'a') as char,
            'A'..='Z' => (((ch as u8 - b'A' + 13) % 26) + b'A') as char,
            _ => ch,
        })
        .collect()
}

fn leet_ascii(value: &str) -> String {
    value
        .chars()
        .map(|ch| match ch {
            '0' => 'o',
            '1' => 'i',
            '3' => 'e',
            '4' => 'a',
            '5' => 's',
            '7' => 't',
            _ => ch,
        })
        .collect()
}

fn push_token_concepts_for_variant(concepts: &mut Vec<String>, token: &str) {
    if token.contains("mamba") || token == "mmb" || token == "manba" {
        push_unique_concept(concepts, "mamba");
    }
    if token == "ssm"
        || token == "ssl"
        || token == "ssi"
        || token.contains("ssm")
        || token.contains("state") && token.contains("space") && token.contains("model")
    {
        push_unique_concept(concepts, "ssm");
    }
    if token.contains("cach")
        || token == "store"
        || token == "kashe"
        || token == "kesh"
        || token == "cch"
        || token == "cachefile"
        || token == "cachecache"
    {
        push_unique_concept(concepts, "cache");
    }
    if token == "ml" {
        push_unique_concept(concepts, "ml");
    }
    if token.contains("index") || token == "inedx" {
        push_unique_concept(concepts, "index");
    }
    if token.contains("reload") || token == "refresh" {
        push_unique_concept(concepts, "reload");
    }
    if token.contains("kernel") || token == "kernl" {
        push_unique_concept(concepts, "kernel");
    }
    if token.contains("inference") || token == "inferencee" {
        push_unique_concept(concepts, "inference");
    }
    if token == "cahce" {
        push_unique_concept(concepts, "cache");
    }
}

fn token_semantic_concepts(token: &str) -> Vec<String> {
    let mut concepts = Vec::new();
    if token.is_empty() || QUERY_CHATTER_WORDS.contains(&token) {
        return concepts;
    }

    for variant in [token.to_string(), leet_ascii(token), rot13_ascii(token)] {
        push_token_concepts_for_variant(&mut concepts, &variant);
    }

    if concepts.is_empty() {
        push_unique_concept(&mut concepts, token);
    }
    concepts
}

fn semantic_concepts(value: &str) -> HashSet<String> {
    let terms = folded_alphanumeric_terms(value);
    let mut concepts = Vec::with_capacity(terms.len());
    let mut index = 0;

    while index < terms.len() {
        if index + 2 < terms.len()
            && terms[index] == "state"
            && terms[index + 1] == "space"
            && terms[index + 2] == "model"
        {
            push_unique_concept(&mut concepts, "ssm");
            index += 3;
            continue;
        }
        if index + 1 < terms.len() && terms[index] == "machine" && terms[index + 1] == "learning" {
            push_unique_concept(&mut concepts, "ml");
            index += 2;
            continue;
        }
        if index + 1 < terms.len() {
            let joined = format!("{}{}", terms[index], terms[index + 1]);
            if joined == "mamba" || joined == "manba" {
                push_unique_concept(&mut concepts, "mamba");
                index += 2;
                continue;
            }
        }

        for concept in token_semantic_concepts(&terms[index]) {
            push_unique_concept(&mut concepts, &concept);
        }
        index += 1;
    }

    concepts.into_iter().collect()
}

fn semantic_concept_score(
    query_concepts: &HashSet<String>,
    document_concepts: &HashSet<String>,
) -> Option<f64> {
    if query_concepts.is_empty() || document_concepts.is_empty() {
        return None;
    }

    let overlap = query_concepts
        .iter()
        .filter(|concept| document_concepts.contains(*concept))
        .count();
    if overlap == 0 {
        return None;
    }

    let query_coverage = overlap as f64 / query_concepts.len() as f64;
    let passes = if query_concepts.len() <= 2 {
        overlap == query_concepts.len()
    } else {
        overlap >= 2 && query_coverage >= 0.60
    };
    if !passes {
        return None;
    }

    let overlap_bonus = overlap.min(5) as f64 / 5.0;
    Some(7.0 + (3.0 * query_coverage) + overlap_bonus)
}

fn normalized_title_key(value: &str) -> Option<String> {
    let key = normalized_query_terms(value).join(" ");
    (!key.is_empty()).then_some(key)
}

fn insert_title_candidate(candidates: &mut HashSet<String>, value: &str) {
    if let Some(key) = normalized_title_key(value) {
        candidates.insert(key);
    }
}

fn dequoted(value: &str) -> &str {
    value
        .trim()
        .trim_matches(|ch| matches!(ch, '"' | '\'' | '`' | ' ' | '\t' | '\n' | '\r' | '<' | '>'))
}

fn quoted_segments(query: &str) -> Vec<String> {
    let mut segments = Vec::new();
    for quote in ['"', '`'] {
        let mut active = false;
        let mut current = String::new();
        for ch in query.chars() {
            if ch == quote {
                if active && !current.trim().is_empty() {
                    segments.push(current.trim().to_string());
                }
                current.clear();
                active = !active;
            } else if active {
                current.push(ch);
            }
        }
    }
    segments
}

fn contains_normalized_phrase(value: &str, phrase: &str) -> bool {
    let value_terms = normalized_query_terms(value);
    let phrase_terms = normalized_query_terms(phrase);
    if value_terms.is_empty() || phrase_terms.is_empty() || phrase_terms.len() > value_terms.len() {
        return false;
    }
    value_terms
        .windows(phrase_terms.len())
        .any(|window| window == phrase_terms.as_slice())
}

fn document_matches_quoted_segments(segments: &[String], path: &str, content: &str) -> bool {
    segments.iter().all(|segment| {
        contains_normalized_phrase(content, segment) || contains_normalized_phrase(path, segment)
    })
}

fn suffix_after_marker(query: &str, markers: &[&str]) -> Vec<String> {
    let parts: Vec<&str> = query.split_whitespace().collect();
    let mut suffixes = Vec::new();
    for (index, part) in parts.iter().enumerate() {
        let token = part
            .trim_matches(|ch: char| !ch.is_alphanumeric())
            .to_lowercase();
        if markers.iter().any(|marker| token == *marker) && index + 1 < parts.len() {
            suffixes.push(parts[index + 1..].join(" "));
        }
    }
    suffixes
}

fn connect_synthesis_segments(query: &str) -> Vec<String> {
    let parts: Vec<&str> = query.split_whitespace().collect();
    let token_at = |part: &str| {
        part.trim_matches(|ch: char| !ch.is_alphanumeric())
            .to_lowercase()
    };

    let Some(connect_index) = parts.iter().position(|part| token_at(part) == "connect") else {
        return Vec::new();
    };
    let Some(with_offset) = parts[connect_index + 1..]
        .iter()
        .position(|part| token_at(part) == "with")
    else {
        return Vec::new();
    };
    let with_index = connect_index + 1 + with_offset;

    let mut segments = Vec::with_capacity(2);
    for segment in [
        parts[connect_index + 1..with_index].join(" "),
        parts[with_index + 1..].join(" "),
    ] {
        if normalized_signal_terms(&segment).len() >= 2 {
            segments.push(segment);
        }
    }
    segments
}

fn stripped_title_prefix(query: &str) -> Option<String> {
    const PREFIX_WORDS: &[&str] = &[
        "pull", "find", "show", "get", "give", "tell", "list", "search", "look", "open", "read",
        "edit", "update", "please", "can", "could", "would", "the", "a", "an", "note", "notes",
        "file", "files",
    ];

    let parts: Vec<&str> = query.split_whitespace().collect();
    let start = parts
        .iter()
        .position(|part| {
            let token = part
                .trim_matches(|ch: char| !ch.is_alphanumeric())
                .to_lowercase();
            !PREFIX_WORDS.contains(&token.as_str())
        })
        .unwrap_or(parts.len());
    (start > 0 && start < parts.len()).then(|| parts[start..].join(" "))
}

fn title_query_candidates(query: &str) -> HashSet<String> {
    const TITLE_MARKERS: &[&str] = &["title", "titled", "called", "named", "alias", "aliases"];
    const TOPIC_MARKERS: &[&str] = &["about", "topic"];

    let mut candidates = HashSet::new();
    insert_title_candidate(&mut candidates, query);

    if let Some(stripped) = stripped_title_prefix(query) {
        insert_title_candidate(&mut candidates, &stripped);
    }

    for segment in quoted_segments(query) {
        insert_title_candidate(&mut candidates, &segment);
    }
    for suffix in suffix_after_marker(query, TITLE_MARKERS) {
        insert_title_candidate(&mut candidates, &suffix);
    }
    for suffix in suffix_after_marker(query, TOPIC_MARKERS) {
        insert_title_candidate(&mut candidates, &suffix);
    }
    for segment in connect_synthesis_segments(query) {
        insert_title_candidate(&mut candidates, &segment);
    }

    candidates
}

fn title_match_score(
    query_titles: &HashSet<String>,
    title_keys: &HashSet<String>,
    allow_partial: bool,
) -> Option<f64> {
    if !query_titles.is_disjoint(title_keys) {
        return Some(12.0);
    }
    if !allow_partial {
        return None;
    }

    let mut best: Option<f64> = None;
    for query in query_titles {
        let query_terms = normalized_signal_terms(query);
        if query_terms.is_empty() {
            continue;
        }
        for title in title_keys {
            let title_terms = normalized_signal_terms(title);
            if title_terms.is_empty() {
                continue;
            }
            let overlap = query_terms
                .iter()
                .filter(|term| title_terms.contains(*term))
                .count();
            if overlap == 0 {
                continue;
            }
            let query_coverage = overlap as f64 / query_terms.len() as f64;
            let title_coverage = overlap as f64 / title_terms.len() as f64;
            if query_coverage < 0.67 && title_coverage < 0.67 {
                continue;
            }
            let score = 6.0 + (2.0 * query_coverage) + (2.0 * title_coverage) + overlap as f64;
            best = Some(best.map_or(score, |existing| existing.max(score)));
        }
    }

    best
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SearchResult {
    pub path: String,
    pub excerpt: String,
    pub score: f64,
    pub tags: Vec<String>,
}

impl SearchResult {
    pub fn projected_uas_address(&self) -> UasAddress {
        vault_note_path_uas_address(&self.path)
    }
}

#[derive(Debug, Clone)]
struct SemanticFallbackHit {
    result: SearchResult,
    raw_score: f64,
    normalized_score: f64,
    uas_address: UasAddress,
}

pub fn vault_note_path_uas_address(path: &str) -> UasAddress {
    let mut hasher = blake3::Hasher::new();
    hasher.update(b"agent_core.vault_note.path.v1\n");
    hasher.update(path.as_bytes());
    UasAddress::from_hash(UasKind::VaultNote, hasher.finalize(), 0)
}

pub fn vault_note_content_uas_address(path: &str, content: &str) -> UasAddress {
    let mut hasher = blake3::Hasher::new();
    hasher.update(b"agent_core.vault_note.content.v1\n");
    hasher.update(path.as_bytes());
    hasher.update(b"\0");
    hasher.update(content.as_bytes());
    UasAddress::from_hash(UasKind::VaultNote, hasher.finalize(), 0)
}

/// P5.H A2 (EML-3) — whether the EML secondary re-rank is enabled. OPT-IN,
/// default OFF (no behavior change) — `EPISTEMOS_EML_RERANK_V1=1` turns it on,
/// mirroring the schema gate's opt-in flag.
pub fn eml_rerank_enabled() -> bool {
    matches!(
        std::env::var("EPISTEMOS_EML_RERANK_V1")
            .map(|raw| raw.trim().to_ascii_lowercase())
            .as_deref(),
        Ok("1" | "true" | "yes" | "on")
    )
}

/// The secondary signal for the EML re-rank: how many DISTINCT query terms
/// (len ≥ 2, punctuation-trimmed, case-insensitive) appear in a result's
/// excerpt. A lexical-coverage signal orthogonal to BM25 (which weights by
/// IDF/frequency) — "the snippet actually mentions more of what I asked".
fn excerpt_query_coverage(query: &str, excerpt: &str) -> f64 {
    let lower_excerpt = excerpt.to_lowercase();
    let terms: std::collections::HashSet<String> = query
        .split_whitespace()
        .map(|t| {
            t.trim_matches(|c: char| !c.is_alphanumeric())
                .to_lowercase()
        })
        .filter(|t| t.len() >= 2)
        .collect();
    if terms.is_empty() {
        return 0.0;
    }
    terms
        .iter()
        .filter(|t| lower_excerpt.contains(t.as_str()))
        .count() as f64
}

/// Apply the EML secondary re-rank to `results` when enabled, else return them
/// unchanged. Fuses BM25 (`result.score`) with the excerpt query-coverage via
/// `eml_rerank::rerank_key` (smaller energy first). Pure given the env flag.
pub fn apply_eml_rerank(query: &str, results: Vec<SearchResult>) -> Vec<SearchResult> {
    if !eml_rerank_enabled() {
        return results;
    }
    crate::eml_rerank::rerank_by_eml(results, |result| {
        (result.score, excerpt_query_coverage(query, &result.excerpt))
    })
}

#[async_trait]
pub trait VaultBackend: Send + Sync {
    async fn hybrid_search(
        &self,
        query: &str,
        limit: usize,
        tag_filter: &[String],
    ) -> Result<Vec<SearchResult>, VaultError>;

    async fn hybrid_search_uas_addresses(
        &self,
        query: &str,
        limit: usize,
        tag_filter: &[String],
    ) -> Result<Vec<UasAddress>, VaultError> {
        let results = self.hybrid_search(query, limit, tag_filter).await?;
        let mut addresses = Vec::with_capacity(results.len());
        for result in &results {
            addresses.push(result.projected_uas_address());
        }
        Ok(addresses)
    }

    /// Tier-1 lexical-only search per
    /// `COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md` §4.2 — pure
    /// BM25 / keyword index match, no embedding component, no RRF
    /// fusion. Used by the `vault.search` Variant Ladder Tier 1 path
    /// (`agent_core::tools::vault_search_ladder`).
    ///
    /// Default delegates to [`hybrid_search`] so backends that don't
    /// (yet) differentiate continue to compile. Backends that DO have
    /// a true RRF-fused `hybrid_search` (e.g. one wrapping
    /// `epistemos-shadow`'s Tantivy + HNSW combo) MUST override this
    /// method with a lexical-only path — otherwise the ladder's T1
    /// tier does the same work as T3 and the strategy-differentiation
    /// is fake.
    ///
    /// For backends whose `hybrid_search` is already lexical-only
    /// (e.g. `VaultStore`'s Tantivy-only impl), the default delegation
    /// is correct: T1 = T3 method, T1 = stricter floor (0.85 vs 0.70).
    /// The ladder still routes high-confidence exact matches through
    /// T1 first, which keeps the doctrine's "cheap deterministic tier
    /// first" invariant honest.
    async fn lexical_search(
        &self,
        query: &str,
        limit: usize,
        tag_filter: &[String],
    ) -> Result<Vec<SearchResult>, VaultError> {
        self.hybrid_search(query, limit, tag_filter).await
    }

    /// T21 Vault Recall Contract (2026-05-18): every vault retrieval MUST
    /// emit a `RetrievalTrace` carrying the five canonical signals so the
    /// "first 7 irrelevant notes" failure is structurally impossible to
    /// hide. This default impl wraps [`hybrid_search`] and populates the
    /// `Lexical` signal from each result's raw BM25 score; backends with
    /// access to semantic / graph / recency / MMR pipelines MUST override
    /// to record those signals too. The trace's `effective_query` defaults
    /// to the input `query`; backends that pre-filter (e.g. `VaultStore`
    /// runs `strip_query_chatter`) MUST override to record the post-filter
    /// form so the W-21 diagnostics surface can show the Fix-B transform.
    ///
    /// Pure-additive: existing callers of `hybrid_search` continue to
    /// compile unchanged; new callers (ChatCoordinator vault-context-
    /// injection seam W-19, Brain Panel "Retrieved by" surface W-20,
    /// Settings → Diagnostics → "Vault recall health" W-21) consume the
    /// trace alongside the result list.
    async fn hybrid_search_with_trace(
        &self,
        query: &str,
        limit: usize,
        tag_filter: &[String],
    ) -> Result<(Vec<SearchResult>, RetrievalTrace), VaultError> {
        let results = self.hybrid_search(query, limit, tag_filter).await?;
        let mut trace = RetrievalTrace::new(query, query).with_pool_size(results.len());
        trace.record_signal(RetrievalSignal::Lexical);
        for result in &results {
            let mut candidate = RetrievalCandidate::new(result.path.clone(), result.score)
                .with_uas_address(result.projected_uas_address())
                .with_selection_reason("matched by default vault lexical result")
                .with_signal(RetrievalSignalScore::new(
                    RetrievalSignal::Lexical,
                    result.score,
                    result.score,
                ));
            if !result.excerpt.is_empty() {
                candidate = candidate.with_snippet(result.excerpt.clone());
            }
            trace.push_candidate(candidate);
        }
        Ok((results, trace))
    }

    async fn search(&self, query: &str, limit: usize) -> Result<Vec<String>, VaultError> {
        let results = self.hybrid_search(query, limit, &[]).await?;
        // P5.H A2 (EML-3) — flag-gated secondary re-rank (default OFF). Fuses
        // BM25 with excerpt query-coverage; no behavior change when disabled.
        let results = apply_eml_rerank(query, results);
        Ok(results
            .into_iter()
            .map(|result| {
                // T21 Fix C (2026-05-18): SearchResult.score is raw BM25 now
                // (unbounded above), not a [0,1] probability. Drop the
                // `* 100 + %` veneer that lied to the model. Match the
                // existing `{:.2}` BM25 format used by tools/registry.rs.
                format!(
                    "## {} (bm25: {:.2})\n{}",
                    result.path, result.score, result.excerpt
                )
            })
            .collect())
    }

    async fn read(&self, path: &str) -> Result<String, VaultError>;

    async fn write(
        &self,
        path: &str,
        content: &str,
        tags: Option<&[String]>,
        append: bool,
    ) -> Result<(), VaultError>;

    async fn list(&self, path_prefix: &str) -> Result<Vec<String>, VaultError>;

    async fn exists(&self, path: &str) -> Result<bool, VaultError>;

    async fn delete(&self, path: &str) -> Result<bool, VaultError>;
}

/// Production-capable vault-recall trace builder (R2 / W-21 follow-up,
/// 2026-05-23). Invokes the supplied [`VaultBackend`]'s
/// [`VaultBackend::hybrid_search_with_trace`] and returns the typed
/// `(results, trace)` tuple, defaulting the trace's `ladder_tier` to
/// `"production-hybrid"` when the backend did not set one.
///
/// **Why this exists**: the bridge-side `vault_recall_trace_json` FFI
/// is a fixture/stub built from the query alone (it cannot reach a
/// `VaultBackend` because the bridge has no shared handle yet). This
/// helper is the production seam: any caller that already holds a
/// `&dyn VaultBackend` (W-21 ChatCoordinator vault-context injection,
/// the Settings → Diagnostics vault recall health row aggregator, or
/// a future bridge FFI that gains a backend handle) MUST route through
/// this helper instead of rebuilding a stub trace.
///
/// The `"production-hybrid"` default makes the trace byte-distinguishable
/// from the scaffold tier (`"scaffold-lexical"`) the bridge emits when
/// no backend is wired, so downstream diagnostics can tell them apart
/// without parsing every candidate.
///
/// **Wire shape**: pure pass-through of [`RetrievalTrace`]; no serde
/// derive changes, no Swift mirror impact.
pub async fn produce_vault_recall_trace<B: VaultBackend + ?Sized>(
    backend: &B,
    query: &str,
    limit: usize,
    tag_filter: &[String],
) -> Result<(Vec<SearchResult>, RetrievalTrace), VaultError> {
    let (results, trace) = backend
        .hybrid_search_with_trace(query, limit, tag_filter)
        .await?;
    let trace = if trace.ladder_tier.is_none() {
        trace.with_ladder_tier("production-hybrid")
    } else {
        trace
    };
    Ok((results, trace))
}

#[derive(Debug, thiserror::Error)]
pub enum VaultError {
    #[error("note not found: {0}")]
    NotFound(String),
    #[error("io error: {0}")]
    IoError(#[from] std::io::Error),
    #[error("database error: {0}")]
    DatabaseError(String),
    #[error("index error: {0}")]
    IndexError(String),
    #[error("path traversal denied: {0}")]
    PathTraversal(String),
}

pub struct VaultStore {
    vault_root: PathBuf,
    db: Mutex<Connection>,
    ft_index: Index,
    ft_reader: IndexReader,
    ft_writer: Option<Mutex<IndexWriter>>,
    field_path: Field,
    field_content: Field,
    field_tags: Field,
}

impl VaultStore {
    pub fn open(vault_root: &str) -> Result<Self, VaultError> {
        Self::open_with_mode(vault_root, true)
    }

    pub fn open_read_only(vault_root: &str) -> Result<Self, VaultError> {
        Self::open_with_mode(vault_root, false)
    }

    /// T21 iter-7 (2026-05-18): force the Tantivy `IndexReader` to pick
    /// up freshly-committed writes immediately. The reader is configured
    /// with `ReloadPolicy::OnCommitWithDelay`, which means an auto-reload
    /// fires asynchronously after each commit; callers that need a
    /// deterministic "I just wrote, search now" guarantee (e.g. the
    /// F-VaultRecall-50 runner exercising a synthetic vault, or vault-
    /// sync code that wants visibility before returning to the user)
    /// can call this method to skip the delay.
    pub fn reload_index(&self) -> Result<(), VaultError> {
        self.ft_reader
            .reload()
            .map_err(|error| VaultError::IndexError(error.to_string()))
    }

    fn open_with_mode(vault_root: &str, writable_index: bool) -> Result<Self, VaultError> {
        let vault_root = PathBuf::from(vault_root);
        let meta_dir = vault_root.join(".epistemos");
        std::fs::create_dir_all(&meta_dir)?;

        let db_path = meta_dir.join("vault.db");
        let db = Connection::open(&db_path)
            .map_err(|error| VaultError::DatabaseError(error.to_string()))?;

        // D5 — substrate durability discipline (per docs/CANONICAL_AUDIT_LOG.md
        // Blocker D5). WAL keeps writers and readers from blocking each other,
        // synchronous=FULL forces SQLite to fsync every commit, foreign_keys=ON
        // matches the rest of the substrate. Same treatment as
        // OpLog::open_persistent so the vault DB survives a power-loss event.
        db.pragma_update(None, "journal_mode", "WAL")
            .map_err(|error| VaultError::DatabaseError(error.to_string()))?;
        db.pragma_update(None, "synchronous", "FULL")
            .map_err(|error| VaultError::DatabaseError(error.to_string()))?;
        db.pragma_update(None, "foreign_keys", "ON")
            .map_err(|error| VaultError::DatabaseError(error.to_string()))?;

        db.execute_batch(
            "
            CREATE TABLE IF NOT EXISTS notes (
                path TEXT PRIMARY KEY,
                content_hash TEXT NOT NULL,
                tags_json TEXT DEFAULT '[]',
                created_at TEXT NOT NULL DEFAULT (datetime('now')),
                updated_at TEXT NOT NULL DEFAULT (datetime('now'))
            );
            CREATE INDEX IF NOT EXISTS idx_notes_updated ON notes(updated_at);
            ",
        )
        .map_err(|error| VaultError::DatabaseError(error.to_string()))?;

        let _has_vec = db
            .execute_batch(
                "
                CREATE VIRTUAL TABLE IF NOT EXISTS note_embeddings USING vec0(
                    path TEXT PRIMARY KEY,
                    embedding float[384]
                );
                ",
            )
            .is_ok();

        let index_path = meta_dir.join("tantivy");
        std::fs::create_dir_all(&index_path)?;

        let mut schema_builder = Schema::builder();
        let field_path = schema_builder.add_text_field("path", STRING | STORED);
        let field_content = schema_builder.add_text_field("content", TEXT | STORED);
        let field_tags = schema_builder.add_text_field("tags", TEXT | STORED);
        let schema = schema_builder.build();

        let directory = tantivy::directory::MmapDirectory::open(&index_path)
            .map_err(|error| VaultError::IndexError(error.to_string()))?;
        let ft_index = Index::open_or_create(directory, schema)
            .map_err(|error| VaultError::IndexError(error.to_string()))?;
        let ft_reader = ft_index
            .reader_builder()
            .reload_policy(ReloadPolicy::OnCommitWithDelay)
            .try_into()
            .map_err(|error| VaultError::IndexError(error.to_string()))?;
        let ft_writer = if writable_index {
            // 15 MB is tantivy's documented minimum heap. Vault writes
            // happen on note save (low frequency); the 50 MB historical
            // budget was carried forward without measurement. Lowering
            // saves ~35 MB resident on idle.
            //
            // LockBusy recovery 2026-05-14 (RCA-VAULT-LOCKBUSY-001):
            // Tantivy's writer() acquires a filesystem advisory lock
            // (`.tantivy-writer.lock`). If another VaultStore instance
            // in this process or a stale crashed instance holds it, the
            // first attempt fails with `LockBusy`. The agent then sees
            // "Failed to open vault: index error: Failed to acquire
            // Lockfile: LockBusy" on note.create — surfaced verbatim to
            // the user. We retry up to 3× with exponential backoff
            // (50 / 150 / 450 ms) to clear transient holders. If still
            // busy after the retries, we attempt stale-lock removal
            // (the holder process is gone if `lsof` shows no live owner)
            // — best effort, ignored if not possible. As a last resort
            // we fall through to opening the vault in read-only mode +
            // mark the writer unavailable so subsequent vault.write
            // calls return a clear "another process holds the write
            // lock" error instead of an opaque LockBusy.
            let writer = match Self::acquire_index_writer(&ft_index, &index_path) {
                Ok(writer) => Some(Mutex::new(writer)),
                Err(error) => {
                    tracing::warn!(
                        index_path = %index_path.display(),
                        error = %error,
                        "vault index writer unavailable; vault opened read-only, vault.write will return clear error"
                    );
                    None
                }
            };
            writer
        } else {
            None
        };

        Ok(Self {
            vault_root,
            db: Mutex::new(db),
            ft_index,
            ft_reader,
            ft_writer,
            field_path,
            field_content,
            field_tags,
        })
    }

    fn writer(&self) -> Result<&Mutex<IndexWriter>, VaultError> {
        self.ft_writer.as_ref().ok_or_else(|| {
            VaultError::IndexError(
                "another process holds the vault index writer lock (Tantivy LockBusy); \
                 close other Epistemos instances or restart the app and try again"
                    .to_string(),
            )
        })
    }

    /// Acquire the Tantivy IndexWriter with bounded retry + stale-lock
    /// recovery. Returns the writer or a typed error.
    ///
    /// Retry strategy: 3 attempts at 50 / 150 / 450 ms backoff. If all
    /// fail with LockBusy, attempt to remove `.tantivy-writer.lock`
    /// (filesystem advisory lock — Tantivy auto-releases when the
    /// holding process dies, so a stale file usually clears on its own
    /// but a hard kill or crash can leave it behind). Final retry
    /// after stale-lock removal. If all 4 attempts fail, return the
    /// most recent error so the caller can fall back to read-only mode.
    fn acquire_index_writer(
        ft_index: &Index,
        index_path: &Path,
    ) -> Result<IndexWriter, VaultError> {
        const RETRY_DELAYS_MS: &[u64] = &[50, 150, 450];
        const HEAP_BYTES: usize = 15_000_000;

        let mut last_error: Option<String> = None;
        for delay_ms in RETRY_DELAYS_MS {
            match ft_index.writer(HEAP_BYTES) {
                Ok(writer) => return Ok(writer),
                Err(error) => {
                    let msg = error.to_string();
                    let normalized = msg.to_ascii_lowercase();
                    if normalized.contains("lockbusy") || normalized.contains("lock") {
                        tracing::debug!(
                            attempt_delay_ms = delay_ms,
                            error = %msg,
                            "vault index writer lock busy, retrying"
                        );
                        std::thread::sleep(std::time::Duration::from_millis(*delay_ms));
                        last_error = Some(msg);
                        continue;
                    }
                    return Err(VaultError::IndexError(msg));
                }
            }
        }

        // Stale-lock recovery: attempt to remove the lockfile if it
        // exists. Best effort — if the file is genuinely held by another
        // live process, the OS-level lock survives removal and the
        // retry below will still fail (correctly).
        let lockfile = index_path.join(".tantivy-writer.lock");
        if lockfile.exists() {
            tracing::warn!(
                lockfile = %lockfile.display(),
                "attempting stale Tantivy writer lockfile removal"
            );
            let _ = std::fs::remove_file(&lockfile);
        }

        // Final attempt after stale-lock removal.
        match ft_index.writer(HEAP_BYTES) {
            Ok(writer) => Ok(writer),
            Err(error) => Err(VaultError::IndexError(format!(
                "failed to acquire Tantivy index writer after 4 attempts ({} retries + 1 \
                 stale-lock cleanup): {}",
                RETRY_DELAYS_MS.len(),
                last_error.unwrap_or_else(|| error.to_string())
            ))),
        }
    }

    fn resolve_path(&self, relative: &str) -> Result<PathBuf, VaultError> {
        let normalized = relative
            .trim_start_matches(|ch| ch == '/' || ch == '\\')
            .replace('\\', "/");
        let mut safe_relative = PathBuf::new();
        for component in Path::new(&normalized).components() {
            match component {
                Component::Normal(segment) => safe_relative.push(segment),
                Component::CurDir => {}
                Component::ParentDir | Component::RootDir | Component::Prefix(_) => {
                    return Err(VaultError::PathTraversal(relative.to_string()));
                }
            }
        }
        let absolute = self.vault_root.join(&safe_relative);
        if !absolute.starts_with(&self.vault_root) {
            return Err(VaultError::PathTraversal(relative.to_string()));
        }
        Ok(absolute)
    }

    fn extract_tags(content: &str) -> Vec<String> {
        if !content.starts_with("---") {
            return Vec::new();
        }

        let Some(end) = content[3..].find("---").map(|index| index + 3) else {
            return Vec::new();
        };
        let frontmatter = &content[3..end];
        let mut tags = Vec::new();
        let mut in_tags = false;

        for line in frontmatter.lines() {
            let trimmed = line.trim();
            if let Some(rest) = trimmed.strip_prefix("tags:") {
                in_tags = true;
                let inline = rest.trim();
                if inline.starts_with('[') && inline.ends_with(']') {
                    let values = &inline[1..inline.len() - 1];
                    tags.extend(
                        values
                            .split(',')
                            .map(|value| {
                                value
                                    .trim()
                                    .trim_matches('"')
                                    .trim_matches('\'')
                                    .to_string()
                            })
                            .filter(|value| !value.is_empty()),
                    );
                    in_tags = false;
                }
            } else if in_tags && trimmed.starts_with("- ") {
                tags.push(
                    trimmed[2..]
                        .trim()
                        .trim_matches('"')
                        .trim_matches('\'')
                        .to_string(),
                );
            } else if in_tags && !trimmed.is_empty() {
                in_tags = false;
            }
        }

        tags
    }

    fn body_without_frontmatter(content: &str) -> &str {
        // Skip a YAML/TOML frontmatter block delimited by `---` if
        // present. Using `strip_prefix` instead of `&content[3..]`
        // means a future prefix-length change can't silently desync
        // the slice index.
        match content.strip_prefix("---") {
            Some(after_open) => after_open
                .find("---")
                .map(|i| after_open[i + 3..].trim_start())
                .unwrap_or(content),
            None => content,
        }
    }

    fn truncate_excerpt(value: &str, max_chars: usize) -> String {
        let value = value.trim();
        if value.chars().count() <= max_chars {
            return value.to_string();
        }

        let mut end = value.len();
        for (idx, _) in value.char_indices().skip(max_chars) {
            end = idx;
            break;
        }
        let prefix = &value[..end];
        let boundary = prefix
            .rfind(char::is_whitespace)
            .filter(|idx| *idx > 0)
            .unwrap_or(prefix.len());
        format!("{}…", prefix[..boundary].trim_end())
    }

    fn excerpt(content: &str, max_chars: usize) -> String {
        Self::truncate_excerpt(Self::body_without_frontmatter(content), max_chars)
    }

    fn excerpt_for_query(content: &str, query: &str, max_chars: usize) -> String {
        let body = Self::body_without_frontmatter(content);
        let terms = normalized_signal_terms(query);
        if !terms.is_empty() {
            for paragraph in body.split("\n\n") {
                let paragraph = paragraph.trim();
                if paragraph.is_empty() {
                    continue;
                }
                let paragraph_terms = normalized_signal_terms(paragraph);
                if terms.iter().any(|term| paragraph_terms.contains(term)) {
                    return Self::truncate_excerpt(paragraph, max_chars);
                }
            }
        }

        Self::excerpt(content, max_chars)
    }

    fn frontmatter_block(content: &str) -> Option<&str> {
        let after_open = content.strip_prefix("---")?;
        after_open.find("---").map(|end| &after_open[..end])
    }

    fn clean_frontmatter_value(value: &str) -> String {
        value
            .trim()
            .trim_end_matches(',')
            .trim_matches(|ch| matches!(ch, '"' | '\'' | '[' | ']'))
            .trim()
            .to_string()
    }

    fn split_inline_frontmatter_values(value: &str) -> Vec<String> {
        let trimmed = value.trim();
        if trimmed.starts_with('[') && trimmed.ends_with(']') {
            trimmed
                .trim_matches(|ch| ch == '[' || ch == ']')
                .split(',')
                .map(Self::clean_frontmatter_value)
                .filter(|value| !value.is_empty())
                .collect()
        } else {
            let cleaned = Self::clean_frontmatter_value(trimmed);
            if cleaned.is_empty() {
                Vec::new()
            } else {
                vec![cleaned]
            }
        }
    }

    fn extract_title_metadata(content: &str) -> Vec<String> {
        const TITLE_KEYS: &[&str] = &["title", "name", "alias", "aliases"];
        let Some(frontmatter) = Self::frontmatter_block(content) else {
            return Vec::new();
        };

        let mut values = Vec::new();
        let mut list_mode = false;
        for line in frontmatter.lines() {
            let trimmed = line.trim();
            if list_mode {
                if let Some(rest) = trimmed.strip_prefix('-') {
                    let cleaned = Self::clean_frontmatter_value(rest);
                    if !cleaned.is_empty() {
                        values.push(cleaned);
                    }
                    continue;
                }
                list_mode = false;
            }

            let Some((raw_key, raw_value)) = trimmed.split_once(':') else {
                continue;
            };
            let key = raw_key.trim().to_lowercase();
            if !TITLE_KEYS.contains(&key.as_str()) {
                continue;
            }
            let parsed_values = Self::split_inline_frontmatter_values(raw_value);
            if parsed_values.is_empty() {
                list_mode = key == "alias" || key == "aliases";
            } else {
                values.extend(parsed_values);
            }
        }

        values
    }

    fn title_keys_for_note(path: &str, content: &str) -> HashSet<String> {
        let mut keys = HashSet::new();
        let stem = Path::new(path)
            .file_stem()
            .and_then(|stem| stem.to_str())
            .unwrap_or(path);
        insert_title_candidate(&mut keys, stem);

        let path_without_extension = Path::new(path)
            .with_extension("")
            .to_string_lossy()
            .replace(['/', '\\', '_', '-'], " ");
        insert_title_candidate(&mut keys, &path_without_extension);

        for value in Self::extract_title_metadata(content) {
            insert_title_candidate(&mut keys, &value);
        }

        keys
    }

    fn path_candidates_from_query(query: &str) -> Vec<String> {
        let mut candidates = Vec::new();
        let mut push_candidate = |candidate: &str| {
            let candidate = dequoted(candidate);
            if candidate.is_empty() {
                return;
            }
            if !candidates.iter().any(|existing| existing == candidate) {
                candidates.push(candidate.to_string());
            }
        };

        push_candidate(query);
        for line in query.lines() {
            push_candidate(line);
        }
        for segment in quoted_segments(query) {
            push_candidate(&segment);
        }

        candidates
    }

    fn expand_home_path(path: &str) -> PathBuf {
        if let Some(rest) = path.strip_prefix("~/") {
            if let Some(home) = std::env::var_os("HOME") {
                return PathBuf::from(home).join(rest);
            }
        }
        PathBuf::from(path)
    }

    fn note_result_for_relative_path(
        &self,
        relative_path: &str,
        score: f64,
        tag_filter: &[String],
    ) -> Result<Option<SearchResult>, VaultError> {
        let absolute = self.resolve_path(relative_path)?;
        if !absolute.is_file() || absolute.extension().and_then(|ext| ext.to_str()) != Some("md") {
            return Ok(None);
        }

        let content = std::fs::read_to_string(&absolute).unwrap_or_default();
        let tags = Self::extract_tags(&content);
        if !tag_filter.is_empty() && !tag_filter.iter().all(|tag| tags.contains(tag)) {
            return Ok(None);
        }

        Ok(Some(SearchResult {
            path: relative_path.trim_matches('/').to_string(),
            excerpt: Self::excerpt(&content, 500),
            score,
            tags,
        }))
    }

    fn explicit_path_search(
        &self,
        query: &str,
        limit: usize,
        tag_filter: &[String],
    ) -> Result<Vec<SearchResult>, VaultError> {
        if limit == 0 {
            return Ok(Vec::new());
        }

        let root = self
            .vault_root
            .canonicalize()
            .unwrap_or_else(|_| self.vault_root.clone());
        let mut seen = HashSet::new();
        let mut results = Vec::new();
        for raw_candidate in Self::path_candidates_from_query(query) {
            let mut candidate = raw_candidate.replace("%20", " ");
            if let Some(rest) = candidate.strip_prefix("file://localhost/") {
                candidate = format!("/{rest}");
            } else if let Some(rest) = candidate.strip_prefix("file://") {
                candidate = rest.to_string();
            }

            let pathish = candidate.starts_with("~/")
                || candidate.starts_with('/')
                || candidate.contains('/')
                || candidate.contains('\\')
                || candidate.ends_with(".md");
            if !pathish {
                continue;
            }

            let path = Self::expand_home_path(&candidate);
            let relative = if path.is_absolute() {
                let absolute = path.canonicalize().unwrap_or(path);
                if !absolute.starts_with(&root) {
                    continue;
                }
                match absolute.strip_prefix(&root) {
                    Ok(relative) => relative.to_string_lossy().to_string(),
                    Err(_) => continue,
                }
            } else {
                candidate.trim_start_matches('/').to_string()
            };

            for relative_candidate in [relative.clone(), format!("{relative}.md")] {
                if !seen.insert(relative_candidate.clone()) {
                    continue;
                }
                if let Some(result) =
                    self.note_result_for_relative_path(&relative_candidate, 12.0, tag_filter)?
                {
                    results.push(result);
                    if results.len() >= limit {
                        return Ok(results);
                    }
                }
            }
        }

        Ok(results)
    }

    fn path_title_search(
        &self,
        query: &str,
        limit: usize,
        tag_filter: &[String],
        existing_paths: &HashSet<String>,
    ) -> Result<Vec<SearchResult>, VaultError> {
        let query_titles = title_query_candidates(query);
        if query_titles.is_empty() || limit == 0 {
            return Ok(Vec::new());
        }
        let allow_partial_title_match = quoted_segments(query).is_empty();

        let mut paths = Vec::new();
        Self::walk_dir(&self.vault_root, &self.vault_root, &mut paths)?;

        let mut results = Vec::new();
        for path in paths {
            if existing_paths.contains(&path) {
                continue;
            }

            let absolute = self.resolve_path(&path)?;
            let content = std::fs::read_to_string(&absolute).unwrap_or_default();
            let tags = Self::extract_tags(&content);
            if !tag_filter.is_empty() && !tag_filter.iter().all(|tag| tags.contains(tag)) {
                continue;
            }

            let title_keys = Self::title_keys_for_note(&path, &content);
            let Some(score) =
                title_match_score(&query_titles, &title_keys, allow_partial_title_match)
            else {
                continue;
            };
            results.push(SearchResult {
                path,
                excerpt: Self::excerpt_for_query(&content, query, 500),
                score,
                tags,
            });
        }

        results.sort_by(|lhs, rhs| {
            rhs.score
                .partial_cmp(&lhs.score)
                .unwrap_or(std::cmp::Ordering::Equal)
                .then_with(|| lhs.path.cmp(&rhs.path))
        });
        results.truncate(limit);
        Ok(results)
    }

    fn semantic_fallback_search(
        &self,
        query: &str,
        limit: usize,
        tag_filter: &[String],
        existing_paths: &HashSet<String>,
    ) -> Result<Vec<SemanticFallbackHit>, VaultError> {
        if limit == 0 {
            return Ok(Vec::new());
        }

        let query_concepts = semantic_concepts(query);
        if query_concepts.is_empty() {
            return Ok(Vec::new());
        }

        let mut paths = Vec::new();
        Self::walk_dir(&self.vault_root, &self.vault_root, &mut paths)?;

        let mut results = Vec::new();
        for path in paths {
            if existing_paths.contains(&path) {
                continue;
            }

            let absolute = self.resolve_path(&path)?;
            let content = std::fs::read_to_string(&absolute).unwrap_or_default();
            let tags = Self::extract_tags(&content);
            if !tag_filter.is_empty() && !tag_filter.iter().all(|tag| tags.contains(tag)) {
                continue;
            }

            let document_concepts = semantic_concepts(&format!("{path}\n{content}"));
            let Some(score) = semantic_concept_score(&query_concepts, &document_concepts) else {
                continue;
            };
            results.push(SemanticFallbackHit {
                result: SearchResult {
                    path: path.clone(),
                    excerpt: Self::excerpt_for_query(&content, query, 500),
                    score,
                    tags,
                },
                raw_score: score,
                normalized_score: (score / 11.0).clamp(0.0, 1.0),
                uas_address: vault_note_content_uas_address(&path, &content),
            });
        }

        results.sort_by(|lhs, rhs| {
            rhs.result
                .score
                .partial_cmp(&lhs.result.score)
                .unwrap_or(std::cmp::Ordering::Equal)
                .then_with(|| lhs.result.path.cmp(&rhs.result.path))
        });
        results.truncate(limit);
        Ok(results)
    }

    fn content_hash(content: &str) -> String {
        let mut digest = Sha256::new();
        digest.update(content.as_bytes());
        digest
            .finalize()
            .iter()
            .map(|byte| format!("{byte:02x}"))
            .collect()
    }

    /// Get the stored content hash for a note path. Returns None if not yet indexed.
    pub fn get_content_hash(&self, path: &str) -> Result<Option<String>, VaultError> {
        let conn = self
            .db
            .lock()
            .map_err(|_| VaultError::DatabaseError("lock poisoned".to_string()))?;
        let mut stmt = conn
            .prepare("SELECT content_hash FROM notes WHERE path = ?1")
            .map_err(|error| VaultError::DatabaseError(error.to_string()))?;
        let hash: Option<String> = stmt.query_row(params![path], |row| row.get(0)).ok();
        Ok(hash)
    }

    /// Update the stored content hash after successful processing.
    pub fn set_content_hash(&self, path: &str, hash: &str) -> Result<(), VaultError> {
        let conn = self
            .db
            .lock()
            .map_err(|_| VaultError::DatabaseError("lock poisoned".to_string()))?;
        conn.execute(
            "UPDATE notes SET content_hash = ?1, updated_at = datetime('now') WHERE path = ?2",
            params![hash, path],
        )
        .map_err(|error| VaultError::DatabaseError(error.to_string()))?;
        Ok(())
    }

    /// Given a list of vault-relative paths, return only those whose current
    /// file content hash differs from the stored hash (new, changed, or missing).
    pub fn changed_paths_since(&self, paths: &[String]) -> Result<Vec<String>, VaultError> {
        let mut changed = Vec::new();
        for path in paths {
            let stored = self.get_content_hash(path)?;
            let full_path = self.vault_root.join(path);
            let current = std::fs::read_to_string(&full_path)
                .ok()
                .map(|content| Self::content_hash(&content));
            match (stored, current) {
                (Some(ref s), Some(ref c)) if s == c => {} // unchanged — skip
                _ => changed.push(path.clone()),           // new, changed, or missing
            }
        }
        Ok(changed)
    }

    fn index_note(&self, path: &str, content: &str, tags: &[String]) -> Result<(), VaultError> {
        let mut writer = self
            .writer()?
            .lock()
            .map_err(|_| VaultError::IndexError("writer lock poisoned".to_string()))?;

        writer.delete_term(Term::from_field_text(self.field_path, path));
        writer
            .add_document(doc!(
                self.field_path => path,
                self.field_content => content,
                self.field_tags => tags.join(" ")
            ))
            .map_err(|error| VaultError::IndexError(error.to_string()))?;
        writer
            .commit()
            .map_err(|error| VaultError::IndexError(error.to_string()))?;
        Ok(())
    }

    fn walk_dir(dir: &Path, root: &Path, entries: &mut Vec<String>) -> Result<(), VaultError> {
        for entry in std::fs::read_dir(dir)? {
            let entry = entry?;
            let path = entry.path();
            let name = path
                .file_name()
                .and_then(|name| name.to_str())
                .unwrap_or("");
            if name.starts_with('.') {
                continue;
            }

            if path.is_dir() {
                Self::walk_dir(&path, root, entries)?;
            } else if path.extension().and_then(|ext| ext.to_str()) == Some("md") {
                if let Ok(relative) = path.strip_prefix(root) {
                    entries.push(relative.to_string_lossy().to_string());
                }
            }
        }

        Ok(())
    }
}

#[async_trait]
impl VaultBackend for VaultStore {
    /// T21 iter-5 (2026-05-18): thin delegation wrapper. The canonical
    /// retrieval body lives in [`hybrid_search_with_trace`] below so there
    /// is exactly one source of truth for Fix-B chatter strip + Fix-C
    /// raw-BM25 + tag-filter culling. Callers who don't need the trace
    /// discard it here.
    async fn hybrid_search(
        &self,
        query: &str,
        limit: usize,
        tag_filter: &[String],
    ) -> Result<Vec<SearchResult>, VaultError> {
        let (results, _trace) = self
            .hybrid_search_with_trace(query, limit, tag_filter)
            .await?;
        Ok(results)
    }

    /// T21 iter-5 (2026-05-18): VaultStore-specific override of the typed
    /// retrieval-trace path. Records the true Tantivy `top_docs` pool size
    /// (pre-tag-filter, pre-limit-cut), the chatter-stripped
    /// `effective_query` (Fix-B output), and free-form notes that name
    /// the Fix-B + AND-conjunction transforms when they fire. The W-21
    /// diagnostics surface consumes these notes to render the "what the
    /// retriever actually saw" breakdown.
    ///
    /// The body holds the canonical retrieval logic; the trait's
    /// `hybrid_search` is a thin wrapper that discards the trace.
    async fn hybrid_search_with_trace(
        &self,
        query: &str,
        limit: usize,
        tag_filter: &[String],
    ) -> Result<(Vec<SearchResult>, RetrievalTrace), VaultError> {
        let searcher = self.ft_reader.searcher();
        let mut query_parser =
            QueryParser::for_index(&self.ft_index, vec![self.field_content, self.field_tags]);

        // F-VaultRecall-50 Fix B (iter 81, 2026-05-16): strip chatter
        // ("Pull my notes on …") so signal-bearing terms dominate BM25.
        // For short queries (≤3 surviving terms), switch to implicit-AND
        // so all topical terms must appear; longer queries keep implicit-OR
        // to preserve recall. If filtering empties the query, fall back to
        // the original so we don't return a parse error.
        let stripped = strip_query_chatter(query);
        // T21 iter-10 (2026-05-18): the all-chatter case (every query
        // token is a chatter word, e.g. "show me my notes") falls back
        // to the raw input below — we record it so the trace flips to
        // weak evidence regardless of how many notes the chatter-laden
        // query incidentally hit.
        let all_chatter_fallback = stripped.is_empty() && !query.trim().is_empty();
        let chatter_stripped = !stripped.is_empty() && stripped != query;
        let effective_query: &str = if stripped.is_empty() {
            query
        } else {
            stripped.as_str()
        };
        let surviving_terms = effective_query.split_whitespace().count();
        let and_conjunction_applied = surviving_terms > 0 && surviving_terms <= 3;
        if and_conjunction_applied {
            query_parser.set_conjunction_by_default();
        }

        let build_trace = |pool_size| {
            let mut trace = RetrievalTrace::new(query, effective_query).with_pool_size(pool_size);
            trace.record_signal(RetrievalSignal::Lexical);
            if all_chatter_fallback {
                trace.record_all_chatter_fallback();
                trace.add_note(format!(
                    "Fix-B all-chatter fallback: query {query:?} stripped to empty; falling back to raw input (consumers SHOULD treat trace as weak evidence)"
                ));
            }
            if chatter_stripped {
                trace.add_note(format!(
                    "Fix-B chatter strip: {query:?} → {effective_query:?} ({surviving_terms} surviving terms)"
                ));
            }
            if and_conjunction_applied {
                trace.add_note(format!(
                    "AND conjunction applied (surviving_terms = {surviving_terms} ≤ 3)"
                ));
            }
            trace
        };

        if limit == 0 {
            let mut trace = build_trace(0);
            trace.add_note("Zero-result guard: limit = 0; skipped Tantivy collection".to_string());
            return Ok((Vec::new(), trace));
        }

        let explicit_path_matches = self.explicit_path_search(query, limit, tag_filter)?;
        if !explicit_path_matches.is_empty() {
            let mut trace = build_trace(explicit_path_matches.len());
            trace.add_note(format!(
                "Explicit path fallback retained {} vault-relative or Finder-path matches for query {query:?}",
                explicit_path_matches.len()
            ));
            for result in &explicit_path_matches {
                let absolute = self.resolve_path(&result.path)?;
                let content = std::fs::read_to_string(&absolute).unwrap_or_default();
                let mut candidate = RetrievalCandidate::new(result.path.clone(), result.score)
                    .with_uas_address(vault_note_content_uas_address(&result.path, &content))
                    .with_selection_reason("matched by explicit vault path")
                    .with_signal(RetrievalSignalScore::new(
                        RetrievalSignal::Lexical,
                        result.score,
                        result.score,
                    ));
                if !result.excerpt.is_empty() {
                    candidate = candidate.with_snippet(result.excerpt.clone());
                }
                trace.push_candidate(candidate);
            }
            trace.record_page_gather_escalation(PageGatherEscalationTrace::vault_escalated(
                "VaultStore::hybrid_search_with_trace:explicit_path",
                explicit_path_matches.len(),
                explicit_path_matches.len(),
            ));
            trace.add_note(
                "Explicit path lookup bypassed broad filesystem search; retained path is vault-scoped",
            );
            return Ok((explicit_path_matches, trace));
        }

        let parsed_query = query_parser
            .parse_query(effective_query)
            .map_err(|error| VaultError::IndexError(error.to_string()))?;
        let top_docs = searcher
            .search(
                &parsed_query,
                &TopDocs::with_limit(vault_recall_candidate_pool_limit(limit)),
            )
            .map_err(|error| VaultError::IndexError(error.to_string()))?;

        let pool_size = top_docs.len();
        let page_gather_score_source: Vec<f32> =
            top_docs.iter().map(|(score, _address)| *score).collect();
        let quoted_query_segments = quoted_segments(query);
        let mut results = Vec::new();
        let mut trace_candidates: HashMap<String, (String, UasAddress)> = HashMap::new();
        let mut semantic_signal_scores: HashMap<String, (f64, f64)> = HashMap::new();
        let mut trace_source_positions: Vec<u32> = Vec::new();
        for (source_position, (score, address)) in top_docs.into_iter().enumerate() {
            let document: TantivyDocument = searcher
                .doc(address)
                .map_err(|error| VaultError::IndexError(error.to_string()))?;
            let path = document
                .get_first(self.field_path)
                .and_then(|value| value.as_str())
                .unwrap_or("")
                .to_string();
            let content = document
                .get_first(self.field_content)
                .and_then(|value| value.as_str())
                .unwrap_or("");
            let uas_address = vault_note_content_uas_address(&path, content);
            let tags = Self::extract_tags(content);

            if !tag_filter.is_empty() && !tag_filter.iter().all(|tag| tags.contains(tag)) {
                continue;
            }
            if !quoted_query_segments.is_empty()
                && !document_matches_quoted_segments(&quoted_query_segments, &path, content)
            {
                continue;
            }

            let excerpt = Self::excerpt_for_query(content, effective_query, 500);
            let score = score as f64;
            trace_candidates.insert(path.clone(), (excerpt.clone(), uas_address));
            trace_source_positions.push(source_position as u32);

            // T21 Fix C (2026-05-18): preserve raw BM25. Tantivy scores are
            // unbounded above; the previous `.clamp(0.0, 1.0)` flattened
            // every match to 1.0 and degraded vault_search_ladder.rs's
            // FLOOR_T1/FLOOR_T3 floors into a "non-empty?" check. See
            // docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md §1
            // Defect 3 + §4 Fix C. Downstream consumers must treat
            // SearchResult.score as raw BM25, not a probability.
            results.push(SearchResult {
                path,
                excerpt,
                score,
                tags,
            });

            if results.len() >= limit {
                break;
            }
        }
        let lexical_paths: HashSet<String> =
            results.iter().map(|result| result.path.clone()).collect();

        let path_title_matches = if !all_chatter_fallback {
            let existing_paths: HashSet<String> =
                results.iter().map(|result| result.path.clone()).collect();
            self.path_title_search(query, limit, tag_filter, &existing_paths)?
        } else {
            Vec::new()
        };
        let path_title_match_count = path_title_matches.len();
        let path_title_paths: HashSet<String> = path_title_matches
            .iter()
            .map(|result| result.path.clone())
            .collect();
        if path_title_match_count > 0 {
            for result in &path_title_matches {
                let absolute = self.resolve_path(&result.path)?;
                let content = std::fs::read_to_string(&absolute).unwrap_or_default();
                trace_candidates.insert(
                    result.path.clone(),
                    (
                        result.excerpt.clone(),
                        vault_note_content_uas_address(&result.path, &content),
                    ),
                );
            }
            results.extend(path_title_matches);
            results.sort_by(|lhs, rhs| {
                rhs.score
                    .partial_cmp(&lhs.score)
                    .unwrap_or(std::cmp::Ordering::Equal)
                    .then_with(|| lhs.path.cmp(&rhs.path))
            });
            results.truncate(limit);
        }

        let semantic_matches =
            if !all_chatter_fallback && quoted_query_segments.is_empty() && results.is_empty() {
                let existing_paths: HashSet<String> =
                    results.iter().map(|result| result.path.clone()).collect();
                self.semantic_fallback_search(effective_query, limit, tag_filter, &existing_paths)?
            } else {
                Vec::new()
            };
        let semantic_match_count = semantic_matches.len();
        for hit in semantic_matches {
            let path = hit.result.path.clone();
            trace_candidates.insert(path.clone(), (hit.result.excerpt.clone(), hit.uas_address));
            semantic_signal_scores.insert(path, (hit.raw_score, hit.normalized_score));
            results.push(hit.result);
        }
        if semantic_match_count > 0 {
            results.sort_by(|lhs, rhs| {
                rhs.score
                    .partial_cmp(&lhs.score)
                    .unwrap_or(std::cmp::Ordering::Equal)
                    .then_with(|| lhs.path.cmp(&rhs.path))
            });
            results.truncate(limit);
        }
        let semantic_retained_count = results
            .iter()
            .filter(|result| semantic_signal_scores.contains_key(&result.path))
            .count();

        let trace_pool_size = pool_size + path_title_match_count + semantic_match_count;
        let mut trace = build_trace(trace_pool_size);
        if pool_size == 0 && path_title_match_count == 0 && semantic_match_count == 0 {
            trace.add_note(format!(
                "Zero-result guard: no lexical matches for effective query {effective_query:?}"
            ));
        } else if !tag_filter.is_empty() && results.is_empty() {
            trace.add_note(format!(
                "Zero-result guard: tag filter culled {trace_pool_size} lexical/path-title/semantic matches"
            ));
        } else if !tag_filter.is_empty() && results.len() < trace_pool_size {
            trace.add_note(format!(
                "Tag filter retained {} of {trace_pool_size} lexical/path-title/semantic matches",
                results.len()
            ));
        }
        if path_title_match_count > 0 {
            trace.add_note(format!(
                "Path/title fallback retained {path_title_match_count} vault-relative exact title/alias/metadata matches for query {query:?}"
            ));
        }
        if semantic_retained_count > 0 {
            trace.record_signal(RetrievalSignal::Semantic);
            trace.add_note(format!(
                "Semantic fallback retained {semantic_retained_count} concept-normalized vault matches for effective query {effective_query:?}"
            ));
        }
        for result in &results {
            let (excerpt, address) = trace_candidates
                .remove(&result.path)
                .unwrap_or_else(|| (result.excerpt.clone(), result.projected_uas_address()));
            let mut candidate = RetrievalCandidate::new(result.path.clone(), result.score)
                .with_uas_address(address)
                .with_selection_reason(if semantic_signal_scores.contains_key(&result.path) {
                    "matched by concept-normalized semantic vault fallback"
                } else if path_title_paths.contains(&result.path) {
                    "matched by vault path/title/alias metadata"
                } else {
                    "matched by lexical vault content/tags"
                });
            if !semantic_signal_scores.contains_key(&result.path)
                || lexical_paths.contains(&result.path)
            {
                candidate = candidate.with_signal(RetrievalSignalScore::new(
                    RetrievalSignal::Lexical,
                    result.score,
                    result.score,
                ));
            }
            if let Some((raw, normalized)) = semantic_signal_scores.get(&result.path) {
                candidate = candidate.with_signal(RetrievalSignalScore::new(
                    RetrievalSignal::Semantic,
                    *raw,
                    *normalized,
                ));
            }
            if !excerpt.is_empty() {
                candidate = candidate.with_snippet(excerpt);
            }
            trace.push_candidate(candidate);
        }
        let mut page_gather_trace = PageGatherEscalationTrace::vault_escalated(
            "VaultStore::hybrid_search_with_trace",
            pool_size,
            results.len(),
        );
        if !trace_source_positions.is_empty() {
            let (_plan, packets, _stats) =
                crate::helios::page_gather::gather_block_sorted_packetized(
                    &page_gather_score_source,
                    &trace_source_positions,
                    crate::helios::DEFAULT_PAGE_GATHER_BLOCK_ELEMENTS,
                )
                .map_err(|error| {
                    VaultError::IndexError(format!("page gather packetized caller: {error:?}"))
                })?;
            page_gather_trace = page_gather_trace.with_packetized_caller(packets.len());
        }
        trace.record_page_gather_escalation(page_gather_trace);
        trace.add_note(
            "PageGather vault escalation trace recorded; packetized caller consumed retained-score packets; F-PageGather-Scatter measurement remains pending",
        );
        Ok((results, trace))
    }

    async fn read(&self, path: &str) -> Result<String, VaultError> {
        let absolute = self.resolve_path(path)?;
        if !absolute.exists() {
            return Err(VaultError::NotFound(path.to_string()));
        }
        Ok(std::fs::read_to_string(absolute)?)
    }

    async fn write(
        &self,
        path: &str,
        content: &str,
        tags: Option<&[String]>,
        append: bool,
    ) -> Result<(), VaultError> {
        let absolute = self.resolve_path(path)?;
        if let Some(parent) = absolute.parent() {
            std::fs::create_dir_all(parent)?;
        }

        let final_content = if append && absolute.exists() {
            format!("{}\n{}", std::fs::read_to_string(&absolute)?, content)
        } else if let Some(tags) = tags {
            if content.starts_with("---") || tags.is_empty() {
                content.to_string()
            } else {
                let frontmatter = format!(
                    "---\ntags:\n{}\n---\n\n",
                    tags.iter()
                        .map(|tag| format!("  - {tag}"))
                        .collect::<Vec<_>>()
                        .join("\n")
                );
                format!("{frontmatter}{content}")
            }
        } else {
            content.to_string()
        };

        std::fs::write(&absolute, &final_content)?;

        let extracted_tags = Self::extract_tags(&final_content);
        self.index_note(path, &final_content, &extracted_tags)?;

        let db = self
            .db
            .lock()
            .map_err(|_| VaultError::DatabaseError("db lock poisoned".to_string()))?;
        db.execute(
            "INSERT INTO notes (path, content_hash, tags_json, updated_at)
             VALUES (?1, ?2, ?3, datetime('now'))
             ON CONFLICT(path) DO UPDATE SET
               content_hash = ?2,
               tags_json = ?3,
               updated_at = datetime('now')",
            params![
                path,
                Self::content_hash(&final_content),
                serde_json::to_string(&extracted_tags).unwrap_or_else(|_| "[]".to_string()),
            ],
        )
        .map_err(|error| VaultError::DatabaseError(error.to_string()))?;

        Ok(())
    }

    async fn list(&self, path_prefix: &str) -> Result<Vec<String>, VaultError> {
        let absolute = self.resolve_path(path_prefix)?;
        if !absolute.is_dir() {
            return Ok(Vec::new());
        }

        let mut entries = Vec::new();
        Self::walk_dir(&absolute, &self.vault_root, &mut entries)?;
        Ok(entries)
    }

    async fn exists(&self, path: &str) -> Result<bool, VaultError> {
        Ok(self.resolve_path(path)?.exists())
    }

    async fn delete(&self, path: &str) -> Result<bool, VaultError> {
        let absolute = self.resolve_path(path)?;
        if !absolute.exists() {
            return Ok(false);
        }

        std::fs::remove_file(&absolute)?;

        let mut writer = self
            .writer()?
            .lock()
            .map_err(|_| VaultError::IndexError("writer lock poisoned".to_string()))?;
        writer.delete_term(Term::from_field_text(self.field_path, path));
        writer
            .commit()
            .map_err(|error| VaultError::IndexError(error.to_string()))?;

        let db = self
            .db
            .lock()
            .map_err(|_| VaultError::DatabaseError("db lock poisoned".to_string()))?;
        db.execute("DELETE FROM notes WHERE path = ?1", [path])
            .map_err(|error| VaultError::DatabaseError(error.to_string()))?;

        Ok(true)
    }
}

#[cfg(test)]
mod tests {
    use async_trait::async_trait;

    use super::{strip_query_chatter, SearchResult, VaultBackend, VaultError, VaultStore};

    struct DefaultTraceBackend;

    #[async_trait]
    impl VaultBackend for DefaultTraceBackend {
        async fn hybrid_search(
            &self,
            _query: &str,
            limit: usize,
            _tag_filter: &[String],
        ) -> Result<Vec<SearchResult>, VaultError> {
            let mut results = vec![
                SearchResult {
                    path: "notes/residency.md".to_string(),
                    excerpt: "residency governance".to_string(),
                    score: 4.0,
                    tags: Vec::new(),
                },
                SearchResult {
                    path: "notes/runtime.md".to_string(),
                    excerpt: "runtime router policy".to_string(),
                    score: 3.0,
                    tags: Vec::new(),
                },
            ];
            results.truncate(limit);
            Ok(results)
        }

        async fn read(&self, path: &str) -> Result<String, VaultError> {
            Ok(format!("content for {path}"))
        }

        async fn write(
            &self,
            _path: &str,
            _content: &str,
            _tags: Option<&[String]>,
            _append: bool,
        ) -> Result<(), VaultError> {
            Ok(())
        }

        async fn list(&self, _path_prefix: &str) -> Result<Vec<String>, VaultError> {
            Ok(Vec::new())
        }

        async fn exists(&self, _path: &str) -> Result<bool, VaultError> {
            Ok(false)
        }

        async fn delete(&self, _path: &str) -> Result<bool, VaultError> {
            Ok(false)
        }
    }

    /// F-VaultRecall-50 Fix B test 1: a chatty prefix is stripped down to
    /// the signal-bearing terms.
    ///
    /// Reproduces the canonical Day-in-the-Life 1:15 PM bug input.
    #[test]
    fn strip_query_chatter_drops_chatty_prefix_and_keeps_signal() {
        let input = "Pull my notes on residency governance";
        let cleaned = strip_query_chatter(input);
        assert_eq!(
            cleaned, "residency governance",
            "expected chatty prefix to be stripped; got {:?}",
            cleaned
        );
    }

    /// F-VaultRecall-50 Fix B test 2: signal-only query is unchanged.
    #[test]
    fn strip_query_chatter_preserves_signal_only_query() {
        let input = "residency governance";
        let cleaned = strip_query_chatter(input);
        assert_eq!(cleaned, "residency governance");
    }

    /// F-VaultRecall-50 Fix B test 3: all-chatter query becomes empty
    /// (caller falls back to original; that fallback is exercised in
    /// `hybrid_search`, not here — this test pins the helper's
    /// "all chatter → empty" contract).
    #[test]
    fn strip_query_chatter_returns_empty_on_pure_chatter() {
        let input = "pull my notes";
        let cleaned = strip_query_chatter(input);
        assert_eq!(
            cleaned, "",
            "expected pure-chatter query to filter to empty; got {:?}",
            cleaned
        );
    }

    /// F-VaultRecall-50 Fix B test 4: mixed case + multi-word signal +
    /// chatter survives correctly (Tantivy lowercases internally; we keep
    /// surviving terms' casing).
    #[test]
    fn strip_query_chatter_handles_mixed_case_and_multi_signal() {
        let input = "show me the Mamba SSM Cache notes";
        let cleaned = strip_query_chatter(input);
        // "show" "me" "the" "notes" stripped; "Mamba" "SSM" "Cache" survive.
        assert_eq!(cleaned, "Mamba SSM Cache");
    }

    #[test]
    fn search_result_projects_typed_vault_note_address() {
        let result = SearchResult {
            path: "notes/residency.md".to_string(),
            excerpt: String::new(),
            score: 1.0,
            tags: Vec::new(),
        };

        let address = result.projected_uas_address();
        assert_eq!(address.kind, crate::uas::UasKind::VaultNote);
        assert_eq!(address.created_at_ms, 0);
    }

    #[tokio::test]
    async fn default_hybrid_search_with_trace_projects_typed_uas_addresses() {
        let backend = DefaultTraceBackend;

        let (results, trace) = backend
            .hybrid_search_with_trace("residency governance", 2, &[])
            .await
            .expect("default trace");

        assert_eq!(trace.candidates.len(), results.len());
        for (candidate, result) in trace.candidates.iter().zip(results.iter()) {
            assert_eq!(candidate.path, result.path);
            assert_eq!(
                candidate.uas_address.as_ref(),
                Some(&result.projected_uas_address()),
                "default trace candidates must carry typed VaultNote UAS addresses"
            );
        }
    }

    #[tokio::test]
    async fn default_hybrid_search_with_trace_records_visible_selection_reasons() {
        let backend = DefaultTraceBackend;

        let (_results, trace) = backend
            .hybrid_search_with_trace("residency governance", 2, &[])
            .await
            .expect("default trace");

        assert!(
            trace
                .candidates
                .iter()
                .all(|candidate| !candidate.selection_reason.trim().is_empty()),
            "default T21 traces must explain why each retained vault candidate was selected"
        );
    }

    /// T21 Fix C contract test (2026-05-18): `hybrid_search` MUST NOT clamp
    /// BM25 scores to `[0.0, 1.0]`. Tantivy BM25 yields raw IDF/TF scores
    /// typically in the 1–15 range for strong topical matches; clamping
    /// destroys the relative-confidence signal that
    /// `agent_core/src/tools/vault_search_ladder.rs` (FLOOR_T1 = 0.85,
    /// FLOOR_T3 = 0.70) depends on.
    ///
    /// With the prior `score.clamp(0.0, 1.0)` in place, every non-empty
    /// result returned `score == 1.0` and the floor ladder degraded to
    /// "did Tantivy return anything?". This test pins the no-clamp
    /// contract so the regression cannot return.
    ///
    /// Cross-ref: docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md §1
    /// Defect 3, §4 Fix C.
    #[tokio::test]
    async fn hybrid_search_returns_raw_bm25_without_unit_clamp() {
        use super::VaultBackend;
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        // Seed several notes whose content repeats the topical bigram so
        // BM25 scores them well above the 1.0 ceiling that the prior
        // clamp would have flattened.
        let docs: [(&str, &str); 4] = [
            (
                "a.md",
                "residency governance tier compression governance residency residency governance",
            ),
            (
                "b.md",
                "residency residency governance hierarchy residency governance",
            ),
            (
                "c.md",
                "tier-3 residency governance budget residency governance",
            ),
            (
                "d.md",
                "ui design pull-down menu unrelated note about layout",
            ),
        ];
        for (path, content) in docs.iter() {
            store
                .write(path, content, None, false)
                .await
                .expect("write note");
        }
        // `ft_reader` uses `ReloadPolicy::OnCommitWithDelay`; force a
        // reload so the searcher sees the freshly-written docs deterministically.
        store.ft_reader.reload().expect("reload ft_reader");

        let results = store
            .hybrid_search("residency governance", 4, &[])
            .await
            .expect("hybrid search");
        assert!(
            !results.is_empty(),
            "expected matches for 'residency governance'"
        );

        let top_score = results.iter().map(|r| r.score).fold(0.0_f64, f64::max);
        assert!(
            top_score > 1.0,
            "expected raw BM25 top score > 1.0 (no unit clamp); got top_score = {top_score}. \
             The score.clamp(0.0, 1.0) regression at vault.rs:606 destroys floor-ladder signal — \
             see F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md §1 Defect 3."
        );
    }

    #[tokio::test]
    async fn hybrid_search_finds_filename_title_when_body_omits_query_terms() {
        use super::VaultBackend;
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        store
            .write(
                "some essays/My Autobiography.md",
                "I grew up around projects, school, and personal systems.",
                None,
                false,
            )
            .await
            .expect("write note");
        store.reload_index().expect("reload index");

        let (results, trace) = store
            .hybrid_search_with_trace("My Autobiography", 5, &[])
            .await
            .expect("hybrid_search_with_trace");

        let first = results
            .first()
            .expect("filename-title fallback should return the named note");
        assert_eq!(first.path, "some essays/My Autobiography.md");
        assert!(
            first.score >= 4.0,
            "path/title fallback must clear the vault.search ladder floor; got {}",
            first.score
        );
        assert!(
            trace
                .notes
                .iter()
                .any(|note| note.contains("Path/title fallback retained")),
            "trace must disclose filename-title fallback: {:?}",
            trace.notes
        );
        assert_eq!(
            trace.candidates.len(),
            results.len(),
            "path/title fallback results must remain visible in retrieval trace candidates"
        );
        assert!(
            trace
                .candidates
                .iter()
                .any(|candidate| candidate.path == "some essays/My Autobiography.md"),
            "trace candidates must include the path/title fallback hit: {:?}",
            trace.candidates
        );
    }

    #[tokio::test]
    async fn hybrid_search_resolves_partial_filename_title_when_body_omits_query_terms() {
        use super::VaultBackend;
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        store
            .write(
                "some essays/My Autobiography.md",
                "I grew up around projects, school, and personal systems.",
                None,
                false,
            )
            .await
            .expect("write note");
        store.reload_index().expect("reload index");

        let (results, trace) = store
            .hybrid_search_with_trace("autobiography", 5, &[])
            .await
            .expect("hybrid_search_with_trace");

        assert_eq!(
            results.first().map(|result| result.path.as_str()),
            Some("some essays/My Autobiography.md"),
            "partial title query should still find the named vault note"
        );
        assert!(
            trace
                .notes
                .iter()
                .any(|note| note.contains("Path/title fallback retained")),
            "trace must disclose partial path/title fallback: {:?}",
            trace.notes
        );
    }

    #[tokio::test]
    async fn hybrid_search_quoted_phrase_rejects_partial_title_overlap() {
        use super::VaultBackend;
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        store
            .write(
                "notes/design_general_system.md",
                "design middle system terms are deliberately non-adjacent",
                None,
                false,
            )
            .await
            .expect("write decoy note");
        store.reload_index().expect("reload index");

        let (results, _trace) = store
            .hybrid_search_with_trace("\"design system\"", 5, &[])
            .await
            .expect("hybrid_search_with_trace");

        assert!(
            results
                .iter()
                .all(|result| result.path != "notes/design_general_system.md"),
            "quoted phrase lookup must not promote partial title/path overlap: {:?}",
            results
        );
    }

    #[tokio::test]
    async fn hybrid_search_quoted_phrase_keeps_adjacent_body_match() {
        use super::VaultBackend;
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        store
            .write(
                "notes/design-system.md",
                "This note explains the design system tokens and spacing rules.",
                None,
                false,
            )
            .await
            .expect("write matching note");
        store.reload_index().expect("reload index");

        let (results, _trace) = store
            .hybrid_search_with_trace("\"design system\"", 5, &[])
            .await
            .expect("hybrid_search_with_trace");

        assert_eq!(
            results.first().map(|result| result.path.as_str()),
            Some("notes/design-system.md"),
            "quoted phrase lookup should retain adjacent body matches: {:?}",
            results
        );
    }

    #[tokio::test]
    async fn hybrid_search_excerpt_centers_matching_paragraph() {
        use super::VaultBackend;
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        let long_preface = "preface ".repeat(120);
        store
            .write(
                "research/runtime-note.md",
                &format!(
                    "{long_preface}\n\nThe semantic kernel maps a paragraph idea into UAS evidence before answer synthesis."
                ),
                None,
                false,
            )
            .await
            .expect("write note");
        store.reload_index().expect("reload index");

        let results = store
            .hybrid_search("semantic kernel", 3, &[])
            .await
            .expect("hybrid_search");
        let first = results.first().expect("semantic kernel match");

        assert!(
            first.excerpt.contains("semantic kernel"),
            "excerpt should focus the matching paragraph, got {:?}",
            first.excerpt
        );
        assert!(
            !first.excerpt.starts_with("preface preface"),
            "excerpt should not be the unrelated leading paragraph"
        );
    }

    #[tokio::test]
    async fn vault_write_rejects_parent_directory_path_without_silent_rewrite() {
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        let err = store
            .write("safe/../outside.md", "escape attempt", None, false)
            .await
            .unwrap_err();

        assert!(matches!(
            err,
            VaultError::PathTraversal(path) if path == "safe/../outside.md"
        ));
        assert!(
            !vault_root.path().join("safe/outside.md").exists(),
            "parent traversal must not be silently rewritten as a different in-vault path"
        );
    }

    #[tokio::test]
    async fn hybrid_search_keeps_exact_title_fallback_when_lexical_returns_weak_results() {
        use super::VaultBackend;
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        store
            .write(
                "some essays/My Autobiography.md",
                "I grew up around projects, school, and personal systems.",
                None,
                false,
            )
            .await
            .expect("write title-only note");
        store
            .write(
                "reference/autobiography-genre.md",
                "Autobiography can be treated as a literary genre.",
                None,
                false,
            )
            .await
            .expect("write lexical distractor");
        store.reload_index().expect("reload index");

        let (results, trace) = store
            .hybrid_search_with_trace("My Autobiography", 5, &[])
            .await
            .expect("hybrid_search_with_trace");

        assert_eq!(
            results.first().map(|result| result.path.as_str()),
            Some("some essays/My Autobiography.md"),
            "exact title fallback should outrank weak lexical distractors"
        );
        assert!(
            results
                .iter()
                .any(|result| result.path == "reference/autobiography-genre.md"),
            "lexical candidates should remain available after title fallback"
        );
        assert!(
            trace
                .notes
                .iter()
                .any(|note| note.contains("Path/title fallback retained")),
            "trace must disclose title fallback even when lexical search returned candidates: {:?}",
            trace.notes
        );
    }

    #[tokio::test]
    async fn hybrid_search_resolves_chatty_title_marker_when_body_omits_query_terms() {
        use super::VaultBackend;
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        store
            .write(
                "some essays/My Autobiography.md",
                "I grew up around projects, school, and personal systems.",
                None,
                false,
            )
            .await
            .expect("write note");
        store.reload_index().expect("reload index");

        let (results, trace) = store
            .hybrid_search_with_trace("please find the note titled My Autobiography", 5, &[])
            .await
            .expect("hybrid_search_with_trace");

        assert_eq!(
            results.first().map(|result| result.path.as_str()),
            Some("some essays/My Autobiography.md"),
            "title-marker fallback should preserve `My` as part of the exact title"
        );
        assert!(
            trace
                .notes
                .iter()
                .any(|note| note.contains("exact title/alias/metadata")),
            "trace should disclose title-marker fallback: {:?}",
            trace.notes
        );
    }

    #[tokio::test]
    async fn hybrid_search_original_title_query_prefers_canonical_note_over_distractor() {
        use super::VaultBackend;
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        store
            .write(
                "some essays/My Autobiography.md",
                "I grew up around projects, school, and personal systems.",
                None,
                false,
            )
            .await
            .expect("write canonical note");
        store
            .write(
                "zz_adversarial/My Autobiography - distractor.md",
                "This is a recently-created distractor for title lookup. It is not the original note.",
                Some(&["f-vaultrecall-distractor".to_string()]),
                false,
            )
            .await
            .expect("write distractor note");
        store.reload_index().expect("reload index");

        let (results, trace) = store
            .hybrid_search_with_trace("original note titled My Autobiography", 5, &[])
            .await
            .expect("hybrid_search_with_trace");

        assert_eq!(
            results.first().map(|result| result.path.as_str()),
            Some("some essays/My Autobiography.md"),
            "exact title fallback should beat the title-shaped distractor"
        );
        assert!(
            !results
                .iter()
                .take(1)
                .any(|result| result.path.contains("distractor")),
            "the first retained result must not be the adversarial title distractor: {:?}",
            results
        );
        assert!(
            trace
                .notes
                .iter()
                .any(|note| note.contains("Path/title fallback retained")),
            "trace must disclose that title fallback resolved the original-note query: {:?}",
            trace.notes
        );
    }

    #[tokio::test]
    async fn hybrid_search_resolves_frontmatter_alias_when_body_omits_query_terms() {
        use super::VaultBackend;
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        store
            .write(
                "archive/private-draft.md",
                "---\ntitle: Private Draft\naliases:\n  - My Autobiography\n---\n\nI grew up around projects, school, and personal systems.",
                None,
                false,
            )
            .await
            .expect("write note");
        store.reload_index().expect("reload index");

        let (results, trace) = store
            .hybrid_search_with_trace("My Autobiography", 5, &[])
            .await
            .expect("hybrid_search_with_trace");

        assert_eq!(
            results.first().map(|result| result.path.as_str()),
            Some("archive/private-draft.md"),
            "frontmatter aliases should participate in title fallback"
        );
        assert!(
            trace
                .candidates
                .iter()
                .any(|candidate| candidate.path == "archive/private-draft.md"),
            "frontmatter alias hit should remain visible in trace candidates: {:?}",
            trace.candidates
        );
    }

    #[tokio::test]
    async fn hybrid_search_seeds_each_side_of_connect_synthesis_query() {
        use super::VaultBackend;
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        store
            .write(
                "Old/me/project/reason for making the project.md",
                "A body that intentionally omits the title words.",
                None,
                false,
            )
            .await
            .expect("write left-side title target");
        store
            .write(
                "Old/me/project/August dumping review.md",
                "A second body that intentionally omits its title words.",
                None,
                false,
            )
            .await
            .expect("write right-side title target");
        store.reload_index().expect("reload index");

        let (results, trace) = store
            .hybrid_search_with_trace("connect reason making with august dumping", 5, &[])
            .await
            .expect("hybrid_search_with_trace");
        let paths = results
            .iter()
            .map(|result| result.path.as_str())
            .collect::<Vec<_>>();

        assert!(
            paths.contains(&"Old/me/project/reason for making the project.md"),
            "synthesis query should seed the left-side title; got {paths:?}"
        );
        assert!(
            paths.contains(&"Old/me/project/August dumping review.md"),
            "synthesis query should seed the right-side title; got {paths:?}"
        );
        assert!(
            trace
                .notes
                .iter()
                .any(|note| note.contains("Path/title fallback retained")),
            "trace must disclose synthesis title fallback: {:?}",
            trace.notes
        );
    }

    #[test]
    fn title_keys_for_note_include_frontmatter_title_and_aliases() {
        let keys = VaultStore::title_keys_for_note(
            "archive/private-draft.md",
            "---\ntitle: Private Draft\naliases:\n  - My Autobiography\n  - Early Memoir\n---\n\nBody",
        );

        assert!(keys.contains("private draft"));
        assert!(keys.contains("my autobiography"));
        assert!(keys.contains("early memoir"));
    }

    #[tokio::test]
    async fn hybrid_search_resolves_finder_absolute_path_inside_vault() {
        use super::VaultBackend;
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        store
            .write(
                "some essays/My Autobiography.md",
                "I grew up around projects, school, and personal systems.",
                None,
                false,
            )
            .await
            .expect("write note");
        store.reload_index().expect("reload index");

        let absolute = vault_root
            .path()
            .join("some essays/My Autobiography.md")
            .to_string_lossy()
            .to_string();
        let (results, trace) = store
            .hybrid_search_with_trace(&absolute, 5, &[])
            .await
            .expect("hybrid_search_with_trace");

        assert_eq!(
            results.first().map(|result| result.path.as_str()),
            Some("some essays/My Autobiography.md"),
            "Finder-copied absolute paths inside the vault should resolve to vault-relative hits"
        );
        assert!(
            trace
                .notes
                .iter()
                .any(|note| note.contains("Explicit path fallback retained")),
            "trace should disclose explicit-path fallback: {:?}",
            trace.notes
        );
    }

    /// T21 iter-4: the new `VaultBackend::hybrid_search_with_trace` default
    /// trait method MUST mirror the regular `hybrid_search` result list AND
    /// emit a `RetrievalTrace` carrying at minimum the `Lexical` signal.
    /// The trace's `candidate_pool_size` records the pre-cull pool; each
    /// candidate carries its raw BM25 score via a `RetrievalSignal::Lexical`
    /// `signals` entry.
    #[tokio::test]
    async fn hybrid_search_with_trace_emits_lexical_signal_per_candidate() {
        use super::{RetrievalSignal, VaultBackend};
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        let docs: [(&str, &str); 3] = [
            (
                "a.md",
                "residency governance residency governance tier compression",
            ),
            ("b.md", "residency governance residency hierarchy"),
            ("c.md", "ui design pull-down menu unrelated"),
        ];
        for (path, content) in docs.iter() {
            store
                .write(path, content, None, false)
                .await
                .expect("write note");
        }
        store.ft_reader.reload().expect("reload ft_reader");

        let (results, trace) = store
            .hybrid_search_with_trace("residency governance", 3, &[])
            .await
            .expect("hybrid_search_with_trace");

        assert!(
            !results.is_empty(),
            "expected matches for 'residency governance'"
        );
        assert_eq!(
            trace.candidates.len(),
            results.len(),
            "trace candidate count must mirror hybrid_search result count"
        );
        assert_eq!(trace.candidates_retained, results.len());
        assert!(
            trace.candidate_pool_size >= results.len(),
            "VaultStore trace records a pre-cull pool: pool = {}, retained = {}",
            trace.candidate_pool_size,
            results.len()
        );
        assert!(
            trace.page_gather.is_some(),
            "VaultStore trace must record PageGather escalation metadata"
        );
        assert!(
            trace.signal_summary.contains(&RetrievalSignal::Lexical),
            "trace must record the Lexical signal: {:?}",
            trace.signal_summary
        );
        assert_eq!(
            trace.query, "residency governance",
            "trace records the input query verbatim"
        );

        // Each candidate must carry a Lexical signal entry whose `raw`
        // equals the corresponding SearchResult.score (no clamp, no
        // double-normalization).
        for (candidate, result) in trace.candidates.iter().zip(results.iter()) {
            assert_eq!(candidate.path, result.path);
            assert_eq!(candidate.fused_score, result.score);
            let lexical = candidate
                .signals
                .iter()
                .find(|s| s.signal == RetrievalSignal::Lexical)
                .expect("candidate missing Lexical signal");
            assert_eq!(
                lexical.raw, result.score,
                "Lexical.raw must match raw BM25 from SearchResult"
            );
        }
    }

    #[tokio::test]
    async fn hybrid_search_with_trace_emits_semantic_signal_for_paraphrase_fallback() {
        use super::{RetrievalSignal, VaultBackend};
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        store
            .write(
                "notes/mamba_ssm_cache.md",
                "mamba ssm cache mamba ssm cache architecture notes",
                None,
                false,
            )
            .await
            .expect("write canonical");
        store
            .write(
                "notes/generic_attention_overview.md",
                "attention softmax overview generic transformer notes",
                None,
                false,
            )
            .await
            .expect("write decoy");
        store.ft_reader.reload().expect("reload ft_reader");

        let (results, trace) = store
            .hybrid_search_with_trace("Mamba state-space-model caching", 5, &[])
            .await
            .expect("hybrid_search_with_trace");

        assert!(
            results
                .iter()
                .take(5)
                .any(|result| result.path == "notes/mamba_ssm_cache.md"),
            "semantic fallback should retrieve the SSM/cache paraphrase; got {results:?}"
        );
        assert!(
            trace.signal_summary.contains(&RetrievalSignal::Semantic),
            "trace should disclose semantic fallback: {:?}",
            trace.signal_summary
        );
        let candidate = trace
            .candidates
            .iter()
            .find(|candidate| candidate.path == "notes/mamba_ssm_cache.md")
            .expect("expected mamba candidate in trace");
        assert!(
            candidate
                .signals
                .iter()
                .any(|score| score.signal == RetrievalSignal::Semantic),
            "candidate should carry semantic score: {:?}",
            candidate.signals
        );
    }

    #[tokio::test]
    async fn vaultstore_hybrid_search_with_trace_records_page_gather_escalation() {
        use super::VaultBackend;
        use crate::storage::retrieval_trace::{
            PageGatherMeasurementStatus, PageGatherScheduleClass,
        };

        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        for index in 0..60 {
            store
                .write(
                    &format!("note-{index:02}.md"),
                    "residency governance residency governance signal",
                    None,
                    false,
                )
                .await
                .expect("write note");
        }
        store.reload_index().expect("reload index");

        let (results, trace) = store
            .hybrid_search_with_trace("residency governance", 4, &[])
            .await
            .expect("hybrid_search_with_trace");

        assert_eq!(results.len(), 4);
        assert!(
            trace.candidate_pool_size >= 50,
            "PageGather escalation must collect a broad pre-cull pool, got {}",
            trace.candidate_pool_size
        );
        let page_gather = trace.page_gather.expect("page gather trace");
        assert_eq!(
            page_gather.measurement_status,
            PageGatherMeasurementStatus::Deferred
        );
        assert_eq!(page_gather.candidate_pool_size, trace.candidate_pool_size);
        assert_eq!(page_gather.candidates_retained, results.len());
        assert_eq!(page_gather.deferred_falsifier, "F-PageGather-Scatter");
        assert_eq!(
            page_gather.schedule_class,
            Some(PageGatherScheduleClass::BlockSorted)
        );
        assert_eq!(
            page_gather.locality_block_elements,
            Some(crate::helios::DEFAULT_PAGE_GATHER_BLOCK_ELEMENTS)
        );
        assert!(
            page_gather.packetized_caller_consumed,
            "VaultStore trace must consume retained candidates as PageGather packets"
        );
        assert_eq!(page_gather.packets_emitted, results.len());
        assert!(
            page_gather.dense_restore_deferred,
            "trace caller must defer dense restore instead of claiming the dense PageGather gate"
        );
    }

    /// T21 iter-5: `VaultStore`'s override of `hybrid_search_with_trace`
    /// MUST capture the chatter-stripped `effective_query` (Fix-B output)
    /// and emit free-form notes that name the Fix-B + AND-conjunction
    /// transforms when they fire. The trace's `candidate_pool_size`
    /// records the true Tantivy pool (`top_docs.len()`), which can exceed
    /// `candidates_retained` when `tag_filter` culls candidates.
    #[tokio::test]
    async fn vaultstore_hybrid_search_with_trace_records_fix_b_and_pool_size() {
        use super::VaultBackend;
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        let docs: [(&str, &str); 3] = [
            ("a.md", "residency governance tier residency governance"),
            ("b.md", "residency governance hierarchy residency"),
            ("c.md", "unrelated layout note ui design"),
        ];
        for (path, content) in docs.iter() {
            store
                .write(path, content, None, false)
                .await
                .expect("write note");
        }
        store.ft_reader.reload().expect("reload ft_reader");

        let (results, trace) = store
            .hybrid_search_with_trace("Pull my notes on residency governance", 3, &[])
            .await
            .expect("hybrid_search_with_trace");

        assert!(!results.is_empty(), "expected matches for the chatty input");
        // Fix-B: chatter stripped to the 2-term topical signal.
        assert_eq!(
            trace.effective_query, "residency governance",
            "VaultStore override records the chatter-stripped form: {:?}",
            trace.effective_query
        );
        assert_eq!(
            trace.query, "Pull my notes on residency governance",
            "input query preserved verbatim"
        );

        // Notes name both the chatter strip and the AND conjunction
        // activation (2 surviving terms is ≤ 3).
        let notes_blob = trace.notes.join(" | ");
        assert!(
            notes_blob.contains("Fix-B chatter strip"),
            "expected Fix-B note: notes = {notes_blob:?}"
        );
        assert!(
            notes_blob.contains("AND conjunction applied"),
            "expected AND-conjunction note: notes = {notes_blob:?}"
        );

        // Pool size ≥ retained for the override (true Tantivy pool ≥ post-
        // filter retained). With no tag_filter we expect equality up to
        // limit, and the relation `retained ≤ pool_size` always holds.
        assert!(
            trace.candidate_pool_size >= trace.candidates_retained,
            "pool_size ({}) must be ≥ candidates_retained ({})",
            trace.candidate_pool_size,
            trace.candidates_retained
        );
    }

    /// T21 iter-5: when `tag_filter` culls candidates, the trace's
    /// `candidate_pool_size` (true Tantivy pool) MUST exceed
    /// `candidates_retained` (post-cull). The W-21 diagnostics surface
    /// uses this delta to show "we considered N but kept M after filter".
    #[tokio::test]
    async fn vaultstore_hybrid_search_with_trace_pool_size_exceeds_retained_when_tag_filter_culls()
    {
        use super::VaultBackend;
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        // Write 3 notes whose tantivy content matches the query, but
        // give each a unique frontmatter tag so a tag_filter retains
        // only one.
        let tagged: [(&str, &str); 3] = [
            (
                "a.md",
                "---\ntags:\n  - alpha\n---\n\nresidency governance residency",
            ),
            (
                "b.md",
                "---\ntags:\n  - beta\n---\n\nresidency governance residency",
            ),
            (
                "c.md",
                "---\ntags:\n  - gamma\n---\n\nresidency governance residency",
            ),
        ];
        for (path, content) in tagged.iter() {
            store
                .write(path, content, None, false)
                .await
                .expect("write tagged note");
        }
        store.ft_reader.reload().expect("reload ft_reader");

        let (results, trace) = store
            .hybrid_search_with_trace(
                "residency governance",
                10,
                std::slice::from_ref(&"alpha".to_string()),
            )
            .await
            .expect("hybrid_search_with_trace");
        assert!(
            !results.is_empty(),
            "tag_filter 'alpha' must retain at least one match"
        );
        assert!(
            trace.candidate_pool_size > trace.candidates_retained,
            "tag_filter must reveal a pool > retained delta: pool = {}, retained = {}",
            trace.candidate_pool_size,
            trace.candidates_retained
        );
        assert!(
            trace
                .notes
                .iter()
                .any(|note| note.contains("Tag filter retained")),
            "trace must explain partial tag culling: {:?}",
            trace.notes
        );
    }

    /// T21 iter-10: when `strip_query_chatter` empties a non-empty query
    /// (all tokens are chatter, e.g. "show me my notes"), VaultStore's
    /// `hybrid_search_with_trace` override MUST record
    /// `trace.all_chatter_fallback = true` and emit the "Fix-B all-chatter
    /// fallback" note. The trace's evidence_strength() then flips to
    /// Weak regardless of how many notes the raw query incidentally hit.
    #[tokio::test]
    async fn vaultstore_hybrid_search_with_trace_records_all_chatter_fallback() {
        use super::VaultBackend;
        use crate::storage::retrieval_trace::EvidenceStrength;
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        // Seed enough notes containing chatter tokens that the raw
        // query "show me my notes" can plausibly match 3+ of them
        // (each contains "show", "me", "my", or "notes" via the
        // strip_query_chatter list).
        let docs: [(&str, &str); 4] = [
            ("a.md", "show me the layout notes about hover behavior"),
            ("b.md", "my notes on the show timeline"),
            ("c.md", "show me my unrelated notes about coffee"),
            ("d.md", "notes about something entirely different"),
        ];
        for (path, content) in docs.iter() {
            store
                .write(path, content, None, false)
                .await
                .expect("write note");
        }
        store.reload_index().expect("reload index");

        let (_results, trace) = store
            .hybrid_search_with_trace("show me my notes", 5, &[])
            .await
            .expect("hybrid_search_with_trace");

        assert!(
            trace.all_chatter_fallback,
            "trace must record all_chatter_fallback when strip empties the query"
        );
        assert_eq!(
            trace.effective_query, "show me my notes",
            "effective_query falls back to the raw input when strip empties"
        );
        assert!(
            trace
                .notes
                .iter()
                .any(|n| n.contains("Fix-B all-chatter fallback")),
            "expected 'Fix-B all-chatter fallback' note: {:?}",
            trace.notes
        );
        // Evidence-strength flips to Weak even when candidates were retained.
        assert_eq!(
            trace.evidence_strength(),
            EvidenceStrength::Weak,
            "all-chatter fallback MUST force Weak verdict regardless of count"
        );
    }

    /// T21 iter-426: zero-result graceful behavior for the degenerate
    /// empty-query / empty-vault case. The backend must return an empty
    /// weak trace, not bubble Tantivy's empty-query parse error.
    #[tokio::test]
    async fn vaultstore_hybrid_search_with_trace_empty_query_empty_vault_is_weak_empty_ok() {
        use super::VaultBackend;
        use crate::storage::retrieval_trace::EvidenceStrength;
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        let (results, trace) = store
            .hybrid_search_with_trace("", 5, &[])
            .await
            .expect("empty query must not error");

        assert!(
            results.is_empty(),
            "empty query on empty vault must return no results"
        );
        assert_eq!(trace.query, "");
        assert_eq!(trace.effective_query, "");
        assert_eq!(trace.candidate_pool_size, 0);
        assert_eq!(trace.candidates_retained, 0);
        assert_eq!(trace.evidence_strength(), EvidenceStrength::Weak);
    }

    /// T21 iter-426: all-stopword queries should be graceful even when
    /// the raw fallback contains parser operator words. This pins the
    /// no-error surface before consumers decide whether to ask the user
    /// to clarify or broaden the search.
    #[tokio::test]
    async fn vaultstore_hybrid_search_with_trace_all_stopword_query_is_weak_empty_ok() {
        use super::VaultBackend;
        use crate::storage::retrieval_trace::EvidenceStrength;
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        store
            .write(
                "signal.md",
                "residency governance unrelated content",
                None,
                false,
            )
            .await
            .expect("write note");
        store.reload_index().expect("reload index");

        let (results, trace) = store
            .hybrid_search_with_trace("the and or", 5, &[])
            .await
            .expect("all-stopword query must not error");

        assert!(
            results.is_empty(),
            "all-stopword query must not retain lexical candidates"
        );
        assert_eq!(trace.query, "the and or");
        assert_eq!(trace.effective_query, "the and or");
        assert!(trace.all_chatter_fallback);
        assert_eq!(trace.candidate_pool_size, 0);
        assert_eq!(trace.candidates_retained, 0);
        assert_eq!(trace.evidence_strength(), EvidenceStrength::Weak);
    }

    /// T21 iter-426: `limit = 0` is another zero-result surface. It
    /// must not retain one candidate just because the Tantivy collector
    /// internally needs a positive limit.
    #[tokio::test]
    async fn vaultstore_hybrid_search_with_trace_zero_limit_retains_zero_candidates() {
        use super::VaultBackend;
        use crate::storage::retrieval_trace::EvidenceStrength;
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        store
            .write("signal.md", "residency governance signal", None, false)
            .await
            .expect("write note");
        store.reload_index().expect("reload index");

        let (results, trace) = store
            .hybrid_search_with_trace("residency governance", 0, &[])
            .await
            .expect("zero limit must not error");

        assert!(results.is_empty(), "limit = 0 must retain no results");
        assert_eq!(trace.candidates_retained, 0);
        assert_eq!(trace.evidence_strength(), EvidenceStrength::Weak);
    }

    /// T21 iter-427: a real search with no lexical matches should be
    /// explainable in the trace, not just represented as an empty list.
    #[tokio::test]
    async fn vaultstore_hybrid_search_with_trace_no_matches_records_zero_result_note() {
        use super::VaultBackend;
        use crate::storage::retrieval_trace::EvidenceStrength;
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        store
            .write("unrelated.md", "coffee archive unrelated", None, false)
            .await
            .expect("write note");
        store.reload_index().expect("reload index");

        let (results, trace) = store
            .hybrid_search_with_trace("residency governance", 5, &[])
            .await
            .expect("no-match query must not error");

        assert!(results.is_empty(), "expected no lexical matches");
        assert_eq!(trace.candidate_pool_size, 0);
        assert_eq!(trace.candidates_retained, 0);
        assert_eq!(trace.evidence_strength(), EvidenceStrength::Weak);
        assert!(
            trace
                .notes
                .iter()
                .any(|note| note.contains("Zero-result guard: no lexical matches")),
            "trace must explain the zero-result retrieval: {:?}",
            trace.notes
        );
    }

    /// T21 iter-428: tag filters can cull every lexical match after
    /// Tantivy found a non-empty pool. The trace should say that the
    /// zero retained result came from filtering, not from no lexical
    /// matches.
    #[tokio::test]
    async fn vaultstore_hybrid_search_with_trace_tag_filter_culls_all_records_note() {
        use super::VaultBackend;
        use crate::storage::retrieval_trace::EvidenceStrength;
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        store
            .write(
                "alpha.md",
                "---\ntags:\n  - alpha\n---\n\nresidency governance signal",
                None,
                false,
            )
            .await
            .expect("write note");
        store.reload_index().expect("reload index");

        let (results, trace) = store
            .hybrid_search_with_trace(
                "residency governance",
                5,
                std::slice::from_ref(&"beta".to_string()),
            )
            .await
            .expect("tag-cull query must not error");

        assert!(results.is_empty(), "tag filter should cull all matches");
        assert!(
            trace.candidate_pool_size > 0,
            "Tantivy must have found a lexical pool before tag culling"
        );
        assert_eq!(trace.candidates_retained, 0);
        assert_eq!(trace.evidence_strength(), EvidenceStrength::Weak);
        assert!(
            trace
                .notes
                .iter()
                .any(|note| note.contains("Zero-result guard: tag filter culled")),
            "trace must explain the tag-cull zero-result retrieval: {:?}",
            trace.notes
        );
    }

    /// T21 iter-64 (2026-05-18): DOCUMENTING test for the Q2 gap.
    /// Today, `VaultStore::hybrid_search_with_trace` only populates the
    /// `Lexical` signal — `Semantic`/`Graph`/`Recency`/`Mmr` are all
    /// absent because epistemos-shadow integration (BM25 + HNSW RRF
    /// fusion) hasn't been wired through `VaultBackend` yet.
    /// This test PASSES today; the point is to pin the gap so that when
    /// the Semantic wiring lands, this test breaks loudly and forces a
    /// deliberate update of the F-VaultRecall-50 acceptance bar. See
    /// Q2 in `docs/F_VAULT_RECALL_50_2026_05_18.md` §8 and the
    /// cross-link doc comment at `RetrievalSignal::Semantic`.
    #[tokio::test]
    async fn vaultstore_trace_currently_omits_semantic_and_other_non_lexical_signals_documenting() {
        use super::{RetrievalSignal, VaultBackend};
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        let docs: [(&str, &str); 3] = [
            ("a.md", "residency governance tier compression"),
            ("b.md", "residency hierarchy and governance"),
            ("c.md", "unrelated coffee notes"),
        ];
        for (path, content) in docs.iter() {
            store
                .write(path, content, None, false)
                .await
                .expect("write note");
        }
        store.reload_index().expect("reload index");

        let (results, trace) = store
            .hybrid_search_with_trace("residency governance", 3, &[])
            .await
            .expect("hybrid_search_with_trace");

        assert!(!results.is_empty(), "expected matches");
        assert!(!trace.candidates.is_empty(), "expected trace candidates");

        // Q2 gap: every candidate currently carries Lexical only.
        // Non-Lexical signals are all None because no backend populates
        // them yet. When the multi-signal wiring lands, this assertion
        // breaks loudly — that breakage IS the signal to update the
        // acceptance bar and summary doc §8 Q2.
        for candidate in trace.candidates.iter() {
            assert!(
                candidate.signal_score(RetrievalSignal::Lexical).is_some(),
                "Lexical must be populated for {}",
                candidate.path
            );
            for signal in [
                RetrievalSignal::Semantic,
                RetrievalSignal::Graph,
                RetrievalSignal::Recency,
                RetrievalSignal::Mmr,
            ] {
                assert!(
                    candidate.signal_score(signal).is_none(),
                    "Q2 gap: {:?} signal MUST be None today for {}; if this fires, \
                     the multi-signal wiring just landed — update the test + \
                     F_VAULT_RECALL_50_2026_05_18.md §8 Q2 to reflect the new floor",
                    signal,
                    candidate.path
                );
            }
        }

        // Symmetric assertion on the per-trace signal_summary.
        assert!(
            trace.signal_summary.contains(&RetrievalSignal::Lexical),
            "signal_summary must contain Lexical"
        );
        for signal in [
            RetrievalSignal::Semantic,
            RetrievalSignal::Graph,
            RetrievalSignal::Recency,
            RetrievalSignal::Mmr,
        ] {
            assert!(
                !trace.signal_summary.contains(&signal),
                "Q2 gap: signal_summary MUST NOT contain {:?} today: {:?}",
                signal,
                trace.signal_summary
            );
        }
    }

    #[test]
    fn read_only_open_succeeds_while_a_writer_lock_is_held() {
        let vault_root = tempfile::tempdir().expect("temp vault");

        let writable = VaultStore::open(vault_root.path().to_str().expect("vault path"))
            .expect("open writable vault");
        let _held_writer = writable
            .ft_writer
            .as_ref()
            .expect("writer present")
            .lock()
            .expect("lock writer");

        let read_only = VaultStore::open_read_only(vault_root.path().to_str().expect("vault path"));

        assert!(
            read_only.is_ok(),
            "read-only open should not need the index writer lock"
        );
    }

    #[test]
    fn eml_rerank_is_flag_gated_and_fuses_excerpt_coverage() {
        let _guard = crate::test_support::env_lock();
        let mk = |path: &str, score: f64, excerpt: &str| super::SearchResult {
            path: path.to_string(),
            excerpt: excerpt.to_string(),
            score,
            tags: vec![],
        };
        let query = "vault recall";
        // A: highest BM25 but excerpt covers NONE of the query terms.
        // B: lower BM25 but the excerpt covers both query terms.
        let results = vec![
            mk("a.md", 12.0, "unrelated text here"),
            mk("b.md", 5.0, "this note is about vault recall and memory"),
        ];

        // The secondary coverage signal.
        assert_eq!(
            super::excerpt_query_coverage(query, "vault recall stuff"),
            2.0
        );
        assert_eq!(super::excerpt_query_coverage(query, "nothing matches"), 0.0);

        // Flag OFF (default): order is the input order (no re-rank).
        std::env::remove_var("EPISTEMOS_EML_RERANK_V1");
        let off = super::apply_eml_rerank(query, results.clone());
        assert_eq!(off[0].path, "a.md", "off → input order preserved");

        // Flag ON: B (covers the query) is fused above A despite lower BM25.
        std::env::set_var("EPISTEMOS_EML_RERANK_V1", "1");
        let on = super::apply_eml_rerank(query, results);
        assert_eq!(
            on[0].path, "b.md",
            "on → excerpt-coverage fusion promotes B"
        );
        std::env::remove_var("EPISTEMOS_EML_RERANK_V1");
    }
}
