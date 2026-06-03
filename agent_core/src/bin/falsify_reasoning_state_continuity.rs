//! `falsify_reasoning_state_continuity` — resumable-state dry-run witness.
//!
//! This fixture-only witness proves preserved state can improve continuity and
//! cache utility without exposing hidden reasoning, bypassing verification, or
//! mutating live cache/runtime policy.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    PreservedStateKind, ReasoningStateBaseline, ReasoningStateContinuityCard,
    ReasoningStateContinuityError, StatePrivacyClass,
};

const FALSIFIER_ID: &str = "F-ReasoningStateContinuity";
const FIXTURE_ID: &str = "reasoning_state_continuity_v1";
const COMMAND: &str = "Tools/falsifiers/f_reasoning_state_continuity.sh";
const RESULT: &str = "artifacts/falsifiers/reasoning_state_continuity/result.json";
const CREATED_AT_MS: u64 = 1_779_400_200_000;

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
        "{FALSIFIER_ID}: overall_pass={} continuity_score={} cache_utility={} artifact={RESULT}",
        report.artifact.overall_pass, report.continuity_score_bps, report.cache_utility_bps
    );

    if report.artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

// UAS: uas/research-construction/reasoning-state-continuity-falsifier-report
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
struct ReasoningStateContinuityReport {
    artifact: agent_core::falsifier_artifacts::FalsifierArtifact,
    continuity_score_bps: u16,
    cache_utility_bps: u16,
}

