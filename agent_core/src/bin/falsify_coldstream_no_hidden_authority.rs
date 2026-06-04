//! `falsify_coldstream_no_hidden_authority` -- ColdStream authority witness.
//!
//! Metadata-only witness for `F-ColdStream-NoHiddenAuthority`. It proves
//! ColdStream transport manifests stay explicit, cancelable, leased, admitted,
//! rollback-bound, RunEventLog-visible, and AnswerPacket-visible before any
//! byte wake or route-policy claim can promote. No runtime/model bytes move.

use std::collections::{BTreeMap, BTreeSet, HashSet};
use std::path::{Path, PathBuf};

#[cfg(test)]
use agent_core::falsifier_artifacts::axes::COLDSTREAM_NO_HIDDEN_AUTHORITY_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ColdStreamAuthority, ColdStreamCachePolicy, ColdStreamDestination, ColdStreamError,
    ColdStreamPageRun, ColdStreamPriority, ColdStreamTransportManifest, ColdStreamTransportTrace,
    ProStatus, ProductBuild, UasAddress, UasKind,
};

const FALSIFIER_ID: &str = "F-ColdStream-NoHiddenAuthority";
const FIXTURE_ID: &str = "coldstream_no_hidden_authority_v1";
const COMMAND: &str = "Tools/falsifiers/f_coldstream_no_hidden_authority.sh";
const RESULT: &str = "artifacts/falsifiers/coldstream_no_hidden_authority/result.json";
const UPSTREAM_SPARSE_ROUTE: &str =
    "artifacts/falsifiers/sparse_route_no_hidden_authority/result.json";
const CREATED_AT_MS: u64 = 1_779_552_000_000;
const MIN_FIXTURE_COUNT: u64 = 2;
const MIN_MANIFEST_COUNT: u64 = 2;
const MIN_PAGE_RUN_COUNT: u64 = 6;
const MIN_TRACE_COUNT: u64 = 2;
const MIN_DESTINATION_LANE_COUNT: u64 = 3;
const MIN_PRIORITY_LANE_COUNT: u64 = 3;
const MIN_CACHE_POLICY_COUNT: u64 = 2;
const MIN_TRANSPORT_SAFETY_BPS: u64 = 9_250;
const MAX_TRACE_COPY_COUNT: u64 = 2;
const MAX_TRANSPORT_METADATA_BYTES: u64 = 512 * 1024;

#[derive(Clone)]
// UAS: uas:coldstream-no-hidden-authority:fixture
// Plane: Assembly + Controller + Verification
// Residency: metadata-only transport fixture; no cold bytes are loaded.
struct ColdStreamFixture {
    fixture_id: String,
    fixture_scope: String,
    transport_safety_bps: u64,
    hidden_transport_baseline_bps: u64,
    policy_mutation_baseline_bps: u64,
    mmap_fault_baseline_bps: u64,
    no_answer_packet_baseline_bps: u64,
    metadata_bytes: u64,
    manifest: ColdStreamTransportManifest,
    trace: ColdStreamTransportTrace,
}

#[derive(Default)]
// UAS: uas:coldstream-no-hidden-authority:metrics
// Plane: Verification
// Residency: metadata-only aggregation; no runtime/model bytes.
struct ColdStreamMetrics {
    fixture_count: u64,
    manifest_count: u64,
    page_run_count: u64,
    trace_count: u64,
    destination_lane_count: u64,
    priority_lane_count: u64,
    cache_policy_count: u64,
    planned_bytes: u64,
    bytes_requested: u64,
    bytes_read: u64,
    max_trace_copy_count: u64,
    cancellation_count: u64,
    max_p95_stall_ms: u64,
    max_p99_stall_ms: u64,
    min_read_amplification_bps: u64,
    transport_safety_bps: u64,
    hidden_transport_baseline_bps: u64,
    policy_mutation_baseline_bps: u64,
    mmap_fault_baseline_bps: u64,
    no_answer_packet_baseline_bps: u64,
    max_transport_metadata_bytes: u64,
}

// UAS: uas:coldstream-no-hidden-authority:registry
// Plane: Assembly + Controller + Verification
// Residency: offline/shadow-only transport registry.
struct ColdStreamRegistry {
    fixtures: Vec<ColdStreamFixture>,
}

impl ColdStreamRegistry {
    fn new(fixtures: Vec<ColdStreamFixture>) -> Result<Self, ColdStreamWitnessError> {
        validate_fixtures(&fixtures)?;
        Ok(Self { fixtures })
    }

    fn manifests(&self) -> impl Iterator<Item = &ColdStreamTransportManifest> {
        self.fixtures.iter().map(|fixture| &fixture.manifest)
    }

    fn traces(&self) -> impl Iterator<Item = &ColdStreamTransportTrace> {
        self.fixtures.iter().map(|fixture| &fixture.trace)
    }

