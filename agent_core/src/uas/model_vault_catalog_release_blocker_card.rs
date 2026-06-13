use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

pub const MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_ID: &str =
    "F-ModelVaultCatalog-ReleaseBlockerCard";
pub const MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_CURSOR: &str =
    "model_vault_catalog_release_blocker_card";
pub const MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_NEXT_CURSOR: &str =
    "agent_route_policy_large_model_no_hidden_authority";
pub const MODEL_VAULT_CATALOG_UPSTREAM_REF: &str = "artifact:falsifiers/release_audit_failure_family_source_card/result.json#F-ReleaseAuditFailureFamily-SourceCard";

const REQUIRED_SOURCE_REFS: [&str; 8] = [
    "Epistemos/State/InferenceState.swift",
    "Epistemos/Engine/TriageService.swift",
    "Epistemos/Engine/MLXInferenceService.swift",
    "Epistemos/Engine/ModelDownloadManager.swift",
    "Epistemos/Views/Settings/ModelVaultsSettingsView.swift",
    "Epistemos/Views/Notes/ModelVaultsSidebarSection.swift",
    "EpistemosTests/TriageServiceTests.swift",
    "docs/fusion/TURBOVEC_QAT_RUNTIME_AGNOSTIC_INTAKE_2026_06_06.md",
];

const REQUIRED_INVARIANTS: [&str; 10] = [
    "release_selectable_installed_models_only",
    "interactive_chat_validated_models_only",
    "gemma4_loader_blocked_from_picker",
    "shared_model_vault_targets_builder",
    "runtime_directory_must_resolve_before_request",
    "model_download_checksum_validation_bound",
    "mas_pro_status_visible_before_route",
    "no_provider_or_cloud_fallback_from_catalog",
    "no_catalog_entry_counts_as_runtime_proof",
    "answer_packet_caveat_required_for_unavailable_models",
];

// UAS: uas:model-vault-catalog-release-blocker-card:organ
// Plane: State + Controller + Verification.
// Residency: catalog/source-card metadata only; no product route changes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ModelVaultCatalogBlockerOrgan {
    Uas,
    Eidos,
    AppColdStore,
    RuntimeRouter,
    SovereignGate,
    RunEventLog,
    AnswerPacket,
    MasProBoundary,
}

// UAS: uas:model-vault-catalog-release-blocker-card:status
// Plane: Verification.
// Residency: retained release blocker classification only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ModelVaultCatalogBlockerStatus {
    RedReleaseBlocker,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:model-vault-catalog-release-blocker-card:card
// Plane: Controller + Verification.
// Residency: metadata-only catalog trust blocker card.
pub struct ModelVaultCatalogReleaseBlockerCard {
    pub family_id: String,
    pub issue_count: u64,
    pub organ: ModelVaultCatalogBlockerOrgan,
    pub status: ModelVaultCatalogBlockerStatus,
    pub source_refs: Vec<String>,
    pub focused_commands: Vec<String>,
    pub required_invariants: Vec<String>,
    pub mas_status: String,
    pub pro_status: String,
    pub catalog_entry_runtime_proof: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub live_dense_70b_claimed: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub product_green_claimed: bool,
    pub model_runtime_bytes_loaded: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
}

