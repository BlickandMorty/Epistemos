// HARDENING ENFORCEMENT: T-MAC kernel reference must remain panic-
// free in production. Tests are allowed to unwrap because a failed
// invariant SHOULD panic loudly.
#![cfg_attr(
    not(test),
    deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)
)]

//! HELIOS V5 W12 — T-MAC LUT-centric ternary inference.
//!
//! HELIOS-W12 guard
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W12 +
//! `docs/fusion/helios v5 first.md` §1.19:
//!
//! > "T-MAC (arXiv 2407.00088) achieves 30 tok/s single-core, 71
//! >  tok/s 8-core on M2 Ultra for BitNet b1.58-3B."
//!
//! Wei et al. "T-MAC: CPU Renaissance via Table Lookup for Low-Bit
//! LLM Deployment on Edge" — arXiv:2407.00088 (June 2024).
//!
//! **Tier 2 contract:** the T-MAC LUT path produces output matching
//! a reference dense ternary GEMM within FP16 tolerance on
//! representative prompts. The path is gated behind the
//! "Experimental Metal Kernels → T-MAC ternary" Settings toggle
//! (default OFF) and requires a bundled BitNet-trained or ternary-
//! quantized model file to be useful.
//!
//! The Tier-2 toggle is off by default per §2.5.2 compliance — the
//! kernel only activates when the user opts in. Source code ships
//! in the MAS bundle; the bundled GGUF model file is the
//! release-prep concern (separate from this commit).
//!
//! ## Cross-references
//!
//! - DOC 0 §0.2 (H4 = LatticeCoder; T-MAC sits adjacent)
//! - DOC 0 §0.4 (lane summary: Tier 2 flagged OFF)
//! - canon-hardening protocol §1 — WRV state machine; this module is
//!   `state: implemented` (no production caller; the
//!   ExperimentalMetalKernels Settings child row wires it once a
//!   bundled ternary GGUF is available)

/// Ternary weight representation: -1, 0, +1 packed into 2 bits.
/// The wire format uses i8 with values in {-1, 0, +1}; production
/// loaders unpack from the GGUF file format.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct TernaryWeight(pub i8);

impl TernaryWeight {
    /// Construct from an integer in {-1, 0, +1}. Returns None for
    /// out-of-range inputs.
    pub fn from_i8(v: i8) -> Option<Self> {
        match v {
            -1..=1 => Some(Self(v)),
            _ => None,
        }
    }

    /// Promote to f32 for arithmetic.
    pub fn to_f32(self) -> f32 {
        self.0 as f32
    }
}

/// LUT-centric ternary GEMM kernel — the T-MAC technique.
///
/// Reference: Wei et al. arXiv:2407.00088. The LUT trick precomputes
/// dot products of small input chunks against the 3 ternary values
/// {-1, 0, +1}; the actual GEMM then becomes table lookups + sums.
///
/// **This pure-Rust reference** does NOT use the LUT trick — it
/// computes the dot product directly. The Metal-accelerated drop-in
/// (W12.b follow-up) uses the LUT representation. The Tier-2
/// contract is FP16-tolerance equivalence between this reference
/// and the LUT path; testing the Metal kernel against this reference
/// is the W25 falsifier rig's job.
pub fn t_mac_reference(
    input: &[f32],
    weights: &[TernaryWeight],
    rows: usize,
    cols: usize,
) -> Vec<f32> {
    debug_assert_eq!(input.len(), cols);
    debug_assert_eq!(weights.len(), rows * cols);
    let mut out = vec![0.0f32; rows];
    for r in 0..rows {
        let mut acc = 0.0f32;
        for c in 0..cols {
            // -1 * x = -x, 0 * x = 0, 1 * x = x
            let w = weights[r * cols + c].0;
            match w {
                1 => acc += input[c],
                -1 => acc -= input[c],
                _ => {} // 0 contributes nothing
            }
        }
        out[r] = acc;
    }
    out
}

/// Sanity check: a ternary weight matrix has no values outside
/// {-1, 0, +1}. Returns true iff valid.
pub fn validate_ternary_weights(weights: &[TernaryWeight]) -> bool {
    weights.iter().all(|w| matches!(w.0, -1..=1))
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ternary_weight_constructor_rejects_out_of_range() {
        assert!(TernaryWeight::from_i8(0).is_some());
        assert!(TernaryWeight::from_i8(-1).is_some());
        assert!(TernaryWeight::from_i8(1).is_some());
        assert!(TernaryWeight::from_i8(2).is_none());
        assert!(TernaryWeight::from_i8(-2).is_none());
    }

    #[test]
    fn t_mac_reference_zero_weights_yield_zero_output() {
        let input = vec![1.0f32, -2.0, 3.0, -4.0];
        let weights = vec![TernaryWeight(0); 8]; // 2x4 zeroes
        let out = t_mac_reference(&input, &weights, 2, 4);
        assert_eq!(out, vec![0.0f32; 2]);
    }

    #[test]
    fn t_mac_reference_unit_positive_weights_match_input_sum() {
        let input = vec![1.0f32, -2.0, 3.0, -4.0];
        // Single row of all-+1 weights → output = sum(input)
        let weights = vec![TernaryWeight(1); 4];
        let out = t_mac_reference(&input, &weights, 1, 4);
        assert_eq!(out.len(), 1);
        assert!((out[0] - (-2.0)).abs() < 1e-6); // 1 - 2 + 3 - 4 = -2
    }

    #[test]
    fn t_mac_reference_unit_negative_weights_match_negated_input_sum() {
        let input = vec![1.0f32, -2.0, 3.0, -4.0];
        // Single row of all--1 weights → output = -sum(input) = 2.0
        let weights = vec![TernaryWeight(-1); 4];
        let out = t_mac_reference(&input, &weights, 1, 4);
        assert!((out[0] - 2.0).abs() < 1e-6);
    }

    #[test]
    fn t_mac_reference_mixed_weights_produce_signed_sum() {
        // Single row: weights = [+1, -1, 0, +1]
        let input = vec![10.0f32, 20.0, 30.0, 40.0];
        let weights = vec![
            TernaryWeight(1),
            TernaryWeight(-1),
            TernaryWeight(0),
            TernaryWeight(1),
        ];
        let out = t_mac_reference(&input, &weights, 1, 4);
        // 10 - 20 + 0 + 40 = 30
        assert!((out[0] - 30.0).abs() < 1e-6);
    }

    #[test]
    fn validate_ternary_weights_accepts_valid_grid() {
        let weights = vec![
            TernaryWeight(1),
            TernaryWeight(-1),
            TernaryWeight(0),
            TernaryWeight(1),
        ];
        assert!(validate_ternary_weights(&weights));
    }
}
