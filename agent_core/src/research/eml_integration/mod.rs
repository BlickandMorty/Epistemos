//! Source:
//! - `docs/fusion/EML_INTEGRATION_DOCTRINE_2026_05_17.md` — T7 §4.B
//!   integration plan. This module is the runtime-integration layer
//!   for the EML primitive (T5 owns the IR layer; the layers are
//!   intentionally separate per the T7 prompt's COORDINATION note).
//! - Companion: [`super::eml`] — the substrate-floor binary primitive
//!   `eml(x, y) = exp(x) − ln(y)` (Odrzywołek arXiv:2603.21852) plus
//!   the `S → 1 | eml(S, S)` grammar, evaluator, AnswerPacket-freeze
//!   gate, and the fp16-ULP smoke oracle.
//! - Audit: `docs/audits/EML_AUDIT_2026_05_17.md`.
//!
//! # T7 §4.B — EML runtime-integration adapter
//!
//! The T7 prompt's acceptance bar: EML stops being a research-island
//! and becomes a substrate primitive that ≥ 2 modules outside
//! `research/eml/` call into, with every behavior claim either paper-
//! line-cited or property-test-backed.
//!
//! This module owns the **runtime-integration layer**: small, focused,
//! additive surfaces that adapt the eml-operator into shapes other
//! modules can consume *without* coupling those modules to the eml
//! grammar's symbolic tree.
//!
//! ## §5.0 reconciliation row (CODE wins, see audit §6)
//!
//! The §4.B prompt vocabulary uses "energy" / "potential" terminology.
//! In this module those words mean *the f64 value of the eml primitive
//! applied to an encoded `(x, y)` pair*, optionally post-composed with
//! a documented monotone normalization. **EML is not an Energy-Based
//! Model in the LeCun sense** — no sampler, no Z, no contrastive
//! divergence, no training loop. The EmlPotential primitive in
//! [`potential`] is the canonical encoding pattern.
//!
//! ## Submodule layout
//!
//! - [`potential`] — `EmlPotential` newtype: monotone-encoded EML
//!   value over a strictly-positive score. The substrate primitive
//!   the rest of the runtime-integration layer composes from.
//!
//! Future submodules (Phase B per the doctrine doc §6):
//! - `observatory` — SAE cognition-observatory anomaly augmentation
//!   (the MVP integration site; see doctrine §3.3).
//! - `diagnostic` — Settings → Diagnostics "EML energy live readout"
//!   payload (doctrine §3.4).

pub mod potential;

pub use potential::{EmlPotential, EmlPotentialError};
