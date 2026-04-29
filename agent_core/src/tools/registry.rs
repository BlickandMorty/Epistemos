use std::collections::{HashMap, HashSet};
use std::sync::Arc;

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use crate::storage::vault::{VaultBackend, VaultError};
use crate::types::ToolSchema;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum RiskLevel {
    ReadOnly,
    Modification,
    Destructive,
}

impl RiskLevel {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::ReadOnly => "read_only",
            Self::Modification => "modification",
            Self::Destructive => "destructive",
        }
    }
}

/// The capability tier a tool belongs to. Tiers form a ladder:
///   None < ChatLite < ChatPro < Agent < Full
/// A registry configured at tier T exposes every tool whose own tier is
/// `<= T`. This is how normal chat modes (fast/thinking/pro) can get a
/// curated set of read-only research tools without inheriting the full
/// destructive surface the agent loop uses.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub enum ToolTier {
    /// No tools — raw text generation only.
    None,
    /// Safe read-only research: web_search, vault_recall, read_file, think...
    ChatLite,
    /// Adds media + perception read-only tools on top of ChatLite.
    ChatPro,
    /// The agent-mode bundle: everything except deeply destructive ops.
    Agent,
    /// Full unrestricted registry.
    Full,
}

impl ToolTier {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::None => "none",
            Self::ChatLite => "chat_lite",
            Self::ChatPro => "chat_pro",
            Self::Agent => "agent",
            Self::Full => "full",
        }
    }

    pub fn from_str_lossy(s: &str) -> Self {
        match s.to_ascii_lowercase().as_str() {
            "none" | "off" | "disabled" => Self::None,
            "chat_lite" | "chat" | "fast" | "thinking" | "lite" => Self::ChatLite,
            "chat_pro" | "pro" | "research" => Self::ChatPro,
            "agent" => Self::Agent,
            "full" | "all" | "unrestricted" => Self::Full,
            _ => Self::Agent, // default: backwards-compatible
        }
    }
}

/// User-facing tool catalogs must hide capabilities the product does not
/// actually ship yet. Keep the handler registered for future wiring and
/// internal/manual use, but do not advertise it through surfaced catalogs
/// until the runtime lane is genuinely available.
pub fn is_user_visible_tool(tool_name: &str) -> bool {
    !matches!(tool_name, "image_generate")
}

pub struct RegisteredTool {
    pub name: String,
    pub description: String,
    pub parameters: Value,
    pub handler: Box<dyn ToolHandler>,
    pub risk_level: RiskLevel,
    /// Minimum tier required to call this tool. Defaults via
    /// `RegisteredTool::new(..)` to `ToolTier::Agent` so existing
    /// registrations don't change behavior until explicitly tiered.
    pub tier: ToolTier,
}

impl RegisteredTool {
    /// Build a registered tool from a schema + handler + risk level,
    /// defaulting the tier to `Agent`. Call `.with_tier()` on the result
    /// to downgrade to ChatLite / ChatPro.
    pub fn new(
        schema: crate::types::ToolSchema,
        handler: Box<dyn ToolHandler>,
        risk_level: RiskLevel,
    ) -> Self {
        Self {
            name: schema.name,
            description: schema.description,
            parameters: schema.parameters,
            handler,
            risk_level,
            tier: ToolTier::Agent,
        }
    }

    pub fn with_tier(mut self, tier: ToolTier) -> Self {
        self.tier = tier;
        self
    }
}

#[async_trait]
pub trait ToolHandler: Send + Sync {
    async fn execute(&self, input: &Value) -> Result<String, ToolError>;
}

#[derive(Debug, thiserror::Error)]
pub enum ToolError {
    #[error("invalid arguments: {0}")]
    InvalidArguments(String),
    #[error("execution failed: {0}")]
    ExecutionFailed(String),
    #[error("not found: {0}")]
    NotFound(String),
    #[error("permission denied")]
    PermissionDenied,
}

/// Phase 2G-3 — map from legacy underscored tool names to their canonical
/// dotted v2 names. The model emits names from `get_definitions()` which
/// still returns legacy schemas with underscored names (vault_search,
/// read_file, …); the v2 catalog uses the plan-canonical dotted form
/// (vault.search, file.read, …). Without this table, every legacy-named
/// dispatch in `execute_v2` would fall through to legacy `execute()`
/// instead of routing via `Tool::invoke`.
///
/// Naming notes:
/// - `think` is intentionally NOT aliased to `reason.think`. Legacy
///   `ThinkHandler` returns the input thought verbatim as plain text;
///   the native v2 `reason.think` (Phase 2E) returns
///   `{"thought": "..."}`. Aliasing them would change model-visible
///   output shape — a deliberate non-alias.
/// - `web_fetch` has no legacy registration; the v2 `web.fetch` is the
///   only entry, so no alias needed.
/// - `pkm_graph_neighbors` / `graph.neighbors` are the same handler
///   under two names; aliased so the model can keep using the legacy
///   form during the migration window.
const LEGACY_TO_V2_ALIASES: &[(&str, &str)] = &[
    ("vault_search", "vault.search"),
    ("vault_read", "vault.read"),
    ("vault_write", "vault.write"),
    ("bash_execute", "action.bash"),
    ("chunk_reduce", "chunk.reduce"),
    ("pkm_graph_neighbors", "graph.neighbors"),
    ("read_file", "file.read"),
    ("write_file", "file.write"),
    ("patch", "file.patch"),
    ("search_files", "file.search"),
    ("terminal", "action.terminal"),
    ("process", "system.process"),
    ("todo", "system.todo"),
    ("cronjob", "system.cron"),
    ("skills_list", "skills.list"),
    ("skill_view", "skills.view"),
    ("skill_manage", "skills.manage"),
    ("vault_recall", "knowledge.recall"),
    ("contradiction_check", "knowledge.contradiction_check"),
    ("neural_recall", "knowledge.neural_recall"),
    ("session_search", "knowledge.session_search"),
    ("graph_query", "graph.query"),
    ("vault_navigate", "graph.vault_navigate"),
    ("memory", "memory.curated"),
    ("web_search", "web.search"),
    ("web_extract", "web.extract"),
    ("web_crawl", "web.crawl"),
    ("apple_notes", "apple.notes"),
    ("apple_reminders", "apple.reminders"),
    ("apple_calendar", "apple.calendar"),
    ("apple_mail", "apple.mail"),
    ("send_message", "communication.send_message"),
    ("vision_analyze", "media.vision_analyze"),
    ("image_generate", "media.image_generate"),
    ("text_to_speech", "media.text_to_speech"),
    ("imessage", "communication.imessage"),
    ("imessage_contacts", "communication.imessage_contacts"),
    ("channel_contacts", "communication.channel_contacts"),
    ("route_private", "inference.route_private"),
    ("mcp_discover", "discovery.mcp_discover"),
    ("model_catalog", "discovery.model_catalog"),
    ("trajectory_export", "trajectory.export"),
    ("self_evolve", "intelligence.self_evolve"),
    ("mixture_of_minds", "intelligence.mixture_of_minds"),
    ("find_symbol", "workspace.find_symbol"),
    ("get_function_source", "workspace.get_function_source"),
    ("get_dependencies", "workspace.get_dependencies"),
    ("get_dependents", "workspace.get_dependents"),
    ("get_change_impact", "workspace.get_change_impact"),
    // Delegate-bound tools — only resolve when build_v2_delegate_catalog
    // has been wired into the registry. Currently the v2_catalog_cache
    // holds only `build_v2_catalog` output, so these aliases are no-ops
    // until Phase 2G-4 merges the delegate catalog. Listed here so the
    // table is the single source of truth for legacy→v2 name mapping.
    ("clarify", "clarify.ask"),
    ("perceive", "macos.perceive"),
    ("interact", "macos.interact"),
    ("screen_watch", "macos.screen_watch"),
    ("ssm_resume", "inference.ssm_resume"),
    ("constrained_generate", "inference.constrained_generate"),
    ("nightbrain_trigger", "intelligence.nightbrain_trigger"),
    ("inline_partner", "intelligence.inline_partner"),
];

/// Phase 2G-1 helper — convert a v2 `Tool::invoke` `result.result` Value
/// into the legacy `Result<String, ToolError>` shape `execute()` returns.
///
/// Special-cases the `LegacyToolAdapter` wrapper output: when the legacy
/// handler returned plain text (not JSON), the adapter wraps it as
/// `{"text": "..."}` so the schema validator stays happy. To present a
/// drop-in replacement for legacy `execute()`, we detect that exact
/// single-key shape and unwrap it. Object/array payloads round-trip
/// through `serde_json::to_string` unchanged.
fn stringify_v2_result(value: &Value) -> Result<String, ToolError> {
    if let Value::Object(map) = value {
        if map.len() == 1 {
            if let Some(Value::String(s)) = map.get("text") {
                return Ok(s.clone());
            }
        }
    }
    serde_json::to_string(value)
        .map_err(|e| ToolError::ExecutionFailed(format!("serialize tool result: {e}")))
}

pub struct ToolRegistry {
    tools: HashMap<String, RegisteredTool>,
    vault: Arc<dyn VaultBackend>,
    enable_bash: bool,
    /// Optional vault root directory. When set, Phase 2 tools that need a
    /// filesystem path (session_search, graph_query, vault_navigate, memory)
    /// are registered; otherwise they are silently skipped.
    vault_root_path: Option<std::path::PathBuf>,
    /// The active tier for this registry. `get_definitions()` and
    /// `execute()` filter against this so a ChatLite registry never exposes
    /// the terminal / send_message / skill_manage surface.
    active_tier: ToolTier,
    /// Explicit per-tool allowlist from the caller (e.g. the Agent Command
    /// Center). When `Some`, `get_definitions()` and `execute()` additionally
    /// require the tool name to be in this set — so even a tier-allowed tool
    /// is hidden/rejected unless the user opted in. `None` = no explicit
    /// restriction (tier is the only gate). This is how ACC's per-tool
    /// toggles become authoritative on the runtime path.
    allowed_tool_names: Option<HashSet<String>>,
    /// Phase 2G-1 lazy-init bridge to the Phase 2F v2 catalog.
    /// `execute_v2` is the new dispatch surface that walks
    /// `Tool::variants()` via `run_with_variants` (plan §3.2) instead of
    /// the legacy `ToolHandler::execute(input)` path. The map is built on
    /// first call from `self.build_v2_catalog()` and cached. Phase 2G-2
    /// switches `execute()` to call `execute_v2` internally; Phase 2G-3
    /// deletes the legacy `tools` map + ToolHandler trait + RegisteredTool.
    v2_catalog_cache: std::sync::OnceLock<HashMap<String, Arc<dyn super::Tool>>>,
}

impl ToolRegistry {
    pub fn new(vault: Arc<dyn VaultBackend>) -> Self {
        let mut registry = Self {
            tools: HashMap::new(),
            vault,
            enable_bash: true,
            vault_root_path: None,
            active_tier: ToolTier::Full,
            allowed_tool_names: None,
            v2_catalog_cache: std::sync::OnceLock::new(),
        };
        registry.register_default_tools();
        registry
    }

    pub fn with_bash_enabled(vault: Arc<dyn VaultBackend>, enable_bash: bool) -> Self {
        let mut registry = Self {
            tools: HashMap::new(),
            vault,
            enable_bash,
            vault_root_path: None,
            active_tier: ToolTier::Full,
            allowed_tool_names: None,
            v2_catalog_cache: std::sync::OnceLock::new(),
        };
        registry.register_default_tools();
        registry
    }

    /// Build a registry that knows its vault root on disk. This unlocks the
    /// Phase 2 tools that need a filesystem path (session_search, graph_query,
    /// vault_navigate, memory).
    pub fn with_vault_root(
        vault: Arc<dyn VaultBackend>,
        enable_bash: bool,
        vault_root: impl Into<std::path::PathBuf>,
    ) -> Self {
        let mut registry = Self {
            tools: HashMap::new(),
            vault,
            enable_bash,
            vault_root_path: Some(vault_root.into()),
            active_tier: ToolTier::Full,
            allowed_tool_names: None,
            v2_catalog_cache: std::sync::OnceLock::new(),
        };
        registry.register_default_tools();
        registry
    }

    /// Build a registry constrained to a specific tier. Tools whose
    /// individual tier is above the supplied one are still *registered*
    /// (so handlers that need state can be constructed once), but
    /// `get_definitions()` and `execute()` filter them out.
    pub fn with_tier(
        vault: Arc<dyn VaultBackend>,
        enable_bash: bool,
        vault_root: Option<impl Into<std::path::PathBuf>>,
        tier: ToolTier,
    ) -> Self {
        let mut registry = Self {
            tools: HashMap::new(),
            vault,
            enable_bash,
            vault_root_path: vault_root.map(Into::into),
            active_tier: tier,
            allowed_tool_names: None,
            v2_catalog_cache: std::sync::OnceLock::new(),
        };
        registry.register_default_tools();
        registry
    }

    /// Replace the active tier at runtime (useful for unit tests and for
    /// rebuilding the definitions list without re-registering).
    pub fn set_active_tier(&mut self, tier: ToolTier) {
        self.active_tier = tier;
    }

    pub fn active_tier(&self) -> ToolTier {
        self.active_tier
    }

    /// Install an explicit per-tool allowlist. When set, `get_definitions()`
    /// and `execute()` additionally require the tool name to be in this set.
    /// Passing `None` clears the allowlist (falls back to tier-only filtering).
    ///
    /// Phase 5 authority boundary: the Agent Command Center's per-tool toggle
    /// state is the authoritative source for this allowlist. See
    /// `CommandCenterRequestCompiler` on the Swift side.
    pub fn set_allowed_tool_names(&mut self, allowlist: Option<HashSet<String>>) {
        self.allowed_tool_names = allowlist;
    }

    /// Return the explicit allowlist, if any.
    pub fn allowlist(&self) -> Option<&HashSet<String>> {
        self.allowed_tool_names.as_ref()
    }

    /// True if the tool name is permitted by BOTH the active tier and the
    /// explicit allowlist (if set). This is the single authoritative check
    /// used by `get_definitions()`, `execute()`, and `allowed_tool_names()`.
    fn is_tool_permitted(&self, tool: &RegisteredTool) -> bool {
        if tool.tier > self.active_tier {
            return false;
        }
        if let Some(allowlist) = &self.allowed_tool_names {
            if !allowlist.contains(&tool.name) {
                return false;
            }
        }
        true
    }

    pub fn register(&mut self, tool: RegisteredTool) {
        self.tools.insert(tool.name.clone(), tool);
    }

