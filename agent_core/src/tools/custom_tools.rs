use std::fs;
use std::path::{Path, PathBuf};
use std::sync::OnceLock;

use async_trait::async_trait;
use regex::Regex;
use serde::{Deserialize, Serialize};
use serde_json::{json, Map, Value};

use super::registry::{RiskLevel, ToolError, ToolHandler, ToolTier};
use super::terminal::TerminalHandler;

const MAX_CUSTOM_TOOL_BYTES: usize = 32 * 1024;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CustomToolSpec {
    pub name: String,
    pub description: String,
    #[serde(default)]
    pub guidance: Option<String>,
    pub input_schema: Value,
    pub command_template: String,
    #[serde(default)]
    pub workdir: Option<String>,
    #[serde(default)]
    pub timeout_secs: Option<u64>,
    #[serde(default)]
    pub risk_level: Option<String>,
    #[serde(default)]
    pub tier: Option<String>,
}

impl CustomToolSpec {
    pub fn validate(&self) -> Result<(), String> {
        if let Some(error) = validate_name(&self.name) {
            return Err(error);
        }
        if crate::tools::registry::is_reserved_tool_name(&self.name) {
            return Err(format!(
                "Tool '{}' conflicts with a built-in or reserved tool name.",
                self.name
            ));
        }
        if self.description.trim().is_empty() {
            return Err("description is required".to_string());
        }
        if self.command_template.trim().is_empty() {
            return Err("command_template is required".to_string());
        }
        if let Some(workdir) = &self.workdir {
            if workdir.trim().is_empty() {
                return Err("workdir cannot be empty when provided".to_string());
            }
        }

        let schema_type = self
            .input_schema
            .get("type")
            .and_then(Value::as_str)
            .unwrap_or("");
        if schema_type != "object" {
            return Err("input_schema.type must be 'object'".to_string());
        }
        if !self.input_schema.is_object() {
            return Err("input_schema must be a JSON object".to_string());
        }
        if let Some(tier) = &self.tier {
            parse_tool_tier(tier)?;
        }
        if let Some(risk_level) = &self.risk_level {
            parse_risk_level(risk_level)?;
        }
        Ok(())
    }

    pub fn tier(&self) -> ToolTier {
        self.tier
            .as_deref()
            .and_then(|raw| parse_tool_tier(raw).ok())
            .unwrap_or(ToolTier::Agent)
    }

    pub fn risk_level(&self) -> RiskLevel {
        self.risk_level
            .as_deref()
            .and_then(|raw| parse_risk_level(raw).ok())
            .unwrap_or(RiskLevel::Modification)
    }

    pub fn model_description(&self) -> String {
        let mut description = self.description.trim().to_string();
        if let Some(guidance) = &self.guidance {
            let trimmed = guidance.trim();
            if !trimmed.is_empty() {
                description.push_str(" Guidance: ");
                description.push_str(trimmed);
            }
        }
        description
    }
}

pub fn custom_tools_dir(vault_root: &Path) -> PathBuf {
    vault_root.join(".epistemos").join("custom_tools")
}

pub fn load_custom_tool_specs(vault_root: &Path) -> Vec<CustomToolSpec> {
    let tools_dir = custom_tools_dir(vault_root);
    let Ok(entries) = fs::read_dir(&tools_dir) else {
        return Vec::new();
    };

    let mut specs: Vec<CustomToolSpec> = entries
        .flatten()
        .map(|entry| entry.path())
        .filter(|path| path.extension().and_then(|value| value.to_str()) == Some("json"))
        .filter_map(|path| {
            let content = fs::read_to_string(&path).ok()?;
            let spec: CustomToolSpec = serde_json::from_str(&content).ok()?;
            spec.validate().ok()?;
            Some(spec)
        })
        .collect();
    specs.sort_by(|lhs, rhs| lhs.name.cmp(&rhs.name));
    specs
}

pub struct CustomToolRuntimeHandler {
    spec: CustomToolSpec,
}

impl CustomToolRuntimeHandler {
    pub fn new(spec: CustomToolSpec) -> Self {
        Self { spec }
    }
}

