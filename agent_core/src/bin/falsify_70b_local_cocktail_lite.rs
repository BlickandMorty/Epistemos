//! `falsify_70b_local_cocktail_lite` — preflight artifact for
//! F-70B-Local-Cocktail-Lite.
//!
//! This is deliberately a failure-report harness, not a benchmark. The
//! user's no-compromise ceiling is a 70B-class local model on the M2 Pro
//! 16 GB floor by composing SSD-backed residency, UAS/ACS, KV-Direct,
//! PageGather, active assembly, ternary/lattice compression, speculative
//! decode, and optional cascade. Until those components compose on disk,
//! the app must keep the 70B route Vault/Research-only and name the
//! missing gates precisely.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind,
    FallbackTier, Measurement,
};
use agent_core::uas::ProviderReferenceManifest;

const FALSIFIER_ID: &str = "F-70B-Local-Cocktail-Lite";
const FIXTURE_ID: &str = "70b_cocktail_lite_preflight_v1";
const COMMAND: &str = "Tools/falsifiers/f_70b_local_cocktail_lite.sh";

const MODEL_PATH_ENV: &str = "EPISTEMOS_70B_MODEL_PATH";
const PROVIDER_REFERENCE_ENV: &str = "EPISTEMOS_70B_PROVIDER_REFERENCE";
const SPARSE_RUNTIME_PATH_ENV: &str = "EPISTEMOS_70B_SPARSE_RUNTIME_PATH";
const LARGE_MODEL_MIN_BYTES: u64 = 30 * 1024 * 1024 * 1024;
const UAS_ACS_MMAP_RESIDENCY_PATH: &str = "artifacts/falsifiers/uas_acs_mmap_residency/result.json";
const WEIGHT_BLOCK_RANGE_HASH_DRY_RUN_PATH: &str =
    "artifacts/falsifiers/weight_block_range_hash_dry_run/result.json";
const RESIDENCY_PLAN_DRY_RUN_PATH: &str = "artifacts/falsifiers/residency_plan_dry_run/result.json";
const KV_DIRECT_GATE_PATH: &str = "artifacts/falsifiers/kv_direct_gate/result.json";
const SPARSE_RUNTIME_SPLIT_PATH: &str = "artifacts/falsifiers/sparse_runtime_split/result.json";
const RETAINED_SHAPE_ONLY_PROVIDER_REFERENCE_MANIFEST_PATH: &str =
    "artifacts/falsifiers/70b_local_cocktail_lite/provider_reference_manifest_dry_run/shape_only_manifest.json";

fn main() {
    let report = build_report();
    let path = PathBuf::from("artifacts/falsifiers/70b_local_cocktail_lite/result.json");
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).expect("create 70B artifact directory");
    }
    let mut file = std::fs::File::create(&path).expect("open 70B artifact for write");
    write_artifact(&mut file, &report.artifact).expect("write 70B artifact");

    println!(
        "F-70B-Local-Cocktail-Lite preflight: overall_pass={} bottleneck={} artifact={}",
        report.artifact.overall_pass,
        report.primary_bottleneck,
        path.display()
    );

    if !report.artifact.overall_pass {
        std::process::exit(1);
    }
}

struct PreflightReport {
    artifact: agent_core::falsifier_artifacts::FalsifierArtifact,
    primary_bottleneck: String,
}

