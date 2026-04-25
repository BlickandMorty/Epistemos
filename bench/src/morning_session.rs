// bench/morning-session
//
// Wave 2.6 of the Extended Program Plan
// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md`,
//  cross-ref dpp §1.1 Task 0.6).
//
// Synthesises a "morning session" workload and writes runtime measurements
// to `build/perf-budgets-runtime.json` for the Wave 2.5 perf-budgets gate
// (`scripts/check-perf-budgets.sh`) to consume.
//
// Honest scope notes (matters for interpreting CI output):
//
//   * cold_start_ms_p99
//       Single-sample reading of `Instant::now() at main entry → first useful
//       work done`. Captures dispatcher init + dylib load cost. NOT a true
//       p99 (only N=1); reported as both p50 and p99 = same value. Wave 6
//       (PGO sprint) is the natural place to tighten this into a true p99.
//
//   * frame_ms_p99
//       CPU-side render-driver proxy: serialize + deserialize a
//       representative 1024-node graph snapshot (matches the per-frame
//       Swift→Rust state shuttle pattern). Does NOT measure GPU frame time;
//       that requires the Metal harness deferred to Wave 4.
//
//   * mcp_invoke_ms_p99
//       Round-trip through `MCPDispatcher::dispatch(tools/list)` — the
//       same JSON-RPC entry point UniFFI calls in shipping builds. Run
//       on an in-memory dispatcher with no registered tools so we measure
//       framework cost, not handler cost.
//
//   * ffi_hot_path_us_p99
//       Round-trip through `MCPDispatcher::dispatch(initialize)` — minimal
//       JSON parse + dispatch + serialize. Closest pure-FFI proxy
//       available without bringing up Metal (graph-engine requires a
//       device pointer we cannot synthesise here).
//
// Re-runnable in CI via `scripts/run-morning-session.sh`. The bench writes
// a flat JSON object the bash parser can read with awk.

use std::fs;
use std::path::PathBuf;
use std::time::Instant;

use omega_mcp::dispatcher::MCPDispatcher;
use serde::Serialize;

// ---------------------------------------------------------------------------
// Workload sizes — kept small so the whole bench finishes inside ~5 s on
// CI hardware (macos-15 runner). Large enough that p99 is meaningful.
// ---------------------------------------------------------------------------

const FFI_HOT_PATH_ITERATIONS: usize = 2_000;
const MCP_INVOKE_ITERATIONS: usize = 500;
const FRAME_PROXY_ITERATIONS: usize = 200;
const FRAME_PROXY_NODE_COUNT: usize = 1_024;

// ---------------------------------------------------------------------------
// Output schema (matches scripts/check-perf-budgets.sh expectations)
// ---------------------------------------------------------------------------

#[derive(Serialize)]
struct RuntimeReport {
    cold_start_ms_p99: f64,
    frame_ms_p99: f64,
    mcp_invoke_ms_p99: f64,
    ffi_hot_path_us_p99: f64,
    metadata: ReportMetadata,
}

#[derive(Serialize)]
struct ReportMetadata {
    workload: &'static str,
    iterations_ffi_hot_path: usize,
    iterations_mcp_invoke: usize,
    iterations_frame_proxy: usize,
    frame_proxy_node_count: usize,
    notes: &'static str,
}

// ---------------------------------------------------------------------------
// Frame proxy state — representative of per-frame Swift→Rust shuttle.
// ---------------------------------------------------------------------------

#[derive(Serialize, serde::Deserialize)]
struct GraphFrameState {
    nodes: Vec<NodePayload>,
}

#[derive(Serialize, serde::Deserialize)]
struct NodePayload {
    id: u64,
    x: f32,
    y: f32,
    radius: f32,
    label: String,
}

fn build_frame_state(node_count: usize) -> GraphFrameState {
    GraphFrameState {
        nodes: (0..node_count)
            .map(|i| NodePayload {
                id: i as u64,
                x: (i as f32) * 0.123,
                y: (i as f32) * 0.456,
                radius: 4.0 + ((i % 8) as f32),
                label: format!("node-{i}"),
            })
            .collect(),
    }
}

// ---------------------------------------------------------------------------
// Stats helpers — sample-as-Vec, sort, index at p99.
// ---------------------------------------------------------------------------

/// p99 of a sample vector (returns 0.0 for an empty vector).
/// Uses linear interpolation between the two surrounding samples per the
/// "linear" type-7 quantile definition NumPy uses by default — matches
/// most engineers' intuition for small N.
fn percentile(samples: &mut [f64], pct: f64) -> f64 {
    if samples.is_empty() {
        return 0.0;
    }
    samples.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let n = samples.len();
    if n == 1 {
        return samples[0];
    }
    let rank = (pct / 100.0) * (n as f64 - 1.0);
    let lo = rank.floor() as usize;
    let hi = rank.ceil() as usize;
    if lo == hi {
        return samples[lo];
    }
    let frac = rank - (lo as f64);
    samples[lo] * (1.0 - frac) + samples[hi] * frac
}

// ---------------------------------------------------------------------------
// Bench routines
// ---------------------------------------------------------------------------

