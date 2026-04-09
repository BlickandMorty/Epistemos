use std::collections::HashMap;
use std::sync::Arc;

use crate::agent_loop::{
    run_agent_loop, AgentConfig, AgentError, Effort, PermissionConfig,
};
use crate::credential_pool::CredentialManager;
use crate::error::HttpStatusError;
use crate::provider::AgentProvider;
use crate::providers::claude::ClaudeProvider;
use crate::providers::gemini::GeminiProvider;
use crate::providers::openai::OpenAIProvider;
use crate::providers::openai_compatible::OpenAICompatibleProvider;
use crate::providers::perplexity::PerplexityProvider;
use crate::routing::{CloudProvider, ConfidenceRouter, RoutingDecision};
use crate::session::GlobalSessions;
use crate::session_persistence::SessionPersistence;
use crate::shared_memory::{ShmPool, ShmReference};
use crate::storage::memory_classifier::{classify_memory_operation, MemoryOperation, VaultFact};
use crate::storage::memory_decay::{batch_decay, collect_garbage, Importance, NodeStrength};
use crate::storage::vault::VaultStore;
use crate::tools::registry::ToolRegistry;

// MARK: - FFI Safety Boundary
//
// SAFETY: agent_core uses `panic = "unwind"` in release (unlike other crates)
// specifically so that catch_unwind can intercept panics at the FFI boundary
// and return typed errors to Swift instead of aborting the macOS process.
//
// Every #[uniffi::export] function returning Result MUST use ffi_guard!.
// Functions returning non-Result types (u32, void) are protected by UniFFI's
// own panic handler under unwind semantics.

/// Extract a human-readable message from a panic payload.
/// Uses `std::mem::forget` on the payload after extraction to prevent
/// re-panicking from Drop implementations on the payload.
fn panic_payload_to_string(payload: Box<dyn std::any::Any + Send>) -> String {
    let msg = if let Some(s) = payload.downcast_ref::<&str>() {
        (*s).to_string()
    } else if let Some(s) = payload.downcast_ref::<String>() {
        s.clone()
    } else {
        "unknown panic".to_string()
    };
    // SAFETY: Prevent potential re-panic from Drop on the payload.
    std::mem::forget(payload);
    msg
}

/// Guard for synchronous FFI entry points returning Result<T, AgentErrorFFI>.
/// Wraps the body in catch_unwind and maps panics to AgentErrorFFI.
macro_rules! ffi_guard_sync {
    ($body:expr) => {{
        match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| $body)) {
            Ok(v) => v,
            Err(payload) => {
                let msg = panic_payload_to_string(payload);
                tracing::error!("[ffi] PANIC at bridge boundary: {}", msg);
                Err(AgentErrorFFI::AgentError {
                    message: format!("Rust panic: {}", msg),
                })
            }
        }
    }};
}

/// Guard for synchronous FFI entry points returning a non-Result value.
/// Wraps the body in catch_unwind and returns a safe default on panic.
macro_rules! ffi_guard_value {
    ($body:expr, $default:expr) => {{
        match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| $body)) {
            Ok(v) => v,
            Err(payload) => {
                let msg = panic_payload_to_string(payload);
                tracing::error!("[ffi] PANIC at bridge boundary: {}", msg);
                $default
            }
        }
    }};
}

#[uniffi::export(callback_interface)]
pub trait AgentEventDelegate: Send + Sync {
    fn on_thinking_delta(&self, thought: String);
    fn on_text_delta(&self, delta: String);
    fn on_tool_input_delta(&self, index: u32, partial_json: String);
    fn on_tool_started(&self, tool_use_id: String, name: String, input_json: String);
    fn on_tool_completed(&self, tool_use_id: String, result: String, is_error: bool);
    fn on_subagent_spawned(&self, agent_id: String, role: String);
    fn on_permission_required(
        &self,
        permission_id: String,
        tool_name: String,
        input_json: String,
        risk_level: String,
    );
    fn on_context_compacting(&self, current_tokens: u32);
    fn on_context_compacted(&self, new_message_count: u32);
    fn on_turn_started(&self, turn_number: u32, message_count: u32);
    fn on_complete(&self, stop_reason: String, input_tokens: u32, output_tokens: u32);
    fn on_error(&self, message: String);
    fn wait_for_permission(&self, permission_id: String) -> bool;
    /// Called when the agent needs user clarification (via the clarify tool).
    /// `question` is the clarification question, `options_json` is a JSON array of suggested answers.
    /// Returns the user's response text.
    fn on_clarification_needed(&self, question: String, options_json: String) -> String;
    /// Called when the current provider has failed and all retries/credential rotations
    /// are exhausted. Swift uses TriageService to recommend a fallback provider.
    /// Returns provider name (e.g., "claude_sonnet", "openai", "apple_intelligence")
    /// or empty string if no fallback is available.
    fn on_provider_failed(
        &self,
        failed_provider: String,
        reason: String,
        token_count: u32,
    ) -> String;
}