impl ModelVaultCatalogReleaseBlockerCard {
    pub fn from_upstream(
        upstream_family_id: &str,
        upstream_issue_count: u64,
    ) -> Result<Self, ModelVaultCatalogReleaseBlockerError> {
        validate_token("upstream_family_id", upstream_family_id)?;
        if upstream_family_id != "model_vault_catalog" {
            return Err(ModelVaultCatalogReleaseBlockerError::WrongFamily(
                upstream_family_id.to_string(),
            ));
        }
        if upstream_issue_count == 0 {
            return Err(ModelVaultCatalogReleaseBlockerError::ZeroIssueCount);
        }
        Ok(Self {
            family_id: upstream_family_id.to_string(),
            issue_count: upstream_issue_count,
            organ: ModelVaultCatalogBlockerOrgan::RuntimeRouter,
            status: ModelVaultCatalogBlockerStatus::RedReleaseBlocker,
            source_refs: REQUIRED_SOURCE_REFS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            focused_commands: vec![
                "xcodebuild test -only-testing:EpistemosTests/TriageServiceTests/gemma4TiersHiddenFromPicker".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/TriageServiceTests/modelVaultSettingsUseSharedReleaseTierFiltering".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/TriageServiceTests/triageRefreshesLocalModelStateBeforeLocalOnlyRequests".to_string(),
            ],
            required_invariants: REQUIRED_INVARIANTS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            mas_status: "red_release_blocker".to_string(),
            pro_status: "gated_release_blocker".to_string(),
            catalog_entry_runtime_proof: false,
            hidden_route_authority: false,
            hidden_cloud_fallback: false,
            live_dense_70b_claimed: false,
            l2_green_claimed: false,
            l3_green_claimed: false,
            product_green_claimed: false,
            model_runtime_bytes_loaded: 0,
            rollback_ref: "rollback:model_vault_catalog_release_blocker".to_string(),
            run_event_log_ref: "run_event_log:model_vault_catalog_release_blocker".to_string(),
            answer_packet_ref: "answer_packet:model_vault_catalog_release_blocker".to_string(),
        })
    }

