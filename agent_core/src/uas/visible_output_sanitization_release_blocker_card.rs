use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

pub const VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_ID: &str =
    "F-VisibleOutputSanitization-ReleaseBlockerCard";
pub const VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_CURSOR: &str =
    "visible_output_sanitization_release_blocker_card";
pub const VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR: &str =
    "graph_filter_visibility_release_blocker_card";
pub const VISIBLE_OUTPUT_SANITIZATION_UPSTREAM_REF: &str =
    "artifact:falsifiers/agent_route_policy_large_model_no_hidden_authority/result.json#F-AgentRoutePolicy-LargeModelNoHiddenAuthority";
pub const VISIBLE_OUTPUT_SANITIZATION_FAMILY_SOURCE_REF: &str =
    "artifact:falsifiers/release_audit_failure_family_source_card/result.json#visible_output_sanitization";

const REQUIRED_SOURCE_REFS: [&str; 9] = [
    "Epistemos/Engine/Extensions.swift",
    "Epistemos/Engine/TriageService.swift",
    "Epistemos/Engine/ThinkTagStreamRouter.swift",
    "Epistemos/State/ChatState.swift",
    "Epistemos/State/AgentChatState.swift",
    "Epistemos/State/NoteChatState.swift",
    "Epistemos/Views/Chat/ChatView.swift",
    "Epistemos/Views/MiniChat/MiniChatView.swift",
    "EpistemosTests/UserFacingModelOutputTests.swift",
];

const REQUIRED_INVARIANTS: [&str; 12] = [
    "function_call_envelopes_never_surface_without_final_answer",
    "action_envelopes_never_surface_without_final_answer",
    "scratch_pad_and_tool_call_blocks_are_stripped",
    "incomplete_control_envelopes_suppress_prelude_only_text",
    "explicit_final_answer_survives_after_control_envelopes",
    "dangling_answer_markers_stay_empty",
    "structured_tool_json_fragments_stay_hidden",
    "thinking_trace_and_reasoning_preludes_stay_out_of_visible_stream",
    "visible_streaming_and_final_paths_share_sanitizer",
    "answer_packet_caveat_required_for_sanitized_output",
    "no_hidden_chain_of_thought_or_tool_payload",
    "release_audit_family_remains_red_until_focused_tests_pass",
];

// UAS: uas:visible-output-sanitization-release-blocker-card:organ
// Plane: Verification.
// Residency: metadata-only output/privacy classification.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VisibleOutputSanitizationOrgan {
    AnswerPacketSanitization,
    UserFacingModelOutput,
    TriageService,
    ChatSurface,
    RunEventLog,
}

// UAS: uas:visible-output-sanitization-release-blocker-card:status
// Plane: Verification.
// Residency: retained release blocker classification only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VisibleOutputSanitizationStatus {
    RedReleaseBlocker,
}

// UAS: uas:visible-output-sanitization-release-blocker-card:card
// Plane: Verification.
// Residency: metadata-only source-card blocker; no model/runtime bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct VisibleOutputSanitizationReleaseBlockerCard {
    pub family_id: String,
    pub issue_count: u64,
    pub organ: VisibleOutputSanitizationOrgan,
    pub status: VisibleOutputSanitizationStatus,
    pub source_refs: Vec<String>,
    pub focused_commands: Vec<String>,
    pub required_invariants: Vec<String>,
    pub mas_status: String,
    pub pro_status: String,
    pub raw_function_call_visible: bool,
    pub raw_action_visible: bool,
    pub raw_tool_json_visible: bool,
    pub hidden_reasoning_visible: bool,
    pub control_prelude_visible_without_answer: bool,
    pub explicit_final_answer_dropped: bool,
    pub answer_packet_caveat_missing: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub product_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub model_runtime_bytes_loaded: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
}

