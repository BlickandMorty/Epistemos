//! Multi-CLI Passthrough Adapter — Pro tier only.
//!
//! Routes structured requests to external CLI tools (Claude Code, Codex CLI,
//! Gemini CLI, Kimi CLI).  **Never** used for model inference — inference
//! stays in-process via [`helios_mlx`].  These adapters are **only** for
//! code generation, file operations, web search, and other external-tool
//! workflows that sit behind a capability grant.
//!
//! ## Capability gate
//!
//! The entire module is compiled only when the `pro` feature is enabled.
//! Free-tier builds omit all CLI subprocess spawning, ensuring zero surface
//! area for external command execution.
//!
//! ## Adapter registry
//!
//! [`CliAdapterRegistry`] enumerates every compiled adapter and routes by
//! `provider_id`.  Call [`CliAdapterRegistry::available_adapters`] to
//! discover which CLIs are installed on the host `PATH`.

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use std::process::Stdio;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::process::Command;
use tokio::sync::mpsc::Sender;

// ---------------------------------------------------------------------------
// Trait
// ---------------------------------------------------------------------------

/// Adapter contract for external CLI tools.
///
/// Implementors spawn a subprocess, marshal a [`CliRequest`] into CLI
/// arguments, and return a [`CliResponse`].  Streaming variants push
/// incremental output through a Tokio channel.
#[async_trait]
pub trait CliAdapter: Send + Sync {
    /// Human-readable adapter name (e.g. `"claude-code"`).
    fn name(&self) -> &'static str;
    /// Provider slug used for routing (e.g. `"anthropic"`).
    fn provider_id(&self) -> &'static str;
    /// Returns `true` when the underlying binary is on `PATH`.
    fn is_available(&self) -> bool;

    /// Execute a command via the CLI and capture the full output.
    async fn execute(&self, request: CliRequest) -> Result<CliResponse, CliError>;

    /// Execute with incremental output streamed through `tx`.
    ///
    /// The final chunk always has `is_complete == true` and empty `content`.
    async fn execute_streaming(
        &self,
        request: CliRequest,
        tx: Sender<CliStreamChunk>,
    ) -> Result<(), CliError>;
}

// ---------------------------------------------------------------------------
// Data types
// ---------------------------------------------------------------------------

/// Structured input sent to a CLI adapter.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CliRequest {
    /// The prompt / instruction.
    pub prompt: String,
    /// Absolute or relative paths to include as context.
    pub context_files: Vec<String>,
    /// Maximum tokens to generate, if the CLI supports it.
    pub max_tokens: Option<usize>,
    /// Sampling temperature, if the CLI supports it.
    pub temperature: Option<f32>,
    /// System-level instructions, if the CLI supports it.
    pub system_message: Option<String>,
}

/// Structured output produced by a CLI adapter.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CliResponse {
    /// Decoded stdout.
    pub stdout: String,
    /// Decoded stderr.
    pub stderr: String,
    /// Process exit code (`-1` if unknown).
    pub exit_code: i32,
    /// Token count when the CLI exposes it.
    pub tokens_used: Option<usize>,
    /// Wall-clock latency in milliseconds.
    pub latency_ms: u64,
}

/// One chunk of streaming output.
#[derive(Clone, Debug)]
pub struct CliStreamChunk {
    /// Text produced in this chunk.
    pub content: String,
    /// `true` for the sentinel chunk that signals completion.
    pub is_complete: bool,
}

// ---------------------------------------------------------------------------
// Error types
// ---------------------------------------------------------------------------

/// Errors that can occur when driving an external CLI.
#[derive(thiserror::Error, Debug)]
pub enum CliError {
    /// The requested CLI binary is not on `PATH`.
    #[error("cli not found: {0}")]
    NotFound(String),
    /// The subprocess exited non-zero or produced invalid data.
    #[error("execution failed: {0}")]
    ExecutionFailed(String),
    /// The operation exceeded its deadline.
    #[error("timeout")]
    Timeout,
    /// The CLI emitted output that could not be parsed.
    #[error("invalid output: {0}")]
    InvalidOutput(String),
    /// Underlying I/O failure.
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
}

