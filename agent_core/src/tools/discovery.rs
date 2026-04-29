//! Discovery Tools — MCP server auto-discovery + external tool catalogs.
//!
//! Two tools live here:
//!
//! * `mcp_discover`  — scan `~/.epistemos/mcp-servers/*.json`, return the
//!                     registered server configs so the UI can surface them
//!                     and the agent can see which MCP tools are available.
//! * `model_catalog` — query OpenRouter's `/api/v1/models` endpoint for live
//!                     pricing and context-window metadata.
//!
//! Both tools are read-only and safe for `ChatLite` tier.

use std::path::PathBuf;
use std::time::Duration;

use async_trait::async_trait;
use reqwest::Client;
use serde_json::{json, Value};

use super::registry::{ToolError, ToolHandler};

const HTTP_TIMEOUT: Duration = Duration::from_secs(15);

// ── mcp_discover ──────────────────────────────────────────────────────────

pub struct McpDiscoverHandler;

fn mcp_config_dirs() -> Vec<PathBuf> {
    let mut out = Vec::new();
    if let Some(home) = dirs::home_dir() {
        out.push(home.join(".epistemos/mcp-servers"));
        out.push(home.join(".config/epistemos/mcp-servers"));
    }
    // Also honour the XDG_CONFIG_HOME override if present.
    if let Ok(xdg) = std::env::var("XDG_CONFIG_HOME") {
        out.push(PathBuf::from(xdg).join("epistemos/mcp-servers"));
    }
    out
}

/// Phase 2G-4 native `Tool` impl. Pattern documented in `todo.rs`.
#[async_trait]
impl super::Tool for McpDiscoverHandler {
    fn name(&self) -> &'static str { "discovery.mcp_discover" }
    fn input_schema(&self) -> &'static Value {
        super::v2_catalog::discovery_mcp_discover::input_schema()
    }
    fn output_schema(&self) -> &'static Value {
        super::legacy_adapter::generic_text_or_object_output_schema()
    }
    fn variants(&self) -> &[super::VariantId] { &[super::VariantId::A] }
    fn profile(&self) -> super::Profile { super::Profile::AppStoreSafe }
    fn small_model_safe(&self) -> bool { true }
    async fn invoke(
        &self,
        _ctx: &super::ToolCtx,
        variant: super::VariantId,
        input: Value,
    ) -> super::ToolResult {
        let started = std::time::Instant::now();
        match <Self as ToolHandler>::execute(self, &input).await {
            Ok(s) => {
                let elapsed_ms = started.elapsed().as_millis() as u32;
                let result = serde_json::from_str::<Value>(&s)
                    .ok()
                    .filter(|v| v.is_object() || v.is_array())
                    .unwrap_or_else(|| serde_json::json!({"text": s}));
                super::ToolResult { meta: super::ToolMeta::ok(variant, elapsed_ms), result }
            }
            Err(e) => super::ToolResult::error(variant, e.to_string()),
        }
    }
}

#[async_trait]
impl ToolHandler for McpDiscoverHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let create_missing = input
            .get("create_missing")
            .and_then(Value::as_bool)
            .unwrap_or(false);

        let mut servers: Vec<Value> = Vec::new();
        let mut scanned: Vec<String> = Vec::new();
        let mut created: Vec<String> = Vec::new();

        for dir in mcp_config_dirs() {
            let dir_str = dir.display().to_string();
            if !dir.exists() {
                if create_missing {
                    if let Err(e) = std::fs::create_dir_all(&dir) {
                        tracing::warn!("mcp_discover: failed to create {}: {e}", dir.display());
                    } else {
                        created.push(dir_str.clone());
                    }
                }
                continue;
            }
            scanned.push(dir_str);

            let entries = match std::fs::read_dir(&dir) {
                Ok(e) => e,
                Err(e) => {
                    tracing::warn!("mcp_discover: failed to read {}: {e}", dir.display());
                    continue;
                }
            };

            for entry in entries.flatten() {
                let path = entry.path();
                let ext_ok = path
                    .extension()
                    .and_then(|s| s.to_str())
                    .map(|s| s.eq_ignore_ascii_case("json"))
                    .unwrap_or(false);
                if !ext_ok {
                    continue;
                }
                let content = match std::fs::read_to_string(&path) {
                    Ok(c) => c,
                    Err(e) => {
                        tracing::debug!("mcp_discover: skip {}: {e}", path.display());
                        continue;
                    }
                };
                let parsed: Value = match serde_json::from_str(&content) {
                    Ok(v) => v,
                    Err(e) => {
                        servers.push(json!({
                            "path": path.display().to_string(),
                            "error": format!("invalid JSON: {e}"),
                        }));
                        continue;
                    }
                };

                // Normalise either {"mcpServers": {...}} (OpenClaw-style)
                // or {"name": ..., "command": ...} single-entry form into
                // a flat list.
                if let Some(obj) = parsed.get("mcpServers").and_then(Value::as_object) {
                    for (name, cfg) in obj {
                        servers.push(json!({
                            "name": name,
                            "path": path.display().to_string(),
                            "config": cfg,
                        }));
                    }
                } else {
                    servers.push(json!({
                        "path": path.display().to_string(),
                        "config": parsed,
                    }));
                }
            }
        }

        Ok(json!({
            "success": true,
            "scanned_dirs": scanned,
            "created_dirs": created,
            "server_count": servers.len(),
            "servers": servers,
        })
        .to_string())
    }
}

