//! JSON Schema to sampler grammar bridge recovered from the Quick Capture
//! salvage track.

use llguidance::api::TopLevelGrammar;
use llguidance::toktrie::{ApproximateTokEnv, TokEnv, TokRxInfo, TokTrie};
use llguidance::{Matcher, ParserFactory};
use serde_json::{json, Value};
use std::sync::Arc;

/// SS-Y: the raw `extern "C"` FFI seam that drives the masking matcher from Swift.
pub mod ffi;

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

/// Build a [`TokEnv`] from a model's vocabulary (token id → raw bytes) — the bridge
/// from a real MLX/GGUF tokenizer to the masking engine. The FFI/MLX path passes the
/// loaded model's vocab (e.g. via llguidance's `token_bytes_from_tokenizer_json`),
/// so the mask then operates over the MODEL's tokens, not the byte-level test env.
fn vocab_tok_env(vocab: &[Vec<u8>], eos_token_id: u32) -> TokEnv {
    let info = TokRxInfo {
        vocab_size: vocab.len() as u32,
        tok_eos: eos_token_id,
        tok_bos: None,
        tok_pad: None,
        tok_unk: None,
        tok_end_of_turn: None,
    };
    Arc::new(ApproximateTokEnv::new(TokTrie::from(&info, vocab)))
}

/// SS-Y: a [`Matcher`] constraining tool-dispatch calls over a REAL model
/// vocabulary (multi-byte tokens), not the byte-level test env. This is what the
/// FFI/MLX wiring builds — the matcher masks the model's own token logits, so a
/// single multi-byte token is allowed only when its whole byte run is grammar-valid.
pub fn tool_dispatch_matcher_with_vocab(
    tools: &[(&str, &Value)],
    vocab: &[Vec<u8>],
    eos_token_id: u32,
) -> Result<Matcher, GrammarError> {
    tool_dispatch_matcher(tools, &vocab_tok_env(vocab, eos_token_id))
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
            assert!(
                allowed.contains(&t),
                "the valid next token must be in the mask"
            );
            m.consume_token(t).unwrap();
        }
        assert!(
            m.is_accepting().unwrap(),
            "the completed tool call must be accepting"
        );

        // After {"name":" the only valid name is the const "get_weather": 'g' is
        // allowed, 'n' (no_such_tool) is masked out — guaranteed-valid generation.
        let mut m2 = tool_dispatch_matcher(&tools, &tok_env).unwrap();
        for &t in &tok_env.tokenize(r#"{"name":""#) {
            m2.consume_token(t).unwrap();
        }
        let allowed_at_name = allowed_token_ids(&mut m2).unwrap();
        let g = tok_env.tokenize("g")[0];
        let n = tok_env.tokenize("n")[0];
        assert!(
            allowed_at_name.contains(&g),
            "'g' (get_weather) must be allowed"
        );
        assert!(
            !allowed_at_name.contains(&n),
            "'n' (no_such_tool) must be masked out"
        );
    }

    #[test]
    fn matcher_constrains_over_a_multi_byte_vocab_like_a_real_tokenizer() {
        // Real model tokenizers emit MULTI-BYTE tokens that can span grammar
        // positions; the mask must include a multi-byte token only when its WHOLE
        // byte run is grammar-valid. Vocab = all single bytes + a few multi-byte
        // chunks (the valid + an invalid tool name, each as one token).
        let mut vocab: Vec<Vec<u8>> = (0u16..=255).map(|b| vec![b as u8]).collect();
        vocab.push(b"get_weather".to_vec()); // token id 256: the valid tool name
        vocab.push(b"no_such_tool".to_vec()); // token id 257: an invalid tool name
        vocab.push(b"<eos>".to_vec()); // token id 258
        let eos = (vocab.len() - 1) as u32;
        let get_w = 256u32;
        let no_such = 257u32;

        let weather_input = json!({
            "type": "object",
            "required": ["city"],
            "additionalProperties": false,
            "properties": { "city": { "type": "string" } }
        });
        let tools: Vec<(&str, &Value)> = vec![("get_weather", &weather_input)];
        let tok_env = vocab_tok_env(&vocab, eos);

        // A valid call (tokenized over the multi-byte vocab) is fully accepted.
        let mut ok = tool_dispatch_matcher_with_vocab(&tools, &vocab, eos).unwrap();
        let valid = tok_env.tokenize(r#"{"name":"get_weather","input":{"city":"Paris"}}"#);
        assert_eq!(
            ok.validate_tokens(&valid).unwrap(),
            valid.len(),
            "a valid call must be fully accepted with a multi-byte vocab"
        );

        // At the const tool-name position the MULTI-BYTE get_weather token is allowed
        // and the multi-byte no_such_tool token is masked out — the mask reasons over
        // each token's whole byte run, not single bytes.
        let mut m = tool_dispatch_matcher_with_vocab(&tools, &vocab, eos).unwrap();
        for &t in &tok_env.tokenize(r#"{"name":""#) {
            m.consume_token(t).unwrap();
        }
        let allowed = allowed_token_ids(&mut m).unwrap();
        assert!(
            allowed.contains(&get_w),
            "the multi-byte get_weather token must be allowed"
        );
        assert!(
            !allowed.contains(&no_such),
            "the multi-byte no_such_tool token must be masked out"
        );
    }
}
