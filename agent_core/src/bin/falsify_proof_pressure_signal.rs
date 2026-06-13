//! `falsify_proof_pressure_signal` -- proof/compiler pressure route witness.
//!
//! Metadata-only witness for `F-ProofPressureSignal`. It proves compiler
//! errors, tactic-state entropy, missing premises, verified-neighbor evidence,
//! and failed-attempt memory can become explicit route-pressure labels without
//! becoming hidden truth, mutating statements, bypassing governance, or waking
//! runtime/model bytes.

use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-ProofPressureSignal";
const FIXTURE_ID: &str = "proof_pressure_signal_v1";
const COMMAND: &str = "Tools/falsifiers/f_proof_pressure_signal.sh";
const RESULT: &str = "artifacts/falsifiers/proof_pressure_signal/result.json";
const UPSTREAM_PROOF_SEARCH_SIGNAL: &str =
    "artifacts/falsifiers/proof_search_signal_route_feedback/result.json";

const CURRENT_FENCE: &str = "fence:proof-pressure-signal:v1:proof-search";
const MAX_PRESSURE_TOKENS: u64 = 32_000;
const MAX_PRESSURE_METADATA_BYTES: u64 = 768 * 1024;
const MAX_TACTIC_STATE_ENTROPY_BPS: u64 = 10_000;
const MIN_STATEMENT_PRESERVATION_BPS: u64 = 9_400;
const MIN_MISSING_PREMISE_RECALL_BPS: u64 = 9_200;
const MIN_HELD_OUT_ROUTE_SUCCESS_BPS: u64 = 8_900;
const MIN_ANSWER_PACKET_COVERAGE_BPS: u64 = 10_000;
const MAX_CALIBRATION_ERROR_BPS: u64 = 850;
const MIN_COMPILER_ERROR_KIND_COUNT: u64 = 5;
const MIN_ROUTE_PRESSURE_KIND_COUNT: u64 = 5;

#[cfg(test)]
const REQUIRED_AXES: &[&str] = &[
    "upstream_proof_search_signal_route_feedback_pass",
    "proof_pressure_signal_fixture_present",
    "fixture_ids_bound",
    "pressure_schema_refs_bound",
    "shadow_policy_refs_bound",
    "pressure_signal_ids_bound",
    "claim_refs_bound",
    "mission_ids_bound",
    "proof_search_signal_refs_bound",
    "statement_preservation_scores_bound",
    "compiler_error_kinds_bound",
    "tactic_state_entropy_bound",
    "missing_premise_refs_bound",
    "verified_proof_neighbors_bound",
    "failed_attempt_memory_refs_bound",
    "route_pressure_labels_bound",
    "retrieve_pressure_bound",
    "repair_pressure_bound",
    "deeper_model_pressure_bound",
    "verifier_pressure_bound",
    "abstain_pressure_bound",
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
    "pressure_not_hidden_truth",
    "statement_not_mutated",
    "verifier_not_bypassed",
    "tests_not_bypassed",
    "citations_not_bypassed",
    "scope_rex_not_bypassed",
    "sovereign_gate_not_bypassed",
    "no_hidden_chain",
    "no_hidden_cloud",
    "no_runtime_bytes_loaded",
    "no_model_bytes_loaded",
    "proof_pressure_signal_address_deterministic",
    "held_out_route_success_bound",
    "statement_preservation_floor_bound",
    "missing_premise_recall_bound",
    "answer_packet_coverage_bound",
    "calibration_error_bound",
    "pressure_token_budget_bound",
    "metadata_bound",
    "beats_static_proof_route_baseline",
    "beats_proof_search_only_baseline",
    "beats_no_pressure_memory_baseline",
    "duplicate_fixture_rejected",
    "duplicate_pressure_signal_rejected",
    "missing_claim_ref_rejected",
    "missing_mission_id_rejected",
    "missing_proof_search_signal_ref_rejected",
    "statement_preservation_too_low_rejected",
    "statement_mutation_rejected",
    "missing_compiler_error_kind_rejected",
    "invalid_compiler_error_kind_rejected",
    "tactic_entropy_out_of_range_rejected",
    "missing_premise_ref_rejected",
    "missing_verified_neighbor_rejected",
    "missing_failed_attempt_memory_rejected",
    "missing_route_pressure_rejected",
    "invalid_route_pressure_rejected",
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
    "static_proof_route_baseline_unbeaten_rejected",
    "proof_search_only_baseline_unbeaten_rejected",
    "no_pressure_memory_baseline_unbeaten_rejected",
    "calibration_error_too_high_rejected",
    "compiler_error_diversity_missing_rejected",
    "route_pressure_diversity_missing_rejected",
    "metadata_budget_rejected",
    "pressure_token_budget_rejected",
    "fixture_count",
    "pressure_signal_count",
    "train_case_count",
    "held_out_case_count",
    "compiler_error_kind_count",
    "route_pressure_kind_count",
    "missing_premise_case_count",
    "verified_neighbor_count",
    "max_pressure_tokens",
    "max_pressure_metadata_bytes",
    "max_tactic_state_entropy_bps",
    "held_out_route_success_bps",
    "statement_preservation_floor_bps",
    "missing_premise_recall_bps",
    "answer_packet_coverage_bps",
    "calibration_error_bps",
    "static_proof_route_baseline_bps",
    "proof_search_only_baseline_bps",
    "no_pressure_memory_baseline_bps",
    "proof_pressure_signal_address",
];

