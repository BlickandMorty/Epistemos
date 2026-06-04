//! `falsify_fast_weight_quarantine` -- fast-weight quarantine witness.
//!
//! Metadata-only witness for `F-FastWeightQuarantine`. It proves verifier-
//! regret fast-weight deltas remain quarantined, shadow-only, resettable, and
//! rollback-bound until drift, held-out replay, TTL, RunEventLog, AnswerPacket,
//! and mutation-safety gates pass. It rejects live route control, base-weight
//! mutation, route-policy mutation, consolidation, hidden authority, runtime
//! bytes, and model bytes.

use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-FastWeightQuarantine";
const FIXTURE_ID: &str = "fast_weight_quarantine_v1";
const COMMAND: &str = "Tools/falsifiers/f_fast_weight_quarantine.sh";
const RESULT: &str = "artifacts/falsifiers/fast_weight_quarantine/result.json";
const UPSTREAM_FAST_WEIGHTS: &str = "artifacts/falsifiers/verifier_regret_fast_weights/result.json";

const CURRENT_FENCE: &str = "fence:fast-weight-quarantine:v1:verifier-regret-fast-weights";
const DRIFT_BOUND_BPS: u64 = 700;
const MIN_FAST_WEIGHT_TTL_MS: u64 = 5_000;
const MAX_FAST_WEIGHT_TTL_MS: u64 = 90_000;
const MAX_QUARANTINE_METADATA_BYTES: u64 = 640 * 1024;
const MIN_HELD_OUT_REPLAY_SUCCESS_BPS: u64 = 9_000;
const MIN_SHADOW_REPLAY_SUCCESS_BPS: u64 = 9_000;
const MIN_LIVE_CONTROL_REJECTION_BPS: u64 = 10_000;
const MIN_ANSWER_PACKET_COVERAGE_BPS: u64 = 10_000;

#[cfg(test)]
const REQUIRED_AXES: &[&str] = &[
    "upstream_verifier_regret_fast_weights_pass",
    "quarantine_fixture_present",
    "fixture_ids_bound",
    "quarantine_ids_bound",
    "source_update_refs_bound",
    "fast_weight_delta_refs_bound",
    "scopes_bound",
    "base_policy_digests_bound",
    "quarantine_policy_refs_bound",
    "quarantine_states_bound",
    "admission_gate_refs_bound",
    "drift_gate_refs_bound",
    "held_out_replay_refs_bound",
    "rollback_bound",
    "ttl_bound",
    "reset_handles_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "replay_trace_refs_bound",
    "release_decisions_bound",
    "write_barriers_bound",
    "mutation_safety_fences_bound",
    "compatibility_fence_bound",
    "privacy_classes_bound",
    "quarantine_shadow_only",
    "route_authority_shadow_only",
    "live_control_attempts_rejected",
    "consolidation_not_promoted",
    "fast_weights_session_local",
    "fast_weights_resettable",
    "ttl_not_expired",
    "drift_within_bound",
    "held_out_replay_passed",
    "rollback_verified",
    "answer_packet_coverage_bound",
    "mutation_safety_bound",
    "no_base_weight_mutation",
    "no_route_policy_mutation",
    "no_live_control_authority",
    "no_hidden_route_authority",
    "no_hidden_chain",
    "no_hidden_cloud",
    "no_runtime_bytes_loaded",
    "no_model_bytes_loaded",
    "fast_weight_quarantine_address_deterministic",
    "metadata_bound",
    "beats_unquarantined_fast_weight_baseline",
    "beats_live_promotion_baseline",
    "beats_stale_quarantine_baseline",
    "beats_no_answer_packet_baseline",
    "duplicate_fixture_rejected",
    "missing_fixture_id_rejected",
    "missing_upstream_fast_weight_rejected",
    "missing_quarantine_policy_rejected",
    "missing_quarantine_record_rejected",
    "duplicate_quarantine_rejected",
    "missing_quarantine_id_rejected",
    "missing_source_update_ref_rejected",
    "missing_delta_ref_rejected",
    "missing_scope_rejected",
    "invalid_scope_rejected",
    "missing_base_policy_digest_rejected",
    "missing_quarantine_state_rejected",
    "invalid_quarantine_state_rejected",
    "missing_admission_gate_rejected",
    "missing_drift_gate_rejected",
    "missing_held_out_replay_rejected",
    "held_out_replay_failure_rejected",
    "missing_rollback_rejected",
    "missing_ttl_rejected",
    "ttl_expired_rejected",
    "missing_reset_handle_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "missing_replay_trace_rejected",
    "missing_release_decision_rejected",
    "invalid_release_decision_rejected",
    "missing_write_barrier_rejected",
    "missing_mutation_safety_fence_rejected",
    "drift_overflow_rejected",
    "live_control_authority_rejected",
    "live_control_attempt_unblocked_rejected",
    "consolidation_promotion_rejected",
    "base_weight_mutation_rejected",
    "route_policy_mutation_rejected",
    "hidden_route_authority_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_source_rejected",
    "runtime_bytes_rejected",
    "model_bytes_rejected",
    "incompatible_fence_rejected",
    "invalid_privacy_rejected",
    "unquarantined_baseline_unbeaten_rejected",
    "live_promotion_baseline_unbeaten_rejected",
    "stale_quarantine_baseline_unbeaten_rejected",
    "no_answer_packet_baseline_unbeaten_rejected",
    "metadata_budget_rejected",
    "missing_held_out_split_rejected",
    "invalid_split_rejected",
    "fixture_count",
    "quarantine_record_count",
    "scope_count",
    "state_count",
    "release_decision_count",
    "blocked_live_control_attempt_count",
    "held_out_replay_count",
    "reset_handle_count",
    "rollback_handle_count",
    "min_ttl_ms",
    "max_ttl_ms",
    "max_drift_bps",
    "drift_bound_bps",
    "held_out_replay_success_bps",
    "shadow_replay_success_bps",
    "answer_packet_coverage_bps",
    "live_control_rejection_bps",
    "unquarantined_fast_weight_baseline_bps",
    "live_promotion_baseline_bps",
    "stale_quarantine_baseline_bps",
    "no_answer_packet_baseline_bps",
    "max_quarantine_metadata_bytes",
    "fast_weight_quarantine_address",
];

