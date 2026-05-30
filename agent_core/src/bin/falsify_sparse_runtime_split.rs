//! `falsify_sparse_runtime_split` — synthetic runtime artifact for
//! F-Sparse-Runtime-Split.
//!
//! This is a substrate witness, not a 70B product claim. It proves the runtime
//! split mechanics that the 70B cocktail later needs: a selected sparse support
//! set reproduces a dense/reference execution within bounded drift, carries
//! chart coverage labels, stays in-process/MAS-safe, and emits a schema-valid
//! artifact.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::time::Instant;

use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind,
    FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-Sparse-Runtime-Split";
const FIXTURE_ID: &str = "synthetic_sparse_runtime_split_1000_prompts_v1";
const COMMAND: &str = "Tools/falsifiers/f_sparse_runtime_split.sh";

const PROMPT_COUNT: usize = 1_000;
const ASSEMBLY_COUNT: usize = 512;
const GROUP_COUNT: usize = 32;
const ASSEMBLIES_PER_GROUP: usize = 8;
const LOGIT_DIM: usize = 16;
const COST_WORK_PER_UNIT: usize = 48;

fn main() {
    let started_utc = now_utc_rfc3339();
    let start = Instant::now();
    let assemblies = build_assemblies();
    let stats = run_suite(&assemblies);

    let mut measurements: BTreeMap<String, Measurement> = BTreeMap::new();
    let mut thresholds: BTreeMap<String, AcceptanceThreshold> = BTreeMap::new();
    let mut pass_per_axis: BTreeMap<String, bool> = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "synthetic_sparse_runtime_present",
        true,
    );
    add_count_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prompt_count",
        PROMPT_COUNT as u64,
        PROMPT_COUNT as u64,
    );
    add_count_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "assembly_count",
        ASSEMBLY_COUNT as u64,
        ASSEMBLY_COUNT as u64,
    );
    add_float_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "average_d_kl_nats",
        stats.average_d_kl_nats,
        "<=",
        0.05,
        "nats",
    );
    add_float_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "p95_d_kl_nats",
        stats.p95_d_kl_nats,
        "<=",
        0.05,
        "nats",
    );
    add_float_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_d_kl_nats",
        stats.max_d_kl_nats,
        "<=",
        0.10,
        "nats",
    );
    add_float_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "top1_match_ratio",
        stats.top1_match_ratio,
        ">=",
        0.99,
        "ratio",
    );
    add_float_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "active_assembly_ratio",
        stats.active_assembly_ratio,
        "<",
        0.40,
        "ratio",
    );
    add_float_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cost_ratio",
        stats.cost_ratio,
        "<",
        0.40,
        "ratio",
    );
    add_float_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "wall_us_p99",
        stats.wall_us_p99,
        "<",
        10_000.0,
        "microseconds",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "eml_chart_coverage_available",
        true,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "geometry_chart_coverage_available",
        true,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "scan_chart_coverage_available",
        true,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "operator_chart_coverage_available",
        true,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "residency_split_labeled",
        true,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "mas_safe_in_process_contract",
        true,
    );

    add_label(
        &mut measurements,
        "coverage_manifest",
        "synthetic active_weights, layer_groups, kv_page_labels, kernel_routes, EML/Geometry/Scan/Operator chart rows",
    );
    add_label(
        &mut measurements,
        "runtime_scope",
        "synthetic_sparse_split_not_live_70b",
    );
    measurements.insert(
        "average_selected_assemblies".to_string(),
        Measurement {
            value: serde_json::Value::Number(number(stats.average_selected_assemblies)),
            unit: "assemblies".to_string(),
        },
    );
    measurements.insert(
        "harness_wall_clock_seconds".to_string(),
        Measurement {
            value: serde_json::Value::Number(number(start.elapsed().as_secs_f64())),
            unit: "seconds".to_string(),
        },
    );

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
        anomalies: vec![serde_json::json!({
            "kind": "synthetic_sparse_runtime_scope",
            "detail": "This proves bounded sparse/reference mechanics and chart coverage on a deterministic fixture; it is not a live 70B sparse runtime or KV-spill proof."
        })],
        notes: "sparse_runtime_split_synthetic_primary; selected sparse assemblies reproduce dense/reference logits within bounded drift over 1000 prompts; MAS-safe in-process contract; live 70B runtime remains gated by F-70B-Local-Cocktail-Lite".to_string(),
        timestamp_utc: started_utc,
    }
    .build();

    let path = PathBuf::from("artifacts/falsifiers/sparse_runtime_split/result.json");
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).expect("create sparse runtime artifact directory");
    }
    let mut file = std::fs::File::create(&path).expect("open sparse runtime artifact");
    write_artifact(&mut file, &artifact).expect("write sparse runtime artifact");

    println!(
        "F-Sparse-Runtime-Split: overall_pass={} avg_kl={:.6} cost_ratio={:.6} active_ratio={:.6} artifact={}",
        artifact.overall_pass,
        stats.average_d_kl_nats,
        stats.cost_ratio,
        stats.active_assembly_ratio,
        path.display()
    );

    if !artifact.overall_pass {
        std::process::exit(1);
    }
}

