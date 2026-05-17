use std::collections::HashSet;
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
#[rustfmt::skip]
const QUERY_CHATTER_WORDS: &[&str] = &[
    // Imperative chat prefixes
    "pull", "find", "show", "get", "give", "tell", "list", "search", "look",
    // First/second person
    "me", "my", "i", "you", "your", "us", "our",
    // Discourse particles
    "please", "can", "could", "would", "should",
    // Common stop-words that appear in chatty prefixes
    "the", "a", "an", "of", "in", "on", "to", "for", "with", "about", "and", "or", "but", "is",
    "are", "was", "were",
    // Generic referents
    "notes", "note", "files", "file", "stuff", "things", "thing",
    // Wh-question words (kept narrow — these can be legitimate signal)
    "what", "where", "when", "how", "why", "which",
    // Misc filler
    "any", "some", "all", "want", "need",
    // Synthesis operators; useful for intent, not lexical match
    "connect",
    // Title lookup scaffolding
    "called", "original", "title", "titled",
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

fn query_requests_original(query: &str) -> bool {
    query
        .split_whitespace()
        .any(|token| token.eq_ignore_ascii_case("original"))
}

fn normalized_title_tokens(input: &str) -> Vec<String> {
    let stripped = strip_query_chatter(input);
    let source = if stripped.trim().is_empty() {
        input
    } else {
        stripped.as_str()
    };

    source
        .split(|ch: char| !ch.is_alphanumeric())
        .filter_map(|token| {
            let token = token.trim().to_lowercase();
            if token.is_empty() || token == "md" {
                None
            } else {
                Some(token)
            }
        })
        .collect()
}

fn path_title_tokens(path: &str) -> Vec<String> {
    let stem = Path::new(path)
        .file_stem()
        .and_then(|stem| stem.to_str())
        .unwrap_or(path);
    normalized_title_tokens(stem)
}

fn contains_subsequence(haystack: &[String], needle: &[String]) -> bool {
    if needle.is_empty() || needle.len() > haystack.len() {
        return false;
    }

    haystack
        .windows(needle.len())
        .any(|window| window.iter().zip(needle).all(|(left, right)| left == right))
}

fn title_match_score(target: &[String], candidate: &[String]) -> Option<f64> {
    if target.is_empty() || candidate.is_empty() {
        return None;
    }
    if target == candidate {
        return Some(1.0);
    }
    if contains_subsequence(candidate, target) {
        return Some(0.92);
    }

    let target_set: HashSet<&str> = target.iter().map(String::as_str).collect();
    let candidate_set: HashSet<&str> = candidate.iter().map(String::as_str).collect();
    let overlap = target_set.intersection(&candidate_set).count();
    if overlap == target_set.len() {
        Some(0.84)
    } else if target_set.len() >= 3 && overlap + 1 >= target_set.len() {
        Some(0.72)
    } else {
        None
    }
}

fn synthesis_title_queries(query: &str) -> Vec<String> {
    let tokens: Vec<String> = query
        .split(|ch: char| !ch.is_alphanumeric())
        .filter_map(|token| {
            let token = token.trim().to_lowercase();
            if token.is_empty() {
                None
            } else {
                Some(token)
            }
        })
        .collect();

    let Some(connect_index) = tokens.iter().position(|token| token == "connect") else {
        return Vec::new();
    };
    let Some(with_offset) = tokens[connect_index + 1..]
        .iter()
        .position(|token| token == "with")
    else {
        return Vec::new();
    };
    let with_index = connect_index + 1 + with_offset;
    let left = tokens[connect_index + 1..with_index].join(" ");
    let right = tokens[with_index + 1..].join(" ");

    [left, right]
        .into_iter()
        .filter(|part| normalized_title_tokens(part).len() >= 2)
        .collect()
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

    async fn search(&self, query: &str, limit: usize) -> Result<Vec<String>, VaultError> {
        let results = self.hybrid_search(query, limit, &[]).await?;
        Ok(results
            .into_iter()
            .map(|result| {
                format!(
                    "## {} (score: {:.0}%)\n{}",
                    result.path,
                    result.score * 100.0,
                    result.excerpt
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

        if body.chars().count() <= max_chars {
            body.to_string()
        } else {
            let byte_limit = body
                .char_indices()
                .nth(max_chars)
                .map(|(idx, _)| idx)
                .unwrap_or(body.len());
            let boundary = body[..byte_limit]
                .rfind(char::is_whitespace)
                .unwrap_or(byte_limit);
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

    fn title_lookup_candidates(
        &self,
        query: &str,
        tag_filter: &[String],
    ) -> Result<Vec<SearchResult>, VaultError> {
        let target_tokens = normalized_title_tokens(query);
        if target_tokens.is_empty() {
            return Ok(Vec::new());
        }

        let original_requested = query_requests_original(query);
        let conn = self
            .db
            .lock()
            .map_err(|_| VaultError::DatabaseError("lock poisoned".to_string()))?;
        let mut stmt = conn
            .prepare("SELECT path, tags_json FROM notes")
            .map_err(|error| VaultError::DatabaseError(error.to_string()))?;
        let rows = stmt
            .query_map([], |row| {
                Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
            })
            .map_err(|error| VaultError::DatabaseError(error.to_string()))?;

        let mut candidates = Vec::new();
        for row in rows {
            let (path, tags_json) =
                row.map_err(|error| VaultError::DatabaseError(error.to_string()))?;
            let tags: Vec<String> = serde_json::from_str(&tags_json).unwrap_or_default();
            if !tag_filter.is_empty() && !tag_filter.iter().all(|tag| tags.contains(tag)) {
                continue;
            }
            if original_requested && Self::is_distractor_candidate(&path, &tags) {
                continue;
            }

            let title_tokens = path_title_tokens(&path);
            let Some(score) = title_match_score(&target_tokens, &title_tokens) else {
                continue;
            };
            let content = std::fs::read_to_string(self.vault_root.join(&path)).unwrap_or_default();
            let result_tags = if content.is_empty() {
                tags
            } else {
                Self::extract_tags(&content)
            };
            candidates.push(SearchResult {
                path,
                excerpt: Self::excerpt(&content, 500),
                score,
                tags: result_tags,
            });
        }

        candidates.sort_by(|left, right| {
            right
                .score
                .partial_cmp(&left.score)
                .unwrap_or(std::cmp::Ordering::Equal)
                .then_with(|| left.path.len().cmp(&right.path.len()))
                .then_with(|| left.path.cmp(&right.path))
        });
        Ok(candidates)
    }

    fn is_distractor_candidate(path: &str, tags: &[String]) -> bool {
        let path_lower = path.to_lowercase();
        path_lower.contains("distractor")
            || path_lower.contains("zz_adversarial")
            || tags
                .iter()
                .any(|tag| tag.to_lowercase().contains("distractor"))
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
    async fn hybrid_search(
        &self,
        query: &str,
        limit: usize,
        tag_filter: &[String],
    ) -> Result<Vec<SearchResult>, VaultError> {
        if limit == 0 {
            return Ok(Vec::new());
        }

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
        let effective_query = if stripped.is_empty() {
            query
        } else {
            stripped.as_str()
        };
        let surviving_terms = effective_query.split_whitespace().count();
        if surviving_terms > 0 && surviving_terms <= 3 {
            query_parser.set_conjunction_by_default();
        }

        let original_requested = query_requests_original(query);
        let mut results = Vec::new();
        let mut seen_paths = HashSet::new();
        for result in self.title_lookup_candidates(query, tag_filter)? {
            if seen_paths.insert(result.path.clone()) {
                results.push(result);
            }
            if results.len() >= limit {
                return Ok(results);
            }
        }
        for title_query in synthesis_title_queries(query) {
            for result in self.title_lookup_candidates(&title_query, tag_filter)? {
                if seen_paths.insert(result.path.clone()) {
                    results.push(result);
                }
                if results.len() >= limit {
                    return Ok(results);
                }
            }
        }

        let parsed_query = query_parser
            .parse_query(effective_query)
            .map_err(|error| VaultError::IndexError(error.to_string()))?;
        let top_docs = searcher
            .search(
                &parsed_query,
                &TopDocs::with_limit(limit.saturating_mul(8).clamp(50, 200)),
            )
            .map_err(|error| VaultError::IndexError(error.to_string()))?;

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
            if original_requested && Self::is_distractor_candidate(&path, &tags) {
                continue;
            }
            if !seen_paths.insert(path.clone()) {
                continue;
            }

            results.push(SearchResult {
                path,
                excerpt: Self::excerpt(content, 500),
                score: (score as f64).clamp(0.0, 1.0),
                tags,
            });

            if results.len() >= limit {
                break;
            }
        }

        Ok(results)
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
    use super::{strip_query_chatter, VaultBackend, VaultStore};

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
    fn strip_query_chatter_drops_synthesis_operator() {
        let input = "connect reason making with august dumping";
        let cleaned = strip_query_chatter(input);
        assert_eq!(cleaned, "reason making august dumping");
    }

    #[tokio::test]
    async fn hybrid_search_prefers_exact_path_title_when_body_lacks_title() {
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");

        store
            .write(
                "Old/me/personal/The Recentering of Virtue.md",
                "A body that intentionally omits the filename words.",
                None,
                false,
            )
            .await
            .expect("write target");
        store
            .write(
                "Old/me/personal/noisy.md",
                "Recentering virtue virtue virtue unrelated body noise.",
                None,
                false,
            )
            .await
            .expect("write noisy note");

        let results = store
            .hybrid_search("The Recentering of Virtue", 5, &[])
            .await
            .expect("hybrid search");

        assert_eq!(
            results.first().map(|result| result.path.as_str()),
            Some("Old/me/personal/The Recentering of Virtue.md")
        );
    }

    #[tokio::test]
    async fn hybrid_search_original_title_rejects_adversarial_distractor() {
        let vault_root = tempfile::tempdir().expect("temp vault");
        let store =
            VaultStore::open(vault_root.path().to_str().expect("vault path")).expect("open vault");
        let distractor_tags = vec!["f-vaultrecall-distractor".to_string()];

        store
            .write(
                "sessions/2026-04-21_1984A7DB/GRAPH_REPORT.md",
                "Original graph report material.",
                None,
                false,
            )
            .await
            .expect("write target");
        store
            .write(
                "zz_adversarial/GRAPH-REPORT - distractor.md",
                "# GRAPH_REPORT - distractor\n\nThis shares the title surface but is not the original note.",
                Some(&distractor_tags),
                false,
            )
            .await
            .expect("write distractor");

        let results = store
            .hybrid_search("original note titled GRAPH_REPORT", 5, &[])
            .await
            .expect("hybrid search");
        let top_paths = results
            .iter()
            .take(5)
            .map(|result| result.path.as_str())
            .collect::<Vec<_>>();

        assert_eq!(
            top_paths.first().copied(),
            Some("sessions/2026-04-21_1984A7DB/GRAPH_REPORT.md")
        );
        assert!(
            !top_paths.contains(&"zz_adversarial/GRAPH-REPORT - distractor.md"),
            "original-note search must suppress the injected distractor; got {top_paths:?}"
        );
    }

    #[tokio::test]
    async fn hybrid_search_seeds_each_side_of_synthesis_query() {
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
            .expect("write title-side target");
        store
            .write(
                "Old/me/project/August dumping review.md",
                "A second body that intentionally omits its title words.",
                None,
                false,
            )
            .await
            .expect("write right-side target");

        let results = store
            .hybrid_search("connect reason making with august dumping", 5, &[])
            .await
            .expect("hybrid search");
        let top_paths = results
            .iter()
            .take(5)
            .map(|result| result.path.as_str())
            .collect::<Vec<_>>();

        assert!(
            top_paths.contains(&"Old/me/project/reason for making the project.md"),
            "synthesis query should seed the left-side title; got {top_paths:?}"
        );
        assert!(
            top_paths.contains(&"Old/me/project/August dumping review.md"),
            "synthesis query should seed the right-side title; got {top_paths:?}"
        );
    }

    #[test]
    fn excerpt_truncates_on_char_boundary() {
        let input = format!("{}” trailing text", "a".repeat(499));
        let excerpt = VaultStore::excerpt(&input, 500);

        assert!(
            excerpt.ends_with('…'),
            "long unicode excerpt should be truncated with an ellipsis"
        );
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
