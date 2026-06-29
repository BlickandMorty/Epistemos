//! WORK code-intelligence tools — ⚠️ REDUNDANT UNDER ARCHITECTURE C (re-eval owner 2026-06-21).
//!
//! ORIGINAL INTENT (addendum §134-137, convergence-era): wire the existing `lsp_runtime` RustLSP
//! into the WORK stack as agent code-intelligence tools — which assumed a Goose-engine work loop
//! with NO built-in LSP.
//!
//! SUPERSEDED by Architecture C's refinement #2: the work engine is OpenCode, which has its OWN
//! BUILT-IN LSP (auto-loads 40+ servers). Forcing `lsp_runtime` into the OpenCode work loop would be
//! a DOUBLE-LSP. So under C this module is REDUNDANT for the work loop; `lsp_runtime` is kept for the
//! NATIVE EDITORS (Prose/Epdoc), not work. KEPT (not blind-deleted) pending the OpenCode runtime
//! vendor — once OpenCode's built-in LSP is confirmed in-tree, this module is removed. Until then it
//! stays compiled + tested behind the `lsp-runtime` feature so nothing rots. Do NOT build new callers.
//!
//! HONEST CAPABILITY (CLAUDE.md "honest capability gating"): only the kernel-BACKED
//! methods are exposed as tools — `textDocument/didOpen|didChange|didClose`,
//! `textDocument/hover` (tree-sitter semantic), and `textDocument/definition`
//! (same-file). `diagnostics` and `edit` are NOT yet backed by the kernel, so they are
//! intentionally NOT advertised here (wiring a fake tool would violate honest gating);
//! they land once the kernel grows `textDocument/publishDiagnostics` + an edit handler.
//!
//! Isolated like the `work` seam — nothing in agent_loop / agent_runtime references it,
//! so Chat/Act are unchanged.

use serde_json::{json, Value};

use crate::lsp_runtime::{LspId, LspMessage};

/// A WORK code-intelligence tool call — each variant maps to a REAL LSP method the
/// `LspKernel` handles. The work agent constructs these; `to_lsp_message` lowers them
/// to the wire form the kernel dispatches.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum WorkCodeTool {
    /// `textDocument/didOpen` — register a file's text with the kernel (notification).
    OpenDocument {
        uri: String,
        language_id: String,
        version: i64,
        text: String,
    },
    /// `textDocument/didChange` — replace a registered file's full text (notification).
    ChangeDocument {
        uri: String,
        version: i64,
        text: String,
    },
    /// `textDocument/didClose` — drop a registered file (notification).
    CloseDocument { uri: String },
    /// `textDocument/hover` — tree-sitter semantic hover at a position (request).
    Hover {
        uri: String,
        line: u32,
        character: u32,
    },
    /// `textDocument/definition` — same-file definition at a position (request).
    Definition {
        uri: String,
        line: u32,
        character: u32,
    },
}

