//! Architecture Pending Work Guard.
//!
//! This is the pre-loop duplicate-work check for the Capability Ceiling queue.
//! It reads the executable route queue plus the KV-Direct full-suite plan and
//! emits one artifact that answers:
//! "what is already mapped, what is partially done, and what exact work should
//! continue next without rebuilding something twice?"

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind,
    FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-Architecture-Pending-Work-Guard";
const FIXTURE_ID: &str = "capability_ceiling_pending_work_dedup_v1";
const COMMAND: &str = "Tools/falsifiers/f_architecture_pending_work_guard.sh";
const OUTPUT: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";

const CAPABILITY_KERNEL_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const KV_PROMPT_SUITE_PATH: &str = "artifacts/falsifiers/kv_direct_gate/prompt_suite.json";
const KV_FULL_SUITE_PLAN_PATH: &str =
    "artifacts/falsifiers/kv_direct_gate/live_mlx_full_suite_plan/full_suite_run_plan.json";
const KV_SMOKE_DIR: &str = "artifacts/falsifiers/kv_direct_gate/live_mlx";
const KV_MERGED_DIR: &str = "artifacts/falsifiers/kv_direct_gate/live_mlx_merged";
const KV_DIRECT_RESULT_PATH: &str = "artifacts/falsifiers/kv_direct_gate/result.json";
const WEIGHT_BLOCK_RANGE_HASH_DRY_RUN_PATH: &str =
    "artifacts/falsifiers/weight_block_range_hash_dry_run/result.json";
const RESIDENCY_PLAN_DRY_RUN_PATH: &str = "artifacts/falsifiers/residency_plan_dry_run/result.json";
const PROVIDER_REFERENCE_MANIFEST_DRY_RUN_PATH: &str =
    "artifacts/falsifiers/provider_reference_manifest_dry_run/result.json";
const LOCAL_70B_COCKTAIL_PATH: &str = "artifacts/falsifiers/70b_local_cocktail_lite/result.json";
const QWEN3_8B_128K_GGUF_ROUTE_PATH: &str =
    "artifacts/falsifiers/qwen3_8b_128k_gguf_route/result.json";
const QWEN3_8B_128K_GGUF_BENCH_RUNNER_PATH: &str =
    "Tools/falsifiers/run_qwen3_8b_128k_gguf_bench.py";
const LOCAL_WORKTREE_INVENTORY_PATH: &str =
    "docs/audits/LOCAL_EPISTEMOS_WORKTREE_INVENTORY_2026_05_28.json";
const KV_MODEL_CONTEXT_INVENTORY_PATH: &str =
    "docs/audits/KV_DIRECT_MODEL_CONTEXT_INVENTORY_2026_05_28.json";

const CONTRACT_FILES: [&str; 5] = [
    "manifest.json",
    "reference_logits.json",
    "test_logits.json",
    "metrics.json",
    "spill_trace.json",
];

fn main() {
    let report = build_report();
    let path = PathBuf::from(OUTPUT);
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).expect("create architecture pending guard directory");
    }
    let mut file = std::fs::File::create(&path).expect("open architecture pending guard artifact");
    write_artifact(&mut file, &report.artifact).expect("write architecture pending guard artifact");

    println!(
        "Architecture Pending Work Guard: overall_pass={} next_existing_work={} duplicate_risk_count={} artifact={}",
        report.artifact.overall_pass,
        report.next_existing_work,
        report.duplicate_risk_count,
        path.display()
    );

    if !report.artifact.overall_pass {
        std::process::exit(1);
    }
}

struct GuardReport {
    artifact: agent_core::falsifier_artifacts::FalsifierArtifact,
    next_existing_work: String,
    duplicate_risk_count: u64,
}

