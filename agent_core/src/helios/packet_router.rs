//! Source:
//! - `docs/fusion/helios v6.2.md` 8-stage falsifier §4 — PacketRouter1bit
//!   dispatch P99 < 100µs on M2 Pro 16 GB.
//! - Shazeer et al., "Outrageously Large Neural Networks: The Sparsely-
//!   Gated Mixture-of-Experts Layer", arXiv:1701.06538, 2017 — sparse
//!   expert dispatch; the 1-bit form here is the binary specialization
//!   (2 experts) that Helios uses for control-flow routing rather than
//!   model-of-experts.
//! - Fedus et al., "Switch Transformer", arXiv:2101.03961, 2022 —
//!   top-1 routing (closest published analog to the 1-bit variant).
//!
//! # Helios stage 4 — PacketRouter1bit dispatch (CPU reference)
//!
//! Routes a batch of input values to one of two output lanes per
//! element. One bit of decision metadata per input. The dispatch is
//! the substrate-floor analog of a MoE gating network: each input
//! goes to `expert_0` (bit clear) or `expert_1` (bit set); the per-
//! lane outputs are tightly packed so downstream kernels see
//! contiguous data.
//!
//! ## Acceptance bar
//!
//! P99 dispatch latency < 100µs on M2 Pro 16 GB across a 100k-element
//! batch. Substrate floor here is the CPU reference + the dispatch
//! semantics; the Metal stub at `Epistemos/Shaders/PacketRouter1bit.metal`
//! lands alongside. Real P99 measurement needs the Swift falsifier
//! harness (Phase B.2 stage 4 acceptance harness, outside Terminal B
//! scope for the Swift side).

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct PacketRouterStats {
    pub total_inputs: usize,
    pub routed_to_lane_0: usize,
    pub routed_to_lane_1: usize,
}

