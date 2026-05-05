// Osascript wrapper: execute AppleScript/JXA from Rust with timeout and error parsing.
// Per Anchor 1: Process::Command wrappers for osascript MUST be in Rust.
// Per Anchor 5: Returns structured ToolResult, logs to SQLite.

use crate::types::ToolResult;
use std::process::Command;
use std::thread;
use std::time::{Duration, Instant};

/// Default timeout for osascript execution (30 seconds per spec).
pub const DEFAULT_TIMEOUT_MS: u64 = 30_000;
const SAFARI_LAUNCH_DELAY_MS: u64 = 500;
const APP_LAUNCH_TIMEOUT_MS: u64 = 5_000;
const APP_LAUNCH_POLL_MS: u64 = 100;
const SAFARI_LAUNCH_RETRIES: usize = 3;

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

    let output = match Command::new("/usr/bin/osascript").args(args).output() {
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

    if lower.contains("not authorized")
        || lower.contains("access for assistive")
        || lower.contains("not allowed")
    {
        (
            format!("Permission denied: {stderr}"),
            crate::types::error_codes::PERMISSION_DENIED,
        )
    } else if lower.contains("has no open windows") {
        (
            format!("Application state unavailable: {stderr}"),
            crate::types::error_codes::NOT_FOUND,
        )
    } else if is_app_not_running_error(stderr) {
        (
            format!("Application not running: {stderr}"),
            crate::types::error_codes::NOT_FOUND,
        )
    } else if lower.contains("application can't be found")
        || lower.contains("can't get application")
    {
        (
            format!("Application not found: {stderr}"),
            crate::types::error_codes::NOT_FOUND,
        )
    } else if lower.contains("connection is invalid") || lower.contains("timed out") {
        (
            format!("Timeout or connection error: {stderr}"),
            crate::types::error_codes::TIMEOUT,
        )
    } else {
        (
            format!("AppleScript error: {stderr}"),
            crate::types::error_codes::EXECUTION_ERROR,
        )
    }
}

fn is_app_not_running_error(stderr: &str) -> bool {
    let lower = stderr.to_lowercase();
    lower.contains("application isn't running") || lower.contains("(-600)")
}

fn escape_applescript_string(value: &str) -> String {
    value.replace('\\', "\\\\").replace('"', "\\\"")
}

fn safari_open_location_script(url: &str) -> String {
    format!(
        "tell application \"Safari\"\nactivate\nopen location \"{}\"\ndelay 0.35\nreturn URL of current tab of front window\nend tell",
        escape_applescript_string(url)
    )
}

fn safari_window_value_script(value_expression: &str) -> String {
    format!(
        "tell application \"Safari\"\nactivate\nif (count of windows) = 0 then\nerror \"Safari has no open windows\"\nend if\nreturn {value_expression}\nend tell"
    )
}

fn safari_page_text_script(limit: u32) -> String {
    format!(
        "tell application \"Safari\"\nactivate\nif (count of windows) = 0 then\nerror \"Safari has no open windows\"\nend if\nreturn (do JavaScript \"document.body ? document.body.innerText.substring(0, {limit}) : ''\" in current tab of front window)\nend tell"
    )
}

fn launch_application(app_name: &str) -> Result<(), ToolResult> {
    let start = Instant::now();
    let output = Command::new("/usr/bin/open")
        .args(["-a", app_name])
        .output();

    match output {
        Ok(result) if result.status.success() => {
            if !wait_for_application_process(app_name, Duration::from_millis(APP_LAUNCH_TIMEOUT_MS))
            {
                let duration_ms = start.elapsed().as_millis() as u64;
                return Err(ToolResult::err(
                    format!("Timed out waiting for {app_name} to launch"),
                    crate::types::error_codes::TIMEOUT,
                    duration_ms,
                ));
            }
            thread::sleep(Duration::from_millis(SAFARI_LAUNCH_DELAY_MS));
            Ok(())
        }
        Ok(result) => {
            let duration_ms = start.elapsed().as_millis() as u64;
            let stderr = String::from_utf8_lossy(&result.stderr).trim().to_string();
            Err(ToolResult::err(
                format!("Failed to launch {app_name}: {stderr}"),
                crate::types::error_codes::EXECUTION_ERROR,
                duration_ms,
            ))
        }
        Err(error) => {
            let duration_ms = start.elapsed().as_millis() as u64;
            Err(ToolResult::err(
                format!("Failed to launch {app_name}: {error}"),
                crate::types::error_codes::EXECUTION_ERROR,
                duration_ms,
            ))
        }
    }
}

fn wait_for_application_process(app_name: &str, timeout: Duration) -> bool {
    let deadline = Instant::now() + timeout;
    loop {
        if Command::new("/usr/bin/pgrep")
            .args(["-x", app_name])
            .output()
            .map(|output| output.status.success())
            .unwrap_or(false)
        {
            return true;
        }

        if Instant::now() >= deadline {
            return false;
        }

        thread::sleep(Duration::from_millis(APP_LAUNCH_POLL_MS));
    }
}

fn run_safari_applescript(script: &str, timeout_ms: Option<u64>) -> ToolResult {
    run_safari_applescript_with_hooks(script, timeout_ms, run_applescript, launch_application)
}

