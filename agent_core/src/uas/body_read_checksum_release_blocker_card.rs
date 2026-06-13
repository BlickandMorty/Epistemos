use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

pub const BODY_READ_CHECKSUM_RELEASE_BLOCKER_CARD_ID: &str =
    "F-BodyReadChecksum-ReleaseBlockerCard";
pub const BODY_READ_CHECKSUM_RELEASE_BLOCKER_CARD_CURSOR: &str =
    "body_read_checksum_release_blocker_card";
pub const BODY_READ_CHECKSUM_RELEASE_BLOCKER_CARD_NEXT_CURSOR: &str =
    "search_index_release_blocker_card";
pub const BODY_READ_CHECKSUM_UPSTREAM_REF: &str = "artifact:falsifiers/runtime_performance_policy_release_blocker_card/result.json#F-RuntimePerformancePolicy-ReleaseBlockerCard";
pub const BODY_READ_CHECKSUM_FAMILY_SOURCE_REF: &str =
    "artifact:falsifiers/release_audit_failure_family_source_card/result.json#body_read_checksum";

const REQUIRED_SOURCE_REFS: [&str; 12] = [
    "Epistemos/Models/SDPage.swift",
    "Epistemos/Sync/NoteFileStorage.swift",
    "EpistemosTests/PhaseR3BodyReadParityTests.swift",
    "Epistemos/Engine/EpdocDocument.swift",
    "Epistemos/Sync/ReadableBlocksIndex.swift",
    "Epistemos/State/NoteChatState.swift",
    "Epistemos/Views/Notes/ProseEditorRepresentable2.swift",
    "Epistemos/Views/Notes/AIPartnerService.swift",
    "Epistemos/Bridge/StreamingDelegate.swift",
    "EpistemosTests/NoteChatStateTests.swift",
    "EpistemosTests/ResourceRuntimeRegressionTests.swift",
    "EpistemosTests/RuntimeValidationTests.swift",
];

const REQUIRED_INVARIANTS: [&str; 15] = [
    "managed_sidecar_first_order_preserved",
    "r3_resource_gateway_parity_preserved",
    "blank_managed_body_is_authoritative",
    "front_matter_policy_recorded",
    "unicode_and_multibyte_digest_stable",
    "editor_snapshot_sequence_required_for_live_editor_text",
    "readable_block_projection_digest_required",
    "graph_evidence_digest_required",
    "prompt_assembly_digest_required",
    "cache_salt_digest_required_before_kv_reuse",
    "answer_packet_carries_freshness_caveat",
    "no_raw_body_prompt_or_token_in_artifact",
    "body_read_parity_is_not_model_quality_proof",
    "no_l2_l3_product_green",
    "no_model_runtime_cache_or_provider_bytes",
];

// UAS: uas:body-read-checksum-release-blocker-card:organ
// Plane: Verification.
// Residency: metadata-only body freshness source-card classification.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum BodyReadChecksumOrgan {
    BodyRead,
    ResourceGateway,
    ReadableBlocks,
    EditorSnapshot,
    GraphEvidence,
    PromptAssembly,
    CacheLineage,
}

// UAS: uas:body-read-checksum-release-blocker-card:status
// Plane: Verification.
// Residency: retained release blocker classification only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum BodyReadChecksumStatus {
    RedReleaseBlocker,
}

// UAS: uas:body-read-checksum-release-blocker-card:source-lane
// Plane: State + Verification.
// Residency: source-of-truth lane taxonomy; no user body bytes are opened.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum BodyReadSourceLane {
    ManagedSidecar,
    R3ResourceGateway,
    InlineBody,
    RawVaultFile,
    EpdocPackage,
    EditorSnapshot,
    TestFixture,
}

// UAS: uas:body-read-checksum-release-blocker-card:projection-status
// Plane: Verification.
// Residency: readable-block/graph projection freshness taxonomy only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ProjectionFreshnessStatus {
    Fresh,
    Missing,
    Stale,
    Failed,
    RetryScheduled,
}

// UAS: uas:body-read-checksum-release-blocker-card:cache-policy
// Plane: Controller + Verification.
// Residency: prompt/KV cache reuse policy; no cache bytes are touched.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CacheReusePolicy {
    Denied,
    AllowedWithMatchingSalt,
    QuarantineResearchOnly,
}

