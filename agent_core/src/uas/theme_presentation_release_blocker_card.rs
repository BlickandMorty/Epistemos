use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

pub const THEME_PRESENTATION_RELEASE_BLOCKER_CARD_ID: &str =
    "F-ThemePresentation-ReleaseBlockerCard";
pub const THEME_PRESENTATION_RELEASE_BLOCKER_CARD_CURSOR: &str =
    "theme_presentation_release_blocker_card";
pub const THEME_PRESENTATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR: &str =
    "distribution_project_integrity_release_blocker_card";
pub const THEME_PRESENTATION_UPSTREAM_REF: &str = "artifact:falsifiers/research_tool_catalog_no_hidden_authority/result.json#F-ResearchToolCatalog-NoHiddenAuthority";
pub const THEME_PRESENTATION_FAMILY_SOURCE_REF: &str =
    "artifact:falsifiers/release_audit_failure_family_source_card/result.json#theme_presentation";

const REQUIRED_SOURCE_REFS: [&str; 12] = [
    "Epistemos/Theme/EpistemosTheme.swift",
    "Epistemos/Theme/PlatinumTheme.swift",
    "Epistemos/Theme/GlassModifiers.swift",
    "Epistemos/Theme/NativeButtonStyles.swift",
    "Epistemos/Theme/ToolbarGlass.swift",
    "Epistemos/Theme/PhysicsModifiers.swift",
    "Epistemos/Views/Shell/PageShell.swift",
    "Epistemos/Views/MiniChat/MiniChatView.swift",
    "Epistemos/Views/Landing/LiquidGreeting.swift",
    "EpistemosTests/ThemePairTests.swift",
    "EpistemosTests/ChatPresentationTests.swift",
    "EpistemosTests/SettingsWindowPresentationTests.swift",
];

const REQUIRED_INVARIANTS: [&str; 12] = [
    "presentation_surfaces_are_visible_proof_only",
    "theme_tokens_do_not_select_runtime_routes",
    "answer_packet_caveats_remain_visible",
    "mas_pro_copy_stays_honest_on_visual_surfaces",
    "reduce_motion_and_window_occlusion_gate_animation",
    "theme_switches_do_not_recreate_model_runtime_handles",
    "settings_presentation_does_not_unlock_gated_capability",
    "chat_presentation_does_not_expose_hidden_tool_payloads",
    "contrast_and_readability_remain_release_blockers",
    "theme_source_guards_must_match_shipping_intent",
    "focused_tests_required_before_wrv_promotion",
    "release_audit_family_remains_red_until_focused_tests_pass",
];

// UAS: uas:theme-presentation-release-blocker-card:organ
// Plane: Verification.
// Residency: metadata-only presentation/source-card classification.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ThemePresentationOrgan {
    ThemePresentation,
    ThemeTokens,
    ChatPresentation,
    SettingsPresentation,
    LandingPresentation,
}

// UAS: uas:theme-presentation-release-blocker-card:status
// Plane: Verification.
// Residency: retained release blocker classification only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ThemePresentationStatus {
    RedReleaseBlocker,
}

// UAS: uas:theme-presentation-release-blocker-card:card
// Plane: Verification.
// Residency: metadata-only source-card blocker; no runtime/model/product bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ThemePresentationReleaseBlockerCard {
    pub family_id: String,
    pub issue_count: u64,
    pub organ: ThemePresentationOrgan,
    pub status: ThemePresentationStatus,
    pub source_refs: Vec<String>,
    pub focused_commands: Vec<String>,
    pub required_invariants: Vec<String>,
    pub mas_status: String,
    pub pro_status: String,
    pub presentation_as_capability_proof: bool,
    pub theme_tokens_select_runtime_route: bool,
    pub answer_packet_caveat_hidden: bool,
    pub mas_pro_copy_overclaims_capability: bool,
    pub repeat_forever_animation_claimed: bool,
    pub window_occlusion_gate_missing: bool,
    pub reduce_motion_gate_missing: bool,
    pub theme_switch_recreates_runtime_handles: bool,
    pub settings_unlocks_gated_capability: bool,
    pub hidden_tool_payload_visible: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub product_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub model_runtime_bytes_loaded: u64,
    pub product_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
}