pub fn mcp_discover_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "mcp_discover".to_string(),
        description: "Scan the standard MCP config directories (~/.epistemos/mcp-servers, \
             ~/.config/epistemos/mcp-servers, $XDG_CONFIG_HOME/epistemos/mcp-servers) and \
             return every server config found. Accepts OpenClaw-style `{mcpServers: {...}}` \
             or single-entry JSON files. Set `create_missing: true` to mkdir the default \
             scan roots when they don't exist."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "create_missing": {
                    "type": "boolean",
                    "description": "Create the scan directories if missing.",
                    "default": false
                }
            }
        }),
    }
}

// ── model_catalog ─────────────────────────────────────────────────────────

pub struct ModelCatalogHandler {
    client: Client,
}

impl ModelCatalogHandler {
    pub fn new() -> Result<Self, ToolError> {
        let client = Client::builder()
            .timeout(HTTP_TIMEOUT)
            .user_agent("Epistemos/1.0 (ModelCatalog)")
            .build()
            .map_err(|e| ToolError::ExecutionFailed(format!("http init: {e}")))?;
        Ok(Self { client })
    }
}

/// Phase 2G-4 native `Tool` impl. Pattern documented in `todo.rs`.
#[async_trait]
impl super::Tool for ModelCatalogHandler {
    fn name(&self) -> &'static str { "discovery.model_catalog" }
    fn input_schema(&self) -> &'static Value {
        super::v2_catalog::discovery_model_catalog::input_schema()
    }
    fn output_schema(&self) -> &'static Value {
        super::legacy_adapter::generic_text_or_object_output_schema()
    }
    fn variants(&self) -> &[super::VariantId] { &[super::VariantId::A] }
    fn profile(&self) -> super::Profile { super::Profile::AppStoreSafe }
    fn small_model_safe(&self) -> bool { true }
    async fn invoke(
        &self,
        _ctx: &super::ToolCtx,
        variant: super::VariantId,
        input: Value,
    ) -> super::ToolResult {
        let started = std::time::Instant::now();
        match <Self as ToolHandler>::execute(self, &input).await {
            Ok(s) => {
                let elapsed_ms = started.elapsed().as_millis() as u32;
                let result = serde_json::from_str::<Value>(&s)
                    .ok()
                    .filter(|v| v.is_object() || v.is_array())
                    .unwrap_or_else(|| serde_json::json!({"text": s}));
                super::ToolResult { meta: super::ToolMeta::ok(variant, elapsed_ms), result }
            }
            Err(e) => super::ToolResult::error(variant, e.to_string()),
        }
    }
}

#[async_trait]
impl ToolHandler for ModelCatalogHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let source = input
            .get("source")
            .and_then(Value::as_str)
            .unwrap_or("openrouter");
        let filter = input.get("filter").and_then(Value::as_str);
        let limit = input.get("limit").and_then(Value::as_u64).unwrap_or(50) as usize;

        match source.to_ascii_lowercase().as_str() {
            "openrouter" => self.fetch_openrouter(filter, limit).await,
            "local" => self.local_catalog(filter, limit),
            other => Err(ToolError::InvalidArguments(format!(
                "unknown source '{other}' (expected: openrouter|local)"
            ))),
        }
    }
}