    /// Return the schemas for every surfaced tool permitted by the current
    /// active tier AND the explicit allowlist (if set). This is what the
    /// agent loop sends to the model at each turn, so filtering here is how
    /// we hide destructive tools from chat-mode sessions, hide unshipped
    /// capabilities from the model-facing catalog, and honor the Agent
    /// Command Center's per-tool toggle choices.
    pub fn get_definitions(&self) -> Vec<ToolSchema> {
        self.tools
            .values()
            .filter(|tool| self.is_tool_permitted(tool))
            .filter(|tool| is_user_visible_tool(&tool.name))
            .map(|tool| ToolSchema {
                name: tool.name.clone(),
                description: tool.description.clone(),
                parameters: tool.parameters.clone(),
            })
            .collect()
    }

    /// Return every registered schema regardless of the active tier. Used by
    /// tooling that needs the full catalogue (docs generation, UI surface).
    pub fn get_all_definitions(&self) -> Vec<ToolSchema> {
        self.tools
            .values()
            .map(|tool| ToolSchema {
                name: tool.name.clone(),
                description: tool.description.clone(),
                parameters: tool.parameters.clone(),
            })
            .collect()
    }

    /// Return tool names permitted by the active tier AND the explicit
    /// allowlist (if set).
    pub fn allowed_tool_names(&self) -> Vec<String> {
        let mut names: Vec<String> = self
            .tools
            .values()
            .filter(|tool| self.is_tool_permitted(tool))
            .filter(|tool| is_user_visible_tool(&tool.name))
            .map(|tool| tool.name.clone())
            .collect();
        names.sort();
        names
    }

    pub fn get_risk_level(&self, name: &str) -> RiskLevel {
        self.tools
            .get(name)
            .map(|tool| tool.risk_level.clone())
            .unwrap_or(RiskLevel::ReadOnly)
    }

    pub fn get_tier(&self, name: &str) -> ToolTier {
        self.tools
            .get(name)
            .map(|tool| tool.tier)
            .unwrap_or(ToolTier::Agent)
    }

    pub async fn execute(&self, name: &str, input: &Value) -> Result<String, ToolError> {
        let tool = self
            .tools
            .get(name)
            .ok_or_else(|| ToolError::InvalidArguments(format!("unknown tool: {name}")))?;
        // Second layer of enforcement: even if a model guesses a tool name
        // not in get_definitions(), reject it here against tier AND the
        // explicit per-tool allowlist (if set).
        if !self.is_tool_permitted(tool) {
            return Err(ToolError::PermissionDenied);
        }
        tool.handler.execute(input).await
    }

    /// Phase 2G-1 — dispatch through the Phase 2F v2 catalog.
    ///
    /// Plan §3.2: walks `Tool::variants()` via `run_with_variants` (cache
    /// → health check → timed invoke → output-schema validation → status
    /// interpretation → cache write). Returns the canonical legacy
    /// `Result<String, ToolError>` shape so callers don't need to know
    /// about `ToolResult` / `ToolMeta` yet — that conversion happens
    /// inline below.
    ///
    /// The v2 catalog is built lazily on first call from
    /// `self.build_v2_catalog()` and cached in `v2_catalog_cache`. Tools
    /// added to the catalog after the first call are NOT re-resolved —
    /// register them BEFORE the first dispatch (mirrors the legacy
    /// `register` + `execute` order discipline).
    ///
    /// Permission gating: still consults the legacy `is_tool_permitted`
    /// path when the same tool name exists in the legacy registry, so
    /// active_tier + allowed_tool_names continue to govern v2 dispatch
    /// during the migration window. Pure-v2 names (e.g. dotted variants
    /// not present in legacy) bypass this check; they're guarded by the
    /// `Tool::profile()` invariant the runner already enforces, plus
    /// the eventual Phase 2G-2 Profile-aware gate.
    pub async fn execute_v2(&self, name: &str, input: &Value) -> Result<String, ToolError> {
        // Permission gate — preserve the legacy enforcement surface for
        // tool names that exist in both legacy and v2 (the common case
        // during 2F→2G migration).
        if let Some(legacy) = self.tools.get(name) {
            if !self.is_tool_permitted(legacy) {
                return Err(ToolError::PermissionDenied);
            }
        }

        let map = self.v2_catalog_cache.get_or_init(|| {
            let mut m: HashMap<String, Arc<dyn super::Tool>> = HashMap::new();
            for tool in self.build_v2_catalog() {
                let n = tool.name().to_string();
                m.insert(n, Arc::from(tool));
            }
            m
        });

        // Phase 2G-3: try the requested name in the v2 catalog first;
        // if missing, consult LEGACY_TO_V2_ALIASES to resolve a legacy
        // underscored name to its dotted v2 counterpart. Only after both
        // lookups miss do we fall back to legacy `execute()` — this
        // unifies dispatch through `Tool::invoke` for every name that
        // has a v2 entry, regardless of whether the model emitted the
        // legacy or dotted form.
        let resolved_name: &str = if map.contains_key(name) {
            name
        } else {
            match LEGACY_TO_V2_ALIASES.iter().find(|(legacy, _)| *legacy == name) {
                Some((_, dotted)) if map.contains_key(*dotted) => dotted,
                _ => return self.execute(name, input).await,
            }
        };

        // Permission gate runs again under the resolved name when the
        // dotted form happens to also be in the legacy registry (rare,
        // but handled defensively).
        if let Some(legacy) = self.tools.get(resolved_name) {
            if !self.is_tool_permitted(legacy) {
                return Err(ToolError::PermissionDenied);
            }
        }

        let tool = map
            .get(resolved_name)
            .expect("resolved name confirmed present above");

        // Default ToolCtx with a 30s latency budget per variant —
        // matches the legacy bash_execute timeout cap and gives space
        // for cloud-backed tools (web.search, communication.send_message,
        // intelligence.mixture_of_minds). Phase 2G-2 will let callers
        // pass an explicit ctx so per-variant budgets become tunable.
        let ctx = super::runner::default_ctx(std::time::Duration::from_secs(30));
        let result =
            super::runner::run_with_variants(tool.as_ref(), &ctx, input.clone()).await;

        // ToolResult → Result<String, ToolError> conversion.
        // Plan §3.1: result is a Value; legacy callers expect a String
        // (typically JSON-encoded). The conversion has to be a true
        // drop-in for legacy `execute()`:
        //   - Legacy handlers that returned plain text (e.g. ThinkHandler
        //     returning the prompt string verbatim) get wrapped by
        //     LegacyToolAdapter as `{"text": "..."}`. To restore parity,
        //     we unwrap a single-key {"text": String} object back to the
        //     inner string.
        //   - Object/array payloads (the common case — most legacy
        //     handlers internally call serde_json::to_string before
        //     returning) get re-stringified via serde_json::to_string,
        //     yielding the same shape callers already expect.
        //   - Native v2 tools (reason.think v2 etc.) return Value::Object
        //     directly; the {text} shape is rare unless intentional.
        //     The unwrap heuristic preserves their output too because
        //     a legitimate `{"text": "..."}` JSON output round-trips
        //     identically through the unwrap.
        match result.meta.status {
            super::Status::Ok => stringify_v2_result(&result.result),
            super::Status::Partial => {
                let confidence = result.meta.confidence.unwrap_or(0.0);
                if confidence > 0.7 {
                    stringify_v2_result(&result.result)
                } else {
                    Err(ToolError::ExecutionFailed(format!(
                        "tool {name} returned Partial below confidence threshold ({confidence})"
                    )))
                }
            }
            super::Status::Empty => stringify_v2_result(&result.result),
            super::Status::Error => {
                // The error envelope landed in result.result as
                // `{"error": "..."}`. Surface the message string when
                // we can find it; otherwise the whole envelope.
                let msg = result
                    .result
                    .get("error")
                    .and_then(|v| v.as_str())
                    .map(String::from)
                    .unwrap_or_else(|| result.result.to_string());
                Err(ToolError::ExecutionFailed(msg))
            }
        }
    }

    /// Get a reference to the underlying vault backend (for context loading).
    pub fn vault(&self) -> &dyn VaultBackend {
        &*self.vault
    }

    pub async fn vault_search(&self, query: &str, limit: usize) -> Result<Vec<String>, ToolError> {
        self.vault
            .search(query, limit)
            .await
            .map_err(map_vault_error)
    }

