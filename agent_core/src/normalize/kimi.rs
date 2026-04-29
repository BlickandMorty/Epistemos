//! Kimi (Moonshot) stream → `AgentEvent` normalization (S2).
//!
//! Kimi exposes an OpenAI-compatible streaming Chat Completions
//! endpoint (`api.moonshot.cn/v1/chat/completions`). The wire shape
//! is identical to OpenAI's, so this normalizer is a thin wrapper
//! around `OpenAiNormalizer`. Future Kimi-specific events
//! (long-context mode markers, agent-mode tool deltas) extend
//! locally.

use super::{
    openai::{OpenAiChunk, OpenAiNormalizer},
    NormalizeContext, Normalizer,
};
use crate::events::AgentEvent;

pub struct KimiNormalizer;

impl Normalizer for KimiNormalizer {
    type Raw = OpenAiChunk;

    fn normalize(&self, ctx: &mut NormalizeContext, raw: Self::Raw) -> Vec<AgentEvent> {
        OpenAiNormalizer.normalize(ctx, raw)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::companions::CompanionId;
    use crate::events::MessageId;

    #[test]
    fn delegates_to_openai_normalizer() {
        let mut c = NormalizeContext::new(CompanionId::new_ulid());
        let n = KimiNormalizer;
        let raw: OpenAiChunk = serde_json::from_str(
            r#"{"id":"kmi-1","choices":[{"delta":{"role":"assistant","content":"hello"}}]}"#,
        )
        .unwrap();
        let out = n.normalize(&mut c, raw);
        assert!(matches!(out[0], AgentEvent::MessageStarted { .. }));
        assert_eq!(c.message_id, Some(MessageId::new("kmi-1")));
    }
}
