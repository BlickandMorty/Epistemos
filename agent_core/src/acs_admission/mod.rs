//! ACS admission field.
//!
//! ACS (Anchored Cognitive Substrate / Autopoietic Cognitive Stack)
//! admission is a policy boundary above SCOPE-Rex. It is intentionally
//! pure-data: it does not call cloud providers, run inference, or apply
//! durable state changes directly.
//!
//! Decomposed across submodules (T18B 2026-05-22). See
//! `docs/T18B-DECOMPOSE-2026-05-22.md` for the layout map.

mod admit;
mod audit_sink;
mod common;
mod decision;
mod input;
mod policy;
mod proof;
mod requests;
mod risk;
mod validation;
mod verdict;
mod wire;

pub use admit::*;
pub use audit_sink::*;
pub use common::*;
pub use decision::*;
pub use input::*;
pub use policy::*;
pub use proof::*;
pub use requests::*;
pub use risk::*;
pub use validation::*;
pub use verdict::*;
pub use wire::*;

#[cfg(test)]
mod tests;