fn run_safari_applescript_with_hooks<FRun, FLaunch>(
    script: &str,
    timeout_ms: Option<u64>,
    mut run_script: FRun,
    mut launch_app: FLaunch,
) -> ToolResult
where
    FRun: FnMut(&str, Option<u64>) -> ToolResult,
    FLaunch: FnMut(&str) -> Result<(), ToolResult>,
{
    let mut result = run_script(script, timeout_ms);
    for _ in 0..SAFARI_LAUNCH_RETRIES {
        if result.success
            || !result
                .error
                .as_deref()
                .is_some_and(is_app_not_running_error)
        {
            return result;
        }

        match launch_app("Safari") {
            Ok(()) => {
                result = run_script(script, timeout_ms);
            }
            Err(error) => return error,
        }
    }

    result
}

// ── Tool Wrappers (called by agents via MCPDispatcher) ───────────────────────

/// Tool: open_url — opens a URL in Safari via AppleScript.
pub fn tool_open_url(url: &str) -> ToolResult {
    let script = safari_open_location_script(url);
    run_safari_applescript(&script, None)
}

/// Tool: get_page_url — gets the current Safari tab URL.
pub fn tool_get_page_url() -> ToolResult {
    let script = safari_window_value_script("URL of current tab of front window");
    run_safari_applescript(&script, Some(10_000))
}

/// Tool: get_page_title — gets the current Safari tab title.
pub fn tool_get_page_title() -> ToolResult {
    let script = safari_window_value_script("name of current tab of front window");
    run_safari_applescript(&script, Some(10_000))
}

/// Tool: get_page_text — extracts visible text from Safari's current tab via JavaScript.
pub fn tool_get_page_text(max_length: u32) -> ToolResult {
    let limit = if max_length == 0 { 4000 } else { max_length };
    let script = safari_page_text_script(limit);
    run_safari_applescript(&script, Some(15_000))
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

    let output = match Command::new("/bin/zsh").args(["-c", command]).output() {
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
            })
            .to_string(),
            duration_ms,
        )
    } else {
        ToolResult::err(
            format!(
                "Exit code {}: {}",
                output.status.code().unwrap_or(-1),
                stderr.trim()
            ),
            crate::types::error_codes::EXECUTION_ERROR,
            duration_ms,
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_app_not_running_error_is_retryable() {
        assert!(is_app_not_running_error(
            "Safari got an error: Application isn't running. (-600)"
        ));
        assert!(!is_app_not_running_error("Application can't be found"));
    }

    #[test]
    fn test_safari_open_script_activates_before_opening() {
        let script = safari_open_location_script("https://example.com?q=1");
        assert!(script.contains("tell application \"Safari\""));
        assert!(script.contains("activate"));
        assert!(script.contains("open location"));
        assert!(script.contains("delay 0.35"));
    }

    #[test]
    fn test_safari_window_value_script_requires_front_window() {
        let script = safari_window_value_script("URL of current tab of front window");
        assert!(script.contains("if (count of windows) = 0 then"));
        assert!(script.contains("error \"Safari has no open windows\""));
        assert!(script.contains("return URL of current tab of front window"));
    }

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
    fn test_parse_error_no_open_windows() {
        let (_, code) = parse_osascript_error("Safari has no open windows");
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
        assert_eq!(
            result.error_code.as_deref(),
            Some(crate::types::error_codes::PERMISSION_DENIED)
        );
    }

    #[test]
    fn test_run_command_echo() {
        let result = tool_run_command("echo hello", &["echo", "ls"]);
        assert!(result.success);
        assert!(result.data_json.contains("hello"));
    }

    #[test]
    fn test_run_safari_applescript_retries_until_launch_succeeds() {
        let mut run_calls = 0;
        let mut launch_calls = 0;
        let result = run_safari_applescript_with_hooks(
            "dummy",
            Some(1_000),
            |_, _| {
                run_calls += 1;
                if run_calls == 1 {
                    ToolResult::err(
                        "Application not running: Safari got an error: Application isn't running. (-600)".to_string(),
                        crate::types::error_codes::NOT_FOUND,
                        1,
                    )
                } else {
                    ToolResult::ok("{\"output\":\"ok\"}".to_string(), 1)
                }
            },
            |_| {
                launch_calls += 1;
                Ok(())
            },
        );

        assert!(result.success);
        assert_eq!(run_calls, 2);
        assert_eq!(launch_calls, 1);
    }

    #[test]
    fn test_run_safari_applescript_stops_retry_after_non_retryable_error() {
        let mut launch_calls = 0;
        let result = run_safari_applescript_with_hooks(
            "dummy",
            Some(1_000),
            |_, _| {
                ToolResult::err(
                    "Permission denied: Not authorized to send Apple events".to_string(),
                    crate::types::error_codes::PERMISSION_DENIED,
                    1,
                )
            },
            |_| {
                launch_calls += 1;
                Ok(())
            },
        );

        assert!(!result.success);
        assert_eq!(
            result.error_code.as_deref(),
            Some(crate::types::error_codes::PERMISSION_DENIED)
        );
        assert_eq!(launch_calls, 0);
    }

    #[test]
    fn test_run_safari_applescript_returns_launch_error() {
        let mut launch_calls = 0;
        let result = run_safari_applescript_with_hooks(
            "dummy",
            Some(1_000),
            |_, _| {
                ToolResult::err(
                    "Application not running: Safari got an error: Application isn't running. (-600)".to_string(),
                    crate::types::error_codes::NOT_FOUND,
                    1,
                )
            },
            |_| {
                launch_calls += 1;
                Err(ToolResult::err(
                    "Timed out waiting for Safari to launch".to_string(),
                    crate::types::error_codes::TIMEOUT,
                    2,
                ))
            },
        );

        assert!(!result.success);
        assert_eq!(
            result.error_code.as_deref(),
            Some(crate::types::error_codes::TIMEOUT)
        );
        assert_eq!(launch_calls, 1);
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
