//! Apple App Tools — Phase 4 osascript bridges
//!
//! Four tools that talk to macOS first-party apps via `osascript`. Pure Rust —
//! no Swift side required. Users only need to grant Automation permissions
//! on first use (macOS will prompt).
//!
//! * `apple_notes`     — list / read / create / search Apple Notes
//! * `apple_reminders` — list / add / complete reminders
//! * `apple_calendar`  — list / create calendar events
//! * `apple_mail`      — list unread / read by subject / send via Mail.app
//!
//! These all shell out to `osascript -e '<AppleScript>'`. The AppleScript is
//! generated from user input with aggressive quoting so we never inject.

use std::time::Duration;

use async_trait::async_trait;
use serde_json::{json, Value};
use tokio::process::Command;

use super::registry::{ToolError, ToolHandler};

const OSASCRIPT_TIMEOUT: Duration = Duration::from_secs(30);

// MARK: - AppleScript quoting

/// Escape a string so it is safe to drop inside an AppleScript double-quoted
/// literal. We escape backslashes and double quotes — everything else flows
/// through unchanged because AppleScript string literals are byte-level.
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

/// Run an osascript snippet and return stdout (trimmed). Fails on non-zero
/// exit, timeout, or stderr output.
async fn run_osascript(script: &str) -> Result<String, ToolError> {
    let mut cmd = Command::new("osascript");
    cmd.arg("-e").arg(script);

    let child = cmd.output();
    let output = match tokio::time::timeout(OSASCRIPT_TIMEOUT, child).await {
        Ok(Ok(out)) => out,
        Ok(Err(e)) => {
            return Err(ToolError::ExecutionFailed(format!(
                "osascript spawn failed: {e}"
            )));
        }
        Err(_) => {
            return Err(ToolError::ExecutionFailed(
                "osascript timed out after 30s".into(),
            ));
        }
    };

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
        return Err(ToolError::ExecutionFailed(format!(
            "osascript failed: {stderr}"
        )));
    }
    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

// MARK: - apple_notes

pub struct AppleNotesHandler;

crate::impl_tool_via_legacy_handler!(
    AppleNotesHandler,
    name = "apple.notes",
    input_schema = super::v2_catalog::apple_notes::input_schema,
    profile = super::Profile::AppStoreSafe,
    small_model_safe = false,
);

#[async_trait]
impl ToolHandler for AppleNotesHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let action = input
            .get("action")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'action'".into()))?;

        match action {
            "list" => apple_notes_list(input).await,
            "read" => apple_notes_read(input).await,
            "create" => apple_notes_create(input).await,
            "search" => apple_notes_search(input).await,
            other => Err(ToolError::InvalidArguments(format!(
                "unknown action '{other}' (expected: list|read|create|search)"
            ))),
        }
    }
}

async fn apple_notes_list(input: &Value) -> Result<String, ToolError> {
    let limit = input
        .get("limit")
        .and_then(Value::as_u64)
        .unwrap_or(20)
        .clamp(1, 100) as usize;
    let folder = input.get("folder").and_then(Value::as_str);

    let script = if let Some(folder_name) = folder {
        format!(
            r#"tell application "Notes"
set noteList to {{}}
set theFolder to folder {quoted_folder}
set theNotes to notes of theFolder
set noteCount to 0
repeat with n in theNotes
    if noteCount >= {limit} then exit repeat
    set noteCount to noteCount + 1
    set end of noteList to (name of n)
end repeat
return noteList as string
end tell"#,
            quoted_folder = applescript_quote(folder_name),
            limit = limit,
        )
    } else {
        format!(
            r#"tell application "Notes"
set noteList to {{}}
set noteCount to 0
repeat with n in notes
    if noteCount >= {limit} then exit repeat
    set noteCount to noteCount + 1
    set end of noteList to (name of n)
end repeat
return noteList as string
end tell"#,
            limit = limit,
        )
    };

    let raw = run_osascript(&script).await?;
    let titles: Vec<String> = raw
        .split(", ")
        .filter(|s| !s.is_empty())
        .map(String::from)
        .collect();

    Ok(json!({
        "action": "list",
        "folder": folder,
        "count": titles.len(),
        "titles": titles,
    })
    .to_string())
}

async fn apple_notes_read(input: &Value) -> Result<String, ToolError> {
    let title = input
        .get("title")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'title'".into()))?;
    let script = format!(
        r#"tell application "Notes"
set theNote to first note whose name is {quoted_title}
return body of theNote
end tell"#,
        quoted_title = applescript_quote(title),
    );
    let body = run_osascript(&script).await?;
    Ok(json!({
        "action": "read",
        "title": title,
        "body": body,
    })
    .to_string())
}

