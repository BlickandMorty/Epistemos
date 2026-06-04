//! `falsify_proof_search_signal_route_feedback` -- proof outcome route witness.
//!
//! Metadata-only witness for `F-ProofSearchSignal-RouteFeedback`. It proves
//! Lean/proof pass, fail, repair, and abstain outcomes can become explicit
//! route features without becoming hidden truth, bypassing verifiers, or
//! omitting RunEventLog / AnswerPacket evidence.

use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-ProofSearchSignal-RouteFeedback";
const FIXTURE_ID: &str = "proof_search_signal_route_feedback_v1";
const COMMAND: &str = "Tools/falsifiers/f_proof_search_signal_route_feedback.sh";
const RESULT: &str = "artifacts/falsifiers/proof_search_signal_route_feedback/result.json";
const UPSTREAM_ROUTE_DISTILLATION: &str =
    "artifacts/falsifiers/route_distillation_tournament/result.json";

const CURRENT_FENCE: &str = "fence:proof-search-signal:v1:route-distillation";
const MAX_PROOF_TOKENS: u64 = 32_000;
const MAX_SIGNAL_METADATA_BYTES: u64 = 768 * 1024;
const MIN_STATUS_KIND_COUNT: u64 = 4;
const MIN_ROUTE_FEATURE_KIND_COUNT: u64 = 5;
const MIN_HELD_OUT_ROUTE_SUCCESS_BPS: u64 = 8_900;
const MIN_VERIFIER_ALIGNMENT_BPS: u64 = 9_000;
const MIN_ANSWER_PACKET_COVERAGE_BPS: u64 = 10_000;
const MAX_CALIBRATION_ERROR_BPS: u64 = 850;

#[cfg(test)]
const REQUIRED_AXES: &[&str] = &[
    "upstream_route_distillation_tournament_pass",
    "proof_search_signal_fixture_present",
    "fixture_ids_bound",
    "feature_schema_refs_bound",
    "shadow_policy_refs_bound",
    "signal_ids_bound",
    "claim_ids_bound",
    "mission_ids_bound",
    "premise_refs_bound",
    "proof_state_hashes_bound",
    "tactic_trace_refs_bound",
    "verifier_status_bound",
    "pass_status_bound",
    "fail_status_bound",
    "repair_status_bound",
    "abstain_status_bound",
    "failure_signatures_bound",
    "repair_hints_bound",
    "route_feature_labels_bound",
    "test_refs_bound",
    "citation_refs_bound",
    "scope_rex_refs_bound",
    "sovereign_gate_refs_bound",
    "compatibility_fence_bound",
    "privacy_classes_bound",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "route_authority_shadow_only",
    "live_policy_not_promoted",
    "proof_feedback_not_hidden_truth",
    "verifier_not_bypassed",
    "tests_not_bypassed",
    "citations_not_bypassed",
    "scope_rex_not_bypassed",
    "sovereign_gate_not_bypassed",
    "no_hidden_chain",
    "no_hidden_cloud",
    "no_runtime_bytes_loaded",
    "no_model_bytes_loaded",
    "proof_search_signal_address_deterministic",
    "held_out_route_success_bound",
    "verifier_alignment_bound",
    "answer_packet_coverage_bound",
    "calibration_error_bound",
    "proof_token_budget_bound",
    "metadata_bound",
    "beats_proof_feature_baseline",
    "beats_route_distillation_only_baseline",
    "beats_no_proof_feedback_baseline",
    "duplicate_fixture_rejected",
    "duplicate_signal_rejected",
    "missing_premise_rejected",
    "missing_proof_state_rejected",
    "missing_tactic_trace_rejected",
    "missing_verifier_status_rejected",
    "invalid_verifier_status_rejected",
    "missing_failure_signature_rejected",
    "missing_repair_hint_rejected",
    "missing_route_feature_rejected",
    "missing_test_ref_rejected",
    "missing_citation_ref_rejected",
    "missing_scope_rex_rejected",
    "missing_sovereign_gate_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "hidden_truth_authority_rejected",
    "verifier_bypass_rejected",
    "test_bypass_rejected",
    "citation_bypass_rejected",
    "scope_rex_bypass_rejected",
    "sovereign_gate_bypass_rejected",
    "hidden_live_authority_rejected",
    "live_policy_promotion_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_source_rejected",
    "runtime_bytes_rejected",
    "model_bytes_rejected",
    "incompatible_fence_rejected",
    "invalid_privacy_rejected",
    "proof_feature_baseline_unbeaten_rejected",
    "route_distillation_baseline_unbeaten_rejected",
    "no_proof_feedback_baseline_unbeaten_rejected",
    "calibration_error_too_high_rejected",
    "status_diversity_missing_rejected",
    "route_feature_diversity_missing_rejected",
    "metadata_budget_rejected",
    "proof_token_budget_rejected",
    "fixture_count",
    "signal_count",
    "train_case_count",
    "held_out_case_count",
    "status_kind_count",
    "route_feature_kind_count",
    "max_proof_tokens",
    "max_signal_metadata_bytes",
    "held_out_route_success_bps",
    "verifier_alignment_bps",
    "answer_packet_coverage_bps",
    "calibration_error_bps",
    "proof_feature_baseline_bps",
    "route_distillation_only_baseline_bps",
    "no_proof_feedback_baseline_bps",
    "proof_search_signal_address",
];

#[derive(Clone)]
// UAS: uas:proof-search-signal:case
// Plane: Controller + Verification
// Residency: metadata-only proof route signal; no proof engine or model bytes load.
struct ProofSearchSignalCase {
    signal_id: String,
    theorem_or_claim_id: String,
    mission_id: String,
    premise_refs: Vec<String>,
    proof_state_hash: String,
    tactic_trace_ref: String,
    verifier_status: String,
    failure_signature: String,
    repair_hint: String,
    route_feature_label: String,
    test_result_ref: String,
    citation_ref: String,
    scope_rex_ref: String,
    sovereign_gate_ref: String,
    compatibility_fence: String,
    privacy_class: String,
    rollback_handle: String,
    run_event_log_ref: String,
    answer_packet_ref: String,
    split: String,
    proof_tokens: u64,
    signal_metadata_bytes: u64,
    hidden_truth_authority: bool,
    verifier_bypassed: bool,
    tests_bypassed: bool,
    citations_bypassed: bool,
    scope_rex_bypassed: bool,
    sovereign_gate_bypassed: bool,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    runtime_bytes_loaded: u64,
    model_bytes_loaded: u64,
}

#[derive(Clone)]
// UAS: uas:proof-search-signal:fixture
// Plane: Controller + Verification
// Residency: metadata-only route-feedback proof.
struct ProofSearchSignalFixture {
    fixture_id: String,
    upstream_route_distillation_ref: String,
    feature_schema_ref: String,
    shadow_policy_ref: String,
    held_out_route_success_bps: u64,
    verifier_alignment_bps: u64,
    answer_packet_coverage_bps: u64,
    calibration_error_bps: u64,
    proof_feature_baseline_bps: u64,
    route_distillation_only_baseline_bps: u64,
    no_proof_feedback_baseline_bps: u64,
    fixture_metadata_bytes: u64,
    route_authority: String,
    live_policy_promoted: bool,
    hidden_truth_authority: bool,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    runtime_bytes_loaded: u64,
    model_bytes_loaded: u64,
    signals: Vec<ProofSearchSignalCase>,
}

