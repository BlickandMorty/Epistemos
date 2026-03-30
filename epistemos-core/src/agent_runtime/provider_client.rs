use std::collections::HashMap;

use futures_util::StreamExt;
use reqwest::header::{HeaderMap, HeaderName, HeaderValue};
use reqwest::Client;
use serde_json::Value;
use thiserror::Error;

use super::config::{AgentProviderConfig, RuntimeProviderKind};
use super::provider_api::{
    build_claude_request, build_openai_request, build_perplexity_request, ProviderRequestBlueprint,
};
use super::{ContentBlock, ProviderEvent, ProviderTurn, StopReason, ToolCall};

#[derive(Debug, Error)]
pub enum ProviderClientError {
    #[error("provider `{0}` is not configured")]
    ProviderNotConfigured(String),
    #[error("provider `{0}` is not implemented in Rust yet")]
    ProviderNotImplemented(String),
    #[error("missing API key for provider `{provider}`")]
    MissingApiKey { provider: String },
    #[error("invalid request header `{name}`")]
    InvalidHeader { name: String },
    #[error("http request failed: {0}")]
    Http(#[from] reqwest::Error),
    #[error("provider returned status {status}: {body}")]
    HttpStatus { status: u16, body: String },
    #[error("invalid provider payload: {0}")]
    InvalidPayload(String),
    #[error("tokio runtime initialization failed: {0}")]
    Runtime(String),
}

pub struct ProviderHttpClient {
    client: Client,
}

impl ProviderHttpClient {
    pub fn new() -> Result<Self, ProviderClientError> {
        let client = Client::builder()
            .build()
            .map_err(ProviderClientError::Http)?;
        Ok(Self { client })
    }

    async fn stream_turn(
        &self,
        provider: &AgentProviderConfig,
        api_key_override: Option<&str>,
        objective: &str,
        system_prompt: Option<&str>,
        max_output_tokens: u32,
        thinking_budget_tokens: u32,
        remote_mcp_servers: &[super::config::McpServerConfig],
    ) -> Result<ProviderTurn, ProviderClientError> {
        let blueprint = build_runtime_request(
            provider,
            objective,
            system_prompt,
            max_output_tokens,
            thinking_budget_tokens,
            remote_mcp_servers,
        )?;
        self.stream_blueprint(&blueprint, provider, api_key_override)
            .await
    }

