//! `falsify_qwen3_8b_128k_gguf_route` -- candidate GGUF split for the
//! Qwen3-8B 128K context contract.
//!
//! This does not retarget F-KV-Direct-Gate. The canonical MLX gate stays pinned
//! to Qwen/Qwen3-8B-MLX-4bit. This harness exists so a 128K-labeled GGUF route
//! can be measured honestly as a separate candidate/fallback lane.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind,
    FallbackTier, Measurement,
};
use serde::de::DeserializeOwned;
use serde::Deserialize;

const FALSIFIER_ID: &str = "F-Qwen3-8B-128K-GGUF-Route";
const FIXTURE_ID: &str = "qwen3_8b_128k_gguf_candidate_route_v1";
const COMMAND: &str = "Tools/falsifiers/f_qwen3_8b_128k_gguf_route.sh";
const OUTPUT: &str = "artifacts/falsifiers/qwen3_8b_128k_gguf_route/result.json";
const ASSET_PLAN_OUTPUT: &str = "artifacts/falsifiers/qwen3_8b_128k_gguf_route/asset_plan.json";
const DEFAULT_BENCH_METRICS_PATH: &str =
    "artifacts/falsifiers/qwen3_8b_128k_gguf_route/live_bench/metrics.json";
const DEFAULT_BENCH_MANIFEST_PATH: &str =
    "artifacts/falsifiers/qwen3_8b_128k_gguf_route/live_bench_128k_q4_0_fa_probe/manifest.json";
const DEFAULT_KL_METRICS_PATH: &str =
    "artifacts/falsifiers/qwen3_8b_128k_gguf_route/live_kl/kl_metrics.json";
const SHAPE_PROBES_DIR: &str = "artifacts/falsifiers/qwen3_8b_128k_gguf_route/shape_probes";

const TARGET_GGUF_REPO_ID: &str = "unsloth/Qwen3-8B-128K-GGUF";
const TARGET_GGUF_SLUG: &str = "models--unsloth--Qwen3-8B-128K-GGUF";
const TARGET_GGUF_REVISION_SHA: &str = "4a4ca8eeed6a9f3cdf58de9a1e86f7376d0059f9";
const TARGET_GGUF_CONFIG_CONTEXT_WINDOW_TOKENS: u64 = 131_072;
const TARGET_GGUF_CONFIG_URL: &str =
    "https://huggingface.co/unsloth/Qwen3-8B-128K-GGUF/raw/main/config.json";
const RECOMMENDED_GGUF_FILENAME: &str = "Qwen3-8B-128K-Q4_K_M.gguf";
const RECOMMENDED_GGUF_URL: &str =
    "https://huggingface.co/unsloth/Qwen3-8B-128K-GGUF/resolve/main/Qwen3-8B-128K-Q4_K_M.gguf";
const CANONICAL_MLX_REPO_ID: &str = "Qwen/Qwen3-8B-MLX-4bit";
const DEFAULT_PROMPT_SUITE_PATH: &str = "artifacts/falsifiers/kv_direct_gate/prompt_suite.json";

const REQUIRED_PROMPTS: u64 = 100;
const REQUIRED_CONTEXT_WINDOW_TOKENS: u64 = 128_000;
const REQUIRED_DECODE_TOKENS_PER_PROMPT: u64 = 256;
const SENTINEL_D_KL_NATS: f64 = 999.0;
const SENTINEL_PEAK_RAM_GB: f64 = 999.0;
const SENTINEL_DECODE_TOK_S: f64 = 0.0;
const SENTINEL_WALL_CLOCK_MIN: f64 = 9_999.0;

const MODEL_PATH_ENV: &str = "EPISTEMOS_QWEN3_8B_128K_GGUF_PATH";
const METADATA_PATH_ENV: &str = "EPISTEMOS_QWEN3_8B_128K_GGUF_METADATA_PATH";
const RUNNER_PATH_ENV: &str = "EPISTEMOS_QWEN3_8B_128K_GGUF_RUNNER";
const PROMPT_SUITE_ENV: &str = "EPISTEMOS_QWEN3_8B_128K_GGUF_PROMPT_SUITE";
const LOGITS_PATH_ENV: &str = "EPISTEMOS_QWEN3_8B_128K_GGUF_LOGITS_PATH";
const REFERENCE_LOGITS_ENV: &str = "EPISTEMOS_QWEN3_8B_128K_GGUF_REFERENCE_LOGITS";
const TEST_LOGITS_ENV: &str = "EPISTEMOS_QWEN3_8B_128K_GGUF_TEST_LOGITS";
const KL_METRICS_PATH_ENV: &str = "EPISTEMOS_QWEN3_8B_128K_GGUF_KL_METRICS_PATH";
const METRICS_PATH_ENV: &str = "EPISTEMOS_QWEN3_8B_128K_GGUF_METRICS_PATH";
const BENCH_MANIFEST_PATH_ENV: &str = "EPISTEMOS_QWEN3_8B_128K_GGUF_BENCH_MANIFEST_PATH";

fn main() {
    let report = build_report();
    let path = PathBuf::from(OUTPUT);
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).expect("create GGUF route artifact directory");
    }
    let asset_plan_path = PathBuf::from(ASSET_PLAN_OUTPUT);
    if let Some(parent) = asset_plan_path.parent() {
        std::fs::create_dir_all(parent).expect("create GGUF route asset plan directory");
    }
    std::fs::write(
        &asset_plan_path,
        serde_json::to_vec_pretty(&report.asset_plan).expect("serialize GGUF route asset plan"),
    )
    .expect("write GGUF route asset plan");
    let mut file = std::fs::File::create(&path).expect("open GGUF route artifact");
    write_artifact(&mut file, &report.artifact).expect("write GGUF route artifact");

    println!(
        "F-Qwen3-8B-128K-GGUF-Route: overall_pass={} next_bottleneck={} artifact={}",
        report.artifact.overall_pass,
        report.next_bottleneck,
        path.display()
    );

    if !report.artifact.overall_pass {
        std::process::exit(1);
    }
}

struct RouteReport {
    artifact: agent_core::falsifier_artifacts::FalsifierArtifact,
    next_bottleneck: String,
    asset_plan: serde_json::Value,
}