    fn metrics(&self) -> ColdStreamMetrics {
        let destination_lanes = self
            .manifests()
            .flat_map(|manifest| manifest.page_runs.iter())
            .map(|run| destination_tag(&run.destination))
            .collect::<BTreeSet<_>>();
        let priority_lanes = self
            .manifests()
            .flat_map(|manifest| manifest.page_runs.iter())
            .map(|run| priority_tag(&run.priority))
            .collect::<BTreeSet<_>>();
        let cache_policies = self
            .manifests()
            .flat_map(|manifest| manifest.page_runs.iter())
            .map(|run| cache_policy_tag(&run.cache_policy))
            .collect::<BTreeSet<_>>();
        ColdStreamMetrics {
            fixture_count: self.fixtures.len() as u64,
            manifest_count: self.fixtures.len() as u64,
            page_run_count: self
                .manifests()
                .map(|manifest| manifest.page_runs.len() as u64)
                .sum(),
            trace_count: self.fixtures.len() as u64,
            destination_lane_count: destination_lanes.len() as u64,
            priority_lane_count: priority_lanes.len() as u64,
            cache_policy_count: cache_policies.len() as u64,
            planned_bytes: self
                .manifests()
                .map(ColdStreamTransportManifest::planned_bytes)
                .sum(),
            bytes_requested: self.traces().map(|trace| trace.bytes_requested).sum(),
            bytes_read: self.traces().map(|trace| trace.bytes_read).sum(),
            max_trace_copy_count: self
                .traces()
                .map(|trace| u64::from(trace.copy_count))
                .max()
                .unwrap_or(0),
            cancellation_count: self
                .traces()
                .map(|trace| u64::from(trace.cancellation_count))
                .sum(),
            max_p95_stall_ms: self
                .traces()
                .map(|trace| u64::from(trace.p95_stall_ms))
                .max()
                .unwrap_or(0),
            max_p99_stall_ms: self
                .traces()
                .map(|trace| u64::from(trace.p99_stall_ms))
                .max()
                .unwrap_or(0),
            min_read_amplification_bps: self
                .traces()
                .map(|trace| u64::from(trace.read_amplification_bps))
                .min()
                .unwrap_or(0),
            transport_safety_bps: self
                .fixtures
                .iter()
                .map(|fixture| fixture.transport_safety_bps)
                .min()
                .unwrap_or(0),
            hidden_transport_baseline_bps: self
                .fixtures
                .iter()
                .map(|fixture| fixture.hidden_transport_baseline_bps)
                .max()
                .unwrap_or(0),
            policy_mutation_baseline_bps: self
                .fixtures
                .iter()
                .map(|fixture| fixture.policy_mutation_baseline_bps)
                .max()
                .unwrap_or(0),
            mmap_fault_baseline_bps: self
                .fixtures
                .iter()
                .map(|fixture| fixture.mmap_fault_baseline_bps)
                .max()
                .unwrap_or(0),
            no_answer_packet_baseline_bps: self
                .fixtures
                .iter()
                .map(|fixture| fixture.no_answer_packet_baseline_bps)
                .max()
                .unwrap_or(0),
            max_transport_metadata_bytes: self
                .fixtures
                .iter()
                .map(|fixture| fixture.metadata_bytes)
                .max()
                .unwrap_or(0),
        }
    }

    fn address(&self) -> String {
        let mut parts = self
            .fixtures
            .iter()
            .map(|fixture| {
                format!(
                    "{}|{}|{}|{}|{}|{}",
                    fixture.fixture_id,
                    fixture.manifest.manifest_address,
                    fixture.trace.trace_id,
                    fixture.trace.bytes_requested,
                    fixture.trace.bytes_read,
                    fixture.transport_safety_bps
                )
            })
            .collect::<Vec<_>>();
        parts.sort();
        format!(
            "uas:coldstream-no-hidden-authority:{}",
            sha256_hex(parts.join("\n").as_bytes())
        )
    }
}

