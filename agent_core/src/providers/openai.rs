use std::collections::HashMap;
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

const OPENAI_API: &str = "https://api.openai.com/v1/chat/completions";

pub struct OpenAIProvider {
    client: Client,
    api_key: String,
    model: &'static str,
    retry_config: RetryConfig,
}

impl OpenAIProvider {
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

    pub fn gpt4o() -> Self {
        Self::new(
            std::env::var("OPENAI_API_KEY").unwrap_or_default(),
            "gpt-4o",
        )
    }

    pub fn gpt4o_mini() -> Self {
        Self::new(
            std::env::var("OPENAI_API_KEY").unwrap_or_default(),
            "gpt-4o-mini",
        )
    }

    pub fn o1() -> Self {
        Self::new(
            std::env::var("OPENAI_API_KEY").unwrap_or_default(),
            "o1",
        )
    }

    pub fn o3_mini() -> Self {
        Self::new(
            std::env::var("OPENAI_API_KEY").unwrap_or_default(),
            "o3-mini",
        )
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
        if self.api_key.trim().is_empty() {
            return Err(AgentError::Provider(
                "OPENAI_API_KEY is not configured".to_string(),
            ));
        }

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
                        .post(OPENAI_API)
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
                        // Text content delta
                        if let Some(text) = delta.content {
                            text_buffer.push_str(&text);
                            yield Ok(StreamEvent::TextDelta {
                                index: 0,
                                text,
                            });
                        }

                        // Tool call deltas
                        for tc_delta in delta.tool_calls {
                            let tc_index = tc_delta.index;

                            // Initialize tool call entry if we see an id (first chunk for this call)
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

                            // Append argument fragments
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

            // Emit completed text block
            if !text_buffer.is_empty() {
                yield Ok(StreamEvent::ContentBlockComplete {
                    block: ContentBlock::Text { text: text_buffer },
                });
            }

            // Emit completed tool use blocks
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

    async fn compact(&self, messages: &[Message]) -> Result<Vec<Message>, AgentError> {
        Ok(crate::compaction::compact_messages(messages, 8, 16_384))
    }

    fn capabilities(&self) -> ProviderCapabilities {
        let (max_ctx, max_out, cost_in, cost_out) = match self.model {
            "gpt-4o" => (128_000, 16_384, 2.50, 10.00),
            "gpt-4o-mini" => (128_000, 16_384, 0.15, 0.60),
            "o1" => (200_000, 100_000, 15.00, 60.00),
            "o3-mini" => (200_000, 100_000, 1.10, 4.40),
            _ => (128_000, 16_384, 2.50, 10.00),
        };

        ProviderCapabilities {
            max_context_tokens: max_ctx,
            max_output_tokens: max_out,
            supports_thinking: false,
            supports_vision: matches!(self.model, "gpt-4o" | "gpt-4o-mini"),
            supports_web_search: false,
            supports_code_execution: false,
            supports_computer_use: false,
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn merge_usage(into: &mut TokenUsage, usage: &UsageData) {
    into.input_tokens = usage.prompt_tokens.unwrap_or(into.input_tokens);
    into.output_tokens = usage.completion_tokens.unwrap_or(into.output_tokens);
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::{ContentBlock, ImageSource, Message, ToolResult, ToolResultContent, UserContent};
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
        assert_eq!(map_finish_reason("content_filter"), StopReason::StopSequence);
        assert_eq!(map_finish_reason("unknown_reason"), StopReason::EndTurn);
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
}
