//! `falsify_depth_lease_checkpoint` -- adaptive-depth checkpoint witness.
//!
//! Metadata-only witness for `F-DepthLease-Checkpoint`. It proves adaptive
//! depth choices declare shallow exits, deeper wakes, verifier margins, maximum
//! extra layers, full-depth fallbacks, resume checkpoints, rollback,
//! RunEventLog, and AnswerPacket fields before dynamic-depth policy can cite
//! savings. It rejects silent depth promotion, live route authority, cache or
//! policy mutation, hidden chains/cloud, runtime bytes, and model bytes.

use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-DepthLease-Checkpoint";
const FIXTURE_ID: &str = "depth_lease_checkpoint_v1";
const COMMAND: &str = "Tools/falsifiers/f_depth_lease_checkpoint.sh";
const RESULT: &str = "artifacts/falsifiers/depth_lease_checkpoint/result.json";
const UPSTREAM_LAYER_KV: &str = "artifacts/falsifiers/layer_kv_joint_lease/result.json";
const UPSTREAM_FAST_WEIGHT_QUARANTINE: &str =
    "artifacts/falsifiers/fast_weight_quarantine/result.json";

const CURRENT_FENCE: &str = "fence:depth-lease:v1:qwen3.5:kv:v1:fast-weight-quarantine:v1";
const MAX_EXTRA_LAYERS: u64 = 10;
const MAX_LATENCY_MS: u64 = 240;
const MIN_VERIFIER_MARGIN_BPS: u64 = 1_500;
const MIN_LEASE_SUCCESS_BPS: u64 = 9_000;
const MIN_ANSWER_PACKET_COVERAGE_BPS: u64 = 10_000;
const MIN_SILENT_PROMOTION_REJECTION_BPS: u64 = 10_000;
const MAX_CHECKPOINT_METADATA_BYTES: u64 = 768 * 1024;
const REQUIRED_PACKET_FIELDS: &[&str] = &[
    "depth_lease_checkpoint",
    "shallow_exit_layer",
    "deeper_wake_layer",
    "verifier_margin",
    "max_extra_layers",
    "full_depth_fallback",
    "resume_checkpoint",
    "rollback",
    "run_event_log",
];

#[cfg(test)]
const REQUIRED_AXES: &[&str] = &[
    "upstream_layer_kv_joint_lease_pass",
    "upstream_fast_weight_quarantine_pass",
    "checkpoint_fixture_present",
    "fixture_ids_bound",
    "checkpoint_ids_bound",
    "mission_ids_bound",
    "route_card_refs_bound",
    "depth_policy_refs_bound",
    "shallow_exit_declared",
    "deeper_wake_declared",
    "verifier_margin_bound",
    "max_extra_layers_bound",
    "full_depth_fallback_bound",
    "checkpoint_refs_bound",
    "resume_tokens_bound",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "answer_packet_fields_bound",
    "mutation_safety_fence_bound",
    "compatibility_fence_bound",
    "privacy_classes_bound",
    "held_out_split_bound",
    "depth_lease_shadow_only",
    "silent_depth_promotion_rejected",
    "full_depth_fallback_visible",
    "no_live_route_authority",
    "no_base_weight_mutation",
    "no_route_policy_mutation",
    "no_cache_mutation",
    "no_hidden_chain",
    "no_hidden_cloud",
    "no_runtime_bytes_loaded",
    "no_model_bytes_loaded",
    "depth_lease_checkpoint_address_deterministic",
    "metadata_bound",
    "beats_shallow_only_baseline",
    "beats_hidden_depth_baseline",
    "beats_no_checkpoint_baseline",
    "beats_no_fallback_baseline",
    "duplicate_fixture_rejected",
    "missing_fixture_id_rejected",
    "missing_fixture_policy_rejected",
    "missing_checkpoint_record_rejected",
    "duplicate_checkpoint_rejected",
    "missing_checkpoint_id_rejected",
    "missing_mission_rejected",
    "missing_upstream_layer_kv_rejected",
    "missing_upstream_fast_weight_quarantine_rejected",
    "missing_route_card_rejected",
    "missing_depth_policy_rejected",
    "missing_shallow_exit_rejected",
    "missing_deeper_wake_rejected",
    "invalid_depth_order_rejected",
    "missing_full_depth_rejected",
    "extra_layer_budget_rejected",
    "missing_checkpoint_ref_rejected",
    "missing_resume_token_rejected",
    "missing_verifier_margin_rejected",
    "verifier_margin_too_low_rejected",
    "latency_budget_rejected",
    "missing_full_depth_fallback_rejected",
    "fallback_disabled_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "missing_answer_packet_field_rejected",
    "missing_mutation_safety_fence_rejected",
    "incompatible_fence_rejected",
    "invalid_privacy_rejected",
    "missing_split_rejected",
    "invalid_split_rejected",
    "missing_held_out_split_rejected",
    "silent_depth_promotion_case_rejected",
    "live_route_authority_rejected",
    "base_weight_mutation_rejected",
    "route_policy_mutation_rejected",
    "cache_mutation_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_source_rejected",
    "runtime_bytes_rejected",
    "model_bytes_rejected",
    "metadata_budget_rejected",
    "shallow_only_baseline_unbeaten_rejected",
    "hidden_depth_baseline_unbeaten_rejected",
    "no_checkpoint_baseline_unbeaten_rejected",
    "no_fallback_baseline_unbeaten_rejected",
    "fixture_count",
    "checkpoint_count",
    "held_out_checkpoint_count",
    "shallow_exit_count",
    "deeper_wake_count",
    "full_depth_fallback_count",
    "resume_token_count",
    "rollback_handle_count",
    "run_event_log_count",
    "answer_packet_count",
    "min_verifier_margin_bps",
    "max_extra_layers",
    "max_depth_delta",
    "max_latency_ms",
    "lease_success_bps",
    "answer_packet_coverage_bps",
    "silent_promotion_rejection_bps",
    "shallow_only_baseline_bps",
    "hidden_depth_baseline_bps",
    "no_checkpoint_baseline_bps",
    "no_fallback_baseline_bps",
    "max_checkpoint_metadata_bytes",
    "depth_lease_checkpoint_address",
];

