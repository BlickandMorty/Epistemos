use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

pub const UI_SHELL_SOURCE_GUARD_RELEASE_BLOCKER_CARD_ID: &str =
    "F-UiShellSourceGuard-ReleaseBlockerCard";
pub const UI_SHELL_SOURCE_GUARD_RELEASE_BLOCKER_CARD_CURSOR: &str =
    "ui_shell_source_guard_release_blocker_card";
pub const UI_SHELL_SOURCE_GUARD_RELEASE_BLOCKER_CARD_NEXT_CURSOR: &str =
    "runtime_performance_policy_release_blocker_card";
pub const UI_SHELL_SOURCE_GUARD_UPSTREAM_REF: &str =
    "artifact:falsifiers/editor_epdoc_surface_release_blocker_card/result.json#F-EditorEpdocSurface-ReleaseBlockerCard";
pub const UI_SHELL_SOURCE_GUARD_FAMILY_SOURCE_REF: &str =
    "artifact:falsifiers/release_audit_failure_family_source_card/result.json#ui_shell_source_guard";

const REQUIRED_SOURCE_REFS: [&str; 14] = [
    "Epistemos/App/AppEnvironment.swift",
    "Epistemos/App/AppBootstrap.swift",
    "Epistemos/App/RootView.swift",
    "Epistemos/App/UtilityWindowManager.swift",
    "Epistemos/Views/Shell/PageShell.swift",
    "Epistemos/Views/Shell/ToastOverlay.swift",
    "Epistemos/Views/Settings/SettingsView.swift",
    "Epistemos/Views/Settings/RuntimeLanesSection.swift",
    "Epistemos/Views/Settings/RuntimeTruthHealthRow.swift",
    "Epistemos/Views/Settings/AnswerPacketHealthRow.swift",
    "Epistemos/Views/MiniChat/MiniChatView.swift",
    "Epistemos/Views/MiniChat/MiniChatWindowController.swift",
    "EpistemosTests/SettingsWindowPresentationTests.swift",
    "EpistemosTests/SidebarShellValidationTests.swift",
];

const REQUIRED_INVARIANTS: [&str; 12] = [
    "app_environment_is_single_shell_injection_source",
    "root_shell_does_not_mount_hidden_agent_overlay",
    "settings_do_not_unlock_gated_runtime_capability",
    "runtime_lanes_show_truth_without_route_mutation",
    "mini_chat_is_not_agent_or_large_model_route_proof",
    "answer_packet_health_row_remains_caveated",
    "mas_pro_visibility_boundaries_remain_explicit",
    "unsupported_modes_are_hidden_or_marked_gated",
    "utility_windows_use_shared_app_environment",
    "shell_toast_status_is_not_capability_proof",
    "source_guard_tests_required_before_wrv_promotion",
    "focused_tests_required_before_wrv_promotion",
];

// UAS: uas:ui-shell-source-guard-release-blocker-card:organ
// Plane: Verification.
// Residency: metadata-only ui shell source-guard source-card classification.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UiShellSourceGuardOrgan {
    UiShellSourceGuard,
    AppEnvironment,
    SettingsSurface,
    MiniChatSurface,
}

// UAS: uas:ui-shell-source-guard-release-blocker-card:status
// Plane: Verification.
// Residency: retained release blocker classification only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UiShellSourceGuardStatus {
    RedReleaseBlocker,
}

// UAS: uas:ui-shell-source-guard-release-blocker-card:card
// Plane: Verification.
// Residency: metadata-only source-card blocker; no shell/model/runtime bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct UiShellSourceGuardReleaseBlockerCard {
    pub family_id: String,
    pub issue_count: u64,
    pub organ: UiShellSourceGuardOrgan,
    pub status: UiShellSourceGuardStatus,
    pub source_refs: Vec<String>,
    pub focused_commands: Vec<String>,
    pub required_invariants: Vec<String>,
    pub mas_status: String,
    pub pro_status: String,
    pub shell_surface_as_capability_proof: bool,
    pub settings_unlocks_gated_capability: bool,
    pub mini_chat_as_agent_route_proof: bool,
    pub runtime_lanes_mutate_routes: bool,
    pub answer_packet_caveat_hidden: bool,
    pub mas_pro_boundary_collapsed: bool,
    pub unsupported_mode_marked_live: bool,
    pub app_environment_drift_ignored: bool,
    pub hidden_agent_overlay_mounted: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub product_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub shell_bytes_loaded: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
}