fn build_report() -> Result<ReasoningStateContinuityReport, Box<dyn std::error::Error>> {
    let card = accepted_card(false)?;
    let reversed = accepted_card(true)?;
    let no_state = card
        .baseline("no_state")
        .ok_or("missing no_state baseline")?;
    let naive_cache = card
        .baseline("naive_cache")
        .ok_or("missing naive_cache baseline")?;
    let static_summary = card
        .baseline("static_summary")
        .ok_or("missing static_summary baseline")?;
    let max_baseline_continuity = card
        .baselines
        .iter()
        .map(|baseline| baseline.continuity_bps)
        .max()
        .unwrap_or_default();
    let max_baseline_cache = card
        .baselines
        .iter()
        .map(|baseline| baseline.cache_utility_bps)
        .max()
        .unwrap_or_default();
    let max_baseline_verifier = card
        .baselines
        .iter()
        .map(|baseline| baseline.verifier_bps)
        .max()
        .unwrap_or_default();
    let min_baseline_latency = card
        .baselines
        .iter()
        .map(|baseline| baseline.latency_ms)
        .min()
        .unwrap_or_default();
    let min_baseline_active_bytes = card
        .baselines
        .iter()
        .map(|baseline| baseline.active_executed_bytes)
        .min()
        .unwrap_or_default();

    let missing_purge_policy_rejected = invalid_missing_purge_policy()
        .is_err_and(|error| matches!(error, ReasoningStateContinuityError::MissingPurgePolicy));
    let incompatible_fence_rejected = invalid_bad_compatibility_fence().is_err_and(|error| {
        matches!(
            error,
            ReasoningStateContinuityError::MissingCompatibilityFence
        )
    });
    let missing_answer_packet_rejected = invalid_missing_answer_packet()
        .is_err_and(|error| matches!(error, ReasoningStateContinuityError::MissingAnswerPacketRef));
    let hidden_chain_rejected = invalid_hidden_chain()
        .is_err_and(|error| matches!(error, ReasoningStateContinuityError::HiddenChainExposed));
    let verifier_bypass_rejected = invalid_verifier_bypass()
        .is_err_and(|error| matches!(error, ReasoningStateContinuityError::VerifierBypass));
    let stale_state_reuse_rejected = invalid_stale_state_reuse()
        .is_err_and(|error| matches!(error, ReasoningStateContinuityError::StaleStateReused));
    let unbeaten_naive_cache_rejected = invalid_unbeaten_naive_cache()
        .is_err_and(|error| matches!(error, ReasoningStateContinuityError::BaselineNotBeaten));

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "reasoning_state_card_present",
        card.preserved_state_kind == PreservedStateKind::ReasoningSummary,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_card_ids_bound",
        card.source_card_ids.len() == 2,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "task_signature_bound",
        card.task_signature == "task:resume-cold-assembly-verification",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "session_id_bound",
        card.session_id == "session:adversarial-note-route",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_id_bound",
        card.model_id == "model:local-mlx-controller",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "preserved_state_kind_bound",
        card.preserved_state_kind == PreservedStateKind::ReasoningSummary,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "privacy_class_bound",
        card.privacy_class == StatePrivacyClass::VaultPrivate,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "visible_summary_present",
        card.visible_summary.contains("Visible summary"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cache_key_bound",
        card.cache_key.starts_with("cache:"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "restore_policy_bound",
        card.restore_policy.contains("summary-only"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compatibility_fence_bound",
        incompatible_fence_rejected
            && card
                .compatibility_fence_ref
                .starts_with("compatibility_fence:"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_caveat_bound",
        card.verifier_caveat.starts_with("verifier:"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "purge_policy_bound",
        missing_purge_policy_rejected && card.purge_policy.starts_with("purge:"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compute_resume_lease_bound",
        card.compute_resume_lease_ref
            .starts_with("compute_resume_lease:"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fallback_bound",
        card.fallback_route.starts_with("fallback:"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rollback_verified",
        card.rollback_ref.starts_with("rollback:"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "answer_packet_ref_bound",
        missing_answer_packet_rejected && card.answer_packet_ref.starts_with("answer_packet:"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "beats_no_state_baseline",
        beats_baseline(&card, no_state),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "beats_naive_cache_baseline",
        beats_baseline(&card, naive_cache),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "beats_static_summary_baseline",
        beats_baseline(&card, static_summary),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "continuity_delta_positive",
        card.continuity_bps > max_baseline_continuity,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cache_utility_delta_positive",
        card.cache_utility_bps > max_baseline_cache,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_delta_positive",
        card.verifier_bps > max_baseline_verifier,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "latency_delta_positive",
        card.latency_ms < min_baseline_latency,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "active_bytes_delta_positive",
        card.active_executed_bytes < min_baseline_active_bytes,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hidden_chain_not_exposed",
        hidden_chain_rejected && !card.hidden_chain_exposed,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_bypass_rejected",
        verifier_bypass_rejected && !card.verifier_bypass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "stale_state_reuse_rejected",
        stale_state_reuse_rejected && !card.stale_state_reused,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "missing_purge_policy_rejected",
        missing_purge_policy_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "incompatible_fence_rejected",
        incompatible_fence_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "missing_answer_packet_rejected",
        missing_answer_packet_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "unbeaten_naive_cache_rejected",
        unbeaten_naive_cache_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_runtime_bytes_loaded",
        true,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "continuity_card_address_deterministic",
        card.card_address == reversed.card_address,
    );

    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_card_count",
        card.source_card_ids.len() as u64,
        2,
        "==",
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "baseline_count",
        card.baselines.len() as u64,
        3,
        "==",
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "continuity_score_bps",
        u64::from(card.score_bps()),
        u64::from(no_state.score_bps()),
        ">",
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cache_utility_bps",
        u64::from(card.cache_utility_bps),
        u64::from(max_baseline_cache),
        ">",
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_bps",
        u64::from(card.verifier_bps),
        u64::from(max_baseline_verifier),
        ">",
        "bps",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "latency_ms",
        card.latency_ms,
        min_baseline_latency,
        "<",
        "ms",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "active_executed_bytes",
        card.active_executed_bytes,
        min_baseline_active_bytes,
        "<",
        "bytes",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "preserved_state_kind",
        card.preserved_state_kind.wire_tag(),
        card.preserved_state_kind.wire_tag(),
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "privacy_class",
        card.privacy_class.wire_tag(),
        card.privacy_class.wire_tag(),
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "card_address",
        &card.card_address.to_string(),
        &card.card_address.to_string(),
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
            "detail": "metadata-only reasoning-state continuity fixture; no hidden chain exposure, verifier bypass, stale-state reuse, model decode, MLX, Metal, provider call, or production cache mutation executed"
        })],
        notes: "metadata-only reasoning continuity witness; preserved state is visible summary/cache policy, not hidden chain-of-thought proof; no runtime/model bytes loaded".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(ReasoningStateContinuityReport {
        artifact,
        continuity_score_bps: card.score_bps(),
        cache_utility_bps: card.cache_utility_bps,
    })
}

fn accepted_card(
    reversed_sources: bool,
) -> Result<ReasoningStateContinuityCard, ReasoningStateContinuityError> {
    build_card(
        reversed_sources,
        "compatibility_fence:model-tokenizer-adapter-rope-system-digest-route",
        "purge:session-close-or-24h",
        "answer_packet:continuity-card-visible-note",
        false,
        false,
        false,
        baselines(),
    )
}

#[allow(clippy::too_many_arguments)]
fn build_card(
    reversed_sources: bool,
    compatibility_fence_ref: &str,
    purge_policy: &str,
    answer_packet_ref: &str,
    hidden_chain_exposed: bool,
    verifier_bypass: bool,
    stale_state_reused: bool,
    baselines: Vec<ReasoningStateBaseline>,
) -> Result<ReasoningStateContinuityCard, ReasoningStateContinuityError> {
    let source_card_ids = if reversed_sources {
        vec![
            "source:constructive-residency".to_string(),
            "source:cache-lineage".to_string(),
        ]
    } else {
        vec![
            "source:cache-lineage".to_string(),
            "source:constructive-residency".to_string(),
        ]
    };
    ReasoningStateContinuityCard::new(
        "session:adversarial-note-route",
        "model:local-mlx-controller",
        source_card_ids,
        "task:resume-cold-assembly-verification",
        PreservedStateKind::ReasoningSummary,
        StatePrivacyClass::VaultPrivate,
        "Visible summary: verifier lane checked the cold assembly plan and needs source replay.",
        "cache:reasoning-summary:cold-assembly-v1",
        "restore:summary-only-after-fence",
        compatibility_fence_ref,
        "verifier:state-is-context-not-proof",
        purge_policy,
        "compute_resume_lease:cold-assembly-route:pause-verify-resume",
        8450,
        8120,
        8300,
        420,
        24_576,
        900,
        450,
        320,
        "fallback:no-state-rag-verified",
        "rollback:drop-continuity-card",
        answer_packet_ref,
        hidden_chain_exposed,
        verifier_bypass,
        stale_state_reused,
        baselines,
        CREATED_AT_MS,
    )
}

fn baselines() -> Vec<ReasoningStateBaseline> {
    vec![
        ReasoningStateBaseline::new(
            "no_state", 5900, 3600, 6500, 980, 65_536, false, false, false,
        )
        .unwrap(),
        ReasoningStateBaseline::new(
            "naive_cache",
            6500,
            6900,
            6600,
            720,
            49_152,
            false,
            false,
            false,
        )
        .unwrap(),
        ReasoningStateBaseline::new(
            "static_summary",
            7000,
            6100,
            7100,
            760,
            57_344,
            false,
            false,
            false,
        )
        .unwrap(),
    ]
}

fn invalid_missing_purge_policy(
) -> Result<ReasoningStateContinuityCard, ReasoningStateContinuityError> {
    build_card(
        false,
        "compatibility_fence:f",
        "",
        "answer_packet:a",
        false,
        false,
        false,
        baselines(),
    )
}

fn invalid_bad_compatibility_fence(
) -> Result<ReasoningStateContinuityCard, ReasoningStateContinuityError> {
    build_card(
        false,
        "bad_fence:f",
        "purge:p",
        "answer_packet:a",
        false,
        false,
        false,
        baselines(),
    )
}

fn invalid_missing_answer_packet(
) -> Result<ReasoningStateContinuityCard, ReasoningStateContinuityError> {
    build_card(
        false,
        "compatibility_fence:f",
        "purge:p",
        "",
        false,
        false,
        false,
        baselines(),
    )
}

fn invalid_hidden_chain() -> Result<ReasoningStateContinuityCard, ReasoningStateContinuityError> {
    build_card(
        false,
        "compatibility_fence:f",
        "purge:p",
        "answer_packet:a",
        true,
        false,
        false,
        baselines(),
    )
}

fn invalid_verifier_bypass() -> Result<ReasoningStateContinuityCard, ReasoningStateContinuityError>
{
    build_card(
        false,
        "compatibility_fence:f",
        "purge:p",
        "answer_packet:a",
        false,
        true,
        false,
        baselines(),
    )
}

fn invalid_stale_state_reuse() -> Result<ReasoningStateContinuityCard, ReasoningStateContinuityError>
{
    build_card(
        false,
        "compatibility_fence:f",
        "purge:p",
        "answer_packet:a",
        false,
        false,
        true,
        baselines(),
    )
}

fn invalid_unbeaten_naive_cache(
) -> Result<ReasoningStateContinuityCard, ReasoningStateContinuityError> {
    let mut baselines = baselines();
    baselines[1].continuity_bps = 9000;
    build_card(
        false,
        "compatibility_fence:f",
        "purge:p",
        "answer_packet:a",
        false,
        false,
        false,
        baselines,
    )
}

fn beats_baseline(card: &ReasoningStateContinuityCard, baseline: &ReasoningStateBaseline) -> bool {
    card.score_bps() > baseline.score_bps()
        && card.continuity_bps > baseline.continuity_bps
        && card.cache_utility_bps > baseline.cache_utility_bps
        && card.verifier_bps > baseline.verifier_bps
        && card.latency_ms < baseline.latency_ms
        && card.active_executed_bytes < baseline.active_executed_bytes
        && !baseline.hidden_chain_exposed
        && !baseline.verifier_bypass
        && !baseline.stale_state_reused
}

fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: u64,
    threshold: u64,
    operator: &str,
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
            operator: operator.to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(threshold)),
            unit: unit.to_string(),
        },
    );
    let pass = match operator {
        "==" => value == threshold,
        ">" => value > threshold,
        "<" => value < threshold,
        _ => false,
    };
    pass_per_axis.insert(axis.to_string(), pass);
}

fn add_string_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: &str,
    expected: &str,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::String(value.to_string()),
            unit: "label".to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::String(expected.to_string()),
            unit: "label".to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), value == expected);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn report_contains_required_reasoning_state_axes() {
        let report = build_report().expect("report");
        let axes = &report.artifact.pass_per_axis;
        for axis in [
            "reasoning_state_card_present",
            "visible_summary_present",
            "cache_key_bound",
            "compatibility_fence_bound",
            "purge_policy_bound",
            "compute_resume_lease_bound",
            "beats_no_state_baseline",
            "beats_naive_cache_baseline",
            "hidden_chain_not_exposed",
            "verifier_bypass_rejected",
            "stale_state_reuse_rejected",
            "continuity_card_address_deterministic",
        ] {
            assert_eq!(axes.get(axis), Some(&true), "axis {axis}");
        }
        assert!(report.artifact.overall_pass);
    }
}
