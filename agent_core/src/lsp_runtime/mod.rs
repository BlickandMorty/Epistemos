// HARDENING ENFORCEMENT: this module is the canonical seam between
// Swift's `LSPClient` and an in-process Rust LSP runtime. A panic in
// any handler would corrupt the FFI message stream and look like a
// transport failure to Swift. Every error path returns a typed
// JSON-RPC error response. No unwrap/expect/panic in production paths.
#![cfg_attr(
    not(test),
    deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)
)]

//! V2.3 in-process LSP runtime — Phase 1.
//!
//! Doctrine reference: `docs/V2_3_LSP_MIGRATION_PLAN_2026_05_05.md`.
//!
//! This module is the Rust side of the V2.3 LSP migration — the
//! in-process replacement for `Epistemos/Engine/LSPServerProcess.swift`
//! (the Foundation `Process`-based subprocess wrapper). The first
//! slice handles the LSP `initialize` + `shutdown` + `exit` lifecycle
//! handshake. Hover, definition, document sync land in subsequent
//! slices when the surface justifies adding tower-lsp + tree-sitter
//! crates (see the doctrine's "Slice 2" section).
//!
//! ## Why hand-rolled instead of tower-lsp
//!
//! For the initialize-only subset, the LSP wire format is small
//! enough to write directly. Pulling in `tower-lsp` + `lsp-types` +
//! their indirect deps for one round trip is net negative compile
//! time. When Slice 2 adds hover/definition + tree-sitter parsing,
//! the surface justifies the framework. This stays modular: the
//! `LspKernel` API doesn't change when we swap the implementation.
//!
//! ## Threading model
//!
//! `LspKernel` is `Send + Sync` via internal `Mutex`. The two FFI
//! entry points (`lsp_send_message_json` + `lsp_poll_response_json`,
//! see `bridge.rs`) operate on a process-global instance. Swift
//! drives via:
//!   1. `lsp_send_message_json(json)` — push a request into the
//!      kernel; the response (or notification ack) is queued for
//!      the next poll.
//!   2. `lsp_poll_response_json()` — pull the next queued message,
//!      or empty string if none ready.
//!
//! This polling shape is intentional: LSP is request/response, not
//! truly streaming, so a poll loop on Swift's side is cheap and
//! avoids exposing a callback FFI surface. Swift's existing
//! `LSPTransport` protocol's `messages: AsyncStream<LSPMessage>`
//! gets fed by a Swift-side polling task in the
//! `RustLSPTransport` Swift wrapper.

use std::collections::VecDeque;
use std::sync::Mutex;

use serde::{Deserialize, Serialize};
use serde_json::Value;
use thiserror::Error;

// ── JSON-RPC envelope types ────────────────────────────────────────────────

/// JSON-RPC 2.0 message envelope. Mirrors the LSP spec's allowed
/// shapes: request, notification, success response, error response.
/// The `jsonrpc: "2.0"` field is required by the spec but elided here
/// for storage — every emit-side helper writes it explicitly.
#[derive(Debug, Clone, PartialEq)]
pub enum LspMessage {
    /// Request from Swift to kernel. Has an id for response matching.
    Request {
        id: LspId,
        method: String,
        params: Option<Value>,
    },
    /// Notification from Swift to kernel (no id, no response).
    Notification {
        method: String,
        params: Option<Value>,
    },
    /// Success response from kernel to Swift.
    ResponseSuccess { id: LspId, result: Value },
    /// Error response from kernel to Swift.
    ResponseError {
        id: Option<LspId>,
        error: LspError,
    },
}

/// JSON-RPC id — either an integer or a string per the spec.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(untagged)]
pub enum LspId {
    Int(i64),
    String(String),
}

/// Standard JSON-RPC + LSP error codes per the spec.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Error)]
#[error("LSP error {code}: {message}")]
pub struct LspError {
    pub code: i32,
    pub message: String,
    pub data: Option<Value>,
}

impl LspError {
    /// JSON-RPC -32601 — method not found.
    pub fn method_not_found(method: &str) -> Self {
        Self {
            code: -32601,
            message: format!("LSP method not implemented: {method}"),
            data: None,
        }
    }

