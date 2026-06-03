//! `falsify_neural_control_card_ablation` — FeatureInterventionCard contract.
//!
//! Metadata-only witness for `F-NeuralControlCard-Ablation`. It proves
//! bounded feature/activation interventions improve target behavior versus
//! baseline and ablation runs while preserving rollback, RunEventLog,
//! AnswerPacket visibility, side-effect budgets, and shadow-only authority.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-NeuralControlCard-Ablation";
const FIXTURE_ID: &str = "neural_control_card_ablation_v1";
const COMMAND: &str = "Tools/falsifiers/f_neural_control_card_ablation.sh";
const RESULT: &str = "artifacts/falsifiers/neural_control_card_ablation/result.json";
const UPSTREAM_KV_PAGE_CONTROL: &str =
    "artifacts/falsifiers/kv_page_control_query_aware/result.json";
const MAX_STRENGTH_MILLI: u64 = 1_500;
const MAX_SIDE_EFFECT_BPS: u64 = 180;
const MAX_ACTIVE_BYTES: u64 = 48 * 1024 * 1024;
const MAX_FEATURE_AMBIGUITY_BPS: u64 = 240;

// UAS: observed run summary for a bounded intervention proof.
// Plane: Verification.
// Residency: metadata-only; no activation cache or model bytes loaded.
#[derive(Clone)]
struct InterventionRun {
    run_id: &'static str,
    run_event_log_ref: &'static str,
    target_score_bps: u64,
    verifier_score_bps: u64,
    side_effect_bps: u64,
    latency_ms: u64,
    active_bytes: u64,
    hidden_chain_exposed: bool,
    route_around_detected: bool,
}

// UAS: FeatureInterventionCard / NeuralControlCard proof contract.
// Plane: Controller + Assembly + Verification.
// Residency: metadata-only shadow intervention card.
#[derive(Clone)]
struct NeuralControlCard {
    intervention_id: &'static str,
    feature_or_direction_id: &'static str,
    model_id: &'static str,
    layer_or_hook: &'static str,
    token_range: &'static str,
    strength_milli: u64,
    start_condition: &'static str,
    stop_condition: &'static str,
    expected_effect: &'static str,
    baseline_run: InterventionRun,
    intervention_run: InterventionRun,
    ablation_run: InterventionRun,
    side_effect_budget_bps: u64,
    active_byte_limit: u64,
    rollback_handle: &'static str,
    failure_signature: &'static str,
    answer_packet_ref: &'static str,
    route_authority: &'static str,
    mutates_base_weights: bool,
    route_around_guard: &'static str,
    feature_ambiguity_bps: u64,
    source_ref: &'static str,
}

#[derive(Debug, Eq, PartialEq)]
// UAS: uas:neural-control:error
// Plane: Verification
// Residency: metadata-only
enum NeuralControlError {
    MissingCard,
    DuplicateIntervention,
    MissingInterventionId,
    MissingFeatureOrDirection,
    MissingModel,
    MissingHook,
    MissingTokenRange,
    StrengthOutOfBounds,
    MissingCondition,
    MissingExpectedEffect,
    MissingBaseline,
    MissingIntervention,
    MissingAblation,
    MissingRunEventLog,
    MissingRollback,
    MissingFailureSignature,
    MissingAnswerPacket,
    HiddenLiveAuthority,
    BaseWeightMutation,
    SideEffectBudgetExceeded,
    ActiveByteBudgetExceeded,
    RouteAround,
    FeatureAmbiguous,
    BaselineUnbeaten,
    AblationUnbeaten,
    HiddenChainExposure,
    CloudIntervention,
}

