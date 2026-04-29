//! Anthropic Messages SSE → `AgentEvent` normalization (S2).
//!
//! Covers the canonical SSE event taxonomy used by `agent_core`'s
//! existing Anthropic provider in `src/providers/claude.rs`:
//! message_start, content_block_start, content_block_delta,
//! content_block_stop, message_delta, message_stop. Per CLAUDE.md
//! "PRESERVE THINKING BLOCKS" — thinking deltas surface as
//! `ThinkingDelta` events; the simulation reducer never strips
//! them.
//!
//! Provider-specific shapes are decoded only enough to drive
//! `AgentEvent` synthesis. The full provider-side parsing (tool
//! input accumulation, server-sent error frames, ping events) lives
//! in `providers/claude.rs`; later slices wire that pipeline through
//! this normalizer.

use serde::Deserialize;

use super::{NormalizeContext, Normalizer};
use crate::events::{
    AgentEvent, ArtifactKind, ArtifactRef, ArtifactId, Blake3Hash, MessageId, ToolCallId,
};

/// Subset of the Anthropic Messages SSE event taxonomy used by S2.
#[derive(Debug, Clone, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum AnthropicSseEvent {
    MessageStart {
        message: AnthropicMessageHeader,
    },
    ContentBlockStart {
        index: u32,
        content_block: AnthropicBlock,
    },
    ContentBlockDelta {
        index: u32,
        delta: AnthropicDelta,
    },
    ContentBlockStop {
        index: u32,
    },
    MessageDelta {
        delta: AnthropicMessageDelta,
    },
    MessageStop,
    Ping,
    /// Anything we don't recognise is silently ignored at this
    /// layer — provider-side error / unknown frames are surfaced by
    /// the provider crate before reaching the normalizer.
    #[serde(other)]
    Unknown,
}

