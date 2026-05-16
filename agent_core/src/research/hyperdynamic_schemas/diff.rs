//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.1 J6 row — Hyper-Dynamic Schemas. Repair is the
//!   forward operation; diff is its inverse — given two schemas
//!   produced by repair (or by hand), enumerate the deltas.
//! - Conceptual antecedent: Bonifati et al., "Schema Evolution in
//!   Document Databases", VLDB 2024 — schema-drift detection.
//! - Companion to [`super::repair`] (repair widens; diff catalogs
//!   the widenings).
//!
//! # Wave J6 — Schema diff (companion to repair)
//!
//! `repair_schema` walks a failing validation and proposes a widened
//! schema. `diff_schemas` walks two schemas and emits the list of
//! structural changes — useful for telemetry, audit logs, and CI
//! gates that fail-build on backward-incompatible deltas.
//!
//! ## Change taxonomy
//!
//! - **FieldAdded** — new field appears in `to` that was not in `from`.
//!   Backward-compatible iff the new field is `optional`.
//! - **FieldRemoved** — field present in `from` is gone in `to`.
//!   Backward-incompatible iff the removed field was `required`.
//! - **TypeWidened** — `allowed_types` in `to` is a strict superset
//!   of `from`. Always backward-compatible.
//! - **TypeNarrowed** — `allowed_types` in `to` is a strict subset
//!   of `from`. Always backward-incompatible (input the old schema
//!   accepted may now fail).
//! - **RequiredFlipped** — `required` flag changed direction.
//!   Optional→required is breaking; required→optional is safe.
//!
//! `is_breaking_change()` returns true iff the change would reject
//! input the old schema accepted.

use super::repair::{FieldSchema, FieldType, Schema};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum SchemaChange {
    FieldAdded { name: String, schema: FieldSchema },
    FieldRemoved { name: String, schema: FieldSchema },
    TypeWidened { name: String, added: Vec<FieldType> },
    TypeNarrowed { name: String, removed: Vec<FieldType> },
    RequiredFlipped { name: String, was_required: bool, now_required: bool },
}

impl SchemaChange {
    pub fn is_breaking(&self) -> bool {
        match self {
            SchemaChange::FieldAdded { schema, .. } => schema.required,
            SchemaChange::FieldRemoved { schema, .. } => schema.required,
            SchemaChange::TypeWidened { .. } => false,
            SchemaChange::TypeNarrowed { .. } => true,
            SchemaChange::RequiredFlipped {
                was_required,
                now_required,
                ..
            } => !*was_required && *now_required,
        }
    }

