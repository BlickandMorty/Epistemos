use std::collections::HashSet;
use std::sync::Arc;

use crate::agent_loop::{run_agent_loop, AgentConfig, AgentError, Effort, PermissionConfig};
use crate::error::HttpStatusError;
use crate::provider::AgentProvider;
use crate::providers::claude::ClaudeProvider;
use crate::providers::gemini::GeminiProvider;
use crate::providers::openai::OpenAIProvider;
use crate::providers::openai_compatible::OpenAICompatibleProvider;
use crate::providers::perplexity::PerplexityProvider;
use crate::reasoning_metrics::ReasoningTrajectoryMetrics;
use crate::routing::{CloudProvider, ConfidenceRouter, RoutingDecision};
use crate::session::GlobalSessions;
use crate::shared_memory::{ShmPool, ShmReference};
use crate::storage::contradiction_detector;
use crate::storage::memory_classifier::{classify_memory_operation, MemoryOperation, VaultFact};
use crate::storage::memory_decay::{batch_decay, collect_garbage, Importance, NodeStrength};
use crate::storage::session_store::{self, SessionFolder};
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
    fn execute_computer_action(&self, action_json: String) -> String;
    fn wait_for_permission(&self, permission_id: String) -> bool;

    /// Present a clarifying question to the user and block until they
    /// respond. `question_json` has shape `{ "question": String, "choices": [String] }`.
    /// The return value must be a JSON string of the form
    /// `{ "response": String, "choice_index": Option<u32> }`.
    fn ask_user_question(&self, question_json: String) -> String;

    // --- Phase 4: macOS Native Specialties ---

    /// Specialty A1 — Perceive a macOS app via AX + Vision + VLM fusion.
    /// `depth` is one of "fast" (AX only), "enriched" (AX + OCR),
    /// or "full" (AX + OCR + VLM). Returns JSON:
    /// `{ elements: [...], screenshot_path: Option<String>, latency_ms: u64 }`.
    fn perceive_app(&self, app_name: String, depth: String) -> String;

    /// Specialty A2 — Interact with a macOS app: click, type, scroll, drag,
    /// press_key. `action_json` has shape
    /// `{ app_name, action, target, value }`. Target is either a semantic
    /// query ("the Save button") or a ref returned by perceive_app.
    /// Returns JSON: `{ success, element_found, action_performed }`.
    fn interact_with_app(&self, action_json: String) -> String;

    /// Specialty A3 — Start a watch on a screen region, file path, or app
    /// state. `watch_json` has shape
    /// `{ mode, target, condition, timeout_secs }`. Blocks until the
    /// condition triggers or the timeout expires. Returns JSON:
    /// `{ triggered, reason, elapsed_ms }`.
    fn start_screen_watch(&self, watch_json: String) -> String;

    // --- Phase 5: Inference Specialties ---

    /// Specialty C1 — Save, load, list, or prune Mamba SSM hidden-state
    /// snapshots. `action_json` has shape
    /// `{ action: "save"|"load"|"list"|"prune", session_id?, label? }`.
    /// Returns JSON:
    /// `{ success, state_size_mb, layers, dtype, duration_ms, states? }`.
    fn manage_ssm_state(&self, action_json: String) -> String;

    /// Specialty C2 — Run constrained decoding on the local model with an
    /// EBNF grammar so the output is guaranteed structurally valid.
    /// `grammar_json` has shape
    /// `{ grammar: "tool_call"|"planning"|"custom", custom_ebnf?, tools? }`.
    /// Returns JSON:
    /// `{ output, tokens_generated, constraint_violations_masked }`.
    fn generate_constrained(&self, prompt: String, grammar_json: String) -> String;

    /// Specialty C3 — Generate an image via the MLX sidecar lane per
    /// PLAN_V2 §5.1 and §16. `aspect_ratio` is one of `"landscape" |
    /// "portrait" | "square"`. Returns a JSON envelope with shape
    /// `{ "provider": "mlx", "model": "...", "image_url"|"image_path": "..." }`
    /// on success, or `{ "error": "...", "hint"?: "..." }` on failure. A
    /// `{"error": "..."}` response is the canonical way to surface
    /// "MLX Flux not yet configured" while the MLX-first plan invariant
    /// stays intact — callers who want a cloud path MUST pass
    /// `provider: "fal"` explicitly. There is no silent cloud escalation
    /// (PLAN_V2 §3.4).
    fn generate_image(&self, prompt: String, aspect_ratio: String) -> String;

    // --- Phase 7: Intelligence Layer ---

    /// Specialty D1 — Trigger a NightBrain background job on demand.
    /// `job_type` is one of: event_checkpoint, search_index_checkpoint,
    /// artifact_dedup, workspace_compaction, memory_distillation,
    /// cloud_knowledge_distillation, session_graph_generation,
    /// skill_evolution_analysis, ssm_state_pruning, vault_integrity_check,
    /// maintenance_log. `priority` is "normal" or "immediate".
    /// Returns JSON: `{ job_id, status, estimated_duration_s }`.
    fn trigger_nightbrain_job(&self, job_type: String, priority: String) -> String;

    /// Specialty D2 — query what the inline AI partner "sees" at a given
    /// note cursor position. Returns JSON with weighted matches, complexity,
    /// and any current partner suggestion context.
    fn get_partner_context(&self, note_id: String, cursor_offset: u32) -> String;
}

