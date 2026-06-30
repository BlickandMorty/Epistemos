use serde_json::json;

use crate::model_profile::{CapabilityTier, CLOUD_CANON};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct MasProviderConfig {
    id: &'static str,
    name: &'static str,
    key_name: &'static str,
    host_key_name: Option<&'static str>,
    description: &'static str,
    setup_steps: &'static [&'static str],
}

const MAS_PROVIDER_CONFIGS: &[MasProviderConfig] = &[
    MasProviderConfig {
        id: "anthropic",
        name: "Anthropic",
        key_name: "ANTHROPIC_API_KEY",
        host_key_name: Some("ANTHROPIC_HOST"),
        description: "Claude models over Anthropic's hosted API.",
        setup_steps: &[
            "Create an Anthropic API key.",
            "Save the key in Epistemos provider settings.",
        ],
    },
    MasProviderConfig {
        id: "openai",
        name: "OpenAI",
        key_name: "OPENAI_API_KEY",
        host_key_name: Some("OPENAI_BASE_URL"),
        description: "OpenAI models over the hosted API.",
        setup_steps: &[
            "Create an OpenAI API key.",
            "Save the key in Epistemos provider settings.",
        ],
    },
    MasProviderConfig {
        id: "google",
        name: "Google",
        key_name: "GOOGLE_API_KEY",
        host_key_name: None,
        description: "Gemini models over Google's hosted API.",
        setup_steps: &[
            "Create a Google AI Studio API key.",
            "Save the key in Epistemos provider settings.",
        ],
    },
    MasProviderConfig {
        id: "deepseek",
        name: "DeepSeek",
        key_name: "DEEPSEEK_API_KEY",
        host_key_name: None,
        description: "DeepSeek cloud models.",
        setup_steps: &[
            "Create a DeepSeek API key.",
            "Save the key in Epistemos provider settings.",
        ],
    },
    MasProviderConfig {
        id: "kimi",
        name: "Kimi",
        key_name: "KIMI_API_KEY",
        host_key_name: None,
        description: "Kimi cloud models.",
        setup_steps: &[
            "Create a Kimi API key.",
            "Save the key in Epistemos provider settings.",
        ],
    },
    MasProviderConfig {
        id: "zai",
        name: "Z.AI",
        key_name: "ZAI_API_KEY",
        host_key_name: None,
        description: "Z.AI cloud models.",
        setup_steps: &[
            "Create a Z.AI API key.",
            "Save the key in Epistemos provider settings.",
        ],
    },
    MasProviderConfig {
        id: "minimax",
        name: "MiniMax",
        key_name: "MINIMAX_API_KEY",
        host_key_name: None,
        description: "MiniMax cloud models.",
        setup_steps: &[
            "Create a MiniMax API key.",
            "Save the key in Epistemos provider settings.",
        ],
    },
];

fn provider_config(id: &str) -> Option<MasProviderConfig> {
    MAS_PROVIDER_CONFIGS
        .iter()
        .copied()
        .find(|entry| entry.id == id)
}

fn family(id: &str) -> &'static str {
    match id {
        "anthropic" => "claude",
        "openai" => "gpt",
        "google" => "gemini",
        "deepseek" => "deepseek",
        "kimi" => "kimi",
        "zai" => "glm",
        "minimax" => "minimax",
        _ => "cloud",
    }
}

fn provider_entry(id: &str) -> serde_json::Value {
    let profile = CLOUD_CANON
        .iter()
        .find(|profile| profile.id == id)
        .unwrap_or_else(|| CLOUD_CANON.first().expect("CLOUD_CANON is empty"));
    let config = provider_config(id);
    let provider_name = config
        .map(|entry| entry.name)
        .unwrap_or(profile.display_name);
    let key_name = config
        .map(|entry| entry.key_name)
        .unwrap_or("CLOUD_PROVIDER_API_KEY");
    let host_key_name = config.and_then(|entry| entry.host_key_name);
    let description = config
        .map(|entry| entry.description)
        .unwrap_or("Cloud model provider.");
    let setup_steps = config
        .map(|entry| entry.setup_steps)
        .unwrap_or(&["Save the provider API key in Epistemos settings."]);
    let reasoning = profile.tier == CapabilityTier::Think;

    let mut config_keys = vec![json!({
        "default": null,
        "deviceCodeFlow": false,
        "name": key_name,
        "oauthFlow": false,
        "primary": true,
        "required": true,
        "secret": true,
    })];
    if let Some(host_key_name) = host_key_name {
        config_keys.push(json!({
            "default": null,
            "deviceCodeFlow": false,
            "name": host_key_name,
            "oauthFlow": false,
            "primary": false,
            "required": false,
            "secret": false,
        }));
    }

    json!({
        "category": "model",
        "configKeys": config_keys,
        "configured": false,
        "defaultModel": profile.id,
        "description": description,
        "masBounded": true,
        "models": [{
            "contextLimit": profile.context_window,
            "family": family(profile.id),
            "id": profile.id,
            "name": profile.display_name,
            "reasoning": reasoning,
            "recommended": profile.advertised,
        }],
        "providerId": profile.id,
        "providerName": provider_name,
        "providerType": "AgentCoreMAS",
        "refreshing": false,
        "setupSteps": setup_steps,
        "stale": false,
        "supportsRefresh": false,
    })
}

