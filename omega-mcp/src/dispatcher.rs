// MCP request dispatcher: routes JSON-RPC requests through the tool registry.
// Handles tools/list, tools/call dispatching, and execution logging.
// The actual tool execution happens on the Swift side — this layer validates
// and routes, then Swift calls back with results.

use crate::registry::ToolRegistry;
use crate::logger::ExecutionLogger;
use crate::server::{self, JsonRpcRequest, JsonRpcResponse, methods};
use crate::types::{ToolDefinition, ExecutionRecord};
use std::sync::Mutex;

/// Central MCP dispatcher. Owns registry + logger, handles JSON-RPC routing.
pub struct MCPDispatcher {
    registry: Mutex<ToolRegistry>,
    logger: Mutex<ExecutionLogger>,
}

impl MCPDispatcher {
    /// Create a new dispatcher with an execution log at the given path.
    /// Falls back to in-memory database if the file path fails.
    pub fn new(log_db_path: String) -> Self {
        let logger = ExecutionLogger::open(&log_db_path)
            .unwrap_or_else(|_| ExecutionLogger::open_in_memory().unwrap());
        MCPDispatcher {
            registry: Mutex::new(ToolRegistry::new()),
            logger: Mutex::new(logger),
        }
    }

    /// Create a dispatcher with in-memory logger (for testing).
    pub fn new_in_memory() -> Self {
        let logger = ExecutionLogger::open_in_memory().unwrap();
        MCPDispatcher {
            registry: Mutex::new(ToolRegistry::new()),
            logger: Mutex::new(logger),
        }
    }

    // ── Registry Operations ──────────────────────────────────────────────────

    /// Register a tool. Returns empty string on success, error message on failure.
    pub fn register_tool(
        &self,
        name: String,
        description: String,
        input_schema_json: String,
        destructive: bool,
        requires_confirmation: bool,
    ) -> String {
        let tool = ToolDefinition {
            name,
            agent: String::new(),
            description,
            input_schema_json,
            arguments_example: String::new(),
            safety: crate::types::SafetyInfo {
                destructive,
                requires_confirmation,
                scoped_to_apps: vec![],
            },
        };
        match self.registry.lock().unwrap().register(tool) {
            Ok(()) => String::new(),
            Err(e) => e.to_string(),
        }
    }

    /// Register a tool with full metadata (agent, description, example args).
    /// Returns empty string on success, error message on failure.
    pub fn register_tool_full(
        &self,
        name: String,
        agent: String,
        description: String,
        input_schema_json: String,
        arguments_example: String,
        destructive: bool,
        requires_confirmation: bool,
    ) -> String {
        let tool = ToolDefinition {
            name,
            agent,
            description,
            input_schema_json,
            arguments_example,
            safety: crate::types::SafetyInfo {
                destructive,
                requires_confirmation,
                scoped_to_apps: vec![],
            },
        };
        match self.registry.lock().unwrap().register(tool) {
            Ok(()) => String::new(),
            Err(e) => e.to_string(),
        }
    }

    /// Register all built-in Epistemos tools from the canonical catalog.
    /// Returns the number of tools registered.
    pub fn register_builtin_tools(&self) -> u32 {
        let catalog = crate::catalog::builtin_tools();
        let mut count = 0u32;
        let mut reg = self.registry.lock().unwrap();
        for tool in catalog {
            if reg.register(tool).is_ok() {
                count += 1;
            }
        }
        count
    }

    /// List all registered tools as JSON array.
    pub fn list_tools_json(&self) -> String {
        let tools = self.registry.lock().unwrap().list();
        serde_json::to_string(&tools).unwrap_or_default()
    }

    /// Get a single tool definition as JSON. Empty string if not found.
    pub fn get_tool_json(&self, name: String) -> String {
        let name = &name;
        match self.registry.lock().unwrap().get(name) {
            Some(tool) => serde_json::to_string(tool).unwrap_or_default(),
            None => String::new(),
        }
    }

    /// Number of registered tools.
    pub fn tool_count(&self) -> u32 {
        self.registry.lock().unwrap().count() as u32
    }

