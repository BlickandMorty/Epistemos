use std::time::Duration;

use async_stream::stream;
use async_trait::async_trait;
use futures::StreamExt;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use crate::agent_loop::{AgentConfig, AgentError};
use crate::error::{with_retry, RetryConfig};
use crate::provider::{AgentProvider, MessageStream, ProviderCapabilities, StreamEvent};
use crate::types::{
    ContentBlock, Message, StopReason, TokenUsage, ToolResultContent, ToolSchema, UserContent,
};

const GEMINI_API_BASE: &str = "https://generativelanguage.googleapis.com/v1beta/models";
const GOOGLE_OAUTH_AUTH_MODE_ENV: &str = "GOOGLE_AUTH_MODE";
const GOOGLE_OAUTH_ACCESS_TOKEN_ENV: &str = "GOOGLE_ACCESS_TOKEN";
const GOOGLE_OAUTH_PROJECT_ID_ENV: &str = "GOOGLE_PROJECT_ID";
const GOOGLE_OAUTH_AUTH_MODE: &str = "oauth";

#[derive(Debug, Clone, PartialEq, Eq)]
enum GeminiAuth {
    ApiKey(String),
    OAuth {
        access_token: String,
        project_id: String,
    },
}

pub struct GeminiProvider {
    client: Client,
    auth: GeminiAuth,
    model: &'static str,
    retry_config: RetryConfig,
}

impl GeminiProvider {
    fn new(auth: GeminiAuth, model: &'static str) -> Self {
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
            resolve_gemini_auth(
                std::env::var("GOOGLE_API_KEY").unwrap_or_default(),
                std::env::var(GOOGLE_OAUTH_ACCESS_TOKEN_ENV).unwrap_or_default(),
                std::env::var(GOOGLE_OAUTH_AUTH_MODE_ENV).unwrap_or_default(),
                std::env::var(GOOGLE_OAUTH_PROJECT_ID_ENV).unwrap_or_default(),
            ),
            model,
        )
    }

    pub fn flash() -> Self {
        Self::from_env("gemini-2.5-flash")
    }

    pub fn pro() -> Self {
        Self::from_env("gemini-2.5-pro")
    }

    pub fn computer_use() -> Self {
        Self::from_env("gemini-2.5-flash-preview-native-audio-dialog")
    }
}

// MARK: - Gemini SSE Response Types

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
struct GeminiStreamChunk {
    candidates: Option<Vec<GeminiCandidate>>,
    usage_metadata: Option<GeminiUsageMetadata>,
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
struct GeminiCandidate {
    content: Option<GeminiContent>,
    finish_reason: Option<String>,
}

#[derive(Deserialize, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct GeminiContent {
    parts: Option<Vec<GeminiPart>>,
    role: Option<String>,
}

#[derive(Deserialize, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct GeminiPart {
    text: Option<String>,
    function_call: Option<GeminiFunctionCall>,
    function_response: Option<GeminiFunctionResponse>,
    thought: Option<bool>,
}

#[derive(Deserialize, Debug, Serialize)]
struct GeminiFunctionCall {
    name: String,
    args: Value,
}