fn build_report() -> GuardReport {
    let capability = read_json(Path::new(CAPABILITY_KERNEL_PATH));
    let queue_items = capability
        .as_ref()
        .and_then(extract_queue_items)
        .unwrap_or_default();
    let queue_summary = summarize_queue(&queue_items);
    let plan = read_json(Path::new(KV_FULL_SUITE_PLAN_PATH));
    let plan_summary = plan
        .as_ref()
        .map(summarize_kv_plan)
        .unwrap_or_else(KvPlanSummary::missing);
    let shard_summary = plan.as_ref().map(summarize_shards).unwrap_or_default();
    let merged_summary = contract_dir_status(Path::new(KV_MERGED_DIR));
    let smoke_summary = contract_dir_status(Path::new(KV_SMOKE_DIR));
    let worktree_inventory = read_json(Path::new(LOCAL_WORKTREE_INVENTORY_PATH));
    let worktree_summary = worktree_inventory
        .as_ref()
        .map(summarize_worktree_inventory)
        .unwrap_or_default();
    let model_context_inventory = read_json(Path::new(KV_MODEL_CONTEXT_INVENTORY_PATH));
    let model_context_summary = model_context_inventory
        .as_ref()
        .map(summarize_model_context_inventory)
        .unwrap_or_default();
    let next_bottleneck = capability
        .as_ref()
        .and_then(|v| measurement_string(v, "next_bottleneck"))
        .unwrap_or_else(|| "missing_capability_kernel_next_bottleneck".to_string());
    let kv_result = read_json(Path::new(KV_DIRECT_RESULT_PATH));
    let qwen3_gguf_route = read_json(Path::new(QWEN3_8B_128K_GGUF_ROUTE_PATH));
    let weight_block_range_hash_dry_run =
        read_json(Path::new(WEIGHT_BLOCK_RANGE_HASH_DRY_RUN_PATH));
    let weight_block_range_hash_dry_run_available = artifact_all_axes_true(
        &weight_block_range_hash_dry_run,
        &[
            "bounded_range_hashed",
            "range_len_bytes",
            "over_limit_rejected_before_read",
            "short_reader_rejected",
            "known_hash_manifest_valid",
            "no_model_file_touched",
        ],
    );
    let residency_plan_dry_run = read_json(Path::new(RESIDENCY_PLAN_DRY_RUN_PATH));
    let residency_plan_dry_run_available = artifact_all_axes_true(
        &residency_plan_dry_run,
        &[
            "fit_for_dry_run",
            "deterministic_plan_address",
            "runtime_model_bytes_loaded",
            "missing_rollback_rejected",
            "overlapping_ranges_rejected",
            "sherry_and_leech_codec_names_present",
        ],
    );
    let provider_reference_manifest_dry_run =
        read_json(Path::new(PROVIDER_REFERENCE_MANIFEST_DRY_RUN_PATH));
    let provider_reference_manifest_dry_run_available = artifact_all_axes_true(
        &provider_reference_manifest_dry_run,
        &[
            "shape_fixture_written",
            "manifest_valid",
            "prompt_level_reference",
            "does_not_advance_70b_reference_gate",
            "row_root_path",
            "digest_matches_sidecar",
            "prompt_suite_bound",
            "no_provider_call",
        ],
    );
    let local_70b_cocktail = read_json(Path::new(LOCAL_70B_COCKTAIL_PATH));
    let local_70b_cocktail_honest_red = local_70b_cocktail.as_ref().is_some_and(|value| {
        !artifact_overall_pass_value(value)
            && measurement_string_value(value, "primary_bottleneck").as_deref()
                == Some("missing_fp16_or_provider_reference")
            && artifact_axis_true_value(value, "weight_block_range_hash_dry_run_available")
            && artifact_axis_true_value(value, "residency_plan_dry_run_available")
            && !artifact_axis_true_value(value, "provider_reference_available")
    });
    let heavy_long_context_guard_present =
        std::fs::read_to_string(QWEN3_8B_128K_GGUF_BENCH_RUNNER_PATH)
            .map(|source| {
                source.contains("EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT")
                    && source.contains("SAFE_CONTEXT_TOKENS")
                    && source.contains("refusing >")
            })
            .unwrap_or(false);
    let qwen3_gguf_next_bottleneck = qwen3_gguf_route
        .as_ref()
        .and_then(|v| measurement_string(v, "next_bottleneck"))
        .unwrap_or_else(|| "missing_qwen3_8b_128k_gguf_candidate_artifact".to_string());
    let kv_fixture_logits_available = kv_result
        .as_ref()
        .and_then(|v| v.get("pass_per_axis"))
        .and_then(|axes| axes.get("reference_logits_available"))
        .and_then(|v| v.as_bool())
        .unwrap_or(false)
        && kv_result
            .as_ref()
            .and_then(|v| v.get("pass_per_axis"))
            .and_then(|axes| axes.get("test_logits_available"))
            .and_then(|v| v.as_bool())
            .unwrap_or(false);

    let next_existing_work = derive_next_existing_work(
        Path::new(KV_PROMPT_SUITE_PATH).exists(),
        plan_summary.available,
        &shard_summary,
        &merged_summary,
        kv_fixture_logits_available,
        &next_bottleneck,
        qwen3_gguf_route.is_some(),
        &qwen3_gguf_next_bottleneck,
    );
    let duplicate_risk_count = queue_summary.duplicate_gap_ids
        + queue_summary.duplicate_orders
        + plan_summary.duplicate_prompt_ids
        + plan_summary.duplicate_output_dirs;
    let required_state_present = capability.is_some()
        && !queue_items.is_empty()
        && Path::new(KV_PROMPT_SUITE_PATH).exists()
        && plan_summary.available
        && qwen3_gguf_route.is_some()
        && weight_block_range_hash_dry_run_available
        && residency_plan_dry_run_available
        && provider_reference_manifest_dry_run_available
        && local_70b_cocktail_honest_red
        && heavy_long_context_guard_present
        && worktree_inventory.is_some()
        && model_context_inventory.is_some()
        && next_existing_work != "unset";
    let no_duplicate_risk = duplicate_risk_count == 0;
    let plan_shape_ok = plan_summary.shape_ok;
    let shard_cursor_ok = shard_summary.total > 0 || !plan_summary.available;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "capability_kernel_artifact_available",
        capability.is_some(),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "ordered_queue_available",
        !queue_items.is_empty(),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "queue_gap_ids_unique",
        queue_summary.duplicate_gap_ids == 0,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "queue_orders_unique",
        queue_summary.duplicate_orders == 0,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "queue_required_fields_present",
        queue_summary.missing_required_fields == 0,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_prompt_suite_available",
        Path::new(KV_PROMPT_SUITE_PATH).exists(),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_full_suite_run_plan_available",
        plan_summary.available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_full_suite_run_plan_shape_ok",
        plan_shape_ok,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_plan_prompt_ids_unique",
        plan_summary.duplicate_prompt_ids == 0,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_plan_output_dirs_unique",
        plan_summary.duplicate_output_dirs == 0,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "qwen3_8b_128k_gguf_candidate_artifact_available",
        qwen3_gguf_route.is_some(),
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
        "provider_reference_manifest_dry_run_available",
        provider_reference_manifest_dry_run_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "local_70b_cocktail_honest_red",
        local_70b_cocktail_honest_red,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "heavy_long_context_guard_present",
        heavy_long_context_guard_present,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "local_worktree_inventory_available",
        worktree_inventory.is_some(),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "local_worktree_inventory_non_destructive",
        worktree_inventory
            .as_ref()
            .and_then(|v| v.get("non_destructive"))
            .and_then(|v| v.as_bool())
            .unwrap_or(false),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "local_worktree_current_repo_present",
        worktree_summary.current_repo_present,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_model_context_inventory_available",
        model_context_inventory.is_some(),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_model_context_inventory_non_destructive",
        model_context_inventory
            .as_ref()
            .and_then(|v| v.get("non_destructive"))
            .and_then(|v| v.as_bool())
            .unwrap_or(false),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "pending_work_cursor_available",
        required_state_present,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_duplicate_rebuild_risk",
        no_duplicate_risk,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "shard_cursor_mapped",
        shard_cursor_ok,
    );

    add_count_measurement(&mut measurements, "queue_item_count", queue_summary.total);
    add_count_measurement(
        &mut measurements,
        "queue_pending_item_count",
        queue_summary.pending,
    );
    add_count_measurement(
        &mut measurements,
        "queue_duplicate_gap_id_count",
        queue_summary.duplicate_gap_ids,
    );
    add_count_measurement(
        &mut measurements,
        "queue_duplicate_order_count",
        queue_summary.duplicate_orders,
    );
    add_count_measurement(
        &mut measurements,
        "queue_missing_required_field_count",
        queue_summary.missing_required_fields,
    );
    add_count_measurement(
        &mut measurements,
        "kv_plan_duplicate_prompt_id_count",
        plan_summary.duplicate_prompt_ids,
    );
    add_count_measurement(
        &mut measurements,
        "kv_plan_duplicate_output_dir_count",
        plan_summary.duplicate_output_dirs,
    );
    add_count_measurement(
        &mut measurements,
        "kv_plan_shard_count",
        shard_summary.total,
    );
    add_count_measurement(
        &mut measurements,
        "kv_complete_shard_count",
        shard_summary.complete,
    );
    add_count_measurement(
        &mut measurements,
        "kv_partial_shard_count",
        shard_summary.partial,
    );
    add_count_measurement(
        &mut measurements,
        "kv_failed_shard_count",
        shard_summary.failed,
    );
    add_count_measurement(
        &mut measurements,
        "kv_missing_shard_count",
        shard_summary.missing,
    );
    add_count_measurement(
        &mut measurements,
        "local_epistemos_candidate_count",
        worktree_summary.candidate_count,
    );
    add_count_measurement(
        &mut measurements,
        "local_sibling_worktree_count",
        worktree_summary.sibling_worktree_count,
    );
    add_count_measurement(
        &mut measurements,
        "local_dirty_candidate_count",
        worktree_summary.dirty_candidate_count,
    );
    add_count_measurement(
        &mut measurements,
        "local_high_duplicate_risk_count",
        worktree_summary.high_duplicate_risk_count,
    );
    add_count_measurement(
        &mut measurements,
        "kv_model_context_required_candidate_count",
        model_context_summary.required_context_candidate_count,
    );
    add_count_measurement(
        &mut measurements,
        "kv_model_context_required_text_candidate_count",
        model_context_summary.required_context_text_model_candidate_count,
    );
    add_label(
        &mut measurements,
        "kv_model_context_best_candidate_repo_id",
        &model_context_summary.best_required_context_candidate_repo_id,
    );
    add_bool_measurement(
        &mut measurements,
        "kv_model_context_canonical_context_ok",
        model_context_summary.canonical_context_ok,
    );
    add_label(
        &mut measurements,
        "qwen3_8b_128k_gguf_next_bottleneck",
        &qwen3_gguf_next_bottleneck,
    );
    add_label(&mut measurements, "next_bottleneck", &next_bottleneck);
    add_label(&mut measurements, "next_existing_work", &next_existing_work);
    add_label(
        &mut measurements,
        "first_incomplete_shard",
        shard_summary.first_incomplete.as_deref().unwrap_or("none"),
    );
    add_label(
        &mut measurements,
        "first_incomplete_shard_status",
        shard_summary
            .first_incomplete_status
            .as_deref()
            .unwrap_or("none"),
    );
    add_json_measurement(
        &mut measurements,
        "already_mapped_work",
        serde_json::json!({
            "kv_prompt_suite": {
                "path": KV_PROMPT_SUITE_PATH,
                "exists": Path::new(KV_PROMPT_SUITE_PATH).exists()
            },
            "kv_full_suite_plan": {
                "path": KV_FULL_SUITE_PLAN_PATH,
                "exists": plan_summary.available,
                "falsifier_green_capable": plan_summary.falsifier_green_capable
            },
            "kv_smoke_contract_dir": {
                "path": KV_SMOKE_DIR,
                "status": smoke_summary.status_label()
            },
            "kv_merged_contract_dir": {
                "path": KV_MERGED_DIR,
                "status": merged_summary.status_label()
            },
            "local_worktree_inventory": {
                "path": LOCAL_WORKTREE_INVENTORY_PATH,
                "exists": worktree_inventory.is_some(),
                "candidate_count": worktree_summary.candidate_count,
                "high_duplicate_risk_count": worktree_summary.high_duplicate_risk_count
            },
            "kv_model_context_inventory": {
                "path": KV_MODEL_CONTEXT_INVENTORY_PATH,
                "exists": model_context_inventory.is_some(),
                "canonical_context_ok": model_context_summary.canonical_context_ok,
                "required_text_candidate_count": model_context_summary.required_context_text_model_candidate_count,
                "best_required_context_candidate_repo_id": model_context_summary.best_required_context_candidate_repo_id
            },
            "qwen3_8b_128k_gguf_candidate_route": {
                "path": QWEN3_8B_128K_GGUF_ROUTE_PATH,
                "exists": qwen3_gguf_route.is_some(),
                "heavy_run_guard_path": QWEN3_8B_128K_GGUF_BENCH_RUNNER_PATH,
                "heavy_long_context_guard_present": heavy_long_context_guard_present,
                "next_bottleneck": qwen3_gguf_next_bottleneck
            },
            "large_model_non_runtime_rungs": {
                "weight_block_range_hash_dry_run": {
                    "path": WEIGHT_BLOCK_RANGE_HASH_DRY_RUN_PATH,
                    "available": weight_block_range_hash_dry_run_available
                },
                "residency_plan_dry_run": {
                    "path": RESIDENCY_PLAN_DRY_RUN_PATH,
                    "available": residency_plan_dry_run_available
                },
                "provider_reference_manifest_dry_run": {
                    "path": PROVIDER_REFERENCE_MANIFEST_DRY_RUN_PATH,
                    "available": provider_reference_manifest_dry_run_available
                },
                "local_70b_cocktail_preflight": {
                    "path": LOCAL_70B_COCKTAIL_PATH,
                    "honest_red": local_70b_cocktail_honest_red,
                    "primary_bottleneck": local_70b_cocktail
                        .as_ref()
                        .and_then(|value| measurement_string_value(value, "primary_bottleneck"))
                        .unwrap_or_else(|| "missing_70b_preflight_artifact".to_string())
                }
            }
        }),
    );
    add_json_measurement(
        &mut measurements,
        "incomplete_shards",
        serde_json::Value::Array(
            shard_summary
                .incomplete_shards
                .iter()
                .map(|shard| serde_json::Value::String(shard.clone()))
                .collect(),
        ),
    );
    add_json_measurement(
        &mut measurements,
        "failed_shards",
        serde_json::Value::Array(
            shard_summary
                .failed_shards
                .iter()
                .map(|shard| serde_json::Value::String(shard.clone()))
                .collect(),
        ),
    );

    let mut anomalies = Vec::new();
    if !required_state_present {
        anomalies.push(serde_json::json!({
            "kind": "missing_pending_work_cursor",
            "detail": "The loop cannot safely continue without the capability kernel artifact, ordered queue, prompt suite, full-suite plan, and next-existing-work cursor."
        }));
    }
    if !no_duplicate_risk {
        anomalies.push(serde_json::json!({
            "kind": "duplicate_work_risk",
            "detail": format!("duplicate_risk_count={duplicate_risk_count}; inspect queue gap/order ids and KV plan prompt/output-dir ids before implementing.")
        }));
    }
    if plan_summary.available && !plan_summary.falsifier_green_capable {
        anomalies.push(serde_json::json!({
            "kind": "mapped_nonpromoting_kv_route",
            "detail": "The current full-suite plan is useful continuation work, but it is still prompt_cache_reload development evidence and cannot promote F-KV-Direct-Gate."
        }));
    }
    if !heavy_long_context_guard_present {
        anomalies.push(serde_json::json!({
            "kind": "missing_heavy_long_context_guard",
            "detail": "Long-context GGUF probes above the known-safe envelope must require EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT=1 so the loop cannot accidentally repeat a watchdog-triggering Metal stall."
        }));
    }
    if !weight_block_range_hash_dry_run_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_weight_block_range_hash_dry_run",
            "detail": "Large-model construction must prove bounded byte-range fingerprinting before trusting SSD-backed model byte ranges."
        }));
    }
    if !residency_plan_dry_run_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_residency_plan_dry_run",
            "detail": "Large-model construction must prove the active set fits the 16 GB floor before any runtime probe."
        }));
    }
    if !provider_reference_manifest_dry_run_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_provider_reference_manifest_dry_run",
            "detail": "70B reference evidence must have a digest-bound manifest ABI before prompt-level comparisons can be trusted."
        }));
    }
    if !local_70b_cocktail_honest_red {
        anomalies.push(serde_json::json!({
            "kind": "missing_honest_70b_preflight_red_artifact",
            "detail": "The 70B preflight should remain red on missing prompt-level reference/runtime evidence while the safe metadata gates are green."
        }));
    }
    if worktree_summary.high_duplicate_risk_count > 0 {
        anomalies.push(serde_json::json!({
            "kind": "local_worktree_sprawl",
            "detail": format!("{} high duplicate-risk Epistemos sibling/copy surfaces are present under Downloads; inspect docs/audits/LOCAL_EPISTEMOS_WORKTREE_INVENTORY_2026_05_28.json before opening more worktrees.", worktree_summary.high_duplicate_risk_count)
        }));
    }
    if shard_summary.partial > 0 {
        anomalies.push(serde_json::json!({
            "kind": "partial_kv_shard_outputs",
            "detail": "At least one KV shard output directory is partial; repair or rerun that shard before starting a later shard."
        }));
    }
    if shard_summary.failed > 0 {
        anomalies.push(serde_json::json!({
            "kind": "failed_kv_shard_outputs",
            "detail": "At least one KV shard recorded failed progress; repair the runtime bottleneck before rerunning the same shard."
        }));
    }
    if model_context_inventory.is_some()
        && !model_context_summary.canonical_context_ok
        && model_context_summary.required_context_text_model_candidate_count > 0
    {
        anomalies.push(serde_json::json!({
            "kind": "alternate_128k_model_candidates_available",
            "detail": format!(
                "Canonical Qwen3-8B 128K context is not satisfied, but {} local text-generation candidates meet the context floor. Best candidate: {}. Treat alternates as development evidence unless canon explicitly changes the F-KV-Direct-Gate model.",
                model_context_summary.required_context_text_model_candidate_count,
                model_context_summary.best_required_context_candidate_repo_id
            )
        }));
    }
    if matches!(
        next_bottleneck.as_str(),
        "resolve_qwen3_8b_128k_context_model_assets_for_kv_direct"
    ) && qwen3_gguf_route.is_some()
        && next_existing_work == qwen3_gguf_next_bottleneck
    {
        anomalies.push(serde_json::json!({
            "kind": "canonical_mlx_context_redirected_to_existing_candidate_split",
            "detail": format!(
                "The canonical MLX KV gate remains context-red, so the loop continues the already-mapped GGUF candidate split at `{qwen3_gguf_next_bottleneck}` instead of recreating KV prompt/shard work."
            )
        }));
    }

    let notes = format!(
        "pending_work_guard; next_existing_work={next_existing_work}; \
         do not recreate prompt suite or shard plan while their artifacts exist; \
         continue the first incomplete shard or merge/feed existing shards before building new surfaces"
    );
    let artifact = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: if required_state_present && no_duplicate_risk {
            ArtifactKind::PrimaryWitness
        } else {
            ArtifactKind::FailureReport
        },
        command: COMMAND.to_string(),
        commit_sha: agent_core::falsifier_artifacts::current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: if required_state_present && no_duplicate_risk {
            FallbackTier::Primary
        } else {
            FallbackTier::Fail
        },
        anomalies,
        notes,
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    GuardReport {
        artifact,
        next_existing_work,
        duplicate_risk_count,
    }
}

