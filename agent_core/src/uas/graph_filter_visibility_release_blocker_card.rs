use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

pub const GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_ID: &str =
    "F-GraphFilterVisibility-ReleaseBlockerCard";
pub const GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_CURSOR: &str =
    "graph_filter_visibility_release_blocker_card";
pub const GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_NEXT_CURSOR: &str =
    "research_tool_catalog_no_hidden_authority";
pub const GRAPH_FILTER_VISIBILITY_UPSTREAM_REF: &str = "artifact:falsifiers/visible_output_sanitization_release_blocker_card/result.json#F-VisibleOutputSanitization-ReleaseBlockerCard";
pub const GRAPH_FILTER_VISIBILITY_FAMILY_SOURCE_REF: &str = "artifact:falsifiers/release_audit_failure_family_source_card/result.json#graph_filter_visibility";

const REQUIRED_SOURCE_REFS: [&str; 9] = [
    "Epistemos/Graph/FilterEngine.swift",
    "Epistemos/Models/GraphTypes.swift",
    "Epistemos/Graph/GraphState.swift",
    "Epistemos/Graph/GraphStore.swift",
    "Epistemos/Views/Graph/MetalGraphView.swift",
    "Epistemos/Views/Graph/HologramSearchSidebar.swift",
    "EpistemosTests/FilterEngineComprehensiveTests.swift",
    "EpistemosTests/ResourceExhaustionTests.swift",
    "EpistemosTests/ConcurrencyEdgeCaseTests.swift",
];

const REQUIRED_INVARIANTS: [&str; 12] = [
    "default_active_cases_are_single_source_of_truth",
    "folder_nodes_remain_opt_in_default",
    "visible_cases_include_app_level_artifacts_without_ffi_promotion",
    "ffi_graph_node_type_contract_stays_fourteen_cases",
    "app_level_graph_types_never_bridge_to_rust_ffi",
    "search_filter_participates_in_node_visibility",
    "focus_filter_participates_in_node_visibility",
    "vault_filter_is_visible_and_lenient_for_missing_origin",
    "edge_visibility_requires_visible_endpoints_and_active_edge_type",
    "filter_snapshot_binds_visible_state_for_background_payloads",
    "graph_filter_repairs_required_before_eidos_evidence_navigation_green",
    "release_audit_family_remains_red_until_focused_tests_pass",
];

// UAS: uas:graph-filter-visibility-release-blocker-card:organ
// Plane: Verification.
// Residency: metadata-only graph/Eidos visibility classification.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GraphFilterVisibilityOrgan {
    EidosGraphVisibility,
    FilterEngine,
    GraphTypes,
    GraphState,
    AnswerPacketEvidenceNavigation,
}

// UAS: uas:graph-filter-visibility-release-blocker-card:status
// Plane: Verification.
// Residency: retained release blocker classification only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GraphFilterVisibilityStatus {
    RedReleaseBlocker,
}

// UAS: uas:graph-filter-visibility-release-blocker-card:card
// Plane: Verification.
// Residency: metadata-only source-card blocker; no graph/model/runtime bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GraphFilterVisibilityReleaseBlockerCard {
    pub family_id: String,
    pub issue_count: u64,
    pub organ: GraphFilterVisibilityOrgan,
    pub status: GraphFilterVisibilityStatus,
    pub source_refs: Vec<String>,
    pub focused_commands: Vec<String>,
    pub required_invariants: Vec<String>,
    pub mas_status: String,
    pub pro_status: String,
    pub graph_filter_as_eidos_route_authority: bool,
    pub hidden_graph_filter_authority: bool,
    pub ffi_app_level_type_promoted: bool,
    pub folder_default_on_claimed: bool,
    pub search_filter_bypass_claimed: bool,
    pub focus_filter_bypass_claimed: bool,
    pub edge_visibility_endpoint_bypass_claimed: bool,
    pub graph_release_family_green_claimed: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub product_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub model_runtime_bytes_loaded: u64,
    pub graph_runtime_bytes_loaded: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
}

