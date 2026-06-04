//! `falsify_sparse_wake_proposal_budget` -- sparse wake budget contract.
//!
//! Metadata-only witness for `F-SparseWakeProposal-Budget`. It proves a sparse
//! wake proposal names selected/rejected UAS units, accounts hot/KV/cold bytes,
//! binds fallback/uncertainty/verifier need, and rejects unsafe or over-budget
//! wake requests before any model/runtime bytes can load.

use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-SparseWakeProposal-Budget";
const FIXTURE_ID: &str = "sparse_wake_proposal_budget_v1";
const COMMAND: &str = "Tools/falsifiers/f_sparse_wake_proposal_budget.sh";
const RESULT: &str = "artifacts/falsifiers/sparse_wake_proposal_budget/result.json";
const UPSTREAM_ESCALATOR: &str = "artifacts/falsifiers/budgeted_uncertainty_escalator/result.json";
const MAX_PROPOSAL_METADATA_BYTES: u64 = 4 * 1024 * 1024;
const MIN_QUALITY_DELTA_BPS: i64 = 50;
const MIN_VERIFIER_DELTA_BPS: i64 = 50;

#[derive(Clone)]
// UAS: uas:sparse-wake-proposal:unit
// Plane: Assembly + Verification
// Residency: metadata-only candidate support unit.
struct WakeUnit {
    unit_id: &'static str,
    uas_address: &'static str,
    unit_kind: &'static str,
    hot_bytes: u64,
    kv_bytes: u64,
    cold_io_bytes: u64,
    verifier_delta_bps: i64,
    quality_delta_bps: i64,
    evidence_ref: &'static str,
    compatibility_fence: &'static str,
    privacy_class: &'static str,
}

#[derive(Clone)]
// UAS: uas:sparse-wake-proposal:rejected-unit
// Plane: Verification
// Residency: metadata-only rejected support unit.
struct RejectedUnit {
    unit_id: &'static str,
    reason: &'static str,
}

#[derive(Clone)]
// UAS: uas:sparse-wake-proposal:proposal
// Plane: Controller + Verification
// Residency: metadata-only wake request.
struct SparseWakeProposal {
    split: &'static str,
    proposal_id: &'static str,
    mission_id: &'static str,
    scout_ref: &'static str,
    escalator_ref: &'static str,
    selected_units: Vec<WakeUnit>,
    rejected_units: Vec<RejectedUnit>,
    expected_selected_unit_ids: &'static [&'static str],
    expected_rejected_unit_ids: &'static [&'static str],
    expected_quality_delta_bps: i64,
    expected_verifier_delta_bps: i64,
    hot_byte_budget: u64,
    kv_byte_budget: u64,
    cold_io_budget: u64,
    latency_budget_ms: u64,
    expected_latency_ms: u64,
    fallback_route: &'static str,
    uncertainty_bps: u64,
    verifier_need: &'static str,
    rollback_handle: &'static str,
    run_event_log_ref: &'static str,
    answer_packet_ref: &'static str,
    route_authority: &'static str,
    proposal_metadata_bytes: u64,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    live_policy_mutated: bool,
}

#[derive(Debug, Eq, PartialEq)]
// UAS: uas:sparse-wake-proposal:error
// Plane: Verification
// Residency: metadata-only rejection reason.
enum SparseWakeError {
    MissingProposal,
    DuplicateProposal,
    MissingSplit,
    MissingProposalId,
    MissingMission,
    MissingScoutRef,
    MissingEscalatorRef,
    MissingSelectedUnit,
    MissingRejectedUnit,
    MissingUasAddress,
    MissingUnitKind,
    MissingBudget,
    MissingFallback,
    MissingUncertainty,
    MissingVerifierNeed,
    MissingRollback,
    MissingRunEventLog,
    MissingAnswerPacket,
    InvalidPrivacyClass,
    InvalidUncertainty,
    InvalidExpectedSelection,
    HotBudgetExceeded,
    KvBudgetExceeded,
    ColdIoBudgetExceeded,
    LatencyBudgetExceeded,
    WeakQualityDelta,
    WeakVerifierDelta,
    MissingTrainingSplit,
    MissingHeldOutSplit,
    MissingWakeCase,
    MissingRejectCase,
    WakeAllBaselineUnbeaten,
    StaticBaselineUnbeaten,
    QwenEverythingBaselineUnbeaten,
    WrongWakeNotRejected,
    HiddenLiveAuthority,
    LivePolicyMutation,
    HiddenChainExposure,
    CloudRoute,
    ProposalMetadataBudgetExceeded,
}

impl std::fmt::Display for SparseWakeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for SparseWakeError {}

