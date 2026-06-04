//! `falsify_layer_kv_joint_lease` -- joint depth/KV lease witness.
//!
//! Metadata-only witness for `F-LayerKVJointLease`. It proves dynamic depth
//! and selected KV/page choices are leased together, with attention-error,
//! verifier-margin, byte, latency, fallback, rollback, RunEventLog, and
//! AnswerPacket accounting before any sparse route authority can promote.

use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-LayerKVJointLease";
const FIXTURE_ID: &str = "layer_kv_joint_lease_v1";
const COMMAND: &str = "Tools/falsifiers/f_layer_kv_joint_lease.sh";
const RESULT: &str = "artifacts/falsifiers/layer_kv_joint_lease/result.json";
const UPSTREAM_SPARSE_CERTIFICATE: &str =
    "artifacts/falsifiers/sparse_wake_certificate_answer_packet/result.json";

const CURRENT_FENCE: &str = "fence:model:qwen3.5:kv:v1:tokenizer:qwen3.5:adapter:none";
const MAX_HOT_BYTES: u64 = 112 * 1024 * 1024;
const MAX_KV_BYTES: u64 = 192 * 1024 * 1024;
const MAX_COLD_BYTES: u64 = 2 * 1024 * 1024 * 1024;
const MAX_LATENCY_MS: u64 = 260;
const MAX_EXTRA_LAYERS: u64 = 12;
const MAX_ATTENTION_ERROR_BPS: u64 = 1_200;
const MIN_VERIFIER_MARGIN_BPS: u64 = 1_500;
const MIN_PAGE_UTILITY_BPS: u64 = 7_000;
const MIN_LEASE_SUCCESS_BPS: u64 = 9_000;
const MAX_LEASE_METADATA_BYTES: u64 = 1_048_576;
const REQUIRED_PACKET_FIELDS: &[&str] = &[
    "joint_depth_kv_lease",
    "depth_plan",
    "kv_pages",
    "attention_error",
    "verifier_margin",
    "fallback",
    "rollback",
    "route_authority",
];

#[derive(Clone)]
// UAS: uas:layer-kv-joint-lease:depth-plan
// Plane: Controller + Assembly
// Residency: metadata-only depth decision; no layer bytes loaded.
struct DepthPlan {
    shallow_exit_layer: u16,
    full_depth_layer: u16,
    selected_layers: Vec<u16>,
    checkpoint_refs: Vec<String>,
    max_extra_layers: u64,
    compatibility_fence: String,
}

#[derive(Clone)]
// UAS: uas:layer-kv-joint-lease:kv-page
// Plane: Assembly + Verification
// Residency: metadata-only KV/page choice; no KV bytes restored.
struct KvPageChoice {
    page_id: String,
    uas_address: String,
    source_ref: String,
    page_digest: String,
    token_range: String,
    page_bytes: u64,
    utility_bps: u64,
    compatibility_fence: String,
    privacy_class: String,
    selected: bool,
    stale: bool,
    required_evidence: bool,
}

#[derive(Clone)]
// UAS: uas:layer-kv-joint-lease:fixture
// Plane: Controller + Assembly + Verification
// Residency: metadata-only joint lease proof.
struct LayerKvJointLeaseFixture {
    lease_id: String,
    mission_id: String,
    answer_packet_ref: String,
    upstream_certificate_ref: String,
    route_card_ref: String,
    joint_decision_ref: String,
    depth_plan: DepthPlan,
    kv_pages: Vec<KvPageChoice>,
    hot_byte_budget: u64,
    kv_byte_budget: u64,
    cold_byte_budget: u64,
    latency_budget_ms: u64,
    expected_attention_error_bps: u64,
    verifier_margin_bps: u64,
    lease_success_bps: u64,
    depth_only_baseline_bps: u64,
    kv_only_baseline_bps: u64,
    independent_greedy_baseline_bps: u64,
    shallow_wrong_page_baseline_bps: u64,
    lease_metadata_bytes: u64,
    fallback_route: String,
    rollback_handle: String,
    run_event_log_ref: String,
    answer_packet_visible_fields: Vec<String>,
    route_authority: String,
    live_route_promoted: bool,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    runtime_bytes_loaded: u64,
}

#[derive(Default, Clone, Copy)]
// UAS: uas:layer-kv-joint-lease:metrics
// Plane: Verification
// Residency: metadata-only summary.
struct LeaseMetrics {
    lease_count: u64,
    selected_kv_page_count: u64,
    required_evidence_page_count: u64,
    depth_checkpoint_count: u64,
    max_extra_layers: u64,
    max_hot_bytes: u64,
    max_kv_bytes: u64,
    max_cold_bytes: u64,
    max_latency_ms: u64,
    max_attention_error_bps: u64,
    min_verifier_margin_bps: u64,
    min_page_utility_bps: u64,
    lease_success_bps: u64,
    depth_only_baseline_bps: u64,
    kv_only_baseline_bps: u64,
    independent_greedy_baseline_bps: u64,
    shallow_wrong_page_baseline_bps: u64,
    max_lease_metadata_bytes: u64,
}

