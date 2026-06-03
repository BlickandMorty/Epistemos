//! `falsify_task_working_set_query_determinism` — bounded query gate.
//!
//! This metadata-only witness proves that a mission-shaped
//! `TaskWorkingSetQuery` has deterministic addressing, canonical source refs,
//! stable privacy/evidence/verifier/budget fields, and fail-closed behavior for
//! empty sources or impossible budgets before any runtime wake path can run.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder,
    ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    EvidenceNeed, PrivacyClass, SemanticWorkingSetError, TaskWorkingSetQuery, VerifierNeed,
};

const FALSIFIER_ID: &str = "F-TaskWorkingSetQuery-Determinism";
const FIXTURE_ID: &str = "task_working_set_query_determinism_v1";
const COMMAND: &str = "Tools/falsifiers/f_task_working_set_query_determinism.sh";
const RESULT: &str = "artifacts/falsifiers/task_working_set_query_determinism/result.json";
const CREATED_AT_MS: u64 = 1_779_000_000_000;

fn main() -> std::process::ExitCode {
    let artifact = match build_artifact() {
        Ok(artifact) => artifact,
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
    if let Err(error) = write_artifact(&mut file, &artifact) {
        eprintln!("failed to write artifact: {error}");
        return std::process::ExitCode::from(2);
    }

    println!(
        "{FALSIFIER_ID}: overall_pass={} source_ref_count={} hot_budget={} kv_budget={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["source_ref_count"].value,
        artifact.measurements["max_hot_bytes"].value,
        artifact.measurements["max_kv_bytes"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let query = fixture_query(vec![
        "source:doc:semantic-working-set".to_string(),
        "source:bookmark:karpathy-autoresearch".to_string(),
        "source:doc:semantic-working-set".to_string(),
    ])?;
    let canonical = fixture_query(vec![
        "source:bookmark:karpathy-autoresearch".to_string(),
        "source:doc:semantic-working-set".to_string(),
    ])?;
    let reversed = fixture_query(vec![
        "source:doc:semantic-working-set".to_string(),
        "source:bookmark:karpathy-autoresearch".to_string(),
    ])?;
    let privacy_drift = TaskWorkingSetQuery::new(
        query.mission_id.clone(),
        query.task_signature.clone(),
        canonical.source_signal_refs.clone(),
        PrivacyClass::PublicResearch,
        query.deadline_ms,
        query.quality_target_millis,
        query.evidence_need.clone(),
        query.verifier_need.clone(),
        query.max_hot_bytes,
        query.max_kv_bytes,
        query.max_cold_io_bytes,
        query.max_adapter_bytes,
        query.max_evidence_bytes,
        query.max_verifier_bytes,
        query.max_scratch_bytes,
        CREATED_AT_MS,
    )?;
    let quality_drift = TaskWorkingSetQuery::new(
        query.mission_id.clone(),
        query.task_signature.clone(),
        canonical.source_signal_refs.clone(),
        query.privacy_class.clone(),
        query.deadline_ms,
        query.quality_target_millis + 1,
        query.evidence_need.clone(),
        query.verifier_need.clone(),
        query.max_hot_bytes,
        query.max_kv_bytes,
        query.max_cold_io_bytes,
        query.max_adapter_bytes,
        query.max_evidence_bytes,
        query.max_verifier_bytes,
        query.max_scratch_bytes,
        CREATED_AT_MS,
    )?;

    let query_address_deterministic = query.query_address == canonical.query_address
        && canonical.query_address == reversed.query_address;
    let source_refs_canonical = query.source_signal_refs
        == vec![
            "source:bookmark:karpathy-autoresearch".to_string(),
            "source:doc:semantic-working-set".to_string(),
        ];
    let duplicate_source_refs_deduped = query.source_signal_refs.len() == 2;
    let mission_id_bound = query.mission_id == "mission-local-research";
    let task_signature_bound = query.task_signature == "retrieve-verify-answer";
    let privacy_class_bound = query.privacy_class == PrivacyClass::VaultPrivate;
    let deadline_bound = query.deadline_ms == 1200;
    let quality_target_bound = query.quality_target_millis == 850;
    let evidence_need_bound = query.evidence_need == EvidenceNeed::ClosedCitation;
    let verifier_need_bound = query.verifier_need == VerifierNeed::Schema;
    let hot_budget_bounded = query.max_hot_bytes == 2 * 1024 * 1024;
    let kv_budget_bounded = query.max_kv_bytes == 4 * 1024 * 1024;
    let cold_io_budget_bounded = query.max_cold_io_bytes == 4 * 1024 * 1024;
    let auxiliary_budgets_bounded = query.max_adapter_bytes == 1024 * 1024
        && query.max_evidence_bytes == 1024 * 1024
        && query.max_verifier_bytes == 1024 * 1024
        && query.max_scratch_bytes == 1024 * 1024;
    let empty_source_refs_rejected = empty_source_refs_rejected()?;
    let zero_budget_rejected = zero_budget_rejected()?;
    let zero_deadline_rejected = zero_deadline_rejected()?;
    let privacy_drift_changes_address = privacy_drift.query_address != query.query_address;
    let quality_drift_changes_address = quality_drift.query_address != query.query_address;
    let query_address_present = !query.query_address.to_string().is_empty();

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "query_address_deterministic",
        query_address_deterministic,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_refs_canonical",
        source_refs_canonical,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "duplicate_source_refs_deduped",
        duplicate_source_refs_deduped,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "mission_id_bound",
        mission_id_bound,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "task_signature_bound",
        task_signature_bound,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "privacy_class_bound",
        privacy_class_bound,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "deadline_bound",
        deadline_bound,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "quality_target_bound",
        quality_target_bound,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "evidence_need_bound",
        evidence_need_bound,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_need_bound",
        verifier_need_bound,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hot_budget_bounded",
        hot_budget_bounded,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_budget_bounded",
        kv_budget_bounded,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_io_budget_bounded",
        cold_io_budget_bounded,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "auxiliary_budgets_bounded",
        auxiliary_budgets_bounded,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "empty_source_refs_rejected",
        empty_source_refs_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "zero_budget_rejected",
        zero_budget_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "zero_deadline_rejected",
        zero_deadline_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "privacy_drift_changes_address",
        privacy_drift_changes_address,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "quality_drift_changes_address",
        quality_drift_changes_address,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "query_address_present",
        query_address_present,
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_ref_count",
        query.source_signal_refs.len() as u64,
        2,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_hot_bytes",
        query.max_hot_bytes,
        2 * 1024 * 1024,
        "==",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_kv_bytes",
        query.max_kv_bytes,
        4 * 1024 * 1024,
        "==",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_cold_io_bytes",
        query.max_cold_io_bytes,
        4 * 1024 * 1024,
        "==",
    );
    measurements.insert(
        "query_address".to_string(),
        Measurement {
            value: serde_json::Value::String(query.query_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "query_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert("query_address".to_string(), true);

    let artifact = ArtifactBuilder {
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
            "detail": "metadata-only TaskWorkingSetQuery determinism; no working-set execution, prefetch, model decode, MLX/Metal, or route mutation executed"
        })],
        notes: "Proves deterministic task working-set query addressing, canonical source refs, bounded privacy/evidence/verifier/budget fields, and fail-closed behavior for empty sources or impossible budgets before runtime wake paths.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(artifact)
}

fn fixture_query(
    source_signal_refs: Vec<String>,
) -> Result<TaskWorkingSetQuery, Box<dyn std::error::Error>> {
    Ok(TaskWorkingSetQuery::new(
        "mission-local-research",
        "retrieve-verify-answer",
        source_signal_refs,
        PrivacyClass::VaultPrivate,
        1200,
        850,
        EvidenceNeed::ClosedCitation,
        VerifierNeed::Schema,
        2 * 1024 * 1024,
        4 * 1024 * 1024,
        4 * 1024 * 1024,
        1024 * 1024,
        1024 * 1024,
        1024 * 1024,
        1024 * 1024,
        CREATED_AT_MS,
    )?)
}

fn empty_source_refs_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = TaskWorkingSetQuery::new(
        "mission-local-research",
        "retrieve-verify-answer",
        Vec::new(),
        PrivacyClass::VaultPrivate,
        1200,
        850,
        EvidenceNeed::ClosedCitation,
        VerifierNeed::Schema,
        2 * 1024 * 1024,
        4 * 1024 * 1024,
        4 * 1024 * 1024,
        1024 * 1024,
        1024 * 1024,
        1024 * 1024,
        1024 * 1024,
        CREATED_AT_MS,
    )
    .unwrap_err();
    Ok(matches!(
        error,
        SemanticWorkingSetError::MissingSourceSignalRef
    ))
}

fn zero_budget_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = TaskWorkingSetQuery::new(
        "mission-local-research",
        "retrieve-verify-answer",
        vec!["source:doc:semantic-working-set".to_string()],
        PrivacyClass::VaultPrivate,
        1200,
        850,
        EvidenceNeed::ClosedCitation,
        VerifierNeed::Schema,
        0,
        4 * 1024 * 1024,
        4 * 1024 * 1024,
        1024 * 1024,
        1024 * 1024,
        1024 * 1024,
        1024 * 1024,
        CREATED_AT_MS,
    )
    .unwrap_err();
    Ok(matches!(error, SemanticWorkingSetError::InvalidQueryBudget))
}

fn zero_deadline_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = TaskWorkingSetQuery::new(
        "mission-local-research",
        "retrieve-verify-answer",
        vec!["source:doc:semantic-working-set".to_string()],
        PrivacyClass::VaultPrivate,
        0,
        850,
        EvidenceNeed::ClosedCitation,
        VerifierNeed::Schema,
        2 * 1024 * 1024,
        4 * 1024 * 1024,
        4 * 1024 * 1024,
        1024 * 1024,
        1024 * 1024,
        1024 * 1024,
        1024 * 1024,
        CREATED_AT_MS,
    )
    .unwrap_err();
    Ok(matches!(error, SemanticWorkingSetError::InvalidQueryBudget))
}

fn add_bool_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    pass: bool,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::Bool(pass),
            unit: "bool".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "bool".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), pass);
}

fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    expected: u64,
    operator: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(actual)),
            unit: "bytes_or_count".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(expected)),
            unit: "bytes_or_count".to_string(),
        },
    );
    let pass = match operator {
        "<=" => actual <= expected,
        ">=" => actual >= expected,
        "==" => actual == expected,
        _ => false,
    };
    pass_per_axis.insert(name.to_string(), pass);
}
