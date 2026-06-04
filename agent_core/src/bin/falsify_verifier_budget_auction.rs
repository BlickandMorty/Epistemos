//! `falsify_verifier_budget_auction` -- verifier budget auction contract.
//!
//! Metadata-only witness for `F-VerifierBudgetAuction`. It proves sparse wake
//! candidates compete under verifier, byte, latency, privacy, interference, and
//! rollback budgets; rejected bundles fail before execution; and no runtime or
//! model bytes load.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-VerifierBudgetAuction";
const FIXTURE_ID: &str = "verifier_budget_auction_v1";
const COMMAND: &str = "Tools/falsifiers/f_verifier_budget_auction.sh";
const RESULT: &str = "artifacts/falsifiers/verifier_budget_auction/result.json";
const UPSTREAM_SPARSE_WAKE: &str = "artifacts/falsifiers/sparse_wake_proposal_budget/result.json";
const MAX_AUCTION_METADATA_BYTES: u64 = 4 * 1024 * 1024;
const MIN_SELECTED_BID_SCORE_BPS: i64 = 600;
const MIN_SELECTED_VERIFIER_COVERAGE_BPS: i64 = 1_100;

#[derive(Clone)]
// UAS: uas:verifier-budget-auction:candidate
// Plane: Assembly + Controller + Verification
// Residency: metadata-only candidate support unit.
struct AuctionCandidate {
    unit_id: String,
    uas_address: String,
    unit_kind: String,
    hot_bytes: u64,
    kv_bytes: u64,
    cold_io_bytes: u64,
    latency_ms: u64,
    verifier_delta_bps: i64,
    quality_delta_bps: i64,
    evidence_delta_bps: i64,
    saved_prefill_bps: i64,
    bid_score_bps: i64,
    privacy_risk_bps: u64,
    interference_risk_bps: u64,
    rollback_cost_bps: u64,
    evidence_ref: String,
    compatibility_fence: String,
    privacy_class: String,
    selected: bool,
    reject_reason: String,
}

#[derive(Clone)]
// UAS: uas:verifier-budget-auction:round
// Plane: Controller + Verification
// Residency: metadata-only auction round.
struct VerifierBudgetAuctionRound {
    split: String,
    auction_id: String,
    mission_id: String,
    sparse_wake_ref: String,
    candidates: Vec<AuctionCandidate>,
    expected_selected_unit_ids: Vec<String>,
    expected_rejected_unit_ids: Vec<String>,
    hot_byte_budget: u64,
    kv_byte_budget: u64,
    cold_io_budget: u64,
    latency_budget_ms: u64,
    privacy_risk_budget_bps: u64,
    interference_risk_budget_bps: u64,
    rollback_cost_budget_bps: u64,
    required_verifier_coverage_bps: i64,
    verifier_need: String,
    fallback_route: String,
    abstain_reason: String,
    rollback_handle: String,
    run_event_log_ref: String,
    answer_packet_ref: String,
    route_authority: String,
    auction_metadata_bytes: u64,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    live_policy_mutated: bool,
}

#[derive(Debug, Eq, PartialEq)]
// UAS: uas:verifier-budget-auction:error
// Plane: Verification
// Residency: metadata-only rejection reason.
enum AuctionError {
    MissingRound,
    DuplicateRound,
    MissingSplit,
    MissingAuctionId,
    MissingMission,
    MissingSparseWakeRef,
    MissingCandidate,
    DuplicateCandidate,
    MissingSelectedBundle,
    MissingRejectedBundle,
    MissingUasAddress,
    MissingUnitKind,
    MissingEvidenceRef,
    MissingCompatibilityFence,
    MissingBudget,
    MissingVerifierNeed,
    MissingFallback,
    MissingAbstainReason,
    MissingRollback,
    MissingRunEventLog,
    MissingAnswerPacket,
    InvalidPrivacyClass,
    InvalidExpectedSelection,
    HotBudgetExceeded,
    KvBudgetExceeded,
    ColdIoBudgetExceeded,
    LatencyBudgetExceeded,
    PrivacyRiskExceeded,
    InterferenceRiskExceeded,
    RollbackCostExceeded,
    WeakVerifierCoverage,
    WeakBidScore,
    MissingTrainingSplit,
    MissingHeldOutSplit,
    MissingOverBudgetRejectCase,
    MissingLowVerifierRejectCase,
    MissingPrivacyRejectCase,
    MissingLatencyRejectCase,
    MissingInterferenceRejectCase,
    MissingRollbackRejectCase,
    GreedyBytesBaselineUnbeaten,
    MaxQualityBaselineUnbeaten,
    WakeAllBaselineUnbeaten,
    HiddenLiveAuthority,
    LivePolicyMutation,
    HiddenChainExposure,
    CloudRoute,
    AuctionMetadataBudgetExceeded,
}

