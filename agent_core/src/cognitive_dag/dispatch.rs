//! Phase 8.E auto-invoke dispatch.
//!
//! The four DagMirror impls
//! (`SkillsMirror` / `ProceduralMirror` / `ProvenanceLedgerMirror` /
//! `CompanionMirror`) are reachable from test code + direct callers,
//! but for the doctrine §10 verification gate to fire ("two consecutive
//! weeks of CI green with mirrors writing on every legacy write") the
//! legacy write paths must auto-invoke them.
//!
//! This module exposes the thin top-level dispatch surface that those
//! write paths call. Each `on_*` helper:
//!   1. Builds the DagMirror mutation from the legacy data type.
//!   2. Calls the mirror's `mirror_write` against the process-global
//!      DAG store.
//!   3. Logs failures with `tracing::warn!` but never propagates them
//!      — a mirror failure must NOT break the legacy write. (Doctrine
//!      §10: legacy stores stay authoritative until Phase 8.H.)
//!
//! Reads through `cognitive_dag_store()` are the canonical app-wide
//! DAG accessor. The bridge.rs FFI surface uses the same accessor so
//! Settings → Diagnostics → "Cognitive DAG" stats reflect every
//! mirror write the moment it lands.

use std::sync::OnceLock;

use crate::provenance::ledger::{Claim, ClaimId, Evidence, EvidenceId};

use super::migration::{
    CompanionMutation, DagMirror, LedgerMutation, ProceduralMirror, ProcedureMutation,
    ProvenanceLedgerMirror, SkillsMirror,
};
use super::node::Hash;
use super::storage::InMemoryDagStore;

/// Process-global cognitive DAG store. Initialized lazily on first
/// access. The InMemoryDagStore is `Send + Sync` (RwLock-protected
/// internally) so we can share a `&'static` reference across the FFI
/// boundary + the auto-dispatch helpers without an outer Mutex.
///
/// **Doctrine §10 contract:** this is the single global DAG instance
/// the four DagMirror impls write to. The bridge.rs FFI surface
/// (`cognitive_dag_stats_json`) reads from this same instance so
/// Settings → Diagnostics + Halo ledger ribbon reflect mirror writes
/// in real time.
pub fn cognitive_dag_store() -> &'static InMemoryDagStore {
    static DAG: OnceLock<InMemoryDagStore> = OnceLock::new();
    DAG.get_or_init(|| {
        let store = InMemoryDagStore::new();
        // Phase 8.C / CD-005: register the system-mirror sentinel
        // capability hash so dispatch-emitted edges verify under
        // capability-bound `put_edge` enforcement instead of falling
        // back to the Phase 8.A structural-only guard. Doctrine §1.2:
        // every edge MUST be signed under a held capability + the
        // store MUST verify against the registered set on insert.
        //
        // The sentinel is the all-`0xE5` hash matching
        // `system_mirror_capability_hash()` below. As Phase 8.C's
        // macaroon-derived caps come online, callers will register
        // those too via DagStore::register_capability(...) and the
        // sentinel becomes one of N accepted caps.
        use crate::cognitive_dag::storage::DagStore;
        let _ = store.register_capability(system_mirror_capability_hash());
        store
    })
}

/// Default capability hash for system-initiated mirror writes. Carries
/// the doctrine §1.2 EdgeSignature contract — Phase 8.A landed
/// content-hash signing; Phase 8.C's macaroon system will replace this
/// with derived caps once macaroons reach the dispatch layer.
///
/// The 32-byte byte pattern `0xE5` is a sentinel — searchable across
/// the codebase, structurally distinct from `0x00` (empty hash) and
/// `0xFF` (max hash), and stable across all auto-dispatch sites so
/// edges they emit can be filtered by signature for audit views.
fn system_mirror_capability_hash() -> Hash {
    Hash::from_bytes([0xE5u8; 32])
}

// ── Provenance ledger auto-dispatch ────────────────────────────────────────

/// Mirror an Evidence commit into the DAG. Called from
/// `ClaimLedger::commit_evidence` after the legacy insert succeeds.
/// Failures are logged but never returned — a mirror miss must not
/// break the legacy write.
pub fn on_evidence_committed(e: &Evidence) {
    let mutation = LedgerMutation::EvidenceCommitted {
        evidence_id: e.id.0.clone(),
        source: e.source.clone(),
        created_at_ms: e.created_at_ms,
    };
    if let Err(err) = ProvenanceLedgerMirror::mirror_write(
        &mutation,
        cognitive_dag_store(),
        system_mirror_capability_hash(),
    ) {
        // Per canonical-upgrade-audit C1 (2026-05-05): tracing is
        // already a workspace dep and used elsewhere; structured
        // observability beats stderr for the mirror failure paths
        // because the doctrine §10 verification window will sample
        // these logs.
        tracing::warn!(
            target: "cognitive_dag::dispatch",
            mirror = "ProvenanceLedgerMirror",
            mutation = "evidence_committed",
            evidence_id = %e.id.0,
            error = %err,
            "mirror write failed"
        );
    }
}

