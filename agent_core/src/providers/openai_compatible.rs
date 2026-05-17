//! OpenAI-Compatible Provider — Universal provider for any /v1/chat/completions API
//! Source: https://platform.openai.com/docs/api-reference/chat/create-chat-completion
//! Source: https://openrouter.ai/docs/api/reference/overview
//! Source: https://openrouter.ai/docs/api/api-reference/chat/send-chat-completion-request
//! Source: https://openrouter.ai/docs/api/reference/streaming
//! Source: https://openrouter.ai/docs/guides/best-practices/reasoning-tokens
//! Source: https://openrouter.ai/docs/guides/routing/provider-selection
//! Source: https://platform.kimi.ai/docs/api/overview
//! Source: https://platform.kimi.ai/docs/models
//! Source: https://platform.kimi.ai/docs/guide/kimi-k2-6-quickstart
//! Source: https://docs.mistral.ai/mistral-vibe/using-fim-api
//! Source: https://docs.mistral.ai/models/model-cards/codestral-25-08
//! Source: https://docs.mistral.ai/api/endpoint/chat
//! Source: https://docs.together.ai/docs/inference/openai-compatibility
//! Source: https://docs.together.ai/docs/inference/chat/overview
//! Source: https://docs.together.ai/docs/inference/function-calling/overview
//! Source: https://docs.together.ai/docs/inference/chat/reasoning
//! Source: https://docs.together.ai/docs/serverless/models
//! Source: https://docs.x.ai/developers/model-capabilities/legacy/chat-completions
//! Source: https://docs.x.ai/developers/model-capabilities/text/streaming
//! Source: https://docs.x.ai/developers/model-capabilities/text/reasoning
//! Source: https://docs.x.ai/developers/tools/function-calling
//! Source: https://docs.x.ai/developers/models/grok-4.3
//! Source: https://docs.x.ai/developers/migration/may-15-retirement
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

use crate::agent_loop::{AgentConfig, AgentError, Effort};
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
    request_extension: Option<RequestExtension>,
    capabilities: ProviderCapabilities,
    retry_config: RetryConfig,
}

