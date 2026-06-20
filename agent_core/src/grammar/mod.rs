//! JSON Schema to sampler grammar bridge recovered from the Quick Capture
//! salvage track.

use llguidance::api::TopLevelGrammar;
use llguidance::toktrie::TokEnv;
use llguidance::{Matcher, ParserFactory};
use serde_json::{json, Value};

#[derive(Debug, thiserror::Error)]
pub enum GrammarError {
    #[error("schema must be a JSON object: got {0}")]
    SchemaShape(String),

    #[error("dispatch must contain at least one tool")]
    EmptyDispatch,

    #[error("dispatch schema failed to serialize: {0}")]
    Serialize(String),

    #[error("grammar parser/matcher build failed: {0}")]
    Parser(String),
}

pub fn schema_to_llg(schema: &Value) -> Result<TopLevelGrammar, GrammarError> {
    require_object_schema(schema, "schema")?;
    Ok(TopLevelGrammar::from_json_schema(schema.clone()))
}

pub fn build_dispatch_grammar(tools: &[(&str, &Value)]) -> Result<TopLevelGrammar, GrammarError> {
    let dispatch_schema = dispatch_schema_for_tools(tools)?;
    schema_to_llg(&dispatch_schema)
}

/// SS-Y masking CORE — build a token [`Matcher`] that CONSTRAINS generation to a
/// valid tool-dispatch call (exactly one of `tools`) over the given tokenizer env.
/// The vendored llguidance engine does the masking: the caller computes the
/// allowed-token mask each step ([`Matcher::compute_mask`]) and feeds back the
/// sampled token ([`Matcher::consume_token`]), so a model can only emit
/// grammar-valid tool-call JSON ("guaranteed-valid tool calls = local > cloud").
///
/// This is the masking engine ONLY — wiring it into the live MLX `LogitProcessor`
/// (behind a flag, then flipping `isFullyConstraining` once a witness proves valid
/// output) is a later SS-Y slice. Nothing here touches the generation path.
pub fn tool_dispatch_matcher(
    tools: &[(&str, &Value)],
    tok_env: &TokEnv,
) -> Result<Matcher, GrammarError> {
    let grammar = build_dispatch_grammar(tools)?;
    let factory =
        ParserFactory::new_simple(tok_env).map_err(|e| GrammarError::Parser(e.to_string()))?;
    let parser = factory
        .create_parser(grammar)
        .map_err(|e| GrammarError::Parser(e.to_string()))?;
    Ok(Matcher::new(Ok(parser)))
}

/// The token ids the matcher currently ALLOWS — computes the grammar mask and
/// returns its set bits. This is the per-step API the MLX `LogitProcessor` will
/// call: keep these logits, set every other to -inf so only a grammar-valid token
/// can be sampled, then feed the sampled token back via [`Matcher::consume_token`].
/// (SS-Y step-API for the FFI/MLX wiring — still no generation-path touch.)
pub fn allowed_token_ids(matcher: &mut Matcher) -> Result<Vec<u32>, GrammarError> {
    let mask = matcher
        .compute_mask()
        .map_err(|e| GrammarError::Parser(e.to_string()))?;
    let mut ids = Vec::with_capacity(mask.num_set());
    mask.iter_set_entries(|idx| ids.push(idx as u32));
    Ok(ids)
}

pub fn dispatch_schema_for_tools(tools: &[(&str, &Value)]) -> Result<Value, GrammarError> {
    if tools.is_empty() {
        return Err(GrammarError::EmptyDispatch);
    }

    let mut branches = Vec::with_capacity(tools.len());
    for (name, input_schema) in tools {
        require_object_schema(input_schema, name)?;
        branches.push(json!({
            "type": "object",
            "required": ["name", "input"],
            "additionalProperties": false,
            "properties": {
                "name": { "const": name },
                "input": input_schema
            }
        }));
    }

    Ok(json!({ "oneOf": branches }))
}

pub fn crane_wrapper_schema(
    answer_schema: &Value,
    reasoning_max_tokens: u32,
) -> Result<Value, GrammarError> {
    require_object_schema(answer_schema, "answer_schema")?;
    Ok(json!({
        "type": "object",
        "required": ["thinking", "answer"],
        "additionalProperties": false,
        "properties": {
            "thinking": {
                "type": "string",
                "maxLength": reasoning_max_tokens
            },
            "answer": answer_schema
        }
    }))
}

