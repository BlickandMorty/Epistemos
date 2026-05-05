//! Merkle root computation over the entire DAG store.
//!
//! Per `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` §1.3 +
//! §1.1's "merkle_root: root including all incoming edges' hashes."
//!
//! Construction: hash the sorted list of all node ids, then hash the
//! sorted list of all edge ids, then BLAKE3 the concatenation. Both
//! lists must be sorted ascending for cross-store reproducibility —
//! same content → same root regardless of insertion order.
//!
//! This is intentionally a flat root (not a true binary Merkle tree).
//! Phase 8.A's reproducibility test cares about "two stores with
//! identical content have identical roots" + "any change shifts the
//! root" — both achievable with the flat hash. A future Phase 8.F
//! `verify-replay` can swap in a tree if proof-of-inclusion ergonomics
//! become important.

use super::edge::EdgeId;
use super::node::{Hash, NodeId};

/// Compute the canonical Merkle root over a sorted list of node ids
/// + sorted list of edge ids. The caller must ensure the slices are
/// sorted ascending — `BTreeMap::keys()` gives this for free.
///
/// Returns `Hash::zero()` for an empty store, which is the canonical
/// "no content" root.
pub fn merkle_root_over(nodes: &[&NodeId], edges: &[&EdgeId]) -> Hash {
    if nodes.is_empty() && edges.is_empty() {
        return Hash::zero();
    }
    let mut hasher = blake3::Hasher::new();
    // Domain-separation prefix so a node id can't accidentally collide
    // with an edge id at the same byte position.
    hasher.update(b"epistemos-dag-merkle-v1\n");
    hasher.update(b"nodes:\n");
    for node_id in nodes {
        hasher.update(node_id.as_bytes());
    }
    hasher.update(b"edges:\n");
    for edge_id in edges {
        hasher.update(edge_id.as_bytes());
    }
    let digest = hasher.finalize();
    Hash::from_bytes(*digest.as_bytes())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn node_id(seed: u8) -> NodeId {
        NodeId::from_bytes([seed; 32])
    }

    fn edge_id(seed: u8) -> EdgeId {
        EdgeId::from_bytes([seed; 32])
    }

    #[test]
    fn empty_store_root_is_zero() {
        let r = merkle_root_over(&[], &[]);
        assert_eq!(r, Hash::zero());
    }

    #[test]
    fn root_is_deterministic_across_calls() {
        let nodes = [node_id(1), node_id(2), node_id(3)];
        let edges = [edge_id(10), edge_id(11)];
        let n_refs: Vec<&NodeId> = nodes.iter().collect();
        let e_refs: Vec<&EdgeId> = edges.iter().collect();
        let r1 = merkle_root_over(&n_refs, &e_refs);
        let r2 = merkle_root_over(&n_refs, &e_refs);
        assert_eq!(r1, r2);
    }

    #[test]
    fn root_changes_when_nodes_change() {
        let n1 = [node_id(1), node_id(2)];
        let n2 = [node_id(1), node_id(3)];
        let n1_refs: Vec<&NodeId> = n1.iter().collect();
        let n2_refs: Vec<&NodeId> = n2.iter().collect();
        let r1 = merkle_root_over(&n1_refs, &[]);
        let r2 = merkle_root_over(&n2_refs, &[]);
        assert_ne!(r1, r2);
    }

    #[test]
    fn root_changes_when_edges_change() {
        let nodes = [node_id(1)];
        let n_refs: Vec<&NodeId> = nodes.iter().collect();
        let r_no_edges = merkle_root_over(&n_refs, &[]);
        let edges = [edge_id(99)];
        let e_refs: Vec<&EdgeId> = edges.iter().collect();
        let r_with_edge = merkle_root_over(&n_refs, &e_refs);
        assert_ne!(r_no_edges, r_with_edge);
    }

    #[test]
    fn root_changes_when_node_id_swapped_with_edge_id_position() {
        // Domain separation: a node id at byte position N must not
        // collide with an edge id at byte position N. The "nodes:\n"
        // / "edges:\n" prefixes guarantee this.
        let same_bytes = [99u8; 32];
        let n = NodeId::from_bytes(same_bytes);
        let e = EdgeId::from_bytes(same_bytes);
        let r_node_only = merkle_root_over(&[&n], &[]);
        let r_edge_only = merkle_root_over(&[], &[&e]);
        assert_ne!(r_node_only, r_edge_only);
    }

    #[test]
    fn root_is_order_invariant_for_caller_who_sorts() {
        // The merkle root is order-DEPENDENT on the input slices —
        // this is intentional; the caller is responsible for sorting.
        // BTreeMap::keys() iteration is sorted, which is the canonical
        // production path.
        //
        // This test confirms the contract: same SORTED inputs produce
        // the same root.
        let mut nodes_a = [node_id(3), node_id(1), node_id(2)];
        nodes_a.sort();
        let n_refs: Vec<&NodeId> = nodes_a.iter().collect();
        let r1 = merkle_root_over(&n_refs, &[]);

        let mut nodes_b = [node_id(2), node_id(3), node_id(1)];
        nodes_b.sort();
        let n_refs2: Vec<&NodeId> = nodes_b.iter().collect();
        let r2 = merkle_root_over(&n_refs2, &[]);

        assert_eq!(r1, r2);
    }

    #[test]
    fn root_differs_for_unsorted_versus_sorted_inputs() {
        // Documents that the caller must sort. This test pins that
        // unsorted input produces a different root than sorted input
        // for the same set — so callers can't accidentally rely on
        // implicit sorting.
        let unsorted = [node_id(3), node_id(1), node_id(2)];
        let mut sorted = unsorted;
        sorted.sort();
        let unsorted_refs: Vec<&NodeId> = unsorted.iter().collect();
        let sorted_refs: Vec<&NodeId> = sorted.iter().collect();
        let r_unsorted = merkle_root_over(&unsorted_refs, &[]);
        let r_sorted = merkle_root_over(&sorted_refs, &[]);
        assert_ne!(r_unsorted, r_sorted);
    }
}