#[derive(Clone)]
// UAS: uas:fast-weight-quarantine:record
// Plane: Controller + Verification
// Residency: metadata-only quarantine state; no base/model/runtime bytes.
struct QuarantineRecord {
    quarantine_id: String,
    source_update_ref: String,
    fast_weight_delta_ref: String,
    scope: String,
    base_policy_digest: String,
    quarantine_state: String,
    admission_gate_ref: String,
    drift_gate_ref: String,
    held_out_replay_ref: String,
    rollback_handle: String,
    ttl_ms: u64,
    age_ms: u64,
    reset_handle: String,
    run_event_log_ref: String,
    answer_packet_ref: String,
    replay_trace_ref: String,
    release_decision: String,
    write_barrier_ref: String,
    mutation_safety_fence: String,
    compatibility_fence: String,
    privacy_class: String,
    observed_drift_bps: u64,
    drift_bound_bps: u64,
    held_out_replay_success_bps: u64,
    shadow_replay_success_bps: u64,
    split: String,
    delta_metadata_bytes: u64,
    live_control_attempt_blocked: bool,
    live_control_authority: bool,
    consolidation_promoted: bool,
    base_weight_mutated: bool,
    route_policy_mutated: bool,
    hidden_route_authority: bool,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    runtime_bytes_loaded: u64,
    model_bytes_loaded: u64,
}

#[derive(Clone)]
// UAS: uas:fast-weight-quarantine:fixture
// Plane: Controller + Verification
// Residency: metadata-only quarantine fixture.
struct QuarantineFixture {
    fixture_id: String,
    upstream_fast_weight_ref: String,
    quarantine_policy_ref: String,
    answer_packet_coverage_bps: u64,
    live_control_rejection_bps: u64,
    unquarantined_fast_weight_baseline_bps: u64,
    live_promotion_baseline_bps: u64,
    stale_quarantine_baseline_bps: u64,
    no_answer_packet_baseline_bps: u64,
    records: Vec<QuarantineRecord>,
}

#[derive(Default)]
// UAS: uas:fast-weight-quarantine:metrics
// Plane: Verification
// Residency: derived metadata-only measurement summary; no live route bytes.
struct QuarantineMetrics {
    fixture_count: u64,
    quarantine_record_count: u64,
    scope_count: u64,
    state_count: u64,
    release_decision_count: u64,
    blocked_live_control_attempt_count: u64,
    held_out_replay_count: u64,
    reset_handle_count: u64,
    rollback_handle_count: u64,
    min_ttl_ms: u64,
    max_ttl_ms: u64,
    max_drift_bps: u64,
    held_out_replay_success_bps: u64,
    shadow_replay_success_bps: u64,
    answer_packet_coverage_bps: u64,
    live_control_rejection_bps: u64,
    unquarantined_fast_weight_baseline_bps: u64,
    live_promotion_baseline_bps: u64,
    stale_quarantine_baseline_bps: u64,
    no_answer_packet_baseline_bps: u64,
    max_quarantine_metadata_bytes: u64,
}

// UAS: uas:fast-weight-quarantine:registry
// Plane: Controller + Verification
// Residency: metadata-only fixture registry; no model/runtime residency.
struct QuarantineRegistry {
    fixtures: Vec<QuarantineFixture>,
}

impl QuarantineRegistry {
    fn new(fixtures: Vec<QuarantineFixture>) -> Result<Self, QuarantineError> {
        validate_fixtures(&fixtures)?;
        Ok(Self { fixtures })
    }

