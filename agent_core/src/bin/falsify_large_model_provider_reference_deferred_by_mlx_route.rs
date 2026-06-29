//! `falsify_large_model_provider_reference_deferred_by_mlx_route`.
//!
//! Metadata-only witness for the default large-model deferral cursor. It proves
//! provider/fp16/70B and heavy 128K routes stay deferred unless explicitly
//! enabled, while the practical MLX local route and cold-assembly architecture
//! remain preserved.

use std::collections::{BTreeMap, BTreeSet, HashSet};
use std::path::{Path, PathBuf};

#[cfg(test)]
use agent_core::falsifier_artifacts::axes::LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_BY_MLX_ROUTE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    large_model_provider_reference_deferred_or_advanced_cursor, LargeModelActiveLane,
    LargeModelDeferralError, LargeModelDeferredLane, LargeModelProviderDeferralCard, ProStatus,
    ProductBuild, LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_CURSOR,
    PROVIDER_ROUTE_COPY_SOURCE_GUARD_CURSOR,
};

const FALSIFIER_ID: &str = "F-LargeModelProviderReference-DeferredByMlxRoute";
const FIXTURE_ID: &str = "large_model_provider_reference_deferred_by_mlx_route_v1";
const COMMAND: &str = "Tools/falsifiers/f_large_model_provider_reference_deferred_by_mlx_route.sh";
const RESULT: &str =
    "artifacts/falsifiers/large_model_provider_reference_deferred_by_mlx_route/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const PROVIDER_READINESS_PATH: &str =
    "artifacts/falsifiers/provider_reference_prompt_level_readiness/result.json";
const LOCAL_70B_PATH: &str = "artifacts/falsifiers/70b_local_cocktail_lite/result.json";
const CREATED_AT_MS: u64 = 1_779_552_000_000;
const MIN_FIXTURE_COUNT: u64 = 2;
const MIN_DEFERRED_LANE_COUNT: u64 = 4;
const MIN_DEFERRAL_SAFETY_BPS: u64 = 9_600;
const MAX_METADATA_BYTES: u64 = 384 * 1024;

#[derive(Clone)]
// UAS: uas:large-model-provider-deferral:fixture
// Plane: Controller + Verification
// Residency: metadata-only fixture; no provider/runtime/model bytes move.
struct LargeModelDeferralFixture {
    fixture_id: String,
    fixture_scope: String,
    card: LargeModelProviderDeferralCard,
    deferral_safety_bps: u64,
    forced_provider_baseline_bps: u64,
    hidden_cloud_baseline_bps: u64,
    dense_resident_baseline_bps: u64,
    rerun_shard_baseline_bps: u64,
    metadata_bytes: u64,
}

#[derive(Default)]
// UAS: uas:large-model-provider-deferral:metrics
// Plane: Verification
// Residency: metadata-only aggregation.
struct DeferralMetrics {
    fixture_count: u64,
    active_lane_count: u64,
    deferred_lane_count: u64,
    deferral_safety_bps: u64,
    forced_provider_baseline_bps: u64,
    hidden_cloud_baseline_bps: u64,
    dense_resident_baseline_bps: u64,
    rerun_shard_baseline_bps: u64,
    provider_call_count: u64,
    runtime_bytes_loaded: u64,
    model_bytes_loaded: u64,
    max_metadata_bytes: u64,
}

// UAS: uas:large-model-provider-deferral:registry
// Plane: Controller + Verification
// Residency: offline/shadow-only deferral registry.
struct LargeModelDeferralRegistry {
    fixtures: Vec<LargeModelDeferralFixture>,
}

impl LargeModelDeferralRegistry {
    fn new(fixtures: Vec<LargeModelDeferralFixture>) -> Result<Self, DeferralWitnessError> {
        validate_fixtures(&fixtures)?;
        Ok(Self { fixtures })
    }