#[derive(Clone)]
// UAS: uas:proof-pressure-signal:case
// Plane: Controller + Verification
// Residency: metadata-only compiler/proof pressure; no proof engine or model bytes load.
struct ProofPressureSignalCase {
    pressure_signal_id: String,
    claim_ref: String,
    mission_id: String,
    proof_search_signal_ref: String,
    statement_preservation_score_bps: u64,
    compiler_error_kind: String,
    tactic_state_entropy_bps: u64,
    missing_premise_refs: Vec<String>,
    verified_proof_neighbors: Vec<String>,
    failed_attempt_memory_ref: String,
    route_pressure: String,
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
    pressure_tokens: u64,
    pressure_metadata_bytes: u64,
    hidden_truth_authority: bool,
    statement_mutated: bool,
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
// UAS: uas:proof-pressure-signal:fixture
// Plane: Controller + Verification
// Residency: metadata-only pressure route fixture.
struct ProofPressureSignalFixture {
    fixture_id: String,
    upstream_proof_search_signal_ref: String,
    pressure_schema_ref: String,
    shadow_policy_ref: String,
    held_out_route_success_bps: u64,
    missing_premise_recall_bps: u64,
    answer_packet_coverage_bps: u64,
    calibration_error_bps: u64,
    static_proof_route_baseline_bps: u64,
    proof_search_only_baseline_bps: u64,
    no_pressure_memory_baseline_bps: u64,
    fixture_metadata_bytes: u64,
    route_authority: String,
    live_policy_promoted: bool,
    hidden_truth_authority: bool,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    runtime_bytes_loaded: u64,
    model_bytes_loaded: u64,
    signals: Vec<ProofPressureSignalCase>,
}

#[derive(Default, Clone, Copy)]
// UAS: uas:proof-pressure-signal:metrics
// Plane: Verification
// Residency: metadata-only pressure summary.
struct ProofPressureSignalMetrics {
    fixture_count: u64,
    pressure_signal_count: u64,
    train_case_count: u64,
    held_out_case_count: u64,
    compiler_error_kind_count: u64,
    route_pressure_kind_count: u64,
    missing_premise_case_count: u64,
    verified_neighbor_count: u64,
    max_pressure_tokens: u64,
    max_pressure_metadata_bytes: u64,
    max_tactic_state_entropy_bps: u64,
    held_out_route_success_bps: u64,
    statement_preservation_floor_bps: u64,
    missing_premise_recall_bps: u64,
    answer_packet_coverage_bps: u64,
    calibration_error_bps: u64,
    static_proof_route_baseline_bps: u64,
    proof_search_only_baseline_bps: u64,
    no_pressure_memory_baseline_bps: u64,
}

#[derive(Debug, Eq, PartialEq)]
// UAS: uas:proof-pressure-signal:error
// Plane: Verification
// Residency: metadata-only rejection reason.
enum ProofPressureSignalError {
    MissingFixture,
    DuplicateFixture,
    MissingFixtureId,
    MissingUpstreamProofSearch,
    MissingPressureSchema,
    MissingShadowPolicy,
    MissingSignal,
    DuplicatePressureSignal,
    MissingSignalId,
    MissingClaimRef,
    MissingMissionId,
    MissingProofSearchSignalRef,
    StatementPreservationTooLow,
    StatementMutation,
    MissingCompilerErrorKind,
    InvalidCompilerErrorKind,
    TacticEntropyOutOfRange,
    MissingPremiseRef,
    MissingVerifiedNeighbor,
    MissingFailedAttemptMemory,
    MissingRoutePressure,
    InvalidRoutePressure,
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
    MissingPremiseRecallTooLow,
    AnswerPacketCoverageTooLow,
    CalibrationErrorTooHigh,
    StaticProofRouteBaselineUnbeaten,
    ProofSearchOnlyBaselineUnbeaten,
    NoPressureMemoryBaselineUnbeaten,
    CompilerErrorDiversityTooLow,
    RoutePressureDiversityTooLow,
    MetadataBudgetExceeded,
    PressureTokenBudgetExceeded,
}

impl std::fmt::Display for ProofPressureSignalError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for ProofPressureSignalError {}

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
        .get("pressure_signal_count")
        .and_then(|m| m.value.as_u64())
        .unwrap_or(0);
    let held_out_route_success_bps = artifact
        .measurements
        .get("held_out_route_success_bps")
        .and_then(|m| m.value.as_u64())
        .unwrap_or(0);
    let pressure_address = artifact
        .measurements
        .get("proof_pressure_signal_address")
        .and_then(|m| m.value.as_str())
        .unwrap_or("unknown");
    println!(
        "{FALSIFIER_ID}: overall_pass={} pressure_signal_count={} held_out_route_success_bps={} proof_pressure_signal_address={pressure_address:?} artifact={RESULT}",
        artifact.overall_pass, signal_count, held_out_route_success_bps
    );
    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact() -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, String> {
    let fixtures = fixture_proof_pressure_signals();
    let registry =
        ProofPressureSignalRegistry::new(fixtures.clone()).map_err(|error| error.to_string())?;
    let metrics = registry.metrics();
    let pressure_address = registry.proof_pressure_signal_address();

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "upstream_proof_search_signal_route_feedback_pass",
        upstream_artifact_pass(UPSTREAM_PROOF_SEARCH_SIGNAL),
    );

    for (name, pass) in registry.axis_bools(&pressure_address) {
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
        "pressure_signal_count",
        metrics.pressure_signal_count,
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
        "compiler_error_kind_count",
        metrics.compiler_error_kind_count,
        MIN_COMPILER_ERROR_KIND_COUNT,
        "kind",
    );
    add_u64_gte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_pressure_kind_count",
        metrics.route_pressure_kind_count,
        MIN_ROUTE_PRESSURE_KIND_COUNT,
        "pressure",
    );
    add_u64_gte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "missing_premise_case_count",
        metrics.missing_premise_case_count,
        4,
        "case",
    );
    add_u64_gte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verified_neighbor_count",
        metrics.verified_neighbor_count,
        12,
        "neighbor",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_pressure_tokens",
        metrics.max_pressure_tokens,
        MAX_PRESSURE_TOKENS,
        "token",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_pressure_metadata_bytes",
        metrics.max_pressure_metadata_bytes,
        MAX_PRESSURE_METADATA_BYTES,
        "bytes",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_tactic_state_entropy_bps",
        metrics.max_tactic_state_entropy_bps,
        MAX_TACTIC_STATE_ENTROPY_BPS,
        "bps",
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
        "statement_preservation_floor_bps",
        metrics.statement_preservation_floor_bps,
        MIN_STATEMENT_PRESERVATION_BPS,
        "bps",
    );
    add_u64_gte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "missing_premise_recall_bps",
        metrics.missing_premise_recall_bps,
        MIN_MISSING_PREMISE_RECALL_BPS,
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
        "static_proof_route_baseline_bps",
        metrics.static_proof_route_baseline_bps,
        metrics.held_out_route_success_bps,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "proof_search_only_baseline_bps",
        metrics.proof_search_only_baseline_bps,
        metrics.held_out_route_success_bps,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_pressure_memory_baseline_bps",
        metrics.no_pressure_memory_baseline_bps,
        metrics.held_out_route_success_bps,
        "bps",
    );
    add_label_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "proof_pressure_signal_address",
        &pressure_address,
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
            "detail": "ProofPressureSignal proves compiler/proof pressure labels and rejection behavior only; it does not run Lean, mutate statements, wake sparse units, mutate live route policy, or promote local model / 70B runtime claims."
        })],
        notes: "metadata-only Meta Control witness; compiler errors, tactic-state entropy, missing premises, verified proof neighbors, and failed-attempt memory become explicit route-pressure labels with statement preservation, rollback, RunEventLog, AnswerPacket, no-hidden-truth, no-bypass, no-cloud, and zero-runtime/model-byte guards; L1 only, not live proof route authority".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:proof-pressure-signal:registry
// Plane: Controller + Verification
// Residency: metadata-only registry; validates pressure labels before artifact emission.
struct ProofPressureSignalRegistry {
    fixtures: Vec<ProofPressureSignalFixture>,
}

impl ProofPressureSignalRegistry {
    fn new(fixtures: Vec<ProofPressureSignalFixture>) -> Result<Self, ProofPressureSignalError> {
        validate_fixtures(&fixtures)?;
        Ok(Self { fixtures })
    }

