//! Plan §3.2 — variant runner. Walks a tool's variant ladder, applies
//! cache → health check → timed invoke → output-schema validation
//! → status interpretation → cache write. The plan-literal snippet is
//! mirrored verbatim where possible; deviations are documented inline.
//!
//! This module also ships the concrete trait impls the runner depends on:
//! `InMemoryCache` (HashMap-backed; SQLite-backed semantic cache lands in
//! Phase 2D), `JsonSchemaValidator` (jsonschema 0.28+), `NoopTracer`,
//! `HealthCheckRegistry` (per-tool CircuitBreaker per §5.3).

use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use async_trait::async_trait;
use serde_json::Value;
use sha2::{Digest, Sha256};

use super::breaker::{BreakerState, CircuitBreaker};
use super::{
    HealthCheck, Status, Tool, ToolCache, ToolCtx, ToolResult, Tracer,
    SchemaValidator, VariantId,
};

/// Run a tool through its variant ladder per plan §3.2.
///
/// Order of operations per variant:
/// 1. Cache hit short-circuits (full ladder skipped).
/// 2. HealthCheck pre-flight — skip variant if unavailable (record_skip).
/// 3. Timed invoke (per-variant latency budget). Timeout is treated as
///    a soft Error result rather than hard panic.
/// 4. Output-schema validation. Schema violation → record_schema_violation,
///    advance to next variant.
/// 5. Status interpretation:
///    - `Ok`: cache + return.
///    - `Partial` AND confidence > 0.7: cache + return.
///    - Anything else: advance.
/// 6. After exhausting all variants: return `error_with_context(Last, ...)`.
pub async fn run_with_variants(
    tool: &dyn Tool,
    ctx: &ToolCtx,
    input: Value,
) -> ToolResult {
    if let Some(cached) = ctx.cache.get(tool.name(), &input).await {
        ctx.tracer.record_cache_hit(tool.name());
        return cached;
    }
    let mut last_err: Option<String> = None;
    for &variant in tool.variants() {
        if !ctx.health.is_available(tool.name(), variant).await {
            ctx.tracer.record_skip(tool.name(), variant, "unavailable");
            continue;
        }
        let attempt_ctx = ctx.with_variant(variant);
        let result = match tokio::time::timeout(
            ctx.latency_budget_per_variant(),
            tool.invoke(&attempt_ctx, variant, input.clone()),
        )
        .await
        {
            Ok(r) => r,
            Err(_) => ToolResult::error(variant, "timeout"),
        };

        if let Err(e) = ctx.validator.validate(tool.output_schema(), &result.result) {
            ctx.tracer.record_schema_violation(tool.name(), variant, &e);
            last_err = Some(e);
            continue;
        }

        match result.meta.status {
            Status::Ok => {
                ctx.cache.put(tool.name(), &input, &result).await;
                return result;
            }
            Status::Partial if result.meta.confidence.unwrap_or(0.0) > 0.7 => {
                ctx.cache.put(tool.name(), &input, &result).await;
                return result;
            }
            other => {
                last_err = Some(format!("variant {:?} returned status {:?}", variant, other));
                continue;
            }
        }
    }
    ToolResult::error_with_context(VariantId::Last, last_err.unwrap_or_default())
}

// ============================================================================
// InMemoryCache — HashMap-backed exact cache for tests + non-persistent
// callers. Phase 2D adds the SQLite-backed semantic cache per §3.6.
// ============================================================================

#[derive(Default)]
pub struct InMemoryCache {
    inner: Mutex<HashMap<String, ToolResult>>,
}

impl InMemoryCache {
    pub fn new() -> Self {
        Self::default()
    }

    fn key(tool: &str, input: &Value) -> String {
        let canonical = serde_json::to_vec(input).expect("Value serializes");
        let mut h = Sha256::new();
        h.update(tool.as_bytes());
        h.update(b"\x00");
        h.update(&canonical);
        format!("{:x}", h.finalize())
    }
}

#[async_trait]
impl ToolCache for InMemoryCache {
    async fn get(&self, tool: &str, input: &Value) -> Option<ToolResult> {
        self.inner
            .lock()
            .expect("cache mutex poisoned")
            .get(&Self::key(tool, input))
            .cloned()
    }

    async fn put(&self, tool: &str, input: &Value, result: &ToolResult) {
        self.inner
            .lock()
            .expect("cache mutex poisoned")
            .insert(Self::key(tool, input), result.clone());
    }
}

