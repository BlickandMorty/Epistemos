//! `falsify_residency_patternboost_no_hidden_authority` — PatternBoost guard.
//!
//! This is a metadata-only witness for Residency PatternBoost. It proves a
//! candidate assembly genome can be shaped without becoming live route
//! authority, loading model bytes, mmap'ing files, or running inference.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder,
    ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    AssemblyPageRun, ColdRoutePolicyPatch, ProStatus, ProductBuild, ResidencyTier, UasAddress,
    UasAssemblyGenome, UasAssemblyGenomeError, UasKind,
};

const FALSIFIER_ID: &str = "F-ResidencyPatternBoost-NoHiddenAuthority";
const FIXTURE_ID: &str = "residency_patternboost_no_hidden_authority_v1";
const COMMAND: &str = "Tools/falsifiers/f_residency_patternboost_no_hidden_authority.sh";
const RESULT: &str = "artifacts/falsifiers/residency_patternboost_no_hidden_authority/result.json";
const ANSWER_PACKET_CAVEAT_REF: &str = "answer_packet_caveat:patternboost-dry-run-only";
const KILL_SWITCH_REF: &str = "kill_switch:patternboost_shadow_patch";
const RUN_EVENT_LOG_SPAN_REF: &str = "run_event_log:patternboost-shadow-span";
const ROLLBACK_REF: &str = "rollback:static_route_policy";

