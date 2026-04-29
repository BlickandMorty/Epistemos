//! Simulation Mode honesty audit ledger (S3; DOCTRINE I-5, §9).
//!
//! Per DOCTRINE I-5 every animation must trace to one of exactly
//! three classes:
//!
//!   1. Event-driven: triggered by an `AgentEvent` or `GraphEvent`.
//!   2. Cosmetic idle: bound to "no events for ≥ N seconds" timer.
//!      Audit-labelled `cosmetic_idle:<companion_id>`.
//!   3. State transition: `companion_activity_state_changed`.
//!      Audit-labelled `state_transition:<from>:<to>`.
//!
//! Anything outside these three is a defect (DOCTRINE §9.2). This
//! module makes the rule **inspectable**: every `FrameDelta` the
//! reducer emits carries an `AuditOrigin`, and `AuditLedger`
//! persists the (delta_id → origin) link to SQLite so the Audit
//! View ("Why is this happening?", §9.3) can answer the question
//! for any visible animation.
//!
//! ## Naming disambiguation
//!
//! `crate::audit::*` (this module) is the **frame-delta animation
//! provenance** ledger. The existing `crate::companions::audit::*`
//! module records **companion-lifecycle events** (registered,
//! updated, archived) into the `companion_audit_log` table. Both
//! modules legitimately use the word "audit" — they observe
//! different concerns and write to different SQLite tables.
//!
//! ## S3 scope vs S4
//!
//! S3 lands the ledger infrastructure: `AuditOrigin`, `FrameDelta`,
//! `DeltaId`, `FrameDeltaKind`, `AuditLedger` SQLite store, and
//! the property-test contract that "every FrameDelta has a valid
//! origin". The actual reducer that emits FrameDeltas lives in S4
//! (Theater Metal renderer); until then the integration is
//! verified via `FrameDelta::for_event(seq, &AgentEvent)` — a
//! deterministic stub that S4 replaces with per-variant emission.

pub mod delta;
pub mod ledger;
pub mod origin;

pub use delta::{DeltaId, FrameDelta, FrameDeltaKind};
pub use ledger::{AuditError, AuditLedger, DeltaAuditEntry};
pub use origin::{AuditOrigin, AuditOriginKind, EventId};
