//! In-process-orchestrated GGUF provider via the local `llama-cli` binary.
//!
//! PRO-ONLY. This is gated behind `pro-build` because it shells out to
//! `/opt/homebrew/bin/llama-cli` (a one-shot, hardened subprocess) — which the
//! MAS sandbox + hardened runtime forbid. It is the proven on-device GGUF path:
//! `llama-cli` loads a Gemma 4 QAT/coder GGUF fully onto Apple Silicon Metal and
//! generates real tokens (E2B ~64 tok/s, 12B coder ~18.5 tok/s, verified
//! 2026-06-16; see artifacts/runtime_receipts/). The command mirrors the
//! `small_compressed_model_owner_approved_runtime_probe` gate's template:
//! offline, deterministic, context/batch capped, no mmap, no network, no server.
//!
//! It returns `ProviderRuntime::Local` so the agent loop refuses to start for it
//! (Gemma stays non-agent per honest-capability-gating), and it streams every
//! line of stdout to the delegate as it arrives (STREAM EVERYTHING).

#![cfg(feature = "pro-build")]

use std::path::PathBuf;
use std::process::Stdio;

use async_stream::stream;
use async_trait::async_trait;
use tokio::io::{AsyncBufReadExt, BufReader};

use crate::agent_loop::{AgentConfig, AgentError};
use crate::provider::{
    AgentProvider, MessageStream, ProviderCapabilities, ProviderRuntime, StreamEvent,
};
use crate::types::{Message, StopReason, TokenUsage, ToolSchema, UserContent};

const DEFAULT_LLAMA_CLI: &str = "/opt/homebrew/bin/llama-cli";
const DEFAULT_CTX_SIZE: u32 = 4096;
const DEFAULT_MAX_TOKENS: u32 = 512;

/// A Pro-only on-device provider that runs a local GGUF model through the
/// hardened `llama-cli` subprocess. Never reachable on the MAS build.
pub struct GgufCliProvider {
    model_path: PathBuf,
    llama_cli_path: PathBuf,
    ctx_size: u32,
    max_output_tokens: u32,
}

impl GgufCliProvider {
    /// Construct against a local, owner-provided GGUF model path. The path is
    /// never downloaded here; it must already exist on disk (the gate chain
    /// owns acquisition + the SHA pin).
    pub fn new(model_path: impl Into<PathBuf>) -> Self {
        Self {
            model_path: model_path.into(),
            llama_cli_path: PathBuf::from(DEFAULT_LLAMA_CLI),
            ctx_size: DEFAULT_CTX_SIZE,
            max_output_tokens: DEFAULT_MAX_TOKENS,
        }
    }

    pub fn with_llama_cli_path(mut self, path: impl Into<PathBuf>) -> Self {
        self.llama_cli_path = path.into();
        self
    }

    pub fn with_ctx_size(mut self, ctx_size: u32) -> Self {
        self.ctx_size = ctx_size;
        self
    }

    /// Flatten the conversation into a single prompt. `llama-cli` applies the
    /// model's embedded chat template to `--prompt`, so we pass the system
    /// prompt (if any) plus the text of the most recent user turn — matching the
    /// proven `--single-turn` probe.
    fn build_prompt(messages: &[Message], system_prompt: Option<&str>) -> String {
        let last_user_text = messages
            .iter()
            .rev()
            .find_map(|message| match message {
                Message::User { content } => {
                    let text: String = content
                        .iter()
                        .filter_map(|block| match block {
                            UserContent::Text { text } => Some(text.as_str()),
                            _ => None,
                        })
                        .collect::<Vec<_>>()
                        .join("\n");
                    if text.trim().is_empty() {
                        None
                    } else {
                        Some(text)
                    }
                }
                Message::Assistant { .. } => None,
            })
            .unwrap_or_default();
        match system_prompt {
            Some(system) if !system.trim().is_empty() => {
                format!("{system}\n\n{last_user_text}")
            }
            _ => last_user_text,
        }
    }
}

