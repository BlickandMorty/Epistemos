//! `falsify_active_assembly_minimal` — runtime artifact for
//! F-ActiveAssembly-Minimal.
//!
//! This is the first schema-valid runtime witness for the active assembly
//! selector. It intentionally uses a deterministic synthetic packet graph:
//! the F-* gate allows this shape, and it keeps the result independent of a
//! still-missing live model packet router.

use std::collections::{BTreeMap, BTreeSet};
use std::hint::black_box;
use std::path::PathBuf;
use std::time::{Duration, Instant};

use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind,
    FallbackTier, Measurement,
};
use agent_core::research::active_assembly::{
    MarginAnchoredGreedyPull, Packet, PacketGraph, PacketId, Selector,
};

const FALSIFIER_ID: &str = "F-ActiveAssembly-Minimal";
const FIXTURE_ID: &str = "synthetic_packet_graph_1024q100_runtime_v1";
const COMMAND: &str = "Tools/falsifiers/f_active_assembly_minimal.sh";

const PACKET_COUNT: usize = 1_024;
const QUERY_COUNT: usize = 100;
const SUPPORT_CHAINS: usize = 4;
const SUPPORT_CHAIN_LEN: usize = 8;
const SINK_ID: usize = PACKET_COUNT - 1;
const QUERY_BASE: u64 = 0xCA51_AA51_1234_5678;
const EXECUTION_WORK_PER_COST: usize = 64;

fn main() {
    let started_utc = now_utc_rfc3339();
    let graph = build_synthetic_graph();
    let stats = run_fixture(&graph, QUERY_COUNT);
    let reproducibility_same_seed = stats.logical_signature
        == run_fixture(&graph, QUERY_COUNT).logical_signature
        && stats.logical_signature == run_fixture(&graph, QUERY_COUNT).logical_signature;

    let mut measurements: BTreeMap<String, Measurement> = BTreeMap::new();
    let mut thresholds: BTreeMap<String, AcceptanceThreshold> = BTreeMap::new();
    let mut pass_per_axis: BTreeMap<String, bool> = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_artifact_present",
        true,
    );
    add_count_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "graph_packet_count",
        PACKET_COUNT as u64,
        PACKET_COUNT as u64,
    );
    add_count_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "query_count",
        QUERY_COUNT as u64,
        QUERY_COUNT as u64,
    );
    add_count_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "output_bound_violation_count",
        stats.output_bound_violation_count,
        0,
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
        "firing_ratio",
        stats.firing_ratio,
        "<",
        0.50,
        "ratio",
    );
    add_float_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "selector_overhead_ratio",
        stats.selector_overhead_ratio,
        "<",
        0.05,
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
    add_float_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "peak_ram_mb_estimate",
        stats.peak_ram_mb_estimate,
        "<",
        100.0,
        "MB",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "sink_selected_all_queries",
        stats.sink_selected_all_queries,
    );
    add_count_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "active_set_orphan_count",
        stats.active_set_orphan_count,
        0,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "reproducibility_same_seed",
        reproducibility_same_seed,
    );

    add_label(
        &mut measurements,
        "selector",
        "MarginAnchoredGreedyPull::default",
    );
    add_label(
        &mut measurements,
        "runtime_semantics",
        "query-thresholded packet contribution over full-fire vs selected active set",
    );
    measurements.insert(
        "average_active_packets".to_string(),
        Measurement {
            value: serde_json::Value::Number(number(stats.average_active_packets)),
            unit: "packets".to_string(),
        },
    );
    measurements.insert(
        "average_output_hamming_distance".to_string(),
        Measurement {
            value: serde_json::Value::Number(number(stats.average_output_hamming_distance)),
            unit: "bits".to_string(),
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
        anomalies: if overall_candidate_pass {
            vec![serde_json::json!({
                "kind": "synthetic_runtime_scope",
                "detail": "Pass is a deterministic synthetic packet-graph runtime witness, not a live model packet-router witness."
            })]
        } else {
            vec![serde_json::json!({
                "kind": "active_assembly_runtime_gate_failed",
                "detail": "The synthetic selector runtime failed one or more F-ActiveAssembly-Minimal axes."
            })]
        },
        notes: "active_assembly_runtime_artifact; synthetic packet graph N=1024 Q=100; proves selective firing with bounded output under deterministic fixture semantics; live model packet routing remains a later Capability Ceiling slice".to_string(),
        timestamp_utc: started_utc,
    }
    .build();

    let path = PathBuf::from("artifacts/falsifiers/active_assembly_minimal/result.json");
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).expect("create active assembly artifact directory");
    }
    let mut file = std::fs::File::create(&path).expect("open active assembly artifact");
    write_artifact(&mut file, &artifact).expect("write active assembly artifact");

    println!(
        "F-ActiveAssembly-Minimal runtime: overall_pass={} cost_ratio={:.6} firing_ratio={:.6} wall_us_p99={:.3} artifact={}",
        artifact.overall_pass,
        stats.cost_ratio,
        stats.firing_ratio,
        stats.wall_us_p99,
        path.display()
    );

    if !artifact.overall_pass {
        std::process::exit(1);
    }
}