#[derive(Debug)]
// UAS: uas:coldstream-no-hidden-authority:witness-error
// Plane: Verification
// Residency: metadata-only witness rejection taxonomy.
enum ColdStreamWitnessError {
    Primitive(ColdStreamError),
    EmptyFixture,
    DuplicateFixture(String),
    DuplicateManifest(String),
    MissingTrace(String),
    TraceWithoutManifest(String),
    SafetyBelowFloor,
    BaselineUnbeaten(&'static str),
    MetadataBudgetExceeded,
}

impl std::fmt::Display for ColdStreamWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::EmptyFixture => write!(f, "missing ColdStream fixture"),
            Self::DuplicateFixture(id) => write!(f, "duplicate fixture `{id}`"),
            Self::DuplicateManifest(id) => write!(f, "duplicate manifest `{id}`"),
            Self::MissingTrace(id) => write!(f, "manifest `{id}` has no trace"),
            Self::TraceWithoutManifest(id) => write!(f, "trace `{id}` has no manifest"),
            Self::SafetyBelowFloor => write!(f, "transport safety below floor"),
            Self::BaselineUnbeaten(name) => write!(f, "baseline `{name}` was unbeaten"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for ColdStreamWitnessError {}

impl From<ColdStreamError> for ColdStreamWitnessError {
    fn from(value: ColdStreamError) -> Self {
        Self::Primitive(value)
    }
}

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
        "{FALSIFIER_ID}: overall_pass={} artifact={RESULT}",
        artifact.overall_pass
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, ColdStreamWitnessError> {
    let registry = ColdStreamRegistry::new(fixture_coldstream_fixtures()?)?;
    let metrics = registry.metrics();
    let address = registry.address();
    let mut reversed = fixture_coldstream_fixtures()?;
    reversed.reverse();
    let deterministic = ColdStreamRegistry::new(reversed)?.address() == address;
    let invalid_axes = invalid_fixture_axes()?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let bool_axes = [
        (
            "upstream_sparse_route_no_hidden_authority_pass",
            upstream_artifact_pass(UPSTREAM_SPARSE_ROUTE),
        ),
        ("coldstream_manifest_present", metrics.manifest_count > 0),
        (
            "manifest_ids_bound",
            registry
                .manifests()
                .all(|manifest| !manifest.manifest_id.is_empty()),
        ),
        (
            "route_ids_bound",
            registry
                .manifests()
                .all(|manifest| !manifest.route_id.is_empty()),
        ),
        (
            "semantic_working_set_plan_bound",
            registry
                .manifests()
                .all(|manifest| manifest.semantic_working_set_plan_ref.starts_with("uas:")),
        ),
        (
            "residency_page_table_bound",
            registry.manifests().all(|manifest| {
                manifest
                    .residency_page_table_ref
                    .starts_with("residency_page_table:")
            }),
        ),
        (
            "page_runs_bound",
            registry
                .manifests()
                .all(|manifest| !manifest.page_runs.is_empty()),
        ),
        (
            "page_run_ids_bound",
            registry
                .manifests()
                .all(|manifest| manifest.page_runs.iter().all(|run| !run.run_id.is_empty())),
        ),
        (
            "file_ranges_bound",
            registry.manifests().all(|manifest| {
                manifest.page_runs.iter().all(|run| {
                    !run.file_id.is_empty()
                        && run.byte_range.len > 0
                        && run.byte_range.end_exclusive() > run.byte_range.start
                })
            }),
        ),
        (
            "semantic_units_bound",
            registry.manifests().all(|manifest| {
                manifest
                    .page_runs
                    .iter()
                    .all(|run| !run.semantic_unit_ids.is_empty())
            }),
        ),
        (
            "uas_addresses_bound",
            registry.manifests().all(|manifest| {
                manifest
                    .page_runs
                    .iter()
                    .all(|run| !run.uas_addresses.is_empty())
            }),
        ),
        (
            "codec_plan_bound",
            registry
                .manifests()
                .all(|manifest| manifest.page_runs.iter().all(|run| !run.codec.is_empty())),
        ),
        (
            "checksum_plan_bound",
            registry.manifests().all(|manifest| {
                manifest.page_runs.iter().all(|run| {
                    run.checksum.starts_with("sha256:") || run.checksum.starts_with("blake3:")
                })
            }),
        ),
        (
            "destination_lanes_bound",
            metrics.destination_lane_count >= MIN_DESTINATION_LANE_COUNT,
        ),
        (
            "priority_lanes_bound",
            metrics.priority_lane_count >= MIN_PRIORITY_LANE_COUNT,
        ),
        (
            "cache_policy_bound",
            metrics.cache_policy_count >= MIN_CACHE_POLICY_COUNT,
        ),
        (
            "lease_refs_bound",
            registry.manifests().all(|manifest| {
                manifest
                    .page_runs
                    .iter()
                    .all(|run| run.lease_ref.starts_with("lease:"))
            }),
        ),
        (
            "cancellation_group_bound",
            registry
                .manifests()
                .all(|manifest| manifest.cancellation_group.starts_with("cancel_group:")),
        ),
        (
            "fallback_bound",
            registry
                .manifests()
                .all(|manifest| manifest.fallback_ref.starts_with("fallback:")),
        ),
        (
            "admission_bound",
            registry
                .manifests()
                .all(|manifest| manifest.admission_ref.starts_with("admission:")),
        ),
        (
            "scope_rex_bound",
            registry
                .manifests()
                .all(|manifest| manifest.scope_rex_ref.starts_with("scope_rex:")),
        ),
        (
            "sovereign_gate_bound",
            registry
                .manifests()
                .all(|manifest| manifest.sovereign_gate_ref.starts_with("sovereign_gate:")),
        ),
        (
            "rollback_bound",
            registry
                .manifests()
                .all(|manifest| manifest.rollback_ref.starts_with("rollback:")),
        ),
        (
            "run_event_log_bound",
            registry
                .manifests()
                .all(|manifest| manifest.run_event_log_ref.starts_with("run_event_log:")),
        ),
        (
            "answer_packet_ref_bound",
            registry
                .manifests()
                .all(|manifest| manifest.answer_packet_ref.starts_with("answer_packet:")),
        ),
        (
            "transport_traces_bound",
            metrics.trace_count == metrics.manifest_count,
        ),
        (
            "trace_bytes_bound",
            metrics.bytes_requested == metrics.planned_bytes,
        ),
        (
            "trace_copies_bound",
            metrics.max_trace_copy_count <= MAX_TRACE_COPY_COUNT,
        ),
        (
            "trace_fallback_visible",
            registry.traces().all(|trace| trace.fallback_visible),
        ),
        (
            "trace_no_stale_slab_execution",
            registry
                .traces()
                .all(|trace| !trace.stale_slab_entered_execution),
        ),
        (
            "proposal_only_transport_authority",
            registry
                .manifests()
                .all(|manifest| manifest.authority == ColdStreamAuthority::ProposalOnly),
        ),
        (
            "product_status_research_only",
            registry.manifests().all(|manifest| {
                manifest.product_build == ProductBuild::Pro
                    && manifest.pro_status == ProStatus::ResearchCandidate
            }),
        ),
        (
            "no_byte_wake_without_lease",
            registry
                .manifests()
                .all(|manifest| !manifest.byte_wake_without_lease),
        ),
        (
            "no_route_policy_mutation",
            registry
                .manifests()
                .all(|manifest| !manifest.route_policy_mutated),
        ),
        (
            "no_scope_rex_override",
            registry
                .manifests()
                .all(|manifest| !manifest.scope_rex_overridden),
        ),
        (
            "no_sovereign_gate_override",
            registry
                .manifests()
                .all(|manifest| !manifest.sovereign_gate_overridden),
        ),
        (
            "no_answer_packet_suppression",
            registry
                .manifests()
                .all(|manifest| !manifest.answer_packet_suppressed),
        ),
        (
            "no_hidden_chain",
            registry
                .manifests()
                .all(|manifest| !manifest.hidden_chain_exposed),
        ),
        (
            "no_hidden_cloud",
            registry
                .manifests()
                .all(|manifest| !manifest.hidden_cloud_route),
        ),
        (
            "no_runtime_bytes_loaded",
            registry
                .manifests()
                .all(|manifest| manifest.runtime_bytes_loaded == 0),
        ),
        (
            "no_model_bytes_loaded",
            registry
                .manifests()
                .all(|manifest| manifest.model_bytes_loaded == 0),
        ),
        (
            "metadata_bound",
            metrics.max_transport_metadata_bytes <= MAX_TRANSPORT_METADATA_BYTES,
        ),
        (
            "coldstream_no_hidden_authority_address_deterministic",
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
        MIN_FIXTURE_COUNT,
        "fixtures",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "manifest_count",
        metrics.manifest_count,
        MIN_MANIFEST_COUNT,
        "manifests",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "page_run_count",
        metrics.page_run_count,
        MIN_PAGE_RUN_COUNT,
        "page_runs",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "trace_count",
        metrics.trace_count,
        MIN_TRACE_COUNT,
        "traces",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "destination_lane_count",
        metrics.destination_lane_count,
        MIN_DESTINATION_LANE_COUNT,
        "lanes",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "priority_lane_count",
        metrics.priority_lane_count,
        MIN_PRIORITY_LANE_COUNT,
        "lanes",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cache_policy_count",
        metrics.cache_policy_count,
        MIN_CACHE_POLICY_COUNT,
        "policies",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "planned_bytes",
        metrics.planned_bytes,
        ">=",
        768 * 1024,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "bytes_requested",
        metrics.bytes_requested,
        ">=",
        metrics.planned_bytes,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "bytes_read",
        metrics.bytes_read,
        ">=",
        metrics.bytes_requested,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_trace_copy_count",
        metrics.max_trace_copy_count,
        "<=",
        MAX_TRACE_COPY_COUNT,
        "copies",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cancellation_count",
        metrics.cancellation_count,
        ">=",
        2,
        "cancellations",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_p95_stall_ms",
        metrics.max_p95_stall_ms,
        "<=",
        5,
        "ms",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_p99_stall_ms",
        metrics.max_p99_stall_ms,
        "<=",
        9,
        "ms",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "min_read_amplification_bps",
        metrics.min_read_amplification_bps,
        ">=",
        10_000,
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "transport_safety_bps",
        metrics.transport_safety_bps,
        ">=",
        MIN_TRANSPORT_SAFETY_BPS,
        "bps",
    );
    add_baseline_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hidden_transport_baseline_bps",
        metrics.hidden_transport_baseline_bps,
        metrics.transport_safety_bps,
    );
    add_baseline_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "policy_mutation_baseline_bps",
        metrics.policy_mutation_baseline_bps,
        metrics.transport_safety_bps,
    );
    add_baseline_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "mmap_fault_baseline_bps",
        metrics.mmap_fault_baseline_bps,
        metrics.transport_safety_bps,
    );
    add_baseline_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_answer_packet_baseline_bps",
        metrics.no_answer_packet_baseline_bps,
        metrics.transport_safety_bps,
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_transport_metadata_bytes",
        metrics.max_transport_metadata_bytes,
        "<=",
        MAX_TRANSPORT_METADATA_BYTES,
        "bytes",
    );
    measurements.insert(
        "coldstream_no_hidden_authority_address".to_string(),
        Measurement {
            value: serde_json::Value::String(address.clone()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "coldstream_no_hidden_authority_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::Value::String(
                "uas:coldstream-no-hidden-authority:sha256:".to_string(),
            ),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "coldstream_no_hidden_authority_address".to_string(),
        address.starts_with("uas:coldstream-no-hidden-authority:sha256:"),
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
            "kind": "metadata_only_coldstream_authority_witness",
            "detail": "Architecture cursor advances only. ColdStream remains a planned transport contract and cannot wake bytes, mutate route policy, override admission, suppress AnswerPacket proof, or claim mmap-vs-transport runtime performance."
        })],
        notes: "Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof. F-ColdStream-NoHiddenAuthority is metadata-only: transport manifests and traces are explicit, leased, admitted, rollback-bound, RunEventLog-visible, AnswerPacket-visible, and proposal-only, with zero runtime/model bytes.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();
    Ok(artifact)
}