/// MAS Goose ACP catalog source of truth for the in-process backend.
///
/// This is intentionally data-only and always MAS-safe: no subprocess, no local
/// stdio MCP, no shell/developer builtin, no provider secrets. Swift serves this
/// over ACP so the Goose WebUI can enumerate capabilities from the backend rather
/// than carrying a Swift-side provider/model roster.
#[uniffi::export]
pub fn goose_mas_acp_catalog_json() -> String {
    #[cfg(feature = "pro-build")]
    let policy_profile = "direct";
    #[cfg(not(feature = "pro-build"))]
    let policy_profile = "mas_sandbox";

    let providers: Vec<_> = CLOUD_CANON
        .iter()
        .map(|profile| provider_entry(profile.id))
        .collect();

    json!({
        "schemaVersion": 1,
        "backend": "agent_core",
        "policyProfile": policy_profile,
        "providers": providers,
        "extensions": [
            {
                "id": "epistemos.vault",
                "name": "Vault read/write",
                "enabled": true,
                "transport": "in-process",
                "description": "Security-scoped vault files only."
            },
            {
                "id": "epistemos.network_http",
                "name": "Network HTTP",
                "enabled": true,
                "transport": "in-process",
                "description": "Sandbox-safe HTTPS requests and hosted model APIs."
            },
            {
                "id": "epistemos.app_capabilities",
                "name": "Epistemos app capabilities",
                "enabled": true,
                "transport": "in-process",
                "description": "In-app PDF, search, and note context tools."
            }
        ],
        "proGatedCapabilities": [
            {
                "id": "goose.developer_builtin",
                "name": "Developer shell builtin",
                "reason": "The App Store sandbox cannot run arbitrary commands."
            },
            {
                "id": "mcp.local_stdio",
                "name": "Local stdio MCP",
                "reason": "Local stdio MCP launches child processes and is Pro-only."
            },
            {
                "id": "goose.subprocess",
                "name": "goose serve subprocess",
                "reason": "The MAS backend is in-process agent_core ACP."
            },
            {
                "id": "install_deps",
                "name": "Install dependencies",
                "reason": "Dependency installers execute local commands and are Pro-only."
            }
        ]
    })
    .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn catalog_is_json_and_contains_cloud_providers() {
        let value: serde_json::Value = serde_json::from_str(&goose_mas_acp_catalog_json()).unwrap();
        let providers = value["providers"].as_array().unwrap();
        assert!(!providers.is_empty());
        assert!(providers
            .iter()
            .any(|provider| provider["providerId"] == "anthropic"));
        assert_eq!(value["backend"], "agent_core");
    }

    #[test]
    fn catalog_excludes_process_spawning_capabilities() {
        let value: serde_json::Value = serde_json::from_str(&goose_mas_acp_catalog_json()).unwrap();
        for provider in value["providers"].as_array().unwrap() {
            assert_eq!(provider["category"], "model");
            assert_ne!(provider["providerId"], "amp-acp");
        }
        for extension in value["extensions"].as_array().unwrap() {
            let id = extension["id"].as_str().unwrap();
            assert!(!id.contains("stdio"));
            assert!(!id.contains("shell"));
            assert!(!id.contains("subprocess"));
        }
        assert!(value["proGatedCapabilities"]
            .as_array()
            .unwrap()
            .iter()
            .any(|capability| capability["id"] == "mcp.local_stdio"));
    }

    #[test]
    fn catalog_reports_build_policy_profile() {
        let value: serde_json::Value = serde_json::from_str(&goose_mas_acp_catalog_json()).unwrap();
        #[cfg(feature = "mas-build")]
        assert_eq!(value["policyProfile"], "mas_sandbox");
        #[cfg(all(feature = "pro-build", not(feature = "mas-build")))]
        assert_eq!(value["policyProfile"], "direct");
    }
}