fn build_report() -> PreflightReport {
    let model_path = std::env::var(MODEL_PATH_ENV).ok();
    let provider_reference_path = std::env::var(PROVIDER_REFERENCE_ENV).ok();
    let sparse_runtime_path = std::env::var(SPARSE_RUNTIME_PATH_ENV).ok();
    let provider_reference_status = provider_reference_status(provider_reference_path.as_deref());
    let discovered_large_model = discover_largest_local_model();
    let discovered_large_model_available = discovered_large_model
        .as_ref()
        .map(|candidate| candidate.weight_bytes >= LARGE_MODEL_MIN_BYTES)
        .unwrap_or(false);
    let model_weights_available =
        path_exists(model_path.as_deref()) || discovered_large_model_available;
    let provider_reference_available = provider_reference_status.prompt_level_available;
    let sparse_70b_runtime_available = path_exists(sparse_runtime_path.as_deref());

    let uas_copy_count_artifact_available =
        Path::new("artifacts/falsifiers/uas_copy_count/result.json").exists();
    let uas_zero_copy_spine_artifact_available =
        Path::new("artifacts/falsifiers/uas_zero_copy_spine/result.json").exists();
    let uas_acs_mmap_residency_artifact = GateArtifact::read(UAS_ACS_MMAP_RESIDENCY_PATH);
    let uas_acs_mmap_residency_artifact_available = uas_acs_mmap_residency_artifact.overall_pass
        && uas_acs_mmap_residency_artifact.all_axes_true(&[
            "mmap_backed_bytes",
            "uas_address_round_trip",
            "acs_projection_lookup",
            "residency_lease_round_trip",
            "hot_path_tracked_copies",
        ]);
    let weight_block_range_hash_dry_run_artifact =
        GateArtifact::read(WEIGHT_BLOCK_RANGE_HASH_DRY_RUN_PATH);
    let weight_block_range_hash_dry_run_available = weight_block_range_hash_dry_run_artifact
        .overall_pass
        && weight_block_range_hash_dry_run_artifact.all_axes_true(&[
            "bounded_range_hashed",
            "range_len_bytes",
            "over_limit_rejected_before_read",
            "short_reader_rejected",
            "known_hash_manifest_valid",
            "no_model_file_touched",
        ]);
    let residency_plan_dry_run_artifact = GateArtifact::read(RESIDENCY_PLAN_DRY_RUN_PATH);
    let residency_plan_dry_run_available = residency_plan_dry_run_artifact.overall_pass
        && residency_plan_dry_run_artifact.all_axes_true(&[
            "fit_for_dry_run",
            "deterministic_plan_address",
            "runtime_model_bytes_loaded",
            "missing_rollback_rejected",
            "overlapping_ranges_rejected",
            "sherry_and_leech_codec_names_present",
        ]);
    let page_gather_packetized_artifact_available =
        Path::new("artifacts/falsifiers/page_gather/locality_probe_result.json").exists();
    let kv_direct_artifact = GateArtifact::read(KV_DIRECT_GATE_PATH);
    let kv_direct_artifact_present = Path::new(KV_DIRECT_GATE_PATH).exists();
    let kv_direct_artifact_available = kv_direct_artifact.overall_pass;
    let active_assembly_component_available =
        Path::new("agent_core/tests/active_assembly_minimal.rs").exists();
    let active_assembly_artifact_available =
        Path::new("artifacts/falsifiers/active_assembly_minimal/result.json").exists();
    let sparse_runtime_split_artifact = GateArtifact::read(SPARSE_RUNTIME_SPLIT_PATH);
    let sparse_runtime_split_artifact_available = sparse_runtime_split_artifact.overall_pass;
    let synthetic_ir_chart_coverage_available = sparse_runtime_split_artifact.all_axes_true(&[
        "eml_chart_coverage_available",
        "geometry_chart_coverage_available",
        "scan_chart_coverage_available",
        "operator_chart_coverage_available",
    ]);
    let live_70b_ir_chart_coverage_available = sparse_70b_runtime_available
        && synthetic_ir_chart_coverage_available
        && model_weights_available
        && provider_reference_available;

    let primary_bottleneck = choose_primary_bottleneck(
        model_weights_available,
        weight_block_range_hash_dry_run_available,
        residency_plan_dry_run_available,
        provider_reference_available,
        kv_direct_artifact_available,
        sparse_70b_runtime_available,
    );

    let mut measurements: BTreeMap<String, Measurement> = BTreeMap::new();
    let mut thresholds: BTreeMap<String, AcceptanceThreshold> = BTreeMap::new();
    let mut pass_per_axis: BTreeMap<String, bool> = BTreeMap::new();

    add_float_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "d_kl_nats",
        999.0,
        "<",
        0.1,
        "nats",
    );
    add_float_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "decode_tok_s",
        0.0,
        ">=",
        5.0,
        "tokens_per_second",
    );
    add_float_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "ttft_seconds",
        9_999.0,
        "<=",
        30.0,
        "seconds",
    );
    add_float_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "resident_memory_gb",
        999.0,
        "<",
        14.0,
        "GB",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "bottleneck_identified",
        true,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_weights_available",
        model_weights_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "provider_reference_available",
        provider_reference_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "provider_reference_manifest_valid",
        provider_reference_status.manifest_valid,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "provider_reference_replay_files_valid",
        provider_reference_status.replay_files_valid,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "uas_copy_count_artifact_available",
        uas_copy_count_artifact_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "uas_zero_copy_spine_artifact_available",
        uas_zero_copy_spine_artifact_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "uas_acs_mmap_residency_artifact_available",
        uas_acs_mmap_residency_artifact_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "weight_block_range_hash_dry_run_available",
        weight_block_range_hash_dry_run_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "residency_plan_dry_run_available",
        residency_plan_dry_run_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "page_gather_packetized_artifact_available",
        page_gather_packetized_artifact_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_direct_artifact_available",
        kv_direct_artifact_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_direct_artifact_present",
        kv_direct_artifact_present,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "active_assembly_component_available",
        active_assembly_component_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "active_assembly_artifact_available",
        active_assembly_artifact_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "sparse_runtime_split_artifact_available",
        sparse_runtime_split_artifact_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "eml_geometry_scan_chart_coverage_available",
        live_70b_ir_chart_coverage_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "synthetic_ir_chart_coverage_available",
        synthetic_ir_chart_coverage_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "sparse_70b_runtime_available",
        sparse_70b_runtime_available,
    );

    measurements.insert(
        "primary_bottleneck".to_string(),
        Measurement {
            value: serde_json::Value::String(primary_bottleneck.clone()),
            unit: "label".to_string(),
        },
    );
    measurements.insert(
        "model_path_env".to_string(),
        Measurement {
            value: serde_json::Value::String(
                model_path.unwrap_or_else(|| format!("{MODEL_PATH_ENV}=unset")),
            ),
            unit: "path_or_env".to_string(),
        },
    );
    measurements.insert(
        "auto_discovered_largest_model".to_string(),
        Measurement {
            value: discovered_large_model
                .as_ref()
                .map(LocalModelCandidate::to_json)
                .unwrap_or(serde_json::Value::Null),
            unit: "object".to_string(),
        },
    );
    measurements.insert(
        "large_model_min_bytes".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(LARGE_MODEL_MIN_BYTES)),
            unit: "bytes".to_string(),
        },
    );
    measurements.insert(
        "provider_reference_env".to_string(),
        Measurement {
            value: serde_json::Value::String(
                provider_reference_path
                    .unwrap_or_else(|| format!("{PROVIDER_REFERENCE_ENV}=unset")),
            ),
            unit: "path_or_env".to_string(),
        },
    );
    measurements.insert(
        "provider_reference_status".to_string(),
        Measurement {
            value: serde_json::Value::String(provider_reference_status.label),
            unit: "label".to_string(),
        },
    );
    measurements.insert(
        "provider_reference_manifest_source".to_string(),
        Measurement {
            value: serde_json::Value::String(
                provider_reference_status
                    .source_path
                    .unwrap_or_else(|| "none".to_string()),
            ),
            unit: "path".to_string(),
        },
    );
    measurements.insert(
        "sparse_runtime_path_env".to_string(),
        Measurement {
            value: serde_json::Value::String(
                sparse_runtime_path.unwrap_or_else(|| format!("{SPARSE_RUNTIME_PATH_ENV}=unset")),
            ),
            unit: "path_or_env".to_string(),
        },
    );

    let anomalies = vec![
        serde_json::json!({
            "kind": "capability_ceiling_not_product",
            "detail": "70B remains Vault/Research-only until this artifact becomes a primary witness with local prompt-level quality, latency, and RSS measurements."
        }),
        serde_json::json!({
            "kind": "missing_sparse_70b_runtime",
            "detail": "No live sparse 70B runtime path is wired yet. The synthetic F-Sparse-Runtime-Split artifact is a substrate witness, not a replacement for a model-backed sparse runtime."
        }),
        serde_json::json!({
            "kind": "missing_ir_chart_coverage",
            "detail": "Synthetic EML/Geometry/Scan/Operator chart coverage exists only if F-Sparse-Runtime-Split passes. Live 70B chart coverage remains red until model weights and the sparse runtime path are present."
        }),
        serde_json::json!({
            "kind": "component_artifact_gap",
            "detail": format!(
                "model_weights_available={model_weights_available}; provider_reference_available={provider_reference_available}; kv_direct_artifact_available={kv_direct_artifact_available}; page_gather_packetized_artifact_available={page_gather_packetized_artifact_available}; uas_acs_mmap_residency_artifact_available={uas_acs_mmap_residency_artifact_available}; weight_block_range_hash_dry_run_available={weight_block_range_hash_dry_run_available}; active_assembly_artifact_available={active_assembly_artifact_available}; sparse_runtime_split_artifact_available={sparse_runtime_split_artifact_available}; synthetic_ir_chart_coverage_available={synthetic_ir_chart_coverage_available}; live_70b_ir_chart_coverage_available={live_70b_ir_chart_coverage_available}"
            )
        }),
        serde_json::json!({
            "kind": "weight_block_range_hash_dry_run_status",
            "detail": format!(
                "weight_block_range_hash_dry_run_available={weight_block_range_hash_dry_run_available}; this proves bounded byte-range fingerprinting only, not model loading or mmap residency."
            )
        }),
        serde_json::json!({
            "kind": "residency_plan_dry_run_status",
            "detail": format!(
                "residency_plan_dry_run_available={residency_plan_dry_run_available}; this proves model-shaped active-set planning only, not live model execution."
            )
        }),
        serde_json::json!({
            "kind": "auto_discovered_large_model",
            "detail": format!(
                "discovered_large_model_available={discovered_large_model_available}; threshold_bytes={LARGE_MODEL_MIN_BYTES}; this is a local large-model candidate, not proof of a working 70B sparse runtime."
            )
        }),
        serde_json::json!({
            "kind": "uas_acs_mmap_component_status",
            "detail": format!(
                "uas_acs_mmap_residency_artifact_available={uas_acs_mmap_residency_artifact_available}; this proves file-backed UAS/ACS residency only, not live 70B token generation."
            )
        }),
    ];

    let notes = format!(
        "preflight_failure_report; no 70B local product claim; primary_bottleneck={primary_bottleneck}; \
         set {MODEL_PATH_ENV}, {PROVIDER_REFERENCE_ENV}, and {SPARSE_RUNTIME_PATH_ENV}, then replace sentinel quality/latency values \
         with measured prompt-level D_KL, TTFT, tok/s, RSS, cache state, and bottleneck attribution"
    );

    let artifact = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: ArtifactKind::FailureReport,
        command: COMMAND.to_string(),
        commit_sha: agent_core::falsifier_artifacts::current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Fail,
        anomalies,
        notes,
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    PreflightReport {
        artifact,
        primary_bottleneck,
    }
}

