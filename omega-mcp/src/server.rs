// JSON-RPC 2.0 protocol types for MCP.
// Wire protocol parsing — not a full server yet.
// The embedded MCP server will be built on top of these types.

use serde::{Deserialize, Serialize};

/// JSON-RPC 2.0 request.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonRpcRequest {
    pub jsonrpc: String,
    pub method: String,
    pub params: Option<serde_json::Value>,
    pub id: Option<serde_json::Value>,
}

/// JSON-RPC 2.0 response.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonRpcResponse {
    pub jsonrpc: String,
    pub result: Option<serde_json::Value>,
    pub error: Option<JsonRpcError>,
    pub id: Option<serde_json::Value>,
}

/// JSON-RPC 2.0 error object.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonRpcError {
    pub code: i64,
    pub message: String,
    pub data: Option<serde_json::Value>,
}

// Standard JSON-RPC error codes
pub const PARSE_ERROR: i64 = -32700;
pub const INVALID_REQUEST: i64 = -32600;
pub const METHOD_NOT_FOUND: i64 = -32601;
pub const INVALID_PARAMS: i64 = -32602;
pub const INTERNAL_ERROR: i64 = -32603;

impl JsonRpcRequest {
    pub fn new(method: impl Into<String>, params: serde_json::Value, id: u64) -> Self {
        Self {
            jsonrpc: "2.0".to_string(),
            method: method.into(),
            params: Some(params),
            id: Some(serde_json::Value::Number(id.into())),
        }
    }

    pub fn notification(method: impl Into<String>, params: serde_json::Value) -> Self {
        Self {
            jsonrpc: "2.0".to_string(),
            method: method.into(),
            params: Some(params),
            id: None,
        }
    }
}

impl JsonRpcResponse {
    pub fn success(id: Option<serde_json::Value>, result: serde_json::Value) -> Self {
        JsonRpcResponse {
            jsonrpc: "2.0".to_string(),
            result: Some(result),
            error: None,
            id,
        }
    }

    pub fn error(id: Option<serde_json::Value>, code: i64, message: impl Into<String>) -> Self {
        JsonRpcResponse {
            jsonrpc: "2.0".to_string(),
            result: None,
            error: Some(JsonRpcError {
                code,
                message: message.into(),
                data: None,
            }),
            id,
        }
    }
}

/// Parse a JSON-RPC request from a string.
pub fn parse_request(input: &str) -> Result<JsonRpcRequest, JsonRpcResponse> {
    let req: JsonRpcRequest = serde_json::from_str(input)
        .map_err(|e| JsonRpcResponse::error(None, PARSE_ERROR, format!("Parse error: {e}")))?;

    if req.jsonrpc != "2.0" {
        return Err(JsonRpcResponse::error(
            req.id.clone(),
            INVALID_REQUEST,
            "jsonrpc must be \"2.0\"".to_string(),
        ));
    }

    if req.method.is_empty() {
        return Err(JsonRpcResponse::error(
            req.id.clone(),
            INVALID_REQUEST,
            "method must not be empty".to_string(),
        ));
    }

    Ok(req)
}

/// MCP method names (subset for tool operations).
pub mod methods {
    pub const TOOLS_LIST: &str = "tools/list";
    pub const TOOLS_CALL: &str = "tools/call";
    pub const RESOURCES_LIST: &str = "resources/list";
    pub const RESOURCES_READ: &str = "resources/read";
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_valid_request() {
        let input = r#"{"jsonrpc":"2.0","method":"tools/list","id":1}"#;
        let req = parse_request(input).unwrap();
        assert_eq!(req.method, "tools/list");
        assert_eq!(req.id, Some(serde_json::json!(1)));
    }

    #[test]
    fn test_parse_request_with_params() {
        let input = r#"{"jsonrpc":"2.0","method":"tools/call","params":{"name":"test","arguments":{}},"id":"abc"}"#;
        let req = parse_request(input).unwrap();
        assert_eq!(req.method, "tools/call");
        assert!(req.params.is_some());
    }

    #[test]
    fn test_parse_invalid_json() {
        let result = parse_request("not json");
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert_eq!(err.error.unwrap().code, PARSE_ERROR);
    }

    #[test]
    fn test_parse_wrong_version() {
        let input = r#"{"jsonrpc":"1.0","method":"test","id":1}"#;
        let result = parse_request(input);
        assert!(result.is_err());
    }

    #[test]
    fn test_parse_empty_method() {
        let input = r#"{"jsonrpc":"2.0","method":"","id":1}"#;
        let result = parse_request(input);
        assert!(result.is_err());
    }

    #[test]
    fn test_response_success() {
        let resp =
            JsonRpcResponse::success(Some(serde_json::json!(1)), serde_json::json!({"tools": []}));
        assert!(resp.result.is_some());
        assert!(resp.error.is_none());
    }

    #[test]
    fn test_response_error() {
        let resp = JsonRpcResponse::error(
            Some(serde_json::json!(1)),
            METHOD_NOT_FOUND,
            "not found".to_string(),
        );
        assert!(resp.result.is_none());
        assert_eq!(resp.error.unwrap().code, METHOD_NOT_FOUND);
    }
}