#[derive(uniffi::Record)]
pub struct ToolConfig {
    pub vault_path: String,
    pub enable_bash: bool,
    pub enable_web_search: bool,
    /// Tool tier. One of: "none", "chat_lite", "chat_pro", "agent", "full".
    /// Defaults to "agent" when not supplied. Normal chat (fast/thinking)
    /// should pass "chat_lite"; Pro mode should pass "chat_pro"; agent mode
    /// should pass "agent".
    pub tool_tier: Option<String>,
    /// Explicit per-tool allowlist. When `Some`, the agent may ONLY call
    /// tools whose names are in this set (intersected with the tier). When
    /// `None`, tier is the only gate — backward compatible with callers that
    /// don't know about per-tool toggles. Populated by the Agent Command
    /// Center's `CommandCenterRequestCompiler` from the user's explicit
    /// tool-toggle selections.
    pub allowed_tool_names: Option<Vec<String>>,
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
    /// Explicit prompt mode override: "general", "code", "research", or "auto" (default).
    /// When "auto", mode is inferred from the objective keywords.
    pub prompt_mode: Option<String>,
}

#[derive(uniffi::Record)]
pub struct ToolSchemaFFI {
    pub name: String,
    pub description: String,
    pub parameters_json: String,
    pub risk_level: String,
    pub tier: String,
}

#[derive(uniffi::Record)]
pub struct ToolExecutionResultFFI {
    pub success: bool,
    pub output_json: String,
    pub error: Option<String>,
}

#[derive(uniffi::Record)]
pub struct AgentResultFFI {
    pub turns: u32,
    pub input_tokens: u32,
    pub output_tokens: u32,
    pub trajectory_metrics: ReasoningTrajectoryMetricsFFI,
}

#[derive(uniffi::Record)]
pub struct ReasoningTrajectoryMetricsFFI {
    pub displacement: f64,
    pub path_length: f64,
    pub curvature_ratio: f64,
    pub loop_count: u32,
    pub error_count: u32,
    pub total_calls: u32,
    pub efficiency: f64,
    pub classification: String,
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
            vault_root: None,
            prompt_mode_override: None,
            max_cost_usd: None,
        }
    }
}