fn path_exists(path: Option<&str>) -> bool {
    path.map(|p| Path::new(p).exists()).unwrap_or(false)
}

struct ProviderReferenceStatus {
    prompt_level_available: bool,
    manifest_valid: bool,
    replay_files_valid: bool,
    label: String,
    source_path: Option<String>,
}

fn provider_reference_status(path: Option<&str>) -> ProviderReferenceStatus {
    provider_reference_status_at(path, Path::new("."))
}

fn provider_reference_status_at(path: Option<&str>, base_dir: &Path) -> ProviderReferenceStatus {
    if let Some(path) = path {
        return provider_reference_status_from_path(Path::new(path), base_dir);
    }
    let retained_shape_manifest = base_dir.join(RETAINED_SHAPE_ONLY_PROVIDER_REFERENCE_MANIFEST_PATH);
    if retained_shape_manifest.exists() {
        return provider_reference_status_from_path(&retained_shape_manifest, base_dir);
    }
    ProviderReferenceStatus {
        prompt_level_available: false,
        manifest_valid: false,
        replay_files_valid: false,
        label: "env_unset".to_string(),
        source_path: None,
    }
}

fn provider_reference_status_from_path(path: &Path, base_dir: &Path) -> ProviderReferenceStatus {
    let source_path = path.display().to_string();
    if !path.exists() {
        return ProviderReferenceStatus {
            prompt_level_available: false,
            manifest_valid: false,
            replay_files_valid: false,
            label: "path_missing".to_string(),
            source_path: Some(source_path),
        };
    };
    match ProviderReferenceManifest::from_path(path) {
        Ok(manifest) => {
            let replay_result = manifest.validate_replay_files_at(base_dir);
            let replay_files_valid = replay_result.is_ok();
            let prompt_level_available = manifest.is_prompt_level_reference() && replay_files_valid;
            let label = match (
                manifest.is_prompt_level_reference(),
                replay_result.as_ref().err(),
            ) {
                (true, None) => "prompt_level_replayable_manifest".to_string(),
                (true, Some(error)) => format!("prompt_level_replay_files_invalid:{error}"),
                (false, None) => "shape_only_manifest".to_string(),
                (false, Some(error)) => format!("shape_only_replay_files_invalid:{error}"),
            };
            ProviderReferenceStatus {
                prompt_level_available,
                manifest_valid: true,
                replay_files_valid,
                label,
                source_path: Some(source_path),
            }
        }
        Err(error) => ProviderReferenceStatus {
            prompt_level_available: false,
            manifest_valid: false,
            replay_files_valid: false,
            label: format!("invalid_manifest:{error}"),
            source_path: Some(source_path),
        },
    }
}

