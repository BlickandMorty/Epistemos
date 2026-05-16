//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md` §5
//!   Phase B.1 J6 row — "research-tier — schema repair: Hyper-Dynamic
//!   Schemas (Meta-Schemas that repair themselves)".
//! - Conceptual antecedents:
//!   * Liskov substitution / type-union widening (canonical static-typing
//!     practice).
//!   * Bonifati et al., "Schema Evolution in Document Databases", VLDB
//!     2024 — schema-drift and auto-relaxation literature.
//!   * Bourbaki-style "structural mathematics": axioms can be widened to
//!     accommodate new observations as long as existing theorems remain
//!     true under the wider axiomatization.
//!
//! # Wave J6 — Hyper-Dynamic Schemas
//!
//! A schema that watches its own validation failures and proposes
//! widenings that absorb the failure while preserving validity for all
//! previously-accepted data. Two repair primitives in the substrate
//! floor:
//!
//! 1. **Type-union widening** — if field `f` was `Integer` and a new
//!    value is `Float`, the repair widens `f` to `IntegerOrFloat`.
//!    Existing integer-only inputs still validate; the new float-bearing
//!    input now validates too.
//! 2. **Optional-field promotion** — if a new input carries field `g`
//!    not declared in the schema, the repair adds `g` as optional. New
//!    inputs may carry `g`; old inputs without `g` still validate.
//!
//! The repair is conservative: never narrows, never drops fields,
//! never marks a previously-optional field as required.
//!
//! ## Diff (iter 79)
//!
//! [`diff`] is the inverse-direction primitive: given two schemas
//! (produced by repair, by hand, or by external schema evolution),
//! enumerate the deltas as `SchemaChange` events and flag whether
//! the overall diff is backward-compatible via `is_breaking()`.
//! Useful for CI gates and audit logs.

pub mod diff;
pub mod repair;

pub use diff::{diff_schemas, SchemaChange, SchemaDiff};
pub use repair::{
    repair_schema, validate_value, FieldSchema, FieldType, RepairPolicy, RepairReport, Schema,
    SchemaError, Value, ValidationError,
};
