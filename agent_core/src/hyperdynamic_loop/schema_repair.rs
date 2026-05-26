//! `SchemaRepairLoop` — consumes the research-tier
//! [`crate::research::hyperdynamic_schemas`] primitives to gate model
//! tool-call drafts against a `Schema`. Produces an operator-visible
//! repair hint listing the missing / mismatched / unknown fields the
//! next attempt must fix.

use std::collections::BTreeMap;

use crate::research::hyperdynamic_schemas::repair::{
    repair_schema, validate_value, FieldType, RepairPolicy, RepairReport, Schema, ValidationError,
    Value,
};

use super::{HyperdynamicLoop, RepairVerdict};

/// One candidate-value draft + the schema the loop validates against.
/// Cloned per iteration; cheap for small flat values.
#[derive(Debug, Clone, PartialEq)]
pub struct SchemaDraft {
    pub value: BTreeMap<String, Value>,
}

impl SchemaDraft {
    #[must_use]
    pub fn new(value: BTreeMap<String, Value>) -> Self {
        Self { value }
    }

    #[must_use]
    pub fn empty() -> Self {
        Self {
            value: BTreeMap::new(),
        }
    }
}

/// Per-call-site loop that classifies a [`SchemaDraft`] against a
/// fixed `Schema` + `RepairPolicy`. The loop **never mutates** the
/// schema — repair happens in the runner via the hint + re_emit
/// closure. We only call `repair_schema` to compute the diagnostic
/// surface that drives the hint text (so e.g. the model knows whether
/// a field would have been widened vs added vs downgraded).
#[derive(Debug, Clone)]
pub struct SchemaRepairLoop {
    schema: Schema,
    policy: RepairPolicy,
}

impl SchemaRepairLoop {
    /// Strict-default constructor — Conservative repair, so the hint
    /// never asks the model to violate the typed contract by dropping
    /// required fields.
    #[must_use]
    pub fn new(schema: Schema) -> Self {
        Self {
            schema,
            policy: RepairPolicy::Conservative,
        }
    }

    #[must_use]
    pub fn with_policy(schema: Schema, policy: RepairPolicy) -> Self {
        Self { schema, policy }
    }

    #[must_use]
    pub fn schema(&self) -> &Schema {
        &self.schema
    }

    #[must_use]
    pub fn policy(&self) -> RepairPolicy {
        self.policy
    }

    fn hint(&self, errors: &[ValidationError], report: &RepairReport) -> String {
        let mut lines: Vec<String> = Vec::with_capacity(errors.len() + 1);
        lines.push(format!(
            "schema_repair: {} field error(s) — see field list below",
            errors.len()
        ));
        for err in errors {
            match err {
                ValidationError::MissingRequiredField { name } => {
                    lines.push(format!("  · missing required field `{name}`"));
                }
                ValidationError::TypeMismatch {
                    name,
                    expected,
                    actual,
                } => {
                    let expected = expected
                        .iter()
                        .copied()
                        .map(FieldType::code)
                        .collect::<Vec<_>>()
                        .join("|");
                    lines.push(format!(
                        "  · field `{name}` got `{}`, expected `{expected}`",
                        actual.code()
                    ));
                }
                ValidationError::UnknownField { name, actual } => {
                    lines.push(format!(
                        "  · unknown field `{name}` (type `{}`)",
                        actual.code()
                    ));
                }
            }
        }
        if !report.is_empty() {
            lines.push(format!(
                "  · repair report: {} widened · {} added-optional · {} downgraded-required",
                report.widened_types.len(),
                report.added_optional_fields.len(),
                report.downgraded_required.len(),
            ));
        }
        lines.join("\n")
    }
}

impl HyperdynamicLoop for SchemaRepairLoop {
    type Packet = SchemaDraft;
    type Error = std::convert::Infallible;