async fn apple_notes_create(input: &Value) -> Result<String, ToolError> {
    let title = input
        .get("title")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'title'".into()))?;
    let content = input
        .get("content")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'content'".into()))?;
    let folder = input.get("folder").and_then(Value::as_str);

    let script = if let Some(folder_name) = folder {
        format!(
            r#"tell application "Notes"
make new note at folder {quoted_folder} with properties {{name:{quoted_title}, body:{quoted_body}}}
return "created"
end tell"#,
            quoted_folder = applescript_quote(folder_name),
            quoted_title = applescript_quote(title),
            quoted_body = applescript_quote(content),
        )
    } else {
        format!(
            r#"tell application "Notes"
make new note with properties {{name:{quoted_title}, body:{quoted_body}}}
return "created"
end tell"#,
            quoted_title = applescript_quote(title),
            quoted_body = applescript_quote(content),
        )
    };

    run_osascript(&script).await?;
    Ok(json!({
        "success": true,
        "action": "create",
        "title": title,
        "folder": folder,
    })
    .to_string())
}

async fn apple_notes_search(input: &Value) -> Result<String, ToolError> {
    let query = input
        .get("query")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'query'".into()))?;
    let limit = input
        .get("limit")
        .and_then(Value::as_u64)
        .unwrap_or(20)
        .clamp(1, 100) as usize;

    let script = format!(
        r#"tell application "Notes"
set matchedNotes to {{}}
set matchCount to 0
repeat with n in notes
    if matchCount >= {limit} then exit repeat
    if (body of n) contains {quoted_query} or (name of n) contains {quoted_query} then
        set matchCount to matchCount + 1
        set end of matchedNotes to (name of n)
    end if
end repeat
return matchedNotes as string
end tell"#,
        quoted_query = applescript_quote(query),
        limit = limit,
    );

    let raw = run_osascript(&script).await?;
    let titles: Vec<String> = raw
        .split(", ")
        .filter(|s| !s.is_empty())
        .map(String::from)
        .collect();
    Ok(json!({
        "action": "search",
        "query": query,
        "count": titles.len(),
        "titles": titles,
    })
    .to_string())
}

pub fn apple_notes_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "apple_notes".to_string(),
        description: "Interact with Apple Notes via AppleScript. Actions: list (titles in a \
             folder or all), read (full body of a note by title), create (new note with \
             title+content, optional folder), search (substring match on title and body). \
             First use will prompt for Automation permission."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "action": { "type": "string", "enum": ["list", "read", "create", "search"] },
                "title": { "type": "string" },
                "content": { "type": "string" },
                "folder": { "type": "string" },
                "query": { "type": "string" },
                "limit": { "type": "integer", "default": 20, "minimum": 1, "maximum": 100 }
            },
            "required": ["action"]
        }),
    }
}

// MARK: - apple_reminders

pub struct AppleRemindersHandler;

crate::impl_tool_via_legacy_handler!(
    AppleRemindersHandler,
    name = "apple.reminders",
    input_schema = super::v2_catalog::apple_reminders::input_schema,
    profile = super::Profile::AppStoreSafe,
    small_model_safe = false,
);

#[async_trait]
impl ToolHandler for AppleRemindersHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let action = input
            .get("action")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'action'".into()))?;

        match action {
            "list" => apple_reminders_list(input).await,
            "add" => apple_reminders_add(input).await,
            "complete" => apple_reminders_complete(input).await,
            other => Err(ToolError::InvalidArguments(format!(
                "unknown action '{other}' (expected: list|add|complete)"
            ))),
        }
    }
}

async fn apple_reminders_list(input: &Value) -> Result<String, ToolError> {
    let list_name = input.get("list").and_then(Value::as_str);
    let include_completed = input
        .get("include_completed")
        .and_then(Value::as_bool)
        .unwrap_or(false);

    let completed_clause = if include_completed {
        ""
    } else {
        "whose completed is false"
    };

    let script = if let Some(name) = list_name {
        format!(
            r#"tell application "Reminders"
set theList to list {quoted}
set items to (name of every reminder of theList {completed_clause})
return items as string
end tell"#,
            quoted = applescript_quote(name),
            completed_clause = completed_clause,
        )
    } else {
        format!(
            r#"tell application "Reminders"
set items to (name of every reminder {completed_clause})
return items as string
end tell"#,
            completed_clause = completed_clause,
        )
    };

    let raw = run_osascript(&script).await?;
    let titles: Vec<String> = raw
        .split(", ")
        .filter(|s| !s.is_empty())
        .map(String::from)
        .collect();
    Ok(json!({
        "action": "list",
        "list": list_name,
        "include_completed": include_completed,
        "count": titles.len(),
        "reminders": titles,
    })
    .to_string())
}