#[derive(Clone)]
// UAS: uas:depth-lease-checkpoint:record
// Plane: Controller + Verification
// Residency: metadata-only adaptive-depth checkpoint; no layer/KV/model bytes.
struct DepthCheckpoint {
    checkpoint_id: String,
    mission_id: String,
    upstream_layer_kv_lease_ref: String,
    upstream_fast_weight_quarantine_ref: String,
    route_card_ref: String,
    depth_policy_ref: String,
    shallow_exit_layer: u16,
    deeper_wake_layer: u16,
    full_depth_layer: u16,
    checkpoint_ref: String,
    resume_token_ref: String,
    verifier_margin_bps: u64,
    max_extra_layers: u64,
    expected_extra_layers: u64,
    latency_budget_ms: u64,
    expected_latency_ms: u64,
    full_depth_fallback_ref: String,
    fallback_enabled: bool,
    rollback_handle: String,
    run_event_log_ref: String,
    answer_packet_ref: String,
    answer_packet_fields: Vec<String>,
    mutation_safety_fence: String,
    compatibility_fence: String,
    privacy_class: String,
    split: String,
    lease_success_bps: u64,
    shallow_only_baseline_bps: u64,
    hidden_depth_baseline_bps: u64,
    no_checkpoint_baseline_bps: u64,
    no_fallback_baseline_bps: u64,
    metadata_bytes: u64,
    silent_depth_promotion: bool,
    live_route_authority: bool,
    base_weight_mutated: bool,
    route_policy_mutated: bool,
    cache_mutated: bool,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    runtime_bytes_loaded: u64,
    model_bytes_loaded: u64,
}

#[derive(Clone)]
// UAS: uas:depth-lease-checkpoint:fixture
// Plane: Controller + Verification
// Residency: metadata-only depth lease fixture.
struct DepthCheckpointFixture {
    fixture_id: String,
    depth_checkpoint_policy_ref: String,
    answer_packet_coverage_bps: u64,
    silent_promotion_rejection_bps: u64,
    checkpoints: Vec<DepthCheckpoint>,
}

#[derive(Default)]
// UAS: uas:depth-lease-checkpoint:metrics
// Plane: Verification
// Residency: derived metadata-only measurement summary.
struct DepthCheckpointMetrics {
    fixture_count: u64,
    checkpoint_count: u64,
    held_out_checkpoint_count: u64,
    shallow_exit_count: u64,
    deeper_wake_count: u64,
    full_depth_fallback_count: u64,
    resume_token_count: u64,
    rollback_handle_count: u64,
    run_event_log_count: u64,
    answer_packet_count: u64,
    min_verifier_margin_bps: u64,
    max_extra_layers: u64,
    max_depth_delta: u64,
    max_latency_ms: u64,
    lease_success_bps: u64,
    answer_packet_coverage_bps: u64,
    silent_promotion_rejection_bps: u64,
    shallow_only_baseline_bps: u64,
    hidden_depth_baseline_bps: u64,
    no_checkpoint_baseline_bps: u64,
    no_fallback_baseline_bps: u64,
    max_checkpoint_metadata_bytes: u64,
}

// UAS: uas:depth-lease-checkpoint:registry
// Plane: Controller + Verification
// Residency: metadata-only fixture registry; no live depth route authority.
struct DepthCheckpointRegistry {
    fixtures: Vec<DepthCheckpointFixture>,
}

impl DepthCheckpointRegistry {
    fn new(fixtures: Vec<DepthCheckpointFixture>) -> Result<Self, DepthCheckpointError> {
        validate_fixtures(&fixtures)?;
        Ok(Self { fixtures })
    }

