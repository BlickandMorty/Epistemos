//! HELIOS V5 E2 — Ultrametric-Sheaf Gluing.
//!
//! HELIOS-E2 guard
//!
//! For finite patch graph G_q (≤128 nodes, ≤256 edges, stalk dim ≤8)
//! cellular sheaf F_q, locally compatible patch states are exactly
//! `Γ(G_q, F_q) = H⁰(G_q, F_q) = ker δ⁰`.

use serde::{Deserialize, Serialize};

/// Bound: at most 128 nodes per patch graph (per v5.2 §C).
pub const MAX_PATCH_NODES: usize = 128;
/// Bound: at most 256 edges per patch graph.
pub const MAX_PATCH_EDGES: usize = 256;
/// Bound: stalk dim ≤ 8.
pub const MAX_STALK_DIM: usize = 8;

/// One patch in the sheaf-gluing setup.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Patch {
    pub patch_id: u32,
    /// Local section value (a vector in the stalk's vector space).
    pub section: Vec<f32>,
}

impl Patch {
    pub fn new(patch_id: u32, section: Vec<f32>) -> Self {
        debug_assert!(section.len() <= MAX_STALK_DIM);
        Self { patch_id, section }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn patch_construction_respects_stalk_bound() {
        let p = Patch::new(0, vec![0.0; MAX_STALK_DIM]);
        assert_eq!(p.patch_id, 0);
        assert_eq!(p.section.len(), MAX_STALK_DIM);
    }
}
