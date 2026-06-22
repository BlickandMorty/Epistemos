//! TRINITY orchestrator — the provider-boundary adapter (owner 2026-06-22). The async TWV loop's role calls
//! talk to an `AgentProvider`, which STREAMS `StreamEvent`s; this collapses one provider response stream into
//! the single `String` a role turn needs. The provider-backed `TrinityRoleExecutorAsync` (which selects a model
//! per tier via `trinity_routing::select_model_for_tier`, builds the role prompt, calls `stream_message`, and
//! collects here) is the final wiring slice; this adapter is its reusable, independently-tested core.

use futures::StreamExt;

use crate::agent_loop::AgentError;
use crate::provider::{MessageStream, StreamEvent};

/// Drain a provider response stream into its full visible text: accumulate every `TextDelta`, stop at
/// `MessageStop` (or stream end). A stream error propagates (HONEST — a failed model call never silently
/// becomes an empty/partial answer that could be mistaken for a real one). Non-text events (tool/json/signature
/// deltas) are ignored — a TRINITY role turn wants the plain answer text.
pub async fn collect_stream_text(mut stream: MessageStream) -> Result<String, AgentError> {
    let mut text = String::new();
    while let Some(event) = stream.next().await {
        match event? {
            StreamEvent::TextDelta { text: delta, .. } => text.push_str(&delta),
            StreamEvent::MessageStop { .. } => break,
            _ => {}
        }
    }
    Ok(text)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::{StopReason, TokenUsage};

    fn stream_of(events: Vec<Result<StreamEvent, AgentError>>) -> MessageStream {
        Box::pin(futures::stream::iter(events))
    }

    #[tokio::test]
    async fn collects_text_deltas_until_message_stop() {
        let stream = stream_of(vec![
            Ok(StreamEvent::TextDelta { index: 0, text: "Hello, ".into() }),
            Ok(StreamEvent::TextDelta { index: 0, text: "world".into() }),
            Ok(StreamEvent::MessageStop { stop_reason: StopReason::EndTurn, usage: TokenUsage::default() }),
            // anything after MessageStop is ignored (we already broke).
            Ok(StreamEvent::TextDelta { index: 0, text: " IGNORED".into() }),
        ]);
        assert_eq!(collect_stream_text(stream).await.unwrap(), "Hello, world");
    }

    #[tokio::test]
    async fn ignores_non_text_events() {
        let stream = stream_of(vec![
            Ok(StreamEvent::SignatureDelta { index: 0, signature: "sig".into() }),
            Ok(StreamEvent::TextDelta { index: 0, text: "answer".into() }),
            Ok(StreamEvent::MessageStop { stop_reason: StopReason::EndTurn, usage: TokenUsage::default() }),
        ]);
        assert_eq!(collect_stream_text(stream).await.unwrap(), "answer");
    }

    #[tokio::test]
    async fn stream_error_propagates_honestly() {
        let stream = stream_of(vec![
            Ok(StreamEvent::TextDelta { index: 0, text: "partial".into() }),
            Err(AgentError::Provider("upstream failed".into())),
        ]);
        // a failed model call surfaces as Err — never a silent partial "answer".
        assert!(collect_stream_text(stream).await.is_err());
    }

    #[tokio::test]
    async fn empty_stream_is_empty_text() {
        assert_eq!(collect_stream_text(stream_of(vec![])).await.unwrap(), "");
    }
}
