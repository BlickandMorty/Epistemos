//! Cron Scheduling Tool — Phase 1 Persistent Cron Jobs
//!
//! The `cronjob` tool lets the agent register scheduled prompts that fire on
//! a cron expression. Jobs are persisted in a local SQLite database so they
//! survive process restarts. The actual execution of scheduled jobs (running
//! a fresh agent loop) is wired up by the caller — this tool only implements
//! the CRUD surface and the next-run computation.
//!
//! Actions:
//!   * `create`  — add a new job (cron expression + prompt + optional name)
//!   * `list`    — show all jobs
//!   * `get`     — fetch a single job by id
//!   * `update`  — change schedule, prompt, or enabled flag
//!   * `remove`  — delete a job
//!   * `pause`   — disable without deleting
//!   * `resume`  — re-enable a paused job

use std::path::PathBuf;
use std::str::FromStr;
use std::sync::{Mutex, OnceLock};

use async_trait::async_trait;
use chrono::{DateTime, Utc};
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use super::registry::{ToolError, ToolHandler};

const MAX_CRON_NAME_CHARS: usize = 120;
const MAX_CRON_PROMPT_CHARS: usize = 8_000;
const MAX_CRON_SCHEDULE_CHARS: usize = 120;
const MAX_CRON_ID_CHARS: usize = 128;
const MAX_LIST_JOBS: usize = 100;

// MARK: - Storage

fn db_path() -> PathBuf {
    // Default to ~/.epistemos/agent_cron.db (tests override via env var).
    if let Ok(override_path) = std::env::var("EPISTEMOS_CRON_DB") {
        return PathBuf::from(override_path);
    }
    let mut base = dirs::home_dir().unwrap_or_else(|| PathBuf::from("."));
    base.push(".epistemos");
    let _ = std::fs::create_dir_all(&base);
    base.push("agent_cron.db");
    base
}

fn connection() -> Result<Connection, ToolError> {
    let path = db_path();
    let conn = Connection::open(&path)
        .map_err(|e| ToolError::ExecutionFailed(format!("open cron db: {e}")))?;
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS cron_jobs (
            id         TEXT PRIMARY KEY,
            name       TEXT NOT NULL,
            prompt     TEXT NOT NULL,
            schedule   TEXT NOT NULL,
            enabled    INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_run   TEXT,
            next_run   TEXT
        );",
    )
    .map_err(|e| ToolError::ExecutionFailed(format!("init cron schema: {e}")))?;
    Ok(conn)
}

static DB_LOCK: OnceLock<Mutex<()>> = OnceLock::new();
fn db_mutex() -> &'static Mutex<()> {
    DB_LOCK.get_or_init(|| Mutex::new(()))
}

// MARK: - Data

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CronJob {
    pub id: String,
    pub name: String,
    pub prompt: String,
    pub schedule: String,
    pub enabled: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub last_run: Option<DateTime<Utc>>,
    pub next_run: Option<DateTime<Utc>>,
}

fn compute_next_run(schedule: &str, after: DateTime<Utc>) -> Result<DateTime<Utc>, ToolError> {
    let sched = cron::Schedule::from_str(schedule).map_err(|e| {
        ToolError::InvalidArguments(format!("invalid cron expression '{schedule}': {e}"))
    })?;
    sched.after(&after).next().ok_or_else(|| {
        ToolError::ExecutionFailed(format!(
            "cron expression '{schedule}' has no future matches"
        ))
    })
}

fn parse_row(row: &rusqlite::Row) -> rusqlite::Result<CronJob> {
    let enabled: i64 = row.get("enabled")?;
    let created_at: String = row.get("created_at")?;
    let updated_at: String = row.get("updated_at")?;
    let last_run: Option<String> = row.get("last_run")?;
    let next_run: Option<String> = row.get("next_run")?;
    Ok(CronJob {
        id: row.get("id")?,
        name: row.get("name")?,
        prompt: row.get("prompt")?,
        schedule: row.get("schedule")?,
        enabled: enabled != 0,
        created_at: DateTime::parse_from_rfc3339(&created_at)
            .map(|dt| dt.with_timezone(&Utc))
            .unwrap_or_else(|_| Utc::now()),
        updated_at: DateTime::parse_from_rfc3339(&updated_at)
            .map(|dt| dt.with_timezone(&Utc))
            .unwrap_or_else(|_| Utc::now()),
        last_run: last_run.and_then(|s| {
            DateTime::parse_from_rfc3339(&s)
                .ok()
                .map(|d| d.with_timezone(&Utc))
        }),
        next_run: next_run.and_then(|s| {
            DateTime::parse_from_rfc3339(&s)
                .ok()
                .map(|d| d.with_timezone(&Utc))
        }),
    })
}