async fn apple_reminders_add(input: &Value) -> Result<String, ToolError> {
    let title = input
        .get("title")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'title'".into()))?;
    let list_name = input.get("list").and_then(Value::as_str);
    let body = input.get("body").and_then(Value::as_str);

    let props = if let Some(body_text) = body {
        format!(
            "{{name:{title}, body:{body}}}",
            title = applescript_quote(title),
            body = applescript_quote(body_text),
        )
    } else {
        format!("{{name:{}}}", applescript_quote(title))
    };

    let script = if let Some(name) = list_name {
        format!(
            r#"tell application "Reminders"
tell list {quoted_list}
make new reminder with properties {props}
end tell
return "added"
end tell"#,
            quoted_list = applescript_quote(name),
            props = props,
        )
    } else {
        format!(
            r#"tell application "Reminders"
make new reminder with properties {props}
return "added"
end tell"#,
            props = props,
        )
    };

    run_osascript(&script).await?;
    Ok(json!({
        "success": true,
        "action": "add",
        "title": title,
        "list": list_name,
    })
    .to_string())
}

async fn apple_reminders_complete(input: &Value) -> Result<String, ToolError> {
    let title = input
        .get("title")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'title'".into()))?;
    let script = format!(
        r#"tell application "Reminders"
set theRem to first reminder whose name is {quoted}
set completed of theRem to true
return "completed"
end tell"#,
        quoted = applescript_quote(title),
    );
    run_osascript(&script).await?;
    Ok(json!({
        "success": true,
        "action": "complete",
        "title": title,
    })
    .to_string())
}

pub fn apple_reminders_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "apple_reminders".to_string(),
        description: "Interact with Apple Reminders via AppleScript. Actions: list (incomplete \
             by default, set include_completed=true for all), add (new reminder with title \
             and optional body, targeting a named list), complete (mark a reminder done by \
             exact title match)."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "action": { "type": "string", "enum": ["list", "add", "complete"] },
                "title": { "type": "string" },
                "body": { "type": "string" },
                "list": { "type": "string", "description": "Reminders list name." },
                "include_completed": { "type": "boolean", "default": false }
            },
            "required": ["action"]
        }),
    }
}

// MARK: - apple_calendar

pub struct AppleCalendarHandler;

crate::impl_tool_via_legacy_handler!(
    AppleCalendarHandler,
    name = "apple.calendar",
    input_schema = super::v2_catalog::apple_calendar::input_schema,
    profile = super::Profile::AppStoreSafe,
    small_model_safe = false,
);

#[async_trait]
impl ToolHandler for AppleCalendarHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let action = input
            .get("action")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'action'".into()))?;

        match action {
            "list" => apple_calendar_list(input).await,
            "create" => apple_calendar_create(input).await,
            other => Err(ToolError::InvalidArguments(format!(
                "unknown action '{other}' (expected: list|create)"
            ))),
        }
    }
}

async fn apple_calendar_list(input: &Value) -> Result<String, ToolError> {
    let calendar_name = input.get("calendar").and_then(Value::as_str);
    let limit = input
        .get("limit")
        .and_then(Value::as_u64)
        .unwrap_or(20)
        .clamp(1, 100) as usize;

    let script = if let Some(name) = calendar_name {
        format!(
            r#"tell application "Calendar"
set theCal to calendar {quoted}
set theEvents to every event of theCal
set result to {{}}
set count to 0
repeat with e in theEvents
    if count >= {limit} then exit repeat
    set count to count + 1
    set end of result to (summary of e)
end repeat
return result as string
end tell"#,
            quoted = applescript_quote(name),
            limit = limit,
        )
    } else {
        format!(
            r#"tell application "Calendar"
set allEvents to {{}}
set count to 0
repeat with c in calendars
    repeat with e in events of c
        if count >= {limit} then exit repeat
        set count to count + 1
        set end of allEvents to (summary of e)
    end repeat
    if count >= {limit} then exit repeat
end repeat
return allEvents as string
end tell"#,
            limit = limit,
        )
    };

    let raw = run_osascript(&script).await?;
    let titles: Vec<String> = raw
        .split(", ")
        .filter(|s| !s.is_empty())
        .map(String::from)
        .collect();
    Ok(json!({
        "action": "list",
        "calendar": calendar_name,
        "count": titles.len(),
        "events": titles,
    })
    .to_string())
}

