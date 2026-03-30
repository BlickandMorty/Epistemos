use serde::{Deserialize, Serialize};

use super::config::{AgentRuntimeConfig, RuntimeProviderKind};

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum RoutingReason {
    Privacy,
    CurrentInfo,
    ShellExecution,
    ComputerUse,
    LightweightLocal,
    ComplexReasoning,
}

impl RoutingReason {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Privacy => "privacy",
            Self::CurrentInfo => "current_info",
            Self::ShellExecution => "shell_execution",
            Self::ComputerUse => "computer_use",
            Self::LightweightLocal => "lightweight_local",
            Self::ComplexReasoning => "complex_reasoning",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct RouteDecision {
    pub provider: RuntimeProviderKind,
    pub model: String,
    pub reason: RoutingReason,
    pub hosted_tool_domains: Vec<String>,
    pub remote_mcp_servers: Vec<String>,
    pub allow_local_full_loop: bool,
    pub notes: Vec<String>,
}

pub fn route_objective(objective: &str, config: &AgentRuntimeConfig) -> RouteDecision {
    let lower = objective.to_lowercase();
    let remote_mcp_servers = config
        .mcp_servers
        .iter()
        .filter(|server| server.enabled && server.remote)
        .map(|server| server.name.clone())
        .collect::<Vec<_>>();
    let allow_local_full_loop = config.local_agent_policy.can_autonomously_orchestrate();

    if contains_any(
        &lower,
        &["private", "privacy", "local only", "offline", "on-device"],
    ) {
        return build_route(
            config,
            RuntimeProviderKind::Local,
            RoutingReason::Privacy,
            vec!["vault".to_string(), "memory".to_string()],
            remote_mcp_servers,
            allow_local_full_loop,
            vec![
                "Keep the full loop on-device when privacy mode is explicit.".to_string(),
                "Bound weak local models to short loops; only capable local models get autonomous turns.".to_string(),
            ],
        );
    }

    if contains_any(
        &lower,
        &[
            "latest", "current", "today", "news", "search", "web", "research",
        ],
    ) {
        return build_route(
            config,
            RuntimeProviderKind::Perplexity,
            RoutingReason::CurrentInfo,
            vec![
                "web_search".to_string(),
                "web_fetch".to_string(),
                "citations".to_string(),
            ],
            Vec::new(),
            false,
            vec![
                "Use Perplexity's Agent API for grounded current-information workflows."
                    .to_string(),
                "Bring synthesized results back into the canonical Rust transcript loop."
                    .to_string(),
            ],
        );
    }

    if contains_any(
        &lower,
        &["terminal", "shell", "bash", "zsh", "command", "script"],
    ) {
        return build_route(
            config,
            RuntimeProviderKind::OpenAI,
            RoutingReason::ShellExecution,
            vec![
                "shell".to_string(),
                "filesystem".to_string(),
                "memory".to_string(),
            ],
            Vec::new(),
            false,
            vec![
                "Route shell-heavy work to the Responses API path for bounded tool execution."
                    .to_string(),
            ],
        );
    }

    if contains_any(
        &lower,
        &[
            "click",
            "type",
            "window",
            "menu",
            "app",
            "screen",
            "accessibility",
            "ax",
        ],
    ) {
        return build_route(
            config,
            RuntimeProviderKind::Claude,
            RoutingReason::ComputerUse,
            vec![
                "computer_use".to_string(),
                "vault".to_string(),
                "memory".to_string(),
            ],
            remote_mcp_servers,
            false,
            vec![
                "Computer use stays AX-first via hosted native tools, with screenshot verification as fallback.".to_string(),
                "Remote MCP remains optional; local stdio MCP stays app-hosted instead of being tunneled through Anthropic.".to_string(),
            ],
        );
    }

    if contains_any(
        &lower,
        &[
            "tag",
            "classify",
            "summarize",
            "rewrite",
            "outline",
            "organize",
        ],
    ) {
        return build_route(
            config,
            RuntimeProviderKind::Local,
            RoutingReason::LightweightLocal,
            vec!["vault".to_string(), "memory".to_string()],
            Vec::new(),
            allow_local_full_loop,
            vec![
                "Local models share the same event and tool-loop contract as cloud providers."
                    .to_string(),
                "Short-loop transforms stay local even when cloud providers are configured."
                    .to_string(),
            ],
        );
    }

    build_route(
        config,
        RuntimeProviderKind::Claude,
        RoutingReason::ComplexReasoning,
        vec![
            "vault".to_string(),
            "memory".to_string(),
            "subagents".to_string(),
            "computer_use".to_string(),
        ],
        remote_mcp_servers,
        false,
        vec![
            "Claude remains the primary orchestrator for multi-step reasoning and tool continuity.".to_string(),
            "Remote MCP connectors are only attached for HTTP-accessible servers; local stdio servers stay host-managed.".to_string(),
        ],
    )
}

fn build_route(
    config: &AgentRuntimeConfig,
    preferred_provider: RuntimeProviderKind,
    reason: RoutingReason,
    hosted_tool_domains: Vec<String>,
    remote_mcp_servers: Vec<String>,
    allow_local_full_loop: bool,
    notes: Vec<String>,
) -> RouteDecision {
    let resolved_provider = if config.provider(preferred_provider).is_some() {
        preferred_provider
    } else if config.provider(RuntimeProviderKind::Claude).is_some() {
        RuntimeProviderKind::Claude
    } else if config.provider(RuntimeProviderKind::Local).is_some() {
        RuntimeProviderKind::Local
    } else {
        config
            .providers
            .iter()
            .find(|provider| provider.enabled)
            .map(|provider| provider.kind)
            .unwrap_or(RuntimeProviderKind::Local)
    };

    let model = config
        .provider(resolved_provider)
        .map(|provider| provider.model.clone())
        .unwrap_or_default();

    RouteDecision {
        provider: resolved_provider,
        model,
        reason,
        hosted_tool_domains,
        remote_mcp_servers,
        allow_local_full_loop: resolved_provider == RuntimeProviderKind::Local
            && allow_local_full_loop,
        notes,
    }
}

fn contains_any(haystack: &str, needles: &[&str]) -> bool {
    needles.iter().any(|needle| haystack.contains(needle))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::agent_runtime::config::{McpServerConfig, McpTransport};

    #[test]
    fn routes_current_info_to_perplexity() {
        let config = AgentRuntimeConfig::production_defaults("/tmp/agents".to_string());

        let route = route_objective("What are the latest AI agent releases today?", &config);

        assert_eq!(route.provider, RuntimeProviderKind::Perplexity);
        assert_eq!(route.reason, RoutingReason::CurrentInfo);
        assert!(route
            .hosted_tool_domains
            .contains(&"web_search".to_string()));
    }

    #[test]
    fn routes_explicit_privacy_to_local_and_allows_full_loop_when_capable() {
        let config = AgentRuntimeConfig::production_defaults("/tmp/agents".to_string());

        let route = route_objective("Do this private, local only, offline", &config);

        assert_eq!(route.provider, RuntimeProviderKind::Local);
        assert_eq!(route.reason, RoutingReason::Privacy);
        assert!(route.allow_local_full_loop);
    }

    #[test]
    fn complex_reasoning_routes_to_claude_and_includes_remote_mcp_names() {
        let mut config = AgentRuntimeConfig::production_defaults("/tmp/agents".to_string());
        config.mcp_servers.push(McpServerConfig::remote_url(
            "calendar",
            McpTransport::StreamableHttp,
            "https://calendar.example.com/mcp",
            "GCAL_MCP_TOKEN",
            false,
        ));

        let route = route_objective("Plan and execute a multi-step desktop workflow", &config);

        assert_eq!(route.provider, RuntimeProviderKind::Claude);
        assert_eq!(route.reason, RoutingReason::ComplexReasoning);
        assert_eq!(route.remote_mcp_servers, vec!["calendar".to_string()]);
    }

    #[test]
    fn local_full_loop_disables_when_capable_model_list_is_empty() {
        let mut config = AgentRuntimeConfig::production_defaults("/tmp/agents".to_string());
        config.local_agent_policy.capable_models.clear();

        let route = route_objective("Rewrite and summarize these notes locally", &config);

        assert_eq!(route.provider, RuntimeProviderKind::Local);
        assert!(!route.allow_local_full_loop);
    }
}
