use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::error::Error;
use std::fmt;

pub const SOURCE_GUARD_DRIFT_RELEASE_BLOCKER_CARD_ID: &str =
    "F-SourceGuardDrift-ReleaseBlockerCard";
pub const SOURCE_GUARD_DRIFT_RELEASE_BLOCKER_CARD_CURSOR: &str =
    "source_guard_drift_release_blocker_card";
pub const SOURCE_GUARD_DRIFT_RELEASE_BLOCKER_CARD_NEXT_CURSOR: &str =
    "tool_execution_surface_release_blocker_card";
pub const SOURCE_GUARD_DRIFT_UPSTREAM_REF: &str =
    "artifact:falsifiers/search_index_release_blocker_card/result.json#F-SearchIndex-ReleaseBlockerCard";
pub const SOURCE_GUARD_DRIFT_FAMILY_SOURCE_REF: &str =
    "artifact:falsifiers/release_audit_failure_family_source_card/result.json#source_guard_drift";

const REQUIRED_SOURCE_REFS: [&str; 14] = [
    "EpistemosTests/UASDeclarationSourceGuardTests.swift",
    "EpistemosTests/CoreMASBoundarySourceGuardTests.swift",
    "EpistemosTests/BackendRuntimeContractTests.swift",
    "EpistemosTests/LocalModelReleaseSweepTests.swift",
    "EpistemosTests/CloudProviderSetupCardSourceGuardTests.swift",
    "EpistemosTests/ProvenanceConsoleSourceGuardTests.swift",
    "EpistemosTests/HTMLWorkspaceSourceGuardTests.swift",
    "EpistemosTests/BenchmarkHarnessSourceGuardTests.swift",
    "agent_core/tests/runtime_router_policy_source_guard.rs",
    "agent_core/tests/runtime_router_lane_toggle_source_guard.rs",
    "docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md",
    "docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md",
    "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md",
    "docs/fusion/DEEP_RESEARCH_BREAKTHROUGH_SYNTHESIS_2026_06_06.md",
];

const REQUIRED_INVARIANTS: [&str; 16] = [
    "upstream_search_freshness_bound",
    "source_refs_current_sha_bound",
    "docs_code_parity_required",
    "source_guard_tests_named",
    "mas_pro_boundary_no_drift",
    "runtime_route_policy_no_drift",
    "large_model_claim_copy_no_drift",
    "model_catalog_source_card_no_drift",
    "eidos_search_source_identity_required",
    "turbovec_qat_canon_identity_required",
    "answer_packet_visibility_required",
    "no_stale_doc_as_authority",
    "no_hidden_cloud_or_provider_fallback",
    "no_hidden_route_authority",
    "no_product_green_from_source_guard",
    "zero_model_runtime_provider_bytes",
];

// UAS: uas:source-guard-drift-release-blocker-card:organ
// Plane: Verification.
// Residency: metadata-only source identity and canon parity source-card.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SourceGuardDriftOrgan {
    SourceGuard,
    CanonParity,
    MasProBoundary,
    RuntimeRouter,
    LargeModelClaims,
    EidosEvidence,
    AnswerPacket,
}

// UAS: uas:source-guard-drift-release-blocker-card:status
// Plane: Verification.
// Residency: retained release blocker classification only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SourceGuardDriftStatus {
    RedReleaseBlocker,
}

// UAS: uas:source-guard-drift-release-blocker-card:drift-surface
// Plane: State + Verification.
// Residency: source/drift taxonomy; no product or model bytes opened.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SourceGuardDriftSurface {
    SwiftSourceGuardTests,
    RustSourceGuardTests,
    MasProCanonDocs,
    LivingIndex,
    LatticeHtml,
    MasterResearchIndex,
    DeepResearchSynthesis,
}

