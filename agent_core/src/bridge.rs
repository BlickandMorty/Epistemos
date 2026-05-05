use std::collections::HashSet;
use std::path::{Path, PathBuf};
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
use crate::storage::vault::{SearchResult, VaultBackend, VaultError, VaultStore};
use crate::tools::registry::{ToolHandler, ToolRegistry};
use async_trait::async_trait;

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
    /// Maximum estimated USD cost before the session pauses through the
    /// budget_gate ApprovalModal path. None or <= 0 means unlimited.
    pub max_cost_usd: Option<f64>,
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
    // N1 Phase 1 closure (MASTER_BUILD_PLAN.md:311) — surface the
    // Anthropic prompt-cache token counters that `merge_usage` in
    // providers/claude.rs:622-630 already accumulates into
    // `AgentResult.total_usage`. Default 0 for non-Anthropic providers
    // (OpenAI, Gemini, Perplexity) — they leave these fields untouched
    // in `TokenUsage` so the FFI value reflects "no cache activity"
    // honestly rather than a fabricated zero.
    pub cache_read_input_tokens: u32,
    pub cache_creation_input_tokens: u32,
}

#[uniffi::export]
pub fn agent_core_policy_profile() -> String {
    #[cfg(not(feature = "pro-build"))]
    {
        "mas_sandbox".to_string()
    }
    #[cfg(feature = "pro-build")]
    {
        "direct".to_string()
    }
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

#[derive(uniffi::Record, Debug, Clone, PartialEq, Eq)]
pub struct NightBrainAdmissionPreviewFFI {
    pub admitted: bool,
    pub reason: String,
    pub idle_threshold_seconds: u64,
    pub worker_pool_size: u32,
}

#[derive(uniffi::Record, Debug, Clone, PartialEq)]
pub struct RouteCaptureContractFFI {
    pub input_schema_id: String,
    pub output_schema_id: String,
    pub actions: Vec<String>,
    pub variant_a_floor: f64,
    pub variant_b_floor: f64,
    pub variant_c_floor: f64,
    pub merge_confidence_gate: f64,
    pub merge_staleness_hours: u64,
    pub create_folder_cluster_cosine: f64,
    pub create_folder_cluster_min_count: u64,
    pub reasoning_trace_max_chars: u64,
    pub review_inbox_path: String,
}

impl Default for RouteCaptureContractFFI {
    fn default() -> Self {
        Self {
            input_schema_id: String::new(),
            output_schema_id: String::new(),
            actions: Vec::new(),
            variant_a_floor: 0.0,
            variant_b_floor: 0.0,
            variant_c_floor: 0.0,
            merge_confidence_gate: 0.0,
            merge_staleness_hours: 0,
            create_folder_cluster_cosine: 0.0,
            create_folder_cluster_min_count: 0,
            reasoning_trace_max_chars: 0,
            review_inbox_path: String::new(),
        }
    }
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
            // Tunnel B.1 — discover URL-based MCP servers from
            // ~/.config/mcp/url_servers.json (+ project override). Anthropic's
            // API handles the connection remotely, so every tool those
            // servers expose becomes available to the model with zero
            // per-tool code on our side. Empty list → None so we don't emit
            // an empty `mcp_servers` field.
            mcp_servers: {
                let servers = crate::mcp::url_servers::discover_url_mcp_servers();
                if servers.is_empty() {
                    None
                } else {
                    Some(servers)
                }
            },
            parallel_tool_execution: true,
            permissions: PermissionConfig {
                auto_approve_read_only: ffi.auto_approve_reads,
                auto_approve_modification: ffi.auto_approve_writes,
                auto_approve_destructive: false,
            },
            vault_root: None,
            prompt_mode_override: None,
            max_cost_usd: ffi
                .max_cost_usd
                .filter(|budget| budget.is_finite() && *budget > 0.0),
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

#[uniffi::export]
pub fn nightbrain_canonical_task_names() -> Vec<String> {
    ffi_guard_value!(crate::nightbrain::canonical_task_names(), Vec::new())
}

#[uniffi::export]
pub fn nightbrain_preview_admission(
    idle_seconds: u64,
    thermal_nominal: bool,
    on_ac_or_battery_above_50: bool,
    preempted: bool,
) -> NightBrainAdmissionPreviewFFI {
    ffi_guard_value!(
        {
            let scheduler = crate::nightbrain::NightBrainScheduler::new();
            if preempted {
                scheduler.preempt();
            }
            let snapshot = crate::nightbrain::HostActivitySnapshot {
                idle_for: std::time::Duration::from_secs(idle_seconds),
                thermal_nominal,
                on_ac_or_battery_above_50,
            };
            let admitted = scheduler.should_admit(snapshot);
            let idle_threshold_seconds = crate::nightbrain::DEFAULT_IDLE_THRESHOLD.as_secs();
            let reason = if admitted {
                "admitted"
            } else if preempted {
                "preempted"
            } else if !thermal_nominal {
                "thermal_pressure"
            } else if !on_ac_or_battery_above_50 {
                "power_gate"
            } else if idle_seconds < idle_threshold_seconds {
                "not_idle"
            } else {
                "not_admitted"
            };
            NightBrainAdmissionPreviewFFI {
                admitted,
                reason: reason.to_string(),
                idle_threshold_seconds,
                worker_pool_size: scheduler.pool_size() as u32,
            }
        },
        NightBrainAdmissionPreviewFFI {
            admitted: false,
            reason: "panic".to_string(),
            idle_threshold_seconds: crate::nightbrain::DEFAULT_IDLE_THRESHOLD.as_secs(),
            worker_pool_size: 1,
        }
    )
}

/// Live-scheduler FFI: idempotently register canonical NightBrain tasks
/// against the process-global singleton scheduler. Called by Swift
/// `AppBootstrap` at startup. Returns the names that ended up
/// registered. Idempotent — re-calling does not produce duplicates or
/// errors. Closes the "NightBrain live Rust task registration not
/// fully wired" follow-up (2026-05-04).
#[uniffi::export]
pub fn nightbrain_register_canonical_tasks() -> Vec<String> {
    ffi_guard_value!(
        {
            let runtime = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .expect("nightbrain registration runtime");
            runtime.block_on(crate::nightbrain::live::register_canonical_tasks())
        },
        Vec::new()
    )
}

/// Live-scheduler FFI: snapshot the live scheduler's registered task
/// names. Cheap; no execution. Used by Swift diagnostics + the
/// Provenance Console NightBrain row.
#[uniffi::export]
pub fn nightbrain_live_registered_task_names() -> Vec<String> {
    ffi_guard_value!(
        {
            let runtime = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .expect("nightbrain registration runtime");
            runtime.block_on(crate::nightbrain::live::live_registered_task_names())
        },
        Vec::new()
    )
}

/// Live-scheduler FFI: trigger a live execution of every registered
/// task. Returns per-task outcome names; failures map to "error" strings
/// rather than throwing across the FFI. Honours cooperative cancellation
/// via `nightbrain_preempt_live_scheduler`.
#[uniffi::export]
pub fn nightbrain_run_live_registered_tasks() -> Vec<String> {
    ffi_guard_value!(
        {
            let runtime = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .expect("nightbrain registration runtime");
            let outcomes = runtime
                .block_on(crate::nightbrain::live::run_live_registered_tasks())
                .unwrap_or_default();
            outcomes
                .into_iter()
                .map(|outcome| {
                    let status = if outcome.outcome.completed {
                        "complete"
                    } else {
                        "preempted"
                    };
                    format!("{}:{}:{}", outcome.name, status, outcome.outcome.items_processed)
                })
                .collect()
        },
        Vec::new()
    )
}

/// Live-scheduler FFI: cancel any in-flight live tasks. Idempotent.
/// Real cancellation observation happens at task `ctx.is_cancelled()`
/// checkpoints.
#[uniffi::export]
pub fn nightbrain_preempt_live_scheduler() {
    ffi_guard_value!(
        {
            let runtime = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .expect("nightbrain registration runtime");
            runtime.block_on(crate::nightbrain::live::preempt_live_scheduler());
        },
        ()
    )
}

/// Live-scheduler FFI: reset the cancellation token so the next
/// admission window can run.
#[uniffi::export]
pub fn nightbrain_reset_live_scheduler() {
    ffi_guard_value!(
        {
            let runtime = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .expect("nightbrain registration runtime");
            runtime.block_on(crate::nightbrain::live::reset_live_scheduler());
        },
        ()
    )
}

fn route_action_wire(action: crate::route::Action) -> String {
    serde_json::to_value(action)
        .ok()
        .and_then(|value| value.as_str().map(str::to_owned))
        .unwrap_or_default()
}

#[uniffi::export]
pub fn route_capture_contract() -> RouteCaptureContractFFI {
    ffi_guard_value!(
        {
            RouteCaptureContractFFI {
                input_schema_id: crate::route::ROUTE_INPUT_V1_ID.to_string(),
                output_schema_id: crate::route::ROUTE_OUTPUT_V1_ID.to_string(),
                actions: vec![
                    route_action_wire(crate::route::Action::Place),
                    route_action_wire(crate::route::Action::MergeIntoExistingNote),
                    route_action_wire(crate::route::Action::CreateFolder),
                    route_action_wire(crate::route::Action::Defer),
                ],
                variant_a_floor: crate::route::VARIANT_A_FLOOR,
                variant_b_floor: crate::route::VARIANT_B_FLOOR,
                variant_c_floor: crate::route::VARIANT_C_FLOOR,
                merge_confidence_gate: crate::route::MERGE_CONFIDENCE_GATE,
                merge_staleness_hours: crate::route::MERGE_STALENESS_HOURS,
                create_folder_cluster_cosine: crate::route::CREATE_FOLDER_CLUSTER_COSINE,
                create_folder_cluster_min_count: crate::route::CREATE_FOLDER_CLUSTER_MIN_COUNT
                    as u64,
                reasoning_trace_max_chars: crate::route::REASONING_TRACE_MAX_CHARS as u64,
                review_inbox_path: "_inbox/review/".to_string(),
            }
        },
        RouteCaptureContractFFI::default()
    )
}

#[uniffi::export]
pub fn route_variant_b_schema_json(vault_paths: Vec<String>) -> Result<String, AgentErrorFFI> {
    ffi_guard_sync!({
        let schema = crate::route::variant_b::build_route_grammar_schema(&vault_paths);
        serde_json::to_string(&schema).map_err(|error| AgentErrorFFI::AgentError {
            message: format!("Route schema serialization failed: {error}"),
        })
    })
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
    // Tunnel B.2 — connect to every stdio MCP server the user has
    // configured under ~/.config/mcp/servers.json (or .epistemos/mcp.json)
    // and register their advertised tools. Errors are logged and the
    // remaining servers still register, so a single bad entry can't
    // block the agent from coming up.
    #[cfg(feature = "pro-build")]
    let _ = crate::tools::stdio_mcp::register_discovered_stdio_mcp_tools(&mut tool_registry).await;

    // Install the caller-provided per-tool allowlist (Phase 5 authority
    // boundary: Agent Command Center tool toggles become authoritative on
    // the runtime path here).
    if let Some(allowed) = &tool_config.allowed_tool_names {
        let set: std::collections::HashSet<String> = allowed.iter().cloned().collect();
        tool_registry.set_allowed_tool_names(Some(set));
    }
    #[cfg(feature = "pro-build")]
    tool_registry.register_delegate_task_tool(Arc::clone(&provider), 0);
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

    let session_start = std::time::Instant::now();
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
    let session_duration_ms = session_start.elapsed().as_millis() as u64;
    tracing::info!(session_id = %session_id, session_duration_ms, "agent_session_complete");
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
                cache_read_input_tokens: result.total_usage.cache_read_input_tokens,
                cache_creation_input_tokens: result.total_usage.cache_creation_input_tokens,
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

#[cfg(debug_assertions)]
#[derive(uniffi::Record)]
pub struct R15TrueRustCallbackLoopBenchmarkFFI {
    pub callbacks_emitted: u32,
    pub payload_bytes_emitted: u64,
}

#[cfg(debug_assertions)]
#[uniffi::export]
pub fn run_r15_true_rust_callback_loop_benchmark(
    delegate: Box<dyn AgentEventDelegate>,
    iterations: u32,
    payload: String,
) -> R15TrueRustCallbackLoopBenchmarkFFI {
    ffi_guard_value!(
        {
            let payload = if payload.is_empty() {
                "true_rust_callback_loop".to_string()
            } else {
                payload
            };
            let payload_bytes = payload.as_bytes().len() as u64;

            for _ in 0..iterations {
                delegate.on_text_delta(payload.clone());
            }

            R15TrueRustCallbackLoopBenchmarkFFI {
                callbacks_emitted: iterations,
                payload_bytes_emitted: payload_bytes.saturating_mul(iterations as u64),
            }
        },
        R15TrueRustCallbackLoopBenchmarkFFI {
            callbacks_emitted: 0,
            payload_bytes_emitted: 0,
        }
    )
}

/// Result of a `respond_to_memory_pressure` call. Lets the Swift caller
/// log the gain (e.g. via OSLog) so the developer panel + signposters
/// can attribute reclaimed memory to the pressure event.
#[derive(uniffi::Record)]
pub struct MemoryPressureReliefFFI {
    pub segments_evicted: u32,
    pub segment_bytes_freed: u64,
    pub sessions_pruned: u32,
}

/// Single entry point the Swift `DispatchSourceMemoryPressure` handler
/// calls when macOS signals memory pressure. Two levels:
///
/// - **1 (warning)**: drop ShmPool segments older than 60s, prune
///   finished sessions older than 5 min. Conservative — keeps active
///   work intact.
/// - **2 (critical)**: cleanup_all on ShmPool, prune all finished
///   sessions regardless of age. Aggressive — caller has signaled the
///   system is about to thrash.
///
/// Any other value collapses to warning. Returns the gain so the
/// caller can log "we reclaimed N MB after a memory-pressure event".
#[uniffi::export]
pub fn respond_to_memory_pressure(level: u8) -> MemoryPressureReliefFFI {
    use crate::shared_memory::ShmPool;
    use std::time::Duration;

    ffi_guard_value!(
        {
            let critical = level == 2;
            let (segments_evicted, bytes_freed) = if critical {
                // Total bytes BEFORE cleanup_all so the caller can log
                // the freed amount; cleanup_all drops the registry so
                // we can't read it after.
                let bytes_before = ShmPool::total_bytes();
                let count = ShmPool::cleanup_all();
                (count, bytes_before as u64)
            } else {
                let (count, bytes) = ShmPool::evict_stale(Duration::from_secs(60));
                (count, bytes as u64)
            };

            let sessions_pruned = if critical {
                GlobalSessions::prune_finished(Duration::from_secs(0))
            } else {
                GlobalSessions::prune_finished(Duration::from_secs(300))
            };

            MemoryPressureReliefFFI {
                segments_evicted: segments_evicted as u32,
                segment_bytes_freed: bytes_freed,
                sessions_pruned: sessions_pruned as u32,
            }
        },
        MemoryPressureReliefFFI {
            segments_evicted: 0,
            segment_bytes_freed: 0,
            sessions_pruned: 0,
        }
    )
}

// MARK: - Resonance Gate τ + π + λ daemon (Core)
//
// Doctrine §4.1 Core entry: τ (Kleene K3 truth) + π (prime/composite/gap
// classification over 9 typed claims) + λ (residency target L0–L3 + L7).
// Pro tier extends with δ + ρ; Research tier extends with κ + η. Both
// future tiers add separate FFI surfaces.
//
// JSON contract:
//   in:  agent_core::resonance::Claim (serde-derived)
//   out: agent_core::resonance::ResonanceSignatureCore (serde-derived)
//
// CPU-only, synchronous, < 100 µs/token target per doctrine §4.1. The
// Swift side mirrors the same compute logic in `ResonanceService.swift`
// for offline previews; this FFI is the authoritative path once wired.

#[uniffi::export]
pub fn compute_resonance_signature_core(claim_json: String) -> Result<String, AgentErrorFFI> {
    ffi_guard_sync!({
        let claim: crate::resonance::Claim =
            serde_json::from_str(&claim_json).map_err(|err| AgentErrorFFI::AgentError {
                message: format!("Resonance Gate: invalid claim JSON: {err}"),
            })?;
        let signature = crate::resonance::compute_signature_core(&claim);
        serde_json::to_string(&signature).map_err(|err| AgentErrorFFI::AgentError {
            message: format!("Resonance Gate: signature serialization failed: {err}"),
        })
    })
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
        crate::command_center::compile_from_json(&input_json)
            .map_err(|message| AgentErrorFFI::AgentError { message })
    })
}

// MARK: - Persistent PTY FFI

#[cfg(feature = "pro-build")]
#[derive(uniffi::Record)]
pub struct PtyConfigFFI {
    pub shell: String,
    pub initial_dir: Option<String>,
    pub cols: u16,
    pub rows: u16,
}

#[cfg(feature = "pro-build")]
#[derive(uniffi::Record)]
pub struct PtyOutputFFI {
    pub stdout: String,
    pub exit_hint: String,
    pub working_dir: String,
    pub duration_ms: u64,
}

/// Spawn a persistent PTY shell session tied to the given agent session.
/// Returns a unique `pty_id` for subsequent `pty_execute` / `pty_close` calls.
#[cfg(feature = "pro-build")]
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
#[cfg(feature = "pro-build")]
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
#[cfg(feature = "pro-build")]
#[uniffi::export]
pub fn pty_close(pty_id: String) {
    ffi_guard_value!(crate::pty::PtyPool::close(&pty_id), ());
}

/// Get the number of active PTY sessions (diagnostics).
#[cfg(feature = "pro-build")]
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
/// Used by native clients to write binary payloads into SHM without routing
/// through any external helper process.
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

struct FilesystemPreviewVault {
    vault_root: PathBuf,
}

impl FilesystemPreviewVault {
    fn new(vault_root: PathBuf) -> Self {
        Self { vault_root }
    }

    fn resolve_path(&self, relative: &str) -> Result<PathBuf, VaultError> {
        let sanitized = relative.trim_start_matches('/').replace("..", "");
        let absolute = self.vault_root.join(&sanitized);
        if !absolute.starts_with(&self.vault_root) {
            return Err(VaultError::PathTraversal(relative.to_string()));
        }
        Ok(absolute)
    }
}

#[async_trait]
impl VaultBackend for FilesystemPreviewVault {
    async fn hybrid_search(
        &self,
        _query: &str,
        _limit: usize,
        _tag_filter: &[String],
    ) -> Result<Vec<SearchResult>, VaultError> {
        Ok(Vec::new())
    }

    async fn read(&self, path: &str) -> Result<String, VaultError> {
        let absolute = self.resolve_path(path)?;
        if !absolute.exists() {
            return Err(VaultError::NotFound(path.to_string()));
        }
        Ok(std::fs::read_to_string(absolute)?)
    }

    async fn write(
        &self,
        _path: &str,
        _content: &str,
        _tags: Option<&[String]>,
        _append: bool,
    ) -> Result<(), VaultError> {
        Err(VaultError::DatabaseError(
            "preview vault is read-only".to_string(),
        ))
    }

    async fn list(&self, path_prefix: &str) -> Result<Vec<String>, VaultError> {
        let root = self.resolve_path(path_prefix)?;
        if !root.exists() {
            return Ok(Vec::new());
        }

        let mut entries = Vec::new();
        for entry in std::fs::read_dir(root)? {
            let entry = entry?;
            let entry_path = entry.path();
            let Ok(relative) = entry_path.strip_prefix(&self.vault_root) else {
                continue;
            };
            entries.push(relative.to_string_lossy().replace('\\', "/"));
        }
        entries.sort();
        Ok(entries)
    }

    async fn exists(&self, path: &str) -> Result<bool, VaultError> {
        Ok(self.resolve_path(path)?.exists())
    }

    async fn delete(&self, _path: &str) -> Result<bool, VaultError> {
        Err(VaultError::DatabaseError(
            "preview vault is read-only".to_string(),
        ))
    }
}

fn should_fallback_to_filesystem_preview(error: &VaultError, vault_root: &Path) -> bool {
    if !vault_root.is_dir() {
        return false;
    }

    match error {
        VaultError::IndexError(message) => {
            let normalized = message.to_ascii_lowercase();
            normalized.contains("lockbusy")
                || normalized.contains("failed to acquire lockfile")
                || normalized.contains("failed to acquire index lock")
                || normalized.contains("indexwriter")
        }
        _ => false,
    }
}

async fn build_preview_session_context_with_opener<F>(
    vault_path: &Path,
    objective: &str,
    max_tokens: usize,
    open_vault: F,
) -> Result<String, AgentErrorFFI>
where
    F: FnOnce(&str) -> Result<VaultStore, VaultError>,
{
    let vault_path_string = vault_path.to_string_lossy().into_owned();

    match open_vault(vault_path_string.as_str()) {
        Ok(vault) => {
            let ctx = crate::context_loader::load_session_context(
                &vault, vault_path, objective, max_tokens,
            )
            .await;
            Ok(ctx.to_xml())
        }
        Err(error) if should_fallback_to_filesystem_preview(&error, vault_path) => {
            tracing::warn!(
                "[ffi] preview_session_context falling back to filesystem reads: {}",
                error
            );
            let vault = FilesystemPreviewVault::new(vault_path.to_path_buf());
            let ctx = crate::context_loader::load_session_context(
                &vault, vault_path, objective, max_tokens,
            )
            .await;
            Ok(ctx.to_xml())
        }
        Err(error) => Err(AgentErrorFFI::AgentError {
            message: format!("Failed to open vault: {error}"),
        }),
    }
}

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
        let vault_root = PathBuf::from(vault_path);
        build_preview_session_context_with_opener(
            &vault_root,
            &objective,
            max_tokens as usize,
            VaultStore::open_read_only,
        )
        .await
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
        // Compact JSON — Swift parses this immediately, no human reads
        // the FFI return string. Pretty would burn CPU + waste bytes.
        serde_json::to_string(&topology).map_err(|e| AgentErrorFFI::AgentError {
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

        serde_json::to_string(&pattern).map_err(|e| AgentErrorFFI::AgentError {
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
                serde_json::to_string(&mutation).map_err(|e| AgentErrorFFI::AgentError {
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
            let router = crate::agent_runtime::skills::SkillRouter::load(vault_root);
            let registry = crate::agent_runtime::skills::SkillsRegistryStore::load(vault_root);
            let entries: Vec<crate::agent_runtime::skills::SkillRegistryEntry> =
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
            let registry = crate::agent_runtime::skills::SkillsRegistryStore::load(vault_root);
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

/// Build the canonical Hermes function-calling system prompt from JSON:
/// `{ tools, additional_instructions, knowledge_index }`.
#[uniffi::export]
pub fn hermes_build_system_prompt(input_json: String) -> Result<String, AgentErrorFFI> {
    ffi_guard_sync!({
        let input: crate::agent_runtime::prompt_format::HermesPromptInput =
            serde_json::from_str(&input_json).map_err(|error| AgentErrorFFI::AgentError {
                message: format!("invalid HermesPromptInput JSON: {error}"),
            })?;
        Ok(crate::agent_runtime::prompt_format::build_system_prompt(&input))
    })
}

/// Parse Hermes/Qwen-style `<tool_call>...</tool_call>` blocks. Returns a JSON
/// array of `{ name, arguments_json }` records so Swift can keep its existing
/// `ParsedToolCall` shape while the parser moves to Rust.
#[uniffi::export]
pub fn hermes_parse_tool_calls(text: String) -> Result<String, AgentErrorFFI> {
    ffi_guard_sync!({
        let calls = crate::agent_runtime::function_call::parse_tool_calls(&text);
        serde_json::to_string(&calls).map_err(|error| AgentErrorFFI::AgentError {
            message: format!("failed to serialize Hermes tool calls: {error}"),
        })
    })
}

#[derive(uniffi::Record, Debug, Clone, PartialEq)]
pub struct SkillDescriptorFFI {
    pub name: String,
    pub description: String,
    pub triggers: Vec<String>,
    pub file_path: String,
}

#[derive(uniffi::Record, Debug, Clone, PartialEq)]
pub struct ProcedureFFI {
    pub skill_name: String,
    pub invocation_context_hash: String,
    pub steps_taken: Vec<String>,
    pub outcome_summary: String,
    pub duration_ms: u64,
    pub error_mode: Option<String>,
    pub succeeded: bool,
    pub occurred_at_unix_seconds: i64,
    pub score: f64,
}

#[derive(uniffi::Record, Debug, Clone, PartialEq)]
pub struct SkillOutcomeFFI {
    pub invocation_context_hash: String,
    pub steps_taken: Vec<String>,
    pub outcome_summary: String,
    pub duration_ms: u64,
    pub error_mode: Option<String>,
    pub succeeded: bool,
    pub occurred_at_unix_seconds: i64,
}

#[derive(uniffi::Record, Debug, Clone, PartialEq)]
pub struct SkillResultFFI {
    pub skill_name: String,
    pub succeeded: bool,
    pub output_json: String,
    pub steps_taken: Vec<String>,
    pub error: Option<String>,
}

#[derive(Debug, serde::Deserialize)]
struct HermesSkillFrontmatter {
    #[serde(default)]
    steps: Vec<HermesSkillStepSpec>,
    metadata: Option<HermesSkillMetadata>,
}

#[derive(Debug, serde::Deserialize)]
struct HermesSkillMetadata {
    epistemos: Option<HermesSkillEpistemosMetadata>,
}

#[derive(Debug, serde::Deserialize)]
struct HermesSkillEpistemosMetadata {
    #[serde(default)]
    steps: Vec<HermesSkillStepSpec>,
}

#[derive(Debug, Clone, serde::Deserialize)]
struct HermesSkillStepSpec {
    #[serde(alias = "name")]
    tool: String,
    #[serde(default, alias = "args")]
    arguments: serde_json::Value,
}

#[uniffi::export]
pub fn list_skills(profile_id: String) -> Result<Vec<SkillDescriptorFFI>, AgentErrorFFI> {
    ffi_guard_sync!({
        let router = crate::agent_runtime::skills::SkillRouter::load(std::path::Path::new(&profile_id));
        Ok(router
            .skills()
            .iter()
            .map(|skill| SkillDescriptorFFI {
                name: skill.name.clone(),
                description: skill.description.clone(),
                triggers: skill.triggers.clone(),
                file_path: skill.file_path.clone(),
            })
            .collect())
    })
}

#[uniffi::export(async_runtime = "tokio")]
pub async fn invoke_skill(
    profile_id: String,
    skill_name: String,
    args: String,
) -> Result<SkillResultFFI, AgentErrorFFI> {
    let skill_name_for_join = skill_name.clone();
    let handle =
        tokio::task::spawn(async move { invoke_skill_inner(profile_id, skill_name, args).await });

    match handle.await {
        Ok(result) => result,
        Err(join_error) => {
            let msg = if join_error.is_panic() {
                panic_payload_to_string(join_error.into_panic())
            } else {
                "invoke_skill task cancelled".to_string()
            };
            Err(AgentErrorFFI::AgentError {
                message: format!(
                    "Hermes skill invocation failed for '{skill_name_for_join}': {msg}"
                ),
            })
        }
    }
}

#[uniffi::export]
pub fn write_procedure(procedure: ProcedureFFI) -> Result<(), AgentErrorFFI> {
    ffi_guard_sync!({
        let store = open_hermes_procedural_memory()?;
        store
            .record_outcome(&procedure_ffi_to_record(procedure))
            .map_err(|error| AgentErrorFFI::AgentError {
                message: format!("failed to write Hermes procedure: {error}"),
            })
    })
}

#[uniffi::export]
pub fn record_skill_outcome(
    skill_name: String,
    outcome: SkillOutcomeFFI,
) -> Result<(), AgentErrorFFI> {
    ffi_guard_sync!({
        write_procedure(ProcedureFFI {
            skill_name,
            invocation_context_hash: outcome.invocation_context_hash,
            steps_taken: outcome.steps_taken,
            outcome_summary: outcome.outcome_summary,
            duration_ms: outcome.duration_ms,
            error_mode: outcome.error_mode,
            succeeded: outcome.succeeded,
            occurred_at_unix_seconds: outcome.occurred_at_unix_seconds,
            score: 0.0,
        })
    })
}

#[uniffi::export]
pub fn recall_procedure(
    skill_name: String,
    context_hash: String,
) -> Result<Option<ProcedureFFI>, AgentErrorFFI> {
    ffi_guard_sync!({
        let store = open_hermes_procedural_memory()?;
        let now = current_unix_seconds();
        let mut recalled = store
            .recall(&skill_name, &context_hash, 1, now)
            .map_err(|error| AgentErrorFFI::AgentError {
                message: format!("failed to recall Hermes procedure: {error}"),
            })?;
        Ok(recalled.pop().map(|recall| {
            let mut procedure = record_to_procedure_ffi(recall.record);
            procedure.score = recall.score;
            procedure
        }))
    })
}

async fn invoke_skill_inner(
    profile_id: String,
    skill_name: String,
    args: String,
) -> Result<SkillResultFFI, AgentErrorFFI> {
    let profile_path = std::path::PathBuf::from(&profile_id);
    let router = crate::agent_runtime::skills::SkillRouter::load(&profile_path);
    let skill = router
        .skills()
        .iter()
        .find(|skill| skill.name == skill_name)
        .cloned()
        .ok_or_else(|| AgentErrorFFI::AgentError {
            message: format!("Hermes skill '{skill_name}' was not found in profile '{profile_id}'"),
        })?;

    let arguments: serde_json::Value =
        serde_json::from_str(&args).map_err(|error| AgentErrorFFI::AgentError {
            message: format!("invalid skill args JSON: {error}"),
        })?;
    let skill_content =
        std::fs::read_to_string(&skill.file_path).map_err(|error| AgentErrorFFI::AgentError {
            message: format!("failed to read Hermes skill '{}': {error}", skill.name),
        })?;
    let steps = extract_hermes_skill_steps(&skill_content);

    if steps.is_empty() {
        return Ok(SkillResultFFI {
            skill_name: skill.name.clone(),
            succeeded: true,
            output_json: serde_json::json!({
                "skill_name": skill.name,
                "description": skill.description,
                "arguments": arguments,
                "instruction": skill.body,
                "step_results": [],
            })
            .to_string(),
            steps_taken: vec!["load_skill".to_string()],
            error: None,
        });
    }

    let mut steps_taken = Vec::with_capacity(steps.len());
    let mut step_results = Vec::with_capacity(steps.len());
    for step in steps {
        let tool_name = step.tool.trim();
        if tool_name.is_empty() {
            let message = "Hermes skill step has an empty tool name".to_string();
            return Ok(SkillResultFFI {
                skill_name: skill.name,
                succeeded: false,
                output_json: serde_json::json!({
                    "skill_name": skill_name,
                    "arguments": arguments,
                    "step_results": step_results,
                })
                .to_string(),
                steps_taken,
                error: Some(message),
            });
        }
        let step_arguments = if step.arguments.is_null() {
            arguments.clone()
        } else {
            step.arguments
        };
        steps_taken.push(tool_name.to_string());
        match execute_hermes_skill_step(&profile_path, tool_name, &step_arguments).await {
            Ok(output) => {
                let parsed_output = serde_json::from_str::<serde_json::Value>(&output)
                    .unwrap_or_else(|_| serde_json::json!({ "raw": output }));
                step_results.push(serde_json::json!({
                    "tool": tool_name,
                    "input": step_arguments,
                    "output": parsed_output,
                    "success": true,
                }));
            }
            Err(error) => {
                let message = error.to_string();
                step_results.push(serde_json::json!({
                    "tool": tool_name,
                    "input": step_arguments,
                    "success": false,
                    "error": message,
                }));
                return Ok(SkillResultFFI {
                    skill_name: skill.name,
                    succeeded: false,
                    output_json: serde_json::json!({
                        "skill_name": skill_name,
                        "arguments": arguments,
                        "step_results": step_results,
                    })
                    .to_string(),
                    steps_taken,
                    error: Some(message),
                });
            }
        }
    }

    Ok(SkillResultFFI {
        skill_name: skill.name,
        succeeded: true,
        output_json: serde_json::json!({
            "skill_name": skill_name,
            "arguments": arguments,
            "step_results": step_results,
        })
        .to_string(),
        steps_taken,
        error: None,
    })
}

async fn execute_hermes_skill_step(
    profile_path: &std::path::Path,
    tool_name: &str,
    arguments: &serde_json::Value,
) -> Result<String, AgentErrorFFI> {
    let skills_dir = profile_path.join("skills");
    match tool_name {
        "skills_list" => {
            let handler = crate::agent_runtime::skills::SkillsListHandler::with_dir(skills_dir);
            handler
                .execute(arguments)
                .await
                .map_err(|error| AgentErrorFFI::AgentError {
                    message: format!("skills_list failed: {error}"),
                })
        }
        "skill_view" => {
            let handler = crate::agent_runtime::skills::SkillViewHandler::with_dir(skills_dir);
            handler
                .execute(arguments)
                .await
                .map_err(|error| AgentErrorFFI::AgentError {
                    message: format!("skill_view failed: {error}"),
                })
        }
        "skill_manage" => Err(AgentErrorFFI::AgentError {
            message: "skill_manage requires the Sovereign Gate promotion path, not direct invoke_skill execution".to_string(),
        }),
        other => {
            let registry = build_registry_for_tool_tier(
                &profile_path.display().to_string(),
                "agent",
                other,
                Some(vec![other.to_string()]),
            )?;
            registry
                .execute(other, arguments)
                .await
                .map_err(|error| AgentErrorFFI::AgentError {
                    message: format!("{other} failed: {error}"),
                })
        }
    }
}

fn extract_hermes_skill_steps(content: &str) -> Vec<HermesSkillStepSpec> {
    let trimmed = content.trim_start();
    if !trimmed.starts_with("---") {
        return Vec::new();
    }
    let Some(end) = trimmed[3..].find("\n---") else {
        return Vec::new();
    };
    let yaml = &trimmed[3..3 + end];
    let Ok(frontmatter) = serde_yaml::from_str::<HermesSkillFrontmatter>(yaml) else {
        return Vec::new();
    };
    if !frontmatter.steps.is_empty() {
        return frontmatter.steps;
    }
    frontmatter
        .metadata
        .and_then(|metadata| metadata.epistemos)
        .map(|epistemos| epistemos.steps)
        .unwrap_or_default()
}

fn open_hermes_procedural_memory(
) -> Result<crate::agent_runtime::procedural_memory::ProceduralMemoryStore, AgentErrorFFI> {
    crate::agent_runtime::procedural_memory::ProceduralMemoryStore::open(hermes_procedural_memory_path())
        .map_err(|error| AgentErrorFFI::AgentError {
            message: format!("failed to open Hermes procedural memory: {error}"),
        })
}

fn hermes_procedural_memory_path() -> PathBuf {
    if let Ok(path) = std::env::var("EPISTEMOS_PROCEDURAL_MEMORY_DB") {
        return PathBuf::from(path);
    }
    let mut base = dirs::home_dir().unwrap_or_else(|| PathBuf::from("."));
    base.push(".epistemos");
    base.push("procedural_memory.sqlite");
    base
}

fn procedure_ffi_to_record(
    procedure: ProcedureFFI,
) -> crate::agent_runtime::procedural_memory::ProcedureOutcomeRecord {
    crate::agent_runtime::procedural_memory::ProcedureOutcomeRecord {
        skill_name: procedure.skill_name,
        invocation_context_hash: procedure.invocation_context_hash,
        steps_taken: procedure.steps_taken,
        outcome_summary: procedure.outcome_summary,
        duration_ms: procedure.duration_ms,
        error_mode: procedure.error_mode,
        succeeded: procedure.succeeded,
        occurred_at_unix_seconds: procedure.occurred_at_unix_seconds,
    }
}

fn record_to_procedure_ffi(
    record: crate::agent_runtime::procedural_memory::ProcedureOutcomeRecord,
) -> ProcedureFFI {
    ProcedureFFI {
        skill_name: record.skill_name,
        invocation_context_hash: record.invocation_context_hash,
        steps_taken: record.steps_taken,
        outcome_summary: record.outcome_summary,
        duration_ms: record.duration_ms,
        error_mode: record.error_mode,
        succeeded: record.succeeded,
        occurred_at_unix_seconds: record.occurred_at_unix_seconds,
        score: 0.0,
    }
}

fn current_unix_seconds() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|duration| duration.as_secs() as i64)
        .unwrap_or(0)
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
        let vault =
            VaultStore::open_read_only(&vault_path).map_err(|error| AgentErrorFFI::AgentError {
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
        let registry = build_registry_for_tool_tier(&vault_path, &tier, "", allowed_tool_names)?;
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

        match registry.execute(&tool_name, &input).await {
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
        let registry =
            build_registry_for_tool_tier(&vault_path, &tier, &tool_name, allowed_tool_names)?;
        let input: serde_json::Value =
            serde_json::from_str(&input_json).map_err(|e| AgentErrorFFI::AgentError {
                message: format!("invalid input_json: {e}"),
            })?;

        match registry.execute(&tool_name, &input).await {
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
    tool_name: &str,
    allowed_tool_names: Option<Vec<String>>,
) -> Result<ToolRegistry, AgentErrorFFI> {
    let vault = if tool_requires_writable_vault_backend(tool_name) {
        VaultStore::open(vault_path)
    } else {
        VaultStore::open_read_only(vault_path)
    }
    .map_err(|error| AgentErrorFFI::AgentError {
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

fn tool_requires_writable_vault_backend(tool_name: &str) -> bool {
    matches!(tool_name, "vault_write")
}

// MARK: - Provenance Ledger FFI (V2 Lane 1 — read-only Rust ledger surface)
//
// Doctrine reference: V2_WIRE_UP_STATUS_2026_05_05.md Lane 1 — surface
// the Rust `agent_core::provenance::ledger::ClaimLedger` to the Swift
// Provenance Console alongside the existing local `EventStore` reads.
//
// This is a READ-ONLY bridge. Writes still flow through the Rust paths
// that own claim/evidence ingestion (agent_loop, retraction handlers).
// The Swift consumer only observes the ledger summary + recent events.
//
// Why read-only matters: the cognitive DAG doctrine §10 explicitly forbids
// parallel-store wiring before Phase 8.E mirroring is in place. A read-only
// surface avoids the parallel-write hazard while still removing the orphan
// status of the ledger from the app's perspective.

/// Process-global `ClaimLedger` instance.
///
/// **C2 (canonical-upgrade-audit 2026-05-05): RwLock not Mutex.**
/// All three FFI callers (`provenance_ledger_summary_json`,
/// `provenance_ledger_recent_events_json`, `provenance_ledger_snapshot_json`)
/// invoke read-only ledger methods (claim_count / evidence_count /
/// events_since / snapshot). Halo ledger ribbon polls every 1Hz;
/// Settings → Diagnostics polls every 5s; an FFI subscriber polling
/// reads under heavy agent traffic would serialize through a Mutex.
/// RwLock lets concurrent readers proceed; future writers (when the
/// dispatch architecture wires them — see Codex audit note below)
/// take exclusive access.
///
/// **Architectural finding flagged for Codex verification:** the
/// `cognitive_dag::dispatch` helpers (`on_evidence_committed`,
/// `on_claim_committed`) do NOT write to this global ledger — they
/// mirror to `cognitive_dag::dispatch::cognitive_dag_store()`
/// instead. So this ledger is *currently always empty* under the
/// FFI. Two interpretations:
///   1. Intended: this ledger is for FFI-driven writes (none yet),
///      and the FFI surface is forward-compat scaffolding.
///   2. Drift: dispatch should ALSO populate this ledger so the
///      Halo ribbon + Provenance Console show non-zero counts
///      under real agent traffic.
/// Either way, C2 (RwLock) is safe; the architectural decision
/// belongs to a separate audit pass.
fn provenance_ledger() -> &'static std::sync::RwLock<crate::provenance::ledger::ClaimLedger> {
    use std::sync::{OnceLock, RwLock};
    static LEDGER: OnceLock<RwLock<crate::provenance::ledger::ClaimLedger>> = OnceLock::new();
    LEDGER.get_or_init(|| RwLock::new(crate::provenance::ledger::ClaimLedger::new()))
}

/// Returns a JSON summary of the global Rust `ClaimLedger` for the Swift
/// Provenance Console. Shape:
///
/// ```json
/// {
///   "claim_count": 42,
///   "evidence_count": 17,
///   "event_count": 89
/// }
/// ```
///
/// Cheap O(1)-per-counter; no allocation beyond the small JSON output.
#[uniffi::export]
pub fn provenance_ledger_summary_json() -> Result<String, AgentErrorFFI> {
    ffi_guard_sync!({
        let ledger = provenance_ledger()
            .read()
            .map_err(|err| AgentErrorFFI::AgentError {
                message: format!("Provenance ledger lock poisoned: {err}"),
            })?;
        // Compose by hand instead of pulling in serde_json::json! to keep
        // the FFI surface boring + cheap.
        Ok(format!(
            r#"{{"claim_count":{},"evidence_count":{},"event_count":{}}}"#,
            ledger.claim_count(),
            ledger.evidence_count(),
            ledger.events_since(0).len(),
        ))
    })
}

/// Returns recent ledger events as a JSON array (newest first), capped at
/// `limit`. Each event is the canonical `LedgerEvent` serde shape from
/// `agent_core::provenance::ledger`. Shape:
///
/// ```json
/// [
///   {"sequence": 12, "kind": "evidence_committed", ...},
///   ...
/// ]
/// ```
///
/// `limit == 0` returns an empty array. Hard cap of 1000 events to keep
/// the FFI return string bounded.
#[uniffi::export]
pub fn provenance_ledger_recent_events_json(limit: u32) -> Result<String, AgentErrorFFI> {
    ffi_guard_sync!({
        let ledger = provenance_ledger()
            .read()
            .map_err(|err| AgentErrorFFI::AgentError {
                message: format!("Provenance ledger lock poisoned: {err}"),
            })?;
        let bounded = limit.min(1000) as usize;
        if bounded == 0 {
            return Ok("[]".to_string());
        }
        let mut events = ledger.events_since(0);
        // Newest first.
        events.reverse();
        events.truncate(bounded);
        serde_json::to_string(&events).map_err(|err| AgentErrorFFI::AgentError {
            message: format!("Provenance events serialization failed: {err}"),
        })
    })
}

/// Returns a deterministic snapshot of the global ledger as JSON. Shape
/// matches `agent_core::provenance::replay::LedgerSnapshot` (claims +
/// evidence + derivations + support_links, all sorted by id for byte-
/// equal serialization across calls).
///
/// Larger return than the summary; intended for occasional audit views
/// rather than every-tick UI refresh.
#[uniffi::export]
pub fn provenance_ledger_snapshot_json() -> Result<String, AgentErrorFFI> {
    ffi_guard_sync!({
        let ledger = provenance_ledger()
            .read()
            .map_err(|err| AgentErrorFFI::AgentError {
                message: format!("Provenance ledger lock poisoned: {err}"),
            })?;
        let snapshot = ledger.snapshot();
        serde_json::to_string(&snapshot).map_err(|err| AgentErrorFFI::AgentError {
            message: format!("Provenance snapshot serialization failed: {err}"),
        })
    })
}

// MARK: - In-process LSP runtime FFI (V2.3 Stage B)
//
// Doctrine reference: `docs/V2_3_LSP_MIGRATION_PLAN_2026_05_05.md`.
// Two thin entry points that drive the global LspKernel:
//   - lsp_send_message_json — push a JSON-RPC envelope into the
//     kernel; the kernel queues the response on its outbox.
//   - lsp_poll_response_json — pull the next outbound JSON-RPC
//     envelope off the outbox (empty string if none ready).
//
// Polling shape (vs. callback) is intentional. LSP is request /
// response, not truly streaming, so a Swift-side polling task is
// cheap and avoids exposing a UniFFI Callback surface. The Swift
// `RustLSPTransport` (Stage C) wraps this poll loop into the existing
// `LSPTransport` `messages: AsyncStream<LSPMessage>` shape.
//
// Both entries are gated behind the `lsp-runtime` cargo feature so
// the default MAS / Pro builds don't carry the LSP code unless
// explicitly enabled.

/// Push a JSON-RPC 2.0 envelope into the global LSP kernel. Returns
/// `Ok("")` on success — the response (if any) is queued for the
/// caller's next poll. Returns `Err(AgentErrorFFI)` only on
/// transport-level failures (mutex poison, etc.) — protocol errors
/// land as queued JSON-RPC error responses, not Err.
#[cfg(feature = "lsp-runtime")]
#[uniffi::export]
pub fn lsp_send_message_json(envelope_json: String) -> Result<String, AgentErrorFFI> {
    ffi_guard_sync!({
        let kernel = crate::lsp_runtime::global_kernel();
        match crate::lsp_runtime::decode_message(&envelope_json) {
            Ok(message) => {
                kernel
                    .send(message)
                    .map_err(|err| AgentErrorFFI::AgentError {
                        message: format!("LSP kernel send failed: {err}"),
                    })?;
                Ok(String::new())
            }
            Err(parse_error) => {
                // Decode failure is a protocol error — queue an error
                // response shaped like the kernel would produce so the
                // Swift consumer can iterate uniformly.
                let response = crate::lsp_runtime::LspMessage::ResponseError {
                    id: None,
                    error: parse_error,
                };
                kernel
                    .send(response)
                    .map_err(|err| AgentErrorFFI::AgentError {
                        message: format!("LSP kernel send failed: {err}"),
                    })?;
                Ok(String::new())
            }
        }
    })
}

/// Pull the next outbound JSON-RPC envelope from the global LSP
/// kernel. Returns `Ok("")` (empty string) when the outbox is empty
/// — the canonical "nothing yet" signal. The Swift `RustLSPTransport`
/// poll loop sleeps + retries when it sees empty, then yields
/// non-empty results onto the `messages: AsyncStream<LSPMessage>`.
#[cfg(feature = "lsp-runtime")]
#[uniffi::export]
pub fn lsp_poll_response_json() -> Result<String, AgentErrorFFI> {
    ffi_guard_sync!({
        let kernel = crate::lsp_runtime::global_kernel();
        match kernel
            .poll_response()
            .map_err(|err| AgentErrorFFI::AgentError {
                message: format!("LSP kernel poll failed: {err}"),
            })? {
            Some(message) => Ok(crate::lsp_runtime::encode_message(&message)),
            None => Ok(String::new()),
        }
    })
}

/// Diagnostic — current LSP kernel lifecycle state as a stable
/// string ("uninitialized" | "initialized" | "shutting_down" |
/// "exited" | "poisoned"). Used by Settings → Diagnostics + any
/// tests that want to assert lifecycle ordering.
#[cfg(feature = "lsp-runtime")]
#[uniffi::export]
pub fn lsp_lifecycle_state_debug() -> String {
    crate::lsp_runtime::global_kernel().lifecycle_state_debug().to_string()
}

// MARK: - Cognitive DAG observability FFI (V2 final lane — read-only)
//
// Doctrine reference: cognitive DAG doctrine §10 — "the seven existing
// subsystems remain authoritative throughout Phase 8.A-G; the DAG runs
// alongside, mirroring writes for one week before Phase 8.H flips
// authority." This FFI surface is READ-ONLY — Swift can observe the
// DAG's content but cannot write to it. Writes happen via the four
// DagMirror impls (Skills/Procedural/Provenance/Companion) wired into
// the Rust write paths. This is the doctrine-safe minimal surface that
// removes the cognitive_dag module's orphan status from the app's
// perspective ahead of the eventual Phase 8.H authority flip.

/// Process-global cognitive DAG store accessor. Re-exports the
/// canonical `cognitive_dag::dispatch::cognitive_dag_store()` so the
/// FFI surface and the auto-invoke dispatch helpers share the same
/// instance — Settings → Diagnostics + Halo ribbon reflect every
/// mirror write the moment it lands. (Earlier this lived as a local
/// OnceLock here; centralising in the dispatch module ensures there's
/// exactly one global store.)
fn cognitive_dag_store() -> &'static crate::cognitive_dag::storage::InMemoryDagStore {
    crate::cognitive_dag::dispatch::cognitive_dag_store()
}

/// Returns a JSON summary of the global cognitive DAG. Shape:
///
/// ```json
/// {
///   "node_count": 42,
///   "edge_count": 87,
///   "merkle_root_hex": "9f86d081884c7d65...",
///   "schema_version": 1
/// }
/// ```
///
/// Cheap O(1)-per-counter + one BLAKE3 walk over the snapshot (hot when
/// the DAG is large; the Swift consumer should poll on an interval, not
/// on every UI tick). The merkle_root_hex is the canonical content hash
/// — two stores with identical content produce identical hex.
#[uniffi::export]
pub fn cognitive_dag_stats_json() -> Result<String, AgentErrorFFI> {
    ffi_guard_sync!({
        use crate::cognitive_dag::storage::DagStore;
        let store = cognitive_dag_store();
        let snapshot = store.snapshot().map_err(|err| AgentErrorFFI::AgentError {
            message: format!("Cognitive DAG snapshot failed: {err}"),
        })?;
        // Hex-encode the merkle root by hand to keep the FFI small —
        // no hex crate dependency just for one 32-byte → 64-char render.
        let mut hex = String::with_capacity(64);
        for byte in snapshot.merkle_root.as_bytes().iter() {
            use std::fmt::Write;
            let _ = write!(&mut hex, "{:02x}", byte);
        }
        Ok(format!(
            r#"{{"node_count":{},"edge_count":{},"merkle_root_hex":"{}","schema_version":{}}}"#,
            snapshot.nodes.len(),
            snapshot.edges.len(),
            hex,
            snapshot.schema_version,
        ))
    })
}

#[cfg(test)]
mod tests {
    use super::build_preview_session_context_with_opener;
    use super::execute_tool_call_filtered;
    use super::list_tools_for_tier;
    use super::resolve_provider_selection_preview;
    use crate::storage::vault::VaultError;
    use serde_json::json;

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

    #[tokio::test]
    async fn preview_session_context_falls_back_when_index_lock_is_busy() {
        let vault = tempfile::tempdir().unwrap();
        std::fs::write(
            vault.path().join("SOUL.md"),
            "You are resuming a useful session.",
        )
        .unwrap();

        let preview = build_preview_session_context_with_opener(
            vault.path(),
            "summarize the current note",
            8_000,
            |_| {
                Err(VaultError::IndexError(
                    "Failed to acquire Lockfile: LockBusy".to_string(),
                ))
            },
        )
        .await
        .expect("preview should fall back to filesystem reads");

        assert!(preview.contains("<session-context>"));
        assert!(preview.contains("You are resuming a useful session."));
    }

    #[test]
    fn filtered_vault_write_uses_writable_backend() {
        let _env_guard = crate::test_support::env_lock();
        let _permission_guard = crate::test_support::permission_store_lock();
        let saved_enforce = std::env::var("EPISTEMOS_R5_ENFORCE").ok();
        std::env::set_var("EPISTEMOS_R5_ENFORCE", "0");

        let vault = tempfile::tempdir().expect("temp vault");
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("tokio runtime");
        let result = runtime
            .block_on(execute_tool_call_filtered(
                vault.path().to_string_lossy().to_string(),
                "agent".to_string(),
                "vault_write".to_string(),
                json!({
                    "path": "Inbox/Filtered.md",
                    "content": "filtered write ok"
                })
                .to_string(),
                Some(vec!["vault_write".to_string()]),
            ))
            .expect("filtered tool call should not throw");

        match saved_enforce {
            Some(value) => std::env::set_var("EPISTEMOS_R5_ENFORCE", value),
            None => std::env::remove_var("EPISTEMOS_R5_ENFORCE"),
        }

        assert!(
            result.success,
            "filtered vault_write should succeed with a writable backend, error={:?}",
            result.error
        );
        assert!(
            result.output_json.contains("\"verified\":true"),
            "vault_write should report readback verification: {}",
            result.output_json
        );
        let written =
            std::fs::read_to_string(vault.path().join("Inbox/Filtered.md")).expect("written note");
        assert_eq!(written, "filtered write ok");
    }
}