    pub fn validate(&self) -> Result<(), ModelVaultCatalogReleaseBlockerError> {
        validate_token("family_id", &self.family_id)?;
        if self.family_id != "model_vault_catalog"
            || self.issue_count == 0
            || self.organ != ModelVaultCatalogBlockerOrgan::RuntimeRouter
            || self.status != ModelVaultCatalogBlockerStatus::RedReleaseBlocker
        {
            return Err(ModelVaultCatalogReleaseBlockerError::CardHeaderBroken);
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
                return Err(ModelVaultCatalogReleaseBlockerError::BadFocusedCommand);
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
        if self.catalog_entry_runtime_proof
            || self.hidden_route_authority
            || self.hidden_cloud_fallback
            || self.live_dense_70b_claimed
            || self.l2_green_claimed
            || self.l3_green_claimed
            || self.product_green_claimed
            || self.model_runtime_bytes_loaded != 0
        {
            return Err(ModelVaultCatalogReleaseBlockerError::PromotionBoundaryBroken);
        }
        Ok(())
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:model-vault-catalog-release-blocker-card:metrics
// Plane: Verification.
// Residency: aggregate catalog blocker metadata only.
pub struct ModelVaultCatalogReleaseBlockerMetrics {
    pub issue_count: u64,
    pub source_ref_count: usize,
    pub focused_command_count: usize,
    pub invariant_count: usize,
    pub model_runtime_bytes_loaded: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:model-vault-catalog-release-blocker-card:witness
// Plane: Verification.
// Residency: metadata-only source-card witness from retained release blocker.
pub struct ModelVaultCatalogReleaseBlockerWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_next_cursor: String,
    pub card: ModelVaultCatalogReleaseBlockerCard,
    pub metrics: ModelVaultCatalogReleaseBlockerMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl ModelVaultCatalogReleaseBlockerWitness {
    pub fn new(
        upstream_ref: &str,
        upstream_overall_pass: bool,
        upstream_next_cursor: &str,
        upstream_family_id: &str,
        upstream_issue_count: u64,
    ) -> Result<Self, ModelVaultCatalogReleaseBlockerError> {
        validate_artifact_ref(upstream_ref)?;
        validate_token("upstream_next_cursor", upstream_next_cursor)?;
        if !upstream_overall_pass {
            return Err(ModelVaultCatalogReleaseBlockerError::UpstreamNotPassed);
        }
        if upstream_next_cursor != MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_CURSOR {
            return Err(ModelVaultCatalogReleaseBlockerError::WrongUpstreamCursor(
                upstream_next_cursor.to_string(),
            ));
        }
        let card = ModelVaultCatalogReleaseBlockerCard::from_upstream(
            upstream_family_id,
            upstream_issue_count,
        )?;
        card.validate()?;
        let metrics = ModelVaultCatalogReleaseBlockerMetrics {
            issue_count: card.issue_count,
            source_ref_count: card.source_refs.len(),
            focused_command_count: card.focused_commands.len(),
            invariant_count: card.required_invariants.len(),
            model_runtime_bytes_loaded: card.model_runtime_bytes_loaded,
        };
        let address = blocker_address(
            upstream_ref,
            upstream_overall_pass,
            upstream_next_cursor,
            &card,
            &metrics,
        );
        Ok(Self {
            falsifier_id: MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_ID.to_string(),
            cursor: MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_CURSOR.to_string(),
            next_cursor: MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_NEXT_CURSOR.to_string(),
            upstream_ref: upstream_ref.to_string(),
            upstream_overall_pass,
            upstream_next_cursor: upstream_next_cursor.to_string(),
            card,
            metrics,
            address,
            metadata_only: true,
            no_product_promotion: true,
        })
    }

    pub fn validate(&self) -> Result<(), ModelVaultCatalogReleaseBlockerError> {
        if self.falsifier_id != MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_ID
            || self.cursor != MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_CURSOR
            || self.next_cursor != MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_NEXT_CURSOR
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(ModelVaultCatalogReleaseBlockerError::WitnessHeaderBroken);
        }
        let rebuilt = Self::new(
            &self.upstream_ref,
            self.upstream_overall_pass,
            &self.upstream_next_cursor,
            &self.card.family_id,
            self.card.issue_count,
        )?;
        if rebuilt.address != self.address || rebuilt.metrics != self.metrics {
            return Err(ModelVaultCatalogReleaseBlockerError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_model_vault_catalog_source_refs() -> &'static [&'static str] {
    &REQUIRED_SOURCE_REFS
}

pub fn required_model_vault_catalog_invariants() -> &'static [&'static str] {
    &REQUIRED_INVARIANTS
}

fn blocker_address(
    upstream_ref: &str,
    upstream_overall_pass: bool,
    upstream_next_cursor: &str,
    card: &ModelVaultCatalogReleaseBlockerCard,
    metrics: &ModelVaultCatalogReleaseBlockerMetrics,
) -> String {
    let mut preimage = String::new();
    preimage.push_str(MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_ID);
    preimage.push_str(MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_CURSOR);
    preimage.push_str(MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_NEXT_CURSOR);
    preimage.push_str(upstream_ref);
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
) -> Result<(), ModelVaultCatalogReleaseBlockerError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(ModelVaultCatalogReleaseBlockerError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    let actual = values.iter().map(String::as_str).collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected {
        return Err(ModelVaultCatalogReleaseBlockerError::MissingRequiredSet {
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
) -> Result<(), ModelVaultCatalogReleaseBlockerError> {
    if values.len() < min || values.len() > max {
        return Err(ModelVaultCatalogReleaseBlockerError::BadListLength {
            field,
            actual: values.len(),
        });
    }
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(ModelVaultCatalogReleaseBlockerError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    Ok(())
}

fn validate_artifact_ref(value: &str) -> Result<(), ModelVaultCatalogReleaseBlockerError> {
    validate_token("upstream_ref", value)?;
    if !value.starts_with("artifact:falsifiers/release_audit_failure_family_source_card/")
        || !value.contains("/result.json#F-ReleaseAuditFailureFamily-SourceCard")
    {
        return Err(ModelVaultCatalogReleaseBlockerError::BadUpstreamRef);
    }
    Ok(())
}

fn validate_token(
    field: &'static str,
    value: &str,
) -> Result<(), ModelVaultCatalogReleaseBlockerError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(ModelVaultCatalogReleaseBlockerError::InvalidToken {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_text(
    field: &'static str,
    value: &str,
) -> Result<(), ModelVaultCatalogReleaseBlockerError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(ModelVaultCatalogReleaseBlockerError::InvalidText {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:model-vault-catalog-release-blocker-card:error
// Plane: Verification.
// Residency: fail-closed metadata validation errors.
pub enum ModelVaultCatalogReleaseBlockerError {
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

impl fmt::Display for ModelVaultCatalogReleaseBlockerError {
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
            Self::BadUpstreamRef => write!(f, "bad upstream release-audit family ref"),
            Self::UpstreamNotPassed => write!(f, "upstream family source card did not pass"),
            Self::WrongUpstreamCursor(cursor) => write!(f, "wrong upstream cursor: {cursor}"),
            Self::WrongFamily(family) => write!(f, "wrong release-audit family: {family}"),
            Self::ZeroIssueCount => write!(f, "model vault catalog issue count is zero"),
            Self::CardHeaderBroken => write!(f, "model vault catalog card header is broken"),
            Self::BadFocusedCommand => write!(f, "focused command is outside EpistemosTests"),
            Self::PromotionBoundaryBroken => {
                write!(f, "model vault catalog promotion boundary is broken")
            }
            Self::WitnessHeaderBroken => write!(f, "model vault catalog witness header is broken"),
            Self::WitnessDigestMismatch => {
                write!(f, "model vault catalog witness digest mismatch")
            }
        }
    }
}

impl std::error::Error for ModelVaultCatalogReleaseBlockerError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_model_vault_catalog_blocker() {
        let witness = ModelVaultCatalogReleaseBlockerWitness::new(
            MODEL_VAULT_CATALOG_UPSTREAM_REF,
            true,
            MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_CURSOR,
            "model_vault_catalog",
            9,
        )
        .expect("valid blocker");
        witness.validate().expect("witness validates");
        assert_eq!(witness.metrics.source_ref_count, REQUIRED_SOURCE_REFS.len());
        assert_eq!(witness.metrics.invariant_count, REQUIRED_INVARIANTS.len());
        assert_eq!(witness.card.model_runtime_bytes_loaded, 0);
    }

    #[test]
    fn rejects_wrong_upstream_or_family() {
        assert!(ModelVaultCatalogReleaseBlockerWitness::new(
            MODEL_VAULT_CATALOG_UPSTREAM_REF,
            false,
            MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_CURSOR,
            "model_vault_catalog",
            9,
        )
        .is_err());
        assert!(ModelVaultCatalogReleaseBlockerWitness::new(
            MODEL_VAULT_CATALOG_UPSTREAM_REF,
            true,
            "other_cursor",
            "model_vault_catalog",
            9,
        )
        .is_err());
        assert!(ModelVaultCatalogReleaseBlockerWitness::new(
            MODEL_VAULT_CATALOG_UPSTREAM_REF,
            true,
            MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_CURSOR,
            "agent_route_policy",
            21,
        )
        .is_err());
    }

    #[test]
    fn rejects_missing_source_and_promotion() {
        let witness = ModelVaultCatalogReleaseBlockerWitness::new(
            MODEL_VAULT_CATALOG_UPSTREAM_REF,
            true,
            MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_CURSOR,
            "model_vault_catalog",
            9,
        )
        .expect("valid blocker");
        let mut missing_source = witness.card.clone();
        missing_source.source_refs.pop();
        assert!(missing_source.validate().is_err());

        let mut promoted = witness.card.clone();
        promoted.catalog_entry_runtime_proof = true;
        assert!(promoted.validate().is_err());

        let mut byte_leak = witness.card.clone();
        byte_leak.model_runtime_bytes_loaded = 1;
        assert!(byte_leak.validate().is_err());
    }
}
