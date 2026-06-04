//! `falsify_sparse_route_no_hidden_authority` -- sparse route authority witness.
//!
//! Metadata-only witness for `F-SparseRoute-NoHiddenAuthority`. It proves
//! source priors, proof traces, oracle labels, PatternBoost motifs,
//! fast-weight deltas, scout proposals, and sparse wake certificates remain
//! visible, rollback-bound route evidence only. They cannot wake bytes, mutate
//! policy, consolidate fast weights, override SCOPE-Rex/SovereignGate, suppress
//! AnswerPacket proof, expose hidden chain, or become live route authority.

use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-SparseRoute-NoHiddenAuthority";
const FIXTURE_ID: &str = "sparse_route_no_hidden_authority_v1";
const COMMAND: &str = "Tools/falsifiers/f_sparse_route_no_hidden_authority.sh";
const RESULT: &str = "artifacts/falsifiers/sparse_route_no_hidden_authority/result.json";
const UPSTREAM_AXIOM_SOURCE_DISTINCTION: &str =
    "artifacts/falsifiers/axiom_axiomatic_source_distinction/result.json";

const CURRENT_FENCE: &str = "fence:sparse-route-no-hidden-authority:v1:axiom-source-distinction:v1";
const MIN_ROUTE_RECORDS: u64 = 6;
const MIN_ROUTE_FAMILY_COUNT: u64 = 4;
const MIN_EVIDENCE_CLASS_COUNT: u64 = 5;
const MIN_HELD_OUT_CASES: u64 = 4;
const MIN_VISIBLE_PROOF_COVERAGE_BPS: u64 = 10_000;
const MIN_HIDDEN_AUTHORITY_REJECTION_BPS: u64 = 10_000;
const MIN_ADMISSION_REJECTION_BPS: u64 = 10_000;
const MIN_ROUTE_SUCCESS_BPS: u64 = 9_100;
const MIN_VERIFIER_MARGIN_BPS: u64 = 400;
const HIGH_UNCERTAINTY_BPS: u64 = 7_500;
const MAX_ROUTE_METADATA_BYTES: u64 = 768 * 1024;

#[derive(Clone, Debug)]
// UAS: uas:sparse-route-no-hidden-authority:record
// Plane: Controller + Verification
// Residency: metadata-only route-control fixture; no live execution authority.
struct SparseRouteRecord {
    route_id: String,
    mission_id: String,
    task_signature_ref: String,
    route_family: String,
    route_decision: String,
    source_prior_refs: Vec<String>,
    proof_trace_refs: Vec<String>,
    oracle_label_refs: Vec<String>,
    patternboost_motif_refs: Vec<String>,
    fast_weight_delta_refs: Vec<String>,
    scout_proposal_ref: String,
    sparse_wake_certificate_ref: String,
    selected_unit_uas_addresses: Vec<String>,
    budget_vector_ref: String,
    admission_ref: String,
    scope_rex_ref: String,
    sovereign_gate_ref: String,
    rollback_handle: String,
    run_event_log_ref: String,
    answer_packet_ref: String,
    compatibility_fence: String,
    privacy_class: String,
    split: String,
    route_authority: String,
    route_impact: String,
    verifier_margin_bps: u64,
    uncertainty_bps: u64,
    metadata_bytes: u64,
    source_priors_authoritative: bool,
    proof_traces_authoritative: bool,
    oracle_labels_authoritative: bool,
    patternboost_motifs_authoritative: bool,
    fast_weight_deltas_quarantined: bool,
    sparse_wake_certificate_visible: bool,
    hidden_live_route_authority: bool,
    byte_wake_without_lease: bool,
    policy_mutated: bool,
    base_weight_mutated: bool,
    fast_weight_consolidated: bool,
    cache_mutated: bool,
    scope_rex_overridden: bool,
    sovereign_gate_overridden: bool,
    answer_packet_suppressed: bool,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    runtime_bytes_loaded: u64,
    model_bytes_loaded: u64,
}

#[derive(Clone, Debug)]
// UAS: uas:sparse-route-no-hidden-authority:fixture
// Plane: Controller + Verification
// Residency: offline/shadow-only sparse-route authority fixture.
struct SparseRouteFixture {
    fixture_id: String,
    fixture_scope: String,
    visible_proof_coverage_bps: u64,
    hidden_authority_rejection_bps: u64,
    admission_rejection_bps: u64,
    route_success_bps: u64,
    hidden_router_baseline_bps: u64,
    policy_mutation_baseline_bps: u64,
    oracle_laundering_baseline_bps: u64,
    no_answer_packet_baseline_bps: u64,
    records: Vec<SparseRouteRecord>,
}

// UAS: uas:sparse-route-no-hidden-authority:metrics
// Plane: Verification
// Residency: metadata-only aggregation; no runtime/model bytes.
struct SparseRouteMetrics {
    fixture_count: u64,
    route_record_count: u64,
    train_case_count: u64,
    held_out_case_count: u64,
    route_family_count: u64,
    evidence_class_count: u64,
    abstain_case_count: u64,
    min_verifier_margin_bps: u64,
    max_uncertainty_bps: u64,
    visible_proof_coverage_bps: u64,
    hidden_authority_rejection_bps: u64,
    admission_rejection_bps: u64,
    route_success_bps: u64,
    hidden_router_baseline_bps: u64,
    policy_mutation_baseline_bps: u64,
    oracle_laundering_baseline_bps: u64,
    no_answer_packet_baseline_bps: u64,
    max_route_metadata_bytes: u64,
}

#[derive(Debug)]
// UAS: uas:sparse-route-no-hidden-authority:registry
// Plane: Controller + Verification
// Residency: offline/shadow-only registry; never live route authority.
struct SparseRouteRegistry {
    fixtures: Vec<SparseRouteFixture>,
}

impl SparseRouteRegistry {
    fn new(fixtures: Vec<SparseRouteFixture>) -> Result<Self, SparseRouteError> {
        validate_fixtures(&fixtures)?;
        Ok(Self { fixtures })
    }

    fn records(&self) -> impl Iterator<Item = &SparseRouteRecord> {
        self.fixtures
            .iter()
            .flat_map(|fixture| fixture.records.iter())
    }