#[derive(Default, Clone, Copy)]
// UAS: uas:proof-search-signal:metrics
// Plane: Verification
// Residency: metadata-only route-feature summary.
struct ProofSearchSignalMetrics {
    fixture_count: u64,
    signal_count: u64,
    train_case_count: u64,
    held_out_case_count: u64,
    status_kind_count: u64,
    route_feature_kind_count: u64,
    max_proof_tokens: u64,
    max_signal_metadata_bytes: u64,
    held_out_route_success_bps: u64,
    verifier_alignment_bps: u64,
    answer_packet_coverage_bps: u64,
    calibration_error_bps: u64,
    proof_feature_baseline_bps: u64,
    route_distillation_only_baseline_bps: u64,
    no_proof_feedback_baseline_bps: u64,
}

#[derive(Debug, Eq, PartialEq)]
// UAS: uas:proof-search-signal:error
// Plane: Verification
// Residency: metadata-only rejection reason.
enum ProofSearchSignalError {
    MissingFixture,
    DuplicateFixture,
    MissingFixtureId,
    MissingUpstreamRouteDistillation,
    MissingFeatureSchema,
    MissingShadowPolicy,
    MissingSignal,
    DuplicateSignal,
    MissingSignalId,
    MissingClaimId,
    MissingMissionId,
    MissingPremise,
    MissingProofStateHash,
    MissingTacticTrace,
    MissingVerifierStatus,
    InvalidVerifierStatus,
    MissingFailureSignature,
    MissingRepairHint,
    MissingRouteFeatureLabel,
    InvalidRouteFeatureLabel,
    MissingTestRef,
    MissingCitationRef,
    MissingScopeRex,
    MissingSovereignGate,
    MissingCompatibilityFence,
    IncompatibleFence,
    InvalidPrivacyClass,
    MissingRollback,
    MissingRunEventLog,
    MissingAnswerPacket,
    HiddenTruthAuthority,
    VerifierBypass,
    TestBypass,
    CitationBypass,
    ScopeRexBypass,
    SovereignGateBypass,
    HiddenLiveAuthority,
    LivePolicyPromotion,
    HiddenChainExposure,
    CloudSource,
    RuntimeBytesLoaded,
    ModelBytesLoaded,
    MissingTrainSplit,
    MissingHeldOutSplit,
    HeldOutSuccessTooLow,
    VerifierAlignmentTooLow,
    AnswerPacketCoverageTooLow,
    CalibrationErrorTooHigh,
    ProofFeatureBaselineUnbeaten,
    RouteDistillationBaselineUnbeaten,
    NoProofFeedbackBaselineUnbeaten,
    StatusDiversityTooLow,
    RouteFeatureDiversityTooLow,
    MetadataBudgetExceeded,
    ProofTokenBudgetExceeded,
}

impl std::fmt::Display for ProofSearchSignalError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for ProofSearchSignalError {}

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
            eprintln!("failed to create artifact: {error}");
            return std::process::ExitCode::from(2);
        }
    };
    if let Err(error) = write_artifact(&mut file, &artifact) {
        eprintln!("failed to write artifact: {error}");
        return std::process::ExitCode::from(2);
    }

    let signal_count = artifact
        .measurements
        .get("signal_count")
        .and_then(|m| m.value.as_u64())
        .unwrap_or(0);
    let held_out_route_success_bps = artifact
        .measurements
        .get("held_out_route_success_bps")
        .and_then(|m| m.value.as_u64())
        .unwrap_or(0);
    let proof_address = artifact
        .measurements
        .get("proof_search_signal_address")
        .and_then(|m| m.value.as_str())
        .unwrap_or("unknown");
    println!(
        "{FALSIFIER_ID}: overall_pass={} signal_count={} held_out_route_success_bps={} proof_search_signal_address={proof_address:?} artifact={RESULT}",
        artifact.overall_pass, signal_count, held_out_route_success_bps
    );
    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact() -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, String> {
    let fixtures = fixture_proof_search_signals();
    let registry =
        ProofSearchSignalRegistry::new(fixtures.clone()).map_err(|error| error.to_string())?;
    let metrics = registry.metrics();
    let proof_address = registry.proof_search_signal_address();

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "upstream_route_distillation_tournament_pass",
        upstream_artifact_pass(UPSTREAM_ROUTE_DISTILLATION),
    );

    for (name, pass) in registry.axis_bools(&proof_address) {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            pass,
        );
    }
    for (name, pass) in invalid_fixture_axes(&fixtures) {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            pass,
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
        "signal_count",
        metrics.signal_count,
        12,
        "signal",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "train_case_count",
        metrics.train_case_count,
        6,
        "case",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_case_count",
        metrics.held_out_case_count,
        6,
        "case",
    );
    add_u64_gte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "status_kind_count",
        metrics.status_kind_count,
        MIN_STATUS_KIND_COUNT,
        "status",
    );
    add_u64_gte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_feature_kind_count",
        metrics.route_feature_kind_count,
        MIN_ROUTE_FEATURE_KIND_COUNT,
        "feature",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_proof_tokens",
        metrics.max_proof_tokens,
        MAX_PROOF_TOKENS,
        "token",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_signal_metadata_bytes",
        metrics.max_signal_metadata_bytes,
        MAX_SIGNAL_METADATA_BYTES,
        "bytes",
    );
    add_u64_gte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_route_success_bps",
        metrics.held_out_route_success_bps,
        MIN_HELD_OUT_ROUTE_SUCCESS_BPS,
        "bps",
    );
    add_u64_gte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_alignment_bps",
        metrics.verifier_alignment_bps,
        MIN_VERIFIER_ALIGNMENT_BPS,
        "bps",
    );
    add_u64_gte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "answer_packet_coverage_bps",
        metrics.answer_packet_coverage_bps,
        MIN_ANSWER_PACKET_COVERAGE_BPS,
        "bps",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "calibration_error_bps",
        metrics.calibration_error_bps,
        MAX_CALIBRATION_ERROR_BPS,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "proof_feature_baseline_bps",
        metrics.proof_feature_baseline_bps,
        metrics.held_out_route_success_bps,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_distillation_only_baseline_bps",
        metrics.route_distillation_only_baseline_bps,
        metrics.held_out_route_success_bps,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_proof_feedback_baseline_bps",
        metrics.no_proof_feedback_baseline_bps,
        metrics.held_out_route_success_bps,
        "bps",
    );
    add_label_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "proof_search_signal_address",
        &proof_address,
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
        anomalies: vec![serde_json::json!({
            "kind": "metadata_only_scope",
            "detail": "ProofSearchSignal proves route-feedback shape and rejection behavior only; it does not run Lean, mutate live route policy, wake sparse units, or promote local model / 70B runtime claims."
        })],
        notes: "metadata-only Meta Control witness; Lean/proof pass, fail, repair, and abstain outcomes become explicit route features with premise refs, proof-state hashes, tactic traces, test/citation/SCOPE-Rex/SovereignGate checks, rollback, RunEventLog, AnswerPacket, no-hidden-truth, no-bypass, no-cloud, and zero-runtime/model-byte guards; L1 only, not live proof route authority".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:proof-search-signal:registry