impl ModelCatalogHandler {
    async fn fetch_openrouter(
        &self,
        filter: Option<&str>,
        limit: usize,
    ) -> Result<String, ToolError> {
        // OpenRouter's public catalog endpoint — no auth required for the
        // GET /api/v1/models listing. Live pricing and context window per
        // model. We cache nothing (agent should re-query when it wants
        // fresh data).
        let resp = self
            .client
            .get("https://openrouter.ai/api/v1/models")
            .send()
            .await
            .map_err(|e| ToolError::ExecutionFailed(format!("openrouter request: {e}")))?;
        if !resp.status().is_success() {
            return Err(ToolError::ExecutionFailed(format!(
                "openrouter HTTP {}",
                resp.status()
            )));
        }
        let payload: Value = resp
            .json()
            .await
            .map_err(|e| ToolError::ExecutionFailed(format!("openrouter parse: {e}")))?;

        let mut models: Vec<Value> = payload
            .get("data")
            .and_then(Value::as_array)
            .cloned()
            .unwrap_or_default();

        if let Some(needle) = filter {
            let needle_lower = needle.to_ascii_lowercase();
            models.retain(|m| {
                let id = m.get("id").and_then(Value::as_str).unwrap_or("");
                let name = m.get("name").and_then(Value::as_str).unwrap_or("");
                id.to_ascii_lowercase().contains(&needle_lower)
                    || name.to_ascii_lowercase().contains(&needle_lower)
            });
        }
        let total = models.len();
        models.truncate(limit);

        // Compress the per-model payload to just the fields the agent cares
        // about so the tool result doesn't blow the context budget.
        let compact: Vec<Value> = models
            .iter()
            .map(|m| {
                json!({
                    "id": m.get("id"),
                    "name": m.get("name"),
                    "context_length": m.get("context_length"),
                    "pricing": m.get("pricing"),
                    "architecture": m.get("architecture").and_then(|a| a.get("modality")),
                    "supports_tools": m
                        .get("supported_parameters")
                        .and_then(Value::as_array)
                        .map(|arr| arr.iter().any(|v| v.as_str() == Some("tools")))
                        .unwrap_or(false),
                })
            })
            .collect();

        Ok(json!({
            "success": true,
            "source": "openrouter",
            "total_matching": total,
            "returned": compact.len(),
            "models": compact,
        })
        .to_string())
    }

    fn local_catalog(&self, filter: Option<&str>, limit: usize) -> Result<String, ToolError> {
        // Hard-coded catalog of the Epistemos-supported local MLX models —
        // mirror of `LocalTextModelID` in the Swift side. This keeps the
        // local picker honest even when offline. If you add a model in
        // Swift, add it here too.
        let local = [
            (
                "mlx-community/Qwen3.5-0.8B-4bit",
                "Qwen 3.5 0.8B",
                32_768usize,
                false,
            ),
            ("mlx-community/Qwen3.5-2B-4bit", "Qwen 3.5 2B", 32_768, true),
            ("mlx-community/Qwen3.5-4B-4bit", "Qwen 3.5 4B", 32_768, true),
            ("mlx-community/Qwen3.5-9B-4bit", "Qwen 3.5 9B", 32_768, true),
            (
                "mlx-community/Qwen3.5-27B-4bit",
                "Qwen 3.5 27B",
                65_536,
                true,
            ),
            (
                "mlx-community/Qwen3.5-35B-A3B-4bit",
                "Qwen 3.5 35B MoE",
                65_536,
                true,
            ),
            (
                "mlx-community/gemma-4-e2b-it-4bit",
                "Gemma 4 2B",
                8_192,
                false,
            ),
            (
                "mlx-community/gemma-4-e4b-it-4bit",
                "Gemma 4 4B",
                8_192,
                true,
            ),
            (
                "mlx-community/gemma-4-26b-a4b-it-4bit",
                "Gemma 4 27B MoE",
                32_768,
                true,
            ),
            (
                "mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit",
                "DeepSeek R1 7B",
                65_536,
                false,
            ),
            (
                "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit",
                "Qwen 2.5 Coder 7B",
                32_768,
                true,
            ),
            (
                "mlx-community/mamba2-2.7b-4bit",
                "Mamba2 2.7B",
                1_048_576,
                false,
            ),
            ("mlx-community/SmolLM3-3B-4bit", "SmolLM3 3B", 32_768, false),
        ];

        let needle_lower = filter.map(|s| s.to_ascii_lowercase());
        let mut out: Vec<Value> = Vec::new();
        for (id, name, ctx, agent) in local {
            if let Some(ref needle) = needle_lower {
                if !id.to_ascii_lowercase().contains(needle)
                    && !name.to_ascii_lowercase().contains(needle)
                {
                    continue;
                }
            }
            out.push(json!({
                "id": id,
                "name": name,
                "context_length": ctx,
                "backend": "mlx",
                "supports_tools": agent,
            }));
            if out.len() >= limit {
                break;
            }
        }
        Ok(json!({
            "success": true,
            "source": "local",
            "returned": out.len(),
            "models": out,
        })
        .to_string())
    }
}

