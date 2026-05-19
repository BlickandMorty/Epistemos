//! Phase 2 — `Tool` trait + variant ladder + sampler-bound dispatch.
//!
//! Plan: §3.1 (trait shape), §3.2 (variant runner — Phase 2C), §3.6
//! (semantic cache — Phase 2D), §17 (sampler-bound dispatch breakthrough),
//! §22.1 (Grammar-Aligned + CRANE + IterGen — Phase 6 inference loop).
//!
//! This module defines the canonical `Tool` trait going forward. The
//! legacy `ToolHandler` trait at `registry.rs:117` coexists during the
//! 2E/2F migration; the 33 in-tree tools are being incrementally
//! retrofitted to `Tool` (Phase 2E ports the canary `reason.think`,
//! Phase 2F bulk-migrates the rest, Phase 2G removes `ToolHandler`).
//!
//! ## Field-naming discipline (§3.1)
//! - The typed payload field is `result` — never `payload`, `data`,
//!   `output`. The schemas, the Rust types, the JSON wire format all
//!   use `result`.
//! - The envelope field is `_meta` — never `metadata`, `meta`. The
//!   underscore prefix marks it as a runtime envelope distinct from
//!   user-domain data.
//! - These are enforced by both the JSON Schema (`tool_meta.v1.json`)
//!   AND by the Rust type (`#[serde(rename = "_meta")]`).

// Existing per-tool modules — preserved 1:1 from the prior
// `pub mod tools { ... }` inline declaration in lib.rs.

// Phase 2C: variant runner + per-tool circuit breaker.

// Phase 2E: canary `reason.think` — first native Tool impl.

// Phase 2F: bridge legacy ToolHandler into the new Tool trait surface.
pub mod legacy_adapter;
pub mod v2_catalog;

/// Phase 2G-4 helper macro — wires a `ToolHandler` into a `Tool` impl
/// with the standard text-or-object output handling. The handler must
/// already implement `ToolHandler`. Pattern documented in `todo.rs`.
#[macro_export]
macro_rules! impl_tool_via_legacy_handler {
    (
        $handler:ty,
        name = $name:literal,
        input_schema = $schema:path,
        profile = $profile:expr,
        small_model_safe = $sms:expr $(,)?
    ) => {
        #[async_trait::async_trait]
        impl $crate::tools::Tool for $handler {
            fn name(&self) -> &'static str {
                $name
            }
            fn input_schema(&self) -> &'static serde_json::Value {
                $schema()
            }
            fn output_schema(&self) -> &'static serde_json::Value {
                $crate::tools::legacy_adapter::generic_text_or_object_output_schema()
            }
            fn variants(&self) -> &[$crate::tools::VariantId] {
                &[$crate::tools::VariantId::A]
            }
            fn profile(&self) -> $crate::tools::Profile {
                $profile
            }
            fn small_model_safe(&self) -> bool {
                $sms
            }
            async fn invoke(
                &self,
                _ctx: &$crate::tools::ToolCtx,
                variant: $crate::tools::VariantId,
                input: serde_json::Value,
            ) -> $crate::tools::ToolResult {
                let started = std::time::Instant::now();
                match <Self as $crate::tools::registry::ToolHandler>::execute(self, &input).await {
                    Ok(s) => {
                        let elapsed_ms = started.elapsed().as_millis() as u32;
                        let result = serde_json::from_str::<serde_json::Value>(&s)
                            .ok()
                            .filter(|v| v.is_object() || v.is_array())
                            .unwrap_or_else(|| serde_json::json!({"text": s}));
                        $crate::tools::ToolResult {
                            meta: $crate::tools::ToolMeta::ok(variant, elapsed_ms),
                            result,
                        }
                    }
                    Err(e) => $crate::tools::ToolResult::error(variant, e.to_string()),
                }
            }
        }
    };
}

use std::sync::Arc;
use std::time::Duration;

use async_trait::async_trait;
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use serde_json::Value;

// ============================================================================
// VariantId — slot in the per-tool variant ladder (§3.2, §4.3-§4.6).
// ============================================================================

/// Slot in the variant ladder. Tools declare which variants they support
/// in their `variants()` method; the runner walks them in order. `Last`
/// is a sentinel set on `ToolResult.meta.variant_used` when no variant
/// succeeded — tools never declare it themselves.
#[derive(Serialize, Deserialize, JsonSchema, Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[serde(rename_all = "lowercase")]
pub enum VariantId {
    A,
    B,
    C,
    D,
    E,
    F,
    G,
    H,
    /// Sentinel — runner exhausted all variants without success.
    Last,
}