fn build_report() -> RouteReport {
    let inputs = CandidateInputs::load();
    let model_repo_id = inputs
        .model_path
        .as_deref()
        .map(infer_model_repo_id)
        .unwrap_or_else(|| "unset".to_string());
    let model_identity_matches_target = model_repo_id == TARGET_GGUF_REPO_ID;
    let metadata_context_tokens = inputs
        .metadata
        .as_ref()
        .map(|metadata| metadata.context_window_tokens)
        .unwrap_or_default();
    let metrics_context_tokens = inputs
        .metrics
        .as_ref()
        .map(|metrics| metrics.context_window_tokens)
        .unwrap_or_default();
    let kl_context_tokens = inputs
        .kl_metrics
        .as_ref()
        .map(|metrics| metrics.context_window_tokens)
        .unwrap_or_default();
    let model_context_window_tokens = metadata_context_tokens
        .max(metrics_context_tokens)
        .max(kl_context_tokens);
    let model_context_supports_required_context =
        model_context_window_tokens >= REQUIRED_CONTEXT_WINDOW_TOKENS;
    let target_remote_config_supports_required_context =
        TARGET_GGUF_CONFIG_CONTEXT_WINDOW_TOKENS >= REQUIRED_CONTEXT_WINDOW_TOKENS;
    let prompt_suite = inputs.prompt_suite.as_ref();
    let prompt_suite_prompt_count = prompt_suite
        .map(|suite| suite.prompt_count)
        .unwrap_or_default();
    let prompt_suite_shape_pass = prompt_suite
        .map(|suite| {
            suite.prompt_count >= REQUIRED_PROMPTS
                && suite.min_context_tokens >= REQUIRED_CONTEXT_WINDOW_TOKENS
                && suite.min_decode_tokens >= REQUIRED_DECODE_TOKENS_PER_PROMPT
                && suite.balanced_family_coverage
        })
        .unwrap_or(false);
    let fixture_prompt_count = inputs
        .logit_fixture
        .as_ref()
        .map(|fixture| fixture.prompts.len() as u64)
        .unwrap_or_default();
    let kl_prompt_count = inputs
        .kl_metrics
        .as_ref()
        .map(|metrics| metrics.prompt_count)
        .unwrap_or_default();
    let prompt_count = fixture_prompt_count.max(kl_prompt_count);
    let logit_or_kl_witness_available =
        inputs.logit_fixture.is_some() || inputs.kl_metrics.is_some();
    let average_d_kl_nats = inputs
        .logit_fixture
        .as_ref()
        .and_then(average_fixture_kl)
        .or_else(|| {
            inputs
                .kl_metrics
                .as_ref()
                .map(|metrics| metrics.average_d_kl_nats)
        })
        .unwrap_or(SENTINEL_D_KL_NATS);
    let peak_ram_gb = inputs
        .metrics
        .as_ref()
        .map(|m| m.peak_ram_gb)
        .unwrap_or(SENTINEL_PEAK_RAM_GB);
    let decode_tok_s = inputs
        .metrics
        .as_ref()
        .map(|m| m.decode_tok_s)
        .unwrap_or(SENTINEL_DECODE_TOK_S);
    let suite_wall_clock_min = inputs
        .metrics
        .as_ref()
        .map(|m| m.suite_wall_clock_min)
        .unwrap_or(SENTINEL_WALL_CLOCK_MIN);
    let live_context_tokens = inputs
        .metrics
        .as_ref()
        .map(|m| m.context_window_tokens)
        .unwrap_or_default()
        .max(kl_context_tokens);
    let decode_tokens_per_prompt = inputs
        .metrics
        .as_ref()
        .map(|m| m.decode_tokens_per_prompt)
        .unwrap_or_default();
    let metrics_prompt_count = inputs
        .metrics
        .as_ref()
        .map(|m| m.prompt_count)
        .unwrap_or_default();
    let live_prompt_count = prompt_count.max(metrics_prompt_count);
    let full_context_probe_manifest_available = inputs.bench_manifest.is_some();
    let full_context_probe_context_tokens = inputs
        .bench_manifest
        .as_ref()
        .map(|manifest| manifest.context_window_tokens)
        .unwrap_or_default();
    let full_context_probe_decode_tokens = inputs
        .bench_manifest
        .as_ref()
        .map(|manifest| manifest.decode_tokens_per_prompt)
        .unwrap_or_default();
    let full_context_probe_timed_out = inputs
        .bench_manifest
        .as_ref()
        .map(|manifest| manifest.timed_out)
        .unwrap_or(false);
    let full_context_probe_exit_status = inputs
        .bench_manifest
        .as_ref()
        .map(|manifest| manifest.exit_status)
        .unwrap_or_default();
    let full_context_probe_reached_required_context =
        full_context_probe_context_tokens >= REQUIRED_CONTEXT_WINDOW_TOKENS;
    let full_context_probe_not_stalled = inputs
        .bench_manifest
        .as_ref()
        .map(|manifest| {
            manifest.exit_status == 0
                && !manifest.timed_out
                && manifest.context_window_tokens >= REQUIRED_CONTEXT_WINDOW_TOKENS
        })
        .unwrap_or(false);
    let probe_ladder = summarize_probe_ladder(&inputs.probe_manifests);
    let next_bottleneck = choose_next_bottleneck(
        inputs.model_file_available,
        model_identity_matches_target,
        inputs.metadata.is_some() || inputs.metrics.is_some(),
        model_context_supports_required_context,
        inputs.runner_available,
        prompt_suite_shape_pass,
        logit_or_kl_witness_available,
        inputs.metrics.is_some(),
        live_prompt_count >= REQUIRED_PROMPTS,
        live_context_tokens >= REQUIRED_CONTEXT_WINDOW_TOKENS,
        decode_tokens_per_prompt >= REQUIRED_DECODE_TOKENS_PER_PROMPT,
        full_context_probe_manifest_available,
        full_context_probe_reached_required_context,
        full_context_probe_not_stalled,
    );

    let mut measurements: BTreeMap<String, Measurement> = BTreeMap::new();
    let mut thresholds: BTreeMap<String, AcceptanceThreshold> = BTreeMap::new();
    let mut pass_per_axis: BTreeMap<String, bool> = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "candidate_route_contract_present",
        true,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "gguf_model_file_available",
        inputs.model_file_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_identity_matches_gguf_target",
        model_identity_matches_target,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "gguf_metadata_or_metrics_available",
        inputs.metadata.is_some() || inputs.metrics.is_some(),
    );
    add_count_floor_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_context_window_tokens",
        model_context_window_tokens,
        REQUIRED_CONTEXT_WINDOW_TOKENS,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_context_supports_required_context",
        model_context_supports_required_context,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "candidate_measurement_runner_available",
        inputs.runner_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prompt_suite_manifest_available",
        prompt_suite.is_some(),
    );
    add_count_floor_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prompt_suite_prompt_count",
        prompt_suite_prompt_count,
        REQUIRED_PROMPTS,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prompt_suite_shape_pass",
        prompt_suite_shape_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "reference_logits_available",
        logit_or_kl_witness_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "test_logits_available",
        logit_or_kl_witness_available,
    );
    add_bool_measurement(
        &mut measurements,
        "llama_perplexity_kl_witness_available",
        inputs.kl_metrics.is_some(),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "live_metrics_available",
        inputs.metrics.is_some(),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "full_context_probe_manifest_available",
        full_context_probe_manifest_available,
    );
    add_count_floor_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "full_context_probe_context_tokens",
        full_context_probe_context_tokens,
        REQUIRED_CONTEXT_WINDOW_TOKENS,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "full_context_probe_not_stalled",
        full_context_probe_not_stalled,
    );
    add_bool_measurement(
        &mut measurements,
        "full_context_probe_timed_out",
        full_context_probe_timed_out,
    );
    add_count_measurement(
        &mut measurements,
        "full_context_probe_decode_tokens",
        full_context_probe_decode_tokens,
        "count",
    );
    measurements.insert(
        "full_context_probe_exit_status".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(
                full_context_probe_exit_status,
            )),
            unit: "integer".to_string(),
        },
    );
    add_count_measurement(
        &mut measurements,
        "probe_ladder_manifest_count",
        probe_ladder.manifest_count,
        "count",
    );
    add_count_measurement(
        &mut measurements,
        "probe_ladder_success_count",
        probe_ladder.success_count,
        "count",
    );
    add_count_measurement(
        &mut measurements,
        "probe_ladder_best_success_context_tokens",
        probe_ladder.best_success_context_tokens,
        "count",
    );
    add_count_measurement(
        &mut measurements,
        "probe_ladder_best_success_decode_tokens",
        probe_ladder.best_success_decode_tokens,
        "count",
    );
    add_label(
        &mut measurements,
        "probe_ladder_best_success_cache_policy",
        &probe_ladder.best_success_cache_policy,
    );
    add_bool_measurement(
        &mut measurements,
        "probe_ladder_quantized_kv_without_flash_success",
        probe_ladder.quantized_kv_without_flash_success,
    );
    add_bool_measurement(
        &mut measurements,
        "probe_ladder_quantized_kv_without_flash_failure_seen",
        probe_ladder.quantized_kv_without_flash_failure_seen,
    );
    add_bool_measurement(
        &mut measurements,
        "probe_ladder_flash_attention_success",
        probe_ladder.flash_attention_success,
    );
    add_bool_measurement(
        &mut measurements,
        "probe_ladder_flash_attention_timeout_seen",
        probe_ladder.flash_attention_timeout_seen,
    );
    add_bool_measurement(
        &mut measurements,
        "probe_ladder_no_kv_offload_success",
        probe_ladder.no_kv_offload_success,
    );
    add_bool_measurement(
        &mut measurements,
        "probe_ladder_no_kv_offload_failure_or_timeout_seen",
        probe_ladder.no_kv_offload_failure_or_timeout_seen,
    );
    add_label(&mut measurements, "probe_ladder_path", SHAPE_PROBES_DIR);
    add_count_floor_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "live_prompt_count",
        live_prompt_count,
        REQUIRED_PROMPTS,
    );
    add_count_floor_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "context_window_tokens",
        live_context_tokens,
        REQUIRED_CONTEXT_WINDOW_TOKENS,
    );
    add_count_floor_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "decode_tokens_per_prompt",
        decode_tokens_per_prompt,
        REQUIRED_DECODE_TOKENS_PER_PROMPT,
    );
    add_float_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "average_d_kl_nats",
        average_d_kl_nats,
        "<",
        0.05,
        "nats",
    );
    add_float_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "peak_ram_gb",
        peak_ram_gb,
        "<",
        13.0,
        "GB",
    );
    add_float_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "decode_tok_s",
        decode_tok_s,
        ">=",
        10.0,
        "tokens_per_second",
    );
    add_float_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "suite_wall_clock_min",
        suite_wall_clock_min,
        "<=",
        30.0,
        "minutes",
    );

    add_label(
        &mut measurements,
        "canonical_mlx_repo_id",
        CANONICAL_MLX_REPO_ID,
    );
    add_label(
        &mut measurements,
        "target_gguf_repo_id",
        TARGET_GGUF_REPO_ID,
    );
    add_label(
        &mut measurements,
        "target_gguf_revision_sha",
        TARGET_GGUF_REVISION_SHA,
    );
    add_label(
        &mut measurements,
        "recommended_gguf_filename",
        RECOMMENDED_GGUF_FILENAME,
    );
    add_label(
        &mut measurements,
        "recommended_gguf_download_url",
        RECOMMENDED_GGUF_URL,
    );
    add_count_floor_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "target_remote_config_context_window_tokens",
        TARGET_GGUF_CONFIG_CONTEXT_WINDOW_TOKENS,
        REQUIRED_CONTEXT_WINDOW_TOKENS,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "target_remote_config_supports_required_context",
        target_remote_config_supports_required_context,
    );
    add_label(&mut measurements, "asset_plan_path", ASSET_PLAN_OUTPUT);
    add_label(&mut measurements, "resolved_model_repo_id", &model_repo_id);
    add_label(
        &mut measurements,
        "resolved_model_path",
        inputs
            .model_path
            .as_ref()
            .map(|path| path.display().to_string())
            .as_deref()
            .unwrap_or("unset"),
    );
    add_label(
        &mut measurements,
        "metadata_path",
        inputs
            .metadata_path
            .as_ref()
            .map(|path| path.display().to_string())
            .as_deref()
            .unwrap_or("unset"),
    );
    add_label(
        &mut measurements,
        "kl_metrics_path",
        inputs
            .kl_metrics_path
            .as_ref()
            .map(|path| path.display().to_string())
            .as_deref()
            .unwrap_or("unset"),
    );
    add_label(
        &mut measurements,
        "bench_manifest_path",
        inputs
            .bench_manifest_path
            .as_ref()
            .map(|path| path.display().to_string())
            .as_deref()
            .unwrap_or("unset"),
    );
    add_label(
        &mut measurements,
        "kl_reference_route",
        inputs
            .kl_metrics
            .as_ref()
            .map(|metrics| metrics.reference_route.as_str())
            .unwrap_or("unset"),
    );
    add_label(
        &mut measurements,
        "kl_test_route",
        inputs
            .kl_metrics
            .as_ref()
            .map(|metrics| metrics.test_route.as_str())
            .unwrap_or("unset"),
    );
    add_label(
        &mut measurements,
        "bench_cache_type_k",
        inputs
            .metrics
            .as_ref()
            .map(|metrics| metrics.cache_type_k.as_str())
            .unwrap_or("unset"),
    );
    add_label(
        &mut measurements,
        "bench_cache_type_v",
        inputs
            .metrics
            .as_ref()
            .map(|metrics| metrics.cache_type_v.as_str())
            .unwrap_or("unset"),
    );
    add_label(
        &mut measurements,
        "runner_path",
        inputs
            .runner_path
            .as_ref()
            .map(|path| path.display().to_string())
            .as_deref()
            .unwrap_or("unset"),
    );
    add_label(
        &mut measurements,
        "prompt_suite_path",
        inputs
            .prompt_suite_path
            .as_ref()
            .map(|path| path.display().to_string())
            .as_deref()
            .unwrap_or(DEFAULT_PROMPT_SUITE_PATH),
    );
    add_label(&mut measurements, "next_bottleneck", &next_bottleneck);

    let mut anomalies = vec![serde_json::json!({
        "kind": "candidate_route_not_canonical_mlx",
        "detail": format!("This artifact is a separate GGUF candidate route. It does not retarget `{CANONICAL_MLX_REPO_ID}` or satisfy F-KV-Direct-Gate.")
    })];
    if !inputs.model_file_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_gguf_model_file",
            "detail": format!("{MODEL_PATH_ENV} is unset or no local `{TARGET_GGUF_SLUG}` GGUF file was found.")
        }));
    }
    if inputs.model_file_available && !model_identity_matches_target {
        anomalies.push(serde_json::json!({
            "kind": "noncanonical_gguf_candidate_identity",
            "detail": format!("Resolved GGUF model identity `{model_repo_id}` does not match target `{TARGET_GGUF_REPO_ID}`.")
        }));
    }
    if inputs.metadata.is_none() && inputs.metrics.is_none() {
        anomalies.push(serde_json::json!({
            "kind": "missing_gguf_context_metadata",
            "detail": format!("Provide {METADATA_PATH_ENV} or live metrics with context_window_tokens before claiming 128K GGUF context support.")
        }));
    }
    if !inputs.runner_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_candidate_measurement_runner",
            "detail": format!("Set {RUNNER_PATH_ENV} to an in-process GGUF harness or install a research-only llama.cpp CLI for measurement.")
        }));
    }
    if !prompt_suite_shape_pass {
        anomalies.push(serde_json::json!({
            "kind": "missing_or_invalid_prompt_suite",
            "detail": "The shared KV prompt suite must provide 100 prompts, 128K target context, 256 decode tokens, and balanced families."
        }));
    }
    if !logit_or_kl_witness_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_paired_logits_or_kl_witness",
            "detail": format!("Provide {LOGITS_PATH_ENV}, paired {REFERENCE_LOGITS_ENV}/{TEST_LOGITS_ENV}, or {KL_METRICS_PATH_ENV} from llama-perplexity KL mode.")
        }));
    }
    if inputs.metrics.is_none() {
        anomalies.push(serde_json::json!({
            "kind": "missing_live_metrics",
            "detail": format!("Provide {METRICS_PATH_ENV} with prompt count, context, decode tokens, RSS, tok/s, and wall-clock.")
        }));
    }
    if let Some(manifest) = &inputs.bench_manifest {
        if manifest.context_window_tokens >= REQUIRED_CONTEXT_WINDOW_TOKENS
            && manifest.exit_status != 0
        {
            anomalies.push(serde_json::json!({
                "kind": "full_context_probe_failed",
                "detail": format!(
                    "The 128K GGUF bench manifest exited with status {} after requesting {} context tokens; repair the Metal/residency stall before treating fixture expansion as a green path.",
                    manifest.exit_status,
                    manifest.context_window_tokens
                )
            }));
        }
    }
    if probe_ladder.best_success_context_tokens > 0
        && probe_ladder.best_success_context_tokens < REQUIRED_CONTEXT_WINDOW_TOKENS
    {
        anomalies.push(serde_json::json!({
            "kind": "gguf_probe_ladder_below_required_context",
            "detail": format!(
                "Best successful GGUF probe is {} context tokens with {}; the required route remains {} tokens.",
                probe_ladder.best_success_context_tokens,
                probe_ladder.best_success_cache_policy,
                REQUIRED_CONTEXT_WINDOW_TOKENS
            )
        }));
    }
    if probe_ladder.quantized_kv_without_flash_failure_seen
        && !probe_ladder.quantized_kv_without_flash_success
    {
        anomalies.push(serde_json::json!({
            "kind": "gguf_quantized_kv_context_create_failed",
            "detail": "Local shape probes show quantized KV cache types fail context creation without flash-attention on this runner/hardware; do not retry 128K q4/q8 without changing the backend policy."
        }));
    }
    if probe_ladder.flash_attention_timeout_seen && !probe_ladder.flash_attention_success {
        anomalies.push(serde_json::json!({
            "kind": "gguf_flash_attention_stall_reproduced",
            "detail": "Local shape probes show flash-attention timed out even at 8K; the 128K stall is a backend/runtime issue, not a missing prompt-suite issue."
        }));
    }
    if probe_ladder.no_kv_offload_failure_or_timeout_seen && !probe_ladder.no_kv_offload_success {
        anomalies.push(serde_json::json!({
            "kind": "gguf_no_kv_offload_not_a_repair",
            "detail": "Local shape probes show disabling KV offload does not repair the route: q4 KV still fails context creation and f16 KV times out at 8K."
        }));
    }
    for error in &inputs.parse_errors {
        anomalies.push(serde_json::json!({
            "kind": "candidate_input_parse_error",
            "detail": error
        }));
    }
    anomalies.push(serde_json::json!({
        "kind": "next_bottleneck",
        "detail": next_bottleneck
    }));

    let asset_plan = build_asset_plan(
        inputs.model_path.as_deref(),
        inputs.metadata_path.as_deref(),
        model_context_window_tokens,
        &next_bottleneck,
    );

    let overall_candidate_pass = pass_per_axis.values().copied().all(|v| v);
    let artifact = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: if overall_candidate_pass {
            ArtifactKind::FallbackWitness
        } else {
            ArtifactKind::FailureReport
        },
        command: COMMAND.to_string(),
        commit_sha: agent_core::falsifier_artifacts::current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: if overall_candidate_pass {
            FallbackTier::Fallback
        } else {
            FallbackTier::Fail
        },
        anomalies,
        notes: format!(
            "candidate_gguf_route_failure_report; target={TARGET_GGUF_REPO_ID}; \
             canonical MLX target remains {CANONICAL_MLX_REPO_ID}; required shape is >=100 prompts, \
             >=128000 context tokens, >=256 decode tokens, D_KL < 0.05, peak RAM < 13 GB, \
             decode >=10 tok/s, and suite wall-clock <=30 minutes; acquisition plan is written to \
             {ASSET_PLAN_OUTPUT}"
        ),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    RouteReport {
        artifact,
        next_bottleneck,
        asset_plan,
    }
}