fn validate_fixtures(fixtures: &[ColdStreamFixture]) -> Result<(), ColdStreamWitnessError> {
    if fixtures.is_empty() {
        return Err(ColdStreamWitnessError::EmptyFixture);
    }
    let mut fixture_ids = HashSet::new();
    let mut manifests = HashSet::new();
    let mut trace_manifest_refs = HashSet::new();
    for fixture in fixtures {
        if fixture.fixture_id.is_empty()
            || fixture.fixture_scope != "metadata_only_transport_authority"
        {
            return Err(ColdStreamWitnessError::EmptyFixture);
        }
        if !fixture_ids.insert(fixture.fixture_id.clone()) {
            return Err(ColdStreamWitnessError::DuplicateFixture(
                fixture.fixture_id.clone(),
            ));
        }
        if !manifests.insert(fixture.manifest.manifest_id.clone()) {
            return Err(ColdStreamWitnessError::DuplicateManifest(
                fixture.manifest.manifest_id.clone(),
            ));
        }
        trace_manifest_refs.insert(fixture.trace.manifest_ref.to_string());
        if fixture.trace.manifest_ref != fixture.manifest.manifest_address {
            return Err(ColdStreamWitnessError::TraceWithoutManifest(
                fixture.trace.trace_id.clone(),
            ));
        }
        if fixture.transport_safety_bps < MIN_TRANSPORT_SAFETY_BPS {
            return Err(ColdStreamWitnessError::SafetyBelowFloor);
        }
        if fixture.hidden_transport_baseline_bps >= fixture.transport_safety_bps {
            return Err(ColdStreamWitnessError::BaselineUnbeaten("hidden_transport"));
        }
        if fixture.policy_mutation_baseline_bps >= fixture.transport_safety_bps {
            return Err(ColdStreamWitnessError::BaselineUnbeaten("policy_mutation"));
        }
        if fixture.mmap_fault_baseline_bps >= fixture.transport_safety_bps {
            return Err(ColdStreamWitnessError::BaselineUnbeaten("mmap_fault"));
        }
        if fixture.no_answer_packet_baseline_bps >= fixture.transport_safety_bps {
            return Err(ColdStreamWitnessError::BaselineUnbeaten("no_answer_packet"));
        }
        if fixture.metadata_bytes > MAX_TRANSPORT_METADATA_BYTES {
            return Err(ColdStreamWitnessError::MetadataBudgetExceeded);
        }
    }
    for fixture in fixtures {
        if !trace_manifest_refs.contains(&fixture.manifest.manifest_address.to_string()) {
            return Err(ColdStreamWitnessError::MissingTrace(
                fixture.manifest.manifest_id.clone(),
            ));
        }
    }
    Ok(())
}

