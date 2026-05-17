//! Source: https://docs.anthropic.com/en/api/messages
//! Source: https://docs.anthropic.com/en/docs/build-with-claude/tool-use/overview
//! Source: https://docs.anthropic.com/en/docs/build-with-claude/extended-thinking
//! Source: https://docs.anthropic.com/en/docs/agents-and-tools/tool-use/fine-grained-tool-streaming
//! Source: https://platform.claude.com/docs/en/docs/agents-and-tools/mcp-connector

use std::collections::HashMap;
use std::time::Duration;

use async_stream::stream;
use async_trait::async_trait;
use eventsource_stream::Eventsource;
use futures::StreamExt;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use crate::agent_loop::{AgentConfig, AgentError, Effort, McpServerConfig};
use crate::error::{with_retry, RetryConfig};
use crate::provider::{AgentProvider, MessageStream, ProviderCapabilities, StreamEvent};
use crate::providers::schema::normalized_tool_parameters;
use crate::types::{
    ContentBlock, Message, StopReason, TokenUsage, ToolResultContent, ToolSchema, UserContent,
};

const ANTHROPIC_API: &str = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION: &str = "2023-06-01";
const MCP_CONNECTOR_BETA_HEADER: &str = "mcp-client-2025-11-20";
const BETA_HEADER: &str = "interleaved-thinking-2025-05-14,mcp-client-2025-11-20";
const ANTHROPIC_OAUTH_BETA_HEADER: &str =
    "interleaved-thinking-2025-05-14,fine-grained-tool-streaming-2025-05-14,claude-code-20250219,oauth-2025-04-20,mcp-client-2025-11-20";
const ANTHROPIC_OAUTH_AUTH_MODE_ENV: &str = "ANTHROPIC_AUTH_MODE";
const ANTHROPIC_OAUTH_ACCESS_TOKEN_ENV: &str = "ANTHROPIC_ACCESS_TOKEN";
const ANTHROPIC_OAUTH_AUTH_MODE: &str = "oauth";

#[derive(Debug, Clone, PartialEq, Eq)]
enum ClaudeAuth {
    ApiKey(String),
    OAuthAccessToken(String),
}

pub struct ClaudeProvider {
    client: Client,
    auth: ClaudeAuth,
    model: &'static str,
    retry_config: RetryConfig,
}

impl ClaudeProvider {
    fn new(auth: ClaudeAuth, model: &'static str) -> Self {
        let client = Client::builder()
            .timeout(Duration::from_secs(300))
            .build()
            .expect("failed to build reqwest client");

        Self {
            client,
            auth,
            model,
            retry_config: RetryConfig::default(),
        }
    }

    fn from_env(model: &'static str) -> Self {
        Self::new(
            resolve_claude_auth(
                std::env::var("ANTHROPIC_API_KEY").unwrap_or_default(),
                std::env::var(ANTHROPIC_OAUTH_ACCESS_TOKEN_ENV).unwrap_or_default(),
                std::env::var(ANTHROPIC_OAUTH_AUTH_MODE_ENV).unwrap_or_default(),
            ),
            model,
        )
    }

    pub fn opus() -> Self {
        Self::from_env("claude-opus-4-7")
    }

    pub fn sonnet() -> Self {
        Self::from_env("claude-sonnet-4-6")
    }

    pub fn haiku() -> Self {
        Self::from_env("claude-haiku-4-5")
    }
}

#[derive(Serialize)]
struct ThinkingConfig {
    #[serde(rename = "type")]
    thinking_type: &'static str,
    #[serde(skip_serializing_if = "Option::is_none")]
    effort: Option<&'static str>,
}

impl ThinkingConfig {
    fn adaptive_with_effort(effort: &'static str) -> Self {
        Self {
            thinking_type: "adaptive",
            effort: Some(effort),
        }
    }

    fn disabled() -> Self {
        Self {
            thinking_type: "disabled",
            effort: None,
        }
    }
}

