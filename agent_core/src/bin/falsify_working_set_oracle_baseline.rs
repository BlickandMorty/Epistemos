//! `falsify_working_set_oracle_baseline` — fixture-only oracle baseline gate.
//!
//! This witness proves a deterministic `WorkingSetOracleCard` beats random,
//! recency, and static file-order baseline policies on held-out quality,
//! evidence validity, cold misses, and active bytes, or abstains with a named
//! reason. It does not train, route live requests, fetch sources, prefetch,
//! decode models, or mutate production policy.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder,
    ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    SemanticWorkingSetError, UasAddress, UasKind, WorkingSetOracleBaselineScore,
    WorkingSetOracleCard, WorkingSetOracleScore, WorkingSetOracleStatus,
};

const FALSIFIER_ID: &str = "F-WorkingSetOracle-Baseline";
const FIXTURE_ID: &str = "working_set_oracle_baseline_v1";
const COMMAND: &str = "Tools/falsifiers/f_working_set_oracle_baseline.sh";
const RESULT: &str = "artifacts/falsifiers/working_set_oracle_baseline/result.json";
const CREATED_AT_MS: u64 = 1_779_000_000_000;
const MIN_CONFIDENCE_BPS: u64 = 6_000;

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
        "{FALSIFIER_ID}: overall_pass={} status={} baseline_policy_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["oracle_status"].value,
        artifact.measurements["baseline_policy_count"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let card = fixture_card()?;
    let reversed = WorkingSetOracleCard::evaluate(
        "oracle:semantic-working-set-v1",
        fixture_inputs().into_iter().rev().collect(),
        fixture_predicted_units().into_iter().rev().collect(),
        8_100,
        "abstain:confidence_below_0.60_or_baseline_loss",
        fixture_baselines().into_iter().rev().collect(),
        fixture_held_out_score()?,
        "regret:semantic-working-set-v1",
        CREATED_AT_MS,
    )?;

    let best_quality = card
        .baseline_policies
        .iter()
        .map(|policy| policy.score.quality_bps)
        .max()
        .unwrap_or_default();
    let best_evidence = card
        .baseline_policies
        .iter()
        .map(|policy| policy.score.evidence_validity_bps)
        .max()
        .unwrap_or_default();
    let min_baseline_misses = card
        .baseline_policies
        .iter()
        .map(|policy| policy.score.cold_misses)
        .min()
        .unwrap_or_default();
    let min_baseline_active_bytes = card
        .baseline_policies
        .iter()
        .map(|policy| policy.score.active_bytes)
        .min()
        .unwrap_or_default();

    let oracle_card_created = !card.oracle_address.to_string().is_empty();
    let oracle_address_deterministic = card.oracle_address == reversed.oracle_address;
    let inputs_bound = card.inputs.len() == 2;
    let predicted_units_bound = card.predicted_units.len() == 2;
    let confidence_reported = card.confidence_bps == 8_100;
    let abstain_condition_named = card.abstain_condition.starts_with("abstain:");
    let baseline_policy_coverage = policy_present(&card, "baseline:random")
        && policy_present(&card, "baseline:recency")
        && policy_present(&card, "baseline:file-order");
    let beats_random_policy = beats_policy(&card, "baseline:random");
    let beats_recency_policy = beats_policy(&card, "baseline:recency");
    let beats_file_order_policy = beats_policy(&card, "baseline:file-order");
    let held_out_quality_beats_baselines = card.held_out_score.quality_bps > best_quality;
    let held_out_evidence_validity_beats_baselines =
        card.held_out_score.evidence_validity_bps > best_evidence;
    let held_out_cold_misses_below_baselines =
        card.held_out_score.cold_misses < min_baseline_misses;
    let held_out_active_bytes_below_baselines =
        card.held_out_score.active_bytes < min_baseline_active_bytes;
    let regret_update_key_bound = card.regret_update_key.starts_with("regret:");
    let status_beats_baselines = card.status == WorkingSetOracleStatus::BeatsBaselines;
    let low_confidence_abstains = low_confidence_abstains()?;
    let baseline_loss_abstains = baseline_loss_abstains()?;
    let missing_abstain_rejected = missing_abstain_rejected()?;
    let no_baseline_rejected = no_baseline_rejected()?;
    let empty_inputs_rejected = empty_inputs_rejected()?;
    let empty_predicted_units_rejected = empty_predicted_units_rejected()?;
    let high_confidence_rejected = high_confidence_rejected()?;
    let score_out_of_range_rejected = score_out_of_range_rejected();
    let duplicate_baseline_rejected = duplicate_baseline_rejected()?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        ("oracle_card_created", oracle_card_created),
        ("oracle_address_deterministic", oracle_address_deterministic),
        ("inputs_bound", inputs_bound),
        ("predicted_units_bound", predicted_units_bound),
        ("confidence_reported", confidence_reported),
        ("abstain_condition_named", abstain_condition_named),
        ("baseline_policy_coverage", baseline_policy_coverage),
        ("beats_random_policy", beats_random_policy),
        ("beats_recency_policy", beats_recency_policy),
        ("beats_file_order_policy", beats_file_order_policy),
        (
            "held_out_quality_beats_baselines",
            held_out_quality_beats_baselines,
        ),
        (
            "held_out_evidence_validity_beats_baselines",
            held_out_evidence_validity_beats_baselines,
        ),
        (
            "held_out_cold_misses_below_baselines",
            held_out_cold_misses_below_baselines,
        ),
        (
            "held_out_active_bytes_below_baselines",
            held_out_active_bytes_below_baselines,
        ),
        ("regret_update_key_bound", regret_update_key_bound),
        ("status_beats_baselines", status_beats_baselines),
        ("low_confidence_abstains", low_confidence_abstains),
        ("baseline_loss_abstains", baseline_loss_abstains),
        ("missing_abstain_rejected", missing_abstain_rejected),
        ("no_baseline_rejected", no_baseline_rejected),
        ("empty_inputs_rejected", empty_inputs_rejected),
        (
            "empty_predicted_units_rejected",
            empty_predicted_units_rejected,
        ),
        ("high_confidence_rejected", high_confidence_rejected),
        ("score_out_of_range_rejected", score_out_of_range_rejected),
        ("duplicate_baseline_rejected", duplicate_baseline_rejected),
    ] {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            pass,
        );
    }

    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "confidence_bps",
        u64::from(card.confidence_bps),
        MIN_CONFIDENCE_BPS,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "predicted_unit_count",
        card.predicted_units.len() as u64,
        2,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "baseline_policy_count",
        card.baseline_policies.len() as u64,
        3,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_quality_bps",
        u64::from(card.held_out_score.quality_bps),
        9_000,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "best_baseline_quality_bps",
        u64::from(best_quality),
        u64::from(card.held_out_score.quality_bps.saturating_sub(1)),
        "<=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_evidence_validity_bps",
        u64::from(card.held_out_score.evidence_validity_bps),
        9_000,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "best_baseline_evidence_validity_bps",
        u64::from(best_evidence),
        u64::from(card.held_out_score.evidence_validity_bps.saturating_sub(1)),
        "<=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_cold_misses",
        card.held_out_score.cold_misses,
        0,
        "==",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "min_baseline_cold_misses",
        min_baseline_misses,
        1,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_active_bytes",
        card.held_out_score.active_bytes,
        192 * 1024,
        "<=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "min_baseline_active_bytes",
        min_baseline_active_bytes,
        card.held_out_score.active_bytes + 1,
        ">=",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "oracle_status",
        status_label(card.status),
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "oracle_address",
        &card.oracle_address.to_string(),
    );

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
            "detail": "fixture-only WorkingSetOracleCard baseline comparison; no training, model decode, prefetch, live route choice, source fetch, MLX/Metal, or production policy mutation executed"
        })],
        notes: "Proves a deterministic WorkingSetOracleCard beats random, recency, and static file-order baselines on held-out quality, evidence validity, cold misses, and active bytes while retaining named abstention and rejecting missing-baseline, empty-input, empty-predicted-unit, bad-score, duplicate-baseline, and high-confidence-invalid cases.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(artifact)
}

