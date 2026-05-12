//! macOS Native Specialties — Phase 4 A1/A2/A3
//!
//! These are the Perception Stack specialties that require entitlement-gated
//! macOS APIs (Accessibility, ScreenCaptureKit, Vision, CGEvent). They cannot
//! be implemented in pure Rust — instead, they delegate to the Swift side via
//! the `AgentEventDelegate` callback interface.
//!
//! * `perceive` — hybrid AX + Vision + VLM percept of any running macOS app
//! * `interact` — semantic click/type/scroll/drag against a live app
//! * `screen_watch` — blocking watch on a screen region or file path
//!
//! Failures are surfaced as JSON `{ "success": false, "error": "..." }` so the
//! agent loop can decide whether to retry or fall back.

use std::sync::Arc;

use async_trait::async_trait;
use serde_json::{json, Value};

use crate::bridge::AgentEventDelegate;

use super::registry::{ToolError, ToolHandler};

const MAX_APP_NAME_CHARS: usize = 120;
const MAX_INTERACT_TARGET_CHARS: usize = 2_000;
const MAX_INTERACT_VALUE_CHARS: usize = 64 * 1024;
const MAX_WATCH_TARGET_CHARS: usize = 4_096;
const MAX_WATCH_CONDITION_CHARS: usize = 2_000;
const MAX_DELEGATE_RESPONSE_CHARS: usize = 256 * 1024;
const MIN_WATCH_TIMEOUT_SECS: u64 = 1;
const MAX_WATCH_TIMEOUT_SECS: u64 = 600;

fn ensure_char_cap(label: &str, value: &str, cap: usize) -> Result<(), ToolError> {
    let count = value.chars().count();
    if count > cap {
        return Err(ToolError::InvalidArguments(format!(
            "{label} exceeds {cap} characters"
        )));
    }
    Ok(())
}

fn parse_delegate_json(tool_name: &str, response: String) -> Result<Value, ToolError> {
    if response.chars().count() > MAX_DELEGATE_RESPONSE_CHARS {
        return Err(ToolError::ExecutionFailed(format!(
            "{tool_name} delegate response exceeded {MAX_DELEGATE_RESPONSE_CHARS} character cap"
        )));
    }

    serde_json::from_str(&response).map_err(|_| {
        ToolError::ExecutionFailed(format!(
            "{tool_name} delegate returned non-JSON response; raw output redacted"
        ))
    })
}

// MARK: - perceive

pub struct PerceiveHandler {
    delegate: Arc<dyn AgentEventDelegate>,
}

impl PerceiveHandler {
    pub fn new(delegate: Arc<dyn AgentEventDelegate>) -> Self {
        Self { delegate }
    }
}

#[async_trait]
impl ToolHandler for PerceiveHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let app_name = input
            .get("app_name")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'app_name'".into()))?
            .to_string();
        ensure_char_cap("app_name", &app_name, MAX_APP_NAME_CHARS)?;
        let depth = input
            .get("depth")
            .map(|value| {
                value
                    .as_str()
                    .ok_or_else(|| ToolError::InvalidArguments("'depth' must be a string".into()))
            })
            .transpose()?
            .unwrap_or("fast")
            .to_string();
        if !matches!(depth.as_str(), "fast" | "enriched" | "full") {
            return Err(ToolError::InvalidArguments(format!(
                "depth '{depth}' invalid (expected fast|enriched|full)"
            )));
        }

        // The Swift callback is blocking — offload it to a blocking task so
        // the tokio executor isn't stalled while ScreenCaptureKit renders.
        let delegate = Arc::clone(&self.delegate);
        let app_for_task = app_name.clone();
        let depth_for_task = depth.clone();
        let payload = tokio::task::spawn_blocking(move || {
            delegate.perceive_app(app_for_task, depth_for_task)
        })
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("perceive join: {e}")))?;

        let parsed = parse_delegate_json("perceive", payload)?;
        Ok(json!({
            "app_name": app_name,
            "depth": depth,
            "percept": parsed,
        })
        .to_string())
    }
}

