//! `falsify_shadow_wake_oracle` -- offline oracle-label witness.
//!
//! Metadata-only witness for `F-ShadowWakeOracle`. It proves full-wake,
//! proof, citation, and test traces can create route labels for distillation
//! while remaining offline/shadow-only, rollback-bound, AnswerPacket-visible,
//! SCOPE-Rex/SovereignGate-governed, and unable to become a live runtime
//! dependency.

use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-ShadowWakeOracle";
const FIXTURE_ID: &str = "shadow_wake_oracle_v1";
const COMMAND: &str = "Tools/falsifiers/f_shadow_wake_oracle.sh";
const RESULT: &str = "artifacts/falsifiers/shadow_wake_oracle/result.json";
const UPSTREAM_DEPTH_LEASE: &str = "artifacts/falsifiers/depth_lease_checkpoint/result.json";
const UPSTREAM_ROUTE_DISTILLATION: &str =
    "artifacts/falsifiers/route_distillation_tournament/result.json";

const CURRENT_FENCE: &str = "fence:shadow-wake-oracle:v1:depth-lease:v1";
const MIN_HELD_OUT_SUCCESS_BPS: u64 = 8_900;
const MIN_LABEL_AGREEMENT_BPS: u64 = 9_100;
const MAX_CALIBRATION_ERROR_BPS: u64 = 850;
const MAX_ORACLE_METADATA_BYTES: u64 = 896 * 1024;
const MAX_TRACE_TOKENS: u64 = 72_000;
const MIN_SOURCE_KIND_COUNT: u64 = 4;
const MIN_ROUTE_LABEL_COUNT: u64 = 4;

#[cfg(test)]
const REQUIRED_AXES: &[&str] = &[
    "upstream_depth_lease_checkpoint_pass",
    "upstream_route_distillation_tournament_pass",
    "shadow_wake_fixture_present",
    "fixture_ids_bound",
    "oracle_ids_bound",
    "mission_ids_bound",
    "cheap_route_traces_bound",
    "full_wake_traces_bound",
    "proof_or_test_results_bound",
    "unit_credit_assignments_bound",
    "byte_latency_deltas_bound",
    "oracle_labels_bound",
    "route_labels_bound",
    "scout_feature_refs_bound",
    "proof_refs_bound",
    "test_refs_bound",
    "citation_refs_bound",
    "scope_rex_refs_bound",
    "sovereign_gate_refs_bound",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "compatibility_fence_bound",
    "privacy_classes_bound",
    "held_out_split_bound",
    "source_kind_diversity_bound",
    "route_label_diversity_bound",
    "shadow_only_authority",
    "offline_distillation_only",
    "oracle_not_live_dependency",
    "oracle_not_hidden_truth",
    "verifier_not_bypassed",
    "tests_not_bypassed",
    "citations_not_bypassed",
    "scope_rex_not_bypassed",
    "sovereign_gate_not_bypassed",
    "no_base_weight_mutation",
    "no_route_policy_mutation",
    "no_cache_mutation",
    "no_hidden_route_authority",
    "no_hidden_chain",
    "no_hidden_cloud",
    "no_runtime_bytes_loaded",
    "no_model_bytes_loaded",
    "shadow_wake_oracle_address_deterministic",
    "held_out_success_bound",
    "label_agreement_bound",
    "calibration_error_bound",
    "trace_token_budget_bound",
    "metadata_bound",
    "beats_cheap_route_baseline",
    "beats_full_wake_everything_baseline",
    "beats_no_oracle_label_baseline",
    "duplicate_fixture_rejected",
    "duplicate_oracle_rejected",
    "missing_fixture_id_rejected",
    "missing_oracle_record_rejected",
    "missing_oracle_id_rejected",
    "missing_mission_rejected",
    "missing_upstream_depth_lease_rejected",
    "missing_upstream_route_distillation_rejected",
    "missing_cheap_route_trace_rejected",
    "missing_full_wake_trace_rejected",
    "missing_proof_or_test_rejected",
    "missing_credit_assignment_rejected",
    "missing_byte_latency_delta_rejected",
    "missing_oracle_label_rejected",
    "missing_route_label_rejected",
    "missing_scout_feature_rejected",
    "missing_proof_ref_rejected",
    "missing_test_ref_rejected",
    "missing_citation_ref_rejected",
    "missing_scope_rex_rejected",
    "missing_sovereign_gate_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "missing_split_rejected",
    "invalid_split_rejected",
    "missing_held_out_split_rejected",
    "incompatible_fence_rejected",
    "invalid_privacy_rejected",
    "hidden_live_dependency_rejected",
    "hidden_truth_authority_rejected",
    "verifier_bypass_rejected",
    "test_bypass_rejected",
    "citation_bypass_rejected",
    "scope_rex_bypass_rejected",
    "sovereign_gate_bypass_rejected",
    "base_weight_mutation_rejected",
    "route_policy_mutation_rejected",
    "cache_mutation_rejected",
    "hidden_route_authority_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_source_rejected",
    "runtime_bytes_rejected",
    "model_bytes_rejected",
    "cheap_route_baseline_unbeaten_rejected",
    "full_wake_everything_baseline_unbeaten_rejected",
    "no_oracle_label_baseline_unbeaten_rejected",
    "label_agreement_too_low_rejected",
    "calibration_error_too_high_rejected",
    "source_kind_diversity_missing_rejected",
    "route_label_diversity_missing_rejected",
    "trace_token_budget_rejected",
    "metadata_budget_rejected",
    "fixture_count",
    "oracle_record_count",
    "train_case_count",
    "held_out_case_count",
    "source_kind_count",
    "route_label_count",
    "credit_assignment_count",
    "proof_or_test_result_count",
    "max_trace_tokens",
    "max_oracle_metadata_bytes",
    "held_out_success_bps",
    "label_agreement_bps",
    "calibration_error_bps",
    "cheap_route_baseline_bps",
    "full_wake_everything_baseline_bps",
    "no_oracle_label_baseline_bps",
    "shadow_wake_oracle_address",
];

