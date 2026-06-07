use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

pub const DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_ID: &str =
    "F-DistributionProjectIntegrity-ReleaseBlockerCard";
pub const DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_CURSOR: &str =
    "distribution_project_integrity_release_blocker_card";
pub const DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_NEXT_CURSOR: &str =
    "editor_epdoc_surface_release_blocker_card";
pub const DISTRIBUTION_PROJECT_INTEGRITY_UPSTREAM_REF: &str =
    "artifact:falsifiers/theme_presentation_release_blocker_card/result.json#F-ThemePresentation-ReleaseBlockerCard";
pub const DISTRIBUTION_PROJECT_INTEGRITY_FAMILY_SOURCE_REF: &str =
    "artifact:falsifiers/release_audit_failure_family_source_card/result.json#distribution_project_integrity";

const REQUIRED_SOURCE_REFS: [&str; 14] = [
    "project.yml",
    "Epistemos.xcodeproj/project.pbxproj",
    "Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos.xcscheme",
    "Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos-AppStore.xcscheme",
    "Epistemos-Info.plist",
    "Epistemos-AppStore-Info.plist",
    "Epistemos/Epistemos.entitlements",
    "Epistemos/Epistemos-AppStore.entitlements",
    "Epistemos/Resources/PrivacyInfo.xcprivacy",
    "docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md",
    "EpistemosTests/AppStoreHardeningTests.swift",
    "EpistemosTests/ReleaseScriptAuditTests.swift",
    "EpistemosTests/CoreMASBoundarySourceGuardTests.swift",
    "EpistemosTests/CargoReleaseProfileTests.swift",
];

const REQUIRED_INVARIANTS: [&str; 12] = [
    "project_yml_is_xcodegen_source_of_truth",
    "pro_and_appstore_schemes_are_both_bound",
    "mas_and_pro_entitlements_remain_separated",
    "privacy_manifest_is_distribution_bound",
    "appstore_info_plist_does_not_claim_pro_capability",
    "pro_info_plist_does_not_claim_mas_review_status",
    "xcodeproj_drift_requires_explicit_regeneration_proof",
    "release_scripts_require_log_evidence",
    "local_model_catalog_is_not_distribution_proof",
    "mas_forbidden_tools_remain_distribution_blockers",
    "archive_codesign_notary_and_review_are_required_for_green",
    "release_audit_family_remains_red_until_focused_tests_pass",
];

// UAS: uas:distribution-project-integrity-release-blocker-card:organ
// Plane: Verification.
// Residency: metadata-only project/distribution source-card classification.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DistributionProjectIntegrityOrgan {
    DistributionIntegrity,
    XcodeProject,
    MasBoundary,
    ProBoundary,
    ReleaseScript,
}

// UAS: uas:distribution-project-integrity-release-blocker-card:status
// Plane: Verification.
// Residency: retained release blocker classification only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DistributionProjectIntegrityStatus {
    RedReleaseBlocker,
}

// UAS: uas:distribution-project-integrity-release-blocker-card:card
// Plane: Verification.
// Residency: metadata-only source-card blocker; no archive/model/runtime bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct DistributionProjectIntegrityReleaseBlockerCard {
    pub family_id: String,
    pub issue_count: u64,
    pub organ: DistributionProjectIntegrityOrgan,
    pub status: DistributionProjectIntegrityStatus,
    pub source_refs: Vec<String>,
    pub focused_commands: Vec<String>,
    pub required_invariants: Vec<String>,
    pub mas_status: String,
    pub pro_status: String,
    pub project_build_as_release_proof: bool,
    pub app_store_archive_claimed: bool,
    pub distribution_codesign_claimed: bool,
    pub notarization_or_review_claimed: bool,
    pub xcodegen_drift_ignored: bool,
    pub mas_entitlements_include_pro_tools: bool,
    pub pro_entitlements_marketed_as_mas: bool,
    pub privacy_manifest_missing: bool,
    pub scheme_mismatch_ignored: bool,
    pub local_model_catalog_as_distribution_proof: bool,
    pub release_script_log_hidden: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub product_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub archive_bytes_loaded: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
}

