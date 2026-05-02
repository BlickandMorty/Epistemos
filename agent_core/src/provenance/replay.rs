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

use crate::mutations::MutationEnvelope;

use super::ledger::{Claim, ClaimId, ClaimLedger, Evidence, EvidenceId};

/// Current schema version for the bundle wire format. Bump in lockstep
/// with the open Provenance Standard's published schemars output.
pub const REPLAY_BUNDLE_SCHEMA_VERSION: u32 = 1;

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
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ReplayBundle {
    /// Wire-format schema version. Readers tolerate higher values by
    /// ignoring unknown fields; writers must bump in lockstep with the
    /// open Provenance Standard.
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
    #[error("serde_json error: {0}")]
    Serde(#[from] serde_json::Error),
}

impl ReplayBundle {
    /// Build a fresh bundle from a ledger + ordered mutations. Computes
    /// the integrity hash last, after every other field is settled.
    pub fn build(
        bundle_id: String,
        run_id: Option<String>,
        generated_at_ms: i64,
        ledger: &ClaimLedger,
        mut mutations: Vec<MutationEnvelope>,
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
        if mutations.is_empty() && snapshot.claims.is_empty() && snapshot.evidence.is_empty() {
            return Err(BundleError::EmptyBundle);
        }
        let mut bundle = Self {
            schema_version: REPLAY_BUNDLE_SCHEMA_VERSION,
            bundle_id,
            run_id,
            generated_at_ms,
            mutations,
            ledger: snapshot,
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
}
