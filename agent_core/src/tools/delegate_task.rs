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

use serde_json::{Value, json};
use tokio_util::sync::CancellationToken;

use crate::agent_loop::{AgentConfig, Effort, run_agent_loop};
use crate::provider::AgentProvider;
use crate::tools::registry::{ToolHandler, ToolRegistry};

use super::registry::ToolError;

const MAX_DEPTH: u32 = 2;
const MAX_OBJECTIVE_CHARS: usize = 8_000;
const MAX_SUBAGENT_RESPONSE_CHARS: usize = 64 * 1024;
const MAX_SUBAGENT_ERROR_CHARS: usize = 8_000;

fn ensure_char_cap(label: &str, value: &str, cap: usize) -> Result<(), ToolError> {
    let count = value.chars().count();
    if count > cap {
        return Err(ToolError::InvalidArguments(format!(
            "{label} exceeds {cap} characters"
        )));
    }
    Ok(())
}

fn truncate_chars(value: String, cap: usize) -> String {
    let mut chars = value.chars();
    let truncated: String = chars.by_ref().take(cap).collect();
    if chars.next().is_some() {
        format!("{truncated}\n\n[truncated to {cap} characters]")
    } else {
        truncated
    }
}

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
    fn execute_computer_action(&self, _: String) -> String {
        "{\"success\":false,\"error\":\"computer use unavailable in silent delegate\"}".to_string()
    }
    fn wait_for_permission(&self, _: String) -> bool {
        // Auto-approve everything in subagents (parent already approved)
        true
    }
    fn ask_user_question(&self, _: String) -> String {
        // Subagents cannot ask the user anything — they must succeed or fail
        // with the context they have.
        "{\"response\":\"\",\"choice_index\":null,\"error\":\"clarify unavailable in silent delegate\"}".to_string()
    }
    fn perceive_app(&self, _: String, _: String) -> String {
        "{\"elements\":[],\"error\":\"perceive unavailable in silent delegate\"}".to_string()
    }
    fn interact_with_app(&self, _: String) -> String {
        "{\"success\":false,\"error\":\"interact unavailable in silent delegate\"}".to_string()
    }
    fn start_screen_watch(&self, _: String) -> String {
        "{\"triggered\":false,\"error\":\"screen_watch unavailable in silent delegate\"}"
            .to_string()
    }
    fn manage_ssm_state(&self, _: String) -> String {
        "{\"success\":false,\"error\":\"ssm_resume unavailable in silent delegate\"}".to_string()
    }
    fn generate_constrained(&self, _: String, _: String) -> String {
        "{\"output\":\"\",\"error\":\"constrained_generate unavailable in silent delegate\"}"
            .to_string()
    }
    fn generate_image(&self, _: String, _: String) -> String {
        // Subagents cannot escalate to the MLX sidecar or any cloud
        // provider. This is an explicit, canonical failure — callers
        // who need image generation must run at a non-subagent level.
        "{\"error\":\"image_generate unavailable in silent delegate — \
         subagents must not escalate to MLX/FAL\"}"
            .to_string()
    }
    fn trigger_nightbrain_job(&self, _: String, _: String) -> String {
        "{\"status\":\"skipped\",\"error\":\"nightbrain unavailable in silent delegate\"}"
            .to_string()
    }
    fn get_partner_context(&self, _: String, _: u32) -> String {
        "{\"success\":false,\"error\":\"inline_partner unavailable in silent delegate\"}"
            .to_string()
    }
}

#[async_trait::async_trait]
impl ToolHandler for DelegateTaskTool {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let objective = input
            .get("objective")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'objective'".into()))?;
        let objective = objective.trim();

        if objective.is_empty() {
            return Err(ToolError::InvalidArguments(
                "'objective' cannot be empty".into(),
            ));
        }
        ensure_char_cap("objective", objective, MAX_OBJECTIVE_CHARS)?;
        let objective = objective.to_string();

        if self.current_depth >= MAX_DEPTH {
            return Err(ToolError::ExecutionFailed(format!(
                "max subagent depth ({MAX_DEPTH}) reached"
            )));
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
        let session_id = uuid::Uuid::new_v4().to_string();

        let result = run_agent_loop(
            session_id,
            objective.clone(),
            self.provider.clone(),
            self.tool_registry.clone(),
            delegate,
            config,
            cancel,
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
                let response_text = truncate_chars(response_text, MAX_SUBAGENT_RESPONSE_CHARS);

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
                "error": truncate_chars(e.to_string(), MAX_SUBAGENT_ERROR_CHARS),
            })
            .to_string()),
        }
    }
}

