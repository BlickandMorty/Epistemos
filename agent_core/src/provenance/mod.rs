//! # `provenance`
//!
//! The Phase-1 keystone primitive of the Epistemos doctrine: a typed
//! `ClaimLedger` with **retraction propagation**. The doctrine names it as
//! the novel architectural property that distinguishes Epistemos from
//! every other agent runtime — a static audit log can be ignored, but a
//! retraction-propagating substrate forces the system to surface when a
//! previously-trusted inference is no longer trustworthy.
//!
//! ## Doctrine reference
//! `docs/_consolidated/00_canonical_authority/01_DOCTRINE.md` §3 — the
//! four-layer event hierarchy + the retraction primitive specification:
//!
//!   - Bounded walk policy: depth ≤ [`MAX_RETRACTION_WALK_DEPTH`] (16)
//!   - Cycle detection: reject retraction walks that traverse a cycle
//!     in the derivation graph
//!   - Append-only edges: status flips emit new edges, never mutate
//!     prior records (the `claim_status_edges` history is the audit
//!     trail; the latest edge wins via the `claim_current` view)
//!
//! ## Phase-1 scope (deliberate)
//!
//! `04_PHASES.md §"Phase 1"` is explicit:
//!
//! > Deliberately scoped: only one Claim type and one Evidence type —
//! > enough to prove the substrate works. Subsequent items extend the
//! > type set.
//!
//! So this module ships a minimal viable substrate: one `Claim` shape,
//! one `Evidence` shape, four status states (`Active` / `AtRisk` /
//! `NeedsRevalidation` / `Retracted`), a `ClaimLedger` that owns the
//! adjacency lists, and `commit_*` / `retract_*` methods that enforce
//! the bounded-walk + cycle-detection invariants.
//!
//! The wider type set (multiple Claim kinds, evidence-quality bands,
//! source-tier scoring, AuditFinding back-references) lands in Phase 2+.
//!
//! ## Cross-language parity
//!
//! Wire format is byte-equal-able with a future Swift mirror at
//! `Epistemos/Models/ClaimLedger.swift` (Phase 2). Phase 1 ships the
//! Rust side only — Swift consumers will subscribe to ledger updates
//! via the `MutationEnvelope` projection once the wiring lands.

pub mod ledger;
pub mod replay;

pub use ledger::{
    Claim, ClaimId, ClaimLedger, ClaimStatus, Evidence, EvidenceId, LedgerError, LedgerEvent,
    RetractionPropagatedEvent, RetractionReport, RetractionTriggerKind, MAX_RETRACTION_WALK_DEPTH,
};
pub use replay::{
    BundleError, ClaimDerivation, ClaimEvidenceLink, LedgerSnapshot, ReplayBundle,
    REPLAY_BUNDLE_SCHEMA_VERSION,
};
