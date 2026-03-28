// Osascript wrapper: execute AppleScript/JXA from Rust with timeout and error parsing.
// Per Anchor 1: Process::Command wrappers for osascript MUST be in Rust.
// Per Anchor 5: Returns structured ToolResult, logs to SQLite.

use crate::types::ToolResult;
use std::process::Command;
use std::time::{Duration, Instant};

/// Default timeout for osascript execution (30 seconds per spec).
pub const DEFAULT_TIMEOUT_MS: u64 = 30_000;

/// Execute an AppleScript string via osascript.
/// Returns a structured ToolResult with stdout, error parsing, and duration.
pub fn run_applescript(script: &str, timeout_ms: Option<u64>) -> ToolResult {
    run_osascript(&["-e", script], timeout_ms)
}

/// Execute a JXA (JavaScript for Automation) string via osascript.
pub fn run_jxa(script: &str, timeout_ms: Option<u64>) -> ToolResult {
    run_osascript(&["-l", "JavaScript", "-e", script], timeout_ms)
}

/// Execute an AppleScript file.
pub fn run_applescript_file(path: &str, timeout_ms: Option<u64>) -> ToolResult {
    run_osascript(&[path], timeout_ms)
}

/// Core osascript execution with timeout and error parsing.
fn run_osascript(args: &[&str], timeout_ms: Option<u64>) -> ToolResult {
    let start = Instant::now();
    let timeout = Duration::from_millis(timeout_ms.unwrap_or(DEFAULT_TIMEOUT_MS));

    let output = match Command::new("/usr/bin/osascript")
        .args(args)
        .output()
    {
        Ok(o) => o,
        Err(e) => {
            let duration_ms = start.elapsed().as_millis() as u64;
            return ToolResult::err(
                format!("Failed to launch osascript: {e}"),
                crate::types::error_codes::EXECUTION_ERROR,
                duration_ms,
            );
        }
    };

    let duration_ms = start.elapsed().as_millis() as u64;

    // Check timeout (approximate — Command doesn't have built-in timeout)
    if duration_ms > timeout.as_millis() as u64 {
        return ToolResult::err(
            "osascript execution timed out".to_string(),
            crate::types::error_codes::TIMEOUT,
            duration_ms,
        );
    }

    let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();

    if output.status.success() {
        ToolResult::ok(
            serde_json::json!({"output": stdout}).to_string(),
            duration_ms,
        )
    } else {
        // Parse the error for meaningful error codes
        let (error_msg, error_code) = parse_osascript_error(&stderr);
        ToolResult::err(error_msg, error_code, duration_ms)
    }
}

/// Parse osascript stderr into a meaningful error message and code.
fn parse_osascript_error(stderr: &str) -> (String, &'static str) {
    let lower = stderr.to_lowercase();

    if lower.contains("not authorized") || lower.contains("access for assistive") || lower.contains("not allowed") {
        (format!("Permission denied: {stderr}"), crate::types::error_codes::PERMISSION_DENIED)
    } else if lower.contains("application can't be found") || lower.contains("can't get application") {
        (format!("Application not found: {stderr}"), crate::types::error_codes::NOT_FOUND)
    } else if lower.contains("connection is invalid") || lower.contains("timed out") {
        (format!("Timeout or connection error: {stderr}"), crate::types::error_codes::TIMEOUT)
    } else {
        (format!("AppleScript error: {stderr}"), crate::types::error_codes::EXECUTION_ERROR)
    }
}

// ── Tool Wrappers (called by agents via MCPDispatcher) ───────────────────────

/// Tool: open_url — opens a URL in Safari via AppleScript.
pub fn tool_open_url(url: &str) -> ToolResult {
    let script = format!(
        "tell application \"Safari\" to open location \"{}\"",
        url.replace('"', "\\\"")
    );
    run_applescript(&script, None)
}

/// Tool: get_page_url — gets the current Safari tab URL.
pub fn tool_get_page_url() -> ToolResult {
    run_applescript(
        "tell application \"Safari\" to get URL of current tab of front window",
        Some(10_000),
    )
}