#[derive(Debug, Clone, Default)]
struct QueueItem {
    order: Option<u64>,
    gap_id: Option<String>,
    status: Option<String>,
    witness: Option<String>,
    falsifier_or_gate: Option<String>,
}

#[derive(Debug, Clone, Default)]
struct QueueSummary {
    total: u64,
    pending: u64,
    duplicate_gap_ids: u64,
    duplicate_orders: u64,
    missing_required_fields: u64,
}

#[derive(Debug, Clone)]
struct KvPlanSummary {
    available: bool,
    shape_ok: bool,
    falsifier_green_capable: bool,
    duplicate_prompt_ids: u64,
    duplicate_output_dirs: u64,
}

impl KvPlanSummary {
    fn missing() -> Self {
        Self {
            available: false,
            shape_ok: false,
            falsifier_green_capable: false,
            duplicate_prompt_ids: 0,
            duplicate_output_dirs: 0,
        }
    }
}

#[derive(Debug, Clone, Default)]
struct ShardSummary {
    total: u64,
    complete: u64,
    partial: u64,
    failed: u64,
    missing: u64,
    first_incomplete: Option<String>,
    first_incomplete_status: Option<String>,
    incomplete_shards: Vec<String>,
    failed_shards: Vec<String>,
}

#[derive(Debug, Clone, Default)]
struct WorktreeSummary {
    candidate_count: u64,
    sibling_worktree_count: u64,
    dirty_candidate_count: u64,
    high_duplicate_risk_count: u64,
    current_repo_present: bool,
}

