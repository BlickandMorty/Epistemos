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

use serde_json::{Value, json};

use super::registry::{ToolError, ToolHandler};

const MAX_TEXT_CHARS: usize = 8_000;
const MAX_APP_NAME_CHARS: usize = 256;
const MAX_COORDINATE_ABS: i64 = 100_000;
const SUPPORTED_ACTIONS: &[&str] = &["screenshot", "click", "type_text", "scroll", "get_ax_tree"];

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
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        validate_computer_action(input)?;
        Err(ToolError::ExecutionFailed(
            "computer use is not executed by the Rust registry handler; v1 uses the native Swift ComputerUseBridge path when a host session is active".into(),
        ))
    }
}

fn validate_computer_action(input: &Value) -> Result<&str, ToolError> {
    let action = input
        .get("action")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'action'".into()))?;
    if !SUPPORTED_ACTIONS.contains(&action) {
        return Err(ToolError::InvalidArguments(format!(
            "unknown action '{action}' (expected: {})",
            SUPPORTED_ACTIONS.join("|")
        )));
    }

    match action {
        "screenshot" => {}
        "click" => {
            required_coordinate(input, "x")?;
            required_coordinate(input, "y")?;
        }
        "type_text" => {
            let text = required_string(input, "text")?;
            if text.chars().count() > MAX_TEXT_CHARS {
                return Err(ToolError::InvalidArguments(format!(
                    "'text' is too long (max {MAX_TEXT_CHARS} chars)"
                )));
            }
        }
        "scroll" => {
            required_coordinate(input, "x")?;
            required_coordinate(input, "y")?;
            let direction = required_string(input, "direction")?;
            if !matches!(direction, "up" | "down" | "left" | "right") {
                return Err(ToolError::InvalidArguments(
                    "'direction' must be one of up|down|left|right".into(),
                ));
            }
        }
        "get_ax_tree" => {
            if let Some(app_name) = optional_string(input, "app_name")? {
                if app_name.chars().count() > MAX_APP_NAME_CHARS {
                    return Err(ToolError::InvalidArguments(format!(
                        "'app_name' is too long (max {MAX_APP_NAME_CHARS} chars)"
                    )));
                }
            }
        }
        _ => unreachable!("validated supported action table"),
    }

    Ok(action)
}

fn required_coordinate(input: &Value, field: &str) -> Result<i64, ToolError> {
    let value = input
        .get(field)
        .and_then(Value::as_i64)
        .ok_or_else(|| ToolError::InvalidArguments(format!("'{field}' must be an integer")))?;
    if value.abs() > MAX_COORDINATE_ABS {
        return Err(ToolError::InvalidArguments(format!(
            "'{field}' is out of range"
        )));
    }
    Ok(value)
}

fn required_string<'a>(input: &'a Value, field: &str) -> Result<&'a str, ToolError> {
    input
        .get(field)
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments(format!("'{field}' must be a string")))
}

fn optional_string<'a>(input: &'a Value, field: &str) -> Result<Option<&'a str>, ToolError> {
    let Some(value) = input.get(field) else {
        return Ok(None);
    };
    value
        .as_str()
        .map(Some)
        .ok_or_else(|| ToolError::InvalidArguments(format!("'{field}' must be a string")))
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn computer_action_rejects_missing_or_unknown_action() {
        let missing = validate_computer_action(&json!({})).unwrap_err();
        assert!(format!("{missing}").contains("action"));

        let unknown = validate_computer_action(&json!({ "action": "drag" })).unwrap_err();
        assert!(format!("{unknown}").contains("unknown action"));
    }

    #[test]
    fn computer_action_validates_action_specific_fields() {
        let missing_click_y =
            validate_computer_action(&json!({ "action": "click", "x": 12 })).unwrap_err();
        assert!(format!("{missing_click_y}").contains("y"));

        let bad_scroll_direction = validate_computer_action(&json!({
            "action": "scroll",
            "x": 12,
            "y": 20,
            "direction": "diagonal"
        }))
        .unwrap_err();
        assert!(format!("{bad_scroll_direction}").contains("direction"));

        let oversized_text = validate_computer_action(
            &json!({ "action": "type_text", "text": "x".repeat(MAX_TEXT_CHARS + 1) }),
        )
        .unwrap_err();
        assert!(format!("{oversized_text}").contains("text"));
    }

    #[tokio::test]
    async fn rust_handler_fails_honestly_instead_of_returning_placeholder() {
        let tool = ComputerUseTool::new();
        let err = tool
            .execute(&json!({ "action": "screenshot" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("ComputerUseBridge"));
    }
}