#[derive(Debug, Clone)]
struct LocalModelCandidate {
    path: String,
    weight_bytes: u64,
    config_model_type: Option<String>,
    max_position_embeddings: Option<u64>,
}

impl LocalModelCandidate {
    fn to_json(&self) -> serde_json::Value {
        serde_json::json!({
            "path": self.path,
            "weight_bytes": self.weight_bytes,
            "config_model_type": self.config_model_type,
            "max_position_embeddings": self.max_position_embeddings,
        })
    }
}

fn discover_largest_local_model() -> Option<LocalModelCandidate> {
    let mut root = PathBuf::from(std::env::var_os("HOME")?);
    root.push("Library/Application Support/Epistemos/Models/text/hub");
    let mut candidates = Vec::new();
    collect_model_candidates(&root, 0, &mut candidates);
    candidates
        .into_iter()
        .max_by_key(|candidate| candidate.weight_bytes)
}

fn collect_model_candidates(path: &Path, depth: usize, candidates: &mut Vec<LocalModelCandidate>) {
    if depth > 8 {
        return;
    }
    let config_path = path.join("config.json");
    if config_path.exists() {
        let weight_bytes = model_weight_bytes(path);
        if weight_bytes > 0 {
            candidates.push(LocalModelCandidate {
                path: path.display().to_string(),
                weight_bytes,
                config_model_type: config_string(&config_path, "model_type"),
                max_position_embeddings: config_u64(&config_path, "max_position_embeddings"),
            });
        }
    }
    let Ok(entries) = std::fs::read_dir(path) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            collect_model_candidates(&path, depth + 1, candidates);
        }
    }
}

