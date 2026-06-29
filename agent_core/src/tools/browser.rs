//! Browser Tools — Phase 3.4-3.14 Browser Automation
//!
//! These tools wrap the `agent-browser` CLI behind the existing ToolHandler
//! surface so the agent loop can drive a real browser without changing its
//! dispatch model. The manager keeps a single shared session alive across
//! commands (`browser_navigate` -> `browser_snapshot` -> `browser_click`, etc.)
//! and uses a short socket directory on macOS to avoid Unix socket path limits.

use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;

use async_trait::async_trait;
use serde_json::{json, Value};
use tokio::sync::Mutex;
use uuid::Uuid;

use super::browser_command::{
    cleanup_local_daemon, run_agent_browser_command, socket_dir_for_session,
};
use super::browser_executable::cdp_url_from_env;
use super::browser_input::{
    normalize_ref, optional_bool_field, optional_string_field, truncate_snapshot,
};
use super::browser_private::create_private_browser_dir;
pub use super::browser_schema::{
    browser_back_schema, browser_click_schema, browser_close_schema, browser_console_schema,
    browser_get_images_schema, browser_navigate_schema, browser_press_schema,
    browser_scroll_schema, browser_snapshot_schema, browser_type_schema, browser_vision_schema,
};
use super::browser_screenshot::{next_screenshot_path, path_resolves_inside};
use super::media::VisionAnalyzeHandler;
use super::registry::{ToolError, ToolHandler};
use super::web_fetch::validate_url;

const DEFAULT_COMMAND_TIMEOUT: Duration = Duration::from_secs(30);
const CLOSE_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Debug)]
struct BrowserState {
    session_name: Option<String>,
    socket_dir: Option<PathBuf>,
    cdp_url: Option<String>,
}

impl BrowserState {
    fn new() -> Self {
        Self {
            session_name: None,
            socket_dir: None,
            cdp_url: None,
        }
    }

    fn reset(&mut self) {
        self.session_name = None;
        self.socket_dir = None;
        self.cdp_url = None;
    }
}

#[derive(Clone, Debug)]
pub struct BrowserManager {
    inner: Arc<Mutex<BrowserState>>,
}

impl BrowserManager {
    pub fn new() -> Self {
        Self {
            inner: Arc::new(Mutex::new(BrowserState::new())),
        }
    }

    async fn open(&self, url: &str) -> Result<Value, ToolError> {
        let mut state = self.inner.lock().await;
        Self::ensure_session(&mut state)?;
        let args = vec![url.to_string()];
        Self::run_command_locked(&mut state, "open", &args, DEFAULT_COMMAND_TIMEOUT).await
    }

    async fn run_existing(&self, command: &str, args: &[String]) -> Result<Value, ToolError> {
        let mut state = self.inner.lock().await;
        if state.session_name.is_none() {
            return Err(ToolError::ExecutionFailed(
                "browser session not active; call browser_navigate first".into(),
            ));
        }
        Self::run_command_locked(&mut state, command, args, DEFAULT_COMMAND_TIMEOUT).await
    }

    async fn close(&self) -> Result<Option<String>, ToolError> {
        let mut state = self.inner.lock().await;
        let Some(session_name) = state.session_name.clone() else {
            return Ok(None);
        };
        let socket_dir = state
            .socket_dir
            .clone()
            .unwrap_or_else(|| socket_dir_for_session(&session_name));

        let warning = match Self::run_command_locked(&mut state, "close", &[], CLOSE_TIMEOUT).await
        {
            Ok(_) => None,
            Err(err) => Some(err.to_string()),
        };

        cleanup_local_daemon(&session_name, &socket_dir);
        state.reset();
        Ok(warning)
    }

    fn ensure_session(state: &mut BrowserState) -> Result<(), ToolError> {
        if state.session_name.is_none() {
            let session_name = format!("epi-{}", &Uuid::new_v4().simple().to_string()[..12]);
            let socket_dir = socket_dir_for_session(&session_name);
            create_private_browser_dir(&socket_dir)?;
            state.session_name = Some(session_name);
            state.socket_dir = Some(socket_dir);
            state.cdp_url = cdp_url_from_env()?;
        }
        Ok(())
    }