#[derive(Debug)]
struct CandidateInputs {
    model_path: Option<PathBuf>,
    model_file_available: bool,
    metadata_path: Option<PathBuf>,
    metadata: Option<RouteMetadata>,
    runner_path: Option<PathBuf>,
    runner_available: bool,
    prompt_suite_path: Option<PathBuf>,
    prompt_suite: Option<PromptSuiteSummary>,
    logit_fixture: Option<LogitFixture>,
    kl_metrics_path: Option<PathBuf>,
    kl_metrics: Option<KlMetrics>,
    metrics: Option<LiveMetrics>,
    bench_manifest_path: Option<PathBuf>,
    bench_manifest: Option<BenchManifest>,
    probe_manifests: Vec<BenchManifest>,
    parse_errors: Vec<String>,
}

impl CandidateInputs {
    fn load() -> Self {
        let mut parse_errors = Vec::new();
        let model_path = discover_gguf_model_path();
        let model_file_available = model_path
            .as_deref()
            .map(gguf_model_path_is_usable)
            .unwrap_or(false);
        let metadata_path = env_path(METADATA_PATH_ENV).or_else(|| {
            model_path
                .as_ref()
                .and_then(|path| discover_metadata_path(path))
                .or_else(|| {
                    let default_config = default_snapshot_dir().join("config.json");
                    default_config.exists().then_some(default_config)
                })
        });
        let metadata = match metadata_path.as_deref() {
            Some(path) => match load_route_metadata(path) {
                Ok(metadata) => Some(metadata),
                Err(error) => {
                    parse_errors.push(format!("{}: {error}", path.display()));
                    None
                }
            },
            None => None,
        };
        let runner_path = discover_runner_path();
        let runner_available = runner_path.is_some();
        let prompt_suite_path = Some(
            env_path(PROMPT_SUITE_ENV).unwrap_or_else(|| PathBuf::from(DEFAULT_PROMPT_SUITE_PATH)),
        );
        let prompt_suite = match load_prompt_suite(prompt_suite_path.as_deref().unwrap()) {
            Ok(prompt_suite) => prompt_suite,
            Err(error) => {
                parse_errors.push(error);
                None
            }
        };
        let logit_fixture = match load_logit_fixture_from_env() {
            Ok(fixture) => fixture,
            Err(error) => {
                parse_errors.push(error);
                None
            }
        };
        let kl_metrics_path = env_path(KL_METRICS_PATH_ENV).or_else(|| {
            let default_kl = PathBuf::from(DEFAULT_KL_METRICS_PATH);
            default_kl.exists().then_some(default_kl)
        });
        let kl_metrics = match kl_metrics_path.as_deref() {
            Some(path) => match load_kl_metrics(path) {
                Ok(metrics) => Some(metrics),
                Err(error) => {
                    parse_errors.push(format!("{}: {error}", path.display()));
                    None
                }
            },
            None => None,
        };
        let metrics_path = env_path(METRICS_PATH_ENV).or_else(|| {
            let default_metrics = PathBuf::from(DEFAULT_BENCH_METRICS_PATH);
            default_metrics.exists().then_some(default_metrics)
        });
        let metrics = match metrics_path {
            Some(path) => match load_live_metrics(&path) {
                Ok(metrics) => Some(metrics),
                Err(error) => {
                    parse_errors.push(format!("{}: {error}", path.display()));
                    None
                }
            },
            None => None,
        };
        let bench_manifest_path = env_path(BENCH_MANIFEST_PATH_ENV).or_else(|| {
            let default_manifest = PathBuf::from(DEFAULT_BENCH_MANIFEST_PATH);
            default_manifest.exists().then_some(default_manifest)
        });
        let bench_manifest = match bench_manifest_path.as_deref() {
            Some(path) => match load_bench_manifest(path) {
                Ok(manifest) => Some(manifest),
                Err(error) => {
                    parse_errors.push(format!("{}: {error}", path.display()));
                    None
                }
            },
            None => None,
        };
        let probe_manifests = load_probe_manifests(Path::new(SHAPE_PROBES_DIR), &mut parse_errors);

        Self {
            model_path,
            model_file_available,
            metadata_path,
            metadata,
            runner_path,
            runner_available,
            prompt_suite_path,
            prompt_suite,
            logit_fixture,
            kl_metrics_path,
            kl_metrics,
            metrics,
            bench_manifest_path,
            bench_manifest,
            probe_manifests,
            parse_errors,
        }
    }
}

