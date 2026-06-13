use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

pub const RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_ID: &str =
    "F-ResearchToolCatalog-NoHiddenAuthority";
pub const RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_CURSOR: &str =
    "research_tool_catalog_no_hidden_authority";
pub const RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_NEXT_CURSOR: &str =
    "theme_presentation_release_blocker_card";
pub const RESEARCH_TOOL_CATALOG_UPSTREAM_REF: &str = "artifact:falsifiers/graph_filter_visibility_release_blocker_card/result.json#F-GraphFilterVisibility-ReleaseBlockerCard";
pub const RESEARCH_TOOL_CATALOG_FAMILY_SOURCE_REF: &str = "artifact:falsifiers/release_audit_failure_family_source_card/result.json#research_tool_catalog";

const REQUIRED_SOURCE_REFS: [&str; 10] = [
    "Epistemos/Omega/MCPBridge.swift",
    "Epistemos/Bridge/ToolTierBridge.swift",
    "Epistemos/Omega/ResearchOrchestrator.swift",
    "Epistemos/Omega/ResearchComplexityGate.swift",
    "Epistemos/Views/Omega/ResearchRequestView.swift",
    "Epistemos/State/AgentCommandCenterState.swift",
    "Epistemos/Engine/AgentHarness/AgentAuthority.swift",
    "agent_core/src/tools/registry.rs",
    "agent_core/src/bridge.rs",
    "EpistemosTests/ResearchModeTests.swift",
];

const REQUIRED_INVARIANTS: [&str; 12] = [
    "seven_research_tools_are_explicit_catalog_entries",
    "research_tools_stay_read_only_non_destructive",
    "planning_prompt_surfaces_canonical_names_only",
    "aliases_normalize_without_expanding_authority",
    "chat_lite_research_tools_do_not_inherit_agent_tools",
    "chat_pro_tools_do_not_inherit_full_agent_surface",
    "tool_tier_bridge_matches_rust_registry_names",
    "research_complexity_gate_is_signal_not_route_authority",
    "research_orchestrator_outputs_visible_evidence_not_hidden_routes",
    "agent_authority_policy_must_admit_each_tool_use",
    "mcp_bridge_catalog_export_is_visible_not_runtime_proof",
    "release_audit_family_remains_red_until_focused_tests_pass",
];

// UAS: uas:research-tool-catalog-no-hidden-authority:organ
// Plane: Verification.
// Residency: metadata-only research-tool catalog classification.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ResearchToolCatalogOrgan {
    ResearchToolCatalog,
    OmegaToolRegistry,
    ToolTierBridge,
    ResearchOrchestrator,
    AgentAuthority,
}

// UAS: uas:research-tool-catalog-no-hidden-authority:status
// Plane: Verification.
// Residency: retained release blocker classification only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ResearchToolCatalogStatus {
    RedReleaseBlocker,
}

// UAS: uas:research-tool-catalog-no-hidden-authority:card
// Plane: Verification.
// Residency: metadata-only source-card blocker; no tool/model/runtime bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ResearchToolCatalogNoHiddenAuthorityCard {
    pub family_id: String,
    pub issue_count: u64,
    pub organ: ResearchToolCatalogOrgan,
    pub status: ResearchToolCatalogStatus,
    pub source_refs: Vec<String>,
    pub focused_commands: Vec<String>,
    pub required_invariants: Vec<String>,
    pub mas_status: String,
    pub pro_status: String,
    pub research_catalog_as_route_authority: bool,
    pub hidden_research_tool_authority: bool,
    pub destructive_research_tool_claimed: bool,
    pub unconfirmed_mutating_research_tool_claimed: bool,
    pub alias_expands_authority: bool,
    pub chat_lite_inherits_agent_tools: bool,
    pub chat_pro_inherits_full_agent_surface: bool,
    pub catalog_export_as_runtime_proof: bool,
    pub research_complexity_gate_as_route_authority: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub product_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub model_runtime_bytes_loaded: u64,
    pub tool_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
}

