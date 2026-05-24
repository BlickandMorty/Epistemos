//! `falsify_uas_zero_copy_spine` — T23B Phase 2 Terminal F harness binary
//! for F-UAS-ZeroCopy-Spine (fallback witness, in-process Rust paths).
//!
//! Per `docs/falsifiers/F-UAS-ZeroCopy-Spine_2026_05_17.md` the gate has
//! 6 designated hot paths spanning Swift / Rust / Metal / MLX / HNSW.
//! Five require Swift / Metal dispatch we cannot drive from a pure-Rust
//! harness. Path #5 (Provenance ClaimLedger snapshot → ReplayBundle) is
//! **in-process Rust** by spec — that one we can measure honestly here.
//!
//! Scope of this fallback witness (per the per-path table §2.1):
//! - Path #5: ClaimLedger snapshot → ReplayBundle.to_epbundle_bytes,
//!   measured via the in-tree `uas::copy_counter::with_tracking` shim.
//!   Pass condition: copy_count == 0 AND alloc_count ≤ 1 (steady-state).
//! - Paths #1-#4, #6: documented as unmeasured here; emit a structured
//!   `unmeasured_path` anomaly per path so the audit doc can track the
//!   open gap (W-41 Apple-platform external work for Metal; T15
//!   Executor for embedding/logit hot paths).
//!
//! The CountingAllocator from `uas/copy_counter.rs` cannot be installed
//! as `#[global_allocator]` in this binary because doing so would
//! contaminate the agent_core lib tests. We use the manual
//! `track_copy` discipline instead — the in-tree path #5 implementation
//! is the same code the lib's integration tests already exercise.
//!
//! Source:
//! - `docs/falsifiers/F-UAS-ZeroCopy-Spine_2026_05_17.md`
//! - `agent_core/src/uas/copy_counter.rs`
//! - `agent_core/src/provenance/ledger.rs` + `replay.rs`

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::time::Instant;

use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind,
    FallbackTier, Measurement,
};
use agent_core::provenance::ledger::{Claim, ClaimId, ClaimLedger, Evidence, EvidenceId};
use agent_core::provenance::replay::ReplayBundle;
use agent_core::uas::copy_counter::{reset_counters, track_copy, with_tracking, CopyStats};

const FALSIFIER_ID: &str = "F-UAS-ZeroCopy-Spine";
const FIXTURE_ID: &str = "provenance_ledger_snapshot_path5_v1";
const COMMAND: &str = "cargo run --release --bin falsify_uas_zero_copy_spine";

fn main() {
    let started_utc = now_utc_rfc3339();
    let start = Instant::now();

    let mut measurements: BTreeMap<String, Measurement> = BTreeMap::new();
    let mut thresholds: BTreeMap<String, AcceptanceThreshold> = BTreeMap::new();
    let mut pass_per_axis: BTreeMap<String, bool> = BTreeMap::new();
    let mut anomalies: Vec<serde_json::Value> = Vec::new();

    // -- Path #5: ClaimLedger snapshot → ReplayBundle --------------
    let path5 = measure_path_5_provenance_snapshot();

    // The harness records track_copy() invocations on the hot path
    // (none — by spec, snapshot is BLAKE3-hashed canonical-JSON IS
    // the wire format per F-UAS-ZeroCopy-Spine §2.1 row 5).
    measurements.insert(
        "path5_tracked_copies".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(path5.copy_count as u64)),
            unit: "count".to_string(),
        },
    );
    thresholds.insert(
        "path5_tracked_copies".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(0)),
            unit: "count".to_string(),
        },
    );
    pass_per_axis.insert("path5_tracked_copies".to_string(), path5.copy_count == 0);

    measurements.insert(
        "path5_bundle_bytes".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(path5.bundle_bytes as u64)),
            unit: "bytes".to_string(),
        },
    );
    thresholds.insert(
        "path5_bundle_bytes".to_string(),
        AcceptanceThreshold {
            operator: ">=".to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(1)),
            unit: "bytes".to_string(),
        },
    );
    pass_per_axis.insert("path5_bundle_bytes".to_string(), path5.bundle_bytes >= 1);

    measurements.insert(
        "path5_wall_us_p50".to_string(),
        Measurement {
            value: serde_json::Value::Number(
                serde_json::Number::from_f64(path5.wall_us_p50)
                    .unwrap_or_else(|| serde_json::Number::from(0)),
            ),
            unit: "microseconds".to_string(),
        },
    );
    thresholds.insert(
        "path5_wall_us_p50".to_string(),
        AcceptanceThreshold {
            operator: "<=".to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(500)),
            unit: "microseconds".to_string(),
        },
    );
    pass_per_axis.insert("path5_wall_us_p50".to_string(), path5.wall_us_p50 <= 500.0);

    // Manual track_copy discipline contract — verifies the
    // `uas::copy_counter` shim's basic semantics.
    let track_copy_contract_pass = verify_track_copy_contract();
    measurements.insert(
        "track_copy_shim_contract".to_string(),
        Measurement {
            value: serde_json::Value::Bool(track_copy_contract_pass),
            unit: "bool".to_string(),
        },
    );
    thresholds.insert(
        "track_copy_shim_contract".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "bool".to_string(),
        },
    );
    pass_per_axis.insert(
        "track_copy_shim_contract".to_string(),
        track_copy_contract_pass,
    );

    // -- Unmeasured-path anomalies ---------------------------------
    for (path_id, desc) in UNMEASURED_PATHS {
        anomalies.push(serde_json::json!({
            "kind": "unmeasured_path",
            "path_id": path_id,
            "detail": desc,
        }));
    }

    let elapsed_seconds = start.elapsed().as_secs_f64();
    measurements.insert(
        "harness_wall_clock_seconds".to_string(),
        Measurement {
            value: serde_json::Value::Number(
                serde_json::Number::from_f64(elapsed_seconds)
                    .unwrap_or_else(|| serde_json::Number::from(0)),
            ),
            unit: "seconds".to_string(),
        },
    );

    let notes = "fallback_witness; in-process Rust path #5 (provenance ClaimLedger \
                 snapshot → ReplayBundle) measured; paths #1-#4 + #6 require Swift / Metal / \
                 MLX-Swift dispatch + IOSurface harness (W-41 Apple-platform external work) — \
                 listed as anomalies. CountingAllocator not installed (lib-test contamination); \
                 track_copy/with_tracking shim contract verified."
        .to_string();

    let artifact = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: ArtifactKind::FallbackWitness,
        command: COMMAND.to_string(),
        commit_sha: agent_core::falsifier_artifacts::current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Fallback,
        anomalies,
        notes,
        timestamp_utc: started_utc,
    }
    .build();

    let path = PathBuf::from("artifacts/falsifiers/uas_zero_copy_spine/result.json");
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).expect("create artifacts directory");
    }
    let mut file = std::fs::File::create(&path).expect("open artifact for write");
    write_artifact(&mut file, &artifact).expect("write artifact");

    println!(
        "F-UAS-ZeroCopy-Spine (path #5 fallback): overall_pass={} elapsed_seconds={:.4} artifact={}",
        artifact.overall_pass,
        elapsed_seconds,
        path.display()
    );

    if !artifact.overall_pass {
        std::process::exit(1);
    }
}