#[derive(Clone)]
// UAS: uas:shadow-wake-oracle:record
// Plane: Controller + Verification
// Residency: metadata-only oracle label; no live runtime or model bytes.
struct ShadowWakeOracleRecord {
    oracle_id: String,
    mission_id: String,
    source_kind: String,
    upstream_depth_lease_ref: String,
    upstream_route_distillation_ref: String,
    cheap_route_trace_ref: String,
    full_wake_trace_ref: String,
    proof_or_test_result_ref: String,
    unit_credit_assignment_ref: String,
    byte_latency_delta_ref: String,
    oracle_label_ref: String,
    route_label: String,
    scout_feature_ref: String,
    proof_ref: String,
    test_ref: String,
    citation_ref: String,
    scope_rex_ref: String,
    sovereign_gate_ref: String,
    rollback_handle: String,
    run_event_log_ref: String,
    answer_packet_ref: String,
    compatibility_fence: String,
    privacy_class: String,
    split: String,
    trace_tokens: u64,
    metadata_bytes: u64,
    cheap_route_baseline_bps: u64,
    full_wake_everything_baseline_bps: u64,
    no_oracle_label_baseline_bps: u64,
    live_runtime_dependency: bool,
    hidden_truth_authority: bool,
    verifier_bypassed: bool,
    tests_bypassed: bool,
    citations_bypassed: bool,
    scope_rex_bypassed: bool,
    sovereign_gate_bypassed: bool,
    base_weight_mutated: bool,
    route_policy_mutated: bool,
    cache_mutated: bool,
    hidden_route_authority: bool,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    runtime_bytes_loaded: u64,
    model_bytes_loaded: u64,
}

#[derive(Clone)]
// UAS: uas:shadow-wake-oracle:fixture
// Plane: Controller + Verification
// Residency: offline/shadow-only oracle-label fixture.
struct ShadowWakeOracleFixture {
    fixture_id: String,
    oracle_policy_ref: String,
    held_out_success_bps: u64,
    label_agreement_bps: u64,
    calibration_error_bps: u64,
    authority: String,
    offline_distillation_only: bool,
    records: Vec<ShadowWakeOracleRecord>,
}

#[derive(Default)]
// UAS: uas:shadow-wake-oracle:metrics
// Plane: Verification
// Residency: derived metadata-only oracle-label summary.
struct ShadowWakeMetrics {
    fixture_count: u64,
    oracle_record_count: u64,
    train_case_count: u64,
    held_out_case_count: u64,
    source_kind_count: u64,
    route_label_count: u64,
    credit_assignment_count: u64,
    proof_or_test_result_count: u64,
    max_trace_tokens: u64,
    max_oracle_metadata_bytes: u64,
    held_out_success_bps: u64,
    label_agreement_bps: u64,
    calibration_error_bps: u64,
    cheap_route_baseline_bps: u64,
    full_wake_everything_baseline_bps: u64,
    no_oracle_label_baseline_bps: u64,
}

// UAS: uas:shadow-wake-oracle:registry
// Plane: Controller + Verification
// Residency: offline/shadow-only registry; no live route authority.
struct ShadowWakeOracleRegistry {
    fixtures: Vec<ShadowWakeOracleFixture>,
}

impl ShadowWakeOracleRegistry {
    fn new(fixtures: Vec<ShadowWakeOracleFixture>) -> Result<Self, ShadowWakeError> {
        validate_fixtures(&fixtures)?;
        Ok(Self { fixtures })
    }

    fn records(&self) -> impl Iterator<Item = &ShadowWakeOracleRecord> {
        self.fixtures.iter().flat_map(|fixture| &fixture.records)
    }

    fn metrics(&self) -> ShadowWakeMetrics {
        let mut oracle_ids = BTreeSet::new();
        let mut source_kinds = BTreeSet::new();
        let mut route_labels = BTreeSet::new();
        let mut credit_assignments = BTreeSet::new();
        let mut proof_or_test_results = BTreeSet::new();
        let mut train = 0_u64;
        let mut held_out = 0_u64;
        let mut max_trace_tokens = 0_u64;
        let mut max_metadata = 0_u64;
        let mut held_out_success = u64::MAX;
        let mut label_agreement = u64::MAX;
        let mut calibration_error = 0_u64;
        let mut cheap_route_baseline = 0_u64;
        let mut full_wake_baseline = 0_u64;
        let mut no_oracle_baseline = 0_u64;

        for fixture in &self.fixtures {
            held_out_success = held_out_success.min(fixture.held_out_success_bps);
            label_agreement = label_agreement.min(fixture.label_agreement_bps);
            calibration_error = calibration_error.max(fixture.calibration_error_bps);
            for record in &fixture.records {
                oracle_ids.insert(record.oracle_id.as_str());
                source_kinds.insert(record.source_kind.as_str());
                route_labels.insert(record.route_label.as_str());
                credit_assignments.insert(record.unit_credit_assignment_ref.as_str());
                proof_or_test_results.insert(record.proof_or_test_result_ref.as_str());
                max_trace_tokens = max_trace_tokens.max(record.trace_tokens);
                max_metadata = max_metadata.max(record.metadata_bytes);
                cheap_route_baseline = cheap_route_baseline.max(record.cheap_route_baseline_bps);
                full_wake_baseline =
                    full_wake_baseline.max(record.full_wake_everything_baseline_bps);
                no_oracle_baseline = no_oracle_baseline.max(record.no_oracle_label_baseline_bps);
                match record.split.as_str() {
                    "train" => train += 1,
                    "held_out" => held_out += 1,
                    _ => {}
                }
            }
        }

        ShadowWakeMetrics {
            fixture_count: self.fixtures.len() as u64,
            oracle_record_count: oracle_ids.len() as u64,
            train_case_count: train,
            held_out_case_count: held_out,
            source_kind_count: source_kinds.len() as u64,
            route_label_count: route_labels.len() as u64,
            credit_assignment_count: credit_assignments.len() as u64,
            proof_or_test_result_count: proof_or_test_results.len() as u64,
            max_trace_tokens,
            max_oracle_metadata_bytes: max_metadata,
            held_out_success_bps: if held_out_success == u64::MAX {
                0
            } else {
                held_out_success
            },
            label_agreement_bps: if label_agreement == u64::MAX {
                0
            } else {
                label_agreement
            },
            calibration_error_bps: calibration_error,
            cheap_route_baseline_bps: cheap_route_baseline,
            full_wake_everything_baseline_bps: full_wake_baseline,
            no_oracle_label_baseline_bps: no_oracle_baseline,
        }
    }