    fn metrics(&self) -> ProofPressureSignalMetrics {
        let mut metrics = ProofPressureSignalMetrics {
            fixture_count: self.fixtures.len() as u64,
            held_out_route_success_bps: u64::MAX,
            statement_preservation_floor_bps: u64::MAX,
            missing_premise_recall_bps: u64::MAX,
            answer_packet_coverage_bps: u64::MAX,
            ..ProofPressureSignalMetrics::default()
        };
        let mut compiler_error_kinds = BTreeSet::new();
        let mut route_pressure_kinds = BTreeSet::new();
        let mut verified_neighbors = BTreeSet::new();
        for fixture in &self.fixtures {
            metrics.held_out_route_success_bps = metrics
                .held_out_route_success_bps
                .min(fixture.held_out_route_success_bps);
            metrics.missing_premise_recall_bps = metrics
                .missing_premise_recall_bps
                .min(fixture.missing_premise_recall_bps);
            metrics.answer_packet_coverage_bps = metrics
                .answer_packet_coverage_bps
                .min(fixture.answer_packet_coverage_bps);
            metrics.calibration_error_bps = metrics
                .calibration_error_bps
                .max(fixture.calibration_error_bps);
            metrics.static_proof_route_baseline_bps = metrics
                .static_proof_route_baseline_bps
                .max(fixture.static_proof_route_baseline_bps);
            metrics.proof_search_only_baseline_bps = metrics
                .proof_search_only_baseline_bps
                .max(fixture.proof_search_only_baseline_bps);
            metrics.no_pressure_memory_baseline_bps = metrics
                .no_pressure_memory_baseline_bps
                .max(fixture.no_pressure_memory_baseline_bps);
            metrics.max_pressure_metadata_bytes = metrics
                .max_pressure_metadata_bytes
                .max(fixture.fixture_metadata_bytes);
            for signal in &fixture.signals {
                metrics.pressure_signal_count += 1;
                metrics.statement_preservation_floor_bps = metrics
                    .statement_preservation_floor_bps
                    .min(signal.statement_preservation_score_bps);
                metrics.max_tactic_state_entropy_bps = metrics
                    .max_tactic_state_entropy_bps
                    .max(signal.tactic_state_entropy_bps);
                metrics.max_pressure_tokens =
                    metrics.max_pressure_tokens.max(signal.pressure_tokens);
                metrics.max_pressure_metadata_bytes = metrics
                    .max_pressure_metadata_bytes
                    .max(signal.pressure_metadata_bytes);
                if requires_missing_premise(&signal.compiler_error_kind) {
                    metrics.missing_premise_case_count += 1;
                }
                for neighbor in &signal.verified_proof_neighbors {
                    verified_neighbors.insert(neighbor.as_str());
                }
                compiler_error_kinds.insert(signal.compiler_error_kind.as_str());
                route_pressure_kinds.insert(signal.route_pressure.as_str());
                match signal.split.as_str() {
                    "train" => metrics.train_case_count += 1,
                    "held_out" => metrics.held_out_case_count += 1,
                    _ => {}
                }
            }
        }
        metrics.compiler_error_kind_count = compiler_error_kinds.len() as u64;
        metrics.route_pressure_kind_count = route_pressure_kinds.len() as u64;
        metrics.verified_neighbor_count = verified_neighbors.len() as u64;
        metrics
    }

    fn axis_bools(&self, pressure_address: &str) -> Vec<(&'static str, bool)> {
        let metrics = self.metrics();
        vec![
            (
                "proof_pressure_signal_fixture_present",
                !self.fixtures.is_empty(),
            ),
            (
                "fixture_ids_bound",
                self.fixtures
                    .iter()
                    .all(|fixture| !fixture.fixture_id.is_empty()),
            ),
            (
                "pressure_schema_refs_bound",
                self.fixtures
                    .iter()
                    .all(|fixture| !fixture.pressure_schema_ref.is_empty()),
            ),
            (
                "shadow_policy_refs_bound",
                self.fixtures
                    .iter()
                    .all(|fixture| !fixture.shadow_policy_ref.is_empty()),
            ),
            (
                "pressure_signal_ids_bound",
                self.signals()
                    .all(|signal| !signal.pressure_signal_id.is_empty()),
            ),
            (
                "claim_refs_bound",
                self.signals().all(|signal| !signal.claim_ref.is_empty()),
            ),
            (
                "mission_ids_bound",
                self.signals().all(|signal| !signal.mission_id.is_empty()),
            ),
            (
                "proof_search_signal_refs_bound",
                self.signals()
                    .all(|signal| !signal.proof_search_signal_ref.is_empty()),
            ),
            (
                "statement_preservation_scores_bound",
                self.signals().all(|signal| {
                    signal.statement_preservation_score_bps >= MIN_STATEMENT_PRESERVATION_BPS
                        && !signal.statement_mutated
                }),
            ),
            (
                "compiler_error_kinds_bound",
                self.signals()
                    .all(|signal| valid_compiler_error_kind(&signal.compiler_error_kind)),
            ),
            (
                "tactic_state_entropy_bound",
                self.signals().all(|signal| {
                    signal.tactic_state_entropy_bps > 0
                        && signal.tactic_state_entropy_bps <= MAX_TACTIC_STATE_ENTROPY_BPS
                }),
            ),
            (
                "missing_premise_refs_bound",
                self.signals().all(|signal| {
                    !requires_missing_premise(&signal.compiler_error_kind)
                        || (!signal.missing_premise_refs.is_empty()
                            && signal
                                .missing_premise_refs
                                .iter()
                                .all(|premise| !premise.is_empty()))
                }),
            ),
            (
                "verified_proof_neighbors_bound",
                self.signals().all(|signal| {
                    !signal.verified_proof_neighbors.is_empty()
                        && signal
                            .verified_proof_neighbors
                            .iter()
                            .all(|neighbor| !neighbor.is_empty())
                }),
            ),
            (
                "failed_attempt_memory_refs_bound",
                self.signals()
                    .all(|signal| !signal.failed_attempt_memory_ref.is_empty()),
            ),
            (
                "route_pressure_labels_bound",
                self.signals()
                    .all(|signal| valid_route_pressure(&signal.route_pressure)),
            ),
            (
                "retrieve_pressure_bound",
                self.has_route_pressure("retrieve"),
            ),
            ("repair_pressure_bound", self.has_route_pressure("repair")),
            (
                "deeper_model_pressure_bound",
                self.has_route_pressure("deeper_model"),
            ),
            (
                "verifier_pressure_bound",
                self.has_route_pressure("verifier"),
            ),
            ("abstain_pressure_bound", self.has_route_pressure("abstain")),
            (
                "test_refs_bound",
                self.signals()
                    .all(|signal| !signal.test_result_ref.is_empty()),
            ),
            (
                "citation_refs_bound",
                self.signals().all(|signal| !signal.citation_ref.is_empty()),
            ),
            (
                "scope_rex_refs_bound",
                self.signals()
                    .all(|signal| !signal.scope_rex_ref.is_empty()),
            ),
            (
                "sovereign_gate_refs_bound",
                self.signals()
                    .all(|signal| !signal.sovereign_gate_ref.is_empty()),
            ),
            (
                "compatibility_fence_bound",
                self.signals().all(|signal| {
                    !signal.compatibility_fence.is_empty()
                        && signal.compatibility_fence == CURRENT_FENCE
                }),
            ),
            (
                "privacy_classes_bound",
                self.signals()
                    .all(|signal| valid_privacy_class(&signal.privacy_class)),
            ),
            (
                "rollback_bound",
                self.signals()
                    .all(|signal| !signal.rollback_handle.is_empty()),
            ),
            (
                "run_event_log_bound",
                self.signals()
                    .all(|signal| !signal.run_event_log_ref.is_empty()),
            ),
            (
                "answer_packet_ref_bound",
                self.signals()
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
                "pressure_not_hidden_truth",
                self.fixtures
                    .iter()
                    .all(|fixture| !fixture.hidden_truth_authority)
                    && self.signals().all(|signal| !signal.hidden_truth_authority),
            ),
            (
                "statement_not_mutated",
                self.signals().all(|signal| !signal.statement_mutated),
            ),
            (
                "verifier_not_bypassed",
                self.signals().all(|signal| !signal.verifier_bypassed),
            ),
            (
                "tests_not_bypassed",
                self.signals().all(|signal| !signal.tests_bypassed),
            ),
            (
                "citations_not_bypassed",
                self.signals().all(|signal| !signal.citations_bypassed),
            ),
            (
                "scope_rex_not_bypassed",
                self.signals().all(|signal| !signal.scope_rex_bypassed),
            ),
            (
                "sovereign_gate_not_bypassed",
                self.signals().all(|signal| !signal.sovereign_gate_bypassed),
            ),
            (
                "no_hidden_chain",
                self.fixtures
                    .iter()
                    .all(|fixture| !fixture.hidden_chain_exposed)
                    && self.signals().all(|signal| !signal.hidden_chain_exposed),
            ),
            (
                "no_hidden_cloud",
                self.fixtures.iter().all(|fixture| !fixture.hidden_cloud)
                    && self.signals().all(|signal| !signal.hidden_cloud),
            ),
            (
                "no_runtime_bytes_loaded",
                self.fixtures
                    .iter()
                    .all(|fixture| fixture.runtime_bytes_loaded == 0)
                    && self
                        .signals()
                        .all(|signal| signal.runtime_bytes_loaded == 0),
            ),
            (
                "no_model_bytes_loaded",
                self.fixtures
                    .iter()
                    .all(|fixture| fixture.model_bytes_loaded == 0)
                    && self.signals().all(|signal| signal.model_bytes_loaded == 0),
            ),
            (
                "proof_pressure_signal_address_deterministic",
                pressure_address.starts_with("uas:proof-pressure-signal:"),
            ),
            (
                "held_out_route_success_bound",
                metrics.held_out_route_success_bps >= MIN_HELD_OUT_ROUTE_SUCCESS_BPS,
            ),
            (
                "statement_preservation_floor_bound",
                metrics.statement_preservation_floor_bps >= MIN_STATEMENT_PRESERVATION_BPS,
            ),
            (
                "missing_premise_recall_bound",
                metrics.missing_premise_recall_bps >= MIN_MISSING_PREMISE_RECALL_BPS,
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
                "pressure_token_budget_bound",
                metrics.max_pressure_tokens <= MAX_PRESSURE_TOKENS,
            ),
            (
                "metadata_bound",
                metrics.max_pressure_metadata_bytes <= MAX_PRESSURE_METADATA_BYTES,
            ),
            (
                "beats_static_proof_route_baseline",
                metrics.static_proof_route_baseline_bps < metrics.held_out_route_success_bps,
            ),
            (
                "beats_proof_search_only_baseline",
                metrics.proof_search_only_baseline_bps < metrics.held_out_route_success_bps,
            ),
            (
                "beats_no_pressure_memory_baseline",
                metrics.no_pressure_memory_baseline_bps < metrics.held_out_route_success_bps,
            ),
        ]
    }