pub fn perceive_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "perceive".to_string(),
        description: "Specialty A1 — fused AX + Vision + VLM percept of any running macOS app. \
             Returns structured UI elements (role, label, position, ref) so you can target them \
             with the 'interact' tool. depth='fast' requests AX-only percepts, 'enriched' requests \
             AX + OCR, and 'full' requests AX + OCR + screenshot analysis when the host delegate \
             has the required permissions."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "app_name": { "type": "string", "description": "Target application name (e.g., 'Safari', 'Finder')." },
                "depth": {
                    "type": "string",
                    "enum": ["fast", "enriched", "full"],
                    "default": "fast"
                }
            },
            "required": ["app_name"]
        }),
    }
}

// MARK: - interact

pub struct InteractHandler {
    delegate: Arc<dyn AgentEventDelegate>,
}

impl InteractHandler {
    pub fn new(delegate: Arc<dyn AgentEventDelegate>) -> Self {
        Self { delegate }
    }
}

#[async_trait]
impl ToolHandler for InteractHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let app_name = input
            .get("app_name")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'app_name'".into()))?;
        ensure_char_cap("app_name", app_name, MAX_APP_NAME_CHARS)?;
        let action = input
            .get("action")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'action'".into()))?;
        if !matches!(
            action,
            "click" | "type" | "scroll" | "drag" | "press_key" | "hover"
        ) {
            return Err(ToolError::InvalidArguments(format!(
                "action '{action}' invalid (expected click|type|scroll|drag|press_key|hover)"
            )));
        }
        let target = input
            .get("target")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'target'".into()))?;
        ensure_char_cap("target", target, MAX_INTERACT_TARGET_CHARS)?;
        let value = input
            .get("value")
            .map(|value| {
                value
                    .as_str()
                    .ok_or_else(|| ToolError::InvalidArguments("'value' must be a string".into()))
            })
            .transpose()?;
        if let Some(value) = value {
            ensure_char_cap("value", value, MAX_INTERACT_VALUE_CHARS)?;
        }

        let payload = json!({
            "app_name": app_name,
            "action": action,
            "target": target,
            "value": value.map(Value::from).unwrap_or(Value::Null),
        })
        .to_string();

        let delegate = Arc::clone(&self.delegate);
        let response = tokio::task::spawn_blocking(move || delegate.interact_with_app(payload))
            .await
            .map_err(|e| ToolError::ExecutionFailed(format!("interact join: {e}")))?;

        let parsed = parse_delegate_json("interact", response)?;
        Ok(parsed.to_string())
    }
}

pub fn interact_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "interact".to_string(),
        description: "Specialty A2 — interact with any macOS app by semantic reference. \
             Supports click, type, scroll, drag, press_key, and hover. 'target' can be a \
             natural-language element query ('the Save button') or a ref returned by \
             'perceive'. Requires Accessibility permission; actions are dispatched via AX \
             and fall back to CGEvent when needed."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "app_name": { "type": "string" },
                "action": {
                    "type": "string",
                    "enum": ["click", "type", "scroll", "drag", "press_key", "hover"]
                },
                "target": { "type": "string", "description": "Element query or @ref from perceive." },
                "value": { "type": "string", "description": "Text for 'type', key name for 'press_key', optional otherwise." }
            },
            "required": ["app_name", "action", "target"]
        }),
    }
}

// MARK: - screen_watch

pub struct ScreenWatchHandler {
    delegate: Arc<dyn AgentEventDelegate>,
}

impl ScreenWatchHandler {
    pub fn new(delegate: Arc<dyn AgentEventDelegate>) -> Self {
        Self { delegate }
    }
}