#[derive(uniffi::Record)]
pub struct ToolConfig {
    pub vault_path: String,
    pub enable_bash: bool,
    pub enable_web_search: bool,
}

#[derive(uniffi::Record)]
pub struct AgentConfigFFI {
    pub max_turns: u32,
    pub max_output_tokens: u32,
    pub context_threshold: u32,
    pub enable_thinking: bool,
    pub effort: String,
    pub system_prompt: Option<String>,
    pub auto_approve_reads: bool,
    pub auto_approve_writes: bool,
}

#[derive(uniffi::Record)]
pub struct AgentResultFFI {
    pub turns: u32,
    pub input_tokens: u32,
    pub output_tokens: u32,
}

#[derive(uniffi::Record, Debug, Clone, PartialEq, Eq)]
pub struct ProviderRoutePreviewFFI {
    pub requested_provider: String,
    pub resolution_kind: String,
    pub effective_provider: String,
    pub routing_summary: String,
    pub supported: bool,
}

#[derive(uniffi::Error, thiserror::Error, Debug)]
pub enum AgentErrorFFI {
    #[error("{message}")]
    AgentError { message: String },
}

impl AgentConfig {
    pub fn from_ffi(ffi: &AgentConfigFFI) -> Self {
        let effort = match ffi.effort.as_str() {
            "low" => Effort::Low,
            "medium" => Effort::Medium,
            "high" => Effort::High,
            "max" => Effort::Max,
            _ => Effort::High,
        };

        Self {
            system_prompt: ffi.system_prompt.clone(),
            max_turns: Some(ffi.max_turns),
            max_output_tokens: Some(ffi.max_output_tokens),
            context_threshold: ffi.context_threshold as usize,
            enable_thinking: ffi.enable_thinking,
            effort,
            enable_web_search: false,
            enable_web_fetch: false,
            enable_code_execution: false,
            enable_computer_use: true,
            mcp_servers: None,
            parallel_tool_execution: true,
            permissions: PermissionConfig {
                auto_approve_read_only: ffi.auto_approve_reads,
                auto_approve_modification: ffi.auto_approve_writes,
                auto_approve_destructive: false,
            },
        }
    }
}

impl HttpStatusError for AgentError {
    fn http_status(&self) -> Option<u16> {
        match self {
            AgentError::ApiError { status, .. } => Some(*status),
            _ => None,
        }
    }

    fn retry_after_header(&self) -> Option<String> {
        None
    }
}

fn preview(
    requested_provider: &str,
    resolution_kind: &str,
    effective_provider: &str,
    routing_summary: impl Into<String>,
    supported: bool,
) -> ProviderRoutePreviewFFI {
    ProviderRoutePreviewFFI {
        requested_provider: requested_provider.to_string(),
        resolution_kind: resolution_kind.to_string(),
        effective_provider: effective_provider.to_string(),
        routing_summary: routing_summary.into(),
        supported,
    }
}

fn cloud_provider_name(provider: CloudProvider) -> &'static str {
    match provider {
        CloudProvider::ClaudeHaiku => "claude_haiku",
        CloudProvider::ClaudeSonnet => "claude_sonnet",
        CloudProvider::ClaudeOpus => "claude_opus",
        CloudProvider::GeminiFlash => "gemini_flash",
        CloudProvider::GeminiPro => "gemini_pro",
        CloudProvider::Perplexity => "perplexity",
        CloudProvider::OpenAI => "openai",
    }
}