fn invalid_fixture_axes() -> Result<Vec<(&'static str, bool)>, ColdStreamWitnessError> {
    let mut cases = Vec::new();
    cases.push((
        "empty_fixture_rejected",
        ColdStreamRegistry::new(vec![]).is_err(),
    ));
    cases.push((
        "duplicate_fixture_rejected",
        rejects_registry(|fixtures| fixtures.push(fixtures[0].clone()))?,
    ));
    cases.push((
        "duplicate_manifest_rejected",
        rejects_registry(|fixtures| {
            fixtures[1].manifest = fixtures[0].manifest.clone();
        })?,
    ));
    cases.push((
        "missing_semantic_working_set_plan_rejected",
        manifest_with_ref("", RefKind::SemanticPlan).is_err(),
    ));
    cases.push((
        "missing_residency_page_table_rejected",
        manifest_with_ref("bad-page-table", RefKind::PageTable).is_err(),
    ));
    cases.push((
        "missing_admission_rejected",
        manifest_with_ref("bad-admission", RefKind::Admission).is_err(),
    ));
    cases.push((
        "missing_scope_rex_rejected",
        manifest_with_ref("bad-scope", RefKind::ScopeRex).is_err(),
    ));
    cases.push((
        "missing_sovereign_gate_rejected",
        manifest_with_ref("bad-sovereign", RefKind::SovereignGate).is_err(),
    ));
    cases.push((
        "missing_rollback_rejected",
        manifest_with_ref("bad-rollback", RefKind::Rollback).is_err(),
    ));
    cases.push((
        "missing_run_event_log_rejected",
        manifest_with_ref("bad-log", RefKind::RunEventLog).is_err(),
    ));
    cases.push((
        "missing_answer_packet_rejected",
        manifest_with_ref("bad-answer", RefKind::AnswerPacket).is_err(),
    ));
    cases.push((
        "missing_fallback_rejected",
        manifest_with_ref("bad-fallback", RefKind::Fallback).is_err(),
    ));
    cases.push((
        "missing_cancellation_group_rejected",
        manifest_with_ref("bad-cancel", RefKind::CancellationGroup).is_err(),
    ));
    cases.push((
        "empty_page_runs_rejected",
        manifest_with_runs(vec![]).is_err(),
    ));
    cases.push((
        "duplicate_page_run_rejected",
        manifest_with_runs(duplicate_run_id_runs()?).is_err(),
    ));
    cases.push((
        "duplicate_byte_range_rejected",
        manifest_with_runs(duplicate_byte_range_runs()?).is_err(),
    ));
    cases.push(("missing_lease_rejected", bad_run(BadRun::Lease).is_err()));
    cases.push((
        "invalid_byte_range_rejected",
        bad_run(BadRun::ByteRange).is_err(),
    ));
    cases.push((
        "invalid_checksum_rejected",
        bad_run(BadRun::Checksum).is_err(),
    ));
    cases.push((
        "incompatible_fence_rejected",
        bad_run(BadRun::Fence).is_err(),
    ));
    cases.push((
        "live_transport_authority_rejected",
        manifest_with_flags(
            ColdStreamAuthority::LiveTransportAuthority,
            false,
            false,
            0,
            0,
        )
        .is_err(),
    ));
    cases.push((
        "product_status_rejected",
        manifest_with_product(ProductBuild::Mas, ProStatus::Live).is_err(),
    ));
    cases.push((
        "byte_wake_without_lease_rejected",
        manifest_with_flags(ColdStreamAuthority::ProposalOnly, true, false, 0, 0).is_err(),
    ));
    cases.push((
        "route_policy_mutation_rejected",
        manifest_with_flags(ColdStreamAuthority::ProposalOnly, false, true, 0, 0).is_err(),
    ));
    cases.push((
        "scope_rex_override_rejected",
        manifest_with_override(OverrideKind::ScopeRex).is_err(),
    ));
    cases.push((
        "sovereign_gate_override_rejected",
        manifest_with_override(OverrideKind::SovereignGate).is_err(),
    ));
    cases.push((
        "answer_packet_suppression_rejected",
        manifest_with_override(OverrideKind::AnswerPacket).is_err(),
    ));
    cases.push((
        "hidden_chain_rejected",
        manifest_with_override(OverrideKind::HiddenChain).is_err(),
    ));
    cases.push((
        "hidden_cloud_rejected",
        manifest_with_override(OverrideKind::HiddenCloud).is_err(),
    ));
    cases.push((
        "runtime_bytes_rejected",
        manifest_with_flags(ColdStreamAuthority::ProposalOnly, false, false, 1, 0).is_err(),
    ));
    cases.push((
        "model_bytes_rejected",
        manifest_with_flags(ColdStreamAuthority::ProposalOnly, false, false, 0, 1).is_err(),
    ));
    cases.push((
        "trace_underdecode_rejected",
        trace_with(TraceMutation::UnderDecode).is_err(),
    ));
    cases.push((
        "trace_p99_order_rejected",
        trace_with(TraceMutation::P99BelowP95).is_err(),
    ));
    cases.push((
        "trace_copy_budget_rejected",
        trace_with(TraceMutation::CopyBudget).is_err(),
    ));
    cases.push((
        "stale_slab_execution_rejected",
        trace_with(TraceMutation::StaleSlab).is_err(),
    ));
    cases.push((
        "trace_missing_run_event_log_rejected",
        trace_with(TraceMutation::RunEventLog).is_err(),
    ));
    cases.push((
        "trace_missing_answer_packet_rejected",
        trace_with(TraceMutation::AnswerPacket).is_err(),
    ));
    cases.push((
        "trace_missing_fallback_rejected",
        trace_with(TraceMutation::Fallback).is_err(),
    ));
    cases.push((
        "hidden_transport_baseline_unbeaten_rejected",
        rejects_registry(|fixtures| {
            fixtures[0].hidden_transport_baseline_bps = fixtures[0].transport_safety_bps;
        })?,
    ));
    cases.push((
        "policy_mutation_baseline_unbeaten_rejected",
        rejects_registry(|fixtures| {
            fixtures[0].policy_mutation_baseline_bps = fixtures[0].transport_safety_bps;
        })?,
    ));
    cases.push((
        "mmap_fault_baseline_unbeaten_rejected",
        rejects_registry(|fixtures| {
            fixtures[0].mmap_fault_baseline_bps = fixtures[0].transport_safety_bps;
        })?,
    ));
    cases.push((
        "no_answer_packet_baseline_unbeaten_rejected",
        rejects_registry(|fixtures| {
            fixtures[0].no_answer_packet_baseline_bps = fixtures[0].transport_safety_bps;
        })?,
    ));
    cases.push((
        "metadata_budget_rejected",
        rejects_registry(|fixtures| {
            fixtures[0].metadata_bytes = MAX_TRANSPORT_METADATA_BYTES + 1;
        })?,
    ));
    Ok(cases)
}

fn rejects_registry(
    mutate: impl FnOnce(&mut Vec<ColdStreamFixture>),
) -> Result<bool, ColdStreamWitnessError> {
    let mut fixtures = fixture_coldstream_fixtures()?;
    mutate(&mut fixtures);
    Ok(ColdStreamRegistry::new(fixtures).is_err())
}