impl DistributionProjectIntegrityReleaseBlockerCard {
    pub fn from_family(
        family_id: &str,
        issue_count: u64,
    ) -> Result<Self, DistributionProjectIntegrityError> {
        validate_token("family_id", family_id)?;
        if family_id != "distribution_project_integrity" {
            return Err(DistributionProjectIntegrityError::WrongFamily(
                family_id.to_string(),
            ));
        }
        if issue_count == 0 {
            return Err(DistributionProjectIntegrityError::ZeroIssueCount);
        }
        Ok(Self {
            family_id: family_id.to_string(),
            issue_count,
            organ: DistributionProjectIntegrityOrgan::DistributionIntegrity,
            status: DistributionProjectIntegrityStatus::RedReleaseBlocker,
            source_refs: REQUIRED_SOURCE_REFS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            focused_commands: vec![
                "xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build".to_string(),
                "xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' build".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/AppStoreHardeningTests".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/ReleaseScriptAuditTests".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/CoreMASBoundarySourceGuardTests".to_string(),
            ],
            required_invariants: REQUIRED_INVARIANTS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            mas_status: "red_release_blocker".to_string(),
            pro_status: "gated_release_blocker".to_string(),
            project_build_as_release_proof: false,
            app_store_archive_claimed: false,
            distribution_codesign_claimed: false,
            notarization_or_review_claimed: false,
            xcodegen_drift_ignored: false,
            mas_entitlements_include_pro_tools: false,
            pro_entitlements_marketed_as_mas: false,
            privacy_manifest_missing: false,
            scheme_mismatch_ignored: false,
            local_model_catalog_as_distribution_proof: false,
            release_script_log_hidden: false,
            hidden_route_authority: false,
            hidden_cloud_fallback: false,
            l2_green_claimed: false,
            l3_green_claimed: false,
            product_green_claimed: false,
            live_dense_70b_claimed: false,
            archive_bytes_loaded: 0,
            model_runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            rollback_ref: "rollback:distribution_project_integrity_release_blocker_card"
                .to_string(),
            run_event_log_ref:
                "run_event_log:distribution_project_integrity_release_blocker_card".to_string(),
            answer_packet_ref:
                "answer_packet:distribution_project_integrity_release_blocker_card".to_string(),
        })
    }