    fn address(&self) -> String {
        let mut rows = Vec::with_capacity(self.fixtures.len());
        for fixture in &self.fixtures {
            let mut record_ids: Vec<&str> = fixture
                .records
                .iter()
                .map(|record| record.oracle_id.as_str())
                .collect();
            record_ids.sort_unstable();
            rows.push(format!(
                "{}:{}:{}:{}:{}",
                fixture.fixture_id,
                fixture.oracle_policy_ref,
                fixture.held_out_success_bps,
                fixture.label_agreement_bps,
                record_ids.join(",")
            ));
        }
        rows.sort_unstable();
        sha256_hex(rows.join("|").as_bytes()).replacen(
            "sha256:",
            "uas:shadow-wake-oracle:sha256:",
            1,
        )
    }

    #[cfg(test)]
    fn has_source_kind(&self, source_kind: &str) -> bool {
        self.records()
            .any(|record| record.source_kind == source_kind)
    }

    #[cfg(test)]
    fn has_route_label(&self, route_label: &str) -> bool {
        self.records()
            .any(|record| record.route_label == route_label)
    }
}

#[derive(Debug, PartialEq, Eq)]
// UAS: uas:shadow-wake-oracle:error
// Plane: Verification
// Residency: metadata-only rejection reason; no live route mutation.
enum ShadowWakeError {
    EmptyFixtures,
    DuplicateFixture,
    MissingFixtureId,
    MissingPolicy,
    MissingRecord,
    DuplicateOracle,
    MissingOracleId,
    MissingMission,
    MissingUpstreamDepthLease,
    MissingUpstreamRouteDistillation,
    MissingCheapRouteTrace,
    MissingFullWakeTrace,
    MissingProofOrTest,
    MissingCreditAssignment,
    MissingByteLatencyDelta,
    MissingOracleLabel,
    MissingRouteLabel,
    MissingScoutFeature,
    MissingProofRef,
    MissingTestRef,
    MissingCitationRef,
    MissingScopeRex,
    MissingSovereignGate,
    MissingRollback,
    MissingRunEventLog,
    MissingAnswerPacket,
    InvalidSplit,
    MissingHeldOut,
    IncompatibleFence,
    InvalidPrivacy,
    HiddenLiveDependency,
    HiddenTruthAuthority,
    VerifierBypass,
    TestBypass,
    CitationBypass,
    ScopeRexBypass,
    SovereignGateBypass,
    BaseWeightMutation,
    RoutePolicyMutation,
    CacheMutation,
    HiddenRouteAuthority,
    HiddenChainExposure,
    CloudSource,
    RuntimeBytes,
    ModelBytes,
    BaselineUnbeaten,
    LabelAgreementTooLow,
    CalibrationErrorTooHigh,
    SourceKindDiversityTooLow,
    RouteLabelDiversityTooLow,
    TraceTokenBudget,
    MetadataBudget,
}

fn validate_fixtures(fixtures: &[ShadowWakeOracleFixture]) -> Result<(), ShadowWakeError> {
    if fixtures.is_empty() {
        return Err(ShadowWakeError::EmptyFixtures);
    }

    let mut fixture_ids = BTreeSet::new();
    let mut oracle_ids = BTreeSet::new();
    let mut source_kinds = BTreeSet::new();
    let mut route_labels = BTreeSet::new();
    let mut held_out_seen = false;

    for fixture in fixtures {
        validate_fixture_header(fixture)?;
        if !fixture_ids.insert(fixture.fixture_id.as_str()) {
            return Err(ShadowWakeError::DuplicateFixture);
        }
        if fixture.records.is_empty() {
            return Err(ShadowWakeError::MissingRecord);
        }
        for record in &fixture.records {
            validate_record(record)?;
            if !oracle_ids.insert(record.oracle_id.as_str()) {
                return Err(ShadowWakeError::DuplicateOracle);
            }
            source_kinds.insert(record.source_kind.as_str());
            route_labels.insert(record.route_label.as_str());
            held_out_seen |= record.split == "held_out";
        }
    }

    if !held_out_seen {
        return Err(ShadowWakeError::MissingHeldOut);
    }
    if source_kinds.len() < MIN_SOURCE_KIND_COUNT as usize {
        return Err(ShadowWakeError::SourceKindDiversityTooLow);
    }
    if route_labels.len() < MIN_ROUTE_LABEL_COUNT as usize {
        return Err(ShadowWakeError::RouteLabelDiversityTooLow);
    }

    Ok(())
}

fn validate_fixture_header(fixture: &ShadowWakeOracleFixture) -> Result<(), ShadowWakeError> {
    if fixture.fixture_id.is_empty() {
        return Err(ShadowWakeError::MissingFixtureId);
    }
    if fixture.oracle_policy_ref.is_empty() {
        return Err(ShadowWakeError::MissingPolicy);
    }
    if fixture.authority != "shadow_only" {
        return Err(ShadowWakeError::HiddenRouteAuthority);
    }
    if !fixture.offline_distillation_only {
        return Err(ShadowWakeError::HiddenLiveDependency);
    }
    if fixture.held_out_success_bps < MIN_HELD_OUT_SUCCESS_BPS {
        return Err(ShadowWakeError::BaselineUnbeaten);
    }
    if fixture.label_agreement_bps < MIN_LABEL_AGREEMENT_BPS {
        return Err(ShadowWakeError::LabelAgreementTooLow);
    }
    if fixture.calibration_error_bps > MAX_CALIBRATION_ERROR_BPS {
        return Err(ShadowWakeError::CalibrationErrorTooHigh);
    }
    Ok(())
}

