use std::collections::HashMap;
use std::sync::Arc;

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use crate::storage::vault::{VaultBackend, VaultError};
use crate::types::ToolSchema;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum RiskLevel {
    ReadOnly,
    Modification,
    Destructive,
}

impl RiskLevel {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::ReadOnly => "read_only",
            Self::Modification => "modification",
            Self::Destructive => "destructive",
        }
    }
}

pub struct RegisteredTool {
    pub name: String,
    pub description: String,
    pub parameters: Value,
    pub handler: Box<dyn ToolHandler>,
    pub risk_level: RiskLevel,
}

#[async_trait]
pub trait ToolHandler: Send + Sync {
    async fn execute(&self, input: &Value) -> Result<String, ToolError>;
}

#[derive(Debug, thiserror::Error)]
pub enum ToolError {
    #[error("invalid arguments: {0}")]
    InvalidArguments(String),
    #[error("execution failed: {0}")]
    ExecutionFailed(String),
    #[error("not found: {0}")]
    NotFound(String),
    #[error("permission denied")]
    PermissionDenied,
}

pub struct ToolRegistry {
    tools: HashMap<String, RegisteredTool>,
    vault: Arc<dyn VaultBackend>,
    enable_bash: bool,
}

impl ToolRegistry {
    pub fn new(vault: Arc<dyn VaultBackend>) -> Self {
        let mut registry = Self {
            tools: HashMap::new(),
            vault,
            enable_bash: true,
        };
        registry.register_default_tools();
        registry
    }

    pub fn with_bash_enabled(vault: Arc<dyn VaultBackend>, enable_bash: bool) -> Self {
        let mut registry = Self {
            tools: HashMap::new(),
            vault,
            enable_bash,
        };
        registry.register_default_tools();
        registry
    }

    pub fn register(&mut self, tool: RegisteredTool) {
        self.tools.insert(tool.name.clone(), tool);
    }

    pub fn get_definitions(&self) -> Vec<ToolSchema> {
        self.tools
            .values()
            .map(|tool| ToolSchema {
                name: tool.name.clone(),
                description: tool.description.clone(),
                parameters: tool.parameters.clone(),
            })
            .collect()
    }

    pub fn get_risk_level(&self, name: &str) -> RiskLevel {
        self.tools
            .get(name)
            .map(|tool| tool.risk_level.clone())
            .unwrap_or(RiskLevel::ReadOnly)
    }

    pub async fn execute(&self, name: &str, input: &Value) -> Result<String, ToolError> {
        let tool = self
            .tools
            .get(name)
            .ok_or_else(|| ToolError::InvalidArguments(format!("unknown tool: {name}")))?;
        tool.handler.execute(input).await
    }

    pub async fn vault_search(&self, query: &str, limit: usize) -> Result<Vec<String>, ToolError> {
        self.vault
            .search(query, limit)
            .await
            .map_err(map_vault_error)
    }

    fn register_default_tools(&mut self) {
        self.register_vault_search();
        self.register_vault_read();
        self.register_vault_write();
        self.register_think_tool();
        self.register_chunk_reduce();
        self.register_workspace_search();
        if self.enable_bash {
            self.register_bash_execute();
        }
        self.register_web_search();
    }

    fn register_think_tool(&mut self) {
        use crate::tools::think;
        self.register(RegisteredTool {
            name: think::THINK_TOOL_NAME.to_string(),
            description: think::THINK_TOOL_DESCRIPTION.to_string(),
            parameters: serde_json::from_str(think::THINK_TOOL_SCHEMA).unwrap_or_default(),
            handler: Box::new(ThinkHandler),
            risk_level: RiskLevel::ReadOnly,
        });
    }

