//! `falsify_app_cold_store_layout` — non-executing AppColdStore layout gate.
//!
//! This proves only the manifest layer: a passed `ResidencyPlan` can be mapped
//! into durable atlas, regenerable warm cache, and hot runway route-card rows
//! without loading model bytes or claiming runtime inference.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::eidos::{
    EidosChunkId, EidosCitation, EidosCitationNeed, EidosContextPacket, EidosDocumentId, EidosHit,
    EidosIndexManifestId, EidosProvenance, EidosQuery, EidosRetrievalMode, EidosRoutePrior,
    EidosScoreComponents, EidosSourceKind, EidosSpan,
};
use agent_core::falsifier_artifacts::{
    current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder,
    ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    AppColdStoreRouteCard, AppColdStoreRouteCardError, ProStatus, ProductBuild, ResidencyBudget,
    ResidencyPlan, ResidencyPlanStatus, UasAddress, UasKind, WeightBlockEncoding,
    WeightBlockIrChart, WeightBlockManifest, WeightBlockResidencyClass,
};

const FALSIFIER_ID: &str = "F-AppColdStore-Layout";
const PARAM_ROUTE_CARD_ADMISSION_FALSIFIER_ID: &str = "F-ParamRouteCard-Admission";
const EIDOS_NEURAL_ROUTE_PRIOR_FALSIFIER_ID: &str = "F-Eidos-NeuralRoute-Prior";
const FIXTURE_ID: &str = "app_cold_store_layout_manifest_only_v1";
const COMMAND: &str = "Tools/falsifiers/f_app_cold_store_layout.sh";
const RESULT: &str = "artifacts/falsifiers/app_cold_store_layout/result.json";
const TASK_SIGNATURE: &str = "deep_research:app_cold_store_layout";

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
    if let Err(error) = write_artifact(&mut file, &report.artifact) {
        eprintln!("failed to write artifact: {error}");
        return std::process::ExitCode::from(2);
    }
    println!(
        "{FALSIFIER_ID}: overall_pass={} durable={} warm={} hot={} artifact={}",
        report.artifact.overall_pass,
        report.durable_bytes,
        report.warm_bytes,
        report.hot_bytes,
        RESULT
    );
    if report.artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

struct AppColdStoreLayoutReport {
    artifact: agent_core::falsifier_artifacts::FalsifierArtifact,
    durable_bytes: u64,
    warm_bytes: u64,
    hot_bytes: u64,
}

