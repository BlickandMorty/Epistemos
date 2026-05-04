use std::path::PathBuf;
use std::sync::{Mutex, OnceLock};

use async_trait::async_trait;
use chrono::{DateTime, Utc};
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use super::registry::{ToolError, ToolHandler};

fn db_path() -> PathBuf {
    if let Ok(path) = std::env::var("EPISTEMOS_CHANNEL_CONTACTS_DB") {
        return PathBuf::from(path);
    }
    let mut base = dirs::home_dir().unwrap_or_else(|| PathBuf::from("."));
    base.push(".epistemos");
    let _ = std::fs::create_dir_all(&base);
    base.push("channel_contacts.db");
    base
}

fn connection() -> Result<Connection, ToolError> {
    let path = db_path();
    let conn = Connection::open(&path)
        .map_err(|e| ToolError::ExecutionFailed(format!("open channel contacts db: {e}")))?;
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS channel_contacts (
            channel_id     TEXT NOT NULL,
            handle         TEXT NOT NULL,
            display_name   TEXT,
            model          TEXT NOT NULL,
            tool_tier      TEXT NOT NULL DEFAULT 'chat_pro',
            prompt_mode    TEXT NOT NULL DEFAULT 'general',
            allowed        INTEGER NOT NULL DEFAULT 1,
            auto_reply     INTEGER NOT NULL DEFAULT 1,
            auto_approve   INTEGER NOT NULL DEFAULT 0,
            notes          TEXT,
            created_at     TEXT NOT NULL,
            updated_at     TEXT NOT NULL,
            last_message   TEXT,
            PRIMARY KEY (channel_id, handle)
        );
        CREATE INDEX IF NOT EXISTS idx_channel_contacts_channel_updated
            ON channel_contacts(channel_id, updated_at DESC);",
    )
    .map_err(|e| ToolError::ExecutionFailed(format!("init channel contacts schema: {e}")))?;
    Ok(conn)
}

static DB_LOCK: OnceLock<Mutex<()>> = OnceLock::new();

