//! iMessage Contact Routing — Phase 6 extension
//!
//! Per-contact model and behavior configuration for the iMessage-as-main-driver
//! UX. Each iMessage handle (phone, email, group chat id) can be mapped to:
//!
//! * A model (local or cloud, e.g. "qwen-2b", "claude-sonnet-4-6")
//! * A tool tier ("chat_lite", "chat_pro", "agent")
//! * A prompt mode ("general", "code", "research")
//! * Allowlist/denylist flags
//! * An auto-reply toggle
//! * A display name override
//!
//! The mapping persists in a SQLite database at
//! `~/.epistemos/imessage_contacts.db`. A separate Swift service
//! (`iMessageDriverService.swift`, not yet written) polls `chat.db` for new
//! messages from allowlisted contacts, looks up the routing here, and spawns
//! an agent session with the matching configuration.

use std::path::PathBuf;
use std::sync::{Mutex, OnceLock};

use async_trait::async_trait;
use chrono::{DateTime, Utc};
use rusqlite::{Connection, params};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

use super::registry::{ToolError, ToolHandler};

// MARK: - Storage

fn db_path() -> PathBuf {
    if let Ok(p) = std::env::var("EPISTEMOS_IMESSAGE_CONTACTS_DB") {
        return PathBuf::from(p);
    }
    let mut base = dirs::home_dir().unwrap_or_else(|| PathBuf::from("."));
    base.push(".epistemos");
    let _ = std::fs::create_dir_all(&base);
    base.push("imessage_contacts.db");
    base
}

fn connection() -> Result<Connection, ToolError> {
    let path = db_path();
    let conn = Connection::open(&path)
        .map_err(|e| ToolError::ExecutionFailed(format!("open contacts db: {e}")))?;
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS imessage_contacts (
            handle        TEXT PRIMARY KEY,
            display_name  TEXT,
            model         TEXT NOT NULL,
            tool_tier     TEXT NOT NULL DEFAULT 'chat_pro',
            prompt_mode   TEXT NOT NULL DEFAULT 'general',
            allowed       INTEGER NOT NULL DEFAULT 1,
            auto_reply    INTEGER NOT NULL DEFAULT 1,
            auto_approve  INTEGER NOT NULL DEFAULT 0,
            notes         TEXT,
            created_at    TEXT NOT NULL,
            updated_at    TEXT NOT NULL,
            last_message  TEXT
        );",
    )
    .map_err(|e| ToolError::ExecutionFailed(format!("init contacts schema: {e}")))?;
    Ok(conn)
}

static DB_LOCK: OnceLock<Mutex<()>> = OnceLock::new();
fn db_mutex() -> &'static Mutex<()> {
    DB_LOCK.get_or_init(|| Mutex::new(()))
}

// MARK: - Data

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContactConfig {
    pub handle: String,
    pub display_name: Option<String>,
    pub model: String,
    pub tool_tier: String,
    pub prompt_mode: String,
    pub allowed: bool,
    pub auto_reply: bool,
    pub auto_approve: bool,
    pub notes: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub last_message: Option<DateTime<Utc>>,
}

fn parse_row(row: &rusqlite::Row) -> rusqlite::Result<ContactConfig> {
    let created_at: String = row.get("created_at")?;
    let updated_at: String = row.get("updated_at")?;
    let last_message: Option<String> = row.get("last_message")?;
    Ok(ContactConfig {
        handle: row.get("handle")?,
        display_name: row.get("display_name")?,
        model: row.get("model")?,
        tool_tier: row.get("tool_tier")?,
        prompt_mode: row.get("prompt_mode")?,
        allowed: {
            let v: i64 = row.get("allowed")?;
            v != 0
        },
        auto_reply: {
            let v: i64 = row.get("auto_reply")?;
            v != 0
        },
        auto_approve: {
            let v: i64 = row.get("auto_approve")?;
            v != 0
        },
        notes: row.get("notes")?,
        created_at: DateTime::parse_from_rfc3339(&created_at)
            .map(|dt| dt.with_timezone(&Utc))
            .unwrap_or_else(|_| Utc::now()),
        updated_at: DateTime::parse_from_rfc3339(&updated_at)
            .map(|dt| dt.with_timezone(&Utc))
            .unwrap_or_else(|_| Utc::now()),
        last_message: last_message.and_then(|s| {
            DateTime::parse_from_rfc3339(&s)
                .ok()
                .map(|dt| dt.with_timezone(&Utc))
        }),
    })
}

