//! Phase 8.B — Resonance propagation across the DAG.
//!
//! Per `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` §2.5.
//!
//! "Each `Claim` node has a current truth value (Kleene K3: True / False
//! / Indeterminate). When a new `Evidence` node is added with a
//! `DerivesFrom` edge to the Claim, the gate re-evaluates. When a
//! `Contradicts` edge appears, both claims may flip to Unknown.
//! Propagation: when claim X flips, the gate walks
//! `Reverse(DerivesFrom)` from X — every claim whose evidence chain
//! *includes* X is re-evaluated. Cascading invalidation. Spreadsheet
//! for truth."
//!
//! Phase 8.B scope (this module):
//! - `TruthCache` — per-`NodeId` Kleene K3 truth values; the node
//!   store stays immutable (content-addressed) so truth lives here
//! - `evaluate_claim_truth(claim_id, store, cache)` — re-derives a
//!   single claim's truth from its inbound `DerivesFrom` (Evidence)
//!   + outbound `Contradicts` (sibling Claims)
//! - `propagate_truth_change(changed_id, store, cache)` — BFS along
//!   reverse `DerivesFrom` + `Contradicts` edges; recomputes truth
//!   for every dependent claim; returns the set of affected nodes
//!   in deterministic order
//! - `add_evidence_then_propagate` / `add_contradiction_then_propagate`
//!   — convenience wrappers that wire the common "insert edge → walk
//!   propagation" pattern into one call
//!
//! Determinism: every method walks edges in `BTreeMap` iteration order
//! (already sorted) + uses a `BTreeSet` for the visited frontier so
//! same-store + same-mutation always produces same affected list.
//! 1000-node stress test pins this.

use std::collections::{BTreeMap, BTreeSet, VecDeque};

use serde::{Deserialize, Serialize};

use crate::resonance::Truth;

use super::{
    edge::{EdgeKind, EdgeKindSelector},
    node::{NodeId, NodeKind},
    storage::{DagError, DagStore},
};

// ── TruthCache ────────────────────────────────────────────────────────────

/// Per-node Kleene K3 truth cache. Backed by a `BTreeMap` so iteration
/// is deterministic.
///
/// Default truth for a never-evaluated node is `Truth::Unknown` —
/// matches doctrine §4.1 invariant 3 ("absence of evidence is not
/// evidence of absence; default to Unknown").
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct TruthCache {
    values: BTreeMap<NodeId, Truth>,
}

impl TruthCache {
    pub fn new() -> Self {
        Self::default()
    }

    /// Read with `Unknown` default.
    pub fn get(&self, id: &NodeId) -> Truth {
        self.values.get(id).copied().unwrap_or(Truth::Unknown)
    }

    /// Set; returns the previous value (or `Unknown` if absent).
    pub fn set(&mut self, id: NodeId, value: Truth) -> Truth {
        self.values.insert(id, value).unwrap_or(Truth::Unknown)
    }

    pub fn len(&self) -> usize {
        self.values.len()
    }

    pub fn is_empty(&self) -> bool {
        self.values.is_empty()
    }

    /// Snapshot of (id, truth) pairs in sorted-id order. Used by
    /// audit + replay.
    pub fn snapshot(&self) -> Vec<(NodeId, Truth)> {
        self.values.iter().map(|(id, t)| (*id, *t)).collect()
    }
}

// ── Evaluation ────────────────────────────────────────────────────────────

