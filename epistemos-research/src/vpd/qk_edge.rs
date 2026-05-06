//! HELIOS V5 PCF-2 — QK Edge Anchor.
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §B:
//!
//! > "PCF-2 QKEdgeAnchor (attention edge per W_QK^h decomposition)"
//!
//! Formula (Goodfire VPD May 5, 2026 verified):
//! ```text
//! W_QK^h = Σ_{c, c'} V_{Q,c} · (U_{Q,c}^h)^T · U_{K,c'}^h · V_{K,c'}^T
//! ```

use serde::{Deserialize, Serialize};

/// One symbolic edge between two parameter-component clusters
/// (source `c`, target `c'`) within a transformer attention head.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct QkEdgeAnchor {
    pub head_index: u32,
    pub source_component: u32,
    pub target_component: u32,
}

impl QkEdgeAnchor {
    pub fn new(head_index: u32, source_component: u32, target_component: u32) -> Self {
        Self {
            head_index,
            source_component,
            target_component,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn qk_edge_round_trip_through_json() {
        let e = QkEdgeAnchor::new(3, 100, 200);
        let json = serde_json::to_string(&e).unwrap();
        let parsed: QkEdgeAnchor = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed, e);
    }

    #[test]
    fn qk_edges_are_hashable_for_set_membership() {
        use std::collections::HashSet;
        let mut set = HashSet::new();
        set.insert(QkEdgeAnchor::new(0, 1, 2));
        set.insert(QkEdgeAnchor::new(0, 1, 2)); // duplicate
        assert_eq!(set.len(), 1);
    }
}