#[derive(Debug)]
struct RouteMetadata {
    context_window_tokens: u64,
}

#[derive(Debug)]
struct PromptSuiteSummary {
    prompt_count: u64,
    min_context_tokens: u64,
    min_decode_tokens: u64,
    balanced_family_coverage: bool,
}

#[derive(Debug, Deserialize)]
struct PromptSuiteInput {
    prompts: Vec<PromptSuitePrompt>,
}

#[derive(Debug, Deserialize)]
struct PromptSuitePrompt {
    family: String,
    target_context_tokens: u64,
    decode_tokens: u64,
}

#[derive(Debug, Deserialize)]
struct PromptLogits {
    reference_logits: Vec<f64>,
    test_logits: Vec<f64>,
}

#[derive(Debug)]
struct LogitFixture {
    prompts: Vec<PromptLogits>,
}

#[derive(Debug)]
struct KlMetrics {
    prompt_count: u64,
    context_window_tokens: u64,
    average_d_kl_nats: f64,
    reference_route: String,
    test_route: String,
}

#[derive(Debug, Deserialize)]
#[serde(untagged)]
enum PromptFixtureInput {
    Object { prompts: Vec<PromptLogits> },
    Prompts(Vec<PromptLogits>),
}

#[derive(Debug, Deserialize)]
#[serde(untagged)]
enum LogitsInput {
    Object { logits: Vec<Vec<f64>> },
    Rows(Vec<Vec<f64>>),
    Row(Vec<f64>),
}