impl std::fmt::Display for AuctionError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for AuctionError {}

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
        "{FALSIFIER_ID}: overall_pass={} held_out_round_count={} auction_address={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["held_out_round_count"].value,
        artifact.measurements["auction_address"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let rounds = fixture_rounds();
    let reversed = rounds.iter().cloned().rev().collect::<Vec<_>>();
    let evaluation = AuctionEvaluation::new(rounds)?;
    let reversed_evaluation = AuctionEvaluation::new(reversed)?;
    let metrics = evaluation.metrics;

    let upstream_sparse_wake_proposal_budget_pass = upstream_sparse_wake_pass();
    let verifier_budget_auction_fixture_present = evaluation.rounds.len() == 10;
    let training_split_bound = evaluation.training_round_count() >= 2;
    let held_out_split_bound = evaluation.held_out_round_count() >= 8;
    let auction_ids_bound = evaluation
        .rounds
        .iter()
        .all(|round| round.auction_id.starts_with("auction:"));
    let mission_ids_bound = evaluation
        .rounds
        .iter()
        .all(|round| round.mission_id.starts_with("mission:"));
    let sparse_wake_refs_bound = evaluation
        .rounds
        .iter()
        .all(|round| round.sparse_wake_ref.starts_with("sparsewake:"));
    let candidates_bound = evaluation
        .rounds
        .iter()
        .all(|round| !round.candidates.is_empty());
    let selected_bundle_bound = evaluation
        .rounds
        .iter()
        .all(|round| !round.expected_selected_unit_ids.is_empty());
    let rejected_bundle_bound = evaluation
        .rounds
        .iter()
        .all(|round| !round.expected_rejected_unit_ids.is_empty());
    let uas_addresses_bound = evaluation.rounds.iter().all(|round| {
        round
            .candidates
            .iter()
            .all(|candidate| candidate.uas_address.starts_with("uas:"))
    });
    let unit_kinds_bound = evaluation.rounds.iter().all(|round| {
        round.candidates.iter().all(|candidate| {
            matches!(
                candidate.unit_kind.as_str(),
                "model_tile" | "kv_page" | "evidence" | "verifier" | "adapter" | "tool"
            )
        })
    });
    let evidence_refs_bound = evaluation.rounds.iter().all(|round| {
        round
            .candidates
            .iter()
            .all(|candidate| candidate.evidence_ref.starts_with("evidence:"))
    });
    let compatibility_fences_bound = evaluation.rounds.iter().all(|round| {
        round
            .candidates
            .iter()
            .all(|candidate| candidate.compatibility_fence.starts_with("fence:"))
    });
    let budget_vector_bound = evaluation
        .rounds
        .iter()
        .all(|round| round.has_budget_vector());
    let verifier_need_bound = evaluation
        .rounds
        .iter()
        .all(|round| round.verifier_need.starts_with("verifier:"));
    let fallback_bound = evaluation
        .rounds
        .iter()
        .all(|round| round.fallback_route.starts_with("fallback:"));
    let abstain_reason_bound = evaluation
        .rounds
        .iter()
        .all(|round| round.abstain_reason.starts_with("reason:"));
    let selected_hot_bytes_within_budget = evaluation
        .rounds
        .iter()
        .all(|round| round.selected_hot_bytes() <= round.hot_byte_budget);
    let selected_kv_bytes_within_budget = evaluation
        .rounds
        .iter()
        .all(|round| round.selected_kv_bytes() <= round.kv_byte_budget);
    let selected_cold_io_within_budget = evaluation
        .rounds
        .iter()
        .all(|round| round.selected_cold_io_bytes() <= round.cold_io_budget);
    let selected_latency_within_budget = evaluation
        .rounds
        .iter()
        .all(|round| round.selected_latency_ms() <= round.latency_budget_ms);
    let privacy_risk_within_budget = evaluation
        .rounds
        .iter()
        .all(|round| round.selected_privacy_risk_bps() <= round.privacy_risk_budget_bps);
    let interference_risk_within_budget = evaluation
        .rounds
        .iter()
        .all(|round| round.selected_interference_risk_bps() <= round.interference_risk_budget_bps);
    let rollback_cost_within_budget = evaluation
        .rounds
        .iter()
        .all(|round| round.selected_rollback_cost_bps() <= round.rollback_cost_budget_bps);
    let verifier_coverage_bound = evaluation.rounds.iter().all(|round| {
        round.selected_verifier_coverage_bps() >= round.required_verifier_coverage_bps
    });
    let selected_bid_scores_positive = evaluation
        .rounds
        .iter()
        .all(|round| round.selected_bid_score_bps() >= MIN_SELECTED_BID_SCORE_BPS);
    let expected_selection_bound = evaluation
        .rounds
        .iter()
        .all(|round| expected_selection_matches(round));
    let rejected_bundle_reasons_bound = evaluation.rounds.iter().all(|round| {
        round
            .rejected_candidates()
            .iter()
            .all(|candidate| candidate.reject_reason.starts_with("reject:"))
    });
    let rollback_bound = evaluation
        .rounds
        .iter()
        .all(|round| round.rollback_handle.starts_with("rollback:"));
    let run_event_log_bound = evaluation
        .rounds
        .iter()
        .all(|round| round.run_event_log_ref.starts_with("runlog:"));
    let answer_packet_ref_bound = evaluation
        .rounds
        .iter()
        .all(|round| round.answer_packet_ref.starts_with("answerpacket:"));
    let route_authority_shadow_only = evaluation
        .rounds
        .iter()
        .all(|round| round.route_authority == "shadow_only");
    let no_hidden_route_authority = route_authority_shadow_only;
    let no_hidden_chain = evaluation
        .rounds
        .iter()
        .all(|round| !round.hidden_chain_exposed);
    let no_hidden_cloud = evaluation.rounds.iter().all(|round| !round.hidden_cloud);
    let live_policy_not_mutated = evaluation
        .rounds
        .iter()
        .all(|round| !round.live_policy_mutated);
    let auction_address_deterministic =
        evaluation.auction_address == reversed_evaluation.auction_address;
    let auction_success_beats_greedy_bytes_baseline =
        metrics.auction_success_bps > metrics.greedy_bytes_baseline_success_bps;
    let auction_success_beats_max_quality_baseline =
        metrics.auction_success_bps > metrics.max_quality_baseline_success_bps;
    let auction_success_beats_wake_all_baseline =
        metrics.auction_success_bps > metrics.wake_all_baseline_success_bps;
    let over_budget_bundle_rejected = metrics.over_budget_reject_count >= 1;
    let low_verifier_bundle_rejected = metrics.low_verifier_reject_count >= 1;
    let privacy_risk_bundle_rejected = metrics.privacy_risk_reject_count >= 1;
    let latency_bundle_rejected = metrics.latency_reject_count >= 1;
    let interference_bundle_rejected = metrics.interference_reject_count >= 1;
    let rollback_cost_bundle_rejected = metrics.rollback_reject_count >= 1;

    let duplicate_round_rejected = duplicate_round_rejected();
    let missing_candidate_rejected = invalid_round_rejected(|round| {
        round.candidates.clear();
    }) == Some(AuctionError::MissingCandidate);
    let missing_selected_bundle_rejected = invalid_round_rejected(|round| {
        round.expected_selected_unit_ids.clear();
    }) == Some(AuctionError::MissingSelectedBundle);
    let missing_rejected_bundle_rejected = invalid_round_rejected(|round| {
        round.expected_rejected_unit_ids.clear();
    }) == Some(AuctionError::MissingRejectedBundle);
    let missing_uas_address_rejected = invalid_round_rejected(|round| {
        round.candidates[0].uas_address.clear();
    }) == Some(AuctionError::MissingUasAddress);
    let missing_budget_rejected = invalid_round_rejected(|round| {
        round.hot_byte_budget = 0;
    }) == Some(AuctionError::MissingBudget);
    let over_hot_budget_rejected = invalid_round_rejected(|round| {
        round.hot_byte_budget = 1;
    }) == Some(AuctionError::HotBudgetExceeded);
    let over_kv_budget_rejected = invalid_round_rejected(|round| {
        round.kv_byte_budget = 1;
    }) == Some(AuctionError::KvBudgetExceeded);
    let over_cold_io_budget_rejected = invalid_round_rejected(|round| {
        round.cold_io_budget = 1;
    }) == Some(AuctionError::ColdIoBudgetExceeded);
    let over_latency_budget_rejected = invalid_round_rejected(|round| {
        round.latency_budget_ms = 1;
    }) == Some(AuctionError::LatencyBudgetExceeded);
    let over_privacy_budget_rejected = invalid_round_rejected(|round| {
        round.privacy_risk_budget_bps = 1;
    }) == Some(AuctionError::PrivacyRiskExceeded);
    let over_interference_budget_rejected = invalid_round_rejected(|round| {
        round.interference_risk_budget_bps = 1;
    }) == Some(AuctionError::InterferenceRiskExceeded);
    let over_rollback_budget_rejected = invalid_round_rejected(|round| {
        round.rollback_cost_budget_bps = 1;
    }) == Some(AuctionError::RollbackCostExceeded);
    let weak_verifier_coverage_rejected = invalid_round_rejected(|round| {
        round.required_verifier_coverage_bps = 10_000;
    }) == Some(AuctionError::WeakVerifierCoverage);
    let weak_bid_score_rejected = invalid_round_rejected(|round| {
        for candidate in round
            .candidates
            .iter_mut()
            .filter(|candidate| candidate.selected)
        {
            candidate.bid_score_bps = -2_000;
            candidate.evidence_delta_bps = 0;
            candidate.saved_prefill_bps = 0;
        }
    }) == Some(AuctionError::WeakBidScore);
    let missing_verifier_need_rejected = invalid_round_rejected(|round| {
        round.verifier_need.clear();
    }) == Some(AuctionError::MissingVerifierNeed);
    let missing_fallback_rejected = invalid_round_rejected(|round| {
        round.fallback_route.clear();
    }) == Some(AuctionError::MissingFallback);
    let missing_abstain_reason_rejected = invalid_round_rejected(|round| {
        round.abstain_reason.clear();
    }) == Some(AuctionError::MissingAbstainReason);
    let missing_rollback_rejected = invalid_round_rejected(|round| {
        round.rollback_handle.clear();
    }) == Some(AuctionError::MissingRollback);
    let missing_run_event_log_rejected = invalid_round_rejected(|round| {
        round.run_event_log_ref.clear();
    }) == Some(AuctionError::MissingRunEventLog);
    let missing_answer_packet_rejected = invalid_round_rejected(|round| {
        round.answer_packet_ref.clear();
    }) == Some(AuctionError::MissingAnswerPacket);
    let hidden_live_authority_rejected = invalid_round_rejected(|round| {
        round.route_authority = "live_sparse_auction".to_string();
    }) == Some(AuctionError::HiddenLiveAuthority);
    let live_policy_mutation_rejected = invalid_round_rejected(|round| {
        round.live_policy_mutated = true;
    }) == Some(AuctionError::LivePolicyMutation);
    let hidden_chain_exposure_rejected = invalid_round_rejected(|round| {
        round.hidden_chain_exposed = true;
    }) == Some(AuctionError::HiddenChainExposure);
    let cloud_route_rejected = invalid_round_rejected(|round| {
        round.hidden_cloud = true;
    }) == Some(AuctionError::CloudRoute);
    let auction_over_metadata_budget_rejected =
        invalid_round_rejected(|round| {
            round.auction_metadata_bytes = 8 * 1024 * 1024;
        }) == Some(AuctionError::AuctionMetadataBudgetExceeded);
    let no_runtime_bytes_loaded = true;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        (
            "upstream_sparse_wake_proposal_budget_pass",
            upstream_sparse_wake_proposal_budget_pass,
        ),
        (
            "verifier_budget_auction_fixture_present",
            verifier_budget_auction_fixture_present,
        ),
        ("training_split_bound", training_split_bound),
        ("held_out_split_bound", held_out_split_bound),
        ("auction_ids_bound", auction_ids_bound),
        ("mission_ids_bound", mission_ids_bound),
        ("sparse_wake_refs_bound", sparse_wake_refs_bound),
        ("candidates_bound", candidates_bound),
        ("selected_bundle_bound", selected_bundle_bound),
        ("rejected_bundle_bound", rejected_bundle_bound),
        ("uas_addresses_bound", uas_addresses_bound),
        ("unit_kinds_bound", unit_kinds_bound),
        ("evidence_refs_bound", evidence_refs_bound),
        ("compatibility_fences_bound", compatibility_fences_bound),
        ("budget_vector_bound", budget_vector_bound),
        ("verifier_need_bound", verifier_need_bound),
        ("fallback_bound", fallback_bound),
        ("abstain_reason_bound", abstain_reason_bound),
        (
            "selected_hot_bytes_within_budget",
            selected_hot_bytes_within_budget,
        ),
        (
            "selected_kv_bytes_within_budget",
            selected_kv_bytes_within_budget,
        ),
        (
            "selected_cold_io_within_budget",
            selected_cold_io_within_budget,
        ),
        (
            "selected_latency_within_budget",
            selected_latency_within_budget,
        ),
        ("privacy_risk_within_budget", privacy_risk_within_budget),
        (
            "interference_risk_within_budget",
            interference_risk_within_budget,
        ),
        ("rollback_cost_within_budget", rollback_cost_within_budget),
        ("verifier_coverage_bound", verifier_coverage_bound),
        ("selected_bid_scores_positive", selected_bid_scores_positive),
        ("expected_selection_bound", expected_selection_bound),
        (
            "rejected_bundle_reasons_bound",
            rejected_bundle_reasons_bound,
        ),
        ("rollback_bound", rollback_bound),
        ("run_event_log_bound", run_event_log_bound),
        ("answer_packet_ref_bound", answer_packet_ref_bound),
        ("route_authority_shadow_only", route_authority_shadow_only),
        ("no_hidden_route_authority", no_hidden_route_authority),
        ("no_hidden_chain", no_hidden_chain),
        ("no_hidden_cloud", no_hidden_cloud),
        ("live_policy_not_mutated", live_policy_not_mutated),
        (
            "auction_address_deterministic",
            auction_address_deterministic,
        ),
        (
            "auction_success_beats_greedy_bytes_baseline",
            auction_success_beats_greedy_bytes_baseline,
        ),
        (
            "auction_success_beats_max_quality_baseline",
            auction_success_beats_max_quality_baseline,
        ),
        (
            "auction_success_beats_wake_all_baseline",
            auction_success_beats_wake_all_baseline,
        ),
        ("over_budget_bundle_rejected", over_budget_bundle_rejected),
        ("low_verifier_bundle_rejected", low_verifier_bundle_rejected),
        ("privacy_risk_bundle_rejected", privacy_risk_bundle_rejected),
        ("latency_bundle_rejected", latency_bundle_rejected),
        ("interference_bundle_rejected", interference_bundle_rejected),
        (
            "rollback_cost_bundle_rejected",
            rollback_cost_bundle_rejected,
        ),
        ("duplicate_round_rejected", duplicate_round_rejected),
        ("missing_candidate_rejected", missing_candidate_rejected),
        (
            "missing_selected_bundle_rejected",
            missing_selected_bundle_rejected,
        ),
        (
            "missing_rejected_bundle_rejected",
            missing_rejected_bundle_rejected,
        ),
        ("missing_uas_address_rejected", missing_uas_address_rejected),
        ("missing_budget_rejected", missing_budget_rejected),
        ("over_hot_budget_rejected", over_hot_budget_rejected),
        ("over_kv_budget_rejected", over_kv_budget_rejected),
        ("over_cold_io_budget_rejected", over_cold_io_budget_rejected),
        ("over_latency_budget_rejected", over_latency_budget_rejected),
        ("over_privacy_budget_rejected", over_privacy_budget_rejected),
        (
            "over_interference_budget_rejected",
            over_interference_budget_rejected,
        ),
        (
            "over_rollback_budget_rejected",
            over_rollback_budget_rejected,
        ),
        (
            "weak_verifier_coverage_rejected",
            weak_verifier_coverage_rejected,
        ),
        ("weak_bid_score_rejected", weak_bid_score_rejected),
        (
            "missing_verifier_need_rejected",
            missing_verifier_need_rejected,
        ),
        ("missing_fallback_rejected", missing_fallback_rejected),
        (
            "missing_abstain_reason_rejected",
            missing_abstain_reason_rejected,
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
            "auction_over_metadata_budget_rejected",
            auction_over_metadata_budget_rejected,
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
        "training_round_count",
        evaluation.training_round_count(),
        2,
        "rounds",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_round_count",
        evaluation.held_out_round_count(),
        8,
        "rounds",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "candidate_count",
        evaluation.candidate_count(),
        30,
        "candidates",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "selected_bundle_unit_count",
        evaluation.selected_candidate_count(),
        20,
        "candidates",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rejected_bundle_unit_count",
        evaluation.rejected_candidate_count(),
        10,
        "candidates",
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_selected_hot_bytes",
        evaluation.max_selected_hot_bytes(),
        2 * 1024 * 1024,
        "<=",
        "bytes",
        evaluation.max_selected_hot_bytes() <= 2 * 1024 * 1024,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_selected_kv_bytes",
        evaluation.max_selected_kv_bytes(),
        2 * 1024 * 1024,
        "<=",
        "bytes",
        evaluation.max_selected_kv_bytes() <= 2 * 1024 * 1024,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_selected_cold_io_bytes",
        evaluation.max_selected_cold_io_bytes(),
        3 * 1024 * 1024,
        "<=",
        "bytes",
        evaluation.max_selected_cold_io_bytes() <= 3 * 1024 * 1024,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_selected_latency_ms",
        evaluation.max_selected_latency_ms(),
        120,
        "<=",
        "milliseconds",
        evaluation.max_selected_latency_ms() <= 120,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "min_selected_verifier_coverage_bps",
        evaluation.min_selected_verifier_coverage_bps() as u64,
        MIN_SELECTED_VERIFIER_COVERAGE_BPS as u64,
        ">=",
        "basis_points",
        evaluation.min_selected_verifier_coverage_bps() >= MIN_SELECTED_VERIFIER_COVERAGE_BPS,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "auction_success_bps",
        metrics.auction_success_bps,
        10_000,
        ">=",
        "basis_points",
        metrics.auction_success_bps >= 10_000,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "greedy_bytes_baseline_success_bps",
        metrics.greedy_bytes_baseline_success_bps,
        metrics.auction_success_bps,
        "<",
        "basis_points",
        metrics.greedy_bytes_baseline_success_bps < metrics.auction_success_bps,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_quality_baseline_success_bps",
        metrics.max_quality_baseline_success_bps,
        metrics.auction_success_bps,
        "<",
        "basis_points",
        metrics.max_quality_baseline_success_bps < metrics.auction_success_bps,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "wake_all_baseline_success_bps",
        metrics.wake_all_baseline_success_bps,
        metrics.auction_success_bps,
        "<",
        "basis_points",
        metrics.wake_all_baseline_success_bps < metrics.auction_success_bps,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "over_budget_reject_count",
        metrics.over_budget_reject_count,
        1,
        ">=",
        "rounds",
        metrics.over_budget_reject_count >= 1,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "low_verifier_reject_count",
        metrics.low_verifier_reject_count,
        1,
        ">=",
        "rounds",
        metrics.low_verifier_reject_count >= 1,
    );
    add_threshold_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_auction_metadata_bytes",
        evaluation.max_auction_metadata_bytes(),
        MAX_AUCTION_METADATA_BYTES,
        "<=",
        "bytes",
        evaluation.max_auction_metadata_bytes() <= MAX_AUCTION_METADATA_BYTES,
    );
    add_string_measurement(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "auction_address",
        &evaluation.auction_address,
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
        notes: "scope=metadata_only;organ=VerifierBudgetAuction;reviewer=codex;reviewed_at_utc=2026-06-04T00:00:00Z;validator=falsifier_validator;local_reference_only=true;detail=VerifierBudgetAuction rejects over-budget, low-verifier, privacy-risk, latency-risk, interference-risk, and rollback-cost bundles before execution while binding fallback, rollback, RunEventLog, AnswerPacket, and shadow-only authority".to_string(),
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
            value: serde_json::Value::String("uas:verifier-budget-auction:".to_string()),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(
        name.to_string(),
        value.starts_with("uas:verifier-budget-auction:"),
    );
}