    /// Phase 2F build factory — returns the new plan-§3.1 `Tool` catalog
    /// driven by the existing handler logic via `LegacyToolAdapter`.
    /// Migration is incremental: 2F-2 ships 4 tools; 2F-3..N add the rest;
    /// 2G removes the legacy `ToolHandler` trait once the catalog is
    /// complete.
    pub fn build_v2_catalog(&self) -> Vec<Box<dyn super::Tool>> {
        use super::legacy_adapter::LegacyToolAdapter;
        use super::v2_catalog;
        let mut tools: Vec<Box<dyn super::Tool>> = vec![
            LegacyToolAdapter::boxed(
                v2_catalog::vault_search::SPEC,
                Arc::new(VaultSearchHandler {
                    vault: Arc::clone(&self.vault),
                }),
            ),
            LegacyToolAdapter::boxed(
                v2_catalog::vault_read::SPEC,
                Arc::new(VaultReadHandler {
                    vault: Arc::clone(&self.vault),
                }),
            ),
            LegacyToolAdapter::boxed(
                v2_catalog::vault_write::SPEC,
                Arc::new(VaultWriteHandler {
                    vault: Arc::clone(&self.vault),
                }),
            ),
            LegacyToolAdapter::boxed(
                v2_catalog::workspace_search::SPEC,
                Arc::new(super::workspace_search::WorkspaceSearchHandler),
            ),
            LegacyToolAdapter::boxed(
                v2_catalog::graph_neighbors::SPEC,
                Arc::new(GraphNeighborsHandler {
                    vault: Arc::clone(&self.vault),
                }),
            ),
            // Phase 2G-4 native Tool impl (no LegacyToolAdapter wrap).
            Box::new(super::chunk_reduce::ChunkReduceHandler) as Box<dyn super::Tool>,
            LegacyToolAdapter::boxed(
                v2_catalog::action_bash::SPEC,
                Arc::new(BashExecuteHandler),
            ),
            LegacyToolAdapter::boxed(
                v2_catalog::file_read::SPEC,
                Arc::new(super::filesystem::ReadFileHandler),
            ),
            LegacyToolAdapter::boxed(
                v2_catalog::file_write::SPEC,
                Arc::new(super::filesystem::WriteFileHandler),
            ),
            LegacyToolAdapter::boxed(
                v2_catalog::file_search::SPEC,
                Arc::new(super::filesystem::SearchFilesHandler),
            ),
            LegacyToolAdapter::boxed(
                v2_catalog::file_patch::SPEC,
                Arc::new(super::filesystem::PatchHandler),
            ),
            LegacyToolAdapter::boxed(
                v2_catalog::knowledge_recall::SPEC,
                Arc::new(super::knowledge::VaultRecallHandler::new(Arc::clone(&self.vault))),
            ),
            LegacyToolAdapter::boxed(
                v2_catalog::knowledge_contradiction::SPEC,
                Arc::new(super::knowledge::ContradictionCheckHandler::new(Arc::clone(&self.vault))),
            ),
            LegacyToolAdapter::boxed(
                v2_catalog::knowledge_neural_recall::SPEC,
                Arc::new(super::knowledge::NeuralRecallHandler::new(
                    Arc::clone(&self.vault),
                    Arc::clone(neural_cache()),
                )),
            ),
            // Phase 2G-4a CANARY: TodoHandler natively implements `Tool`
            // (see todo.rs), so the v2 catalog uses it directly without
            // the LegacyToolAdapter indirection. Other ~24 files follow
            // this same pattern in 2G-4b..z.
            Box::new(super::todo::TodoHandler) as Box<dyn super::Tool>,
            // Phase 2G-4 native Tool impls.
            Box::new(super::scheduling::CronJobHandler::new()) as Box<dyn super::Tool>,
            Box::new(super::terminal::TerminalHandler) as Box<dyn super::Tool>,
            Box::new(super::discovery::McpDiscoverHandler) as Box<dyn super::Tool>,
            LegacyToolAdapter::boxed(
                v2_catalog::media_text_to_speech::SPEC,
                Arc::new(super::media::TextToSpeechHandler),
            ),
        ];
        // discovery.model_catalog needs an HTTP client; if construction
        // fails (rare — only on reqwest TLS-init errors) we skip it
        // rather than poisoning the whole catalog. Mirrors the existing
        // legacy registration in register_phase_eight_discovery.
        // Phase 2G-4 native Tool impl. Construction can fail (HTTP TLS init).
        if let Ok(catalog_handler) = super::discovery::ModelCatalogHandler::new() {
            tools.push(Box::new(catalog_handler) as Box<dyn super::Tool>);
        }
        // Web family — same Ok-gating as the legacy
        // register_phase_three_web. web.fetch's `WebFetchTool::new()`
        // is infallible (`.expect()`s on reqwest init), so it's
        // unconditional.
        if let Ok(web_search) = super::web::WebSearchHandler::new() {
            tools.push(LegacyToolAdapter::boxed(
                v2_catalog::web_search::SPEC,
                Arc::new(web_search),
            ));
        }
        if let Ok(web_extract) = super::web::WebExtractHandler::new() {
            tools.push(LegacyToolAdapter::boxed(
                v2_catalog::web_extract::SPEC,
                Arc::new(web_extract),
            ));
        }
        if let Ok(web_crawl) = super::web::WebCrawlHandler::new() {
            tools.push(LegacyToolAdapter::boxed(
                v2_catalog::web_crawl::SPEC,
                Arc::new(web_crawl),
            ));
        }
        // Phase 2G-4 native Tool impl.
        tools.push(Box::new(super::web_fetch::WebFetchTool::new()) as Box<dyn super::Tool>);
        // Apple-app family — all unit-struct handlers; osascript spawns
        // gated by harden_cli_subprocess in security.rs.
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::apple_notes::SPEC,
            Arc::new(super::apple::AppleNotesHandler),
        ));
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::apple_reminders::SPEC,
            Arc::new(super::apple::AppleRemindersHandler),
        ));
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::apple_calendar::SPEC,
            Arc::new(super::apple::AppleCalendarHandler),
        ));
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::apple_mail::SPEC,
            Arc::new(super::apple::AppleMailHandler),
        ));
        // memory.curated — derive memory dir from vault root, falling
        // back to ~/.epistemos/memory then "./.epistemos-memory" so the
        // tool always registers (mirrors register_phase_two_memory).
        let memory_dir = if let Some(root) = self.vault_root_path.as_ref() {
            root.join(".epistemos").join("memory")
        } else if let Some(home) = dirs::home_dir() {
            home.join(".epistemos").join("memory")
        } else {
            std::path::PathBuf::from(".epistemos-memory")
        };
        // Phase 2G-4 native Tool impl.
        tools.push(Box::new(super::memory::MemoryTool::new(memory_dir)) as Box<dyn super::Tool>);
        // communication.send_message + media.vision_analyze +
        // media.image_generate + intelligence.mixture_of_minds — all
        // Result-returning HTTP-client constructors. Same Ok-gating as
        // legacy register_phase_six_communication / six_media /
        // seven_intelligence registration paths. media.image_generate
        // is the delegate-free fallback variant; the delegate-bound
        // override lands separately in build_v2_delegate_catalog (per
        // FINAL_SYNTHESIS §1 trust-boundary discipline — when the
        // delegate is in place, MLX lane is reachable in-process).
        // Phase 2G-4 native Tool impl. Construction can fail (HTTP client
        // init) so still Ok-gated.
        if let Ok(send_message) = super::communication::SendMessageHandler::new() {
            tools.push(Box::new(send_message) as Box<dyn super::Tool>);
        }
        if let Ok(vision_analyze) = super::media::VisionAnalyzeHandler::new() {
            tools.push(LegacyToolAdapter::boxed(
                v2_catalog::media_vision_analyze::SPEC,
                Arc::new(vision_analyze),
            ));
        }
        if let Ok(image_generate) = super::media::ImageGenerateHandler::new() {
            tools.push(LegacyToolAdapter::boxed(
                v2_catalog::media_image_generate::SPEC,
                Arc::new(image_generate),
            ));
        }
        if let Ok(mom) = super::intelligence::MixtureOfMindsHandler::new() {
            tools.push(LegacyToolAdapter::boxed(
                v2_catalog::intelligence_mixture_of_minds::SPEC,
                Arc::new(mom),
            ));
        }
        // Token-savior workspace tools — all unit struct handlers; the
        // input_schema is parsed from the existing TOOL_SCHEMA constants
        // so we don't fork the schema definition.
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::workspace_find_symbol::SPEC,
            Arc::new(super::workspace_search::FindSymbolHandler),
        ));
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::workspace_get_function_source::SPEC,
            Arc::new(super::workspace_search::GetFunctionSourceHandler),
        ));
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::workspace_get_dependencies::SPEC,
            Arc::new(super::workspace_search::GetDependenciesHandler),
        ));
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::workspace_get_dependents::SPEC,
            Arc::new(super::workspace_search::GetDependentsHandler),
        ));
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::workspace_get_change_impact::SPEC,
            Arc::new(super::workspace_search::GetChangeImpactHandler),
        ));
        // Browser family — all 11 share a single BrowserManager (per-call
        // ephemeral spawn; not always-on daemon per FINAL_SYNTHESIS §5.7).
        // Until Wave 6 BrowserEngine trait splits the adapters
        // (WebKit-baseline AppStoreSafe vs Obscura-experimental Pro), all
        // browser.* tools route through the legacy BrowserActionHandler.
        let browser_manager = super::browser::BrowserManager::new();
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::browser_navigate::SPEC,
            Arc::new(super::browser::BrowserActionHandler::new(
                browser_manager.clone(),
                super::browser::BrowserAction::Navigate,
            )),
        ));
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::browser_snapshot::SPEC,
            Arc::new(super::browser::BrowserActionHandler::new(
                browser_manager.clone(),
                super::browser::BrowserAction::Snapshot,
            )),
        ));
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::browser_click::SPEC,
            Arc::new(super::browser::BrowserActionHandler::new(
                browser_manager.clone(),
                super::browser::BrowserAction::Click,
            )),
        ));
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::browser_type::SPEC,
            Arc::new(super::browser::BrowserActionHandler::new(
                browser_manager.clone(),
                super::browser::BrowserAction::Type,
            )),
        ));
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::browser_scroll::SPEC,
            Arc::new(super::browser::BrowserActionHandler::new(
                browser_manager.clone(),
                super::browser::BrowserAction::Scroll,
            )),
        ));
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::browser_back::SPEC,
            Arc::new(super::browser::BrowserActionHandler::new(
                browser_manager.clone(),
                super::browser::BrowserAction::Back,
            )),
        ));
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::browser_press::SPEC,
            Arc::new(super::browser::BrowserActionHandler::new(
                browser_manager.clone(),
                super::browser::BrowserAction::Press,
            )),
        ));
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::browser_close::SPEC,
            Arc::new(super::browser::BrowserActionHandler::new(
                browser_manager.clone(),
                super::browser::BrowserAction::Close,
            )),
        ));
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::browser_get_images::SPEC,
            Arc::new(super::browser::BrowserActionHandler::new(
                browser_manager.clone(),
                super::browser::BrowserAction::GetImages,
            )),
        ));
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::browser_vision::SPEC,
            Arc::new(super::browser::BrowserActionHandler::new(
                browser_manager.clone(),
                super::browser::BrowserAction::Vision,
            )),
        ));
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::browser_console::SPEC,
            Arc::new(super::browser::BrowserActionHandler::new(
                browser_manager,
                super::browser::BrowserAction::Console,
            )),
        ));
        // inference.route_private — pure-Rust dimension classifier; no
        // delegate, no constructor failure.
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::inference_route_private::SPEC,
            Arc::new(super::inference::RoutePrivateHandler::new()),
        ));
        // communication.{imessage, imessage_contacts, channel_contacts} —
        // unit-struct handlers; iMessage send is Destructive but the
        // existing legacy permission gate fires regardless of the v2
        // surface choice.
        // Phase 2G-4 native Tool impls (no LegacyToolAdapter wrap).
        tools.push(Box::new(super::imessage::IMessageHandler) as Box<dyn super::Tool>);
        tools.push(
            Box::new(super::imessage_contacts::IMessageContactsHandler) as Box<dyn super::Tool>,
        );
        tools.push(
            Box::new(super::channel_contacts::ChannelContactsHandler) as Box<dyn super::Tool>,
        );
        // skills.{list, view, manage} — progressive-disclosure family.
        // skills.manage gates installs through the existing 40-rule
        // security scanner per plan §17 Compile-Verify-Mint.
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::skills_list::SPEC,
            Arc::new(super::skills::SkillsListHandler::new()),
        ));
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::skills_view::SPEC,
            Arc::new(super::skills::SkillViewHandler::new()),
        ));
        tools.push(LegacyToolAdapter::boxed(
            v2_catalog::skills_manage::SPEC,
            Arc::new(super::skills::SkillManageHandler::new()),
        ));
        // Phase 2G-4 native Tool impl — manages action.terminal PTYs.
        tools.push(Box::new(super::terminal::ProcessHandler) as Box<dyn super::Tool>);
        // trajectory.export needs the vault root for session-store reads.
        if let Some(root) = self.vault_root_path.clone() {
            tools.push(Box::new(super::trajectory::TrajectoryExportHandler::new(root.clone()))
                as Box<dyn super::Tool>);
            // intelligence.self_evolve also needs the vault root (it scans
            // session traces under it). Same gating.
            tools.push(LegacyToolAdapter::boxed(
                v2_catalog::intelligence_self_evolve::SPEC,
                Arc::new(super::intelligence::SelfEvolveHandler::new(root.clone())),
            ));
            // graph.{query, vault_navigate} + knowledge.session_search —
            // all walk the vault directory tree directly, so they need
            // the configured vault root. Mirrors register_phase_two_graph
            // and register_phase_two_knowledge gating.
            tools.push(LegacyToolAdapter::boxed(
                v2_catalog::graph_query::SPEC,
                Arc::new(super::graph::GraphQueryHandler::new(root.clone())),
            ));
            tools.push(LegacyToolAdapter::boxed(
                v2_catalog::graph_vault_navigate::SPEC,
                Arc::new(super::graph::VaultNavigateHandler::new(root.clone())),
            ));
            tools.push(LegacyToolAdapter::boxed(
                v2_catalog::knowledge_session_search::SPEC,
                Arc::new(super::knowledge::SessionSearchHandler::new(root)),
            ));
        }
        tools
    }

    /// Phase 2F-8 delegate-bound v2 catalog. Mirrors the legacy
    /// `register_delegate_tools` path — these tools cross UniFFI to the
    /// Swift side via `AgentEventDelegate` so they can only be wired
    /// after the delegate exists. The agent session calls this from
    /// `bridge.rs` once the delegate is constructed, in addition to
    /// `build_v2_catalog()`.
    ///
    /// Per FINAL_SYNTHESIS §2 layer 5 (motor) and CLAUDE.md "NO SIDECAR
    /// for INFERENCE": the inference-family tools (ssm_resume,
    /// constrained_generate) cross UniFFI but inference itself runs
    /// in-process on the Swift / MLX-Swift side — this is exactly the
    /// "one substrate, one trust boundary" invariant from §1 of the
    /// final synthesis.
    pub fn build_v2_delegate_catalog(
        &self,
        delegate: Arc<dyn crate::bridge::AgentEventDelegate>,
    ) -> Vec<Box<dyn super::Tool>> {
        use super::legacy_adapter::LegacyToolAdapter;
        use super::v2_catalog;
        vec![
            // Phase 2G-4 native Tool impl (no LegacyToolAdapter wrap).
            Box::new(super::clarify::ClarifyHandler::new(Arc::clone(&delegate)))
                as Box<dyn super::Tool>,
            LegacyToolAdapter::boxed(
                v2_catalog::macos_perceive::SPEC,
                Arc::new(super::macos::PerceiveHandler::new(Arc::clone(&delegate))),
            ),
            LegacyToolAdapter::boxed(
                v2_catalog::macos_interact::SPEC,
                Arc::new(super::macos::InteractHandler::new(Arc::clone(&delegate))),
            ),
            LegacyToolAdapter::boxed(
                v2_catalog::macos_screen_watch::SPEC,
                Arc::new(super::macos::ScreenWatchHandler::new(Arc::clone(&delegate))),
            ),
            LegacyToolAdapter::boxed(
                v2_catalog::inference_ssm_resume::SPEC,
                Arc::new(super::inference::SsmResumeHandler::new(Arc::clone(&delegate))),
            ),
            LegacyToolAdapter::boxed(
                v2_catalog::inference_constrained_generate::SPEC,
                Arc::new(super::inference::ConstrainedGenerateHandler::new(Arc::clone(&delegate))),
            ),
            LegacyToolAdapter::boxed(
                v2_catalog::intelligence_nightbrain_trigger::SPEC,
                Arc::new(super::intelligence::NightBrainTriggerHandler::new(Arc::clone(&delegate))),
            ),
            LegacyToolAdapter::boxed(
                v2_catalog::intelligence_inline_partner::SPEC,
                Arc::new(super::intelligence::InlinePartnerHandler::new(delegate)),
            ),
        ]
    }

    fn register_default_tools(&mut self) {
        self.register_vault_search();
        self.register_vault_read();
        self.register_vault_write();
        self.register_think_tool();
        self.register_chunk_reduce();
        self.register_workspace_search();
        if self.enable_bash {
            self.register_bash_execute();
        }
        self.register_pkm_graph_neighbors();

        // Phase 1 core tools (Hermes/OpenClaw parity)
        self.register_phase_one_filesystem();
        self.register_phase_one_terminal();
        self.register_phase_one_todo();
        self.register_phase_one_scheduling();
        self.register_phase_one_skills_progressive();

        // Phase 2 knowledge & memory tools (vault-native specialties)
        self.register_phase_two_knowledge();
        self.register_phase_two_graph();
        self.register_phase_two_memory();

        // Phase 3 web tools — replaces the legacy DuckDuckGo web_search.
        self.register_phase_three_web();

        // Phase 4 Apple app tools (pure Rust via osascript).
        self.register_phase_four_apple_apps();

        // Phase 5 inference specialties — route_private is pure Rust. The
        // Swift-dependent ones (ssm_resume, constrained_generate) are wired
        // in via register_delegate_tools().
        self.register_phase_five_route_private();

        // Phase 6 communication + media tools.
        self.register_phase_six_communication();
        self.register_phase_six_media();
        self.register_phase_six_imessage();

        // Phase 7 intelligence layer (pure-Rust parts).
        self.register_phase_seven_intelligence();

        // Phase 8 discovery + trajectory + skill marketplace (post-plan work
        // — comprehensive Hermes/OpenClaw parity pass). All read-only except
        // trajectory_export (Modification because it writes JSONL to disk).
        self.register_phase_eight_discovery();
        self.register_phase_eight_trajectory();

        // Tier rebalance: mark the read-only research tools as ChatLite so
        // normal chat (fast/thinking) can call them, and the cloud-heavy
        // read-only tools as ChatPro so the Pro mode picks them up too.
        self.apply_tier_overrides();
    }

    fn register_phase_eight_discovery(&mut self) {
        use crate::tools::discovery::{
            mcp_discover_schema, model_catalog_schema, McpDiscoverHandler, ModelCatalogHandler,
        };

        let mcp = mcp_discover_schema();
        self.register(RegisteredTool {
            name: mcp.name,
            description: mcp.description,
            parameters: mcp.parameters,
            handler: Box::new(McpDiscoverHandler),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::ChatPro,
        });

        match ModelCatalogHandler::new() {
            Ok(handler) => {
                let cat = model_catalog_schema();
                self.register(RegisteredTool {
                    name: cat.name,
                    description: cat.description,
                    parameters: cat.parameters,
                    handler: Box::new(handler),
                    risk_level: RiskLevel::ReadOnly,
                    tier: ToolTier::ChatLite,
                });
            }
            Err(e) => tracing::warn!("model_catalog registration skipped: {e}"),
        }
    }

    fn register_phase_eight_trajectory(&mut self) {
        use crate::tools::trajectory::{trajectory_export_schema, TrajectoryExportHandler};
        if let Some(root) = self.vault_root_path.clone() {
            let schema = trajectory_export_schema();
            self.register(RegisteredTool {
                name: schema.name,
                description: schema.description,
                parameters: schema.parameters,
                handler: Box::new(TrajectoryExportHandler::new(root)),
                risk_level: RiskLevel::Modification,
                tier: ToolTier::Agent,
            });
        }
    }

    /// Downgrade chat-safe tools from their default `Agent` tier so normal
    /// chat modes can see them. Only tools whose handlers are side-effect
    /// free (or have narrowly scoped side-effects like `think`) should be
    /// downgraded here.
    fn apply_tier_overrides(&mut self) {
        // Tier: ChatLite — safe for even the smallest local model.
        // These are the ones the user specifically called out (web_search,
        // vault_search, read_file, think) plus the obvious read-only cousins.
        const CHAT_LITE: &[&str] = &[
            // Research / web
            "web_search",
            "web_extract",
            "web_fetch",
            // Vault reads
            "vault_search",
            "vault_read",
            "vault_recall",
            "pkm_graph_neighbors",
            "graph_query",
            "vault_navigate",
            "session_search",
            "neural_recall",
            "contradiction_check",
            // Filesystem reads
            "read_file",
            "search_files",
            "workspace_search",
            "find_symbol",
            "get_function_source",
            "get_dependencies",
            "get_dependents",
            "get_change_impact",
            // Reasoning primitives — zero cost
            "think",
            "chunk_reduce",
            // Skills discovery (read-only)
            "skills_list",
            "skill_view",
            // Todo list is session-scoped and mutating but harmless
            "todo",
            // Model catalog is a simple HTTP GET + local array
            "model_catalog",
        ];

        // Tier: ChatPro — adds cloud-backed and macOS-privileged read-only
        // tools. Anything on CHAT_LITE is also available here.
        const CHAT_PRO_EXTRA: &[&str] = &[
            "vision_analyze",
            "text_to_speech",
            "web_crawl",
            "route_private",
            "perceive",
            "mixture_of_minds",
            "self_evolve",
            // Clarify is fine — it just asks the user a question
            "clarify",
        ];

        for name in CHAT_LITE {
            if let Some(tool) = self.tools.get_mut(*name) {
                tool.tier = ToolTier::ChatLite;
            }
        }
        for name in CHAT_PRO_EXTRA {
            if let Some(tool) = self.tools.get_mut(*name) {
                tool.tier = ToolTier::ChatPro;
            }
        }
    }

    fn register_phase_seven_intelligence(&mut self) {
        use crate::tools::intelligence::{
            mixture_of_minds_schema, self_evolve_schema, MixtureOfMindsHandler, SelfEvolveHandler,
        };

        // self_evolve needs the vault root for scanning session traces; skip
        // silently when no root was configured.
        if let Some(root) = self.vault_root_path.clone() {
            let se = self_evolve_schema();
            self.register(RegisteredTool {
                name: se.name,
                description: se.description,
                parameters: se.parameters,
                handler: Box::new(SelfEvolveHandler::new(root)),
                risk_level: RiskLevel::ReadOnly,
                tier: ToolTier::Agent,
            });
        }

        match MixtureOfMindsHandler::new() {
            Ok(handler) => {
                let schema = mixture_of_minds_schema();
                self.register(RegisteredTool {
                    name: schema.name,
                    description: schema.description,
                    parameters: schema.parameters,
                    handler: Box::new(handler),
                    risk_level: RiskLevel::ReadOnly,
                    tier: ToolTier::Agent,
                });
            }
            Err(e) => tracing::warn!("mixture_of_minds registration skipped: {e}"),
        }
    }

    fn register_phase_six_communication(&mut self) {
        use crate::tools::communication::{send_message_schema, SendMessageHandler};
        match SendMessageHandler::new() {
            Ok(handler) => {
                let schema = send_message_schema();
                self.register(RegisteredTool {
                    name: schema.name,
                    description: schema.description,
                    parameters: schema.parameters,
                    handler: Box::new(handler),
                    // Sending messages is hard-to-reverse and visible to others.
                    risk_level: RiskLevel::Destructive,
                    tier: ToolTier::Agent,
                });
            }
            Err(e) => tracing::warn!("send_message registration skipped: {e}"),
        }
    }

    fn register_phase_six_media(&mut self) {
        use crate::tools::media::{
            image_generate_schema, text_to_speech_schema, vision_analyze_schema,
            ImageGenerateHandler, TextToSpeechHandler, VisionAnalyzeHandler,
        };

        match VisionAnalyzeHandler::new() {
            Ok(handler) => {
                let schema = vision_analyze_schema();
                self.register(RegisteredTool {
                    name: schema.name,
                    description: schema.description,
                    parameters: schema.parameters,
                    handler: Box::new(handler),
                    risk_level: RiskLevel::ReadOnly,
                    tier: ToolTier::Agent,
                });
            }
            Err(e) => tracing::warn!("vision_analyze registration skipped: {e}"),
        }

        match ImageGenerateHandler::new() {
            Ok(handler) => {
                let schema = image_generate_schema();
                self.register(RegisteredTool {
                    name: schema.name,
                    description: schema.description,
                    parameters: schema.parameters,
                    handler: Box::new(handler),
                    risk_level: RiskLevel::ReadOnly,
                    tier: ToolTier::Agent,
                });
            }
            Err(e) => tracing::warn!("image_generate registration skipped: {e}"),
        }

        let tts = text_to_speech_schema();
        self.register(RegisteredTool {
            name: tts.name,
            description: tts.description,
            parameters: tts.parameters,
            handler: Box::new(TextToSpeechHandler),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });
    }

    fn register_phase_six_imessage(&mut self) {
        use crate::tools::channel_contacts::{channel_contacts_schema, ChannelContactsHandler};
        use crate::tools::imessage::{imessage_schema, IMessageHandler};
        use crate::tools::imessage_contacts::{imessage_contacts_schema, IMessageContactsHandler};

        let schema = imessage_schema();
        self.register(RegisteredTool {
            name: schema.name,
            description: schema.description,
            parameters: schema.parameters,
            handler: Box::new(IMessageHandler),
            // 'send' is destructive, reads are not — but we tag the whole
            // tool Destructive because the action arg can be 'send'.
            risk_level: RiskLevel::Destructive,
            tier: ToolTier::Agent,
        });

        let contacts_schema = imessage_contacts_schema();
        self.register(RegisteredTool {
            name: contacts_schema.name,
            description: contacts_schema.description,
            parameters: contacts_schema.parameters,
            handler: Box::new(IMessageContactsHandler),
            // Configuring contacts is modification — not destructive.
            risk_level: RiskLevel::Modification,
            // Configurable from Chat Pro so the Pro chat agent can set up
            // the contact routing during conversation.
            tier: ToolTier::ChatPro,
        });

        let channel_contacts = channel_contacts_schema();
        self.register(RegisteredTool {
            name: channel_contacts.name,
            description: channel_contacts.description,
            parameters: channel_contacts.parameters,
            handler: Box::new(ChannelContactsHandler),
            risk_level: RiskLevel::Modification,
            tier: ToolTier::ChatPro,
        });
    }

    fn register_phase_five_route_private(&mut self) {
        use crate::tools::inference::{route_private_schema, RoutePrivateHandler};
        let schema = route_private_schema();
        self.register(RegisteredTool {
            name: schema.name,
            description: schema.description,
            parameters: schema.parameters,
            handler: Box::new(RoutePrivateHandler::new()),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });
    }

    fn register_phase_four_apple_apps(&mut self) {
        use crate::tools::apple::{
            apple_calendar_schema, apple_mail_schema, apple_notes_schema, apple_reminders_schema,
            AppleCalendarHandler, AppleMailHandler, AppleNotesHandler, AppleRemindersHandler,
        };

        let notes = apple_notes_schema();
        self.register(RegisteredTool {
            name: notes.name,
            description: notes.description,
            parameters: notes.parameters,
            handler: Box::new(AppleNotesHandler),
            // create/edit actions mutate Notes — treat as Modification so the
            // permission gate fires unless auto-approved.
            risk_level: RiskLevel::Modification,
            tier: ToolTier::Agent,
        });

        let reminders = apple_reminders_schema();
        self.register(RegisteredTool {
            name: reminders.name,
            description: reminders.description,
            parameters: reminders.parameters,
            handler: Box::new(AppleRemindersHandler),
            risk_level: RiskLevel::Modification,
            tier: ToolTier::Agent,
        });

        let calendar = apple_calendar_schema();
        self.register(RegisteredTool {
            name: calendar.name,
            description: calendar.description,
            parameters: calendar.parameters,
            handler: Box::new(AppleCalendarHandler),
            risk_level: RiskLevel::Modification,
            tier: ToolTier::Agent,
        });

        let mail = apple_mail_schema();
        self.register(RegisteredTool {
            name: mail.name,
            description: mail.description,
            parameters: mail.parameters,
            handler: Box::new(AppleMailHandler),
            // send is destructive (visible to others, hard to reverse) —
            // tag the whole tool as Destructive so the permission gate fires.
            risk_level: RiskLevel::Destructive,
            tier: ToolTier::Agent,
        });
    }

    /// Register delegate-aware tools. Must be called after the registry is
    /// constructed but before it is shared via Arc — the agent session wires
    /// this up in `bridge.rs`.
    pub fn register_delegate_tools(
        &mut self,
        delegate: Arc<dyn crate::bridge::AgentEventDelegate>,
    ) {
        use crate::tools::clarify::{clarify_schema, ClarifyHandler};
        use crate::tools::macos::{
            interact_schema, perceive_schema, screen_watch_schema, InteractHandler,
            PerceiveHandler, ScreenWatchHandler,
        };

        let schema = clarify_schema();
        self.register(RegisteredTool {
            name: schema.name,
            description: schema.description,
            parameters: schema.parameters,
            handler: Box::new(ClarifyHandler::new(Arc::clone(&delegate))),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });

        // Phase 4: macOS perception stack — Specialties A1/A2/A3.
        let p = perceive_schema();
        self.register(RegisteredTool {
            name: p.name,
            description: p.description,
            parameters: p.parameters,
            handler: Box::new(PerceiveHandler::new(Arc::clone(&delegate))),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });

        let i = interact_schema();
        self.register(RegisteredTool {
            name: i.name,
            description: i.description,
            parameters: i.parameters,
            handler: Box::new(InteractHandler::new(Arc::clone(&delegate))),
            risk_level: RiskLevel::Modification,
            tier: ToolTier::Agent,
        });

        let w = screen_watch_schema();
        self.register(RegisteredTool {
            name: w.name,
            description: w.description,
            parameters: w.parameters,
            handler: Box::new(ScreenWatchHandler::new(Arc::clone(&delegate))),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });

        // Phase 5: on-device inference specialties that need the Swift MLX
        // runtime — ssm_resume (Mamba state) and constrained_generate (EBNF
        // grammar-guided decoding).
        use crate::tools::inference::{
            constrained_generate_schema, ssm_resume_schema, ConstrainedGenerateHandler,
            SsmResumeHandler,
        };

        let ssm = ssm_resume_schema();
        self.register(RegisteredTool {
            name: ssm.name,
            description: ssm.description,
            parameters: ssm.parameters,
            handler: Box::new(SsmResumeHandler::new(Arc::clone(&delegate))),
            // save/load mutate on-disk state → Modification.
            risk_level: RiskLevel::Modification,
            tier: ToolTier::Agent,
        });

        let cg = constrained_generate_schema();
        self.register(RegisteredTool {
            name: cg.name,
            description: cg.description,
            parameters: cg.parameters,
            handler: Box::new(ConstrainedGenerateHandler::new(Arc::clone(&delegate))),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });

        // Phase 7: NightBrain trigger (delegate-backed Specialty D1).
        use crate::tools::intelligence::{
            inline_partner_schema, nightbrain_trigger_schema, InlinePartnerHandler,
            NightBrainTriggerHandler,
        };
        let ip = inline_partner_schema();
        self.register(RegisteredTool {
            name: ip.name,
            description: ip.description,
            parameters: ip.parameters,
            handler: Box::new(InlinePartnerHandler::new(Arc::clone(&delegate))),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });

        let nb = nightbrain_trigger_schema();
        self.register(RegisteredTool {
            name: nb.name,
            description: nb.description,
            parameters: nb.parameters,
            handler: Box::new(NightBrainTriggerHandler::new(Arc::clone(&delegate))),
            risk_level: RiskLevel::Modification,
            tier: ToolTier::Agent,
        });

        // Phase 6: upgrade `image_generate` from the delegate-free fallback
        // registration in `register_phase_six_media` to a delegate-backed
        // instance so the default `provider: "mlx"` path can reach the
        // Swift sidecar per PLAN_V2 §5.1 / §16. The FAL cloud path stays
        // available as an explicit `provider: "fal"` opt-in. This call
        // replaces the existing registration entry (register() is
        // insert-or-replace on the tool name key).
        use crate::tools::media::{image_generate_schema, ImageGenerateHandler};
        match ImageGenerateHandler::new_with_delegate(Arc::clone(&delegate)) {
            Ok(handler) => {
                let schema = image_generate_schema();
                self.register(RegisteredTool {
                    name: schema.name,
                    description: schema.description,
                    parameters: schema.parameters,
                    handler: Box::new(handler),
                    risk_level: RiskLevel::ReadOnly,
                    tier: ToolTier::Agent,
                });
            }
            Err(e) => tracing::warn!(
                "image_generate delegate-aware registration skipped: {e}"
            ),
        }
    }

    fn register_phase_one_filesystem(&mut self) {
        use crate::tools::filesystem::{
            patch_schema, read_file_schema, search_files_schema, write_file_schema, PatchHandler,
            ReadFileHandler, SearchFilesHandler, WriteFileHandler,
        };

        let rf = read_file_schema();
        self.register(RegisteredTool {
            name: rf.name,
            description: rf.description,
            parameters: rf.parameters,
            handler: Box::new(ReadFileHandler),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });

        let wf = write_file_schema();
        self.register(RegisteredTool {
            name: wf.name,
            description: wf.description,
            parameters: wf.parameters,
            handler: Box::new(WriteFileHandler),
            risk_level: RiskLevel::Modification,
            tier: ToolTier::Agent,
        });

        let pt = patch_schema();
        self.register(RegisteredTool {
            name: pt.name,
            description: pt.description,
            parameters: pt.parameters,
            handler: Box::new(PatchHandler),
            risk_level: RiskLevel::Modification,
            tier: ToolTier::Agent,
        });

        let sf = search_files_schema();
        self.register(RegisteredTool {
            name: sf.name,
            description: sf.description,
            parameters: sf.parameters,
            handler: Box::new(SearchFilesHandler),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });
    }

    fn register_phase_one_terminal(&mut self) {
        use crate::tools::terminal::{
            process_schema, terminal_schema, ProcessHandler, TerminalHandler,
        };

        if self.enable_bash {
            let t = terminal_schema();
            self.register(RegisteredTool {
                name: t.name,
                description: t.description,
                parameters: t.parameters,
                handler: Box::new(TerminalHandler),
                risk_level: RiskLevel::Destructive,
                tier: ToolTier::Agent,
            });
        }

        let p = process_schema();
        self.register(RegisteredTool {
            name: p.name,
            description: p.description,
            parameters: p.parameters,
            handler: Box::new(ProcessHandler),
            risk_level: RiskLevel::Destructive,
            tier: ToolTier::Agent,
        });
    }

    fn register_phase_one_todo(&mut self) {
        use crate::tools::todo::{todo_schema, TodoHandler};
        let t = todo_schema();
        self.register(RegisteredTool {
            name: t.name,
            description: t.description,
            parameters: t.parameters,
            handler: Box::new(TodoHandler),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });
    }

    fn register_phase_one_scheduling(&mut self) {
        use crate::tools::scheduling::{cronjob_schema, CronJobHandler};
        let c = cronjob_schema();
        self.register(RegisteredTool {
            name: c.name,
            description: c.description,
            parameters: c.parameters,
            handler: Box::new(CronJobHandler::new()),
            risk_level: RiskLevel::Modification,
            tier: ToolTier::Agent,
        });
    }

    fn register_phase_one_skills_progressive(&mut self) {
        use crate::tools::skills::{
            skill_manage_schema, skill_view_schema, skills_list_schema, SkillManageHandler,
            SkillViewHandler, SkillsListHandler,
        };

        let sl = skills_list_schema();
        self.register(RegisteredTool {
            name: sl.name,
            description: sl.description,
            parameters: sl.parameters,
            handler: Box::new(SkillsListHandler::new()),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });

        let sv = skill_view_schema();
        self.register(RegisteredTool {
            name: sv.name,
            description: sv.description,
            parameters: sv.parameters,
            handler: Box::new(SkillViewHandler::new()),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });

        let sm = skill_manage_schema();
        self.register(RegisteredTool {
            name: sm.name,
            description: sm.description,
            parameters: sm.parameters,
            handler: Box::new(SkillManageHandler::new()),
            risk_level: RiskLevel::Modification,
            tier: ToolTier::Agent,
        });
    }

    fn register_phase_two_knowledge(&mut self) {
        use crate::tools::knowledge::{
            contradiction_check_schema, neural_recall_schema, vault_recall_schema,
            ContradictionCheckHandler, NeuralRecallHandler, VaultRecallHandler,
        };

        let vr = vault_recall_schema();
        self.register(RegisteredTool {
            name: vr.name,
            description: vr.description,
            parameters: vr.parameters,
            handler: Box::new(VaultRecallHandler::new(Arc::clone(&self.vault))),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });

        let cc = contradiction_check_schema();
        self.register(RegisteredTool {
            name: cc.name,
            description: cc.description,
            parameters: cc.parameters,
            handler: Box::new(ContradictionCheckHandler::new(Arc::clone(&self.vault))),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });

        let nc = neural_recall_schema();
        self.register(RegisteredTool {
            name: nc.name,
            description: nc.description,
            parameters: nc.parameters,
            handler: Box::new(NeuralRecallHandler::new(
                Arc::clone(&self.vault),
                Arc::clone(neural_cache()),
            )),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });

        // session_search needs the vault root path, not the backend trait.
        // We stash the configured root on the registry so we can wire it in.
        if let Some(root) = self.vault_root_path.clone() {
            use crate::tools::knowledge::{session_search_schema, SessionSearchHandler};
            let ss = session_search_schema();
            self.register(RegisteredTool {
                name: ss.name,
                description: ss.description,
                parameters: ss.parameters,
                handler: Box::new(SessionSearchHandler::new(root)),
                risk_level: RiskLevel::ReadOnly,
                tier: ToolTier::Agent,
            });
        }
    }

    fn register_phase_two_graph(&mut self) {
        use crate::tools::graph::{
            graph_query_schema, vault_navigate_schema, GraphQueryHandler, VaultNavigateHandler,
        };

        // Both tools operate on the vault root directory. Skip registration
        // if no root was configured — the vanilla pkm_graph_neighbors tool
        // still covers the basic relationship query.
        let Some(root) = self.vault_root_path.clone() else {
            return;
        };

        let gq = graph_query_schema();
        self.register(RegisteredTool {
            name: gq.name,
            description: gq.description,
            parameters: gq.parameters,
            handler: Box::new(GraphQueryHandler::new(root.clone())),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });

        let vn = vault_navigate_schema();
        self.register(RegisteredTool {
            name: vn.name,
            description: vn.description,
            parameters: vn.parameters,
            handler: Box::new(VaultNavigateHandler::new(root)),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });
    }

    fn register_phase_two_memory(&mut self) {
        use crate::tools::memory::{memory_tool_schema, MemoryTool};

        // Memory lives under <vault>/.epistemos/memory when a vault root is
        // available, otherwise fall back to ~/.epistemos/memory so the tool is
        // always registered.
        let memory_dir = if let Some(root) = self.vault_root_path.as_ref() {
            root.join(".epistemos").join("memory")
        } else if let Some(home) = dirs::home_dir() {
            home.join(".epistemos").join("memory")
        } else {
            std::path::PathBuf::from(".epistemos-memory")
        };

        let schema = memory_tool_schema();
        self.register(RegisteredTool {
            name: schema.name,
            description: schema.description,
            parameters: schema.parameters,
            handler: Box::new(MemoryTool::new(memory_dir)),
            risk_level: RiskLevel::Modification,
            tier: ToolTier::Agent,
        });
    }

    fn register_pkm_graph_neighbors(&mut self) {
        let vault = Arc::clone(&self.vault);
        self.register(RegisteredTool {
            name: "pkm_graph_neighbors".to_string(),
            description: "Find notes connected to a given note in the knowledge graph. \
                Searches for notes that reference or are semantically related to the given path."
                .to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "path": {
                        "type": "string",
                        "description": "Vault-relative path of the source note (e.g., 'Projects/MOHAWK/README.md')"
                    },
                    "limit": {
                        "type": "integer",
                        "default": 10,
                        "minimum": 1,
                        "maximum": 20,
                        "description": "Maximum number of neighbors to return"
                    }
                },
                "required": ["path"]
            }),
            handler: Box::new(GraphNeighborsHandler { vault }),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });
    }

    fn register_think_tool(&mut self) {
        use crate::tools::think;
        self.register(RegisteredTool {
            name: think::THINK_TOOL_NAME.to_string(),
            description: think::THINK_TOOL_DESCRIPTION.to_string(),
            parameters: serde_json::from_str(think::THINK_TOOL_SCHEMA).unwrap_or_default(),
            handler: Box::new(ThinkHandler),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });
    }

    fn register_vault_search(&mut self) {
        let vault = Arc::clone(&self.vault);
        self.register(RegisteredTool {
            name: "vault_search".to_string(),
            description: "Hybrid semantic and keyword search across the personal knowledge vault."
                .to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "query": { "type": "string", "description": "Natural language search query" },
                    "limit": {
                        "type": "integer",
                        "description": "Maximum results to return",
                        "default": 5,
                        "minimum": 1,
                        "maximum": 20
                    },
                    "tags": {
                        "type": "array",
                        "items": { "type": "string" },
                        "description": "Optional tag filter"
                    }
                },
                "required": ["query"]
            }),
            handler: Box::new(VaultSearchHandler { vault }),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });
    }

    fn register_vault_read(&mut self) {
        let vault = Arc::clone(&self.vault);
        self.register(RegisteredTool {
            name: "vault_read".to_string(),
            description: "Read the full content of a note by its vault-relative path.".to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "path": { "type": "string", "description": "Vault-relative note path" }
                },
                "required": ["path"]
            }),
            handler: Box::new(VaultReadHandler { vault }),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });
    }

    fn register_vault_write(&mut self) {
        let vault = Arc::clone(&self.vault);
        self.register(RegisteredTool {
            name: "vault_write".to_string(),
            description: "Create or update a note in the vault. Runs a pre-flight contradiction \
                check against existing facts — conflicts above 0.75 confidence are returned in \
                'warnings' but do NOT block the write. Set 'skip_contradiction_check': true to \
                skip the scan."
                .to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "path": { "type": "string", "description": "Vault-relative note path" },
                    "content": { "type": "string", "description": "Full markdown content" },
                    "tags": {
                        "type": "array",
                        "items": { "type": "string" },
                        "description": "Tags to inject into frontmatter"
                    },
                    "append": {
                        "type": "boolean",
                        "default": false,
                        "description": "Append instead of overwrite"
                    },
                    "skip_contradiction_check": {
                        "type": "boolean",
                        "default": false,
                        "description": "Skip the pre-flight contradiction scan."
                    }
                },
                "required": ["path", "content"]
            }),
            handler: Box::new(VaultWriteHandler { vault }),
            risk_level: RiskLevel::Modification,
            tier: ToolTier::Agent,
        });
    }

    fn register_bash_execute(&mut self) {
        self.register(RegisteredTool {
            name: "bash_execute".to_string(),
            description: "Execute a bash command with a timeout and a conservative security blocklist."
                .to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "command": { "type": "string", "description": "Bash command to execute" },
                    "working_dir": { "type": "string", "description": "Optional working directory" },
                    "timeout_seconds": {
                        "type": "integer",
                        "default": 30,
                        "maximum": 120,
                        "description": "Timeout for the command"
                    }
                },
                "required": ["command"]
            }),
            handler: Box::new(BashExecuteHandler),
            risk_level: RiskLevel::Destructive,
            tier: ToolTier::Agent,
        });
    }

    fn register_phase_three_web(&mut self) {
        use crate::tools::browser::{
            browser_back_schema, browser_click_schema, browser_close_schema,
            browser_console_schema, browser_get_images_schema, browser_navigate_schema,
            browser_press_schema, browser_scroll_schema, browser_snapshot_schema,
            browser_type_schema, browser_vision_schema, BrowserAction, BrowserActionHandler,
            BrowserManager,
        };
        use crate::tools::web::{
            web_crawl_schema, web_extract_schema, web_search_schema, WebCrawlHandler,
            WebExtractHandler, WebSearchHandler,
        };

        // All three handlers need a reqwest Client — if construction fails
        // (shouldn't in practice), log and skip so the rest of the registry
        // still lands.
        match WebSearchHandler::new() {
            Ok(handler) => {
                let schema = web_search_schema();
                self.register(RegisteredTool {
                    name: schema.name,
                    description: schema.description,
                    parameters: schema.parameters,
                    handler: Box::new(handler),
                    risk_level: RiskLevel::ReadOnly,
                    tier: ToolTier::Agent,
                });
            }
            Err(e) => tracing::warn!("web_search registration skipped: {e}"),
        }

        match WebExtractHandler::new() {
            Ok(handler) => {
                let schema = web_extract_schema();
                self.register(RegisteredTool {
                    name: schema.name,
                    description: schema.description,
                    parameters: schema.parameters,
                    handler: Box::new(handler),
                    risk_level: RiskLevel::ReadOnly,
                    tier: ToolTier::Agent,
                });
            }
            Err(e) => tracing::warn!("web_extract registration skipped: {e}"),
        }

        match WebCrawlHandler::new() {
            Ok(handler) => {
                let schema = web_crawl_schema();
                self.register(RegisteredTool {
                    name: schema.name,
                    description: schema.description,
                    parameters: schema.parameters,
                    handler: Box::new(handler),
                    risk_level: RiskLevel::ReadOnly,
                    tier: ToolTier::Agent,
                });
            }
            Err(e) => tracing::warn!("web_crawl registration skipped: {e}"),
        }

        let browser_manager = BrowserManager::new();
        let mut register_browser =
            |schema: crate::types::ToolSchema, action: BrowserAction, risk_level: RiskLevel| {
                self.register(RegisteredTool {
                    name: schema.name,
                    description: schema.description,
                    parameters: schema.parameters,
                    handler: Box::new(BrowserActionHandler::new(browser_manager.clone(), action)),
                    risk_level,
                    tier: ToolTier::Agent,
                });
            };

        register_browser(
            browser_navigate_schema(),
            BrowserAction::Navigate,
            RiskLevel::Modification,
        );
        register_browser(
            browser_snapshot_schema(),
            BrowserAction::Snapshot,
            RiskLevel::ReadOnly,
        );
        register_browser(
            browser_click_schema(),
            BrowserAction::Click,
            RiskLevel::Destructive,
        );
        register_browser(
            browser_type_schema(),
            BrowserAction::Type,
            RiskLevel::Destructive,
        );
        register_browser(
            browser_scroll_schema(),
            BrowserAction::Scroll,
            RiskLevel::Modification,
        );
        register_browser(
            browser_back_schema(),
            BrowserAction::Back,
            RiskLevel::Modification,
        );
        register_browser(
            browser_press_schema(),
            BrowserAction::Press,
            RiskLevel::Destructive,
        );
        register_browser(
            browser_close_schema(),
            BrowserAction::Close,
            RiskLevel::Modification,
        );
        register_browser(
            browser_get_images_schema(),
            BrowserAction::GetImages,
            RiskLevel::ReadOnly,
        );
        register_browser(
            browser_vision_schema(),
            BrowserAction::Vision,
            RiskLevel::ReadOnly,
        );
        register_browser(
            browser_console_schema(),
            BrowserAction::Console,
            RiskLevel::ReadOnly,
        );
    }

    fn register_chunk_reduce(&mut self) {
        use crate::tools::chunk_reduce;
        self.register(RegisteredTool {
            name: chunk_reduce::CHUNK_REDUCE_TOOL_NAME.to_string(),
            description: chunk_reduce::CHUNK_REDUCE_TOOL_DESCRIPTION.to_string(),
            parameters: serde_json::from_str(chunk_reduce::CHUNK_REDUCE_TOOL_SCHEMA)
                .unwrap_or_default(),
            handler: Box::new(chunk_reduce::ChunkReduceHandler),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });
    }

    fn register_workspace_search(&mut self) {
        use crate::tools::workspace_search;
        self.register(RegisteredTool {
            name: workspace_search::WORKSPACE_SEARCH_TOOL_NAME.to_string(),
            description: workspace_search::WORKSPACE_SEARCH_TOOL_DESCRIPTION.to_string(),
            parameters: serde_json::from_str(workspace_search::WORKSPACE_SEARCH_TOOL_SCHEMA)
                .unwrap_or_default(),
            handler: Box::new(workspace_search::WorkspaceSearchHandler),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });
        // Token Savior: AST-level symbol tools (replace grep/cat for codebase navigation)
        self.register_token_savior_tools();
    }

    fn register_token_savior_tools(&mut self) {
        use crate::tools::workspace_search;

        self.register(RegisteredTool {
            name: workspace_search::FIND_SYMBOL_TOOL_NAME.to_string(),
            description: workspace_search::FIND_SYMBOL_TOOL_DESCRIPTION.to_string(),
            parameters: serde_json::from_str(workspace_search::FIND_SYMBOL_TOOL_SCHEMA)
                .unwrap_or_default(),
            handler: Box::new(workspace_search::FindSymbolHandler),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });

        self.register(RegisteredTool {
            name: workspace_search::GET_FUNCTION_SOURCE_TOOL_NAME.to_string(),
            description: workspace_search::GET_FUNCTION_SOURCE_TOOL_DESCRIPTION.to_string(),
            parameters: serde_json::from_str(workspace_search::GET_FUNCTION_SOURCE_TOOL_SCHEMA)
                .unwrap_or_default(),
            handler: Box::new(workspace_search::GetFunctionSourceHandler),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });

        self.register(RegisteredTool {
            name: workspace_search::GET_DEPENDENCIES_TOOL_NAME.to_string(),
            description: workspace_search::GET_DEPENDENCIES_TOOL_DESCRIPTION.to_string(),
            parameters: serde_json::from_str(workspace_search::GET_DEPENDENCIES_TOOL_SCHEMA)
                .unwrap_or_default(),
            handler: Box::new(workspace_search::GetDependenciesHandler),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });

        self.register(RegisteredTool {
            name: workspace_search::GET_DEPENDENTS_TOOL_NAME.to_string(),
            description: workspace_search::GET_DEPENDENTS_TOOL_DESCRIPTION.to_string(),
            parameters: serde_json::from_str(workspace_search::GET_DEPENDENTS_TOOL_SCHEMA)
                .unwrap_or_default(),
            handler: Box::new(workspace_search::GetDependentsHandler),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });

        self.register(RegisteredTool {
            name: workspace_search::GET_CHANGE_IMPACT_TOOL_NAME.to_string(),
            description: workspace_search::GET_CHANGE_IMPACT_TOOL_DESCRIPTION.to_string(),
            parameters: serde_json::from_str(workspace_search::GET_CHANGE_IMPACT_TOOL_SCHEMA)
                .unwrap_or_default(),
            handler: Box::new(workspace_search::GetChangeImpactHandler),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });
    }
}

