//! iMessage Tool — Phase 6 Primary Agent Channel
//!
//! The user wants iMessage to be the main driver for the agent, so this tool
//! is treated as a first-class communication channel rather than a generic
//! messenger. It supports both directions:
//!
//! * Read path — SQLite reads against `~/Library/Messages/chat.db` (requires
//!   Full Disk Access). Actions: list_chats, read_chat, recent, unread, search.
//! * Write path — AppleScript `tell application "Messages"` subprocess
//!   (requires Automation permission). Actions: send.
//!
//! Everything is pure Rust — no Swift FFI required. The SQLite reads go
//! through `rusqlite` which is already a project dep; writes shell out to
//! `osascript` exactly like `apple_mail`/`apple_notes`.

use std::path::PathBuf;
use std::time::Duration;

use async_trait::async_trait;
use rusqlite::{params, Connection, OpenFlags};
use serde_json::{json, Value};
use tokio::process::Command;

use super::registry::{ToolError, ToolHandler};

const OSASCRIPT_TIMEOUT: Duration = Duration::from_secs(30);
const MAX_OSASCRIPT_OUTPUT_BYTES: usize = 512 * 1024;
const MAX_MESSAGE_LEN: usize = 8_192;
const DEFAULT_LIMIT: usize = 25;

// MARK: - Helpers

fn chat_db_path() -> PathBuf {
    // Allow override for tests.
    if let Ok(p) = std::env::var("EPISTEMOS_IMESSAGE_DB") {
        return PathBuf::from(p);
    }
    dirs::home_dir()
        .map(|h| h.join("Library/Messages/chat.db"))
        .unwrap_or_else(|| PathBuf::from("chat.db"))
}

fn open_chat_db() -> Result<Connection, ToolError> {
    let path = chat_db_path();
    if !path.exists() {
        return Err(ToolError::ExecutionFailed(format!(
            "chat.db not found at '{}'. Grant Full Disk Access to Epistemos in \
             System Settings → Privacy & Security.",
            path.display()
        )));
    }
    // Open read-only so we never accidentally mutate Messages' private state.
    Connection::open_with_flags(
        &path,
        OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_URI,
    )
    .map_err(|e| ToolError::ExecutionFailed(format!("open chat.db: {e}")))
}

/// Apple stores message timestamps as nanoseconds since 2001-01-01 UTC.
/// Convert to a unix epoch (seconds) for downstream consumers.
fn apple_timestamp_to_unix(raw: i64) -> i64 {
    // Apple epoch = 2001-01-01T00:00:00Z = unix 978307200.
    // `raw` can be seconds (pre-macOS Sierra) or nanoseconds (post).
    // If it's > 1e12 we assume nanoseconds; otherwise seconds.
    let seconds_since_apple_epoch = if raw > 1_000_000_000_000 {
        raw / 1_000_000_000
    } else {
        raw
    };
    978_307_200 + seconds_since_apple_epoch
}

/// AppleScript-safe quoting: escape backslashes, double-quotes, and line
/// terminators. Same rules as `tools::apple::applescript_quote`.
fn applescript_quote(value: &str) -> String {
    let mut out = String::with_capacity(value.len() + 2);
    out.push('"');
    for ch in value.chars() {
        match ch {
            '\\' => out.push_str("\\\\"),
            '"' => out.push_str("\\\""),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            _ => out.push(ch),
        }
    }
    out.push('"');
    out
}