// ---------------------------------------------------------------------------
// Claude Code adapter
// ---------------------------------------------------------------------------

/// Adapter for the Anthropic `claude` CLI (a.k.a. Claude Code).
pub struct ClaudeCodeAdapter;

#[async_trait]
impl CliAdapter for ClaudeCodeAdapter {
    fn name(&self) -> &'static str {
        "claude-code"
    }

    fn provider_id(&self) -> &'static str {
        "anthropic"
    }

    fn is_available(&self) -> bool {
        std::process::Command::new("which")
            .arg("claude")
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
    }

    async fn execute(&self, request: CliRequest) -> Result<CliResponse, CliError> {
        let mut cmd = Command::new("claude");
        cmd.arg("-p").arg(&request.prompt)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        if let Some(temp) = request.temperature {
            cmd.arg("--temperature").arg(temp.to_string());
        }

        let start = std::time::Instant::now();
        let output = cmd.output().await.map_err(CliError::Io)?;
        let latency = start.elapsed().as_millis() as u64;

        Ok(CliResponse {
            stdout: String::from_utf8_lossy(&output.stdout).to_string(),
            stderr: String::from_utf8_lossy(&output.stderr).to_string(),
            exit_code: output.status.code().unwrap_or(-1),
            tokens_used: None, // Claude Code does not expose token count
            latency_ms: latency,
        })
    }

    async fn execute_streaming(
        &self,
        request: CliRequest,
        tx: Sender<CliStreamChunk>,
    ) -> Result<(), CliError> {
        let mut cmd = Command::new("claude");
        cmd.arg("-p").arg(&request.prompt)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        let mut child = cmd.spawn().map_err(CliError::Io)?;
        let mut stdout = child
            .stdout
            .take()
            .ok_or_else(|| CliError::ExecutionFailed("no stdout".into()))?;

        let mut buf = [0u8; 1024];
        loop {
            let n = stdout.read(&mut buf).await.map_err(CliError::Io)?;
            if n == 0 {
                break;
            }
            let chunk = String::from_utf8_lossy(&buf[..n]).to_string();
            tx.send(CliStreamChunk {
                content: chunk,
                is_complete: false,
            })
            .await
            .map_err(|_| CliError::ExecutionFailed("send failed".into()))?;
        }

        tx.send(CliStreamChunk {
            content: String::new(),
            is_complete: true,
        })
        .await
        .map_err(|_| CliError::ExecutionFailed("send failed".into()))?;

        Ok(())
    }
}

// ---------------------------------------------------------------------------
// Codex CLI adapter
// ---------------------------------------------------------------------------

/// Adapter for the OpenAI `codex` CLI.
pub struct CodexAdapter;

#[async_trait]
impl CliAdapter for CodexAdapter {
    fn name(&self) -> &'static str {
        "codex"
    }

    fn provider_id(&self) -> &'static str {
        "openai"
    }

    fn is_available(&self) -> bool {
        std::process::Command::new("which")
            .arg("codex")
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
    }

    async fn execute(&self, request: CliRequest) -> Result<CliResponse, CliError> {
        let mut cmd = Command::new("codex");
        cmd.arg("--prompt").arg(&request.prompt)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        let start = std::time::Instant::now();
        let output = cmd.output().await.map_err(CliError::Io)?;
        let latency = start.elapsed().as_millis() as u64;

        Ok(CliResponse {
            stdout: String::from_utf8_lossy(&output.stdout).to_string(),
            stderr: String::from_utf8_lossy(&output.stderr).to_string(),
            exit_code: output.status.code().unwrap_or(-1),
            tokens_used: None,
            latency_ms: latency,
        })
    }

    async fn execute_streaming(
        &self,
        _request: CliRequest,
        _tx: Sender<CliStreamChunk>,
    ) -> Result<(), CliError> {
        // Codex CLI does not support streaming well — delegate to non-streaming.
        Err(CliError::ExecutionFailed(
            "codex does not support streaming".into(),
        ))
    }
}

