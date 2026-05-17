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

    /// Stable identifier for the change kind. Used by telemetry logs
    /// that want a wire-form string per variant.
    pub const fn kind(&self) -> &'static str {
        match self {
            SchemaChange::FieldAdded { .. } => "field_added",
            SchemaChange::FieldRemoved { .. } => "field_removed",
            SchemaChange::TypeWidened { .. } => "type_widened",
            SchemaChange::TypeNarrowed { .. } => "type_narrowed",
            SchemaChange::RequiredFlipped { .. } => "required_flipped",
        }
    }

    pub const fn is_field_added(&self) -> bool {
        matches!(self, SchemaChange::FieldAdded { .. })
    }

    pub const fn is_field_removed(&self) -> bool {
        matches!(self, SchemaChange::FieldRemoved { .. })
    }

    pub const fn is_type_widened(&self) -> bool {
        matches!(self, SchemaChange::TypeWidened { .. })
    }

    pub const fn is_type_narrowed(&self) -> bool {
        matches!(self, SchemaChange::TypeNarrowed { .. })
    }

    /// Cross-surface invariant: exactly one of the 5 `is_*` predicates
    /// is true per SchemaChange variant (5-way partition).
    pub const fn is_required_flipped(&self) -> bool {
        matches!(self, SchemaChange::RequiredFlipped { .. })
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

    /// Number of changes. Cross-surface invariant: `len() == 0 iff is_empty()`.
    pub fn len(&self) -> usize {
        self.changes.len()
    }

    /// Number of breaking changes. Cross-surface invariant:
    /// `breaking_change_count() == 0 iff !is_breaking()`.
    pub fn breaking_change_count(&self) -> usize {
        self.changes.iter().filter(|c| c.is_breaking()).count()
    }

    /// Number of safe (non-breaking) changes. Cross-surface invariant:
    /// `safe_change_count() + breaking_change_count() == len()`.
    pub fn safe_change_count(&self) -> usize {
        self.changes.iter().filter(|c| !c.is_breaking()).count()
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

    // ── diagnostic surface (iter 182) ────────────────────────────────────────

    fn all_change_variants() -> Vec<SchemaChange> {
        vec![
            SchemaChange::FieldAdded { name: "a".into(), schema: FieldSchema::optional(ft_int()) },
            SchemaChange::FieldRemoved { name: "b".into(), schema: FieldSchema::strict(ft_int()) },
            SchemaChange::TypeWidened { name: "c".into(), added: vec![ft_flt()] },
            SchemaChange::TypeNarrowed { name: "d".into(), removed: vec![ft_str()] },
            SchemaChange::RequiredFlipped { name: "e".into(), was_required: true, now_required: false },
        ]
    }

    #[test]
    fn change_kind_distinct_per_variant() {
        let variants = all_change_variants();
        let kinds: std::collections::HashSet<_> = variants.iter().map(|c| c.kind()).collect();
        assert_eq!(kinds.len(), 5);
    }

    #[test]
    fn change_classifiers_5way_partition() {
        // Cross-surface invariant: exactly one of the 5 `is_*` predicates
        // is true per SchemaChange variant.
        for c in all_change_variants() {
            let five = [
                c.is_field_added(),
                c.is_field_removed(),
                c.is_type_widened(),
                c.is_type_narrowed(),
                c.is_required_flipped(),
            ];
            assert_eq!(five.iter().filter(|t| **t).count(), 1, "{:?}", c);
        }
    }

    #[test]
    fn diff_len_zero_iff_is_empty() {
        // Cross-surface invariant.
        let s = Schema::new().with("a", FieldSchema::strict(ft_int()));
        let d_same = diff_schemas(&s, &s);
        assert_eq!(d_same.len() == 0, d_same.is_empty());
        let d_diff = diff_schemas(&Schema::new(), &s);
        assert_eq!(d_diff.len() == 0, d_diff.is_empty());
        assert_eq!(d_diff.len(), 1);
    }

    #[test]
    fn breaking_count_zero_iff_not_is_breaking() {
        // Cross-surface invariant.
        let from = Schema::new();
        let to_safe = Schema::new().with("a", FieldSchema::optional(ft_int()));
        let d = diff_schemas(&from, &to_safe);
        assert_eq!(d.breaking_change_count() == 0, !d.is_breaking());

        let to_break = Schema::new().with("a", FieldSchema::strict(ft_int()));
        let d = diff_schemas(&from, &to_break);
        assert!(d.breaking_change_count() > 0);
        assert!(d.is_breaking());
    }

    #[test]
    fn safe_plus_breaking_equals_total_invariant() {
        // Cross-surface invariant: safe_change_count + breaking_change_count = len.
        let from = Schema::new().with("a", FieldSchema::strict(ft_int()));
        let to = Schema::new()
            .with("a", FieldSchema::optional(ft_int())) // RequiredFlipped (safe)
            .with("b", FieldSchema::strict(ft_str())); // FieldAdded required (breaking)
        let d = diff_schemas(&from, &to);
        assert_eq!(d.safe_change_count() + d.breaking_change_count(), d.len());
        assert_eq!(d.safe_change_count(), 1);
        assert_eq!(d.breaking_change_count(), 1);
    }
}