struct VaultSearchHandler {
    vault: Arc<dyn VaultBackend>,
}

#[async_trait]
impl ToolHandler for VaultSearchHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let query = input
            .get("query")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("query required".to_string()))?;
        let limit = input.get("limit").and_then(Value::as_u64).unwrap_or(5) as usize;
        let tags: Vec<String> = input
            .get("tags")
            .and_then(Value::as_array)
            .map(|items| {
                items
                    .iter()
                    .filter_map(Value::as_str)
                    .map(ToString::to_string)
                    .collect()
            })
            .unwrap_or_default();

        let results = self
            .vault
            .hybrid_search(query, limit.min(20).max(1), &tags)
            .await
            .map_err(map_vault_error)?;

        if results.is_empty() {
            return Ok("No matching notes found in vault.".to_string());
        }

        Ok(results
            .iter()
            .enumerate()
            .map(|(index, result)| {
                format!(
                    "{}. **{}** (score: {:.2})\n{}",
                    index + 1,
                    result.path,
                    result.score,
                    result.excerpt
                )
            })
            .collect::<Vec<_>>()
            .join("\n\n"))
    }
}

struct VaultReadHandler {
    vault: Arc<dyn VaultBackend>,
}

#[async_trait]
impl ToolHandler for VaultReadHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let path = input
            .get("path")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("path required".to_string()))?;
        self.vault.read(path).await.map_err(map_vault_error)
    }
}