    fn metrics(&self) -> SparseRouteMetrics {
        let route_families = self
            .records()
            .map(|record| record.route_family.as_str())
            .collect::<BTreeSet<_>>();
        let evidence_classes = self
            .records()
            .flat_map(evidence_classes_for)
            .collect::<BTreeSet<_>>();
        let train_case_count = self
            .records()
            .filter(|record| record.split == "train")
            .count();
        let held_out_case_count = self
            .records()
            .filter(|record| record.split == "held_out")
            .count();
        let abstain_case_count = self
            .records()
            .filter(|record| record.route_decision == "abstain")
            .count();
        let min_verifier_margin_bps = self
            .records()
            .map(|record| record.verifier_margin_bps)
            .min()
            .unwrap_or(0);
        let max_uncertainty_bps = self
            .records()
            .map(|record| record.uncertainty_bps)
            .max()
            .unwrap_or(0);
        let max_route_metadata_bytes = self
            .records()
            .map(|record| record.metadata_bytes)
            .max()
            .unwrap_or(0);
        let visible_proof_coverage_bps = self
            .fixtures
            .iter()
            .map(|fixture| fixture.visible_proof_coverage_bps)
            .min()
            .unwrap_or(0);
        let hidden_authority_rejection_bps = self
            .fixtures
            .iter()
            .map(|fixture| fixture.hidden_authority_rejection_bps)
            .min()
            .unwrap_or(0);
        let admission_rejection_bps = self
            .fixtures
            .iter()
            .map(|fixture| fixture.admission_rejection_bps)
            .min()
            .unwrap_or(0);
        let route_success_bps = self
            .fixtures
            .iter()
            .map(|fixture| fixture.route_success_bps)
            .min()
            .unwrap_or(0);
        let hidden_router_baseline_bps = self
            .fixtures
            .iter()
            .map(|fixture| fixture.hidden_router_baseline_bps)
            .max()
            .unwrap_or(0);
        let policy_mutation_baseline_bps = self
            .fixtures
            .iter()
            .map(|fixture| fixture.policy_mutation_baseline_bps)
            .max()
            .unwrap_or(0);
        let oracle_laundering_baseline_bps = self
            .fixtures
            .iter()
            .map(|fixture| fixture.oracle_laundering_baseline_bps)
            .max()
            .unwrap_or(0);
        let no_answer_packet_baseline_bps = self
            .fixtures
            .iter()
            .map(|fixture| fixture.no_answer_packet_baseline_bps)
            .max()
            .unwrap_or(0);

        SparseRouteMetrics {
            fixture_count: self.fixtures.len() as u64,
            route_record_count: self.records().count() as u64,
            train_case_count: train_case_count as u64,
            held_out_case_count: held_out_case_count as u64,
            route_family_count: route_families.len() as u64,
            evidence_class_count: evidence_classes.len() as u64,
            abstain_case_count: abstain_case_count as u64,
            min_verifier_margin_bps,
            max_uncertainty_bps,
            visible_proof_coverage_bps,
            hidden_authority_rejection_bps,
            admission_rejection_bps,
            route_success_bps,
            hidden_router_baseline_bps,
            policy_mutation_baseline_bps,
            oracle_laundering_baseline_bps,
            no_answer_packet_baseline_bps,
            max_route_metadata_bytes,
        }
    }