impl ResearchToolCatalogNoHiddenAuthorityCard {
    pub fn from_family(
        family_id: &str,
        issue_count: u64,
    ) -> Result<Self, ResearchToolCatalogError> {
        validate_token("family_id", family_id)?;
        if family_id != "research_tool_catalog" {
            return Err(ResearchToolCatalogError::WrongFamily(family_id.to_string()));
        }
        if issue_count == 0 {
            return Err(ResearchToolCatalogError::ZeroIssueCount);
        }
        Ok(Self {
            family_id: family_id.to_string(),
            issue_count,
            organ: ResearchToolCatalogOrgan::ResearchToolCatalog,
            status: ResearchToolCatalogStatus::RedReleaseBlocker,
            source_refs: REQUIRED_SOURCE_REFS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            focused_commands: vec![
                "xcodebuild test -only-testing:EpistemosTests/ResearchModeTests".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/ToolTierBridgeVisibleFailureGuardTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/ToolSurfacePolicyTests".to_string(),
            ],
            required_invariants: REQUIRED_INVARIANTS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            mas_status: "red_release_blocker".to_string(),
            pro_status: "gated_release_blocker".to_string(),
            research_catalog_as_route_authority: false,
            hidden_research_tool_authority: false,
            destructive_research_tool_claimed: false,
            unconfirmed_mutating_research_tool_claimed: false,
            alias_expands_authority: false,
            chat_lite_inherits_agent_tools: false,
            chat_pro_inherits_full_agent_surface: false,
            catalog_export_as_runtime_proof: false,
            research_complexity_gate_as_route_authority: false,
            hidden_route_authority: false,
            hidden_cloud_fallback: false,
            l2_green_claimed: false,
            l3_green_claimed: false,
            product_green_claimed: false,
            live_dense_70b_claimed: false,
            model_runtime_bytes_loaded: 0,
            tool_runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            rollback_ref: "rollback:research_tool_catalog_no_hidden_authority".to_string(),
            run_event_log_ref: "run_event_log:research_tool_catalog_no_hidden_authority"
                .to_string(),
            answer_packet_ref: "answer_packet:research_tool_catalog_no_hidden_authority"
                .to_string(),
        })
    }

    pub fn validate(&self) -> Result<(), ResearchToolCatalogError> {
        validate_token("family_id", &self.family_id)?;
        if self.family_id != "research_tool_catalog"
            || self.issue_count == 0
            || self.organ != ResearchToolCatalogOrgan::ResearchToolCatalog
            || self.status != ResearchToolCatalogStatus::RedReleaseBlocker
        {
            return Err(ResearchToolCatalogError::CardHeaderBroken);
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
                return Err(ResearchToolCatalogError::BadFocusedCommand);
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
        if self.research_catalog_as_route_authority
            || self.hidden_research_tool_authority
            || self.destructive_research_tool_claimed
            || self.unconfirmed_mutating_research_tool_claimed
            || self.alias_expands_authority
            || self.chat_lite_inherits_agent_tools
            || self.chat_pro_inherits_full_agent_surface
            || self.catalog_export_as_runtime_proof
            || self.research_complexity_gate_as_route_authority
            || self.hidden_route_authority
            || self.hidden_cloud_fallback
            || self.l2_green_claimed
            || self.l3_green_claimed
            || self.product_green_claimed
            || self.live_dense_70b_claimed
            || self.model_runtime_bytes_loaded != 0
            || self.tool_runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(ResearchToolCatalogError::PromotionBoundaryBroken);
        }
        Ok(())
    }
}

// UAS: uas:research-tool-catalog-no-hidden-authority:metrics
// Plane: Verification.
// Residency: aggregate release-blocker metrics only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ResearchToolCatalogMetrics {
    pub issue_count: u64,
    pub source_ref_count: usize,
    pub focused_command_count: usize,
    pub invariant_count: usize,
    pub model_runtime_bytes_loaded: u64,
    pub tool_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