// Plane: Controller + Verification
// Residency: metadata-only registry; validates proof-feedback signals before artifact emission.
struct ProofSearchSignalRegistry {
    fixtures: Vec<ProofSearchSignalFixture>,
}

impl ProofSearchSignalRegistry {
    fn new(fixtures: Vec<ProofSearchSignalFixture>) -> Result<Self, ProofSearchSignalError> {
        validate_fixtures(&fixtures)?;
        Ok(Self { fixtures })
    }

    fn metrics(&self) -> ProofSearchSignalMetrics {
        let mut metrics = ProofSearchSignalMetrics {
            fixture_count: self.fixtures.len() as u64,
            held_out_route_success_bps: u64::MAX,
            verifier_alignment_bps: u64::MAX,
            answer_packet_coverage_bps: u64::MAX,
            ..ProofSearchSignalMetrics::default()
        };
        let mut status_kinds = BTreeSet::new();
        let mut route_feature_kinds = BTreeSet::new();
        for fixture in &self.fixtures {
            metrics.held_out_route_success_bps = metrics
                .held_out_route_success_bps
                .min(fixture.held_out_route_success_bps);
            metrics.verifier_alignment_bps = metrics
                .verifier_alignment_bps
                .min(fixture.verifier_alignment_bps);
            metrics.answer_packet_coverage_bps = metrics
                .answer_packet_coverage_bps
                .min(fixture.answer_packet_coverage_bps);
            metrics.calibration_error_bps = metrics
                .calibration_error_bps
                .max(fixture.calibration_error_bps);
            metrics.proof_feature_baseline_bps = metrics
                .proof_feature_baseline_bps
                .max(fixture.proof_feature_baseline_bps);
            metrics.route_distillation_only_baseline_bps = metrics
                .route_distillation_only_baseline_bps
                .max(fixture.route_distillation_only_baseline_bps);
            metrics.no_proof_feedback_baseline_bps = metrics
                .no_proof_feedback_baseline_bps
                .max(fixture.no_proof_feedback_baseline_bps);
            metrics.max_signal_metadata_bytes = metrics
                .max_signal_metadata_bytes
                .max(fixture.fixture_metadata_bytes);
            for signal in &fixture.signals {
                metrics.signal_count += 1;
                metrics.max_proof_tokens = metrics.max_proof_tokens.max(signal.proof_tokens);
                metrics.max_signal_metadata_bytes = metrics
                    .max_signal_metadata_bytes
                    .max(signal.signal_metadata_bytes);
                status_kinds.insert(signal.verifier_status.as_str());
                route_feature_kinds.insert(signal.route_feature_label.as_str());
                match signal.split.as_str() {
                    "train" => metrics.train_case_count += 1,
                    "held_out" => metrics.held_out_case_count += 1,
                    _ => {}
                }
            }
        }
        metrics.status_kind_count = status_kinds.len() as u64;
        metrics.route_feature_kind_count = route_feature_kinds.len() as u64;
        metrics
    }

