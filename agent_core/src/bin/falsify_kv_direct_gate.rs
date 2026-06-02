//! `falsify_kv_direct_gate` — preflight artifact for F-KV-Direct-Gate.
//!
//! This harness proves the current Tier-1 Rust KV-Direct equality contract and
//! keeps the full Qwen3-8B / 128K / SSD-spill gate red until prompt-level
//! measurements exist. It is intentionally a failure report, because layout
//! equality is not the same as the live L3 SSD Oracle.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::time::Instant;

use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind,
    FallbackTier, Measurement,
};
use agent_core::scope_rex::kv::direct_gate::{
    direct_qk_row, reference_qk_row, route, KvDispatch, KvLayout, KvPair,
};
use serde::de::DeserializeOwned;
use serde::Deserialize;

const FALSIFIER_ID: &str = "F-KV-Direct-Gate";
const FIXTURE_ID: &str = "kv_direct_tier1_plus_live_contract_v1";
const COMMAND: &str = "Tools/falsifiers/f_kv_direct_gate.sh";
const TRACE_COUNT: u64 = 1_000;
const REQUIRED_LIVE_PROMPTS: u64 = 100;
const REQUIRED_CONTEXT_WINDOW_TOKENS: u64 = 128_000;
const REQUIRED_DECODE_TOKENS_PER_PROMPT: u64 = 256;
const SENTINEL_D_KL_NATS: f64 = 999.0;
const SENTINEL_PEAK_RAM_GB: f64 = 999.0;
const SENTINEL_DECODE_TOK_S: f64 = 0.0;
const SENTINEL_WALL_CLOCK_MIN: f64 = 9_999.0;
const DEFAULT_QWEN3_8B_SLUG: &str = "models--Qwen--Qwen3-8B-MLX-4bit";
const CANONICAL_MODEL_REPO_ID: &str = "Qwen/Qwen3-8B-MLX-4bit";
const DEFAULT_PROMPT_SUITE_PATH: &str = "artifacts/falsifiers/kv_direct_gate/prompt_suite.json";
const CANONICAL_SPILL_ROUTE: &str = "residual_patched_mmap_nf4_ssd_spill";
const REQUIRED_COLD_KV_BYTES: u64 = 1;

const MODEL_PATH_ENV: &str = "EPISTEMOS_KV_DIRECT_MODEL_PATH";
const PROMPT_SUITE_ENV: &str = "EPISTEMOS_KV_DIRECT_PROMPT_SUITE";
const LOGITS_PATH_ENV: &str = "EPISTEMOS_KV_DIRECT_LOGITS_PATH";
const REFERENCE_LOGITS_ENV: &str = "EPISTEMOS_KV_DIRECT_REFERENCE_LOGITS";
const TEST_LOGITS_ENV: &str = "EPISTEMOS_KV_DIRECT_TEST_LOGITS";
const METRICS_PATH_ENV: &str = "EPISTEMOS_KV_DIRECT_METRICS_PATH";
const SPILL_TRACE_ENV: &str = "EPISTEMOS_KV_DIRECT_SPILL_TRACE";