fn contact_to_json(c: &ContactConfig) -> Value {
    json!({
        "handle": c.handle,
        "display_name": c.display_name,
        "model": c.model,
        "tool_tier": c.tool_tier,
        "prompt_mode": c.prompt_mode,
        "allowed": c.allowed,
        "auto_reply": c.auto_reply,
        "auto_approve": c.auto_approve,
        "notes": c.notes,
        "created_at": c.created_at.to_rfc3339(),
        "updated_at": c.updated_at.to_rfc3339(),
        "last_message": c.last_message.map(|d| d.to_rfc3339()),
    })
}

fn parse_route_tool_tier(input: &Value) -> Result<String, ToolError> {
    let tool_tier = input
        .get("tool_tier")
        .and_then(Value::as_str)
        .unwrap_or("chat_pro")
        .to_string();
    match tool_tier.as_str() {
        "none" | "chat_lite" | "chat_pro" | "agent" => Ok(tool_tier),
        "full" => Err(ToolError::InvalidArguments(
            "tool_tier 'full' is not allowed for iMessage contact routes; use 'agent' at most"
                .to_string(),
        )),
        _ => Err(ToolError::InvalidArguments(format!(
            "tool_tier '{tool_tier}' invalid"
        ))),
    }
}

// MARK: - Handler

pub struct IMessageContactsHandler;

#[async_trait]
impl ToolHandler for IMessageContactsHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let action = input
            .get("action")
            .and_then(Value::as_str)
            .unwrap_or("list");
        let input_owned = input.clone();
        let action_owned = action.to_string();

        tokio::task::spawn_blocking(move || -> Result<String, ToolError> {
            let _gate = db_mutex()
                .lock()
                .map_err(|e| ToolError::ExecutionFailed(format!("contacts lock: {e}")))?;
            match action_owned.as_str() {
                "list" => list_contacts(&input_owned),
                "get" => get_contact(&input_owned),
                "set" | "upsert" => set_contact(&input_owned),
                "remove" | "delete" => remove_contact(&input_owned),
                "resolve" => resolve_contact(&input_owned),
                "record_message" => record_message(&input_owned),
                other => Err(ToolError::InvalidArguments(format!(
                    "unknown action '{other}' (expected: list|get|set|remove|resolve|record_message)"
                ))),
            }
        })
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("contacts join: {e}")))?
    }
}

fn list_contacts(input: &Value) -> Result<String, ToolError> {
    let allowed_only = input
        .get("allowed_only")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    let conn = connection()?;
    let query = if allowed_only {
        "SELECT * FROM imessage_contacts WHERE allowed = 1 ORDER BY updated_at DESC"
    } else {
        "SELECT * FROM imessage_contacts ORDER BY updated_at DESC"
    };
    let mut stmt = conn
        .prepare(query)
        .map_err(|e| ToolError::ExecutionFailed(format!("prepare list: {e}")))?;
    let rows = stmt
        .query_map([], parse_row)
        .map_err(|e| ToolError::ExecutionFailed(format!("query list: {e}")))?;
    let mut contacts = Vec::new();
    for row in rows {
        let c = row.map_err(|e| ToolError::ExecutionFailed(format!("row parse: {e}")))?;
        contacts.push(contact_to_json(&c));
    }
    Ok(json!({
        "action": "list",
        "count": contacts.len(),
        "contacts": contacts,
    })
    .to_string())
}

