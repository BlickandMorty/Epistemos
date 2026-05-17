//! URL-based MCP server discovery.
//!
//! Reads a list of `{name, url, authorization_token_env?}` MCP servers
//! from a JSON config file and returns them as
//! [`crate::agent_loop::McpServerConfig`] values. The
//! Claude provider already forwards `AgentConfig.mcp_servers` into the
//! Anthropic `mcp_servers` API parameter, so every tool those servers
//! expose becomes available to the model without any per-tool code on the
//! Rust or Swift side.
//!
//! This is the "Tunnel B.1" path from Claude's 2026-04-22 capability-tunnel
//! handoff: user adds an entry to `~/.config/mcp/url_servers.json`, and
//! the next Agent-mode turn sees those tools. No registry wiring, no
//! approval plumbing — Anthropic handles the connection remotely.
//!
//! File format (`~/.config/mcp/url_servers.json` or `.epistemos/mcp_url_servers.json`):
//!
//! ```json
//! [
//!   { "name": "github", "url": "https://mcp.example.com/github" },
//!   { "name": "linear", "url": "https://mcp.example.com/linear",
//!     "authorization_token_env": "LINEAR_MCP_TOKEN" }
//! ]
//! ```
//!
//! Silent failures are intentional: a missing or malformed file returns an
//! empty list so a fresh install just has zero extra servers.
//!
//! Stdio MCP servers (spawned as local subprocesses) are handled by
//! [`crate::mcp::client::McpClient::discover_servers`] separately and
//! deliberately — those tools get registered into the local
//! [`crate::tools::registry::ToolRegistry`] instead of forwarded to the
//! remote API.

use std::path::PathBuf;

use serde::{Deserialize, Serialize};

use crate::agent_loop::McpServerConfig;

#[derive(Debug, Clone, Serialize, Deserialize)]
struct UrlMcpServerEntry {
    name: String,
    url: String,
    #[serde(default)]
    authorization_token: Option<String>,
    #[serde(default)]
    authorization_token_env: Option<String>,
}

/// Returns every URL-based MCP server configured on this machine, from
/// both the global location (`~/.config/mcp/url_servers.json`) and the
/// per-project location (`.epistemos/mcp_url_servers.json`). The per-
/// project list appends to the global list; duplicates are deduplicated
/// by `name` with per-project winning.
pub fn discover_url_mcp_servers() -> Vec<McpServerConfig> {
    let mut seen: std::collections::HashSet<String> = std::collections::HashSet::new();
    let mut result: Vec<McpServerConfig> = Vec::new();

    // Per-project wins over global, so gather it first.
    for path in [project_config_path(), global_config_path()]
        .into_iter()
        .flatten()
    {
        for entry in load_entries(&path) {
            if let Some(config) = entry_to_config(entry) {
                if seen.insert(config.name.clone()) {
                    result.push(config);
                }
            }
        }
    }

    result
}

fn project_config_path() -> Option<PathBuf> {
    let cwd = std::env::current_dir().ok()?;
    Some(cwd.join(".epistemos").join("mcp_url_servers.json"))
}

fn global_config_path() -> Option<PathBuf> {
    let home = std::env::var_os("HOME")?;
    Some(
        PathBuf::from(home)
            .join(".config")
            .join("mcp")
            .join("url_servers.json"),
    )
}

fn load_entries(path: &std::path::Path) -> Vec<UrlMcpServerEntry> {
    let raw = match std::fs::read_to_string(path) {
        Ok(data) => data,
        Err(_) => return Vec::new(),
    };
    serde_json::from_str::<Vec<UrlMcpServerEntry>>(&raw).unwrap_or_default()
}

fn entry_to_config(entry: UrlMcpServerEntry) -> Option<McpServerConfig> {
    let url = entry.url.trim().to_string();
    if !url.starts_with("https://") {
        return None;
    }

    let authorization_token = entry
        .authorization_token_env
        .as_deref()
        .filter(|key| auth_env_key_allowed(key))
        .and_then(|key| std::env::var(key).ok())
        .or(entry.authorization_token)
        .map(|token| token.trim().to_string())
        .filter(|token| !token.is_empty());

    Some(McpServerConfig {
        name: entry.name,
        url,
        authorization_token,
    })
}

fn auth_env_key_allowed(key: &str) -> bool {
    !key.is_empty() && !key.contains('=') && !key.contains('\0')
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    #[test]
    fn load_entries_returns_empty_on_missing_file() {
        let missing = PathBuf::from("/nonexistent/path/that/should/not/exist.json");
        assert!(load_entries(&missing).is_empty());
    }

    #[test]
    fn load_entries_returns_empty_on_malformed_file() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("bad.json");
        let mut file = std::fs::File::create(&path).expect("create");
        file.write_all(b"{ not json").expect("write");
        assert!(load_entries(&path).is_empty());
    }

    #[test]
    fn load_entries_parses_valid_list() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("ok.json");
        let mut file = std::fs::File::create(&path).expect("create");
        file.write_all(
            br#"[{"name":"github","url":"https://example.com/gh"},{"name":"linear","url":"https://example.com/lin"}]"#,
        )
        .expect("write");
        let entries = load_entries(&path);
        assert_eq!(entries.len(), 2);
        assert_eq!(entries[0].name, "github");
        assert_eq!(entries[1].url, "https://example.com/lin");
    }

    #[test]
    fn entry_to_config_resolves_authorization_token_env() {
        let key = "EPISTEMOS_TEST_PRIVATE_MCP_TOKEN";
        let saved = std::env::var(key).ok();
        std::env::set_var(key, "env-token");

        let config = entry_to_config(UrlMcpServerEntry {
            name: "private".to_string(),
            url: "https://mcp.example.com/private".to_string(),
            authorization_token: None,
            authorization_token_env: Some(key.to_string()),
        })
        .expect("valid https URL MCP server");

        assert_eq!(config.authorization_token.as_deref(), Some("env-token"));

        match saved {
            Some(value) => std::env::set_var(key, value),
            None => std::env::remove_var(key),
        }
    }

    #[test]
    fn entry_to_config_rejects_non_https_url() {
        let config = entry_to_config(UrlMcpServerEntry {
            name: "local".to_string(),
            url: "http://127.0.0.1:3000/mcp".to_string(),
            authorization_token: None,
            authorization_token_env: None,
        });

        assert!(config.is_none());
    }
}