pub fn delegate_task_tool_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "delegate_task".to_string(),
        description: "Delegate a focused sub-task to an independent agent. The sub-agent runs with its own message history and returns the result. Use for: parallel research, focused analysis, code review, or any task that can be decomposed. Max depth: 2 levels; objective and returned text are bounded.".to_string(),
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

#[cfg(test)]
mod tests {
    use super::*;
    use async_trait::async_trait;
    use futures::stream;

    use crate::agent_loop::{AgentConfig, AgentError};
    use crate::provider::{AgentProvider, MessageStream, ProviderCapabilities};
    use crate::storage::vault::{SearchResult, VaultBackend, VaultError};
    use crate::types::{Message, ToolSchema};

    struct StubProvider;

    #[async_trait]
    impl AgentProvider for StubProvider {
        async fn stream_message(
            &self,
            _messages: &[Message],
            _tools: &[ToolSchema],
            _config: &AgentConfig,
        ) -> Result<MessageStream, AgentError> {
            Ok(Box::pin(stream::empty()))
        }

        async fn compact(&self, _messages: &[Message]) -> Result<Vec<Message>, AgentError> {
            Ok(Vec::new())
        }

        fn capabilities(&self) -> ProviderCapabilities {
            ProviderCapabilities {
                max_context_tokens: 8_192,
                max_output_tokens: 4_096,
                supports_thinking: false,
                supports_vision: false,
                supports_web_search: false,
                supports_code_execution: false,
                supports_computer_use: false,
                supports_mcp: false,
                supports_streaming: true,
                supports_compaction: false,
                cost_input_per_million: 0.0,
                cost_output_per_million: 0.0,
            }
        }

        fn name(&self) -> &'static str {
            "stub"
        }
    }

    struct NullVault;

    #[async_trait]
    impl VaultBackend for NullVault {
        async fn hybrid_search(
            &self,
            _query: &str,
            _limit: usize,
            _tag_filter: &[String],
        ) -> Result<Vec<SearchResult>, VaultError> {
            Ok(Vec::new())
        }

        async fn read(&self, _path: &str) -> Result<String, VaultError> {
            Ok(String::new())
        }

        async fn write(
            &self,
            _path: &str,
            _content: &str,
            _tags: Option<&[String]>,
            _append: bool,
        ) -> Result<(), VaultError> {
            Ok(())
        }

        async fn list(&self, _path_prefix: &str) -> Result<Vec<String>, VaultError> {
            Ok(Vec::new())
        }

        async fn exists(&self, _path: &str) -> Result<bool, VaultError> {
            Ok(false)
        }

        async fn delete(&self, _path: &str) -> Result<bool, VaultError> {
            Ok(false)
        }
    }

    fn handler_at_depth(depth: u32) -> DelegateTaskTool {
        let provider: Arc<dyn AgentProvider> = Arc::new(StubProvider);
        let vault: Arc<dyn VaultBackend> = Arc::new(NullVault);
        let registry = Arc::new(ToolRegistry::new(vault));
        DelegateTaskTool::new(provider, registry, depth)
    }

    #[tokio::test]
    async fn delegate_task_rejects_missing_objective() {
        let handler = handler_at_depth(0);
        let err = handler.execute(&json!({})).await.unwrap_err();
        assert!(format!("{err}").contains("objective"));
    }

    #[tokio::test]
    async fn delegate_task_rejects_empty_objective() {
        let handler = handler_at_depth(0);
        let err = handler
            .execute(&json!({ "objective": "   " }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("cannot be empty"));
    }

    #[tokio::test]
    async fn delegate_task_rejects_oversized_objective() {
        let handler = handler_at_depth(0);
        let objective = "x".repeat(MAX_OBJECTIVE_CHARS + 1);
        let err = handler
            .execute(&json!({ "objective": objective }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("objective exceeds"));
    }

    #[tokio::test]
    async fn delegate_task_rejects_max_depth_before_spawn() {
        let handler = handler_at_depth(MAX_DEPTH);
        let err = handler
            .execute(&json!({ "objective": "summarize this" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("max subagent depth"));
    }

    #[test]
    fn delegate_task_truncates_long_text() {
        let text = truncate_chars("abcdef".to_string(), 3);
        assert_eq!(text, "abc\n\n[truncated to 3 characters]");
        assert_eq!(truncate_chars("abc".to_string(), 3), "abc");
    }
}