    fn register_vault_search(&mut self) {
        let vault = Arc::clone(&self.vault);
        self.register(RegisteredTool {
            name: "vault_search".to_string(),
            description: "Hybrid semantic and keyword search across the personal knowledge vault."
                .to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "query": { "type": "string", "description": "Natural language search query" },
                    "limit": {
                        "type": "integer",
                        "description": "Maximum results to return",
                        "default": 5,
                        "minimum": 1,
                        "maximum": 20
                    },
                    "tags": {
                        "type": "array",
                        "items": { "type": "string" },
                        "description": "Optional tag filter"
                    }
                },
                "required": ["query"]
            }),
            handler: Box::new(VaultSearchHandler { vault }),
            risk_level: RiskLevel::ReadOnly,
        });
    }

    fn register_vault_read(&mut self) {
        let vault = Arc::clone(&self.vault);
        self.register(RegisteredTool {
            name: "vault_read".to_string(),
            description: "Read the full content of a note by its vault-relative path.".to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "path": { "type": "string", "description": "Vault-relative note path" }
                },
                "required": ["path"]
            }),
            handler: Box::new(VaultReadHandler { vault }),
            risk_level: RiskLevel::ReadOnly,
        });
    }

    fn register_vault_write(&mut self) {
        let vault = Arc::clone(&self.vault);
        self.register(RegisteredTool {
            name: "vault_write".to_string(),
            description: "Create or update a note in the vault.".to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "path": { "type": "string", "description": "Vault-relative note path" },
                    "content": { "type": "string", "description": "Full markdown content" },
                    "tags": {
                        "type": "array",
                        "items": { "type": "string" },
                        "description": "Tags to inject into frontmatter"
                    },
                    "append": {
                        "type": "boolean",
                        "default": false,
                        "description": "Append instead of overwrite"
                    }
                },
                "required": ["path", "content"]
            }),
            handler: Box::new(VaultWriteHandler { vault }),
            risk_level: RiskLevel::Modification,
        });
    }

    fn register_bash_execute(&mut self) {
        self.register(RegisteredTool {
            name: "bash_execute".to_string(),
            description: "Execute a bash command with a timeout and a conservative security blocklist."
                .to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "command": { "type": "string", "description": "Bash command to execute" },
                    "working_dir": { "type": "string", "description": "Optional working directory" },
                    "timeout_seconds": {
                        "type": "integer",
                        "default": 30,
                        "maximum": 120,
                        "description": "Timeout for the command"
                    }
                },
                "required": ["command"]
            }),
            handler: Box::new(BashExecuteHandler),
            risk_level: RiskLevel::Destructive,
        });
    }

    fn register_web_search(&mut self) {
        self.register(RegisteredTool {
            name: "web_search".to_string(),
            description: "Search the web for current information using a lightweight HTTP API."
                .to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "query": { "type": "string", "description": "Search query" },
                    "limit": {
                        "type": "integer",
                        "default": 5,
                        "description": "Number of results to summarize"
                    }
                },
                "required": ["query"]
            }),
            handler: Box::new(WebSearchHandler::new()),
            risk_level: RiskLevel::ReadOnly,
        });
    }

    fn register_chunk_reduce(&mut self) {
        use crate::tools::chunk_reduce;
        self.register(RegisteredTool {
            name: chunk_reduce::CHUNK_REDUCE_TOOL_NAME.to_string(),
            description: chunk_reduce::CHUNK_REDUCE_TOOL_DESCRIPTION.to_string(),
            parameters: serde_json::from_str(chunk_reduce::CHUNK_REDUCE_TOOL_SCHEMA)
                .unwrap_or_default(),
            handler: Box::new(chunk_reduce::ChunkReduceHandler),
            risk_level: RiskLevel::ReadOnly,
        });
    }

    fn register_workspace_search(&mut self) {
        use crate::tools::workspace_search;
        self.register(RegisteredTool {
            name: workspace_search::WORKSPACE_SEARCH_TOOL_NAME.to_string(),
            description: workspace_search::WORKSPACE_SEARCH_TOOL_DESCRIPTION.to_string(),
            parameters: serde_json::from_str(workspace_search::WORKSPACE_SEARCH_TOOL_SCHEMA)
                .unwrap_or_default(),
            handler: Box::new(workspace_search::WorkspaceSearchHandler),
            risk_level: RiskLevel::ReadOnly,
        });
        // Token Savior: AST-level symbol tools (replace grep/cat for codebase navigation)
        self.register_token_savior_tools();
    }

    fn register_token_savior_tools(&mut self) {
        use crate::tools::workspace_search;

        self.register(RegisteredTool {
            name: workspace_search::FIND_SYMBOL_TOOL_NAME.to_string(),
            description: workspace_search::FIND_SYMBOL_TOOL_DESCRIPTION.to_string(),
            parameters: serde_json::from_str(workspace_search::FIND_SYMBOL_TOOL_SCHEMA)
                .unwrap_or_default(),
            handler: Box::new(workspace_search::FindSymbolHandler),
            risk_level: RiskLevel::ReadOnly,
        });

        self.register(RegisteredTool {
            name: workspace_search::GET_FUNCTION_SOURCE_TOOL_NAME.to_string(),
            description: workspace_search::GET_FUNCTION_SOURCE_TOOL_DESCRIPTION.to_string(),
            parameters: serde_json::from_str(workspace_search::GET_FUNCTION_SOURCE_TOOL_SCHEMA)
                .unwrap_or_default(),
            handler: Box::new(workspace_search::GetFunctionSourceHandler),
            risk_level: RiskLevel::ReadOnly,
        });

        self.register(RegisteredTool {
            name: workspace_search::GET_DEPENDENCIES_TOOL_NAME.to_string(),
            description: workspace_search::GET_DEPENDENCIES_TOOL_DESCRIPTION.to_string(),
            parameters: serde_json::from_str(workspace_search::GET_DEPENDENCIES_TOOL_SCHEMA)
                .unwrap_or_default(),
            handler: Box::new(workspace_search::GetDependenciesHandler),
            risk_level: RiskLevel::ReadOnly,
        });

        self.register(RegisteredTool {
            name: workspace_search::GET_DEPENDENTS_TOOL_NAME.to_string(),
            description: workspace_search::GET_DEPENDENTS_TOOL_DESCRIPTION.to_string(),
            parameters: serde_json::from_str(workspace_search::GET_DEPENDENTS_TOOL_SCHEMA)
                .unwrap_or_default(),
            handler: Box::new(workspace_search::GetDependentsHandler),
            risk_level: RiskLevel::ReadOnly,
        });

        self.register(RegisteredTool {
            name: workspace_search::GET_CHANGE_IMPACT_TOOL_NAME.to_string(),
            description: workspace_search::GET_CHANGE_IMPACT_TOOL_DESCRIPTION.to_string(),
            parameters: serde_json::from_str(workspace_search::GET_CHANGE_IMPACT_TOOL_SCHEMA)
                .unwrap_or_default(),
            handler: Box::new(workspace_search::GetChangeImpactHandler),
            risk_level: RiskLevel::ReadOnly,
        });
    }
}

