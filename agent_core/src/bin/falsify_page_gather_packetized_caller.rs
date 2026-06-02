//! F-PageGather-Packetized-Caller.
//!
//! This is not the dense `F-PageGather-M2Pro` primary bandwidth gate. It proves
//! one non-hot retrieval caller consumes `(logical_position, value)` packets and
//! defers dense restore, so PageGather can keep moving while the dense Metal
//! restore bottleneck remains red.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind,
    FallbackTier, Measurement,
};
use agent_core::storage::retrieval_trace::{PageGatherMeasurementStatus, PageGatherScheduleClass};
use agent_core::storage::vault::{VaultBackend, VaultStore};

const FALSIFIER_ID: &str = "F-PageGather-Packetized-Caller";
const FIXTURE_ID: &str = "vault_hybrid_search_trace_packetized_page_gather_v1";
const COMMAND: &str = "Tools/falsifiers/f_page_gather_packetized_caller.sh";

#[tokio::main]
async fn main() -> std::process::ExitCode {
    match build_artifact().await {
        Ok(artifact) => {
            let pass = artifact.overall_pass;
            let path =
                PathBuf::from("artifacts/falsifiers/page_gather_packetized_caller/result.json");
            if let Some(parent) = path.parent() {
                if let Err(error) = std::fs::create_dir_all(parent) {
                    eprintln!("failed to create artifact directory: {error}");
                    return std::process::ExitCode::from(2);
                }
            }
            match std::fs::File::create(&path)
                .and_then(|mut file| write_artifact(&mut file, &artifact))
            {
                Ok(()) if pass => std::process::ExitCode::SUCCESS,
                Ok(()) => std::process::ExitCode::from(1),
                Err(error) => {
                    eprintln!("failed to write artifact: {error}");
                    std::process::ExitCode::from(2)
                }
            }
        }
        Err(error) => {
            eprintln!("failed to build PageGather packetized caller artifact: {error}");
            std::process::ExitCode::from(2)
        }
    }
}

async fn build_artifact() -> anyhow::Result<agent_core::falsifier_artifacts::FalsifierArtifact> {
    let vault_root = tempfile::tempdir()?;
    let store = VaultStore::open(vault_root.path().to_str().expect("utf8 temp path"))?;
    for index in 0..60 {
        store
            .write(
                &format!("note-{index:02}.md"),
                "residency governance residency governance signal",
                None,
                false,
            )
            .await?;
    }
    store.reload_index()?;
    let (results, trace) = store
        .hybrid_search_with_trace("residency governance", 4, &[])
        .await?;
    let page_gather = trace
        .page_gather
        .as_ref()
        .ok_or_else(|| anyhow::anyhow!("missing PageGather trace"))?;

    let page_gather_trace_present = trace.page_gather.is_some();
    let packetized_caller_consumed = page_gather.packetized_caller_consumed;
    let packets_match_results = page_gather.packets_emitted == results.len();
    let dense_restore_deferred = page_gather.dense_restore_deferred;
    let schedule_block_sorted =
        page_gather.schedule_class == Some(PageGatherScheduleClass::BlockSorted);
    let measurement_status_deferred =
        page_gather.measurement_status == PageGatherMeasurementStatus::Deferred;
    let candidate_pool_broad = trace.candidate_pool_size >= 50;
    let retained_limit_honored = results.len() == 4 && page_gather.candidates_retained == 4;

    let mut measurements: BTreeMap<String, Measurement> = BTreeMap::new();
    let mut thresholds: BTreeMap<String, AcceptanceThreshold> = BTreeMap::new();
    let mut pass_per_axis: BTreeMap<String, bool> = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "page_gather_trace_present",
        page_gather_trace_present,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "packetized_caller_consumed",
        packetized_caller_consumed,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "packets_match_results",
        packets_match_results,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "dense_restore_deferred",
        dense_restore_deferred,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "schedule_block_sorted",
        schedule_block_sorted,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "measurement_status_deferred",
        measurement_status_deferred,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "candidate_pool_broad",
        candidate_pool_broad,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "retained_limit_honored",
        retained_limit_honored,
    );

    measurements.insert(
        "candidate_pool_size".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(
                trace.candidate_pool_size as u64,
            )),
            unit: "candidates".to_string(),
        },
    );
    measurements.insert(
        "packets_emitted".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(
                page_gather.packets_emitted as u64,
            )),
            unit: "packets".to_string(),
        },
    );

    Ok(ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: ArtifactKind::FallbackWitness,
        command: COMMAND.to_string(),
        commit_sha: agent_core::falsifier_artifacts::current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Fallback,
        anomalies: vec![serde_json::json!({
            "kind": "not_dense_primary_gate",
            "detail": "This caller witness proves packet consumption and dense-restore deferral only; F-PageGather-M2Pro dense Metal throughput remains red."
        })],
        notes: "fallback_witness; VaultStore hybrid_search_with_trace consumes PageGather packets for retained candidate scores and defers dense restore".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
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