#[derive(Deserialize, Debug)]
#[serde(tag = "type", rename_all = "snake_case")]
enum RawSseEvent {
    MessageStart {
        message: MessageStartData,
    },
    ContentBlockStart {
        index: usize,
        content_block: ContentBlockStartData,
    },
    ContentBlockDelta {
        index: usize,
        delta: DeltaData,
    },
    ContentBlockStop {
        index: usize,
    },
    MessageDelta {
        delta: MessageDeltaData,
        usage: Option<UsageData>,
    },
    MessageStop,
    Ping,
    Error {
        error: ErrorData,
    },
}

#[derive(Deserialize, Debug)]
struct MessageStartData {
    usage: UsageData,
}

#[derive(Deserialize, Debug)]
#[serde(tag = "type", rename_all = "snake_case")]
enum ContentBlockStartData {
    Text {
        text: String,
    },
    Thinking {
        thinking: String,
        signature: String,
    },
    RedactedThinking {
        data: String,
    },
    ToolUse {
        id: String,
        name: String,
        input: Value,
    },
    ServerToolUse {
        id: String,
        name: String,
        input: Value,
    },
}

#[derive(Deserialize, Debug)]
#[serde(tag = "type", rename_all = "snake_case")]
#[allow(clippy::enum_variant_names)]
enum DeltaData {
    TextDelta { text: String },
    ThinkingDelta { thinking: String },
    InputJsonDelta { partial_json: String },
    SignatureDelta { signature: String },
}

#[derive(Deserialize, Debug)]
struct MessageDeltaData {
    stop_reason: Option<String>,
}

#[derive(Deserialize, Debug, Default)]
struct UsageData {
    input_tokens: Option<u32>,
    output_tokens: Option<u32>,
    cache_creation_input_tokens: Option<u32>,
    cache_read_input_tokens: Option<u32>,
}

#[derive(Deserialize, Debug)]
struct ErrorData {
    #[serde(rename = "type")]
    error_type: String,
    message: String,
}

enum BlockInProgress {
    Text(String),
    Thinking {
        text: String,
        signature: String,
    },
    RedactedThinking {
        data: String,
    },
    ToolUse {
        id: String,
        name: String,
        input_json: String,
    },
}

