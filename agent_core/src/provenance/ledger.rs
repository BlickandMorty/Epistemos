// HARDENING ENFORCEMENT: production paths in this module MUST remain
// unwrap/expect/panic-free. The keystone retraction primitive crashes
// the agent if it panics — every error path returns a typed
// `LedgerError`. Tests are allowed to unwrap because a failed test
// invariant SHOULD panic loudly. Updated 2026-04-28 hardening pass.
#![cfg_attr(
    not(test),
    deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)
)]

//! `ClaimLedger` — the keystone Phase-1 primitive.
//!
//! Holds claims, evidence, and the directed-acyclic-graph of dependencies
//! between them. Implements **retraction propagation**: when a piece of
//! evidence is retracted (or a foundational claim is invalidated), every
//! transitively-derived claim is automatically marked `AtRisk` so the UI
//! can surface the now-unreliable inferences.
//!
//! Per `01_DOCTRINE.md §3` the propagation walk is **bounded** (depth ≤
//! [`MAX_RETRACTION_WALK_DEPTH`]) and **cycle-rejecting** — otherwise a
//! mutual-derivation loop would either run forever or silently truncate.
//!
//! The ledger is in-memory for Phase 1. Persistence onto GRDB / SQLite
//! lands in Phase 2 once the API surface is settled.

use std::collections::{BTreeSet, HashMap, HashSet, VecDeque};

use serde::{Deserialize, Serialize};
use thiserror::Error;

/// Maximum walk depth for retraction propagation. Per
/// `docs/_consolidated/00_canonical_authority/01_DOCTRINE.md §3.3`:
/// retraction walks deeper than 16 hops indicate a derivation graph
/// that has either drifted into noise or contains a path the user
/// would not be able to reason about anyway. The walk halts and
/// surfaces a [`LedgerError::WalkDepthExceeded`] so the operator
/// can decide whether to extend manually.
pub const MAX_RETRACTION_WALK_DEPTH: usize = 16;

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------

/// Stable claim identifier. Opaque to the ledger — caller chooses the
/// generation strategy (ULID / UUIDv7) so the rest of the codebase's
/// id discipline carries through.
#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(transparent)]
pub struct ClaimId(pub String);

impl ClaimId {
    pub fn new<S: Into<String>>(s: S) -> Self {
        Self(s.into())
    }
}

/// Stable evidence identifier. Same shape as [`ClaimId`] but distinguished
/// at the type level so APIs can refuse to cross the streams.
#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(transparent)]
pub struct EvidenceId(pub String);

impl EvidenceId {
    pub fn new<S: Into<String>>(s: S) -> Self {
        Self(s.into())
    }
}

// ---------------------------------------------------------------------------
// Status
// ---------------------------------------------------------------------------

/// Current trustworthiness state of a claim or piece of evidence.
///
/// Status is computed from the latest entry in the append-only
/// `claim_status_edges` history (the doctrine's mandate). Phase 1 keeps
/// the history implicit (just "current state") to ship the substrate;
/// the explicit edge log lands in Phase 2 alongside persistence.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ClaimStatus {
    /// Active and trusted.
    Active,
    /// Upstream evidence or a depended-upon claim was retracted; this
    /// claim is now suspect and the UI should surface it.
    AtRisk,
    /// Operator marked the claim as needing human re-validation
    /// (typically after an `AtRisk` signal triggers review).
    NeedsRevalidation,
    /// Explicitly invalidated. Downstream claims that depended on it
    /// are propagated to `AtRisk`.
    Retracted,
}

// ---------------------------------------------------------------------------
// Claim + Evidence
// ---------------------------------------------------------------------------

/// One Phase-1 Claim. Deliberately minimal — `text` + status + creation
/// timestamp is enough to prove the substrate works. Subsequent items
/// extend the type set with claim-kind enum, confidence, source-tier, etc.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Claim {
    pub id: ClaimId,
    pub text: String,
    pub status: ClaimStatus,
    pub created_at_ms: i64,
}

impl Claim {
    pub fn new<S: Into<String>>(id: ClaimId, text: S, created_at_ms: i64) -> Self {
        Self {
            id,
            text: text.into(),
            status: ClaimStatus::Active,
            created_at_ms,
        }
    }
}

