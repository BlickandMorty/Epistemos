//! Phase 5 — Native skills: Spotlight + Vision + voice + clipboard.
//!
//! These tools delegate the actual capture primitives to the Swift side
//! via `AgentEventDelegate` (Phase 5 methods: capture_screenshot,
//! capture_voice, capture_clipboard). Per FINAL_SYNTHESIS §5.1: keeping
//! capture in-process via UniFFI satisfies "one substrate, one trust
//! boundary" — no subprocess, no IPC daemon, just a UniFFI hop into the
//! same process address space.
//!
//! Per PLAN.md Phase 5 exit:
//! - End-to-end voice → text → route → write succeeds in <2s p95 on M-series.
//! - Screenshot → OCR → route → write succeeds with bounding-box preservation.
//!
//! Rust owns the Tool surface + scheduling; Swift owns the on-device
//! hardware (ScreenCaptureKit + Vision + SpeechAnalyzer).

use std::sync::Arc;

use async_trait::async_trait;
use serde_json::{json, Value};

use crate::bridge::AgentEventDelegate;

use super::registry::{ToolError, ToolHandler};

// MARK: - capture.screenshot — Vision OCR with bounding boxes

pub struct CaptureScreenshotHandler {
    delegate: Arc<dyn AgentEventDelegate>,
}

impl CaptureScreenshotHandler {
    pub fn new(delegate: Arc<dyn AgentEventDelegate>) -> Self {
        Self { delegate }
    }
}

crate::impl_tool_via_legacy_handler!(
    CaptureScreenshotHandler,
    name = "capture.screenshot",
    input_schema = super::v2_catalog::capture_screenshot::input_schema,
    profile = super::Profile::AppStoreSafe,
    small_model_safe = true,
);

#[async_trait]
impl ToolHandler for CaptureScreenshotHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let region = input.get("region").cloned().unwrap_or_else(|| json!("fullscreen"));
        let preserve_layout = input
            .get("preserve_layout")
            .and_then(Value::as_bool)
            .unwrap_or(true);
        let payload = json!({
            "region": region,
            "preserve_layout": preserve_layout,
        })
        .to_string();
        let delegate = Arc::clone(&self.delegate);
        let response =
            tokio::task::spawn_blocking(move || delegate.capture_screenshot(payload))
                .await
                .map_err(|e| {
                    ToolError::ExecutionFailed(format!("capture_screenshot join: {e}"))
                })?;
        let parsed: Value = serde_json::from_str(&response).unwrap_or_else(|_| {
            json!({
                "raw": response,
                "error": "non-json delegate response",
            })
        });
        Ok(parsed.to_string())
    }
}

// MARK: - capture.voice — SpeechAnalyzer ASR

pub struct CaptureVoiceHandler {
    delegate: Arc<dyn AgentEventDelegate>,
}

impl CaptureVoiceHandler {
    pub fn new(delegate: Arc<dyn AgentEventDelegate>) -> Self {
        Self { delegate }
    }
}

crate::impl_tool_via_legacy_handler!(
    CaptureVoiceHandler,
    name = "capture.voice",
    input_schema = super::v2_catalog::capture_voice::input_schema,
    profile = super::Profile::AppStoreSafe,
    small_model_safe = true,
);

#[async_trait]
impl ToolHandler for CaptureVoiceHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let max_duration_secs = input
            .get("max_duration_secs")
            .and_then(Value::as_u64)
            .unwrap_or(60)
            .clamp(1, 600);
        let language_hint = input.get("language_hint").and_then(Value::as_str);
        let payload = json!({
            "max_duration_secs": max_duration_secs,
            "language_hint": language_hint,
        })
        .to_string();
        let delegate = Arc::clone(&self.delegate);
        let response = tokio::task::spawn_blocking(move || delegate.capture_voice(payload))
            .await
            .map_err(|e| ToolError::ExecutionFailed(format!("capture_voice join: {e}")))?;
        let parsed: Value = serde_json::from_str(&response).unwrap_or_else(|_| {
            json!({"raw": response, "error": "non-json delegate response"})
        });
        Ok(parsed.to_string())
    }
}

// MARK: - capture.clipboard — NSPasteboard read

pub struct CaptureClipboardHandler {
    delegate: Arc<dyn AgentEventDelegate>,
}

impl CaptureClipboardHandler {
    pub fn new(delegate: Arc<dyn AgentEventDelegate>) -> Self {
        Self { delegate }
    }
}

crate::impl_tool_via_legacy_handler!(
    CaptureClipboardHandler,
    name = "capture.clipboard",
    input_schema = super::v2_catalog::capture_clipboard::input_schema,
    profile = super::Profile::AppStoreSafe,
    small_model_safe = true,
);

#[async_trait]
impl ToolHandler for CaptureClipboardHandler {
    async fn execute(&self, _input: &Value) -> Result<String, ToolError> {
        let delegate = Arc::clone(&self.delegate);
        let response = tokio::task::spawn_blocking(move || delegate.capture_clipboard())
            .await
            .map_err(|e| ToolError::ExecutionFailed(format!("capture_clipboard join: {e}")))?;
        let parsed: Value = serde_json::from_str(&response).unwrap_or_else(|_| {
            json!({"raw": response, "error": "non-json delegate response"})
        });
        Ok(parsed.to_string())
    }
}
