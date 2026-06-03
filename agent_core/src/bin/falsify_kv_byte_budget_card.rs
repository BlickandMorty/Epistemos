//! `falsify_kv_byte_budget_card` — fixture-only KV accounting witness.
//!
//! This gate proves `KVByteBudgetCard` reports KV bytes, cache hit/miss tokens,
//! codec, quality caveat, and compatibility failures separately from weight
//! bytes. It does not restore KV pages, decode a model, call MLX/Metal, or
//! mutate route policy.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder,
    ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    EvidenceNeed, KVByteBudgetCard, MmapResidencyFence, PrivacyClass, ProStatus, ProductBuild,
    ResidencyTier, SemanticWorkingSetError, SemanticWorkingSetPlan, SemanticWorkingSetUnit,
    TaskWorkingSetQuery, UasAddress, UasKind, VerifierNeed, WorkingSetStorageTier,
    WorkingSetUnitKind,
};

const FALSIFIER_ID: &str = "F-KVByteBudgetCard";
const FIXTURE_ID: &str = "kv_byte_budget_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_kv_byte_budget_card.sh";
const RESULT: &str = "artifacts/falsifiers/kv_byte_budget_card/result.json";
const CREATED_AT_MS: u64 = 1_779_000_000_000;
const WEIGHT_BYTES: u64 = 2 * 1024 * 1024;
const KV_BYTES_PREDICTED: u64 = 384 * 1024;
const KV_BYTES_OBSERVED: u64 = 320 * 1024;
const PROMPT_CACHE_HIT_TOKENS: u32 = 768;
const PROMPT_CACHE_MISS_TOKENS: u32 = 96;

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
        "{FALSIFIER_ID}: overall_pass={} kv_bytes_predicted={} hit_tokens={} miss_tokens={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["kv_bytes_predicted"].value,
        artifact.measurements["prompt_cache_hit_tokens"].value,
        artifact.measurements["prompt_cache_miss_tokens"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let compatible = fixture_kv_budget()?;
    let incompatible = fixture_kv_budget()?.with_compatibility_failures(vec![
        "rope-scale-mismatch".to_string(),
        "prefix-digest-mismatch".to_string(),
        "rope-scale-mismatch".to_string(),
    ])?;
    let compatible_plan = plan_with_kv_budget(compatible.clone())?;
    let incompatible_plan = plan_with_kv_budget(incompatible.clone())?;

    let model_id_reported = !compatible.model_id.is_empty();
    let context_tokens_reported = compatible.context_tokens == 8192;
    let kv_codec_reported = compatible.kv_codec == "kivi-q4-dry-run";
    let predicted_kv_bytes_reported = compatible.kv_bytes_predicted == KV_BYTES_PREDICTED;
    let observed_kv_bytes_reported = compatible.kv_bytes_observed == KV_BYTES_OBSERVED;
    let observed_kv_bytes_bounded = compatible.kv_bytes_observed <= compatible.kv_bytes_predicted;
    let kv_bytes_separate_from_weight_bytes = compatible.kv_bytes_predicted != WEIGHT_BYTES
        && compatible.kv_bytes_observed != WEIGHT_BYTES;
    let hit_tokens_reported = compatible.prompt_cache_hit_tokens == PROMPT_CACHE_HIT_TOKENS;
    let miss_tokens_reported = compatible.prompt_cache_miss_tokens == PROMPT_CACHE_MISS_TOKENS;
    let hit_miss_tokens_separate =
        compatible.prompt_cache_hit_tokens != compatible.prompt_cache_miss_tokens;
    let quality_caveat_reported = compatible
        .quality_caveat
        .contains("dry-run fixture; no KV page loaded");
    let compatible_has_no_failures = compatible.compatibility_failures.is_empty();
    let compatibility_failures_reported = incompatible.compatibility_failures
        == vec![
            "prefix-digest-mismatch".to_string(),
            "rope-scale-mismatch".to_string(),
        ];
    let compatibility_failure_changes_plan_address =
        compatible_plan.plan_address != incompatible_plan.plan_address;
    let plan_kv_totals_keep_separate = compatible_plan.totals.kv_bytes
        != compatible_plan.totals.cold_bytes
        && compatible_plan.totals.kv_bytes != WEIGHT_BYTES;
    let missing_model_id_rejected = missing_model_id_rejected()?;
    let missing_codec_rejected = missing_codec_rejected()?;
    let missing_quality_caveat_rejected = missing_quality_caveat_rejected()?;
    let zero_context_rejected = zero_context_rejected()?;
    let zero_predicted_bytes_rejected = zero_predicted_bytes_rejected()?;
    let empty_compatibility_failure_rejected = empty_compatibility_failure_rejected()?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_id_reported",
        model_id_reported,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "context_tokens_reported",
        context_tokens_reported,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_codec_reported",
        kv_codec_reported,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "predicted_kv_bytes_reported",
        predicted_kv_bytes_reported,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "observed_kv_bytes_reported",
        observed_kv_bytes_reported,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "observed_kv_bytes_bounded",
        observed_kv_bytes_bounded,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_bytes_separate_from_weight_bytes",
        kv_bytes_separate_from_weight_bytes,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hit_tokens_reported",
        hit_tokens_reported,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "miss_tokens_reported",
        miss_tokens_reported,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hit_miss_tokens_separate",
        hit_miss_tokens_separate,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "quality_caveat_reported",
        quality_caveat_reported,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compatible_has_no_failures",
        compatible_has_no_failures,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compatibility_failures_reported",
        compatibility_failures_reported,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compatibility_failure_changes_plan_address",
        compatibility_failure_changes_plan_address,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "plan_kv_totals_keep_separate",
        plan_kv_totals_keep_separate,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "missing_model_id_rejected",
        missing_model_id_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "missing_codec_rejected",
        missing_codec_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "missing_quality_caveat_rejected",
        missing_quality_caveat_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "zero_context_rejected",
        zero_context_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "zero_predicted_bytes_rejected",
        zero_predicted_bytes_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "empty_compatibility_failure_rejected",
        empty_compatibility_failure_rejected,
    );

    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "context_tokens",
        u64::from(compatible.context_tokens),
        8192,
        "==",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_bytes_predicted",
        compatible.kv_bytes_predicted,
        KV_BYTES_PREDICTED,
        "==",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_bytes_observed",
        compatible.kv_bytes_observed,
        KV_BYTES_OBSERVED,
        "==",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "weight_bytes",
        WEIGHT_BYTES,
        WEIGHT_BYTES,
        "==",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prompt_cache_hit_tokens",
        u64::from(compatible.prompt_cache_hit_tokens),
        u64::from(PROMPT_CACHE_HIT_TOKENS),
        "==",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prompt_cache_miss_tokens",
        u64::from(compatible.prompt_cache_miss_tokens),
        u64::from(PROMPT_CACHE_MISS_TOKENS),
        "==",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compatibility_failure_count",
        incompatible.compatibility_failures.len() as u64,
        2,
        "==",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_codec",
        &compatible.kv_codec,
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "quality_caveat",
        &compatible.quality_caveat,
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compatible_plan_address",
        &compatible_plan.plan_address.to_string(),
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
            "detail": "fixture-only KVByteBudgetCard accounting; no KV restore, model decode, MLX/Metal, live prompt cache, or route mutation executed"
        })],
        notes: "Proves KV budget cards report predicted/observed KV bytes, prompt-cache hit/miss tokens, codec, quality caveat, and compatibility failures separately from weight bytes, with missing core fields rejected before runtime.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(artifact)
}

