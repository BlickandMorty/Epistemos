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

impl FieldType {
    pub const ALL: [FieldType; 5] = [
        FieldType::Integer,
        FieldType::Float,
        FieldType::String,
        FieldType::Bool,
        FieldType::Null,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            FieldType::Integer => "integer",
            FieldType::Float => "float",
            FieldType::String => "string",
            FieldType::Bool => "bool",
            FieldType::Null => "null",
        }
    }

    /// Reverse lookup for [`Self::code`].
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|t| t.code() == code)
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

    /// Predicate: this is a single-type required schema (matches
    /// [`Self::strict`] output). Cross-surface invariant:
    /// `is_strict iff allowed_types.len() == 1 && required`.
    pub fn is_strict(&self) -> bool {
        self.allowed_types.len() == 1 && self.required
    }

    /// Predicate: this is a single-type non-required schema (matches
    /// [`Self::optional`] output).
    pub fn is_optional_singleton(&self) -> bool {
        self.allowed_types.len() == 1 && !self.required
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

    /// Number of fields in this schema.
    pub fn field_count(&self) -> usize {
        self.fields.len()
    }

    /// Predicate: zero fields. Cross-surface invariant: `is_empty()
    /// iff field_count() == 0`.
    pub fn is_empty(&self) -> bool {
        self.fields.is_empty()
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

impl ValidationError {
    /// Stable identifier for the failure kind.
    pub const fn kind(&self) -> &'static str {
        match self {
            ValidationError::MissingRequiredField { .. } => "missing_required_field",
            ValidationError::TypeMismatch { .. } => "type_mismatch",
            ValidationError::UnknownField { .. } => "unknown_field",
        }
    }

    /// Field name involved in the error. Every variant carries one,
    /// so this is total.
    pub fn field_name(&self) -> &str {
        match self {
            ValidationError::MissingRequiredField { name }
            | ValidationError::TypeMismatch { name, .. }
            | ValidationError::UnknownField { name, .. } => name,
        }
    }

    pub const fn is_missing_required(&self) -> bool {
        matches!(self, ValidationError::MissingRequiredField { .. })
    }

    pub const fn is_type_mismatch(&self) -> bool {
        matches!(self, ValidationError::TypeMismatch { .. })
    }

    /// Cross-surface invariant: exactly one of `is_missing_required /
    /// is_type_mismatch / is_unknown_field` is true per variant
    /// (3-way partition).
    pub const fn is_unknown_field(&self) -> bool {
        matches!(self, ValidationError::UnknownField { .. })
    }
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

impl RepairPolicy {
    pub const ALL: [RepairPolicy; 3] =
        [RepairPolicy::NoRepair, RepairPolicy::Conservative, RepairPolicy::Permissive];

    pub const fn code(self) -> &'static str {
        match self {
            RepairPolicy::NoRepair => "no_repair",
            RepairPolicy::Conservative => "conservative",
            RepairPolicy::Permissive => "permissive",
        }
    }

    /// Reverse lookup for [`Self::code`].
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|p| p.code() == code)
    }

    /// Predicate: this policy will mutate the schema during repair.
    /// Cross-surface invariant: `is_active() iff repair_schema produces
    /// a non-empty RepairReport given errors that match the policy`.
    pub const fn is_active(self) -> bool {
        matches!(self, RepairPolicy::Conservative | RepairPolicy::Permissive)
    }
}

impl RepairReport {
    /// Total change count across all three repair categories.
    pub fn total_changes(&self) -> usize {
        self.widened_types.len() + self.added_optional_fields.len() + self.downgraded_required.len()
    }

    /// Predicate: no changes applied. Cross-surface invariant:
    /// `is_empty() iff total_changes() == 0`.
    pub fn is_empty(&self) -> bool {
        self.widened_types.is_empty()
            && self.added_optional_fields.is_empty()
            && self.downgraded_required.is_empty()
    }
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

    // ── diagnostic surface (iter 183) ────────────────────────────────────────

    #[test]
    fn field_type_from_code_roundtrips_all() {
        for t in FieldType::ALL.iter().copied() {
            assert_eq!(FieldType::from_code(t.code()), Some(t));
        }
        assert_eq!(FieldType::from_code("Integer"), None);
    }