/// Re-derive a claim's truth from its current edges + the truth cache.
///
/// Edge convention per doctrine §1.2: `DerivesFrom` edges go
/// **Claim → Evidence** (the claim derives from the evidence). To
/// find a claim's supporters, walk OUTBOUND DerivesFrom (edges
/// FROM the claim).
///
/// Algorithm:
/// 1. Walk the claim's outbound `DerivesFrom` edges to find what it
///    supports. An edge to `Evidence` is taken as `True` support;
///    an edge to another `Claim` reads that target's cached truth
///    (True → True support; Unknown / False → no support yet).
/// 2. Walk the claim's outbound + inbound `Contradicts` edges to find
///    sibling claims. If any sibling has cached truth `True`, this
///    claim flips to `Unknown` (mutual exclusion).
/// 3. Default: `Unknown`.
pub fn evaluate_claim_truth(
    claim_id: NodeId,
    store: &dyn DagStore,
    cache: &TruthCache,
) -> Result<Truth, DagError> {
    // OUTBOUND DerivesFrom: this claim derives FROM these targets.
    let supports = store.edges_from(claim_id, Some(EdgeKindSelector::DerivesFrom))?;
    let mut has_evidence_support = false;
    let mut has_claim_support_true = false;
    for edge in &supports {
        // Resolve the destination endpoint (what this claim derives from)
        if let Some(target) = store.get_node(edge.to)? {
            match &target.kind {
                NodeKind::Evidence { .. } => {
                    has_evidence_support = true;
                }
                NodeKind::Claim { .. } => {
                    if cache.get(&edge.to) == Truth::True {
                        has_claim_support_true = true;
                    }
                }
                _ => {
                    // Other target kinds don't contribute support; skip.
                }
            }
        }
    }

    // Resolve sibling Contradicts edges (both directions). A
    // contradiction is "active" when the sibling has any direct
    // evidence support (independent of cache state) OR the sibling's
    // cached truth is True. Active contradictions force this claim to
    // Unknown — symmetric semantics per doctrine §2.5 ("both claims
    // may flip to Unknown") so the BFS reaches a stable fixpoint.
    let mut contradicting_siblings: Vec<NodeId> = store
        .edges_from(claim_id, Some(EdgeKindSelector::Contradicts))?
        .iter()
        .map(|e| e.to)
        .collect();
    contradicting_siblings.extend(
        store
            .edges_to(claim_id, Some(EdgeKindSelector::Contradicts))?
            .iter()
            .map(|e| e.from),
    );
    let mut has_active_contradiction = false;
    for sib in &contradicting_siblings {
        if cache.get(sib) == Truth::True {
            has_active_contradiction = true;
            break;
        }
        // Sibling has independent evidence? Then this contradiction
        // is active even if the sibling's cache hasn't caught up.
        let sib_supports = store.edges_from(*sib, Some(EdgeKindSelector::DerivesFrom))?;
        for sup in &sib_supports {
            if let Some(target) = store.get_node(sup.to)? {
                if matches!(target.kind, NodeKind::Evidence { .. }) {
                    has_active_contradiction = true;
                    break;
                }
            }
        }
        if has_active_contradiction {
            break;
        }
    }

    // Resolve final truth
    let final_truth = if has_active_contradiction {
        // Mutual-exclusion: even if we have evidence, an active
        // contradiction floats us to Unknown until the user resolves.
        Truth::Unknown
    } else if has_evidence_support || has_claim_support_true {
        Truth::True
    } else {
        Truth::Unknown
    };
    Ok(final_truth)
}

// ── Propagation ───────────────────────────────────────────────────────────