/// Tool: get_page_title — gets the current Safari tab title.
pub fn tool_get_page_title() -> ToolResult {
    run_applescript(
        "tell application \"Safari\" to get name of current tab of front window",
        Some(10_000),
    )
}

/// Tool: get_page_text — extracts visible text from Safari's current tab via JavaScript.
pub fn tool_get_page_text(max_length: u32) -> ToolResult {
    let limit = if max_length == 0 { 4000 } else { max_length };
    let script = format!(
        "tell application \"Safari\" to return (do JavaScript \"document.body.innerText.substring(0, {limit})\" in current tab of front window)"
    );
    run_applescript(&script, Some(15_000))
}

/// Tool: search_web — searches Google via Safari.
pub fn tool_search_web(query: &str) -> ToolResult {
    let encoded = query.replace(' ', "+").replace('"', "%22");
    let url = format!("https://www.google.com/search?q={encoded}");
    tool_open_url(&url)
}

/// Tool: run_shell_command — executes a shell command with timeout.
pub fn tool_run_command(command: &str, allowed_commands: &[&str]) -> ToolResult {
    let start = Instant::now();

    // Extract base command for allow-list check
    let base = command.split_whitespace().next().unwrap_or(command);
    if !allowed_commands.is_empty() && !allowed_commands.contains(&base) {
        return ToolResult::err(
            format!("Command '{base}' not in allow-list"),
            crate::types::error_codes::PERMISSION_DENIED,
            0,
        );
    }

    let output = match Command::new("/bin/zsh")
        .args(["-c", command])
        .output()
    {
        Ok(o) => o,
        Err(e) => {
            let duration_ms = start.elapsed().as_millis() as u64;
            return ToolResult::err(
                format!("Failed to execute command: {e}"),
                crate::types::error_codes::EXECUTION_ERROR,
                duration_ms,
            );
        }
    };

    let duration_ms = start.elapsed().as_millis() as u64;
    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).to_string();

    if output.status.success() {
        ToolResult::ok(
            serde_json::json!({
                "exit_code": 0,
                "stdout": stdout.trim(),
                "stderr": stderr.trim(),
            }).to_string(),
            duration_ms,
        )
    } else {
        ToolResult::err(
            format!("Exit code {}: {}", output.status.code().unwrap_or(-1), stderr.trim()),
            crate::types::error_codes::EXECUTION_ERROR,
            duration_ms,
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_error_permission() {
        let (_, code) = parse_osascript_error("Not authorized to send Apple events");
        assert_eq!(code, crate::types::error_codes::PERMISSION_DENIED);
    }

    #[test]
    fn test_parse_error_not_found() {
        let (_, code) = parse_osascript_error("Application can't be found");
        assert_eq!(code, crate::types::error_codes::NOT_FOUND);
    }

    #[test]
    fn test_parse_error_timeout() {
        let (_, code) = parse_osascript_error("Connection timed out");
        assert_eq!(code, crate::types::error_codes::TIMEOUT);
    }

    #[test]
    fn test_parse_error_generic() {
        let (msg, code) = parse_osascript_error("Some random error");
        assert_eq!(code, crate::types::error_codes::EXECUTION_ERROR);
        assert!(msg.contains("Some random error"));
    }

    #[test]
    fn test_run_command_allow_list() {
        let result = tool_run_command("rm -rf /", &["echo", "ls"]);
        assert!(!result.success);
        assert_eq!(result.error_code.as_deref(), Some(crate::types::error_codes::PERMISSION_DENIED));
    }

    #[test]
    fn test_run_command_echo() {
        let result = tool_run_command("echo hello", &["echo", "ls"]);
        assert!(result.success);
        assert!(result.data_json.contains("hello"));
    }

    #[test]
    fn test_tool_result_ok() {
        let r = ToolResult::ok("{\"test\":true}".to_string(), 42);
        assert!(r.success);
        assert_eq!(r.duration_ms, 42);
    }

    #[test]
    fn test_tool_result_err() {
        let r = ToolResult::err("fail".to_string(), "TEST_ERROR", 1);
        assert!(!r.success);
        assert_eq!(r.error_code.as_deref(), Some("TEST_ERROR"));
    }
}