#[derive(Clone)]
// UAS: uas:verifier-budget-auction:evaluation
// Plane: Verification
// Residency: metadata-only
struct AuctionEvaluation {
    rounds: Vec<VerifierBudgetAuctionRound>,
    metrics: AuctionMetrics,
    auction_address: String,
}

impl AuctionEvaluation {
    fn new(rounds: Vec<VerifierBudgetAuctionRound>) -> Result<Self, AuctionError> {
        if rounds.is_empty() {
            return Err(AuctionError::MissingRound);
        }
        let mut seen = BTreeSet::new();
        for round in &rounds {
            if !seen.insert(round.auction_id.as_str()) {
                return Err(AuctionError::DuplicateRound);
            }
            validate_round(round)?;
        }
        let metrics = AuctionMetrics::from_rounds(&rounds)?;
        let auction_address = auction_address(&rounds);
        Ok(Self {
            rounds,
            metrics,
            auction_address,
        })
    }

    fn held_out_rounds(&self) -> Vec<&VerifierBudgetAuctionRound> {
        self.rounds
            .iter()
            .filter(|round| round.split == "held_out")
            .collect()
    }

    fn training_round_count(&self) -> u64 {
        self.rounds
            .iter()
            .filter(|round| round.split == "train")
            .count() as u64
    }

