//! Inference Specialties — Phase 5 (Specialties C1/C2/C3)
//!
//! * `ssm_resume` — save/load/list/prune Mamba-2 SSM hidden state. Uses the
//!   Swift bridge because the state lives in Metal GPU buffers.
//! * `constrained_generate` — grammar-constrained local model decoding. Also
//!   requires the Swift MLX sampling loop.
//! * `route_private` — classify an objective on five dimensions and return
//!   the routing decision. Pure Rust — wraps the existing `ConfidenceRouter`
//!   so the agent can query it directly from tool-use turns.
//!
//! This is the audit layer for Epistemos's on-device AI stack. `route_private`
//! is the "seatbelt" — the agent can sanity-check whether a task would be
//! routed to the cloud or kept local *before* it executes the action.

use std::sync::Arc;

use async_trait::async_trait;
use serde_json::{Value, json};

use crate::bridge::AgentEventDelegate;
use crate::routing::{ConfidenceRouter, HeuristicClassifier, LocalTask, RoutingDecision};

use super::registry::{ToolError, ToolHandler};

const MAX_ROUTE_OBJECTIVE_CHARS: usize = 8_000;
const MAX_SSM_SESSION_ID_CHARS: usize = 128;
const MAX_SSM_LABEL_CHARS: usize = 120;
const MAX_CONSTRAINED_PROMPT_CHARS: usize = 16_000;
const MAX_CUSTOM_EBNF_CHARS: usize = 32_000;
const MAX_TOOLS_JSON_CHARS: usize = 128 * 1024;
const MAX_DELEGATE_RESPONSE_CHARS: usize = 256 * 1024;
const MIN_CONSTRAINED_TOKENS: u64 = 1;
const MAX_CONSTRAINED_TOKENS: u64 = 4_096;

fn ensure_char_cap(label: &str, value: &str, cap: usize) -> Result<(), ToolError> {
    let count = value.chars().count();
    if count > cap {
        return Err(ToolError::InvalidArguments(format!(
            "{label} exceeds {cap} characters"
        )));
    }
    Ok(())
}

fn parse_delegate_json(tool_name: &str, response: String) -> Result<Value, ToolError> {
    if response.chars().count() > MAX_DELEGATE_RESPONSE_CHARS {
        return Err(ToolError::ExecutionFailed(format!(
            "{tool_name} delegate response exceeded {MAX_DELEGATE_RESPONSE_CHARS} character cap"
        )));
    }

    serde_json::from_str(&response).map_err(|_| {
        ToolError::ExecutionFailed(format!(
            "{tool_name} delegate returned non-JSON response; raw output redacted"
        ))
    })
}

// MARK: - route_private (Specialty C3)

pub struct RoutePrivateHandler;

impl RoutePrivateHandler {
    pub fn new() -> Self {
        Self
    }
}