#[async_trait]
impl AgentProvider for ClaudeProvider {
    async fn stream_message(
        &self,
        messages: &[Message],
        tools: &[ToolSchema],
        config: &AgentConfig,
    ) -> Result<MessageStream, AgentError> {
        match &self.auth {
            ClaudeAuth::ApiKey(api_key) if api_key.trim().is_empty() => {
                return Err(AgentError::Provider(
                    "ANTHROPIC_API_KEY is not configured".to_string(),
                ));
            }
            ClaudeAuth::OAuthAccessToken(access_token) if access_token.trim().is_empty() => {
                return Err(AgentError::Provider(
                    "ANTHROPIC_ACCESS_TOKEN is not configured".to_string(),
                ));
            }
            _ => {}
        }

        let thinking = if config.enable_thinking && self.model != "claude-haiku-4-5" {
            ThinkingConfig::adaptive_with_effort(match config.effort {
                Effort::Low => "low",
                Effort::Medium => "medium",
                Effort::High => "high",
                Effort::Max => "max",
            })
        } else {
            ThinkingConfig::disabled()
        };

        let mut api_tools: Vec<Value> = tools.iter().map(tool_definition_to_claude_json).collect();
        if config.enable_web_search {
            api_tools.push(json!({ "type": "web_search_20250305" }));
        }
        if config.enable_web_fetch {
            api_tools.push(json!({ "type": "web_fetch_20250305" }));
        }
        if config.enable_code_execution {
            api_tools.push(json!({ "type": "code_execution_20250825" }));
        }
        if config.enable_computer_use && self.model != "claude-haiku-4-5" {
            api_tools.push(json!({
                "type": "computer_20251124",
                "name": "computer",
                "display_width_px": 1280,
                "display_height_px": 720,
                "display_number": 1,
            }));
        }
        if let Some(servers) = config
            .mcp_servers
            .as_deref()
            .filter(|servers| !servers.is_empty())
        {
            api_tools.extend(mcp_toolsets_to_anthropic_json(servers));
        }

        // Build system prompt with cache breakpoint (breakpoint 1 of 4).
        let system_value = config
            .system_prompt
            .as_deref()
            .map(crate::prompt_caching::cache_system_prompt);

        // Build messages with cache breakpoints on strategic positions.
        let mut api_messages: Vec<Value> = messages.iter().map(message_to_api_json).collect();
        crate::prompt_caching::apply_message_cache_breakpoints(&mut api_messages);

        let mcp_server_values = config
            .mcp_servers
            .as_deref()
            .filter(|servers| !servers.is_empty())
            .map(mcp_servers_to_anthropic_json);

        let body = json!({
            "model": self.model,
            "max_tokens": config.max_output_tokens.unwrap_or(16_384),
            "thinking": serde_json::to_value(&thinking)
                .map_err(|e| AgentError::Serialization(e.to_string()))?,
            "messages": api_messages,
            "tools": api_tools,
            "stream": true,
            "system": system_value,
            "mcp_servers": mcp_server_values,
        });

        let retry_config = self.retry_config.clone();
        let client = self.client.clone();
        let auth = self.auth.clone();

        let response = with_retry(
            &retry_config,
            &tokio_util::sync::CancellationToken::new(),
            || {
                let client = client.clone();
                let auth = auth.clone();
                let body = body.clone();
                async move {
                    let response = authenticated_request(&client, &auth)
                        .json(&body)
                        .send()
                        .await
                        .map_err(|error| AgentError::HttpError(error.to_string()))?;

                    if !response.status().is_success() {
                        let status = response.status().as_u16();
                        let retry_after = response
                            .headers()
                            .get("retry-after")
                            .and_then(|header| header.to_str().ok())
                            .map(ToString::to_string);
                        let body = response.text().await.unwrap_or_default();
                        let _ = retry_after;
                        return Err(AgentError::ApiError { status, body });
                    }

                    Ok(response)
                }
            },
        )
        .await?;

        let event_stream = response.bytes_stream().eventsource();

        let parsed_stream = stream! {
            let mut blocks_in_progress: HashMap<usize, BlockInProgress> = HashMap::new();
            let mut final_stop_reason = StopReason::EndTurn;
            let mut final_usage = TokenUsage::default();
            futures::pin_mut!(event_stream);

            while let Some(event_result) = event_stream.next().await {
                let event = match event_result {
                    Ok(event) => event,
                    Err(error) => {
                        yield Err(AgentError::StreamError(error.to_string()));
                        return;
                    }
                };

                if event.data == "[DONE]" {
                    break;
                }

                let raw = match serde_json::from_str::<RawSseEvent>(&event.data) {
                    Ok(raw) => raw,
                    Err(_) => continue,
                };

                match raw {
                    RawSseEvent::Ping => {}
                    RawSseEvent::MessageStart { message } => {
                        merge_usage(&mut final_usage, &message.usage);
                    }
                    RawSseEvent::ContentBlockStart { index, content_block } => {
                        let block = match content_block {
                            ContentBlockStartData::Text { text } => BlockInProgress::Text(text),
                            ContentBlockStartData::Thinking { thinking, signature } => {
                                BlockInProgress::Thinking {
                                    text: thinking,
                                    signature,
                                }
                            }
                            ContentBlockStartData::RedactedThinking { data } => {
                                yield Ok(StreamEvent::RedactedThinking {
                                    index,
                                    data: data.clone(),
                                });
                                BlockInProgress::RedactedThinking { data }
                            }
                            ContentBlockStartData::ToolUse { id, name, input }
                            | ContentBlockStartData::ServerToolUse { id, name, input } => {
                                BlockInProgress::ToolUse {
                                    id,
                                    name: crate::providers::tool_names::canonical_tool_name_from_api(&name),
                                    input_json: initial_input_json(input),
                                }
                            }
                        };
                        blocks_in_progress.insert(index, block);
                    }
                    RawSseEvent::ContentBlockDelta { index, delta } => match delta {
                        DeltaData::TextDelta { text } => {
                            yield Ok(StreamEvent::TextDelta {
                                index,
                                text: text.clone(),
                            });
                            if let Some(BlockInProgress::Text(buffer)) = blocks_in_progress.get_mut(&index) {
                                buffer.push_str(&text);
                            }
                        }
                        DeltaData::ThinkingDelta { thinking } => {
                            yield Ok(StreamEvent::ThinkingDelta {
                                index,
                                text: thinking.clone(),
                            });
                            if let Some(BlockInProgress::Thinking { text, .. }) = blocks_in_progress.get_mut(&index) {
                                text.push_str(&thinking);
                            }
                        }
                        DeltaData::InputJsonDelta { partial_json } => {
                            yield Ok(StreamEvent::InputJsonDelta {
                                index,
                                partial_json: partial_json.clone(),
                            });
                            if let Some(BlockInProgress::ToolUse { input_json, .. }) = blocks_in_progress.get_mut(&index) {
                                input_json.push_str(&partial_json);
                            }
                        }
                        DeltaData::SignatureDelta { signature } => {
                            yield Ok(StreamEvent::SignatureDelta {
                                index,
                                signature: signature.clone(),
                            });
                            if let Some(BlockInProgress::Thinking { signature: stored, .. }) = blocks_in_progress.get_mut(&index) {
                                stored.push_str(&signature);
                            }
                        }
                    },
                    RawSseEvent::ContentBlockStop { index } => {
                        if let Some(block) = blocks_in_progress.remove(&index) {
                            let completed = match block {
                                BlockInProgress::Text(text) => ContentBlock::Text { text },
                                BlockInProgress::Thinking { text, signature } => ContentBlock::Thinking {
                                    thinking: text,
                                    signature,
                                },
                                BlockInProgress::RedactedThinking { data } => {
                                    ContentBlock::RedactedThinking { data }
                                }
                                BlockInProgress::ToolUse { id, name, input_json } => ContentBlock::ToolUse {
                                    id,
                                    name,
                                    input: serde_json::from_str(&input_json).unwrap_or(Value::Null),
                                },
                            };
                            yield Ok(StreamEvent::ContentBlockComplete { block: completed });
                        }
                    }
                    RawSseEvent::MessageDelta { delta, usage } => {
                        if let Some(usage) = usage {
                            merge_usage(&mut final_usage, &usage);
                        }
                        if let Some(reason) = delta.stop_reason {
                            final_stop_reason = map_stop_reason(&reason);
                        }
                    }
                    RawSseEvent::MessageStop => {
                        yield Ok(StreamEvent::MessageStop {
                            stop_reason: final_stop_reason,
                            usage: final_usage,
                        });
                        return;
                    }
                    RawSseEvent::Error { error } => {
                        yield Err(AgentError::ApiError {
                            status: 0,
                            body: format!("{}: {}", error.error_type, error.message),
                        });
                        return;
                    }
                }
            }

            yield Ok(StreamEvent::MessageStop {
                stop_reason: final_stop_reason,
                usage: final_usage,
            });
        };

        Ok(Box::pin(parsed_stream))
    }

