// HARDENING ENFORCEMENT: production paths in this module MUST remain
// unwrap/expect/panic-free. ReplayBundle integrity is the open
// Provenance Standard's contract — a panic during build / verify /
// epbundle-IO would corrupt the audit trail. Every error path returns
// a typed `BundleError`. Tests may unwrap. Updated 2026-04-28.
#![cfg_attr(
    not(test),
    deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)
)]

//! `ReplayBundle` — Phase-1 task 6 from `docs/plan/04_PHASES.md`.
//!
//! Doctrine reference: `01_DOCTRINE.md §5.2 ReplayBundle byte-equivalence
//! guarantee` + `04_PHASES.md` Phase-1 task 6 ("First ReplayBundle export.
//! A button in the chat surface emits a `.epbundle` for a completed run.
//! `epistemos-trace verify` … consumes it and exits 0").
//!
//! A ReplayBundle is the portable artifact that captures everything
//! needed to reconstruct a run for audit:
//!
//! - the ordered list of `MutationEnvelope`s that fired during the run
//! - a `LedgerSnapshot` of the `ClaimLedger` at the moment the bundle
//!   was minted (claims, evidence, and the claim/evidence/derivation
//!   adjacency lists)
//! - a BLAKE3 integrity hash over the canonical serialization of the
//!   bundle content (computed with the hash field set to the empty
//!   string so the hash itself isn't fed into the hash)
//!
//! Pairs with the open-standard parallel track's `epistemos-trace verify`
//! CLI. Phase 1 ships the type + acceptance tests; the CLI binary lands
//! in the sibling `epistemos-provenance-standard` repo.
//!
//! ## Byte-equivalence guarantee
//!
//! Per `04_PHASES.md` Phase-1 acceptance: "2 tests for ReplayBundle
//! byte-equivalence." This module ships THREE such tests:
//!
//! 1. JSON round-trip is byte-equal: serialize → deserialize → serialize
//!    produces identical bytes.
//! 2. Deterministic generation: two bundles built from the same ledger
//!    state are byte-equal at every byte.
//! 3. Tampering invalidates the hash: any single-byte content change
//!    causes `verify_integrity()` to return false.
//!
//! Determinism is achieved by:
//! - Sorting all collections at snapshot time (claims, evidence,
//!   derivations, support links) so vector order is deterministic.
//! - Relying on `serde_json`'s struct-field order matching declaration
//!   order, which it does (this is part of serde's contract).

use serde::{Deserialize, Serialize};
use thiserror::Error;

use crate::cognitive_dag::storage::DagSnapshot;
use crate::mutations::MutationEnvelope;

use super::ledger::{Claim, ClaimId, ClaimLedger, Evidence, EvidenceId};

/// Current schema version for the bundle wire format. Bump in lockstep
/// with the open Provenance Standard's published schemars output.
///
/// History:
/// - v1: claims + evidence + derivations + support_links + mutations
/// - v2: adds optional `dag_snapshot` (Phase 8.F — replay verification
///   via merkle root parity). Old v1 bundles deserialize cleanly under
///   v2 readers; new bundles without a DAG snapshot still emit v1.
pub const REPLAY_BUNDLE_SCHEMA_VERSION: u32 = 2;

/// Schema version for bundles that lack a DAG snapshot. Pre-Phase-8.F
/// callers can stay on this version forever.
pub const REPLAY_BUNDLE_SCHEMA_VERSION_LEDGER_ONLY: u32 = 1;

// ---------------------------------------------------------------------------
// LedgerSnapshot — deterministic view of a `ClaimLedger`
// ---------------------------------------------------------------------------

/// One claim's derivation lineage rendered in flat form for the bundle.
/// `derived_from` is sorted by `ClaimId` so the bundle is deterministic.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ClaimDerivation {
    pub claim: ClaimId,
    pub derived_from: Vec<ClaimId>,
}

/// One claim's evidence-support link rendered flat. `evidence` is sorted
/// by `EvidenceId` so the bundle is deterministic.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ClaimEvidenceLink {
    pub claim: ClaimId,
    pub evidence: Vec<EvidenceId>,
}