    async fn stream_blueprint(
        &self,
        blueprint: &ProviderRequestBlueprint,
        provider: &AgentProviderConfig,
        api_key_override: Option<&str>,
    ) -> Result<ProviderTurn, ProviderClientError> {
        let headers = resolved_headers(blueprint, provider, api_key_override)?;
        let response = self
            .client
            .request(
                reqwest::Method::from_bytes(blueprint.method.as_bytes())
                    .map_err(|error| ProviderClientError::InvalidPayload(error.to_string()))?,
                &blueprint.url,
            )
            .headers(headers)
            .body(blueprint.body_json.clone())
            .send()
            .await?;

        let status = response.status();
        if !status.is_success() {
            let body = response.text().await.unwrap_or_default();
            return Err(ProviderClientError::HttpStatus {
                status: status.as_u16(),
                body,
            });
        }

        let mut parser = StreamParser::new(blueprint.provider);
        let mut stream = response.bytes_stream();
        while let Some(chunk) = stream.next().await {
            let chunk = chunk?;
            parser.push_bytes(chunk.as_ref())?;
        }
        parser.finish()
    }
}

pub(super) fn run_stream_turn_blocking(
    provider: &AgentProviderConfig,
    api_key_override: Option<&str>,
    objective: &str,
    system_prompt: Option<&str>,
    max_output_tokens: u32,
    thinking_budget_tokens: u32,
    remote_mcp_servers: &[super::config::McpServerConfig],
) -> Result<ProviderTurn, ProviderClientError> {
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .map_err(|error| ProviderClientError::Runtime(error.to_string()))?;

    runtime.block_on(async {
        ProviderHttpClient::new()?
            .stream_turn(
                provider,
                api_key_override,
                objective,
                system_prompt,
                max_output_tokens,
                thinking_budget_tokens,
                remote_mcp_servers,
            )
            .await
    })
}

fn build_runtime_request(
    provider: &AgentProviderConfig,
    objective: &str,
    system_prompt: Option<&str>,
    max_output_tokens: u32,
    thinking_budget_tokens: u32,
    remote_mcp_servers: &[super::config::McpServerConfig],
) -> Result<ProviderRequestBlueprint, ProviderClientError> {
    match provider.kind {
        RuntimeProviderKind::Claude => build_claude_request(
            provider,
            vec![serde_json::json!({
                "role": "user",
                "content": objective,
            })],
            Vec::new(),
            max_output_tokens.max(1024),
            thinking_budget_tokens.max(1024),
            remote_mcp_servers,
        )
        .map_err(ProviderClientError::InvalidPayload),
        RuntimeProviderKind::Perplexity => build_perplexity_request(
            provider,
            serde_json::json!([{ "role": "user", "content": objective }]),
            system_prompt,
            max_output_tokens.max(1024),
            true,
        )
        .map_err(ProviderClientError::InvalidPayload),
        RuntimeProviderKind::OpenAI => build_openai_request(
            provider,
            serde_json::json!([{ "role": "user", "content": objective }]),
            system_prompt,
            Vec::new(),
            max_output_tokens.max(1024),
        )
        .map_err(ProviderClientError::InvalidPayload),
        RuntimeProviderKind::Google => Err(ProviderClientError::ProviderNotImplemented(
            provider.kind.as_str().to_string(),
        )),
        RuntimeProviderKind::Local => Err(ProviderClientError::ProviderNotImplemented(
            provider.kind.as_str().to_string(),
        )),
    }
}

fn resolved_headers(
    blueprint: &ProviderRequestBlueprint,
    provider: &AgentProviderConfig,
    api_key_override: Option<&str>,
) -> Result<HeaderMap, ProviderClientError> {
    let mut headers = HeaderMap::new();
    let api_key = api_key_override.map(str::to_string).or_else(|| {
        if provider.api_key_env.is_empty() {
            None
        } else {
            std::env::var(&provider.api_key_env).ok()
        }
    });

    for header in &blueprint.headers {
        let mut value = header.value.clone();
        if header.value.contains("${") {
            value = resolve_placeholder_header_value(&header.value, api_key.as_deref(), provider)?;
        }
        let name = HeaderName::from_bytes(header.name.as_bytes()).map_err(|_| {
            ProviderClientError::InvalidHeader {
                name: header.name.clone(),
            }
        })?;
        let value =
            HeaderValue::from_str(&value).map_err(|_| ProviderClientError::InvalidHeader {
                name: header.name.clone(),
            })?;
        headers.insert(name, value);
    }

    Ok(headers)
}

fn resolve_placeholder_header_value(
    raw: &str,
    api_key_override: Option<&str>,
    provider: &AgentProviderConfig,
) -> Result<String, ProviderClientError> {
    let mut resolved = raw.to_string();
    for placeholder in extract_placeholders(raw) {
        let replacement = if !provider.api_key_env.is_empty() && placeholder == provider.api_key_env
        {
            api_key_override.map(str::to_string).ok_or_else(|| {
                ProviderClientError::MissingApiKey {
                    provider: provider.kind.as_str().to_string(),
                }
            })?
        } else {
            std::env::var(&placeholder).map_err(|_| ProviderClientError::MissingApiKey {
                provider: provider.kind.as_str().to_string(),
            })?
        };
        resolved = resolved.replace(&format!("${{{placeholder}}}"), &replacement);
    }
    Ok(resolved)
}

fn extract_placeholders(raw: &str) -> Vec<String> {
    let mut placeholders = Vec::new();
    let mut remainder = raw;
    while let Some(start) = remainder.find("${") {
        let after_start = &remainder[start + 2..];
        if let Some(end) = after_start.find('}') {
            placeholders.push(after_start[..end].to_string());
            remainder = &after_start[end + 1..];
        } else {
            break;
        }
    }
    placeholders
}

struct StreamParser {
    provider: RuntimeProviderKind,
    line_buffer: Vec<u8>,
    event_name: Option<String>,
    data_lines: Vec<String>,
    events: Vec<ProviderEvent>,
    content_blocks: Vec<ContentBlock>,
    stop_reason: StopReason,
    anthropic_tools: HashMap<u64, ToolCall>,
}

impl StreamParser {
    fn new(provider: RuntimeProviderKind) -> Self {
        Self {
            provider,
            line_buffer: Vec::new(),
            event_name: None,
            data_lines: Vec::new(),
            events: Vec::new(),
            content_blocks: Vec::new(),
            stop_reason: StopReason::EndTurn,
            anthropic_tools: HashMap::new(),
        }
    }

