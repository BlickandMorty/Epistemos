use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use super::config::{AgentProviderConfig, McpServerConfig, McpTransport, RuntimeProviderKind};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProviderHeader {
    pub name: String,
    pub value: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProviderRequestBlueprint {
    pub provider: RuntimeProviderKind,
    pub method: String,
    pub url: String,
    pub headers: Vec<ProviderHeader>,
    pub body_json: String,
}

pub fn build_claude_request(
    config: &AgentProviderConfig,
    messages: Vec<Value>,
    tools: Vec<Value>,
    max_tokens: u32,
    thinking_budget_tokens: u32,
    mcp_servers: &[McpServerConfig],
) -> Result<ProviderRequestBlueprint, String> {
    if config.kind != RuntimeProviderKind::Claude {
        return Err("claude request builder requires a Claude provider config".to_string());
    }

    let remote_servers = mcp_servers
        .iter()
        .filter(|server| server.enabled && server.remote)
        .filter_map(anthropic_remote_mcp_server_json)
        .collect::<Vec<_>>();

    let mut beta_features = vec!["interleaved-thinking-2025-05-14".to_string()];
    if !remote_servers.is_empty() {
        beta_features.push("mcp-client-2025-04-04".to_string());
    }

    let mut body = json!({
        "model": config.model,
        "max_tokens": max_tokens,
        "messages": messages,
        "stream": true,
        "thinking": {
            "type": "enabled",
            "budget_tokens": thinking_budget_tokens,
        },
        "tools": tools,
    });

    if !remote_servers.is_empty() {
        body["mcp_servers"] = Value::Array(remote_servers);
    }

    Ok(ProviderRequestBlueprint {
        provider: RuntimeProviderKind::Claude,
        method: "POST".to_string(),
        url: config.base_url.clone(),
        headers: vec![
            ProviderHeader {
                name: "content-type".to_string(),
                value: "application/json".to_string(),
            },
            ProviderHeader {
                name: "x-api-key".to_string(),
                value: format!("${{{}}}", config.api_key_env),
            },
            ProviderHeader {
                name: "anthropic-version".to_string(),
                value: "2023-06-01".to_string(),
            },
            ProviderHeader {
                name: "anthropic-beta".to_string(),
                value: beta_features.join(","),
            },
        ],
        body_json: serde_json::to_string_pretty(&body).map_err(|error| error.to_string())?,
    })
}

pub fn build_perplexity_request(
    config: &AgentProviderConfig,
    input: Value,
    instructions: Option<&str>,
    max_output_tokens: u32,
    enable_web_search: bool,
) -> Result<ProviderRequestBlueprint, String> {
    if config.kind != RuntimeProviderKind::Perplexity {
        return Err("perplexity request builder requires a Perplexity provider config".to_string());
    }

    let mut body = json!({
        "input": input,
        "stream": true,
    });

    if !config.model.is_empty() {
        body["model"] = Value::String(config.model.clone());
    }
    if !config.preset.is_empty() {
        body["preset"] = Value::String(config.preset.clone());
    }
    if max_output_tokens > 0 {
        body["max_output_tokens"] = Value::Number(max_output_tokens.into());
    }
    if let Some(instructions) = instructions {
        if !instructions.is_empty() {
            body["instructions"] = Value::String(instructions.to_string());
        }
    }
    if enable_web_search {
        body["tools"] = json!([{ "type": "web_search" }]);
    }

    Ok(ProviderRequestBlueprint {
        provider: RuntimeProviderKind::Perplexity,
        method: "POST".to_string(),
        url: config.base_url.clone(),
        headers: vec![
            ProviderHeader {
                name: "content-type".to_string(),
                value: "application/json".to_string(),
            },
            ProviderHeader {
                name: "authorization".to_string(),
                value: format!("Bearer ${{{}}}", config.api_key_env),
            },
        ],
        body_json: serde_json::to_string_pretty(&body).map_err(|error| error.to_string())?,
    })
}

pub fn build_openai_request(
    config: &AgentProviderConfig,
    input: Value,
    instructions: Option<&str>,
    tools: Vec<Value>,
    max_output_tokens: u32,
) -> Result<ProviderRequestBlueprint, String> {
    if config.kind != RuntimeProviderKind::OpenAI {
        return Err("openai request builder requires an OpenAI provider config".to_string());
    }

    let mut body = json!({
        "model": config.model,
        "input": input,
        "stream": true,
    });
    if max_output_tokens > 0 {
        body["max_output_tokens"] = Value::Number(max_output_tokens.into());
    }
    if let Some(instructions) = instructions {
        if !instructions.is_empty() {
            body["instructions"] = Value::String(instructions.to_string());
        }
    }
    if !tools.is_empty() {
        body["tools"] = Value::Array(tools);
    }

    Ok(ProviderRequestBlueprint {
        provider: RuntimeProviderKind::OpenAI,
        method: "POST".to_string(),
        url: config.base_url.clone(),
        headers: vec![
            ProviderHeader {
                name: "content-type".to_string(),
                value: "application/json".to_string(),
            },
            ProviderHeader {
                name: "authorization".to_string(),
                value: format!("Bearer ${{{}}}", config.api_key_env),
            },
        ],
        body_json: serde_json::to_string_pretty(&body).map_err(|error| error.to_string())?,
    })
}

fn anthropic_remote_mcp_server_json(server: &McpServerConfig) -> Option<Value> {
    let server_type = match server.transport {
        McpTransport::StreamableHttp | McpTransport::Sse => "url",
        McpTransport::Stdio => return None,
    };

    let mut json = json!({
        "type": server_type,
        "url": server.endpoint,
        "name": server.name,
    });
    if !server.authorization_env.is_empty() {
        json["authorization_token"] = Value::String(format!("${{{}}}", server.authorization_env));
    }
    Some(json)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::agent_runtime::config::{AgentRuntimeConfig, McpServerConfig, McpTransport};

    #[test]
    fn claude_request_uses_messages_api_and_remote_mcp_only() {
        let mut config = AgentRuntimeConfig::production_defaults("/tmp/agents".to_string());
        config.mcp_servers.push(McpServerConfig::remote_url(
            "calendar",
            McpTransport::StreamableHttp,
            "https://calendar.example.com/mcp",
            "GCAL_MCP_TOKEN",
            false,
        ));

        let request = build_claude_request(
            config
                .provider(RuntimeProviderKind::Claude)
                .expect("claude provider should exist"),
            vec![json!({ "role": "user", "content": "Plan my day" })],
            vec![json!({
                "name": "vault_search",
                "description": "Search the local vault",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "query": { "type": "string" }
                    },
                    "required": ["query"]
                }
            })],
            4096,
            2048,
            &config.mcp_servers,
        )
        .expect("claude request should build");

        assert_eq!(request.url, "https://api.anthropic.com/v1/messages");
        assert!(request
            .headers
            .iter()
            .any(|header| header.name == "anthropic-beta"
                && header.value.contains("interleaved-thinking-2025-05-14")
                && header.value.contains("mcp-client-2025-04-04")));
        assert!(request.body_json.contains("\"thinking\""));
        assert!(request.body_json.contains("\"mcp_servers\""));
        assert!(request.body_json.contains("\"calendar\""));
        assert!(!request.body_json.contains("epistemos-vault-mcp"));
    }

    #[test]
    fn perplexity_request_uses_agent_endpoint_and_web_search_tool() {
        let config = AgentRuntimeConfig::production_defaults("/tmp/agents".to_string());
        let request = build_perplexity_request(
            config
                .provider(RuntimeProviderKind::Perplexity)
                .expect("perplexity provider should exist"),
            json!([{ "role": "user", "content": "What happened today in AI?" }]),
            Some("Use web search whenever the user asks for current information."),
            2048,
            true,
        )
        .expect("perplexity request should build");

        assert_eq!(request.url, "https://api.perplexity.ai/v1/agent");
        assert!(request.body_json.contains("\"preset\": \"pro-search\""));
        assert!(request.body_json.contains("\"type\": \"web_search\""));
    }

    #[test]
    fn openai_request_targets_responses_api() {
        let config = AgentRuntimeConfig::production_defaults("/tmp/agents".to_string());
        let request = build_openai_request(
            config
                .provider(RuntimeProviderKind::OpenAI)
                .expect("openai provider should exist"),
            json!([{ "role": "user", "content": "Run a bounded shell analysis" }]),
            Some("Use tools only when necessary."),
            vec![json!({
                "type": "function",
                "name": "shell",
                "description": "Run a bounded shell command"
            })],
            1024,
        )
        .expect("openai request should build");

        assert_eq!(request.url, "https://api.openai.com/v1/responses");
        assert!(request.body_json.contains("\"stream\": true"));
        assert!(request.body_json.contains("\"tools\""));
    }
}
