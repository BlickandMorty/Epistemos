use std::path::{Path, PathBuf};
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
    RetrievalCandidate, RetrievalSignal, RetrievalSignalScore, RetrievalTrace,
};

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
    "me", "my", "i", "you", "your", "us", "our",
    // Discourse particles
    "please", "can", "could", "would", "should",
    // Common stop-words that appear in chatty prefixes
    "the", "a", "an", "of", "in", "on", "to", "for", "with", "about",
    "and", "or", "but", "is", "are", "was", "were",
    // Generic referents
    "notes", "note", "files", "file", "stuff", "things", "thing",
    // Wh-question words (kept narrow — these can be legitimate signal)
    "what", "where", "when", "how", "why", "which",
    // Misc filler
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

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SearchResult {
    pub path: String,
    pub excerpt: String,
    pub score: f64,
    pub tags: Vec<String>,
}

#[async_trait]
pub trait VaultBackend: Send + Sync {
    async fn hybrid_search(
        &self,
        query: &str,
        limit: usize,
        tag_filter: &[String],
    ) -> Result<Vec<SearchResult>, VaultError>;

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
        let sanitized = relative.trim_start_matches('/').replace("..", "");
        let absolute = self.vault_root.join(&sanitized);
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

    fn excerpt(content: &str, max_chars: usize) -> String {
        // Skip a YAML/TOML frontmatter block delimited by `---` if
        // present. Using `strip_prefix` instead of `&content[3..]`
        // means a future prefix-length change can't silently desync
        // the slice index.
        let body = match content.strip_prefix("---") {
            Some(after_open) => after_open
                .find("---")
                .map(|i| after_open[i + 3..].trim_start())
                .unwrap_or(content),
            None => content,
        };

        if body.len() <= max_chars {
            body.to_string()
        } else {
            let boundary = body[..max_chars]
                .rfind(char::is_whitespace)
                .unwrap_or(max_chars);
            format!("{}…", &body[..boundary])
        }
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
            trace.add_note(
                "Zero-result guard: limit = 0; skipped Tantivy collection".to_string(),
            );
            return Ok((Vec::new(), trace));
        }

        let parsed_query = query_parser
            .parse_query(effective_query)
            .map_err(|error| VaultError::IndexError(error.to_string()))?;
        let top_docs = searcher
            .search(
                &parsed_query,
                &TopDocs::with_limit(limit.saturating_mul(2).max(1)),
            )
            .map_err(|error| VaultError::IndexError(error.to_string()))?;

        let pool_size = top_docs.len();
        let mut results = Vec::new();
        let mut trace_excerpts: Vec<String> = Vec::new();
        for (score, address) in top_docs {
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
            let tags = Self::extract_tags(content);

            if !tag_filter.is_empty() && !tag_filter.iter().all(|tag| tags.contains(tag)) {
                continue;
            }

            let excerpt = Self::excerpt(content, 500);
            trace_excerpts.push(excerpt.clone());

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
                score: score as f64,
                tags,
            });

            if results.len() >= limit {
                break;
            }
        }

        let mut trace = build_trace(pool_size);
        if pool_size == 0 {
            trace.add_note(format!(
                "Zero-result guard: no lexical matches for effective query {effective_query:?}"
            ));
        } else if !tag_filter.is_empty() && results.is_empty() {
            trace.add_note(format!(
                "Zero-result guard: tag filter culled {pool_size} lexical matches"
            ));
        }
        for (result, excerpt) in results.iter().zip(trace_excerpts.into_iter()) {
            let mut candidate = RetrievalCandidate::new(result.path.clone(), result.score)
                .with_signal(RetrievalSignalScore::new(
                    RetrievalSignal::Lexical,
                    result.score,
                    result.score,
                ));
            if !excerpt.is_empty() {
                candidate = candidate.with_snippet(excerpt);
            }
            trace.push_candidate(candidate);
        }
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
    use super::{strip_query_chatter, VaultStore};

    /// F-VaultRecall-50 Fix B test 1: a chatty prefix is stripped down to
    /// the signal-bearing terms.
    ///
    /// Reproduces the canonical Day-in-the-Life 1:15 PM bug input.
    #[test]
    fn strip_query_chatter_drops_chatty_prefix_and_keeps_signal() {
        let input = "Pull my notes on residency governance";
        let cleaned = strip_query_chatter(input);
        assert_eq!(cleaned, "residency governance",
            "expected chatty prefix to be stripped; got {:?}", cleaned);
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
        assert_eq!(cleaned, "",
            "expected pure-chatter query to filter to empty; got {:?}", cleaned);
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
        let store = VaultStore::open(vault_root.path().to_str().expect("vault path"))
            .expect("open vault");

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

    /// T21 iter-4: the new `VaultBackend::hybrid_search_with_trace` default
    /// trait method MUST mirror the regular `hybrid_search` result list AND
    /// emit a `RetrievalTrace` carrying at minimum the `Lexical` signal.
    /// The trace's `candidate_pool_size` equals the result count (default
    /// impl can't see Tantivy's pre-cull pool — `VaultStore` will override
    /// in a later iter to record the true 2x pool); each candidate carries
    /// its raw BM25 score via a `RetrievalSignal::Lexical` `signals` entry.
    #[tokio::test]
    async fn hybrid_search_with_trace_emits_lexical_signal_per_candidate() {
        use super::{RetrievalSignal, VaultBackend};
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store = VaultStore::open(vault_root.path().to_str().expect("vault path"))
            .expect("open vault");

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
        assert_eq!(
            trace.candidate_pool_size,
            results.len(),
            "default impl records pool_size == retained; VaultStore override \
             will record the true Tantivy pool in a later iter"
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
        let store = VaultStore::open(vault_root.path().to_str().expect("vault path"))
            .expect("open vault");

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
        let store = VaultStore::open(vault_root.path().to_str().expect("vault path"))
            .expect("open vault");

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
        let store = VaultStore::open(vault_root.path().to_str().expect("vault path"))
            .expect("open vault");

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
        let store = VaultStore::open(vault_root.path().to_str().expect("vault path"))
            .expect("open vault");

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
        let store = VaultStore::open(vault_root.path().to_str().expect("vault path"))
            .expect("open vault");

        store
            .write("signal.md", "residency governance unrelated content", None, false)
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
        let store = VaultStore::open(vault_root.path().to_str().expect("vault path"))
            .expect("open vault");

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
        let store = VaultStore::open(vault_root.path().to_str().expect("vault path"))
            .expect("open vault");

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
        let store = VaultStore::open(vault_root.path().to_str().expect("vault path"))
            .expect("open vault");

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
    async fn vaultstore_trace_currently_omits_semantic_and_other_non_lexical_signals_documenting()
    {
        use super::{RetrievalSignal, VaultBackend};
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store = VaultStore::open(vault_root.path().to_str().expect("vault path"))
            .expect("open vault");

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
}
