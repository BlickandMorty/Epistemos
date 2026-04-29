//! Universal `_meta` envelope returned by every tool invocation.
//!
//! Plan §3.1: `ToolResult { meta: ToolMeta, result: serde_json::Value }`.
//! Field name is `result` (NOT `payload` or `data`); envelope is `_meta`.

use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

use super::{validate_against, FormatError};

pub const TOOL_META_V1_ID: &str = "epistemos://schemas/tool_meta.v1.json";

#[derive(Serialize, Deserialize, JsonSchema, Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[serde(rename_all = "lowercase")]
pub enum Status {
    Ok,
    Empty,
    Partial,
    Error,
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum PowerState {
    AcNominal,
    AcHot,
    BatteryNominal,
    BatteryHot,
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct ToolMeta {
    pub status: Status,
    pub variant_used: String,
    pub latency_ms: u32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub confidence: Option<f64>,
    pub schema_version: u32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub power_state: Option<PowerState>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cache_hit: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub model_id: Option<String>,
}

impl ToolMeta {
    /// Fresh OK meta with current latency. variant_used is required because
    /// the runner always knows which variant produced the result.
    pub fn ok(variant_used: impl Into<String>, latency_ms: u32) -> Self {
        Self {
            status: Status::Ok,
            variant_used: variant_used.into(),
            latency_ms,
            confidence: None,
            schema_version: 1,
            power_state: None,
            cache_hit: None,
            model_id: None,
        }
    }

    pub fn validate(&self) -> Result<(), FormatError> {
        let v = serde_json::to_value(self)?;
        validate_against(super::schemas::TOOL_META_V1, &v)
    }
}

/// Generic tool result envelope. The typed payload is `result` per §3.1.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct ToolResult<T> {
    #[serde(rename = "_meta")]
    pub meta: ToolMeta,
    pub result: T,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ok_meta_validates() {
        let m = ToolMeta::ok("variant_a", 42);
        m.validate().unwrap();
    }

    #[test]
    fn round_trip_through_json() {
        let m = ToolMeta {
            status: Status::Partial,
            variant_used: "variant_b".to_string(),
            latency_ms: 612,
            confidence: Some(0.78),
            schema_version: 1,
            power_state: Some(PowerState::AcNominal),
            cache_hit: Some(false),
            model_id: Some("qwen2.5-1.5b".to_string()),
        };
        let s = serde_json::to_string(&m).unwrap();
        let p: ToolMeta = serde_json::from_str(&s).unwrap();
        assert_eq!(p, m);
    }

    #[test]
    fn schema_rejects_invalid_status() {
        let bad = serde_json::json!({
            "status": "weird",
            "variant_used": "variant_a",
            "latency_ms": 0,
            "schema_version": 1
        });
        assert!(super::super::validate_against(super::super::schemas::TOOL_META_V1, &bad).is_err());
    }

    #[test]
    fn schema_rejects_confidence_out_of_range() {
        let bad = serde_json::json!({
            "status": "ok",
            "variant_used": "variant_a",
            "latency_ms": 0,
            "schema_version": 1,
            "confidence": 1.5
        });
        assert!(super::super::validate_against(super::super::schemas::TOOL_META_V1, &bad).is_err());
    }

    #[test]
    fn tool_result_uses_field_name_result_not_payload() {
        let r = ToolResult {
            meta: ToolMeta::ok("variant_a", 5),
            result: serde_json::json!({"hits": []}),
        };
        let s = serde_json::to_string(&r).unwrap();
        assert!(s.contains("\"_meta\":"), "envelope must be _meta");
        assert!(s.contains("\"result\":"), "payload field must be `result` per §3.1");
        assert!(!s.contains("\"payload\":"), "must never use `payload`");
    }
}