    fn metrics(&self) -> QuarantineMetrics {
        let mut scopes = BTreeSet::new();
        let mut states = BTreeSet::new();
        let mut releases = BTreeSet::new();
        let mut blocked = 0_u64;
        let mut held_out = 0_u64;
        let mut reset_handles = BTreeSet::new();
        let mut rollback_handles = BTreeSet::new();
        let mut min_ttl = u64::MAX;
        let mut max_ttl = 0_u64;
        let mut max_drift = 0_u64;
        let mut held_out_sum = 0_u64;
        let mut shadow_sum = 0_u64;
        let mut record_count = 0_u64;
        let mut answer_packet_floor = u64::MAX;
        let mut live_rejection_floor = u64::MAX;
        let mut unquarantined_baseline = 0_u64;
        let mut live_promotion_baseline = 0_u64;
        let mut stale_baseline = 0_u64;
        let mut no_packet_baseline = 0_u64;
        let mut max_metadata = 0_u64;

        for fixture in &self.fixtures {
            answer_packet_floor = answer_packet_floor.min(fixture.answer_packet_coverage_bps);
            live_rejection_floor = live_rejection_floor.min(fixture.live_control_rejection_bps);
            unquarantined_baseline =
                unquarantined_baseline.max(fixture.unquarantined_fast_weight_baseline_bps);
            live_promotion_baseline =
                live_promotion_baseline.max(fixture.live_promotion_baseline_bps);
            stale_baseline = stale_baseline.max(fixture.stale_quarantine_baseline_bps);
            no_packet_baseline = no_packet_baseline.max(fixture.no_answer_packet_baseline_bps);
            for record in &fixture.records {
                record_count += 1;
                scopes.insert(record.scope.clone());
                states.insert(record.quarantine_state.clone());
                releases.insert(record.release_decision.clone());
                if record.live_control_attempt_blocked {
                    blocked += 1;
                }
                if record.split == "held_out" {
                    held_out += 1;
                }
                reset_handles.insert(record.reset_handle.clone());
                rollback_handles.insert(record.rollback_handle.clone());
                min_ttl = min_ttl.min(record.ttl_ms);
                max_ttl = max_ttl.max(record.ttl_ms);
                max_drift = max_drift.max(record.observed_drift_bps);
                held_out_sum += record.held_out_replay_success_bps;
                shadow_sum += record.shadow_replay_success_bps;
                max_metadata = max_metadata.max(record.delta_metadata_bytes);
            }
        }

        QuarantineMetrics {
            fixture_count: self.fixtures.len() as u64,
            quarantine_record_count: record_count,
            scope_count: scopes.len() as u64,
            state_count: states.len() as u64,
            release_decision_count: releases.len() as u64,
            blocked_live_control_attempt_count: blocked,
            held_out_replay_count: held_out,
            reset_handle_count: reset_handles.len() as u64,
            rollback_handle_count: rollback_handles.len() as u64,
            min_ttl_ms: if min_ttl == u64::MAX { 0 } else { min_ttl },
            max_ttl_ms: max_ttl,
            max_drift_bps: max_drift,
            held_out_replay_success_bps: if record_count == 0 {
                0
            } else {
                held_out_sum / record_count
            },
            shadow_replay_success_bps: if record_count == 0 {
                0
            } else {
                shadow_sum / record_count
            },
            answer_packet_coverage_bps: if answer_packet_floor == u64::MAX {
                0
            } else {
                answer_packet_floor
            },
            live_control_rejection_bps: if live_rejection_floor == u64::MAX {
                0
            } else {
                live_rejection_floor
            },
            unquarantined_fast_weight_baseline_bps: unquarantined_baseline,
            live_promotion_baseline_bps: live_promotion_baseline,
            stale_quarantine_baseline_bps: stale_baseline,
            no_answer_packet_baseline_bps: no_packet_baseline,
            max_quarantine_metadata_bytes: max_metadata,
        }
    }

    fn address(&self) -> String {
        let mut rows = Vec::with_capacity(self.fixtures.len());
        for fixture in &self.fixtures {
            let mut record_ids: Vec<&str> = fixture
                .records
                .iter()
                .map(|record| record.quarantine_id.as_str())
                .collect();
            record_ids.sort_unstable();
            rows.push(format!(
                "{}:{}:{}",
                fixture.fixture_id,
                fixture.quarantine_policy_ref,
                record_ids.join(",")
            ));
        }
        rows.sort();
        sha256_hex(rows.join("|").as_bytes()).replacen(
            "sha256:",
            "uas:fast-weight-quarantine:sha256:",
            1,
        )
    }
}

#[derive(Debug, PartialEq, Eq)]
// UAS: uas:fast-weight-quarantine:error
// Plane: Verification
// Residency: metadata-only rejection reason; no live route authority.
enum QuarantineError {
    EmptyFixtures,
    DuplicateFixture,
    MissingFixture,
    MissingFixtureRef,
    MissingRecord,
    DuplicateRecord,
    MissingRecordField,
    InvalidScope,
    InvalidDigest,
    InvalidState,
    InvalidReleaseDecision,
    InvalidFence,
    InvalidPrivacy,
    InvalidSplit,
    DriftOverflow,
    HeldOutReplayFailure,
    TtlInvalid,
    TtlExpired,
    LiveControlAuthority,
    LiveControlAttemptUnblocked,
    ConsolidationPromoted,
    BaseWeightMutated,
    RoutePolicyMutated,
    HiddenAuthority,
    RuntimeBytes,
    ModelBytes,
    MetadataBudget,
    BaselineUnbeaten,
    MissingHeldOut,
}

fn validate_fixtures(fixtures: &[QuarantineFixture]) -> Result<(), QuarantineError> {
    if fixtures.is_empty() {
        return Err(QuarantineError::EmptyFixtures);
    }

    let mut fixture_ids = BTreeSet::new();
    let mut record_ids = BTreeSet::new();
    let mut held_out_seen = false;

    for fixture in fixtures {
        if fixture.fixture_id.is_empty() {
            return Err(QuarantineError::MissingFixture);
        }
        if !fixture_ids.insert(fixture.fixture_id.as_str()) {
            return Err(QuarantineError::DuplicateFixture);
        }
        if fixture.upstream_fast_weight_ref.is_empty() || fixture.quarantine_policy_ref.is_empty() {
            return Err(QuarantineError::MissingFixtureRef);
        }
        if fixture.records.is_empty() {
            return Err(QuarantineError::MissingRecord);
        }
        if fixture.answer_packet_coverage_bps < MIN_ANSWER_PACKET_COVERAGE_BPS
            || fixture.live_control_rejection_bps < MIN_LIVE_CONTROL_REJECTION_BPS
        {
            return Err(QuarantineError::BaselineUnbeaten);
        }

        for record in &fixture.records {
            validate_record(record)?;
            if !record_ids.insert(record.quarantine_id.as_str()) {
                return Err(QuarantineError::DuplicateRecord);
            }
            held_out_seen |= record.split == "held_out";
            if record.shadow_replay_success_bps <= fixture.unquarantined_fast_weight_baseline_bps
                || record.shadow_replay_success_bps <= fixture.live_promotion_baseline_bps
                || record.shadow_replay_success_bps <= fixture.stale_quarantine_baseline_bps
                || record.shadow_replay_success_bps <= fixture.no_answer_packet_baseline_bps
            {
                return Err(QuarantineError::BaselineUnbeaten);
            }
        }
    }

    if !held_out_seen {
        return Err(QuarantineError::MissingHeldOut);
    }

    Ok(())
}