#[derive(Debug, Eq, PartialEq)]
// UAS: uas:layer-kv-joint-lease:error
// Plane: Verification
// Residency: metadata-only rejection reason.
enum LayerKvJointLeaseError {
    MissingLease,
    DuplicateLease,
    MissingLeaseId,
    MissingMission,
    MissingAnswerPacket,
    MissingUpstreamCertificate,
    MissingRouteCard,
    MissingJointDecision,
    MissingDepthPlan,
    MissingSelectedLayer,
    InvalidDepthOrder,
    ExtraLayerBudgetExceeded,
    MissingCheckpoint,
    MissingDepthFence,
    IncompatibleDepthFence,
    MissingKvPage,
    MissingSelectedKvPage,
    DuplicateKvPage,
    MissingPageId,
    MissingUasAddress,
    MissingSourceRef,
    MissingDigest,
    MissingTokenRange,
    MissingPageBytes,
    MissingPageUtility,
    MissingPageFence,
    IncompatiblePageFence,
    InvalidPrivacyClass,
    StalePageSelected,
    MissingRequiredEvidencePage,
    JointCouplingMissing,
    HotBudgetExceeded,
    KvBudgetExceeded,
    ColdBudgetExceeded,
    LatencyBudgetExceeded,
    MissingAttentionError,
    AttentionErrorTooHigh,
    MissingVerifierMargin,
    VerifierMarginTooLow,
    MissingFullDepthFallback,
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
    ShallowWrongPageAccepted,
    UnbeatenBaseline,
}

impl std::fmt::Display for LayerKvJointLeaseError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for LayerKvJointLeaseError {}

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

    let lease_count = artifact
        .measurements
        .get("lease_count")
        .and_then(|m| m.value.as_u64())
        .unwrap_or(0);
    let selected_kv_page_count = artifact
        .measurements
        .get("selected_kv_page_count")
        .and_then(|m| m.value.as_u64())
        .unwrap_or(0);
    let lease_success_bps = artifact
        .measurements
        .get("lease_success_bps")
        .and_then(|m| m.value.as_u64())
        .unwrap_or(0);
    let lease_address = artifact
        .measurements
        .get("layer_kv_joint_lease_address")
        .and_then(|m| m.value.as_str())
        .unwrap_or("unknown");
    println!(
        "{FALSIFIER_ID}: overall_pass={} lease_count={} selected_kv_page_count={} lease_success_bps={} lease_address={lease_address:?} artifact={RESULT}",
        artifact.overall_pass, lease_count, selected_kv_page_count, lease_success_bps
    );
    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact() -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, String> {
    let leases = fixture_leases();
    let registry = LayerKvJointLeaseRegistry::new(leases.clone()).map_err(|e| e.to_string())?;
    let metrics = registry.metrics();
    let lease_address = registry.lease_address()?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let upstream_pass = upstream_artifact_pass(UPSTREAM_SPARSE_CERTIFICATE);
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "upstream_sparse_wake_certificate_answer_packet_pass",
        upstream_pass,
    );

    for (name, pass) in registry.axis_bools(&lease_address) {
        add_bool_axis(&mut measurements, &mut thresholds, &mut pass_per_axis, name, pass);
    }
    for (name, pass) in invalid_fixture_axes(&leases) {
        add_bool_axis(&mut measurements, &mut thresholds, &mut pass_per_axis, name, pass);
    }

    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "lease_count",
        metrics.lease_count,
        2,
        "lease",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "selected_kv_page_count",
        metrics.selected_kv_page_count,
        6,
        "page",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "required_evidence_page_count",
        metrics.required_evidence_page_count,
        4,
        "page",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "depth_checkpoint_count",
        metrics.depth_checkpoint_count,
        4,
        "checkpoint",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_extra_layers",
        metrics.max_extra_layers,
        MAX_EXTRA_LAYERS,
        "layer",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_hot_bytes",
        metrics.max_hot_bytes,
        MAX_HOT_BYTES,
        "bytes",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_kv_bytes",
        metrics.max_kv_bytes,
        MAX_KV_BYTES,
        "bytes",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_cold_bytes",
        metrics.max_cold_bytes,
        MAX_COLD_BYTES,
        "bytes",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_latency_ms",
        metrics.max_latency_ms,
        MAX_LATENCY_MS,
        "ms",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_attention_error_bps",
        metrics.max_attention_error_bps,
        MAX_ATTENTION_ERROR_BPS,
        "bps",
    );
    add_u64_gte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "min_verifier_margin_bps",
        metrics.min_verifier_margin_bps,
        MIN_VERIFIER_MARGIN_BPS,
        "bps",
    );
    add_u64_gte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "min_page_utility_bps",
        metrics.min_page_utility_bps,
        MIN_PAGE_UTILITY_BPS,
        "bps",
    );
    add_u64_gte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "lease_success_bps",
        metrics.lease_success_bps,
        MIN_LEASE_SUCCESS_BPS,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "depth_only_baseline_bps",
        metrics.depth_only_baseline_bps,
        metrics.lease_success_bps,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_only_baseline_bps",
        metrics.kv_only_baseline_bps,
        metrics.lease_success_bps,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "independent_greedy_baseline_bps",
        metrics.independent_greedy_baseline_bps,
        metrics.lease_success_bps,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "shallow_wrong_page_baseline_bps",
        metrics.shallow_wrong_page_baseline_bps,
        metrics.lease_success_bps,
        "bps",
    );
    add_u64_lte_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_lease_metadata_bytes",
        metrics.max_lease_metadata_bytes,
        MAX_LEASE_METADATA_BYTES,
        "bytes",
    );
    add_label_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "layer_kv_joint_lease_address",
        &lease_address,
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
            "kind": "metadata_only_scope",
            "detail": "LayerKVJointLease proves joint depth/KV lease shape and rejection behavior only; it loads no model bytes, restores no live KV pages, and promotes no live sparse route authority."
        })],
        notes: "metadata-only Meta Control witness; dynamic depth and KV/page choices are leased together with attention-error, verifier-margin, fallback, rollback, RunEventLog, AnswerPacket, no-hidden-authority, and zero-runtime-byte guards; L1 only, not product/live 70B evidence".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();
    Ok(artifact)
}

// UAS: uas:layer-kv-joint-lease:registry
// Plane: Controller + Assembly + Verification
// Residency: metadata-only registry; validates lease shape before artifact emission.
struct LayerKvJointLeaseRegistry {
    leases: Vec<LayerKvJointLeaseFixture>,
}