    fn push_bytes(&mut self, chunk: &[u8]) -> Result<(), ProviderClientError> {
        self.line_buffer.extend_from_slice(chunk);

        while let Some(newline_index) = self.line_buffer.iter().position(|byte| *byte == b'\n') {
            let mut line = self.line_buffer.drain(..=newline_index).collect::<Vec<_>>();
            if matches!(line.last(), Some(b'\n')) {
                line.pop();
            }
            if matches!(line.last(), Some(b'\r')) {
                line.pop();
            }
            let line = String::from_utf8(line)
                .map_err(|error| ProviderClientError::InvalidPayload(error.to_string()))?;
            self.process_line(&line)?;
        }

        Ok(())
    }

    fn finish(mut self) -> Result<ProviderTurn, ProviderClientError> {
        if !self.line_buffer.is_empty() {
            let line = String::from_utf8(std::mem::take(&mut self.line_buffer))
                .map_err(|error| ProviderClientError::InvalidPayload(error.to_string()))?;
            self.process_line(&line)?;
        }
        self.flush_event()?;
        Ok(ProviderTurn {
            events: self.events,
            content_blocks: self.content_blocks,
            stop_reason: self.stop_reason,
        })
    }

    fn process_line(&mut self, line: &str) -> Result<(), ProviderClientError> {
        if line.is_empty() {
            return self.flush_event();
        }
        if let Some(value) = line.strip_prefix("event:") {
            self.event_name = Some(sse_field_value(value));
            return Ok(());
        }
        if let Some(value) = line.strip_prefix("data:") {
            self.data_lines.push(sse_field_value(value));
        }
        Ok(())
    }

    fn flush_event(&mut self) -> Result<(), ProviderClientError> {
        if self.data_lines.is_empty() {
            self.event_name = None;
            return Ok(());
        }

        let payload = self.data_lines.join("\n");
        self.event_name = None;
        self.data_lines.clear();

        if payload == "[DONE]" {
            return Ok(());
        }

        let json: Value = serde_json::from_str(&payload)
            .map_err(|error| ProviderClientError::InvalidPayload(error.to_string()))?;
        match self.provider {
            RuntimeProviderKind::Claude => self.handle_claude_event(json),
            RuntimeProviderKind::Perplexity => self.handle_openai_compatible_event(json),
            RuntimeProviderKind::OpenAI => self.handle_openai_compatible_event(json),
            RuntimeProviderKind::Google => self.handle_google_event(json),
            RuntimeProviderKind::Local => Err(ProviderClientError::ProviderNotImplemented(
                RuntimeProviderKind::Local.as_str().to_string(),
            )),
        }
    }

