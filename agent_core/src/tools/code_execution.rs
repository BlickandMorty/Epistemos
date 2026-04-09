//! Code Execution Tool — Sandboxed Script Runner
//!
//! Reference: Hermes `tools/code_execution_tool.py`
//! Executes code in a temporary directory with timeout and output limits.
//! Supports: python3, node, ruby, bash, swift, rust (via rustc)

use serde_json::{json, Value};
use tokio::process::Command;

use super::registry::{ToolError, ToolHandler};

pub struct CodeExecutionTool;

const MAX_OUTPUT_BYTES: usize = 10 * 1024 * 1024; // 10MB
const TIMEOUT_SECS: u64 = 30;

#[async_trait::async_trait]
impl ToolHandler for CodeExecutionTool {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let language = input["language"]
            .as_str()
            .ok_or_else(|| ToolError::InvalidArguments("language required".into()))?;
        let code = input["code"]
            .as_str()
            .ok_or_else(|| ToolError::InvalidArguments("code required".into()))?;

        let (ext, cmd): (&str, &str) = match language {
            "python" | "python3" => ("py", "python3"),
            "node" | "javascript" | "js" => ("js", "node"),
            "ruby" => ("rb", "ruby"),
            "bash" | "sh" => ("sh", "bash"),
            "swift" => ("swift", "swift"),
            _ => return Ok(json!({"error": format!("Unsupported language: {language}")}).to_string()),
        };

        // Create temp directory
        let tmp = tempfile::TempDir::new()
            .map_err(|e| ToolError::ExecutionFailed(format!("Failed to create temp dir: {e}")))?;

        let script_path = tmp.path().join(format!("script.{ext}"));
        std::fs::write(&script_path, code)
            .map_err(|e| ToolError::ExecutionFailed(format!("Failed to write script: {e}")))?;

        // Execute with timeout
        let mut command = Command::new(cmd);
        command
            .arg(&script_path)
            .current_dir(tmp.path())
            .stdout(std::process::Stdio::piped())
            .stderr(std::process::Stdio::piped());

        let result = tokio::time::timeout(
            std::time::Duration::from_secs(TIMEOUT_SECS),
            command.output(),
        )
        .await;

        match result {
            Ok(Ok(output)) => {
                let stdout = String::from_utf8_lossy(&output.stdout[..output.stdout.len().min(MAX_OUTPUT_BYTES)]);
                let stderr = String::from_utf8_lossy(&output.stderr[..output.stderr.len().min(MAX_OUTPUT_BYTES)]);
                let exit_code = output.status.code().unwrap_or(-1);

                Ok(json!({
                    "exit_code": exit_code,
                    "stdout": stdout,
                    "stderr": if stderr.is_empty() { None } else { Some(stderr.to_string()) },
                    "success": output.status.success(),
                })
                .to_string())
            }
            Ok(Err(e)) => Ok(json!({"error": format!("Execution failed: {e}")}).to_string()),
            Err(_) => Ok(json!({"error": format!("Execution timed out after {TIMEOUT_SECS}s")}).to_string()),
        }
    }
}

pub fn code_execution_tool_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "execute_code".to_string(),
        description: "Execute code in a sandboxed temporary directory. Supports python3, node, ruby, bash, swift. 30-second timeout. Use for: testing snippets, data processing, calculations.".to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "language": {
                    "type": "string",
                    "enum": ["python3", "node", "ruby", "bash", "swift"],
                    "description": "Programming language to execute"
                },
                "code": {
                    "type": "string",
                    "description": "Source code to execute"
                }
            },
            "required": ["language", "code"]
        }),
    }
}