impl PacketRouterStats {
    pub fn balance(&self) -> f32 {
        if self.total_inputs == 0 {
            return 0.0;
        }
        let smaller = self.routed_to_lane_0.min(self.routed_to_lane_1) as f32;
        smaller / (self.total_inputs as f32) * 2.0
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum PacketRouterError {
    /// `bits` had a different length than `inputs`.
    BitsLengthMismatch { inputs: usize, bits: usize },
}

#[derive(Clone, Debug, PartialEq)]
pub struct RoutingOutputs {
    pub lane_0: Vec<f32>,
    pub lane_1: Vec<f32>,
    pub original_indices_lane_0: Vec<u32>,
    pub original_indices_lane_1: Vec<u32>,
}

/// 1-bit dispatch: bit clear → `lane_0`, bit set → `lane_1`.
/// `bits.len()` must equal `inputs.len()`. Returns per-lane outputs
/// (packed contiguously) plus original-index lists so downstream
/// kernels can scatter results back into the original batch order.
pub fn route_1bit(
    inputs: &[f32],
    bits: &[bool],
) -> Result<(RoutingOutputs, PacketRouterStats), PacketRouterError> {
    if bits.len() != inputs.len() {
        return Err(PacketRouterError::BitsLengthMismatch {
            inputs: inputs.len(),
            bits: bits.len(),
        });
    }
    let mut lane_0 = Vec::with_capacity(inputs.len() / 2);
    let mut lane_1 = Vec::with_capacity(inputs.len() / 2);
    let mut idx_0 = Vec::with_capacity(inputs.len() / 2);
    let mut idx_1 = Vec::with_capacity(inputs.len() / 2);
    for (i, (&v, &b)) in inputs.iter().zip(bits.iter()).enumerate() {
        if b {
            lane_1.push(v);
            idx_1.push(i as u32);
        } else {
            lane_0.push(v);
            idx_0.push(i as u32);
        }
    }
    let stats = PacketRouterStats {
        total_inputs: inputs.len(),
        routed_to_lane_0: lane_0.len(),
        routed_to_lane_1: lane_1.len(),
    };
    Ok((
        RoutingOutputs {
            lane_0,
            lane_1,
            original_indices_lane_0: idx_0,
            original_indices_lane_1: idx_1,
        },
        stats,
    ))
}

/// Inverse of [`route_1bit`]: given the per-lane outputs + the
/// recorded original-index lists, reassemble the original-order batch.
/// Used by downstream kernels that want to merge expert outputs.
pub fn unroute_1bit(
    routed: &RoutingOutputs,
    total: usize,
) -> Result<Vec<f32>, PacketRouterError> {
    if routed.lane_0.len() != routed.original_indices_lane_0.len() {
        return Err(PacketRouterError::BitsLengthMismatch {
            inputs: routed.lane_0.len(),
            bits: routed.original_indices_lane_0.len(),
        });
    }
    if routed.lane_1.len() != routed.original_indices_lane_1.len() {
        return Err(PacketRouterError::BitsLengthMismatch {
            inputs: routed.lane_1.len(),
            bits: routed.original_indices_lane_1.len(),
        });
    }
    let mut out = vec![0.0_f32; total];
    for (i, &v) in routed.lane_0.iter().enumerate() {
        let dest = routed.original_indices_lane_0[i] as usize;
        if dest >= total {
            return Err(PacketRouterError::BitsLengthMismatch {
                inputs: total,
                bits: dest + 1,
            });
        }
        out[dest] = v;
    }
    for (i, &v) in routed.lane_1.iter().enumerate() {
        let dest = routed.original_indices_lane_1[i] as usize;
        if dest >= total {
            return Err(PacketRouterError::BitsLengthMismatch {
                inputs: total,
                bits: dest + 1,
            });
        }
        out[dest] = v;
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_input_routes_to_empty_lanes() {
        let (routed, stats) = route_1bit(&[], &[]).unwrap();
        assert!(routed.lane_0.is_empty());
        assert!(routed.lane_1.is_empty());
        assert_eq!(stats.total_inputs, 0);
        assert_eq!(stats.balance(), 0.0);
    }

    #[test]
    fn all_zero_bits_route_everything_to_lane_0() {
        let inputs = vec![1.0_f32, 2.0, 3.0];
        let bits = vec![false; 3];
        let (routed, stats) = route_1bit(&inputs, &bits).unwrap();
        assert_eq!(routed.lane_0, inputs);
        assert!(routed.lane_1.is_empty());
        assert_eq!(stats.routed_to_lane_0, 3);
        assert_eq!(stats.routed_to_lane_1, 0);
    }

    #[test]
    fn all_one_bits_route_everything_to_lane_1() {
        let inputs = vec![1.0_f32, 2.0, 3.0];
        let bits = vec![true; 3];
        let (routed, stats) = route_1bit(&inputs, &bits).unwrap();
        assert!(routed.lane_0.is_empty());
        assert_eq!(routed.lane_1, inputs);
        assert_eq!(stats.routed_to_lane_1, 3);
    }

    #[test]
    fn alternating_bits_split_evenly() {
        let inputs = vec![1.0_f32, 2.0, 3.0, 4.0];
        let bits = vec![false, true, false, true];
        let (routed, stats) = route_1bit(&inputs, &bits).unwrap();
        assert_eq!(routed.lane_0, vec![1.0, 3.0]);
        assert_eq!(routed.lane_1, vec![2.0, 4.0]);
        assert_eq!(stats.routed_to_lane_0, 2);
        assert_eq!(stats.routed_to_lane_1, 2);
        assert!((stats.balance() - 1.0).abs() < 1e-6);
    }

    #[test]
    fn bits_length_mismatch_errors() {
        let inputs = vec![1.0_f32, 2.0];
        let bits = vec![false; 3];
        let err = route_1bit(&inputs, &bits).unwrap_err();
        assert_eq!(
            err,
            PacketRouterError::BitsLengthMismatch { inputs: 2, bits: 3 }
        );
    }

    #[test]
    fn original_indices_preserve_source_position() {
        let inputs = vec![10.0_f32, 20.0, 30.0, 40.0, 50.0];
        let bits = vec![true, false, true, false, true];
        let (routed, _) = route_1bit(&inputs, &bits).unwrap();
        assert_eq!(routed.original_indices_lane_0, vec![1, 3]);
        assert_eq!(routed.original_indices_lane_1, vec![0, 2, 4]);
        assert_eq!(routed.lane_0, vec![20.0, 40.0]);
        assert_eq!(routed.lane_1, vec![10.0, 30.0, 50.0]);
    }

    #[test]
    fn unroute_round_trips_to_original_batch() {
        let inputs = vec![10.0_f32, 20.0, 30.0, 40.0, 50.0];
        let bits = vec![true, false, true, false, true];
        let (routed, _) = route_1bit(&inputs, &bits).unwrap();
        let merged = unroute_1bit(&routed, inputs.len()).unwrap();
        assert_eq!(merged, inputs);
    }

    #[test]
    fn balance_is_zero_for_fully_skewed_routing() {
        let inputs = vec![1.0_f32; 10];
        let bits = vec![false; 10];
        let (_, stats) = route_1bit(&inputs, &bits).unwrap();
        assert_eq!(stats.balance(), 0.0);
    }

    #[test]
    fn balance_is_one_for_perfectly_even_routing() {
        let inputs = vec![1.0_f32; 4];
        let bits = vec![false, true, false, true];
        let (_, stats) = route_1bit(&inputs, &bits).unwrap();
        assert!((stats.balance() - 1.0).abs() < 1e-6);
    }

    #[test]
    fn stats_round_trip_through_serde_json() {
        let s = PacketRouterStats {
            total_inputs: 4,
            routed_to_lane_0: 2,
            routed_to_lane_1: 2,
        };
        let json = serde_json::to_string(&s).unwrap();
        let back: PacketRouterStats = serde_json::from_str(&json).unwrap();
        assert_eq!(s, back);
    }

    #[test]
    fn large_batch_unroute_idempotent() {
        let inputs: Vec<f32> = (0..1000).map(|i| i as f32).collect();
        let bits: Vec<bool> = (0..1000).map(|i| i % 2 == 0).collect();
        let (routed, stats) = route_1bit(&inputs, &bits).unwrap();
        assert_eq!(stats.routed_to_lane_0, 500);
        assert_eq!(stats.routed_to_lane_1, 500);
        let merged = unroute_1bit(&routed, inputs.len()).unwrap();
        assert_eq!(merged, inputs);
    }
}