fn fixture_coldstream_fixtures() -> Result<Vec<ColdStreamFixture>, ColdStreamWitnessError> {
    let local = manifest(
        "coldstream-manifest-local-research",
        "route:coldstream:local-research",
        "local-research",
        0,
    )?;
    let local_trace = trace(&local, "trace:coldstream:local-research", 1, 3, 5)?;
    let proof = manifest(
        "coldstream-manifest-proof-repair",
        "route:coldstream:proof-repair",
        "proof-repair",
        384 * 1024,
    )?;
    let proof_trace = trace(&proof, "trace:coldstream:proof-repair", 2, 4, 8)?;
    Ok(vec![
        ColdStreamFixture {
            fixture_id: "coldstream-authority-local-research".to_string(),
            fixture_scope: "metadata_only_transport_authority".to_string(),
            transport_safety_bps: 9_420,
            hidden_transport_baseline_bps: 7_300,
            policy_mutation_baseline_bps: 7_650,
            mmap_fault_baseline_bps: 8_250,
            no_answer_packet_baseline_bps: 7_050,
            metadata_bytes: 196 * 1024,
            manifest: local,
            trace: local_trace,
        },
        ColdStreamFixture {
            fixture_id: "coldstream-authority-proof-repair".to_string(),
            fixture_scope: "metadata_only_transport_authority".to_string(),
            transport_safety_bps: 9_310,
            hidden_transport_baseline_bps: 7_450,
            policy_mutation_baseline_bps: 7_700,
            mmap_fault_baseline_bps: 8_400,
            no_answer_packet_baseline_bps: 7_250,
            metadata_bytes: 224 * 1024,
            manifest: proof,
            trace: proof_trace,
        },
    ])
}

fn manifest(
    manifest_id: &str,
    route_id: &str,
    suffix: &str,
    offset_base: u64,
) -> Result<ColdStreamTransportManifest, ColdStreamError> {
    ColdStreamTransportManifest::new(
        manifest_id,
        route_id,
        &format!("uas:semantic_working_set_plan:{suffix}@{CREATED_AT_MS}"),
        &format!("residency_page_table:{suffix}:v1"),
        &format!("admission:scope-rex-sovereign:{suffix}:v1"),
        &format!("scope_rex:{suffix}:v1"),
        &format!("sovereign_gate:{suffix}:v1"),
        &format!("rollback:coldstream:{suffix}:v1"),
        &format!("run_event_log:coldstream:{suffix}:v1"),
        &format!("answer_packet:coldstream:{suffix}:v1"),
        &format!("fallback:cold_panic_visible:{suffix}:v1"),
        &format!("cancel_group:coldstream:{suffix}:v1"),
        ColdStreamAuthority::ProposalOnly,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        runs(suffix, offset_base)?,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        0,
        0,
        CREATED_AT_MS,
    )
}

fn runs(suffix: &str, offset_base: u64) -> Result<Vec<ColdStreamPageRun>, ColdStreamError> {
    Ok(vec![
        page_run(
            suffix,
            "evidence",
            offset_base,
            128 * 1024,
            ColdStreamDestination::CpuSlab,
            ColdStreamPriority::Urgent,
            ColdStreamCachePolicy::NoCache,
            "raw",
        )?,
        page_run(
            suffix,
            "kv",
            offset_base + 128 * 1024,
            128 * 1024,
            ColdStreamDestination::MlxReadySlab,
            ColdStreamPriority::Prefetch,
            ColdStreamCachePolicy::NoCache,
            "nf4",
        )?,
        page_run(
            suffix,
            "verifier",
            offset_base + 256 * 1024,
            128 * 1024,
            ColdStreamDestination::MetalBuffer,
            ColdStreamPriority::Background,
            ColdStreamCachePolicy::HotReuse,
            "raw",
        )?,
    ])
}

fn page_run(
    suffix: &str,
    unit: &str,
    offset: u64,
    length: u64,
    destination: ColdStreamDestination,
    priority: ColdStreamPriority,
    cache_policy: ColdStreamCachePolicy,
    codec: &str,
) -> Result<ColdStreamPageRun, ColdStreamError> {
    ColdStreamPageRun::new(
        format!("run:{suffix}:{unit}"),
        format!("file:appcoldstore:{suffix}:{unit}"),
        offset,
        length,
        vec![format!("semantic:{suffix}:{unit}")],
        vec![uas_address(suffix, unit)],
        codec,
        format!("sha256:{suffix}-{unit}-checksum"),
        destination,
        priority,
        cache_policy,
        format!("lease:coldstream:{suffix}:{unit}"),
        "compat:coldstream:v1",
    )
}

fn trace(
    manifest: &ColdStreamTransportManifest,
    trace_id: &str,
    cancellations: u32,
    p95_stall_ms: u32,
    p99_stall_ms: u32,
) -> Result<ColdStreamTransportTrace, ColdStreamError> {
    ColdStreamTransportTrace::new(
        manifest,
        trace_id,
        manifest.planned_bytes(),
        manifest.planned_bytes() + 4096,
        manifest.planned_bytes(),
        2,
        cancellations,
        p95_stall_ms,
        p99_stall_ms,
        10_105,
        false,
        true,
        manifest.run_event_log_ref.clone(),
        manifest.answer_packet_ref.clone(),
    )
}

fn uas_address(suffix: &str, unit: &str) -> UasAddress {
    UasAddress::new(
        UasKind::Other("coldstream_fixture_unit".to_string()),
        format!("{suffix}:{unit}").as_bytes(),
        CREATED_AT_MS,
    )
}

#[derive(Clone, Copy)]
// UAS: uas:coldstream-no-hidden-authority:ref-kind
// Plane: Verification
// Residency: metadata-only invalid-reference fixture selector.
enum RefKind {
    SemanticPlan,
    PageTable,
    Admission,
    ScopeRex,
    SovereignGate,
    Rollback,
    RunEventLog,
    AnswerPacket,
    Fallback,
    CancellationGroup,
}

fn manifest_with_ref(
    value: &str,
    ref_kind: RefKind,
) -> Result<ColdStreamTransportManifest, ColdStreamError> {
    let suffix = "bad-ref";
    ColdStreamTransportManifest::new(
        "coldstream-manifest-bad-ref",
        "route:coldstream:bad-ref",
        if matches!(ref_kind, RefKind::SemanticPlan) {
            value
        } else {
            "uas:semantic_working_set_plan:bad-ref@1779552000000"
        },
        if matches!(ref_kind, RefKind::PageTable) {
            value
        } else {
            "residency_page_table:bad-ref:v1"
        },
        if matches!(ref_kind, RefKind::Admission) {
            value
        } else {
            "admission:scope-rex-sovereign:bad-ref:v1"
        },
        if matches!(ref_kind, RefKind::ScopeRex) {
            value
        } else {
            "scope_rex:bad-ref:v1"
        },
        if matches!(ref_kind, RefKind::SovereignGate) {
            value
        } else {
            "sovereign_gate:bad-ref:v1"
        },
        if matches!(ref_kind, RefKind::Rollback) {
            value
        } else {
            "rollback:coldstream:bad-ref:v1"
        },
        if matches!(ref_kind, RefKind::RunEventLog) {
            value
        } else {
            "run_event_log:coldstream:bad-ref:v1"
        },
        if matches!(ref_kind, RefKind::AnswerPacket) {
            value
        } else {
            "answer_packet:coldstream:bad-ref:v1"
        },
        if matches!(ref_kind, RefKind::Fallback) {
            value
        } else {
            "fallback:cold_panic_visible:bad-ref:v1"
        },
        if matches!(ref_kind, RefKind::CancellationGroup) {
            value
        } else {
            "cancel_group:coldstream:bad-ref:v1"
        },
        ColdStreamAuthority::ProposalOnly,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        runs(suffix, 0)?,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        0,
        0,
        CREATED_AT_MS,
    )
}