#[async_trait]
impl AgentProvider for GgufCliProvider {
    async fn stream_message(
        &self,
        messages: &[Message],
        _tools: &[ToolSchema],
        config: &AgentConfig,
    ) -> Result<MessageStream, AgentError> {
        let prompt = Self::build_prompt(messages, config.system_prompt.as_deref());
        let model = self.model_path.clone();
        let cli = self.llama_cli_path.clone();
        let ctx = self.ctx_size;
        let predict = config.max_output_tokens.unwrap_or(self.max_output_tokens);

        let s = stream! {
            // Exact, gate-aligned, network-free, deterministic, capped command.
            let mut cmd = tokio::process::Command::new(&cli);
            cmd.arg("--offline")
                .arg("--model").arg(&model)
                .arg("--prompt").arg(&prompt)
                .arg("--predict").arg(predict.to_string())
                .arg("--ctx-size").arg(ctx.to_string())
                .arg("--batch-size").arg("64")
                .arg("--ubatch-size").arg("64")
                .arg("--temp").arg("0")
                .arg("--seed").arg("0")
                .arg("--single-turn")
                .arg("--simple-io")
                .arg("--no-display-prompt")
                .arg("--no-mmap")
                .arg("--log-disable")
                .stdout(Stdio::piped())
                .stderr(Stdio::null());
            // env_clear + allowlist + denylist + kill_on_drop + process_group.
            crate::security::harden_cli_subprocess(&mut cmd);

            let mut child = match cmd.spawn() {
                Ok(child) => child,
                Err(error) => {
                    yield Err(AgentError::Provider(format!(
                        "gguf_llama_cli spawn failed ({}): {error}",
                        cli.display()
                    )));
                    return;
                }
            };

            let stdout = match child.stdout.take() {
                Some(stdout) => stdout,
                None => {
                    yield Err(AgentError::Provider(
                        "gguf_llama_cli produced no stdout pipe".to_string(),
                    ));
                    return;
                }
            };

            let mut lines = BufReader::new(stdout).lines();
            let mut output_token_estimate: u32 = 0;
            loop {
                match lines.next_line().await {
                    Ok(Some(line)) => {
                        output_token_estimate =
                            output_token_estimate.saturating_add(line.split_whitespace().count() as u32);
                        // STREAM EVERYTHING: forward each line as it arrives.
                        yield Ok(StreamEvent::TextDelta {
                            index: 0,
                            text: format!("{line}\n"),
                        });
                    }
                    Ok(None) => break,
                    Err(error) => {
                        yield Err(AgentError::StreamError(error.to_string()));
                        break;
                    }
                }
            }

            let _ = child.wait().await;

            yield Ok(StreamEvent::MessageStop {
                stop_reason: StopReason::EndTurn,
                usage: TokenUsage {
                    input_tokens: 0,
                    output_tokens: output_token_estimate,
                    cache_creation_input_tokens: 0,
                    cache_read_input_tokens: 0,
                },
            });
        };

        Ok(Box::pin(s))
    }

    async fn compact(&self, messages: &[Message]) -> Result<Vec<Message>, AgentError> {
        // No remote compaction for a local one-shot CLI; preserve history.
        Ok(messages.to_vec())
    }

    fn capabilities(&self) -> ProviderCapabilities {
        ProviderCapabilities {
            max_context_tokens: self.ctx_size as usize,
            max_output_tokens: self.max_output_tokens as usize,
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
        "gguf_llama_cli"
    }

    fn runtime(&self) -> ProviderRuntime {
        // On-device: the agent loop must refuse to start (Gemma stays non-agent).
        ProviderRuntime::Local
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn name_and_runtime_are_local_gguf() {
        let provider = GgufCliProvider::new("/tmp/does-not-exist.gguf");
        assert_eq!(provider.name(), "gguf_llama_cli");
        assert_eq!(provider.runtime(), ProviderRuntime::Local);
        assert!(provider.capabilities().supports_streaming);
        assert!(!provider.capabilities().supports_mcp);
    }

    #[test]
    fn build_prompt_uses_last_user_turn_and_system() {
        let messages = vec![
            Message::user_text("first"),
            Message::Assistant { content: vec![] },
            Message::user_text("write a function"),
        ];
        let prompt = GgufCliProvider::build_prompt(&messages, Some("You are terse."));
        assert!(prompt.contains("You are terse."));
        assert!(prompt.contains("write a function"));
        assert!(!prompt.contains("first")); // only the most recent user turn
    }

    #[test]
    fn build_prompt_without_system_is_just_user_text() {
        let messages = vec![Message::user_text("hello")];
        let prompt = GgufCliProvider::build_prompt(&messages, None);
        assert_eq!(prompt, "hello");
    }
}