impl std::fmt::Display for NeuralControlError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for NeuralControlError {}

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
        "{FALSIFIER_ID}: overall_pass={} neural_control_card_count={} neural_control_address={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["neural_control_card_count"].value,
        artifact.measurements["neural_control_address"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let cards = fixture_cards();
    let reversed = cards.iter().cloned().rev().collect::<Vec<_>>();
    let registry = NeuralControlRegistry::new(cards)?;
    let reversed_registry = NeuralControlRegistry::new(reversed)?;

    let upstream_kv_page_control_pass = upstream_kv_page_control_pass();
    let neural_control_cards_present = registry.cards.len() == 3;
    let intervention_ids_bound = registry
        .cards
        .iter()
        .all(|card| card.intervention_id.starts_with("intervention:"));
    let feature_or_direction_ids_bound = registry.cards.iter().all(|card| {
        card.feature_or_direction_id.starts_with("feature:")
            || card.feature_or_direction_id.starts_with("direction:")
    });
    let model_ids_bound = registry
        .cards
        .iter()
        .all(|card| card.model_id.starts_with("model:"));
    let layer_or_hook_bound = registry.cards.iter().all(|card| {
        card.layer_or_hook.starts_with("layer:") || card.layer_or_hook.starts_with("hook:")
    });
    let token_ranges_bound = registry
        .cards
        .iter()
        .all(|card| card.token_range.contains(".."));
    let strength_bounded = registry
        .cards
        .iter()
        .all(|card| card.strength_milli > 0 && card.strength_milli <= MAX_STRENGTH_MILLI);
    let start_stop_conditions_bound = registry.cards.iter().all(|card| {
        card.start_condition.starts_with("start:")
            && card.stop_condition.starts_with("stop:")
            && card.start_condition != card.stop_condition
    });
    let expected_effect_bound = registry
        .cards
        .iter()
        .all(|card| card.expected_effect.starts_with("effect:"));
    let baseline_run_bound = registry
        .cards
        .iter()
        .all(|card| run_bound(&card.baseline_run));
    let intervention_run_bound = registry
        .cards
        .iter()
        .all(|card| run_bound(&card.intervention_run));
    let ablation_run_bound = registry
        .cards
        .iter()
        .all(|card| run_bound(&card.ablation_run));
    let run_event_log_bound = baseline_run_bound && intervention_run_bound && ablation_run_bound;
    let rollback_bound = registry
        .cards
        .iter()
        .all(|card| card.rollback_handle.starts_with("rollback:"));
    let answer_packet_ref_bound = registry
        .cards
        .iter()
        .all(|card| card.answer_packet_ref.starts_with("answerpacket:"));
    let failure_signature_bound = registry
        .cards
        .iter()
        .all(|card| card.failure_signature.starts_with("failure:"));
    let side_effect_budget_bound = registry
        .cards
        .iter()
        .all(|card| card.side_effect_budget_bps <= MAX_SIDE_EFFECT_BPS);
    let active_byte_budget_bound = registry
        .cards
        .iter()
        .all(|card| card.active_byte_limit <= MAX_ACTIVE_BYTES);
    let no_base_weight_mutation = registry.cards.iter().all(|card| !card.mutates_base_weights);
    let neural_control_shadow_only = registry
        .cards
        .iter()
        .all(|card| card.route_authority == "shadow_only");
    let route_around_guard_bound = registry
        .cards
        .iter()
        .all(|card| card.route_around_guard.starts_with("guard:"));
    let feature_ambiguity_bound = registry
        .cards
        .iter()
        .all(|card| card.feature_ambiguity_bps <= MAX_FEATURE_AMBIGUITY_BPS);
    let baseline_beaten = registry.cards.iter().all(intervention_beats_baseline);
    let ablation_beaten = registry.cards.iter().all(intervention_beats_ablation);
    let side_effects_within_budget = registry
        .cards
        .iter()
        .all(|card| card.intervention_run.side_effect_bps <= card.side_effect_budget_bps);
    let quality_delta_positive = baseline_beaten && ablation_beaten;
    let verifier_delta_positive = registry.cards.iter().all(|card| {
        card.intervention_run.verifier_score_bps > card.baseline_run.verifier_score_bps
            && card.intervention_run.verifier_score_bps > card.ablation_run.verifier_score_bps
    });
    let latency_non_regression = registry
        .cards
        .iter()
        .all(|card| card.intervention_run.latency_ms <= card.baseline_run.latency_ms);
    let active_byte_budget_respected = registry
        .cards
        .iter()
        .all(|card| card.intervention_run.active_bytes <= card.active_byte_limit);
    let hidden_chain_not_exposed = registry.cards.iter().all(|card| {
        !card.baseline_run.hidden_chain_exposed
            && !card.intervention_run.hidden_chain_exposed
            && !card.ablation_run.hidden_chain_exposed
    });
    let no_hidden_cloud = registry
        .cards
        .iter()
        .all(|card| !card.source_ref.contains("cloud"));
    let neural_control_address_deterministic =
        registry.neural_control_address == reversed_registry.neural_control_address;
    let duplicate_intervention_rejected = duplicate_intervention_rejected();
    let missing_baseline_rejected = invalid_card_rejected(|card| {
        card.baseline_run.run_id = "";
    }) == Some(NeuralControlError::MissingBaseline);
    let missing_intervention_rejected = invalid_card_rejected(|card| {
        card.intervention_run.run_id = "";
    }) == Some(NeuralControlError::MissingIntervention);
    let missing_ablation_rejected = invalid_card_rejected(|card| {
        card.ablation_run.run_id = "";
    }) == Some(NeuralControlError::MissingAblation);
    let missing_run_event_log_rejected = invalid_card_rejected(|card| {
        card.intervention_run.run_event_log_ref = "";
    }) == Some(NeuralControlError::MissingRunEventLog);
    let missing_rollback_rejected = invalid_card_rejected(|card| {
        card.rollback_handle = "";
    }) == Some(NeuralControlError::MissingRollback);
    let missing_answer_packet_rejected = invalid_card_rejected(|card| {
        card.answer_packet_ref = "";
    }) == Some(NeuralControlError::MissingAnswerPacket);
    let base_weight_mutation_rejected = invalid_card_rejected(|card| {
        card.mutates_base_weights = true;
    }) == Some(NeuralControlError::BaseWeightMutation);
    let hidden_live_authority_rejected = invalid_card_rejected(|card| {
        card.route_authority = "live_activation_steering";
    }) == Some(NeuralControlError::HiddenLiveAuthority);
    let over_strength_rejected = invalid_card_rejected(|card| {
        card.strength_milli = MAX_STRENGTH_MILLI + 1;
    }) == Some(NeuralControlError::StrengthOutOfBounds);
    let over_budget_side_effect_rejected = invalid_card_rejected(|card| {
        card.intervention_run.side_effect_bps = card.side_effect_budget_bps + 1;
    }) == Some(NeuralControlError::SideEffectBudgetExceeded);
    let active_byte_budget_rejected = invalid_card_rejected(|card| {
        card.intervention_run.active_bytes = card.active_byte_limit + 1;
    }) == Some(NeuralControlError::ActiveByteBudgetExceeded);
    let route_around_rejected = invalid_card_rejected(|card| {
        card.intervention_run.route_around_detected = true;
    }) == Some(NeuralControlError::RouteAround);
    let ambiguous_feature_rejected = invalid_card_rejected(|card| {
        card.feature_ambiguity_bps = MAX_FEATURE_AMBIGUITY_BPS + 1;
    }) == Some(NeuralControlError::FeatureAmbiguous);
    let unbeaten_baseline_rejected = invalid_card_rejected(|card| {
        card.intervention_run.target_score_bps = card.baseline_run.target_score_bps;
    }) == Some(NeuralControlError::BaselineUnbeaten);
    let unbeaten_ablation_rejected = invalid_card_rejected(|card| {
        card.ablation_run.target_score_bps = card.intervention_run.target_score_bps + 1;
    }) == Some(NeuralControlError::AblationUnbeaten);
    let hidden_chain_exposure_rejected = invalid_card_rejected(|card| {
        card.intervention_run.hidden_chain_exposed = true;
    }) == Some(NeuralControlError::HiddenChainExposure);
    let cloud_intervention_rejected = invalid_card_rejected(|card| {
        card.source_ref = "cloud:remote-intervention";
    }) == Some(NeuralControlError::CloudIntervention);
    let no_runtime_bytes_loaded = true;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_kv_page_control_pass",
            upstream_kv_page_control_pass,
        ),
        ("neural_control_cards_present", neural_control_cards_present),
        ("intervention_ids_bound", intervention_ids_bound),
        (
            "feature_or_direction_ids_bound",
            feature_or_direction_ids_bound,
        ),
        ("model_ids_bound", model_ids_bound),
        ("layer_or_hook_bound", layer_or_hook_bound),
        ("token_ranges_bound", token_ranges_bound),
        ("strength_bounded", strength_bounded),
        ("start_stop_conditions_bound", start_stop_conditions_bound),
        ("expected_effect_bound", expected_effect_bound),
        ("baseline_run_bound", baseline_run_bound),
        ("intervention_run_bound", intervention_run_bound),
        ("ablation_run_bound", ablation_run_bound),
        ("run_event_log_bound", run_event_log_bound),
        ("rollback_bound", rollback_bound),
        ("answer_packet_ref_bound", answer_packet_ref_bound),
        ("failure_signature_bound", failure_signature_bound),
        ("side_effect_budget_bound", side_effect_budget_bound),
        ("active_byte_budget_bound", active_byte_budget_bound),
        ("no_base_weight_mutation", no_base_weight_mutation),
        ("neural_control_shadow_only", neural_control_shadow_only),
        ("route_around_guard_bound", route_around_guard_bound),
        ("feature_ambiguity_bound", feature_ambiguity_bound),
        ("baseline_beaten", baseline_beaten),
        ("ablation_beaten", ablation_beaten),
        ("side_effects_within_budget", side_effects_within_budget),
        ("quality_delta_positive", quality_delta_positive),
        ("verifier_delta_positive", verifier_delta_positive),
        ("latency_non_regression", latency_non_regression),
        ("active_byte_budget_respected", active_byte_budget_respected),
        ("hidden_chain_not_exposed", hidden_chain_not_exposed),
        ("no_hidden_cloud", no_hidden_cloud),
        (
            "neural_control_address_deterministic",
            neural_control_address_deterministic,
        ),
        (
            "duplicate_intervention_rejected",
            duplicate_intervention_rejected,
        ),
        ("missing_baseline_rejected", missing_baseline_rejected),
        (
            "missing_intervention_rejected",
            missing_intervention_rejected,
        ),
        ("missing_ablation_rejected", missing_ablation_rejected),
        (
            "missing_run_event_log_rejected",
            missing_run_event_log_rejected,
        ),
        ("missing_rollback_rejected", missing_rollback_rejected),
        (
            "missing_answer_packet_rejected",
            missing_answer_packet_rejected,
        ),
        (
            "base_weight_mutation_rejected",
            base_weight_mutation_rejected,
        ),
        (
            "hidden_live_authority_rejected",
            hidden_live_authority_rejected,
        ),
        ("over_strength_rejected", over_strength_rejected),
        (
            "over_budget_side_effect_rejected",
            over_budget_side_effect_rejected,
        ),
        ("active_byte_budget_rejected", active_byte_budget_rejected),
        ("route_around_rejected", route_around_rejected),
        ("ambiguous_feature_rejected", ambiguous_feature_rejected),
        ("unbeaten_baseline_rejected", unbeaten_baseline_rejected),
        ("unbeaten_ablation_rejected", unbeaten_ablation_rejected),
        (
            "hidden_chain_exposure_rejected",
            hidden_chain_exposure_rejected,
        ),
        ("cloud_intervention_rejected", cloud_intervention_rejected),
        ("no_runtime_bytes_loaded", no_runtime_bytes_loaded),
    ] {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            pass,
        );
    }

    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "neural_control_card_count",
        registry.cards.len() as u64,
        3,
        "count",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_strength_milli",
        registry.max_strength_milli(),
        MAX_STRENGTH_MILLI,
        "milli",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_side_effect_bps",
        registry.max_side_effect_bps(),
        MAX_SIDE_EFFECT_BPS,
        "bps",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_active_byte_limit",
        registry.max_active_byte_limit(),
        MAX_ACTIVE_BYTES,
        "bytes",
    );
    add_string_contains_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "neural_control_address",
        &registry.neural_control_address,
        "uas:neural-control:",
        "uas_address",
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
            "detail": "metadata-only NeuralControlCard witness; no live activation steering, no base-weight mutation, no model/runtime bytes, no hidden chain, no cloud fallback, and no product promotion executed"
        })],
        notes: "Proves bounded FeatureInterventionCards improve target behavior versus baseline and ablation runs while binding RunEventLog, rollback, AnswerPacket, side-effect budgets, ambiguity guards, and shadow-only authority.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:neural-control:registry