fn fixture_kv_budget() -> Result<KVByteBudgetCard, Box<dyn std::error::Error>> {
    Ok(KVByteBudgetCard::new(
        "local/kv-budget-card-fixture",
        8192,
        "kivi-q4-dry-run",
        KV_BYTES_PREDICTED,
        KV_BYTES_OBSERVED,
        PROMPT_CACHE_HIT_TOKENS,
        PROMPT_CACHE_MISS_TOKENS,
        "dry-run fixture; no KV page loaded; codec may change answer quality",
    )?)
}

fn plan_with_kv_budget(
    kv_budget: KVByteBudgetCard,
) -> Result<SemanticWorkingSetPlan, Box<dyn std::error::Error>> {
    Ok(SemanticWorkingSetPlan::compile_dry_run(
        fixture_query()?,
        vec![
            unit(
                "fixture-weight-page",
                WorkingSetUnitKind::WeightPage,
                UasKind::ModelComponent,
                WorkingSetStorageTier::Cold,
                0,
                WEIGHT_BYTES,
                20,
            )?,
            unit(
                "fixture-kv-page",
                WorkingSetUnitKind::KvPage,
                UasKind::KvPage,
                WorkingSetStorageTier::Warm,
                WEIGHT_BYTES,
                128 * 1024,
                80,
            )?,
        ],
        kv_budget,
        MmapResidencyFence::evaluate(
            "fixture-kv-budget-card",
            0,
            WEIGHT_BYTES,
            true,
            true,
            WEIGHT_BYTES,
            0,
            1,
            0,
            0,
        )?,
        "runtime_router:fallback_kv_budget_card",
        "rollback:kv-byte-budget-card",
        "run_event_log:kv-byte-budget-card",
        "answer_packet:kv-byte-budget-card",
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        ResidencyTier::CapabilityCeiling,
        CREATED_AT_MS,
    )?)
}