impl WorkCodeTool {
    /// Stable agent-facing tool name (what the WORK agent calls).
    pub fn tool_name(&self) -> &'static str {
        match self {
            WorkCodeTool::OpenDocument { .. } => "lsp_open_document",
            WorkCodeTool::ChangeDocument { .. } => "lsp_change_document",
            WorkCodeTool::CloseDocument { .. } => "lsp_close_document",
            WorkCodeTool::Hover { .. } => "lsp_hover",
            WorkCodeTool::Definition { .. } => "lsp_definition",
        }
    }

    /// The exact LSP method this tool lowers to (kernel-backed, no fabricated methods).
    pub fn lsp_method(&self) -> &'static str {
        match self {
            WorkCodeTool::OpenDocument { .. } => "textDocument/didOpen",
            WorkCodeTool::ChangeDocument { .. } => "textDocument/didChange",
            WorkCodeTool::CloseDocument { .. } => "textDocument/didClose",
            WorkCodeTool::Hover { .. } => "textDocument/hover",
            WorkCodeTool::Definition { .. } => "textDocument/definition",
        }
    }

    /// True for the request/response tools (hover/definition); false for the
    /// fire-and-forget document-lifecycle notifications. Determines whether the caller
    /// should poll the kernel for a response.
    pub fn expects_response(&self) -> bool {
        matches!(
            self,
            WorkCodeTool::Hover { .. } | WorkCodeTool::Definition { .. }
        )
    }

    /// Lower the tool call to the wire-form `LspMessage` the kernel dispatches. The
    /// `id` is only used by the request variants; notifications ignore it.
    pub fn to_lsp_message(&self, id: LspId) -> LspMessage {
        match self {
            WorkCodeTool::OpenDocument {
                uri,
                language_id,
                version,
                text,
            } => LspMessage::Notification {
                method: self.lsp_method().to_string(),
                params: Some(json!({
                    "textDocument": {
                        "uri": uri,
                        "languageId": language_id,
                        "version": version,
                        "text": text,
                    }
                })),
            },
            WorkCodeTool::ChangeDocument { uri, version, text } => LspMessage::Notification {
                method: self.lsp_method().to_string(),
                params: Some(json!({
                    "textDocument": { "uri": uri, "version": version },
                    "contentChanges": [ { "text": text } ],
                })),
            },
            WorkCodeTool::CloseDocument { uri } => LspMessage::Notification {
                method: self.lsp_method().to_string(),
                params: Some(json!({ "textDocument": { "uri": uri } })),
            },
            WorkCodeTool::Hover {
                uri,
                line,
                character,
            }
            | WorkCodeTool::Definition {
                uri,
                line,
                character,
            } => LspMessage::Request {
                id,
                method: self.lsp_method().to_string(),
                params: Some(json!({
                    "textDocument": { "uri": uri },
                    "position": { "line": line, "character": character },
                })),
            },
        }
    }
}

/// The code-intelligence tools the WORK agent ADVERTISES — only the kernel-backed ones
/// (honest capability gating). `diagnostics` / `edit` are deliberately absent until the
/// kernel grows handlers for them.
pub fn advertised_work_code_tools() -> &'static [&'static str] {
    &[
        "lsp_open_document",
        "lsp_change_document",
        "lsp_close_document",
        "lsp_hover",
        "lsp_definition",
    ]
}

/// Drive a hover/definition tool against an already-initialized `LspKernel`: send the
/// request, then drain the kernel's outbox for the matching response. Reuses the real
/// kernel — this is the wiring that gives the WORK agent code understanding. Returns the
/// response `result` value, or `None` if the kernel produced no matching success.
pub fn run_query_tool(
    kernel: &crate::lsp_runtime::LspKernel,
    tool: &WorkCodeTool,
    id: LspId,
) -> Option<Value> {
    if !tool.expects_response() {
        // Notifications are driven via `send` directly; this helper is for queries.
        return None;
    }
    kernel.send(tool.to_lsp_message(id.clone())).ok()?;
    while let Ok(Some(message)) = kernel.poll_response() {
        if let LspMessage::ResponseSuccess {
            id: resp_id,
            result,
        } = message
        {
            if resp_id == id {
                return Some(result);
            }
        }
    }
    None
}

