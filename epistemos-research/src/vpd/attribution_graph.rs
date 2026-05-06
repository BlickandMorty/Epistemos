//! HELIOS V5 PCF-3 — ParamAttributionGraph.

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// Directed graph over parameter components. Edges carry attribution
/// weight in [0, 1]. Used as a visualization research artifact (Lane
/// 3 only).
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct ParamAttributionGraph {
    /// Outgoing edges by source component id: `src → vec of (dst, weight)`.
    pub edges: BTreeMap<u32, Vec<(u32, f32)>>,
}

impl ParamAttributionGraph {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn add_edge(&mut self, source: u32, dest: u32, weight: f32) {
        self.edges.entry(source).or_default().push((dest, weight));
    }

    pub fn outgoing(&self, source: u32) -> &[(u32, f32)] {
        self.edges.get(&source).map(Vec::as_slice).unwrap_or(&[])
    }

    pub fn node_count(&self) -> usize {
        let mut nodes = std::collections::BTreeSet::new();
        for (s, dsts) in &self.edges {
            nodes.insert(*s);
            for (d, _) in dsts {
                nodes.insert(*d);
            }
        }
        nodes.len()
    }

    pub fn edge_count(&self) -> usize {
        self.edges.values().map(Vec::len).sum()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_graph_has_zero_nodes_and_edges() {
        let g = ParamAttributionGraph::new();
        assert_eq!(g.node_count(), 0);
        assert_eq!(g.edge_count(), 0);
    }

    #[test]
    fn add_edge_increases_counts() {
        let mut g = ParamAttributionGraph::new();
        g.add_edge(1, 2, 0.5);
        g.add_edge(1, 3, 0.7);
        assert_eq!(g.edge_count(), 2);
        assert_eq!(g.node_count(), 3);
    }
}