    fn metrics(&self) -> DeferralMetrics {
        let active_lanes = self
            .fixtures
            .iter()
            .map(|fixture| active_lane_tag(&fixture.card.active_lane))
            .collect::<BTreeSet<_>>();
        let deferred_lanes = self
            .fixtures
            .iter()
            .flat_map(|fixture| fixture.card.deferred_lanes.iter().map(deferred_lane_tag))
            .collect::<BTreeSet<_>>();
        DeferralMetrics {
            fixture_count: self.fixtures.len() as u64,
            active_lane_count: active_lanes.len() as u64,
            deferred_lane_count: deferred_lanes.len() as u64,
            deferral_safety_bps: self
                .fixtures
                .iter()
                .map(|fixture| fixture.deferral_safety_bps)
                .min()
                .unwrap_or(0),
            forced_provider_baseline_bps: self
                .fixtures
                .iter()
                .map(|fixture| fixture.forced_provider_baseline_bps)
                .max()
                .unwrap_or(0),
            hidden_cloud_baseline_bps: self
                .fixtures
                .iter()
                .map(|fixture| fixture.hidden_cloud_baseline_bps)
                .max()
                .unwrap_or(0),
            dense_resident_baseline_bps: self
                .fixtures
                .iter()
                .map(|fixture| fixture.dense_resident_baseline_bps)
                .max()
                .unwrap_or(0),
            rerun_shard_baseline_bps: self
                .fixtures
                .iter()
                .map(|fixture| fixture.rerun_shard_baseline_bps)
                .max()
                .unwrap_or(0),
            provider_call_count: self
                .fixtures
                .iter()
                .map(|fixture| u64::from(fixture.card.provider_calls_attempted))
                .sum(),
            runtime_bytes_loaded: self
                .fixtures
                .iter()
                .map(|fixture| fixture.card.runtime_bytes_loaded)
                .sum(),
            model_bytes_loaded: self
                .fixtures
                .iter()
                .map(|fixture| fixture.card.model_bytes_loaded)
                .sum(),
            max_metadata_bytes: self
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
                    fixture.card.card_address,
                    fixture.card.current_cursor,
                    active_lane_tag(&fixture.card.active_lane),
                    fixture.card.provider_reference_primary_blocker,
                    fixture.deferral_safety_bps
                )
            })
            .collect::<Vec<_>>();
        parts.sort();
        format!(
            "uas:large-model-provider-reference-deferral:{}",
            sha256_hex(parts.join("\n").as_bytes())
        )
    }
}