impl Default for RoutePrivateHandler {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait]
impl ToolHandler for RoutePrivateHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let objective = input
            .get("objective")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'objective'".into()))?;
        ensure_char_cap("objective", objective, MAX_ROUTE_OBJECTIVE_CHARS)?;
        let force_local = input
            .get("force_local")
            .and_then(Value::as_bool)
            .unwrap_or(false);

        let classifier = HeuristicClassifier;
        let classification = classifier.classify(objective);
        let router = ConfidenceRouter::default();
        let decision = router.route(objective);

        // Honor the override: if force_local was set AND the decision wasn't
        // already local, flag it so the caller can short-circuit without
        // actually executing the cloud route.
        let override_triggered = force_local && !matches!(decision, RoutingDecision::Local(_));

        let (route_kind, effective_provider, reason) = match &decision {
            RoutingDecision::Local(task) => {
                let reason = if classification.privacy_sensitive {
                    "privacy_sensitive"
                } else {
                    "simple_local_task"
                };
                ("local", format!("{task:?}"), reason.to_string())
            }
            RoutingDecision::LocalWithFallback { local, fallback } => (
                "local_with_fallback",
                format!("{local:?} (fallback: {fallback:?})"),
                "simple_task_with_cloud_escape_hatch".to_string(),
            ),
            RoutingDecision::Cloud(provider, config) => {
                let reason =
                    if classification.research_related || classification.requires_current_info {
                        "needs_web_search"
                    } else if classification.shell_required {
                        "needs_shell"
                    } else if classification.complexity > 0.9 {
                        "very_high_complexity"
                    } else if classification.complexity < 0.2 {
                        "very_low_complexity"
                    } else {
                        "medium_complexity"
                    };
                (
                    "cloud",
                    format!("{provider:?} (effort={})", config.effort),
                    reason.to_string(),
                )
            }
        };

        // Explain why in one sentence the agent can cite in its reasoning.
        let explanation = build_explanation(&classification, &decision, force_local);

        // Derive a privacy confidence score in [0.0, 1.0] from the classifier
        // signal + the final routing target. Local routes get a bigger boost
        // when privacy_sensitive was the driver.
        let privacy_score = if classification.privacy_sensitive {
            0.90
        } else if matches!(decision, RoutingDecision::Local(_))
            || matches!(decision, RoutingDecision::LocalWithFallback { .. })
        {
            0.55
        } else {
            0.20
        };

        Ok(json!({
            "objective": objective,
            "force_local_requested": force_local,
            "override_triggered": override_triggered,
            "route": route_kind,
            "effective_target": effective_provider,
            "reason": reason,
            "privacy_score": privacy_score,
            "classification": {
                "complexity": classification.complexity,
                "tool_count_estimate": classification.tool_count_estimate,
                "requires_current_info": classification.requires_current_info,
                "privacy_sensitive": classification.privacy_sensitive,
                "shell_required": classification.shell_required,
                "research_related": classification.research_related,
            },
            "explanation": explanation,
        })
        .to_string())
    }
}

fn build_explanation(
    classification: &crate::routing::ClassificationResult,
    decision: &RoutingDecision,
    force_local: bool,
) -> String {
    let mut parts: Vec<String> = Vec::new();
    if classification.privacy_sensitive {
        parts.push("Request contains privacy markers — forcing local route.".to_string());
    }
    if force_local {
        parts.push("Caller passed force_local=true.".to_string());
    }
    if classification.research_related {
        parts.push("Research keywords detected → web_search required.".to_string());
    }
    if classification.requires_current_info {
        parts.push("Current info needed → cloud search provider preferred.".to_string());
    }
    if classification.shell_required {
        parts.push("Shell execution implied → code-execution-capable provider.".to_string());
    }
    parts.push(format!(
        "Complexity estimate {:.2} and ~{} tools.",
        classification.complexity, classification.tool_count_estimate
    ));
    match decision {
        RoutingDecision::Local(LocalTask::Classify) => {
            parts.push("Routed to local classifier (in-process).".to_string());
        }
        RoutingDecision::Local(LocalTask::GhostWrite) => {
            parts.push("Routed to local ghost-writer (MLX).".to_string());
        }
        RoutingDecision::Local(LocalTask::SimpleTool { max_tools }) => {
            parts.push(format!(
                "Routed to local simple-tool runner (max {max_tools} tools)."
            ));
        }
        RoutingDecision::Local(LocalTask::Embed) => {
            parts.push("Routed to local embedding model.".to_string());
        }
        RoutingDecision::LocalWithFallback { fallback, .. } => {
            parts.push(format!("Local-first with cloud fallback: {fallback:?}."));
        }
        RoutingDecision::Cloud(provider, config) => {
            parts.push(format!(
                "Routed to cloud {provider:?} (effort={}).",
                config.effort
            ));
        }
    }
    parts.join(" ")
}

pub fn route_private_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "route_private".to_string(),
        description: "Specialty C3 — classify an objective on five privacy/complexity dimensions \
             and return the routing decision with a typed audit trail. Use this to sanity-check \
             whether a task would leave the device BEFORE taking action. Setting \
             force_local=true flags requests the caller wants kept local even if the router \
             would normally escalate to the cloud."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "objective": { "type": "string", "description": "The task / prompt you are about to run." },
                "force_local": { "type": "boolean", "default": false, "description": "Flag the result with override_triggered when the route was non-local." }
            },
            "required": ["objective"]
        }),
    }
}

// MARK: - ssm_resume (Specialty C1)

pub struct SsmResumeHandler {
    delegate: Arc<dyn AgentEventDelegate>,
}

