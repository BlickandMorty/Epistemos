use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::PathBuf;
use std::time::Duration;

use async_stream::stream;
use async_trait::async_trait;
use eventsource_stream::Eventsource;
use futures::StreamExt;
use reqwest::Client;
use serde_json::{Value, json};
use tracing::{debug, warn};

use crate::agent_loop::{AgentConfig, AgentError};
use crate::error::{RetryConfig, with_retry};
use crate::provider::{AgentProvider, MessageStream, ProviderCapabilities, StreamEvent};
use crate::providers::schema::normalized_strict_tool_parameters;
use crate::types::{
    ContentBlock, Message, StopReason, TokenUsage, ToolResultContent, ToolSchema, UserContent,
};

pub(crate) const OPENAI_RESPONSES_API: &str = "https://api.openai.com/v1/responses";
const OPENAI_CODEX_RESPONSES_API: &str = "https://chatgpt.com/backend-api/codex/responses";
const OPENAI_CODEX_AUTH_MODE_ENV: &str = "OPENAI_AUTH_MODE";
const OPENAI_CODEX_ACCESS_TOKEN_ENV: &str = "OPENAI_ACCESS_TOKEN";
const OPENAI_CODEX_CLIENT_VERSION_ENV: &str = "OPENAI_CLIENT_VERSION";
const OPENAI_CODEX_DEFAULT_CLIENT_VERSION: &str = "0.118.0";
const OPENAI_CODEX_AUTH_MODE: &str = "codex";

#[derive(Debug, Clone, PartialEq, Eq)]
enum OpenAIAuth {
    ApiKey(String),
    Codex {
        access_token: String,
        client_version: String,
    },
}

#[derive(Debug, Clone, PartialEq, Eq)]
enum OpenAIResponsesAuth {
    ApiKey {
        api_key: String,
    },
    Codex {
        access_token: String,
        client_version: String,
    },
}

pub struct OpenAIProvider {
    client: Client,
    auth: OpenAIAuth,
    model: &'static str,
    retry_config: RetryConfig,
}

