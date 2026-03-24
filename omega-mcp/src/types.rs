// Core types for the MCP tool system.
// All types derive Serialize/Deserialize for persistence and Clone for sharing.

use serde::{Deserialize, Serialize};

/// Definition of a tool that can be registered and invoked.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolDefinition {
    pub name: String,
    pub description: String,
    /// JSON Schema string for argument validation.
    pub input_schema_json: String,
    pub safety: SafetyInfo,
}

/// Safety metadata for a tool.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SafetyInfo {
    pub destructive: bool,
    pub requires_confirmation: bool,
    /// App bundle IDs this tool is scoped to (empty = unrestricted).
    pub scoped_to_apps: Vec<String>,
}

/// A tool invocation request (parsed from model output or user input).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolCall {
    pub name: String,
    /// JSON-encoded arguments.
    pub arguments_json: String,
}

/// Standardized result from tool execution.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolResult {
    pub success: bool,
    /// JSON-encoded result data.
    pub data_json: String,
    pub error: Option<String>,
    pub error_code: Option<String>,
    pub duration_ms: u64,
}

impl ToolResult {
    pub fn ok(data_json: String, duration_ms: u64) -> Self {
        ToolResult {
            success: true,
            data_json,
            error: None,
            error_code: None,
            duration_ms,
        }
    }

    pub fn err(error: String, code: &str, duration_ms: u64) -> Self {
        ToolResult {
            success: false,
            data_json: "null".to_string(),
            error: Some(error),
            error_code: Some(code.to_string()),
            duration_ms,
        }
    }
}

/// Persisted record of a tool execution (stored in SQLite).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecutionRecord {
    pub id: String,
    pub timestamp: String,
    pub tool_name: String,
    pub arguments_json: String,
    pub result_json: String,
    pub duration_ms: u64,
    pub success: bool,
}

/// Error codes for tool failures (matches Anchor 5 taxonomy).
pub mod error_codes {
    pub const TIMEOUT: &str = "TIMEOUT";
    pub const PERMISSION_DENIED: &str = "PERMISSION_DENIED";
    pub const NOT_FOUND: &str = "NOT_FOUND";
    pub const INVALID_INPUT: &str = "INVALID_INPUT";
    pub const EXECUTION_ERROR: &str = "EXECUTION_ERROR";
    pub const CANCELLED: &str = "CANCELLED";
    pub const AX_SPARSE: &str = "AX_SPARSE";
}