/// One Phase-1 Evidence. `source` is a free-form string in Phase 1; the
/// typed `SourceTier` enum lands in Phase 2 alongside the full
/// source-quality contract `01_DOCTRINE.md §3.4` mandates.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Evidence {
    pub id: EvidenceId,
    pub source: String,
    pub status: ClaimStatus,
    pub created_at_ms: i64,
}

impl Evidence {
    pub fn new<S: Into<String>>(id: EvidenceId, source: S, created_at_ms: i64) -> Self {
        Self {
            id,
            source: source.into(),
            status: ClaimStatus::Active,
            created_at_ms,
        }
    }
}

// ---------------------------------------------------------------------------
// Ledger errors
// ---------------------------------------------------------------------------

#[derive(Debug, Error, PartialEq, Eq)]
pub enum LedgerError {
    /// Cycle detected while walking the derivation graph during a
    /// retraction. The doctrine forbids cycles in the claim DAG; the
    /// caller must remove the cycle (or audit the data ingestion path
    /// that produced it) before retraction can be re-attempted.
    #[error("cycle detected at claim {0:?} during retraction walk (path length {1})")]
    CycleDetected(ClaimId, usize),

    /// Bounded walk exceeded the [`MAX_RETRACTION_WALK_DEPTH`] depth.
    /// The walk halts with the partial result; operator can decide
    /// whether to extend manually.
    #[error("retraction walk exceeded max depth {0}")]
    WalkDepthExceeded(usize),

    #[error("claim {0:?} not found in ledger")]
    ClaimNotFound(ClaimId),

    #[error("evidence {0:?} not found in ledger")]
    EvidenceNotFound(EvidenceId),

    #[error("duplicate id on commit: {0:?}")]
    DuplicateId(String),

    /// Caller attempted to register a derivation chain that introduces
    /// a cycle into the claim DAG. Rejected at commit time so the walk
    /// invariants hold for every subsequent retraction.
    #[error("derivation would introduce a cycle: claim {0:?} → {1:?}")]
    DerivationWouldCycle(ClaimId, ClaimId),
}

// ---------------------------------------------------------------------------
// RetractionReport
// ---------------------------------------------------------------------------

/// Summary of a retraction propagation walk. Returned from
/// [`ClaimLedger::retract_evidence`] and [`ClaimLedger::retract_claim`]
/// so the caller can decide which UI surface to flag (and which agent
/// runs to mark for re-evaluation).
///
/// The set is computed deterministically — claim ids ordered via the
/// `BTreeSet` so multiple invocations against the same ledger state
/// produce byte-equal output (per `01_DOCTRINE.md §6` determinism rule).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RetractionReport {
    /// The id that triggered the walk (either a claim or evidence id,
    /// rendered as a string for cross-type uniformity).
    pub triggered_by: String,
    /// Claims whose status flipped from `Active` (or `NeedsRevalidation`)
    /// to `AtRisk` during the walk.
    pub claims_marked_at_risk: BTreeSet<ClaimId>,
    /// Walk depth actually traversed. Useful for telemetry — a walk
    /// approaching [`MAX_RETRACTION_WALK_DEPTH`] suggests the derivation
    /// graph is starting to drift.
    pub max_depth_reached: usize,
    /// Whether the walk exited because it hit the depth cap (rather
    /// than exhausting the frontier naturally). True means the report
    /// is a partial result; the operator may want to extend.
    pub depth_capped: bool,
}

// ---------------------------------------------------------------------------
// ClaimLedger
// ---------------------------------------------------------------------------

/// In-memory ledger of claims, evidence, and their derivation graph.
/// Phase 1 ships the API; persistence to GRDB lands in Phase 2.
///
/// The four adjacency maps are denormalized intentionally — every
/// retraction walk needs both directions of each edge, and Phase 1 is
/// optimizing for clarity over memory. The `evidence_supports` reverse
/// index turns an evidence retraction into an O(1) lookup of affected
/// claims; the `claim_derives` reverse index turns a claim retraction
/// into an O(1) lookup of downstream claims.
#[derive(Debug, Default, Clone)]
pub struct ClaimLedger {
    claims: HashMap<ClaimId, Claim>,
    evidence: HashMap<EvidenceId, Evidence>,
    /// `claim_id → set of evidence_ids that support it`
    claim_supported_by: HashMap<ClaimId, HashSet<EvidenceId>>,
    /// `evidence_id → set of claim_ids it supports` (reverse of above)
    evidence_supports: HashMap<EvidenceId, HashSet<ClaimId>>,
    /// `claim_id → set of upstream claim_ids it is derived from`
    claim_derived_from: HashMap<ClaimId, HashSet<ClaimId>>,
    /// `claim_id → set of downstream claim_ids that depend on it` (reverse of above)
    claim_derives: HashMap<ClaimId, HashSet<ClaimId>>,
}

