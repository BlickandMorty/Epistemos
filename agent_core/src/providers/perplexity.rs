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
use crate::types::{ContentBlock, Message, StopReason, TokenUsage, ToolResultContent, ToolSchema, UserContent};

const PERPLEXITY_API: &str = "https://api.perplexity.ai/v1/sonar";

pub struct PerplexityProvider {
    client: Client,
    api_key: String,
    model: &'static str,
    retry_config: RetryConfig,
}

impl PerplexityProvider {
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

    pub fn sonar_pro() -> Self {
        Self::new(
            std::env::var("PERPLEXITY_API_KEY").unwrap_or_default(),
            "sonar-pro",
        )
    }
}

#[derive(Serialize)]
struct SonarRequest<'a> {
    model: &'a str,
    messages: Vec<Value>,
    stream: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    max_tokens: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    search_context_size: Option<&'static str>,
}

#[derive(Deserialize, Debug, Default)]
struct RawChunk {
    #[serde(default)]
    choices: Vec<RawChoice>,
    #[serde(default)]
    citations: Vec<String>,
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
}

#[derive(Deserialize, Debug, Default)]
struct UsageData {
    prompt_tokens: Option<u32>,
    completion_tokens: Option<u32>,
    total_tokens: Option<u32>,
}

#[async_trait]
impl AgentProvider for PerplexityProvider {
    async fn stream_message(
        &self,
        messages: &[Message],
        _tools: &[ToolSchema],
        config: &AgentConfig,
    ) -> Result<MessageStream, AgentError> {
        if self.api_key.trim().is_empty() {
            return Err(AgentError::Provider(
                "PERPLEXITY_API_KEY is not configured".to_string(),
            ));
        }

        let body = SonarRequest {
            model: self.model,
            messages: messages.iter().map(message_to_perplexity_json).collect(),
            stream: true,
            max_tokens: config.max_output_tokens,
            search_context_size: Some(search_context_size(config.effort)),
        };

        let retry_config = self.retry_config.clone();
        let client = self.client.clone();
        let api_key = self.api_key.clone();

        let response = with_retry(&retry_config, &tokio_util::sync::CancellationToken::new(), || {
            let client = client.clone();
            let api_key = api_key.clone();
            let body = serde_json::to_value(&body)
                .map_err(|error| AgentError::Serialization(error.to_string()));

            async move {
                let body = body?;
                let response = client
                    .post(PERPLEXITY_API)
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
        })
        .await?;

        let event_stream = response.bytes_stream().eventsource();

        let parsed_stream = stream! {
            let mut final_stop_reason = StopReason::EndTurn;
            let mut final_usage = TokenUsage::default();
            let mut text_buffer = String::new();
            let mut citations: Vec<String> = Vec::new();
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

                let chunk = match serde_json::from_str::<RawChunk>(&event.data) {
                    Ok(chunk) => chunk,
                    Err(_) => continue,
                };

                if !chunk.citations.is_empty() {
                    citations.extend(chunk.citations);
                }

                if let Some(usage) = chunk.usage {
                    merge_usage(&mut final_usage, &usage);
                }

                for choice in chunk.choices {
                    if let Some(delta) = choice.delta.and_then(|delta| delta.content) {
                        text_buffer.push_str(&delta);
                        yield Ok(StreamEvent::TextDelta {
                            index: 0,
                            text: delta,
                        });
                    }

                    if let Some(finish_reason) = choice.finish_reason.as_deref() {
                        final_stop_reason = map_finish_reason(Some(finish_reason));
                    }
                }
            }

            if !text_buffer.is_empty() {
                yield Ok(StreamEvent::ContentBlockComplete {
                    block: ContentBlock::Text { text: text_buffer },
                });
            }

            if let Some(citation_block) = format_citation_block(&citations) {
                yield Ok(StreamEvent::TextDelta {
                    index: 1,
                    text: citation_block.clone(),
                });
                yield Ok(StreamEvent::ContentBlockComplete {
                    block: ContentBlock::Text { text: citation_block },
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
        if messages.len() <= 10 {
            return Ok(messages.to_vec());
        }

        let recent_window = 6_usize.min(messages.len());
        let older = &messages[..messages.len() - recent_window];
        let newer = &messages[messages.len() - recent_window..];

        let mut summary = String::from("[Compacted conversation summary]\n");
        for message in older {
            let line = flatten_message(message);
            if !line.is_empty() {
                if summary.len() + line.len() > 6_000 {
                    break;
                }
                summary.push_str("- ");
                summary.push_str(&line);
                summary.push('\n');
            }
        }

        let mut compacted = Vec::with_capacity(newer.len() + 1);
        compacted.push(Message::user_text(summary));
        compacted.extend_from_slice(newer);
        Ok(compacted)
    }

    fn capabilities(&self) -> ProviderCapabilities {
        ProviderCapabilities {
            max_context_tokens: 128_000,
            max_output_tokens: 8_192,
            supports_thinking: false,
            supports_vision: false,
            supports_web_search: true,
            supports_code_execution: false,
            supports_computer_use: false,
            supports_mcp: false,
            supports_streaming: true,
            supports_compaction: true,
            cost_input_per_million: 3.0,
            cost_output_per_million: 15.0,
        }
    }

    fn name(&self) -> &'static str {
        self.model
    }
}

fn search_context_size(effort: Effort) -> &'static str {
    match effort {
        Effort::Low => "low",
        Effort::Medium => "medium",
        Effort::High | Effort::Max => "high",
    }
}

fn message_to_perplexity_json(message: &Message) -> Value {
    match message {
        Message::User { content } => json!({
            "role": "user",
            "content": flatten_user_content(content),
        }),
        Message::Assistant { content } => json!({
            "role": "assistant",
            "content": flatten_assistant_content(content),
        }),
    }
}

fn flatten_user_content(content: &[UserContent]) -> String {
    content
        .iter()
        .map(|item| match item {
            UserContent::Text { text } => text.clone(),
            UserContent::ToolResult(result) => {
                let body = result
                    .content
                    .iter()
                    .filter_map(|entry| match entry {
                        ToolResultContent::Text { text } => Some(text.as_str()),
                        ToolResultContent::Image { .. } => None,
                    })
                    .collect::<Vec<_>>()
                    .join("\n");
                format!(
                    "[tool_result id={} error={}]\n{}",
                    result.tool_use_id, result.is_error, body
                )
            }
            UserContent::Image { .. } => "[image omitted for Perplexity route]".to_string(),
        })
        .filter(|segment| !segment.trim().is_empty())
        .collect::<Vec<_>>()
        .join("\n\n")
}

fn flatten_assistant_content(content: &[ContentBlock]) -> String {
    content
        .iter()
        .map(|block| match block {
            ContentBlock::Text { text } => text.clone(),
            ContentBlock::Thinking { thinking, .. } => format!("[thinking]\n{thinking}"),
            ContentBlock::ToolUse { id, name, input } => format!(
                "[tool_use id={id} name={name}]\n{}",
                serde_json::to_string_pretty(input).unwrap_or_else(|_| "{}".to_string())
            ),
        })
        .filter(|segment| !segment.trim().is_empty())
        .collect::<Vec<_>>()
        .join("\n\n")
}

fn flatten_message(message: &Message) -> String {
    match message {
        Message::User { content } => flatten_user_content(content),
        Message::Assistant { content } => flatten_assistant_content(content),
    }
}

fn merge_usage(usage: &mut TokenUsage, chunk: &UsageData) {
    usage.input_tokens = chunk.prompt_tokens.unwrap_or(usage.input_tokens);
    usage.output_tokens = chunk.completion_tokens.unwrap_or(usage.output_tokens);
    if usage.input_tokens == 0 && usage.output_tokens == 0 {
        if let Some(total) = chunk.total_tokens {
            usage.input_tokens = total;
        }
    }
}

fn map_finish_reason(reason: Option<&str>) -> StopReason {
    match reason {
        Some("length") => StopReason::MaxTokens,
        Some("tool_calls") => StopReason::ToolUse,
        Some("stop") | Some("end_turn") | None => StopReason::EndTurn,
        Some("stop_sequence") => StopReason::StopSequence,
        Some(_) => StopReason::EndTurn,
    }
}

fn format_citation_block(citations: &[String]) -> Option<String> {
    let mut unique = Vec::new();
    for citation in citations {
        let trimmed = citation.trim();
        if trimmed.is_empty() || unique.iter().any(|existing: &String| existing == trimmed) {
            continue;
        }
        unique.push(trimmed.to_string());
    }

    if unique.is_empty() {
        return None;
    }

    let mut rendered = String::from("\n\nSources:\n");
    for citation in unique {
        rendered.push_str("- ");
        rendered.push_str(&citation);
        rendered.push('\n');
    }
    Some(rendered)
}

#[cfg(test)]
mod tests {
    use super::{format_citation_block, map_finish_reason};
    use crate::types::StopReason;

    #[test]
    fn maps_length_finish_reason_to_max_tokens() {
        assert_eq!(map_finish_reason(Some("length")), StopReason::MaxTokens);
    }

    #[test]
    fn maps_stop_finish_reason_to_end_turn() {
        assert_eq!(map_finish_reason(Some("stop")), StopReason::EndTurn);
    }

    #[test]
    fn citation_block_deduplicates_and_formats_urls() {
        let rendered = format_citation_block(&[
            "https://example.com/a".to_string(),
            "https://example.com/a".to_string(),
            "https://example.com/b".to_string(),
        ])
        .expect("citations should render");

        assert!(rendered.contains("Sources:"));
        assert!(rendered.contains("https://example.com/a"));
        assert!(rendered.contains("https://example.com/b"));
        assert_eq!(rendered.matches("https://example.com/a").count(), 1);
    }
}