fn resolve_provider_selection_preview(
    objective: &str,
    provider_name: &str,
) -> ProviderRoutePreviewFFI {
    let requested = provider_name.trim();
    match requested {
        "claude_sonnet" | "claude_opus" | "claude_haiku"
        | "openai" | "openai_gpt4o" | "openai_gpt4o_mini" | "openai_o1" | "openai_o3_mini" => preview(
            requested,
            "forced",
            requested,
            format!("Explicit provider override: {requested}"),
            true,
        ),
        "" | "auto" => match ConfidenceRouter::default().route(objective) {
            RoutingDecision::Cloud(provider, config) => {
                let effective_provider = cloud_provider_name(provider);
                let supported = matches!(
                    provider,
                    CloudProvider::ClaudeHaiku
                        | CloudProvider::ClaudeSonnet
                        | CloudProvider::ClaudeOpus
                        | CloudProvider::GeminiFlash
                        | CloudProvider::GeminiPro
                        | CloudProvider::Perplexity
                        | CloudProvider::OpenAI
                );
                preview(
                    requested,
                    "auto_cloud",
                    effective_provider,
                    format!(
                        "ConfidenceRouter selected {effective_provider} for a cloud task (effort={}, web_search={}, code_execution={}).",
                        config.effort, config.enable_web_search, config.enable_code_execution
                    ),
                    supported,
                )
            }
            RoutingDecision::LocalWithFallback { fallback, .. } => {
                let effective_provider = cloud_provider_name(fallback);
                let supported = matches!(
                    fallback,
                    CloudProvider::ClaudeHaiku | CloudProvider::ClaudeSonnet | CloudProvider::ClaudeOpus
                        | CloudProvider::GeminiFlash | CloudProvider::GeminiPro
                );
                preview(
                    requested,
                    "auto_local_fallback",
                    effective_provider,
                    format!(
                        "ConfidenceRouter selected a local-first task, but the Rust bridge currently exposes only cloud providers. Using fallback {effective_provider}."
                    ),
                    supported,
                )
            }
            RoutingDecision::Local(local_task) => preview(
                requested,
                "auto_local_only",
                "",
                format!(
                    "ConfidenceRouter selected a local-only task ({local_task:?}), but local providers are not wired into agent_core yet."
                ),
                false,
            ),
        },
        other => preview(
            other,
            "forced_unknown",
            "",
            format!("Unknown provider override: {other}"),
            false,
        ),
    }
}

fn instantiate_provider(name: &str) -> Result<Arc<dyn AgentProvider>, AgentErrorFFI> {
    match name {
        // Anthropic Claude (native API)
        "claude_sonnet" => Ok(Arc::new(ClaudeProvider::sonnet())),
        "claude_opus" => Ok(Arc::new(ClaudeProvider::opus())),
        "claude_haiku" => Ok(Arc::new(ClaudeProvider::haiku())),
        // Google Gemini (native API)
        "gemini_flash" => Ok(Arc::new(GeminiProvider::flash())),
        "gemini_pro" => Ok(Arc::new(GeminiProvider::pro())),
        // Perplexity (native API)
        "perplexity" => Ok(Arc::new(PerplexityProvider::sonar_pro())),
        // OpenAI (native API)
        "openai" | "openai_gpt4o" => Ok(Arc::new(OpenAIProvider::gpt4o())),
        "openai_gpt4o_mini" => Ok(Arc::new(OpenAIProvider::gpt4o_mini())),
        "openai_o1" => Ok(Arc::new(OpenAIProvider::o1())),
        "openai_o3_mini" => Ok(Arc::new(OpenAIProvider::o3_mini())),
        // OpenRouter (200+ models via universal gateway)
        "openrouter" => Ok(Arc::new(OpenAICompatibleProvider::openrouter("anthropic/claude-sonnet-4"))),
        // Local providers (no API key needed)
        "ollama" => Ok(Arc::new(OpenAICompatibleProvider::ollama("llama3.3"))),
        "llama_cpp" => Ok(Arc::new(OpenAICompatibleProvider::llama_cpp("default"))),
        // Chinese AI providers
        "zai" | "glm" => Ok(Arc::new(OpenAICompatibleProvider::zai())),
        "kimi" | "kimi_coding" => Ok(Arc::new(OpenAICompatibleProvider::kimi_coding())),
        "deepseek" => Ok(Arc::new(OpenAICompatibleProvider::deepseek())),
        "minimax" => Ok(Arc::new(OpenAICompatibleProvider::minimax())),
        // Western AI providers
        "xai" | "grok" => Ok(Arc::new(OpenAICompatibleProvider::xai())),
        "mistral" => Ok(Arc::new(OpenAICompatibleProvider::mistral())),
        "groq" => Ok(Arc::new(OpenAICompatibleProvider::groq())),
        // HuggingFace (any model via Inference API)
        "huggingface" | "hf" => Ok(Arc::new(OpenAICompatibleProvider::huggingface("meta-llama/Llama-3.3-70B-Instruct"))),
        // Dynamic: provider_name/model format for OpenRouter + HuggingFace
        name if name.contains('/') => {
            // Auto-detect: openrouter/model or hf/model
            if name.starts_with("hf/") || name.starts_with("huggingface/") {
                let model = name.splitn(2, '/').nth(1).unwrap_or("meta-llama/Llama-3.3-70B-Instruct");
                Ok(Arc::new(OpenAICompatibleProvider::huggingface(model)))
            } else {
                // Default to OpenRouter for any provider/model format
                Ok(Arc::new(OpenAICompatibleProvider::openrouter(name)))
            }
        }
        _ => Err(AgentErrorFFI::AgentError {
            message: format!("Unsupported provider: {name}. Available: claude_sonnet, claude_opus, claude_haiku, gemini_flash, gemini_pro, perplexity, openai, openrouter, ollama, llama_cpp, zai, kimi, deepseek, minimax, xai, mistral, groq, huggingface, or any provider/model slug."),
        }),
    }
}