struct VaultSearchHandler {
    vault: Arc<dyn VaultBackend>,
}

#[async_trait]
impl ToolHandler for VaultSearchHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let query = input
            .get("query")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("query required".to_string()))?;
        let limit = input.get("limit").and_then(Value::as_u64).unwrap_or(5) as usize;
        let tags: Vec<String> = input
            .get("tags")
            .and_then(Value::as_array)
            .map(|items| {
                items
                    .iter()
                    .filter_map(Value::as_str)
                    .map(ToString::to_string)
                    .collect()
            })
            .unwrap_or_default();

        let results = self
            .vault
            .hybrid_search(query, limit.min(20).max(1), &tags)
            .await
            .map_err(map_vault_error)?;

        if results.is_empty() {
            return Ok("No matching notes found in vault.".to_string());
        }

        Ok(results
            .iter()
            .enumerate()
            .map(|(index, result)| {
                format!(
                    "{}. **{}** (score: {:.2})\n{}",
                    index + 1,
                    result.path,
                    result.score,
                    result.excerpt
                )
            })
            .collect::<Vec<_>>()
            .join("\n\n"))
    }
}

struct VaultReadHandler {
    vault: Arc<dyn VaultBackend>,
}

#[async_trait]
impl ToolHandler for VaultReadHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let path = input
            .get("path")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("path required".to_string()))?;
        self.vault.read(path).await.map_err(map_vault_error)
    }
}

struct VaultWriteHandler {
    vault: Arc<dyn VaultBackend>,
}

#[async_trait]
impl ToolHandler for VaultWriteHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let path = input
            .get("path")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("path required".to_string()))?;
        let content = input
            .get("content")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("content required".to_string()))?;
        let append = input.get("append").and_then(Value::as_bool).unwrap_or(false);
        let tags: Vec<String> = input
            .get("tags")
            .and_then(Value::as_array)
            .map(|items| {
                items
                    .iter()
                    .filter_map(Value::as_str)
                    .map(ToString::to_string)
                    .collect()
            })
            .unwrap_or_default();

        self.vault
            .write(path, content, Some(&tags), append)
            .await
            .map_err(map_vault_error)?;
        Ok(format!("Wrote vault note: {path}"))
    }
}