impl From<ReasoningTrajectoryMetrics> for ReasoningTrajectoryMetricsFFI {
    fn from(metrics: ReasoningTrajectoryMetrics) -> Self {
        Self {
            displacement: metrics.displacement as f64,
            path_length: metrics.path_length as f64,
            curvature_ratio: metrics.curvature_ratio as f64,
            loop_count: metrics.loop_count,
            error_count: metrics.error_count,
            total_calls: metrics.total_calls,
            efficiency: metrics.efficiency as f64,
            classification: metrics.classification.as_str().to_string(),
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
pub fn preview_provider_route(objective: String, provider_name: String) -> ProviderRoutePreviewFFI {
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
            session_id_clone,
            objective,
            provider_name,
            tool_config,
            agent_config,
            delegate,
        )
        .await
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
) -> Result<AgentResultFFI, AgentErrorFFI> {
    // Initialize the shared memory pool (idempotent)
    ShmPool::init();

    let (provider, _route_preview) = resolve_provider_for_session(&objective, &provider_name)?;

    let vault_path = std::path::Path::new(&tool_config.vault_path);

    // Create a persistent session folder inside the vault
    let session_folder = SessionFolder::create(
        vault_path,
        &session_id,
        &provider_name,
        &provider_name, // provider == provider_name for now
    )
    .map_err(|error| AgentErrorFFI::AgentError {
        message: format!("Failed to create session folder: {error}"),
    })?;

    tracing::info!(
        "[session] Created session folder: {}",
        session_folder.root().display()
    );

    // Register with folder so SessionGuard::drop can finalize on crash
    let (_guard, cancel) = GlobalSessions::register_with_folder(&session_id, session_folder);

    let vault =
        VaultStore::open(&tool_config.vault_path).map_err(|error| AgentErrorFFI::AgentError {
            message: format!("Failed to open vault: {error}"),
        })?;
    let tier = tool_config
        .tool_tier
        .as_deref()
        .map(crate::tools::registry::ToolTier::from_str_lossy)
        .unwrap_or(crate::tools::registry::ToolTier::Agent);
    let mut tool_registry = ToolRegistry::with_tier(
        Arc::new(vault),
        tool_config.enable_bash,
        Some(std::path::PathBuf::from(&tool_config.vault_path)),
        tier,
    );
    // Install the caller-provided per-tool allowlist (Phase 5 authority
    // boundary: Agent Command Center tool toggles become authoritative on
    // the runtime path here).
    if let Some(allowed) = &tool_config.allowed_tool_names {
        let set: std::collections::HashSet<String> = allowed.iter().cloned().collect();
        tool_registry.set_allowed_tool_names(Some(set));
    }
    let mut config = AgentConfig::from_ffi(&agent_config);
    config.vault_root = Some(tool_config.vault_path.clone());
    config.prompt_mode_override = agent_config.prompt_mode.as_deref().and_then(|mode| {
        match mode {
            "code" => Some(crate::prompts::PromptMode::Code),
            "research" => Some(crate::prompts::PromptMode::Research),
            "general" => Some(crate::prompts::PromptMode::General),
            _ => None, // "auto" or unknown → auto-detect from keywords
        }
    });
    let delegate: Arc<dyn AgentEventDelegate> = delegate.into();
    // Wire the delegate into tools that need it (clarify is the only one for
    // now — Phase 4/5 macOS specialties will extend this).
    tool_registry.register_delegate_tools(Arc::clone(&delegate));
    let tool_registry = Arc::new(tool_registry);

    let result = run_agent_loop(
        session_id.clone(),
        objective,
        provider,
        tool_registry,
        delegate,
        config,
        cancel,
    )
    .await;
    match result {
        Ok(result) => {
            // Clean up shared memory segments for this session
            ShmPool::cleanup_session(&session_id);
            GlobalSessions::complete(
                &session_id,
                result.turns,
                result.total_usage.input_tokens,
                result.total_usage.output_tokens,
                Some(result.trajectory_metrics.clone()),
            );
            Ok(AgentResultFFI {
                turns: result.turns,
                input_tokens: result.total_usage.input_tokens,
                output_tokens: result.total_usage.output_tokens,
                trajectory_metrics: result.trajectory_metrics.into(),
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

// MARK: - Agent Command Center Request Compilation
//
// Rust authority per PLAN_V2 §3.1 / §4.1. Swift must call this entry point
// for every Agent Command Center submission. Swift pre-resolves @-mentions
// via VaultSyncService (the only Swift-resident dependency), then JSON-
// encodes the full input and calls this function. Rust owns:
//
// - runtime resolution (explicit brain never silently reroutes)
// - tool permission resolution against the catalog + explicit toggles
// - execution policy / budgets / route / expert allowlist / summary
// - notes-context block assembly
//
// The JSON contract is the existing Swift `CompiledCommandCenterRequest`
// Codable shape. Swift decodes the returned JSON into that existing type,
// so every downstream consumer (ChatCoordinator, Inspector, diagnostics)
// keeps working unchanged.

#[uniffi::export]
pub fn compile_command_center_request(input_json: String) -> Result<String, AgentErrorFFI> {
    ffi_guard_sync!({
        crate::command_center::compile_from_json(&input_json).map_err(|message| {
            AgentErrorFFI::AgentError { message }
        })
    })
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
pub async fn pty_spawn(session_id: String, config: PtyConfigFFI) -> Result<String, AgentErrorFFI> {
    let pty_config = crate::pty::PtyConfig {
        shell: config.shell,
        initial_dir: config.initial_dir,
        cols: config.cols,
        rows: config.rows,
    };
    let handle =
        tokio::task::spawn_blocking(move || crate::pty::PtyPool::spawn(&session_id, pty_config));
    match handle.await {
        Ok(Ok(pty_id)) => Ok(pty_id),
        Ok(Err(e)) => Err(AgentErrorFFI::AgentError {
            message: e.to_string(),
        }),
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
        Ok(Err(e)) => {
            return Err(AgentErrorFFI::AgentError {
                message: e.to_string(),
            })
        }
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
                    let last_accessed =
                        chrono::DateTime::from_timestamp(f.last_accessed_epoch as i64, 0)
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
pub fn decay_memory_nodes(mut nodes: Vec<NodeStrengthFFI>, now_epoch: f64) -> Vec<NodeStrengthFFI> {
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
                    let last_accessed =
                        chrono::DateTime::from_timestamp(n.last_accessed_epoch as i64, 0)
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
pub fn gc_memory_nodes(nodes: Vec<NodeStrengthFFI>, threshold: f64) -> u32 {
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
                    let last_accessed =
                        chrono::DateTime::from_timestamp(n.last_accessed_epoch as i64, 0)
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
pub fn shm_read_payload(segment_name: String, byte_length: u64) -> Result<String, AgentErrorFFI> {
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
        let reference = ShmPool::write_payload(&session_id, &data, &content_type).map_err(|e| {
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

// MARK: - Context Loader FFI

/// Preview the 5-tier session context that would be injected for a given objective.
/// Returns the XML-formatted context string.
///
/// SAFETY: Wrapped in tokio::task::spawn to catch panics from vault I/O
/// or skill routing, preventing unwind across FFI boundary.
#[uniffi::export(async_runtime = "tokio")]
pub async fn preview_session_context(
    vault_path: String,
    objective: String,
    max_tokens: u32,
) -> Result<String, AgentErrorFFI> {
    let handle = tokio::task::spawn(async move {
        let vault = VaultStore::open(&vault_path).map_err(|e| AgentErrorFFI::AgentError {
            message: format!("Failed to open vault: {e}"),
        })?;
        let vault_root = std::path::Path::new(&vault_path);
        let ctx = crate::context_loader::load_session_context(
            &vault,
            vault_root,
            &objective,
            max_tokens as usize,
        )
        .await;
        Ok::<String, AgentErrorFFI>(ctx.to_xml())
    });

    match handle.await {
        Ok(result) => result,
        Err(join_error) => {
            let msg = if join_error.is_panic() {
                let payload = join_error.into_panic();
                let msg = panic_payload_to_string(payload);
                tracing::error!("[ffi] PANIC in preview_session_context: {}", msg);
                format!("Rust panic in context preview: {}", msg)
            } else {
                "Context preview task cancelled".to_string()
            };
            Err(AgentErrorFFI::AgentError { message: msg })
        }
    }
}

// MARK: - Neocortex Engine FFI

/// Feed compacted context into the Neocortex for "fluid awareness" retention.
#[uniffi::export]
pub fn neocortex_absorb(content: String, source_type: String, source_id: String) {
    ffi_guard_value!(
        {
            let source = match source_type.as_str() {
                "compaction" => crate::neocortex::ContextSource::Compaction,
                "session" => crate::neocortex::ContextSource::SessionSummary {
                    session_id: source_id,
                },
                "vault" => crate::neocortex::ContextSource::VaultFact { path: source_id },
                "pinned" => crate::neocortex::ContextSource::UserPinned,
                _ => crate::neocortex::ContextSource::Compaction,
            };
            crate::neocortex::global_neocortex().absorb(&content, source);
        },
        ()
    )
}

/// Generate a gist from the Neocortex's accumulated awareness.
/// Returns empty string if nothing has been absorbed.
#[uniffi::export]
pub fn neocortex_query(max_tokens: u32) -> String {
    ffi_guard_value!(
        {
            crate::neocortex::global_neocortex()
                .generate_gist(max_tokens as usize)
                .map(|g| g.content)
                .unwrap_or_default()
        },
        String::new()
    )
}

/// Get Neocortex status for diagnostics.
#[uniffi::export]
pub fn neocortex_status() -> String {
    ffi_guard_value!(
        {
            let status = crate::neocortex::global_neocortex().status();
            serde_json::to_string(&status).unwrap_or_else(|_| "{}".to_string())
        },
        "{}".to_string()
    )
}

/// Clear the Neocortex (reset awareness).
#[uniffi::export]
pub fn neocortex_clear() {
    ffi_guard_value!(crate::neocortex::global_neocortex().clear(), ())
}

// MARK: - SSM State Persistence FFI

/// Save an SSM hidden state to disk.
#[uniffi::export]
pub fn save_ssm_state_ffi(
    vault_path: String,
    model_id: String,
    session_id: String,
    layer_count: u32,
    state_dim: u32,
    head_dim: u32,
    layer_data: Vec<u8>,
) -> Result<String, AgentErrorFFI> {
    ffi_guard_sync!({
        let state = crate::storage::ssm_state::SSMState {
            model_id,
            session_id,
            layer_count,
            state_dim,
            head_dim,
            layer_data,
        };
        let vault_root = std::path::Path::new(&vault_path);
        let path = crate::storage::ssm_state::save_ssm_state(&state, vault_root).map_err(|e| {
            AgentErrorFFI::AgentError {
                message: format!("Failed to save SSM state: {e}"),
            }
        })?;
        Ok(path.to_string_lossy().to_string())
    })
}

/// List all saved SSM states for a vault.
#[uniffi::export]
pub fn list_ssm_states_ffi(vault_path: String) -> String {
    ffi_guard_value!(
        {
            let vault_root = std::path::Path::new(&vault_path);
            let states = crate::storage::ssm_state::list_ssm_states(vault_root).unwrap_or_default();
            serde_json::to_string(&states).unwrap_or_else(|_| "[]".to_string())
        },
        "[]".to_string()
    )
}

// MARK: - Hyperbolic Topology FFI

/// Build the hyperbolic topology map for a vault.
/// Returns the topology as a JSON string with Poincaré coordinates,
/// complexity weights, gravity, volatility, and Markov Blanket summaries.
#[uniffi::export]
pub fn build_vault_topology(vault_path: String) -> Result<String, AgentErrorFFI> {
    ffi_guard_sync!({
        let vault_root = std::path::Path::new(&vault_path);
        let topology =
            crate::storage::hyperbolic_topology::build_topology(vault_root).map_err(|e| {
                AgentErrorFFI::AgentError {
                    message: format!("Topology build failed: {e}"),
                }
            })?;
        serde_json::to_string_pretty(&topology).map_err(|e| AgentErrorFFI::AgentError {
            message: format!("Topology serialization failed: {e}"),
        })
    })
}

/// Generate a compact agent-facing topology context string.
/// This replaces `ls -la` with dimensionally-tagged spatial awareness.
#[uniffi::export]
pub fn vault_topology_context(vault_path: String, max_tokens: u32) -> String {
    ffi_guard_value!(
        {
            let vault_root = std::path::Path::new(&vault_path);
            match crate::storage::hyperbolic_topology::build_topology(vault_root) {
                Ok(topology) => crate::storage::hyperbolic_topology::topology_to_agent_context(
                    &topology,
                    max_tokens as usize,
                ),
                Err(_) => String::new(),
            }
        },
        String::new()
    )
}

// MARK: - Neural Cache FFI

#[derive(uniffi::Record)]
pub struct CachedResultFFI {
    pub path: String,
    pub content: String,
    pub score: f64,
    /// "hot", "warm", or "cold"
    pub layer: String,
    pub latency_us: u64,
}

#[derive(uniffi::Record)]
pub struct CacheStatsFFI {
    pub hot_entries: u32,
    pub max_hot_entries: u32,
}

/// Instant tiered retrieval: searches hot cache first (<1ms), then warm index (<5ms).
/// Results are automatically warmed into the hot layer for next time.
#[uniffi::export(async_runtime = "tokio")]
pub async fn instant_retrieve(
    vault_path: String,
    query: String,
    limit: u32,
) -> Vec<CachedResultFFI> {
    let handle = tokio::task::spawn(async move {
        let vault = match VaultStore::open(&vault_path) {
            Ok(v) => v,
            Err(_) => return Vec::new(),
        };
        let cache = get_or_create_cache(&vault_path);
        let results = cache.instant_retrieve(&query, &vault, limit as usize).await;
        results
            .into_iter()
            .map(|r| CachedResultFFI {
                path: r.path,
                content: r.content,
                score: r.score,
                layer: match r.layer {
                    crate::storage::neural_cache::CacheLayer::Hot => "hot".to_string(),
                    crate::storage::neural_cache::CacheLayer::Warm => "warm".to_string(),
                    crate::storage::neural_cache::CacheLayer::Cold => "cold".to_string(),
                },
                latency_us: r.latency_us,
            })
            .collect()
    });

    match handle.await {
        Ok(results) => results,
        Err(join_error) => {
            if join_error.is_panic() {
                let payload = join_error.into_panic();
                let msg = panic_payload_to_string(payload);
                tracing::error!("[ffi] PANIC in instant_retrieve: {}", msg);
            }
            Vec::new()
        }
    }
}

/// Get neural cache statistics for diagnostics.
#[uniffi::export]
pub fn neural_cache_stats(vault_path: String) -> CacheStatsFFI {
    ffi_guard_value!(
        {
            let cache = get_or_create_cache(&vault_path);
            let stats = cache.stats();
            CacheStatsFFI {
                hot_entries: stats.hot_entries as u32,
                max_hot_entries: stats.max_hot_entries as u32,
            }
        },
        CacheStatsFFI {
            hot_entries: 0,
            max_hot_entries: 0,
        }
    )
}

/// Temporal query: retrieve cached facts from a specific time window.
/// "What did we discuss X minutes ago?" — instant KV-cache-style recall.
#[uniffi::export]
pub fn temporal_retrieve(
    vault_path: String,
    minutes_ago: u32,
    window_minutes: u32,
) -> Vec<CachedResultFFI> {
    ffi_guard_value!(
        {
            let cache = get_or_create_cache(&vault_path);
            cache
                .temporal_retrieve(minutes_ago as u64, window_minutes as u64)
                .into_iter()
                .map(|r| CachedResultFFI {
                    path: r.path,
                    content: r.content,
                    score: r.score,
                    layer: "hot".to_string(),
                    latency_us: r.latency_us,
                })
                .collect()
        },
        Vec::new()
    )
}

/// Clear the neural cache hot layer (call on vault switch).
#[uniffi::export]
pub fn neural_cache_clear(vault_path: String) {
    ffi_guard_value!(
        {
            let cache = get_or_create_cache(&vault_path);
            cache.clear_hot();
        },
        ()
    )
}

/// Global singleton neural caches per vault path.
fn get_or_create_cache(_vault_path: &str) -> &'static crate::storage::neural_cache::NeuralCache {
    use std::sync::OnceLock;

    // Single global cache (could be extended to per-vault with a HashMap)
    static CACHE: OnceLock<crate::storage::neural_cache::NeuralCache> = OnceLock::new();
    CACHE.get_or_init(|| crate::storage::neural_cache::NeuralCache::new(500))
}

// MARK: - GEPA Evolution FFI

/// Analyze traces for a skill across session folders in a vault.
/// Returns the analysis as a JSON string.
#[uniffi::export]
pub fn analyze_skill_traces(
    vault_path: String,
    skill_name: String,
) -> Result<String, AgentErrorFFI> {
    ffi_guard_sync!({
        let vault_root = std::path::Path::new(&vault_path);
        let sessions_dir = vault_root.join("sessions");
        if !sessions_dir.is_dir() {
            return Ok("{}".to_string());
        }

        let mut folder_paths = Vec::new();
        for entry in std::fs::read_dir(&sessions_dir).map_err(|e| AgentErrorFFI::AgentError {
            message: format!("Failed to read sessions dir: {e}"),
        })? {
            let entry = entry.map_err(|e| AgentErrorFFI::AgentError {
                message: format!("Failed to read entry: {e}"),
            })?;
            if entry.path().is_dir() {
                folder_paths.push(entry.path());
            }
        }

        let folder_refs: Vec<&std::path::Path> = folder_paths.iter().map(|p| p.as_path()).collect();
        let pattern = crate::evolution::trace_analyzer::analyze_traces(&folder_refs, &skill_name)
            .map_err(|e| AgentErrorFFI::AgentError {
            message: format!("Trace analysis failed: {e}"),
        })?;

        serde_json::to_string_pretty(&pattern).map_err(|e| AgentErrorFFI::AgentError {
            message: format!("Pattern serialization failed: {e}"),
        })
    })
}

/// Propose a mutation to a skill based on a trace pattern.
/// Returns the mutation proposal as a JSON string, or empty string if no mutation needed.
#[uniffi::export]
pub fn propose_skill_mutation(
    skill_content: String,
    trace_pattern_json: String,
) -> Result<String, AgentErrorFFI> {
    ffi_guard_sync!({
        let pattern: crate::evolution::trace_analyzer::TracePattern =
            serde_json::from_str(&trace_pattern_json).map_err(|e| AgentErrorFFI::AgentError {
                message: format!("Invalid trace pattern JSON: {e}"),
            })?;

        match crate::evolution::mutation_proposer::propose_mutation(&skill_content, &pattern) {
            Some(mutation) => {
                serde_json::to_string_pretty(&mutation).map_err(|e| AgentErrorFFI::AgentError {
                    message: format!("Mutation serialization failed: {e}"),
                })
            }
            None => Ok(String::new()),
        }
    })
}

// MARK: - Dispatcher & Skills Registry FFI

#[derive(uniffi::Record)]
pub struct DispatchDecisionFFI {
    /// "skill", "agent", or "direct_response"
    pub target_type: String,
    /// Skill name or agent type (empty for direct_response)
    pub target_name: String,
    pub confidence: f64,
    pub reasoning: String,
}

/// Route an objective to the best skill or agent type.
#[uniffi::export]
pub fn dispatch_skill(vault_path: String, objective: String) -> DispatchDecisionFFI {
    ffi_guard_value!(
        {
            let vault_root = std::path::Path::new(&vault_path);
            let router = crate::skill_router::SkillRouter::load(vault_root);
            let registry = crate::storage::skills_registry::SkillsRegistryStore::load(vault_root);
            let entries: Vec<crate::storage::skills_registry::SkillRegistryEntry> =
                registry.list_all().into_iter().cloned().collect();
            let decision = crate::dispatcher::dispatch_intent(&objective, &router, &entries);

            let (target_type, target_name) = match decision.target {
                crate::dispatcher::DispatchTarget::Skill(name) => ("skill".to_string(), name),
                crate::dispatcher::DispatchTarget::Agent(agent_type) => {
                    ("agent".to_string(), agent_type)
                }
                crate::dispatcher::DispatchTarget::DirectResponse => {
                    ("direct_response".to_string(), String::new())
                }
            };

            DispatchDecisionFFI {
                target_type,
                target_name,
                confidence: decision.confidence,
                reasoning: decision.reasoning,
            }
        },
        DispatchDecisionFFI {
            target_type: "direct_response".to_string(),
            target_name: String::new(),
            confidence: 0.0,
            reasoning: "Internal panic during dispatch".to_string(),
        }
    )
}

#[derive(uniffi::Record)]
pub struct SkillRegistryEntryFFI {
    pub name: String,
    pub description: String,
    pub version: String,
    pub use_count: u32,
    pub success_rate: f64,
}

/// List all registered skills with their usage stats.
#[uniffi::export]
pub fn list_registered_skills(vault_path: String) -> Vec<SkillRegistryEntryFFI> {
    ffi_guard_value!(
        {
            let vault_root = std::path::Path::new(&vault_path);
            let registry = crate::storage::skills_registry::SkillsRegistryStore::load(vault_root);
            registry
                .list_all()
                .into_iter()
                .map(|entry| SkillRegistryEntryFFI {
                    name: entry.name.clone(),
                    description: entry.description.clone(),
                    version: entry.version.clone(),
                    use_count: entry.use_count,
                    success_rate: entry.avg_success_rate(),
                })
                .collect()
        },
        Vec::new()
    )
}

// MARK: - Session Graph FFI

/// Generate a knowledge graph from a session folder's transcript and summary.
/// Returns the graph as a JSON string.
#[uniffi::export]
pub fn generate_session_graph(session_folder_path: String) -> Result<String, AgentErrorFFI> {
    ffi_guard_sync!({
        let folder = std::path::Path::new(&session_folder_path);
        let transcript = folder.join("transcript.jsonl");
        let summary = folder.join("summary.md");

        // Derive session_id from folder name
        let session_id = folder
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("unknown");

        let graph =
            crate::storage::session_graph::extract_session_graph(&transcript, &summary, session_id)
                .map_err(|e| AgentErrorFFI::AgentError {
                    message: format!("Graph extraction failed: {e}"),
                })?;

        // Write graph.json and GRAPH_REPORT.md to the session folder
        let graph_json =
            serde_json::to_string_pretty(&graph).map_err(|e| AgentErrorFFI::AgentError {
                message: format!("Graph serialization failed: {e}"),
            })?;
        std::fs::write(folder.join("graph.json"), &graph_json).map_err(|e| {
            AgentErrorFFI::AgentError {
                message: format!("Failed to write graph.json: {e}"),
            }
        })?;

        let report = crate::storage::session_graph::generate_graph_report(&graph);
        std::fs::write(folder.join("GRAPH_REPORT.md"), &report).map_err(|e| {
            AgentErrorFFI::AgentError {
                message: format!("Failed to write GRAPH_REPORT.md: {e}"),
            }
        })?;

        Ok(graph_json)
    })
}

// MARK: - Contradiction Detection FFI

#[derive(uniffi::Record)]
pub struct ContradictionFFI {
    pub incoming_fact: String,
    pub existing_file_path: String,
    pub existing_section: String,
    pub existing_content: String,
    /// One of: "numeric", "boolean", "antonym", "semantic_reversal"
    pub conflict_type: String,
    pub confidence: f64,
}

/// Detect contradictions between an incoming fact and existing vault facts.
/// Returns a list of contradictions sorted by confidence (highest first).
#[uniffi::export]
pub fn detect_vault_contradictions(
    incoming: String,
    existing_facts: Vec<VaultFactFFI>,
) -> Vec<ContradictionFFI> {
    ffi_guard_value!(
        {
            let facts: Vec<VaultFact> = existing_facts
                .into_iter()
                .map(|f| {
                    let last_accessed =
                        chrono::DateTime::from_timestamp(f.last_accessed_epoch as i64, 0)
                            .unwrap_or_else(chrono::Utc::now);
                    VaultFact::new(f.file_path, f.section, f.content, f.strength, last_accessed)
                })
                .collect();
            let contradictions = contradiction_detector::detect_contradictions(&incoming, &facts);
            contradictions
                .into_iter()
                .map(|c| ContradictionFFI {
                    incoming_fact: c.incoming_fact,
                    existing_file_path: c.existing_fact.file_path,
                    existing_section: c.existing_fact.section,
                    existing_content: c.existing_fact.content,
                    conflict_type: match c.conflict_type {
                        contradiction_detector::ConflictType::Numeric => "numeric".to_string(),
                        contradiction_detector::ConflictType::Boolean => "boolean".to_string(),
                        contradiction_detector::ConflictType::Antonym => "antonym".to_string(),
                        contradiction_detector::ConflictType::SemanticReversal => {
                            "semantic_reversal".to_string()
                        }
                    },
                    confidence: c.confidence,
                })
                .collect()
        },
        Vec::new()
    )
}

// MARK: - Session Store FFI

#[derive(uniffi::Record)]
pub struct SessionFolderInfoFFI {
    pub session_id: String,
    pub model: String,
    pub provider: String,
    pub started_at_epoch: f64,
    pub status: String,
    pub turn_count: u32,
    pub folder_path: String,
}

/// List all session folders within a vault, sorted newest first.
#[uniffi::export]
pub fn list_session_folders(vault_path: String) -> Vec<SessionFolderInfoFFI> {
    ffi_guard_value!(
        {
            let vault_root = std::path::Path::new(&vault_path);
            session_store::list_session_folders(vault_root)
                .unwrap_or_default()
                .into_iter()
                .map(|info| SessionFolderInfoFFI {
                    session_id: info.session_id,
                    model: info.model,
                    provider: info.provider,
                    started_at_epoch: info.started_at_epoch,
                    status: info.status,
                    turn_count: info.turn_count,
                    folder_path: info.folder_path,
                })
                .collect()
        },
        Vec::new()
    )
}

/// Read session metadata as a JSON string from a session folder path.
#[uniffi::export]
pub fn read_session_metadata(session_folder_path: String) -> Result<String, AgentErrorFFI> {
    ffi_guard_sync!({
        let path = std::path::Path::new(&session_folder_path);
        session_store::read_session_metadata(path).map_err(|e| AgentErrorFFI::AgentError {
            message: format!("Failed to read session metadata: {e}"),
        })
    })
}

/// Get the session folder path for a currently running session (if it has one).
#[uniffi::export]
pub fn session_folder_path(session_id: String) -> Option<String> {
    ffi_guard_value!(GlobalSessions::session_folder_path(&session_id), None)
}

// MARK: - Tool Tier FFI (normal chat tool access)
//
// These entry points let Swift use the agent_core tool registry directly
// without going through `run_agent_session`. The normal chat path (Fast /
// Thinking / Pro modes) can call `list_tools_for_tier` to discover what's
// available and `execute_tool_call` to run a single tool per user turn.
//
// This is how local models (Qwen, Hermes) get web_search + vault_recall
// without the full agent loop. The Swift side handles the tool-use
// messaging protocol for whichever model is active.

/// Return the schemas for every tool visible at the requested tier.
/// `tier` is one of "none", "chat_lite", "chat_pro", "agent", "full".
/// A missing vault path is OK — tools that need it are silently skipped.
#[uniffi::export]
pub fn list_tools_for_tier(
    vault_path: String,
    tier: String,
) -> Result<Vec<ToolSchemaFFI>, AgentErrorFFI> {
    ffi_guard_sync!({
        let vault = VaultStore::open(&vault_path).map_err(|error| AgentErrorFFI::AgentError {
            message: format!("Failed to open vault: {error}"),
        })?;
        let tier_enum = crate::tools::registry::ToolTier::from_str_lossy(&tier);
        let registry = ToolRegistry::with_tier(
            Arc::new(vault),
            true,
            Some(std::path::PathBuf::from(&vault_path)),
            tier_enum,
        );
        let out: Vec<ToolSchemaFFI> = registry
            .get_definitions()
            .into_iter()
            .filter(|schema| crate::tools::registry::is_user_visible_tool(&schema.name))
            .map(|schema| ToolSchemaFFI {
                name: schema.name.clone(),
                description: schema.description,
                parameters_json: serde_json::to_string(&schema.parameters).unwrap_or_default(),
                risk_level: registry.get_risk_level(&schema.name).as_str().to_string(),
                tier: registry.get_tier(&schema.name).as_str().to_string(),
            })
            .collect();
        Ok(out)
    })
}

/// Return the schemas for every tool visible at the requested tier,
/// intersected with an explicit allowlist when one is supplied.
#[uniffi::export]
pub fn list_tools_for_tier_filtered(
    vault_path: String,
    tier: String,
    allowed_tool_names: Option<Vec<String>>,
) -> Result<Vec<ToolSchemaFFI>, AgentErrorFFI> {
    ffi_guard_sync!({
        let registry = build_registry_for_tool_tier(
            &vault_path,
            &tier,
            allowed_tool_names,
        )?;
        let out: Vec<ToolSchemaFFI> = registry
            .get_definitions()
            .into_iter()
            .filter(|schema| crate::tools::registry::is_user_visible_tool(&schema.name))
            .map(|schema| ToolSchemaFFI {
                name: schema.name.clone(),
                description: schema.description,
                parameters_json: serde_json::to_string(&schema.parameters).unwrap_or_default(),
                risk_level: registry.get_risk_level(&schema.name).as_str().to_string(),
                tier: registry.get_tier(&schema.name).as_str().to_string(),
            })
            .collect();
        Ok(out)
    })
}

/// Execute a single tool call on a tier-limited registry. `input_json` must
/// decode to a JSON object. Returns `{ success, output_json, error }`.
/// Tools that require the `AgentEventDelegate` (clarify, perceive, etc.)
/// are NOT supported by this entry point — use `run_agent_session` for those.
#[uniffi::export(async_runtime = "tokio")]
pub async fn execute_tool_call(
    vault_path: String,
    tier: String,
    tool_name: String,
    input_json: String,
) -> Result<ToolExecutionResultFFI, AgentErrorFFI> {
    let handle = tokio::task::spawn(async move {
        let vault = VaultStore::open(&vault_path).map_err(|error| AgentErrorFFI::AgentError {
            message: format!("Failed to open vault: {error}"),
        })?;
        let tier_enum = crate::tools::registry::ToolTier::from_str_lossy(&tier);
        let registry = ToolRegistry::with_tier(
            Arc::new(vault),
            true,
            Some(std::path::PathBuf::from(&vault_path)),
            tier_enum,
        );
        let input: serde_json::Value =
            serde_json::from_str(&input_json).map_err(|e| AgentErrorFFI::AgentError {
                message: format!("invalid input_json: {e}"),
            })?;

        match registry.execute_v2(&tool_name, &input).await {
            Ok(output) => Ok(ToolExecutionResultFFI {
                success: true,
                output_json: output,
                error: None,
            }),
            Err(err) => Ok(ToolExecutionResultFFI {
                success: false,
                output_json: String::new(),
                error: Some(err.to_string()),
            }),
        }
    });

    match handle.await {
        Ok(result) => result,
        Err(join_err) => {
            let msg = if join_err.is_panic() {
                let payload = join_err.into_panic();
                panic_payload_to_string(payload)
            } else {
                "execute_tool_call task cancelled".to_string()
            };
            Err(AgentErrorFFI::AgentError { message: msg })
        }
    }
}

/// Execute a single tool call on a tier-limited registry, optionally
/// intersected with an explicit allowlist.
#[uniffi::export(async_runtime = "tokio")]
pub async fn execute_tool_call_filtered(
    vault_path: String,
    tier: String,
    tool_name: String,
    input_json: String,
    allowed_tool_names: Option<Vec<String>>,
) -> Result<ToolExecutionResultFFI, AgentErrorFFI> {
    let handle = tokio::task::spawn(async move {
        let registry = build_registry_for_tool_tier(
            &vault_path,
            &tier,
            allowed_tool_names,
        )?;
        let input: serde_json::Value =
            serde_json::from_str(&input_json).map_err(|e| AgentErrorFFI::AgentError {
                message: format!("invalid input_json: {e}"),
            })?;

        match registry.execute_v2(&tool_name, &input).await {
            Ok(output) => Ok(ToolExecutionResultFFI {
                success: true,
                output_json: output,
                error: None,
            }),
            Err(err) => Ok(ToolExecutionResultFFI {
                success: false,
                output_json: String::new(),
                error: Some(err.to_string()),
            }),
        }
    });

    match handle.await {
        Ok(result) => result,
        Err(join_err) => {
            let msg = if join_err.is_panic() {
                let payload = join_err.into_panic();
                panic_payload_to_string(payload)
            } else {
                "execute_tool_call_filtered task cancelled".to_string()
            };
            Err(AgentErrorFFI::AgentError { message: msg })
        }
    }
}

fn build_registry_for_tool_tier(
    vault_path: &str,
    tier: &str,
    allowed_tool_names: Option<Vec<String>>,
) -> Result<ToolRegistry, AgentErrorFFI> {
    let vault = VaultStore::open(vault_path).map_err(|error| AgentErrorFFI::AgentError {
        message: format!("Failed to open vault: {error}"),
    })?;
    let tier_enum = crate::tools::registry::ToolTier::from_str_lossy(tier);
    let mut registry = ToolRegistry::with_tier(
        Arc::new(vault),
        true,
        Some(std::path::PathBuf::from(vault_path)),
        tier_enum,
    );
    if let Some(allowlist) = allowed_tool_names {
        registry.set_allowed_tool_names(Some(HashSet::from_iter(allowlist)));
    }
    Ok(registry)
}

#[cfg(test)]
mod tests {
    use super::resolve_provider_selection_preview;
    use super::list_tools_for_tier;

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

    #[test]
    fn list_tools_for_tier_hides_unsupported_image_generation() {
        let vault = tempfile::tempdir().unwrap();
        let tools = list_tools_for_tier(
            vault.path().to_str().unwrap().to_string(),
            "agent".to_string(),
        )
        .expect("tool list");

        assert!(!tools.iter().any(|tool| tool.name == "image_generate"));
    }
}