#[async_trait]
impl ToolHandler for ScreenWatchHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let mode = input
            .get("mode")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'mode'".into()))?;
        if !matches!(mode, "visual_region" | "file_path" | "app_state") {
            return Err(ToolError::InvalidArguments(format!(
                "mode '{mode}' invalid (expected visual_region|file_path|app_state)"
            )));
        }
        let target = input
            .get("target")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'target'".into()))?;
        ensure_char_cap("target", target, MAX_WATCH_TARGET_CHARS)?;
        let condition = input
            .get("condition")
            .map(|value| {
                value.as_str().ok_or_else(|| {
                    ToolError::InvalidArguments("'condition' must be a string".into())
                })
            })
            .transpose()?
            .unwrap_or("changes");
        ensure_char_cap("condition", condition, MAX_WATCH_CONDITION_CHARS)?;
        let timeout_secs = input
            .get("timeout_secs")
            .map(|value| {
                value.as_u64().ok_or_else(|| {
                    ToolError::InvalidArguments("'timeout_secs' must be an integer".into())
                })
            })
            .transpose()?
            .unwrap_or(60);
        if !(MIN_WATCH_TIMEOUT_SECS..=MAX_WATCH_TIMEOUT_SECS).contains(&timeout_secs) {
            return Err(ToolError::InvalidArguments(format!(
                "timeout_secs must be between {MIN_WATCH_TIMEOUT_SECS} and {MAX_WATCH_TIMEOUT_SECS}"
            )));
        }

        let payload = json!({
            "mode": mode,
            "target": target,
            "condition": condition,
            "timeout_secs": timeout_secs,
        })
        .to_string();

        let delegate = Arc::clone(&self.delegate);
        let response = tokio::task::spawn_blocking(move || delegate.start_screen_watch(payload))
            .await
            .map_err(|e| ToolError::ExecutionFailed(format!("screen_watch join: {e}")))?;

        let parsed = parse_delegate_json("screen_watch", response)?;
        Ok(parsed.to_string())
    }
}