impl SsmResumeHandler {
    pub fn new(delegate: Arc<dyn AgentEventDelegate>) -> Self {
        Self { delegate }
    }
}

#[async_trait]
impl ToolHandler for SsmResumeHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let action = input
            .get("action")
            .map(|value| {
                value
                    .as_str()
                    .ok_or_else(|| ToolError::InvalidArguments("'action' must be a string".into()))
            })
            .transpose()?
            .unwrap_or("list");
        if !matches!(action, "save" | "load" | "list" | "prune") {
            return Err(ToolError::InvalidArguments(format!(
                "action '{action}' invalid (expected save|load|list|prune)"
            )));
        }

        let session_id = input
            .get("session_id")
            .map(|value| {
                value.as_str().ok_or_else(|| {
                    ToolError::InvalidArguments("'session_id' must be a string".into())
                })
            })
            .transpose()?;
        // Require session_id for save/load/prune; list is fine without it.
        if matches!(action, "save" | "load" | "prune") && session_id.is_none() {
            return Err(ToolError::InvalidArguments(format!(
                "action '{action}' requires 'session_id'"
            )));
        }
        if let Some(session_id) = session_id {
            ensure_char_cap("session_id", session_id, MAX_SSM_SESSION_ID_CHARS)?;
        }

        let label = input
            .get("label")
            .map(|value| {
                value
                    .as_str()
                    .ok_or_else(|| ToolError::InvalidArguments("'label' must be a string".into()))
            })
            .transpose()?;
        if let Some(label) = label {
            ensure_char_cap("label", label, MAX_SSM_LABEL_CHARS)?;
        }

        let payload = json!({
            "action": action,
            "session_id": session_id.map(Value::from).unwrap_or(Value::Null),
            "label": label.map(Value::from).unwrap_or(Value::Null),
        })
        .to_string();

        let delegate = Arc::clone(&self.delegate);
        let response = tokio::task::spawn_blocking(move || delegate.manage_ssm_state(payload))
            .await
            .map_err(|e| ToolError::ExecutionFailed(format!("ssm_resume join: {e}")))?;
        let parsed = parse_delegate_json("ssm_resume", response)?;
        Ok(parsed.to_string())
    }
}

pub fn ssm_resume_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "ssm_resume".to_string(),
        description: "Specialty C1 — manage Mamba-2 SSM hidden state snapshots. Actions: \
             'save' (persist current hidden state for a session with an optional label), \
             'load' (restore a snapshot without replaying the transcript), \
             'list' (enumerate saved snapshots), 'prune' (evict old snapshots for a session). \
             This Rust handler is a bounded audit bridge to the host delegate; storage size and \
             latency are reported by the delegate implementation."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["save", "load", "list", "prune"],
                    "default": "list"
                },
                "session_id": { "type": "string", "description": "Session identifier (required for save/load/prune)." },
                "label": { "type": "string", "description": "Optional named checkpoint like 'before_refactor'." }
            }
        }),
    }
}

// MARK: - constrained_generate (Specialty C2)

pub struct ConstrainedGenerateHandler {
    delegate: Arc<dyn AgentEventDelegate>,
}

impl ConstrainedGenerateHandler {
    pub fn new(delegate: Arc<dyn AgentEventDelegate>) -> Self {
        Self { delegate }
    }
}

