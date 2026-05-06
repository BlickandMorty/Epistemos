//! HELIOS V5 W25 — Tier-2 ternary kernel BIT-IDENTICAL contract fixtures.
//!
//! HELIOS-W12-FIXTURE / HELIOS-W13-FIXTURE / HELIOS-W14-FIXTURE
//!
//! Per `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §2 W12 + W13 + W14
//! and the Stage-20 Metal kernels at `Epistemos/Shaders/`:
//!
//!   - tmac_lut.metal           (W12 T-MAC LUT GEMM)
//!   - bitnet_b158.metal        (W13 BitNet b1.58 GEMM)
//!   - sparse_ternary_gemm.metal (W14 Sparse Ternary GEMM)
//!
//! ## Contract
//!
//! Each Rust reference function in `agent_core::scope_rex::kernels`
//! computes a canonical output for a given input. The Metal kernel
//! drop-ins MUST match the reference output BIT-IDENTICALLY at the
//! per-element level (within FP16 ULP tolerance for any reduction-
//! order-sensitive accumulation).
//!
//! These fixtures pin specific canonical input/output pairs. Any
//! consumer (Rust unit tests, Metal kernel runtime tests, the W25
//! M2 Max falsifier rig) can use these to verify behavioral
//! equivalence between implementations.
//!
//! ## How to use
//!
//! - **Rust callers**: use `tier2_*_fixture()` to retrieve a
//!   canonical (input, expected_output) tuple and exercise the
//!   reference against it.
//! - **Metal kernels**: load the same canonical inputs through the
//!   Metal pipeline, compare the GPU buffer output to the expected
//!   array. Any divergence outside FP16 tolerance is a HALT-class
//!   contract violation.
//!
//! ## Fixture stability
//!
//! These fixtures are **PINNED**. Changing them is a canon-violation
//! (any Metal implementation that previously passed would now fail).
//! Changes require explicit canon sign-off per CANON_HARDENING
//! _PROTOCOL §1 WRV state machine.

use agent_core::scope_rex::kernels::{
    bitnet::{absmean_quantize, bitnet_b158_gemm},
    sparse_ternary_gemm::{sparse_ternary_gemm, SparseTernaryMatrix},
    t_mac::{t_mac_reference, validate_ternary_weights, TernaryWeight},
};

// ---------------------------------------------------------------------------
// W12 — T-MAC LUT GEMM fixture
// ---------------------------------------------------------------------------

#[test]
fn w12_tmac_fixture_2x4_canonical_input() {
    // Canonical input: 4-element activation vector.
    let input: [f32; 4] = [1.0, 2.0, 3.0, 4.0];
    // 2x4 ternary weight matrix in row-major order:
    //   row 0: [+1, -1,  0, +1]   row 1: [ 0, +1, -1, +1]
    let weights: Vec<TernaryWeight> = [1, -1, 0, 1, 0, 1, -1, 1]
        .iter()
        .copied()
        .map(TernaryWeight)
        .collect();
    assert!(validate_ternary_weights(&weights));

    let out = t_mac_reference(&input, &weights, 2, 4);

    // Expected:
    //   row 0: 1·1 + (-1)·2 + 0·3 + 1·4 = 1 - 2 + 0 + 4 = 3.0
    //   row 1: 0·1 + 1·2 + (-1)·3 + 1·4 = 0 + 2 - 3 + 4 = 3.0
    assert_eq!(out, vec![3.0_f32, 3.0_f32]);
}

#[test]
fn w12_tmac_fixture_all_zero_weights_yield_zero_output() {
    let input: [f32; 8] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0];
    let weights: Vec<TernaryWeight> = vec![TernaryWeight(0); 24]; // 3x8
    let out = t_mac_reference(&input, &weights, 3, 8);
    assert_eq!(out, vec![0.0_f32, 0.0_f32, 0.0_f32]);
}

#[test]
fn w12_tmac_fixture_negative_weights_negate_input_correctly() {
    // 1x4 with all -1 weights → output = -sum(input)
    let input: [f32; 4] = [1.5, 2.5, 3.5, 4.5];
    let weights: Vec<TernaryWeight> = vec![TernaryWeight(-1); 4];
    let out = t_mac_reference(&input, &weights, 1, 4);
    // Expected: -(1.5 + 2.5 + 3.5 + 4.5) = -12.0
    assert_eq!(out, vec![-12.0_f32]);
}

#[test]
fn w12_tmac_fixture_pure_positive_weights_sum_input() {
    // 1x4 with all +1 weights → output = sum(input)
    let input: [f32; 4] = [1.5, 2.5, 3.5, 4.5];
    let weights: Vec<TernaryWeight> = vec![TernaryWeight(1); 4];
    let out = t_mac_reference(&input, &weights, 1, 4);
    assert_eq!(out, vec![12.0_f32]);
}

// ---------------------------------------------------------------------------
// W13 — BitNet b1.58 GEMM fixture
// ---------------------------------------------------------------------------

