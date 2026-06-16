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

/// What to do with one line of llama-cli stdout.
#[derive(Debug, PartialEq, Eq)]
enum FilterStep {
    /// Drop this line (banner / prompt echo / residual prompt marker).
    Skip,
    /// Forward this line as generated output.
    Emit,
    /// Terminal framing reached (stats footer / "Exiting..."); stop reading.
    Stop,
}

/// Stateful filter that strips llama-cli b9370's interactive REPL framing from
/// its stdout, leaving only the model's generation.
///
/// llama-cli b9370 is an interactive REPL (`-no-cnv` is rejected by this build):
/// on stdout it prints a "Loading model" line, an ASCII-art banner,
/// build/model info, an "available commands" block, the echoed prompt (after a
/// "> " marker), a "[ Prompt: ... ]" stats footer and "Exiting...". The state
/// machine skips the banner until the "> " prompt-echo marker, drops the echoed
/// prompt lines (matched against the known prompt set), then emits generation
/// until the stats footer. NOTE: format-coupled to this llama.cpp line; a
/// non-interactive binary would remove the need.
struct LlamaCliFramingFilter<'a> {
    prompt_line_set: &'a std::collections::HashSet<String>,
    emitting: bool,
    seen_prompt_marker: bool,
}

impl<'a> LlamaCliFramingFilter<'a> {
    fn new(prompt_line_set: &'a std::collections::HashSet<String>) -> Self {
        Self {
            prompt_line_set,
            emitting: false,
            seen_prompt_marker: false,
        }
    }

    fn step(&mut self, line: &str) -> FilterStep {
        let trimmed = line.trim();
        // Terminal framing: stop before the stats footer / exit line.
        if trimmed.starts_with("[ Prompt:") || trimmed == "Exiting..." {
            return FilterStep::Stop;
        }
        if !self.emitting {
            if !self.seen_prompt_marker {
                if trimmed.starts_with("> ") || trimmed == ">" {
                    self.seen_prompt_marker = true;
                }
                return FilterStep::Skip; // banner / preamble
            }
            // Past the marker: drop the echoed prompt (we know it) plus blank /
            // residual "> " lines.
            if trimmed.is_empty()
                || trimmed.starts_with("> ")
                || self.prompt_line_set.contains(trimmed)
            {
                return FilterStep::Skip;
            }
            self.emitting = true; // first real generated line
        }
        if trimmed == ">" {
            return FilterStep::Skip; // trailing interactive prompt
        }
        FilterStep::Emit
    }
}