fn resolve_provider_for_session(
    objective: &str,
    provider_name: &str,
) -> Result<(Arc<dyn AgentProvider>, ProviderRoutePreviewFFI), AgentErrorFFI> {
    let preview = resolve_provider_selection_preview(objective, provider_name);
    if !preview.supported {
        return Err(AgentErrorFFI::AgentError {
            message: preview.routing_summary.clone(),
        });
    }

    let provider = instantiate_provider(&preview.effective_provider)?;
    Ok((provider, preview))
}

#[uniffi::export]
pub fn preview_provider_route(
    objective: String,
    provider_name: String,
) -> ProviderRoutePreviewFFI {
    ffi_guard_value!(
        resolve_provider_selection_preview(&objective, &provider_name),
        ProviderRoutePreviewFFI {
            requested_provider: provider_name,
            resolution_kind: "error".to_string(),
            effective_provider: String::new(),
            routing_summary: "Internal panic during route preview".to_string(),
            supported: false,
        }
    )
}

#[uniffi::export(async_runtime = "tokio")]
pub async fn run_agent_session(
    session_id: String,
    objective: String,
    provider_name: String,
    tool_config: ToolConfig,
    agent_config: AgentConfigFFI,
    delegate: Box<dyn AgentEventDelegate>,
    api_keys: HashMap<String, Vec<String>>,
) -> Result<AgentResultFFI, AgentErrorFFI> {
    // SAFETY: This is the primary agentic loop entry point. A panic anywhere
    // in the tool registry, HTTP streaming, compaction, or PTY execution would
    // previously abort the entire macOS process. With panic="unwind" and this
    // guard, panics are caught and returned as typed AgentErrorFFI to Swift.
    //
    // For async FFI: UniFFI's tokio runtime spawns this as a task. We use
    // tokio::task::spawn + JoinHandle to catch panics from the executor.
    let session_id_clone = session_id.clone();
    let handle = tokio::task::spawn(async move {
        run_agent_session_inner(
            session_id_clone, objective, provider_name,
            tool_config, agent_config, delegate, api_keys,
        ).await
    });

    match handle.await {
        Ok(result) => result,
        Err(join_error) => {
            // JoinError means the task panicked or was cancelled
            let msg = if join_error.is_panic() {
                let payload = join_error.into_panic();
                let msg = panic_payload_to_string(payload);
                tracing::error!("[ffi] PANIC in run_agent_session: {}", msg);
                format!("Rust panic in agent session: {}", msg)
            } else {
                "Agent session task cancelled".to_string()
            };
            // Clean up shared memory even on panic
            ShmPool::cleanup_session(&session_id);
            GlobalSessions::fail(&session_id, &msg);
            Err(AgentErrorFFI::AgentError { message: msg })
        }
    }
}