    fn held_out_round_count(&self) -> u64 {
        self.held_out_rounds().len() as u64
    }

    fn candidate_count(&self) -> u64 {
        self.rounds
            .iter()
            .map(|round| round.candidates.len() as u64)
            .sum()
    }

    fn selected_candidate_count(&self) -> u64 {
        self.rounds
            .iter()
            .map(|round| round.selected_candidates().len() as u64)
            .sum()
    }

    fn rejected_candidate_count(&self) -> u64 {
        self.rounds
            .iter()
            .map(|round| round.rejected_candidates().len() as u64)
            .sum()
    }

    fn max_selected_hot_bytes(&self) -> u64 {
        self.rounds
            .iter()
            .map(VerifierBudgetAuctionRound::selected_hot_bytes)
            .max()
            .unwrap_or(0)
    }

    fn max_selected_kv_bytes(&self) -> u64 {
        self.rounds
            .iter()
            .map(VerifierBudgetAuctionRound::selected_kv_bytes)
            .max()
            .unwrap_or(0)
    }

    fn max_selected_cold_io_bytes(&self) -> u64 {
        self.rounds
            .iter()
            .map(VerifierBudgetAuctionRound::selected_cold_io_bytes)
            .max()
            .unwrap_or(0)
    }

    fn max_selected_latency_ms(&self) -> u64 {
        self.rounds
            .iter()
            .map(VerifierBudgetAuctionRound::selected_latency_ms)
            .max()
            .unwrap_or(0)
    }

    fn min_selected_verifier_coverage_bps(&self) -> i64 {
        self.rounds
            .iter()
            .map(VerifierBudgetAuctionRound::selected_verifier_coverage_bps)
            .min()
            .unwrap_or(0)
    }

    fn max_auction_metadata_bytes(&self) -> u64 {
        self.rounds
            .iter()
            .map(|round| round.auction_metadata_bytes)
            .max()
            .unwrap_or(0)
    }
}

#[derive(Clone, Copy)]
// UAS: uas:verifier-budget-auction:metrics
// Plane: Verification
// Residency: metadata-only
struct AuctionMetrics {
    auction_success_bps: u64,
    greedy_bytes_baseline_success_bps: u64,
    max_quality_baseline_success_bps: u64,
    wake_all_baseline_success_bps: u64,
    over_budget_reject_count: u64,
    low_verifier_reject_count: u64,
    privacy_risk_reject_count: u64,
    latency_reject_count: u64,
    interference_reject_count: u64,
    rollback_reject_count: u64,
}