async fn run_osascript(script: &str) -> Result<String, ToolError> {
    let mut cmd = Command::new("osascript");
    // Apply doctrine subprocess hardening (env_clear + allowlist +
    // kill_on_drop + process_group). iMessage / contact-resolution
    // AppleScript runs against system frameworks; defense in depth
    // says: still don't leak DYLD_INSERT_LIBRARIES into the child.
    crate::security::harden_cli_subprocess(&mut cmd);
    cmd.arg("-e").arg(script);
    let child = cmd.output();
    let output = match tokio::time::timeout(OSASCRIPT_TIMEOUT, child).await {
        Ok(Ok(out)) => out,
        Ok(Err(e)) => {
            return Err(ToolError::ExecutionFailed(format!("osascript spawn: {e}")));
        }
        Err(_) => {
            return Err(ToolError::ExecutionFailed(
                "osascript timed out after 30s".into(),
            ));
        }
    };
    if !output.status.success() {
        let stderr = decode_limited_output(&output.stderr, "stderr");
        let exit_code = output.status.code().unwrap_or(-1);
        return Err(ToolError::ExecutionFailed(format!(
            "osascript failed: {}",
            describe_osascript_failure(&stderr, exit_code)
        )));
    }
    Ok(decode_limited_output(&output.stdout, "stdout")
        .trim()
        .to_string())
}

fn decode_limited_output(bytes: &[u8], stream: &str) -> String {
    let capped = bytes.len() > MAX_OSASCRIPT_OUTPUT_BYTES;
    let slice = &bytes[..bytes.len().min(MAX_OSASCRIPT_OUTPUT_BYTES)];
    let mut text = String::from_utf8_lossy(slice).into_owned();
    if capped {
        text.push_str(&format!(
            "\n... [{stream} truncated at {MAX_OSASCRIPT_OUTPUT_BYTES} bytes]"
        ));
    }
    text
}

fn describe_osascript_failure(stderr: &str, exit_code: i32) -> String {
    let lower = stderr.to_ascii_lowercase();
    if exit_code == 1743
        || lower.contains("not authorized")
        || lower.contains("not authorised")
        || lower.contains("not permitted")
        || lower.contains("automation")
        || lower.contains("tccd")
    {
        return "Messages automation permission denied; grant Automation permission for Epistemos/System Events in System Settings".into();
    }
    if lower.contains("can't get buddy")
        || lower.contains("can’t get buddy")
        || (lower.contains("buddy") && lower.contains("can't get"))
    {
        return "recipient could not be resolved in Messages for the selected service".into();
    }
    if lower.contains("application isn't running")
        || lower.contains("application is not running")
        || lower.contains("messages got an error")
    {
        return format!(
            "Messages returned an AppleScript error (exit code {exit_code}; stderr redacted)"
        );
    }
    if stderr.trim().is_empty() {
        return format!("Messages AppleScript exited with code {exit_code} and no stderr");
    }
    format!("Messages AppleScript failed (exit code {exit_code}; stderr redacted)")
}

// MARK: - Handler

pub struct IMessageHandler;

#[async_trait]
impl ToolHandler for IMessageHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let action = input
            .get("action")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'action'".into()))?;

        match action {
            "send" => imessage_send(input).await,
            "list_chats" => imessage_list_chats(input),
            "read_chat" => imessage_read_chat(input),
            "recent" => imessage_recent(input),
            "unread" => imessage_unread(input),
            "search" => imessage_search(input),
            other => Err(ToolError::InvalidArguments(format!(
                "unknown action '{other}' (expected: send|list_chats|read_chat|recent|unread|search)"
            ))),
        }
    }
}

// MARK: - Write path (send)

async fn imessage_send(input: &Value) -> Result<String, ToolError> {
    let to = input.get("to").and_then(Value::as_str).ok_or_else(|| {
        ToolError::InvalidArguments("missing 'to' (phone, email, or handle)".into())
    })?;
    let message = input
        .get("message")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'message'".into()))?;
    if message.is_empty() {
        return Err(ToolError::InvalidArguments(
            "message cannot be empty".into(),
        ));
    }
    if message.len() > MAX_MESSAGE_LEN {
        return Err(ToolError::InvalidArguments(format!(
            "message exceeds {MAX_MESSAGE_LEN} char cap"
        )));
    }
    let service = input
        .get("service")
        .and_then(Value::as_str)
        .unwrap_or("iMessage");
    if !matches!(service, "iMessage" | "SMS") {
        return Err(ToolError::InvalidArguments(format!(
            "service '{service}' invalid (expected iMessage|SMS)"
        )));
    }

    // AppleScript: resolve buddy on the target service, then send.
    let script = format!(
        r#"tell application "Messages"
set targetService to 1st service whose service type = {service_kw}
set targetBuddy to buddy {to_q} of targetService
send {msg_q} to targetBuddy
return "sent"
end tell"#,
        service_kw = if service == "SMS" { "SMS" } else { "iMessage" },
        to_q = applescript_quote(to),
        msg_q = applescript_quote(message),
    );

    run_osascript(&script).await?;

    Ok(json!({
        "success": true,
        "action": "send",
        "to": to,
        "service": service,
        "chars_sent": message.len(),
    })
    .to_string())
}

