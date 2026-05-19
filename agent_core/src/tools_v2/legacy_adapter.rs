//! Phase 2F — bridge the legacy `ToolHandler` trait into the new
//! plan §3.1 `Tool` trait surface.
//!
//! The adapter is a behavior-preserving wrapper: any existing
//! `Box<dyn ToolHandler>` can be exposed as a `Tool` by attaching the
//! schemas + variants metadata that the §3.1 trait demands but the
//! legacy trait does not carry. This makes the 33-tool migration
//! tractable: every tool gets a `Tool` impl in 2F via the adapter
//! (zero behavior delta, ~10 lines per tool); native re-implementations
//! of individual tool internals happen incrementally as the variant
//! ladder pattern proves itself per-tool.
//!
//! ## What this is NOT
//!
//! - Not a new tool runtime — the legacy handler runs verbatim inside
//!   the adapter's `invoke`.
//! - Not a permission gate — `Profile` is a deployment-build gate
//!   (§1.6), separate from the existing `RiskLevel` / `ToolTier`
//!   plumbing in `registry.rs`. Both stay in force.
//! - Not the long-term home for tools that need real variants (§4.3-§4.6
//!   route_capture). Those land natively per plan §11 Phase 3.
//!
//! ## Plan-canonical naming
//!
//! Plan §3.1 / §3.5 / §6.7 use dotted tool names (`vault.search`,
//! `reason.think`). The legacy `ToolHandler` registry uses underscored
//! names (`vault_search`). The adapter exposes the dotted form;
//! callers that drive the new `Tool` trait surface (Phase 3+ router)
//! see plan-canonical names, while the legacy underscored names remain
//! addressable through `ToolRegistry::execute()` until Phase 2G.

use std::sync::Arc;

use async_trait::async_trait;
use serde_json::{json, Value};

use crate::tools::registry::ToolHandler;
use super::{Profile, Tool, ToolCtx, ToolMeta, ToolResult, VariantId};

/// Static metadata bundle — the 7 plan-§3.1 method results that the
/// legacy handler can't supply on its own. Each migrated tool ships
/// a `static SPEC: AdapterSpec = AdapterSpec { ... }` constant.
#[derive(Clone, Copy)]
pub struct AdapterSpec {
    pub name: &'static str,
    pub input_schema: fn() -> &'static Value,
    pub output_schema: fn() -> &'static Value,
    pub variants: &'static [VariantId],
    pub profile: Profile,
    pub small_model_safe: bool,
}

/// Wraps a `ToolHandler` as a `Tool` per plan §3.1.
pub struct LegacyToolAdapter {
    spec: AdapterSpec,
    handler: Arc<dyn ToolHandler>,
}

impl LegacyToolAdapter {
    pub fn new(spec: AdapterSpec, handler: Arc<dyn ToolHandler>) -> Self {
        Self { spec, handler }
    }

    /// Convenience for adapter construction in 2F-N catalog modules.
    pub fn boxed(spec: AdapterSpec, handler: Arc<dyn ToolHandler>) -> Box<dyn Tool> {
        Box::new(Self::new(spec, handler))
    }
}

#[async_trait]
impl Tool for LegacyToolAdapter {
    fn name(&self) -> &'static str {
        self.spec.name
    }

    fn input_schema(&self) -> &'static Value {
        (self.spec.input_schema)()
    }

    fn output_schema(&self) -> &'static Value {
        (self.spec.output_schema)()
    }

    fn variants(&self) -> &[VariantId] {
        self.spec.variants
    }

    fn profile(&self) -> Profile {
        self.spec.profile
    }

    fn small_model_safe(&self) -> bool {
        self.spec.small_model_safe
    }

    async fn invoke(&self, _ctx: &ToolCtx, variant: VariantId, input: Value) -> ToolResult {
        let started = std::time::Instant::now();
        match self.handler.execute(&input).await {
            Ok(text) => {
                let elapsed_ms = started.elapsed().as_millis() as u32;
                // Try to round-trip the legacy String result through
                // serde_json — if the tool returned a JSON-serialized
                // payload, the parsed Value preserves structure; if it
                // returned plain text, we wrap as `{ "text": "..." }`
                // so the result schema is uniform across all adapters.
                let result_value = match serde_json::from_str::<Value>(&text) {
                    Ok(parsed) if parsed.is_object() || parsed.is_array() => parsed,
                    _ => json!({ "text": text }),
                };
                ToolResult {
                    meta: ToolMeta::ok(variant, elapsed_ms),
                    result: result_value,
                }
            }
            Err(e) => ToolResult::error(variant, e.to_string()),
        }
    }
}

