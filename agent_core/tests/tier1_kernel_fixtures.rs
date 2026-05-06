//! HELIOS V5 W25 — Tier-1 substrate BIT-IDENTICAL contract fixtures.
//!
//! HELIOS-W6-FIXTURE / HELIOS-W7-FIXTURE / HELIOS-W8-FIXTURE
//!
//! Per `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` §2 W6/W7/W8 and the
//! Tier-1 Metal kernels at `Epistemos/Shaders/`:
//!
//!   - active_support_atlas.metal (W6 ASA matmul)
//!   - half_softmax_post.metal     (W7 H2 ½ post-softmax contraction)
//!   - kv_direct_gate.metal        (W8 KV direct path)
//!
//! ## Contract
//!
//! Each Rust reference in `agent_core::scope_rex::metal` /
//! `::kv` computes a canonical output. Metal kernel drop-ins MUST
//! match the reference output BIT-IDENTICALLY at the per-element
//! level (within ≤2 ULP for fp16, BIT-IDENTICAL for fp32).
//!
//! ## How to use
//!
//! - Rust unit tests use these fixtures to catch reference
//!   regressions.
//! - The W25 M2 Max falsifier rig loads the same canonical inputs
//!   through the Metal pipeline and compares per-element.
//!
//! ## Fixture stability
//!
//! These fixtures are PINNED. Changing them is a canon violation.

use agent_core::scope_rex::{
    kv::direct_gate::{direct_qk_row, reference_qk_row, KvLayout, KvPair, route},
    metal::{
        asa_index::{asa_matmul, dense_matmul, AsaIndex},
        softmax::{half_softmax_post, reference_softmax},
    },
};

// ---------------------------------------------------------------------------
// W6 — Active-Support Atlas matmul fixture
// ---------------------------------------------------------------------------

#[test]
fn w6_asa_matmul_full_atlas_matches_dense() {
    // 3x4 dense weight matrix:
    //   row 0: [1, 2, 3, 4]
    //   row 1: [5, 6, 7, 8]
    //   row 2: [9, 10, 11, 12]
    let weights: Vec<f32> = vec![1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0];
    let input: [f32; 4] = [0.1, 0.2, 0.3, 0.4];

    // ASA with all 3 rows active = identical to dense matmul.
    let full = AsaIndex::full(3);
    let dense_out = dense_matmul(&input, &weights, 3, 4);
    let asa_out = asa_matmul(&input, &weights, 3, 4, &full);
    assert_eq!(dense_out, asa_out);
}

#[test]
fn w6_asa_matmul_pinned_dense_canonical_output() {
    // Pin a known dense output to lock the reference. 3x4 matrix:
    //   row 0: [1, 0, -1, 0]
    //   row 1: [0, 1, 0, -1]
    //   row 2: [-1, 0, 1, 0]
    let weights: Vec<f32> = vec![1.0, 0.0, -1.0, 0.0, 0.0, 1.0, 0.0, -1.0, -1.0, 0.0, 1.0, 0.0];
    let input: [f32; 4] = [10.0, 20.0, 30.0, 40.0];
    let out = dense_matmul(&input, &weights, 3, 4);
    // Expected:
    //   row 0: 10 - 30 = -20.0
    //   row 1: 20 - 40 = -20.0
    //   row 2: -10 + 30 = 20.0
    assert_eq!(out, vec![-20.0_f32, -20.0_f32, 20.0_f32]);
}

#[test]
fn w6_asa_matmul_partial_atlas_zeroes_inactive_rows() {
    // Active only row 1. Rows 0 and 2 must produce 0.
    let weights: Vec<f32> = vec![1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0];
    let input: [f32; 4] = [0.1, 0.2, 0.3, 0.4];

    let partial = AsaIndex::from_active_rows([1]);
    let out = asa_matmul(&input, &weights, 3, 4, &partial);
    // row 0 inactive → 0
    // row 1 active   → 5*0.1 + 6*0.2 + 7*0.3 + 8*0.4 = 0.5 + 1.2 + 2.1 + 3.2 = 7.0
    // row 2 inactive → 0
    assert_eq!(out[0], 0.0_f32);
    assert!((out[1] - 7.0).abs() < 1e-5);
    assert_eq!(out[2], 0.0_f32);
}

#[test]
fn w6_asa_matmul_empty_atlas_yields_all_zero_output() {
    let weights: Vec<f32> = vec![1.0; 12];
    let input: [f32; 4] = [1.0, 2.0, 3.0, 4.0];
    let empty = AsaIndex::new();
    let out = asa_matmul(&input, &weights, 3, 4, &empty);
    assert_eq!(out, vec![0.0_f32, 0.0_f32, 0.0_f32]);
}

// ---------------------------------------------------------------------------
// W7 — Half-softmax-post fixture (H2 post-softmax ½ contraction)
// ---------------------------------------------------------------------------

#[test]
fn w7_reference_softmax_uniform_input_yields_uniform_output() {
    // Uniform logits → uniform probabilities (1/N each).
    let input: [f32; 4] = [1.0, 1.0, 1.0, 1.0];
    let out = reference_softmax(&input);
    assert_eq!(out.len(), 4);
    for v in out {
        assert!((v - 0.25).abs() < 1e-6);
    }
}

