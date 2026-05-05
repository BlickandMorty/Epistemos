use std::sync::Arc;

use rusqlite::{params, Connection};
use thiserror::Error;

use super::{Action, AlternativePath, EmbeddingProvider, RouteDecision, VARIANT_A_FLOOR};

const INBOX_PREFIX: &str = "_inbox/";
const MIN_NOTE_COUNT_FOR_CENTROID: u32 = 3;
const TOP_K_NEIGHBOURS: usize = 5;
const SCHEMA: &str = r#"
CREATE TABLE IF NOT EXISTS folder_medoids (
    path TEXT PRIMARY KEY NOT NULL,
    note_count INTEGER NOT NULL,
    medoid_json TEXT NOT NULL,
    updated_at INTEGER NOT NULL
);
"#;

#[derive(Debug, Clone, PartialEq)]
pub struct FolderCentroid {
    pub path: String,
    pub note_count: u32,
    pub medoid: Vec<f32>,
}

pub struct FolderMedoidStore {
    conn: std::sync::Mutex<Connection>,
}

impl FolderMedoidStore {
    pub fn open(path: impl AsRef<std::path::Path>) -> Result<Self, FolderMedoidStoreError> {
        if let Some(parent) = path.as_ref().parent() {
            std::fs::create_dir_all(parent)?;
        }
        let conn = Connection::open(path)?;
        init_connection(&conn)?;
        Ok(Self {
            conn: std::sync::Mutex::new(conn),
        })
    }

    pub fn open_in_memory() -> Result<Self, FolderMedoidStoreError> {
        let conn = Connection::open_in_memory()?;
        init_connection(&conn)?;
        Ok(Self {
            conn: std::sync::Mutex::new(conn),
        })
    }

    pub fn upsert(&self, folder: &FolderCentroid) -> Result<(), FolderMedoidStoreError> {
        validate_folder(folder)?;
        let medoid_json = serde_json::to_string(&folder.medoid)?;
        let conn = self
            .conn
            .lock()
            .map_err(|_| FolderMedoidStoreError::LockPoisoned)?;
        conn.execute(
            "INSERT INTO folder_medoids (path, note_count, medoid_json, updated_at)
             VALUES (?1, ?2, ?3, strftime('%s', 'now'))
             ON CONFLICT(path) DO UPDATE SET
                note_count = excluded.note_count,
                medoid_json = excluded.medoid_json,
                updated_at = excluded.updated_at",
            params![folder.path, i64::from(folder.note_count), medoid_json],
        )?;
        Ok(())
    }

    pub fn delete(&self, path: &str) -> Result<(), FolderMedoidStoreError> {
        let conn = self
            .conn
            .lock()
            .map_err(|_| FolderMedoidStoreError::LockPoisoned)?;
        conn.execute("DELETE FROM folder_medoids WHERE path = ?1", params![path])?;
        Ok(())
    }

    pub fn load_all(&self) -> Result<Vec<FolderCentroid>, FolderMedoidStoreError> {
        let conn = self
            .conn
            .lock()
            .map_err(|_| FolderMedoidStoreError::LockPoisoned)?;
        let mut stmt = conn.prepare(
            "SELECT path, note_count, medoid_json
             FROM folder_medoids
             ORDER BY path ASC",
        )?;
        let rows = stmt.query_map([], |row| {
            let path: String = row.get(0)?;
            let note_count_i64: i64 = row.get(1)?;
            let medoid_json: String = row.get(2)?;
            let medoid = serde_json::from_str::<Vec<f32>>(&medoid_json).map_err(|error| {
                rusqlite::Error::FromSqlConversionFailure(
                    2,
                    rusqlite::types::Type::Text,
                    Box::new(error),
                )
            })?;
            let note_count = u32::try_from(note_count_i64).map_err(|error| {
                rusqlite::Error::FromSqlConversionFailure(
                    1,
                    rusqlite::types::Type::Integer,
                    Box::new(error),
                )
            })?;
            Ok(FolderCentroid {
                path,
                note_count,
                medoid,
            })
        })?;
        let mut folders = Vec::new();
        for row in rows {
            let folder = row?;
            validate_folder(&folder)?;
            folders.push(folder);
        }
        Ok(folders)
    }