    fn signals(&self) -> impl Iterator<Item = &ProofPressureSignalCase> {
        self.fixtures.iter().flat_map(|fixture| &fixture.signals)
    }

    fn has_route_pressure(&self, pressure: &str) -> bool {
        self.signals()
            .any(|signal| signal.route_pressure == pressure)
    }

    fn proof_pressure_signal_address(&self) -> String {
        let mut rows = Vec::with_capacity(self.fixtures.len());
        for fixture in &self.fixtures {
            let mut signal_ids: Vec<&str> = fixture
                .signals
                .iter()
                .map(|signal| signal.pressure_signal_id.as_str())
                .collect();
            signal_ids.sort_unstable();
            rows.push(format!(
                "{}:{}:{}:{}:{}",
                fixture.fixture_id,
                fixture.pressure_schema_ref,
                fixture.held_out_route_success_bps,
                fixture.missing_premise_recall_bps,
                signal_ids.join(",")
            ));
        }
        rows.sort_unstable();
        format!(
            "uas:proof-pressure-signal:{}",
            sha256_hex(rows.join("|").as_bytes())
        )
    }
}

fn validate_fixtures(
    fixtures: &[ProofPressureSignalFixture],
) -> Result<(), ProofPressureSignalError> {
    if fixtures.is_empty() {
        return Err(ProofPressureSignalError::MissingFixture);
    }
    let mut fixture_ids = BTreeSet::new();
    let mut signal_ids = BTreeSet::new();
    let mut train_count = 0_u64;
    let mut held_out_count = 0_u64;
    let mut compiler_kinds = BTreeSet::new();
    let mut route_pressures = BTreeSet::new();
    for fixture in fixtures {
        validate_fixture_header(fixture)?;
        if !fixture_ids.insert(fixture.fixture_id.as_str()) {
            return Err(ProofPressureSignalError::DuplicateFixture);
        }
        if fixture.signals.is_empty() {
            return Err(ProofPressureSignalError::MissingSignal);
        }
        for signal in &fixture.signals {
            validate_signal(signal)?;
            if !signal_ids.insert(signal.pressure_signal_id.as_str()) {
                return Err(ProofPressureSignalError::DuplicatePressureSignal);
            }
            match signal.split.as_str() {
                "train" => train_count += 1,
                "held_out" => held_out_count += 1,
                _ => return Err(ProofPressureSignalError::MissingHeldOutSplit),
            }
            compiler_kinds.insert(signal.compiler_error_kind.as_str());
            route_pressures.insert(signal.route_pressure.as_str());
        }
        validate_fixture_scores(fixture)?;
    }
    if train_count == 0 {
        return Err(ProofPressureSignalError::MissingTrainSplit);
    }
    if held_out_count == 0 {
        return Err(ProofPressureSignalError::MissingHeldOutSplit);
    }
    if compiler_kinds.len() < MIN_COMPILER_ERROR_KIND_COUNT as usize {
        return Err(ProofPressureSignalError::CompilerErrorDiversityTooLow);
    }
    if route_pressures.len() < MIN_ROUTE_PRESSURE_KIND_COUNT as usize {
        return Err(ProofPressureSignalError::RoutePressureDiversityTooLow);
    }
    Ok(())
}

fn validate_fixture_header(
    fixture: &ProofPressureSignalFixture,
) -> Result<(), ProofPressureSignalError> {
    if fixture.fixture_id.is_empty() {
        return Err(ProofPressureSignalError::MissingFixtureId);
    }
    if fixture.upstream_proof_search_signal_ref.is_empty() {
        return Err(ProofPressureSignalError::MissingUpstreamProofSearch);
    }
    if fixture.pressure_schema_ref.is_empty() {
        return Err(ProofPressureSignalError::MissingPressureSchema);
    }
    if fixture.shadow_policy_ref.is_empty() {
        return Err(ProofPressureSignalError::MissingShadowPolicy);
    }
    if fixture.route_authority != "shadow_only" {
        return Err(ProofPressureSignalError::HiddenLiveAuthority);
    }
    if fixture.live_policy_promoted {
        return Err(ProofPressureSignalError::LivePolicyPromotion);
    }
    if fixture.hidden_truth_authority {
        return Err(ProofPressureSignalError::HiddenTruthAuthority);
    }
    if fixture.hidden_chain_exposed {
        return Err(ProofPressureSignalError::HiddenChainExposure);
    }
    if fixture.hidden_cloud {
        return Err(ProofPressureSignalError::CloudSource);
    }
    if fixture.runtime_bytes_loaded > 0 {
        return Err(ProofPressureSignalError::RuntimeBytesLoaded);
    }
    if fixture.model_bytes_loaded > 0 {
        return Err(ProofPressureSignalError::ModelBytesLoaded);
    }
    if fixture.fixture_metadata_bytes > MAX_PRESSURE_METADATA_BYTES {
        return Err(ProofPressureSignalError::MetadataBudgetExceeded);
    }
    Ok(())
}