#[derive(Debug)]
struct LiveMetrics {
    prompt_count: u64,
    context_window_tokens: u64,
    decode_tokens_per_prompt: u64,
    peak_ram_gb: f64,
    decode_tok_s: f64,
    suite_wall_clock_min: f64,
    cache_type_k: String,
    cache_type_v: String,
}

#[derive(Debug)]
struct BenchManifest {
    exit_status: i64,
    timed_out: bool,
    context_window_tokens: u64,
    decode_tokens_per_prompt: u64,
    cache_type_k: String,
    cache_type_v: String,
    flash_attn: bool,
    no_kv_offload: bool,
}

#[derive(Debug, Default)]
struct ProbeLadderSummary {
    manifest_count: u64,
    success_count: u64,
    best_success_context_tokens: u64,
    best_success_decode_tokens: u64,
    best_success_cache_policy: String,
    quantized_kv_without_flash_success: bool,
    quantized_kv_without_flash_failure_seen: bool,
    flash_attention_success: bool,
    flash_attention_timeout_seen: bool,
    no_kv_offload_success: bool,
    no_kv_offload_failure_or_timeout_seen: bool,
}

fn load_route_metadata(path: &Path) -> Result<RouteMetadata, String> {
    let value: serde_json::Value = read_json_file(path)?;
    let object = value
        .as_object()
        .ok_or_else(|| "GGUF metadata JSON must be an object".to_string())?;
    let context_window_tokens = optional_u64(
        object,
        &[
            "context_window_tokens",
            "n_ctx_train",
            "qwen3.context_length",
            "qwen3.rope.scaling.context_length",
            "max_position_embeddings",
            "model_max_length",
        ],
    )
    .unwrap_or_default();
    Ok(RouteMetadata {
        context_window_tokens,
    })
}

fn load_prompt_suite(path: &Path) -> Result<Option<PromptSuiteSummary>, String> {
    if !path.exists() {
        return Ok(None);
    }
    let suite: PromptSuiteInput =
        read_json_file(path).map_err(|error| format!("{}: {error}", path.display()))?;
    let prompt_count = suite.prompts.len() as u64;
    let min_context_tokens = suite
        .prompts
        .iter()
        .map(|prompt| prompt.target_context_tokens)
        .min()
        .unwrap_or_default();
    let min_decode_tokens = suite
        .prompts
        .iter()
        .map(|prompt| prompt.decode_tokens)
        .min()
        .unwrap_or_default();
    let mut family_counts = BTreeMap::<String, u64>::new();
    for prompt in &suite.prompts {
        *family_counts.entry(prompt.family.clone()).or_default() += 1;
    }
    let balanced_family_coverage = [
        "long_prefix_recall",
        "multi_turn",
        "code_completion",
        "reasoning",
    ]
    .iter()
    .all(|family| family_counts.get(*family).copied().unwrap_or_default() >= 25);
    Ok(Some(PromptSuiteSummary {
        prompt_count,
        min_context_tokens,
        min_decode_tokens,
        balanced_family_coverage,
    }))
}

fn load_logit_fixture_from_env() -> Result<Option<LogitFixture>, String> {
    if let Some(path) = env_path(LOGITS_PATH_ENV) {
        let input: PromptFixtureInput =
            read_json_file(&path).map_err(|error| format!("{}: {error}", path.display()))?;
        let prompts = match input {
            PromptFixtureInput::Object { prompts } => prompts,
            PromptFixtureInput::Prompts(prompts) => prompts,
        };
        return Ok(Some(LogitFixture { prompts }));
    }

    match (env_path(REFERENCE_LOGITS_ENV), env_path(TEST_LOGITS_ENV)) {
        (Some(reference_path), Some(test_path)) => {
            let reference_rows = read_logits_rows(&reference_path)
                .map_err(|error| format!("{}: {error}", reference_path.display()))?;
            let test_rows = read_logits_rows(&test_path)
                .map_err(|error| format!("{}: {error}", test_path.display()))?;
            if reference_rows.len() != test_rows.len() {
                return Err(format!(
                    "reference/test logit row mismatch: {} vs {}",
                    reference_rows.len(),
                    test_rows.len()
                ));
            }
            let prompts = reference_rows
                .into_iter()
                .zip(test_rows)
                .map(|(reference_logits, test_logits)| PromptLogits {
                    reference_logits,
                    test_logits,
                })
                .collect();
            Ok(Some(LogitFixture { prompts }))
        }
        (Some(_), None) => Err(format!(
            "{REFERENCE_LOGITS_ENV} is set but {TEST_LOGITS_ENV} is missing"
        )),
        (None, Some(_)) => Err(format!(
            "{TEST_LOGITS_ENV} is set but {REFERENCE_LOGITS_ENV} is missing"
        )),
        (None, None) => Ok(None),
    }
}

fn read_logits_rows(path: &Path) -> Result<Vec<Vec<f64>>, String> {
    let input: LogitsInput = read_json_file(path)?;
    Ok(match input {
        LogitsInput::Object { logits } | LogitsInput::Rows(logits) => logits,
        LogitsInput::Row(logits) => vec![logits],
    })
}

fn load_kl_metrics(path: &Path) -> Result<KlMetrics, String> {
    let value: serde_json::Value = read_json_file(path)?;
    let object = value
        .as_object()
        .ok_or_else(|| "KL metrics JSON must be an object".to_string())?;
    Ok(KlMetrics {
        prompt_count: optional_u64(object, &["prompt_count", "live_prompt_count"])
            .unwrap_or_default(),
        context_window_tokens: required_u64(
            object,
            &[
                "context_window_tokens",
                "context_tokens",
                "prompt_context_tokens",
            ],
        )?,
        average_d_kl_nats: required_f64(object, &["average_d_kl_nats", "mean_kld", "d_kl_nats"])?,
        reference_route: optional_string(object, &["reference_route"])
            .unwrap_or_else(|| "unset".to_string()),
        test_route: optional_string(object, &["test_route"]).unwrap_or_else(|| "unset".to_string()),
    })
}

fn load_live_metrics(path: &Path) -> Result<LiveMetrics, String> {
    let value: serde_json::Value = read_json_file(path)?;
    let object = value
        .as_object()
        .ok_or_else(|| "metrics JSON must be an object".to_string())?;
    Ok(LiveMetrics {
        prompt_count: optional_u64(object, &["prompt_count", "live_prompt_count"])
            .unwrap_or_default(),
        context_window_tokens: required_u64(
            object,
            &[
                "context_window_tokens",
                "context_tokens",
                "max_context_tokens",
                "prompt_context_tokens",
            ],
        )?,
        decode_tokens_per_prompt: required_u64(
            object,
            &[
                "decode_tokens_per_prompt",
                "generated_tokens_per_prompt",
                "tokens_emitted_per_prompt",
                "decode_tokens",
            ],
        )?,
        peak_ram_gb: required_f64(object, &["peak_ram_gb", "peak_rss_gb"])?,
        decode_tok_s: required_f64(
            object,
            &[
                "decode_tok_s",
                "decode_tokens_per_second",
                "tokens_per_second",
            ],
        )?,
        suite_wall_clock_min: required_f64(
            object,
            &[
                "suite_wall_clock_min",
                "wall_clock_min",
                "suite_wall_clock_minutes",
            ],
        )?,
        cache_type_k: optional_string(object, &["cache_type_k"])
            .unwrap_or_else(|| "unset".to_string()),
        cache_type_v: optional_string(object, &["cache_type_v"])
            .unwrap_or_else(|| "unset".to_string()),
    })
}