    async fn compact(&self, messages: &[Message]) -> Result<Vec<Message>, AgentError> {
        Ok(crate::compaction::compact_messages(messages, 8, 16_384))
    }

    fn capabilities(&self) -> ProviderCapabilities {
        ProviderCapabilities {
            max_context_tokens: 1_000_000,
            max_output_tokens: 128_000,
            supports_thinking: self.model != "claude-haiku-4-5",
            supports_vision: true,
            supports_web_search: true,
            supports_code_execution: true,
            supports_computer_use: self.model != "claude-haiku-4-5",
            supports_mcp: true,
            supports_streaming: true,
            supports_compaction: true,
            cost_input_per_million: match self.model {
                "claude-opus-4-7" => 15.0,
                "claude-sonnet-4-6" => 3.0,
                _ => 0.8,
            },
            cost_output_per_million: match self.model {
                "claude-opus-4-7" => 75.0,
                "claude-sonnet-4-6" => 15.0,
                _ => 4.0,
            },
        }
    }

    fn name(&self) -> &'static str {
        self.model
    }
}

fn resolve_claude_auth(api_key: String, access_token: String, auth_mode: String) -> ClaudeAuth {
    if auth_mode
        .trim()
        .eq_ignore_ascii_case(ANTHROPIC_OAUTH_AUTH_MODE)
        && !access_token.trim().is_empty()
    {
        ClaudeAuth::OAuthAccessToken(access_token)
    } else {
        ClaudeAuth::ApiKey(api_key)
    }
}

