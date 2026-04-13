use std::collections::HashMap;
use std::time::Duration;

use async_stream::stream;
use async_trait::async_trait;
use eventsource_stream::Eventsource;
use futures::StreamExt;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use crate::agent_loop::{AgentConfig, AgentError, Effort};
use crate::error::{with_retry, RetryConfig};
use crate::provider::{AgentProvider, MessageStream, ProviderCapabilities, StreamEvent};
use crate::types::{
    ContentBlock, Message, StopReason, TokenUsage, ToolResultContent, ToolSchema, UserContent,
};

const ANTHROPIC_API: &str = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION: &str = "2023-06-01";
const BETA_HEADER: &str = "interleaved-thinking-2025-05-14";

pub struct ClaudeProvider {
    client: Client,
    api_key: String,
    model: &'static str,
    retry_config: RetryConfig,
}

impl ClaudeProvider {
    pub fn new(api_key: impl Into<String>, model: &'static str) -> Self {
        let client = Client::builder()
            .timeout(Duration::from_secs(300))
            .build()
            .expect("failed to build reqwest client");

        Self {
            client,
            api_key: api_key.into(),
            model,
            retry_config: RetryConfig::default(),
        }
    }

    pub fn opus() -> Self {
        Self::new(
            std::env::var("ANTHROPIC_API_KEY").unwrap_or_default(),
            "claude-opus-4-6",
        )
    }

    pub fn sonnet() -> Self {
        Self::new(
            std::env::var("ANTHROPIC_API_KEY").unwrap_or_default(),
            "claude-sonnet-4-6",
        )
    }

    pub fn haiku() -> Self {
        Self::new(
            std::env::var("ANTHROPIC_API_KEY").unwrap_or_default(),
            "claude-haiku-4-5",
        )
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
        if self.api_key.trim().is_empty() {
            return Err(AgentError::Provider(
                "ANTHROPIC_API_KEY is not configured".to_string(),
            ));
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

        // Build system prompt with cache breakpoint (breakpoint 1 of 4).
        let system_value = config
            .system_prompt
            .as_deref()
            .map(|s| crate::prompt_caching::cache_system_prompt(s));

        // Build messages with cache breakpoints on strategic positions.
        let mut api_messages: Vec<Value> = messages.iter().map(message_to_api_json).collect();
        crate::prompt_caching::apply_message_cache_breakpoints(&mut api_messages);

        let mcp_server_values = config.mcp_servers.as_ref().map(|servers| {
            servers
                .iter()
                .map(|server| {
                    json!({
                        "type": "url",
                        "url": server.url,
                        "name": server.name,
                    })
                })
                .collect::<Vec<Value>>()
        });

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
        let api_key = self.api_key.clone();

        let response = with_retry(
            &retry_config,
            &tokio_util::sync::CancellationToken::new(),
            || {
                let client = client.clone();
                let api_key = api_key.clone();
                let body = body.clone();
                async move {
                    let response = client
                        .post(ANTHROPIC_API)
                        .header("x-api-key", api_key)
                        .header("anthropic-version", ANTHROPIC_VERSION)
                        .header("anthropic-beta", BETA_HEADER)
                        .header("content-type", "application/json")
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
                            ContentBlockStartData::ToolUse { id, name, input }
                            | ContentBlockStartData::ServerToolUse { id, name, input } => {
                                BlockInProgress::ToolUse {
                                    id,
                                    name,
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
                "claude-opus-4-6" => 15.0,
                "claude-sonnet-4-6" => 3.0,
                _ => 0.8,
            },
            cost_output_per_million: match self.model {
                "claude-opus-4-6" => 75.0,
                "claude-sonnet-4-6" => 15.0,
                _ => 4.0,
            },
        }
    }

    fn name(&self) -> &'static str {
        self.model
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
        ContentBlock::Text { text } => json!({
            "type": "text",
            "text": text,
        }),
        ContentBlock::ToolUse { id, name, input } => json!({
            "type": "tool_use",
            "id": id,
            "name": name,
            "input": input,
        }),
    }
}

fn tool_definition_to_claude_json(tool: &ToolSchema) -> Value {
    json!({
        "name": tool.name,
        "description": tool.description,
        "input_schema": tool.parameters,
    })
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
    use super::{content_block_to_json, initial_input_json, map_stop_reason};
    use crate::types::{ContentBlock, StopReason};
    use serde_json::json;

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
}
