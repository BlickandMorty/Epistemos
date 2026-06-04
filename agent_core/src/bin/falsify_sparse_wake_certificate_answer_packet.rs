//! `falsify_sparse_wake_certificate_answer_packet` -- sparse wake certificate.
//!
//! Metadata-only witness for `F-SparseWakeCertificate-AnswerPacket`. It proves
//! a sparse route cannot promote from proposal/selector evidence to live route
//! authority unless the selected sparse/KV units, budgets, verifier evidence,
//! citation evidence, test evidence, trace refs, uncertainty, fallback, and
//! rollback are all visible in an AnswerPacket-bound certificate.

use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-SparseWakeCertificate-AnswerPacket";
const FIXTURE_ID: &str = "sparse_wake_certificate_answer_packet_v1";
const COMMAND: &str = "Tools/falsifiers/f_sparse_wake_certificate_answer_packet.sh";
const RESULT: &str = "artifacts/falsifiers/sparse_wake_certificate_answer_packet/result.json";
const UPSTREAM_SPARSE_WAKE: &str =
    "artifacts/falsifiers/sparse_wake_proposal_budget/result.json";
const UPSTREAM_VERIFIER_AUCTION: &str =
    "artifacts/falsifiers/verifier_budget_auction/result.json";
const UPSTREAM_QUERY_SELECTOR: &str =
    "artifacts/falsifiers/query_aware_kv_selector/result.json";
const CURRENT_FENCE: &str = "fence:model:qwen3.5:kv:v1:tokenizer:qwen3.5:adapter:none";
const MAX_HOT_BYTES: u64 = 96 * 1024 * 1024;
const MAX_KV_BYTES: u64 = 128 * 1024 * 1024;
const MAX_COLD_BYTES: u64 = 2 * 1024 * 1024 * 1024;
const MAX_LATENCY_MS: u64 = 220;
const MAX_UNCERTAINTY_BPS: u64 = 3_000;
const MIN_VERIFIER_BPS: u64 = 8_500;
const MIN_CITATION_BPS: u64 = 8_500;
const MIN_TEST_BPS: u64 = 8_000;
const MAX_CERTIFICATE_METADATA_BYTES: u64 = 1_048_576;
const REQUIRED_PACKET_FIELDS: &[&str] = &[
    "selected_units",
    "budget_vector",
    "verifier_results",
    "citation_results",
    "test_results",
    "trace_refs",
    "uncertainty",
    "fallback",
    "rollback",
    "route_authority",
];

#[derive(Clone)]
// UAS: uas:sparse-wake-certificate:unit
// Plane: Assembly + Verification
// Residency: metadata-only selected unit proof; no live bytes loaded.
struct CertifiedWakeUnit {
    unit_id: String,
    uas_address: String,
    unit_kind: String,
    source_ref: String,
    selected_reason: String,
    budget_class: String,
    byte_count: u64,
    verifier_result_ref: String,
    citation_result_ref: String,
    test_result_ref: String,
    trace_ref: String,
    compatibility_fence: String,
    privacy_class: String,
    selected: bool,
    stale: bool,
}

#[derive(Clone)]
// UAS: uas:sparse-wake-certificate:fixture
// Plane: Controller + Assembly + Verification
// Residency: metadata-only shadow certificate.
struct SparseWakeCertificateFixture {
    certificate_id: String,
    mission_id: String,
    answer_packet_ref: String,
    upstream_sparse_wake_ref: String,
    upstream_verifier_auction_ref: String,
    upstream_query_selector_ref: String,
    route_card_ref: String,
    selected_unit_ids: Vec<String>,
    units: Vec<CertifiedWakeUnit>,
    max_hot_bytes: u64,
    max_kv_bytes: u64,
    max_cold_bytes: u64,
    max_latency_ms: u64,
    uncertainty_bps: u64,
    fallback_route: String,
    rollback_handle: String,
    run_event_log_ref: String,
    answer_packet_visible_fields: Vec<String>,
    verifier_pass_bps: u64,
    citation_pass_bps: u64,
    test_pass_bps: u64,
    proposal_only_baseline_bps: u64,
    route_only_baseline_bps: u64,
    hidden_answer_baseline_bps: u64,
    certificate_metadata_bytes: u64,
    route_authority: String,
    live_route_promoted: bool,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    runtime_bytes_loaded: u64,
}

#[derive(Default, Clone, Copy)]
// UAS: uas:sparse-wake-certificate:metrics
// Plane: Verification
// Residency: metadata-only summary.
struct CertificateMetrics {
    certificate_count: u64,
    selected_unit_count: u64,
    kv_unit_count: u64,
    verifier_unit_count: u64,
    citation_unit_count: u64,
    test_unit_count: u64,
    max_hot_bytes: u64,
    max_kv_bytes: u64,
    max_cold_bytes: u64,
    max_latency_ms: u64,
    max_uncertainty_bps: u64,
    min_verifier_bps: u64,
    min_citation_bps: u64,
    min_test_bps: u64,
    certificate_success_bps: u64,
    proposal_only_baseline_bps: u64,
    route_only_baseline_bps: u64,
    hidden_answer_baseline_bps: u64,
    max_certificate_metadata_bytes: u64,
}

#[derive(Debug, Eq, PartialEq)]
// UAS: uas:sparse-wake-certificate:error
// Plane: Verification
// Residency: metadata-only rejection reason.
enum SparseWakeCertificateError {
    MissingCertificate,
    DuplicateCertificate,
    MissingCertificateId,
    MissingMission,
    MissingAnswerPacket,
    MissingUpstreamSparseWake,
    MissingUpstreamVerifierAuction,
    MissingUpstreamQuerySelector,
    MissingRouteCard,
    MissingUnit,
    DuplicateUnit,
    MissingSelectedUnit,
    UnknownSelectedUnit,
    SelectedMismatch,
    MissingUasAddress,
    MissingUnitKind,
    MissingSourceRef,
    MissingSelectedReason,
    MissingBudgetClass,
    MissingBytes,
    MissingVerifierResult,
    MissingCitationResult,
    MissingTestResult,
    MissingTraceRef,
    MissingCompatibilityFence,
    IncompatibleFence,
    InvalidPrivacyClass,
    StaleUnitSelected,
    MissingKvUnit,
    MissingVerifierUnit,
    MissingCitationUnit,
    MissingTestUnit,
    HotBudgetExceeded,
    KvBudgetExceeded,
    ColdBudgetExceeded,
    LatencyBudgetExceeded,
    MissingUncertainty,
    UncertaintyTooHigh,
    VerifierBypass,
    CitationBypass,
    TestBypass,
    MissingAnswerPacketField,
    MissingFallback,
    MissingRollback,
    MissingRunEventLog,
    HiddenLiveAuthority,
    LiveRoutePromotion,
    HiddenChainExposure,
    CloudSource,
    RuntimeBytesLoaded,
    MetadataBudgetExceeded,
    UnbeatenBaseline,
}