impl LayerKvJointLeaseRegistry {
    fn new(leases: Vec<LayerKvJointLeaseFixture>) -> Result<Self, LayerKvJointLeaseError> {
        validate_leases(&leases)?;
        Ok(Self { leases })
    }

    fn metrics(&self) -> LeaseMetrics {
        let mut metrics = LeaseMetrics {
            lease_count: self.leases.len() as u64,
            min_verifier_margin_bps: u64::MAX,
            min_page_utility_bps: u64::MAX,
            lease_success_bps: u64::MAX,
            depth_only_baseline_bps: 0,
            kv_only_baseline_bps: 0,
            independent_greedy_baseline_bps: 0,
            shallow_wrong_page_baseline_bps: 0,
            ..LeaseMetrics::default()
        };
        for lease in &self.leases {
            metrics.depth_checkpoint_count += lease.depth_plan.checkpoint_refs.len() as u64;
            metrics.max_extra_layers = metrics
                .max_extra_layers
                .max(lease.depth_plan.max_extra_layers);
            metrics.max_hot_bytes = metrics.max_hot_bytes.max(lease.hot_byte_budget);
            metrics.max_kv_bytes = metrics.max_kv_bytes.max(lease.kv_byte_budget);
            metrics.max_cold_bytes = metrics.max_cold_bytes.max(lease.cold_byte_budget);
            metrics.max_latency_ms = metrics.max_latency_ms.max(lease.latency_budget_ms);
            metrics.max_attention_error_bps = metrics
                .max_attention_error_bps
                .max(lease.expected_attention_error_bps);
            metrics.min_verifier_margin_bps = metrics
                .min_verifier_margin_bps
                .min(lease.verifier_margin_bps);
            metrics.lease_success_bps = metrics.lease_success_bps.min(lease.lease_success_bps);
            metrics.depth_only_baseline_bps = metrics
                .depth_only_baseline_bps
                .max(lease.depth_only_baseline_bps);
            metrics.kv_only_baseline_bps = metrics.kv_only_baseline_bps.max(lease.kv_only_baseline_bps);
            metrics.independent_greedy_baseline_bps = metrics
                .independent_greedy_baseline_bps
                .max(lease.independent_greedy_baseline_bps);
            metrics.shallow_wrong_page_baseline_bps = metrics
                .shallow_wrong_page_baseline_bps
                .max(lease.shallow_wrong_page_baseline_bps);
            metrics.max_lease_metadata_bytes = metrics
                .max_lease_metadata_bytes
                .max(lease.lease_metadata_bytes);
            for page in lease.kv_pages.iter().filter(|page| page.selected) {
                metrics.selected_kv_page_count += 1;
                if page.required_evidence {
                    metrics.required_evidence_page_count += 1;
                }
                metrics.min_page_utility_bps = metrics.min_page_utility_bps.min(page.utility_bps);
            }
        }
        if metrics.min_verifier_margin_bps == u64::MAX {
            metrics.min_verifier_margin_bps = 0;
        }
        if metrics.min_page_utility_bps == u64::MAX {
            metrics.min_page_utility_bps = 0;
        }
        if metrics.lease_success_bps == u64::MAX {
            metrics.lease_success_bps = 0;
        }
        metrics
    }

    fn lease_address(&self) -> Result<String, String> {
        let mut rows = Vec::with_capacity(self.leases.len());
        for lease in &self.leases {
            let mut pages: Vec<_> = lease
                .kv_pages
                .iter()
                .filter(|page| page.selected)
                .map(|page| {
                    serde_json::json!({
                        "page_id": page.page_id,
                        "uas_address": page.uas_address,
                        "digest": page.page_digest,
                        "bytes": page.page_bytes,
                        "utility_bps": page.utility_bps,
                    })
                })
                .collect();
            pages.sort_by(|left, right| {
                left["page_id"]
                    .as_str()
                    .unwrap_or_default()
                    .cmp(right["page_id"].as_str().unwrap_or_default())
            });
            rows.push(serde_json::json!({
                "lease_id": lease.lease_id,
                "mission_id": lease.mission_id,
                "joint_decision_ref": lease.joint_decision_ref,
                "shallow_exit_layer": lease.depth_plan.shallow_exit_layer,
                "full_depth_layer": lease.depth_plan.full_depth_layer,
                "selected_layers": lease.depth_plan.selected_layers,
                "checkpoint_refs": lease.depth_plan.checkpoint_refs,
                "pages": pages,
                "attention_error_bps": lease.expected_attention_error_bps,
                "verifier_margin_bps": lease.verifier_margin_bps,
            }));
        }
        rows.sort_by(|left, right| {
            left["lease_id"]
                .as_str()
                .unwrap_or_default()
                .cmp(right["lease_id"].as_str().unwrap_or_default())
        });
        let bytes = serde_json::to_vec(&rows).map_err(|error| error.to_string())?;
        Ok(format!(
            "uas:layer-kv-joint-lease:{}",
            sha256_hex(&bytes)
                .strip_prefix("sha256:")
                .unwrap_or_default()
        ))
    }