fn manifest_with_runs(
    runs: Vec<ColdStreamPageRun>,
) -> Result<ColdStreamTransportManifest, ColdStreamError> {
    ColdStreamTransportManifest::new(
        "coldstream-manifest-runs-test",
        "route:coldstream:runs-test",
        "uas:semantic_working_set_plan:runs-test@1779552000000",
        "residency_page_table:runs-test:v1",
        "admission:scope-rex-sovereign:runs-test:v1",
        "scope_rex:runs-test:v1",
        "sovereign_gate:runs-test:v1",
        "rollback:coldstream:runs-test:v1",
        "run_event_log:coldstream:runs-test:v1",
        "answer_packet:coldstream:runs-test:v1",
        "fallback:cold_panic_visible:runs-test:v1",
        "cancel_group:coldstream:runs-test:v1",
        ColdStreamAuthority::ProposalOnly,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        runs,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        0,
        0,
        CREATED_AT_MS,
    )
}

fn duplicate_run_id_runs() -> Result<Vec<ColdStreamPageRun>, ColdStreamError> {
    let mut runs = runs("duplicate-run", 0)?;
    runs[1] = runs[0].clone();
    Ok(runs)
}

fn duplicate_byte_range_runs() -> Result<Vec<ColdStreamPageRun>, ColdStreamError> {
    Ok(vec![
        page_run(
            "duplicate-range",
            "evidence",
            0,
            128 * 1024,
            ColdStreamDestination::CpuSlab,
            ColdStreamPriority::Urgent,
            ColdStreamCachePolicy::NoCache,
            "raw",
        )?,
        ColdStreamPageRun::new(
            "run:duplicate-range:kv",
            "file:appcoldstore:duplicate-range:evidence",
            0,
            128 * 1024,
            vec!["semantic:duplicate-range:kv".to_string()],
            vec![uas_address("duplicate-range", "kv")],
            "nf4",
            "sha256:duplicate-range-kv-checksum",
            ColdStreamDestination::MlxReadySlab,
            ColdStreamPriority::Prefetch,
            ColdStreamCachePolicy::NoCache,
            "lease:coldstream:duplicate-range:kv",
            "compat:coldstream:v1",
        )?,
    ])
}

// UAS: uas:coldstream-no-hidden-authority:bad-run-kind
// Plane: Verification
// Residency: metadata-only invalid-page-run fixture selector.
enum BadRun {
    Lease,
    ByteRange,
    Checksum,
    Fence,
}

fn bad_run(kind: BadRun) -> Result<ColdStreamPageRun, ColdStreamError> {
    ColdStreamPageRun::new(
        "run:bad",
        "file:bad",
        0,
        if matches!(kind, BadRun::ByteRange) {
            0
        } else {
            128 * 1024
        },
        vec!["semantic:bad".to_string()],
        vec![uas_address("bad", "run")],
        "raw",
        if matches!(kind, BadRun::Checksum) {
            "bad-checksum"
        } else {
            "sha256:bad-run-checksum"
        },
        ColdStreamDestination::CpuSlab,
        ColdStreamPriority::Urgent,
        ColdStreamCachePolicy::NoCache,
        if matches!(kind, BadRun::Lease) {
            "bad-lease"
        } else {
            "lease:coldstream:bad"
        },
        if matches!(kind, BadRun::Fence) {
            "bad-fence"
        } else {
            "compat:coldstream:v1"
        },
    )
}

fn manifest_with_flags(
    authority: ColdStreamAuthority,
    byte_wake_without_lease: bool,
    route_policy_mutated: bool,
    runtime_bytes_loaded: u64,
    model_bytes_loaded: u64,
) -> Result<ColdStreamTransportManifest, ColdStreamError> {
    ColdStreamTransportManifest::new(
        "coldstream-manifest-flags",
        "route:coldstream:flags",
        "uas:semantic_working_set_plan:flags@1779552000000",
        "residency_page_table:flags:v1",
        "admission:scope-rex-sovereign:flags:v1",
        "scope_rex:flags:v1",
        "sovereign_gate:flags:v1",
        "rollback:coldstream:flags:v1",
        "run_event_log:coldstream:flags:v1",
        "answer_packet:coldstream:flags:v1",
        "fallback:cold_panic_visible:flags:v1",
        "cancel_group:coldstream:flags:v1",
        authority,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        runs("flags", 0)?,
        byte_wake_without_lease,
        route_policy_mutated,
        false,
        false,
        false,
        false,
        false,
        runtime_bytes_loaded,
        model_bytes_loaded,
        CREATED_AT_MS,
    )
}

fn manifest_with_product(
    product_build: ProductBuild,
    pro_status: ProStatus,
) -> Result<ColdStreamTransportManifest, ColdStreamError> {
    ColdStreamTransportManifest::new(
        "coldstream-manifest-product",
        "route:coldstream:product",
        "uas:semantic_working_set_plan:product@1779552000000",
        "residency_page_table:product:v1",
        "admission:scope-rex-sovereign:product:v1",
        "scope_rex:product:v1",
        "sovereign_gate:product:v1",
        "rollback:coldstream:product:v1",
        "run_event_log:coldstream:product:v1",
        "answer_packet:coldstream:product:v1",
        "fallback:cold_panic_visible:product:v1",
        "cancel_group:coldstream:product:v1",
        ColdStreamAuthority::ProposalOnly,
        product_build,
        pro_status,
        runs("product", 0)?,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        0,
        0,
        CREATED_AT_MS,
    )
}