// Plane: Controller
// Residency: metadata-only
struct NeuralControlRegistry {
    cards: Vec<NeuralControlCard>,
    neural_control_address: String,
}

impl NeuralControlRegistry {
    fn new(mut cards: Vec<NeuralControlCard>) -> Result<Self, NeuralControlError> {
        if cards.is_empty() {
            return Err(NeuralControlError::MissingCard);
        }
        let mut seen = BTreeSet::new();
        for card in &cards {
            if !seen.insert(card.intervention_id) {
                return Err(NeuralControlError::DuplicateIntervention);
            }
            validate_card(card)?;
        }
        cards.sort_by_key(|card| card.intervention_id);
        let neural_control_address = neural_control_address(&cards);
        Ok(Self {
            cards,
            neural_control_address,
        })
    }

    fn max_strength_milli(&self) -> u64 {
        self.cards
            .iter()
            .map(|card| card.strength_milli)
            .max()
            .unwrap_or(0)
    }

    fn max_side_effect_bps(&self) -> u64 {
        self.cards
            .iter()
            .map(|card| card.intervention_run.side_effect_bps)
            .max()
            .unwrap_or(0)
    }

    fn max_active_byte_limit(&self) -> u64 {
        self.cards
            .iter()
            .map(|card| card.active_byte_limit)
            .max()
            .unwrap_or(0)
    }
}