#[async_trait]
impl ToolHandler for CustomToolRuntimeHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let input_object = input.as_object().ok_or_else(|| {
            ToolError::InvalidArguments("custom tool input must be a JSON object".into())
        })?;
        validate_required_properties(&self.spec.input_schema, input_object)?;

        let command = interpolate_template(&self.spec.command_template, input_object)?;
        let workdir = match &self.spec.workdir {
            Some(template) => Some(interpolate_template(template, input_object)?),
            None => None,
        };
        let terminal_input = json!({
            "command": command,
            "timeout_secs": self.spec.timeout_secs.unwrap_or(120).clamp(1, 600),
            "workdir": workdir,
        });

        TerminalHandler.execute(&terminal_input).await
    }
}

pub struct CustomToolManageHandler {
    tools_dir: PathBuf,
}

impl CustomToolManageHandler {
    pub fn new(vault_root: PathBuf) -> Self {
        Self {
            tools_dir: custom_tools_dir(&vault_root),
        }
    }
}

#[async_trait]
impl ToolHandler for CustomToolManageHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let action = input
            .get("action")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'action'".into()))?;

        match action {
            "list" => list_tools(&self.tools_dir),
            "create" => save_tool(&self.tools_dir, input, false),
            "edit" => save_tool(&self.tools_dir, input, true),
            "delete" => delete_tool(&self.tools_dir, input),
            other => Err(ToolError::InvalidArguments(format!(
                "unknown action '{other}' (expected: list|create|edit|delete)"
            ))),
        }
    }
}

pub fn custom_tool_manage_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "tool_manage".to_string(),
        description: "Create, edit, delete, or list user-defined JSON tools. Custom tools are \
             persisted inside the vault and become real callable tools for the model once saved. \
             They are shell-backed and use a command_template with {{input_name}} placeholders."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["list", "create", "edit", "delete"]
                },
                "spec": {
                    "type": "object",
                    "description": "Custom tool spec JSON for create/edit."
                },
                "name": {
                    "type": "string",
                    "description": "Tool name for delete."
                }
            },
            "required": ["action"]
        }),
    }
}

fn save_tool(tools_dir: &Path, input: &Value, allow_existing: bool) -> Result<String, ToolError> {
    let spec_value = input
        .get("spec")
        .ok_or_else(|| ToolError::InvalidArguments("missing 'spec'".into()))?;
    let spec: CustomToolSpec = serde_json::from_value(spec_value.clone()).map_err(|error| {
        ToolError::InvalidArguments(format!("invalid custom tool spec: {error}"))
    })?;
    spec.validate().map_err(ToolError::InvalidArguments)?;

    let path = tool_spec_path(tools_dir, &spec.name);
    if !allow_existing && path.exists() {
        return Err(ToolError::ExecutionFailed(format!(
            "custom tool '{}' already exists",
            spec.name
        )));
    }
    if allow_existing && !path.exists() {
        return Err(ToolError::NotFound(format!("custom tool '{}'", spec.name)));
    }

    fs::create_dir_all(tools_dir)
        .map_err(|error| ToolError::ExecutionFailed(format!("mkdir: {error}")))?;
    let encoded = serde_json::to_vec_pretty(&spec)
        .map_err(|error| ToolError::ExecutionFailed(format!("encode: {error}")))?;
    if encoded.len() > MAX_CUSTOM_TOOL_BYTES {
        return Err(ToolError::InvalidArguments(format!(
            "custom tool spec exceeds {MAX_CUSTOM_TOOL_BYTES} bytes"
        )));
    }
    fs::write(&path, encoded)
        .map_err(|error| ToolError::ExecutionFailed(format!("write: {error}")))?;

    Ok(json!({
        "success": true,
        "action": if allow_existing { "edit" } else { "create" },
        "name": spec.name,
        "path": path.display().to_string(),
    })
    .to_string())
}

fn list_tools(tools_dir: &Path) -> Result<String, ToolError> {
    let mut specs = Vec::new();
    if tools_dir.exists() {
        for spec in load_specs_from_dir(tools_dir)? {
            specs.push(
                serde_json::to_value(spec)
                    .map_err(|error| ToolError::ExecutionFailed(format!("encode: {error}")))?,
            );
        }
    }

    Ok(json!({
        "success": true,
        "count": specs.len(),
        "tools": specs,
        "tools_dir": tools_dir.display().to_string(),
    })
    .to_string())
}