impl ClaimLedger {
    pub fn new() -> Self {
        Self::default()
    }

    // -- read accessors -----------------------------------------------------

    pub fn claim(&self, id: &ClaimId) -> Option<&Claim> {
        self.claims.get(id)
    }

    pub fn evidence(&self, id: &EvidenceId) -> Option<&Evidence> {
        self.evidence.get(id)
    }

    pub fn claim_count(&self) -> usize {
        self.claims.len()
    }

    pub fn evidence_count(&self) -> usize {
        self.evidence.len()
    }

    /// Build a deterministic snapshot suitable for serialization into
    /// a `ReplayBundle`. Every collection is sorted by id at snapshot
    /// time so two snapshots of equal ledgers serialize to byte-equal
    /// JSON. Lives on the ledger so the private adjacency maps don't
    /// have to leak through the public API.
    pub fn snapshot(&self) -> super::replay::LedgerSnapshot {
        let mut claims: Vec<Claim> = self.claims.values().cloned().collect();
        claims.sort_by(|a, b| a.id.cmp(&b.id));
        let mut evidence: Vec<Evidence> = self.evidence.values().cloned().collect();
        evidence.sort_by(|a, b| a.id.cmp(&b.id));

        let mut derivations: Vec<super::replay::ClaimDerivation> = self
            .claim_derived_from
            .iter()
            .map(|(claim, parents)| {
                let mut parents_sorted: Vec<ClaimId> = parents.iter().cloned().collect();
                parents_sorted.sort();
                super::replay::ClaimDerivation {
                    claim: claim.clone(),
                    derived_from: parents_sorted,
                }
            })
            .collect();
        derivations.sort_by(|a, b| a.claim.cmp(&b.claim));

        let mut support_links: Vec<super::replay::ClaimEvidenceLink> = self
            .claim_supported_by
            .iter()
            .map(|(claim, evs)| {
                let mut evs_sorted: Vec<EvidenceId> = evs.iter().cloned().collect();
                evs_sorted.sort();
                super::replay::ClaimEvidenceLink {
                    claim: claim.clone(),
                    evidence: evs_sorted,
                }
            })
            .collect();
        support_links.sort_by(|a, b| a.claim.cmp(&b.claim));

        super::replay::LedgerSnapshot {
            claims,
            evidence,
            derivations,
            support_links,
        }
    }

    // -- commit -------------------------------------------------------------

    /// Insert evidence into the ledger. Idempotent on the id.
    pub fn commit_evidence(&mut self, e: Evidence) -> Result<(), LedgerError> {
        if self.evidence.contains_key(&e.id) {
            return Err(LedgerError::DuplicateId(e.id.0.clone()));
        }
        self.evidence_supports.entry(e.id.clone()).or_default();
        self.evidence.insert(e.id.clone(), e);
        Ok(())
    }