    fn kind(&self) -> &'static str {
        "schema_repair"
    }

    fn check(&self, draft: &Self::Packet) -> Result<RepairVerdict<Self::Packet>, Self::Error> {
        let errors = validate_value(&self.schema, &draft.value);
        if errors.is_empty() {
            return Ok(RepairVerdict::Accept(draft.clone()));
        }
        if self.policy == RepairPolicy::NoRepair {
            return Ok(RepairVerdict::Quarantine {
                reason: format!(
                    "schema_repair_disabled: {} unresolved validation error(s)",
                    errors.len()
                ),
            });
        }
        // `repair_schema` returns an Err only when `errors.is_empty()`,
        // which we've already excluded.
        let (_, report) = repair_schema(&self.schema, &errors, self.policy)
            .expect("repair_schema only errors on empty error list");
        Ok(RepairVerdict::RepairWith {
            hint: self.hint(&errors, &report),
            tightened: draft.clone(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::hyperdynamic_loop::{run_loop, LoopCounters, RepairBudget, RepairOutcome};
    use crate::research::hyperdynamic_schemas::repair::FieldSchema;

    fn user_schema() -> Schema {
        Schema::new()
            .with("name", FieldSchema::strict(FieldType::String))
            .with("age", FieldSchema::strict(FieldType::Integer))
    }

    fn draft(pairs: &[(&str, Value)]) -> SchemaDraft {
        SchemaDraft::new(
            pairs
                .iter()
                .map(|(k, v)| ((*k).to_string(), v.clone()))
                .collect(),
        )
    }

    #[test]
    fn loop_kind_is_schema_repair() {
        let l = SchemaRepairLoop::new(user_schema());
        assert_eq!(l.kind(), "schema_repair");
    }

    #[test]
    fn valid_draft_accepts_immediately() {
        let l = SchemaRepairLoop::new(user_schema());
        let d = draft(&[
            ("name", Value::String("Alice".into())),
            ("age", Value::Integer(30)),
        ]);
        let mut c = LoopCounters::new();
        let outcome =
            run_loop(&l, d.clone(), RepairBudget::DEFAULT, &mut c, |p, _| p.clone()).unwrap();
        assert!(matches!(outcome, RepairOutcome::Accepted { repairs: 0, .. }));
        assert_eq!(c.accepted, 1);
    }

    #[test]
    fn type_mismatch_produces_repair_hint_with_field_list() {
        let l = SchemaRepairLoop::new(user_schema());
        let d = draft(&[
            ("name", Value::String("Alice".into())),
            ("age", Value::String("thirty".into())),
        ]);
        let v = l.check(&d).unwrap();
        match v {
            RepairVerdict::RepairWith { hint, .. } => {
                assert!(hint.contains("schema_repair:"), "hint: {hint}");
                assert!(hint.contains("`age`"), "hint: {hint}");
                assert!(hint.contains("expected `integer`"), "hint: {hint}");
            }
            other => panic!("expected RepairWith, got {other:?}"),
        }
    }

    #[test]
    fn missing_required_field_repair_hint_names_field() {
        let l = SchemaRepairLoop::new(user_schema());
        let d = draft(&[("name", Value::String("Alice".into()))]);
        let v = l.check(&d).unwrap();
        match v {
            RepairVerdict::RepairWith { hint, .. } => {
                assert!(hint.contains("missing required field `age`"), "hint: {hint}");
            }
            other => panic!("expected RepairWith, got {other:?}"),
        }
    }

    #[test]
    fn no_repair_policy_quarantines_invalid_draft() {
        let l = SchemaRepairLoop::with_policy(user_schema(), RepairPolicy::NoRepair);
        let d = draft(&[("name", Value::String("Alice".into()))]);
        let v = l.check(&d).unwrap();
        assert!(matches!(v, RepairVerdict::Quarantine { .. }));
    }

    #[test]
    fn repair_loop_accepts_after_model_fixes_field() {
        // Drive a full loop: model first emits a draft missing `age`,
        // then on repair hint the closure fills it in.
        let l = SchemaRepairLoop::new(user_schema());
        let initial = draft(&[("name", Value::String("Alice".into()))]);
        let mut c = LoopCounters::new();
        let outcome = run_loop(
            &l,
            initial,
            RepairBudget::DEFAULT,
            &mut c,
            |prev, _hint| {
                // Simulated re-emit: add the missing age.
                let mut next = prev.clone();
                next.value
                    .insert("age".to_string(), Value::Integer(42));
                next
            },
        )
        .unwrap();
        match outcome {
            RepairOutcome::Accepted { packet, repairs } => {
                assert_eq!(repairs, 1);
                assert_eq!(packet.value["name"], Value::String("Alice".into()));
                assert_eq!(packet.value["age"], Value::Integer(42));
            }
            other => panic!("expected accepted, got {other:?}"),
        }
        assert_eq!(c.accepted, 1);
        assert_eq!(c.repaired, 1);
        assert_eq!(c.total_repair_attempts, 1);
    }

    #[test]
    fn budget_exhaustion_quarantines_persistent_drift() {
        let l = SchemaRepairLoop::new(user_schema());
        let initial = draft(&[]);
        let mut c = LoopCounters::new();
        // Re-emit closure that never fixes anything → must hit retry cap.
        let outcome = run_loop(
            &l,
            initial,
            RepairBudget::tightened(2, std::time::Duration::from_millis(500), 64),
            &mut c,
            |prev, _hint| prev.clone(),
        )
        .unwrap();
        match outcome {
            RepairOutcome::QuarantinedBudgetExhausted { repairs, .. } => {
                assert_eq!(repairs, 2);
            }
            other => panic!("expected budget exhaustion, got {other:?}"),
        }
        assert_eq!(c.quarantined, 1);
    }
}