impl std::fmt::Display for SparseWakeCertificateError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for SparseWakeCertificateError {}

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
        "{FALSIFIER_ID}: overall_pass={} certificate_count={} selected_unit_count={} certificate_success_bps={} certificate_address={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["certificate_count"].value,
        artifact.measurements["selected_unit_count"].value,
        artifact.measurements["certificate_success_bps"].value,
        artifact.measurements["sparse_wake_certificate_address"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let certificates = fixture_certificates();
    let reversed = certificates.iter().cloned().rev().collect::<Vec<_>>();
    let registry = SparseWakeCertificateRegistry::new(certificates)?;
    let reversed_registry = SparseWakeCertificateRegistry::new(reversed)?;
    let metrics = registry.metrics;

    let upstream_sparse_wake_proposal_budget_pass = upstream_artifact_pass(UPSTREAM_SPARSE_WAKE);
    let upstream_verifier_budget_auction_pass = upstream_artifact_pass(UPSTREAM_VERIFIER_AUCTION);
    let upstream_query_aware_kv_selector_pass = upstream_artifact_pass(UPSTREAM_QUERY_SELECTOR);
    let sparse_wake_certificate_fixture_present =
        registry.certificates.len() == 2 && metrics.selected_unit_count == 12;
    let certificate_ids_bound = registry
        .certificates
        .iter()
        .all(|certificate| certificate.certificate_id.starts_with("sparse-wake-cert:"));
    let mission_ids_bound = registry
        .certificates
        .iter()
        .all(|certificate| certificate.mission_id.starts_with("mission:"));
    let answer_packet_refs_bound = registry
        .certificates
        .iter()
        .all(|certificate| certificate.answer_packet_ref.starts_with("answerpacket:"));
    let upstream_refs_bound = registry.certificates.iter().all(|certificate| {
        certificate.upstream_sparse_wake_ref == UPSTREAM_SPARSE_WAKE
            && certificate.upstream_verifier_auction_ref == UPSTREAM_VERIFIER_AUCTION
            && certificate.upstream_query_selector_ref == UPSTREAM_QUERY_SELECTOR
    });
    let route_card_refs_bound = registry
        .certificates
        .iter()
        .all(|certificate| certificate.route_card_ref.starts_with("route-card:"));
    let selected_units_bound = registry.certificates.iter().all(selected_units_match_flags);
    let uas_addresses_bound = registry
        .certificates
        .iter()
        .flat_map(|certificate| certificate.units.iter())
        .all(|unit| unit.uas_address.starts_with("uas:"));
    let selected_reasons_bound = registry
        .certificates
        .iter()
        .flat_map(|certificate| certificate.units.iter().filter(|unit| unit.selected))
        .all(|unit| !unit.selected_reason.is_empty());
    let verifier_results_bound = registry
        .certificates
        .iter()
        .flat_map(|certificate| certificate.units.iter().filter(|unit| unit.selected))
        .all(|unit| unit.verifier_result_ref.starts_with("verifier:"));
    let citation_results_bound = registry
        .certificates
        .iter()
        .flat_map(|certificate| certificate.units.iter().filter(|unit| unit.selected))
        .all(|unit| unit.citation_result_ref.starts_with("citation:"));
    let test_results_bound = registry
        .certificates
        .iter()
        .flat_map(|certificate| certificate.units.iter().filter(|unit| unit.selected))
        .all(|unit| unit.test_result_ref.starts_with("test:"));
    let trace_refs_bound = registry
        .certificates
        .iter()
        .flat_map(|certificate| certificate.units.iter().filter(|unit| unit.selected))
        .all(|unit| unit.trace_ref.starts_with("trace:"));
    let compatibility_fences_bound = registry
        .certificates
        .iter()
        .flat_map(|certificate| certificate.units.iter())
        .all(|unit| unit.compatibility_fence == CURRENT_FENCE);
    let privacy_classes_bound = registry
        .certificates
        .iter()
        .flat_map(|certificate| certificate.units.iter())
        .all(|unit| valid_privacy_class(&unit.privacy_class));
    let answer_packet_required_fields_bound = registry
        .certificates
        .iter()
        .all(answer_packet_fields_complete);
    let fallback_bound = registry
        .certificates
        .iter()
        .all(|certificate| certificate.fallback_route.starts_with("fallback:"));
    let rollback_bound = registry
        .certificates
        .iter()
        .all(|certificate| certificate.rollback_handle.starts_with("rollback:"));
    let run_event_log_bound = registry
        .certificates
        .iter()
        .all(|certificate| certificate.run_event_log_ref.starts_with("runevent:"));
    let route_authority_shadow_only = registry
        .certificates
        .iter()
        .all(|certificate| certificate.route_authority == "shadow_only");
    let live_route_not_promoted = registry
        .certificates
        .iter()
        .all(|certificate| !certificate.live_route_promoted);
    let no_hidden_chain = registry
        .certificates
        .iter()
        .all(|certificate| !certificate.hidden_chain_exposed);
    let no_hidden_cloud = registry
        .certificates
        .iter()
        .all(|certificate| !certificate.hidden_cloud);
    let no_runtime_bytes_loaded = registry
        .certificates
        .iter()
        .all(|certificate| certificate.runtime_bytes_loaded == 0);
    let sparse_wake_certificate_address_deterministic =
        registry.sparse_wake_certificate_address == reversed_registry.sparse_wake_certificate_address;
    let selected_units_fit_hot_budget = metrics.max_hot_bytes <= MAX_HOT_BYTES;
    let selected_units_fit_kv_budget = metrics.max_kv_bytes <= MAX_KV_BYTES;
    let selected_units_fit_cold_budget = metrics.max_cold_bytes <= MAX_COLD_BYTES;
    let certificate_latency_bound = metrics.max_latency_ms <= MAX_LATENCY_MS;
    let uncertainty_bound = metrics.max_uncertainty_bps <= MAX_UNCERTAINTY_BPS;
    let verifier_floor_bound = metrics.min_verifier_bps >= MIN_VERIFIER_BPS;
    let citation_floor_bound = metrics.min_citation_bps >= MIN_CITATION_BPS;
    let test_floor_bound = metrics.min_test_bps >= MIN_TEST_BPS;
    let certificate_beats_proposal_only_baseline =
        metrics.certificate_success_bps > metrics.proposal_only_baseline_bps;
    let certificate_beats_route_only_baseline =
        metrics.certificate_success_bps > metrics.route_only_baseline_bps;
    let certificate_beats_hidden_answer_baseline =
        metrics.certificate_success_bps > metrics.hidden_answer_baseline_bps;
    let certificate_metadata_bound =
        metrics.max_certificate_metadata_bytes <= MAX_CERTIFICATE_METADATA_BYTES;

    let duplicate_certificate_rejected =
        invalid_certificates_rejected(|certificates| certificates.push(certificates[0].clone()))
            == Some(SparseWakeCertificateError::DuplicateCertificate);
    let duplicate_unit_rejected = invalid_certificate_rejected(|certificate| {
        certificate.units.push(certificate.units[0].clone());
    }) == Some(SparseWakeCertificateError::DuplicateUnit);
    let missing_selected_unit_rejected =
        invalid_certificate_rejected(|certificate| certificate.selected_unit_ids.clear())
            == Some(SparseWakeCertificateError::MissingSelectedUnit);
    let unknown_selected_unit_rejected = invalid_certificate_rejected(|certificate| {
        certificate.selected_unit_ids = vec!["unit:unknown".to_string()];
    }) == Some(SparseWakeCertificateError::UnknownSelectedUnit);
    let missing_verifier_result_rejected =
        invalid_selected_unit_rejected(|unit| unit.verifier_result_ref.clear())
            == Some(SparseWakeCertificateError::MissingVerifierResult);
    let missing_citation_result_rejected =
        invalid_selected_unit_rejected(|unit| unit.citation_result_ref.clear())
            == Some(SparseWakeCertificateError::MissingCitationResult);
    let missing_test_result_rejected =
        invalid_selected_unit_rejected(|unit| unit.test_result_ref.clear())
            == Some(SparseWakeCertificateError::MissingTestResult);
    let missing_trace_ref_rejected =
        invalid_selected_unit_rejected(|unit| unit.trace_ref.clear())
            == Some(SparseWakeCertificateError::MissingTraceRef);
    let missing_answer_packet_field_rejected = invalid_certificate_rejected(|certificate| {
        certificate
            .answer_packet_visible_fields
            .retain(|field| field != "trace_refs");
    }) == Some(SparseWakeCertificateError::MissingAnswerPacketField);
    let stale_unit_rejected = invalid_selected_unit_rejected(|unit| unit.stale = true)
        == Some(SparseWakeCertificateError::StaleUnitSelected);
    let incompatible_fence_rejected =
        invalid_selected_unit_rejected(|unit| unit.compatibility_fence = "fence:old".to_string())
            == Some(SparseWakeCertificateError::IncompatibleFence);
    let invalid_privacy_class_rejected =
        invalid_selected_unit_rejected(|unit| unit.privacy_class = "raw_hidden_chain".to_string())
            == Some(SparseWakeCertificateError::InvalidPrivacyClass);
    let over_hot_budget_rejected =
        invalid_certificate_rejected(|certificate| certificate.max_hot_bytes = 1)
            == Some(SparseWakeCertificateError::HotBudgetExceeded);
    let over_kv_budget_rejected =
        invalid_certificate_rejected(|certificate| certificate.max_kv_bytes = 1)
            == Some(SparseWakeCertificateError::KvBudgetExceeded);
    let over_cold_budget_rejected =
        invalid_certificate_rejected(|certificate| certificate.max_cold_bytes = 1)
            == Some(SparseWakeCertificateError::ColdBudgetExceeded);
    let over_latency_rejected =
        invalid_certificate_rejected(|certificate| certificate.max_latency_ms = 1)
            == Some(SparseWakeCertificateError::LatencyBudgetExceeded);
    let uncertainty_too_high_rejected =
        invalid_certificate_rejected(|certificate| certificate.uncertainty_bps = 9_000)
            == Some(SparseWakeCertificateError::UncertaintyTooHigh);
    let verifier_bypass_rejected =
        invalid_certificate_rejected(|certificate| certificate.verifier_pass_bps = 2_000)
            == Some(SparseWakeCertificateError::VerifierBypass);
    let citation_bypass_rejected =
        invalid_certificate_rejected(|certificate| certificate.citation_pass_bps = 2_000)
            == Some(SparseWakeCertificateError::CitationBypass);
    let test_bypass_rejected =
        invalid_certificate_rejected(|certificate| certificate.test_pass_bps = 2_000)
            == Some(SparseWakeCertificateError::TestBypass);
    let missing_fallback_rejected =
        invalid_certificate_rejected(|certificate| certificate.fallback_route.clear())
            == Some(SparseWakeCertificateError::MissingFallback);
    let missing_rollback_rejected =
        invalid_certificate_rejected(|certificate| certificate.rollback_handle.clear())
            == Some(SparseWakeCertificateError::MissingRollback);
    let missing_run_event_log_rejected =
        invalid_certificate_rejected(|certificate| certificate.run_event_log_ref.clear())
            == Some(SparseWakeCertificateError::MissingRunEventLog);
    let hidden_live_authority_rejected =
        invalid_certificate_rejected(|certificate| certificate.route_authority = "live".to_string())
            == Some(SparseWakeCertificateError::HiddenLiveAuthority);
    let live_route_promotion_rejected =
        invalid_certificate_rejected(|certificate| certificate.live_route_promoted = true)
            == Some(SparseWakeCertificateError::LiveRoutePromotion);
    let hidden_chain_exposure_rejected =
        invalid_certificate_rejected(|certificate| certificate.hidden_chain_exposed = true)
            == Some(SparseWakeCertificateError::HiddenChainExposure);
    let cloud_source_rejected =
        invalid_selected_unit_rejected(|unit| unit.source_ref = "cloud:runtime".to_string())
            == Some(SparseWakeCertificateError::CloudSource);
    let runtime_bytes_rejected =
        invalid_certificate_rejected(|certificate| certificate.runtime_bytes_loaded = 1)
            == Some(SparseWakeCertificateError::RuntimeBytesLoaded);
    let metadata_budget_rejected = invalid_certificate_rejected(|certificate| {
        certificate.certificate_metadata_bytes = MAX_CERTIFICATE_METADATA_BYTES + 1;
    }) == Some(SparseWakeCertificateError::MetadataBudgetExceeded);
    let unbeaten_baseline_rejected = invalid_certificate_rejected(|certificate| {
        certificate.proposal_only_baseline_bps = 10_000;
    }) == Some(SparseWakeCertificateError::UnbeatenBaseline);

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_sparse_wake_proposal_budget_pass",
            upstream_sparse_wake_proposal_budget_pass,
        ),
        (
            "upstream_verifier_budget_auction_pass",
            upstream_verifier_budget_auction_pass,
        ),
        (
            "upstream_query_aware_kv_selector_pass",
            upstream_query_aware_kv_selector_pass,
        ),
        (
            "sparse_wake_certificate_fixture_present",
            sparse_wake_certificate_fixture_present,
        ),
        ("certificate_ids_bound", certificate_ids_bound),
        ("mission_ids_bound", mission_ids_bound),
        ("answer_packet_refs_bound", answer_packet_refs_bound),
        ("upstream_refs_bound", upstream_refs_bound),
        ("route_card_refs_bound", route_card_refs_bound),
        ("selected_units_bound", selected_units_bound),
        ("uas_addresses_bound", uas_addresses_bound),
        ("selected_reasons_bound", selected_reasons_bound),
        ("verifier_results_bound", verifier_results_bound),
        ("citation_results_bound", citation_results_bound),
        ("test_results_bound", test_results_bound),
        ("trace_refs_bound", trace_refs_bound),
        ("compatibility_fences_bound", compatibility_fences_bound),
        ("privacy_classes_bound", privacy_classes_bound),
        (
            "answer_packet_required_fields_bound",
            answer_packet_required_fields_bound,
        ),
        ("fallback_bound", fallback_bound),
        ("rollback_bound", rollback_bound),
        ("run_event_log_bound", run_event_log_bound),
        ("route_authority_shadow_only", route_authority_shadow_only),
        ("live_route_not_promoted", live_route_not_promoted),
        ("no_hidden_chain", no_hidden_chain),
        ("no_hidden_cloud", no_hidden_cloud),
        ("no_runtime_bytes_loaded", no_runtime_bytes_loaded),
        (
            "sparse_wake_certificate_address_deterministic",
            sparse_wake_certificate_address_deterministic,
        ),
        ("selected_units_fit_hot_budget", selected_units_fit_hot_budget),
        ("selected_units_fit_kv_budget", selected_units_fit_kv_budget),
        ("selected_units_fit_cold_budget", selected_units_fit_cold_budget),
        ("certificate_latency_bound", certificate_latency_bound),
        ("uncertainty_bound", uncertainty_bound),
        ("verifier_floor_bound", verifier_floor_bound),
        ("citation_floor_bound", citation_floor_bound),
        ("test_floor_bound", test_floor_bound),
        (
            "certificate_beats_proposal_only_baseline",
            certificate_beats_proposal_only_baseline,
        ),
        (
            "certificate_beats_route_only_baseline",
            certificate_beats_route_only_baseline,
        ),
        (
            "certificate_beats_hidden_answer_baseline",
            certificate_beats_hidden_answer_baseline,
        ),
        ("certificate_metadata_bound", certificate_metadata_bound),
        ("duplicate_certificate_rejected", duplicate_certificate_rejected),
        ("duplicate_unit_rejected", duplicate_unit_rejected),
        ("missing_selected_unit_rejected", missing_selected_unit_rejected),
        ("unknown_selected_unit_rejected", unknown_selected_unit_rejected),
        (
            "missing_verifier_result_rejected",
            missing_verifier_result_rejected,
        ),
        (
            "missing_citation_result_rejected",
            missing_citation_result_rejected,
        ),
        ("missing_test_result_rejected", missing_test_result_rejected),
        ("missing_trace_ref_rejected", missing_trace_ref_rejected),
        (
            "missing_answer_packet_field_rejected",
            missing_answer_packet_field_rejected,
        ),
        ("stale_unit_rejected", stale_unit_rejected),
        ("incompatible_fence_rejected", incompatible_fence_rejected),
        (
            "invalid_privacy_class_rejected",
            invalid_privacy_class_rejected,
        ),
        ("over_hot_budget_rejected", over_hot_budget_rejected),
        ("over_kv_budget_rejected", over_kv_budget_rejected),
        ("over_cold_budget_rejected", over_cold_budget_rejected),
        ("over_latency_rejected", over_latency_rejected),
        ("uncertainty_too_high_rejected", uncertainty_too_high_rejected),
        ("verifier_bypass_rejected", verifier_bypass_rejected),
        ("citation_bypass_rejected", citation_bypass_rejected),
        ("test_bypass_rejected", test_bypass_rejected),
        ("missing_fallback_rejected", missing_fallback_rejected),
        ("missing_rollback_rejected", missing_rollback_rejected),
        (
            "missing_run_event_log_rejected",
            missing_run_event_log_rejected,
        ),
        ("hidden_live_authority_rejected", hidden_live_authority_rejected),
        ("live_route_promotion_rejected", live_route_promotion_rejected),
        (
            "hidden_chain_exposure_rejected",
            hidden_chain_exposure_rejected,
        ),
        ("cloud_source_rejected", cloud_source_rejected),
        ("runtime_bytes_rejected", runtime_bytes_rejected),
        ("metadata_budget_rejected", metadata_budget_rejected),
        ("unbeaten_baseline_rejected", unbeaten_baseline_rejected),
    ] {
        add_bool_axis(&mut measurements, &mut thresholds, &mut pass_per_axis, name, pass);
    }

    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "certificate_count",
        metrics.certificate_count,
        2,
        "certificates",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "selected_unit_count",
        metrics.selected_unit_count,
        12,
        "units",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_unit_count",
        metrics.kv_unit_count,
        4,
        "units",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_unit_count",
        metrics.verifier_unit_count,
        2,
        "units",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "citation_unit_count",
        metrics.citation_unit_count,
        2,
        "units",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "test_unit_count",
        metrics.test_unit_count,
        2,
        "units",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_hot_bytes",
        metrics.max_hot_bytes,
        MAX_HOT_BYTES,
        "bytes",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_kv_bytes",
        metrics.max_kv_bytes,
        MAX_KV_BYTES,
        "bytes",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_cold_bytes",
        metrics.max_cold_bytes,
        MAX_COLD_BYTES,
        "bytes",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_latency_ms",
        metrics.max_latency_ms,
        MAX_LATENCY_MS,
        "ms",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_uncertainty_bps",
        metrics.max_uncertainty_bps,
        MAX_UNCERTAINTY_BPS,
        "bps",
    );
    add_u64_ge_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "min_verifier_bps",
        metrics.min_verifier_bps,
        MIN_VERIFIER_BPS,
        "bps",
    );
    add_u64_ge_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "min_citation_bps",
        metrics.min_citation_bps,
        MIN_CITATION_BPS,
        "bps",
    );
    add_u64_ge_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "min_test_bps",
        metrics.min_test_bps,
        MIN_TEST_BPS,
        "bps",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "certificate_success_bps",
        metrics.certificate_success_bps,
        10_000,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "proposal_only_baseline_bps",
        metrics.proposal_only_baseline_bps,
        metrics.certificate_success_bps,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_only_baseline_bps",
        metrics.route_only_baseline_bps,
        metrics.certificate_success_bps,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hidden_answer_baseline_bps",
        metrics.hidden_answer_baseline_bps,
        metrics.certificate_success_bps,
        "bps",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_certificate_metadata_bytes",
        metrics.max_certificate_metadata_bytes,
        MAX_CERTIFICATE_METADATA_BYTES,
        "bytes",
    );
    add_string_contains_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "sparse_wake_certificate_address",
        &registry.sparse_wake_certificate_address,
        "uas:sparse-wake-certificate:",
        "uas_address",
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
            "kind": "scope_guard",
            "detail": "metadata-only SparseWakeCertificate witness; exposes selected sparse/KV units, budgets, verifier/citation/test evidence, traces, uncertainty, fallback, rollback, and route authority in an AnswerPacket-bound certificate; no live sparse routing, no KV restore, no 70B inference, and no runtime/model bytes"
        })],
        notes: "scope=metadata_only;organ=SparseWakeCertificate;reviewer=codex;reviewed_at_utc=2026-06-04T00:00:00Z;validator=falsifier_validator;detail=sparse wake certificate exposes selected units, budget vectors, verifier/citation/test results, traces, uncertainty, fallback, rollback, and shadow-only authority in AnswerPacket-visible proof before live route promotion.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:sparse-wake-certificate:registry