#[derive(Debug)]
// UAS: uas:large-model-provider-deferral:witness-error
// Plane: Verification
// Residency: metadata-only witness rejection taxonomy.
enum DeferralWitnessError {
    Primitive(LargeModelDeferralError),
    Io(String),
    EmptyFixture,
    DuplicateFixture(String),
    DuplicateCard(String),
    SafetyBelowFloor,
    BaselineUnbeaten(&'static str),
    MetadataBudgetExceeded,
}

impl std::fmt::Display for DeferralWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) => write!(f, "{error}"),
            Self::EmptyFixture => write!(f, "missing deferral fixture"),
            Self::DuplicateFixture(id) => write!(f, "duplicate fixture `{id}`"),
            Self::DuplicateCard(address) => write!(f, "duplicate deferral card `{address}`"),
            Self::SafetyBelowFloor => write!(f, "deferral safety below floor"),
            Self::BaselineUnbeaten(name) => write!(f, "baseline `{name}` was unbeaten"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for DeferralWitnessError {}

impl From<LargeModelDeferralError> for DeferralWitnessError {
    fn from(value: LargeModelDeferralError) -> Self {
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
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, DeferralWitnessError> {
    let evidence = EvidenceSnapshot::read()?;
    let registry = LargeModelDeferralRegistry::new(fixture_deferral_fixtures()?)?;
    let metrics = registry.metrics();
    let address = registry.address();
    let mut reversed = fixture_deferral_fixtures()?;
    reversed.reverse();
    let deterministic = LargeModelDeferralRegistry::new(reversed)?.address() == address;
    let invalid_axes = invalid_fixture_axes()?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let bool_axes = [
        ("guard_artifact_pass", evidence.guard_overall_pass),
        (
            "guard_cursor_deferred_or_advanced_by_mlx_route",
            large_model_provider_reference_deferred_or_advanced_cursor(
                &evidence.guard_next_existing_work,
            ) || evidence.guard_next_existing_work == PROVIDER_ROUTE_COPY_SOURCE_GUARD_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_deferred_or_advanced_by_mlx_route",
            large_model_provider_reference_deferred_or_advanced_cursor(
                &evidence.capability_next_bottleneck,
            ) || (evidence.capability_next_bottleneck == PROVIDER_ROUTE_COPY_SOURCE_GUARD_CURSOR
                && evidence.capability_deferral_pass_consumed),
        ),
        (
            "heavy_long_context_disabled",
            !evidence.guard_heavy_long_context_enabled
                && !evidence.capability_heavy_long_context_enabled,
        ),
        (
            "provider_reference_not_required",
            !evidence.guard_provider_reference_required,
        ),
        (
            "provider_reference_readiness_witness_available",
            evidence.provider_reference_readiness_witness_available,
        ),
        (
            "provider_reference_primary_blocker_bound",
            evidence.provider_reference_primary_blocker == "missing_provider_reference_env",
        ),
        (
            "provider_reference_env_not_set",
            !evidence.provider_reference_env_set,
        ),
        (
            "prompt_level_reference_unavailable",
            !evidence.prompt_level_reference_available,
        ),
        (
            "local_70b_preflight_honest_red",
            evidence.local_70b_preflight_honest_red,
        ),
        (
            "local_70b_primary_bottleneck_bound",
            evidence.local_70b_primary_bottleneck == "missing_fp16_or_provider_reference",
        ),
        (
            "local_70b_provider_reference_unavailable",
            !evidence.local_70b_provider_reference_available,
        ),
        (
            "practical_mlx_route_preserved",
            registry
                .fixtures
                .iter()
                .any(|fixture| fixture.card.active_lane == LargeModelActiveLane::PracticalMlxLocal),
        ),
        (
            "cold_assembly_architecture_preserved",
            registry
                .fixtures
                .iter()
                .all(|fixture| fixture.card.cold_assembly_architecture_preserved),
        ),
        (
            "provider_reference_prompt_level_deferred",
            registry.fixtures.iter().all(|fixture| {
                fixture
                    .card
                    .deferred_lanes
                    .contains(&LargeModelDeferredLane::ProviderReferencePromptLevel)
            }),
        ),
        (
            "kv_direct_128k_deferred",
            registry.fixtures.iter().all(|fixture| {
                fixture
                    .card
                    .deferred_lanes
                    .contains(&LargeModelDeferredLane::KvDirect128k)
            }),
        ),
        (
            "dense_70b_runtime_deferred",
            registry.fixtures.iter().all(|fixture| {
                fixture
                    .card
                    .deferred_lanes
                    .contains(&LargeModelDeferredLane::Dense70bRuntime)
            }),
        ),
        (
            "live_sparse_70b_runtime_deferred",
            registry.fixtures.iter().all(|fixture| {
                fixture
                    .card
                    .deferred_lanes
                    .contains(&LargeModelDeferredLane::LiveSparse70bRuntime)
            }),
        ),
        (
            "rollback_bound",
            registry
                .fixtures
                .iter()
                .all(|fixture| fixture.card.rollback_ref.starts_with("rollback:")),
        ),
        (
            "run_event_log_bound",
            registry
                .fixtures
                .iter()
                .all(|fixture| fixture.card.run_event_log_ref.starts_with("run_event_log:")),
        ),
        (
            "answer_packet_ref_bound",
            registry
                .fixtures
                .iter()
                .all(|fixture| fixture.card.answer_packet_ref.starts_with("answer_packet:")),
        ),
        (
            "compatibility_fence_bound",
            registry
                .fixtures
                .iter()
                .all(|fixture| fixture.card.compatibility_fence.starts_with("compat:")),
        ),
        (
            "product_status_research_only",
            registry.fixtures.iter().all(|fixture| {
                fixture.card.product_build == ProductBuild::Pro
                    && fixture.card.pro_status == ProStatus::ResearchCandidate
            }),
        ),
        ("no_provider_call", metrics.provider_call_count == 0),
        (
            "no_prompt_level_manifest_created",
            registry
                .fixtures
                .iter()
                .all(|fixture| !fixture.card.prompt_level_manifest_created),
        ),
        (
            "no_kv_shard_rerun",
            registry
                .fixtures
                .iter()
                .all(|fixture| !fixture.card.kv_shard_rerun_requested),
        ),
        ("no_runtime_bytes_loaded", metrics.runtime_bytes_loaded == 0),
        ("no_model_bytes_loaded", metrics.model_bytes_loaded == 0),
        (
            "no_hidden_cloud_fallback",
            registry
                .fixtures
                .iter()
                .all(|fixture| !fixture.card.hidden_cloud_fallback),
        ),
        (
            "no_product_route_promotion",
            registry
                .fixtures
                .iter()
                .all(|fixture| !fixture.card.product_route_promoted),
        ),
        (
            "no_dense_resident_overclaim",
            registry
                .fixtures
                .iter()
                .all(|fixture| !fixture.card.dense_resident_overclaim),
        ),
        (
            "metadata_bound",
            metrics.max_metadata_bytes <= MAX_METADATA_BYTES,
        ),
        (
            "large_model_provider_deferral_address_deterministic",
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
        "deferred_lane_count",
        metrics.deferred_lane_count,
        MIN_DEFERRED_LANE_COUNT,
        "lanes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "active_lane_count",
        metrics.active_lane_count,
        ">=",
        2,
        "lanes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "deferral_safety_bps",
        metrics.deferral_safety_bps,
        ">=",
        MIN_DEFERRAL_SAFETY_BPS,
        "bps",
    );
    add_baseline_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "forced_provider_baseline_bps",
        metrics.forced_provider_baseline_bps,
        metrics.deferral_safety_bps,
    );
    add_baseline_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hidden_cloud_baseline_bps",
        metrics.hidden_cloud_baseline_bps,
        metrics.deferral_safety_bps,
    );
    add_baseline_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "dense_resident_baseline_bps",
        metrics.dense_resident_baseline_bps,
        metrics.deferral_safety_bps,
    );
    add_baseline_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rerun_shard_baseline_bps",
        metrics.rerun_shard_baseline_bps,
        metrics.deferral_safety_bps,
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "provider_call_count",
        metrics.provider_call_count,
        "<=",
        0,
        "calls",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_bytes_loaded",
        metrics.runtime_bytes_loaded,
        "<=",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_bytes_loaded",
        metrics.model_bytes_loaded,
        "<=",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_metadata_bytes",
        metrics.max_metadata_bytes,
        "<=",
        MAX_METADATA_BYTES,
        "bytes",
    );
    measurements.insert(
        "large_model_provider_deferral_address".to_string(),
        Measurement {
            value: serde_json::Value::String(address.clone()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "large_model_provider_deferral_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::Value::String(
                "uas:large-model-provider-reference-deferral:sha256:".to_string(),
            ),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "large_model_provider_deferral_address".to_string(),
        address.starts_with("uas:large-model-provider-reference-deferral:sha256:"),
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
            "kind": "metadata_only_large_model_provider_deferral",
            "detail": "Default architecture loop preserves large-local-model ambition but defers provider/fp16/70B and 128K heavy probes unless EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT=1 is explicitly set."
        })],
        notes: "Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof. F-LargeModelProviderReference-DeferredByMlxRoute is metadata-only: it proves default MLX routing defers provider/fp16/70B and 128K heavy work without provider calls, prompt-level manifests, runtime/model bytes, hidden cloud fallback, dense-resident overclaim, or product promotion.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();
    Ok(artifact)
}