/// Snapshot of every relevant adjacency list in a `ClaimLedger`, with
/// every collection sorted at snapshot time. Two snapshots produced
/// from equal ledgers are byte-equal under JSON serialization.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LedgerSnapshot {
    /// All claims in the ledger, sorted by `ClaimId`.
    pub claims: Vec<Claim>,
    /// All evidence in the ledger, sorted by `EvidenceId`.
    pub evidence: Vec<Evidence>,
    /// Derivation graph rendered flat. Empty inner vectors are kept
    /// (so claims with no parents are still present in the snapshot).
    pub derivations: Vec<ClaimDerivation>,
    /// Evidence-support links rendered flat. Empty inner vectors are
    /// kept for symmetry.
    pub support_links: Vec<ClaimEvidenceLink>,
}

impl LedgerSnapshot {
    /// Build a deterministic snapshot from a `ClaimLedger`. The
    /// ledger's internal HashMaps are non-deterministic in iteration
    /// order; this method imposes the canonical sort order so two
    /// snapshots from equal ledgers are byte-equal.
    pub fn from_ledger(ledger: &ClaimLedger) -> Self {
        // Use the public read accessors only — Phase 1 exposes
        // `claim()`, `evidence()`, and counts; the adjacency lists
        // are accessed via the ledger's `claim()` method that returns
        // borrows by ClaimId. We need a way to enumerate; expose
        // helpers on the ledger or pass them through the builder.
        // For Phase 1 we access via the field-public adjacency maps
        // through a typed builder API on the ledger itself.
        //
        // The actual snapshot population happens in
        // `ClaimLedger::snapshot()` (ledger.rs) which has access to
        // its private maps; we just declare the shape here.
        ledger.snapshot()
    }
}

// ---------------------------------------------------------------------------
// ReplayBundle — the .epbundle artifact
// ---------------------------------------------------------------------------

/// Portable replay artifact. Field order matches the canonical wire
/// format; `serde_json` preserves this order across serializations.
///
/// Note on `Eq`: removed in v2 because the optional `dag_snapshot` carries
/// f32 strengths in `EdgeKind` which can't satisfy `Eq`. PartialEq still
/// works and is what every test asserts on.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ReplayBundle {
    /// Wire-format schema version. Readers tolerate higher values by
    /// ignoring unknown fields; writers must bump in lockstep with the
    /// open Provenance Standard. v1 = ledger only; v2 = optional DAG
    /// snapshot (Phase 8.F).
    pub schema_version: u32,
    /// Unique bundle id. Caller chooses the generation strategy
    /// (matches the rest of the codebase's id discipline).
    pub bundle_id: String,
    /// Optional run id when the bundle scopes a single agent run.
    /// Bundles that span multiple runs (cross-session audits) leave
    /// this `None`.
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub run_id: Option<String>,
    /// Unix milliseconds at bundle creation.
    pub generated_at_ms: i64,
    /// Ordered list of mutations that fired during the run. Sorted by
    /// `(run_id, sequence)` at bundle build time so deterministic.
    pub mutations: Vec<MutationEnvelope>,
    /// Ledger state at bundle creation.
    pub ledger: LedgerSnapshot,
    /// Phase 8.F — optional cognitive DAG snapshot. When present, the
    /// epistemos-trace `verify-replay` subcommand re-walks the
    /// snapshot's merkle root to confirm the DAG content has not been
    /// tampered with independently of the ledger. Skipped from
    /// serialization when None so v1 bundles stay byte-identical.
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub dag_snapshot: Option<DagSnapshot>,
    /// BLAKE3 hex (lowercase 64-char) over the canonical JSON of the
    /// bundle WITH `integrity_hash` set to the empty string. Verifiable
    /// via `verify_integrity()`.
    pub integrity_hash: String,
}