fn job_to_json(job: &CronJob) -> Value {
    json!({
        "id": job.id,
        "name": job.name,
        "prompt": job.prompt,
        "schedule": job.schedule,
        "enabled": job.enabled,
        "created_at": job.created_at.to_rfc3339(),
        "updated_at": job.updated_at.to_rfc3339(),
        "last_run": job.last_run.map(|d| d.to_rfc3339()),
        "next_run": job.next_run.map(|d| d.to_rfc3339()),
    })
}

// MARK: - Handler

pub struct CronJobHandler;

impl CronJobHandler {
    pub fn new() -> Self {
        Self
    }
}

impl Default for CronJobHandler {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait]
impl ToolHandler for CronJobHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let action = input
            .get("action")
            .and_then(Value::as_str)
            .unwrap_or("list");

        // rusqlite is sync — guard with a mutex and offload via spawn_blocking
        // so we don't block the tokio runtime on disk I/O.
        let input_owned = input.clone();
        let action_owned = action.to_string();
        tokio::task::spawn_blocking(move || -> Result<String, ToolError> {
            let _gate = db_mutex()
                .lock()
                .map_err(|e| ToolError::ExecutionFailed(format!("cron lock poisoned: {e}")))?;
            match action_owned.as_str() {
                "create" => create_job(&input_owned),
                "list" => list_jobs(&input_owned),
                "get" => get_job(&input_owned),
                "update" => update_job(&input_owned),
                "remove" => remove_job(&input_owned),
                "pause" => set_enabled(&input_owned, false),
                "resume" => set_enabled(&input_owned, true),
                other => Err(ToolError::InvalidArguments(format!(
                    "unknown cronjob action '{other}' (expected: create|list|get|update|remove|pause|resume)"
                ))),
            }
        })
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("cronjob join: {e}")))?
    }
}

fn create_job(input: &Value) -> Result<String, ToolError> {
    require_persistent_schedule_ack(input, "create")?;
    let name = optional_limited_string(input, "name", "unnamed-job", MAX_CRON_NAME_CHARS)?;
    let prompt = required_limited_string(input, "prompt", MAX_CRON_PROMPT_CHARS)?;
    let schedule = required_limited_string(input, "schedule", MAX_CRON_SCHEDULE_CHARS)?;
    let enabled = input
        .get("enabled")
        .and_then(Value::as_bool)
        .unwrap_or(true);

    let now = Utc::now();
    let next = compute_next_run(&schedule, now)?;
    let id = uuid::Uuid::new_v4().to_string();

    let conn = connection()?;
    conn.execute(
        "INSERT INTO cron_jobs (id, name, prompt, schedule, enabled, created_at, updated_at, last_run, next_run)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, NULL, ?8)",
        params![
            id,
            name,
            prompt,
            schedule,
            enabled as i64,
            now.to_rfc3339(),
            now.to_rfc3339(),
            next.to_rfc3339(),
        ],
    )
    .map_err(|e| ToolError::ExecutionFailed(format!("insert cron job: {e}")))?;

    let job = CronJob {
        id: id.clone(),
        name,
        prompt,
        schedule,
        enabled,
        created_at: now,
        updated_at: now,
        last_run: None,
        next_run: Some(next),
    };
    Ok(json!({
        "success": true,
        "action": "create",
        "job": job_to_json(&job),
    })
    .to_string())
}

fn list_jobs(input: &Value) -> Result<String, ToolError> {
    let limit = input
        .get("limit")
        .and_then(Value::as_u64)
        .unwrap_or(MAX_LIST_JOBS as u64)
        .clamp(1, MAX_LIST_JOBS as u64) as usize;
    let conn = connection()?;
    let mut stmt = conn
        .prepare("SELECT * FROM cron_jobs ORDER BY created_at DESC LIMIT ?1")
        .map_err(|e| ToolError::ExecutionFailed(format!("prepare list: {e}")))?;
    let rows = stmt
        .query_map(params![limit as i64], parse_row)
        .map_err(|e| ToolError::ExecutionFailed(format!("query list: {e}")))?;
    let mut jobs = Vec::new();
    for row in rows {
        let job = row.map_err(|e| ToolError::ExecutionFailed(format!("row parse: {e}")))?;
        jobs.push(job_to_json(&job));
    }
    Ok(json!({
        "action": "list",
        "count": jobs.len(),
        "limit": limit,
        "jobs": jobs,
    })
    .to_string())
}