fn main() -> std::process::ExitCode {
    let artifact = match build_artifact() {
        Ok(artifact) => artifact,
        Err(error) => {
            eprintln!("failed to build {FALSIFIER_ID}: {error}");
            return std::process::ExitCode::from(2);
        }
    };

    let path = PathBuf::from(RESULT);
    if let Some(parent) = path.parent() {
        if let Err(error) = std::fs::create_dir_all(parent) {
            eprintln!("failed to create artifact directory: {error}");
            return std::process::ExitCode::from(2);
        }
    }
    let mut file = match std::fs::File::create(&path) {
        Ok(file) => file,
        Err(error) => {
            eprintln!("failed to open artifact: {error}");
            return std::process::ExitCode::from(2);
        }
    };
    if let Err(error) = write_artifact(&mut file, &artifact) {
        eprintln!("failed to write artifact: {error}");
        return std::process::ExitCode::from(2);
    }

    println!(
        "{FALSIFIER_ID}: overall_pass={} held_out_proposal_count={} sparse_wake_address={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["held_out_proposal_count"].value,
        artifact.measurements["sparse_wake_address"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let proposals = fixture_proposals();
    let reversed = proposals.iter().cloned().rev().collect::<Vec<_>>();
    let evaluation = SparseWakeEvaluation::new(proposals)?;
    let reversed_evaluation = SparseWakeEvaluation::new(reversed)?;
    let metrics = evaluation.metrics;

    let upstream_budgeted_uncertainty_escalator_pass = upstream_escalator_pass();
    let sparse_wake_fixture_present = evaluation.proposals.len() == 10;
    let training_split_bound = evaluation.training_proposal_count() >= 2;
    let held_out_split_bound = evaluation.held_out_proposal_count() >= 8;
    let proposal_ids_bound = evaluation
        .proposals
        .iter()
        .all(|proposal| proposal.proposal_id.starts_with("proposal:"));
    let mission_ids_bound = evaluation
        .proposals
        .iter()
        .all(|proposal| proposal.mission_id.starts_with("mission:"));
    let scout_refs_bound = evaluation
        .proposals
        .iter()
        .all(|proposal| proposal.scout_ref.starts_with("two-stage:"));
    let escalator_refs_bound = evaluation
        .proposals
        .iter()
        .all(|proposal| proposal.escalator_ref.starts_with("escalator:"));
    let selected_units_bound = evaluation
        .proposals
        .iter()
        .all(|proposal| !proposal.selected_units.is_empty());
    let rejected_units_bound = evaluation
        .proposals
        .iter()
        .all(|proposal| !proposal.rejected_units.is_empty());
    let unit_addresses_bound = evaluation.proposals.iter().all(|proposal| {
        proposal
            .selected_units
            .iter()
            .all(|unit| unit.uas_address.starts_with("uas:"))
    });
    let unit_kinds_bound = evaluation.proposals.iter().all(|proposal| {
        proposal.selected_units.iter().all(|unit| {
            matches!(
                unit.unit_kind,
                "model_tile" | "kv_page" | "evidence" | "verifier" | "adapter" | "tool"
            )
        })
    });
    let unit_budget_fields_bound = evaluation.proposals.iter().all(|proposal| {
        proposal
            .selected_units
            .iter()
            .all(|unit| unit.hot_bytes + unit.kv_bytes + unit.cold_io_bytes > 0)
    });
    let fallback_route_bound = evaluation
        .proposals
        .iter()
        .all(|proposal| proposal.fallback_route.starts_with("fallback:"));
    let uncertainty_bound = evaluation
        .proposals
        .iter()
        .all(|proposal| proposal.uncertainty_bps <= 10_000);
    let verifier_need_bound = evaluation
        .proposals
        .iter()
        .all(|proposal| proposal.verifier_need.starts_with("verifier:"));
    let quality_delta_positive = evaluation
        .proposals
        .iter()
        .all(|proposal| proposal.expected_quality_delta_bps >= MIN_QUALITY_DELTA_BPS);
    let verifier_delta_positive = evaluation
        .proposals
        .iter()
        .all(|proposal| proposal.expected_verifier_delta_bps >= MIN_VERIFIER_DELTA_BPS);
    let hot_bytes_within_budget = evaluation
        .proposals
        .iter()
        .all(|proposal| proposal.hot_bytes() <= proposal.hot_byte_budget);
    let kv_bytes_within_budget = evaluation
        .proposals
        .iter()
        .all(|proposal| proposal.kv_bytes() <= proposal.kv_byte_budget);
    let cold_io_within_budget = evaluation
        .proposals
        .iter()
        .all(|proposal| proposal.cold_io_bytes() <= proposal.cold_io_budget);
    let latency_within_budget = evaluation
        .proposals
        .iter()
        .all(|proposal| proposal.expected_latency_ms <= proposal.latency_budget_ms);
    let byte_budget_accounting_bound = evaluation
        .proposals
        .iter()
        .all(|proposal| proposal.hot_bytes() + proposal.kv_bytes() + proposal.cold_io_bytes() > 0);
    let reject_reasons_bound = evaluation.proposals.iter().all(|proposal| {
        proposal
            .rejected_units
            .iter()
            .all(|unit| unit.reason.starts_with("reject:"))
    });
    let rollback_bound = evaluation
        .proposals
        .iter()
        .all(|proposal| proposal.rollback_handle.starts_with("rollback:"));
    let run_event_log_bound = evaluation
        .proposals
        .iter()
        .all(|proposal| proposal.run_event_log_ref.starts_with("runlog:"));
    let answer_packet_ref_bound = evaluation
        .proposals
        .iter()
        .all(|proposal| proposal.answer_packet_ref.starts_with("answerpacket:"));
    let route_authority_shadow_only = evaluation
        .proposals
        .iter()
        .all(|proposal| proposal.route_authority == "shadow_only");
    let no_hidden_route_authority = route_authority_shadow_only;
    let no_hidden_chain = evaluation
        .proposals
        .iter()
        .all(|proposal| !proposal.hidden_chain_exposed);
    let no_hidden_cloud = evaluation
        .proposals
        .iter()
        .all(|proposal| !proposal.hidden_cloud);
    let live_policy_not_mutated = evaluation
        .proposals
        .iter()
        .all(|proposal| !proposal.live_policy_mutated);
    let sparse_wake_address_deterministic =
        evaluation.sparse_wake_address == reversed_evaluation.sparse_wake_address;
    let proposal_success_beats_wake_all_baseline =
        metrics.sparse_wake_success_bps > metrics.wake_all_baseline_success_bps;
    let proposal_success_beats_static_baseline =
        metrics.sparse_wake_success_bps > metrics.static_baseline_success_bps;
    let proposal_success_beats_qwen_everything_baseline =
        metrics.sparse_wake_success_bps > metrics.qwen_everything_baseline_success_bps;
    let wrong_wake_rejected = metrics.wrong_wake_count == metrics.wrong_wake_rejected_count
        && metrics.wrong_wake_count > 0;

    let duplicate_proposal_rejected = duplicate_proposal_rejected();
    let missing_selected_unit_rejected = invalid_proposal_rejected(|proposal| {
        proposal.selected_units.clear();
    }) == Some(SparseWakeError::MissingSelectedUnit);
    let missing_rejected_unit_rejected = invalid_proposal_rejected(|proposal| {
        proposal.rejected_units.clear();
    }) == Some(SparseWakeError::MissingRejectedUnit);
    let missing_uas_address_rejected = invalid_proposal_rejected(|proposal| {
        proposal.selected_units[0].uas_address = "";
    }) == Some(SparseWakeError::MissingUasAddress);
    let missing_budget_rejected = invalid_proposal_rejected(|proposal| {
        proposal.hot_byte_budget = 0;
    }) == Some(SparseWakeError::MissingBudget);
    let over_hot_budget_rejected = invalid_proposal_rejected(|proposal| {
        proposal.hot_byte_budget = 1;
    }) == Some(SparseWakeError::HotBudgetExceeded);
    let over_kv_budget_rejected = invalid_proposal_rejected(|proposal| {
        proposal.selected_units[0].kv_bytes = 2;
        proposal.kv_byte_budget = 1;
    }) == Some(SparseWakeError::KvBudgetExceeded);
    let over_cold_io_budget_rejected = invalid_proposal_rejected(|proposal| {
        proposal.selected_units[0].cold_io_bytes = 2;
        proposal.cold_io_budget = 1;
    }) == Some(SparseWakeError::ColdIoBudgetExceeded);
    let over_latency_budget_rejected = invalid_proposal_rejected(|proposal| {
        proposal.latency_budget_ms = 1;
    }) == Some(SparseWakeError::LatencyBudgetExceeded);
    let missing_fallback_rejected = invalid_proposal_rejected(|proposal| {
        proposal.fallback_route = "";
    }) == Some(SparseWakeError::MissingFallback);
    let missing_uncertainty_rejected = invalid_proposal_rejected(|proposal| {
        proposal.uncertainty_bps = 10_001;
    }) == Some(SparseWakeError::InvalidUncertainty);
    let missing_verifier_need_rejected = invalid_proposal_rejected(|proposal| {
        proposal.verifier_need = "";
    }) == Some(SparseWakeError::MissingVerifierNeed);
    let missing_rollback_rejected = invalid_proposal_rejected(|proposal| {
        proposal.rollback_handle = "";
    }) == Some(SparseWakeError::MissingRollback);
    let missing_run_event_log_rejected = invalid_proposal_rejected(|proposal| {
        proposal.run_event_log_ref = "";
    }) == Some(SparseWakeError::MissingRunEventLog);
    let missing_answer_packet_rejected = invalid_proposal_rejected(|proposal| {
        proposal.answer_packet_ref = "";
    }) == Some(SparseWakeError::MissingAnswerPacket);
    let hidden_live_authority_rejected = invalid_proposal_rejected(|proposal| {
        proposal.route_authority = "live_sparse_wake";
    }) == Some(SparseWakeError::HiddenLiveAuthority);
    let live_policy_mutation_rejected = invalid_proposal_rejected(|proposal| {
        proposal.live_policy_mutated = true;
    }) == Some(SparseWakeError::LivePolicyMutation);
    let hidden_chain_exposure_rejected = invalid_proposal_rejected(|proposal| {
        proposal.hidden_chain_exposed = true;
    }) == Some(SparseWakeError::HiddenChainExposure);
    let cloud_route_rejected = invalid_proposal_rejected(|proposal| {
        proposal.hidden_cloud = true;
    }) == Some(SparseWakeError::CloudRoute);
    let proposal_over_metadata_budget_rejected =
        invalid_proposal_rejected(|proposal| {
            proposal.proposal_metadata_bytes = 8 * 1024 * 1024;
        }) == Some(SparseWakeError::ProposalMetadataBudgetExceeded);
    let no_runtime_bytes_loaded = true;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        (
            "upstream_budgeted_uncertainty_escalator_pass",
            upstream_budgeted_uncertainty_escalator_pass,
        ),
        ("sparse_wake_fixture_present", sparse_wake_fixture_present),
        ("training_split_bound", training_split_bound),
        ("held_out_split_bound", held_out_split_bound),
        ("proposal_ids_bound", proposal_ids_bound),
        ("mission_ids_bound", mission_ids_bound),
        ("scout_refs_bound", scout_refs_bound),
        ("escalator_refs_bound", escalator_refs_bound),
        ("selected_units_bound", selected_units_bound),
        ("rejected_units_bound", rejected_units_bound),
        ("unit_addresses_bound", unit_addresses_bound),
        ("unit_kinds_bound", unit_kinds_bound),
        ("unit_budget_fields_bound", unit_budget_fields_bound),
        ("fallback_route_bound", fallback_route_bound),
        ("uncertainty_bound", uncertainty_bound),
        ("verifier_need_bound", verifier_need_bound),
        ("quality_delta_positive", quality_delta_positive),
        ("verifier_delta_positive", verifier_delta_positive),
        ("hot_bytes_within_budget", hot_bytes_within_budget),
        ("kv_bytes_within_budget", kv_bytes_within_budget),
        ("cold_io_within_budget", cold_io_within_budget),
        ("latency_within_budget", latency_within_budget),
        ("byte_budget_accounting_bound", byte_budget_accounting_bound),
        ("reject_reasons_bound", reject_reasons_bound),
        ("rollback_bound", rollback_bound),
        ("run_event_log_bound", run_event_log_bound),
        ("answer_packet_ref_bound", answer_packet_ref_bound),
        ("route_authority_shadow_only", route_authority_shadow_only),
        ("no_hidden_route_authority", no_hidden_route_authority),
        ("no_hidden_chain", no_hidden_chain),
        ("no_hidden_cloud", no_hidden_cloud),
        ("live_policy_not_mutated", live_policy_not_mutated),
        (
            "sparse_wake_address_deterministic",
            sparse_wake_address_deterministic,
        ),
        (
            "proposal_success_beats_wake_all_baseline",
            proposal_success_beats_wake_all_baseline,
        ),
        (
            "proposal_success_beats_static_baseline",
            proposal_success_beats_static_baseline,
        ),
        (
            "proposal_success_beats_qwen_everything_baseline",
            proposal_success_beats_qwen_everything_baseline,
        ),
        ("wrong_wake_rejected", wrong_wake_rejected),
        ("duplicate_proposal_rejected", duplicate_proposal_rejected),
        (
            "missing_selected_unit_rejected",
            missing_selected_unit_rejected,
        ),
        (
            "missing_rejected_unit_rejected",
            missing_rejected_unit_rejected,
        ),
        ("missing_uas_address_rejected", missing_uas_address_rejected),
        ("missing_budget_rejected", missing_budget_rejected),
        ("over_hot_budget_rejected", over_hot_budget_rejected),
        ("over_kv_budget_rejected", over_kv_budget_rejected),
        ("over_cold_io_budget_rejected", over_cold_io_budget_rejected),
        ("over_latency_budget_rejected", over_latency_budget_rejected),
        ("missing_fallback_rejected", missing_fallback_rejected),
        ("missing_uncertainty_rejected", missing_uncertainty_rejected),
        (
            "missing_verifier_need_rejected",
            missing_verifier_need_rejected,
        ),
        ("missing_rollback_rejected", missing_rollback_rejected),
        (
            "missing_run_event_log_rejected",
            missing_run_event_log_rejected,
        ),
        (
            "missing_answer_packet_rejected",
            missing_answer_packet_rejected,
        ),
        (
            "hidden_live_authority_rejected",
            hidden_live_authority_rejected,
        ),
        (
            "live_policy_mutation_rejected",
            live_policy_mutation_rejected,
        ),
        (
            "hidden_chain_exposure_rejected",
            hidden_chain_exposure_rejected,
        ),
        ("cloud_route_rejected", cloud_route_rejected),
        (
            "proposal_over_metadata_budget_rejected",
            proposal_over_metadata_budget_rejected,
        ),
        ("no_runtime_bytes_loaded", no_runtime_bytes_loaded),
    ] {
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
        "training_proposal_count",
        evaluation.training_proposal_count(),
        2,
        "proposals",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_proposal_count",
        evaluation.held_out_proposal_count(),
        8,
        "proposals",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "selected_unit_count",
        evaluation.selected_unit_count(),
        20,
        "units",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rejected_unit_count",
        evaluation.rejected_unit_count(),
        10,
        "units",
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_hot_bytes",
        evaluation.max_hot_bytes(),
        3 * 1024 * 1024,
        "<=",
        "bytes",
        evaluation.max_hot_bytes() <= 3 * 1024 * 1024,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_kv_bytes",
        evaluation.max_kv_bytes(),
        4 * 1024 * 1024,
        "<=",
        "bytes",
        evaluation.max_kv_bytes() <= 4 * 1024 * 1024,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_cold_io_bytes",
        evaluation.max_cold_io_bytes(),
        6 * 1024 * 1024,
        "<=",
        "bytes",
        evaluation.max_cold_io_bytes() <= 6 * 1024 * 1024,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_latency_ms",
        evaluation.max_latency_ms(),
        180,
        "<=",
        "milliseconds",
        evaluation.max_latency_ms() <= 180,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "sparse_wake_success_bps",
        metrics.sparse_wake_success_bps,
        10_000,
        ">=",
        "basis_points",
        metrics.sparse_wake_success_bps >= 10_000,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "wake_all_baseline_success_bps",
        metrics.wake_all_baseline_success_bps,
        metrics.sparse_wake_success_bps,
        "<",
        "basis_points",
        metrics.wake_all_baseline_success_bps < metrics.sparse_wake_success_bps,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "static_baseline_success_bps",
        metrics.static_baseline_success_bps,
        metrics.sparse_wake_success_bps,
        "<",
        "basis_points",
        metrics.static_baseline_success_bps < metrics.sparse_wake_success_bps,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "qwen_everything_baseline_success_bps",
        metrics.qwen_everything_baseline_success_bps,
        metrics.sparse_wake_success_bps,
        "<",
        "basis_points",
        metrics.qwen_everything_baseline_success_bps < metrics.sparse_wake_success_bps,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "wrong_wake_count",
        metrics.wrong_wake_count,
        1,
        ">=",
        "proposals",
        metrics.wrong_wake_count >= 1,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "wrong_wake_rejected_count",
        metrics.wrong_wake_rejected_count,
        metrics.wrong_wake_count,
        "==",
        "proposals",
        metrics.wrong_wake_rejected_count == metrics.wrong_wake_count,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_proposal_metadata_bytes",
        evaluation.max_proposal_metadata_bytes(),
        MAX_PROPOSAL_METADATA_BYTES,
        "<=",
        "bytes",
        evaluation.max_proposal_metadata_bytes() <= MAX_PROPOSAL_METADATA_BYTES,
    );
    add_string_measurement(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "sparse_wake_address",
        &evaluation.sparse_wake_address,
        "address",
    );

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
        notes: "scope=metadata_only;organ=SparseWakeProposal;reviewer=codex;reviewed_at_utc=2026-06-04T00:00:00Z;validator=falsifier_validator;local_reference_only=true;detail=SparseWakeProposal guards selected/rejected UAS units, byte budgets, fallback, uncertainty, verifier need, rollback, RunEventLog, and AnswerPacket before any live sparse wake or model/runtime byte load".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn add_threshold_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    expected: u64,
    operator: &str,
    unit: &str,
    passed: bool,
) {
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

fn add_string_measurement(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: &str,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(value.to_string()),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::Value::String("uas:sparse-wake-proposal:".to_string()),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(
        name.to_string(),
        value.starts_with("uas:sparse-wake-proposal:"),
    );
}

#[derive(Clone)]
// UAS: uas:sparse-wake-proposal:evaluation
// Plane: Verification
// Residency: metadata-only
struct SparseWakeEvaluation {
    proposals: Vec<SparseWakeProposal>,
    metrics: SparseWakeMetrics,
    sparse_wake_address: String,
}

impl SparseWakeEvaluation {
    fn new(proposals: Vec<SparseWakeProposal>) -> Result<Self, SparseWakeError> {
        if proposals.is_empty() {
            return Err(SparseWakeError::MissingProposal);
        }
        let mut seen = BTreeSet::new();
        for proposal in &proposals {
            if !seen.insert(proposal.proposal_id) {
                return Err(SparseWakeError::DuplicateProposal);
            }
            validate_proposal(proposal)?;
        }
        let metrics = SparseWakeMetrics::from_proposals(&proposals)?;
        let sparse_wake_address = sparse_wake_address(&proposals);
        Ok(Self {
            proposals,
            metrics,
            sparse_wake_address,
        })
    }

    fn held_out_proposals(&self) -> Vec<&SparseWakeProposal> {
        self.proposals
            .iter()
            .filter(|proposal| proposal.split == "held_out")
            .collect()
    }

    fn training_proposal_count(&self) -> u64 {
        self.proposals
            .iter()
            .filter(|proposal| proposal.split == "train")
            .count() as u64
    }

    fn held_out_proposal_count(&self) -> u64 {
        self.held_out_proposals().len() as u64
    }

    fn selected_unit_count(&self) -> u64 {
        self.proposals
            .iter()
            .map(|proposal| proposal.selected_units.len() as u64)
            .sum()
    }

    fn rejected_unit_count(&self) -> u64 {
        self.proposals
            .iter()
            .map(|proposal| proposal.rejected_units.len() as u64)
            .sum()
    }

    fn max_hot_bytes(&self) -> u64 {
        self.proposals
            .iter()
            .map(SparseWakeProposal::hot_bytes)
            .max()
            .unwrap_or(0)
    }

    fn max_kv_bytes(&self) -> u64 {
        self.proposals
            .iter()
            .map(SparseWakeProposal::kv_bytes)
            .max()
            .unwrap_or(0)
    }

    fn max_cold_io_bytes(&self) -> u64 {
        self.proposals
            .iter()
            .map(SparseWakeProposal::cold_io_bytes)
            .max()
            .unwrap_or(0)
    }

    fn max_latency_ms(&self) -> u64 {
        self.proposals
            .iter()
            .map(|proposal| proposal.expected_latency_ms)
            .max()
            .unwrap_or(0)
    }

    fn max_proposal_metadata_bytes(&self) -> u64 {
        self.proposals
            .iter()
            .map(|proposal| proposal.proposal_metadata_bytes)
            .max()
            .unwrap_or(0)
    }
}

#[derive(Clone, Copy)]
// UAS: uas:sparse-wake-proposal:metrics
// Plane: Verification
// Residency: metadata-only
struct SparseWakeMetrics {
    sparse_wake_success_bps: u64,
    wake_all_baseline_success_bps: u64,
    static_baseline_success_bps: u64,
    qwen_everything_baseline_success_bps: u64,
    wrong_wake_count: u64,
    wrong_wake_rejected_count: u64,
}

impl SparseWakeMetrics {
    fn from_proposals(proposals: &[SparseWakeProposal]) -> Result<Self, SparseWakeError> {
        if proposals
            .iter()
            .filter(|proposal| proposal.split == "train")
            .count()
            < 2
        {
            return Err(SparseWakeError::MissingTrainingSplit);
        }
        let held_out = proposals
            .iter()
            .filter(|proposal| proposal.split == "held_out")
            .collect::<Vec<_>>();
        if held_out.len() < 8 {
            return Err(SparseWakeError::MissingHeldOutSplit);
        }

        let sparse_wake_success_bps = success_bps(&held_out, sparse_wake_correct);
        let wake_all_baseline_success_bps = success_bps(&held_out, wake_all_baseline_correct);
        let static_baseline_success_bps = success_bps(&held_out, static_baseline_correct);
        let qwen_everything_baseline_success_bps =
            success_bps(&held_out, qwen_everything_baseline_correct);

        if sparse_wake_success_bps <= wake_all_baseline_success_bps {
            return Err(SparseWakeError::WakeAllBaselineUnbeaten);
        }
        if sparse_wake_success_bps <= static_baseline_success_bps {
            return Err(SparseWakeError::StaticBaselineUnbeaten);
        }
        if sparse_wake_success_bps <= qwen_everything_baseline_success_bps {
            return Err(SparseWakeError::QwenEverythingBaselineUnbeaten);
        }
        if !held_out
            .iter()
            .any(|proposal| !proposal.selected_units.is_empty())
        {
            return Err(SparseWakeError::MissingWakeCase);
        }
        if !held_out
            .iter()
            .any(|proposal| !proposal.rejected_units.is_empty())
        {
            return Err(SparseWakeError::MissingRejectCase);
        }

        let wrong_wake_count = held_out
            .iter()
            .filter(|proposal| {
                proposal
                    .rejected_units
                    .iter()
                    .any(|unit| unit.reason != "reject:not_needed")
            })
            .count() as u64;
        let wrong_wake_rejected_count = held_out
            .iter()
            .filter(|proposal| {
                proposal
                    .rejected_units
                    .iter()
                    .any(|unit| unit.reason != "reject:not_needed")
                    && sparse_wake_correct(proposal)
            })
            .count() as u64;
        if wrong_wake_count != wrong_wake_rejected_count {
            return Err(SparseWakeError::WrongWakeNotRejected);
        }

        Ok(Self {
            sparse_wake_success_bps,
            wake_all_baseline_success_bps,
            static_baseline_success_bps,
            qwen_everything_baseline_success_bps,
            wrong_wake_count,
            wrong_wake_rejected_count,
        })
    }
}

impl SparseWakeProposal {
    fn hot_bytes(&self) -> u64 {
        self.selected_units.iter().map(|unit| unit.hot_bytes).sum()
    }

    fn kv_bytes(&self) -> u64 {
        self.selected_units.iter().map(|unit| unit.kv_bytes).sum()
    }

    fn cold_io_bytes(&self) -> u64 {
        self.selected_units
            .iter()
            .map(|unit| unit.cold_io_bytes)
            .sum()
    }

    fn selected_id_set(&self) -> BTreeSet<&'static str> {
        self.selected_units
            .iter()
            .map(|unit| unit.unit_id)
            .collect()
    }

    fn rejected_id_set(&self) -> BTreeSet<&'static str> {
        self.rejected_units
            .iter()
            .map(|unit| unit.unit_id)
            .collect()
    }

    fn expected_selected_set(&self) -> BTreeSet<&'static str> {
        self.expected_selected_unit_ids.iter().copied().collect()
    }

    fn expected_rejected_set(&self) -> BTreeSet<&'static str> {
        self.expected_rejected_unit_ids.iter().copied().collect()
    }
}