fn validate_fixtures(fixtures: &[LargeModelDeferralFixture]) -> Result<(), DeferralWitnessError> {
    if fixtures.is_empty() {
        return Err(DeferralWitnessError::EmptyFixture);
    }
    let mut fixture_ids = HashSet::new();
    let mut card_addresses = HashSet::new();
    for fixture in fixtures {
        if fixture.fixture_id.is_empty()
            || fixture.fixture_scope != "metadata_only_large_model_provider_deferral"
        {
            return Err(DeferralWitnessError::EmptyFixture);
        }
        if !fixture_ids.insert(fixture.fixture_id.clone()) {
            return Err(DeferralWitnessError::DuplicateFixture(
                fixture.fixture_id.clone(),
            ));
        }
        if !card_addresses.insert(fixture.card.card_address.to_string()) {
            return Err(DeferralWitnessError::DuplicateCard(
                fixture.card.card_address.to_string(),
            ));
        }
        if fixture.deferral_safety_bps < MIN_DEFERRAL_SAFETY_BPS {
            return Err(DeferralWitnessError::SafetyBelowFloor);
        }
        if fixture.forced_provider_baseline_bps >= fixture.deferral_safety_bps {
            return Err(DeferralWitnessError::BaselineUnbeaten("forced_provider"));
        }
        if fixture.hidden_cloud_baseline_bps >= fixture.deferral_safety_bps {
            return Err(DeferralWitnessError::BaselineUnbeaten("hidden_cloud"));
        }
        if fixture.dense_resident_baseline_bps >= fixture.deferral_safety_bps {
            return Err(DeferralWitnessError::BaselineUnbeaten("dense_resident"));
        }
        if fixture.rerun_shard_baseline_bps >= fixture.deferral_safety_bps {
            return Err(DeferralWitnessError::BaselineUnbeaten("rerun_shard"));
        }
        if fixture.metadata_bytes > MAX_METADATA_BYTES {
            return Err(DeferralWitnessError::MetadataBudgetExceeded);
        }
    }
    Ok(())
}