// ============================================================================
// Profile — deployment-profile gating per §1.6 (PolicyProfile equivalent).
// ============================================================================

/// Deployment-profile gate per plan §1.6. AppStoreSafe tools run on both
/// App Store builds (Bounded Intelligence OS) and Pro builds (Full
/// Autonomy OS); ProOnly tools are gated to the Pro build only and never
/// surface in App Store dispatch grammars.
#[derive(Serialize, Deserialize, JsonSchema, Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum Profile {
    AppStoreSafe,
    ProOnly,
}

// ============================================================================
// Status — tool-result outcome (§3.1).
// ============================================================================

#[derive(Serialize, Deserialize, JsonSchema, Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[serde(rename_all = "lowercase")]
pub enum Status {
    Ok,
    Empty,
    Partial,
    Error,
}

// ============================================================================
// PowerState — surfaced by the router on every routing decision (§6.10).
// ============================================================================

#[derive(Serialize, Deserialize, JsonSchema, Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum PowerState {
    AcNominal,
    AcHot,
    BatteryNominal,
    BatteryHot,
}

// ============================================================================
// ToolMeta — universal `_meta` envelope returned by every tool (§3.1).
// ============================================================================

/// `_meta` envelope. Plan §3.1 uses `f32` for confidence; we follow that.
#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct ToolMeta {
    pub status: Status,
    pub variant_used: VariantId,
    pub latency_ms: u32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub confidence: Option<f32>,
    pub schema_version: u32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub power_state: Option<PowerState>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cache_hit: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub model_id: Option<String>,
}

impl ToolMeta {
    pub fn ok(variant: VariantId, latency_ms: u32) -> Self {
        Self {
            status: Status::Ok,
            variant_used: variant,
            latency_ms,
            confidence: None,
            schema_version: 1,
            power_state: None,
            cache_hit: None,
            model_id: None,
        }
    }

    pub fn error(variant: VariantId) -> Self {
        Self {
            status: Status::Error,
            variant_used: variant,
            latency_ms: 0,
            confidence: None,
            schema_version: 1,
            power_state: None,
            cache_hit: None,
            model_id: None,
        }
    }
}

// ============================================================================
// ToolResult — typed payload + envelope. Plan-literal: result is `Value`,
// not generic. Tools dispatch dynamically; static typing happens upstream
// at the schema layer.
// ============================================================================

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct ToolResult {
    #[serde(rename = "_meta")]
    pub meta: ToolMeta,
    /// Schema-validated payload. Field name is `result` per §3.1 — never
    /// `payload`, never `data`, never `output`.
    pub result: Value,
}

impl ToolResult {
    pub fn ok(variant: VariantId, latency_ms: u32, result: Value) -> Self {
        Self {
            meta: ToolMeta::ok(variant, latency_ms),
            result,
        }
    }

    pub fn error(variant: VariantId, reason: impl Into<String>) -> Self {
        Self {
            meta: ToolMeta::error(variant),
            result: serde_json::json!({"error": reason.into()}),
        }
    }

    pub fn error_with_context(variant: VariantId, context: String) -> Self {
        Self::error(variant, context)
    }
}

// ============================================================================
// Trait surfaces consumed by the variant runner (§3.2). Concrete impls
// land in Phase 2C (runner) / Phase 2D (cache).
// ============================================================================

#[async_trait]
pub trait ToolCache: Send + Sync {
    async fn get(&self, tool: &str, input: &Value) -> Option<ToolResult>;
    async fn put(&self, tool: &str, input: &Value, result: &ToolResult);
}

#[async_trait]
pub trait HealthCheck: Send + Sync {
    /// Pre-flight check before invoking a `(tool, variant)` combo.
    /// Plan §3.2: must cover keychain item present, network reachable,
    /// rate-limit budget remaining (cloud), model resident or loadable
    /// in budget (local), per-tool circuit breaker not Open.
    ///
    /// Plan §3.2 footnote: results are "cached for 5s per (tool,
    /// variant); evicted on any tool-error event." Concrete impls
    /// implement the cache; consumers call `evict(tool)` from the
    /// runner's error paths to invalidate stale "available" hits.
    async fn is_available(&self, tool: &str, variant: VariantId) -> bool;

    /// Plan §3.2 footnote — invalidate cached availability after a
    /// tool-error event. Default impl is a no-op for stub
    /// implementations that don't cache.
    async fn evict(&self, _tool: &str) {}
}