fn model_weight_bytes(path: &Path) -> u64 {
    let Ok(entries) = std::fs::read_dir(path) else {
        return 0;
    };
    entries
        .flatten()
        .filter_map(|entry| {
            let path = entry.path();
            let extension = path.extension().and_then(|extension| extension.to_str())?;
            if !matches!(extension, "safetensors" | "gguf") {
                return None;
            }
            std::fs::metadata(&path).ok().map(|metadata| metadata.len())
        })
        .sum()
}

fn config_string(path: &Path, key: &str) -> Option<String> {
    let value = read_config_json(path)?;
    value.get(key)?.as_str().map(ToString::to_string)
}

fn config_u64(path: &Path, key: &str) -> Option<u64> {
    let value = read_config_json(path)?;
    value.get(key)?.as_u64()
}

fn read_config_json(path: &Path) -> Option<serde_json::Value> {
    let text = std::fs::read_to_string(path).ok()?;
    serde_json::from_str(&text).ok()
}

struct GateArtifact {
    overall_pass: bool,
    value: Option<serde_json::Value>,
}

impl GateArtifact {
    fn read(path: &str) -> Self {
        let value = std::fs::read_to_string(path)
            .ok()
            .and_then(|s| serde_json::from_str::<serde_json::Value>(&s).ok());
        let overall_pass = value
            .as_ref()
            .and_then(|v| v.get("overall_pass"))
            .and_then(|v| v.as_bool())
            .unwrap_or(false);
        Self {
            overall_pass,
            value,
        }
    }