// MARK: - Read path (SQLite)

fn imessage_list_chats(input: &Value) -> Result<String, ToolError> {
    let limit = input
        .get("limit")
        .and_then(Value::as_u64)
        .unwrap_or(DEFAULT_LIMIT as u64)
        .clamp(1, 500) as usize;

    let conn = open_chat_db()?;
    // Join `chat` with the most-recent message time so we can sort newest-first.
    let mut stmt = conn
        .prepare(
            "SELECT c.ROWID, c.display_name, c.chat_identifier, c.is_archived,
                    COALESCE(MAX(m.date), 0) AS last_date
             FROM chat c
             LEFT JOIN chat_message_join cmj ON cmj.chat_id = c.ROWID
             LEFT JOIN message m ON m.ROWID = cmj.message_id
             GROUP BY c.ROWID
             ORDER BY last_date DESC
             LIMIT ?1",
        )
        .map_err(|e| ToolError::ExecutionFailed(format!("prepare list_chats: {e}")))?;

    let rows = stmt
        .query_map(params![limit as i64], |row| {
            let rowid: i64 = row.get(0)?;
            let display_name: Option<String> = row.get(1)?;
            let chat_identifier: Option<String> = row.get(2)?;
            let is_archived: Option<i64> = row.get(3)?;
            let last_date: i64 = row.get(4)?;
            Ok(json!({
                "chat_id": rowid,
                "display_name": display_name,
                "identifier": chat_identifier,
                "archived": is_archived.unwrap_or(0) != 0,
                "last_activity_unix": apple_timestamp_to_unix(last_date),
            }))
        })
        .map_err(|e| ToolError::ExecutionFailed(format!("query list_chats: {e}")))?;

    let mut chats = Vec::new();
    for row in rows {
        chats.push(row.map_err(|e| ToolError::ExecutionFailed(format!("row parse: {e}")))?);
    }

    Ok(json!({
        "action": "list_chats",
        "count": chats.len(),
        "chats": chats,
    })
    .to_string())
}

fn imessage_read_chat(input: &Value) -> Result<String, ToolError> {
    let chat_id = input
        .get("chat_id")
        .and_then(Value::as_i64)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'chat_id'".into()))?;
    let limit = input
        .get("limit")
        .and_then(Value::as_u64)
        .unwrap_or(50)
        .clamp(1, 500) as usize;

    let conn = open_chat_db()?;
    let mut stmt = conn
        .prepare(
            "SELECT m.ROWID, m.text, m.is_from_me, m.date, h.id AS handle
             FROM message m
             JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
             LEFT JOIN handle h ON h.ROWID = m.handle_id
             WHERE cmj.chat_id = ?1
             ORDER BY m.date DESC
             LIMIT ?2",
        )
        .map_err(|e| ToolError::ExecutionFailed(format!("prepare read_chat: {e}")))?;

    let rows = stmt
        .query_map(params![chat_id, limit as i64], |row| {
            let rowid: i64 = row.get(0)?;
            let text: Option<String> = row.get(1)?;
            let is_from_me: i64 = row.get(2)?;
            let date: i64 = row.get(3)?;
            let handle: Option<String> = row.get(4)?;
            Ok(json!({
                "message_id": rowid,
                "text": text,
                "from_me": is_from_me != 0,
                "unix": apple_timestamp_to_unix(date),
                "handle": handle,
            }))
        })
        .map_err(|e| ToolError::ExecutionFailed(format!("query read_chat: {e}")))?;

    let mut messages = Vec::new();
    for row in rows {
        messages.push(row.map_err(|e| ToolError::ExecutionFailed(format!("row parse: {e}")))?);
    }
    // Reverse so the agent sees oldest→newest within the window.
    messages.reverse();

    Ok(json!({
        "action": "read_chat",
        "chat_id": chat_id,
        "count": messages.len(),
        "messages": messages,
    })
    .to_string())
}