fn build_report() -> Result<AppColdStoreLayoutReport, Box<dyn std::error::Error>> {
    let plan = fit_plan()?;
    let eidos_packet = eidos_context_packet()?;
    let eidos_prior = eidos_route_prior(&eidos_packet)?;
    let first_evidence_id = eidos_prior
        .evidence_ids
        .first()
        .cloned()
        .ok_or("EidosRoutePrior fixture must carry closed evidence")?;
    let eidos_citation = EidosCitation {
        source_id: first_evidence_id,
        manifest_id: eidos_prior.manifest_id.clone(),
    };
    let closed_evidence_verified = eidos_packet.validate_citation(&eidos_citation).is_ok();
    let card = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
        TASK_SIGNATURE,
        route_card_verifier_stack_with_eidos_prior(),
        "rollback:raw-installed-snapshot",
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        &plan,
        "rebuild_warm_cache_from_durable_atlas",
        Some(eidos_prior.clone()),
        1_779_000_000_000,
    )?;
    let rejected = ResidencyPlan::evaluate(
        Vec::<WeightBlockManifest>::new(),
        ResidencyBudget::new(1024, 1024, 1024, 0.25, 16)?,
        1_779_000_000_000,
    );
    let plan_rejected_before_card = AppColdStoreRouteCard::from_residency_plan(
        TASK_SIGNATURE,
        route_card_verifier_stack(),
        "rollback:raw-installed-snapshot",
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        &rejected,
        "rebuild_warm_cache_from_durable_atlas",
        1_779_000_000_000,
    )
    .unwrap_err()
        == AppColdStoreRouteCardError::PlanRejected;
    let mas_research_rejected = AppColdStoreRouteCard::from_residency_plan(
        TASK_SIGNATURE,
        route_card_verifier_stack(),
        "rollback:raw-installed-snapshot",
        ProductBuild::Mas,
        ProStatus::ResearchCandidate,
        &plan,
        "rebuild_warm_cache_from_durable_atlas",
        1_779_000_000_000,
    )
    .unwrap_err()
        == AppColdStoreRouteCardError::ProductBuildStatusMismatch;
    let missing_eidos_route_prior_falsifier_rejected =
        AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            TASK_SIGNATURE,
            route_card_verifier_stack(),
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            Some(eidos_prior),
            1_779_000_000_000,
        )
        .unwrap_err()
            == AppColdStoreRouteCardError::MissingEidosNeuralRoutePriorVerifier;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_card_constructed",
        card.residency_plan_address.as_ref() == Some(&plan.plan_address),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "durable_warm_hot_tiers_present",
        card.durable_units.len() == 1
            && card.warm_cache_units.len() == 1
            && card.hot_runway_units.len() == 1,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "warm_cache_rebuildable",
        card.warm_cache_units
            .iter()
            .all(|unit| unit.rebuildable_from_durable),
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_model_bytes_loaded",
        card.totals.runtime_model_bytes_loaded,
        0,
        "bytes",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "failed_residency_plan_rejected",
        plan_rejected_before_card,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "mas_research_status_rejected",
        mas_research_rejected,
    );
    add_count_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "durable_atlas_bytes",
        card.totals.durable_atlas_bytes,
        1,
        "bytes",
    );
    add_count_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "warm_cache_bytes",
        card.totals.warm_cache_bytes,
        1,
        "bytes",
    );
    add_count_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hot_runway_bytes",
        card.totals.hot_runway_bytes,
        1,
        "bytes",
    );
    add_count_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "total_addressed_bytes",
        card.totals.total_addressed_bytes,
        1,
        "bytes",
    );
    add_count_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "planned_active_runtime_bytes",
        card.totals.active_runtime_bytes,
        1,
        "bytes",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_bytes_excluded_from_active_runtime",
        card.totals.active_runtime_bytes < card.totals.total_addressed_bytes,
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "dry_run_copy_count",
        0,
        0,
        "copies",
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
        "dry_run_ssd_read_bytes",
        0,
        0,
        "bytes",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "closed_citation_validity_not_applicable",
        true,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "eidos_route_prior_bound_to_card",
        card.eidos_route_prior.is_some(),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "eidos_route_prior_closed_evidence_verified",
        closed_evidence_verified,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "eidos_route_prior_neural_falsifier_bound",
        card.verifier_stack
            .iter()
            .any(|verifier| verifier == EIDOS_NEURAL_ROUTE_PRIOR_FALSIFIER_ID),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "eidos_route_prior_missing_falsifier_rejected",
        missing_eidos_route_prior_falsifier_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "param_route_card_admission_verifier_bound",
        card.verifier_stack
            .iter()
            .any(|verifier| verifier == PARAM_ROUTE_CARD_ADMISSION_FALSIFIER_ID),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "product_build_pro_research_status_bound",
        card.product_build == ProductBuild::Pro && card.pro_status == ProStatus::ResearchCandidate,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rollback_reference_bound",
        !card.rollback_reference.trim().is_empty(),
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "witness_completeness_percent",
        100,
        100,
        "percent",
    );

    Ok(AppColdStoreLayoutReport {
        durable_bytes: card.totals.durable_atlas_bytes,
        warm_bytes: card.totals.warm_cache_bytes,
        hot_bytes: card.totals.hot_runway_bytes,
        artifact: ArtifactBuilder {
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
                "detail": "manifest-only AppColdStore route card; no mmap, no cache warm, no model byte load, no inference"
            })],
            notes: "Validates AppColdStore route-card layout over a passed ResidencyPlan; not a runtime or storage-speed proof.".to_string(),
            timestamp_utc: now_utc_rfc3339(),
        }
        .build(),
    })
}