impl OpenAIProvider {
    fn new(auth: OpenAIAuth, model: &'static str) -> Self {
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

    fn from_env(api_model: &'static str, codex_model: &'static str) -> Self {
        let auth = resolve_openai_auth(
            env::var("OPENAI_API_KEY").unwrap_or_default(),
            env::var(OPENAI_CODEX_ACCESS_TOKEN_ENV).unwrap_or_default(),
            env::var(OPENAI_CODEX_AUTH_MODE_ENV).unwrap_or_default(),
            env::var(OPENAI_CODEX_CLIENT_VERSION_ENV).ok(),
        );
        let model = match auth {
            OpenAIAuth::ApiKey(_) => api_model,
            OpenAIAuth::Codex { .. } => codex_model,
        };
        Self::new(auth, model)
    }

    pub fn gpt54() -> Self {
        Self::from_env("gpt-5.4", "gpt-5.4")
    }

    pub fn gpt54_mini() -> Self {
        Self::from_env("gpt-5.4-mini", "gpt-5.4-mini")
    }

    pub fn gpt4o() -> Self {
        Self::gpt54()
    }

    pub fn gpt4o_mini() -> Self {
        Self::gpt54_mini()
    }

    pub fn o1() -> Self {
        Self::from_env("o1", "gpt-5.4")
    }

    pub fn o3_mini() -> Self {
        Self::from_env("o3-mini", "gpt-5.4")
    }

    async fn stream_openai_responses(
        &self,
        messages: &[Message],
        tools: &[ToolSchema],
        config: &AgentConfig,
        auth: OpenAIResponsesAuth,
    ) -> Result<MessageStream, AgentError> {
        let input = build_openai_responses_input(messages);
        let api_tools: Vec<Value> = tools.iter().map(tool_schema_to_responses_json).collect();
        let body = build_openai_responses_body(self.model.to_string(), config, input, api_tools);

        let retry_config = self.retry_config.clone();
        let client = self.client.clone();

        let response = with_retry(
            &retry_config,
            &tokio_util::sync::CancellationToken::new(),
            || {
                let client = client.clone();
                let auth = auth.clone();
                let body = body.clone();
                async move {
                    let request = match auth {
                        OpenAIResponsesAuth::ApiKey { api_key } => client
                            .post(OPENAI_RESPONSES_API)
                            .header("authorization", format!("Bearer {api_key}"))
                            .header("content-type", "application/json"),
                        OpenAIResponsesAuth::Codex {
                            access_token,
                            client_version,
                        } => client
                            .post(OPENAI_CODEX_RESPONSES_API)
                            .query(&[("client_version", client_version)])
                            .header("authorization", format!("Bearer {access_token}"))
                            .header("content-type", "application/json"),
                    };

                    let response = request
                        .json(&body)
                        .send()
                        .await
                        .map_err(|error| AgentError::HttpError(error.to_string()))?;

                    if !response.status().is_success() {
                        let status = response.status().as_u16();
                        let body = response.text().await.unwrap_or_default();
                        return Err(AgentError::ApiError { status, body });
                    }

                    Ok(response)
                }
            },
        )
        .await?;

        let event_stream = response.bytes_stream().eventsource();

        let parsed_stream = stream! {
            let mut final_usage = TokenUsage::default();
            let mut text_buffer = String::new();
            let mut tool_calls: HashMap<String, ToolCallInProgress> = HashMap::new();
            let mut tool_indices: HashMap<String, usize> = HashMap::new();
            let mut tool_order: Vec<String> = Vec::new();
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
                    debug!("OpenAI Responses SSE stream received [DONE]");
                    break;
                }

                let payload = match serde_json::from_str::<Value>(&event.data) {
                    Ok(payload) => payload,
                    Err(error) => {
                        warn!(data = %event.data, error = %error, "failed to parse OpenAI Responses SSE chunk");
                        continue;
                    }
                };

                match payload.get("type").and_then(Value::as_str).unwrap_or_default() {
                    "response.output_text.delta" => {
                        if let Some(text) = payload.get("delta").and_then(Value::as_str) {
                            text_buffer.push_str(text);
                            yield Ok(StreamEvent::TextDelta {
                                index: 0,
                                text: text.to_string(),
                            });
                        }
                    }
                    // Only forward the model-provided reasoning SUMMARY.
                    // Raw `response.reasoning_text.delta` content is not
                    // stable user-facing copy and often reads like gibberish
                    // or partial chain-of-thought. The Swift direct-cloud
                    // client already applies this filter; keep the Rust path
                    // aligned so main chat, agent chat, and command-center
                    // surfaces behave the same way.
                    "response.reasoning_summary_text.delta" => {
                        if let Some(text) = openai_responses_visible_reasoning_delta(&payload) {
                            yield Ok(StreamEvent::ThinkingDelta {
                                index: 0,
                                text,
                            });
                        }
                    }
                    "response.output_item.added" | "response.output_item.done" => {
                        if let Some(item) = payload.get("item") {
                            if item.get("type").and_then(Value::as_str) == Some("function_call") {
                                let Some((item_id, call_id)) = response_function_call_ids(item) else {
                                    continue;
                                };
                                let name = item
                                    .get("name")
                                    .and_then(Value::as_str)
                                    .unwrap_or_default()
                                    .to_string();
                                let arguments = item
                                    .get("arguments")
                                    .and_then(Value::as_str)
                                    .unwrap_or_default()
                                    .to_string();
                                let next_index = tool_order.len();
                                tool_indices.entry(item_id.clone()).or_insert_with(|| {
                                    tool_order.push(item_id.clone());
                                    next_index
                                });
                                let entry = tool_calls.entry(item_id.clone()).or_insert_with(|| ToolCallInProgress {
                                    id: call_id.clone(),
                                    name: name.clone(),
                                    arguments: String::new(),
                                });
                                entry.id = call_id;
                                if !name.is_empty() {
                                    entry.name = name;
                                }
                                if !arguments.is_empty() {
                                    entry.arguments = arguments;
                                }
                            }
                        }
                    }
                    "response.function_call_arguments.delta" => {
                        let item_id = payload
                            .get("item_id")
                            .and_then(Value::as_str)
                            .unwrap_or_default()
                            .to_string();
                        let delta = payload
                            .get("delta")
                            .and_then(Value::as_str)
                            .unwrap_or_default()
                            .to_string();
                        if item_id.is_empty() || delta.is_empty() {
                            continue;
                        }
                        let next_index = tool_order.len();
                        let index = *tool_indices.entry(item_id.clone()).or_insert_with(|| {
                            tool_order.push(item_id.clone());
                            next_index
                        });
                        let entry = tool_calls.entry(item_id.clone()).or_insert_with(|| ToolCallInProgress {
                            id: item_id.clone(),
                            name: String::new(),
                            arguments: String::new(),
                        });
                        entry.arguments.push_str(&delta);
                        yield Ok(StreamEvent::InputJsonDelta {
                            index,
                            partial_json: delta,
                        });
                    }
                    "response.function_call_arguments.done" => {
                        let item_id = payload
                            .get("item_id")
                            .and_then(Value::as_str)
                            .unwrap_or_default();
                        if let Some(arguments) = payload.get("arguments").and_then(Value::as_str) {
                            if let Some(entry) = tool_calls.get_mut(item_id) {
                                entry.arguments = arguments.to_string();
                            }
                        }
                    }
                    "response.completed" => {
                        if let Some(usage) = payload
                            .get("response")
                            .and_then(|response| response.get("usage"))
                        {
                            merge_codex_usage(&mut final_usage, usage);
                        }
                    }
                    "response.failed" | "error" => {
                        let message = payload
                            .get("error")
                            .and_then(|error| error.get("message"))
                            .and_then(Value::as_str)
                            .or_else(|| payload.get("message").and_then(Value::as_str))
                            .unwrap_or("OpenAI Responses request failed")
                            .to_string();
                        yield Err(AgentError::ApiError {
                            status: 400,
                            body: message,
                        });
                        return;
                    }
                    _ => {}
                }
            }

            if !text_buffer.is_empty() {
                yield Ok(StreamEvent::ContentBlockComplete {
                    block: ContentBlock::Text { text: text_buffer },
                });
            }

            for id in tool_order {
                if let Some(tc) = tool_calls.remove(&id) {
                    let input = serde_json::from_str(&tc.arguments).unwrap_or(Value::Null);
                    yield Ok(StreamEvent::ContentBlockComplete {
                        block: ContentBlock::ToolUse {
                            id: tc.id,
                            name: tc.name,
                            input,
                        },
                    });
                }
            }

            let stop_reason = if tool_indices.is_empty() {
                StopReason::EndTurn
            } else {
                StopReason::ToolUse
            };

            yield Ok(StreamEvent::MessageStop {
                stop_reason,
                usage: final_usage,
            });
        };