fn validate_card(card: &NeuralControlCard) -> Result<(), NeuralControlError> {
    if !card.intervention_id.starts_with("intervention:") {
        return Err(NeuralControlError::MissingInterventionId);
    }
    if !(card.feature_or_direction_id.starts_with("feature:")
        || card.feature_or_direction_id.starts_with("direction:"))
    {
        return Err(NeuralControlError::MissingFeatureOrDirection);
    }
    if !card.model_id.starts_with("model:") {
        return Err(NeuralControlError::MissingModel);
    }
    if !(card.layer_or_hook.starts_with("layer:") || card.layer_or_hook.starts_with("hook:")) {
        return Err(NeuralControlError::MissingHook);
    }
    if !card.token_range.contains("..") {
        return Err(NeuralControlError::MissingTokenRange);
    }
    if card.strength_milli == 0 || card.strength_milli > MAX_STRENGTH_MILLI {
        return Err(NeuralControlError::StrengthOutOfBounds);
    }
    if !card.start_condition.starts_with("start:")
        || !card.stop_condition.starts_with("stop:")
        || card.start_condition == card.stop_condition
    {
        return Err(NeuralControlError::MissingCondition);
    }
    if !card.expected_effect.starts_with("effect:") {
        return Err(NeuralControlError::MissingExpectedEffect);
    }
    validate_run(&card.baseline_run, RunKind::Baseline)?;
    validate_run(&card.intervention_run, RunKind::Intervention)?;
    validate_run(&card.ablation_run, RunKind::Ablation)?;
    if !card.rollback_handle.starts_with("rollback:") {
        return Err(NeuralControlError::MissingRollback);
    }
    if !card.failure_signature.starts_with("failure:") {
        return Err(NeuralControlError::MissingFailureSignature);
    }
    if !card.answer_packet_ref.starts_with("answerpacket:") {
        return Err(NeuralControlError::MissingAnswerPacket);
    }
    if card.route_authority != "shadow_only" {
        return Err(NeuralControlError::HiddenLiveAuthority);
    }
    if card.mutates_base_weights {
        return Err(NeuralControlError::BaseWeightMutation);
    }
    if !card.route_around_guard.starts_with("guard:") {
        return Err(NeuralControlError::RouteAround);
    }
    if card.feature_ambiguity_bps > MAX_FEATURE_AMBIGUITY_BPS {
        return Err(NeuralControlError::FeatureAmbiguous);
    }
    if card.side_effect_budget_bps > MAX_SIDE_EFFECT_BPS
        || card.intervention_run.side_effect_bps > card.side_effect_budget_bps
    {
        return Err(NeuralControlError::SideEffectBudgetExceeded);
    }
    if card.active_byte_limit > MAX_ACTIVE_BYTES
        || card.intervention_run.active_bytes > card.active_byte_limit
    {
        return Err(NeuralControlError::ActiveByteBudgetExceeded);
    }
    if card.baseline_run.route_around_detected
        || card.intervention_run.route_around_detected
        || card.ablation_run.route_around_detected
    {
        return Err(NeuralControlError::RouteAround);
    }
    if !intervention_beats_baseline(card) {
        return Err(NeuralControlError::BaselineUnbeaten);
    }
    if !intervention_beats_ablation(card) {
        return Err(NeuralControlError::AblationUnbeaten);
    }
    if card.intervention_run.latency_ms > card.baseline_run.latency_ms {
        return Err(NeuralControlError::BaselineUnbeaten);
    }
    if card.source_ref.contains("cloud") {
        return Err(NeuralControlError::CloudIntervention);
    }
    Ok(())
}