fn require_object_schema(schema: &Value, label: &str) -> Result<(), GrammarError> {
    if schema.is_object() {
        Ok(())
    } else {
        Err(GrammarError::SchemaShape(format!(
            "{label}: expected object, got {}",
            type_name(schema)
        )))
    }
}

fn type_name(value: &Value) -> &'static str {
    match value {
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
    use llguidance::toktrie::ApproximateTokEnv;

    #[test]
    fn tool_dispatch_matcher_accepts_valid_and_masks_invalid_tool_calls() {
        // SS-Y witness: the vendored llguidance engine, fed the tool-dispatch
        // grammar, accepts a valid tool call byte-for-byte and REJECTS a divergent
        // one (an unknown tool name) before the sequence ends — i.e. the mask would
        // forbid the invalid continuation. A single-byte tokenizer keeps the test
        // self-contained (no model tokenizer / no network).
        let weather_input = json!({
            "type": "object",
            "required": ["city"],
            "additionalProperties": false,
            "properties": { "city": { "type": "string" } }
        });
        let tools: Vec<(&str, &Value)> = vec![("get_weather", &weather_input)];
        let tok_env = ApproximateTokEnv::single_byte_env();

        // A valid dispatch call → every token is grammar-valid.
        let mut ok = tool_dispatch_matcher(&tools, &tok_env).unwrap();
        let valid = r#"{"name":"get_weather","input":{"city":"Paris"}}"#;
        let valid_toks = tok_env.tokenize(valid);
        let accepted = ok.validate_tokens(&valid_toks).unwrap();
        assert_eq!(
            accepted,
            valid_toks.len(),
            "a valid tool call must be fully grammar-accepted"
        );

        // An unknown tool name → rejected before the end (the grammar masks the
        // divergent byte; const \"get_weather\" can't continue as \"no_such_tool\").
        let mut bad = tool_dispatch_matcher(&tools, &tok_env).unwrap();
        let invalid = r#"{"name":"no_such_tool","input":{}}"#;
        let invalid_toks = tok_env.tokenize(invalid);
        let accepted_bad = bad.validate_tokens(&invalid_toks).unwrap();
        assert!(
            accepted_bad < invalid_toks.len(),
            "an unknown tool name must be rejected by the grammar (got {accepted_bad}/{} valid)",
            invalid_toks.len()
        );
    }

    #[test]
    fn allowed_token_ids_drive_a_valid_streaming_tool_call_and_forbid_divergence() {
        // SS-Y streaming witness: drive the matcher token-by-token exactly as the
        // MLX LogitProcessor will — at each step the ALLOWED set contains the valid
        // next token, consume it, and the completed call is accepting. Then prove
        // the mask FORBIDS a divergent token at the const tool-name position.
        let weather_input = json!({
            "type": "object",
            "required": ["city"],
            "additionalProperties": false,
            "properties": { "city": { "type": "string" } }
        });
        let tools: Vec<(&str, &Value)> = vec![("get_weather", &weather_input)];
        let tok_env = ApproximateTokEnv::single_byte_env();

        // Streamed valid call: every byte is in the allowed mask before we consume it.
        let mut m = tool_dispatch_matcher(&tools, &tok_env).unwrap();
        let valid_toks = tok_env.tokenize(r#"{"name":"get_weather","input":{"city":"Paris"}}"#);
        for &t in &valid_toks {
            let allowed = allowed_token_ids(&mut m).unwrap();
            assert!(allowed.contains(&t), "the valid next token must be in the mask");
            m.consume_token(t).unwrap();
        }
        assert!(m.is_accepting().unwrap(), "the completed tool call must be accepting");

        // After {"name":" the only valid name is the const "get_weather": 'g' is
        // allowed, 'n' (no_such_tool) is masked out — guaranteed-valid generation.
        let mut m2 = tool_dispatch_matcher(&tools, &tok_env).unwrap();
        for &t in &tok_env.tokenize(r#"{"name":""#) {
            m2.consume_token(t).unwrap();
        }
        let allowed_at_name = allowed_token_ids(&mut m2).unwrap();
        let g = tok_env.tokenize("g")[0];
        let n = tok_env.tokenize("n")[0];
        assert!(allowed_at_name.contains(&g), "'g' (get_weather) must be allowed");
        assert!(!allowed_at_name.contains(&n), "'n' (no_such_tool) must be masked out");
    }
}
