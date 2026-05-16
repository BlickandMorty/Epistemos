//! Source:
//! - `~/Documents/Epistemos-QuickCapture/FINAL_SYNTHESIS.md` §5.4
//!   lines 446-461 — canonical `dp_aggregate(values, epsilon)`
//!   spec + ε ≤ 0.5 budget pin.
//! - `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.42 —
//!   "Differential Privacy on Auto-Research Telemetry — ε ≤ 0.5
//!   Laplace gate (B2-M14)" forward-staged doctrine row landed
//!   2026-05-16 (audit-of-audit #2).
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   line 62, 167 — explicit `agent_core/src/auto_research/dp.rs`
//!   B2-M14 substrate target.
//! - Dwork et al., "Calibrating Noise to Sensitivity in Private Data
//!   Analysis", TCC 2006 — canonical Laplace mechanism.
//! - Dwork-Roth, "The Algorithmic Foundations of Differential
//!   Privacy", 2014 — §3.4 parallel-composition theorem.
//!
//! # Auto-research telemetry substrate
//!
//! The morning auto-research report aggregates per-night experiment
//! outcomes back into the user's context. Without a DP gate, those
//! aggregates can leak individual query content back to the user's
//! own future LLMs through prompt-context absorption — "the user's
//! queries stay private even from themselves-tomorrow" is the
//! design property.
//!
//! Sub-module:
//!
//! - [`dp`] — Laplace-noise differential-privacy gate. Canonical
//!   `dp_aggregate(values, epsilon, &mut sampler)` formula with
//!   `sensitivity = 1.0`, `scale = sensitivity / epsilon`, Laplace
//!   noise added to the aggregate mean. Doctrine bound ε ≤ 0.5
//!   enforced at the validator.
//!
//! ## What this module is NOT
//!
//! - It is NOT the report generator. The aggregate values are
//!   produced by upstream auto-research telemetry; this module only
//!   gates the report-to-LLM context boundary.
//! - It is NOT applied to RunLedger / ClaimLedger / ExecutionReceipt
//!   — those are integrity-critical and remain plaintext. The DP
//!   gate guards only the report-to-LLM context channel.
//! - It does NOT compose across nights — each morning consumes a
//!   fresh ε = 0.5 budget per §3.42 doctrine. Post-V1 evaluation if
//!   the report becomes a long-running attack surface.

pub mod dp;

pub use dp::{
    dp_aggregate, is_valid_epsilon, noise_scale, DeterministicLcgSampler, DpError,
    LaplaceSampler, ZeroNoiseSampler, DEFAULT_SENSITIVITY, DP_EPSILON_MAX,
};