        Ok(Box::pin(parsed_stream))
    }
}

// ---------------------------------------------------------------------------
// In-progress tool call accumulator
// ---------------------------------------------------------------------------

struct ToolCallInProgress {
    id: String,
    name: String,
    arguments: String,
}

// ---------------------------------------------------------------------------
// AgentProvider implementation
// ---------------------------------------------------------------------------

#[async_trait]
impl AgentProvider for OpenAIProvider {
    async fn stream_message(
        &self,
        messages: &[Message],
        tools: &[ToolSchema],
        config: &AgentConfig,
    ) -> Result<MessageStream, AgentError> {
        match &self.auth {
            OpenAIAuth::ApiKey(api_key) => {
                if api_key.trim().is_empty() {
                    return Err(AgentError::Provider(
                        "OPENAI_API_KEY is not configured".to_string(),
                    ));
                }
                self.stream_openai_responses(
                    messages,
                    tools,
                    config,
                    OpenAIResponsesAuth::ApiKey {
                        api_key: api_key.clone(),
                    },
                )
                .await
            }
            OpenAIAuth::Codex {
                access_token,
                client_version,
            } => {
                if access_token.trim().is_empty() {
                    return Err(AgentError::Provider(
                        "OPENAI_ACCESS_TOKEN is not configured".to_string(),
                    ));
                }
                self.stream_openai_responses(
                    messages,
                    tools,
                    config,
                    OpenAIResponsesAuth::Codex {
                        access_token: access_token.clone(),
                        client_version: client_version.clone(),
                    },
                )
                .await
            }
        }
    }

    async fn compact(&self, messages: &[Message]) -> Result<Vec<Message>, AgentError> {
        Ok(crate::compaction::compact_messages(messages, 8, 16_384))
    }

