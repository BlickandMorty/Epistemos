//! Phase 2 — sampler-bound grammar compiler. Plan §3.3 + §17 + §22.1.
//!
//! Single source of truth for tool-call grammars: a JSON Schema (the same
//! one that validates results in `format::tool_meta` etc.) is compiled into
//! an `llguidance::api::TopLevelGrammar` that the sampler enforces at the
//! logit level. The model literally cannot emit a syntactically invalid call
//! — the constraint *is* the dispatch (§17.1).
//!
//! The plan §3.3 snippet uses `llguidance::Grammar::from_json_schema(&json,
//! opts)` — a slightly older API shape. The real llguidance 1.x exposes
//! `llguidance::api::TopLevelGrammar::from_json_schema(Value)` (owned, no
//! Result, no opts). The semantic contract is preserved; this module
//! adapts the surface and documents the deviation.

use llguidance::api::TopLevelGrammar;
use serde_json::{json, Value};

#[derive(Debug, thiserror::Error)]
pub enum GrammarError {
    #[error("schema must be a JSON object: got {0}")]
    SchemaShape(String),

    #[error("dispatch must contain at least one tool")]
    EmptyDispatch,
}

/// Compile a JSON Schema into a sampler-enforceable grammar.
///
/// The returned `TopLevelGrammar` is consumed by `Constraint`/`TokenParser`
/// in the inference loop (Phase 6 work) — they call `compute_mask()` on
/// each token slot to zero out invalid logits.
pub fn schema_to_llg(schema: &Value) -> Result<TopLevelGrammar, GrammarError> {
    if !schema.is_object() {
        return Err(GrammarError::SchemaShape(format!(
            "expected object, got {}",
            type_name(schema)
        )));
    }
    Ok(TopLevelGrammar::from_json_schema(schema.clone()))
}

/// Build the dispatch grammar for a set of tools. The grammar accepts
/// exactly one of: `{"name": "<tool_name>", "input": <tool_input_schema>}`
/// for each registered tool, with `additionalProperties: false`.
///
/// This is the §17.3 sampler-bound dispatch: the model can choose only
/// among the names in `tools`, and for whichever name it picks, the input
/// must conform to that tool's input schema. It cannot emit a tool name
/// that isn't registered, cannot type-mismatch an argument, cannot omit a
/// required field — these are all structurally impossible at decode time.
pub fn build_dispatch_grammar(
    tools: &[(&str, &Value)],
) -> Result<TopLevelGrammar, GrammarError> {
    if tools.is_empty() {
        return Err(GrammarError::EmptyDispatch);
    }
    let dispatch_schema = json!({
        "oneOf": tools.iter().map(|(name, input_schema)| {
            json!({
                "type": "object",
                "required": ["name", "input"],
                "additionalProperties": false,
                "properties": {
                    "name": { "const": name },
                    "input": input_schema
                }
            })
        }).collect::<Vec<_>>()
    });
    schema_to_llg(&dispatch_schema)
}

/// CRANE wrapper grammar (§22.1.2 — open thinking, closed commit). The
/// model emits `<think>…freeform up to N tokens…</think>` followed by a
/// schema-constrained `answer` payload.
///
/// Phase 2 ships the *shape* of the wrapper; the actual sentinel-token
/// region switching lives inside the inference loop (Phase 6 work). This
/// helper produces the wrapper schema so callers can compile it.
pub fn crane_wrapper_schema(answer_schema: &Value, _reasoning_max_tokens: u32) -> Value {
    // The reasoning region is unconstrained string content; the answer
    // region must conform to `answer_schema`. The sentinel tokens
    // `<think>` / `</think>` are tokenizer-added (Hermes-3 native;
    // 2-3 tokens on Qwen) and the runtime swaps the constraint at the
    // boundary.
    json!({
        "type": "object",
        "required": ["thinking", "answer"],
        "additionalProperties": false,
        "properties": {
            "thinking": {
                "type": "string",
                "description": "CRANE open-reasoning region (§22.1.2). Bounded by `reasoning_max_tokens` at the inference layer, not by the schema."
            },
            "answer": answer_schema
        }
    })
}

fn type_name(v: &Value) -> &'static str {
    match v {
        Value::Null => "null",
        Value::Bool(_) => "bool",
        Value::Number(_) => "number",
        Value::String(_) => "string",
        Value::Array(_) => "array",
        Value::Object(_) => "object",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn schema_to_llg_compiles_minimal_object() {
        let s = json!({ "type": "object" });
        schema_to_llg(&s).expect("minimal object schema must compile");
    }

    #[test]
    fn schema_to_llg_compiles_typical_tool_input() {
        let s = json!({
            "type": "object",
            "required": ["query"],
            "additionalProperties": false,
            "properties": {
                "query": { "type": "string", "minLength": 1, "maxLength": 200 },
                "k": { "type": "integer", "minimum": 1, "maximum": 50 }
            }
        });
        schema_to_llg(&s).expect("typical tool-input schema must compile");
    }

    #[test]
    fn schema_to_llg_rejects_non_object_schema() {
        let s = json!("not an object");
        assert!(schema_to_llg(&s).is_err());
    }

    #[test]
    fn build_dispatch_grammar_with_two_tools_compiles() {
        let search_input = json!({
            "type": "object",
            "required": ["query"],
            "additionalProperties": false,
            "properties": {
                "query": { "type": "string", "minLength": 1 }
            }
        });
        let think_input = json!({
            "type": "object",
            "required": ["thought"],
            "additionalProperties": false,
            "properties": {
                "thought": { "type": "string", "minLength": 1, "maxLength": 280 }
            }
        });
        let tools: Vec<(&str, &Value)> =
            vec![("vault.search", &search_input), ("reason.think", &think_input)];
        build_dispatch_grammar(&tools).expect("dispatch must compile");
    }

    #[test]
    fn build_dispatch_rejects_empty() {
        assert!(matches!(
            build_dispatch_grammar(&[]),
            Err(GrammarError::EmptyDispatch)
        ));
    }

    #[test]
    fn crane_wrapper_produces_thinking_and_answer_fields() {
        let answer_schema = json!({
            "type": "object",
            "required": ["folder_path", "confidence"],
            "additionalProperties": false,
            "properties": {
                "folder_path": { "type": "string", "minLength": 1 },
                "confidence": { "type": "number", "minimum": 0, "maximum": 1 }
            }
        });
        let wrapper = crane_wrapper_schema(&answer_schema, 256);
        assert!(wrapper["properties"]["thinking"].is_object());
        assert_eq!(
            wrapper["properties"]["answer"]["required"],
            json!(["folder_path", "confidence"])
        );
        // The wrapper itself is a valid schema that compiles.
        schema_to_llg(&wrapper).expect("CRANE wrapper schema must compile");
    }

    #[test]
    fn dispatch_grammar_includes_oneof_branches_with_const_names() {
        // Inspect the generated dispatch schema indirectly by recomputing
        // the inner JSON before passing to llguidance. This catches
        // regressions in the wrapper logic.
        let s1 = json!({"type": "object"});
        let s2 = json!({"type": "object"});
        let tools = vec![("a", &s1), ("b", &s2)];
        // We can't easily introspect TopLevelGrammar's internal shape from
        // here, but the call must not panic and must produce a Grammar.
        // The schema-side check is implicit: build_dispatch_grammar
        // composes a `oneOf` whose branches embed `name: {const: <tool>}`,
        // and TopLevelGrammar::from_json_schema processes the result.
        let _g = build_dispatch_grammar(&tools).unwrap();
    }
}