#[derive(Debug, Error)]
pub enum BundleError {
    #[error("integrity hash mismatch (stored {stored}, computed {computed})")]
    IntegrityMismatch { stored: String, computed: String },
    #[error("bundle is empty (no mutations and no claims) — refusing to mint")]
    EmptyBundle,
    /// Phase 8.F — DAG snapshot's stored merkle root does not match
    /// the merkle root recomputed from the snapshot's nodes + edges.
    /// The bundle's `integrity_hash` may still match (the DAG snapshot
    /// is part of the hashed payload) — this error specifically calls
    /// out internal DAG inconsistency vs. external tampering.
    #[error("DAG merkle root mismatch (stored {stored}, recomputed {recomputed})")]
    DagMerkleMismatch { stored: String, recomputed: String },
    #[error("serde_json error: {0}")]
    Serde(#[from] serde_json::Error),
}

impl ReplayBundle {
    /// Build a fresh ledger-only bundle (schema v1). Same shape that
    /// shipped pre-Phase-8.F. Use `build_with_dag` to include a DAG
    /// snapshot.
    pub fn build(
        bundle_id: String,
        run_id: Option<String>,
        generated_at_ms: i64,
        ledger: &ClaimLedger,
        mutations: Vec<MutationEnvelope>,
    ) -> Result<Self, BundleError> {
        Self::build_inner(
            bundle_id,
            run_id,
            generated_at_ms,
            ledger,
            mutations,
            None,
            REPLAY_BUNDLE_SCHEMA_VERSION_LEDGER_ONLY,
        )
    }

    /// Phase 8.F — build a bundle that includes a cognitive DAG
    /// snapshot. The snapshot's merkle root carries the canonical
    /// content hash; `verify_replay()` re-walks it during audit.
    /// Schema bumps to v2 to signal the extended payload.
    pub fn build_with_dag(
        bundle_id: String,
        run_id: Option<String>,
        generated_at_ms: i64,
        ledger: &ClaimLedger,
        mutations: Vec<MutationEnvelope>,
        dag_snapshot: DagSnapshot,
    ) -> Result<Self, BundleError> {
        Self::build_inner(
            bundle_id,
            run_id,
            generated_at_ms,
            ledger,
            mutations,
            Some(dag_snapshot),
            REPLAY_BUNDLE_SCHEMA_VERSION,
        )
    }

    fn build_inner(
        bundle_id: String,
        run_id: Option<String>,
        generated_at_ms: i64,
        ledger: &ClaimLedger,
        mut mutations: Vec<MutationEnvelope>,
        dag_snapshot: Option<DagSnapshot>,
        schema_version: u32,
    ) -> Result<Self, BundleError> {
        // Sort mutations by (run_id then sequence) for determinism. A
        // bundle covering multiple runs gets a stable cross-run order.
        mutations.sort_by(|a, b| {
            a.run_id
                .cmp(&b.run_id)
                .then_with(|| a.sequence.cmp(&b.sequence))
                .then_with(|| a.mutation_id.cmp(&b.mutation_id))
        });
        let snapshot = LedgerSnapshot::from_ledger(ledger);
        let dag_is_empty = dag_snapshot
            .as_ref()
            .map(|s| s.nodes.is_empty() && s.edges.is_empty())
            .unwrap_or(true);
        if mutations.is_empty()
            && snapshot.claims.is_empty()
            && snapshot.evidence.is_empty()
            && dag_is_empty
        {
            return Err(BundleError::EmptyBundle);
        }
        let mut bundle = Self {
            schema_version,
            bundle_id,
            run_id,
            generated_at_ms,
            mutations,
            ledger: snapshot,
            dag_snapshot,
            integrity_hash: String::new(),
        };
        let hash = bundle.compute_integrity_hash()?;
        bundle.integrity_hash = hash;
        Ok(bundle)
    }

    /// Compute the BLAKE3 hash over the canonical JSON form of the
    /// bundle WITH `integrity_hash` set to the empty string. Used both
    /// by `build()` (to fill the field) and by `verify_integrity()`
    /// (to validate it).
    pub fn compute_integrity_hash(&self) -> Result<String, BundleError> {
        let mut hashable = self.clone();
        hashable.integrity_hash = String::new();
        let bytes = serde_json::to_vec(&hashable)?;
        let h = blake3::hash(&bytes);
        Ok(h.to_hex().to_string())
    }

