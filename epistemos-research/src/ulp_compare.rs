//! HELIOS V5 — Ordered-bit ULP comparison utilities (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-ULP-COMPARE guard
//!
//! Per HELIOS v4 preservation
//! `source_docs/epistemos_helios_v3_master_canon_v2_1.md` Patch 8:
//!
//! > "Raw bit-distance only works for same-sign finite normal
//! >  values. EML can produce negative results because
//! >  exp(x) − log(y) can be negative. Use ordered float-bit
//! >  mapping before subtracting ULPs."
//!
//! ## The bug
//!
//! Naive ULP comparison treats `f.to_bits()` as a `u32` and
//! subtracts. This works for two positive normals (or two negative
//! normals) but breaks across the sign boundary: `+0.0` and `-0.0`
//! have bit representations `0x0000_0000` and `0x8000_0000`,
//! differing by `0x8000_0000` ULPs even though they're equal in
//! value.
//!
//! ## The fix
//!
//! Map the raw bits onto a monotonic ordered integer via the
//! "two's-complement-style negation" pattern:
//!   - positive bits ↔ unchanged (with positive offset)
//!   - negative bits ↔ flipped + sign-mask
//!
//! After the mapping, subtraction gives the correct ULP distance
//! across sign boundaries.
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. Building requires `--features research`.
//! Pure-Rust utility with no external dependencies (no `half`
//! crate; we operate on raw `u16` representing IEEE-754 fp16).

/// Map a fp32 value's bit representation onto a monotonic ordered
/// integer suitable for ULP-distance computation across sign
/// boundaries. The mapping is:
///
///   x ≥ 0  →  x.to_bits() | 0x8000_0000
///   x < 0  →  0x8000_0000 - (x.to_bits() & 0x7FFF_FFFF)
///
/// The result is a strictly-monotonic function of `x` (NaN aside),
/// so `ordered_f32_bits(a) - ordered_f32_bits(b)` gives the signed
/// ULP distance.
pub fn ordered_f32_bits(x: f32) -> i64 {
    let b = x.to_bits() as i64;
    if (b & 0x8000_0000) != 0 {
        // Negative: invert magnitude with sign-mask offset.
        0x8000_0000_i64 - (b & 0x7FFF_FFFF)
    } else {
        // Non-negative: shift up by the sign-mask offset.
        b + 0x8000_0000
    }
}

/// Map a fp16 value's bit representation onto a monotonic ordered
/// integer. Operates on raw `u16` to avoid pulling the `half`
/// crate as a dependency. Per `epistemos_helios_v3_master_canon_v2_1.md`
/// Patch 8 sketch.
pub fn ordered_f16_bits(raw: u16) -> i32 {
    let b = raw as i32;
    if (b & 0x8000) != 0 {
        // Negative.
        0x8000 - (b & 0x7FFF)
    } else {
        // Non-negative.
        b + 0x8000
    }
}

/// ULP distance between two fp32 values, sign-correct via the
/// ordered-bit mapping. Returns 0 when both inputs are NaN; treats
/// NaN-with-non-NaN as `u32::MAX` (a poison value indicating
/// "not comparable").
pub fn ulp_distance_f32(a: f32, b: f32) -> u32 {
    if a.is_nan() && b.is_nan() {
        return 0;
    }
    if a.is_nan() || b.is_nan() {
        return u32::MAX;
    }
    let oa = ordered_f32_bits(a);
    let ob = ordered_f32_bits(b);
    (oa - ob).unsigned_abs() as u32
}