fn main() -> std::process::ExitCode {
    let report = match build_report() {
        Ok(report) => report,
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
    if let Err(error) = write_artifact(&mut file, &report) {
        eprintln!("failed to write artifact: {error}");
        return std::process::ExitCode::from(2);
    }
    println!(
        "{FALSIFIER_ID}: overall_pass={} artifact={RESULT}",
        report.overall_pass
    );
    if report.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_report(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let genome = accepted_shadow_genome()?;
    let policy_patch = accepted_shadow_policy_patch();
    let direct_live_authority_rejected = UasAssemblyGenome::new(
        "citation_heavy_research",
        route_card_ref(),
        "patternboost:direct_live_policy",
        vec![addr(UasKind::ModelComponent, b"weight-a")],
        Vec::new(),
        Vec::new(),
        Vec::new(),
        required_verifier_lanes(),
        "query_aware_sparse_attention_v0",
        "depth_budget_gate_shadow_v0",
        vec![page_run("a", 0)?],
        vec!["nf4".to_string()],
        vec!["kv:research-prefix".to_string()],
        vec!["kv_restore_before_decode".to_string()],
        "runtime_router:fallback_static_route",
        ROLLBACK_REF,
        RUN_EVENT_LOG_SPAN_REF,
        ANSWER_PACKET_CAVEAT_REF,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        ResidencyTier::CapabilityCeiling,
        1_779_000_000_000,
    )
    .unwrap_err()
        == UasAssemblyGenomeError::UnsupportedRuntimeRouteAuthority {
            field: "runtime_route_id",
            route: "patternboost:direct_live_policy".to_string(),
        };
    let live_runtime_router_route_rejected = UasAssemblyGenome::new(
        "citation_heavy_research",
        route_card_ref(),
        "runtime_router:live_patternboost_policy",
        vec![addr(UasKind::ModelComponent, b"weight-a")],
        Vec::new(),
        Vec::new(),
        Vec::new(),
        required_verifier_lanes(),
        "query_aware_sparse_attention_v0",
        "depth_budget_gate_shadow_v0",
        vec![page_run("a", 0)?],
        vec!["nf4".to_string()],
        vec!["kv:research-prefix".to_string()],
        vec!["kv_restore_before_decode".to_string()],
        "runtime_router:fallback_static_route",
        ROLLBACK_REF,
        RUN_EVENT_LOG_SPAN_REF,
        ANSWER_PACKET_CAVEAT_REF,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        ResidencyTier::CapabilityCeiling,
        1_779_000_000_000,
    )
    .unwrap_err()
        == UasAssemblyGenomeError::UnsupportedRuntimeRouteAuthority {
            field: "runtime_route_id",
            route: "runtime_router:live_patternboost_policy".to_string(),
        };
    let mas_promotion_rejected = UasAssemblyGenome::new(
        "citation_heavy_research",
        route_card_ref(),
        "runtime_router:shadow_patternboost_route",
        vec![addr(UasKind::ModelComponent, b"weight-a")],
        Vec::new(),
        Vec::new(),
        Vec::new(),
        required_verifier_lanes(),
        "query_aware_sparse_attention_v0",
        "depth_budget_gate_shadow_v0",
        vec![page_run("a", 0)?],
        vec!["nf4".to_string()],
        vec!["kv:research-prefix".to_string()],
        vec!["kv_restore_before_decode".to_string()],
        "runtime_router:fallback_static_route",
        ROLLBACK_REF,
        RUN_EVENT_LOG_SPAN_REF,
        ANSWER_PACKET_CAVEAT_REF,
        ProductBuild::Mas,
        ProStatus::Live,
        ResidencyTier::CurrentApp,
        1_779_000_000_000,
    )
    .unwrap_err()
        == UasAssemblyGenomeError::ProductBuildStatusMismatch;
    let missing_no_hidden_authority_falsifier_rejected = UasAssemblyGenome::new(
        "citation_heavy_research",
        route_card_ref(),
        "runtime_router:shadow_patternboost_route",
        vec![addr(UasKind::ModelComponent, b"weight-a")],
        Vec::new(),
        Vec::new(),
        Vec::new(),
        vec![
            "F-ComputeResumeLease-Compatibility".to_string(),
            "F-LatticeAbstentionGate-Soundness".to_string(),
            "F-NoOfflineOracleLeak".to_string(),
            "F-ParamRouteCard-Admission".to_string(),
        ],
        "query_aware_sparse_attention_v0",
        "depth_budget_gate_shadow_v0",
        vec![page_run("a", 0)?],
        vec!["nf4".to_string()],
        vec!["kv:research-prefix".to_string()],
        vec!["kv_restore_before_decode".to_string()],
        "runtime_router:fallback_static_route",
        ROLLBACK_REF,
        RUN_EVENT_LOG_SPAN_REF,
        ANSWER_PACKET_CAVEAT_REF,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        ResidencyTier::CapabilityCeiling,
        1_779_000_000_000,
    )
    .unwrap_err()
        == UasAssemblyGenomeError::MissingRequiredVerifierLane {
            verifier: FALSIFIER_ID,
        };
    let network_transport_rejected = UasAssemblyGenome::new(
        "citation_heavy_research",
        route_card_ref(),
        "runtime_router:shadow_patternboost_route",
        vec![addr(UasKind::ModelComponent, b"weight-a")],
        Vec::new(),
        Vec::new(),
        Vec::new(),
        required_verifier_lanes(),
        "query_aware_sparse_attention_v0",
        "depth_budget_gate_shadow_v0",
        vec![AssemblyPageRun::new(
            "https://example.invalid/coldstore/page.epwp",
            0,
            128,
        )?],
        vec!["nf4".to_string()],
        vec!["kv:research-prefix".to_string()],
        vec!["kv_restore_before_decode".to_string()],
        "runtime_router:fallback_static_route",
        ROLLBACK_REF,
        RUN_EVENT_LOG_SPAN_REF,
        ANSWER_PACKET_CAVEAT_REF,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        ResidencyTier::CapabilityCeiling,
        1_779_000_000_000,
    )
    .unwrap_err()
        == UasAssemblyGenomeError::UnsupportedTransportPageRunSourceUri {
            source_uri: "https://example.invalid/coldstore/page.epwp".to_string(),
        };
    let live_policy_patch_rejected = ColdRoutePolicyPatch::new(
        "runtime_router:live_patternboost_policy",
        tournament_trace_ref(),
        "metrics:static_baseline",
        "delta:held_out_route_win",
        "held_out:mission_family_v1",
        "shadow_policy_patch",
        KILL_SWITCH_REF,
        ROLLBACK_REF,
        RUN_EVENT_LOG_SPAN_REF,
        ANSWER_PACKET_CAVEAT_REF,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        ResidencyTier::CapabilityCeiling,
        1_779_000_000_000,
    )
    .is_err();
    let unscoped_policy_patch_rejected = ColdRoutePolicyPatch::new(
        "runtime_router:shadow_patternboost_route",
        tournament_trace_ref(),
        "metrics:static_baseline",
        "delta:held_out_route_win",
        "held_out:mission_family_v1",
        "live_policy_patch",
        KILL_SWITCH_REF,
        ROLLBACK_REF,
        RUN_EVENT_LOG_SPAN_REF,
        ANSWER_PACKET_CAVEAT_REF,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        ResidencyTier::CapabilityCeiling,
        1_779_000_000_000,
    )
    .is_err();

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "shadow_genome_constructed",
        genome.validate_shape().is_ok(),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "pro_research_capability_ceiling_only",
        genome.product_build == ProductBuild::Pro
            && genome.pro_status == ProStatus::ResearchCandidate
            && genome.residency_status == ResidencyTier::CapabilityCeiling,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_router_shadow_route_only",
        genome
            .runtime_route_id
            .starts_with("runtime_router:shadow_"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fallback_route_is_static_or_baseline",
        genome
            .fallback_route
            .starts_with("runtime_router:fallback_")
            || genome
                .fallback_route
                .starts_with("runtime_router:baseline_")
            || genome.fallback_route.starts_with("runtime_router:static_"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "required_no_hidden_authority_guard_present",
        genome
            .selected_verifier_lanes
            .iter()
            .any(|lane| lane == FALSIFIER_ID),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "run_event_log_and_answer_packet_refs_visible",
        genome.run_event_log_span_ref.starts_with("run_event_log:")
            && genome
                .answer_packet_caveat_ref
                .starts_with("answer_packet_caveat:"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "direct_live_authority_rejected",
        direct_live_authority_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "live_runtime_router_route_rejected",
        live_runtime_router_route_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "mas_promotion_rejected",
        mas_promotion_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "missing_no_hidden_authority_falsifier_rejected",
        missing_no_hidden_authority_falsifier_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "network_transport_rejected",
        network_transport_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_route_policy_patch_shape_valid",
        policy_patch.validate_shape().is_ok(),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_route_policy_patch_shadow_scoped",
        policy_patch
            .target_policy
            .starts_with("runtime_router:shadow_")
            && policy_patch.rollout_scope.starts_with("shadow_"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_route_policy_patch_kill_switch_bound",
        policy_patch.kill_switch.starts_with("kill_switch:"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_route_policy_patch_rollback_bound",
        policy_patch.rollback_ref.starts_with("rollback:"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "live_policy_patch_rejected",
        live_policy_patch_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "unscoped_policy_patch_rejected",
        unscoped_policy_patch_rejected,
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_model_bytes_loaded",
        0,
        0,
        "bytes",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_model_peak_uma_bytes",
        0,
        0,
        "bytes",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "ssd_read_bytes",
        0,
        0,
        "bytes",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_inference_runs",
        0,
        0,
        "count",
    );
    measurements.insert(
        "selected_weight_pages".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(
                genome.selected_weight_pages.len(),
            )),
            unit: "count".to_string(),
        },
    );
    measurements.insert(
        "transport_page_runs".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(
                genome.transport_page_runs.len(),
            )),
            unit: "count".to_string(),
        },
    );

    Ok(ArtifactBuilder {
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
            "kind": "scope_guard",
            "detail": "metadata-only UAS assembly genome; no model bytes, mmap, MLX, Metal, KV restore, or inference executed"
        })],
        notes: "Validates Residency PatternBoost no-hidden-authority guardrails; not a live route or runtime pass.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn accepted_shadow_genome() -> Result<UasAssemblyGenome, UasAssemblyGenomeError> {
    UasAssemblyGenome::new(
        "citation_heavy_research",
        route_card_ref(),
        "runtime_router:shadow_patternboost_route",
        vec![addr(UasKind::ModelComponent, b"weight-a")],
        vec![addr(UasKind::KvPage, b"kv-a")],
        vec![addr(
            UasKind::Other("adapter_slice".to_string()),
            b"adapter-citation",
        )],
        vec![addr(UasKind::VaultNote, b"evidence-a")],
        required_verifier_lanes(),
        "query_aware_sparse_attention_v0",
        "depth_budget_gate_shadow_v0",
        vec![page_run("a", 0)?],
        vec!["dense_bf16".to_string(), "nf4".to_string()],
        vec!["kv:research-prefix".to_string()],
        vec!["kv_restore_before_decode".to_string()],
        "runtime_router:fallback_static_route",
        ROLLBACK_REF,
        RUN_EVENT_LOG_SPAN_REF,
        ANSWER_PACKET_CAVEAT_REF,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        ResidencyTier::CapabilityCeiling,
        1_779_000_000_000,
    )
}

fn accepted_shadow_policy_patch() -> ColdRoutePolicyPatch {
    ColdRoutePolicyPatch::new(
        "runtime_router:shadow_patternboost_route",
        tournament_trace_ref(),
        "metrics:static_baseline",
        "delta:held_out_route_win",
        "held_out:mission_family_v1",
        "shadow_policy_patch",
        KILL_SWITCH_REF,
        ROLLBACK_REF,
        RUN_EVENT_LOG_SPAN_REF,
        ANSWER_PACKET_CAVEAT_REF,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        ResidencyTier::CapabilityCeiling,
        1_779_000_000_000,
    )
    .expect("shadow policy patch fixture must stay valid")
}

fn addr(kind: UasKind, label: &[u8]) -> UasAddress {
    UasAddress::new(kind, label, 1_779_000_000_000)
}

fn route_card_ref() -> UasAddress {
    addr(
        UasKind::Other("app_cold_store_route_card".to_string()),
        b"route-card",
    )
}

fn tournament_trace_ref() -> UasAddress {
    addr(
        UasKind::Other("assembly_tournament_trace".to_string()),
        b"tournament-trace",
    )
}

fn page_run(label: &str, start: u64) -> Result<AssemblyPageRun, UasAssemblyGenomeError> {
    AssemblyPageRun::new(format!("app-support://coldstore/{label}.epwp"), start, 128)
}

fn required_verifier_lanes() -> Vec<String> {
    [
        "F-ComputeResumeLease-Compatibility",
        "F-LatticeAbstentionGate-Soundness",
        "F-NoOfflineOracleLeak",
        "F-ParamRouteCard-Admission",
        FALSIFIER_ID,
    ]
    .into_iter()
    .map(str::to_string)
    .collect()
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

fn add_count_eq_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: u64,
    expected: u64,
    unit: &str,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(value)),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(expected)),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), value == expected);
}

#[cfg(test)]
mod tests {
    #[test]
    fn report_is_green_and_runtime_inert() {
        let report = super::build_report().unwrap();
        assert!(report.overall_pass);
        assert_eq!(
            report.pass_per_axis.get("direct_live_authority_rejected"),
            Some(&true)
        );
        assert_eq!(
            report
                .pass_per_axis
                .get("live_runtime_router_route_rejected"),
            Some(&true)
        );
        assert_eq!(
            report.pass_per_axis.get("runtime_model_bytes_loaded"),
            Some(&true)
        );
        assert_eq!(
            report.pass_per_axis.get("model_inference_runs"),
            Some(&true)
        );
    }
}
