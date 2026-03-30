use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum RuntimeProviderKind {
    Claude,
    Perplexity,
    OpenAI,
    Google,
    Local,
}

impl RuntimeProviderKind {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Claude => "claude",
            Self::Perplexity => "perplexity",
            Self::OpenAI => "openai",
            Self::Google => "google",
            Self::Local => "local",
        }
    }

    pub fn parse(value: &str) -> Option<Self> {
        match value.trim().to_ascii_lowercase().as_str() {
            "claude" | "anthropic" => Some(Self::Claude),
            "perplexity" => Some(Self::Perplexity),
            "openai" | "open_ai" => Some(Self::OpenAI),
            "google" | "gemini" => Some(Self::Google),
            "local" | "mlx" | "ollama" => Some(Self::Local),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProviderCapabilities {
    pub streaming: bool,
    pub tool_loop: bool,
    pub remote_mcp: bool,
    pub hosted_tools: bool,
    pub native_computer_use: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct AgentProviderConfig {
    pub kind: RuntimeProviderKind,
    pub label: String,
    pub model: String,
    pub base_url: String,
    pub api_key_env: String,
    pub enabled: bool,
    pub preset: String,
    pub capabilities: ProviderCapabilities,
}

impl AgentProviderConfig {
    fn new(
        kind: RuntimeProviderKind,
        label: &str,
        model: &str,
        base_url: &str,
        api_key_env: &str,
        preset: &str,
        capabilities: ProviderCapabilities,
    ) -> Self {
        Self {
            kind,
            label: label.to_string(),
            model: model.to_string(),
            base_url: base_url.to_string(),
            api_key_env: api_key_env.to_string(),
            enabled: true,
            preset: preset.to_string(),
            capabilities,
        }
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum McpTransport {
    Stdio,
    StreamableHttp,
    Sse,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct McpServerConfig {
    pub name: String,
    pub transport: McpTransport,
    pub endpoint: String,
    pub args: Vec<String>,
    pub enabled: bool,
    pub remote: bool,
    pub read_only: bool,
    pub authorization_env: String,
}

impl McpServerConfig {
    pub fn local_stdio(name: &str, command: &str, args: Vec<String>, read_only: bool) -> Self {
        Self {
            name: name.to_string(),
            transport: McpTransport::Stdio,
            endpoint: command.to_string(),
            args,
            enabled: true,
            remote: false,
            read_only,
            authorization_env: String::new(),
        }
    }

    pub fn remote_url(
        name: &str,
        transport: McpTransport,
        url: &str,
        authorization_env: &str,
        read_only: bool,
    ) -> Self {
        Self {
            name: name.to_string(),
            transport,
            endpoint: url.to_string(),
            args: Vec::new(),
            enabled: true,
            remote: true,
            read_only,
            authorization_env: authorization_env.to_string(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct LocalAgentPolicy {
    pub allow_full_loop: bool,
    pub max_autonomous_turns: u32,
    pub capable_models: Vec<String>,
    pub bounded_roles: Vec<String>,
    pub full_loop_roles: Vec<String>,
    pub require_structured_tools: bool,
}

impl LocalAgentPolicy {
    pub fn production_default() -> Self {
        Self {
            allow_full_loop: true,
            max_autonomous_turns: 8,
            capable_models: vec![
                "mlx-community/Qwen3.5-27B-4bit".to_string(),
                "mlx-community/Qwen3.5-35B-A3B-4bit".to_string(),
                "mlx-community/Devstral-Small-2505-4bit".to_string(),
                "mlx-community/Mistral-Small-3.1-24B-Instruct-2503-4bit".to_string(),
                "mlx-community/gemma-3-27b-it-qat-4bit".to_string(),
            ],
            bounded_roles: vec![
                "tagger".to_string(),
                "classifier".to_string(),
                "rewriter".to_string(),
                "summarizer".to_string(),
                "router".to_string(),
            ],
            full_loop_roles: vec![
                "writer".to_string(),
                "coder".to_string(),
                "critic".to_string(),
            ],
            require_structured_tools: true,
        }
    }

    pub fn can_autonomously_orchestrate(&self) -> bool {
        self.allow_full_loop && !self.capable_models.is_empty()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct AgentRuntimeConfig {
    pub transcript_root: String,
    pub providers: Vec<AgentProviderConfig>,
    pub mcp_servers: Vec<McpServerConfig>,
    pub local_agent_policy: LocalAgentPolicy,
}

impl AgentRuntimeConfig {
    pub fn production_defaults(transcript_root: String) -> Self {
        Self {
            transcript_root,
            providers: vec![
                AgentProviderConfig::new(
                    RuntimeProviderKind::Claude,
                    "Primary orchestrator",
                    "claude-sonnet-4-20250514",
                    "https://api.anthropic.com/v1/messages",
                    "ANTHROPIC_API_KEY",
                    "",
                    ProviderCapabilities {
                        streaming: true,
                        tool_loop: true,
                        remote_mcp: true,
                        hosted_tools: true,
                        native_computer_use: true,
                    },
                ),
                AgentProviderConfig::new(
                    RuntimeProviderKind::Perplexity,
                    "Grounded search",
                    "sonar-pro",
                    "https://api.perplexity.ai/v1/agent",
                    "PERPLEXITY_API_KEY",
                    "pro-search",
                    ProviderCapabilities {
                        streaming: true,
                        tool_loop: true,
                        remote_mcp: false,
                        hosted_tools: true,
                        native_computer_use: false,
                    },
                ),
                AgentProviderConfig::new(
                    RuntimeProviderKind::OpenAI,
                    "Secondary shell/recovery provider",
                    "gpt-5.4",
                    "https://api.openai.com/v1/responses",
                    "OPENAI_API_KEY",
                    "",
                    ProviderCapabilities {
                        streaming: true,
                        tool_loop: true,
                        remote_mcp: false,
                        hosted_tools: true,
                        native_computer_use: false,
                    },
                ),
                AgentProviderConfig::new(
                    RuntimeProviderKind::Google,
                    "Optional deep-research fallback",
                    "gemini-2.5-pro",
                    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:streamGenerateContent",
                    "GOOGLE_API_KEY",
                    "",
                    ProviderCapabilities {
                        streaming: true,
                        tool_loop: true,
                        remote_mcp: false,
                        hosted_tools: true,
                        native_computer_use: false,
                    },
                ),
                AgentProviderConfig::new(
                    RuntimeProviderKind::Local,
                    "Private local runtime",
                    "mlx-community/Qwen3.5-27B-4bit",
                    "mlx://epistemos-local-agent-runtime",
                    "",
                    "",
                    ProviderCapabilities {
                        streaming: true,
                        tool_loop: true,
                        remote_mcp: false,
                        hosted_tools: true,
                        native_computer_use: true,
                    },
                ),
            ],
            mcp_servers: vec![
                McpServerConfig::local_stdio(
                    "vault",
                    "epistemos-vault-mcp",
                    Vec::new(),
                    false,
                ),
                McpServerConfig::local_stdio(
                    "system",
                    "epistemos-system-mcp",
                    Vec::new(),
                    false,
                ),
            ],
            local_agent_policy: LocalAgentPolicy::production_default(),
        }
    }

    pub fn provider(&self, kind: RuntimeProviderKind) -> Option<&AgentProviderConfig> {
        self.providers
            .iter()
            .find(|provider| provider.kind == kind && provider.enabled)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn production_defaults_include_real_cloud_and_local_providers() {
        let config = AgentRuntimeConfig::production_defaults("/tmp/agents".to_string());
        let provider_kinds: Vec<RuntimeProviderKind> = config
            .providers
            .iter()
            .map(|provider| provider.kind)
            .collect();

        assert!(provider_kinds.contains(&RuntimeProviderKind::Claude));
        assert!(provider_kinds.contains(&RuntimeProviderKind::Perplexity));
        assert!(provider_kinds.contains(&RuntimeProviderKind::OpenAI));
        assert!(provider_kinds.contains(&RuntimeProviderKind::Local));

        let claude = config
            .provider(RuntimeProviderKind::Claude)
            .expect("claude provider should be present");
        assert_eq!(claude.base_url, "https://api.anthropic.com/v1/messages");

        let perplexity = config
            .provider(RuntimeProviderKind::Perplexity)
            .expect("perplexity provider should be present");
        assert_eq!(perplexity.base_url, "https://api.perplexity.ai/v1/agent");
        assert_eq!(perplexity.preset, "pro-search");
    }

    #[test]
    fn production_defaults_include_local_mcp_hosts() {
        let config = AgentRuntimeConfig::production_defaults("/tmp/agents".to_string());

        assert_eq!(config.mcp_servers.len(), 2);
        assert!(config
            .mcp_servers
            .iter()
            .all(|server| server.transport == McpTransport::Stdio));
        assert!(config
            .mcp_servers
            .iter()
            .any(|server| server.name == "vault"));
        assert!(config
            .mcp_servers
            .iter()
            .any(|server| server.name == "system"));
    }

    #[test]
    fn parses_provider_aliases() {
        assert_eq!(
            RuntimeProviderKind::parse("claude"),
            Some(RuntimeProviderKind::Claude)
        );
        assert_eq!(
            RuntimeProviderKind::parse("anthropic"),
            Some(RuntimeProviderKind::Claude)
        );
        assert_eq!(
            RuntimeProviderKind::parse("openai"),
            Some(RuntimeProviderKind::OpenAI)
        );
        assert_eq!(
            RuntimeProviderKind::parse("gemini"),
            Some(RuntimeProviderKind::Google)
        );
        assert_eq!(
            RuntimeProviderKind::parse("ollama"),
            Some(RuntimeProviderKind::Local)
        );
        assert_eq!(RuntimeProviderKind::parse("unknown"), None);
    }
}
