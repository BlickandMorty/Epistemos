//! omega_mcp_stdio — a stdio MCP server exposing the app's VAULT + GRAPH tools (and vault resources) to
//! EXTERNAL agents, primarily OpenCode's work agent (Architecture C "fuse beneath": OpenCode is the work
//! engine; the app's vault tools + clean-room hardening fuse in via MCP). Newline-delimited JSON-RPC over
//! stdin/stdout (the MCP stdio transport). The vault root is passed via `EPISTEMOS_VAULT_ROOT`.
//!
//! HONEST SCOPE: this server executes the RUST-side tools (vault read/write/search + the wikilink graph +
//! graph verbs + vault resources) — exactly the tools `execute_vault_tool` / the dispatcher's resource
//! handlers implement in Rust. App tools that execute Swift-side return an honest error (no fake execution);
//! exposing the full app tool surface to an external process is the follow-on (app-hosted network MCP).

use std::io::{self, BufRead, Write};

use serde_json::{json, Value};

fn main() {
    let vault_root = std::env::var("EPISTEMOS_VAULT_ROOT").unwrap_or_default();
    let dispatcher = omega_mcp::dispatcher::MCPDispatcher::new_in_memory();
    dispatcher.register_builtin_tools(); // so tools/list advertises the catalog
    if !vault_root.is_empty() {
        dispatcher.set_vault_root(vault_root.clone());
    }

    let stdin = io::stdin();
    let stdout = io::stdout();
    let mut out = stdout.lock();

    for line in stdin.lock().lines() {
        let line = match line {
            Ok(l) => l,
            Err(_) => break,
        };
        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }
        if let Some(response) = handle(&dispatcher, &vault_root, trimmed) {
            if writeln!(out, "{response}").is_err() {
                break;
            }
            let _ = out.flush();
        }
    }
}

/// Route one JSON-RPC line. `Some(response)` for requests; `None` for notifications (no reply).
pub fn handle(
    dispatcher: &omega_mcp::dispatcher::MCPDispatcher,
    vault_root: &str,
    line: &str,
) -> Option<String> {
    let req: Value = serde_json::from_str(line).ok()?;
    let id = req.get("id").cloned().unwrap_or(Value::Null);
    let method = req.get("method")?.as_str()?;
    // Diagnostic to STDERR (never stdout — that would corrupt the JSON-RPC framing). OpenCode captures MCP
    // server stderr in its logs, so "epistemos-vault Failed to get tools" becomes debuggable (which method,
    // what error) instead of opaque. 2026-06-24 owner-reported.
    eprintln!("[omega_mcp_stdio] → method={method}");
    match method {
        "initialize" => {
            // Echo the client's requested protocolVersion when present (strict MCP clients reject a server
            // that downgrades the version); fall back to the baseline we implement. Robustness for OpenCode.
            let client_version = req
                .get("params")
                .and_then(|p| p.get("protocolVersion"))
                .and_then(Value::as_str)
                .unwrap_or("2024-11-05");
            Some(
                json!({
                    "jsonrpc": "2.0", "id": id,
                    "result": {
                        "protocolVersion": client_version,
                        "capabilities": { "tools": {}, "resources": {} },
                        "serverInfo": { "name": "epistemos-vault", "version": env!("CARGO_PKG_VERSION") }
                    }
                })
                .to_string(),
            )
        }
        // MCP `ping` (spec keepalive — the MCP SDKs send it for connection health): respond with an EMPTY
        // result, per spec. Falling through to the dispatcher returned `-32601 Unknown method`, which some
        // clients treat as an unhealthy server → they DROP the connection (a real fusion break, not cosmetic).
        "ping" => Some(json!({ "jsonrpc": "2.0", "id": id, "result": {} }).to_string()),
        // Notifications (initialized, cancelled, …) carry no id and need no response.
        m if m.starts_with("notifications/") => None,
        "tools/call" => {
            let params = req.get("params");
            let name = params
                .and_then(|p| p.get("name"))
                .and_then(Value::as_str)
                .unwrap_or("");
            let args = params
                .and_then(|p| p.get("arguments"))
                .cloned()
                .unwrap_or_else(|| json!({}));
            // Execute the Rust-side vault/graph tool; wrap the ToolResult JSON as MCP tool content.
            let result_json = omega_mcp::vault::execute_vault_tool(
                vault_root.to_string(),
                name.to_string(),
                args.to_string(),
            );
            Some(
                json!({
                    "jsonrpc": "2.0", "id": id,
                    "result": { "content": [ { "type": "text", "text": result_json } ] }
                })
                .to_string(),
            )
        }
        // tools/list: served by the dispatcher, then HONESTLY SCOPED to the tools this server can actually
        // EXECUTE (tools/call routes only through execute_vault_tool = vault + graph). Advertising the full
        // app catalog here would show OpenCode phantom tools (computer-use, safari, move/delete_file, …) that
        // execute Swift-side / in-app and would fail with "Unknown vault tool" — a dishonest surface. Scope it.
        "tools/list" => {
            let scoped = scope_tools_list_to_executable(&dispatcher.dispatch(line.to_string()));
            // Count advertised tools for the stderr diagnostic (helps debug "Failed to get tools").
            let count = serde_json::from_str::<Value>(&scoped)
                .ok()
                .and_then(|v| {
                    v.get("result")
                        .and_then(|r| r.get("tools"))
                        .and_then(|t| t.as_array().map(|a| a.len()))
                })
                .unwrap_or(0);
            eprintln!("[omega_mcp_stdio] tools/list → {count} tools");
            Some(scoped)
        }
        // resources/list + resources/read are served by the dispatcher.
        _ => Some(dispatcher.dispatch(line.to_string())),
    }
}