// UAS: uas:research-tool-catalog-no-hidden-authority:witness
// Plane: Verification.
// Residency: metadata-only research-tool no-hidden-authority witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ResearchToolCatalogNoHiddenAuthorityWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_ref: String,
    pub family_source_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_next_cursor: String,
    pub card: ResearchToolCatalogNoHiddenAuthorityCard,
    pub metrics: ResearchToolCatalogMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl ResearchToolCatalogNoHiddenAuthorityWitness {
    pub fn new(
        upstream_ref: &str,
        family_source_ref: &str,
        upstream_overall_pass: bool,
        upstream_next_cursor: &str,
        family_id: &str,
        issue_count: u64,
    ) -> Result<Self, ResearchToolCatalogError> {
        validate_upstream_ref(upstream_ref)?;
        validate_family_source_ref(family_source_ref)?;
        validate_token("upstream_next_cursor", upstream_next_cursor)?;
        if !upstream_overall_pass {
            return Err(ResearchToolCatalogError::UpstreamNotPassed);
        }
        if upstream_next_cursor != RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_CURSOR {
            return Err(ResearchToolCatalogError::WrongUpstreamCursor(
                upstream_next_cursor.to_string(),
            ));
        }
        let card = ResearchToolCatalogNoHiddenAuthorityCard::from_family(family_id, issue_count)?;
        card.validate()?;
        let metrics = ResearchToolCatalogMetrics {
            issue_count: card.issue_count,
            source_ref_count: card.source_refs.len(),
            focused_command_count: card.focused_commands.len(),
            invariant_count: card.required_invariants.len(),
            model_runtime_bytes_loaded: card.model_runtime_bytes_loaded,
            tool_runtime_bytes_loaded: card.tool_runtime_bytes_loaded,
            provider_calls_made: card.provider_calls_made,
        };
        let address = research_tool_catalog_address(
            upstream_ref,
            family_source_ref,
            upstream_overall_pass,
            upstream_next_cursor,
            &card,
            &metrics,
        );
        Ok(Self {
            falsifier_id: RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_ID.to_string(),
            cursor: RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_CURSOR.to_string(),
            next_cursor: RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_NEXT_CURSOR.to_string(),
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

    pub fn validate(&self) -> Result<(), ResearchToolCatalogError> {
        if self.falsifier_id != RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_ID
            || self.cursor != RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_CURSOR
            || self.next_cursor != RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_NEXT_CURSOR
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(ResearchToolCatalogError::WitnessHeaderBroken);
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
            return Err(ResearchToolCatalogError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_research_tool_catalog_source_refs() -> &'static [&'static str] {
    &REQUIRED_SOURCE_REFS
}

pub fn required_research_tool_catalog_invariants() -> &'static [&'static str] {
    &REQUIRED_INVARIANTS
}

fn research_tool_catalog_address(
    upstream_ref: &str,
    family_source_ref: &str,
    upstream_overall_pass: bool,
    upstream_next_cursor: &str,
    card: &ResearchToolCatalogNoHiddenAuthorityCard,
    metrics: &ResearchToolCatalogMetrics,
) -> String {
    let mut preimage = String::new();
    preimage.push_str(RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_ID);
    preimage.push_str(RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_CURSOR);
    preimage.push_str(RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_NEXT_CURSOR);
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
) -> Result<(), ResearchToolCatalogError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(ResearchToolCatalogError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    let actual = values.iter().map(String::as_str).collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected {
        return Err(ResearchToolCatalogError::MissingRequiredSet {
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
) -> Result<(), ResearchToolCatalogError> {
    if values.len() < min || values.len() > max {
        return Err(ResearchToolCatalogError::BadListLength {
            field,
            actual: values.len(),
        });
    }
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(ResearchToolCatalogError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    Ok(())
}

fn validate_upstream_ref(value: &str) -> Result<(), ResearchToolCatalogError> {
    validate_token("upstream_ref", value)?;
    if !value.starts_with("artifact:falsifiers/graph_filter_visibility_release_blocker_card/")
        || !value.contains("/result.json#F-GraphFilterVisibility-ReleaseBlockerCard")
    {
        return Err(ResearchToolCatalogError::BadUpstreamRef);
    }
    Ok(())
}

fn validate_family_source_ref(value: &str) -> Result<(), ResearchToolCatalogError> {
    validate_token("family_source_ref", value)?;
    if !value.starts_with("artifact:falsifiers/release_audit_failure_family_source_card/")
        || !value.contains("/result.json#research_tool_catalog")
    {
        return Err(ResearchToolCatalogError::BadFamilySourceRef);
    }
    Ok(())
}

fn validate_token(field: &'static str, value: &str) -> Result<(), ResearchToolCatalogError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(ResearchToolCatalogError::InvalidToken {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_text(field: &'static str, value: &str) -> Result<(), ResearchToolCatalogError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(ResearchToolCatalogError::InvalidText {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

// UAS: uas:research-tool-catalog-no-hidden-authority:error
// Plane: Verification.
// Residency: fail-closed metadata validation errors.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ResearchToolCatalogError {
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

impl fmt::Display for ResearchToolCatalogError {
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
            Self::BadUpstreamRef => write!(f, "bad graph-filter blocker ref"),
            Self::BadFamilySourceRef => write!(f, "bad research-tool family source ref"),
            Self::UpstreamNotPassed => write!(f, "upstream graph-filter blocker did not pass"),
            Self::WrongUpstreamCursor(cursor) => write!(f, "wrong upstream cursor: {cursor}"),
            Self::WrongFamily(family) => write!(f, "wrong release-audit family: {family}"),
            Self::ZeroIssueCount => write!(f, "research-tool issue count is zero"),
            Self::CardHeaderBroken => write!(f, "research-tool card header is broken"),
            Self::BadFocusedCommand => write!(f, "focused command is outside EpistemosTests"),
            Self::PromotionBoundaryBroken => {
                write!(f, "research-tool promotion boundary is broken")
            }
            Self::WitnessHeaderBroken => write!(f, "research-tool witness header is broken"),
            Self::WitnessDigestMismatch => write!(f, "research-tool witness digest mismatch"),
        }
    }
}

impl std::error::Error for ResearchToolCatalogError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_research_tool_catalog_blocker() {
        let witness = ResearchToolCatalogNoHiddenAuthorityWitness::new(
            RESEARCH_TOOL_CATALOG_UPSTREAM_REF,
            RESEARCH_TOOL_CATALOG_FAMILY_SOURCE_REF,
            true,
            RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_CURSOR,
            "research_tool_catalog",
            16,
        )
        .expect("valid research-tool blocker");
        witness.validate().expect("witness validates");
        assert_eq!(witness.metrics.source_ref_count, REQUIRED_SOURCE_REFS.len());
        assert_eq!(witness.metrics.invariant_count, REQUIRED_INVARIANTS.len());
        assert_eq!(witness.card.model_runtime_bytes_loaded, 0);
        assert_eq!(witness.card.provider_calls_made, 0);
    }

    #[test]
    fn rejects_wrong_upstream_or_family() {
        assert!(ResearchToolCatalogNoHiddenAuthorityWitness::new(
            RESEARCH_TOOL_CATALOG_UPSTREAM_REF,
            RESEARCH_TOOL_CATALOG_FAMILY_SOURCE_REF,
            false,
            RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_CURSOR,
            "research_tool_catalog",
            16,
        )
        .is_err());
        assert!(ResearchToolCatalogNoHiddenAuthorityWitness::new(
            RESEARCH_TOOL_CATALOG_UPSTREAM_REF,
            RESEARCH_TOOL_CATALOG_FAMILY_SOURCE_REF,
            true,
            "other_cursor",
            "research_tool_catalog",
            16,
        )
        .is_err());
        assert!(ResearchToolCatalogNoHiddenAuthorityWitness::new(
            RESEARCH_TOOL_CATALOG_UPSTREAM_REF,
            RESEARCH_TOOL_CATALOG_FAMILY_SOURCE_REF,
            true,
            RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_CURSOR,
            "graph_filter_visibility",
            34,
        )
        .is_err());
    }

    #[test]
    fn rejects_hidden_authority_and_promotion() {
        let witness = ResearchToolCatalogNoHiddenAuthorityWitness::new(
            RESEARCH_TOOL_CATALOG_UPSTREAM_REF,
            RESEARCH_TOOL_CATALOG_FAMILY_SOURCE_REF,
            true,
            RESEARCH_TOOL_CATALOG_NO_HIDDEN_AUTHORITY_CURSOR,
            "research_tool_catalog",
            16,
        )
        .expect("valid research-tool blocker");
        let mut missing_source = witness.card.clone();
        missing_source
            .source_refs
            .retain(|value| value != "Epistemos/Omega/MCPBridge.swift");
        assert!(missing_source.validate().is_err());

        let mut hidden = witness.card.clone();
        hidden.hidden_research_tool_authority = true;
        assert!(hidden.validate().is_err());

        let mut promoted = witness.card.clone();
        promoted.product_green_claimed = true;
        assert!(promoted.validate().is_err());
    }
}