fn validate_signal(signal: &ProofPressureSignalCase) -> Result<(), ProofPressureSignalError> {
    if signal.pressure_signal_id.is_empty() {
        return Err(ProofPressureSignalError::MissingSignalId);
    }
    if signal.claim_ref.is_empty() {
        return Err(ProofPressureSignalError::MissingClaimRef);
    }
    if signal.mission_id.is_empty() {
        return Err(ProofPressureSignalError::MissingMissionId);
    }
    if signal.proof_search_signal_ref.is_empty() {
        return Err(ProofPressureSignalError::MissingProofSearchSignalRef);
    }
    if signal.statement_preservation_score_bps < MIN_STATEMENT_PRESERVATION_BPS {
        return Err(ProofPressureSignalError::StatementPreservationTooLow);
    }
    if signal.statement_mutated {
        return Err(ProofPressureSignalError::StatementMutation);
    }
    if signal.compiler_error_kind.is_empty() {
        return Err(ProofPressureSignalError::MissingCompilerErrorKind);
    }
    if !valid_compiler_error_kind(&signal.compiler_error_kind) {
        return Err(ProofPressureSignalError::InvalidCompilerErrorKind);
    }
    if signal.tactic_state_entropy_bps == 0
        || signal.tactic_state_entropy_bps > MAX_TACTIC_STATE_ENTROPY_BPS
    {
        return Err(ProofPressureSignalError::TacticEntropyOutOfRange);
    }
    if requires_missing_premise(&signal.compiler_error_kind)
        && (signal.missing_premise_refs.is_empty()
            || signal
                .missing_premise_refs
                .iter()
                .any(|premise| premise.is_empty()))
    {
        return Err(ProofPressureSignalError::MissingPremiseRef);
    }
    if signal.verified_proof_neighbors.is_empty()
        || signal
            .verified_proof_neighbors
            .iter()
            .any(|neighbor| neighbor.is_empty())
    {
        return Err(ProofPressureSignalError::MissingVerifiedNeighbor);
    }
    if signal.failed_attempt_memory_ref.is_empty() {
        return Err(ProofPressureSignalError::MissingFailedAttemptMemory);
    }
    if signal.route_pressure.is_empty() {
        return Err(ProofPressureSignalError::MissingRoutePressure);
    }
    if !valid_route_pressure(&signal.route_pressure) {
        return Err(ProofPressureSignalError::InvalidRoutePressure);
    }
    if signal.test_result_ref.is_empty() {
        return Err(ProofPressureSignalError::MissingTestRef);
    }
    if signal.citation_ref.is_empty() {
        return Err(ProofPressureSignalError::MissingCitationRef);
    }
    if signal.scope_rex_ref.is_empty() {
        return Err(ProofPressureSignalError::MissingScopeRex);
    }
    if signal.sovereign_gate_ref.is_empty() {
        return Err(ProofPressureSignalError::MissingSovereignGate);
    }
    if signal.compatibility_fence.is_empty() {
        return Err(ProofPressureSignalError::MissingCompatibilityFence);
    }
    if signal.compatibility_fence != CURRENT_FENCE {
        return Err(ProofPressureSignalError::IncompatibleFence);
    }
    if !valid_privacy_class(&signal.privacy_class) {
        return Err(ProofPressureSignalError::InvalidPrivacyClass);
    }
    if signal.rollback_handle.is_empty() {
        return Err(ProofPressureSignalError::MissingRollback);
    }
    if signal.run_event_log_ref.is_empty() {
        return Err(ProofPressureSignalError::MissingRunEventLog);
    }
    if signal.answer_packet_ref.is_empty() {
        return Err(ProofPressureSignalError::MissingAnswerPacket);
    }
    if signal.hidden_truth_authority {
        return Err(ProofPressureSignalError::HiddenTruthAuthority);
    }
    if signal.verifier_bypassed {
        return Err(ProofPressureSignalError::VerifierBypass);
    }
    if signal.tests_bypassed {
        return Err(ProofPressureSignalError::TestBypass);
    }
    if signal.citations_bypassed {
        return Err(ProofPressureSignalError::CitationBypass);
    }
    if signal.scope_rex_bypassed {
        return Err(ProofPressureSignalError::ScopeRexBypass);
    }
    if signal.sovereign_gate_bypassed {
        return Err(ProofPressureSignalError::SovereignGateBypass);
    }
    if signal.hidden_chain_exposed {
        return Err(ProofPressureSignalError::HiddenChainExposure);
    }
    if signal.hidden_cloud {
        return Err(ProofPressureSignalError::CloudSource);
    }
    if signal.runtime_bytes_loaded > 0 {
        return Err(ProofPressureSignalError::RuntimeBytesLoaded);
    }
    if signal.model_bytes_loaded > 0 {
        return Err(ProofPressureSignalError::ModelBytesLoaded);
    }
    if signal.pressure_tokens == 0 || signal.pressure_tokens > MAX_PRESSURE_TOKENS {
        return Err(ProofPressureSignalError::PressureTokenBudgetExceeded);
    }
    if signal.pressure_metadata_bytes > MAX_PRESSURE_METADATA_BYTES {
        return Err(ProofPressureSignalError::MetadataBudgetExceeded);
    }
    Ok(())
}

fn validate_fixture_scores(
    fixture: &ProofPressureSignalFixture,
) -> Result<(), ProofPressureSignalError> {
    if fixture.held_out_route_success_bps < MIN_HELD_OUT_ROUTE_SUCCESS_BPS {
        return Err(ProofPressureSignalError::HeldOutSuccessTooLow);
    }
    if fixture.missing_premise_recall_bps < MIN_MISSING_PREMISE_RECALL_BPS {
        return Err(ProofPressureSignalError::MissingPremiseRecallTooLow);
    }
    if fixture.answer_packet_coverage_bps < MIN_ANSWER_PACKET_COVERAGE_BPS {
        return Err(ProofPressureSignalError::AnswerPacketCoverageTooLow);
    }
    if fixture.calibration_error_bps > MAX_CALIBRATION_ERROR_BPS {
        return Err(ProofPressureSignalError::CalibrationErrorTooHigh);
    }
    if fixture.static_proof_route_baseline_bps >= fixture.held_out_route_success_bps {
        return Err(ProofPressureSignalError::StaticProofRouteBaselineUnbeaten);
    }
    if fixture.proof_search_only_baseline_bps >= fixture.held_out_route_success_bps {
        return Err(ProofPressureSignalError::ProofSearchOnlyBaselineUnbeaten);
    }
    if fixture.no_pressure_memory_baseline_bps >= fixture.held_out_route_success_bps {
        return Err(ProofPressureSignalError::NoPressureMemoryBaselineUnbeaten);
    }
    Ok(())
}

