//! # `mutations`
//!
//! Typed mutation envelopes — the canonical replacement for broad
//! `NotificationCenter.default.post(name: .vaultChanged, ...)` style
//! invalidation.
//!
//! T+4.8 of `docs/audits/deliberation/T+4_cognitive_artifact_spine_deliberation_20260427.md`.
//! Closes Drift Q1 from `docs/audits/T+1_RECONCILIATION_2026-04-27.md` by
//! satisfying both `MASTER_FUSION.md` §3.5 (four-layer event hierarchy
//! contract) and `COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §9
//! (query-fingerprint matching with `affects_*` flags + `touched_*` lists).
//!
//! Two files:
//!   - [`envelope`] — the [`MutationEnvelope`] struct itself.
//!   - [`types`] — the small leaf enums and structs the envelope carries
//!     ([`MutationStatus`], [`MutationActor`], [`Sensitivity`],
//!     [`Reversibility`], [`BlockRef`], [`SourceOp`], [`RelationChange`]).
//!
//! Cross-language parity is enforced by
//! `EpistemosTests/MutationEnvelopeParityTests.swift`. The Swift mirror
//! lives at `Epistemos/Models/MutationEnvelope.swift`.
//!
//! T+4.8 ships the type only. Replacing existing `NotificationCenter`
//! call sites with envelope delivery is deferred to T+13 master
//! hardening so this slice stays purely additive — no protected
//! surface or hot path is touched.

pub mod envelope;
pub mod types;

pub use envelope::MutationEnvelope;
pub use types::{
    BlockRef, MutationActor, MutationStatus, RelationChange, Reversibility, Sensitivity, SourceOp,
};