    pub fn validate(&self) -> Result<(), DistributionProjectIntegrityError> {
        validate_token("family_id", &self.family_id)?;
        if self.family_id != "distribution_project_integrity"
            || self.issue_count == 0
            || self.organ != DistributionProjectIntegrityOrgan::DistributionIntegrity
            || self.status != DistributionProjectIntegrityStatus::RedReleaseBlocker
        {
            return Err(DistributionProjectIntegrityError::CardHeaderBroken);
        }
        validate_unique_exact_set("source_refs", &self.source_refs, &REQUIRED_SOURCE_REFS)?;
        validate_unique_exact_set(
            "required_invariants",
            &self.required_invariants,
            &REQUIRED_INVARIANTS,
        )?;
        validate_list("focused_commands", &self.focused_commands, 5, 8)?;
        for command in &self.focused_commands {
            if !(command.starts_with("xcodebuild ")
                && (command.contains(" -scheme Epistemos ")
                    || command.contains(" -scheme Epistemos-AppStore ")
                    || command.contains("-only-testing:EpistemosTests/")))
            {
                return Err(DistributionProjectIntegrityError::BadFocusedCommand);
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
        if self.project_build_as_release_proof
            || self.app_store_archive_claimed
            || self.distribution_codesign_claimed
            || self.notarization_or_review_claimed
            || self.xcodegen_drift_ignored
            || self.mas_entitlements_include_pro_tools
            || self.pro_entitlements_marketed_as_mas
            || self.privacy_manifest_missing
            || self.scheme_mismatch_ignored
            || self.local_model_catalog_as_distribution_proof
            || self.release_script_log_hidden
            || self.hidden_route_authority
            || self.hidden_cloud_fallback
            || self.l2_green_claimed
            || self.l3_green_claimed
            || self.product_green_claimed
            || self.live_dense_70b_claimed
            || self.archive_bytes_loaded != 0
            || self.model_runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(DistributionProjectIntegrityError::PromotionBoundaryBroken);
        }
        Ok(())
    }
}

// UAS: uas:distribution-project-integrity-release-blocker-card:metrics
// Plane: Verification.
// Residency: aggregate release-blocker metrics only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct DistributionProjectIntegrityMetrics {
    pub issue_count: u64,
    pub source_ref_count: usize,
    pub focused_command_count: usize,
    pub invariant_count: usize,
    pub archive_bytes_loaded: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

// UAS: uas:distribution-project-integrity-release-blocker-card:witness
// Plane: Verification.
// Residency: metadata-only project/distribution source-card witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct DistributionProjectIntegrityReleaseBlockerWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_ref: String,
    pub family_source_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_next_cursor: String,
    pub card: DistributionProjectIntegrityReleaseBlockerCard,
    pub metrics: DistributionProjectIntegrityMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl DistributionProjectIntegrityReleaseBlockerWitness {
    pub fn new(
        upstream_ref: &str,
        family_source_ref: &str,
        upstream_overall_pass: bool,
        upstream_next_cursor: &str,
        family_id: &str,
        issue_count: u64,
    ) -> Result<Self, DistributionProjectIntegrityError> {
        validate_upstream_ref(upstream_ref)?;
        validate_family_source_ref(family_source_ref)?;
        validate_token("upstream_next_cursor", upstream_next_cursor)?;
        if !upstream_overall_pass {
            return Err(DistributionProjectIntegrityError::UpstreamNotPassed);
        }
        if upstream_next_cursor != DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_CURSOR {
            return Err(DistributionProjectIntegrityError::WrongUpstreamCursor(
                upstream_next_cursor.to_string(),
            ));
        }
        let card =
            DistributionProjectIntegrityReleaseBlockerCard::from_family(family_id, issue_count)?;
        card.validate()?;
        let metrics = DistributionProjectIntegrityMetrics {
            issue_count: card.issue_count,
            source_ref_count: card.source_refs.len(),
            focused_command_count: card.focused_commands.len(),
            invariant_count: card.required_invariants.len(),
            archive_bytes_loaded: card.archive_bytes_loaded,
            model_runtime_bytes_loaded: card.model_runtime_bytes_loaded,
            provider_calls_made: card.provider_calls_made,
        };
        let address = distribution_project_integrity_address(
            upstream_ref,
            family_source_ref,
            upstream_overall_pass,
            upstream_next_cursor,
            &card,
            &metrics,
        );
        Ok(Self {
            falsifier_id: DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_ID.to_string(),
            cursor: DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_CURSOR.to_string(),
            next_cursor: DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_NEXT_CURSOR
                .to_string(),
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

    pub fn validate(&self) -> Result<(), DistributionProjectIntegrityError> {
        if self.falsifier_id != DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_ID
            || self.cursor != DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_CURSOR
            || self.next_cursor != DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_NEXT_CURSOR
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(DistributionProjectIntegrityError::WitnessHeaderBroken);
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
            return Err(DistributionProjectIntegrityError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_distribution_project_integrity_source_refs() -> &'static [&'static str] {
    &REQUIRED_SOURCE_REFS
}

pub fn required_distribution_project_integrity_invariants() -> &'static [&'static str] {
    &REQUIRED_INVARIANTS
}

fn distribution_project_integrity_address(
    upstream_ref: &str,
    family_source_ref: &str,
    upstream_overall_pass: bool,
    upstream_next_cursor: &str,
    card: &DistributionProjectIntegrityReleaseBlockerCard,
    metrics: &DistributionProjectIntegrityMetrics,
) -> String {
    let mut preimage = String::new();
    preimage.push_str(DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_ID);
    preimage.push_str(DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_CURSOR);
    preimage.push_str(DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_NEXT_CURSOR);
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
) -> Result<(), DistributionProjectIntegrityError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(DistributionProjectIntegrityError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    let actual = values.iter().map(String::as_str).collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected {
        return Err(DistributionProjectIntegrityError::MissingRequiredSet {
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
) -> Result<(), DistributionProjectIntegrityError> {
    if values.len() < min || values.len() > max {
        return Err(DistributionProjectIntegrityError::BadListLength {
            field,
            actual: values.len(),
        });
    }
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(DistributionProjectIntegrityError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    Ok(())
}

fn validate_upstream_ref(value: &str) -> Result<(), DistributionProjectIntegrityError> {
    validate_token("upstream_ref", value)?;
    if !value.starts_with("artifact:falsifiers/theme_presentation_release_blocker_card/")
        || !value.contains("/result.json#F-ThemePresentation-ReleaseBlockerCard")
    {
        return Err(DistributionProjectIntegrityError::BadUpstreamRef);
    }
    Ok(())
}

fn validate_family_source_ref(value: &str) -> Result<(), DistributionProjectIntegrityError> {
    validate_token("family_source_ref", value)?;
    if !value.starts_with("artifact:falsifiers/release_audit_failure_family_source_card/")
        || !value.contains("/result.json#distribution_project_integrity")
    {
        return Err(DistributionProjectIntegrityError::BadFamilySourceRef);
    }
    Ok(())
}

fn validate_token(
    field: &'static str,
    value: &str,
) -> Result<(), DistributionProjectIntegrityError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(DistributionProjectIntegrityError::InvalidToken {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_text(
    field: &'static str,
    value: &str,
) -> Result<(), DistributionProjectIntegrityError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(DistributionProjectIntegrityError::InvalidText {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

// UAS: uas:distribution-project-integrity-release-blocker-card:error
// Plane: Verification.
// Residency: fail-closed metadata validation errors.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum DistributionProjectIntegrityError {
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

impl fmt::Display for DistributionProjectIntegrityError {
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
            Self::ZeroIssueCount => write!(
                f,
                "distribution_project_integrity issue count cannot be zero"
            ),
            Self::CardHeaderBroken => write!(f, "card header is inconsistent"),
            Self::BadFocusedCommand => write!(f, "focused command is not scoped"),
            Self::PromotionBoundaryBroken => write!(f, "promotion boundary was broken"),
            Self::WitnessHeaderBroken => write!(f, "witness header is inconsistent"),
            Self::WitnessDigestMismatch => write!(f, "witness digest mismatch"),
        }
    }
}

impl std::error::Error for DistributionProjectIntegrityError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_distribution_project_integrity_card() {
        let witness = DistributionProjectIntegrityReleaseBlockerWitness::new(
            DISTRIBUTION_PROJECT_INTEGRITY_UPSTREAM_REF,
            DISTRIBUTION_PROJECT_INTEGRITY_FAMILY_SOURCE_REF,
            true,
            DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_CURSOR,
            "distribution_project_integrity",
            18,
        )
        .expect("valid distribution project witness");
        witness.validate().expect("witness validates");
        assert_eq!(witness.metrics.source_ref_count, 14);
        assert_eq!(witness.metrics.focused_command_count, 5);
        assert_eq!(witness.metrics.invariant_count, 12);
        assert_eq!(witness.metrics.archive_bytes_loaded, 0);
        assert_eq!(
            witness.next_cursor,
            DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_NEXT_CURSOR
        );
    }

    #[test]
    fn rejects_wrong_upstream_or_family() {
        assert!(DistributionProjectIntegrityReleaseBlockerWitness::new(
            DISTRIBUTION_PROJECT_INTEGRITY_UPSTREAM_REF,
            DISTRIBUTION_PROJECT_INTEGRITY_FAMILY_SOURCE_REF,
            false,
            DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_CURSOR,
            "distribution_project_integrity",
            18,
        )
        .is_err());
        assert!(DistributionProjectIntegrityReleaseBlockerWitness::new(
            DISTRIBUTION_PROJECT_INTEGRITY_UPSTREAM_REF,
            DISTRIBUTION_PROJECT_INTEGRITY_FAMILY_SOURCE_REF,
            true,
            "theme_presentation_release_blocker_card",
            "distribution_project_integrity",
            18,
        )
        .is_err());
        assert!(DistributionProjectIntegrityReleaseBlockerWitness::new(
            DISTRIBUTION_PROJECT_INTEGRITY_UPSTREAM_REF,
            DISTRIBUTION_PROJECT_INTEGRITY_FAMILY_SOURCE_REF,
            true,
            DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_CURSOR,
            "theme_presentation",
            19,
        )
        .is_err());
    }

    #[test]
    fn rejects_distribution_promotion_and_byte_leaks() {
        let mut card = DistributionProjectIntegrityReleaseBlockerCard::from_family(
            "distribution_project_integrity",
            18,
        )
        .expect("valid card");
        card.project_build_as_release_proof = true;
        assert!(card.validate().is_err());

        let mut card = DistributionProjectIntegrityReleaseBlockerCard::from_family(
            "distribution_project_integrity",
            18,
        )
        .expect("valid card");
        card.source_refs.retain(|value| value != "project.yml");
        assert!(card.validate().is_err());

        let mut card = DistributionProjectIntegrityReleaseBlockerCard::from_family(
            "distribution_project_integrity",
            18,
        )
        .expect("valid card");
        card.archive_bytes_loaded = 1;
        assert!(card.validate().is_err());
    }
}