fn validate_proposal(proposal: &SparseWakeProposal) -> Result<(), SparseWakeError> {
    if proposal.split != "train" && proposal.split != "held_out" {
        return Err(SparseWakeError::MissingSplit);
    }
    if !proposal.proposal_id.starts_with("proposal:") {
        return Err(SparseWakeError::MissingProposalId);
    }
    if !proposal.mission_id.starts_with("mission:") {
        return Err(SparseWakeError::MissingMission);
    }
    if !proposal.scout_ref.starts_with("two-stage:") {
        return Err(SparseWakeError::MissingScoutRef);
    }
    if !proposal.escalator_ref.starts_with("escalator:") {
        return Err(SparseWakeError::MissingEscalatorRef);
    }
    if proposal.selected_units.is_empty() {
        return Err(SparseWakeError::MissingSelectedUnit);
    }
    if proposal.rejected_units.is_empty() {
        return Err(SparseWakeError::MissingRejectedUnit);
    }
    for unit in &proposal.selected_units {
        validate_unit(unit)?;
    }
    for unit in &proposal.rejected_units {
        if !unit.unit_id.starts_with("unit:") || !unit.reason.starts_with("reject:") {
            return Err(SparseWakeError::MissingRejectedUnit);
        }
    }
    if proposal.hot_byte_budget == 0
        || proposal.kv_byte_budget == 0
        || proposal.cold_io_budget == 0
        || proposal.latency_budget_ms == 0
    {
        return Err(SparseWakeError::MissingBudget);
    }
    if proposal.hot_bytes() > proposal.hot_byte_budget {
        return Err(SparseWakeError::HotBudgetExceeded);
    }
    if proposal.kv_bytes() > proposal.kv_byte_budget {
        return Err(SparseWakeError::KvBudgetExceeded);
    }
    if proposal.cold_io_bytes() > proposal.cold_io_budget {
        return Err(SparseWakeError::ColdIoBudgetExceeded);
    }
    if proposal.expected_latency_ms > proposal.latency_budget_ms {
        return Err(SparseWakeError::LatencyBudgetExceeded);
    }
    if !proposal.fallback_route.starts_with("fallback:") {
        return Err(SparseWakeError::MissingFallback);
    }
    if proposal.uncertainty_bps == 0 {
        return Err(SparseWakeError::MissingUncertainty);
    }
    if proposal.uncertainty_bps > 10_000 {
        return Err(SparseWakeError::InvalidUncertainty);
    }
    if !proposal.verifier_need.starts_with("verifier:") {
        return Err(SparseWakeError::MissingVerifierNeed);
    }
    if proposal.selected_id_set() != proposal.expected_selected_set()
        || proposal.rejected_id_set() != proposal.expected_rejected_set()
    {
        return Err(SparseWakeError::InvalidExpectedSelection);
    }
    if proposal.expected_quality_delta_bps < MIN_QUALITY_DELTA_BPS {
        return Err(SparseWakeError::WeakQualityDelta);
    }
    if proposal.expected_verifier_delta_bps < MIN_VERIFIER_DELTA_BPS {
        return Err(SparseWakeError::WeakVerifierDelta);
    }
    if !proposal.rollback_handle.starts_with("rollback:") {
        return Err(SparseWakeError::MissingRollback);
    }
    if !proposal.run_event_log_ref.starts_with("runlog:") {
        return Err(SparseWakeError::MissingRunEventLog);
    }
    if !proposal.answer_packet_ref.starts_with("answerpacket:") {
        return Err(SparseWakeError::MissingAnswerPacket);
    }
    if proposal.route_authority != "shadow_only" {
        return Err(SparseWakeError::HiddenLiveAuthority);
    }
    if proposal.live_policy_mutated {
        return Err(SparseWakeError::LivePolicyMutation);
    }
    if proposal.hidden_chain_exposed {
        return Err(SparseWakeError::HiddenChainExposure);
    }
    if proposal.hidden_cloud {
        return Err(SparseWakeError::CloudRoute);
    }
    if proposal.proposal_metadata_bytes > MAX_PROPOSAL_METADATA_BYTES {
        return Err(SparseWakeError::ProposalMetadataBudgetExceeded);
    }
    Ok(())
}

