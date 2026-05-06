//! HELIOS V5 PCF-8 — Parameter Connectome Sheaf Consistency.
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §B:
//!
//! > "PCF-8 Parameter Connectome Sheaf Consistency — the parameter
//! >  connectome over component clusters carries a cellular sheaf
//! >  (Hansen-Ghrist, Bodnar et al.) whose global sections coincide
//! >  with consistent multi-component computations."
//!
//! Citations: Hansen-Ghrist 2019; Bodnar et al. arXiv:2202.04579
//! (Neural Sheaf Diffusion, NeurIPS 2022).

use serde::{Deserialize, Serialize};

/// One stalk of the parameter-connectome cellular sheaf — a finite
/// vector space attached to a component cluster vertex.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SheafStalk {
    pub vertex: u32,
    pub dim: u32,
}

/// One restriction map between adjacent stalks. Linear map
/// `R_{u→v}: F(u) → F(v)` represented as a flat row-major matrix.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RestrictionMap {
    pub source: u32,
    pub target: u32,
    pub matrix: Vec<f32>,
    pub source_dim: u32,
    pub target_dim: u32,
}

/// A parameter-connectome cellular sheaf. Vertices are component
/// clusters; edges carry restriction maps.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct ConnectomeSheaf {
    pub stalks: Vec<SheafStalk>,
    pub restrictions: Vec<RestrictionMap>,
}

impl ConnectomeSheaf {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn add_stalk(&mut self, stalk: SheafStalk) {
        self.stalks.push(stalk);
    }

    pub fn add_restriction(&mut self, restriction: RestrictionMap) {
        self.restrictions.push(restriction);
    }

    pub fn vertex_count(&self) -> usize {
        self.stalks.len()
    }

    pub fn edge_count(&self) -> usize {
        self.restrictions.len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_sheaf_has_no_stalks_or_restrictions() {
        let s = ConnectomeSheaf::new();
        assert_eq!(s.vertex_count(), 0);
        assert_eq!(s.edge_count(), 0);
    }

    #[test]
    fn sheaf_round_trip_through_json() {
        let mut s = ConnectomeSheaf::new();
        s.add_stalk(SheafStalk { vertex: 0, dim: 3 });
        s.add_stalk(SheafStalk { vertex: 1, dim: 4 });
        s.add_restriction(RestrictionMap {
            source: 0,
            target: 1,
            matrix: vec![0.0; 12], // 3 → 4 = 12 entries
            source_dim: 3,
            target_dim: 4,
        });
        let json = serde_json::to_string(&s).unwrap();
        let parsed: ConnectomeSheaf = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed, s);
    }
}