    async fn run_command_locked(
        state: &mut BrowserState,
        command_name: &str,
        args: &[String],
        timeout: Duration,
    ) -> Result<Value, ToolError> {
        let session_name = state
            .session_name
            .clone()
            .ok_or_else(|| ToolError::ExecutionFailed("browser session missing".into()))?;
        let socket_dir = state
            .socket_dir
            .clone()
            .unwrap_or_else(|| socket_dir_for_session(&session_name));
        create_private_browser_dir(&socket_dir)?;

        run_agent_browser_command(
            command_name,
            args,
            &session_name,
            state.cdp_url.as_deref(),
            &socket_dir,
            timeout,
        )
        .await
    }
}

impl Default for BrowserManager {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BrowserAction {
    Navigate,
    Snapshot,
    Click,
    Type,
    Scroll,
    Back,
    Press,
    Close,
    GetImages,
    Vision,
    Console,
}

#[derive(Clone)]
pub struct BrowserActionHandler {
    manager: BrowserManager,
    action: BrowserAction,
}

impl BrowserActionHandler {
    pub fn new(manager: BrowserManager, action: BrowserAction) -> Self {
        Self { manager, action }
    }
}

#[async_trait]
impl ToolHandler for BrowserActionHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let output = match self.action {
            BrowserAction::Navigate => navigate_impl(&self.manager, input).await?,
            BrowserAction::Snapshot => snapshot_impl(&self.manager, input).await?,
            BrowserAction::Click => click_impl(&self.manager, input).await?,
            BrowserAction::Type => type_impl(&self.manager, input).await?,
            BrowserAction::Scroll => scroll_impl(&self.manager, input).await?,
            BrowserAction::Back => back_impl(&self.manager).await?,
            BrowserAction::Press => press_impl(&self.manager, input).await?,
            BrowserAction::Close => close_impl(&self.manager).await?,
            BrowserAction::GetImages => get_images_impl(&self.manager).await?,
            BrowserAction::Vision => vision_impl(&self.manager, input).await?,
            BrowserAction::Console => console_impl(&self.manager, input).await?,
        };
        Ok(output.to_string())
    }
}

async fn navigate_impl(manager: &BrowserManager, input: &Value) -> Result<Value, ToolError> {
    let url = input
        .get("url")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'url'".into()))?;
    validate_url(url).map_err(ToolError::InvalidArguments)?;
    let raw = manager.open(url).await?;
    let actual_url = raw
        .get("data")
        .and_then(|data| data.get("url"))
        .and_then(Value::as_str)
        .unwrap_or(url);
    Ok(json!({
        "success": true,
        "url": actual_url,
    }))
}

async fn snapshot_impl(manager: &BrowserManager, input: &Value) -> Result<Value, ToolError> {
    let full = optional_bool_field(input, "full")?.unwrap_or(false);
    let mut args = Vec::new();
    if !full {
        args.push("-c".to_string());
    }
    let raw = manager.run_existing("snapshot", &args).await?;
    let snapshot_text = raw
        .get("data")
        .and_then(|data| data.get("snapshot"))
        .and_then(Value::as_str)
        .unwrap_or("");
    let refs = raw
        .get("data")
        .and_then(|data| data.get("refs"))
        .cloned()
        .unwrap_or_else(|| json!({}));
    let (snapshot, truncated) = truncate_snapshot(snapshot_text);
    let element_count = refs.as_object().map(|refs| refs.len()).unwrap_or(0);
    Ok(json!({
        "success": true,
        "snapshot": snapshot,
        "full": full,
        "element_count": element_count,
        "refs": refs,
        "truncated": truncated,
    }))
}

async fn click_impl(manager: &BrowserManager, input: &Value) -> Result<Value, ToolError> {
    let raw_ref = input
        .get("ref")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'ref'".into()))?;
    let normalized = normalize_ref(raw_ref)?;
    manager
        .run_existing("click", std::slice::from_ref(&normalized))
        .await?;
    Ok(json!({
        "success": true,
        "clicked": normalized,
    }))
}