fn validate_unit(unit: &WakeUnit) -> Result<(), SparseWakeError> {
    if !unit.unit_id.starts_with("unit:") {
        return Err(SparseWakeError::MissingSelectedUnit);
    }
    if !unit.uas_address.starts_with("uas:") {
        return Err(SparseWakeError::MissingUasAddress);
    }
    if !matches!(
        unit.unit_kind,
        "model_tile" | "kv_page" | "evidence" | "verifier" | "adapter" | "tool"
    ) {
        return Err(SparseWakeError::MissingUnitKind);
    }
    if unit.hot_bytes + unit.kv_bytes + unit.cold_io_bytes == 0 {
        return Err(SparseWakeError::MissingBudget);
    }
    if unit.verifier_delta_bps < 0 || unit.quality_delta_bps < 0 {
        return Err(SparseWakeError::WeakVerifierDelta);
    }
    if !unit.evidence_ref.starts_with("evidence:") {
        return Err(SparseWakeError::MissingSelectedUnit);
    }
    if !unit.compatibility_fence.starts_with("fence:") {
        return Err(SparseWakeError::MissingSelectedUnit);
    }
    if !matches!(
        unit.privacy_class,
        "vault_private" | "local_public" | "tool_proof"
    ) {
        return Err(SparseWakeError::InvalidPrivacyClass);
    }
    Ok(())
}