    fn axis_bools(&self, lease_address: &str) -> Vec<(&'static str, bool)> {
        let metrics = self.metrics();
        vec![
            ("layer_kv_joint_lease_fixture_present", !self.leases.is_empty()),
            ("lease_ids_bound", self.leases.iter().all(|lease| !lease.lease_id.is_empty())),
            ("mission_ids_bound", self.leases.iter().all(|lease| !lease.mission_id.is_empty())),
            (
                "answer_packet_refs_bound",
                self.leases.iter().all(|lease| !lease.answer_packet_ref.is_empty()),
            ),
            (
                "upstream_certificate_refs_bound",
                self.leases
                    .iter()
                    .all(|lease| !lease.upstream_certificate_ref.is_empty()),
            ),
            (
                "route_card_refs_bound",
                self.leases.iter().all(|lease| !lease.route_card_ref.is_empty()),
            ),
            (
                "joint_decision_refs_bound",
                self.leases.iter().all(|lease| !lease.joint_decision_ref.is_empty()),
            ),
            (
                "depth_plans_bound",
                self.leases.iter().all(|lease| !lease.depth_plan.selected_layers.is_empty()),
            ),
            (
                "kv_page_choices_bound",
                self.leases.iter().all(|lease| lease.kv_pages.iter().any(|page| page.selected)),
            ),
            (
                "depth_kv_coupling_bound",
                self.leases.iter().all(joint_coupling_present),
            ),
            (
                "checkpoint_refs_bound",
                self.leases
                    .iter()
                    .all(|lease| !lease.depth_plan.checkpoint_refs.is_empty()),
            ),
            (
                "compatibility_fences_bound",
                self.leases.iter().all(|lease| {
                    lease.depth_plan.compatibility_fence == CURRENT_FENCE
                        && lease
                            .kv_pages
                            .iter()
                            .filter(|page| page.selected)
                            .all(|page| page.compatibility_fence == CURRENT_FENCE)
                }),
            ),
            (
                "privacy_classes_bound",
                self.leases.iter().all(|lease| {
                    lease
                        .kv_pages
                        .iter()
                        .filter(|page| page.selected)
                        .all(|page| valid_privacy(&page.privacy_class))
                }),
            ),
            (
                "attention_error_bound",
                metrics.max_attention_error_bps <= MAX_ATTENTION_ERROR_BPS,
            ),
            (
                "verifier_margin_bound",
                metrics.min_verifier_margin_bps >= MIN_VERIFIER_MARGIN_BPS,
            ),
            (
                "full_depth_fallback_bound",
                self.leases
                    .iter()
                    .all(|lease| lease.depth_plan.full_depth_layer > lease.depth_plan.shallow_exit_layer),
            ),
            (
                "answer_packet_required_fields_bound",
                self.leases.iter().all(answer_packet_fields_present),
            ),
            (
                "fallback_bound",
                self.leases.iter().all(|lease| !lease.fallback_route.is_empty()),
            ),
            (
                "rollback_bound",
                self.leases.iter().all(|lease| !lease.rollback_handle.is_empty()),
            ),
            (
                "run_event_log_bound",
                self.leases.iter().all(|lease| !lease.run_event_log_ref.is_empty()),
            ),
            (
                "route_authority_shadow_only",
                self.leases
                    .iter()
                    .all(|lease| lease.route_authority == "shadow_only"),
            ),
            (
                "live_route_not_promoted",
                self.leases.iter().all(|lease| !lease.live_route_promoted),
            ),
            (
                "no_hidden_chain",
                self.leases.iter().all(|lease| !lease.hidden_chain_exposed),
            ),
            (
                "no_hidden_cloud",
                self.leases.iter().all(|lease| !lease.hidden_cloud),
            ),
            (
                "no_runtime_bytes_loaded",
                self.leases.iter().all(|lease| lease.runtime_bytes_loaded == 0),
            ),
            (
                "layer_kv_joint_lease_address_deterministic",
                lease_address.starts_with("uas:layer-kv-joint-lease:"),
            ),
            ("selected_pages_fit_hot_budget", metrics.max_hot_bytes <= MAX_HOT_BYTES),
            ("selected_pages_fit_kv_budget", metrics.max_kv_bytes <= MAX_KV_BYTES),
            ("selected_pages_fit_cold_budget", metrics.max_cold_bytes <= MAX_COLD_BYTES),
            ("joint_latency_bound", metrics.max_latency_ms <= MAX_LATENCY_MS),
            ("extra_layer_bound", metrics.max_extra_layers <= MAX_EXTRA_LAYERS),
            (
                "lease_beats_depth_only_baseline",
                metrics.lease_success_bps > metrics.depth_only_baseline_bps,
            ),
            (
                "lease_beats_kv_only_baseline",
                metrics.lease_success_bps > metrics.kv_only_baseline_bps,
            ),
            (
                "lease_beats_independent_greedy_baseline",
                metrics.lease_success_bps > metrics.independent_greedy_baseline_bps,
            ),
            (
                "shallow_wrong_page_negative_beaten",
                metrics.lease_success_bps > metrics.shallow_wrong_page_baseline_bps,
            ),
            (
                "lease_metadata_bound",
                metrics.max_lease_metadata_bytes <= MAX_LEASE_METADATA_BYTES,
            ),
        ]
    }
}

fn validate_leases(leases: &[LayerKvJointLeaseFixture]) -> Result<(), LayerKvJointLeaseError> {
    if leases.is_empty() {
        return Err(LayerKvJointLeaseError::MissingLease);
    }
    let mut lease_ids = BTreeSet::new();
    for lease in leases {
        validate_lease(lease)?;
        if !lease_ids.insert(lease.lease_id.as_str()) {
            return Err(LayerKvJointLeaseError::DuplicateLease);
        }
    }
    Ok(())
}