// UAS: uas:source-guard-drift-release-blocker-card:card
// Plane: Verification.
// Residency: metadata-only source-guard drift card.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceGuardDriftReleaseBlockerCard {
    pub family_id: String,
    pub issue_count: u64,
    pub organ: SourceGuardDriftOrgan,
    pub status: SourceGuardDriftStatus,
    pub source_refs: Vec<String>,
    pub focused_commands: Vec<String>,
    pub required_invariants: Vec<String>,
    pub drift_surfaces: Vec<SourceGuardDriftSurface>,
    pub upstream_search_freshness_required: bool,
    pub source_refs_current_sha_required: bool,
    pub docs_code_parity_required: bool,
    pub source_guard_tests_named: bool,
    pub mas_pro_boundary_no_drift_required: bool,
    pub runtime_route_policy_no_drift_required: bool,
    pub large_model_claim_copy_no_drift_required: bool,
    pub model_catalog_source_card_no_drift_required: bool,
    pub eidos_search_source_identity_required: bool,
    pub turbovec_qat_canon_identity_required: bool,
    pub answer_packet_visibility_required: bool,
    pub stale_doc_as_authority_allowed: bool,
    pub hidden_cloud_or_provider_fallback_allowed: bool,
    pub hidden_route_authority_allowed: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub product_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub source_file_bytes_opened: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
}

impl SourceGuardDriftReleaseBlockerCard {
    pub fn from_family(family_id: &str, issue_count: u64) -> Result<Self, SourceGuardDriftError> {
        validate_token("family_id", family_id)?;
        if family_id != "source_guard_drift" {
            return Err(SourceGuardDriftError::WrongFamily(family_id.to_string()));
        }
        if issue_count == 0 {
            return Err(SourceGuardDriftError::ZeroIssueCount);
        }
        Ok(Self {
            family_id: family_id.to_string(),
            issue_count,
            organ: SourceGuardDriftOrgan::SourceGuard,
            status: SourceGuardDriftStatus::RedReleaseBlocker,
            source_refs: REQUIRED_SOURCE_REFS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            focused_commands: vec![
                "xcodebuild test -only-testing:EpistemosTests/UASDeclarationSourceGuardTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/CoreMASBoundarySourceGuardTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/BackendRuntimeContractTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/LocalModelReleaseSweepTests"
                    .to_string(),
                "cargo test --manifest-path agent_core/Cargo.toml runtime_router_policy_source_guard"
                    .to_string(),
                "cargo test --manifest-path agent_core/Cargo.toml runtime_router_lane_toggle_source_guard"
                    .to_string(),
            ],
            required_invariants: REQUIRED_INVARIANTS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            drift_surfaces: vec![
                SourceGuardDriftSurface::SwiftSourceGuardTests,
                SourceGuardDriftSurface::RustSourceGuardTests,
                SourceGuardDriftSurface::MasProCanonDocs,
                SourceGuardDriftSurface::LivingIndex,
                SourceGuardDriftSurface::LatticeHtml,
                SourceGuardDriftSurface::MasterResearchIndex,
                SourceGuardDriftSurface::DeepResearchSynthesis,
            ],
            upstream_search_freshness_required: true,
            source_refs_current_sha_required: true,
            docs_code_parity_required: true,
            source_guard_tests_named: true,
            mas_pro_boundary_no_drift_required: true,
            runtime_route_policy_no_drift_required: true,
            large_model_claim_copy_no_drift_required: true,
            model_catalog_source_card_no_drift_required: true,
            eidos_search_source_identity_required: true,
            turbovec_qat_canon_identity_required: true,
            answer_packet_visibility_required: true,
            stale_doc_as_authority_allowed: false,
            hidden_cloud_or_provider_fallback_allowed: false,
            hidden_route_authority_allowed: false,
            l2_green_claimed: false,
            l3_green_claimed: false,
            product_green_claimed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
            source_file_bytes_opened: 0,
            model_runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            rollback_ref: "rollback:source_guard_drift_release_blocker_card".to_string(),
            run_event_log_ref: "run_event_log:source_guard_drift_release_blocker_card".to_string(),
            answer_packet_ref: "answer_packet:source_guard_drift_release_blocker_card".to_string(),
        })
    }

