// UniFFI-exported free functions for Swift interop.
// These are the Swift-callable entry points defined in omega_mcp.udl.

use crate::server;

// Note: For Phase 0, we export stateless utility functions.
// Stateful objects (ToolRegistry, ExecutionLogger) are managed in Swift
// and call into Rust for individual operations via these functions.

/// Parse a JSON-RPC 2.0 request string. Returns the method and params as JSON.
/// On error, returns the error response JSON.
pub fn parse_jsonrpc_request(input: String) -> String {
    match server::parse_request(&input) {
        Ok(req) => serde_json::to_string(&req).unwrap_or_default(),
        Err(err_resp) => serde_json::to_string(&err_resp).unwrap_or_default(),
    }
}

/// Create a JSON-RPC success response.
pub fn jsonrpc_success(id_json: String, result_json: String) -> String {
    let id: Option<serde_json::Value> = serde_json::from_str(&id_json).ok();
    let result: serde_json::Value = serde_json::from_str(&result_json)
        .unwrap_or(serde_json::Value::Null);
    let resp = server::JsonRpcResponse::success(id, result);
    serde_json::to_string(&resp).unwrap_or_default()
}

/// Create a JSON-RPC error response.
pub fn jsonrpc_error(id_json: String, code: i64, message: String) -> String {
    let id: Option<serde_json::Value> = serde_json::from_str(&id_json).ok();
    let resp = server::JsonRpcResponse::error(id, code, message);
    serde_json::to_string(&resp).unwrap_or_default()
}

/// Validate tool arguments JSON against a schema JSON.
/// Returns empty string on success, error message on failure.
pub fn validate_tool_args(schema_json: String, args_json: String) -> String {
    // Basic validation: parse both as JSON, check args is object,
    // check required fields present
    let args: serde_json::Value = match serde_json::from_str(&args_json) {
        Ok(v) => v,
        Err(e) => return format!("Invalid arguments JSON: {e}"),
    };

    if !args.is_object() {
        return "Arguments must be a JSON object".to_string();
    }

    if let Ok(schema) = serde_json::from_str::<serde_json::Value>(&schema_json) {
        if let Some(required) = schema.get("required").and_then(|r| r.as_array()) {
            let obj = args.as_object().unwrap();
            for req in required {
                if let Some(key) = req.as_str() {
                    if !obj.contains_key(key) {
                        return format!("Missing required argument: {key}");
                    }
                }
            }
        }
    }

    String::new() // empty = valid
}
