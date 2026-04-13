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
    ft_writer: Mutex<IndexWriter>,
    field_path: Field,
    field_content: Field,
    field_tags: Field,
}

impl VaultStore {
    pub fn open(vault_root: &str) -> Result<Self, VaultError> {
        let vault_root = PathBuf::from(vault_root);
        let meta_dir = vault_root.join(".epistemos");
        std::fs::create_dir_all(&meta_dir)?;

        let db_path = meta_dir.join("vault.db");
        let db = Connection::open(&db_path)
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
        let ft_writer = ft_index
            .writer(50_000_000)
            .map_err(|error| VaultError::IndexError(error.to_string()))?;

        Ok(Self {
            vault_root,
            db: Mutex::new(db),
            ft_index,
            ft_reader,
            ft_writer: Mutex::new(ft_writer),
            field_path,
            field_content,
            field_tags,
        })
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
        let body = if content.starts_with("---") {
            content[3..]
                .find("---")
                .map(|index| content[index + 6..].trim_start())
                .unwrap_or(content)
        } else {
            content
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
            .ft_writer
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
        let searcher = self.ft_reader.searcher();
        let query_parser =
            QueryParser::for_index(&self.ft_index, vec![self.field_content, self.field_tags]);
        let parsed_query = query_parser
            .parse_query(query)
            .map_err(|error| VaultError::IndexError(error.to_string()))?;
        let top_docs = searcher
            .search(
                &parsed_query,
                &TopDocs::with_limit(limit.saturating_mul(2).max(1)),
            )
            .map_err(|error| VaultError::IndexError(error.to_string()))?;

        let mut results = Vec::new();
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
            .ft_writer
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