fn main() {
    let started_utc = now_utc_rfc3339();
    let start = Instant::now();

    let equality_violations = count_equality_violations(TRACE_COUNT);
    let dispatch_contract_pass = route(&KvLayout::new(16, 64, 64, 8)) == KvDispatch::Direct
        && route(&KvLayout::new(15, 64, 64, 8)) == KvDispatch::Reference
        && route(&KvLayout::new(16, 64, 32, 8)) == KvDispatch::Reference
        && route(&KvLayout::new(16, 64, 64, 0)) == KvDispatch::Reference
        && route(&KvLayout::new(0, 64, 64, 8)) == KvDispatch::Reference;
    let live_inputs = LiveHarnessInputs::load_from_env();
    let average_d_kl_nats = live_inputs
        .logit_fixture
        .as_ref()
        .and_then(average_fixture_kl)
        .unwrap_or(SENTINEL_D_KL_NATS);
    let live_metrics = live_inputs.metrics.as_ref();
    let peak_ram_gb = live_metrics
        .map(|m| m.peak_ram_gb)
        .unwrap_or(SENTINEL_PEAK_RAM_GB);
    let decode_tok_s = live_metrics
        .map(|m| m.decode_tok_s)
        .unwrap_or(SENTINEL_DECODE_TOK_S);
    let suite_wall_clock_min = live_metrics
        .map(|m| m.suite_wall_clock_min)
        .unwrap_or(SENTINEL_WALL_CLOCK_MIN);
    let metrics_spill_labeling = live_metrics.map(|m| m.spill_labeling).unwrap_or(false);
    let spill_trace = live_inputs.spill_trace.as_ref();
    let spill_trace_ssd_spill_labeled = spill_trace
        .map(|trace| trace.ssd_spill_labeled)
        .unwrap_or(false);
    let spill_trace_route_is_canonical = spill_trace
        .map(|trace| trace.route_is_canonical)
        .unwrap_or(false);
    let spill_trace_residual_patch_applied = spill_trace
        .map(|trace| trace.residual_patch_applied)
        .unwrap_or(false);
    let spill_trace_mmap_backed = spill_trace.map(|trace| trace.mmap_backed).unwrap_or(false);
    let spill_trace_quantized_storage = spill_trace
        .map(|trace| trace.quantized_storage)
        .unwrap_or(false);
    let spill_trace_cold_kv_bytes = spill_trace.map(|trace| trace.cold_kv_bytes).unwrap_or(0);
    let spill_labeling = metrics_spill_labeling && spill_trace_ssd_spill_labeled;
    let context_window_tokens = live_metrics.map(|m| m.context_window_tokens).unwrap_or(0);
    let decode_tokens_per_prompt = live_metrics
        .map(|m| m.decode_tokens_per_prompt)
        .unwrap_or(0);
    let prompt_count = live_inputs
        .logit_fixture
        .as_ref()
        .map(|fixture| fixture.prompts.len() as u64)
        .unwrap_or(0);
    let prompt_suite = live_inputs.prompt_suite.as_ref();
    let prompt_suite_prompt_count = prompt_suite
        .map(|suite| suite.prompt_count)
        .unwrap_or_default();
    let prompt_suite_min_context_tokens = prompt_suite
        .map(|suite| suite.min_context_tokens)
        .unwrap_or_default();
    let prompt_suite_min_decode_tokens_per_prompt = prompt_suite
        .map(|suite| suite.min_decode_tokens)
        .unwrap_or_default();
    let prompt_suite_balanced_family_coverage = prompt_suite
        .map(|suite| suite.balanced_family_coverage)
        .unwrap_or(false);
    let model_context = live_inputs.model_context.as_ref();
    let model_context_window_tokens = model_context
        .map(|summary| summary.effective_context_window_tokens)
        .unwrap_or_default();
    let model_context_supports_required_context =
        model_context_window_tokens >= REQUIRED_CONTEXT_WINDOW_TOKENS;
    let model_identity_matches_canonical = model_context
        .map(|summary| summary.canonical_model_identity)
        .unwrap_or(false);

    let mut measurements: BTreeMap<String, Measurement> = BTreeMap::new();
    let mut thresholds: BTreeMap<String, AcceptanceThreshold> = BTreeMap::new();
    let mut pass_per_axis: BTreeMap<String, bool> = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "live_harness_contract_present",
        true,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_assets_available",
        live_inputs.model_assets_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_identity_matches_canonical",
        model_identity_matches_canonical,
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
        "prompt_suite_manifest_available",
        prompt_suite.is_some(),
    );
    add_count_floor_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prompt_suite_prompt_count",
        prompt_suite_prompt_count,
        REQUIRED_LIVE_PROMPTS,
    );
    add_count_floor_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prompt_suite_min_context_tokens",
        prompt_suite_min_context_tokens,
        REQUIRED_CONTEXT_WINDOW_TOKENS,
    );
    add_count_floor_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prompt_suite_min_decode_tokens_per_prompt",
        prompt_suite_min_decode_tokens_per_prompt,
        REQUIRED_DECODE_TOKENS_PER_PROMPT,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prompt_suite_balanced_family_coverage",
        prompt_suite_balanced_family_coverage,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "reference_logits_available",
        live_inputs.reference_logits_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "test_logits_available",
        live_inputs.test_logits_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "live_metrics_available",
        live_inputs.metrics.is_some(),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "spill_trace_available",
        live_inputs.spill_trace_available,
    );
    add_count_floor_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "live_prompt_count",
        prompt_count,
        REQUIRED_LIVE_PROMPTS,
    );
    add_count_floor_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "context_window_tokens",
        context_window_tokens,
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
    add_count_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "tier1_qk_equality_violations",
        equality_violations,
        0,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "tier1_dispatch_contract",
        dispatch_contract_pass,
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
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "spill_labeling",
        spill_labeling,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metrics_spill_labeling",
        metrics_spill_labeling,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "spill_trace_ssd_spill_labeled",
        spill_trace_ssd_spill_labeled,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "spill_trace_route_is_canonical",
        spill_trace_route_is_canonical,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "spill_trace_residual_patch_applied",
        spill_trace_residual_patch_applied,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "spill_trace_mmap_backed",
        spill_trace_mmap_backed,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "spill_trace_quantized_storage",
        spill_trace_quantized_storage,
    );
    add_count_floor_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "spill_trace_cold_kv_bytes",
        spill_trace_cold_kv_bytes,
        REQUIRED_COLD_KV_BYTES,
    );

    measurements.insert(
        "trace_count".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(TRACE_COUNT)),
            unit: "traces".to_string(),
        },
    );
    add_label(
        &mut measurements,
        "live_harness_mode",
        if live_inputs.logit_fixture.is_some() {
            "fixture_logits"
        } else {
            "contract_only"
        },
    );
    add_label(
        &mut measurements,
        "spill_trace_route",
        spill_trace
            .map(|trace| trace.route_label.as_str())
            .unwrap_or("unset"),
    );
    add_optional_env_label(&mut measurements, "model_path_env", MODEL_PATH_ENV);
    add_optional_env_label(&mut measurements, "prompt_suite_path_env", PROMPT_SUITE_ENV);
    add_optional_env_label(&mut measurements, "logits_path_env", LOGITS_PATH_ENV);
    add_optional_env_label(
        &mut measurements,
        "reference_logits_path_env",
        REFERENCE_LOGITS_ENV,
    );
    add_optional_env_label(&mut measurements, "test_logits_path_env", TEST_LOGITS_ENV);
    add_optional_env_label(&mut measurements, "metrics_path_env", METRICS_PATH_ENV);
    add_optional_env_label(&mut measurements, "spill_trace_path_env", SPILL_TRACE_ENV);
    add_label(
        &mut measurements,
        "resolved_model_asset_path",
        live_inputs
            .model_asset_path
            .as_ref()
            .map(|path| path.display().to_string())
            .as_deref()
            .unwrap_or("unset"),
    );
    add_label(
        &mut measurements,
        "canonical_model_repo_id",
        CANONICAL_MODEL_REPO_ID,
    );
    add_label(
        &mut measurements,
        "resolved_model_repo_id",
        model_context
            .map(|summary| summary.repo_id.as_str())
            .unwrap_or("unset"),
    );
    add_label(
        &mut measurements,
        "resolved_model_type",
        model_context
            .map(|summary| summary.model_type.as_str())
            .unwrap_or("unset"),
    );
    add_label(
        &mut measurements,
        "resolved_model_context_source",
        model_context
            .map(|summary| summary.context_source.as_str())
            .unwrap_or("unset"),
    );
    add_label(
        &mut measurements,
        "resolved_model_rope_scaling",
        model_context
            .map(|summary| summary.rope_scaling_label.as_str())
            .unwrap_or("unset"),
    );
    add_label(
        &mut measurements,
        "resolved_prompt_suite_path",
        live_inputs
            .prompt_suite_path
            .as_ref()
            .map(|path| path.display().to_string())
            .as_deref()
            .unwrap_or(DEFAULT_PROMPT_SUITE_PATH),
    );
    measurements.insert(
        "harness_wall_clock_seconds".to_string(),
        Measurement {
            value: serde_json::Value::Number(number(start.elapsed().as_secs_f64())),
            unit: "seconds".to_string(),
        },
    );

    let mut anomalies = vec![serde_json::json!({
        "kind": "partial_substrate_only",
        "detail": "Tier-1 Rust KV-Direct equality is measured, but this is not the 128K Qwen3-8B SSD-spill gate."
    })];
    if !live_inputs.model_assets_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_model_assets",
            "detail": format!("{MODEL_PATH_ENV} is unset or neither the Epistemos app-support nor HuggingFace cache Qwen3-8B MLX snapshot contains local weights.")
        }));
    } else if !model_identity_matches_canonical {
        let resolved = model_context
            .map(|summary| summary.repo_id.as_str())
            .unwrap_or("unknown");
        anomalies.push(serde_json::json!({
            "kind": "noncanonical_model_identity",
            "detail": format!(
                "Resolved model identity is `{resolved}`; F-KV-Direct-Gate is pinned to `{CANONICAL_MODEL_REPO_ID}`. Alternate long-context models may be used only as candidate-tier development evidence unless canon changes the falsifier target."
            )
        }));
    } else if !model_context_supports_required_context {
        anomalies.push(serde_json::json!({
            "kind": "model_context_window_too_small",
            "detail": format!(
                "Resolved model context window is {model_context_window_tokens} tokens; F-KV-Direct-Gate requires at least {REQUIRED_CONTEXT_WINDOW_TOKENS}. Do not rerun the 128K suite until the model asset or rope/context config honestly supports it."
            )
        }));
    }
    if prompt_suite.is_none() {
        anomalies.push(serde_json::json!({
            "kind": "missing_prompt_suite_manifest",
            "detail": format!("No KV-Direct prompt-suite manifest found. Run `cargo +stable-aarch64-apple-darwin run --manifest-path agent_core/Cargo.toml --bin kv_direct_prompt_suite` or set {PROMPT_SUITE_ENV}.")
        }));
    } else {
        if prompt_suite_prompt_count < REQUIRED_LIVE_PROMPTS {
            anomalies.push(serde_json::json!({
                "kind": "undersized_prompt_suite",
                "detail": format!("Prompt suite has {prompt_suite_prompt_count} prompts; F-KV-Direct-Gate requires at least {REQUIRED_LIVE_PROMPTS}.")
            }));
        }
        if prompt_suite_min_context_tokens < REQUIRED_CONTEXT_WINDOW_TOKENS {
            anomalies.push(serde_json::json!({
                "kind": "undersized_prompt_suite_context",
                "detail": format!("Prompt suite minimum context is {prompt_suite_min_context_tokens}; F-KV-Direct-Gate requires at least {REQUIRED_CONTEXT_WINDOW_TOKENS}.")
            }));
        }
        if prompt_suite_min_decode_tokens_per_prompt < REQUIRED_DECODE_TOKENS_PER_PROMPT {
            anomalies.push(serde_json::json!({
                "kind": "undersized_prompt_suite_decode",
                "detail": format!("Prompt suite minimum decode tokens is {prompt_suite_min_decode_tokens_per_prompt}; F-KV-Direct-Gate requires at least {REQUIRED_DECODE_TOKENS_PER_PROMPT}.")
            }));
        }
        if !prompt_suite_balanced_family_coverage {
            anomalies.push(serde_json::json!({
                "kind": "imbalanced_prompt_suite",
                "detail": "Prompt suite must include at least 25 prompts each for long_prefix_recall, multi_turn, code_completion, and reasoning."
            }));
        }
    }
    if live_inputs.logit_fixture.is_none() {
        anomalies.push(serde_json::json!({
            "kind": "missing_prompt_logits",
            "detail": "No paired reference/test logits were supplied; average_d_kl_nats remains a sentinel failure."
        }));
    }
    if live_inputs.metrics.is_none() {
        anomalies.push(serde_json::json!({
            "kind": "missing_live_metrics",
            "detail": "No live metrics JSON was supplied; peak RAM, decode tok/s, suite wall clock, and spill labeling remain sentinel failures."
        }));
    }
    if !live_inputs.spill_trace_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_spill_trace",
            "detail": format!("{SPILL_TRACE_ENV} is unset or missing; SSD-spill labeling cannot stand alone as a trace witness.")
        }));
    } else {
        if !spill_trace_route_is_canonical {
            anomalies.push(serde_json::json!({
                "kind": "noncanonical_spill_route",
                "detail": format!("Spill trace route must be `{CANONICAL_SPILL_ROUTE}`; prompt-cache reload, KV-quantized, and full-KV traces cannot satisfy F-KV-Direct-Gate.")
            }));
        }
        if !spill_trace_residual_patch_applied {
            anomalies.push(serde_json::json!({
                "kind": "missing_residual_patch_witness",
                "detail": "Spill trace must explicitly set residual_patch_applied=true for the residual-sufficiency oracle."
            }));
        }
        if !spill_trace_mmap_backed {
            anomalies.push(serde_json::json!({
                "kind": "missing_mmap_witness",
                "detail": "Spill trace must explicitly prove mmap-backed cold KV storage."
            }));
        }
        if !spill_trace_quantized_storage {
            anomalies.push(serde_json::json!({
                "kind": "missing_nf4_or_quantized_storage_witness",
                "detail": "Spill trace must label NF4 or equivalent quantized cold KV storage."
            }));
        }
        if spill_trace_cold_kv_bytes < REQUIRED_COLD_KV_BYTES {
            anomalies.push(serde_json::json!({
                "kind": "missing_cold_kv_byte_count",
                "detail": "Spill trace must include cold_kv_bytes/ssd_spill_bytes/mmap_bytes greater than zero."
            }));
        }
    }
    if prompt_count < REQUIRED_LIVE_PROMPTS {
        anomalies.push(serde_json::json!({
            "kind": "insufficient_prompt_fixture",
            "detail": format!("Live fixture has {prompt_count} prompts; F-KV-Direct-Gate requires at least {REQUIRED_LIVE_PROMPTS} prompts.")
        }));
    }
    if context_window_tokens < REQUIRED_CONTEXT_WINDOW_TOKENS {
        anomalies.push(serde_json::json!({
            "kind": "insufficient_context_window",
            "detail": format!("Metrics report {context_window_tokens} context tokens; F-KV-Direct-Gate requires at least {REQUIRED_CONTEXT_WINDOW_TOKENS}.")
        }));
    }
    if decode_tokens_per_prompt < REQUIRED_DECODE_TOKENS_PER_PROMPT {
        anomalies.push(serde_json::json!({
            "kind": "insufficient_decode_tokens",
            "detail": format!("Metrics report {decode_tokens_per_prompt} decode tokens per prompt; F-KV-Direct-Gate requires at least {REQUIRED_DECODE_TOKENS_PER_PROMPT}.")
        }));
    }
    for error in &live_inputs.parse_errors {
        anomalies.push(serde_json::json!({
            "kind": "live_input_parse_error",
            "detail": error
        }));
    }

    let overall_candidate_pass = pass_per_axis.values().copied().all(|v| v);

    let artifact = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: if overall_candidate_pass {
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
        fallback_tier: if overall_candidate_pass {
            FallbackTier::Primary
        } else {
            FallbackTier::Fail
        },
        anomalies,
        notes: format!(
            "preflight_failure_report; Tier-1 Rust equality contract measured over 1000 traces; \
             live harness contract accepts {MODEL_PATH_ENV}, {LOGITS_PATH_ENV} or paired \
             {REFERENCE_LOGITS_ENV}/{TEST_LOGITS_ENV}, {METRICS_PATH_ENV}, {SPILL_TRACE_ENV}, \
             and optional {PROMPT_SUITE_ENV}; \
             no product KV-Direct claim unless all live axes pass, including >=100 prompts, >=128000 \
             context tokens, and >=256 decode tokens per prompt"
        ),
        timestamp_utc: started_utc,
    }
    .build();

    let path = PathBuf::from("artifacts/falsifiers/kv_direct_gate/result.json");
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).expect("create kv_direct artifact directory");
    }
    let mut file = std::fs::File::create(&path).expect("open kv_direct artifact for write");
    write_artifact(&mut file, &artifact).expect("write kv_direct artifact");

    println!(
        "F-KV-Direct-Gate preflight: overall_pass={} equality_violations={} artifact={}",
        artifact.overall_pass,
        equality_violations,
        path.display()
    );

    if !artifact.overall_pass {
        std::process::exit(1);
    }
}