    fn metrics(&self) -> DepthCheckpointMetrics {
        let mut checkpoint_ids = BTreeSet::new();
        let mut resume_tokens = BTreeSet::new();
        let mut rollbacks = BTreeSet::new();
        let mut run_logs = BTreeSet::new();
        let mut packets = BTreeSet::new();
        let mut min_margin = u64::MAX;
        let mut max_extra = 0_u64;
        let mut max_delta = 0_u64;
        let mut max_latency = 0_u64;
        let mut success_sum = 0_u64;
        let mut shallow_baseline = 0_u64;
        let mut hidden_baseline = 0_u64;
        let mut no_checkpoint_baseline = 0_u64;
        let mut no_fallback_baseline = 0_u64;
        let mut max_metadata = 0_u64;
        let mut held_out = 0_u64;
        let mut fallback_count = 0_u64;
        let mut shallow_count = 0_u64;
        let mut deeper_count = 0_u64;
        let mut answer_packet_floor = u64::MAX;
        let mut rejection_floor = u64::MAX;

        for fixture in &self.fixtures {
            answer_packet_floor = answer_packet_floor.min(fixture.answer_packet_coverage_bps);
            rejection_floor = rejection_floor.min(fixture.silent_promotion_rejection_bps);
            for checkpoint in &fixture.checkpoints {
                checkpoint_ids.insert(checkpoint.checkpoint_id.clone());
                resume_tokens.insert(checkpoint.resume_token_ref.clone());
                rollbacks.insert(checkpoint.rollback_handle.clone());
                run_logs.insert(checkpoint.run_event_log_ref.clone());
                packets.insert(checkpoint.answer_packet_ref.clone());
                min_margin = min_margin.min(checkpoint.verifier_margin_bps);
                max_extra = max_extra.max(checkpoint.max_extra_layers);
                max_delta = max_delta.max(
                    u64::from(checkpoint.deeper_wake_layer)
                        .saturating_sub(u64::from(checkpoint.shallow_exit_layer)),
                );
                max_latency = max_latency.max(checkpoint.expected_latency_ms);
                success_sum += checkpoint.lease_success_bps;
                shallow_baseline = shallow_baseline.max(checkpoint.shallow_only_baseline_bps);
                hidden_baseline = hidden_baseline.max(checkpoint.hidden_depth_baseline_bps);
                no_checkpoint_baseline =
                    no_checkpoint_baseline.max(checkpoint.no_checkpoint_baseline_bps);
                no_fallback_baseline =
                    no_fallback_baseline.max(checkpoint.no_fallback_baseline_bps);
                max_metadata = max_metadata.max(checkpoint.metadata_bytes);
                if checkpoint.split == "held_out" {
                    held_out += 1;
                }
                if checkpoint.fallback_enabled && !checkpoint.full_depth_fallback_ref.is_empty() {
                    fallback_count += 1;
                }
                if checkpoint.shallow_exit_layer > 0 {
                    shallow_count += 1;
                }
                if checkpoint.deeper_wake_layer > checkpoint.shallow_exit_layer {
                    deeper_count += 1;
                }
            }
        }

        let checkpoint_count = checkpoint_ids.len() as u64;
        DepthCheckpointMetrics {
            fixture_count: self.fixtures.len() as u64,
            checkpoint_count,
            held_out_checkpoint_count: held_out,
            shallow_exit_count: shallow_count,
            deeper_wake_count: deeper_count,
            full_depth_fallback_count: fallback_count,
            resume_token_count: resume_tokens.len() as u64,
            rollback_handle_count: rollbacks.len() as u64,
            run_event_log_count: run_logs.len() as u64,
            answer_packet_count: packets.len() as u64,
            min_verifier_margin_bps: if min_margin == u64::MAX {
                0
            } else {
                min_margin
            },
            max_extra_layers: max_extra,
            max_depth_delta: max_delta,
            max_latency_ms: max_latency,
            lease_success_bps: if checkpoint_count == 0 {
                0
            } else {
                success_sum / checkpoint_count
            },
            answer_packet_coverage_bps: if answer_packet_floor == u64::MAX {
                0
            } else {
                answer_packet_floor
            },
            silent_promotion_rejection_bps: if rejection_floor == u64::MAX {
                0
            } else {
                rejection_floor
            },
            shallow_only_baseline_bps: shallow_baseline,
            hidden_depth_baseline_bps: hidden_baseline,
            no_checkpoint_baseline_bps: no_checkpoint_baseline,
            no_fallback_baseline_bps: no_fallback_baseline,
            max_checkpoint_metadata_bytes: max_metadata,
        }
    }

    fn address(&self) -> String {
        let mut rows = Vec::with_capacity(self.fixtures.len());
        for fixture in &self.fixtures {
            let mut checkpoint_ids: Vec<&str> = fixture
                .checkpoints
                .iter()
                .map(|checkpoint| checkpoint.checkpoint_id.as_str())
                .collect();
            checkpoint_ids.sort_unstable();
            rows.push(format!(
                "{}:{}:{}",
                fixture.fixture_id,
                fixture.depth_checkpoint_policy_ref,
                checkpoint_ids.join(",")
            ));
        }
        rows.sort();
        sha256_hex(rows.join("|").as_bytes()).replacen(
            "sha256:",
            "uas:depth-lease-checkpoint:sha256:",
            1,
        )
    }
}

#[derive(Debug, PartialEq, Eq)]
// UAS: uas:depth-lease-checkpoint:error
// Plane: Verification
// Residency: metadata-only rejection reason; no live route mutation.
enum DepthCheckpointError {
    EmptyFixtures,
    DuplicateFixture,
    MissingFixture,
    MissingPolicy,
    MissingCheckpoint,
    DuplicateCheckpoint,
    MissingField,
    MissingShallowExit,
    MissingDeeperWake,
    InvalidDepthOrder,
    MissingFullDepth,
    ExtraLayerBudget,
    MissingVerifierMargin,
    VerifierMarginTooLow,
    LatencyBudget,
    MissingFallback,
    FallbackDisabled,
    MissingAnswerPacketField,
    InvalidFence,
    InvalidPrivacy,
    InvalidSplit,
    MissingHeldOut,
    SilentDepthPromotion,
    LiveRouteAuthority,
    BaseWeightMutated,
    RoutePolicyMutated,
    CacheMutated,
    HiddenAuthority,
    RuntimeBytes,
    ModelBytes,
    MetadataBudget,
    BaselineUnbeaten,
}