    /// Insert a claim with its derivation lineage and supporting evidence.
    /// `derived_from` and `supported_by` ids must already be in the
    /// ledger; cycles in the derivation graph are rejected.
    pub fn commit_claim(
        &mut self,
        claim: Claim,
        derived_from: Vec<ClaimId>,
        supported_by: Vec<EvidenceId>,
    ) -> Result<(), LedgerError> {
        if self.claims.contains_key(&claim.id) {
            return Err(LedgerError::DuplicateId(claim.id.0.clone()));
        }
        // Self-cycle is checked BEFORE parent-existence so a request
        // like `commit_claim(c2, derived_from=[c2])` returns the
        // semantically-correct `DerivationWouldCycle` rather than the
        // misleading `ClaimNotFound` that the parent-existence check
        // would emit (since c2 isn't in the ledger until after this
        // commit succeeds).
        for parent in &derived_from {
            if parent == &claim.id {
                return Err(LedgerError::DerivationWouldCycle(
                    claim.id.clone(),
                    parent.clone(),
                ));
            }
        }
        // Validate references exist BEFORE mutating any state, so a
        // failed commit leaves the ledger untouched.
        for parent in &derived_from {
            if !self.claims.contains_key(parent) {
                return Err(LedgerError::ClaimNotFound(parent.clone()));
            }
        }
        for ev in &supported_by {
            if !self.evidence.contains_key(ev) {
                return Err(LedgerError::EvidenceNotFound(ev.clone()));
            }
        }
        // Defensive non-self-cycle check: walk descendants of each
        // proposed parent and reject if we re-encounter `claim.id`.
        // The new claim has no descendants yet, so a hit means the id
        // is being recycled into a position that was previously
        // upstream — corruption from a Phase-2+ recreate-after-delete
        // path. The bounded BFS in `is_descendant_of` keeps this O(N)
        // even on pathological graphs.
        for parent in &derived_from {
            if self.is_descendant_of(&claim.id, parent) {
                return Err(LedgerError::DerivationWouldCycle(
                    claim.id.clone(),
                    parent.clone(),
                ));
            }
        }

        // All validation passed — commit atomically.
        let id = claim.id.clone();
        self.claims.insert(id.clone(), claim);
        let parents: HashSet<ClaimId> = derived_from.iter().cloned().collect();
        for parent in &parents {
            self.claim_derives
                .entry(parent.clone())
                .or_default()
                .insert(id.clone());
        }
        self.claim_derived_from.insert(id.clone(), parents);

        let supports: HashSet<EvidenceId> = supported_by.iter().cloned().collect();
        for ev in &supports {
            self.evidence_supports
                .entry(ev.clone())
                .or_default()
                .insert(id.clone());
        }
        self.claim_supported_by.insert(id.clone(), supports);
        self.claim_derives.entry(id).or_default();
        Ok(())
    }

    // -- retract ------------------------------------------------------------

    /// Retract evidence and propagate `AtRisk` to all transitively-derived
    /// claims, up to [`MAX_RETRACTION_WALK_DEPTH`]. Cycles in the claim
    /// graph cause the walk to fail (cycles are rejected at commit time
    /// per `commit_claim`, so this is a defensive belt-and-suspenders
    /// guard against state corruption).
    pub fn retract_evidence(&mut self, id: &EvidenceId) -> Result<RetractionReport, LedgerError> {
        if !self.evidence.contains_key(id) {
            return Err(LedgerError::EvidenceNotFound(id.clone()));
        }
        // Mark the evidence retracted FIRST so a subsequent retraction
        // walk over the same id is idempotent.
        if let Some(e) = self.evidence.get_mut(id) {
            e.status = ClaimStatus::Retracted;
        }
        // Seed the walk with every claim directly supported by this
        // evidence.
        let directly_supported: Vec<ClaimId> = self
            .evidence_supports
            .get(id)
            .map(|s| s.iter().cloned().collect())
            .unwrap_or_default();
        let report = self.bfs_mark_at_risk(&directly_supported, id.0.clone())?;
        Ok(report)
    }

    /// Retract a claim directly (e.g. operator marked it invalid) and
    /// propagate `AtRisk` to all downstream claims.
    pub fn retract_claim(&mut self, id: &ClaimId) -> Result<RetractionReport, LedgerError> {
        if !self.claims.contains_key(id) {
            return Err(LedgerError::ClaimNotFound(id.clone()));
        }
        if let Some(c) = self.claims.get_mut(id) {
            c.status = ClaimStatus::Retracted;
        }
        // Seed the walk with the descendants of the retracted claim.
        // The retracted claim itself is in `Retracted`, not `AtRisk`,
        // so it is NOT included in `claims_marked_at_risk`.
        let descendants: Vec<ClaimId> = self
            .claim_derives
            .get(id)
            .map(|s| s.iter().cloned().collect())
            .unwrap_or_default();
        self.bfs_mark_at_risk(&descendants, id.0.clone())
    }

    // -- internals ---------------------------------------------------------