fn fixture_card() -> Result<WorkingSetOracleCard, Box<dyn std::error::Error>> {
    Ok(WorkingSetOracleCard::evaluate(
        "oracle:semantic-working-set-v1",
        fixture_inputs(),
        fixture_predicted_units(),
        8_100,
        "abstain:confidence_below_0.60_or_baseline_loss",
        fixture_baselines(),
        fixture_held_out_score()?,
        "regret:semantic-working-set-v1",
        CREATED_AT_MS,
    )?)
}

fn fixture_inputs() -> Vec<String> {
    vec![
        "mission:module-5-adversarial-thinking".to_string(),
        "source:doc:semantic-working-set".to_string(),
    ]
}

fn fixture_predicted_units() -> Vec<UasAddress> {
    vec![
        address(UasKind::ModelComponent, b"module-5-evidence"),
        address(UasKind::ModelComponent, b"module-5-kv"),
    ]
}

fn fixture_baselines() -> Vec<WorkingSetOracleBaselineScore> {
    vec![
        baseline("baseline:file-order", 7_200, 7_800, 2, 512 * 1024),
        baseline("baseline:recency", 8_000, 8_200, 1, 384 * 1024),
        baseline("baseline:random", 6_600, 7_000, 2, 448 * 1024),
    ]
}