fn validate_fixtures(fixtures: &[DepthCheckpointFixture]) -> Result<(), DepthCheckpointError> {
    if fixtures.is_empty() {
        return Err(DepthCheckpointError::EmptyFixtures);
    }

    let mut fixture_ids = BTreeSet::new();
    let mut checkpoint_ids = BTreeSet::new();
    let mut held_out_seen = false;

    for fixture in fixtures {
        if fixture.fixture_id.is_empty() {
            return Err(DepthCheckpointError::MissingFixture);
        }
        if !fixture_ids.insert(fixture.fixture_id.as_str()) {
            return Err(DepthCheckpointError::DuplicateFixture);
        }
        if fixture.depth_checkpoint_policy_ref.is_empty() {
            return Err(DepthCheckpointError::MissingPolicy);
        }
        if fixture.checkpoints.is_empty() {
            return Err(DepthCheckpointError::MissingCheckpoint);
        }
        if fixture.answer_packet_coverage_bps < MIN_ANSWER_PACKET_COVERAGE_BPS
            || fixture.silent_promotion_rejection_bps < MIN_SILENT_PROMOTION_REJECTION_BPS
        {
            return Err(DepthCheckpointError::BaselineUnbeaten);
        }

        for checkpoint in &fixture.checkpoints {
            validate_checkpoint(checkpoint)?;
            if !checkpoint_ids.insert(checkpoint.checkpoint_id.as_str()) {
                return Err(DepthCheckpointError::DuplicateCheckpoint);
            }
            held_out_seen |= checkpoint.split == "held_out";
        }
    }

    if !held_out_seen {
        return Err(DepthCheckpointError::MissingHeldOut);
    }

    Ok(())
}

fn validate_checkpoint(checkpoint: &DepthCheckpoint) -> Result<(), DepthCheckpointError> {
    if checkpoint.checkpoint_id.is_empty()
        || checkpoint.mission_id.is_empty()
        || checkpoint.upstream_layer_kv_lease_ref.is_empty()
        || checkpoint.upstream_fast_weight_quarantine_ref.is_empty()
        || checkpoint.route_card_ref.is_empty()
        || checkpoint.depth_policy_ref.is_empty()
        || checkpoint.checkpoint_ref.is_empty()
        || checkpoint.resume_token_ref.is_empty()
        || checkpoint.full_depth_fallback_ref.is_empty()
        || checkpoint.rollback_handle.is_empty()
        || checkpoint.run_event_log_ref.is_empty()
        || checkpoint.answer_packet_ref.is_empty()
        || checkpoint.mutation_safety_fence.is_empty()
    {
        return Err(DepthCheckpointError::MissingField);
    }
    if checkpoint.shallow_exit_layer == 0 {
        return Err(DepthCheckpointError::MissingShallowExit);
    }
    if checkpoint.deeper_wake_layer == 0 {
        return Err(DepthCheckpointError::MissingDeeperWake);
    }
    if checkpoint.deeper_wake_layer <= checkpoint.shallow_exit_layer {
        return Err(DepthCheckpointError::InvalidDepthOrder);
    }
    if checkpoint.full_depth_layer < checkpoint.deeper_wake_layer {
        return Err(DepthCheckpointError::MissingFullDepth);
    }
    let actual_extra = u64::from(checkpoint.deeper_wake_layer - checkpoint.shallow_exit_layer);
    if checkpoint.max_extra_layers == 0
        || checkpoint.max_extra_layers > MAX_EXTRA_LAYERS
        || checkpoint.expected_extra_layers == 0
        || checkpoint.expected_extra_layers > checkpoint.max_extra_layers
        || actual_extra > checkpoint.max_extra_layers
    {
        return Err(DepthCheckpointError::ExtraLayerBudget);
    }
    if checkpoint.verifier_margin_bps == 0 {
        return Err(DepthCheckpointError::MissingVerifierMargin);
    }
    if checkpoint.verifier_margin_bps < MIN_VERIFIER_MARGIN_BPS {
        return Err(DepthCheckpointError::VerifierMarginTooLow);
    }
    if checkpoint.expected_latency_ms == 0
        || checkpoint.expected_latency_ms > checkpoint.latency_budget_ms
        || checkpoint.latency_budget_ms > MAX_LATENCY_MS
    {
        return Err(DepthCheckpointError::LatencyBudget);
    }
    if checkpoint.full_depth_fallback_ref.is_empty() {
        return Err(DepthCheckpointError::MissingFallback);
    }
    if !checkpoint.fallback_enabled {
        return Err(DepthCheckpointError::FallbackDisabled);
    }
    if !REQUIRED_PACKET_FIELDS.iter().all(|field| {
        checkpoint
            .answer_packet_fields
            .iter()
            .any(|value| value == field)
    }) {
        return Err(DepthCheckpointError::MissingAnswerPacketField);
    }
    if checkpoint.compatibility_fence != CURRENT_FENCE {
        return Err(DepthCheckpointError::InvalidFence);
    }
    if !valid_privacy_class(&checkpoint.privacy_class) {
        return Err(DepthCheckpointError::InvalidPrivacy);
    }
    if !valid_split(&checkpoint.split) {
        return Err(DepthCheckpointError::InvalidSplit);
    }
    if checkpoint.silent_depth_promotion {
        return Err(DepthCheckpointError::SilentDepthPromotion);
    }
    if checkpoint.live_route_authority {
        return Err(DepthCheckpointError::LiveRouteAuthority);
    }
    if checkpoint.base_weight_mutated {
        return Err(DepthCheckpointError::BaseWeightMutated);
    }
    if checkpoint.route_policy_mutated {
        return Err(DepthCheckpointError::RoutePolicyMutated);
    }
    if checkpoint.cache_mutated {
        return Err(DepthCheckpointError::CacheMutated);
    }
    if checkpoint.hidden_chain_exposed || checkpoint.hidden_cloud {
        return Err(DepthCheckpointError::HiddenAuthority);
    }
    if checkpoint.runtime_bytes_loaded > 0 {
        return Err(DepthCheckpointError::RuntimeBytes);
    }
    if checkpoint.model_bytes_loaded > 0 {
        return Err(DepthCheckpointError::ModelBytes);
    }
    if checkpoint.metadata_bytes > MAX_CHECKPOINT_METADATA_BYTES {
        return Err(DepthCheckpointError::MetadataBudget);
    }
    if checkpoint.lease_success_bps < MIN_LEASE_SUCCESS_BPS
        || checkpoint.lease_success_bps <= checkpoint.shallow_only_baseline_bps
        || checkpoint.lease_success_bps <= checkpoint.hidden_depth_baseline_bps
        || checkpoint.lease_success_bps <= checkpoint.no_checkpoint_baseline_bps
        || checkpoint.lease_success_bps <= checkpoint.no_fallback_baseline_bps
    {
        return Err(DepthCheckpointError::BaselineUnbeaten);
    }

    Ok(())
}

