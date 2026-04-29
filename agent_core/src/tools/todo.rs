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
use super::{
    Profile, Status, Tool, ToolCtx, ToolMeta, ToolResult, VariantId,
};

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

/// Phase 2G-4a CANARY — first non-test handler to natively implement
/// `Tool` (joining `reason_think::ReasonThinkTool` from Phase 2E). The
/// existing `impl ToolHandler` stays for now so legacy
/// `register_phase_one_todo` continues to work; the v2 catalog wiring
/// uses this native impl directly (no `LegacyToolAdapter` wrap), which
/// is what makes this a true 2G canary — it removes one indirection
/// layer from `system.todo` dispatch.
///
/// Pattern for replicating in the other ~24 files (Phase 2G-4b..z):
///   1. Move the `*_schema()` body out of the `v2_catalog/<name>.rs`
///      module into the handler's own module (or keep it where it is
///      and reference it from the `impl Tool::input_schema`).
///   2. Add an `impl Tool for <Handler>` block whose `invoke` body
///      calls a private helper that contains the existing
///      `ToolHandler::execute` logic, then wraps the resulting String
///      via `wrap_text_result(variant, started, ...)` (or builds a
///      structured `ToolResult::ok` when the handler already returns
///      JSON).
///   3. Update `build_v2_catalog` in registry.rs to construct the
///      handler directly via `Box::new(<Handler>) as Box<dyn Tool>`
///      instead of `LegacyToolAdapter::boxed(<spec>, Arc::new(<Handler>))`.
///   4. Optional: delete the now-unused `v2_catalog/<name>.rs` module
///      (only safe once nothing else references its `SPEC` const).
fn todo_input_schema() -> &'static Value {
    use std::sync::OnceLock;
    static S: OnceLock<Value> = OnceLock::new();
    S.get_or_init(|| {
        json!({
            "type": "object",
            "additionalProperties": false,
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["list", "write", "merge", "clear"],
                    "default": "list"
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
        })
    })
}

fn todo_output_schema() -> &'static Value {
    use std::sync::OnceLock;
    static S: OnceLock<Value> = OnceLock::new();
    S.get_or_init(|| {
        json!({
            "type": "object",
            "required": ["todos", "summary"],
            "properties": {
                "todos": { "type": "array" },
                "summary": { "type": "object" }
            }
        })
    })
}

fn dispatch_action(input: &Value) -> Result<String, ToolError> {
    let action = input
        .get("action")
        .and_then(Value::as_str)
        .unwrap_or("list");

    match action {
        "list" => list_todos(),
        "write" => write_todos(input, false),
        "merge" => write_todos(input, true),
        "clear" => clear_todos(),
        other => Err(ToolError::InvalidArguments(format!(
            "unknown action '{other}' (expected: list|write|merge|clear)"
        ))),
    }
}

#[async_trait]
impl ToolHandler for TodoHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        dispatch_action(input)
    }
}

#[async_trait]
impl Tool for TodoHandler {
    fn name(&self) -> &'static str {
        "system.todo"
    }

    fn input_schema(&self) -> &'static Value {
        todo_input_schema()
    }

    fn output_schema(&self) -> &'static Value {
        todo_output_schema()
    }

    fn variants(&self) -> &[VariantId] {
        &[VariantId::A]
    }

    fn profile(&self) -> Profile {
        Profile::AppStoreSafe
    }

    fn small_model_safe(&self) -> bool {
        true
    }

    async fn invoke(&self, _ctx: &ToolCtx, variant: VariantId, input: Value) -> ToolResult {
        let started = std::time::Instant::now();
        match dispatch_action(&input) {
            Ok(json_string) => {
                let elapsed_ms = started.elapsed().as_millis() as u32;
                // dispatch_action returns a JSON-encoded String; parse
                // back into Value so the v2 surface yields structured
                // result (not a String wrap).
                let parsed: Value = serde_json::from_str(&json_string).unwrap_or_else(
                    |_| serde_json::json!({ "text": json_string }),
                );
                ToolResult {
                    meta: ToolMeta::ok(variant, elapsed_ms),
                    result: parsed,
                }
            }
            Err(e) => {
                let mut meta = ToolMeta::error(variant);
                meta.status = Status::Error;
                ToolResult {
                    meta,
                    result: serde_json::json!({"error": e.to_string()}),
                }
            }
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
             list (current todos), write (replace the whole list), merge (upsert by id), \
             clear (drop everything). Each item needs 'content' plus optional 'active_form' \
             and 'status' (pending|in_progress|completed|cancelled)."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["list", "write", "merge", "clear"],
                    "default": "list"
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