struct VaultWriteHandler {
    vault: Arc<dyn VaultBackend>,
}

#[async_trait]
impl ToolHandler for VaultWriteHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        use crate::storage::contradiction_detector::detect_contradictions;
        use crate::storage::memory_classifier::VaultFact;

        let path = input
            .get("path")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("path required".to_string()))?;
        let content = input
            .get("content")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("content required".to_string()))?;
        let append = input
            .get("append")
            .and_then(Value::as_bool)
            .unwrap_or(false);
        let tags: Vec<String> = input
            .get("tags")
            .and_then(Value::as_array)
            .map(|items| {
                items
                    .iter()
                    .filter_map(Value::as_str)
                    .map(ToString::to_string)
                    .collect()
            })
            .unwrap_or_default();
        let skip_contradiction_check = input
            .get("skip_contradiction_check")
            .and_then(Value::as_bool)
            .unwrap_or(false);

        // Contradiction pre-flight: surface conflicts but don't block the
        // write. The agent is responsible for deciding whether to proceed.
        let contradictions = if skip_contradiction_check {
            Vec::new()
        } else {
            let candidates = self
                .vault
                .hybrid_search(content, 10, &[])
                .await
                .unwrap_or_default();
            let now = chrono::Utc::now();
            let facts: Vec<VaultFact> = candidates
                .iter()
                .filter(|r| r.path != path)
                .map(|r| {
                    VaultFact::new(
                        r.path.clone(),
                        "".to_string(),
                        r.excerpt.clone(),
                        r.score,
                        now,
                    )
                })
                .collect();
            detect_contradictions(content, &facts)
        };

        self.vault
            .write(path, content, Some(&tags), append)
            .await
            .map_err(map_vault_error)?;

        let warnings: Vec<Value> = contradictions
            .iter()
            .filter(|c| c.confidence >= 0.75)
            .map(|c| {
                json!({
                    "type": format!("{:?}", c.conflict_type),
                    "confidence": c.confidence,
                    "existing_fact": c.existing_fact.content,
                    "source_path": c.existing_fact.file_path,
                })
            })
            .collect();

        Ok(json!({
            "success": true,
            "path": path,
            "bytes_written": content.len(),
            "warnings": warnings,
        })
        .to_string())
    }
}