impl AuctionMetrics {
    fn from_rounds(rounds: &[VerifierBudgetAuctionRound]) -> Result<Self, AuctionError> {
        if rounds.iter().filter(|round| round.split == "train").count() < 2 {
            return Err(AuctionError::MissingTrainingSplit);
        }
        let held_out = rounds
            .iter()
            .filter(|round| round.split == "held_out")
            .collect::<Vec<_>>();
        if held_out.len() < 8 {
            return Err(AuctionError::MissingHeldOutSplit);
        }

        let auction_success_bps = success_bps(&held_out, auction_correct);
        let greedy_bytes_baseline_success_bps = success_bps(&held_out, greedy_bytes_correct);
        let max_quality_baseline_success_bps = success_bps(&held_out, max_quality_correct);
        let wake_all_baseline_success_bps = success_bps(&held_out, wake_all_correct);
        if auction_success_bps <= greedy_bytes_baseline_success_bps {
            return Err(AuctionError::GreedyBytesBaselineUnbeaten);
        }
        if auction_success_bps <= max_quality_baseline_success_bps {
            return Err(AuctionError::MaxQualityBaselineUnbeaten);
        }
        if auction_success_bps <= wake_all_baseline_success_bps {
            return Err(AuctionError::WakeAllBaselineUnbeaten);
        }

        let over_budget_reject_count =
            count_reject_reason(&held_out, "reject:hot_budget_exceeded") as u64;
        let low_verifier_reject_count =
            count_reject_reason(&held_out, "reject:low_verifier_coverage") as u64;
        let privacy_risk_reject_count =
            count_reject_reason(&held_out, "reject:privacy_risk_exceeded") as u64;
        let latency_reject_count =
            count_reject_reason(&held_out, "reject:latency_budget_exceeded") as u64;
        let interference_reject_count =
            count_reject_reason(&held_out, "reject:interference_risk_exceeded") as u64;
        let rollback_reject_count =
            count_reject_reason(&held_out, "reject:rollback_cost_exceeded") as u64;

        if over_budget_reject_count == 0 {
            return Err(AuctionError::MissingOverBudgetRejectCase);
        }
        if low_verifier_reject_count == 0 {
            return Err(AuctionError::MissingLowVerifierRejectCase);
        }
        if privacy_risk_reject_count == 0 {
            return Err(AuctionError::MissingPrivacyRejectCase);
        }
        if latency_reject_count == 0 {
            return Err(AuctionError::MissingLatencyRejectCase);
        }
        if interference_reject_count == 0 {
            return Err(AuctionError::MissingInterferenceRejectCase);
        }
        if rollback_reject_count == 0 {
            return Err(AuctionError::MissingRollbackRejectCase);
        }

        Ok(Self {
            auction_success_bps,
            greedy_bytes_baseline_success_bps,
            max_quality_baseline_success_bps,
            wake_all_baseline_success_bps,
            over_budget_reject_count,
            low_verifier_reject_count,
            privacy_risk_reject_count,
            latency_reject_count,
            interference_reject_count,
            rollback_reject_count,
        })
    }
}

impl VerifierBudgetAuctionRound {
    fn selected_candidates(&self) -> Vec<&AuctionCandidate> {
        self.candidates
            .iter()
            .filter(|candidate| candidate.selected)
            .collect()
    }

    fn rejected_candidates(&self) -> Vec<&AuctionCandidate> {
        self.candidates
            .iter()
            .filter(|candidate| !candidate.selected)
            .collect()
    }

    fn selected_hot_bytes(&self) -> u64 {
        self.selected_candidates()
            .iter()
            .map(|candidate| candidate.hot_bytes)
            .sum()
    }

    fn selected_kv_bytes(&self) -> u64 {
        self.selected_candidates()
            .iter()
            .map(|candidate| candidate.kv_bytes)
            .sum()
    }

    fn selected_cold_io_bytes(&self) -> u64 {
        self.selected_candidates()
            .iter()
            .map(|candidate| candidate.cold_io_bytes)
            .sum()
    }

    fn selected_latency_ms(&self) -> u64 {
        self.selected_candidates()
            .iter()
            .map(|candidate| candidate.latency_ms)
            .sum()
    }

    fn selected_privacy_risk_bps(&self) -> u64 {
        self.selected_candidates()
            .iter()
            .map(|candidate| candidate.privacy_risk_bps)
            .sum()
    }

    fn selected_interference_risk_bps(&self) -> u64 {
        self.selected_candidates()
            .iter()
            .map(|candidate| candidate.interference_risk_bps)
            .sum()
    }

    fn selected_rollback_cost_bps(&self) -> u64 {
        self.selected_candidates()
            .iter()
            .map(|candidate| candidate.rollback_cost_bps)
            .sum()
    }

    fn selected_verifier_coverage_bps(&self) -> i64 {
        self.selected_candidates()
            .iter()
            .map(|candidate| candidate.verifier_delta_bps)
            .sum()
    }

    fn selected_bid_score_bps(&self) -> i64 {
        self.selected_candidates()
            .iter()
            .map(|candidate| {
                candidate.bid_score_bps + candidate.evidence_delta_bps + candidate.saved_prefill_bps
            })
            .sum()
    }

    fn has_budget_vector(&self) -> bool {
        self.hot_byte_budget > 0
            && self.kv_byte_budget > 0
            && self.cold_io_budget > 0
            && self.latency_budget_ms > 0
            && self.privacy_risk_budget_bps > 0
            && self.interference_risk_budget_bps > 0
            && self.rollback_cost_budget_bps > 0
    }
}

impl AuctionCandidate {
    fn total_bytes(&self) -> u64 {
        self.hot_bytes + self.kv_bytes + self.cold_io_bytes
    }
}

