//! OpenAI-Compatible Provider — Universal provider for any /v1/chat/completions API
//!
//! Most LLM providers implement the OpenAI API standard. This single provider
//! covers: OpenRouter (200+ models), Ollama, Z.AI/GLM, Kimi/Moonshot, DeepSeek,
//! MiniMax, xAI/Grok, Mistral, Together AI, Groq, Fireworks, llama.cpp, LM Studio,
//! HuggingFace, and any other OpenAI-compatible endpoint.
//!
//! Configuration: base_url + api_key + model_id + optional extra headers.

use std::collections::HashMap;
use std::time::Duration;

use async_stream::stream;
use async_trait::async_trait;
use eventsource_stream::Eventsource;
use futures::StreamExt;
use reqwest::Client;
use serde::Deserialize;
use serde_json::{json, Value};

use crate::agent_loop::{AgentConfig, AgentError};
use crate::error::{with_retry, RetryConfig};
use crate::provider::{AgentProvider, MessageStream, ProviderCapabilities, StreamEvent};
use crate::providers::schema::normalized_tool_parameters;
use crate::types::{
    ContentBlock, Message, StopReason, TokenUsage, ToolResultContent, ToolSchema, UserContent,
};

pub struct OpenAICompatibleProvider {
    client: Client,
    api_key: String,
    base_url: String,
    model: String,
    display_name: &'static str,
    extra_headers: HashMap<String, String>,
    capabilities: ProviderCapabilities,
    retry_config: RetryConfig,
}

impl OpenAICompatibleProvider {
    pub fn new(
        api_key: impl Into<String>,
        base_url: impl Into<String>,
        model: impl Into<String>,
        display_name: &'static str,
        capabilities: ProviderCapabilities,
    ) -> Self {
        let client = Client::builder()
            .timeout(Duration::from_secs(300))
            .build()
            .expect("failed to build reqwest client");

        Self {
            client,
            api_key: api_key.into(),
            base_url: base_url.into(),
            model: model.into(),
            display_name,
            extra_headers: HashMap::new(),
            capabilities,
            retry_config: RetryConfig::default(),
        }
    }

    pub fn with_header(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.extra_headers.insert(key.into(), value.into());
        self
    }

    fn endpoint(&self) -> String {
        let base = self.base_url.trim_end_matches('/');
        if base.ends_with("/chat/completions") {
            base.to_string()
        } else if base.ends_with("/v1") {
            format!("{}/chat/completions", base)
        } else {
            format!("{}/v1/chat/completions", base)
        }
    }

    // ========================================================================
    // Factory constructors for specific providers
    // ========================================================================

    // --- OpenRouter (200+ models) ---
    pub fn openrouter(model: &str) -> Self {
        Self::new(
            std::env::var("OPENROUTER_API_KEY").unwrap_or_default(),
            "https://openrouter.ai/api/v1",
            model,
            "OpenRouter",
            ProviderCapabilities {
                max_context_tokens: 200_000,
                max_output_tokens: 32_000,
                supports_thinking: false,
                supports_vision: true,
                supports_web_search: false,
                supports_code_execution: false,
                supports_computer_use: false,
                supports_mcp: false,
                supports_streaming: true,
                supports_compaction: true,
                cost_input_per_million: 3.0,
                cost_output_per_million: 15.0,
            },
        )
        .with_header("HTTP-Referer", "https://epistemos.app")
        .with_header("X-Title", "Epistemos")
    }

    // --- Ollama (local, no API key) ---
    pub fn ollama(model: &str) -> Self {
        Self::new(
            "",
            "http://localhost:11434/v1",
            model,
            "Ollama",
            ProviderCapabilities {
                max_context_tokens: 128_000,
                max_output_tokens: 8_192,
                supports_thinking: false,
                supports_vision: false,
                supports_web_search: false,
                supports_code_execution: false,
                supports_computer_use: false,
                supports_mcp: false,
                supports_streaming: true,
                supports_compaction: true,
                cost_input_per_million: 0.0,
                cost_output_per_million: 0.0,
            },
        )
    }