#[derive(Deserialize, Debug, Serialize)]
struct GeminiFunctionResponse {
    name: String,
    response: Value,
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
struct GeminiUsageMetadata {
    prompt_token_count: Option<u32>,
    candidates_token_count: Option<u32>,
}

// MARK: - AgentProvider Implementation

#[async_trait]
impl AgentProvider for GeminiProvider {
    async fn stream_message(
        &self,
        messages: &[Message],
        tools: &[ToolSchema],
        config: &AgentConfig,
    ) -> Result<MessageStream, AgentError> {
        match &self.auth {
            GeminiAuth::ApiKey(api_key) if api_key.trim().is_empty() => {
                return Err(AgentError::Provider(
                    "GOOGLE_API_KEY is not configured".to_string(),
                ));
            }
            GeminiAuth::OAuth {
                access_token,
                project_id,
            } if access_token.trim().is_empty() || project_id.trim().is_empty() => {
                return Err(AgentError::Provider(
                    "GOOGLE_ACCESS_TOKEN or GOOGLE_PROJECT_ID is not configured".to_string(),
                ));
            }
            _ => {}
        }

        // Build Gemini contents array from message history
        let contents: Vec<Value> = messages.iter().map(message_to_gemini).collect();

        // Build function declarations for tool use
        let function_declarations: Vec<Value> = tools
            .iter()
            .map(|tool| {
                json!({
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": tool.parameters,
                })
            })
            .collect();

        let mut body = json!({
            "contents": contents,
            "generationConfig": {
                "maxOutputTokens": config.max_output_tokens.unwrap_or(8192),
                "temperature": 0.7,
            },
        });

        // Add tools if any
        if !function_declarations.is_empty() {
            body["tools"] = json!([{
                "functionDeclarations": function_declarations,
            }]);
        }

        // Add system instruction if provided
        if let Some(system) = &config.system_prompt {
            body["systemInstruction"] = json!({
                "parts": [{ "text": system }],
            });
        }

        // Add thinking config if supported
        if config.enable_thinking {
            body["generationConfig"]["thinkingConfig"] = json!({
                "thinkingBudget": match config.effort {
                    crate::agent_loop::Effort::Low => 1024,
                    crate::agent_loop::Effort::Medium => 4096,
                    crate::agent_loop::Effort::High => 16384,
                    crate::agent_loop::Effort::Max => 32768,
                },
            });
        }

        // Add grounding (web search) if enabled
        if config.enable_web_search {
            if let Some(tools_array) = body["tools"].as_array_mut() {
                tools_array.push(json!({
                    "googleSearch": {},
                }));
            } else {
                body["tools"] = json!([{ "googleSearch": {} }]);
            }
        }

        let retry_config = self.retry_config.clone();
        let client = self.client.clone();
        let auth = self.auth.clone();
        let model = self.model;

        let response = with_retry(
            &retry_config,
            &tokio_util::sync::CancellationToken::new(),
            || {
                let client = client.clone();
                let auth = auth.clone();
                let body = body.clone();
                async move {
                    let response = streaming_request(&client, &auth, model)
                        .header("content-type", "application/json")
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

        // Parse SSE stream
        let byte_stream = response.bytes_stream();
        let mut sse_buffer = String::new();

        let parsed_stream = stream! {
            let mut tool_call_index: usize = 0;
            let text_index: usize = 0;
            let mut final_usage = TokenUsage::default();
            let mut final_stop_reason = StopReason::EndTurn;

            futures::pin_mut!(byte_stream);

            while let Some(chunk_result) = byte_stream.next().await {
                let chunk = match chunk_result {
                    Ok(bytes) => bytes,
                    Err(e) => {
                        yield Err(AgentError::StreamError(e.to_string()));
                        return;
                    }
                };

                let text = String::from_utf8_lossy(&chunk);
                sse_buffer.push_str(&text);

                // Parse SSE lines: "data: {json}\n\n"
                while let Some(data_start) = sse_buffer.find("data: ") {
                    let json_start = data_start + 6;
                    let Some(line_end) = sse_buffer[json_start..].find('\n') else { break };
                    let json_str = &sse_buffer[json_start..json_start + line_end];

                    let parsed = serde_json::from_str::<GeminiStreamChunk>(json_str);
                    sse_buffer = sse_buffer[json_start + line_end..].to_string();

                    let chunk = match parsed {
                        Ok(c) => c,
                        Err(_) => continue,
                    };

                    // Extract usage
                    if let Some(usage) = &chunk.usage_metadata {
                        final_usage.input_tokens = usage.prompt_token_count.unwrap_or(0);
                        final_usage.output_tokens = usage.candidates_token_count.unwrap_or(0);
                    }

                    // Process candidates
                    if let Some(candidates) = &chunk.candidates {
                        for candidate in candidates {
                            // Check finish reason
                            if let Some(reason) = &candidate.finish_reason {
                                final_stop_reason = match reason.as_str() {
                                    "STOP" => StopReason::EndTurn,
                                    "MAX_TOKENS" => StopReason::MaxTokens,
                                    _ => StopReason::EndTurn,
                                };
                            }

                            // Process parts
                            if let Some(content) = &candidate.content {
                                if let Some(parts) = &content.parts {
                                    for part in parts {
                                        // Thinking text
                                        if part.thought == Some(true) {
                                            if let Some(text) = &part.text {
                                                yield Ok(StreamEvent::ThinkingDelta {
                                                    index: 0,
                                                    text: text.clone(),
                                                });
                                            }
                                            continue;
                                        }

                                        // Regular text
                                        if let Some(text) = &part.text {
                                            yield Ok(StreamEvent::TextDelta {
                                                index: text_index,
                                                text: text.clone(),
                                            });
                                        }

                                        // Function call
                                        if let Some(fc) = &part.function_call {
                                            let block = ContentBlock::ToolUse {
                                                id: format!("gemini-tool-{}", tool_call_index),
                                                name: fc.name.clone(),
                                                input: fc.args.clone(),
                                            };
                                            yield Ok(StreamEvent::ContentBlockComplete { block });
                                            tool_call_index += 1;
                                        }
                                    }
                                }
                            }
                        }
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
        Ok(crate::compaction::compact_messages(messages, 8, 8_192))
    }

    fn capabilities(&self) -> ProviderCapabilities {
        ProviderCapabilities {
            max_context_tokens: if self.model.contains("pro") {
                1_000_000
            } else {
                1_000_000
            },
            max_output_tokens: if self.model.contains("pro") {
                65_536
            } else {
                8_192
            },
            supports_thinking: true,
            supports_vision: true,
            supports_web_search: true,
            supports_code_execution: false,
            supports_computer_use: false,
            supports_mcp: false,
            supports_streaming: true,
            supports_compaction: true,
            cost_input_per_million: if self.model.contains("pro") {
                1.25
            } else {
                0.15
            },
            cost_output_per_million: if self.model.contains("pro") {
                10.0
            } else {
                0.60
            },
        }
    }

    fn name(&self) -> &'static str {
        self.model
    }
}

fn resolve_gemini_auth(
    api_key: String,
    access_token: String,
    auth_mode: String,
    project_id: String,
) -> GeminiAuth {
    if auth_mode
        .trim()
        .eq_ignore_ascii_case(GOOGLE_OAUTH_AUTH_MODE)
        && !access_token.trim().is_empty()
        && !project_id.trim().is_empty()
    {
        GeminiAuth::OAuth {
            access_token,
            project_id,
        }
    } else {
        GeminiAuth::ApiKey(api_key)
    }
}

fn streaming_request(
    client: &Client,
    auth: &GeminiAuth,
    model: &'static str,
) -> reqwest::RequestBuilder {
    match auth {
        GeminiAuth::ApiKey(api_key) => client.post(format!(
            "{}/{}:streamGenerateContent?alt=sse&key={}",
            GEMINI_API_BASE, model, api_key
        )),
        GeminiAuth::OAuth {
            access_token,
            project_id,
        } => client
            .post(format!(
                "{}/{}:streamGenerateContent?alt=sse",
                GEMINI_API_BASE, model
            ))
            .header("authorization", format!("Bearer {access_token}"))
            .header("x-goog-user-project", project_id),
    }
}

// MARK: - Message Conversion

fn message_to_gemini(message: &Message) -> Value {
    match message {
        Message::User { content } => {
            let parts: Vec<Value> = content
                .iter()
                .filter_map(|c| match c {
                    UserContent::Text { text } => Some(json!({ "text": text })),
                    UserContent::ToolResult(result) => Some(json!({
                        "functionResponse": {
                            "name": result.tool_use_id,
                            "response": {
                                "content": result.content.iter().map(|c| match c {
                                    ToolResultContent::Text { text } => text.clone(),
                                    ToolResultContent::Image { .. } => "[image]".to_string(),
                                }).collect::<Vec<_>>().join("\n"),
                            },
                        },
                    })),
                    UserContent::Image { source } => Some(json!({
                        "inlineData": {
                            "mimeType": source.media_type,
                            "data": source.data,
                        },
                    })),
                })
                .collect();

            json!({ "role": "user", "parts": parts })
        }
        Message::Assistant { content } => {
            let parts: Vec<Value> = content
                .iter()
                .filter_map(|block| match block {
                    ContentBlock::Text { text } => Some(json!({ "text": text })),
                    ContentBlock::ToolUse { id: _, name, input } => Some(json!({
                        "functionCall": {
                            "name": name,
                            "args": input,
                        },
                    })),
                    ContentBlock::Thinking { thinking, .. } => {
                        Some(json!({ "text": thinking, "thought": true }))
                    }
                })
                .collect();

            json!({ "role": "model", "parts": parts })
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{resolve_gemini_auth, streaming_request, GeminiAuth};
    use reqwest::Client;

    #[test]
    fn resolves_oauth_auth_when_access_token_and_project_are_present() {
        let auth = resolve_gemini_auth(
            "AIza-legacy-key".to_string(),
            "google-oauth-token".to_string(),
            "oauth".to_string(),
            "epistemos-auth-project".to_string(),
        );

        assert_eq!(
            auth,
            GeminiAuth::OAuth {
                access_token: "google-oauth-token".to_string(),
                project_id: "epistemos-auth-project".to_string(),
            }
        );
    }

    #[test]
    fn resolves_oauth_auth_case_insensitively() {
        let auth = resolve_gemini_auth(
            "AIza-legacy-key".to_string(),
            "google-oauth-token".to_string(),
            "OAuth".to_string(),
            "epistemos-auth-project".to_string(),
        );

        assert_eq!(
            auth,
            GeminiAuth::OAuth {
                access_token: "google-oauth-token".to_string(),
                project_id: "epistemos-auth-project".to_string(),
            }
        );
    }

    #[test]
    fn oauth_requests_use_bearer_headers_instead_of_api_key_query() {
        let client = Client::builder().build().unwrap();
        let request = streaming_request(
            &client,
            &GeminiAuth::OAuth {
                access_token: "google-oauth-token".to_string(),
                project_id: "epistemos-auth-project".to_string(),
            },
            "gemini-2.5-pro",
        )
        .build()
        .unwrap();

        assert_eq!(request.url().query(), Some("alt=sse"));
        assert_eq!(
            request.headers().get("authorization").unwrap(),
            "Bearer google-oauth-token"
        );
        assert_eq!(
            request.headers().get("x-goog-user-project").unwrap(),
            "epistemos-auth-project"
        );
    }

    #[test]
    fn api_key_requests_keep_query_auth() {
        let client = Client::builder().build().unwrap();
        let request = streaming_request(
            &client,
            &GeminiAuth::ApiKey("AIza-legacy-key".to_string()),
            "gemini-2.5-pro",
        )
        .build()
        .unwrap();

        assert_eq!(request.url().query(), Some("alt=sse&key=AIza-legacy-key"));
        assert!(request.headers().get("authorization").is_none());
    }
}
