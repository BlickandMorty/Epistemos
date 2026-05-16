//! Source: see `super::` rustdoc for citation context. This module owns
//! the schema + value types + validation + repair logic.

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// Type tags supported by the substrate floor. Real schemas need
/// arrays / nested objects / regex constraints / enum literals; those
/// are deferred to future J6 iters.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum FieldType {
    Integer,
    Float,
    String,
    Bool,
    Null,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum Value {
    Integer(i64),
    Float(f64),
    String(String),
    Bool(bool),
    Null,
}

impl Value {
    pub fn field_type(&self) -> FieldType {
        match self {
            Value::Integer(_) => FieldType::Integer,
            Value::Float(_) => FieldType::Float,
            Value::String(_) => FieldType::String,
            Value::Bool(_) => FieldType::Bool,
            Value::Null => FieldType::Null,
        }
    }
}

/// One field constraint. `allowed_types` is the type-union (set of
/// types this field can accept); singleton = strict, multi-element =
/// widened. `required = true` means the input MUST carry the field.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct FieldSchema {
    pub allowed_types: Vec<FieldType>,
    pub required: bool,
}

impl FieldSchema {
    pub fn strict(t: FieldType) -> Self {
        Self { allowed_types: vec![t], required: true }
    }

    pub fn optional(t: FieldType) -> Self {
        Self { allowed_types: vec![t], required: false }
    }

    fn accepts(&self, t: FieldType) -> bool {
        self.allowed_types.iter().any(|&a| a == t)
    }
}

#[derive(Clone, Debug, PartialEq, Default, Serialize, Deserialize)]
pub struct Schema {
    pub fields: BTreeMap<String, FieldSchema>,
}

impl Schema {
    pub fn new() -> Self {
        Self { fields: BTreeMap::new() }
    }