#[derive(Debug)]
struct LiveHarnessInputs {
    model_assets_available: bool,
    model_asset_path: Option<PathBuf>,
    model_context: Option<ModelContextSummary>,
    prompt_suite_path: Option<PathBuf>,
    prompt_suite: Option<PromptSuiteSummary>,
    reference_logits_available: bool,
    test_logits_available: bool,
    spill_trace_available: bool,
    spill_trace: Option<SpillTraceSummary>,
    logit_fixture: Option<LogitFixture>,
    metrics: Option<LiveMetrics>,
    parse_errors: Vec<String>,
}

impl LiveHarnessInputs {
    fn load_from_env() -> Self {
        let model_asset_path = discover_model_asset_path();
        let model_assets_available = model_asset_path.is_some();
        let prompt_suite_path = Some(prompt_suite_path());
        let spill_trace_path = env_path(SPILL_TRACE_ENV);
        let spill_trace_available = spill_trace_path
            .as_deref()
            .map(Path::exists)
            .unwrap_or(false);
        let mut parse_errors = Vec::new();
        let model_context = match model_asset_path.as_deref() {
            Some(path) => match load_model_context_summary(path) {
                Ok(summary) => Some(summary),
                Err(error) => {
                    parse_errors.push(format!("{}: {error}", path.join("config.json").display()));
                    None
                }
            },
            None => None,
        };

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
        let reference_logits_available = logit_fixture
            .as_ref()
            .map(|fixture| !fixture.prompts.is_empty())
            .unwrap_or(false);
        let test_logits_available = reference_logits_available;

        let metrics = match env_path(METRICS_PATH_ENV) {
            Some(path) => match load_live_metrics(&path) {
                Ok(metrics) => Some(metrics),
                Err(error) => {
                    parse_errors.push(format!("{}: {error}", path.display()));
                    None
                }
            },
            None => None,
        };
        let spill_trace = match spill_trace_path.as_deref() {
            Some(path) if path.exists() => match load_spill_trace(path) {
                Ok(trace) => Some(trace),
                Err(error) => {
                    parse_errors.push(format!("{}: {error}", path.display()));
                    None
                }
            },
            _ => None,
        };

        Self {
            model_assets_available,
            model_asset_path,
            model_context,
            prompt_suite_path,
            prompt_suite,
            reference_logits_available,
            test_logits_available,
            spill_trace_available,
            spill_trace,
            logit_fixture,
            metrics,
            parse_errors,
        }
    }
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
struct PromptSuiteSummary {
    prompt_count: u64,
    min_context_tokens: u64,
    min_decode_tokens: u64,
    balanced_family_coverage: bool,
}

#[derive(Debug)]
struct ModelContextSummary {
    repo_id: String,
    canonical_model_identity: bool,
    model_type: String,
    effective_context_window_tokens: u64,
    context_source: String,
    rope_scaling_label: String,
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

#[derive(Debug)]
struct LiveMetrics {
    peak_ram_gb: f64,
    decode_tok_s: f64,
    suite_wall_clock_min: f64,
    spill_labeling: bool,
    context_window_tokens: u64,
    decode_tokens_per_prompt: u64,
}

#[derive(Debug)]
struct SpillTraceSummary {
    route_label: String,
    route_is_canonical: bool,
    ssd_spill_labeled: bool,
    residual_patch_applied: bool,
    mmap_backed: bool,
    quantized_storage: bool,
    cold_kv_bytes: u64,
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

fn load_live_metrics(path: &Path) -> Result<LiveMetrics, String> {
    let value: serde_json::Value = read_json_file(path)?;
    let object = value
        .as_object()
        .ok_or_else(|| "metrics JSON must be an object".to_string())?;
    Ok(LiveMetrics {
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
        spill_labeling: required_bool(object, &["spill_labeling", "ssd_spill_labeled"])?,
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
    })
}

fn load_spill_trace(path: &Path) -> Result<SpillTraceSummary, String> {
    let value: serde_json::Value = read_json_file(path)?;
    summarize_spill_trace(&value)
}

fn summarize_spill_trace(value: &serde_json::Value) -> Result<SpillTraceSummary, String> {
    let object = value
        .as_object()
        .ok_or_else(|| "spill trace JSON must be an object".to_string())?;
    let route_label = optional_string(object, &["route", "test_route", "kv_route", "spill_route"])
        .unwrap_or_else(|| "unset".to_string());
    let route_is_canonical = spill_route_is_canonical(&route_label);
    let ssd_spill_labeled = optional_bool(
        object,
        &["ssd_spill_labeled", "spill_labeling", "ssd_spill"],
    )
    .unwrap_or(false);
    let residual_patch_applied = optional_bool(
        object,
        &[
            "residual_patch_applied",
            "residual_patched",
            "residual_patch",
        ],
    )
    .unwrap_or(false);
    let mmap_backed = optional_bool(
        object,
        &["mmap_backed", "cold_kv_mmap_backed", "ssd_mmap_backed"],
    )
    .unwrap_or(false);
    let quantized_storage = optional_bool(
        object,
        &["nf4_storage", "quantized_storage", "quantized_kv_storage"],
    )
    .unwrap_or_else(|| {
        optional_string(
            object,
            &[
                "kv_storage_format",
                "storage_format",
                "cold_kv_format",
                "quantized_storage_format",
            ],
        )
        .map(|value| {
            let lower = value.to_ascii_lowercase();
            lower.contains("nf4") || lower.contains("quant")
        })
        .unwrap_or(false)
    });
    let cold_kv_bytes = optional_u64(
        object,
        &[
            "cold_kv_bytes",
            "ssd_spill_bytes",
            "mmap_bytes",
            "cold_bytes",
        ],
    )
    .unwrap_or_else(|| route_trace_cold_kv_bytes(object));

    Ok(SpillTraceSummary {
        route_label,
        route_is_canonical,
        ssd_spill_labeled,
        residual_patch_applied,
        mmap_backed,
        quantized_storage,
        cold_kv_bytes,
    })
}

fn spill_route_is_canonical(route_label: &str) -> bool {
    if route_label == CANONICAL_SPILL_ROUTE {
        return true;
    }
    route_label
        .strip_prefix("merged:")
        .map(|routes| {
            routes
                .split(',')
                .filter(|route| !route.trim().is_empty())
                .all(|route| route.trim() == CANONICAL_SPILL_ROUTE)
        })
        .unwrap_or(false)
}

fn read_json_file<T: DeserializeOwned>(path: &Path) -> Result<T, String> {
    let bytes = std::fs::read(path).map_err(|error| error.to_string())?;
    serde_json::from_slice(&bytes).map_err(|error| error.to_string())
}

fn optional_string(
    object: &serde_json::Map<String, serde_json::Value>,
    keys: &[&str],
) -> Option<String> {
    keys.iter()
        .find_map(|key| object.get(*key).and_then(|value| value.as_str()))
        .map(str::to_string)
}

fn optional_bool(
    object: &serde_json::Map<String, serde_json::Value>,
    keys: &[&str],
) -> Option<bool> {
    keys.iter()
        .find_map(|key| object.get(*key).and_then(|value| value.as_bool()))
}

fn optional_u64(object: &serde_json::Map<String, serde_json::Value>, keys: &[&str]) -> Option<u64> {
    keys.iter()
        .find_map(|key| object.get(*key).and_then(|value| value.as_u64()))
}

fn route_trace_cold_kv_bytes(object: &serde_json::Map<String, serde_json::Value>) -> u64 {
    object
        .get("route_traces")
        .and_then(|value| value.as_array())
        .map(|traces| {
            traces
                .iter()
                .filter_map(|trace| trace.as_object())
                .filter_map(|trace| {
                    optional_u64(trace, &["cold_kv_bytes", "ssd_spill_bytes", "mmap_bytes"])
                })
                .sum()
        })
        .unwrap_or(0)
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

fn required_bool(
    object: &serde_json::Map<String, serde_json::Value>,
    keys: &[&str],
) -> Result<bool, String> {
    for key in keys {
        if let Some(value) = object.get(*key) {
            return value
                .as_bool()
                .ok_or_else(|| format!("metrics field `{key}` must be bool"));
        }
    }
    Err(format!("missing bool metrics field {:?}", keys))
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

fn env_path(env_name: &str) -> Option<PathBuf> {
    std::env::var_os(env_name).map(PathBuf::from)
}

fn prompt_suite_path() -> PathBuf {
    env_path(PROMPT_SUITE_ENV).unwrap_or_else(|| PathBuf::from(DEFAULT_PROMPT_SUITE_PATH))
}

fn discover_model_asset_path() -> Option<PathBuf> {
    if let Some(path) = env_path(MODEL_PATH_ENV).filter(|path| model_asset_path_is_usable(path)) {
        return Some(path);
    }

    candidate_model_roots()
        .into_iter()
        .flat_map(candidate_qwen3_8b_snapshots)
        .find(|path| model_asset_path_is_usable(path))
}

fn candidate_model_roots() -> Vec<PathBuf> {
    let mut roots = Vec::new();
    if let Some(root) = env_path("EPISTEMOS_LOCAL_MODEL_ROOT") {
        roots.push(root);
    }
    if let Some(home) = std::env::var_os("HOME") {
        roots.push(
            PathBuf::from(home)
                .join("Library")
                .join("Application Support")
                .join("Epistemos")
                .join("Models"),
        );
    }
    if let Some(user) = std::env::var_os("USER").or_else(|| std::env::var_os("LOGNAME")) {
        roots.push(
            PathBuf::from("/Users")
                .join(PathBuf::from(user))
                .join("Library")
                .join("Application Support")
                .join("Epistemos")
                .join("Models"),
        );
    }
    roots.sort();
    roots.dedup();
    roots
}

fn candidate_qwen3_8b_snapshots(root: PathBuf) -> Vec<PathBuf> {
    let repo = root.join("text").join("hub").join(DEFAULT_QWEN3_8B_SLUG);
    let snapshots_dir = repo.join("snapshots");
    let mut candidates = Vec::new();

    if let Ok(entries) = std::fs::read_dir(&snapshots_dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                candidates.push(path);
            }
        }
    }
    candidates.push(repo);
    candidates
}

fn model_asset_path_is_usable(path: &Path) -> bool {
    path.exists()
        && path.join("config.json").exists()
        && path.join("tokenizer.json").exists()
        && std::fs::read_dir(path)
            .ok()
            .map(|entries| {
                entries.flatten().any(|entry| {
                    entry
                        .path()
                        .extension()
                        .and_then(|ext| ext.to_str())
                        .map(|ext| ext == "safetensors" || ext == "gguf" || ext == "npz")
                        .unwrap_or(false)
                })
            })
            .unwrap_or(false)
}

fn load_model_context_summary(path: &Path) -> Result<ModelContextSummary, String> {
    let config_path = path.join("config.json");
    let value: serde_json::Value = read_json_file(&config_path)?;
    let object = value
        .as_object()
        .ok_or_else(|| "model config JSON must be an object".to_string())?;
    let model_type = optional_string(object, &["model_type", "architectures"])
        .unwrap_or_else(|| "unknown".to_string());
    let declared_context = optional_u64(
        object,
        &[
            "max_position_embeddings",
            "max_sequence_length",
            "max_seq_len",
            "seq_length",
            "context_length",
            "model_max_length",
        ],
    )
    .unwrap_or_default();
    let (rope_scaling_label, rope_effective_context) =
        summarize_rope_scaling(object.get("rope_scaling"), declared_context);
    let (effective_context_window_tokens, context_source) =
        if let Some(effective) = rope_effective_context.filter(|value| *value > declared_context) {
            (effective, "rope_scaling_effective_context".to_string())
        } else {
            (declared_context, "declared_config_context".to_string())
        };
    let repo_id = infer_model_repo_id(path);
    let canonical_model_identity = repo_id == CANONICAL_MODEL_REPO_ID;

    Ok(ModelContextSummary {
        repo_id,
        canonical_model_identity,
        model_type,
        effective_context_window_tokens,
        context_source,
        rope_scaling_label,
    })
}

fn summarize_rope_scaling(
    value: Option<&serde_json::Value>,
    declared_context: u64,
) -> (String, Option<u64>) {
    let Some(value) = value else {
        return ("none".to_string(), None);
    };
    if value.is_null() {
        return ("none".to_string(), None);
    }

    let label = serde_json::to_string(value).unwrap_or_else(|_| "unserializable".to_string());
    let Some(object) = value.as_object() else {
        return (label, None);
    };
    let factor = object.get("factor").and_then(|v| v.as_f64()).unwrap_or(1.0);
    let original = optional_u64(
        object,
        &[
            "original_max_position_embeddings",
            "original_context_length",
            "original_max_seq_len",
        ],
    )
    .unwrap_or(declared_context);
    let effective = if factor.is_finite() && factor > 1.0 && original > 0 {
        Some((original as f64 * factor).floor() as u64)
    } else {
        None
    };
    (label, effective)
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
            if path.to_string_lossy().contains(DEFAULT_QWEN3_8B_SLUG) {
                CANONICAL_MODEL_REPO_ID.to_string()
            } else {
                "unknown".to_string()
            }
        })
}

fn average_fixture_kl(fixture: &LogitFixture) -> Option<f64> {
    let mut total = 0.0;
    let mut count = 0usize;
    for prompt in &fixture.prompts {
        let kl = kl_divergence(&prompt.reference_logits, &prompt.test_logits)?;
        total += kl;
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

fn count_equality_violations(trace_count: u64) -> u64 {
    let mut violations = 0;
    for seed in 0..trace_count {
        let key_dim = 32;
        let count = 8 + (seed as usize % 16);
        let pairs = random_kv_pairs(seed, count, key_dim, key_dim);
        let query = deterministic_random(seed.wrapping_add(99_999), key_dim);

        if reference_qk_row(&query, &pairs) != direct_qk_row(&query, &pairs) {
            violations += 1;
        }
    }
    violations
}

fn random_kv_pairs(seed: u64, count: usize, key_dim: usize, value_dim: usize) -> Vec<KvPair> {
    (0..count)
        .map(|i| {
            KvPair::new(
                deterministic_random(seed.wrapping_add(2 * i as u64 + 1), key_dim),
                deterministic_random(seed.wrapping_add(2 * i as u64 + 2), value_dim),
            )
        })
        .collect()
}

fn deterministic_random(seed: u64, n: usize) -> Vec<f32> {
    let mut state = seed
        .wrapping_mul(2862933555777941757)
        .wrapping_add(3037000493);
    let mut out = Vec::with_capacity(n);
    for _ in 0..n {
        state = state
            .wrapping_mul(2862933555777941757)
            .wrapping_add(3037000493);
        let f = ((state >> 8) & 0xFFFFFF) as f32 / 8_388_608.0 - 1.0;
        out.push(f);
    }
    out
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

fn add_count_axis(
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
            operator: "==".to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(threshold)),
            unit: "count".to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), value == threshold);
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

fn add_label(measurements: &mut BTreeMap<String, Measurement>, axis: &str, value: &str) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::String(value.to_string()),
            unit: "label".to_string(),
        },
    );
}