/// Drive a document-lifecycle tool (didOpen/didChange/didClose) against the kernel.
pub fn run_lifecycle_tool(
    kernel: &crate::lsp_runtime::LspKernel,
    tool: &WorkCodeTool,
) -> Result<(), crate::lsp_runtime::LspKernelError> {
    // The lifecycle tools are notifications — `id` is ignored by `to_lsp_message`.
    kernel.send(tool.to_lsp_message(LspId::Int(0)))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::lsp_runtime::LspKernel;

    #[test]
    fn tool_names_and_methods_are_stable_and_kernel_backed() {
        let open = WorkCodeTool::OpenDocument {
            uri: "file:///x.rs".into(),
            language_id: "rust".into(),
            version: 1,
            text: "fn a() {}".into(),
        };
        assert_eq!(open.tool_name(), "lsp_open_document");
        assert_eq!(open.lsp_method(), "textDocument/didOpen");
        assert!(!open.expects_response());

        let hover = WorkCodeTool::Hover {
            uri: "file:///x.rs".into(),
            line: 0,
            character: 3,
        };
        assert_eq!(hover.tool_name(), "lsp_hover");
        assert_eq!(hover.lsp_method(), "textDocument/hover");
        assert!(hover.expects_response());

        let def = WorkCodeTool::Definition {
            uri: "file:///x.rs".into(),
            line: 0,
            character: 3,
        };
        assert_eq!(def.lsp_method(), "textDocument/definition");
    }

    #[test]
    fn open_lowers_to_spec_correct_didopen_notification() {
        let tool = WorkCodeTool::OpenDocument {
            uri: "file:///x.rs".into(),
            language_id: "rust".into(),
            version: 7,
            text: "fn a() {}".into(),
        };
        match tool.to_lsp_message(LspId::Int(0)) {
            LspMessage::Notification { method, params } => {
                assert_eq!(method, "textDocument/didOpen");
                let td = &params.unwrap()["textDocument"];
                assert_eq!(td["uri"], "file:///x.rs");
                assert_eq!(td["languageId"], "rust");
                assert_eq!(td["version"], 7);
                assert_eq!(td["text"], "fn a() {}");
            }
            other => panic!("expected didOpen notification, got {other:?}"),
        }
    }

    #[test]
    fn hover_lowers_to_spec_correct_request_with_position() {
        let tool = WorkCodeTool::Hover {
            uri: "file:///x.rs".into(),
            line: 1,
            character: 12,
        };
        match tool.to_lsp_message(LspId::Int(42)) {
            LspMessage::Request { id, method, params } => {
                assert_eq!(id, LspId::Int(42));
                assert_eq!(method, "textDocument/hover");
                let p = params.unwrap();
                assert_eq!(p["textDocument"]["uri"], "file:///x.rs");
                assert_eq!(p["position"]["line"], 1);
                assert_eq!(p["position"]["character"], 12);
            }
            other => panic!("expected hover request, got {other:?}"),
        }
    }

    #[test]
    fn advertises_only_kernel_backed_tools_not_fake_diagnostics_or_edit() {
        let tools = advertised_work_code_tools();
        assert!(tools.contains(&"lsp_hover"));
        assert!(tools.contains(&"lsp_definition"));
        // Honest gating: diagnostics/edit are NOT backed by the kernel yet → not advertised.
        assert!(!tools.contains(&"lsp_diagnostics"));
        assert!(!tools.contains(&"lsp_edit"));
    }

    #[test]
    fn work_tools_drive_a_real_hover_through_the_actual_kernel() {
        // REAL-STATE proof: the WORK tools, lowered through the SAME LspKernel the Swift
        // RustLSPTransport drives, produce genuine tree-sitter code intelligence.
        let kernel = LspKernel::new();
        // initialize (flips lifecycle so subsequent methods dispatch).
        kernel
            .send(LspMessage::Request {
                id: LspId::Int(1),
                method: "initialize".into(),
                params: None,
            })
            .unwrap();
        let _ = kernel.poll_response().unwrap();

        let uri = "file:///tmp/semantic.rs";
        let text = "fn answer() -> i32 { 42 }\nfn main() { answer(); }\n";
        run_lifecycle_tool(
            &kernel,
            &WorkCodeTool::OpenDocument {
                uri: uri.into(),
                language_id: "rust".into(),
                version: 1,
                text: text.into(),
            },
        )
        .unwrap();

        let hover = WorkCodeTool::Hover {
            uri: uri.into(),
            line: 1,
            character: 12,
        };
        let result = run_query_tool(&kernel, &hover, LspId::Int(2)).expect("hover result");
        let rendered = serde_json::to_string(&result).unwrap();
        assert!(rendered.contains("answer"), "hover: {rendered}");
        assert!(rendered.contains("function_item"), "hover: {rendered}");
    }

    #[test]
    fn definition_tool_resolves_same_file_location_through_the_kernel() {
        let kernel = LspKernel::new();
        kernel
            .send(LspMessage::Request {
                id: LspId::Int(1),
                method: "initialize".into(),
                params: None,
            })
            .unwrap();
        let _ = kernel.poll_response().unwrap();

        let uri = "file:///tmp/semantic.rs";
        run_lifecycle_tool(
            &kernel,
            &WorkCodeTool::OpenDocument {
                uri: uri.into(),
                language_id: "rust".into(),
                version: 1,
                text: "fn answer() -> i32 { 42 }\nfn main() { answer(); }\n".into(),
            },
        )
        .unwrap();

        let def = WorkCodeTool::Definition {
            uri: uri.into(),
            line: 1,
            character: 12,
        };
        let result = run_query_tool(&kernel, &def, LspId::Int(2)).expect("definition result");
        let rendered = serde_json::to_string(&result).unwrap();
        assert!(rendered.contains("semantic.rs"), "definition: {rendered}");
    }
}