// Plane: Controller + Verification
// Residency: metadata-only
struct SparseWakeCertificateRegistry {
    certificates: Vec<SparseWakeCertificateFixture>,
    metrics: CertificateMetrics,
    sparse_wake_certificate_address: String,
}

impl SparseWakeCertificateRegistry {
    fn new(
        mut certificates: Vec<SparseWakeCertificateFixture>,
    ) -> Result<Self, SparseWakeCertificateError> {
        if certificates.is_empty() {
            return Err(SparseWakeCertificateError::MissingCertificate);
        }
        let mut seen_certificates = BTreeSet::new();
        for certificate in &certificates {
            if !seen_certificates.insert(certificate.certificate_id.clone()) {
                return Err(SparseWakeCertificateError::DuplicateCertificate);
            }
            validate_certificate(certificate)?;
        }
        certificates.sort_by(|left, right| left.certificate_id.cmp(&right.certificate_id));
        let metrics = certificate_metrics(&certificates);
        let address = certificate_address(&certificates);
        Ok(Self {
            certificates,
            metrics,
            sparse_wake_certificate_address: address,
        })
    }
}

fn validate_certificate(
    certificate: &SparseWakeCertificateFixture,
) -> Result<(), SparseWakeCertificateError> {
    if !certificate.certificate_id.starts_with("sparse-wake-cert:") {
        return Err(SparseWakeCertificateError::MissingCertificateId);
    }
    if !certificate.mission_id.starts_with("mission:") {
        return Err(SparseWakeCertificateError::MissingMission);
    }
    if !certificate.answer_packet_ref.starts_with("answerpacket:") {
        return Err(SparseWakeCertificateError::MissingAnswerPacket);
    }
    if certificate.upstream_sparse_wake_ref != UPSTREAM_SPARSE_WAKE {
        return Err(SparseWakeCertificateError::MissingUpstreamSparseWake);
    }
    if certificate.upstream_verifier_auction_ref != UPSTREAM_VERIFIER_AUCTION {
        return Err(SparseWakeCertificateError::MissingUpstreamVerifierAuction);
    }
    if certificate.upstream_query_selector_ref != UPSTREAM_QUERY_SELECTOR {
        return Err(SparseWakeCertificateError::MissingUpstreamQuerySelector);
    }
    if !certificate.route_card_ref.starts_with("route-card:") {
        return Err(SparseWakeCertificateError::MissingRouteCard);
    }
    if certificate.units.is_empty() {
        return Err(SparseWakeCertificateError::MissingUnit);
    }
    let mut seen_units = BTreeSet::new();
    for unit in &certificate.units {
        if !seen_units.insert(unit.unit_id.clone()) {
            return Err(SparseWakeCertificateError::DuplicateUnit);
        }
        validate_unit(unit)?;
    }
    if certificate.selected_unit_ids.is_empty() {
        return Err(SparseWakeCertificateError::MissingSelectedUnit);
    }
    let unit_lookup = certificate
        .units
        .iter()
        .map(|unit| (unit.unit_id.as_str(), unit))
        .collect::<BTreeMap<_, _>>();
    for unit_id in &certificate.selected_unit_ids {
        let unit = unit_lookup
            .get(unit_id.as_str())
            .ok_or(SparseWakeCertificateError::UnknownSelectedUnit)?;
        if !unit.selected {
            return Err(SparseWakeCertificateError::SelectedMismatch);
        }
        if unit.stale {
            return Err(SparseWakeCertificateError::StaleUnitSelected);
        }
    }
    if !selected_units_match_flags(certificate) {
        return Err(SparseWakeCertificateError::SelectedMismatch);
    }
    if !has_selected_kind(certificate, "kv_page") {
        return Err(SparseWakeCertificateError::MissingKvUnit);
    }
    if !has_selected_kind(certificate, "verifier_tool") {
        return Err(SparseWakeCertificateError::MissingVerifierUnit);
    }
    if !has_selected_kind(certificate, "citation_source") {
        return Err(SparseWakeCertificateError::MissingCitationUnit);
    }
    if !has_selected_kind(certificate, "test_harness") {
        return Err(SparseWakeCertificateError::MissingTestUnit);
    }
    let (hot, kv, cold) = selected_budget_bytes(certificate);
    if hot > certificate.max_hot_bytes {
        return Err(SparseWakeCertificateError::HotBudgetExceeded);
    }
    if kv > certificate.max_kv_bytes {
        return Err(SparseWakeCertificateError::KvBudgetExceeded);
    }
    if cold > certificate.max_cold_bytes {
        return Err(SparseWakeCertificateError::ColdBudgetExceeded);
    }
    if selected_latency_ms(certificate) > certificate.max_latency_ms {
        return Err(SparseWakeCertificateError::LatencyBudgetExceeded);
    }
    if certificate.uncertainty_bps == 0 {
        return Err(SparseWakeCertificateError::MissingUncertainty);
    }
    if certificate.uncertainty_bps > MAX_UNCERTAINTY_BPS {
        return Err(SparseWakeCertificateError::UncertaintyTooHigh);
    }
    if certificate.verifier_pass_bps < MIN_VERIFIER_BPS {
        return Err(SparseWakeCertificateError::VerifierBypass);
    }
    if certificate.citation_pass_bps < MIN_CITATION_BPS {
        return Err(SparseWakeCertificateError::CitationBypass);
    }
    if certificate.test_pass_bps < MIN_TEST_BPS {
        return Err(SparseWakeCertificateError::TestBypass);
    }
    if !answer_packet_fields_complete(certificate) {
        return Err(SparseWakeCertificateError::MissingAnswerPacketField);
    }
    if !certificate.fallback_route.starts_with("fallback:") {
        return Err(SparseWakeCertificateError::MissingFallback);
    }
    if !certificate.rollback_handle.starts_with("rollback:") {
        return Err(SparseWakeCertificateError::MissingRollback);
    }
    if !certificate.run_event_log_ref.starts_with("runevent:") {
        return Err(SparseWakeCertificateError::MissingRunEventLog);
    }
    if certificate.route_authority != "shadow_only" {
        return Err(SparseWakeCertificateError::HiddenLiveAuthority);
    }
    if certificate.live_route_promoted {
        return Err(SparseWakeCertificateError::LiveRoutePromotion);
    }
    if certificate.hidden_chain_exposed {
        return Err(SparseWakeCertificateError::HiddenChainExposure);
    }
    if certificate.hidden_cloud {
        return Err(SparseWakeCertificateError::CloudSource);
    }
    if certificate.runtime_bytes_loaded > 0 {
        return Err(SparseWakeCertificateError::RuntimeBytesLoaded);
    }
    if certificate.certificate_metadata_bytes > MAX_CERTIFICATE_METADATA_BYTES {
        return Err(SparseWakeCertificateError::MetadataBudgetExceeded);
    }
    let success = certificate_success_bps(certificate);
    if certificate.proposal_only_baseline_bps >= success
        || certificate.route_only_baseline_bps >= success
        || certificate.hidden_answer_baseline_bps >= success
    {
        return Err(SparseWakeCertificateError::UnbeatenBaseline);
    }
    Ok(())
}

