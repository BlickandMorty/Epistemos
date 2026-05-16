use std::collections::{HashMap, HashSet};
use std::panic::AssertUnwindSafe;
use std::sync::{Arc, OnceLock};

use async_trait::async_trait;
use futures::FutureExt;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use crate::storage::vault::{VaultBackend, VaultError};
use crate::types::ToolSchema;

/// Phase R.5 — env-flag gate. Default is **enforcement ON**: when a
/// grant store is non-empty and this tool call doesn't match any
/// grant, the R.5 gate rejects the call before the handler runs.
/// `EPISTEMOS_R5_ENFORCE=0` (or `false`/`no`/`off`) is the escape
/// hatch — primarily for operators who need to roll back to
/// advisory-only behaviour while diagnosing a grant-store issue.
///
/// Any other value — including `1`/`true`/`yes`/`on` — leaves
/// enforcement on, matching the unset default.
///
/// Prior to 2026-04-23 the default was advisory; the R.5
/// arm-by-arm expansion landed first so the flip here doesn't
/// accidentally block anything that has no ResourceId mapping
/// (those tools return `None` from `infer_tool_authz_target` and
/// bypass the gate entirely — see
/// `resources::tool_authz::tests::non_resourceable_mutating_tools_return_none`).
///
/// Placed here (rather than a general config module) because the
/// only consumer is `ToolRegistry::execute` directly below.
fn r5_enforce_enabled() -> bool {
    match std::env::var("EPISTEMOS_R5_ENFORCE") {
        Ok(raw) => !matches!(
            raw.trim().to_ascii_lowercase().as_str(),
            "0" | "false" | "no" | "off"
        ),
        Err(_) => true,
    }
}

#[cfg(not(feature = "pro-build"))]
fn mas_forbidden_tool_name(name: &str) -> bool {
    matches!(
        name,
        "action.bash"
            | "action.terminal"
            | "bash_execute"
            | "run_command"
            | "run_persistent"
            | "terminal"
            | "process"
            | "system.process"
            | "cronjob"
            | "system.cron"
    )
}

#[cfg(not(feature = "pro-build"))]
fn mas_allows_bounded_internal_mutation(name: &str, input: &Value) -> bool {
    let action = input
        .get("action")
        .and_then(Value::as_str)
        .unwrap_or("read");
    match name {
        // App-contained memory and SSM state are bounded local state, not
        // arbitrary filesystem / process / network execution. Keep this list
        // deliberately tiny so future mutating tools fail closed until audited.
        "memory" => matches!(action, "add" | "replace" | "remove" | "read"),
        "ssm_resume" => matches!(action, "save" | "load" | "list" | "prune"),
        _ => false,
    }
}

#[cfg(not(feature = "pro-build"))]
fn mas_runtime_preflight(
    tool: &RegisteredTool,
    input: &Value,
    authz_target: Option<&crate::resources::tool_authz::ToolAuthzTarget>,
) -> Result<(), ToolError> {
    if mas_forbidden_tool_name(&tool.name) {
        tracing::warn!(
            tool = tool.name.as_str(),
            "App Store runtime preflight denied forbidden tool"
        );
        return Err(ToolError::PermissionDenied);
    }

    if matches!(tool.risk_level, RiskLevel::Destructive) {
        tracing::warn!(
            tool = tool.name.as_str(),
            "App Store runtime preflight denied destructive tool"
        );
        return Err(ToolError::PermissionDenied);
    }

    if matches!(tool.risk_level, RiskLevel::Modification)
        && authz_target.is_none()
        && !mas_allows_bounded_internal_mutation(&tool.name, input)
    {
        tracing::warn!(
            tool = tool.name.as_str(),
            "App Store runtime preflight denied unscoped mutating tool"
        );
        return Err(ToolError::PermissionDenied);
    }

    Ok(())
}

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
///
/// # HELIOS doctrine cross-reference
///
/// `ToolTier` is the **chat-mode-aware** tool-exposure ladder. The
/// **deployment-tier-aware** capability matrix lives in
/// `epistemos-research/src/mas_capability_lattice.rs` (research-tier,
/// `--features research`) and is a different axis:
///
///   - `ToolTier` (this enum, active app): None/ChatLite/ChatPro/Agent/Full
///     — controls which tools are exposed within a single deployment.
///   - `DeploymentTier` (HELIOS canon): MasCore / Pro / Research
///     — controls which capabilities ship in each distribution channel.
///   - `Capability` (HELIOS canon): 12 named capabilities (SelectedVault-
///     Retrieval, TouchIdGating, AppGroupSharedSubstrate, SandboxedXpc-
///     Helper, CuratedLocalToolManifests, FirstPartyCloudProvider-
///     Adapters, ArbitraryDownloadedSkills, ShellOrSubprocessOrchestration,
///     AppleEventsAutomation, BrowserAutomation, RawAneOrPrivateFrameworks,
///     UnrestrictedWasmOrJit).
///
/// Active-app implementation status per HELIOS capability (audited
/// 2026-05-12):
///
/// | HELIOS Capability                  | Active-app analog                                        | status     |
/// |------------------------------------|----------------------------------------------------------|------------|
/// | SelectedVaultRetrieval             | `Epistemos/Sync/VaultSyncService.swift` (security bookmark) | shipped    |
/// | TouchIdGating                      | LocalAuthentication biometric path                       | shipped    |
/// | AppGroupSharedSubstrate            | `agent_core::shared_memory::ShmPool` (L0 only)           | shipped    |
/// | SandboxedXpcHelper                 | XPC doctrine, state: candidate                           | NOT shipped|
/// | CuratedLocalToolManifests          | `agent_core::tools::registry::ToolTier` (this enum)      | shipped    |
/// | FirstPartyCloudProviderAdapters    | `agent_core::providers::{claude, perplexity, ...}`       | shipped    |
/// | ArbitraryDownloadedSkills          | (intentionally not in MAS per doctrine)                  | NOT shipped|
/// | ShellOrSubprocessOrchestration     | `agent_core::tools::cli_passthrough` (Pro feature)       | shipped (Pro) |
/// | AppleEventsAutomation              | `agent_core::tools::apple::imessage` (osascript)         | shipped (Pro) |
/// | BrowserAutomation                  | `agent_core::tools::browser` + chrome MCP                | shipped (Pro) |
/// | RawAneOrPrivateFrameworks          | (research only, never product)                           | NOT shipped|
/// | UnrestrictedWasmOrJit              | (deferred per MAS-First doctrine)                        | NOT shipped|
///
/// Drift gate: the test
/// `epistemos-research/src/mas_capability_lattice.rs::tests::active_app_capability_coverage_table_locked`
/// locks the 12 canonical capability names so HELIOS can't rename a
/// row without forcing this table to update.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub enum ToolTier {
    /// No tools — raw text generation only.
    None,
    /// Safe read-only research: web.search, knowledge.recall, file.read, think...
    ChatLite,
    /// Adds cloud media, local media subprocess, and perception tools on top of ChatLite.
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
    !matches!(tool_name, "image_generate" | "media.image_generate")
}

pub fn is_reserved_tool_name(tool_name: &str) -> bool {
    static RESERVED: OnceLock<HashSet<String>> = OnceLock::new();
    RESERVED
        .get_or_init(build_reserved_tool_names)
        .contains(tool_name)
}