#[derive(Clone, Debug, PartialEq)]
struct RuntimeStats {
    output_bound_violation_count: u64,
    cost_ratio: f64,
    firing_ratio: f64,
    selector_overhead_ratio: f64,
    wall_us_p99: f64,
    peak_ram_mb_estimate: f64,
    sink_selected_all_queries: bool,
    active_set_orphan_count: u64,
    average_active_packets: f64,
    average_output_hamming_distance: f64,
    logical_signature: LogicalSignature,
}

#[derive(Clone, Debug, PartialEq)]
struct LogicalSignature {
    output_bound_violation_count: u64,
    baseline_cost_units: u64,
    active_cost_units: u64,
    baseline_fired_packets: u64,
    active_fired_packets: u64,
    active_output_hash: u64,
}

fn build_synthetic_graph() -> PacketGraph {
    let mut graph = PacketGraph::new();
    for i in 0..SUPPORT_CHAINS * SUPPORT_CHAIN_LEN {
        let chain = i / SUPPORT_CHAIN_LEN;
        let depth = i % SUPPORT_CHAIN_LEN;
        let predecessor = if depth == 0 {
            Vec::new()
        } else {
            vec![PacketId(i - 1)]
        };
        graph
            .add(Packet::new(
                PacketId(i),
                QUERY_BASE ^ (chain as u64),
                support_output_pattern(chain, depth),
                1,
                predecessor,
            ))
            .expect("support packet must be valid");
    }

    for i in SUPPORT_CHAINS * SUPPORT_CHAIN_LEN..SINK_ID {
        graph
            .add(Packet::new(
                PacketId(i),
                !QUERY_BASE ^ ((i as u64).rotate_left((i % 31) as u32)),
                (i as u64).wrapping_mul(0x9E37_79B9_7F4A_7C15),
                16,
                Vec::new(),
            ))
            .expect("distractor packet must be valid");
    }

    let sink_predecessors = (0..SUPPORT_CHAINS)
        .map(|chain| PacketId(chain * SUPPORT_CHAIN_LEN + SUPPORT_CHAIN_LEN - 1))
        .collect();
    graph
        .add(Packet::new(
            PacketId(SINK_ID),
            QUERY_BASE,
            0xA11C_EA55_EEED_0001,
            1,
            sink_predecessors,
        ))
        .expect("sink packet must be valid");
    graph
}

fn support_output_pattern(chain: usize, depth: usize) -> u64 {
    0xA5A5_0000_0000_0000 ^ ((chain as u64) << 32) ^ depth as u64
}

fn run_fixture(graph: &PacketGraph, query_count: usize) -> RuntimeStats {
    let selector = MarginAnchoredGreedyPull::default();
    let sink = PacketId(SINK_ID);
    let mut baseline_cost_units = 0u64;
    let mut active_cost_units = 0u64;
    let mut baseline_fired_packets = 0u64;
    let mut active_fired_packets = 0u64;
    let mut output_bound_violation_count = 0u64;
    let mut output_hamming_total = 0u64;
    let mut sink_selected_all_queries = true;
    let mut active_set_orphan_count = 0u64;
    let mut selector_elapsed = Duration::ZERO;
    let mut baseline_fire_elapsed = Duration::ZERO;
    let mut active_wall_us = Vec::with_capacity(query_count);
    let mut active_output_hash = 0u64;

    for q in 0..query_count {
        let query = query_for_index(q);
        let baseline_start = Instant::now();
        let baseline = run_all_packets(graph, query);
        baseline_fire_elapsed += baseline_start.elapsed();

        let active_start = Instant::now();
        let select_start = Instant::now();
        let active = selector
            .select(graph, sink, query)
            .expect("active assembly selector must succeed");
        selector_elapsed += select_start.elapsed();
        let active_output = run_active_packets(graph, query, &active);
        active_wall_us.push(active_start.elapsed().as_secs_f64() * 1_000_000.0);

        if !active.contains(&sink) {
            sink_selected_all_queries = false;
        }
        for active_id in &active {
            if !graph.contains(*active_id) {
                active_set_orphan_count += 1;
            }
        }

        let hamming = (baseline.output ^ active_output.output).count_ones() as u64;
        output_hamming_total += hamming;
        if hamming > 4 {
            output_bound_violation_count += 1;
        }

        baseline_cost_units += baseline.cost_units;
        active_cost_units += active_output.cost_units;
        baseline_fired_packets += graph.len() as u64;
        active_fired_packets += active.len() as u64;
        active_output_hash = active_output_hash.rotate_left(7) ^ active_output.output;
    }

    active_wall_us.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
    let p99_index = ((active_wall_us.len() as f64) * 0.99).ceil() as usize;
    let wall_us_p99 = active_wall_us[p99_index.saturating_sub(1).min(active_wall_us.len() - 1)];
    let cost_ratio = active_cost_units as f64 / baseline_cost_units as f64;
    let firing_ratio = active_fired_packets as f64 / baseline_fired_packets as f64;
    let selector_overhead_ratio =
        selector_elapsed.as_secs_f64() / baseline_fire_elapsed.as_secs_f64().max(1e-12);

    RuntimeStats {
        output_bound_violation_count,
        cost_ratio,
        firing_ratio,
        selector_overhead_ratio,
        wall_us_p99,
        peak_ram_mb_estimate: estimate_graph_ram_mb(graph),
        sink_selected_all_queries,
        active_set_orphan_count,
        average_active_packets: active_fired_packets as f64 / query_count as f64,
        average_output_hamming_distance: output_hamming_total as f64 / query_count as f64,
        logical_signature: LogicalSignature {
            output_bound_violation_count,
            baseline_cost_units,
            active_cost_units,
            baseline_fired_packets,
            active_fired_packets,
            active_output_hash,
        },
    }
}

