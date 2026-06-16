//! E2E harness witness for the on-device GGUF provider.
//!
//! Proves that `GgufCliProvider` — the exact code path the app's in-process
//! GGUF engine drives through the `run_local_gguf_generation` FFI — streams real
//! tokens from a GGUF model on disk via the hardened `llama-cli` subprocess.
//!
//! Skips cleanly (returns Ok) unless `EPISTEMOS_GGUF_E2E_MODEL` points at an
//! existing file, so CI — which has no multi-GB model — stays green. The whole
//! file is `#![cfg(feature = "pro-build")]`; the provider does not exist on MAS.
//!
//! Run locally:
//!   EPISTEMOS_GGUF_E2E_MODEL=~/Downloads/gemma-4-E2B_q4_0-it.gguf \
//!     cargo test --no-default-features --features pro-build \
//!     --test gguf_cli_provider_e2e -- --nocapture

#![cfg(feature = "pro-build")]

use agent_core::agent_loop::AgentConfig;
use agent_core::provider::{AgentProvider, ProviderRuntime, StreamEvent};
use agent_core::providers::gguf_cli::GgufCliProvider;
use agent_core::types::Message;
use futures::StreamExt;

/// Resolve the opt-in model path, expanding a leading `~/`. Returns `None` (skip)
/// when the env var is unset or the file is absent.
fn model_path_from_env() -> Option<std::path::PathBuf> {
    let raw = std::env::var("EPISTEMOS_GGUF_E2E_MODEL").ok()?;
    let expanded = if let Some(rest) = raw.strip_prefix("~/") {
        std::path::PathBuf::from(std::env::var("HOME").ok()?).join(rest)
    } else {
        std::path::PathBuf::from(raw)
    };
    expanded.exists().then_some(expanded)
}

#[tokio::test]
async fn gguf_cli_provider_streams_real_tokens() {
    let Some(model_path) = model_path_from_env() else {
        eprintln!(
            "[skip] set EPISTEMOS_GGUF_E2E_MODEL to an existing GGUF to run this e2e witness"
        );
        return;
    };

    let provider = GgufCliProvider::new(&model_path);
    // Honest-capability-gating: the GGUF provider is on-device, so the agent
    // loop must refuse it. This witnesses that invariant alongside generation.
    assert_eq!(
        provider.runtime(),
        ProviderRuntime::Local,
        "GGUF provider must report a Local runtime"
    );

    let mut config = AgentConfig::default();
    config.max_output_tokens = Some(24);
    config.system_prompt = Some("You are terse.".to_string());

    let messages = vec![Message::user_text("Reply with the single word: ready")];
    let mut stream = provider
        .stream_message(&messages, &[], &config)
        .await
        .expect("stream_message should start the llama-cli subprocess");

    let mut text = String::new();
    let mut saw_stop = false;
    while let Some(event) = stream.next().await {
        match event.expect("each stream event should be Ok") {
            StreamEvent::TextDelta { text: delta, .. } => text.push_str(&delta),
            StreamEvent::MessageStop { .. } => saw_stop = true,
            _ => {}
        }
    }

    eprintln!(
        "[gguf-e2e] model={} streamed {} chars: {:?}",
        model_path.display(),
        text.len(),
        text
    );
    assert!(saw_stop, "must receive a terminal MessageStop event");
    assert!(
        !text.trim().is_empty(),
        "GGUF provider must stream non-empty text from a real model"
    );
    // The provider must strip llama-cli's interactive REPL framing so only the
    // model's generation reaches the delegate.
    assert!(
        !text.contains("Loading model"),
        "banner 'Loading model' must be stripped: {text:?}"
    );
    assert!(
        !text.contains("available commands"),
        "command list must be stripped: {text:?}"
    );
    assert!(
        !text.contains("[ Prompt:"),
        "llama-cli stats footer must be stripped: {text:?}"
    );
    assert!(
        !text.contains("Exiting..."),
        "llama-cli exit line must be stripped: {text:?}"
    );
}