    pub fn validate(&self) -> Result<(), SourceGuardDriftError> {
        validate_token("family_id", &self.family_id)?;
        if self.family_id != "source_guard_drift"
            || self.issue_count == 0
            || self.organ != SourceGuardDriftOrgan::SourceGuard
            || self.status != SourceGuardDriftStatus::RedReleaseBlocker
        {
            return Err(SourceGuardDriftError::CardHeaderBroken);
        }
        validate_unique_exact_set("source_refs", &self.source_refs, &REQUIRED_SOURCE_REFS)?;
        validate_unique_exact_set(
            "required_invariants",
            &self.required_invariants,
            &REQUIRED_INVARIANTS,
        )?;
        validate_focused_commands(&self.focused_commands)?;
        validate_exact_enum_set(
            "drift_surfaces",
            &self.drift_surfaces,
            &[
                SourceGuardDriftSurface::SwiftSourceGuardTests,
                SourceGuardDriftSurface::RustSourceGuardTests,
                SourceGuardDriftSurface::MasProCanonDocs,
                SourceGuardDriftSurface::LivingIndex,
                SourceGuardDriftSurface::LatticeHtml,
                SourceGuardDriftSurface::MasterResearchIndex,
                SourceGuardDriftSurface::DeepResearchSynthesis,
            ],
        )?;
        for value in [
            &self.rollback_ref,
            &self.run_event_log_ref,
            &self.answer_packet_ref,
        ] {
            validate_token("proof_ref", value)?;
        }
        if !self.upstream_search_freshness_required
            || !self.source_refs_current_sha_required
            || !self.docs_code_parity_required
            || !self.source_guard_tests_named
            || !self.mas_pro_boundary_no_drift_required
            || !self.runtime_route_policy_no_drift_required
            || !self.large_model_claim_copy_no_drift_required
            || !self.model_catalog_source_card_no_drift_required
            || !self.eidos_search_source_identity_required
            || !self.turbovec_qat_canon_identity_required
            || !self.answer_packet_visibility_required
            || self.stale_doc_as_authority_allowed
            || self.hidden_cloud_or_provider_fallback_allowed
            || self.hidden_route_authority_allowed
            || self.l2_green_claimed
            || self.l3_green_claimed
            || self.product_green_claimed
            || self.live_dense_70b_claimed
            || self.ssd_as_ram_claimed
            || self.source_file_bytes_opened != 0
            || self.model_runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(SourceGuardDriftError::PromotionBoundaryBroken);
        }
        Ok(())
    }
}

// UAS: uas:source-guard-drift-release-blocker-card:metrics
// Plane: Verification.
// Residency: aggregate source-guard metadata only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceGuardDriftMetrics {
    pub issue_count: u64,
    pub source_ref_count: usize,
    pub focused_command_count: usize,
    pub invariant_count: usize,
    pub drift_surface_count: usize,
    pub source_file_bytes_opened: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