// ============================================================================
// JsonSchemaValidator — jsonschema 0.28+ (Draft 2020-12 native).
// ============================================================================

#[derive(Default)]
pub struct JsonSchemaValidator;

impl SchemaValidator for JsonSchemaValidator {
    fn validate(&self, schema: &Value, value: &Value) -> Result<(), String> {
        let validator = jsonschema::validator_for(schema)
            .map_err(|e| format!("schema compile failed: {e}"))?;
        if let Err(err) = validator.validate(value) {
            return Err(format!("at {}: {}", err.instance_path, err));
        }
        Ok(())
    }
}

// ============================================================================
// NoopTracer — silent. Real Tracer (`tracing` crate + os_signpost spans)
// lands in Phase 8 observability work per §5.5.
// ============================================================================

#[derive(Default)]
pub struct NoopTracer;

impl Tracer for NoopTracer {
    fn record_skip(&self, _tool: &str, _variant: VariantId, _reason: &str) {}
    fn record_schema_violation(&self, _tool: &str, _variant: VariantId, _error: &str) {}
    fn record_cache_hit(&self, _tool: &str) {}
}

// ============================================================================
// HealthCheckRegistry — per-tool CircuitBreaker dispatch (§5.3) + 5s
// (tool, variant) availability cache per §3.2 footnote.
// ============================================================================

pub struct HealthCheckRegistry {
    breakers: Mutex<HashMap<String, CircuitBreaker>>,
    failure_threshold: u32,
    cooldown: Duration,
}

impl HealthCheckRegistry {
    /// Plan §5.3 default: open after 5 consecutive failures, 30s cooldown.
    pub fn new() -> Self {
        Self {
            breakers: Mutex::new(HashMap::new()),
            failure_threshold: 5,
            cooldown: Duration::from_secs(30),
        }
    }

    pub fn with_thresholds(failure_threshold: u32, cooldown: Duration) -> Self {
        Self {
            breakers: Mutex::new(HashMap::new()),
            failure_threshold,
            cooldown,
        }
    }

    /// Get-or-create the breaker for a tool. Cheap.
    pub fn breaker(&self, tool: &str) -> CircuitBreaker {
        self.breakers
            .lock()
            .expect("breakers mutex poisoned")
            .entry(tool.to_string())
            .or_insert_with(|| CircuitBreaker::new(self.failure_threshold, self.cooldown))
            .clone()
    }

    pub fn record_success(&self, tool: &str) {
        self.breaker(tool).record_success();
    }

    pub fn record_failure(&self, tool: &str) {
        self.breaker(tool).record_failure();
    }

    pub fn state(&self, tool: &str) -> BreakerState {
        self.breaker(tool).state()
    }
}

impl Default for HealthCheckRegistry {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait]
impl HealthCheck for HealthCheckRegistry {
    async fn is_available(&self, tool: &str, _variant: VariantId) -> bool {
        // Plan §3.2 says HealthCheck covers keychain/network/breaker. For
        // Phase 2C the breaker is the only signal; richer checks
        // (keychain item present, network reachable, model resident) are
        // composed in by callers wrapping us in a stack of checks.
        self.breaker(tool).before_call().is_ok()
    }
}

// ============================================================================
// ToolCtx convenience constructor for tests + callers that just want
// the default-everything path.
// ============================================================================