fn validate_unit(unit: &CertifiedWakeUnit) -> Result<(), SparseWakeCertificateError> {
    if !unit.uas_address.starts_with("uas:") {
        return Err(SparseWakeCertificateError::MissingUasAddress);
    }
    if unit.unit_kind.is_empty() {
        return Err(SparseWakeCertificateError::MissingUnitKind);
    }
    if unit.source_ref.is_empty() {
        return Err(SparseWakeCertificateError::MissingSourceRef);
    }
    if unit.source_ref.contains("cloud") {
        return Err(SparseWakeCertificateError::CloudSource);
    }
    if unit.selected && unit.selected_reason.is_empty() {
        return Err(SparseWakeCertificateError::MissingSelectedReason);
    }
    if !matches!(unit.budget_class.as_str(), "hot" | "kv" | "cold") {
        return Err(SparseWakeCertificateError::MissingBudgetClass);
    }
    if unit.byte_count == 0 {
        return Err(SparseWakeCertificateError::MissingBytes);
    }
    if !unit.verifier_result_ref.starts_with("verifier:") {
        return Err(SparseWakeCertificateError::MissingVerifierResult);
    }
    if !unit.citation_result_ref.starts_with("citation:") {
        return Err(SparseWakeCertificateError::MissingCitationResult);
    }
    if !unit.test_result_ref.starts_with("test:") {
        return Err(SparseWakeCertificateError::MissingTestResult);
    }
    if !unit.trace_ref.starts_with("trace:") {
        return Err(SparseWakeCertificateError::MissingTraceRef);
    }
    if !unit.compatibility_fence.starts_with("fence:") {
        return Err(SparseWakeCertificateError::MissingCompatibilityFence);
    }
    if unit.compatibility_fence != CURRENT_FENCE {
        return Err(SparseWakeCertificateError::IncompatibleFence);
    }
    if !valid_privacy_class(&unit.privacy_class) {
        return Err(SparseWakeCertificateError::InvalidPrivacyClass);
    }
    Ok(())
}

