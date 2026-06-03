//! Lattice state controller for constructive residency routing.
//!
//! This is a metadata-only route-controller witness. It models a tiny
//! recurrent/lattice-style controller that chooses wake/retrieve/continue/
//! verify/abstain actions from abstract route state, compares that choice to
//! static baselines, and refuses hidden live authority.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;

use crate::uas::{UasAddress, UasKind};

const CONTROLLER_UAS_KIND: &str = "lattice_state_controller";
const FALLBACK_PREFIX: &str = "fallback:";
const ROLLBACK_PREFIX: &str = "rollback:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const BASELINE_NAMES: [&str; 3] = ["static_policy", "random_policy", "always_retrieve"];

// UAS: uas/research-construction/lattice-route-action
// Plane: RuntimePlane::Controller
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LatticeRouteAction {
    Wake,
    Retrieve,
    Continue,
    Pause,
    Resume,
    Verify,
    Abstain,
}

impl LatticeRouteAction {
    pub fn wire_tag(self) -> &'static str {
        match self {
            Self::Wake => "wake",
            Self::Retrieve => "retrieve",
            Self::Continue => "continue",
            Self::Pause => "pause",
            Self::Resume => "resume",
            Self::Verify => "verify",
            Self::Abstain => "abstain",
        }
    }
}

// UAS: uas/research-construction/lattice-controller-baseline
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LatticeControllerBaseline {
    pub name: String,
    pub quality_bps: u16,
    pub evidence_validity_bps: u16,
    pub verifier_bps: u16,
    pub route_success_bps: u16,
    pub abstention_accuracy_bps: u16,
    pub active_executed_bytes: u64,
    pub cold_stall_ms: u64,
    pub hidden_live_authority: bool,
}

impl LatticeControllerBaseline {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        name: impl Into<String>,
        quality_bps: u16,
        evidence_validity_bps: u16,
        verifier_bps: u16,
        route_success_bps: u16,
        abstention_accuracy_bps: u16,
        active_executed_bytes: u64,
        cold_stall_ms: u64,
        hidden_live_authority: bool,
    ) -> Result<Self, LatticeStateControllerError> {
        let name = name.into();
        validate_nonempty("baseline_name", &name)?;
        validate_score("quality_bps", quality_bps)?;
        validate_score("evidence_validity_bps", evidence_validity_bps)?;
        validate_score("verifier_bps", verifier_bps)?;
        validate_score("route_success_bps", route_success_bps)?;
        validate_score("abstention_accuracy_bps", abstention_accuracy_bps)?;
        Ok(Self {
            name,
            quality_bps,
            evidence_validity_bps,
            verifier_bps,
            route_success_bps,
            abstention_accuracy_bps,
            active_executed_bytes,
            cold_stall_ms,
            hidden_live_authority,
        })
    }

    pub fn score_bps(&self) -> u16 {
        ((u32::from(self.quality_bps)
            + u32::from(self.evidence_validity_bps)
            + u32::from(self.verifier_bps)
            + u32::from(self.route_success_bps)
            + u32::from(self.abstention_accuracy_bps))
            / 5) as u16
    }
}

// UAS: uas/research-construction/lattice-state-controller
// Plane: RuntimePlane::Controller
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LatticeStateController {
    pub controller_address: UasAddress,
    pub mission_id: String,
    pub source_card_ids: Vec<String>,
    pub task_signature: String,
    pub abstract_route_state: String,
    pub candidate_actions: Vec<LatticeRouteAction>,
    pub selected_action: LatticeRouteAction,
    pub static_policy_action: LatticeRouteAction,
    pub monotone_progress_bps: u16,
    pub uncertainty_bps: u16,
    pub conflict_signal_bps: u16,
    pub abstain_threshold_bps: u16,
    pub abstain_condition: String,
    pub verifier_feedback_bps: u16,
    pub quality_bps: u16,
    pub evidence_validity_bps: u16,
    pub verifier_bps: u16,
    pub route_success_bps: u16,
    pub abstention_accuracy_bps: u16,
    pub active_executed_bytes: u64,
    pub cold_stall_ms: u64,
    pub fallback_route: String,
    pub rollback_ref: String,
    pub answer_packet_ref: String,
    pub live_route_authority: bool,
    pub hidden_chain_exposed: bool,
    pub baselines: Vec<LatticeControllerBaseline>,
}

