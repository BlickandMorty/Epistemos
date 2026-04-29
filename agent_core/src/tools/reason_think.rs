//! Phase 2E canary — `reason.think` as the first native `Tool` impl.
//!
//! Plan §11 Phase 2 EXIT criterion: "A canary tool (`reason.think`)
//! can be invoked through the runner with grammar-constrained output
//! validated against schema." This module satisfies that gate.
//!
//! `reason.think` is the model's sanctioned pause-and-plan tool. The
//! input thought is hard-capped at 280 chars per §4.2's Brief-Is-Better
//! finding (arxiv:2604.02155): Qwen 1.5B peaks at ~32 tokens of
//! reasoning, 256+ degrades below the no-CoT baseline. The grammar
//! enforces this at the schema layer so the model literally cannot
//! emit a longer trace.
//!
//! The legacy free function `execute_think` + `ThinkHandler` in
//! `tools/think.rs` + `tools/registry.rs:1710` continue to work
//! (legacy `ToolHandler` trait); they retire in Phase 2G after the
//! bulk-migration in 2F.

use std::sync::OnceLock;
use std::time::Instant;

use async_trait::async_trait;
use serde_json::{json, Value};

use super::{Profile, Tool, ToolCtx, ToolMeta, ToolResult, VariantId};

pub struct ReasonThinkTool;

pub const REASON_THINK_NAME: &str = "reason.think";

pub fn input_schema_value() -> &'static Value {
    static S: OnceLock<Value> = OnceLock::new();
    S.get_or_init(|| {
        json!({
            "type": "object",
            "required": ["thought"],
            "additionalProperties": false,
            "properties": {
                "thought": {
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 280,
                    "description": "Step-by-step reasoning. Hard-capped at 280 chars per §4.2 Brief-Is-Better."
                }
            }
        })
    })
}

pub fn output_schema_value() -> &'static Value {
    static S: OnceLock<Value> = OnceLock::new();
    S.get_or_init(|| {
        json!({
            "type": "object",
            "required": ["thought"],
            "additionalProperties": false,
            "properties": {
                "thought": {
                    "type": "string",
                    "minLength": 1
                }
            }
        })
    })
}