    fn handle_claude_event(&mut self, json: Value) -> Result<(), ProviderClientError> {
        let event_type = json.get("type").and_then(Value::as_str).unwrap_or_default();
        match event_type {
            "content_block_delta" => {
                let index = json
                    .get("index")
                    .and_then(Value::as_u64)
                    .unwrap_or_default();
                if let Some(delta) = json.get("delta").and_then(Value::as_object) {
                    match delta
                        .get("type")
                        .and_then(Value::as_str)
                        .unwrap_or_default()
                    {
                        "thinking_delta" => {
                            if let Some(text) = delta.get("thinking").and_then(Value::as_str) {
                                if !text.is_empty() {
                                    self.events
                                        .push(ProviderEvent::ThinkingDelta(text.to_string()));
                                    self.content_blocks.push(ContentBlock::thinking(text));
                                }
                            }
                        }
                        "text_delta" => {
                            if let Some(text) = delta.get("text").and_then(Value::as_str) {
                                if !text.is_empty() {
                                    self.events.push(ProviderEvent::TextDelta(text.to_string()));
                                    self.content_blocks.push(ContentBlock::text(text));
                                }
                            }
                        }
                        "input_json_delta" => {
                            if let Some(partial) = delta.get("partial_json").and_then(Value::as_str)
                            {
                                let tool_call =
                                    self.anthropic_tools.entry(index).or_insert(ToolCall {
                                        id: String::new(),
                                        name: String::new(),
                                        input_json: String::new(),
                                    });
                                tool_call.input_json.push_str(partial);
                            }
                        }
                        _ => {}
                    }
                }
            }
            "content_block_start" => {
                let index = json
                    .get("index")
                    .and_then(Value::as_u64)
                    .unwrap_or_default();
                if let Some(block) = json.get("content_block").and_then(Value::as_object) {
                    if block.get("type").and_then(Value::as_str) == Some("tool_use") {
                        let mut tool_call = ToolCall {
                            id: block
                                .get("id")
                                .and_then(Value::as_str)
                                .unwrap_or_default()
                                .to_string(),
                            name: block
                                .get("name")
                                .and_then(Value::as_str)
                                .unwrap_or_default()
                                .to_string(),
                            input_json: String::new(),
                        };
                        if let Some(input) = block.get("input") {
                            tool_call.input_json =
                                serde_json::to_string(input).map_err(|error| {
                                    ProviderClientError::InvalidPayload(error.to_string())
                                })?;
                        }
                        self.anthropic_tools.insert(index, tool_call);
                    }
                }
            }
            "content_block_stop" => {
                let index = json
                    .get("index")
                    .and_then(Value::as_u64)
                    .unwrap_or_default();
                if let Some(tool_call) = self.anthropic_tools.remove(&index) {
                    self.events
                        .push(ProviderEvent::ToolStart(tool_call.clone()));
                    self.content_blocks.push(ContentBlock::tool_use(&tool_call));
                    self.stop_reason = StopReason::ToolUse;
                }
            }
            "message_delta" => {
                if let Some(stop_reason) = json
                    .get("delta")
                    .and_then(Value::as_object)
                    .and_then(|delta| delta.get("stop_reason"))
                    .and_then(Value::as_str)
                {
                    self.stop_reason = if stop_reason == "tool_use" {
                        StopReason::ToolUse
                    } else {
                        StopReason::EndTurn
                    };
                }
            }
            "error" => {
                return Err(ProviderClientError::InvalidPayload(
                    json.get("error")
                        .map(Value::to_string)
                        .unwrap_or_else(|| json.to_string()),
                ));
            }
            _ => {}
        }
        Ok(())
    }

    fn handle_openai_compatible_event(&mut self, json: Value) -> Result<(), ProviderClientError> {
        if let Some(error) = json.get("error") {
            return Err(ProviderClientError::InvalidPayload(error.to_string()));
        }

        if let Some(delta) = json.get("delta").and_then(Value::as_str) {
            if !delta.is_empty() {
                self.events
                    .push(ProviderEvent::TextDelta(delta.to_string()));
                self.content_blocks.push(ContentBlock::text(delta));
                return Ok(());
            }
        }

        if let Some(delta) = json
            .get("choices")
            .and_then(Value::as_array)
            .and_then(|choices| choices.first())
            .and_then(|choice| choice.get("delta"))
            .and_then(Value::as_object)
            .and_then(|delta| delta.get("content"))
        {
            match delta {
                Value::String(text) => {
                    if !text.is_empty() {
                        self.events.push(ProviderEvent::TextDelta(text.clone()));
                        self.content_blocks.push(ContentBlock::text(text));
                    }
                }
                Value::Array(parts) => {
                    for part in parts {
                        if let Some(text) = part.get("text").and_then(Value::as_str) {
                            if !text.is_empty() {
                                self.events.push(ProviderEvent::TextDelta(text.to_string()));
                                self.content_blocks.push(ContentBlock::text(text));
                            }
                        }
                    }
                }
                _ => {}
            }
        }

        Ok(())
    }