fn imessage_recent(input: &Value) -> Result<String, ToolError> {
    let limit = input
        .get("limit")
        .and_then(Value::as_u64)
        .unwrap_or(DEFAULT_LIMIT as u64)
        .clamp(1, 500) as usize;

    let conn = open_chat_db()?;
    let mut stmt = conn
        .prepare(
            "SELECT m.ROWID, m.text, m.is_from_me, m.date, h.id AS handle, cmj.chat_id
             FROM message m
             JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
             LEFT JOIN handle h ON h.ROWID = m.handle_id
             ORDER BY m.date DESC
             LIMIT ?1",
        )
        .map_err(|e| ToolError::ExecutionFailed(format!("prepare recent: {e}")))?;

    let rows = stmt
        .query_map(params![limit as i64], |row| {
            let rowid: i64 = row.get(0)?;
            let text: Option<String> = row.get(1)?;
            let is_from_me: i64 = row.get(2)?;
            let date: i64 = row.get(3)?;
            let handle: Option<String> = row.get(4)?;
            let chat_id: i64 = row.get(5)?;
            Ok(json!({
                "message_id": rowid,
                "text": text,
                "from_me": is_from_me != 0,
                "unix": apple_timestamp_to_unix(date),
                "handle": handle,
                "chat_id": chat_id,
            }))
        })
        .map_err(|e| ToolError::ExecutionFailed(format!("query recent: {e}")))?;

    let mut messages = Vec::new();
    for row in rows {
        messages.push(row.map_err(|e| ToolError::ExecutionFailed(format!("row parse: {e}")))?);
    }
    Ok(json!({
        "action": "recent",
        "count": messages.len(),
        "messages": messages,
    })
    .to_string())
}

fn imessage_unread(input: &Value) -> Result<String, ToolError> {
    let limit = input
        .get("limit")
        .and_then(Value::as_u64)
        .unwrap_or(DEFAULT_LIMIT as u64)
        .clamp(1, 500) as usize;

    let conn = open_chat_db()?;
    let mut stmt = conn
        .prepare(
            "SELECT m.ROWID, m.text, m.date, h.id AS handle, cmj.chat_id
             FROM message m
             JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
             LEFT JOIN handle h ON h.ROWID = m.handle_id
             WHERE m.is_from_me = 0 AND m.is_read = 0
             ORDER BY m.date DESC
             LIMIT ?1",
        )
        .map_err(|e| ToolError::ExecutionFailed(format!("prepare unread: {e}")))?;

    let rows = stmt
        .query_map(params![limit as i64], |row| {
            let rowid: i64 = row.get(0)?;
            let text: Option<String> = row.get(1)?;
            let date: i64 = row.get(2)?;
            let handle: Option<String> = row.get(3)?;
            let chat_id: i64 = row.get(4)?;
            Ok(json!({
                "message_id": rowid,
                "text": text,
                "unix": apple_timestamp_to_unix(date),
                "handle": handle,
                "chat_id": chat_id,
            }))
        })
        .map_err(|e| ToolError::ExecutionFailed(format!("query unread: {e}")))?;

    let mut messages = Vec::new();
    for row in rows {
        messages.push(row.map_err(|e| ToolError::ExecutionFailed(format!("row parse: {e}")))?);
    }
    Ok(json!({
        "action": "unread",
        "count": messages.len(),
        "messages": messages,
    })
    .to_string())
}