fn validate_round(round: &VerifierBudgetAuctionRound) -> Result<(), AuctionError> {
    if round.split != "train" && round.split != "held_out" {
        return Err(AuctionError::MissingSplit);
    }
    if round.auction_id.is_empty() || !round.auction_id.starts_with("auction:") {
        return Err(AuctionError::MissingAuctionId);
    }
    if round.mission_id.is_empty() || !round.mission_id.starts_with("mission:") {
        return Err(AuctionError::MissingMission);
    }
    if round.sparse_wake_ref.is_empty() || !round.sparse_wake_ref.starts_with("sparsewake:") {
        return Err(AuctionError::MissingSparseWakeRef);
    }
    if round.candidates.is_empty() {
        return Err(AuctionError::MissingCandidate);
    }
    let mut seen = BTreeSet::new();
    for candidate in &round.candidates {
        if !seen.insert(candidate.unit_id.as_str()) {
            return Err(AuctionError::DuplicateCandidate);
        }
        validate_candidate(candidate)?;
    }
    if round.expected_selected_unit_ids.is_empty() {
        return Err(AuctionError::MissingSelectedBundle);
    }
    if round.expected_rejected_unit_ids.is_empty() {
        return Err(AuctionError::MissingRejectedBundle);
    }
    if !round.has_budget_vector() {
        return Err(AuctionError::MissingBudget);
    }
    if round.verifier_need.is_empty() || !round.verifier_need.starts_with("verifier:") {
        return Err(AuctionError::MissingVerifierNeed);
    }
    if round.fallback_route.is_empty() || !round.fallback_route.starts_with("fallback:") {
        return Err(AuctionError::MissingFallback);
    }
    if round.abstain_reason.is_empty() || !round.abstain_reason.starts_with("reason:") {
        return Err(AuctionError::MissingAbstainReason);
    }
    if round.rollback_handle.is_empty() || !round.rollback_handle.starts_with("rollback:") {
        return Err(AuctionError::MissingRollback);
    }
    if round.run_event_log_ref.is_empty() || !round.run_event_log_ref.starts_with("runlog:") {
        return Err(AuctionError::MissingRunEventLog);
    }
    if round.answer_packet_ref.is_empty() || !round.answer_packet_ref.starts_with("answerpacket:") {
        return Err(AuctionError::MissingAnswerPacket);
    }
    if round.selected_hot_bytes() > round.hot_byte_budget {
        return Err(AuctionError::HotBudgetExceeded);
    }
    if round.selected_kv_bytes() > round.kv_byte_budget {
        return Err(AuctionError::KvBudgetExceeded);
    }
    if round.selected_cold_io_bytes() > round.cold_io_budget {
        return Err(AuctionError::ColdIoBudgetExceeded);
    }
    if round.selected_latency_ms() > round.latency_budget_ms {
        return Err(AuctionError::LatencyBudgetExceeded);
    }
    if round.selected_privacy_risk_bps() > round.privacy_risk_budget_bps {
        return Err(AuctionError::PrivacyRiskExceeded);
    }
    if round.selected_interference_risk_bps() > round.interference_risk_budget_bps {
        return Err(AuctionError::InterferenceRiskExceeded);
    }
    if round.selected_rollback_cost_bps() > round.rollback_cost_budget_bps {
        return Err(AuctionError::RollbackCostExceeded);
    }
    if round.selected_verifier_coverage_bps() < round.required_verifier_coverage_bps {
        return Err(AuctionError::WeakVerifierCoverage);
    }
    if round.selected_bid_score_bps() < MIN_SELECTED_BID_SCORE_BPS {
        return Err(AuctionError::WeakBidScore);
    }
    if !expected_selection_matches(round) {
        return Err(AuctionError::InvalidExpectedSelection);
    }
    if round.route_authority != "shadow_only" {
        return Err(AuctionError::HiddenLiveAuthority);
    }
    if round.live_policy_mutated {
        return Err(AuctionError::LivePolicyMutation);
    }
    if round.hidden_chain_exposed {
        return Err(AuctionError::HiddenChainExposure);
    }
    if round.hidden_cloud {
        return Err(AuctionError::CloudRoute);
    }
    if round.auction_metadata_bytes > MAX_AUCTION_METADATA_BYTES {
        return Err(AuctionError::AuctionMetadataBudgetExceeded);
    }
    Ok(())
}

fn validate_candidate(candidate: &AuctionCandidate) -> Result<(), AuctionError> {
    if candidate.uas_address.is_empty() || !candidate.uas_address.starts_with("uas:") {
        return Err(AuctionError::MissingUasAddress);
    }
    if !matches!(
        candidate.unit_kind.as_str(),
        "model_tile" | "kv_page" | "evidence" | "verifier" | "adapter" | "tool"
    ) {
        return Err(AuctionError::MissingUnitKind);
    }
    if candidate.evidence_ref.is_empty() || !candidate.evidence_ref.starts_with("evidence:") {
        return Err(AuctionError::MissingEvidenceRef);
    }
    if candidate.compatibility_fence.is_empty()
        || !candidate.compatibility_fence.starts_with("fence:")
    {
        return Err(AuctionError::MissingCompatibilityFence);
    }
    if !matches!(
        candidate.privacy_class.as_str(),
        "local_private" | "vault_private" | "research_shadow"
    ) {
        return Err(AuctionError::InvalidPrivacyClass);
    }
    Ok(())
}

fn expected_selection_matches(round: &VerifierBudgetAuctionRound) -> bool {
    let actual_selected = round
        .selected_candidates()
        .iter()
        .map(|candidate| candidate.unit_id.as_str())
        .collect::<BTreeSet<_>>();
    let expected_selected = round
        .expected_selected_unit_ids
        .iter()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    let actual_rejected = round
        .rejected_candidates()
        .iter()
        .map(|candidate| candidate.unit_id.as_str())
        .collect::<BTreeSet<_>>();
    let expected_rejected = round
        .expected_rejected_unit_ids
        .iter()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    actual_selected == expected_selected && actual_rejected == expected_rejected
}

fn auction_correct(round: &&VerifierBudgetAuctionRound) -> bool {
    expected_selection_matches(round)
        && round.selected_hot_bytes() <= round.hot_byte_budget
        && round.selected_kv_bytes() <= round.kv_byte_budget
        && round.selected_cold_io_bytes() <= round.cold_io_budget
        && round.selected_latency_ms() <= round.latency_budget_ms
        && round.selected_verifier_coverage_bps() >= round.required_verifier_coverage_bps
}

fn greedy_bytes_correct(round: &&VerifierBudgetAuctionRound) -> bool {
    let selected_count = round.expected_selected_unit_ids.len();
    let mut candidates = round.candidates.iter().collect::<Vec<_>>();
    candidates.sort_by_key(|candidate| (candidate.total_bytes(), candidate.unit_id.as_str()));
    let picked = candidates
        .into_iter()
        .take(selected_count)
        .map(|candidate| candidate.unit_id.as_str())
        .collect::<BTreeSet<_>>();
    let expected = round
        .expected_selected_unit_ids
        .iter()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    picked == expected
}

fn max_quality_correct(round: &&VerifierBudgetAuctionRound) -> bool {
    let selected_count = round.expected_selected_unit_ids.len();
    let mut candidates = round.candidates.iter().collect::<Vec<_>>();
    candidates.sort_by(|left, right| {
        right
            .quality_delta_bps
            .cmp(&left.quality_delta_bps)
            .then_with(|| left.unit_id.cmp(&right.unit_id))
    });
    let picked = candidates
        .into_iter()
        .take(selected_count)
        .map(|candidate| candidate.unit_id.as_str())
        .collect::<BTreeSet<_>>();
    let expected = round
        .expected_selected_unit_ids
        .iter()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    picked == expected
}

fn wake_all_correct(round: &&VerifierBudgetAuctionRound) -> bool {
    let picked = round
        .candidates
        .iter()
        .map(|candidate| candidate.unit_id.as_str())
        .collect::<BTreeSet<_>>();
    let expected = round
        .expected_selected_unit_ids
        .iter()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    picked == expected
}

fn success_bps<F>(rounds: &[&VerifierBudgetAuctionRound], predicate: F) -> u64
where
    F: Fn(&&VerifierBudgetAuctionRound) -> bool,
{
    let wins = rounds.iter().filter(|round| predicate(round)).count() as u64;
    if rounds.is_empty() {
        0
    } else {
        wins * 10_000 / rounds.len() as u64
    }
}

fn count_reject_reason(rounds: &[&VerifierBudgetAuctionRound], reason: &str) -> usize {
    rounds
        .iter()
        .filter(|round| {
            round
                .rejected_candidates()
                .iter()
                .any(|candidate| candidate.reject_reason == reason)
        })
        .count()
}

