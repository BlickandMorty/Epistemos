use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use futures::{future::try_join_all, StreamExt};
use tokio_util::sync::CancellationToken;

use crate::approval::{approval_key, ApprovalDecision, SmartApproval, SmartApprovalConfig};
use crate::bridge::AgentEventDelegate;
use crate::prompts::{build_system_prompt_with_index, PromptMode};
use crate::provider::{AgentProvider, StreamEvent};
use crate::reasoning_metrics::{compute_trajectory_metrics, ReasoningTrajectoryMetrics};
use crate::session::GlobalSessions;
use crate::storage::session_store::{ToolCallRecord, TraceEvent, TranscriptTurn};
use crate::tools::registry::{RiskLevel, ToolRegistry};
use crate::types::{ContentBlock, Message, StopReason, TokenUsage, ToolResult, ToolResultContent};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Effort {
    Low,
    Medium,
    High,
    Max,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct McpServerConfig {
    pub name: String,
    pub url: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PermissionConfig {
    pub auto_approve_read_only: bool,
    pub auto_approve_modification: bool,
    pub auto_approve_destructive: bool,
}

impl Default for PermissionConfig {
    fn default() -> Self {
        Self {
            auto_approve_read_only: true,
            auto_approve_modification: false,
            auto_approve_destructive: false,
        }
    }
}

#[derive(Debug, Clone)]
pub struct AgentConfig {
    pub system_prompt: Option<String>,
    pub max_turns: Option<u32>,
    pub max_output_tokens: Option<u32>,
    pub context_threshold: usize,
    pub enable_thinking: bool,
    pub effort: Effort,
    pub enable_web_search: bool,
    pub enable_web_fetch: bool,
    pub enable_code_execution: bool,
    pub enable_computer_use: bool,
    pub mcp_servers: Option<Vec<McpServerConfig>>,
    pub parallel_tool_execution: bool,
    pub permissions: PermissionConfig,
    /// Vault root path for 5-tier context injection. When set, the agent loop
    /// loads SOUL.md, decisions.md, skill descriptions, and prior session summaries.
    pub vault_root: Option<String>,
    /// Explicit prompt mode override. None = auto-detect from objective keywords.
    pub prompt_mode_override: Option<PromptMode>,
    /// Maximum USD cost for this agent session. None = unlimited.
    /// On exceed: session pauses with budget_exceeded reason.
    pub max_cost_usd: Option<f64>,
}

impl Default for AgentConfig {
    fn default() -> Self {
        Self {
            system_prompt: None,
            max_turns: Some(25),
            max_output_tokens: Some(16_384),
            context_threshold: 150_000,
            enable_thinking: true,
            effort: Effort::High,
            enable_web_search: false,
            enable_web_fetch: false,
            enable_code_execution: false,
            enable_computer_use: false,
            mcp_servers: None,
            parallel_tool_execution: true,
            permissions: PermissionConfig::default(),
            vault_root: None,
            prompt_mode_override: None,
            max_cost_usd: None,
        }
    }
}

#[derive(Debug, Clone)]
pub struct AgentResult {
    pub final_content: Vec<ContentBlock>,
    pub full_history: Vec<Message>,
    pub turns: u32,
    pub total_usage: TokenUsage,
    pub trajectory_metrics: ReasoningTrajectoryMetrics,
}

#[derive(Debug, thiserror::Error)]
pub enum AgentError {
    #[error("HTTP error: {0}")]
    HttpError(String),
    #[error("API error {status}: {body}")]
    ApiError { status: u16, body: String },
    #[error("stream error: {0}")]
    StreamError(String),
    #[error("provider error: {0}")]
    Provider(String),
    #[error("tool error [{tool}]: {message}")]
    ToolError { tool: String, message: String },
    #[error("vault error: {0}")]
    Vault(String),
    #[error("permission denied for tool: {0}")]
    PermissionDenied(String),
    #[error("context overflow and compaction failed")]
    CompactionFailed,
    #[error("max turns exceeded: {0}")]
    MaxTurnsExceeded(u32),
    #[error("serialization error: {0}")]
    Serialization(String),
    #[error("invalid config: {0}")]
    InvalidConfig(String),
    #[error("agent cancelled")]
    Cancelled,
}

pub async fn run_agent_loop(
    session_id: String,
    objective: String,
    provider: Arc<dyn AgentProvider>,
    tool_registry: Arc<ToolRegistry>,
    delegate: Arc<dyn AgentEventDelegate>,
    config: AgentConfig,
    cancel: CancellationToken,
) -> Result<AgentResult, AgentError> {
    let mut messages = vec![Message::user_text(&objective)];
    let mut turn_count = 0_u32;
    let mut total_usage = TokenUsage::default();
    let mut trajectory_tool_calls: Vec<(String, String, String, bool)> = Vec::new();
    let max_turns = config.max_turns.unwrap_or(25);
    let smart_approval = Arc::new(SmartApproval::new(
        SmartApprovalConfig::default(),
        config.vault_root.as_ref().map(std::path::PathBuf::from),
    ));

    GlobalSessions::append_transcript_turn(
        &session_id,
        TranscriptTurn {
            timestamp: chrono::Utc::now(),
            role: "user".to_string(),
            content: objective.clone(),
            model: None,
            tokens: None,
            tool_calls: Vec::new(),
            latency_ms: None,
        },
    );

    // 5-tier context injection: load identity, facts, skills, and episodes from the vault
    let context_notes = if let Some(ref vault_root) = config.vault_root {
        let vault_path = std::path::Path::new(vault_root);
        let session_ctx = crate::context_loader::load_session_context(
            tool_registry.vault(),
            vault_path,
            &objective,
            config.context_threshold,
        )
        .await;
        let xml = session_ctx.to_xml();
        if xml.is_empty() {
            // Fallback to simple vault search if context loader found nothing
            tool_registry
                .vault_search(&objective, 5)
                .await
                .unwrap_or_default()
        } else {
            vec![xml]
        }
    } else {
        // No vault root configured — use simple search
        tool_registry
            .vault_search(&objective, 5)
            .await
            .unwrap_or_default()
    };
    let prompt_mode = config
        .prompt_mode_override
        .unwrap_or_else(|| prompt_mode_for_objective(&objective));

    // Read knowledge index from vault if available (written by Swift KnowledgeIndexBuilder)
    let knowledge_index = if let Some(ref root) = config.vault_root {
        let index_path = format!("{}/.epistemos/knowledge_index.md", root);
        std::fs::read_to_string(&index_path).ok()
    } else {
        None
    };

    let system_prompt = build_system_prompt_with_index(
        config.system_prompt.as_deref(),
        &context_notes,
        prompt_mode,
        knowledge_index.as_deref(),
    );

    loop {
        turn_count += 1;
        if turn_count > max_turns {
            let error = AgentError::MaxTurnsExceeded(max_turns);
            delegate.on_error(error.to_string());
            return Err(error);
        }

        if cancel.is_cancelled() {
            return Err(AgentError::Cancelled);
        }

        delegate.on_turn_started(turn_count, messages.len() as u32);

        // Proactive compaction: compact BEFORE the API call if context is above 80%
        // of the threshold. This prevents the API from rejecting an oversized request
        // (reactive compaction only fires after tool results, which may be too late
        // if a single large tool output pushed us past the limit).
        let proactive_threshold = config.context_threshold * 4 / 5; // 80% of limit
        let pre_flight_tokens = estimate_tokens(&messages);
        if pre_flight_tokens > proactive_threshold {
            delegate.on_context_compacting(pre_flight_tokens as u32);
            messages = provider
                .compact(&messages)
                .await
                .map_err(|_| AgentError::CompactionFailed)?;
            delegate.on_context_compacted(messages.len() as u32);
            GlobalSessions::append_trace_event(
                &session_id,
                TraceEvent {
                    timestamp: chrono::Utc::now(),
                    kind: "compaction".to_string(),
                    name: None,
                    input_summary: Some(format!(
                        "{pre_flight_tokens} tokens before pre-flight compaction"
                    )),
                    output_summary: Some(format!("{} messages retained", messages.len())),
                    duration_ms: None,
                    outcome: Some("success".to_string()),
                },
            );
        }

        let tools = tool_registry.get_definitions();
        let mut turn_config = config.clone();
        turn_config.system_prompt = Some(system_prompt.clone());

        let mut stream = provider
            .stream_message(&messages, &tools, &turn_config)
            .await?;

        let mut response_blocks = Vec::new();
        let mut stop_reason = StopReason::EndTurn;
        let mut turn_usage = TokenUsage::default();

        while let Some(event_result) = stream.next().await {
            if cancel.is_cancelled() {
                return Err(AgentError::Cancelled);
            }

            match event_result? {
                StreamEvent::ThinkingDelta { text, .. } => {
                    delegate.on_thinking_delta(text);
                }
                StreamEvent::TextDelta { text, .. } => {
                    delegate.on_text_delta(text);
                }
                StreamEvent::InputJsonDelta {
                    index,
                    partial_json,
                } => {
                    delegate.on_tool_input_delta(index as u32, partial_json);
                }
                StreamEvent::SignatureDelta { .. } => {}
                StreamEvent::ContentBlockComplete { block } => {
                    if let ContentBlock::ToolUse { id, name, input } = &block {
                        let input_json = serde_json::to_string(input)
                            .map_err(|error| AgentError::Serialization(error.to_string()))?;
                        delegate.on_tool_started(id.clone(), name.clone(), input_json);
                    }
                    response_blocks.push(block);
                }
                StreamEvent::MessageStop {
                    stop_reason: reason,
                    usage,
                } => {
                    stop_reason = reason;
                    turn_usage = usage;
                    break;
                }
            }
        }

        total_usage.input_tokens = total_usage
            .input_tokens
            .saturating_add(turn_usage.input_tokens);
        total_usage.output_tokens = total_usage
            .output_tokens
            .saturating_add(turn_usage.output_tokens);
        total_usage.cache_creation_input_tokens = total_usage
            .cache_creation_input_tokens
            .saturating_add(turn_usage.cache_creation_input_tokens);
        total_usage.cache_read_input_tokens = total_usage
            .cache_read_input_tokens
            .saturating_add(turn_usage.cache_read_input_tokens);

        // Budget enforcement: estimate cost and check against limit
        if let Some(budget) = config.max_cost_usd {
            // Rough cost estimate based on Claude Sonnet 4.6 pricing ($3/$15 per MTok)
            // This is conservative — actual cost varies by provider
            let estimated_cost = (total_usage.input_tokens as f64 * 3.0
                + total_usage.output_tokens as f64 * 15.0)
                / 1_000_000.0;
            if estimated_cost >= budget {
                let msg = format!(
                    "Budget limit ${:.2} reached (estimated ${:.2} spent). Task paused.",
                    budget, estimated_cost
                );
                delegate.on_error(msg.clone());
                let transcript_turn = build_assistant_transcript_turn(
                    provider.name(),
                    &response_blocks,
                    &[],
                    turn_usage.output_tokens,
                );
                GlobalSessions::append_transcript_turn(&session_id, transcript_turn);
                messages.push(Message::assistant(response_blocks));
                return Ok(AgentResult {
                    final_content: vec![ContentBlock::Text { text: msg }],
                    full_history: messages,
                    turns: turn_count,
                    total_usage,
                    trajectory_metrics: compute_trajectory_metrics(&trajectory_tool_calls),
                });
            }
        }

        match stop_reason {
            StopReason::EndTurn | StopReason::StopSequence => {
                let transcript_turn = build_assistant_transcript_turn(
                    provider.name(),
                    &response_blocks,
                    &[],
                    turn_usage.output_tokens,
                );
                GlobalSessions::append_transcript_turn(&session_id, transcript_turn);
                messages.push(Message::assistant(response_blocks.clone()));
                delegate.on_complete(
                    match stop_reason {
                        StopReason::EndTurn => "end_turn".to_string(),
                        StopReason::StopSequence => "stop_sequence".to_string(),
                        _ => unreachable!(),
                    },
                    total_usage.input_tokens,
                    total_usage.output_tokens,
                );
                return Ok(AgentResult {
                    final_content: response_blocks,
                    full_history: messages,
                    turns: turn_count,
                    total_usage,
                    trajectory_metrics: compute_trajectory_metrics(&trajectory_tool_calls),
                });
            }
            StopReason::ToolUse => {
                let tool_calls = extract_tool_calls(&response_blocks);

                messages.push(Message::assistant(response_blocks.clone()));

                let results = if config.parallel_tool_execution {
                    execute_tools_parallel(
                        &session_id,
                        &tool_calls,
                        &tool_registry,
                        &delegate,
                        &smart_approval,
                        &config.permissions,
                        &cancel,
                    )
                    .await?
                } else {
                    execute_tools_sequential(
                        &session_id,
                        &tool_calls,
                        &tool_registry,
                        &delegate,
                        &smart_approval,
                        &config.permissions,
                        &cancel,
                    )
                    .await?
                };

                for result in &results {
                    let result_text = result
                        .content
                        .iter()
                        .filter_map(|content| match content {
                            ToolResultContent::Text { text } => Some(text.as_str()),
                            ToolResultContent::Image { .. } => None,
                        })
                        .collect::<Vec<_>>()
                        .join("");
                    delegate.on_tool_completed(
                        result.tool_use_id.clone(),
                        result_text,
                        result.is_error,
                    );
                }

                for ((_, name, input), result) in tool_calls.iter().zip(results.iter()) {
                    let args_json = serde_json::to_string(input)
                        .map_err(|error| AgentError::Serialization(error.to_string()))?;
                    let result_text = result
                        .content
                        .iter()
                        .filter_map(|content| match content {
                            ToolResultContent::Text { text } => Some(text.as_str()),
                            ToolResultContent::Image { .. } => None,
                        })
                        .collect::<Vec<_>>()
                        .join("");
                    trajectory_tool_calls.push((
                        name.clone(),
                        args_json,
                        result_text,
                        result.is_error,
                    ));
                }

                let tool_records = build_tool_call_records(&tool_calls, &results)?;
                let transcript_turn = build_assistant_transcript_turn(
                    provider.name(),
                    &response_blocks,
                    &tool_records,
                    turn_usage.output_tokens,
                );
                GlobalSessions::append_transcript_turn(&session_id, transcript_turn);

                messages.push(Message::user_tool_results(results));

                // Write transparent working memory — user can open and edit this file
                if let Some(ref root) = config.vault_root {
                    let wm_path = format!(
                        "{}/.epistemos/sessions/{}/working-memory.md",
                        root, session_id
                    );
                    if let Some(parent) = std::path::Path::new(&wm_path).parent() {
                        let _ = std::fs::create_dir_all(parent);
                    }
                    let wm_content = format!(
                        "---\nsession_id: {}\nobjective: \"{}\"\nstatus: running\nturn: {}\n---\n\n\
                         ## Goal\n{}\n\n\
                         ## Progress\n{} turns completed, {} messages in context.\n",
                        session_id,
                        objective.replace('"', "'"),
                        turn_count,
                        objective,
                        turn_count,
                        messages.len(),
                    );
                    let _ = std::fs::write(&wm_path, &wm_content);
                }

                let estimated_tokens = estimate_tokens(&messages);
                if estimated_tokens > config.context_threshold {
                    delegate.on_context_compacting(estimated_tokens as u32);
                    messages = provider
                        .compact(&messages)
                        .await
                        .map_err(|_| AgentError::CompactionFailed)?;
                    delegate.on_context_compacted(messages.len() as u32);
                    GlobalSessions::append_trace_event(
                        &session_id,
                        TraceEvent {
                            timestamp: chrono::Utc::now(),
                            kind: "compaction".to_string(),
                            name: None,
                            input_summary: Some(format!(
                                "{estimated_tokens} tokens before reactive compaction"
                            )),
                            output_summary: Some(format!("{} messages retained", messages.len())),
                            duration_ms: None,
                            outcome: Some("success".to_string()),
                        },
                    );
                }
            }
            StopReason::MaxTokens => {
                let transcript_turn = build_assistant_transcript_turn(
                    provider.name(),
                    &response_blocks,
                    &[],
                    turn_usage.output_tokens,
                );
                GlobalSessions::append_transcript_turn(&session_id, transcript_turn);
                messages.push(Message::assistant(response_blocks.clone()));
                let tokens_before_compaction = estimate_tokens(&messages) as u32;
                delegate.on_context_compacting(tokens_before_compaction);
                messages = provider
                    .compact(&messages)
                    .await
                    .map_err(|_| AgentError::CompactionFailed)?;
                delegate.on_context_compacted(messages.len() as u32);
                GlobalSessions::append_trace_event(
                    &session_id,
                    TraceEvent {
                        timestamp: chrono::Utc::now(),
                        kind: "compaction".to_string(),
                        name: None,
                        input_summary: Some(format!(
                            "{tokens_before_compaction} tokens after max-token stop"
                        )),
                        output_summary: Some(format!("{} messages retained", messages.len())),
                        duration_ms: None,
                        outcome: Some("success".to_string()),
                    },
                );
            }
        }
    }
}

fn extract_tool_calls(blocks: &[ContentBlock]) -> Vec<(String, String, serde_json::Value)> {
    blocks
        .iter()
        .filter_map(|block| match block {
            ContentBlock::ToolUse { id, name, input } => {
                Some((id.clone(), name.clone(), input.clone()))
            }
            _ => None,
        })
        .collect()
}

fn build_assistant_transcript_turn(
    model_name: &str,
    response_blocks: &[ContentBlock],
    tool_calls: &[ToolCallRecord],
    output_tokens: u32,
) -> TranscriptTurn {
    TranscriptTurn {
        timestamp: chrono::Utc::now(),
        role: "assistant".to_string(),
        content: summarize_response_blocks(response_blocks),
        model: Some(model_name.to_string()),
        tokens: Some(output_tokens),
        tool_calls: tool_calls.to_vec(),
        latency_ms: None,
    }
}

fn build_tool_call_records(
    tool_calls: &[(String, String, serde_json::Value)],
    results: &[ToolResult],
) -> Result<Vec<ToolCallRecord>, AgentError> {
    tool_calls
        .iter()
        .zip(results.iter())
        .map(|((id, name, input), result)| {
            let input_summary = serde_json::to_string(input)
                .map_err(|error| AgentError::Serialization(error.to_string()))?;
            let result_summary = result
                .content
                .iter()
                .filter_map(|content| match content {
                    ToolResultContent::Text { text } => Some(text.as_str()),
                    ToolResultContent::Image { .. } => None,
                })
                .collect::<Vec<_>>()
                .join("");

            Ok(ToolCallRecord {
                name: name.clone(),
                tool_use_id: id.clone(),
                input_summary: Some(truncate_tool_output(input_summary, 240)),
                result_summary: Some(truncate_tool_output(result_summary, 240)),
                is_error: result.is_error,
            })
        })
        .collect()
}

fn summarize_response_blocks(response_blocks: &[ContentBlock]) -> String {
    let text = response_blocks
        .iter()
        .filter_map(|block| match block {
            ContentBlock::Text { text } => Some(text.as_str()),
            ContentBlock::Thinking { .. } | ContentBlock::ToolUse { .. } => None,
        })
        .collect::<Vec<_>>()
        .join("\n");
    let trimmed = text.trim();
    if trimmed.is_empty() {
        "[tool-only turn]".to_string()
    } else {
        trimmed.to_string()
    }
}

async fn execute_tools_parallel(
    session_id: &str,
    tool_calls: &[(String, String, serde_json::Value)],
    tool_registry: &Arc<ToolRegistry>,
    delegate: &Arc<dyn AgentEventDelegate>,
    smart_approval: &Arc<SmartApproval>,
    permissions: &PermissionConfig,
    cancel: &CancellationToken,
) -> Result<Vec<ToolResult>, AgentError> {
    let futures = tool_calls.iter().map(|(id, name, input)| {
        execute_one_tool(
            session_id.to_string(),
            id.clone(),
            name.clone(),
            input.clone(),
            Arc::clone(tool_registry),
            Arc::clone(delegate),
            Arc::clone(smart_approval),
            permissions.clone(),
            cancel.clone(),
        )
    });

    try_join_all(futures).await
}

async fn execute_tools_sequential(
    session_id: &str,
    tool_calls: &[(String, String, serde_json::Value)],
    tool_registry: &Arc<ToolRegistry>,
    delegate: &Arc<dyn AgentEventDelegate>,
    smart_approval: &Arc<SmartApproval>,
    permissions: &PermissionConfig,
    cancel: &CancellationToken,
) -> Result<Vec<ToolResult>, AgentError> {
    let mut results = Vec::with_capacity(tool_calls.len());
    for (id, name, input) in tool_calls {
        results.push(
            execute_one_tool(
                session_id.to_string(),
                id.clone(),
                name.clone(),
                input.clone(),
                Arc::clone(tool_registry),
                Arc::clone(delegate),
                Arc::clone(smart_approval),
                permissions.clone(),
                cancel.clone(),
            )
            .await?,
        );
    }
    Ok(results)
}

async fn execute_one_tool(
    session_id: String,
    id: String,
    name: String,
    input: serde_json::Value,
    tool_registry: Arc<ToolRegistry>,
    delegate: Arc<dyn AgentEventDelegate>,
    smart_approval: Arc<SmartApproval>,
    permissions: PermissionConfig,
    cancel: CancellationToken,
) -> Result<ToolResult, AgentError> {
    if cancel.is_cancelled() {
        return Err(AgentError::Cancelled);
    }

    let risk = tool_risk_level(&name, &input, &tool_registry);
    let permission_auto_approved = match risk {
        RiskLevel::ReadOnly => permissions.auto_approve_read_only,
        RiskLevel::Modification => permissions.auto_approve_modification,
        RiskLevel::Destructive => permissions.auto_approve_destructive,
    };
    let input_json = serde_json::to_string(&input)
        .map_err(|error| AgentError::Serialization(error.to_string()))?;
    let approval_decision = smart_approval.assess(&name, &input_json, &session_id);
    let approval_key = approval_key(&name, &input_json);
    let approval_requirement =
        match resolve_approval_requirement(risk, permission_auto_approved, approval_decision) {
            Ok(requirement) => requirement,
            Err(reason) => {
                GlobalSessions::append_trace_event(
                    &session_id,
                    TraceEvent {
                        timestamp: chrono::Utc::now(),
                        kind: "approval".to_string(),
                        name: Some(name.clone()),
                        input_summary: Some(truncate_tool_output(input_json.clone(), 512)),
                        output_summary: Some(reason.clone()),
                        duration_ms: None,
                        outcome: Some("denied".to_string()),
                    },
                );
                return Ok(ToolResult::text(
                    id,
                    format!("Tool execution denied: {reason}"),
                    true,
                ));
            }
        };

    let mut is_execution_approved = permission_auto_approved && approval_requirement.is_none();
    if let Some(requirement) = approval_requirement {
        let permission_id = uuid::Uuid::new_v4().to_string();
        let deadline_secs = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs()
            .saturating_add(120);
        GlobalSessions::pause_for_approval(&session_id, &name, &input_json, deadline_secs);
        delegate.on_permission_required(
            permission_id.clone(),
            name.clone(),
            input_json.clone(),
            requirement.risk_level.clone(),
        );

        let approved = delegate.wait_for_permission(permission_id);
        GlobalSessions::resume_from_approval(&session_id);
        smart_approval.record_decision(&session_id, &approval_key, approved);
        GlobalSessions::append_trace_event(
            &session_id,
            TraceEvent {
                timestamp: chrono::Utc::now(),
                kind: "approval".to_string(),
                name: Some(name.clone()),
                input_summary: Some(truncate_tool_output(input_json.clone(), 512)),
                output_summary: Some(requirement.reason.clone()),
                duration_ms: None,
                outcome: Some(if approved { "approved" } else { "denied" }.to_string()),
            },
        );

        if !approved {
            return Ok(ToolResult::text(id, "Tool execution denied by user.", true));
        }
        is_execution_approved = true;
    }

    // Security: classify command risk for bash/shell tools.
    if name == "bash_execute" || name == "shell" {
        if let Some(command) = input.get("command").and_then(serde_json::Value::as_str) {
            let risk = crate::security::classify_command_risk(command);
            if risk.level == crate::security::CommandRiskLevel::Forbidden {
                return Ok(ToolResult::text(
                    id,
                    format!("Command blocked (forbidden): {}", risk.reasons.join(", ")),
                    true,
                ));
            }
            if risk.level == crate::security::CommandRiskLevel::Dangerous && !is_execution_approved
            {
                return Ok(ToolResult::text(
                    id,
                    format!(
                        "Command requires approval (dangerous): {}",
                        risk.reasons.join(", ")
                    ),
                    true,
                ));
            }
        }
    }

    if name == "computer" {
        let output = delegate.execute_computer_action(input_json.clone());
        let is_error = serde_json::from_str::<serde_json::Value>(&output)
            .ok()
            .and_then(|value| value.get("success").and_then(serde_json::Value::as_bool))
            .map(|success| !success)
            .unwrap_or(false);
        let redacted = crate::security::redact_credentials(&output);
        let truncated = truncate_tool_output(redacted.into_owned(), 16_384);
        GlobalSessions::append_trace_event(
            &session_id,
            TraceEvent {
                timestamp: chrono::Utc::now(),
                kind: "tool_call".to_string(),
                name: Some(name.clone()),
                input_summary: Some(truncate_tool_output(input_json.clone(), 512)),
                output_summary: Some(truncate_tool_output(truncated.clone(), 512)),
                duration_ms: None,
                outcome: Some(if is_error { "error" } else { "success" }.to_string()),
            },
        );
        return Ok(ToolResult::text(id, truncated, is_error));
    }

    match tool_registry.execute(&name, &input).await {
        Ok(output) => {
            // Security: redact credentials from tool output.
            let redacted = crate::security::redact_credentials(&output);
            // Security: run the comprehensive 40+ rule scanner (Hermes
            // skills_guard + OpenClaw tirith_security). Critical hits are
            // converted into an is_error tool result so the agent sees a
            // hard block it can recover from; High hits are logged; Medium
            // and Low are ignored in the hot path.
            let scan = crate::security::scan_tool_output(&redacted);
            if let Some(max_severity) = scan.max_severity() {
                if max_severity >= crate::security::Severity::Critical {
                    let reasons: Vec<String> = scan
                        .threats
                        .iter()
                        .filter(|t| t.severity >= crate::security::Severity::Critical)
                        .map(|t| t.description.clone())
                        .collect();
                    tracing::error!(
                        tool = %name,
                        "Security scan BLOCKED tool output: {reasons:?}"
                    );
                    return Ok(ToolResult::text(
                        id,
                        format!(
                            "Tool output blocked by security scanner (critical threats): {}",
                            reasons.join(", ")
                        ),
                        true,
                    ));
                }
                if max_severity >= crate::security::Severity::High {
                    tracing::warn!(
                        tool = %name,
                        "Security scan flagged tool output: {:?}",
                        scan.threats.iter().map(|t| &t.description).collect::<Vec<_>>()
                    );
                }
            }
            let truncated = truncate_tool_output(redacted.into_owned(), 16_384);
            GlobalSessions::append_trace_event(
                &session_id,
                TraceEvent {
                    timestamp: chrono::Utc::now(),
                    kind: "tool_call".to_string(),
                    name: Some(name.clone()),
                    input_summary: Some(truncate_tool_output(input_json.clone(), 512)),
                    output_summary: Some(truncate_tool_output(truncated.clone(), 512)),
                    duration_ms: None,
                    outcome: Some("success".to_string()),
                },
            );
            Ok(ToolResult::text(id, truncated, false))
        }
        Err(error) => {
            let message = format!("Tool error: {error}");
            GlobalSessions::append_trace_event(
                &session_id,
                TraceEvent {
                    timestamp: chrono::Utc::now(),
                    kind: "tool_call".to_string(),
                    name: Some(name.clone()),
                    input_summary: Some(truncate_tool_output(input_json, 512)),
                    output_summary: Some(truncate_tool_output(message.clone(), 512)),
                    duration_ms: None,
                    outcome: Some("error".to_string()),
                },
            );
            Ok(ToolResult::text(id, message, true))
        }
    }
}

fn tool_risk_level(
    name: &str,
    input: &serde_json::Value,
    tool_registry: &ToolRegistry,
) -> RiskLevel {
    if name == "computer" {
        return match input.get("action").and_then(serde_json::Value::as_str) {
            Some("screenshot") | Some("get_ax_tree") => RiskLevel::ReadOnly,
            Some("delete_file") => RiskLevel::Destructive,
            _ => RiskLevel::Modification,
        };
    }

    tool_registry.get_risk_level(name)
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct ApprovalRequirement {
    risk_level: String,
    reason: String,
}

fn resolve_approval_requirement(
    risk: RiskLevel,
    permission_auto_approved: bool,
    smart_decision: ApprovalDecision,
) -> Result<Option<ApprovalRequirement>, String> {
    match smart_decision {
        ApprovalDecision::Deny { reason } => Err(reason),
        ApprovalDecision::RequireApproval { reason, risk_level } => {
            Ok(Some(ApprovalRequirement { risk_level, reason }))
        }
        ApprovalDecision::AutoApprove => {
            if permission_auto_approved {
                Ok(None)
            } else {
                Ok(Some(ApprovalRequirement {
                    risk_level: risk.as_str().to_string(),
                    reason: "Tool policy requires approval.".to_string(),
                }))
            }
        }
    }
}

fn prompt_mode_for_objective(objective: &str) -> PromptMode {
    let normalized = objective.to_lowercase();
    if contains_any(
        &normalized,
        &["code", "swift", "rust", "bug", "test", "compile"],
    ) {
        PromptMode::Code
    } else if contains_any(
        &normalized,
        &[
            "research", "compare", "cite", "citation", "source", "latest", "current", "web",
        ],
    ) {
        PromptMode::Research
    } else {
        PromptMode::General
    }
}

fn contains_any(haystack: &str, needles: &[&str]) -> bool {
    needles.iter().any(|needle| haystack.contains(needle))
}

fn estimate_tokens(messages: &[Message]) -> usize {
    let characters: usize = messages
        .iter()
        .map(|message| match message {
            Message::User { content } => content
                .iter()
                .map(|content| match content {
                    crate::types::UserContent::Text { text } => text.len(),
                    crate::types::UserContent::ToolResult(result) => result
                        .content
                        .iter()
                        .map(|content| match content {
                            ToolResultContent::Text { text } => text.len(),
                            ToolResultContent::Image { .. } => 1_000,
                        })
                        .sum::<usize>(),
                    crate::types::UserContent::Image { .. } => 1_000,
                })
                .sum::<usize>(),
            Message::Assistant { content } => content
                .iter()
                .map(|block| match block {
                    ContentBlock::Thinking {
                        thinking,
                        signature,
                    } => thinking.len() + signature.len(),
                    ContentBlock::Text { text } => text.len(),
                    ContentBlock::ToolUse { name, input, .. } => {
                        name.len() + input.to_string().len()
                    }
                })
                .sum::<usize>(),
        })
        .sum::<usize>();

    characters / 4
}

fn truncate_tool_output(output: String, max_chars: usize) -> String {
    let total_chars = output.chars().count();
    if total_chars <= max_chars {
        return output;
    }

    let keep_each_side = max_chars / 2;
    let prefix: String = output.chars().take(keep_each_side).collect();
    let suffix: String = output
        .chars()
        .rev()
        .take(keep_each_side)
        .collect::<Vec<_>>()
        .into_iter()
        .rev()
        .collect();

    format!(
        "{prefix}\n\n[... {} chars truncated ...]\n\n{suffix}",
        total_chars.saturating_sub(max_chars)
    )
}

#[cfg(test)]
mod tests {
    use super::{estimate_tokens, resolve_approval_requirement, truncate_tool_output};
    use crate::approval::ApprovalDecision;
    use crate::tools::registry::RiskLevel;
    use crate::types::{ContentBlock, Message, ToolResult, UserContent};

    #[test]
    fn truncates_tool_output_without_breaking_unicode_boundaries() {
        let output = "αβγδεζηθικλμνξοπρστυφχψω".repeat(8);
        let truncated = truncate_tool_output(output.clone(), 20);
        assert!(truncated.contains("[..."));
        assert!(truncated.is_char_boundary(truncated.len()));
        assert!(truncated.len() < output.len());
    }

    #[test]
    fn estimates_tokens_from_mixed_history() {
        let messages = vec![
            Message::User {
                content: vec![
                    UserContent::Text {
                        text: "hello world".to_string(),
                    },
                    UserContent::ToolResult(ToolResult::text("tool-1", "tool output", false)),
                ],
            },
            Message::assistant(vec![
                ContentBlock::Thinking {
                    thinking: "plan".to_string(),
                    signature: "sig".to_string(),
                },
                ContentBlock::Text {
                    text: "done".to_string(),
                },
            ]),
        ];

        assert!(estimate_tokens(&messages) > 0);
    }

    #[test]
    fn smart_approval_requirement_overrides_auto_approved_risk_tier() {
        let requirement = resolve_approval_requirement(
            RiskLevel::ReadOnly,
            true,
            ApprovalDecision::RequireApproval {
                reason: "tirith flagged suspicious clipboard exfiltration".to_string(),
                risk_level: "high".to_string(),
            },
        )
        .expect("smart approval should not deny")
        .expect("smart approval should still require confirmation");

        assert_eq!(requirement.risk_level, "high");
        assert!(requirement
            .reason
            .contains("tirith flagged suspicious clipboard exfiltration"));
    }

    #[test]
    fn permission_policy_still_requires_approval_when_smart_guard_auto_approves() {
        let requirement = resolve_approval_requirement(
            RiskLevel::Modification,
            false,
            ApprovalDecision::AutoApprove,
        )
        .expect("permission policy should not deny")
        .expect("writes should still require approval when auto-approve is disabled");

        assert_eq!(requirement.risk_level, "modification");
        assert!(requirement.reason.contains("Tool policy requires approval"));
    }

    #[test]
    fn smart_approval_denials_short_circuit_execution() {
        let denial = resolve_approval_requirement(
            RiskLevel::Destructive,
            false,
            ApprovalDecision::Deny {
                reason: "Command matches permanent blocklist".to_string(),
            },
        )
        .expect_err("smart approval denial should short-circuit");

        assert!(denial.contains("blocklist"));
    }
}