fn fixture_query() -> Result<TaskWorkingSetQuery, Box<dyn std::error::Error>> {
    Ok(TaskWorkingSetQuery::new(
        "mission-kv-byte-budget-card",
        "fixture-kv-accounting",
        vec![
            "source:docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md".to_string(),
            "source:docs/falsifiers/F-SEMANTIC-WORKING-SET-COMPILER-BUNDLE_2026_06_01.md"
                .to_string(),
        ],
        PrivacyClass::VaultPrivate,
        1200,
        850,
        EvidenceNeed::ClosedCitation,
        VerifierNeed::Schema,
        4 * 1024 * 1024,
        2 * 1024 * 1024,
        4 * 1024 * 1024,
        1024 * 1024,
        1024 * 1024,
        1024 * 1024,
        1024 * 1024,
        CREATED_AT_MS,
    )?)
}

fn unit(
    id: &str,
    kind: WorkingSetUnitKind,
    uas_kind: UasKind,
    tier: WorkingSetStorageTier,
    byte_start: u64,
    byte_len: u64,
    priority: u32,
) -> Result<SemanticWorkingSetUnit, Box<dyn std::error::Error>> {
    Ok(SemanticWorkingSetUnit::new(
        id,
        kind,
        UasAddress::new(uas_kind, id.as_bytes(), CREATED_AT_MS),
        tier,
        byte_start,
        byte_len,
        "fixture-codec",
        "blake3:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        "compat:kv-budget-fixture",
        priority,
        "lease:fixture",
    )?)
}

fn missing_model_id_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = KVByteBudgetCard::new(
        "",
        8192,
        "kivi-q4-dry-run",
        KV_BYTES_PREDICTED,
        KV_BYTES_OBSERVED,
        PROMPT_CACHE_HIT_TOKENS,
        PROMPT_CACHE_MISS_TOKENS,
        "dry-run fixture",
    )
    .unwrap_err();
    Ok(matches!(error, SemanticWorkingSetError::MissingModelId))
}

fn missing_codec_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = KVByteBudgetCard::new(
        "local/kv-budget-card-fixture",
        8192,
        "",
        KV_BYTES_PREDICTED,
        KV_BYTES_OBSERVED,
        PROMPT_CACHE_HIT_TOKENS,
        PROMPT_CACHE_MISS_TOKENS,
        "dry-run fixture",
    )
    .unwrap_err();
    Ok(matches!(error, SemanticWorkingSetError::MissingKvCodec))
}

fn missing_quality_caveat_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = KVByteBudgetCard::new(
        "local/kv-budget-card-fixture",
        8192,
        "kivi-q4-dry-run",
        KV_BYTES_PREDICTED,
        KV_BYTES_OBSERVED,
        PROMPT_CACHE_HIT_TOKENS,
        PROMPT_CACHE_MISS_TOKENS,
        "",
    )
    .unwrap_err();
    Ok(matches!(
        error,
        SemanticWorkingSetError::MissingQualityCaveat
    ))
}

fn zero_context_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = KVByteBudgetCard::new(
        "local/kv-budget-card-fixture",
        0,
        "kivi-q4-dry-run",
        KV_BYTES_PREDICTED,
        KV_BYTES_OBSERVED,
        PROMPT_CACHE_HIT_TOKENS,
        PROMPT_CACHE_MISS_TOKENS,
        "dry-run fixture",
    )
    .unwrap_err();
    Ok(matches!(error, SemanticWorkingSetError::InvalidKvBudget))
}

fn zero_predicted_bytes_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = KVByteBudgetCard::new(
        "local/kv-budget-card-fixture",
        8192,
        "kivi-q4-dry-run",
        0,
        KV_BYTES_OBSERVED,
        PROMPT_CACHE_HIT_TOKENS,
        PROMPT_CACHE_MISS_TOKENS,
        "dry-run fixture",
    )
    .unwrap_err();
    Ok(matches!(error, SemanticWorkingSetError::InvalidKvBudget))
}

fn empty_compatibility_failure_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = fixture_kv_budget()?
        .with_compatibility_failures(vec!["".to_string()])
        .unwrap_err();
    Ok(matches!(error, SemanticWorkingSetError::InvalidKvBudget))
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
            unit: "count_or_bytes".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(expected)),
            unit: "count_or_bytes".to_string(),
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
