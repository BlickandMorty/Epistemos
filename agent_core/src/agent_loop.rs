use std::sync::Arc;
use std::time::Duration;

use futures::{future::try_join_all, StreamExt};
use tokio_util::sync::CancellationToken;

use crate::bridge::AgentEventDelegate;
use crate::credential_pool::CredentialManager;
use crate::error_classifier::classify_error;
use crate::prompts::{build_system_prompt, PromptMode};
use crate::provider::{AgentProvider, StreamEvent};
use crate::rate_limit_tracker::RateLimitTracker;
use crate::session_persistence::{build_checkpoint, SessionPersistence};
use crate::tools::registry::{RiskLevel, ToolRegistry};
use crate::types::{ContentBlock, Message, StopReason, TokenUsage, ToolResult, ToolResultContent};

/// Maximum retries for transient API errors (Hermes uses 5).
const MAX_API_RETRIES: u32 = 5;

/// Maximum compaction retry attempts before giving up.
const MAX_COMPACTION_ATTEMPTS: u32 = 3;

/// Stream read timeout — if no event received for this long, abort.
const STREAM_TIMEOUT: Duration = Duration::from_secs(90);

/// Jittered exponential backoff (Hermes: jittered_backoff).
fn jittered_backoff(attempt: u32, base_secs: f64, max_secs: f64) -> Duration {
    let delay = (base_secs * 2.0_f64.powi(attempt as i32)).min(max_secs);
    // Add 0-25% jitter to prevent thundering herd.
    let jitter = delay * 0.25 * (attempt as f64 % 4.0) / 4.0;
    Duration::from_secs_f64(delay + jitter)
}

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
        }
    }
}