impl UiShellSourceGuardReleaseBlockerCard {
    pub fn from_family(family_id: &str, issue_count: u64) -> Result<Self, UiShellSourceGuardError> {
        validate_token("family_id", family_id)?;
        if family_id != "ui_shell_source_guard" {
            return Err(UiShellSourceGuardError::WrongFamily(family_id.to_string()));
        }
        if issue_count == 0 {
            return Err(UiShellSourceGuardError::ZeroIssueCount);
        }
        Ok(Self {
            family_id: family_id.to_string(),
            issue_count,
            organ: UiShellSourceGuardOrgan::UiShellSourceGuard,
            status: UiShellSourceGuardStatus::RedReleaseBlocker,
            source_refs: REQUIRED_SOURCE_REFS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            focused_commands: vec![
                "xcodebuild test -only-testing:EpistemosTests/SettingsWindowPresentationTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/SidebarShellValidationTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/SettingsTruthFloorTests".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/AgentCommandCenterStateTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/CoreMASBoundarySourceGuardTests"
                    .to_string(),
            ],
            required_invariants: REQUIRED_INVARIANTS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            mas_status: "red_release_blocker".to_string(),
            pro_status: "gated_release_blocker".to_string(),
            shell_surface_as_capability_proof: false,
            settings_unlocks_gated_capability: false,
            mini_chat_as_agent_route_proof: false,
            runtime_lanes_mutate_routes: false,
            answer_packet_caveat_hidden: false,
            mas_pro_boundary_collapsed: false,
            unsupported_mode_marked_live: false,
            app_environment_drift_ignored: false,
            hidden_agent_overlay_mounted: false,
            l2_green_claimed: false,
            l3_green_claimed: false,
            product_green_claimed: false,
            live_dense_70b_claimed: false,
            shell_bytes_loaded: 0,
            model_runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            rollback_ref: "rollback:ui_shell_source_guard_release_blocker_card".to_string(),
            run_event_log_ref: "run_event_log:ui_shell_source_guard_release_blocker_card"
                .to_string(),
            answer_packet_ref: "answer_packet:ui_shell_source_guard_release_blocker_card"
                .to_string(),
        })
    }

