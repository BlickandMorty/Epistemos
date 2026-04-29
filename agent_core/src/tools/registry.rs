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
        vec![
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
            LegacyToolAdapter::boxed(
                v2_catalog::chunk_reduce::SPEC,
                Arc::new(super::chunk_reduce::ChunkReduceHandler),
            ),
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
        // Phase 2F-2 audit: factory produces a Vec<Box<dyn Tool>> whose
        // entries carry dotted names + compiling input schemas. This is
        // the integration check that pairs the v2_catalog static SPEC
        // tests with real handler instances driven by a stub vault.
        let registry = build_registry(ToolTier::Full);
        let catalog = registry.build_v2_catalog();
        assert_eq!(catalog.len(), 11, "2F-4 ships 11 adapted tools");

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
