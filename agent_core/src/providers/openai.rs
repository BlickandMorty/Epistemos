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
use serde::Deserialize;
use serde_json::{json, Value};
use tracing::{debug, warn};

use crate::agent_loop::{AgentConfig, AgentError};
use crate::error::{with_retry, RetryConfig};
use crate::provider::{AgentProvider, MessageStream, ProviderCapabilities, StreamEvent};
use crate::types::{
    ContentBlock, Message, StopReason, TokenUsage, ToolResultContent, ToolSchema, UserContent,
};

const OPENAI_CHAT_COMPLETIONS_API: &str = "https://api.openai.com/v1/chat/completions";
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

    pub fn gpt4o() -> Self {
        Self::from_env("gpt-4o", "gpt-5.4")
    }

    pub fn gpt4o_mini() -> Self {
        Self::from_env("gpt-4o-mini", "gpt-5.4-mini")
    }

    pub fn o1() -> Self {
        Self::from_env("o1", "gpt-5.4")
    }

    pub fn o3_mini() -> Self {
        Self::from_env("o3-mini", "gpt-5.4")
    }

    async fn stream_chat_completions(
        &self,
        messages: &[Message],
        tools: &[ToolSchema],
        config: &AgentConfig,
        api_key: String,
    ) -> Result<MessageStream, AgentError> {
        let api_messages = build_openai_messages(messages, config.system_prompt.as_deref());
        let api_tools: Vec<Value> = tools.iter().map(tool_schema_to_openai_json).collect();

        let mut body = json!({
            "model": self.model,
            "messages": api_messages,
            "stream": true,
            "stream_options": { "include_usage": true },
        });

        if let Some(max_tokens) = config.max_output_tokens {
            body["max_completion_tokens"] = json!(max_tokens);
        }

        if !api_tools.is_empty() {
            body["tools"] = json!(api_tools);
        }

        let retry_config = self.retry_config.clone();
        let client = self.client.clone();

        let response = with_retry(
            &retry_config,
            &tokio_util::sync::CancellationToken::new(),
            || {
                let client = client.clone();
                let api_key = api_key.clone();
                let body = body.clone();
                async move {
                    let response = client
                        .post(OPENAI_CHAT_COMPLETIONS_API)
                        .header("authorization", format!("Bearer {api_key}"))
                        .header("content-type", "application/json")
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
            let mut final_stop_reason = StopReason::EndTurn;
            let mut final_usage = TokenUsage::default();
            let mut text_buffer = String::new();
            let mut tool_calls: HashMap<usize, ToolCallInProgress> = HashMap::new();
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
                    debug!("OpenAI SSE stream received [DONE]");
                    break;
                }

                let chunk = match serde_json::from_str::<RawChunk>(&event.data) {
                    Ok(chunk) => chunk,
                    Err(error) => {
                        warn!(data = %event.data, error = %error, "failed to parse OpenAI SSE chunk");
                        continue;
                    }
                };

                if let Some(usage) = chunk.usage {
                    merge_usage(&mut final_usage, &usage);
                }

                for choice in chunk.choices {
                    if let Some(finish_reason) = choice.finish_reason.as_deref() {
                        final_stop_reason = map_finish_reason(finish_reason);
                    }

                    if let Some(delta) = choice.delta {
                        if let Some(reasoning) = delta.reasoning_content {
                            if !reasoning.is_empty() {
                                yield Ok(StreamEvent::ThinkingDelta {
                                    index: 0,
                                    text: reasoning,
                                });
                            }
                        }

                        if let Some(text) = delta.content {
                            text_buffer.push_str(&text);
                            yield Ok(StreamEvent::TextDelta {
                                index: 0,
                                text,
                            });
                        }

                        for tc_delta in delta.tool_calls {
                            let tc_index = tc_delta.index;

                            if let Some(id) = tc_delta.id {
                                let name = tc_delta
                                    .function
                                    .as_ref()
                                    .and_then(|f| f.name.clone())
                                    .unwrap_or_default();
                                tool_calls.insert(
                                    tc_index,
                                    ToolCallInProgress {
                                        id,
                                        name,
                                        arguments: String::new(),
                                    },
                                );
                            }

                            if let Some(func) = tc_delta.function {
                                if let Some(name) = func.name {
                                    if let Some(tc) = tool_calls.get_mut(&tc_index) {
                                        if tc.name.is_empty() {
                                            tc.name = name;
                                        }
                                    }
                                }
                                if let Some(args) = func.arguments {
                                    if let Some(tc) = tool_calls.get_mut(&tc_index) {
                                        tc.arguments.push_str(&args);
                                        yield Ok(StreamEvent::InputJsonDelta {
                                            index: tc_index,
                                            partial_json: args,
                                        });
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if !text_buffer.is_empty() {
                yield Ok(StreamEvent::ContentBlockComplete {
                    block: ContentBlock::Text { text: text_buffer },
                });
            }

            let mut sorted_indices: Vec<usize> = tool_calls.keys().copied().collect();
            sorted_indices.sort_unstable();
            for idx in sorted_indices {
                if let Some(tc) = tool_calls.remove(&idx) {
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

            yield Ok(StreamEvent::MessageStop {
                stop_reason: final_stop_reason,
                usage: final_usage,
            });
        };

        Ok(Box::pin(parsed_stream))
    }

    async fn stream_codex_responses(
        &self,
        messages: &[Message],
        tools: &[ToolSchema],
        config: &AgentConfig,
        access_token: String,
        client_version: String,
    ) -> Result<MessageStream, AgentError> {
        let input = build_codex_input(messages);
        let api_tools: Vec<Value> = tools.iter().map(tool_schema_to_codex_json).collect();
        let body = build_codex_responses_body(self.model.to_string(), config, input, api_tools);

        let retry_config = self.retry_config.clone();
        let client = self.client.clone();

        let response = with_retry(
            &retry_config,
            &tokio_util::sync::CancellationToken::new(),
            || {
                let client = client.clone();
                let access_token = access_token.clone();
                let body = body.clone();
                let client_version = client_version.clone();
                async move {
                    let response = client
                        .post(OPENAI_CODEX_RESPONSES_API)
                        .query(&[("client_version", client_version)])
                        .header("authorization", format!("Bearer {access_token}"))
                        .header("content-type", "application/json")
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
                    debug!("OpenAI Codex SSE stream received [DONE]");
                    break;
                }

                let payload = match serde_json::from_str::<Value>(&event.data) {
                    Ok(payload) => payload,
                    Err(error) => {
                        warn!(data = %event.data, error = %error, "failed to parse OpenAI Codex SSE chunk");
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
                                let id = item
                                    .get("id")
                                    .and_then(Value::as_str)
                                    .unwrap_or_default()
                                    .to_string();
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
                                if !id.is_empty() {
                                    let next_index = tool_order.len();
                                    tool_indices.entry(id.clone()).or_insert_with(|| {
                                        tool_order.push(id.clone());
                                        next_index
                                    });
                                    let entry = tool_calls.entry(id.clone()).or_insert_with(|| ToolCallInProgress {
                                        id: id.clone(),
                                        name: name.clone(),
                                        arguments: String::new(),
                                    });
                                    if !name.is_empty() {
                                        entry.name = name;
                                    }
                                    if !arguments.is_empty() {
                                        entry.arguments = arguments;
                                    }
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
                            .unwrap_or("OpenAI Codex request failed")
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
// SSE chunk deserialization types (matching OpenAI streaming response format)
// ---------------------------------------------------------------------------

#[derive(Deserialize, Debug, Default)]
struct RawChunk {
    #[serde(default)]
    choices: Vec<RawChoice>,
    usage: Option<UsageData>,
}

#[derive(Deserialize, Debug, Default)]
struct RawChoice {
    delta: Option<RawDelta>,
    finish_reason: Option<String>,
}

#[derive(Deserialize, Debug, Default)]
struct RawDelta {
    content: Option<String>,
    // DeepSeek-R1 / some OpenAI-compatible gateways (Together, Groq,
    // Novita, etc.) put the model's reasoning in a separate field on
    // the delta. If we don't explicitly capture it serde silently drops
    // it and the caller never sees the thinking trace. Route it to
    // ThinkingDelta just like the Responses API reasoning events.
    reasoning_content: Option<String>,
    #[serde(default)]
    tool_calls: Vec<RawToolCallDelta>,
}

#[derive(Deserialize, Debug, Default, Clone)]
struct RawToolCallDelta {
    index: usize,
    id: Option<String>,
    function: Option<RawFunctionDelta>,
}

#[derive(Deserialize, Debug, Default, Clone)]
struct RawFunctionDelta {
    name: Option<String>,
    arguments: Option<String>,
}

#[derive(Deserialize, Debug, Default)]
struct UsageData {
    prompt_tokens: Option<u32>,
    completion_tokens: Option<u32>,
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
                self.stream_chat_completions(messages, tools, config, api_key.clone())
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
                self.stream_codex_responses(
                    messages,
                    tools,
                    config,
                    access_token.clone(),
                    client_version.clone(),
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

// ---------------------------------------------------------------------------
// Message conversion: internal types -> OpenAI Chat Completions format
// ---------------------------------------------------------------------------

fn build_openai_messages(messages: &[Message], system_prompt: Option<&str>) -> Vec<Value> {
    let mut api_messages = Vec::with_capacity(messages.len() + 1);

    if let Some(system) = system_prompt {
        api_messages.push(json!({
            "role": "system",
            "content": system,
        }));
    }

    for message in messages {
        match message {
            Message::User { content } => {
                // Tool results get emitted as separate "tool" role messages.
                // Plain text and images become a single "user" message.
                let mut user_parts: Vec<Value> = Vec::new();

                for item in content {
                    match item {
                        UserContent::Text { text } => {
                            user_parts.push(json!({
                                "type": "text",
                                "text": text,
                            }));
                        }
                        UserContent::Image { source } => {
                            user_parts.push(json!({
                                "type": "image_url",
                                "image_url": {
                                    "url": format!(
                                        "data:{};base64,{}",
                                        source.media_type,
                                        source.data
                                    ),
                                },
                            }));
                        }
                        UserContent::ToolResult(result) => {
                            let text_content = result
                                .content
                                .iter()
                                .filter_map(|entry| match entry {
                                    ToolResultContent::Text { text } => Some(text.as_str()),
                                    ToolResultContent::Image { .. } => None,
                                })
                                .collect::<Vec<_>>()
                                .join("\n");

                            api_messages.push(json!({
                                "role": "tool",
                                "tool_call_id": result.tool_use_id,
                                "content": text_content,
                            }));
                        }
                    }
                }

                if !user_parts.is_empty() {
                    if user_parts.len() == 1 && user_parts[0]["type"] == "text" {
                        // Single text content can use the simple string form
                        api_messages.push(json!({
                            "role": "user",
                            "content": user_parts[0]["text"].as_str().unwrap_or(""),
                        }));
                    } else {
                        api_messages.push(json!({
                            "role": "user",
                            "content": user_parts,
                        }));
                    }
                }
            }
            Message::Assistant { content } => {
                let mut text_parts = String::new();
                let mut tool_calls_json: Vec<Value> = Vec::new();

                for block in content {
                    match block {
                        ContentBlock::Text { text } => {
                            text_parts.push_str(text);
                        }
                        ContentBlock::Thinking { thinking, .. } => {
                            // OpenAI has no thinking block; prepend as context
                            if !thinking.is_empty() {
                                text_parts.push_str("[thinking]\n");
                                text_parts.push_str(thinking);
                                text_parts.push('\n');
                            }
                        }
                        ContentBlock::ToolUse { id, name, input } => {
                            tool_calls_json.push(json!({
                                "id": id,
                                "type": "function",
                                "function": {
                                    "name": name,
                                    "arguments": serde_json::to_string(input)
                                        .unwrap_or_else(|_| "{}".to_string()),
                                },
                            }));
                        }
                    }
                }

                let mut msg = json!({ "role": "assistant" });
                if !text_parts.is_empty() || tool_calls_json.is_empty() {
                    msg["content"] = json!(text_parts);
                }
                if !tool_calls_json.is_empty() {
                    msg["tool_calls"] = json!(tool_calls_json);
                }
                api_messages.push(msg);
            }
        }
    }

    api_messages
}

fn build_codex_input(messages: &[Message]) -> Vec<Value> {
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

fn tool_schema_to_openai_json(tool: &ToolSchema) -> Value {
    json!({
        "type": "function",
        "function": {
            "name": tool.name,
            "description": tool.description,
            "parameters": tool.parameters,
        },
    })
}

fn tool_schema_to_codex_json(tool: &ToolSchema) -> Value {
    json!({
        "type": "function",
        "name": tool.name,
        "description": tool.description,
        "parameters": tool.parameters,
        "strict": true,
    })
}

fn build_codex_responses_body(
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

    let reasoning_effort = codex_reasoning_effort(config);
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

fn codex_reasoning_effort(config: &AgentConfig) -> &'static str {
    if !config.enable_thinking {
        return "none";
    }

    match config.effort {
        crate::agent_loop::Effort::Low => "low",
        crate::agent_loop::Effort::Medium => "medium",
        crate::agent_loop::Effort::High | crate::agent_loop::Effort::Max => "high",
    }
}

fn merge_usage(into: &mut TokenUsage, usage: &UsageData) {
    into.input_tokens = usage.prompt_tokens.unwrap_or(into.input_tokens);
    into.output_tokens = usage.completion_tokens.unwrap_or(into.output_tokens);
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

fn map_finish_reason(reason: &str) -> StopReason {
    match reason {
        "stop" => StopReason::EndTurn,
        "tool_calls" => StopReason::ToolUse,
        "length" => StopReason::MaxTokens,
        "content_filter" => StopReason::StopSequence,
        _ => StopReason::EndTurn,
    }
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

    // -- Message formatting tests --

    #[test]
    fn formats_system_prompt_as_first_message() {
        let messages = vec![Message::user_text("hello")];
        let api_msgs = build_openai_messages(&messages, Some("You are helpful."));

        assert_eq!(api_msgs.len(), 2);
        assert_eq!(api_msgs[0]["role"], "system");
        assert_eq!(api_msgs[0]["content"], "You are helpful.");
        assert_eq!(api_msgs[1]["role"], "user");
        assert_eq!(api_msgs[1]["content"], "hello");
    }

    #[test]
    fn formats_no_system_prompt_when_none() {
        let messages = vec![Message::user_text("hi")];
        let api_msgs = build_openai_messages(&messages, None);

        assert_eq!(api_msgs.len(), 1);
        assert_eq!(api_msgs[0]["role"], "user");
    }

    #[test]
    fn formats_assistant_tool_calls() {
        let messages = vec![Message::Assistant {
            content: vec![
                ContentBlock::Text {
                    text: "Let me search.".to_string(),
                },
                ContentBlock::ToolUse {
                    id: "call_abc".to_string(),
                    name: "vault_search".to_string(),
                    input: json!({"query": "rust"}),
                },
            ],
        }];
        let api_msgs = build_openai_messages(&messages, None);

        assert_eq!(api_msgs.len(), 1);
        let msg = &api_msgs[0];
        assert_eq!(msg["role"], "assistant");
        assert_eq!(msg["content"], "Let me search.");
        assert_eq!(msg["tool_calls"][0]["id"], "call_abc");
        assert_eq!(msg["tool_calls"][0]["type"], "function");
        assert_eq!(msg["tool_calls"][0]["function"]["name"], "vault_search");
    }

    #[test]
    fn formats_tool_result_as_tool_role() {
        let messages = vec![Message::User {
            content: vec![UserContent::ToolResult(ToolResult {
                tool_use_id: "call_abc".to_string(),
                content: vec![ToolResultContent::Text {
                    text: "found 3 results".to_string(),
                }],
                is_error: false,
            })],
        }];
        let api_msgs = build_openai_messages(&messages, None);

        assert_eq!(api_msgs.len(), 1);
        assert_eq!(api_msgs[0]["role"], "tool");
        assert_eq!(api_msgs[0]["tool_call_id"], "call_abc");
        assert_eq!(api_msgs[0]["content"], "found 3 results");
    }

    #[test]
    fn formats_image_as_image_url() {
        let messages = vec![Message::User {
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
        }];
        let api_msgs = build_openai_messages(&messages, None);

        assert_eq!(api_msgs.len(), 1);
        let msg = &api_msgs[0];
        assert_eq!(msg["role"], "user");
        let content = msg["content"].as_array().expect("content should be array");
        assert_eq!(content.len(), 2);
        assert_eq!(content[0]["type"], "text");
        assert_eq!(content[1]["type"], "image_url");
        assert!(content[1]["image_url"]["url"]
            .as_str()
            .unwrap()
            .starts_with("data:image/png;base64,"));
    }

    #[test]
    fn formats_tool_schema_correctly() {
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
        let tool_json = tool_schema_to_openai_json(&schema);

        assert_eq!(tool_json["type"], "function");
        assert_eq!(tool_json["function"]["name"], "read_file");
        assert_eq!(tool_json["function"]["description"], "Read a file");
        assert!(tool_json["function"]["parameters"]["properties"]["path"].is_object());
    }

    // -- SSE chunk parsing tests --

    #[test]
    fn parses_text_delta_chunk() {
        let raw = r#"{"choices":[{"delta":{"content":"Hello"},"finish_reason":null}]}"#;
        let chunk: RawChunk = serde_json::from_str(raw).expect("parse chunk");

        assert_eq!(chunk.choices.len(), 1);
        assert_eq!(
            chunk.choices[0].delta.as_ref().unwrap().content.as_deref(),
            Some("Hello")
        );
        assert!(chunk.choices[0].finish_reason.is_none());
    }

    #[test]
    fn parses_tool_call_start_chunk() {
        let raw = r#"{
            "choices": [{
                "delta": {
                    "tool_calls": [{
                        "index": 0,
                        "id": "call_xyz",
                        "function": { "name": "vault_search", "arguments": "" }
                    }]
                },
                "finish_reason": null
            }]
        }"#;
        let chunk: RawChunk = serde_json::from_str(raw).expect("parse chunk");

        let tc = &chunk.choices[0].delta.as_ref().unwrap().tool_calls[0];
        assert_eq!(tc.index, 0);
        assert_eq!(tc.id.as_deref(), Some("call_xyz"));
        assert_eq!(
            tc.function.as_ref().unwrap().name.as_deref(),
            Some("vault_search")
        );
    }

    #[test]
    fn parses_tool_call_argument_delta() {
        let raw = r#"{
            "choices": [{
                "delta": {
                    "tool_calls": [{
                        "index": 0,
                        "function": { "arguments": "{\"query\":" }
                    }]
                },
                "finish_reason": null
            }]
        }"#;
        let chunk: RawChunk = serde_json::from_str(raw).expect("parse chunk");

        let tc = &chunk.choices[0].delta.as_ref().unwrap().tool_calls[0];
        assert_eq!(
            tc.function.as_ref().unwrap().arguments.as_deref(),
            Some("{\"query\":")
        );
    }

    #[test]
    fn parses_finish_reason_tool_calls() {
        let raw = r#"{"choices":[{"delta":{},"finish_reason":"tool_calls"}]}"#;
        let chunk: RawChunk = serde_json::from_str(raw).expect("parse chunk");

        assert_eq!(
            chunk.choices[0].finish_reason.as_deref(),
            Some("tool_calls")
        );
    }

    #[test]
    fn parses_usage_data() {
        let raw = r#"{"choices":[],"usage":{"prompt_tokens":42,"completion_tokens":18}}"#;
        let chunk: RawChunk = serde_json::from_str(raw).expect("parse chunk");

        let usage = chunk.usage.expect("usage present");
        assert_eq!(usage.prompt_tokens, Some(42));
        assert_eq!(usage.completion_tokens, Some(18));
    }

    // -- Tool call assembly tests --

    #[test]
    fn assembles_tool_call_from_streaming_deltas() {
        // Simulate the sequence of deltas that OpenAI sends for a tool call
        let mut tool_calls: HashMap<usize, ToolCallInProgress> = HashMap::new();

        // First delta: tool call start with id and name
        let start_raw = r#"{
            "choices": [{
                "delta": {
                    "tool_calls": [{
                        "index": 0,
                        "id": "call_001",
                        "function": { "name": "read_file", "arguments": "" }
                    }]
                },
                "finish_reason": null
            }]
        }"#;
        let start_chunk: RawChunk = serde_json::from_str(start_raw).unwrap();
        for choice in &start_chunk.choices {
            if let Some(delta) = &choice.delta {
                for tc_delta in &delta.tool_calls {
                    if let Some(id) = &tc_delta.id {
                        let name = tc_delta
                            .function
                            .as_ref()
                            .and_then(|f| f.name.clone())
                            .unwrap_or_default();
                        tool_calls.insert(
                            tc_delta.index,
                            ToolCallInProgress {
                                id: id.clone(),
                                name,
                                arguments: String::new(),
                            },
                        );
                    }
                }
            }
        }

        // Second delta: argument fragment
        let arg1_raw = r#"{
            "choices": [{
                "delta": {
                    "tool_calls": [{
                        "index": 0,
                        "function": { "arguments": "{\"path\":" }
                    }]
                },
                "finish_reason": null
            }]
        }"#;
        let arg1_chunk: RawChunk = serde_json::from_str(arg1_raw).unwrap();
        for choice in &arg1_chunk.choices {
            if let Some(delta) = &choice.delta {
                for tc_delta in &delta.tool_calls {
                    if let Some(func) = &tc_delta.function {
                        if let Some(args) = &func.arguments {
                            if let Some(tc) = tool_calls.get_mut(&tc_delta.index) {
                                tc.arguments.push_str(args);
                            }
                        }
                    }
                }
            }
        }

        // Third delta: remaining argument fragment
        let arg2_raw = r#"{
            "choices": [{
                "delta": {
                    "tool_calls": [{
                        "index": 0,
                        "function": { "arguments": "\"/tmp/test.rs\"}" }
                    }]
                },
                "finish_reason": null
            }]
        }"#;
        let arg2_chunk: RawChunk = serde_json::from_str(arg2_raw).unwrap();
        for choice in &arg2_chunk.choices {
            if let Some(delta) = &choice.delta {
                for tc_delta in &delta.tool_calls {
                    if let Some(func) = &tc_delta.function {
                        if let Some(args) = &func.arguments {
                            if let Some(tc) = tool_calls.get_mut(&tc_delta.index) {
                                tc.arguments.push_str(args);
                            }
                        }
                    }
                }
            }
        }

        // Verify assembled tool call
        let tc = tool_calls.remove(&0).expect("tool call at index 0");
        assert_eq!(tc.id, "call_001");
        assert_eq!(tc.name, "read_file");

        let parsed_input: Value = serde_json::from_str(&tc.arguments).expect("valid JSON");
        assert_eq!(parsed_input["path"], "/tmp/test.rs");
    }

    // -- Stop reason mapping tests --

    #[test]
    fn maps_stop_reasons_correctly() {
        assert_eq!(map_finish_reason("stop"), StopReason::EndTurn);
        assert_eq!(map_finish_reason("tool_calls"), StopReason::ToolUse);
        assert_eq!(map_finish_reason("length"), StopReason::MaxTokens);
        assert_eq!(
            map_finish_reason("content_filter"),
            StopReason::StopSequence
        );
        assert_eq!(map_finish_reason("unknown_reason"), StopReason::EndTurn);
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

    // -- Usage merge test --

    #[test]
    fn merges_usage_correctly() {
        let mut token_usage = TokenUsage::default();
        let usage = UsageData {
            prompt_tokens: Some(100),
            completion_tokens: Some(50),
        };
        merge_usage(&mut token_usage, &usage);

        assert_eq!(token_usage.input_tokens, 100);
        assert_eq!(token_usage.output_tokens, 50);
    }

    #[test]
    fn mixed_user_content_with_tool_results_and_text() {
        let messages = vec![Message::User {
            content: vec![
                UserContent::ToolResult(ToolResult {
                    tool_use_id: "call_1".to_string(),
                    content: vec![ToolResultContent::Text {
                        text: "result data".to_string(),
                    }],
                    is_error: false,
                }),
                UserContent::Text {
                    text: "Now do something else".to_string(),
                },
            ],
        }];
        let api_msgs = build_openai_messages(&messages, None);

        // Should produce a "tool" message and then a "user" message
        assert_eq!(api_msgs.len(), 2);
        assert_eq!(api_msgs[0]["role"], "tool");
        assert_eq!(api_msgs[0]["tool_call_id"], "call_1");
        assert_eq!(api_msgs[1]["role"], "user");
        assert_eq!(api_msgs[1]["content"], "Now do something else");
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
    fn builds_codex_input_with_function_call_round_trip() {
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

        let input = build_codex_input(&messages);

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
    fn codex_tool_schema_is_flat_function_shape() {
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

        let tool_json = tool_schema_to_codex_json(&schema);
        assert_eq!(tool_json["type"], "function");
        assert_eq!(tool_json["name"], "read_file");
        assert_eq!(tool_json["description"], "Read a file");
        assert_eq!(tool_json["strict"], true);
        assert!(tool_json["parameters"]["properties"]["path"].is_object());
    }

    #[test]
    fn codex_request_body_enables_auto_parallel_tool_calls_when_tools_exist() {
        let config = AgentConfig {
            system_prompt: Some("You are Hermes.".to_string()),
            ..Default::default()
        };
        let body = build_codex_responses_body(
            "gpt-5.4".to_string(),
            &config,
            vec![json!({
                "type": "message",
                "role": "user",
                "content": [{ "type": "input_text", "text": "Ping" }],
            })],
            vec![tool_schema_to_codex_json(&ToolSchema {
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
}
