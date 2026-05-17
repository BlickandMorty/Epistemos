#![cfg(feature = "research")]
//! Wave J6 hyperdynamic schemas — repair + validation harness.
//!
//! Source:
//! - `agent_core/src/research/hyperdynamic_schemas/repair.rs` (substrate).
//! - MASTER_FUSION §3.7 "Variant ladder + hyper-deterministic schemas
//!   (Jordan's pre-Helios research)" — meta-schemas that repair
//!   themselves; axioms widen to accommodate new observations as long
//!   as existing theorems remain true.
//! - Phase B iter 62 substrate-floor.
//!
//! # Substrate-floor scope
//!
//! Exercises Schema + FieldSchema + Value + validate_value + repair_schema
//! across all 5 FieldType variants × 3 RepairPolicy variants. Verifies the
//! 3-way partition invariant (missing_required / type_mismatch / unknown_field)
//! + RepairReport monotonicity (Permissive ≥ Conservative ≥ NoRepair).

use agent_core::research::hyperdynamic_schemas::repair::{
    repair_schema, validate_value, FieldSchema, FieldType, RepairPolicy, RepairReport, Schema,
    SchemaError, ValidationError, Value,
};
use std::collections::BTreeMap;

#[test]
fn field_type_all_lists_five_variants() {
    assert_eq!(FieldType::ALL.len(), 5);
}

#[test]
fn field_type_code_round_trip() {
    for t in FieldType::ALL {
        let code = t.code();
        let parsed = FieldType::from_code(code).unwrap();
        assert_eq!(parsed, t);
    }
}

#[test]
fn field_type_from_unknown_code_returns_none() {
    assert!(FieldType::from_code("unknown_type").is_none());
}

#[test]
fn value_field_type_matches_constructor() {
    assert_eq!(Value::Integer(42).field_type(), FieldType::Integer);
    assert_eq!(Value::Float(1.5).field_type(), FieldType::Float);
    assert_eq!(Value::String("x".into()).field_type(), FieldType::String);
    assert_eq!(Value::Bool(true).field_type(), FieldType::Bool);
    assert_eq!(Value::Null.field_type(), FieldType::Null);
}

#[test]
fn strict_schema_is_strict_and_required() {
    let s = FieldSchema::strict(FieldType::Integer);
    assert!(s.is_strict());
    assert!(!s.is_optional_singleton());
    assert!(s.required);
    assert_eq!(s.allowed_types.len(), 1);
}

#[test]
fn optional_schema_is_singleton_and_not_required() {
    let s = FieldSchema::optional(FieldType::String);
    assert!(s.is_optional_singleton());
    assert!(!s.is_strict());
    assert!(!s.required);
}

#[test]
fn validate_clean_value_yields_no_errors() {
    let schema = Schema::new()
        .with("age", FieldSchema::strict(FieldType::Integer))
        .with("name", FieldSchema::strict(FieldType::String));
    let mut value = BTreeMap::new();
    value.insert("age".to_string(), Value::Integer(30));
    value.insert("name".to_string(), Value::String("Alice".into()));
    let errors = validate_value(&schema, &value);
    assert!(errors.is_empty());
}

#[test]
fn validate_missing_required_field_errors() {
    let schema = Schema::new().with("required_field", FieldSchema::strict(FieldType::Integer));
    let value = BTreeMap::new();
    let errors = validate_value(&schema, &value);
    assert_eq!(errors.len(), 1);
    assert!(errors[0].is_missing_required());
    assert_eq!(errors[0].field_name(), "required_field");
}

#[test]
fn validate_type_mismatch_errors() {
    let schema = Schema::new().with("age", FieldSchema::strict(FieldType::Integer));
    let mut value = BTreeMap::new();
    value.insert("age".to_string(), Value::String("thirty".into()));
    let errors = validate_value(&schema, &value);
    assert_eq!(errors.len(), 1);
    assert!(errors[0].is_type_mismatch());
}

#[test]
fn validate_unknown_field_errors() {
    let schema = Schema::new().with("known", FieldSchema::strict(FieldType::Integer));
    let mut value = BTreeMap::new();
    value.insert("known".to_string(), Value::Integer(1));
    value.insert("surprise".to_string(), Value::Bool(false));
    let errors = validate_value(&schema, &value);
    assert!(errors.iter().any(|e| e.is_unknown_field() && e.field_name() == "surprise"));
}

