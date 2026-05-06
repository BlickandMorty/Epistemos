//! HELIOS V5 E4 — UST-1.5 / WBO-7 Master Inequality.
//!
//! HELIOS-E4 guard
//!
//! (A) Pre-softmax: `‖Δz‖_∞ ≤ T_LWZ + T_K + T_R + T_TTR + T_SE +
//!      T_DAG + T_num`.
//! (B) Post-softmax: ½ contraction (Nair 2510.23012).
//!
//! T_S handled correctly per v2.1 patch.

use serde::{Deserialize, Serialize};

/// The 7-term envelope of the WBO-7 master inequality (E4).
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct Wbo7Envelope {
    pub t_lwz: f32,
    pub t_k: f32,
    pub t_r: f32,
    pub t_ttr: f32,
    pub t_se: f32,
    pub t_dag: f32,
    pub t_num: f32,
}

impl Wbo7Envelope {
    pub fn sum(&self) -> f32 {
        self.t_lwz + self.t_k + self.t_r + self.t_ttr + self.t_se + self.t_dag + self.t_num
    }
}

/// E4 invariant check: pre-softmax delta-z infinity-norm bound.
pub fn e4_pre_softmax_holds(envelope: &Wbo7Envelope, delta_z_inf_norm: f32) -> bool {
    delta_z_inf_norm <= envelope.sum()
}

/// E4 post-softmax half-contraction check (the post-softmax leg of
/// the master inequality).
pub fn e4_post_softmax_half_contraction(pre: f32, post: f32) -> bool {
    post <= 0.5 * pre
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn envelope_sum_is_seven_term_sum() {
        let e = Wbo7Envelope {
            t_lwz: 1.0,
            t_k: 1.0,
            t_r: 1.0,
            t_ttr: 1.0,
            t_se: 1.0,
            t_dag: 1.0,
            t_num: 1.0,
        };
        assert_eq!(e.sum(), 7.0);
    }

    #[test]
    fn pre_softmax_invariant_passes_within_envelope() {
        let e = Wbo7Envelope {
            t_lwz: 0.1,
            t_k: 0.1,
            t_r: 0.1,
            t_ttr: 0.1,
            t_se: 0.1,
            t_dag: 0.1,
            t_num: 0.1,
        };
        assert!(e4_pre_softmax_holds(&e, 0.5));
        assert!(!e4_pre_softmax_holds(&e, 0.71));
    }

    #[test]
    fn post_softmax_half_contraction_holds() {
        assert!(e4_post_softmax_half_contraction(1.0, 0.4));
        assert!(e4_post_softmax_half_contraction(1.0, 0.5));
        assert!(!e4_post_softmax_half_contraction(1.0, 0.51));
    }
}