#[derive(Debug, Clone, Default)]
struct ModelContextInventorySummary {
    required_context_candidate_count: u64,
    required_context_text_model_candidate_count: u64,
    canonical_context_ok: bool,
    best_required_context_candidate_repo_id: String,
}

#[derive(Debug, Clone, Copy, Eq, PartialEq)]
enum ContractStatus {
    Missing,
    Partial,
    Complete,
}

impl ContractStatus {
    fn status_label(self) -> &'static str {
        match self {
            Self::Missing => "missing",
            Self::Partial => "partial",
            Self::Complete => "complete",
        }
    }
}

fn extract_queue_items(value: &serde_json::Value) -> Option<Vec<QueueItem>> {
    let queue = value
        .get("measurements")?
        .get("ordered_build_queue")?
        .get("value")?
        .as_array()?;
    Some(
        queue
            .iter()
            .map(|item| QueueItem {
                order: item.get("order").and_then(|v| v.as_u64()),
                gap_id: item
                    .get("gap_id")
                    .and_then(|v| v.as_str())
                    .map(ToString::to_string),
                status: item
                    .get("status")
                    .and_then(|v| v.as_str())
                    .map(ToString::to_string),
                witness: item
                    .get("witness")
                    .and_then(|v| v.as_str())
                    .map(ToString::to_string),
                falsifier_or_gate: item
                    .get("falsifier_or_gate")
                    .and_then(|v| v.as_str())
                    .map(ToString::to_string),
            })
            .collect(),
    )
}

