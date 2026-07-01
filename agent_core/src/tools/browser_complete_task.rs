//! `browser.complete_task` — bounded browser-use subordinate agent task.
//!
//! This is intentionally separate from `browser.rs`: the regular browser tools
//! operate an existing shared session, while this tool creates a short-lived
//! browser-use task session and always tears it down.

use std::path::PathBuf;
use std::time::Duration;

use async_trait::async_trait;
use serde_json::{json, Value};
use uuid::Uuid;

use super::browser_command::{
    cleanup_local_daemon, run_agent_browser_command, socket_dir_for_session,
};
use super::browser_executable::cdp_url_from_env;
use super::browser_private::create_private_browser_dir;
use super::browser_redaction::redact_browser_error_detail;
pub use super::browser_schema::browser_complete_task_schema;
use super::registry::{ToolError, ToolHandler};

const TASK_COMMAND_TIMEOUT: Duration = Duration::from_secs(300);
const MAX_TASK_CHARS: usize = 4_000;
const DEFAULT_TASK_STEPS: u64 = 20;
const MAX_TASK_STEPS: u64 = 50;
const MAX_TASK_RESULT_CHARS: usize = 12_000;
const MAX_TASK_ERRORS: usize = 20;
const MAX_TASK_ERROR_CHARS: usize = 512;

#[derive(Clone, Default)]
pub struct BrowserCompleteTaskHandler;

impl BrowserCompleteTaskHandler {
    pub fn new() -> Self {
        Self
    }
}

#[async_trait]
impl ToolHandler for BrowserCompleteTaskHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        Ok(complete_task_impl(input).await?.to_string())
    }
}

#[derive(Debug)]
struct BrowserEphemeralSession {
    session_name: String,
    socket_dir: PathBuf,
}

impl BrowserEphemeralSession {
    fn create(prefix: &str) -> Result<Self, ToolError> {
        let session_name = format!("{prefix}-{}", &Uuid::new_v4().simple().to_string()[..12]);
        let socket_dir = socket_dir_for_session(&session_name);
        create_private_browser_dir(&socket_dir)?;
        Ok(Self {
            session_name,
            socket_dir,
        })
    }
}

impl Drop for BrowserEphemeralSession {
    fn drop(&mut self) {
        cleanup_local_daemon(&self.session_name, &self.socket_dir);
    }
}

async fn complete_task_impl(input: &Value) -> Result<Value, ToolError> {
    let task = normalized_task(input)?;
    let max_steps = parse_task_max_steps(input)?;
    let task_chars = task.chars().count();
    let task_session = BrowserEphemeralSession::create("epi-task")?;
    let cdp_url = cdp_url_from_env()?;
    let args = vec![task, max_steps.to_string()];

    let raw = run_agent_browser_command(
        "task",
        &args,
        &task_session.session_name,
        cdp_url.as_deref(),
        &task_session.socket_dir,
        TASK_COMMAND_TIMEOUT,
    )
    .await?;
    let data = raw.get("data").cloned().unwrap_or_else(|| json!({}));
    let (final_result, final_result_truncated) =
        bounded_task_text(data.get("final_result"), MAX_TASK_RESULT_CHARS);
    let (errors, errors_truncated) = bounded_task_errors(data.get("errors"));
    let adapter_truncated = data
        .get("truncated")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    let steps = data.get("steps").and_then(Value::as_u64);
    validate_task_envelope_limits(&data, max_steps)?;
    let is_done = data.get("is_done").and_then(Value::as_bool);
    let successful = data.get("successful").and_then(Value::as_bool);
    let status = normalized_task_status(
        data.get("status").and_then(Value::as_str),
        data.get("is_done"),
        data.get("successful"),
    );
    let errors_present = task_errors_present(&errors);
    let status = task_status_after_errors(status, errors_present);
    let used_browser_use_agent = data
        .get("used_browser_use_agent")
        .and_then(Value::as_bool)
        .unwrap_or(true);
    let dry_run = data
        .get("dry_run")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    let task_success = task_outcome_success(status, is_done, successful) && !errors_present;

    Ok(json!({
        "success": task_success,
        "adapter_success": true,
        "task_success": task_success,
        "status": status,
        "final_result": final_result,
        "errors": errors,
        "steps": steps,
        "max_steps": max_steps,
        "task_chars": task_chars,
        "is_done": is_done,
        "successful": successful,
        "used_browser_use_agent": used_browser_use_agent,
        "dry_run": dry_run,
        "truncated": adapter_truncated || final_result_truncated || errors_truncated,
    }))
}