    pub fn validate(&self) -> Result<(), UiShellSourceGuardError> {
        validate_token("family_id", &self.family_id)?;
        if self.family_id != "ui_shell_source_guard"
            || self.issue_count == 0
            || self.organ != UiShellSourceGuardOrgan::UiShellSourceGuard
            || self.status != UiShellSourceGuardStatus::RedReleaseBlocker
        {
            return Err(UiShellSourceGuardError::CardHeaderBroken);
        }
        validate_unique_exact_set("source_refs", &self.source_refs, &REQUIRED_SOURCE_REFS)?;
        validate_unique_exact_set(
            "required_invariants",
            &self.required_invariants,
            &REQUIRED_INVARIANTS,
        )?;
        validate_list("focused_commands", &self.focused_commands, 5, 8)?;
        for command in &self.focused_commands {
            if !(command.starts_with("xcodebuild test -only-testing:EpistemosTests/")
                && (command.contains("Settings")
                    || command.contains("Shell")
                    || command.contains("AgentCommandCenter")
                    || command.contains("CoreMASBoundary")))
            {
                return Err(UiShellSourceGuardError::BadFocusedCommand);
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
        if self.shell_surface_as_capability_proof
            || self.settings_unlocks_gated_capability
            || self.mini_chat_as_agent_route_proof
            || self.runtime_lanes_mutate_routes
            || self.answer_packet_caveat_hidden
            || self.mas_pro_boundary_collapsed
            || self.unsupported_mode_marked_live
            || self.app_environment_drift_ignored
            || self.hidden_agent_overlay_mounted
            || self.l2_green_claimed
            || self.l3_green_claimed
            || self.product_green_claimed
            || self.live_dense_70b_claimed
            || self.shell_bytes_loaded != 0
            || self.model_runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(UiShellSourceGuardError::PromotionBoundaryBroken);
        }
        Ok(())
    }
}

// UAS: uas:ui-shell-source-guard-release-blocker-card:metrics
// Plane: Verification.
// Residency: aggregate release-blocker metrics only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct UiShellSourceGuardMetrics {
    pub issue_count: u64,
    pub source_ref_count: usize,
    pub focused_command_count: usize,
    pub invariant_count: usize,
    pub shell_bytes_loaded: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

// UAS: uas:ui-shell-source-guard-release-blocker-card:witness
// Plane: Verification.
// Residency: metadata-only ui shell source-guard source-card witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct UiShellSourceGuardReleaseBlockerWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_ref: String,
    pub family_source_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_next_cursor: String,
    pub card: UiShellSourceGuardReleaseBlockerCard,
    pub metrics: UiShellSourceGuardMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl UiShellSourceGuardReleaseBlockerWitness {
    pub fn new(
        upstream_ref: &str,
        family_source_ref: &str,
        upstream_overall_pass: bool,
        upstream_next_cursor: &str,
        family_id: &str,
        issue_count: u64,
    ) -> Result<Self, UiShellSourceGuardError> {
        validate_upstream_ref(upstream_ref)?;
        validate_family_source_ref(family_source_ref)?;
        validate_token("upstream_next_cursor", upstream_next_cursor)?;
        if !upstream_overall_pass {
            return Err(UiShellSourceGuardError::UpstreamNotPassed);
        }
        if upstream_next_cursor != UI_SHELL_SOURCE_GUARD_RELEASE_BLOCKER_CARD_CURSOR {
            return Err(UiShellSourceGuardError::WrongUpstreamCursor(
                upstream_next_cursor.to_string(),
            ));
        }
        let card = UiShellSourceGuardReleaseBlockerCard::from_family(family_id, issue_count)?;
        card.validate()?;
        let metrics = UiShellSourceGuardMetrics {
            issue_count: card.issue_count,
            source_ref_count: card.source_refs.len(),
            focused_command_count: card.focused_commands.len(),
            invariant_count: card.required_invariants.len(),
            shell_bytes_loaded: card.shell_bytes_loaded,
            model_runtime_bytes_loaded: card.model_runtime_bytes_loaded,
            provider_calls_made: card.provider_calls_made,
        };
        let address = ui_shell_source_guard_address(
            upstream_ref,
            family_source_ref,
            upstream_overall_pass,
            upstream_next_cursor,
            &card,
            &metrics,
        );
        Ok(Self {
            falsifier_id: UI_SHELL_SOURCE_GUARD_RELEASE_BLOCKER_CARD_ID.to_string(),
            cursor: UI_SHELL_SOURCE_GUARD_RELEASE_BLOCKER_CARD_CURSOR.to_string(),
            next_cursor: UI_SHELL_SOURCE_GUARD_RELEASE_BLOCKER_CARD_NEXT_CURSOR.to_string(),
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

    pub fn validate(&self) -> Result<(), UiShellSourceGuardError> {
        if self.falsifier_id != UI_SHELL_SOURCE_GUARD_RELEASE_BLOCKER_CARD_ID
            || self.cursor != UI_SHELL_SOURCE_GUARD_RELEASE_BLOCKER_CARD_CURSOR
            || self.next_cursor != UI_SHELL_SOURCE_GUARD_RELEASE_BLOCKER_CARD_NEXT_CURSOR
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(UiShellSourceGuardError::WitnessHeaderBroken);
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
            return Err(UiShellSourceGuardError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_ui_shell_source_guard_source_refs() -> &'static [&'static str] {
    &REQUIRED_SOURCE_REFS
}

pub fn required_ui_shell_source_guard_invariants() -> &'static [&'static str] {
    &REQUIRED_INVARIANTS
}

fn ui_shell_source_guard_address(
    upstream_ref: &str,
    family_source_ref: &str,
    upstream_overall_pass: bool,
    upstream_next_cursor: &str,
    card: &UiShellSourceGuardReleaseBlockerCard,
    metrics: &UiShellSourceGuardMetrics,
) -> String {
    let mut preimage = String::new();
    preimage.push_str(UI_SHELL_SOURCE_GUARD_RELEASE_BLOCKER_CARD_ID);
    preimage.push_str(UI_SHELL_SOURCE_GUARD_RELEASE_BLOCKER_CARD_CURSOR);
    preimage.push_str(UI_SHELL_SOURCE_GUARD_RELEASE_BLOCKER_CARD_NEXT_CURSOR);
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
) -> Result<(), UiShellSourceGuardError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(UiShellSourceGuardError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    let actual = values.iter().map(String::as_str).collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected {
        return Err(UiShellSourceGuardError::MissingRequiredSet {
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
) -> Result<(), UiShellSourceGuardError> {
    if values.len() < min || values.len() > max {
        return Err(UiShellSourceGuardError::BadListLength {
            field,
            actual: values.len(),
        });
    }
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(UiShellSourceGuardError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    Ok(())
}

fn validate_upstream_ref(value: &str) -> Result<(), UiShellSourceGuardError> {
    validate_token("upstream_ref", value)?;
    if !value.starts_with("artifact:falsifiers/editor_epdoc_surface_release_blocker_card/")
        || !value.contains("/result.json#F-EditorEpdocSurface-ReleaseBlockerCard")
    {
        return Err(UiShellSourceGuardError::BadUpstreamRef);
    }
    Ok(())
}

fn validate_family_source_ref(value: &str) -> Result<(), UiShellSourceGuardError> {
    validate_token("family_source_ref", value)?;
    if !value.starts_with("artifact:falsifiers/release_audit_failure_family_source_card/")
        || !value.contains("/result.json#ui_shell_source_guard")
    {
        return Err(UiShellSourceGuardError::BadFamilySourceRef);
    }
    Ok(())
}

fn validate_token(field: &'static str, value: &str) -> Result<(), UiShellSourceGuardError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(UiShellSourceGuardError::InvalidToken {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_text(field: &'static str, value: &str) -> Result<(), UiShellSourceGuardError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(UiShellSourceGuardError::InvalidText {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

// UAS: uas:ui-shell-source-guard-release-blocker-card:error
// Plane: Verification.
// Residency: fail-closed metadata validation errors.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum UiShellSourceGuardError {
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
    BadFocusedCommand,
    BadUpstreamRef,
    BadFamilySourceRef,
    UpstreamNotPassed,
    WrongUpstreamCursor(String),
    WrongFamily(String),
    ZeroIssueCount,
    CardHeaderBroken,
    PromotionBoundaryBroken,
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for UiShellSourceGuardError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for UiShellSourceGuardError {}

#[cfg(test)]
mod tests {
    use super::*;

    fn witness() -> UiShellSourceGuardReleaseBlockerWitness {
        UiShellSourceGuardReleaseBlockerWitness::new(
            UI_SHELL_SOURCE_GUARD_UPSTREAM_REF,
            UI_SHELL_SOURCE_GUARD_FAMILY_SOURCE_REF,
            true,
            UI_SHELL_SOURCE_GUARD_RELEASE_BLOCKER_CARD_CURSOR,
            "ui_shell_source_guard",
            14,
        )
        .expect("valid ui shell source-guard blocker witness")
    }

    #[test]
    fn accepts_ui_shell_source_guard_card() {
        let witness = witness();
        assert_eq!(witness.card.issue_count, 14);
        assert_eq!(witness.metrics.source_ref_count, REQUIRED_SOURCE_REFS.len());
        assert_eq!(witness.metrics.invariant_count, REQUIRED_INVARIANTS.len());
        assert!(witness.metadata_only);
        assert!(witness.no_product_promotion);
        assert!(witness.address.starts_with("sha256:"));
        witness.validate().expect("witness validates");
    }

    #[test]
    fn rejects_wrong_upstream_or_family() {
        assert!(UiShellSourceGuardReleaseBlockerWitness::new(
            UI_SHELL_SOURCE_GUARD_UPSTREAM_REF,
            UI_SHELL_SOURCE_GUARD_FAMILY_SOURCE_REF,
            false,
            UI_SHELL_SOURCE_GUARD_RELEASE_BLOCKER_CARD_CURSOR,
            "ui_shell_source_guard",
            14,
        )
        .is_err());
        assert!(UiShellSourceGuardReleaseBlockerWitness::new(
            UI_SHELL_SOURCE_GUARD_UPSTREAM_REF,
            UI_SHELL_SOURCE_GUARD_FAMILY_SOURCE_REF,
            true,
            "editor_epdoc_surface_release_blocker_card",
            "ui_shell_source_guard",
            14,
        )
        .is_err());
        assert!(UiShellSourceGuardReleaseBlockerWitness::new(
            UI_SHELL_SOURCE_GUARD_UPSTREAM_REF,
            UI_SHELL_SOURCE_GUARD_FAMILY_SOURCE_REF,
            true,
            UI_SHELL_SOURCE_GUARD_RELEASE_BLOCKER_CARD_CURSOR,
            "editor_epdoc_surface",
            14,
        )
        .is_err());
    }

    #[test]
    fn rejects_shell_authority_promotion_and_byte_leaks() {
        let mut card = witness().card;
        card.settings_unlocks_gated_capability = true;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.mini_chat_as_agent_route_proof = true;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.product_green_claimed = true;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.shell_bytes_loaded = 1;
        assert!(card.validate().is_err());
    }
}
