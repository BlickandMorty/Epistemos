use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

pub const EDITOR_EPDOC_SURFACE_RELEASE_BLOCKER_CARD_ID: &str =
    "F-EditorEpdocSurface-ReleaseBlockerCard";
pub const EDITOR_EPDOC_SURFACE_RELEASE_BLOCKER_CARD_CURSOR: &str =
    "editor_epdoc_surface_release_blocker_card";
pub const EDITOR_EPDOC_SURFACE_RELEASE_BLOCKER_CARD_NEXT_CURSOR: &str =
    "ui_shell_source_guard_release_blocker_card";
pub const EDITOR_EPDOC_SURFACE_UPSTREAM_REF: &str =
    "artifact:falsifiers/distribution_project_integrity_release_blocker_card/result.json#F-DistributionProjectIntegrity-ReleaseBlockerCard";
pub const EDITOR_EPDOC_SURFACE_FAMILY_SOURCE_REF: &str =
    "artifact:falsifiers/release_audit_failure_family_source_card/result.json#editor_epdoc_surface";

const REQUIRED_SOURCE_REFS: [&str; 14] = [
    "Epistemos/Views/Notes/ProseEditorView.swift",
    "Epistemos/Views/Notes/ProseEditorRepresentable2.swift",
    "Epistemos/Views/Notes/ProseTextView2.swift",
    "Epistemos/Views/Notes/MarkdownContentStorage.swift",
    "Epistemos/Views/Epdoc/EpdocEditorChromeView.swift",
    "Epistemos/Views/Epdoc/EpdocCopilotDockView.swift",
    "js-editor/src/bridge/inbound.ts",
    "Epistemos/Engine/EpdocDocument.swift",
    "Epistemos/Engine/EpdocEditorBridge.swift",
    "Epistemos/Sync/ReadableBlocksProjector.swift",
    "Epistemos/Sync/ReadableBlocksIndex.swift",
    "EpistemosTests/EpdocDocumentTests.swift",
    "EpistemosTests/EpdocCopilotSurfaceTests.swift",
    "EpistemosTests/ProseTextView2AppearanceTests.swift",
];

const REQUIRED_INVARIANTS: [&str; 12] = [
    "prose_textkit_mutations_remain_undo_safe",
    "epdoc_package_is_not_runtime_proof",
    "epdoc_bridge_commands_require_visible_actions",
    "readable_blocks_projection_is_not_hidden_route_authority",
    "copilot_surface_does_not_claim_freeform_agent_loop",
    "model_suggestions_do_not_mutate_without_acceptance",
    "editor_indices_require_staleness_and_checksum_guards",
    "hidden_chain_and_tool_payloads_never_render_as_editor_content",
    "epdoc_graph_projection_requires_source_bound_caveats",
    "large_model_editor_claims_require_answer_packet",
    "focused_tests_required_before_wrv_promotion",
    "release_audit_family_remains_red_until_focused_tests_pass",
];

// UAS: uas:editor-epdoc-surface-release-blocker-card:organ
// Plane: Verification.
// Residency: metadata-only editor/EPDoc source-card classification.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EditorEpdocSurfaceOrgan {
    EditorSurface,
    ProseEditor,
    EpdocBridge,
    ReadableBlocks,
}

// UAS: uas:editor-epdoc-surface-release-blocker-card:status
// Plane: Verification.
// Residency: retained release blocker classification only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EditorEpdocSurfaceStatus {
    RedReleaseBlocker,
}

// UAS: uas:editor-epdoc-surface-release-blocker-card:card
// Plane: Verification.
// Residency: metadata-only source-card blocker; no editor/model/runtime bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct EditorEpdocSurfaceReleaseBlockerCard {
    pub family_id: String,
    pub issue_count: u64,
    pub organ: EditorEpdocSurfaceOrgan,
    pub status: EditorEpdocSurfaceStatus,
    pub source_refs: Vec<String>,
    pub focused_commands: Vec<String>,
    pub required_invariants: Vec<String>,
    pub mas_status: String,
    pub pro_status: String,
    pub editor_surface_as_runtime_proof: bool,
    pub epdoc_package_as_runtime_proof: bool,
    pub readable_blocks_as_route_authority: bool,
    pub model_mutation_without_acceptance: bool,
    pub hidden_chain_rendered_as_editor_content: bool,
    pub hidden_tool_payload_rendered_as_editor_content: bool,
    pub stale_projection_ignored: bool,
    pub checksum_guard_missing: bool,
    pub copilot_freeform_agent_claimed: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub product_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub editor_bytes_loaded: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
}

