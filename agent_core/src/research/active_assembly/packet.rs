//! `Packet` + `PacketGraph` — synthetic packet primitives for the
//! F-ActiveAssembly-Minimal substrate-floor.
//!
//! Per F-ActiveAssembly falsifier §2.
//!
//! # Substrate-floor scope
//!
//! - N = 1024 packets per graph (sized in the harness, not enforced here).
//! - Each packet carries a 64-bit input pattern + 64-bit output pattern
//!   + a cost-units cost in 1..16.
//! - Edges: 1-4 predecessor packets per packet. DAG topology verified at
//!   construction.
//!
//! The graph implementation here is the substrate; the active-pull selector
//! that consumes it lands in a follow-up iter.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;

/// Opaque identifier for a packet within a graph. Wraps `usize` for fast
/// indexing.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub struct PacketId(pub usize);

/// A single packet in the synthetic graph.
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct Packet {
    pub id: PacketId,
    /// 64-bit "input pattern" — substrate-floor mock of the packet's
    /// activation signature.
    pub input_pattern: u64,
    /// 64-bit "output pattern" — substrate-floor mock of what this packet
    /// produces.
    pub output_pattern: u64,
    /// Cost units in `1..=16` (substrate-floor abstract cost).
    pub cost_units: u8,
    /// Predecessor packets this packet consumes from. Up to 4 entries by
    /// the falsifier §2 spec.
    pub predecessors: Vec<PacketId>,
}

impl Packet {
    pub fn new(
        id: PacketId,
        input_pattern: u64,
        output_pattern: u64,
        cost_units: u8,
        predecessors: Vec<PacketId>,
    ) -> Self {
        Self { id, input_pattern, output_pattern, cost_units, predecessors }
    }
}

/// Error surface for graph construction.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum PacketGraphError {
    /// Predecessor `pred` of packet `p` was not yet defined when `p` was
    /// added. Construct packets in topological order.
    UndefinedPredecessor { packet: PacketId, predecessor: PacketId },
    /// A packet's predecessor list referenced itself.
    SelfReference { packet: PacketId },
    /// A packet's predecessor count exceeded the falsifier-§2 max of 4.
    TooManyPredecessors { packet: PacketId, count: usize },
    /// The packet id `requested` was already used.
    DuplicateId { packet: PacketId },
    /// The packet's cost_units was outside `1..=16`.
    BadCost { packet: PacketId, cost: u8 },
}

/// DAG of packets. Construction enforces:
/// - packet ids are unique
/// - predecessor ids reference packets that already exist (topological add)
/// - no self-reference
/// - max 4 predecessors per packet
/// - cost_units in `1..=16`
#[derive(Clone, Debug, Default)]
pub struct PacketGraph {
    packets: Vec<Packet>,
    by_id: BTreeSet<PacketId>,
}

impl PacketGraph {
    pub fn new() -> Self {
        Self { packets: Vec::new(), by_id: BTreeSet::new() }
    }

    /// Add a packet. Returns `Err` if any of the graph invariants are
    /// violated.
    pub fn add(&mut self, packet: Packet) -> Result<(), PacketGraphError> {
        if !(1..=16).contains(&packet.cost_units) {
            return Err(PacketGraphError::BadCost { packet: packet.id, cost: packet.cost_units });
        }
        if self.by_id.contains(&packet.id) {
            return Err(PacketGraphError::DuplicateId { packet: packet.id });
        }
        if packet.predecessors.len() > 4 {
            return Err(PacketGraphError::TooManyPredecessors {
                packet: packet.id,
                count: packet.predecessors.len(),
            });
        }
        for pred in &packet.predecessors {
            if *pred == packet.id {
                return Err(PacketGraphError::SelfReference { packet: packet.id });
            }
            if !self.by_id.contains(pred) {
                return Err(PacketGraphError::UndefinedPredecessor {
                    packet: packet.id,
                    predecessor: *pred,
                });
            }
        }

        self.by_id.insert(packet.id);
        self.packets.push(packet);
        Ok(())
    }