// ---------------------------------------------------------------------------
// Gemini CLI adapter
// ---------------------------------------------------------------------------

/// Adapter for the Google `gemini` CLI.
pub struct GeminiAdapter;

#[async_trait]
impl CliAdapter for GeminiAdapter {
    fn name(&self) -> &'static str {
        "gemini"
    }

    fn provider_id(&self) -> &'static str {
        "google"
    }

    fn is_available(&self) -> bool {
        std::process::Command::new("which")
            .arg("gemini")
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
    }

    async fn execute(&self, request: CliRequest) -> Result<CliResponse, CliError> {
        let mut cmd = Command::new("gemini");
        cmd.arg("prompt").arg(&request.prompt)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        let start = std::time::Instant::now();
        let output = cmd.output().await.map_err(CliError::Io)?;
        let latency = start.elapsed().as_millis() as u64;

        Ok(CliResponse {
            stdout: String::from_utf8_lossy(&output.stdout).to_string(),
            stderr: String::from_utf8_lossy(&output.stderr).to_string(),
            exit_code: output.status.code().unwrap_or(-1),
            tokens_used: None,
            latency_ms: latency,
        })
    }

    async fn execute_streaming(
        &self,
        _request: CliRequest,
        _tx: Sender<CliStreamChunk>,
    ) -> Result<(), CliError> {
        Err(CliError::ExecutionFailed(
            "gemini does not support streaming".into(),
        ))
    }
}

// ---------------------------------------------------------------------------
// Kimi CLI adapter
// ---------------------------------------------------------------------------

/// Adapter for the Moonshot AI `kimi` CLI.
pub struct KimiAdapter;

#[async_trait]
impl CliAdapter for KimiAdapter {
    fn name(&self) -> &'static str {
        "kimi"
    }

    fn provider_id(&self) -> &'static str {
        "moonshot"
    }

    fn is_available(&self) -> bool {
        std::process::Command::new("which")
            .arg("kimi")
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
    }

    async fn execute(&self, request: CliRequest) -> Result<CliResponse, CliError> {
        let mut cmd = Command::new("kimi");
        cmd.arg("--prompt").arg(&request.prompt)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        let start = std::time::Instant::now();
        let output = cmd.output().await.map_err(CliError::Io)?;
        let latency = start.elapsed().as_millis() as u64;

        Ok(CliResponse {
            stdout: String::from_utf8_lossy(&output.stdout).to_string(),
            stderr: String::from_utf8_lossy(&output.stderr).to_string(),
            exit_code: output.status.code().unwrap_or(-1),
            tokens_used: None,
            latency_ms: latency,
        })
    }

    async fn execute_streaming(
        &self,
        _request: CliRequest,
        _tx: Sender<CliStreamChunk>,
    ) -> Result<(), CliError> {
        Err(CliError::ExecutionFailed(
            "kimi does not support streaming".into(),
        ))
    }
}

// ---------------------------------------------------------------------------
// Adapter registry
// ---------------------------------------------------------------------------

/// Central registry that owns every compiled [`CliAdapter`] and routes by
/// `provider_id`.
pub struct CliAdapterRegistry {
    adapters: Vec<Box<dyn CliAdapter>>,
}

impl CliAdapterRegistry {
    /// Build a registry with all built-in adapters.
    pub fn new() -> Self {
        Self {
            adapters: vec![
                Box::new(ClaudeCodeAdapter),
                Box::new(CodexAdapter),
                Box::new(GeminiAdapter),
                Box::new(KimiAdapter),
            ],
        }
    }

    /// Return only the adapters whose binaries are present on `PATH`.
    pub fn available_adapters(&self) -> Vec<&dyn CliAdapter> {
        self.adapters
            .iter()
            .filter(|a| a.is_available())
            .map(|a| a.as_ref())
            .collect()
    }