impl LatticeStateController {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        mission_id: impl Into<String>,
        source_card_ids: Vec<String>,
        task_signature: impl Into<String>,
        abstract_route_state: impl Into<String>,
        candidate_actions: Vec<LatticeRouteAction>,
        selected_action: LatticeRouteAction,
        static_policy_action: LatticeRouteAction,
        monotone_progress_bps: u16,
        uncertainty_bps: u16,
        conflict_signal_bps: u16,
        abstain_threshold_bps: u16,
        abstain_condition: impl Into<String>,
        verifier_feedback_bps: u16,
        quality_bps: u16,
        evidence_validity_bps: u16,
        verifier_bps: u16,
        route_success_bps: u16,
        abstention_accuracy_bps: u16,
        active_executed_bytes: u64,
        cold_stall_ms: u64,
        fallback_route: impl Into<String>,
        rollback_ref: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        live_route_authority: bool,
        hidden_chain_exposed: bool,
        baselines: Vec<LatticeControllerBaseline>,
        created_at_ms: u64,
    ) -> Result<Self, LatticeStateControllerError> {
        let mission_id = mission_id.into();
        let task_signature = task_signature.into();
        let abstract_route_state = abstract_route_state.into();
        let abstain_condition = abstain_condition.into();
        let fallback_route = fallback_route.into();
        let rollback_ref = rollback_ref.into();
        let answer_packet_ref = answer_packet_ref.into();
        validate_nonempty("mission_id", &mission_id)?;
        validate_nonempty("task_signature", &task_signature)?;
        validate_nonempty("abstract_route_state", &abstract_route_state)?;
        validate_nonempty("abstain_condition", &abstain_condition)?;
        validate_nonempty("fallback_route", &fallback_route)?;
        validate_nonempty("rollback_ref", &rollback_ref)?;
        validate_nonempty("answer_packet_ref", &answer_packet_ref)?;
        if !fallback_route.starts_with(FALLBACK_PREFIX) {
            return Err(LatticeStateControllerError::InvalidFallbackRoute);
        }
        if !rollback_ref.starts_with(ROLLBACK_PREFIX) {
            return Err(LatticeStateControllerError::MissingRollback);
        }
        if !answer_packet_ref.starts_with(ANSWER_PACKET_PREFIX) {
            return Err(LatticeStateControllerError::MissingAnswerPacketRef);
        }
        if live_route_authority {
            return Err(LatticeStateControllerError::HiddenLiveRouteAuthority);
        }
        if hidden_chain_exposed {
            return Err(LatticeStateControllerError::HiddenChainExposed);
        }
        validate_score("monotone_progress_bps", monotone_progress_bps)?;
        validate_score("uncertainty_bps", uncertainty_bps)?;
        validate_score("conflict_signal_bps", conflict_signal_bps)?;
        validate_score("abstain_threshold_bps", abstain_threshold_bps)?;
        validate_score("verifier_feedback_bps", verifier_feedback_bps)?;
        validate_score("quality_bps", quality_bps)?;
        validate_score("evidence_validity_bps", evidence_validity_bps)?;
        validate_score("verifier_bps", verifier_bps)?;
        validate_score("route_success_bps", route_success_bps)?;
        validate_score("abstention_accuracy_bps", abstention_accuracy_bps)?;
        if abstain_threshold_bps == 0 {
            return Err(LatticeStateControllerError::InvalidAbstainThreshold);
        }
        let source_card_ids = canonicalize_strings("source_card_ids", source_card_ids)?;
        if source_card_ids.is_empty() {
            return Err(LatticeStateControllerError::MissingSourceCards);
        }
        let candidate_actions = canonicalize_actions(candidate_actions)?;
        validate_action_coverage(&candidate_actions, selected_action, static_policy_action)?;
        validate_abstention_rule(
            selected_action,
            uncertainty_bps,
            conflict_signal_bps,
            abstain_threshold_bps,
        )?;
        let baselines = canonicalize_baselines(baselines)?;
        let controller_address = controller_address(
            &mission_id,
            &source_card_ids,
            &task_signature,
            &abstract_route_state,
            &candidate_actions,
            selected_action,
            static_policy_action,
            monotone_progress_bps,
            uncertainty_bps,
            conflict_signal_bps,
            abstain_threshold_bps,
            &abstain_condition,
            verifier_feedback_bps,
            quality_bps,
            evidence_validity_bps,
            verifier_bps,
            route_success_bps,
            abstention_accuracy_bps,
            active_executed_bytes,
            cold_stall_ms,
            &fallback_route,
            &rollback_ref,
            &answer_packet_ref,
            &baselines,
            created_at_ms,
        );
        let controller = Self {
            controller_address,
            mission_id,
            source_card_ids,
            task_signature,
            abstract_route_state,
            candidate_actions,
            selected_action,
            static_policy_action,
            monotone_progress_bps,
            uncertainty_bps,
            conflict_signal_bps,
            abstain_threshold_bps,
            abstain_condition,
            verifier_feedback_bps,
            quality_bps,
            evidence_validity_bps,
            verifier_bps,
            route_success_bps,
            abstention_accuracy_bps,
            active_executed_bytes,
            cold_stall_ms,
            fallback_route,
            rollback_ref,
            answer_packet_ref,
            live_route_authority,
            hidden_chain_exposed,
            baselines,
        };
        if !controller.beats_all_baselines() {
            return Err(LatticeStateControllerError::BaselineNotBeaten);
        }
        Ok(controller)
    }

    pub fn score_bps(&self) -> u16 {
        ((u32::from(self.quality_bps)
            + u32::from(self.evidence_validity_bps)
            + u32::from(self.verifier_bps)
            + u32::from(self.route_success_bps)
            + u32::from(self.abstention_accuracy_bps))
            / 5) as u16
    }

    pub fn baseline(&self, name: &str) -> Option<&LatticeControllerBaseline> {
        self.baselines.iter().find(|baseline| baseline.name == name)
    }

    pub fn beats_all_baselines(&self) -> bool {
        self.baselines.iter().all(|baseline| {
            self.score_bps() > baseline.score_bps()
                && self.quality_bps > baseline.quality_bps
                && self.evidence_validity_bps > baseline.evidence_validity_bps
                && self.verifier_bps > baseline.verifier_bps
                && self.route_success_bps > baseline.route_success_bps
                && self.abstention_accuracy_bps > baseline.abstention_accuracy_bps
                && self.active_executed_bytes < baseline.active_executed_bytes
                && self.cold_stall_ms < baseline.cold_stall_ms
                && !baseline.hidden_live_authority
        })
    }
}

