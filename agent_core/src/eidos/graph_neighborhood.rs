//! GraphNeighborhood retrieval mode — 1-hop adjacency expansion.
//!
//! Given a seed [`EidosDocumentId`] supplied as the query text, return the
//! seed's neighbors in the in-memory graph. The toy backend here is a
//! directed adjacency list; production wiring routes through the existing
//! cognitive DAG (`agent_core::cognitive_dag`) under a later W-row.
//!
//! ## Why 1-hop only for V0
//!
//! Multi-hop expansion is valuable but introduces deterministic-replay
//! pitfalls — the order of frontier expansion, dedup of paths, and cycle
//! handling all need careful spec. 1-hop is the smallest useful surface
//! that exercises the closed-citation contract without those decisions; the
//! prompt deck's deep-hardening phase upgrades this to 2-hop with explicit
//! ordering invariants.
//!
//! ## Chunk id shape
//!
//! Hits emit `source_id = "{neighbor_id}::graph::from::{seed_id}"`. The seed
//! is part of the citable token so the Brain Panel can render
//! "neighbor X retrieved because of seed Y" without a separate metadata
//! round-trip, and so a chat layer cannot smuggle a graph hit from one
//! seed under a different seed's provenance.

use std::collections::{BTreeMap, BTreeSet};

use super::retriever::EidosRetriever;
use super::types::{
    EidosChunkId, EidosContextPacket, EidosDocumentId, EidosHit, EidosIndexManifestId,
    EidosProvenance, EidosQuery, EidosRetrievalMode, EidosScoreComponents, EidosSourceKind,
};

/// In-memory directed adjacency list. `edges[u]` = neighbors directly
/// reachable from `u`.
#[derive(Clone, Debug)]
pub struct InMemoryGraphNeighborhood {
    manifest_id: EidosIndexManifestId,
    edges: BTreeMap<EidosDocumentId, BTreeSet<EidosDocumentId>>,
}

impl InMemoryGraphNeighborhood {
    pub fn new(manifest_id: EidosIndexManifestId) -> Self {
        Self {
            manifest_id,
            edges: BTreeMap::new(),
        }
    }

    /// Add a directed edge `from -> to`. Idempotent — re-adding the same
    /// edge is a no-op (BTreeSet handles dedup).
    pub fn add_edge(&mut self, from: EidosDocumentId, to: EidosDocumentId) {
        self.edges.entry(from).or_default().insert(to);
    }

    /// Add an undirected edge by inserting both directions. Convenience for
    /// "these two notes link to each other" wiring.
    pub fn add_undirected_edge(&mut self, a: EidosDocumentId, b: EidosDocumentId) {
        self.add_edge(a.clone(), b.clone());
        self.add_edge(b, a);
    }
}

impl EidosRetriever for InMemoryGraphNeighborhood {
    fn mode(&self) -> EidosRetrievalMode {
        EidosRetrievalMode::GraphNeighborhood
    }

    fn manifest_id(&self) -> &EidosIndexManifestId {
        &self.manifest_id
    }

    fn retrieve(
        &self,
        query: &EidosQuery,
        retrieved_at_unix_ms: u64,
    ) -> EidosContextPacket {
        if query.text.trim().is_empty() || query.top_k == 0 {
            return empty_packet(query, &self.manifest_id);
        }

        let seed = match EidosDocumentId::new(query.text.clone()) {
            Ok(id) => id,
            Err(_) => return empty_packet(query, &self.manifest_id),
        };

        let Some(neighbors) = self.edges.get(&seed) else {
            return empty_packet(query, &self.manifest_id);
        };

        let top_k = query.top_k as usize;
        // BTreeSet iteration is already sorted ascending — that IS our
        // deterministic order, no extra sort needed.
        let hits: Vec<EidosHit> = neighbors
            .iter()
            .take(top_k)
            .map(|n| {
                let chunk_id = EidosChunkId::new(format!(
                    "{}::graph::from::{}",
                    n.as_str(),
                    seed.as_str()
                ))
                .expect("non-empty document ids");
                EidosHit {
                    source_id: chunk_id,
                    document_id: n.clone(),
                    kind: EidosSourceKind::Graph,
                    span: None,
                    confidence: 1.0,
                    score: EidosScoreComponents {
                        lexical: 0.0,
                        semantic: 0.0,
                        recency: 0.0,
                        graph: 1.0,
                    },
                    provenance: EidosProvenance {
                        manifest_id: self.manifest_id.clone(),
                        mode: EidosRetrievalMode::GraphNeighborhood,
                        retrieved_at_unix_ms,
                    },
                }
            })
            .collect();

        EidosContextPacket {
            query: query.clone(),
            manifest_id: self.manifest_id.clone(),
            hits,
        }
    }
}