fn load_bench_manifest(path: &Path) -> Result<BenchManifest, String> {
    let value: serde_json::Value = read_json_file(path)?;
    let object = value
        .as_object()
        .ok_or_else(|| "bench manifest JSON must be an object".to_string())?;
    let command = object
        .get("command")
        .and_then(|value| value.as_array())
        .map(|values| {
            values
                .iter()
                .filter_map(|value| value.as_str().map(ToString::to_string))
                .collect::<Vec<String>>()
        })
        .unwrap_or_default();
    Ok(BenchManifest {
        exit_status: object
            .get("exit_status")
            .and_then(|value| value.as_i64())
            .unwrap_or_default(),
        timed_out: object
            .get("timed_out")
            .and_then(|value| value.as_bool())
            .unwrap_or(false),
        context_window_tokens: required_u64(object, &["context_window_tokens"])?,
        decode_tokens_per_prompt: required_u64(object, &["decode_tokens_per_prompt"])?,
        cache_type_k: optional_string(object, &["cache_type_k"])
            .or_else(|| command_value(&command, "-ctk"))
            .unwrap_or_else(|| "unset".to_string()),
        cache_type_v: optional_string(object, &["cache_type_v"])
            .or_else(|| command_value(&command, "-ctv"))
            .unwrap_or_else(|| "unset".to_string()),
        flash_attn: optional_u64(object, &["flash_attn"])
            .or_else(|| command_value(&command, "-fa").and_then(|value| value.parse().ok()))
            .map(|value| value != 0)
            .unwrap_or(false),
        no_kv_offload: optional_u64(object, &["no_kv_offload"])
            .or_else(|| command_value(&command, "-nkvo").and_then(|value| value.parse().ok()))
            .map(|value| value != 0)
            .unwrap_or(false),
    })
}

fn load_probe_manifests(root: &Path, parse_errors: &mut Vec<String>) -> Vec<BenchManifest> {
    let mut manifests = Vec::new();
    let Ok(entries) = std::fs::read_dir(root) else {
        return manifests;
    };
    for entry in entries.flatten() {
        let path = entry.path().join("manifest.json");
        if !path.exists() {
            continue;
        }
        match load_bench_manifest(&path) {
            Ok(manifest) => manifests.push(manifest),
            Err(error) => parse_errors.push(format!("{}: {error}", path.display())),
        }
    }
    manifests
}

fn summarize_probe_ladder(manifests: &[BenchManifest]) -> ProbeLadderSummary {
    let mut summary = ProbeLadderSummary {
        best_success_cache_policy: "unset".to_string(),
        ..ProbeLadderSummary::default()
    };
    for manifest in manifests {
        summary.manifest_count += 1;
        let success = manifest.exit_status == 0 && !manifest.timed_out;
        let quantized_kv = manifest.cache_type_k != "f16" || manifest.cache_type_v != "f16";
        if success {
            summary.success_count += 1;
            if manifest.context_window_tokens > summary.best_success_context_tokens
                || (manifest.context_window_tokens == summary.best_success_context_tokens
                    && manifest.decode_tokens_per_prompt > summary.best_success_decode_tokens)
            {
                summary.best_success_context_tokens = manifest.context_window_tokens;
                summary.best_success_decode_tokens = manifest.decode_tokens_per_prompt;
                summary.best_success_cache_policy = format!(
                    "ctk={} ctv={} flash_attn={}",
                    manifest.cache_type_k, manifest.cache_type_v, manifest.flash_attn
                );
            }
            if quantized_kv && !manifest.flash_attn {
                summary.quantized_kv_without_flash_success = true;
            }
            if manifest.flash_attn {
                summary.flash_attention_success = true;
            }
            if manifest.no_kv_offload {
                summary.no_kv_offload_success = true;
            }
        } else {
            if quantized_kv && !manifest.flash_attn {
                summary.quantized_kv_without_flash_failure_seen = true;
            }
            if manifest.flash_attn && manifest.timed_out {
                summary.flash_attention_timeout_seen = true;
            }
            if manifest.no_kv_offload {
                summary.no_kv_offload_failure_or_timeout_seen = true;
            }
        }
    }
    summary
}

fn command_value(command: &[String], flag: &str) -> Option<String> {
    command
        .windows(2)
        .find(|window| window.first().map(String::as_str) == Some(flag))
        .and_then(|window| window.get(1).cloned())
}

fn discover_gguf_model_path() -> Option<PathBuf> {
    if let Some(path) = env_path(MODEL_PATH_ENV).and_then(resolve_gguf_path) {
        return Some(path);
    }
    for root in candidate_model_roots() {
        for candidate in [
            root.join(TARGET_GGUF_SLUG),
            root.join("text").join("hub").join(TARGET_GGUF_SLUG),
        ] {
            if let Some(path) = resolve_gguf_path(candidate) {
                return Some(path);
            }
        }
    }
    None
}

fn resolve_gguf_path(path: PathBuf) -> Option<PathBuf> {
    if gguf_model_path_is_usable(&path) {
        return Some(path);
    }
    if path.is_dir() {
        return find_first_gguf(&path);
    }
    None
}

fn find_first_gguf(root: &Path) -> Option<PathBuf> {
    let mut stack = vec![root.to_path_buf()];
    let mut seen = 0usize;
    while let Some(dir) = stack.pop() {
        seen += 1;
        if seen > 2_000 {
            return None;
        }
        let Ok(entries) = std::fs::read_dir(&dir) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            if gguf_model_path_is_usable(&path) {
                return Some(path);
            }
            if path.is_dir() {
                stack.push(path);
            }
        }
    }
    None
}

fn gguf_model_path_is_usable(path: &Path) -> bool {
    path.is_file()
        && path
            .extension()
            .and_then(|ext| ext.to_str())
            .map(|ext| ext.eq_ignore_ascii_case("gguf"))
            .unwrap_or(false)
        && std::fs::metadata(path)
            .map(|metadata| metadata.len() > 1_000_000)
            .unwrap_or(false)
}

fn candidate_model_roots() -> Vec<PathBuf> {
    let mut roots = Vec::new();
    if let Some(root) = env_path("EPISTEMOS_LOCAL_MODEL_ROOT") {
        roots.push(root);
    }
    if let Some(home) = std::env::var_os("HOME") {
        let home = PathBuf::from(home);
        roots.push(home.join("Library/Application Support/Epistemos/Models"));
        roots.push(home.join(".cache/huggingface/hub"));
    }
    if let Some(user) = std::env::var_os("USER").or_else(|| std::env::var_os("LOGNAME")) {
        let home = PathBuf::from("/Users").join(PathBuf::from(user));
        roots.push(home.join("Library/Application Support/Epistemos/Models"));
        roots.push(home.join(".cache/huggingface/hub"));
    }
    roots.sort();
    roots.dedup();
    roots.into_iter().filter(|root| root.exists()).collect()
}

fn discover_metadata_path(model_path: &Path) -> Option<PathBuf> {
    let mut cursor = if model_path.is_dir() {
        Some(model_path)
    } else {
        model_path.parent()
    };
    let mut depth = 0usize;
    while let Some(dir) = cursor {
        for name in ["gguf_route_metadata.json", "config.json"] {
            let candidate = dir.join(name);
            if candidate.exists() {
                return Some(candidate);
            }
        }
        depth += 1;
        if depth >= 8 {
            break;
        }
        cursor = dir.parent();
    }
    None
}

fn discover_runner_path() -> Option<PathBuf> {
    if let Some(path) = env_path(RUNNER_PATH_ENV).filter(|path| path.exists()) {
        return Some(path);
    }
    for name in ["llama-cli", "llama-bench", "llama-server", "llama"] {
        if let Some(path) = find_on_path(name) {
            return Some(path);
        }
    }
    None
}

fn find_on_path(name: &str) -> Option<PathBuf> {
    let path_var = std::env::var_os("PATH")?;
    for dir in std::env::split_paths(&path_var) {
        let candidate = dir.join(name);
        if candidate.exists() {
            return Some(candidate);
        }
    }
    None
}