    fn axis_bools(&self, proof_address: &str) -> Vec<(&'static str, bool)> {
        let metrics = self.metrics();
        vec![
            (
                "proof_search_signal_fixture_present",
                !self.fixtures.is_empty(),
            ),
            (
                "fixture_ids_bound",
                self.fixtures
                    .iter()
                    .all(|fixture| !fixture.fixture_id.is_empty()),
            ),
            (
                "feature_schema_refs_bound",
                self.fixtures
                    .iter()
                    .all(|fixture| !fixture.feature_schema_ref.is_empty()),
            ),
            (
                "shadow_policy_refs_bound",
                self.fixtures
                    .iter()
                    .all(|fixture| !fixture.shadow_policy_ref.is_empty()),
            ),
            (
                "signal_ids_bound",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| !signal.signal_id.is_empty()),
            ),
            (
                "claim_ids_bound",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| !signal.theorem_or_claim_id.is_empty()),
            ),
            (
                "mission_ids_bound",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| !signal.mission_id.is_empty()),
            ),
            (
                "premise_refs_bound",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| {
                        !signal.premise_refs.is_empty()
                            && signal
                                .premise_refs
                                .iter()
                                .all(|premise| !premise.is_empty())
                    }),
            ),
            (
                "proof_state_hashes_bound",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| !signal.proof_state_hash.is_empty()),
            ),
            (
                "tactic_trace_refs_bound",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| !signal.tactic_trace_ref.is_empty()),
            ),
            (
                "verifier_status_bound",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| valid_verifier_status(&signal.verifier_status)),
            ),
            ("pass_status_bound", self.has_status("pass")),
            ("fail_status_bound", self.has_status("fail")),
            ("repair_status_bound", self.has_status("repair")),
            ("abstain_status_bound", self.has_status("abstain")),
            (
                "failure_signatures_bound",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| {
                        signal.verifier_status == "pass" || !signal.failure_signature.is_empty()
                    }),
            ),
            (
                "repair_hints_bound",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| {
                        signal.verifier_status != "repair" || !signal.repair_hint.is_empty()
                    }),
            ),
            (
                "route_feature_labels_bound",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| valid_route_feature_label(&signal.route_feature_label)),
            ),
            (
                "test_refs_bound",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| !signal.test_result_ref.is_empty()),
            ),
            (
                "citation_refs_bound",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| !signal.citation_ref.is_empty()),
            ),
            (
                "scope_rex_refs_bound",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| !signal.scope_rex_ref.is_empty()),
            ),
            (
                "sovereign_gate_refs_bound",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| !signal.sovereign_gate_ref.is_empty()),
            ),
            (
                "compatibility_fence_bound",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| {
                        !signal.compatibility_fence.is_empty()
                            && signal.compatibility_fence == CURRENT_FENCE
                    }),
            ),
            (
                "privacy_classes_bound",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| valid_privacy_class(&signal.privacy_class)),
            ),
            (
                "rollback_bound",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| !signal.rollback_handle.is_empty()),
            ),
            (
                "run_event_log_bound",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| !signal.run_event_log_ref.is_empty()),
            ),
            (
                "answer_packet_ref_bound",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| !signal.answer_packet_ref.is_empty()),
            ),
            (
                "route_authority_shadow_only",
                self.fixtures
                    .iter()
                    .all(|fixture| fixture.route_authority == "shadow_only"),
            ),
            (
                "live_policy_not_promoted",
                self.fixtures
                    .iter()
                    .all(|fixture| !fixture.live_policy_promoted),
            ),
            (
                "proof_feedback_not_hidden_truth",
                self.fixtures
                    .iter()
                    .all(|fixture| !fixture.hidden_truth_authority)
                    && self
                        .fixtures
                        .iter()
                        .flat_map(|fixture| &fixture.signals)
                        .all(|signal| !signal.hidden_truth_authority),
            ),
            (
                "verifier_not_bypassed",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| !signal.verifier_bypassed),
            ),
            (
                "tests_not_bypassed",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| !signal.tests_bypassed),
            ),
            (
                "citations_not_bypassed",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| !signal.citations_bypassed),
            ),
            (
                "scope_rex_not_bypassed",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| !signal.scope_rex_bypassed),
            ),
            (
                "sovereign_gate_not_bypassed",
                self.fixtures
                    .iter()
                    .flat_map(|fixture| &fixture.signals)
                    .all(|signal| !signal.sovereign_gate_bypassed),
            ),
            (
                "no_hidden_chain",
                self.fixtures
                    .iter()
                    .all(|fixture| !fixture.hidden_chain_exposed)
                    && self
                        .fixtures
                        .iter()
                        .flat_map(|fixture| &fixture.signals)
                        .all(|signal| !signal.hidden_chain_exposed),
            ),
            (
                "no_hidden_cloud",
                self.fixtures.iter().all(|fixture| !fixture.hidden_cloud)
                    && self
                        .fixtures
                        .iter()
                        .flat_map(|fixture| &fixture.signals)
                        .all(|signal| !signal.hidden_cloud),
            ),
            (
                "no_runtime_bytes_loaded",
                self.fixtures
                    .iter()
                    .all(|fixture| fixture.runtime_bytes_loaded == 0)
                    && self
                        .fixtures
                        .iter()
                        .flat_map(|fixture| &fixture.signals)
                        .all(|signal| signal.runtime_bytes_loaded == 0),
            ),
            (
                "no_model_bytes_loaded",
                self.fixtures
                    .iter()
                    .all(|fixture| fixture.model_bytes_loaded == 0)
                    && self
                        .fixtures
                        .iter()
                        .flat_map(|fixture| &fixture.signals)
                        .all(|signal| signal.model_bytes_loaded == 0),
            ),
            (
                "proof_search_signal_address_deterministic",
                proof_address.starts_with("uas:proof-search-signal:"),
            ),
            (
                "held_out_route_success_bound",
                metrics.held_out_route_success_bps >= MIN_HELD_OUT_ROUTE_SUCCESS_BPS,
            ),
            (
                "verifier_alignment_bound",
                metrics.verifier_alignment_bps >= MIN_VERIFIER_ALIGNMENT_BPS,
            ),
            (
                "answer_packet_coverage_bound",
                metrics.answer_packet_coverage_bps >= MIN_ANSWER_PACKET_COVERAGE_BPS,
            ),
            (
                "calibration_error_bound",
                metrics.calibration_error_bps <= MAX_CALIBRATION_ERROR_BPS,
            ),
            (
                "proof_token_budget_bound",
                metrics.max_proof_tokens <= MAX_PROOF_TOKENS,
            ),
            (
                "metadata_bound",
                metrics.max_signal_metadata_bytes <= MAX_SIGNAL_METADATA_BYTES,
            ),
            (
                "beats_proof_feature_baseline",
                metrics.proof_feature_baseline_bps < metrics.held_out_route_success_bps,
            ),
            (
                "beats_route_distillation_only_baseline",
                metrics.route_distillation_only_baseline_bps < metrics.held_out_route_success_bps,
            ),
            (
                "beats_no_proof_feedback_baseline",
                metrics.no_proof_feedback_baseline_bps < metrics.held_out_route_success_bps,
            ),
        ]
    }

    fn has_status(&self, status: &str) -> bool {
        self.fixtures
            .iter()
            .flat_map(|fixture| &fixture.signals)
            .any(|signal| signal.verifier_status == status)
    }

    fn proof_search_signal_address(&self) -> String {
        let mut rows = Vec::with_capacity(self.fixtures.len());
        for fixture in &self.fixtures {
            let mut signal_ids: Vec<&str> = fixture
                .signals
                .iter()
                .map(|signal| signal.signal_id.as_str())
                .collect();
            signal_ids.sort_unstable();
            rows.push(format!(
                "{}:{}:{}:{}:{}",
                fixture.fixture_id,
                fixture.feature_schema_ref,
                fixture.held_out_route_success_bps,
                fixture.verifier_alignment_bps,
                signal_ids.join(",")
            ));
        }
        rows.sort_unstable();
        format!(
            "uas:proof-search-signal:{}",
            sha256_hex(rows.join("|").as_bytes())
        )
    }
}

fn validate_fixtures(fixtures: &[ProofSearchSignalFixture]) -> Result<(), ProofSearchSignalError> {
    if fixtures.is_empty() {
        return Err(ProofSearchSignalError::MissingFixture);
    }
    let mut fixture_ids = BTreeSet::new();
    let mut signal_ids = BTreeSet::new();
    let mut train_count = 0_u64;
    let mut held_out_count = 0_u64;
    let mut statuses = BTreeSet::new();
    let mut route_features = BTreeSet::new();
    for fixture in fixtures {
        validate_fixture_header(fixture)?;
        if !fixture_ids.insert(fixture.fixture_id.as_str()) {
            return Err(ProofSearchSignalError::DuplicateFixture);
        }
        if fixture.signals.is_empty() {
            return Err(ProofSearchSignalError::MissingSignal);
        }
        for signal in &fixture.signals {
            validate_signal(signal)?;
            if !signal_ids.insert(signal.signal_id.as_str()) {
                return Err(ProofSearchSignalError::DuplicateSignal);
            }
            match signal.split.as_str() {
                "train" => train_count += 1,
                "held_out" => held_out_count += 1,
                _ => return Err(ProofSearchSignalError::MissingHeldOutSplit),
            }
            statuses.insert(signal.verifier_status.as_str());
            route_features.insert(signal.route_feature_label.as_str());
        }
        validate_fixture_scores(fixture)?;
    }
    if train_count == 0 {
        return Err(ProofSearchSignalError::MissingTrainSplit);
    }
    if held_out_count == 0 {
        return Err(ProofSearchSignalError::MissingHeldOutSplit);
    }
    if statuses.len() < MIN_STATUS_KIND_COUNT as usize {
        return Err(ProofSearchSignalError::StatusDiversityTooLow);
    }
    if route_features.len() < MIN_ROUTE_FEATURE_KIND_COUNT as usize {
        return Err(ProofSearchSignalError::RouteFeatureDiversityTooLow);
    }
    Ok(())
}