impl EditorEpdocSurfaceReleaseBlockerCard {
    pub fn from_family(family_id: &str, issue_count: u64) -> Result<Self, EditorEpdocSurfaceError> {
        validate_token("family_id", family_id)?;
        if family_id != "editor_epdoc_surface" {
            return Err(EditorEpdocSurfaceError::WrongFamily(family_id.to_string()));
        }
        if issue_count == 0 {
            return Err(EditorEpdocSurfaceError::ZeroIssueCount);
        }
        Ok(Self {
            family_id: family_id.to_string(),
            issue_count,
            organ: EditorEpdocSurfaceOrgan::EditorSurface,
            status: EditorEpdocSurfaceStatus::RedReleaseBlocker,
            source_refs: REQUIRED_SOURCE_REFS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            focused_commands: vec![
                "xcodebuild test -only-testing:EpistemosTests/EpdocDocumentTests".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/EpdocCopilotSurfaceTests".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/ProseTextView2AppearanceTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/ReadableBlocksProjectorTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/EpdocEditorBridgeTests".to_string(),
            ],
            required_invariants: REQUIRED_INVARIANTS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            mas_status: "red_release_blocker".to_string(),
            pro_status: "gated_release_blocker".to_string(),
            editor_surface_as_runtime_proof: false,
            epdoc_package_as_runtime_proof: false,
            readable_blocks_as_route_authority: false,
            model_mutation_without_acceptance: false,
            hidden_chain_rendered_as_editor_content: false,
            hidden_tool_payload_rendered_as_editor_content: false,
            stale_projection_ignored: false,
            checksum_guard_missing: false,
            copilot_freeform_agent_claimed: false,
            l2_green_claimed: false,
            l3_green_claimed: false,
            product_green_claimed: false,
            live_dense_70b_claimed: false,
            editor_bytes_loaded: 0,
            model_runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            rollback_ref: "rollback:editor_epdoc_surface_release_blocker_card".to_string(),
            run_event_log_ref: "run_event_log:editor_epdoc_surface_release_blocker_card"
                .to_string(),
            answer_packet_ref: "answer_packet:editor_epdoc_surface_release_blocker_card"
                .to_string(),
        })
    }

    pub fn validate(&self) -> Result<(), EditorEpdocSurfaceError> {
        validate_token("family_id", &self.family_id)?;
        if self.family_id != "editor_epdoc_surface"
            || self.issue_count == 0
            || self.organ != EditorEpdocSurfaceOrgan::EditorSurface
            || self.status != EditorEpdocSurfaceStatus::RedReleaseBlocker
        {
            return Err(EditorEpdocSurfaceError::CardHeaderBroken);
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
                && (command.contains("Epdoc")
                    || command.contains("ProseTextView2")
                    || command.contains("ReadableBlocks")))
            {
                return Err(EditorEpdocSurfaceError::BadFocusedCommand);
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
        if self.editor_surface_as_runtime_proof
            || self.epdoc_package_as_runtime_proof
            || self.readable_blocks_as_route_authority
            || self.model_mutation_without_acceptance
            || self.hidden_chain_rendered_as_editor_content
            || self.hidden_tool_payload_rendered_as_editor_content
            || self.stale_projection_ignored
            || self.checksum_guard_missing
            || self.copilot_freeform_agent_claimed
            || self.l2_green_claimed
            || self.l3_green_claimed
            || self.product_green_claimed
            || self.live_dense_70b_claimed
            || self.editor_bytes_loaded != 0
            || self.model_runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(EditorEpdocSurfaceError::PromotionBoundaryBroken);
        }
        Ok(())
    }
}

// UAS: uas:editor-epdoc-surface-release-blocker-card:metrics
// Plane: Verification.
// Residency: aggregate release-blocker metrics only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct EditorEpdocSurfaceMetrics {
    pub issue_count: u64,
    pub source_ref_count: usize,
    pub focused_command_count: usize,
    pub invariant_count: usize,
    pub editor_bytes_loaded: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

