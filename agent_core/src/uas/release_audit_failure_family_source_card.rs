use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};
use std::fmt;

pub const RELEASE_AUDIT_FAILURE_FAMILY_SOURCE_CARD_ID: &str =
    "F-ReleaseAuditFailureFamily-SourceCard";
pub const RELEASE_AUDIT_FAILURE_FAMILY_SOURCE_CARD_CURSOR: &str =
    "release_audit_failure_family_source_card";
pub const RELEASE_AUDIT_FAILURE_FAMILY_SOURCE_CARD_NEXT_CURSOR: &str =
    "model_vault_catalog_release_blocker_card";
pub const RELEASE_AUDIT_AUTOMATED_CHECKS_UPSTREAM_REF: &str =
    "artifact:falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe/result.json#F-SmallModelRuntimeHarnessFreshProductRuntimeL3ReleaseAuditAutomatedChecksProbe";

const REQUIRED_FAMILIES: [&str; 15] = [
    "agent_route_policy",
    "body_read_checksum",
    "distribution_project_integrity",
    "editor_epdoc_surface",
    "graph_filter_visibility",
    "model_vault_catalog",
    "research_tool_catalog",
    "runtime_performance_policy",
    "search_index",
    "source_guard_drift",
    "theme_presentation",
    "tool_execution_surface",
    "ui_shell_source_guard",
    "visible_output_sanitization",
    "xpc_trust_configuration",
];

// UAS: uas:release-audit-failure-family-source-card:organ
// Plane: State + Controller + Verification
// Residency: family-to-organ source card only; no product route changes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ReleaseAuditFailureFamilyOrgan {
    EidosGraphVisibility,
    RuntimeRouterPolicy,
    ThemePresentation,
    DistributionIntegrity,
    ResearchToolCatalog,
    EditorSurface,
    UiShellSourceGuard,
    ModelVaultCatalog,
    AnswerPacketSanitization,
    RuntimePerformancePolicy,
    SearchIndex,
    SourceGuardDrift,
    ToolExecutionSurface,
    XpcTrust,
    BodyReadChecksum,
}

// UAS: uas:release-audit-failure-family-source-card:status
// Plane: Verification
// Residency: blocker classification for retained red xcode evidence.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ReleaseAuditFailureFamilyStatus {
    RedRetainedLog,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:release-audit-failure-family-source-card:card
// Plane: Controller + Verification
// Residency: typed blocker card generated from retained release-audit logs.
pub struct ReleaseAuditFailureFamilySourceCard {
    pub family_id: String,
    pub issue_count: u64,
    pub organ: ReleaseAuditFailureFamilyOrgan,
    pub status: ReleaseAuditFailureFamilyStatus,
    pub source_refs: Vec<String>,
    pub focused_commands: Vec<String>,
    pub falsifier_backlog: String,
    pub promotion_blocker: bool,
    pub product_green_claimed: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub live_70b_claimed: bool,
    pub hidden_authority_claimed: bool,
    pub model_runtime_bytes_loaded: u64,
}

impl ReleaseAuditFailureFamilySourceCard {
    pub fn new(family_id: &str, issue_count: u64) -> Result<Self, ReleaseAuditFailureFamilyError> {
        let spec = family_spec(family_id)
            .ok_or_else(|| ReleaseAuditFailureFamilyError::UnknownFamily(family_id.to_string()))?;
        Ok(Self {
            family_id: family_id.to_string(),
            issue_count,
            organ: spec.organ,
            status: ReleaseAuditFailureFamilyStatus::RedRetainedLog,
            source_refs: spec
                .source_refs
                .iter()
                .map(|value| value.to_string())
                .collect(),
            focused_commands: spec
                .focused_commands
                .iter()
                .map(|value| value.to_string())
                .collect(),
            falsifier_backlog: spec.falsifier_backlog.to_string(),
            promotion_blocker: true,
            product_green_claimed: false,
            l2_green_claimed: false,
            l3_green_claimed: false,
            live_70b_claimed: false,
            hidden_authority_claimed: false,
            model_runtime_bytes_loaded: 0,
        })
    }