async fn run_agent_session_inner(
    session_id: String,
    objective: String,
    provider_name: String,
    tool_config: ToolConfig,
    agent_config: AgentConfigFFI,
    delegate: Box<dyn AgentEventDelegate>,
    api_keys: HashMap<String, Vec<String>>,
) -> Result<AgentResultFFI, AgentErrorFFI> {
    let (_guard, cancel) = GlobalSessions::register(&session_id);

    // Initialize the shared memory pool (idempotent)
    ShmPool::init();

    let (provider, _route_preview) = resolve_provider_for_session(&objective, &provider_name)?;

    let vault = VaultStore::open(&tool_config.vault_path).map_err(|error| AgentErrorFFI::AgentError {
        message: format!("Failed to open vault: {error}"),
    })?;
    let tool_registry = Arc::new(ToolRegistry::with_bash_enabled(
        Arc::new(vault),
        tool_config.enable_bash,
    ));
    let config = AgentConfig::from_ffi(&agent_config);
    let delegate: Arc<dyn AgentEventDelegate> = delegate.into();

    // ── Infrastructure: credential manager + session persistence ────
    let credential_manager = if api_keys.is_empty() {
        None
    } else {
        let cm = CredentialManager::new();
        for (provider, keys) in api_keys {
            cm.register_pool(&provider, keys);
        }
        Some(Arc::new(cm))
    };

    let session_persistence = match SessionPersistence::open(std::path::Path::new(&tool_config.vault_path)) {
        Ok(p) => Some(Arc::new(tokio::sync::Mutex::new(p))),
        Err(e) => {
            tracing::warn!("Failed to open session persistence: {}", e);
            None
        }
    };

    // Provider factory for fallback instantiation (P0.2 + P0.3)
    let provider_factory: Option<crate::agent_loop::ProviderFactory> = Some(Box::new(|name| {
        instantiate_provider(name).map_err(|e| AgentError::Provider(e.to_string()))
    }));

    let result = run_agent_loop(
        session_id.clone(), objective, provider, tool_registry, delegate, config, cancel,
        credential_manager, session_persistence, provider_factory,
    ).await;
    match result {
        Ok(result) => {
            // Clean up shared memory segments for this session
            ShmPool::cleanup_session(&session_id);
            GlobalSessions::complete(
                &session_id,
                result.turns,
                result.total_usage.input_tokens,
                result.total_usage.output_tokens,
            );
            Ok(AgentResultFFI {
                turns: result.turns,
                input_tokens: result.total_usage.input_tokens,
                output_tokens: result.total_usage.output_tokens,
            })
        }
        Err(error) => {
            // Clean up shared memory segments even on failure
            ShmPool::cleanup_session(&session_id);
            GlobalSessions::fail(&session_id, &error.to_string());
            Err(AgentErrorFFI::AgentError {
                message: error.to_string(),
            })
        }
    }
}

#[uniffi::export]
pub fn cancel_agent_session(session_id: String) {
    ffi_guard_value!(GlobalSessions::cancel(&session_id), ());
}

#[uniffi::export]
pub fn active_session_count() -> u32 {
    ffi_guard_value!(GlobalSessions::active_count() as u32, 0)
}

// MARK: - Persistent PTY FFI

#[derive(uniffi::Record)]
pub struct PtyConfigFFI {
    pub shell: String,
    pub initial_dir: Option<String>,
    pub cols: u16,
    pub rows: u16,
}

#[derive(uniffi::Record)]
pub struct PtyOutputFFI {
    pub stdout: String,
    pub exit_hint: String,
    pub working_dir: String,
    pub duration_ms: u64,
}

/// Spawn a persistent PTY shell session tied to the given agent session.
/// Returns a unique `pty_id` for subsequent `pty_execute` / `pty_close` calls.
#[uniffi::export(async_runtime = "tokio")]
pub async fn pty_spawn(
    session_id: String,
    config: PtyConfigFFI,
) -> Result<String, AgentErrorFFI> {
    let pty_config = crate::pty::PtyConfig {
        shell: config.shell,
        initial_dir: config.initial_dir,
        cols: config.cols,
        rows: config.rows,
    };
    let handle = tokio::task::spawn_blocking(move || {
        crate::pty::PtyPool::spawn(&session_id, pty_config)
    });
    match handle.await {
        Ok(Ok(pty_id)) => Ok(pty_id),
        Ok(Err(e)) => Err(AgentErrorFFI::AgentError { message: e.to_string() }),
        Err(join_error) => {
            // JoinError: task panicked or cancelled
            let msg = if join_error.is_panic() {
                let payload = join_error.into_panic();
                let msg = panic_payload_to_string(payload);
                tracing::error!("[ffi] PANIC in pty_spawn: {}", msg);
                format!("Rust panic in PTY spawn: {}", msg)
            } else {
                "PTY spawn task cancelled".to_string()
            };
            Err(AgentErrorFFI::AgentError { message: msg })
        }
    }
}

/// Execute a command in a persistent PTY session.
/// The shell state (working directory, env vars, aliases) persists between calls.
#[uniffi::export(async_runtime = "tokio")]
pub async fn pty_execute(
    pty_id: String,
    command: String,
    timeout_ms: u64,
) -> Result<PtyOutputFFI, AgentErrorFFI> {
    let timeout = std::time::Duration::from_millis(timeout_ms.min(120_000));
    let handle = tokio::task::spawn_blocking(move || {
        crate::pty::PtyPool::execute(&pty_id, &command, timeout)
    });
    let output = match handle.await {
        Ok(Ok(out)) => out,
        Ok(Err(e)) => return Err(AgentErrorFFI::AgentError { message: e.to_string() }),
        Err(join_error) => {
            let msg = if join_error.is_panic() {
                let payload = join_error.into_panic();
                let msg = panic_payload_to_string(payload);
                tracing::error!("[ffi] PANIC in pty_execute: {}", msg);
                format!("Rust panic in PTY execute: {}", msg)
            } else {
                "PTY execute task cancelled".to_string()
            };
            return Err(AgentErrorFFI::AgentError { message: msg });
        }
    };
    Ok(PtyOutputFFI {
        stdout: output.stdout,
        exit_hint: output.exit_hint,
        working_dir: output.working_dir,
        duration_ms: output.duration_ms,
    })
}

