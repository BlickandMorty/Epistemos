//! TRINITY orchestrator — the provider-boundary adapter (owner 2026-06-22). The async TWV loop's role calls
//! talk to an `AgentProvider`, which STREAMS `StreamEvent`s; this collapses one provider response stream into
//! the single `String` a role turn needs. The provider-backed `TrinityRoleExecutorAsync` (which selects a model
//! per tier via `trinity_routing::select_model_for_tier`, builds the role prompt, calls `stream_message`, and
//! collects here) is the final wiring slice; this adapter is its reusable, independently-tested core.

use std::sync::Arc;

use async_trait::async_trait;
use futures::StreamExt;

use crate::agent_loop::{AgentConfig, AgentError};
use crate::model_profile::CapabilityTier;
use crate::provider::{AgentProvider, MessageStream, StreamEvent};
use crate::types::Message;

use super::trinity_async::TrinityRoleExecutorAsync;
use super::trinity_executor::{parse_verifier_verdict, thinker_prompt, verifier_prompt, worker_prompt};
use super::trinity_loop::{TrinityRole, VerifierVerdict};
use super::trinity_routing::select_role_tier;

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

/// The real provider-backed async TRINITY executor (capstone): each role selects its tier
/// (`select_role_tier`), resolves a provider via the injected `provider_for_tier` (which uses
/// `select_model_for_tier` app-side), builds the role prompt, calls `stream_message`, and collects the result.
/// HONEST: a provider/stream failure becomes a visible `[trinity-error: …]` content string — for the Verifier
/// that parses as NOT-ACCEPT → REPAIR (an errored turn can never false-ACCEPT), and for Thinker/Worker it is
/// visible in the trace + rejected by the Verifier, never silently an empty answer.
pub struct ProviderTrinityExecutor<F>
where
    F: Fn(CapabilityTier) -> Arc<dyn AgentProvider> + Send + Sync,
{
    objective: String,
    provider_for_tier: F,
}

impl<F> ProviderTrinityExecutor<F>
where
    F: Fn(CapabilityTier) -> Arc<dyn AgentProvider> + Send + Sync,
{
    pub fn new(objective: impl Into<String>, provider_for_tier: F) -> Self {
        Self { objective: objective.into(), provider_for_tier }
    }

    async fn run(&self, role: TrinityRole, objective: &str, prompt: &str) -> String {
        let tier = select_role_tier(role, objective);
        let provider = (self.provider_for_tier)(tier);
        let messages = [Message::user_text(prompt)];
        let config = AgentConfig::default();
        match provider.stream_message(&messages, &[], &config).await {
            Ok(stream) => collect_stream_text(stream)
                .await
                .unwrap_or_else(|e| format!("[trinity-error: {e:?}]")),
            Err(e) => format!("[trinity-error: {e:?}]"),
        }
    }
}

#[async_trait]
impl<F> TrinityRoleExecutorAsync for ProviderTrinityExecutor<F>
where
    F: Fn(CapabilityTier) -> Arc<dyn AgentProvider> + Send + Sync,
{
    async fn think(&mut self, objective: &str, feedback: &str) -> String {
        self.run(TrinityRole::Thinker, objective, &thinker_prompt(objective, feedback)).await
    }
    async fn work(&mut self, plan: &str) -> String {
        let objective = self.objective.clone();
        self.run(TrinityRole::Worker, &objective, &worker_prompt(plan)).await
    }
    async fn verify(&mut self, work: &str, objective: &str) -> (VerifierVerdict, String) {
        let out = self.run(TrinityRole::Verifier, objective, &verifier_prompt(work, objective)).await;
        parse_verifier_verdict(&out)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::provider::ProviderCapabilities;
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

    // --- ProviderTrinityExecutor (capstone) ---

    /// A mock provider that replies based on the prompt (Verifier prompt → ACCEPT/REPAIR script; else fixed).
    struct MockProvider {
        verifier_accepts: bool,
    }
    #[async_trait]
    impl AgentProvider for MockProvider {
        async fn stream_message(
            &self,
            messages: &[Message],
            _tools: &[crate::types::ToolSchema],
            _config: &AgentConfig,
        ) -> Result<MessageStream, AgentError> {
            let prompt = format!("{:?}", messages);
            let reply = if prompt.contains("Reply with exactly") {
                if self.verifier_accepts { "ACCEPT" } else { "REPAIR: redo" }
            } else if prompt.contains("Execute this plan") {
                "the final answer"
            } else {
                "a plan"
            };
            Ok(stream_of(vec![
                Ok(StreamEvent::TextDelta { index: 0, text: reply.into() }),
                Ok(StreamEvent::MessageStop { stop_reason: StopReason::EndTurn, usage: TokenUsage::default() }),
            ]))
        }
        async fn compact(&self, messages: &[Message]) -> Result<Vec<Message>, AgentError> {
            Ok(messages.to_vec())
        }
        fn capabilities(&self) -> ProviderCapabilities {
            ProviderCapabilities {
                max_context_tokens: 8192,
                max_output_tokens: 2048,
                supports_thinking: false,
                supports_vision: false,
                supports_web_search: false,
                supports_code_execution: false,
                supports_computer_use: false,
                supports_mcp: false,
                supports_streaming: true,
                supports_compaction: false,
                cost_input_per_million: 0.0,
                cost_output_per_million: 0.0,
            }
        }
        fn name(&self) -> &'static str {
            "mock"
        }
    }

    #[tokio::test]
    async fn provider_executor_drives_the_async_loop_to_accept() {
        use super::super::trinity_async::run_trinity_loop_async;
        let provider: Arc<dyn AgentProvider> = Arc::new(MockProvider { verifier_accepts: true });
        let provider_for_tier = move |_tier: CapabilityTier| provider.clone();
        let mut exec = ProviderTrinityExecutor::new("write a function", provider_for_tier);
        let out = run_trinity_loop_async("write a function", 5, &mut exec).await;
        assert!(out.accepted);
        assert_eq!(out.final_answer, "the final answer");
    }

    #[tokio::test]
    async fn provider_executor_never_false_accepts_when_verifier_repairs() {
        use super::super::trinity_async::run_trinity_loop_async;
        let provider: Arc<dyn AgentProvider> = Arc::new(MockProvider { verifier_accepts: false });
        let provider_for_tier = move |_tier: CapabilityTier| provider.clone();
        let mut exec = ProviderTrinityExecutor::new("hard", provider_for_tier);
        let out = run_trinity_loop_async("hard", 5, &mut exec).await;
        assert!(!out.accepted, "a never-accepting verifier honestly budget-exhausts");
    }
}