fn summarize_queue(items: &[QueueItem]) -> QueueSummary {
    let mut gap_ids = BTreeSet::new();
    let mut orders = BTreeSet::new();
    let mut duplicate_gap_ids = 0;
    let mut duplicate_orders = 0;
    let mut missing_required_fields = 0;
    let mut pending = 0;

    for item in items {
        match item.gap_id.as_deref() {
            Some(gap_id) if !gap_id.is_empty() => {
                if !gap_ids.insert(gap_id.to_string()) {
                    duplicate_gap_ids += 1;
                }
            }
            _ => missing_required_fields += 1,
        }
        match item.order {
            Some(order) => {
                if !orders.insert(order) {
                    duplicate_orders += 1;
                }
            }
            None => missing_required_fields += 1,
        }
        if item.status.as_deref().unwrap_or("").is_empty()
            || item.witness.as_deref().unwrap_or("").is_empty()
            || item.falsifier_or_gate.as_deref().unwrap_or("").is_empty()
        {
            missing_required_fields += 1;
        }
        if item.status.as_deref() != Some("completed") {
            pending += 1;
        }
    }

    QueueSummary {
        total: items.len() as u64,
        pending,
        duplicate_gap_ids,
        duplicate_orders,
        missing_required_fields,
    }
}

fn summarize_kv_plan(value: &serde_json::Value) -> KvPlanSummary {
    let prompt_count = value
        .get("prompt_count")
        .and_then(|v| v.as_u64())
        .unwrap_or_default();
    let target_context = value
        .get("target_context_tokens")
        .and_then(|v| v.as_u64())
        .unwrap_or_default();
    let decode_tokens = value
        .get("decode_tokens_per_prompt")
        .and_then(|v| v.as_u64())
        .unwrap_or_default();
    let shards = value
        .get("shards")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    let shard_count = value
        .get("shard_count")
        .and_then(|v| v.as_u64())
        .unwrap_or_default();
    let mut prompt_ids = BTreeSet::new();
    let mut output_dirs = BTreeSet::new();
    let mut duplicate_prompt_ids = 0;
    let mut duplicate_output_dirs = 0;
    let mut command_shape_ok = true;

    for shard in &shards {
        let prompt_id_values = shard
            .get("prompt_ids")
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default();
        for prompt_id in prompt_id_values {
            let prompt_id = prompt_id.as_str().unwrap_or("").to_string();
            if prompt_id.is_empty() || !prompt_ids.insert(prompt_id) {
                duplicate_prompt_ids += 1;
            }
        }
        let output_dir = shard
            .get("output_dir")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        if output_dir.is_empty() || !output_dirs.insert(output_dir) {
            duplicate_output_dirs += 1;
        }
        let command = shard
            .get("run_command")
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default();
        command_shape_ok = command_shape_ok
            && command
                .iter()
                .any(|arg| arg.as_str() == Some("--allow-full-suite"))
            && command
                .iter()
                .any(|arg| arg.as_str() == Some("--prompt-offset"))
            && command
                .iter()
                .any(|arg| arg.as_str() == Some("--max-prompts"));
    }

    let shape_ok = prompt_count >= 100
        && target_context >= 128_000
        && decode_tokens >= 256
        && shard_count > 0
        && shard_count as usize == shards.len()
        && prompt_ids.len() as u64 == prompt_count
        && command_shape_ok;

    KvPlanSummary {
        available: true,
        shape_ok,
        falsifier_green_capable: value
            .get("falsifier_green_capable")
            .and_then(|v| v.as_bool())
            .unwrap_or(false),
        duplicate_prompt_ids,
        duplicate_output_dirs,
    }
}