/// Close a persistent PTY session and terminate its child shell process.
#[uniffi::export]
pub fn pty_close(pty_id: String) {
    ffi_guard_value!(crate::pty::PtyPool::close(&pty_id), ());
}

/// Get the number of active PTY sessions (diagnostics).
#[uniffi::export]
pub fn pty_active_count() -> u32 {
    ffi_guard_value!(crate::pty::PtyPool::active_count() as u32, 0)
}

// MARK: - Living Vault FFI

#[derive(uniffi::Record)]
pub struct VaultFactFFI {
    pub file_path: String,
    pub section: String,
    pub content: String,
    pub strength: f64,
    pub last_accessed_epoch: f64,
}

#[derive(uniffi::Record)]
pub struct MemoryOperationFFI {
    /// One of: "ADD", "UPDATE", "DELETE", "NOOP"
    pub operation: String,
    pub target_file: Option<String>,
    pub target_section: Option<String>,
    pub reason: Option<String>,
}

impl From<MemoryOperation> for MemoryOperationFFI {
    fn from(op: MemoryOperation) -> Self {
        match op {
            MemoryOperation::Add => MemoryOperationFFI {
                operation: "ADD".to_string(),
                target_file: None,
                target_section: None,
                reason: None,
            },
            MemoryOperation::Update {
                target_file,
                target_section,
            } => MemoryOperationFFI {
                operation: "UPDATE".to_string(),
                target_file: Some(target_file),
                target_section: Some(target_section),
                reason: None,
            },
            MemoryOperation::Delete {
                target_file,
                target_section,
                reason,
            } => MemoryOperationFFI {
                operation: "DELETE".to_string(),
                target_file: Some(target_file),
                target_section: Some(target_section),
                reason: Some(reason),
            },
            MemoryOperation::Noop { reason } => MemoryOperationFFI {
                operation: "NOOP".to_string(),
                target_file: None,
                target_section: None,
                reason: Some(reason),
            },
        }
    }
}

/// Classify an incoming memory against existing vault facts.
/// Returns ADD/UPDATE/DELETE/NOOP.
#[uniffi::export]
pub fn classify_vault_memory(
    incoming: String,
    existing_facts: Vec<VaultFactFFI>,
) -> MemoryOperationFFI {
    ffi_guard_value!(
        {
            let facts: Vec<VaultFact> = existing_facts
                .into_iter()
                .map(|f| {
                    let last_accessed = chrono::DateTime::from_timestamp(f.last_accessed_epoch as i64, 0)
                        .unwrap_or_else(chrono::Utc::now);
                    VaultFact::new(f.file_path, f.section, f.content, f.strength, last_accessed)
                })
                .collect();
            classify_memory_operation(&incoming, &facts).into()
        },
        MemoryOperationFFI {
            operation: "NOOP".to_string(),
            target_file: None,
            target_section: None,
            reason: Some("Internal panic during classification".to_string()),
        }
    )
}

#[derive(uniffi::Record)]
pub struct NodeStrengthFFI {
    pub strength: f64,
    pub importance: String,
    pub decay_rate: f64,
    pub last_accessed_epoch: f64,
    pub access_count: u32,
    pub pinned: bool,
}

/// Apply Ebbinghaus decay to a batch of memory nodes.
/// Returns the updated strengths.
#[uniffi::export]
pub fn decay_memory_nodes(
    mut nodes: Vec<NodeStrengthFFI>,
    now_epoch: f64,
) -> Vec<NodeStrengthFFI> {
    ffi_guard_value!(
        {
            let now = chrono::DateTime::from_timestamp(now_epoch as i64, 0)
                .unwrap_or_else(chrono::Utc::now);
            let mut internal: Vec<NodeStrength> = nodes
                .drain(..)
                .map(|n| {
                    let importance = match n.importance.as_str() {
                        "critical" => Importance::Critical,
                        "high" => Importance::High,
                        "low" => Importance::Low,
                        _ => Importance::Normal,
                    };
                    let last_accessed = chrono::DateTime::from_timestamp(n.last_accessed_epoch as i64, 0)
                        .unwrap_or_else(chrono::Utc::now);
                    NodeStrength {
                        strength: n.strength,
                        importance,
                        decay_rate: n.decay_rate,
                        last_accessed,
                        access_count: n.access_count,
                        pinned: n.pinned,
                    }
                })
                .collect();

            batch_decay(&mut internal, now);

            internal
                .into_iter()
                .map(|n| NodeStrengthFFI {
                    strength: n.strength,
                    importance: match n.importance {
                        Importance::Critical => "critical".to_string(),
                        Importance::High => "high".to_string(),
                        Importance::Normal => "normal".to_string(),
                        Importance::Low => "low".to_string(),
                    },
                    decay_rate: n.decay_rate,
                    last_accessed_epoch: n.last_accessed.timestamp() as f64,
                    access_count: n.access_count,
                    pinned: n.pinned,
                })
                .collect()
        },
        Vec::new()
    )
}