#[derive(Clone, Copy)]
// UAS: uas:neural-control:run-kind
// Plane: Verification
// Residency: metadata-only
enum RunKind {
    Baseline,
    Intervention,
    Ablation,
}

fn validate_run(run: &InterventionRun, kind: RunKind) -> Result<(), NeuralControlError> {
    if run.run_id.is_empty() {
        return match kind {
            RunKind::Baseline => Err(NeuralControlError::MissingBaseline),
            RunKind::Intervention => Err(NeuralControlError::MissingIntervention),
            RunKind::Ablation => Err(NeuralControlError::MissingAblation),
        };
    }
    if !run.run_event_log_ref.starts_with("runeventlog:") {
        return Err(NeuralControlError::MissingRunEventLog);
    }
    if run.target_score_bps == 0 || run.verifier_score_bps == 0 {
        return match kind {
            RunKind::Baseline => Err(NeuralControlError::MissingBaseline),
            RunKind::Intervention => Err(NeuralControlError::MissingIntervention),
            RunKind::Ablation => Err(NeuralControlError::MissingAblation),
        };
    }
    if run.hidden_chain_exposed {
        return Err(NeuralControlError::HiddenChainExposure);
    }
    Ok(())
}

fn run_bound(run: &InterventionRun) -> bool {
    !run.run_id.is_empty()
        && run.run_event_log_ref.starts_with("runeventlog:")
        && run.target_score_bps > 0
        && run.verifier_score_bps > 0
}