pub trait SchemaValidator: Send + Sync {
    fn validate(&self, schema: &Value, value: &Value) -> Result<(), String>;
}

pub trait Tracer: Send + Sync {
    fn record_skip(&self, tool: &str, variant: VariantId, reason: &str);
    fn record_schema_violation(&self, tool: &str, variant: VariantId, error: &str);
    fn record_cache_hit(&self, tool: &str);
}

// ============================================================================
// ToolCtx — per-call runtime context handed to `Tool::invoke` (§3.2).
// ============================================================================

#[derive(Clone)]
pub struct ToolCtx {
    pub cache: Arc<dyn ToolCache>,
    pub health: Arc<dyn HealthCheck>,
    pub validator: Arc<dyn SchemaValidator>,
    pub tracer: Arc<dyn Tracer>,
    pub variant: VariantId,
    pub latency_budget: Duration,
}

impl ToolCtx {
    pub fn with_variant(&self, variant: VariantId) -> Self {
        Self {
            variant,
            ..self.clone()
        }
    }

    pub fn latency_budget_per_variant(&self) -> Duration {
        self.latency_budget
    }
}

// ============================================================================
// The Tool trait — plan §3.1 canonical shape.
// ============================================================================

/// Every Phase 2+ tool implements this trait. The trait is the contract
/// the variant runner consumes: schemas drive validation, variants drive
/// the ladder, profile drives App Store / Pro gating, `small_model_safe`
/// drives the routing layer's choice between local-1.5B and local-7B.
#[async_trait]
pub trait Tool: Send + Sync {
    fn name(&self) -> &'static str;
    fn input_schema(&self) -> &'static Value;
    fn output_schema(&self) -> &'static Value;
    fn variants(&self) -> &[VariantId];
    fn profile(&self) -> Profile;
    fn small_model_safe(&self) -> bool;
    async fn invoke(&self, ctx: &ToolCtx, variant: VariantId, input: Value) -> ToolResult;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn variant_ids_serialize_lowercase() {
        for (variant, expected) in [
            (VariantId::A, "\"a\""),
            (VariantId::B, "\"b\""),
            (VariantId::Last, "\"last\""),
        ] {
            assert_eq!(serde_json::to_string(&variant).unwrap(), expected);
        }
    }

    #[test]
    fn profile_serializes_snake_case() {
        assert_eq!(
            serde_json::to_string(&Profile::AppStoreSafe).unwrap(),
            "\"app_store_safe\""
        );
        assert_eq!(
            serde_json::to_string(&Profile::ProOnly).unwrap(),
            "\"pro_only\""
        );
    }

    #[test]
    fn tool_meta_uses_f32_confidence_per_plan_3_1() {
        let m = ToolMeta {
            status: Status::Ok,
            variant_used: VariantId::A,
            latency_ms: 42,
            confidence: Some(0.5_f32),
            schema_version: 1,
            power_state: Some(PowerState::AcNominal),
            cache_hit: None,
            model_id: None,
        };
        // Confidence type is f32; if anyone widens to f64 they must
        // update both ToolMeta + the schema in tandem.
        let _f: Option<f32> = m.confidence;
    }

    #[test]
    fn tool_result_serializes_result_field_not_payload() {
        let r = ToolResult::ok(VariantId::A, 5, serde_json::json!({"hits": []}));
        let s = serde_json::to_string(&r).unwrap();
        assert!(s.contains("\"_meta\":"), "envelope must be _meta");
        assert!(s.contains("\"result\":"), "payload field must be `result` per §3.1");
        assert!(!s.contains("\"payload\":"), "must never use `payload`");
        assert!(!s.contains("\"data\":"), "must never use `data` for the payload");
    }

    #[test]
    fn tool_meta_round_trips_via_json_with_variant_id_typed() {
        let m = ToolMeta {
            status: Status::Partial,
            variant_used: VariantId::C,
            latency_ms: 600,
            confidence: Some(0.78),
            schema_version: 1,
            power_state: Some(PowerState::BatteryNominal),
            cache_hit: Some(true),
            model_id: Some("qwen2.5-1.5b".into()),
        };
        let s = serde_json::to_string(&m).unwrap();
        let p: ToolMeta = serde_json::from_str(&s).unwrap();
        assert_eq!(p, m);
        assert_eq!(p.variant_used, VariantId::C);
    }