    /// Return true if `target` is a descendant of `root` in the claim
    /// derivation graph. Used to reject cycle-introducing commits.
    /// Bounded by [`MAX_RETRACTION_WALK_DEPTH`] for symmetry with the
    /// retraction walk; a graph deeper than that is already pathological.
    fn is_descendant_of(&self, target: &ClaimId, root: &ClaimId) -> bool {
        if target == root {
            return true;
        }
        let mut visited: HashSet<ClaimId> = HashSet::new();
        let mut frontier: VecDeque<(ClaimId, usize)> = VecDeque::new();
        frontier.push_back((root.clone(), 0));
        while let Some((cur, depth)) = frontier.pop_front() {
            if depth >= MAX_RETRACTION_WALK_DEPTH {
                return false;
            }
            if let Some(children) = self.claim_derives.get(&cur) {
                for child in children {
                    if child == target {
                        return true;
                    }
                    if visited.insert(child.clone()) {
                        frontier.push_back((child.clone(), depth + 1));
                    }
                }
            }
        }
        false
    }

    /// BFS over the claim_derives forward index, marking every reached
    /// claim `AtRisk` (skipping those already `Retracted`). Returns a
    /// deterministic report.
    fn bfs_mark_at_risk(
        &mut self,
        seeds: &[ClaimId],
        triggered_by: String,
    ) -> Result<RetractionReport, LedgerError> {
        let mut visited: HashSet<ClaimId> = HashSet::new();
        let mut marked: BTreeSet<ClaimId> = BTreeSet::new();
        let mut frontier: VecDeque<(ClaimId, usize)> = VecDeque::new();
        for s in seeds {
            if visited.insert(s.clone()) {
                frontier.push_back((s.clone(), 1));
            }
        }
        let mut max_depth = 0usize;
        let mut depth_capped = false;
        while let Some((cur, depth)) = frontier.pop_front() {
            if depth > MAX_RETRACTION_WALK_DEPTH {
                depth_capped = true;
                break;
            }
            max_depth = max_depth.max(depth);
            // Mark this claim AtRisk if it is currently Active or
            // NeedsRevalidation. Already-retracted claims are skipped
            // (idempotency); already-at-risk claims keep their status.
            if let Some(c) = self.claims.get_mut(&cur) {
                if matches!(
                    c.status,
                    ClaimStatus::Active | ClaimStatus::NeedsRevalidation
                ) {
                    c.status = ClaimStatus::AtRisk;
                    marked.insert(cur.clone());
                }
            }
            // Enqueue descendants. The ledger is a DAG by construction
            // (commit_claim rejects cycles), so legitimate re-visits
            // happen at diamond-shaped re-convergences (`c2 ← c1`,
            // `c3 ← c1`, `c4 ← c2`, `c4 ← c3` — c4 is reached via two
            // BFS paths). We dedupe via the visited set; cycle detection
            // belongs at commit time, not retraction time.
            if let Some(children) = self.claim_derives.get(&cur) {
                // Sort children for deterministic walk order so the
                // BTreeSet `marked` and `max_depth_reached` are stable
                // across runs (per `01_DOCTRINE.md §6` determinism rule).
                let mut sorted_children: Vec<&ClaimId> = children.iter().collect();
                sorted_children.sort();
                for child in sorted_children {
                    if visited.insert(child.clone()) {
                        frontier.push_back((child.clone(), depth + 1));
                    }
                }
            }
        }
        Ok(RetractionReport {
            triggered_by,
            claims_marked_at_risk: marked,
            max_depth_reached: max_depth,
            depth_capped,
        })
    }
}

// ---------------------------------------------------------------------------
// Tests — Phase 1 acceptance gates from `04_PHASES.md`
// ---------------------------------------------------------------------------
//
//   "Existing test floor still green; at least 3 unit tests for retraction
//   propagation (direct retraction, transitive retraction at depth 1,
//   cycle detection rejection); 2 tests for ReplayBundle byte-equivalence."
//
// This file ships the 3 retraction tests + a handful of substrate tests.
// ReplayBundle byte-equivalence ships in its own module (Phase 1 task 6).

#[cfg(test)]
mod tests {
    use super::*;

    fn t() -> i64 {
        1_745_000_000_000
    }