fn fixture_held_out_score() -> Result<WorkingSetOracleScore, SemanticWorkingSetError> {
    WorkingSetOracleScore::new(9_400, 9_600, 0, 192 * 1024)
}

fn baseline(
    policy_id: &str,
    quality_bps: u16,
    evidence_validity_bps: u16,
    cold_misses: u64,
    active_bytes: u64,
) -> WorkingSetOracleBaselineScore {
    WorkingSetOracleBaselineScore::new(
        policy_id,
        WorkingSetOracleScore::new(
            quality_bps,
            evidence_validity_bps,
            cold_misses,
            active_bytes,
        )
        .unwrap(),
    )
    .unwrap()
}

fn beats_policy(card: &WorkingSetOracleCard, policy_id: &str) -> bool {
    card.baseline_policies
        .iter()
        .find(|policy| policy.policy_id == policy_id)
        .map(|policy| {
            card.held_out_score.quality_bps > policy.score.quality_bps
                && card.held_out_score.evidence_validity_bps > policy.score.evidence_validity_bps
                && card.held_out_score.cold_misses < policy.score.cold_misses
                && card.held_out_score.active_bytes < policy.score.active_bytes
        })
        .unwrap_or(false)
}

fn policy_present(card: &WorkingSetOracleCard, policy_id: &str) -> bool {
    card.baseline_policies
        .iter()
        .any(|policy| policy.policy_id == policy_id)
}

fn low_confidence_abstains() -> Result<bool, Box<dyn std::error::Error>> {
    Ok(WorkingSetOracleCard::evaluate(
        "oracle:semantic-working-set-v1",
        fixture_inputs(),
        fixture_predicted_units(),
        5_100,
        "abstain:low_confidence",
        fixture_baselines(),
        fixture_held_out_score()?,
        "regret:semantic-working-set-v1",
        CREATED_AT_MS,
    )?
    .status
        == WorkingSetOracleStatus::Abstained)
}

fn baseline_loss_abstains() -> Result<bool, Box<dyn std::error::Error>> {
    Ok(WorkingSetOracleCard::evaluate(
        "oracle:semantic-working-set-v1",
        fixture_inputs(),
        fixture_predicted_units(),
        8_100,
        "abstain:baseline_loss",
        fixture_baselines(),
        WorkingSetOracleScore::new(7_000, 7_200, 2, 768 * 1024)?,
        "regret:semantic-working-set-v1",
        CREATED_AT_MS,
    )?
    .status
        == WorkingSetOracleStatus::Abstained)
}

