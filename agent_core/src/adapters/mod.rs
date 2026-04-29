//! Adapter Gift-Box System (Simulation Mode S11; DOCTRINE §7).
//!
//! Each `.epbox` package is a real artifact whose unwrap performs
//! a real config change (per §7 — "not a metaphor"). Gift boxes
//! are mailed to companions, sit in the Mailroom inventory until
//! unwrapped, and on unwrap their content type's applier mutates
//! the companion record atomically.
//!
//! Module layout:
//!   - `epbox.rs`     — `.epbox` package format parser + validator
//!   - `applier/`     — one applier per V1 content type (5 total)
//!
//! The Swift host calls the FFI surface in
//! `crate::companions::bridge` to apply / list / revert gift
//! boxes; the audit ledger records the full config diff per §6.4.

pub mod applier;
pub mod epbox;

#[cfg(test)]
mod tests;

pub use applier::{Applier, ApplierError, ApplyOutcome};
pub use epbox::{
    EpBoxContent, EpBoxManifest, EpBoxOrigin, EpBoxParseError, EpBoxPath,
    EpBoxType,
};