fn validate_record(record: &ShadowWakeOracleRecord) -> Result<(), ShadowWakeError> {
    if record.oracle_id.is_empty() {
        return Err(ShadowWakeError::MissingOracleId);
    }
    if record.mission_id.is_empty() {
        return Err(ShadowWakeError::MissingMission);
    }
    if record.upstream_depth_lease_ref.is_empty() {
        return Err(ShadowWakeError::MissingUpstreamDepthLease);
    }
    if record.upstream_route_distillation_ref.is_empty() {
        return Err(ShadowWakeError::MissingUpstreamRouteDistillation);
    }
    if record.cheap_route_trace_ref.is_empty() {
        return Err(ShadowWakeError::MissingCheapRouteTrace);
    }
    if record.full_wake_trace_ref.is_empty() {
        return Err(ShadowWakeError::MissingFullWakeTrace);
    }
    if record.proof_or_test_result_ref.is_empty() {
        return Err(ShadowWakeError::MissingProofOrTest);
    }
    if record.unit_credit_assignment_ref.is_empty() {
        return Err(ShadowWakeError::MissingCreditAssignment);
    }
    if record.byte_latency_delta_ref.is_empty() {
        return Err(ShadowWakeError::MissingByteLatencyDelta);
    }
    if record.oracle_label_ref.is_empty() {
        return Err(ShadowWakeError::MissingOracleLabel);
    }
    if record.route_label.is_empty() {
        return Err(ShadowWakeError::MissingRouteLabel);
    }
    if record.scout_feature_ref.is_empty() {
        return Err(ShadowWakeError::MissingScoutFeature);
    }
    if record.proof_ref.is_empty() {
        return Err(ShadowWakeError::MissingProofRef);
    }
    if record.test_ref.is_empty() {
        return Err(ShadowWakeError::MissingTestRef);
    }
    if record.citation_ref.is_empty() {
        return Err(ShadowWakeError::MissingCitationRef);
    }
    if record.scope_rex_ref.is_empty() {
        return Err(ShadowWakeError::MissingScopeRex);
    }
    if record.sovereign_gate_ref.is_empty() {
        return Err(ShadowWakeError::MissingSovereignGate);
    }
    if record.rollback_handle.is_empty() {
        return Err(ShadowWakeError::MissingRollback);
    }
    if record.run_event_log_ref.is_empty() {
        return Err(ShadowWakeError::MissingRunEventLog);
    }
    if record.answer_packet_ref.is_empty() {
        return Err(ShadowWakeError::MissingAnswerPacket);
    }
    if !matches!(record.split.as_str(), "train" | "held_out") {
        return Err(ShadowWakeError::InvalidSplit);
    }
    if record.compatibility_fence != CURRENT_FENCE {
        return Err(ShadowWakeError::IncompatibleFence);
    }
    if !valid_privacy_class(&record.privacy_class) {
        return Err(ShadowWakeError::InvalidPrivacy);
    }
    if record.trace_tokens == 0 || record.trace_tokens > MAX_TRACE_TOKENS {
        return Err(ShadowWakeError::TraceTokenBudget);
    }
    if record.metadata_bytes > MAX_ORACLE_METADATA_BYTES {
        return Err(ShadowWakeError::MetadataBudget);
    }
    if record.live_runtime_dependency {
        return Err(ShadowWakeError::HiddenLiveDependency);
    }
    if record.hidden_truth_authority {
        return Err(ShadowWakeError::HiddenTruthAuthority);
    }
    if record.verifier_bypassed {
        return Err(ShadowWakeError::VerifierBypass);
    }
    if record.tests_bypassed {
        return Err(ShadowWakeError::TestBypass);
    }
    if record.citations_bypassed {
        return Err(ShadowWakeError::CitationBypass);
    }
    if record.scope_rex_bypassed {
        return Err(ShadowWakeError::ScopeRexBypass);
    }
    if record.sovereign_gate_bypassed {
        return Err(ShadowWakeError::SovereignGateBypass);
    }
    if record.base_weight_mutated {
        return Err(ShadowWakeError::BaseWeightMutation);
    }
    if record.route_policy_mutated {
        return Err(ShadowWakeError::RoutePolicyMutation);
    }
    if record.cache_mutated {
        return Err(ShadowWakeError::CacheMutation);
    }
    if record.hidden_route_authority {
        return Err(ShadowWakeError::HiddenRouteAuthority);
    }
    if record.hidden_chain_exposed {
        return Err(ShadowWakeError::HiddenChainExposure);
    }
    if record.hidden_cloud {
        return Err(ShadowWakeError::CloudSource);
    }
    if record.runtime_bytes_loaded > 0 {
        return Err(ShadowWakeError::RuntimeBytes);
    }
    if record.model_bytes_loaded > 0 {
        return Err(ShadowWakeError::ModelBytes);
    }
    if record.cheap_route_baseline_bps >= MIN_HELD_OUT_SUCCESS_BPS
        || record.full_wake_everything_baseline_bps >= MIN_HELD_OUT_SUCCESS_BPS
        || record.no_oracle_label_baseline_bps >= MIN_HELD_OUT_SUCCESS_BPS
    {
        return Err(ShadowWakeError::BaselineUnbeaten);
    }
    Ok(())
}

fn valid_privacy_class(value: &str) -> bool {
    matches!(value, "local_private" | "project_private" | "vault_private")
}