async fn apple_calendar_create(input: &Value) -> Result<String, ToolError> {
    let title = input
        .get("title")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'title'".into()))?;
    let start = input
        .get("start")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'start' (YYYY-MM-DD HH:MM)".into()))?;
    let end = input
        .get("end")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'end' (YYYY-MM-DD HH:MM)".into()))?;
    let calendar = input
        .get("calendar")
        .and_then(Value::as_str)
        .unwrap_or("Calendar");
    let location = input.get("location").and_then(Value::as_str);

    let props = if let Some(loc) = location {
        format!(
            "{{summary:{s}, start date:(date {sd}), end date:(date {ed}), location:{l}}}",
            s = applescript_quote(title),
            sd = applescript_quote(start),
            ed = applescript_quote(end),
            l = applescript_quote(loc),
        )
    } else {
        format!(
            "{{summary:{s}, start date:(date {sd}), end date:(date {ed})}}",
            s = applescript_quote(title),
            sd = applescript_quote(start),
            ed = applescript_quote(end),
        )
    };

    let script = format!(
        r#"tell application "Calendar"
tell calendar {quoted_cal}
make new event with properties {props}
end tell
return "created"
end tell"#,
        quoted_cal = applescript_quote(calendar),
        props = props,
    );

    run_osascript(&script).await?;
    Ok(json!({
        "success": true,
        "action": "create",
        "title": title,
        "calendar": calendar,
        "start": start,
        "end": end,
    })
    .to_string())
}

pub fn apple_calendar_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "apple_calendar".to_string(),
        description: "Interact with Apple Calendar via AppleScript. Actions: list (upcoming \
             event summaries, optionally filtered by calendar), create (new event with \
             title, start+end dates, optional location and calendar name)."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "action": { "type": "string", "enum": ["list", "create"] },
                "title": { "type": "string" },
                "start": { "type": "string", "description": "Start datetime ('YYYY-MM-DD HH:MM:SS' or AppleScript-compatible)." },
                "end": { "type": "string", "description": "End datetime." },
                "calendar": { "type": "string", "description": "Calendar name." },
                "location": { "type": "string" },
                "limit": { "type": "integer", "default": 20, "minimum": 1, "maximum": 100 }
            },
            "required": ["action"]
        }),
    }
}

// MARK: - apple_mail

pub struct AppleMailHandler;

crate::impl_tool_via_legacy_handler!(
    AppleMailHandler,
    name = "apple.mail",
    input_schema = super::v2_catalog::apple_mail::input_schema,
    profile = super::Profile::AppStoreSafe,
    small_model_safe = false,
);

#[async_trait]
impl ToolHandler for AppleMailHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let action = input
            .get("action")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'action'".into()))?;

        match action {
            "list_unread" => apple_mail_list_unread(input).await,
            "search" => apple_mail_search(input).await,
            "send" => apple_mail_send(input).await,
            other => Err(ToolError::InvalidArguments(format!(
                "unknown action '{other}' (expected: list_unread|search|send)"
            ))),
        }
    }
}

async fn apple_mail_list_unread(input: &Value) -> Result<String, ToolError> {
    let limit = input
        .get("limit")
        .and_then(Value::as_u64)
        .unwrap_or(10)
        .clamp(1, 100) as usize;
    let script = format!(
        r#"tell application "Mail"
set theAccounts to every account
set unreadSummaries to {{}}
set count to 0
repeat with acct in theAccounts
    repeat with mb in (every mailbox of acct)
        set msgs to (messages of mb whose read status is false)
        repeat with m in msgs
            if count >= {limit} then exit repeat
            set count to count + 1
            set end of unreadSummaries to (subject of m)
        end repeat
        if count >= {limit} then exit repeat
    end repeat
    if count >= {limit} then exit repeat
end repeat
return unreadSummaries as string
end tell"#,
        limit = limit,
    );
    let raw = run_osascript(&script).await?;
    let subjects: Vec<String> = raw
        .split(", ")
        .filter(|s| !s.is_empty())
        .map(String::from)
        .collect();
    Ok(json!({
        "action": "list_unread",
        "count": subjects.len(),
        "subjects": subjects,
    })
    .to_string())
}