fn valid_privacy_class(privacy_class: &str) -> bool {
    matches!(privacy_class, "vault_private" | "local_only" | "proof_public")
}

fn has_selected_kind(certificate: &SparseWakeCertificateFixture, kind: &str) -> bool {
    certificate
        .units
        .iter()
        .any(|unit| unit.selected && unit.unit_kind == kind)
}

fn selected_units_match_flags(certificate: &SparseWakeCertificateFixture) -> bool {
    let selected_ids = certificate
        .selected_unit_ids
        .iter()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    let selected_flags = certificate
        .units
        .iter()
        .filter(|unit| unit.selected)
        .map(|unit| unit.unit_id.as_str())
        .collect::<BTreeSet<_>>();
    selected_ids == selected_flags
}

fn answer_packet_fields_complete(certificate: &SparseWakeCertificateFixture) -> bool {
    let fields = certificate
        .answer_packet_visible_fields
        .iter()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    REQUIRED_PACKET_FIELDS
        .iter()
        .all(|required| fields.contains(required))
}

fn selected_budget_bytes(certificate: &SparseWakeCertificateFixture) -> (u64, u64, u64) {
    let mut hot = 0;
    let mut kv = 0;
    let mut cold = 0;
    for unit in certificate.units.iter().filter(|unit| unit.selected) {
        match unit.budget_class.as_str() {
            "hot" => hot += unit.byte_count,
            "kv" => kv += unit.byte_count,
            "cold" => cold += unit.byte_count,
            _ => {}
        }
    }
    (hot, kv, cold)
}