struct BashExecuteHandler;

#[async_trait]
impl ToolHandler for BashExecuteHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let command = input
            .get("command")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("command required".to_string()))?;
        let timeout_seconds = input
            .get("timeout_seconds")
            .and_then(Value::as_u64)
            .unwrap_or(30)
            .min(120);
        let working_dir = input.get("working_dir").and_then(Value::as_str);

        let blocked = [
            "rm -rf /",
            "sudo rm",
            "mkfs",
            "dd if=",
            "diskutil eraseDisk",
        ];
        if blocked.iter().any(|pattern| command.contains(pattern)) {
            return Err(ToolError::PermissionDenied);
        }

        let mut process = tokio::process::Command::new("bash");
        process.arg("-lc").arg(command);
        if let Some(working_dir) = working_dir {
            process.current_dir(working_dir);
        }

        let output = tokio::time::timeout(
            std::time::Duration::from_secs(timeout_seconds),
            process.output(),
        )
        .await
        .map_err(|_| {
            ToolError::ExecutionFailed(format!("command timed out after {timeout_seconds}s"))
        })?
        .map_err(|error| ToolError::ExecutionFailed(error.to_string()))?;

        let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
        let mut parts = Vec::new();
        if !stdout.is_empty() {
            parts.push(format!("STDOUT:\n{stdout}"));
        }
        if !stderr.is_empty() {
            parts.push(format!("STDERR:\n{stderr}"));
        }
        if !output.status.success() {
            parts.push(format!("Exit code: {}", output.status.code().unwrap_or(-1)));
        }

        Ok(if parts.is_empty() {
            "(no output)".to_string()
        } else {
            parts.join("\n\n")
        })
    }
}

struct ThinkHandler;

#[async_trait]
impl ToolHandler for ThinkHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        Ok(crate::tools::think::execute_think(input))
    }
}

struct GraphNeighborsHandler {
    vault: Arc<dyn VaultBackend>,
}

#[async_trait]
impl ToolHandler for GraphNeighborsHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let path = input
            .get("path")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("path required".to_string()))?;
        let limit = input.get("limit").and_then(Value::as_u64).unwrap_or(10) as usize;

        // Extract the note title from the path for searching
        let title = std::path::Path::new(path)
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or(path);

        // Search for notes that reference this note by title or path
        let results = self
            .vault
            .hybrid_search(title, limit.min(20), &[])
            .await
            .map_err(map_vault_error)?;

        // Filter out the source note itself
        let neighbors: Vec<_> = results.into_iter().filter(|r| r.path != path).collect();

        if neighbors.is_empty() {
            return Ok(format!("No connected notes found for '{path}'."));
        }

        let formatted = neighbors
            .iter()
            .enumerate()
            .map(|(i, r)| {
                format!(
                    "{}. **{}** (relevance: {:.2})\n   {}",
                    i + 1,
                    r.path,
                    r.score,
                    r.excerpt.chars().take(200).collect::<String>()
                )
            })
            .collect::<Vec<_>>()
            .join("\n\n");

        Ok(format!(
            "Neighbors of '{path}' ({} found):\n\n{formatted}",
            neighbors.len()
        ))
    }
}

fn map_vault_error(error: VaultError) -> ToolError {
    match error {
        VaultError::NotFound(message) => ToolError::NotFound(message),
        other => ToolError::ExecutionFailed(other.to_string()),
    }
}

/// Process-wide NeuralCache for the `neural_recall` tool. Matches the existing
/// cache singleton used by the FFI layer (`bridge::get_or_create_cache`) so
/// both paths share the same hot facts.
fn neural_cache() -> &'static Arc<crate::storage::neural_cache::NeuralCache> {
    use std::sync::OnceLock;
    static CACHE: OnceLock<Arc<crate::storage::neural_cache::NeuralCache>> = OnceLock::new();
    CACHE.get_or_init(|| Arc::new(crate::storage::neural_cache::NeuralCache::new(500)))
}

#[cfg(test)]
mod tier_tests {
    use super::*;
    use crate::storage::vault::{SearchResult, VaultBackend, VaultError};
    use async_trait::async_trait;

    /// Minimal vault stub for registry construction in unit tests.
    struct NullVault;

    #[async_trait]
    impl VaultBackend for NullVault {
        async fn hybrid_search(
            &self,
            _query: &str,
            _limit: usize,
            _tag_filter: &[String],
        ) -> Result<Vec<SearchResult>, VaultError> {
            Ok(Vec::new())
        }
        async fn read(&self, _path: &str) -> Result<String, VaultError> {
            Ok(String::new())
        }
        async fn write(
            &self,
            _path: &str,
            _content: &str,
            _tags: Option<&[String]>,
            _append: bool,
        ) -> Result<(), VaultError> {
            Ok(())
        }
        async fn list(&self, _path_prefix: &str) -> Result<Vec<String>, VaultError> {
            Ok(Vec::new())
        }
        async fn exists(&self, _path: &str) -> Result<bool, VaultError> {
            Ok(false)
        }
        async fn delete(&self, _path: &str) -> Result<bool, VaultError> {
            Ok(false)
        }
    }

    fn build_registry(tier: ToolTier) -> ToolRegistry {
        ToolRegistry::with_tier(Arc::new(NullVault), true, None::<std::path::PathBuf>, tier)
    }

    #[test]
    fn v2_catalog_builds_four_plan_canonical_tools() {
        // Phase 2F audit: factory produces a Vec<Box<dyn Tool>> whose
        // entries carry dotted names + compiling input schemas. This is
        // the integration check that pairs the v2_catalog static SPEC
        // tests with real handler instances driven by a stub vault.
        //
        // Counts (with `vault_root_path = None`):
        //   2F-2..6: 17 tools always present
        //   2F-7   : +3 always (discovery.mcp_discover, discovery.model_catalog,
        //                       media.text_to_speech)
        //   2F-9   : +4 web family (web.search/extract/crawl Ok-gated;
        //                           web.fetch unconditional)
        //   2F-10  : +5 always (apple.{notes,reminders,calendar,mail},
        //                       memory.curated)
        //   2F-11  : +9 always: 4 Ok-gated cloud-HTTP
        //                       (communication.send_message,
        //                        media.vision_analyze, media.image_generate,
        //                        intelligence.mixture_of_minds) +
        //                       5 token-savior workspace tools
        //                       (workspace.find_symbol,
        //                        workspace.get_function_source,
        //                        workspace.get_dependencies,
        //                        workspace.get_dependents,
        //                        workspace.get_change_impact)
        //   2F-12  : +11 always (browser.{navigate, snapshot, click, type,
        //                        scroll, back, press, close, get_images,
        //                        vision, console}) all ProOnly per
        //                        FINAL_SYNTHESIS §5.7 / §6 wave sequencing
        //                        until Wave 6 BrowserEngine trait splits
        //                        the adapters
        //   2F-13  : +7 always (inference.route_private,
        //                       communication.{imessage, imessage_contacts,
        //                                      channel_contacts},
        //                       skills.{list, view, manage})
        //   2F-14  : +3 vault-root-bound (graph.query,
        //                       graph.vault_navigate,
        //                       knowledge.session_search) — gated out
        //                       in the None branch
        //   2F-15  : +1 always (system.process — manages action.terminal
        //                       PTYs; Pro-only same as action.terminal)
        //   trajectory.export, intelligence.self_evolve, graph.query,
        //   graph.vault_navigate, knowledge.session_search are skipped
        //   here because vault_root_path is None;
        //   `v2_catalog_includes_trajectory_export_when_vault_root_set`
        //   covers the with-root branch.
        let registry = build_registry(ToolTier::Full);
        let catalog = registry.build_v2_catalog();
        assert_eq!(catalog.len(), 57, "2F-15 ships 57 adapted tools when vault_root is None");

        let names: Vec<&'static str> = catalog.iter().map(|t| t.name()).collect();
        assert!(names.contains(&"vault.search"));
        assert!(names.contains(&"vault.read"));
        assert!(names.contains(&"vault.write"));
        assert!(names.contains(&"workspace.search"));
        assert!(names.contains(&"graph.neighbors"));
        assert!(names.contains(&"chunk.reduce"));
        assert!(names.contains(&"action.bash"));
        assert!(names.contains(&"file.read"));
        assert!(names.contains(&"file.write"));
        assert!(names.contains(&"file.search"));
        assert!(names.contains(&"file.patch"));
        assert!(names.contains(&"knowledge.recall"));
        assert!(names.contains(&"knowledge.contradiction_check"));
        assert!(names.contains(&"knowledge.neural_recall"));
        assert!(names.contains(&"system.todo"));
        assert!(names.contains(&"system.cron"));
        assert!(names.contains(&"action.terminal"));
        assert!(names.contains(&"discovery.mcp_discover"));
        assert!(names.contains(&"discovery.model_catalog"));
        assert!(names.contains(&"media.text_to_speech"));
        assert!(names.contains(&"web.search"));
        assert!(names.contains(&"web.extract"));
        assert!(names.contains(&"web.crawl"));
        assert!(names.contains(&"web.fetch"));
        assert!(names.contains(&"apple.notes"));
        assert!(names.contains(&"apple.reminders"));
        assert!(names.contains(&"apple.calendar"));
        assert!(names.contains(&"apple.mail"));
        assert!(names.contains(&"memory.curated"));
        assert!(names.contains(&"communication.send_message"));
        assert!(names.contains(&"media.vision_analyze"));
        assert!(names.contains(&"media.image_generate"));
        assert!(names.contains(&"intelligence.mixture_of_minds"));
        assert!(names.contains(&"workspace.find_symbol"));
        assert!(names.contains(&"workspace.get_function_source"));
        assert!(names.contains(&"workspace.get_dependencies"));
        assert!(names.contains(&"workspace.get_dependents"));
        assert!(names.contains(&"workspace.get_change_impact"));
        assert!(names.contains(&"browser.navigate"));
        assert!(names.contains(&"browser.snapshot"));
        assert!(names.contains(&"browser.click"));
        assert!(names.contains(&"browser.type"));
        assert!(names.contains(&"browser.scroll"));
        assert!(names.contains(&"browser.back"));
        assert!(names.contains(&"browser.press"));
        assert!(names.contains(&"browser.close"));
        assert!(names.contains(&"browser.get_images"));
        assert!(names.contains(&"browser.vision"));
        assert!(names.contains(&"browser.console"));
        assert!(names.contains(&"inference.route_private"));
        assert!(names.contains(&"communication.imessage"));
        assert!(names.contains(&"communication.imessage_contacts"));
        assert!(names.contains(&"communication.channel_contacts"));
        assert!(names.contains(&"skills.list"));
        assert!(names.contains(&"skills.view"));
        assert!(names.contains(&"skills.manage"));
        assert!(names.contains(&"system.process"));
        assert!(
            !names.contains(&"trajectory.export"),
            "trajectory.export requires vault_root_path; gated out when None"
        );
        assert!(
            !names.contains(&"graph.query"),
            "graph.query requires vault_root_path; gated out when None"
        );
        assert!(
            !names.contains(&"graph.vault_navigate"),
            "graph.vault_navigate requires vault_root_path; gated out when None"
        );
        assert!(
            !names.contains(&"knowledge.session_search"),
            "knowledge.session_search requires vault_root_path; gated out when None"
        );

        // Each tool's input schema must compile via the Phase 2A grammar
        // compiler — proves §17.3 sampler-bound dispatch for each.
        for tool in &catalog {
            crate::grammar::schema_to_llg(tool.input_schema()).unwrap_or_else(|e| {
                panic!(
                    "v2 tool {} input schema must compile: {:?}",
                    tool.name(),
                    e
                )
            });
        }
    }