    pub fn with(mut self, name: &str, schema: FieldSchema) -> Self {
        self.fields.insert(name.to_string(), schema);
        self
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum ValidationError {
    /// `name` was required by the schema but absent from the value.
    MissingRequiredField { name: String },
    /// `name` had a type not in the schema's `allowed_types`.
    TypeMismatch {
        name: String,
        expected: Vec<FieldType>,
        actual: FieldType,
    },
    /// `name` appeared in the value but not in the schema (strict mode).
    UnknownField { name: String, actual: FieldType },
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub enum RepairPolicy {
    /// No repair; validation errors are surfaced verbatim.
    NoRepair,
    /// Widen type unions on TypeMismatch + add optional fields on
    /// UnknownField. Never drops fields, never narrows.
    Conservative,
    /// Like Conservative but ALSO downgrades MissingRequiredField from
    /// required → optional. Most-permissive substrate-floor repair.
    Permissive,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum SchemaError {
    /// Repair was requested but `errors` was empty — caller bug.
    NoErrorsToRepair,
}

/// Validate a value (as a flat `BTreeMap<String, Value>`) against the
/// schema. Returns all errors found (does not stop at the first).
pub fn validate_value(
    schema: &Schema,
    value: &BTreeMap<String, Value>,
) -> Vec<ValidationError> {
    let mut errors = Vec::new();
    for (name, fs) in &schema.fields {
        match value.get(name) {
            None => {
                if fs.required {
                    errors.push(ValidationError::MissingRequiredField {
                        name: name.clone(),
                    });
                }
            }
            Some(v) => {
                let t = v.field_type();
                if !fs.accepts(t) {
                    errors.push(ValidationError::TypeMismatch {
                        name: name.clone(),
                        expected: fs.allowed_types.clone(),
                        actual: t,
                    });
                }
            }
        }
    }
    for (name, v) in value {
        if !schema.fields.contains_key(name) {
            errors.push(ValidationError::UnknownField {
                name: name.clone(),
                actual: v.field_type(),
            });
        }
    }
    errors
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct RepairReport {
    pub widened_types: Vec<(String, FieldType)>,
    pub added_optional_fields: Vec<(String, FieldType)>,
    pub downgraded_required: Vec<String>,
}

/// Apply a repair policy. Returns the new schema + a report of what
/// changed. Conservative is monotone: any previously-valid value
/// stays valid under the repaired schema.
pub fn repair_schema(
    schema: &Schema,
    errors: &[ValidationError],
    policy: RepairPolicy,
) -> Result<(Schema, RepairReport), SchemaError> {
    if errors.is_empty() {
        return Err(SchemaError::NoErrorsToRepair);
    }
    if policy == RepairPolicy::NoRepair {
        return Ok((schema.clone(), RepairReport {
            widened_types: vec![],
            added_optional_fields: vec![],
            downgraded_required: vec![],
        }));
    }
    let mut new_schema = schema.clone();
    let mut report = RepairReport {
        widened_types: vec![],
        added_optional_fields: vec![],
        downgraded_required: vec![],
    };
    for err in errors {
        match err {
            ValidationError::TypeMismatch { name, actual, .. } => {
                if let Some(fs) = new_schema.fields.get_mut(name) {
                    if !fs.allowed_types.contains(actual) {
                        fs.allowed_types.push(*actual);
                        fs.allowed_types.sort();
                        report.widened_types.push((name.clone(), *actual));
                    }
                }
            }
            ValidationError::UnknownField { name, actual } => {
                if !new_schema.fields.contains_key(name) {
                    new_schema.fields.insert(
                        name.clone(),
                        FieldSchema::optional(*actual),
                    );
                    report.added_optional_fields.push((name.clone(), *actual));
                }
            }
            ValidationError::MissingRequiredField { name } => {
                if policy == RepairPolicy::Permissive {
                    if let Some(fs) = new_schema.fields.get_mut(name) {
                        if fs.required {
                            fs.required = false;
                            report.downgraded_required.push(name.clone());
                        }
                    }
                }
            }
        }
    }
    Ok((new_schema, report))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn value(pairs: &[(&str, Value)]) -> BTreeMap<String, Value> {
        pairs.iter().map(|(k, v)| ((*k).to_string(), v.clone())).collect()
    }

    #[test]
    fn empty_schema_accepts_empty_value() {
        let s = Schema::new();
        let v = value(&[]);
        assert!(validate_value(&s, &v).is_empty());
    }

    #[test]
    fn strict_schema_validates_matching_value() {
        let s = Schema::new().with("age", FieldSchema::strict(FieldType::Integer));
        let v = value(&[("age", Value::Integer(42))]);
        assert!(validate_value(&s, &v).is_empty());
    }

    #[test]
    fn strict_schema_rejects_type_mismatch() {
        let s = Schema::new().with("age", FieldSchema::strict(FieldType::Integer));
        let v = value(&[("age", Value::Float(42.5))]);
        let errs = validate_value(&s, &v);
        assert_eq!(errs.len(), 1);
        match &errs[0] {
            ValidationError::TypeMismatch { name, expected, actual } => {
                assert_eq!(name, "age");
                assert_eq!(expected, &vec![FieldType::Integer]);
                assert_eq!(*actual, FieldType::Float);
            }
            other => panic!("expected TypeMismatch, got {:?}", other),
        }
    }

    #[test]
    fn missing_required_field_errors() {
        let s = Schema::new().with("name", FieldSchema::strict(FieldType::String));
        let v = value(&[]);
        let errs = validate_value(&s, &v);
        assert_eq!(
            errs,
            vec![ValidationError::MissingRequiredField { name: "name".to_string() }]
        );
    }

    #[test]
    fn missing_optional_field_does_not_error() {
        let s = Schema::new().with("nickname", FieldSchema::optional(FieldType::String));
        let v = value(&[]);
        assert!(validate_value(&s, &v).is_empty());
    }

    #[test]
    fn unknown_field_errors() {
        let s = Schema::new().with("age", FieldSchema::strict(FieldType::Integer));
        let v = value(&[("age", Value::Integer(1)), ("foo", Value::Bool(true))]);
        let errs = validate_value(&s, &v);
        assert!(errs.contains(&ValidationError::UnknownField {
            name: "foo".to_string(),
            actual: FieldType::Bool
        }));
    }

    #[test]
    fn conservative_repair_widens_type_union() {
        let s = Schema::new().with("age", FieldSchema::strict(FieldType::Integer));
        let v = value(&[("age", Value::Float(42.5))]);
        let errs = validate_value(&s, &v);
        let (s2, report) = repair_schema(&s, &errs, RepairPolicy::Conservative).unwrap();
        assert!(validate_value(&s2, &v).is_empty());
        assert_eq!(report.widened_types, vec![("age".to_string(), FieldType::Float)]);
    }

    #[test]
    fn widened_schema_still_accepts_original_type() {
        let s = Schema::new().with("age", FieldSchema::strict(FieldType::Integer));
        let v_new = value(&[("age", Value::Float(1.5))]);
        let errs = validate_value(&s, &v_new);
        let (s2, _) = repair_schema(&s, &errs, RepairPolicy::Conservative).unwrap();
        let v_old = value(&[("age", Value::Integer(42))]);
        assert!(validate_value(&s2, &v_old).is_empty());
    }

    #[test]
    fn conservative_repair_adds_optional_field() {
        let s = Schema::new().with("age", FieldSchema::strict(FieldType::Integer));
        let v = value(&[("age", Value::Integer(1)), ("nickname", Value::String("ace".into()))]);
        let errs = validate_value(&s, &v);
        let (s2, report) = repair_schema(&s, &errs, RepairPolicy::Conservative).unwrap();
        assert!(validate_value(&s2, &v).is_empty());
        assert_eq!(
            report.added_optional_fields,
            vec![("nickname".to_string(), FieldType::String)]
        );
        let fs = &s2.fields["nickname"];
        assert!(!fs.required);
    }

    #[test]
    fn conservative_does_not_downgrade_required() {
        let s = Schema::new().with("name", FieldSchema::strict(FieldType::String));
        let v = value(&[]);
        let errs = validate_value(&s, &v);
        let (s2, report) = repair_schema(&s, &errs, RepairPolicy::Conservative).unwrap();
        assert!(report.downgraded_required.is_empty());
        assert!(s2.fields["name"].required);
    }

    #[test]
    fn permissive_downgrades_required() {
        let s = Schema::new().with("name", FieldSchema::strict(FieldType::String));
        let v = value(&[]);
        let errs = validate_value(&s, &v);
        let (s2, report) = repair_schema(&s, &errs, RepairPolicy::Permissive).unwrap();
        assert_eq!(report.downgraded_required, vec!["name".to_string()]);
        assert!(!s2.fields["name"].required);
    }

    #[test]
    fn no_repair_policy_leaves_schema_unchanged() {
        let s = Schema::new().with("age", FieldSchema::strict(FieldType::Integer));
        let v = value(&[("age", Value::Float(1.5))]);
        let errs = validate_value(&s, &v);
        let (s2, report) = repair_schema(&s, &errs, RepairPolicy::NoRepair).unwrap();
        assert_eq!(s2, s);
        assert!(report.widened_types.is_empty());
    }

    #[test]
    fn no_errors_repair_request_errors() {
        let s = Schema::new();
        let err = repair_schema(&s, &[], RepairPolicy::Conservative).unwrap_err();
        assert_eq!(err, SchemaError::NoErrorsToRepair);
    }

    #[test]
    fn multi_error_batch_repair_addresses_all() {
        let s = Schema::new()
            .with("age", FieldSchema::strict(FieldType::Integer))
            .with("name", FieldSchema::strict(FieldType::String));
        let v = value(&[
            ("age", Value::Float(1.5)),
            ("name", Value::String("a".into())),
            ("extra", Value::Bool(true)),
        ]);
        let errs = validate_value(&s, &v);
        let (s2, report) = repair_schema(&s, &errs, RepairPolicy::Conservative).unwrap();
        assert!(validate_value(&s2, &v).is_empty());
        assert!(!report.widened_types.is_empty());
        assert!(!report.added_optional_fields.is_empty());
    }

    #[test]
    fn schema_roundtrips_through_serde_json() {
        let s = Schema::new()
            .with("age", FieldSchema::strict(FieldType::Integer))
            .with("nick", FieldSchema::optional(FieldType::String));
        let json = serde_json::to_string(&s).unwrap();
        let back: Schema = serde_json::from_str(&json).unwrap();
        assert_eq!(s, back);
    }
}