fn validate_fixture_header(
    fixture: &ProofSearchSignalFixture,
) -> Result<(), ProofSearchSignalError> {
    if fixture.fixture_id.is_empty() {
        return Err(ProofSearchSignalError::MissingFixtureId);
    }
    if fixture.upstream_route_distillation_ref.is_empty() {
        return Err(ProofSearchSignalError::MissingUpstreamRouteDistillation);
    }
    if fixture.feature_schema_ref.is_empty() {
        return Err(ProofSearchSignalError::MissingFeatureSchema);
    }
    if fixture.shadow_policy_ref.is_empty() {
        return Err(ProofSearchSignalError::MissingShadowPolicy);
    }
    if fixture.route_authority != "shadow_only" {
        return Err(ProofSearchSignalError::HiddenLiveAuthority);
    }
    if fixture.live_policy_promoted {
        return Err(ProofSearchSignalError::LivePolicyPromotion);
    }
    if fixture.hidden_truth_authority {
        return Err(ProofSearchSignalError::HiddenTruthAuthority);
    }
    if fixture.hidden_chain_exposed {
        return Err(ProofSearchSignalError::HiddenChainExposure);
    }
    if fixture.hidden_cloud {
        return Err(ProofSearchSignalError::CloudSource);
    }
    if fixture.runtime_bytes_loaded > 0 {
        return Err(ProofSearchSignalError::RuntimeBytesLoaded);
    }
    if fixture.model_bytes_loaded > 0 {
        return Err(ProofSearchSignalError::ModelBytesLoaded);
    }
    if fixture.fixture_metadata_bytes > MAX_SIGNAL_METADATA_BYTES {
        return Err(ProofSearchSignalError::MetadataBudgetExceeded);
    }
    Ok(())
}

fn validate_signal(signal: &ProofSearchSignalCase) -> Result<(), ProofSearchSignalError> {
    if signal.signal_id.is_empty() {
        return Err(ProofSearchSignalError::MissingSignalId);
    }
    if signal.theorem_or_claim_id.is_empty() {
        return Err(ProofSearchSignalError::MissingClaimId);
    }
    if signal.mission_id.is_empty() {
        return Err(ProofSearchSignalError::MissingMissionId);
    }
    if signal.premise_refs.is_empty()
        || signal.premise_refs.iter().any(|premise| premise.is_empty())
    {
        return Err(ProofSearchSignalError::MissingPremise);
    }
    if signal.proof_state_hash.is_empty() {
        return Err(ProofSearchSignalError::MissingProofStateHash);
    }
    if signal.tactic_trace_ref.is_empty() {
        return Err(ProofSearchSignalError::MissingTacticTrace);
    }
    if signal.verifier_status.is_empty() {
        return Err(ProofSearchSignalError::MissingVerifierStatus);
    }
    if !valid_verifier_status(&signal.verifier_status) {
        return Err(ProofSearchSignalError::InvalidVerifierStatus);
    }
    if signal.verifier_status != "pass" && signal.failure_signature.is_empty() {
        return Err(ProofSearchSignalError::MissingFailureSignature);
    }
    if signal.verifier_status == "repair" && signal.repair_hint.is_empty() {
        return Err(ProofSearchSignalError::MissingRepairHint);
    }
    if signal.route_feature_label.is_empty() {
        return Err(ProofSearchSignalError::MissingRouteFeatureLabel);
    }
    if !valid_route_feature_label(&signal.route_feature_label) {
        return Err(ProofSearchSignalError::InvalidRouteFeatureLabel);
    }
    if signal.test_result_ref.is_empty() {
        return Err(ProofSearchSignalError::MissingTestRef);
    }
    if signal.citation_ref.is_empty() {
        return Err(ProofSearchSignalError::MissingCitationRef);
    }
    if signal.scope_rex_ref.is_empty() {
        return Err(ProofSearchSignalError::MissingScopeRex);
    }
    if signal.sovereign_gate_ref.is_empty() {
        return Err(ProofSearchSignalError::MissingSovereignGate);
    }
    if signal.compatibility_fence.is_empty() {
        return Err(ProofSearchSignalError::MissingCompatibilityFence);
    }
    if signal.compatibility_fence != CURRENT_FENCE {
        return Err(ProofSearchSignalError::IncompatibleFence);
    }
    if !valid_privacy_class(&signal.privacy_class) {
        return Err(ProofSearchSignalError::InvalidPrivacyClass);
    }
    if signal.rollback_handle.is_empty() {
        return Err(ProofSearchSignalError::MissingRollback);
    }
    if signal.run_event_log_ref.is_empty() {
        return Err(ProofSearchSignalError::MissingRunEventLog);
    }
    if signal.answer_packet_ref.is_empty() {
        return Err(ProofSearchSignalError::MissingAnswerPacket);
    }
    if signal.hidden_truth_authority {
        return Err(ProofSearchSignalError::HiddenTruthAuthority);
    }
    if signal.verifier_bypassed {
        return Err(ProofSearchSignalError::VerifierBypass);
    }
    if signal.tests_bypassed {
        return Err(ProofSearchSignalError::TestBypass);
    }
    if signal.citations_bypassed {
        return Err(ProofSearchSignalError::CitationBypass);
    }
    if signal.scope_rex_bypassed {
        return Err(ProofSearchSignalError::ScopeRexBypass);
    }
    if signal.sovereign_gate_bypassed {
        return Err(ProofSearchSignalError::SovereignGateBypass);
    }
    if signal.hidden_chain_exposed {
        return Err(ProofSearchSignalError::HiddenChainExposure);
    }
    if signal.hidden_cloud {
        return Err(ProofSearchSignalError::CloudSource);
    }
    if signal.runtime_bytes_loaded > 0 {
        return Err(ProofSearchSignalError::RuntimeBytesLoaded);
    }
    if signal.model_bytes_loaded > 0 {
        return Err(ProofSearchSignalError::ModelBytesLoaded);
    }
    if signal.proof_tokens == 0 || signal.proof_tokens > MAX_PROOF_TOKENS {
        return Err(ProofSearchSignalError::ProofTokenBudgetExceeded);
    }
    if signal.signal_metadata_bytes > MAX_SIGNAL_METADATA_BYTES {
        return Err(ProofSearchSignalError::MetadataBudgetExceeded);
    }
    Ok(())
}

fn validate_fixture_scores(
    fixture: &ProofSearchSignalFixture,
) -> Result<(), ProofSearchSignalError> {
    if fixture.held_out_route_success_bps < MIN_HELD_OUT_ROUTE_SUCCESS_BPS {
        return Err(ProofSearchSignalError::HeldOutSuccessTooLow);
    }
    if fixture.verifier_alignment_bps < MIN_VERIFIER_ALIGNMENT_BPS {
        return Err(ProofSearchSignalError::VerifierAlignmentTooLow);
    }
    if fixture.answer_packet_coverage_bps < MIN_ANSWER_PACKET_COVERAGE_BPS {
        return Err(ProofSearchSignalError::AnswerPacketCoverageTooLow);
    }
    if fixture.calibration_error_bps > MAX_CALIBRATION_ERROR_BPS {
        return Err(ProofSearchSignalError::CalibrationErrorTooHigh);
    }
    if fixture.proof_feature_baseline_bps >= fixture.held_out_route_success_bps {
        return Err(ProofSearchSignalError::ProofFeatureBaselineUnbeaten);
    }
    if fixture.route_distillation_only_baseline_bps >= fixture.held_out_route_success_bps {
        return Err(ProofSearchSignalError::RouteDistillationBaselineUnbeaten);
    }
    if fixture.no_proof_feedback_baseline_bps >= fixture.held_out_route_success_bps {
        return Err(ProofSearchSignalError::NoProofFeedbackBaselineUnbeaten);
    }
    Ok(())
}

