//! Todo Tool — Session-Scoped Task List
//!
//! A structured planning aid for the agent. Todos live in process memory
//! inside a static registry, keyed by the thread owning the registry
//! (effectively global per agent_core session). Each call can replace the
//! whole list or merge incremental updates.
//!
//! Status values follow Hermes/Claude Code conventions:
//!   pending / in_progress / completed / cancelled
//!
//! The tool returns the current list plus a summary count.

use std::sync::{Mutex, OnceLock};

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use super::registry::{ToolError, ToolHandler};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TodoItem {
    pub id: String,
    pub content: String,
    pub active_form: String,
    pub status: String,
}

static TODO_STORE: OnceLock<Mutex<Vec<TodoItem>>> = OnceLock::new();

fn store() -> &'static Mutex<Vec<TodoItem>> {
    TODO_STORE.get_or_init(|| Mutex::new(Vec::new()))
}

pub struct TodoHandler;

#[async_trait]
impl ToolHandler for TodoHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let action = input
            .get("action")
            .and_then(Value::as_str)
            .unwrap_or("list");

        match action {
            "list" => list_todos(),
            "add" => add_todo(input),
            "done" => complete_todo(input),
            "write" => write_todos(input, false),
            "merge" => write_todos(input, true),
            "clear" => clear_todos(),
            other => Err(ToolError::InvalidArguments(format!(
                "unknown action '{other}' (expected: list|add|done|write|merge|clear)"
            ))),
        }
    }
}

fn list_todos() -> Result<String, ToolError> {
    let guard = store()
        .lock()
        .map_err(|e| ToolError::ExecutionFailed(format!("todo lock poisoned: {e}")))?;
    Ok(render(&guard))
}

fn clear_todos() -> Result<String, ToolError> {
    let mut guard = store()
        .lock()
        .map_err(|e| ToolError::ExecutionFailed(format!("todo lock poisoned: {e}")))?;
    guard.clear();
    Ok(render(&guard))
}

fn add_todo(input: &Value) -> Result<String, ToolError> {
    let content = input
        .get("content")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .ok_or_else(|| ToolError::InvalidArguments("missing non-empty 'content'".into()))?;
    let active_form = input
        .get("active_form")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .unwrap_or(content);
    let id = input
        .get("id")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(str::to_string)
        .unwrap_or_else(|| uuid::Uuid::new_v4().to_string());

    let mut guard = store()
        .lock()
        .map_err(|e| ToolError::ExecutionFailed(format!("todo lock poisoned: {e}")))?;
    guard.push(TodoItem {
        id,
        content: content.to_string(),
        active_form: active_form.to_string(),
        status: "pending".to_string(),
    });
    Ok(render(&guard))
}

fn complete_todo(input: &Value) -> Result<String, ToolError> {
    let id = input
        .get("id")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .ok_or_else(|| ToolError::InvalidArguments("missing non-empty 'id'".into()))?;

    let mut guard = store()
        .lock()
        .map_err(|e| ToolError::ExecutionFailed(format!("todo lock poisoned: {e}")))?;
    let item = guard
        .iter_mut()
        .find(|item| item.id == id)
        .ok_or_else(|| ToolError::InvalidArguments(format!("todo id '{id}' not found")))?;
    item.status = "completed".to_string();
    Ok(render(&guard))
}