fn build_reserved_tool_names() -> HashSet<String> {
    struct ReservedNameVault;

    #[async_trait]
    impl VaultBackend for ReservedNameVault {
        async fn hybrid_search(
            &self,
            _query: &str,
            _limit: usize,
            _tag_filter: &[String],
        ) -> Result<Vec<crate::storage::vault::SearchResult>, VaultError> {
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

    let registry = ToolRegistry::with_tier(
        Arc::new(ReservedNameVault),
        true,
        None::<std::path::PathBuf>,
        ToolTier::Full,
    );
    let mut names: HashSet<String> = registry
        .get_all_definitions()
        .into_iter()
        .map(|tool| tool.name)
        .collect();
    names.insert("tool_manage".to_string());
    names
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

pub const LEGACY_TO_V2_ALIASES: &[(&str, &str)] = &[
    ("vault_search", "vault.search"),
    ("vault_read", "vault.read"),
    ("vault_write", "vault.write"),
    ("vault_get", "vault.read"),
    ("pkm_search", "vault.search"),
    ("pkm_get", "vault.read"),
    ("pkm_write", "vault.write"),
    ("chunk_reduce", "chunk.reduce"),
    ("pkm_graph_neighbors", "graph.neighbors"),
    ("read_file", "file.read"),
    ("write_file", "file.write"),
    ("edit_file", "file.patch"),
    ("delete_file", "file.delete"),
    ("patch", "file.patch"),
    ("search_files", "file.search"),
    ("list_files", "file.list"),
    ("move_file", "file.move"),
    ("todo", "system.todo"),
    ("vault_recall", "knowledge.recall"),
    ("contradiction_check", "knowledge.contradiction_check"),
    ("analyzecontradiction", "knowledge.contradiction_check"),
    ("scoreevidence", "knowledge.evidence_score"),
    ("neural_recall", "knowledge.neural_recall"),
    ("session_search", "knowledge.session_search"),
    ("create_note", "note.create"),
    ("edit_note", "note.edit"),
    ("search_notes", "vault.search"),
    ("list_notes", "vault.list"),
    ("note_template", "note.template"),
    ("note_linker", "note.linker"),
    ("research_digest", "note.research_digest"),
    ("collectsnippet", "research.collect_snippet"),
    ("createresearchnote", "note.research_digest"),
    ("citation_extractor", "citation.extract"),
    ("savecitation", "citation.save"),
    ("markdown_table", "markdown.table"),
    ("graph_query", "graph.query"),
    ("vault_navigate", "graph.vault_navigate"),
    ("memory", "memory.curated"),
    ("open_url", "web.fetch"),
    ("web_search", "web.search"),
    ("search_web", "web.search"),
    ("web_fetch", "web.fetch"),
    ("readpagecontent", "web.extract"),
    ("searchpapers", "research.search_papers"),
    ("web_extract", "web.extract"),
    ("web_crawl", "web.crawl"),
    ("route_private", "inference.route_private"),
    ("clarify", "clarify.ask"),
    ("ssm_resume", "inference.ssm_resume"),
    ("constrained_generate", "inference.constrained_generate"),
    ("capture_screenshot", "capture.screenshot"),
    ("capture_voice", "capture.voice"),
    ("capture_clipboard", "capture.clipboard"),
];

#[cfg(feature = "pro-build")]
pub const PRO_LEGACY_TO_V2_ALIASES: &[(&str, &str)] = &[
    ("bash_execute", "action.bash"),
    ("run_command", "action.bash"),
    ("run_persistent", "action.terminal"),
    ("terminal", "action.terminal"),
    ("process", "system.process"),
    ("cronjob", "system.cron"),
    ("skills_list", "skills.list"),
    ("skill_view", "skills.view"),
    ("skill_manage", "skills.manage"),
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
    ("perceive", "macos.perceive"),
    ("interact", "macos.interact"),
    ("screen_watch", "macos.screen_watch"),
    ("nightbrain_trigger", "intelligence.nightbrain_trigger"),
    ("inline_partner", "intelligence.inline_partner"),
];

pub fn v2_name_for_legacy(name: &str) -> Option<&'static str> {
    let common = LEGACY_TO_V2_ALIASES
        .iter()
        .find_map(|(legacy, dotted)| (*legacy == name).then_some(*dotted));
    #[cfg(feature = "pro-build")]
    {
        common.or_else(|| {
            PRO_LEGACY_TO_V2_ALIASES
                .iter()
                .find_map(|(legacy, dotted)| (*legacy == name).then_some(*dotted))
        })
    }
    #[cfg(not(feature = "pro-build"))]
    {
        common
    }
}

pub fn legacy_name_for_v2(name: &str) -> Option<&'static str> {
    let common = LEGACY_TO_V2_ALIASES
        .iter()
        .find_map(|(legacy, dotted)| (*dotted == name).then_some(*legacy));
    #[cfg(feature = "pro-build")]
    {
        common.or_else(|| {
            PRO_LEGACY_TO_V2_ALIASES
                .iter()
                .find_map(|(legacy, dotted)| (*dotted == name).then_some(*legacy))
        })
    }
    #[cfg(not(feature = "pro-build"))]
    {
        common
    }
}

fn surface_name_for_registered(name: &str) -> &str {
    v2_name_for_legacy(name).unwrap_or(name)
}

fn allowlist_contains_equivalent(allowlist: &HashSet<String>, name: &str) -> bool {
    allowlist.contains(name)
        || v2_name_for_legacy(name).is_some_and(|v2_name| allowlist.contains(v2_name))
        || legacy_name_for_v2(name).is_some_and(|legacy_name| allowlist.contains(legacy_name))
}

pub struct ToolRegistry {
    tools: HashMap<String, RegisteredTool>,
    vault: Arc<dyn VaultBackend>,
    #[cfg_attr(not(feature = "pro-build"), allow(dead_code))]
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
}

impl ToolRegistry {
    pub fn new(vault: Arc<dyn VaultBackend>) -> Self {
        let mut registry = Self {
            tools: HashMap::new(),
            vault,
            enable_bash: !cfg!(not(feature = "pro-build")),
            vault_root_path: None,
            active_tier: ToolTier::Full,
            allowed_tool_names: None,
        };
        registry.register_default_tools();
        registry
    }

    pub fn with_bash_enabled(vault: Arc<dyn VaultBackend>, enable_bash: bool) -> Self {
        let mut registry = Self {
            tools: HashMap::new(),
            vault,
            enable_bash: enable_bash && !cfg!(not(feature = "pro-build")),
            vault_root_path: None,
            active_tier: ToolTier::Full,
            allowed_tool_names: None,
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
            enable_bash: enable_bash && !cfg!(not(feature = "pro-build")),
            vault_root_path: Some(vault_root.into()),
            active_tier: ToolTier::Full,
            allowed_tool_names: None,
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
            enable_bash: enable_bash && !cfg!(not(feature = "pro-build")),
            vault_root_path: vault_root.map(Into::into),
            active_tier: tier,
            allowed_tool_names: None,
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

    #[cfg(feature = "pro-build")]
    pub fn register_delegate_task_tool(
        &mut self,
        provider: Arc<dyn crate::provider::AgentProvider>,
        current_depth: u32,
    ) {
        use crate::tools::delegate_task::{delegate_task_tool_schema, DelegateTaskTool};

        let mut child_registry = ToolRegistry::with_tier(
            Arc::clone(&self.vault),
            self.enable_bash,
            self.vault_root_path.clone(),
            self.active_tier,
        );
        child_registry.allowed_tool_names = self.allowed_tool_names.clone();

        let schema = delegate_task_tool_schema();
        self.register(RegisteredTool {
            name: schema.name,
            description: schema.description,
            parameters: schema.parameters,
            handler: Box::new(DelegateTaskTool::new(
                provider,
                Arc::new(child_registry),
                current_depth,
            )),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });
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
            if !allowlist_contains_equivalent(allowlist, &tool.name) {
                return false;
            }
        }
        true
    }

    fn registered_name_for<'a>(&self, name: &'a str) -> Option<&'a str> {
        if self.tools.contains_key(name) {
            return Some(name);
        }
        legacy_name_for_v2(name).filter(|legacy_name| self.tools.contains_key(*legacy_name))
    }

    pub fn register(&mut self, tool: RegisteredTool) {
        self.tools.insert(tool.name.clone(), tool);
    }

    /// Returns true if a tool with the given name is already registered.
    /// Used by late-bound registration paths (e.g. stdio MCP tool discovery)
    /// to avoid clobbering a built-in handler with a same-named remote tool.
    pub fn contains_tool(&self, name: &str) -> bool {
        self.tools.contains_key(name)
    }

    /// Return the schemas for every surfaced tool permitted by the current
    /// active tier AND the explicit allowlist (if set). This is what the
    /// agent loop sends to the model at each turn, so filtering here is how
    /// we hide destructive tools from chat-mode sessions, hide unshipped
    /// capabilities from the model-facing catalog, and honor the Agent
    /// Command Center's per-tool toggle choices.
    pub fn get_definitions(&self) -> Vec<ToolSchema> {
        let mut surfaced: HashMap<String, ToolSchema> = HashMap::new();
        for tool in self
            .tools
            .values()
            .filter(|tool| self.is_tool_permitted(tool))
        {
            let name = surface_name_for_registered(&tool.name).to_string();
            if !is_user_visible_tool(&name) {
                continue;
            }

            let schema = ToolSchema {
                name: name.clone(),
                description: tool.description.clone(),
                parameters: tool.parameters.clone(),
            };

            if tool.name == name || !surfaced.contains_key(&name) {
                surfaced.insert(name, schema);
            }
        }

        let mut definitions: Vec<ToolSchema> = surfaced.into_values().collect();
        definitions.sort_by(|a, b| a.name.cmp(&b.name));
        definitions
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
            .map(|tool| surface_name_for_registered(&tool.name).to_string())
            .collect();
        names.sort();
        names.dedup();
        names
    }

    pub fn get_risk_level(&self, name: &str) -> RiskLevel {
        self.registered_name_for(name)
            .and_then(|registered_name| self.tools.get(registered_name))
            .map(|tool| tool.risk_level.clone())
            .unwrap_or(RiskLevel::ReadOnly)
    }

    pub fn get_tier(&self, name: &str) -> ToolTier {
        self.registered_name_for(name)
            .and_then(|registered_name| self.tools.get(registered_name))
            .map(|tool| tool.tier)
            .unwrap_or(ToolTier::Agent)
    }

    pub async fn execute(&self, name: &str, input: &Value) -> Result<String, ToolError> {
        let registered_name = self.registered_name_for(name).unwrap_or(name);
        let tool = self
            .tools
            .get(registered_name)
            .ok_or_else(|| ToolError::InvalidArguments(format!("unknown tool: {name}")))?;
        // Second layer of enforcement: even if a model guesses a tool name
        // not in get_definitions(), reject it here against tier AND the
        // explicit per-tool allowlist (if set).
        if !self.is_tool_permitted(tool) {
            return Err(ToolError::PermissionDenied);
        }

        let authz_target = crate::resources::tool_authz::infer_tool_authz_target(
            registered_name,
            input,
            &tool.risk_level,
            self.vault_root_path.as_deref(),
        );

        #[cfg(not(feature = "pro-build"))]
        mas_runtime_preflight(tool, input, authz_target.as_ref())?;

        // Phase R.5 authorization gate. Infers a `(ResourceId, Capability)`
        // target for mutating tools, consults the process-local
        // permission store, and denies the call when no grant covers the
        // target. Enforcement is ON by default for App Store hardening;
        // `EPISTEMOS_R5_ENFORCE=0` is the explicit operator rollback
        // path. Telemetry is emitted in both modes so operators can tune
        // policy against real traffic without muting visibility.
        if let Some(target) = authz_target {
            let granted = crate::resources::bridge::check_resource_capability(
                target.resource.clone(),
                target.capability,
            )
            .await;
            let enforce = r5_enforce_enabled();
            let active_grants = crate::resources::bridge::active_grant_count().await;
            tracing::info!(
                tool = name,
                capability = ?target.capability,
                granted = granted,
                enforce = enforce,
                active_grants = active_grants,
                "R.5 tool authorization check"
            );
            if !granted && enforce {
                // Strict policy: a resource-targeted mutating tool must
                // have a matching stored grant. Reject before the handler
                // runs so nothing mutates.
                return Err(ToolError::PermissionDenied);
            }
        }

        // Panic isolation: wrap the handler future in catch_unwind so a
        // panicking tool (bad unwrap inside a downstream crate, slice OOB
        // in a parse path, etc.) does NOT take down the whole agent
        // session. The panic is converted into ToolError::ExecutionFailed
        // so the agent loop can surface it back to the model, which can
        // then recover or retry with different input.
        let fut = AssertUnwindSafe(tool.handler.execute(input));
        match fut.catch_unwind().await {
            Ok(result) => result,
            Err(panic) => {
                let message = if let Some(s) = panic.downcast_ref::<&str>() {
                    (*s).to_string()
                } else if let Some(s) = panic.downcast_ref::<String>() {
                    s.clone()
                } else {
                    format!("tool '{name}' panicked")
                };
                tracing::error!("tool handler panic in '{name}': {message}");
                Err(ToolError::ExecutionFailed(format!(
                    "tool '{name}' panicked: {message}"
                )))
            }
        }
    }

    pub async fn execute_v2(&self, name: &str, input: &Value) -> Result<String, ToolError> {
        self.execute(name, input).await
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

    fn register_default_tools(&mut self) {
        self.register_vault_search();
        self.register_vault_read();
        self.register_vault_write();
        self.register_vault_list();
        self.register_think_tool();
        self.register_chunk_reduce();
        self.register_workspace_search();
        self.register_pkm_graph_neighbors();

        #[cfg(feature = "pro-build")]
        {
            if self.enable_bash {
                self.register_bash_execute();
            }

            // Tunnel C — delegate a task to Claude Code / Codex / Gemini /
            // Kimi / Goose / Aider / OpenHands / mini-SWE-agent CLI. Same `enable_bash` gate because these are subprocess
            // spawners with the same trust profile. The gemini + kimi
            // handlers (added 2026-05-05 per user request "i don't see
            // CLIs at all si please fix") follow the same shape as the
            // claude_code / codex pair.
            if self.enable_bash {
                self.register_claude_code_passthrough();
                self.register_codex_passthrough();
                self.register_gemini_passthrough();
                self.register_kimi_passthrough();
                self.register_goose_passthrough();
                self.register_aider_passthrough();
                self.register_openhands_passthrough();
                self.register_mini_swe_agent_passthrough();
            }
        }

        // Phase 1 core tools (Hermes/OpenClaw parity)
        self.register_phase_one_filesystem();
        self.register_phase_one_file_ops();
        self.register_phase_one_todo();
        self.register_phase_one_skills_core();
        #[cfg(feature = "pro-build")]
        {
            self.register_phase_one_terminal();
            self.register_phase_one_scheduling();
            self.register_phase_one_skills_progressive();
            self.register_phase_one_custom_tools();
        }

        // Phase 2 knowledge & memory tools (vault-native specialties)
        self.register_phase_two_knowledge();
        self.register_phase_two_note_tools();
        self.register_phase_two_graph();
        self.register_phase_two_memory();

        // Phase 3 web tools — replaces the legacy DuckDuckGo web_search.
        self.register_phase_three_web();

        #[cfg(feature = "pro-build")]
        {
            // Phase 4 Apple app tools (pure Rust via osascript).
            self.register_phase_four_apple_apps();
        }

        // Phase 5 inference specialties — route_private is pure Rust. The
        // Swift-dependent ones (ssm_resume, constrained_generate) are wired
        // in via register_delegate_tools().
        self.register_phase_five_route_private();

        #[cfg(feature = "pro-build")]
        {
            // Phase 6 communication + media tools.
            self.register_phase_six_communication();
            self.register_phase_six_media();
            self.register_phase_six_imessage();

            // Phase 7 intelligence layer (pure-Rust parts).
            self.register_phase_seven_intelligence();

            // Phase 8 discovery + trajectory + skill marketplace (post-plan work
            // — comprehensive Hermes/OpenClaw parity pass). Most are read-only;
            // mcp_discover is Modification because it can optionally create
            // missing config directories, and trajectory_export writes JSONL.
            self.register_phase_eight_discovery();
            self.register_phase_eight_trajectory();
        }

        // Tier rebalance: mark the read-only research tools as ChatLite so
        // normal chat (fast/thinking) can call them, and the Pro-only
        // cloud/macOS-privileged tools as ChatPro so Pro mode picks them
        // up with their own risk labels intact.
        self.apply_tier_overrides();
    }

    #[cfg(feature = "pro-build")]
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
            risk_level: RiskLevel::Modification,
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

    #[cfg(feature = "pro-build")]
    fn register_phase_eight_trajectory(&mut self) {
        use crate::tools::trajectory::{trajectory_export_schema, TrajectoryExportHandler};
        if std::env::var_os("DISABLE_TRAJECTORY_EXPORT").is_some() {
            tracing::warn!(
                "trajectory_export registration skipped because DISABLE_TRAJECTORY_EXPORT is set"
            );
            return;
        }
        if let Some(root) = self.vault_root_path.clone() {
            let registration = std::panic::catch_unwind(AssertUnwindSafe(|| {
                let schema = trajectory_export_schema();
                RegisteredTool {
                    name: schema.name,
                    description: schema.description,
                    parameters: schema.parameters,
                    handler: Box::new(TrajectoryExportHandler::new(root)),
                    risk_level: RiskLevel::Modification,
                    tier: ToolTier::Agent,
                }
            }));
            match registration {
                Ok(tool) => self.register(tool),
                Err(panic) => {
                    let message = if let Some(s) = panic.downcast_ref::<&str>() {
                        (*s).to_string()
                    } else if let Some(s) = panic.downcast_ref::<String>() {
                        s.clone()
                    } else {
                        "trajectory_export registration panicked".to_string()
                    };
                    tracing::error!(
                        "trajectory_export registration skipped after panic: {message}"
                    );
                }
            }
        }
    }

    /// Downgrade chat-safe tools from their default `Agent` tier so normal
    /// chat modes can see them. Only tools whose handlers are side-effect
    /// free (or have narrowly scoped side-effects like `think`) should be
    /// downgraded here.
    fn apply_tier_overrides(&mut self) {
        // Tier: ChatLite — safe for even the smallest local model.
        // These are the ones the user specifically called out (web_search,
        // vault.search, file.read, think) plus the obvious read-only cousins.
        const CHAT_LITE: &[&str] = &[
            // Research / web
            "web_search",
            "searchpapers",
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

        // Tier: ChatPro — adds cloud-backed and macOS-privileged tools
        // plus narrowly-scoped vault writes the user explicitly asked
        // for in Pro mode (Research 3, 2026-04-19). `vault_write` and
        // vault-scoped `patch` gate behind the AgentAuthority
        // `vaultWrite` category so destructive side-effects still prompt
        // the user; elevating them out of Agent-only was the single gap
        // that made "save this to a note" hallucinate instead of writing.
        // `memory` is session-level and self-repairing so it rides along.
        // Anything on CHAT_LITE is also available here.
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
            // Vault writes (gated by AgentAuthority.vaultWrite approval)
            "vault_write",
            "patch",
            "memory",
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

    #[cfg(feature = "pro-build")]
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

    #[cfg(feature = "pro-build")]
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

    #[cfg(feature = "pro-build")]
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
            risk_level: RiskLevel::Modification,
            tier: ToolTier::Agent,
        });
    }

    #[cfg(feature = "pro-build")]
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

    #[cfg(feature = "pro-build")]
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
        let schema = clarify_schema();
        self.register(RegisteredTool {
            name: schema.name,
            description: schema.description,
            parameters: schema.parameters,
            handler: Box::new(ClarifyHandler::new(Arc::clone(&delegate))),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });

        #[cfg(feature = "pro-build")]
        {
            use crate::tools::macos::{
                interact_schema, perceive_schema, screen_watch_schema, InteractHandler,
                PerceiveHandler, ScreenWatchHandler,
            };

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
        }

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

        #[cfg(feature = "pro-build")]
        {
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
                Err(e) => tracing::warn!("image_generate delegate-aware registration skipped: {e}"),
            }
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

    fn register_phase_one_file_ops(&mut self) {
        use crate::tools::file_ops::{file_ops_tool_schema, FileOpsTool};

        let schema = file_ops_tool_schema();
        self.register(RegisteredTool {
            name: schema.name,
            description: schema.description,
            parameters: schema.parameters,
            handler: Box::new(FileOpsTool::new()),
            risk_level: RiskLevel::Modification,
            tier: ToolTier::Agent,
        });
    }

    #[cfg(feature = "pro-build")]
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

    #[cfg(feature = "pro-build")]
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

    fn register_phase_one_skills_core(&mut self) {
        use crate::agent_runtime::skills::{default_skills_dir, skills_tool_schema, SkillsTool};

        let legacy = skills_tool_schema();
        self.register(RegisteredTool {
            name: legacy.name,
            description: legacy.description,
            parameters: legacy.parameters,
            handler: Box::new(SkillsTool::new(default_skills_dir())),
            risk_level: RiskLevel::Modification,
            tier: ToolTier::Agent,
        });
    }

    #[cfg(feature = "pro-build")]
    fn register_phase_one_skills_progressive(&mut self) {
        use crate::agent_runtime::skills::{
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

    #[cfg(feature = "pro-build")]
    fn register_phase_one_custom_tools(&mut self) {
        use crate::tools::custom_tools::{
            custom_tool_manage_schema, load_custom_tool_specs, CustomToolManageHandler,
            CustomToolRuntimeHandler,
        };

        let Some(vault_root) = self.vault_root_path.clone() else {
            return;
        };

        let schema = custom_tool_manage_schema();
        self.register(RegisteredTool {
            name: schema.name,
            description: schema.description,
            parameters: schema.parameters,
            handler: Box::new(CustomToolManageHandler::new(vault_root.clone())),
            risk_level: RiskLevel::Modification,
            tier: ToolTier::Agent,
        });

        for spec in load_custom_tool_specs(&vault_root) {
            if self.tools.contains_key(&spec.name) {
                tracing::warn!(
                    "custom tool '{}' conflicts with an existing tool and was skipped",
                    spec.name
                );
                continue;
            }

            self.register(RegisteredTool {
                name: spec.name.clone(),
                description: spec.model_description(),
                parameters: spec.input_schema.clone(),
                handler: Box::new(CustomToolRuntimeHandler::new(spec.clone())),
                risk_level: spec.risk_level(),
                tier: spec.tier(),
            });
        }
    }

    fn register_phase_two_knowledge(&mut self) {
        use crate::tools::knowledge::{
            contradiction_check_schema, evidence_score_schema, neural_recall_schema,
            vault_recall_schema, ContradictionCheckHandler, EvidenceScoreHandler,
            NeuralRecallHandler, VaultRecallHandler,
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

        let es = evidence_score_schema();
        self.register(RegisteredTool {
            name: es.name,
            description: es.description,
            parameters: es.parameters,
            handler: Box::new(EvidenceScoreHandler),
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

    fn register_phase_two_note_tools(&mut self) {
        use crate::tools::note_tools::{
            citation_extractor_schema, citation_save_schema, markdown_table_schema,
            note_create_schema, note_edit_schema, note_linker_schema, note_template_schema,
            research_collect_snippet_schema, research_digest_schema, CitationExtractorTool,
            CitationSaveTool, MarkdownTableTool, NoteCreateTool, NoteEditTool, NoteLinkerTool,
            NoteTemplateTool, ResearchCollectSnippetTool, ResearchDigestTool,
        };

        let nc = note_create_schema();
        self.register(RegisteredTool {
            name: nc.name,
            description: nc.description,
            parameters: nc.parameters,
            handler: Box::new(NoteCreateTool::new(Arc::clone(&self.vault))),
            risk_level: RiskLevel::Modification,
            tier: ToolTier::Agent,
        });

        let ne = note_edit_schema();
        self.register(RegisteredTool {
            name: ne.name,
            description: ne.description,
            parameters: ne.parameters,
            handler: Box::new(NoteEditTool::new(Arc::clone(&self.vault))),
            risk_level: RiskLevel::Modification,
            tier: ToolTier::Agent,
        });

        let nt = note_template_schema();
        self.register(RegisteredTool {
            name: nt.name,
            description: nt.description,
            parameters: nt.parameters,
            handler: Box::new(NoteTemplateTool::new(Arc::clone(&self.vault))),
            risk_level: RiskLevel::Modification,
            tier: ToolTier::Agent,
        });

        if let Some(root) = self.vault_root_path.clone() {
            let nl = note_linker_schema();
            self.register(RegisteredTool {
                name: nl.name,
                description: nl.description,
                parameters: nl.parameters,
                handler: Box::new(NoteLinkerTool::new(Arc::clone(&self.vault), root)),
                risk_level: RiskLevel::ReadOnly,
                tier: ToolTier::Agent,
            });
        }

        let rd = research_digest_schema();
        self.register(RegisteredTool {
            name: rd.name,
            description: rd.description,
            parameters: rd.parameters,
            handler: Box::new(ResearchDigestTool::new(Arc::clone(&self.vault))),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });

        let ce = citation_extractor_schema();
        self.register(RegisteredTool {
            name: ce.name,
            description: ce.description,
            parameters: ce.parameters,
            handler: Box::new(CitationExtractorTool),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });

        let cs = citation_save_schema();
        self.register(RegisteredTool {
            name: cs.name,
            description: cs.description,
            parameters: cs.parameters,
            handler: Box::new(CitationSaveTool::new(Arc::clone(&self.vault))),
            risk_level: RiskLevel::Modification,
            tier: ToolTier::Agent,
        });

        let rcs = research_collect_snippet_schema();
        self.register(RegisteredTool {
            name: rcs.name,
            description: rcs.description,
            parameters: rcs.parameters,
            handler: Box::new(ResearchCollectSnippetTool::new(Arc::clone(&self.vault))),
            risk_level: RiskLevel::Modification,
            tier: ToolTier::Agent,
        });

        let mt = markdown_table_schema();
        self.register(RegisteredTool {
            name: mt.name,
            description: mt.description,
            parameters: mt.parameters,
            handler: Box::new(MarkdownTableTool),
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
            description: "Hybrid semantic and keyword search across the personal knowledge vault. \
                Use this first when the user names or describes a note but you do not yet have \
                its exact vault-relative path."
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
            description: "Read the full content of a note by its vault-relative path. Use \
                vault_search first if you only know the note title or topic."
                .to_string(),
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

    fn register_vault_list(&mut self) {
        let vault = Arc::clone(&self.vault);
        self.register(RegisteredTool {
            name: "list_notes".to_string(),
            description: "List vault-relative note paths under an optional folder prefix. \
                Returns paths sorted alphabetically (not by relevance). \
                IF YOU WANT NOTES ABOUT A TOPIC or relevance-ranked results, USE vault.search INSTEAD — \
                list_notes is only for browsing a known folder structure. \
                Pass `query` to auto-route this call to vault.search for convenience."
                .to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "path": {
                        "type": "string",
                        "description": "Optional vault-relative folder path to list",
                        "default": "."
                    },
                    "path_prefix": {
                        "type": "string",
                        "description": "Alias for path"
                    },
                    "prefix": {
                        "type": "string",
                        "description": "Alias for path"
                    },
                    "query": {
                        "type": "string",
                        "description": "If supplied, this call is auto-routed to vault.search for \
                            relevance-ranked results. Use this for any 'find notes about X' intent."
                    },
                    "limit": {
                        "type": "integer",
                        "description": "Maximum note paths to return",
                        "default": 50,
                        "minimum": 1,
                        "maximum": 200
                    }
                }
            }),
            handler: Box::new(VaultListHandler { vault }),
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

    #[cfg(feature = "pro-build")]
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

    #[cfg(feature = "pro-build")]
    fn register_claude_code_passthrough(&mut self) {
        self.register(RegisteredTool {
            name: "claude_code".to_string(),
            description: "Delegate a coding task to Anthropic's Claude Code CLI running in non-interactive mode. \
                The delegated agent has Claude Code's full tool surface (shell, file edit, git, test runner, MCP servers, skills). \
                Use for multi-step coding work where you want Claude Code's own loop to own the turn. \
                Returns combined stdout/stderr. If Claude Code is not installed, returns a structured install-hint.".to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "task": {
                        "type": "string",
                        "description": "The prompt / instructions to pass to Claude Code."
                    },
                    "working_dir": {
                        "type": "string",
                        "description": "Optional absolute path to run the Claude Code session in."
                    },
                    "model": {
                        "type": "string",
                        "description": "Optional model alias or id (e.g. 'opus', 'sonnet', 'claude-sonnet-4-6'). Omit to use Claude Code's default."
                    },
                    "bypass_permissions": {
                        "type": "boolean",
                        "default": true,
                        "description": "When true (default), run with --permission-mode bypassPermissions so the delegated agent doesn't re-prompt. Set false to keep Claude Code's own approval flow."
                    },
                    "timeout_seconds": {
                        "type": "integer",
                        "default": 300,
                        "maximum": 1800,
                        "description": "Timeout for the CLI invocation. Default 5 minutes, max 30 minutes."
                    }
                },
                "required": ["task"]
            }),
            handler: Box::new(crate::tools::cli_passthrough::ClaudeCodeHandler),
            risk_level: RiskLevel::Destructive,
            tier: ToolTier::Agent,
        });
    }

    #[cfg(feature = "pro-build")]
    fn register_codex_passthrough(&mut self) {
        self.register(RegisteredTool {
            name: "codex".to_string(),
            description: "Delegate a coding task to OpenAI's Codex CLI running in `codex exec` mode. \
                The delegated agent has Codex's full tool surface (shell, file edit, sandboxed commands, MCP servers, git). \
                Set sandbox=true to run under `codex sandbox` for an additional command sandbox layer. \
                Returns combined stdout/stderr. If Codex is not installed, returns a structured install-hint.".to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "task": {
                        "type": "string",
                        "description": "The prompt / instructions to pass to Codex."
                    },
                    "working_dir": {
                        "type": "string",
                        "description": "Optional absolute path to run the Codex session in."
                    },
                    "sandbox": {
                        "type": "boolean",
                        "default": false,
                        "description": "When true, invoke `codex sandbox <task>` instead of `codex exec <task>`. Extra sandbox layer for untrusted tasks."
                    },
                    "timeout_seconds": {
                        "type": "integer",
                        "default": 300,
                        "maximum": 1800,
                        "description": "Timeout for the CLI invocation. Default 5 minutes, max 30 minutes."
                    }
                },
                "required": ["task"]
            }),
            handler: Box::new(crate::tools::cli_passthrough::CodexHandler),
            risk_level: RiskLevel::Destructive,
            tier: ToolTier::Agent,
        });
    }

    #[cfg(feature = "pro-build")]
    fn register_gemini_passthrough(&mut self) {
        self.register(RegisteredTool {
            name: "gemini".to_string(),
            description: "Delegate a coding task to Google's Gemini CLI in non-interactive mode \
                (`gemini -p <task>`). The delegated agent has Gemini's full tool surface. \
                Optional `model` overrides the default model. \
                Returns combined stdout/stderr. If Gemini is not installed, returns a structured install-hint."
                .to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "task": {
                        "type": "string",
                        "description": "The prompt / instructions to pass to Gemini."
                    },
                    "model": {
                        "type": "string",
                        "description": "Optional model override (e.g. 'gemini-2.5-pro', 'gemini-2.5-flash')."
                    },
                    "working_dir": {
                        "type": "string",
                        "description": "Optional absolute path to run the Gemini session in."
                    },
                    "timeout_seconds": {
                        "type": "integer",
                        "default": 300,
                        "maximum": 1800,
                        "description": "Timeout for the CLI invocation. Default 5 minutes, max 30 minutes."
                    }
                },
                "required": ["task"]
            }),
            handler: Box::new(crate::tools::cli_passthrough::GeminiHandler),
            risk_level: RiskLevel::Destructive,
            tier: ToolTier::Agent,
        });
    }

    #[cfg(feature = "pro-build")]
    fn register_kimi_passthrough(&mut self) {
        self.register(RegisteredTool {
            name: "kimi".to_string(),
            description: "Delegate a coding task to Moonshot's Kimi CLI in non-interactive mode \
                (`kimi -p <task>`). The delegated agent has Kimi's full tool surface. \
                Optional `model` overrides the default model. \
                Returns combined stdout/stderr. If Kimi is not installed, returns a structured install-hint."
                .to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "task": {
                        "type": "string",
                        "description": "The prompt / instructions to pass to Kimi."
                    },
                    "model": {
                        "type": "string",
                        "description": "Optional model override (e.g. 'kimi-k2', 'kimi-k1.5')."
                    },
                    "working_dir": {
                        "type": "string",
                        "description": "Optional absolute path to run the Kimi session in."
                    },
                    "timeout_seconds": {
                        "type": "integer",
                        "default": 300,
                        "maximum": 1800,
                        "description": "Timeout for the CLI invocation. Default 5 minutes, max 30 minutes."
                    }
                },
                "required": ["task"]
            }),
            handler: Box::new(crate::tools::cli_passthrough::KimiHandler),
            risk_level: RiskLevel::Destructive,
            tier: ToolTier::Agent,
        });
    }

    #[cfg(feature = "pro-build")]
    fn register_goose_passthrough(&mut self) {
        self.register(RegisteredTool {
            name: "goose".to_string(),
            description: "Delegate a coding task to Goose CLI in headless run mode \
                (`goose run --no-session -t <task>`). The delegated agent uses Goose's configured \
                provider, model, and extension ecosystem while Epistemos keeps the shared hardened \
                Tunnel C receipt boundary. Defaults to JSON output and no persistent Goose session. \
                Returns a structured receipt. If Goose is not installed, returns a structured install-hint."
                .to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "task": {
                        "type": "string",
                        "description": "The prompt / instructions to pass to Goose."
                    },
                    "provider": {
                        "type": "string",
                        "description": "Optional Goose provider override, for example 'anthropic', 'openai', or another provider configured in Goose."
                    },
                    "model": {
                        "type": "string",
                        "description": "Optional Goose model override."
                    },
                    "builtin_extensions": {
                        "type": "array",
                        "items": { "type": "string" },
                        "description": "Optional Goose built-in extensions to enable, passed as --with-builtin with comma-separated values."
                    },
                    "working_dir": {
                        "type": "string",
                        "description": "Optional absolute path to run the Goose session in."
                    },
                    "no_session": {
                        "type": "boolean",
                        "default": true,
                        "description": "When true (default), pass --no-session so one-off delegated runs do not persist Goose session state."
                    },
                    "output_json": {
                        "type": "boolean",
                        "default": true,
                        "description": "When true (default), request Goose's JSON output format for automation."
                    },
                    "timeout_seconds": {
                        "type": "integer",
                        "default": 300,
                        "maximum": 1800,
                        "description": "Timeout for the CLI invocation. Default 5 minutes, max 30 minutes."
                    }
                },
                "required": ["task"]
            }),
            handler: Box::new(crate::tools::cli_passthrough::GooseHandler),
            risk_level: RiskLevel::Destructive,
            tier: ToolTier::Agent,
        });
    }

    #[cfg(feature = "pro-build")]
    fn register_aider_passthrough(&mut self) {
        self.register(RegisteredTool {
            name: "aider".to_string(),
            description: "Delegate a coding task to Aider in single-message scripting mode \
                (`aider --message <task>`). The delegated agent can edit files in the selected \
                working directory using Aider's own model and repo-map loop. By default Epistemos \
                disables Aider auto-commits so host commit discipline stays explicit. \
                Returns a structured receipt. If Aider is not installed, returns a structured install-hint."
                .to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "task": {
                        "type": "string",
                        "description": "The prompt / instructions to pass to Aider."
                    },
                    "model": {
                        "type": "string",
                        "description": "Optional Aider model override (for example 'sonnet', 'openai/gpt-5.2', or another model id supported by Aider)."
                    },
                    "working_dir": {
                        "type": "string",
                        "description": "Optional absolute path to run the Aider session in."
                    },
                    "yes_always": {
                        "type": "boolean",
                        "default": true,
                        "description": "When true (default), pass --yes-always so the non-interactive invocation can proceed without re-prompting."
                    },
                    "auto_commits": {
                        "type": "boolean",
                        "default": false,
                        "description": "When true, allow Aider's auto-commit behavior. Default false passes --no-auto-commits."
                    },
                    "dirty_commits": {
                        "type": "boolean",
                        "default": false,
                        "description": "When true, allow Aider dirty-worktree commits. Default false passes --no-dirty-commits."
                    },
                    "timeout_seconds": {
                        "type": "integer",
                        "default": 300,
                        "maximum": 1800,
                        "description": "Timeout for the CLI invocation. Default 5 minutes, max 30 minutes."
                    }
                },
                "required": ["task"]
            }),
            handler: Box::new(crate::tools::cli_passthrough::AiderHandler),
            risk_level: RiskLevel::Destructive,
            tier: ToolTier::Agent,
        });
    }

    #[cfg(feature = "pro-build")]
    fn register_openhands_passthrough(&mut self) {
        self.register(RegisteredTool {
            name: "openhands".to_string(),
            description: "Delegate a coding task to OpenHands CLI in headless mode \
                (`openhands --headless --json -t <task>` by default). OpenHands headless mode \
                runs without an interactive UI and uses OpenHands' local configuration while \
                Epistemos keeps the shared hardened Tunnel C receipt boundary. \
                Returns a structured receipt. If OpenHands is not installed, returns a structured install-hint."
                .to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "task": {
                        "type": "string",
                        "description": "The prompt / instructions to pass to OpenHands."
                    },
                    "working_dir": {
                        "type": "string",
                        "description": "Optional absolute path to run the OpenHands session in."
                    },
                    "output_json": {
                        "type": "boolean",
                        "default": true,
                        "description": "When true (default), pass --json so OpenHands emits JSONL events for automation."
                    },
                    "timeout_seconds": {
                        "type": "integer",
                        "default": 300,
                        "maximum": 1800,
                        "description": "Timeout for the CLI invocation. Default 5 minutes, max 30 minutes."
                    }
                },
                "required": ["task"]
            }),
            handler: Box::new(crate::tools::cli_passthrough::OpenHandsHandler),
            risk_level: RiskLevel::Destructive,
            tier: ToolTier::Agent,
        });
    }

    #[cfg(feature = "pro-build")]
    fn register_mini_swe_agent_passthrough(&mut self) {
        self.register(RegisteredTool {
            name: "mini_swe_agent".to_string(),
            description: "Delegate a coding task to mini-SWE-agent in local CLI mode \
                (`mini --yolo --task <task>` by default). mini-SWE-agent uses its configured \
                model/provider setup and local environment while Epistemos keeps the shared \
                hardened Tunnel C receipt boundary. \
                Returns a structured receipt. If mini-SWE-agent is not installed, returns a structured install-hint."
                .to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "task": {
                        "type": "string",
                        "description": "The prompt / instructions to pass to mini-SWE-agent."
                    },
                    "model": {
                        "type": "string",
                        "description": "Optional mini-SWE-agent model override, for example 'anthropic/claude-sonnet-4-5-20250929'."
                    },
                    "config": {
                        "type": "string",
                        "description": "Optional mini-SWE-agent config file name or path, passed through --config."
                    },
                    "working_dir": {
                        "type": "string",
                        "description": "Optional absolute path to run the mini-SWE-agent session in."
                    },
                    "yolo": {
                        "type": "boolean",
                        "default": true,
                        "description": "When true (default), pass --yolo so the delegated run does not block on confirmation prompts."
                    },
                    "timeout_seconds": {
                        "type": "integer",
                        "default": 300,
                        "maximum": 1800,
                        "description": "Timeout for the CLI invocation. Default 5 minutes, max 30 minutes."
                    }
                },
                "required": ["task"]
            }),
            handler: Box::new(crate::tools::cli_passthrough::MiniSweAgentHandler),
            risk_level: RiskLevel::Destructive,
            tier: ToolTier::Agent,
        });
    }

    fn register_phase_three_web(&mut self) {
        use crate::tools::web::{
            search_papers_schema, web_crawl_schema, web_extract_schema, web_search_schema,
            SearchPapersHandler, WebCrawlHandler, WebExtractHandler, WebSearchHandler,
        };
        use crate::tools::web_fetch::{web_fetch_tool_schema, WebFetchTool};

        let fetch = web_fetch_tool_schema();
        self.register(RegisteredTool {
            name: fetch.name,
            description: fetch.description,
            parameters: fetch.parameters,
            handler: Box::new(WebFetchTool::new()),
            risk_level: RiskLevel::ReadOnly,
            tier: ToolTier::Agent,
        });

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

        match SearchPapersHandler::new() {
            Ok(handler) => {
                let schema = search_papers_schema();
                self.register(RegisteredTool {
                    name: schema.name,
                    description: schema.description,
                    parameters: schema.parameters,
                    handler: Box::new(handler),
                    risk_level: RiskLevel::ReadOnly,
                    tier: ToolTier::Agent,
                });
            }
            Err(e) => tracing::warn!("searchpapers registration skipped: {e}"),
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

        #[cfg(feature = "pro-build")]
        {
            use crate::tools::browser::{
                browser_back_schema, browser_click_schema, browser_close_schema,
                browser_console_schema, browser_get_images_schema, browser_navigate_schema,
                browser_press_schema, browser_scroll_schema, browser_snapshot_schema,
                browser_type_schema, browser_vision_schema, BrowserAction, BrowserActionHandler,
                BrowserManager,
            };

            let browser_manager = BrowserManager::new();
            let mut register_browser =
                |schema: crate::types::ToolSchema, action: BrowserAction, risk_level: RiskLevel| {
                    self.register(RegisteredTool {
                        name: schema.name,
                        description: schema.description,
                        parameters: schema.parameters,
                        handler: Box::new(BrowserActionHandler::new(
                            browser_manager.clone(),
                            action,
                        )),
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
        // Master Fusion Plan §B.1: vault.search dispatch walks the
        // typed Variant Ladder at `crate::tools::vault_search_ladder`.
        // As of B.1 2/N the ladder ships T1 (lexical-only via
        // VaultBackend::lexical_search, FLOOR_T1 = 0.85) → T3 (RRF
        // hybrid, FLOOR_T3 = 0.70). When T2 embedding-only lands in a
        // follow-up slice, this call site does not change — the
        // ladder constructor adds variants and resolve_walk() honors
        // the new tiers automatically.
        //
        // §B.1 4/N (this PR): switched to `resolve_walk()` so we get
        // the full per-attempt audit trail (not just the winning tier)
        // and emit a structured tracing event per call. Future Swift
        // ChatCoordinator + Provenance Console rows subscribe to the
        // `target = "vault_search.ladder_walk"` tracing target.
        use crate::tools::vault_search_ladder::{
            build_vault_search_ladder, VaultSearchLadderInput,
        };

        let query = input
            .get("query")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("query required".to_string()))?;
        let limit = (input.get("limit").and_then(Value::as_u64).unwrap_or(5) as usize)
            .clamp(1, 20);
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

        let ladder_input = VaultSearchLadderInput {
            query: query.to_string(),
            limit,
            tags,
            backend: self.vault.clone(),
        };
        let ladder = build_vault_search_ladder()
            .map_err(|e| ToolError::ExecutionFailed(e.to_string()))?;

        let walk = ladder.resolve_walk(&ladder_input).await;

        // Emit a structured trace for every walk — resolved OR
        // deferred. The `target` is stable so a Swift-side
        // tracing-subscriber can filter to just ladder events for the
        // Provenance Console. `LadderAttempt` now derives Serialize
        // (added in B.1 5/N) so the attempts vec serializes directly
        // via serde — no manual JSON construction needed.
        let attempts_json = serde_json::to_string(&walk.attempts)
            .unwrap_or_else(|_| "[]".to_string());
        let resolved_variant = walk
            .resolution
            .as_ref()
            .map(|r| r.variant_name.clone())
            .unwrap_or_else(|| "deferred".to_string());
        tracing::info!(
            target: "vault_search.ladder_walk",
            query = %query,
            limit = limit,
            tag_filter_count = walk_tag_count(&ladder_input.tags),
            resolved = walk.resolution.is_some(),
            resolved_variant = %resolved_variant,
            attempts_count = walk.attempts.len(),
            attempts = %attempts_json,
            "vault.search ladder walk complete"
        );

        let Some(resolution) = walk.resolution else {
            // Doctrine §6: "Defer is a first-class outcome." Every tier
            // declined (e.g. no result met FLOOR_T3 = 0.70). Surface
            // honestly rather than silently escalating.
            return Ok(
                "No notes matched with high enough confidence (ladder declined; no tier above floor)."
                    .to_string(),
            );
        };

        Ok(resolution
            .output
            .results
            .iter()
            .enumerate()
            .map(|(index, result)| {
                format!(
                    "{}. **{}** (score: {:.2}, tier: {:?}, variant: {})\n{}",
                    index + 1,
                    result.path,
                    result.score,
                    resolution.tier,
                    resolution.variant_name,
                    result.excerpt
                )
            })
            .collect::<Vec<_>>()
            .join("\n\n"))
    }
}

/// Tag-filter count helper — keeps the tracing macro readable.
fn walk_tag_count(tags: &[String]) -> usize {
    tags.len()
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

struct VaultListHandler {
    vault: Arc<dyn VaultBackend>,
}

#[async_trait]
impl ToolHandler for VaultListHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        // RCA-LOCAL-AGENT-VAULT-LIST-001 (2026-05-15): if the caller
        // supplied a `query`, route this call to vault.search rather
        // than returning the alphabetically-first N paths. This is the
        // fix for the user-reported "Qwen listed only 7 irrelevant
        // notes" bug — relevance-ranked results are vastly more useful
        // than alphabetical filesystem-order for any "find notes about
        // X" intent, and small local models often pick list_notes when
        // they should pick vault.search.
        if let Some(query) = input
            .get("query")
            .and_then(Value::as_str)
            .map(str::trim)
            .filter(|q| !q.is_empty())
        {
            let limit = input.get("limit").and_then(Value::as_u64).unwrap_or(10) as usize;
            let limit = limit.clamp(1, 20);
            let results = self
                .vault
                .hybrid_search(query, limit, &[])
                .await
                .map_err(map_vault_error)?;

            if results.is_empty() {
                return Ok(format!(
                    "No notes matched `{query}` (auto-routed from list_notes to vault.search). \
                     Try a different query or call list_notes without `query` to browse paths."
                ));
            }

            let header = format!(
                "Auto-routed to vault.search for relevance (query: `{query}`). \
                 Returned {} result{}:",
                results.len(),
                if results.len() == 1 { "" } else { "s" }
            );
            let body = results
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
                .join("\n\n");
            return Ok(format!("{header}\n\n{body}"));
        }

        let path_prefix = input
            .get("path")
            .or_else(|| input.get("path_prefix"))
            .or_else(|| input.get("prefix"))
            .and_then(Value::as_str)
            .unwrap_or(".")
            .trim();
        let path_prefix = if path_prefix.is_empty() {
            "."
        } else {
            path_prefix
        };
        let limit = input.get("limit").and_then(Value::as_u64).unwrap_or(50) as usize;
        let limit = limit.clamp(1, 200);

        let mut entries = self
            .vault
            .list(path_prefix)
            .await
            .map_err(map_vault_error)?;
        entries.sort();
        entries.dedup();

        if entries.is_empty() {
            return Ok(format!("No notes found under `{path_prefix}`."));
        }

        let total = entries.len();
        let mut lines: Vec<String> = Vec::with_capacity(limit.min(total) + 3);
        lines.push(format!(
            "Vault has {} note{} under `{path_prefix}` (alphabetical, NOT relevance-ranked).",
            total,
            if total == 1 { "" } else { "s" },
        ));
        lines.extend(entries.iter().take(limit).map(|path| format!("- {path}")));
        if total > limit {
            lines.push(format!(
                "- ...and {} more (alphabetical truncation). \
                 To find notes ABOUT a topic, call vault.search with a query — \
                 alphabetical listing rarely shows the most relevant ones first.",
                total - limit
            ));
        }
        Ok(lines.join("\n"))
    }
}

struct VaultWriteHandler {
    vault: Arc<dyn VaultBackend>,
}

fn expected_vault_write_readback(
    previous: Option<&str>,
    content: &str,
    tags: &[String],
    append: bool,
) -> String {
    if append {
        if let Some(previous) = previous {
            return format!("{previous}\n{content}");
        }
    }

    if content.starts_with("---") || tags.is_empty() {
        content.to_string()
    } else {
        let frontmatter = format!(
            "---\ntags:\n{}\n---\n\n",
            tags.iter()
                .map(|tag| format!("  - {tag}"))
                .collect::<Vec<_>>()
                .join("\n")
        );
        format!("{frontmatter}{content}")
    }
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

        let previous_content = if append {
            match self.vault.read(path).await {
                Ok(content) => Some(content),
                Err(VaultError::NotFound(_)) => None,
                Err(error) => {
                    return Err(ToolError::ExecutionFailed(format!(
                        "pre-write readback failed for append verification: {error}"
                    )));
                }
            }
        } else {
            None
        };

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

        let expected_readback =
            expected_vault_write_readback(previous_content.as_deref(), content, &tags, append);
        let actual_readback = self.vault.read(path).await.map_err(|error| {
            ToolError::ExecutionFailed(format!(
                "write verification readback failed for '{path}': {error}"
            ))
        })?;
        if actual_readback != expected_readback {
            return Err(ToolError::ExecutionFailed(format!(
                "write verification failed for '{path}': readback did not match requested content \
                 (expected {} bytes, got {} bytes)",
                expected_readback.len(),
                actual_readback.len()
            )));
        }

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
            "verified": true,
        })
        .to_string())
    }
}