/// A Pro-only on-device provider that runs a local GGUF model through the
/// hardened `llama-cli` subprocess. Never reachable on the MAS build.
pub struct GgufCliProvider {
    model_path: PathBuf,
    llama_cli_path: PathBuf,
    ctx_size: u32,
    max_output_tokens: u32,
    temperature: f32,
    /// Optional JSON Schema to constrain generation. When set, the provider
    /// passes `--json-schema <schema>` to llama-cli, which uses GBNF
    /// grammar-constrained decoding to GUARANTEE the output is structurally
    /// valid against the schema. This is the honest path to reliable local
    /// tool calling: a model whose free-form tool-call output is malformed
    /// (e.g. Gemma 4, which doesn't speak the `<tool_call>` XML grammar) is
    /// forced at the sampler level to emit valid tool-call JSON. Real
    /// capability via decoding constraints, NOT a faked capability badge.
    json_schema: Option<String>,
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
            // Default 0.0 == greedy/deterministic, matching the owner-approval
            // gate's witnessed command card. Chat callers raise it per reasoning
            // mode via `with_temperature`.
            temperature: 0.0,
            json_schema: None,
        }
    }

    /// Constrain generation to a JSON Schema via llama-cli `--json-schema`.
    /// An empty / whitespace-only schema is treated as "no constraint".
    pub fn with_json_schema(mut self, schema: impl Into<String>) -> Self {
        let schema = schema.into();
        self.json_schema = if schema.trim().is_empty() {
            None
        } else {
            Some(schema)
        };
        self
    }

    /// The extra llama-cli args that apply the JSON-schema constraint, or an
    /// empty vec when unconstrained. Split out as a pure function so the arg
    /// wiring is unit-testable without spawning a subprocess.
    fn constrained_args(&self) -> Vec<String> {
        match &self.json_schema {
            Some(schema) => vec!["--json-schema".to_string(), schema.clone()],
            None => Vec::new(),
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

    /// Set the sampling temperature. 0.0 is greedy/deterministic (the gate
    /// default + witness). Negative values are clamped to 0.0.
    pub fn with_temperature(mut self, temperature: f32) -> Self {
        self.temperature = if temperature.is_finite() && temperature > 0.0 {
            temperature
        } else {
            0.0
        };
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
        let temperature = self.temperature;
        // JSON-schema constraint args (empty when unconstrained). Captured here
        // so the `stream!` block below can move them in alongside the model/cli.
        let constrained_args = self.constrained_args();
        // Trimmed, non-empty lines of the prompt we send, so the banner strip
        // below can drop llama-cli's echo of the prompt without depending on its
        // exact reformatting.
        let prompt_line_set: std::collections::HashSet<String> = prompt
            .lines()
            .map(|line| line.trim().to_string())
            .filter(|line| !line.is_empty())
            .collect();

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
                .arg("--temp").arg(format!("{temperature}"))
                .arg("--seed").arg("0")
                // Grammar-constrained decoding (empty when unconstrained):
                // forces structurally-valid JSON for honest local tool calls.
                .args(&constrained_args)
                .arg("--single-turn")
                .arg("--simple-io")
                .arg("--no-display-prompt")
                // mmap (default) lazily pages the weights in — much faster to
                // "get going" than --no-mmap (which read the whole 7GB model
                // into RAM upfront), and gentler on a 16GB Mac since the OS can
                // evict clean pages. The deeper latency win (a warm/persistent
                // process instead of a one-shot reload per turn) rides on the
                // local-server work.
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
            // Strip llama-cli's interactive REPL framing (see LlamaCliFramingFilter).
            let mut filter = LlamaCliFramingFilter::new(&prompt_line_set);
            loop {
                match lines.next_line().await {
                    Ok(Some(line)) => match filter.step(&line) {
                        FilterStep::Stop => break,
                        FilterStep::Skip => continue,
                        FilterStep::Emit => {
                            output_token_estimate = output_token_estimate
                                .saturating_add(line.split_whitespace().count() as u32);
                            // STREAM EVERYTHING: forward each generated line as it arrives.
                            yield Ok(StreamEvent::TextDelta {
                                index: 0,
                                text: format!("{line}\n"),
                            });
                        }
                    },
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

    fn prompt_set(prompt: &str) -> std::collections::HashSet<String> {
        prompt
            .lines()
            .map(|line| line.trim().to_string())
            .filter(|line| !line.is_empty())
            .collect()
    }

    #[test]
    fn framing_filter_strips_banner_prompt_echo_and_footer() {
        // Mirrors real llama-cli b9370 stdout (see runtime_receipts).
        let set = prompt_set("You are terse.\n\nReply with the single word: ready");
        let stdout = [
            "",
            "Loading model... ",
            "▄▄ ▄▄",
            "build      : b9370-aa50b2c2a",
            "model      : gemma-4-E2B_q4_0-it.gguf",
            "available commands:",
            "  /exit or Ctrl+C     stop or exit",
            "  /glob <pattern>     add text files using globbing pattern",
            "",
            "> You are terse.",
            "",
            "Reply with the single word: ready",
            "",
            "[Start thinking]",
            "Thinking Process:",
            "ready",
            "[ Prompt: 331.4 t/s | Generation: 81.8 t/s ]",
            "> ",
            "Exiting...",
        ];
        let mut filter = LlamaCliFramingFilter::new(&set);
        let mut emitted = Vec::new();
        for line in stdout {
            match filter.step(line) {
                FilterStep::Stop => break,
                FilterStep::Skip => {}
                FilterStep::Emit => emitted.push(line),
            }
        }
        assert_eq!(emitted, vec!["[Start thinking]", "Thinking Process:", "ready"]);
        let joined = emitted.join("\n");
        assert!(!joined.contains("Loading model"));
        assert!(!joined.contains("available commands"));
        assert!(!joined.contains("[ Prompt:"));
        assert!(!joined.contains("You are terse."));
    }

    #[test]
    fn framing_filter_skips_everything_before_prompt_marker() {
        let set = std::collections::HashSet::new();
        let mut filter = LlamaCliFramingFilter::new(&set);
        // With no "> " marker, all lines are preamble and are skipped.
        assert_eq!(filter.step("Loading model..."), FilterStep::Skip);
        assert_eq!(filter.step("build : x"), FilterStep::Skip);
        assert_eq!(filter.step("plain text"), FilterStep::Skip);
    }

    #[test]
    fn framing_filter_emits_after_marker_and_stops_at_footer() {
        let set = std::collections::HashSet::new();
        let mut filter = LlamaCliFramingFilter::new(&set);
        assert_eq!(filter.step("> hi"), FilterStep::Skip); // prompt-echo marker
        assert_eq!(filter.step("generated line"), FilterStep::Emit);
        assert_eq!(filter.step("more"), FilterStep::Emit);
        assert_eq!(filter.step("[ Prompt: 1 t/s ]"), FilterStep::Stop);
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

    #[test]
    fn unconstrained_provider_emits_no_schema_args() {
        let provider = GgufCliProvider::new("/tmp/model.gguf");
        assert!(provider.constrained_args().is_empty());
    }

    #[test]
    fn with_json_schema_emits_json_schema_arg() {
        let schema = r#"{"type":"object","properties":{"name":{"type":"string"}}}"#;
        let provider = GgufCliProvider::new("/tmp/model.gguf").with_json_schema(schema);
        let args = provider.constrained_args();
        assert_eq!(args.len(), 2);
        assert_eq!(args[0], "--json-schema");
        assert_eq!(args[1], schema);
    }

    #[test]
    fn empty_or_blank_json_schema_is_treated_as_unconstrained() {
        // Defensive: an empty/whitespace schema must NOT pass a broken
        // `--json-schema ""` to llama-cli (which would error or match nothing).
        for blank in ["", "   ", "\n\t "] {
            let provider = GgufCliProvider::new("/tmp/model.gguf").with_json_schema(blank);
            assert!(
                provider.constrained_args().is_empty(),
                "blank schema {blank:?} must be unconstrained"
            );
        }
    }
}
