//! B.1 procedural-memory boundary.
//!
//! Durable skill-outcome memory for Hermes. The first slice keeps retrieval
//! local and deterministic: SQLite persistence, context similarity over the
//! invocation context key, and recency decay.

use std::collections::HashSet;
use std::path::Path;

use rusqlite::{params, Connection, Result};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ProcedureOutcomeDraft {
    pub skill_name: String,
    pub outcome_summary: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ProcedureOutcomeRecord {
    pub skill_name: String,
    pub invocation_context_hash: String,
    pub steps_taken: Vec<String>,
    pub outcome_summary: String,
    pub duration_ms: u64,
    pub error_mode: Option<String>,
    pub succeeded: bool,
    pub occurred_at_unix_seconds: i64,
}

#[derive(Clone, Debug, PartialEq)]
pub struct ProceduralRecall {
    pub record: ProcedureOutcomeRecord,
    pub score: f64,
}

pub struct ProceduralMemoryStore {
    conn: Connection,
}

impl ProceduralMemoryStore {
    pub fn open(path: impl AsRef<Path>) -> Result<Self> {
        if let Some(parent) = path.as_ref().parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        let conn = Connection::open(path)?;
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS procedure_outcomes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                skill_name TEXT NOT NULL,
                invocation_context_hash TEXT NOT NULL,
                steps_taken_json TEXT NOT NULL,
                outcome_summary TEXT NOT NULL,
                duration_ms INTEGER NOT NULL,
                error_mode TEXT,
                succeeded INTEGER NOT NULL,
                occurred_at_unix_seconds INTEGER NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_procedure_outcomes_skill
                ON procedure_outcomes(skill_name, occurred_at_unix_seconds DESC);",
        )?;
        Ok(Self { conn })
    }

    pub fn record_outcome(&self, record: &ProcedureOutcomeRecord) -> Result<()> {
        let steps_json =
            serde_json::to_string(&record.steps_taken).unwrap_or_else(|_| "[]".to_string());
        self.conn.execute(
            "INSERT INTO procedure_outcomes (
                skill_name,
                invocation_context_hash,
                steps_taken_json,
                outcome_summary,
                duration_ms,
                error_mode,
                succeeded,
                occurred_at_unix_seconds
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            params![
                record.skill_name,
                record.invocation_context_hash,
                steps_json,
                record.outcome_summary,
                record.duration_ms as i64,
                record.error_mode,
                i64::from(record.succeeded),
                record.occurred_at_unix_seconds,
            ],
        )?;
        Ok(())
    }

    pub fn recall(
        &self,
        skill_name: &str,
        invocation_context_hash: &str,
        limit: usize,
        now_unix_seconds: i64,
    ) -> Result<Vec<ProceduralRecall>> {
        if limit == 0 {
            return Ok(Vec::new());
        }

        let mut stmt = self.conn.prepare(
            "SELECT
                skill_name,
                invocation_context_hash,
                steps_taken_json,
                outcome_summary,
                duration_ms,
                error_mode,
                succeeded,
                occurred_at_unix_seconds
             FROM procedure_outcomes
             WHERE skill_name = ?1
             ORDER BY occurred_at_unix_seconds DESC
             LIMIT 128",
        )?;

        let rows = stmt.query_map(params![skill_name], |row| {
            let steps_json: String = row.get(2)?;
            let steps_taken = serde_json::from_str::<Vec<String>>(&steps_json).unwrap_or_default();
            Ok(ProcedureOutcomeRecord {
                skill_name: row.get(0)?,
                invocation_context_hash: row.get(1)?,
                steps_taken,
                outcome_summary: row.get(3)?,
                duration_ms: row.get::<_, i64>(4)?.max(0) as u64,
                error_mode: row.get(5)?,
                succeeded: row.get::<_, i64>(6)? != 0,
                occurred_at_unix_seconds: row.get(7)?,
            })
        })?;

        let mut recalls = Vec::new();
        for row in rows {
            let record = row?;
            let similarity =
                context_similarity(invocation_context_hash, &record.invocation_context_hash);
            if similarity <= 0.0 {
                continue;
            }
            let score = similarity
                * recency_decay(record.occurred_at_unix_seconds, now_unix_seconds)
                * if record.succeeded { 1.0 } else { 0.5 };
            recalls.push(ProceduralRecall { record, score });
        }

        recalls.sort_by(|a, b| {
            b.score
                .partial_cmp(&a.score)
                .unwrap_or(std::cmp::Ordering::Equal)
        });
        recalls.truncate(limit);
        Ok(recalls)
    }
}

fn context_similarity(a: &str, b: &str) -> f64 {
    if a == b {
        return 1.0;
    }

    let a_terms = token_set(a);
    let b_terms = token_set(b);
    if a_terms.is_empty() || b_terms.is_empty() {
        return 0.0;
    }

    let intersection = a_terms.intersection(&b_terms).count() as f64;
    let union = a_terms.union(&b_terms).count() as f64;
    if union == 0.0 {
        0.0
    } else {
        intersection / union
    }
}

fn token_set(value: &str) -> HashSet<String> {
    value
        .to_lowercase()
        .split(|c: char| !c.is_ascii_alphanumeric())
        .filter(|part| part.len() > 1)
        .map(str::to_string)
        .collect()
}

fn recency_decay(occurred_at: i64, now: i64) -> f64 {
    let age_seconds = now.saturating_sub(occurred_at).max(0) as f64;
    let age_days = age_seconds / 86_400.0;
    0.5_f64.powf(age_days / 30.0)
}
