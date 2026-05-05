use agent_core::grammar::{
    build_dispatch_grammar, crane_wrapper_schema, dispatch_schema_for_tools, schema_to_llg,
    GrammarError,
};
use serde_json::{json, Value};

#[test]
fn schema_to_llg_accepts_json_schema_objects_and_rejects_other_shapes() {
    let schema = json!({
        "type": "object",
        "required": ["query"],
        "additionalProperties": false,
        "properties": {
            "query": { "type": "string", "minLength": 1 }
        }
    });
    schema_to_llg(&schema).unwrap();

    assert!(matches!(
        schema_to_llg(&json!("not a schema")),
        Err(GrammarError::SchemaShape(_))
    ));
}

#[test]
fn dispatch_schema_is_closed_and_name_const_bound() {
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
    let tools: Vec<(&str, &Value)> = vec![
        ("vault.search", &search_input),
        ("reason.think", &think_input),
    ];

    let schema = dispatch_schema_for_tools(&tools).unwrap();
    assert_eq!(schema["oneOf"][0]["additionalProperties"], json!(false));
    assert_eq!(
        schema["oneOf"][0]["properties"]["name"],
        json!({"const": "vault.search"})
    );
    assert_eq!(
        schema["oneOf"][1]["properties"]["name"],
        json!({"const": "reason.think"})
    );
    build_dispatch_grammar(&tools).unwrap();
}

#[test]
fn dispatch_rejects_empty_tools_and_non_object_inputs() {
    assert!(matches!(
        dispatch_schema_for_tools(&[]),
        Err(GrammarError::EmptyDispatch)
    ));

    let not_object = json!("bad");
    let tools: Vec<(&str, &Value)> = vec![("vault.search", &not_object)];
    assert!(matches!(
        dispatch_schema_for_tools(&tools),
        Err(GrammarError::SchemaShape(_))
    ));
}

#[test]
fn crane_wrapper_keeps_open_thinking_and_closed_answer_schema() {
    let answer_schema = json!({
        "type": "object",
        "required": ["folder_path", "confidence"],
        "additionalProperties": false,
        "properties": {
            "folder_path": { "type": "string", "minLength": 1 },
            "confidence": { "type": "number", "minimum": 0, "maximum": 1 }
        }
    });

    let wrapper = crane_wrapper_schema(&answer_schema, 256).unwrap();
    assert_eq!(wrapper["required"], json!(["thinking", "answer"]));
    assert_eq!(wrapper["additionalProperties"], json!(false));
    assert_eq!(wrapper["properties"]["thinking"]["type"], json!("string"));
    assert_eq!(wrapper["properties"]["thinking"]["maxLength"], json!(256));
    assert_eq!(wrapper["properties"]["answer"], answer_schema);
    schema_to_llg(&wrapper).unwrap();
}