fn invalid_fixture_axes() -> Result<Vec<(&'static str, bool)>, DeferralWitnessError> {
    let mut cases = Vec::new();
    cases.push((
        "empty_fixture_rejected",
        LargeModelDeferralRegistry::new(vec![]).is_err(),
    ));
    cases.push((
        "duplicate_fixture_rejected",
        rejects_registry(|fixtures| fixtures.push(fixtures[0].clone()))?,
    ));
    cases.push((
        "duplicate_card_rejected",
        rejects_registry(|fixtures| {
            fixtures[1].card = fixtures[0].card.clone();
        })?,
    ));
    cases.push((
        "wrong_cursor_rejected",
        card_with_cursor("missing_fp16_or_provider_reference").is_err(),
    ));
    cases.push((
        "missing_readiness_ref_rejected",
        card_with_readiness_ref("bad").is_err(),
    ));
    cases.push((
        "missing_deferred_lane_rejected",
        card_with_lanes(vec![]).is_err(),
    ));
    cases.push((
        "duplicate_deferred_lane_rejected",
        card_with_lanes(vec![
            LargeModelDeferredLane::KvDirect128k,
            LargeModelDeferredLane::KvDirect128k,
        ])
        .is_err(),
    ));
    cases.push((
        "heavy_long_context_enabled_rejected",
        card_with_flags(
            true, false, 0, false, false, 0, 0, false, false, false, true, true,
        )
        .is_err(),
    ));
    cases.push((
        "provider_reference_required_rejected",
        card_with_flags(
            false, true, 0, false, false, 0, 0, false, false, false, true, true,
        )
        .is_err(),
    ));
    cases.push((
        "provider_call_rejected",
        card_with_flags(
            false, false, 1, false, false, 0, 0, false, false, false, true, true,
        )
        .is_err(),
    ));
    cases.push((
        "prompt_level_manifest_creation_rejected",
        card_with_flags(
            false, false, 0, true, false, 0, 0, false, false, false, true, true,
        )
        .is_err(),
    ));
    cases.push((
        "kv_shard_rerun_rejected",
        card_with_flags(
            false, false, 0, false, true, 0, 0, false, false, false, true, true,
        )
        .is_err(),
    ));
    cases.push((
        "runtime_bytes_rejected",
        card_with_flags(
            false, false, 0, false, false, 1, 0, false, false, false, true, true,
        )
        .is_err(),
    ));
    cases.push((
        "model_bytes_rejected",
        card_with_flags(
            false, false, 0, false, false, 0, 1, false, false, false, true, true,
        )
        .is_err(),
    ));
    cases.push((
        "hidden_cloud_fallback_rejected",
        card_with_flags(
            false, false, 0, false, false, 0, 0, true, false, false, true, true,
        )
        .is_err(),
    ));
    cases.push((
        "product_route_promotion_rejected",
        card_with_flags(
            false, false, 0, false, false, 0, 0, false, true, false, true, true,
        )
        .is_err(),
    ));
    cases.push((
        "dense_resident_overclaim_rejected",
        card_with_flags(
            false, false, 0, false, false, 0, 0, false, false, true, true, true,
        )
        .is_err(),
    ));
    cases.push((
        "practical_mlx_route_missing_rejected",
        card_with_flags(
            false, false, 0, false, false, 0, 0, false, false, false, false, true,
        )
        .is_err(),
    ));
    cases.push((
        "cold_assembly_architecture_missing_rejected",
        card_with_flags(
            false, false, 0, false, false, 0, 0, false, false, false, true, false,
        )
        .is_err(),
    ));
    cases.push((
        "forced_provider_baseline_unbeaten_rejected",
        rejects_registry(|fixtures| {
            fixtures[0].forced_provider_baseline_bps = fixtures[0].deferral_safety_bps;
        })?,
    ));
    cases.push((
        "hidden_cloud_baseline_unbeaten_rejected",
        rejects_registry(|fixtures| {
            fixtures[0].hidden_cloud_baseline_bps = fixtures[0].deferral_safety_bps;
        })?,
    ));
    cases.push((
        "dense_resident_baseline_unbeaten_rejected",
        rejects_registry(|fixtures| {
            fixtures[0].dense_resident_baseline_bps = fixtures[0].deferral_safety_bps;
        })?,
    ));
    cases.push((
        "rerun_shard_baseline_unbeaten_rejected",
        rejects_registry(|fixtures| {
            fixtures[0].rerun_shard_baseline_bps = fixtures[0].deferral_safety_bps;
        })?,
    ));
    cases.push((
        "metadata_budget_rejected",
        rejects_registry(|fixtures| {
            fixtures[0].metadata_bytes = MAX_METADATA_BYTES + 1;
        })?,
    ));
    Ok(cases)
}

fn rejects_registry(
    mutate: impl FnOnce(&mut Vec<LargeModelDeferralFixture>),
) -> Result<bool, DeferralWitnessError> {
    let mut fixtures = fixture_deferral_fixtures()?;
    mutate(&mut fixtures);
    Ok(LargeModelDeferralRegistry::new(fixtures).is_err())
}