    #[test]
    fn validation_error_kind_distinct_and_classifier_partition() {
        let variants = [
            ValidationError::MissingRequiredField { name: "a".into() },
            ValidationError::TypeMismatch {
                name: "b".into(),
                expected: vec![FieldType::Integer],
                actual: FieldType::String,
            },
            ValidationError::UnknownField { name: "c".into(), actual: FieldType::Bool },
        ];
        let kinds: std::collections::HashSet<_> = variants.iter().map(|e| e.kind()).collect();
        assert_eq!(kinds.len(), 3);
        // Cross-surface invariant: 3-way classifier partition.
        for e in &variants {
            let trio = [e.is_missing_required(), e.is_type_mismatch(), e.is_unknown_field()];
            assert_eq!(trio.iter().filter(|t| **t).count(), 1, "{:?}", e);
        }
        // field_name extracts correctly.
        assert_eq!(variants[0].field_name(), "a");
        assert_eq!(variants[1].field_name(), "b");
        assert_eq!(variants[2].field_name(), "c");
    }

    #[test]
    fn repair_policy_from_code_roundtrips_all() {
        for p in RepairPolicy::ALL.iter().copied() {
            assert_eq!(RepairPolicy::from_code(p.code()), Some(p));
        }
    }

    #[test]
    fn repair_policy_is_active_only_for_repair_modes() {
        assert!(!RepairPolicy::NoRepair.is_active());
        assert!(RepairPolicy::Conservative.is_active());
        assert!(RepairPolicy::Permissive.is_active());
    }

    #[test]
    fn no_repair_yields_empty_report() {
        // Cross-surface invariant: NoRepair → empty report.
        let s = Schema::new().with("age", FieldSchema::strict(FieldType::Integer));
        let v = value(&[("age", Value::Float(1.5))]);
        let errs = validate_value(&s, &v);
        let (_, report) = repair_schema(&s, &errs, RepairPolicy::NoRepair).unwrap();
        assert!(report.is_empty());
        assert_eq!(report.total_changes(), 0);
    }

    #[test]
    fn report_is_empty_iff_total_changes_zero() {
        let empty = RepairReport {
            widened_types: vec![],
            added_optional_fields: vec![],
            downgraded_required: vec![],
        };
        assert!(empty.is_empty());
        assert_eq!(empty.total_changes(), 0);
        let with_change = RepairReport {
            widened_types: vec![("x".into(), FieldType::Float)],
            added_optional_fields: vec![],
            downgraded_required: vec![],
        };
        assert!(!with_change.is_empty());
        assert_eq!(with_change.total_changes(), 1);
    }

    #[test]
    fn report_total_changes_sums_three_categories() {
        let r = RepairReport {
            widened_types: vec![("a".into(), FieldType::Float)],
            added_optional_fields: vec![("b".into(), FieldType::String); 2],
            downgraded_required: vec!["c".into(), "d".into(), "e".into()],
        };
        assert_eq!(r.total_changes(), 1 + 2 + 3);
    }

    #[test]
    fn schema_field_count_and_is_empty_aligned() {
        let s = Schema::new();
        assert!(s.is_empty());
        assert_eq!(s.field_count(), 0);
        let s = s.with("a", FieldSchema::strict(FieldType::Integer))
            .with("b", FieldSchema::optional(FieldType::String));
        assert!(!s.is_empty());
        assert_eq!(s.field_count(), 2);
    }

    #[test]
    fn field_schema_is_strict_matches_constructor() {
        // Cross-surface invariant: strict() output satisfies is_strict.
        let s = FieldSchema::strict(FieldType::Integer);
        assert!(s.is_strict());
        assert!(!s.is_optional_singleton());

        let o = FieldSchema::optional(FieldType::Integer);
        assert!(!o.is_strict());
        assert!(o.is_optional_singleton());

        let widened = FieldSchema {
            allowed_types: vec![FieldType::Integer, FieldType::Float],
            required: true,
        };
        assert!(!widened.is_strict()); // more than one type
        assert!(!widened.is_optional_singleton());
    }

    #[test]
    fn real_conservative_repair_produces_active_report() {
        // Cross-surface: an active policy with applicable errors
        // yields a non-empty report.
        let s = Schema::new().with("age", FieldSchema::strict(FieldType::Integer));
        let v = value(&[("age", Value::Float(1.5)), ("nick", Value::String("a".into()))]);
        let errs = validate_value(&s, &v);
        let (_, report) = repair_schema(&s, &errs, RepairPolicy::Conservative).unwrap();
        assert!(!report.is_empty());
        assert_eq!(report.total_changes(), 2); // 1 widen + 1 added field
    }
}