fn selected_latency_ms(certificate: &SparseWakeCertificateFixture) -> u64 {
    let selected_count = certificate
        .units
        .iter()
        .filter(|unit| unit.selected)
        .count() as u64;
    40 + selected_count * 15
}

fn certificate_success_bps(certificate: &SparseWakeCertificateFixture) -> u64 {
    u64::from(
        certificate.verifier_pass_bps >= MIN_VERIFIER_BPS
            && certificate.citation_pass_bps >= MIN_CITATION_BPS
            && certificate.test_pass_bps >= MIN_TEST_BPS
            && answer_packet_fields_complete(certificate),
    ) * 10_000
}

fn certificate_metrics(certificates: &[SparseWakeCertificateFixture]) -> CertificateMetrics {
    let mut metrics = CertificateMetrics {
        certificate_count: certificates.len() as u64,
        min_verifier_bps: u64::MAX,
        min_citation_bps: u64::MAX,
        min_test_bps: u64::MAX,
        ..CertificateMetrics::default()
    };
    for certificate in certificates {
        let (hot, kv, cold) = selected_budget_bytes(certificate);
        metrics.max_hot_bytes = metrics.max_hot_bytes.max(hot);
        metrics.max_kv_bytes = metrics.max_kv_bytes.max(kv);
        metrics.max_cold_bytes = metrics.max_cold_bytes.max(cold);
        metrics.max_latency_ms = metrics.max_latency_ms.max(selected_latency_ms(certificate));
        metrics.max_uncertainty_bps = metrics.max_uncertainty_bps.max(certificate.uncertainty_bps);
        metrics.min_verifier_bps = metrics.min_verifier_bps.min(certificate.verifier_pass_bps);
        metrics.min_citation_bps = metrics.min_citation_bps.min(certificate.citation_pass_bps);
        metrics.min_test_bps = metrics.min_test_bps.min(certificate.test_pass_bps);
        metrics
            .max_certificate_metadata_bytes = metrics
            .max_certificate_metadata_bytes
            .max(certificate.certificate_metadata_bytes);
        metrics
            .proposal_only_baseline_bps = metrics
            .proposal_only_baseline_bps
            .max(certificate.proposal_only_baseline_bps);
        metrics.route_only_baseline_bps =
            metrics.route_only_baseline_bps.max(certificate.route_only_baseline_bps);
        metrics
            .hidden_answer_baseline_bps = metrics
            .hidden_answer_baseline_bps
            .max(certificate.hidden_answer_baseline_bps);
        metrics
            .certificate_success_bps = metrics
            .certificate_success_bps
            .min(certificate_success_bps(certificate));
        if metrics.certificate_success_bps == 0 {
            metrics.certificate_success_bps = certificate_success_bps(certificate);
        }
        for unit in certificate.units.iter().filter(|unit| unit.selected) {
            metrics.selected_unit_count += 1;
            match unit.unit_kind.as_str() {
                "kv_page" => metrics.kv_unit_count += 1,
                "verifier_tool" => metrics.verifier_unit_count += 1,
                "citation_source" => metrics.citation_unit_count += 1,
                "test_harness" => metrics.test_unit_count += 1,
                _ => {}
            }
        }
    }
    if metrics.min_verifier_bps == u64::MAX {
        metrics.min_verifier_bps = 0;
    }
    if metrics.min_citation_bps == u64::MAX {
        metrics.min_citation_bps = 0;
    }
    if metrics.min_test_bps == u64::MAX {
        metrics.min_test_bps = 0;
    }
    metrics
}

fn certificate_address(certificates: &[SparseWakeCertificateFixture]) -> String {
    let mut material = String::new();
    for certificate in certificates {
        material.push_str(&certificate.certificate_id);
        material.push('|');
        material.push_str(&certificate.answer_packet_ref);
        material.push('|');
        material.push_str(&certificate.selected_unit_ids.join(","));
        material.push('|');
    }
    format!("uas:sparse-wake-certificate:{}", sha256_hex(material.as_bytes()))
}

fn upstream_artifact_pass(path: &str) -> bool {
    [PathBuf::from(path), PathBuf::from("..").join(path)]
        .iter()
        .find_map(|candidate| {
            let bytes = std::fs::read(candidate).ok()?;
            serde_json::from_slice::<serde_json::Value>(&bytes).ok()
        })
        .and_then(|value| value.get("overall_pass").and_then(|value| value.as_bool()))
        .unwrap_or(false)
}