/// Filter a `tools/list` JSON-RPC response down to the tools THIS server can execute — `is_vault_tool` (vault
/// file/search/wikilink/patch) plus `is_graph_tool` (graph verbs). Fail-OPEN: if the response can't be parsed
/// or has no `result.tools` array, it's returned unchanged (never hide tools due to a shape surprise).
fn scope_tools_list_to_executable(response: &str) -> String {
    let mut value: Value = match serde_json::from_str(response) {
        Ok(v) => v,
        Err(_) => return response.to_string(),
    };
    let Some(tools) = value
        .get_mut("result")
        .and_then(|r| r.get_mut("tools"))
        .and_then(Value::as_array_mut)
    else {
        return response.to_string();
    };
    tools.retain(|tool| {
        tool.get("name")
            .and_then(Value::as_str)
            .map(|name| {
                omega_mcp::vault::is_vault_tool(name) || omega_mcp::graph_tools::is_graph_tool(name)
            })
            .unwrap_or(false)
    });
    serde_json::to_string(&value).unwrap_or_else(|_| response.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn dispatcher_with_vault(root: &str) -> omega_mcp::dispatcher::MCPDispatcher {
        let d = omega_mcp::dispatcher::MCPDispatcher::new_in_memory();
        d.register_builtin_tools();
        d.set_vault_root(root.to_string());
        d
    }

    #[test]
    fn initialize_advertises_tools_and_resources() {
        let d = omega_mcp::dispatcher::MCPDispatcher::new_in_memory();
        let resp = handle(&d, "", r#"{"jsonrpc":"2.0","method":"initialize","id":1}"#).unwrap();
        assert!(resp.contains("epistemos-vault"), "{resp}");
        assert!(
            resp.contains("\"tools\"") && resp.contains("\"resources\""),
            "{resp}"
        );
    }

    #[test]
    fn notifications_get_no_response() {
        let d = omega_mcp::dispatcher::MCPDispatcher::new_in_memory();
        assert!(handle(
            &d,
            "",
            r#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#
        )
        .is_none());
    }

    #[test]
    fn ping_returns_empty_result_not_an_error() {
        let d = omega_mcp::dispatcher::MCPDispatcher::new_in_memory();
        let resp = handle(&d, "", r#"{"jsonrpc":"2.0","method":"ping","id":9}"#).unwrap();
        let v: Value = serde_json::from_str(&resp).unwrap();
        assert_eq!(v["id"], 9);
        assert!(
            v["result"].is_object() && v["result"].as_object().unwrap().is_empty(),
            "{resp}"
        );
        assert!(
            v.get("error").is_none(),
            "ping must NOT be an error (clients drop on ping failure): {resp}"
        );
    }

    #[test]
    fn tools_call_executes_a_real_vault_tool() {
        let dir = std::env::temp_dir().join(format!("epi_stdio_{}", std::process::id()));
        let _ = std::fs::create_dir_all(&dir);
        std::fs::write(dir.join("a.md"), "links [[b]]").unwrap();
        std::fs::write(dir.join("b.md"), "I am b").unwrap();
        let root = dir.to_string_lossy().to_string();
        let d = dispatcher_with_vault(&root);

        // tools/list comes from the dispatcher's catalog.
        let listed = handle(
            &d,
            &root,
            r#"{"jsonrpc":"2.0","method":"tools/list","id":1}"#,
        )
        .unwrap();
        assert!(listed.contains("backlinks"), "{listed}");

        // tools/call executes the Rust vault tool (backlinks: a links to b).
        let called = handle(
            &d, &root,
            r#"{"jsonrpc":"2.0","method":"tools/call","params":{"name":"backlinks","arguments":{"target":"b"}},"id":2}"#,
        ).unwrap();
        assert!(called.contains("a.md"), "{called}");
        assert!(
            called.contains("\"content\""),
            "MCP content wrapper: {called}"
        );

        // resources/list is served by the dispatcher (vault notes as resources).
        let res = handle(
            &d,
            &root,
            r#"{"jsonrpc":"2.0","method":"resources/list","id":3}"#,
        )
        .unwrap();
        assert!(res.contains("vault:///a.md"), "{res}");

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn tools_list_is_scoped_to_executable_tools() {
        // HONEST SURFACE: the fusion server advertises ONLY vault + graph tools it can actually execute —
        // never phantom computer-use/safari/move-delete tools that run in-app and would fail "Unknown vault tool".
        let d = omega_mcp::dispatcher::MCPDispatcher::new_in_memory();
        d.register_builtin_tools();
        let listed = handle(&d, "", r#"{"jsonrpc":"2.0","method":"tools/list","id":1}"#).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&listed).unwrap();
        let names: Vec<String> = parsed["result"]["tools"]
            .as_array()
            .unwrap()
            .iter()
            .map(|t| t["name"].as_str().unwrap().to_string())
            .collect();

        // executable tools are advertised…
        assert!(names.iter().any(|n| n == "backlinks"), "{names:?}");
        assert!(
            names.iter().any(|n| n == "graph.populate_from_vault"),
            "{names:?}"
        );
        assert!(names.iter().any(|n| n == "patch_note"), "{names:?}");
        // …phantom (in-app / Swift-side) tools are NOT.
        assert!(
            !names.iter().any(|n| n == "screenshot"),
            "computer-use leaked: {names:?}"
        );
        assert!(
            !names.iter().any(|n| n == "move_file"),
            "non-executable file tool leaked: {names:?}"
        );
        // every advertised tool is one the server can actually run.
        for n in &names {
            assert!(
                omega_mcp::vault::is_vault_tool(n) || omega_mcp::graph_tools::is_graph_tool(n),
                "advertised but not executable: {n}"
            );
        }
    }

    #[test]
    fn scope_filter_fails_open_on_unparseable() {
        // never hide tools because of a shape surprise — non-JSON / missing result.tools passes through.
        assert_eq!(scope_tools_list_to_executable("not json"), "not json");
        let no_tools = r#"{"jsonrpc":"2.0","id":1,"result":{}}"#;
        assert_eq!(scope_tools_list_to_executable(no_tools), no_tools);
    }
}