fn infer_model_repo_id(path: &Path) -> String {
    path.components()
        .filter_map(|component| component.as_os_str().to_str())
        .find_map(|component| {
            component.strip_prefix("models--").map(|slug| {
                let parts: Vec<&str> = slug.split("--").collect();
                if parts.len() >= 2 {
                    format!("{}/{}", parts[0], parts[1..].join("--"))
                } else {
                    slug.to_string()
                }
            })
        })
        .unwrap_or_else(|| {
            path.file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("unknown")
                .to_string()
        })
}

fn choose_next_bottleneck(
    model_file_available: bool,
    model_identity_matches_target: bool,
    metadata_or_metrics_available: bool,
    model_context_supports_required_context: bool,
    runner_available: bool,
    prompt_suite_shape_pass: bool,
    logits_available: bool,
    metrics_available: bool,
    live_prompt_floor_pass: bool,
    live_context_floor_pass: bool,
    decode_floor_pass: bool,
    full_context_probe_manifest_available: bool,
    full_context_probe_reached_required_context: bool,
    full_context_probe_not_stalled: bool,
) -> String {
    if !model_file_available {
        "download_or_register_qwen3_8b_128k_gguf_model_file".to_string()
    } else if !model_identity_matches_target {
        "resolve_qwen3_8b_128k_gguf_model_identity".to_string()
    } else if !metadata_or_metrics_available || !model_context_supports_required_context {
        "record_qwen3_8b_128k_gguf_context_metadata".to_string()
    } else if !runner_available {
        "provide_qwen3_8b_128k_gguf_measurement_runner".to_string()
    } else if !prompt_suite_shape_pass {
        "restore_qwen3_8b_128k_prompt_suite_shape".to_string()
    } else if !logits_available {
        "run_qwen3_8b_128k_gguf_reference_and_test_logits".to_string()
    } else if !metrics_available {
        "record_qwen3_8b_128k_gguf_live_metrics".to_string()
    } else if full_context_probe_manifest_available
        && full_context_probe_reached_required_context
        && !full_context_probe_not_stalled
    {
        "repair_qwen3_8b_128k_gguf_metal_stall".to_string()
    } else if !live_prompt_floor_pass || !live_context_floor_pass || !decode_floor_pass {
        "expand_qwen3_8b_128k_gguf_fixture_shape".to_string()
    } else {
        "debug_qwen3_8b_128k_gguf_threshold_failures".to_string()
    }
}

fn build_asset_plan(
    model_path: Option<&Path>,
    metadata_path: Option<&Path>,
    model_context_window_tokens: u64,
    next_bottleneck: &str,
) -> serde_json::Value {
    let default_snapshot_dir = default_snapshot_dir();
    let default_model_path = default_snapshot_dir.join(RECOMMENDED_GGUF_FILENAME);
    let default_config_path = default_snapshot_dir.join("config.json");
    serde_json::json!({
        "plan_id": "qwen3_8b_128k_gguf_asset_plan_v1",
        "generated_by": FALSIFIER_ID,
        "target_repo_id": TARGET_GGUF_REPO_ID,
        "target_revision_sha": TARGET_GGUF_REVISION_SHA,
        "target_slug": TARGET_GGUF_SLUG,
        "canonical_mlx_repo_id": CANONICAL_MLX_REPO_ID,
        "does_not_retarget_canonical_kv_gate": true,
        "required_context_window_tokens": REQUIRED_CONTEXT_WINDOW_TOKENS,
        "target_remote_config": {
            "url": TARGET_GGUF_CONFIG_URL,
            "context_window_tokens": TARGET_GGUF_CONFIG_CONTEXT_WINDOW_TOKENS,
            "supports_required_context": TARGET_GGUF_CONFIG_CONTEXT_WINDOW_TOKENS >= REQUIRED_CONTEXT_WINDOW_TOKENS
        },
        "recommended_quantization": {
            "filename": RECOMMENDED_GGUF_FILENAME,
            "reason": "First measurement candidate for the 16 GB route; promote or replace only after RSS/tok-s/quality artifacts pass.",
            "download_url": RECOMMENDED_GGUF_URL
        },
        "default_local_paths": {
            "snapshot_dir": default_snapshot_dir.display().to_string(),
            "model_file": default_model_path.display().to_string(),
            "metadata_file": default_config_path.display().to_string()
        },
        "resolved_local_state": {
            "model_path": model_path
                .map(|path| path.display().to_string())
                .unwrap_or_else(|| "unset".to_string()),
            "metadata_path": metadata_path
                .map(|path| path.display().to_string())
                .unwrap_or_else(|| "unset".to_string()),
            "model_context_window_tokens": model_context_window_tokens
        },
        "download_commands": {
            "config": format!(
                "curl -L --fail --create-dirs -o '{}' '{}'",
                default_config_path.display(),
                TARGET_GGUF_CONFIG_URL
            ),
            "model": format!(
                "curl -L --fail --create-dirs -o '{}' '{}'",
                default_model_path.display(),
                RECOMMENDED_GGUF_URL
            )
        },
        "register_env": {
            "model_path_env": MODEL_PATH_ENV,
            "model_path_value": default_model_path.display().to_string(),
            "metadata_path_env": METADATA_PATH_ENV,
            "metadata_path_value": default_config_path.display().to_string()
        },
        "runner_requirement": {
            "env": RUNNER_PATH_ENV,
            "accepted_binaries": ["llama-cli", "llama-bench", "llama-server", "llama"],
            "current_next_bottleneck": next_bottleneck
        },
        "bench_runner": {
            "command": "Tools/falsifiers/run_qwen3_8b_128k_gguf_bench.sh",
            "default_metrics_path": DEFAULT_BENCH_METRICS_PATH,
            "green_capable": false,
            "reason": "Bench metrics prove model load/RSS/throughput only; paired logits still require a separate witness."
        },
        "kl_runner": {
            "command": "Tools/falsifiers/run_qwen3_8b_128k_gguf_kl.sh",
            "default_kl_metrics_path": DEFAULT_KL_METRICS_PATH,
            "green_capable": false,
            "reason": "Default KL metrics are smoke-sized; full promotion still requires 100 prompts and 128K context."
        },
        "next_gate_after_asset": "provide_qwen3_8b_128k_gguf_measurement_runner"
    })
}

fn default_snapshot_dir() -> PathBuf {
    if let Some(root) = env_path("EPISTEMOS_LOCAL_MODEL_ROOT") {
        return root
            .join("text")
            .join("hub")
            .join(TARGET_GGUF_SLUG)
            .join("snapshots")
            .join(TARGET_GGUF_REVISION_SHA);
    }
    if let Some(user) = std::env::var_os("USER").or_else(|| std::env::var_os("LOGNAME")) {
        let user_home = PathBuf::from("/Users").join(PathBuf::from(user));
        if user_home.exists() {
            return user_home
                .join("Library/Application Support/Epistemos/Models/text/hub")
                .join(TARGET_GGUF_SLUG)
                .join("snapshots")
                .join(TARGET_GGUF_REVISION_SHA);
        }
    }
    if let Some(home) = std::env::var_os("HOME") {
        return PathBuf::from(home)
            .join("Library/Application Support/Epistemos/Models/text/hub")
            .join(TARGET_GGUF_SLUG)
            .join("snapshots")
            .join(TARGET_GGUF_REVISION_SHA);
    }
    PathBuf::from("models")
        .join(TARGET_GGUF_SLUG)
        .join("snapshots")
        .join(TARGET_GGUF_REVISION_SHA)
}

fn average_fixture_kl(fixture: &LogitFixture) -> Option<f64> {
    let mut total = 0.0;
    let mut count = 0usize;
    for prompt in &fixture.prompts {
        total += kl_divergence(&prompt.reference_logits, &prompt.test_logits)?;
        count += 1;
    }
    (count > 0).then_some(total / count as f64)
}