fn imessage_search(input: &Value) -> Result<String, ToolError> {
    let query = input
        .get("query")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'query'".into()))?;
    let limit = input
        .get("limit")
        .and_then(Value::as_u64)
        .unwrap_or(DEFAULT_LIMIT as u64)
        .clamp(1, 500) as usize;

    let conn = open_chat_db()?;
    // Simple LIKE match — Messages' chat.db doesn't have an FTS index we can
    // rely on. For the agent use case this is fine at the scale of personal
    // histories.
    let like_pattern = format!("%{query}%");

    let mut stmt = conn
        .prepare(
            "SELECT m.ROWID, m.text, m.is_from_me, m.date, h.id AS handle, cmj.chat_id
             FROM message m
             JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
             LEFT JOIN handle h ON h.ROWID = m.handle_id
             WHERE m.text LIKE ?1
             ORDER BY m.date DESC
             LIMIT ?2",
        )
        .map_err(|e| ToolError::ExecutionFailed(format!("prepare search: {e}")))?;

    let rows = stmt
        .query_map(params![like_pattern, limit as i64], |row| {
            let rowid: i64 = row.get(0)?;
            let text: Option<String> = row.get(1)?;
            let is_from_me: i64 = row.get(2)?;
            let date: i64 = row.get(3)?;
            let handle: Option<String> = row.get(4)?;
            let chat_id: i64 = row.get(5)?;
            Ok(json!({
                "message_id": rowid,
                "text": text,
                "from_me": is_from_me != 0,
                "unix": apple_timestamp_to_unix(date),
                "handle": handle,
                "chat_id": chat_id,
            }))
        })
        .map_err(|e| ToolError::ExecutionFailed(format!("query search: {e}")))?;

    let mut messages = Vec::new();
    for row in rows {
        messages.push(row.map_err(|e| ToolError::ExecutionFailed(format!("row parse: {e}")))?);
    }
    Ok(json!({
        "action": "search",
        "query": query,
        "count": messages.len(),
        "messages": messages,
    })
    .to_string())
}

// MARK: - Schema