/// Generic output schema usable by any legacy adapter that doesn't have
/// a tighter native shape: the result is either an object/array (when the
/// legacy handler returned JSON) or `{ "text": <string> }`. Schema is
/// permissive on purpose — schema validation runs at the runner layer
/// and we don't want to fail-out otherwise-correct handlers during
/// the migration window.
pub fn generic_text_or_object_output_schema() -> &'static Value {
    use std::sync::OnceLock;
    static S: OnceLock<Value> = OnceLock::new();
    S.get_or_init(|| {
        json!({
            "anyOf": [
                {
                    "type": "object",
                    "required": ["text"],
                    "properties": { "text": { "type": "string" } }
                },
                { "type": "object" },
                { "type": "array" }
            ]
        })
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::tools::registry::ToolError;
    use crate::tools::runner::{default_ctx, run_with_variants};
    use crate::tools::Status;
    use std::sync::OnceLock;
    use std::time::Duration;

    /// Stub legacy handler that returns either a plain string or a
    /// JSON-serialized payload, depending on construction.
    struct StubHandler {
        out: String,
    }

    #[async_trait]
    impl ToolHandler for StubHandler {
        async fn execute(&self, _input: &Value) -> Result<String, ToolError> {
            Ok(self.out.clone())
        }
    }

    fn input_schema() -> &'static Value {
        static S: OnceLock<Value> = OnceLock::new();
        S.get_or_init(|| {
            json!({
                "type": "object",
                "properties": { "q": { "type": "string" } },
                "required": ["q"]
            })
        })
    }

    const TEST_SPEC: AdapterSpec = AdapterSpec {
        name: "test.legacy_adapter",
        input_schema,
        output_schema: generic_text_or_object_output_schema,
        variants: &[VariantId::A],
        profile: Profile::AppStoreSafe,
        small_model_safe: true,
    };

    #[tokio::test]
    async fn adapter_wraps_plain_string_output_as_text_object() {
        let handler = Arc::new(StubHandler { out: "hello world".to_string() });
        let tool = LegacyToolAdapter::new(TEST_SPEC, handler);
        let ctx = default_ctx(Duration::from_millis(800));
        let r = run_with_variants(&tool, &ctx, json!({"q": "x"})).await;
        assert_eq!(r.meta.status, Status::Ok);
        assert_eq!(r.result["text"].as_str().unwrap(), "hello world");
    }

    #[tokio::test]
    async fn adapter_preserves_json_object_output_structure() {
        let handler = Arc::new(StubHandler {
            out: r#"{"hits":[{"path":"a.md"},{"path":"b.md"}]}"#.to_string(),
        });
        let tool = LegacyToolAdapter::new(TEST_SPEC, handler);
        let ctx = default_ctx(Duration::from_millis(800));
        let r = run_with_variants(&tool, &ctx, json!({"q": "x"})).await;
        assert_eq!(r.meta.status, Status::Ok);
        assert_eq!(r.result["hits"][0]["path"].as_str().unwrap(), "a.md");
    }

    #[tokio::test]
    async fn adapter_propagates_handler_error_as_status_error() {
        struct FailingHandler;
        #[async_trait]
        impl ToolHandler for FailingHandler {
            async fn execute(&self, _: &Value) -> Result<String, ToolError> {
                Err(ToolError::ExecutionFailed("nope".to_string()))
            }
        }
        let tool = LegacyToolAdapter::new(TEST_SPEC, Arc::new(FailingHandler));
        let ctx = default_ctx(Duration::from_millis(800));
        let r = run_with_variants(&tool, &ctx, json!({"q": "x"})).await;
        // The handler errors; runner records the error and falls through
        // to "all variants failed" → VariantId::Last.
        assert_eq!(r.meta.status, Status::Error);
    }

    #[tokio::test]
    async fn adapter_exposes_static_schemas_via_tool_trait() {
        let handler = Arc::new(StubHandler { out: "x".to_string() });
        let tool = LegacyToolAdapter::new(TEST_SPEC, handler);
        // Pointer-equality proves the schemas come from OnceLock-backed
        // statics — the adapter doesn't rebuild them per call.
        assert!(std::ptr::eq(tool.input_schema(), input_schema()));
        assert!(std::ptr::eq(
            tool.output_schema(),
            generic_text_or_object_output_schema()
        ));
        assert_eq!(tool.name(), "test.legacy_adapter");
        assert_eq!(tool.variants(), &[VariantId::A]);
        assert_eq!(tool.profile(), Profile::AppStoreSafe);
        assert!(tool.small_model_safe());
    }

    #[tokio::test]
    async fn adapter_input_schema_compiles_to_dispatch_grammar() {
        // Plan §17.3 sampler-bound dispatch: any adapted tool's input
        // schema must compile via Phase 2A's compiler.
        use crate::grammar::{build_dispatch_grammar, schema_to_llg};
        let handler = Arc::new(StubHandler { out: "x".to_string() });
        let tool = LegacyToolAdapter::new(TEST_SPEC, handler);
        schema_to_llg(tool.input_schema()).expect("input schema must compile");
        let pairs: Vec<(&str, &Value)> = vec![(tool.name(), tool.input_schema())];
        build_dispatch_grammar(&pairs).expect("dispatch must compile");
    }
}