fn validate_lease(lease: &LayerKvJointLeaseFixture) -> Result<(), LayerKvJointLeaseError> {
    if lease.lease_id.is_empty() {
        return Err(LayerKvJointLeaseError::MissingLeaseId);
    }
    if lease.mission_id.is_empty() {
        return Err(LayerKvJointLeaseError::MissingMission);
    }
    if lease.answer_packet_ref.is_empty() {
        return Err(LayerKvJointLeaseError::MissingAnswerPacket);
    }
    if lease.upstream_certificate_ref.is_empty() {
        return Err(LayerKvJointLeaseError::MissingUpstreamCertificate);
    }
    if lease.route_card_ref.is_empty() {
        return Err(LayerKvJointLeaseError::MissingRouteCard);
    }
    if lease.joint_decision_ref.is_empty() {
        return Err(LayerKvJointLeaseError::MissingJointDecision);
    }
    validate_depth_plan(&lease.depth_plan)?;
    validate_pages(&lease.kv_pages)?;
    if !joint_coupling_present(lease) {
        return Err(LayerKvJointLeaseError::JointCouplingMissing);
    }
    let selected_pages: Vec<_> = lease.kv_pages.iter().filter(|page| page.selected).collect();
    let selected_bytes = selected_pages.iter().map(|page| page.page_bytes).sum::<u64>();
    if lease.hot_byte_budget == 0 || selected_bytes > lease.hot_byte_budget {
        return Err(LayerKvJointLeaseError::HotBudgetExceeded);
    }
    if lease.kv_byte_budget == 0 || selected_bytes > lease.kv_byte_budget {
        return Err(LayerKvJointLeaseError::KvBudgetExceeded);
    }
    if lease.cold_byte_budget == 0 || selected_bytes > lease.cold_byte_budget {
        return Err(LayerKvJointLeaseError::ColdBudgetExceeded);
    }
    if lease.latency_budget_ms == 0 || lease.latency_budget_ms > MAX_LATENCY_MS {
        return Err(LayerKvJointLeaseError::LatencyBudgetExceeded);
    }
    if lease.expected_attention_error_bps == 0 {
        return Err(LayerKvJointLeaseError::MissingAttentionError);
    }
    if lease.expected_attention_error_bps > MAX_ATTENTION_ERROR_BPS {
        return Err(LayerKvJointLeaseError::AttentionErrorTooHigh);
    }
    if lease.verifier_margin_bps == 0 {
        return Err(LayerKvJointLeaseError::MissingVerifierMargin);
    }
    if lease.verifier_margin_bps < MIN_VERIFIER_MARGIN_BPS {
        return Err(LayerKvJointLeaseError::VerifierMarginTooLow);
    }
    if lease.fallback_route != "full_depth_safe_route" {
        return Err(LayerKvJointLeaseError::MissingFullDepthFallback);
    }
    if !answer_packet_fields_present(lease) {
        return Err(LayerKvJointLeaseError::MissingAnswerPacketField);
    }
    if lease.fallback_route.is_empty() {
        return Err(LayerKvJointLeaseError::MissingFallback);
    }
    if lease.rollback_handle.is_empty() {
        return Err(LayerKvJointLeaseError::MissingRollback);
    }
    if lease.run_event_log_ref.is_empty() {
        return Err(LayerKvJointLeaseError::MissingRunEventLog);
    }
    if lease.route_authority != "shadow_only" {
        return Err(LayerKvJointLeaseError::HiddenLiveAuthority);
    }
    if lease.live_route_promoted {
        return Err(LayerKvJointLeaseError::LiveRoutePromotion);
    }
    if lease.hidden_chain_exposed {
        return Err(LayerKvJointLeaseError::HiddenChainExposure);
    }
    if lease.hidden_cloud {
        return Err(LayerKvJointLeaseError::CloudSource);
    }
    if lease.runtime_bytes_loaded != 0 {
        return Err(LayerKvJointLeaseError::RuntimeBytesLoaded);
    }
    if lease.lease_metadata_bytes == 0 || lease.lease_metadata_bytes > MAX_LEASE_METADATA_BYTES {
        return Err(LayerKvJointLeaseError::MetadataBudgetExceeded);
    }
    if lease.shallow_wrong_page_baseline_bps >= lease.lease_success_bps {
        return Err(LayerKvJointLeaseError::ShallowWrongPageAccepted);
    }
    if lease.depth_only_baseline_bps >= lease.lease_success_bps
        || lease.kv_only_baseline_bps >= lease.lease_success_bps
        || lease.independent_greedy_baseline_bps >= lease.lease_success_bps
    {
        return Err(LayerKvJointLeaseError::UnbeatenBaseline);
    }
    Ok(())
}

fn validate_depth_plan(plan: &DepthPlan) -> Result<(), LayerKvJointLeaseError> {
    if plan.selected_layers.is_empty() {
        return Err(LayerKvJointLeaseError::MissingDepthPlan);
    }
    if plan.shallow_exit_layer == 0 || plan.full_depth_layer <= plan.shallow_exit_layer {
        return Err(LayerKvJointLeaseError::InvalidDepthOrder);
    }
    let mut seen = BTreeSet::new();
    let mut previous = 0;
    for layer in &plan.selected_layers {
        if *layer == 0 || *layer < previous || !seen.insert(*layer) {
            return Err(LayerKvJointLeaseError::MissingSelectedLayer);
        }
        previous = *layer;
    }
    let max_selected = plan
        .selected_layers
        .last()
        .copied()
        .ok_or(LayerKvJointLeaseError::MissingSelectedLayer)?;
    if u64::from(max_selected.saturating_sub(plan.shallow_exit_layer)) > plan.max_extra_layers
        || plan.max_extra_layers > MAX_EXTRA_LAYERS
    {
        return Err(LayerKvJointLeaseError::ExtraLayerBudgetExceeded);
    }
    if plan.checkpoint_refs.is_empty() || plan.checkpoint_refs.iter().any(|item| item.is_empty()) {
        return Err(LayerKvJointLeaseError::MissingCheckpoint);
    }
    if plan.compatibility_fence.is_empty() {
        return Err(LayerKvJointLeaseError::MissingDepthFence);
    }
    if plan.compatibility_fence != CURRENT_FENCE {
        return Err(LayerKvJointLeaseError::IncompatibleDepthFence);
    }
    Ok(())
}