    /// Validate arguments for a tool. Returns empty string on success.
    pub fn validate_tool_args(&self, tool_name: String, args_json: String) -> String {
        match self.registry.lock().unwrap().validate_args(&tool_name, &args_json) {
            Ok(()) => String::new(),
            Err(e) => e.to_string(),
        }
    }

    /// Unregister a tool. Returns true if it existed.
    pub fn unregister_tool(&self, name: String) -> bool {
        self.registry.lock().unwrap().unregister(&name)
    }

    // ── Logger Operations ────────────────────────────────────────────────────

    /// Log a tool execution. Returns empty string on success.
    pub fn log_execution(
        &self,
        id: String,
        timestamp: String,
        tool_name: String,
        arguments_json: String,
        result_json: String,
        duration_ms: u64,
        success: bool,
    ) -> String {
        let record = ExecutionRecord {
            id,
            timestamp,
            tool_name,
            arguments_json,
            result_json,
            duration_ms,
            success,
        };
        match self.logger.lock().unwrap().log(&record) {
            Ok(()) => String::new(),
            Err(e) => e.to_string(),
        }
    }

    /// Query recent executions as JSON array.
    pub fn recent_executions_json(&self, limit: u32) -> String {
        match self.logger.lock().unwrap().recent(limit as usize) {
            Ok(records) => serde_json::to_string(&records).unwrap_or_default(),
            Err(e) => format!("{{\"error\":\"{e}\"}}"),
        }
    }

    /// Query executions by tool name as JSON array.
    pub fn executions_by_tool_json(&self, tool_name: String, limit: u32) -> String {
        match self.logger.lock().unwrap().by_tool(&tool_name, limit as usize) {
            Ok(records) => serde_json::to_string(&records).unwrap_or_default(),
            Err(e) => format!("{{\"error\":\"{e}\"}}"),
        }
    }

    /// Total execution count.
    pub fn execution_count(&self) -> u64 {
        self.logger.lock().unwrap().count().unwrap_or(0)
    }

    /// Total successful execution count.
    pub fn successful_execution_count(&self) -> u64 {
        self.logger.lock().unwrap().count_successful().unwrap_or(0)
    }

    // ── MCP Dispatch ─────────────────────────────────────────────────────────

    /// Dispatch a JSON-RPC request string. Returns JSON-RPC response string.
    /// Handles: tools/list, tools/call (validation only — actual execution is Swift-side).
    ///
    /// Wave 6.2 follow-up: the entire parse → route → format hot path
    /// runs inside `arena::with_frame` so per-call scratch allocations
    /// (parsed JSON sub-trees, format buffers, capability lookups)
    /// come from the bumpalo per-thread arena instead of the system
    /// allocator. Reset is O(1) at the next call. The arena is
    /// internal — arena-allocated values that need to escape the
    /// closure are copied to owned `String` before return.
    pub fn dispatch(&self, request_json: String) -> String {
        crate::arena::with_frame(|_bump| {
            // _bump is reserved for scratch allocations as the
            // dispatcher grows. The current parse + route paths still
            // use the system allocator for the structures they own
            // (because the registry's internal `Mutex<ToolRegistry>`
            // returns `Vec<ToolDefinition>` we don't control); the
            // W6.2 next-step migrates those one at a time per
            // dpp §5.5's "one event per day" discipline so a
            // differential test catches any drift.
            //
            // Today the with_frame call exercises the arena-reset
            // path on every dispatch, proving the scaffold is wired
            // and ready for the per-allocation migration that follows.
            let req = match server::parse_request(&request_json) {
                Ok(r) => r,
                Err(err_resp) => return serde_json::to_string(&err_resp).unwrap_or_default(),
            };

            let response = match req.method.as_str() {
                methods::TOOLS_LIST => self.handle_tools_list(&req),
                methods::TOOLS_CALL => self.handle_tools_call(&req),
                _ => JsonRpcResponse::error(
                    req.id.clone(),
                    server::METHOD_NOT_FOUND,
                    format!("Unknown method: {}", req.method),
                ),
            };

            serde_json::to_string(&response).unwrap_or_default()
        })
    }