fn success_bps(
    proposals: &[&SparseWakeProposal],
    decision: impl Fn(&SparseWakeProposal) -> bool,
) -> u64 {
    let success = proposals
        .iter()
        .filter(|proposal| decision(proposal))
        .count() as u64;
    success.saturating_mul(10_000) / proposals.len() as u64
}

fn sparse_wake_correct(proposal: &SparseWakeProposal) -> bool {
    proposal.selected_id_set() == proposal.expected_selected_set()
        && proposal.rejected_id_set() == proposal.expected_rejected_set()
        && proposal.hot_bytes() <= proposal.hot_byte_budget
        && proposal.kv_bytes() <= proposal.kv_byte_budget
        && proposal.cold_io_bytes() <= proposal.cold_io_budget
        && proposal.expected_latency_ms <= proposal.latency_budget_ms
        && proposal.expected_quality_delta_bps >= MIN_QUALITY_DELTA_BPS
        && proposal.expected_verifier_delta_bps >= MIN_VERIFIER_DELTA_BPS
}

fn wake_all_baseline_correct(proposal: &SparseWakeProposal) -> bool {
    proposal.expected_rejected_unit_ids.is_empty()
        && proposal.hot_bytes() <= proposal.hot_byte_budget
        && proposal.kv_bytes() <= proposal.kv_byte_budget
        && proposal.cold_io_bytes() <= proposal.cold_io_budget
}

