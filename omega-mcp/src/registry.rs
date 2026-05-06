// Tool registry: register, discover, validate, and invoke tools by name.
// Thread-safe via internal HashMap (UniFFI handles concurrency at the Swift level).

#[cfg(test)]
use crate::types::SafetyInfo;
use crate::types::ToolDefinition;
use std::collections::HashMap;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum ToolRegistryError {
    #[error("Tool '{0}' not found")]
    NotFound(String),
    #[error("Tool '{0}' already registered")]
    AlreadyRegistered(String),
    #[error("Invalid JSON schema for tool '{0}': {1}")]
    InvalidSchema(String, String),
    #[error("Argument validation failed for tool '{0}': {1}")]
    ValidationFailed(String, String),
}

/// In-process tool registry. Holds tool definitions for lookup and validation.
pub struct ToolRegistry {
    tools: HashMap<String, ToolDefinition>,
}

impl Default for ToolRegistry {
    fn default() -> Self {
        Self::new()
    }
}

impl ToolRegistry {
    pub fn new() -> Self {
        ToolRegistry {
            tools: HashMap::new(),
        }
    }

    /// Register a tool definition. Returns error if name already taken.
    pub fn register(&mut self, tool: ToolDefinition) -> Result<(), ToolRegistryError> {
        if self.tools.contains_key(&tool.name) {
            return Err(ToolRegistryError::AlreadyRegistered(tool.name.clone()));
        }
        // Validate that input_schema_json is parseable
        if serde_json::from_str::<serde_json::Value>(&tool.input_schema_json).is_err() {
            return Err(ToolRegistryError::InvalidSchema(
                tool.name.clone(),
                "input_schema_json is not valid JSON".to_string(),
            ));
        }
        self.tools.insert(tool.name.clone(), tool);
        Ok(())
    }

    /// Look up a tool by name.
    pub fn get(&self, name: &str) -> Option<&ToolDefinition> {
        self.tools.get(name)
    }

    /// List all registered tool definitions.
    pub fn list(&self) -> Vec<ToolDefinition> {
        self.tools.values().cloned().collect()
    }

    /// Number of registered tools.
    pub fn count(&self) -> usize {
        self.tools.len()
    }

    /// Validate arguments JSON against a tool's input schema.
    /// For Phase 0, this does basic structural validation (is valid JSON object).
    /// Full JSON Schema validation will be added when needed.
    pub fn validate_args(&self, tool_name: &str, args_json: &str) -> Result<(), ToolRegistryError> {
        let tool = self
            .tools
            .get(tool_name)
            .ok_or_else(|| ToolRegistryError::NotFound(tool_name.to_string()))?;

        // Parse the arguments as JSON
        let args: serde_json::Value = serde_json::from_str(args_json).map_err(|e| {
            ToolRegistryError::ValidationFailed(
                tool_name.to_string(),
                format!("Arguments are not valid JSON: {e}"),
            )
        })?;

        // Must be an object
        if !args.is_object() {
            return Err(ToolRegistryError::ValidationFailed(
                tool_name.to_string(),
                "Arguments must be a JSON object".to_string(),
            ));
        }

        // Parse schema to check required fields
        if let Ok(schema) = serde_json::from_str::<serde_json::Value>(&tool.input_schema_json) {
            if let Some(required) = schema.get("required").and_then(|r| r.as_array()) {
                let Some(obj) = args.as_object() else {
                    return Err(ToolRegistryError::ValidationFailed(
                        tool_name.to_string(),
                        "Arguments must be a JSON object".to_string(),
                    ));
                };
                for req in required {
                    if let Some(key) = req.as_str() {
                        if !obj.contains_key(key) {
                            return Err(ToolRegistryError::ValidationFailed(
                                tool_name.to_string(),
                                format!("Missing required argument: {key}"),
                            ));
                        }
                    }
                }
            }
        }

        Ok(())
    }

    /// Remove a tool by name. Returns true if it existed.
    pub fn unregister(&mut self, name: &str) -> bool {
        self.tools.remove(name).is_some()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_tool(name: &str) -> ToolDefinition {
        ToolDefinition {
            name: name.to_string(),
            agent: "test".to_string(),
            description: format!("Test tool: {name}"),
            input_schema_json:
                r#"{"type":"object","properties":{"input":{"type":"string"}},"required":["input"]}"#
                    .to_string(),
            arguments_example: r#"{"input":"test"}"#.to_string(),
            safety: SafetyInfo {
                destructive: false,
                requires_confirmation: false,
                scoped_to_apps: vec![],
            },
        }
    }

    #[test]
    fn test_register_and_get() {
        let mut reg = ToolRegistry::new();
        reg.register(make_tool("test_tool")).unwrap();
        assert!(reg.get("test_tool").is_some());
        assert_eq!(reg.count(), 1);
    }

    #[test]
    fn test_duplicate_registration() {
        let mut reg = ToolRegistry::new();
        reg.register(make_tool("dup")).unwrap();
        assert!(reg.register(make_tool("dup")).is_err());
    }

    #[test]
    fn test_list_tools() {
        let mut reg = ToolRegistry::new();
        reg.register(make_tool("a")).unwrap();
        reg.register(make_tool("b")).unwrap();
        assert_eq!(reg.list().len(), 2);
    }

    #[test]
    fn test_validate_args_valid() {
        let mut reg = ToolRegistry::new();
        reg.register(make_tool("t")).unwrap();
        assert!(reg.validate_args("t", r#"{"input":"hello"}"#).is_ok());
    }

    #[test]
    fn test_validate_args_missing_required() {
        let mut reg = ToolRegistry::new();
        reg.register(make_tool("t")).unwrap();
        let result = reg.validate_args("t", r#"{"other":"value"}"#);
        assert!(result.is_err());
        assert!(format!("{:?}", result.unwrap_err()).contains("Missing required"));
    }

    #[test]
    fn test_validate_args_not_object() {
        let mut reg = ToolRegistry::new();
        reg.register(make_tool("t")).unwrap();
        assert!(reg.validate_args("t", r#""just a string""#).is_err());
    }

    #[test]
    fn test_validate_args_invalid_json() {
        let mut reg = ToolRegistry::new();
        reg.register(make_tool("t")).unwrap();
        assert!(reg.validate_args("t", "not json at all").is_err());
    }

    #[test]
    fn test_not_found() {
        let reg = ToolRegistry::new();
        assert!(reg.get("nonexistent").is_none());
        assert!(reg.validate_args("nonexistent", "{}").is_err());
    }

    #[test]
    fn test_invalid_schema_rejected() {
        let mut reg = ToolRegistry::new();
        let mut tool = make_tool("bad");
        tool.input_schema_json = "not valid json".to_string();
        assert!(reg.register(tool).is_err());
    }

    #[test]
    fn test_unregister() {
        let mut reg = ToolRegistry::new();
        reg.register(make_tool("removeme")).unwrap();
        assert!(reg.unregister("removeme"));
        assert!(reg.get("removeme").is_none());
        assert!(!reg.unregister("removeme"));
    }
}
