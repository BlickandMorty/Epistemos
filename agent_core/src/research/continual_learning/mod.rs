//! Source:
//! - `docs/fusion/jordan's research/kimis deep research/research/continual_learning_online.md`
//!   §8 "Architecture Recommendation: 'Never Retrain' Stack" — the 7-layer
//!   architecture (base model · adaptation · protection · memory · history ·
//!   governance · quantization) and the 5 sub-features called out in the
//!   Terminal B driver J3 row.
//! - `docs/fusion/jordan's research/kimis deep research/osft_psoft_coso_fusion.md` —
//!   OSFT / PSOFT / COSO fusion (orthogonal fine-tuning lane).
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md` §5
//!   Phase B.1 J3 row.
//!
//! # Wave J3 — Continual learning suite ("Never Retrain" architecture)
//!
//! Five sub-features per the driver J3 row:
//!
//! 1. **EWC (Elastic Weight Consolidation)** ([`ewc`]) — Kirkpatrick et al.
//!    PNAS 2017, arXiv:1612.00796. Fisher-information-weighted quadratic
//!    penalty anchoring "important" parameters to their post-task values.
//!    The "Protection" layer in §8.1.
//! 2. **OFTv2 / QOFT** (NOT-STARTED) — Qiu et al. arXiv:2506.19847.
//!    Orthogonal fine-tuning with input-centric matrix-vector multiply
//!    (10× faster than original OFT, 3× lower GPU memory). The
//!    "Adaptation" layer in §8.1 (alternative to LoRA).
//! 3. **DSC / DOC (Dynamic Orthogonal Continual)** (NOT-STARTED) — Wang
//!    et al. arXiv:2509.23893, 2025. Online PCA tracking of functional
//!    direction drift; ~40% less forgetting vs fixed-direction methods
//!    over >100-conversation sequences.
//! 4. **Titans-MAC** (NOT-STARTED) — Behrouz et al. arXiv:2501.00663.
//!    Memory-Augmented Continual learning; surprise-gradient-driven
//!    inner-loop update to a learned-memory module. L_SE in the
//!    Helios v3 six-tier architecture.
//! 5. **SEAL-DoRA** (NOT-STARTED) — Zweiger-Pari et al. arXiv:2506.10943.
//!    Self-Edited Active Learning; outer-RL nightly self-edits compiled
//!    into per-user DoRA adapter.
//!
//! ## "Never Retrain" invariant
//!
//! Per §8.1: base model weights are immutable; all adaptation happens via
//! external memory + per-user adapter + protected parameter set. The
//! continual learning lane MUST preserve this — any sub-feature that
//! modifies the base weights breaks the canonical contract.
//!
//! ## §8.3 open questions
//!
//! - No unified convergence proof for EWC + LoRA + Fast Weights interaction.
//! - Optimal Fisher threshold τ_prime is currently heuristic.
//! - ANE backward pass unavailable; on-device training requires GPU/CPU
//!   fallback (Wave J8 ANE Direct may revisit but is read-only inference).

pub mod dsc;
pub mod ewc;
pub mod oftv2;
pub mod titans_mac;

pub use dsc::{project_orthogonal, update_with_gradient, DscError, OrthogonalSubspace};
pub use ewc::{ewc_gradient_contribution, ewc_penalty, EwcAnchor, EwcError, FisherInfo};
pub use oftv2::{apply_oftv2, rotation_2d, OftError, OrthogonalMatrix};
pub use titans_mac::{
    apply_surprise_update, surprise, LearnedMemoryModule, TitansError,
};