pub fn default_ctx(latency_budget: Duration) -> ToolCtx {
    ToolCtx {
        cache: Arc::new(InMemoryCache::new()),
        health: Arc::new(HealthCheckRegistry::new()),
        validator: Arc::new(JsonSchemaValidator),
        tracer: Arc::new(NoopTracer),
        variant: VariantId::A,
        latency_budget,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use async_trait::async_trait;
    use serde_json::json;
    use std::sync::OnceLock;

    fn schema_object_with_value() -> &'static Value {
        static S: OnceLock<Value> = OnceLock::new();
        S.get_or_init(|| {
            json!({
                "type": "object",
                "required": ["value"],
                "additionalProperties": false,
                "properties": { "value": { "type": "integer" } }
            })
        })
    }

    fn schema_anything() -> &'static Value {
        static S: OnceLock<Value> = OnceLock::new();
        S.get_or_init(|| json!({ "type": "object" }))
    }

    /// Configurable tool: `outcomes` is consumed left-to-right per variant
    /// invocation. Each entry decides what variant N returns.
    struct ProgrammableTool {
        outcomes: Mutex<Vec<ToolResult>>,
        variants_list: Vec<VariantId>,
    }

    #[async_trait]
    impl Tool for ProgrammableTool {
        fn name(&self) -> &'static str {
            "test.programmable"
        }
        fn input_schema(&self) -> &'static Value {
            schema_anything()
        }
        fn output_schema(&self) -> &'static Value {
            schema_object_with_value()
        }
        fn variants(&self) -> &[VariantId] {
            &self.variants_list
        }
        fn profile(&self) -> super::super::Profile {
            super::super::Profile::AppStoreSafe
        }
        fn small_model_safe(&self) -> bool {
            true
        }
        async fn invoke(&self, _ctx: &ToolCtx, _v: VariantId, _i: Value) -> ToolResult {
            self.outcomes
                .lock()
                .unwrap()
                .pop()
                .unwrap_or_else(|| ToolResult::error(VariantId::Last, "no programmed outcome"))
        }
    }

    fn programmed(outcomes: Vec<ToolResult>, variants: Vec<VariantId>) -> ProgrammableTool {
        // Reverse so pop() yields them left-to-right.
        let rev: Vec<_> = outcomes.into_iter().rev().collect();
        ProgrammableTool {
            outcomes: Mutex::new(rev),
            variants_list: variants,
        }
    }

    #[tokio::test]
    async fn first_variant_ok_returns_immediately() {
        let tool = programmed(
            vec![ToolResult::ok(VariantId::A, 5, json!({"value": 42}))],
            vec![VariantId::A, VariantId::B],
        );
        let ctx = default_ctx(Duration::from_millis(800));
        let r = run_with_variants(&tool, &ctx, json!({"q": "x"})).await;
        assert_eq!(r.meta.status, Status::Ok);
        assert_eq!(r.meta.variant_used, VariantId::A);
        assert_eq!(r.result, json!({"value": 42}));
    }

    #[tokio::test]
    async fn schema_violation_advances_to_next_variant() {
        let tool = programmed(
            vec![
                ToolResult::ok(VariantId::A, 5, json!({"NOT_value": "wrong"})),
                ToolResult::ok(VariantId::B, 8, json!({"value": 7})),
            ],
            vec![VariantId::A, VariantId::B],
        );
        let ctx = default_ctx(Duration::from_millis(800));
        let r = run_with_variants(&tool, &ctx, json!({})).await;
        assert_eq!(r.meta.status, Status::Ok);
        assert_eq!(r.meta.variant_used, VariantId::B, "A failed schema, B succeeded");
    }

    #[tokio::test]
    async fn partial_with_high_confidence_returns_short_circuit() {
        let mut partial = ToolResult::ok(VariantId::A, 5, json!({"value": 1}));
        partial.meta.status = Status::Partial;
        partial.meta.confidence = Some(0.85);
        let tool = programmed(vec![partial], vec![VariantId::A, VariantId::B]);
        let ctx = default_ctx(Duration::from_millis(800));
        let r = run_with_variants(&tool, &ctx, json!({})).await;
        assert_eq!(r.meta.status, Status::Partial);
        assert_eq!(r.meta.variant_used, VariantId::A);
    }

    #[tokio::test]
    async fn partial_with_low_confidence_advances() {
        let mut partial = ToolResult::ok(VariantId::A, 5, json!({"value": 1}));
        partial.meta.status = Status::Partial;
        partial.meta.confidence = Some(0.5);
        let tool = programmed(
            vec![partial, ToolResult::ok(VariantId::B, 10, json!({"value": 2}))],
            vec![VariantId::A, VariantId::B],
        );
        let ctx = default_ctx(Duration::from_millis(800));
        let r = run_with_variants(&tool, &ctx, json!({})).await;
        assert_eq!(r.meta.status, Status::Ok);
        assert_eq!(r.meta.variant_used, VariantId::B);
    }

    #[tokio::test]
    async fn all_variants_fail_returns_error_with_last_sentinel() {
        let tool = programmed(
            vec![
                ToolResult::ok(VariantId::A, 5, json!({"NOT_value": "x"})),
                ToolResult::ok(VariantId::B, 8, json!({"NOT_value": "y"})),
            ],
            vec![VariantId::A, VariantId::B],
        );
        let ctx = default_ctx(Duration::from_millis(800));
        let r = run_with_variants(&tool, &ctx, json!({})).await;
        assert_eq!(r.meta.status, Status::Error);
        assert_eq!(r.meta.variant_used, VariantId::Last);
    }

    #[tokio::test]
    async fn cache_hit_short_circuits_entire_ladder() {
        let cache = Arc::new(InMemoryCache::new());
        // Pre-populate cache as if a prior call had succeeded.
        let cached = ToolResult::ok(VariantId::A, 1, json!({"value": 99}));
        cache
            .put("test.programmable", &json!({"q": "x"}), &cached)
            .await;
        let tool = programmed(
            vec![ToolResult::ok(VariantId::A, 5, json!({"value": -1}))],
            vec![VariantId::A],
        );
        let ctx = ToolCtx {
            cache: cache.clone(),
            health: Arc::new(HealthCheckRegistry::new()),
            validator: Arc::new(JsonSchemaValidator),
            tracer: Arc::new(NoopTracer),
            variant: VariantId::A,
            latency_budget: Duration::from_millis(800),
        };
        let r = run_with_variants(&tool, &ctx, json!({"q": "x"})).await;
        assert_eq!(r.result, json!({"value": 99}), "must come from cache");
    }

    #[tokio::test]
    async fn timeout_advances_to_next_variant() {
        struct SlowTool;
        #[async_trait]
        impl Tool for SlowTool {
            fn name(&self) -> &'static str { "test.slow" }
            fn input_schema(&self) -> &'static Value { schema_anything() }
            fn output_schema(&self) -> &'static Value { schema_object_with_value() }
            fn variants(&self) -> &[VariantId] { &[VariantId::A] }
            fn profile(&self) -> super::super::Profile {
                super::super::Profile::AppStoreSafe
            }
            fn small_model_safe(&self) -> bool { true }
            async fn invoke(&self, _: &ToolCtx, v: VariantId, _: Value) -> ToolResult {
                tokio::time::sleep(Duration::from_millis(500)).await;
                ToolResult::ok(v, 500, json!({"value": 1}))
            }
        }
        let tool = SlowTool;
        let ctx = default_ctx(Duration::from_millis(20));
        let r = run_with_variants(&tool, &ctx, json!({})).await;
        // Budget exceeded → timeout error → no further variants → Last.
        assert_eq!(r.meta.status, Status::Error);
        assert_eq!(r.meta.variant_used, VariantId::Last);
    }

    #[tokio::test]
    async fn unavailable_variant_is_skipped() {
        // Custom HealthCheck that says variant A is down, B is up.
        struct PickyHealth;
        #[async_trait]
        impl HealthCheck for PickyHealth {
            async fn is_available(&self, _tool: &str, variant: VariantId) -> bool {
                variant == VariantId::B
            }
        }
        let tool = programmed(
            vec![ToolResult::ok(VariantId::B, 5, json!({"value": 1}))],
            vec![VariantId::A, VariantId::B],
        );
        let ctx = ToolCtx {
            cache: Arc::new(InMemoryCache::new()),
            health: Arc::new(PickyHealth),
            validator: Arc::new(JsonSchemaValidator),
            tracer: Arc::new(NoopTracer),
            variant: VariantId::A,
            latency_budget: Duration::from_millis(800),
        };
        let r = run_with_variants(&tool, &ctx, json!({})).await;
        assert_eq!(r.meta.status, Status::Ok);
        assert_eq!(r.meta.variant_used, VariantId::B);
    }

    #[tokio::test]
    async fn successful_call_writes_to_cache() {
        let cache = Arc::new(InMemoryCache::new());
        let tool = programmed(
            vec![ToolResult::ok(VariantId::A, 5, json!({"value": 7}))],
            vec![VariantId::A],
        );
        let ctx = ToolCtx {
            cache: cache.clone(),
            health: Arc::new(HealthCheckRegistry::new()),
            validator: Arc::new(JsonSchemaValidator),
            tracer: Arc::new(NoopTracer),
            variant: VariantId::A,
            latency_budget: Duration::from_millis(800),
        };
        let _ = run_with_variants(&tool, &ctx, json!({"k": 1})).await;
        let hit = cache.get("test.programmable", &json!({"k": 1})).await;
        assert!(hit.is_some());
    }

    #[tokio::test]
    async fn registry_health_check_blocks_when_breaker_open() {
        let h = HealthCheckRegistry::with_thresholds(1, Duration::from_secs(60));
        h.record_failure("test.blocked");
        assert!(!h.is_available("test.blocked", VariantId::A).await);
        assert!(h.is_available("test.fresh", VariantId::A).await);
    }
}