    /// LSP -32002 — server not initialized.
    pub fn server_not_initialized() -> Self {
        Self {
            code: -32002,
            message: "Server received request before initialize completed".to_string(),
            data: None,
        }
    }

    /// JSON-RPC -32700 — parse error.
    pub fn parse_error(detail: &str) -> Self {
        Self {
            code: -32700,
            message: format!("LSP message parse error: {detail}"),
            data: None,
        }
    }

    /// JSON-RPC -32600 — invalid request.
    pub fn invalid_request(detail: &str) -> Self {
        Self {
            code: -32600,
            message: format!("LSP invalid request: {detail}"),
            data: None,
        }
    }
}

// ── LSP kernel ─────────────────────────────────────────────────────────────

/// Lifecycle states per the LSP spec §6.1: an initialize request
/// must precede any other request; a shutdown request must precede
/// the exit notification.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum LifecycleState {
    /// Pre-initialize. Only `initialize` is accepted.
    Uninitialized,
    /// Post-initialize, pre-shutdown. All ops accepted.
    Initialized,
    /// Post-shutdown, pre-exit. Only `exit` notification is accepted;
    /// other requests return server-not-initialized error.
    ShuttingDown,
    /// Post-exit. The server has finished — every send is a no-op.
    Exited,
}

/// In-process LSP server for the Epistemos editor surface.
///
/// **Phase 1 scope (this slice):** initialize + shutdown + exit
/// lifecycle handshake. Every other request returns
/// `LspError::method_not_found`. This is enough to prove the
/// architectural seam works end-to-end (Swift LSPClient ↔ Rust
/// LspKernel ↔ initialize roundtrip) without committing to the
/// hover/definition + tree-sitter dep surface.
pub struct LspKernel {
    state: Mutex<KernelState>,
}

struct KernelState {
    lifecycle: LifecycleState,
    /// Queue of messages destined for Swift. Kernel-to-Swift
    /// responses + notifications land here; Swift drains via
    /// `lsp_poll_response_json`.
    outbox: VecDeque<LspMessage>,
}

impl Default for LspKernel {
    fn default() -> Self {
        Self::new()
    }
}

impl LspKernel {
    pub fn new() -> Self {
        Self {
            state: Mutex::new(KernelState {
                lifecycle: LifecycleState::Uninitialized,
                outbox: VecDeque::new(),
            }),
        }
    }

    /// Send a message into the kernel. Errors during dispatch are
    /// queued as JSON-RPC error responses on the outbox; this
    /// function only returns Err for transport-level failures
    /// (mutex poison etc.) that callers can't recover from inline.
    pub fn send(&self, message: LspMessage) -> Result<(), LspKernelError> {
        let mut state = self.state.lock().map_err(|_| LspKernelError::MutexPoisoned)?;
        if state.lifecycle == LifecycleState::Exited {
            // After exit, all sends are silent no-ops per LSP §6.1.
            return Ok(());
        }
        match message {
            LspMessage::Request { id, method, params } => {
                let response = self.dispatch_request(&mut state, id.clone(), &method, params);
                state.outbox.push_back(response);
            }
            LspMessage::Notification { method, params } => {
                self.dispatch_notification(&mut state, &method, params);
            }
            LspMessage::ResponseSuccess { .. } | LspMessage::ResponseError { .. } => {
                // Phase 1 doesn't issue server-initiated requests, so
                // any client-side response must be unsolicited. Drop
                // silently per LSP §6.4 ("server should ignore").
            }
        }
        Ok(())
    }

    /// Pull the next queued outbound message, if any. Returns None
    /// when the outbox is empty. Swift polls this on a background
    /// task to drive the `messages` AsyncStream on `RustLSPTransport`.
    pub fn poll_response(&self) -> Result<Option<LspMessage>, LspKernelError> {
        let mut state = self.state.lock().map_err(|_| LspKernelError::MutexPoisoned)?;
        Ok(state.outbox.pop_front())
    }