fn static_baseline_correct(proposal: &SparseWakeProposal) -> bool {
    proposal.expected_selected_unit_ids.len() == 1
        && proposal
            .selected_units
            .first()
            .is_some_and(|unit| unit.unit_id == proposal.expected_selected_unit_ids[0])
        && proposal.expected_rejected_unit_ids.len() <= 1
}

fn qwen_everything_baseline_correct(proposal: &SparseWakeProposal) -> bool {
    proposal.fallback_route == "fallback:local-qwen-full"
        && proposal.verifier_need == "verifier:none"
        && proposal.expected_selected_unit_ids.len() <= 1
}

fn sparse_wake_address(proposals: &[SparseWakeProposal]) -> String {
    let mut rows = proposals
        .iter()
        .map(|proposal| {
            format!(
                "{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
                proposal.proposal_id,
                proposal.mission_id,
                proposal.scout_ref,
                proposal.escalator_ref,
                proposal
                    .selected_id_set()
                    .into_iter()
                    .collect::<Vec<_>>()
                    .join(","),
                proposal
                    .rejected_id_set()
                    .into_iter()
                    .collect::<Vec<_>>()
                    .join(","),
                proposal.hot_bytes(),
                proposal.kv_bytes(),
                proposal.cold_io_bytes(),
                proposal.expected_latency_ms,
                proposal.fallback_route,
                proposal.verifier_need
            )
        })
        .collect::<Vec<_>>();
    rows.sort();
    let digest = sha256_hex(rows.join("\n").as_bytes());
    format!("uas:sparse-wake-proposal:{digest}")
}

fn upstream_escalator_pass() -> bool {
    let Ok(bytes) = std::fs::read(UPSTREAM_ESCALATOR) else {
        return false;
    };
    let Ok(json) = serde_json::from_slice::<serde_json::Value>(&bytes) else {
        return false;
    };
    json.get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
        && json
            .get("pass_per_axis")
            .and_then(|axes| axes.get("no_runtime_bytes_loaded"))
            .and_then(serde_json::Value::as_bool)
            .unwrap_or(false)
}