#[derive(Clone, Copy)]
enum RequestExtension {
    KimiThinking,
    OpenRouterReasoning,
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
            request_extension: None,
            capabilities,
            retry_config: RetryConfig::default(),
        }
    }

    pub fn with_header(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.extra_headers.insert(key.into(), value.into());
        self
    }

    fn with_request_extension(mut self, extension: RequestExtension) -> Self {
        self.request_extension = Some(extension);
        self
    }

    fn apply_provider_request_extensions(&self, body: &mut Value, config: &AgentConfig) {
        match self.request_extension {
            Some(RequestExtension::KimiThinking) => {
                body["thinking"] = json!({
                    "type": if config.enable_thinking { "enabled" } else { "disabled" }
                });
            }
            Some(RequestExtension::OpenRouterReasoning) => {
                body["reasoning"] = openrouter_reasoning_config(config);
            }
            None => {}
        }
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
    // Source: https://openrouter.ai/docs/api/reference/overview
    // Source: https://openrouter.ai/docs/guides/best-practices/reasoning-tokens
    // Endpoint: https://openrouter.ai/api/v1/chat/completions
    // Auth: OPENROUTER_API_KEY
    pub fn openrouter(model: &str) -> Self {
        Self::new(
            std::env::var("OPENROUTER_API_KEY").unwrap_or_default(),
            "https://openrouter.ai/api/v1",
            model,
            "OpenRouter",
            ProviderCapabilities {
                max_context_tokens: 200_000,
                max_output_tokens: 32_000,
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
        .with_header("HTTP-Referer", "https://epistemos.app")
        .with_header("X-OpenRouter-Title", "Epistemos")
        .with_request_extension(RequestExtension::OpenRouterReasoning)
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

    // --- Kimi / Moonshot ---
    // Source: https://platform.kimi.ai/docs/api/overview
    // Source: https://platform.kimi.ai/docs/models
    // Source: https://platform.kimi.ai/docs/guide/kimi-k2-6-quickstart
    // Auth: MOONSHOT_API_KEY (legacy KIMI_API_KEY fallback)
    pub fn kimi(model: &str) -> Self {
        let provider = Self::new(
            moonshot_api_key(),
            "https://api.moonshot.ai/v1",
            model,
            "Kimi",
            kimi_capabilities(model),
        );

        if kimi_supports_configurable_thinking(model) {
            provider.with_request_extension(RequestExtension::KimiThinking)
        } else {
            provider
        }
    }

    pub fn kimi_latest() -> Self {
        Self::kimi("kimi-k2.6")
    }

    pub fn kimi_k2() -> Self {
        Self::kimi("kimi-k2-0905-preview")
    }

    pub fn kimi_thinking() -> Self {
        Self::kimi("kimi-k2-thinking")
    }

    pub fn kimi_coding() -> Self {
        Self::kimi_latest()
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
    // Source: https://docs.x.ai/developers/model-capabilities/legacy/chat-completions
    // Source: https://docs.x.ai/developers/models/grok-4.3
    // Source: https://docs.x.ai/developers/migration/may-15-retirement
    // Endpoint: https://api.x.ai/v1/chat/completions
    // Auth: XAI_API_KEY
    pub fn xai() -> Self {
        Self::grok_latest()
    }

    pub fn grok(model: &str) -> Self {
        Self::new(
            xai_api_key(),
            "https://api.x.ai/v1",
            model,
            "xAI Grok",
            xai_capabilities(model),
        )
    }

    pub fn grok_latest() -> Self {
        Self::grok("grok-4.3")
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

    // --- Codestral (Mistral's code-specialised model) ---
    // Source: https://docs.mistral.ai/mistral-vibe/using-fim-api
    // Source: https://docs.mistral.ai/models/model-cards/codestral-25-08
    // Source: https://docs.mistral.ai/api/endpoint/chat
    // Endpoint: https://codestral.mistral.ai/v1  (separate from api.mistral.ai)
    // Auth: CODESTRAL_API_KEY (falls back to MISTRAL_API_KEY)
    pub fn codestral(model: &str) -> Self {
        Self::new(
            codestral_api_key(),
            "https://codestral.mistral.ai/v1",
            model,
            "Codestral",
            ProviderCapabilities {
                max_context_tokens: 128_000,
                max_output_tokens: 32_768,
                supports_thinking: false,
                supports_vision: false,
                supports_web_search: false,
                supports_code_execution: false,
                supports_computer_use: false,
                supports_mcp: false,
                supports_streaming: true,
                supports_compaction: true,
                cost_input_per_million: 0.3,
                cost_output_per_million: 0.9,
            },
        )
    }

    pub fn codestral_latest() -> Self {
        Self::codestral("codestral-latest")
    }

    // --- Together AI (open-model fast inference gateway) ---
    // Source: https://docs.together.ai/docs/inference/openai-compatibility
    // Source: https://docs.together.ai/docs/serverless/models
    // Endpoint: https://api.together.ai/v1  (OpenAI-compatible)
    // Auth: TOGETHER_API_KEY
    pub fn together(model: &str) -> Self {
        Self::new(
            std::env::var("TOGETHER_API_KEY").unwrap_or_default(),
            "https://api.together.ai/v1",
            model,
            "Together AI",
            ProviderCapabilities {
                max_context_tokens: together_context_tokens(model),
                max_output_tokens: 8_192,
                supports_thinking: together_supports_thinking(model),
                supports_vision: false,
                supports_web_search: false,
                supports_code_execution: false,
                supports_computer_use: false,
                supports_mcp: false,
                supports_streaming: true,
                supports_compaction: true,
                cost_input_per_million: together_input_cost(model),
                cost_output_per_million: together_output_cost(model),
            },
        )
    }

    pub fn together_latest() -> Self {
        Self::together("meta-llama/Llama-3.3-70B-Instruct-Turbo")
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
    reasoning: Option<String>,
    reasoning_content: Option<String>,
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
                        "name": crate::providers::tool_names::api_safe_tool_name(&t.name),
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

        self.apply_provider_request_extensions(&mut body, config);

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
                            if let Some(thinking) = openai_compatible_reasoning_delta_text(delta) {
                                yield Ok(StreamEvent::ThinkingDelta {
                                    index: text_index,
                                    text: thinking.to_string(),
                                });
                            }

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
                                                func.name
                                                    .as_deref()
                                                    .map(crate::providers::tool_names::canonical_tool_name_from_api)
                                                    .unwrap_or_default(),
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
            for (id, name, args_json) in tool_calls.values() {
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

fn moonshot_api_key() -> String {
    std::env::var("MOONSHOT_API_KEY")
        .or_else(|_| std::env::var("KIMI_API_KEY"))
        .unwrap_or_default()
}

fn codestral_api_key() -> String {
    std::env::var("CODESTRAL_API_KEY")
        .or_else(|_| std::env::var("MISTRAL_API_KEY"))
        .unwrap_or_default()
}

fn xai_api_key() -> String {
    std::env::var("XAI_API_KEY").unwrap_or_default()
}

fn xai_capabilities(model: &str) -> ProviderCapabilities {
    ProviderCapabilities {
        max_context_tokens: xai_context_tokens(model),
        max_output_tokens: 16_384,
        supports_thinking: true,
        supports_vision: true,
        supports_web_search: false,
        supports_code_execution: false,
        supports_computer_use: false,
        supports_mcp: false,
        supports_streaming: true,
        supports_compaction: true,
        cost_input_per_million: 1.25,
        cost_output_per_million: 2.50,
    }
}

fn xai_context_tokens(model: &str) -> usize {
    if model.contains("multi-agent") {
        2_000_000
    } else {
        1_000_000
    }
}

fn kimi_capabilities(model: &str) -> ProviderCapabilities {
    ProviderCapabilities {
        max_context_tokens: 256_000,
        max_output_tokens: 32_768,
        supports_thinking: kimi_supports_thinking(model),
        supports_vision: matches!(model, "kimi-k2.6" | "kimi-k2.5"),
        supports_web_search: false,
        supports_code_execution: false,
        supports_computer_use: false,
        supports_mcp: false,
        supports_streaming: true,
        supports_compaction: true,
        cost_input_per_million: match model {
            "kimi-k2.6" => 0.95,
            "kimi-k2.5" => 0.60,
            _ => 0.60,
        },
        cost_output_per_million: match model {
            "kimi-k2.6" => 4.0,
            "kimi-k2.5" => 3.0,
            _ => 2.50,
        },
    }
}

fn kimi_supports_configurable_thinking(model: &str) -> bool {
    matches!(model, "kimi-k2.6" | "kimi-k2.5")
}

fn kimi_supports_thinking(model: &str) -> bool {
    kimi_supports_configurable_thinking(model) || model.contains("thinking")
}

fn openrouter_reasoning_config(config: &AgentConfig) -> Value {
    if config.enable_thinking {
        json!({
            "effort": openrouter_reasoning_effort(config.effort),
            "exclude": false
        })
    } else {
        json!({
            "effort": "none",
            "exclude": true
        })
    }
}

fn openrouter_reasoning_effort(effort: Effort) -> &'static str {
    match effort {
        Effort::Low => "low",
        Effort::Medium => "medium",
        Effort::High => "high",
        Effort::Max => "xhigh",
    }
}

fn together_context_tokens(model: &str) -> usize {
    match model {
        "meta-llama/Llama-3.3-70B-Instruct-Turbo" => 131_072,
        "openai/gpt-oss-120b" | "openai/gpt-oss-20b" => 128_000,
        "moonshotai/Kimi-K2.6" | "moonshotai/Kimi-K2.5" => 262_144,
        "Qwen/Qwen3.6-Plus" => 1_000_000,
        "Qwen/Qwen3.5-397B-A17B" | "Qwen/Qwen3.5-9B" => 262_144,
        "zai-org/GLM-5" | "zai-org/GLM-5.1" => 202_752,
        "deepseek-ai/DeepSeek-V4-Pro" => 512_000,
        "MiniMaxAI/MiniMax-M2.7" => 202_752,
        _ => 128_000,
    }
}

fn together_supports_thinking(model: &str) -> bool {
    matches!(
        model,
        "openai/gpt-oss-120b"
            | "openai/gpt-oss-20b"
            | "moonshotai/Kimi-K2.6"
            | "moonshotai/Kimi-K2.5"
            | "Qwen/Qwen3.6-Plus"
            | "Qwen/Qwen3.5-397B-A17B"
            | "Qwen/Qwen3.5-9B"
            | "zai-org/GLM-5"
            | "zai-org/GLM-5.1"
            | "deepseek-ai/DeepSeek-V4-Pro"
            | "MiniMaxAI/MiniMax-M2.7"
    )
}

fn together_input_cost(model: &str) -> f64 {
    match model {
        "meta-llama/Llama-3.3-70B-Instruct-Turbo" => 0.88,
        "openai/gpt-oss-120b" => 0.15,
        "openai/gpt-oss-20b" => 0.05,
        "moonshotai/Kimi-K2.6" => 1.20,
        "moonshotai/Kimi-K2.5" => 0.50,
        "Qwen/Qwen3.6-Plus" => 0.50,
        "Qwen/Qwen3.5-397B-A17B" => 0.60,
        "Qwen/Qwen3.5-9B" => 0.10,
        "zai-org/GLM-5" => 1.00,
        "deepseek-ai/DeepSeek-V4-Pro" => 2.10,
        "MiniMaxAI/MiniMax-M2.7" => 0.30,
        _ => 0.90,
    }
}

fn together_output_cost(model: &str) -> f64 {
    match model {
        "meta-llama/Llama-3.3-70B-Instruct-Turbo" => 0.88,
        "openai/gpt-oss-120b" => 0.60,
        "openai/gpt-oss-20b" => 0.20,
        "moonshotai/Kimi-K2.6" => 4.50,
        "moonshotai/Kimi-K2.5" => 2.80,
        "Qwen/Qwen3.6-Plus" => 3.00,
        "Qwen/Qwen3.5-397B-A17B" => 3.60,
        "Qwen/Qwen3.5-9B" => 0.15,
        "zai-org/GLM-5" => 3.20,
        "deepseek-ai/DeepSeek-V4-Pro" => 4.40,
        "MiniMaxAI/MiniMax-M2.7" => 1.20,
        _ => 0.90,
    }
}

fn openai_compatible_reasoning_delta_text(delta: &DeltaContent) -> Option<&str> {
    delta
        .reasoning_content
        .as_deref()
        .or(delta.reasoning.as_deref())
        .filter(|text| !text.is_empty())
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
                                "name": crate::providers::tool_names::api_safe_tool_name(name),
                                "arguments": serde_json::to_string(input).unwrap_or_default(),
                            },
                        }));
                    }
                    ContentBlock::Thinking { .. } | ContentBlock::RedactedThinking { .. } => {}
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
    use super::message_to_openai_json;
    use super::{openai_compatible_reasoning_delta_text, OpenAICompatibleProvider, StreamChunk};
    use crate::agent_loop::{AgentConfig, Effort};
    use crate::providers::schema::normalized_tool_parameters;
    use crate::test_support::env_lock;
    use crate::types::{ContentBlock, Message};
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

    #[test]
    fn assistant_tool_use_serializes_v2_name_as_openai_safe_wire_name() {
        let message = Message::Assistant {
            content: vec![ContentBlock::ToolUse {
                id: "call-1".to_string(),
                name: "file.read".to_string(),
                input: json!({"path": "README.md"}),
            }],
        };
        let json = message_to_openai_json(&message);
        assert_eq!(
            json["tool_calls"][0]["function"]["name"].as_str(),
            Some("file__read")
        );
    }

    #[test]
    fn module_prologue_includes_moonshot_source_comments() {
        let source = include_str!("openai_compatible.rs");
        let prologue = source
            .split("//! Most LLM providers")
            .next()
            .unwrap_or(source);

        assert!(
            prologue.contains("//! Source: https://platform.kimi.ai/docs/api/overview"),
            "Kimi/Moonshot API overview must be in the module-level Source prologue"
        );
        assert!(
            prologue.contains("//! Source: https://platform.kimi.ai/docs/models"),
            "Kimi model list must be in the module-level Source prologue"
        );
        assert!(
            prologue.contains("//! Source: https://platform.kimi.ai/docs/guide/kimi-k2-6-quickstart"),
            "Kimi K2.6 quickstart must be in the module-level Source prologue"
        );
    }

    #[test]
    fn openrouter_gateway_uses_current_api_contract() {
        let provider = OpenAICompatibleProvider::openrouter("openai/gpt-5.2");

        assert_eq!(provider.base_url, "https://openrouter.ai/api/v1");
        assert_eq!(provider.model, "openai/gpt-5.2");
        assert_eq!(provider.display_name, "OpenRouter");
        assert_eq!(provider.capabilities.max_context_tokens, 200_000);
        assert!(provider.capabilities.supports_thinking);
        assert!(provider.capabilities.supports_vision);
        assert_eq!(
            provider.extra_headers.get("X-OpenRouter-Title"),
            Some(&"Epistemos".to_string())
        );
    }

    #[test]
    fn openrouter_reasoning_request_extension_maps_effort() {
        let provider = OpenAICompatibleProvider::openrouter("openai/gpt-5.2");
        let mut body = json!({
            "model": provider.model,
            "messages": [],
            "stream": true
        });
        let config = AgentConfig {
            enable_thinking: true,
            effort: Effort::Max,
            ..AgentConfig::default()
        };

        provider.apply_provider_request_extensions(&mut body, &config);

        assert_eq!(
            body["reasoning"],
            json!({ "effort": "xhigh", "exclude": false })
        );
    }

    #[test]
    fn openrouter_stream_chunk_exposes_reasoning_as_thinking_delta() {
        let chunk: StreamChunk = serde_json::from_value(json!({
            "choices": [{
                "index": 0,
                "delta": { "reasoning": "plan first" },
                "finish_reason": null
            }]
        }))
        .unwrap();
        let choices = chunk.choices.unwrap();
        let delta = choices[0].delta.as_ref().unwrap();

        assert_eq!(
            openai_compatible_reasoning_delta_text(delta),
            Some("plan first")
        );
    }

    #[test]
    fn kimi_latest_uses_current_moonshot_api_contract() {
        let provider = OpenAICompatibleProvider::kimi_latest();

        assert_eq!(provider.base_url, "https://api.moonshot.ai/v1");
        assert_eq!(provider.model, "kimi-k2.6");
        assert_eq!(provider.display_name, "Kimi");
        assert_eq!(provider.capabilities.max_context_tokens, 256_000);
        assert_eq!(provider.capabilities.max_output_tokens, 32_768);
        assert!(provider.capabilities.supports_thinking);
        assert!(provider.capabilities.supports_vision);
    }

    #[test]
    fn kimi_k2_stays_on_explicit_k2_preview_id() {
        let provider = OpenAICompatibleProvider::kimi_k2();

        assert_eq!(provider.base_url, "https://api.moonshot.ai/v1");
        assert_eq!(provider.model, "kimi-k2-0905-preview");
        assert_eq!(provider.capabilities.max_context_tokens, 256_000);
        assert!(!provider.capabilities.supports_vision);
    }

    #[test]
    fn kimi_request_extension_disables_thinking_when_config_disables_it() {
        let provider = OpenAICompatibleProvider::kimi_latest();
        let mut body = json!({
            "model": provider.model,
            "messages": [],
            "stream": true
        });
        let config = AgentConfig {
            enable_thinking: false,
            ..AgentConfig::default()
        };

        provider.apply_provider_request_extensions(&mut body, &config);

        assert_eq!(
            body["thinking"],
            json!({ "type": "disabled" }),
            "Kimi K2.6 enables thinking by default, so the provider must explicitly disable it for fast/no-thinking turns"
        );
    }

    #[test]
    fn kimi_stream_chunk_exposes_reasoning_content_as_thinking_delta() {
        let chunk: StreamChunk = serde_json::from_value(json!({
            "choices": [{
                "index": 0,
                "delta": { "reasoning_content": "plan first" },
                "finish_reason": null
            }]
        }))
        .unwrap();
        let choices = chunk.choices.unwrap();
        let delta = choices[0].delta.as_ref().unwrap();

        assert_eq!(
            openai_compatible_reasoning_delta_text(delta),
            Some("plan first")
        );
    }

    #[test]
    fn grok_latest_uses_current_xai_api_contract() {
        let provider = OpenAICompatibleProvider::grok_latest();

        assert_eq!(provider.base_url, "https://api.x.ai/v1");
        assert_eq!(provider.model, "grok-4.3");
        assert_eq!(provider.display_name, "xAI Grok");
        assert_eq!(provider.capabilities.max_context_tokens, 1_000_000);
        assert!(provider.capabilities.supports_thinking);
        assert!(provider.capabilities.supports_vision);
        assert_eq!(provider.capabilities.cost_input_per_million, 1.25);
        assert_eq!(provider.capabilities.cost_output_per_million, 2.50);
    }

    #[test]
    fn grok_stream_chunk_exposes_reasoning_content_as_thinking_delta() {
        let chunk: StreamChunk = serde_json::from_value(json!({
            "choices": [{
                "index": 0,
                "delta": { "reasoning_content": "reasoning summary" },
                "finish_reason": null
            }]
        }))
        .unwrap();
        let choices = chunk.choices.unwrap();
        let delta = choices[0].delta.as_ref().unwrap();

        assert_eq!(
            openai_compatible_reasoning_delta_text(delta),
            Some("reasoning summary")
        );
    }

    #[test]
    fn codestral_latest_uses_current_mistral_code_contract() {
        let provider = OpenAICompatibleProvider::codestral_latest();

        assert_eq!(provider.base_url, "https://codestral.mistral.ai/v1");
        assert_eq!(provider.model, "codestral-latest");
        assert_eq!(provider.display_name, "Codestral");
        assert_eq!(provider.capabilities.max_context_tokens, 128_000);
        assert_eq!(provider.capabilities.max_output_tokens, 32_768);
        assert!(!provider.capabilities.supports_thinking);
        assert!(!provider.capabilities.supports_vision);
    }

    #[test]
    fn codestral_api_key_prefers_dedicated_codestral_key() {
        let _guard = env_lock();
        let saved_codestral = std::env::var("CODESTRAL_API_KEY").ok();
        let saved_mistral = std::env::var("MISTRAL_API_KEY").ok();
        std::env::set_var("CODESTRAL_API_KEY", "codestral-specific");
        std::env::set_var("MISTRAL_API_KEY", "mistral-general");

        let provider = OpenAICompatibleProvider::codestral_latest();

        assert_eq!(provider.api_key, "codestral-specific");
        match saved_codestral {
            Some(value) => std::env::set_var("CODESTRAL_API_KEY", value),
            None => std::env::remove_var("CODESTRAL_API_KEY"),
        }
        match saved_mistral {
            Some(value) => std::env::set_var("MISTRAL_API_KEY", value),
            None => std::env::remove_var("MISTRAL_API_KEY"),
        }
    }

    #[test]
    fn together_latest_uses_current_api_contract() {
        let provider = OpenAICompatibleProvider::together_latest();

        assert_eq!(provider.base_url, "https://api.together.ai/v1");
        assert_eq!(provider.model, "meta-llama/Llama-3.3-70B-Instruct-Turbo");
        assert_eq!(provider.display_name, "Together AI");
        assert_eq!(provider.capabilities.max_context_tokens, 131_072);
        assert_eq!(provider.capabilities.max_output_tokens, 8_192);
        assert!(provider.capabilities.supports_streaming);
        assert!(!provider.capabilities.supports_thinking);
        assert!(!provider.capabilities.supports_vision);
        assert_eq!(provider.capabilities.cost_input_per_million, 0.88);
        assert_eq!(provider.capabilities.cost_output_per_million, 0.88);
    }

    #[test]
    fn together_stream_chunk_exposes_reasoning_when_model_returns_it() {
        let chunk: StreamChunk = serde_json::from_value(json!({
            "choices": [{
                "index": 0,
                "delta": { "reasoning": "plan first" },
                "finish_reason": null
            }]
        }))
        .unwrap();
        let choices = chunk.choices.unwrap();
        let delta = choices[0].delta.as_ref().unwrap();

        assert_eq!(
            openai_compatible_reasoning_delta_text(delta),
            Some("plan first")
        );
    }
}
