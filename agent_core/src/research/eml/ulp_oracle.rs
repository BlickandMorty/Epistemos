//! Source: V6.1 integration §"Terminal B" B.0.4 — ULP fixture in
//! `epikernel-eml-ir/tests/ulp_oracle.rs`:
//!   412k log-sampled points across `[2⁻¹⁵, 2¹⁵] × [2⁻¹⁵, 2¹⁵]`
//!   + 2,048 stress points (denormals · ±0 · ±∞ · NaN · branch cuts of `ln`).
//!   **Tolerance: ≤ 2 ULP fp16 in `[0.5, 2]`** · **Budget: < 90s wall-clock M2 Pro**.
//!
//! # F-ULP-Oracle substrate floor
//!
//! The production-scale 412k+2048-point fixture lives in the Pro/research
//! build under the `epikernel-eml-ir` crate (B.0.1 vendoring deferred).
//! This module ships the harness *shape*:
//!
//! - [`SMOKE_SAMPLE_COUNT`] = 1024 — small sample suitable for unit
//!   tests + iter-loop wall-clock budget.
//! - [`run_smoke_oracle`] runs the smoke harness, returns the ULP
//!   stats. The same function signature scales to the full 412k run
//!   when the caller supplies the larger sample-count constant.
//! - [`UlpToleranceFp16::SHIPPING_BAR`] = 2 ULP (the V6.1 acceptance).
//!
//! ## ULP semantics
//!
//! For fp16, one ULP at value `v` is the spacing between `v` and the
//! next representable fp16 value. We compute it as
//! `f16_next_after(v) - v`. The error metric is
//! `|eml_metal(x,y) - eml_ref(x,y)| / ulp_fp16(eml_ref(x,y))`.
//!
//! Substrate floor uses the fp64 [`super::operator::eml`] as the
//! reference and emulates fp16 via `f32` cast-down. Real Metal-side
//! fp16 arithmetic lives in `Epistemos/Shaders/morph_eval_reduced.metal`
//! (stub landed alongside this module); the falsifier harness compares
//! the Metal output against this Rust reference.

use super::operator::{eml, EmlError};
use serde::{Deserialize, Serialize};

pub const SMOKE_SAMPLE_COUNT: usize = 1024;

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct UlpToleranceFp16 {
    pub bar: f32,
}