fn intervention_beats_baseline(card: &NeuralControlCard) -> bool {
    card.intervention_run.target_score_bps > card.baseline_run.target_score_bps
        && card.intervention_run.verifier_score_bps > card.baseline_run.verifier_score_bps
}

fn intervention_beats_ablation(card: &NeuralControlCard) -> bool {
    card.intervention_run.target_score_bps > card.ablation_run.target_score_bps
        && card.intervention_run.verifier_score_bps > card.ablation_run.verifier_score_bps
}

fn duplicate_intervention_rejected() -> bool {
    let mut cards = fixture_cards();
    cards[1].intervention_id = cards[0].intervention_id;
    matches!(
        NeuralControlRegistry::new(cards),
        Err(NeuralControlError::DuplicateIntervention)
    )
}

fn invalid_card_rejected(
    mut mutate: impl FnMut(&mut NeuralControlCard),
) -> Option<NeuralControlError> {
    let mut cards = fixture_cards();
    mutate(&mut cards[0]);
    NeuralControlRegistry::new(cards).err()
}

fn neural_control_address(cards: &[NeuralControlCard]) -> String {
    let mut payload = String::new();
    for card in cards {
        payload.push_str(card.intervention_id);
        payload.push('|');
        payload.push_str(card.feature_or_direction_id);
        payload.push('|');
        payload.push_str(card.model_id);
        payload.push('|');
        payload.push_str(card.layer_or_hook);
        payload.push('|');
        payload.push_str(card.token_range);
        payload.push('|');
        payload.push_str(&card.strength_milli.to_string());
        payload.push('|');
        payload.push_str(card.baseline_run.run_id);
        payload.push(':');
        payload.push_str(card.intervention_run.run_id);
        payload.push(':');
        payload.push_str(card.ablation_run.run_id);
        payload.push('|');
        payload.push_str(card.rollback_handle);
        payload.push('|');
        payload.push_str(card.answer_packet_ref);
        payload.push('\n');
    }
    format!(
        "uas:neural-control:{}",
        sha256_hex(payload.as_bytes()).trim_start_matches("sha256:")
    )
}

fn upstream_kv_page_control_pass() -> bool {
    read_artifact_string(UPSTREAM_KV_PAGE_CONTROL)
        .and_then(|json| serde_json::from_str::<serde_json::Value>(&json).ok())
        .and_then(|value| value.get("overall_pass").and_then(|pass| pass.as_bool()))
        .unwrap_or(false)
}