/// BFS-walks reverse `DerivesFrom` (and Contradicts both directions)
/// from `changed_id`, recomputing truth for every dependent claim.
/// Commits cache updates on the way. Returns the affected node ids
/// in deterministic sorted order.
///
/// Algorithm (matches doctrine §2.5 sketch):
/// ```text
/// affected = {changed_id}
/// frontier = {changed_id}
/// while frontier non-empty:
///   node = frontier.pop_front()
///   for edge in edges_to(node, Some(DerivesFrom)):
///     dep = edge.from
///     new = recompute_truth(dep, store, cache)
///     if new != cache.get(dep):
///       cache.set(dep, new)
///       affected.insert(dep)
///       frontier.push_back(dep)
///   for edge in edges_from(node, Some(Contradicts)):
///     sib = edge.to
///     <same recompute / commit / push>
///   for edge in edges_to(node, Some(Contradicts)):
///     sib = edge.from
///     <same>
/// ```
pub fn propagate_truth_change(
    changed_id: NodeId,
    store: &dyn DagStore,
    cache: &mut TruthCache,
) -> Result<Vec<NodeId>, DagError> {
    let mut affected: BTreeSet<NodeId> = BTreeSet::new();
    affected.insert(changed_id);

    let mut frontier: VecDeque<NodeId> = VecDeque::new();
    frontier.push_back(changed_id);

    // Bound the walk to prevent runaway propagation in pathological
    // graphs. 100k nodes is conservative — well above the 1000-node
    // stress test target + a real PKM vault scale.
    const MAX_PROPAGATION_STEPS: usize = 100_000;
    let mut steps = 0usize;

    // Always evaluate the changed node itself first if it's a Claim.
    recompute_and_propagate(changed_id, store, cache, &mut affected, &mut frontier)?;

    while let Some(node) = frontier.pop_front() {
        if steps >= MAX_PROPAGATION_STEPS {
            break;
        }
        steps += 1;

        // Find dependents: claims whose chain INCLUDES `node` —
        // i.e. claims with a DerivesFrom edge pointing TO `node`.
        // Per doctrine §1.2 DerivesFrom is Claim → Target, so the
        // dependent is the source of an inbound DerivesFrom edge.
        let dependents_via_derives = store.edges_to(node, Some(EdgeKindSelector::DerivesFrom))?;
        for edge in &dependents_via_derives {
            let dep = edge.from;
            recompute_and_propagate(dep, store, cache, &mut affected, &mut frontier)?;
        }

        // Outbound Contradicts (we contradict X; if X just flipped,
        // we re-evaluate)
        let outbound_contradicts = store.edges_from(node, Some(EdgeKindSelector::Contradicts))?;
        for edge in &outbound_contradicts {
            let sib = edge.to;
            recompute_and_propagate(sib, store, cache, &mut affected, &mut frontier)?;
        }

        // Inbound Contradicts (X contradicts us; same)
        let inbound_contradicts = store.edges_to(node, Some(EdgeKindSelector::Contradicts))?;
        for edge in &inbound_contradicts {
            let sib = edge.from;
            recompute_and_propagate(sib, store, cache, &mut affected, &mut frontier)?;
        }
    }

    Ok(affected.into_iter().collect())
}

fn recompute_and_propagate(
    candidate: NodeId,
    store: &dyn DagStore,
    cache: &mut TruthCache,
    affected: &mut BTreeSet<NodeId>,
    frontier: &mut VecDeque<NodeId>,
) -> Result<(), DagError> {
    // Only propagate to Claim nodes (the truth-bearing kind).
    let node = match store.get_node(candidate)? {
        Some(n) => n,
        None => return Ok(()),
    };
    if !matches!(node.kind, NodeKind::Claim { .. }) {
        return Ok(());
    }
    let new = evaluate_claim_truth(candidate, store, cache)?;
    let old = cache.get(&candidate);
    if new != old {
        cache.set(candidate, new);
        if affected.insert(candidate) {
            frontier.push_back(candidate);
        }
    }
    Ok(())
}

// ── Convenience wrappers ──────────────────────────────────────────────────

/// "Insert evidence + propagate" — the canonical pattern for adding
/// new Evidence to the DAG. Inserts the evidence node + the
/// `DerivesFrom` edge **from the claim to the evidence** (per
/// doctrine §1.2: DerivesFrom = Source → Target, where the Claim
/// derives FROM the Evidence). Then propagates.
///
/// Returns the affected node ids (in sorted order).
pub fn add_evidence_then_propagate(
    evidence_node: super::node::Node,
    claim_id: NodeId,
    derives_strength: f32,
    capability_hash: super::node::Hash,
    store: &dyn DagStore,
    cache: &mut TruthCache,
) -> Result<Vec<NodeId>, DagError> {
    let evidence_id = store.put_node(evidence_node)?;
    let edge = super::edge::Edge::new(
        claim_id,
        evidence_id,
        EdgeKind::DerivesFrom {
            strength: derives_strength,
        },
        capability_hash,
    );
    store.put_edge(edge)?;
    // Re-evaluate the claim (it has a new outbound DerivesFrom)
    propagate_truth_change(claim_id, store, cache)
}