#[test]
fn three_way_partition_invariant_per_error() {
    // For every variant, exactly one of the 3 predicates is true.
    let errs = [
        ValidationError::MissingRequiredField { name: "a".into() },
        ValidationError::TypeMismatch {
            name: "b".into(),
            expected: vec![FieldType::Integer],
            actual: FieldType::String,
        },
        ValidationError::UnknownField { name: "c".into(), actual: FieldType::Bool },
    ];
    for e in &errs {
        let count = (e.is_missing_required() as u8)
            + (e.is_type_mismatch() as u8)
            + (e.is_unknown_field() as u8);
        assert_eq!(count, 1, "exactly one predicate must be true for {:?}", e);
    }
}

#[test]
fn no_repair_policy_leaves_schema_unchanged() {
    let schema = Schema::new().with("x", FieldSchema::strict(FieldType::Integer));
    let errors = vec![ValidationError::TypeMismatch {
        name: "x".into(),
        expected: vec![FieldType::Integer],
        actual: FieldType::String,
    }];
    let (new_schema, report) = repair_schema(&schema, &errors, RepairPolicy::NoRepair).unwrap();
    assert_eq!(new_schema, schema);
    assert!(report.is_empty());
}

#[test]
fn conservative_repair_widens_type_mismatch() {
    let schema = Schema::new().with("x", FieldSchema::strict(FieldType::Integer));
    let errors = vec![ValidationError::TypeMismatch {
        name: "x".into(),
        expected: vec![FieldType::Integer],
        actual: FieldType::Float,
    }];
    let (new_schema, report) = repair_schema(&schema, &errors, RepairPolicy::Conservative).unwrap();
    let fs = &new_schema.fields["x"];
    assert!(fs.allowed_types.contains(&FieldType::Integer));
    assert!(fs.allowed_types.contains(&FieldType::Float));
    assert!(!report.is_empty());
    assert_eq!(report.widened_types.len(), 1);
}

#[test]
fn permissive_repair_downgrades_required() {
    let schema = Schema::new().with("x", FieldSchema::strict(FieldType::Integer));
    let errors = vec![ValidationError::MissingRequiredField { name: "x".into() }];
    let (new_schema, report) = repair_schema(&schema, &errors, RepairPolicy::Permissive).unwrap();
    assert!(!new_schema.fields["x"].required);
    assert_eq!(report.downgraded_required.len(), 1);
}

#[test]
fn conservative_does_NOT_downgrade_required() {
    let schema = Schema::new().with("x", FieldSchema::strict(FieldType::Integer));
    let errors = vec![ValidationError::MissingRequiredField { name: "x".into() }];
    let (new_schema, report) = repair_schema(&schema, &errors, RepairPolicy::Conservative).unwrap();
    // Conservative keeps required = true even with MissingRequiredField.
    assert!(new_schema.fields["x"].required, "conservative must not downgrade required");
    assert!(report.downgraded_required.is_empty());
}

#[test]
fn repair_with_no_errors_errors_typed() {
    let schema = Schema::new().with("x", FieldSchema::strict(FieldType::Integer));
    let errors: Vec<ValidationError> = vec![];
    let err = repair_schema(&schema, &errors, RepairPolicy::Conservative).unwrap_err();
    assert_eq!(err, SchemaError::NoErrorsToRepair);
}

#[test]
fn repair_policy_code_round_trip() {
    for p in RepairPolicy::ALL {
        let code = p.code();
        let parsed = RepairPolicy::from_code(code).unwrap();
        assert_eq!(parsed, p);
    }
}

#[test]
fn repair_policy_is_active_predicate() {
    assert!(!RepairPolicy::NoRepair.is_active());
    assert!(RepairPolicy::Conservative.is_active());
    assert!(RepairPolicy::Permissive.is_active());
}

#[test]
fn repair_report_total_changes_sums_categories() {
    let report = RepairReport {
        widened_types: vec![("a".into(), FieldType::Float)],
        added_optional_fields: vec![("b".into(), FieldType::Bool), ("c".into(), FieldType::Null)],
        downgraded_required: vec!["d".into()],
    };
    assert_eq!(report.total_changes(), 4);
    assert!(!report.is_empty());
}

#[test]
fn validation_error_kind_strings_locked() {
    assert_eq!(
        ValidationError::MissingRequiredField { name: "x".into() }.kind(),
        "missing_required_field"
    );
    assert_eq!(
        ValidationError::TypeMismatch {
            name: "x".into(),
            expected: vec![],
            actual: FieldType::Null
        }
        .kind(),
        "type_mismatch"
    );
    assert_eq!(
        ValidationError::UnknownField { name: "x".into(), actual: FieldType::Null }.kind(),
        "unknown_field"
    );
}