fn validate_pages(pages: &[KvPageChoice]) -> Result<(), LayerKvJointLeaseError> {
    if pages.is_empty() {
        return Err(LayerKvJointLeaseError::MissingKvPage);
    }
    if !pages.iter().any(|page| page.selected) {
        return Err(LayerKvJointLeaseError::MissingSelectedKvPage);
    }
    if !pages.iter().any(|page| page.selected && page.required_evidence) {
        return Err(LayerKvJointLeaseError::MissingRequiredEvidencePage);
    }
    let mut page_ids = BTreeSet::new();
    for page in pages {
        if page.page_id.is_empty() {
            return Err(LayerKvJointLeaseError::MissingPageId);
        }
        if !page_ids.insert(page.page_id.as_str()) {
            return Err(LayerKvJointLeaseError::DuplicateKvPage);
        }
        if !page.selected {
            continue;
        }
        if page.uas_address.is_empty() {
            return Err(LayerKvJointLeaseError::MissingUasAddress);
        }
        if page.source_ref.is_empty() {
            return Err(LayerKvJointLeaseError::MissingSourceRef);
        }
        if page.page_digest.is_empty() {
            return Err(LayerKvJointLeaseError::MissingDigest);
        }
        if page.token_range.is_empty() {
            return Err(LayerKvJointLeaseError::MissingTokenRange);
        }
        if page.page_bytes == 0 {
            return Err(LayerKvJointLeaseError::MissingPageBytes);
        }
        if page.utility_bps == 0 {
            return Err(LayerKvJointLeaseError::MissingPageUtility);
        }
        if page.utility_bps < MIN_PAGE_UTILITY_BPS {
            return Err(LayerKvJointLeaseError::VerifierMarginTooLow);
        }
        if page.compatibility_fence.is_empty() {
            return Err(LayerKvJointLeaseError::MissingPageFence);
        }
        if page.compatibility_fence != CURRENT_FENCE {
            return Err(LayerKvJointLeaseError::IncompatiblePageFence);
        }
        if !valid_privacy(&page.privacy_class) {
            return Err(LayerKvJointLeaseError::InvalidPrivacyClass);
        }
        if page.stale {
            return Err(LayerKvJointLeaseError::StalePageSelected);
        }
    }
    Ok(())
}

fn joint_coupling_present(lease: &LayerKvJointLeaseFixture) -> bool {
    !lease.joint_decision_ref.is_empty()
        && !lease.depth_plan.selected_layers.is_empty()
        && lease.kv_pages.iter().any(|page| page.selected)
        && lease
            .joint_decision_ref
            .contains(&lease.depth_plan.shallow_exit_layer.to_string())
}

fn answer_packet_fields_present(lease: &LayerKvJointLeaseFixture) -> bool {
    REQUIRED_PACKET_FIELDS
        .iter()
        .all(|field| lease.answer_packet_visible_fields.iter().any(|present| present == field))
}

fn valid_privacy(value: &str) -> bool {
    matches!(value, "local_private" | "local_sensitive" | "project_private")
}