    fn capabilities(&self) -> ProviderCapabilities {
        let (max_ctx, max_out, cost_in, cost_out) = match self.model {
            "gpt-4o" => (128_000, 16_384, 2.50, 10.00),
            "gpt-4o-mini" => (128_000, 16_384, 0.15, 0.60),
            "o1" => (200_000, 100_000, 15.00, 60.00),
            "o3-mini" => (200_000, 100_000, 1.10, 4.40),
            "gpt-5.4" => (400_000, 128_000, 1.25, 10.00),
            "gpt-5.4-mini" => (400_000, 128_000, 0.25, 2.00),
            _ => (128_000, 16_384, 2.50, 10.00),
        };

        ProviderCapabilities {
            max_context_tokens: max_ctx,
            max_output_tokens: max_out,
            supports_thinking: matches!(self.model, "gpt-5.4" | "gpt-5.4-mini"),
            supports_vision: matches!(
                self.model,
                "gpt-4o" | "gpt-4o-mini" | "gpt-5.4" | "gpt-5.4-mini"
            ),
            supports_web_search: false,
            supports_code_execution: false,
            supports_computer_use: matches!(self.model, "gpt-4o" | "gpt-5.4"),
            supports_mcp: false,
            supports_streaming: true,
            supports_compaction: true,
            cost_input_per_million: cost_in,
            cost_output_per_million: cost_out,
        }
    }

    fn name(&self) -> &'static str {
        self.model
    }
}

fn build_openai_responses_input(messages: &[Message]) -> Vec<Value> {
    let mut input = Vec::new();

    for message in messages {
        match message {
            Message::User { content } => {
                let mut pending_content: Vec<Value> = Vec::new();

                for item in content {
                    match item {
                        UserContent::Text { text } => pending_content.push(json!({
                            "type": "input_text",
                            "text": text,
                        })),
                        UserContent::Image { source } => pending_content.push(json!({
                            "type": "input_image",
                            "image_url": format!(
                                "data:{};base64,{}",
                                source.media_type,
                                source.data
                            ),
                        })),
                        UserContent::ToolResult(result) => {
                            if !pending_content.is_empty() {
                                input.push(json!({
                                    "type": "message",
                                    "role": "user",
                                    "content": pending_content,
                                }));
                                pending_content = Vec::new();
                            }

                            let output = result
                                .content
                                .iter()
                                .filter_map(|entry| match entry {
                                    ToolResultContent::Text { text } => Some(text.as_str()),
                                    ToolResultContent::Image { .. } => None,
                                })
                                .collect::<Vec<_>>()
                                .join("\n");

                            input.push(json!({
                                "type": "function_call_output",
                                "call_id": result.tool_use_id,
                                "output": output,
                            }));
                        }
                    }
                }

                if !pending_content.is_empty() {
                    input.push(json!({
                        "type": "message",
                        "role": "user",
                        "content": pending_content,
                    }));
                }
            }
            Message::Assistant { content } => {
                let mut pending_text = String::new();

                for block in content {
                    match block {
                        ContentBlock::Text { text } => {
                            pending_text.push_str(text);
                        }
                        ContentBlock::Thinking { thinking, .. } => {
                            if !thinking.is_empty() {
                                if !pending_text.is_empty() {
                                    pending_text.push_str("\n\n");
                                }
                                pending_text.push_str("[thinking]\n");
                                pending_text.push_str(thinking);
                            }
                        }
                        ContentBlock::RedactedThinking { .. } => {}
                        ContentBlock::ToolUse {
                            id,
                            name,
                            input: tool_input,
                        } => {
                            if !pending_text.is_empty() {
                                input.push(json!({
                                    "type": "message",
                                    "role": "assistant",
                                    "content": [{
                                        "type": "output_text",
                                        "text": pending_text,
                                    }],
                                }));
                                pending_text = String::new();
                            }

                            input.push(json!({
                                "type": "function_call",
                                "id": id,
                                "call_id": id,
                                "name": name,
                                "arguments": serde_json::to_string(tool_input)
                                    .unwrap_or_else(|_| "{}".to_string()),
                            }));
                        }
                    }
                }

                if !pending_text.is_empty() {
                    input.push(json!({
                        "type": "message",
                        "role": "assistant",
                        "content": [{
                            "type": "output_text",
                            "text": pending_text,
                        }],
                    }));
                }
            }
        }
    }

    input
}