    pub fn field_name(&self) -> &str {
        match self {
            SchemaChange::FieldAdded { name, .. }
            | SchemaChange::FieldRemoved { name, .. }
            | SchemaChange::TypeWidened { name, .. }
            | SchemaChange::TypeNarrowed { name, .. }
            | SchemaChange::RequiredFlipped { name, .. } => name,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SchemaDiff {
    pub changes: Vec<SchemaChange>,
}

impl SchemaDiff {
    pub fn is_empty(&self) -> bool {
        self.changes.is_empty()
    }

    pub fn is_breaking(&self) -> bool {
        self.changes.iter().any(SchemaChange::is_breaking)
    }

    pub fn breaking_changes(&self) -> Vec<&SchemaChange> {
        self.changes.iter().filter(|c| c.is_breaking()).collect()
    }
}

/// Walk two schemas and emit the list of structural changes from
/// `from` → `to`. Output is sorted by field name (deterministic).
pub fn diff_schemas(from: &Schema, to: &Schema) -> SchemaDiff {
    let mut changes = Vec::new();
    let mut all_names: Vec<&String> =
        from.fields.keys().chain(to.fields.keys()).collect();
    all_names.sort();
    all_names.dedup();

    for name in all_names {
        match (from.fields.get(name), to.fields.get(name)) {
            (None, None) => unreachable!(),
            (None, Some(s)) => {
                changes.push(SchemaChange::FieldAdded {
                    name: name.clone(),
                    schema: s.clone(),
                });
            }
            (Some(s), None) => {
                changes.push(SchemaChange::FieldRemoved {
                    name: name.clone(),
                    schema: s.clone(),
                });
            }
            (Some(f), Some(t)) => {
                let from_types: std::collections::BTreeSet<FieldType> =
                    f.allowed_types.iter().copied().collect();
                let to_types: std::collections::BTreeSet<FieldType> =
                    t.allowed_types.iter().copied().collect();

                let added: Vec<FieldType> = to_types.difference(&from_types).copied().collect();
                let removed: Vec<FieldType> =
                    from_types.difference(&to_types).copied().collect();

                if !added.is_empty() && removed.is_empty() {
                    changes.push(SchemaChange::TypeWidened {
                        name: name.clone(),
                        added,
                    });
                } else if !removed.is_empty() && added.is_empty() {
                    changes.push(SchemaChange::TypeNarrowed {
                        name: name.clone(),
                        removed,
                    });
                } else if !added.is_empty() && !removed.is_empty() {
                    // Mixed add+remove decomposes into two changes for clarity.
                    changes.push(SchemaChange::TypeWidened {
                        name: name.clone(),
                        added,
                    });
                    changes.push(SchemaChange::TypeNarrowed {
                        name: name.clone(),
                        removed,
                    });
                }

                if f.required != t.required {
                    changes.push(SchemaChange::RequiredFlipped {
                        name: name.clone(),
                        was_required: f.required,
                        now_required: t.required,
                    });
                }
            }
        }
    }

    SchemaDiff { changes }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ft_int() -> FieldType {
        FieldType::Integer
    }
    fn ft_str() -> FieldType {
        FieldType::String
    }
    fn ft_flt() -> FieldType {
        FieldType::Float
    }

    #[test]
    fn identical_schemas_produce_empty_diff() {
        let s = Schema::new().with("a", FieldSchema::strict(ft_int()));
        let d = diff_schemas(&s, &s);
        assert!(d.is_empty());
        assert!(!d.is_breaking());
    }

    #[test]
    fn added_optional_field_not_breaking() {
        let from = Schema::new();
        let to = Schema::new().with("a", FieldSchema::optional(ft_int()));
        let d = diff_schemas(&from, &to);
        assert_eq!(d.changes.len(), 1);
        assert!(matches!(&d.changes[0], SchemaChange::FieldAdded { .. }));
        assert!(!d.is_breaking());
    }

    #[test]
    fn added_required_field_is_breaking() {
        let from = Schema::new();
        let to = Schema::new().with("a", FieldSchema::strict(ft_int()));
        let d = diff_schemas(&from, &to);
        assert!(d.is_breaking());
    }

    #[test]
    fn removed_optional_field_not_breaking() {
        let from = Schema::new().with("a", FieldSchema::optional(ft_int()));
        let to = Schema::new();
        let d = diff_schemas(&from, &to);
        assert_eq!(d.changes.len(), 1);
        assert!(matches!(&d.changes[0], SchemaChange::FieldRemoved { .. }));
        assert!(!d.is_breaking());
    }

    #[test]
    fn removed_required_field_is_breaking() {
        let from = Schema::new().with("a", FieldSchema::strict(ft_int()));
        let to = Schema::new();
        let d = diff_schemas(&from, &to);
        assert!(d.is_breaking());
    }

    #[test]
    fn type_widened_not_breaking() {
        let from = Schema::new().with("a", FieldSchema::strict(ft_int()));
        let to_schema = FieldSchema {
            allowed_types: vec![ft_int(), ft_flt()],
            required: true,
        };
        let to = Schema::new().with("a", to_schema);
        let d = diff_schemas(&from, &to);
        assert_eq!(d.changes.len(), 1);
        assert!(matches!(&d.changes[0], SchemaChange::TypeWidened { .. }));
        assert!(!d.is_breaking());
    }

    #[test]
    fn type_narrowed_is_breaking() {
        let from_schema = FieldSchema {
            allowed_types: vec![ft_int(), ft_flt()],
            required: true,
        };
        let from = Schema::new().with("a", from_schema);
        let to = Schema::new().with("a", FieldSchema::strict(ft_int()));
        let d = diff_schemas(&from, &to);
        assert!(matches!(&d.changes[0], SchemaChange::TypeNarrowed { .. }));
        assert!(d.is_breaking());
    }

    #[test]
    fn required_to_optional_not_breaking() {
        let from = Schema::new().with("a", FieldSchema::strict(ft_int()));
        let to = Schema::new().with("a", FieldSchema::optional(ft_int()));
        let d = diff_schemas(&from, &to);
        assert_eq!(d.changes.len(), 1);
        assert!(matches!(&d.changes[0], SchemaChange::RequiredFlipped { was_required: true, now_required: false, .. }));
        assert!(!d.is_breaking());
    }

    #[test]
    fn optional_to_required_is_breaking() {
        let from = Schema::new().with("a", FieldSchema::optional(ft_int()));
        let to = Schema::new().with("a", FieldSchema::strict(ft_int()));
        let d = diff_schemas(&from, &to);
        assert!(d.is_breaking());
    }

    #[test]
    fn mixed_widen_and_narrow_decomposed() {
        let from_schema = FieldSchema {
            allowed_types: vec![ft_int(), ft_flt()],
            required: true,
        };
        let to_schema = FieldSchema {
            allowed_types: vec![ft_int(), ft_str()],
            required: true,
        };
        let from = Schema::new().with("a", from_schema);
        let to = Schema::new().with("a", to_schema);
        let d = diff_schemas(&from, &to);
        assert_eq!(d.changes.len(), 2);
        assert!(d.changes.iter().any(|c| matches!(c, SchemaChange::TypeWidened { .. })));
        assert!(d.changes.iter().any(|c| matches!(c, SchemaChange::TypeNarrowed { .. })));
        assert!(d.is_breaking());
    }

    #[test]
    fn multiple_fields_diffed_in_sorted_order() {
        let from = Schema::new()
            .with("z", FieldSchema::strict(ft_int()))
            .with("a", FieldSchema::strict(ft_int()));
        let to = Schema::new()
            .with("a", FieldSchema::strict(ft_int()))
            .with("m", FieldSchema::optional(ft_str()))
            .with("z", FieldSchema::strict(ft_int()));
        let d = diff_schemas(&from, &to);
        // Only "m" added; "a" and "z" unchanged.
        assert_eq!(d.changes.len(), 1);
        assert_eq!(d.changes[0].field_name(), "m");
    }

    #[test]
    fn breaking_changes_filter_works() {
        let from = Schema::new().with("a", FieldSchema::strict(ft_int()));
        let to_schema = FieldSchema {
            allowed_types: vec![ft_int(), ft_flt()],
            required: true,
        };
        let to = Schema::new()
            .with("a", to_schema)
            .with("b", FieldSchema::strict(ft_str()));
        let d = diff_schemas(&from, &to);
        assert_eq!(d.changes.len(), 2);
        assert_eq!(d.breaking_changes().len(), 1);
        assert_eq!(d.breaking_changes()[0].field_name(), "b");
    }

    #[test]
    fn diff_is_deterministic() {
        let from = Schema::new().with("a", FieldSchema::strict(ft_int()));
        let to = Schema::new()
            .with("a", FieldSchema::optional(ft_int()))
            .with("b", FieldSchema::optional(ft_str()));
        let d1 = diff_schemas(&from, &to);
        let d2 = diff_schemas(&from, &to);
        assert_eq!(d1, d2);
    }

    #[test]
    fn diff_roundtrips_through_serde_json() {
        let from = Schema::new().with("a", FieldSchema::strict(ft_int()));
        let to = Schema::new().with("a", FieldSchema::optional(ft_int()));
        let d = diff_schemas(&from, &to);
        let json = serde_json::to_string(&d).unwrap();
        let back: SchemaDiff = serde_json::from_str(&json).unwrap();
        assert_eq!(d, back);
    }
}