    fn handle_google_event(&mut self, json: Value) -> Result<(), ProviderClientError> {
        if let Some(error) = json.get("error") {
            return Err(ProviderClientError::InvalidPayload(error.to_string()));
        }

        if let Some(candidates) = json.get("candidates").and_then(Value::as_array) {
            for candidate in candidates {
                if let Some(parts) = candidate
                    .get("content")
                    .and_then(Value::as_object)
                    .and_then(|content| content.get("parts"))
                    .and_then(Value::as_array)
                {
                    for part in parts {
                        if let Some(text) = part.get("text").and_then(Value::as_str) {
                            if !text.is_empty() {
                                self.events.push(ProviderEvent::TextDelta(text.to_string()));
                                self.content_blocks.push(ContentBlock::text(text));
                            }
                        }
                    }
                }
            }
        }
        Ok(())
    }
}

fn sse_field_value(raw: &str) -> String {
    raw.trim_start_matches(' ').to_string()
}

#[cfg(test)]
mod tests {
    use std::io::{Read, Write};
    use std::net::TcpListener;
    use std::thread;

    use super::*;
    use crate::agent_runtime::config::AgentRuntimeConfig;

    #[test]
    fn parses_claude_thinking_text_and_tool_events() {
        let mut parser = StreamParser::new(RuntimeProviderKind::Claude);
        let payload = concat!(
            "event: content_block_delta\n",
            "data: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"thinking_delta\",\"thinking\":\"Plan first\"}}\n\n",
            "event: content_block_start\n",
            "data: {\"type\":\"content_block_start\",\"index\":1,\"content_block\":{\"type\":\"tool_use\",\"id\":\"tool-1\",\"name\":\"vault_search\",\"input\":{\"query\":\"agent\"}}}\n\n",
            "event: content_block_stop\n",
            "data: {\"type\":\"content_block_stop\",\"index\":1}\n\n",
            "event: content_block_delta\n",
            "data: {\"type\":\"content_block_delta\",\"index\":2,\"delta\":{\"type\":\"text_delta\",\"text\":\"Done.\"}}\n\n",
            "event: message_delta\n",
            "data: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"tool_use\"}}\n\n"
        );
        parser
            .push_bytes(payload.as_bytes())
            .expect("payload should parse");
        let turn = parser.finish().expect("turn should finish");

        assert_eq!(turn.stop_reason, StopReason::ToolUse);
        assert!(turn.events.iter().any(
            |event| matches!(event, ProviderEvent::ThinkingDelta(text) if text == "Plan first")
        ));
        assert!(turn.events.iter().any(
            |event| matches!(event, ProviderEvent::ToolStart(call) if call.name == "vault_search")
        ));
        assert!(turn
            .events
            .iter()
            .any(|event| matches!(event, ProviderEvent::TextDelta(text) if text == "Done.")));
    }

    #[test]
    fn runs_openai_stream_against_mock_server() {
        let response = concat!(
            "event: response.output_text.delta\n",
            "data: {\"type\":\"response.output_text.delta\",\"delta\":\"Hello\"}\n\n",
            "event: response.output_text.delta\n",
            "data: {\"type\":\"response.output_text.delta\",\"delta\":\" world\"}\n\n",
            "data: [DONE]\n\n"
        )
        .to_string();
        let (url, _request) = spawn_mock_server(response);

        let mut config = AgentRuntimeConfig::production_defaults("/tmp/agents".to_string());
        let provider = config
            .providers
            .iter_mut()
            .find(|provider| provider.kind == RuntimeProviderKind::OpenAI)
            .expect("openai provider should exist");
        provider.base_url = url;
        provider.api_key_env = "EP_TEST_OPENAI_KEY".to_string();
        let provider = provider.clone();

        let turn = run_stream_turn_blocking(
            &provider,
            Some("test-key"),
            "Say hello",
            None,
            256,
            256,
            &config.mcp_servers,
        )
        .expect("openai turn should succeed");

        assert_eq!(turn.stop_reason, StopReason::EndTurn);
        let text = turn
            .content_blocks
            .iter()
            .filter(|block| block.kind == "text")
            .map(|block| block.text.as_str())
            .collect::<Vec<_>>()
            .join("");
        assert_eq!(text, "Hello world");
    }

