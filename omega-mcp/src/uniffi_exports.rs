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
    let result: serde_json::Value =
        serde_json::from_str(&result_json).unwrap_or(serde_json::Value::Null);
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
            // SAFETY: is_object() check above guarantees as_object() succeeds
            let Some(obj) = args.as_object() else {
                return "Arguments must be a JSON object".to_string();
            };
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

// ── Catalog Exports ──────────────────────────────────────────────────────────

/// Get the built-in tool catalog as a JSON array.
/// Each element has: name, agent, description, arguments_example, input_schema_json,
/// and safety (destructive, requires_confirmation).
pub fn builtin_tools_json() -> String {
    let tools = crate::catalog::builtin_tools();
    serde_json::to_string(&tools).unwrap_or_else(|_| "[]".to_string())
}

// ── Vault Tool Exports ───────────────────────────────────────────────────────

/// Execute a vault tool by name. vault_root is the path to the user's vault.
/// tool_name is a canonical V2 name such as file.read, file.write,
/// file.list, vault.search, vault.read, or vault.write. Legacy names are
/// still accepted for archived callers.
/// args_json is the tool arguments as JSON.
/// Returns a JSON ToolResult.
pub fn execute_vault_tool(vault_root: String, tool_name: String, args_json: String) -> String {
    crate::vault::execute_vault_tool(vault_root, tool_name, args_json)
}

/// Execute one of the seven canonical D2 graph tools.
/// This uses the same vault-scoped substrate boundary as `execute_vault_tool`
/// but rejects non-graph tool names before dispatch.
pub fn execute_graph_tool(vault_root: String, tool_name: String, args_json: String) -> String {
    if !crate::graph_tools::is_graph_tool(&tool_name) {
        let result = crate::types::ToolResult::err(
            format!("Unknown graph tool: {tool_name}"),
            crate::types::error_codes::NOT_FOUND,
            0,
        );
        return serde_json::to_string(&result).unwrap_or_default();
    }
    crate::vault::execute_vault_tool(vault_root, tool_name, args_json)
}

// ── Orchestrator Exports ─────────────────────────────────────────────────────

/// Generate a heuristic plan (Rust-side, no LLM needed).
/// Returns JSON-encoded TaskGraph.
pub fn generate_heuristic_plan(task: String) -> String {
    let graph = crate::orchestrator::heuristic_plan(&task);
    graph.to_json()
}

/// Get the default agent definitions as JSON.
pub fn get_default_agents_json() -> String {
    let agents = crate::orchestrator::default_agents();
    serde_json::to_string(&agents).unwrap_or_default()
}

/// Evaluate confirmation decision for a risk level.
/// Returns: "auto_execute", "execute_with_logging", "require_preview", "require_explicit_confirm"
pub fn evaluate_risk_confirmation(risk_level: String) -> String {
    let risk = crate::orchestrator::RiskLevel::from_str(&risk_level);
    let decision = crate::orchestrator::evaluate_confirmation(&risk);
    match decision {
        crate::orchestrator::ConfirmationDecision::AutoExecute => "auto_execute",
        crate::orchestrator::ConfirmationDecision::ExecuteWithLogging => "execute_with_logging",
        crate::orchestrator::ConfirmationDecision::RequirePreview => "require_preview",
        crate::orchestrator::ConfirmationDecision::RequireExplicitConfirm => {
            "require_explicit_confirm"
        }
    }
    .to_string()
}

// ── Tool Execution via Rust Layer (Anchor 5 compliance) ──────────────────────
//
// The osascript + PTY entry points below are exported via UniFFI so the
// generated Swift surface stays binary-stable across MAS and Pro builds.
// Under `--features mas-sandbox` the underlying `osascript` and `pty`
// modules are not compiled (see lib.rs gates), so the MAS dylib contains
// zero `std::process::Command`, `nix::pty::openpty`, `nix::unistd::Fork*`,
// or `nix::sys::signal` symbols originating from this crate. The MAS
// stubs below never call any subprocess primitive — they return an inert
// JSON sentinel so any accidental Swift call fails loudly.