    /// Diagnostics: current lifecycle state. Read-only; useful for
    /// the V2 wire-up tests + Settings → Diagnostics row.
    pub fn lifecycle_state_debug(&self) -> &'static str {
        match self.state.lock().map(|s| s.lifecycle) {
            Ok(LifecycleState::Uninitialized) => "uninitialized",
            Ok(LifecycleState::Initialized) => "initialized",
            Ok(LifecycleState::ShuttingDown) => "shutting_down",
            Ok(LifecycleState::Exited) => "exited",
            Err(_) => "poisoned",
        }
    }

    // ── Dispatch helpers ───────────────────────────────────────────────────

    fn dispatch_request(
        &self,
        state: &mut KernelState,
        id: LspId,
        method: &str,
        _params: Option<Value>,
    ) -> LspMessage {
        // Lifecycle gate: only `initialize` is allowed in Uninitialized.
        if state.lifecycle == LifecycleState::Uninitialized && method != "initialize" {
            return LspMessage::ResponseError {
                id: Some(id),
                error: LspError::server_not_initialized(),
            };
        }
        match method {
            "initialize" => {
                state.lifecycle = LifecycleState::Initialized;
                LspMessage::ResponseSuccess {
                    id,
                    result: serve_capabilities(),
                }
            }
            "shutdown" => {
                state.lifecycle = LifecycleState::ShuttingDown;
                // shutdown returns null per the spec.
                LspMessage::ResponseSuccess {
                    id,
                    result: Value::Null,
                }
            }
            other => LspMessage::ResponseError {
                id: Some(id),
                error: LspError::method_not_found(other),
            },
        }
    }

    fn dispatch_notification(
        &self,
        state: &mut KernelState,
        method: &str,
        _params: Option<Value>,
    ) {
        match method {
            "initialized" => {
                // The client tells us initialization is complete; we
                // don't need to reply but we can use this as a cue to
                // start any deferred work. Phase 1 does no such work.
            }
            "exit" => {
                state.lifecycle = LifecycleState::Exited;
                state.outbox.clear();
            }
            _ => {
                // Unknown notification — drop per LSP §6.4.
            }
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum LspKernelError {
    #[error("LSP kernel mutex poisoned")]
    MutexPoisoned,
}

/// Phase-1 server capabilities. Declares the textDocumentSync +
/// hoverProvider + definitionProvider fields so a Swift client can
/// see what we'll eventually support, but the actual hover /
/// definition handlers return MethodNotFound until Slice 2 lands.
fn serve_capabilities() -> Value {
    serde_json::json!({
        "capabilities": {
            "textDocumentSync": 1, // Full document sync
            "hoverProvider": true,
            "definitionProvider": true,
        },
        "serverInfo": {
            "name": "epistemos-lsp-runtime",
            "version": env!("CARGO_PKG_VERSION"),
        }
    })
}

// ── JSON serialization helpers ─────────────────────────────────────────────

/// Decode an `LspMessage` from a JSON-RPC 2.0 wire string. Used by
/// the FFI entry point `lsp_send_message_json` to parse Swift-side
/// envelopes.
pub fn decode_message(json: &str) -> Result<LspMessage, LspError> {
    let value: Value = serde_json::from_str(json).map_err(|e| LspError::parse_error(&e.to_string()))?;
    let obj = value
        .as_object()
        .ok_or_else(|| LspError::invalid_request("top-level must be object"))?;

    // Reject anything not declaring jsonrpc 2.0 — defensive against
    // accidental v1 tooling.
    let jsonrpc = obj.get("jsonrpc").and_then(|v| v.as_str()).unwrap_or("");
    if jsonrpc != "2.0" {
        return Err(LspError::invalid_request(
            "missing or wrong jsonrpc version (expected 2.0)",
        ));
    }

    // The 4 envelope shapes are distinguished by which fields are present.
    let id = obj.get("id").map(decode_id);
    let method = obj.get("method").and_then(|v| v.as_str()).map(String::from);
    let result = obj.get("result").cloned();
    let error = obj.get("error").cloned();
    let params = obj.get("params").cloned();

    match (id, method, result, error) {
        (Some(Some(id)), Some(method), None, None) => Ok(LspMessage::Request { id, method, params }),
        (None, Some(method), None, None) => Ok(LspMessage::Notification { method, params }),
        (Some(Some(id)), None, Some(result), None) => {
            Ok(LspMessage::ResponseSuccess { id, result })
        }
        (id_opt, None, None, Some(err_value)) => {
            let error: LspError = serde_json::from_value(err_value)
                .map_err(|e| LspError::parse_error(&format!("error envelope: {e}")))?;
            Ok(LspMessage::ResponseError {
                id: id_opt.flatten(),
                error,
            })
        }
        _ => Err(LspError::invalid_request(
            "envelope shape doesn't match request/notification/response/error",
        )),
    }
}

fn decode_id(value: &Value) -> Option<LspId> {
    if let Some(i) = value.as_i64() {
        Some(LspId::Int(i))
    } else if let Some(s) = value.as_str() {
        Some(LspId::String(s.to_string()))
    } else {
        None
    }
}

/// Encode an `LspMessage` to a JSON-RPC 2.0 wire string. Used by
/// the FFI entry point `lsp_poll_response_json` to ship outbound
/// messages back to Swift.
pub fn encode_message(message: &LspMessage) -> String {
    let value = match message {
        LspMessage::Request { id, method, params } => {
            let mut obj = serde_json::json!({
                "jsonrpc": "2.0",
                "id": id,
                "method": method,
            });
            if let Some(p) = params {
                obj["params"] = p.clone();
            }
            obj
        }
        LspMessage::Notification { method, params } => {
            let mut obj = serde_json::json!({
                "jsonrpc": "2.0",
                "method": method,
            });
            if let Some(p) = params {
                obj["params"] = p.clone();
            }
            obj
        }
        LspMessage::ResponseSuccess { id, result } => serde_json::json!({
            "jsonrpc": "2.0",
            "id": id,
            "result": result,
        }),
        LspMessage::ResponseError { id, error } => serde_json::json!({
            "jsonrpc": "2.0",
            "id": id,
            "error": error,
        }),
    };
    // unwrap_or_default: if serialization somehow fails (it won't —
    // Value is already a serde_json type), return empty string and
    // the consumer treats it as no-message.
    serde_json::to_string(&value).unwrap_or_default()
}

// ── Process-global kernel + tests ──────────────────────────────────────────

use std::sync::OnceLock;

/// Process-global LSP kernel instance. The bridge.rs FFI surface
/// (`lsp_send_message_json` / `lsp_poll_response_json`) operates on
/// this instance. Mirrors the cognitive_dag / provenance_ledger
/// pattern for shared state.
pub fn global_kernel() -> &'static LspKernel {
    static KERNEL: OnceLock<LspKernel> = OnceLock::new();
    KERNEL.get_or_init(LspKernel::new)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn req(id: i64, method: &str) -> LspMessage {
        LspMessage::Request {
            id: LspId::Int(id),
            method: method.to_string(),
            params: None,
        }
    }

    #[test]
    fn fresh_kernel_is_uninitialized() {
        let k = LspKernel::new();
        assert_eq!(k.lifecycle_state_debug(), "uninitialized");
    }

    #[test]
    fn initialize_request_returns_capabilities_and_advances_lifecycle() {
        let k = LspKernel::new();
        k.send(req(1, "initialize")).unwrap();
        assert_eq!(k.lifecycle_state_debug(), "initialized");
        let response = k.poll_response().unwrap().expect("must have a response");
        match response {
            LspMessage::ResponseSuccess { id, result } => {
                assert_eq!(id, LspId::Int(1));
                assert!(result.get("capabilities").is_some());
                assert!(result.get("serverInfo").is_some());
            }
            other => panic!("expected ResponseSuccess, got {other:?}"),
        }
    }

    #[test]
    fn pre_initialize_request_returns_server_not_initialized_error() {
        let k = LspKernel::new();
        k.send(req(1, "textDocument/hover")).unwrap();
        let response = k.poll_response().unwrap().expect("must have response");
        match response {
            LspMessage::ResponseError { error, .. } => {
                assert_eq!(error.code, -32002);
            }
            other => panic!("expected error, got {other:?}"),
        }
    }

    #[test]
    fn unknown_post_initialize_request_returns_method_not_found() {
        let k = LspKernel::new();
        k.send(req(1, "initialize")).unwrap();
        let _ = k.poll_response().unwrap();
        k.send(req(2, "textDocument/hover")).unwrap();
        let response = k.poll_response().unwrap().expect("must have response");
        match response {
            LspMessage::ResponseError { error, .. } => {
                assert_eq!(error.code, -32601);
                assert!(error.message.contains("textDocument/hover"));
            }
            other => panic!("expected error, got {other:?}"),
        }
    }

    #[test]
    fn shutdown_then_exit_lifecycle() {
        let k = LspKernel::new();
        k.send(req(1, "initialize")).unwrap();
        let _ = k.poll_response();
        k.send(req(2, "shutdown")).unwrap();
        assert_eq!(k.lifecycle_state_debug(), "shutting_down");
        let shutdown_response = k.poll_response().unwrap().expect("shutdown response");
        match shutdown_response {
            LspMessage::ResponseSuccess { result, .. } => assert_eq!(result, Value::Null),
            other => panic!("expected null success, got {other:?}"),
        }
        k.send(LspMessage::Notification {
            method: "exit".into(),
            params: None,
        })
        .unwrap();
        assert_eq!(k.lifecycle_state_debug(), "exited");
    }

    #[test]
    fn json_round_trip_request() {
        let original = req(42, "initialize");
        let encoded = encode_message(&original);
        let decoded = decode_message(&encoded).unwrap();
        assert_eq!(decoded, original);
    }

    #[test]
    fn json_round_trip_notification() {
        let original = LspMessage::Notification {
            method: "initialized".into(),
            params: Some(serde_json::json!({})),
        };
        let encoded = encode_message(&original);
        let decoded = decode_message(&encoded).unwrap();
        assert_eq!(decoded, original);
    }

    #[test]
    fn json_round_trip_success_response() {
        let original = LspMessage::ResponseSuccess {
            id: LspId::Int(7),
            result: serve_capabilities(),
        };
        let encoded = encode_message(&original);
        let decoded = decode_message(&encoded).unwrap();
        assert_eq!(decoded, original);
    }

    #[test]
    fn json_round_trip_error_response() {
        let original = LspMessage::ResponseError {
            id: Some(LspId::Int(11)),
            error: LspError::method_not_found("foo"),
        };
        let encoded = encode_message(&original);
        let decoded = decode_message(&encoded).unwrap();
        assert_eq!(decoded, original);
    }

    #[test]
    fn decode_rejects_bad_jsonrpc_version() {
        let json = r#"{"jsonrpc":"1.0","id":1,"method":"initialize"}"#;
        match decode_message(json) {
            Err(e) => assert_eq!(e.code, -32600),
            Ok(other) => panic!("expected error, got {other:?}"),
        }
    }

    #[test]
    fn decode_rejects_malformed_json() {
        match decode_message("not json") {
            Err(e) => assert_eq!(e.code, -32700),
            Ok(other) => panic!("expected error, got {other:?}"),
        }
    }

    #[test]
    fn after_exit_sends_are_silent_noops() {
        let k = LspKernel::new();
        k.send(req(1, "initialize")).unwrap();
        let _ = k.poll_response();
        k.send(req(2, "shutdown")).unwrap();
        let _ = k.poll_response();
        k.send(LspMessage::Notification {
            method: "exit".into(),
            params: None,
        })
        .unwrap();
        // Now any further send is a no-op + no response queued.
        k.send(req(3, "textDocument/hover")).unwrap();
        assert!(k.poll_response().unwrap().is_none());
    }

    #[test]
    fn client_response_envelopes_are_silently_dropped() {
        let k = LspKernel::new();
        k.send(req(1, "initialize")).unwrap();
        let _ = k.poll_response();
        k.send(LspMessage::ResponseSuccess {
            id: LspId::Int(99),
            result: Value::Null,
        })
        .unwrap();
        // No response queued — server-side phase 1 doesn't issue
        // server-initiated requests so any client response is
        // unsolicited.
        assert!(k.poll_response().unwrap().is_none());
    }

    #[test]
    fn global_kernel_is_singleton() {
        let k1 = global_kernel();
        let k2 = global_kernel();
        assert!(std::ptr::eq(k1, k2));
    }
}