fn summarize_shards(plan: &serde_json::Value) -> ShardSummary {
    let shards = plan
        .get("shards")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    let mut summary = ShardSummary {
        total: shards.len() as u64,
        ..ShardSummary::default()
    };

    for shard in shards {
        let shard_id = shard
            .get("shard_id")
            .and_then(|v| v.as_str())
            .unwrap_or("unknown_shard")
            .to_string();
        let output_dir = shard
            .get("output_dir")
            .and_then(|v| v.as_str())
            .map(PathBuf::from);
        let status = output_dir
            .as_deref()
            .map(contract_dir_status)
            .unwrap_or(ContractStatus::Missing);
        let progress_status = output_dir
            .as_deref()
            .and_then(progress_status)
            .unwrap_or_else(|| "unset".to_string());
        let is_failed = progress_status == "failed";
        match status {
            ContractStatus::Complete if !is_failed => summary.complete += 1,
            ContractStatus::Partial => {
                summary.partial += 1;
                if is_failed {
                    summary.failed += 1;
                    summary.failed_shards.push(shard_id.clone());
                }
                summary.incomplete_shards.push(shard_id.clone());
                if summary.first_incomplete.is_none() {
                    summary.first_incomplete = Some(shard_id);
                    summary.first_incomplete_status = Some(if is_failed {
                        "failed".to_string()
                    } else {
                        "partial".to_string()
                    });
                }
            }
            ContractStatus::Complete => {
                summary.partial += 1;
                summary.failed += 1;
                summary.failed_shards.push(shard_id.clone());
                summary.incomplete_shards.push(shard_id.clone());
                if summary.first_incomplete.is_none() {
                    summary.first_incomplete = Some(shard_id);
                    summary.first_incomplete_status = Some("failed".to_string());
                }
            }
            ContractStatus::Missing => {
                summary.missing += 1;
                summary.incomplete_shards.push(shard_id.clone());
                if summary.first_incomplete.is_none() {
                    summary.first_incomplete = Some(shard_id);
                    summary.first_incomplete_status = Some("missing".to_string());
                }
            }
        }
    }
    summary
}

fn progress_status(dir: &Path) -> Option<String> {
    read_json(&dir.join("progress.json")).and_then(|value| {
        value
            .get("status")
            .and_then(|v| v.as_str())
            .map(ToString::to_string)
    })
}

fn summarize_worktree_inventory(value: &serde_json::Value) -> WorktreeSummary {
    let summary = value.get("summary").and_then(|v| v.as_object());
    let entries = value
        .get("entries")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    WorktreeSummary {
        candidate_count: summary
            .and_then(|s| s.get("candidate_count"))
            .and_then(|v| v.as_u64())
            .unwrap_or_default(),
        sibling_worktree_count: summary
            .and_then(|s| s.get("sibling_worktree_count"))
            .and_then(|v| v.as_u64())
            .unwrap_or_default(),
        dirty_candidate_count: summary
            .and_then(|s| s.get("dirty_candidate_count"))
            .and_then(|v| v.as_u64())
            .unwrap_or_default(),
        high_duplicate_risk_count: summary
            .and_then(|s| s.get("high_duplicate_risk_count"))
            .and_then(|v| v.as_u64())
            .unwrap_or_default(),
        current_repo_present: entries.iter().any(|entry| {
            entry
                .get("classification")
                .and_then(|v| v.as_str())
                .map(|classification| classification == "current_repo")
                .unwrap_or(false)
        }),
    }
}

