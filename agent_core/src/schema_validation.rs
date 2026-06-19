//! Schema validation gate for REPAIR — Deterministic Schema Engine, P8.2 spec §C.1
//! (docs/DETERMINISTIC_SCHEMA_ENGINE_SPEC_2026_06_18.md).
//!
//! The existing `tools_v2::runner::JsonSchemaValidator` returns the FIRST error (it's an
//! accept/reject gate). A repair loop needs the opposite: ALL the ways an emitted value
//! violates the schema, so the model can be told everything to fix at once instead of
//! one error per round-trip. This collects every violation via `jsonschema`'s
//! `iter_errors`. Pure + deterministic + unit-tested. Non-duplicating: complementary to
//! the single-error validator, not a replacement.

use serde_json::Value;

/// Every way `value` violates `schema`, as human-readable "at <path>: <message>" strings
/// for a repair prompt. Empty = valid. A schema that fails to compile is reported as a
/// single violation, so a broken schema never silently "passes".
pub fn all_violations(schema: &Value, value: &Value) -> Vec<String> {
    let validator = match jsonschema::validator_for(schema) {
        Ok(v) => v,
        Err(e) => return vec![format!("schema compile failed: {e}")],
    };
    validator
        .iter_errors(value)
        .map(|err| format!("at {}: {}", err.instance_path, err))
        .collect()
}

/// Whether `value` satisfies `schema` (no violations) — convenience over `all_violations`.
pub fn is_valid(schema: &Value, value: &Value) -> bool {
    all_violations(schema, value).is_empty()
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn schema() -> Value {
        json!({
            "type": "object",
            "properties": {
                "name": {"type": "string"},
                "count": {"type": "integer"}
            },
            "required": ["name", "count"]
        })
    }

    #[test]
    fn a_valid_value_has_no_violations() {
        let value = json!({"name": "x", "count": 3});
        assert!(is_valid(&schema(), &value));
        assert!(all_violations(&schema(), &value).is_empty());
    }

    #[test]
    fn collects_all_violations_not_just_the_first() {
        // BOTH properties have the wrong type → both must be reported (the point of this
        // gate vs the single-error validator).
        let value = json!({"name": 123, "count": "not an int"});
        let violations = all_violations(&schema(), &value);
        assert!(violations.len() >= 2, "expected all violations, got {violations:?}");
        assert!(!is_valid(&schema(), &value));
    }

    #[test]
    fn missing_required_field_is_reported() {
        let value = json!({"name": "x"}); // missing 'count'
        assert!(!is_valid(&schema(), &value));
        assert!(!all_violations(&schema(), &value).is_empty());
    }

    #[test]
    fn a_broken_schema_never_silently_passes() {
        let bad_schema = json!({"type": "not-a-real-type"});
        let violations = all_violations(&bad_schema, &json!({}));
        assert!(!violations.is_empty());
    }
}