impl GraphFilterVisibilityReleaseBlockerCard {
    pub fn from_family(
        family_id: &str,
        issue_count: u64,
    ) -> Result<Self, GraphFilterVisibilityError> {
        validate_token("family_id", family_id)?;
        if family_id != "graph_filter_visibility" {
            return Err(GraphFilterVisibilityError::WrongFamily(
                family_id.to_string(),
            ));
        }
        if issue_count == 0 {
            return Err(GraphFilterVisibilityError::ZeroIssueCount);
        }
        Ok(Self {
            family_id: family_id.to_string(),
            issue_count,
            organ: GraphFilterVisibilityOrgan::EidosGraphVisibility,
            status: GraphFilterVisibilityStatus::RedReleaseBlocker,
            source_refs: REQUIRED_SOURCE_REFS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            focused_commands: vec![
                "xcodebuild test -only-testing:EpistemosTests/FilterEngineComprehensiveTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/ResourceExhaustionTests".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/ConcurrencyEdgeCaseTests".to_string(),
            ],
            required_invariants: REQUIRED_INVARIANTS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            mas_status: "red_release_blocker".to_string(),
            pro_status: "gated_release_blocker".to_string(),
            graph_filter_as_eidos_route_authority: false,
            hidden_graph_filter_authority: false,
            ffi_app_level_type_promoted: false,
            folder_default_on_claimed: false,
            search_filter_bypass_claimed: false,
            focus_filter_bypass_claimed: false,
            edge_visibility_endpoint_bypass_claimed: false,
            graph_release_family_green_claimed: false,
            hidden_route_authority: false,
            hidden_cloud_fallback: false,
            l2_green_claimed: false,
            l3_green_claimed: false,
            product_green_claimed: false,
            live_dense_70b_claimed: false,
            model_runtime_bytes_loaded: 0,
            graph_runtime_bytes_loaded: 0,
            rollback_ref: "rollback:graph_filter_visibility_release_blocker".to_string(),
            run_event_log_ref: "run_event_log:graph_filter_visibility_release_blocker".to_string(),
            answer_packet_ref: "answer_packet:graph_filter_visibility_release_blocker".to_string(),
        })
    }

    pub fn validate(&self) -> Result<(), GraphFilterVisibilityError> {
        validate_token("family_id", &self.family_id)?;
        if self.family_id != "graph_filter_visibility"
            || self.issue_count == 0
            || self.organ != GraphFilterVisibilityOrgan::EidosGraphVisibility
            || self.status != GraphFilterVisibilityStatus::RedReleaseBlocker
        {
            return Err(GraphFilterVisibilityError::CardHeaderBroken);
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
                return Err(GraphFilterVisibilityError::BadFocusedCommand);
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
        if self.graph_filter_as_eidos_route_authority
            || self.hidden_graph_filter_authority
            || self.ffi_app_level_type_promoted
            || self.folder_default_on_claimed
            || self.search_filter_bypass_claimed
            || self.focus_filter_bypass_claimed
            || self.edge_visibility_endpoint_bypass_claimed
            || self.graph_release_family_green_claimed
            || self.hidden_route_authority
            || self.hidden_cloud_fallback
            || self.l2_green_claimed
            || self.l3_green_claimed
            || self.product_green_claimed
            || self.live_dense_70b_claimed
            || self.model_runtime_bytes_loaded != 0
            || self.graph_runtime_bytes_loaded != 0
        {
            return Err(GraphFilterVisibilityError::PromotionBoundaryBroken);
        }
        Ok(())
    }
}

// UAS: uas:graph-filter-visibility-release-blocker-card:metrics
// Plane: Verification.
// Residency: aggregate release-blocker metrics only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GraphFilterVisibilityMetrics {
    pub issue_count: u64,
    pub source_ref_count: usize,
    pub focused_command_count: usize,
    pub invariant_count: usize,
    pub model_runtime_bytes_loaded: u64,
    pub graph_runtime_bytes_loaded: u64,
}