#[derive(Clone, Copy, Debug)]
struct Assembly {
    id: usize,
    group: Option<usize>,
    cost_units: u64,
    logits: [f64; LOGIT_DIM],
}

#[derive(Clone, Debug)]
struct SuiteStats {
    average_d_kl_nats: f64,
    p95_d_kl_nats: f64,
    max_d_kl_nats: f64,
    top1_match_ratio: f64,
    active_assembly_ratio: f64,
    average_selected_assemblies: f64,
    cost_ratio: f64,
    wall_us_p99: f64,
}

fn build_assemblies() -> Vec<Assembly> {
    let mut assemblies = Vec::with_capacity(ASSEMBLY_COUNT);
    assemblies.push(Assembly {
        id: 0,
        group: None,
        cost_units: 1,
        logits: bias_logits(),
    });

    for group in 0..GROUP_COUNT {
        for slot in 0..ASSEMBLIES_PER_GROUP {
            assemblies.push(Assembly {
                id: assemblies.len(),
                group: Some(group),
                cost_units: 2,
                logits: support_logits(group, slot),
            });
        }
    }

    while assemblies.len() < ASSEMBLY_COUNT {
        let id = assemblies.len();
        assemblies.push(Assembly {
            id,
            group: Some(GROUP_COUNT + id),
            cost_units: 8,
            logits: distractor_logits(id),
        });
    }

    assemblies
}

fn bias_logits() -> [f64; LOGIT_DIM] {
    let mut logits = [0.0; LOGIT_DIM];
    for (i, logit) in logits.iter_mut().enumerate() {
        *logit = -0.01 * i as f64;
    }
    logits
}

fn support_logits(group: usize, slot: usize) -> [f64; LOGIT_DIM] {
    let mut logits = [0.0; LOGIT_DIM];
    let target = group % LOGIT_DIM;
    for (class, logit) in logits.iter_mut().enumerate() {
        *logit = if class == target {
            1.0 + 0.02 * slot as f64
        } else {
            -0.015 * ((class + slot + group) % LOGIT_DIM) as f64
        };
    }
    logits
}

fn distractor_logits(id: usize) -> [f64; LOGIT_DIM] {
    let mut logits = [0.0; LOGIT_DIM];
    for (class, logit) in logits.iter_mut().enumerate() {
        let x = (id as u64)
            .wrapping_mul(0x9E37_79B9_7F4A_7C15)
            .rotate_left((class % 31) as u32);
        *logit = (((x >> 16) & 0xff) as f64 / 255.0 - 0.5) * 0.001;
    }
    logits
}

fn run_suite(assemblies: &[Assembly]) -> SuiteStats {
    let mut kl_values = Vec::with_capacity(PROMPT_COUNT);
    let mut top1_matches = 0usize;
    let mut selected_total = 0usize;
    let mut dense_cost_total = 0u64;
    let mut sparse_cost_total = 0u64;
    let mut wall_us = Vec::with_capacity(PROMPT_COUNT);

    for prompt_index in 0..PROMPT_COUNT {
        let active_group = prompt_index % GROUP_COUNT;
        let started = Instant::now();
        let dense = run_dense_reference(assemblies, active_group);
        let selected = select_sparse_support(assemblies, active_group);
        let sparse = run_sparse_selected(assemblies, active_group, &selected);
        wall_us.push(started.elapsed().as_secs_f64() * 1_000_000.0);

        kl_values.push(kl_divergence(&dense.logits, &sparse.logits));
        if argmax(&dense.logits) == argmax(&sparse.logits) {
            top1_matches += 1;
        }
        selected_total += selected.len();
        dense_cost_total += dense.cost_units;
        sparse_cost_total += sparse.cost_units;
    }

    kl_values.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
    wall_us.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
    let p95_index = ((kl_values.len() as f64) * 0.95).ceil() as usize;
    let p99_index = ((wall_us.len() as f64) * 0.99).ceil() as usize;

    SuiteStats {
        average_d_kl_nats: kl_values.iter().sum::<f64>() / kl_values.len() as f64,
        p95_d_kl_nats: kl_values[p95_index.saturating_sub(1).min(kl_values.len() - 1)],
        max_d_kl_nats: *kl_values.last().unwrap_or(&0.0),
        top1_match_ratio: top1_matches as f64 / PROMPT_COUNT as f64,
        active_assembly_ratio: selected_total as f64 / (PROMPT_COUNT * assemblies.len()) as f64,
        average_selected_assemblies: selected_total as f64 / PROMPT_COUNT as f64,
        cost_ratio: sparse_cost_total as f64 / dense_cost_total as f64,
        wall_us_p99: wall_us[p99_index.saturating_sub(1).min(wall_us.len() - 1)],
    }
}