fn normalized_task(input: &Value) -> Result<String, ToolError> {
    let task = input
        .get("task")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'task'".into()))?
        .trim()
        .to_string();
    if task.is_empty() {
        return Err(ToolError::InvalidArguments("task cannot be empty".into()));
    }
    if task.chars().count() > MAX_TASK_CHARS {
        return Err(ToolError::InvalidArguments(format!(
            "task exceeds {MAX_TASK_CHARS} characters"
        )));
    }
    Ok(task)
}

fn parse_task_max_steps(input: &Value) -> Result<u64, ToolError> {
    let Some(value) = input.get("max_steps") else {
        return Ok(DEFAULT_TASK_STEPS);
    };
    if value.is_null() {
        return Ok(DEFAULT_TASK_STEPS);
    }
    let Some(max_steps) = value.as_u64() else {
        return Err(ToolError::InvalidArguments(
            "max_steps must be an integer between 1 and 50".into(),
        ));
    };
    if !(1..=MAX_TASK_STEPS).contains(&max_steps) {
        return Err(ToolError::InvalidArguments(format!(
            "max_steps must be between 1 and {MAX_TASK_STEPS}"
        )));
    }
    Ok(max_steps)
}

fn validate_task_envelope_limits(data: &Value, requested_max_steps: u64) -> Result<(), ToolError> {
    if let Some(value) = data.get("max_steps") {
        let Some(adapter_max_steps) = value.as_u64() else {
            return Err(ToolError::ExecutionFailed(
                "browser-use adapter returned non-integer max_steps".into(),
            ));
        };
        if adapter_max_steps != requested_max_steps {
            return Err(ToolError::ExecutionFailed(
                "browser-use adapter returned mismatched max_steps".into(),
            ));
        }
    }
    if let Some(value) = data.get("steps") {
        let Some(steps) = value.as_u64() else {
            return Err(ToolError::ExecutionFailed(
                "browser-use adapter returned non-integer steps".into(),
            ));
        };
        if steps > requested_max_steps {
            return Err(ToolError::ExecutionFailed(
                "browser-use adapter returned steps above max_steps".into(),
            ));
        }
    }
    Ok(())
}

fn bounded_task_text(value: Option<&Value>, cap: usize) -> (Value, bool) {
    let Some(value) = value else {
        return (Value::Null, false);
    };
    let text = value
        .as_str()
        .map(ToString::to_string)
        .unwrap_or_else(|| value.to_string());
    let total = text.chars().count();
    if total <= cap {
        return (Value::String(text), false);
    }
    (
        Value::String(bounded_with_truncation_marker(&text, cap, total)),
        true,
    )
}

fn bounded_with_truncation_marker(text: &str, cap: usize, total: usize) -> String {
    let marker = format!("\n[Truncated: {total} total chars]");
    let marker_chars = marker.chars().count();
    if cap <= marker_chars {
        return marker.chars().take(cap).collect();
    }
    let prefix: String = text.chars().take(cap - marker_chars).collect();
    format!("{prefix}{marker}")
}

fn bounded_task_errors(value: Option<&Value>) -> (Value, bool) {
    let Some(Value::Array(items)) = value else {
        return (json!([]), false);
    };
    let mut truncated = items.len() > MAX_TASK_ERRORS;
    let errors = items
        .iter()
        .take(MAX_TASK_ERRORS)
        .filter_map(|item| {
            if item.is_null() {
                None
            } else {
                let text = item
                    .as_str()
                    .map(ToString::to_string)
                    .unwrap_or_else(|| item.to_string());
                Some(redact_browser_error_detail(&text))
            }
        })
        .filter(|text| !text.is_empty())
        .map(|text| {
            let total = text.chars().count();
            if total <= MAX_TASK_ERROR_CHARS {
                Value::String(text)
            } else {
                truncated = true;
                Value::String(bounded_with_truncation_marker(
                    &text,
                    MAX_TASK_ERROR_CHARS,
                    total,
                ))
            }
        })
        .collect();
    (Value::Array(errors), truncated)
}

fn task_errors_present(errors: &Value) -> bool {
    matches!(errors, Value::Array(items) if !items.is_empty())
}