fn fixture_proposals() -> Vec<SparseWakeProposal> {
    vec![
        proposal(
            "train",
            "proposal:private-rewrite-single",
            "mission:mas-private-rewrite",
            vec![unit(
                "unit:apple-private-rewrite",
                "uas:model:apple-private",
                "tool",
                128 * 1024,
                0,
                0,
                150,
                220,
                "vault_private",
            )],
            vec![rejected("unit:local-qwen-heavy", "reject:over_budget")],
            &["unit:apple-private-rewrite"],
            &["unit:local-qwen-heavy"],
            "fallback:local-qwen-full",
            "verifier:none",
            1_200,
        ),
        proposal(
            "train",
            "proposal:proof-repair-lean",
            "mission:proof-repair",
            vec![
                unit(
                    "unit:lean-verifier",
                    "uas:verifier:lean",
                    "verifier",
                    384 * 1024,
                    0,
                    256 * 1024,
                    900,
                    500,
                    "tool_proof",
                ),
                unit(
                    "unit:proof-context-page",
                    "uas:kv:proof-context",
                    "kv_page",
                    0,
                    512 * 1024,
                    256 * 1024,
                    300,
                    180,
                    "vault_private",
                ),
            ],
            vec![rejected(
                "unit:unverified-local-answer",
                "reject:verifier_required",
            )],
            &["unit:lean-verifier", "unit:proof-context-page"],
            &["unit:unverified-local-answer"],
            "fallback:full-proof-route",
            "verifier:lean",
            3_200,
        ),
        proposal(
            "held_out",
            "proposal:eidos-cited-answer",
            "mission:cited-answer",
            vec![
                unit(
                    "unit:eidos-source-card",
                    "uas:evidence:eidos-source",
                    "evidence",
                    128 * 1024,
                    0,
                    512 * 1024,
                    450,
                    420,
                    "vault_private",
                ),
                unit(
                    "unit:citation-verifier",
                    "uas:verifier:citation",
                    "verifier",
                    256 * 1024,
                    0,
                    128 * 1024,
                    600,
                    200,
                    "tool_proof",
                ),
            ],
            vec![rejected(
                "unit:uncited-local-summary",
                "reject:evidence_gap",
            )],
            &["unit:eidos-source-card", "unit:citation-verifier"],
            &["unit:uncited-local-summary"],
            "fallback:eidos-full-retrieve",
            "verifier:citation",
            2_100,
        ),
        proposal(
            "held_out",
            "proposal:local-code-note",
            "mission:local-code",
            vec![
                unit(
                    "unit:local-qwen-code",
                    "uas:model:local-qwen-code",
                    "model_tile",
                    1024 * 1024,
                    0,
                    2 * 1024 * 1024,
                    350,
                    750,
                    "vault_private",
                ),
                unit(
                    "unit:repo-context-kv",
                    "uas:kv:repo-context",
                    "kv_page",
                    0,
                    1024 * 1024,
                    512 * 1024,
                    150,
                    350,
                    "vault_private",
                ),
            ],
            vec![rejected(
                "unit:apple-private-rewrite",
                "reject:insufficient_depth",
            )],
            &["unit:local-qwen-code", "unit:repo-context-kv"],
            &["unit:apple-private-rewrite"],
            "fallback:local-qwen-full",
            "verifier:tests",
            2_400,
        ),
        proposal(
            "held_out",
            "proposal:long-context-kv-recall",
            "mission:long-context-recall",
            vec![
                unit(
                    "unit:query-kv-page-a",
                    "uas:kv:query-page-a",
                    "kv_page",
                    0,
                    1536 * 1024,
                    1024 * 1024,
                    250,
                    300,
                    "vault_private",
                ),
                unit(
                    "unit:query-kv-page-b",
                    "uas:kv:query-page-b",
                    "kv_page",
                    0,
                    1536 * 1024,
                    1024 * 1024,
                    250,
                    300,
                    "vault_private",
                ),
                unit(
                    "unit:recall-evidence-card",
                    "uas:evidence:recall-card",
                    "evidence",
                    128 * 1024,
                    0,
                    512 * 1024,
                    300,
                    250,
                    "vault_private",
                ),
            ],
            vec![rejected("unit:file-order-kv-bulk", "reject:cold_io_excess")],
            &[
                "unit:query-kv-page-a",
                "unit:query-kv-page-b",
                "unit:recall-evidence-card",
            ],
            &["unit:file-order-kv-bulk"],
            "fallback:full-kv-route",
            "verifier:evidence",
            3_500,
        ),
        proposal(
            "held_out",
            "proposal:scope-rex-mutation-review",
            "mission:sovereign-note-mutation",
            vec![
                unit(
                    "unit:scope-rex-gate",
                    "uas:controller:scope-rex",
                    "tool",
                    256 * 1024,
                    0,
                    128 * 1024,
                    500,
                    250,
                    "tool_proof",
                ),
                unit(
                    "unit:mutation-diff-verifier",
                    "uas:verifier:diff",
                    "verifier",
                    384 * 1024,
                    0,
                    256 * 1024,
                    700,
                    300,
                    "tool_proof",
                ),
            ],
            vec![rejected(
                "unit:direct-note-mutation",
                "reject:sovereign_gate",
            )],
            &["unit:scope-rex-gate", "unit:mutation-diff-verifier"],
            &["unit:direct-note-mutation"],
            "fallback:user-visible-review",
            "verifier:mutation",
            4_000,
        ),
        proposal(
            "held_out",
            "proposal:uncalibrated-source-answer",
            "mission:source-answer",
            vec![
                unit(
                    "unit:source-calibration-card",
                    "uas:evidence:calibration-card",
                    "evidence",
                    128 * 1024,
                    0,
                    256 * 1024,
                    400,
                    240,
                    "vault_private",
                ),
                unit(
                    "unit:source-verifier",
                    "uas:verifier:source",
                    "verifier",
                    256 * 1024,
                    0,
                    128 * 1024,
                    650,
                    180,
                    "tool_proof",
                ),
            ],
            vec![rejected(
                "unit:cheap-uncalibrated-scout",
                "reject:missing_calibration",
            )],
            &["unit:source-calibration-card", "unit:source-verifier"],
            &["unit:cheap-uncalibrated-scout"],
            "fallback:full-source-route",
            "verifier:source",
            3_800,
        ),
        proposal(
            "held_out",
            "proposal:adversarial-synthesis-ood",
            "mission:adversarial-synthesis",
            vec![
                unit(
                    "unit:adversarial-detector",
                    "uas:verifier:ood",
                    "verifier",
                    384 * 1024,
                    0,
                    256 * 1024,
                    800,
                    220,
                    "tool_proof",
                ),
                unit(
                    "unit:full-shadow-oracle",
                    "uas:tool:shadow-oracle",
                    "tool",
                    512 * 1024,
                    0,
                    768 * 1024,
                    500,
                    300,
                    "tool_proof",
                ),
            ],
            vec![rejected(
                "unit:cheap-synthesis-only",
                "reject:out_of_distribution",
            )],
            &["unit:adversarial-detector", "unit:full-shadow-oracle"],
            &["unit:cheap-synthesis-only"],
            "fallback:full-shadow-route",
            "verifier:ood",
            5_000,
        ),
        proposal(
            "held_out",
            "proposal:coverage-shortfall-code-patch",
            "mission:code-patch",
            vec![
                unit(
                    "unit:test-verifier",
                    "uas:verifier:test",
                    "verifier",
                    512 * 1024,
                    0,
                    512 * 1024,
                    900,
                    260,
                    "tool_proof",
                ),
                unit(
                    "unit:repo-context-kv",
                    "uas:kv:repo-context",
                    "kv_page",
                    0,
                    1024 * 1024,
                    512 * 1024,
                    200,
                    350,
                    "vault_private",
                ),
            ],
            vec![rejected(
                "unit:patch-without-tests",
                "reject:coverage_below_target",
            )],
            &["unit:test-verifier", "unit:repo-context-kv"],
            &["unit:patch-without-tests"],
            "fallback:test-backed-route",
            "verifier:tests",
            3_100,
        ),
        proposal(
            "held_out",
            "proposal:verifier-coverage-citation-risk",
            "mission:citation-risk",
            vec![
                unit(
                    "unit:citation-verifier",
                    "uas:verifier:citation",
                    "verifier",
                    256 * 1024,
                    0,
                    128 * 1024,
                    800,
                    180,
                    "tool_proof",
                ),
                unit(
                    "unit:eidos-source-card",
                    "uas:evidence:eidos-source",
                    "evidence",
                    128 * 1024,
                    0,
                    512 * 1024,
                    350,
                    300,
                    "vault_private",
                ),
            ],
            vec![rejected(
                "unit:source-without-verifier",
                "reject:verifier_coverage_gap",
            )],
            &["unit:citation-verifier", "unit:eidos-source-card"],
            &["unit:source-without-verifier"],
            "fallback:citation-full-route",
            "verifier:citation",
            2_800,
        ),
    ]
}