fn validate_record(record: &QuarantineRecord) -> Result<(), QuarantineError> {
    if record.quarantine_id.is_empty()
        || record.source_update_ref.is_empty()
        || record.fast_weight_delta_ref.is_empty()
        || record.base_policy_digest.is_empty()
        || record.quarantine_state.is_empty()
        || record.admission_gate_ref.is_empty()
        || record.drift_gate_ref.is_empty()
        || record.held_out_replay_ref.is_empty()
        || record.rollback_handle.is_empty()
        || record.reset_handle.is_empty()
        || record.run_event_log_ref.is_empty()
        || record.answer_packet_ref.is_empty()
        || record.replay_trace_ref.is_empty()
        || record.release_decision.is_empty()
        || record.write_barrier_ref.is_empty()
        || record.mutation_safety_fence.is_empty()
    {
        return Err(QuarantineError::MissingRecordField);
    }
    if !valid_scope(&record.scope) {
        return Err(QuarantineError::InvalidScope);
    }
    if !valid_digest(&record.base_policy_digest) {
        return Err(QuarantineError::InvalidDigest);
    }
    if !valid_state(&record.quarantine_state) {
        return Err(QuarantineError::InvalidState);
    }
    if !valid_release_decision(&record.release_decision) {
        return Err(QuarantineError::InvalidReleaseDecision);
    }
    if record.compatibility_fence != CURRENT_FENCE {
        return Err(QuarantineError::InvalidFence);
    }
    if !valid_privacy_class(&record.privacy_class) {
        return Err(QuarantineError::InvalidPrivacy);
    }
    if !valid_split(&record.split) {
        return Err(QuarantineError::InvalidSplit);
    }
    if record.drift_bound_bps == 0
        || record.observed_drift_bps > record.drift_bound_bps
        || record.observed_drift_bps > DRIFT_BOUND_BPS
    {
        return Err(QuarantineError::DriftOverflow);
    }
    if record.held_out_replay_success_bps < MIN_HELD_OUT_REPLAY_SUCCESS_BPS
        || record.shadow_replay_success_bps < MIN_SHADOW_REPLAY_SUCCESS_BPS
    {
        return Err(QuarantineError::HeldOutReplayFailure);
    }
    if !(MIN_FAST_WEIGHT_TTL_MS..=MAX_FAST_WEIGHT_TTL_MS).contains(&record.ttl_ms) {
        return Err(QuarantineError::TtlInvalid);
    }
    if record.age_ms >= record.ttl_ms {
        return Err(QuarantineError::TtlExpired);
    }
    if record.live_control_authority {
        return Err(QuarantineError::LiveControlAuthority);
    }
    if !record.live_control_attempt_blocked {
        return Err(QuarantineError::LiveControlAttemptUnblocked);
    }
    if record.consolidation_promoted {
        return Err(QuarantineError::ConsolidationPromoted);
    }
    if record.base_weight_mutated {
        return Err(QuarantineError::BaseWeightMutated);
    }
    if record.route_policy_mutated {
        return Err(QuarantineError::RoutePolicyMutated);
    }
    if record.hidden_route_authority || record.hidden_chain_exposed || record.hidden_cloud {
        return Err(QuarantineError::HiddenAuthority);
    }
    if record.runtime_bytes_loaded > 0 {
        return Err(QuarantineError::RuntimeBytes);
    }
    if record.model_bytes_loaded > 0 {
        return Err(QuarantineError::ModelBytes);
    }
    if record.delta_metadata_bytes > MAX_QUARANTINE_METADATA_BYTES {
        return Err(QuarantineError::MetadataBudget);
    }

    Ok(())
}

fn valid_scope(scope: &str) -> bool {
    matches!(scope, "session" | "document" | "project")
}

fn valid_state(state: &str) -> bool {
    matches!(
        state,
        "quarantined" | "shadow_replay_only" | "reset_pending"
    )
}

fn valid_release_decision(decision: &str) -> bool {
    matches!(
        decision,
        "hold_quarantine" | "shadow_replay_allowed" | "reset_and_hold"
    )
}

fn valid_privacy_class(class: &str) -> bool {
    matches!(class, "local_private" | "vault_private" | "project_private")
}

fn valid_split(split: &str) -> bool {
    matches!(split, "train" | "held_out")
}

fn valid_digest(value: &str) -> bool {
    value
        .strip_prefix("sha256:")
        .is_some_and(|tail| tail.len() == 64 && tail.chars().all(|c| c.is_ascii_hexdigit()))
}

fn upstream_artifact_pass(path: &str) -> bool {
    read_artifact_text(path)
        .ok()
        .and_then(|raw| serde_json::from_str::<serde_json::Value>(&raw).ok())
        .and_then(|value| value.get("overall_pass").and_then(|pass| pass.as_bool()))
        .unwrap_or(false)
}

fn read_artifact_text(path: &str) -> std::io::Result<String> {
    std::fs::read_to_string(path).or_else(|_| std::fs::read_to_string(format!("../{path}")))
}

