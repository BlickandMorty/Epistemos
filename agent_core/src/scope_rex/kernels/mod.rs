//! HELIOS V5 Tier-2 kernel reference paths.
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §1 Tier-2:
//! these kernels ship in the MAS bundle but default OFF. User opts
//! in via Settings → Experimental Metal Kernels (W11). Each kernel
//! requires a corresponding alternate model file to be useful — those
//! model files are bundled (NOT downloaded) per App Review §2.5.2.
//!
//! - [`t_mac`] — W12 T-MAC LUT-centric ternary inference
//!   (Wei et al. arXiv 2407.00088)
//! - [`bitnet`] — W13 BitNet b1.58 inference path
//!   (Ma et al. arXiv 2402.17764 / 2504.12285)
//! - [`sparse_ternary_gemm`] — W14 Sparse Ternary GEMM
//!   (Lipshitz et al. arXiv 2510.06957)
//!
//! ## §2.5.2 compliance posture
//!
//! Tier 2: bundled-but-default-OFF. The pure-Rust references below
//! lock the correctness contract; Metal acceleration on top of them
//! lands in a follow-up slice gated on the M2 Max falsifier rig
//! (W25). The bundled GGUF / ternary-quantized model files land in
//! the App Store release-prep slice (deferred) — until then, these
//! kernels run against synthetic ternary weights for testing.

pub mod bitnet;
pub mod sparse_ternary_gemm;
pub mod t_mac;
