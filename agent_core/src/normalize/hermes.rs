//! Hermes Agent (Nous Research) JSON-RPC events → `AgentEvent`
//! normalization (S2).
//!
//! Hermes is the graph-faculty subprocess described in
//! DOCTRINE §8. It speaks JSON-RPC over stdio with a small set of
//! method/notification kinds:
//!
//!   - `message.delta` notifications carrying chunked output
//!   - `tool.call.started` / `tool.call.completed` notifications
//!     for the seven graph verbs (DOCTRINE §8.3)
//!   - `graph.node.created` / `graph.edge.created` / `graph.node.accessed`
//!     and traversal markers
//!   - `recovery.started` / `recovery.completed` when Hermes
//!     auto-heals a corrupted slice
//!
//! S2 covers the canonical happy-path notifications. The full
//! taxonomy lands in S9 alongside the hermes session wiring.

use serde::Deserialize;

use super::{NormalizeContext, Normalizer};
use crate::events::{
    AgentEvent, ArtifactKind, ArtifactRef, ArtifactId, Blake3Hash, EdgeId, EdgeKind,
    ErrorId, MessageId, NodeId, NodeKind, ToolCallId,
};

#[derive(Debug, Clone, Deserialize)]
#[serde(tag = "method", content = "params", rename_all = "snake_case")]
pub enum HermesEvent {
    #[serde(rename = "message.delta")]
    MessageDelta {
        message_id: String,
        delta: String,
    },
    #[serde(rename = "message.completed")]
    MessageCompleted {
        message_id: String,
    },
    #[serde(rename = "tool.call.started")]
    ToolCallStarted {
        tool_call_id: String,
        tool_name: String,
        #[serde(default)]
        input: serde_json::Value,
    },
    #[serde(rename = "tool.call.completed")]
    ToolCallCompleted {
        tool_call_id: String,
        #[serde(default)]
        output_id: Option<String>,
    },
    #[serde(rename = "graph.node.accessed")]
    GraphNodeAccessed {
        node_id: String,
    },
    #[serde(rename = "graph.node.created")]
    GraphNodeCreated {
        node_id: String,
        kind: NodeKind,
    },
    #[serde(rename = "graph.edge.created")]
    GraphEdgeCreated {
        edge_id: String,
        from: String,
        to: String,
        kind: EdgeKind,
    },
    #[serde(rename = "graph.traverse.started")]
    GraphTraverseStarted {
        start: String,
        max_depth: u32,
    },
    #[serde(rename = "graph.traverse.completed")]
    GraphTraverseCompleted {
        visited: Vec<String>,
    },
    #[serde(rename = "recovery.started")]
    RecoveryStarted {
        error_id: String,
    },
    #[serde(rename = "recovery.completed")]
    RecoveryCompleted {
        error_id: String,
        success: bool,
    },
}

pub struct HermesNormalizer;

impl Normalizer for HermesNormalizer {
    type Raw = HermesEvent;