async fn type_impl(manager: &BrowserManager, input: &Value) -> Result<Value, ToolError> {
    let raw_ref = input
        .get("ref")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'ref'".into()))?;
    let text = input
        .get("text")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'text'".into()))?;
    let normalized = normalize_ref(raw_ref)?;
    manager
        .run_existing("fill", &[normalized.clone(), text.to_string()])
        .await?;
    Ok(json!({
        "success": true,
        "element": normalized,
        "typed": text,
    }))
}

async fn scroll_impl(manager: &BrowserManager, input: &Value) -> Result<Value, ToolError> {
    let direction = input
        .get("direction")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'direction'".into()))?;
    if !matches!(direction, "up" | "down") {
        return Err(ToolError::InvalidArguments(
            "direction must be 'up' or 'down'".into(),
        ));
    }
    manager
        .run_existing("scroll", &[direction.to_string()])
        .await?;
    Ok(json!({
        "success": true,
        "scrolled": direction,
    }))
}

async fn back_impl(manager: &BrowserManager) -> Result<Value, ToolError> {
    let raw = manager.run_existing("back", &[]).await?;
    let url = raw
        .get("data")
        .and_then(|data| data.get("url"))
        .and_then(Value::as_str);
    Ok(json!({
        "success": true,
        "url": url,
    }))
}

async fn press_impl(manager: &BrowserManager, input: &Value) -> Result<Value, ToolError> {
    let key = input
        .get("key")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'key'".into()))?;
    if key.trim().is_empty() {
        return Err(ToolError::InvalidArguments("key cannot be empty".into()));
    }
    manager.run_existing("press", &[key.to_string()]).await?;
    Ok(json!({
        "success": true,
        "pressed": key,
    }))
}

async fn close_impl(manager: &BrowserManager) -> Result<Value, ToolError> {
    let warning = manager.close().await?;
    Ok(json!({
        "success": true,
        "closed": true,
        "warning": warning,
    }))
}

async fn get_images_impl(manager: &BrowserManager) -> Result<Value, ToolError> {
    let js = "JSON.stringify([...document.images].map(img => ({ src: img.src, alt: img.alt || '', width: img.naturalWidth, height: img.naturalHeight })).filter(img => img.src && !img.src.startsWith('data:')))";
    let raw = manager.run_existing("eval", &[js.to_string()]).await?;
    let raw_result = raw
        .get("data")
        .and_then(|data| data.get("result"))
        .cloned()
        .unwrap_or_else(|| json!("[]"));
    let images = match raw_result {
        Value::String(text) => serde_json::from_str::<Value>(&text).unwrap_or_else(|_| json!([])),
        Value::Array(items) => Value::Array(items),
        other => other,
    };
    let count = images.as_array().map(|items| items.len()).unwrap_or(0);
    Ok(json!({
        "success": true,
        "images": images,
        "count": count,
    }))
}

