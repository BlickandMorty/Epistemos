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
use std::time::{Duration, Instant};

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
/// 4. Output-schema validation. Schema violation → record_schema_violation
///    + ctx.health.evict(tool) per §3.2 footnote, advance to next variant.
/// 5. Status interpretation:
///    - `Ok`: cache + return.
///    - `Partial` AND confidence > 0.7: cache + return.
///    - Anything else: ctx.health.evict(tool) + advance.
/// 6. After exhausting all variants: return `error_with_context(Last, ...)`.
///
/// Plan §3.2 footnote: HealthCheck availability is cached for 5s per
/// (tool, variant); evicted on any tool-error event. The runner is
/// responsible for emitting that eviction signal — every "continue"
/// path calls ctx.health.evict(tool.name()).await before advancing.
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
            Err(_) => {
                // Timeout is a tool-error event per §3.2 footnote.
                ctx.health.evict(tool.name()).await;
                ToolResult::error(variant, "timeout")
            }
        };

        if let Err(e) = ctx.validator.validate(tool.output_schema(), &result.result) {
            ctx.tracer.record_schema_violation(tool.name(), variant, &e);
            ctx.health.evict(tool.name()).await;
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
                // Status::Error / Empty / low-confidence Partial — all
                // tool-error events per §3.2 footnote.
                ctx.health.evict(tool.name()).await;
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
    /// Plan §3.2 footnote — `(tool, variant)` availability cached
    /// for `cache_ttl` (default 5s); evicted via `evict(tool)`.
    cache: Mutex<HashMap<(String, VariantId), (Instant, bool)>>,
    cache_ttl: Duration,
    failure_threshold: u32,
    cooldown: Duration,
}

impl HealthCheckRegistry {
    /// Plan §5.3 default: open after 5 consecutive failures, 30s cooldown.
    /// Plan §3.2 default: 5s availability cache.
    pub fn new() -> Self {
        Self {
            breakers: Mutex::new(HashMap::new()),
            cache: Mutex::new(HashMap::new()),
            cache_ttl: Duration::from_secs(5),
            failure_threshold: 5,
            cooldown: Duration::from_secs(30),
        }
    }

    pub fn with_thresholds(failure_threshold: u32, cooldown: Duration) -> Self {
        Self {
            breakers: Mutex::new(HashMap::new()),
            cache: Mutex::new(HashMap::new()),
            cache_ttl: Duration::from_secs(5),
            failure_threshold,
            cooldown,
        }
    }

