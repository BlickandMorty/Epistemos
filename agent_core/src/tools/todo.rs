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

#[derive(Clone)]
struct TodoItem {
    id: u32,
    text: String,
    completed: bool,
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
            if line.starts_with("- [x] ") {
                items.push(TodoItem {
                    id: next_id,
                    text: line[6..].to_string(),
                    completed: true,
                    priority: "normal".into(),
                    created_at: String::new(),
                });
                next_id += 1;
            } else if line.starts_with("- [ ] ") {
                items.push(TodoItem {
                    id: next_id,
                    text: line[6..].to_string(),
                    completed: false,
                    priority: "normal".into(),
                    created_at: String::new(),
                });
                next_id += 1;
            }
        }
        items
    }

    fn save_to_disk_at(file_path: &Path, items: &[TodoItem]) {
        if let Some(parent) = file_path.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        let mut content = String::from("# Todos\n\n## Active\n");
        for item in items.iter().filter(|i| !i.completed) {
            content.push_str(&format!("- [ ] {}\n", item.text));
        }
        content.push_str("\n## Completed\n");
        for item in items.iter().filter(|i| i.completed) {
            content.push_str(&format!("- [x] {}\n", item.text));
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
                    completed: false,
                    priority: priority.to_string(),
                    created_at: chrono::Utc::now().to_rfc3339(),
                });
                Self::save_to_disk_at(&self.file_path, &items);
                Ok(json!({"added": text, "id": id, "total": items.len()}).to_string())
            }
            "complete" => {
                let id = input["id"].as_u64()
                    .ok_or_else(|| ToolError::InvalidArguments("id required for complete".into()))? as u32;
                let found = items.iter_mut().find(|i| i.id == id).map(|item| {
                    item.completed = true;
                    item.text.clone()
                });
                if let Some(text) = found {
                    Self::save_to_disk_at(&self.file_path, &items);
                    Ok(json!({"completed": text}).to_string())
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
                let active: Vec<_> = items.iter().filter(|i| !i.completed)
                    .map(|i| json!({"id": i.id, "text": i.text, "priority": i.priority}))
                    .collect();
                let completed: Vec<_> = items.iter().filter(|i| i.completed)
                    .map(|i| json!({"id": i.id, "text": i.text}))
                    .collect();
                Ok(json!({"active": active, "completed": completed}).to_string())
            }
            "clear_completed" => {
                let before = items.len();
                items.retain(|i| !i.completed);
                Self::save_to_disk_at(&self.file_path, &items);
                Ok(json!({"cleared": before - items.len(), "remaining": items.len()}).to_string())
            }
            _ => Ok(json!({"error": format!("Unknown action: {action}")}).to_string()),
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
                    "enum": ["add", "complete", "remove", "list", "clear_completed"],
                    "description": "Action to perform"
                },
                "text": { "type": "string", "description": "Todo text (for add)" },
                "id": { "type": "integer", "description": "Todo ID (for complete/remove)" },
                "priority": { "type": "string", "enum": ["low", "normal", "high", "critical"], "description": "Priority (for add)" }
            },
            "required": ["action"]
        }),
    }
}
