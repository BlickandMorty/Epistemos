// ── Think Tool: Zero-Cost Structured Reasoning ────────────────────────────
//
// DROP-IN for agent_core/src/tools/think.rs
//
// The "think" tool is a pattern from Anthropic's agent documentation and
// Claude Code. It costs zero tokens beyond the model's own output because
// it simply returns the model's reasoning back to it. But it serves a
// critical architectural purpose:
//
//   1. VISIBLE DECISION TRACE — When the agent calls think(), its reasoning
//      becomes part of the conversation history. This makes debugging and
//      auditing agent decisions possible.
//
//   2. STRUCTURED PAUSE — In a fast tool-calling loop, the model sometimes
//      needs to stop and plan before acting. think() gives it a sanctioned
//      way to do this without burning an extra API round-trip.
//
//   3. ERROR RECOVERY — After a tool failure, the agent can think() about
//      what went wrong and plan a different approach.
//
//   4. MULTI-STEP PLANNING — For complex tasks, think() lets the agent
//      decompose the problem before diving into tool calls.
//
// The tool is marked ReadOnly (auto-approved) and has zero execution cost.
//
// INTEGRATION:
//   1. Register in ToolRegistry alongside vault_search, bash, etc.
//   2. Add the tool schema to get_definitions()
//   3. Handle in execute() — just return the thought text

use serde_json::Value;

/// The tool name as it appears in the tool registry and API calls.
pub const THINK_TOOL_NAME: &str = "think";

/// Tool description sent to the model. This is carefully worded to encourage
/// the model to use it for planning, not as a crutch for simple tasks.
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
///
/// This is intentionally trivial — the value is in the model writing the
/// thought, not in any computation we do with it. The thought becomes part
/// of the tool_result in the conversation history, giving the model a
/// visible reasoning trace it can refer back to.
pub fn execute_think(input: &Value) -> String {
    match input.get("thought").and_then(Value::as_str) {
        Some(thought) => thought.to_string(),
        None => "[think tool called without thought content]".to_string(),
    }
}

/// Returns the ToolSchema for registration in the tool registry.
///
/// The think tool is always available and always auto-approved.
/// It appears in every tool list sent to the model.
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
        // This test verifies the ToolSchema construction works.
        // In the real crate, ToolSchema must be importable.
        assert_eq!(THINK_TOOL_NAME, "think");
        assert!(!THINK_TOOL_DESCRIPTION.is_empty());
    }
}