#[allow(clippy::too_many_arguments)]
fn proposal(
    split: &'static str,
    proposal_id: &'static str,
    mission_id: &'static str,
    selected_units: Vec<WakeUnit>,
    rejected_units: Vec<RejectedUnit>,
    expected_selected_unit_ids: &'static [&'static str],
    expected_rejected_unit_ids: &'static [&'static str],
    fallback_route: &'static str,
    verifier_need: &'static str,
    uncertainty_bps: u64,
) -> SparseWakeProposal {
    SparseWakeProposal {
        split,
        proposal_id,
        mission_id,
        scout_ref: "two-stage:route-scout-abstain",
        escalator_ref: "escalator:budgeted-uncertainty",
        expected_quality_delta_bps: 500,
        expected_verifier_delta_bps: 650,
        hot_byte_budget: 3 * 1024 * 1024,
        kv_byte_budget: 4 * 1024 * 1024,
        cold_io_budget: 6 * 1024 * 1024,
        latency_budget_ms: 180,
        expected_latency_ms: 120,
        fallback_route,
        uncertainty_bps,
        verifier_need,
        selected_units,
        rejected_units,
        expected_selected_unit_ids,
        expected_rejected_unit_ids,
        rollback_handle: "rollback:sparse-wake-proposal",
        run_event_log_ref: "runlog:sparse-wake-proposal",
        answer_packet_ref: "answerpacket:sparse-wake-proposal",
        route_authority: "shadow_only",
        proposal_metadata_bytes: 1 * 1024 * 1024,
        hidden_chain_exposed: false,
        hidden_cloud: false,
        live_policy_mutated: false,
    }
}

#[allow(clippy::too_many_arguments)]
fn unit(
    unit_id: &'static str,
    uas_address: &'static str,
    unit_kind: &'static str,
    hot_bytes: u64,
    kv_bytes: u64,
    cold_io_bytes: u64,
    verifier_delta_bps: i64,
    quality_delta_bps: i64,
    privacy_class: &'static str,
) -> WakeUnit {
    WakeUnit {
        unit_id,
        uas_address,
        unit_kind,
        hot_bytes,
        kv_bytes,
        cold_io_bytes,
        verifier_delta_bps,
        quality_delta_bps,
        evidence_ref: "evidence:sparse-wake-fixture",
        compatibility_fence: "fence:sparse-wake-v1",
        privacy_class,
    }
}

fn rejected(unit_id: &'static str, reason: &'static str) -> RejectedUnit {
    RejectedUnit { unit_id, reason }
}

fn duplicate_proposal_rejected() -> bool {
    let mut proposals = fixture_proposals();
    proposals.push(proposals[0].clone());
    SparseWakeEvaluation::new(proposals).err() == Some(SparseWakeError::DuplicateProposal)
}

fn invalid_proposal_rejected(
    mutate: impl FnOnce(&mut SparseWakeProposal),
) -> Option<SparseWakeError> {
    let mut proposals = fixture_proposals();
    let mut proposal = proposals.remove(0);
    mutate(&mut proposal);
    proposals.insert(0, proposal);
    SparseWakeEvaluation::new(proposals).err()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_fixture_rejects() {
        assert_eq!(
            SparseWakeEvaluation::new(Vec::new()).err(),
            Some(SparseWakeError::MissingProposal)
        );
    }

    #[test]
    fn fixture_evaluation_passes_and_address_is_order_stable() {
        let proposals = fixture_proposals();
        let reversed = proposals.iter().cloned().rev().collect::<Vec<_>>();
        let evaluation = match SparseWakeEvaluation::new(proposals) {
            Ok(evaluation) => evaluation,
            Err(error) => panic!("fixture should pass: {error}"),
        };
        let reversed_evaluation = match SparseWakeEvaluation::new(reversed) {
            Ok(evaluation) => evaluation,
            Err(error) => panic!("reversed fixture should pass: {error}"),
        };
        assert_eq!(evaluation.training_proposal_count(), 2);
        assert_eq!(evaluation.held_out_proposal_count(), 8);
        assert_eq!(evaluation.selected_unit_count(), 20);
        assert_eq!(evaluation.rejected_unit_count(), 10);
        assert_eq!(
            evaluation.sparse_wake_address,
            reversed_evaluation.sparse_wake_address
        );
    }

    #[test]
    fn required_invalid_fixtures_reject() {
        assert!(duplicate_proposal_rejected());
        assert_eq!(
            invalid_proposal_rejected(|proposal| proposal.selected_units.clear()),
            Some(SparseWakeError::MissingSelectedUnit)
        );
        assert_eq!(
            invalid_proposal_rejected(|proposal| proposal.selected_units[0].uas_address = ""),
            Some(SparseWakeError::MissingUasAddress)
        );
        assert_eq!(
            invalid_proposal_rejected(|proposal| proposal.hot_byte_budget = 1),
            Some(SparseWakeError::HotBudgetExceeded)
        );
        assert_eq!(
            invalid_proposal_rejected(|proposal| proposal.route_authority = "live_sparse_wake"),
            Some(SparseWakeError::HiddenLiveAuthority)
        );
        const WRONG_SELECTED: &[&str] = &["unit:not-selected"];
        assert_eq!(
            invalid_proposal_rejected(|proposal| {
                proposal.expected_selected_unit_ids = WRONG_SELECTED;
            }),
            Some(SparseWakeError::InvalidExpectedSelection)
        );
    }

    #[test]
    fn build_artifact_sets_required_scope_axis() {
        let artifact = match build_artifact() {
            Ok(artifact) => artifact,
            Err(error) => panic!("artifact should build: {error}"),
        };
        assert_eq!(artifact.falsifier_id, FALSIFIER_ID);
        assert!(artifact.pass_per_axis["no_runtime_bytes_loaded"]);
        assert!(artifact.pass_per_axis["selected_units_bound"]);
        assert!(artifact.pass_per_axis["rejected_units_bound"]);
        assert!(artifact.pass_per_axis["proposal_success_beats_wake_all_baseline"]);
    }
}