fn empty_packet(query: &EidosQuery, manifest: &EidosIndexManifestId) -> EidosContextPacket {
    EidosContextPacket {
        query: query.clone(),
        manifest_id: manifest.clone(),
        hits: vec![],
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::eidos::types::EidosCitation;

    fn manifest() -> EidosIndexManifestId {
        EidosIndexManifestId::new("graph-test-manifest").unwrap()
    }

    fn doc(id: &str) -> EidosDocumentId {
        EidosDocumentId::new(id).unwrap()
    }

    fn build() -> InMemoryGraphNeighborhood {
        let mut g = InMemoryGraphNeighborhood::new(manifest());
        g.add_edge(doc("hub"), doc("a"));
        g.add_edge(doc("hub"), doc("b"));
        g.add_edge(doc("hub"), doc("c"));
        g.add_edge(doc("a"), doc("a-child"));
        g
    }

    #[test]
    fn seed_neighbors_returned_in_sorted_order() {
        // Acceptance bar: "graph hit". Seeding from "hub" returns its
        // three neighbors as citable hits, deterministically ordered.
        let g = build();
        let q = EidosQuery::new("hub", EidosRetrievalMode::GraphNeighborhood, 16);
        let packet = g.retrieve(&q, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 3);
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert_eq!(
            ids,
            vec![
                "a::graph::from::hub",
                "b::graph::from::hub",
                "c::graph::from::hub",
            ]
        );
        for hit in &packet.hits {
            assert_eq!(hit.kind, EidosSourceKind::Graph);
            assert_eq!(hit.score.graph, 1.0);
        }
    }

    #[test]
    fn missing_seed_returns_empty_packet() {
        let g = build();
        let q = EidosQuery::new("not-in-graph", EidosRetrievalMode::GraphNeighborhood, 8);
        let packet = g.retrieve(&q, 1_700_000_000_000);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn seed_with_no_outbound_edges_returns_empty_packet() {
        let g = build();
        let q = EidosQuery::new("c", EidosRetrievalMode::GraphNeighborhood, 8);
        let packet = g.retrieve(&q, 1_700_000_000_000);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn empty_query_text_returns_empty_packet() {
        let g = build();
        let q = EidosQuery::new("", EidosRetrievalMode::GraphNeighborhood, 8);
        let packet = g.retrieve(&q, 1_700_000_000_000);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn whitespace_only_query_text_returns_empty_packet() {
        let mut g = InMemoryGraphNeighborhood::new(manifest());
        g.add_edge(doc("   "), doc("neighbor"));
        let q = EidosQuery::new("   ", EidosRetrievalMode::GraphNeighborhood, 8);
        let packet = g.retrieve(&q, 1_700_000_000_000);
        assert!(
            packet.hits.is_empty(),
            "whitespace-only text is not a stable graph seed id"
        );
    }

    #[test]
    fn top_k_truncates_neighborhood() {
        let g = build();
        let q = EidosQuery::new("hub", EidosRetrievalMode::GraphNeighborhood, 2);
        let packet = g.retrieve(&q, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 2);
        // Truncation preserves the sorted-ascending order, so "a" and "b"
        // survive over "c".
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert_eq!(
            ids,
            vec!["a::graph::from::hub", "b::graph::from::hub"]
        );
    }

    #[test]
    fn idempotent_edge_insertion() {
        let mut g = InMemoryGraphNeighborhood::new(manifest());
        g.add_edge(doc("u"), doc("v"));
        g.add_edge(doc("u"), doc("v"));
        g.add_edge(doc("u"), doc("v"));
        let q = EidosQuery::new("u", EidosRetrievalMode::GraphNeighborhood, 8);
        let packet = g.retrieve(&q, 0);
        assert_eq!(packet.hits.len(), 1);
    }

    #[test]
    fn undirected_edge_creates_both_directions() {
        let mut g = InMemoryGraphNeighborhood::new(manifest());
        g.add_undirected_edge(doc("u"), doc("v"));
        let q1 = EidosQuery::new("u", EidosRetrievalMode::GraphNeighborhood, 8);
        let q2 = EidosQuery::new("v", EidosRetrievalMode::GraphNeighborhood, 8);
        assert_eq!(g.retrieve(&q1, 0).hits.len(), 1);
        assert_eq!(g.retrieve(&q2, 0).hits.len(), 1);
    }

    #[test]
    fn closed_citation_contract_holds_through_graph_neighborhood() {
        let g = build();
        let q = EidosQuery::new("hub", EidosRetrievalMode::GraphNeighborhood, 8);
        let packet = g.retrieve(&q, 1_700_000_000_000);
        for hit in &packet.hits {
            let cite = EidosCitation {
                source_id: hit.source_id.clone(),
                manifest_id: packet.manifest_id.clone(),
            };
            assert_eq!(packet.validate_citation(&cite), Ok(()));
        }
        // A graph hit "from" a different seed is rejected — the seed
        // attribution is part of the closed citation universe.
        let smuggled = EidosCitation {
            source_id: EidosChunkId::new("a::graph::from::OTHER_SEED").unwrap(),
            manifest_id: packet.manifest_id.clone(),
        };
        assert!(packet.validate_citation(&smuggled).is_err());
    }

    #[test]
    fn replay_byte_equal_for_pinned_clock() {
        let a = build();
        let b = build();
        let q = EidosQuery::new("hub", EidosRetrievalMode::GraphNeighborhood, 8);
        let pa = a.retrieve(&q, 1_700_000_000_000);
        let pb = b.retrieve(&q, 1_700_000_000_000);
        assert_eq!(pa, pb);
    }

    #[test]
    fn retriever_advertises_graph_neighborhood_mode() {
        let g = InMemoryGraphNeighborhood::new(manifest());
        assert_eq!(g.mode(), EidosRetrievalMode::GraphNeighborhood);
        assert_eq!(g.manifest_id(), &manifest());
    }

    #[test]
    fn unicode_document_ids_round_trip() {
        let mut g = InMemoryGraphNeighborhood::new(manifest());
        g.add_edge(doc("中心-α"), doc("近邻-β"));
        let q = EidosQuery::new("中心-α", EidosRetrievalMode::GraphNeighborhood, 8);
        let packet = g.retrieve(&q, 0);
        assert_eq!(packet.hits.len(), 1);
        assert_eq!(
            packet.hits[0].source_id.as_str(),
            "近邻-β::graph::from::中心-α"
        );
    }

    #[test]
    fn self_loop_appears_as_own_neighbor() {
        // A self-loop is a legitimate cognitive-DAG edge (a claim that
        // refers back to itself, an Idea node tagged with itself). The
        // retriever must return d as its own neighbor when add_edge(d, d)
        // is the only edge, and the closed-citation contract must still
        // hold for the resulting source_id "d::graph::from::d".
        let mut g = InMemoryGraphNeighborhood::new(manifest());
        g.add_edge(doc("d"), doc("d"));
        let q = EidosQuery::new("d", EidosRetrievalMode::GraphNeighborhood, 8);
        let packet = g.retrieve(&q, 0);
        assert_eq!(packet.hits.len(), 1);
        assert_eq!(packet.hits[0].source_id.as_str(), "d::graph::from::d");

        let cite = EidosCitation {
            source_id: EidosChunkId::new("d::graph::from::d").unwrap(),
            manifest_id: packet.manifest_id.clone(),
        };
        assert_eq!(packet.validate_citation(&cite), Ok(()));
    }

    #[test]
    fn self_loop_among_other_neighbors_sorts_in_place() {
        // Strengthens the bare self-loop pin above with the mixed case:
        // seed has multiple outbound edges INCLUDING a self-loop. The
        // self-loop must sort alphabetically with the rest of the
        // neighbor ids (BTreeSet ordering — neighbor "d" lands between
        // "c" and "e") and carry the same provenance/score shape as
        // every other neighbor. Pinning the ordering + provenance
        // jointly catches a future special-case "skip if from == to" or
        // "self-loops emit graph score 0" regression.
        let mut g = InMemoryGraphNeighborhood::new(manifest());
        g.add_edge(doc("d"), doc("a"));
        g.add_edge(doc("d"), doc("c"));
        g.add_edge(doc("d"), doc("d")); // self-loop
        g.add_edge(doc("d"), doc("e"));
        let q = EidosQuery::new("d", EidosRetrievalMode::GraphNeighborhood, 16);
        let packet = g.retrieve(&q, 1_700_000_000_000);

        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert_eq!(
            ids,
            vec![
                "a::graph::from::d",
                "c::graph::from::d",
                "d::graph::from::d",
                "e::graph::from::d",
            ],
            "self-loop must sort in alphabetic position alongside other neighbors"
        );

        // Every hit (including the self-loop) carries the canonical
        // graph-mode shape: provenance.mode == GraphNeighborhood,
        // kind == Graph, score.graph == 1.0.
        for hit in &packet.hits {
            assert_eq!(hit.provenance.mode, EidosRetrievalMode::GraphNeighborhood);
            assert_eq!(hit.kind, EidosSourceKind::Graph);
            assert_eq!(hit.score.graph, 1.0);
        }

        // Closed-citation contract: every emitted id, including the
        // synthetic self-loop one, must validate.
        for hit in &packet.hits {
            let cite = EidosCitation {
                source_id: hit.source_id.clone(),
                manifest_id: packet.manifest_id.clone(),
            };
            assert_eq!(packet.validate_citation(&cite), Ok(()));
        }
    }
}