fn db_mutex() -> &'static Mutex<()> {
    DB_LOCK.get_or_init(|| Mutex::new(()))
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChannelContactConfig {
    pub channel_id: String,
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

fn parse_row(row: &rusqlite::Row) -> rusqlite::Result<ChannelContactConfig> {
    let created_at: String = row.get("created_at")?;
    let updated_at: String = row.get("updated_at")?;
    let last_message: Option<String> = row.get("last_message")?;
    Ok(ChannelContactConfig {
        channel_id: row.get("channel_id")?,
        handle: row.get("handle")?,
        display_name: row.get("display_name")?,
        model: row.get("model")?,
        tool_tier: row.get("tool_tier")?,
        prompt_mode: row.get("prompt_mode")?,
        allowed: row.get::<_, i64>("allowed")? != 0,
        auto_reply: row.get::<_, i64>("auto_reply")? != 0,
        auto_approve: row.get::<_, i64>("auto_approve")? != 0,
        notes: row.get("notes")?,
        created_at: DateTime::parse_from_rfc3339(&created_at)
            .map(|date| date.with_timezone(&Utc))
            .unwrap_or_else(|_| Utc::now()),
        updated_at: DateTime::parse_from_rfc3339(&updated_at)
            .map(|date| date.with_timezone(&Utc))
            .unwrap_or_else(|_| Utc::now()),
        last_message: last_message.and_then(|value| {
            DateTime::parse_from_rfc3339(&value)
                .ok()
                .map(|date| date.with_timezone(&Utc))
        }),
    })
}

fn contact_to_json(contact: &ChannelContactConfig) -> Value {
    json!({
        "channel_id": contact.channel_id,
        "handle": contact.handle,
        "display_name": contact.display_name,
        "model": contact.model,
        "tool_tier": contact.tool_tier,
        "prompt_mode": contact.prompt_mode,
        "allowed": contact.allowed,
        "auto_reply": contact.auto_reply,
        "auto_approve": contact.auto_approve,
        "notes": contact.notes,
        "created_at": contact.created_at.to_rfc3339(),
        "updated_at": contact.updated_at.to_rfc3339(),
        "last_message": contact.last_message.map(|date| date.to_rfc3339()),
    })
}

pub struct ChannelContactsHandler;

#[async_trait]
impl ToolHandler for ChannelContactsHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let action = input
            .get("action")
            .and_then(Value::as_str)
            .unwrap_or("list")
            .to_string();
        let input_owned = input.clone();

        tokio::task::spawn_blocking(move || -> Result<String, ToolError> {
            let _gate = db_mutex()
                .lock()
                .map_err(|e| ToolError::ExecutionFailed(format!("channel contacts lock: {e}")))?;
            match action.as_str() {
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
        .map_err(|e| ToolError::ExecutionFailed(format!("channel contacts join: {e}")))?
    }
}

fn parse_channel_id(input: &Value, required: bool) -> Result<Option<String>, ToolError> {
    let channel_id = input
        .get("channel_id")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned);
    if required && channel_id.is_none() {
        return Err(ToolError::InvalidArguments("missing 'channel_id'".into()));
    }
    Ok(channel_id)
}

fn parse_handle(input: &Value) -> Result<String, ToolError> {
    input
        .get("handle")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'handle'".into()))
}

fn list_contacts(input: &Value) -> Result<String, ToolError> {
    let channel_id = parse_channel_id(input, false)?;
    let allowed_only = input
        .get("allowed_only")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    let conn = connection()?;

    let sql = match (channel_id.is_some(), allowed_only) {
        (true, true) => {
            "SELECT * FROM channel_contacts
             WHERE channel_id = ?1 AND allowed = 1
             ORDER BY updated_at DESC"
        }
        (true, false) => {
            "SELECT * FROM channel_contacts
             WHERE channel_id = ?1
             ORDER BY updated_at DESC"
        }
        (false, true) => {
            "SELECT * FROM channel_contacts
             WHERE allowed = 1
             ORDER BY channel_id ASC, updated_at DESC"
        }
        (false, false) => {
            "SELECT * FROM channel_contacts
             ORDER BY channel_id ASC, updated_at DESC"
        }
    };

    let mut stmt = conn
        .prepare(sql)
        .map_err(|e| ToolError::ExecutionFailed(format!("prepare channel contact list: {e}")))?;
    let rows = if let Some(channel_id) = channel_id.as_deref() {
        stmt.query_map(params![channel_id], parse_row)
            .map_err(|e| ToolError::ExecutionFailed(format!("query channel contact list: {e}")))?
    } else {
        stmt.query_map([], parse_row)
            .map_err(|e| ToolError::ExecutionFailed(format!("query channel contact list: {e}")))?
    };

    let mut contacts = Vec::new();
    for row in rows {
        contacts.push(contact_to_json(&row.map_err(|e| {
            ToolError::ExecutionFailed(format!("parse contact row: {e}"))
        })?));
    }

    Ok(json!({
        "action": "list",
        "channel_id": channel_id,
        "count": contacts.len(),
        "contacts": contacts,
    })
    .to_string())
}

fn get_contact(input: &Value) -> Result<String, ToolError> {
    let channel_id = parse_channel_id(input, true)?.unwrap_or_default();
    let handle = parse_handle(input)?;
    let conn = connection()?;
    let mut stmt = conn
        .prepare("SELECT * FROM channel_contacts WHERE channel_id = ?1 AND handle = ?2")
        .map_err(|e| ToolError::ExecutionFailed(format!("prepare get channel contact: {e}")))?;
    let mut rows = stmt
        .query_map(params![channel_id, handle], parse_row)
        .map_err(|e| ToolError::ExecutionFailed(format!("query get channel contact: {e}")))?;
    if let Some(row) = rows.next() {
        let contact =
            row.map_err(|e| ToolError::ExecutionFailed(format!("parse contact row: {e}")))?;
        return Ok(json!({
            "action": "get",
            "contact": contact_to_json(&contact),
        })
        .to_string());
    }
    Err(ToolError::NotFound("contact not configured".into()))
}

fn set_contact(input: &Value) -> Result<String, ToolError> {
    let channel_id = parse_channel_id(input, true)?.unwrap_or_default();
    let handle = parse_handle(input)?;
    let model = input
        .get("model")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'model'".into()))?;
    let display_name = input
        .get("display_name")
        .and_then(Value::as_str)
        .map(String::from);
    let tool_tier = input
        .get("tool_tier")
        .and_then(Value::as_str)
        .unwrap_or("chat_pro")
        .to_string();
    if !matches!(
        tool_tier.as_str(),
        "none" | "chat_lite" | "chat_pro" | "agent" | "full"
    ) {
        return Err(ToolError::InvalidArguments(format!(
            "tool_tier '{tool_tier}' invalid"
        )));
    }
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
    conn.execute(
        "INSERT INTO channel_contacts
            (channel_id, handle, display_name, model, tool_tier, prompt_mode,
             allowed, auto_reply, auto_approve, notes, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?11)
         ON CONFLICT(channel_id, handle) DO UPDATE SET
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
            channel_id,
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
    .map_err(|e| ToolError::ExecutionFailed(format!("upsert channel contact: {e}")))?;

    let contact = ChannelContactConfig {
        channel_id,
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
    let channel_id = parse_channel_id(input, true)?.unwrap_or_default();
    let handle = parse_handle(input)?;
    let conn = connection()?;
    let count = conn
        .execute(
            "DELETE FROM channel_contacts WHERE channel_id = ?1 AND handle = ?2",
            params![channel_id, handle],
        )
        .map_err(|e| ToolError::ExecutionFailed(format!("delete channel contact: {e}")))?;
    if count == 0 {
        return Err(ToolError::NotFound("contact not configured".into()));
    }
    Ok(json!({
        "success": true,
        "action": "remove",
        "channel_id": channel_id,
        "handle": handle,
    })
    .to_string())
}

fn resolve_contact(input: &Value) -> Result<String, ToolError> {
    let channel_id = parse_channel_id(input, true)?.unwrap_or_default();
    let handle = parse_handle(input)?;
    let conn = connection()?;
    let mut stmt = conn
        .prepare("SELECT * FROM channel_contacts WHERE channel_id = ?1 AND handle = ?2")
        .map_err(|e| ToolError::ExecutionFailed(format!("prepare resolve channel contact: {e}")))?;
    let mut rows = stmt
        .query_map(params![channel_id, handle], parse_row)
        .map_err(|e| ToolError::ExecutionFailed(format!("query resolve channel contact: {e}")))?;
    if let Some(row) = rows.next() {
        let contact =
            row.map_err(|e| ToolError::ExecutionFailed(format!("parse contact row: {e}")))?;
        return Ok(json!({
            "action": "resolve",
            "configured": true,
            "allowed": contact.allowed,
            "auto_reply": contact.auto_reply,
            "auto_approve": contact.auto_approve,
            "contact": contact_to_json(&contact),
        })
        .to_string());
    }
    Ok(json!({
        "action": "resolve",
        "channel_id": channel_id,
        "handle": handle,
        "configured": false,
        "allowed": false,
        "auto_reply": false,
        "note": "sender not configured — driver should fall back to the channel default route",
    })
    .to_string())
}

fn record_message(input: &Value) -> Result<String, ToolError> {
    let channel_id = parse_channel_id(input, true)?.unwrap_or_default();
    let handle = parse_handle(input)?;
    let now = Utc::now();
    let conn = connection()?;
    let count = conn
        .execute(
            "UPDATE channel_contacts
             SET last_message = ?1, updated_at = ?1
             WHERE channel_id = ?2 AND handle = ?3",
            params![now.to_rfc3339(), channel_id, handle],
        )
        .map_err(|e| {
            ToolError::ExecutionFailed(format!("update channel contact last_message: {e}"))
        })?;
    if count == 0 {
        return Err(ToolError::NotFound("contact not configured".into()));
    }
    Ok(json!({
        "success": true,
        "action": "record_message",
        "channel_id": channel_id,
        "handle": handle,
        "last_message": now.to_rfc3339(),
    })
    .to_string())
}

pub fn channel_contacts_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "channel_contacts".to_string(),
        description: "Configure per-sender routing for non-iMessage channels in the shared relay control plane. \
            Each sender handle is scoped to a channel_id (telegram, slack, discord, whatsapp, signal, email) \
            and maps to a model, tool tier, prompt mode, and allowlist/auto-reply flags. Actions: list, get, \
            set/upsert, remove, resolve, record_message."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["list", "get", "set", "upsert", "remove", "delete", "resolve", "record_message"],
                    "default": "list"
                },
                "channel_id": {
                    "type": "string",
                    "enum": ["telegram", "slack", "discord", "whatsapp", "signal", "email"],
                    "description": "Channel namespace for this sender route."
                },
                "handle": { "type": "string", "description": "Sender handle, username, phone number, or address." },
                "display_name": { "type": "string" },
                "model": { "type": "string", "description": "Model id like 'qwen-4b' or 'claude-sonnet-4-6'." },
                "tool_tier": {
                    "type": "string",
                    "enum": ["none", "chat_lite", "chat_pro", "agent", "full"],
                    "default": "chat_pro"
                },
                "prompt_mode": {
                    "type": "string",
                    "enum": ["general", "code", "research"],
                    "default": "general"
                },
                "allowed": { "type": "boolean", "default": true },
                "auto_reply": { "type": "boolean", "default": true },
                "auto_approve": {
                    "type": "boolean",
                    "default": false,
                    "description": "Auto-approve Modification tools for this sender route. Leave false unless fully trusted."
                },
                "notes": { "type": "string" },
                "allowed_only": { "type": "boolean", "description": "For list action — only return allowed senders." }
            },
            "required": ["action"]
        }),
    }
}