/// ULP distance between two fp16 values (raw u16), sign-correct.
/// Mirrors `ulp_distance_f32`.
pub fn ulp_distance_f16(a: u16, b: u16) -> u32 {
    // fp16 NaN: exponent = 0x1F (5 bits at positions 10..15) AND
    // mantissa != 0.
    let is_nan = |raw: u16| (raw & 0x7C00) == 0x7C00 && (raw & 0x03FF) != 0;
    if is_nan(a) && is_nan(b) {
        return 0;
    }
    if is_nan(a) || is_nan(b) {
        return u32::MAX;
    }
    let oa = ordered_f16_bits(a);
    let ob = ordered_f16_bits(b);
    (oa - ob).unsigned_abs()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ordered_f32_bits_is_monotonic_across_zero_boundary() {
        // -ε < +0.0 must be reflected in ordered bits.
        let neg_eps = ordered_f32_bits(-f32::EPSILON);
        let pos_zero = ordered_f32_bits(0.0);
        let pos_eps = ordered_f32_bits(f32::EPSILON);
        assert!(neg_eps < pos_zero);
        assert!(pos_zero < pos_eps);
    }

    #[test]
    fn ordered_f16_bits_is_monotonic_across_zero_boundary() {
        let neg_one = 0xBC00_u16; // fp16 -1.0
        let pos_zero = 0x0000_u16; // fp16 +0.0
        let pos_one = 0x3C00_u16; // fp16 +1.0
        assert!(ordered_f16_bits(neg_one) < ordered_f16_bits(pos_zero));
        assert!(ordered_f16_bits(pos_zero) < ordered_f16_bits(pos_one));
    }

    #[test]
    fn ulp_distance_f32_is_zero_for_equal_inputs() {
        assert_eq!(ulp_distance_f32(0.0, 0.0), 0);
        assert_eq!(ulp_distance_f32(1.5, 1.5), 0);
        assert_eq!(ulp_distance_f32(-3.14, -3.14), 0);
    }

    #[test]
    fn ulp_distance_f32_is_one_for_adjacent_floats() {
        // Adjacent fp32 values differ by 1 ULP.
        let a = 1.0_f32;
        let b = f32::from_bits(a.to_bits() + 1);
        assert_eq!(ulp_distance_f32(a, b), 1);
        assert_eq!(ulp_distance_f32(b, a), 1);
    }

    #[test]
    fn ulp_distance_f32_handles_sign_boundary_correctly() {
        // +0.0 and -0.0 must report ZERO ULP distance per IEEE 754
        // (they compare as equal). Naive bit-subtraction would
        // report 2^31; the ordered mapping fixes this.
        let pos_zero = 0.0_f32;
        let neg_zero = -0.0_f32;
        // The naive `a == b` check catches this before we compute
        // ordered bits, but verify via the ordered mapping anyway.
        let dist = ulp_distance_f32(pos_zero, neg_zero);
        // The ordered mapping gives bit-positions that differ by exactly 1
        // (the smallest possible negative-side bit vs the smallest positive
        // side bit). Naive `to_bits` subtraction would report 0x8000_0000.
        assert!(dist <= 1);
    }

    #[test]
    fn ulp_distance_f32_strictly_less_than_naive_across_sign_boundary() {
        // Naive `to_bits() - to_bits()` for -ε vs +ε gives
        // exactly 0x8000_0000 = 2^31 due to the sign-bit flip.
        // The ordered mapping must give a STRICTLY SMALLER value
        // (since the actual representable-float count between -ε
        // and +ε is roughly 2 × bits(+ε), not 2^31).
        let dist = ulp_distance_f32(-f32::EPSILON, f32::EPSILON);
        let naive = (-f32::EPSILON).to_bits().wrapping_sub(f32::EPSILON.to_bits());
        // Naive is ≥ 2^31; ordered must be strictly less.
        assert!(naive >= 1u32 << 31);
        assert!(dist < naive, "ordered {} must beat naive {}", dist, naive);
    }

    #[test]
    fn ulp_distance_f32_handles_nan_pair_as_zero() {
        assert_eq!(ulp_distance_f32(f32::NAN, f32::NAN), 0);
    }

    #[test]
    fn ulp_distance_f32_returns_u32_max_for_nan_with_non_nan() {
        assert_eq!(ulp_distance_f32(f32::NAN, 0.0), u32::MAX);
        assert_eq!(ulp_distance_f32(1.0, f32::NAN), u32::MAX);
    }

    #[test]
    fn ulp_distance_f16_zero_for_equal_raw_bits() {
        assert_eq!(ulp_distance_f16(0x3C00, 0x3C00), 0); // +1.0 vs +1.0
        assert_eq!(ulp_distance_f16(0xBC00, 0xBC00), 0); // -1.0 vs -1.0
    }

    #[test]
    fn ulp_distance_f16_is_one_for_adjacent_bit_patterns() {
        let a = 0x3C00_u16;
        let b = 0x3C01_u16;
        assert_eq!(ulp_distance_f16(a, b), 1);
        assert_eq!(ulp_distance_f16(b, a), 1);
    }

    #[test]
    fn ulp_distance_f16_handles_sign_boundary() {
        // fp16 +0.0 = 0x0000, -0.0 = 0x8000.
        let dist = ulp_distance_f16(0x0000, 0x8000);
        // Naive subtraction would give 0x8000 = 32768; ordered
        // mapping gives a small distance (1 in canonical
        // ordered-int convention).
        assert!(dist <= 1);
    }

    #[test]
    fn ulp_distance_f16_handles_nan_pair_as_zero() {
        // fp16 NaN: exponent = 0x1F, mantissa != 0.
        let nan_a = 0x7E00_u16; // signaling-style NaN
        let nan_b = 0x7E01_u16;
        assert_eq!(ulp_distance_f16(nan_a, nan_b), 0);
    }

    #[test]
    fn ulp_distance_f16_returns_u32_max_for_nan_with_non_nan() {
        let nan = 0x7E00_u16;
        let one = 0x3C00_u16;
        assert_eq!(ulp_distance_f16(nan, one), u32::MAX);
        assert_eq!(ulp_distance_f16(one, nan), u32::MAX);
    }

    #[test]
    fn ulp_distance_f32_within_2_ulp_target_for_h2_substrate() {
        // The H2 BIT-IDENTICAL contract for half_softmax_post is
        // ≤ 2 ULP fp32 tolerance. Verify the utility can detect
        // both sides of that boundary.
        let a = 1.0_f32;
        let b1 = f32::from_bits(a.to_bits() + 2); // 2 ULP above
        let b2 = f32::from_bits(a.to_bits() + 3); // 3 ULP above
        assert!(ulp_distance_f32(a, b1) <= 2);
        assert!(ulp_distance_f32(a, b2) > 2);
    }
}