    pub fn journal_mode(&self) -> Result<String, FolderMedoidStoreError> {
        let conn = self
            .conn
            .lock()
            .map_err(|_| FolderMedoidStoreError::LockPoisoned)?;
        Ok(conn.query_row("PRAGMA journal_mode", [], |row| row.get(0))?)
    }
}

#[derive(Debug, Error)]
pub enum FolderMedoidStoreError {
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("sqlite: {0}")]
    Sqlite(#[from] rusqlite::Error),
    #[error("json: {0}")]
    Json(#[from] serde_json::Error),
    #[error("folder path must not be empty")]
    EmptyPath,
    #[error("medoid vector must not be empty and must contain only finite values")]
    InvalidMedoid,
    #[error("sqlite connection lock poisoned")]
    LockPoisoned,
}

pub async fn try_centroid(
    capture_text: &str,
    folders: &[FolderCentroid],
    embedder: &Arc<dyn EmbeddingProvider>,
) -> Option<RouteDecision> {
    if capture_text.trim().is_empty() {
        return None;
    }

    let candidates = folders
        .iter()
        .filter(|folder| !folder.path.starts_with(INBOX_PREFIX))
        .filter(|folder| folder.note_count >= MIN_NOTE_COUNT_FOR_CENTROID)
        .filter(|folder| !folder.medoid.is_empty())
        .collect::<Vec<_>>();
    if candidates.is_empty() {
        return None;
    }

    let query = embedder.embed(capture_text).await;
    if query.is_empty() {
        return None;
    }

    let mut scored = candidates
        .into_iter()
        .map(|folder| (folder.path.clone(), cosine(&query, &folder.medoid)))
        .collect::<Vec<_>>();
    scored.sort_by(|left, right| {
        right
            .1
            .partial_cmp(&left.1)
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    let top = scored
        .into_iter()
        .take(TOP_K_NEIGHBOURS)
        .collect::<Vec<_>>();
    let confidence = top.first().map(|(_, score)| *score as f64).unwrap_or(0.0);
    if confidence < VARIANT_A_FLOOR {
        return None;
    }

    let alternatives = top
        .iter()
        .skip(1)
        .map(|(path, score)| AlternativePath {
            path: path.clone(),
            score: *score as f64,
        })
        .collect();

    Some(RouteDecision {
        action: Action::Place,
        folder_path: Some(top[0].0.clone()),
        target_note_path: None,
        new_folder_name: None,
        confidence,
        reasoning_trace: format!(
            "variant_a centroid cosine {:.3} >= floor {:.2}",
            confidence, VARIANT_A_FLOOR
        ),
        alternative_paths: alternatives,
    })
}

fn cosine(left: &[f32], right: &[f32]) -> f32 {
    if left.len() != right.len() || left.is_empty() {
        return 0.0;
    }
    let mut dot = 0.0_f32;
    let mut left_norm = 0.0_f32;
    let mut right_norm = 0.0_f32;
    for index in 0..left.len() {
        dot += left[index] * right[index];
        left_norm += left[index] * left[index];
        right_norm += right[index] * right[index];
    }
    if left_norm == 0.0 || right_norm == 0.0 {
        0.0
    } else {
        dot / (left_norm.sqrt() * right_norm.sqrt())
    }
}

fn init_connection(conn: &Connection) -> Result<(), FolderMedoidStoreError> {
    conn.pragma_update(None, "journal_mode", "WAL")?;
    conn.pragma_update(None, "synchronous", "NORMAL")?;
    conn.execute_batch(SCHEMA)?;
    Ok(())
}

fn validate_folder(folder: &FolderCentroid) -> Result<(), FolderMedoidStoreError> {
    if folder.path.trim().is_empty() {
        return Err(FolderMedoidStoreError::EmptyPath);
    }
    if folder.medoid.is_empty() || folder.medoid.iter().any(|value| !value.is_finite()) {
        return Err(FolderMedoidStoreError::InvalidMedoid);
    }
    Ok(())
}