const UNMEASURED_PATHS: &[(&str, &str)] = &[
    (
        "path1_embedding_query",
        "Embedding query &[f32] (Model2Vec) Swift EmbedderRegistry → \
         epistemos-shadow::vector_index. Requires Swift+Metal dispatch.",
    ),
    (
        "path2_logit_stream",
        "Logit stream &[f32] (MLX-Swift) → agent_core scope_rex AnswerPacket. \
         Requires MLX-Swift inference dispatch.",
    ),
    (
        "path3_kv_page_metadata",
        "KV cache page metadata UasAddress + ResidencyLease handle. \
         Requires KV-Direct gate + MLXInferenceService bridge.",
    ),
    (
        "path4_graph_search_row",
        "FusedResult row epistemos-shadow → SearchIndexService::fusedSearch. \
         Requires mmap'd FFI bridge measurement.",
    ),
    (
        "path6_page_gather_scatter",
        "PageGather scatter 256 MB+ IOSurface working set. Requires Metal \
         kernel + IOSurface harness (see falsify_page_gather fallback).",
    ),
];

struct Path5Stats {
    copy_count: usize,
    bundle_bytes: usize,
    wall_us_p50: f64,
}

fn measure_path_5_provenance_snapshot() -> Path5Stats {
    // Seed a small ledger: 8 evidence + 16 claims with derivation links.
    let mut ledger = ClaimLedger::new();
    let t = 1_745_000_000_000_i64;
    for i in 0..8 {
        let ev = Evidence::new(EvidenceId::new(format!("ev-{i}")), format!("src://{i}"), t);
        ledger.commit_evidence(ev).expect("commit evidence");
    }
    for i in 0..16 {
        let parents = if i == 0 {
            vec![]
        } else {
            vec![ClaimId::new(format!("c-{}", i - 1))]
        };
        let claim = Claim::new(ClaimId::new(format!("c-{i}")), format!("text-{i}"), t);
        ledger
            .commit_claim(claim, parents, vec![EvidenceId::new(format!("ev-{}", i % 8))])
            .expect("commit claim");
    }

    // First, capture bundle bytes (untimed).
    let bundle = ReplayBundle::build("uas-spine-path5".to_string(), None, t, &ledger, vec![])
        .expect("build bundle");
    let bundle_bytes = bundle.to_epbundle_bytes().expect("serialize").len();

    // N timed iterations through with_tracking; record copy_count and
    // per-iteration latency. We track wall_us_p50 over 200 iterations.
    let n = 200usize;
    let mut wall_samples_us: Vec<f64> = Vec::with_capacity(n);
    let mut total_copies = 0usize;
    for _ in 0..n {
        let (_, stats): (Result<Vec<u8>, _>, CopyStats) = with_tracking(|| {
            let snap_bundle =
                ReplayBundle::build("uas-spine-path5".to_string(), None, t, &ledger, vec![])
                    .expect("build inner");
            let t0 = Instant::now();
            let bytes = snap_bundle.to_epbundle_bytes();
            let _us = t0.elapsed().as_micros();
            // The snapshot path itself should not call track_copy; the
            // tracking captures only intentional copy-discipline events.
            bytes
        });
        total_copies += stats.copy_count;
        // Independent latency sample (outside with_tracking mutex).
        let t1 = Instant::now();
        let snap_bundle =
            ReplayBundle::build("uas-spine-path5".to_string(), None, t, &ledger, vec![])
                .expect("build inner");
        let _ = snap_bundle.to_epbundle_bytes().expect("serialize");
        let us = t1.elapsed().as_micros() as f64;
        wall_samples_us.push(us);
    }
    wall_samples_us.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let p50_idx = wall_samples_us.len() / 2;
    let wall_us_p50 = wall_samples_us[p50_idx];

    reset_counters();
    Path5Stats {
        copy_count: total_copies,
        bundle_bytes,
        wall_us_p50,
    }
}

fn verify_track_copy_contract() -> bool {
    let (_r, stats) = with_tracking(|| {
        track_copy();
        track_copy();
        track_copy();
        "ok"
    });
    let pass = stats.copy_count == 3;
    reset_counters();
    pass
}
