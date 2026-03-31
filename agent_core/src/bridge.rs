use std::sync::Arc;

use crate::agent_loop::{
    run_agent_loop, AgentConfig, AgentError, Effort, PermissionConfig,
};
use crate::error::HttpStatusError;
use crate::provider::AgentProvider;
use crate::providers::claude::ClaudeProvider;
use crate::providers::perplexity::PerplexityProvider;
use crate::routing::{CloudProvider, ConfidenceRouter, RoutingDecision};
use crate::session::GlobalSessions;
use crate::storage::memory_classifier::{classify_memory_operation, MemoryOperation, VaultFact};
use crate::storage::memory_decay::{batch_decay, collect_garbage, Importance, NodeStrength};
use crate::storage::vault::VaultStore;
use crate::tools::registry::ToolRegistry;

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
        "claude_sonnet" | "claude_opus" | "claude_haiku" => preview(
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
                        | CloudProvider::Perplexity
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
        "claude_sonnet" => Ok(Arc::new(ClaudeProvider::sonnet())),
        "claude_opus" => Ok(Arc::new(ClaudeProvider::opus())),
        "claude_haiku" => Ok(Arc::new(ClaudeProvider::haiku())),
        "perplexity" => Ok(Arc::new(PerplexityProvider::sonar_pro())),
        _ => Err(AgentErrorFFI::AgentError {
            message: format!("Unsupported provider in agent_core bridge: {name}"),
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
    resolve_provider_selection_preview(&objective, &provider_name)
}

#[uniffi::export(async_runtime = "tokio")]
pub async fn run_agent_session(
    session_id: String,
    objective: String,
    provider_name: String,
    tool_config: ToolConfig,
    agent_config: AgentConfigFFI,
    delegate: Box<dyn AgentEventDelegate>,
) -> Result<AgentResultFFI, AgentErrorFFI> {
    let (_guard, cancel) = GlobalSessions::register(&session_id);

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

    let result = run_agent_loop(objective, provider, tool_registry, delegate, config, cancel).await;
    match result {
        Ok(result) => {
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
            GlobalSessions::fail(&session_id, &error.to_string());
            Err(AgentErrorFFI::AgentError {
                message: error.to_string(),
            })
        }
    }
}

#[uniffi::export]
pub fn cancel_agent_session(session_id: String) {
    GlobalSessions::cancel(&session_id);
}

#[uniffi::export]
pub fn active_session_count() -> u32 {
    GlobalSessions::active_count() as u32
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
    tokio::task::spawn_blocking(move || {
        crate::pty::PtyPool::spawn(&session_id, pty_config)
    })
    .await
    .map_err(|e| AgentErrorFFI::AgentError {
        message: format!("PTY spawn join error: {e}"),
    })?
    .map_err(|e| AgentErrorFFI::AgentError {
        message: e.to_string(),
    })
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
    let output = tokio::task::spawn_blocking(move || {
        crate::pty::PtyPool::execute(&pty_id, &command, timeout)
    })
    .await
    .map_err(|e| AgentErrorFFI::AgentError {
        message: format!("PTY execute join error: {e}"),
    })?
    .map_err(|e| AgentErrorFFI::AgentError {
        message: e.to_string(),
    })?;
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
    crate::pty::PtyPool::close(&pty_id);
}

/// Get the number of active PTY sessions (diagnostics).
#[uniffi::export]
pub fn pty_active_count() -> u32 {
    crate::pty::PtyPool::active_count() as u32
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
    let facts: Vec<VaultFact> = existing_facts
        .into_iter()
        .map(|f| {
            let last_accessed = chrono::DateTime::from_timestamp(f.last_accessed_epoch as i64, 0)
                .unwrap_or_else(chrono::Utc::now);
            VaultFact::new(f.file_path, f.section, f.content, f.strength, last_accessed)
        })
        .collect();
    classify_memory_operation(&incoming, &facts).into()
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
}

/// Garbage-collect weak memory nodes below the threshold.
/// Returns the number of nodes removed.
#[uniffi::export]
pub fn gc_memory_nodes(
    nodes: Vec<NodeStrengthFFI>,
    threshold: f64,
) -> u32 {
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