pub fn screen_watch_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "screen_watch".to_string(),
        description: "Specialty A3 — block on a screen region, file path, or app state until a \
             condition triggers. Mode 'visual_region' watches a rect for pixel changes, \
             'file_path' uses FSEvents, 'app_state' polls a named app. Use this to wait for \
             builds, downloads, or UI state transitions without burning tokens on polling."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "mode": { "type": "string", "enum": ["visual_region", "file_path", "app_state"] },
                "target": { "type": "string", "description": "Screen rect [x,y,w,h], file glob, or app name." },
                "condition": { "type": "string", "description": "'changes', 'exists', 'contains:<text>' ...", "default": "changes" },
                "timeout_secs": { "type": "integer", "default": 60, "minimum": 1, "maximum": 600 }
            },
            "required": ["mode", "target"]
        }),
    }
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    /// Scripted delegate that returns a canned response and records the last
    /// payload it received. Lets us unit test the Phase 4 handlers without
    /// the Swift bridge.
    struct RecordingDelegate {
        perceive_response: String,
        interact_response: String,
        watch_response: String,
        last_payload: Mutex<Option<String>>,
    }

    impl RecordingDelegate {
        fn new(perceive: &str, interact: &str, watch: &str) -> Self {
            Self {
                perceive_response: perceive.to_string(),
                interact_response: interact.to_string(),
                watch_response: watch.to_string(),
                last_payload: Mutex::new(None),
            }
        }
    }

    impl AgentEventDelegate for RecordingDelegate {
        fn on_thinking_delta(&self, _: String) {}
        fn on_text_delta(&self, _: String) {}
        fn on_tool_input_delta(&self, _: u32, _: String) {}
        fn on_tool_started(&self, _: String, _: String, _: String) {}
        fn on_tool_completed(&self, _: String, _: String, _: bool) {}
        fn on_subagent_spawned(&self, _: String, _: String) {}
        fn on_permission_required(&self, _: String, _: String, _: String, _: String) {}
        fn on_context_compacting(&self, _: u32) {}
        fn on_context_compacted(&self, _: u32) {}
        fn on_turn_started(&self, _: u32, _: u32) {}
        fn on_complete(&self, _: String, _: u32, _: u32) {}
        fn on_error(&self, _: String) {}
        fn execute_computer_action(&self, _: String) -> String {
            "{}".to_string()
        }
        fn wait_for_permission(&self, _: String) -> bool {
            true
        }
        fn ask_user_question(&self, _: String) -> String {
            "{}".to_string()
        }
        fn perceive_app(&self, app: String, depth: String) -> String {
            *self.last_payload.lock().unwrap() = Some(format!("{app}/{depth}"));
            self.perceive_response.clone()
        }
        fn interact_with_app(&self, payload: String) -> String {
            *self.last_payload.lock().unwrap() = Some(payload);
            self.interact_response.clone()
        }
        fn start_screen_watch(&self, payload: String) -> String {
            *self.last_payload.lock().unwrap() = Some(payload);
            self.watch_response.clone()
        }
        fn manage_ssm_state(&self, _: String) -> String {
            "{}".to_string()
        }
        fn generate_constrained(&self, _: String, _: String) -> String {
            "{}".to_string()
        }
        fn generate_image(&self, _: String, _: String) -> String {
            "{\"error\":\"image_generate stub\"}".to_string()
        }
        fn trigger_nightbrain_job(&self, _: String, _: String) -> String {
            "{}".to_string()
        }
        fn get_partner_context(&self, _: String, _: u32) -> String {
            "{}".to_string()
        }
    }

    #[tokio::test]
    async fn perceive_forwards_app_and_depth_and_wraps_response() {
        let delegate: Arc<dyn AgentEventDelegate> = Arc::new(RecordingDelegate::new(
            r#"{"elements":[{"role":"button","label":"Save"}]}"#,
            "{}",
            "{}",
        ));
        let handler = PerceiveHandler::new(delegate);
        let result = handler
            .execute(&json!({ "app_name": "Finder", "depth": "enriched" }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["app_name"], json!("Finder"));
        assert_eq!(parsed["depth"], json!("enriched"));
        assert!(parsed["percept"]["elements"].is_array());
    }

    #[tokio::test]
    async fn perceive_rejects_unknown_depth() {
        let delegate: Arc<dyn AgentEventDelegate> =
            Arc::new(RecordingDelegate::new("{}", "{}", "{}"));
        let handler = PerceiveHandler::new(delegate);
        let err = handler
            .execute(&json!({ "app_name": "Finder", "depth": "laser" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("depth"));
    }

    #[tokio::test]
    async fn perceive_rejects_oversized_app_name() {
        let delegate: Arc<dyn AgentEventDelegate> =
            Arc::new(RecordingDelegate::new("{}", "{}", "{}"));
        let handler = PerceiveHandler::new(delegate);
        let app_name = "a".repeat(MAX_APP_NAME_CHARS + 1);
        let err = handler
            .execute(&json!({ "app_name": app_name }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("app_name exceeds"));
    }

    #[tokio::test]
    async fn perceive_rejects_non_json_delegate_without_echoing_raw() {
        let raw = "not json sk-secret-token";
        let delegate: Arc<dyn AgentEventDelegate> =
            Arc::new(RecordingDelegate::new(raw, "{}", "{}"));
        let handler = PerceiveHandler::new(delegate);
        let err = handler
            .execute(&json!({ "app_name": "Finder" }))
            .await
            .unwrap_err();
        let message = format!("{err}");
        assert!(message.contains("non-JSON"));
        assert!(!message.contains("sk-secret-token"));
    }

    #[tokio::test]
    async fn interact_forwards_action_payload() {
        let delegate: Arc<dyn AgentEventDelegate> = Arc::new(RecordingDelegate::new(
            "{}",
            r#"{"success":true,"element_found":"Save button","action_performed":"click"}"#,
            "{}",
        ));
        let handler = InteractHandler::new(Arc::clone(&delegate));
        let result = handler
            .execute(&json!({
                "app_name": "TextEdit",
                "action": "click",
                "target": "Save button"
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["success"], json!(true));
        assert_eq!(parsed["action_performed"], json!("click"));
    }

    #[tokio::test]
    async fn interact_rejects_unknown_action() {
        let delegate: Arc<dyn AgentEventDelegate> =
            Arc::new(RecordingDelegate::new("{}", "{}", "{}"));
        let handler = InteractHandler::new(delegate);
        let err = handler
            .execute(&json!({
                "app_name": "Finder",
                "action": "teleport",
                "target": "wherever"
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("action"));
    }

    #[tokio::test]
    async fn interact_rejects_non_string_value() {
        let delegate: Arc<dyn AgentEventDelegate> =
            Arc::new(RecordingDelegate::new("{}", "{}", "{}"));
        let handler = InteractHandler::new(delegate);
        let err = handler
            .execute(&json!({
                "app_name": "Finder",
                "action": "type",
                "target": "search",
                "value": 7
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("value"));
    }

    #[tokio::test]
    async fn interact_rejects_oversized_value() {
        let delegate: Arc<dyn AgentEventDelegate> =
            Arc::new(RecordingDelegate::new("{}", "{}", "{}"));
        let handler = InteractHandler::new(delegate);
        let value = "v".repeat(MAX_INTERACT_VALUE_CHARS + 1);
        let err = handler
            .execute(&json!({
                "app_name": "Finder",
                "action": "type",
                "target": "search",
                "value": value
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("value exceeds"));
    }

    #[tokio::test]
    async fn interact_rejects_non_json_delegate_without_echoing_raw() {
        let raw = "not json api_key=do-not-leak";
        let delegate: Arc<dyn AgentEventDelegate> =
            Arc::new(RecordingDelegate::new("{}", raw, "{}"));
        let handler = InteractHandler::new(delegate);
        let err = handler
            .execute(&json!({
                "app_name": "Finder",
                "action": "click",
                "target": "Save"
            }))
            .await
            .unwrap_err();
        let message = format!("{err}");
        assert!(message.contains("non-JSON"));
        assert!(!message.contains("api_key"));
    }

    #[tokio::test]
    async fn screen_watch_forwards_mode_and_condition() {
        let delegate: Arc<dyn AgentEventDelegate> = Arc::new(RecordingDelegate::new(
            "{}",
            "{}",
            r#"{"triggered":true,"reason":"file created","elapsed_ms":512}"#,
        ));
        let handler = ScreenWatchHandler::new(delegate);
        let result = handler
            .execute(&json!({
                "mode": "file_path",
                "target": "/tmp/ready",
                "condition": "exists",
                "timeout_secs": 5
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["triggered"], json!(true));
        assert_eq!(parsed["reason"], json!("file created"));
    }

    #[tokio::test]
    async fn screen_watch_rejects_unknown_mode() {
        let delegate: Arc<dyn AgentEventDelegate> =
            Arc::new(RecordingDelegate::new("{}", "{}", "{}"));
        let handler = ScreenWatchHandler::new(delegate);
        let err = handler
            .execute(&json!({ "mode": "telepathy", "target": "x" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("mode"));
    }

    #[tokio::test]
    async fn screen_watch_rejects_invalid_timeout() {
        let delegate: Arc<dyn AgentEventDelegate> =
            Arc::new(RecordingDelegate::new("{}", "{}", "{}"));
        let handler = ScreenWatchHandler::new(delegate);
        let err = handler
            .execute(&json!({
                "mode": "app_state",
                "target": "Finder",
                "timeout_secs": MAX_WATCH_TIMEOUT_SECS + 1
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("timeout_secs"));
    }

    #[tokio::test]
    async fn screen_watch_rejects_non_json_delegate_without_echoing_raw() {
        let raw = "not json password=do-not-leak";
        let delegate: Arc<dyn AgentEventDelegate> =
            Arc::new(RecordingDelegate::new("{}", "{}", raw));
        let handler = ScreenWatchHandler::new(delegate);
        let err = handler
            .execute(&json!({
                "mode": "app_state",
                "target": "Finder"
            }))
            .await
            .unwrap_err();
        let message = format!("{err}");
        assert!(message.contains("non-JSON"));
        assert!(!message.contains("password"));
    }
}