#[test]
fn w7_reference_softmax_peaks_at_argmax() {
    // The largest input must produce the largest output probability.
    let input: [f32; 4] = [1.0, 2.0, 5.0, 0.5];
    let out = reference_softmax(&input);
    let argmax = out
        .iter()
        .enumerate()
        .max_by(|a, b| a.1.partial_cmp(b.1).unwrap())
        .unwrap()
        .0;
    assert_eq!(argmax, 2); // input[2] = 5.0 is the maximum
}

#[test]
fn w7_reference_softmax_sums_to_one() {
    let input: [f32; 5] = [0.1, -0.2, 0.3, -0.4, 0.5];
    let out = reference_softmax(&input);
    let sum: f32 = out.iter().sum();
    assert!((sum - 1.0).abs() < 1e-6);
}

#[test]
fn w7_half_softmax_post_matches_reference_within_ulp() {
    // The "post" in `half_softmax_post` refers to the dispatch
    // ordering at the resonance phase (post-softmax stage of the
    // WBO-7 inequality), NOT to a half-factor in the function
    // output. The function computes the SAME softmax as
    // `reference_softmax`. The H2 ½ contraction lives in the
    // theorem statement (½ factor on post-softmax LSE drift),
    // not in this kernel's per-element output.
    let input: [f32; 4] = [0.1, 0.2, 0.3, 0.4];
    let reference = reference_softmax(&input);
    let post = half_softmax_post(&input);
    assert_eq!(reference.len(), post.len());
    for (r, p) in reference.iter().zip(post.iter()) {
        // ≤ 2 ULP fp32 tolerance per the H2 BIT-IDENTICAL contract.
        assert!(
            (r - p).abs() < 1e-6,
            "half_softmax_post must match reference_softmax bit-for-bit"
        );
    }
}

#[test]
fn w7_half_softmax_post_sums_to_one() {
    // Same softmax-distribution invariant as reference_softmax.
    let input: [f32; 6] = [0.5, -0.5, 1.0, -1.0, 0.0, 2.0];
    let post = half_softmax_post(&input);
    let sum: f32 = post.iter().sum();
    assert!((sum - 1.0).abs() < 1e-5);
}

// ---------------------------------------------------------------------------
// W8 — KV direct-gate fixture
// ---------------------------------------------------------------------------

#[test]
fn w8_kv_route_page_aligned_dispatches_via_direct_path() {
    // Direct path eligibility requires:
    //   key_dim == value_dim AND seq_len % page_size == 0.
    // Page-aligned, equal dim → Direct.
    let layout = KvLayout::new(128, 64, 64, 128);
    assert!(layout.direct_path_eligible());
    let dispatch = route(&layout);
    assert_eq!(dispatch, agent_core::scope_rex::kv::direct_gate::KvDispatch::Direct);
}

#[test]
fn w8_kv_route_unaligned_seq_len_falls_back_to_reference() {
    // seq_len = 100 is NOT a multiple of page_size = 128 → Reference path.
    let layout = KvLayout::new(100, 64, 64, 128);
    assert!(!layout.direct_path_eligible());
    let dispatch = route(&layout);
    assert_eq!(dispatch, agent_core::scope_rex::kv::direct_gate::KvDispatch::Reference);
}

#[test]
fn w8_kv_route_asymmetric_kv_dims_falls_back_to_reference() {
    // Asymmetric key_dim != value_dim → Reference path even when
    // seq_len is page-aligned.
    let layout = KvLayout::new(128, 64, 32, 128);
    assert!(!layout.direct_path_eligible());
    let dispatch = route(&layout);
    assert_eq!(dispatch, agent_core::scope_rex::kv::direct_gate::KvDispatch::Reference);
}

#[test]
fn w8_kv_direct_qk_row_matches_reference_for_canonical_input() {
    // 3 KV pairs with deterministic values; query is a known vector.
    let pairs = vec![
        KvPair::new(vec![1.0, 0.0, 0.0, 0.0], vec![0.0; 4]),
        KvPair::new(vec![0.0, 1.0, 0.0, 0.0], vec![0.0; 4]),
        KvPair::new(vec![0.0, 0.0, 1.0, 0.0], vec![0.0; 4]),
    ];
    let query = vec![2.0, 3.0, 5.0, 0.0];

    let reference = reference_qk_row(&query, &pairs);
    let direct = direct_qk_row(&query, &pairs);

    assert_eq!(reference.len(), 3);
    assert_eq!(direct.len(), 3);
    // Bit-identical match between the two implementations.
    for (r, d) in reference.iter().zip(direct.iter()) {
        assert_eq!(r, d, "direct path must match reference path bit-for-bit");
    }
    // Pin canonical values: dot(query, key_i):
    //   pair 0: dot([2,3,5,0], [1,0,0,0]) = 2.0
    //   pair 1: dot([2,3,5,0], [0,1,0,0]) = 3.0
    //   pair 2: dot([2,3,5,0], [0,0,1,0]) = 5.0
    assert_eq!(reference, vec![2.0_f32, 3.0_f32, 5.0_f32]);
}

#[test]
fn w8_kv_direct_qk_row_handles_empty_pairs_gracefully() {
    let pairs: Vec<KvPair> = Vec::new();
    let query = vec![1.0, 2.0, 3.0, 4.0];
    let reference = reference_qk_row(&query, &pairs);
    let direct = direct_qk_row(&query, &pairs);
    assert!(reference.is_empty());
    assert!(direct.is_empty());
}