fn get_contact(input: &Value) -> Result<String, ToolError> {
    let handle = input
        .get("handle")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'handle'".into()))?;
    let conn = connection()?;
    let mut stmt = conn
        .prepare("SELECT * FROM imessage_contacts WHERE handle = ?1")
        .map_err(|e| ToolError::ExecutionFailed(format!("prepare get: {e}")))?;
    let mut rows = stmt
        .query_map(params![handle], parse_row)
        .map_err(|e| ToolError::ExecutionFailed(format!("query get: {e}")))?;
    if let Some(row) = rows.next() {
        let c = row.map_err(|e| ToolError::ExecutionFailed(format!("row parse: {e}")))?;
        Ok(json!({ "action": "get", "contact": contact_to_json(&c) }).to_string())
    } else {
        Err(ToolError::NotFound(format!(
            "contact '{handle}' not configured"
        )))
    }
}

fn set_contact(input: &Value) -> Result<String, ToolError> {
    let handle = input
        .get("handle")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'handle'".into()))?
        .to_string();
    let model = input
        .get("model")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'model'".into()))?
        .to_string();
    let display_name = input
        .get("display_name")
        .and_then(Value::as_str)
        .map(String::from);
    let tool_tier = parse_route_tool_tier(input)?;
    let prompt_mode = input
        .get("prompt_mode")
        .and_then(Value::as_str)
        .unwrap_or("general")
        .to_string();
    if !matches!(prompt_mode.as_str(), "general" | "code" | "research") {
        return Err(ToolError::InvalidArguments(format!(
            "prompt_mode '{prompt_mode}' invalid"
        )));
    }
    let allowed = input
        .get("allowed")
        .and_then(Value::as_bool)
        .unwrap_or(true);
    let auto_reply = input
        .get("auto_reply")
        .and_then(Value::as_bool)
        .unwrap_or(true);
    let auto_approve = input
        .get("auto_approve")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    let notes = input.get("notes").and_then(Value::as_str).map(String::from);

    let now = Utc::now();
    let conn = connection()?;
    // Upsert via ON CONFLICT.
    conn.execute(
        "INSERT INTO imessage_contacts
            (handle, display_name, model, tool_tier, prompt_mode,
             allowed, auto_reply, auto_approve, notes, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?10)
         ON CONFLICT(handle) DO UPDATE SET
            display_name = excluded.display_name,
            model = excluded.model,
            tool_tier = excluded.tool_tier,
            prompt_mode = excluded.prompt_mode,
            allowed = excluded.allowed,
            auto_reply = excluded.auto_reply,
            auto_approve = excluded.auto_approve,
            notes = excluded.notes,
            updated_at = excluded.updated_at",
        params![
            handle,
            display_name,
            model,
            tool_tier,
            prompt_mode,
            allowed as i64,
            auto_reply as i64,
            auto_approve as i64,
            notes,
            now.to_rfc3339(),
        ],
    )
    .map_err(|e| ToolError::ExecutionFailed(format!("upsert contact: {e}")))?;

    let contact = ContactConfig {
        handle,
        display_name,
        model,
        tool_tier,
        prompt_mode,
        allowed,
        auto_reply,
        auto_approve,
        notes,
        created_at: now,
        updated_at: now,
        last_message: None,
    };
    Ok(json!({
        "success": true,
        "action": "set",
        "contact": contact_to_json(&contact),
    })
    .to_string())
}

fn remove_contact(input: &Value) -> Result<String, ToolError> {
    let handle = input
        .get("handle")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'handle'".into()))?;
    let conn = connection()?;
    let count = conn
        .execute(
            "DELETE FROM imessage_contacts WHERE handle = ?1",
            params![handle],
        )
        .map_err(|e| ToolError::ExecutionFailed(format!("delete contact: {e}")))?;
    if count == 0 {
        return Err(ToolError::NotFound(format!(
            "contact '{handle}' not configured"
        )));
    }
    Ok(json!({ "success": true, "action": "remove", "handle": handle }).to_string())
}