fn tool_schema_to_responses_json(tool: &ToolSchema) -> Value {
    let parameters = normalized_strict_tool_parameters(&tool.parameters);
    json!({
        "type": "function",
        "name": tool.name,
        "description": tool.description,
        "parameters": parameters,
        "strict": true,
    })
}

fn build_openai_responses_body(
    model: String,
    config: &AgentConfig,
    input: Vec<Value>,
    api_tools: Vec<Value>,
) -> Value {
    let mut body = json!({
        "model": model,
        "instructions": config.system_prompt.clone().unwrap_or_else(|| "You are a helpful assistant.".to_string()),
        "input": input,
        "stream": true,
        "store": false,
        "text": { "verbosity": "low" },
    });

    if !api_tools.is_empty() {
        body["tools"] = json!(api_tools);
        body["tool_choice"] = json!("auto");
        body["parallel_tool_calls"] = json!(true);
    }

    if let Some(max_tokens) = config.max_output_tokens {
        body["max_output_tokens"] = json!(max_tokens);
    }

    let reasoning_effort = openai_responses_reasoning_effort(config);
    if reasoning_effort != "none" {
        body["reasoning"] = json!({
            "effort": reasoning_effort,
            "summary": "auto",
        });
    }

    body
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn resolve_openai_auth(
    api_key: String,
    access_token: String,
    auth_mode: String,
    client_version_override: Option<String>,
) -> OpenAIAuth {
    let trimmed_api_key = api_key.trim().to_string();
    let trimmed_access_token = access_token.trim().to_string();
    let prefers_codex = auth_mode
        .trim()
        .eq_ignore_ascii_case(OPENAI_CODEX_AUTH_MODE)
        || (trimmed_api_key.is_empty() && !trimmed_access_token.is_empty());

    if prefers_codex && !trimmed_access_token.is_empty() {
        OpenAIAuth::Codex {
            access_token: trimmed_access_token,
            client_version: client_version_override
                .map(|value| value.trim().to_string())
                .filter(|value| !value.is_empty())
                .unwrap_or_else(load_codex_client_version),
        }
    } else {
        OpenAIAuth::ApiKey(trimmed_api_key)
    }
}

fn load_codex_client_version() -> String {
    let from_cache = env::var("HOME")
        .ok()
        .map(PathBuf::from)
        .map(|path| path.join(".codex").join("models_cache.json"))
        .and_then(|path| fs::read_to_string(path).ok())
        .and_then(|contents| serde_json::from_str::<Value>(&contents).ok())
        .and_then(|value| {
            value
                .get("client_version")
                .and_then(Value::as_str)
                .map(str::to_string)
        })
        .filter(|value| !value.trim().is_empty());

    from_cache.unwrap_or_else(|| OPENAI_CODEX_DEFAULT_CLIENT_VERSION.to_string())
}

fn openai_responses_reasoning_effort(config: &AgentConfig) -> &'static str {
    if !config.enable_thinking {
        return "none";
    }

    match config.effort {
        crate::agent_loop::Effort::Low => "low",
        crate::agent_loop::Effort::Medium => "medium",
        crate::agent_loop::Effort::High => "high",
        crate::agent_loop::Effort::Max => "xhigh",
    }
}

fn response_function_call_ids(item: &Value) -> Option<(String, String)> {
    let item_id = item
        .get("id")
        .and_then(Value::as_str)
        .filter(|value| !value.is_empty())
        .or_else(|| item.get("call_id").and_then(Value::as_str))
        .filter(|value| !value.is_empty())?
        .to_string();
    let call_id = item
        .get("call_id")
        .and_then(Value::as_str)
        .filter(|value| !value.is_empty())
        .unwrap_or(item_id.as_str())
        .to_string();

    Some((item_id, call_id))
}

fn merge_codex_usage(into: &mut TokenUsage, usage: &Value) {
    into.input_tokens = usage
        .get("input_tokens")
        .and_then(Value::as_u64)
        .map(|value| value as u32)
        .unwrap_or(into.input_tokens);
    into.output_tokens = usage
        .get("output_tokens")
        .and_then(Value::as_u64)
        .map(|value| value as u32)
        .unwrap_or(into.output_tokens);
}

