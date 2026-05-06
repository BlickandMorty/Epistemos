//! Computer Use Tool — Delegates to Swift for screen capture + UI automation
//!
//! This tool acts as a bridge: the Rust agent requests computer actions,
//! and the Swift host executes them via ScreenCaptureKit + AXorcist + CGEvent.
//!
//! Actions:
//! - screenshot: Capture current screen (returns base64 image via shared memory)
//! - click: Click at coordinates
//! - type_text: Type text via keyboard
//! - scroll: Scroll at coordinates
//! - get_ax_tree: Get accessibility tree of focused app
//!
//! Architecture: Rust sends action request → Swift delegate handles it →
//! result returned via shared memory for large payloads (screenshots)
//! or inline JSON for small results (AX tree summary).

use serde_json::{json, Value};

use super::registry::ToolHandler;

/// Computer use actions executed by the Swift host.
/// The Rust tool emits these as tool calls; the Swift side intercepts
/// tool_started events with name="computer" and executes natively.
pub struct ComputerUseTool;

impl ComputerUseTool {
    pub fn new() -> Self {
        Self
    }
}

impl Default for ComputerUseTool {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait::async_trait]
impl ToolHandler for ComputerUseTool {
    async fn execute(&self, input: &Value) -> Result<String, super::registry::ToolError> {
        // Computer use is handled by the Swift host, not in Rust.
        // The agent_loop calls this tool handler, but the StreamingDelegate
        // intercepts the tool_started event and executes the action natively.
        //
        // This handler returns a placeholder that tells the Swift side to
        // handle the action. The actual result comes back via tool_completed.
        let action = input["action"].as_str().unwrap_or("screenshot");

        let result = json!({
            "delegate": "swift_host",
            "action": action,
            "input": input,
            "message": "This action is executed by the native macOS host (ScreenCaptureKit + AXorcist).",
        });

        Ok(serde_json::to_string(&result).unwrap_or_default())
    }
}

pub fn computer_use_tool_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "computer".to_string(),
        description: "Control the computer: take screenshots, click, type, scroll, and read the accessibility tree. Actions are executed by the native macOS host.".to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["screenshot", "click", "type_text", "scroll", "get_ax_tree"],
                    "description": "The computer action to perform."
                },
                "x": {
                    "type": "integer",
                    "description": "X coordinate for click/scroll."
                },
                "y": {
                    "type": "integer",
                    "description": "Y coordinate for click/scroll."
                },
                "text": {
                    "type": "string",
                    "description": "Text to type (for type_text action)."
                },
                "direction": {
                    "type": "string",
                    "enum": ["up", "down", "left", "right"],
                    "description": "Scroll direction."
                },
                "app_name": {
                    "type": "string",
                    "description": "Target app for get_ax_tree (optional, defaults to focused app)."
                }
            },
            "required": ["action"],
        }),
    }
}