    fn normalize(&self, ctx: &mut NormalizeContext, raw: Self::Raw) -> Vec<AgentEvent> {
        match raw {
            HermesEvent::MessageDelta { message_id, delta } => {
                let mid = MessageId::new(message_id);
                let mut out = Vec::new();
                if ctx.message_id.is_none() {
                    ctx.message_id = Some(mid.clone());
                    out.push(AgentEvent::MessageStarted {
                        message_id: mid.clone(),
                        agent_id: ctx.agent_id,
                    });
                }
                out.push(AgentEvent::MessageDelta {
                    message_id: mid,
                    delta,
                });
                out
            }
            HermesEvent::MessageCompleted { message_id } => {
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
            HermesEvent::ToolCallStarted {
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
            HermesEvent::ToolCallCompleted {
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
            HermesEvent::GraphNodeAccessed { node_id } => {
                vec![AgentEvent::GraphNodeAccessed {
                    agent_id: ctx.agent_id,
                    node_id: NodeId::new(node_id),
                }]
            }
            HermesEvent::GraphNodeCreated { node_id, kind } => {
                vec![AgentEvent::GraphNodeCreated {
                    agent_id: ctx.agent_id,
                    node_id: NodeId::new(node_id),
                    kind,
                }]
            }
            HermesEvent::GraphEdgeCreated {
                edge_id,
                from,
                to,
                kind,
            } => vec![AgentEvent::GraphEdgeCreated {
                agent_id: ctx.agent_id,
                edge_id: EdgeId::new(edge_id),
                from: NodeId::new(from),
                to: NodeId::new(to),
                kind,
            }],
            HermesEvent::GraphTraverseStarted { start, max_depth } => {
                vec![AgentEvent::GraphTraverseStarted {
                    agent_id: ctx.agent_id,
                    start: NodeId::new(start),
                    max_depth,
                }]
            }
            HermesEvent::GraphTraverseCompleted { visited } => {
                vec![AgentEvent::GraphTraverseCompleted {
                    agent_id: ctx.agent_id,
                    visited: visited.into_iter().map(NodeId::new).collect(),
                }]
            }
            HermesEvent::RecoveryStarted { error_id } => {
                vec![AgentEvent::RecoveryStarted {
                    agent_id: ctx.agent_id,
                    error_id: ErrorId::new(error_id),
                }]
            }
            HermesEvent::RecoveryCompleted { error_id, success } => {
                vec![AgentEvent::RecoveryCompleted {
                    agent_id: ctx.agent_id,
                    error_id: ErrorId::new(error_id),
                    success,
                }]
            }
        }
    }
}

/// Try to decode a raw Hermes JSON-RPC notification into a typed
/// `HermesEvent`. Returns `Ok(None)` for unknown method names
/// (forward-compat from a newer Hermes version) so the caller can
/// silently skip them in production. Other JSON parse errors
/// surface as `Err`.
pub fn try_decode(raw_json: &str) -> Result<Option<HermesEvent>, serde_json::Error> {
    match serde_json::from_str::<HermesEvent>(raw_json) {
        Ok(e) => Ok(Some(e)),
        Err(e) => {
            // Distinguish "unknown method" (allowed) from genuine
            // parse errors. Method-name extraction is cheap and
            // leaves us with a structured outcome.
            #[derive(Deserialize)]
            struct MethodOnly {
                method: String,
            }
            if let Ok(MethodOnly { method }) = serde_json::from_str::<MethodOnly>(raw_json) {
                let known = matches!(
                    method.as_str(),
                    "message.delta"
                        | "message.completed"
                        | "tool.call.started"
                        | "tool.call.completed"
                        | "graph.node.accessed"
                        | "graph.node.created"
                        | "graph.edge.created"
                        | "graph.traverse.started"
                        | "graph.traverse.completed"
                        | "recovery.started"
                        | "recovery.completed"
                );
                if !known {
                    // Unknown method — forward-compat skip.
                    return Ok(None);
                }
            }
            Err(e)
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

    fn raw(payload: &str) -> HermesEvent {
        serde_json::from_str(payload).unwrap()
    }

    #[test]
    fn first_message_delta_emits_started_then_delta() {
        let mut c = ctx();
        let n = HermesNormalizer;
        let out = n.normalize(
            &mut c,
            raw(r#"{"method":"message.delta","params":{"message_id":"m1","delta":"hi"}}"#),
        );
        assert_eq!(out.len(), 2);
        assert!(matches!(out[0], AgentEvent::MessageStarted { .. }));
        assert!(matches!(out[1], AgentEvent::MessageDelta { .. }));
    }

    #[test]
    fn graph_mutation_events_normalize() {
        let mut c = ctx();
        let n = HermesNormalizer;
        let out = n.normalize(
            &mut c,
            raw(
                r#"{"method":"graph.node.created","params":{"node_id":"n1","kind":"Note"}}"#,
            ),
        );
        assert!(matches!(out[0], AgentEvent::GraphNodeCreated { .. }));
        let out = n.normalize(
            &mut c,
            raw(
                r#"{"method":"graph.edge.created","params":{"edge_id":"e1","from":"n1","to":"n2","kind":"Reference"}}"#,
            ),
        );
        assert!(matches!(out[0], AgentEvent::GraphEdgeCreated { .. }));
    }

    #[test]
    fn unknown_method_decodes_to_none() {
        // Forward-compat: a method we haven't taught the
        // normalizer about yet must NOT crash the stream.
        // `try_decode` returns `Ok(None)` so the writer drops it.
        let r = try_decode(r#"{"method":"future.event","params":{"x":1}}"#).unwrap();
        assert!(r.is_none());
    }

    #[test]
    fn malformed_json_surfaces_serde_error() {
        let r = try_decode(r#"not valid json"#);
        assert!(r.is_err());
    }
}