    /// Recompute and compare against the stored hash. Returns `Ok(())`
    /// on match, `Err(IntegrityMismatch)` on tamper, or any
    /// serialization error.
    pub fn verify_integrity(&self) -> Result<(), BundleError> {
        let computed = self.compute_integrity_hash()?;
        if computed == self.integrity_hash {
            Ok(())
        } else {
            Err(BundleError::IntegrityMismatch {
                stored: self.integrity_hash.clone(),
                computed,
            })
        }
    }

    /// Phase 8.F — full replay verification. Runs `verify_integrity()`
    /// FIRST (the bundle-wide BLAKE3 hash chain — catches any external
    /// tampering of any field), then if a DAG snapshot is present,
    /// recomputes the merkle root over the snapshot's nodes + edges
    /// and compares to the snapshot's stored merkle_root.
    ///
    /// The two checks are complementary:
    /// - `verify_integrity` catches edits to the bundle bytes after
    ///   minting (anything from a flipped char in claim text to a
    ///   swapped DAG node).
    /// - DAG merkle parity catches the rare case where the snapshot's
    ///   internal merkle_root field disagrees with the actual node /
    ///   edge content — which only happens if the snapshot was
    ///   constructed incorrectly OR if the merkle_root_over algorithm
    ///   itself is non-deterministic. Both are doctrine §1.3 hard
    ///   contracts.
    ///
    /// Returns `Ok(())` on success. Bundles WITHOUT a dag_snapshot
    /// short-circuit to integrity-only verification.
    pub fn verify_replay(&self) -> Result<(), BundleError> {
        self.verify_integrity()?;
        if let Some(ref snapshot) = self.dag_snapshot {
            // Recompute the merkle root from scratch over the
            // snapshot's sorted nodes + edges. The cognitive_dag
            // module's `merkle_root_over` is the canonical
            // computation per doctrine §1.3.
            // Edge ids are computed from the (from, to, kind) tuple; cache
            // them once so the merkle walk + the borrow vec see the same
            // EdgeId values.
            let edge_ids_owned: Vec<crate::cognitive_dag::edge::EdgeId> =
                snapshot.edges.iter().map(|e| e.id()).collect();
            let node_ids: Vec<&crate::cognitive_dag::node::NodeId> =
                snapshot.nodes.iter().map(|n| &n.id).collect();
            let edge_ids: Vec<&crate::cognitive_dag::edge::EdgeId> =
                edge_ids_owned.iter().collect();
            let recomputed = crate::cognitive_dag::merkle::merkle_root_over(&node_ids, &edge_ids);
            if recomputed != snapshot.merkle_root {
                let mut stored_hex = String::with_capacity(64);
                let mut recomp_hex = String::with_capacity(64);
                use std::fmt::Write;
                for byte in snapshot.merkle_root.as_bytes() {
                    let _ = write!(&mut stored_hex, "{:02x}", byte);
                }
                for byte in recomputed.as_bytes() {
                    let _ = write!(&mut recomp_hex, "{:02x}", byte);
                }
                return Err(BundleError::DagMerkleMismatch {
                    stored: stored_hex,
                    recomputed: recomp_hex,
                });
            }
        }
        Ok(())
    }

    /// Serialize to a `.epbundle` byte payload (canonical JSON). The
    /// `epistemos-trace verify` CLI consumes exactly this format.
    pub fn to_epbundle_bytes(&self) -> Result<Vec<u8>, BundleError> {
        Ok(serde_json::to_vec(self)?)
    }

    /// Parse a `.epbundle` payload. Verification is the caller's
    /// responsibility (call `verify_integrity()` after parsing).
    pub fn from_epbundle_bytes(bytes: &[u8]) -> Result<Self, BundleError> {
        Ok(serde_json::from_slice(bytes)?)
    }
}

// ---------------------------------------------------------------------------
// Tests — the doctrine's "2 tests for ReplayBundle byte-equivalence" + extras
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::mutations::types::{MutationActor, Reversibility, Sensitivity, SourceOp};

    fn t() -> i64 {
        1_745_000_000_000
    }