fn authenticated_request(client: &Client, auth: &ClaudeAuth) -> reqwest::RequestBuilder {
    let builder = client
        .post(ANTHROPIC_API)
        .header("anthropic-version", ANTHROPIC_VERSION)
        .header("content-type", "application/json");

    match auth {
        ClaudeAuth::ApiKey(api_key) => builder
            .header("x-api-key", api_key)
            .header("anthropic-beta", BETA_HEADER),
        ClaudeAuth::OAuthAccessToken(access_token) => builder
            .header("authorization", format!("Bearer {access_token}"))
            .header("anthropic-beta", ANTHROPIC_OAUTH_BETA_HEADER)
            .header("user-agent", "claude-cli/2.1.74 (external, cli)")
            .header("x-app", "cli"),
    }
}

fn message_to_api_json(message: &Message) -> Value {
    match message {
        Message::User { content } => json!({
            "role": "user",
            "content": content.iter().map(user_content_to_json).collect::<Vec<_>>(),
        }),
        Message::Assistant { content } => json!({
            "role": "assistant",
            "content": content.iter().map(content_block_to_json).collect::<Vec<_>>(),
        }),
    }
}

fn user_content_to_json(content: &UserContent) -> Value {
    match content {
        UserContent::Text { text } => json!({
            "type": "text",
            "text": text,
        }),
        UserContent::ToolResult(result) => json!({
            "type": "tool_result",
            "tool_use_id": result.tool_use_id,
            "content": result.content.iter().map(tool_result_content_to_json).collect::<Vec<_>>(),
            "is_error": result.is_error,
        }),
        UserContent::Image { source } => json!({
            "type": "image",
            "source": {
                "type": source.source_type,
                "media_type": source.media_type,
                "data": source.data,
            },
        }),
    }
}

fn tool_result_content_to_json(content: &ToolResultContent) -> Value {
    match content {
        ToolResultContent::Text { text } => json!({
            "type": "text",
            "text": text,
        }),
        ToolResultContent::Image { source } => json!({
            "type": "image",
            "source": {
                "type": source.source_type,
                "media_type": source.media_type,
                "data": source.data,
            },
        }),
    }
}

fn content_block_to_json(block: &ContentBlock) -> Value {
    match block {
        ContentBlock::Thinking {
            thinking,
            signature,
        } => json!({
            "type": "thinking",
            "thinking": thinking,
            "signature": signature,
        }),
        ContentBlock::RedactedThinking { data } => json!({
            "type": "redacted_thinking",
            "data": data,
        }),
        ContentBlock::Text { text } => json!({
            "type": "text",
            "text": text,
        }),
        ContentBlock::ToolUse { id, name, input } => json!({
            "type": "tool_use",
            "id": id,
            "name": crate::providers::tool_names::api_safe_tool_name(name),
            "input": input,
        }),
    }
}

fn tool_definition_to_claude_json(tool: &ToolSchema) -> Value {
    json!({
        "name": crate::providers::tool_names::api_safe_tool_name(&tool.name),
        "description": tool.description,
        "input_schema": normalized_tool_parameters(&tool.parameters),
    })
}