fn valid_verifier_status(status: &str) -> bool {
    matches!(status, "pass" | "fail" | "repair" | "abstain")
}

fn valid_route_feature_label(label: &str) -> bool {
    matches!(
        label,
        "retrieve" | "repair" | "deeper_model" | "verifier" | "abstain"
    )
}

fn valid_privacy_class(value: &str) -> bool {
    matches!(value, "local_private" | "local_sensitive" | "proof_public")
}

fn invalid_fixture_axes(fixtures: &[ProofSearchSignalFixture]) -> Vec<(&'static str, bool)> {
    let cases: Vec<(
        &'static str,
        fn(&mut Vec<ProofSearchSignalFixture>),
        ProofSearchSignalError,
    )> = vec![
        (
            "duplicate_fixture_rejected",
            |fixtures| fixtures.push(fixtures[0].clone()),
            ProofSearchSignalError::DuplicateFixture,
        ),
        (
            "duplicate_signal_rejected",
            |fixtures| {
                let duplicate = fixtures[0].signals[0].clone();
                fixtures[0].signals.push(duplicate);
            },
            ProofSearchSignalError::DuplicateSignal,
        ),
        (
            "missing_premise_rejected",
            |fixtures| fixtures[0].signals[0].premise_refs.clear(),
            ProofSearchSignalError::MissingPremise,
        ),
        (
            "missing_proof_state_rejected",
            |fixtures| fixtures[0].signals[0].proof_state_hash.clear(),
            ProofSearchSignalError::MissingProofStateHash,
        ),
        (
            "missing_tactic_trace_rejected",
            |fixtures| fixtures[0].signals[0].tactic_trace_ref.clear(),
            ProofSearchSignalError::MissingTacticTrace,
        ),
        (
            "missing_verifier_status_rejected",
            |fixtures| fixtures[0].signals[0].verifier_status.clear(),
            ProofSearchSignalError::MissingVerifierStatus,
        ),
        (
            "invalid_verifier_status_rejected",
            |fixtures| fixtures[0].signals[0].verifier_status = "unchecked".to_string(),
            ProofSearchSignalError::InvalidVerifierStatus,
        ),
        (
            "missing_failure_signature_rejected",
            |fixtures| fixtures[0].signals[1].failure_signature.clear(),
            ProofSearchSignalError::MissingFailureSignature,
        ),
        (
            "missing_repair_hint_rejected",
            |fixtures| fixtures[0].signals[2].repair_hint.clear(),
            ProofSearchSignalError::MissingRepairHint,
        ),
        (
            "missing_route_feature_rejected",
            |fixtures| fixtures[0].signals[0].route_feature_label.clear(),
            ProofSearchSignalError::MissingRouteFeatureLabel,
        ),
        (
            "missing_test_ref_rejected",
            |fixtures| fixtures[0].signals[0].test_result_ref.clear(),
            ProofSearchSignalError::MissingTestRef,
        ),
        (
            "missing_citation_ref_rejected",
            |fixtures| fixtures[0].signals[0].citation_ref.clear(),
            ProofSearchSignalError::MissingCitationRef,
        ),
        (
            "missing_scope_rex_rejected",
            |fixtures| fixtures[0].signals[0].scope_rex_ref.clear(),
            ProofSearchSignalError::MissingScopeRex,
        ),
        (
            "missing_sovereign_gate_rejected",
            |fixtures| fixtures[0].signals[0].sovereign_gate_ref.clear(),
            ProofSearchSignalError::MissingSovereignGate,
        ),
        (
            "missing_rollback_rejected",
            |fixtures| fixtures[0].signals[0].rollback_handle.clear(),
            ProofSearchSignalError::MissingRollback,
        ),
        (
            "missing_run_event_log_rejected",
            |fixtures| fixtures[0].signals[0].run_event_log_ref.clear(),
            ProofSearchSignalError::MissingRunEventLog,
        ),
        (
            "missing_answer_packet_rejected",
            |fixtures| fixtures[0].signals[0].answer_packet_ref.clear(),
            ProofSearchSignalError::MissingAnswerPacket,
        ),
        (
            "hidden_truth_authority_rejected",
            |fixtures| fixtures[0].signals[0].hidden_truth_authority = true,
            ProofSearchSignalError::HiddenTruthAuthority,
        ),
        (
            "verifier_bypass_rejected",
            |fixtures| fixtures[0].signals[0].verifier_bypassed = true,
            ProofSearchSignalError::VerifierBypass,
        ),
        (
            "test_bypass_rejected",
            |fixtures| fixtures[0].signals[0].tests_bypassed = true,
            ProofSearchSignalError::TestBypass,
        ),
        (
            "citation_bypass_rejected",
            |fixtures| fixtures[0].signals[0].citations_bypassed = true,
            ProofSearchSignalError::CitationBypass,
        ),
        (
            "scope_rex_bypass_rejected",
            |fixtures| fixtures[0].signals[0].scope_rex_bypassed = true,
            ProofSearchSignalError::ScopeRexBypass,
        ),
        (
            "sovereign_gate_bypass_rejected",
            |fixtures| fixtures[0].signals[0].sovereign_gate_bypassed = true,
            ProofSearchSignalError::SovereignGateBypass,
        ),
        (
            "hidden_live_authority_rejected",
            |fixtures| fixtures[0].route_authority = "live_route".to_string(),
            ProofSearchSignalError::HiddenLiveAuthority,
        ),
        (
            "live_policy_promotion_rejected",
            |fixtures| fixtures[0].live_policy_promoted = true,
            ProofSearchSignalError::LivePolicyPromotion,
        ),
        (
            "hidden_chain_exposure_rejected",
            |fixtures| fixtures[0].signals[0].hidden_chain_exposed = true,
            ProofSearchSignalError::HiddenChainExposure,
        ),
        (
            "cloud_source_rejected",
            |fixtures| fixtures[0].signals[0].hidden_cloud = true,
            ProofSearchSignalError::CloudSource,
        ),
        (
            "runtime_bytes_rejected",
            |fixtures| fixtures[0].signals[0].runtime_bytes_loaded = 1,
            ProofSearchSignalError::RuntimeBytesLoaded,
        ),
        (
            "model_bytes_rejected",
            |fixtures| fixtures[0].signals[0].model_bytes_loaded = 1,
            ProofSearchSignalError::ModelBytesLoaded,
        ),
        (
            "incompatible_fence_rejected",
            |fixtures| fixtures[0].signals[0].compatibility_fence = "fence:other".to_string(),
            ProofSearchSignalError::IncompatibleFence,
        ),
        (
            "invalid_privacy_rejected",
            |fixtures| fixtures[0].signals[0].privacy_class = "public_cloud".to_string(),
            ProofSearchSignalError::InvalidPrivacyClass,
        ),
        (
            "proof_feature_baseline_unbeaten_rejected",
            |fixtures| {
                fixtures[0].proof_feature_baseline_bps = fixtures[0].held_out_route_success_bps
            },
            ProofSearchSignalError::ProofFeatureBaselineUnbeaten,
        ),
        (
            "route_distillation_baseline_unbeaten_rejected",
            |fixtures| {
                fixtures[0].route_distillation_only_baseline_bps =
                    fixtures[0].held_out_route_success_bps
            },
            ProofSearchSignalError::RouteDistillationBaselineUnbeaten,
        ),
        (
            "no_proof_feedback_baseline_unbeaten_rejected",
            |fixtures| {
                fixtures[0].no_proof_feedback_baseline_bps = fixtures[0].held_out_route_success_bps
            },
            ProofSearchSignalError::NoProofFeedbackBaselineUnbeaten,
        ),
        (
            "calibration_error_too_high_rejected",
            |fixtures| fixtures[0].calibration_error_bps = MAX_CALIBRATION_ERROR_BPS + 1,
            ProofSearchSignalError::CalibrationErrorTooHigh,
        ),
        (
            "status_diversity_missing_rejected",
            |fixtures| {
                for signal in &mut fixtures[0].signals {
                    signal.verifier_status = "pass".to_string();
                    signal.failure_signature.clear();
                    signal.repair_hint.clear();
                }
                for signal in &mut fixtures[1].signals {
                    signal.verifier_status = "pass".to_string();
                    signal.failure_signature.clear();
                    signal.repair_hint.clear();
                }
            },
            ProofSearchSignalError::StatusDiversityTooLow,
        ),
        (
            "route_feature_diversity_missing_rejected",
            |fixtures| {
                for signal in &mut fixtures[0].signals {
                    signal.route_feature_label = "retrieve".to_string();
                }
                for signal in &mut fixtures[1].signals {
                    signal.route_feature_label = "retrieve".to_string();
                }
            },
            ProofSearchSignalError::RouteFeatureDiversityTooLow,
        ),
        (
            "metadata_budget_rejected",
            |fixtures| fixtures[0].signals[0].signal_metadata_bytes = MAX_SIGNAL_METADATA_BYTES + 1,
            ProofSearchSignalError::MetadataBudgetExceeded,
        ),
        (
            "proof_token_budget_rejected",
            |fixtures| fixtures[0].signals[0].proof_tokens = MAX_PROOF_TOKENS + 1,
            ProofSearchSignalError::ProofTokenBudgetExceeded,
        ),
    ];
    cases
        .into_iter()
        .map(|(axis, mutate, expected)| {
            let mut candidate = fixtures.to_vec();
            mutate(&mut candidate);
            (
                axis,
                validate_fixtures(&candidate).is_err_and(|error| error == expected),
            )
        })
        .collect()
}