impl ThemePresentationReleaseBlockerCard {
    pub fn from_family(family_id: &str, issue_count: u64) -> Result<Self, ThemePresentationError> {
        validate_token("family_id", family_id)?;
        if family_id != "theme_presentation" {
            return Err(ThemePresentationError::WrongFamily(family_id.to_string()));
        }
        if issue_count == 0 {
            return Err(ThemePresentationError::ZeroIssueCount);
        }
        Ok(Self {
            family_id: family_id.to_string(),
            issue_count,
            organ: ThemePresentationOrgan::ThemePresentation,
            status: ThemePresentationStatus::RedReleaseBlocker,
            source_refs: REQUIRED_SOURCE_REFS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            focused_commands: vec![
                "xcodebuild test -only-testing:EpistemosTests/ThemePairTests".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/ChatPresentationTests".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/SettingsWindowPresentationTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/MiniChatViewAuditTests".to_string(),
            ],
            required_invariants: REQUIRED_INVARIANTS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            mas_status: "red_release_blocker".to_string(),
            pro_status: "gated_release_blocker".to_string(),
            presentation_as_capability_proof: false,
            theme_tokens_select_runtime_route: false,
            answer_packet_caveat_hidden: false,
            mas_pro_copy_overclaims_capability: false,
            repeat_forever_animation_claimed: false,
            window_occlusion_gate_missing: false,
            reduce_motion_gate_missing: false,
            theme_switch_recreates_runtime_handles: false,
            settings_unlocks_gated_capability: false,
            hidden_tool_payload_visible: false,
            hidden_route_authority: false,
            hidden_cloud_fallback: false,
            l2_green_claimed: false,
            l3_green_claimed: false,
            product_green_claimed: false,
            live_dense_70b_claimed: false,
            model_runtime_bytes_loaded: 0,
            product_runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            rollback_ref: "rollback:theme_presentation_release_blocker_card".to_string(),
            run_event_log_ref: "run_event_log:theme_presentation_release_blocker_card".to_string(),
            answer_packet_ref: "answer_packet:theme_presentation_release_blocker_card".to_string(),
        })
    }