#[cfg(test)]
mod tests {
    // Test-isolation gate held across `.await` is intentional — see
    // `resources/bridge.rs::tests` for the canonical rationale.
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
                "EPISTEMOS_CHANNEL_CONTACTS_DB",
                dir.path().join("channel_contacts.db"),
            );
            Self { _dir: dir }
        }
    }

    impl Drop for TempDb {
        fn drop(&mut self) {
            std::env::remove_var("EPISTEMOS_CHANNEL_CONTACTS_DB");
        }
    }

    #[tokio::test]
    async fn set_and_resolve_roundtrip() {
        let _gate = lock_tests();
        let _db = TempDb::new();
        let handler = ChannelContactsHandler;

        let set_result = handler
            .execute(&json!({
                "action": "set",
                "channel_id": "telegram",
                "handle": "alice",
                "display_name": "Alice",
                "model": "claude-sonnet-4-6",
                "tool_tier": "agent",
                "prompt_mode": "research",
                "allowed": true,
                "auto_reply": true,
                "auto_approve": true,
                "notes": "VIP"
            }))
            .await
            .unwrap();
        let set_json: Value = serde_json::from_str(&set_result).unwrap();
        assert_eq!(set_json["contact"]["channel_id"], json!("telegram"));

        let resolve_result = handler
            .execute(&json!({
                "action": "resolve",
                "channel_id": "telegram",
                "handle": "alice"
            }))
            .await
            .unwrap();
        let resolve_json: Value = serde_json::from_str(&resolve_result).unwrap();
        assert_eq!(resolve_json["configured"], json!(true));
        assert_eq!(resolve_json["contact"]["display_name"], json!("Alice"));
        assert_eq!(resolve_json["contact"]["prompt_mode"], json!("research"));
    }

    #[tokio::test]
    async fn channel_scoping_keeps_routes_isolated() {
        let _gate = lock_tests();
        let _db = TempDb::new();
        let handler = ChannelContactsHandler;

        handler
            .execute(&json!({
                "action": "set",
                "channel_id": "telegram",
                "handle": "alice",
                "model": "qwen-4b"
            }))
            .await
            .unwrap();
        handler
            .execute(&json!({
                "action": "set",
                "channel_id": "signal",
                "handle": "alice",
                "model": "claude-sonnet-4-6"
            }))
            .await
            .unwrap();

        let telegram_list = handler
            .execute(&json!({
                "action": "list",
                "channel_id": "telegram"
            }))
            .await
            .unwrap();
        let telegram_json: Value = serde_json::from_str(&telegram_list).unwrap();
        assert_eq!(telegram_json["count"], json!(1));
        assert_eq!(telegram_json["contacts"][0]["model"], json!("qwen-4b"));

        let signal_resolve = handler
            .execute(&json!({
                "action": "resolve",
                "channel_id": "signal",
                "handle": "alice"
            }))
            .await
            .unwrap();
        let signal_json: Value = serde_json::from_str(&signal_resolve).unwrap();
        assert_eq!(signal_json["contact"]["model"], json!("claude-sonnet-4-6"));
    }
}