pub fn model_catalog_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "model_catalog".to_string(),
        description: "Fetch the live model catalog. source='openrouter' hits the public \
             OpenRouter API for cloud models with live pricing + context windows; \
             source='local' returns the Epistemos-supported MLX local models. Optional \
             'filter' substring match on id or name. Results compressed to the fields an \
             agent needs (id, name, context, pricing, supports_tools)."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "source": {
                    "type": "string",
                    "enum": ["openrouter", "local"],
                    "default": "openrouter"
                },
                "filter": { "type": "string", "description": "Substring filter on id/name." },
                "limit": { "type": "integer", "default": 50, "minimum": 1, "maximum": 500 }
            }
        }),
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use tempfile::tempdir;

    #[tokio::test]
    async fn mcp_discover_returns_empty_when_dirs_missing() {
        // Override HOME so the scanner finds nothing.
        let dir = tempdir().unwrap();
        let saved = std::env::var("HOME").ok();
        std::env::set_var("HOME", dir.path());
        let saved_xdg = std::env::var("XDG_CONFIG_HOME").ok();
        std::env::remove_var("XDG_CONFIG_HOME");

        let handler = McpDiscoverHandler;
        let result = handler.execute(&json!({})).await.unwrap();
        assert!(result.contains("\"server_count\":0"));

        if let Some(v) = saved {
            std::env::set_var("HOME", v);
        }
        if let Some(v) = saved_xdg {
            std::env::set_var("XDG_CONFIG_HOME", v);
        }
    }

    #[tokio::test]
    async fn mcp_discover_parses_openclaw_style_config() {
        let dir = tempdir().unwrap();
        let home = dir.path().to_path_buf();
        let saved = std::env::var("HOME").ok();
        std::env::set_var("HOME", &home);
        let saved_xdg = std::env::var("XDG_CONFIG_HOME").ok();
        std::env::remove_var("XDG_CONFIG_HOME");

        let server_dir = home.join(".epistemos/mcp-servers");
        std::fs::create_dir_all(&server_dir).unwrap();
        std::fs::write(
            server_dir.join("brave.json"),
            r#"{"mcpServers":{"brave":{"command":"mcp-brave","args":["--key","X"]}}}"#,
        )
        .unwrap();

        let handler = McpDiscoverHandler;
        let result = handler.execute(&json!({})).await.unwrap();
        assert!(result.contains("\"name\":\"brave\""));
        assert!(result.contains("\"command\":\"mcp-brave\""));

        if let Some(v) = saved {
            std::env::set_var("HOME", v);
        }
        if let Some(v) = saved_xdg {
            std::env::set_var("XDG_CONFIG_HOME", v);
        }
    }

    #[tokio::test]
    async fn model_catalog_local_filters_by_name() {
        let handler = ModelCatalogHandler::new().unwrap();
        let result = handler
            .execute(&json!({"source":"local","filter":"qwen","limit":3}))
            .await
            .unwrap();
        assert!(result.contains("Qwen"));
        assert!(!result.contains("Gemma"));
    }

    #[tokio::test]
    async fn model_catalog_rejects_unknown_source() {
        let handler = ModelCatalogHandler::new().unwrap();
        let err = handler
            .execute(&json!({"source":"yahoo"}))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("unknown source"));
    }
}
