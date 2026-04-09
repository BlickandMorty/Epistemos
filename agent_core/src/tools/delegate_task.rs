//! Delegate Task Tool — Subagent Spawning (Goose Gap #1)
//!
//! Allows the agent to spawn a child agent session with an isolated
//! objective and message history. The child runs on a separate Tokio
//! task and returns its final response as the tool result.
//!
//! This enables parallel task decomposition: the parent agent can
//! delegate subtasks (research, analysis, code review) to child
//! agents while continuing its own work.
//!
//! Depth-limited: max 2 levels of nesting to prevent infinite recursion.

use std::sync::Arc;

use serde_json::{json, Value};
use tokio_util::sync::CancellationToken;

use crate::agent_loop::{run_agent_loop, AgentConfig, AgentError, Effort};
use crate::provider::AgentProvider;
use crate::tools::registry::{ToolHandler, ToolRegistry};
use crate::types::TokenUsage;

use super::registry::ToolError;

const MAX_DEPTH: u32 = 2;

pub struct DelegateTaskTool {
    provider: Arc<dyn AgentProvider>,
    tool_registry: Arc<ToolRegistry>,
    current_depth: u32,
}

impl DelegateTaskTool {
    pub fn new(
        provider: Arc<dyn AgentProvider>,
        tool_registry: Arc<ToolRegistry>,
        depth: u32,
    ) -> Self {
        Self {
            provider,
            tool_registry,
            current_depth: depth,
        }
    }
}

/// Lightweight delegate that discards events (subagent runs silently).
struct SilentDelegate;

impl crate::bridge::AgentEventDelegate for SilentDelegate {
    fn on_thinking_delta(&self, _: String) {}
    fn on_text_delta(&self, _: String) {}
    fn on_tool_input_delta(&self, _: u32, _: String) {}
    fn on_tool_started(&self, _: String, _: String, _: String) {}
    fn on_tool_completed(&self, _: String, _: String, _: bool) {}
    fn on_subagent_spawned(&self, _: String, _: String) {}
    fn on_permission_required(&self, _: String, _: String, _: String, _: String) {}
    fn on_context_compacting(&self, _: u32) {}
    fn on_context_compacted(&self, _: u32) {}
    fn on_turn_started(&self, _: u32, _: u32) {}
    fn on_complete(&self, _: String, _: u32, _: u32) {}
    fn on_error(&self, _: String) {}
    fn wait_for_permission(&self, _: String) -> bool {
        // Auto-approve everything in subagents (parent already approved)
        true
    }
    fn on_clarification_needed(&self, _: String, _: String) -> String {
        // Subagents cannot ask for user clarification; return empty.
        String::new()
    }
    fn on_provider_failed(&self, _: String, _: String, _: u32) -> String {
        // Subagents don't do fallback — return empty.
        String::new()
    }
}

#[async_trait::async_trait]
impl ToolHandler for DelegateTaskTool {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let objective = input["objective"]
            .as_str()
            .unwrap_or("")
            .to_string();

        if objective.is_empty() {
            return Ok(json!({"error": "objective is required"}).to_string());
        }

        if self.current_depth >= MAX_DEPTH {
            return Ok(json!({
                "error": format!("Max subagent depth ({}) reached", MAX_DEPTH),
            }).to_string());
        }

        let config = AgentConfig {
            system_prompt: Some(format!(
                "You are a focused sub-agent. Complete this specific task and return the result concisely. Task: {}",
                objective
            )),
            max_turns: Some(10),
            max_output_tokens: Some(4096),
            effort: Effort::Medium,
            enable_computer_use: false,
            ..AgentConfig::default()
        };

        let cancel = CancellationToken::new();
        let delegate: Arc<dyn crate::bridge::AgentEventDelegate> = Arc::new(SilentDelegate);

        let result = run_agent_loop(
            format!("delegate_{}", uuid::Uuid::new_v4()),
            objective.clone(),
            self.provider.clone(),
            self.tool_registry.clone(),
            delegate,
            config,
            cancel,
            None, // credential_manager
            None, // session_persistence
            None, // provider_factory
        )
        .await;

        match result {
            Ok(agent_result) => {
                // Extract text from content blocks
                let response_text: String = agent_result
                    .final_content
                    .iter()
                    .filter_map(|block| match block {
                        crate::types::ContentBlock::Text { text } => Some(text.as_str()),
                        _ => None,
                    })
                    .collect::<Vec<_>>()
                    .join("\n");

                Ok(json!({
                    "success": true,
                    "objective": objective,
                    "response": response_text,
                    "turns": agent_result.turns,
                    "tokens": {
                        "input": agent_result.total_usage.input_tokens,
                        "output": agent_result.total_usage.output_tokens,
                    },
                })
                .to_string())
            }
            Err(e) => Ok(json!({
                "success": false,
                "objective": objective,
                "error": e.to_string(),
            })
            .to_string()),
        }
    }
}

pub fn delegate_task_tool_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "delegate_task".to_string(),
        description: "Delegate a focused sub-task to an independent agent. The sub-agent runs with its own message history and returns the result. Use for: parallel research, focused analysis, code review, or any task that can be decomposed. Max depth: 2 levels.".to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "objective": {
                    "type": "string",
                    "description": "Clear, focused objective for the sub-agent to accomplish."
                }
            },
            "required": ["objective"],
        }),
    }
}