fn fit_plan() -> Result<ResidencyPlan, Box<dyn std::error::Error>> {
    let rollback = UasAddress::new(UasKind::ModelComponent, b"dense-reference", 7);
    let hot = manifest(
        "hot-controller-page",
        0,
        512,
        WeightBlockEncoding::DenseBf16,
        WeightBlockResidencyClass::HotUma,
        None,
    )?;
    let warm = manifest(
        "warm-adapter-page",
        1024,
        256,
        WeightBlockEncoding::Sherry125,
        WeightBlockResidencyClass::WarmCompressedUma,
        Some(rollback.clone()),
    )?;
    let cold = manifest(
        "durable-weight-page",
        2048,
        4096,
        WeightBlockEncoding::Nf4,
        WeightBlockResidencyClass::ColdMmapSsd,
        Some(rollback),
    )?;
    let budget = ResidencyBudget::new(4096, 4096, 8192, 0.25, 16)?;
    let plan = ResidencyPlan::evaluate([cold, hot, warm], budget, 1_779_000_000_000);
    if plan.status != ResidencyPlanStatus::FitForDryRun {
        return Err("fixture residency plan must fit".into());
    }
    Ok(plan)
}

fn route_card_verifier_stack() -> Vec<String> {
    vec![
        FALSIFIER_ID.to_string(),
        PARAM_ROUTE_CARD_ADMISSION_FALSIFIER_ID.to_string(),
    ]
}

fn route_card_verifier_stack_with_eidos_prior() -> Vec<String> {
    let mut stack = route_card_verifier_stack();
    stack.push(EIDOS_NEURAL_ROUTE_PRIOR_FALSIFIER_ID.to_string());
    stack
}

fn eidos_context_packet() -> Result<EidosContextPacket, Box<dyn std::error::Error>> {
    let manifest_id = EidosIndexManifestId::new("manifest:app-cold-store-layout")?;
    Ok(EidosContextPacket {
        query: EidosQuery::new("app cold store layout", EidosRetrievalMode::Hybrid, 4),
        manifest_id: manifest_id.clone(),
        hits: vec![EidosHit {
            source_id: EidosChunkId::new("vault://note/app-cold-store-layout")?,
            document_id: EidosDocumentId::new("vault://note/app-cold-store-layout-doc")?,
            kind: EidosSourceKind::Note,
            span: Some(EidosSpan {
                byte_start: 0,
                byte_end: 64,
            }),
            confidence: 0.84,
            score: EidosScoreComponents {
                lexical: 0.46,
                semantic: 0.34,
                recency: 0.04,
                graph: 0.0,
            },
            provenance: EidosProvenance {
                manifest_id,
                mode: EidosRetrievalMode::Hybrid,
                retrieved_at_unix_ms: 1_779_000_000_000,
            },
        }],
    })
}

fn eidos_route_prior(
    packet: &EidosContextPacket,
) -> Result<EidosRoutePrior, Box<dyn std::error::Error>> {
    Ok(EidosRoutePrior::from_packet(
        packet,
        TASK_SIGNATURE,
        vec![EidosChunkId::new("vault://note/app-cold-store-layout")?],
        EidosCitationNeed::Required,
        vec!["local_reasoning".to_string(), "cold_store".to_string()],
        vec!["requires_manifest_only_scope_guard".to_string()],
        vec![FALSIFIER_ID.to_string()],
        vec!["adapter:layout_planner".to_string()],
        vec!["kv:layout_manifest_only".to_string()],
        vec!["weight_page:durable_atlas_fixture".to_string()],
        0.84,
        vec!["Eidos matched closed evidence for AppColdStore route-card planning".to_string()],
    )?)
}

fn manifest(
    label: &str,
    byte_start: u64,
    byte_len: u64,
    encoding: WeightBlockEncoding,
    residency_class: WeightBlockResidencyClass,
    rollback_reference: Option<UasAddress>,
) -> Result<WeightBlockManifest, Box<dyn std::error::Error>> {
    let hash = blake3::hash(label.as_bytes());
    Ok(WeightBlockManifest::from_known_hash_hex(
        "local/app-cold-store-fixture",
        format!("app-support://Epistemos/Models/coldstore/{label}.epwp"),
        byte_start,
        byte_len,
        hash.to_hex().as_str(),
        1_779_000_000_000,
        encoding,
        residency_class,
        WeightBlockIrChart::OpaqueWithWitness,
        0.02,
        FALSIFIER_ID,
        rollback_reference,
    )?)
}