fn task_status_after_errors(status: &'static str, errors_present: bool) -> &'static str {
    if errors_present && status == "completed" {
        "failed"
    } else {
        status
    }
}

fn normalized_task_status(
    raw_status: Option<&str>,
    is_done: Option<&Value>,
    successful: Option<&Value>,
) -> &'static str {
    let is_done = is_done.and_then(Value::as_bool);
    let successful = successful.and_then(Value::as_bool);
    if is_done == Some(false) {
        return "incomplete";
    }
    if successful == Some(false) {
        return "failed";
    }

    if let Some(status) = raw_status.map(str::trim) {
        if status.eq_ignore_ascii_case("completed")
            || status.eq_ignore_ascii_case("complete")
            || status.eq_ignore_ascii_case("succeeded")
            || status.eq_ignore_ascii_case("success")
        {
            return "completed";
        }
        if status.eq_ignore_ascii_case("failed")
            || status.eq_ignore_ascii_case("failure")
            || status.eq_ignore_ascii_case("error")
        {
            return "failed";
        }
        if status.eq_ignore_ascii_case("incomplete")
            || status.eq_ignore_ascii_case("running")
            || status.eq_ignore_ascii_case("cancelled")
            || status.eq_ignore_ascii_case("canceled")
            || status.eq_ignore_ascii_case("stopped")
        {
            return "incomplete";
        }
        if status.eq_ignore_ascii_case("unknown") {
            return "unknown";
        }
    }
    inferred_task_status(is_done, successful)
}

fn inferred_task_status(is_done: Option<bool>, successful: Option<bool>) -> &'static str {
    match (is_done, successful) {
        (Some(true), _) => "completed",
        (None, Some(true)) => "completed",
        _ => "unknown",
    }
}