    #[test]
    fn v2_catalog_includes_trajectory_export_when_vault_root_set() {
        // 2F-7 invariant: trajectory.export is conditionally registered on
        // vault_root_path. Construct a registry with a temp root and verify
        // the tool appears. 2F-8 also adds intelligence.self_evolve under the
        // same gating, so both names must surface.
        let tmp = tempfile::tempdir().expect("tempdir");
        let registry = ToolRegistry::with_tier(
            Arc::new(NullVault),
            true,
            Some(tmp.path().to_path_buf()),
            ToolTier::Full,
        );
        let catalog = registry.build_v2_catalog();
        let names: Vec<&'static str> = catalog.iter().map(|t| t.name()).collect();
        assert!(
            names.contains(&"trajectory.export"),
            "trajectory.export must register when vault_root_path is Some"
        );
        assert!(
            names.contains(&"intelligence.self_evolve"),
            "intelligence.self_evolve must register when vault_root_path is Some"
        );
        assert!(
            names.contains(&"graph.query"),
            "graph.query must register when vault_root_path is Some"
        );
        assert!(
            names.contains(&"graph.vault_navigate"),
            "graph.vault_navigate must register when vault_root_path is Some"
        );
        assert!(
            names.contains(&"knowledge.session_search"),
            "knowledge.session_search must register when vault_root_path is Some"
        );
        assert_eq!(
            catalog.len(),
            62,
            "all 62 unconditional + vault-root-bound v2 tools present"
        );
    }

    #[tokio::test]
    async fn execute_v2_matches_legacy_execute_for_wrapped_handler() {
        // Phase 2G-2 parity invariant: for a tool whose v2 catalog entry
        // is a LegacyToolAdapter wrapping the same underlying handler,
        // execute_v2 must produce the SAME output string as legacy
        // execute(). Without the {text} unwrap in stringify_v2_result
        // this test would fail: VaultSearchHandler returns plain text
        // "No matching notes found in vault." for an empty result, the
        // adapter wraps it as {"text": "No matching..."}, and a naive
        // re-stringify would yield `{"text":"No matching..."}` instead
        // of the bare string the legacy callers (agent_loop, bridge)
        // expect to forward to the model.
        let registry = build_registry(ToolTier::Full);
        let input = serde_json::json!({"query": "anything"});
        let legacy = registry
            .execute("vault_search", &input)
            .await
            .expect("legacy vault_search must succeed");
        let v2 = registry
            .execute_v2("vault.search", &input)
            .await
            .expect("v2 vault.search must succeed");
        assert_eq!(
            legacy, v2,
            "execute_v2 must be a drop-in for execute on a wrapped handler"
        );
    }

    #[tokio::test]
    async fn execute_v2_returns_invalid_arguments_for_unknown_tool() {
        // Phase 2G-2: when the name isn't in the v2 catalog AND isn't
        // in the legacy registry, the legacy fallback produces
        // InvalidArguments. The name must be implausible enough not to
        // collide with either surface.
        let registry = build_registry(ToolTier::Full);
        let err = registry
            .execute_v2("totally_made_up_42", &serde_json::json!({}))
            .await
            .unwrap_err();
        assert!(
            matches!(err, ToolError::InvalidArguments(_)),
            "unknown tool must surface as InvalidArguments, got: {err:?}"
        );
    }

    #[tokio::test]
    async fn execute_v2_resolves_legacy_underscored_name_via_alias_table() {
        // Phase 2G-3 invariant: a model-emitted legacy name like
        // `vault_search` resolves through LEGACY_TO_V2_ALIASES to
        // `vault.search` in the v2 catalog, so dispatch routes through
        // `Tool::invoke` instead of falling back to legacy `execute()`.
        // The end-to-end output must still match what the legacy path
        // would have returned (drop-in semantics).
        let registry = build_registry(ToolTier::Full);
        let input = serde_json::json!({"query": "anything"});
        let legacy_path = registry
            .execute("vault_search", &input)
            .await
            .expect("legacy vault_search must succeed");
        let v2_path = registry
            .execute_v2("vault_search", &input)
            .await
            .expect("vault_search via execute_v2 alias must succeed");
        assert_eq!(legacy_path, v2_path, "alias-resolved dispatch must be byte-identical");
    }

    #[test]
    fn legacy_v2_alias_table_has_no_typos_against_actual_v2_catalog() {
        // Phase 2G-3 invariant: every dotted name on the right side of
        // LEGACY_TO_V2_ALIASES must exist in the v2 catalog (either the
        // unconditional set or the delegate-bound set). Catches typos
        // and missing-port regressions early.
        let unconditional: std::collections::HashSet<&str> = [
            crate::tools::v2_catalog::vault_search::SPEC.name,
            crate::tools::v2_catalog::vault_read::SPEC.name,
            crate::tools::v2_catalog::vault_write::SPEC.name,
            crate::tools::v2_catalog::workspace_search::SPEC.name,
            crate::tools::v2_catalog::graph_neighbors::SPEC.name,
            crate::tools::v2_catalog::chunk_reduce::SPEC.name,
            crate::tools::v2_catalog::action_bash::SPEC.name,
            crate::tools::v2_catalog::file_read::SPEC.name,
            crate::tools::v2_catalog::file_write::SPEC.name,
            crate::tools::v2_catalog::file_search::SPEC.name,
            crate::tools::v2_catalog::file_patch::SPEC.name,
            crate::tools::v2_catalog::knowledge_recall::SPEC.name,
            crate::tools::v2_catalog::knowledge_contradiction::SPEC.name,
            crate::tools::v2_catalog::knowledge_neural_recall::SPEC.name,
            crate::tools::v2_catalog::system_todo::SPEC.name,
            crate::tools::v2_catalog::system_cron::SPEC.name,
            crate::tools::v2_catalog::action_terminal::SPEC.name,
            crate::tools::v2_catalog::discovery_mcp_discover::SPEC.name,
            crate::tools::v2_catalog::discovery_model_catalog::SPEC.name,
            crate::tools::v2_catalog::media_text_to_speech::SPEC.name,
            crate::tools::v2_catalog::trajectory_export::SPEC.name,
            crate::tools::v2_catalog::web_search::SPEC.name,
            crate::tools::v2_catalog::web_extract::SPEC.name,
            crate::tools::v2_catalog::web_crawl::SPEC.name,
            crate::tools::v2_catalog::web_fetch::SPEC.name,
            crate::tools::v2_catalog::apple_notes::SPEC.name,
            crate::tools::v2_catalog::apple_reminders::SPEC.name,
            crate::tools::v2_catalog::apple_calendar::SPEC.name,
            crate::tools::v2_catalog::apple_mail::SPEC.name,
            crate::tools::v2_catalog::memory_curated::SPEC.name,
            crate::tools::v2_catalog::communication_send_message::SPEC.name,
            crate::tools::v2_catalog::media_vision_analyze::SPEC.name,
            crate::tools::v2_catalog::media_image_generate::SPEC.name,
            crate::tools::v2_catalog::intelligence_mixture_of_minds::SPEC.name,
            crate::tools::v2_catalog::workspace_find_symbol::SPEC.name,
            crate::tools::v2_catalog::workspace_get_function_source::SPEC.name,
            crate::tools::v2_catalog::workspace_get_dependencies::SPEC.name,
            crate::tools::v2_catalog::workspace_get_dependents::SPEC.name,
            crate::tools::v2_catalog::workspace_get_change_impact::SPEC.name,
            crate::tools::v2_catalog::browser_navigate::SPEC.name,
            crate::tools::v2_catalog::browser_snapshot::SPEC.name,
            crate::tools::v2_catalog::browser_click::SPEC.name,
            crate::tools::v2_catalog::browser_type::SPEC.name,
            crate::tools::v2_catalog::browser_scroll::SPEC.name,
            crate::tools::v2_catalog::browser_back::SPEC.name,
            crate::tools::v2_catalog::browser_press::SPEC.name,
            crate::tools::v2_catalog::browser_close::SPEC.name,
            crate::tools::v2_catalog::browser_get_images::SPEC.name,
            crate::tools::v2_catalog::browser_vision::SPEC.name,
            crate::tools::v2_catalog::browser_console::SPEC.name,
            crate::tools::v2_catalog::inference_route_private::SPEC.name,
            crate::tools::v2_catalog::communication_imessage::SPEC.name,
            crate::tools::v2_catalog::communication_imessage_contacts::SPEC.name,
            crate::tools::v2_catalog::communication_channel_contacts::SPEC.name,
            crate::tools::v2_catalog::skills_list::SPEC.name,
            crate::tools::v2_catalog::skills_view::SPEC.name,
            crate::tools::v2_catalog::skills_manage::SPEC.name,
            crate::tools::v2_catalog::graph_query::SPEC.name,
            crate::tools::v2_catalog::graph_vault_navigate::SPEC.name,
            crate::tools::v2_catalog::knowledge_session_search::SPEC.name,
            crate::tools::v2_catalog::system_process::SPEC.name,
            crate::tools::v2_catalog::intelligence_self_evolve::SPEC.name,
            // Delegate-bound (build_v2_delegate_catalog):
            crate::tools::v2_catalog::clarify_ask::SPEC.name,
            crate::tools::v2_catalog::macos_perceive::SPEC.name,
            crate::tools::v2_catalog::macos_interact::SPEC.name,
            crate::tools::v2_catalog::macos_screen_watch::SPEC.name,
            crate::tools::v2_catalog::inference_ssm_resume::SPEC.name,
            crate::tools::v2_catalog::inference_constrained_generate::SPEC.name,
            crate::tools::v2_catalog::intelligence_nightbrain_trigger::SPEC.name,
            crate::tools::v2_catalog::intelligence_inline_partner::SPEC.name,
        ]
        .into_iter()
        .collect();

        for (legacy, dotted) in crate::tools::registry::LEGACY_TO_V2_ALIASES {
            assert!(
                unconditional.contains(dotted),
                "alias {legacy} → {dotted} but {dotted} is not a known v2 catalog name"
            );
        }
    }

    #[tokio::test]
    async fn execute_v2_falls_back_to_legacy_for_underscored_names() {
        // Phase 2G-2 fallback invariant: the model emits legacy
        // underscored names (vault_search, think, read_file). execute_v2
        // must resolve them through the legacy registry when the v2
        // catalog doesn't have a matching entry, so swapping callers
        // from execute() to execute_v2() is a true drop-in.
        //
        // "think" is the cleanest probe — its handler returns the
        // input thought verbatim and is unconditionally registered.
        let registry = build_registry(ToolTier::Full);
        let r = registry
            .execute_v2("think", &serde_json::json!({"thought": "phase 2g-2 fallback"}))
            .await
            .expect("legacy 'think' must route through execute_v2 fallback");
        assert_eq!(
            r, "phase 2g-2 fallback",
            "fallback to legacy execute() must preserve plain-text return"
        );
    }

    #[tokio::test]
    async fn execute_v2_honors_tier_gate_for_legacy_known_tool() {
        // bash_execute is registered in legacy as Destructive/Agent tier.
        // execute_v2's permission gate runs BEFORE the v2 lookup, so a
        // ChatLite registry rejects it via the existing is_tool_permitted
        // path even though the v2 catalog has no "bash_execute" entry
        // (the v2 form is "action.bash" — see Phase 2F-3). This proves
        // execute_v2 keeps the legacy tier/allowlist semantics intact
        // during the migration window.
        let registry = build_registry(ToolTier::ChatLite);
        let err = registry
            .execute_v2("bash_execute", &serde_json::json!({"command": "echo hi"}))
            .await
            .unwrap_err();
        assert!(
            matches!(err, ToolError::PermissionDenied),
            "bash_execute is in legacy + Destructive; ChatLite tier must reject via is_tool_permitted. got: {err:?}"
        );
    }

