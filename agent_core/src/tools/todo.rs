//! Todo Tool — Task Management
//!
//! Reference: Hermes `tools/todo_tool.py`
//! Manages a persistent todo list in the vault at .epistemos/todos.md.
//! Actions: add, complete, remove, list, clear_completed.

use serde_json::{json, Value};
use std::path::{Path, PathBuf};
use std::sync::Mutex;

use super::registry::{ToolError, ToolHandler};

pub struct TodoTool {
    file_path: PathBuf,
    items: Mutex<Vec<TodoItem>>,
}

#[derive(Clone, PartialEq, Eq)]
enum TodoStatus {
    Pending,
    InProgress,
    Completed,
    Cancelled,
}

impl TodoStatus {
    fn as_str(&self) -> &'static str {
        match self {
            Self::Pending => "pending",
            Self::InProgress => "in_progress",
            Self::Completed => "completed",
            Self::Cancelled => "cancelled",
        }
    }
    fn from_str(s: &str) -> Self {
        match s {
            "in_progress" => Self::InProgress,
            "completed" => Self::Completed,
            "cancelled" => Self::Cancelled,
            _ => Self::Pending,
        }
    }
    fn marker(&self) -> &'static str {
        match self {
            Self::Pending => "- [ ]",
            Self::InProgress => "- [~]",
            Self::Completed => "- [x]",
            Self::Cancelled => "- [-]",
        }
    }
}

#[derive(Clone)]
struct TodoItem {
    id: u32,
    text: String,
    status: TodoStatus,
    priority: String,
    created_at: String,
}

impl TodoTool {
    pub fn new(vault_root: PathBuf) -> Self {
        let file_path = vault_root.join(".epistemos/todos.md");
        let items = Self::load_from_disk(&file_path);
        Self {
            file_path,
            items: Mutex::new(items),
        }
    }

    fn load_from_disk(path: &PathBuf) -> Vec<TodoItem> {
        let content = std::fs::read_to_string(path).unwrap_or_default();
        let mut items = Vec::new();
        let mut next_id = 1u32;

        for line in content.lines() {
            let line = line.trim();
            let (status, text) = if line.starts_with("- [x] ") {
                (TodoStatus::Completed, &line[6..])
            } else if line.starts_with("- [~] ") {
                (TodoStatus::InProgress, &line[6..])
            } else if line.starts_with("- [-] ") {
                (TodoStatus::Cancelled, &line[6..])
            } else if line.starts_with("- [ ] ") {
                (TodoStatus::Pending, &line[6..])
            } else {
                continue;
            };

            items.push(TodoItem {
                id: next_id,
                text: text.to_string(),
                status,
                priority: "normal".into(),
                created_at: String::new(),
            });
            next_id += 1;
        }
        items
    }

    fn save_to_disk_at(file_path: &Path, items: &[TodoItem]) {
        if let Some(parent) = file_path.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        let mut content = String::from("# Todos\n\n## In Progress\n");
        for item in items.iter().filter(|i| i.status == TodoStatus::InProgress) {
            content.push_str(&format!("{} {}\n", item.status.marker(), item.text));
        }
        content.push_str("\n## Pending\n");
        for item in items.iter().filter(|i| i.status == TodoStatus::Pending) {
            content.push_str(&format!("{} {}\n", item.status.marker(), item.text));
        }
        content.push_str("\n## Completed\n");
        for item in items.iter().filter(|i| i.status == TodoStatus::Completed) {
            content.push_str(&format!("{} {}\n", item.status.marker(), item.text));
        }
        content.push_str("\n## Cancelled\n");
        for item in items.iter().filter(|i| i.status == TodoStatus::Cancelled) {
            content.push_str(&format!("{} {}\n", item.status.marker(), item.text));
        }
        let _ = std::fs::write(file_path, content);
    }
}

#[async_trait::async_trait]
impl ToolHandler for TodoTool {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let action = input["action"].as_str().unwrap_or("list");
        let mut items = self.items.lock().map_err(|_| ToolError::ExecutionFailed("lock".into()))?;