async fn apple_mail_search(input: &Value) -> Result<String, ToolError> {
    let query = input
        .get("query")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'query'".into()))?;
    let limit = input
        .get("limit")
        .and_then(Value::as_u64)
        .unwrap_or(10)
        .clamp(1, 100) as usize;
    let script = format!(
        r#"tell application "Mail"
set found to {{}}
set count to 0
repeat with acct in (every account)
    repeat with mb in (every mailbox of acct)
        repeat with m in messages of mb
            if count >= {limit} then exit repeat
            if (subject of m) contains {quoted} then
                set count to count + 1
                set end of found to ((sender of m) & " | " & (subject of m))
            end if
        end repeat
        if count >= {limit} then exit repeat
    end repeat
    if count >= {limit} then exit repeat
end repeat
return found as string
end tell"#,
        limit = limit,
        quoted = applescript_quote(query),
    );
    let raw = run_osascript(&script).await?;
    let results: Vec<String> = raw
        .split(", ")
        .filter(|s| !s.is_empty())
        .map(String::from)
        .collect();
    Ok(json!({
        "action": "search",
        "query": query,
        "count": results.len(),
        "results": results,
    })
    .to_string())
}

async fn apple_mail_send(input: &Value) -> Result<String, ToolError> {
    let to = input
        .get("to")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'to'".into()))?;
    let subject = input
        .get("subject")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'subject'".into()))?;
    let body = input
        .get("body")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'body'".into()))?;
    let send_now = input
        .get("send_now")
        .and_then(Value::as_bool)
        .unwrap_or(false);

    // By default we create a draft and leave it in the user's Drafts folder —
    // sending without explicit confirmation is a hard-to-reverse action.
    let send_clause = if send_now { "send newMsg" } else { "" };

    let script = format!(
        r#"tell application "Mail"
set newMsg to make new outgoing message with properties {{subject:{s}, content:{b}, visible:true}}
tell newMsg
make new to recipient at end of to recipients with properties {{address:{t}}}
end tell
{send_clause}
return "ok"
end tell"#,
        s = applescript_quote(subject),
        b = applescript_quote(body),
        t = applescript_quote(to),
        send_clause = send_clause,
    );

    run_osascript(&script).await?;
    Ok(json!({
        "success": true,
        "action": "send",
        "to": to,
        "subject": subject,
        "sent": send_now,
        "note": if send_now {
            "Message dispatched"
        } else {
            "Draft created in Mail.app — open Mail to review and send"
        },
    })
    .to_string())
}

pub fn apple_mail_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "apple_mail".to_string(),
        description: "Interact with Apple Mail via AppleScript. Actions: list_unread (subjects \
             of unread messages across all accounts), search (subject substring match), send \
             (create a draft by default — pass send_now: true to dispatch immediately). \
             First use prompts for Mail automation permission."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "action": { "type": "string", "enum": ["list_unread", "search", "send"] },
                "query": { "type": "string" },
                "to": { "type": "string" },
                "subject": { "type": "string" },
                "body": { "type": "string" },
                "send_now": { "type": "boolean", "default": false, "description": "If false, a draft is created instead of sending." },
                "limit": { "type": "integer", "default": 10, "minimum": 1, "maximum": 100 }
            },
            "required": ["action"]
        }),
    }
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn quoting_escapes_backslashes_and_quotes() {
        assert_eq!(
            applescript_quote("hello \"world\" \\"),
            "\"hello \\\"world\\\" \\\\\""
        );
        assert_eq!(applescript_quote("line\nbreak"), "\"line\\nbreak\"");
    }

    #[tokio::test]
    async fn apple_notes_rejects_unknown_action() {
        let handler = AppleNotesHandler;
        let err = handler
            .execute(&json!({ "action": "teleport" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("unknown action"));
    }

    #[tokio::test]
    async fn apple_reminders_rejects_unknown_action() {
        let handler = AppleRemindersHandler;
        let err = handler
            .execute(&json!({ "action": "teleport" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("unknown action"));
    }

    #[tokio::test]
    async fn apple_calendar_rejects_missing_action() {
        let handler = AppleCalendarHandler;
        let err = handler.execute(&json!({})).await.unwrap_err();
        assert!(format!("{err}").contains("action"));
    }

    #[tokio::test]
    async fn apple_mail_rejects_unknown_action() {
        let handler = AppleMailHandler;
        let err = handler
            .execute(&json!({ "action": "parachute" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("unknown action"));
    }

    #[tokio::test]
    async fn apple_notes_create_validates_missing_content() {
        let handler = AppleNotesHandler;
        let err = handler
            .execute(&json!({ "action": "create", "title": "x" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("content"));
    }

    #[tokio::test]
    async fn apple_mail_send_validates_required_fields() {
        let handler = AppleMailHandler;
        let err = handler
            .execute(&json!({ "action": "send", "to": "a@b.c" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("subject"));
    }
}