#[test]
fn w13_bitnet_absmean_quantize_fixture() {
    // Canonical input: 4 weights with known absmean.
    let weights: [f32; 4] = [1.0, -2.0, 0.5, -0.5];
    // absmean = (1 + 2 + 0.5 + 0.5) / 4 = 1.0
    let q = absmean_quantize(&weights);
    // The reference uses `gamma` as the absmean scale anchor.
    assert!((q.gamma - 1.0).abs() < 1e-6);
    // After quantization with scale γ=1.0:
    //   1.0  -> round(1.0)  = 1 → +1
    //  -2.0  -> round(-2.0) = -2 → clamp to -1
    // The fixture pins the first two positions which are unambiguous
    // (round-to-nearest at integer values; tie-break at 0.5 is
    // implementation-defined and intentionally NOT pinned here).
    assert_eq!(q.weights[0].0, 1);
    assert_eq!(q.weights[1].0, -1);
}

#[test]
fn w13_bitnet_b158_gemm_zero_input_yields_zero_output() {
    let input: Vec<f32> = vec![0.0; 4];
    let weights: Vec<f32> = vec![1.0, -1.0, 0.5, -0.5, 0.5, 1.0, -1.0, -0.5];
    let q = absmean_quantize(&weights);
    let out = bitnet_b158_gemm(&input, &q, 2, 4);
    // Zero input through any quantized weight matrix yields zero out.
    assert_eq!(out.len(), 2);
    for v in out {
        assert_eq!(v, 0.0_f32);
    }
}

#[test]
fn w13_bitnet_b158_gemm_dimensions_match_contract() {
    // Pin the dimension contract: rows × input_len weights, output of `rows`.
    let input: Vec<f32> = vec![1.0, 2.0, 3.0, 4.0];
    let weights: Vec<f32> = vec![1.0; 12]; // 3 rows × 4 cols
    let q = absmean_quantize(&weights);
    let out = bitnet_b158_gemm(&input, &q, 3, 4);
    assert_eq!(out.len(), 3);
}

// ---------------------------------------------------------------------------
// W14 — Sparse Ternary GEMM fixture
// ---------------------------------------------------------------------------

#[test]
fn w14_sparse_ternary_gemm_fixture_3x4() {
    // 3x4 ternary matrix in dense form:
    //   row 0: [+1,  0, -1,  0]   nnz=2
    //   row 1: [ 0, +1,  0, +1]   nnz=2
    //   row 2: [ 0,  0,  0, -1]   nnz=1
    let dense: Vec<TernaryWeight> = [1, 0, -1, 0, 0, 1, 0, 1, 0, 0, 0, -1]
        .iter()
        .copied()
        .map(TernaryWeight)
        .collect();
    let sparse = SparseTernaryMatrix::from_dense(&dense, 3, 4);
    assert_eq!(sparse.nnz(), 5);

    let input: [f32; 4] = [10.0, 20.0, 30.0, 40.0];
    let out = sparse_ternary_gemm(&input, &sparse);

    // Expected (matches dense GEMV):
    //   row 0: 1*10 + 0 + (-1)*30 + 0 = -20.0
    //   row 1: 0 + 1*20 + 0 + 1*40 = 60.0
    //   row 2: 0 + 0 + 0 + (-1)*40 = -40.0
    assert_eq!(out, vec![-20.0_f32, 60.0_f32, -40.0_f32]);
}

#[test]
fn w14_sparse_ternary_gemm_round_trip_matches_t_mac_dense() {
    // Sparsity invariant: STG output must match T-MAC dense GEMV
    // for any ternary matrix. This is the substrate-level
    // BIT-IDENTICAL contract between W12 and W14 references.
    let dense_weights: Vec<TernaryWeight> =
        [1, -1, 0, 1, 0, 1, -1, 1, -1, 0, 1, 0, 0, 1, 1, -1]
            .iter()
            .copied()
            .map(TernaryWeight)
            .collect();
    let sparse = SparseTernaryMatrix::from_dense(&dense_weights, 4, 4);
    let input: [f32; 4] = [1.5, -2.5, 3.5, -4.5];

    let dense_out = t_mac_reference(&input, &dense_weights, 4, 4);
    let sparse_out = sparse_ternary_gemm(&input, &sparse);

    assert_eq!(dense_out.len(), sparse_out.len());
    for (d, s) in dense_out.iter().zip(sparse_out.iter()) {
        // Both implementations are pure-i32-acc-on-f32-products; they
        // are BIT-IDENTICAL within reduction-order tolerance.
        assert_eq!(d, s, "dense vs sparse mismatch at fixture row");
    }
}

#[test]
fn w14_sparse_ternary_gemm_empty_sparse_yields_zero_output() {
    // All-zero ternary matrix → sparse matrix with nnz=0 → zero output.
    let dense: Vec<TernaryWeight> = vec![TernaryWeight(0); 16];
    let sparse = SparseTernaryMatrix::from_dense(&dense, 4, 4);
    assert_eq!(sparse.nnz(), 0);
    let input: [f32; 4] = [1.0, 2.0, 3.0, 4.0];
    let out = sparse_ternary_gemm(&input, &sparse);
    assert_eq!(out, vec![0.0_f32, 0.0_f32, 0.0_f32, 0.0_f32]);
}

#[test]
fn w14_sparse_ternary_gemm_sparsity_metric_matches_dense_zero_count() {
    let dense: Vec<TernaryWeight> = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
        .iter()
        .copied()
        .map(TernaryWeight)
        .collect();
    let sparse = SparseTernaryMatrix::from_dense(&dense, 4, 4);
    // 4 non-zero out of 16 = 75% sparse / 25% dense.
    assert_eq!(sparse.nnz(), 4);
    assert!((sparse.sparsity() - 0.75).abs() < 1e-6);
}