    #[test]
    fn runs_claude_stream_against_mock_server() {
        let response = concat!(
            "event: content_block_delta\n",
            "data: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"thinking_delta\",\"thinking\":\"Need to reason\"}}\n\n",
            "event: content_block_delta\n",
            "data: {\"type\":\"content_block_delta\",\"index\":1,\"delta\":{\"type\":\"text_delta\",\"text\":\"Ready\"}}\n\n",
            "event: message_delta\n",
            "data: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\"}}\n\n"
        )
        .to_string();
        let (url, captured_request) = spawn_mock_server(response);

        let mut config = AgentRuntimeConfig::production_defaults("/tmp/agents".to_string());
        let provider = config
            .providers
            .iter_mut()
            .find(|provider| provider.kind == RuntimeProviderKind::Claude)
            .expect("claude provider should exist");
        provider.base_url = url;
        provider.api_key_env = "EP_TEST_ANTHROPIC_KEY".to_string();
        let provider = provider.clone();

        let turn = run_stream_turn_blocking(
            &provider,
            Some("anthropic-test-key"),
            "Reason about the note",
            Some("You are helpful."),
            256,
            256,
            &config.mcp_servers,
        )
        .expect("claude turn should succeed");

        assert!(captured_request
            .lock()
            .expect("request capture should be available")
            .contains("x-api-key: anthropic-test-key"));
        assert!(turn.events.iter().any(
            |event| matches!(event, ProviderEvent::ThinkingDelta(text) if text == "Need to reason")
        ));
        assert!(turn
            .events
            .iter()
            .any(|event| matches!(event, ProviderEvent::TextDelta(text) if text == "Ready")));
    }

    #[test]
    fn surfaces_http_status_errors() {
        let (url, _request) =
            spawn_mock_server_with_status(401, "{\"error\":\"bad key\"}".to_string());

        let provider = AgentProviderConfig {
            kind: RuntimeProviderKind::OpenAI,
            label: "Test".to_string(),
            model: "gpt-5.4".to_string(),
            base_url: url,
            api_key_env: "EP_TEST_OPENAI_KEY".to_string(),
            enabled: true,
            preset: String::new(),
            capabilities: crate::agent_runtime::config::ProviderCapabilities {
                streaming: true,
                tool_loop: true,
                remote_mcp: false,
                hosted_tools: true,
                native_computer_use: false,
            },
        };

        let error = run_stream_turn_blocking(&provider, Some("bad"), "Hello", None, 128, 128, &[])
            .expect_err("request should fail");

        assert!(matches!(
            error,
            ProviderClientError::HttpStatus { status: 401, .. }
        ));
    }

    fn spawn_mock_server(
        response_body: String,
    ) -> (String, std::sync::Arc<std::sync::Mutex<String>>) {
        spawn_mock_server_with_headers(200, "text/event-stream", response_body)
    }

    fn spawn_mock_server_with_status(
        status: u16,
        response_body: String,
    ) -> (String, std::sync::Arc<std::sync::Mutex<String>>) {
        spawn_mock_server_with_headers(status, "application/json", response_body)
    }

    fn spawn_mock_server_with_headers(
        status: u16,
        content_type: &str,
        response_body: String,
    ) -> (String, std::sync::Arc<std::sync::Mutex<String>>) {
        let listener = TcpListener::bind("127.0.0.1:0").expect("listener should bind");
        let address = listener
            .local_addr()
            .expect("listener should have local address");
        let captured = std::sync::Arc::new(std::sync::Mutex::new(String::new()));
        let captured_clone = captured.clone();
        let content_type = content_type.to_string();

        thread::spawn(move || {
            let (mut stream, _) = listener
                .accept()
                .expect("mock server should accept one request");
            let mut buffer = [0_u8; 8192];
            let read = stream
                .read(&mut buffer)
                .expect("request should be readable");
            let request = String::from_utf8_lossy(&buffer[..read]).to_string();
            *captured_clone.lock().expect("capture lock should work") = request;

            let status_text = match status {
                200 => "OK",
                401 => "Unauthorized",
                429 => "Too Many Requests",
                _ => "OK",
            };
            let response = format!(
                "HTTP/1.1 {status} {status_text}\r\ncontent-type: {content_type}\r\ncontent-length: {}\r\nconnection: close\r\n\r\n{}",
                response_body.len(),
                response_body
            );
            stream
                .write_all(response.as_bytes())
                .expect("response should write");
        });

        (format!("http://{}", address), captured)
    }
}