fn add_optional_env_label(
    measurements: &mut BTreeMap<String, Measurement>,
    axis: &str,
    env_name: &str,
) {
    let value = std::env::var(env_name).unwrap_or_else(|_| "unset".to_string());
    add_label(measurements, axis, &value);
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
    fn equality_contract_has_zero_violations() {
        assert_eq!(count_equality_violations(1_000), 0);
    }

    #[test]
    fn dispatch_contract_routes_only_eligible_layouts_direct() {
        assert_eq!(route(&KvLayout::new(16, 64, 64, 8)), KvDispatch::Direct);
        assert_eq!(route(&KvLayout::new(15, 64, 64, 8)), KvDispatch::Reference);
        assert_eq!(route(&KvLayout::new(16, 64, 32, 8)), KvDispatch::Reference);
        assert_eq!(route(&KvLayout::new(16, 64, 64, 0)), KvDispatch::Reference);
        assert_eq!(route(&KvLayout::new(0, 64, 64, 8)), KvDispatch::Reference);
    }

    #[test]
    fn kl_divergence_is_zero_for_identical_logits() {
        let logits = [1.0, 2.0, -3.0, 0.25];
        let kl = kl_divergence(&logits, &logits).expect("valid KL");
        assert!(kl.abs() < 1e-12, "kl={kl}");
    }

    #[test]
    fn average_fixture_kl_rejects_shape_mismatch() {
        let fixture = LogitFixture {
            prompts: vec![PromptLogits {
                reference_logits: vec![1.0, 2.0],
                test_logits: vec![1.0],
            }],
        };
        assert!(average_fixture_kl(&fixture).is_none());
    }

    #[test]
    fn average_fixture_kl_uses_all_prompts() {
        let fixture = LogitFixture {
            prompts: vec![
                PromptLogits {
                    reference_logits: vec![0.0, 1.0],
                    test_logits: vec![0.0, 1.0],
                },
                PromptLogits {
                    reference_logits: vec![0.0, 1.0],
                    test_logits: vec![0.0, 0.9],
                },
            ],
        };
        let kl = average_fixture_kl(&fixture).expect("valid average KL");
        assert!(kl >= 0.0);
        assert!(kl < 0.01, "kl={kl}");
    }

    #[test]
    fn live_metrics_parser_accepts_aliases() {
        let value = serde_json::json!({
            "peak_rss_gb": 11.5,
            "decode_tokens_per_second": 12.25,
            "wall_clock_min": 8.0,
            "ssd_spill_labeled": true,
            "context_window_tokens": 128_000,
            "decode_tokens_per_prompt": 256
        });
        let path = std::env::temp_dir().join(format!(
            "epistemos_kv_direct_metrics_{}.json",
            std::process::id()
        ));
        std::fs::write(&path, serde_json::to_vec(&value).unwrap()).unwrap();
        let metrics = load_live_metrics(&path).expect("metrics parse");
        std::fs::remove_file(&path).ok();

        assert_eq!(metrics.peak_ram_gb, 11.5);
        assert_eq!(metrics.decode_tok_s, 12.25);
        assert_eq!(metrics.suite_wall_clock_min, 8.0);
        assert!(metrics.spill_labeling);
        assert_eq!(metrics.context_window_tokens, 128_000);
        assert_eq!(metrics.decode_tokens_per_prompt, 256);
    }

    #[test]
    fn model_context_loader_reads_declared_context() {
        let dir = std::env::temp_dir().join(format!(
            "epistemos_kv_direct_model_context_{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(
            dir.join("config.json"),
            serde_json::to_vec(&serde_json::json!({
                "model_type": "qwen3",
                "max_position_embeddings": 40960,
                "rope_scaling": null
            }))
            .unwrap(),
        )
        .unwrap();

        let summary = load_model_context_summary(&dir).expect("context summary");
        std::fs::remove_dir_all(&dir).ok();

        assert_eq!(summary.model_type, "qwen3");
        assert_eq!(summary.repo_id, "unknown");
        assert!(!summary.canonical_model_identity);
        assert_eq!(summary.effective_context_window_tokens, 40_960);
        assert_eq!(summary.context_source, "declared_config_context");
        assert_eq!(summary.rope_scaling_label, "none");
    }

    #[test]
    fn model_context_loader_accounts_for_rope_factor() {
        let dir = std::env::temp_dir().join(format!(
            "epistemos_kv_direct_model_context_rope_{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(
            dir.join("config.json"),
            serde_json::to_vec(&serde_json::json!({
                "model_type": "qwen3",
                "max_position_embeddings": 32768,
                "rope_scaling": {
                    "factor": 4.0,
                    "original_max_position_embeddings": 32768
                }
            }))
            .unwrap(),
        )
        .unwrap();

        let summary = load_model_context_summary(&dir).expect("context summary");
        std::fs::remove_dir_all(&dir).ok();

        assert_eq!(summary.effective_context_window_tokens, 131_072);
        assert_eq!(summary.context_source, "rope_scaling_effective_context");
    }

    #[test]
    fn model_repo_id_inference_reads_huggingface_cache_slugs() {
        let canonical_path = PathBuf::from(
            "/Users/jojo/Library/Application Support/Epistemos/Models/text/hub/models--Qwen--Qwen3-8B-MLX-4bit/snapshots/abc123",
        );
        let alternate_path = PathBuf::from(
            "/Users/jojo/Library/Application Support/Epistemos/Models/text/hub/models--mlx-community--Qwen3-Coder-Next-4bit/snapshots/abc123",
        );

        assert_eq!(
            infer_model_repo_id(&canonical_path),
            CANONICAL_MODEL_REPO_ID
        );
        assert_eq!(
            infer_model_repo_id(&alternate_path),
            "mlx-community/Qwen3-Coder-Next-4bit"
        );
    }

    #[test]
    fn model_context_loader_marks_canonical_identity_only_for_qwen3_8b_target() {
        let root = std::env::temp_dir().join(format!(
            "epistemos_kv_direct_model_identity_{}",
            std::process::id()
        ));
        let canonical_dir = root
            .join("models--Qwen--Qwen3-8B-MLX-4bit")
            .join("snapshots")
            .join("canonical");
        let alternate_dir = root
            .join("models--mlx-community--Qwen3-Coder-Next-4bit")
            .join("snapshots")
            .join("alternate");
        for dir in [&canonical_dir, &alternate_dir] {
            std::fs::create_dir_all(dir).unwrap();
            std::fs::write(
                dir.join("config.json"),
                serde_json::to_vec(&serde_json::json!({
                    "model_type": "qwen3",
                    "max_position_embeddings": 262144
                }))
                .unwrap(),
            )
            .unwrap();
        }

        let canonical = load_model_context_summary(&canonical_dir).expect("canonical summary");
        let alternate = load_model_context_summary(&alternate_dir).expect("alternate summary");
        std::fs::remove_dir_all(&root).ok();

        assert_eq!(canonical.repo_id, CANONICAL_MODEL_REPO_ID);
        assert!(canonical.canonical_model_identity);
        assert_eq!(alternate.repo_id, "mlx-community/Qwen3-Coder-Next-4bit");
        assert!(!alternate.canonical_model_identity);
    }

    #[test]
    fn spill_trace_requires_canonical_residual_mmap_nf4_route() {
        let value = serde_json::json!({
            "route": CANONICAL_SPILL_ROUTE,
            "ssd_spill_labeled": true,
            "residual_patch_applied": true,
            "mmap_backed": true,
            "kv_storage_format": "nf4",
            "cold_kv_bytes": 4096
        });
        let trace = summarize_spill_trace(&value).expect("spill trace parse");

        assert!(trace.route_is_canonical);
        assert!(trace.ssd_spill_labeled);
        assert!(trace.residual_patch_applied);
        assert!(trace.mmap_backed);
        assert!(trace.quantized_storage);
        assert_eq!(trace.cold_kv_bytes, 4096);
    }

    #[test]
    fn prompt_cache_reload_spill_trace_cannot_satisfy_canonical_route() {
        let value = serde_json::json!({
            "route": "prompt_cache_reload",
            "ssd_spill_labeled": false,
            "file_backed_cache_reload": true,
            "route_traces": [{ "cache_bytes": 75_356_889 }]
        });
        let trace = summarize_spill_trace(&value).expect("spill trace parse");

        assert!(!trace.route_is_canonical);
        assert!(!trace.ssd_spill_labeled);
        assert!(!trace.residual_patch_applied);
        assert!(!trace.mmap_backed);
        assert!(!trace.quantized_storage);
        assert_eq!(trace.cold_kv_bytes, 0);
    }

    #[test]
    fn merged_spill_trace_accepts_only_all_canonical_shards() {
        assert!(spill_route_is_canonical(&format!(
            "merged:{CANONICAL_SPILL_ROUTE},{CANONICAL_SPILL_ROUTE}"
        )));
        assert!(!spill_route_is_canonical(&format!(
            "merged:{CANONICAL_SPILL_ROUTE},prompt_cache_reload"
        )));
    }

    #[test]
    fn prompt_suite_loader_requires_balanced_100_prompt_shape() {
        let mut prompts = Vec::new();
        for family in [
            "long_prefix_recall",
            "multi_turn",
            "code_completion",
            "reasoning",
        ] {
            for _ in 0..25 {
                prompts.push(serde_json::json!({
                    "family": family,
                    "target_context_tokens": 128_000,
                    "decode_tokens": 256
                }));
            }
        }
        let value = serde_json::json!({ "prompts": prompts });
        let path = std::env::temp_dir().join(format!(
            "epistemos_kv_direct_prompt_suite_{}.json",
            std::process::id()
        ));
        std::fs::write(&path, serde_json::to_vec(&value).unwrap()).unwrap();
        let suite = load_prompt_suite(&path)
            .expect("suite parse")
            .expect("suite present");
        std::fs::remove_file(&path).ok();

        assert_eq!(suite.prompt_count, 100);
        assert_eq!(suite.min_context_tokens, 128_000);
        assert_eq!(suite.min_decode_tokens, 256);
        assert!(suite.balanced_family_coverage);
    }
}