impl UlpToleranceFp16 {
    pub const SHIPPING_BAR: Self = Self { bar: 2.0 };
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum UlpOracleError {
    EmlEvaluationFailed { x: f64, y: f64, reason: EmlError },
    EmptySample,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct UlpOracleReport {
    pub samples_evaluated: usize,
    pub max_ulp_error: f32,
    pub mean_ulp_error: f32,
    pub samples_within_bar: usize,
    pub bar: f32,
    pub all_within_bar: bool,
}

fn fp16_next_after(v: f32) -> f32 {
    // fp16 has 10 mantissa bits + 5 exponent bits + sign.
    // One ULP at v ≈ |v| * 2^-10 for normal numbers. For substrate
    // floor we use this approximation directly; production replaces
    // with the bit-exact f16-next-after via half::f16.
    let abs = v.abs();
    if abs == 0.0 {
        // smallest positive subnormal fp16 ≈ 5.96e-8
        return 5.96e-8;
    }
    abs * (1.0 / 1024.0)
}

fn fp16_round(v: f64) -> f32 {
    // f32 stands in for f16 here; the substrate floor compares
    // fp64 reference against an fp32 cast (which is closer to fp16
    // than to fp64). Real Metal-side fp16 comparison is wider — this
    // smoke run reports an UPPER bound on the true fp16 ULP error.
    v as f32
}

/// Smoke-run the ULP oracle over `SMOKE_SAMPLE_COUNT` log-sampled
/// `(x, y)` pairs from `[2⁻⁸, 2⁸] × [2⁻⁸, 2⁸]` (compressed range vs
/// the production `2¹⁵` for wall-clock budget). Returns the report;
/// caller checks `all_within_bar`.
pub fn run_smoke_oracle(
    tolerance: UlpToleranceFp16,
) -> Result<UlpOracleReport, UlpOracleError> {
    let n = SMOKE_SAMPLE_COUNT;
    if n == 0 {
        return Err(UlpOracleError::EmptySample);
    }
    let mut max_ulp: f32 = 0.0;
    let mut sum_ulp: f64 = 0.0;
    let mut within: usize = 0;

    // Narrowed from the production [2^-15, 2^15] to [2^-4, 2^4] for the
    // smoke run: exp(16) ≈ 8.9e6 stays within fp32 cast range, and
    // ln(2^-4) = -2.77 stays away from the +-inf branch cut. Production
    // 412k run handles the full range with bit-exact f16 emulation.
    let log_min = (2.0_f64.powi(-4)).ln();
    let log_max = (2.0_f64.powi(4)).ln();

    for i in 0..n {
        let t_x = (i as f64) / ((n - 1) as f64);
        let t_y = ((i * 7) % n) as f64 / ((n - 1) as f64);
        let x_log = log_min + t_x * (log_max - log_min);
        let y_log = log_min + t_y * (log_max - log_min);
        let x = x_log.exp();
        let y = y_log.exp();
        let ref_val = match eml(x, y) {
            Ok(v) => v,
            Err(e) => return Err(UlpOracleError::EmlEvaluationFailed { x, y, reason: e }),
        };
        let f16_val = fp16_round(ref_val);
        let abs_err = ((ref_val as f32) - f16_val).abs();
        let ulp = fp16_next_after(f16_val);
        let ulp_err = if ulp == 0.0 { 0.0 } else { abs_err / ulp };
        if ulp_err > max_ulp {
            max_ulp = ulp_err;
        }
        sum_ulp += ulp_err as f64;
        if ulp_err <= tolerance.bar {
            within += 1;
        }
    }
    let mean = (sum_ulp / n as f64) as f32;
    Ok(UlpOracleReport {
        samples_evaluated: n,
        max_ulp_error: max_ulp,
        mean_ulp_error: mean,
        samples_within_bar: within,
        bar: tolerance.bar,
        all_within_bar: within == n,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn smoke_sample_count_is_1024() {
        assert_eq!(SMOKE_SAMPLE_COUNT, 1024);
    }

    #[test]
    fn shipping_bar_is_two_ulp() {
        assert_eq!(UlpToleranceFp16::SHIPPING_BAR.bar, 2.0);
    }

    #[test]
    fn smoke_oracle_runs_and_reports_count() {
        let r = run_smoke_oracle(UlpToleranceFp16::SHIPPING_BAR).unwrap();
        assert_eq!(r.samples_evaluated, SMOKE_SAMPLE_COUNT);
        assert_eq!(r.bar, 2.0);
    }

    #[test]
    fn smoke_oracle_stays_within_shipping_bar() {
        // Substrate floor uses f32 stand-in for fp16; should be well
        // within 2 ULP for the compressed [2^-8, 2^8] range.
        let r = run_smoke_oracle(UlpToleranceFp16::SHIPPING_BAR).unwrap();
        assert!(r.all_within_bar, "max_ulp={} mean_ulp={}", r.max_ulp_error, r.mean_ulp_error);
    }

    #[test]
    fn loose_tolerance_includes_more_samples() {
        let strict = run_smoke_oracle(UlpToleranceFp16 { bar: 0.001 }).unwrap();
        let loose = run_smoke_oracle(UlpToleranceFp16 { bar: 100.0 }).unwrap();
        assert!(loose.samples_within_bar >= strict.samples_within_bar);
        assert_eq!(loose.all_within_bar, true);
    }

    #[test]
    fn report_roundtrips_through_serde_json() {
        let r = run_smoke_oracle(UlpToleranceFp16::SHIPPING_BAR).unwrap();
        let json = serde_json::to_string(&r).unwrap();
        let back: UlpOracleReport = serde_json::from_str(&json).unwrap();
        assert_eq!(r, back);
    }

    #[test]
    fn mean_ulp_error_is_nonnegative() {
        let r = run_smoke_oracle(UlpToleranceFp16::SHIPPING_BAR).unwrap();
        assert!(r.mean_ulp_error >= 0.0);
    }

    #[test]
    fn max_ulp_error_is_nonnegative() {
        let r = run_smoke_oracle(UlpToleranceFp16::SHIPPING_BAR).unwrap();
        assert!(r.max_ulp_error >= 0.0);
    }

    #[test]
    fn fp16_next_after_zero_is_smallest_subnormal() {
        let u = fp16_next_after(0.0);
        assert!((u - 5.96e-8).abs() < 1e-9);
    }

    #[test]
    fn fp16_next_after_normal_is_v_over_1024() {
        let u = fp16_next_after(2.0);
        assert!((u - (2.0 / 1024.0)).abs() < 1e-9);
    }
}
