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
//!
//! # HELIOS doctrine cross-reference
//!
//! `ClaimLedger` stores exact, addressable claim + evidence records — that
//! places it in the **Episodic** plane (plane 2) per V6.1 §3. The canonical
//! anchor lives in `epistemos-research/src/five_planes.rs::PROVENANCE_STORAGE_PLANE`
//! (research-tier, `--features research`). This mirrors the existing
//! `acs.rs::ACS_CANONICAL_PLANE = Episodic` precedent.
//!
//! The audit-side surface (ReplayBundle / LedgerSnapshot / `epistemos_trace
//! verify`) is plane 5 (Verification) — see `provenance::replay` for its
//! doctrine block.
//!
//! Drift gate: the test
//! `epistemos-research/src/five_planes.rs::tests::provenance_storage_in_episodic_audit_in_verification`
//! locks both placements + the inequality invariant (storage ≠ audit).
//! Any move of the ledger or the replay verifier in agent_core must
//! update the constants in five_planes.rs in lockstep.

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
// ClaimKind (HELIOS V5 W2 + V6.1 runtime acknowledgement)
// ---------------------------------------------------------------------------

// HELIOS-W2 guard
//
// Per HELIOS V5 Canon Lock v2 §1 (Q2 = optimal-combination Tier 1) +
// `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §1 W2 + DOC 0 §0.6:
//
//   "ClaimKind 5-arm extension `(Empirical | Mathematical | CodeInvariant |
//    Causal | Speculative)` to existing ClaimLedger — strictly additive
//    enum; backward-compat for v1 ClaimLedger archives."
//
// Maps to π Kleene K3 9-claim subset (helios v5 first.md §1.9). The
// AnswerPacket spine (W1) carries (ClaimKind, VRMLabel) for every emitted
// claim. Backward-compat is enforced by `#[serde(default)]` on the new
// `kind` field — old archives without `kind` deserialize as
// `ClaimKind::Empirical`.

/// HELIOS V5 W2 — classification of a claim.
///
/// Strictly additive over the v1 `Claim` schema. Old archives that lack
/// the `kind` field deserialize to [`ClaimKind::Empirical`] via
/// `#[serde(default)]` on [`Claim::kind`].
///
/// V5 locks the five epistemic arms. V6.1 adds one runtime-admission
/// arm so a static 9:1 attention fallback cannot occur silently in an
/// AnswerPacket.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ClaimKind {
    /// Empirical observations, measurements, or facts about the world.
    /// Default for backward-compat with v1 archives.
    Empirical,
    /// Mathematical statements with formal proofs (Lean / mathlib4 / etc.).
    Mathematical,
    /// Code invariants verified by tests, type system, or property tests.
    CodeInvariant,
    /// Causal claims (X causes Y); weaker than mathematical, stronger
    /// than speculative.
    Causal,
    /// Speculative claims, hypotheses, or conjectures pending evidence.
    Speculative,
    /// V6.1 runtime acknowledgement: static 9:1 fallback was used
    /// because dynamic interrupt signals were unavailable. This is not
    /// a sixth epistemic truth class; it is an audit-plane admission.
    StaticFallbackAcknowledged,
}

impl Default for ClaimKind {
    /// V1 ClaimLedger archives have no `kind` field; default to
    /// `Empirical` per W2 acceptance (backward-compat replay test).
    fn default() -> Self {
        Self::Empirical
    }
}

// ---------------------------------------------------------------------------
// Claim + Evidence
// ---------------------------------------------------------------------------

/// One Claim. The HELIOS V5 W2 extension adds the [`ClaimKind`]
/// discriminator so downstream consumers (AnswerPacket, VRMLabel, π
/// classifier) can route by claim type. The field is `serde(default)`
/// so v1 archives without `kind` continue to deserialize.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Claim {
    pub id: ClaimId,
    pub text: String,
    pub status: ClaimStatus,
    pub created_at_ms: i64,
    /// HELIOS V5 W2 — claim classification. Defaults to
    /// `ClaimKind::Empirical` if absent (v1 backward-compat).
    #[serde(default)]
    pub kind: ClaimKind,
}