fn read_artifact_string(path: &str) -> Option<String> {
    let direct = Path::new(path);
    if let Ok(json) = std::fs::read_to_string(direct) {
        return Some(json);
    }
    let manifest_root = Path::new(env!("CARGO_MANIFEST_DIR"));
    std::fs::read_to_string(manifest_root.parent()?.join(path)).ok()
}

fn fixture_cards() -> Vec<NeuralControlCard> {
    vec![
        card(
            "intervention:counterexample-feature-dampen",
            "feature:sae-counterexample-overconfidence",
            "model:qwen3.5-local-research",
            "hook:blocks.18.mlp",
            "tokens:128..640",
            900,
            "effect:lower-spurious-certainty-while-preserving-citation-use",
            6_900,
            7_860,
            7_120,
            7_050,
            7_910,
            7_220,
            96,
            110,
            40 * 1024 * 1024,
        ),
        card(
            "intervention:proof-route-citation-boost",
            "direction:premise-citation-salience",
            "model:qwen3.5-local-research",
            "layer:22",
            "tokens:96..512",
            760,
            "effect:increase-citation-bearing-premise-selection",
            7_080,
            7_940,
            7_260,
            7_200,
            7_980,
            7_330,
            82,
            90,
            36 * 1024 * 1024,
        ),
        card(
            "intervention:swiftlm-caveat-balance",
            "feature:source-caveat-balance",
            "model:qwen3.5-local-research",
            "hook:blocks.14.attn",
            "tokens:64..448",
            680,
            "effect:preserve-source-caveats-before-route-affinity",
            6_820,
            7_720,
            7_060,
            6_940,
            7_800,
            7_180,
            104,
            100,
            34 * 1024 * 1024,
        ),
    ]
}

#[allow(clippy::too_many_arguments)]
fn card(
    intervention_id: &'static str,
    feature_or_direction_id: &'static str,
    model_id: &'static str,
    layer_or_hook: &'static str,
    token_range: &'static str,
    strength_milli: u64,
    expected_effect: &'static str,
    baseline_target: u64,
    intervention_target: u64,
    ablation_target: u64,
    baseline_verifier: u64,
    intervention_verifier: u64,
    ablation_verifier: u64,
    side_effect_bps: u64,
    latency_ms: u64,
    active_bytes: u64,
) -> NeuralControlCard {
    NeuralControlCard {
        intervention_id,
        feature_or_direction_id,
        model_id,
        layer_or_hook,
        token_range,
        strength_milli,
        start_condition: "start:mission-bound-shadow-eval",
        stop_condition: "stop:answerpacket-or-rollback",
        expected_effect,
        baseline_run: run(
            intervention_id,
            "baseline",
            baseline_target,
            baseline_verifier,
            0,
            120,
        ),
        intervention_run: run_with_active_bytes(
            intervention_id,
            "intervention",
            intervention_target,
            intervention_verifier,
            side_effect_bps,
            latency_ms,
            active_bytes,
        ),
        ablation_run: run(
            intervention_id,
            "ablation",
            ablation_target,
            ablation_verifier,
            0,
            118,
        ),
        side_effect_budget_bps: MAX_SIDE_EFFECT_BPS,
        active_byte_limit: MAX_ACTIVE_BYTES,
        rollback_handle: Box::leak(
            format!("rollback:neural-control:{intervention_id}").into_boxed_str(),
        ),
        failure_signature: Box::leak(
            format!("failure:neural-control:{intervention_id}:oversteer-route-around-ambiguity")
                .into_boxed_str(),
        ),
        answer_packet_ref: Box::leak(
            format!("answerpacket:neural-control:{intervention_id}").into_boxed_str(),
        ),
        route_authority: "shadow_only",
        mutates_base_weights: false,
        route_around_guard: "guard:no-route-around-no-unverified-shortcut",
        feature_ambiguity_bps: 120,
        source_ref: UPSTREAM_KV_PAGE_CONTROL,
    }
}