    pub fn validate(&self) -> Result<(), ThemePresentationError> {
        validate_token("family_id", &self.family_id)?;
        if self.family_id != "theme_presentation"
            || self.issue_count == 0
            || self.organ != ThemePresentationOrgan::ThemePresentation
            || self.status != ThemePresentationStatus::RedReleaseBlocker
        {
            return Err(ThemePresentationError::CardHeaderBroken);
        }
        validate_unique_exact_set("source_refs", &self.source_refs, &REQUIRED_SOURCE_REFS)?;
        validate_unique_exact_set(
            "required_invariants",
            &self.required_invariants,
            &REQUIRED_INVARIANTS,
        )?;
        validate_list("focused_commands", &self.focused_commands, 4, 8)?;
        for command in &self.focused_commands {
            if !command.starts_with("xcodebuild test -only-testing:EpistemosTests/") {
                return Err(ThemePresentationError::BadFocusedCommand);
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
        if self.presentation_as_capability_proof
            || self.theme_tokens_select_runtime_route
            || self.answer_packet_caveat_hidden
            || self.mas_pro_copy_overclaims_capability
            || self.repeat_forever_animation_claimed
            || self.window_occlusion_gate_missing
            || self.reduce_motion_gate_missing
            || self.theme_switch_recreates_runtime_handles
            || self.settings_unlocks_gated_capability
            || self.hidden_tool_payload_visible
            || self.hidden_route_authority
            || self.hidden_cloud_fallback
            || self.l2_green_claimed
            || self.l3_green_claimed
            || self.product_green_claimed
            || self.live_dense_70b_claimed
            || self.model_runtime_bytes_loaded != 0
            || self.product_runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(ThemePresentationError::PromotionBoundaryBroken);
        }
        Ok(())
    }
}

// UAS: uas:theme-presentation-release-blocker-card:metrics
// Plane: Verification.
// Residency: aggregate release-blocker metrics only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ThemePresentationMetrics {
    pub issue_count: u64,
    pub source_ref_count: usize,
    pub focused_command_count: usize,
    pub invariant_count: usize,
    pub model_runtime_bytes_loaded: u64,
    pub product_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

// UAS: uas:theme-presentation-release-blocker-card:witness
// Plane: Verification.
// Residency: metadata-only theme/presentation source-card witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ThemePresentationReleaseBlockerWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_ref: String,
    pub family_source_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_next_cursor: String,
    pub card: ThemePresentationReleaseBlockerCard,
    pub metrics: ThemePresentationMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl ThemePresentationReleaseBlockerWitness {
    pub fn new(
        upstream_ref: &str,
        family_source_ref: &str,
        upstream_overall_pass: bool,
        upstream_next_cursor: &str,
        family_id: &str,
        issue_count: u64,
    ) -> Result<Self, ThemePresentationError> {
        validate_upstream_ref(upstream_ref)?;
        validate_family_source_ref(family_source_ref)?;
        validate_token("upstream_next_cursor", upstream_next_cursor)?;
        if !upstream_overall_pass {
            return Err(ThemePresentationError::UpstreamNotPassed);
        }
        if upstream_next_cursor != THEME_PRESENTATION_RELEASE_BLOCKER_CARD_CURSOR {
            return Err(ThemePresentationError::WrongUpstreamCursor(
                upstream_next_cursor.to_string(),
            ));
        }
        let card = ThemePresentationReleaseBlockerCard::from_family(family_id, issue_count)?;
        card.validate()?;
        let metrics = ThemePresentationMetrics {
            issue_count: card.issue_count,
            source_ref_count: card.source_refs.len(),
            focused_command_count: card.focused_commands.len(),
            invariant_count: card.required_invariants.len(),
            model_runtime_bytes_loaded: card.model_runtime_bytes_loaded,
            product_runtime_bytes_loaded: card.product_runtime_bytes_loaded,
            provider_calls_made: card.provider_calls_made,
        };
        let address = theme_presentation_address(
            upstream_ref,
            family_source_ref,
            upstream_overall_pass,
            upstream_next_cursor,
            &card,
            &metrics,
        );
        Ok(Self {
            falsifier_id: THEME_PRESENTATION_RELEASE_BLOCKER_CARD_ID.to_string(),
            cursor: THEME_PRESENTATION_RELEASE_BLOCKER_CARD_CURSOR.to_string(),
            next_cursor: THEME_PRESENTATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR.to_string(),
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

    pub fn validate(&self) -> Result<(), ThemePresentationError> {
        if self.falsifier_id != THEME_PRESENTATION_RELEASE_BLOCKER_CARD_ID
            || self.cursor != THEME_PRESENTATION_RELEASE_BLOCKER_CARD_CURSOR
            || self.next_cursor != THEME_PRESENTATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(ThemePresentationError::WitnessHeaderBroken);
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
            return Err(ThemePresentationError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_theme_presentation_source_refs() -> &'static [&'static str] {
    &REQUIRED_SOURCE_REFS
}

pub fn required_theme_presentation_invariants() -> &'static [&'static str] {
    &REQUIRED_INVARIANTS
}

fn theme_presentation_address(
    upstream_ref: &str,
    family_source_ref: &str,
    upstream_overall_pass: bool,
    upstream_next_cursor: &str,
    card: &ThemePresentationReleaseBlockerCard,
    metrics: &ThemePresentationMetrics,
) -> String {
    let mut preimage = String::new();
    preimage.push_str(THEME_PRESENTATION_RELEASE_BLOCKER_CARD_ID);
    preimage.push_str(THEME_PRESENTATION_RELEASE_BLOCKER_CARD_CURSOR);
    preimage.push_str(THEME_PRESENTATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR);
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
) -> Result<(), ThemePresentationError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(ThemePresentationError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    let actual = values.iter().map(String::as_str).collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected {
        return Err(ThemePresentationError::MissingRequiredSet {
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
) -> Result<(), ThemePresentationError> {
    if values.len() < min || values.len() > max {
        return Err(ThemePresentationError::BadListLength {
            field,
            actual: values.len(),
        });
    }
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(ThemePresentationError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    Ok(())
}

fn validate_upstream_ref(value: &str) -> Result<(), ThemePresentationError> {
    validate_token("upstream_ref", value)?;
    if !value.starts_with("artifact:falsifiers/research_tool_catalog_no_hidden_authority/")
        || !value.contains("/result.json#F-ResearchToolCatalog-NoHiddenAuthority")
    {
        return Err(ThemePresentationError::BadUpstreamRef);
    }
    Ok(())
}

fn validate_family_source_ref(value: &str) -> Result<(), ThemePresentationError> {
    validate_token("family_source_ref", value)?;
    if !value.starts_with("artifact:falsifiers/release_audit_failure_family_source_card/")
        || !value.contains("/result.json#theme_presentation")
    {
        return Err(ThemePresentationError::BadFamilySourceRef);
    }
    Ok(())
}

fn validate_token(field: &'static str, value: &str) -> Result<(), ThemePresentationError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(ThemePresentationError::InvalidToken {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_text(field: &'static str, value: &str) -> Result<(), ThemePresentationError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(ThemePresentationError::InvalidText {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

// UAS: uas:theme-presentation-release-blocker-card:error
// Plane: Verification.
// Residency: fail-closed metadata validation errors.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ThemePresentationError {
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

impl fmt::Display for ThemePresentationError {
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
                "missing required set values for {field}: {actual}/{expected}"
            ),
            Self::BadUpstreamRef => write!(f, "bad upstream ref"),
            Self::BadFamilySourceRef => write!(f, "bad family source ref"),
            Self::UpstreamNotPassed => write!(f, "upstream witness did not pass"),
            Self::WrongUpstreamCursor(cursor) => write!(f, "wrong upstream cursor: {cursor}"),
            Self::WrongFamily(family) => write!(f, "wrong failure family: {family}"),
            Self::ZeroIssueCount => write!(f, "theme_presentation issue count cannot be zero"),
            Self::CardHeaderBroken => write!(f, "card header is inconsistent"),
            Self::BadFocusedCommand => write!(f, "focused command is not scoped to tests"),
            Self::PromotionBoundaryBroken => write!(f, "promotion boundary was broken"),
            Self::WitnessHeaderBroken => write!(f, "witness header is inconsistent"),
            Self::WitnessDigestMismatch => write!(f, "witness digest mismatch"),
        }
    }
}

impl std::error::Error for ThemePresentationError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_theme_presentation_card() {
        let witness = ThemePresentationReleaseBlockerWitness::new(
            THEME_PRESENTATION_UPSTREAM_REF,
            THEME_PRESENTATION_FAMILY_SOURCE_REF,
            true,
            THEME_PRESENTATION_RELEASE_BLOCKER_CARD_CURSOR,
            "theme_presentation",
            19,
        )
        .expect("valid theme presentation witness");
        witness.validate().expect("witness validates");
        assert_eq!(witness.metrics.source_ref_count, 12);
        assert_eq!(witness.metrics.focused_command_count, 4);
        assert_eq!(witness.metrics.invariant_count, 12);
        assert_eq!(witness.metrics.model_runtime_bytes_loaded, 0);
        assert_eq!(
            witness.next_cursor,
            THEME_PRESENTATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR
        );
    }

    #[test]
    fn rejects_wrong_upstream_or_family() {
        assert!(ThemePresentationReleaseBlockerWitness::new(
            THEME_PRESENTATION_UPSTREAM_REF,
            THEME_PRESENTATION_FAMILY_SOURCE_REF,
            false,
            THEME_PRESENTATION_RELEASE_BLOCKER_CARD_CURSOR,
            "theme_presentation",
            19,
        )
        .is_err());
        assert!(ThemePresentationReleaseBlockerWitness::new(
            THEME_PRESENTATION_UPSTREAM_REF,
            THEME_PRESENTATION_FAMILY_SOURCE_REF,
            true,
            "research_tool_catalog_no_hidden_authority",
            "theme_presentation",
            19,
        )
        .is_err());
        assert!(ThemePresentationReleaseBlockerWitness::new(
            THEME_PRESENTATION_UPSTREAM_REF,
            THEME_PRESENTATION_FAMILY_SOURCE_REF,
            true,
            THEME_PRESENTATION_RELEASE_BLOCKER_CARD_CURSOR,
            "research_tool_catalog",
            16,
        )
        .is_err());
    }

    #[test]
    fn rejects_presentation_promotion_and_runtime_leaks() {
        let mut card = ThemePresentationReleaseBlockerCard::from_family("theme_presentation", 19)
            .expect("valid card");
        card.presentation_as_capability_proof = true;
        assert!(card.validate().is_err());

        let mut card = ThemePresentationReleaseBlockerCard::from_family("theme_presentation", 19)
            .expect("valid card");
        card.source_refs
            .retain(|value| value != "Epistemos/Theme/EpistemosTheme.swift");
        assert!(card.validate().is_err());

        let mut card = ThemePresentationReleaseBlockerCard::from_family("theme_presentation", 19)
            .expect("valid card");
        card.model_runtime_bytes_loaded = 1;
        assert!(card.validate().is_err());
    }
}
