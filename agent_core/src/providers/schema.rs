use serde_json::{Map, Value};

pub(crate) fn normalized_tool_parameters(parameters: &Value) -> Value {
    let mut normalized = parameters.clone();
    normalize_schema_node(&mut normalized, true);
    normalized
}

pub(crate) fn normalized_strict_tool_parameters(parameters: &Value) -> Value {
    let mut normalized = normalized_tool_parameters(parameters);
    normalize_strict_schema_node(&mut normalized);
    normalized
}

fn normalize_schema_node(value: &mut Value, is_root: bool) {
    match value {
        Value::Object(map) => normalize_schema_object(map, is_root),
        Value::Array(values) => {
            for nested in values {
                normalize_schema_node(nested, false);
            }
        }
        _ => {}
    }
}

fn normalize_schema_object(map: &mut Map<String, Value>, is_root: bool) {
    let is_object_schema = map.get("type").and_then(Value::as_str) == Some("object");
    let has_properties = matches!(map.get("properties"), Some(Value::Object(_)));

    if is_object_schema && (is_root || has_properties) && !map.contains_key("additionalProperties")
    {
        map.entry("properties".to_string())
            .or_insert_with(|| Value::Object(Map::new()));
        map.insert("additionalProperties".to_string(), Value::Bool(false));
    }

    if let Some(Value::Object(properties)) = map.get_mut("properties") {
        for nested in properties.values_mut() {
            normalize_schema_node(nested, false);
        }
    }

    if let Some(items) = map.get_mut("items") {
        normalize_schema_node(items, false);
    }

    for key in ["anyOf", "oneOf", "allOf", "prefixItems"] {
        if let Some(Value::Array(values)) = map.get_mut(key) {
            for nested in values {
                normalize_schema_node(nested, false);
            }
        }
    }

    for key in ["$defs", "definitions"] {
        if let Some(Value::Object(values)) = map.get_mut(key) {
            for nested in values.values_mut() {
                normalize_schema_node(nested, false);
            }
        }
    }
}

fn normalize_strict_schema_node(value: &mut Value) {
    match value {
        Value::Object(map) => normalize_strict_schema_object(map),
        Value::Array(values) => {
            for nested in values {
                normalize_strict_schema_node(nested);
            }
        }
        _ => {}
    }
}

fn normalize_strict_schema_object(map: &mut Map<String, Value>) {
    let originally_required = map
        .get("required")
        .and_then(Value::as_array)
        .map(|values| {
            values
                .iter()
                .filter_map(Value::as_str)
                .map(str::to_owned)
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();

    if let Some(Value::Object(properties)) = map.get_mut("properties") {
        let property_names: Vec<String> = properties.keys().cloned().collect();

        for (name, nested) in properties.iter_mut() {
            if !originally_required.iter().any(|required| required == name) {
                make_schema_nullable(nested);
            }
            normalize_strict_schema_node(nested);
        }

        map.insert(
            "required".to_string(),
            Value::Array(property_names.into_iter().map(Value::String).collect()),
        );
    }

    if let Some(items) = map.get_mut("items") {
        normalize_strict_schema_node(items);
    }

    for key in ["anyOf", "oneOf", "allOf", "prefixItems"] {
        if let Some(Value::Array(values)) = map.get_mut(key) {
            for nested in values {
                normalize_strict_schema_node(nested);
            }
        }
    }

    for key in ["$defs", "definitions"] {
        if let Some(Value::Object(values)) = map.get_mut(key) {
            for nested in values.values_mut() {
                normalize_strict_schema_node(nested);
            }
        }
    }
}

fn make_schema_nullable(value: &mut Value) {
    let allows_null = value.as_object().map(schema_allows_null).unwrap_or(false);
    if allows_null {
        return;
    }

    let Some(map) = value.as_object_mut() else {
        return;
    };

    if let Some(type_value) = map.get_mut("type") {
        match type_value {
            Value::String(existing) => {
                let existing = std::mem::take(existing);
                *type_value = Value::Array(vec![
                    Value::String(existing),
                    Value::String("null".to_string()),
                ]);
            }
            Value::Array(types) => {
                if !types.iter().any(|entry| entry.as_str() == Some("null")) {
                    types.push(Value::String("null".to_string()));
                }
            }
            _ => {}
        }
        return;
    }

    let original = value.clone();
    *value = Value::Object(Map::from_iter([(
        "anyOf".to_string(),
        Value::Array(vec![
            original,
            Value::Object(Map::from_iter([(
                "type".to_string(),
                Value::String("null".to_string()),
            )])),
        ]),
    )]));
}

fn schema_allows_null(map: &Map<String, Value>) -> bool {
    if schema_type_allows_null(map.get("type")) {
        return true;
    }

    for key in ["anyOf", "oneOf"] {
        if let Some(Value::Array(values)) = map.get(key) {
            if values.iter().any(schema_value_allows_null) {
                return true;
            }
        }
    }

    false
}

fn schema_value_allows_null(value: &Value) -> bool {
    value.as_object().map(schema_allows_null).unwrap_or(false)
}

fn schema_type_allows_null(value: Option<&Value>) -> bool {
    match value {
        Some(Value::String(kind)) => kind == "null",
        Some(Value::Array(kinds)) => kinds.iter().any(|entry| entry.as_str() == Some("null")),
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use super::{normalized_strict_tool_parameters, normalized_tool_parameters};
    use serde_json::{json, Value};

    #[test]
    fn closes_root_and_nested_object_schemas_with_explicit_properties() {
        let normalized = normalized_tool_parameters(&json!({
            "type": "object",
            "properties": {
                "path": { "type": "string" },
                "options": {
                    "type": "object",
                    "properties": {
                        "overwrite": { "type": "boolean" }
                    }
                }
            },
            "required": ["path"]
        }));

        assert_eq!(normalized["additionalProperties"], false);
        assert_eq!(
            normalized["properties"]["options"]["additionalProperties"],
            false
        );
    }

    #[test]
    fn preserves_open_ended_maps_without_explicit_properties() {
        let normalized = normalized_tool_parameters(&json!({
            "type": "object",
            "properties": {
                "metadata": {
                    "type": "object",
                    "additionalProperties": { "type": "string" }
                }
            }
        }));

        assert_eq!(
            normalized["properties"]["metadata"]["additionalProperties"],
            json!({ "type": "string" })
        );
    }

    #[test]
    fn strict_normalization_requires_every_property_and_nullables_optional_fields() {
        let normalized = normalized_strict_tool_parameters(&json!({
            "type": "object",
            "properties": {
                "path": { "type": "string" },
                "offset": { "type": "integer" },
                "options": {
                    "type": "object",
                    "properties": {
                        "overwrite": { "type": "boolean" }
                    }
                }
            },
            "required": ["path"]
        }));

        let mut required_names: Vec<&str> = normalized["required"]
            .as_array()
            .expect("required array")
            .iter()
            .filter_map(Value::as_str)
            .collect();
        required_names.sort_unstable();

        assert_eq!(required_names, vec!["offset", "options", "path"]);
        assert_eq!(normalized["properties"]["path"]["type"], json!("string"));
        assert_eq!(
            normalized["properties"]["offset"]["type"],
            json!(["integer", "null"])
        );
        assert_eq!(
            normalized["properties"]["options"]["type"],
            json!(["object", "null"])
        );
        assert_eq!(
            normalized["properties"]["options"]["required"],
            json!(["overwrite"])
        );
        assert_eq!(
            normalized["properties"]["options"]["properties"]["overwrite"]["type"],
            json!(["boolean", "null"])
        );
    }
}