// UAS: uas:body-read-checksum-release-blocker-card:card
// Plane: Verification.
// Residency: metadata-only freshness source-card; no body/model/cache bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BodyReadChecksumReleaseBlockerCard {
    pub family_id: String,
    pub issue_count: u64,
    pub organ: BodyReadChecksumOrgan,
    pub status: BodyReadChecksumStatus,
    pub source_refs: Vec<String>,
    pub focused_commands: Vec<String>,
    pub required_invariants: Vec<String>,
    pub body_source_lanes: Vec<BodyReadSourceLane>,
    pub projection_statuses: Vec<ProjectionFreshnessStatus>,
    pub cache_reuse_policy: CacheReusePolicy,
    pub body_digest_required: bool,
    pub body_digest_algorithm_label_required: bool,
    pub body_byte_count_required: bool,
    pub normalized_text_count_required: bool,
    pub editor_snapshot_sequence_required: bool,
    pub readable_block_projection_digest_required: bool,
    pub graph_evidence_digest_required: bool,
    pub prompt_assembly_digest_required: bool,
    pub cache_salt_digest_required: bool,
    pub managed_sidecar_first_required: bool,
    pub r3_gateway_parity_required: bool,
    pub blank_managed_body_authoritative: bool,
    pub front_matter_policy_required: bool,
    pub unicode_digest_fixture_required: bool,
    pub body_read_parity_as_model_quality_proof: bool,
    pub no_raw_body_in_artifact: bool,
    pub no_raw_prompt_in_artifact: bool,
    pub no_raw_model_token_in_artifact: bool,
    pub no_hidden_chain: bool,
    pub no_hidden_cache_authority: bool,
    pub no_provider_call: bool,
    pub answer_packet_caveat_hidden: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub product_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub body_bytes_read: u64,
    pub model_runtime_bytes_loaded: u64,
    pub cache_bytes_reused: u64,
    pub provider_calls_made: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
}

impl BodyReadChecksumReleaseBlockerCard {
    pub fn from_family(family_id: &str, issue_count: u64) -> Result<Self, BodyReadChecksumError> {
        validate_token("family_id", family_id)?;
        if family_id != "body_read_checksum" {
            return Err(BodyReadChecksumError::WrongFamily(family_id.to_string()));
        }
        if issue_count == 0 {
            return Err(BodyReadChecksumError::ZeroIssueCount);
        }
        Ok(Self {
            family_id: family_id.to_string(),
            issue_count,
            organ: BodyReadChecksumOrgan::BodyRead,
            status: BodyReadChecksumStatus::RedReleaseBlocker,
            source_refs: REQUIRED_SOURCE_REFS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            focused_commands: vec![
                "xcodebuild test -only-testing:EpistemosTests/PhaseR3BodyReadParityTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/NoteChatStateTests".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/ResourceRuntimeRegressionTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/RuntimeValidationTests".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/AIPartnerServiceTests".to_string(),
            ],
            required_invariants: REQUIRED_INVARIANTS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            body_source_lanes: vec![
                BodyReadSourceLane::ManagedSidecar,
                BodyReadSourceLane::R3ResourceGateway,
                BodyReadSourceLane::InlineBody,
                BodyReadSourceLane::RawVaultFile,
                BodyReadSourceLane::EpdocPackage,
                BodyReadSourceLane::EditorSnapshot,
                BodyReadSourceLane::TestFixture,
            ],
            projection_statuses: vec![
                ProjectionFreshnessStatus::Fresh,
                ProjectionFreshnessStatus::Missing,
                ProjectionFreshnessStatus::Stale,
                ProjectionFreshnessStatus::Failed,
                ProjectionFreshnessStatus::RetryScheduled,
            ],
            cache_reuse_policy: CacheReusePolicy::Denied,
            body_digest_required: true,
            body_digest_algorithm_label_required: true,
            body_byte_count_required: true,
            normalized_text_count_required: true,
            editor_snapshot_sequence_required: true,
            readable_block_projection_digest_required: true,
            graph_evidence_digest_required: true,
            prompt_assembly_digest_required: true,
            cache_salt_digest_required: true,
            managed_sidecar_first_required: true,
            r3_gateway_parity_required: true,
            blank_managed_body_authoritative: true,
            front_matter_policy_required: true,
            unicode_digest_fixture_required: true,
            body_read_parity_as_model_quality_proof: false,
            no_raw_body_in_artifact: true,
            no_raw_prompt_in_artifact: true,
            no_raw_model_token_in_artifact: true,
            no_hidden_chain: true,
            no_hidden_cache_authority: true,
            no_provider_call: true,
            answer_packet_caveat_hidden: false,
            l2_green_claimed: false,
            l3_green_claimed: false,
            product_green_claimed: false,
            live_dense_70b_claimed: false,
            body_bytes_read: 0,
            model_runtime_bytes_loaded: 0,
            cache_bytes_reused: 0,
            provider_calls_made: 0,
            rollback_ref: "rollback:body_read_checksum_release_blocker_card".to_string(),
            run_event_log_ref: "run_event_log:body_read_checksum_release_blocker_card".to_string(),
            answer_packet_ref: "answer_packet:body_read_checksum_release_blocker_card".to_string(),
        })
    }