/// "Insert contradiction + propagate" — the canonical pattern for
/// asserting a Contradicts edge between two existing claims.
pub fn add_contradiction_then_propagate(
    claim_a: NodeId,
    claim_b: NodeId,
    tension: f32,
    capability_hash: super::node::Hash,
    store: &dyn DagStore,
    cache: &mut TruthCache,
) -> Result<Vec<NodeId>, DagError> {
    let edge = super::edge::Edge::new(
        claim_a,
        claim_b,
        EdgeKind::Contradicts { tension },
        capability_hash,
    );
    store.put_edge(edge)?;
    let mut affected = propagate_truth_change(claim_a, store, cache)?;
    let from_b = propagate_truth_change(claim_b, store, cache)?;
    for id in from_b {
        if !affected.contains(&id) {
            affected.push(id);
        }
    }
    affected.sort();
    Ok(affected)
}

#[cfg(test)]
mod tests {
    use super::super::edge::Edge;
    use super::super::node::{
        AuthorRef, ClaimScope, EvidenceBlob, EvidenceKind, Hash, MimeType, Node, NodeKind,
        SourceRef, Timestamp,
    };
    use super::super::storage::InMemoryDagStore;
    use super::*;

    fn cap() -> Hash {
        Hash::from_bytes([7u8; 32])
    }

    fn claim(prop: &str) -> Node {
        Node::new(NodeKind::Claim {
            proposition: prop.into(),
            scope: ClaimScope::Vault,
            source: SourceRef("test".into()),
        })
    }

    fn evidence(blob: &[u8]) -> Node {
        Node::new(NodeKind::Evidence {
            kind: EvidenceKind::Citation,
            payload: EvidenceBlob(blob.to_vec()),
            captured_at: Timestamp(1000),
        })
    }

    fn note(body: &str) -> Node {
        Node::new(NodeKind::Note {
            body: body.into(),
            author: AuthorRef("test".into()),
            mime: MimeType("text/markdown".into()),
        })
    }

    #[test]
    fn truth_cache_default_is_unknown() {
        let cache = TruthCache::new();
        let id = claim("X").id;
        assert_eq!(cache.get(&id), Truth::Unknown);
    }

    #[test]
    fn truth_cache_get_after_set_round_trips() {
        let mut cache = TruthCache::new();
        let id = claim("X").id;
        let prior = cache.set(id, Truth::True);
        assert_eq!(prior, Truth::Unknown);
        assert_eq!(cache.get(&id), Truth::True);
        let prior2 = cache.set(id, Truth::False);
        assert_eq!(prior2, Truth::True);
        assert_eq!(cache.get(&id), Truth::False);
    }

    #[test]
    fn evaluate_unknown_for_lone_claim_with_no_evidence() {
        let store = InMemoryDagStore::new();
        let c = claim("alone");
        store.put_node(c.clone()).unwrap();
        let cache = TruthCache::new();
        let t = evaluate_claim_truth(c.id, &store, &cache).unwrap();
        assert_eq!(t, Truth::Unknown);
    }

    #[test]
    fn evaluate_true_for_claim_with_one_evidence() {
        let store = InMemoryDagStore::new();
        let c = claim("supported");
        let e = evidence(b"witness");
        store.put_node(c.clone()).unwrap();
        store.put_node(e.clone()).unwrap();
        // Claim → Evidence (claim derives from evidence) per doctrine §1.2
        store
            .put_edge(Edge::new(
                c.id,
                e.id,
                EdgeKind::DerivesFrom { strength: 0.9 },
                cap(),
            ))
            .unwrap();
        let cache = TruthCache::new();
        let t = evaluate_claim_truth(c.id, &store, &cache).unwrap();
        assert_eq!(t, Truth::True);
    }

