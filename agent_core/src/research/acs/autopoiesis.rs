//! Source:
//! - Maturana, H., Varela, F., "Autopoiesis and Cognition", Reidel 1973
//!   — the canonical six criteria for an autopoietic system. Item 3
//!   (operational closure: "the production network is closed — A
//!   produces B, B produces C, C produces A") is the criterion this
//!   substrate floor checks.
//! - `docs/fusion/jordan's research/kimis deep research/acs_meta_layer.md`
//!   §1.3 "Autopoiesis — The System That Produces Itself" — restates the
//!   six criteria in computational terms.
//!
//! # J5 #3 — Autopoietic operational-closure check (CPU reference)
//!
//! A production network is a directed graph: an edge `(p, c)` means
//! "component p produces component c". Per Maturana-Varela, the system
//! is operationally closed when every component is part of some
//! production cycle — i.e. each node lives in a non-trivial strongly
//! connected component (SCC).
//!
//! Substrate floor uses Tarjan's classic SCC algorithm (Tarjan 1972) on
//! the production graph. The full six-criteria checker is NOT-STARTED
//! here — criteria 1 (boundary production), 4 (structural coupling),
//! 5 (self-reference), 6 (identity through change) need richer state
//! than a single directed graph captures. Criterion 2 (component
//! production) reduces to "every node has at least one incoming edge",
//! which falls out of the SCC check for free.
//!
//! Operational closure is criterion 3; this iter ships the verdict for
//! 3 alone. The full checker is iter 22 or later.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// One node in the production network. `id` is a stable string handle
/// the caller chooses (e.g. "boundary", "membrane", "metabolism").
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct ComponentId(pub String);

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProductionEdge {
    pub producer: ComponentId,
    pub produced: ComponentId,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ProductionNetwork {
    pub components: Vec<ComponentId>,
    pub edges: Vec<ProductionEdge>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum AutopoiesisError {
    /// A `ProductionEdge` referenced a `ComponentId` not in
    /// `components`. Caller bug, surface so it doesn't get treated as
    /// "no closure" silently.
    DanglingEdge,
    EmptyNetwork,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct OperationalClosureVerdict {
    /// True iff every component lives in a non-trivial SCC.
    pub closed: bool,
    /// Components NOT in any non-trivial cycle. Empty when `closed = true`.
    pub orphans: Vec<ComponentId>,
    /// Component-count of the largest SCC. `1` means every node is
    /// orphan; `components.len()` means full single-SCC closure.
    pub largest_scc_size: usize,
}

fn build_adjacency(net: &ProductionNetwork) -> Result<HashMap<usize, Vec<usize>>, AutopoiesisError> {
    let id_to_idx: HashMap<&ComponentId, usize> = net
        .components
        .iter()
        .enumerate()
        .map(|(i, c)| (c, i))
        .collect();
    let mut adj: HashMap<usize, Vec<usize>> =
        (0..net.components.len()).map(|i| (i, Vec::new())).collect();
    for e in &net.edges {
        let p = id_to_idx
            .get(&e.producer)
            .ok_or(AutopoiesisError::DanglingEdge)?;
        let c = id_to_idx
            .get(&e.produced)
            .ok_or(AutopoiesisError::DanglingEdge)?;
        adj.get_mut(p).unwrap().push(*c);
    }
    Ok(adj)
}

struct Tarjan<'a> {
    adj: &'a HashMap<usize, Vec<usize>>,
    index_counter: usize,
    index: Vec<Option<usize>>,
    lowlink: Vec<usize>,
    on_stack: Vec<bool>,
    stack: Vec<usize>,
    sccs: Vec<Vec<usize>>,
}

impl<'a> Tarjan<'a> {
    fn new(n: usize, adj: &'a HashMap<usize, Vec<usize>>) -> Self {
        Self {
            adj,
            index_counter: 0,
            index: vec![None; n],
            lowlink: vec![0; n],
            on_stack: vec![false; n],
            stack: Vec::new(),
            sccs: Vec::new(),
        }
    }

    fn strongconnect(&mut self, v: usize) {
        self.index[v] = Some(self.index_counter);
        self.lowlink[v] = self.index_counter;
        self.index_counter += 1;
        self.stack.push(v);
        self.on_stack[v] = true;

        let neighbors = self.adj.get(&v).cloned().unwrap_or_default();
        for w in neighbors {
            if self.index[w].is_none() {
                self.strongconnect(w);
                self.lowlink[v] = self.lowlink[v].min(self.lowlink[w]);
            } else if self.on_stack[w] {
                self.lowlink[v] = self.lowlink[v].min(self.index[w].unwrap());
            }
        }

        if Some(self.lowlink[v]) == self.index[v] {
            let mut component = Vec::new();
            while let Some(w) = self.stack.pop() {
                self.on_stack[w] = false;
                component.push(w);
                if w == v {
                    break;
                }
            }
            self.sccs.push(component);
        }
    }
}

/// Verdict on Maturana-Varela criterion 3 (operational closure).
pub fn check_operational_closure(
    net: &ProductionNetwork,
) -> Result<OperationalClosureVerdict, AutopoiesisError> {
    if net.components.is_empty() {
        return Err(AutopoiesisError::EmptyNetwork);
    }
    let adj = build_adjacency(net)?;
    let n = net.components.len();
    let mut t = Tarjan::new(n, &adj);
    for v in 0..n {
        if t.index[v].is_none() {
            t.strongconnect(v);
        }
    }

    let mut in_nontrivial: Vec<bool> = vec![false; n];
    let mut largest: usize = 1;
    for scc in &t.sccs {
        let size = scc.len();
        let is_nontrivial = size > 1
            || (size == 1 && {
                let v = scc[0];
                adj.get(&v).map(|out| out.contains(&v)).unwrap_or(false)
            });
        if is_nontrivial {
            for &v in scc {
                in_nontrivial[v] = true;
            }
        }
        if size > largest {
            largest = size;
        }
    }

    let orphans: Vec<ComponentId> = (0..n)
        .filter(|i| !in_nontrivial[*i])
        .map(|i| net.components[i].clone())
        .collect();
    let closed = orphans.is_empty();
    Ok(OperationalClosureVerdict {
        closed,
        orphans,
        largest_scc_size: largest,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn cid(s: &str) -> ComponentId {
        ComponentId(s.to_string())
    }

    fn edge(a: &str, b: &str) -> ProductionEdge {
        ProductionEdge { producer: cid(a), produced: cid(b) }
    }

    #[test]
    fn empty_network_errors() {
        let net = ProductionNetwork { components: vec![], edges: vec![] };
        let err = check_operational_closure(&net).unwrap_err();
        assert_eq!(err, AutopoiesisError::EmptyNetwork);
    }

    #[test]
    fn dangling_edge_errors() {
        let net = ProductionNetwork {
            components: vec![cid("a")],
            edges: vec![edge("a", "b")],
        };
        let err = check_operational_closure(&net).unwrap_err();
        assert_eq!(err, AutopoiesisError::DanglingEdge);
    }

    #[test]
    fn single_node_no_edges_is_orphan() {
        let net = ProductionNetwork {
            components: vec![cid("a")],
            edges: vec![],
        };
        let v = check_operational_closure(&net).unwrap();
        assert!(!v.closed);
        assert_eq!(v.orphans, vec![cid("a")]);
        assert_eq!(v.largest_scc_size, 1);
    }

    #[test]
    fn single_node_self_loop_is_closed() {
        let net = ProductionNetwork {
            components: vec![cid("a")],
            edges: vec![edge("a", "a")],
        };
        let v = check_operational_closure(&net).unwrap();
        assert!(v.closed);
        assert!(v.orphans.is_empty());
        assert_eq!(v.largest_scc_size, 1);
    }

    #[test]
    fn two_node_cycle_is_closed() {
        let net = ProductionNetwork {
            components: vec![cid("a"), cid("b")],
            edges: vec![edge("a", "b"), edge("b", "a")],
        };
        let v = check_operational_closure(&net).unwrap();
        assert!(v.closed);
        assert_eq!(v.largest_scc_size, 2);
    }

    #[test]
    fn three_node_cycle_is_closed() {
        let net = ProductionNetwork {
            components: vec![cid("a"), cid("b"), cid("c")],
            edges: vec![edge("a", "b"), edge("b", "c"), edge("c", "a")],
        };
        let v = check_operational_closure(&net).unwrap();
        assert!(v.closed);
        assert_eq!(v.largest_scc_size, 3);
    }

    #[test]
    fn linear_chain_is_not_closed() {
        let net = ProductionNetwork {
            components: vec![cid("a"), cid("b"), cid("c")],
            edges: vec![edge("a", "b"), edge("b", "c")],
        };
        let v = check_operational_closure(&net).unwrap();
        assert!(!v.closed);
        assert_eq!(v.orphans.len(), 3);
        assert_eq!(v.largest_scc_size, 1);
    }

    #[test]
    fn cycle_plus_orphan_reports_partial() {
        let net = ProductionNetwork {
            components: vec![cid("a"), cid("b"), cid("c")],
            edges: vec![edge("a", "b"), edge("b", "a")],
        };
        let v = check_operational_closure(&net).unwrap();
        assert!(!v.closed);
        assert_eq!(v.orphans, vec![cid("c")]);
        assert_eq!(v.largest_scc_size, 2);
    }

    #[test]
    fn two_disjoint_cycles_both_closed() {
        let net = ProductionNetwork {
            components: vec![cid("a"), cid("b"), cid("c"), cid("d")],
            edges: vec![
                edge("a", "b"),
                edge("b", "a"),
                edge("c", "d"),
                edge("d", "c"),
            ],
        };
        let v = check_operational_closure(&net).unwrap();
        assert!(v.closed);
        assert_eq!(v.largest_scc_size, 2);
    }

    #[test]
    fn maturana_six_components_full_closure() {
        let net = ProductionNetwork {
            components: vec![
                cid("boundary"),
                cid("metabolism"),
                cid("membrane"),
                cid("dna"),
                cid("rna"),
                cid("protein"),
            ],
            edges: vec![
                edge("dna", "rna"),
                edge("rna", "protein"),
                edge("protein", "metabolism"),
                edge("metabolism", "membrane"),
                edge("membrane", "boundary"),
                edge("boundary", "dna"),
            ],
        };
        let v = check_operational_closure(&net).unwrap();
        assert!(v.closed);
        assert_eq!(v.largest_scc_size, 6);
    }

    #[test]
    fn network_roundtrips_through_serde_json() {
        let net = ProductionNetwork {
            components: vec![cid("x"), cid("y")],
            edges: vec![edge("x", "y"), edge("y", "x")],
        };
        let json = serde_json::to_string(&net).unwrap();
        let back: ProductionNetwork = serde_json::from_str(&json).unwrap();
        assert_eq!(net, back);
    }

    #[test]
    fn single_node_with_outgoing_only_is_orphan() {
        let net = ProductionNetwork {
            components: vec![cid("a"), cid("b")],
            edges: vec![edge("a", "b")],
        };
        let v = check_operational_closure(&net).unwrap();
        assert!(!v.closed);
        assert_eq!(v.orphans.len(), 2);
    }

    #[test]
    fn dag_no_cycle_anywhere_is_not_closed() {
        let net = ProductionNetwork {
            components: vec![cid("a"), cid("b"), cid("c"), cid("d")],
            edges: vec![
                edge("a", "b"),
                edge("a", "c"),
                edge("b", "d"),
                edge("c", "d"),
            ],
        };
        let v = check_operational_closure(&net).unwrap();
        assert!(!v.closed);
        assert_eq!(v.largest_scc_size, 1);
    }
}