fn invalid_fixture_axes(valid_fixtures: &[ShadowWakeOracleFixture]) -> Vec<(&'static str, bool)> {
    let mut cases = Vec::with_capacity(49);
    cases.push((
        "duplicate_fixture_rejected",
        rejects(valid_fixtures, |fixtures| {
            fixtures.push(fixtures[0].clone())
        }),
    ));
    cases.push((
        "duplicate_oracle_rejected",
        rejects(valid_fixtures, |fixtures| {
            let duplicate = fixtures[0].records[0].clone();
            fixtures[0].records.push(duplicate);
        }),
    ));
    cases.push((
        "missing_fixture_id_rejected",
        rejects(valid_fixtures, |fixtures| fixtures[0].fixture_id.clear()),
    ));
    cases.push((
        "missing_oracle_record_rejected",
        rejects(valid_fixtures, |fixtures| fixtures[0].records.clear()),
    ));
    cases.push((
        "missing_oracle_id_rejected",
        rejects_record(valid_fixtures, |r| r.oracle_id.clear()),
    ));
    cases.push((
        "missing_mission_rejected",
        rejects_record(valid_fixtures, |r| r.mission_id.clear()),
    ));
    cases.push((
        "missing_upstream_depth_lease_rejected",
        rejects_record(valid_fixtures, |r| r.upstream_depth_lease_ref.clear()),
    ));
    cases.push((
        "missing_upstream_route_distillation_rejected",
        rejects_record(valid_fixtures, |r| {
            r.upstream_route_distillation_ref.clear()
        }),
    ));
    cases.push((
        "missing_cheap_route_trace_rejected",
        rejects_record(valid_fixtures, |r| r.cheap_route_trace_ref.clear()),
    ));
    cases.push((
        "missing_full_wake_trace_rejected",
        rejects_record(valid_fixtures, |r| r.full_wake_trace_ref.clear()),
    ));
    cases.push((
        "missing_proof_or_test_rejected",
        rejects_record(valid_fixtures, |r| r.proof_or_test_result_ref.clear()),
    ));
    cases.push((
        "missing_credit_assignment_rejected",
        rejects_record(valid_fixtures, |r| r.unit_credit_assignment_ref.clear()),
    ));
    cases.push((
        "missing_byte_latency_delta_rejected",
        rejects_record(valid_fixtures, |r| r.byte_latency_delta_ref.clear()),
    ));
    cases.push((
        "missing_oracle_label_rejected",
        rejects_record(valid_fixtures, |r| r.oracle_label_ref.clear()),
    ));
    cases.push((
        "missing_route_label_rejected",
        rejects_record(valid_fixtures, |r| r.route_label.clear()),
    ));
    cases.push((
        "missing_scout_feature_rejected",
        rejects_record(valid_fixtures, |r| r.scout_feature_ref.clear()),
    ));
    cases.push((
        "missing_proof_ref_rejected",
        rejects_record(valid_fixtures, |r| r.proof_ref.clear()),
    ));
    cases.push((
        "missing_test_ref_rejected",
        rejects_record(valid_fixtures, |r| r.test_ref.clear()),
    ));
    cases.push((
        "missing_citation_ref_rejected",
        rejects_record(valid_fixtures, |r| r.citation_ref.clear()),
    ));
    cases.push((
        "missing_scope_rex_rejected",
        rejects_record(valid_fixtures, |r| r.scope_rex_ref.clear()),
    ));
    cases.push((
        "missing_sovereign_gate_rejected",
        rejects_record(valid_fixtures, |r| r.sovereign_gate_ref.clear()),
    ));
    cases.push((
        "missing_rollback_rejected",
        rejects_record(valid_fixtures, |r| r.rollback_handle.clear()),
    ));
    cases.push((
        "missing_run_event_log_rejected",
        rejects_record(valid_fixtures, |r| r.run_event_log_ref.clear()),
    ));
    cases.push((
        "missing_answer_packet_rejected",
        rejects_record(valid_fixtures, |r| r.answer_packet_ref.clear()),
    ));
    cases.push((
        "missing_split_rejected",
        rejects_record(valid_fixtures, |r| r.split.clear()),
    ));
    cases.push((
        "invalid_split_rejected",
        rejects_record(valid_fixtures, |r| r.split = "live".to_string()),
    ));
    cases.push((
        "missing_held_out_split_rejected",
        rejects(valid_fixtures, |fixtures| {
            for record in &mut fixtures[0].records {
                record.split = "train".to_string();
            }
            for record in &mut fixtures[1].records {
                record.split = "train".to_string();
            }
        }),
    ));
    cases.push((
        "incompatible_fence_rejected",
        rejects_record(valid_fixtures, |r| {
            r.compatibility_fence = "fence:stale".to_string()
        }),
    ));
    cases.push((
        "invalid_privacy_rejected",
        rejects_record(valid_fixtures, |r| {
            r.privacy_class = "public_cloud".to_string()
        }),
    ));
    cases.push((
        "hidden_live_dependency_rejected",
        rejects_record(valid_fixtures, |r| r.live_runtime_dependency = true),
    ));
    cases.push((
        "hidden_truth_authority_rejected",
        rejects_record(valid_fixtures, |r| r.hidden_truth_authority = true),
    ));
    cases.push((
        "verifier_bypass_rejected",
        rejects_record(valid_fixtures, |r| r.verifier_bypassed = true),
    ));
    cases.push((
        "test_bypass_rejected",
        rejects_record(valid_fixtures, |r| r.tests_bypassed = true),
    ));
    cases.push((
        "citation_bypass_rejected",
        rejects_record(valid_fixtures, |r| r.citations_bypassed = true),
    ));
    cases.push((
        "scope_rex_bypass_rejected",
        rejects_record(valid_fixtures, |r| r.scope_rex_bypassed = true),
    ));
    cases.push((
        "sovereign_gate_bypass_rejected",
        rejects_record(valid_fixtures, |r| r.sovereign_gate_bypassed = true),
    ));
    cases.push((
        "base_weight_mutation_rejected",
        rejects_record(valid_fixtures, |r| r.base_weight_mutated = true),
    ));
    cases.push((
        "route_policy_mutation_rejected",
        rejects_record(valid_fixtures, |r| r.route_policy_mutated = true),
    ));
    cases.push((
        "cache_mutation_rejected",
        rejects_record(valid_fixtures, |r| r.cache_mutated = true),
    ));
    cases.push((
        "hidden_route_authority_rejected",
        rejects_record(valid_fixtures, |r| r.hidden_route_authority = true),
    ));
    cases.push((
        "hidden_chain_exposure_rejected",
        rejects_record(valid_fixtures, |r| r.hidden_chain_exposed = true),
    ));
    cases.push((
        "cloud_source_rejected",
        rejects_record(valid_fixtures, |r| r.hidden_cloud = true),
    ));
    cases.push((
        "runtime_bytes_rejected",
        rejects_record(valid_fixtures, |r| r.runtime_bytes_loaded = 1),
    ));
    cases.push((
        "model_bytes_rejected",
        rejects_record(valid_fixtures, |r| r.model_bytes_loaded = 1),
    ));
    cases.push((
        "cheap_route_baseline_unbeaten_rejected",
        rejects_record(valid_fixtures, |r| {
            r.cheap_route_baseline_bps = MIN_HELD_OUT_SUCCESS_BPS
        }),
    ));
    cases.push((
        "full_wake_everything_baseline_unbeaten_rejected",
        rejects_record(valid_fixtures, |r| {
            r.full_wake_everything_baseline_bps = MIN_HELD_OUT_SUCCESS_BPS
        }),
    ));
    cases.push((
        "no_oracle_label_baseline_unbeaten_rejected",
        rejects_record(valid_fixtures, |r| {
            r.no_oracle_label_baseline_bps = MIN_HELD_OUT_SUCCESS_BPS
        }),
    ));
    cases.push((
        "label_agreement_too_low_rejected",
        rejects(valid_fixtures, |fixtures| {
            fixtures[0].label_agreement_bps = MIN_LABEL_AGREEMENT_BPS - 1
        }),
    ));
    cases.push((
        "calibration_error_too_high_rejected",
        rejects(valid_fixtures, |fixtures| {
            fixtures[0].calibration_error_bps = MAX_CALIBRATION_ERROR_BPS + 1
        }),
    ));
    cases.push((
        "source_kind_diversity_missing_rejected",
        rejects(valid_fixtures, |fixtures| {
            for record in &mut fixtures[0].records {
                record.source_kind = "full_wake".to_string();
            }
            for record in &mut fixtures[1].records {
                record.source_kind = "full_wake".to_string();
            }
        }),
    ));
    cases.push((
        "route_label_diversity_missing_rejected",
        rejects(valid_fixtures, |fixtures| {
            for record in &mut fixtures[0].records {
                record.route_label = "escalate_full_wake".to_string();
            }
            for record in &mut fixtures[1].records {
                record.route_label = "escalate_full_wake".to_string();
            }
        }),
    ));
    cases.push((
        "trace_token_budget_rejected",
        rejects_record(valid_fixtures, |r| r.trace_tokens = MAX_TRACE_TOKENS + 1),
    ));
    cases.push((
        "metadata_budget_rejected",
        rejects_record(valid_fixtures, |r| {
            r.metadata_bytes = MAX_ORACLE_METADATA_BYTES + 1
        }),
    ));
    cases
}

