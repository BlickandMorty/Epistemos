//! Provider-stream normalization (S2; DOCTRINE I-3 /
//! IMPLEMENTATION §3-S2).
//!
//! Per DOCTRINE I-3 every cloud + local provider stream is
//! converted into a single `AgentEvent` enum at this boundary.
//! Provider-specific peculiarities (Anthropic SSE event taxonomy,
//! OpenAI delta accumulation, Hermes JSON-RPC framing, MLX-Swift
//! token deltas) live behind these submodules; the simulation
//! reducer never imports any provider type directly.
//!
//! S2 implements the canonical happy path for each provider — message
//! lifecycle (start / delta / completed), thinking blocks (preserved
//! per CLAUDE.md "PRESERVE THINKING BLOCKS"), and tool calls. Edge
//! cases (provider-specific errors, partial-recovery sequences,
//! reasoning summaries) extend the same tables in later slices.

pub mod anthropic;
pub mod hermes;
pub mod kimi;
pub mod local_mlx;
pub mod openai;

use crate::companions::CompanionId;
use crate::events::{AgentEvent, MessageId, ToolCallId};

/// Per-stream context passed alongside each raw event. Lets the
/// normalizer attribute the resulting `AgentEvent`s to the right
/// agent/message without threading providers through call sites.
#[derive(Debug, Clone)]
pub struct NormalizeContext {
    /// Companion (agent) emitting this stream. Set at session
    /// participant-join time and held for the duration of the
    /// stream.
    pub agent_id: CompanionId,
    /// Currently-streaming message id, if any. Most providers emit
    /// one message per stream; we let the normalizer update this
    /// when a `message_start` arrives.
    pub message_id: Option<MessageId>,
    /// Currently-streaming tool-call id, if any.
    pub tool_call_id: Option<ToolCallId>,
}

impl NormalizeContext {
    pub fn new(agent_id: CompanionId) -> Self {
        Self {
            agent_id,
            message_id: None,
            tool_call_id: None,
        }
    }
}

/// Trait every provider normalizer implements. Returns zero or more
/// `AgentEvent`s for each raw provider event. Many provider event
/// types collapse to zero AgentEvents (heartbeats, pings) or fan
/// out to multiple (a single message_start may produce
/// `MessageStarted` + `ThinkingStarted` if thinking is enabled).
pub trait Normalizer {
    type Raw;
    fn normalize(&self, ctx: &mut NormalizeContext, raw: Self::Raw) -> Vec<AgentEvent>;
}