    pub fn validate(&self) -> Result<(), BodyReadChecksumError> {
        validate_token("family_id", &self.family_id)?;
        if self.family_id != "body_read_checksum"
            || self.issue_count == 0
            || self.organ != BodyReadChecksumOrgan::BodyRead
            || self.status != BodyReadChecksumStatus::RedReleaseBlocker
        {
            return Err(BodyReadChecksumError::CardHeaderBroken);
        }
        validate_unique_exact_set("source_refs", &self.source_refs, &REQUIRED_SOURCE_REFS)?;
        validate_unique_exact_set(
            "required_invariants",
            &self.required_invariants,
            &REQUIRED_INVARIANTS,
        )?;
        validate_focused_commands(&self.focused_commands)?;
        validate_exact_enum_set(
            "body_source_lanes",
            &self.body_source_lanes,
            &[
                BodyReadSourceLane::ManagedSidecar,
                BodyReadSourceLane::R3ResourceGateway,
                BodyReadSourceLane::InlineBody,
                BodyReadSourceLane::RawVaultFile,
                BodyReadSourceLane::EpdocPackage,
                BodyReadSourceLane::EditorSnapshot,
                BodyReadSourceLane::TestFixture,
            ],
        )?;
        validate_exact_enum_set(
            "projection_statuses",
            &self.projection_statuses,
            &[
                ProjectionFreshnessStatus::Fresh,
                ProjectionFreshnessStatus::Missing,
                ProjectionFreshnessStatus::Stale,
                ProjectionFreshnessStatus::Failed,
                ProjectionFreshnessStatus::RetryScheduled,
            ],
        )?;
        for value in [
            &self.rollback_ref,
            &self.run_event_log_ref,
            &self.answer_packet_ref,
        ] {
            validate_token("proof_ref", value)?;
        }
        if self.cache_reuse_policy != CacheReusePolicy::Denied
            || !self.body_digest_required
            || !self.body_digest_algorithm_label_required
            || !self.body_byte_count_required
            || !self.normalized_text_count_required
            || !self.editor_snapshot_sequence_required
            || !self.readable_block_projection_digest_required
            || !self.graph_evidence_digest_required
            || !self.prompt_assembly_digest_required
            || !self.cache_salt_digest_required
            || !self.managed_sidecar_first_required
            || !self.r3_gateway_parity_required
            || !self.blank_managed_body_authoritative
            || !self.front_matter_policy_required
            || !self.unicode_digest_fixture_required
            || self.body_read_parity_as_model_quality_proof
            || !self.no_raw_body_in_artifact
            || !self.no_raw_prompt_in_artifact
            || !self.no_raw_model_token_in_artifact
            || !self.no_hidden_chain
            || !self.no_hidden_cache_authority
            || !self.no_provider_call
            || self.answer_packet_caveat_hidden
            || self.l2_green_claimed
            || self.l3_green_claimed
            || self.product_green_claimed
            || self.live_dense_70b_claimed
            || self.body_bytes_read != 0
            || self.model_runtime_bytes_loaded != 0
            || self.cache_bytes_reused != 0
            || self.provider_calls_made != 0
        {
            return Err(BodyReadChecksumError::PromotionBoundaryBroken);
        }
        Ok(())
    }
}

// UAS: uas:body-read-checksum-release-blocker-card:metrics
// Plane: Verification.
// Residency: aggregate freshness source-card metrics only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BodyReadChecksumMetrics {
    pub issue_count: u64,
    pub source_ref_count: usize,
    pub focused_command_count: usize,
    pub invariant_count: usize,
    pub source_lane_count: usize,
    pub projection_status_count: usize,
    pub body_bytes_read_total: u64,
    pub model_runtime_bytes_loaded: u64,
    pub cache_bytes_reused: u64,
    pub provider_calls_made: u64,
}