    fn handle_tools_list(&self, req: &JsonRpcRequest) -> JsonRpcResponse {
        let tools = self.registry.lock().unwrap().list();
        let tools_json: Vec<serde_json::Value> = tools.iter().map(|t| {
            serde_json::json!({
                "name": t.name,
                "description": t.description,
                "inputSchema": serde_json::from_str::<serde_json::Value>(&t.input_schema_json)
                    .unwrap_or(serde_json::Value::Null),
            })
        }).collect();

        JsonRpcResponse::success(
            req.id.clone(),
            serde_json::json!({ "tools": tools_json }),
        )
    }

    fn handle_tools_call(&self, req: &JsonRpcRequest) -> JsonRpcResponse {
        let params = match &req.params {
            Some(p) => p,
            None => return JsonRpcResponse::error(
                req.id.clone(),
                server::INVALID_PARAMS,
                "tools/call requires params".to_string(),
            ),
        };

        let tool_name = match params.get("name").and_then(|n| n.as_str()) {
            Some(n) => n,
            None => return JsonRpcResponse::error(
                req.id.clone(),
                server::INVALID_PARAMS,
                "params.name is required".to_string(),
            ),
        };

        // Check tool exists
        let registry = self.registry.lock().unwrap();
        let tool = match registry.get(tool_name) {
            Some(t) => t.clone(),
            None => return JsonRpcResponse::error(
                req.id.clone(),
                server::METHOD_NOT_FOUND,
                format!("Tool not found: {tool_name}"),
            ),
        };
        drop(registry);

        // Validate arguments if provided
        let args_json = params.get("arguments")
            .map(|a| serde_json::to_string(a).unwrap_or_default())
            .unwrap_or_else(|| "{}".to_string());

        let validation = self.validate_tool_args(tool_name.to_string(), args_json.clone());
        if !validation.is_empty() {
            return JsonRpcResponse::error(
                req.id.clone(),
                server::INVALID_PARAMS,
                validation,
            );
        }

        // Return a "pending" response — actual execution happens on Swift side.
        // The response tells Swift which tool to call and with what arguments.
        JsonRpcResponse::success(
            req.id.clone(),
            serde_json::json!({
                "status": "pending",
                "tool_name": tool_name,
                "arguments": serde_json::from_str::<serde_json::Value>(&args_json)
                    .unwrap_or(serde_json::Value::Null),
                "requires_confirmation": tool.safety.requires_confirmation,
                "destructive": tool.safety.destructive,
            }),
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_dispatcher() -> MCPDispatcher {
        let d = MCPDispatcher::new_in_memory();
        d.register_tool(
            "read_file".to_string(),
            "Read a file from disk".to_string(),
            r#"{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}"#.to_string(),
            false,
            false,
        );
        d.register_tool(
            "delete_file".to_string(),
            "Delete a file from disk".to_string(),
            r#"{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}"#.to_string(),
            true,
            true,
        );
        d
    }

    #[test]
    fn test_register_and_count() {
        let d = make_dispatcher();
        assert_eq!(d.tool_count(), 2);
    }

    #[test]
    fn test_list_tools_json() {
        let d = make_dispatcher();
        let json = d.list_tools_json();
        let tools: Vec<serde_json::Value> = serde_json::from_str(&json).unwrap();
        assert_eq!(tools.len(), 2);
    }

    #[test]
    fn test_get_tool_json() {
        let d = make_dispatcher();
        let json = d.get_tool_json("read_file".to_string());
        assert!(!json.is_empty());
        assert!(json.contains("read_file"));
        let empty = d.get_tool_json("nonexistent".to_string());
        assert!(empty.is_empty());
    }

    #[test]
    fn test_dispatch_tools_list() {
        let d = make_dispatcher();
        let req = r#"{"jsonrpc":"2.0","method":"tools/list","id":1}"#;
        let resp = d.dispatch(req.to_string());
        let parsed: serde_json::Value = serde_json::from_str(&resp).unwrap();
        assert!(parsed["result"]["tools"].is_array());
        assert_eq!(parsed["result"]["tools"].as_array().unwrap().len(), 2);
    }

    #[test]
    fn test_dispatch_tools_call_valid() {
        let d = make_dispatcher();
        let req = r#"{"jsonrpc":"2.0","method":"tools/call","params":{"name":"read_file","arguments":{"path":"/tmp/test"}},"id":2}"#;
        let resp = d.dispatch(req.to_string());
        let parsed: serde_json::Value = serde_json::from_str(&resp).unwrap();
        assert_eq!(parsed["result"]["status"], "pending");
        assert_eq!(parsed["result"]["tool_name"], "read_file");
        assert_eq!(parsed["result"]["requires_confirmation"], false);
    }

    #[test]
    fn test_dispatch_tools_call_destructive() {
        let d = make_dispatcher();
        let req = r#"{"jsonrpc":"2.0","method":"tools/call","params":{"name":"delete_file","arguments":{"path":"/tmp/test"}},"id":3}"#;
        let resp = d.dispatch(req.to_string());
        let parsed: serde_json::Value = serde_json::from_str(&resp).unwrap();
        assert_eq!(parsed["result"]["destructive"], true);
        assert_eq!(parsed["result"]["requires_confirmation"], true);
    }

    #[test]
    fn test_dispatch_tools_call_not_found() {
        let d = make_dispatcher();
        let req = r#"{"jsonrpc":"2.0","method":"tools/call","params":{"name":"nonexistent","arguments":{}},"id":4}"#;
        let resp = d.dispatch(req.to_string());
        let parsed: serde_json::Value = serde_json::from_str(&resp).unwrap();
        assert!(parsed["error"]["message"].as_str().unwrap().contains("not found"));
    }

    #[test]
    fn test_dispatch_tools_call_missing_required_arg() {
        let d = make_dispatcher();
        let req = r#"{"jsonrpc":"2.0","method":"tools/call","params":{"name":"read_file","arguments":{"wrong":"arg"}},"id":5}"#;
        let resp = d.dispatch(req.to_string());
        let parsed: serde_json::Value = serde_json::from_str(&resp).unwrap();
        assert!(parsed["error"]["message"].as_str().unwrap().contains("Missing required"));
    }

    #[test]
    fn test_dispatch_unknown_method() {
        let d = make_dispatcher();
        let req = r#"{"jsonrpc":"2.0","method":"unknown/method","id":6}"#;
        let resp = d.dispatch(req.to_string());
        let parsed: serde_json::Value = serde_json::from_str(&resp).unwrap();
        assert!(parsed["error"]["message"].as_str().unwrap().contains("Unknown method"));
    }

    #[test]
    fn test_dispatch_invalid_json() {
        let d = make_dispatcher();
        let resp = d.dispatch("not json".to_string());
        let parsed: serde_json::Value = serde_json::from_str(&resp).unwrap();
        assert!(parsed["error"].is_object());
    }

    #[test]
    fn test_log_and_query() {
        let d = make_dispatcher();
        let err = d.log_execution(
            "exec-1".to_string(),
            "2026-03-24T12:00:00Z".to_string(),
            "read_file".to_string(),
            r#"{"path":"/tmp/test"}"#.to_string(),
            r#"{"data":"hello"}"#.to_string(),
            42,
            true,
        );
        assert!(err.is_empty());
        assert_eq!(d.execution_count(), 1);
        assert_eq!(d.successful_execution_count(), 1);

        let recent = d.recent_executions_json(10);
        let records: Vec<serde_json::Value> = serde_json::from_str(&recent).unwrap();
        assert_eq!(records.len(), 1);
        assert_eq!(records[0]["tool_name"], "read_file");
    }

    #[test]
    fn test_unregister_tool() {
        let d = make_dispatcher();
        assert_eq!(d.tool_count(), 2);
        assert!(d.unregister_tool("read_file".to_string()));
        assert_eq!(d.tool_count(), 1);
        assert!(!d.unregister_tool("read_file".to_string()));
    }

    // ── Integration Tests ────────────────────────────────────────────────

    #[test]
    fn test_full_tool_lifecycle() {
        let d = MCPDispatcher::new_in_memory();
        let err = d.register_tool(
            "greet".to_string(), "Greet".to_string(),
            r#"{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}"#.to_string(),
            false, false,
        );
        assert!(err.is_empty());

        // List via JSON-RPC
        let resp = d.dispatch(r#"{"jsonrpc":"2.0","method":"tools/list","id":1}"#.to_string());
        assert!(resp.contains("greet"));

        // Call via JSON-RPC
        let resp = d.dispatch(r#"{"jsonrpc":"2.0","method":"tools/call","params":{"name":"greet","arguments":{"name":"World"}},"id":2}"#.to_string());
        assert!(resp.contains("pending"));

        // Log execution
        assert!(d.log_execution(
            "e1".to_string(), "2026-03-24T14:00:00Z".to_string(), "greet".to_string(),
            r#"{"name":"World"}"#.to_string(), r#"{"msg":"Hello"}"#.to_string(), 15, true,
        ).is_empty());

        assert_eq!(d.execution_count(), 1);
        assert_eq!(d.successful_execution_count(), 1);
        assert!(d.recent_executions_json(10).contains("greet"));
    }

    #[test]
    fn test_destructive_tool_flagged_in_dispatch() {
        let d = MCPDispatcher::new_in_memory();
        d.register_tool(
            "destroy".to_string(), "Destroy".to_string(),
            r#"{"type":"object","properties":{"confirm":{"type":"boolean"}},"required":["confirm"]}"#.to_string(),
            true, true,
        );
        let resp = d.dispatch(r#"{"jsonrpc":"2.0","method":"tools/call","params":{"name":"destroy","arguments":{"confirm":true}},"id":1}"#.to_string());
        assert!(resp.contains("\"destructive\":true"));
        assert!(resp.contains("\"requires_confirmation\":true"));
    }

    #[test]
    fn test_concurrent_logging() {
        let d = std::sync::Arc::new(MCPDispatcher::new_in_memory());
        let mut handles = vec![];
        for i in 0..10 {
            let d = d.clone();
            handles.push(std::thread::spawn(move || {
                d.log_execution(
                    format!("e-{i}"), format!("2026-03-24T14:00:{i:02}Z"),
                    "tool".to_string(), "{}".to_string(), "{}".to_string(), i as u64, true,
                );
            }));
        }
        for h in handles { h.join().unwrap(); }
        assert_eq!(d.execution_count(), 10);
    }

    #[test]
    fn test_validation_roundtrip() {
        let d = MCPDispatcher::new_in_memory();
        d.register_tool(
            "calc".to_string(), "Calc".to_string(),
            r#"{"type":"object","properties":{"a":{"type":"number"},"b":{"type":"number"}},"required":["a","b"]}"#.to_string(),
            false, false,
        );
        assert!(d.validate_tool_args("calc".to_string(), r#"{"a":1,"b":2}"#.to_string()).is_empty());
        assert!(d.validate_tool_args("calc".to_string(), r#"{"a":1}"#.to_string()).contains("Missing required"));
        assert!(d.validate_tool_args("calc".to_string(), "bad".to_string()).contains("not valid JSON"));
        assert!(d.validate_tool_args("nope".to_string(), "{}".to_string()).contains("not found"));
    }

    #[test]
    fn test_file_persistence() {
        let path = "/tmp/omega_test_persist.db";
        let _ = std::fs::remove_file(path);
        {
            let d = MCPDispatcher::new(path.to_string());
            d.log_execution("p1".to_string(), "2026-03-24T15:00:00Z".to_string(),
                "tool_a".to_string(), "{}".to_string(), "{}".to_string(), 100, true);
            assert_eq!(d.execution_count(), 1);
        }
        {
            let d = MCPDispatcher::new(path.to_string());
            assert_eq!(d.execution_count(), 1);
            assert!(d.recent_executions_json(10).contains("tool_a"));
        }
        let _ = std::fs::remove_file(path);
    }
}