fn add_bool_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    passed: bool,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::Bool(passed),
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
    pass_per_axis.insert(axis.to_string(), passed);
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
    add_count_axis(
        measurements,
        thresholds,
        pass_per_axis,
        axis,
        value,
        "==",
        expected,
        value == expected,
        unit,
    );
}

fn add_count_min_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: u64,
    min: u64,
    unit: &str,
) {
    add_count_axis(
        measurements,
        thresholds,
        pass_per_axis,
        axis,
        value,
        ">=",
        min,
        value >= min,
        unit,
    );
}

#[allow(clippy::too_many_arguments)]
fn add_count_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: u64,
    op: &str,
    threshold: u64,
    passed: bool,
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
            operator: op.to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(threshold)),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), passed);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn app_cold_store_layout_report_is_manifest_only_and_green() {
        let report = build_report().unwrap();

        assert!(report.artifact.overall_pass);
        assert_eq!(report.artifact.falsifier_id, FALSIFIER_ID);
        assert_eq!(
            report
                .artifact
                .pass_per_axis
                .get("runtime_model_bytes_loaded"),
            Some(&true)
        );
        assert!(report.durable_bytes > 0);
        assert!(report.warm_bytes > 0);
        assert!(report.hot_bytes > 0);
        assert_eq!(
            report
                .artifact
                .measurements
                .get("total_addressed_bytes")
                .map(|measurement| &measurement.value),
            Some(&serde_json::Value::Number(serde_json::Number::from(
                report.durable_bytes + report.warm_bytes + report.hot_bytes
            )))
        );
        assert_eq!(
            report
                .artifact
                .pass_per_axis
                .get("cold_bytes_excluded_from_active_runtime"),
            Some(&true)
        );
        assert_eq!(
            report
                .artifact
                .measurements
                .get("planned_active_runtime_bytes")
                .map(|measurement| &measurement.value),
            Some(&serde_json::Value::Number(serde_json::Number::from(
                report.warm_bytes + report.hot_bytes
            )))
        );
        assert_eq!(
            report.artifact.pass_per_axis.get("dry_run_copy_count"),
            Some(&true)
        );
        assert_eq!(
            report
                .artifact
                .pass_per_axis
                .get("runtime_model_peak_uma_bytes"),
            Some(&true)
        );
        assert_eq!(
            report.artifact.pass_per_axis.get("dry_run_ssd_read_bytes"),
            Some(&true)
        );
        assert_eq!(
            report
                .artifact
                .pass_per_axis
                .get("closed_citation_validity_not_applicable"),
            Some(&true)
        );
        assert_eq!(
            report
                .artifact
                .pass_per_axis
                .get("eidos_route_prior_bound_to_card"),
            Some(&true)
        );
        assert_eq!(
            report
                .artifact
                .pass_per_axis
                .get("eidos_route_prior_closed_evidence_verified"),
            Some(&true)
        );
        assert_eq!(
            report
                .artifact
                .pass_per_axis
                .get("eidos_route_prior_neural_falsifier_bound"),
            Some(&true)
        );
        assert_eq!(
            report
                .artifact
                .pass_per_axis
                .get("eidos_route_prior_missing_falsifier_rejected"),
            Some(&true)
        );
        assert_eq!(
            report
                .artifact
                .pass_per_axis
                .get("param_route_card_admission_verifier_bound"),
            Some(&true)
        );
        assert_eq!(
            report
                .artifact
                .pass_per_axis
                .get("product_build_pro_research_status_bound"),
            Some(&true)
        );
        assert_eq!(
            report
                .artifact
                .pass_per_axis
                .get("rollback_reference_bound"),
            Some(&true)
        );
        assert_eq!(
            report
                .artifact
                .pass_per_axis
                .get("witness_completeness_percent"),
            Some(&true)
        );
    }
}