    // --- llama.cpp (local, no API key) ---
    pub fn llama_cpp(model: &str) -> Self {
        Self::new(
            "",
            "http://localhost:8080/v1",
            model,
            "llama.cpp",
            ProviderCapabilities {
                max_context_tokens: 128_000,
                max_output_tokens: 4_096,
                supports_thinking: false,
                supports_vision: false,
                supports_web_search: false,
                supports_code_execution: false,
                supports_computer_use: false,
                supports_mcp: false,
                supports_streaming: true,
                supports_compaction: true,
                cost_input_per_million: 0.0,
                cost_output_per_million: 0.0,
            },
        )
    }

    // --- Z.AI / GLM ---
    pub fn zai() -> Self {
        Self::new(
            std::env::var("GLM_API_KEY").unwrap_or_default(),
            "https://open.bigmodel.cn/api/paas/v4",
            "glm-4-plus",
            "Z.AI / GLM",
            ProviderCapabilities {
                max_context_tokens: 128_000,
                max_output_tokens: 4_096,
                supports_thinking: false,
                supports_vision: true,
                supports_web_search: true,
                supports_code_execution: true,
                supports_computer_use: false,
                supports_mcp: false,
                supports_streaming: true,
                supports_compaction: true,
                cost_input_per_million: 1.0,
                cost_output_per_million: 1.0,
            },
        )
    }

    // --- Kimi / Moonshot (coding-focused) ---
    pub fn kimi_coding() -> Self {
        Self::new(
            std::env::var("KIMI_API_KEY").unwrap_or_default(),
            "https://api.moonshot.cn/v1",
            "kimi-k2",
            "Kimi Code",
            ProviderCapabilities {
                max_context_tokens: 128_000,
                max_output_tokens: 8_192,
                supports_thinking: true,
                supports_vision: false,
                supports_web_search: false,
                supports_code_execution: false,
                supports_computer_use: false,
                supports_mcp: false,
                supports_streaming: true,
                supports_compaction: true,
                cost_input_per_million: 0.7,
                cost_output_per_million: 0.7,
            },
        )
    }

    // --- DeepSeek ---
    pub fn deepseek() -> Self {
        Self::new(
            std::env::var("DEEPSEEK_API_KEY").unwrap_or_default(),
            "https://api.deepseek.com/v1",
            "deepseek-chat",
            "DeepSeek",
            ProviderCapabilities {
                max_context_tokens: 128_000,
                max_output_tokens: 8_192,
                supports_thinking: true,
                supports_vision: false,
                supports_web_search: false,
                supports_code_execution: false,
                supports_computer_use: false,
                supports_mcp: false,
                supports_streaming: true,
                supports_compaction: true,
                cost_input_per_million: 0.14,
                cost_output_per_million: 0.28,
            },
        )
    }

    // --- MiniMax ---
    pub fn minimax() -> Self {
        Self::new(
            std::env::var("MINIMAX_API_KEY").unwrap_or_default(),
            "https://api.minimax.chat/v1",
            "MiniMax-Text-01",
            "MiniMax",
            ProviderCapabilities {
                max_context_tokens: 1_000_000,
                max_output_tokens: 16_384,
                supports_thinking: false,
                supports_vision: false,
                supports_web_search: false,
                supports_code_execution: false,
                supports_computer_use: false,
                supports_mcp: false,
                supports_streaming: true,
                supports_compaction: true,
                cost_input_per_million: 1.0,
                cost_output_per_million: 1.0,
            },
        )
    }