async fn vision_impl(manager: &BrowserManager, input: &Value) -> Result<Value, ToolError> {
    let question = input
        .get("question")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("missing 'question'".into()))?;
    let allow_cloud = optional_bool_field(input, "allow_cloud_external_requests")?.unwrap_or(false);
    if !allow_cloud {
        return Err(ToolError::InvalidArguments(
            "allow_cloud_external_requests must be true because browser_vision sends a browser screenshot to an external vision provider"
                .to_string(),
        ));
    }
    let provider = optional_string_field(input, "provider")?.unwrap_or("claude");
    let annotate = optional_bool_field(input, "annotate")?.unwrap_or(false);
    let screenshot_path = next_screenshot_path()?;
    let screenshot_directory = screenshot_path.parent().ok_or_else(|| {
        ToolError::ExecutionFailed("browser screenshot path missing private directory".into())
    })?;
    let mut args = Vec::new();
    if annotate {
        args.push("--annotate".to_string());
    }
    args.push("--full".to_string());
    args.push(screenshot_path.display().to_string());

    let raw = manager.run_existing("screenshot", &args).await?;
    let actual_path = raw
        .get("data")
        .and_then(|data| data.get("path"))
        .and_then(Value::as_str)
        .map(PathBuf::from)
        .unwrap_or_else(|| screenshot_path.clone());

    if !actual_path.exists() {
        return Err(ToolError::ExecutionFailed(format!(
            "browser screenshot was not created at '{}'",
            actual_path.display()
        )));
    }
    if !path_resolves_inside(&actual_path, screenshot_directory) {
        return Err(ToolError::ExecutionFailed(format!(
            "browser screenshot resolved outside private screenshot directory at '{}'",
            actual_path.display()
        )));
    }

    let vision_handler = VisionAnalyzeHandler::new()?;
    let vision_raw = vision_handler
        .execute(&json!({
            "image_path": actual_path.display().to_string(),
            "question": question,
            "provider": provider,
            "allow_cloud_external_requests": true,
        }))
        .await?;
    let mut vision_value: Value = serde_json::from_str(&vision_raw)
        .map_err(|e| ToolError::ExecutionFailed(format!("parse vision response: {e}")))?;
    if let Some(object) = vision_value.as_object_mut() {
        object.insert(
            "screenshot_path".to_string(),
            Value::String(actual_path.display().to_string()),
        );
    }
    Ok(vision_value)
}

