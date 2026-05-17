#![cfg(feature = "research")]
//! Wave J7 Sherry 1.25-bit sparse ternary codec — integration harness.
//!
//! Source:
//! - `agent_core/src/research/sherry_lattice/sparse_ternary.rs` (substrate).
//! - Huang et al. "Sherry: Hardware-Efficient 1.25-Bit Ternary
//!   Quantization", arXiv:2601.07892, 2026 — 3:4 sparse ternary
//!   pattern (exactly one zero per 4-weight group → 3 ternary values +
//!   1 forced zero, ≈ 4.75 bits per 4-weight group ≈ 1.19 bits/weight
//!   ≈ "1.25-bit" on the doctrine-doc shelf).
//! - Phase B iter 59 substrate-floor.
//!
//! # Substrate-floor scope
//!
//! Round-trip encode/decode + smallest-abs slot picking + scale =
//! mean-of-abs invariants + non-finite-input error surface.

use agent_core::research::sherry_lattice::sparse_ternary::{
    decode_sherry_3_4, encode_sherry_3_4, quantization_error, Sherry34Block, SherryError,
    SHERRY_GROUP_SIZE,
};
use agent_core::research::ternary::trit::Trit;

#[test]
fn sherry_group_size_is_four() {
    assert_eq!(SHERRY_GROUP_SIZE, 4);
}

#[test]
fn encode_picks_smallest_abs_slot_as_zero() {
    let group = [3.0, 0.5, -2.0, 4.0]; // smallest |w| = 0.5 at index 1
    let block = encode_sherry_3_4(&group).unwrap();
    assert_eq!(block.zero_slot, 1);
    assert_eq!(block.signs[1], Trit::Zero);
}

#[test]
fn encode_assigns_correct_signs() {
    let group = [3.0, 0.5, -2.0, 4.0];
    let block = encode_sherry_3_4(&group).unwrap();
    // Slot 1 is zeroed. Other slots: 3.0 (Pos), -2.0 (Neg), 4.0 (Pos).
    assert_eq!(block.signs[0], Trit::Pos);
    assert_eq!(block.signs[2], Trit::Neg);
    assert_eq!(block.signs[3], Trit::Pos);
}

#[test]
fn encode_scale_is_mean_of_nonzero_abs() {
    let group = [3.0, 0.5, -2.0, 4.0];
    let block = encode_sherry_3_4(&group).unwrap();
    // mean(|3|, |-2|, |4|) = 9 / 3 = 3.0
    assert!((block.scale - 3.0).abs() < 1e-6);
}

#[test]
fn round_trip_decode_reconstructs_signs_and_scale() {
    let group = [3.0, 0.5, -2.0, 4.0];
    let block = encode_sherry_3_4(&group).unwrap();
    let decoded = decode_sherry_3_4(&block).unwrap();
    assert_eq!(decoded[1], 0.0, "zeroed slot reconstructs to 0.0");
    // Non-zero slots: sign × scale.
    assert!((decoded[0] - 3.0).abs() < 1e-6);
    assert!((decoded[2] + 3.0).abs() < 1e-6); // -3.0 (negative)
    assert!((decoded[3] - 3.0).abs() < 1e-6);
}

#[test]
fn non_finite_input_errors() {
    let bad = [1.0, f32::NAN, 2.0, 3.0];
    let err = encode_sherry_3_4(&bad).unwrap_err();
    assert!(matches!(err, SherryError::NonFiniteInput { index: 1, .. }));
}

#[test]
fn infinity_input_errors() {
    let bad = [1.0, 2.0, f32::INFINITY, 3.0];
    let err = encode_sherry_3_4(&bad).unwrap_err();
    assert!(matches!(err, SherryError::NonFiniteInput { index: 2, .. }));
}

#[test]
fn out_of_range_zero_slot_decode_errors() {
    let bad_block = Sherry34Block {
        zero_slot: 9,
        signs: [Trit::Pos; 4],
        scale: 1.0,
    };
    let err = decode_sherry_3_4(&bad_block).unwrap_err();
    assert_eq!(err, SherryError::ZeroSlotOutOfRange { zero_slot: 9 });
}

#[test]
fn zero_slot_not_zeroed_decode_errors() {
    // zero_slot says 2 but signs[2] is Pos — malformed.
    let malformed = Sherry34Block {
        zero_slot: 2,
        signs: [Trit::Pos, Trit::Pos, Trit::Pos, Trit::Pos],
        scale: 1.0,
    };
    let err = decode_sherry_3_4(&malformed).unwrap_err();
    assert!(matches!(err, SherryError::ZeroSlotNotZeroed { zero_slot: 2, actual: Trit::Pos }));
}

#[test]
fn round_trip_preserves_sparsity_invariant() {
    let group = [10.0, 0.1, -5.0, 20.0];
    let block = encode_sherry_3_4(&group).unwrap();
    let decoded = decode_sherry_3_4(&block).unwrap();
    let nonzero_count = decoded.iter().filter(|&&v| v != 0.0).count();
    assert_eq!(nonzero_count, 3, "exactly 3 non-zero values per 3:4 sparse pattern");
}

#[test]
fn quantization_error_sse_for_uniform_input() {
    // Uniform-magnitude input: all values 1.0; scale=1.0, error per slot=0.0
    // for non-zero slots; zero slot contributes (0 - 1.0)^2 = 1.0 to SSE.
    let group = [1.0, 1.0, 1.0, 1.0];
    let block = encode_sherry_3_4(&group).unwrap();
    let qe = quantization_error(&group, &block).expect("must succeed");
    // quantization_error returns SSE (sum of squared errors), per the
    // implementation. SSE = 1.0 (one zeroed slot × 1.0² + three correct slots).
    assert!((qe - 1.0).abs() < 1e-6, "SSE = 1.0 for one zeroed slot; got {}", qe);
}

#[test]
fn quantization_error_zero_for_all_zero_input() {
    // All-zero input: decoded matches exactly → SSE = 0.
    let group = [0.0_f32; SHERRY_GROUP_SIZE];
    let block = encode_sherry_3_4(&group).unwrap();
    let qe = quantization_error(&group, &block).unwrap();
    assert_eq!(qe, 0.0);
}

#[test]
fn block_serde_round_trip() {
    let group = [1.0, 2.0, -3.0, 0.1];
    let block = encode_sherry_3_4(&group).unwrap();
    let json = serde_json::to_string(&block).unwrap();
    let parsed: Sherry34Block = serde_json::from_str(&json).unwrap();
    assert_eq!(parsed, block);
}

#[test]
fn encode_with_negative_smallest_picks_it_as_zero() {
    let group = [5.0, -0.2, 3.0, -7.0]; // |w| smallest = 0.2 at index 1
    let block = encode_sherry_3_4(&group).unwrap();
    assert_eq!(block.zero_slot, 1);
    assert_eq!(block.signs[1], Trit::Zero);
}

#[test]
fn all_zero_input_picks_first_slot() {
    let group = [0.0; SHERRY_GROUP_SIZE];
    let block = encode_sherry_3_4(&group).unwrap();
    // First-min ties to slot 0; all slots are Zero (since they're all 0.0).
    assert_eq!(block.zero_slot, 0);
    for s in &block.signs {
        assert_eq!(*s, Trit::Zero);
    }
    assert_eq!(block.scale, 0.0);
}