    // --- xAI / Grok ---
    pub fn xai() -> Self {
        Self::new(
            std::env::var("XAI_API_KEY").unwrap_or_default(),
            "https://api.x.ai/v1",
            "grok-3",
            "xAI / Grok",
            ProviderCapabilities {
                max_context_tokens: 131_072,
                max_output_tokens: 16_384,
                supports_thinking: true,
                supports_vision: true,
                supports_web_search: false,
                supports_code_execution: false,
                supports_computer_use: false,
                supports_mcp: false,
                supports_streaming: true,
                supports_compaction: true,
                cost_input_per_million: 3.0,
                cost_output_per_million: 15.0,
            },
        )
    }

    // --- Mistral AI ---
    pub fn mistral() -> Self {
        Self::new(
            std::env::var("MISTRAL_API_KEY").unwrap_or_default(),
            "https://api.mistral.ai/v1",
            "mistral-large-latest",
            "Mistral AI",
            ProviderCapabilities {
                max_context_tokens: 128_000,
                max_output_tokens: 8_192,
                supports_thinking: false,
                supports_vision: true,
                supports_web_search: false,
                supports_code_execution: false,
                supports_computer_use: false,
                supports_mcp: false,
                supports_streaming: true,
                supports_compaction: true,
                cost_input_per_million: 2.0,
                cost_output_per_million: 6.0,
            },
        )
    }

    // --- Groq (fast inference) ---
    pub fn groq() -> Self {
        Self::new(
            std::env::var("GROQ_API_KEY").unwrap_or_default(),
            "https://api.groq.com/openai/v1",
            "llama-3.3-70b-versatile",
            "Groq",
            ProviderCapabilities {
                max_context_tokens: 128_000,
                max_output_tokens: 8_192,
                supports_thinking: false,
                supports_vision: false,
                supports_web_search: false,
                supports_code_execution: false,
                supports_computer_use: false,
                supports_mcp: false,
                supports_streaming: true,
                supports_compaction: true,
                cost_input_per_million: 0.59,
                cost_output_per_million: 0.79,
            },
        )
    }

    // --- HuggingFace Inference API ---
    pub fn huggingface(model: &str) -> Self {
        Self::new(
            std::env::var("HF_TOKEN").unwrap_or_default(),
            "https://router.huggingface.co/v1",
            model,
            "HuggingFace",
            ProviderCapabilities {
                max_context_tokens: 128_000,
                max_output_tokens: 8_192,
                supports_thinking: false,
                supports_vision: false,
                supports_web_search: false,
                supports_code_execution: false,
                supports_computer_use: false,
                supports_mcp: false,
                supports_streaming: true,
                supports_compaction: true,
                cost_input_per_million: 0.0, // Free tier available
                cost_output_per_million: 0.0,
            },
        )
    }
}

// ============================================================================
// AgentProvider trait implementation (reuses OpenAI SSE format)
// ============================================================================

#[derive(Deserialize, Debug)]
struct StreamChunk {
    choices: Option<Vec<StreamChoice>>,
    usage: Option<UsageData>,
}

#[derive(Deserialize, Debug)]
struct StreamChoice {
    delta: Option<DeltaContent>,
    finish_reason: Option<String>,
}

#[derive(Deserialize, Debug)]
struct DeltaContent {
    content: Option<String>,
    tool_calls: Option<Vec<ToolCallDelta>>,
}

#[derive(Deserialize, Debug)]
struct ToolCallDelta {
    index: Option<usize>,
    id: Option<String>,
    function: Option<FunctionDelta>,
}

#[derive(Deserialize, Debug)]
struct FunctionDelta {
    name: Option<String>,
    arguments: Option<String>,
}

#[derive(Deserialize, Debug)]
struct UsageData {
    prompt_tokens: Option<u32>,
    completion_tokens: Option<u32>,
}