impl VisibleOutputSanitizationReleaseBlockerCard {
    pub fn from_family(
        family_id: &str,
        issue_count: u64,
    ) -> Result<Self, VisibleOutputSanitizationError> {
        validate_token("family_id", family_id)?;
        if family_id != "visible_output_sanitization" {
            return Err(VisibleOutputSanitizationError::WrongFamily(
                family_id.to_string(),
            ));
        }
        if issue_count == 0 {
            return Err(VisibleOutputSanitizationError::ZeroIssueCount);
        }
        Ok(Self {
            family_id: family_id.to_string(),
            issue_count,
            organ: VisibleOutputSanitizationOrgan::AnswerPacketSanitization,
            status: VisibleOutputSanitizationStatus::RedReleaseBlocker,
            source_refs: REQUIRED_SOURCE_REFS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            focused_commands: vec![
                "xcodebuild test -only-testing:EpistemosTests/UserFacingModelOutputTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/AssistantInlineTranscriptTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/ChatPresentationTests".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/MiniChatViewAuditTests".to_string(),
            ],
            required_invariants: REQUIRED_INVARIANTS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            mas_status: "red_release_blocker".to_string(),
            pro_status: "gated_release_blocker".to_string(),
            raw_function_call_visible: false,
            raw_action_visible: false,
            raw_tool_json_visible: false,
            hidden_reasoning_visible: false,
            control_prelude_visible_without_answer: false,
            explicit_final_answer_dropped: false,
            answer_packet_caveat_missing: false,
            hidden_route_authority: false,
            hidden_cloud_fallback: false,
            l2_green_claimed: false,
            l3_green_claimed: false,
            product_green_claimed: false,
            live_dense_70b_claimed: false,
            model_runtime_bytes_loaded: 0,
            rollback_ref: "rollback:visible_output_sanitization_release_blocker".to_string(),
            run_event_log_ref: "run_event_log:visible_output_sanitization_release_blocker"
                .to_string(),
            answer_packet_ref: "answer_packet:visible_output_sanitization_release_blocker"
                .to_string(),
        })
    }

    pub fn validate(&self) -> Result<(), VisibleOutputSanitizationError> {
        validate_token("family_id", &self.family_id)?;
        if self.family_id != "visible_output_sanitization"
            || self.issue_count == 0
            || self.organ != VisibleOutputSanitizationOrgan::AnswerPacketSanitization
            || self.status != VisibleOutputSanitizationStatus::RedReleaseBlocker
        {
            return Err(VisibleOutputSanitizationError::CardHeaderBroken);
        }
        validate_unique_exact_set("source_refs", &self.source_refs, &REQUIRED_SOURCE_REFS)?;
        validate_unique_exact_set(
            "required_invariants",
            &self.required_invariants,
            &REQUIRED_INVARIANTS,
        )?;
        validate_list("focused_commands", &self.focused_commands, 3, 8)?;
        for command in &self.focused_commands {
            if !command.starts_with("xcodebuild test -only-testing:EpistemosTests/") {
                return Err(VisibleOutputSanitizationError::BadFocusedCommand);
            }
        }
        for value in [
            &self.mas_status,
            &self.pro_status,
            &self.rollback_ref,
            &self.run_event_log_ref,
            &self.answer_packet_ref,
        ] {
            validate_token("proof_ref", value)?;
        }
        if self.raw_function_call_visible
            || self.raw_action_visible
            || self.raw_tool_json_visible
            || self.hidden_reasoning_visible
            || self.control_prelude_visible_without_answer
            || self.explicit_final_answer_dropped
            || self.answer_packet_caveat_missing
            || self.hidden_route_authority
            || self.hidden_cloud_fallback
            || self.l2_green_claimed
            || self.l3_green_claimed
            || self.product_green_claimed
            || self.live_dense_70b_claimed
            || self.model_runtime_bytes_loaded != 0
        {
            return Err(VisibleOutputSanitizationError::PromotionBoundaryBroken);
        }
        Ok(())
    }
}

// UAS: uas:visible-output-sanitization-release-blocker-card:metrics
// Plane: Verification.
// Residency: aggregate release-blocker metrics only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct VisibleOutputSanitizationMetrics {
    pub issue_count: u64,
    pub source_ref_count: usize,
    pub focused_command_count: usize,
    pub invariant_count: usize,
    pub model_runtime_bytes_loaded: u64,
}