fn openai_responses_visible_reasoning_delta(payload: &Value) -> Option<String> {
    let event_type = payload.get("type").and_then(Value::as_str)?;
    if event_type != "response.reasoning_summary_text.delta" {
        return None;
    }
    payload
        .get("delta")
        .and_then(Value::as_str)
        .map(str::to_string)
}

#[cfg_attr(not(any(test, feature = "pro-build")), allow(dead_code))]
pub(crate) fn extract_openai_responses_output_text(payload: &Value) -> String {
    if let Some(text) = payload.get("output_text").and_then(Value::as_str) {
        return text.to_string();
    }

    payload
        .get("output")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(|item| item.get("content").and_then(Value::as_array))
        .flatten()
        .filter_map(|content| content.get("text").and_then(Value::as_str))
        .collect::<Vec<_>>()
        .join("\n")
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::{
        ContentBlock, ImageSource, Message, ToolResult, ToolResultContent, UserContent,
    };
    use serde_json::json;

    #[test]
    fn openai_responses_reasoning_effort_uses_xhigh_for_max() {
        let config = AgentConfig {
            enable_thinking: true,
            effort: crate::agent_loop::Effort::Max,
            ..AgentConfig::default()
        };

        assert_eq!(openai_responses_reasoning_effort(&config), "xhigh");
    }

    #[test]
    fn openai_api_key_provider_has_no_chat_completions_fallback() {
        let source = include_str!("openai.rs");
        let legacy_fragment = ["chat", "completions"].join("/");

        assert!(
            source.contains("client.post(OPENAI_RESPONSES_API)"),
            "API-key OpenAI traffic must use the public Responses endpoint"
        );
        assert!(
            !source.contains(&legacy_fragment),
            "the legacy Chat Completions fallback must not remain in the live provider"
        );
    }

    #[test]
    fn visible_reasoning_delta_ignores_raw_responses_reasoning_text() {
        let summary = json!({
            "type": "response.reasoning_summary_text.delta",
            "delta": "Checking the note structure"
        });
        let raw = json!({
            "type": "response.reasoning_text.delta",
            "delta": "Private chain of thought"
        });

        assert_eq!(
            openai_responses_visible_reasoning_delta(&summary),
            Some("Checking the note structure".to_string())
        );
        assert_eq!(openai_responses_visible_reasoning_delta(&raw), None);
    }

    #[test]
    fn extracts_non_streaming_responses_output_text() {
        let direct = json!({
            "output_text": "direct text"
        });
        let nested = json!({
            "output": [{
                "type": "message",
                "content": [
                    { "type": "output_text", "text": "first" },
                    { "type": "output_text", "text": "second" }
                ]
            }]
        });

        assert_eq!(extract_openai_responses_output_text(&direct), "direct text");
        assert_eq!(
            extract_openai_responses_output_text(&nested),
            "first\nsecond"
        );
    }

    #[test]
    fn resolves_codex_auth_when_access_token_is_present() {
        let auth = resolve_openai_auth(
            "sk-openai".to_string(),
            "codex-token".to_string(),
            "codex".to_string(),
            Some("0.200.0".to_string()),
        );

        assert_eq!(
            auth,
            OpenAIAuth::Codex {
                access_token: "codex-token".to_string(),
                client_version: "0.200.0".to_string(),
            }
        );
    }

    #[test]
    fn legacy_gpt4o_alias_uses_current_gpt54_model() {
        let provider = OpenAIProvider::gpt4o();

        assert_eq!(provider.model, "gpt-5.4");
    }

    #[test]
    fn legacy_gpt4o_mini_alias_uses_current_gpt54_mini_model() {
        let provider = OpenAIProvider::gpt4o_mini();

        assert_eq!(provider.model, "gpt-5.4-mini");
    }

    #[test]
    fn builds_openai_responses_input_with_function_call_round_trip() {
        let messages = vec![
            Message::user_text("Use the tool."),
            Message::Assistant {
                content: vec![ContentBlock::ToolUse {
                    id: "fc_call_1".to_string(),
                    name: "echo".to_string(),
                    input: json!({ "message": "hello-world" }),
                }],
            },
            Message::User {
                content: vec![UserContent::ToolResult(ToolResult {
                    tool_use_id: "fc_call_1".to_string(),
                    content: vec![ToolResultContent::Text {
                        text: "{\"message\":\"hello-world\"}".to_string(),
                    }],
                    is_error: false,
                })],
            },
        ];

        let input = build_openai_responses_input(&messages);

        assert_eq!(input.len(), 3);
        assert_eq!(input[0]["type"], "message");
        assert_eq!(input[0]["role"], "user");
        assert_eq!(input[1]["type"], "function_call");
        assert_eq!(input[1]["id"], "fc_call_1");
        assert_eq!(input[1]["call_id"], "fc_call_1");
        assert_eq!(input[1]["name"], "echo");
        assert_eq!(input[2]["type"], "function_call_output");
        assert_eq!(input[2]["call_id"], "fc_call_1");
        assert_eq!(input[2]["output"], "{\"message\":\"hello-world\"}");
    }

    #[test]
    fn builds_openai_responses_input_with_text_image_and_tool_result() {
        let messages = vec![
            Message::User {
                content: vec![
                    UserContent::Text {
                        text: "What is this?".to_string(),
                    },
                    UserContent::Image {
                        source: ImageSource {
                            source_type: "base64".to_string(),
                            media_type: "image/png".to_string(),
                            data: "abc123".to_string(),
                        },
                    },
                ],
            },
            Message::User {
                content: vec![UserContent::ToolResult(ToolResult {
                    tool_use_id: "fc_call_1".to_string(),
                    content: vec![ToolResultContent::Text {
                        text: "found 3 results".to_string(),
                    }],
                    is_error: false,
                })],
            },
        ];

        let input = build_openai_responses_input(&messages);

        assert_eq!(input.len(), 2);
        assert_eq!(input[0]["type"], "message");
        assert_eq!(input[0]["role"], "user");
        assert_eq!(input[0]["content"][0]["type"], "input_text");
        assert_eq!(input[0]["content"][0]["text"], "What is this?");
        assert_eq!(input[0]["content"][1]["type"], "input_image");
        assert!(
            input[0]["content"][1]["image_url"]
                .as_str()
                .unwrap()
                .starts_with("data:image/png;base64,")
        );
        assert_eq!(input[1]["type"], "function_call_output");
        assert_eq!(input[1]["call_id"], "fc_call_1");
        assert_eq!(input[1]["output"], "found 3 results");
    }

    #[test]
    fn responses_tool_schema_is_flat_function_shape() {
        let schema = ToolSchema {
            name: "read_file".to_string(),
            description: "Read a file".to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "path": { "type": "string" }
                },
                "required": ["path"]
            }),
        };

        let tool_json = tool_schema_to_responses_json(&schema);
        assert_eq!(tool_json["type"], "function");
        assert_eq!(tool_json["name"], "read_file");
        assert_eq!(tool_json["description"], "Read a file");
        assert_eq!(tool_json["strict"], true);
        assert!(tool_json["parameters"]["properties"]["path"].is_object());
    }

    #[test]
    fn responses_tool_schema_closes_object_parameters_recursively_for_strict_mode() {
        let schema = ToolSchema {
            name: "write_file".to_string(),
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
                },
                "required": ["path"]
            }),
        };

        let tool_json = tool_schema_to_responses_json(&schema);
        assert_eq!(tool_json["strict"], true);
        assert_eq!(tool_json["parameters"]["additionalProperties"], false);
        assert_eq!(
            tool_json["parameters"]["properties"]["options"]["additionalProperties"],
            false
        );
    }

    #[test]
    fn responses_tool_schema_requires_every_property_and_keeps_optional_inputs_nullable() {
        let tool_json =
            tool_schema_to_responses_json(&crate::tools::filesystem::read_file_schema());
        let mut required_names: Vec<&str> = tool_json["parameters"]["required"]
            .as_array()
            .expect("required array")
            .iter()
            .filter_map(Value::as_str)
            .collect();
        required_names.sort_unstable();

        assert_eq!(required_names, vec!["limit", "offset", "path"]);
        assert_eq!(
            tool_json["parameters"]["properties"]["path"]["type"],
            json!("string")
        );
        assert_eq!(
            tool_json["parameters"]["properties"]["offset"]["type"],
            json!(["integer", "null"])
        );
        assert_eq!(
            tool_json["parameters"]["properties"]["limit"]["type"],
            json!(["integer", "null"])
        );
    }

    #[test]
    fn responses_request_body_enables_auto_parallel_tool_calls_when_tools_exist() {
        let config = AgentConfig {
            system_prompt: Some("You are Hermes.".to_string()),
            ..Default::default()
        };
        let body = build_openai_responses_body(
            "gpt-5.4".to_string(),
            &config,
            vec![json!({
                "type": "message",
                "role": "user",
                "content": [{ "type": "input_text", "text": "Ping" }],
            })],
            vec![tool_schema_to_responses_json(&ToolSchema {
                name: "terminal".to_string(),
                description: "Run a shell command".to_string(),
                parameters: json!({
                    "type": "object",
                    "properties": {
                        "command": { "type": "string" }
                    },
                    "required": ["command"]
                }),
            })],
        );

        assert_eq!(body["tool_choice"], "auto");
        assert_eq!(body["parallel_tool_calls"], true);
        assert_eq!(body["tools"][0]["type"], "function");
        assert_eq!(body["tools"][0]["name"], "terminal");
        assert!(body["tools"][0]["function"].is_null());
    }

    #[test]
    fn responses_request_body_respects_max_output_tokens() {
        let config = AgentConfig {
            max_output_tokens: Some(8192),
            ..Default::default()
        };
        let body = build_openai_responses_body(
            "gpt-5.4".to_string(),
            &config,
            vec![json!({
                "type": "message",
                "role": "user",
                "content": [{ "type": "input_text", "text": "Ping" }],
            })],
            Vec::new(),
        );

        assert_eq!(body["max_output_tokens"], 8192);
    }

    #[test]
    fn responses_function_call_identity_prefers_call_id_for_tool_results() {
        let item = json!({
            "type": "function_call",
            "id": "fc_item_123",
            "call_id": "call_runtime_456",
            "name": "read_file",
            "arguments": "{\"path\":\"README.md\"}"
        });

        let (item_id, call_id) = response_function_call_ids(&item).expect("function ids");

        assert_eq!(item_id, "fc_item_123");
        assert_eq!(call_id, "call_runtime_456");
    }

    #[test]
    fn registered_agent_tools_emit_codex_safe_object_schemas() {
        use crate::storage::vault::VaultStore;
        use crate::tools::registry::{ToolRegistry, ToolTier};
        use std::sync::Arc;

        let vault = tempfile::tempdir().unwrap();
        let vault_path = vault.path().to_string_lossy().to_string();
        let store = VaultStore::open(&vault_path).expect("open temp vault");
        let registry = ToolRegistry::with_tier(
            Arc::new(store),
            true,
            Some(vault.path().to_path_buf()),
            ToolTier::Full,
        );

        for tool in registry.get_definitions() {
            let tool_json = tool_schema_to_responses_json(&tool);
            assert_closed_object_schemas(
                &tool_json["parameters"],
                true,
                &format!("tool `{}`", tool.name),
            );
        }
    }

    fn assert_closed_object_schemas(value: &Value, is_root: bool, context: &str) {
        if let Some(object) = value.as_object() {
            let is_object_schema = object.get("type").and_then(Value::as_str) == Some("object");
            let has_properties = matches!(object.get("properties"), Some(Value::Object(_)));
            if is_object_schema && (is_root || has_properties) {
                assert_eq!(
                    object.get("additionalProperties").and_then(Value::as_bool),
                    Some(false),
                    "{context} should set additionalProperties=false"
                );
            }

            if let Some(Value::Object(properties)) = object.get("properties") {
                for (name, nested) in properties {
                    assert_closed_object_schemas(
                        nested,
                        false,
                        &format!("{context} property `{name}`"),
                    );
                }
            }

            if let Some(items) = object.get("items") {
                assert_closed_object_schemas(items, false, &format!("{context} items"));
            }

            for key in ["anyOf", "oneOf", "allOf", "prefixItems"] {
                if let Some(Value::Array(values)) = object.get(key) {
                    for (index, nested) in values.iter().enumerate() {
                        assert_closed_object_schemas(
                            nested,
                            false,
                            &format!("{context} {key}[{index}]"),
                        );
                    }
                }
            }

            for key in ["$defs", "definitions"] {
                if let Some(Value::Object(values)) = object.get(key) {
                    for (name, nested) in values {
                        assert_closed_object_schemas(
                            nested,
                            false,
                            &format!("{context} {key}.{name}"),
                        );
                    }
                }
            }
        }
    }
}