    #[test]
    fn evaluate_unknown_when_contradicted_by_true_sibling() {
        let store = InMemoryDagStore::new();
        let c1 = claim("X");
        let c2 = claim("not X");
        let e1 = evidence(b"e1");
        let e2 = evidence(b"e2");
        for n in [&c1, &c2, &e1, &e2] {
            store.put_node(n.clone()).unwrap();
        }
        // Claim → Evidence per doctrine §1.2
        store
            .put_edge(Edge::new(
                c1.id,
                e1.id,
                EdgeKind::DerivesFrom { strength: 0.9 },
                cap(),
            ))
            .unwrap();
        store
            .put_edge(Edge::new(
                c2.id,
                e2.id,
                EdgeKind::DerivesFrom { strength: 0.9 },
                cap(),
            ))
            .unwrap();
        store
            .put_edge(Edge::new(
                c1.id,
                c2.id,
                EdgeKind::Contradicts { tension: 0.9 },
                cap(),
            ))
            .unwrap();
        // Cache c2 as True; c1's evaluation should see contradiction
        let mut cache = TruthCache::new();
        cache.set(c2.id, Truth::True);
        let t1 = evaluate_claim_truth(c1.id, &store, &cache).unwrap();
        assert_eq!(t1, Truth::Unknown);
    }

    #[test]
    fn propagate_walks_reverse_derives_chain() {
        // c2 → c1 → e1: c2 derives from c1, c1 derives from e1.
        // Per doctrine §1.2 DerivesFrom = Source → Target. Edges:
        //   c1 → e1 (DerivesFrom)
        //   c2 → c1 (DerivesFrom)
        // Propagating from c1 should evaluate c1 (True via e1) then
        // walk inbound DerivesFrom (find c2 → c1), re-evaluate c2.
        let store = InMemoryDagStore::new();
        let c1 = claim("c1");
        let c2 = claim("c2");
        let e1 = evidence(b"witness");
        for n in [&c1, &c2, &e1] {
            store.put_node(n.clone()).unwrap();
        }
        // c1 → e1 (c1 derives from e1)
        store
            .put_edge(Edge::new(
                c1.id,
                e1.id,
                EdgeKind::DerivesFrom { strength: 0.9 },
                cap(),
            ))
            .unwrap();
        // c2 → c1 (c2 derives from c1)
        store
            .put_edge(Edge::new(
                c2.id,
                c1.id,
                EdgeKind::DerivesFrom { strength: 0.7 },
                cap(),
            ))
            .unwrap();
        let mut cache = TruthCache::new();
        let affected = propagate_truth_change(c1.id, &store, &mut cache).unwrap();
        assert_eq!(cache.get(&c1.id), Truth::True);
        assert_eq!(cache.get(&c2.id), Truth::True);
        assert!(affected.contains(&c1.id));
        assert!(affected.contains(&c2.id));
    }

    #[test]
    fn propagate_returns_sorted_affected_ids() {
        let store = InMemoryDagStore::new();
        let claims: Vec<Node> = (0..5).map(|i| claim(&format!("c{}", i))).collect();
        for c in &claims {
            store.put_node(c.clone()).unwrap();
        }
        // Chain: c4 derives from c3 derives from c2 derives from c1
        // derives from c0 derives from evidence. c0 is the leaf
        // toward the evidence root.
        for i in 0..4 {
            // c[i+1] → c[i] (each upper claim derives from lower)
            store
                .put_edge(Edge::new(
                    claims[i + 1].id,
                    claims[i].id,
                    EdgeKind::DerivesFrom { strength: 0.8 },
                    cap(),
                ))
                .unwrap();
        }
        // c0 derives from evidence
        let e = evidence(b"root");
        store.put_node(e.clone()).unwrap();
        store
            .put_edge(Edge::new(
                claims[0].id,
                e.id,
                EdgeKind::DerivesFrom { strength: 0.9 },
                cap(),
            ))
            .unwrap();
        let mut cache = TruthCache::new();
        let affected = propagate_truth_change(claims[0].id, &store, &mut cache).unwrap();
        // Affected ids must be in sorted-ascending order (BTreeSet
        // iteration). The exact set is verified separately by checking
        // every claim's truth.
        let mut sorted = affected.clone();
        sorted.sort();
        assert_eq!(affected, sorted, "affected list must be sorted");
        // All 5 claims should be True
        for c in &claims {
            assert_eq!(
                cache.get(&c.id),
                Truth::True,
                "claim {} truth",
                c.id.to_hex()
            );
        }
    }

