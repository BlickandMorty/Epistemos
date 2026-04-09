//! Clarify Tool — Ask User for Clarification
//!
//! Reference: Hermes `tools/clarify_tool.py`
//! Pauses the agent and surfaces a question to the user.
//! The agent loop intercepts the special marker and pauses the session.

use serde_json::{json, Value};

use super::registry::{ToolError, ToolHandler};

pub struct ClarifyTool;

#[async_trait::async_trait]
impl ToolHandler for ClarifyTool {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let question = input["question"]
            .as_str()
            .ok_or_else(|| ToolError::InvalidArguments("question required".into()))?;

        let options = input["options"]
            .as_array()
            .map(|arr| {
                arr.iter()
                    .filter_map(|v| v.as_str())
                    .collect::<Vec<_>>()
                    .join(", ")
            });

        let mut result = format!("[CLARIFICATION_NEEDED]: {}", question);
        if let Some(opts) = options {
            result.push_str(&format!("\nOptions: {}", opts));
        }
        Ok(result)
    }
}

pub fn clarify_tool_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "clarify".to_string(),
        description: "Ask the user a clarification question. Use when the task is ambiguous or you need more information to proceed correctly.".to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "question": {
                    "type": "string",
                    "description": "The question to ask the user"
                },
                "options": {
                    "type": "array",
                    "items": { "type": "string" },
                    "description": "Optional suggested answers"
                }
            },
            "required": ["question"]
        }),
    }
}
