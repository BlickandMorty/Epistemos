//! MCP Client — Model Context Protocol client for connecting to external tool servers
//!
//! Discovers and connects to MCP servers via stdio transport.
//! Server tools are dynamically registered in the ToolRegistry,
//! going through the same approval flow as built-in tools.
//!
//! Discovery sources:
//! - ~/.config/mcp/servers.json (global)
//! - .epistemos/mcp.json (per-project)
//!
//! Protocol: JSON-RPC 2.0 over stdio (line-delimited)
//!
//! Source: https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle
//! Source: https://modelcontextprotocol.io/specification/2025-11-25/schema

use std::collections::HashMap;
use std::path::PathBuf;
use std::process::Stdio;
use std::time::Duration;

use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::process::{Child, ChildStdin, ChildStdout, Command};

use crate::types::ToolSchema;

const MCP_PROTOCOL_VERSION: &str = "2025-11-25";
const MCP_REQUEST_TIMEOUT: Duration = Duration::from_secs(30);

// MARK: - MCP Server Configuration

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct McpServerConfig {
    pub name: String,
    pub command: String,
    #[serde(default)]
    pub args: Vec<String>,
    #[serde(default)]
    pub env: HashMap<String, String>,
}

// MARK: - MCP Server Connection

pub struct McpServerConnection {
    process: Child,
    stdin: ChildStdin,
    stdout: BufReader<ChildStdout>,
    request_id: u64,
    tools: Vec<ToolSchema>,
}

impl McpServerConnection {
    async fn write_message(&mut self, message: &Value) -> Result<(), String> {
        let line = serde_json::to_string(message)
            .map_err(|e| format!("JSON serialization failed: {e}"))?;
        self.stdin
            .write_all(line.as_bytes())
            .await
            .map_err(|e| format!("Write to MCP server failed: {e}"))?;
        self.stdin
            .write_all(b"\n")
            .await
            .map_err(|e| format!("Write newline failed: {e}"))?;
        self.stdin
            .flush()
            .await
            .map_err(|e| format!("Flush failed: {e}"))
    }

    async fn send_request(&mut self, method: &str, params: Value) -> Result<Value, String> {
        self.send_request_with_timeout(method, params, MCP_REQUEST_TIMEOUT)
            .await
    }

    async fn send_request_with_timeout(
        &mut self,
        method: &str,
        params: Value,
        timeout: Duration,
    ) -> Result<Value, String> {
        self.request_id += 1;
        let expected_id = self.request_id;
        let request = json!({
            "jsonrpc": "2.0",
            "id": expected_id,
            "method": method,
            "params": params,
        });

        self.write_message(&request).await?;

        match tokio::time::timeout(timeout, self.read_response_for_id(expected_id)).await {
            Ok(result) => result,
            Err(_) => {
                let timeout_label = format_timeout_duration(timeout);
                let _ = self
                    .send_notification(
                        "notifications/cancelled",
                        Some(json!({
                            "requestId": expected_id,
                            "reason": format!("request timed out after {timeout_label}"),
                        })),
                    )
                    .await;
                Err(format!(
                    "MCP request '{method}' timed out after {timeout_label} waiting for response id {expected_id}"
                ))
            }
        }
    }

    async fn read_response_for_id(&mut self, expected_id: u64) -> Result<Value, String> {
        let mut line = String::new();
        loop {
            line.clear();
            let bytes = self
                .stdout
                .read_line(&mut line)
                .await
                .map_err(|e| format!("Read from MCP server failed: {e}"))?;
            if bytes == 0 {
                return Err(format!(
                    "MCP server closed stdout while waiting for response id {expected_id}"
                ));
            }
            if line.trim().is_empty() {
                continue;
            }

            let response: Value = serde_json::from_str(&line)
                .map_err(|e| format!("MCP response parse failed: {e}"))?;
            if response.get("id").and_then(Value::as_u64) != Some(expected_id) {
                continue;
            }

            if let Some(error) = response.get("error") {
                return Err(format!("MCP error: {}", error));
            }

            return Ok(response.get("result").cloned().unwrap_or(Value::Null));
        }
    }