// UAS: uas:body-read-checksum-release-blocker-card:witness
// Plane: Verification.
// Residency: metadata-only body freshness source-card witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BodyReadChecksumReleaseBlockerWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_ref: String,
    pub family_source_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_next_cursor: String,
    pub card: BodyReadChecksumReleaseBlockerCard,
    pub metrics: BodyReadChecksumMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl BodyReadChecksumReleaseBlockerWitness {
    pub fn new(
        upstream_ref: &str,
        family_source_ref: &str,
        upstream_overall_pass: bool,
        upstream_next_cursor: &str,
        family_id: &str,
        issue_count: u64,
    ) -> Result<Self, BodyReadChecksumError> {
        validate_upstream_ref(upstream_ref)?;
        validate_family_source_ref(family_source_ref)?;
        validate_token("upstream_next_cursor", upstream_next_cursor)?;
        if !upstream_overall_pass {
            return Err(BodyReadChecksumError::UpstreamNotPassed);
        }
        if upstream_next_cursor != BODY_READ_CHECKSUM_RELEASE_BLOCKER_CARD_CURSOR {
            return Err(BodyReadChecksumError::WrongUpstreamCursor(
                upstream_next_cursor.to_string(),
            ));
        }
        let card = BodyReadChecksumReleaseBlockerCard::from_family(family_id, issue_count)?;
        card.validate()?;
        let metrics = BodyReadChecksumMetrics {
            issue_count: card.issue_count,
            source_ref_count: card.source_refs.len(),
            focused_command_count: card.focused_commands.len(),
            invariant_count: card.required_invariants.len(),
            source_lane_count: card.body_source_lanes.len(),
            projection_status_count: card.projection_statuses.len(),
            body_bytes_read_total: card.body_bytes_read,
            model_runtime_bytes_loaded: card.model_runtime_bytes_loaded,
            cache_bytes_reused: card.cache_bytes_reused,
            provider_calls_made: card.provider_calls_made,
        };
        let address = body_read_checksum_address(
            upstream_ref,
            family_source_ref,
            upstream_overall_pass,
            upstream_next_cursor,
            &card,
            &metrics,
        );
        Ok(Self {
            falsifier_id: BODY_READ_CHECKSUM_RELEASE_BLOCKER_CARD_ID.to_string(),
            cursor: BODY_READ_CHECKSUM_RELEASE_BLOCKER_CARD_CURSOR.to_string(),
            next_cursor: BODY_READ_CHECKSUM_RELEASE_BLOCKER_CARD_NEXT_CURSOR.to_string(),
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

    pub fn validate(&self) -> Result<(), BodyReadChecksumError> {
        if self.falsifier_id != BODY_READ_CHECKSUM_RELEASE_BLOCKER_CARD_ID
            || self.cursor != BODY_READ_CHECKSUM_RELEASE_BLOCKER_CARD_CURSOR
            || self.next_cursor != BODY_READ_CHECKSUM_RELEASE_BLOCKER_CARD_NEXT_CURSOR
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(BodyReadChecksumError::WitnessHeaderBroken);
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
            return Err(BodyReadChecksumError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_body_read_checksum_source_refs() -> &'static [&'static str] {
    &REQUIRED_SOURCE_REFS
}

pub fn required_body_read_checksum_invariants() -> &'static [&'static str] {
    &REQUIRED_INVARIANTS
}

fn body_read_checksum_address(
    upstream_ref: &str,
    family_source_ref: &str,
    upstream_overall_pass: bool,
    upstream_next_cursor: &str,
    card: &BodyReadChecksumReleaseBlockerCard,
    metrics: &BodyReadChecksumMetrics,
) -> String {
    let mut preimage = String::new();
    preimage.push_str(BODY_READ_CHECKSUM_RELEASE_BLOCKER_CARD_ID);
    preimage.push_str(BODY_READ_CHECKSUM_RELEASE_BLOCKER_CARD_CURSOR);
    preimage.push_str(BODY_READ_CHECKSUM_RELEASE_BLOCKER_CARD_NEXT_CURSOR);
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
) -> Result<(), BodyReadChecksumError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(BodyReadChecksumError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    let actual = values.iter().map(String::as_str).collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected {
        return Err(BodyReadChecksumError::MissingRequiredSet {
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
) -> Result<(), BodyReadChecksumError>
where
    T: Copy + Ord + fmt::Debug,
{
    let actual = values.iter().copied().collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected || values.len() != actual.len() {
        return Err(BodyReadChecksumError::BadEnumSet {
            field,
            actual: values.len(),
            expected: required.len(),
        });
    }
    Ok(())
}

fn validate_focused_commands(values: &[String]) -> Result<(), BodyReadChecksumError> {
    if values.len() < 5 || values.len() > 8 {
        return Err(BodyReadChecksumError::BadListLength {
            field: "focused_commands",
            actual: values.len(),
        });
    }
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text("focused_commands", value)?;
        if !seen.insert(value.as_str()) {
            return Err(BodyReadChecksumError::DuplicateValue {
                field: "focused_commands",
                value: value.to_string(),
            });
        }
        if !(value.starts_with("xcodebuild test -only-testing:EpistemosTests/")
            && (value.contains("BodyRead")
                || value.contains("NoteChat")
                || value.contains("ResourceRuntime")
                || value.contains("RuntimeValidation")
                || value.contains("AIPartner")))
        {
            return Err(BodyReadChecksumError::BadFocusedCommand);
        }
    }
    Ok(())
}

fn validate_upstream_ref(value: &str) -> Result<(), BodyReadChecksumError> {
    validate_token("upstream_ref", value)?;
    if !value.starts_with("artifact:falsifiers/runtime_performance_policy_release_blocker_card/")
        || !value.contains("/result.json#F-RuntimePerformancePolicy-ReleaseBlockerCard")
    {
        return Err(BodyReadChecksumError::BadUpstreamRef);
    }
    Ok(())
}

fn validate_family_source_ref(value: &str) -> Result<(), BodyReadChecksumError> {
    validate_token("family_source_ref", value)?;
    if !value.starts_with("artifact:falsifiers/release_audit_failure_family_source_card/")
        || !value.contains("/result.json#body_read_checksum")
    {
        return Err(BodyReadChecksumError::BadFamilySourceRef);
    }
    Ok(())
}

fn validate_token(field: &'static str, value: &str) -> Result<(), BodyReadChecksumError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(BodyReadChecksumError::InvalidToken {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_text(field: &'static str, value: &str) -> Result<(), BodyReadChecksumError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(BodyReadChecksumError::InvalidText {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

// UAS: uas:body-read-checksum-release-blocker-card:error
// Plane: Verification.
// Residency: fail-closed metadata validation errors.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum BodyReadChecksumError {
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
    UpstreamNotPassed,
    WrongUpstreamCursor(String),
    WrongFamily(String),
    ZeroIssueCount,
    CardHeaderBroken,
    PromotionBoundaryBroken,
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for BodyReadChecksumError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for BodyReadChecksumError {}

#[cfg(test)]
mod tests {
    use super::*;

    fn witness() -> BodyReadChecksumReleaseBlockerWitness {
        BodyReadChecksumReleaseBlockerWitness::new(
            BODY_READ_CHECKSUM_UPSTREAM_REF,
            BODY_READ_CHECKSUM_FAMILY_SOURCE_REF,
            true,
            BODY_READ_CHECKSUM_RELEASE_BLOCKER_CARD_CURSOR,
            "body_read_checksum",
            1,
        )
        .expect("valid body read checksum blocker witness")
    }

    #[test]
    fn accepts_body_read_checksum_card() {
        let witness = witness();
        assert_eq!(witness.card.issue_count, 1);
        assert_eq!(witness.metrics.source_ref_count, REQUIRED_SOURCE_REFS.len());
        assert_eq!(witness.metrics.invariant_count, REQUIRED_INVARIANTS.len());
        assert_eq!(witness.metrics.body_bytes_read_total, 0);
        assert!(witness.metadata_only);
        assert!(witness.no_product_promotion);
        assert!(witness.address.starts_with("sha256:"));
        witness.validate().expect("witness validates");
    }

    #[test]
    fn rejects_wrong_upstream_or_family() {
        assert!(BodyReadChecksumReleaseBlockerWitness::new(
            BODY_READ_CHECKSUM_UPSTREAM_REF,
            BODY_READ_CHECKSUM_FAMILY_SOURCE_REF,
            false,
            BODY_READ_CHECKSUM_RELEASE_BLOCKER_CARD_CURSOR,
            "body_read_checksum",
            1,
        )
        .is_err());
        assert!(BodyReadChecksumReleaseBlockerWitness::new(
            BODY_READ_CHECKSUM_UPSTREAM_REF,
            BODY_READ_CHECKSUM_FAMILY_SOURCE_REF,
            true,
            "runtime_performance_policy_release_blocker_card",
            "body_read_checksum",
            1,
        )
        .is_err());
        assert!(BodyReadChecksumReleaseBlockerWitness::new(
            BODY_READ_CHECKSUM_UPSTREAM_REF,
            BODY_READ_CHECKSUM_FAMILY_SOURCE_REF,
            true,
            BODY_READ_CHECKSUM_RELEASE_BLOCKER_CARD_CURSOR,
            "runtime_performance_policy",
            1,
        )
        .is_err());
    }

    #[test]
    fn rejects_freshness_gaps_and_byte_leaks() {
        let mut card = witness().card;
        card.managed_sidecar_first_required = false;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.prompt_assembly_digest_required = false;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.no_raw_body_in_artifact = false;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.cache_bytes_reused = 1;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.product_green_claimed = true;
        assert!(card.validate().is_err());
    }
}