#[derive(Debug, Clone, Deserialize)]
pub struct AnthropicMessageHeader {
    pub id: String,
    /// Optional, but Anthropic always supplies it. Ignored here
    /// (already attributed via `NormalizeContext::agent_id`).
    #[serde(default)]
    pub model: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum AnthropicBlock {
    Text {
        #[serde(default)]
        text: String,
    },
    Thinking {
        #[serde(default)]
        thinking: String,
    },
    ToolUse {
        id: String,
        name: String,
        #[serde(default)]
        input: serde_json::Value,
    },
    #[serde(other)]
    Unknown,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum AnthropicDelta {
    TextDelta {
        text: String,
    },
    ThinkingDelta {
        thinking: String,
    },
    InputJsonDelta {
        partial_json: String,
    },
    #[serde(other)]
    Unknown,
}

#[derive(Debug, Clone, Deserialize)]
pub struct AnthropicMessageDelta {
    /// `"end_turn"` / `"tool_use"` / etc. — used by the provider
    /// crate to drive its tool-loop. Not yet observable in
    /// `AgentEvent` (the reducer doesn't need it for visualisation).
    #[serde(default)]
    pub stop_reason: Option<String>,
}

pub struct AnthropicNormalizer;

impl Normalizer for AnthropicNormalizer {
    type Raw = AnthropicSseEvent;

    fn normalize(&self, ctx: &mut NormalizeContext, raw: Self::Raw) -> Vec<AgentEvent> {
        match raw {
            AnthropicSseEvent::MessageStart { message } => {
                let mid = MessageId::new(message.id);
                ctx.message_id = Some(mid.clone());
                vec![AgentEvent::MessageStarted {
                    message_id: mid,
                    agent_id: ctx.agent_id,
                }]
            }

            AnthropicSseEvent::ContentBlockStart {
                content_block: AnthropicBlock::Thinking { .. },
                ..
            } => match ctx.message_id.clone() {
                Some(mid) => vec![AgentEvent::ThinkingStarted {
                    agent_id: ctx.agent_id,
                    message_id: mid,
                }],
                None => Vec::new(),
            },

            AnthropicSseEvent::ContentBlockStart {
                content_block: AnthropicBlock::ToolUse { id, name, input },
                ..
            } => {
                let tcid = ToolCallId::new(id);
                ctx.tool_call_id = Some(tcid.clone());
                let bytes = serde_json::to_vec(&input).unwrap_or_default();
                vec![AgentEvent::ToolCallStarted {
                    tool_call_id: tcid,
                    agent_id: ctx.agent_id,
                    tool_name: name,
                    input_hash: Blake3Hash::of(&bytes),
                }]
            }

            AnthropicSseEvent::ContentBlockStart { .. } => Vec::new(),

            AnthropicSseEvent::ContentBlockDelta {
                delta: AnthropicDelta::TextDelta { text },
                ..
            } => match ctx.message_id.clone() {
                Some(mid) => vec![AgentEvent::MessageDelta {
                    message_id: mid,
                    delta: text,
                }],
                None => Vec::new(),
            },

            AnthropicSseEvent::ContentBlockDelta {
                delta: AnthropicDelta::ThinkingDelta { thinking },
                ..
            } => match ctx.message_id.clone() {
                Some(mid) => {
                    // Token count approximated as character count
                    // for V0 — the provider crate has the
                    // canonical tokenizer integration; we surface
                    // a representative number until that wires in.
                    vec![AgentEvent::ThinkingDelta {
                        message_id: mid,
                        token_count: thinking.chars().count() as u32,
                    }]
                }
                None => Vec::new(),
            },

            AnthropicSseEvent::ContentBlockDelta {
                delta: AnthropicDelta::InputJsonDelta { partial_json },
                ..
            } => match ctx.tool_call_id.clone() {
                Some(tcid) => vec![AgentEvent::ToolCallDelta {
                    tool_call_id: tcid,
                    partial: serde_json::Value::String(partial_json),
                }],
                None => Vec::new(),
            },

            AnthropicSseEvent::ContentBlockDelta { .. } => Vec::new(),

            AnthropicSseEvent::ContentBlockStop { .. } => {
                // We only emit a tool-call completion if a tool
                // call was active. Text/thinking blocks do not
                // emit a completion at this granularity (the
                // message-level completion fires on
                // `message_stop`).
                if let Some(tcid) = ctx.tool_call_id.take() {
                    vec![AgentEvent::ToolCallCompleted {
                        tool_call_id: tcid.clone(),
                        output_ref: ArtifactRef {
                            id: ArtifactId::new(tcid.0),
                            kind: ArtifactKind::ToolOutput,
                        },
                    }]
                } else {
                    Vec::new()
                }
            }

            AnthropicSseEvent::MessageDelta { .. } => Vec::new(),

            AnthropicSseEvent::MessageStop => match ctx.message_id.take() {
                Some(mid) => vec![AgentEvent::MessageCompleted {
                    message_id: mid.clone(),
                    full_text_ref: ArtifactRef {
                        id: ArtifactId::new(mid.0),
                        kind: ArtifactKind::MessageBody,
                    },
                }],
                None => Vec::new(),
            },

            AnthropicSseEvent::Ping | AnthropicSseEvent::Unknown => Vec::new(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::companions::CompanionId;
    use crate::events::SimulationState;

    fn ctx() -> NormalizeContext {
        NormalizeContext::new(CompanionId::new_ulid())
    }

    fn raw(payload: &str) -> AnthropicSseEvent {
        serde_json::from_str(payload).unwrap()
    }

    #[test]
    fn message_start_emits_message_started_event() {
        let mut c = ctx();
        let n = AnthropicNormalizer;
        let raw_evt = raw(r#"{"type":"message_start","message":{"id":"msg_abc"}}"#);
        let out = n.normalize(&mut c, raw_evt);
        assert_eq!(out.len(), 1);
        assert!(matches!(out[0], AgentEvent::MessageStarted { .. }));
        assert_eq!(c.message_id, Some(MessageId::new("msg_abc")));
    }

    #[test]
    fn text_delta_within_message_emits_message_delta() {
        let mut c = ctx();
        let n = AnthropicNormalizer;
        n.normalize(
            &mut c,
            raw(r#"{"type":"message_start","message":{"id":"m"}}"#),
        );
        let out = n.normalize(
            &mut c,
            raw(r#"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"hi"}}"#),
        );
        assert_eq!(out.len(), 1);
        assert!(matches!(out[0], AgentEvent::MessageDelta { .. }));
    }

    #[test]
    fn thinking_block_lifecycle_emits_thinking_events() {
        let mut c = ctx();
        let n = AnthropicNormalizer;
        n.normalize(
            &mut c,
            raw(r#"{"type":"message_start","message":{"id":"m"}}"#),
        );
        let out = n.normalize(
            &mut c,
            raw(r#"{"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":""}}"#),
        );
        assert!(matches!(out[0], AgentEvent::ThinkingStarted { .. }));
        let out = n.normalize(
            &mut c,
            raw(r#"{"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"step"}}"#),
        );
        assert!(matches!(out[0], AgentEvent::ThinkingDelta { .. }));
    }

    #[test]
    fn tool_use_block_emits_started_and_completed_events() {
        let mut c = ctx();
        let n = AnthropicNormalizer;
        n.normalize(
            &mut c,
            raw(r#"{"type":"message_start","message":{"id":"m"}}"#),
        );
        let out = n.normalize(
            &mut c,
            raw(
                r#"{"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"t1","name":"code_edit","input":{"path":"x"}}}"#,
            ),
        );
        assert!(matches!(out[0], AgentEvent::ToolCallStarted { .. }));
        assert_eq!(c.tool_call_id, Some(ToolCallId::new("t1")));
        let out = n.normalize(
            &mut c,
            raw(
                r#"{"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\"path\":\"x"}}"#,
            ),
        );
        assert!(matches!(out[0], AgentEvent::ToolCallDelta { .. }));
        let out = n.normalize(
            &mut c,
            raw(r#"{"type":"content_block_stop","index":1}"#),
        );
        assert!(matches!(out[0], AgentEvent::ToolCallCompleted { .. }));
        assert!(c.tool_call_id.is_none());
    }

    #[test]
    fn ping_and_unknown_events_are_dropped() {
        let mut c = ctx();
        let n = AnthropicNormalizer;
        let out = n.normalize(&mut c, raw(r#"{"type":"ping"}"#));
        assert!(out.is_empty());
        let out = n.normalize(&mut c, raw(r#"{"type":"some_future_event_kind"}"#));
        assert!(out.is_empty());
    }

    #[test]
    fn full_stream_round_trip_yields_identical_simulation_state() {
        // Acceptance-criterion test: a recorded provider stream
        // replays through the normalizer twice and produces
        // byte-identical SimulationState (per IMPLEMENTATION
        // §3-S2 acceptance + DOCTRINE I-13).
        let recorded = vec![
            r#"{"type":"message_start","message":{"id":"msg_1"}}"#,
            r#"{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}"#,
            r#"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"hello "}}"#,
            r#"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"world"}}"#,
            r#"{"type":"content_block_stop","index":0}"#,
            r#"{"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"t1","name":"fs","input":{}}}"#,
            r#"{"type":"content_block_stop","index":1}"#,
            r#"{"type":"message_stop"}"#,
        ];
        let agent = CompanionId::new_ulid();

        let run = || {
            let mut c = NormalizeContext::new(agent);
            let n = AnthropicNormalizer;
            let mut all = Vec::new();
            for raw_str in &recorded {
                let evt: AnthropicSseEvent = serde_json::from_str(raw_str).unwrap();
                all.extend(n.normalize(&mut c, evt));
            }
            all
        };
        let a = run();
        let b = run();
        assert_eq!(a, b);
        // And the resulting SimulationState is byte-identical.
        let sa = crate::replay::replay(a);
        let sb = crate::replay::replay(b);
        assert_eq!(sa.hash(), sb.hash());
        // Sanity: at least one MessageStarted + one ToolCallStarted.
        assert!(sa.message_count >= 1);
        assert!(sa.tool_call_count >= 1);
    }
}