fn fixture_deferral_fixtures() -> Result<Vec<LargeModelDeferralFixture>, DeferralWitnessError> {
    Ok(vec![
        LargeModelDeferralFixture {
            fixture_id: "deferral:practical-mlx-local".to_string(),
            fixture_scope: "metadata_only_large_model_provider_deferral".to_string(),
            card: card_with_active_lane(
                "large-model-deferral:practical-mlx-local",
                LargeModelActiveLane::PracticalMlxLocal,
            )?,
            deferral_safety_bps: 9_700,
            forced_provider_baseline_bps: 3_200,
            hidden_cloud_baseline_bps: 2_100,
            dense_resident_baseline_bps: 1_200,
            rerun_shard_baseline_bps: 4_100,
            metadata_bytes: 84 * 1024,
        },
        LargeModelDeferralFixture {
            fixture_id: "deferral:cold-assembly-preserved".to_string(),
            fixture_scope: "metadata_only_large_model_provider_deferral".to_string(),
            card: card_with_active_lane(
                "large-model-deferral:cold-assembly-preserved",
                LargeModelActiveLane::ColdAssemblyPlanner,
            )?,
            deferral_safety_bps: 9_650,
            forced_provider_baseline_bps: 3_400,
            hidden_cloud_baseline_bps: 2_200,
            dense_resident_baseline_bps: 1_100,
            rerun_shard_baseline_bps: 4_300,
            metadata_bytes: 88 * 1024,
        },
    ])
}

fn card_with_active_lane(
    card_id: &str,
    active_lane: LargeModelActiveLane,
) -> Result<LargeModelProviderDeferralCard, LargeModelDeferralError> {
    LargeModelProviderDeferralCard::new(
        card_id,
        LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_CURSOR,
        active_lane,
        fixture_lanes(),
        "artifact:falsifier:provider_reference_prompt_level_readiness",
        "missing_provider_reference_env",
        "artifact:falsifier:70b_local_cocktail_lite",
        "artifact:falsifier:architecture_pending_work_guard",
        "artifact:falsifier:capability_ceiling_evaluation_kernel",
        "rollback:large-model-provider-deferral:v1",
        "run_event_log:large-model-provider-deferral:v1",
        "answer_packet:large-model-provider-deferral:v1",
        "compat:large-model-provider-deferral:v1",
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        false,
        false,
        0,
        false,
        false,
        0,
        0,
        false,
        false,
        false,
        true,
        true,
        CREATED_AT_MS,
    )
}

fn card_with_lanes(
    lanes: Vec<LargeModelDeferredLane>,
) -> Result<LargeModelProviderDeferralCard, LargeModelDeferralError> {
    new_card(
        LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_CURSOR,
        "artifact:falsifier:provider_reference_prompt_level_readiness",
        lanes,
        false,
        false,
        0,
        false,
        false,
        0,
        0,
        false,
        false,
        false,
        true,
        true,
    )
}

fn card_with_cursor(
    cursor: &str,
) -> Result<LargeModelProviderDeferralCard, LargeModelDeferralError> {
    new_card(
        cursor,
        "artifact:falsifier:provider_reference_prompt_level_readiness",
        fixture_lanes(),
        false,
        false,
        0,
        false,
        false,
        0,
        0,
        false,
        false,
        false,
        true,
        true,
    )
}

fn card_with_readiness_ref(
    readiness_ref: &str,
) -> Result<LargeModelProviderDeferralCard, LargeModelDeferralError> {
    new_card(
        LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_CURSOR,
        readiness_ref,
        fixture_lanes(),
        false,
        false,
        0,
        false,
        false,
        0,
        0,
        false,
        false,
        false,
        true,
        true,
    )
}

#[allow(clippy::too_many_arguments)]
fn card_with_flags(
    heavy_long_context_enabled: bool,
    provider_reference_required: bool,
    provider_calls_attempted: u32,
    prompt_level_manifest_created: bool,
    kv_shard_rerun_requested: bool,
    runtime_bytes_loaded: u64,
    model_bytes_loaded: u64,
    hidden_cloud_fallback: bool,
    product_route_promoted: bool,
    dense_resident_overclaim: bool,
    practical_mlx_route_preserved: bool,
    cold_assembly_architecture_preserved: bool,
) -> Result<LargeModelProviderDeferralCard, LargeModelDeferralError> {
    new_card(
        LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_CURSOR,
        "artifact:falsifier:provider_reference_prompt_level_readiness",
        fixture_lanes(),
        heavy_long_context_enabled,
        provider_reference_required,
        provider_calls_attempted,
        prompt_level_manifest_created,
        kv_shard_rerun_requested,
        runtime_bytes_loaded,
        model_bytes_loaded,
        hidden_cloud_fallback,
        product_route_promoted,
        dense_resident_overclaim,
        practical_mlx_route_preserved,
        cold_assembly_architecture_preserved,
    )
}