// UAS: uas:coldstream-no-hidden-authority:override-kind
// Plane: Verification
// Residency: metadata-only hidden-authority fixture selector.
enum OverrideKind {
    ScopeRex,
    SovereignGate,
    AnswerPacket,
    HiddenChain,
    HiddenCloud,
}

fn manifest_with_override(
    kind: OverrideKind,
) -> Result<ColdStreamTransportManifest, ColdStreamError> {
    ColdStreamTransportManifest::new(
        "coldstream-manifest-override",
        "route:coldstream:override",
        "uas:semantic_working_set_plan:override@1779552000000",
        "residency_page_table:override:v1",
        "admission:scope-rex-sovereign:override:v1",
        "scope_rex:override:v1",
        "sovereign_gate:override:v1",
        "rollback:coldstream:override:v1",
        "run_event_log:coldstream:override:v1",
        "answer_packet:coldstream:override:v1",
        "fallback:cold_panic_visible:override:v1",
        "cancel_group:coldstream:override:v1",
        ColdStreamAuthority::ProposalOnly,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        runs("override", 0)?,
        false,
        false,
        matches!(kind, OverrideKind::ScopeRex),
        matches!(kind, OverrideKind::SovereignGate),
        matches!(kind, OverrideKind::AnswerPacket),
        matches!(kind, OverrideKind::HiddenChain),
        matches!(kind, OverrideKind::HiddenCloud),
        0,
        0,
        CREATED_AT_MS,
    )
}

// UAS: uas:coldstream-no-hidden-authority:trace-mutation
// Plane: Verification
// Residency: metadata-only invalid-trace fixture selector.
enum TraceMutation {
    UnderDecode,
    P99BelowP95,
    CopyBudget,
    StaleSlab,
    RunEventLog,
    AnswerPacket,
    Fallback,
}

fn trace_with(kind: TraceMutation) -> Result<ColdStreamTransportTrace, ColdStreamError> {
    let manifest = manifest(
        "coldstream-manifest-trace",
        "route:coldstream:trace",
        "trace",
        0,
    )?;
    ColdStreamTransportTrace::new(
        &manifest,
        "trace:coldstream:mutation",
        manifest.planned_bytes(),
        manifest.planned_bytes(),
        if matches!(kind, TraceMutation::UnderDecode) {
            manifest.planned_bytes() - 1
        } else {
            manifest.planned_bytes()
        },
        if matches!(kind, TraceMutation::CopyBudget) {
            3
        } else {
            1
        },
        1,
        if matches!(kind, TraceMutation::P99BelowP95) {
            9
        } else {
            3
        },
        5,
        10_000,
        matches!(kind, TraceMutation::StaleSlab),
        !matches!(kind, TraceMutation::Fallback),
        if matches!(kind, TraceMutation::RunEventLog) {
            "run_event_log:other"
        } else {
            &manifest.run_event_log_ref
        },
        if matches!(kind, TraceMutation::AnswerPacket) {
            "answer_packet:other"
        } else {
            &manifest.answer_packet_ref
        },
    )
}

fn destination_tag(destination: &ColdStreamDestination) -> &'static str {
    match destination {
        ColdStreamDestination::CpuSlab => "cpu_slab",
        ColdStreamDestination::MetalBuffer => "metal_buffer",
        ColdStreamDestination::MlxReadySlab => "mlx_ready_slab",
    }
}

fn priority_tag(priority: &ColdStreamPriority) -> &'static str {
    match priority {
        ColdStreamPriority::Urgent => "urgent",
        ColdStreamPriority::Prefetch => "prefetch",
        ColdStreamPriority::Background => "background",
    }
}

fn cache_policy_tag(cache_policy: &ColdStreamCachePolicy) -> &'static str {
    match cache_policy {
        ColdStreamCachePolicy::Default => "default",
        ColdStreamCachePolicy::NoCache => "no_cache",
        ColdStreamCachePolicy::HotReuse => "hot_reuse",
    }
}

fn upstream_artifact_pass(path: &str) -> bool {
    let Some(raw) = read_repo_relative(path) else {
        return false;
    };
    let Ok(json) = serde_json::from_str::<serde_json::Value>(&raw) else {
        return false;
    };
    json.get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
}

fn read_repo_relative(path: &str) -> Option<String> {
    std::fs::read_to_string(path).ok().or_else(|| {
        std::fs::read_to_string(Path::new(env!("CARGO_MANIFEST_DIR")).join("..").join(path)).ok()
    })
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
        ">=" => actual >= expected,
        "<=" => actual <= expected,
        "<" => actual < expected,
        _ => false,
    };
    pass_per_axis.insert(name.to_string(), passed);
}

fn add_baseline_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    baseline: u64,
    transport_safety: u64,
) {
    add_u64_axis(
        measurements,
        thresholds,
        pass_per_axis,
        name,
        baseline,
        "<",
        transport_safety,
        "bps",
    );
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn valid_artifact_passes() {
        let artifact = build_artifact().expect("artifact");
        assert!(artifact.overall_pass);
        assert_eq!(artifact.falsifier_id, FALSIFIER_ID);
        assert_eq!(
            artifact.measurements["no_runtime_bytes_loaded"].value,
            serde_json::Value::Bool(true)
        );
    }

    #[test]
    fn artifact_contains_all_required_axes() {
        let artifact = build_artifact().expect("artifact");
        for axis in COLDSTREAM_NO_HIDDEN_AUTHORITY_AXES {
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
    }

    #[test]
    fn invalid_axes_are_true() {
        let artifact = build_artifact().expect("artifact");
        for axis in [
            "empty_page_runs_rejected",
            "live_transport_authority_rejected",
            "route_policy_mutation_rejected",
            "trace_missing_answer_packet_rejected",
            "stale_slab_execution_rejected",
            "metadata_budget_rejected",
        ] {
            assert_eq!(artifact.pass_per_axis[axis], true, "{axis}");
        }
    }

    #[test]
    fn address_is_deterministic_under_fixture_order() {
        let left = ColdStreamRegistry::new(fixture_coldstream_fixtures().expect("fixtures"))
            .expect("registry")
            .address();
        let mut reversed = fixture_coldstream_fixtures().expect("fixtures");
        reversed.reverse();
        let right = ColdStreamRegistry::new(reversed)
            .expect("registry")
            .address();
        assert_eq!(left, right);
        assert!(left.starts_with("uas:coldstream-no-hidden-authority:sha256:"));
        assert!(!left.contains("sha256:sha256:"));
    }
}