#[cfg(feature = "pro-build")]
struct BashExecuteHandler;

#[async_trait]
#[cfg(feature = "pro-build")]
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
        // Doctrine-mandated subprocess hardening for the LLM-driven
        // bash execution path. `bash -lc` runs LLM-supplied command
        // strings with shell expansion, so blocking inherited
        // LD_PRELOAD / DYLD_INSERT_LIBRARIES / NODE_OPTIONS / PYTHONPATH
        // is non-negotiable. The blocked-pattern list above catches
        // overtly destructive commands; subprocess hardening covers
        // the silent-injection vectors that pattern matching can't see.
        crate::security::harden_cli_subprocess(&mut process);
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

        // Post-read output cap (see cli_passthrough.rs for rationale —
        // doctrine's "Codex 1.8GB stdout regression" hardest-problem).
        const MAX_OUTPUT_BYTES: usize = 10 * 1024 * 1024;
        let stdout_bytes = &output.stdout[..output.stdout.len().min(MAX_OUTPUT_BYTES)];
        let stderr_bytes = &output.stderr[..output.stderr.len().min(MAX_OUTPUT_BYTES)];
        let stdout = String::from_utf8_lossy(stdout_bytes).trim().to_string();
        let stderr = String::from_utf8_lossy(stderr_bytes).trim().to_string();
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
    // Test-isolation gate held across `.await` is intentional — see
    // `resources/bridge.rs::tests` for the canonical rationale. The
    // tier registry tests share a process-wide registry singleton
    // and must serialize.
    #![allow(clippy::await_holding_lock)]

    use super::*;
    use crate::storage::vault::{SearchResult, VaultBackend, VaultError};
    use async_trait::async_trait;
    use std::collections::{HashMap, HashSet};
    use std::sync::Mutex as TestMutex;

    /// Minimal vault stub for registry construction in unit tests.
    #[derive(Default)]
    struct NullVault {
        notes: TestMutex<HashMap<String, String>>,
    }

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
        async fn read(&self, path: &str) -> Result<String, VaultError> {
            let notes = self
                .notes
                .lock()
                .map_err(|_| VaultError::DatabaseError("test vault lock poisoned".to_string()))?;
            Ok(notes.get(path).cloned().unwrap_or_default())
        }
        async fn write(
            &self,
            path: &str,
            content: &str,
            tags: Option<&[String]>,
            append: bool,
        ) -> Result<(), VaultError> {
            let mut notes = self
                .notes
                .lock()
                .map_err(|_| VaultError::DatabaseError("test vault lock poisoned".to_string()))?;
            let previous = notes.get(path).cloned();
            let empty_tags: Vec<String> = Vec::new();
            let tags = tags.unwrap_or(&empty_tags);
            notes.insert(
                path.to_string(),
                expected_vault_write_readback(previous.as_deref(), content, tags, append),
            );
            Ok(())
        }
        async fn list(&self, path_prefix: &str) -> Result<Vec<String>, VaultError> {
            let notes = self
                .notes
                .lock()
                .map_err(|_| VaultError::DatabaseError("test vault lock poisoned".to_string()))?;
            let prefix = path_prefix.trim();
            let prefix = if prefix.is_empty() || prefix == "." {
                ""
            } else {
                prefix.trim_matches('/')
            };
            let mut paths: Vec<String> = notes
                .keys()
                .filter(|path| prefix.is_empty() || path.starts_with(prefix))
                .cloned()
                .collect();
            paths.sort();
            Ok(paths)
        }
        async fn exists(&self, _path: &str) -> Result<bool, VaultError> {
            Ok(false)
        }
        async fn delete(&self, _path: &str) -> Result<bool, VaultError> {
            Ok(false)
        }
    }

    struct LyingVault;

    #[async_trait]
    impl VaultBackend for LyingVault {
        async fn hybrid_search(
            &self,
            _query: &str,
            _limit: usize,
            _tag_filter: &[String],
        ) -> Result<Vec<SearchResult>, VaultError> {
            Ok(Vec::new())
        }
        async fn read(&self, _path: &str) -> Result<String, VaultError> {
            Ok("not the requested content".to_string())
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
            Ok(true)
        }
        async fn delete(&self, _path: &str) -> Result<bool, VaultError> {
            Ok(false)
        }
    }

    fn build_registry(tier: ToolTier) -> ToolRegistry {
        ToolRegistry::with_tier(
            Arc::new(NullVault::default()),
            true,
            None::<std::path::PathBuf>,
            tier,
        )
    }

    fn build_registry_with_root(tier: ToolTier, vault_root: &std::path::Path) -> ToolRegistry {
        ToolRegistry::with_tier(
            Arc::new(NullVault::default()),
            true,
            Some(vault_root.to_path_buf()),
            tier,
        )
    }

    #[cfg(not(feature = "pro-build"))]
    struct StaticOkHandler;

    #[cfg(not(feature = "pro-build"))]
    #[async_trait]
    impl ToolHandler for StaticOkHandler {
        async fn execute(&self, _input: &serde_json::Value) -> Result<String, ToolError> {
            Ok(serde_json::json!({ "success": true }).to_string())
        }
    }

    #[cfg(not(feature = "pro-build"))]
    fn register_test_tool(registry: &mut ToolRegistry, name: &str, risk_level: RiskLevel) {
        registry.register(RegisteredTool {
            name: name.to_string(),
            description: "test tool".to_string(),
            parameters: serde_json::json!({
                "type": "object",
                "properties": {
                    "action": { "type": "string" },
                    "path": { "type": "string" }
                }
            }),
            handler: Box::new(StaticOkHandler),
            risk_level,
            tier: ToolTier::ChatLite,
        });
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
        // web_search only appears when a backend env var is present — the
        // runtime contract is that the tool must disappear entirely when
        // no provider is configured. Seed a test-only key so the registry
        // builds with the expected lite-tier shape, then restore the prior
        // env value.
        let _env_guard = crate::test_support::env_lock();
        let saved_tavily = std::env::var("TAVILY_API_KEY").ok();
        std::env::set_var("TAVILY_API_KEY", "test-fixture-key");

        let registry = build_registry(ToolTier::ChatLite);
        let names: Vec<String> = registry
            .get_definitions()
            .into_iter()
            .map(|t| t.name)
            .collect();

        match saved_tavily {
            Some(v) => std::env::set_var("TAVILY_API_KEY", v),
            None => std::env::remove_var("TAVILY_API_KEY"),
        }

        assert!(
            names.contains(&"web.search".to_string()),
            "chat_lite must expose web.search when a backend is configured, got: {names:?}"
        );
        assert!(
            names.contains(&"knowledge.recall".to_string()),
            "chat_lite must expose knowledge.recall"
        );
        assert!(names.contains(&"think".to_string()));
        assert!(names.contains(&"file.read".to_string()));
        assert!(names.contains(&"web.fetch".to_string()));
        assert!(
            !names.contains(&"web_search".to_string())
                && !names.contains(&"web_fetch".to_string())
                && !names.contains(&"vault_recall".to_string())
                && !names.contains(&"read_file".to_string()),
            "model-facing catalog must surface canonical V2 names, not legacy names: {names:?}"
        );
    }

    #[test]
    fn hermes_parity_phase_one_tools_are_registered() {
        let temp = tempfile::tempdir().unwrap();
        let registry = build_registry_with_root(ToolTier::Full, temp.path());
        let names: std::collections::HashSet<String> = registry
            .get_all_definitions()
            .into_iter()
            .map(|tool| tool.name)
            .collect();

        for required in ["file_ops", "memory", "skills", "web_fetch"] {
            assert!(
                names.contains(required),
                "B.1 Phase 1 must register {required}; got {names:?}"
            );
        }
    }

    #[test]
    fn phase_two_note_tools_are_registered_without_orphan_source() {
        let temp = tempfile::tempdir().unwrap();
        let registry = build_registry_with_root(ToolTier::Full, temp.path());
        let names: std::collections::HashSet<String> = registry
            .get_all_definitions()
            .into_iter()
            .map(|tool| tool.name)
            .collect();

        for required in [
            "create_note",
            "edit_note",
            "note_template",
            "note_linker",
            "research_digest",
            "citation_extractor",
            "savecitation",
            "collectsnippet",
            "markdown_table",
        ] {
            assert!(
                names.contains(required),
                "note scaffold must be wired or explicitly archived; missing {required}"
            );
        }

        assert_eq!(
            registry.get_risk_level("note_template"),
            RiskLevel::Modification
        );
        assert_eq!(
            registry.get_risk_level("note.create"),
            RiskLevel::Modification
        );
        assert_eq!(
            registry.get_risk_level("research.collect_snippet"),
            RiskLevel::Modification
        );
        assert_eq!(
            registry.get_risk_level("citation_extractor"),
            RiskLevel::ReadOnly
        );
        assert_eq!(
            registry.get_risk_level("markdown_table"),
            RiskLevel::ReadOnly
        );
    }

    #[test]
    fn tools_v2_alias_table_preserves_quick_capture_contract() {
        #[cfg(feature = "pro-build")]
        assert!(
            LEGACY_TO_V2_ALIASES.len() + PRO_LEGACY_TO_V2_ALIASES.len() >= 56,
            "Tools V2 recovery must preserve the Quick Capture alias surface"
        );
        #[cfg(not(feature = "pro-build"))]
        assert!(
            LEGACY_TO_V2_ALIASES.len() >= 30,
            "MAS Tools V2 alias surface must preserve non-subprocess aliases"
        );
        assert_eq!(v2_name_for_legacy("vault_search"), Some("vault.search"));
        assert_eq!(legacy_name_for_v2("vault.search"), Some("vault_search"));
        assert_eq!(v2_name_for_legacy("read_file"), Some("file.read"));
        assert_eq!(legacy_name_for_v2("file.read"), Some("read_file"));
        assert_eq!(
            v2_name_for_legacy("think"),
            None,
            "think intentionally stays legacy-shaped until reason.think can preserve output parity"
        );
    }

    #[tokio::test]
    async fn execute_v2_accepts_canonical_dotted_names() {
        let registry = build_registry(ToolTier::ChatLite);
        let result = registry
            .execute_v2("vault.read", &serde_json::json!({ "path": "missing.md" }))
            .await
            .expect("dotted v2 vault.read must route through the current registry");

        assert_eq!(result, "");
    }

    #[test]
    fn model_facing_tool_catalog_surfaces_v2_aliases() {
        let registry = build_registry(ToolTier::Agent);
        let names: std::collections::HashSet<String> = registry
            .get_definitions()
            .into_iter()
            .map(|tool| tool.name)
            .collect();

        for canonical in [
            "vault.search",
            "vault.read",
            "vault.list",
            "note.create",
            "note.edit",
            "research.collect_snippet",
            "citation.save",
            "research.search_papers",
            "file.read",
            "file.search",
            "knowledge.recall",
            "knowledge.evidence_score",
            "graph.neighbors",
        ] {
            assert!(
                names.contains(canonical),
                "model-facing catalog must expose V2 tool name {canonical}; got {names:?}"
            );
        }

        for legacy in [
            "vault_search",
            "vault_read",
            "create_note",
            "edit_note",
            "list_notes",
            "collectsnippet",
            "savecitation",
            "searchpapers",
            "read_file",
            "search_files",
            "vault_recall",
            "scoreevidence",
            "pkm_graph_neighbors",
        ] {
            assert!(
                !names.contains(legacy),
                "legacy tool name {legacy} must not be model-facing once a V2 alias exists"
            );
        }
    }

    #[test]
    fn allowed_tool_names_surface_v2_aliases() {
        let registry = build_registry(ToolTier::Agent);
        let names = registry.allowed_tool_names();

        assert!(names.contains(&"vault.search".to_string()));
        assert!(names.contains(&"file.read".to_string()));
        assert!(names.contains(&"vault.list".to_string()));
        assert!(names.contains(&"note.create".to_string()));
        assert!(names.contains(&"research.collect_snippet".to_string()));
        assert!(names.contains(&"citation.save".to_string()));
        assert!(names.contains(&"research.search_papers".to_string()));
        assert!(!names.contains(&"vault_search".to_string()));
        assert!(!names.contains(&"read_file".to_string()));
        assert!(!names.contains(&"list_notes".to_string()));
    }

    #[tokio::test]
    async fn v2_allowlist_accepts_legacy_and_canonical_callers() {
        let mut registry = build_registry(ToolTier::Agent);
        registry.set_allowed_tool_names(Some(HashSet::from(["vault.read".to_string()])));

        let canonical = registry
            .execute_v2("vault.read", &serde_json::json!({ "path": "note.md" }))
            .await
            .expect("canonical V2 name should be allowed");
        let legacy = registry
            .execute_v2("vault_read", &serde_json::json!({ "path": "note.md" }))
            .await
            .expect("legacy compatibility caller should resolve through the V2 allowlist");

        assert_eq!(canonical, "");
        assert_eq!(legacy, "");
    }

    #[tokio::test]
    async fn vault_list_executes_through_v2_and_legacy_names() {
        let vault = Arc::new(NullVault::default());
        {
            let mut notes = vault.notes.lock().unwrap();
            notes.insert("research/alpha.md".to_string(), "Alpha".to_string());
            notes.insert("research/beta.md".to_string(), "Beta".to_string());
            notes.insert("daily/today.md".to_string(), "Today".to_string());
        }
        let registry =
            ToolRegistry::with_tier(vault, true, None::<std::path::PathBuf>, ToolTier::Agent);

        let canonical = registry
            .execute_v2(
                "vault.list",
                &serde_json::json!({ "path": "research", "limit": 1 }),
            )
            .await
            .expect("canonical vault.list should execute");
        let legacy = registry
            .execute_v2("list_notes", &serde_json::json!({ "path_prefix": "daily" }))
            .await
            .expect("legacy list_notes should execute");

        assert!(canonical.contains("- research/alpha.md"));
        assert!(canonical.contains("...and 1 more"));
        // RCA-LOCAL-AGENT-VAULT-LIST-001 (2026-05-15): list_notes now
        // prepends a "Vault has N notes under …" header line and an
        // "alphabetical, NOT relevance-ranked" disclaimer so small
        // local models stop returning the alphabetically-first N as if
        // they were relevant. Pin both signals.
        assert!(
            legacy.contains("- daily/today.md"),
            "list_notes output must still contain the path; got: {legacy}"
        );
        assert!(
            legacy.contains("Vault has 1 note"),
            "list_notes output must include total-count diagnostic; got: {legacy}"
        );
        assert!(
            legacy.contains("NOT relevance-ranked"),
            "list_notes output must include the alphabetical disclaimer so the model \
             prefers vault.search for relevance; got: {legacy}"
        );
    }

    #[tokio::test]
    async fn list_notes_auto_routes_to_vault_search_when_query_supplied() {
        // RCA-LOCAL-AGENT-VAULT-LIST-001 source-guard test:
        // when the agent passes a `query` argument to list_notes (a
        // common Qwen / small-LM tool-confusion pattern), the call
        // is routed to vault.search internally so the model never
        // gets the alphabetical-irrelevant-first-N failure mode.
        let vault = Arc::new(NullVault::default());
        {
            let mut notes = vault.notes.lock().unwrap();
            notes.insert(
                "research/alpha.md".to_string(),
                "Alpha discusses state space models in depth.".to_string(),
            );
            notes.insert(
                "daily/today.md".to_string(),
                "Today I learned about graph neural networks.".to_string(),
            );
        }
        let registry =
            ToolRegistry::with_tier(vault, true, None::<std::path::PathBuf>, ToolTier::Agent);

        let result = registry
            .execute_v2(
                "vault.list",
                &serde_json::json!({ "query": "alpha", "limit": 3 }),
            )
            .await
            .expect("vault.list with `query` should auto-route to vault.search");

        // NullVault returns empty hybrid_search results, so we go down
        // the empty-result branch — but the response still tags the
        // call as auto-routed so the agent knows the routing happened.
        assert!(
            result.contains("auto-routed from list_notes to vault.search")
                || result.contains("Auto-routed to vault.search"),
            "list_notes with `query` must surface the auto-route disclaimer so the agent \
             knows the call took the vault.search path (relevance), not the alphabetical \
             path; got: {result}"
        );
    }

    #[test]
    fn v2_alias_risk_and_tier_match_legacy_handler() {
        let registry = build_registry(ToolTier::Agent);

        assert_eq!(
            registry.get_risk_level("file.write"),
            RiskLevel::Modification
        );
        assert_eq!(registry.get_risk_level("file.read"), RiskLevel::ReadOnly);
        assert_eq!(registry.get_tier("file.write"), ToolTier::Agent);
    }

    #[test]
    fn live_agent_paths_use_v2_tool_dispatch() {
        let agent_loop_source = include_str!("../agent_loop.rs");
        let bridge_source = include_str!("../bridge.rs");

        assert!(
            agent_loop_source.contains("tool_registry.execute_v2(&name, &input).await"),
            "agent_loop must execute tools through the V2 compatibility dispatch"
        );
        assert!(
            bridge_source
                .matches("registry.execute_v2(&tool_name, &input).await")
                .count()
                >= 2,
            "Swift-facing single-tool bridges must execute tools through V2 dispatch"
        );
    }

    #[test]
    fn bridge_wires_delegate_task_after_provider_resolution() {
        let bridge_source = include_str!("../bridge.rs");
        assert!(
            bridge_source.contains("register_delegate_task_tool"),
            "run_agent_session_inner must wire delegate_task with the resolved provider"
        );
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
        assert!(!names.contains(&"action.terminal".to_string()));
        assert!(!names.contains(&"bash_execute".to_string()));
        assert!(!names.contains(&"action.bash".to_string()));
        assert!(!names.contains(&"send_message".to_string()));
        assert!(!names.contains(&"communication.send_message".to_string()));
        assert!(!names.contains(&"imessage".to_string()));
        assert!(!names.contains(&"communication.imessage".to_string()));
        assert!(!names.contains(&"write_file".to_string()));
        assert!(!names.contains(&"file.write".to_string()));
        assert!(!names.contains(&"patch".to_string()));
        assert!(!names.contains(&"file.patch".to_string()));
        assert!(!names.contains(&"skill_manage".to_string()));
        assert!(!names.contains(&"skills.manage".to_string()));
        assert!(!names.contains(&"cronjob".to_string()));
        assert!(!names.contains(&"system.cron".to_string()));
    }

    #[test]
    fn computer_placeholder_handler_is_not_registered() {
        let registry = build_registry(ToolTier::Full);
        let names: std::collections::HashSet<String> = registry
            .get_all_definitions()
            .into_iter()
            .map(|tool| tool.name)
            .collect();
        assert!(
            !names.contains("computer"),
            "the Rust computer_use handler is host-intercept scaffolding; shipping computer use must stay on the native Swift ComputerUseBridge path"
        );
    }

    #[cfg(not(feature = "pro-build"))]
    #[test]
    fn mas_sandbox_registry_excludes_unbounded_tools() {
        let _env_guard = crate::test_support::env_lock();
        let saved_tavily = std::env::var("TAVILY_API_KEY").ok();
        std::env::set_var("TAVILY_API_KEY", "test-fixture-key");

        let temp = tempfile::tempdir().unwrap();
        let registry = build_registry_with_root(ToolTier::Full, temp.path());
        let names: std::collections::HashSet<String> = registry
            .get_all_definitions()
            .into_iter()
            .map(|tool| tool.name)
            .collect();

        match saved_tavily {
            Some(v) => std::env::set_var("TAVILY_API_KEY", v),
            None => std::env::remove_var("TAVILY_API_KEY"),
        }

        for blocked in [
            "bash_execute",
            "terminal",
            "process",
            "claude_code",
            "codex",
            "imessage",
            "imessage_contacts",
            "channel_contacts",
            "send_message",
            "apple_notes",
            "apple_reminders",
            "apple_calendar",
            "apple_mail",
            "browser_navigate",
            "browser_click",
            "browser_type",
            "browser_press",
            "browser_close",
            "browser_scroll",
            "skill_manage",
            "custom_tool_manage",
            "cronjob",
            "trajectory_export",
            "mcp_discover",
            "vision_analyze",
            "image_generate",
            "text_to_speech",
            "perceive",
            "interact",
            "screen_watch",
            "nightbrain_trigger",
            "inline_partner",
        ] {
            assert!(
                !names.contains(blocked),
                "{blocked} must not be registered in mas-sandbox"
            );
        }

        for allowed in [
            "vault_search",
            "vault_read",
            "vault_write",
            "read_file",
            "write_file",
            "patch",
            "search_files",
            "think",
            "todo",
            "graph_query",
            "memory",
            "web_search",
            "web_extract",
            "web_crawl",
            "route_private",
        ] {
            assert!(
                names.contains(allowed),
                "{allowed} should remain in bounded MAS registry; got {names:?}"
            );
        }
    }

    #[cfg(not(feature = "pro-build"))]
    #[tokio::test]
    async fn mas_runtime_denies_forbidden_tool_even_if_registered() {
        let mut registry = build_registry(ToolTier::Full);
        register_test_tool(&mut registry, "bash_execute", RiskLevel::ReadOnly);

        let result = registry
            .execute(
                "bash_execute",
                &serde_json::json!({ "command": "echo nope" }),
            )
            .await;
        assert!(matches!(result, Err(ToolError::PermissionDenied)));
    }

    #[cfg(not(feature = "pro-build"))]
    #[tokio::test]
    async fn mas_runtime_denies_destructive_tool_even_if_registered() {
        let mut registry = build_registry(ToolTier::Full);
        register_test_tool(
            &mut registry,
            "local_delete_fixture",
            RiskLevel::Destructive,
        );

        let result = registry
            .execute(
                "local_delete_fixture",
                &serde_json::json!({ "path": "anything" }),
            )
            .await;
        assert!(matches!(result, Err(ToolError::PermissionDenied)));
    }

    #[cfg(not(feature = "pro-build"))]
    #[tokio::test]
    async fn mas_runtime_denies_unscoped_mutating_tool() {
        let mut registry = build_registry(ToolTier::Full);
        register_test_tool(
            &mut registry,
            "unscoped_mutation_fixture",
            RiskLevel::Modification,
        );

        let result = registry
            .execute(
                "unscoped_mutation_fixture",
                &serde_json::json!({ "action": "mutate" }),
            )
            .await;
        assert!(matches!(result, Err(ToolError::PermissionDenied)));
    }

    #[cfg(not(feature = "pro-build"))]
    #[tokio::test]
    async fn mas_runtime_allows_explicit_bounded_internal_mutation() {
        let mut registry = build_registry(ToolTier::Full);
        register_test_tool(&mut registry, "memory", RiskLevel::Modification);

        let result = registry
            .execute("memory", &serde_json::json!({ "action": "add" }))
            .await
            .expect("bounded internal App Store mutation should pass preflight");
        let parsed: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["success"], serde_json::json!(true));
    }

    #[cfg(not(feature = "pro-build"))]
    #[tokio::test]
    async fn mas_runtime_requires_grant_for_file_write() {
        let _guard = r5_gate_test_lock();
        let _env = ScopedEnforceFlag::set_on();

        let temp = tempfile::tempdir().unwrap();
        let target = temp
            .path()
            .join(format!("mas-write-{}.txt", uuid::Uuid::new_v4()));
        let registry = build_registry_with_root(ToolTier::Full, temp.path());

        let result = registry
            .execute(
                "write_file",
                &serde_json::json!({
                    "path": target.to_string_lossy(),
                    "content": "blocked"
                }),
            )
            .await;
        assert!(matches!(result, Err(ToolError::PermissionDenied)));
        assert!(
            !target.exists(),
            "write_file must be denied before the handler creates the file"
        );
    }

    #[cfg(feature = "pro-build")]
    #[test]
    fn chat_pro_adds_vision_and_tts_over_chat_lite() {
        let _env_guard = crate::test_support::env_lock();
        let saved_tavily = std::env::var("TAVILY_API_KEY").ok();
        std::env::set_var("TAVILY_API_KEY", "test-fixture-key");

        let lite = build_registry(ToolTier::ChatLite);
        let pro = build_registry(ToolTier::ChatPro);

        match saved_tavily {
            Some(v) => std::env::set_var("TAVILY_API_KEY", v),
            None => std::env::remove_var("TAVILY_API_KEY"),
        }

        let lite_definitions = lite.get_definitions();
        let pro_definitions = pro.get_definitions();
        let lite_names: std::collections::HashSet<String> =
            lite_definitions.into_iter().map(|t| t.name).collect();
        let pro_names: std::collections::HashSet<String> =
            pro_definitions.iter().map(|t| t.name.clone()).collect();

        // Pro must be a superset of Lite.
        for name in &lite_names {
            assert!(
                pro_names.contains(name),
                "chat_pro missing lite tool '{name}'"
            );
        }
        // Pro adds media/perception tools under the model-facing V2 names.
        assert!(pro_names.contains("media.vision_analyze"));
        assert!(pro_names.contains("media.text_to_speech"));
        assert_eq!(
            pro.get_risk_level("media.text_to_speech"),
            RiskLevel::Modification
        );
        let vision = pro_definitions
            .iter()
            .find(|tool| tool.name == "media.vision_analyze")
            .expect("chat_pro should expose media.vision_analyze");
        assert_eq!(
            vision.parameters["required"],
            serde_json::json!(["allow_cloud_external_requests"])
        );
        let mixture = pro_definitions
            .iter()
            .find(|tool| tool.name == "intelligence.mixture_of_minds")
            .expect("chat_pro should expose intelligence.mixture_of_minds");
        assert_eq!(
            mixture.parameters["required"],
            serde_json::json!(["problem", "allow_cloud_external_requests"])
        );
        let catalog = pro_definitions
            .iter()
            .find(|tool| tool.name == "discovery.model_catalog")
            .expect("chat_pro should expose discovery.model_catalog through chat_lite");
        assert_eq!(
            catalog.parameters["properties"]["source"]["default"],
            serde_json::json!("local")
        );
        assert_eq!(pro.get_risk_level("mcp_discover"), RiskLevel::Modification);

        let vault_root = tempfile::tempdir().unwrap();
        let pro_with_root = build_registry_with_root(ToolTier::ChatPro, vault_root.path());
        let pro_with_root_names: std::collections::HashSet<String> = pro_with_root
            .get_definitions()
            .into_iter()
            .map(|tool| tool.name)
            .collect();
        assert!(pro_with_root_names.contains("intelligence.self_evolve"));
    }

    #[cfg(feature = "pro-build")]
    #[test]
    fn agent_tier_is_superset_of_chat_pro() {
        let _env_guard = crate::test_support::env_lock();
        let saved_tavily = std::env::var("TAVILY_API_KEY").ok();
        std::env::set_var("TAVILY_API_KEY", "test-fixture-key");

        let pro = build_registry(ToolTier::ChatPro);
        let agent = build_registry(ToolTier::Agent);

        match saved_tavily {
            Some(v) => std::env::set_var("TAVILY_API_KEY", v),
            None => std::env::remove_var("TAVILY_API_KEY"),
        }

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
        // Agent tier includes the destructive tools Pro hides, surfaced under V2 names.
        assert!(agent_names.contains("action.terminal"));
        assert!(agent_names.contains("communication.send_message"));
    }

    #[cfg(feature = "pro-build")]
    #[test]
    fn agent_tier_exposes_aider_passthrough_as_destructive() {
        let registry = build_registry(ToolTier::Agent);
        let names: std::collections::HashSet<String> = registry
            .get_definitions()
            .into_iter()
            .map(|tool| tool.name)
            .collect();

        assert!(names.contains("aider"));
        assert_eq!(registry.get_risk_level("aider"), RiskLevel::Destructive);
        assert_eq!(registry.get_tier("aider"), ToolTier::Agent);
    }

    #[cfg(feature = "pro-build")]
    #[test]
    fn agent_tier_exposes_goose_passthrough_as_destructive() {
        let registry = build_registry(ToolTier::Agent);
        let names: std::collections::HashSet<String> = registry
            .get_definitions()
            .into_iter()
            .map(|tool| tool.name)
            .collect();

        assert!(names.contains("goose"));
        assert_eq!(registry.get_risk_level("goose"), RiskLevel::Destructive);
        assert_eq!(registry.get_tier("goose"), ToolTier::Agent);
    }

    #[cfg(feature = "pro-build")]
    #[test]
    fn agent_tier_exposes_openhands_passthrough_as_destructive() {
        let registry = build_registry(ToolTier::Agent);
        let names: std::collections::HashSet<String> = registry
            .get_definitions()
            .into_iter()
            .map(|tool| tool.name)
            .collect();

        assert!(names.contains("openhands"));
        assert_eq!(registry.get_risk_level("openhands"), RiskLevel::Destructive);
        assert_eq!(registry.get_tier("openhands"), ToolTier::Agent);
    }

    #[cfg(feature = "pro-build")]
    #[test]
    fn agent_tier_exposes_mini_swe_agent_passthrough_as_destructive() {
        let registry = build_registry(ToolTier::Agent);
        let names: std::collections::HashSet<String> = registry
            .get_definitions()
            .into_iter()
            .map(|tool| tool.name)
            .collect();

        assert!(names.contains("mini_swe_agent"));
        assert_eq!(
            registry.get_risk_level("mini_swe_agent"),
            RiskLevel::Destructive
        );
        assert_eq!(registry.get_tier("mini_swe_agent"), ToolTier::Agent);
    }

    #[cfg(feature = "pro-build")]
    #[test]
    fn trajectory_export_disappears_when_registration_is_disabled() {
        let saved = std::env::var("DISABLE_TRAJECTORY_EXPORT").ok();
        std::env::set_var("DISABLE_TRAJECTORY_EXPORT", "1");

        let temp = tempfile::tempdir().unwrap();
        let registry = build_registry_with_root(ToolTier::Agent, temp.path());
        let names: std::collections::HashSet<String> = registry
            .get_all_definitions()
            .into_iter()
            .map(|tool| tool.name)
            .collect();

        match saved {
            Some(value) => std::env::set_var("DISABLE_TRAJECTORY_EXPORT", value),
            None => std::env::remove_var("DISABLE_TRAJECTORY_EXPORT"),
        }

        assert!(!names.contains("trajectory_export"));
    }

    #[cfg(feature = "pro-build")]
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
        assert_eq!(
            after.len(),
            2,
            "explicit allowlist must shrink the visible tool set"
        );
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

    #[tokio::test]
    async fn vault_write_returns_success_only_after_readback_matches() {
        let handler = VaultWriteHandler {
            vault: Arc::new(NullVault::default()),
        };
        let result = handler
            .execute(&serde_json::json!({
                "path": "Inbox/Verified.md",
                "content": "verified body",
                "skip_contradiction_check": true
            }))
            .await
            .unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["success"], serde_json::json!(true));
        assert_eq!(parsed["verified"], serde_json::json!(true));
    }

    #[tokio::test]
    async fn vault_write_rejects_success_when_readback_does_not_match() {
        let handler = VaultWriteHandler {
            vault: Arc::new(LyingVault),
        };
        let err = handler
            .execute(&serde_json::json!({
                "path": "Inbox/Lied.md",
                "content": "the requested content",
                "skip_contradiction_check": true
            }))
            .await
            .unwrap_err();
        assert!(
            format!("{err}").contains("write verification failed"),
            "expected readback mismatch to block success, got: {err}"
        );
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

    #[cfg(feature = "pro-build")]
    #[tokio::test]
    async fn custom_tool_specs_become_runtime_tools() {
        let vault_root = tempfile::tempdir().unwrap();
        let tools_dir = vault_root.path().join(".epistemos").join("custom_tools");
        std::fs::create_dir_all(&tools_dir).unwrap();
        std::fs::write(
            tools_dir.join("echo-name.json"),
            serde_json::to_vec_pretty(&serde_json::json!({
                "name": "echo-name",
                "description": "Echo the provided name.",
                "guidance": "Use this instead of raw terminal for simple echoes.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "name": { "type": "string" }
                    },
                    "required": ["name"]
                },
                "command_template": "printf %s {{name}}",
                "risk_level": "modification",
                "tier": "agent"
            }))
            .unwrap(),
        )
        .unwrap();

        let registry = build_registry_with_root(ToolTier::Agent, vault_root.path());
        let visible_names: std::collections::HashSet<String> = registry
            .get_definitions()
            .into_iter()
            .map(|tool| tool.name)
            .collect();
        assert!(visible_names.contains("echo-name"));

        let result = registry
            .execute("echo-name", &serde_json::json!({ "name": "Grace Hopper" }))
            .await
            .unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["success"], serde_json::json!(true));
        assert_eq!(parsed["stdout"], serde_json::json!("Grace Hopper"));
    }

    // -----------------------------------------------------------------
    // Phase R.5 — tool-execution authorization gate
    // -----------------------------------------------------------------
    //
    // These tests mutate two pieces of process-local state: the
    // `EPISTEMOS_R5_ENFORCE` env var (read by `r5_enforce_enabled()`)
    // and the process-local permission store (inside
    // `resources::bridge`). Both are shared with other tests in the
    // crate, so we serialize this group behind a mutex and always
    // restore the env var before returning. Grant IDs are revoked
    // in the test body so the store's residue is bounded.
    //
    // The gate is fail-closed in enforcement mode: grant count is only
    // telemetry. Tests seed unrelated grants to prove that "some grants
    // exist" is not enough; the grant must cover the exact target.

    fn r5_gate_test_lock() -> (
        std::sync::MutexGuard<'static, ()>,
        std::sync::MutexGuard<'static, ()>,
    ) {
        (
            crate::test_support::env_lock(),
            crate::test_support::permission_store_lock(),
        )
    }

    struct ScopedEnforceFlag {
        previous: Option<String>,
    }

    impl ScopedEnforceFlag {
        fn set_on() -> Self {
            let previous = std::env::var("EPISTEMOS_R5_ENFORCE").ok();
            std::env::set_var("EPISTEMOS_R5_ENFORCE", "1");
            Self { previous }
        }

        /// The escape hatch: set the env var to "0" so the gate drops
        /// back to advisory mode. Used by the regression test that
        /// proves operators can roll back to the pre-flip default.
        fn set_off() -> Self {
            let previous = std::env::var("EPISTEMOS_R5_ENFORCE").ok();
            std::env::set_var("EPISTEMOS_R5_ENFORCE", "0");
            Self { previous }
        }

        fn clear() -> Self {
            let previous = std::env::var("EPISTEMOS_R5_ENFORCE").ok();
            std::env::remove_var("EPISTEMOS_R5_ENFORCE");
            Self { previous }
        }
    }

    impl Drop for ScopedEnforceFlag {
        fn drop(&mut self) {
            match self.previous.take() {
                Some(prev) => std::env::set_var("EPISTEMOS_R5_ENFORCE", prev),
                None => std::env::remove_var("EPISTEMOS_R5_ENFORCE"),
            }
        }
    }

    fn vault_write_input(path: &str) -> serde_json::Value {
        serde_json::json!({
            "path": path,
            "content": "r5 gate test body",
            "skip_contradiction_check": true
        })
    }

    #[tokio::test]
    async fn r5_gate_allows_vault_write_when_escape_hatch_disables_enforce() {
        let _guard = r5_gate_test_lock();
        // EPISTEMOS_R5_ENFORCE=0 rolls the gate back to advisory mode.
        // Even with grants in the store pointing at OTHER resources,
        // this call — which has no matching grant — must succeed.
        let _env = ScopedEnforceFlag::set_off();

        // Seed an unrelated grant so active_grant_count > 0; advisory
        // mode must still allow regardless.
        let unrelated_uri = format!(
            "vault://r5-escape-{0}/note/Inbox/Unrelated-{0}.md",
            uuid::Uuid::new_v4()
        );
        let unrelated_grant =
            crate::resources::bridge::permission_store_record_user_grant_from_statement(
                "You have my permission to edit this note.".into(),
                unrelated_uri,
                vec!["Write".into()],
                "Session".into(),
            )
            .await
            .expect("seed grant for escape-hatch test");

        let vault_root = tempfile::tempdir().unwrap();
        let registry = build_registry_with_root(ToolTier::Agent, vault_root.path());
        let unique_path = format!("Inbox/R5Advisory-{}.md", uuid::Uuid::new_v4());
        let result = registry
            .execute("vault_write", &vault_write_input(&unique_path))
            .await
            .expect("advisory-mode gate must not block vault_write");
        let parsed: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["path"], serde_json::json!(unique_path));

        let _ = crate::resources::bridge::permission_store_revoke(unrelated_grant).await;
    }

    #[tokio::test]
    async fn r5_gate_denies_vault_write_by_default_when_grants_exist_but_not_for_this_resource() {
        let _guard = r5_gate_test_lock();
        // Critical test: prove default-on enforcement. No env var
        // set — the new default (`r5_enforce_enabled() == true`) must
        // kick in so an un-granted vault_write against a target that
        // doesn't match any stored grant is rejected. Pre-flip this
        // would have been advisory-allow; the whole point of flipping
        // is that the user-visible "permission evaporates as chat
        // text" symptom stops reproducing in production.
        let _env = ScopedEnforceFlag::clear();

        // Seed ANY grant to prove that a grant for another target is
        // not enough. The test call below targets a different resource,
        // so enforcement must DENY without any env flag being set.
        let unrelated_uri = format!(
            "vault://r5-default-{0}/note/Inbox/Unrelated-{0}.md",
            uuid::Uuid::new_v4()
        );
        let unrelated_grant =
            crate::resources::bridge::permission_store_record_user_grant_from_statement(
                "You have my permission to edit this note.".into(),
                unrelated_uri,
                vec!["Write".into()],
                "Session".into(),
            )
            .await
            .expect("seed grant for default-enforce test");

        let vault_dir_name = format!("r5-default-{}", uuid::Uuid::new_v4());
        let parent = tempfile::tempdir().unwrap();
        let vault_root = parent.path().join(&vault_dir_name);
        std::fs::create_dir_all(&vault_root).unwrap();
        let relative_path = format!("Inbox/Target-{}.md", uuid::Uuid::new_v4());

        let registry = build_registry_with_root(ToolTier::Agent, &vault_root);
        let result = registry
            .execute("vault_write", &vault_write_input(&relative_path))
            .await;
        match result {
            Err(ToolError::PermissionDenied) => {}
            Err(other) => panic!("expected PermissionDenied, got {other:?}"),
            Ok(payload) => panic!(
                "expected PermissionDenied under default-on enforcement, got success: {payload}"
            ),
        }

        let _ = crate::resources::bridge::permission_store_revoke(unrelated_grant).await;
    }

    #[tokio::test]
    async fn r5_gate_denies_note_template_without_matching_grant() {
        let _guard = r5_gate_test_lock();
        let _env = ScopedEnforceFlag::set_on();

        let unrelated_uri = format!(
            "vault://r5-note-template-{0}/note/Inbox/Unrelated-{0}.md",
            uuid::Uuid::new_v4()
        );
        let unrelated_grant =
            crate::resources::bridge::permission_store_record_user_grant_from_statement(
                "You have my permission to edit this note.".into(),
                unrelated_uri,
                vec!["Write".into()],
                "Session".into(),
            )
            .await
            .expect("seed grant for note_template denial test");

        let vault_dir_name = format!("r5-note-template-{}", uuid::Uuid::new_v4());
        let parent = tempfile::tempdir().unwrap();
        let vault_root = parent.path().join(&vault_dir_name);
        std::fs::create_dir_all(&vault_root).unwrap();

        let registry = build_registry_with_root(ToolTier::Agent, &vault_root);
        let result = registry
            .execute(
                "note_template",
                &serde_json::json!({
                    "template": "# {{title}}",
                    "output_path": "Inbox/Blocked.md",
                    "variables": { "title": "Blocked" }
                }),
            )
            .await;
        match result {
            Err(ToolError::PermissionDenied) => {}
            Err(other) => panic!("expected PermissionDenied, got {other:?}"),
            Ok(payload) => panic!("expected PermissionDenied, got success payload: {payload}"),
        }

        let _ = crate::resources::bridge::permission_store_revoke(unrelated_grant).await;
    }

    #[tokio::test]
    async fn r5_gate_allows_vault_write_when_explicit_grant_covers_resource() {
        let _guard = r5_gate_test_lock();
        let _env = ScopedEnforceFlag::set_on();

        let vault_dir_name = format!("r5-allow-{}", uuid::Uuid::new_v4());
        let parent = tempfile::tempdir().unwrap();
        let vault_root = parent.path().join(&vault_dir_name);
        std::fs::create_dir_all(&vault_root).unwrap();
        let relative_path = format!("Inbox/Granted-{}.md", uuid::Uuid::new_v4());
        let uri = format!("vault://{vault_dir_name}/note/{relative_path}");

        // Seed the permission store with a Write grant for this
        // exact resource so the enforcement branch should ALLOW.
        let grant_id = crate::resources::bridge::permission_store_record_user_grant_from_statement(
            "You have my permission to edit this note.".into(),
            uri.clone(),
            vec!["Write".into()],
            "Session".into(),
        )
        .await
        .expect("grant must be recorded for the happy-path test");

        let registry = build_registry_with_root(ToolTier::Agent, &vault_root);
        let result = registry
            .execute("vault_write", &vault_write_input(&relative_path))
            .await
            .expect("granted resource must pass the R.5 gate");
        let parsed: serde_json::Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["path"], serde_json::json!(relative_path));

        // Housekeeping: remove the grant so subsequent tests see a
        // smaller `active_grant_count`.
        let _ = crate::resources::bridge::permission_store_revoke(grant_id).await;
    }

    #[tokio::test]
    async fn r5_gate_denies_vault_write_when_grants_exist_but_not_for_this_resource() {
        let _guard = r5_gate_test_lock();
        let _env = ScopedEnforceFlag::set_on();

        // Seed ANY grant; the call below targets a DIFFERENT resource,
        // so enforcement must DENY.
        let unrelated_uri = format!(
            "vault://r5-unrelated-{0}/note/Inbox/Unrelated-{0}.md",
            uuid::Uuid::new_v4()
        );
        let unrelated_grant =
            crate::resources::bridge::permission_store_record_user_grant_from_statement(
                "You have my permission to edit this note.".into(),
                unrelated_uri,
                vec!["Write".into()],
                "Session".into(),
            )
            .await
            .expect("seed grant for the enforcement test");

        let vault_dir_name = format!("r5-deny-{}", uuid::Uuid::new_v4());
        let parent = tempfile::tempdir().unwrap();
        let vault_root = parent.path().join(&vault_dir_name);
        std::fs::create_dir_all(&vault_root).unwrap();
        let relative_path = format!("Inbox/Target-{}.md", uuid::Uuid::new_v4());

        let registry = build_registry_with_root(ToolTier::Agent, &vault_root);
        let result = registry
            .execute("vault_write", &vault_write_input(&relative_path))
            .await;
        match result {
            Err(ToolError::PermissionDenied) => {}
            Err(other) => panic!("expected PermissionDenied, got {other:?}"),
            Ok(payload) => panic!("expected PermissionDenied, got success payload: {payload}"),
        }

        let _ = crate::resources::bridge::permission_store_revoke(unrelated_grant).await;
    }

    #[tokio::test]
    async fn r5_gate_skips_read_only_vault_read_even_when_enforce_flag_is_on() {
        let _guard = r5_gate_test_lock();
        let _env = ScopedEnforceFlag::set_on();

        // vault_read has RiskLevel::ReadOnly — the gate must short-
        // circuit to None before consulting the store. Even with a
        // store full of grants that don't cover this resource, the
        // read call must succeed.
        let vault_root = tempfile::tempdir().unwrap();
        let registry = build_registry_with_root(ToolTier::Agent, vault_root.path());
        let result = registry
            .execute(
                "vault_read",
                &serde_json::json!({"path": "Inbox/ReadBypass.md"}),
            )
            .await;
        assert!(
            result.is_ok(),
            "read-only tools must bypass the R.5 write gate: {result:?}"
        );
    }
}