    fn axis_true(&self, axis: &str) -> bool {
        self.value
            .as_ref()
            .and_then(|v| v.get("pass_per_axis"))
            .and_then(|v| v.get(axis))
            .and_then(|v| v.as_bool())
            .unwrap_or(false)
    }

    fn all_axes_true(&self, axes: &[&str]) -> bool {
        self.overall_pass && axes.iter().all(|axis| self.axis_true(axis))
    }
}

fn choose_primary_bottleneck(
    model_weights_available: bool,
    weight_block_range_hash_dry_run_available: bool,
    residency_plan_dry_run_available: bool,
    provider_reference_available: bool,
    kv_direct_artifact_available: bool,
    sparse_70b_runtime_available: bool,
) -> String {
    if !model_weights_available {
        "missing_local_70b_model_weights".to_string()
    } else if !weight_block_range_hash_dry_run_available {
        "missing_weight_block_range_hash_dry_run".to_string()
    } else if !residency_plan_dry_run_available {
        "missing_residency_plan_dry_run".to_string()
    } else if !provider_reference_available {
        "missing_fp16_or_provider_reference".to_string()
    } else if !kv_direct_artifact_available {
        "missing_kv_direct_gate_artifact".to_string()
    } else if !sparse_70b_runtime_available {
        "missing_sparse_70b_runtime".to_string()
    } else {
        "ready_for_prompt_level_measurement".to_string()
    }
}

fn add_bool_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: bool,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::Bool(value),
            unit: "bool".to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "bool".to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), value);
}

fn add_float_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: f64,
    operator: &str,
    threshold: f64,
    unit: &str,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::Number(number(value)),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::Number(number(threshold)),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), compare(value, operator, threshold));
}

fn compare(value: f64, operator: &str, threshold: f64) -> bool {
    match operator {
        "<" => value < threshold,
        "<=" => value <= threshold,
        ">=" => value >= threshold,
        ">" => value > threshold,
        "==" => (value - threshold).abs() <= f64::EPSILON,
        _ => false,
    }
}

fn number(value: f64) -> serde_json::Number {
    serde_json::Number::from_f64(value).unwrap_or_else(|| serde_json::Number::from(0))
}