#[async_trait]
impl ToolHandler for ConstrainedGenerateHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let prompt = input
            .get("prompt")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'prompt'".into()))?;
        ensure_char_cap("prompt", prompt, MAX_CONSTRAINED_PROMPT_CHARS)?;
        let prompt = prompt.to_string();
        let grammar = input
            .get("grammar")
            .map(|value| {
                value
                    .as_str()
                    .ok_or_else(|| ToolError::InvalidArguments("'grammar' must be a string".into()))
            })
            .transpose()?
            .unwrap_or("tool_call");
        if !matches!(grammar, "tool_call" | "planning" | "custom") {
            return Err(ToolError::InvalidArguments(format!(
                "grammar '{grammar}' invalid (expected tool_call|planning|custom)"
            )));
        }
        let custom_ebnf = input
            .get("custom_ebnf")
            .map(|value| {
                value.as_str().ok_or_else(|| {
                    ToolError::InvalidArguments("'custom_ebnf' must be a string".into())
                })
            })
            .transpose()?;
        if grammar == "custom" && custom_ebnf.is_none() {
            return Err(ToolError::InvalidArguments(
                "grammar='custom' requires string 'custom_ebnf'".into(),
            ));
        }
        if let Some(custom_ebnf) = custom_ebnf {
            ensure_char_cap("custom_ebnf", custom_ebnf, MAX_CUSTOM_EBNF_CHARS)?;
        }

        let tools = input.get("tools").cloned().unwrap_or(Value::Null);
        if !tools.is_null() && !tools.is_array() {
            return Err(ToolError::InvalidArguments(
                "'tools' must be an array when supplied".into(),
            ));
        }
        let tools_len = tools.to_string().chars().count();
        if tools_len > MAX_TOOLS_JSON_CHARS {
            return Err(ToolError::InvalidArguments(format!(
                "tools JSON exceeds {MAX_TOOLS_JSON_CHARS} characters"
            )));
        }

        let max_tokens = input
            .get("max_tokens")
            .map(|value| {
                value.as_u64().ok_or_else(|| {
                    ToolError::InvalidArguments("'max_tokens' must be an integer".into())
                })
            })
            .transpose()?
            .unwrap_or(256);
        if !(MIN_CONSTRAINED_TOKENS..=MAX_CONSTRAINED_TOKENS).contains(&max_tokens) {
            return Err(ToolError::InvalidArguments(format!(
                "max_tokens must be between {MIN_CONSTRAINED_TOKENS} and {MAX_CONSTRAINED_TOKENS}"
            )));
        }

        let grammar_payload = json!({
            "grammar": grammar,
            "custom_ebnf": custom_ebnf.map(Value::from).unwrap_or(Value::Null),
            "tools": tools,
            "max_tokens": max_tokens,
        })
        .to_string();

        let delegate = Arc::clone(&self.delegate);
        let response = tokio::task::spawn_blocking(move || {
            delegate.generate_constrained(prompt, grammar_payload)
        })
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("constrained_generate join: {e}")))?;
        let parsed = parse_delegate_json("constrained_generate", response)?;
        Ok(parsed.to_string())
    }
}