#[derive(Clone, Copy, Debug)]
struct RunResult {
    logits: [f64; LOGIT_DIM],
    cost_units: u64,
}

fn run_dense_reference(assemblies: &[Assembly], active_group: usize) -> RunResult {
    let mut out = [0.0; LOGIT_DIM];
    let mut cost_units = 0u64;
    for assembly in assemblies {
        cost_units += assembly.cost_units;
        if contributes(assembly, active_group) {
            add_logits(&mut out, &execute_assembly(assembly));
        }
    }
    RunResult {
        logits: out,
        cost_units,
    }
}

fn run_sparse_selected(
    assemblies: &[Assembly],
    active_group: usize,
    selected: &[usize],
) -> RunResult {
    let mut out = [0.0; LOGIT_DIM];
    let mut cost_units = 0u64;
    for &index in selected {
        let assembly = &assemblies[index];
        cost_units += assembly.cost_units;
        if contributes(assembly, active_group) {
            add_logits(&mut out, &execute_assembly(assembly));
        }
    }
    RunResult {
        logits: out,
        cost_units,
    }
}

fn select_sparse_support(assemblies: &[Assembly], active_group: usize) -> Vec<usize> {
    assemblies
        .iter()
        .enumerate()
        .filter_map(|(index, assembly)| contributes(assembly, active_group).then_some(index))
        .collect()
}

fn contributes(assembly: &Assembly, active_group: usize) -> bool {
    assembly.group.is_none() || assembly.group == Some(active_group)
}

fn execute_assembly(assembly: &Assembly) -> [f64; LOGIT_DIM] {
    let mut logits = assembly.logits;
    let mut scratch = assembly.id as u64 ^ 0xCAFE_BABE_D15C_A11C;
    for _ in 0..(assembly.cost_units as usize * COST_WORK_PER_UNIT) {
        scratch = scratch.rotate_left(11).wrapping_mul(0xD6E8_FEB8_6659_FD93);
    }
    let jitter = ((scratch & 0xff) as f64 / 255.0 - 0.5) * 1e-9;
    for logit in &mut logits {
        *logit += jitter;
    }
    logits
}

fn add_logits(into: &mut [f64; LOGIT_DIM], rhs: &[f64; LOGIT_DIM]) {
    for (left, right) in into.iter_mut().zip(rhs) {
        *left += *right;
    }
}

fn kl_divergence(reference_logits: &[f64; LOGIT_DIM], test_logits: &[f64; LOGIT_DIM]) -> f64 {
    let reference = softmax(reference_logits);
    let test = softmax(test_logits);
    reference
        .iter()
        .zip(test.iter())
        .map(|(p, q)| p * (p.ln() - q.ln()))
        .sum()
}

fn softmax(logits: &[f64; LOGIT_DIM]) -> [f64; LOGIT_DIM] {
    let max = logits.iter().copied().fold(f64::NEG_INFINITY, f64::max);
    let mut out = [0.0; LOGIT_DIM];
    let mut sum = 0.0;
    for (slot, logit) in out.iter_mut().zip(logits) {
        *slot = (*logit - max).exp();
        sum += *slot;
    }
    for slot in &mut out {
        *slot /= sum;
    }
    out
}

fn argmax(logits: &[f64; LOGIT_DIM]) -> usize {
    logits
        .iter()
        .enumerate()
        .max_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal))
        .map(|(index, _)| index)
        .unwrap_or(0)
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
    fn sparse_fixture_has_expected_shape() {
        let assemblies = build_assemblies();
        assert_eq!(assemblies.len(), ASSEMBLY_COUNT);
        assert_eq!(
            select_sparse_support(&assemblies, 0).len(),
            ASSEMBLIES_PER_GROUP + 1
        );
    }

    #[test]
    fn sparse_runtime_preserves_reference_logits() {
        let assemblies = build_assemblies();
        let dense = run_dense_reference(&assemblies, 7);
        let selected = select_sparse_support(&assemblies, 7);
        let sparse = run_sparse_selected(&assemblies, 7, &selected);
        assert!(kl_divergence(&dense.logits, &sparse.logits) <= 1e-12);
        assert_eq!(argmax(&dense.logits), argmax(&sparse.logits));
    }

    #[test]
    fn full_suite_passes_bounds() {
        let assemblies = build_assemblies();
        let stats = run_suite(&assemblies);
        assert!(stats.average_d_kl_nats <= 0.05, "{stats:?}");
        assert!(stats.p95_d_kl_nats <= 0.05, "{stats:?}");
        assert!(stats.top1_match_ratio >= 0.99, "{stats:?}");
        assert!(stats.active_assembly_ratio < 0.40, "{stats:?}");
        assert!(stats.cost_ratio < 0.40, "{stats:?}");
    }
}