#[cfg(test)]
mod tests {
    use super::*;
    use agent_core::falsifier_artifacts::sha256_hex;
    use agent_core::uas::{
        ProviderReferenceKind, ReferenceDataSentClass, ReferenceEvidenceScope,
        ReferenceRetentionClaim,
    };

    fn write_provider_reference_fixture(
        root: &Path,
        scope: ReferenceEvidenceScope,
        prompt_count: u32,
        write_prompt_suite: bool,
    ) -> String {
        let artifact_ref =
            "artifacts/falsifiers/70b_local_cocktail_lite/test_reference.jsonl".to_string();
        let prompt_suite_artifact_ref =
            "artifacts/falsifiers/kv_direct_gate/test_prompt_suite.json".to_string();
        let artifact_path = root.join(&artifact_ref);
        let prompt_suite_path = root.join(&prompt_suite_artifact_ref);
        std::fs::create_dir_all(artifact_path.parent().unwrap()).unwrap();
        std::fs::create_dir_all(prompt_suite_path.parent().unwrap()).unwrap();
        let reference_bytes = b"{\"scope\":\"test-reference\"}\n";
        let prompt_suite_bytes = b"{\"suite\":\"test-suite\"}\n";
        std::fs::write(&artifact_path, reference_bytes).unwrap();
        if write_prompt_suite {
            std::fs::write(&prompt_suite_path, prompt_suite_bytes).unwrap();
        }
        let manifest = ProviderReferenceManifest {
            schema_version: ProviderReferenceManifest::SCHEMA_VERSION.to_string(),
            model_id: "test-70b-reference".to_string(),
            reference_kind: ProviderReferenceKind::LocalFp16Replay,
            evidence_scope: scope,
            artifact_ref,
            artifact_sha256: sha256_hex(reference_bytes),
            prompt_suite_id: "test_suite".to_string(),
            prompt_suite_artifact_ref,
            prompt_suite_artifact_sha256: sha256_hex(prompt_suite_bytes),
            request_id_hash: None,
            redaction_digest: None,
            data_sent_class: ReferenceDataSentClass::LocalOnly,
            retention_claim: ReferenceRetentionClaim::LocalFileOnly,
            replay_allowed: true,
            prompt_count,
            notes: "test fixture".to_string(),
        };
        let manifest_path = root.join("provider_reference.json");
        std::fs::write(
            &manifest_path,
            serde_json::to_vec_pretty(&manifest).unwrap(),
        )
        .unwrap();
        manifest_path.display().to_string()
    }

    #[test]
    fn missing_model_is_first_bottleneck() {
        assert_eq!(
            choose_primary_bottleneck(false, false, false, false, false, false),
            "missing_local_70b_model_weights"
        );
    }

    #[test]
    fn readiness_order_reaches_sparse_runtime_last() {
        assert_eq!(
            choose_primary_bottleneck(true, true, true, true, true, false),
            "missing_sparse_70b_runtime"
        );
        assert_eq!(
            choose_primary_bottleneck(true, true, true, true, true, true),
            "ready_for_prompt_level_measurement"
        );
    }

    #[test]
    fn range_hash_dry_run_is_required_before_residency_plan() {
        assert_eq!(
            choose_primary_bottleneck(true, false, true, true, true, true),
            "missing_weight_block_range_hash_dry_run"
        );
    }

    #[test]
    fn residency_plan_dry_run_is_required_before_reference() {
        assert_eq!(
            choose_primary_bottleneck(true, true, false, false, false, false),
            "missing_residency_plan_dry_run"
        );
    }

    #[test]
    fn provider_reference_requires_replayable_manifest_shape() {
        let missing = provider_reference_status(Some("/definitely/not/a/provider-ref.json"));
        assert!(!missing.prompt_level_available);
        assert!(!missing.manifest_valid);
        assert_eq!(missing.label, "path_missing");
        let temp = tempfile::tempdir().unwrap();
        let unset = provider_reference_status_at(None, temp.path());
        assert!(!unset.prompt_level_available);
        assert!(!unset.manifest_valid);
        assert_eq!(unset.label, "env_unset");
    }