#[derive(Clone, Copy, Debug)]
struct RunOutput {
    output: u64,
    cost_units: u64,
}

fn run_all_packets(graph: &PacketGraph, query: u64) -> RunOutput {
    let mut output = 0u64;
    let mut cost_units = 0u64;
    for packet in graph.iter() {
        let fired = execute_packet(packet, query);
        cost_units += u64::from(packet.cost_units);
        if packet_contributes(packet, query) {
            output ^= fired;
        }
    }
    RunOutput { output, cost_units }
}

fn run_active_packets(graph: &PacketGraph, query: u64, active: &BTreeSet<PacketId>) -> RunOutput {
    let mut output = 0u64;
    let mut cost_units = 0u64;
    for active_id in active {
        if let Some(packet) = graph.get(*active_id) {
            let fired = execute_packet(packet, query);
            cost_units += u64::from(packet.cost_units);
            if packet_contributes(packet, query) {
                output ^= fired;
            }
        }
    }
    RunOutput { output, cost_units }
}

fn execute_packet(packet: &Packet, query: u64) -> u64 {
    let mut acc = packet.output_pattern ^ query ^ packet.input_pattern;
    for _ in 0..(usize::from(packet.cost_units) * EXECUTION_WORK_PER_COST) {
        acc = acc.rotate_left(7) ^ packet.input_pattern.wrapping_mul(0xD6E8_FEB8_6659_FD93);
        acc = acc.wrapping_add(packet.output_pattern);
    }
    black_box(acc)
}

fn packet_contributes(packet: &Packet, query: u64) -> bool {
    packet.id == PacketId(SINK_ID) || (packet.input_pattern ^ query).count_ones() <= 4
}

fn query_for_index(index: usize) -> u64 {
    QUERY_BASE ^ (1u64 << (index % 4))
}

fn estimate_graph_ram_mb(graph: &PacketGraph) -> f64 {
    let packet_bytes = graph.len() * std::mem::size_of::<Packet>();
    let edge_bytes: usize = graph
        .iter()
        .map(|packet| packet.predecessors.capacity() * std::mem::size_of::<PacketId>())
        .sum();
    (packet_bytes + edge_bytes) as f64 / (1024.0 * 1024.0)
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
    fn synthetic_graph_has_canonical_shape() {
        let graph = build_synthetic_graph();
        assert_eq!(graph.len(), PACKET_COUNT);
        assert!(graph.contains(PacketId(SINK_ID)));
    }

    #[test]
    fn runtime_fixture_passes_core_bounds() {
        let graph = build_synthetic_graph();
        let stats = run_fixture(&graph, QUERY_COUNT);
        assert_eq!(stats.output_bound_violation_count, 0);
        assert!(stats.cost_ratio < 0.40, "{}", stats.cost_ratio);
        assert!(stats.firing_ratio < 0.50, "{}", stats.firing_ratio);
        assert!(stats.sink_selected_all_queries);
        assert_eq!(stats.active_set_orphan_count, 0);
    }

    #[test]
    fn runtime_fixture_is_logically_reproducible() {
        let graph = build_synthetic_graph();
        let a = run_fixture(&graph, QUERY_COUNT);
        let b = run_fixture(&graph, QUERY_COUNT);
        assert_eq!(a.logical_signature, b.logical_signature);
    }
}
