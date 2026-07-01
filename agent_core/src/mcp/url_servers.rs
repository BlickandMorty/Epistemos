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

use std::io::Read;
use std::os::unix::fs::OpenOptionsExt;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

use crate::agent_loop::McpServerConfig;

const MAX_CONFIG_BYTES: usize = 256 * 1024;

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

fn load_entries(path: &Path) -> Vec<UrlMcpServerEntry> {
    let metadata = match std::fs::symlink_metadata(path) {
        Ok(metadata) => metadata,
        Err(_) => return Vec::new(),
    };
    let file_type = metadata.file_type();
    if file_type.is_symlink() || !file_type.is_file() || metadata.len() > MAX_CONFIG_BYTES as u64 {
        return Vec::new();
    }

    let file = match std::fs::OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC)
        .open(path)
    {
        Ok(file) => file,
        Err(_) => return Vec::new(),
    };

    let mut raw = String::new();
    let mut limited = file.take(MAX_CONFIG_BYTES as u64 + 1);
    if limited.read_to_string(&mut raw).is_err() || raw.len() > MAX_CONFIG_BYTES {
        return Vec::new();
    }
    serde_json::from_str::<Vec<UrlMcpServerEntry>>(&raw).unwrap_or_default()
}

fn entry_to_config(entry: UrlMcpServerEntry) -> Option<McpServerConfig> {
    let name = entry.name.trim().to_string();
    if name.is_empty() {
        return None;
    }

    let url = validated_https_url(&entry.url)?;
    if entry
        .authorization_token
        .as_deref()
        .map(str::trim)
        .is_some_and(|token| !token.is_empty())
    {
        return None;
    }

    let authorization_token_env = entry
        .authorization_token_env
        .as_deref()
        .map(str::trim)
        .filter(|key| !key.is_empty());
    if authorization_token_env.is_some_and(|key| !auth_env_key_allowed(key)) {
        return None;
    }

    let authorization_token = authorization_token_env
        .and_then(|key| std::env::var(key).ok())
        .map(|token| token.trim().to_string())
        .filter(|token| !token.is_empty());

    Some(McpServerConfig {
        name,
        url,
        authorization_token,
    })
}

fn validated_https_url(raw: &str) -> Option<String> {
    let url = raw.trim();
    let scheme = url.get(..8)?;
    if !scheme.eq_ignore_ascii_case("https://") {
        return None;
    }
    let authority_and_path = url.get(8..)?;
    if matches!(
        authority_and_path.chars().next(),
        None | Some('/' | '?' | '#')
    ) {
        return None;
    }
    let parsed = reqwest::Url::parse(url).ok()?;
    if parsed.scheme() != "https"
        || parsed.host_str().unwrap_or_default().is_empty()
        || !parsed.username().is_empty()
        || parsed.password().is_some()
        || parsed.query().is_some()
        || parsed.fragment().is_some()
    {
        return None;
    }
    Some(url.to_string())
}

fn auth_env_key_allowed(key: &str) -> bool {
    let mut chars = key.chars();
    match chars.next() {
        Some(first) if first == '_' || first.is_ascii_alphabetic() => {}
        _ => return false,
    }
    chars.all(|ch| ch == '_' || ch.is_ascii_alphanumeric())
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

    #[test]
    fn entry_to_config_rejects_secret_bearing_urls_and_inline_tokens() {
        for url in [
            "https://token@example.com/mcp",
            "https://example.com/mcp?token=abc123",
            "https://example.com/mcp#token=abc123",
            "https:///mcp",
        ] {
            let config = entry_to_config(UrlMcpServerEntry {
                name: "bad".to_string(),
                url: url.to_string(),
                authorization_token: None,
                authorization_token_env: None,
            });
            assert!(config.is_none());
        }

        let inline_token_config = entry_to_config(UrlMcpServerEntry {
            name: "inline".to_string(),
            url: "https://example.com/mcp".to_string(),
            authorization_token: Some("secret".to_string()),
            authorization_token_env: None,
        });
        assert!(inline_token_config.is_none());

        let invalid_auth_env_config = entry_to_config(UrlMcpServerEntry {
            name: "invalid-auth-env".to_string(),
            url: "https://example.com/mcp".to_string(),
            authorization_token: None,
            authorization_token_env: Some("TOKEN-NAME".to_string()),
        });
        assert!(invalid_auth_env_config.is_none());
    }

    #[test]
    fn auth_env_key_shape_matches_process_env_keys() {
        assert!(auth_env_key_allowed("_TOKEN_9"));
        for key in ["1TOKEN", "TOKEN NAME", "TOKEN-NAME", "TOKEN\nNAME", "TØKEN"] {
            assert!(!auth_env_key_allowed(key));
        }
    }
}