fn kl_divergence(reference_logits: &[f64], test_logits: &[f64]) -> Option<f64> {
    if reference_logits.is_empty() || reference_logits.len() != test_logits.len() {
        return None;
    }
    let reference = softmax(reference_logits)?;
    let test = softmax(test_logits)?;
    let mut kl = 0.0;
    for (p, q) in reference.iter().zip(test.iter()) {
        if *p > 0.0 && *q > 0.0 {
            kl += p * (p.ln() - q.ln());
        }
    }
    Some(kl)
}

fn softmax(logits: &[f64]) -> Option<Vec<f64>> {
    let max = logits.iter().copied().reduce(f64::max)?;
    if !max.is_finite() {
        return None;
    }
    let mut exp_sum = 0.0;
    let mut exp_values = Vec::with_capacity(logits.len());
    for logit in logits {
        let shifted = *logit - max;
        if !shifted.is_finite() {
            return None;
        }
        let exp = shifted.exp();
        exp_sum += exp;
        exp_values.push(exp);
    }
    if exp_sum <= 0.0 || !exp_sum.is_finite() {
        return None;
    }
    Some(
        exp_values
            .into_iter()
            .map(|value| value / exp_sum)
            .collect(),
    )
}

fn read_json_file<T: DeserializeOwned>(path: &Path) -> Result<T, String> {
    let bytes = std::fs::read(path).map_err(|error| error.to_string())?;
    serde_json::from_slice(&bytes).map_err(|error| error.to_string())
}

fn env_path(env_name: &str) -> Option<PathBuf> {
    std::env::var_os(env_name).map(PathBuf::from)
}

fn optional_u64(object: &serde_json::Map<String, serde_json::Value>, keys: &[&str]) -> Option<u64> {
    keys.iter()
        .find_map(|key| object.get(*key).and_then(|value| value.as_u64()))
}

fn optional_string(
    object: &serde_json::Map<String, serde_json::Value>,
    keys: &[&str],
) -> Option<String> {
    keys.iter().find_map(|key| {
        object
            .get(*key)
            .and_then(|value| value.as_str())
            .map(ToString::to_string)
    })
}

fn required_u64(
    object: &serde_json::Map<String, serde_json::Value>,
    keys: &[&str],
) -> Result<u64, String> {
    for key in keys {
        if let Some(value) = object.get(*key) {
            return value
                .as_u64()
                .ok_or_else(|| format!("metrics field `{key}` must be an unsigned integer"));
        }
    }
    Err(format!("missing unsigned integer metrics field {:?}", keys))
}

fn required_f64(
    object: &serde_json::Map<String, serde_json::Value>,
    keys: &[&str],
) -> Result<f64, String> {
    for key in keys {
        if let Some(value) = object.get(*key) {
            return value
                .as_f64()
                .ok_or_else(|| format!("metrics field `{key}` must be numeric"));
        }
    }
    Err(format!("missing numeric metrics field {:?}", keys))
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

fn add_count_floor_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: u64,
    threshold: u64,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(value)),
            unit: "count".to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: ">=".to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(threshold)),
            unit: "count".to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), value >= threshold);
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

fn add_label(measurements: &mut BTreeMap<String, Measurement>, key: &str, value: &str) {
    measurements.insert(
        key.to_string(),
        Measurement {
            value: serde_json::Value::String(value.to_string()),
            unit: "label".to_string(),
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

fn add_count_measurement(
    measurements: &mut BTreeMap<String, Measurement>,
    key: &str,
    value: u64,
    unit: &str,
) {
    measurements.insert(
        key.to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(value)),
            unit: unit.to_string(),
        },
    );
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

    #[test]
    fn repo_id_inference_reads_huggingface_cache_slug() {
        let path = PathBuf::from(
            "/Users/jojo/.cache/huggingface/hub/models--unsloth--Qwen3-8B-128K-GGUF/snapshots/abc/model.Q4_K_M.gguf",
        );
        assert_eq!(infer_model_repo_id(&path), TARGET_GGUF_REPO_ID);
    }

    #[test]
    fn next_bottleneck_starts_with_model_file() {
        assert_eq!(
            choose_next_bottleneck(
                false, false, false, false, false, false, false, false, false, false, false, false,
                false, false,
            ),
            "download_or_register_qwen3_8b_128k_gguf_model_file"
        );
        assert_eq!(
            choose_next_bottleneck(
                true, true, false, false, false, false, false, false, false, false, false, false,
                false, false,
            ),
            "record_qwen3_8b_128k_gguf_context_metadata"
        );
        assert_eq!(
            choose_next_bottleneck(
                true, true, true, true, true, true, false, false, false, false, false, false,
                false, false,
            ),
            "run_qwen3_8b_128k_gguf_reference_and_test_logits"
        );
        assert_eq!(
            choose_next_bottleneck(
                true, true, true, true, true, true, true, true, false, false, false, true, true,
                false,
            ),
            "repair_qwen3_8b_128k_gguf_metal_stall"
        );
    }

    #[test]
    fn route_metadata_reads_context_aliases() {
        let path = std::env::temp_dir().join(format!(
            "epistemos_gguf_route_metadata_{}.json",
            std::process::id()
        ));
        std::fs::write(
            &path,
            serde_json::to_vec(&serde_json::json!({
                "n_ctx_train": 128000
            }))
            .unwrap(),
        )
        .unwrap();
        let metadata = load_route_metadata(&path).expect("metadata parse");
        std::fs::remove_file(&path).ok();
        assert_eq!(metadata.context_window_tokens, 128_000);
    }

    #[test]
    fn average_kl_is_zero_for_identical_logits() {
        let fixture = LogitFixture {
            prompts: vec![PromptLogits {
                reference_logits: vec![1.0, 2.0, -3.0],
                test_logits: vec![1.0, 2.0, -3.0],
            }],
        };
        let kl = average_fixture_kl(&fixture).expect("valid KL");
        assert!(kl.abs() < 1e-12, "kl={kl}");
    }

    #[test]
    fn artifact_is_failure_until_live_route_inputs_exist() {
        let report = build_report();
        assert_eq!(report.artifact.falsifier_id, FALSIFIER_ID);
        assert_eq!(report.artifact.artifact_kind, "failure_report");
        assert!(!report.artifact.overall_pass);
        assert!(report
            .artifact
            .measurements
            .contains_key("candidate_route_contract_present"));
        assert!(report.artifact.measurements.contains_key("next_bottleneck"));
    }

    #[test]
    fn probe_ladder_distinguishes_quantized_kv_and_flash_stalls() {
        let summary = summarize_probe_ladder(&[
            BenchManifest {
                exit_status: 0,
                timed_out: false,
                context_window_tokens: 32_768,
                decode_tokens_per_prompt: 256,
                cache_type_k: "f16".into(),
                cache_type_v: "f16".into(),
                flash_attn: false,
                no_kv_offload: false,
            },
            BenchManifest {
                exit_status: 1,
                timed_out: false,
                context_window_tokens: 8_192,
                decode_tokens_per_prompt: 16,
                cache_type_k: "q4_0".into(),
                cache_type_v: "q4_0".into(),
                flash_attn: false,
                no_kv_offload: true,
            },
            BenchManifest {
                exit_status: 124,
                timed_out: true,
                context_window_tokens: 8_192,
                decode_tokens_per_prompt: 16,
                cache_type_k: "f16".into(),
                cache_type_v: "f16".into(),
                flash_attn: true,
                no_kv_offload: false,
            },
        ]);
        assert_eq!(summary.manifest_count, 3);
        assert_eq!(summary.success_count, 1);
        assert_eq!(summary.best_success_context_tokens, 32_768);
        assert_eq!(
            summary.best_success_cache_policy,
            "ctk=f16 ctv=f16 flash_attn=false"
        );
        assert!(summary.quantized_kv_without_flash_failure_seen);
        assert!(!summary.quantized_kv_without_flash_success);
        assert!(summary.flash_attention_timeout_seen);
        assert!(!summary.flash_attention_success);
        assert!(summary.no_kv_offload_failure_or_timeout_seen);
        assert!(!summary.no_kv_offload_success);
    }
}
