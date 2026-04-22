//! Stdio MCP server registry wiring — Tunnel B.2.
//!
//! Discovers local MCP servers configured in
//! `~/.config/mcp/servers.json` (the `{ name, command, args, env }`
//! shape) and `.epistemos/mcp.json` via
//! [`crate::mcp::client::McpClient::discover_servers`], spawns each,
//! calls `initialize` + `tools/list`, and registers every advertised
//! tool into the local [`ToolRegistry`] with a handler that forwards
//! calls back over the stdio connection.
//!
//! Lifetime: the shared [`McpClient`] is kept alive inside each
//! registered handler via `Arc<tokio::sync::Mutex<McpClient>>`, so the
//! spawned child processes live as long as any tool from them is
//! still reachable. When the registry drops, all clones drop, the
//! client drops, and tokio reaps the children.
//!
//! Failure mode: connection errors are logged and skipped. A bad entry
//! in `servers.json` never prevents the rest of the registry from
//! coming up.

use std::sync::Arc;

use async_trait::async_trait;
use serde_json::Value;
use tokio::sync::Mutex;
use tracing::warn;

use crate::mcp::client::{McpClient, McpServerConfig};
use crate::tools::registry::{
    is_reserved_tool_name, is_user_visible_tool, RegisteredTool, RiskLevel, ToolError,
    ToolHandler, ToolRegistry, ToolTier,
};

/// Handler that forwards a tool call to an MCP server over stdio.
///
/// The server's tool name may differ from the tool name we register
/// locally (we prefix with `mcp_<server>/` to avoid collisions with
/// built-in tool names), so we keep both.
pub struct StdioMcpToolHandler {
    client: Arc<Mutex<McpClient>>,
    server_name: String,
    remote_tool_name: String,
}

impl StdioMcpToolHandler {
    pub fn new(
        client: Arc<Mutex<McpClient>>,
        server_name: String,
        remote_tool_name: String,
    ) -> Self {
        Self {
            client,
            server_name,
            remote_tool_name,
        }
    }
}

#[async_trait]
impl ToolHandler for StdioMcpToolHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let mut client = self.client.lock().await;
        client
            .call_tool(&self.server_name, &self.remote_tool_name, input.clone())
            .await
            .map_err(ToolError::ExecutionFailed)
    }
}

/// Discover every stdio MCP server the user has configured, connect to
/// it, and register each advertised tool into the provided
/// [`ToolRegistry`] at [`ToolTier::Agent`].
///
/// Returns the number of tools that were successfully registered. Log
/// entries are emitted for every connection failure.
pub async fn register_discovered_stdio_mcp_tools(registry: &mut ToolRegistry) -> usize {
    let configs = McpClient::discover_servers();
    if configs.is_empty() {
        return 0;
    }

    let client = Arc::new(Mutex::new(McpClient::new()));
    let mut registered = 0usize;

    for config in configs {
        match connect_and_register(&client, &config, registry).await {
            Ok(count) => registered += count,
            Err(error) => warn!(
                server = %config.name,
                error = %error,
                "stdio MCP server connect failed; skipping"
            ),
        }
    }

    registered
}

async fn connect_and_register(
    client: &Arc<Mutex<McpClient>>,
    config: &McpServerConfig,
    registry: &mut ToolRegistry,
) -> Result<usize, String> {
    let tools = {
        let mut guard = client.lock().await;
        guard.connect(config).await?
    };

    let mut count = 0usize;
    for tool in tools {
        // Skip if the prefixed name is reserved or already registered.
        if is_reserved_tool_name(&tool.name) {
            warn!(
                server = %config.name,
                tool = %tool.name,
                "stdio MCP tool name collides with a reserved built-in; skipping"
            );
            continue;
        }
        if registry.contains_tool(&tool.name) {
            warn!(
                server = %config.name,
                tool = %tool.name,
                "stdio MCP tool name already registered; skipping"
            );
            continue;
        }
        if !is_user_visible_tool(&tool.name) {
            continue;
        }

        // Derive the remote tool name by stripping the `mcp_<server>/`
        // prefix that `McpClient::connect` added to the schema.
        let remote_tool_name = tool
            .name
            .strip_prefix(&format!("mcp_{}/", config.name))
            .unwrap_or(&tool.name)
            .to_string();

        let handler = StdioMcpToolHandler::new(
            client.clone(),
            config.name.clone(),
            remote_tool_name,
        );
        registry.register(RegisteredTool {
            name: tool.name,
            description: tool.description,
            parameters: tool.parameters,
            handler: Box::new(handler),
            risk_level: RiskLevel::Modification,
            tier: ToolTier::Agent,
        });
        count += 1;
    }

    Ok(count)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn stdio_mcp_tool_handler_stores_names_verbatim() {
        // Handler construction must NOT mutate or re-prefix the tool
        // names; the registry registers the prefixed name and the
        // handler forwards the unprefixed `remote_tool_name` over the
        // stdio connection. If this invariant breaks, tool calls will
        // silently target the wrong tool on the server side.
        let client = Arc::new(Mutex::new(McpClient::new()));
        let handler = StdioMcpToolHandler::new(
            client.clone(),
            "example_server".to_string(),
            "do_thing".to_string(),
        );
        assert_eq!(handler.server_name, "example_server");
        assert_eq!(handler.remote_tool_name, "do_thing");
    }
}