fn delete_tool(tools_dir: &Path, input: &Value) -> Result<String, ToolError> {
    let name = input
        .get("name")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'name'".into()))?;
    if let Some(error) = validate_name(name) {
        return Err(ToolError::InvalidArguments(error));
    }

    let path = tool_spec_path(tools_dir, name);
    if !path.exists() {
        return Err(ToolError::NotFound(format!("custom tool '{name}'")));
    }
    fs::remove_file(&path)
        .map_err(|error| ToolError::ExecutionFailed(format!("remove: {error}")))?;

    Ok(json!({
        "success": true,
        "action": "delete",
        "name": name,
    })
    .to_string())
}

fn tool_spec_path(tools_dir: &Path, name: &str) -> PathBuf {
    tools_dir.join(format!("{name}.json"))
}

fn load_specs_from_dir(tools_dir: &Path) -> Result<Vec<CustomToolSpec>, ToolError> {
    let entries = fs::read_dir(tools_dir)
        .map_err(|error| ToolError::ExecutionFailed(format!("read_dir: {error}")))?;
    let mut specs = Vec::new();
    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().and_then(|value| value.to_str()) != Some("json") {
            continue;
        }
        let content = fs::read_to_string(&path)
            .map_err(|error| ToolError::ExecutionFailed(format!("read: {error}")))?;
        let spec: CustomToolSpec = serde_json::from_str(&content).map_err(|error| {
            ToolError::ExecutionFailed(format!("invalid spec '{}': {error}", path.display()))
        })?;
        spec.validate().map_err(|error| {
            ToolError::ExecutionFailed(format!("invalid spec '{}': {error}", path.display()))
        })?;
        specs.push(spec);
    }
    specs.sort_by(|lhs, rhs| lhs.name.cmp(&rhs.name));
    Ok(specs)
}

fn validate_name(name: &str) -> Option<String> {
    if name.is_empty() {
        return Some("tool name is required".to_string());
    }
    if !name
        .chars()
        .next()
        .map(|character| character.is_ascii_alphanumeric())
        .unwrap_or(false)
    {
        return Some("tool name must start with a letter or digit".to_string());
    }
    if !name.chars().all(|character| {
        character.is_ascii_lowercase()
            || character.is_ascii_digit()
            || character == '-'
            || character == '_'
            || character == '.'
    }) {
        return Some(
            "tool name must use lowercase letters, numbers, hyphens, underscores, or dots"
                .to_string(),
        );
    }
    None
}

fn parse_risk_level(raw: &str) -> Result<RiskLevel, String> {
    match raw.to_ascii_lowercase().as_str() {
        "read_only" | "readonly" | "read-only" => Ok(RiskLevel::ReadOnly),
        "modification" | "modify" | "write" => Ok(RiskLevel::Modification),
        "destructive" | "delete" => Ok(RiskLevel::Destructive),
        _ => Err(format!("unsupported risk_level '{raw}'")),
    }
}

fn parse_tool_tier(raw: &str) -> Result<ToolTier, String> {
    match raw.to_ascii_lowercase().as_str() {
        "none" => Ok(ToolTier::None),
        "chat_lite" | "chat-lite" => Ok(ToolTier::ChatLite),
        "chat_pro" | "chat-pro" => Ok(ToolTier::ChatPro),
        "agent" => Ok(ToolTier::Agent),
        "full" => Ok(ToolTier::Full),
        _ => Err(format!("unsupported tier '{raw}'")),
    }
}

fn validate_required_properties(
    schema: &Value,
    input: &Map<String, Value>,
) -> Result<(), ToolError> {
    let Some(required) = schema.get("required").and_then(Value::as_array) else {
        return Ok(());
    };

    for name in required {
        let Some(name) = name.as_str() else { continue };
        if !input.contains_key(name) {
            return Err(ToolError::InvalidArguments(format!(
                "missing required input '{}'",
                name
            )));
        }
    }
    Ok(())
}