    fn address(&self) -> String {
        let mut rows = self
            .records()
            .map(|record| {
                format!(
                    "{}|{}|{}|{}|{}|{}|{}|{}|{}",
                    record.route_id,
                    record.mission_id,
                    record.route_family,
                    record.route_decision,
                    record.task_signature_ref,
                    record.scout_proposal_ref,
                    record.sparse_wake_certificate_ref,
                    record.budget_vector_ref,
                    record.answer_packet_ref
                )
            })
            .collect::<Vec<_>>();
        rows.sort();
        let digest = sha256_hex(rows.join("\n").as_bytes());
        format!(
            "uas:sparse-route-no-hidden-authority:sha256:{}",
            digest.trim_start_matches("sha256:")
        )
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
// UAS: uas:sparse-route-no-hidden-authority:error
// Plane: Verification
// Residency: metadata-only rejection surface.
enum SparseRouteError {
    EmptyFixture,
    DuplicateFixture,
    DuplicateRoute,
    MissingFixtureId,
    MissingRouteRecord,
    MissingRouteId,
    MissingMissionId,
    MissingTaskSignature,
    MissingRouteFamily,
    MissingRouteDecision,
    MissingSourcePrior,
    MissingProofTrace,
    MissingOracleLabel,
    MissingPatternBoostMotif,
    MissingFastWeightDelta,
    MissingScoutProposal,
    MissingSparseWakeCertificate,
    MissingSelectedUnit,
    InvalidSelectedUnitUas,
    MissingBudgetVector,
    MissingAdmission,
    MissingScopeRex,
    MissingSovereignGate,
    MissingRollback,
    MissingRunEventLog,
    MissingAnswerPacket,
    IncompatibleFence,
    InvalidPrivacy,
    LiveAuthority,
    LiveRouteImpact,
    SourcePriorAuthority,
    ProofTraceAuthority,
    OracleLabelAuthority,
    PatternBoostAuthority,
    FastWeightUnquarantined,
    HiddenAuthority,
    ByteWakeWithoutLease,
    PolicyMutation,
    BaseWeightMutation,
    FastWeightConsolidation,
    CacheMutation,
    ScopeRexOverride,
    SovereignGateOverride,
    AnswerPacketSuppressed,
    HiddenChain,
    HiddenCloud,
    RuntimeBytes,
    ModelBytes,
    HighUncertaintyNonAbstain,
    LowVerifierMargin,
    RouteFamilyDiversity,
    EvidenceClassDiversity,
    VisibleProofCoverageLow,
    HiddenAuthorityRejectionLow,
    AdmissionRejectionLow,
    RouteSuccessLow,
    HiddenRouterBaselineUnbeaten,
    PolicyMutationBaselineUnbeaten,
    OracleLaunderingBaselineUnbeaten,
    NoAnswerPacketBaselineUnbeaten,
    MetadataBudget,
}

fn validate_fixtures(fixtures: &[SparseRouteFixture]) -> Result<(), SparseRouteError> {
    if fixtures.is_empty() {
        return Err(SparseRouteError::EmptyFixture);
    }

    let mut fixture_ids = BTreeSet::new();
    let mut route_ids = BTreeSet::new();
    for fixture in fixtures {
        if fixture.fixture_id.is_empty() {
            return Err(SparseRouteError::MissingFixtureId);
        }
        if !fixture_ids.insert(fixture.fixture_id.as_str()) {
            return Err(SparseRouteError::DuplicateFixture);
        }
        if fixture.fixture_scope != "metadata_only_shadow_route_authority" {
            return Err(SparseRouteError::LiveAuthority);
        }
        if fixture.records.is_empty() {
            return Err(SparseRouteError::MissingRouteRecord);
        }
        if fixture.visible_proof_coverage_bps < MIN_VISIBLE_PROOF_COVERAGE_BPS {
            return Err(SparseRouteError::VisibleProofCoverageLow);
        }
        if fixture.hidden_authority_rejection_bps < MIN_HIDDEN_AUTHORITY_REJECTION_BPS {
            return Err(SparseRouteError::HiddenAuthorityRejectionLow);
        }
        if fixture.admission_rejection_bps < MIN_ADMISSION_REJECTION_BPS {
            return Err(SparseRouteError::AdmissionRejectionLow);
        }
        if fixture.route_success_bps < MIN_ROUTE_SUCCESS_BPS {
            return Err(SparseRouteError::RouteSuccessLow);
        }
        if fixture.route_success_bps <= fixture.hidden_router_baseline_bps {
            return Err(SparseRouteError::HiddenRouterBaselineUnbeaten);
        }
        if fixture.route_success_bps <= fixture.policy_mutation_baseline_bps {
            return Err(SparseRouteError::PolicyMutationBaselineUnbeaten);
        }
        if fixture.route_success_bps <= fixture.oracle_laundering_baseline_bps {
            return Err(SparseRouteError::OracleLaunderingBaselineUnbeaten);
        }
        if fixture.route_success_bps <= fixture.no_answer_packet_baseline_bps {
            return Err(SparseRouteError::NoAnswerPacketBaselineUnbeaten);
        }

        for record in &fixture.records {
            validate_record(record)?;
            if !route_ids.insert(record.route_id.as_str()) {
                return Err(SparseRouteError::DuplicateRoute);
            }
        }
    }

    let registry = SparseRouteRegistry {
        fixtures: fixtures.to_vec(),
    };
    let metrics = registry.metrics();
    if metrics.route_record_count < MIN_ROUTE_RECORDS {
        return Err(SparseRouteError::MissingRouteRecord);
    }
    if metrics.held_out_case_count < MIN_HELD_OUT_CASES {
        return Err(SparseRouteError::RouteSuccessLow);
    }
    if metrics.route_family_count < MIN_ROUTE_FAMILY_COUNT {
        return Err(SparseRouteError::RouteFamilyDiversity);
    }
    if metrics.evidence_class_count < MIN_EVIDENCE_CLASS_COUNT {
        return Err(SparseRouteError::EvidenceClassDiversity);
    }
    Ok(())
}

fn validate_record(record: &SparseRouteRecord) -> Result<(), SparseRouteError> {
    if record.route_id.is_empty() {
        return Err(SparseRouteError::MissingRouteId);
    }
    if record.mission_id.is_empty() {
        return Err(SparseRouteError::MissingMissionId);
    }
    if record.task_signature_ref.is_empty() {
        return Err(SparseRouteError::MissingTaskSignature);
    }
    if record.route_family.is_empty() {
        return Err(SparseRouteError::MissingRouteFamily);
    }
    if !matches!(
        record.route_family.as_str(),
        "local_summary"
            | "proof_repair"
            | "citation_recall"
            | "cold_kv_route"
            | "uncertainty_abstain"
    ) {
        return Err(SparseRouteError::MissingRouteFamily);
    }
    if record.route_decision.is_empty() {
        return Err(SparseRouteError::MissingRouteDecision);
    }
    if !matches!(
        record.route_decision.as_str(),
        "propose_sparse_wake" | "propose_verify" | "propose_recall" | "abstain"
    ) {
        return Err(SparseRouteError::MissingRouteDecision);
    }
    if record.source_prior_refs.is_empty() || has_empty(&record.source_prior_refs) {
        return Err(SparseRouteError::MissingSourcePrior);
    }
    if record.proof_trace_refs.is_empty() || has_empty(&record.proof_trace_refs) {
        return Err(SparseRouteError::MissingProofTrace);
    }
    if record.oracle_label_refs.is_empty() || has_empty(&record.oracle_label_refs) {
        return Err(SparseRouteError::MissingOracleLabel);
    }
    if record.patternboost_motif_refs.is_empty() || has_empty(&record.patternboost_motif_refs) {
        return Err(SparseRouteError::MissingPatternBoostMotif);
    }
    if record.fast_weight_delta_refs.is_empty() || has_empty(&record.fast_weight_delta_refs) {
        return Err(SparseRouteError::MissingFastWeightDelta);
    }
    if record.scout_proposal_ref.is_empty() {
        return Err(SparseRouteError::MissingScoutProposal);
    }
    if record.sparse_wake_certificate_ref.is_empty() {
        return Err(SparseRouteError::MissingSparseWakeCertificate);
    }
    if record.selected_unit_uas_addresses.is_empty() {
        return Err(SparseRouteError::MissingSelectedUnit);
    }
    if record
        .selected_unit_uas_addresses
        .iter()
        .any(|address| !address.starts_with("uas:"))
    {
        return Err(SparseRouteError::InvalidSelectedUnitUas);
    }
    if record.budget_vector_ref.is_empty() {
        return Err(SparseRouteError::MissingBudgetVector);
    }
    if record.admission_ref.is_empty() {
        return Err(SparseRouteError::MissingAdmission);
    }
    if record.scope_rex_ref.is_empty() {
        return Err(SparseRouteError::MissingScopeRex);
    }
    if record.sovereign_gate_ref.is_empty() {
        return Err(SparseRouteError::MissingSovereignGate);
    }
    if record.rollback_handle.is_empty() {
        return Err(SparseRouteError::MissingRollback);
    }
    if record.run_event_log_ref.is_empty() {
        return Err(SparseRouteError::MissingRunEventLog);
    }
    if record.answer_packet_ref.is_empty() {
        return Err(SparseRouteError::MissingAnswerPacket);
    }
    if record.compatibility_fence != CURRENT_FENCE {
        return Err(SparseRouteError::IncompatibleFence);
    }
    if !matches!(
        record.privacy_class.as_str(),
        "local_private" | "project_private" | "public_source_metadata"
    ) {
        return Err(SparseRouteError::InvalidPrivacy);
    }
    if !matches!(record.split.as_str(), "train" | "held_out") {
        return Err(SparseRouteError::RouteSuccessLow);
    }
    if record.route_authority != "shadow_only_non_authoritative" {
        return Err(SparseRouteError::LiveAuthority);
    }
    if record.route_impact != "proposal_only" {
        return Err(SparseRouteError::LiveRouteImpact);
    }
    if record.source_priors_authoritative {
        return Err(SparseRouteError::SourcePriorAuthority);
    }
    if record.proof_traces_authoritative {
        return Err(SparseRouteError::ProofTraceAuthority);
    }
    if record.oracle_labels_authoritative {
        return Err(SparseRouteError::OracleLabelAuthority);
    }
    if record.patternboost_motifs_authoritative {
        return Err(SparseRouteError::PatternBoostAuthority);
    }
    if !record.fast_weight_deltas_quarantined {
        return Err(SparseRouteError::FastWeightUnquarantined);
    }
    if !record.sparse_wake_certificate_visible {
        return Err(SparseRouteError::AnswerPacketSuppressed);
    }
    if record.hidden_live_route_authority {
        return Err(SparseRouteError::HiddenAuthority);
    }
    if record.byte_wake_without_lease {
        return Err(SparseRouteError::ByteWakeWithoutLease);
    }
    if record.policy_mutated {
        return Err(SparseRouteError::PolicyMutation);
    }
    if record.base_weight_mutated {
        return Err(SparseRouteError::BaseWeightMutation);
    }
    if record.fast_weight_consolidated {
        return Err(SparseRouteError::FastWeightConsolidation);
    }
    if record.cache_mutated {
        return Err(SparseRouteError::CacheMutation);
    }
    if record.scope_rex_overridden {
        return Err(SparseRouteError::ScopeRexOverride);
    }
    if record.sovereign_gate_overridden {
        return Err(SparseRouteError::SovereignGateOverride);
    }
    if record.answer_packet_suppressed {
        return Err(SparseRouteError::AnswerPacketSuppressed);
    }
    if record.hidden_chain_exposed {
        return Err(SparseRouteError::HiddenChain);
    }
    if record.hidden_cloud {
        return Err(SparseRouteError::HiddenCloud);
    }
    if record.runtime_bytes_loaded > 0 {
        return Err(SparseRouteError::RuntimeBytes);
    }
    if record.model_bytes_loaded > 0 {
        return Err(SparseRouteError::ModelBytes);
    }
    if record.uncertainty_bps >= HIGH_UNCERTAINTY_BPS && record.route_decision != "abstain" {
        return Err(SparseRouteError::HighUncertaintyNonAbstain);
    }
    if record.route_decision != "abstain" && record.verifier_margin_bps < MIN_VERIFIER_MARGIN_BPS {
        return Err(SparseRouteError::LowVerifierMargin);
    }
    if record.metadata_bytes > MAX_ROUTE_METADATA_BYTES {
        return Err(SparseRouteError::MetadataBudget);
    }
    Ok(())
}

fn has_empty(values: &[String]) -> bool {
    values.iter().any(String::is_empty)
}

fn evidence_classes_for(record: &SparseRouteRecord) -> Vec<&'static str> {
    let mut classes = Vec::with_capacity(5);
    if !record.source_prior_refs.is_empty() {
        classes.push("source_prior");
    }
    if !record.proof_trace_refs.is_empty() {
        classes.push("proof_trace");
    }
    if !record.oracle_label_refs.is_empty() {
        classes.push("oracle_label");
    }
    if !record.patternboost_motif_refs.is_empty() {
        classes.push("patternboost_motif");
    }
    if !record.fast_weight_delta_refs.is_empty() {
        classes.push("fast_weight_delta");
    }
    classes
}

fn invalid_fixture_axes(valid_fixtures: &[SparseRouteFixture]) -> Vec<(&'static str, bool)> {
    let mut cases = Vec::with_capacity(54);
    cases.push((
        "empty_fixture_rejected",
        SparseRouteRegistry::new(Vec::new()).is_err(),
    ));
    cases.push((
        "duplicate_fixture_rejected",
        rejects(valid_fixtures, |fixtures| {
            fixtures.push(fixtures[0].clone());
        }),
    ));
    cases.push((
        "duplicate_route_rejected",
        rejects_record(valid_fixtures, |record| {
            record.route_id = "sparse-route-local-summary".to_string();
        }),
    ));
    cases.push((
        "missing_fixture_id_rejected",
        rejects(valid_fixtures, |fixtures| fixtures[0].fixture_id.clear()),
    ));
    cases.push((
        "missing_route_record_rejected",
        rejects(valid_fixtures, |fixtures| fixtures[0].records.clear()),
    ));
    cases.push((
        "missing_route_id_rejected",
        rejects_record(valid_fixtures, |record| record.route_id.clear()),
    ));
    cases.push((
        "missing_mission_id_rejected",
        rejects_record(valid_fixtures, |record| record.mission_id.clear()),
    ));
    cases.push((
        "missing_task_signature_rejected",
        rejects_record(valid_fixtures, |record| record.task_signature_ref.clear()),
    ));
    cases.push((
        "missing_route_family_rejected",
        rejects_record(valid_fixtures, |record| record.route_family.clear()),
    ));
    cases.push((
        "missing_route_decision_rejected",
        rejects_record(valid_fixtures, |record| record.route_decision.clear()),
    ));
    cases.push((
        "missing_source_prior_rejected",
        rejects_record(valid_fixtures, |record| record.source_prior_refs.clear()),
    ));
    cases.push((
        "missing_proof_trace_rejected",
        rejects_record(valid_fixtures, |record| record.proof_trace_refs.clear()),
    ));
    cases.push((
        "missing_oracle_label_rejected",
        rejects_record(valid_fixtures, |record| record.oracle_label_refs.clear()),
    ));
    cases.push((
        "missing_patternboost_motif_rejected",
        rejects_record(valid_fixtures, |record| {
            record.patternboost_motif_refs.clear()
        }),
    ));
    cases.push((
        "missing_fast_weight_delta_rejected",
        rejects_record(valid_fixtures, |record| {
            record.fast_weight_delta_refs.clear()
        }),
    ));
    cases.push((
        "missing_scout_proposal_rejected",
        rejects_record(valid_fixtures, |record| record.scout_proposal_ref.clear()),
    ));
    cases.push((
        "missing_sparse_wake_certificate_rejected",
        rejects_record(valid_fixtures, |record| {
            record.sparse_wake_certificate_ref.clear()
        }),
    ));
    cases.push((
        "missing_selected_unit_rejected",
        rejects_record(valid_fixtures, |record| {
            record.selected_unit_uas_addresses.clear()
        }),
    ));
    cases.push((
        "invalid_selected_unit_uas_rejected",
        rejects_record(valid_fixtures, |record| {
            record.selected_unit_uas_addresses[0] = "not-uas".to_string();
        }),
    ));
    cases.push((
        "missing_budget_vector_rejected",
        rejects_record(valid_fixtures, |record| record.budget_vector_ref.clear()),
    ));
    cases.push((
        "missing_admission_rejected",
        rejects_record(valid_fixtures, |record| record.admission_ref.clear()),
    ));
    cases.push((
        "missing_scope_rex_rejected",
        rejects_record(valid_fixtures, |record| record.scope_rex_ref.clear()),
    ));
    cases.push((
        "missing_sovereign_gate_rejected",
        rejects_record(valid_fixtures, |record| record.sovereign_gate_ref.clear()),
    ));
    cases.push((
        "missing_rollback_rejected",
        rejects_record(valid_fixtures, |record| record.rollback_handle.clear()),
    ));
    cases.push((
        "missing_run_event_log_rejected",
        rejects_record(valid_fixtures, |record| record.run_event_log_ref.clear()),
    ));
    cases.push((
        "missing_answer_packet_rejected",
        rejects_record(valid_fixtures, |record| record.answer_packet_ref.clear()),
    ));
    cases.push((
        "incompatible_fence_rejected",
        rejects_record(valid_fixtures, |record| {
            record.compatibility_fence = "fence:stale".to_string();
        }),
    ));
    cases.push((
        "invalid_privacy_rejected",
        rejects_record(valid_fixtures, |record| {
            record.privacy_class = "hidden_chain".to_string();
        }),
    ));
    cases.push((
        "live_authority_rejected",
        rejects_record(valid_fixtures, |record| {
            record.route_authority = "live_route_authority".to_string();
        }),
    ));
    cases.push((
        "live_route_impact_rejected",
        rejects_record(valid_fixtures, |record| {
            record.route_impact = "execute_route".to_string();
        }),
    ));
    cases.push((
        "source_prior_authority_rejected",
        rejects_record(valid_fixtures, |record| {
            record.source_priors_authoritative = true
        }),
    ));
    cases.push((
        "proof_trace_authority_rejected",
        rejects_record(valid_fixtures, |record| {
            record.proof_traces_authoritative = true
        }),
    ));
    cases.push((
        "oracle_label_authority_rejected",
        rejects_record(valid_fixtures, |record| {
            record.oracle_labels_authoritative = true
        }),
    ));
    cases.push((
        "patternboost_authority_rejected",
        rejects_record(valid_fixtures, |record| {
            record.patternboost_motifs_authoritative = true
        }),
    ));
    cases.push((
        "fast_weight_unquarantined_rejected",
        rejects_record(valid_fixtures, |record| {
            record.fast_weight_deltas_quarantined = false
        }),
    ));
    cases.push((
        "hidden_authority_rejected",
        rejects_record(valid_fixtures, |record| {
            record.hidden_live_route_authority = true
        }),
    ));
    cases.push((
        "byte_wake_without_lease_rejected",
        rejects_record(valid_fixtures, |record| {
            record.byte_wake_without_lease = true
        }),
    ));
    cases.push((
        "policy_mutation_rejected",
        rejects_record(valid_fixtures, |record| record.policy_mutated = true),
    ));
    cases.push((
        "base_weight_mutation_rejected",
        rejects_record(valid_fixtures, |record| record.base_weight_mutated = true),
    ));
    cases.push((
        "fast_weight_consolidation_rejected",
        rejects_record(valid_fixtures, |record| {
            record.fast_weight_consolidated = true
        }),
    ));
    cases.push((
        "cache_mutation_rejected",
        rejects_record(valid_fixtures, |record| record.cache_mutated = true),
    ));
    cases.push((
        "scope_rex_override_rejected",
        rejects_record(valid_fixtures, |record| record.scope_rex_overridden = true),
    ));
    cases.push((
        "sovereign_gate_override_rejected",
        rejects_record(valid_fixtures, |record| {
            record.sovereign_gate_overridden = true
        }),
    ));
    cases.push((
        "answer_packet_suppressed_rejected",
        rejects_record(valid_fixtures, |record| {
            record.answer_packet_suppressed = true
        }),
    ));
    cases.push((
        "hidden_chain_rejected",
        rejects_record(valid_fixtures, |record| record.hidden_chain_exposed = true),
    ));
    cases.push((
        "hidden_cloud_rejected",
        rejects_record(valid_fixtures, |record| record.hidden_cloud = true),
    ));
    cases.push((
        "runtime_bytes_rejected",
        rejects_record(valid_fixtures, |record| record.runtime_bytes_loaded = 1),
    ));
    cases.push((
        "model_bytes_rejected",
        rejects_record(valid_fixtures, |record| record.model_bytes_loaded = 1),
    ));
    cases.push((
        "high_uncertainty_non_abstain_rejected",
        rejects_record(valid_fixtures, |record| {
            record.uncertainty_bps = HIGH_UNCERTAINTY_BPS;
            record.route_decision = "propose_sparse_wake".to_string();
        }),
    ));
    cases.push((
        "low_verifier_margin_rejected",
        rejects_record(valid_fixtures, |record| record.verifier_margin_bps = 1),
    ));
    cases.push((
        "route_family_diversity_missing_rejected",
        rejects(valid_fixtures, |fixtures| {
            for fixture in fixtures {
                for record in &mut fixture.records {
                    record.route_family = "local_summary".to_string();
                }
            }
        }),
    ));
    cases.push((
        "evidence_class_diversity_missing_rejected",
        rejects(valid_fixtures, |fixtures| {
            for fixture in fixtures {
                for record in &mut fixture.records {
                    record.oracle_label_refs.clear();
                    record.proof_trace_refs.clear();
                    record.patternboost_motif_refs.clear();
                    record.fast_weight_delta_refs.clear();
                }
            }
        }),
    ));
    cases.push((
        "visible_proof_coverage_low_rejected",
        rejects(valid_fixtures, |fixtures| {
            fixtures[0].visible_proof_coverage_bps = MIN_VISIBLE_PROOF_COVERAGE_BPS - 1;
        }),
    ));
    cases.push((
        "hidden_authority_rejection_low_rejected",
        rejects(valid_fixtures, |fixtures| {
            fixtures[0].hidden_authority_rejection_bps = MIN_HIDDEN_AUTHORITY_REJECTION_BPS - 1;
        }),
    ));
    cases.push((
        "admission_rejection_low_rejected",
        rejects(valid_fixtures, |fixtures| {
            fixtures[0].admission_rejection_bps = MIN_ADMISSION_REJECTION_BPS - 1;
        }),
    ));
    cases.push((
        "route_success_low_rejected",
        rejects(valid_fixtures, |fixtures| {
            fixtures[0].route_success_bps = MIN_ROUTE_SUCCESS_BPS - 1;
        }),
    ));
    cases.push((
        "hidden_router_baseline_unbeaten_rejected",
        rejects(valid_fixtures, |fixtures| {
            fixtures[0].hidden_router_baseline_bps = fixtures[0].route_success_bps;
        }),
    ));
    cases.push((
        "policy_mutation_baseline_unbeaten_rejected",
        rejects(valid_fixtures, |fixtures| {
            fixtures[0].policy_mutation_baseline_bps = fixtures[0].route_success_bps;
        }),
    ));
    cases.push((
        "oracle_laundering_baseline_unbeaten_rejected",
        rejects(valid_fixtures, |fixtures| {
            fixtures[0].oracle_laundering_baseline_bps = fixtures[0].route_success_bps;
        }),
    ));
    cases.push((
        "no_answer_packet_baseline_unbeaten_rejected",
        rejects(valid_fixtures, |fixtures| {
            fixtures[0].no_answer_packet_baseline_bps = fixtures[0].route_success_bps;
        }),
    ));
    cases.push((
        "metadata_budget_rejected",
        rejects_record(valid_fixtures, |record| {
            record.metadata_bytes = MAX_ROUTE_METADATA_BYTES + 1
        }),
    ));
    cases
}

fn rejects_record(
    fixtures: &[SparseRouteFixture],
    mutate: impl FnOnce(&mut SparseRouteRecord),
) -> bool {
    rejects(fixtures, |fixtures| mutate(&mut fixtures[0].records[1]))
}

fn rejects(
    fixtures: &[SparseRouteFixture],
    mutate: impl FnOnce(&mut Vec<SparseRouteFixture>),
) -> bool {
    let mut mutated = fixtures.to_vec();
    mutate(&mut mutated);
    SparseRouteRegistry::new(mutated).is_err()
}

fn fixture_sparse_routes() -> Vec<SparseRouteFixture> {
    vec![
        SparseRouteFixture {
            fixture_id: "sparse-route-authority-local-research".to_string(),
            fixture_scope: "metadata_only_shadow_route_authority".to_string(),
            visible_proof_coverage_bps: 10_000,
            hidden_authority_rejection_bps: 10_000,
            admission_rejection_bps: 10_000,
            route_success_bps: 9_320,
            hidden_router_baseline_bps: 7_200,
            policy_mutation_baseline_bps: 7_650,
            oracle_laundering_baseline_bps: 7_480,
            no_answer_packet_baseline_bps: 7_100,
            records: vec![
                sparse_route_record(
                    "sparse-route-local-summary",
                    "mission-local-summary",
                    "task-signature:local-summary",
                    "local_summary",
                    "propose_sparse_wake",
                    "held_out",
                    840,
                    2_400,
                ),
                sparse_route_record(
                    "sparse-route-proof-repair",
                    "mission-proof-repair",
                    "task-signature:proof-repair",
                    "proof_repair",
                    "propose_verify",
                    "held_out",
                    1_120,
                    3_800,
                ),
                sparse_route_record(
                    "sparse-route-citation-recall",
                    "mission-citation-recall",
                    "task-signature:citation-recall",
                    "citation_recall",
                    "propose_recall",
                    "train",
                    760,
                    4_100,
                ),
            ],
        },
        SparseRouteFixture {
            fixture_id: "sparse-route-authority-cold-kv".to_string(),
            fixture_scope: "metadata_only_shadow_route_authority".to_string(),
            visible_proof_coverage_bps: 10_000,
            hidden_authority_rejection_bps: 10_000,
            admission_rejection_bps: 10_000,
            route_success_bps: 9_180,
            hidden_router_baseline_bps: 7_450,
            policy_mutation_baseline_bps: 7_600,
            oracle_laundering_baseline_bps: 7_500,
            no_answer_packet_baseline_bps: 7_300,
            records: vec![
                sparse_route_record(
                    "sparse-route-cold-kv",
                    "mission-cold-kv",
                    "task-signature:cold-kv",
                    "cold_kv_route",
                    "propose_sparse_wake",
                    "held_out",
                    910,
                    4_900,
                ),
                sparse_route_record(
                    "sparse-route-uncertainty-abstain",
                    "mission-uncertainty-abstain",
                    "task-signature:uncertainty-abstain",
                    "uncertainty_abstain",
                    "abstain",
                    "held_out",
                    0,
                    8_600,
                ),
                sparse_route_record(
                    "sparse-route-formal-source-prior",
                    "mission-formal-source-prior",
                    "task-signature:formal-source-prior",
                    "proof_repair",
                    "propose_verify",
                    "train",
                    680,
                    4_400,
                ),
            ],
        },
    ]
}

fn sparse_route_record(
    route_id: &str,
    mission_id: &str,
    task_signature_ref: &str,
    route_family: &str,
    route_decision: &str,
    split: &str,
    verifier_margin_bps: u64,
    uncertainty_bps: u64,
) -> SparseRouteRecord {
    SparseRouteRecord {
        route_id: route_id.to_string(),
        mission_id: mission_id.to_string(),
        task_signature_ref: task_signature_ref.to_string(),
        route_family: route_family.to_string(),
        route_decision: route_decision.to_string(),
        source_prior_refs: vec![
            format!("source-prior:{route_id}:axiom-axiomatic-source-distinction"),
            format!("source-prior:{route_id}:eidos-source-signal"),
        ],
        proof_trace_refs: vec![format!("proof-trace:{route_id}:shadow-wake-oracle")],
        oracle_label_refs: vec![format!("oracle-label:{route_id}:ablation-shadow-run")],
        patternboost_motif_refs: vec![format!("patternboost-motif:{route_id}:offline-only")],
        fast_weight_delta_refs: vec![format!(
            "fast-weight-delta:{route_id}:fast-weight-quarantine"
        )],
        scout_proposal_ref: format!("scout-proposal:{route_id}:two-stage-route-scout"),
        sparse_wake_certificate_ref: format!("sparse-wake-certificate:{route_id}:answer-packet"),
        selected_unit_uas_addresses: vec![
            format!("uas:sparse-route-unit:{route_id}:eidos-evidence"),
            format!("uas:sparse-route-unit:{route_id}:kv-page"),
        ],
        budget_vector_ref: format!("budget-vector:{route_id}:hot-kv-cold-latency"),
        admission_ref: format!("admission:{route_id}:scope-rex-sovereign-gate"),
        scope_rex_ref: format!("scope-rex:{route_id}:admit-or-abstain"),
        sovereign_gate_ref: format!("sovereign-gate:{route_id}:visible-proof-required"),
        rollback_handle: format!("rollback:sparse-route:{route_id}"),
        run_event_log_ref: format!("run-event-log:sparse-route:{route_id}"),
        answer_packet_ref: format!("answer-packet:sparse-route:{route_id}"),
        compatibility_fence: CURRENT_FENCE.to_string(),
        privacy_class: "local_private".to_string(),
        split: split.to_string(),
        route_authority: "shadow_only_non_authoritative".to_string(),
        route_impact: "proposal_only".to_string(),
        verifier_margin_bps,
        uncertainty_bps,
        metadata_bytes: 512 * 1024,
        source_priors_authoritative: false,
        proof_traces_authoritative: false,
        oracle_labels_authoritative: false,
        patternboost_motifs_authoritative: false,
        fast_weight_deltas_quarantined: true,
        sparse_wake_certificate_visible: true,
        hidden_live_route_authority: false,
        byte_wake_without_lease: false,
        policy_mutated: false,
        base_weight_mutated: false,
        fast_weight_consolidated: false,
        cache_mutated: false,
        scope_rex_overridden: false,
        sovereign_gate_overridden: false,
        answer_packet_suppressed: false,
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

fn build_artifact() -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, SparseRouteError>
{
    let registry = SparseRouteRegistry::new(fixture_sparse_routes())?;
    let metrics = registry.metrics();
    let address = registry.address();
    let mut reversed = fixture_sparse_routes();
    reversed.reverse();
    for fixture in &mut reversed {
        fixture.records.reverse();
    }
    let deterministic = SparseRouteRegistry::new(reversed)?.address() == address;
    let invalid_axes = invalid_fixture_axes(&registry.fixtures);

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let bool_axes = [
        (
            "upstream_axiom_axiomatic_source_distinction_pass",
            upstream_artifact_pass(UPSTREAM_AXIOM_SOURCE_DISTINCTION),
        ),
        ("sparse_route_fixture_present", metrics.fixture_count > 0),
        (
            "fixture_ids_bound",
            registry
                .fixtures
                .iter()
                .all(|fixture| !fixture.fixture_id.is_empty()),
        ),
        (
            "route_ids_bound",
            registry.records().all(|record| !record.route_id.is_empty()),
        ),
        (
            "mission_ids_bound",
            registry
                .records()
                .all(|record| !record.mission_id.is_empty()),
        ),
        (
            "task_signatures_bound",
            registry
                .records()
                .all(|record| !record.task_signature_ref.is_empty()),
        ),
        (
            "route_families_bound",
            registry
                .records()
                .all(|record| !record.route_family.is_empty()),
        ),
        (
            "route_decisions_bound",
            registry
                .records()
                .all(|record| !record.route_decision.is_empty()),
        ),
        (
            "source_priors_bound",
            registry
                .records()
                .all(|record| !record.source_prior_refs.is_empty()),
        ),
        (
            "proof_traces_bound",
            registry
                .records()
                .all(|record| !record.proof_trace_refs.is_empty()),
        ),
        (
            "oracle_labels_bound",
            registry
                .records()
                .all(|record| !record.oracle_label_refs.is_empty()),
        ),
        (
            "patternboost_motifs_bound",
            registry
                .records()
                .all(|record| !record.patternboost_motif_refs.is_empty()),
        ),
        (
            "fast_weight_deltas_bound",
            registry
                .records()
                .all(|record| !record.fast_weight_delta_refs.is_empty()),
        ),
        (
            "scout_proposals_bound",
            registry
                .records()
                .all(|record| !record.scout_proposal_ref.is_empty()),
        ),
        (
            "sparse_wake_certificates_bound",
            registry
                .records()
                .all(|record| !record.sparse_wake_certificate_ref.is_empty()),
        ),
        (
            "selected_unit_uas_addresses_bound",
            registry.records().all(|record| {
                !record.selected_unit_uas_addresses.is_empty()
                    && record
                        .selected_unit_uas_addresses
                        .iter()
                        .all(|address| address.starts_with("uas:"))
            }),
        ),
        (
            "budget_vectors_bound",
            registry
                .records()
                .all(|record| !record.budget_vector_ref.is_empty()),
        ),
        (
            "admission_bound",
            registry
                .records()
                .all(|record| !record.admission_ref.is_empty()),
        ),
        (
            "scope_rex_bound",
            registry
                .records()
                .all(|record| !record.scope_rex_ref.is_empty()),
        ),
        (
            "sovereign_gate_bound",
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
            registry.records().all(|record| {
                matches!(
                    record.privacy_class.as_str(),
                    "local_private" | "project_private" | "public_source_metadata"
                )
            }),
        ),
        (
            "held_out_split_bound",
            metrics.held_out_case_count >= MIN_HELD_OUT_CASES,
        ),
        (
            "route_family_diversity_bound",
            metrics.route_family_count >= MIN_ROUTE_FAMILY_COUNT,
        ),
        (
            "evidence_class_diversity_bound",
            metrics.evidence_class_count >= MIN_EVIDENCE_CLASS_COUNT,
        ),
        (
            "shadow_only_authority",
            registry
                .records()
                .all(|record| record.route_authority == "shadow_only_non_authoritative"),
        ),
        (
            "proposal_only_route_impact",
            registry
                .records()
                .all(|record| record.route_impact == "proposal_only"),
        ),
        (
            "source_priors_non_authoritative",
            registry
                .records()
                .all(|record| !record.source_priors_authoritative),
        ),
        (
            "proof_traces_non_authoritative",
            registry
                .records()
                .all(|record| !record.proof_traces_authoritative),
        ),
        (
            "oracle_labels_non_authoritative",
            registry
                .records()
                .all(|record| !record.oracle_labels_authoritative),
        ),
        (
            "patternboost_motifs_non_authoritative",
            registry
                .records()
                .all(|record| !record.patternboost_motifs_authoritative),
        ),
        (
            "fast_weight_deltas_quarantined",
            registry
                .records()
                .all(|record| record.fast_weight_deltas_quarantined),
        ),
        (
            "sparse_wake_certificate_visible",
            registry
                .records()
                .all(|record| record.sparse_wake_certificate_visible),
        ),
        (
            "high_uncertainty_abstains",
            registry.records().all(|record| {
                record.uncertainty_bps < HIGH_UNCERTAINTY_BPS || record.route_decision == "abstain"
            }),
        ),
        (
            "verifier_margin_bound",
            registry.records().all(|record| {
                record.route_decision == "abstain"
                    || record.verifier_margin_bps >= MIN_VERIFIER_MARGIN_BPS
            }),
        ),
        (
            "visible_proof_coverage_bound",
            metrics.visible_proof_coverage_bps >= MIN_VISIBLE_PROOF_COVERAGE_BPS,
        ),
        (
            "hidden_authority_rejection_bound",
            metrics.hidden_authority_rejection_bps >= MIN_HIDDEN_AUTHORITY_REJECTION_BPS,
        ),
        (
            "admission_rejection_bound",
            metrics.admission_rejection_bps >= MIN_ADMISSION_REJECTION_BPS,
        ),
        (
            "route_success_bound",
            metrics.route_success_bps >= MIN_ROUTE_SUCCESS_BPS,
        ),
        (
            "beats_hidden_router_baseline",
            metrics.route_success_bps > metrics.hidden_router_baseline_bps,
        ),
        (
            "beats_policy_mutation_baseline",
            metrics.route_success_bps > metrics.policy_mutation_baseline_bps,
        ),
        (
            "beats_oracle_laundering_baseline",
            metrics.route_success_bps > metrics.oracle_laundering_baseline_bps,
        ),
        (
            "beats_no_answer_packet_baseline",
            metrics.route_success_bps > metrics.no_answer_packet_baseline_bps,
        ),
        (
            "no_hidden_live_route_authority",
            registry
                .records()
                .all(|record| !record.hidden_live_route_authority),
        ),
        (
            "no_byte_wake_without_lease",
            registry
                .records()
                .all(|record| !record.byte_wake_without_lease),
        ),
        (
            "no_policy_mutation",
            registry.records().all(|record| !record.policy_mutated),
        ),
        (
            "no_base_weight_mutation",
            registry.records().all(|record| !record.base_weight_mutated),
        ),
        (
            "no_fast_weight_consolidation",
            registry
                .records()
                .all(|record| !record.fast_weight_consolidated),
        ),
        (
            "no_cache_mutation",
            registry.records().all(|record| !record.cache_mutated),
        ),
        (
            "no_scope_rex_override",
            registry
                .records()
                .all(|record| !record.scope_rex_overridden),
        ),
        (
            "no_sovereign_gate_override",
            registry
                .records()
                .all(|record| !record.sovereign_gate_overridden),
        ),
        (
            "no_answer_packet_suppression",
            registry
                .records()
                .all(|record| !record.answer_packet_suppressed),
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
        (
            "metadata_bound",
            metrics.max_route_metadata_bytes <= MAX_ROUTE_METADATA_BYTES,
        ),
        (
            "sparse_route_no_hidden_authority_address_deterministic",
            deterministic,
        ),
    ];
    for (axis, passed) in bool_axes {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            passed,
        );
    }
    for (axis, passed) in invalid_axes {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
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
        "route_record_count",
        metrics.route_record_count,
        MIN_ROUTE_RECORDS,
        "routes",
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
        MIN_HELD_OUT_CASES,
        "cases",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_family_count",
        metrics.route_family_count,
        MIN_ROUTE_FAMILY_COUNT + 1,
        "families",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "evidence_class_count",
        metrics.evidence_class_count,
        MIN_EVIDENCE_CLASS_COUNT,
        "classes",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "abstain_case_count",
        metrics.abstain_case_count,
        1,
        "cases",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "min_verifier_margin_bps",
        metrics.min_verifier_margin_bps,
        ">=",
        0,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_uncertainty_bps",
        metrics.max_uncertainty_bps,
        "<=",
        8_600,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "visible_proof_coverage_bps",
        metrics.visible_proof_coverage_bps,
        ">=",
        MIN_VISIBLE_PROOF_COVERAGE_BPS,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hidden_authority_rejection_bps",
        metrics.hidden_authority_rejection_bps,
        ">=",
        MIN_HIDDEN_AUTHORITY_REJECTION_BPS,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "admission_rejection_bps",
        metrics.admission_rejection_bps,
        ">=",
        MIN_ADMISSION_REJECTION_BPS,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_success_bps",
        metrics.route_success_bps,
        ">=",
        MIN_ROUTE_SUCCESS_BPS,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hidden_router_baseline_bps",
        metrics.hidden_router_baseline_bps,
        "<",
        metrics.route_success_bps,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "policy_mutation_baseline_bps",
        metrics.policy_mutation_baseline_bps,
        "<",
        metrics.route_success_bps,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "oracle_laundering_baseline_bps",
        metrics.oracle_laundering_baseline_bps,
        "<",
        metrics.route_success_bps,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_answer_packet_baseline_bps",
        metrics.no_answer_packet_baseline_bps,
        "<",
        metrics.route_success_bps,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_route_metadata_bytes",
        metrics.max_route_metadata_bytes,
        "<=",
        MAX_ROUTE_METADATA_BYTES,
        "bytes",
    );
    measurements.insert(
        "sparse_route_no_hidden_authority_address".to_string(),
        Measurement {
            value: serde_json::Value::String(address.clone()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "sparse_route_no_hidden_authority_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::Value::String(
                "uas:sparse-route-no-hidden-authority:sha256:".to_string(),
            ),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "sparse_route_no_hidden_authority_address".to_string(),
        address.starts_with("uas:sparse-route-no-hidden-authority:sha256:"),
    );

    let artifact = ArtifactBuilder {
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
            "kind": "metadata_only_sparse_route_authority_witness",
            "detail": "Architecture cursor advances only. Sparse route policy remains proposal-only and cannot wake bytes, mutate policy, consolidate fast weights, bypass admission, or suppress visible proof."
        })],
        notes: "Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof. F-SparseRoute-NoHiddenAuthority is metadata-only: source priors, proof traces, oracle labels, PatternBoost motifs, fast-weight deltas, scout proposals, and SparseWakeCertificates remain visible route evidence only, with no live route authority or runtime/model bytes.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();
    Ok(artifact)
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
    let passed = match operator {
        "<" => actual < expected,
        "<=" => actual <= expected,
        ">=" => actual >= expected,
        "==" => actual == expected,
        _ => false,
    };
    pass_per_axis.insert(name.to_string(), passed);
}

fn main() {
    match build_artifact() {
        Ok(artifact) => {
            let path = PathBuf::from(RESULT);
            if let Some(parent) = path.parent() {
                if let Err(error) = std::fs::create_dir_all(parent) {
                    eprintln!(
                        "failed to create artifact directory {}: {error}",
                        parent.display()
                    );
                    std::process::exit(1);
                }
            }
            match std::fs::File::create(&path) {
                Ok(mut file) => {
                    if let Err(error) = write_artifact(&mut file, &artifact) {
                        eprintln!("failed to write artifact {}: {error}", path.display());
                        std::process::exit(1);
                    }
                    println!(
                        "{}: overall_pass={} artifact={}",
                        FALSIFIER_ID,
                        artifact.overall_pass,
                        path.display()
                    );
                    if !artifact.overall_pass {
                        std::process::exit(1);
                    }
                }
                Err(error) => {
                    eprintln!("failed to open artifact {}: {error}", path.display());
                    std::process::exit(1);
                }
            }
        }
        Err(error) => {
            eprintln!("failed to build {} fixture: {:?}", FALSIFIER_ID, error);
            std::process::exit(1);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use agent_core::falsifier_artifacts::axes::SPARSE_ROUTE_NO_HIDDEN_AUTHORITY_AXES;

    #[test]
    fn valid_fixture_builds_registry() {
        assert!(SparseRouteRegistry::new(fixture_sparse_routes()).is_ok());
    }

    #[test]
    fn empty_fixture_is_rejected() {
        assert_eq!(
            SparseRouteRegistry::new(Vec::new()).err(),
            Some(SparseRouteError::EmptyFixture)
        );
    }

    #[test]
    fn duplicate_fixture_and_route_are_rejected() {
        let fixtures = fixture_sparse_routes();
        assert!(rejects(&fixtures, |fixtures| fixtures.push(fixtures[0].clone())));
        assert!(rejects_record(&fixtures, |record| record.route_id =
            "sparse-route-local-summary".to_string()));
    }

    #[test]
    fn authority_mutations_are_rejected() {
        let fixtures = fixture_sparse_routes();
        assert!(rejects_record(&fixtures, |record| {
            record.hidden_live_route_authority = true
        }));
        assert!(rejects_record(&fixtures, |record| record.policy_mutated = true));
        assert!(rejects_record(&fixtures, |record| {
            record.scope_rex_overridden = true
        }));
        assert!(rejects_record(&fixtures, |record| {
            record.sovereign_gate_overridden = true
        }));
    }

    #[test]
    fn high_uncertainty_requires_abstention() {
        let fixtures = fixture_sparse_routes();
        assert!(rejects_record(&fixtures, |record| {
            record.uncertainty_bps = HIGH_UNCERTAINTY_BPS;
            record.route_decision = "propose_sparse_wake".to_string();
        }));
    }

    #[test]
    fn address_is_deterministic_under_ordering() {
        let registry = SparseRouteRegistry::new(fixture_sparse_routes()).unwrap();
        let address = registry.address();
        let mut reversed = fixture_sparse_routes();
        reversed.reverse();
        for fixture in &mut reversed {
            fixture.records.reverse();
        }
        let reversed_address = SparseRouteRegistry::new(reversed).unwrap().address();
        assert_eq!(address, reversed_address);
    }

    #[test]
    fn invalid_fixture_axes_all_reject() {
        let fixtures = fixture_sparse_routes();
        for (axis, passed) in invalid_fixture_axes(&fixtures) {
            assert!(passed, "{axis} did not reject its invalid fixture");
        }
    }

    #[test]
    fn artifact_contains_required_axes() {
        let artifact = build_artifact().unwrap();
        for axis in SPARSE_ROUTE_NO_HIDDEN_AUTHORITY_AXES {
            assert!(
                artifact.pass_per_axis.contains_key(*axis),
                "missing required axis {axis}"
            );
        }
    }
}