    #[test]
    fn add_evidence_then_propagate_helper_works() {
        let store = InMemoryDagStore::new();
        let c = claim("h");
        store.put_node(c.clone()).unwrap();
        let mut cache = TruthCache::new();
        let affected =
            add_evidence_then_propagate(evidence(b"new"), c.id, 0.8, cap(), &store, &mut cache)
                .unwrap();
        assert_eq!(cache.get(&c.id), Truth::True);
        assert!(affected.contains(&c.id));
    }

    #[test]
    fn add_contradiction_helper_flips_caches() {
        let store = InMemoryDagStore::new();
        let c1 = claim("a");
        let c2 = claim("b");
        let e1 = evidence(b"e1");
        let e2 = evidence(b"e2");
        for n in [&c1, &c2, &e1, &e2] {
            store.put_node(n.clone()).unwrap();
        }
        // Both claims have independent evidence — necessary for the
        // contradiction to be "active" per the symmetric semantics
        // (a sibling without its own evidence isn't a real
        // contradiction; just an unsupported assertion).
        store
            .put_edge(Edge::new(
                c1.id,
                e1.id,
                EdgeKind::DerivesFrom { strength: 0.9 },
                cap(),
            ))
            .unwrap();
        store
            .put_edge(Edge::new(
                c2.id,
                e2.id,
                EdgeKind::DerivesFrom { strength: 0.9 },
                cap(),
            ))
            .unwrap();
        let mut cache = TruthCache::new();
        // Propagate both to True
        propagate_truth_change(c1.id, &store, &mut cache).unwrap();
        propagate_truth_change(c2.id, &store, &mut cache).unwrap();
        assert_eq!(cache.get(&c1.id), Truth::True);
        assert_eq!(cache.get(&c2.id), Truth::True);
        // Add the contradiction
        let affected =
            add_contradiction_then_propagate(c1.id, c2.id, 0.9, cap(), &store, &mut cache).unwrap();
        // Both claims should land at Unknown (mutual exclusion;
        // both have evidence and contradict, so neither can be True
        // without user resolution)
        assert_eq!(cache.get(&c1.id), Truth::Unknown);
        assert_eq!(cache.get(&c2.id), Truth::Unknown);
        assert!(affected.contains(&c1.id));
        assert!(affected.contains(&c2.id));
    }

    #[test]
    fn propagation_skips_non_claim_nodes() {
        // A Note node should never get a Truth value via propagation;
        // only Claim nodes do.
        let store = InMemoryDagStore::new();
        let n = note("this is a note");
        let c = claim("c");
        let e = evidence(b"e");
        for n in [&n, &c, &e] {
            store.put_node(n.clone()).unwrap();
        }
        // c → e per doctrine §1.2
        store
            .put_edge(Edge::new(
                c.id,
                e.id,
                EdgeKind::DerivesFrom { strength: 0.9 },
                cap(),
            ))
            .unwrap();
        // Note "annotates" the claim
        store
            .put_edge(Edge::new(
                c.id,
                n.id,
                EdgeKind::AnnotatedBy {
                    kind: super::super::edge::AnnotationKind::Comment,
                },
                cap(),
            ))
            .unwrap();
        let mut cache = TruthCache::new();
        propagate_truth_change(c.id, &store, &mut cache).unwrap();
        // Claim is True; Note remains Unknown (and is NOT in affected
        // list either since AnnotatedBy isn't walked)
        assert_eq!(cache.get(&c.id), Truth::True);
        assert_eq!(cache.get(&n.id), Truth::Unknown);
    }