fn interpolate_template(template: &str, input: &Map<String, Value>) -> Result<String, ToolError> {
    let pattern = placeholder_pattern();
    let mut rendered = String::with_capacity(template.len() + 32);
    let mut last = 0;

    for captures in pattern.captures_iter(template) {
        let Some(matched) = captures.get(0) else {
            continue;
        };
        let Some(name) = captures.get(1) else {
            continue;
        };
        rendered.push_str(&template[last..matched.start()]);
        let key = name.as_str();
        let value = input.get(key).ok_or_else(|| {
            ToolError::InvalidArguments(format!("missing template input '{}'", key))
        })?;
        rendered.push_str(&shell_escape_json_value(value));
        last = matched.end();
    }
    rendered.push_str(&template[last..]);

    if rendered.contains("{{") && rendered.contains("}}") {
        return Err(ToolError::InvalidArguments(
            "template still contains unresolved placeholders".into(),
        ));
    }

    Ok(rendered)
}

fn shell_escape_json_value(value: &Value) -> String {
    let scalar = match value {
        Value::Null => String::new(),
        Value::Bool(boolean) => boolean.to_string(),
        Value::Number(number) => number.to_string(),
        Value::String(string) => string.clone(),
        Value::Array(_) | Value::Object(_) => serde_json::to_string(value).unwrap_or_default(),
    };
    shell_escape(&scalar)
}

fn shell_escape(raw: &str) -> String {
    if raw.is_empty() {
        return "''".to_string();
    }
    let escaped = raw.replace('\'', r#"'\''"#);
    format!("'{escaped}'")
}

fn placeholder_pattern() -> &'static Regex {
    static REGEX: OnceLock<Regex> = OnceLock::new();
    REGEX.get_or_init(|| Regex::new(r"\{\{\s*([A-Za-z0-9_.-]+)\s*\}\}").expect("valid regex"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn load_custom_specs_skips_invalid_entries() {
        let root = tempdir().unwrap();
        let tools_dir = custom_tools_dir(root.path());
        fs::create_dir_all(&tools_dir).unwrap();

        let valid = json!({
            "name": "echo-name",
            "description": "Echo the provided name.",
            "input_schema": {
                "type": "object",
                "properties": {
                    "name": { "type": "string" }
                },
                "required": ["name"]
            },
            "command_template": "printf %s {{name}}",
            "risk_level": "read_only",
            "tier": "chat_lite"
        });
        fs::write(
            tools_dir.join("echo-name.json"),
            serde_json::to_vec_pretty(&valid).unwrap(),
        )
        .unwrap();
        fs::write(tools_dir.join("broken.json"), br#"{"name":"broken"}"#).unwrap();

        let specs = load_custom_tool_specs(root.path());
        assert_eq!(specs.len(), 1);
        assert_eq!(specs[0].name, "echo-name");
    }

    #[tokio::test]
    async fn custom_tool_handler_executes_templated_command() {
        let spec = CustomToolSpec {
            name: "echo-name".to_string(),
            description: "Echo the provided name.".to_string(),
            guidance: Some("Use for simple shell-backed echoes.".to_string()),
            input_schema: json!({
                "type": "object",
                "properties": {
                    "name": { "type": "string" }
                },
                "required": ["name"]
            }),
            command_template: "printf %s {{name}}".to_string(),
            workdir: None,
            timeout_secs: Some(30),
            risk_level: Some("read_only".to_string()),
            tier: Some("chat_lite".to_string()),
        };

        let result = CustomToolRuntimeHandler::new(spec)
            .execute(&json!({ "name": "Ada Lovelace" }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["success"], json!(true));
        assert_eq!(parsed["stdout"], json!("Ada Lovelace"));
    }

    #[test]
    fn save_and_list_custom_tools_roundtrip() {
        let root = tempdir().unwrap();
        let tools_dir = custom_tools_dir(root.path());
        let input = json!({
            "action": "create",
            "spec": {
                "name": "echo-name",
                "description": "Echo the provided name.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "name": { "type": "string" }
                    },
                    "required": ["name"]
                },
                "command_template": "printf %s {{name}}",
                "risk_level": "read_only",
                "tier": "chat_lite"
            }
        });

        let created = save_tool(&tools_dir, &input, false).unwrap();
        assert!(created.contains("\"action\":\"create\""));

        let listed = list_tools(&tools_dir).unwrap();
        let parsed: Value = serde_json::from_str(&listed).unwrap();
        assert_eq!(parsed["count"], json!(1));
        assert_eq!(parsed["tools"][0]["name"], json!("echo-name"));
    }
}