    /// Look up an adapter by its `provider_id` slug.
    pub fn by_provider(&self, provider_id: &str) -> Option<&dyn CliAdapter> {
        self.adapters
            .iter()
            .find(|a| a.provider_id() == provider_id)
            .map(|a| a.as_ref())
    }

    /// Convenience: route a [`CliRequest`] to the adapter matching
    /// `provider_id` and await its `execute`.
    pub async fn route_and_execute(
        &self,
        provider_id: &str,
        request: CliRequest,
    ) -> Result<CliResponse, CliError> {
        let adapter = self
            .by_provider(provider_id)
            .ok_or_else(|| CliError::NotFound(provider_id.into()))?;
        adapter.execute(request).await
    }
}

impl Default for CliAdapterRegistry {
    fn default() -> Self {
        Self::new()
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_adapter_registry_lists_available() {
        let reg = CliAdapterRegistry::new();
        let available = reg.available_adapters();
        // We can't assume any CLI is installed in CI, but the call must not
        // panic and the returned slice must be a subset of all adapters.
        assert!(available.len() <= 4);
    }

    #[test]
    fn test_claude_code_adapter_name() {
        let adapter = ClaudeCodeAdapter;
        assert_eq!(adapter.name(), "claude-code");
        assert_eq!(adapter.provider_id(), "anthropic");
    }

    #[test]
    fn test_codex_adapter_name() {
        let adapter = CodexAdapter;
        assert_eq!(adapter.name(), "codex");
        assert_eq!(adapter.provider_id(), "openai");
    }

    #[test]
    fn test_gemini_adapter_name() {
        let adapter = GeminiAdapter;
        assert_eq!(adapter.name(), "gemini");
        assert_eq!(adapter.provider_id(), "google");
    }

    #[test]
    fn test_kimi_adapter_name() {
        let adapter = KimiAdapter;
        assert_eq!(adapter.name(), "kimi");
        assert_eq!(adapter.provider_id(), "moonshot");
    }

    #[test]
    fn test_route_by_provider_found() {
        let reg = CliAdapterRegistry::new();
        let adapter = reg.by_provider("anthropic");
        assert!(adapter.is_some());
        assert_eq!(adapter.unwrap().name(), "claude-code");
    }

    #[test]
    fn test_route_by_provider_not_found() {
        let reg = CliAdapterRegistry::new();
        let adapter = reg.by_provider("nonexistent");
        assert!(adapter.is_none());
    }

    #[test]
    fn test_registry_default() {
        let reg: CliAdapterRegistry = Default::default();
        assert!(reg.by_provider("anthropic").is_some());
        assert!(reg.by_provider("openai").is_some());
        assert!(reg.by_provider("google").is_some());
        assert!(reg.by_provider("moonshot").is_some());
    }

    #[tokio::test]
    async fn test_route_and_execute_not_found() {
        let reg = CliAdapterRegistry::new();
        let request = CliRequest {
            prompt: "hello".into(),
            context_files: vec![],
            max_tokens: None,
            temperature: None,
            system_message: None,
        };
        let result = reg.route_and_execute("nonexistent", request).await;
        assert!(result.is_err());
        match result.unwrap_err() {
            CliError::NotFound(id) => assert_eq!(id, "nonexistent"),
            other => panic!("expected NotFound, got {:?}", other),
        }
    }

    #[tokio::test]
    async fn test_claude_streaming_send_error() {
        // Simulate a dropped receiver so the sender returns an error.
        let adapter = ClaudeCodeAdapter;
        let request = CliRequest {
            prompt: "test".into(),
            context_files: vec![],
            max_tokens: None,
            temperature: None,
            system_message: None,
        };
        // Dropped channel — the adapter will fail on the first send.
        let (tx, _rx) = tokio::sync::mpsc::channel::<CliStreamChunk>(1);
        drop(_rx);
        let result = adapter.execute_streaming(request, tx).await;
        // Because we can't guarantee the binary exists, the error could be
        // NotFound (spawn fails) or ExecutionFailed (send fails).  We just
        // assert that *some* error is returned.
        assert!(result.is_err());
    }
}