fn missing_abstain_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = WorkingSetOracleCard::evaluate(
        "oracle:semantic-working-set-v1",
        fixture_inputs(),
        fixture_predicted_units(),
        8_100,
        "",
        fixture_baselines(),
        fixture_held_out_score()?,
        "regret:semantic-working-set-v1",
        CREATED_AT_MS,
    )
    .unwrap_err();
    Ok(matches!(
        error,
        SemanticWorkingSetError::MissingAbstainCondition
    ))
}

fn no_baseline_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = WorkingSetOracleCard::evaluate(
        "oracle:semantic-working-set-v1",
        fixture_inputs(),
        fixture_predicted_units(),
        8_100,
        "abstain:baseline_loss",
        Vec::new(),
        fixture_held_out_score()?,
        "regret:semantic-working-set-v1",
        CREATED_AT_MS,
    )
    .unwrap_err();
    Ok(matches!(
        error,
        SemanticWorkingSetError::MissingBaselinePolicy
    ))
}

fn empty_inputs_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = WorkingSetOracleCard::evaluate(
        "oracle:semantic-working-set-v1",
        Vec::new(),
        fixture_predicted_units(),
        8_100,
        "abstain:baseline_loss",
        fixture_baselines(),
        fixture_held_out_score()?,
        "regret:semantic-working-set-v1",
        CREATED_AT_MS,
    )
    .unwrap_err();
    Ok(matches!(error, SemanticWorkingSetError::MissingOracleInput))
}

fn empty_predicted_units_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = WorkingSetOracleCard::evaluate(
        "oracle:semantic-working-set-v1",
        fixture_inputs(),
        Vec::new(),
        8_100,
        "abstain:baseline_loss",
        fixture_baselines(),
        fixture_held_out_score()?,
        "regret:semantic-working-set-v1",
        CREATED_AT_MS,
    )
    .unwrap_err();
    Ok(matches!(
        error,
        SemanticWorkingSetError::MissingPredictedUnit
    ))
}

fn high_confidence_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = WorkingSetOracleCard::evaluate(
        "oracle:semantic-working-set-v1",
        fixture_inputs(),
        fixture_predicted_units(),
        10_001,
        "abstain:baseline_loss",
        fixture_baselines(),
        fixture_held_out_score()?,
        "regret:semantic-working-set-v1",
        CREATED_AT_MS,
    )
    .unwrap_err();
    Ok(matches!(
        error,
        SemanticWorkingSetError::WorkingSetOracleRejected { .. }
    ))
}

fn score_out_of_range_rejected() -> bool {
    matches!(
        WorkingSetOracleScore::new(10_001, 9_000, 0, 192 * 1024).unwrap_err(),
        SemanticWorkingSetError::WorkingSetOracleRejected { .. }
    )
}

fn duplicate_baseline_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = WorkingSetOracleCard::evaluate(
        "oracle:semantic-working-set-v1",
        fixture_inputs(),
        fixture_predicted_units(),
        8_100,
        "abstain:baseline_loss",
        vec![
            baseline("baseline:random", 6_600, 7_000, 2, 448 * 1024),
            baseline("baseline:random", 6_700, 7_100, 2, 448 * 1024),
        ],
        fixture_held_out_score()?,
        "regret:semantic-working-set-v1",
        CREATED_AT_MS,
    )
    .unwrap_err();
    Ok(matches!(
        error,
        SemanticWorkingSetError::WorkingSetOracleRejected { .. }
    ))
}

fn address(kind: UasKind, bytes: &[u8]) -> UasAddress {
    UasAddress::new(kind, bytes, CREATED_AT_MS)
}

fn status_label(status: WorkingSetOracleStatus) -> &'static str {
    match status {
        WorkingSetOracleStatus::BeatsBaselines => "beats_baselines",
        WorkingSetOracleStatus::Abstained => "abstained",
    }
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
            unit: "count_or_bps_or_bytes".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(expected)),
            unit: "count_or_bps_or_bytes".to_string(),
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

fn add_string_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: &str,
) {
    let pass = !value.is_empty();
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(value.to_string()),
            unit: "string".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "string".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), pass);
}