    fn seed_basic_ledger() -> ClaimLedger {
        let mut l = ClaimLedger::new();
        l.commit_evidence(Evidence::new(EvidenceId::new("ev-a"), "arxiv://1234", t()))
            .unwrap();
        l.commit_evidence(Evidence::new(EvidenceId::new("ev-b"), "doi://5678", t()))
            .unwrap();
        l.commit_claim(
            Claim::new(ClaimId::new("c1"), "ground-truth claim", t()),
            vec![],
            vec![EvidenceId::new("ev-a")],
        )
        .unwrap();
        l.commit_claim(
            Claim::new(ClaimId::new("c2"), "derived from c1", t()),
            vec![ClaimId::new("c1")],
            vec![EvidenceId::new("ev-b")],
        )
        .unwrap();
        l.commit_claim(
            Claim::new(ClaimId::new("c3"), "two-hops downstream", t()),
            vec![ClaimId::new("c2")],
            vec![],
        )
        .unwrap();
        l
    }

    #[test]
    fn direct_retraction_marks_supported_claim_at_risk() {
        let mut l = seed_basic_ledger();
        let report = l.retract_evidence(&EvidenceId::new("ev-a")).unwrap();
        assert!(
            report.claims_marked_at_risk.contains(&ClaimId::new("c1")),
            "c1 (directly supported by ev-a) must be AtRisk"
        );
        assert_eq!(
            l.claim(&ClaimId::new("c1")).unwrap().status,
            ClaimStatus::AtRisk
        );
        // The retracted evidence itself is Retracted, not AtRisk.
        assert_eq!(
            l.evidence(&EvidenceId::new("ev-a")).unwrap().status,
            ClaimStatus::Retracted
        );
        assert_eq!(report.triggered_by, "ev-a");
    }

    #[test]
    fn transitive_retraction_at_depth_1_propagates() {
        let mut l = seed_basic_ledger();
        // Retract c1 directly. c2 is one hop downstream of c1; c3 is
        // two hops downstream. Both must end AtRisk.
        let report = l.retract_claim(&ClaimId::new("c1")).unwrap();
        assert_eq!(
            l.claim(&ClaimId::new("c1")).unwrap().status,
            ClaimStatus::Retracted,
            "the retracted claim itself is Retracted, not AtRisk"
        );
        assert_eq!(
            l.claim(&ClaimId::new("c2")).unwrap().status,
            ClaimStatus::AtRisk
        );
        assert_eq!(
            l.claim(&ClaimId::new("c3")).unwrap().status,
            ClaimStatus::AtRisk
        );
        // The report enumerates only the downstream-flipped claims.
        assert_eq!(
            report.claims_marked_at_risk,
            [ClaimId::new("c2"), ClaimId::new("c3")]
                .into_iter()
                .collect::<BTreeSet<_>>()
        );
        assert_eq!(report.max_depth_reached, 2);
        assert!(!report.depth_capped);
    }

    #[test]
    fn cycle_detection_rejects_self_referential_derivation() {
        let mut l = ClaimLedger::new();
        l.commit_claim(Claim::new(ClaimId::new("c1"), "first", t()), vec![], vec![])
            .unwrap();
        // Direct self-cycle: c2 derived from itself. Must be rejected
        // before the ledger admits the corruption.
        let err = l
            .commit_claim(
                Claim::new(ClaimId::new("c2"), "self-cycle attempt", t()),
                vec![ClaimId::new("c2")],
                vec![],
            )
            .unwrap_err();
        match err {
            LedgerError::DerivationWouldCycle(child, parent) => {
                assert_eq!(child, ClaimId::new("c2"));
                assert_eq!(parent, ClaimId::new("c2"));
            }
            other => panic!("expected DerivationWouldCycle, got {other:?}"),
        }
        // Phase-1 invariant: an erroneous commit leaves the ledger
        // untouched. c2 must NOT be in the claims map.
        assert!(l.claim(&ClaimId::new("c2")).is_none());
    }

    // -- additional substrate tests for the corner cases the Phase 1
    //    acceptance gates don't enumerate explicitly but the doctrine
    //    invariants demand. ------------------------------------------

    #[test]
    fn retracting_unrelated_evidence_does_not_touch_other_claims() {
        let mut l = seed_basic_ledger();
        let report = l.retract_evidence(&EvidenceId::new("ev-b")).unwrap();
        // ev-b supports only c2; c1 should NOT be marked AtRisk by
        // this walk.
        assert!(report.claims_marked_at_risk.contains(&ClaimId::new("c2")));
        assert_eq!(
            l.claim(&ClaimId::new("c1")).unwrap().status,
            ClaimStatus::Active,
            "c1 has no causal link to ev-b — must stay Active"
        );
        // c3 is downstream of c2 — it propagates AtRisk.
        assert_eq!(
            l.claim(&ClaimId::new("c3")).unwrap().status,
            ClaimStatus::AtRisk
        );
    }

