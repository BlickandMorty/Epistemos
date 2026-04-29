//! OpenAI Chat Completions stream → `AgentEvent` normalization (S2).
//!
//! Covers the canonical OpenAI SSE delta shape used by
//! `agent_core/src/providers/openai.rs`:
//!
//!   { "choices": [{ "delta": { "role"|"content"|"tool_calls": ... } }],
//!     "usage": ..., "id": "chatcmpl-...", "finish_reason": null|"stop"|"tool_calls" }
//!
//! Each delta frame is converted to zero or more `AgentEvent`s. Per
//! IMPLEMENTATION §3-S2, the canonical happy-path coverage at S2
//! is: first frame → MessageStarted; content delta → MessageDelta;
//! tool_calls delta → ToolCallStarted / ToolCallDelta; finish →
//! MessageCompleted / ToolCallCompleted.

use serde::Deserialize;

use super::{NormalizeContext, Normalizer};
use crate::events::{
    AgentEvent, ArtifactKind, ArtifactRef, ArtifactId, Blake3Hash, MessageId, ToolCallId,
};

/// One streamed chat-completion chunk.
#[derive(Debug, Clone, Deserialize)]
pub struct OpenAiChunk {
    /// `chatcmpl-*` id; we use the first frame's id as the canonical
    /// MessageId.
    #[serde(default)]
    pub id: Option<String>,
    pub choices: Vec<OpenAiChoice>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct OpenAiChoice {
    #[serde(default)]
    pub delta: OpenAiDelta,
    #[serde(default)]
    pub finish_reason: Option<String>,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct OpenAiDelta {
    #[serde(default)]
    pub role: Option<String>,
    #[serde(default)]
    pub content: Option<String>,
    #[serde(default)]
    pub tool_calls: Vec<OpenAiToolCallDelta>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct OpenAiToolCallDelta {
    #[serde(default)]
    pub index: u32,
    #[serde(default)]
    pub id: Option<String>,
    #[serde(default)]
    pub function: OpenAiFunctionDelta,
    #[serde(default, rename = "type")]
    pub kind: Option<String>,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct OpenAiFunctionDelta {
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub arguments: Option<String>,
}

pub struct OpenAiNormalizer;

impl Normalizer for OpenAiNormalizer {
    type Raw = OpenAiChunk;

    fn normalize(&self, ctx: &mut NormalizeContext, raw: Self::Raw) -> Vec<AgentEvent> {
        let mut out = Vec::new();

        // First frame for this stream: synthesise MessageStarted.
        if ctx.message_id.is_none() {
            let id = raw
                .id
                .clone()
                .unwrap_or_else(|| format!("chatcmpl-{}", ulid::Ulid::new()));
            let mid = MessageId::new(id);
            ctx.message_id = Some(mid.clone());
            out.push(AgentEvent::MessageStarted {
                message_id: mid,
                agent_id: ctx.agent_id,
            });
        }

        for choice in raw.choices {
            // Content delta.
            if let Some(text) = choice.delta.content {
                if !text.is_empty() {
                    if let Some(mid) = ctx.message_id.clone() {
                        out.push(AgentEvent::MessageDelta {
                            message_id: mid,
                            delta: text,
                        });
                    }
                }
            }

            // Tool-call delta. OpenAI streams tool calls in pieces:
            // first frame carries `id` + `function.name`; later
            // frames carry `arguments` partials.
            for tc in choice.delta.tool_calls {
                if let Some(id) = tc.id.clone() {
                    let tcid = ToolCallId::new(id);
                    ctx.tool_call_id = Some(tcid.clone());
                    let name = tc.function.name.clone().unwrap_or_default();
                    out.push(AgentEvent::ToolCallStarted {
                        tool_call_id: tcid,
                        agent_id: ctx.agent_id,
                        tool_name: name,
                        // Hash so far is over the empty argument
                        // string; later argument deltas accumulate
                        // inside the partial JSON value below.
                        input_hash: Blake3Hash::of(b""),
                    });
                }
                if let Some(args) = tc.function.arguments {
                    if let Some(tcid) = ctx.tool_call_id.clone() {
                        out.push(AgentEvent::ToolCallDelta {
                            tool_call_id: tcid,
                            partial: serde_json::Value::String(args),
                        });
                    }
                }
            }

            // Finish reason → message-level / tool-call completion.
            if let Some(reason) = choice.finish_reason {
                if reason == "tool_calls" {
                    if let Some(tcid) = ctx.tool_call_id.take() {
                        out.push(AgentEvent::ToolCallCompleted {
                            tool_call_id: tcid.clone(),
                            output_ref: ArtifactRef {
                                id: ArtifactId::new(tcid.0),
                                kind: ArtifactKind::ToolOutput,
                            },
                        });
                    }
                }
                if let Some(mid) = ctx.message_id.take() {
                    out.push(AgentEvent::MessageCompleted {
                        message_id: mid.clone(),
                        full_text_ref: ArtifactRef {
                            id: ArtifactId::new(mid.0),
                            kind: ArtifactKind::MessageBody,
                        },
                    });
                }
            }
        }

        out
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::companions::CompanionId;

    fn ctx() -> NormalizeContext {
        NormalizeContext::new(CompanionId::new_ulid())
    }

    fn chunk(payload: &str) -> OpenAiChunk {
        serde_json::from_str(payload).unwrap()
    }

    #[test]
    fn first_chunk_emits_message_started() {
        let mut c = ctx();
        let n = OpenAiNormalizer;
        let raw = chunk(
            r#"{"id":"chatcmpl-1","choices":[{"delta":{"role":"assistant","content":"hi"}}]}"#,
        );
        let out = n.normalize(&mut c, raw);
        // MessageStarted then MessageDelta.
        assert_eq!(out.len(), 2);
        assert!(matches!(out[0], AgentEvent::MessageStarted { .. }));
        assert!(matches!(out[1], AgentEvent::MessageDelta { .. }));
        assert_eq!(c.message_id, Some(MessageId::new("chatcmpl-1")));
    }

    #[test]
    fn subsequent_content_chunks_emit_only_delta() {
        let mut c = ctx();
        let n = OpenAiNormalizer;
        n.normalize(
            &mut c,
            chunk(r#"{"id":"chatcmpl-1","choices":[{"delta":{"role":"assistant","content":""}}]}"#),
        );
        let out = n.normalize(
            &mut c,
            chunk(r#"{"id":"chatcmpl-1","choices":[{"delta":{"content":" world"}}]}"#),
        );
        assert_eq!(out.len(), 1);
        assert!(matches!(out[0], AgentEvent::MessageDelta { .. }));
    }

    #[test]
    fn finish_emits_message_completed() {
        let mut c = ctx();
        let n = OpenAiNormalizer;
        n.normalize(
            &mut c,
            chunk(r#"{"id":"chatcmpl-1","choices":[{"delta":{"content":"x"}}]}"#),
        );
        let out = n.normalize(
            &mut c,
            chunk(r#"{"id":"chatcmpl-1","choices":[{"delta":{},"finish_reason":"stop"}]}"#),
        );
        assert!(out
            .iter()
            .any(|e| matches!(e, AgentEvent::MessageCompleted { .. })));
        assert!(c.message_id.is_none());
    }

    #[test]
    fn tool_calls_lifecycle() {
        let mut c = ctx();
        let n = OpenAiNormalizer;
        // First frame: tool call started with id + function name.
        let out = n.normalize(
            &mut c,
            chunk(
                r#"{"id":"chatcmpl-1","choices":[{"delta":{"role":"assistant","tool_calls":[{"index":0,"id":"call_1","type":"function","function":{"name":"do_x"}}]}}]}"#,
            ),
        );
        // MessageStarted + ToolCallStarted.
        assert_eq!(out.len(), 2);
        assert!(matches!(out[0], AgentEvent::MessageStarted { .. }));
        assert!(matches!(out[1], AgentEvent::ToolCallStarted { .. }));
        // Second frame: argument delta.
        let out = n.normalize(
            &mut c,
            chunk(
                r#"{"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\"a\":1}"}}]}}]}"#,
            ),
        );
        assert!(matches!(out[0], AgentEvent::ToolCallDelta { .. }));
        // Finish frame.
        let out = n.normalize(
            &mut c,
            chunk(r#"{"choices":[{"delta":{},"finish_reason":"tool_calls"}]}"#),
        );
        assert!(out
            .iter()
            .any(|e| matches!(e, AgentEvent::ToolCallCompleted { .. })));
        assert!(out
            .iter()
            .any(|e| matches!(e, AgentEvent::MessageCompleted { .. })));
    }

    #[test]
    fn round_trip_is_deterministic() {
        let agent = CompanionId::new_ulid();
        let chunks = [
            r#"{"id":"chatcmpl-1","choices":[{"delta":{"role":"assistant","content":"hi"}}]}"#,
            r#"{"id":"chatcmpl-1","choices":[{"delta":{"content":" there"}}]}"#,
            r#"{"id":"chatcmpl-1","choices":[{"delta":{},"finish_reason":"stop"}]}"#,
        ];
        let run = || {
            let mut c = NormalizeContext::new(agent);
            let n = OpenAiNormalizer;
            chunks
                .iter()
                .flat_map(|s| n.normalize(&mut c, chunk(s)))
                .collect::<Vec<_>>()
        };
        assert_eq!(run(), run());
    }
}