        match action {
            "add" => {
                let text = input["text"].as_str()
                    .ok_or_else(|| ToolError::InvalidArguments("text required for add".into()))?;
                let priority = input["priority"].as_str().unwrap_or("normal");
                let id = items.iter().map(|i| i.id).max().unwrap_or(0) + 1;
                items.push(TodoItem {
                    id,
                    text: text.to_string(),
                    status: TodoStatus::Pending,
                    priority: priority.to_string(),
                    created_at: chrono::Utc::now().to_rfc3339(),
                });
                Self::save_to_disk_at(&self.file_path, &items);
                Ok(json!({"added": text, "id": id, "total": items.len()}).to_string())
            }
            "start" => {
                let id = input["id"].as_u64()
                    .ok_or_else(|| ToolError::InvalidArguments("id required for start".into()))? as u32;
                // Enforce: only ONE item in_progress at a time (Hermes rule).
                for item in items.iter_mut() {
                    if item.status == TodoStatus::InProgress {
                        item.status = TodoStatus::Pending;
                    }
                }
                let found = items.iter_mut().find(|i| i.id == id).map(|item| {
                    item.status = TodoStatus::InProgress;
                    item.text.clone()
                });
                if let Some(text) = found {
                    Self::save_to_disk_at(&self.file_path, &items);
                    Ok(json!({"started": text, "id": id}).to_string())
                } else {
                    Ok(json!({"error": format!("Todo #{id} not found")}).to_string())
                }
            }
            "complete" => {
                let id = input["id"].as_u64()
                    .ok_or_else(|| ToolError::InvalidArguments("id required for complete".into()))? as u32;
                let found = items.iter_mut().find(|i| i.id == id).map(|item| {
                    item.status = TodoStatus::Completed;
                    item.text.clone()
                });
                if let Some(text) = found {
                    Self::save_to_disk_at(&self.file_path, &items);
                    Ok(json!({"completed": text}).to_string())
                } else {
                    Ok(json!({"error": format!("Todo #{id} not found")}).to_string())
                }
            }
            "cancel" => {
                let id = input["id"].as_u64()
                    .ok_or_else(|| ToolError::InvalidArguments("id required for cancel".into()))? as u32;
                let found = items.iter_mut().find(|i| i.id == id).map(|item| {
                    item.status = TodoStatus::Cancelled;
                    item.text.clone()
                });
                if let Some(text) = found {
                    Self::save_to_disk_at(&self.file_path, &items);
                    Ok(json!({"cancelled": text}).to_string())
                } else {
                    Ok(json!({"error": format!("Todo #{id} not found")}).to_string())
                }
            }
            "remove" => {
                let id = input["id"].as_u64()
                    .ok_or_else(|| ToolError::InvalidArguments("id required for remove".into()))? as u32;
                let before = items.len();
                items.retain(|i| i.id != id);
                Self::save_to_disk_at(&self.file_path, &items);
                Ok(json!({"removed": before != items.len(), "remaining": items.len()}).to_string())
            }
            "list" => {
                let counts = |s: &TodoStatus| items.iter().filter(|i| &i.status == s).count();
                let in_progress: Vec<_> = items.iter().filter(|i| i.status == TodoStatus::InProgress)
                    .map(|i| json!({"id": i.id, "text": i.text, "priority": i.priority}))
                    .collect();
                let pending: Vec<_> = items.iter().filter(|i| i.status == TodoStatus::Pending)
                    .map(|i| json!({"id": i.id, "text": i.text, "priority": i.priority}))
                    .collect();
                let completed: Vec<_> = items.iter().filter(|i| i.status == TodoStatus::Completed)
                    .map(|i| json!({"id": i.id, "text": i.text}))
                    .collect();
                let cancelled: Vec<_> = items.iter().filter(|i| i.status == TodoStatus::Cancelled)
                    .map(|i| json!({"id": i.id, "text": i.text}))
                    .collect();
                Ok(json!({
                    "in_progress": in_progress,
                    "pending": pending,
                    "completed": completed,
                    "cancelled": cancelled,
                    "summary": {
                        "total": items.len(),
                        "in_progress": counts(&TodoStatus::InProgress),
                        "pending": counts(&TodoStatus::Pending),
                        "completed": counts(&TodoStatus::Completed),
                        "cancelled": counts(&TodoStatus::Cancelled),
                    }
                }).to_string())
            }
            "clear_completed" => {
                let before = items.len();
                items.retain(|i| i.status != TodoStatus::Completed && i.status != TodoStatus::Cancelled);
                Self::save_to_disk_at(&self.file_path, &items);
                Ok(json!({"cleared": before - items.len(), "remaining": items.len()}).to_string())
            }
            _ => Ok(json!({"error": format!("Unknown action: {action}. Available: add, start, complete, cancel, remove, list, clear_completed")}).to_string()),
        }
    }
}

pub fn todo_tool_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "todo".to_string(),
        description: "Manage a persistent todo list. Track tasks across sessions.".to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["add", "start", "complete", "cancel", "remove", "list", "clear_completed"],
                    "description": "Action to perform. Use 'start' to mark in_progress (only ONE at a time). Use 'cancel' to mark cancelled."
                },
                "text": { "type": "string", "description": "Todo text (for add)" },
                "id": { "type": "integer", "description": "Todo ID (for complete/remove)" },
                "priority": { "type": "string", "enum": ["low", "normal", "high", "critical"], "description": "Priority (for add)" }
            },
            "required": ["action"]
        }),
    }
}