fn write_todos(input: &Value, merge: bool) -> Result<String, ToolError> {
    let raw = input
        .get("todos")
        .ok_or_else(|| ToolError::InvalidArguments("missing 'todos' array".into()))?;
    let array = raw
        .as_array()
        .ok_or_else(|| ToolError::InvalidArguments("'todos' must be an array".into()))?;

    let mut parsed: Vec<TodoItem> = Vec::with_capacity(array.len());
    for (idx, entry) in array.iter().enumerate() {
        let content = entry
            .get("content")
            .and_then(Value::as_str)
            .filter(|s| !s.is_empty())
            .ok_or_else(|| ToolError::InvalidArguments(format!("todo[{idx}] missing 'content'")))?;
        let status = entry
            .get("status")
            .and_then(Value::as_str)
            .unwrap_or("pending");
        if !matches!(
            status,
            "pending" | "in_progress" | "completed" | "cancelled"
        ) {
            return Err(ToolError::InvalidArguments(format!(
                "todo[{idx}].status '{status}' invalid (expected pending|in_progress|completed|cancelled)"
            )));
        }
        let active_form = entry
            .get("active_form")
            .and_then(Value::as_str)
            .unwrap_or(content)
            .to_string();
        let id = entry
            .get("id")
            .and_then(Value::as_str)
            .map(|s| s.to_string())
            .unwrap_or_else(|| uuid::Uuid::new_v4().to_string());
        parsed.push(TodoItem {
            id,
            content: content.to_string(),
            active_form,
            status: status.to_string(),
        });
    }

    let mut guard = store()
        .lock()
        .map_err(|e| ToolError::ExecutionFailed(format!("todo lock poisoned: {e}")))?;

    if merge {
        // Upsert by id.
        for new_item in parsed {
            if let Some(existing) = guard.iter_mut().find(|t| t.id == new_item.id) {
                *existing = new_item;
            } else {
                guard.push(new_item);
            }
        }
    } else {
        *guard = parsed;
    }

    Ok(render(&guard))
}

fn render(todos: &[TodoItem]) -> String {
    let mut pending = 0;
    let mut in_progress = 0;
    let mut completed = 0;
    let mut cancelled = 0;
    for item in todos {
        match item.status.as_str() {
            "pending" => pending += 1,
            "in_progress" => in_progress += 1,
            "completed" => completed += 1,
            "cancelled" => cancelled += 1,
            _ => {}
        }
    }
    json!({
        "todos": todos,
        "summary": {
            "pending": pending,
            "in_progress": in_progress,
            "completed": completed,
            "cancelled": cancelled,
            "total": todos.len(),
        }
    })
    .to_string()
}

pub fn todo_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "todo".to_string(),
        description: "Session-scoped task list for planning multi-step work. Actions: \
             list (current todos), add (append one pending todo), done (mark one todo completed), \
             write (replace the whole list), merge (upsert by id), clear (drop everything). \
             Each item needs 'content' plus optional 'active_form' and 'status' \
             (pending|in_progress|completed|cancelled)."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["list", "add", "done", "write", "merge", "clear"],
                    "default": "list"
                },
                "id": {
                    "type": "string",
                    "description": "Todo id for add/done actions."
                },
                "content": {
                    "type": "string",
                    "description": "Todo content for add action."
                },
                "active_form": {
                    "type": "string",
                    "description": "Current active phrasing for add action."
                },
                "todos": {
                    "type": "array",
                    "description": "Todo items for write/merge actions.",
                    "items": {
                        "type": "object",
                        "properties": {
                            "id": { "type": "string" },
                            "content": { "type": "string" },
                            "active_form": { "type": "string" },
                            "status": {
                                "type": "string",
                                "enum": ["pending", "in_progress", "completed", "cancelled"]
                            }
                        },
                        "required": ["content"]
                    }
                }
            }
        }),
    }
}

#[cfg(test)]
mod tests {
    // Test-isolation gate held across `.await` is intentional — see
    // `resources/bridge.rs::tests` for the canonical rationale. The
    // todo tests share a process-wide TODO_STORE singleton.
    #![allow(clippy::await_holding_lock)]

    use super::*;
    use serde_json::json;
    use std::sync::{Mutex, MutexGuard, OnceLock};