    fn seed_ledger() -> ClaimLedger {
        let mut l = ClaimLedger::new();
        l.commit_evidence(Evidence::new(EvidenceId::new("ev-1"), "arxiv://1234", t()))
            .unwrap();
        l.commit_evidence(Evidence::new(EvidenceId::new("ev-2"), "doi://5678", t()))
            .unwrap();
        l.commit_claim(
            Claim::new(ClaimId::new("c1"), "ground truth", t()),
            vec![],
            vec![EvidenceId::new("ev-1")],
        )
        .unwrap();
        l.commit_claim(
            Claim::new(ClaimId::new("c2"), "derived", t()),
            vec![ClaimId::new("c1")],
            vec![EvidenceId::new("ev-2")],
        )
        .unwrap();
        l
    }

    fn seed_mutation(seq: u64, mid: &str) -> MutationEnvelope {
        MutationEnvelope::pending(
            mid.to_string(),
            seq,
            MutationActor::User,
            SourceOp::ArtifactUpdate {
                artifact_id: "doc-1".to_string(),
            },
            Sensitivity::Internal,
            Reversibility::Reversible,
            t(),
        )
    }

    fn seed_bundle() -> ReplayBundle {
        let ledger = seed_ledger();
        let mutations = vec![seed_mutation(2, "m-2"), seed_mutation(1, "m-1")];
        ReplayBundle::build(
            "bundle-test".to_string(),
            Some("run-test".to_string()),
            t(),
            &ledger,
            mutations,
        )
        .unwrap()
    }

    // -- Phase-1 acceptance test 1: JSON round-trip byte-equality --------

    #[test]
    fn json_round_trip_is_byte_equal() {
        let b1 = seed_bundle();
        let json1 = serde_json::to_vec(&b1).unwrap();
        let recovered: ReplayBundle = serde_json::from_slice(&json1).unwrap();
        let json2 = serde_json::to_vec(&recovered).unwrap();
        assert_eq!(
            json1, json2,
            "ReplayBundle must round-trip through JSON byte-equally"
        );
        // And the structs must compare equal via `PartialEq`.
        assert_eq!(b1, recovered);
    }

    // -- Phase-1 acceptance test 2: deterministic build -----------------

    #[test]
    fn deterministic_build_from_equal_ledgers() {
        let l1 = seed_ledger();
        let l2 = seed_ledger();
        let muts1 = vec![seed_mutation(2, "m-2"), seed_mutation(1, "m-1")];
        let muts2 = vec![seed_mutation(1, "m-1"), seed_mutation(2, "m-2")]; // shuffled
        let b1 = ReplayBundle::build(
            "bundle-X".to_string(),
            Some("run-X".to_string()),
            t(),
            &l1,
            muts1,
        )
        .unwrap();
        let b2 = ReplayBundle::build(
            "bundle-X".to_string(),
            Some("run-X".to_string()),
            t(),
            &l2,
            muts2,
        )
        .unwrap();
        let json1 = serde_json::to_vec(&b1).unwrap();
        let json2 = serde_json::to_vec(&b2).unwrap();
        assert_eq!(
            json1, json2,
            "two bundles built from equal ledgers + same mutation set must be byte-equal regardless of input order"
        );
    }

    // -- Bonus test: tampering invalidates the integrity hash -----------

    #[test]
    fn tampering_invalidates_integrity_hash() {
        let mut b = seed_bundle();
        // First, the freshly-built bundle verifies.
        b.verify_integrity()
            .expect("freshly-built bundle must verify");

        // Now tamper: flip a byte in a claim's text. Re-verify must fail.
        if let Some(c) = b.ledger.claims.first_mut() {
            c.text.push('!');
        }
        match b.verify_integrity() {
            Err(BundleError::IntegrityMismatch { stored, computed }) => {
                assert_ne!(stored, computed);
            }
            other => panic!("expected IntegrityMismatch, got {other:?}"),
        }
    }

    // -- Substrate sanity tests -----------------------------------------

    #[test]
    fn empty_inputs_are_rejected() {
        let empty_ledger = ClaimLedger::new();
        let err =
            ReplayBundle::build("empty".to_string(), None, t(), &empty_ledger, vec![]).unwrap_err();
        assert!(matches!(err, BundleError::EmptyBundle));
    }

