//! HELIOS V5 E7 — Autogenous Kernel Identity.
//!
//! HELIOS-E7 guard
//!
//! For each template `T_i`, `c_W ≃_{α, K_i · 2 ULP} c_C` in Epi_ε.
//! ULP-bounded kernel-vs-controller equivalence. v2.1 patch:
//! equality in Epi_ε, not raw `Para(Lens(Smooth))`.

use serde::{Deserialize, Serialize};

/// Identity claim record for one template (kernel vs controller).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct AutogenousKernelClaim {
    pub template_id: String,
    pub alpha: f32,
    pub k_i: f32,
}

impl AutogenousKernelClaim {
    pub fn new(template_id: String, alpha: f32, k_i: f32) -> Self {
        Self {
            template_id,
            alpha,
            k_i,
        }
    }

    /// ULP bound for this template = `K_i · 2`.
    pub fn ulp_bound(&self) -> f32 {
        self.k_i * 2.0
    }
}

/// Verify `|c_W - c_C| ≤ K_i · 2 ULP` on a single output sample. Returns
/// true iff the claim holds for the sampled pair.
pub fn e7_holds_for_sample(claim: &AutogenousKernelClaim, c_w: f32, c_c: f32) -> bool {
    // Compute ULP distance approximately as bit difference; for f32
    // this is a crude bound but enough for E7's load-bearing
    // "within K_i · 2 ULP" sampling discipline.
    let diff_bits = (c_w.to_bits() as i64 - c_c.to_bits() as i64).unsigned_abs();
    (diff_bits as f32) <= claim.ulp_bound()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ulp_bound_is_2_times_k() {
        let c = AutogenousKernelClaim::new("t1".to_string(), 0.5, 3.0);
        assert!((c.ulp_bound() - 6.0).abs() < 1e-6);
    }

    #[test]
    fn equal_pair_passes_zero_ulp_bound() {
        let c = AutogenousKernelClaim::new("t1".to_string(), 0.5, 0.0);
        assert!(e7_holds_for_sample(&c, 1.5_f32, 1.5_f32));
    }

    #[test]
    fn far_pair_fails_tight_bound() {
        let c = AutogenousKernelClaim::new("t1".to_string(), 0.5, 0.0);
        // Two completely different f32s — bit distance is huge.
        assert!(!e7_holds_for_sample(&c, 0.0_f32, 1.0e30_f32));
    }
}