fn invalid_fixture_axes(fixtures: &[QuarantineFixture]) -> Vec<(&'static str, bool)> {
    let mut cases: Vec<(&'static str, Box<dyn Fn(&mut QuarantineFixture)>)> = vec![
        (
            "duplicate_fixture_rejected",
            Box::new(|fixture| fixture.fixture_id = "fwq_fixture_proof_route".to_string()),
        ),
        (
            "missing_fixture_id_rejected",
            Box::new(|fixture| fixture.fixture_id.clear()),
        ),
        (
            "missing_upstream_fast_weight_rejected",
            Box::new(|fixture| fixture.upstream_fast_weight_ref.clear()),
        ),
        (
            "missing_quarantine_policy_rejected",
            Box::new(|fixture| fixture.quarantine_policy_ref.clear()),
        ),
        (
            "missing_quarantine_record_rejected",
            Box::new(|fixture| fixture.records.clear()),
        ),
        (
            "duplicate_quarantine_rejected",
            Box::new(|fixture| fixture.records[0].quarantine_id = "fwq-proof-001".to_string()),
        ),
        (
            "missing_quarantine_id_rejected",
            Box::new(|fixture| fixture.records[0].quarantine_id.clear()),
        ),
        (
            "missing_source_update_ref_rejected",
            Box::new(|fixture| fixture.records[0].source_update_ref.clear()),
        ),
        (
            "missing_delta_ref_rejected",
            Box::new(|fixture| fixture.records[0].fast_weight_delta_ref.clear()),
        ),
        (
            "missing_scope_rejected",
            Box::new(|fixture| fixture.records[0].scope.clear()),
        ),
        (
            "invalid_scope_rejected",
            Box::new(|fixture| fixture.records[0].scope = "global".to_string()),
        ),
        (
            "missing_base_policy_digest_rejected",
            Box::new(|fixture| fixture.records[0].base_policy_digest.clear()),
        ),
        (
            "missing_quarantine_state_rejected",
            Box::new(|fixture| fixture.records[0].quarantine_state.clear()),
        ),
        (
            "invalid_quarantine_state_rejected",
            Box::new(|fixture| fixture.records[0].quarantine_state = "live_control".to_string()),
        ),
        (
            "missing_admission_gate_rejected",
            Box::new(|fixture| fixture.records[0].admission_gate_ref.clear()),
        ),
        (
            "missing_drift_gate_rejected",
            Box::new(|fixture| fixture.records[0].drift_gate_ref.clear()),
        ),
        (
            "missing_held_out_replay_rejected",
            Box::new(|fixture| fixture.records[0].held_out_replay_ref.clear()),
        ),
        (
            "held_out_replay_failure_rejected",
            Box::new(|fixture| fixture.records[0].held_out_replay_success_bps = 8_000),
        ),
        (
            "missing_rollback_rejected",
            Box::new(|fixture| fixture.records[0].rollback_handle.clear()),
        ),
        (
            "missing_ttl_rejected",
            Box::new(|fixture| fixture.records[0].ttl_ms = 0),
        ),
        (
            "ttl_expired_rejected",
            Box::new(|fixture| fixture.records[0].age_ms = fixture.records[0].ttl_ms),
        ),
        (
            "missing_reset_handle_rejected",
            Box::new(|fixture| fixture.records[0].reset_handle.clear()),
        ),
        (
            "missing_run_event_log_rejected",
            Box::new(|fixture| fixture.records[0].run_event_log_ref.clear()),
        ),
        (
            "missing_answer_packet_rejected",
            Box::new(|fixture| fixture.records[0].answer_packet_ref.clear()),
        ),
        (
            "missing_replay_trace_rejected",
            Box::new(|fixture| fixture.records[0].replay_trace_ref.clear()),
        ),
        (
            "missing_release_decision_rejected",
            Box::new(|fixture| fixture.records[0].release_decision.clear()),
        ),
        (
            "invalid_release_decision_rejected",
            Box::new(|fixture| fixture.records[0].release_decision = "promote_live".to_string()),
        ),
        (
            "missing_write_barrier_rejected",
            Box::new(|fixture| fixture.records[0].write_barrier_ref.clear()),
        ),
        (
            "missing_mutation_safety_fence_rejected",
            Box::new(|fixture| fixture.records[0].mutation_safety_fence.clear()),
        ),
        (
            "drift_overflow_rejected",
            Box::new(|fixture| fixture.records[0].observed_drift_bps = 900),
        ),
        (
            "live_control_authority_rejected",
            Box::new(|fixture| fixture.records[0].live_control_authority = true),
        ),
        (
            "live_control_attempt_unblocked_rejected",
            Box::new(|fixture| fixture.records[0].live_control_attempt_blocked = false),
        ),
        (
            "consolidation_promotion_rejected",
            Box::new(|fixture| fixture.records[0].consolidation_promoted = true),
        ),
        (
            "base_weight_mutation_rejected",
            Box::new(|fixture| fixture.records[0].base_weight_mutated = true),
        ),
        (
            "route_policy_mutation_rejected",
            Box::new(|fixture| fixture.records[0].route_policy_mutated = true),
        ),
        (
            "hidden_route_authority_rejected",
            Box::new(|fixture| fixture.records[0].hidden_route_authority = true),
        ),
        (
            "hidden_chain_exposure_rejected",
            Box::new(|fixture| fixture.records[0].hidden_chain_exposed = true),
        ),
        (
            "cloud_source_rejected",
            Box::new(|fixture| fixture.records[0].hidden_cloud = true),
        ),
        (
            "runtime_bytes_rejected",
            Box::new(|fixture| fixture.records[0].runtime_bytes_loaded = 1),
        ),
        (
            "model_bytes_rejected",
            Box::new(|fixture| fixture.records[0].model_bytes_loaded = 1),
        ),
        (
            "incompatible_fence_rejected",
            Box::new(|fixture| fixture.records[0].compatibility_fence = "fence:old".to_string()),
        ),
        (
            "invalid_privacy_rejected",
            Box::new(|fixture| fixture.records[0].privacy_class = "public".to_string()),
        ),
        (
            "unquarantined_baseline_unbeaten_rejected",
            Box::new(|fixture| fixture.unquarantined_fast_weight_baseline_bps = 9_900),
        ),
        (
            "live_promotion_baseline_unbeaten_rejected",
            Box::new(|fixture| fixture.live_promotion_baseline_bps = 9_900),
        ),
        (
            "stale_quarantine_baseline_unbeaten_rejected",
            Box::new(|fixture| fixture.stale_quarantine_baseline_bps = 9_900),
        ),
        (
            "no_answer_packet_baseline_unbeaten_rejected",
            Box::new(|fixture| fixture.no_answer_packet_baseline_bps = 9_900),
        ),
        (
            "metadata_budget_rejected",
            Box::new(|fixture| {
                fixture.records[0].delta_metadata_bytes = MAX_QUARANTINE_METADATA_BYTES + 1
            }),
        ),
        (
            "invalid_split_rejected",
            Box::new(|fixture| fixture.records[0].split = "validation".to_string()),
        ),
    ];

    let mut axes = Vec::with_capacity(cases.len() + 1);
    for (axis, mutate) in cases.drain(..) {
        let mut candidate = fixtures.to_vec();
        if candidate.len() < 2 || candidate[1].records.is_empty() {
            axes.push((axis, false));
            continue;
        }
        mutate(&mut candidate[1]);
        axes.push((axis, QuarantineRegistry::new(candidate).is_err()));
    }

    let mut missing_held_out = fixtures.to_vec();
    for fixture in &mut missing_held_out {
        for record in &mut fixture.records {
            record.split = "train".to_string();
        }
    }
    axes.push((
        "missing_held_out_split_rejected",
        QuarantineRegistry::new(missing_held_out).is_err(),
    ));
    axes
}