fn get_job(input: &Value) -> Result<String, ToolError> {
    let id = input
        .get("id")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'id'".into()))?;
    ensure_char_cap("id", id, MAX_CRON_ID_CHARS)?;
    let conn = connection()?;
    let mut stmt = conn
        .prepare("SELECT * FROM cron_jobs WHERE id = ?1")
        .map_err(|e| ToolError::ExecutionFailed(format!("prepare get: {e}")))?;
    let mut rows = stmt
        .query_map(params![id], parse_row)
        .map_err(|e| ToolError::ExecutionFailed(format!("query get: {e}")))?;
    if let Some(row) = rows.next() {
        let job = row.map_err(|e| ToolError::ExecutionFailed(format!("row parse: {e}")))?;
        Ok(json!({ "action": "get", "job": job_to_json(&job) }).to_string())
    } else {
        Err(ToolError::NotFound(format!("cron job '{id}' not found")))
    }
}

fn update_job(input: &Value) -> Result<String, ToolError> {
    let id = input
        .get("id")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'id'".into()))?;
    ensure_char_cap("id", id, MAX_CRON_ID_CHARS)?;
    require_persistent_schedule_ack(input, "update")?;

    // Load existing job.
    let conn = connection()?;
    let mut job: CronJob = {
        let mut stmt = conn
            .prepare("SELECT * FROM cron_jobs WHERE id = ?1")
            .map_err(|e| ToolError::ExecutionFailed(format!("prepare update load: {e}")))?;
        let mut rows = stmt
            .query_map(params![id], parse_row)
            .map_err(|e| ToolError::ExecutionFailed(format!("query update load: {e}")))?;
        rows.next()
            .ok_or_else(|| ToolError::NotFound(format!("cron job '{id}' not found")))?
            .map_err(|e| ToolError::ExecutionFailed(format!("row parse: {e}")))?
    };

    if let Some(prompt) = input.get("prompt").and_then(Value::as_str) {
        ensure_char_cap("prompt", prompt, MAX_CRON_PROMPT_CHARS)?;
        job.prompt = prompt.to_string();
    }
    if let Some(schedule) = input.get("schedule").and_then(Value::as_str) {
        ensure_char_cap("schedule", schedule, MAX_CRON_SCHEDULE_CHARS)?;
        job.next_run = Some(compute_next_run(schedule, Utc::now())?);
        job.schedule = schedule.to_string();
    }
    if let Some(name) = input.get("name").and_then(Value::as_str) {
        ensure_char_cap("name", name, MAX_CRON_NAME_CHARS)?;
        job.name = name.to_string();
    }
    if let Some(enabled) = input.get("enabled").and_then(Value::as_bool) {
        job.enabled = enabled;
    }
    job.updated_at = Utc::now();

    conn.execute(
        "UPDATE cron_jobs SET name = ?1, prompt = ?2, schedule = ?3, enabled = ?4, updated_at = ?5, next_run = ?6 WHERE id = ?7",
        params![
            job.name,
            job.prompt,
            job.schedule,
            job.enabled as i64,
            job.updated_at.to_rfc3339(),
            job.next_run.map(|d| d.to_rfc3339()),
            id,
        ],
    )
    .map_err(|e| ToolError::ExecutionFailed(format!("update cron job: {e}")))?;

    Ok(json!({ "success": true, "action": "update", "job": job_to_json(&job) }).to_string())
}

fn remove_job(input: &Value) -> Result<String, ToolError> {
    let id = input
        .get("id")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'id'".into()))?;
    ensure_char_cap("id", id, MAX_CRON_ID_CHARS)?;
    let conn = connection()?;
    let count = conn
        .execute("DELETE FROM cron_jobs WHERE id = ?1", params![id])
        .map_err(|e| ToolError::ExecutionFailed(format!("delete cron job: {e}")))?;
    if count == 0 {
        return Err(ToolError::NotFound(format!("cron job '{id}' not found")));
    }
    Ok(json!({ "success": true, "action": "remove", "id": id }).to_string())
}

fn set_enabled(input: &Value, enabled: bool) -> Result<String, ToolError> {
    let id = input
        .get("id")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'id'".into()))?;
    ensure_char_cap("id", id, MAX_CRON_ID_CHARS)?;
    if enabled {
        require_persistent_schedule_ack(input, "resume")?;
    }
    let conn = connection()?;
    let updated_at = Utc::now();
    let count = conn
        .execute(
            "UPDATE cron_jobs SET enabled = ?1, updated_at = ?2 WHERE id = ?3",
            params![enabled as i64, updated_at.to_rfc3339(), id],
        )
        .map_err(|e| ToolError::ExecutionFailed(format!("toggle cron job: {e}")))?;
    if count == 0 {
        return Err(ToolError::NotFound(format!("cron job '{id}' not found")));
    }
    Ok(json!({
        "success": true,
        "action": if enabled { "resume" } else { "pause" },
        "id": id,
        "enabled": enabled,
    })
    .to_string())
}