// UAS: uas:visible-output-sanitization-release-blocker-card:witness
// Plane: Verification.
// Residency: metadata-only visible-output witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct VisibleOutputSanitizationReleaseBlockerWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_ref: String,
    pub family_source_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_next_cursor: String,
    pub card: VisibleOutputSanitizationReleaseBlockerCard,
    pub metrics: VisibleOutputSanitizationMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl VisibleOutputSanitizationReleaseBlockerWitness {
    pub fn new(
        upstream_ref: &str,
        family_source_ref: &str,
        upstream_overall_pass: bool,
        upstream_next_cursor: &str,
        family_id: &str,
        issue_count: u64,
    ) -> Result<Self, VisibleOutputSanitizationError> {
        validate_upstream_ref(upstream_ref)?;
        validate_family_source_ref(family_source_ref)?;
        validate_token("upstream_next_cursor", upstream_next_cursor)?;
        if !upstream_overall_pass {
            return Err(VisibleOutputSanitizationError::UpstreamNotPassed);
        }
        if upstream_next_cursor != VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_CURSOR {
            return Err(VisibleOutputSanitizationError::WrongUpstreamCursor(
                upstream_next_cursor.to_string(),
            ));
        }
        let card =
            VisibleOutputSanitizationReleaseBlockerCard::from_family(family_id, issue_count)?;
        card.validate()?;
        let metrics = VisibleOutputSanitizationMetrics {
            issue_count: card.issue_count,
            source_ref_count: card.source_refs.len(),
            focused_command_count: card.focused_commands.len(),
            invariant_count: card.required_invariants.len(),
            model_runtime_bytes_loaded: card.model_runtime_bytes_loaded,
        };
        let address = visible_output_address(
            upstream_ref,
            family_source_ref,
            upstream_overall_pass,
            upstream_next_cursor,
            &card,
            &metrics,
        );
        Ok(Self {
            falsifier_id: VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_ID.to_string(),
            cursor: VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_CURSOR.to_string(),
            next_cursor: VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR.to_string(),
            upstream_ref: upstream_ref.to_string(),
            family_source_ref: family_source_ref.to_string(),
            upstream_overall_pass,
            upstream_next_cursor: upstream_next_cursor.to_string(),
            card,
            metrics,
            address,
            metadata_only: true,
            no_product_promotion: true,
        })
    }

    pub fn validate(&self) -> Result<(), VisibleOutputSanitizationError> {
        if self.falsifier_id != VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_ID
            || self.cursor != VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_CURSOR
            || self.next_cursor != VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(VisibleOutputSanitizationError::WitnessHeaderBroken);
        }
        let rebuilt = Self::new(
            &self.upstream_ref,
            &self.family_source_ref,
            self.upstream_overall_pass,
            &self.upstream_next_cursor,
            &self.card.family_id,
            self.card.issue_count,
        )?;
        if rebuilt.address != self.address || rebuilt.metrics != self.metrics {
            return Err(VisibleOutputSanitizationError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_visible_output_sanitization_source_refs() -> &'static [&'static str] {
    &REQUIRED_SOURCE_REFS
}

pub fn required_visible_output_sanitization_invariants() -> &'static [&'static str] {
    &REQUIRED_INVARIANTS
}

fn visible_output_address(
    upstream_ref: &str,
    family_source_ref: &str,
    upstream_overall_pass: bool,
    upstream_next_cursor: &str,
    card: &VisibleOutputSanitizationReleaseBlockerCard,
    metrics: &VisibleOutputSanitizationMetrics,
) -> String {
    let mut preimage = String::new();
    preimage.push_str(VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_ID);
    preimage.push_str(VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_CURSOR);
    preimage.push_str(VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR);
    preimage.push_str(upstream_ref);
    preimage.push_str(family_source_ref);
    preimage.push_str(&upstream_overall_pass.to_string());
    preimage.push_str(upstream_next_cursor);
    preimage.push_str(&card.family_id);
    preimage.push_str(&card.issue_count.to_string());
    for source in &card.source_refs {
        preimage.push_str(source);
    }
    for invariant in &card.required_invariants {
        preimage.push_str(invariant);
    }
    preimage.push_str(&format!("{metrics:?}"));
    sha256_hex(preimage.as_bytes())
}

fn validate_unique_exact_set(
    field: &'static str,
    values: &[String],
    required: &[&'static str],
) -> Result<(), VisibleOutputSanitizationError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(VisibleOutputSanitizationError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    let actual = values.iter().map(String::as_str).collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected {
        return Err(VisibleOutputSanitizationError::MissingRequiredSet {
            field,
            actual: values.len(),
            expected: required.len(),
        });
    }
    Ok(())
}

fn validate_list(
    field: &'static str,
    values: &[String],
    min: usize,
    max: usize,
) -> Result<(), VisibleOutputSanitizationError> {
    if values.len() < min || values.len() > max {
        return Err(VisibleOutputSanitizationError::BadListLength {
            field,
            actual: values.len(),
        });
    }
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(VisibleOutputSanitizationError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    Ok(())
}

fn validate_upstream_ref(value: &str) -> Result<(), VisibleOutputSanitizationError> {
    validate_token("upstream_ref", value)?;
    if !value.starts_with("artifact:falsifiers/agent_route_policy_large_model_no_hidden_authority/")
        || !value.contains("/result.json#F-AgentRoutePolicy-LargeModelNoHiddenAuthority")
    {
        return Err(VisibleOutputSanitizationError::BadUpstreamRef);
    }
    Ok(())
}

fn validate_family_source_ref(value: &str) -> Result<(), VisibleOutputSanitizationError> {
    validate_token("family_source_ref", value)?;
    if !value.starts_with("artifact:falsifiers/release_audit_failure_family_source_card/")
        || !value.contains("/result.json#visible_output_sanitization")
    {
        return Err(VisibleOutputSanitizationError::BadFamilySourceRef);
    }
    Ok(())
}

fn validate_token(field: &'static str, value: &str) -> Result<(), VisibleOutputSanitizationError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(VisibleOutputSanitizationError::InvalidToken {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_text(field: &'static str, value: &str) -> Result<(), VisibleOutputSanitizationError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(VisibleOutputSanitizationError::InvalidText {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

// UAS: uas:visible-output-sanitization-release-blocker-card:error
// Plane: Verification.
// Residency: fail-closed metadata validation errors.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum VisibleOutputSanitizationError {
    InvalidToken {
        field: &'static str,
        value: String,
    },
    InvalidText {
        field: &'static str,
        value: String,
    },
    BadListLength {
        field: &'static str,
        actual: usize,
    },
    DuplicateValue {
        field: &'static str,
        value: String,
    },
    MissingRequiredSet {
        field: &'static str,
        actual: usize,
        expected: usize,
    },
    BadUpstreamRef,
    BadFamilySourceRef,
    UpstreamNotPassed,
    WrongUpstreamCursor(String),
    WrongFamily(String),
    ZeroIssueCount,
    CardHeaderBroken,
    BadFocusedCommand,
    PromotionBoundaryBroken,
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for VisibleOutputSanitizationError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidToken { field, value } => {
                write!(f, "invalid token in {field}: {value:?}")
            }
            Self::InvalidText { field, value } => write!(f, "invalid text in {field}: {value:?}"),
            Self::BadListLength { field, actual } => {
                write!(f, "bad list length for {field}: {actual}")
            }
            Self::DuplicateValue { field, value } => {
                write!(f, "duplicate value in {field}: {value}")
            }
            Self::MissingRequiredSet {
                field,
                actual,
                expected,
            } => write!(
                f,
                "missing required set values for {field}: actual={actual} expected={expected}"
            ),
            Self::BadUpstreamRef => write!(f, "bad upstream agent-route blocker ref"),
            Self::BadFamilySourceRef => write!(f, "bad visible-output family source ref"),
            Self::UpstreamNotPassed => write!(f, "upstream agent-route blocker did not pass"),
            Self::WrongUpstreamCursor(cursor) => write!(f, "wrong upstream cursor: {cursor}"),
            Self::WrongFamily(family) => write!(f, "wrong release-audit family: {family}"),
            Self::ZeroIssueCount => write!(f, "visible-output issue count is zero"),
            Self::CardHeaderBroken => write!(f, "visible-output card header is broken"),
            Self::BadFocusedCommand => write!(f, "focused command is outside EpistemosTests"),
            Self::PromotionBoundaryBroken => {
                write!(f, "visible-output promotion boundary is broken")
            }
            Self::WitnessHeaderBroken => write!(f, "visible-output witness header is broken"),
            Self::WitnessDigestMismatch => write!(f, "visible-output witness digest mismatch"),
        }
    }
}

impl std::error::Error for VisibleOutputSanitizationError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_visible_output_blocker() {
        let witness = VisibleOutputSanitizationReleaseBlockerWitness::new(
            VISIBLE_OUTPUT_SANITIZATION_UPSTREAM_REF,
            VISIBLE_OUTPUT_SANITIZATION_FAMILY_SOURCE_REF,
            true,
            VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_CURSOR,
            "visible_output_sanitization",
            5,
        )
        .expect("valid visible-output blocker");
        witness.validate().expect("witness validates");
        assert_eq!(witness.metrics.source_ref_count, REQUIRED_SOURCE_REFS.len());
        assert_eq!(witness.metrics.invariant_count, REQUIRED_INVARIANTS.len());
        assert_eq!(witness.card.model_runtime_bytes_loaded, 0);
    }

    #[test]
    fn rejects_wrong_upstream_or_family() {
        assert!(VisibleOutputSanitizationReleaseBlockerWitness::new(
            VISIBLE_OUTPUT_SANITIZATION_UPSTREAM_REF,
            VISIBLE_OUTPUT_SANITIZATION_FAMILY_SOURCE_REF,
            false,
            VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_CURSOR,
            "visible_output_sanitization",
            5,
        )
        .is_err());
        assert!(VisibleOutputSanitizationReleaseBlockerWitness::new(
            VISIBLE_OUTPUT_SANITIZATION_UPSTREAM_REF,
            VISIBLE_OUTPUT_SANITIZATION_FAMILY_SOURCE_REF,
            true,
            "other_cursor",
            "visible_output_sanitization",
            5,
        )
        .is_err());
        assert!(VisibleOutputSanitizationReleaseBlockerWitness::new(
            VISIBLE_OUTPUT_SANITIZATION_UPSTREAM_REF,
            VISIBLE_OUTPUT_SANITIZATION_FAMILY_SOURCE_REF,
            true,
            VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_CURSOR,
            "agent_route_policy",
            21,
        )
        .is_err());
    }

    #[test]
    fn rejects_output_leaks_and_promotion() {
        let witness = VisibleOutputSanitizationReleaseBlockerWitness::new(
            VISIBLE_OUTPUT_SANITIZATION_UPSTREAM_REF,
            VISIBLE_OUTPUT_SANITIZATION_FAMILY_SOURCE_REF,
            true,
            VISIBLE_OUTPUT_SANITIZATION_RELEASE_BLOCKER_CARD_CURSOR,
            "visible_output_sanitization",
            5,
        )
        .expect("valid visible-output blocker");
        let mut missing_source = witness.card.clone();
        missing_source
            .source_refs
            .retain(|value| value != "Epistemos/Engine/Extensions.swift");
        assert!(missing_source.validate().is_err());

        let mut leaked = witness.card.clone();
        leaked.raw_function_call_visible = true;
        assert!(leaked.validate().is_err());

        let mut promoted = witness.card.clone();
        promoted.product_green_claimed = true;
        assert!(promoted.validate().is_err());
    }
}