fn mcp_servers_to_anthropic_json(servers: &[McpServerConfig]) -> Vec<Value> {
    servers
        .iter()
        .map(|server| {
            json!({
                "type": "url",
                "url": server.url,
                "name": server.name,
            })
        })
        .collect()
}

fn mcp_toolsets_to_anthropic_json(servers: &[McpServerConfig]) -> Vec<Value> {
    servers
        .iter()
        .map(|server| {
            json!({
                "type": "mcp_toolset",
                "mcp_server_name": server.name,
            })
        })
        .collect()
}

fn initial_input_json(input: Value) -> String {
    match input {
        Value::Null => String::new(),
        Value::Object(ref object) if object.is_empty() => String::new(),
        other => other.to_string(),
    }
}

fn merge_usage(into: &mut TokenUsage, usage: &UsageData) {
    into.input_tokens = usage.input_tokens.unwrap_or(into.input_tokens);
    into.output_tokens = usage.output_tokens.unwrap_or(into.output_tokens);
    into.cache_creation_input_tokens = usage
        .cache_creation_input_tokens
        .unwrap_or(into.cache_creation_input_tokens);
    into.cache_read_input_tokens = usage
        .cache_read_input_tokens
        .unwrap_or(into.cache_read_input_tokens);
}

fn map_stop_reason(reason: &str) -> StopReason {
    match reason {
        "tool_use" => StopReason::ToolUse,
        "max_tokens" => StopReason::MaxTokens,
        "stop_sequence" => StopReason::StopSequence,
        _ => StopReason::EndTurn,
    }
}

#[cfg(test)]
mod tests {
    use super::{
        authenticated_request, content_block_to_json, initial_input_json, map_stop_reason,
        mcp_toolsets_to_anthropic_json, merge_usage, resolve_claude_auth,
        tool_definition_to_claude_json, ClaudeAuth, UsageData, ANTHROPIC_OAUTH_BETA_HEADER,
        BETA_HEADER, MCP_CONNECTOR_BETA_HEADER,
    };
    use crate::agent_loop::McpServerConfig;
    use crate::types::{ContentBlock, StopReason, TokenUsage, ToolSchema};
    use reqwest::Client;
    use serde_json::json;

    #[test]
    fn module_starts_with_official_source_comments() {
        let source = include_str!("claude.rs");

        assert!(
            source.starts_with("//! Source: https://docs.anthropic.com/en/api/messages\n"),
            "Claude provider must start with official API source comments"
        );
        assert!(
            source.contains(
                "//! Source: https://docs.anthropic.com/en/docs/build-with-claude/tool-use/overview"
            ),
            "Claude provider must cite the official tool-use contract"
        );
        assert!(
            source.contains(
                "//! Source: https://docs.anthropic.com/en/docs/build-with-claude/extended-thinking"
            ),
            "Claude provider must cite the official extended-thinking contract"
        );
        assert!(
            source.contains(
                "//! Source: https://platform.claude.com/docs/en/docs/agents-and-tools/mcp-connector"
            ),
            "Claude provider must cite the official MCP connector contract"
        );
    }

    #[test]
    fn preserves_thinking_signature_in_json() {
        let json = content_block_to_json(&ContentBlock::Thinking {
            thinking: "plan".to_string(),
            signature: "sig-123".to_string(),
        });

        assert_eq!(json["type"], "thinking");
        assert_eq!(json["signature"], "sig-123");
    }

    #[test]
    fn preserves_redacted_thinking_in_json() {
        let opaque = "opaque-redacted-data+/=\nwith unicode \u{2603}";
        let json = content_block_to_json(&ContentBlock::RedactedThinking {
            data: opaque.to_string(),
        });

        assert_eq!(json["type"], "redacted_thinking");
        assert_eq!(json["data"].as_str().unwrap().as_bytes(), opaque.as_bytes());
    }