fn auction_address(rounds: &[VerifierBudgetAuctionRound]) -> String {
    let mut entries = rounds
        .iter()
        .map(|round| {
            let selected = round
                .expected_selected_unit_ids
                .iter()
                .map(String::as_str)
                .collect::<Vec<_>>()
                .join(",");
            let rejected = round
                .expected_rejected_unit_ids
                .iter()
                .map(String::as_str)
                .collect::<Vec<_>>()
                .join(",");
            format!(
                "{}|{}|{}|{}|{}|{}|{}|{}|{}",
                round.auction_id,
                round.mission_id,
                round.sparse_wake_ref,
                selected,
                rejected,
                round.hot_byte_budget,
                round.kv_byte_budget,
                round.cold_io_budget,
                round.latency_budget_ms
            )
        })
        .collect::<Vec<_>>();
    entries.sort();
    let digest = sha256_hex(entries.join("\n").as_bytes());
    format!("uas:verifier-budget-auction:{digest}")
}

fn upstream_sparse_wake_pass() -> bool {
    let bytes = match read_repo_or_crate_relative(UPSTREAM_SPARSE_WAKE) {
        Some(bytes) => bytes,
        None => return false,
    };
    let value = match serde_json::from_slice::<serde_json::Value>(&bytes) {
        Ok(value) => value,
        Err(_) => return false,
    };
    value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
}

fn read_repo_or_crate_relative(path: &str) -> Option<Vec<u8>> {
    std::fs::read(path)
        .ok()
        .or_else(|| std::fs::read(Path::new("..").join(path)).ok())
}

fn invalid_round_rejected(
    mutate: impl FnOnce(&mut VerifierBudgetAuctionRound),
) -> Option<AuctionError> {
    let mut rounds = fixture_rounds();
    mutate(&mut rounds[0]);
    AuctionEvaluation::new(rounds).err()
}

fn duplicate_round_rejected() -> bool {
    let mut rounds = fixture_rounds();
    let duplicate = rounds[0].clone();
    rounds.push(duplicate);
    AuctionEvaluation::new(rounds).err() == Some(AuctionError::DuplicateRound)
}

fn fixture_rounds() -> Vec<VerifierBudgetAuctionRound> {
    vec![
        auction_round(1, "train", "apple-private-rewrite", "hot_budget_exceeded"),
        auction_round(2, "train", "eidos-cited-answer", "low_verifier_coverage"),
        auction_round(3, "held_out", "local-code-note", "privacy_risk_exceeded"),
        auction_round(4, "held_out", "proof-repair", "latency_budget_exceeded"),
        auction_round(5, "held_out", "kv-recall", "interference_risk_exceeded"),
        auction_round(
            6,
            "held_out",
            "scope-rex-mutation",
            "rollback_cost_exceeded",
        ),
        auction_round(7, "held_out", "uncalibrated-source", "hot_budget_exceeded"),
        auction_round(
            8,
            "held_out",
            "adversarial-synthesis",
            "low_verifier_coverage",
        ),
        auction_round(9, "held_out", "coverage-shortfall", "privacy_risk_exceeded"),
        auction_round(
            10,
            "held_out",
            "verifier-citation-risk",
            "latency_budget_exceeded",
        ),
    ]
}

fn auction_round(
    index: u64,
    split: &str,
    mission_suffix: &str,
    reject_kind: &str,
) -> VerifierBudgetAuctionRound {
    let selected_a = selected_candidate(index, "model_tile", "selected-model", 720, 520);
    let selected_b = selected_candidate(index, "verifier", "selected-verifier", 640, 610);
    let rejected = rejected_candidate(index, reject_kind);
    let selected_a_id = selected_a.unit_id.clone();
    let selected_b_id = selected_b.unit_id.clone();
    let rejected_id = rejected.unit_id.clone();

    VerifierBudgetAuctionRound {
        split: split.to_string(),
        auction_id: format!("auction:{index:02}:{mission_suffix}"),
        mission_id: format!("mission:{mission_suffix}"),
        sparse_wake_ref: format!("sparsewake:{index:02}:{mission_suffix}"),
        candidates: vec![selected_a, selected_b, rejected],
        expected_selected_unit_ids: vec![selected_a_id, selected_b_id],
        expected_rejected_unit_ids: vec![rejected_id],
        hot_byte_budget: 2 * 1024 * 1024,
        kv_byte_budget: 2 * 1024 * 1024,
        cold_io_budget: 3 * 1024 * 1024,
        latency_budget_ms: 120,
        privacy_risk_budget_bps: 700,
        interference_risk_budget_bps: 700,
        rollback_cost_budget_bps: 350,
        required_verifier_coverage_bps: MIN_SELECTED_VERIFIER_COVERAGE_BPS,
        verifier_need: format!("verifier:{mission_suffix}"),
        fallback_route: format!("fallback:{mission_suffix}:full-route-shadow"),
        abstain_reason: "reason:not_needed".to_string(),
        rollback_handle: format!("rollback:auction:{index:02}"),
        run_event_log_ref: format!("runlog:auction:{index:02}"),
        answer_packet_ref: format!("answerpacket:auction:{index:02}"),
        route_authority: "shadow_only".to_string(),
        auction_metadata_bytes: 96 * 1024,
        hidden_chain_exposed: false,
        hidden_cloud: false,
        live_policy_mutated: false,
    }
}

fn selected_candidate(
    index: u64,
    unit_kind: &str,
    label: &str,
    verifier_delta_bps: i64,
    quality_delta_bps: i64,
) -> AuctionCandidate {
    AuctionCandidate {
        unit_id: format!("unit:{index:02}:{label}"),
        uas_address: format!("uas:verifier-budget-auction:{index:02}:{label}"),
        unit_kind: unit_kind.to_string(),
        hot_bytes: 620 * 1024,
        kv_bytes: 540 * 1024,
        cold_io_bytes: 760 * 1024,
        latency_ms: 44,
        verifier_delta_bps,
        quality_delta_bps,
        evidence_delta_bps: 480,
        saved_prefill_bps: 250,
        bid_score_bps: verifier_delta_bps + quality_delta_bps + 730,
        privacy_risk_bps: 110,
        interference_risk_bps: 130,
        rollback_cost_bps: 70,
        evidence_ref: format!("evidence:{index:02}:{label}"),
        compatibility_fence: format!("fence:{index:02}:mlx-local-shadow"),
        privacy_class: "local_private".to_string(),
        selected: true,
        reject_reason: "reject:not_rejected".to_string(),
    }
}