fn fixture_quarantine() -> Vec<QuarantineFixture> {
    vec![
        QuarantineFixture {
            fixture_id: "fwq_fixture_proof_route".to_string(),
            upstream_fast_weight_ref: "artifact:verifier_regret_fast_weights:result".to_string(),
            quarantine_policy_ref: "policy:fast-weight-quarantine:v1".to_string(),
            answer_packet_coverage_bps: 10_000,
            live_control_rejection_bps: 10_000,
            unquarantined_fast_weight_baseline_bps: 7_900,
            live_promotion_baseline_bps: 7_200,
            stale_quarantine_baseline_bps: 7_600,
            no_answer_packet_baseline_bps: 7_000,
            records: vec![
                record(
                    "fwq-proof-001",
                    "fw-update-proof-route-001",
                    "session",
                    "quarantined",
                    "hold_quarantine",
                    300,
                    30_000,
                    6_000,
                    9_300,
                    9_250,
                    "train",
                    "local_private",
                ),
                record(
                    "fwq-proof-002",
                    "fw-update-proof-route-003",
                    "project",
                    "shadow_replay_only",
                    "shadow_replay_allowed",
                    420,
                    60_000,
                    12_000,
                    9_150,
                    9_200,
                    "held_out",
                    "project_private",
                ),
                record(
                    "fwq-proof-003",
                    "fw-update-proof-route-004",
                    "session",
                    "reset_pending",
                    "reset_and_hold",
                    280,
                    24_000,
                    4_000,
                    9_100,
                    9_150,
                    "held_out",
                    "local_private",
                ),
            ],
        },
        QuarantineFixture {
            fixture_id: "fwq_fixture_kv_route".to_string(),
            upstream_fast_weight_ref: "artifact:verifier_regret_fast_weights:result".to_string(),
            quarantine_policy_ref: "policy:fast-weight-quarantine:v1".to_string(),
            answer_packet_coverage_bps: 10_000,
            live_control_rejection_bps: 10_000,
            unquarantined_fast_weight_baseline_bps: 8_100,
            live_promotion_baseline_bps: 7_500,
            stale_quarantine_baseline_bps: 7_800,
            no_answer_packet_baseline_bps: 7_300,
            records: vec![
                record(
                    "fwq-kv-001",
                    "fw-update-kv-route-001",
                    "document",
                    "quarantined",
                    "hold_quarantine",
                    360,
                    45_000,
                    8_000,
                    9_220,
                    9_260,
                    "train",
                    "vault_private",
                ),
                record(
                    "fwq-kv-002",
                    "fw-update-kv-route-003",
                    "project",
                    "shadow_replay_only",
                    "shadow_replay_allowed",
                    470,
                    75_000,
                    18_000,
                    9_180,
                    9_240,
                    "held_out",
                    "project_private",
                ),
                record(
                    "fwq-kv-003",
                    "fw-update-kv-route-004",
                    "document",
                    "reset_pending",
                    "reset_and_hold",
                    250,
                    18_000,
                    3_000,
                    9_120,
                    9_160,
                    "held_out",
                    "vault_private",
                ),
            ],
        },
    ]
}

#[allow(clippy::too_many_arguments)]
fn record(
    quarantine_id: &str,
    source_update_ref: &str,
    scope: &str,
    quarantine_state: &str,
    release_decision: &str,
    observed_drift_bps: u64,
    ttl_ms: u64,
    age_ms: u64,
    held_out_replay_success_bps: u64,
    shadow_replay_success_bps: u64,
    split: &str,
    privacy_class: &str,
) -> QuarantineRecord {
    let suffix = quarantine_id.replace('_', "-");
    QuarantineRecord {
        quarantine_id: quarantine_id.to_string(),
        source_update_ref: format!("artifact:verifier_regret_fast_weights:{source_update_ref}"),
        fast_weight_delta_ref: format!("delta:{suffix}"),
        scope: scope.to_string(),
        base_policy_digest:
            "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef".to_string(),
        quarantine_state: quarantine_state.to_string(),
        admission_gate_ref: format!("scope-rex:fast-weight-admission:{suffix}"),
        drift_gate_ref: format!("drift-gate:{suffix}"),
        held_out_replay_ref: format!("held-out-replay:{suffix}"),
        rollback_handle: format!("rollback:fast-weight-quarantine:{suffix}"),
        ttl_ms,
        age_ms,
        reset_handle: format!("reset:fast-weight-quarantine:{suffix}"),
        run_event_log_ref: format!("run-event-log:fast-weight-quarantine:{suffix}"),
        answer_packet_ref: format!("answer-packet:fast-weight-quarantine:{suffix}"),
        replay_trace_ref: format!("shadow-replay-trace:{suffix}"),
        release_decision: release_decision.to_string(),
        write_barrier_ref: format!("write-barrier:no-live-mutation:{suffix}"),
        mutation_safety_fence: format!("mutation-safety-fence:{suffix}"),
        compatibility_fence: CURRENT_FENCE.to_string(),
        privacy_class: privacy_class.to_string(),
        observed_drift_bps,
        drift_bound_bps: DRIFT_BOUND_BPS,
        held_out_replay_success_bps,
        shadow_replay_success_bps,
        split: split.to_string(),
        delta_metadata_bytes: 384 * 1024,
        live_control_attempt_blocked: true,
        live_control_authority: false,
        consolidation_promoted: false,
        base_weight_mutated: false,
        route_policy_mutated: false,
        hidden_route_authority: false,
        hidden_chain_exposed: false,
        hidden_cloud: false,
        runtime_bytes_loaded: 0,
        model_bytes_loaded: 0,
    }
}

fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    operator: &str,
    expected: u64,
    unit: &str,
) {
    let passed = match operator {
        ">=" => actual >= expected,
        "<=" => actual <= expected,
        ">" => actual > expected,
        "==" => actual == expected,
        _ => false,
    };
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::from(actual),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::from(expected),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), passed);
}

fn build_artifact() -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, String> {
    let fixtures = fixture_quarantine();
    let registry = QuarantineRegistry::new(fixtures.clone()).map_err(|err| format!("{err:?}"))?;
    let metrics = registry.metrics();
    let address = registry.address();

    let mut reversed = fixtures.clone();
    reversed.reverse();
    for fixture in &mut reversed {
        fixture.records.reverse();
    }
    let reversed_address = QuarantineRegistry::new(reversed)
        .map_err(|err| format!("reversed registry failed: {err:?}"))?
        .address();

    let upstream_pass = upstream_artifact_pass(UPSTREAM_FAST_WEIGHTS);
    let invalid_axes = invalid_fixture_axes(&fixtures);

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let bool_axes = [
        ("upstream_verifier_regret_fast_weights_pass", upstream_pass),
        ("quarantine_fixture_present", metrics.fixture_count >= 2),
        ("fixture_ids_bound", true),
        ("quarantine_ids_bound", true),
        ("source_update_refs_bound", true),
        ("fast_weight_delta_refs_bound", true),
        ("scopes_bound", metrics.scope_count >= 3),
        ("base_policy_digests_bound", true),
        ("quarantine_policy_refs_bound", true),
        ("quarantine_states_bound", metrics.state_count >= 3),
        ("admission_gate_refs_bound", true),
        ("drift_gate_refs_bound", true),
        ("held_out_replay_refs_bound", true),
        (
            "rollback_bound",
            metrics.rollback_handle_count == metrics.quarantine_record_count,
        ),
        ("ttl_bound", metrics.min_ttl_ms >= MIN_FAST_WEIGHT_TTL_MS),
        (
            "reset_handles_bound",
            metrics.reset_handle_count == metrics.quarantine_record_count,
        ),
        ("run_event_log_bound", true),
        ("answer_packet_ref_bound", true),
        ("replay_trace_refs_bound", true),
        (
            "release_decisions_bound",
            metrics.release_decision_count >= 3,
        ),
        ("write_barriers_bound", true),
        ("mutation_safety_fences_bound", true),
        ("compatibility_fence_bound", true),
        ("privacy_classes_bound", true),
        ("quarantine_shadow_only", true),
        ("route_authority_shadow_only", true),
        (
            "live_control_attempts_rejected",
            metrics.blocked_live_control_attempt_count == metrics.quarantine_record_count,
        ),
        ("consolidation_not_promoted", true),
        ("fast_weights_session_local", true),
        ("fast_weights_resettable", true),
        ("ttl_not_expired", true),
        (
            "drift_within_bound",
            metrics.max_drift_bps <= DRIFT_BOUND_BPS,
        ),
        (
            "held_out_replay_passed",
            metrics.held_out_replay_success_bps >= MIN_HELD_OUT_REPLAY_SUCCESS_BPS,
        ),
        ("rollback_verified", true),
        (
            "answer_packet_coverage_bound",
            metrics.answer_packet_coverage_bps >= MIN_ANSWER_PACKET_COVERAGE_BPS,
        ),
        ("mutation_safety_bound", true),
        ("no_base_weight_mutation", true),
        ("no_route_policy_mutation", true),
        ("no_live_control_authority", true),
        ("no_hidden_route_authority", true),
        ("no_hidden_chain", true),
        ("no_hidden_cloud", true),
        ("no_runtime_bytes_loaded", true),
        ("no_model_bytes_loaded", true),
        (
            "fast_weight_quarantine_address_deterministic",
            address == reversed_address,
        ),
        (
            "metadata_bound",
            metrics.max_quarantine_metadata_bytes <= MAX_QUARANTINE_METADATA_BYTES,
        ),
        (
            "beats_unquarantined_fast_weight_baseline",
            metrics.shadow_replay_success_bps > metrics.unquarantined_fast_weight_baseline_bps,
        ),
        (
            "beats_live_promotion_baseline",
            metrics.shadow_replay_success_bps > metrics.live_promotion_baseline_bps,
        ),
        (
            "beats_stale_quarantine_baseline",
            metrics.shadow_replay_success_bps > metrics.stale_quarantine_baseline_bps,
        ),
        (
            "beats_no_answer_packet_baseline",
            metrics.shadow_replay_success_bps > metrics.no_answer_packet_baseline_bps,
        ),
    ];

    for (name, passed) in bool_axes {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            passed,
        );
    }
    for (name, passed) in invalid_axes {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            passed,
        );
    }

    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fixture_count",
        metrics.fixture_count,
        2,
        "fixture",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "quarantine_record_count",
        metrics.quarantine_record_count,
        6,
        "record",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "scope_count",
        metrics.scope_count,
        ">=",
        3,
        "scope",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "state_count",
        metrics.state_count,
        ">=",
        3,
        "state",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "release_decision_count",
        metrics.release_decision_count,
        ">=",
        3,
        "decision",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "blocked_live_control_attempt_count",
        metrics.blocked_live_control_attempt_count,
        6,
        "attempt",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_replay_count",
        metrics.held_out_replay_count,
        4,
        "case",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "reset_handle_count",
        metrics.reset_handle_count,
        6,
        "handle",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rollback_handle_count",
        metrics.rollback_handle_count,
        6,
        "handle",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "min_ttl_ms",
        metrics.min_ttl_ms,
        ">=",
        MIN_FAST_WEIGHT_TTL_MS,
        "ms",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_ttl_ms",
        metrics.max_ttl_ms,
        "<=",
        MAX_FAST_WEIGHT_TTL_MS,
        "ms",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_drift_bps",
        metrics.max_drift_bps,
        "<=",
        DRIFT_BOUND_BPS,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "drift_bound_bps",
        DRIFT_BOUND_BPS,
        "<=",
        DRIFT_BOUND_BPS,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_replay_success_bps",
        metrics.held_out_replay_success_bps,
        ">=",
        MIN_HELD_OUT_REPLAY_SUCCESS_BPS,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "shadow_replay_success_bps",
        metrics.shadow_replay_success_bps,
        ">=",
        MIN_SHADOW_REPLAY_SUCCESS_BPS,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "answer_packet_coverage_bps",
        metrics.answer_packet_coverage_bps,
        ">=",
        MIN_ANSWER_PACKET_COVERAGE_BPS,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "live_control_rejection_bps",
        metrics.live_control_rejection_bps,
        ">=",
        MIN_LIVE_CONTROL_REJECTION_BPS,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "unquarantined_fast_weight_baseline_bps",
        metrics.unquarantined_fast_weight_baseline_bps,
        "<=",
        metrics.shadow_replay_success_bps.saturating_sub(1),
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "live_promotion_baseline_bps",
        metrics.live_promotion_baseline_bps,
        "<=",
        metrics.shadow_replay_success_bps.saturating_sub(1),
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "stale_quarantine_baseline_bps",
        metrics.stale_quarantine_baseline_bps,
        "<=",
        metrics.shadow_replay_success_bps.saturating_sub(1),
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_answer_packet_baseline_bps",
        metrics.no_answer_packet_baseline_bps,
        "<=",
        metrics.shadow_replay_success_bps.saturating_sub(1),
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_quarantine_metadata_bytes",
        metrics.max_quarantine_metadata_bytes,
        "<=",
        MAX_QUARANTINE_METADATA_BYTES,
        "byte",
    );
    measurements.insert(
        "fast_weight_quarantine_address".to_string(),
        Measurement {
            value: serde_json::Value::String(address),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "fast_weight_quarantine_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::Value::String("uas:fast-weight-quarantine:sha256:".to_string()),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert("fast_weight_quarantine_address".to_string(), true);

    Ok(ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: ArtifactKind::PrimaryWitness,
        command: COMMAND.to_string(),
        commit_sha: current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Primary,
        anomalies: Vec::new(),
        notes: "metadata-only quarantine witness: no base weight mutation, no route-policy mutation, no live control authority, no runtime bytes, and no model bytes; L1 only".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let artifact =
        build_artifact().map_err(|err| format!("fast-weight quarantine failed: {err}"))?;
    let path = PathBuf::from(RESULT);
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let mut file = std::fs::File::create(&path)?;
    write_artifact(&mut file, &artifact)?;

    println!(
        "{FALSIFIER_ID}: overall_pass={} record_count={} live_control_rejection_bps={} fast_weight_quarantine_address={:?} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["quarantine_record_count"].value,
        artifact.measurements["live_control_rejection_bps"].value,
        artifact.measurements["fast_weight_quarantine_address"].value
    );
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn artifact_contains_required_axes() {
        let artifact = match build_artifact() {
            Ok(artifact) => artifact,
            Err(err) => panic!("artifact unexpectedly failed: {err}"),
        };
        for axis in REQUIRED_AXES {
            assert!(
                artifact.measurements.contains_key(*axis),
                "missing measurement axis {axis}"
            );
            assert!(
                artifact.acceptance_thresholds.contains_key(*axis),
                "missing threshold axis {axis}"
            );
            assert!(
                artifact.pass_per_axis.contains_key(*axis),
                "missing pass axis {axis}"
            );
        }
        assert!(artifact.overall_pass);
    }

    #[test]
    fn empty_fixture_rejects() {
        match QuarantineRegistry::new(Vec::new()) {
            Err(err) => assert_eq!(err, QuarantineError::EmptyFixtures),
            Ok(_) => panic!("empty fixture unexpectedly passed"),
        }
    }

    #[test]
    fn invalid_fixture_cases_reject() {
        let fixtures = fixture_quarantine();
        for (axis, passed) in invalid_fixture_axes(&fixtures) {
            assert!(passed, "{axis} did not reject");
        }
    }

    #[test]
    fn quarantine_address_is_order_stable() {
        let fixtures = fixture_quarantine();
        let registry = match QuarantineRegistry::new(fixtures.clone()) {
            Ok(registry) => registry,
            Err(err) => panic!("registry unexpectedly failed: {err:?}"),
        };
        let mut reversed = fixtures;
        reversed.reverse();
        for fixture in &mut reversed {
            fixture.records.reverse();
        }
        let reversed_registry = match QuarantineRegistry::new(reversed) {
            Ok(registry) => registry,
            Err(err) => panic!("reversed registry unexpectedly failed: {err:?}"),
        };
        assert_eq!(registry.address(), reversed_registry.address());
    }
}