    #[test]
    fn parses_redacted_thinking_content_block_start() {
        let opaque = "opaque-redacted-data+/=\nwith unicode \u{2603}";
        let raw: super::RawSseEvent = serde_json::from_value(json!({
            "type": "content_block_start",
            "index": 2,
            "content_block": {
                "type": "redacted_thinking",
                "data": opaque,
            },
        }))
        .unwrap();

        match raw {
            super::RawSseEvent::ContentBlockStart {
                index,
                content_block: super::ContentBlockStartData::RedactedThinking { data },
            } => {
                assert_eq!(index, 2);
                assert_eq!(data.as_bytes(), opaque.as_bytes());
            }
            other => panic!("expected redacted thinking block start, got {other:?}"),
        }
    }

    #[test]
    fn keeps_initial_tool_input_when_block_start_includes_it() {
        assert_eq!(
            initial_input_json(json!({"query": "rust"})),
            "{\"query\":\"rust\"}"
        );
        assert!(initial_input_json(json!({})).is_empty());
    }

    #[test]
    fn maps_stop_reasons() {
        assert_eq!(map_stop_reason("tool_use"), StopReason::ToolUse);
        assert_eq!(map_stop_reason("max_tokens"), StopReason::MaxTokens);
        assert_eq!(map_stop_reason("anything_else"), StopReason::EndTurn);
    }

    // N1 Phase 1 closure (MASTER_BUILD_PLAN.md:311) — guard the data path
    // from Anthropic's SSE `usage` block into `TokenUsage`. The W9.6
    // cost dashboard reads `cache_read_input_tokens` from this same
    // struct via `AgentResultFFI`; if `merge_usage` ever stops
    // populating those fields, the dashboard's "Cache hit rate" row
    // silently flat-lines at 0 % and N1's whole point evaporates.
    #[test]
    fn merge_usage_captures_anthropic_cache_token_counters() {
        let mut usage = TokenUsage::default();
        merge_usage(
            &mut usage,
            &UsageData {
                input_tokens: Some(120),
                output_tokens: Some(80),
                cache_creation_input_tokens: Some(2_048),
                cache_read_input_tokens: Some(9_216),
            },
        );

        assert_eq!(usage.input_tokens, 120);
        assert_eq!(usage.output_tokens, 80);
        assert_eq!(usage.cache_creation_input_tokens, 2_048);
        assert_eq!(usage.cache_read_input_tokens, 9_216);
    }

    #[test]
    fn merge_usage_preserves_prior_cache_counters_when_chunk_is_silent() {
        // Anthropic's SSE often emits a `message_start` event with the
        // initial usage block, then per-chunk `message_delta` events
        // that omit cache fields. `merge_usage` must keep the prior
        // value rather than reset to zero, otherwise mid-stream chunks
        // wipe out the cache numbers reported by the opener.
        let mut usage = TokenUsage {
            input_tokens: 50,
            output_tokens: 0,
            cache_creation_input_tokens: 1_000,
            cache_read_input_tokens: 5_000,
        };
        merge_usage(
            &mut usage,
            &UsageData {
                input_tokens: None,
                output_tokens: Some(40),
                cache_creation_input_tokens: None,
                cache_read_input_tokens: None,
            },
        );

        assert_eq!(usage.input_tokens, 50);
        assert_eq!(usage.output_tokens, 40);
        assert_eq!(usage.cache_creation_input_tokens, 1_000);
        assert_eq!(usage.cache_read_input_tokens, 5_000);
    }

    #[test]
    fn resolves_oauth_auth_when_access_token_is_present() {
        let auth = resolve_claude_auth(
            "sk-ant-api-key".to_string(),
            "anthropic-oauth-token".to_string(),
            "oauth".to_string(),
        );

        assert_eq!(
            auth,
            ClaudeAuth::OAuthAccessToken("anthropic-oauth-token".to_string())
        );
    }

    #[test]
    fn resolves_oauth_auth_case_insensitively() {
        let auth = resolve_claude_auth(
            "sk-ant-api-key".to_string(),
            "anthropic-oauth-token".to_string(),
            "OAuth".to_string(),
        );

        assert_eq!(
            auth,
            ClaudeAuth::OAuthAccessToken("anthropic-oauth-token".to_string())
        );
    }