    pub fn len(&self) -> usize {
        self.packets.len()
    }

    pub fn is_empty(&self) -> bool {
        self.packets.is_empty()
    }

    pub fn contains(&self, id: PacketId) -> bool {
        self.by_id.contains(&id)
    }

    pub fn get(&self, id: PacketId) -> Option<&Packet> {
        self.packets.iter().find(|p| p.id == id)
    }

    pub fn iter(&self) -> impl Iterator<Item = &Packet> {
        self.packets.iter()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn p(id: usize, preds: Vec<usize>) -> Packet {
        Packet::new(
            PacketId(id),
            (id as u64).wrapping_mul(0xDEAD_BEEF),
            (id as u64).wrapping_mul(0xC0FF_EE),
            (id % 16) as u8 + 1, // ensures 1..=16
            preds.into_iter().map(PacketId).collect(),
        )
    }

    #[test]
    fn empty_graph_has_no_packets() {
        let g = PacketGraph::new();
        assert!(g.is_empty());
        assert_eq!(g.len(), 0);
    }

    #[test]
    fn add_packet_topologically() {
        let mut g = PacketGraph::new();
        g.add(p(0, vec![])).expect("root packet must succeed");
        g.add(p(1, vec![0])).expect("predecessor 0 exists");
        g.add(p(2, vec![0, 1])).expect("predecessors 0+1 exist");
        assert_eq!(g.len(), 3);
        assert!(g.contains(PacketId(2)));
        assert_eq!(g.get(PacketId(1)).unwrap().predecessors, vec![PacketId(0)]);
    }

    #[test]
    fn undefined_predecessor_errors() {
        let mut g = PacketGraph::new();
        let err = g.add(p(1, vec![0])).unwrap_err();
        assert_eq!(
            err,
            PacketGraphError::UndefinedPredecessor { packet: PacketId(1), predecessor: PacketId(0) }
        );
    }

    #[test]
    fn self_reference_errors() {
        let mut g = PacketGraph::new();
        g.add(p(0, vec![])).unwrap();
        let err = g.add(Packet::new(PacketId(1), 0, 0, 1, vec![PacketId(1)])).unwrap_err();
        assert_eq!(err, PacketGraphError::SelfReference { packet: PacketId(1) });
    }

    #[test]
    fn duplicate_id_errors() {
        let mut g = PacketGraph::new();
        g.add(p(0, vec![])).unwrap();
        let err = g.add(p(0, vec![])).unwrap_err();
        assert_eq!(err, PacketGraphError::DuplicateId { packet: PacketId(0) });
    }

    #[test]
    fn too_many_predecessors_errors() {
        let mut g = PacketGraph::new();
        for i in 0..5 {
            g.add(p(i, vec![])).unwrap();
        }
        // 6th packet referencing 5 predecessors should fail (max 4).
        let err = g.add(p(5, vec![0, 1, 2, 3, 4])).unwrap_err();
        assert_eq!(err, PacketGraphError::TooManyPredecessors { packet: PacketId(5), count: 5 });
    }

    #[test]
    fn bad_cost_errors() {
        let mut g = PacketGraph::new();
        let bad = Packet::new(PacketId(0), 0, 0, 0, vec![]); // cost 0 — bad
        let err = g.add(bad).unwrap_err();
        assert_eq!(err, PacketGraphError::BadCost { packet: PacketId(0), cost: 0 });
        let bad = Packet::new(PacketId(0), 0, 0, 17, vec![]); // cost 17 — bad
        let err = g.add(bad).unwrap_err();
        assert_eq!(err, PacketGraphError::BadCost { packet: PacketId(0), cost: 17 });
    }

    #[test]
    fn iter_walks_in_insertion_order() {
        let mut g = PacketGraph::new();
        for i in 0..5 {
            g.add(p(i, if i == 0 { vec![] } else { vec![i - 1] })).unwrap();
        }
        let ids: Vec<usize> = g.iter().map(|p| p.id.0).collect();
        assert_eq!(ids, vec![0, 1, 2, 3, 4]);
    }
}