#[cfg(not(feature = "mas-sandbox"))]
/// Execute the web.fetch/open_url tool via Rust osascript wrapper.
pub fn tool_open_url(url: String) -> String {
    let result = crate::osascript::tool_open_url(&url);
    serde_json::to_string(&result).unwrap_or_default()
}

#[cfg(feature = "mas-sandbox")]
pub fn tool_open_url(_url: String) -> String {
    mas_sandbox_unavailable("tool_open_url")
}

#[cfg(not(feature = "mas-sandbox"))]
/// Execute get_page_url tool via Rust osascript wrapper.
pub fn tool_get_page_url() -> String {
    let result = crate::osascript::tool_get_page_url();
    serde_json::to_string(&result).unwrap_or_default()
}

#[cfg(feature = "mas-sandbox")]
pub fn tool_get_page_url() -> String {
    mas_sandbox_unavailable("tool_get_page_url")
}

#[cfg(not(feature = "mas-sandbox"))]
/// Execute get_page_title tool via Rust osascript wrapper.
pub fn tool_get_page_title() -> String {
    let result = crate::osascript::tool_get_page_title();
    serde_json::to_string(&result).unwrap_or_default()
}

#[cfg(feature = "mas-sandbox")]
pub fn tool_get_page_title() -> String {
    mas_sandbox_unavailable("tool_get_page_title")
}

#[cfg(not(feature = "mas-sandbox"))]
/// Execute get_page_text tool via Rust osascript wrapper.
pub fn tool_get_page_text(max_length: u32) -> String {
    let result = crate::osascript::tool_get_page_text(max_length);
    serde_json::to_string(&result).unwrap_or_default()
}

#[cfg(feature = "mas-sandbox")]
pub fn tool_get_page_text(_max_length: u32) -> String {
    mas_sandbox_unavailable("tool_get_page_text")
}

#[cfg(not(feature = "mas-sandbox"))]
/// Execute the web.search/search_web tool via Rust osascript wrapper.
pub fn tool_search_web(query: String) -> String {
    let result = crate::osascript::tool_search_web(&query);
    serde_json::to_string(&result).unwrap_or_default()
}

#[cfg(feature = "mas-sandbox")]
pub fn tool_search_web(_query: String) -> String {
    mas_sandbox_unavailable("tool_search_web")
}

#[cfg(not(feature = "mas-sandbox"))]
/// Execute the action.bash/run_command tool via Rust with allow-list enforcement.
pub fn tool_run_command(command: String, allowed_commands_csv: String) -> String {
    let allowed: Vec<&str> = if allowed_commands_csv.is_empty() {
        vec![]
    } else {
        allowed_commands_csv.split(',').map(|s| s.trim()).collect()
    };
    let result = crate::osascript::tool_run_command(&command, &allowed);
    serde_json::to_string(&result).unwrap_or_default()
}

#[cfg(feature = "mas-sandbox")]
pub fn tool_run_command(_command: String, _allowed_commands_csv: String) -> String {
    mas_sandbox_unavailable("tool_run_command")
}

/// Get confidence action for a given confidence score.
/// Returns: "auto_execute", "log_and_execute", "escalate_to_user", "refuse"
pub fn evaluate_confidence(confidence: f64) -> String {
    let action = crate::orchestrator::confidence_decision(confidence);
    match action {
        crate::orchestrator::ConfidenceAction::AutoExecute => "auto_execute",
        crate::orchestrator::ConfidenceAction::LogAndExecute => "log_and_execute",
        crate::orchestrator::ConfidenceAction::EscalateToUser => "escalate_to_user",
        crate::orchestrator::ConfidenceAction::Refuse => "refuse",
    }
    .to_string()
}

// ── Persistent PTY Exports (Ω-HAS) ────────────────────────────────────────

#[cfg(not(feature = "mas-sandbox"))]
/// Spawn a persistent PTY shell session.
/// Returns a JSON with {"pty_id": "..."} on success, or {"error": "..."} on failure.
pub fn pty_spawn_session(session_id: String, shell: String, initial_dir: String) -> String {
    let config = crate::pty::PtyConfig {
        shell: if shell.is_empty() {
            "/bin/zsh".to_string()
        } else {
            shell
        },
        initial_dir: if initial_dir.is_empty() {
            None
        } else {
            Some(initial_dir)
        },
        cols: 120,
        rows: 40,
    };
    match crate::pty::PtyPool::spawn(&session_id, config) {
        Ok(pty_id) => serde_json::json!({"pty_id": pty_id}).to_string(),
        Err(e) => serde_json::json!({"error": e.to_string()}).to_string(),
    }
}