    async fn send_notification(
        &mut self,
        method: &str,
        params: Option<Value>,
    ) -> Result<(), String> {
        let notification = match params {
            Some(params) => json!({
                "jsonrpc": "2.0",
                "method": method,
                "params": params,
            }),
            None => json!({
                "jsonrpc": "2.0",
                "method": method,
            }),
        };
        self.write_message(&notification).await
    }
}

// MARK: - MCP Client

pub struct McpClient {
    servers: HashMap<String, McpServerConnection>,
}

impl Default for McpClient {
    fn default() -> Self {
        Self::new()
    }
}

impl McpClient {
    pub fn new() -> Self {
        Self {
            servers: HashMap::new(),
        }
    }

    /// Discovers MCP server configurations from standard locations.
    pub fn discover_servers() -> Vec<McpServerConfig> {
        let mut configs = Vec::new();

        // Global: ~/.config/mcp/servers.json
        if let Some(home) = std::env::var_os("HOME") {
            let global_path = PathBuf::from(home)
                .join(".config")
                .join("mcp")
                .join("servers.json");
            if let Ok(data) = std::fs::read_to_string(&global_path) {
                if let Ok(parsed) = serde_json::from_str::<HashMap<String, McpServerConfig>>(&data)
                {
                    configs.extend(parsed.into_values());
                }
            }
        }

        // Per-project: .epistemos/mcp.json
        let project_path = PathBuf::from(".epistemos/mcp.json");
        if let Ok(data) = std::fs::read_to_string(&project_path) {
            if let Ok(parsed) = serde_json::from_str::<HashMap<String, McpServerConfig>>(&data) {
                configs.extend(parsed.into_values());
            }
        }

        configs
    }

    /// Connects to an MCP server and fetches its tool list.
    pub async fn connect(&mut self, config: &McpServerConfig) -> Result<Vec<ToolSchema>, String> {
        // Spawn server process. MCP servers are user-installed binaries
        // executing arbitrary code in our process tree, so we harden
        // FIRST (env_clear + canonical allowlist + kill_on_drop +
        // process_group(0)) and then re-add the per-server `config.env`
        // explicitly. The user-controlled `config.env` is the trusted
        // allowlist; the parent process's env is NOT trusted.
        let mut cmd = Command::new(&config.command);
        crate::security::harden_cli_subprocess(&mut cmd);
        cmd.args(&config.args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::null());

        // After hardening, re-apply safe per-server config.env. Order
        // matters: hardening clears env first, config.env overrides
        // allowlist values the user wants to customize (e.g. PATH pointing
        // to a vendored Node). Dynamic-loader and interpreter-option
        // hijack keys stay blocked even when present in user config.
        for (k, v) in &config.env {
            if mcp_config_env_key_allowed(k) {
                cmd.env(k, v);
            }
        }

        let mut child = cmd
            .spawn()
            .map_err(|e| format!("Failed to spawn MCP server '{}': {e}", config.name))?;
        let stdin = child
            .stdin
            .take()
            .ok_or_else(|| format!("MCP server '{}' stdin unavailable", config.name))?;
        let stdout = child
            .stdout
            .take()
            .ok_or_else(|| format!("MCP server '{}' stdout unavailable", config.name))?;

        let mut conn = McpServerConnection {
            process: child,
            stdin,
            stdout: BufReader::new(stdout),
            request_id: 0,
            tools: Vec::new(),
        };

        // Initialize handshake
        let _init_result = conn
            .send_request(
                "initialize",
                json!({
                    "protocolVersion": MCP_PROTOCOL_VERSION,
                    "capabilities": {},
                    "clientInfo": {
                        "name": "epistemos",
                        "version": "1.0.0",
                    },
                }),
            )
            .await?;

        conn.send_notification("notifications/initialized", None)
            .await?;

        // Fetch tool list
        let tools_result = conn.send_request("tools/list", json!({})).await?;

        let tools: Vec<ToolSchema> = if let Some(tools_array) = tools_result["tools"].as_array() {
            tools_array
                .iter()
                .filter_map(|t| {
                    let name = t["name"].as_str()?;
                    let description = t["description"].as_str().unwrap_or("");
                    let params = t["inputSchema"].clone();

                    Some(ToolSchema {
                        name: format!("mcp_{}/{}", config.name, name),
                        description: format!("[MCP: {}] {}", config.name, description),
                        parameters: params,
                    })
                })
                .collect()
        } else {
            Vec::new()
        };

        conn.tools = tools.clone();
        self.servers.insert(config.name.clone(), conn);

        Ok(tools)
    }