fn invalid_certificates_rejected(
    mutate: impl FnOnce(&mut Vec<SparseWakeCertificateFixture>),
) -> Option<SparseWakeCertificateError> {
    let mut certificates = fixture_certificates();
    mutate(&mut certificates);
    SparseWakeCertificateRegistry::new(certificates).err()
}

fn invalid_certificate_rejected(
    mutate: impl FnOnce(&mut SparseWakeCertificateFixture),
) -> Option<SparseWakeCertificateError> {
    invalid_certificates_rejected(|certificates| mutate(&mut certificates[0]))
}

fn invalid_selected_unit_rejected(
    mutate: impl FnOnce(&mut CertifiedWakeUnit),
) -> Option<SparseWakeCertificateError> {
    invalid_certificate_rejected(|certificate| {
        let index = certificate
            .units
            .iter()
            .position(|unit| unit.selected)
            .unwrap_or(0);
        mutate(&mut certificate.units[index]);
    })
}

fn fixture_certificates() -> Vec<SparseWakeCertificateFixture> {
    vec![
        SparseWakeCertificateFixture {
            certificate_id: "sparse-wake-cert:local-summary-proof".to_string(),
            mission_id: "mission:local-summary-proof".to_string(),
            answer_packet_ref: "answerpacket:sparse-wake:local-summary-proof".to_string(),
            upstream_sparse_wake_ref: UPSTREAM_SPARSE_WAKE.to_string(),
            upstream_verifier_auction_ref: UPSTREAM_VERIFIER_AUCTION.to_string(),
            upstream_query_selector_ref: UPSTREAM_QUERY_SELECTOR.to_string(),
            route_card_ref: "route-card:query-aware-kv-local-summary".to_string(),
            selected_unit_ids: vec![
                "unit:hot-controller:summary".to_string(),
                "unit:kv-page:summary-evidence-a".to_string(),
                "unit:kv-page:summary-evidence-b".to_string(),
                "unit:citation:summary-vault".to_string(),
                "unit:verifier:summary-factuality".to_string(),
                "unit:test:summary-regression".to_string(),
            ],
            units: vec![
                unit("unit:hot-controller:summary", "uas:model-component:hot-controller:summary", "model_component", "route-card:query-aware-kv-local-summary", "hot controller keeps the route small", "hot", 24 * 1024 * 1024),
                unit("unit:kv-page:summary-evidence-a", "uas:kv-page:summary:evidence:a", "kv_page", UPSTREAM_QUERY_SELECTOR, "query selector picked required evidence page A", "kv", 32 * 1024 * 1024),
                unit("unit:kv-page:summary-evidence-b", "uas:kv-page:summary:evidence:b", "kv_page", UPSTREAM_QUERY_SELECTOR, "query selector picked required evidence page B", "kv", 28 * 1024 * 1024),
                unit("unit:citation:summary-vault", "uas:eidos:citation:summary-vault", "citation_source", "eidos:summary:citation", "citations must be exposed in AnswerPacket", "cold", 96 * 1024 * 1024),
                unit("unit:verifier:summary-factuality", "uas:verifier:summary-factuality", "verifier_tool", UPSTREAM_VERIFIER_AUCTION, "factuality verifier is required before answer", "hot", 8 * 1024 * 1024),
                unit("unit:test:summary-regression", "uas:test:summary-regression", "test_harness", "test:summary-regression-suite", "summary regression test result must be exposed", "hot", 6 * 1024 * 1024),
                unselected_unit("unit:rejected:wake-all-summary", "uas:model-component:wake-all-summary", "model_component", "wake-all baseline rejected", "cold", 512 * 1024 * 1024),
            ],
            max_hot_bytes: MAX_HOT_BYTES,
            max_kv_bytes: MAX_KV_BYTES,
            max_cold_bytes: MAX_COLD_BYTES,
            max_latency_ms: MAX_LATENCY_MS,
            uncertainty_bps: 1_800,
            fallback_route: "fallback:apple-private-summary-with-citations".to_string(),
            rollback_handle: "rollback:sparse-wake:local-summary-proof".to_string(),
            run_event_log_ref: "runevent:sparse-wake:local-summary-proof".to_string(),
            answer_packet_visible_fields: REQUIRED_PACKET_FIELDS.iter().map(|field| field.to_string()).collect(),
            verifier_pass_bps: 9_200,
            citation_pass_bps: 9_100,
            test_pass_bps: 8_800,
            proposal_only_baseline_bps: 6_000,
            route_only_baseline_bps: 5_500,
            hidden_answer_baseline_bps: 0,
            certificate_metadata_bytes: 32_768,
            route_authority: "shadow_only".to_string(),
            live_route_promoted: false,
            hidden_chain_exposed: false,
            hidden_cloud: false,
            runtime_bytes_loaded: 0,
        },
        SparseWakeCertificateFixture {
            certificate_id: "sparse-wake-cert:proof-repair-citation".to_string(),
            mission_id: "mission:proof-repair-citation".to_string(),
            answer_packet_ref: "answerpacket:sparse-wake:proof-repair-citation".to_string(),
            upstream_sparse_wake_ref: UPSTREAM_SPARSE_WAKE.to_string(),
            upstream_verifier_auction_ref: UPSTREAM_VERIFIER_AUCTION.to_string(),
            upstream_query_selector_ref: UPSTREAM_QUERY_SELECTOR.to_string(),
            route_card_ref: "route-card:proof-repair-query-kv".to_string(),
            selected_unit_ids: vec![
                "unit:hot-controller:proof".to_string(),
                "unit:kv-page:proof-premise-a".to_string(),
                "unit:kv-page:proof-premise-b".to_string(),
                "unit:citation:proof-source".to_string(),
                "unit:verifier:proof-checker".to_string(),
                "unit:test:proof-regression".to_string(),
            ],
            units: vec![
                unit("unit:hot-controller:proof", "uas:model-component:hot-controller:proof", "model_component", "route-card:proof-repair-query-kv", "hot controller keeps proof repair bounded", "hot", 26 * 1024 * 1024),
                unit("unit:kv-page:proof-premise-a", "uas:kv-page:proof:premise:a", "kv_page", UPSTREAM_QUERY_SELECTOR, "query selector picked premise A", "kv", 30 * 1024 * 1024),
                unit("unit:kv-page:proof-premise-b", "uas:kv-page:proof:premise:b", "kv_page", UPSTREAM_QUERY_SELECTOR, "query selector picked premise B", "kv", 30 * 1024 * 1024),
                unit("unit:citation:proof-source", "uas:eidos:citation:proof-source", "citation_source", "eidos:proof:citation", "proof source must be exposed", "cold", 128 * 1024 * 1024),
                unit("unit:verifier:proof-checker", "uas:verifier:proof-checker", "verifier_tool", UPSTREAM_VERIFIER_AUCTION, "proof checker result is required", "hot", 10 * 1024 * 1024),
                unit("unit:test:proof-regression", "uas:test:proof-regression", "test_harness", "test:proof-regression-suite", "regression test result must be exposed", "hot", 6 * 1024 * 1024),
                unselected_unit("unit:rejected:dense-proof", "uas:model-component:dense-proof", "model_component", "dense proof route rejected", "cold", 1024 * 1024 * 1024),
            ],
            max_hot_bytes: MAX_HOT_BYTES,
            max_kv_bytes: MAX_KV_BYTES,
            max_cold_bytes: MAX_COLD_BYTES,
            max_latency_ms: MAX_LATENCY_MS,
            uncertainty_bps: 2_100,
            fallback_route: "fallback:proof-repair-abstain-with-visible-gap".to_string(),
            rollback_handle: "rollback:sparse-wake:proof-repair-citation".to_string(),
            run_event_log_ref: "runevent:sparse-wake:proof-repair-citation".to_string(),
            answer_packet_visible_fields: REQUIRED_PACKET_FIELDS.iter().map(|field| field.to_string()).collect(),
            verifier_pass_bps: 9_300,
            citation_pass_bps: 9_000,
            test_pass_bps: 8_700,
            proposal_only_baseline_bps: 6_500,
            route_only_baseline_bps: 5_800,
            hidden_answer_baseline_bps: 0,
            certificate_metadata_bytes: 36_864,
            route_authority: "shadow_only".to_string(),
            live_route_promoted: false,
            hidden_chain_exposed: false,
            hidden_cloud: false,
            runtime_bytes_loaded: 0,
        },
    ]
}