fn invalid_fixture_axes(
    fixtures: &[LayerKvJointLeaseFixture],
) -> Vec<(&'static str, bool)> {
    let cases: Vec<(&'static str, fn(&mut Vec<LayerKvJointLeaseFixture>), LayerKvJointLeaseError)> = vec![
        ("duplicate_lease_rejected", |leases| leases.push(leases[0].clone()), LayerKvJointLeaseError::DuplicateLease),
        ("duplicate_kv_page_rejected", |leases| {
            let duplicate = leases[0].kv_pages[0].clone();
            leases[0].kv_pages.push(duplicate);
        }, LayerKvJointLeaseError::DuplicateKvPage),
        ("missing_depth_plan_rejected", |leases| leases[0].depth_plan.selected_layers.clear(), LayerKvJointLeaseError::MissingDepthPlan),
        ("missing_selected_kv_page_rejected", |leases| leases[0].kv_pages.iter_mut().for_each(|page| page.selected = false), LayerKvJointLeaseError::MissingSelectedKvPage),
        ("missing_joint_decision_rejected", |leases| leases[0].joint_decision_ref.clear(), LayerKvJointLeaseError::MissingJointDecision),
        ("uncoupled_depth_kv_rejected", |leases| leases[0].joint_decision_ref = "lease:uncoupled".to_string(), LayerKvJointLeaseError::JointCouplingMissing),
        ("stale_kv_page_rejected", |leases| leases[0].kv_pages[0].stale = true, LayerKvJointLeaseError::StalePageSelected),
        ("incompatible_depth_fence_rejected", |leases| leases[0].depth_plan.compatibility_fence = "fence:model:other".to_string(), LayerKvJointLeaseError::IncompatibleDepthFence),
        ("incompatible_page_fence_rejected", |leases| leases[0].kv_pages[0].compatibility_fence = "fence:model:other".to_string(), LayerKvJointLeaseError::IncompatiblePageFence),
        ("invalid_privacy_class_rejected", |leases| leases[0].kv_pages[0].privacy_class = "public_cloud".to_string(), LayerKvJointLeaseError::InvalidPrivacyClass),
        ("over_hot_budget_rejected", |leases| leases[0].hot_byte_budget = 1, LayerKvJointLeaseError::HotBudgetExceeded),
        ("over_kv_budget_rejected", |leases| leases[0].kv_byte_budget = 1, LayerKvJointLeaseError::KvBudgetExceeded),
        ("over_cold_budget_rejected", |leases| leases[0].cold_byte_budget = 1, LayerKvJointLeaseError::ColdBudgetExceeded),
        ("over_latency_rejected", |leases| leases[0].latency_budget_ms = MAX_LATENCY_MS + 1, LayerKvJointLeaseError::LatencyBudgetExceeded),
        ("over_extra_layers_rejected", |leases| leases[0].depth_plan.max_extra_layers = MAX_EXTRA_LAYERS + 1, LayerKvJointLeaseError::ExtraLayerBudgetExceeded),
        ("attention_error_too_high_rejected", |leases| leases[0].expected_attention_error_bps = MAX_ATTENTION_ERROR_BPS + 1, LayerKvJointLeaseError::AttentionErrorTooHigh),
        ("verifier_margin_too_low_rejected", |leases| leases[0].verifier_margin_bps = MIN_VERIFIER_MARGIN_BPS - 1, LayerKvJointLeaseError::VerifierMarginTooLow),
        ("missing_full_depth_fallback_rejected", |leases| leases[0].fallback_route = "cheap_retry".to_string(), LayerKvJointLeaseError::MissingFullDepthFallback),
        ("missing_rollback_rejected", |leases| leases[0].rollback_handle.clear(), LayerKvJointLeaseError::MissingRollback),
        ("missing_run_event_log_rejected", |leases| leases[0].run_event_log_ref.clear(), LayerKvJointLeaseError::MissingRunEventLog),
        ("missing_answer_packet_field_rejected", |leases| {
            let _ = leases[0].answer_packet_visible_fields.pop();
        }, LayerKvJointLeaseError::MissingAnswerPacketField),
        ("hidden_live_authority_rejected", |leases| leases[0].route_authority = "live_route".to_string(), LayerKvJointLeaseError::HiddenLiveAuthority),
        ("live_route_promotion_rejected", |leases| leases[0].live_route_promoted = true, LayerKvJointLeaseError::LiveRoutePromotion),
        ("hidden_chain_exposure_rejected", |leases| leases[0].hidden_chain_exposed = true, LayerKvJointLeaseError::HiddenChainExposure),
        ("cloud_source_rejected", |leases| leases[0].hidden_cloud = true, LayerKvJointLeaseError::CloudSource),
        ("runtime_bytes_rejected", |leases| leases[0].runtime_bytes_loaded = 1, LayerKvJointLeaseError::RuntimeBytesLoaded),
        ("metadata_budget_rejected", |leases| leases[0].lease_metadata_bytes = MAX_LEASE_METADATA_BYTES + 1, LayerKvJointLeaseError::MetadataBudgetExceeded),
        ("shallow_wrong_page_negative_rejected", |leases| leases[0].shallow_wrong_page_baseline_bps = leases[0].lease_success_bps, LayerKvJointLeaseError::ShallowWrongPageAccepted),
        ("unbeaten_baseline_rejected", |leases| leases[0].independent_greedy_baseline_bps = leases[0].lease_success_bps, LayerKvJointLeaseError::UnbeatenBaseline),
    ];
    cases
        .into_iter()
        .map(|(axis, mutate, expected)| {
            let mut leases = fixtures.to_vec();
            mutate(&mut leases);
            (axis, validate_leases(&leases).is_err_and(|error| error == expected))
        })
        .collect()
}

fn upstream_artifact_pass(path: &str) -> bool {
    for candidate in [
        PathBuf::from(path),
        PathBuf::from("..").join(path),
        PathBuf::from("../..").join(path),
    ] {
        if let Ok(raw) = std::fs::read_to_string(candidate) {
            if let Ok(value) = serde_json::from_str::<serde_json::Value>(&raw) {
                return value
                    .get("overall_pass")
                    .and_then(|pass| pass.as_bool())
                    .unwrap_or(false);
            }
        }
    }
    false
}

