//! Agent Command Center Request Compiler — Rust authority per PLAN_V2 §3.1
//! and §4.1 (the command center is a delegation surface, not a second control
//! plane; Rust owns routing, policy, permissions, and runtime truth).
//!
//! This module is the canonical home for Command Center request compilation.
//! Swift supplies parsed/explicit-toggle user intent plus pre-resolved
//! mention bodies (vault title lookup still lives in Swift because
//! `VaultSyncService` holds the indices); this module owns:
//!
//! - **tool catalog truth** — derived from the Rust `ToolRegistry` itself,
//!   not from a Swift-supplied mirror. Swift never tells Rust what tools
//!   exist; it only tells Rust which tools the user toggled on.
//! - runtime resolution (explicit brain vs. auto vs. unavailable truth — an
//!   explicit unavailable brain never silently reroutes)
//! - tool permission decision against the Rust-owned catalog + explicit
//!   user toggles
//! - execution policy / budgets / route / expert allowlist / summary
//! - notes-context block assembly from the pre-resolved mentions
//!
//! The FFI entry point is a JSON-in / JSON-out function declared in
//! `bridge.rs`. JSON round-tripping preserves the Swift
//! `CompiledCommandCenterRequest` Codable contract without requiring every
//! associated-value enum to be mirrored through a UniFFI dictionary. The
//! existing Swift Codable parity tests remain the golden test set for this
//! contract.

use chrono::{DateTime, SecondsFormat, Utc};
use serde::{Deserialize, Serialize};

pub const CONTRACT_VERSION: &str = "v1";
const NOTES_CONTEXT_BODY_CAP: usize = 6_000;

// ===== Input shape (Swift → Rust) =====

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CompileCommandCenterInput {
    pub query: String,
    #[serde(default)]
    pub conversation_history: Option<String>,
    pub operating_mode: OperatingMode,
    #[serde(default)]
    pub slash_token: Option<SerializedSlashToken>,
    #[serde(default)]
    pub brain_override: Option<SerializedBrainSelection>,
    /// User intent: which tools the user toggled on in the Agent Command
    /// Center UI. Rust intersects this against the Rust-owned tool catalog
    /// at the operating-mode-derived tier to decide allow/deny.
    #[serde(default)]
    pub enabled_tool_names: Vec<String>,
    #[serde(default)]
    pub requested_mentions: Vec<SerializedMention>,
    /// Pre-resolved mention bodies. Swift resolves vault titles because
    /// `VaultSyncService` holds the indices today; Rust consumes the
    /// already-resolved refs and takes it from there.
    #[serde(default)]
    pub resolved_mentions: Vec<ResolvedContextRef>,
    #[serde(default)]
    pub available_brains: Vec<SerializedBrainSelection>,
    #[serde(default)]
    pub preferred_auto_brain: Option<SerializedBrainSelection>,
    /// Vault path the Rust side uses to construct a `ToolRegistry` so it
    /// can derive the canonical tool catalog for the current operating
    /// mode. Swift never supplies the catalog itself — only the path to
    /// the vault. An empty string is treated as "no vault available" and
    /// yields an empty catalog (every tool denied with a truthful reason).
    #[serde(default)]
    pub vault_path: String,
    /// Graph context attached when the request originated from a
    /// graph-workspace "Ask Graph Chat" action. Carries the fields
    /// required by PLAN_V2 §4.1: graph node id, backing source id,
    /// node type, node label, and current graph route. `None` when
    /// the request did not originate from the graph workspace.
    #[serde(default)]
    pub graph_context: Option<GraphContext>,
}

/// Graph-originated request context per PLAN_V2 §4.1. Attached to the
/// compile input when the user invokes "Ask Graph Chat" from a graph
/// node's context menu.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GraphContext {
    pub graph_node_id: String,
    #[serde(default)]
    pub source_id: Option<String>,
    pub node_type: String,
    pub node_label: String,
    pub graph_route: String,
}

/// Tool catalog entry derived from `ToolRegistry` at the operating-mode
/// tier. Held in-memory only; not part of the FFI input envelope.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ToolCatalogEntry {
    pub name: String,
    pub agent: String,
    pub description: String,
    pub requires_confirmation: bool,
    pub destructive: bool,
}

// ===== Output shape — Swift `CompiledCommandCenterRequest` mirror =====

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CompiledCommandCenterRequest {
    pub contract_version: String,
    #[serde(serialize_with = "serialize_iso8601")]
    pub compiled_at: DateTime<Utc>,
    pub query: String,
    pub conversation_history: Option<String>,
    pub requested_slash_token: Option<SerializedSlashToken>,
    pub requested_operating_mode: OperatingMode,
    pub requested_brain: Option<SerializedBrainSelection>,
    /// Sorted for deterministic JSON output.
    pub requested_tool_names: Vec<String>,
    pub requested_mentions: Vec<SerializedMention>,
    pub resolved_runtime: ResolvedRuntime,
    pub resolved_tool_permissions: Vec<ResolvedToolPermission>,
    pub resolved_context_refs: Vec<ResolvedContextRef>,
    pub resolved_execution_policy: ResolvedExecutionPolicy,
    pub notes_context: Option<String>,
    /// Passed through from the input when the request originated from the
    /// graph workspace. Downstream execution and the inspector can use
    /// this to surface graph provenance without re-querying the graph store.
    pub graph_context: Option<GraphContext>,
}