fn require_persistent_schedule_ack(input: &Value, action: &str) -> Result<(), ToolError> {
    if input
        .get("allow_persistent_schedule")
        .and_then(Value::as_bool)
        .unwrap_or(false)
    {
        Ok(())
    } else {
        Err(ToolError::InvalidArguments(format!(
            "allow_persistent_schedule must be true before cronjob can {action} a job that may run later"
        )))
    }
}

fn required_limited_string(input: &Value, key: &str, cap: usize) -> Result<String, ToolError> {
    let value = input
        .get(key)
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments(format!("missing '{key}'")))?;
    ensure_char_cap(key, value, cap)?;
    Ok(value.to_string())
}

fn optional_limited_string(
    input: &Value,
    key: &str,
    default: &str,
    cap: usize,
) -> Result<String, ToolError> {
    let value = input.get(key).and_then(Value::as_str).unwrap_or(default);
    ensure_char_cap(key, value, cap)?;
    Ok(value.to_string())
}

fn ensure_char_cap(label: &str, value: &str, cap: usize) -> Result<(), ToolError> {
    if value.chars().count() > cap {
        Err(ToolError::InvalidArguments(format!(
            "{label} exceeds {cap} character cap"
        )))
    } else {
        Ok(())
    }
}

// MARK: - Schema