fn measure_ffi_hot_path_us(dispatcher: &MCPDispatcher) -> f64 {
    let request = r#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"#.to_string();
    let mut samples: Vec<f64> = Vec::with_capacity(FFI_HOT_PATH_ITERATIONS);
    // Warm-up — ignore the first 32 dispatches so the JIT-ish allocator
    // patterns are settled before we start sampling.
    for _ in 0..32 {
        let _ = dispatcher.dispatch(request.clone());
    }
    for _ in 0..FFI_HOT_PATH_ITERATIONS {
        let started = Instant::now();
        let _ = dispatcher.dispatch(request.clone());
        samples.push(started.elapsed().as_secs_f64() * 1_000_000.0); // microseconds
    }
    percentile(&mut samples, 99.0)
}

fn measure_mcp_invoke_ms(dispatcher: &MCPDispatcher) -> f64 {
    let request = r#"{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}"#.to_string();
    let mut samples: Vec<f64> = Vec::with_capacity(MCP_INVOKE_ITERATIONS);
    for _ in 0..16 {
        let _ = dispatcher.dispatch(request.clone());
    }
    for _ in 0..MCP_INVOKE_ITERATIONS {
        let started = Instant::now();
        let _ = dispatcher.dispatch(request.clone());
        samples.push(started.elapsed().as_secs_f64() * 1_000.0); // milliseconds
    }
    percentile(&mut samples, 99.0)
}

fn measure_frame_ms() -> f64 {
    let state = build_frame_state(FRAME_PROXY_NODE_COUNT);
    let mut samples: Vec<f64> = Vec::with_capacity(FRAME_PROXY_ITERATIONS);
    for _ in 0..8 {
        let json = serde_json::to_string(&state).expect("serialize warm-up");
        let _: GraphFrameState = serde_json::from_str(&json).expect("deserialize warm-up");
    }
    for _ in 0..FRAME_PROXY_ITERATIONS {
        let started = Instant::now();
        let json = serde_json::to_string(&state).expect("serialize");
        let _: GraphFrameState = serde_json::from_str(&json).expect("deserialize");
        samples.push(started.elapsed().as_secs_f64() * 1_000.0);
    }
    percentile(&mut samples, 99.0)
}

// ---------------------------------------------------------------------------
// Output discovery — write into <repo-root>/build/perf-budgets-runtime.json.
// ---------------------------------------------------------------------------

fn build_dir() -> PathBuf {
    // CARGO_MANIFEST_DIR is baked in at compile time via env!(), so the
    // bench writes to a stable absolute path regardless of cwd at runtime.
    // (std::env::var would only work during `cargo run`, not for an
    // already-compiled binary invoked by scripts/run-morning-session.sh.)
    let manifest_dir = env!("CARGO_MANIFEST_DIR");
    let repo_root = PathBuf::from(manifest_dir)
        .parent()
        .map(|p| p.to_path_buf())
        .unwrap_or_else(|| PathBuf::from("."));
    repo_root.join("build")
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

fn main() {
    let main_started = Instant::now();

    // Initialise dispatcher (in-memory logger so the bench has zero side
    // effects on the host filesystem outside of the JSON output).
    let dispatcher = MCPDispatcher::new_in_memory();

    let cold_start_ms = main_started.elapsed().as_secs_f64() * 1_000.0;

    println!("==> bench/morning-session (Wave 2.6)");
    println!("    cold_start_ms        : {cold_start_ms:.3}");
    let ffi_hot_path_us = measure_ffi_hot_path_us(&dispatcher);
    println!("    ffi_hot_path_us_p99  : {ffi_hot_path_us:.3}");
    let mcp_invoke_ms = measure_mcp_invoke_ms(&dispatcher);
    println!("    mcp_invoke_ms_p99    : {mcp_invoke_ms:.3}");
    let frame_ms = measure_frame_ms();
    println!("    frame_ms_p99         : {frame_ms:.3}");

    let report = RuntimeReport {
        cold_start_ms_p99: cold_start_ms,
        frame_ms_p99: frame_ms,
        mcp_invoke_ms_p99: mcp_invoke_ms,
        ffi_hot_path_us_p99: ffi_hot_path_us,
        metadata: ReportMetadata {
            workload: "morning-session-v0",
            iterations_ffi_hot_path: FFI_HOT_PATH_ITERATIONS,
            iterations_mcp_invoke: MCP_INVOKE_ITERATIONS,
            iterations_frame_proxy: FRAME_PROXY_ITERATIONS,
            frame_proxy_node_count: FRAME_PROXY_NODE_COUNT,
            notes:
                "cold_start = single sample (proxy); frame_ms = JSON state shuttle proxy \
                 (true GPU frame in Wave 4 harness); mcp_invoke + ffi_hot_path = real \
                 dispatcher round-trips on an in-memory MCPDispatcher.",
        },
    };

    let out_dir = build_dir();
    if let Err(e) = fs::create_dir_all(&out_dir) {
        eprintln!("morning-session: failed to create {}: {e}", out_dir.display());
        std::process::exit(1);
    }
    let out_path = out_dir.join("perf-budgets-runtime.json");
    let json = serde_json::to_string_pretty(&report).expect("serialize report");
    if let Err(e) = fs::write(&out_path, json) {
        eprintln!("morning-session: failed to write {}: {e}", out_path.display());
        std::process::exit(1);
    }
    println!("==> wrote {}", out_path.display());
}
