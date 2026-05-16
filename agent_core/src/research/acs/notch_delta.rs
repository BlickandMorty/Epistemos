//! Source:
//! - Collier, J., Monk, N., Maini, P., Lewis, J., "Pattern formation by
//!   lateral inhibition with feedback: a mathematical model of
//!   Delta-Notch intercellular signalling", J. Theor. Biol. 183(4), 1996
//!   — the canonical mathematical model the ACS doctrine cites.
//! - `docs/fusion/jordan's research/kimis deep research/acs_meta_layer.md`
//!   §1.2 — "Homogeneous cells self-organize into precisely spaced
//!   functional roles through purely local interactions. No central
//!   planner assigns roles. The pattern emerges from inhibition."
//!
//! # J5 #2 — Notch-Delta lateral inhibition substrate (CPU reference)
//!
//! Per Collier et al. 1996 each cell `i` carries two concentrations:
//!
//! ```text
//! d N_i / dt = f(<D>_neighbors(i)) − N_i
//! d D_i / dt = g(N_i) − D_i
//! ```
//!
//! where `f(D) = D^k / (a + D^k)` (Hill-up, high neighbor Delta → high
//! Notch) and `g(N) = 1 / (1 + b · N^h)` (Hill-down, high own Notch →
//! suppress own Delta). `<D>_neighbors(i)` is the mean Delta across
//! cell `i`'s adjacency list. With symmetric initial conditions plus a
//! tiny seed perturbation the system converges to a bimodal pattern:
//! some cells fully on (high Notch, low Delta = "differentiated") and
//! some fully off (low Notch, high Delta = "primary fate"). That
//! pattern is the substrate-floor analog of ACS cell differentiation
//! into specialized agent roles.
//!
//! Substrate floor uses forward Euler integration. Hill exponents `k`
//! and `h` and the saturation constants `a` and `b` are exposed on the
//! [`NotchDeltaParams`] so callers can dial in stiffness. Defaults
//! (`k=h=2`, `a=b=0.01`) match Collier et al. Table 1.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct NotchDeltaCell {
    pub notch: f32,
    pub delta: f32,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct NotchDeltaParams {
    pub k: f32,
    pub h: f32,
    pub a: f32,
    pub b: f32,
}