#[async_trait]
impl AgentProvider for OpenAICompatibleProvider {
    async fn stream_message(
        &self,
        messages: &[Message],
        tools: &[ToolSchema],
        config: &AgentConfig,
    ) -> Result<MessageStream, AgentError> {
        // Empty API key is OK for local providers (Ollama, llama.cpp)
        if self.api_key.is_empty()
            && !self.base_url.contains("localhost")
            && !self.base_url.contains("127.0.0.1")
        {
            return Err(AgentError::Provider(format!(
                "{} API key is not configured",
                self.display_name
            )));
        }

        let api_messages: Vec<Value> = messages.iter().map(message_to_openai_json).collect();

        let api_tools: Vec<Value> = tools
            .iter()
            .map(|t| {
                json!({
                    "type": "function",
                    "function": {
                        "name": t.name,
                        "description": t.description,
                        "parameters": normalized_tool_parameters(&t.parameters),
                    }
                })
            })
            .collect();

        let mut body = json!({
            "model": self.model,
            "messages": api_messages,
            "stream": true,
            "max_tokens": config.max_output_tokens.unwrap_or(4096),
        });

        if !api_tools.is_empty() {
            body["tools"] = json!(api_tools);
        }

        if let Some(system) = &config.system_prompt {
            // Prepend system message
            if let Some(msgs) = body["messages"].as_array_mut() {
                msgs.insert(0, json!({"role": "system", "content": system}));
            }
        }

        let endpoint = self.endpoint();
        let retry_config = self.retry_config.clone();
        let client = self.client.clone();
        let api_key = self.api_key.clone();
        let extra_headers = self.extra_headers.clone();

        let response = with_retry(
            &retry_config,
            &tokio_util::sync::CancellationToken::new(),
            || {
                let client = client.clone();
                let api_key = api_key.clone();
                let endpoint = endpoint.clone();
                let body = body.clone();
                let extra_headers = extra_headers.clone();

                async move {
                    let mut req = client
                        .post(&endpoint)
                        .header("content-type", "application/json");

                    if !api_key.is_empty() {
                        req = req.header("authorization", format!("Bearer {}", api_key));
                    }

                    for (k, v) in &extra_headers {
                        req = req.header(k.as_str(), v.as_str());
                    }

                    let response = req
                        .json(&body)
                        .send()
                        .await
                        .map_err(|e| AgentError::HttpError(e.to_string()))?;

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
            let mut tool_calls: HashMap<usize, (String, String, String)> = HashMap::new();
            let mut final_usage = TokenUsage::default();
            let mut final_stop_reason = StopReason::EndTurn;
            let text_index: usize = 0;
            futures::pin_mut!(event_stream);

            while let Some(event_result) = event_stream.next().await {
                let event = match event_result {
                    Ok(e) => e,
                    Err(e) => {
                        yield Err(AgentError::StreamError(e.to_string()));
                        return;
                    }
                };

                if event.data == "[DONE]" {
                    break;
                }

                let chunk: StreamChunk = match serde_json::from_str(&event.data) {
                    Ok(c) => c,
                    Err(_) => continue,
                };

                if let Some(usage) = &chunk.usage {
                    final_usage.input_tokens = usage.prompt_tokens.unwrap_or(0);
                    final_usage.output_tokens = usage.completion_tokens.unwrap_or(0);
                }

                if let Some(choices) = &chunk.choices {
                    for choice in choices {
                        if let Some(reason) = &choice.finish_reason {
                            final_stop_reason = match reason.as_str() {
                                "stop" => StopReason::EndTurn,
                                "length" => StopReason::MaxTokens,
                                "tool_calls" => StopReason::ToolUse,
                                _ => StopReason::EndTurn,
                            };
                        }

                        if let Some(delta) = &choice.delta {
                            // Text content
                            if let Some(text) = &delta.content {
                                if !text.is_empty() {
                                    yield Ok(StreamEvent::TextDelta {
                                        index: text_index,
                                        text: text.clone(),
                                    });
                                }
                            }

                            // Tool calls
                            if let Some(tcs) = &delta.tool_calls {
                                for tc in tcs {
                                    let idx = tc.index.unwrap_or(0);

                                    if let Some(func) = &tc.function {
                                        let entry = tool_calls.entry(idx).or_insert_with(|| {
                                            (
                                                tc.id.clone().unwrap_or_default(),
                                                func.name.clone().unwrap_or_default(),
                                                String::new(),
                                            )
                                        });

                                        if let Some(args) = &func.arguments {
                                            entry.2.push_str(args);
                                            yield Ok(StreamEvent::InputJsonDelta {
                                                index: idx,
                                                partial_json: args.clone(),
                                            });
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Emit completed tool calls
            for (_idx, (id, name, args_json)) in &tool_calls {
                let input = serde_json::from_str(args_json).unwrap_or(Value::Null);
                yield Ok(StreamEvent::ContentBlockComplete {
                    block: ContentBlock::ToolUse {
                        id: id.clone(),
                        name: name.clone(),
                        input,
                    },
                });
            }

            yield Ok(StreamEvent::MessageStop {
                stop_reason: final_stop_reason,
                usage: final_usage,
            });
        };

        Ok(Box::pin(parsed_stream))
    }

    async fn compact(&self, messages: &[Message]) -> Result<Vec<Message>, AgentError> {
        Ok(crate::compaction::compact_messages(messages, 8, 8_192))
    }

    fn capabilities(&self) -> ProviderCapabilities {
        self.capabilities.clone()
    }

    fn name(&self) -> &'static str {
        self.display_name
    }
}

// ============================================================================
// Message conversion (same format as OpenAI)
// ============================================================================

fn message_to_openai_json(message: &Message) -> Value {
    match message {
        Message::User { content } => {
            let parts: Vec<Value> = content
                .iter()
                .map(|c| match c {
                    UserContent::Text { text } => json!({"type": "text", "text": text}),
                    UserContent::ToolResult(result) => json!({
                        "type": "text",
                        "text": result.content.iter().map(|c| match c {
                            ToolResultContent::Text { text } => text.clone(),
                            ToolResultContent::Image { .. } => "[image]".to_string(),
                        }).collect::<Vec<_>>().join("\n"),
                    }),
                    UserContent::Image { source } => json!({
                        "type": "image_url",
                        "image_url": {
                            "url": format!("data:{};base64,{}", source.media_type, source.data),
                        },
                    }),
                })
                .collect();

            // If single text part, flatten to simple content string
            if parts.len() == 1 {
                if let Some(text) = parts[0]["text"].as_str() {
                    return json!({"role": "user", "content": text});
                }
            }

            json!({"role": "user", "content": parts})
        }
        Message::Assistant { content } => {
            let mut text_parts = Vec::new();
            let mut tool_calls = Vec::new();

            for block in content {
                match block {
                    ContentBlock::Text { text } => text_parts.push(text.clone()),
                    ContentBlock::ToolUse { id, name, input } => {
                        tool_calls.push(json!({
                            "id": id,
                            "type": "function",
                            "function": {
                                "name": name,
                                "arguments": serde_json::to_string(input).unwrap_or_default(),
                            },
                        }));
                    }
                    ContentBlock::Thinking { .. } => {}
                }
            }

            let mut msg = json!({"role": "assistant"});
            if !text_parts.is_empty() {
                msg["content"] = json!(text_parts.join("\n"));
            }
            if !tool_calls.is_empty() {
                msg["tool_calls"] = json!(tool_calls);
            }
            msg
        }
    }
}

#[cfg(test)]
mod tests {
    use crate::providers::schema::normalized_tool_parameters;
    use serde_json::json;

    #[test]
    fn openai_compatible_tools_use_closed_object_schemas() {
        let normalized = normalized_tool_parameters(&json!({
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
        }));

        assert_eq!(normalized["additionalProperties"], false);
        assert_eq!(
            normalized["properties"]["options"]["additionalProperties"],
            false
        );
    }
}