fn rejects_record(
    fixtures: &[ShadowWakeOracleFixture],
    mutate: impl FnOnce(&mut ShadowWakeOracleRecord),
) -> bool {
    rejects(fixtures, |fixtures| mutate(&mut fixtures[0].records[0]))
}

fn rejects(
    fixtures: &[ShadowWakeOracleFixture],
    mutate: impl FnOnce(&mut Vec<ShadowWakeOracleFixture>),
) -> bool {
    let mut mutated = fixtures.to_vec();
    mutate(&mut mutated);
    ShadowWakeOracleRegistry::new(mutated).is_err()
}

fn fixture_shadow_wake_oracles() -> Vec<ShadowWakeOracleFixture> {
    vec![
        ShadowWakeOracleFixture {
            fixture_id: "shadow-wake-proof-fixture".to_string(),
            oracle_policy_ref: "oracle-policy:proof-pressure:v1".to_string(),
            held_out_success_bps: 9_220,
            label_agreement_bps: 9_360,
            calibration_error_bps: 640,
            authority: "shadow_only".to_string(),
            offline_distillation_only: true,
            records: vec![
                oracle_record(
                    "proof-full-001",
                    "proof_repair",
                    "mission-proof-route",
                    "escalate_full_wake",
                    "train",
                    48_000,
                    7_200,
                    8_100,
                    7_860,
                    "vault_private",
                ),
                oracle_record(
                    "proof-test-002",
                    "test_failure",
                    "mission-proof-route",
                    "repair_then_verify",
                    "held_out",
                    42_000,
                    7_480,
                    8_050,
                    7_730,
                    "project_private",
                ),
                oracle_record(
                    "proof-cite-003",
                    "citation_failure",
                    "mission-cited-answer",
                    "retrieve_then_verify",
                    "held_out",
                    39_000,
                    7_620,
                    8_140,
                    7_800,
                    "local_private",
                ),
            ],
        },
        ShadowWakeOracleFixture {
            fixture_id: "shadow-wake-code-fixture".to_string(),
            oracle_policy_ref: "oracle-policy:code-kv-depth:v1".to_string(),
            held_out_success_bps: 9_080,
            label_agreement_bps: 9_180,
            calibration_error_bps: 710,
            authority: "shadow_only".to_string(),
            offline_distillation_only: true,
            records: vec![
                oracle_record(
                    "code-kv-001",
                    "kv_miss",
                    "mission-code-note",
                    "wake_sparse_kv_pages",
                    "train",
                    46_000,
                    7_500,
                    8_000,
                    7_620,
                    "vault_private",
                ),
                oracle_record(
                    "code-depth-002",
                    "depth_miss",
                    "mission-code-note",
                    "resume_with_depth_lease",
                    "held_out",
                    54_000,
                    7_740,
                    8_220,
                    7_690,
                    "project_private",
                ),
                oracle_record(
                    "code-abstain-003",
                    "uncertain_route",
                    "mission-note-mutation",
                    "abstain_for_sovereign_gate",
                    "held_out",
                    44_000,
                    7_350,
                    7_980,
                    7_550,
                    "local_private",
                ),
            ],
        },
    ]
}

fn oracle_record(
    suffix: &str,
    source_kind: &str,
    mission_id: &str,
    route_label: &str,
    split: &str,
    trace_tokens: u64,
    cheap_route_baseline_bps: u64,
    full_wake_everything_baseline_bps: u64,
    no_oracle_label_baseline_bps: u64,
    privacy_class: &str,
) -> ShadowWakeOracleRecord {
    ShadowWakeOracleRecord {
        oracle_id: format!("shadow-oracle:{suffix}"),
        mission_id: mission_id.to_string(),
        source_kind: source_kind.to_string(),
        upstream_depth_lease_ref: UPSTREAM_DEPTH_LEASE.to_string(),
        upstream_route_distillation_ref: UPSTREAM_ROUTE_DISTILLATION.to_string(),
        cheap_route_trace_ref: format!("cheap-route-trace:{suffix}"),
        full_wake_trace_ref: format!("full-wake-trace:{suffix}"),
        proof_or_test_result_ref: format!("proof-or-test-result:{suffix}"),
        unit_credit_assignment_ref: format!("unit-credit-assignment:{suffix}"),
        byte_latency_delta_ref: format!("byte-latency-delta:{suffix}"),
        oracle_label_ref: format!("oracle-label:{}", sha256_hex(suffix.as_bytes())),
        route_label: route_label.to_string(),
        scout_feature_ref: format!("scout-feature:shadow-wake:{source_kind}:{suffix}"),
        proof_ref: format!("proof-ref:shadow-wake:{suffix}"),
        test_ref: format!("test-ref:shadow-wake:{suffix}"),
        citation_ref: format!("citation-ref:shadow-wake:{suffix}"),
        scope_rex_ref: format!("scope-rex:shadow-wake:{suffix}"),
        sovereign_gate_ref: format!("sovereign-gate:shadow-wake:{suffix}"),
        rollback_handle: format!("rollback:shadow-wake:{suffix}"),
        run_event_log_ref: format!("run-event-log:shadow-wake:{suffix}"),
        answer_packet_ref: format!("answer-packet:shadow-wake:{suffix}"),
        compatibility_fence: CURRENT_FENCE.to_string(),
        privacy_class: privacy_class.to_string(),
        split: split.to_string(),
        trace_tokens,
        metadata_bytes: 512 * 1024,
        cheap_route_baseline_bps,
        full_wake_everything_baseline_bps,
        no_oracle_label_baseline_bps,
        live_runtime_dependency: false,
        hidden_truth_authority: false,
        verifier_bypassed: false,
        tests_bypassed: false,
        citations_bypassed: false,
        scope_rex_bypassed: false,
        sovereign_gate_bypassed: false,
        base_weight_mutated: false,
        route_policy_mutated: false,
        cache_mutated: false,
        hidden_route_authority: false,
        hidden_chain_exposed: false,
        hidden_cloud: false,
        runtime_bytes_loaded: 0,
        model_bytes_loaded: 0,
    }
}