/// Driver-side helper: given a handle, return the routing config OR a
/// "not configured" sentinel so the poller can decide whether to ignore or
/// create a default profile.
fn resolve_contact(input: &Value) -> Result<String, ToolError> {
    let handle = input
        .get("handle")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'handle'".into()))?;
    let conn = connection()?;
    let mut stmt = conn
        .prepare("SELECT * FROM imessage_contacts WHERE handle = ?1")
        .map_err(|e| ToolError::ExecutionFailed(format!("prepare resolve: {e}")))?;
    let mut rows = stmt
        .query_map(params![handle], parse_row)
        .map_err(|e| ToolError::ExecutionFailed(format!("query resolve: {e}")))?;
    if let Some(row) = rows.next() {
        let c = row.map_err(|e| ToolError::ExecutionFailed(format!("row parse: {e}")))?;
        return Ok(json!({
            "action": "resolve",
            "configured": true,
            "allowed": c.allowed,
            "auto_reply": c.auto_reply,
            "auto_approve": c.auto_approve,
            "contact": contact_to_json(&c),
        })
        .to_string());
    }
    Ok(json!({
        "action": "resolve",
        "configured": false,
        "allowed": false,
        "auto_reply": false,
        "handle": handle,
        "note": "contact not configured — poller should ignore or prompt user",
    })
    .to_string())
}

/// Update the `last_message` timestamp for a handle. Useful for the poller
/// to deduplicate runs.
fn record_message(input: &Value) -> Result<String, ToolError> {
    let handle = input
        .get("handle")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'handle'".into()))?;
    let now = Utc::now();
    let conn = connection()?;
    let count = conn
        .execute(
            "UPDATE imessage_contacts SET last_message = ?1, updated_at = ?1 WHERE handle = ?2",
            params![now.to_rfc3339(), handle],
        )
        .map_err(|e| ToolError::ExecutionFailed(format!("update last_message: {e}")))?;
    if count == 0 {
        return Err(ToolError::NotFound(format!(
            "contact '{handle}' not configured"
        )));
    }
    Ok(json!({
        "success": true,
        "action": "record_message",
        "handle": handle,
        "last_message": now.to_rfc3339(),
    })
    .to_string())
}