/// Mirror a Claim commit into the DAG. Called from
/// `ClaimLedger::commit_claim` after the legacy insert + lineage check
/// succeed. Failures are logged but never returned.
pub fn on_claim_committed(
    claim: &Claim,
    derived_from: &[ClaimId],
    supported_by: &[EvidenceId],
) {
    let mutation = LedgerMutation::ClaimCommitted {
        claim_id: claim.id.0.clone(),
        text: claim.text.clone(),
        derived_from: derived_from.iter().map(|id| id.0.clone()).collect(),
        supported_by: supported_by.iter().map(|id| id.0.clone()).collect(),
        created_at_ms: claim.created_at_ms,
    };
    if let Err(err) = ProvenanceLedgerMirror::mirror_write(
        &mutation,
        cognitive_dag_store(),
        system_mirror_capability_hash(),
    ) {
        tracing::warn!(
            target: "cognitive_dag::dispatch",
            mirror = "ProvenanceLedgerMirror",
            mutation = "claim_committed",
            claim_id = %claim.id.0,
            error = %err,
            "mirror write failed"
        );
    }
}

// ── Procedural memory auto-dispatch ────────────────────────────────────────

use crate::agent_runtime::procedural_memory::ProcedureOutcomeRecord;

/// Mirror a procedure outcome record into the DAG. Called from
/// `ProceduralMemoryStore::record_outcome` after the legacy SQLite
/// insert succeeds. Failures are logged but never returned.
///
/// **Note on the parent-Skill contract.** ProceduralMirror requires
/// the parent Skill node to be in the DAG already (doctrine: don't
/// silently invent parents). Until SkillsMirror auto-invocation
/// catches up, procedure mirrors against unknown skills will log a
/// `NodeNotFound` warning — that's the doctrine-expected drift signal.
/// The right fix is to wire SkillRouter::load to dispatch
/// `on_skills_loaded` at startup so the parent skills are always
/// mirrored before the first procedure outcome arrives.
pub fn on_procedure_recorded(record: &ProcedureOutcomeRecord) {
    let mutation = ProcedureMutation::Record {
        skill_name: record.skill_name.clone(),
        invocation_context_hash_hex: record.invocation_context_hash.clone(),
        steps_taken: record.steps_taken.clone(),
        outcome_summary: record.outcome_summary.clone(),
        succeeded: record.succeeded,
        duration_ms: record.duration_ms,
        occurred_at_unix_seconds: record.occurred_at_unix_seconds,
    };
    if let Err(err) = ProceduralMirror::mirror_write(
        &mutation,
        cognitive_dag_store(),
        system_mirror_capability_hash(),
    ) {
        tracing::warn!(
            target: "cognitive_dag::dispatch",
            mirror = "ProceduralMirror",
            mutation = "procedure_recorded",
            skill_name = %record.skill_name,
            error = %err,
            "mirror write failed"
        );
    }
}

// ── Skills auto-dispatch ───────────────────────────────────────────────────

use crate::skill_router::SkillEntry;
use super::migration::SkillMutation;

/// Mirror the SkillRouter's loaded skills into the DAG. Called from
/// `SkillRouter::load` once the directory scan completes; one Register
/// mutation per loaded skill. Idempotent on the SkillsMirror side
/// (re-registering the same skill content is a no-op via content
/// addressing), so repeated load() calls don't bloat the DAG.
///
/// The mirror call surface is intentionally bulk: the dispatch fires
/// after the legacy SkillRouter has loaded everything, so the DAG
/// always has the full skill catalog before any procedure outcome can
/// reference an unknown parent skill (see `on_procedure_recorded`).
pub fn on_skills_loaded(skills: &[SkillEntry]) {
    for entry in skills {
        // Map SkillEntry → DagMirror's SkillMutation::Register shape.
        //
        // Phase 8.E note on tool steps: today's SkillEntry doesn't
        // expose a structured tool list — the tool references live
        // inside the skill body markdown. Until the body parser
        // exists, register the Skill node with an empty steps list.
        // This still lands the parent Skill in the DAG (which is the
        // doctrine §10 requirement so procedure outcomes can resolve
        // their parent), and step-level Invokes edges arrive in the
        // Phase 8.E body-parser slice. SkillEntry's `triggers` stay
        // routing-layer concerns and aren't part of the DAG schema
        // per doctrine §2.2.
        let mutation = SkillMutation::Register {
            name: entry.name.clone(),
            description: entry.description.clone(),
            schema_version: 1,
            steps: Vec::new(),
        };
        if let Err(err) = SkillsMirror::mirror_write(
            &mutation,
            cognitive_dag_store(),
            system_mirror_capability_hash(),
        ) {
            tracing::warn!(
                target: "cognitive_dag::dispatch",
                mirror = "SkillsMirror",
                mutation = "skill_register",
                skill_name = %entry.name,
                error = %err,
                "mirror write failed"
            );
        }
    }
}