// UAS: uas:source-guard-drift-release-blocker-card:witness
// Plane: Verification.
// Residency: metadata-only source-guard drift source-card witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceGuardDriftReleaseBlockerWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_ref: String,
    pub family_source_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_next_cursor: String,
    pub card: SourceGuardDriftReleaseBlockerCard,
    pub metrics: SourceGuardDriftMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl SourceGuardDriftReleaseBlockerWitness {
    pub fn new(
        upstream_ref: &str,
        family_source_ref: &str,
        upstream_overall_pass: bool,
        upstream_next_cursor: &str,
        family_id: &str,
        issue_count: u64,
    ) -> Result<Self, SourceGuardDriftError> {
        validate_upstream_ref(upstream_ref)?;
        validate_family_source_ref(family_source_ref)?;
        validate_token("upstream_next_cursor", upstream_next_cursor)?;
        if !upstream_overall_pass {
            return Err(SourceGuardDriftError::UpstreamNotPassed);
        }
        if upstream_next_cursor != SOURCE_GUARD_DRIFT_RELEASE_BLOCKER_CARD_CURSOR {
            return Err(SourceGuardDriftError::WrongUpstreamCursor(
                upstream_next_cursor.to_string(),
            ));
        }
        let card = SourceGuardDriftReleaseBlockerCard::from_family(family_id, issue_count)?;
        card.validate()?;
        let metrics = SourceGuardDriftMetrics {
            issue_count: card.issue_count,
            source_ref_count: card.source_refs.len(),
            focused_command_count: card.focused_commands.len(),
            invariant_count: card.required_invariants.len(),
            drift_surface_count: card.drift_surfaces.len(),
            source_file_bytes_opened: card.source_file_bytes_opened,
            model_runtime_bytes_loaded: card.model_runtime_bytes_loaded,
            provider_calls_made: card.provider_calls_made,
        };
        let address = source_guard_drift_address(
            upstream_ref,
            family_source_ref,
            upstream_overall_pass,
            upstream_next_cursor,
            &card,
            &metrics,
        );
        Ok(Self {
            falsifier_id: SOURCE_GUARD_DRIFT_RELEASE_BLOCKER_CARD_ID.to_string(),
            cursor: SOURCE_GUARD_DRIFT_RELEASE_BLOCKER_CARD_CURSOR.to_string(),
            next_cursor: SOURCE_GUARD_DRIFT_RELEASE_BLOCKER_CARD_NEXT_CURSOR.to_string(),
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

    pub fn validate(&self) -> Result<(), SourceGuardDriftError> {
        if self.falsifier_id != SOURCE_GUARD_DRIFT_RELEASE_BLOCKER_CARD_ID
            || self.cursor != SOURCE_GUARD_DRIFT_RELEASE_BLOCKER_CARD_CURSOR
            || self.next_cursor != SOURCE_GUARD_DRIFT_RELEASE_BLOCKER_CARD_NEXT_CURSOR
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(SourceGuardDriftError::WitnessHeaderBroken);
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
            return Err(SourceGuardDriftError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_source_guard_drift_source_refs() -> &'static [&'static str] {
    &REQUIRED_SOURCE_REFS
}

pub fn required_source_guard_drift_invariants() -> &'static [&'static str] {
    &REQUIRED_INVARIANTS
}

fn source_guard_drift_address(
    upstream_ref: &str,
    family_source_ref: &str,
    upstream_overall_pass: bool,
    upstream_next_cursor: &str,
    card: &SourceGuardDriftReleaseBlockerCard,
    metrics: &SourceGuardDriftMetrics,
) -> String {
    let mut preimage = String::new();
    preimage.push_str(SOURCE_GUARD_DRIFT_RELEASE_BLOCKER_CARD_ID);
    preimage.push_str(SOURCE_GUARD_DRIFT_RELEASE_BLOCKER_CARD_CURSOR);
    preimage.push_str(SOURCE_GUARD_DRIFT_RELEASE_BLOCKER_CARD_NEXT_CURSOR);
    preimage.push_str(upstream_ref);
    preimage.push_str(family_source_ref);
    preimage.push_str(&upstream_overall_pass.to_string());
    preimage.push_str(upstream_next_cursor);
    preimage.push_str(&format!("{card:?}"));
    preimage.push_str(&format!("{metrics:?}"));
    sha256_hex(preimage.as_bytes())
}

fn validate_unique_exact_set(
    field: &'static str,
    values: &[String],
    required: &[&'static str],
) -> Result<(), SourceGuardDriftError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(SourceGuardDriftError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    let actual = values.iter().map(String::as_str).collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected {
        return Err(SourceGuardDriftError::MissingRequiredSet {
            field,
            actual: values.len(),
            expected: required.len(),
        });
    }
    Ok(())
}

fn validate_exact_enum_set<T>(
    field: &'static str,
    values: &[T],
    required: &[T],
) -> Result<(), SourceGuardDriftError>
where
    T: Copy + Ord + fmt::Debug,
{
    let actual = values.iter().copied().collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected || values.len() != actual.len() {
        return Err(SourceGuardDriftError::BadEnumSet {
            field,
            actual: values.len(),
            expected: required.len(),
        });
    }
    Ok(())
}

fn validate_focused_commands(values: &[String]) -> Result<(), SourceGuardDriftError> {
    if values.len() < 5 || values.len() > 8 {
        return Err(SourceGuardDriftError::BadListLength {
            field: "focused_commands",
            actual: values.len(),
        });
    }
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text("focused_commands", value)?;
        if !seen.insert(value.as_str()) {
            return Err(SourceGuardDriftError::DuplicateValue {
                field: "focused_commands",
                value: value.to_string(),
            });
        }
        let swift_ok = value.starts_with("xcodebuild test -only-testing:EpistemosTests/")
            && (value.contains("SourceGuard")
                || value.contains("MASBoundary")
                || value.contains("BackendRuntime")
                || value.contains("LocalModelRelease"));
        let rust_ok = value.starts_with("cargo test --manifest-path agent_core/Cargo.toml ")
            && value.contains("source_guard");
        if !(swift_ok || rust_ok) {
            return Err(SourceGuardDriftError::BadFocusedCommand);
        }
    }
    Ok(())
}

fn validate_upstream_ref(value: &str) -> Result<(), SourceGuardDriftError> {
    validate_token("upstream_ref", value)?;
    if !value.starts_with("artifact:falsifiers/search_index_release_blocker_card/")
        || !value.contains("/result.json#F-SearchIndex-ReleaseBlockerCard")
    {
        return Err(SourceGuardDriftError::BadUpstreamRef);
    }
    Ok(())
}

fn validate_family_source_ref(value: &str) -> Result<(), SourceGuardDriftError> {
    validate_token("family_source_ref", value)?;
    if !value.starts_with("artifact:falsifiers/release_audit_failure_family_source_card/")
        || !value.contains("/result.json#source_guard_drift")
    {
        return Err(SourceGuardDriftError::BadFamilySourceRef);
    }
    Ok(())
}

fn validate_token(field: &'static str, value: &str) -> Result<(), SourceGuardDriftError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(SourceGuardDriftError::InvalidToken {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_text(field: &'static str, value: &str) -> Result<(), SourceGuardDriftError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(SourceGuardDriftError::InvalidText {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

// UAS: uas:source-guard-drift-release-blocker-card:error
// Plane: Verification.
// Residency: fail-closed metadata validation errors.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SourceGuardDriftError {
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
    BadEnumSet {
        field: &'static str,
        actual: usize,
        expected: usize,
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
    WrongFamily(String),
    ZeroIssueCount,
    CardHeaderBroken,
    PromotionBoundaryBroken,
    UpstreamNotPassed,
    WrongUpstreamCursor(String),
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for SourceGuardDriftError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{self:?}")
    }
}

impl Error for SourceGuardDriftError {}

#[cfg(test)]
mod tests {
    use super::*;

    fn witness() -> SourceGuardDriftReleaseBlockerWitness {
        SourceGuardDriftReleaseBlockerWitness::new(
            SOURCE_GUARD_DRIFT_UPSTREAM_REF,
            SOURCE_GUARD_DRIFT_FAMILY_SOURCE_REF,
            true,
            SOURCE_GUARD_DRIFT_RELEASE_BLOCKER_CARD_CURSOR,
            "source_guard_drift",
            3,
        )
        .expect("valid source guard drift witness")
    }

    #[test]
    fn valid_witness_is_metadata_only_and_stable() {
        let witness = witness();
        assert!(witness.validate().is_ok());
        assert_eq!(witness.card.source_file_bytes_opened, 0);
        assert_eq!(witness.card.model_runtime_bytes_loaded, 0);
        assert_eq!(witness.card.provider_calls_made, 0);
        assert!(witness.metadata_only);
        assert!(witness.no_product_promotion);
        assert_eq!(
            witness.metrics.source_ref_count,
            required_source_guard_drift_source_refs().len()
        );
    }

    #[test]
    fn rejects_wrong_family_and_zero_issues() {
        assert!(SourceGuardDriftReleaseBlockerWitness::new(
            SOURCE_GUARD_DRIFT_UPSTREAM_REF,
            SOURCE_GUARD_DRIFT_FAMILY_SOURCE_REF,
            true,
            SOURCE_GUARD_DRIFT_RELEASE_BLOCKER_CARD_CURSOR,
            "search_index",
            3,
        )
        .is_err());
        assert!(SourceGuardDriftReleaseBlockerWitness::new(
            SOURCE_GUARD_DRIFT_UPSTREAM_REF,
            SOURCE_GUARD_DRIFT_FAMILY_SOURCE_REF,
            true,
            SOURCE_GUARD_DRIFT_RELEASE_BLOCKER_CARD_CURSOR,
            "source_guard_drift",
            0,
        )
        .is_err());
    }

    #[test]
    fn rejects_missing_sources_invariants_and_broad_commands() {
        let mut card = witness().card;
        card.source_refs
            .retain(|value| value != "docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md");
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.required_invariants
            .retain(|value| value != "docs_code_parity_required");
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.focused_commands[0] = "xcodebuild test -only-testing:EpistemosTests".to_string();
        assert!(card.validate().is_err());
    }

    #[test]
    fn rejects_hidden_authority_and_false_promotion() {
        let mut card = witness().card;
        card.hidden_route_authority_allowed = true;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.product_green_claimed = true;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.live_dense_70b_claimed = true;
        assert!(card.validate().is_err());
    }

    #[test]
    fn rejects_byte_and_provider_leaks() {
        let mut card = witness().card;
        card.source_file_bytes_opened = 1;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.model_runtime_bytes_loaded = 1;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.provider_calls_made = 1;
        assert!(card.validate().is_err());
    }
}