    /// Serialize todo tests — they share a process-wide TODO_STORE and would
    /// race against each other under the default multi-threaded test runner.
    fn lock_tests() -> MutexGuard<'static, ()> {
        static GATE: OnceLock<Mutex<()>> = OnceLock::new();
        GATE.get_or_init(|| Mutex::new(()))
            .lock()
            .unwrap_or_else(|poison| poison.into_inner())
    }

    async fn reset_store() {
        let handler = TodoHandler;
        handler
            .execute(&json!({ "action": "clear" }))
            .await
            .unwrap();
    }

    #[tokio::test]
    async fn todo_write_replaces_list() {
        let _gate = lock_tests();
        reset_store().await;
        let handler = TodoHandler;
        let result = handler
            .execute(&json!({
                "action": "write",
                "todos": [
                    { "content": "task one", "status": "pending" },
                    { "content": "task two", "status": "in_progress" }
                ]
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["summary"]["total"], json!(2));
        assert_eq!(parsed["summary"]["pending"], json!(1));
        assert_eq!(parsed["summary"]["in_progress"], json!(1));
    }

    #[tokio::test]
    async fn todo_merge_upserts_by_id() {
        let _gate = lock_tests();
        reset_store().await;
        let handler = TodoHandler;

        // Seed with one item.
        let first = handler
            .execute(&json!({
                "action": "write",
                "todos": [ { "id": "a", "content": "first", "status": "pending" } ]
            }))
            .await
            .unwrap();
        let _: Value = serde_json::from_str(&first).unwrap();

        // Merge: update existing 'a' and add 'b'.
        let merged = handler
            .execute(&json!({
                "action": "merge",
                "todos": [
                    { "id": "a", "content": "first updated", "status": "completed" },
                    { "id": "b", "content": "second", "status": "pending" }
                ]
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&merged).unwrap();
        assert_eq!(parsed["summary"]["total"], json!(2));
        assert_eq!(parsed["summary"]["completed"], json!(1));
        let todos = parsed["todos"].as_array().unwrap();
        assert!(todos
            .iter()
            .any(|t| t["id"] == "a" && t["status"] == "completed"));
        assert!(todos.iter().any(|t| t["id"] == "b"));
    }

    #[tokio::test]
    async fn todo_add_appends_pending_item() {
        let _gate = lock_tests();
        reset_store().await;
        let handler = TodoHandler;

        let result = handler
            .execute(&json!({
                "action": "add",
                "id": "hermes-1",
                "content": "Ship Hermes todo bridge",
                "active_form": "Shipping Hermes todo bridge"
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();

        assert_eq!(parsed["summary"]["total"], json!(1));
        assert_eq!(parsed["summary"]["pending"], json!(1));
        assert_eq!(parsed["todos"][0]["id"], json!("hermes-1"));
        assert_eq!(parsed["todos"][0]["active_form"], json!("Shipping Hermes todo bridge"));
    }

    #[tokio::test]
    async fn todo_done_marks_existing_item_completed() {
        let _gate = lock_tests();
        reset_store().await;
        let handler = TodoHandler;

        handler
            .execute(&json!({
                "action": "add",
                "id": "hermes-2",
                "content": "Finish the task",
            }))
            .await
            .unwrap();
        let result = handler
            .execute(&json!({
                "action": "done",
                "id": "hermes-2",
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();

        assert_eq!(parsed["summary"]["completed"], json!(1));
        assert_eq!(parsed["todos"][0]["status"], json!("completed"));
    }

    #[tokio::test]
    async fn todo_done_rejects_unknown_id() {
        let _gate = lock_tests();
        reset_store().await;
        let handler = TodoHandler;

        let err = handler
            .execute(&json!({
                "action": "done",
                "id": "missing",
            }))
            .await
            .unwrap_err();

        assert!(format!("{err}").contains("not found"));
    }

    #[tokio::test]
    async fn todo_rejects_invalid_status() {
        let _gate = lock_tests();
        reset_store().await;
        let handler = TodoHandler;
        let err = handler
            .execute(&json!({
                "action": "write",
                "todos": [ { "content": "bad", "status": "weird" } ]
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("status"));
    }

    #[tokio::test]
    async fn todo_list_starts_empty_or_preserves_state() {
        let _gate = lock_tests();
        // Just ensure list runs without panicking.
        let handler = TodoHandler;
        let result = handler.execute(&json!({ "action": "list" })).await.unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert!(parsed["summary"]["total"].is_number());
    }
}