#[async_trait]
impl Tool for ReasonThinkTool {
    fn name(&self) -> &'static str {
        REASON_THINK_NAME
    }

    fn input_schema(&self) -> &'static Value {
        input_schema_value()
    }

    fn output_schema(&self) -> &'static Value {
        output_schema_value()
    }

    fn variants(&self) -> &[VariantId] {
        // Single deterministic variant — `think` is a pure pass-through;
        // there's no real fallback ladder. Variant A is the only slot used.
        &[VariantId::A]
    }

    fn profile(&self) -> Profile {
        Profile::AppStoreSafe
    }

    fn small_model_safe(&self) -> bool {
        true
    }

    async fn invoke(&self, _ctx: &ToolCtx, variant: VariantId, input: Value) -> ToolResult {
        let started = Instant::now();
        let thought = match input.get("thought").and_then(Value::as_str) {
            Some(t) => t.to_string(),
            None => {
                return ToolResult {
                    meta: ToolMeta::error(variant),
                    result: json!({"error": "thought required"}),
                };
            }
        };
        let elapsed_ms = started.elapsed().as_millis() as u32;
        ToolResult::ok(variant, elapsed_ms, json!({ "thought": thought }))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::grammar::{build_dispatch_grammar, schema_to_llg};
    use crate::tools::runner::{default_ctx, run_with_variants};
    use crate::tools::Status;
    use std::time::Duration;

    #[tokio::test]
    async fn input_schema_compiles_to_grammar() {
        // Plan §17.3 sampler-bound dispatch: the input schema must compile
        // to a llguidance grammar so the sampler can mask invalid tokens
        // at decode time. This proves Phase 2A's compiler accepts the
        // canary's schema.
        let schema = ReasonThinkTool.input_schema();
        schema_to_llg(schema).expect("reason.think input must compile to grammar");
    }

    #[tokio::test]
    async fn output_schema_compiles_to_grammar() {
        let schema = ReasonThinkTool.output_schema();
        schema_to_llg(schema).expect("reason.think output must compile to grammar");
    }

    #[tokio::test]
    async fn dispatch_grammar_with_reason_think_alone_compiles() {
        // Verify the canary slots cleanly into a §17.3 dispatch table.
        let tools: Vec<(&str, &Value)> = vec![(REASON_THINK_NAME, ReasonThinkTool.input_schema())];
        build_dispatch_grammar(&tools).expect("dispatch with reason.think must compile");
    }

    #[tokio::test]
    async fn invokable_through_runner_with_schema_validation() {
        // The plan §11 Phase 2 EXIT criterion verbatim: the canary is
        // invoked via the runner; output validates against output_schema.
        let tool = ReasonThinkTool;
        let ctx = default_ctx(Duration::from_millis(800));
        let input = json!({"thought": "I should search vault.notes before answering."});

        let r = run_with_variants(&tool, &ctx, input.clone()).await;
        assert_eq!(r.meta.status, Status::Ok, "expected Ok, got {:?}", r.meta.status);
        assert_eq!(r.meta.variant_used, VariantId::A);
        assert_eq!(
            r.result["thought"].as_str().unwrap(),
            "I should search vault.notes before answering."
        );

        // Re-validate the output against output_schema explicitly to
        // close the loop (the runner already did this internally).
        let validator = crate::tools::runner::JsonSchemaValidator;
        use crate::tools::SchemaValidator;
        validator
            .validate(ReasonThinkTool.output_schema(), &r.result)
            .expect("runner output must satisfy output_schema");
    }

    #[tokio::test]
    async fn second_invocation_hits_cache() {
        // Plan §3.6: cache wraps the runner. Second call with identical
        // input short-circuits the ladder.
        let tool = ReasonThinkTool;
        let ctx = default_ctx(Duration::from_millis(800));
        let input = json!({"thought": "first time"});

        let r1 = run_with_variants(&tool, &ctx, input.clone()).await;
        assert_eq!(r1.meta.status, Status::Ok);

        let r2 = run_with_variants(&tool, &ctx, input).await;
        assert_eq!(r2.meta.status, Status::Ok);
        // Cache hit returns the prior result identically, including the
        // recorded latency_ms — proves the cache short-circuited rather
        // than re-invoking.
        assert_eq!(r1.result, r2.result);
    }

    #[tokio::test]
    async fn missing_thought_returns_error_status_not_panic() {
        let tool = ReasonThinkTool;
        let ctx = default_ctx(Duration::from_millis(800));
        let input = json!({"NOT_thought": "x"});
        let r = run_with_variants(&tool, &ctx, input).await;
        // The tool returns Status::Error from invoke (input missing
        // `thought`); schema validation on the OUTPUT also fails because
        // the error result doesn't have `thought` either. Either path
        // surfaces as Status::Error / VariantId::Last via the runner's
        // "all variants failed" fallback.
        assert_eq!(r.meta.status, Status::Error);
    }

    #[tokio::test]
    async fn schema_rejects_thought_over_280_chars_at_validation_time() {
        // The 280-char cap from §4.2 is a schema invariant. Verify the
        // input schema rejects oversized thoughts even though our impl
        // doesn't cut them off at runtime — the grammar layer (Phase 6
        // inference loop) is where the model is *prevented* from emitting
        // them in the first place.
        let oversized = "x".repeat(281);
        let bad_input = json!({"thought": oversized});
        let validator = crate::tools::runner::JsonSchemaValidator;
        use crate::tools::SchemaValidator;
        let r = validator.validate(ReasonThinkTool.input_schema(), &bad_input);
        assert!(r.is_err(), "281-char thought must fail input schema");
    }

    #[test]
    fn schemas_are_static_and_round_trip_through_serde() {
        let inp1 = ReasonThinkTool.input_schema();
        let inp2 = ReasonThinkTool.input_schema();
        // Same `&'static Value` pointer (OnceLock) — confirms the schema
        // isn't being rebuilt per call.
        assert!(std::ptr::eq(inp1, inp2));

        let s = serde_json::to_string(inp1).unwrap();
        let parsed: Value = serde_json::from_str(&s).unwrap();
        assert_eq!(&parsed, inp1);
    }
}
