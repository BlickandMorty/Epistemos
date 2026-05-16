//! Source:
//! - `docs/fusion/jordan's research/kimis deep research/acs_meta_layer.md`
//!   — Autopoietic Cognitive Stack (ACS) doctrine. Recursive self-governance
//!   where each cell is a complete SCOPE-Rex instance and cells synchronize
//!   via Kuramoto-coupled phase dynamics on Apple Silicon UMA.
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md` §5
//!   J5 row.
//!
//! # Wave J5 — Autopoietic Cognitive Stack (ACS)
//!
//! Multi-scale governance pattern: transistor → cell → tissue → organ →
//! organism → ecosystem, with the same Residency-Governance pattern at
//! every scale. The substrate floor here owns the **synchronization
//! primitive** that lets cells form tissues — Kuramoto phase coupling.
//!
//! Sub-features (substrate floor in this iter is #1 only):
//!
//! 1. **Kuramoto synchronization** ([`kuramoto`]) — N-oscillator phase
//!    network with mean-field coupling. Per `acs_meta_layer.md`
//!    Dorfler-Bullo exact results: synchronization onset at
//!    `K_c = 2 / (π · g(0))` where `g(0)` is the natural-frequency
//!    distribution density at zero.
//! 2. **Notch-Delta lateral inhibition** (NOT-STARTED) — cell
//!    differentiation pattern, future iter.
//! 3. **Autopoietic closure check** (NOT-STARTED) — Maturana-Varela
//!    6-criteria validator for the organizational-closure property.
//! 4. **VSM recursive governance** (NOT-STARTED) — Stafford Beer
//!    Viable Systems Model implementation.
//!
//! Per the doctrine's §"This is not metaphor" pin, all of these are
//! grounded in published math (Dorfler-Bullo, Kauffman, Maturana-Varela,
//! SiliconSwarm's empirical 6.31× Apple Silicon speedup) rather than
//! loose biological analogies.

pub mod kuramoto;
pub mod notch_delta;

pub use kuramoto::{
    kuramoto_step, order_parameter, KuramotoError, KuramotoNetwork, KuramotoOscillator,
    OrderParameter,
};
pub use notch_delta::{
    notch_delta_step, NotchDeltaCell, NotchDeltaError, NotchDeltaNetwork, NotchDeltaParams,
};
