//! `helios-core` — The mathematical foundation of Epistenos.
//!
//! This crate provides the five mathematical pillars on which the Epistenos
//! deterministic superintelligence system is built. Every module is
//! independently testable, verifiable, and documented.
//!
//! # The Five Mathematical Pillars
//!
//! 1. **Type-State Memory Hierarchy** (`types`)
//!    Compile-time guarantees for the six-tier memory system (L0 → L1 →
//!    L2 → L3 → L4 → L_SE). Tokens carry phantom-type markers that
//!    prevent accidental operations on compressed or sketched state.
//!
//! 2. **Lattice Vector Quantization** (`lattice`)
//!    Real implementations of E8 (240 minimal vectors, G ≈ 0.0717) and
//!    Leech (4096 shallow-shell representatives, G ≈ 0.0658) lattice
//!    codebooks, plus Babai’s nearest-plane CVP approximation and the
//!    GPTQ-as-Babai interpretation for Hessian-induced quantization.
//!
//! 3. **Randomized Sketching** (`sketch`)
//!    CountSketch (D × W, median estimator), Sparse Johnson–Lindenstrauss
//!    (s = 1), and Free Random Projection (Hayase-Collins-Inoue orthogonal
//!    basis). All sketches support deterministic merge semantics.
//!
//! 4. **Per-Coordinate Data-Dependent Quantization** (`prcda`)
//!    The Tencent "Sherry" 1.25-bit binary codec for weights and
//!    residuals, with automatic NF4 fallback when the KL-divergence proxy
//!    exceeds a configurable threshold.
//!
//! 5. **Weighted Bounded-Output Drift Inequality** (`inequality`)
//!    The WBO-6 theorem: `‖Δlogits‖ ≤ ½·(T_W + T_K + T_R + T_Q + T_S +
//!    T_SE)`. This is the core analytical guarantee that the multi-tier
//!    memory hierarchy does not catastrophically diverge from exact
//!    inference.
//!
//! # Usage
//!
//! ```
//! use helios_core::types::{TokenState, L0, TokenId, LayerId};
//! use helios_core::lattice::{E8Codebook, babai_nearest_plane, LatticeBasis};
//! use helios_core::sketch::CountSketch;
//! use helios_core::prcda::{SherryCodec, sherry_pack};
//! use helios_core::inequality::{Wbo6Terms, measure_wbo6, DriftTracker};
//! ```

#![warn(missing_docs)]
#![warn(rust_2018_idioms)]

pub mod inequality;
pub mod lattice;
pub mod prcda;
pub mod sketch;
pub mod traits;
pub mod types;

// Re-export the most commonly used items for ergonomic access.

// ---- types ----------------------------------------------------------------
pub use types::{
    BlockScale, LayerId, L0, L1, L2, L3, L4, L_SE, MemoryTier, TernaryState, TokenId, TokenState,
};
pub use types::{
    demote_l1_to_l2, demote_l2_to_l3, demote_l3_to_l4, promote_l0_to_l1, promote_to_l_se,
};

// ---- lattice --------------------------------------------------------------
pub use lattice::{
    babai_nearest_plane, gptq_as_babai, E8Codebook, LatticeBasis, LatticeError, LeechCodebook,
    QuantizedWeights,
};

// ---- sketch ---------------------------------------------------------------
pub use sketch::{
    CountSketch, FreeRandomProjection, SketchBasis, SketchError, SparseJL,
};

// ---- prcda ----------------------------------------------------------------
pub use prcda::{
    sherry_nf4_fallback, sherry_pack, sherry_unpack, SherryBlock, SherryCodec, SherryError,
};

// ---- inequality -----------------------------------------------------------
pub use inequality::{
    drift_from_terms, measure_wbo6, synthetic_terms, wbo5_paper_version, DriftTracker,
    LogitDrift, Wbo6Terms,
};