pub fn imessage_contacts_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "imessage_contacts".to_string(),
        description: "Configure per-contact routing for the iMessage-as-main-driver UX. Each \
             handle (phone, email, or group chat id) maps to a model, tool tier, prompt mode, \
             and allowlist/auto-reply flags. Actions: list (all contacts, filter with \
             allowed_only=true), get (by handle), set/upsert (create or update), remove, \
             resolve (driver lookup — returns 'configured: false' for unknown handles), \
             record_message (stamp last_message for poller dedup)."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["list", "get", "set", "upsert", "remove", "delete", "resolve", "record_message"],
                    "default": "list"
                },
                "handle": { "type": "string", "description": "iMessage handle (phone/email/chat_id)." },
                "display_name": { "type": "string" },
                "model": { "type": "string", "description": "Model id like 'qwen-2b', 'claude-sonnet-4-6'." },
                "tool_tier": {
                    "type": "string",
                    "enum": ["none", "chat_lite", "chat_pro", "agent"],
                    "default": "chat_pro"
                },
                "prompt_mode": {
                    "type": "string",
                    "enum": ["general", "code", "research"],
                    "default": "general"
                },
                "allowed": { "type": "boolean", "default": true },
                "auto_reply": { "type": "boolean", "default": true },
                "auto_approve": { "type": "boolean", "default": false, "description": "Auto-approve Modification tools for this contact. Leave false unless you fully trust them." },
                "notes": { "type": "string" },
                "allowed_only": { "type": "boolean", "description": "For 'list' action — only return allowed contacts." }
            },
            "required": ["action"]
        }),
    }
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    // Test-isolation gates use `std::sync::MutexGuard` held across
    // `.await` to serialize against process-wide state (the iMessage
    // contacts SQLite store). Clippy's `await_holding_lock` lint
    // correctly flags the sync-mutex-across-await idiom but here it's
    // intentional: tests are exclusive within the gate, and a
    // `tokio::sync::Mutex` would require every test to hop through
    // an async runtime. See `resources/bridge.rs::tests` for the
    // canonical rationale.
    #![allow(clippy::await_holding_lock)]

    use super::*;
    use serde_json::json;
    use std::sync::MutexGuard;
    use tempfile::TempDir;

    fn lock_tests() -> MutexGuard<'static, ()> {
        static GATE: OnceLock<Mutex<()>> = OnceLock::new();
        GATE.get_or_init(|| Mutex::new(()))
            .lock()
            .unwrap_or_else(|poison| poison.into_inner())
    }

    struct TempDb {
        _dir: TempDir,
    }

    impl TempDb {
        fn new() -> Self {
            let dir = TempDir::new().unwrap();
            std::env::set_var(
                "EPISTEMOS_IMESSAGE_CONTACTS_DB",
                dir.path().join("contacts.db"),
            );
            Self { _dir: dir }
        }
    }

    impl Drop for TempDb {
        fn drop(&mut self) {
            std::env::remove_var("EPISTEMOS_IMESSAGE_CONTACTS_DB");
        }
    }

    #[tokio::test]
    async fn set_and_get_roundtrip() {
        let _gate = lock_tests();
        let _db = TempDb::new();
        let handler = IMessageContactsHandler;

        let set_result = handler
            .execute(&json!({
                "action": "set",
                "handle": "+15551234567",
                "display_name": "Alice",
                "model": "claude-sonnet-4-6",
                "tool_tier": "chat_pro",
                "prompt_mode": "general",
                "auto_reply": true
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&set_result).unwrap();
        assert_eq!(parsed["success"], json!(true));

        let get_result = handler
            .execute(&json!({ "action": "get", "handle": "+15551234567" }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&get_result).unwrap();
        assert_eq!(parsed["contact"]["display_name"], json!("Alice"));
        assert_eq!(parsed["contact"]["model"], json!("claude-sonnet-4-6"));
        assert_eq!(parsed["contact"]["tool_tier"], json!("chat_pro"));
    }

    #[tokio::test]
    async fn upsert_updates_existing_contact() {
        let _gate = lock_tests();
        let _db = TempDb::new();
        let handler = IMessageContactsHandler;

        handler
            .execute(&json!({
                "action": "set",
                "handle": "bob@example.com",
                "model": "qwen-2b",
                "tool_tier": "chat_lite"
            }))
            .await
            .unwrap();
        // Update to a different model.
        handler
            .execute(&json!({
                "action": "set",
                "handle": "bob@example.com",
                "model": "claude-opus-4-6",
                "tool_tier": "agent",
                "auto_approve": true
            }))
            .await
            .unwrap();

        let result = handler
            .execute(&json!({ "action": "get", "handle": "bob@example.com" }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["contact"]["model"], json!("claude-opus-4-6"));
        assert_eq!(parsed["contact"]["tool_tier"], json!("agent"));
        assert_eq!(parsed["contact"]["auto_approve"], json!(true));
    }

    #[tokio::test]
    async fn list_respects_allowed_only_filter() {
        let _gate = lock_tests();
        let _db = TempDb::new();
        let handler = IMessageContactsHandler;

        handler
            .execute(&json!({
                "action": "set",
                "handle": "allowed@example.com",
                "model": "qwen-2b",
                "allowed": true
            }))
            .await
            .unwrap();
        handler
            .execute(&json!({
                "action": "set",
                "handle": "blocked@example.com",
                "model": "qwen-2b",
                "allowed": false
            }))
            .await
            .unwrap();

        let all = handler.execute(&json!({ "action": "list" })).await.unwrap();
        let all_parsed: Value = serde_json::from_str(&all).unwrap();
        assert_eq!(all_parsed["count"], json!(2));

        let allowed = handler
            .execute(&json!({ "action": "list", "allowed_only": true }))
            .await
            .unwrap();
        let allowed_parsed: Value = serde_json::from_str(&allowed).unwrap();
        assert_eq!(allowed_parsed["count"], json!(1));
    }

    #[tokio::test]
    async fn resolve_returns_unconfigured_for_unknown_handle() {
        let _gate = lock_tests();
        let _db = TempDb::new();
        let handler = IMessageContactsHandler;

        let result = handler
            .execute(&json!({
                "action": "resolve",
                "handle": "+15559999999"
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["configured"], json!(false));
        assert_eq!(parsed["allowed"], json!(false));
    }

    #[tokio::test]
    async fn resolve_returns_configured_for_known_handle() {
        let _gate = lock_tests();
        let _db = TempDb::new();
        let handler = IMessageContactsHandler;

        handler
            .execute(&json!({
                "action": "set",
                "handle": "known@example.com",
                "model": "qwen-2b"
            }))
            .await
            .unwrap();

        let result = handler
            .execute(&json!({
                "action": "resolve",
                "handle": "known@example.com"
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["configured"], json!(true));
        assert_eq!(parsed["allowed"], json!(true));
    }

    #[tokio::test]
    async fn remove_contact_deletes_row() {
        let _gate = lock_tests();
        let _db = TempDb::new();
        let handler = IMessageContactsHandler;

        handler
            .execute(&json!({
                "action": "set",
                "handle": "temp@example.com",
                "model": "qwen-2b"
            }))
            .await
            .unwrap();
        let removed = handler
            .execute(&json!({ "action": "remove", "handle": "temp@example.com" }))
            .await
            .unwrap();
        assert!(removed.contains("\"success\":true"));

        let err = handler
            .execute(&json!({ "action": "get", "handle": "temp@example.com" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("not configured"));
    }

    #[tokio::test]
    async fn set_rejects_invalid_tool_tier() {
        let _gate = lock_tests();
        let _db = TempDb::new();
        let handler = IMessageContactsHandler;
        let err = handler
            .execute(&json!({
                "action": "set",
                "handle": "x@example.com",
                "model": "qwen-2b",
                "tool_tier": "nuclear"
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("tool_tier"));
    }

    #[tokio::test]
    async fn set_rejects_full_tool_tier_for_contact_routes() {
        let _gate = lock_tests();
        let _db = TempDb::new();
        let handler = IMessageContactsHandler;
        let err = handler
            .execute(&json!({
                "action": "set",
                "handle": "full@example.com",
                "model": "qwen-2b",
                "tool_tier": "full"
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("not allowed"));
    }

    #[test]
    fn schema_caps_contact_tool_tier_at_agent() {
        let schema = imessage_contacts_schema();
        let tiers = schema.parameters["properties"]["tool_tier"]["enum"]
            .as_array()
            .unwrap();
        assert!(!tiers.iter().any(|tier| tier.as_str() == Some("full")));
        assert!(tiers.iter().any(|tier| tier.as_str() == Some("agent")));
    }

    #[tokio::test]
    async fn record_message_updates_timestamp() {
        let _gate = lock_tests();
        let _db = TempDb::new();
        let handler = IMessageContactsHandler;

        handler
            .execute(&json!({
                "action": "set",
                "handle": "ts@example.com",
                "model": "qwen-2b"
            }))
            .await
            .unwrap();

        let result = handler
            .execute(&json!({
                "action": "record_message",
                "handle": "ts@example.com"
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["success"], json!(true));
        assert!(parsed["last_message"].is_string());
    }
}