#[derive(Debug, Clone)]
pub struct AgentResult {
    pub final_content: Vec<ContentBlock>,
    pub full_history: Vec<Message>,
    pub turns: u32,
    pub total_usage: TokenUsage,
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

/// Run the agent loop with full infrastructure: credential rotation, provider fallback,
/// and session persistence. This is the production-grade entry point.
pub async fn run_agent_loop(
    objective: String,
    provider: Arc<dyn AgentProvider>,
    tool_registry: Arc<ToolRegistry>,
    delegate: Arc<dyn AgentEventDelegate>,
    config: AgentConfig,
    cancel: CancellationToken,
    credential_manager: Option<Arc<CredentialManager>>,
    session_persistence: Option<Arc<tokio::sync::Mutex<SessionPersistence>>>,
) -> Result<AgentResult, AgentError> {
    let mut messages = vec![Message::user_text(&objective)];
    let mut turn_count = 0_u32;
    let mut total_usage = TokenUsage::default();
    let max_turns = config.max_turns.unwrap_or(25);
    let rate_tracker = RateLimitTracker::new();
    let provider_name = provider.name().to_string();
    let current_provider = provider;

    // ── Session persistence: record session start ────────────────────
    if let Some(ref persistence) = session_persistence {
        let mut p = persistence.lock().await;
        let _ = p.record_session_start("session", &objective, &provider_name);
    }

    let context_notes = tool_registry
        .vault_search(&objective, 5)
        .await
        .unwrap_or_default();
    let prompt_mode = prompt_mode_for_objective(&objective);
    let system_prompt = build_system_prompt(config.system_prompt.as_deref(), &context_notes, prompt_mode);

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
        // of the threshold. Uses retry logic (up to MAX_COMPACTION_ATTEMPTS).
        let proactive_threshold = config.context_threshold * 4 / 5;
        let pre_flight_tokens = estimate_tokens(&messages);
        if pre_flight_tokens > proactive_threshold {
            delegate.on_context_compacting(pre_flight_tokens as u32);
            messages = try_compact(&current_provider, &messages, &delegate, MAX_COMPACTION_ATTEMPTS).await?;
            delegate.on_context_compacted(messages.len() as u32);
        }

        let tools = tool_registry.get_definitions();
        let mut turn_config = config.clone();
        turn_config.system_prompt = Some(system_prompt.clone());

        // ── API call with retry + error classification ──────────────────
        let mut response_blocks = Vec::new();
        let mut stop_reason = StopReason::EndTurn;
        let mut turn_usage = TokenUsage::default();
        let mut api_retry_count = 0u32;

        'api_retry: loop {
            if cancel.is_cancelled() {
                return Err(AgentError::Cancelled);
            }

            // Rate limit pre-check.
            if let Some(wait_duration) = rate_tracker.should_wait(&provider_name) {
                tracing::info!(
                    provider = %provider_name,
                    wait_ms = wait_duration.as_millis() as u64,
                    "Rate-limited, waiting before retry"
                );
                tokio::time::sleep(wait_duration).await;
            }

            let stream_result = current_provider
                .stream_message(&messages, &tools, &turn_config)
                .await;

            let mut stream = match stream_result {
                Ok(s) => {
                    rate_tracker.record_success(&provider_name);
                    s
                }
                Err(e) => {
                    let (status, body_owned) = match &e {
                        AgentError::ApiError { status, body } => (Some(*status), body.clone()),
                        AgentError::HttpError(msg) => (None, msg.clone()),
                        AgentError::StreamError(msg) => (None, msg.clone()),
                        _ => (None, String::new()),
                    };

                    if status == Some(429) {
                        rate_tracker.record_429(&provider_name);
                    }

                    let classified = classify_error(
                        status,
                        &body_owned,
                        &provider_name,
                        estimate_tokens(&messages),
                        messages.len(),
                    );

                    // If retryable and under retry limit, back off and retry.
                    if classified.retryable && api_retry_count < MAX_API_RETRIES {
                        api_retry_count += 1;
                        let backoff = jittered_backoff(api_retry_count, 2.0, 120.0);
                        tracing::warn!(
                            provider = %provider_name,
                            reason = %classified.reason.as_str(),
                            attempt = api_retry_count,
                            backoff_ms = backoff.as_millis() as u64,
                            "Retrying after classified error"
                        );

                        // If error says to compress, try compaction before retry.
                        if classified.should_compress {
                            if let Ok(compacted) = try_compact(&current_provider, &messages, &delegate, MAX_COMPACTION_ATTEMPTS).await {
                                messages = compacted;
                            }
                        }

                        tokio::time::sleep(backoff).await;
                        continue 'api_retry;
                    }

                    // ── Credential rotation (HIGH gap #1) ─────────────────────
                    if classified.should_rotate_credential {
                        if let Some(ref cm) = credential_manager {
                            if cm.rotate(&provider_name) {
                                tracing::info!(
                                    provider = %provider_name,
                                    "Rotated to next API key after auth failure"
                                );
                                api_retry_count = 0; // Reset retry count for fresh key
                                continue 'api_retry;
                            }
                        }
                    }

                    // Non-retryable or all recovery options exhausted.
                    return Err(e);
                }
            };

            // ── Stream consumption with timeout ─────────────────────────
            response_blocks.clear();

            loop {
                if cancel.is_cancelled() {
                    return Err(AgentError::Cancelled);
                }

                // Timeout: if no event for STREAM_TIMEOUT, treat as stall.
                let event = tokio::time::timeout(STREAM_TIMEOUT, stream.next()).await;

                match event {
                    Err(_elapsed) => {
                        // Stream stalled — classify as timeout and retry.
                        if api_retry_count < MAX_API_RETRIES {
                            api_retry_count += 1;
                            tracing::warn!(
                                provider = %provider_name,
                                "Stream stalled for {}s, retrying (attempt {})",
                                STREAM_TIMEOUT.as_secs(), api_retry_count
                            );
                            let backoff = jittered_backoff(api_retry_count, 2.0, 60.0);
                            tokio::time::sleep(backoff).await;
                            continue 'api_retry;
                        }
                        return Err(AgentError::StreamError(format!(
                            "Stream stalled for {}s after {} retries",
                            STREAM_TIMEOUT.as_secs(), api_retry_count
                        )));
                    }
                    Ok(None) => {
                        // Stream ended without MessageStop — treat as empty response.
                        break;
                    }
                    Ok(Some(event_result)) => {
                        match event_result {
                            Err(ref e) => {
                                // Stream error mid-response — retry if possible.
                                let (status, body) = match e {
                                    AgentError::ApiError { status, body } => (Some(*status), body.as_str()),
                                    _ => (None, &e.to_string() as &str),
                                };
                                let classified = classify_error(
                                    status, body, &provider_name,
                                    estimate_tokens(&messages), messages.len(),
                                );
                                if classified.retryable && api_retry_count < MAX_API_RETRIES {
                                    api_retry_count += 1;
                                    let backoff = jittered_backoff(api_retry_count, 2.0, 60.0);
                                    tracing::warn!(
                                        provider = %provider_name,
                                        reason = %classified.reason.as_str(),
                                        "Mid-stream error, retrying (attempt {})", api_retry_count
                                    );
                                    tokio::time::sleep(backoff).await;
                                    continue 'api_retry;
                                }
                                return Err(event_result.unwrap_err());
                            }
                            Ok(event) => match event {
                                StreamEvent::ThinkingDelta { text, .. } => {
                                    delegate.on_thinking_delta(text);
                                }
                                StreamEvent::TextDelta { text, .. } => {
                                    delegate.on_text_delta(text);
                                }
                                StreamEvent::InputJsonDelta { index, partial_json } => {
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
                                StreamEvent::MessageStop { stop_reason: reason, usage } => {
                                    stop_reason = reason;
                                    turn_usage = usage;
                                    break;
                                }
                            },
                        }
                    }
                }
            }
            // If we reach here, stream completed successfully — exit retry loop.
            break 'api_retry;
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

        match stop_reason {
            StopReason::EndTurn | StopReason::StopSequence => {
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
                // ── Session persistence: record completion ──────────────
                if let Some(ref persistence) = session_persistence {
                    let mut p = persistence.lock().await;
                    let _ = p.record_session_complete(
                        "session",
                        turn_count,
                        total_usage.input_tokens,
                        total_usage.output_tokens,
                        "completed",
                    );
                    let _ = p.delete_session_checkpoints("session");
                }

                return Ok(AgentResult {
                    final_content: response_blocks,
                    full_history: messages,
                    turns: turn_count,
                    total_usage,
                });
            }
            StopReason::ToolUse => {
                let tool_calls = extract_tool_calls(&response_blocks);

                messages.push(Message::assistant(response_blocks.clone()));

                let results = if config.parallel_tool_execution {
                    execute_tools_parallel(
                        &tool_calls,
                        &tool_registry,
                        &delegate,
                        &config.permissions,
                        &cancel,
                    )
                    .await?
                } else {
                    execute_tools_sequential(
                        &tool_calls,
                        &tool_registry,
                        &delegate,
                        &config.permissions,
                        &cancel,
                    )
                    .await?
                };

                // Post-process results: detect clarification markers and
                // replace with actual user responses.
                let mut final_results = Vec::with_capacity(results.len());
                for mut result in results {
                    let result_text = result
                        .content
                        .iter()
                        .filter_map(|content| match content {
                            ToolResultContent::Text { text } => Some(text.as_str()),
                            ToolResultContent::Image { .. } => None,
                        })
                        .collect::<Vec<_>>()
                        .join("");

                    // Intercept clarification markers from the clarify tool.
                    if result_text.contains("[CLARIFICATION_NEEDED]") {
                        let question = result_text
                            .strip_prefix("[CLARIFICATION_NEEDED]: ")
                            .unwrap_or(&result_text)
                            .to_string();
                        // Extract options if present (format: "\nOptions: a, b, c")
                        let (q, options_json) = if let Some(idx) = question.find("\nOptions: ") {
                            let opts_str = &question[idx + 10..];
                            let opts: Vec<&str> = opts_str.split(", ").collect();
                            let json = serde_json::to_string(&opts).unwrap_or_default();
                            (question[..idx].to_string(), json)
                        } else {
                            (question, "[]".to_string())
                        };
                        let user_response = delegate.on_clarification_needed(q, options_json);
                        result.content = vec![ToolResultContent::Text {
                            text: format!("User responded: {user_response}"),
                        }];
                    }

                    delegate.on_tool_completed(
                        result.tool_use_id.clone(),
                        result.content
                            .iter()
                            .filter_map(|c| match c {
                                ToolResultContent::Text { text } => Some(text.as_str()),
                                ToolResultContent::Image { .. } => None,
                            })
                            .collect::<Vec<_>>()
                            .join(""),
                        result.is_error,
                    );
                    final_results.push(result);
                }

                messages.push(Message::user_tool_results(final_results));

                let estimated_tokens = estimate_tokens(&messages);
                if estimated_tokens > config.context_threshold {
                    delegate.on_context_compacting(estimated_tokens as u32);
                    messages = try_compact(&current_provider, &messages, &delegate, MAX_COMPACTION_ATTEMPTS).await?;
                    delegate.on_context_compacted(messages.len() as u32);
                }

                // ── Session persistence: save checkpoint (HIGH gap #3) ────
                if let Some(ref persistence) = session_persistence {
                    let checkpoint = build_checkpoint(
                        "session",
                        turn_count,
                        &messages,
                        &total_usage,
                        Some(&provider_name),
                        None, // key index not tracked yet
                    );
                    let mut p = persistence.lock().await;
                    let _ = p.save_checkpoint(&checkpoint);
                }
            }
            StopReason::MaxTokens => {
                messages.push(Message::assistant(response_blocks.clone()));
                delegate.on_context_compacting(estimate_tokens(&messages) as u32);
                messages = try_compact(&current_provider, &messages, &delegate, MAX_COMPACTION_ATTEMPTS).await?;
                delegate.on_context_compacted(messages.len() as u32);
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

async fn execute_tools_parallel(
    tool_calls: &[(String, String, serde_json::Value)],
    tool_registry: &Arc<ToolRegistry>,
    delegate: &Arc<dyn AgentEventDelegate>,
    permissions: &PermissionConfig,
    cancel: &CancellationToken,
) -> Result<Vec<ToolResult>, AgentError> {
    let futures = tool_calls.iter().map(|(id, name, input)| {
        execute_one_tool(
            id.clone(),
            name.clone(),
            input.clone(),
            Arc::clone(tool_registry),
            Arc::clone(delegate),
            permissions.clone(),
            cancel.clone(),
        )
    });

    try_join_all(futures).await
}

async fn execute_tools_sequential(
    tool_calls: &[(String, String, serde_json::Value)],
    tool_registry: &Arc<ToolRegistry>,
    delegate: &Arc<dyn AgentEventDelegate>,
    permissions: &PermissionConfig,
    cancel: &CancellationToken,
) -> Result<Vec<ToolResult>, AgentError> {
    let mut results = Vec::with_capacity(tool_calls.len());
    for (id, name, input) in tool_calls {
        results.push(
            execute_one_tool(
                id.clone(),
                name.clone(),
                input.clone(),
                Arc::clone(tool_registry),
                Arc::clone(delegate),
                permissions.clone(),
                cancel.clone(),
            )
            .await?,
        );
    }
    Ok(results)
}

async fn execute_one_tool(
    id: String,
    name: String,
    input: serde_json::Value,
    tool_registry: Arc<ToolRegistry>,
    delegate: Arc<dyn AgentEventDelegate>,
    permissions: PermissionConfig,
    cancel: CancellationToken,
) -> Result<ToolResult, AgentError> {
    if cancel.is_cancelled() {
        return Err(AgentError::Cancelled);
    }

    let risk = tool_registry.get_risk_level(&name);
    let approved = match risk {
        RiskLevel::ReadOnly => permissions.auto_approve_read_only,
        RiskLevel::Modification => permissions.auto_approve_modification,
        RiskLevel::Destructive => permissions.auto_approve_destructive,
    };

    if !approved {
        let permission_id = uuid::Uuid::new_v4().to_string();
        let input_json = serde_json::to_string(&input)
            .map_err(|error| AgentError::Serialization(error.to_string()))?;
        delegate.on_permission_required(
            permission_id.clone(),
            name.clone(),
            input_json,
            risk.as_str().to_string(),
        );

        if !delegate.wait_for_permission(permission_id) {
            return Ok(ToolResult::text(
                id,
                "Tool execution denied by user.",
                false,
            ));
        }
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
            if risk.level == crate::security::CommandRiskLevel::Dangerous && !approved {
                return Ok(ToolResult::text(
                    id,
                    format!("Command requires approval (dangerous): {}", risk.reasons.join(", ")),
                    true,
                ));
            }
        }
    }

    match tool_registry.execute(&name, &input).await {
        Ok(output) => {
            // Security: redact credentials from tool output.
            let redacted = crate::security::redact_credentials(&output);
            // Security: scan for injection/exfiltration patterns.
            let scan = crate::security::scan_tool_output(&redacted);
            if let Some(severity) = scan.max_severity() {
                if severity >= crate::security::Severity::High {
                    tracing::warn!(
                        tool = %name,
                        "Security scan flagged tool output: {:?}",
                        scan.threats.iter().map(|t| &t.description).collect::<Vec<_>>()
                    );
                }
            }
            Ok(ToolResult::text(id, truncate_tool_output(redacted.into_owned(), 16_384), false))
        }
        Err(error) => Ok(ToolResult::text(id, format!("Tool error: {error}"), true)),
    }
}

fn prompt_mode_for_objective(objective: &str) -> PromptMode {
    let normalized = objective.to_lowercase();
    if contains_any(&normalized, &["code", "swift", "rust", "bug", "test", "compile"]) {
        PromptMode::Code
    } else if contains_any(
        &normalized,
        &["research", "compare", "cite", "citation", "source", "latest", "current", "web"],
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
                    ContentBlock::ToolUse { name, input, .. } => name.len() + input.to_string().len(),
                })
                .sum::<usize>(),
        })
        .sum::<usize>();

    characters / 4
}

/// Try compaction with up to `max_attempts` retries. Returns CompactionFailed only
/// after all attempts are exhausted (Hermes retries 3 times before giving up).
async fn try_compact(
    provider: &Arc<dyn AgentProvider>,
    messages: &[Message],
    delegate: &Arc<dyn AgentEventDelegate>,
    max_attempts: u32,
) -> Result<Vec<Message>, AgentError> {
    for attempt in 1..=max_attempts {
        match provider.compact(messages).await {
            Ok(compacted) => return Ok(compacted),
            Err(_) if attempt < max_attempts => {
                tracing::warn!(
                    attempt,
                    max_attempts,
                    "Compaction failed, retrying"
                );
                delegate.on_error(format!(
                    "Compaction attempt {attempt}/{max_attempts} failed, retrying..."
                ));
                // Brief pause before retry.
                tokio::time::sleep(Duration::from_secs(1)).await;
            }
            Err(_) => {
                return Err(AgentError::CompactionFailed);
            }
        }
    }
    Err(AgentError::CompactionFailed)
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
    use super::{estimate_tokens, truncate_tool_output};
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
}