    #[test]
    fn epbundle_bytes_round_trip() {
        let b1 = seed_bundle();
        let bytes = b1.to_epbundle_bytes().unwrap();
        let b2 = ReplayBundle::from_epbundle_bytes(&bytes).unwrap();
        assert_eq!(b1, b2);
        b2.verify_integrity().unwrap();
    }

    #[test]
    fn integrity_hash_is_64_char_lowercase_hex() {
        let b = seed_bundle();
        assert_eq!(b.integrity_hash.len(), 64, "BLAKE3 hex is 64 chars");
        assert!(
            b.integrity_hash
                .chars()
                .all(|c| c.is_ascii_hexdigit() && (c.is_numeric() || c.is_ascii_lowercase())),
            "BLAKE3 hex must be lowercase: got `{}`",
            b.integrity_hash
        );
    }

    #[test]
    fn snapshot_orders_collections_by_id() {
        let mut l = ClaimLedger::new();
        // Insert in reverse alphabetical order; snapshot must yield
        // alphabetical order regardless.
        l.commit_evidence(Evidence::new(EvidenceId::new("ev-z"), "src", t()))
            .unwrap();
        l.commit_evidence(Evidence::new(EvidenceId::new("ev-a"), "src", t()))
            .unwrap();
        l.commit_claim(Claim::new(ClaimId::new("c-z"), "z", t()), vec![], vec![])
            .unwrap();
        l.commit_claim(Claim::new(ClaimId::new("c-a"), "a", t()), vec![], vec![])
            .unwrap();
        let snap = LedgerSnapshot::from_ledger(&l);
        assert_eq!(snap.claims[0].id, ClaimId::new("c-a"));
        assert_eq!(snap.claims[1].id, ClaimId::new("c-z"));
        assert_eq!(snap.evidence[0].id, EvidenceId::new("ev-a"));
        assert_eq!(snap.evidence[1].id, EvidenceId::new("ev-z"));
    }

    // ── Phase 8.F — verify_replay tests ────────────────────────────────────

    use crate::cognitive_dag::edge::{Edge, EdgeKind};
    use crate::cognitive_dag::node::{
        AuthorRef, ClaimScope, EvidenceBlob, EvidenceKind, Hash, MimeType, Node, NodeKind,
        SourceRef, Timestamp,
    };
    use crate::cognitive_dag::storage::{DagStore, InMemoryDagStore};

    fn seed_dag_snapshot() -> crate::cognitive_dag::storage::DagSnapshot {
        let store = InMemoryDagStore::new();
        let note = Node::new_at(
            NodeKind::Note {
                body: "phase 8.f test".into(),
                author: AuthorRef("test".into()),
                mime: MimeType("text/markdown".into()),
            },
            Timestamp(1000),
        );
        let claim = Node::new_at(
            NodeKind::Claim {
                proposition: "verify_replay works".into(),
                scope: ClaimScope::Vault,
                source: SourceRef("phase_8f_test".into()),
            },
            Timestamp(1100),
        );
        let evidence = Node::new_at(
            NodeKind::Evidence {
                kind: EvidenceKind::Citation,
                payload: EvidenceBlob(b"phase8f-payload".to_vec()),
                captured_at: Timestamp(1050),
            },
            Timestamp(1050),
        );
        let cap = Hash::from_bytes([0xE5u8; 32]);
        for n in [&note, &claim, &evidence] {
            store.put_node(n.clone()).unwrap();
        }
        let edge = Edge::new_at(
            claim.id,
            evidence.id,
            EdgeKind::DerivesFrom { strength: 0.9 },
            cap,
            Timestamp(1200),
        );
        store.put_edge(edge).unwrap();
        store.snapshot().unwrap()
    }

    #[test]
    fn build_with_dag_emits_v2_schema() {
        let ledger = seed_ledger();
        let mutations = vec![seed_mutation(1, "m-1")];
        let dag = seed_dag_snapshot();
        let bundle = ReplayBundle::build_with_dag(
            "phase8f-bundle".to_string(),
            None,
            t(),
            &ledger,
            mutations,
            dag,
        )
        .unwrap();
        assert_eq!(bundle.schema_version, REPLAY_BUNDLE_SCHEMA_VERSION);
        assert!(bundle.dag_snapshot.is_some());
        assert!(bundle.dag_snapshot.as_ref().unwrap().nodes.len() >= 3);
    }