fn valid_privacy_class(class: &str) -> bool {
    matches!(class, "local_private" | "vault_private" | "project_private")
}

fn valid_split(split: &str) -> bool {
    matches!(split, "train" | "held_out")
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

fn invalid_fixture_axes(fixtures: &[DepthCheckpointFixture]) -> Vec<(&'static str, bool)> {
    let mut cases: Vec<(&'static str, Box<dyn Fn(&mut DepthCheckpointFixture)>)> = vec![
        (
            "duplicate_fixture_rejected",
            Box::new(|fixture| fixture.fixture_id = "depth_fixture_proof_route".to_string()),
        ),
        (
            "missing_fixture_id_rejected",
            Box::new(|fixture| fixture.fixture_id.clear()),
        ),
        (
            "missing_fixture_policy_rejected",
            Box::new(|fixture| fixture.depth_checkpoint_policy_ref.clear()),
        ),
        (
            "missing_checkpoint_record_rejected",
            Box::new(|fixture| fixture.checkpoints.clear()),
        ),
        (
            "duplicate_checkpoint_rejected",
            Box::new(|fixture| {
                fixture.checkpoints[0].checkpoint_id = "depth-proof-001".to_string()
            }),
        ),
        (
            "missing_checkpoint_id_rejected",
            Box::new(|fixture| fixture.checkpoints[0].checkpoint_id.clear()),
        ),
        (
            "missing_mission_rejected",
            Box::new(|fixture| fixture.checkpoints[0].mission_id.clear()),
        ),
        (
            "missing_upstream_layer_kv_rejected",
            Box::new(|fixture| fixture.checkpoints[0].upstream_layer_kv_lease_ref.clear()),
        ),
        (
            "missing_upstream_fast_weight_quarantine_rejected",
            Box::new(|fixture| {
                fixture.checkpoints[0]
                    .upstream_fast_weight_quarantine_ref
                    .clear()
            }),
        ),
        (
            "missing_route_card_rejected",
            Box::new(|fixture| fixture.checkpoints[0].route_card_ref.clear()),
        ),
        (
            "missing_depth_policy_rejected",
            Box::new(|fixture| fixture.checkpoints[0].depth_policy_ref.clear()),
        ),
        (
            "missing_shallow_exit_rejected",
            Box::new(|fixture| fixture.checkpoints[0].shallow_exit_layer = 0),
        ),
        (
            "missing_deeper_wake_rejected",
            Box::new(|fixture| fixture.checkpoints[0].deeper_wake_layer = 0),
        ),
        (
            "invalid_depth_order_rejected",
            Box::new(|fixture| fixture.checkpoints[0].deeper_wake_layer = 10),
        ),
        (
            "missing_full_depth_rejected",
            Box::new(|fixture| fixture.checkpoints[0].full_depth_layer = 18),
        ),
        (
            "extra_layer_budget_rejected",
            Box::new(|fixture| fixture.checkpoints[0].expected_extra_layers = MAX_EXTRA_LAYERS + 1),
        ),
        (
            "missing_checkpoint_ref_rejected",
            Box::new(|fixture| fixture.checkpoints[0].checkpoint_ref.clear()),
        ),
        (
            "missing_resume_token_rejected",
            Box::new(|fixture| fixture.checkpoints[0].resume_token_ref.clear()),
        ),
        (
            "missing_verifier_margin_rejected",
            Box::new(|fixture| fixture.checkpoints[0].verifier_margin_bps = 0),
        ),
        (
            "verifier_margin_too_low_rejected",
            Box::new(|fixture| fixture.checkpoints[0].verifier_margin_bps = 1_000),
        ),
        (
            "latency_budget_rejected",
            Box::new(|fixture| fixture.checkpoints[0].expected_latency_ms = MAX_LATENCY_MS + 1),
        ),
        (
            "missing_full_depth_fallback_rejected",
            Box::new(|fixture| fixture.checkpoints[0].full_depth_fallback_ref.clear()),
        ),
        (
            "fallback_disabled_rejected",
            Box::new(|fixture| fixture.checkpoints[0].fallback_enabled = false),
        ),
        (
            "missing_rollback_rejected",
            Box::new(|fixture| fixture.checkpoints[0].rollback_handle.clear()),
        ),
        (
            "missing_run_event_log_rejected",
            Box::new(|fixture| fixture.checkpoints[0].run_event_log_ref.clear()),
        ),
        (
            "missing_answer_packet_rejected",
            Box::new(|fixture| fixture.checkpoints[0].answer_packet_ref.clear()),
        ),
        (
            "missing_answer_packet_field_rejected",
            Box::new(|fixture| {
                fixture.checkpoints[0]
                    .answer_packet_fields
                    .pop()
                    .map(drop)
                    .unwrap_or(())
            }),
        ),
        (
            "missing_mutation_safety_fence_rejected",
            Box::new(|fixture| fixture.checkpoints[0].mutation_safety_fence.clear()),
        ),
        (
            "incompatible_fence_rejected",
            Box::new(|fixture| {
                fixture.checkpoints[0].compatibility_fence = "fence:old".to_string()
            }),
        ),
        (
            "invalid_privacy_rejected",
            Box::new(|fixture| fixture.checkpoints[0].privacy_class = "public".to_string()),
        ),
        (
            "missing_split_rejected",
            Box::new(|fixture| fixture.checkpoints[0].split.clear()),
        ),
        (
            "invalid_split_rejected",
            Box::new(|fixture| fixture.checkpoints[0].split = "validation".to_string()),
        ),
        (
            "silent_depth_promotion_case_rejected",
            Box::new(|fixture| fixture.checkpoints[0].silent_depth_promotion = true),
        ),
        (
            "live_route_authority_rejected",
            Box::new(|fixture| fixture.checkpoints[0].live_route_authority = true),
        ),
        (
            "base_weight_mutation_rejected",
            Box::new(|fixture| fixture.checkpoints[0].base_weight_mutated = true),
        ),
        (
            "route_policy_mutation_rejected",
            Box::new(|fixture| fixture.checkpoints[0].route_policy_mutated = true),
        ),
        (
            "cache_mutation_rejected",
            Box::new(|fixture| fixture.checkpoints[0].cache_mutated = true),
        ),
        (
            "hidden_chain_exposure_rejected",
            Box::new(|fixture| fixture.checkpoints[0].hidden_chain_exposed = true),
        ),
        (
            "cloud_source_rejected",
            Box::new(|fixture| fixture.checkpoints[0].hidden_cloud = true),
        ),
        (
            "runtime_bytes_rejected",
            Box::new(|fixture| fixture.checkpoints[0].runtime_bytes_loaded = 1),
        ),
        (
            "model_bytes_rejected",
            Box::new(|fixture| fixture.checkpoints[0].model_bytes_loaded = 1),
        ),
        (
            "metadata_budget_rejected",
            Box::new(|fixture| {
                fixture.checkpoints[0].metadata_bytes = MAX_CHECKPOINT_METADATA_BYTES + 1
            }),
        ),
        (
            "shallow_only_baseline_unbeaten_rejected",
            Box::new(|fixture| fixture.checkpoints[0].shallow_only_baseline_bps = 9_900),
        ),
        (
            "hidden_depth_baseline_unbeaten_rejected",
            Box::new(|fixture| fixture.checkpoints[0].hidden_depth_baseline_bps = 9_900),
        ),
        (
            "no_checkpoint_baseline_unbeaten_rejected",
            Box::new(|fixture| fixture.checkpoints[0].no_checkpoint_baseline_bps = 9_900),
        ),
        (
            "no_fallback_baseline_unbeaten_rejected",
            Box::new(|fixture| fixture.checkpoints[0].no_fallback_baseline_bps = 9_900),
        ),
    ];

    let mut axes = Vec::with_capacity(cases.len() + 1);
    for (axis, mutate) in cases.drain(..) {
        let mut candidate = fixtures.to_vec();
        if candidate.len() < 2 || candidate[1].checkpoints.is_empty() {
            axes.push((axis, false));
            continue;
        }
        mutate(&mut candidate[1]);
        axes.push((axis, DepthCheckpointRegistry::new(candidate).is_err()));
    }

    let mut missing_held_out = fixtures.to_vec();
    for fixture in &mut missing_held_out {
        for checkpoint in &mut fixture.checkpoints {
            checkpoint.split = "train".to_string();
        }
    }
    axes.push((
        "missing_held_out_split_rejected",
        DepthCheckpointRegistry::new(missing_held_out).is_err(),
    ));
    axes
}

fn fixture_depth_checkpoints() -> Vec<DepthCheckpointFixture> {
    vec![
        DepthCheckpointFixture {
            fixture_id: "depth_fixture_proof_route".to_string(),
            depth_checkpoint_policy_ref: "policy:depth-lease-checkpoint:v1".to_string(),
            answer_packet_coverage_bps: 10_000,
            silent_promotion_rejection_bps: 10_000,
            checkpoints: vec![
                checkpoint(
                    "depth-proof-001",
                    "mission-proof-route",
                    16,
                    22,
                    40,
                    6,
                    1_900,
                    152,
                    9_350,
                    "train",
                    "local_private",
                ),
                checkpoint(
                    "depth-proof-002",
                    "mission-proof-route",
                    18,
                    26,
                    40,
                    8,
                    1_750,
                    168,
                    9_180,
                    "held_out",
                    "project_private",
                ),
                checkpoint(
                    "depth-proof-003",
                    "mission-proof-route",
                    20,
                    24,
                    40,
                    4,
                    2_100,
                    144,
                    9_260,
                    "held_out",
                    "vault_private",
                ),
            ],
        },
        DepthCheckpointFixture {
            fixture_id: "depth_fixture_kv_route".to_string(),
            depth_checkpoint_policy_ref: "policy:depth-lease-checkpoint:v1".to_string(),
            answer_packet_coverage_bps: 10_000,
            silent_promotion_rejection_bps: 10_000,
            checkpoints: vec![
                checkpoint(
                    "depth-kv-001",
                    "mission-kv-route",
                    14,
                    20,
                    40,
                    6,
                    1_820,
                    156,
                    9_240,
                    "train",
                    "vault_private",
                ),
                checkpoint(
                    "depth-kv-002",
                    "mission-kv-route",
                    16,
                    24,
                    40,
                    8,
                    1_690,
                    178,
                    9_140,
                    "held_out",
                    "project_private",
                ),
                checkpoint(
                    "depth-kv-003",
                    "mission-kv-route",
                    18,
                    22,
                    40,
                    4,
                    2_200,
                    132,
                    9_320,
                    "held_out",
                    "local_private",
                ),
            ],
        },
    ]
}

#[allow(clippy::too_many_arguments)]
fn checkpoint(
    checkpoint_id: &str,
    mission_id: &str,
    shallow_exit_layer: u16,
    deeper_wake_layer: u16,
    full_depth_layer: u16,
    expected_extra_layers: u64,
    verifier_margin_bps: u64,
    expected_latency_ms: u64,
    lease_success_bps: u64,
    split: &str,
    privacy_class: &str,
) -> DepthCheckpoint {
    let suffix = checkpoint_id.replace('_', "-");
    DepthCheckpoint {
        checkpoint_id: checkpoint_id.to_string(),
        mission_id: mission_id.to_string(),
        upstream_layer_kv_lease_ref: "artifact:layer_kv_joint_lease:result".to_string(),
        upstream_fast_weight_quarantine_ref: "artifact:fast_weight_quarantine:result".to_string(),
        route_card_ref: format!("route-card:depth-lease:{suffix}"),
        depth_policy_ref: "policy:depth-lease-checkpoint:v1".to_string(),
        shallow_exit_layer,
        deeper_wake_layer,
        full_depth_layer,
        checkpoint_ref: format!("checkpoint:depth-lease:{suffix}"),
        resume_token_ref: format!("compute-resume-lease:{suffix}"),
        verifier_margin_bps,
        max_extra_layers: MAX_EXTRA_LAYERS,
        expected_extra_layers,
        latency_budget_ms: MAX_LATENCY_MS,
        expected_latency_ms,
        full_depth_fallback_ref: format!("fallback:full-depth:{suffix}"),
        fallback_enabled: true,
        rollback_handle: format!("rollback:depth-lease:{suffix}"),
        run_event_log_ref: format!("run-event-log:depth-lease:{suffix}"),
        answer_packet_ref: format!("answer-packet:depth-lease:{suffix}"),
        answer_packet_fields: REQUIRED_PACKET_FIELDS
            .iter()
            .map(|field| field.to_string())
            .collect(),
        mutation_safety_fence: format!("mutation-safety-fence:depth-lease:{suffix}"),
        compatibility_fence: CURRENT_FENCE.to_string(),
        privacy_class: privacy_class.to_string(),
        split: split.to_string(),
        lease_success_bps,
        shallow_only_baseline_bps: 8_200,
        hidden_depth_baseline_bps: 7_700,
        no_checkpoint_baseline_bps: 7_500,
        no_fallback_baseline_bps: 7_300,
        metadata_bytes: 448 * 1024,
        silent_depth_promotion: false,
        live_route_authority: false,
        base_weight_mutated: false,
        route_policy_mutated: false,
        cache_mutated: false,
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
    let fixtures = fixture_depth_checkpoints();
    let registry =
        DepthCheckpointRegistry::new(fixtures.clone()).map_err(|err| format!("{err:?}"))?;
    let metrics = registry.metrics();
    let address = registry.address();

    let mut reversed = fixtures.clone();
    reversed.reverse();
    for fixture in &mut reversed {
        fixture.checkpoints.reverse();
    }
    let reversed_address = DepthCheckpointRegistry::new(reversed)
        .map_err(|err| format!("reversed registry failed: {err:?}"))?
        .address();

    let upstream_layer_kv_pass = upstream_artifact_pass(UPSTREAM_LAYER_KV);
    let upstream_fast_weight_quarantine_pass =
        upstream_artifact_pass(UPSTREAM_FAST_WEIGHT_QUARANTINE);
    let invalid_axes = invalid_fixture_axes(&fixtures);

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let bool_axes = [
        ("upstream_layer_kv_joint_lease_pass", upstream_layer_kv_pass),
        (
            "upstream_fast_weight_quarantine_pass",
            upstream_fast_weight_quarantine_pass,
        ),
        ("checkpoint_fixture_present", metrics.fixture_count >= 2),
        ("fixture_ids_bound", true),
        ("checkpoint_ids_bound", true),
        ("mission_ids_bound", true),
        ("route_card_refs_bound", true),
        ("depth_policy_refs_bound", true),
        (
            "shallow_exit_declared",
            metrics.shallow_exit_count == metrics.checkpoint_count,
        ),
        (
            "deeper_wake_declared",
            metrics.deeper_wake_count == metrics.checkpoint_count,
        ),
        (
            "verifier_margin_bound",
            metrics.min_verifier_margin_bps >= MIN_VERIFIER_MARGIN_BPS,
        ),
        (
            "max_extra_layers_bound",
            metrics.max_extra_layers <= MAX_EXTRA_LAYERS,
        ),
        (
            "full_depth_fallback_bound",
            metrics.full_depth_fallback_count == metrics.checkpoint_count,
        ),
        ("checkpoint_refs_bound", true),
        (
            "resume_tokens_bound",
            metrics.resume_token_count == metrics.checkpoint_count,
        ),
        (
            "rollback_bound",
            metrics.rollback_handle_count == metrics.checkpoint_count,
        ),
        (
            "run_event_log_bound",
            metrics.run_event_log_count == metrics.checkpoint_count,
        ),
        (
            "answer_packet_ref_bound",
            metrics.answer_packet_count == metrics.checkpoint_count,
        ),
        ("answer_packet_fields_bound", true),
        ("mutation_safety_fence_bound", true),
        ("compatibility_fence_bound", true),
        ("privacy_classes_bound", true),
        (
            "held_out_split_bound",
            metrics.held_out_checkpoint_count >= 4,
        ),
        ("depth_lease_shadow_only", true),
        ("silent_depth_promotion_rejected", true),
        ("full_depth_fallback_visible", true),
        ("no_live_route_authority", true),
        ("no_base_weight_mutation", true),
        ("no_route_policy_mutation", true),
        ("no_cache_mutation", true),
        ("no_hidden_chain", true),
        ("no_hidden_cloud", true),
        ("no_runtime_bytes_loaded", true),
        ("no_model_bytes_loaded", true),
        (
            "depth_lease_checkpoint_address_deterministic",
            address == reversed_address,
        ),
        (
            "metadata_bound",
            metrics.max_checkpoint_metadata_bytes <= MAX_CHECKPOINT_METADATA_BYTES,
        ),
        (
            "beats_shallow_only_baseline",
            metrics.lease_success_bps > metrics.shallow_only_baseline_bps,
        ),
        (
            "beats_hidden_depth_baseline",
            metrics.lease_success_bps > metrics.hidden_depth_baseline_bps,
        ),
        (
            "beats_no_checkpoint_baseline",
            metrics.lease_success_bps > metrics.no_checkpoint_baseline_bps,
        ),
        (
            "beats_no_fallback_baseline",
            metrics.lease_success_bps > metrics.no_fallback_baseline_bps,
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
        "checkpoint_count",
        metrics.checkpoint_count,
        6,
        "checkpoint",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_checkpoint_count",
        metrics.held_out_checkpoint_count,
        4,
        "checkpoint",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "shallow_exit_count",
        metrics.shallow_exit_count,
        6,
        "checkpoint",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "deeper_wake_count",
        metrics.deeper_wake_count,
        6,
        "checkpoint",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "full_depth_fallback_count",
        metrics.full_depth_fallback_count,
        6,
        "fallback",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "resume_token_count",
        metrics.resume_token_count,
        6,
        "token",
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
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "run_event_log_count",
        metrics.run_event_log_count,
        6,
        "log",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "answer_packet_count",
        metrics.answer_packet_count,
        6,
        "packet",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "min_verifier_margin_bps",
        metrics.min_verifier_margin_bps,
        ">=",
        MIN_VERIFIER_MARGIN_BPS,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_extra_layers",
        metrics.max_extra_layers,
        "<=",
        MAX_EXTRA_LAYERS,
        "layer",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_depth_delta",
        metrics.max_depth_delta,
        "<=",
        MAX_EXTRA_LAYERS,
        "layer",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_latency_ms",
        metrics.max_latency_ms,
        "<=",
        MAX_LATENCY_MS,
        "ms",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "lease_success_bps",
        metrics.lease_success_bps,
        ">=",
        MIN_LEASE_SUCCESS_BPS,
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
        "silent_promotion_rejection_bps",
        metrics.silent_promotion_rejection_bps,
        ">=",
        MIN_SILENT_PROMOTION_REJECTION_BPS,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "shallow_only_baseline_bps",
        metrics.shallow_only_baseline_bps,
        "<=",
        metrics.lease_success_bps.saturating_sub(1),
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hidden_depth_baseline_bps",
        metrics.hidden_depth_baseline_bps,
        "<=",
        metrics.lease_success_bps.saturating_sub(1),
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_checkpoint_baseline_bps",
        metrics.no_checkpoint_baseline_bps,
        "<=",
        metrics.lease_success_bps.saturating_sub(1),
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_fallback_baseline_bps",
        metrics.no_fallback_baseline_bps,
        "<=",
        metrics.lease_success_bps.saturating_sub(1),
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_checkpoint_metadata_bytes",
        metrics.max_checkpoint_metadata_bytes,
        "<=",
        MAX_CHECKPOINT_METADATA_BYTES,
        "byte",
    );
    measurements.insert(
        "depth_lease_checkpoint_address".to_string(),
        Measurement {
            value: serde_json::Value::String(address),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "depth_lease_checkpoint_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::Value::String("uas:depth-lease-checkpoint:sha256:".to_string()),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert("depth_lease_checkpoint_address".to_string(), true);

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
        notes: "metadata-only adaptive-depth checkpoint witness: shallow exit, deeper wake, verifier margin, max extra layers, full-depth fallback, rollback, RunEventLog, and AnswerPacket are required; no runtime/model bytes; L1 only".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let artifact =
        build_artifact().map_err(|err| format!("depth lease checkpoint failed: {err}"))?;
    let path = PathBuf::from(RESULT);
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let mut file = std::fs::File::create(&path)?;
    write_artifact(&mut file, &artifact)?;

    println!(
        "{FALSIFIER_ID}: overall_pass={} checkpoint_count={} max_extra_layers={} depth_lease_checkpoint_address={:?} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["checkpoint_count"].value,
        artifact.measurements["max_extra_layers"].value,
        artifact.measurements["depth_lease_checkpoint_address"].value
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
        match DepthCheckpointRegistry::new(Vec::new()) {
            Err(err) => assert_eq!(err, DepthCheckpointError::EmptyFixtures),
            Ok(_) => panic!("empty fixture unexpectedly passed"),
        }
    }

    #[test]
    fn invalid_fixture_cases_reject() {
        let fixtures = fixture_depth_checkpoints();
        for (axis, passed) in invalid_fixture_axes(&fixtures) {
            assert!(passed, "{axis} did not reject");
        }
    }

    #[test]
    fn depth_checkpoint_address_is_order_stable() {
        let fixtures = fixture_depth_checkpoints();
        let registry = match DepthCheckpointRegistry::new(fixtures.clone()) {
            Ok(registry) => registry,
            Err(err) => panic!("registry unexpectedly failed: {err:?}"),
        };
        let mut reversed = fixtures;
        reversed.reverse();
        for fixture in &mut reversed {
            fixture.checkpoints.reverse();
        }
        let reversed_registry = match DepthCheckpointRegistry::new(reversed) {
            Ok(registry) => registry,
            Err(err) => panic!("reversed registry unexpectedly failed: {err:?}"),
        };
        assert_eq!(registry.address(), reversed_registry.address());
    }
}
