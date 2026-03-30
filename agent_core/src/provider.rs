use std::pin::Pin;

use async_trait::async_trait;
use futures::Stream;

use crate::agent_loop::{AgentConfig, AgentError};
use crate::types::{ContentBlock, Message, StopReason, TokenUsage, ToolSchema};

#[derive(Debug, Clone)]
pub enum StreamEvent {
    ThinkingDelta { index: usize, text: String },
    TextDelta { index: usize, text: String },
    InputJsonDelta { index: usize, partial_json: String },
    ContentBlockComplete { block: ContentBlock },
    SignatureDelta { index: usize, signature: String },
    MessageStop { stop_reason: StopReason, usage: TokenUsage },
}

pub type MessageStream = Pin<Box<dyn Stream<Item = Result<StreamEvent, AgentError>> + Send>>;

#[async_trait]
pub trait AgentProvider: Send + Sync {
    async fn stream_message(
        &self,
        messages: &[Message],
        tools: &[ToolSchema],
        config: &AgentConfig,
    ) -> Result<MessageStream, AgentError>;

    async fn compact(&self, messages: &[Message]) -> Result<Vec<Message>, AgentError>;

    fn capabilities(&self) -> ProviderCapabilities;

    fn name(&self) -> &'static str;
}

#[derive(Debug, Clone)]
pub struct ProviderCapabilities {
    pub max_context_tokens: usize,
    pub max_output_tokens: usize,
    pub supports_thinking: bool,
    pub supports_vision: bool,
    pub supports_web_search: bool,
    pub supports_code_execution: bool,
    pub supports_computer_use: bool,
    pub supports_mcp: bool,
    pub supports_streaming: bool,
    pub supports_compaction: bool,
    pub cost_input_per_million: f64,
    pub cost_output_per_million: f64,
}
