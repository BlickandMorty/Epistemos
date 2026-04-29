//! Local MLX-Swift inference events → `AgentEvent` normalization
//! (S2).
//!
//! The local Qwen3 / Hermes-3 / Mamba runtimes hosted in
//! `Epistemos/Engine/MLXInferenceService.swift` produce a small
//! set of typed events as they stream tokens. The Swift side
//! emits these over the FFI boundary as JSON; we deserialise here
//! and project them onto `AgentEvent` so the simulation reducer
//! treats local and cloud streams identically (DOCTRINE I-3).
//!
//! Coverage at S2: token deltas, message lifecycle, grammar-
//! constrained tool calls (the local runtime's idiomatic tool
//! invocation per CLAUDE.md "Local Qwen3.5/Hermes-3: in-process
//! MLX, grammar-constrained tools"). Local-side error recovery
//! and adapter-load events graduate at S11 / S14.

use serde::Deserialize;

use super::{NormalizeContext, Normalizer};
use crate::events::{
    AgentEvent, ArtifactKind, ArtifactRef, ArtifactId, Blake3Hash, MessageId, ToolCallId,
};

#[derive(Debug, Clone, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum LocalMlxEvent {
    /// Inference loop started; `message_id` is a deterministic id
    /// derived from `(session_id, turn_index)` Swift-side.
    MessageStarted {
        message_id: String,
    },
    /// Token emitted by the model.
    TokenDelta {
        message_id: String,
        text: String,
    },
    /// Grammar-constrained tool call begins.
    ToolCallStarted {
        tool_call_id: String,
        tool_name: String,
        #[serde(default)]
        input: serde_json::Value,
    },
    /// Grammar-constrained tool call ends with structured output.
    ToolCallCompleted {
        tool_call_id: String,
        #[serde(default)]
        output_id: Option<String>,
    },
    /// Inference loop reached `end_turn` or hit the max-tokens cap.
    MessageCompleted {
        message_id: String,
    },
    #[serde(other)]
    Unknown,
}

pub struct LocalMlxNormalizer;

impl Normalizer for LocalMlxNormalizer {
    type Raw = LocalMlxEvent;

    fn normalize(&self, ctx: &mut NormalizeContext, raw: Self::Raw) -> Vec<AgentEvent> {
        match raw {
            LocalMlxEvent::MessageStarted { message_id } => {
                let mid = MessageId::new(message_id);
                ctx.message_id = Some(mid.clone());
                vec![AgentEvent::MessageStarted {
                    message_id: mid,
                    agent_id: ctx.agent_id,
                }]
            }
            LocalMlxEvent::TokenDelta { message_id, text } => {
                vec![AgentEvent::MessageDelta {
                    message_id: MessageId::new(message_id),
                    delta: text,
                }]
            }
            LocalMlxEvent::ToolCallStarted {
                tool_call_id,
                tool_name,
                input,
            } => {
                let tcid = ToolCallId::new(tool_call_id);
                ctx.tool_call_id = Some(tcid.clone());
                let bytes = serde_json::to_vec(&input).unwrap_or_default();
                vec![AgentEvent::ToolCallStarted {
                    tool_call_id: tcid,
                    agent_id: ctx.agent_id,
                    tool_name,
                    input_hash: Blake3Hash::of(&bytes),
                }]
            }
            LocalMlxEvent::ToolCallCompleted {
                tool_call_id,
                output_id,
            } => {
                let tcid = ToolCallId::new(tool_call_id);
                ctx.tool_call_id = None;
                vec![AgentEvent::ToolCallCompleted {
                    tool_call_id: tcid.clone(),
                    output_ref: ArtifactRef {
                        id: ArtifactId::new(output_id.unwrap_or(tcid.0)),
                        kind: ArtifactKind::ToolOutput,
                    },
                }]
            }
            LocalMlxEvent::MessageCompleted { message_id } => {
                let mid = MessageId::new(message_id);
                ctx.message_id = None;
                vec![AgentEvent::MessageCompleted {
                    message_id: mid.clone(),
                    full_text_ref: ArtifactRef {
                        id: ArtifactId::new(mid.0),
                        kind: ArtifactKind::MessageBody,
                    },
                }]
            }
            LocalMlxEvent::Unknown => Vec::new(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::companions::CompanionId;

    fn ctx() -> NormalizeContext {
        NormalizeContext::new(CompanionId::new_ulid())
    }

    fn raw(payload: &str) -> LocalMlxEvent {
        serde_json::from_str(payload).unwrap()
    }

    #[test]
    fn token_delta_within_message_emits_message_delta() {
        let mut c = ctx();
        let n = LocalMlxNormalizer;
        n.normalize(
            &mut c,
            raw(r#"{"kind":"message_started","message_id":"m1"}"#),
        );
        let out = n.normalize(
            &mut c,
            raw(r#"{"kind":"token_delta","message_id":"m1","text":"hello"}"#),
        );
        assert!(matches!(out[0], AgentEvent::MessageDelta { .. }));
    }

    #[test]
    fn tool_call_grammar_lifecycle() {
        let mut c = ctx();
        let n = LocalMlxNormalizer;
        let out = n.normalize(
            &mut c,
            raw(
                r#"{"kind":"tool_call_started","tool_call_id":"t1","tool_name":"local_search","input":{"q":"x"}}"#,
            ),
        );
        assert!(matches!(out[0], AgentEvent::ToolCallStarted { .. }));
        let out = n.normalize(
            &mut c,
            raw(r#"{"kind":"tool_call_completed","tool_call_id":"t1"}"#),
        );
        assert!(matches!(out[0], AgentEvent::ToolCallCompleted { .. }));
        assert!(c.tool_call_id.is_none());
    }
}