    #[tokio::test]
    async fn execute_v2_dotted_name_unknown_to_legacy_passes_permission_gate() {
        // Phase 2G-1 documented behavior: dotted v2 names like
        // "action.bash" don't appear in the legacy registry, so the
        // legacy permission gate is skipped for them. Phase 2G-2 will
        // introduce Profile-aware gating against Tool::profile() so
        // the gate doesn't rely on dual legacy/v2 name matching.
        //
        // Here we just prove the LOOKUP succeeds (the call itself may
        // fail because action.bash needs a real shell + permission
        // approval, but that's a runtime error, not InvalidArguments).
        let registry = build_registry(ToolTier::ChatLite);
        let result = registry
            .execute_v2(
                "action.bash",
                &serde_json::json!({"command": "echo phase-2g-1"}),
            )
            .await;
        // The call should NOT report InvalidArguments (tool found) and
        // should NOT report PermissionDenied (no legacy match → gate
        // skipped per current 2G-1 design). Anything else (Ok or
        // ExecutionFailed) is acceptable here.
        if let Err(ToolError::InvalidArguments(msg)) = &result {
            panic!("action.bash should resolve through v2 catalog: {msg}");
        }
        if let Err(ToolError::PermissionDenied) = &result {
            panic!(
                "action.bash has no legacy counterpart; permission gate \
                 should not fire on it in 2G-1. Phase 2G-2 will add \
                 Profile-aware gating."
            );
        }
    }

    #[tokio::test]
    async fn v2_delegate_catalog_builds_eight_delegate_bound_tools() {
        // Phase 2F-8 invariant: build_v2_delegate_catalog returns exactly
        // the 8 delegate-bound dotted-name v2 tools. Drives a stub
        // AgentEventDelegate so we don't pull the Swift bridge into the
        // unit test.
        use crate::bridge::AgentEventDelegate;

        struct StubDelegate;
        impl AgentEventDelegate for StubDelegate {
            fn on_thinking_delta(&self, _: String) {}
            fn on_text_delta(&self, _: String) {}
            fn on_tool_input_delta(&self, _: u32, _: String) {}
            fn on_tool_started(&self, _: String, _: String, _: String) {}
            fn on_tool_completed(&self, _: String, _: String, _: bool) {}
            fn on_subagent_spawned(&self, _: String, _: String) {}
            fn on_permission_required(&self, _: String, _: String, _: String, _: String) {}
            fn on_context_compacting(&self, _: u32) {}
            fn on_context_compacted(&self, _: u32) {}
            fn on_turn_started(&self, _: u32, _: u32) {}
            fn on_complete(&self, _: String, _: u32, _: u32) {}
            fn on_error(&self, _: String) {}
            fn execute_computer_action(&self, _: String) -> String {
                "{}".into()
            }
            fn wait_for_permission(&self, _: String) -> bool {
                false
            }
            fn ask_user_question(&self, _: String) -> String {
                "{}".into()
            }
            fn perceive_app(&self, _: String, _: String) -> String {
                "{}".into()
            }
            fn interact_with_app(&self, _: String) -> String {
                "{}".into()
            }
            fn start_screen_watch(&self, _: String) -> String {
                "{}".into()
            }
            fn manage_ssm_state(&self, _: String) -> String {
                "{}".into()
            }
            fn generate_constrained(&self, _: String, _: String) -> String {
                "{}".into()
            }
            fn generate_image(&self, _: String, _: String) -> String {
                "{}".into()
            }
            fn trigger_nightbrain_job(&self, _: String, _: String) -> String {
                "{}".into()
            }
            fn get_partner_context(&self, _: String, _: u32) -> String {
                "{}".into()
            }
        }

        let registry = build_registry(ToolTier::Full);
        let delegate: Arc<dyn AgentEventDelegate> = Arc::new(StubDelegate);
        let catalog = registry.build_v2_delegate_catalog(delegate);
        assert_eq!(catalog.len(), 8, "2F-8 ships 8 delegate-bound tools");

        let names: Vec<&'static str> = catalog.iter().map(|t| t.name()).collect();
        assert!(names.contains(&"clarify.ask"));
        assert!(names.contains(&"macos.perceive"));
        assert!(names.contains(&"macos.interact"));
        assert!(names.contains(&"macos.screen_watch"));
        assert!(names.contains(&"inference.ssm_resume"));
        assert!(names.contains(&"inference.constrained_generate"));
        assert!(names.contains(&"intelligence.nightbrain_trigger"));
        assert!(names.contains(&"intelligence.inline_partner"));

        for tool in &catalog {
            crate::grammar::schema_to_llg(tool.input_schema()).unwrap_or_else(|e| {
                panic!(
                    "v2 delegate tool {} input schema must compile: {:?}",
                    tool.name(),
                    e
                )
            });
        }
    }

    #[tokio::test]
    async fn v2_catalog_vault_search_invokable_through_runner() {
        // End-to-end: build the catalog, locate vault.search, run it
        // through Phase 2C's run_with_variants against the NullVault
        // (which returns empty hits). Verifies the adapter + runner
        // + grammar + cache stack works for a wrapped legacy tool.
        let registry = build_registry(ToolTier::Full);
        let catalog = registry.build_v2_catalog();
        let vault_search = catalog
            .iter()
            .find(|t| t.name() == "vault.search")
            .expect("vault.search must be in v2 catalog");

        let ctx = crate::tools::runner::default_ctx(std::time::Duration::from_millis(800));
        let r = crate::tools::runner::run_with_variants(
            vault_search.as_ref(),
            &ctx,
            serde_json::json!({"query": "test"}),
        )
        .await;
        // NullVault returns Ok(Vec::new()), legacy handler maps this to a
        // formatted string ("(no output)" or similar); adapter wraps that
        // as `{ "text": "..." }`. We just assert the call completed Ok.
        assert_eq!(
            r.meta.status,
            crate::tools::Status::Ok,
            "vault.search must succeed against NullVault"
        );
    }

    #[test]
    fn tool_tier_ordering_is_ladder() {
        assert!(ToolTier::None < ToolTier::ChatLite);
        assert!(ToolTier::ChatLite < ToolTier::ChatPro);
        assert!(ToolTier::ChatPro < ToolTier::Agent);
        assert!(ToolTier::Agent < ToolTier::Full);
    }

    #[test]
    fn tool_tier_parses_case_insensitively() {
        assert_eq!(ToolTier::from_str_lossy("chat_lite"), ToolTier::ChatLite);
        assert_eq!(ToolTier::from_str_lossy("CHAT_PRO"), ToolTier::ChatPro);
        assert_eq!(ToolTier::from_str_lossy("fast"), ToolTier::ChatLite);
        assert_eq!(ToolTier::from_str_lossy("pro"), ToolTier::ChatPro);
        assert_eq!(ToolTier::from_str_lossy("agent"), ToolTier::Agent);
        // Unknown tier falls back to Agent so existing callers don't break.
        assert_eq!(ToolTier::from_str_lossy("nonsense"), ToolTier::Agent);
    }

    #[test]
    fn chat_lite_exposes_web_search_and_vault_recall() {
        let registry = build_registry(ToolTier::ChatLite);
        let names: Vec<String> = registry
            .get_definitions()
            .into_iter()
            .map(|t| t.name)
            .collect();
        assert!(
            names.contains(&"web_search".to_string()),
            "chat_lite must expose web_search, got: {names:?}"
        );
        assert!(
            names.contains(&"vault_recall".to_string()),
            "chat_lite must expose vault_recall"
        );
        assert!(names.contains(&"think".to_string()));
        assert!(names.contains(&"read_file".to_string()));
    }

    #[test]
    fn chat_lite_hides_destructive_tools() {
        let registry = build_registry(ToolTier::ChatLite);
        let names: Vec<String> = registry
            .get_definitions()
            .into_iter()
            .map(|t| t.name)
            .collect();
        assert!(!names.contains(&"terminal".to_string()));
        assert!(!names.contains(&"bash_execute".to_string()));
        assert!(!names.contains(&"send_message".to_string()));
        assert!(!names.contains(&"imessage".to_string()));
        assert!(!names.contains(&"write_file".to_string()));
        assert!(!names.contains(&"patch".to_string()));
        assert!(!names.contains(&"skill_manage".to_string()));
        assert!(!names.contains(&"cronjob".to_string()));
    }

    #[test]
    fn chat_pro_adds_vision_and_tts_over_chat_lite() {
        let lite = build_registry(ToolTier::ChatLite);
        let pro = build_registry(ToolTier::ChatPro);
        let lite_names: std::collections::HashSet<String> =
            lite.get_definitions().into_iter().map(|t| t.name).collect();
        let pro_names: std::collections::HashSet<String> =
            pro.get_definitions().into_iter().map(|t| t.name).collect();

        // Pro must be a superset of Lite.
        for name in &lite_names {
            assert!(
                pro_names.contains(name),
                "chat_pro missing lite tool '{name}'"
            );
        }
        // Pro adds vision_analyze + text_to_speech.
        assert!(pro_names.contains("vision_analyze"));
        assert!(pro_names.contains("text_to_speech"));
    }

    #[test]
    fn agent_tier_is_superset_of_chat_pro() {
        let pro = build_registry(ToolTier::ChatPro);
        let agent = build_registry(ToolTier::Agent);
        let pro_names: std::collections::HashSet<String> =
            pro.get_definitions().into_iter().map(|t| t.name).collect();
        let agent_names: std::collections::HashSet<String> = agent
            .get_definitions()
            .into_iter()
            .map(|t| t.name)
            .collect();
        for name in &pro_names {
            assert!(
                agent_names.contains(name),
                "agent tier missing pro tool '{name}'"
            );
        }
        // Agent tier includes the destructive tools Pro hides.
        assert!(agent_names.contains("terminal"));
        assert!(agent_names.contains("send_message"));
    }

    #[test]
    fn model_facing_catalog_hides_unsupported_image_generation() {
        let registry = build_registry(ToolTier::Agent);
        let visible_names: std::collections::HashSet<String> = registry
            .get_definitions()
            .into_iter()
            .map(|tool| tool.name)
            .collect();
        let all_names: std::collections::HashSet<String> = registry
            .get_all_definitions()
            .into_iter()
            .map(|tool| tool.name)
            .collect();

        assert!(!visible_names.contains("image_generate"));
        assert!(all_names.contains("image_generate"));
    }

    #[tokio::test]
    async fn execute_rejects_tools_above_active_tier() {
        let registry = build_registry(ToolTier::ChatLite);
        // `write_file` is Agent tier — ChatLite must refuse.
        let err = registry
            .execute(
                "write_file",
                &serde_json::json!({ "path": "/tmp/x", "content": "" }),
            )
            .await
            .unwrap_err();
        assert!(matches!(err, ToolError::PermissionDenied));
    }

    #[tokio::test]
    async fn execute_permits_tools_within_active_tier() {
        let registry = build_registry(ToolTier::ChatLite);
        // `think` is ChatLite-tagged and always succeeds.
        let result = registry
            .execute("think", &serde_json::json!({ "thought": "reasoning..." }))
            .await
            .unwrap();
        assert!(result.contains("reasoning"));
    }

    #[test]
    fn allowed_tool_names_matches_get_definitions() {
        let registry = build_registry(ToolTier::ChatPro);
        let allowed = registry.allowed_tool_names();
        let defs: Vec<String> = registry
            .get_definitions()
            .into_iter()
            .map(|t| t.name)
            .collect();
        assert_eq!(allowed.len(), defs.len());
    }

    // ───── Phase 5 authority: explicit per-tool allowlist ─────

    #[test]
    fn explicit_allowlist_hides_tier_allowed_tools_from_get_definitions() {
        let mut registry = build_registry(ToolTier::Agent);
        let tier_only = registry.get_definitions().len();
        assert!(tier_only > 2, "agent tier must expose multiple tools");

        // Pick two real tool names present at Agent tier.
        let allowed: HashSet<String> = registry
            .get_definitions()
            .into_iter()
            .map(|t| t.name)
            .take(2)
            .collect();
        assert_eq!(allowed.len(), 2);

        registry.set_allowed_tool_names(Some(allowed.clone()));
        let after = registry.get_definitions();
        assert_eq!(after.len(), 2, "explicit allowlist must shrink the visible tool set");
        for def in &after {
            assert!(allowed.contains(&def.name));
        }
    }

    #[test]
    fn explicit_allowlist_allowed_tool_names_matches_get_definitions() {
        let mut registry = build_registry(ToolTier::Agent);
        let first_three: HashSet<String> = registry
            .get_definitions()
            .into_iter()
            .map(|t| t.name)
            .take(3)
            .collect();
        registry.set_allowed_tool_names(Some(first_three.clone()));
        let names = registry.allowed_tool_names();
        assert_eq!(
            names.iter().cloned().collect::<HashSet<_>>(),
            first_three,
            "allowed_tool_names() must reflect the explicit allowlist"
        );
    }

    #[tokio::test]
    async fn execute_denies_tier_allowed_tool_when_explicit_allowlist_excludes_it() {
        let mut registry = build_registry(ToolTier::Agent);
        // `think` is tier-allowed at any chat tier. Excluding it via the
        // explicit allowlist must cause execute() to return PermissionDenied.
        let mut allowlist = HashSet::new();
        allowlist.insert("vault_read".to_string()); // allow something else
        registry.set_allowed_tool_names(Some(allowlist));

        let err = registry
            .execute("think", &serde_json::json!({ "thought": "hello" }))
            .await
            .unwrap_err();
        assert!(matches!(err, ToolError::PermissionDenied));
    }

    #[tokio::test]
    async fn execute_permits_tool_when_explicit_allowlist_includes_it() {
        let mut registry = build_registry(ToolTier::Agent);
        let mut allowlist = HashSet::new();
        allowlist.insert("think".to_string());
        registry.set_allowed_tool_names(Some(allowlist));

        let result = registry
            .execute("think", &serde_json::json!({ "thought": "reasoning..." }))
            .await
            .unwrap();
        assert!(result.contains("reasoning"));
    }

    #[test]
    fn clearing_allowlist_restores_tier_only_filtering() {
        let mut registry = build_registry(ToolTier::Agent);
        let tier_only = registry.get_definitions().len();

        let mut allowlist = HashSet::new();
        allowlist.insert("think".to_string());
        registry.set_allowed_tool_names(Some(allowlist));
        assert_eq!(registry.get_definitions().len(), 1);

        registry.set_allowed_tool_names(None);
        assert_eq!(
            registry.get_definitions().len(),
            tier_only,
            "clearing allowlist must restore full tier-only surface"
        );
    }
}