/// Garbage-collect weak memory nodes below the threshold.
/// Returns the number of nodes removed.
#[uniffi::export]
pub fn gc_memory_nodes(
    nodes: Vec<NodeStrengthFFI>,
    threshold: f64,
) -> u32 {
    ffi_guard_value!(
    {
    let mut internal: Vec<NodeStrength> = nodes
        .into_iter()
        .map(|n| {
            let importance = match n.importance.as_str() {
                "critical" => Importance::Critical,
                "high" => Importance::High,
                "low" => Importance::Low,
                _ => Importance::Normal,
            };
            let last_accessed = chrono::DateTime::from_timestamp(n.last_accessed_epoch as i64, 0)
                .unwrap_or_else(chrono::Utc::now);
            NodeStrength {
                strength: n.strength,
                importance,
                decay_rate: n.decay_rate,
                last_accessed,
                access_count: n.access_count,
                pinned: n.pinned,
            }
        })
        .collect();

    let removed = collect_garbage(&mut internal, threshold);
    removed.len() as u32
    },
    0
    )
}

// MARK: - Shared Memory FFI

/// Read a payload from shared memory by its reference fields.
/// Returns the raw bytes as a UTF-8 string (for JSON/text payloads).
#[uniffi::export]
pub fn shm_read_payload(
    segment_name: String,
    byte_length: u64,
) -> Result<String, AgentErrorFFI> {
    ffi_guard_sync!({
        let reference = ShmReference {
            segment_name,
            byte_length: byte_length as usize,
            content_type: String::new(),
        };
        let data = ShmPool::read_payload(&reference).map_err(|e| AgentErrorFFI::AgentError {
            message: format!("shm read failed: {e}"),
        })?;
        String::from_utf8(data).map_err(|e| AgentErrorFFI::AgentError {
            message: format!("shm payload is not valid UTF-8: {e}"),
        })
    })
}

/// Write raw bytes into a new shared memory segment and return the reference JSON.
/// Used by the TCC Swift Proxy to write screen capture pixel data into SHM
/// without routing through the Python daemon (which lacks TCC permissions).
///
/// Returns a JSON string like: `{"segment_name":"/ep_tcc_42","byte_length":1234567,"content_type":"image/png"}`
#[uniffi::export]
pub fn shm_write_payload(
    session_id: String,
    data: Vec<u8>,
    content_type: String,
) -> Result<String, AgentErrorFFI> {
    ffi_guard_sync!({
        ShmPool::init();
        let reference =
            ShmPool::write_payload(&session_id, &data, &content_type).map_err(|e| {
                AgentErrorFFI::AgentError {
                    message: format!("shm write failed: {e}"),
                }
            })?;
        serde_json::to_string(&reference).map_err(|e| AgentErrorFFI::AgentError {
            message: format!("shm reference serialization failed: {e}"),
        })
    })
}

/// Clean up all shared memory segments for a given agent session.
/// Call this from Swift when an agent session ends.
#[uniffi::export]
pub fn shm_cleanup_session(session_id: String) -> u32 {
    ffi_guard_value!(ShmPool::cleanup_session(&session_id) as u32, 0)
}

/// Emergency cleanup — unlink ALL tracked segments across all sessions.
/// Call this from Swift on app termination to prevent zombie shm segments.
#[uniffi::export]
pub fn shm_cleanup_all() -> u32 {
    ffi_guard_value!(ShmPool::cleanup_all() as u32, 0)
}

/// Diagnostics: total number of tracked shared memory segments.
#[uniffi::export]
pub fn shm_total_segment_count() -> u32 {
    ffi_guard_value!(ShmPool::total_segment_count() as u32, 0)
}

// MARK: - Credential Pool FFI