async fn console_impl(manager: &BrowserManager, input: &Value) -> Result<Value, ToolError> {
    let clear = optional_bool_field(input, "clear")?.unwrap_or(false);
    let expression = optional_string_field(input, "expression")?;
    let mut console_args = Vec::new();
    let mut error_args = Vec::new();
    if clear {
        console_args.push("--clear".to_string());
        error_args.push("--clear".to_string());
    }

    let console = manager.run_existing("console", &console_args).await?;
    let errors = manager.run_existing("errors", &error_args).await?;

    let evaluation = if let Some(expression) = expression {
        Some(
            manager
                .run_existing("eval", &[expression.to_string()])
                .await?
                .get("data")
                .and_then(|data| data.get("result"))
                .cloned()
                .unwrap_or(Value::Null),
        )
    } else {
        None
    };

    let messages = console
        .get("data")
        .and_then(|data| data.get("messages"))
        .cloned()
        .unwrap_or_else(|| json!([]));
    let js_errors = errors
        .get("data")
        .and_then(|data| data.get("errors"))
        .cloned()
        .unwrap_or_else(|| json!([]));

    Ok(json!({
        "success": true,
        "console_messages": messages,
        "js_errors": js_errors,
        "evaluation": evaluation,
    }))
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

    use super::super::browser_screenshot::screenshot_directory;
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

    fn mark_executable(path: &Path) {
        #[cfg(unix)]
        {
            let mut permissions = fs::metadata(path).unwrap().permissions();
            permissions.set_mode(0o755);
            fs::set_permissions(path, permissions).unwrap();
        }
    }

    fn make_fake_browser(temp_root: &Path) -> PathBuf {
        let bin_dir = temp_root.join("bin");
        fs::create_dir_all(&bin_dir).unwrap();
        let script_path = bin_dir.join("agent-browser");
        let script = r#"#!/bin/sh
set -eu
if [ -n "${FAKE_BROWSER_LOG:-}" ]; then
  printf '%s\n' "$*" >> "$FAKE_BROWSER_LOG"
fi
command_name=""
last=""
prev=""
for arg in "$@"; do
  if [ "$prev" = "--json" ]; then
    command_name="$arg"
  fi
  last="$arg"
  prev="$arg"
done
case "$command_name" in
  open)
    printf '{"success":true,"data":{"url":"%s"}}\n' "$last"
    ;;
  snapshot)
    printf '{"success":true,"data":{"snapshot":"Page heading\n[@e1] Search\n[@e2] Submit","refs":{"@e1":{"role":"textbox"},"@e2":{"role":"button"}}}}\n'
    ;;
  click)
    printf '{"success":true,"data":{"clicked":"%s"}}\n' "$last"
    ;;
  fill)
    printf '{"success":true,"data":{"filled":true}}\n'
    ;;
  scroll)
    printf '{"success":true,"data":{"direction":"%s"}}\n' "$last"
    ;;
  back)
    printf '{"success":true,"data":{"url":"https://example.com/previous"}}\n'
    ;;
  press)
    printf '{"success":true,"data":{"key":"%s"}}\n' "$last"
    ;;
  close)
    printf '{"success":true,"data":{"closed":true}}\n'
    ;;
  console)
    printf '{"success":true,"data":{"messages":[{"type":"log","text":"hello from page"}]}}\n'
    ;;
  errors)
    printf '{"success":true,"data":{"errors":[{"message":"boom"}]}}\n'
    ;;
  eval)
    if printf '%s' "$*" | grep -q 'document.images'; then
      cat <<'EOF'
{"success":true,"data":{"result":"[{\"src\":\"https://example.com/image.png\",\"alt\":\"cover\",\"width\":640,\"height\":480}]"}}
EOF
    else
      printf '{"success":true,"data":{"result":"42"}}\n'
    fi
    ;;
  badjson)
    printf 'token=sk-secret-token non-json output\n'
    ;;
  fail)
    printf 'stderr token=sk-secret-token\n' >&2
    exit 7
    ;;
  jsonfail)
    printf '{"success":false,"error":"failed token=sk-secret-token https://user:pass@example.com/path"}\n'
    ;;
  envcheck)
    gemini_present=false
    openai_auth_present=false
    node_options_present=false
    fake_log_present=false
    socket_dir_present=false
    path_present=false
    dotenv_disabled=false
    if [ -n "${GEMINI_API_KEY+x}" ]; then gemini_present=true; fi
    if [ -n "${OPENAI_AUTH_MODE+x}" ]; then openai_auth_present=true; fi
    if [ -n "${NODE_OPTIONS+x}" ]; then node_options_present=true; fi
    if [ -n "${FAKE_BROWSER_LOG+x}" ]; then fake_log_present=true; fi
    if [ -n "${AGENT_BROWSER_SOCKET_DIR+x}" ]; then socket_dir_present=true; fi
    if [ -n "${PATH+x}" ]; then path_present=true; fi
    if [ "${PYTHON_DOTENV_DISABLED:-}" = "true" ]; then dotenv_disabled=true; fi
    printf '{"success":true,"data":{"gemini_api_key_present":%s,"openai_auth_mode_present":%s,"node_options_present":%s,"fake_browser_log_present":%s,"socket_dir_present":%s,"path_present":%s,"dotenv_disabled":%s}}\n' "$gemini_present" "$openai_auth_present" "$node_options_present" "$fake_log_present" "$socket_dir_present" "$path_present" "$dotenv_disabled"
    ;;
  screenshot)
    screenshot_root_present=false
    if [ -n "${AGENT_BROWSER_SCREENSHOT_DIR+x}" ]; then screenshot_root_present=true; fi
    printf 'fake png bytes' > "$last"
    printf '{"success":true,"data":{"path":"%s","screenshot_root_present":%s}}\n' "$last" "$screenshot_root_present"
    ;;
  *)
    printf '{"success":true,"data":{}}\n'
    ;;