fn serialize_iso8601<S: serde::Serializer>(dt: &DateTime<Utc>, s: S) -> Result<S::Ok, S::Error> {
    // Swift `JSONDecoder` with `.iso8601` strategy uses `ISO8601DateFormatter`
    // in its default mode which rejects fractional seconds. Emit seconds
    // precision with a trailing Z so Swift can decode without churn.
    s.serialize_str(&dt.to_rfc3339_opts(SecondsFormat::Secs, true))
}

// ===== Shared serializable mirrors =====

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum OperatingMode {
    Fast,
    Thinking,
    Pro,
    Agent,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SerializedSlashToken {
    pub kind: SlashTokenKind,
    pub identifier: String,
    pub display_name: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum SlashTokenKind {
    BuiltinMode,
    Skill,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SerializedBrainSelection {
    pub kind: BrainKind,
    pub identifier: String,
    pub display_name: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum BrainKind {
    Local,
    AppleIntelligence,
    Cloud,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SerializedMention {
    pub id: String,
    pub token: String,
    pub resolved_label: String,
    pub mention_type: String,
}

// ===== Output sub-structures =====

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ResolvedRuntime {
    pub requested: Option<SerializedBrainSelection>,
    pub resolved: ResolvedBrainDescriptor,
    pub fallback_reason: Option<String>,
}

// Swift `Codable` synthesis wraps every enum case — including ones with no
// associated values — in a dictionary whose single key is the case name and
// whose value is an empty object. Serde's default for a Rust unit variant
// emits just the case name as a string, which Swift cannot decode. Every
// empty case on the wire side must therefore be modelled as an empty
// struct variant so serde emits `{"appleIntelligence": {}}` instead of
// `"appleIntelligence"`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum ResolvedBrainDescriptor {
    #[serde(rename = "local", rename_all = "camelCase")]
    Local {
        model_id: String,
        display_name: String,
    },
    #[serde(rename = "appleIntelligence")]
    AppleIntelligence {},
    #[serde(rename = "cloud", rename_all = "camelCase")]
    Cloud {
        provider: String,
        display_name: String,
    },
    #[serde(rename = "unavailable", rename_all = "camelCase")]
    Unavailable { reason: String },
}

impl ResolvedBrainDescriptor {
    pub fn category(&self) -> &'static str {
        match self {
            ResolvedBrainDescriptor::Local { .. } => "local",
            ResolvedBrainDescriptor::AppleIntelligence {} => "apple_intelligence",
            ResolvedBrainDescriptor::Cloud { .. } => "cloud",
            ResolvedBrainDescriptor::Unavailable { .. } => "unavailable",
        }
    }

    fn from_selection(sel: &SerializedBrainSelection) -> Self {
        match sel.kind {
            BrainKind::Local => ResolvedBrainDescriptor::Local {
                model_id: sel.identifier.clone(),
                display_name: sel.display_name.clone(),
            },
            BrainKind::AppleIntelligence => ResolvedBrainDescriptor::AppleIntelligence {},
            BrainKind::Cloud => ResolvedBrainDescriptor::Cloud {
                provider: sel.identifier.clone(),
                display_name: sel.display_name.clone(),
            },
        }
    }
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ResolvedToolPermission {
    pub tool_name: String,
    pub agent: String,
    pub description: String,
    pub decision: ToolDecision,
    pub requires_confirmation: bool,
    pub destructive: bool,
}

#[derive(Debug, Clone, Serialize)]
pub enum ToolDecision {
    // Empty struct variant so serde emits `{"allow": {}}` — matches Swift's
    // Codable synthesis for an enum case with no associated values.
    #[serde(rename = "allow")]
    Allow {},
    #[serde(rename = "deny", rename_all = "camelCase")]
    Deny { reason: String },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ResolvedContextRef {
    #[serde(rename = "note", rename_all = "camelCase")]
    Note {
        id: String,
        title: String,
        preview: String,
        #[serde(default)]
        body: Option<String>,
        approx_tokens: i64,
    },
    #[serde(rename = "agentTarget", rename_all = "camelCase")]
    AgentTarget { agent_id: String, label: String },
    #[serde(rename = "vaultScope", rename_all = "camelCase")]
    VaultScope { scope: VaultScope, label: String },
    #[serde(rename = "graphScope", rename_all = "camelCase")]
    GraphScope { label: String },
    #[serde(rename = "folderScope", rename_all = "camelCase")]
    FolderScope { folder_name: String, label: String },
    #[serde(rename = "skillTarget", rename_all = "camelCase")]
    SkillTarget { skill_id: String, label: String },
    #[serde(rename = "unresolved", rename_all = "camelCase")]
    Unresolved { token: String, reason: String },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum VaultScope {
    AllNotes,
    CurrentVault,
    CurrentGraph,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ResolvedExecutionPolicy {
    pub requested_operating_mode: OperatingMode,
    pub effective_operating_mode: OperatingMode,
    pub route: String,
    pub max_turns: i64,
    pub max_reasoning_steps: i64,
    pub max_tool_calls: i64,
    pub max_output_tokens: i64,
    pub expert_allowlist: Vec<String>,
    pub summary: String,
}

// ===== Entry point =====

/// Map an `OperatingMode` to the canonical tool tier string. This mapping
/// is Rust-owned — Swift never picks the tier directly, it only sends the
/// user's operating-mode intent and Rust decides which tier to query.
pub fn tier_for_operating_mode(mode: OperatingMode) -> &'static str {
    match mode {
        OperatingMode::Fast | OperatingMode::Thinking => "chat_lite",
        OperatingMode::Pro => "chat_pro",
        OperatingMode::Agent => "agent",
    }
}

/// Pure compilation step: takes a parsed input plus the Rust-derived tool
/// catalog and returns a normalized request. Split out from
/// `compile_from_json` so unit tests can exercise the compilation logic
/// without paying the cost of building a real `ToolRegistry`.
pub fn compile_with_catalog(
    input: CompileCommandCenterInput,
    catalog: Vec<ToolCatalogEntry>,
) -> CompiledCommandCenterRequest {
    let compiled_at = Utc::now();

    let notes_context = build_notes_context_block(&input.resolved_mentions);

    let resolved_runtime = resolve_runtime(
        input.brain_override.as_ref(),
        &input.available_brains,
        input.preferred_auto_brain.as_ref(),
    );

    let enabled_set: std::collections::BTreeSet<&str> = input
        .enabled_tool_names
        .iter()
        .map(String::as_str)
        .collect();
    let resolved_tool_permissions = resolve_tool_permissions(&enabled_set, &catalog);

    let resolved_policy = build_execution_policy(
        input.operating_mode,
        &resolved_runtime,
        input.slash_token.as_ref(),
        input.enabled_tool_names.is_empty(),
        input.resolved_mentions.len(),
        notes_context.is_some(),
    );

    // Canonicalize requested_tool_names as a sorted unique vec for
    // deterministic output — Swift's `Set<String>` has no ordering.
    let mut sorted_tool_names: Vec<String> = enabled_set.iter().map(|s| s.to_string()).collect();
    sorted_tool_names.sort();

    CompiledCommandCenterRequest {
        contract_version: CONTRACT_VERSION.to_string(),
        compiled_at,
        query: input.query,
        conversation_history: input.conversation_history,
        requested_slash_token: input.slash_token,
        requested_operating_mode: input.operating_mode,
        requested_brain: input.brain_override,
        requested_tool_names: sorted_tool_names,
        requested_mentions: input.requested_mentions,
        resolved_runtime,
        resolved_tool_permissions,
        resolved_context_refs: input.resolved_mentions,
        resolved_execution_policy: resolved_policy,
        notes_context,
        graph_context: input.graph_context,
    }
}

/// JSON-in / JSON-out entry point callable from the FFI layer. Returns a
/// result string; on parse failure, returns a structured error envelope so
/// Swift can surface it without panicking through UniFFI.
///
/// Rust derives the tool catalog from its own `ToolRegistry` at the tier
/// implied by the request's operating mode. Swift never supplies the
/// catalog — it only sends user intent. When `vault_path` is empty or the
/// vault cannot be opened, the catalog is empty and every tool the user
/// toggled on gets an explicit `vault_unavailable` deny reason (no fake
/// successes).
pub fn compile_from_json(input_json: &str) -> Result<String, String> {
    let input: CompileCommandCenterInput = serde_json::from_str(input_json)
        .map_err(|e| format!("compile_command_center_request: invalid input JSON: {e}"))?;

    let tier = tier_for_operating_mode(input.operating_mode);
    let catalog = build_catalog_for_tier(&input.vault_path, tier);

    let compiled = compile_with_catalog(input, catalog);
    serde_json::to_string(&compiled)
        .map_err(|e| format!("compile_command_center_request: serialize output: {e}"))
}

/// Construct a Rust `ToolRegistry` at the requested tier and project the
/// permitted tools down to `ToolCatalogEntry` values. Failures (empty
/// vault path, vault open error) return an empty catalog — the caller
/// then denies every user-enabled tool with a truthful reason, which is
/// the canonical fail-closed behavior per PLAN_V2 §3.4.
fn build_catalog_for_tier(vault_path: &str, tier: &str) -> Vec<ToolCatalogEntry> {
    if vault_path.is_empty() {
        return Vec::new();
    }
    let Ok(vault) = crate::storage::vault::VaultStore::open(vault_path) else {
        return Vec::new();
    };
    let tier_enum = crate::tools::registry::ToolTier::from_str_lossy(tier);
    let registry = crate::tools::registry::ToolRegistry::with_tier(
        std::sync::Arc::new(vault),
        true,
        Some(std::path::PathBuf::from(vault_path)),
        tier_enum,
    );
    registry
        .get_definitions()
        .into_iter()
        .filter(|schema| crate::tools::registry::is_user_visible_tool(&schema.name))
        .map(|schema| {
            let risk = registry.get_risk_level(&schema.name);
            let destructive = matches!(risk, crate::tools::registry::RiskLevel::Destructive);
            let requires_confirmation =
                destructive || matches!(risk, crate::tools::registry::RiskLevel::Modification);
            ToolCatalogEntry {
                name: schema.name,
                // Display-only categorization. The Command Center inspector
                // used to receive a Swift-maintained "agent" string from
                // `OmegaToolRegistry.all`; that JSON mirror is now retired
                // and Rust is the sole source of truth. Every Rust-registered
                // tool reports `"rust"` here — the inspector can enrich this
                // at display time if it wants finer-grained categorization.
                agent: "rust".to_string(),
                description: schema.description,
                requires_confirmation,
                destructive,
            }
        })
        .collect()
}

// ===== Resolution logic =====

fn resolve_runtime(
    requested: Option<&SerializedBrainSelection>,
    available: &[SerializedBrainSelection],
    preferred_auto: Option<&SerializedBrainSelection>,
) -> ResolvedRuntime {
    // Auto-route — no explicit brain picked.
    let Some(requested) = requested else {
        if let Some(preferred) = preferred_auto {
            if available.iter().any(|b| b == preferred) {
                return ResolvedRuntime {
                    requested: None,
                    resolved: ResolvedBrainDescriptor::from_selection(preferred),
                    fallback_reason: None,
                };
            }
        }
        if let Some(first) = available.first() {
            return ResolvedRuntime {
                requested: None,
                resolved: ResolvedBrainDescriptor::from_selection(first),
                fallback_reason: None,
            };
        }
        return ResolvedRuntime {
            requested: None,
            resolved: ResolvedBrainDescriptor::Unavailable {
                reason: "no_brains_available".to_string(),
            },
            fallback_reason: Some("no_brains_available".to_string()),
        };
    };

    // Explicit request — resolve strictly. Unavailable must surface truth,
    // never silently reroute (PLAN_V2 §3.4 + Phase 6 non-negotiable).
    if available.iter().any(|b| b == requested) {
        ResolvedRuntime {
            requested: Some(requested.clone()),
            resolved: ResolvedBrainDescriptor::from_selection(requested),
            fallback_reason: None,
        }
    } else {
        ResolvedRuntime {
            requested: Some(requested.clone()),
            resolved: ResolvedBrainDescriptor::Unavailable {
                reason: "requested_brain_unavailable".to_string(),
            },
            fallback_reason: Some("requested_brain_unavailable".to_string()),
        }
    }
}

fn resolve_tool_permissions(
    enabled: &std::collections::BTreeSet<&str>,
    catalog: &[ToolCatalogEntry],
) -> Vec<ResolvedToolPermission> {
    // Walk the Rust-owned catalog and decide allow/deny for every tool at
    // the current tier. Tools the user toggled on that are not in the
    // Rust catalog get synthesized deny entries with a truthful reason —
    // this surfaces an empty-catalog state (e.g. vault unavailable) or a
    // stale Swift UI toggle without silently dropping either side.
    let catalog_names: std::collections::BTreeSet<&str> =
        catalog.iter().map(|t| t.name.as_str()).collect();

    let mut out: Vec<ResolvedToolPermission> = catalog
        .iter()
        .map(|tool| {
            let decision = if enabled.contains(tool.name.as_str()) {
                ToolDecision::Allow {}
            } else {
                ToolDecision::Deny {
                    reason: "not_enabled_by_user".to_string(),
                }
            };
            ResolvedToolPermission {
                tool_name: tool.name.clone(),
                agent: tool.agent.clone(),
                description: tool.description.clone(),
                decision,
                requires_confirmation: tool.requires_confirmation,
                destructive: tool.destructive,
            }
        })
        .collect();

    // Surface user-enabled tool names that the Rust catalog does not
    // contain at this tier. Two realistic causes: (1) an empty catalog
    // because the vault failed to open, (2) a stale Swift UI toggle
    // pointing at a tool the Rust registry no longer exposes.
    let deny_reason = if catalog.is_empty() {
        "tool_catalog_unavailable"
    } else {
        "not_in_rust_catalog"
    };
    for name in enabled {
        if !catalog_names.contains(name) {
            out.push(ResolvedToolPermission {
                tool_name: name.to_string(),
                agent: "rust".to_string(),
                description: String::new(),
                decision: ToolDecision::Deny {
                    reason: deny_reason.to_string(),
                },
                requires_confirmation: false,
                destructive: false,
            });
        }
    }

    out
}

fn build_execution_policy(
    operating_mode: OperatingMode,
    resolved_runtime: &ResolvedRuntime,
    slash_token: Option<&SerializedSlashToken>,
    enabled_tools_empty: bool,
    explicit_context_count: usize,
    has_notes_context: bool,
) -> ResolvedExecutionPolicy {
    let route = match operating_mode {
        OperatingMode::Fast | OperatingMode::Thinking => "local_only".to_string(),
        OperatingMode::Pro => "overseer_local_execution".to_string(),
        OperatingMode::Agent => {
            if matches!(
                resolved_runtime.resolved,
                ResolvedBrainDescriptor::Cloud { .. }
            ) {
                "managed_agent_session".to_string()
            } else if enabled_tools_empty {
                "local_only".to_string()
            } else {
                "overseer_local_execution".to_string()
            }
        }
    };

    let (max_turns, max_reasoning, max_tools, max_output) = match operating_mode {
        OperatingMode::Fast => (1, 0, 0, 4_096),
        OperatingMode::Thinking => (1, 8, 0, 8_192),
        OperatingMode::Pro => (3, 12, 8, 16_384),
        OperatingMode::Agent => (8, 24, 32, 32_768),
    };

    let experts = match slash_token {
        Some(token) if token.kind == SlashTokenKind::BuiltinMode => match token.identifier.as_str()
        {
            "code" => vec![
                "coding".to_string(),
                "implementation".to_string(),
                "refactoring".to_string(),
                "tool-use".to_string(),
            ],
            "debug" => vec![
                "debugging".to_string(),
                "code-analysis".to_string(),
                "error-diagnosis".to_string(),
            ],
            "research" => vec![
                "research".to_string(),
                "web-search".to_string(),
                "summarization".to_string(),
            ],
            "review" => vec![
                "code-review".to_string(),
                "critique".to_string(),
                "analysis".to_string(),
            ],
            "security-review" => vec![
                "security-review".to_string(),
                "threat-modeling".to_string(),
                "vulnerability-analysis".to_string(),
            ],
            "summarize" => vec!["summarization".to_string(), "distillation".to_string()],
            "explain" => vec![
                "teaching".to_string(),
                "explanation".to_string(),
                "simplification".to_string(),
            ],
            _ => vec!["general".to_string()],
        },
        Some(token) if token.kind == SlashTokenKind::Skill => vec![token.identifier.clone()],
        _ => {
            if operating_mode == OperatingMode::Agent {
                vec!["general".to_string(), "agent".to_string()]
            } else {
                vec!["general".to_string()]
            }
        }
    };

    let summary_base = match slash_token {
        Some(token) if token.kind == SlashTokenKind::BuiltinMode => format!(
            "Command Center: /{} — {}",
            token.identifier,
            builtin_help_text(&token.identifier)
        ),
        Some(token) if token.kind == SlashTokenKind::Skill => format!(
            "Command Center: skill {} — {}",
            token.identifier, token.display_name
        ),
        _ => match operating_mode {
            OperatingMode::Fast => "Command Center: fast mode".to_string(),
            OperatingMode::Thinking => "Command Center: thinking mode".to_string(),
            OperatingMode::Pro => "Command Center: pro mode".to_string(),
            OperatingMode::Agent => "Command Center: agent mode".to_string(),
        },
    };

    let summary = if explicit_context_count > 0 || has_notes_context {
        format!("{summary_base} with {explicit_context_count} explicit context attachment(s)")
    } else {
        summary_base
    };

    ResolvedExecutionPolicy {
        requested_operating_mode: operating_mode,
        effective_operating_mode: operating_mode,
        route,
        max_turns,
        max_reasoning_steps: max_reasoning,
        max_tool_calls: max_tools,
        max_output_tokens: max_output,
        expert_allowlist: experts,
        summary,
    }
}

/// Mirrors Swift `ACCSlashCommand.helpText` for the 5 built-in modes the
/// execution policy summary uses. Kept as a static map because the Swift
/// type is not Codable and the help strings are stable.
fn builtin_help_text(identifier: &str) -> &'static str {
    match identifier {
        "debug" => "find and fix issues in the attached context",
        "research" => "gather and synthesize external context",
        "review" => "critique the attached work for correctness and quality",
        "security-review" => "audit the attached code and config for vulnerabilities",
        "summarize" => "distill the attached context into a short summary",
        "explain" => "walk through the attached context in plain terms",
        "ask" => "ask a question against the attached context",
        "plan" => "build a step-by-step plan for the task",
        "code" => "write or modify code with tools and file context",
        _ => "command center mode",
    }
}

fn build_notes_context_block(refs: &[ResolvedContextRef]) -> Option<String> {
    let note_refs: Vec<(&str, &str)> = refs
        .iter()
        .filter_map(|r| match r {
            ResolvedContextRef::Note {
                title,
                body: Some(body),
                ..
            } => Some((title.as_str(), body.as_str())),
            _ => None,
        })
        .collect();

    if note_refs.is_empty() {
        return None;
    }

    let mut lines: Vec<String> = Vec::with_capacity(2 + note_refs.len() * 2);
    lines.push("## Requested Note Context".to_string());
    lines.push(
        "The user explicitly attached these notes via @mention. Prefer them when answering."
            .to_string(),
    );
    for (title, body) in note_refs {
        lines.push(format!("### {title}"));
        if body.chars().count() > NOTES_CONTEXT_BODY_CAP {
            let truncated: String = body.chars().take(NOTES_CONTEXT_BODY_CAP).collect();
            lines.push(format!("{truncated}…"));
        } else {
            lines.push(body.to_string());
        }
    }
    Some(lines.join("\n"))
}

// ===== Tests =====

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn local_brain(id: &str, name: &str) -> SerializedBrainSelection {
        SerializedBrainSelection {
            kind: BrainKind::Local,
            identifier: id.to_string(),
            display_name: name.to_string(),
        }
    }

    fn cloud_brain(provider: &str) -> SerializedBrainSelection {
        SerializedBrainSelection {
            kind: BrainKind::Cloud,
            identifier: provider.to_string(),
            display_name: provider.to_string(),
        }
    }

    fn sample_tool(name: &str, destructive: bool) -> ToolCatalogEntry {
        ToolCatalogEntry {
            name: name.to_string(),
            agent: "cloud".to_string(),
            description: format!("{name} tool"),
            requires_confirmation: destructive,
            destructive,
        }
    }

    #[test]
    fn auto_route_prefers_preferred_auto_brain_when_available() {
        let available = vec![local_brain("qwen", "Qwen"), cloud_brain("claude")];
        let preferred = local_brain("qwen", "Qwen");
        let runtime = resolve_runtime(None, &available, Some(&preferred));
        assert_eq!(runtime.requested, None);
        assert!(runtime.fallback_reason.is_none());
        match runtime.resolved {
            ResolvedBrainDescriptor::Local { model_id, .. } => assert_eq!(model_id, "qwen"),
            other => panic!("expected local qwen, got {other:?}"),
        }
    }

    #[test]
    fn auto_route_falls_through_to_first_available_when_preferred_missing() {
        let available = vec![cloud_brain("claude")];
        let preferred = local_brain("qwen", "Qwen");
        let runtime = resolve_runtime(None, &available, Some(&preferred));
        assert!(matches!(
            runtime.resolved,
            ResolvedBrainDescriptor::Cloud { .. }
        ));
    }

    #[test]
    fn auto_route_with_no_brains_is_unavailable() {
        let runtime = resolve_runtime(None, &[], None);
        assert!(matches!(
            runtime.resolved,
            ResolvedBrainDescriptor::Unavailable { .. }
        ));
        assert_eq!(
            runtime.fallback_reason.as_deref(),
            Some("no_brains_available")
        );
    }

    #[test]
    fn explicit_brain_never_silently_reroutes_when_unavailable() {
        let requested = local_brain("qwen", "Qwen");
        let available = vec![cloud_brain("claude")];
        let runtime = resolve_runtime(Some(&requested), &available, None);
        assert_eq!(runtime.requested.as_ref(), Some(&requested));
        assert!(matches!(
            runtime.resolved,
            ResolvedBrainDescriptor::Unavailable { .. }
        ));
        assert_eq!(
            runtime.fallback_reason.as_deref(),
            Some("requested_brain_unavailable")
        );
    }

    #[test]
    fn explicit_brain_resolves_to_itself_when_available() {
        let requested = local_brain("qwen", "Qwen");
        let available = vec![local_brain("qwen", "Qwen"), cloud_brain("claude")];
        let runtime = resolve_runtime(Some(&requested), &available, None);
        assert!(runtime.fallback_reason.is_none());
        match runtime.resolved {
            ResolvedBrainDescriptor::Local { model_id, .. } => assert_eq!(model_id, "qwen"),
            other => panic!("expected local qwen, got {other:?}"),
        }
    }

    #[test]
    fn tool_permissions_allow_only_user_enabled() {
        let catalog = vec![
            sample_tool("read_file", false),
            sample_tool("bash_command", true),
            sample_tool("memory_search", false),
        ];
        let enabled: std::collections::BTreeSet<&str> = ["bash_command"].iter().copied().collect();
        let perms = resolve_tool_permissions(&enabled, &catalog);
        assert_eq!(perms.len(), 3);
        let allow: Vec<&str> = perms
            .iter()
            .filter(|p| matches!(p.decision, ToolDecision::Allow { .. }))
            .map(|p| p.tool_name.as_str())
            .collect();
        assert_eq!(allow, vec!["bash_command"]);
    }

    #[test]
    fn empty_tool_toggles_deny_everything() {
        let catalog = vec![sample_tool("read_file", false), sample_tool("bash", true)];
        let perms = resolve_tool_permissions(&Default::default(), &catalog);
        assert!(perms
            .iter()
            .all(|p| matches!(p.decision, ToolDecision::Deny { .. })));
    }

    #[test]
    fn execution_policy_agent_with_cloud_routes_to_managed_agent_session() {
        let runtime = ResolvedRuntime {
            requested: None,
            resolved: ResolvedBrainDescriptor::Cloud {
                provider: "claude".to_string(),
                display_name: "Claude".to_string(),
            },
            fallback_reason: None,
        };
        let policy = build_execution_policy(OperatingMode::Agent, &runtime, None, false, 0, false);
        assert_eq!(policy.route, "managed_agent_session");
        assert_eq!(policy.max_turns, 8);
        assert_eq!(policy.max_tool_calls, 32);
        assert!(policy.expert_allowlist.contains(&"general".to_string()));
    }

    #[test]
    fn execution_policy_agent_with_local_and_no_tools_is_local_only() {
        let runtime = ResolvedRuntime {
            requested: None,
            resolved: ResolvedBrainDescriptor::Local {
                model_id: "qwen".to_string(),
                display_name: "Qwen".to_string(),
            },
            fallback_reason: None,
        };
        let policy = build_execution_policy(OperatingMode::Agent, &runtime, None, true, 0, false);
        assert_eq!(policy.route, "local_only");
    }

    #[test]
    fn execution_policy_fast_mode_routes_local() {
        let runtime = ResolvedRuntime {
            requested: None,
            resolved: ResolvedBrainDescriptor::AppleIntelligence {},
            fallback_reason: None,
        };
        let policy = build_execution_policy(OperatingMode::Fast, &runtime, None, true, 0, false);
        assert_eq!(policy.route, "local_only");
        assert_eq!(policy.max_turns, 1);
        assert_eq!(policy.max_reasoning_steps, 0);
    }

    #[test]
    fn execution_policy_slash_debug_sets_debugging_experts() {
        let runtime = ResolvedRuntime {
            requested: None,
            resolved: ResolvedBrainDescriptor::Local {
                model_id: "qwen".to_string(),
                display_name: "Qwen".to_string(),
            },
            fallback_reason: None,
        };
        let slash = SerializedSlashToken {
            kind: SlashTokenKind::BuiltinMode,
            identifier: "debug".to_string(),
            display_name: "Debug".to_string(),
        };
        let policy =
            build_execution_policy(OperatingMode::Pro, &runtime, Some(&slash), false, 0, false);
        assert!(policy.expert_allowlist.contains(&"debugging".to_string()));
        assert!(policy.summary.starts_with("Command Center: /debug"));
    }

    #[test]
    fn execution_policy_slash_code_sets_coding_experts() {
        let runtime = ResolvedRuntime {
            requested: None,
            resolved: ResolvedBrainDescriptor::Local {
                model_id: "qwen-coder".to_string(),
                display_name: "Qwen Coder".to_string(),
            },
            fallback_reason: None,
        };
        let slash = SerializedSlashToken {
            kind: SlashTokenKind::BuiltinMode,
            identifier: "code".to_string(),
            display_name: "Code".to_string(),
        };
        let policy =
            build_execution_policy(OperatingMode::Agent, &runtime, Some(&slash), false, 0, false);
        assert!(policy.expert_allowlist.contains(&"coding".to_string()));
        assert!(policy.expert_allowlist.contains(&"tool-use".to_string()));
        assert!(policy.summary.starts_with("Command Center: /code"));
    }

    #[test]
    fn execution_policy_security_review_sets_security_experts() {
        let runtime = ResolvedRuntime {
            requested: None,
            resolved: ResolvedBrainDescriptor::Cloud {
                provider: "openai".to_string(),
                display_name: "OpenAI".to_string(),
            },
            fallback_reason: None,
        };
        let slash = SerializedSlashToken {
            kind: SlashTokenKind::BuiltinMode,
            identifier: "security-review".to_string(),
            display_name: "Security Review".to_string(),
        };
        let policy =
            build_execution_policy(OperatingMode::Pro, &runtime, Some(&slash), false, 0, false);
        assert!(policy
            .expert_allowlist
            .contains(&"security-review".to_string()));
        assert!(policy
            .expert_allowlist
            .contains(&"vulnerability-analysis".to_string()));
        assert!(policy.summary.starts_with("Command Center: /security-review"));
    }

    #[test]
    fn execution_policy_skill_slash_token_uses_skill_identifier() {
        let runtime = ResolvedRuntime {
            requested: None,
            resolved: ResolvedBrainDescriptor::AppleIntelligence {},
            fallback_reason: None,
        };
        let slash = SerializedSlashToken {
            kind: SlashTokenKind::Skill,
            identifier: "research-dive".to_string(),
            display_name: "Research Dive".to_string(),
        };
        let policy = build_execution_policy(
            OperatingMode::Agent,
            &runtime,
            Some(&slash),
            false,
            0,
            false,
        );
        assert_eq!(policy.expert_allowlist, vec!["research-dive".to_string()]);
        assert!(policy.summary.contains("skill research-dive"));
    }

    #[test]
    fn notes_context_block_caps_long_bodies() {
        let long_body = "x".repeat(NOTES_CONTEXT_BODY_CAP + 10);
        let refs = vec![ResolvedContextRef::Note {
            id: "p1".to_string(),
            title: "Long Note".to_string(),
            preview: "p".to_string(),
            body: Some(long_body),
            approx_tokens: 100,
        }];
        let block = build_notes_context_block(&refs).expect("block");
        assert!(block.contains("## Requested Note Context"));
        assert!(block.contains("### Long Note"));
        assert!(block.ends_with("…"));
    }

    #[test]
    fn notes_context_block_none_when_no_notes_with_body() {
        let refs = vec![
            ResolvedContextRef::VaultScope {
                scope: VaultScope::CurrentVault,
                label: "vault".to_string(),
            },
            ResolvedContextRef::Note {
                id: "p1".to_string(),
                title: "T".to_string(),
                preview: "p".to_string(),
                body: None,
                approx_tokens: 10,
            },
        ];
        assert!(build_notes_context_block(&refs).is_none());
    }

    /// Exercises the pure `compile_with_catalog` path — the compilation
    /// logic under a Rust-supplied catalog (the real production path
    /// derives this catalog from `ToolRegistry` via `build_catalog_for_tier`,
    /// which needs a real vault and is exercised separately in
    /// `build_catalog_for_tier_empty_vault_path_yields_empty_catalog`).
    #[test]
    fn compile_with_catalog_produces_stable_contract() {
        let input = CompileCommandCenterInput {
            query: "explain the vault bootstrap".to_string(),
            conversation_history: None,
            operating_mode: OperatingMode::Pro,
            slash_token: None,
            brain_override: Some(local_brain("qwen", "Qwen")),
            enabled_tool_names: vec!["read_file".to_string(), "memory_search".to_string()],
            requested_mentions: vec![],
            resolved_mentions: vec![ResolvedContextRef::Note {
                id: "p1".to_string(),
                title: "Bootstrap".to_string(),
                preview: "Preview".to_string(),
                body: Some("Short body.".to_string()),
                approx_tokens: 25,
            }],
            available_brains: vec![local_brain("qwen", "Qwen")],
            preferred_auto_brain: None,
            vault_path: String::new(),
            graph_context: None,
        };
        let catalog = vec![
            sample_tool("read_file", false),
            sample_tool("memory_search", false),
            sample_tool("bash", true),
        ];

        let compiled = compile_with_catalog(input, catalog);
        let out_json = serde_json::to_string(&compiled).expect("serialize");
        let out: serde_json::Value = serde_json::from_str(&out_json).expect("parse");

        assert_eq!(out["contractVersion"], "v1");
        assert_eq!(out["query"], "explain the vault bootstrap");
        assert_eq!(out["requestedToolNames"].as_array().unwrap().len(), 2);
        assert!(out["resolvedRuntime"]["resolved"].get("local").is_some());
        assert!(out["notesContext"]
            .as_str()
            .unwrap()
            .contains("## Requested Note Context"));
        // Three-entry Rust catalog, two toggled on → two allow / one deny.
        let perms = out["resolvedToolPermissions"].as_array().unwrap();
        let allow_count = perms
            .iter()
            .filter(|p| p["decision"].get("allow").is_some())
            .count();
        assert_eq!(allow_count, 2);
        assert_eq!(perms.len(), 3);
        assert_eq!(
            out["resolvedExecutionPolicy"]["route"],
            "overseer_local_execution"
        );
        assert_eq!(out["resolvedExecutionPolicy"]["maxTurns"], 3);
    }

    /// Compiling with an empty vault_path must produce an empty catalog and
    /// synthesize explicit deny entries for every user-toggled tool — no
    /// silent drops, no fake successes (PLAN_V2 §3.4).
    #[test]
    fn compile_from_json_empty_vault_path_synthesizes_deny_entries() {
        let input_json = json!({
            "query": "q",
            "operatingMode": "agent",
            "enabledToolNames": ["web_search", "vault_read"],
            "availableBrains": [{ "kind": "appleIntelligence", "identifier": "apple", "displayName": "Apple" }],
            "vaultPath": ""
        })
        .to_string();
        let out_json = compile_from_json(&input_json).expect("compile_from_json");
        let out: serde_json::Value = serde_json::from_str(&out_json).expect("parse");
        let perms = out["resolvedToolPermissions"].as_array().unwrap();
        assert_eq!(perms.len(), 2);
        for perm in perms {
            let deny = perm["decision"]["deny"].as_object().expect("deny object");
            assert_eq!(deny["reason"].as_str(), Some("tool_catalog_unavailable"));
        }
    }

    /// `build_catalog_for_tier` with an empty vault_path is the fail-closed
    /// state: no tools returned, not a panic. Rust then synthesizes
    /// user-enabled names as explicit deny entries with a truthful reason.
    #[test]
    fn build_catalog_for_tier_empty_vault_path_yields_empty_catalog() {
        let catalog = build_catalog_for_tier("", "agent");
        assert!(catalog.is_empty());
    }

    #[test]
    fn build_catalog_for_tier_hides_unsupported_image_generation() {
        let vault = tempfile::tempdir().expect("tempdir");
        let catalog = build_catalog_for_tier(vault.path().to_str().unwrap(), "agent");
        assert!(!catalog.iter().any(|tool| tool.name == "image_generate"));
    }

    /// User enabled a tool name that Rust's catalog does not contain at the
    /// current tier. The permission table must surface it as an explicit
    /// deny with reason `not_in_rust_catalog`, never silently drop it.
    #[test]
    fn resolve_tool_permissions_surfaces_unknown_enabled_names() {
        let catalog = vec![sample_tool("read_file", false)];
        let enabled: std::collections::BTreeSet<&str> =
            ["read_file", "ghost_tool"].iter().copied().collect();
        let perms = resolve_tool_permissions(&enabled, &catalog);
        assert_eq!(perms.len(), 2);
        let ghost = perms
            .iter()
            .find(|p| p.tool_name == "ghost_tool")
            .expect("ghost_tool entry");
        assert!(matches!(
            &ghost.decision,
            ToolDecision::Deny { reason } if reason == "not_in_rust_catalog"
        ));
    }

    #[test]
    fn compile_from_json_rejects_malformed_input() {
        let err = compile_from_json("{not json").unwrap_err();
        assert!(err.contains("invalid input JSON"));
    }

    #[test]
    fn tier_for_operating_mode_maps_expected_tiers() {
        assert_eq!(tier_for_operating_mode(OperatingMode::Fast), "chat_lite");
        assert_eq!(
            tier_for_operating_mode(OperatingMode::Thinking),
            "chat_lite"
        );
        assert_eq!(tier_for_operating_mode(OperatingMode::Pro), "chat_pro");
        assert_eq!(tier_for_operating_mode(OperatingMode::Agent), "agent");
    }

    #[test]
    fn resolved_context_ref_note_round_trips() {
        let refs = vec![ResolvedContextRef::Note {
            id: "p1".to_string(),
            title: "T".to_string(),
            preview: "p".to_string(),
            body: Some("b".to_string()),
            approx_tokens: 3,
        }];
        let json = serde_json::to_string(&refs).unwrap();
        let back: Vec<ResolvedContextRef> = serde_json::from_str(&json).unwrap();
        assert_eq!(back.len(), 1);
    }

    #[test]
    fn graph_context_passes_through_compile() {
        let ctx = GraphContext {
            graph_node_id: "g-node-1".to_string(),
            source_id: Some("page-abc".to_string()),
            node_type: "note".to_string(),
            node_label: "Design Review".to_string(),
            graph_route: "canvas".to_string(),
        };
        let input = CompileCommandCenterInput {
            query: "tell me about this node".to_string(),
            conversation_history: None,
            operating_mode: OperatingMode::Agent,
            slash_token: None,
            brain_override: None,
            enabled_tool_names: vec![],
            requested_mentions: vec![],
            resolved_mentions: vec![],
            available_brains: vec![local_brain("qwen", "Qwen")],
            preferred_auto_brain: Some(local_brain("qwen", "Qwen")),
            vault_path: String::new(),
            graph_context: Some(ctx),
        };
        let compiled = compile_with_catalog(input, vec![]);
        let gc = compiled
            .graph_context
            .expect("graph_context must pass through");
        assert_eq!(gc.graph_node_id, "g-node-1");
        assert_eq!(gc.source_id.as_deref(), Some("page-abc"));
        assert_eq!(gc.node_type, "note");
        assert_eq!(gc.node_label, "Design Review");
        assert_eq!(gc.graph_route, "canvas");
    }

    #[test]
    fn graph_context_none_when_absent() {
        let input = CompileCommandCenterInput {
            query: "plain chat".to_string(),
            conversation_history: None,
            operating_mode: OperatingMode::Fast,
            slash_token: None,
            brain_override: None,
            enabled_tool_names: vec![],
            requested_mentions: vec![],
            resolved_mentions: vec![],
            available_brains: vec![local_brain("qwen", "Qwen")],
            preferred_auto_brain: None,
            vault_path: String::new(),
            graph_context: None,
        };
        let compiled = compile_with_catalog(input, vec![]);
        assert!(compiled.graph_context.is_none());
    }

    #[test]
    fn graph_context_round_trips_through_json() {
        let ctx = GraphContext {
            graph_node_id: "gn-42".to_string(),
            source_id: None,
            node_type: "idea".to_string(),
            node_label: "Brainstorm".to_string(),
            graph_route: "folder:f1".to_string(),
        };
        let json = serde_json::to_string(&ctx).unwrap();
        let back: GraphContext = serde_json::from_str(&json).unwrap();
        assert_eq!(back.graph_node_id, "gn-42");
        assert!(back.source_id.is_none());
        assert_eq!(back.node_type, "idea");
    }
}