    #[test]
    fn provider_reference_uses_retained_shape_fixture_when_env_is_unset() {
        let temp = tempfile::tempdir().unwrap();
        let manifest_path = write_provider_reference_fixture(
            temp.path(),
            ReferenceEvidenceScope::ShapeOnlyFixture,
            1,
            true,
        );
        let retained_manifest_path = temp.path().join(
            "artifacts/falsifiers/70b_local_cocktail_lite/provider_reference_manifest_dry_run/shape_only_manifest.json",
        );
        std::fs::create_dir_all(retained_manifest_path.parent().unwrap()).unwrap();
        std::fs::rename(manifest_path, retained_manifest_path).unwrap();

        let status = provider_reference_status_at(None, temp.path());

        assert!(status.manifest_valid);
        assert!(status.replay_files_valid);
        assert!(!status.prompt_level_available);
        assert_eq!(status.label, "shape_only_manifest");
    }

    #[test]
    fn prompt_level_reference_requires_replay_files() {
        let temp = tempfile::tempdir().unwrap();
        let manifest_path = write_provider_reference_fixture(
            temp.path(),
            ReferenceEvidenceScope::PromptLevelComparison,
            50,
            false,
        );
        let status = provider_reference_status_at(Some(&manifest_path), temp.path());

        assert!(status.manifest_valid);
        assert!(!status.replay_files_valid);
        assert!(!status.prompt_level_available);
        assert!(status
            .label
            .starts_with("prompt_level_replay_files_invalid:"));
    }

    #[test]
    fn prompt_level_reference_with_retained_replay_files_can_advance_reference_gate() {
        let temp = tempfile::tempdir().unwrap();
        let manifest_path = write_provider_reference_fixture(
            temp.path(),
            ReferenceEvidenceScope::PromptLevelComparison,
            50,
            true,
        );
        let status = provider_reference_status_at(Some(&manifest_path), temp.path());

        assert!(status.manifest_valid);
        assert!(status.replay_files_valid);
        assert!(status.prompt_level_available);
        assert_eq!(status.label, "prompt_level_replayable_manifest");
    }

    #[test]
    fn shape_only_reference_keeps_reference_gate_closed_even_with_replay_files() {
        let temp = tempfile::tempdir().unwrap();
        let manifest_path = write_provider_reference_fixture(
            temp.path(),
            ReferenceEvidenceScope::ShapeOnlyFixture,
            1,
            true,
        );
        let status = provider_reference_status_at(Some(&manifest_path), temp.path());

        assert!(status.manifest_valid);
        assert!(status.replay_files_valid);
        assert!(!status.prompt_level_available);
        assert_eq!(status.label, "shape_only_manifest");
    }

    #[test]
    fn preflight_artifact_never_accidentally_passes_today() {
        let report = build_report();
        assert!(!report.artifact.overall_pass);
        assert_eq!(report.artifact.falsifier_id, FALSIFIER_ID);
        assert_eq!(report.artifact.artifact_kind, "failure_report");
        assert_eq!(report.artifact.fallback_tier, "Fail");
        for axis in [
            "d_kl_nats",
            "decode_tok_s",
            "ttft_seconds",
            "resident_memory_gb",
            "bottleneck_identified",
            "provider_reference_manifest_valid",
            "provider_reference_replay_files_valid",
            "weight_block_range_hash_dry_run_available",
            "uas_acs_mmap_residency_artifact_available",
            "sparse_runtime_split_artifact_available",
            "synthetic_ir_chart_coverage_available",
            "eml_geometry_scan_chart_coverage_available",
        ] {
            assert!(report.artifact.measurements.contains_key(axis));
            assert!(report.artifact.acceptance_thresholds.contains_key(axis));
            assert!(report.artifact.pass_per_axis.contains_key(axis));
        }
    }
}
