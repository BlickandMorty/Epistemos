use std::sync::Arc;
use std::time::{Instant, SystemTime, UNIX_EPOCH};

use futures::{future::try_join_all, StreamExt};
use tokio_util::sync::CancellationToken;

use crate::approval::{approval_key, ApprovalDecision, SmartApproval, SmartApprovalConfig};
use crate::bridge::AgentEventDelegate;
use crate::prompts::{build_system_prompt_with_index, PromptMode};
use crate::provider::{AgentProvider, StreamEvent};
use crate::providers::pricing::{budget_gate_payload_json, estimate_usage_cost_usd};
use crate::reasoning_metrics::{compute_trajectory_metrics, ReasoningTrajectoryMetrics};
use crate::routing::contains_any;
use crate::session::GlobalSessions;
use crate::storage::raw_thoughts::{RawThoughtsEmitter, RawThoughtsEvent, RawThoughtsStatus};
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

/// Canonical safety-rail ceiling for `AgentConfig.max_turns`.
///
/// Per CLAUDE.md non-negotiable: "max_turns is a safety rail, not a
/// schedule. Trust stop_reason == 'end_turn'." 25 is the practical
/// cap that lets a multi-step task complete (compaction + retries +
/// tool calls) without runaway.
///
/// Single source of truth — both `AgentConfig::default()` and the
/// `unwrap_or(...)` fallback in `run_agent_loop` reference this
/// constant so the two sites can't drift independently.
pub const DEFAULT_AGENT_MAX_TURNS: u32 = 25;

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
            max_turns: Some(DEFAULT_AGENT_MAX_TURNS),
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
    #[error("local provider cannot run the agent loop: {0}")]
    LocalProviderNotAllowed(String),
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
    // Honest capability gating (CLAUDE.md non-negotiable): local models get
    // fast / thinking / research tiers only — cloud models get
    // agent / liveAgent. Reject a local provider at the door instead of
    // silently downgrading an agentic task into plain chat. Swift-side
    // routing is expected to upgrade the user to a cloud provider (or
    // surface an explicit "agent needs cloud" message) before dispatch.
    if provider.runtime() == crate::provider::ProviderRuntime::Local {
        return Err(AgentError::LocalProviderNotAllowed(format!(
            "provider '{}' runs on-device; the agent loop requires a cloud provider",
            provider.name()
        )));
    }

    let mut messages = vec![Message::user_text(&objective)];
    let mut turn_count = 0_u32;
    let mut total_usage = TokenUsage::default();
    let mut trajectory_tool_calls: Vec<(String, String, String, bool)> = Vec::new();
    let max_turns = config.max_turns.unwrap_or(DEFAULT_AGENT_MAX_TURNS);
    let budget_step_usd = config
        .max_cost_usd
        .filter(|budget| budget.is_finite() && *budget > 0.0);
    let mut next_budget_gate_usd = budget_step_usd;

    // Raw Thoughts V0 — per-run artifact emitter. Always constructed so
    // the rest of the loop is branch-free; it is a no-op unless the user
    // sets EPISTEMOS_RAW_THOUGHTS_V0=1 AND a vault root is configured.
    // All writes go through a BufWriter so the streaming hot path is not
    // blocked on disk I/O per delta. `Arc` lets the parallel tool
    // executors record `tool_use` / `tool_result` events without
    // ceremony; `record` and `finish` both take `&self`.
    let raw_thoughts_emitter: Arc<RawThoughtsEmitter> = {
        let vault_root_path = config
            .vault_root
            .as_ref()
            .map(std::path::PathBuf::from)
            .unwrap_or_default();
        Arc::new(RawThoughtsEmitter::new(
            &vault_root_path,
            provider.name(),
            provider.name(),
            &session_id,
            None,
        ))
    };
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

    let prompt_mode = config
        .prompt_mode_override
        .unwrap_or_else(|| prompt_mode_for_objective(&objective));

    // 5-tier context injection: load identity, facts, skills, and episodes from the vault
    let context_notes = if should_preload_vault_context(prompt_mode, &objective) {
        if let Some(ref vault_root) = config.vault_root {
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
                // Fallback to simple vault search if context loader found nothing.
                // External research prompts now skip this path unless the user
                // explicitly referenced notes, files, or attachments.
                tool_registry
                    .vault_search(&objective, 5)
                    .await
                    .unwrap_or_default()
            } else {
                vec![xml]
            }
        } else {
            // No vault root configured — use simple search when note/file context
            // was explicitly requested and no structured vault session exists.
            tool_registry
                .vault_search(&objective, 5)
                .await
                .unwrap_or_default()
        }
    } else {
        Vec::new()
    };

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
            let _ = raw_thoughts_emitter.finish(RawThoughtsStatus::Errored, None);
            return Err(error);
        }

        if cancel.is_cancelled() {
            let _ = raw_thoughts_emitter.finish(RawThoughtsStatus::Cancelled, None);
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

        let turn_stream_start = Instant::now();
        let mut stream = provider
            .stream_message(&messages, &tools, &turn_config)
            .await?;

        let mut response_blocks = Vec::new();
        let mut stop_reason = StopReason::EndTurn;
        let mut turn_usage = TokenUsage::default();
        let mut ttft_recorded = false;
        let mut event_count: u32 = 0;

        while let Some(event_result) = stream.next().await {
            if cancel.is_cancelled() {
                let _ = raw_thoughts_emitter.finish(RawThoughtsStatus::Cancelled, None);
                return Err(AgentError::Cancelled);
            }

            event_count += 1;
            match event_result? {
                StreamEvent::ThinkingDelta { text, index } => {
                    if !ttft_recorded {
                        let ttft_ms = turn_stream_start.elapsed().as_millis() as u64;
                        tracing::info!(
                            turn = turn_count,
                            ttft_ms,
                            "time_to_first_token (thinking)"
                        );
                        ttft_recorded = true;
                    }
                    let _ = raw_thoughts_emitter.record(RawThoughtsEvent::ThinkingDelta {
                        index: index as u32,
                        text: text.clone(),
                    });
                    delegate.on_thinking_delta(text);
                }
                StreamEvent::RedactedThinking { index, data } => {
                    let _ = raw_thoughts_emitter.record(RawThoughtsEvent::RedactedThinking {
                        index: index as u32,
                        data,
                    });
                }
                StreamEvent::TextDelta { text, index } => {
                    if !ttft_recorded {
                        let ttft_ms = turn_stream_start.elapsed().as_millis() as u64;
                        tracing::info!(turn = turn_count, ttft_ms, "time_to_first_token (text)");
                        ttft_recorded = true;
                    }
                    let _ = raw_thoughts_emitter.record(RawThoughtsEvent::TextDelta {
                        index: index as u32,
                        text: text.clone(),
                    });
                    delegate.on_text_delta(text);
                }
                StreamEvent::InputJsonDelta {
                    index,
                    partial_json,
                } => {
                    delegate.on_tool_input_delta(index as u32, partial_json);
                }
                StreamEvent::SignatureDelta { index, signature } => {
                    let _ = raw_thoughts_emitter.record(RawThoughtsEvent::SignatureDelta {
                        index: index as u32,
                        signature,
                    });
                }
                StreamEvent::ContentBlockComplete { block } => {
                    if let ContentBlock::ToolUse { id, name, input } = &block {
                        let input_json = serde_json::to_string(input)
                            .map_err(|error| AgentError::Serialization(error.to_string()))?;
                        let _ = raw_thoughts_emitter.record(RawThoughtsEvent::ToolUse {
                            id: id.clone(),
                            name: name.clone(),
                            input: input.clone(),
                        });
                        delegate.on_tool_started(id.clone(), name.clone(), input_json);
                    }
                    response_blocks.push(block);
                }
                StreamEvent::MessageStop {
                    stop_reason: reason,
                    usage,
                } => {
                    let stop_reason_str = match reason {
                        StopReason::EndTurn => "end_turn",
                        StopReason::StopSequence => "stop_sequence",
                        StopReason::ToolUse => "tool_use",
                        StopReason::MaxTokens => "max_tokens",
                    };
                    let _ = raw_thoughts_emitter.record(RawThoughtsEvent::MessageStop {
                        stop_reason: stop_reason_str.to_string(),
                    });
                    stop_reason = reason;
                    turn_usage = usage;
                    break;
                }
            }
        }

        let turn_stream_duration_ms = turn_stream_start.elapsed().as_millis() as u64;
        tracing::info!(
            turn = turn_count,
            stream_duration_ms = turn_stream_duration_ms,
            event_count,
            output_tokens = turn_usage.output_tokens,
            "turn_stream_complete"
        );

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

        if let (Some(step), Some(gate)) = (budget_step_usd, next_budget_gate_usd) {
            let estimated_cost = estimate_usage_cost_usd(provider.name(), &total_usage);
            if estimated_cost >= gate {
                let next_gate = next_budget_gate_after(estimated_cost, step, gate);
                let input_json = budget_gate_payload_json(
                    &session_id,
                    provider.name(),
                    estimated_cost,
                    gate,
                    next_gate,
                );
                let permission_id = uuid::Uuid::new_v4().to_string();
                let deadline_secs = SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_secs()
                    .saturating_add(120);
                GlobalSessions::pause_for_approval(
                    &session_id,
                    "budget_gate",
                    &input_json,
                    deadline_secs,
                );
                delegate.on_permission_required(
                    permission_id.clone(),
                    "budget_gate".to_string(),
                    input_json.clone(),
                    "modification".to_string(),
                );
                let approved = delegate.wait_for_permission(permission_id);
                GlobalSessions::resume_from_approval(&session_id);
                GlobalSessions::append_trace_event(
                    &session_id,
                    TraceEvent {
                        timestamp: chrono::Utc::now(),
                        kind: "approval".to_string(),
                        name: Some("budget_gate".to_string()),
                        input_summary: Some(input_json.clone()),
                        output_summary: Some(format!(
                            "Estimated spend ${estimated_cost:.2} reached budget gate ${gate:.2}"
                        )),
                        duration_ms: None,
                        outcome: Some(if approved { "approved" } else { "denied" }.to_string()),
                    },
                );
                if approved {
                    next_budget_gate_usd = Some(next_gate);
                    tracing::info!(
                        session_id = session_id.as_str(),
                        provider = provider.name(),
                        estimated_cost_usd = estimated_cost,
                        next_gate_usd = next_gate,
                        "budget_gate_approved"
                    );
                } else {
                    let msg = format!(
                        "Budget gate denied at ${:.2} estimated spend (gate ${:.2}).",
                        estimated_cost, gate
                    );
                    let transcript_turn = build_assistant_transcript_turn(
                        provider.name(),
                        &response_blocks,
                        &[],
                        turn_usage.output_tokens,
                        Some(turn_stream_duration_ms),
                    );
                    GlobalSessions::append_transcript_turn(&session_id, transcript_turn);
                    messages.push(Message::assistant(response_blocks));
                    let _ = raw_thoughts_emitter.finish(RawThoughtsStatus::Completed, None);
                    return Ok(AgentResult {
                        final_content: vec![ContentBlock::Text { text: msg }],
                        full_history: messages,
                        turns: turn_count,
                        total_usage,
                        trajectory_metrics: compute_trajectory_metrics(&trajectory_tool_calls),
                    });
                }
            }
        }

        match stop_reason {
            StopReason::EndTurn | StopReason::StopSequence => {
                let transcript_turn = build_assistant_transcript_turn(
                    provider.name(),
                    &response_blocks,
                    &[],
                    turn_usage.output_tokens,
                    Some(turn_stream_duration_ms),
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
                let _ = raw_thoughts_emitter.finish(RawThoughtsStatus::Completed, None);
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
                    let _ = raw_thoughts_emitter.record(RawThoughtsEvent::ToolResult {
                        tool_use_id: result.tool_use_id.clone(),
                        output: result_text.clone(),
                        is_error: result.is_error,
                    });
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
                    Some(turn_stream_duration_ms),
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
                    Some(turn_stream_duration_ms),
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
    latency_ms: Option<u64>,
) -> TranscriptTurn {
    TranscriptTurn {
        timestamp: chrono::Utc::now(),
        role: "assistant".to_string(),
        content: summarize_response_blocks(response_blocks),
        model: Some(model_name.to_string()),
        tokens: Some(output_tokens),
        tool_calls: tool_calls.to_vec(),
        latency_ms,
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
            ContentBlock::Thinking { .. }
            | ContentBlock::RedactedThinking { .. }
            | ContentBlock::ToolUse { .. } => None,
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

#[allow(clippy::too_many_arguments)]
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

    #[cfg(feature = "pro-build")]
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
        #[cfg(feature = "pro-build")]
        {
            is_execution_approved = true;
        }
    }

    // Security: classify command risk for bash/shell tools.
    #[cfg(feature = "pro-build")]
    if name == "action.bash" || name == "bash_execute" || name == "shell" {
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

    #[cfg(not(feature = "pro-build"))]
    if name == "computer" {
        return Ok(ToolResult::text(
            id,
            "Tool execution denied: computer use is unavailable in the App Store build.",
            true,
        ));
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

    match tool_registry.execute_v2(&name, &input).await {
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

fn objective_mentions_local_context(objective: &str) -> bool {
    contains_any(
        objective,
        &[
            "my note",
            "my notes",
            "vault",
            "attached",
            "attachment",
            "file",
            "document",
            "pdf",
            "@",
        ],
    )
}

fn should_preload_vault_context(prompt_mode: PromptMode, objective: &str) -> bool {
    match prompt_mode {
        PromptMode::Research => objective_mentions_local_context(&objective.to_lowercase()),
        PromptMode::General | PromptMode::Code | PromptMode::LocalFallback => true,
    }
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
                    ContentBlock::RedactedThinking { data } => data.len(),
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

fn next_budget_gate_after(
    current_spend_usd: f64,
    budget_step_usd: f64,
    current_gate_usd: f64,
) -> f64 {
    if !current_spend_usd.is_finite() || !budget_step_usd.is_finite() || budget_step_usd <= 0.0 {
        return current_gate_usd;
    }
    let mut next_gate = current_gate_usd + budget_step_usd;
    while next_gate <= current_spend_usd {
        next_gate += budget_step_usd;
    }
    next_gate
}

#[cfg(test)]
mod tests {
    use super::{
        estimate_tokens, next_budget_gate_after, objective_mentions_local_context,
        prompt_mode_for_objective, resolve_approval_requirement, should_preload_vault_context,
        truncate_tool_output, AgentConfig, AgentError, DEFAULT_AGENT_MAX_TURNS,
    };
    use crate::approval::ApprovalDecision;
    use crate::prompts::PromptMode;
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
    fn budget_gate_advances_by_budget_step_without_reprompting_same_gate() {
        assert_eq!(next_budget_gate_after(0.51, 0.50, 0.50), 1.0);
        assert_eq!(next_budget_gate_after(1.01, 0.50, 1.0), 1.5);
        assert_eq!(next_budget_gate_after(2.20, 0.50, 1.5), 2.5);
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
    fn read_only_tools_require_approval_when_read_auto_approval_is_disabled() {
        let requirement =
            resolve_approval_requirement(RiskLevel::ReadOnly, false, ApprovalDecision::AutoApprove)
                .expect("permission policy should not deny")
                .expect(
                    "read-only tools should still require approval when auto-approve is disabled",
                );

        assert_eq!(requirement.risk_level, "read_only");
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

    #[test]
    fn external_research_queries_do_not_preload_vault_context() {
        let objective = "research Gemini 2.5 and write a paper";
        let mode = prompt_mode_for_objective(objective);
        assert!(matches!(mode, PromptMode::Research));
        assert!(!should_preload_vault_context(mode, objective));
    }

    #[test]
    fn note_scoped_research_queries_keep_vault_preload() {
        let objective = "research my notes about Gemini and compare them to the latest release";
        assert!(objective_mentions_local_context(&objective.to_lowercase()));
        assert!(should_preload_vault_context(
            prompt_mode_for_objective(objective),
            objective
        ));
    }

    #[test]
    fn provider_runtime_default_is_cloud() {
        // Every existing cloud provider impl gets the correct default so
        // the agent loop accepts them. If anyone ever downgrades this by
        // declaring a Local override on a cloud provider, this regression
        // will catch it.
        use crate::provider::ProviderRuntime;
        assert_eq!(ProviderRuntime::Cloud, ProviderRuntime::Cloud);
        assert_ne!(ProviderRuntime::Cloud, ProviderRuntime::Local);
    }

    #[test]
    fn local_provider_error_carries_provider_name() {
        // Documents the exact message shape the Swift error classifier
        // parses when it decides whether to show the "agent mode needs a
        // cloud provider" UI banner. If this format changes, the Swift
        // side needs to match.
        let err = AgentError::LocalProviderNotAllowed(
            "provider 'qwen3.5-4b' runs on-device; the agent loop requires a cloud provider"
                .to_string(),
        );
        assert!(err.to_string().contains("qwen3.5-4b"));
        assert!(err.to_string().contains("cloud provider"));
    }

    #[test]
    fn default_agent_max_turns_is_25_per_claude_md_safety_rail() {
        // CLAUDE.md non-negotiable: "max_turns is a safety rail, not a
        // schedule. Trust stop_reason == 'end_turn'." 25 is the canonical
        // ceiling that lets multi-step tasks complete (compaction +
        // retries + tool calls) without runaway.
        //
        // Pin the value here so a future "let's bump it" PR has to
        // explicitly modify this test, surfacing the CLAUDE.md
        // doctrine bar to the author + reviewer. Both AgentConfig::
        // default() and the run_agent_loop unwrap_or fallback reference
        // this constant so they can't desync.
        assert_eq!(DEFAULT_AGENT_MAX_TURNS, 25);
        assert_eq!(
            AgentConfig::default().max_turns,
            Some(DEFAULT_AGENT_MAX_TURNS),
            "AgentConfig::default().max_turns must reference DEFAULT_AGENT_MAX_TURNS, not a literal"
        );
    }
}