    pub fn validate(&self) -> Result<(), ReleaseAuditFailureFamilyError> {
        validate_token("family_id", &self.family_id)?;
        let spec = family_spec(&self.family_id)
            .ok_or_else(|| ReleaseAuditFailureFamilyError::UnknownFamily(self.family_id.clone()))?;
        if self.issue_count == 0 {
            return Err(ReleaseAuditFailureFamilyError::ZeroIssueFamily(
                self.family_id.clone(),
            ));
        }
        if self.organ != spec.organ
            || self.status != ReleaseAuditFailureFamilyStatus::RedRetainedLog
            || self.falsifier_backlog != spec.falsifier_backlog
        {
            return Err(ReleaseAuditFailureFamilyError::FamilySpecMismatch(
                self.family_id.clone(),
            ));
        }
        validate_list("source_refs", &self.source_refs, 1, 8)?;
        validate_list("focused_commands", &self.focused_commands, 1, 8)?;
        if !self.promotion_blocker
            || self.product_green_claimed
            || self.l2_green_claimed
            || self.l3_green_claimed
            || self.live_70b_claimed
            || self.hidden_authority_claimed
            || self.model_runtime_bytes_loaded != 0
        {
            return Err(ReleaseAuditFailureFamilyError::PromotionBoundaryBroken(
                self.family_id.clone(),
            ));
        }
        Ok(())
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:release-audit-failure-family-source-card:metrics
// Plane: Verification
// Residency: aggregate retained-log source-card metrics.
pub struct ReleaseAuditFailureFamilyMetrics {
    pub family_count: usize,
    pub total_issue_count: u64,
    pub top_family_id: String,
    pub top_family_issue_count: u64,
    pub promotion_blocker_count: usize,
    pub model_runtime_bytes_loaded: u64,
    pub source_ref_count: usize,
    pub focused_command_count: usize,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:release-audit-failure-family-source-card:witness
// Plane: Verification
// Residency: metadata-only source-card witness from retained red logs.
pub struct ReleaseAuditFailureFamilySourceCardWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_failed_check_count: u64,
    pub upstream_unique_failure_count: u64,
    pub cards: Vec<ReleaseAuditFailureFamilySourceCard>,
    pub metrics: ReleaseAuditFailureFamilyMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl ReleaseAuditFailureFamilySourceCardWitness {
    pub fn new(
        upstream_ref: &str,
        upstream_overall_pass: bool,
        upstream_failed_check_count: u64,
        upstream_unique_failure_count: u64,
        family_counts: &BTreeMap<String, u64>,
    ) -> Result<Self, ReleaseAuditFailureFamilyError> {
        validate_artifact_ref(upstream_ref)?;
        if upstream_overall_pass
            || upstream_failed_check_count == 0
            || upstream_unique_failure_count == 0
        {
            return Err(ReleaseAuditFailureFamilyError::UpstreamNotRed);
        }
        let mut cards = Vec::with_capacity(REQUIRED_FAMILIES.len());
        for family in REQUIRED_FAMILIES {
            let count = family_counts
                .get(family)
                .copied()
                .ok_or_else(|| ReleaseAuditFailureFamilyError::MissingRequiredFamily(family))?;
            cards.push(ReleaseAuditFailureFamilySourceCard::new(family, count)?);
        }
        cards.sort_by(|left, right| left.family_id.cmp(&right.family_id));
        let mut seen = BTreeSet::new();
        for card in &cards {
            card.validate()?;
            if !seen.insert(card.family_id.as_str()) {
                return Err(ReleaseAuditFailureFamilyError::DuplicateFamily(
                    card.family_id.clone(),
                ));
            }
        }
        if family_counts.len() != REQUIRED_FAMILIES.len() {
            return Err(ReleaseAuditFailureFamilyError::UnexpectedFamilyCount {
                actual: family_counts.len(),
                expected: REQUIRED_FAMILIES.len(),
            });
        }
        let metrics = metrics_for_cards(&cards)?;
        let address = source_card_address(
            upstream_ref,
            upstream_overall_pass,
            upstream_failed_check_count,
            upstream_unique_failure_count,
            &cards,
            &metrics,
        );
        Ok(Self {
            falsifier_id: RELEASE_AUDIT_FAILURE_FAMILY_SOURCE_CARD_ID.to_string(),
            cursor: RELEASE_AUDIT_FAILURE_FAMILY_SOURCE_CARD_CURSOR.to_string(),
            next_cursor: RELEASE_AUDIT_FAILURE_FAMILY_SOURCE_CARD_NEXT_CURSOR.to_string(),
            upstream_ref: upstream_ref.to_string(),
            upstream_overall_pass,
            upstream_failed_check_count,
            upstream_unique_failure_count,
            cards,
            metrics,
            address,
            metadata_only: true,
            no_product_promotion: true,
        })
    }

    pub fn validate(&self) -> Result<(), ReleaseAuditFailureFamilyError> {
        if self.falsifier_id != RELEASE_AUDIT_FAILURE_FAMILY_SOURCE_CARD_ID
            || self.cursor != RELEASE_AUDIT_FAILURE_FAMILY_SOURCE_CARD_CURSOR
            || self.next_cursor != RELEASE_AUDIT_FAILURE_FAMILY_SOURCE_CARD_NEXT_CURSOR
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(ReleaseAuditFailureFamilyError::WitnessHeaderBroken);
        }
        let family_counts = self
            .cards
            .iter()
            .map(|card| (card.family_id.clone(), card.issue_count))
            .collect::<BTreeMap<_, _>>();
        let rebuilt = Self::new(
            &self.upstream_ref,
            self.upstream_overall_pass,
            self.upstream_failed_check_count,
            self.upstream_unique_failure_count,
            &family_counts,
        )?;
        if rebuilt.address != self.address || rebuilt.metrics != self.metrics {
            return Err(ReleaseAuditFailureFamilyError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_release_audit_failure_families() -> &'static [&'static str] {
    &REQUIRED_FAMILIES
}

fn metrics_for_cards(
    cards: &[ReleaseAuditFailureFamilySourceCard],
) -> Result<ReleaseAuditFailureFamilyMetrics, ReleaseAuditFailureFamilyError> {
    let top = cards
        .iter()
        .max_by_key(|card| card.issue_count)
        .ok_or(ReleaseAuditFailureFamilyError::EmptyFamilySet)?;
    Ok(ReleaseAuditFailureFamilyMetrics {
        family_count: cards.len(),
        total_issue_count: cards.iter().map(|card| card.issue_count).sum(),
        top_family_id: top.family_id.clone(),
        top_family_issue_count: top.issue_count,
        promotion_blocker_count: cards.iter().filter(|card| card.promotion_blocker).count(),
        model_runtime_bytes_loaded: cards
            .iter()
            .map(|card| card.model_runtime_bytes_loaded)
            .sum(),
        source_ref_count: cards.iter().map(|card| card.source_refs.len()).sum(),
        focused_command_count: cards.iter().map(|card| card.focused_commands.len()).sum(),
    })
}

fn source_card_address(
    upstream_ref: &str,
    upstream_overall_pass: bool,
    upstream_failed_check_count: u64,
    upstream_unique_failure_count: u64,
    cards: &[ReleaseAuditFailureFamilySourceCard],
    metrics: &ReleaseAuditFailureFamilyMetrics,
) -> String {
    let mut preimage = String::new();
    preimage.push_str(RELEASE_AUDIT_FAILURE_FAMILY_SOURCE_CARD_ID);
    preimage.push_str(RELEASE_AUDIT_FAILURE_FAMILY_SOURCE_CARD_CURSOR);
    preimage.push_str(RELEASE_AUDIT_FAILURE_FAMILY_SOURCE_CARD_NEXT_CURSOR);
    preimage.push_str(upstream_ref);
    preimage.push_str(&upstream_overall_pass.to_string());
    preimage.push_str(&upstream_failed_check_count.to_string());
    preimage.push_str(&upstream_unique_failure_count.to_string());
    for card in cards {
        preimage.push_str(&card.family_id);
        preimage.push_str(&card.issue_count.to_string());
        preimage.push_str(&format!("{:?}", card.organ));
        preimage.push_str(&card.falsifier_backlog);
    }
    preimage.push_str(&format!("{metrics:?}"));
    sha256_hex(preimage.as_bytes())
}

// UAS: release-audit failure-family source-card static repair spec.
// Plane: Verification.
// Residency: metadata-only; no model, runtime, product, or log bytes.
struct ReleaseAuditFailureFamilySpec {
    organ: ReleaseAuditFailureFamilyOrgan,
    source_refs: &'static [&'static str],
    focused_commands: &'static [&'static str],
    falsifier_backlog: &'static str,
}

fn family_spec(family_id: &str) -> Option<ReleaseAuditFailureFamilySpec> {
    let spec = match family_id {
        "agent_route_policy" => ReleaseAuditFailureFamilySpec {
            organ: ReleaseAuditFailureFamilyOrgan::RuntimeRouterPolicy,
            source_refs: &["Epistemos/Engine", "EpistemosTests/AgentCommandCenterStateTests.swift"],
            focused_commands: &["xcodebuild test -only-testing:EpistemosTests/AgentCommandCenterStateTests"],
            falsifier_backlog: "F-AgentRoutePolicy-LargeModelNoHiddenAuthority",
        },
        "body_read_checksum" => ReleaseAuditFailureFamilySpec {
            organ: ReleaseAuditFailureFamilyOrgan::BodyReadChecksum,
            source_refs: &["Epistemos/Models", "EpistemosTests"],
            focused_commands: &["xcodebuild test -only-testing:EpistemosTests"],
            falsifier_backlog: "F-BodyReadChecksum-ReleaseBlockerCard",
        },
        "distribution_project_integrity" => ReleaseAuditFailureFamilySpec {
            organ: ReleaseAuditFailureFamilyOrgan::DistributionIntegrity,
            source_refs: &["Epistemos.xcodeproj", "docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md"],
            focused_commands: &["xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build"],
            falsifier_backlog: "F-DistributionProjectIntegrity-ReleaseBlockerCard",
        },
        "editor_epdoc_surface" => ReleaseAuditFailureFamilySpec {
            organ: ReleaseAuditFailureFamilyOrgan::EditorSurface,
            source_refs: &["Epistemos/Views/Notes", "EpistemosTests"],
            focused_commands: &["xcodebuild test -only-testing:EpistemosTests"],
            falsifier_backlog: "F-EditorEpdocSurface-ReleaseBlockerCard",
        },
        "graph_filter_visibility" => ReleaseAuditFailureFamilySpec {
            organ: ReleaseAuditFailureFamilyOrgan::EidosGraphVisibility,
            source_refs: &["Epistemos/Graph", "EpistemosTests/FilterEngineComprehensiveTests.swift"],
            focused_commands: &[
                "xcodebuild test -only-testing:EpistemosTests/FilterEngineComprehensiveTests",
                "xcodebuild test -only-testing:EpistemosTests/ResourceExhaustionTests",
            ],
            falsifier_backlog: "F-GraphFilterVisibility-ReleaseBlockerCard",
        },
        "model_vault_catalog" => ReleaseAuditFailureFamilySpec {
            organ: ReleaseAuditFailureFamilyOrgan::ModelVaultCatalog,
            source_refs: &["Epistemos/Engine", "docs/fusion/TURBOVEC_QAT_RUNTIME_AGNOSTIC_INTAKE_2026_06_06.md"],
            focused_commands: &["xcodebuild test -only-testing:EpistemosTests"],
            falsifier_backlog: "F-ModelVaultCatalog-ReleaseBlockerCard",
        },
        "research_tool_catalog" => ReleaseAuditFailureFamilySpec {
            organ: ReleaseAuditFailureFamilyOrgan::ResearchToolCatalog,
            source_refs: &["Epistemos/Engine", "agent_core/src"],
            focused_commands: &["xcodebuild test -only-testing:EpistemosTests"],
            falsifier_backlog: "F-ResearchToolCatalog-NoHiddenAuthority",
        },
        "runtime_performance_policy" => ReleaseAuditFailureFamilySpec {
            organ: ReleaseAuditFailureFamilyOrgan::RuntimePerformancePolicy,
            source_refs: &["Epistemos/Engine", "benchmarks/results"],
            focused_commands: &["xcodebuild test -only-testing:EpistemosTests"],
            falsifier_backlog: "F-RuntimePerformancePolicy-ReleaseBlockerCard",
        },
        "search_index" => ReleaseAuditFailureFamilySpec {
            organ: ReleaseAuditFailureFamilyOrgan::SearchIndex,
            source_refs: &["Epistemos/Graph", "Epistemos/Sync"],
            focused_commands: &["xcodebuild test -only-testing:EpistemosTests"],
            falsifier_backlog: "F-SearchIndex-ReleaseBlockerCard",
        },
        "source_guard_drift" => ReleaseAuditFailureFamilySpec {
            organ: ReleaseAuditFailureFamilyOrgan::SourceGuardDrift,
            source_refs: &["EpistemosTests", "docs"],
            focused_commands: &["xcodebuild test -only-testing:EpistemosTests"],
            falsifier_backlog: "F-SourceGuardDrift-ReleaseBlockerCard",
        },
        "theme_presentation" => ReleaseAuditFailureFamilySpec {
            organ: ReleaseAuditFailureFamilyOrgan::ThemePresentation,
            source_refs: &["Epistemos/Theme", "EpistemosTests"],
            focused_commands: &["xcodebuild test -only-testing:EpistemosTests"],
            falsifier_backlog: "F-ThemePresentation-ReleaseBlockerCard",
        },
        "tool_execution_surface" => ReleaseAuditFailureFamilySpec {
            organ: ReleaseAuditFailureFamilyOrgan::ToolExecutionSurface,
            source_refs: &["Epistemos/Engine", "agent_core/src"],
            focused_commands: &["xcodebuild test -only-testing:EpistemosTests"],
            falsifier_backlog: "F-ToolExecutionSurface-ReleaseBlockerCard",
        },
        "ui_shell_source_guard" => ReleaseAuditFailureFamilySpec {
            organ: ReleaseAuditFailureFamilyOrgan::UiShellSourceGuard,
            source_refs: &["Epistemos/Views/Shell", "EpistemosTests"],
            focused_commands: &["xcodebuild test -only-testing:EpistemosTests"],
            falsifier_backlog: "F-UiShellSourceGuard-ReleaseBlockerCard",
        },
        "visible_output_sanitization" => ReleaseAuditFailureFamilySpec {
            organ: ReleaseAuditFailureFamilyOrgan::AnswerPacketSanitization,
            source_refs: &["Epistemos/Engine", "EpistemosTests/UserFacingModelOutputTests.swift"],
            focused_commands: &["xcodebuild test -only-testing:EpistemosTests/UserFacingModelOutputTests"],
            falsifier_backlog: "F-VisibleOutputSanitization-ReleaseBlockerCard",
        },
        "xpc_trust_configuration" => ReleaseAuditFailureFamilySpec {
            organ: ReleaseAuditFailureFamilyOrgan::XpcTrust,
            source_refs: &["Epistemos/XPC", "EpistemosTests/XPCSmokeTests.swift"],
            focused_commands: &["xcodebuild test -only-testing:EpistemosTests/XPCSmokeTests"],
            falsifier_backlog: "F-XpcTrustConfiguration-ReleaseBlockerCard",
        },
        _ => return None,
    };
    Some(spec)
}

fn validate_list(
    field: &'static str,
    values: &[String],
    min: usize,
    max: usize,
) -> Result<(), ReleaseAuditFailureFamilyError> {
    if values.len() < min || values.len() > max {
        return Err(ReleaseAuditFailureFamilyError::BadListLength {
            field,
            actual: values.len(),
        });
    }
    for value in values {
        validate_text(field, value)?;
    }
    Ok(())
}

fn validate_artifact_ref(value: &str) -> Result<(), ReleaseAuditFailureFamilyError> {
    validate_token("upstream_ref", value)?;
    if !value.starts_with("artifact:falsifiers/")
        || !value.contains(
            "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe",
        )
        || !value.contains("/result.json#")
    {
        return Err(ReleaseAuditFailureFamilyError::BadUpstreamRef);
    }
    Ok(())
}

fn validate_token(field: &'static str, value: &str) -> Result<(), ReleaseAuditFailureFamilyError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(ReleaseAuditFailureFamilyError::InvalidToken {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_text(field: &'static str, value: &str) -> Result<(), ReleaseAuditFailureFamilyError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(ReleaseAuditFailureFamilyError::InvalidText {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:release-audit-failure-family-source-card:error
// Plane: Verification
// Residency: fail-closed metadata validation errors.
pub enum ReleaseAuditFailureFamilyError {
    InvalidToken { field: &'static str, value: String },
    InvalidText { field: &'static str, value: String },
    BadListLength { field: &'static str, actual: usize },
    BadUpstreamRef,
    UpstreamNotRed,
    EmptyFamilySet,
    UnknownFamily(String),
    MissingRequiredFamily(&'static str),
    UnexpectedFamilyCount { actual: usize, expected: usize },
    DuplicateFamily(String),
    ZeroIssueFamily(String),
    FamilySpecMismatch(String),
    PromotionBoundaryBroken(String),
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for ReleaseAuditFailureFamilyError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidToken { field, value } => write!(f, "invalid token {field}: {value}"),
            Self::InvalidText { field, value } => write!(f, "invalid text {field}: {value}"),
            Self::BadListLength { field, actual } => {
                write!(f, "bad list length for {field}: {actual}")
            }
            Self::BadUpstreamRef => write!(f, "bad upstream ref"),
            Self::UpstreamNotRed => write!(f, "upstream automated-check ledger is not red"),
            Self::EmptyFamilySet => write!(f, "empty family set"),
            Self::UnknownFamily(family) => write!(f, "unknown family {family}"),
            Self::MissingRequiredFamily(family) => write!(f, "missing required family {family}"),
            Self::UnexpectedFamilyCount { actual, expected } => {
                write!(f, "unexpected family count {actual}; expected {expected}")
            }
            Self::DuplicateFamily(family) => write!(f, "duplicate family {family}"),
            Self::ZeroIssueFamily(family) => write!(f, "zero issue family {family}"),
            Self::FamilySpecMismatch(family) => write!(f, "family spec mismatch {family}"),
            Self::PromotionBoundaryBroken(family) => {
                write!(f, "promotion boundary broken for {family}")
            }
            Self::WitnessHeaderBroken => write!(f, "witness header broken"),
            Self::WitnessDigestMismatch => write!(f, "witness digest mismatch"),
        }
    }
}

impl std::error::Error for ReleaseAuditFailureFamilyError {}

#[cfg(test)]
mod tests {
    use super::*;

    fn family_counts() -> BTreeMap<String, u64> {
        REQUIRED_FAMILIES
            .iter()
            .enumerate()
            .map(|(index, family)| ((*family).to_string(), (index as u64) + 1))
            .collect()
    }

    #[test]
    fn accepts_red_retained_log_family_source_cards() {
        let witness = ReleaseAuditFailureFamilySourceCardWitness::new(
            RELEASE_AUDIT_AUTOMATED_CHECKS_UPSTREAM_REF,
            false,
            1,
            84,
            &family_counts(),
        )
        .expect("valid source-card witness");
        witness.validate().expect("witness validates");
        assert_eq!(witness.metrics.family_count, REQUIRED_FAMILIES.len());
        assert_eq!(witness.metrics.model_runtime_bytes_loaded, 0);
        assert!(witness.no_product_promotion);
    }

    #[test]
    fn rejects_green_upstream_or_missing_family() {
        assert_eq!(
            ReleaseAuditFailureFamilySourceCardWitness::new(
                RELEASE_AUDIT_AUTOMATED_CHECKS_UPSTREAM_REF,
                true,
                0,
                0,
                &family_counts(),
            )
            .err(),
            Some(ReleaseAuditFailureFamilyError::UpstreamNotRed)
        );

        let mut counts = family_counts();
        counts.remove("graph_filter_visibility");
        assert_eq!(
            ReleaseAuditFailureFamilySourceCardWitness::new(
                RELEASE_AUDIT_AUTOMATED_CHECKS_UPSTREAM_REF,
                false,
                1,
                84,
                &counts,
            )
            .err(),
            Some(ReleaseAuditFailureFamilyError::MissingRequiredFamily(
                "graph_filter_visibility"
            ))
        );
    }

    #[test]
    fn rejects_promotion_or_runtime_byte_leaks() {
        let witness = ReleaseAuditFailureFamilySourceCardWitness::new(
            RELEASE_AUDIT_AUTOMATED_CHECKS_UPSTREAM_REF,
            false,
            1,
            84,
            &family_counts(),
        )
        .expect("valid source-card witness");
        let mut counts = BTreeMap::new();
        for card in &witness.cards {
            counts.insert(card.family_id.clone(), card.issue_count);
        }
        let mut rebuilt = ReleaseAuditFailureFamilySourceCardWitness::new(
            RELEASE_AUDIT_AUTOMATED_CHECKS_UPSTREAM_REF,
            false,
            1,
            84,
            &counts,
        )
        .expect("valid source-card witness");
        rebuilt.cards[0].l3_green_claimed = true;
        assert!(matches!(
            rebuilt.cards[0].validate(),
            Err(ReleaseAuditFailureFamilyError::PromotionBoundaryBroken(_))
        ));
        rebuilt.cards[0].l3_green_claimed = false;
        rebuilt.cards[0].model_runtime_bytes_loaded = 1;
        assert!(matches!(
            rebuilt.cards[0].validate(),
            Err(ReleaseAuditFailureFamilyError::PromotionBoundaryBroken(_))
        ));
    }
}