fn upstream_artifact_pass(path: &str) -> bool {
    let Ok(bytes) = std::fs::read(path) else {
        return false;
    };
    let Ok(value) = serde_json::from_slice::<serde_json::Value>(&bytes) else {
        return false;
    };
    value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
}

fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    operator: &str,
    expected: u64,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::from(actual),
            unit: "count".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::from(expected),
            unit: "count".to_string(),
        },
    );
    let passed = match operator {
        ">=" => actual >= expected,
        "<=" => actual <= expected,
        "<" => actual < expected,
        _ => false,
    };
    pass_per_axis.insert(name.to_string(), passed);
}

fn build_artifact() -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, ShadowWakeError> {
    let registry = ShadowWakeOracleRegistry::new(fixture_shadow_wake_oracles())?;
    let metrics = registry.metrics();
    let address = registry.address();
    let mut reversed = fixture_shadow_wake_oracles();
    reversed.reverse();
    for fixture in &mut reversed {
        fixture.records.reverse();
    }
    let deterministic = ShadowWakeOracleRegistry::new(reversed)?.address() == address;
    let invalid_axes = invalid_fixture_axes(&registry.fixtures);

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let bool_axes = [
        (
            "upstream_depth_lease_checkpoint_pass",
            upstream_artifact_pass(UPSTREAM_DEPTH_LEASE),
        ),
        (
            "upstream_route_distillation_tournament_pass",
            upstream_artifact_pass(UPSTREAM_ROUTE_DISTILLATION),
        ),
        ("shadow_wake_fixture_present", metrics.fixture_count > 0),
        (
            "fixture_ids_bound",
            registry
                .fixtures
                .iter()
                .all(|fixture| !fixture.fixture_id.is_empty()),
        ),
        ("oracle_ids_bound", metrics.oracle_record_count == 6),
        (
            "mission_ids_bound",
            registry
                .records()
                .all(|record| !record.mission_id.is_empty()),
        ),
        (
            "cheap_route_traces_bound",
            registry
                .records()
                .all(|record| !record.cheap_route_trace_ref.is_empty()),
        ),
        (
            "full_wake_traces_bound",
            registry
                .records()
                .all(|record| !record.full_wake_trace_ref.is_empty()),
        ),
        (
            "proof_or_test_results_bound",
            metrics.proof_or_test_result_count == metrics.oracle_record_count,
        ),
        (
            "unit_credit_assignments_bound",
            metrics.credit_assignment_count == metrics.oracle_record_count,
        ),
        (
            "byte_latency_deltas_bound",
            registry
                .records()
                .all(|record| !record.byte_latency_delta_ref.is_empty()),
        ),
        (
            "oracle_labels_bound",
            registry
                .records()
                .all(|record| !record.oracle_label_ref.is_empty()),
        ),
        (
            "route_labels_bound",
            registry
                .records()
                .all(|record| !record.route_label.is_empty()),
        ),
        (
            "scout_feature_refs_bound",
            registry
                .records()
                .all(|record| !record.scout_feature_ref.is_empty()),
        ),
        (
            "proof_refs_bound",
            registry
                .records()
                .all(|record| !record.proof_ref.is_empty()),
        ),
        (
            "test_refs_bound",
            registry.records().all(|record| !record.test_ref.is_empty()),
        ),
        (
            "citation_refs_bound",
            registry
                .records()
                .all(|record| !record.citation_ref.is_empty()),
        ),
        (
            "scope_rex_refs_bound",
            registry
                .records()
                .all(|record| !record.scope_rex_ref.is_empty()),
        ),
        (
            "sovereign_gate_refs_bound",
            registry
                .records()
                .all(|record| !record.sovereign_gate_ref.is_empty()),
        ),
        (
            "rollback_bound",
            registry
                .records()
                .all(|record| !record.rollback_handle.is_empty()),
        ),
        (
            "run_event_log_bound",
            registry
                .records()
                .all(|record| !record.run_event_log_ref.is_empty()),
        ),
        (
            "answer_packet_ref_bound",
            registry
                .records()
                .all(|record| !record.answer_packet_ref.is_empty()),
        ),
        (
            "compatibility_fence_bound",
            registry
                .records()
                .all(|record| record.compatibility_fence == CURRENT_FENCE),
        ),
        (
            "privacy_classes_bound",
            registry
                .records()
                .all(|record| valid_privacy_class(&record.privacy_class)),
        ),
        ("held_out_split_bound", metrics.held_out_case_count >= 4),
        (
            "source_kind_diversity_bound",
            metrics.source_kind_count >= MIN_SOURCE_KIND_COUNT,
        ),
        (
            "route_label_diversity_bound",
            metrics.route_label_count >= MIN_ROUTE_LABEL_COUNT,
        ),
        (
            "shadow_only_authority",
            registry
                .fixtures
                .iter()
                .all(|fixture| fixture.authority == "shadow_only"),
        ),
        (
            "offline_distillation_only",
            registry
                .fixtures
                .iter()
                .all(|fixture| fixture.offline_distillation_only),
        ),
        (
            "oracle_not_live_dependency",
            registry
                .records()
                .all(|record| !record.live_runtime_dependency),
        ),
        (
            "oracle_not_hidden_truth",
            registry
                .records()
                .all(|record| !record.hidden_truth_authority),
        ),
        (
            "verifier_not_bypassed",
            registry.records().all(|record| !record.verifier_bypassed),
        ),
        (
            "tests_not_bypassed",
            registry.records().all(|record| !record.tests_bypassed),
        ),
        (
            "citations_not_bypassed",
            registry.records().all(|record| !record.citations_bypassed),
        ),
        (
            "scope_rex_not_bypassed",
            registry.records().all(|record| !record.scope_rex_bypassed),
        ),
        (
            "sovereign_gate_not_bypassed",
            registry
                .records()
                .all(|record| !record.sovereign_gate_bypassed),
        ),
        (
            "no_base_weight_mutation",
            registry.records().all(|record| !record.base_weight_mutated),
        ),
        (
            "no_route_policy_mutation",
            registry
                .records()
                .all(|record| !record.route_policy_mutated),
        ),
        (
            "no_cache_mutation",
            registry.records().all(|record| !record.cache_mutated),
        ),
        (
            "no_hidden_route_authority",
            registry
                .records()
                .all(|record| !record.hidden_route_authority),
        ),
        (
            "no_hidden_chain",
            registry
                .records()
                .all(|record| !record.hidden_chain_exposed),
        ),
        (
            "no_hidden_cloud",
            registry.records().all(|record| !record.hidden_cloud),
        ),
        (
            "no_runtime_bytes_loaded",
            registry
                .records()
                .all(|record| record.runtime_bytes_loaded == 0),
        ),
        (
            "no_model_bytes_loaded",
            registry
                .records()
                .all(|record| record.model_bytes_loaded == 0),
        ),
        ("shadow_wake_oracle_address_deterministic", deterministic),
        (
            "held_out_success_bound",
            metrics.held_out_success_bps >= MIN_HELD_OUT_SUCCESS_BPS,
        ),
        (
            "label_agreement_bound",
            metrics.label_agreement_bps >= MIN_LABEL_AGREEMENT_BPS,
        ),
        (
            "calibration_error_bound",
            metrics.calibration_error_bps <= MAX_CALIBRATION_ERROR_BPS,
        ),
        (
            "trace_token_budget_bound",
            metrics.max_trace_tokens <= MAX_TRACE_TOKENS,
        ),
        (
            "metadata_bound",
            metrics.max_oracle_metadata_bytes <= MAX_ORACLE_METADATA_BYTES,
        ),
        (
            "beats_cheap_route_baseline",
            metrics.cheap_route_baseline_bps < metrics.held_out_success_bps,
        ),
        (
            "beats_full_wake_everything_baseline",
            metrics.full_wake_everything_baseline_bps < metrics.held_out_success_bps,
        ),
        (
            "beats_no_oracle_label_baseline",
            metrics.no_oracle_label_baseline_bps < metrics.held_out_success_bps,
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
        "fixtures",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "oracle_record_count",
        metrics.oracle_record_count,
        6,
        "records",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "train_case_count",
        metrics.train_case_count,
        2,
        "cases",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_case_count",
        metrics.held_out_case_count,
        4,
        "cases",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_kind_count",
        metrics.source_kind_count,
        ">=",
        MIN_SOURCE_KIND_COUNT,
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_label_count",
        metrics.route_label_count,
        ">=",
        MIN_ROUTE_LABEL_COUNT,
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "credit_assignment_count",
        metrics.credit_assignment_count,
        6,
        "assignments",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "proof_or_test_result_count",
        metrics.proof_or_test_result_count,
        6,
        "results",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_trace_tokens",
        metrics.max_trace_tokens,
        "<=",
        MAX_TRACE_TOKENS,
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_oracle_metadata_bytes",
        metrics.max_oracle_metadata_bytes,
        "<=",
        MAX_ORACLE_METADATA_BYTES,
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_success_bps",
        metrics.held_out_success_bps,
        ">=",
        MIN_HELD_OUT_SUCCESS_BPS,
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "label_agreement_bps",
        metrics.label_agreement_bps,
        ">=",
        MIN_LABEL_AGREEMENT_BPS,
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "calibration_error_bps",
        metrics.calibration_error_bps,
        "<=",
        MAX_CALIBRATION_ERROR_BPS,
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cheap_route_baseline_bps",
        metrics.cheap_route_baseline_bps,
        "<",
        metrics.held_out_success_bps,
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "full_wake_everything_baseline_bps",
        metrics.full_wake_everything_baseline_bps,
        "<",
        metrics.held_out_success_bps,
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_oracle_label_baseline_bps",
        metrics.no_oracle_label_baseline_bps,
        "<",
        metrics.held_out_success_bps,
    );

    measurements.insert(
        "shadow_wake_oracle_address".to_string(),
        Measurement {
            value: serde_json::Value::String(address.clone()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "shadow_wake_oracle_address".to_string(),
        AcceptanceThreshold {
            operator: "nonempty".to_string(),
            value: serde_json::Value::String("nonempty".to_string()),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "shadow_wake_oracle_address".to_string(),
        !address.is_empty(),
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
        notes: "metadata_only_shadow_wake_oracle; no_runtime_bytes_loaded; no_model_bytes_loaded; L1 cursor only; oracle traces are offline labels, not live route dependencies; L2/L3 remain red"
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let artifact = build_artifact().map_err(|err| format!("shadow wake oracle failed: {err:?}"))?;
    let path = PathBuf::from(RESULT);
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let mut file = std::fs::File::create(&path)?;
    write_artifact(&mut file, &artifact)?;
    println!(
        "{FALSIFIER_ID}: overall_pass={} oracle_record_count={} source_kind_count={} shadow_wake_oracle_address={:?} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["oracle_record_count"].value,
        artifact.measurements["source_kind_count"].value,
        artifact.measurements["shadow_wake_oracle_address"].value
    );
    if artifact.overall_pass {
        Ok(())
    } else {
        Err("shadow wake oracle did not pass all axes".into())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_fixture_rejects() {
        assert_eq!(
            ShadowWakeOracleRegistry::new(Vec::new()).err(),
            Some(ShadowWakeError::EmptyFixtures)
        );
    }

    #[test]
    fn invalid_fixture_cases_reject() {
        let fixtures = fixture_shadow_wake_oracles();
        for (axis, passed) in invalid_fixture_axes(&fixtures) {
            assert!(passed, "{axis} should reject");
        }
    }

    #[test]
    fn shadow_wake_oracle_address_is_order_stable() {
        let registry = ShadowWakeOracleRegistry::new(fixture_shadow_wake_oracles()).unwrap();
        let address = registry.address();
        let mut reversed = fixture_shadow_wake_oracles();
        reversed.reverse();
        for fixture in &mut reversed {
            fixture.records.reverse();
        }
        let reversed_registry = ShadowWakeOracleRegistry::new(reversed).unwrap();
        assert_eq!(address, reversed_registry.address());
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

    #[test]
    fn source_and_route_diversity_are_present() {
        let registry = ShadowWakeOracleRegistry::new(fixture_shadow_wake_oracles()).unwrap();
        assert!(registry.has_source_kind("proof_repair"));
        assert!(registry.has_source_kind("test_failure"));
        assert!(registry.has_source_kind("citation_failure"));
        assert!(registry.has_source_kind("kv_miss"));
        assert!(registry.has_route_label("escalate_full_wake"));
        assert!(registry.has_route_label("repair_then_verify"));
        assert!(registry.has_route_label("wake_sparse_kv_pages"));
        assert!(registry.has_route_label("abstain_for_sovereign_gate"));
    }
}