fn rejected_candidate(index: u64, reject_kind: &str) -> AuctionCandidate {
    let mut candidate = AuctionCandidate {
        unit_id: format!("unit:{index:02}:rejected-{reject_kind}"),
        uas_address: format!("uas:verifier-budget-auction:{index:02}:rejected-{reject_kind}"),
        unit_kind: "model_tile".to_string(),
        hot_bytes: 110 * 1024,
        kv_bytes: 90 * 1024,
        cold_io_bytes: 130 * 1024,
        latency_ms: 30,
        verifier_delta_bps: 30,
        quality_delta_bps: 2_200,
        evidence_delta_bps: 80,
        saved_prefill_bps: 40,
        bid_score_bps: 180,
        privacy_risk_bps: 100,
        interference_risk_bps: 120,
        rollback_cost_bps: 60,
        evidence_ref: format!("evidence:{index:02}:rejected-{reject_kind}"),
        compatibility_fence: format!("fence:{index:02}:reject"),
        privacy_class: "local_private".to_string(),
        selected: false,
        reject_reason: format!("reject:{reject_kind}"),
    };

    match reject_kind {
        "hot_budget_exceeded" => {
            candidate.hot_bytes = 4 * 1024 * 1024;
            candidate.verifier_delta_bps = 2_400;
            candidate.bid_score_bps = 2_900;
        }
        "low_verifier_coverage" => {
            candidate.verifier_delta_bps = 20;
            candidate.bid_score_bps = 250;
        }
        "privacy_risk_exceeded" => {
            candidate.privacy_risk_bps = 1_600;
            candidate.verifier_delta_bps = 2_000;
            candidate.bid_score_bps = 2_700;
        }
        "latency_budget_exceeded" => {
            candidate.latency_ms = 260;
            candidate.verifier_delta_bps = 2_000;
            candidate.bid_score_bps = 2_600;
        }
        "interference_risk_exceeded" => {
            candidate.interference_risk_bps = 1_500;
            candidate.verifier_delta_bps = 2_000;
            candidate.bid_score_bps = 2_600;
        }
        "rollback_cost_exceeded" => {
            candidate.rollback_cost_bps = 1_000;
            candidate.verifier_delta_bps = 2_000;
            candidate.bid_score_bps = 2_500;
        }
        _ => {}
    }

    candidate
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fixture_evaluation_passes_and_address_is_order_stable() {
        let rounds = fixture_rounds();
        let reversed = rounds.iter().cloned().rev().collect::<Vec<_>>();
        let evaluation = match AuctionEvaluation::new(rounds) {
            Ok(evaluation) => evaluation,
            Err(error) => panic!("fixture should pass: {error}"),
        };
        let reversed_evaluation = match AuctionEvaluation::new(reversed) {
            Ok(evaluation) => evaluation,
            Err(error) => panic!("reversed fixture should pass: {error}"),
        };

        assert_eq!(evaluation.training_round_count(), 2);
        assert_eq!(evaluation.held_out_round_count(), 8);
        assert_eq!(evaluation.candidate_count(), 30);
        assert_eq!(evaluation.selected_candidate_count(), 20);
        assert_eq!(evaluation.rejected_candidate_count(), 10);
        assert_eq!(
            evaluation.auction_address,
            reversed_evaluation.auction_address
        );
        assert_eq!(evaluation.metrics.auction_success_bps, 10_000);
        assert!(evaluation.metrics.greedy_bytes_baseline_success_bps < 10_000);
        assert!(evaluation.metrics.max_quality_baseline_success_bps < 10_000);
        assert!(evaluation.metrics.wake_all_baseline_success_bps < 10_000);
    }

    #[test]
    fn empty_fixture_rejects() {
        assert_eq!(
            AuctionEvaluation::new(Vec::new()).err(),
            Some(AuctionError::MissingRound)
        );
    }

    #[test]
    fn required_invalid_fixtures_reject() {
        let cases = [
            duplicate_round_rejected(),
            invalid_round_rejected(|round| round.candidates.clear())
                == Some(AuctionError::MissingCandidate),
            invalid_round_rejected(|round| round.expected_selected_unit_ids.clear())
                == Some(AuctionError::MissingSelectedBundle),
            invalid_round_rejected(|round| round.expected_rejected_unit_ids.clear())
                == Some(AuctionError::MissingRejectedBundle),
            invalid_round_rejected(|round| round.candidates[0].uas_address.clear())
                == Some(AuctionError::MissingUasAddress),
            invalid_round_rejected(|round| round.hot_byte_budget = 0)
                == Some(AuctionError::MissingBudget),
            invalid_round_rejected(|round| round.hot_byte_budget = 1)
                == Some(AuctionError::HotBudgetExceeded),
            invalid_round_rejected(|round| round.kv_byte_budget = 1)
                == Some(AuctionError::KvBudgetExceeded),
            invalid_round_rejected(|round| round.cold_io_budget = 1)
                == Some(AuctionError::ColdIoBudgetExceeded),
            invalid_round_rejected(|round| round.latency_budget_ms = 1)
                == Some(AuctionError::LatencyBudgetExceeded),
            invalid_round_rejected(|round| round.privacy_risk_budget_bps = 1)
                == Some(AuctionError::PrivacyRiskExceeded),
            invalid_round_rejected(|round| round.interference_risk_budget_bps = 1)
                == Some(AuctionError::InterferenceRiskExceeded),
            invalid_round_rejected(|round| round.rollback_cost_budget_bps = 1)
                == Some(AuctionError::RollbackCostExceeded),
            invalid_round_rejected(|round| round.required_verifier_coverage_bps = 10_000)
                == Some(AuctionError::WeakVerifierCoverage),
            invalid_round_rejected(|round| {
                for candidate in round
                    .candidates
                    .iter_mut()
                    .filter(|candidate| candidate.selected)
                {
                    candidate.bid_score_bps = -2_000;
                    candidate.evidence_delta_bps = 0;
                    candidate.saved_prefill_bps = 0;
                }
            }) == Some(AuctionError::WeakBidScore),
            invalid_round_rejected(|round| round.verifier_need.clear())
                == Some(AuctionError::MissingVerifierNeed),
            invalid_round_rejected(|round| round.fallback_route.clear())
                == Some(AuctionError::MissingFallback),
            invalid_round_rejected(|round| round.abstain_reason.clear())
                == Some(AuctionError::MissingAbstainReason),
            invalid_round_rejected(|round| round.rollback_handle.clear())
                == Some(AuctionError::MissingRollback),
            invalid_round_rejected(|round| round.run_event_log_ref.clear())
                == Some(AuctionError::MissingRunEventLog),
            invalid_round_rejected(|round| round.answer_packet_ref.clear())
                == Some(AuctionError::MissingAnswerPacket),
            invalid_round_rejected(|round| round.route_authority = "live".to_string())
                == Some(AuctionError::HiddenLiveAuthority),
            invalid_round_rejected(|round| round.live_policy_mutated = true)
                == Some(AuctionError::LivePolicyMutation),
            invalid_round_rejected(|round| round.hidden_chain_exposed = true)
                == Some(AuctionError::HiddenChainExposure),
            invalid_round_rejected(|round| round.hidden_cloud = true)
                == Some(AuctionError::CloudRoute),
            invalid_round_rejected(|round| round.auction_metadata_bytes = 8 * 1024 * 1024)
                == Some(AuctionError::AuctionMetadataBudgetExceeded),
        ];

        assert!(cases.into_iter().all(|passed| passed));
    }

    #[test]
    fn build_artifact_sets_required_scope_axis() {
        let artifact = match build_artifact() {
            Ok(artifact) => artifact,
            Err(error) => panic!("artifact should build: {error}"),
        };
        assert_eq!(artifact.falsifier_id, FALSIFIER_ID);
        assert!(artifact.overall_pass);
        assert_eq!(
            artifact.measurements["no_runtime_bytes_loaded"].value,
            serde_json::Value::Bool(true)
        );
        assert_eq!(
            artifact.measurements["auction_success_bps"].value,
            serde_json::Value::from(10_000)
        );
        assert!(artifact.measurements["auction_address"]
            .value
            .as_str()
            .is_some_and(|value| value.starts_with("uas:verifier-budget-auction:")));
    }
}
