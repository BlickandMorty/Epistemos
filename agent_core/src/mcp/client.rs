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

use std::collections::HashMap;
use std::path::PathBuf;
use std::process::Stdio;

use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::process::{Child, Command};

use crate::types::ToolSchema;

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
    request_id: u64,
    tools: Vec<ToolSchema>,
}

impl McpServerConnection {
    async fn send_request(&mut self, method: &str, params: Value) -> Result<Value, String> {
        self.request_id += 1;
        let request = json!({
            "jsonrpc": "2.0",
            "id": self.request_id,
            "method": method,
            "params": params,
        });

        let stdin = self
            .process
            .stdin
            .as_mut()
            .ok_or("MCP server stdin unavailable")?;
        let line = serde_json::to_string(&request)
            .map_err(|e| format!("JSON serialization failed: {e}"))?;
        stdin
            .write_all(line.as_bytes())
            .await
            .map_err(|e| format!("Write to MCP server failed: {e}"))?;
        stdin
            .write_all(b"\n")
            .await
            .map_err(|e| format!("Write newline failed: {e}"))?;
        stdin
            .flush()
            .await
            .map_err(|e| format!("Flush failed: {e}"))?;

        // Read response
        let stdout = self
            .process
            .stdout
            .as_mut()
            .ok_or("MCP server stdout unavailable")?;
        let mut reader = BufReader::new(stdout);
        let mut line = String::new();
        reader
            .read_line(&mut line)
            .await
            .map_err(|e| format!("Read from MCP server failed: {e}"))?;

        let response: Value =
            serde_json::from_str(&line).map_err(|e| format!("MCP response parse failed: {e}"))?;

        if let Some(error) = response.get("error") {
            return Err(format!("MCP error: {}", error));
        }

        Ok(response["result"].clone())
    }
}

// MARK: - MCP Client

pub struct McpClient {
    servers: HashMap<String, McpServerConnection>,
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

        // After hardening, re-apply per-server config.env. Order
        // matters: hardening clears env first, config.env overrides
        // any allowlist values the user wants to customize (e.g. PATH
        // pointing to a vendored Node).
        for (k, v) in &config.env {
            cmd.env(k, v);
        }

        let child = cmd
            .spawn()
            .map_err(|e| format!("Failed to spawn MCP server '{}': {e}", config.name))?;

        let mut conn = McpServerConnection {
            process: child,
            request_id: 0,
            tools: Vec::new(),
        };

        // Initialize handshake
        let _init_result = conn
            .send_request(
                "initialize",
                json!({
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "clientInfo": {
                        "name": "epistemos",
                        "version": "1.0.0",
                    },
                }),
            )
            .await?;

        // Send initialized notification (no response expected)
        // For simplicity, skip the notification and go straight to tools/list

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