// ── Companion auto-dispatch ────────────────────────────────────────────────

use super::node::{IdentityHash, ModelProfile, NodeId, PersonaBlob};
use std::path::PathBuf;

/// Mirror a companion registration into the DAG. The CompanionRegistry
/// already writes Companion + Deforms edges natively (Phase 8.D), so
/// this dispatch helper is for callers that ONLY know the
/// CompanionMutation::Register shape — typically test infrastructure
/// + the future cross-language bridge from Swift's CompanionState.
///
/// Returns the new Companion's NodeId on success so callers can chain
/// further ops (companion-derived edges, etc.). Errors are logged AND
/// returned because companion creation is meant to be observable from
/// the caller (unlike fire-and-forget claim/evidence/procedure writes).
pub fn on_companion_registered(
    profile: ModelProfile,
    identity: IdentityHash,
    persona: PersonaBlob,
    base_model_id: NodeId,
    lora_path: PathBuf,
    weight_alpha: f32,
) -> Option<NodeId> {
    let mutation = CompanionMutation::Register {
        profile,
        identity,
        persona,
        base_model_id,
        lora_path,
        weight_alpha,
    };
    use super::migration::CompanionMirror;
    match CompanionMirror::mirror_write(
        &mutation,
        cognitive_dag_store(),
        system_mirror_capability_hash(),
    ) {
        Ok(id) => Some(id),
        Err(err) => {
            tracing::warn!(
                target: "cognitive_dag::dispatch",
                mirror = "CompanionMirror",
                mutation = "companion_register",
                error = %err,
                "mirror write failed"
            );
            None
        }
    }
}

// ── Tests ──────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::provenance::ledger::ClaimLedger;

    /// Test isolation note: the DAG is process-global so tests in this
    /// module share state with every other test that exercises the
    /// dispatch surface. All assertions below are MONOTONIC (counts
    /// only go up; we record the baseline at the start and assert the
    /// delta) so test ordering doesn't matter.
    fn baseline_node_count() -> usize {
        use crate::cognitive_dag::storage::DagStore;
        cognitive_dag_store().snapshot().unwrap().nodes.len()
    }

    #[test]
    fn on_evidence_committed_populates_dag() {
        let baseline = baseline_node_count();
        let evidence = Evidence::new(
            EvidenceId::new(format!("ev-dispatch-test-{}", baseline)),
            "https://example.com/auto-invoke-source",
            1_700_000_000_000,
        );
        on_evidence_committed(&evidence);
        let after = baseline_node_count();
        assert!(after > baseline, "evidence dispatch must add at least one node");
    }

    #[test]
    fn on_claim_committed_populates_dag() {
        let baseline = baseline_node_count();
        let claim = Claim::new(
            ClaimId::new(format!("claim-dispatch-test-{}", baseline)),
            "Auto-invoke claim text",
            1_700_000_000_000,
        );
        on_claim_committed(&claim, &[], &[]);
        let after = baseline_node_count();
        assert!(after > baseline, "claim dispatch must add at least one node");
    }

    #[test]
    fn ledger_commit_evidence_auto_invokes_mirror() {
        let mut ledger = ClaimLedger::new();
        let baseline = baseline_node_count();
        let evidence = Evidence::new(
            EvidenceId::new(format!("ev-ledger-auto-{}", baseline)),
            "https://example.com/ledger-auto",
            1_700_000_000_000,
        );
        ledger.commit_evidence(evidence).unwrap();
        let after = baseline_node_count();
        assert!(
            after > baseline,
            "ClaimLedger::commit_evidence must auto-fire the dispatch"
        );
    }

    #[test]
    fn ledger_commit_claim_auto_invokes_mirror() {
        let mut ledger = ClaimLedger::new();
        let baseline = baseline_node_count();
        let claim = Claim::new(
            ClaimId::new(format!("claim-ledger-auto-{}", baseline)),
            "Auto-invoked claim",
            1_700_000_000_000,
        );
        ledger.commit_claim(claim, vec![], vec![]).unwrap();
        let after = baseline_node_count();
        assert!(
            after > baseline,
            "ClaimLedger::commit_claim must auto-fire the dispatch"
        );
    }

    #[test]
    fn system_mirror_capability_hash_is_stable_sentinel() {
        let h1 = system_mirror_capability_hash();
        let h2 = system_mirror_capability_hash();
        assert_eq!(h1, h2);
        // Sentinel byte pattern is 0xE5 — distinct from 0x00 and 0xFF
        // so dispatch-emitted edges can be filtered by signature for
        // audit views.
        assert_eq!(h1.as_bytes()[0], 0xE5);
        assert_eq!(h1.as_bytes()[31], 0xE5);
    }
}
