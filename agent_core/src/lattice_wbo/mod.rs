//! Lightweight Lattice-Wyner-Ziv / WBO accounting types.
//!
//! This module is deliberately ledger-only. It names codecs, budgets, side
//! information, and falsifier hooks so callers cannot hide approximation error
//! behind UAS residency or active-support terminology.
//!
//! The module is split into reviewable submodules; this file is a thin façade
//! that re-exports the public surface in its historical shape. See
//! `docs/T17B-DECOMPOSE-2026-05-22.md` for the 1:1 mapping back to the prior
//! monolith.

mod accounting;
mod error;
mod register;
mod verifier;
mod wire;

#[cfg(test)]
mod tests;

pub use accounting::{ActiveSupportBudget, LatticeBudget, LatticeErrorContribution, WboTermCode};
pub use error::LatticeWboError;
pub use register::{LatticeCoderKind, ResidencyTier, SideInformationKind, WboLedgerEntry};
pub use verifier::{falsifier_hook_owners, FalsifierHookOwner, FALSIFIER_HOOK_OWNERS};
