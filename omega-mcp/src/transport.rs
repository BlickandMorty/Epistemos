// ── MCP Stdio Transport ────────────────────────────────────────────────────
//
// Newline-delimited JSON-RPC stdio transport layer for omega-mcp.
// Enables bidirectional MCP communication with external processes
// (preparation for Hermes bridge in Sprint Omega-2).
//
// StdioTransport: client-side, wraps child process stdin/stdout
// StdioServer: server-side, accepts JSON-RPC on own stdin/stdout

use crate::server::{JsonRpcRequest, JsonRpcResponse};
use serde::Serialize;
use std::io::{self, BufRead, Write};

/// Errors specific to the MCP stdio transport layer.
#[derive(Debug, thiserror::Error)]
pub enum TransportError {
    #[error("IO error: {0}")]
    Io(#[from] io::Error),
    #[error("JSON parse error: {0}")]
    JsonParse(#[from] serde_json::Error),
    #[error("transport closed")]
    Closed,
    #[error("malformed message: {0}")]
    MalformedMessage(String),
}

/// Client-side stdio transport for communicating with a child process.
///
/// Wraps a child process's stdin (for sending) and stdout (for receiving).
/// Messages are newline-delimited JSON.
pub struct StdioTransport<W: Write, R: BufRead> {
    writer: W,
    reader: R,
}

impl<W: Write, R: BufRead> StdioTransport<W, R> {
    pub fn new(writer: W, reader: R) -> Self {
        Self { writer, reader }
    }

    /// Send a JSON-RPC message as a newline-delimited JSON line.
    pub fn send(&mut self, request: &str) -> Result<(), TransportError> {
        // Validate it's valid JSON before sending.
        let _: serde_json::Value = serde_json::from_str(request)?;

        self.writer.write_all(request.as_bytes())?;
        self.writer.write_all(b"\n")?;
        self.writer.flush()?;
        Ok(())
    }

    /// Send a typed JSON-RPC request.
    pub fn send_request(&mut self, request: &JsonRpcRequest) -> Result<(), TransportError> {
        let json = serialize_transport_message(request)?;
        self.send(&json)
    }

    /// Receive one JSON line from the transport.
    pub fn receive(&mut self) -> Result<String, TransportError> {
        let mut line = String::new();
        let bytes_read = self.reader.read_line(&mut line)?;
        if bytes_read == 0 {
            return Err(TransportError::Closed);
        }
        let trimmed = line.trim().to_string();
        if trimmed.is_empty() {
            return Err(TransportError::MalformedMessage(
                "empty line received".to_string(),
            ));
        }
        // Validate it's valid JSON.
        let _: serde_json::Value = serde_json::from_str(&trimmed)?;
        Ok(trimmed)
    }

    /// Receive and parse a JSON-RPC response.
    pub fn receive_response(&mut self) -> Result<JsonRpcResponse, TransportError> {
        let line = self.receive()?;
        let response: JsonRpcResponse = serde_json::from_str(&line)?;
        Ok(response)
    }
}

/// Server-side stdio transport that accepts JSON-RPC on stdin/stdout.
///
/// Used when Epistemos IS the MCP server being called by an external process.
pub struct StdioServer<W: Write, R: BufRead> {
    writer: W,
    reader: R,
}

impl<W: Write, R: BufRead> StdioServer<W, R> {
    pub fn new(writer: W, reader: R) -> Self {
        Self { writer, reader }
    }

    /// Read the next incoming JSON-RPC request.
    pub fn receive_request(&mut self) -> Result<JsonRpcRequest, TransportError> {
        let mut line = String::new();
        let bytes_read = self.reader.read_line(&mut line)?;
        if bytes_read == 0 {
            return Err(TransportError::Closed);
        }
        let trimmed = line.trim();
        if trimmed.is_empty() {
            return Err(TransportError::MalformedMessage(
                "empty line received".to_string(),
            ));
        }
        let request: JsonRpcRequest = serde_json::from_str(trimmed)?;
        Ok(request)
    }

    /// Send a JSON-RPC response.
    pub fn send_response(&mut self, response: &JsonRpcResponse) -> Result<(), TransportError> {
        let json = serialize_transport_message(response)?;
        // Never write non-JSON to stdout (preserve transport cleanliness).
        self.writer.write_all(json.as_bytes())?;
        self.writer.write_all(b"\n")?;
        self.writer.flush()?;
        Ok(())
    }

    /// Send a success response.
    pub fn send_success(
        &mut self,
        result: serde_json::Value,
        id: serde_json::Value,
    ) -> Result<(), TransportError> {
        self.send_response(&JsonRpcResponse::success(Some(id), result))
    }

    /// Send an error response.
    pub fn send_error(
        &mut self,
        code: i64,
        message: &str,
        id: Option<serde_json::Value>,
    ) -> Result<(), TransportError> {
        self.send_response(&JsonRpcResponse::error(id, code, message))
    }
}

fn serialize_transport_message<T: Serialize>(message: &T) -> Result<String, TransportError> {
    let mut value = serde_json::to_value(message)?;
    strip_null_fields(&mut value);
    Ok(serde_json::to_string(&value)?)
}

fn strip_null_fields(value: &mut serde_json::Value) {
    match value {
        serde_json::Value::Object(object) => {
            object.retain(|_, child| {
                strip_null_fields(child);
                !child.is_null()
            });
        }
        serde_json::Value::Array(items) => {
            for item in items {
                strip_null_fields(item);
            }
        }
        _ => {}
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::server;
    use std::io::Cursor;

    #[test]
    fn round_trip_json_rpc_encode_decode() {
        let request = JsonRpcRequest::new("tools/list", serde_json::json!({}), 1);

        // Encode to a buffer.
        let mut write_buf = Vec::new();
        let read_buf = Cursor::new(Vec::new());
        let mut transport = StdioTransport::new(&mut write_buf, read_buf);
        transport.send_request(&request).unwrap();

        // Decode from the buffer.
        let written = String::from_utf8(write_buf).unwrap();
        assert!(written.ends_with('\n'));
        let trimmed = written.trim();
        let decoded: JsonRpcRequest = serde_json::from_str(trimmed).unwrap();
        assert_eq!(decoded.method, "tools/list");
        assert_eq!(decoded.jsonrpc, "2.0");
        assert_eq!(decoded.id, Some(serde_json::json!(1)));
    }

    #[test]
    fn newline_delimiting() {
        let mut write_buf = Vec::new();
        let read_buf = Cursor::new(Vec::new());
        let mut transport = StdioTransport::new(&mut write_buf, read_buf);

        let req1 = JsonRpcRequest::new("method1", serde_json::json!({}), 1);
        let req2 = JsonRpcRequest::new("method2", serde_json::json!({}), 2);
        transport.send_request(&req1).unwrap();
        transport.send_request(&req2).unwrap();

        let written = String::from_utf8(write_buf).unwrap();
        let lines: Vec<&str> = written.trim().split('\n').collect();
        assert_eq!(lines.len(), 2);
        assert!(lines[0].contains("method1"));
        assert!(lines[1].contains("method2"));
    }

    #[test]
    fn malformed_json_handling() {
        let input = b"not valid json\n";
        let read_buf = Cursor::new(input.to_vec());
        let write_buf = Vec::new();
        let mut transport = StdioTransport::new(write_buf, read_buf);

        let result = transport.receive();
        assert!(result.is_err());
        match result {
            Err(TransportError::JsonParse(_)) => {} // expected
            other => panic!("Expected JsonParse error, got: {other:?}"),
        }
    }

    #[test]
    fn receive_valid_json_line() {
        let json = r#"{"jsonrpc":"2.0","method":"tools/list","id":1}"#;
        let input = format!("{json}\n");
        let read_buf = Cursor::new(input.into_bytes());
        let write_buf = Vec::new();
        let mut transport = StdioTransport::new(write_buf, read_buf);

        let received = transport.receive().unwrap();
        assert_eq!(received, json);
    }

    #[test]
    fn closed_transport_returns_error() {
        let read_buf = Cursor::new(Vec::new()); // empty = EOF
        let write_buf = Vec::new();
        let mut transport = StdioTransport::new(write_buf, read_buf);

        let result = transport.receive();
        assert!(matches!(result, Err(TransportError::Closed)));
    }

    #[test]
    fn server_round_trip() {
        // Create a request, send it to a server, get a response back.
        let request_json = r#"{"jsonrpc":"2.0","method":"tools/list","params":{},"id":42}"#;
        let input = format!("{request_json}\n");

        let read_buf = Cursor::new(input.into_bytes());
        let mut write_buf = Vec::new();
        let mut server = StdioServer::new(&mut write_buf, read_buf);

        let request = server.receive_request().unwrap();
        assert_eq!(request.method, "tools/list");

        server
            .send_success(serde_json::json!({"tools": []}), request.id.unwrap())
            .unwrap();

        let written = String::from_utf8(write_buf).unwrap();
        let response: JsonRpcResponse = serde_json::from_str(written.trim()).unwrap();
        assert!(response.result.is_some());
        assert_eq!(response.id, Some(serde_json::json!(42)));
    }

    #[test]
    fn json_rpc_error_response() {
        let response =
            JsonRpcResponse::error(Some(serde_json::json!(1)), -32601, "Method not found");
        let json = serde_json::to_string(&response).unwrap();
        let decoded: JsonRpcResponse = serde_json::from_str(&json).unwrap();
        assert!(decoded.error.is_some());
        assert_eq!(decoded.error.unwrap().code, -32601);
    }

    #[test]
    fn transport_response_serialization_omits_null_fields() {
        let read_buf = Cursor::new(Vec::new());
        let mut write_buf = Vec::new();
        let mut transport = StdioServer::new(&mut write_buf, read_buf);
        let response = JsonRpcResponse::error(None, -32601, "Method not found");

        transport.send_response(&response).unwrap();

        let written = String::from_utf8(write_buf).unwrap();
        assert!(!written.contains("\"id\""));
        assert!(!written.contains("\"data\""));
        assert!(!written.contains("\"result\""));
    }

    #[test]
    fn transport_accepts_canonical_server_json_rpc_response() {
        let read_buf = Cursor::new(Vec::new());
        let mut write_buf = Vec::new();
        let mut transport = StdioServer::new(&mut write_buf, read_buf);
        let response = server::JsonRpcResponse::success(
            Some(serde_json::json!(7)),
            serde_json::json!({"ok": true}),
        );

        transport.send_response(&response).unwrap();

        let written = String::from_utf8(write_buf).unwrap();
        let decoded: server::JsonRpcResponse = serde_json::from_str(written.trim()).unwrap();
        assert_eq!(decoded.id, Some(serde_json::json!(7)));
        assert_eq!(decoded.result, Some(serde_json::json!({"ok": true})));
    }
}