pub fn cronjob_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "cronjob".to_string(),
        description: "Create and manage scheduled cron jobs that run prompts on a schedule. \
             Jobs are persisted in SQLite at ~/.epistemos/agent_cron.db. Actions: \
             create (new job with cron expression + prompt), list (all jobs), get (by id), \
             update (change schedule/prompt/name/enabled), remove (delete), \
             pause (disable), resume (re-enable)."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["create", "list", "get", "update", "remove", "pause", "resume"],
                    "default": "list"
                },
                "id": { "type": "string", "description": "Job id for get/update/remove/pause/resume." },
                "name": { "type": "string", "description": "Human-readable job name." },
                "prompt": { "type": "string", "description": "Prompt the agent runs when the job fires." },
                "schedule": { "type": "string", "description": "Cron expression (6 or 7 fields; seconds are supported)." },
                "enabled": { "type": "boolean", "description": "Whether the job should run." },
                "limit": { "type": "integer", "description": "Max jobs returned by list (1-100).", "minimum": 1, "maximum": 100 },
                "allow_persistent_schedule": {
                    "type": "boolean",
                    "description": "Required for create/update/resume because the prompt may run later outside the current turn."
                }
            }
        }),
    }
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    // Test-isolation gate held across `.await` is intentional — see
    // `resources/bridge.rs::tests` for the canonical rationale.
    // Scheduling tests share the EPISTEMOS_CRON_DB env var and the
    // cron-job persistence layer.
    #![allow(clippy::await_holding_lock)]

    use super::*;
    use serde_json::json;
    use std::sync::MutexGuard;
    use tempfile::TempDir;

    /// Serialize scheduling tests — they share the EPISTEMOS_CRON_DB env var.
    fn lock_tests() -> MutexGuard<'static, ()> {
        static GATE: OnceLock<Mutex<()>> = OnceLock::new();
        GATE.get_or_init(|| Mutex::new(()))
            .lock()
            .unwrap_or_else(|poison| poison.into_inner())
    }

    /// RAII guard that points EPISTEMOS_CRON_DB at a fresh tempdir for the
    /// duration of a single test, then clears it.
    struct TempDb {
        _dir: TempDir,
    }

    impl TempDb {
        fn new() -> Self {
            let dir = TempDir::new().unwrap();
            std::env::set_var("EPISTEMOS_CRON_DB", dir.path().join("cron.db"));
            Self { _dir: dir }
        }
    }

    impl Drop for TempDb {
        fn drop(&mut self) {
            std::env::remove_var("EPISTEMOS_CRON_DB");
        }
    }

    #[tokio::test]
    async fn cronjob_create_and_list() {
        let _gate = lock_tests();
        let _db = TempDb::new();
        let handler = CronJobHandler::new();
        let expected_name = format!("test-job-{}", uuid::Uuid::new_v4());

        let created = handler
            .execute(&json!({
                "action": "create",
                "name": expected_name,
                "prompt": "do the thing",
                "schedule": "0 0 * * * *",
                "allow_persistent_schedule": true
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&created).unwrap();
        assert_eq!(parsed["success"], json!(true));

        let list = handler.execute(&json!({ "action": "list" })).await.unwrap();
        let list_parsed: Value = serde_json::from_str(&list).unwrap();
        assert!(list_parsed["count"].as_u64().unwrap() >= 1);
        assert!(list_parsed["jobs"]
            .as_array()
            .unwrap()
            .iter()
            .any(|j| j["name"] == expected_name.as_str()));
    }

    #[tokio::test]
    async fn cronjob_create_requires_persistent_schedule_ack() {
        let _gate = lock_tests();
        let _db = TempDb::new();
        let handler = CronJobHandler::new();

        let err = handler
            .execute(&json!({
                "action": "create",
                "prompt": "do the thing",
                "schedule": "0 0 * * * *"
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("allow_persistent_schedule"));
    }

    #[tokio::test]
    async fn cronjob_rejects_oversized_prompt_before_insert() {
        let _gate = lock_tests();
        let _db = TempDb::new();
        let handler = CronJobHandler::new();

        let err = handler
            .execute(&json!({
                "action": "create",
                "prompt": "x".repeat(MAX_CRON_PROMPT_CHARS + 1),
                "schedule": "0 0 * * * *",
                "allow_persistent_schedule": true
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("prompt exceeds"));
    }

    #[tokio::test]
    async fn cronjob_update_changes_fields() {
        let _gate = lock_tests();
        let _db = TempDb::new();
        let handler = CronJobHandler::new();

        let created = handler
            .execute(&json!({
                "action": "create",
                "name": "orig",
                "prompt": "first",
                "schedule": "0 0 * * * *",
                "allow_persistent_schedule": true
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&created).unwrap();
        let id = parsed["job"]["id"].as_str().unwrap().to_string();

        let updated = handler
            .execute(&json!({
                "action": "update",
                "id": id,
                "prompt": "second",
                "schedule": "0 */5 * * * *",
                "allow_persistent_schedule": true
            }))
            .await
            .unwrap();
        let up_parsed: Value = serde_json::from_str(&updated).unwrap();
        assert_eq!(up_parsed["job"]["prompt"], json!("second"));
        assert_eq!(up_parsed["job"]["schedule"], json!("0 */5 * * * *"));
    }

    #[tokio::test]
    async fn cronjob_pause_and_resume() {
        let _gate = lock_tests();
        let _db = TempDb::new();
        let handler = CronJobHandler::new();

        let created = handler
            .execute(&json!({
                "action": "create",
                "prompt": "x",
                "schedule": "0 0 * * * *",
                "allow_persistent_schedule": true
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&created).unwrap();
        let id = parsed["job"]["id"].as_str().unwrap().to_string();

        let paused = handler
            .execute(&json!({ "action": "pause", "id": id }))
            .await
            .unwrap();
        let p_parsed: Value = serde_json::from_str(&paused).unwrap();
        assert_eq!(p_parsed["enabled"], json!(false));

        let resumed = handler
            .execute(&json!({ "action": "resume", "id": id }))
            .await
            .unwrap_err();
        assert!(format!("{resumed}").contains("allow_persistent_schedule"));

        let resumed = handler
            .execute(&json!({
                "action": "resume",
                "id": id,
                "allow_persistent_schedule": true
            }))
            .await
            .unwrap();
        let r_parsed: Value = serde_json::from_str(&resumed).unwrap();
        assert_eq!(r_parsed["enabled"], json!(true));
    }

    #[tokio::test]
    async fn cronjob_remove_deletes_row() {
        let _gate = lock_tests();
        let _db = TempDb::new();
        let handler = CronJobHandler::new();

        let created = handler
            .execute(&json!({
                "action": "create",
                "prompt": "x",
                "schedule": "0 0 * * * *",
                "allow_persistent_schedule": true
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&created).unwrap();
        let id = parsed["job"]["id"].as_str().unwrap().to_string();

        let removed = handler
            .execute(&json!({ "action": "remove", "id": id }))
            .await
            .unwrap();
        assert!(removed.contains("\"success\":true"));

        let get_err = handler
            .execute(&json!({ "action": "get", "id": id }))
            .await
            .unwrap_err();
        assert!(format!("{get_err}").contains("not found"));
    }

    #[test]
    fn compute_next_run_accepts_valid_expression() {
        let now = Utc::now();
        let next = compute_next_run("0 0 * * * *", now).unwrap();
        assert!(next > now);
    }

    #[test]
    fn compute_next_run_rejects_garbage() {
        let err = compute_next_run("not a cron expression", Utc::now()).unwrap_err();
        assert!(format!("{err}").contains("invalid"));
    }
}
