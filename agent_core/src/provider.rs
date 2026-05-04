use std::pin::Pin;

use async_trait::async_trait;
use futures::Stream;

use crate::agent_loop::{AgentConfig, AgentError};
use crate::types::{ContentBlock, Message, StopReason, TokenUsage, ToolSchema};

#[derive(Debug, Clone)]
pub enum StreamEvent {
    ThinkingDelta {
        index: usize,
        text: String,
    },
    RedactedThinking {
        index: usize,
        data: String,
    },
    TextDelta {
        index: usize,
        text: String,
    },
    InputJsonDelta {
        index: usize,
        partial_json: String,
    },
    ContentBlockComplete {
        block: ContentBlock,
    },
    SignatureDelta {
        index: usize,
        signature: String,
    },
    MessageStop {
        stop_reason: StopReason,
        usage: TokenUsage,
    },
}

pub type MessageStream = Pin<Box<dyn Stream<Item = Result<StreamEvent, AgentError>> + Send>>;

/// Where a provider actually runs. Cloud providers (Anthropic, OpenAI,
/// Gemini, Perplexity) are the only ones eligible for the agent tier per
/// CLAUDE.md's honest-capability-gating rule: "Local models get
/// fast/thinking/research. Cloud models get agent/liveAgent." The agent
/// loop refuses to start for Local providers so we never silently
/// downgrade a user's agentic task into plain chat.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProviderRuntime {
    Cloud,
    Local,
}

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

    /// Where this provider physically runs. Defaults to Cloud so existing
    /// provider impls (Claude / Gemini / OpenAI / Perplexity) need no
    /// change. Any on-device provider (MLX, llama.cpp, etc.) MUST override
    /// this to return Local so the agent loop refuses to start for it.
    fn runtime(&self) -> ProviderRuntime {
        ProviderRuntime::Cloud
    }
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