impl Default for NotchDeltaParams {
    fn default() -> Self {
        Self { k: 2.0, h: 2.0, a: 0.01, b: 100.0 }
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct NotchDeltaNetwork {
    pub cells: Vec<NotchDeltaCell>,
    pub adjacency: Vec<Vec<usize>>,
    pub params: NotchDeltaParams,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum NotchDeltaError {
    EmptyNetwork,
    AdjacencyLengthMismatch { cells: usize, adjacency: usize },
    AdjacencyIndexOutOfRange { cell: usize, neighbor: usize, n: usize },
    NonPositiveDt { dt: f32 },
    NonPositiveHillParam { which: &'static str, value: f32 },
}

fn hill_up(x: f32, exponent: f32, sat: f32) -> f32 {
    let powed = x.powf(exponent);
    powed / (sat + powed)
}

fn hill_down(x: f32, exponent: f32, b: f32) -> f32 {
    1.0 / (1.0 + b * x.powf(exponent))
}

fn validate_network(net: &NotchDeltaNetwork) -> Result<(), NotchDeltaError> {
    if net.cells.is_empty() {
        return Err(NotchDeltaError::EmptyNetwork);
    }
    if net.adjacency.len() != net.cells.len() {
        return Err(NotchDeltaError::AdjacencyLengthMismatch {
            cells: net.cells.len(),
            adjacency: net.adjacency.len(),
        });
    }
    for (i, adj) in net.adjacency.iter().enumerate() {
        for &j in adj {
            if j >= net.cells.len() {
                return Err(NotchDeltaError::AdjacencyIndexOutOfRange {
                    cell: i,
                    neighbor: j,
                    n: net.cells.len(),
                });
            }
        }
    }
    if net.params.a <= 0.0 {
        return Err(NotchDeltaError::NonPositiveHillParam { which: "a", value: net.params.a });
    }
    if net.params.b <= 0.0 {
        return Err(NotchDeltaError::NonPositiveHillParam { which: "b", value: net.params.b });
    }
    Ok(())
}

/// One forward-Euler step of the Collier dynamics. Validates network
/// shape and Hill parameters; rejects non-positive `dt`.
pub fn notch_delta_step(net: &mut NotchDeltaNetwork, dt: f32) -> Result<(), NotchDeltaError> {
    validate_network(net)?;
    if dt <= 0.0 {
        return Err(NotchDeltaError::NonPositiveDt { dt });
    }
    let n = net.cells.len();
    let mut new_cells = Vec::with_capacity(n);
    for i in 0..n {
        let adj = &net.adjacency[i];
        let mean_delta = if adj.is_empty() {
            0.0
        } else {
            adj.iter().map(|&j| net.cells[j].delta).sum::<f32>() / (adj.len() as f32)
        };
        let dn = hill_up(mean_delta, net.params.k, net.params.a) - net.cells[i].notch;
        let dd = hill_down(net.cells[i].notch, net.params.h, net.params.b) - net.cells[i].delta;
        new_cells.push(NotchDeltaCell {
            notch: net.cells[i].notch + dt * dn,
            delta: net.cells[i].delta + dt * dd,
        });
    }
    net.cells = new_cells;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn pair_network(notch_a: f32, delta_a: f32, notch_b: f32, delta_b: f32) -> NotchDeltaNetwork {
        NotchDeltaNetwork {
            cells: vec![
                NotchDeltaCell { notch: notch_a, delta: delta_a },
                NotchDeltaCell { notch: notch_b, delta: delta_b },
            ],
            adjacency: vec![vec![1], vec![0]],
            params: NotchDeltaParams::default(),
        }
    }

    #[test]
    fn empty_network_rejected() {
        let mut net = NotchDeltaNetwork {
            cells: vec![],
            adjacency: vec![],
            params: NotchDeltaParams::default(),
        };
        let err = notch_delta_step(&mut net, 0.01).unwrap_err();
        assert_eq!(err, NotchDeltaError::EmptyNetwork);
    }

    #[test]
    fn adjacency_length_mismatch_errors() {
        let mut net = NotchDeltaNetwork {
            cells: vec![NotchDeltaCell { notch: 0.5, delta: 0.5 }],
            adjacency: vec![vec![], vec![]],
            params: NotchDeltaParams::default(),
        };
        let err = notch_delta_step(&mut net, 0.01).unwrap_err();
        assert_eq!(
            err,
            NotchDeltaError::AdjacencyLengthMismatch { cells: 1, adjacency: 2 }
        );
    }

    #[test]
    fn adjacency_index_out_of_range_errors() {
        let mut net = NotchDeltaNetwork {
            cells: vec![NotchDeltaCell { notch: 0.5, delta: 0.5 }],
            adjacency: vec![vec![5]],
            params: NotchDeltaParams::default(),
        };
        let err = notch_delta_step(&mut net, 0.01).unwrap_err();
        assert_eq!(
            err,
            NotchDeltaError::AdjacencyIndexOutOfRange { cell: 0, neighbor: 5, n: 1 }
        );
    }

    #[test]
    fn non_positive_dt_rejected() {
        let mut net = pair_network(0.5, 0.5, 0.5, 0.5);
        let err = notch_delta_step(&mut net, 0.0).unwrap_err();
        assert_eq!(err, NotchDeltaError::NonPositiveDt { dt: 0.0 });
    }

    #[test]
    fn non_positive_a_rejected() {
        let mut net = pair_network(0.5, 0.5, 0.5, 0.5);
        net.params.a = 0.0;
        let err = notch_delta_step(&mut net, 0.01).unwrap_err();
        assert_eq!(
            err,
            NotchDeltaError::NonPositiveHillParam { which: "a", value: 0.0 }
        );
    }

    #[test]
    fn non_positive_b_rejected() {
        let mut net = pair_network(0.5, 0.5, 0.5, 0.5);
        net.params.b = -1.0;
        let err = notch_delta_step(&mut net, 0.01).unwrap_err();
        assert_eq!(
            err,
            NotchDeltaError::NonPositiveHillParam { which: "b", value: -1.0 }
        );
    }

    #[test]
    fn perturbed_pair_diverges_into_bimodal_pattern() {
        let mut net = pair_network(0.5, 0.5, 0.5 + 0.01, 0.5 - 0.01);
        for _ in 0..5000 {
            notch_delta_step(&mut net, 0.01).unwrap();
        }
        let n0 = net.cells[0].notch;
        let n1 = net.cells[1].notch;
        let d0 = net.cells[0].delta;
        let d1 = net.cells[1].delta;
        assert!((n0 - n1).abs() > 0.5, "n0={} n1={}", n0, n1);
        assert!((d0 - d1).abs() > 0.5, "d0={} d1={}", d0, d1);
        let (high_notch_cell, low_notch_cell) = if n0 > n1 { (0, 1) } else { (1, 0) };
        assert!(net.cells[high_notch_cell].delta < net.cells[low_notch_cell].delta);
    }

    #[test]
    fn solo_cell_with_no_neighbors_notch_decays_to_zero_input_baseline() {
        let mut net = NotchDeltaNetwork {
            cells: vec![NotchDeltaCell { notch: 0.5, delta: 0.0 }],
            adjacency: vec![vec![]],
            params: NotchDeltaParams::default(),
        };
        for _ in 0..1000 {
            notch_delta_step(&mut net, 0.01).unwrap();
        }
        assert!(net.cells[0].notch < 0.01);
    }

    #[test]
    fn delta_high_when_notch_zero_per_hill_down() {
        let mut net = NotchDeltaNetwork {
            cells: vec![NotchDeltaCell { notch: 0.0, delta: 0.0 }],
            adjacency: vec![vec![]],
            params: NotchDeltaParams::default(),
        };
        for _ in 0..1000 {
            notch_delta_step(&mut net, 0.01).unwrap();
        }
        assert!(net.cells[0].delta > 0.99);
    }

    #[test]
    fn hill_up_saturates_with_high_input() {
        let h_low = hill_up(0.0, 2.0, 0.01);
        let h_high = hill_up(100.0, 2.0, 0.01);
        assert!(h_low < 0.01);
        assert!(h_high > 0.99);
    }

    #[test]
    fn hill_down_inverts() {
        let h_low = hill_down(0.0, 2.0, 100.0);
        let h_high = hill_down(100.0, 2.0, 100.0);
        assert!(h_low > 0.99);
        assert!(h_high < 0.01);
    }

    #[test]
    fn network_roundtrips_through_serde_json() {
        let net = pair_network(0.4, 0.6, 0.6, 0.4);
        let json = serde_json::to_string(&net).unwrap();
        let back: NotchDeltaNetwork = serde_json::from_str(&json).unwrap();
        assert_eq!(net, back);
    }

    #[test]
    fn default_params_match_collier_table_one() {
        let p = NotchDeltaParams::default();
        assert_eq!(p.k, 2.0);
        assert_eq!(p.h, 2.0);
        assert_eq!(p.a, 0.01);
        assert_eq!(p.b, 100.0);
    }
}