// UAS: uas:graph-filter-visibility-release-blocker-card:witness
// Plane: Verification.
// Residency: metadata-only graph/filter visibility witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GraphFilterVisibilityReleaseBlockerWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_ref: String,
    pub family_source_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_next_cursor: String,
    pub card: GraphFilterVisibilityReleaseBlockerCard,
    pub metrics: GraphFilterVisibilityMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl GraphFilterVisibilityReleaseBlockerWitness {
    pub fn new(
        upstream_ref: &str,
        family_source_ref: &str,
        upstream_overall_pass: bool,
        upstream_next_cursor: &str,
        family_id: &str,
        issue_count: u64,
    ) -> Result<Self, GraphFilterVisibilityError> {
        validate_upstream_ref(upstream_ref)?;
        validate_family_source_ref(family_source_ref)?;
        validate_token("upstream_next_cursor", upstream_next_cursor)?;
        if !upstream_overall_pass {
            return Err(GraphFilterVisibilityError::UpstreamNotPassed);
        }
        if upstream_next_cursor != GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_CURSOR {
            return Err(GraphFilterVisibilityError::WrongUpstreamCursor(
                upstream_next_cursor.to_string(),
            ));
        }
        let card = GraphFilterVisibilityReleaseBlockerCard::from_family(family_id, issue_count)?;
        card.validate()?;
        let metrics = GraphFilterVisibilityMetrics {
            issue_count: card.issue_count,
            source_ref_count: card.source_refs.len(),
            focused_command_count: card.focused_commands.len(),
            invariant_count: card.required_invariants.len(),
            model_runtime_bytes_loaded: card.model_runtime_bytes_loaded,
            graph_runtime_bytes_loaded: card.graph_runtime_bytes_loaded,
        };
        let address = graph_filter_visibility_address(
            upstream_ref,
            family_source_ref,
            upstream_overall_pass,
            upstream_next_cursor,
            &card,
            &metrics,
        );
        Ok(Self {
            falsifier_id: GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_ID.to_string(),
            cursor: GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_CURSOR.to_string(),
            next_cursor: GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_NEXT_CURSOR.to_string(),
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

    pub fn validate(&self) -> Result<(), GraphFilterVisibilityError> {
        if self.falsifier_id != GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_ID
            || self.cursor != GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_CURSOR
            || self.next_cursor != GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_NEXT_CURSOR
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(GraphFilterVisibilityError::WitnessHeaderBroken);
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
            return Err(GraphFilterVisibilityError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_graph_filter_visibility_source_refs() -> &'static [&'static str] {
    &REQUIRED_SOURCE_REFS
}

pub fn required_graph_filter_visibility_invariants() -> &'static [&'static str] {
    &REQUIRED_INVARIANTS
}

fn graph_filter_visibility_address(
    upstream_ref: &str,
    family_source_ref: &str,
    upstream_overall_pass: bool,
    upstream_next_cursor: &str,
    card: &GraphFilterVisibilityReleaseBlockerCard,
    metrics: &GraphFilterVisibilityMetrics,
) -> String {
    let mut preimage = String::new();
    preimage.push_str(GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_ID);
    preimage.push_str(GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_CURSOR);
    preimage.push_str(GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_NEXT_CURSOR);
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
) -> Result<(), GraphFilterVisibilityError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(GraphFilterVisibilityError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    let actual = values.iter().map(String::as_str).collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected {
        return Err(GraphFilterVisibilityError::MissingRequiredSet {
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
) -> Result<(), GraphFilterVisibilityError> {
    if values.len() < min || values.len() > max {
        return Err(GraphFilterVisibilityError::BadListLength {
            field,
            actual: values.len(),
        });
    }
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(GraphFilterVisibilityError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    Ok(())
}

fn validate_upstream_ref(value: &str) -> Result<(), GraphFilterVisibilityError> {
    validate_token("upstream_ref", value)?;
    if !value.starts_with("artifact:falsifiers/visible_output_sanitization_release_blocker_card/")
        || !value.contains("/result.json#F-VisibleOutputSanitization-ReleaseBlockerCard")
    {
        return Err(GraphFilterVisibilityError::BadUpstreamRef);
    }
    Ok(())
}

fn validate_family_source_ref(value: &str) -> Result<(), GraphFilterVisibilityError> {
    validate_token("family_source_ref", value)?;
    if !value.starts_with("artifact:falsifiers/release_audit_failure_family_source_card/")
        || !value.contains("/result.json#graph_filter_visibility")
    {
        return Err(GraphFilterVisibilityError::BadFamilySourceRef);
    }
    Ok(())
}

fn validate_token(field: &'static str, value: &str) -> Result<(), GraphFilterVisibilityError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(GraphFilterVisibilityError::InvalidToken {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_text(field: &'static str, value: &str) -> Result<(), GraphFilterVisibilityError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(GraphFilterVisibilityError::InvalidText {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

// UAS: uas:graph-filter-visibility-release-blocker-card:error
// Plane: Verification.
// Residency: fail-closed metadata validation errors.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GraphFilterVisibilityError {
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

impl fmt::Display for GraphFilterVisibilityError {
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
            Self::BadUpstreamRef => write!(f, "bad visible-output blocker ref"),
            Self::BadFamilySourceRef => write!(f, "bad graph-filter family source ref"),
            Self::UpstreamNotPassed => write!(f, "upstream visible-output blocker did not pass"),
            Self::WrongUpstreamCursor(cursor) => write!(f, "wrong upstream cursor: {cursor}"),
            Self::WrongFamily(family) => write!(f, "wrong release-audit family: {family}"),
            Self::ZeroIssueCount => write!(f, "graph-filter issue count is zero"),
            Self::CardHeaderBroken => write!(f, "graph-filter card header is broken"),
            Self::BadFocusedCommand => write!(f, "focused command is outside EpistemosTests"),
            Self::PromotionBoundaryBroken => {
                write!(f, "graph-filter promotion boundary is broken")
            }
            Self::WitnessHeaderBroken => write!(f, "graph-filter witness header is broken"),
            Self::WitnessDigestMismatch => write!(f, "graph-filter witness digest mismatch"),
        }
    }
}

impl std::error::Error for GraphFilterVisibilityError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_graph_filter_visibility_blocker() {
        let witness = GraphFilterVisibilityReleaseBlockerWitness::new(
            GRAPH_FILTER_VISIBILITY_UPSTREAM_REF,
            GRAPH_FILTER_VISIBILITY_FAMILY_SOURCE_REF,
            true,
            GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_CURSOR,
            "graph_filter_visibility",
            34,
        )
        .expect("valid graph-filter blocker");
        witness.validate().expect("witness validates");
        assert_eq!(witness.metrics.source_ref_count, REQUIRED_SOURCE_REFS.len());
        assert_eq!(witness.metrics.invariant_count, REQUIRED_INVARIANTS.len());
        assert_eq!(witness.card.model_runtime_bytes_loaded, 0);
        assert_eq!(witness.card.graph_runtime_bytes_loaded, 0);
    }

    #[test]
    fn rejects_wrong_upstream_or_family() {
        assert!(GraphFilterVisibilityReleaseBlockerWitness::new(
            GRAPH_FILTER_VISIBILITY_UPSTREAM_REF,
            GRAPH_FILTER_VISIBILITY_FAMILY_SOURCE_REF,
            false,
            GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_CURSOR,
            "graph_filter_visibility",
            34,
        )
        .is_err());
        assert!(GraphFilterVisibilityReleaseBlockerWitness::new(
            GRAPH_FILTER_VISIBILITY_UPSTREAM_REF,
            GRAPH_FILTER_VISIBILITY_FAMILY_SOURCE_REF,
            true,
            "other_cursor",
            "graph_filter_visibility",
            34,
        )
        .is_err());
        assert!(GraphFilterVisibilityReleaseBlockerWitness::new(
            GRAPH_FILTER_VISIBILITY_UPSTREAM_REF,
            GRAPH_FILTER_VISIBILITY_FAMILY_SOURCE_REF,
            true,
            GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_CURSOR,
            "visible_output_sanitization",
            5,
        )
        .is_err());
    }

    #[test]
    fn rejects_graph_authority_and_promotion() {
        let witness = GraphFilterVisibilityReleaseBlockerWitness::new(
            GRAPH_FILTER_VISIBILITY_UPSTREAM_REF,
            GRAPH_FILTER_VISIBILITY_FAMILY_SOURCE_REF,
            true,
            GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_CURSOR,
            "graph_filter_visibility",
            34,
        )
        .expect("valid graph-filter blocker");
        let mut missing_source = witness.card.clone();
        missing_source
            .source_refs
            .retain(|value| value != "Epistemos/Graph/FilterEngine.swift");
        assert!(missing_source.validate().is_err());

        let mut authority = witness.card.clone();
        authority.graph_filter_as_eidos_route_authority = true;
        assert!(authority.validate().is_err());

        let mut promoted = witness.card.clone();
        promoted.product_green_claimed = true;
        assert!(promoted.validate().is_err());
    }
}