// UAS: uas/research-construction/lattice-state-controller-error
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum LatticeStateControllerError {
    MissingMissionId,
    MissingSourceCards,
    MissingTaskSignature,
    MissingAbstractRouteState,
    MissingCandidateActions,
    MissingAbstainCondition,
    MissingFallbackRoute,
    InvalidFallbackRoute,
    MissingRollback,
    MissingAnswerPacketRef,
    MissingBaselineSet,
    InvalidBaselineSet,
    DuplicateBaseline { name: String },
    DuplicateSourceCard { source_card_id: String },
    DuplicateAction { action: LatticeRouteAction },
    MissingSelectedAction,
    MissingStaticPolicyAction,
    MissingRequiredAction { action: LatticeRouteAction },
    InvalidAbstainThreshold,
    HighUncertaintyMustAbstain,
    HiddenLiveRouteAuthority,
    HiddenChainExposed,
    BaselineNotBeaten,
    ScoreOutOfRange { field: &'static str },
    FieldHasSurroundingWhitespace { field: &'static str },
    FieldContainsControlCharacter { field: &'static str },
}

impl std::fmt::Display for LatticeStateControllerError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::MissingMissionId => write!(f, "missing mission id"),
            Self::MissingSourceCards => write!(f, "missing source cards"),
            Self::MissingTaskSignature => write!(f, "missing task signature"),
            Self::MissingAbstractRouteState => write!(f, "missing abstract route state"),
            Self::MissingCandidateActions => write!(f, "missing candidate actions"),
            Self::MissingAbstainCondition => write!(f, "missing abstain condition"),
            Self::MissingFallbackRoute => write!(f, "missing fallback route"),
            Self::InvalidFallbackRoute => write!(f, "fallback route must start with fallback:"),
            Self::MissingRollback => write!(f, "missing rollback"),
            Self::MissingAnswerPacketRef => write!(f, "missing AnswerPacket ref"),
            Self::MissingBaselineSet => write!(f, "missing baseline set"),
            Self::InvalidBaselineSet => write!(
                f,
                "baseline set must include static_policy, random_policy, and always_retrieve"
            ),
            Self::DuplicateBaseline { name } => write!(f, "duplicate baseline {name}"),
            Self::DuplicateSourceCard { source_card_id } => {
                write!(f, "duplicate source card {source_card_id}")
            }
            Self::DuplicateAction { action } => write!(f, "duplicate action {:?}", action),
            Self::MissingSelectedAction => write!(f, "selected action missing from candidates"),
            Self::MissingStaticPolicyAction => {
                write!(f, "static policy action missing from candidates")
            }
            Self::MissingRequiredAction { action } => {
                write!(f, "required action {:?} missing from candidates", action)
            }
            Self::InvalidAbstainThreshold => write!(f, "invalid abstain threshold"),
            Self::HighUncertaintyMustAbstain => {
                write!(f, "high uncertainty or conflict must select abstain")
            }
            Self::HiddenLiveRouteAuthority => {
                write!(f, "controller cannot claim hidden live route authority")
            }
            Self::HiddenChainExposed => write!(f, "controller cannot expose hidden chain"),
            Self::BaselineNotBeaten => write!(f, "controller did not beat all baselines"),
            Self::ScoreOutOfRange { field } => write!(f, "{field} score out of range"),
            Self::FieldHasSurroundingWhitespace { field } => {
                write!(f, "{field} has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter { field } => {
                write!(f, "{field} contains control character")
            }
        }
    }
}

impl std::error::Error for LatticeStateControllerError {}

fn canonicalize_strings(
    field: &'static str,
    values: Vec<String>,
) -> Result<Vec<String>, LatticeStateControllerError> {
    let mut seen = BTreeSet::new();
    let mut canonical = Vec::with_capacity(values.len());
    for value in values {
        validate_nonempty(field, &value)?;
        if !seen.insert(value.clone()) {
            return Err(match field {
                "source_card_ids" => LatticeStateControllerError::DuplicateSourceCard {
                    source_card_id: value,
                },
                _ => LatticeStateControllerError::FieldContainsControlCharacter { field },
            });
        }
        canonical.push(value);
    }
    canonical.sort();
    Ok(canonical)
}

fn canonicalize_actions(
    actions: Vec<LatticeRouteAction>,
) -> Result<Vec<LatticeRouteAction>, LatticeStateControllerError> {
    if actions.is_empty() {
        return Err(LatticeStateControllerError::MissingCandidateActions);
    }
    let mut seen = BTreeSet::new();
    for action in actions {
        if !seen.insert(action) {
            return Err(LatticeStateControllerError::DuplicateAction { action });
        }
    }
    Ok(seen.into_iter().collect())
}

fn validate_action_coverage(
    actions: &[LatticeRouteAction],
    selected_action: LatticeRouteAction,
    static_policy_action: LatticeRouteAction,
) -> Result<(), LatticeStateControllerError> {
    for action in [
        LatticeRouteAction::Wake,
        LatticeRouteAction::Retrieve,
        LatticeRouteAction::Continue,
        LatticeRouteAction::Verify,
        LatticeRouteAction::Abstain,
    ] {
        if !actions.contains(&action) {
            return Err(LatticeStateControllerError::MissingRequiredAction { action });
        }
    }
    if !actions.contains(&selected_action) {
        return Err(LatticeStateControllerError::MissingSelectedAction);
    }
    if !actions.contains(&static_policy_action) {
        return Err(LatticeStateControllerError::MissingStaticPolicyAction);
    }
    Ok(())
}

fn validate_abstention_rule(
    selected_action: LatticeRouteAction,
    uncertainty_bps: u16,
    conflict_signal_bps: u16,
    abstain_threshold_bps: u16,
) -> Result<(), LatticeStateControllerError> {
    if (uncertainty_bps >= abstain_threshold_bps || conflict_signal_bps >= abstain_threshold_bps)
        && selected_action != LatticeRouteAction::Abstain
    {
        return Err(LatticeStateControllerError::HighUncertaintyMustAbstain);
    }
    Ok(())
}

fn canonicalize_baselines(
    mut baselines: Vec<LatticeControllerBaseline>,
) -> Result<Vec<LatticeControllerBaseline>, LatticeStateControllerError> {
    if baselines.is_empty() {
        return Err(LatticeStateControllerError::MissingBaselineSet);
    }
    let mut names = BTreeSet::new();
    for baseline in &baselines {
        if !names.insert(baseline.name.clone()) {
            return Err(LatticeStateControllerError::DuplicateBaseline {
                name: baseline.name.clone(),
            });
        }
    }
    if !BASELINE_NAMES.iter().all(|name| names.contains(*name)) {
        return Err(LatticeStateControllerError::InvalidBaselineSet);
    }
    baselines.sort_by(|a, b| a.name.cmp(&b.name));
    Ok(baselines)
}

#[allow(clippy::too_many_arguments)]
fn controller_address(
    mission_id: &str,
    source_card_ids: &[String],
    task_signature: &str,
    abstract_route_state: &str,
    candidate_actions: &[LatticeRouteAction],
    selected_action: LatticeRouteAction,
    static_policy_action: LatticeRouteAction,
    monotone_progress_bps: u16,
    uncertainty_bps: u16,
    conflict_signal_bps: u16,
    abstain_threshold_bps: u16,
    abstain_condition: &str,
    verifier_feedback_bps: u16,
    quality_bps: u16,
    evidence_validity_bps: u16,
    verifier_bps: u16,
    route_success_bps: u16,
    abstention_accuracy_bps: u16,
    active_executed_bytes: u64,
    cold_stall_ms: u64,
    fallback_route: &str,
    rollback_ref: &str,
    answer_packet_ref: &str,
    baselines: &[LatticeControllerBaseline],
    created_at_ms: u64,
) -> UasAddress {
    let mut preimage = String::new();
    preimage.push_str("lattice_state_controller_v1\n");
    preimage.push_str(mission_id);
    preimage.push('\n');
    preimage.push_str(task_signature);
    preimage.push('\n');
    preimage.push_str(abstract_route_state);
    preimage.push('\n');
    for source_card_id in source_card_ids {
        preimage.push_str(source_card_id);
        preimage.push('\n');
    }
    for action in candidate_actions {
        preimage.push_str(action.wire_tag());
        preimage.push('\n');
    }
    preimage.push_str(selected_action.wire_tag());
    preimage.push('\n');
    preimage.push_str(static_policy_action.wire_tag());
    preimage.push('\n');
    preimage.push_str(&format!(
        "{monotone_progress_bps}|{uncertainty_bps}|{conflict_signal_bps}|{abstain_threshold_bps}|{verifier_feedback_bps}|{quality_bps}|{evidence_validity_bps}|{verifier_bps}|{route_success_bps}|{abstention_accuracy_bps}|{active_executed_bytes}|{cold_stall_ms}\n"
    ));
    preimage.push_str(abstain_condition);
    preimage.push('\n');
    preimage.push_str(fallback_route);
    preimage.push('\n');
    preimage.push_str(rollback_ref);
    preimage.push('\n');
    preimage.push_str(answer_packet_ref);
    preimage.push('\n');
    for baseline in baselines {
        preimage.push_str(&format!(
            "{}|{}|{}|{}|{}|{}|{}|{}|{}\n",
            baseline.name,
            baseline.quality_bps,
            baseline.evidence_validity_bps,
            baseline.verifier_bps,
            baseline.route_success_bps,
            baseline.abstention_accuracy_bps,
            baseline.active_executed_bytes,
            baseline.cold_stall_ms,
            baseline.hidden_live_authority
        ));
    }
    UasAddress::new(
        UasKind::Other(CONTROLLER_UAS_KIND.to_string()),
        preimage.as_bytes(),
        created_at_ms,
    )
}

fn validate_nonempty(field: &'static str, value: &str) -> Result<(), LatticeStateControllerError> {
    if value.is_empty() {
        return match field {
            "mission_id" => Err(LatticeStateControllerError::MissingMissionId),
            "task_signature" => Err(LatticeStateControllerError::MissingTaskSignature),
            "abstract_route_state" => Err(LatticeStateControllerError::MissingAbstractRouteState),
            "abstain_condition" => Err(LatticeStateControllerError::MissingAbstainCondition),
            "fallback_route" => Err(LatticeStateControllerError::MissingFallbackRoute),
            "rollback_ref" => Err(LatticeStateControllerError::MissingRollback),
            "answer_packet_ref" => Err(LatticeStateControllerError::MissingAnswerPacketRef),
            _ => Err(LatticeStateControllerError::FieldContainsControlCharacter { field }),
        };
    }
    if value.trim() != value {
        return Err(LatticeStateControllerError::FieldHasSurroundingWhitespace { field });
    }
    if value.chars().any(char::is_control) {
        return Err(LatticeStateControllerError::FieldContainsControlCharacter { field });
    }
    Ok(())
}

fn validate_score(field: &'static str, value: u16) -> Result<(), LatticeStateControllerError> {
    if value > 10_000 {
        Err(LatticeStateControllerError::ScoreOutOfRange { field })
    } else {
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_400_000_000;

    fn actions() -> Vec<LatticeRouteAction> {
        vec![
            LatticeRouteAction::Wake,
            LatticeRouteAction::Retrieve,
            LatticeRouteAction::Continue,
            LatticeRouteAction::Verify,
            LatticeRouteAction::Abstain,
        ]
    }

    fn baselines() -> Vec<LatticeControllerBaseline> {
        vec![
            LatticeControllerBaseline::new(
                "static_policy",
                8100,
                8000,
                7900,
                7600,
                6500,
                600_000,
                80,
                false,
            )
            .unwrap(),
            LatticeControllerBaseline::new(
                "random_policy",
                7000,
                6900,
                6700,
                6100,
                5000,
                700_000,
                100,
                false,
            )
            .unwrap(),
            LatticeControllerBaseline::new(
                "always_retrieve",
                7700,
                7600,
                7200,
                6800,
                5200,
                900_000,
                120,
                false,
            )
            .unwrap(),
        ]
    }

    fn controller() -> LatticeStateController {
        LatticeStateController::new(
            "mission:adversarial-note-controller",
            vec![
                "source:lattice-deduction-transformers".to_string(),
                "source:constructive-residency".to_string(),
            ],
            "task:verify-cold-assembly-route",
            "state:cold-plan-ready-low-conflict",
            actions(),
            LatticeRouteAction::Verify,
            LatticeRouteAction::Retrieve,
            8_900,
            1_800,
            1_200,
            7_000,
            "abstain when uncertainty or conflict crosses threshold",
            8_950,
            8_800,
            8_650,
            8_600,
            8_850,
            8_700,
            256_000,
            25,
            "fallback:static-policy-abstain",
            "rollback:restore-static-policy",
            "answer_packet:lattice-controller-fixture",
            false,
            false,
            baselines(),
            CREATED_AT_MS,
        )
        .unwrap()
    }

    #[test]
    fn lattice_state_controller_beats_baselines() {
        let controller = controller();
        assert!(controller.beats_all_baselines());
        assert_eq!(controller.selected_action, LatticeRouteAction::Verify);
        assert_eq!(
            controller.static_policy_action,
            LatticeRouteAction::Retrieve
        );
    }

    #[test]
    fn lattice_state_controller_address_is_deterministic() {
        assert_eq!(
            controller().controller_address,
            controller().controller_address
        );
    }

    #[test]
    fn lattice_state_controller_requires_abstain_on_high_uncertainty() {
        let error = LatticeStateController::new(
            "mission:bad",
            vec!["source:a".to_string()],
            "task:bad",
            "state:high-conflict",
            actions(),
            LatticeRouteAction::Verify,
            LatticeRouteAction::Retrieve,
            4_000,
            8_500,
            7_500,
            7_000,
            "abstain high uncertainty",
            5_000,
            8_800,
            8_650,
            8_600,
            8_850,
            8_700,
            256_000,
            25,
            "fallback:static",
            "rollback:static",
            "answer_packet:bad",
            false,
            false,
            baselines(),
            CREATED_AT_MS,
        )
        .expect_err("high uncertainty must abstain");
        assert!(matches!(
            error,
            LatticeStateControllerError::HighUncertaintyMustAbstain
        ));
    }

    #[test]
    fn lattice_state_controller_rejects_hidden_authority() {
        let error = LatticeStateController::new(
            "mission:bad",
            vec!["source:a".to_string()],
            "task:bad",
            "state:bad",
            actions(),
            LatticeRouteAction::Verify,
            LatticeRouteAction::Retrieve,
            8_900,
            1_800,
            1_200,
            7_000,
            "abstain high uncertainty",
            8_950,
            8_800,
            8_650,
            8_600,
            8_850,
            8_700,
            256_000,
            25,
            "fallback:static",
            "rollback:static",
            "answer_packet:bad",
            true,
            false,
            baselines(),
            CREATED_AT_MS,
        )
        .expect_err("hidden live authority should fail");
        assert!(matches!(
            error,
            LatticeStateControllerError::HiddenLiveRouteAuthority
        ));
    }

    #[test]
    fn lattice_state_controller_rejects_unbeaten_static_baseline() {
        let mut baselines = baselines();
        baselines.retain(|baseline| baseline.name != "static_policy");
        baselines.push(
            LatticeControllerBaseline::new(
                "static_policy",
                9_900,
                9_900,
                9_900,
                9_900,
                9_900,
                100_000,
                1,
                false,
            )
            .unwrap(),
        );
        let error = LatticeStateController::new(
            "mission:bad",
            vec!["source:a".to_string()],
            "task:bad",
            "state:bad",
            actions(),
            LatticeRouteAction::Verify,
            LatticeRouteAction::Retrieve,
            8_900,
            1_800,
            1_200,
            7_000,
            "abstain high uncertainty",
            8_950,
            8_800,
            8_650,
            8_600,
            8_850,
            8_700,
            256_000,
            25,
            "fallback:static",
            "rollback:static",
            "answer_packet:bad",
            false,
            false,
            baselines,
            CREATED_AT_MS,
        )
        .expect_err("unbeaten static baseline should fail");
        assert!(matches!(
            error,
            LatticeStateControllerError::BaselineNotBeaten
        ));
    }
}