#[cfg(feature = "mas-sandbox")]
pub fn pty_spawn_session(_session_id: String, _shell: String, _initial_dir: String) -> String {
    mas_sandbox_unavailable("pty_spawn_session")
}

#[cfg(not(feature = "mas-sandbox"))]
/// Execute a command in a persistent PTY session.
/// Returns JSON: {"stdout": "...", "exit_hint": "ok|error(N)|unknown",
///   "working_dir": "...", "duration_ms": N}
/// Or: {"error": "..."}
pub fn pty_execute_command(pty_id: String, command: String, timeout_ms: u64) -> String {
    let timeout = std::time::Duration::from_millis(timeout_ms.min(120_000));
    match crate::pty::PtyPool::execute(&pty_id, &command, timeout) {
        Ok(output) => serde_json::json!({
            "stdout": output.stdout,
            "exit_hint": output.exit_hint,
            "working_dir": output.working_dir,
            "duration_ms": output.duration_ms,
        })
        .to_string(),
        Err(e) => serde_json::json!({"error": e.to_string()}).to_string(),
    }
}

#[cfg(feature = "mas-sandbox")]
pub fn pty_execute_command(_pty_id: String, _command: String, _timeout_ms: u64) -> String {
    mas_sandbox_unavailable("pty_execute_command")
}

#[cfg(not(feature = "mas-sandbox"))]
/// Close a persistent PTY session.
pub fn pty_close_session(pty_id: String) {
    crate::pty::PtyPool::close(&pty_id);
}

#[cfg(feature = "mas-sandbox")]
pub fn pty_close_session(_pty_id: String) {}

#[cfg(not(feature = "mas-sandbox"))]
/// Close all PTY sessions for a given session ID (cascade cleanup).
pub fn pty_close_all(session_id: String) {
    crate::pty::PtyPool::close_all_for_session(&session_id);
}

#[cfg(feature = "mas-sandbox")]
pub fn pty_close_all(_session_id: String) {}

#[cfg(not(feature = "mas-sandbox"))]
/// Get active PTY session count.
pub fn pty_active_session_count() -> u32 {
    crate::pty::PtyPool::active_count() as u32
}

#[cfg(feature = "mas-sandbox")]
pub fn pty_active_session_count() -> u32 {
    0
}

/// MAS-sandbox sentinel returned by gated subprocess wrappers. Kept private to
/// this module; never references `std::process::Command` or `nix::*`.
#[cfg(feature = "mas-sandbox")]
fn mas_sandbox_unavailable(name: &str) -> String {
    serde_json::json!({
        "error": "unavailable_in_mas_sandbox",
        "tool": name,
    })
    .to_string()
}

/// Execute a Mixture-of-Agents pool in parallel via Rust's rayon thread pool.
/// Takes JSON-encoded tasks and config, returns JSON-encoded results with consensus.
/// Bypasses Python's GIL by running all sub-agent tasks on native threads.
pub fn moa_execute_pool(tasks_json: String, config_json: String) -> String {
    crate::moa::moa_execute_pool(&tasks_json, &config_json)
}

/// Validate that a step's tool is within the agent's allowed toolset.
/// Returns empty string on success, error message on failure.
pub fn validate_agent_tool(agent_name: String, tool_name: String) -> String {
    let agents = crate::orchestrator::default_agents();
    let step = crate::orchestrator::TaskStep {
        id: String::new(),
        description: String::new(),
        assigned_agent: agent_name,
        tool_name,
        arguments_json: "{}".to_string(),
        depends_on: vec![],
        risk_level: crate::orchestrator::RiskLevel::Low,
        status: crate::orchestrator::StepStatus::Pending,
        result_json: None,
        error: None,
        duration_ms: 0,
        retry_count: 0,
    };
    match crate::orchestrator::validate_agent_toolset(&agents, &step) {
        Ok(()) => String::new(),
        Err(e) => e,
    }
}