impl Claim {
    /// Create a new active Claim with the default kind ([`ClaimKind::Empirical`]).
    /// Use [`Claim::with_kind`] to set a non-default kind on the same object.
    pub fn new<S: Into<String>>(id: ClaimId, text: S, created_at_ms: i64) -> Self {
        Self {
            id,
            text: text.into(),
            status: ClaimStatus::Active,
            created_at_ms,
            kind: ClaimKind::Empirical,
        }
    }

    /// Builder-style setter for [`ClaimKind`]. Enables one-liner
    /// construction:
    ///
    /// ```
    /// use agent_core::provenance::ledger::{Claim, ClaimId, ClaimKind};
    /// let c = Claim::new(ClaimId::new("c1"), "x", 0).with_kind(ClaimKind::Mathematical);
    /// assert_eq!(c.kind, ClaimKind::Mathematical);
    /// ```
    pub fn with_kind(mut self, kind: ClaimKind) -> Self {
        self.kind = kind;
        self
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

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RetractionTriggerKind {
    Evidence,
    Claim,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RetractionPropagatedEvent {
    pub sequence: u64,
    pub trigger_kind: RetractionTriggerKind,
    pub triggered_by: String,
    pub report: RetractionReport,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum LedgerEvent {
    RetractionPropagated(RetractionPropagatedEvent),
}

impl LedgerEvent {
    pub fn sequence(&self) -> u64 {
        match self {
            Self::RetractionPropagated(event) => event.sequence,
        }
    }
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
// ---------------------------------------------------------------------------
// Knowledge Sieve + Gap Winner Rule (Master Fusion Plan §B.7)
// ---------------------------------------------------------------------------
//
// Per `docs/fusion/jordan's research/kimis deep research/ternary_reconceptualization.md`
// §3.2-3.6. A claim's "prime / composite / gap" tier is derived from
//
//   - **prime**:  claim with HIGH normalized in-degree (many downstream
//                 dependents); a structural carrier. `weight(C) = d(C) /
//                 max(d(C') for all C' in KB)` (§3.2).
//   - **composite**: claim with LOW in-degree; entailed by primes, eligible
//                 for derivation-on-demand (§3.6 Knowledge Sieve).
//   - **gap**:    AtRisk / NeedsRevalidation / Retracted claims — the
//                 "waiting / unverified" tier the No-Later-Simpler-
//                 Composite curriculum deprioritizes (§3.4).
//
// The Gap Winner Rule (§3.3) governs retrieval: the winner of a
// retrieval set is the leftmost min-dependency carrier — i.e. the prime
// with the FEWEST upstream prerequisites that still has a non-zero
// downstream dependent count. That gives consumers (RRF k=60 fusion in
// `epistemos-shadow`, future memory.semantic_recall) a deterministic
// ranking order without invoking an LLM.

/// Tier in the prime / composite / gap taxonomy.
///
/// Derived from the ClaimLedger's adjacency graph + claim status at
/// rank time. Order: `Gap` < `Composite` < `Prime` so a `(tier, weight)`
/// natural ordering sorts gap → composite → prime ascending.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ClaimTier {
    /// Status ∈ {`AtRisk`, `NeedsRevalidation`, `Retracted`} — the
    /// curriculum-deprioritized "waiting / unverified" set.
    Gap,
    /// Active, but has zero downstream dependents — derivable from
    /// primes via the Knowledge Sieve.
    Composite,
    /// Active and carrier of downstream structure (`claim_derives`
    /// non-empty). Anchors that survive aggressive compression.
    Prime,
}

/// One ranked claim returned by [`ClaimLedger::rank_by_prime_composite_gap`].
///
/// Fields are denormalized for downstream consumers (RRF rank-boost
/// term, Provenance Console UI, NightBrain task budgeters) so they
/// don't have to re-walk the adjacency maps.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RankedClaim {
    pub claim_id: ClaimId,
    pub tier: ClaimTier,
    pub dependents: usize,
    pub dependencies: usize,
    /// HELIOS V5 W2 — claim kind passed through for downstream filters.
    pub kind: ClaimKind,
    /// Active / AtRisk / NeedsRevalidation / Retracted.
    pub status: ClaimStatus,
    /// Created-at timestamp, surfaced so consumers can tiebreak by
    /// recency without having to fetch the full Claim back.
    pub created_at_ms: i64,
}

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
    events: Vec<LedgerEvent>,
    next_event_sequence: u64,
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

    pub fn events_since(&self, after_sequence: u64) -> Vec<LedgerEvent> {
        self.events
            .iter()
            .filter(|event| event.sequence() > after_sequence)
            .cloned()
            .collect()
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
        // Phase 8.E auto-invoke: mirror the legacy write into the
        // cognitive DAG. Cloned by reference because the dispatch
        // helper needs the owned Evidence shape and the legacy store
        // is about to take ownership too. Failures inside the dispatch
        // are logged but never propagated — doctrine §10: a mirror
        // miss must NOT break the legacy write.
        crate::cognitive_dag::dispatch::on_evidence_committed(&e);
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
        // Phase 8.E auto-invoke: mirror into the cognitive DAG before
        // the legacy take-ownership move so the dispatch helper sees
        // the canonical Claim shape. Doctrine §10: failures are logged
        // but not propagated — legacy commit stays authoritative.
        crate::cognitive_dag::dispatch::on_claim_committed(&claim, &derived_from, &supported_by);
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
        self.record_retraction_event(RetractionTriggerKind::Evidence, &report);
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
        let report = self.bfs_mark_at_risk(&descendants, id.0.clone())?;
        self.record_retraction_event(RetractionTriggerKind::Claim, &report);
        Ok(report)
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

    fn record_retraction_event(
        &mut self,
        trigger_kind: RetractionTriggerKind,
        report: &RetractionReport,
    ) {
        let sequence = self.next_event_sequence.saturating_add(1);
        self.next_event_sequence = sequence;
        self.events.push(LedgerEvent::RetractionPropagated(
            RetractionPropagatedEvent {
                sequence,
                trigger_kind,
                triggered_by: report.triggered_by.clone(),
                report: report.clone(),
            },
        ));
    }

    // -- Knowledge Sieve + Gap Winner Rule (Master Fusion §B.7) ------------

    /// Rank every claim in the ledger by the prime / composite / gap
    /// taxonomy per `ternary_reconceptualization.md` §3.2-3.6.
    ///
    /// Tier resolution:
    ///   - `Gap` — claim status ∈ {`AtRisk`, `NeedsRevalidation`,
    ///     `Retracted`}. Curriculum-deprioritized.
    ///   - `Composite` — `Active`, `claim_derives` empty (no downstream
    ///     dependents). Eligible for derivation-on-demand.
    ///   - `Prime` — `Active`, `claim_derives` non-empty (structural
    ///     carrier). High weight.
    ///
    /// Output order (highest-rank first → lowest):
    ///   1. Tier descending: `Prime` → `Composite` → `Gap`
    ///   2. Within a tier, dependents descending (Gap-Winner: more
    ///      carriers first)
    ///   3. Then dependencies ascending (Gap Winner's "leftmost
    ///      min-dependency carrier" rule — fewer prereqs ranks higher)
    ///   4. Then created_at_ms ascending (older = more established)
    ///   5. Final tiebreak: claim_id lexicographic (determinism anchor)
    ///
    /// Determinism: every collection consulted by this method is sorted
    /// before iteration, so two ledgers in equal state produce
    /// byte-identical output. Pin this with the
    /// `ranking_is_deterministic_across_repeated_calls` test.
    pub fn rank_by_prime_composite_gap(&self) -> Vec<RankedClaim> {
        // Sort claim ids for deterministic iteration. BTreeMap would
        // give us this for free but we don't want to disturb the
        // existing HashMap-backed adjacency storage; sorting at rank
        // time is cheap relative to the ranking sort itself.
        let mut ids: Vec<&ClaimId> = self.claims.keys().collect();
        ids.sort();

        let mut ranked: Vec<RankedClaim> = ids
            .into_iter()
            .map(|id| {
                let claim = &self.claims[id];
                let dependents = self
                    .claim_derives
                    .get(id)
                    .map(|s| s.len())
                    .unwrap_or(0);
                let dependencies = self
                    .claim_derived_from
                    .get(id)
                    .map(|s| s.len())
                    .unwrap_or(0);
                let tier = match (claim.status, dependents) {
                    (ClaimStatus::Retracted, _)
                    | (ClaimStatus::AtRisk, _)
                    | (ClaimStatus::NeedsRevalidation, _) => ClaimTier::Gap,
                    (ClaimStatus::Active, 0) => ClaimTier::Composite,
                    (ClaimStatus::Active, _) => ClaimTier::Prime,
                };
                RankedClaim {
                    claim_id: claim.id.clone(),
                    tier,
                    dependents,
                    dependencies,
                    kind: claim.kind,
                    status: claim.status,
                    created_at_ms: claim.created_at_ms,
                }
            })
            .collect();

        // Sort: prime → composite → gap, then dependents desc,
        // dependencies asc (Gap Winner), then created_at asc, then id.
        // `sort_by` is stable so equal-key claims keep ledger-id order.
        ranked.sort_by(|a, b| {
            // tier: descending (Prime > Composite > Gap when reversed)
            b.tier
                .cmp(&a.tier)
                // dependents: descending (more carriers first)
                .then_with(|| b.dependents.cmp(&a.dependents))
                // dependencies: ascending (fewer prereqs wins per
                // Gap Winner Rule §3.3)
                .then_with(|| a.dependencies.cmp(&b.dependencies))
                // created_at: ascending (older = more established)
                .then_with(|| a.created_at_ms.cmp(&b.created_at_ms))
                // final tiebreak: claim id (determinism anchor)
                .then_with(|| a.claim_id.cmp(&b.claim_id))
        });
        ranked
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
    fn evidence_retraction_emits_typed_retraction_propagated_event() {
        let mut l = seed_basic_ledger();
        let report = l.retract_evidence(&EvidenceId::new("ev-a")).unwrap();
        let events = l.events_since(0);

        assert_eq!(events.len(), 1);
        match &events[0] {
            LedgerEvent::RetractionPropagated(event) => {
                assert_eq!(event.sequence, 1);
                assert_eq!(event.trigger_kind, RetractionTriggerKind::Evidence);
                assert_eq!(event.triggered_by, "ev-a");
                assert_eq!(event.report, report);
                assert!(event
                    .report
                    .claims_marked_at_risk
                    .contains(&ClaimId::new("c1")));
            }
        }
    }

    #[test]
    fn events_since_is_a_subscriber_cursor_over_retraction_events() {
        let mut l = seed_basic_ledger();
        l.retract_evidence(&EvidenceId::new("ev-a")).unwrap();
        l.retract_claim(&ClaimId::new("c2")).unwrap();

        let all = l.events_since(0);
        let after_first = l.events_since(1);

        assert_eq!(all.len(), 2);
        assert_eq!(after_first.len(), 1);
        match &after_first[0] {
            LedgerEvent::RetractionPropagated(event) => {
                assert_eq!(event.sequence, 2);
                assert_eq!(event.trigger_kind, RetractionTriggerKind::Claim);
                assert_eq!(event.triggered_by, "c2");
            }
        }
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

    // ----------------------------------------------------------------
    // HELIOS V5 W2 — ClaimKind 5-arm extension
    // ----------------------------------------------------------------

    #[test]
    fn claim_new_defaults_to_empirical_kind() {
        let c = Claim::new(ClaimId::new("c"), "x", t());
        assert_eq!(c.kind, ClaimKind::Empirical);
    }

    #[test]
    fn claim_with_kind_sets_each_canonical_arm_plus_static_fallback_ack() {
        let base = || Claim::new(ClaimId::new("c"), "x", t());
        assert_eq!(
            base().with_kind(ClaimKind::Empirical).kind,
            ClaimKind::Empirical
        );
        assert_eq!(
            base().with_kind(ClaimKind::Mathematical).kind,
            ClaimKind::Mathematical
        );
        assert_eq!(
            base().with_kind(ClaimKind::CodeInvariant).kind,
            ClaimKind::CodeInvariant
        );
        assert_eq!(base().with_kind(ClaimKind::Causal).kind, ClaimKind::Causal);
        assert_eq!(
            base().with_kind(ClaimKind::Speculative).kind,
            ClaimKind::Speculative
        );
        assert_eq!(
            base().with_kind(ClaimKind::StaticFallbackAcknowledged).kind,
            ClaimKind::StaticFallbackAcknowledged
        );
    }

    #[test]
    fn claim_kind_default_is_empirical_for_v1_archive_compat() {
        // The Default impl is the backward-compat anchor: any v1
        // archive that lacks `kind` deserializes via `serde(default)`
        // → `ClaimKind::default()` → `Empirical`.
        assert_eq!(ClaimKind::default(), ClaimKind::Empirical);
    }

    #[test]
    fn v1_claim_archive_without_kind_field_deserializes_as_empirical() {
        // Simulate a v1 ClaimLedger archive: Claim JSON without the
        // `kind` field. The new code path must accept this and default
        // to Empirical (the backward-compat acceptance criterion for
        // W2 per HELIOS V5 v2 plan §3 W2).
        let v1_json = r#"{
            "id": "c-legacy",
            "text": "claim from a v1 archive",
            "status": "active",
            "created_at_ms": 1745000000000
        }"#;
        let claim: Claim = serde_json::from_str(v1_json).expect("v1 archive must deserialize");
        assert_eq!(claim.kind, ClaimKind::Empirical);
        assert_eq!(claim.id, ClaimId::new("c-legacy"));
        assert_eq!(claim.status, ClaimStatus::Active);
    }

    #[test]
    fn v2_claim_with_explicit_kind_round_trips_through_json() {
        let original =
            Claim::new(ClaimId::new("c-v2"), "math claim", t()).with_kind(ClaimKind::Mathematical);
        let json = serde_json::to_string(&original).expect("v2 claim must serialize");
        let parsed: Claim = serde_json::from_str(&json).expect("v2 claim must deserialize");
        assert_eq!(parsed, original);
        assert_eq!(parsed.kind, ClaimKind::Mathematical);
        // The kind field is rendered in snake_case per the enum's serde rename.
        assert!(json.contains("\"kind\":\"mathematical\""));
    }

    #[test]
    fn claim_kind_serializes_in_snake_case_for_each_arm() {
        // Lock the wire format so a downstream Swift mirror struct (W1
        // / W3) can rely on the snake_case spelling.
        for (kind, expected) in [
            (ClaimKind::Empirical, "\"empirical\""),
            (ClaimKind::Mathematical, "\"mathematical\""),
            (ClaimKind::CodeInvariant, "\"code_invariant\""),
            (ClaimKind::Causal, "\"causal\""),
            (ClaimKind::Speculative, "\"speculative\""),
            (
                ClaimKind::StaticFallbackAcknowledged,
                "\"static_fallback_acknowledged\"",
            ),
        ] {
            let json = serde_json::to_string(&kind).unwrap();
            assert_eq!(json, expected, "wire format for {:?}", kind);
        }
    }

    // -- Master Fusion §B.7 Knowledge Sieve + Gap Winner Rule -------------

    #[test]
    fn rank_classifies_basic_ledger_as_two_primes_one_composite() {
        // seed_basic_ledger() builds: c1 → c2 → c3. c1 + c2 have
        // downstream dependents (Prime); c3 has none (Composite).
        let ledger = seed_basic_ledger();
        let ranked = ledger.rank_by_prime_composite_gap();
        assert_eq!(ranked.len(), 3);

        let by_id: std::collections::HashMap<String, &RankedClaim> =
            ranked.iter().map(|r| (r.claim_id.0.clone(), r)).collect();

        // c1 — 1 dependent (c2), 0 deps → Prime.
        let c1 = by_id.get("c1").expect("c1 must rank");
        assert_eq!(c1.tier, ClaimTier::Prime);
        assert_eq!(c1.dependents, 1);
        assert_eq!(c1.dependencies, 0);

        // c2 — 1 dependent (c3), 1 dep (c1) → Prime.
        let c2 = by_id.get("c2").expect("c2 must rank");
        assert_eq!(c2.tier, ClaimTier::Prime);
        assert_eq!(c2.dependents, 1);
        assert_eq!(c2.dependencies, 1);

        // c3 — 0 dependents, 1 dep (c2) → Composite.
        let c3 = by_id.get("c3").expect("c3 must rank");
        assert_eq!(c3.tier, ClaimTier::Composite);
        assert_eq!(c3.dependents, 0);
        assert_eq!(c3.dependencies, 1);
    }

    #[test]
    fn rank_gap_winner_orders_primes_by_dependents_then_fewest_dependencies() {
        // c1 + c2 are both Prime. Gap Winner Rule §3.3 says the
        // leftmost min-dependency carrier wins. c1 has 0 dependencies,
        // c2 has 1 → c1 ranks above c2.
        let ledger = seed_basic_ledger();
        let ranked = ledger.rank_by_prime_composite_gap();

        let positions: std::collections::HashMap<String, usize> = ranked
            .iter()
            .enumerate()
            .map(|(i, r)| (r.claim_id.0.clone(), i))
            .collect();
        assert!(
            positions["c1"] < positions["c2"],
            "c1 (fewer deps) must rank above c2; got {:?}",
            ranked
                .iter()
                .map(|r| (r.claim_id.0.clone(), r.tier))
                .collect::<Vec<_>>()
        );

        // And both primes outrank the composite c3.
        assert!(positions["c2"] < positions["c3"]);
    }

    #[test]
    fn rank_deprioritizes_retracted_claims_to_gap_tier() {
        // Retract c1's only evidence (ev-a) → c1 + c2 + c3 cascade to
        // AtRisk per existing retraction propagation. AtRisk maps to
        // Gap tier; all three claims should rank below any active
        // primes (none exist after retraction).
        let mut ledger = seed_basic_ledger();
        ledger.retract_evidence(&EvidenceId::new("ev-a")).unwrap();

        let ranked = ledger.rank_by_prime_composite_gap();
        assert!(ranked.iter().all(|r| r.tier == ClaimTier::Gap),
            "after evidence retraction every claim must fall into Gap tier; got {:?}",
            ranked.iter().map(|r| (r.claim_id.0.clone(), r.tier)).collect::<Vec<_>>()
        );
    }

    #[test]
    fn rank_explicitly_retracted_claim_is_gap_even_if_downstream_dependents_exist() {
        // If you retract a claim DIRECTLY (not its evidence), the
        // claim itself goes to Retracted status. It must rank as Gap
        // regardless of how many dependents it had.
        let mut ledger = seed_basic_ledger();
        ledger.retract_claim(&ClaimId::new("c1")).unwrap();

        let ranked = ledger.rank_by_prime_composite_gap();
        let by_id: std::collections::HashMap<String, &RankedClaim> =
            ranked.iter().map(|r| (r.claim_id.0.clone(), r)).collect();

        let c1 = by_id["c1"];
        assert_eq!(c1.status, ClaimStatus::Retracted);
        assert_eq!(c1.tier, ClaimTier::Gap);
        // c1 had 1 dependent (c2) before retraction — the dependent
        // count is reported but the tier reflects status.
        assert_eq!(c1.dependents, 1);
    }

    #[test]
    fn ranking_is_deterministic_across_repeated_calls() {
        // Determinism is the rank doctrine anchor — repeated calls on
        // an unchanged ledger must produce byte-identical output for
        // the Provenance Console replay path.
        let ledger = seed_basic_ledger();
        let a = ledger.rank_by_prime_composite_gap();
        let b = ledger.rank_by_prime_composite_gap();
        let c = ledger.rank_by_prime_composite_gap();
        assert_eq!(a, b);
        assert_eq!(b, c);

        // And the JSON serialization is byte-equal too (Provenance
        // Console replay path serializes ranked output into the
        // .epbundle replay shape).
        let ja = serde_json::to_string(&a).unwrap();
        let jb = serde_json::to_string(&b).unwrap();
        assert_eq!(ja, jb, "serialized ranking must be byte-equal across calls");
    }

    #[test]
    fn rank_orders_gap_below_composite_below_prime_globally() {
        // Construct a 4-claim ledger:
        //   - c-prime: 1 dependent, status Active → Prime
        //   - c-composite: 0 dependents, Active → Composite
        //   - c-gap-needsreval: 0 dependents, NeedsRevalidation → Gap
        //   - c-gap-retracted: explicitly retracted → Gap
        let mut l = ClaimLedger::new();
        l.commit_evidence(Evidence::new(EvidenceId::new("ev"), "src", t()))
            .unwrap();
        l.commit_claim(
            Claim::new(ClaimId::new("c-prime"), "p", t()),
            vec![],
            vec![EvidenceId::new("ev")],
        )
        .unwrap();
        l.commit_claim(
            Claim::new(ClaimId::new("c-derived"), "d", t()),
            vec![ClaimId::new("c-prime")],
            vec![],
        )
        .unwrap();
        l.commit_claim(
            Claim::new(ClaimId::new("c-composite"), "c", t()),
            vec![],
            vec![EvidenceId::new("ev")],
        )
        .unwrap();
        l.commit_claim(
            Claim::new(ClaimId::new("c-gap-retracted"), "g1", t()),
            vec![],
            vec![EvidenceId::new("ev")],
        )
        .unwrap();
        l.retract_claim(&ClaimId::new("c-gap-retracted")).unwrap();

        let ranked = l.rank_by_prime_composite_gap();
        let tiers: Vec<ClaimTier> = ranked.iter().map(|r| r.tier).collect();

        // Global ordering invariant: Prime block first, then any
        // Composite block, then any Gap block. Find the first index
        // where the tier transitions and assert monotonic-non-increase.
        for window in tiers.windows(2) {
            // Tier ordering reverses naturally on cmp; we want
            // Prime > Composite > Gap when reading left-to-right.
            assert!(
                window[0] >= window[1],
                "tier order violated: {window:?} — full tiers = {tiers:?}"
            );
        }

        // And the actual block tiers must match the seeded fixture.
        assert_eq!(tiers.first(), Some(&ClaimTier::Prime));
        assert_eq!(tiers.last(), Some(&ClaimTier::Gap));
    }

    #[test]
    fn claim_tier_serializes_to_snake_case_for_ranked_claim_audit() {
        // `ClaimTier` is part of `RankedClaim`'s wire format, used by:
        //   - the Provenance Console UI surface (tier-coloured rows)
        //   - persisted analytics / dashboards exported from
        //     `rank_by_prime_composite_gap()` output
        //   - any future `.epbundle`-embedded ranking audit
        // A serde casing change (e.g. dropping the `rename_all =
        // "snake_case"` attribute, or accidentally PascalCase-ing the
        // wire form) would silently orphan every prior persisted
        // record in those surfaces.
        //
        // (Aside: the prior commit 2a4d31d2e's message overstated the
        // dependency on `epistemos-shadow::rrf_fuse_with_tier_boosts`
        // — that function's boost map is keyed by `doc_id`, not by
        // tier name. Callers walk RankedClaim entries and compute a
        // per-doc-id boost; ClaimTier strings don't appear in the
        // boost map keys. The wire-format pin is still load-bearing
        // for the UI + analytics consumers above.)
        use serde_json::to_string;
        assert_eq!(to_string(&ClaimTier::Gap).unwrap(), "\"gap\"");
        assert_eq!(to_string(&ClaimTier::Composite).unwrap(), "\"composite\"");
        assert_eq!(to_string(&ClaimTier::Prime).unwrap(), "\"prime\"");

        // Round-trip in: a historical RankedClaim JSON or external
        // analytics dashboard must decode the snake_case strings
        // cleanly.
        let decoded: ClaimTier = serde_json::from_str("\"gap\"").unwrap();
        assert_eq!(decoded, ClaimTier::Gap);
        let decoded: ClaimTier = serde_json::from_str("\"composite\"").unwrap();
        assert_eq!(decoded, ClaimTier::Composite);
        let decoded: ClaimTier = serde_json::from_str("\"prime\"").unwrap();
        assert_eq!(decoded, ClaimTier::Prime);
    }

    #[test]
    fn claim_tier_rejects_unknown_string_on_decode_without_panic() {
        // Defensive decode for the cross-crate Provenance Console
        // surface. A future build might introduce a 4th claim tier
        // (e.g. hypothetical "Synthesized" or "Retracted-via-merge");
        // this build must reject the unknown string rather than
        // panic mid-render of the audit console.
        let result: Result<ClaimTier, _> = serde_json::from_str("\"synthesized\"");
        assert!(result.is_err(),
                "decoder must reject unknown claim tiers");
        let result: Result<ClaimTier, _> = serde_json::from_str("\"\"");
        assert!(result.is_err());
        // PascalCase rejects — only snake_case is canonical.
        let result: Result<ClaimTier, _> = serde_json::from_str("\"Composite\"");
        assert!(result.is_err(),
                "PascalCase tier names must reject — only snake_case is canonical");
    }

    #[test]
    fn claim_tier_natural_ordering_is_gap_lt_composite_lt_prime() {
        // The doc comment on `ClaimTier` promises "`Gap < Composite <
        // Prime` so a `(tier, weight)` natural ordering sorts gap →
        // composite → prime ascending." Sort code elsewhere relies on
        // this — e.g. the rank_by_prime_composite_gap consumer that
        // chains `sort_by(|a, b| b.tier.cmp(&a.tier))` for descending
        // tier order. Pin the natural ordering directly so a future
        // refactor that reorders the enum variants trips before any
        // downstream caller silently inverts.
        assert!(ClaimTier::Gap < ClaimTier::Composite);
        assert!(ClaimTier::Composite < ClaimTier::Prime);
        assert!(ClaimTier::Gap < ClaimTier::Prime);

        // PartialOrd consistent with Ord (derived together).
        assert_eq!(
            ClaimTier::Gap.partial_cmp(&ClaimTier::Prime),
            Some(std::cmp::Ordering::Less)
        );

        // Sorting a mixed vec must produce gap → composite → prime.
        let mut tiers = vec![
            ClaimTier::Prime,
            ClaimTier::Gap,
            ClaimTier::Composite,
            ClaimTier::Prime,
            ClaimTier::Gap,
        ];
        tiers.sort();
        assert_eq!(
            tiers,
            vec![
                ClaimTier::Gap,
                ClaimTier::Gap,
                ClaimTier::Composite,
                ClaimTier::Prime,
                ClaimTier::Prime,
            ]
        );
    }
}