fn fixture_proof_search_signals() -> Vec<ProofSearchSignalFixture> {
    vec![
        ProofSearchSignalFixture {
            fixture_id: "proof-signal:local-summary:v1".to_string(),
            upstream_route_distillation_ref: UPSTREAM_ROUTE_DISTILLATION.to_string(),
            feature_schema_ref: "schema:proof-search-signal:v1".to_string(),
            shadow_policy_ref: "shadow-policy:proof-feedback:local-summary".to_string(),
            held_out_route_success_bps: 9_100,
            verifier_alignment_bps: 9_300,
            answer_packet_coverage_bps: 10_000,
            calibration_error_bps: 620,
            proof_feature_baseline_bps: 8_400,
            route_distillation_only_baseline_bps: 8_600,
            no_proof_feedback_baseline_bps: 7_200,
            fixture_metadata_bytes: 196_000,
            route_authority: "shadow_only".to_string(),
            live_policy_promoted: false,
            hidden_truth_authority: false,
            hidden_chain_exposed: false,
            hidden_cloud: false,
            runtime_bytes_loaded: 0,
            model_bytes_loaded: 0,
            signals: vec![
                signal(
                    "pss:summary:pass",
                    "claim:summary:cites-all-sources",
                    "mission:summary-proof",
                    &["premise:source:a", "premise:source:b"],
                    "proof-state:sha256:summary-pass",
                    "lean-trace:summary:pass",
                    "pass",
                    "",
                    "",
                    "verifier",
                    "held_out",
                    15_000,
                ),
                signal(
                    "pss:summary:fail",
                    "claim:summary:unsupported-causal-link",
                    "mission:summary-proof",
                    &["premise:source:c"],
                    "proof-state:sha256:summary-fail",
                    "lean-trace:summary:fail",
                    "fail",
                    "missing-premise:causal-link",
                    "",
                    "retrieve",
                    "train",
                    18_000,
                ),
                signal(
                    "pss:summary:repair",
                    "claim:summary:ambiguous-quote",
                    "mission:summary-proof",
                    &["premise:quote:a"],
                    "proof-state:sha256:summary-repair",
                    "lean-trace:summary:repair",
                    "repair",
                    "tactic-failed:rewrite",
                    "retrieve premise quote span then retry exact citation",
                    "repair",
                    "held_out",
                    20_000,
                ),
                signal(
                    "pss:summary:abstain",
                    "claim:summary:scope-too-wide",
                    "mission:summary-proof",
                    &["premise:scope:missing"],
                    "proof-state:sha256:summary-abstain",
                    "lean-trace:summary:abstain",
                    "abstain",
                    "state-entropy:high",
                    "",
                    "abstain",
                    "train",
                    14_000,
                ),
                signal(
                    "pss:summary:deeper",
                    "claim:summary:multi-hop",
                    "mission:summary-proof",
                    &["premise:source:d", "premise:source:e"],
                    "proof-state:sha256:summary-deeper",
                    "lean-trace:summary:deeper",
                    "repair",
                    "search-depth:insufficient",
                    "wake deeper model after citation expansion",
                    "deeper_model",
                    "held_out",
                    22_000,
                ),
                signal(
                    "pss:summary:premise",
                    "claim:summary:needs-lemma",
                    "mission:summary-proof",
                    &["premise:lemma:summary"],
                    "proof-state:sha256:summary-premise",
                    "lean-trace:summary:premise",
                    "fail",
                    "missing-premise:lemma",
                    "",
                    "retrieve",
                    "train",
                    17_000,
                ),
            ],
        },
        ProofSearchSignalFixture {
            fixture_id: "proof-signal:code-repair:v1".to_string(),
            upstream_route_distillation_ref: UPSTREAM_ROUTE_DISTILLATION.to_string(),
            feature_schema_ref: "schema:proof-search-signal:v1".to_string(),
            shadow_policy_ref: "shadow-policy:proof-feedback:code-repair".to_string(),
            held_out_route_success_bps: 9_000,
            verifier_alignment_bps: 9_200,
            answer_packet_coverage_bps: 10_000,
            calibration_error_bps: 700,
            proof_feature_baseline_bps: 8_500,
            route_distillation_only_baseline_bps: 8_700,
            no_proof_feedback_baseline_bps: 7_400,
            fixture_metadata_bytes: 210_000,
            route_authority: "shadow_only".to_string(),
            live_policy_promoted: false,
            hidden_truth_authority: false,
            hidden_chain_exposed: false,
            hidden_cloud: false,
            runtime_bytes_loaded: 0,
            model_bytes_loaded: 0,
            signals: vec![
                signal(
                    "pss:code:pass",
                    "claim:code:ffi-layout-preserved",
                    "mission:code-proof",
                    &["premise:repr-c", "premise:swift-layout"],
                    "proof-state:sha256:code-pass",
                    "lean-trace:code:pass",
                    "pass",
                    "",
                    "",
                    "verifier",
                    "train",
                    16_000,
                ),
                signal(
                    "pss:code:fail",
                    "claim:code:unsafe-boundary",
                    "mission:code-proof",
                    &["premise:unsafe:block"],
                    "proof-state:sha256:code-fail",
                    "lean-trace:code:fail",
                    "fail",
                    "unsafe-proof-missing",
                    "",
                    "verifier",
                    "held_out",
                    19_000,
                ),
                signal(
                    "pss:code:repair",
                    "claim:code:rollback-path",
                    "mission:code-proof",
                    &["premise:rollback:state"],
                    "proof-state:sha256:code-repair",
                    "lean-trace:code:repair",
                    "repair",
                    "rollback-proof-gap",
                    "add rollback witness before route promotion",
                    "repair",
                    "train",
                    21_000,
                ),
                signal(
                    "pss:code:abstain",
                    "claim:code:autogenous-kernel",
                    "mission:code-proof",
                    &["premise:kernel:panic-risk"],
                    "proof-state:sha256:code-abstain",
                    "lean-trace:code:abstain",
                    "abstain",
                    "kernel-panic-class-risk",
                    "",
                    "abstain",
                    "held_out",
                    13_000,
                ),
                signal(
                    "pss:code:retrieve",
                    "claim:code:missing-citation",
                    "mission:code-proof",
                    &["premise:test:unknown"],
                    "proof-state:sha256:code-retrieve",
                    "lean-trace:code:retrieve",
                    "fail",
                    "missing-test-evidence",
                    "",
                    "retrieve",
                    "held_out",
                    18_000,
                ),
                signal(
                    "pss:code:deeper",
                    "claim:code:multi-module-invariant",
                    "mission:code-proof",
                    &["premise:module:a", "premise:module:b"],
                    "proof-state:sha256:code-deeper",
                    "lean-trace:code:deeper",
                    "repair",
                    "invariant-cross-module",
                    "wake deeper route with proof harness card",
                    "deeper_model",
                    "train",
                    23_000,
                ),
            ],
        },
    ]
}