fn fixture_leases() -> Vec<LayerKvJointLeaseFixture> {
    vec![
        LayerKvJointLeaseFixture {
            lease_id: "lease:local-summary:depth-kv:001".to_string(),
            mission_id: "mission:local-summary-with-proof-sources".to_string(),
            answer_packet_ref: "answer:local-summary:packet:001".to_string(),
            upstream_certificate_ref: "sparse-cert:local-summary:001".to_string(),
            route_card_ref: "route-card:local-summary:proof-visible".to_string(),
            joint_decision_ref: "joint-depth-kv:exit-18:pages-source-a-source-b-source-c".to_string(),
            depth_plan: DepthPlan {
                shallow_exit_layer: 18,
                full_depth_layer: 32,
                selected_layers: vec![18, 22, 26],
                checkpoint_refs: vec![
                    "checkpoint:layer:18:summary".to_string(),
                    "checkpoint:layer:26:verifier".to_string(),
                ],
                max_extra_layers: 8,
                compatibility_fence: CURRENT_FENCE.to_string(),
            },
            kv_pages: vec![
                kv_page("kv:summary:source-a", 9_437_184, 8_900, true),
                kv_page("kv:summary:source-b", 8_388_608, 8_500, true),
                kv_page("kv:summary:source-c", 7_340_032, 8_100, false),
            ],
            hot_byte_budget: 64 * 1024 * 1024,
            kv_byte_budget: 72 * 1024 * 1024,
            cold_byte_budget: 512 * 1024 * 1024,
            latency_budget_ms: 180,
            expected_attention_error_bps: 760,
            verifier_margin_bps: 2_250,
            lease_success_bps: 9_700,
            depth_only_baseline_bps: 7_400,
            kv_only_baseline_bps: 7_900,
            independent_greedy_baseline_bps: 8_100,
            shallow_wrong_page_baseline_bps: 6_300,
            lease_metadata_bytes: 262_144,
            fallback_route: "full_depth_safe_route".to_string(),
            rollback_handle: "rollback:lease:local-summary:001".to_string(),
            run_event_log_ref: "runlog:lease:local-summary:001".to_string(),
            answer_packet_visible_fields: REQUIRED_PACKET_FIELDS
                .iter()
                .map(|field| (*field).to_string())
                .collect(),
            route_authority: "shadow_only".to_string(),
            live_route_promoted: false,
            hidden_chain_exposed: false,
            hidden_cloud: false,
            runtime_bytes_loaded: 0,
        },
        LayerKvJointLeaseFixture {
            lease_id: "lease:proof-repair:depth-kv:002".to_string(),
            mission_id: "mission:proof-repair-with-citation-risk".to_string(),
            answer_packet_ref: "answer:proof-repair:packet:002".to_string(),
            upstream_certificate_ref: "sparse-cert:proof-repair:002".to_string(),
            route_card_ref: "route-card:proof-repair:verifier-visible".to_string(),
            joint_decision_ref: "joint-depth-kv:exit-20:pages-proof-a-proof-b-proof-c".to_string(),
            depth_plan: DepthPlan {
                shallow_exit_layer: 20,
                full_depth_layer: 32,
                selected_layers: vec![20, 24, 28],
                checkpoint_refs: vec![
                    "checkpoint:layer:20:proof".to_string(),
                    "checkpoint:layer:28:citation".to_string(),
                ],
                max_extra_layers: 8,
                compatibility_fence: CURRENT_FENCE.to_string(),
            },
            kv_pages: vec![
                kv_page("kv:proof:source-a", 10_485_760, 9_100, true),
                kv_page("kv:proof:source-b", 9_961_472, 8_700, true),
                kv_page("kv:proof:source-c", 8_912_896, 8_300, false),
            ],
            hot_byte_budget: 72 * 1024 * 1024,
            kv_byte_budget: 80 * 1024 * 1024,
            cold_byte_budget: 640 * 1024 * 1024,
            latency_budget_ms: 210,
            expected_attention_error_bps: 840,
            verifier_margin_bps: 2_050,
            lease_success_bps: 9_500,
            depth_only_baseline_bps: 7_200,
            kv_only_baseline_bps: 7_700,
            independent_greedy_baseline_bps: 8_000,
            shallow_wrong_page_baseline_bps: 5_900,
            lease_metadata_bytes: 294_912,
            fallback_route: "full_depth_safe_route".to_string(),
            rollback_handle: "rollback:lease:proof-repair:002".to_string(),
            run_event_log_ref: "runlog:lease:proof-repair:002".to_string(),
            answer_packet_visible_fields: REQUIRED_PACKET_FIELDS
                .iter()
                .map(|field| (*field).to_string())
                .collect(),
            route_authority: "shadow_only".to_string(),
            live_route_promoted: false,
            hidden_chain_exposed: false,
            hidden_cloud: false,
            runtime_bytes_loaded: 0,
        },
    ]
}

fn kv_page(page_id: &str, bytes: u64, utility_bps: u64, required_evidence: bool) -> KvPageChoice {
    KvPageChoice {
        page_id: page_id.to_string(),
        uas_address: format!("uas:kv-page:{page_id}"),
        source_ref: format!("source:{page_id}"),
        page_digest: sha256_hex(page_id.as_bytes()),
        token_range: "0..4096".to_string(),
        page_bytes: bytes,
        utility_bps,
        compatibility_fence: CURRENT_FENCE.to_string(),
        privacy_class: "local_private".to_string(),
        selected: true,
        stale: false,
        required_evidence,
    }
}

fn add_u64_lte_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    ceiling: u64,
    unit: &str,
) {
    add_u64_threshold_axis(
        measurements,
        thresholds,
        pass_per_axis,
        name,
        actual,
        "<=",
        ceiling,
        unit,
        actual <= ceiling,
    );
}

fn add_u64_gte_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    floor: u64,
    unit: &str,
) {
    add_u64_threshold_axis(
        measurements,
        thresholds,
        pass_per_axis,
        name,
        actual,
        ">=",
        floor,
        unit,
        actual >= floor,
    );
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
    add_u64_threshold_axis(
        measurements,
        thresholds,
        pass_per_axis,
        name,
        actual,
        "<",
        ceiling,
        unit,
        actual < ceiling,
    );
}

fn add_u64_threshold_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    operator: &str,
    threshold: u64,
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
            value: serde_json::Value::from(threshold),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), passed);
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
            value: serde_json::Value::String(value.to_string()),
            unit: "address".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::Value::String("uas:layer-kv-joint-lease:".to_string()),
            unit: "address".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), value.starts_with("uas:layer-kv-joint-lease:"));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn artifact_contains_required_axes() {
        let artifact = build_artifact().expect("artifact builds");
        assert!(artifact.overall_pass);
        for axis in [
            "upstream_sparse_wake_certificate_answer_packet_pass",
            "layer_kv_joint_lease_fixture_present",
            "depth_kv_coupling_bound",
            "attention_error_bound",
            "verifier_margin_bound",
            "full_depth_fallback_bound",
            "shallow_wrong_page_negative_rejected",
            "no_runtime_bytes_loaded",
        ] {
            assert_eq!(artifact.pass_per_axis.get(axis), Some(&true), "{axis}");
        }
    }

    #[test]
    fn invalid_fixture_cases_reject() {
        let leases = fixture_leases();
        for (axis, passed) in invalid_fixture_axes(&leases) {
            assert!(passed, "{axis}");
        }
    }

    #[test]
    fn lease_address_is_order_stable() {
        let registry = LayerKvJointLeaseRegistry::new(fixture_leases()).expect("valid");
        let mut reversed = fixture_leases();
        reversed.reverse();
        let reversed_registry = LayerKvJointLeaseRegistry::new(reversed).expect("valid");
        assert_eq!(
            registry.lease_address().expect("address"),
            reversed_registry.lease_address().expect("address")
        );
    }

    #[test]
    fn empty_fixture_rejects() {
        assert_eq!(
            validate_leases(&[]),
            Err(LayerKvJointLeaseError::MissingLease)
        );
    }
}
