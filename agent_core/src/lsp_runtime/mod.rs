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
//! (the Foundation `Process`-based subprocess wrapper). It uses
//! `tower-lsp`'s canonical LSP types for response payloads and
//! tree-sitter Rust/Swift grammars for semantic hover + same-file
//! definition lookup.
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

use std::collections::{BTreeMap, VecDeque};
use std::sync::Mutex;

use serde::{Deserialize, Serialize};
use serde_json::Value;
use thiserror::Error;
use tower_lsp::lsp_types as lsp;
use tree_sitter::{Node as TsNode, Parser};

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
/// **V2.3 semantic scope:** initialize + document cache +
/// tree-sitter hover + same-file definition + shutdown/exit. This
/// closes the old subprocess transport without reducing the editor
/// surface to a lifecycle-only stub.
pub struct LspKernel {
    state: Mutex<KernelState>,
}

struct KernelState {
    lifecycle: LifecycleState,
    /// Queue of messages destined for Swift. Kernel-to-Swift
    /// responses + notifications land here; Swift drains via
    /// `lsp_poll_response_json`.
    outbox: VecDeque<LspMessage>,
    /// In-memory document cache keyed by LSP URI. This replaces the old
    /// subprocess server's implicit process-local document state while
    /// staying inside the Rust kernel.
    documents: BTreeMap<String, LspDocument>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct LspDocument {
    uri: String,
    language_id: String,
    version: i64,
    text: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum LanguageKind {
    Rust,
    Swift,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct SymbolHit {
    name: String,
    range: lsp::Range,
    node_kind: String,
    declaration: Option<String>,
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
                documents: BTreeMap::new(),
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
        params: Option<Value>,
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
            "textDocument/hover" => self.handle_hover(state, id, params.as_ref()),
            "textDocument/definition" => self.handle_definition(state, id, params.as_ref()),
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
        params: Option<Value>,
    ) {
        match method {
            "initialized" => {
                // The client tells us initialization is complete; we
                // don't need to reply but we can use this as a cue to
                // start any deferred work. Phase 1 does no such work.
            }
            "textDocument/didOpen" => {
                if let Some(document) = parse_did_open(params.as_ref()) {
                    state.documents.insert(document.uri.clone(), document);
                }
            }
            "textDocument/didChange" => {
                apply_did_change(&mut state.documents, params.as_ref());
            }
            "textDocument/didClose" => {
                if let Some(uri) = text_document_uri(params.as_ref()) {
                    state.documents.remove(uri);
                }
            }
            "exit" => {
                state.lifecycle = LifecycleState::Exited;
                state.outbox.clear();
                state.documents.clear();
            }
            _ => {
                // Unknown notification — drop per LSP §6.4.
            }
        }
    }

    fn handle_hover(
        &self,
        state: &KernelState,
        id: LspId,
        params: Option<&Value>,
    ) -> LspMessage {
        let Some((uri, line, character)) = request_uri_position(params) else {
            return LspMessage::ResponseError {
                id: Some(id),
                error: LspError::invalid_request("hover params missing textDocument.uri or position"),
            };
        };
        let result = state
            .documents
            .get(uri)
            .and_then(|doc| semantic_hover(doc, line, character))
            .and_then(|hover| serde_json::to_value(hover).ok())
            .unwrap_or(Value::Null);
        LspMessage::ResponseSuccess { id, result }
    }

    fn handle_definition(
        &self,
        state: &KernelState,
        id: LspId,
        params: Option<&Value>,
    ) -> LspMessage {
        let Some((uri, line, character)) = request_uri_position(params) else {
            return LspMessage::ResponseError {
                id: Some(id),
                error: LspError::invalid_request(
                    "definition params missing textDocument.uri or position",
                ),
            };
        };
        let result = state
            .documents
            .get(uri)
            .and_then(|doc| semantic_definition(doc, line, character))
            .and_then(|location| serde_json::to_value(location).ok())
            .unwrap_or(Value::Null);
        LspMessage::ResponseSuccess { id, result }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum LspKernelError {
    #[error("LSP kernel mutex poisoned")]
    MutexPoisoned,
}

/// Server capabilities emitted through tower-lsp's canonical LSP
/// structs. Hover + definition are backed by tree-sitter handlers in
/// this module, so the capability flags are no longer aspirational.
fn serve_capabilities() -> Value {
    let result = lsp::InitializeResult {
        capabilities: lsp::ServerCapabilities {
            text_document_sync: Some(lsp::TextDocumentSyncCapability::Kind(
                lsp::TextDocumentSyncKind::FULL,
            )),
            hover_provider: Some(lsp::HoverProviderCapability::Simple(true)),
            definition_provider: Some(lsp::OneOf::Left(true)),
            ..Default::default()
        },
        server_info: Some(lsp::ServerInfo {
            name: "epistemos-lsp-runtime".to_string(),
            version: Some(env!("CARGO_PKG_VERSION").to_string()),
        }),
    };
    serde_json::to_value(result).unwrap_or_else(|_| Value::Object(Default::default()))
}

fn parse_did_open(params: Option<&Value>) -> Option<LspDocument> {
    let doc = params?.get("textDocument")?.as_object()?;
    let uri = doc.get("uri")?.as_str()?.to_string();
    let language_id = doc
        .get("languageId")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();
    let version = doc.get("version").and_then(Value::as_i64).unwrap_or(0);
    let text = doc.get("text")?.as_str()?.to_string();
    Some(LspDocument {
        uri,
        language_id,
        version,
        text,
    })
}

fn apply_did_change(documents: &mut BTreeMap<String, LspDocument>, params: Option<&Value>) {
    let Some(uri) = text_document_uri(params) else {
        return;
    };
    let version = params
        .and_then(|p| p.get("textDocument"))
        .and_then(|d| d.get("version"))
        .and_then(Value::as_i64);
    let Some(changes) = params
        .and_then(|p| p.get("contentChanges"))
        .and_then(Value::as_array)
    else {
        return;
    };
    let Some(text) = changes
        .iter()
        .rev()
        .find_map(|change| change.get("text").and_then(Value::as_str))
    else {
        return;
    };
    if let Some(doc) = documents.get_mut(uri) {
        doc.text = text.to_string();
        if let Some(version) = version {
            doc.version = version;
        }
    }
}

fn text_document_uri(params: Option<&Value>) -> Option<&str> {
    params?
        .get("textDocument")?
        .get("uri")?
        .as_str()
}

fn request_uri_position(params: Option<&Value>) -> Option<(&str, u32, u32)> {
    let params = params?;
    let uri = text_document_uri(Some(params))?;
    let position = params.get("position")?.as_object()?;
    let line = position.get("line")?.as_u64()?.try_into().ok()?;
    let character = position.get("character")?.as_u64()?.try_into().ok()?;
    Some((uri, line, character))
}

fn semantic_hover(doc: &LspDocument, line: u32, character: u32) -> Option<lsp::Hover> {
    let parsed = parse_document(doc)?;
    let offset = byte_offset_for_lsp_position(&doc.text, line, character)?;
    let root = parsed.root_node();
    let symbol = symbol_at_offset(root, &doc.text, offset)?;
    let definition = find_definition_for_symbol(root, &doc.text, &symbol.name);
    let definition_declaration = definition.and_then(enclosing_declaration);
    let node_kind = definition_declaration
        .map(|node| node.kind().to_string())
        .unwrap_or_else(|| symbol.node_kind.clone());
    let declaration = definition_declaration
        .and_then(|node| node_text(node, &doc.text).map(str::to_string))
        .or(symbol.declaration)
        .unwrap_or_else(|| node_kind.clone());
    let contents = format!(
        "`{}` — {}\n\n```{}\n{}\n```",
        symbol.name,
        node_kind,
        parsed.language.label(),
        declaration.trim()
    );
    Some(lsp::Hover {
        contents: lsp::HoverContents::Scalar(lsp::MarkedString::String(contents)),
        range: Some(symbol.range),
    })
}

fn semantic_definition(doc: &LspDocument, line: u32, character: u32) -> Option<lsp::Location> {
    let parsed = parse_document(doc)?;
    let offset = byte_offset_for_lsp_position(&doc.text, line, character)?;
    let root = parsed.root_node();
    let symbol = symbol_at_offset(root, &doc.text, offset)?;
    let definition = find_definition_for_symbol(root, &doc.text, &symbol.name)?;
    let range = range_for_node(definition, &doc.text);
    let uri = lsp::Url::parse(&doc.uri).ok()?;
    Some(lsp::Location { uri, range })
}

struct ParsedDocument {
    tree: tree_sitter::Tree,
    language: LanguageKind,
}

impl ParsedDocument {
    fn root_node(&self) -> TsNode<'_> {
        self.tree.root_node()
    }
}

impl LanguageKind {
    fn label(self) -> &'static str {
        match self {
            LanguageKind::Rust => "rust",
            LanguageKind::Swift => "swift",
        }
    }
}

fn parse_document(doc: &LspDocument) -> Option<ParsedDocument> {
    let language = language_for_document(doc)?;
    let mut parser = Parser::new();
    let grammar: tree_sitter::Language = match language {
        LanguageKind::Rust => tree_sitter_rust::LANGUAGE.into(),
        LanguageKind::Swift => tree_sitter_swift::LANGUAGE.into(),
    };
    parser.set_language(&grammar).ok()?;
    let tree = parser.parse(&doc.text, None)?;
    Some(ParsedDocument { tree, language })
}

fn language_for_document(doc: &LspDocument) -> Option<LanguageKind> {
    let lang = doc.language_id.to_ascii_lowercase();
    if lang == "rust" || lang == "rs" {
        return Some(LanguageKind::Rust);
    }
    if lang == "swift" {
        return Some(LanguageKind::Swift);
    }
    if doc.uri.ends_with(".rs") {
        return Some(LanguageKind::Rust);
    }
    if doc.uri.ends_with(".swift") {
        return Some(LanguageKind::Swift);
    }
    None
}

fn symbol_at_offset(root: TsNode<'_>, source: &str, offset: usize) -> Option<SymbolHit> {
    let end = offset.saturating_add(1).min(source.len());
    let mut cursor = root.descendant_for_byte_range(offset, end)?;
    loop {
        if is_identifier_kind(cursor.kind()) {
            let name = node_text(cursor, source)?;
            let declaration = enclosing_declaration(cursor)
                .and_then(|node| node_text(node, source))
                .map(str::to_string);
            let node_kind = enclosing_declaration(cursor)
                .map(|node| node.kind().to_string())
                .unwrap_or_else(|| cursor.kind().to_string());
            return Some(SymbolHit {
                name: name.to_string(),
                range: range_for_node(cursor, source),
                node_kind,
                declaration,
            });
        }
        if let Some(name_node) = declaration_name_node(cursor) {
            let name = node_text(name_node, source)?;
            return Some(SymbolHit {
                name: name.to_string(),
                range: range_for_node(name_node, source),
                node_kind: cursor.kind().to_string(),
                declaration: node_text(cursor, source).map(str::to_string),
            });
        }
        cursor = cursor.parent()?;
    }
}

fn find_definition_for_symbol<'tree>(
    root: TsNode<'tree>,
    source: &str,
    symbol: &str,
) -> Option<TsNode<'tree>> {
    let mut stack = vec![root];
    while let Some(node) = stack.pop() {
        if is_definition_kind(node.kind()) {
            if let Some(name_node) = declaration_name_node(node) {
                if node_text(name_node, source) == Some(symbol) {
                    return Some(name_node);
                }
            }
        }
        let mut cursor = node.walk();
        for child in node.children(&mut cursor) {
            stack.push(child);
        }
    }
    None
}