    /// Calls a tool on a connected MCP server.
    pub async fn call_tool(
        &mut self,
        server_name: &str,
        tool_name: &str,
        arguments: Value,
    ) -> Result<String, String> {
        let conn = self
            .servers
            .get_mut(server_name)
            .ok_or_else(|| format!("MCP server '{}' not connected", server_name))?;

        let result = conn
            .send_request(
                "tools/call",
                json!({
                    "name": tool_name,
                    "arguments": arguments,
                }),
            )
            .await?;

        // Extract text content from MCP tool result
        if let Some(content) = result["content"].as_array() {
            let texts: Vec<&str> = content.iter().filter_map(|c| c["text"].as_str()).collect();
            Ok(texts.join("\n"))
        } else {
            Ok(result.to_string())
        }
    }

    /// Returns all discovered tool schemas from connected servers.
    pub fn all_tools(&self) -> Vec<ToolSchema> {
        self.servers
            .values()
            .flat_map(|conn| conn.tools.iter().cloned())
            .collect()
    }

    /// Disconnects all MCP servers.
    pub async fn disconnect_all(&mut self) {
        for (_, mut conn) in self.servers.drain() {
            let _ = conn.process.kill().await;
        }
    }
}

fn mcp_config_env_key_allowed(key: &str) -> bool {
    if key.is_empty() || key.contains('=') || key.contains('\0') {
        return false;
    }
    !crate::security::SUBPROCESS_DENYLIST
        .iter()
        .any(|deny| deny.eq_ignore_ascii_case(key))
}