    #[test]
    fn tool_ctx_with_variant_replaces_only_variant() {
        // Construct minimal ToolCtx with stub trait objects to verify
        // the with_variant builder doesn't reset other fields.
        struct StubCache;
        #[async_trait]
        impl ToolCache for StubCache {
            async fn get(&self, _: &str, _: &Value) -> Option<ToolResult> { None }
            async fn put(&self, _: &str, _: &Value, _: &ToolResult) {}
        }
        struct StubHealth;
        #[async_trait]
        impl HealthCheck for StubHealth {
            async fn is_available(&self, _: &str, _: VariantId) -> bool { true }
        }
        struct StubValidator;
        impl SchemaValidator for StubValidator {
            fn validate(&self, _: &Value, _: &Value) -> Result<(), String> { Ok(()) }
        }
        struct StubTracer;
        impl Tracer for StubTracer {
            fn record_skip(&self, _: &str, _: VariantId, _: &str) {}
            fn record_schema_violation(&self, _: &str, _: VariantId, _: &str) {}
            fn record_cache_hit(&self, _: &str) {}
        }

        let ctx = ToolCtx {
            cache: Arc::new(StubCache),
            health: Arc::new(StubHealth),
            validator: Arc::new(StubValidator),
            tracer: Arc::new(StubTracer),
            variant: VariantId::A,
            latency_budget: Duration::from_millis(800),
        };
        let stepped = ctx.with_variant(VariantId::C);
        assert_eq!(stepped.variant, VariantId::C);
        assert_eq!(stepped.latency_budget, Duration::from_millis(800));
        // Original unchanged (clone semantics).
        assert_eq!(ctx.variant, VariantId::A);
    }

    /// Mock Tool to prove the trait compiles + can be invoked dynamically.
    /// The Phase 2C runner consumes this same trait surface.
    struct MockTool {
        input: &'static Value,
        output: &'static Value,
    }

    #[async_trait]
    impl Tool for MockTool {
        fn name(&self) -> &'static str { "mock.canary" }
        fn input_schema(&self) -> &'static Value { self.input }
        fn output_schema(&self) -> &'static Value { self.output }
        fn variants(&self) -> &[VariantId] { &[VariantId::A] }
        fn profile(&self) -> Profile { Profile::AppStoreSafe }
        fn small_model_safe(&self) -> bool { true }
        async fn invoke(
            &self,
            _ctx: &ToolCtx,
            variant: VariantId,
            input: Value,
        ) -> ToolResult {
            ToolResult::ok(variant, 1, input)
        }
    }

    #[tokio::test]
    async fn mock_tool_implements_full_trait_surface() {
        // Use std::sync::OnceLock for the test schemas — no stable
        // alternative exists for static Value at this scope.
        use std::sync::OnceLock;
        static IN: OnceLock<Value> = OnceLock::new();
        static OUT: OnceLock<Value> = OnceLock::new();
        let input = IN.get_or_init(|| serde_json::json!({"type": "object"}));
        let output = OUT.get_or_init(|| serde_json::json!({"type": "object"}));

        let tool = MockTool { input, output };
        assert_eq!(tool.name(), "mock.canary");
        assert_eq!(tool.variants(), &[VariantId::A]);
        assert_eq!(tool.profile(), Profile::AppStoreSafe);
        assert!(tool.small_model_safe());

        // Build a minimal ctx and invoke.
        struct C;
        #[async_trait]
        impl ToolCache for C {
            async fn get(&self, _: &str, _: &Value) -> Option<ToolResult> { None }
            async fn put(&self, _: &str, _: &Value, _: &ToolResult) {}
        }
        struct H;
        #[async_trait]
        impl HealthCheck for H {
            async fn is_available(&self, _: &str, _: VariantId) -> bool { true }
        }
        struct V;
        impl SchemaValidator for V {
            fn validate(&self, _: &Value, _: &Value) -> Result<(), String> { Ok(()) }
        }
        struct T;
        impl Tracer for T {
            fn record_skip(&self, _: &str, _: VariantId, _: &str) {}
            fn record_schema_violation(&self, _: &str, _: VariantId, _: &str) {}
            fn record_cache_hit(&self, _: &str) {}
        }
        let ctx = ToolCtx {
            cache: Arc::new(C),
            health: Arc::new(H),
            validator: Arc::new(V),
            tracer: Arc::new(T),
            variant: VariantId::A,
            latency_budget: Duration::from_millis(800),
        };
        let result = tool
            .invoke(&ctx, VariantId::A, serde_json::json!({"x": 1}))
            .await;
        assert_eq!(result.meta.status, Status::Ok);
        assert_eq!(result.meta.variant_used, VariantId::A);
        assert_eq!(result.result, serde_json::json!({"x": 1}));
    }
}