fn enclosing_declaration(mut node: TsNode<'_>) -> Option<TsNode<'_>> {
    loop {
        if is_definition_kind(node.kind()) {
            return Some(node);
        }
        node = node.parent()?;
    }
}

fn declaration_name_node(node: TsNode<'_>) -> Option<TsNode<'_>> {
    if let Some(name) = node.child_by_field_name("name") {
        return Some(name);
    }
    let mut cursor = node.walk();
    let name = node
        .children(&mut cursor)
        .find(|child| is_identifier_kind(child.kind()));
    name
}

fn is_identifier_kind(kind: &str) -> bool {
    matches!(
        kind,
        "identifier"
            | "type_identifier"
            | "field_identifier"
            | "shorthand_property_identifier"
            | "simple_identifier"
            | "identifier_pattern"
    ) || kind.ends_with("_identifier")
}

fn is_definition_kind(kind: &str) -> bool {
    matches!(
        kind,
        "function_item"
            | "struct_item"
            | "enum_item"
            | "trait_item"
            | "mod_item"
            | "const_item"
            | "static_item"
            | "type_item"
            | "field_declaration"
            | "function_declaration"
            | "class_declaration"
            | "struct_declaration"
            | "enum_declaration"
            | "protocol_declaration"
            | "actor_declaration"
            | "property_declaration"
            | "variable_declaration"
            | "typealias_declaration"
    )
}

fn node_text<'a>(node: TsNode<'_>, source: &'a str) -> Option<&'a str> {
    node.utf8_text(source.as_bytes()).ok()
}

fn range_for_node(node: TsNode<'_>, source: &str) -> lsp::Range {
    let start = lsp_position_for_byte_offset(source, node.start_byte());
    let end = lsp_position_for_byte_offset(source, node.end_byte());
    lsp::Range { start, end }
}

fn byte_offset_for_lsp_position(source: &str, line: u32, character: u32) -> Option<usize> {
    let target_line = usize::try_from(line).ok()?;
    let target_character = usize::try_from(character).ok()?;
    let mut current_line = 0usize;
    let mut current_utf16 = 0usize;
    for (idx, ch) in source.char_indices() {
        if current_line == target_line && current_utf16 >= target_character {
            return Some(idx);
        }
        if ch == '\n' {
            if current_line == target_line {
                return Some(idx);
            }
            current_line += 1;
            current_utf16 = 0;
        } else if current_line == target_line {
            current_utf16 += ch.len_utf16();
        }
    }
    if current_line == target_line {
        Some(source.len())
    } else {
        None
    }
}

fn lsp_position_for_byte_offset(source: &str, offset: usize) -> lsp::Position {
    let safe_offset = offset.min(source.len());
    let mut line = 0u32;
    let mut line_start = 0usize;
    for (idx, ch) in source.char_indices() {
        if idx >= safe_offset {
            break;
        }
        if ch == '\n' {
            line = line.saturating_add(1);
            line_start = idx + ch.len_utf8();
        }
    }
    let character = source
        .get(line_start..safe_offset)
        .map(|s| s.chars().map(char::len_utf16).sum::<usize>())
        .and_then(|c| u32::try_from(c).ok())
        .unwrap_or(0);
    lsp::Position { line, character }
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

    fn req_params(id: i64, method: &str, params: Value) -> LspMessage {
        LspMessage::Request {
            id: LspId::Int(id),
            method: method.to_string(),
            params: Some(params),
        }
    }

    fn note(method: &str, params: Value) -> LspMessage {
        LspMessage::Notification {
            method: method.to_string(),
            params: Some(params),
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
        k.send(req(2, "workspace/unknown")).unwrap();
        let response = k.poll_response().unwrap().expect("must have response");
        match response {
            LspMessage::ResponseError { error, .. } => {
                assert_eq!(error.code, -32601);
                assert!(error.message.contains("workspace/unknown"));
            }
            other => panic!("expected error, got {other:?}"),
        }
    }

    #[test]
    fn did_open_then_hover_returns_tree_sitter_rust_symbol() {
        let k = LspKernel::new();
        k.send(req(1, "initialize")).unwrap();
        let _ = k.poll_response().unwrap();
        let uri = "file:///tmp/semantic.rs";
        let text = "fn answer() -> i32 { 42 }\nfn main() { answer(); }\n";
        k.send(note(
            "textDocument/didOpen",
            serde_json::json!({
                "textDocument": {
                    "uri": uri,
                    "languageId": "rust",
                    "version": 1,
                    "text": text
                }
            }),
        ))
        .unwrap();
        k.send(req_params(
            2,
            "textDocument/hover",
            serde_json::json!({
                "textDocument": { "uri": uri },
                "position": { "line": 1, "character": 12 }
            }),
        ))
        .unwrap();
        let response = k.poll_response().unwrap().expect("hover response");
        match response {
            LspMessage::ResponseSuccess { result, .. } => {
                let rendered = serde_json::to_string(&result).unwrap();
                assert!(rendered.contains("answer"), "hover response: {rendered}");
                assert!(rendered.contains("function_item"), "hover response: {rendered}");
            }
            other => panic!("expected hover success, got {other:?}"),
        }
    }

    #[test]
    fn did_open_then_definition_returns_same_file_rust_location() {
        let k = LspKernel::new();
        k.send(req(1, "initialize")).unwrap();
        let _ = k.poll_response().unwrap();
        let uri = "file:///tmp/semantic.rs";
        let text = "fn answer() -> i32 { 42 }\nfn main() { answer(); }\n";
        k.send(note(
            "textDocument/didOpen",
            serde_json::json!({
                "textDocument": {
                    "uri": uri,
                    "languageId": "rust",
                    "version": 1,
                    "text": text
                }
            }),
        ))
        .unwrap();
        k.send(req_params(
            2,
            "textDocument/definition",
            serde_json::json!({
                "textDocument": { "uri": uri },
                "position": { "line": 1, "character": 12 }
            }),
        ))
        .unwrap();
        let response = k.poll_response().unwrap().expect("definition response");
        match response {
            LspMessage::ResponseSuccess { result, .. } => {
                assert_eq!(result["uri"], uri);
                assert_eq!(result["range"]["start"]["line"], 0);
                assert_eq!(result["range"]["start"]["character"], 3);
            }
            other => panic!("expected definition success, got {other:?}"),
        }
    }

    #[test]
    fn did_change_updates_document_before_semantic_hover() {
        let k = LspKernel::new();
        k.send(req(1, "initialize")).unwrap();
        let _ = k.poll_response().unwrap();
        let uri = "file:///tmp/semantic.swift";
        k.send(note(
            "textDocument/didOpen",
            serde_json::json!({
                "textDocument": {
                    "uri": uri,
                    "languageId": "swift",
                    "version": 1,
                    "text": "func oldName() -> String { \"old\" }\nlet value = oldName()\n"
                }
            }),
        ))
        .unwrap();
        k.send(note(
            "textDocument/didChange",
            serde_json::json!({
                "textDocument": { "uri": uri, "version": 2 },
                "contentChanges": [{
                    "text": "func newName() -> String { \"new\" }\nlet value = newName()\n"
                }]
            }),
        ))
        .unwrap();
        k.send(req_params(
            2,
            "textDocument/hover",
            serde_json::json!({
                "textDocument": { "uri": uri },
                "position": { "line": 1, "character": 12 }
            }),
        ))
        .unwrap();
        let response = k.poll_response().unwrap().expect("hover response");
        match response {
            LspMessage::ResponseSuccess { result, .. } => {
                let rendered = serde_json::to_string(&result).unwrap();
                assert!(rendered.contains("newName"), "hover should use changed text: {rendered}");
                assert!(!rendered.contains("oldName"), "stale text leaked into hover: {rendered}");
            }
            other => panic!("expected hover success, got {other:?}"),
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