fn valid_compiler_error_kind(kind: &str) -> bool {
    matches!(
        kind,
        "no_error"
            | "missing_premise"
            | "unknown_identifier"
            | "type_mismatch"
            | "tactic_timeout"
            | "state_entropy_high"
            | "verifier_gap"
    )
}

fn requires_missing_premise(kind: &str) -> bool {
    matches!(kind, "missing_premise" | "unknown_identifier")
}

fn valid_route_pressure(pressure: &str) -> bool {
    matches!(
        pressure,
        "retrieve" | "repair" | "deeper_model" | "verifier" | "abstain"
    )
}

fn valid_privacy_class(value: &str) -> bool {
    matches!(value, "local_private" | "local_sensitive" | "proof_public")
}

fn invalid_fixture_axes(fixtures: &[ProofPressureSignalFixture]) -> Vec<(&'static str, bool)> {
    let cases: Vec<(
        &'static str,
        fn(&mut Vec<ProofPressureSignalFixture>),
        ProofPressureSignalError,
    )> = vec![
        (
            "duplicate_fixture_rejected",
            |fixtures| fixtures.push(fixtures[0].clone()),
            ProofPressureSignalError::DuplicateFixture,
        ),
        (
            "duplicate_pressure_signal_rejected",
            |fixtures| {
                let duplicate = fixtures[0].signals[0].clone();
                fixtures[0].signals.push(duplicate);
            },
            ProofPressureSignalError::DuplicatePressureSignal,
        ),
        (
            "missing_claim_ref_rejected",
            |fixtures| fixtures[0].signals[0].claim_ref.clear(),
            ProofPressureSignalError::MissingClaimRef,
        ),
        (
            "missing_mission_id_rejected",
            |fixtures| fixtures[0].signals[0].mission_id.clear(),
            ProofPressureSignalError::MissingMissionId,
        ),
        (
            "missing_proof_search_signal_ref_rejected",
            |fixtures| fixtures[0].signals[0].proof_search_signal_ref.clear(),
            ProofPressureSignalError::MissingProofSearchSignalRef,
        ),
        (
            "statement_preservation_too_low_rejected",
            |fixtures| fixtures[0].signals[0].statement_preservation_score_bps = 9_000,
            ProofPressureSignalError::StatementPreservationTooLow,
        ),
        (
            "statement_mutation_rejected",
            |fixtures| fixtures[0].signals[0].statement_mutated = true,
            ProofPressureSignalError::StatementMutation,
        ),
        (
            "missing_compiler_error_kind_rejected",
            |fixtures| fixtures[0].signals[0].compiler_error_kind.clear(),
            ProofPressureSignalError::MissingCompilerErrorKind,
        ),
        (
            "invalid_compiler_error_kind_rejected",
            |fixtures| fixtures[0].signals[0].compiler_error_kind = "silent_success".to_string(),
            ProofPressureSignalError::InvalidCompilerErrorKind,
        ),
        (
            "tactic_entropy_out_of_range_rejected",
            |fixtures| fixtures[0].signals[0].tactic_state_entropy_bps = 0,
            ProofPressureSignalError::TacticEntropyOutOfRange,
        ),
        (
            "missing_premise_ref_rejected",
            |fixtures| fixtures[0].signals[0].missing_premise_refs.clear(),
            ProofPressureSignalError::MissingPremiseRef,
        ),
        (
            "missing_verified_neighbor_rejected",
            |fixtures| fixtures[0].signals[0].verified_proof_neighbors.clear(),
            ProofPressureSignalError::MissingVerifiedNeighbor,
        ),
        (
            "missing_failed_attempt_memory_rejected",
            |fixtures| fixtures[0].signals[0].failed_attempt_memory_ref.clear(),
            ProofPressureSignalError::MissingFailedAttemptMemory,
        ),
        (
            "missing_route_pressure_rejected",
            |fixtures| fixtures[0].signals[0].route_pressure.clear(),
            ProofPressureSignalError::MissingRoutePressure,
        ),
        (
            "invalid_route_pressure_rejected",
            |fixtures| fixtures[0].signals[0].route_pressure = "hidden_oracle".to_string(),
            ProofPressureSignalError::InvalidRoutePressure,
        ),
        (
            "missing_test_ref_rejected",
            |fixtures| fixtures[0].signals[0].test_result_ref.clear(),
            ProofPressureSignalError::MissingTestRef,
        ),
        (
            "missing_citation_ref_rejected",
            |fixtures| fixtures[0].signals[0].citation_ref.clear(),
            ProofPressureSignalError::MissingCitationRef,
        ),
        (
            "missing_scope_rex_rejected",
            |fixtures| fixtures[0].signals[0].scope_rex_ref.clear(),
            ProofPressureSignalError::MissingScopeRex,
        ),
        (
            "missing_sovereign_gate_rejected",
            |fixtures| fixtures[0].signals[0].sovereign_gate_ref.clear(),
            ProofPressureSignalError::MissingSovereignGate,
        ),
        (
            "missing_rollback_rejected",
            |fixtures| fixtures[0].signals[0].rollback_handle.clear(),
            ProofPressureSignalError::MissingRollback,
        ),
        (
            "missing_run_event_log_rejected",
            |fixtures| fixtures[0].signals[0].run_event_log_ref.clear(),
            ProofPressureSignalError::MissingRunEventLog,
        ),
        (
            "missing_answer_packet_rejected",
            |fixtures| fixtures[0].signals[0].answer_packet_ref.clear(),
            ProofPressureSignalError::MissingAnswerPacket,
        ),
        (
            "hidden_truth_authority_rejected",
            |fixtures| fixtures[0].signals[0].hidden_truth_authority = true,
            ProofPressureSignalError::HiddenTruthAuthority,
        ),
        (
            "verifier_bypass_rejected",
            |fixtures| fixtures[0].signals[0].verifier_bypassed = true,
            ProofPressureSignalError::VerifierBypass,
        ),
        (
            "test_bypass_rejected",
            |fixtures| fixtures[0].signals[0].tests_bypassed = true,
            ProofPressureSignalError::TestBypass,
        ),
        (
            "citation_bypass_rejected",
            |fixtures| fixtures[0].signals[0].citations_bypassed = true,
            ProofPressureSignalError::CitationBypass,
        ),
        (
            "scope_rex_bypass_rejected",
            |fixtures| fixtures[0].signals[0].scope_rex_bypassed = true,
            ProofPressureSignalError::ScopeRexBypass,
        ),
        (
            "sovereign_gate_bypass_rejected",
            |fixtures| fixtures[0].signals[0].sovereign_gate_bypassed = true,
            ProofPressureSignalError::SovereignGateBypass,
        ),
        (
            "hidden_live_authority_rejected",
            |fixtures| fixtures[0].route_authority = "live_route".to_string(),
            ProofPressureSignalError::HiddenLiveAuthority,
        ),
        (
            "live_policy_promotion_rejected",
            |fixtures| fixtures[0].live_policy_promoted = true,
            ProofPressureSignalError::LivePolicyPromotion,
        ),
        (
            "hidden_chain_exposure_rejected",
            |fixtures| fixtures[0].signals[0].hidden_chain_exposed = true,
            ProofPressureSignalError::HiddenChainExposure,
        ),
        (
            "cloud_source_rejected",
            |fixtures| fixtures[0].signals[0].hidden_cloud = true,
            ProofPressureSignalError::CloudSource,
        ),
        (
            "runtime_bytes_rejected",
            |fixtures| fixtures[0].signals[0].runtime_bytes_loaded = 1,
            ProofPressureSignalError::RuntimeBytesLoaded,
        ),
        (
            "model_bytes_rejected",
            |fixtures| fixtures[0].signals[0].model_bytes_loaded = 1,
            ProofPressureSignalError::ModelBytesLoaded,
        ),
        (
            "incompatible_fence_rejected",
            |fixtures| fixtures[0].signals[0].compatibility_fence = "fence:other".to_string(),
            ProofPressureSignalError::IncompatibleFence,
        ),
        (
            "invalid_privacy_rejected",
            |fixtures| fixtures[0].signals[0].privacy_class = "public_cloud".to_string(),
            ProofPressureSignalError::InvalidPrivacyClass,
        ),
        (
            "static_proof_route_baseline_unbeaten_rejected",
            |fixtures| {
                fixtures[0].static_proof_route_baseline_bps = fixtures[0].held_out_route_success_bps
            },
            ProofPressureSignalError::StaticProofRouteBaselineUnbeaten,
        ),
        (
            "proof_search_only_baseline_unbeaten_rejected",
            |fixtures| {
                fixtures[0].proof_search_only_baseline_bps = fixtures[0].held_out_route_success_bps
            },
            ProofPressureSignalError::ProofSearchOnlyBaselineUnbeaten,
        ),
        (
            "no_pressure_memory_baseline_unbeaten_rejected",
            |fixtures| {
                fixtures[0].no_pressure_memory_baseline_bps = fixtures[0].held_out_route_success_bps
            },
            ProofPressureSignalError::NoPressureMemoryBaselineUnbeaten,
        ),
        (
            "calibration_error_too_high_rejected",
            |fixtures| fixtures[0].calibration_error_bps = MAX_CALIBRATION_ERROR_BPS + 1,
            ProofPressureSignalError::CalibrationErrorTooHigh,
        ),
        (
            "compiler_error_diversity_missing_rejected",
            |fixtures| {
                for signal in &mut fixtures[0].signals {
                    signal.compiler_error_kind = "no_error".to_string();
                    signal.missing_premise_refs.clear();
                }
                for signal in &mut fixtures[1].signals {
                    signal.compiler_error_kind = "no_error".to_string();
                    signal.missing_premise_refs.clear();
                }
            },
            ProofPressureSignalError::CompilerErrorDiversityTooLow,
        ),
        (
            "route_pressure_diversity_missing_rejected",
            |fixtures| {
                for signal in &mut fixtures[0].signals {
                    signal.route_pressure = "retrieve".to_string();
                }
                for signal in &mut fixtures[1].signals {
                    signal.route_pressure = "retrieve".to_string();
                }
            },
            ProofPressureSignalError::RoutePressureDiversityTooLow,
        ),
        (
            "metadata_budget_rejected",
            |fixtures| {
                fixtures[0].signals[0].pressure_metadata_bytes = MAX_PRESSURE_METADATA_BYTES + 1
            },
            ProofPressureSignalError::MetadataBudgetExceeded,
        ),
        (
            "pressure_token_budget_rejected",
            |fixtures| fixtures[0].signals[0].pressure_tokens = MAX_PRESSURE_TOKENS + 1,
            ProofPressureSignalError::PressureTokenBudgetExceeded,
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

fn fixture_proof_pressure_signals() -> Vec<ProofPressureSignalFixture> {
    vec![
        ProofPressureSignalFixture {
            fixture_id: "proof-pressure:local-summary:v1".to_string(),
            upstream_proof_search_signal_ref: UPSTREAM_PROOF_SEARCH_SIGNAL.to_string(),
            pressure_schema_ref: "schema:proof-pressure-signal:v1".to_string(),
            shadow_policy_ref: "shadow-policy:proof-pressure:local-summary".to_string(),
            held_out_route_success_bps: 9_100,
            missing_premise_recall_bps: 9_400,
            answer_packet_coverage_bps: 10_000,
            calibration_error_bps: 620,
            static_proof_route_baseline_bps: 8_200,
            proof_search_only_baseline_bps: 8_650,
            no_pressure_memory_baseline_bps: 7_300,
            fixture_metadata_bytes: 210_000,
            route_authority: "shadow_only".to_string(),
            live_policy_promoted: false,
            hidden_truth_authority: false,
            hidden_chain_exposed: false,
            hidden_cloud: false,
            runtime_bytes_loaded: 0,
            model_bytes_loaded: 0,
            signals: vec![
                pressure_signal(
                    "pps:summary:missing-premise",
                    "claim:summary:causal-link-needs-source",
                    "mission:summary-proof-pressure",
                    "pss:summary:fail",
                    9_700,
                    "missing_premise",
                    6_200,
                    &["premise:source:causal-link"],
                    &["proof-neighbor:summary:citation-lemma"],
                    "attempt-memory:summary:missing-premise",
                    "retrieve",
                    "held_out",
                    18_000,
                ),
                pressure_signal(
                    "pps:summary:type-mismatch",
                    "claim:summary:quote-span-type",
                    "mission:summary-proof-pressure",
                    "pss:summary:repair",
                    9_600,
                    "type_mismatch",
                    4_700,
                    &[],
                    &["proof-neighbor:summary:quote-normalization"],
                    "attempt-memory:summary:type-mismatch",
                    "repair",
                    "train",
                    19_000,
                ),
                pressure_signal(
                    "pps:summary:entropy",
                    "claim:summary:scope-too-wide",
                    "mission:summary-proof-pressure",
                    "pss:summary:abstain",
                    9_800,
                    "state_entropy_high",
                    9_100,
                    &[],
                    &["proof-neighbor:summary:scope-bound"],
                    "attempt-memory:summary:entropy",
                    "abstain",
                    "held_out",
                    14_000,
                ),
                pressure_signal(
                    "pps:summary:verifier-gap",
                    "claim:summary:all-citations-checked",
                    "mission:summary-proof-pressure",
                    "pss:summary:pass",
                    9_900,
                    "unknown_identifier",
                    2_800,
                    &["premise:source:coverage-table"],
                    &["proof-neighbor:summary:source-coverage"],
                    "attempt-memory:summary:verifier-gap",
                    "verifier",
                    "train",
                    13_000,
                ),
                pressure_signal(
                    "pps:summary:tactic-timeout",
                    "claim:summary:multi-hop-inference",
                    "mission:summary-proof-pressure",
                    "pss:summary:deeper",
                    9_500,
                    "tactic_timeout",
                    7_600,
                    &[],
                    &["proof-neighbor:summary:multi-hop"],
                    "attempt-memory:summary:tactic-timeout",
                    "deeper_model",
                    "held_out",
                    22_000,
                ),
                pressure_signal(
                    "pps:summary:no-error",
                    "claim:summary:cites-all-sources",
                    "mission:summary-proof-pressure",
                    "pss:summary:pass",
                    10_000,
                    "no_error",
                    900,
                    &[],
                    &["proof-neighbor:summary:pass"],
                    "attempt-memory:summary:pass",
                    "verifier",
                    "train",
                    12_000,
                ),
            ],
        },
        ProofPressureSignalFixture {
            fixture_id: "proof-pressure:code-repair:v1".to_string(),
            upstream_proof_search_signal_ref: UPSTREAM_PROOF_SEARCH_SIGNAL.to_string(),
            pressure_schema_ref: "schema:proof-pressure-signal:v1".to_string(),
            shadow_policy_ref: "shadow-policy:proof-pressure:code-repair".to_string(),
            held_out_route_success_bps: 9_000,
            missing_premise_recall_bps: 9_300,
            answer_packet_coverage_bps: 10_000,
            calibration_error_bps: 700,
            static_proof_route_baseline_bps: 8_150,
            proof_search_only_baseline_bps: 8_550,
            no_pressure_memory_baseline_bps: 7_100,
            fixture_metadata_bytes: 225_000,
            route_authority: "shadow_only".to_string(),
            live_policy_promoted: false,
            hidden_truth_authority: false,
            hidden_chain_exposed: false,
            hidden_cloud: false,
            runtime_bytes_loaded: 0,
            model_bytes_loaded: 0,
            signals: vec![
                pressure_signal(
                    "pps:code:unknown-identifier",
                    "claim:code:rollback-invariant",
                    "mission:code-proof-pressure",
                    "pss:code:retrieve",
                    9_600,
                    "unknown_identifier",
                    6_800,
                    &["premise:api:rollback-handle"],
                    &["proof-neighbor:code:rollback-lease"],
                    "attempt-memory:code:unknown-identifier",
                    "retrieve",
                    "train",
                    18_000,
                ),
                pressure_signal(
                    "pps:code:missing-premise",
                    "claim:code:unsafe-boundary-documented",
                    "mission:code-proof-pressure",
                    "pss:code:fail",
                    9_500,
                    "missing_premise",
                    6_500,
                    &["premise:unsafe:safety-comment"],
                    &["proof-neighbor:code:unsafe-doc"],
                    "attempt-memory:code:missing-premise",
                    "verifier",
                    "held_out",
                    17_000,
                ),
                pressure_signal(
                    "pps:code:type-mismatch",
                    "claim:code:ffi-layout-preserved",
                    "mission:code-proof-pressure",
                    "pss:code:pass",
                    9_800,
                    "type_mismatch",
                    4_500,
                    &[],
                    &["proof-neighbor:code:repr-c"],
                    "attempt-memory:code:type-mismatch",
                    "repair",
                    "held_out",
                    20_000,
                ),
                pressure_signal(
                    "pps:code:timeout",
                    "claim:code:multi-module-invariant",
                    "mission:code-proof-pressure",
                    "pss:code:deeper",
                    9_500,
                    "tactic_timeout",
                    8_200,
                    &[],
                    &["proof-neighbor:code:module-invariant"],
                    "attempt-memory:code:timeout",
                    "deeper_model",
                    "train",
                    23_000,
                ),
                pressure_signal(
                    "pps:code:entropy",
                    "claim:code:autogenous-kernel-mutation",
                    "mission:code-proof-pressure",
                    "pss:code:abstain",
                    9_700,
                    "state_entropy_high",
                    9_300,
                    &[],
                    &["proof-neighbor:code:kernel-dry-run"],
                    "attempt-memory:code:entropy",
                    "abstain",
                    "held_out",
                    14_000,
                ),
                pressure_signal(
                    "pps:code:verifier-gap",
                    "claim:code:answer-packet-visible",
                    "mission:code-proof-pressure",
                    "pss:code:repair",
                    9_900,
                    "verifier_gap",
                    3_200,
                    &[],
                    &["proof-neighbor:code:answer-packet"],
                    "attempt-memory:code:verifier-gap",
                    "verifier",
                    "train",
                    15_000,
                ),
            ],
        },
    ]
}

fn pressure_signal(
    pressure_signal_id: &str,
    claim_ref: &str,
    mission_id: &str,
    proof_search_signal_ref: &str,
    statement_preservation_score_bps: u64,
    compiler_error_kind: &str,
    tactic_state_entropy_bps: u64,
    missing_premise_refs: &[&str],
    verified_proof_neighbors: &[&str],
    failed_attempt_memory_ref: &str,
    route_pressure: &str,
    split: &str,
    pressure_tokens: u64,
) -> ProofPressureSignalCase {
    ProofPressureSignalCase {
        pressure_signal_id: pressure_signal_id.to_string(),
        claim_ref: claim_ref.to_string(),
        mission_id: mission_id.to_string(),
        proof_search_signal_ref: proof_search_signal_ref.to_string(),
        statement_preservation_score_bps,
        compiler_error_kind: compiler_error_kind.to_string(),
        tactic_state_entropy_bps,
        missing_premise_refs: missing_premise_refs
            .iter()
            .map(|premise| (*premise).to_string())
            .collect(),
        verified_proof_neighbors: verified_proof_neighbors
            .iter()
            .map(|neighbor| (*neighbor).to_string())
            .collect(),
        failed_attempt_memory_ref: failed_attempt_memory_ref.to_string(),
        route_pressure: route_pressure.to_string(),
        test_result_ref: format!("test-result:{pressure_signal_id}"),
        citation_ref: format!("citation:{pressure_signal_id}"),
        scope_rex_ref: format!("scope-rex:{pressure_signal_id}"),
        sovereign_gate_ref: format!("sovereign-gate:{pressure_signal_id}"),
        compatibility_fence: CURRENT_FENCE.to_string(),
        privacy_class: "local_private".to_string(),
        rollback_handle: format!("rollback:{pressure_signal_id}"),
        run_event_log_ref: format!("runevent:{pressure_signal_id}"),
        answer_packet_ref: format!("answer-packet:{pressure_signal_id}"),
        split: split.to_string(),
        pressure_tokens,
        pressure_metadata_bytes: 44_000,
        hidden_truth_authority: false,
        statement_mutated: false,
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
    let prefix = "uas:proof-pressure-signal:";
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
            value: serde_json::Value::String(prefix.to_string()),
            unit: "address".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), value.starts_with(prefix));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_fixture_rejects() {
        assert_eq!(
            validate_fixtures(&[]).err(),
            Some(ProofPressureSignalError::MissingFixture)
        );
    }

    #[test]
    fn invalid_fixture_cases_reject() {
        let fixtures = fixture_proof_pressure_signals();
        for (axis, passed) in invalid_fixture_axes(&fixtures) {
            assert!(passed, "{axis} should reject");
        }
    }

    #[test]
    fn proof_pressure_signal_address_is_order_stable() {
        let registry = ProofPressureSignalRegistry::new(fixture_proof_pressure_signals()).unwrap();
        let address = registry.proof_pressure_signal_address();
        let mut reversed = fixture_proof_pressure_signals();
        reversed.reverse();
        for fixture in &mut reversed {
            fixture.signals.reverse();
        }
        let reversed_registry = ProofPressureSignalRegistry::new(reversed).unwrap();
        assert_eq!(address, reversed_registry.proof_pressure_signal_address());
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