    #[test]
    fn evidence_only_supports_via_outbound_derives_from_edge() {
        // Sanity: evaluate_claim_truth must look at edges_FROM claim
        // (Claim → Evidence per doctrine §1.2), not edges_TO claim.
        // Reversing the edge direction must NOT yield True.
        let store = InMemoryDagStore::new();
        let c = claim("c");
        let e = evidence(b"e");
        store.put_node(c.clone()).unwrap();
        store.put_node(e.clone()).unwrap();
        // WRONG direction: Evidence → Claim (treats evidence as source)
        store
            .put_edge(Edge::new(
                e.id,
                c.id,
                EdgeKind::DerivesFrom { strength: 0.9 },
                cap(),
            ))
            .unwrap();
        let cache = TruthCache::new();
        let t = evaluate_claim_truth(c.id, &store, &cache).unwrap();
        assert_eq!(
            t,
            Truth::Unknown,
            "Evidence → Claim is not the canonical direction"
        );
    }

    #[test]
    fn one_thousand_node_stress_test_propagates_in_bounded_time() {
        // Doctrine §8 Phase 8.B test target: "truth flip propagation
        // across 1000-node test DAGs"
        let store = InMemoryDagStore::new();
        let claims: Vec<Node> = (0..1000).map(|i| claim(&format!("c{}", i))).collect();
        for c in &claims {
            store.put_node(c.clone()).unwrap();
        }
        // Chain per doctrine §1.2 direction: c[i+1] → c[i].
        // c[0] is the leaf; c[999] is the root that derives from c[998]
        // ... down to c[0] which derives from evidence.
        for i in 0..999 {
            store
                .put_edge(Edge::new(
                    claims[i + 1].id,
                    claims[i].id,
                    EdgeKind::DerivesFrom { strength: 0.9 },
                    cap(),
                ))
                .unwrap();
        }
        let e = evidence(b"root");
        store.put_node(e.clone()).unwrap();
        store
            .put_edge(Edge::new(
                claims[0].id,
                e.id,
                EdgeKind::DerivesFrom { strength: 0.9 },
                cap(),
            ))
            .unwrap();

        let mut cache = TruthCache::new();
        let start = std::time::Instant::now();
        let affected = propagate_truth_change(claims[0].id, &store, &mut cache).unwrap();
        let elapsed = start.elapsed();

        // Should propagate all 1000 claims to True
        assert!(
            elapsed.as_millis() < 5_000,
            "1000-node propagation took {:?} (>5s)",
            elapsed
        );
        assert!(
            affected.len() >= 1000,
            "expected ≥1000 affected, got {}",
            affected.len()
        );
        for c in &claims {
            assert_eq!(
                cache.get(&c.id),
                Truth::True,
                "claim {} not True",
                c.id.to_hex()
            );
        }
    }

    #[test]
    fn propagation_terminates_on_cycles() {
        // Build a 3-cycle of claims via DerivesFrom edges: c0→c1→c2→c0.
        // Each derives_from the next; propagation must terminate.
        let store = InMemoryDagStore::new();
        let c0 = claim("c0");
        let c1 = claim("c1");
        let c2 = claim("c2");
        for c in [&c0, &c1, &c2] {
            store.put_node(c.clone()).unwrap();
        }
        for (a, b) in [(c0.id, c1.id), (c1.id, c2.id), (c2.id, c0.id)] {
            store
                .put_edge(Edge::new(
                    a,
                    b,
                    EdgeKind::DerivesFrom { strength: 0.5 },
                    cap(),
                ))
                .unwrap();
        }
        let mut cache = TruthCache::new();
        // No evidence root → all stay Unknown (no flip → no infinite loop)
        let affected = propagate_truth_change(c0.id, &store, &mut cache).unwrap();
        assert!(!affected.is_empty());
        for c in [&c0, &c1, &c2] {
            assert_eq!(cache.get(&c.id), Truth::Unknown);
        }
    }
}