    /// Override the §3.2 5s availability cache TTL. Tests use this to
    /// drive deterministic cache-eviction assertions without sleeping.
    pub fn with_cache_ttl(mut self, ttl: Duration) -> Self {
        self.cache_ttl = ttl;
        self
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
    async fn is_available(&self, tool: &str, variant: VariantId) -> bool {
        // Plan §3.2 says HealthCheck covers keychain/network/breaker. For
        // Phase 2C the breaker is the only signal; richer checks
        // (keychain item present, network reachable, model resident) are
        // composed in by callers wrapping us in a stack of checks.
        //
        // Plan §3.2 footnote — cache the result for `cache_ttl` (5s
        // default) keyed by (tool, variant) so the breaker isn't
        // re-locked on every variant-A/B/C check inside a tight ladder.
        let key = (tool.to_string(), variant);
        let now = Instant::now();
        {
            let g = self.cache.lock().expect("health cache poisoned");
            if let Some((stamp, val)) = g.get(&key) {
                if now.duration_since(*stamp) < self.cache_ttl {
                    return *val;
                }
            }
        }
        let avail = self.breaker(tool).before_call().is_ok();
        self.cache
            .lock()
            .expect("health cache poisoned")
            .insert(key, (now, avail));
        avail
    }

    async fn evict(&self, tool: &str) {
        // Plan §3.2 footnote — invalidate cached availability for this
        // tool across all variants on any tool-error event.
        let mut g = self.cache.lock().expect("health cache poisoned");
        g.retain(|(t, _), _| t != tool);
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

    /// Plan §3.2 footnote: "Cached for 5s per (tool, variant)." Verify
    /// that within the cache TTL, breaker state changes don't affect
    /// `is_available` results.
    #[tokio::test]
    async fn health_check_caches_availability_per_tool_variant_per_3_2_footnote() {
        // Use a long TTL so the cache definitely doesn't expire mid-test.
        let h = HealthCheckRegistry::with_thresholds(1, Duration::from_secs(60))
            .with_cache_ttl(Duration::from_secs(60));
        // First call: cache miss; tool is fresh (no failures), available = true.
        assert!(h.is_available("cached.tool", VariantId::A).await);
        // Now trip the breaker by recording a failure.
        h.record_failure("cached.tool");
        // The breaker is now Open, but the cached "available=true" should
        // still come back per §3.2 footnote — caller must explicitly evict.
        assert!(
            h.is_available("cached.tool", VariantId::A).await,
            "cached availability survives a breaker change until evicted"
        );
    }

    #[tokio::test]
    async fn health_check_evict_invalidates_cache_across_all_variants() {
        let h = HealthCheckRegistry::with_thresholds(1, Duration::from_secs(60))
            .with_cache_ttl(Duration::from_secs(60));
        // Seed cache for two variants of the same tool.
        let _ = h.is_available("evicted.tool", VariantId::A).await;
        let _ = h.is_available("evicted.tool", VariantId::B).await;
        // Trip the breaker silently then evict.
        h.record_failure("evicted.tool");
        h.evict("evicted.tool").await;
        // Both variants must re-check (and now see breaker Open → false).
        assert!(!h.is_available("evicted.tool", VariantId::A).await);
        assert!(!h.is_available("evicted.tool", VariantId::B).await);
    }

    #[tokio::test]
    async fn health_check_evict_only_affects_named_tool() {
        let h = HealthCheckRegistry::with_thresholds(1, Duration::from_secs(60))
            .with_cache_ttl(Duration::from_secs(60));
        let _ = h.is_available("a", VariantId::A).await;
        let _ = h.is_available("b", VariantId::A).await;
        h.record_failure("a");
        h.record_failure("b");
        // Evict a only.
        h.evict("a").await;
        // a re-checks and sees breaker Open → false.
        assert!(!h.is_available("a", VariantId::A).await);
        // b is still cached at the pre-failure (true) value.
        assert!(h.is_available("b", VariantId::A).await);
    }

    /// Plan §3.2 footnote: "evicted on any tool-error event." Verify the
    /// runner emits the eviction signal on schema violations, timeouts,
    /// and Status::Error results.
    #[tokio::test]
    async fn runner_evicts_health_cache_on_schema_violation() {
        let evict_count = Arc::new(Mutex::new(0u32));
        let evicted = Arc::new(Mutex::new(Vec::<String>::new()));

        struct CountingHealth {
            evict_count: Arc<Mutex<u32>>,
            evicted: Arc<Mutex<Vec<String>>>,
        }
        #[async_trait]
        impl HealthCheck for CountingHealth {
            async fn is_available(&self, _: &str, _: VariantId) -> bool { true }
            async fn evict(&self, tool: &str) {
                *self.evict_count.lock().unwrap() += 1;
                self.evicted.lock().unwrap().push(tool.to_string());
            }
        }

        // Tool that returns a schema-invalid result on Variant A then a
        // valid result on Variant B.
        let tool = programmed(
            vec![
                ToolResult::ok(VariantId::A, 5, json!({"NOT_value": "wrong"})),
                ToolResult::ok(VariantId::B, 8, json!({"value": 7})),
            ],
            vec![VariantId::A, VariantId::B],
        );
        let ctx = ToolCtx {
            cache: Arc::new(InMemoryCache::new()),
            health: Arc::new(CountingHealth {
                evict_count: evict_count.clone(),
                evicted: evicted.clone(),
            }),
            validator: Arc::new(JsonSchemaValidator),
            tracer: Arc::new(NoopTracer),
            variant: VariantId::A,
            latency_budget: Duration::from_millis(800),
        };
        let r = run_with_variants(&tool, &ctx, json!({})).await;
        assert_eq!(r.meta.status, Status::Ok);
        assert_eq!(r.meta.variant_used, VariantId::B);
        // Schema violation on A must have triggered evict.
        let count = *evict_count.lock().unwrap();
        assert!(count >= 1, "expected at least 1 evict from schema violation, got {}", count);
        assert!(evicted.lock().unwrap().contains(&"test.programmable".to_string()));
    }

    #[tokio::test]
    async fn runner_evicts_health_cache_on_status_error() {
        let evict_count = Arc::new(Mutex::new(0u32));
        struct CountingHealth(Arc<Mutex<u32>>);
        #[async_trait]
        impl HealthCheck for CountingHealth {
            async fn is_available(&self, _: &str, _: VariantId) -> bool { true }
            async fn evict(&self, _tool: &str) {
                *self.0.lock().unwrap() += 1;
            }
        }
        // Both variants return Error status — runner walks both and
        // evicts on each, then returns Last sentinel.
        let mut e1 = ToolResult::ok(VariantId::A, 5, json!({"value": 1}));
        e1.meta.status = Status::Error;
        let mut e2 = ToolResult::ok(VariantId::B, 5, json!({"value": 1}));
        e2.meta.status = Status::Error;
        let tool = programmed(vec![e1, e2], vec![VariantId::A, VariantId::B]);
        let ctx = ToolCtx {
            cache: Arc::new(InMemoryCache::new()),
            health: Arc::new(CountingHealth(evict_count.clone())),
            validator: Arc::new(JsonSchemaValidator),
            tracer: Arc::new(NoopTracer),
            variant: VariantId::A,
            latency_budget: Duration::from_millis(800),
        };
        let r = run_with_variants(&tool, &ctx, json!({})).await;
        assert_eq!(r.meta.status, Status::Error);
        assert_eq!(r.meta.variant_used, VariantId::Last);
        assert_eq!(*evict_count.lock().unwrap(), 2, "evict per error variant");
    }
}