    #[test]
    fn oauth_requests_match_claude_code_session_headers() {
        let client = Client::builder().build().unwrap();
        let request = authenticated_request(
            &client,
            &ClaudeAuth::OAuthAccessToken("anthropic-oauth-token".to_string()),
        )
        .build()
        .unwrap();

        assert_eq!(
            request.headers().get("authorization").unwrap(),
            "Bearer anthropic-oauth-token"
        );
        assert_eq!(
            request.headers().get("anthropic-beta").unwrap(),
            ANTHROPIC_OAUTH_BETA_HEADER
        );
        assert_eq!(
            request.headers().get("user-agent").unwrap(),
            "claude-cli/2.1.74 (external, cli)"
        );
        assert_eq!(request.headers().get("x-app").unwrap(), "cli");
    }

    #[test]
    fn oauth_requests_include_current_mcp_connector_beta() {
        let client = Client::builder().build().unwrap();
        let request = authenticated_request(
            &client,
            &ClaudeAuth::OAuthAccessToken("anthropic-oauth-token".to_string()),
        )
        .build()
        .unwrap();
        let beta = request
            .headers()
            .get("anthropic-beta")
            .unwrap()
            .to_str()
            .unwrap();

        assert!(beta.contains(MCP_CONNECTOR_BETA_HEADER));
        assert!(!beta.contains("mcp-client-2025-04-04"));
    }

    #[test]
    fn api_key_requests_preserve_legacy_headers() {
        let client = Client::builder().build().unwrap();
        let request =
            authenticated_request(&client, &ClaudeAuth::ApiKey("sk-ant-api-key".to_string()))
                .build()
                .unwrap();

        assert_eq!(
            request.headers().get("x-api-key").unwrap(),
            "sk-ant-api-key"
        );
        assert_eq!(
            request.headers().get("anthropic-beta").unwrap(),
            BETA_HEADER
        );
        assert!(request.headers().get("authorization").is_none());
    }

    #[test]
    fn api_key_requests_include_current_mcp_connector_beta() {
        let client = Client::builder().build().unwrap();
        let request =
            authenticated_request(&client, &ClaudeAuth::ApiKey("sk-ant-api-key".to_string()))
                .build()
                .unwrap();
        let beta = request
            .headers()
            .get("anthropic-beta")
            .unwrap()
            .to_str()
            .unwrap();

        assert!(beta.contains(MCP_CONNECTOR_BETA_HEADER));
        assert!(!beta.contains("mcp-client-2025-04-04"));
    }

    #[test]
    fn url_mcp_servers_add_current_mcp_toolsets() {
        let toolsets = mcp_toolsets_to_anthropic_json(&[
            McpServerConfig {
                name: "github".to_string(),
                url: "https://mcp.example.com/github".to_string(),
            },
            McpServerConfig {
                name: "linear".to_string(),
                url: "https://mcp.example.com/linear".to_string(),
            },
        ]);

        assert_eq!(toolsets.len(), 2);
        assert_eq!(toolsets[0]["type"], "mcp_toolset");
        assert_eq!(toolsets[0]["mcp_server_name"], "github");
        assert!(toolsets[0].get("tool_configuration").is_none());
        assert_eq!(toolsets[1]["type"], "mcp_toolset");
        assert_eq!(toolsets[1]["mcp_server_name"], "linear");
    }

    #[test]
    fn claude_tool_schemas_close_nested_object_parameters() {
        let tool_json = tool_definition_to_claude_json(&ToolSchema {
            name: "file.write".to_string(),
            description: "Write a file".to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "path": { "type": "string" },
                    "options": {
                        "type": "object",
                        "properties": {
                            "overwrite": { "type": "boolean" }
                        }
                    }
                }
            }),
        });

        assert_eq!(tool_json["name"], "file__write");
        assert_eq!(tool_json["input_schema"]["additionalProperties"], false);
        assert_eq!(
            tool_json["input_schema"]["properties"]["options"]["additionalProperties"],
            false
        );
    }
}