fn summarize_model_context_inventory(value: &serde_json::Value) -> ModelContextInventorySummary {
    let summary = value.get("summary").and_then(|v| v.as_object());
    ModelContextInventorySummary {
        required_context_candidate_count: summary
            .and_then(|s| s.get("required_context_candidate_count"))
            .and_then(|v| v.as_u64())
            .unwrap_or_default(),
        required_context_text_model_candidate_count: summary
            .and_then(|s| s.get("required_context_text_model_candidate_count"))
            .and_then(|v| v.as_u64())
            .unwrap_or_default(),
        canonical_context_ok: summary
            .and_then(|s| s.get("canonical_context_ok"))
            .and_then(|v| v.as_bool())
            .unwrap_or(false),
        best_required_context_candidate_repo_id: summary
            .and_then(|s| s.get("best_required_context_candidate_repo_id"))
            .and_then(|v| v.as_str())
            .unwrap_or("none")
            .to_string(),
    }
}

fn contract_dir_status(dir: &Path) -> ContractStatus {
    let present = CONTRACT_FILES
        .iter()
        .filter(|file| dir.join(file).is_file())
        .count();
    if present == CONTRACT_FILES.len() {
        ContractStatus::Complete
    } else if present > 0 {
        ContractStatus::Partial
    } else {
        ContractStatus::Missing
    }
}

fn derive_next_existing_work(
    prompt_suite_exists: bool,
    plan_exists: bool,
    shards: &ShardSummary,
    merged: &ContractStatus,
    kv_fixture_logits_available: bool,
    next_bottleneck: &str,
    qwen3_gguf_route_exists: bool,
    qwen3_gguf_next_bottleneck: &str,
) -> String {
    if matches!(
        next_bottleneck,
        "resolve_qwen3_8b_mlx_model_assets_for_kv_direct"
    ) {
        return next_bottleneck.to_string();
    }
    if next_bottleneck == "resolve_qwen3_8b_128k_context_model_assets_for_kv_direct" {
        if qwen3_gguf_route_exists
            && !qwen3_gguf_next_bottleneck.is_empty()
            && qwen3_gguf_next_bottleneck != "missing_qwen3_8b_128k_gguf_candidate_artifact"
        {
            return qwen3_gguf_next_bottleneck.to_string();
        }
        return next_bottleneck.to_string();
    }
    if qwen3_gguf_route_exists
        && next_bottleneck == qwen3_gguf_next_bottleneck
        && !qwen3_gguf_next_bottleneck.is_empty()
    {
        return qwen3_gguf_next_bottleneck.to_string();
    }
    if !prompt_suite_exists {
        return "create_kv_direct_prompt_suite".to_string();
    }
    if !plan_exists {
        return "create_kv_direct_full_suite_run_plan".to_string();
    }
    if let Some(shard) = &shards.first_incomplete {
        if shards.first_incomplete_status.as_deref() == Some("failed") {
            return format!("repair_failed_kv_direct_shard:{shard}");
        }
        if shards.first_incomplete_status.as_deref() == Some("partial") {
            return format!("repair_partial_kv_direct_shard:{shard}");
        }
        return format!("continue_kv_direct_shard:{shard}");
    }
    if shards.total > 0 && *merged != ContractStatus::Complete {
        return "merge_completed_kv_direct_shards".to_string();
    }
    if *merged == ContractStatus::Complete && !kv_fixture_logits_available {
        return "feed_merged_kv_direct_bundle_to_falsifier".to_string();
    }
    next_bottleneck.to_string()
}

fn read_json(path: &Path) -> Option<serde_json::Value> {
    std::fs::read_to_string(path)
        .ok()
        .and_then(|s| serde_json::from_str::<serde_json::Value>(&s).ok())
}

fn artifact_all_axes_true(value: &Option<serde_json::Value>, axes: &[&str]) -> bool {
    value.as_ref().is_some_and(|artifact| {
        artifact_overall_pass_value(artifact)
            && axes
                .iter()
                .all(|axis| artifact_axis_true_value(artifact, axis))
    })
}

fn artifact_overall_pass_value(value: &serde_json::Value) -> bool {
    value
        .get("overall_pass")
        .and_then(|v| v.as_bool())
        .unwrap_or(false)
}

fn artifact_axis_true_value(value: &serde_json::Value, axis: &str) -> bool {
    value
        .get("pass_per_axis")
        .and_then(|axes| axes.get(axis))
        .and_then(|v| v.as_bool())
        .unwrap_or(false)
}

fn measurement_string_value(value: &serde_json::Value, key: &str) -> Option<String> {
    value
        .get("measurements")?
        .get(key)?
        .get("value")
        .or_else(|| value.get("measurements")?.get(key))?
        .as_str()
        .map(ToString::to_string)
}

fn measurement_string(value: &serde_json::Value, key: &str) -> Option<String> {
    measurement_string_value(value, key)
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

fn add_count_measurement(measurements: &mut BTreeMap<String, Measurement>, key: &str, value: u64) {
    measurements.insert(
        key.to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(value)),
            unit: "count".to_string(),
        },
    );
}