esac
"#;
        fs::write(&script_path, script).unwrap();
        mark_executable(&script_path);
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
    async fn browser_cli_subprocess_scrubs_provider_secrets() {
        let _env_guard = env_lock().lock().await;
        let temp = tempfile::tempdir().unwrap();
        let script = make_fake_browser(temp.path());
        let log_path = temp.path().join("browser.log");
        let _path = EnvGuard::set("PATH", prepend_to_path(script.parent().unwrap()));
        let _log = EnvGuard::set("FAKE_BROWSER_LOG", log_path.as_os_str());
        let _gemini = EnvGuard::set("GEMINI_API_KEY", "AIza-test-secret");
        let _openai_auth = EnvGuard::set("OPENAI_AUTH_MODE", "browser-should-not-see-this");
        let _node_options = EnvGuard::set("NODE_OPTIONS", "--require /tmp/injected.js");
        let socket_dir = socket_dir_for_session("env-hardening");
        fs::create_dir_all(&socket_dir).unwrap();

        let output = run_agent_browser_command(
            "envcheck",
            &[],
            "env-hardening",
            None,
            &socket_dir,
            DEFAULT_COMMAND_TIMEOUT,
        )
        .await
        .unwrap();

        assert_eq!(output["data"]["gemini_api_key_present"], json!(false));
        assert_eq!(output["data"]["openai_auth_mode_present"], json!(false));
        assert_eq!(output["data"]["node_options_present"], json!(false));
        assert_eq!(output["data"]["fake_browser_log_present"], json!(true));
        assert_eq!(output["data"]["socket_dir_present"], json!(true));
        assert_eq!(output["data"]["path_present"], json!(true));
        assert_eq!(output["data"]["dotenv_disabled"], json!(true));
    }

    #[tokio::test]
    async fn browser_non_json_output_is_redacted() {
        let _env_guard = env_lock().lock().await;
        let temp = tempfile::tempdir().unwrap();
        let script = make_fake_browser(temp.path());
        let _path = EnvGuard::set("PATH", prepend_to_path(script.parent().unwrap()));
        let socket_dir = socket_dir_for_session("non-json-redaction");
        fs::create_dir_all(&socket_dir).unwrap();

        let err = run_agent_browser_command(
            "badjson",
            &[],
            "non-json-redaction",
            None,
            &socket_dir,
            DEFAULT_COMMAND_TIMEOUT,
        )
        .await
        .unwrap_err();
        let message = format!("{err}");
        assert!(message.contains("non-JSON output"));
        assert!(message.contains("stdout redacted"));
        assert!(!message.contains("sk-secret-token"));
    }

    #[tokio::test]
    async fn browser_failure_output_is_redacted() {
        let _env_guard = env_lock().lock().await;
        let temp = tempfile::tempdir().unwrap();
        let script = make_fake_browser(temp.path());
        let _path = EnvGuard::set("PATH", prepend_to_path(script.parent().unwrap()));
        let socket_dir = socket_dir_for_session("failure-redaction");
        fs::create_dir_all(&socket_dir).unwrap();

        let err = run_agent_browser_command(
            "fail",
            &[],
            "failure-redaction",
            None,
            &socket_dir,
            DEFAULT_COMMAND_TIMEOUT,
        )
        .await
        .unwrap_err();
        let message = format!("{err}");
        assert!(message.contains("exit code 7"));
        assert!(message.contains("stderr redacted"));
        assert!(!message.contains("sk-secret-token"));
    }

    #[tokio::test]
    async fn browser_json_error_detail_is_scrubbed_and_bounded() {
        let _env_guard = env_lock().lock().await;
        let temp = tempfile::tempdir().unwrap();
        let script = make_fake_browser(temp.path());
        let _path = EnvGuard::set("PATH", prepend_to_path(script.parent().unwrap()));
        let socket_dir = socket_dir_for_session("json-error-redaction");
        fs::create_dir_all(&socket_dir).unwrap();

        let err = run_agent_browser_command(
            "jsonfail",
            &[],
            "json-error-redaction",
            None,
            &socket_dir,
            DEFAULT_COMMAND_TIMEOUT,
        )
        .await
        .unwrap_err();
        let message = format!("{err}");
        assert!(message.contains("[redacted]"));
        assert!(!message.contains("sk-secret-token"));
        assert!(!message.contains("user:pass"));
    }

    #[tokio::test]
    async fn browser_navigate_blocks_private_urls() {
        let _env_guard = env_lock().lock().await;
        let temp = tempfile::tempdir().unwrap();
        let script = make_fake_browser(temp.path());
        let _path = EnvGuard::set("PATH", prepend_to_path(script.parent().unwrap()));

        let handler = BrowserActionHandler::new(BrowserManager::new(), BrowserAction::Navigate);
        let err = handler
            .execute(&json!({ "url": "http://127.0.0.1:3000" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("SSRF protection"));
    }

    #[tokio::test]
    async fn browser_handlers_reuse_the_same_session() {
        let _env_guard = env_lock().lock().await;
        let temp = tempfile::tempdir().unwrap();
        let script = make_fake_browser(temp.path());
        let log_path = temp.path().join("browser.log");
        let _path = EnvGuard::set("PATH", prepend_to_path(script.parent().unwrap()));
        let _log = EnvGuard::set("FAKE_BROWSER_LOG", log_path.as_os_str());

        let manager = BrowserManager::new();
        let navigate = BrowserActionHandler::new(manager.clone(), BrowserAction::Navigate);
        let click = BrowserActionHandler::new(manager, BrowserAction::Click);

        navigate
            .execute(&json!({ "url": "https://example.com" }))
            .await
            .unwrap();
        click.execute(&json!({ "ref": "e2" })).await.unwrap();

        let lines: Vec<String> = fs::read_to_string(&log_path)
            .unwrap()
            .lines()
            .map(|line| line.to_string())
            .collect();
        assert_eq!(lines.len(), 2);

        let session_values: Vec<String> = lines
            .iter()
            .map(|line| {
                let tokens: Vec<&str> = line.split_whitespace().collect();
                let index = tokens
                    .iter()
                    .position(|token| *token == "--session")
                    .unwrap();
                tokens[index + 1].to_string()
            })
            .collect();
        assert_eq!(session_values[0], session_values[1]);
    }

    #[tokio::test]
    async fn browser_get_images_parses_json_string_results() {
        let _env_guard = env_lock().lock().await;
        let temp = tempfile::tempdir().unwrap();
        let script = make_fake_browser(temp.path());
        let _path = EnvGuard::set("PATH", prepend_to_path(script.parent().unwrap()));

        let manager = BrowserManager::new();
        BrowserActionHandler::new(manager.clone(), BrowserAction::Navigate)
            .execute(&json!({ "url": "https://example.com/gallery" }))
            .await
            .unwrap();
        let output = BrowserActionHandler::new(manager, BrowserAction::GetImages)
            .execute(&json!({}))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&output).unwrap();
        assert_eq!(parsed["count"], json!(1));
        assert_eq!(
            parsed["images"][0]["src"],
            json!("https://example.com/image.png")
        );
    }

    #[tokio::test]
    async fn browser_close_requires_a_fresh_navigate_after_cleanup() {
        let _env_guard = env_lock().lock().await;
        let temp = tempfile::tempdir().unwrap();
        let script = make_fake_browser(temp.path());
        let _path = EnvGuard::set("PATH", prepend_to_path(script.parent().unwrap()));

        let manager = BrowserManager::new();
        BrowserActionHandler::new(manager.clone(), BrowserAction::Navigate)
            .execute(&json!({ "url": "https://example.com" }))
            .await
            .unwrap();
        BrowserActionHandler::new(manager.clone(), BrowserAction::Close)
            .execute(&json!({}))
            .await
            .unwrap();
        let err = BrowserActionHandler::new(manager, BrowserAction::Click)
            .execute(&json!({ "ref": "@e1" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("browser_navigate first"));
    }

    #[tokio::test]
    async fn browser_vision_requires_cloud_ack_before_screenshot() {
        let _env_guard = env_lock().lock().await;
        let temp = tempfile::tempdir().unwrap();
        let script = make_fake_browser(temp.path());
        let log_path = temp.path().join("browser.log");
        let _path = EnvGuard::set("PATH", prepend_to_path(script.parent().unwrap()));
        let _log = EnvGuard::set("FAKE_BROWSER_LOG", log_path.as_os_str());

        let manager = BrowserManager::new();
        BrowserActionHandler::new(manager.clone(), BrowserAction::Navigate)
            .execute(&json!({ "url": "https://example.com" }))
            .await
            .unwrap();
        let err = BrowserActionHandler::new(manager, BrowserAction::Vision)
            .execute(&json!({
                "question": "What is on this page?",
                "provider": "bogus"
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("allow_cloud_external_requests"));

        let lines: Vec<String> = fs::read_to_string(&log_path)
            .unwrap()
            .lines()
            .map(|line| line.to_string())
            .collect();
        assert_eq!(
            lines.len(),
            1,
            "vision must not screenshot before cloud ack"
        );
        assert!(lines[0].contains("open"));
    }

    #[tokio::test]
    async fn browser_screenshot_exports_private_root_to_adapter() {
        let _env_guard = env_lock().lock().await;
        let temp = tempfile::tempdir().unwrap();
        let script = make_fake_browser(temp.path());
        let _path = EnvGuard::set("PATH", prepend_to_path(script.parent().unwrap()));
        let socket_dir = socket_dir_for_session("screenshot-root-export");
        fs::create_dir_all(&socket_dir).unwrap();
        let screenshot_path = screenshot_directory().unwrap().join("root-export.png");

        let output = run_agent_browser_command(
            "screenshot",
            &[screenshot_path.display().to_string()],
            "screenshot-root-export",
            None,
            &socket_dir,
            DEFAULT_COMMAND_TIMEOUT,
        )
        .await
        .unwrap();

        assert_eq!(output["data"]["screenshot_root_present"], json!(true));
    }

    #[tokio::test]
    async fn browser_optional_flags_are_strictly_typed_before_cli_execution() {
        let manager = BrowserManager::new();

        let snapshot_err = BrowserActionHandler::new(manager.clone(), BrowserAction::Snapshot)
            .execute(&json!({ "full": "false" }))
            .await
            .unwrap_err();
        assert!(format!("{snapshot_err}").contains("full"));

        let console_clear_err = BrowserActionHandler::new(manager.clone(), BrowserAction::Console)
            .execute(&json!({ "clear": "true" }))
            .await
            .unwrap_err();
        assert!(format!("{console_clear_err}").contains("clear"));

        let console_expression_err =
            BrowserActionHandler::new(manager.clone(), BrowserAction::Console)
                .execute(&json!({ "expression": 42 }))
                .await
                .unwrap_err();
        assert!(format!("{console_expression_err}").contains("expression"));

        let vision_ack_err = BrowserActionHandler::new(manager.clone(), BrowserAction::Vision)
            .execute(&json!({
                "question": "What is visible?",
                "allow_cloud_external_requests": "true"
            }))
            .await
            .unwrap_err();
        assert!(format!("{vision_ack_err}").contains("allow_cloud_external_requests"));

        let vision_provider_err = BrowserActionHandler::new(manager.clone(), BrowserAction::Vision)
            .execute(&json!({
                "question": "What is visible?",
                "allow_cloud_external_requests": true,
                "provider": 7
            }))
            .await
            .unwrap_err();
        assert!(format!("{vision_provider_err}").contains("provider"));

        let vision_annotate_err = BrowserActionHandler::new(manager, BrowserAction::Vision)
            .execute(&json!({
                "question": "What is visible?",
                "allow_cloud_external_requests": true,
                "annotate": "yes"
            }))
            .await
            .unwrap_err();
        assert!(format!("{vision_annotate_err}").contains("annotate"));
    }

    #[test]
    fn browser_vision_schema_requires_cloud_ack() {
        let schema = browser_vision_schema();
        assert_eq!(
            schema.parameters["required"],
            json!(["question", "allow_cloud_external_requests"])
        );
    }

    #[tokio::test]
    async fn browser_console_returns_messages_errors_and_eval_output() {
        let _env_guard = env_lock().lock().await;
        let temp = tempfile::tempdir().unwrap();
        let script = make_fake_browser(temp.path());
        let _path = EnvGuard::set("PATH", prepend_to_path(script.parent().unwrap()));

        let manager = BrowserManager::new();
        BrowserActionHandler::new(manager.clone(), BrowserAction::Navigate)
            .execute(&json!({ "url": "https://example.com" }))
            .await
            .unwrap();
        let output = BrowserActionHandler::new(manager, BrowserAction::Console)
            .execute(&json!({
                "expression": "21 + 21",
                "clear": true
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&output).unwrap();
        assert_eq!(
            parsed["console_messages"][0]["text"],
            json!("hello from page")
        );
        assert_eq!(parsed["js_errors"][0]["message"], json!("boom"));
        assert_eq!(parsed["evaluation"], json!("42"));
    }
}
