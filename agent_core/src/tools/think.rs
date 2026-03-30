// ── Think Tool: Zero-Cost Structured Reasoning ────────────────────────────
//
// The "think" tool gives the model a sanctioned way to pause and plan.
// It returns the thought text unchanged — the value is in creating a
// visible decision trace in the conversation history.

use serde_json::Value;

/// The tool name as it appears in the tool registry and API calls.
pub const THINK_TOOL_NAME: &str = "think";

/// Tool description sent to the model.
pub const THINK_TOOL_DESCRIPTION: &str = "\
Use this tool to think through complex problems step-by-step before acting. \
Call think() when you need to: \
(1) plan a multi-step approach before executing tools, \
(2) analyze a tool result before deciding the next action, \
(3) reason about which tool to use when multiple options exist, \
(4) recover from an error by analyzing what went wrong, or \
(5) synthesize information from multiple sources before responding. \
The content of your thought is returned to you and becomes part of the conversation \
history, making your reasoning visible and auditable. \
This tool has zero execution cost — use it freely whenever careful reasoning would improve your output.";

/// JSON schema for the think tool's input parameters.
pub const THINK_TOOL_SCHEMA: &str = r#"{
    "type": "object",
    "properties": {
        "thought": {
            "type": "string",
            "description": "Your step-by-step reasoning about the current situation, plan, or analysis."
        }
    },
    "required": ["thought"]
}"#;

/// Execute the think tool. Returns the thought text unchanged.
pub fn execute_think(input: &Value) -> String {
    match input.get("thought").and_then(Value::as_str) {
        Some(thought) => thought.to_string(),
        None => "[think tool called without thought content]".to_string(),
    }
}

/// Returns the ToolSchema for registration in the tool registry.
pub fn think_tool_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: THINK_TOOL_NAME.to_string(),
        description: THINK_TOOL_DESCRIPTION.to_string(),
        parameters: serde_json::from_str(THINK_TOOL_SCHEMA).unwrap_or_default(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn returns_thought_text_unchanged() {
        let input = json!({ "thought": "I should search the vault first, then use the result to plan my approach." });
        let result = execute_think(&input);
        assert_eq!(
            result,
            "I should search the vault first, then use the result to plan my approach."
        );
    }

    #[test]
    fn handles_missing_thought_gracefully() {
        let input = json!({});
        let result = execute_think(&input);
        assert!(result.contains("without thought content"));
    }

    #[test]
    fn handles_non_string_thought() {
        let input = json!({ "thought": 42 });
        let result = execute_think(&input);
        assert!(result.contains("without thought content"));
    }

    #[test]
    fn schema_parses_as_valid_json() {
        let parsed: Result<Value, _> = serde_json::from_str(THINK_TOOL_SCHEMA);
        assert!(parsed.is_ok());
        let schema = parsed.unwrap();
        assert_eq!(schema["type"], "object");
        assert!(schema["properties"]["thought"].is_object());
    }

    #[test]
    fn tool_schema_has_correct_name() {
        assert_eq!(THINK_TOOL_NAME, "think");
        assert!(!THINK_TOOL_DESCRIPTION.is_empty());
    }
}
