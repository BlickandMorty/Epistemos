//! Real-transport e2e for the OpenCode WORK fusion seam (Architecture C). The in-process `handle()` unit
//! tests cover routing logic; THIS test proves the COMPILED `omega_mcp_stdio` binary works exactly as OpenCode
//! drives it — spawned as a subprocess, fed newline-delimited JSON-RPC over real stdin, responses read off real
//! stdout, vault root via `EPISTEMOS_VAULT_ROOT`. Covers the transport half of the progress map's "REMAINS:
//! app-build + GUI launch-smoke" (the GUI half needs the running app; the protocol half is provable headless).

use std::io::Write;
use std::process::{Command, Stdio};

use serde_json::Value;

#[test]
fn fusion_stdio_real_transport_handshake_and_tool_call() {
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path();
    std::fs::write(root.join("a.md"), "links to [[b]]").unwrap();
    std::fs::write(root.join("b.md"), "I am b").unwrap();

    let mut child = Command::new(env!("CARGO_BIN_EXE_omega_mcp_stdio"))
        .env("EPISTEMOS_VAULT_ROOT", root)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .expect("spawn omega_mcp_stdio");

    // Drive the exact sequence an MCP client (OpenCode) does: initialize, the initialized notification (no
    // reply expected), tools/list, then a real vault tool call. Then close stdin → the server loop ends → exit.
    {
        let mut stdin = child.stdin.take().unwrap();
        writeln!(stdin, r#"{{"jsonrpc":"2.0","method":"initialize","id":1}}"#).unwrap();
        writeln!(stdin, r#"{{"jsonrpc":"2.0","method":"notifications/initialized"}}"#).unwrap();
        writeln!(stdin, r#"{{"jsonrpc":"2.0","method":"tools/list","id":2}}"#).unwrap();
        writeln!(
            stdin,
            r#"{{"jsonrpc":"2.0","method":"tools/call","params":{{"name":"backlinks","arguments":{{"target":"b"}}}},"id":3}}"#
        )
        .unwrap();
        // a keepalive ping (MCP clients send these) must get an empty-result reply, not an error/drop.
        writeln!(stdin, r#"{{"jsonrpc":"2.0","method":"ping","id":4}}"#).unwrap();
    } // stdin dropped here → EOF

    let out = child.wait_with_output().expect("wait omega_mcp_stdio");
    assert!(out.status.success(), "server exited non-zero: {:?}", out.status);
    let stdout = String::from_utf8(out.stdout).unwrap();
    let lines: Vec<&str> = stdout.lines().filter(|l| !l.trim().is_empty()).collect();
    // initialize + tools/list + tools/call + ping get replies; the notification does NOT → exactly 4 lines.
    assert_eq!(lines.len(), 4, "expected 4 responses (notification is silent): {stdout}");

    let init: Value = serde_json::from_str(lines[0]).unwrap();
    assert_eq!(init["id"], 1);
    assert_eq!(init["result"]["serverInfo"]["name"], "epistemos-vault");
    assert_eq!(init["result"]["protocolVersion"], "2024-11-05");

    let list: Value = serde_json::from_str(lines[1]).unwrap();
    assert_eq!(list["id"], 2);
    let names: Vec<&str> = list["result"]["tools"]
        .as_array()
        .unwrap()
        .iter()
        .map(|t| t["name"].as_str().unwrap())
        .collect();
    // executable vault/graph tools are advertised over the real transport…
    assert!(names.contains(&"backlinks"), "{names:?}");
    assert!(names.contains(&"link_candidates"), "newest tool reachable over real stdio: {names:?}");
    assert!(names.contains(&"graph.populate_from_vault"), "{names:?}");
    // …phantom in-app tools are scoped out (honest surface, end-to-end).
    assert!(!names.contains(&"screenshot"), "computer-use leaked over transport: {names:?}");

    let call: Value = serde_json::from_str(lines[2]).unwrap();
    assert_eq!(call["id"], 3);
    let text = call["result"]["content"][0]["text"].as_str().unwrap();
    assert!(text.contains("a.md"), "backlinks(b) should report a.md links to it: {text}");

    // ping over the real transport → empty result, never an error (else the client drops the fusion).
    let ping: Value = serde_json::from_str(lines[3]).unwrap();
    assert_eq!(ping["id"], 4);
    assert!(ping["result"].is_object() && ping.get("error").is_none(), "ping reply: {}", lines[3]);
}