struct BashExecuteHandler;

#[async_trait]
impl ToolHandler for BashExecuteHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let command = input
            .get("command")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("command required".to_string()))?;
        let timeout_seconds = input
            .get("timeout_seconds")
            .and_then(Value::as_u64)
            .unwrap_or(30)
            .min(120);
        let working_dir = input.get("working_dir").and_then(Value::as_str);

        let blocked = ["rm -rf /", "sudo rm", "mkfs", "dd if=", "diskutil eraseDisk"];
        if blocked.iter().any(|pattern| command.contains(pattern)) {
            return Err(ToolError::PermissionDenied);
        }

        let mut process = tokio::process::Command::new("bash");
        process.arg("-lc").arg(command);
        if let Some(working_dir) = working_dir {
            process.current_dir(working_dir);
        }

        let output = tokio::time::timeout(std::time::Duration::from_secs(timeout_seconds), process.output())
            .await
            .map_err(|_| ToolError::ExecutionFailed(format!("command timed out after {timeout_seconds}s")))?
            .map_err(|error| ToolError::ExecutionFailed(error.to_string()))?;

        let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
        let mut parts = Vec::new();
        if !stdout.is_empty() {
            parts.push(format!("STDOUT:\n{stdout}"));
        }
        if !stderr.is_empty() {
            parts.push(format!("STDERR:\n{stderr}"));
        }
        if !output.status.success() {
            parts.push(format!("Exit code: {}", output.status.code().unwrap_or(-1)));
        }

        Ok(if parts.is_empty() {
            "(no output)".to_string()
        } else {
            parts.join("\n\n")
        })
    }
}

struct WebSearchHandler {
    client: reqwest::Client,
}

impl WebSearchHandler {
    fn new() -> Self {
        Self {
            client: reqwest::Client::new(),
        }
    }
}

#[async_trait]
impl ToolHandler for WebSearchHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let query = input
            .get("query")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("query required".to_string()))?;
        let limit = input.get("limit").and_then(Value::as_u64).unwrap_or(5).max(1) as usize;

        let response = self
            .client
            .get("https://api.duckduckgo.com/")
            .query(&[
                ("q", query),
                ("format", "json"),
                ("no_html", "1"),
                ("skip_disambig", "1"),
                ("t", "epistemos"),
            ])
            .send()
            .await
            .map_err(|error| ToolError::ExecutionFailed(error.to_string()))?;
        let payload = response
            .json::<Value>()
            .await
            .map_err(|error| ToolError::ExecutionFailed(error.to_string()))?;

        let abstract_text = payload
            .get("AbstractText")
            .and_then(Value::as_str)
            .filter(|text| !text.is_empty())
            .map(|text| format!("Abstract: {text}"));
        let related = payload
            .get("RelatedTopics")
            .and_then(Value::as_array)
            .map(|items| {
                items
                    .iter()
                    .filter_map(|item| {
                        let text = item.get("Text").and_then(Value::as_str)?;
                        let url = item.get("FirstURL").and_then(Value::as_str)?;
                        Some(format!("- {text} ({url})"))
                    })
                    .take(limit)
                    .collect::<Vec<_>>()
            })
            .unwrap_or_default();

        let mut sections = Vec::new();
        if let Some(abstract_text) = abstract_text {
            sections.push(abstract_text);
        }
        if !related.is_empty() {
            sections.push(format!("Related topics:\n{}", related.join("\n")));
        }

        Ok(if sections.is_empty() {
            format!("No web search summary found for query: {query}")
        } else {
            sections.join("\n\n")
        })
    }
}

struct ThinkHandler;

#[async_trait]
impl ToolHandler for ThinkHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        Ok(crate::tools::think::execute_think(input))
    }
}

fn map_vault_error(error: VaultError) -> ToolError {
    match error {
        VaultError::NotFound(message) => ToolError::NotFound(message),
        other => ToolError::ExecutionFailed(other.to_string()),
    }
}