// UAS: uas:editor-epdoc-surface-release-blocker-card:witness
// Plane: Verification.
// Residency: metadata-only editor/EPDoc source-card witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct EditorEpdocSurfaceReleaseBlockerWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_ref: String,
    pub family_source_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_next_cursor: String,
    pub card: EditorEpdocSurfaceReleaseBlockerCard,
    pub metrics: EditorEpdocSurfaceMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl EditorEpdocSurfaceReleaseBlockerWitness {
    pub fn new(
        upstream_ref: &str,
        family_source_ref: &str,
        upstream_overall_pass: bool,
        upstream_next_cursor: &str,
        family_id: &str,
        issue_count: u64,
    ) -> Result<Self, EditorEpdocSurfaceError> {
        validate_upstream_ref(upstream_ref)?;
        validate_family_source_ref(family_source_ref)?;
        validate_token("upstream_next_cursor", upstream_next_cursor)?;
        if !upstream_overall_pass {
            return Err(EditorEpdocSurfaceError::UpstreamNotPassed);
        }
        if upstream_next_cursor != EDITOR_EPDOC_SURFACE_RELEASE_BLOCKER_CARD_CURSOR {
            return Err(EditorEpdocSurfaceError::WrongUpstreamCursor(
                upstream_next_cursor.to_string(),
            ));
        }
        let card = EditorEpdocSurfaceReleaseBlockerCard::from_family(family_id, issue_count)?;
        card.validate()?;
        let metrics = EditorEpdocSurfaceMetrics {
            issue_count: card.issue_count,
            source_ref_count: card.source_refs.len(),
            focused_command_count: card.focused_commands.len(),
            invariant_count: card.required_invariants.len(),
            editor_bytes_loaded: card.editor_bytes_loaded,
            model_runtime_bytes_loaded: card.model_runtime_bytes_loaded,
            provider_calls_made: card.provider_calls_made,
        };
        let address = editor_epdoc_surface_address(
            upstream_ref,
            family_source_ref,
            upstream_overall_pass,
            upstream_next_cursor,
            &card,
            &metrics,
        );
        Ok(Self {
            falsifier_id: EDITOR_EPDOC_SURFACE_RELEASE_BLOCKER_CARD_ID.to_string(),
            cursor: EDITOR_EPDOC_SURFACE_RELEASE_BLOCKER_CARD_CURSOR.to_string(),
            next_cursor: EDITOR_EPDOC_SURFACE_RELEASE_BLOCKER_CARD_NEXT_CURSOR.to_string(),
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

    pub fn validate(&self) -> Result<(), EditorEpdocSurfaceError> {
        if self.falsifier_id != EDITOR_EPDOC_SURFACE_RELEASE_BLOCKER_CARD_ID
            || self.cursor != EDITOR_EPDOC_SURFACE_RELEASE_BLOCKER_CARD_CURSOR
            || self.next_cursor != EDITOR_EPDOC_SURFACE_RELEASE_BLOCKER_CARD_NEXT_CURSOR
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(EditorEpdocSurfaceError::WitnessHeaderBroken);
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
            return Err(EditorEpdocSurfaceError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_editor_epdoc_surface_source_refs() -> &'static [&'static str] {
    &REQUIRED_SOURCE_REFS
}

pub fn required_editor_epdoc_surface_invariants() -> &'static [&'static str] {
    &REQUIRED_INVARIANTS
}

fn editor_epdoc_surface_address(
    upstream_ref: &str,
    family_source_ref: &str,
    upstream_overall_pass: bool,
    upstream_next_cursor: &str,
    card: &EditorEpdocSurfaceReleaseBlockerCard,
    metrics: &EditorEpdocSurfaceMetrics,
) -> String {
    let mut preimage = String::new();
    preimage.push_str(EDITOR_EPDOC_SURFACE_RELEASE_BLOCKER_CARD_ID);
    preimage.push_str(EDITOR_EPDOC_SURFACE_RELEASE_BLOCKER_CARD_CURSOR);
    preimage.push_str(EDITOR_EPDOC_SURFACE_RELEASE_BLOCKER_CARD_NEXT_CURSOR);
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
) -> Result<(), EditorEpdocSurfaceError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(EditorEpdocSurfaceError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    let actual = values.iter().map(String::as_str).collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected {
        return Err(EditorEpdocSurfaceError::MissingRequiredSet {
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
) -> Result<(), EditorEpdocSurfaceError> {
    if values.len() < min || values.len() > max {
        return Err(EditorEpdocSurfaceError::BadListLength {
            field,
            actual: values.len(),
        });
    }
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(EditorEpdocSurfaceError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    Ok(())
}

fn validate_upstream_ref(value: &str) -> Result<(), EditorEpdocSurfaceError> {
    validate_token("upstream_ref", value)?;
    if !value
        .starts_with("artifact:falsifiers/distribution_project_integrity_release_blocker_card/")
        || !value.contains("/result.json#F-DistributionProjectIntegrity-ReleaseBlockerCard")
    {
        return Err(EditorEpdocSurfaceError::BadUpstreamRef);
    }
    Ok(())
}

fn validate_family_source_ref(value: &str) -> Result<(), EditorEpdocSurfaceError> {
    validate_token("family_source_ref", value)?;
    if !value.starts_with("artifact:falsifiers/release_audit_failure_family_source_card/")
        || !value.contains("/result.json#editor_epdoc_surface")
    {
        return Err(EditorEpdocSurfaceError::BadFamilySourceRef);
    }
    Ok(())
}

fn validate_token(field: &'static str, value: &str) -> Result<(), EditorEpdocSurfaceError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(EditorEpdocSurfaceError::InvalidToken {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_text(field: &'static str, value: &str) -> Result<(), EditorEpdocSurfaceError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(EditorEpdocSurfaceError::InvalidText {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

// UAS: uas:editor-epdoc-surface-release-blocker-card:error
// Plane: Verification.
// Residency: fail-closed metadata validation errors.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum EditorEpdocSurfaceError {
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

impl fmt::Display for EditorEpdocSurfaceError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for EditorEpdocSurfaceError {}

#[cfg(test)]
mod tests {
    use super::*;

    fn witness() -> EditorEpdocSurfaceReleaseBlockerWitness {
        EditorEpdocSurfaceReleaseBlockerWitness::new(
            EDITOR_EPDOC_SURFACE_UPSTREAM_REF,
            EDITOR_EPDOC_SURFACE_FAMILY_SOURCE_REF,
            true,
            EDITOR_EPDOC_SURFACE_RELEASE_BLOCKER_CARD_CURSOR,
            "editor_epdoc_surface",
            14,
        )
        .expect("valid editor/EPDoc blocker witness")
    }

    #[test]
    fn accepts_editor_epdoc_surface_card() {
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
        assert!(EditorEpdocSurfaceReleaseBlockerWitness::new(
            EDITOR_EPDOC_SURFACE_UPSTREAM_REF,
            EDITOR_EPDOC_SURFACE_FAMILY_SOURCE_REF,
            false,
            EDITOR_EPDOC_SURFACE_RELEASE_BLOCKER_CARD_CURSOR,
            "editor_epdoc_surface",
            14,
        )
        .is_err());
        assert!(EditorEpdocSurfaceReleaseBlockerWitness::new(
            EDITOR_EPDOC_SURFACE_UPSTREAM_REF,
            EDITOR_EPDOC_SURFACE_FAMILY_SOURCE_REF,
            true,
            "distribution_project_integrity_release_blocker_card",
            "editor_epdoc_surface",
            14,
        )
        .is_err());
        assert!(EditorEpdocSurfaceReleaseBlockerWitness::new(
            EDITOR_EPDOC_SURFACE_UPSTREAM_REF,
            EDITOR_EPDOC_SURFACE_FAMILY_SOURCE_REF,
            true,
            EDITOR_EPDOC_SURFACE_RELEASE_BLOCKER_CARD_CURSOR,
            "distribution_project_integrity",
            18,
        )
        .is_err());
    }

    #[test]
    fn rejects_editor_authority_promotion_and_byte_leaks() {
        let mut card = witness().card;
        card.readable_blocks_as_route_authority = true;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.model_mutation_without_acceptance = true;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.product_green_claimed = true;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.editor_bytes_loaded = 1;
        assert!(card.validate().is_err());
    }
}