fn add_bool_measurement(measurements: &mut BTreeMap<String, Measurement>, key: &str, value: bool) {
    measurements.insert(
        key.to_string(),
        Measurement {
            value: serde_json::Value::Bool(value),
            unit: "bool".to_string(),
        },
    );
}

fn add_label(measurements: &mut BTreeMap<String, Measurement>, key: &str, value: &str) {
    measurements.insert(
        key.to_string(),
        Measurement {
            value: serde_json::Value::String(value.to_string()),
            unit: "label".to_string(),
        },
    );
}

fn add_json_measurement(
    measurements: &mut BTreeMap<String, Measurement>,
    key: &str,
    value: serde_json::Value,
) {
    measurements.insert(
        key.to_string(),
        Measurement {
            value,
            unit: "object".to_string(),
        },
    );
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn queue_summary_catches_duplicate_gap_ids() {
        let items = vec![
            QueueItem {
                order: Some(1),
                gap_id: Some("kv".to_string()),
                status: Some("completed".to_string()),
                witness: Some("a".to_string()),
                falsifier_or_gate: Some("F-A".to_string()),
            },
            QueueItem {
                order: Some(2),
                gap_id: Some("kv".to_string()),
                status: Some("pending".to_string()),
                witness: Some("b".to_string()),
                falsifier_or_gate: Some("F-B".to_string()),
            },
        ];
        let summary = summarize_queue(&items);
        assert_eq!(summary.total, 2);
        assert_eq!(summary.pending, 1);
        assert_eq!(summary.duplicate_gap_ids, 1);
        assert_eq!(summary.duplicate_orders, 0);
    }

    #[test]
    fn next_work_continues_first_incomplete_shard_before_merge() {
        let shards = ShardSummary {
            total: 4,
            complete: 0,
            partial: 0,
            failed: 0,
            missing: 4,
            first_incomplete: Some("shard_000_024".to_string()),
            first_incomplete_status: Some("missing".to_string()),
            incomplete_shards: vec!["shard_000_024".to_string()],
            failed_shards: vec![],
        };
        assert_eq!(
            derive_next_existing_work(
                true,
                true,
                &shards,
                &ContractStatus::Missing,
                false,
                "run_qwen3_8b_100_prompt_128k_reference_and_kv_direct_logits",
                false,
                "missing_qwen3_8b_128k_gguf_candidate_artifact",
            ),
            "continue_kv_direct_shard:shard_000_024"
        );
    }

    #[test]
    fn next_work_honors_model_context_bottleneck_before_failed_shard() {
        let shards = ShardSummary {
            total: 4,
            complete: 0,
            partial: 1,
            failed: 1,
            missing: 3,
            first_incomplete: Some("shard_000_000".to_string()),
            first_incomplete_status: Some("failed".to_string()),
            incomplete_shards: vec!["shard_000_000".to_string()],
            failed_shards: vec!["shard_000_000".to_string()],
        };
        assert_eq!(
            derive_next_existing_work(
                true,
                true,
                &shards,
                &ContractStatus::Missing,
                false,
                "resolve_qwen3_8b_128k_context_model_assets_for_kv_direct",
                false,
                "missing_qwen3_8b_128k_gguf_candidate_artifact",
            ),
            "resolve_qwen3_8b_128k_context_model_assets_for_kv_direct"
        );
    }

    #[test]
    fn next_work_continues_existing_gguf_split_when_canonical_mlx_context_is_red() {
        let shards = ShardSummary {
            total: 4,
            complete: 0,
            partial: 1,
            failed: 1,
            missing: 3,
            first_incomplete: Some("shard_000_000".to_string()),
            first_incomplete_status: Some("failed".to_string()),
            incomplete_shards: vec!["shard_000_000".to_string()],
            failed_shards: vec!["shard_000_000".to_string()],
        };
        assert_eq!(
            derive_next_existing_work(
                true,
                true,
                &shards,
                &ContractStatus::Missing,
                false,
                "resolve_qwen3_8b_128k_context_model_assets_for_kv_direct",
                true,
                "download_or_register_qwen3_8b_128k_gguf_model_file",
            ),
            "download_or_register_qwen3_8b_128k_gguf_model_file"
        );
    }

    #[test]
    fn next_work_prioritizes_active_gguf_bottleneck_before_legacy_failed_shard() {
        let shards = ShardSummary {
            total: 4,
            complete: 0,
            partial: 1,
            failed: 1,
            missing: 3,
            first_incomplete: Some("shard_000_000".to_string()),
            first_incomplete_status: Some("failed".to_string()),
            incomplete_shards: vec!["shard_000_000".to_string()],
            failed_shards: vec!["shard_000_000".to_string()],
        };
        assert_eq!(
            derive_next_existing_work(
                true,
                true,
                &shards,
                &ContractStatus::Missing,
                false,
                "download_or_register_qwen3_8b_128k_gguf_model_file",
                true,
                "download_or_register_qwen3_8b_128k_gguf_model_file",
            ),
            "download_or_register_qwen3_8b_128k_gguf_model_file"
        );
    }

    #[test]
    fn contract_dir_status_distinguishes_partial_outputs() {
        let dir =
            std::env::temp_dir().join(format!("epistemos_contract_dir_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        assert_eq!(contract_dir_status(&dir), ContractStatus::Missing);
        std::fs::write(dir.join("manifest.json"), "{}").unwrap();
        assert_eq!(contract_dir_status(&dir), ContractStatus::Partial);
        for file in CONTRACT_FILES {
            std::fs::write(dir.join(file), "{}").unwrap();
        }
        assert_eq!(contract_dir_status(&dir), ContractStatus::Complete);
        let _ = std::fs::remove_dir_all(dir);
    }
}
