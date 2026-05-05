//! JSON Schema to sampler grammar bridge recovered from the Quick Capture
//! salvage track.

use llguidance::api::TopLevelGrammar;
use serde_json::{json, Value};

#[derive(Debug, thiserror::Error)]
pub enum GrammarError {
    #[error("schema must be a JSON object: got {0}")]
    SchemaShape(String),

    #[error("dispatch must contain at least one tool")]
    EmptyDispatch,
}

pub fn schema_to_llg(schema: &Value) -> Result<TopLevelGrammar, GrammarError> {
    require_object_schema(schema, "schema")?;
    Ok(TopLevelGrammar::from_json_schema(schema.clone()))
}

pub fn build_dispatch_grammar(tools: &[(&str, &Value)]) -> Result<TopLevelGrammar, GrammarError> {
    let dispatch_schema = dispatch_schema_for_tools(tools)?;
    schema_to_llg(&dispatch_schema)
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
