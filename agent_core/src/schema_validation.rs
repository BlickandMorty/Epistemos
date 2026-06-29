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

/// Build a concise REPAIR instruction for a model whose emitted JSON failed schema
/// validation (the §C.1 "validation gate → repair" step on the live `jsonschema` path):
/// it shows what the model produced, lists EVERY violation (from `all_violations`), and
/// asks for corrected JSON ONLY. Deterministic — violations are listed in order.
/// Returns `None` when there are no violations (nothing to repair).
pub fn build_repair_prompt(failed_value: &Value, violations: &[String]) -> Option<String> {
    if violations.is_empty() {
        return None;
    }
    let produced =
        serde_json::to_string_pretty(failed_value).unwrap_or_else(|_| failed_value.to_string());
    let listed = violations
        .iter()
        .enumerate()
        .map(|(i, v)| format!("  {}. {}", i + 1, v))
        .collect::<Vec<_>>()
        .join("\n");
    Some(format!(
        "Your JSON did not match the required schema. You produced:\n{produced}\n\n\
         These are ALL the problems to fix:\n{listed}\n\n\
         Reply with ONLY the corrected JSON that fixes every problem above — no prose, no markdown."
    ))
}

/// FFI: the §C.1 validate→repair gate, in ONE call. Swift passes the tool's JSON schema
/// + the local model's emitted value (both as JSON strings); gets back EITHER an empty
/// string (the value is VALID — proceed to execute) OR a repair prompt listing every
/// violation (re-prompt the model with it). PURE — it does NOT touch the live loop; the
/// Swift local agent loop calls it after a local tool-call and decides execute-vs-repair.
/// Honest: an unparseable schema/value is reported (never silently "valid").
#[uniffi::export]
pub fn schema_validate_and_repair_json(schema_json: String, value_json: String) -> String {
    let schema: Value = match serde_json::from_str(&schema_json) {
        Ok(v) => v,
        Err(e) => return format!("schema is not valid JSON: {e}"),
    };
    let value: Value = match serde_json::from_str(&value_json) {
        Ok(v) => v,
        Err(e) => {
            let raw = Value::String(value_json);
            return build_repair_prompt(&raw, &[format!("your output was not valid JSON: {e}")])
                .unwrap_or_default();
        }
    };
    let violations = all_violations(&schema, &value);
    // Empty when valid (build_repair_prompt returns None → ""); the repair prompt when not.
    build_repair_prompt(&value, &violations).unwrap_or_default()
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
        assert!(
            violations.len() >= 2,
            "expected all violations, got {violations:?}"
        );
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

    #[test]
    fn repair_prompt_lists_all_violations_shows_the_value_and_asks_for_json() {
        let failed = json!({"name": 123});
        let violations = vec![
            "at /name: 123 is not of type \"string\"".to_string(),
            "at /: \"count\" is a required property".to_string(),
        ];
        let prompt = build_repair_prompt(&failed, &violations).expect("a repair prompt");
        assert!(prompt.contains("123 is not of type")); // violation 1 listed
        assert!(prompt.contains("required property")); // violation 2 listed
        assert!(prompt.contains("\"name\"")); // the failed value is shown
        assert!(prompt.contains("corrected JSON")); // asks for the fix
        assert!(prompt.contains("no prose")); // structured-output discipline
    }

    #[test]
    fn no_violations_means_no_repair_prompt() {
        assert!(build_repair_prompt(&json!({"ok": true}), &[]).is_none());
    }

    #[test]
    fn validate_then_repair_round_trips() {
        // The §C.1 flow: a value that violates → all_violations → a repair prompt.
        let value = json!({"name": 5});
        let violations = all_violations(&schema(), &value);
        assert!(!violations.is_empty());
        let prompt = build_repair_prompt(&value, &violations).expect("a repair prompt");
        assert!(prompt.contains("corrected JSON"));
    }

    #[test]
    fn ffi_valid_value_returns_empty() {
        let s = schema().to_string();
        assert_eq!(
            schema_validate_and_repair_json(s, json!({"name": "x", "count": 1}).to_string()),
            ""
        );
    }

    #[test]
    fn ffi_invalid_value_returns_a_repair_prompt() {
        let s = schema().to_string();
        let out = schema_validate_and_repair_json(s, json!({"name": 5}).to_string());
        assert!(!out.is_empty());
        assert!(out.contains("corrected JSON"));
    }

    #[test]
    fn ffi_unparseable_value_is_repaired_not_silently_valid() {
        let out = schema_validate_and_repair_json(
            json!({"type": "object"}).to_string(),
            "not json".to_string(),
        );
        assert!(out.contains("not valid JSON"));
        assert!(out.contains("corrected JSON"));
    }

    #[test]
    fn ffi_unparseable_schema_is_reported_honestly() {
        let out = schema_validate_and_repair_json("not json".to_string(), json!({}).to_string());
        assert!(out.contains("schema is not valid JSON"));
    }
}