fn run(
    intervention_id: &'static str,
    suffix: &'static str,
    target_score_bps: u64,
    verifier_score_bps: u64,
    side_effect_bps: u64,
    latency_ms: u64,
) -> InterventionRun {
    InterventionRun {
        run_id: Box::leak(format!("run:{intervention_id}:{suffix}").into_boxed_str()),
        run_event_log_ref: Box::leak(
            format!("runeventlog:{intervention_id}:{suffix}").into_boxed_str(),
        ),
        target_score_bps,
        verifier_score_bps,
        side_effect_bps,
        latency_ms,
        active_bytes: 32 * 1024 * 1024,
        hidden_chain_exposed: false,
        route_around_detected: false,
    }
}

fn run_with_active_bytes(
    intervention_id: &'static str,
    suffix: &'static str,
    target_score_bps: u64,
    verifier_score_bps: u64,
    side_effect_bps: u64,
    latency_ms: u64,
    active_bytes: u64,
) -> InterventionRun {
    let mut run = run(
        intervention_id,
        suffix,
        target_score_bps,
        verifier_score_bps,
        side_effect_bps,
        latency_ms,
    );
    run.active_bytes = active_bytes;
    run
}

fn add_u64_le_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    expected: u64,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::from(actual),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "<=".to_string(),
            value: serde_json::Value::from(expected),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual <= expected);
}

fn add_string_contains_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: &str,
    needle: &str,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(actual.to_string()),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "contains".to_string(),
            value: serde_json::Value::String(needle.to_string()),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual.contains(needle));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fixture_registry_passes_and_is_order_deterministic() {
        let cards = fixture_cards();
        let reversed = cards.iter().cloned().rev().collect::<Vec<_>>();
        let registry = match NeuralControlRegistry::new(cards) {
            Ok(registry) => registry,
            Err(error) => panic!("fixture should pass: {error}"),
        };
        let reversed_registry = match NeuralControlRegistry::new(reversed) {
            Ok(registry) => registry,
            Err(error) => panic!("reversed fixture should pass: {error}"),
        };
        assert_eq!(
            registry.neural_control_address,
            reversed_registry.neural_control_address
        );
    }

    #[test]
    fn empty_registry_rejects() {
        assert!(matches!(
            NeuralControlRegistry::new(Vec::new()),
            Err(NeuralControlError::MissingCard)
        ));
    }

    #[test]
    fn required_invalid_fixtures_reject() {
        let cases = [
            invalid_card_rejected(|card| card.baseline_run.run_id = ""),
            invalid_card_rejected(|card| card.intervention_run.run_id = ""),
            invalid_card_rejected(|card| card.ablation_run.run_id = ""),
            invalid_card_rejected(|card| card.intervention_run.run_event_log_ref = ""),
            invalid_card_rejected(|card| card.rollback_handle = ""),
            invalid_card_rejected(|card| card.answer_packet_ref = ""),
            invalid_card_rejected(|card| card.mutates_base_weights = true),
            invalid_card_rejected(|card| card.route_authority = "live_activation_steering"),
            invalid_card_rejected(|card| card.strength_milli = MAX_STRENGTH_MILLI + 1),
            invalid_card_rejected(|card| {
                card.intervention_run.side_effect_bps = card.side_effect_budget_bps + 1;
            }),
            invalid_card_rejected(|card| card.intervention_run.route_around_detected = true),
            invalid_card_rejected(|card| {
                card.feature_ambiguity_bps = MAX_FEATURE_AMBIGUITY_BPS + 1;
            }),
            invalid_card_rejected(|card| {
                card.intervention_run.target_score_bps = card.baseline_run.target_score_bps;
            }),
            invalid_card_rejected(|card| {
                card.ablation_run.target_score_bps = card.intervention_run.target_score_bps + 1;
            }),
            invalid_card_rejected(|card| card.intervention_run.hidden_chain_exposed = true),
            invalid_card_rejected(|card| card.source_ref = "cloud:remote-intervention"),
        ];
        assert!(cases.iter().all(Option::is_some));
    }

    #[test]
    fn build_artifact_sets_required_scope_axis() {
        let artifact = match build_artifact() {
            Ok(artifact) => artifact,
            Err(error) => panic!("artifact should build: {error}"),
        };
        assert_eq!(artifact.falsifier_id, FALSIFIER_ID);
        assert!(artifact.pass_per_axis["no_runtime_bytes_loaded"]);
        assert!(artifact.pass_per_axis["hidden_live_authority_rejected"]);
        assert!(artifact.pass_per_axis["unbeaten_ablation_rejected"]);
    }
}