#[allow(clippy::too_many_arguments)]
fn new_card(
    cursor: &str,
    readiness_ref: &str,
    lanes: Vec<LargeModelDeferredLane>,
    heavy_long_context_enabled: bool,
    provider_reference_required: bool,
    provider_calls_attempted: u32,
    prompt_level_manifest_created: bool,
    kv_shard_rerun_requested: bool,
    runtime_bytes_loaded: u64,
    model_bytes_loaded: u64,
    hidden_cloud_fallback: bool,
    product_route_promoted: bool,
    dense_resident_overclaim: bool,
    practical_mlx_route_preserved: bool,
    cold_assembly_architecture_preserved: bool,
) -> Result<LargeModelProviderDeferralCard, LargeModelDeferralError> {
    LargeModelProviderDeferralCard::new(
        "large-model-deferral:test-card",
        cursor,
        LargeModelActiveLane::PracticalMlxLocal,
        lanes,
        readiness_ref,
        "missing_provider_reference_env",
        "artifact:falsifier:70b_local_cocktail_lite",
        "artifact:falsifier:architecture_pending_work_guard",
        "artifact:falsifier:capability_ceiling_evaluation_kernel",
        "rollback:large-model-provider-deferral:v1",
        "run_event_log:large-model-provider-deferral:v1",
        "answer_packet:large-model-provider-deferral:v1",
        "compat:large-model-provider-deferral:v1",
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        heavy_long_context_enabled,
        provider_reference_required,
        provider_calls_attempted,
        prompt_level_manifest_created,
        kv_shard_rerun_requested,
        runtime_bytes_loaded,
        model_bytes_loaded,
        hidden_cloud_fallback,
        product_route_promoted,
        dense_resident_overclaim,
        practical_mlx_route_preserved,
        cold_assembly_architecture_preserved,
        CREATED_AT_MS,
    )
}

fn fixture_lanes() -> Vec<LargeModelDeferredLane> {
    vec![
        LargeModelDeferredLane::ProviderReferencePromptLevel,
        LargeModelDeferredLane::KvDirect128k,
        LargeModelDeferredLane::Dense70bRuntime,
        LargeModelDeferredLane::LiveSparse70bRuntime,
    ]
}

fn active_lane_tag(lane: &LargeModelActiveLane) -> &'static str {
    match lane {
        LargeModelActiveLane::PracticalMlxLocal => "practical_mlx_local",
        LargeModelActiveLane::ColdAssemblyPlanner => "cold_assembly_planner",
    }
}

fn deferred_lane_tag(lane: &LargeModelDeferredLane) -> &'static str {
    match lane {
        LargeModelDeferredLane::ProviderReferencePromptLevel => "provider_reference_prompt_level",
        LargeModelDeferredLane::KvDirect128k => "kv_direct_128k",
        LargeModelDeferredLane::Dense70bRuntime => "dense_70b_runtime",
        LargeModelDeferredLane::LiveSparse70bRuntime => "live_sparse_70b_runtime",
    }
}

// UAS: uas:large-model-provider-deferral:evidence-snapshot
// Plane: Verification
// Residency: metadata-only artifact reader; never calls providers or runtimes.
struct EvidenceSnapshot {
    guard_overall_pass: bool,
    guard_next_existing_work: String,
    guard_heavy_long_context_enabled: bool,
    guard_provider_reference_required: bool,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
    capability_deferral_pass_consumed: bool,
    capability_heavy_long_context_enabled: bool,
    provider_reference_readiness_witness_available: bool,
    provider_reference_primary_blocker: String,
    provider_reference_env_set: bool,
    prompt_level_reference_available: bool,
    local_70b_preflight_honest_red: bool,
    local_70b_primary_bottleneck: String,
    local_70b_provider_reference_available: bool,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, DeferralWitnessError> {
        let guard = read_json(GUARD_PATH)?;
        let capability = read_json(CAPABILITY_PATH)?;
        let provider = read_json(PROVIDER_READINESS_PATH)?;
        let cocktail = read_json(LOCAL_70B_PATH)?;
        Ok(Self {
            guard_overall_pass: bool_field(&guard, "overall_pass"),
            guard_next_existing_work: measurement_string(&guard, "next_existing_work")
                .unwrap_or_default(),
            guard_heavy_long_context_enabled: measurement_bool(
                &guard,
                "heavy_long_context_enabled",
            )
            .unwrap_or(false),
            guard_provider_reference_required: measurement_bool(
                &guard,
                "large_model_provider_reference_required",
            )
            .unwrap_or(false),
            capability_overall_pass: bool_field(&capability, "overall_pass"),
            capability_route_status: measurement_string(&capability, "route_status")
                .unwrap_or_default(),
            capability_next_bottleneck: measurement_string(&capability, "next_bottleneck")
                .unwrap_or_default(),
            capability_deferral_pass_consumed: measurement_bool(
                &capability,
                "large_model_provider_reference_deferral_pass",
            )
            .unwrap_or(false),
            capability_heavy_long_context_enabled: measurement_bool(
                &capability,
                "heavy_long_context_enabled",
            )
            .unwrap_or(false),
            provider_reference_readiness_witness_available: artifact_has_measurements(
                &provider,
                &[
                    "provider_reference_env_set",
                    "manifest_file_exists",
                    "manifest_valid",
                    "prompt_level_scope",
                    "prompt_count_floor",
                    "replay_files_valid",
                    "prompt_level_reference_available",
                    "primary_blocker",
                ],
            ),
            provider_reference_primary_blocker: measurement_string(&provider, "primary_blocker")
                .unwrap_or_default(),
            provider_reference_env_set: measurement_bool(&provider, "provider_reference_env_set")
                .unwrap_or(false),
            prompt_level_reference_available: measurement_bool(
                &provider,
                "prompt_level_reference_available",
            )
            .unwrap_or(false),
            local_70b_preflight_honest_red: !bool_field(&cocktail, "overall_pass")
                && measurement_string(&cocktail, "primary_bottleneck").as_deref()
                    == Some("missing_fp16_or_provider_reference")
                && measurement_bool(&cocktail, "provider_reference_available") == Some(false)
                && artifact_axis_true(&cocktail, "bottleneck_identified"),
            local_70b_primary_bottleneck: measurement_string(&cocktail, "primary_bottleneck")
                .unwrap_or_default(),
            local_70b_provider_reference_available: measurement_bool(
                &cocktail,
                "provider_reference_available",
            )
            .unwrap_or(false),
        })
    }
}