fn task_outcome_success(
    status: &str,
    is_done: Option<bool>,
    successful: Option<bool>,
) -> bool {
    match status {
        "completed" => {
            (successful == Some(true) || is_done == Some(true))
                && successful != Some(false)
                && is_done != Some(false)
        }
        "failed" | "incomplete" | "unknown" => false,
        _ => successful == Some(true) && is_done != Some(false),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::env;
    use std::ffi::OsString;
    use std::fs;
    #[cfg(unix)]
    use std::os::unix::fs::PermissionsExt;
    use std::path::Path;

    use tokio::sync::Mutex as AsyncMutex;

    static TEST_ENV_LOCK: std::sync::OnceLock<AsyncMutex<()>> = std::sync::OnceLock::new();

    fn env_lock() -> &'static AsyncMutex<()> {
        TEST_ENV_LOCK.get_or_init(|| AsyncMutex::new(()))
    }

    struct EnvGuard {
        key: &'static str,
        old_value: Option<OsString>,
    }

    impl EnvGuard {
        fn set(key: &'static str, value: impl Into<OsString>) -> Self {
            let old_value = env::var_os(key);
            env::set_var(key, value.into());
            Self { key, old_value }
        }
    }

    impl Drop for EnvGuard {
        fn drop(&mut self) {
            if let Some(value) = &self.old_value {
                env::set_var(self.key, value);
            } else {
                env::remove_var(self.key);
            }
        }
    }

    fn make_fake_task_browser(temp_root: &Path) -> PathBuf {
        let bin_dir = temp_root.join("bin");
        fs::create_dir_all(&bin_dir).unwrap();
        let script_path = bin_dir.join("agent-browser");
        let script = r#"#!/bin/sh
set -eu
if [ -n "${FAKE_BROWSER_LOG:-}" ]; then
  printf '%s\n' "$*" >> "$FAKE_BROWSER_LOG"
fi
last=""
for arg in "$@"; do
  last="$arg"
done
printf '{"success":true,"data":{"status":"completed","final_result":"fake browser-use task complete","steps":3,"max_steps":%s,"is_done":true,"successful":true,"errors":[],"used_browser_use_agent":true,"dry_run":false,"truncated":false}}\n' "$last"
"#;
        fs::write(&script_path, script).unwrap();
        #[cfg(unix)]
        {
            let mut permissions = fs::metadata(&script_path).unwrap().permissions();
            permissions.set_mode(0o755);
            fs::set_permissions(&script_path, permissions).unwrap();
        }
        script_path
    }

    fn prepend_to_path(new_dir: &Path) -> OsString {
        let mut entries = vec![new_dir.to_path_buf()];
        if let Some(path) = env::var_os("PATH") {
            for item in env::split_paths(&path) {
                entries.push(item);
            }
        }
        env::join_paths(entries).unwrap()
    }

    #[tokio::test]
    async fn browser_complete_task_delegates_high_level_task_to_adapter() {
        let _env_guard = env_lock().lock().await;
        let temp = tempfile::tempdir().unwrap();
        let script = make_fake_task_browser(temp.path());
        let log_path = temp.path().join("browser.log");
        let _path = EnvGuard::set("PATH", prepend_to_path(script.parent().unwrap()));
        let _log = EnvGuard::set("FAKE_BROWSER_LOG", log_path.as_os_str());

        let output = BrowserCompleteTaskHandler::new()
            .execute(&json!({
                "task": "Find the Example Domain title",
                "max_steps": 3
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&output).unwrap();

        assert_eq!(parsed["success"], json!(true));
        assert_eq!(parsed["status"], json!("completed"));
        assert_eq!(
            parsed["final_result"],
            json!("fake browser-use task complete")
        );
        assert_eq!(parsed["max_steps"], json!(3));
        assert_eq!(parsed["task_chars"], json!(29));
        assert_eq!(parsed["used_browser_use_agent"], json!(true));
        assert_eq!(parsed["dry_run"], json!(false));

        let line = fs::read_to_string(&log_path).unwrap();
        assert!(line.contains("--json task"));
        assert!(line.contains("Find the Example Domain title"));
        assert!(line.contains(" 3"));
    }

    #[tokio::test]
    async fn browser_complete_task_validates_bounds_before_adapter() {
        let handler = BrowserCompleteTaskHandler::new();
        let empty = handler
            .execute(&json!({ "task": "   " }))
            .await
            .unwrap_err();
        assert!(format!("{empty}").contains("task cannot be empty"));

        let too_long = "x".repeat(MAX_TASK_CHARS + 1);
        let too_long_err = handler
            .execute(&json!({ "task": too_long }))
            .await
            .unwrap_err();
        assert!(format!("{too_long_err}").contains("task exceeds"));

        let zero_steps = handler
            .execute(&json!({ "task": "Open example.com", "max_steps": 0 }))
            .await
            .unwrap_err();
        assert!(format!("{zero_steps}").contains("max_steps"));

        let string_steps = handler
            .execute(&json!({ "task": "Open example.com", "max_steps": "3" }))
            .await
            .unwrap_err();
        assert!(format!("{string_steps}").contains("max_steps"));
    }

    #[test]
    fn browser_complete_task_preserves_bounded_adapter_errors() {
        let long_error = "x".repeat(MAX_TASK_ERROR_CHARS + 1);
        let (errors, truncated) = bounded_task_errors(Some(
            &json!(["plain", 404, {"kind":"adapter"}, null, long_error]),
        ));

        assert_eq!(truncated, true);
        assert_eq!(
            errors.as_array().unwrap()[0],
            Value::String("plain".to_string())
        );
        assert_eq!(
            errors.as_array().unwrap()[1],
            Value::String("404".to_string())
        );
        assert_eq!(
            errors.as_array().unwrap()[2],
            Value::String(r#"{"kind":"adapter"}"#.to_string())
        );
        let truncated_error = errors.as_array().unwrap()[3].as_str().unwrap();
        assert!(truncated_error.contains("[Truncated:"));
        assert!(truncated_error.chars().count() <= MAX_TASK_ERROR_CHARS);
    }

    #[test]
    fn browser_complete_task_truncates_final_result_inside_cap() {
        let cap = 64;
        let (text, truncated) = bounded_task_text(Some(&json!("x".repeat(200))), cap);
        let text = text.as_str().unwrap();

        assert_eq!(truncated, true);
        assert!(text.contains("[Truncated:"));
        assert!(text.chars().count() <= cap);
    }

    #[test]
    fn browser_complete_task_infers_status_from_successful_when_is_done_missing() {
        assert_eq!(
            normalized_task_status(None, None, Some(&json!(true))),
            "completed"
        );
        assert_eq!(
            normalized_task_status(None, None, Some(&json!(false))),
            "failed"
        );
        assert_eq!(
            normalized_task_status(None, Some(&json!(false)), Some(&json!(true))),
            "incomplete"
        );
        assert_eq!(
            normalized_task_status(
                Some("completed"),
                Some(&json!(true)),
                Some(&json!(false))
            ),
            "failed"
        );
        assert_eq!(task_outcome_success("completed", None, None), false);
        assert_eq!(task_outcome_success("completed", Some(true), None), true);
        assert_eq!(task_outcome_success("completed", None, Some(true)), true);
    }

    #[test]
    fn browser_complete_task_errors_prevent_successful_completed_outcome() {
        let errors = json!(["adapter error"]);
        let errors_present = task_errors_present(&errors);
        let status = task_status_after_errors("completed", errors_present);

        assert_eq!(errors_present, true);
        assert_eq!(status, "failed");
        assert!(!(task_outcome_success(status, Some(true), Some(true)) && !errors_present));
    }

    #[test]
    fn browser_complete_task_redacts_adapter_error_values() {
        let (errors, truncated) = bounded_task_errors(Some(&json!([
            "token=sk-secret-token https://user:pass@example.com/path?code=oauth-code#id_token=jwt"
        ])));
        let serialized = errors.to_string();

        assert_eq!(truncated, false);
        assert!(serialized.contains("[redacted]"));
        assert!(!serialized.contains("sk-secret-token"));
        assert!(!serialized.contains("user:pass"));
        assert!(!serialized.contains("oauth-code"));
        assert!(!serialized.contains("id_token"));
    }
}