fn format_timeout_duration(timeout: Duration) -> String {
    if timeout.as_millis() < 1_000 {
        format!("{}ms", timeout.as_millis())
    } else if timeout.subsec_millis() == 0 {
        format!("{}s", timeout.as_secs())
    } else {
        format!("{:.3}s", timeout.as_secs_f64())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mcp_config_env_filter_blocks_loader_and_interpreter_hijacks() {
        assert!(!mcp_config_env_key_allowed("DYLD_INSERT_LIBRARIES"));
        assert!(!mcp_config_env_key_allowed("dyld_library_path"));
        assert!(!mcp_config_env_key_allowed("NODE_OPTIONS"));
        assert!(!mcp_config_env_key_allowed("PYTHONPATH"));
        assert!(!mcp_config_env_key_allowed(""));
        assert!(!mcp_config_env_key_allowed("BAD=KEY"));
    }

    #[test]
    fn mcp_config_env_filter_blocks_process_wide_provider_credentials() {
        assert!(!mcp_config_env_key_allowed("ANTHROPIC_API_KEY"));
        assert!(!mcp_config_env_key_allowed("OPENAI_API_KEY"));
        assert!(!mcp_config_env_key_allowed("TOGETHER_API_KEY"));
    }

    #[test]
    fn mcp_config_env_filter_allows_nonsecret_runtime_keys() {
        assert!(mcp_config_env_key_allowed("PATH"));
        assert!(mcp_config_env_key_allowed("MCP_SERVER_MODE"));
    }

    #[test]
    fn stdio_mcp_initialize_uses_current_protocol_version() {
        let source = include_str!("client.rs");
        assert!(
            source.contains("const MCP_PROTOCOL_VERSION: &str = \"2025-11-25\""),
            "stdio MCP initialize should advertise the current MCP protocol revision"
        );
        let retired_version = ["2024", "11", "05"].join("-");
        assert!(
            !source.contains(&format!("\"protocolVersion\": \"{retired_version}\"")),
            "stdio MCP initialize must not stay pinned to the retired 2024-11-05 protocol"
        );
    }

    #[test]
    fn stdio_mcp_sends_initialized_notification_before_tools_list() {
        let source = include_str!("client.rs");
        let initialized = source
            .find("send_notification(\"notifications/initialized\"")
            .expect("stdio MCP client should send initialized notification");
        let tools_list = source
            .find("send_request(\"tools/list\"")
            .expect("stdio MCP client should request tools/list");
        assert!(
            initialized < tools_list,
            "initialized notification must be sent before normal tools/list operation"
        );
        let skipped_notification = ["skip", "the", "notification"].join(" ");
        assert!(
            !source.contains(&skipped_notification),
            "stdio MCP client should not document skipping the required initialized notification"
        );
    }

    #[tokio::test]
    async fn stdio_mcp_skips_notifications_while_waiting_for_matching_response() {
        let dir = tempfile::tempdir().expect("tempdir");
        let script_path = dir.path().join("mcp_fixture.sh");
        std::fs::write(
            &script_path,
            r#"#!/bin/sh
IFS= read -r init_request
printf '%s\n' '{"jsonrpc":"2.0","method":"notifications/message","params":{"level":"info","data":"booting"}}'
printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-11-25","capabilities":{},"serverInfo":{"name":"fixture","version":"1.0"}}}'
IFS= read -r initialized_notification
IFS= read -r tools_request
printf '%s\n' '{"jsonrpc":"2.0","method":"notifications/progress","params":{"progress":1}}'
printf '%s\n' '{"jsonrpc":"2.0","id":2,"result":{"tools":[{"name":"echo","description":"Echo","inputSchema":{"type":"object","properties":{}}}]}}'
IFS= read -r call_request
printf '%s\n' '{"jsonrpc":"2.0","method":"notifications/message","params":{"level":"debug","data":"calling"}}'
printf '%s\n' '{"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"text","text":"ok"}]}}'
"#,
        )
        .expect("write script");

        let config = McpServerConfig {
            name: "fixture".to_string(),
            command: "/bin/sh".to_string(),
            args: vec![script_path.display().to_string()],
            env: HashMap::new(),
        };

        let mut client = McpClient::new();
        let tools = client.connect(&config).await.expect("connect");
        assert_eq!(tools.len(), 1);
        assert_eq!(tools[0].name, "mcp_fixture/echo");

        let result = client
            .call_tool("fixture", "echo", json!({"message": "hello"}))
            .await
            .expect("call tool");
        assert_eq!(result, "ok");
        client.disconnect_all().await;
    }

    #[tokio::test]
    async fn stdio_mcp_request_timeout_returns_error_instead_of_hanging() {
        let dir = tempfile::tempdir().expect("tempdir");
        let script_path = dir.path().join("silent_mcp_fixture.sh");
        std::fs::write(
            &script_path,
            r#"#!/bin/sh
IFS= read -r request
sleep 1
"#,
        )
        .expect("write script");

        let mut child = Command::new("/bin/sh")
            .arg(script_path)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .spawn()
            .expect("spawn fixture");
        let stdin = child.stdin.take().expect("stdin");
        let stdout = child.stdout.take().expect("stdout");
        let mut conn = McpServerConnection {
            process: child,
            stdin,
            stdout: BufReader::new(stdout),
            request_id: 0,
            tools: Vec::new(),
        };

        let err = conn
            .send_request_with_timeout(
                "initialize",
                json!({"protocolVersion": MCP_PROTOCOL_VERSION}),
                std::time::Duration::from_millis(20),
            )
            .await
            .expect_err("silent MCP server should time out");

        assert!(
            err.contains("timed out after 20ms"),
            "timeout error should explain the MCP request timeout, got {err}"
        );
        let _ = conn.process.kill().await;
    }
}