fn signal(
    signal_id: &str,
    theorem_or_claim_id: &str,
    mission_id: &str,
    premise_refs: &[&str],
    proof_state_hash: &str,
    tactic_trace_ref: &str,
    verifier_status: &str,
    failure_signature: &str,
    repair_hint: &str,
    route_feature_label: &str,
    split: &str,
    proof_tokens: u64,
) -> ProofSearchSignalCase {
    ProofSearchSignalCase {
        signal_id: signal_id.to_string(),
        theorem_or_claim_id: theorem_or_claim_id.to_string(),
        mission_id: mission_id.to_string(),
        premise_refs: premise_refs
            .iter()
            .map(|premise| (*premise).to_string())
            .collect(),
        proof_state_hash: proof_state_hash.to_string(),
        tactic_trace_ref: tactic_trace_ref.to_string(),
        verifier_status: verifier_status.to_string(),
        failure_signature: failure_signature.to_string(),
        repair_hint: repair_hint.to_string(),
        route_feature_label: route_feature_label.to_string(),
        test_result_ref: format!("test-result:{signal_id}"),
        citation_ref: format!("citation:{signal_id}"),
        scope_rex_ref: format!("scope-rex:{signal_id}"),
        sovereign_gate_ref: format!("sovereign-gate:{signal_id}"),
        compatibility_fence: CURRENT_FENCE.to_string(),
        privacy_class: "local_private".to_string(),
        rollback_handle: format!("rollback:{signal_id}"),
        run_event_log_ref: format!("runevent:{signal_id}"),
        answer_packet_ref: format!("answer-packet:{signal_id}"),
        split: split.to_string(),
        proof_tokens,
        signal_metadata_bytes: 42_000,
        hidden_truth_authority: false,
        verifier_bypassed: false,
        tests_bypassed: false,
        citations_bypassed: false,
        scope_rex_bypassed: false,
        sovereign_gate_bypassed: false,
        hidden_chain_exposed: false,
        hidden_cloud: false,
        runtime_bytes_loaded: 0,
        model_bytes_loaded: 0,
    }
}

fn upstream_artifact_pass(path: &str) -> bool {
    std::fs::read_to_string(path)
        .ok()
        .and_then(|content| serde_json::from_str::<serde_json::Value>(&content).ok())
        .and_then(|artifact| {
            artifact
                .get("overall_pass")
                .and_then(|value| value.as_bool())
        })
        .unwrap_or(false)
}

fn add_u64_gte_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: u64,
    min_value: u64,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::json!(value),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: ">=".to_string(),
            value: serde_json::Value::from(min_value),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), value >= min_value);
}

fn add_u64_lte_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: u64,
    max_value: u64,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::json!(value),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "<=".to_string(),
            value: serde_json::Value::from(max_value),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), value <= max_value);
}

fn add_u64_lt_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: u64,
    max_exclusive: u64,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::json!(value),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "<".to_string(),
            value: serde_json::Value::from(max_exclusive),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), value < max_exclusive);
}

fn add_label_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::json!(value),
            unit: "address".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "prefix".to_string(),
            value: serde_json::Value::String("uas:proof-search-signal:".to_string()),
            unit: "address".to_string(),
        },
    );
    pass_per_axis.insert(
        name.to_string(),
        value.starts_with("uas:proof-search-signal:"),
    );
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_fixture_rejects() {
        assert_eq!(
            validate_fixtures(&[]).err(),
            Some(ProofSearchSignalError::MissingFixture)
        );
    }

    #[test]
    fn invalid_fixture_cases_reject() {
        let fixtures = fixture_proof_search_signals();
        for (axis, passed) in invalid_fixture_axes(&fixtures) {
            assert!(passed, "{axis} should reject");
        }
    }

    #[test]
    fn proof_search_signal_address_is_order_stable() {
        let registry = ProofSearchSignalRegistry::new(fixture_proof_search_signals()).unwrap();
        let address = registry.proof_search_signal_address();
        let mut reversed = fixture_proof_search_signals();
        reversed.reverse();
        for fixture in &mut reversed {
            fixture.signals.reverse();
        }
        let reversed_registry = ProofSearchSignalRegistry::new(reversed).unwrap();
        assert_eq!(address, reversed_registry.proof_search_signal_address());
    }

    #[test]
    fn artifact_contains_required_axes() {
        let artifact = build_artifact().expect("artifact builds");
        for axis in REQUIRED_AXES {
            assert!(
                artifact.measurements.contains_key(*axis),
                "missing measurement {axis}"
            );
            assert!(
                artifact.acceptance_thresholds.contains_key(*axis),
                "missing threshold {axis}"
            );
            assert!(
                artifact.pass_per_axis.contains_key(*axis),
                "missing pass axis {axis}"
            );
        }
    }
}