pub fn imessage_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "imessage".to_string(),
        description: "Send and read iMessages from macOS Messages.app. Read actions query \
             ~/Library/Messages/chat.db directly (requires Full Disk Access): list_chats, \
             read_chat (by chat_id from list_chats), recent (newest across all chats), \
             unread (incoming + unread), search (LIKE match on message text). \
             Write action 'send' shells out to AppleScript (requires Automation permission). \
             This tool is intended as the primary agent-user channel."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["send", "list_chats", "read_chat", "recent", "unread", "search"]
                },
                "to": { "type": "string", "description": "Recipient phone, email, or handle (send)." },
                "message": { "type": "string", "description": "Message body (send, max 8,192 chars)." },
                "service": { "type": "string", "enum": ["iMessage", "SMS"], "default": "iMessage" },
                "chat_id": { "type": "integer", "description": "chat.db ROWID from list_chats (read_chat)." },
                "query": { "type": "string", "description": "Substring to search message text (search)." },
                "limit": { "type": "integer", "default": 25, "minimum": 1, "maximum": 500 }
            },
            "required": ["action"]
        }),
    }
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    // Test-isolation gate held across `.await` is intentional — see
    // `resources/bridge.rs::tests` for the canonical rationale.
    // Process-wide iMessage AppleScript state requires serial test
    // execution.
    #![allow(clippy::await_holding_lock)]

    use super::*;
    use serde_json::json;
    use std::sync::MutexGuard;
    use tempfile::TempDir;

    fn lock_tests() -> MutexGuard<'static, ()> {
        use std::sync::{Mutex, OnceLock};
        static GATE: OnceLock<Mutex<()>> = OnceLock::new();
        GATE.get_or_init(|| Mutex::new(()))
            .lock()
            .unwrap_or_else(|poison| poison.into_inner())
    }

    /// Build a skeletal chat.db mirroring the Messages schema and return a
    /// TempDir that must outlive the test. Tests can set EPISTEMOS_IMESSAGE_DB
    /// to point at this temporary database.
    fn build_temp_chat_db() -> (TempDir, PathBuf) {
        let dir = TempDir::new().unwrap();
        let db_path = dir.path().join("chat.db");
        let conn = Connection::open(&db_path).unwrap();
        conn.execute_batch(
            "
            CREATE TABLE chat (
                ROWID INTEGER PRIMARY KEY AUTOINCREMENT,
                display_name TEXT,
                chat_identifier TEXT,
                is_archived INTEGER DEFAULT 0
            );
            CREATE TABLE handle (
                ROWID INTEGER PRIMARY KEY AUTOINCREMENT,
                id TEXT
            );
            CREATE TABLE message (
                ROWID INTEGER PRIMARY KEY AUTOINCREMENT,
                text TEXT,
                is_from_me INTEGER,
                is_read INTEGER DEFAULT 1,
                date INTEGER,
                handle_id INTEGER
            );
            CREATE TABLE chat_message_join (
                chat_id INTEGER,
                message_id INTEGER
            );
            ",
        )
        .unwrap();

        conn.execute(
            "INSERT INTO chat (display_name, chat_identifier) VALUES ('Alice', 'alice@example.com')",
            [],
        )
        .unwrap();
        conn.execute("INSERT INTO handle (id) VALUES ('alice@example.com')", [])
            .unwrap();
        // Two messages — one outbound (read), one inbound (unread).
        conn.execute(
            "INSERT INTO message (text, is_from_me, is_read, date, handle_id) VALUES
                ('hello alice', 1, 1, 100, 1),
                ('hey how are you', 0, 0, 200, 1),
                ('search target token', 0, 1, 150, 1)",
            [],
        )
        .unwrap();
        conn.execute(
            "INSERT INTO chat_message_join (chat_id, message_id) VALUES (1,1),(1,2),(1,3)",
            [],
        )
        .unwrap();
        drop(conn);
        (dir, db_path)
    }

    #[test]
    fn apple_epoch_converts_seconds_and_nanos() {
        // Seconds-form input (pre-Sierra): 10 seconds past apple epoch.
        assert_eq!(apple_timestamp_to_unix(10), 978_307_200 + 10);
        // Nanoseconds-form input (post-Sierra): 5e12 ns = 5,000 seconds past.
        assert_eq!(
            apple_timestamp_to_unix(5_000_000_000_000),
            978_307_200 + 5_000
        );
    }

    #[test]
    fn applescript_quote_escapes_control_chars() {
        assert_eq!(applescript_quote("a\"b\\c"), "\"a\\\"b\\\\c\"");
        assert_eq!(applescript_quote("a\nb"), "\"a\\nb\"");
    }

    #[test]
    fn osascript_output_is_bounded() {
        let bytes = vec![b'x'; MAX_OSASCRIPT_OUTPUT_BYTES + 16];
        let output = decode_limited_output(&bytes, "stdout");
        assert!(output.contains("stdout truncated"));
        assert!(output.len() < MAX_OSASCRIPT_OUTPUT_BYTES + 128);
    }

    #[test]
    fn osascript_failure_redacts_raw_stderr() {
        let message =
            describe_osascript_failure("Messages got an error: cannot send sk-secret-token", 1);
        assert!(message.contains("stderr redacted"));
        assert!(!message.contains("sk-secret-token"));
    }

    #[test]
    fn osascript_failure_classifies_permissions_and_recipients() {
        let permission = describe_osascript_failure("Not authorized to send Apple events", 1743);
        assert!(permission.contains("Automation permission"));

        let recipient = describe_osascript_failure("Messages got an error: Can't get buddy", 1);
        assert!(recipient.contains("recipient could not be resolved"));
    }

    #[tokio::test]
    async fn imessage_list_chats_reads_temp_db() {
        let _gate = lock_tests();
        let (_dir, db_path) = build_temp_chat_db();
        std::env::set_var("EPISTEMOS_IMESSAGE_DB", &db_path);

        let handler = IMessageHandler;
        let result = handler
            .execute(&json!({ "action": "list_chats" }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["count"], json!(1));
        assert_eq!(parsed["chats"][0]["display_name"], json!("Alice"));

        std::env::remove_var("EPISTEMOS_IMESSAGE_DB");
    }

    #[tokio::test]
    async fn imessage_read_chat_returns_ordered_messages() {
        let _gate = lock_tests();
        let (_dir, db_path) = build_temp_chat_db();
        std::env::set_var("EPISTEMOS_IMESSAGE_DB", &db_path);

        let handler = IMessageHandler;
        let result = handler
            .execute(&json!({ "action": "read_chat", "chat_id": 1 }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["count"], json!(3));
        let messages = parsed["messages"].as_array().unwrap();
        // oldest -> newest order after internal reverse.
        assert_eq!(messages[0]["text"], json!("hello alice"));
        assert_eq!(messages[2]["text"], json!("hey how are you"));

        std::env::remove_var("EPISTEMOS_IMESSAGE_DB");
    }

    #[tokio::test]
    async fn imessage_unread_returns_only_incoming_unread() {
        let _gate = lock_tests();
        let (_dir, db_path) = build_temp_chat_db();
        std::env::set_var("EPISTEMOS_IMESSAGE_DB", &db_path);

        let handler = IMessageHandler;
        let result = handler
            .execute(&json!({ "action": "unread" }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["count"], json!(1));
        assert_eq!(parsed["messages"][0]["text"], json!("hey how are you"));

        std::env::remove_var("EPISTEMOS_IMESSAGE_DB");
    }

    #[tokio::test]
    async fn imessage_search_matches_substring() {
        let _gate = lock_tests();
        let (_dir, db_path) = build_temp_chat_db();
        std::env::set_var("EPISTEMOS_IMESSAGE_DB", &db_path);

        let handler = IMessageHandler;
        let result = handler
            .execute(&json!({ "action": "search", "query": "target token" }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["count"], json!(1));
        assert_eq!(parsed["messages"][0]["text"], json!("search target token"));

        std::env::remove_var("EPISTEMOS_IMESSAGE_DB");
    }

    #[tokio::test]
    async fn imessage_recent_lists_newest_first() {
        let _gate = lock_tests();
        let (_dir, db_path) = build_temp_chat_db();
        std::env::set_var("EPISTEMOS_IMESSAGE_DB", &db_path);

        let handler = IMessageHandler;
        let result = handler
            .execute(&json!({ "action": "recent", "limit": 10 }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["count"], json!(3));
        // Newest first: "hey how are you" has date 200, latest.
        assert_eq!(parsed["messages"][0]["text"], json!("hey how are you"));

        std::env::remove_var("EPISTEMOS_IMESSAGE_DB");
    }

    #[tokio::test]
    async fn imessage_send_validates_missing_fields() {
        let handler = IMessageHandler;
        let err = handler
            .execute(&json!({ "action": "send" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("to"));
    }

    #[tokio::test]
    async fn imessage_send_rejects_empty_message() {
        let handler = IMessageHandler;
        let err = handler
            .execute(&json!({
                "action": "send",
                "to": "alice@example.com",
                "message": ""
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("empty"));
    }

    #[tokio::test]
    async fn imessage_send_rejects_oversized_message() {
        let handler = IMessageHandler;
        let huge = "x".repeat(MAX_MESSAGE_LEN + 1);
        let err = handler
            .execute(&json!({
                "action": "send",
                "to": "alice@example.com",
                "message": huge
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("char cap"));
    }

    #[tokio::test]
    async fn imessage_rejects_unknown_action() {
        let handler = IMessageHandler;
        let err = handler
            .execute(&json!({ "action": "fly_pigeon" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("unknown action"));
    }

    #[tokio::test]
    async fn imessage_missing_db_errors_clearly() {
        let _gate = lock_tests();
        std::env::set_var("EPISTEMOS_IMESSAGE_DB", "/nonexistent/path/chat.db");
        let handler = IMessageHandler;
        let err = handler
            .execute(&json!({ "action": "list_chats" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("chat.db"));
        std::env::remove_var("EPISTEMOS_IMESSAGE_DB");
    }
}