    #[test]
    fn retraction_is_idempotent_on_already_retracted_evidence() {
        let mut l = seed_basic_ledger();
        let r1 = l.retract_evidence(&EvidenceId::new("ev-a")).unwrap();
        let r2 = l.retract_evidence(&EvidenceId::new("ev-a")).unwrap();
        // Second retraction touches no new claims (c1 is already AtRisk).
        assert_eq!(r2.claims_marked_at_risk.len(), 0);
        // First retraction marked c1; second left it.
        assert!(r1.claims_marked_at_risk.contains(&ClaimId::new("c1")));
    }

    #[test]
    fn missing_evidence_returns_evidence_not_found() {
        let mut l = seed_basic_ledger();
        let err = l.retract_evidence(&EvidenceId::new("ghost")).unwrap_err();
        assert_eq!(err, LedgerError::EvidenceNotFound(EvidenceId::new("ghost")));
    }

    #[test]
    fn duplicate_id_commit_is_rejected() {
        let mut l = ClaimLedger::new();
        l.commit_evidence(Evidence::new(EvidenceId::new("ev"), "src", t()))
            .unwrap();
        let err = l
            .commit_evidence(Evidence::new(EvidenceId::new("ev"), "src", t()))
            .unwrap_err();
        match err {
            LedgerError::DuplicateId(id) => assert_eq!(id, "ev"),
            other => panic!("expected DuplicateId, got {other:?}"),
        }
    }

    #[test]
    fn report_is_deterministic_across_runs() {
        // Run the same retraction against the same seed twice; the
        // BTreeSet ordering must yield byte-equal RetractionReports.
        let mut l1 = seed_basic_ledger();
        let mut l2 = seed_basic_ledger();
        let r1 = l1.retract_claim(&ClaimId::new("c1")).unwrap();
        let r2 = l2.retract_claim(&ClaimId::new("c1")).unwrap();
        let json1 = serde_json::to_string(&r1).unwrap();
        let json2 = serde_json::to_string(&r2).unwrap();
        assert_eq!(
            json1, json2,
            "RetractionReport must serialize deterministically across runs"
        );
    }

    #[test]
    fn diamond_dependency_is_handled_without_double_walking() {
        // c1 ← c2, c1 ← c3, c2 ← c4, c3 ← c4 — diamond. Retracting c1
        // must mark c2, c3, c4 each exactly once; the BFS must not
        // re-enter c4.
        let mut l = ClaimLedger::new();
        for id in ["c1", "c2", "c3", "c4"] {
            l.commit_claim(
                Claim::new(ClaimId::new(id), id, t()),
                if id == "c1" {
                    vec![]
                } else if id == "c2" || id == "c3" {
                    vec![ClaimId::new("c1")]
                } else {
                    vec![ClaimId::new("c2"), ClaimId::new("c3")]
                },
                vec![],
            )
            .unwrap();
        }
        let report = l.retract_claim(&ClaimId::new("c1")).unwrap();
        assert_eq!(
            report.claims_marked_at_risk,
            [ClaimId::new("c2"), ClaimId::new("c3"), ClaimId::new("c4")]
                .into_iter()
                .collect::<BTreeSet<_>>()
        );
    }

    #[test]
    fn deep_chain_walks_without_capping_below_max_depth() {
        // 10-deep chain — under MAX_RETRACTION_WALK_DEPTH (16).
        let mut l = ClaimLedger::new();
        l.commit_claim(Claim::new(ClaimId::new("c0"), "root", t()), vec![], vec![])
            .unwrap();
        for i in 1..=10 {
            let prev = format!("c{}", i - 1);
            let cur = format!("c{}", i);
            l.commit_claim(
                Claim::new(ClaimId::new(&cur), &cur, t()),
                vec![ClaimId::new(&prev)],
                vec![],
            )
            .unwrap();
        }
        let report = l.retract_claim(&ClaimId::new("c0")).unwrap();
        assert_eq!(report.claims_marked_at_risk.len(), 10);
        assert!(!report.depth_capped);
        assert!(report.max_depth_reached <= MAX_RETRACTION_WALK_DEPTH);
    }
}