fn read_json(path: &'static str) -> Result<serde_json::Value, DeferralWitnessError> {
    let resolved = resolve_artifact_path(path);
    let text = std::fs::read_to_string(&resolved).map_err(|error| {
        DeferralWitnessError::Io(format!("failed to read {}: {error}", resolved.display()))
    })?;
    serde_json::from_str(&text)
        .map_err(|error| DeferralWitnessError::Io(format!("failed to parse {path}: {error}")))
}

fn resolve_artifact_path(path: &'static str) -> PathBuf {
    let direct = PathBuf::from(path);
    if direct.exists() {
        return direct;
    }
    Path::new("..").join(path)
}

fn bool_field(value: &serde_json::Value, key: &str) -> bool {
    value
        .get(key)
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
}

fn measurement_bool(value: &serde_json::Value, key: &str) -> Option<bool> {
    value
        .get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(serde_json::Value::as_bool)
}

fn measurement_string(value: &serde_json::Value, key: &str) -> Option<String> {
    value
        .get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(serde_json::Value::as_str)
        .map(str::to_string)
}

fn artifact_axis_true(value: &serde_json::Value, key: &str) -> bool {
    value
        .get("pass_per_axis")
        .and_then(|axes| axes.get(key))
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
}

fn artifact_has_measurements(value: &serde_json::Value, keys: &[&str]) -> bool {
    value
        .get("measurements")
        .is_some_and(|measurements| keys.iter().all(|key| measurements.get(*key).is_some()))
}

fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    actual: u64,
    operator: &str,
    expected: u64,
    unit: &str,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::from(actual),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
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
        ">" => actual > expected,
        "==" => actual == expected,
        _ => false,
    };
    pass_per_axis.insert(axis.to_string(), passed);
}

fn add_baseline_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    baseline_bps: u64,
    deferral_bps: u64,
) {
    add_u64_axis(
        measurements,
        thresholds,
        pass_per_axis,
        axis,
        baseline_bps,
        "<",
        deferral_bps,
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
    }

    #[test]
    fn artifact_contains_all_required_axes() {
        let artifact = build_artifact().expect("artifact");
        for axis in LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_BY_MLX_ROUTE_AXES {
            assert!(
                artifact.pass_per_axis.contains_key(*axis),
                "missing axis {axis}"
            );
        }
    }

    #[test]
    fn invalid_axes_are_true() {
        let artifact = build_artifact().expect("artifact");
        for axis in [
            "heavy_long_context_enabled_rejected",
            "provider_call_rejected",
            "prompt_level_manifest_creation_rejected",
            "kv_shard_rerun_rejected",
            "hidden_cloud_fallback_rejected",
            "dense_resident_overclaim_rejected",
            "forced_provider_baseline_unbeaten_rejected",
        ] {
            assert_eq!(
                artifact.pass_per_axis.get(axis).copied(),
                Some(true),
                "{axis}"
            );
        }
    }

    #[test]
    fn address_is_deterministic_under_fixture_order() {
        let left = LargeModelDeferralRegistry::new(fixture_deferral_fixtures().expect("fixtures"))
            .expect("registry")
            .address();
        let mut reversed = fixture_deferral_fixtures().expect("fixtures");
        reversed.reverse();
        let right = LargeModelDeferralRegistry::new(reversed)
            .expect("registry")
            .address();

        assert_eq!(left, right);
    }
}