    #[test]
    fn ledger_only_build_stays_v1_schema() {
        let ledger = seed_ledger();
        let bundle = ReplayBundle::build("v1".to_string(), None, t(), &ledger, vec![]).unwrap();
        assert_eq!(
            bundle.schema_version,
            REPLAY_BUNDLE_SCHEMA_VERSION_LEDGER_ONLY
        );
        assert!(bundle.dag_snapshot.is_none());
    }

    #[test]
    fn verify_replay_accepts_clean_bundle_with_dag() {
        let ledger = seed_ledger();
        let dag = seed_dag_snapshot();
        let bundle = ReplayBundle::build_with_dag(
            "clean".to_string(),
            None,
            t(),
            &ledger,
            vec![seed_mutation(1, "m-1")],
            dag,
        )
        .unwrap();
        bundle
            .verify_replay()
            .expect("clean bundle with DAG must verify");
    }

    #[test]
    fn verify_replay_accepts_clean_ledger_only_bundle() {
        // Bundles WITHOUT a DAG snapshot short-circuit to integrity-only
        // verification — important for backward compat with v1 bundles.
        let ledger = seed_ledger();
        let bundle = ReplayBundle::build(
            "v1-clean".to_string(),
            None,
            t(),
            &ledger,
            vec![seed_mutation(1, "m-1")],
        )
        .unwrap();
        bundle.verify_replay().expect("clean v1 bundle must verify");
    }

    #[test]
    fn verify_replay_catches_tampered_dag_merkle_root() {
        let ledger = seed_ledger();
        let dag = seed_dag_snapshot();
        let mut bundle = ReplayBundle::build_with_dag(
            "tampered".to_string(),
            None,
            t(),
            &ledger,
            vec![seed_mutation(1, "m-1")],
            dag,
        )
        .unwrap();
        // Tamper with the snapshot's merkle_root field directly. The
        // bundle-wide integrity hash will ALSO mismatch (because the
        // dag_snapshot is part of the hashed payload), but verify_integrity
        // catches that first. Re-fix the integrity hash so verify_replay
        // gets to the DAG merkle parity check, and confirm THAT fires.
        bundle.dag_snapshot.as_mut().unwrap().merkle_root = Hash::from_bytes([0xFFu8; 32]);
        bundle.integrity_hash = bundle.compute_integrity_hash().unwrap();
        let err = bundle
            .verify_replay()
            .expect_err("DAG merkle tamper must fail verify_replay");
        assert!(matches!(err, BundleError::DagMerkleMismatch { .. }));
    }

    #[test]
    fn verify_replay_catches_outer_integrity_tamper_first() {
        // If both the outer hash AND the DAG merkle are wrong, the outer
        // integrity check fires first — that's the canonical surface for
        // "the bundle bytes were edited."
        let ledger = seed_ledger();
        let dag = seed_dag_snapshot();
        let mut bundle = ReplayBundle::build_with_dag(
            "double-tamper".to_string(),
            None,
            t(),
            &ledger,
            vec![seed_mutation(1, "m-1")],
            dag,
        )
        .unwrap();
        // Tamper with a claim text — invalidates the outer hash.
        bundle.ledger.claims[0].text.push('!');
        let err = bundle
            .verify_replay()
            .expect_err("outer-hash tamper must fail verify_replay");
        assert!(matches!(err, BundleError::IntegrityMismatch { .. }));
    }

    #[test]
    fn v2_bundle_round_trips_through_epbundle_bytes() {
        let ledger = seed_ledger();
        let dag = seed_dag_snapshot();
        let b1 = ReplayBundle::build_with_dag(
            "rt".to_string(),
            None,
            t(),
            &ledger,
            vec![seed_mutation(1, "m-1")],
            dag,
        )
        .unwrap();
        let bytes = b1.to_epbundle_bytes().unwrap();
        let b2 = ReplayBundle::from_epbundle_bytes(&bytes).unwrap();
        // PartialEq still works (we removed Eq because of f32 strengths).
        assert_eq!(b1, b2);
        b2.verify_replay()
            .expect("round-tripped v2 bundle must verify");
    }
}