fn unit(
    unit_id: &str,
    uas_address: &str,
    unit_kind: &str,
    source_ref: &str,
    selected_reason: &str,
    budget_class: &str,
    byte_count: u64,
) -> CertifiedWakeUnit {
    CertifiedWakeUnit {
        unit_id: unit_id.to_string(),
        uas_address: uas_address.to_string(),
        unit_kind: unit_kind.to_string(),
        source_ref: source_ref.to_string(),
        selected_reason: selected_reason.to_string(),
        budget_class: budget_class.to_string(),
        byte_count,
        verifier_result_ref: format!("verifier:{unit_id}"),
        citation_result_ref: format!("citation:{unit_id}"),
        test_result_ref: format!("test:{unit_id}"),
        trace_ref: format!("trace:{unit_id}"),
        compatibility_fence: CURRENT_FENCE.to_string(),
        privacy_class: "vault_private".to_string(),
        selected: true,
        stale: false,
    }
}

fn unselected_unit(
    unit_id: &str,
    uas_address: &str,
    unit_kind: &str,
    selected_reason: &str,
    budget_class: &str,
    byte_count: u64,
) -> CertifiedWakeUnit {
    CertifiedWakeUnit {
        selected: false,
        ..unit(
            unit_id,
            uas_address,
            unit_kind,
            "shadow-baseline:rejected",
            selected_reason,
            budget_class,
            byte_count,
        )
    }
}

fn add_u64_le_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    ceiling: u64,
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
            operator: "<=".to_string(),
            value: serde_json::Value::from(ceiling),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual <= ceiling);
}

fn add_u64_ge_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    floor: u64,
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
            operator: ">=".to_string(),
            value: serde_json::Value::from(floor),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual >= floor);
}

fn add_u64_lt_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    ceiling: u64,
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
            operator: "<".to_string(),
            value: serde_json::Value::from(ceiling),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual < ceiling);
}

fn add_string_contains_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: &str,
    needle: &str,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(actual.to_string()),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "contains".to_string(),
            value: serde_json::Value::String(needle.to_string()),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual.contains(needle));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn artifact_contains_required_axes() {
        let artifact = build_artifact().expect("artifact builds");
        assert!(artifact.overall_pass);
        for axis in [
            "upstream_sparse_wake_proposal_budget_pass",
            "upstream_verifier_budget_auction_pass",
            "upstream_query_aware_kv_selector_pass",
            "sparse_wake_certificate_fixture_present",
            "answer_packet_required_fields_bound",
            "selected_units_fit_hot_budget",
            "selected_units_fit_kv_budget",
            "selected_units_fit_cold_budget",
            "verifier_results_bound",
            "citation_results_bound",
            "test_results_bound",
            "trace_refs_bound",
            "route_authority_shadow_only",
            "live_route_not_promoted",
            "certificate_beats_proposal_only_baseline",
            "missing_answer_packet_field_rejected",
            "hidden_live_authority_rejected",
            "live_route_promotion_rejected",
            "runtime_bytes_rejected",
            "no_runtime_bytes_loaded",
        ] {
            assert_eq!(artifact.pass_per_axis.get(axis), Some(&true), "{axis}");
        }
    }

    #[test]
    fn empty_fixture_rejects() {
        assert_eq!(
            SparseWakeCertificateRegistry::new(Vec::new()).err(),
            Some(SparseWakeCertificateError::MissingCertificate)
        );
    }

    #[test]
    fn invalid_fixture_cases_reject() {
        for (name, observed, expected) in [
            (
                "missing selected unit",
                invalid_certificate_rejected(|certificate| certificate.selected_unit_ids.clear()),
                SparseWakeCertificateError::MissingSelectedUnit,
            ),
            (
                "missing packet field",
                invalid_certificate_rejected(|certificate| {
                    certificate
                        .answer_packet_visible_fields
                        .retain(|field| field != "rollback");
                }),
                SparseWakeCertificateError::MissingAnswerPacketField,
            ),
            (
                "over hot budget",
                invalid_certificate_rejected(|certificate| certificate.max_hot_bytes = 1),
                SparseWakeCertificateError::HotBudgetExceeded,
            ),
            (
                "high uncertainty",
                invalid_certificate_rejected(|certificate| certificate.uncertainty_bps = 9_000),
                SparseWakeCertificateError::UncertaintyTooHigh,
            ),
            (
                "hidden live authority",
                invalid_certificate_rejected(|certificate| {
                    certificate.route_authority = "live".to_string();
                }),
                SparseWakeCertificateError::HiddenLiveAuthority,
            ),
            (
                "live route promotion",
                invalid_certificate_rejected(|certificate| certificate.live_route_promoted = true),
                SparseWakeCertificateError::LiveRoutePromotion,
            ),
            (
                "missing verifier evidence",
                invalid_selected_unit_rejected(|unit| unit.verifier_result_ref.clear()),
                SparseWakeCertificateError::MissingVerifierResult,
            ),
            (
                "runtime bytes",
                invalid_certificate_rejected(|certificate| certificate.runtime_bytes_loaded = 1),
                SparseWakeCertificateError::RuntimeBytesLoaded,
            ),
        ] {
            assert_eq!(observed, Some(expected), "{name}");
        }
    }

    #[test]
    fn certificate_address_is_order_stable() {
        let registry = SparseWakeCertificateRegistry::new(fixture_certificates()).expect("valid");
        let reversed = fixture_certificates().into_iter().rev().collect::<Vec<_>>();
        let reversed_registry = SparseWakeCertificateRegistry::new(reversed).expect("valid");
        assert_eq!(
            registry.sparse_wake_certificate_address,
            reversed_registry.sparse_wake_certificate_address
        );
    }
}