#[derive(uniffi::Record)]
pub struct CredentialPoolStatusFFI {
    pub provider: String,
    pub total_keys: u32,
    pub exhausted_keys: u32,
}

/// Get the status of all credential pools (for diagnostics).
#[uniffi::export]
pub fn get_credential_pool_status() -> Vec<CredentialPoolStatusFFI> {
    ffi_guard_value!(
        {
            // Note: This returns empty since we don't have a global singleton.
            // The actual pools are per-session. This is for diagnostics UI.
            Vec::new()
        },
        Vec::new()
    )
}

// MARK: - Session Persistence FFI

#[derive(uniffi::Record)]
pub struct SessionCheckpointFFI {
    pub session_id: String,
    pub turn_number: u32,
    pub can_resume: bool,
}

#[derive(uniffi::Record)]
pub struct SessionSummaryFFI {
    pub session_id: String,
    pub objective: String,
    pub provider_name: String,
    pub started_at: String,
    pub last_turn: u32,
}

/// Check if a session has checkpoints available for resume.
#[uniffi::export]
pub fn session_has_checkpoints(vault_path: String, session_id: String) -> bool {
    ffi_guard_value!(
        {
            match SessionPersistence::open(std::path::Path::new(&vault_path)) {
                Ok(persistence) => persistence.has_checkpoints(&session_id).unwrap_or(false),
                Err(_) => false,
            }
        },
        false
    )
}

/// List all incomplete sessions in a vault (for recovery UI).
#[uniffi::export]
pub fn list_incomplete_sessions(vault_path: String) -> Vec<SessionSummaryFFI> {
    ffi_guard_value!(
        {
            match SessionPersistence::open(std::path::Path::new(&vault_path)) {
                Ok(persistence) => persistence
                    .list_incomplete_sessions()
                    .unwrap_or_default()
                    .into_iter()
                    .map(|s| SessionSummaryFFI {
                        session_id: s.session_id,
                        objective: s.objective,
                        provider_name: s.provider_name,
                        started_at: s.started_at,
                        last_turn: s.last_turn.unwrap_or(0) as u32,
                    })
                    .collect(),
                Err(_) => Vec::new(),
            }
        },
        Vec::new()
    )
}

/// Delete all checkpoints for a session (call after successful completion).
#[uniffi::export]
pub fn delete_session_checkpoints(vault_path: String, session_id: String) -> u32 {
    ffi_guard_value!(
        {
            match SessionPersistence::open(std::path::Path::new(&vault_path)) {
                Ok(mut persistence) => {
                    persistence.delete_session_checkpoints(&session_id).unwrap_or(0)
                }
                Err(_) => 0,
            }
        },
        0
    )
}

/// Prune old checkpoints (keep last N per session, delete older than X days).
#[uniffi::export]
pub fn prune_old_checkpoints(vault_path: String, keep_per_session: u32, max_age_days: u32) -> u32 {
    ffi_guard_value!(
        {
            match SessionPersistence::open(std::path::Path::new(&vault_path)) {
                Ok(mut persistence) => persistence
                    .prune_old_checkpoints(keep_per_session as usize, max_age_days as i64)
                    .unwrap_or(0),
                Err(_) => 0,
            }
        },
        0
    )
}

#[cfg(test)]
mod tests {
    use super::resolve_provider_selection_preview;

    #[test]
    fn explicit_provider_override_stays_forced() {
        let preview = resolve_provider_selection_preview("summarize this note", "claude_opus");

        assert_eq!(preview.requested_provider, "claude_opus");
        assert_eq!(preview.resolution_kind, "forced");
        assert_eq!(preview.effective_provider, "claude_opus");
        assert!(preview.supported);
    }

    #[test]
    fn auto_mode_uses_cloud_fallback_for_simple_tasks() {
        let preview = resolve_provider_selection_preview("summarize this note", "auto");

        assert_eq!(preview.resolution_kind, "auto_local_fallback");
        assert_eq!(preview.effective_provider, "claude_sonnet");
        assert!(preview.supported);
    }

    #[test]
    fn auto_mode_routes_research_to_perplexity_when_available() {
        let preview =
            resolve_provider_selection_preview("research the latest transformer papers", "auto");

        assert_eq!(preview.resolution_kind, "auto_cloud");
        assert_eq!(preview.effective_provider, "perplexity");
        assert!(preview.supported);
    }

    #[test]
    fn auto_mode_surfaces_local_only_routes_honestly() {
        let preview = resolve_provider_selection_preview("rewrite this paragraph", "auto");

        assert_eq!(preview.resolution_kind, "auto_local_only");
        assert_eq!(preview.effective_provider, "");
        assert!(!preview.supported);
    }
}