pub fn constrained_generate_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "constrained_generate".to_string(),
        description: "Specialty C2 — ask the host delegate to run constrained decoding against \
             the on-device model with an EBNF grammar, returning only JSON delegate responses. Grammars: \
             'tool_call' (auto-compiled from the tool registry), 'planning' (task-plan JSON), \
             'custom' (supply your own EBNF via custom_ebnf). Used for reliable local tool \
             calling without JSON-schema retries."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "prompt": { "type": "string" },
                "grammar": {
                    "type": "string",
                    "enum": ["tool_call", "planning", "custom"],
                    "default": "tool_call"
                },
                "custom_ebnf": { "type": "string", "description": "Required when grammar='custom'." },
                "tools": { "type": "array", "description": "Optional tool schema list when grammar='tool_call'." },
                "max_tokens": { "type": "integer", "default": 256, "minimum": 1, "maximum": 4096 }
            },
            "required": ["prompt"]
        }),
    }
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    /// Scripted delegate for unit-testing the two delegate-backed tools.
    struct StubDelegate {
        ssm_response: String,
        constrained_response: String,
    }

    impl AgentEventDelegate for StubDelegate {
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
            "{}".to_string()
        }
        fn wait_for_permission(&self, _: String) -> bool {
            true
        }
        fn ask_user_question(&self, _: String) -> String {
            "{}".to_string()
        }
        fn perceive_app(&self, _: String, _: String) -> String {
            "{}".to_string()
        }
        fn interact_with_app(&self, _: String) -> String {
            "{}".to_string()
        }
        fn start_screen_watch(&self, _: String) -> String {
            "{}".to_string()
        }
        fn manage_ssm_state(&self, _: String) -> String {
            self.ssm_response.clone()
        }
        fn generate_constrained(&self, _: String, _: String) -> String {
            self.constrained_response.clone()
        }
        fn generate_image(&self, _: String, _: String) -> String {
            "{\"error\":\"image_generate stub\"}".to_string()
        }
        fn trigger_nightbrain_job(&self, _: String, _: String) -> String {
            "{}".to_string()
        }
        fn get_partner_context(&self, _: String, _: u32) -> String {
            "{}".to_string()
        }
    }

    fn stub_delegate(ssm: &str, cg: &str) -> Arc<dyn AgentEventDelegate> {
        Arc::new(StubDelegate {
            ssm_response: ssm.to_string(),
            constrained_response: cg.to_string(),
        })
    }

    // route_private ---------------------------------------------------------

    #[tokio::test]
    async fn route_private_flags_privacy_sensitive_as_local() {
        let handler = RoutePrivateHandler::new();
        let result = handler
            .execute(&json!({
                "objective": "Summarise my private financial notes for my own eyes only"
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["route"], json!("local"));
        assert_eq!(parsed["classification"]["privacy_sensitive"], json!(true));
        assert!(parsed["privacy_score"].as_f64().unwrap() >= 0.85);
        assert!(parsed["reason"].as_str().unwrap().contains("privacy"));
    }

    #[tokio::test]
    async fn route_private_escalates_research_to_cloud() {
        let handler = RoutePrivateHandler::new();
        let result = handler
            .execute(&json!({
                "objective": "Research the latest Rust async runtime comparisons with citations"
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["route"], json!("cloud"));
    }

    #[tokio::test]
    async fn route_private_reports_override_triggered() {
        let handler = RoutePrivateHandler::new();
        let result = handler
            .execute(&json!({
                "objective": "Research current LLM benchmarks",
                "force_local": true
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["force_local_requested"], json!(true));
        assert_eq!(parsed["override_triggered"], json!(true));
    }

    #[tokio::test]
    async fn route_private_rejects_missing_objective() {
        let handler = RoutePrivateHandler::new();
        let err = handler.execute(&json!({})).await.unwrap_err();
        assert!(format!("{err}").contains("objective"));
    }

    #[tokio::test]
    async fn route_private_rejects_oversized_objective() {
        let handler = RoutePrivateHandler::new();
        let objective = "x".repeat(MAX_ROUTE_OBJECTIVE_CHARS + 1);
        let err = handler
            .execute(&json!({ "objective": objective }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("objective exceeds"));
    }

    // ssm_resume ------------------------------------------------------------

    #[tokio::test]
    async fn ssm_resume_list_works_without_session_id() {
        let delegate = stub_delegate(
            r#"{"states":[{"session":"abc","layers":24,"state_size_mb":12.4}]}"#,
            "{}",
        );
        let handler = SsmResumeHandler::new(delegate);
        let result = handler.execute(&json!({ "action": "list" })).await.unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert!(parsed["states"].is_array());
    }

    #[tokio::test]
    async fn ssm_resume_save_requires_session_id() {
        let delegate = stub_delegate("{}", "{}");
        let handler = SsmResumeHandler::new(delegate);
        let err = handler
            .execute(&json!({ "action": "save" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("session_id"));
    }

    #[tokio::test]
    async fn ssm_resume_rejects_unknown_action() {
        let delegate = stub_delegate("{}", "{}");
        let handler = SsmResumeHandler::new(delegate);
        let err = handler
            .execute(&json!({ "action": "teleport", "session_id": "x" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("invalid"));
    }

    #[tokio::test]
    async fn ssm_resume_save_forwards_session_and_label() {
        let delegate = stub_delegate(r#"{"success":true,"state_size_mb":12.1,"layers":24}"#, "{}");
        let handler = SsmResumeHandler::new(delegate);
        let result = handler
            .execute(&json!({
                "action": "save",
                "session_id": "sess-42",
                "label": "before_refactor"
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["success"], json!(true));
    }

    #[tokio::test]
    async fn ssm_resume_rejects_oversized_session_id() {
        let delegate = stub_delegate("{}", "{}");
        let handler = SsmResumeHandler::new(delegate);
        let session_id = "s".repeat(MAX_SSM_SESSION_ID_CHARS + 1);
        let err = handler
            .execute(&json!({ "action": "save", "session_id": session_id }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("session_id exceeds"));
    }

    #[tokio::test]
    async fn ssm_resume_rejects_oversized_label() {
        let delegate = stub_delegate("{}", "{}");
        let handler = SsmResumeHandler::new(delegate);
        let label = "l".repeat(MAX_SSM_LABEL_CHARS + 1);
        let err = handler
            .execute(&json!({
                "action": "save",
                "session_id": "sess-1",
                "label": label
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("label exceeds"));
    }

    #[tokio::test]
    async fn ssm_resume_rejects_non_json_delegate_without_echoing_raw() {
        let raw = "not json secret-token=do-not-leak";
        let delegate = stub_delegate(raw, "{}");
        let handler = SsmResumeHandler::new(delegate);
        let err = handler
            .execute(&json!({ "action": "list" }))
            .await
            .unwrap_err();
        let message = format!("{err}");
        assert!(message.contains("non-JSON"));
        assert!(!message.contains("secret-token"));
    }

    // constrained_generate --------------------------------------------------

    #[tokio::test]
    async fn constrained_generate_tool_call_grammar_ok() {
        let delegate = stub_delegate(
            "{}",
            r#"{"output":"{\"name\":\"vault_search\"}","tokens_generated":18}"#,
        );
        let handler = ConstrainedGenerateHandler::new(delegate);
        let result = handler
            .execute(&json!({
                "prompt": "search the vault for 'alpha'",
                "grammar": "tool_call"
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert!(parsed["output"].is_string());
    }

    #[tokio::test]
    async fn constrained_generate_custom_requires_ebnf() {
        let delegate = stub_delegate("{}", "{}");
        let handler = ConstrainedGenerateHandler::new(delegate);
        let err = handler
            .execute(&json!({
                "prompt": "anything",
                "grammar": "custom"
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("custom_ebnf"));
    }

    #[tokio::test]
    async fn constrained_generate_rejects_unknown_grammar() {
        let delegate = stub_delegate("{}", "{}");
        let handler = ConstrainedGenerateHandler::new(delegate);
        let err = handler
            .execute(&json!({
                "prompt": "hi",
                "grammar": "freestyle"
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("grammar"));
    }

    #[tokio::test]
    async fn constrained_generate_rejects_missing_prompt() {
        let delegate = stub_delegate("{}", "{}");
        let handler = ConstrainedGenerateHandler::new(delegate);
        let err = handler.execute(&json!({})).await.unwrap_err();
        assert!(format!("{err}").contains("prompt"));
    }

    #[tokio::test]
    async fn constrained_generate_rejects_oversized_prompt() {
        let delegate = stub_delegate("{}", "{}");
        let handler = ConstrainedGenerateHandler::new(delegate);
        let prompt = "p".repeat(MAX_CONSTRAINED_PROMPT_CHARS + 1);
        let err = handler
            .execute(&json!({ "prompt": prompt }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("prompt exceeds"));
    }

    #[tokio::test]
    async fn constrained_generate_rejects_non_string_custom_ebnf() {
        let delegate = stub_delegate("{}", "{}");
        let handler = ConstrainedGenerateHandler::new(delegate);
        let err = handler
            .execute(&json!({
                "prompt": "hi",
                "grammar": "custom",
                "custom_ebnf": null
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("custom_ebnf"));
    }

    #[tokio::test]
    async fn constrained_generate_rejects_invalid_max_tokens() {
        let delegate = stub_delegate("{}", "{}");
        let handler = ConstrainedGenerateHandler::new(delegate);
        let err = handler
            .execute(&json!({
                "prompt": "hi",
                "max_tokens": MAX_CONSTRAINED_TOKENS + 1
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("max_tokens"));
    }

    #[tokio::test]
    async fn constrained_generate_rejects_oversized_tools_payload() {
        let delegate = stub_delegate("{}", "{}");
        let handler = ConstrainedGenerateHandler::new(delegate);
        let large_tool = "t".repeat(MAX_TOOLS_JSON_CHARS + 1);
        let err = handler
            .execute(&json!({
                "prompt": "hi",
                "tools": [large_tool]
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("tools JSON exceeds"));
    }

    #[tokio::test]
    async fn constrained_generate_rejects_non_json_delegate_without_echoing_raw() {
        let raw = "not json api_key=do-not-leak";
        let delegate = stub_delegate("{}", raw);
        let handler = ConstrainedGenerateHandler::new(delegate);
        let err = handler
            .execute(&json!({ "prompt": "hi" }))
            .await
            .unwrap_err();
        let message = format!("{err}");
        assert!(message.contains("non-JSON"));
        assert!(!message.contains("api_key"));
    }
}
