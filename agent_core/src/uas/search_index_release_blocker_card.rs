use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::error::Error;
use std::fmt;

pub const SEARCH_INDEX_RELEASE_BLOCKER_CARD_ID: &str = "F-SearchIndex-ReleaseBlockerCard";
pub const SEARCH_INDEX_RELEASE_BLOCKER_CARD_CURSOR: &str = "search_index_release_blocker_card";
pub const SEARCH_INDEX_RELEASE_BLOCKER_CARD_NEXT_CURSOR: &str =
    "source_guard_drift_release_blocker_card";
pub const SEARCH_INDEX_UPSTREAM_REF: &str = "artifact:falsifiers/body_read_checksum_release_blocker_card/result.json#F-BodyReadChecksum-ReleaseBlockerCard";
pub const SEARCH_INDEX_FAMILY_SOURCE_REF: &str =
    "artifact:falsifiers/release_audit_failure_family_source_card/result.json#search_index";

const REQUIRED_SOURCE_REFS: [&str; 13] = [
    "Epistemos/Sync/SearchIndexService.swift",
    "Epistemos/Sync/RRFFusionQuery.swift",
    "Epistemos/Sync/ReadableBlocksIndex.swift",
    "Epistemos/Sync/ReadableBlocksProjector.swift",
    "Epistemos/Sync/VaultSyncService.swift",
    "Epistemos/Engine/QueryRuntime.swift",
    "Epistemos/Engine/QueryTypes.swift",
    "Epistemos/Graph/GraphState.swift",
    "Epistemos/Graph/GraphStore.swift",
    "EpistemosTests/SearchIndexTests.swift",
    "EpistemosTests/RRFFusionQueryTests.swift",
    "EpistemosTests/QueryRuntimeTests.swift",
    "docs/RRF_FUSION_DESIGN.md",
];

const REQUIRED_INVARIANTS: [&str; 16] = [
    "upstream_body_read_freshness_bound",
    "external_content_fts_trigger_required",
    "external_content_rebuild_fallback_required",
    "query_parser_fallback_required",
    "rrf_k_parity_required",
    "bm25_rank_convention_required",
    "recency_half_life_policy_required",
    "vault_scope_filter_required",
    "graph_evidence_digest_required",
    "search_output_is_evidence_not_route_authority",
    "turbovec_allowlist_before_rank_required",
    "gemma_qat_replay_requires_search_freshness_ref",
    "kv_cache_reuse_requires_search_lineage_salt",
    "no_raw_query_body_or_snippet_in_artifact",
    "rollback_run_event_log_answer_packet_required",
    "no_l2_l3_product_green_or_live_dense_70b",
];

// UAS: uas:search-index-release-blocker-card:organ
// Plane: Verification.
// Residency: metadata-only search freshness source-card classification.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SearchIndexOrgan {
    SearchIndex,
    RrfFusion,
    ReadableBlocks,
    QueryRuntime,
    GraphEvidence,
    EidosRecall,
    CacheLineage,
}

// UAS: uas:search-index-release-blocker-card:status
// Plane: Verification.
// Residency: retained release blocker classification only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SearchIndexStatus {
    RedReleaseBlocker,
}

// UAS: uas:search-index-release-blocker-card:retrieval-lane
// Plane: State + Verification.
// Residency: retrieval source taxonomy; no database/body/index bytes opened.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SearchRetrievalLane {
    PageFts,
    ReadableBlockFts,
    RrfFusion,
    GraphEvidence,
    EidosPrior,
    TurbovecCache,
    QueryRuntimeFixture,
}

// UAS: uas:search-index-release-blocker-card:rank-policy
// Plane: Controller + Verification.
// Residency: ranking policy taxonomy; no live search route authority.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SearchRankPolicy {
    Bm25,
    RrfK,
    RecencyHalfLife,
    VaultScopeFilter,
    AbstainOnStaleIndex,
}

// UAS: uas:search-index-release-blocker-card:authority
// Plane: Controller + Verification.
// Residency: explicit no-hidden-authority gate for Eidos/TurboVec/search.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SearchAuthorityPolicy {
    EvidenceOnly,
}

// UAS: uas:search-index-release-blocker-card:card
// Plane: Verification.
// Residency: metadata-only search freshness source-card; no user/model bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SearchIndexReleaseBlockerCard {
    pub family_id: String,
    pub issue_count: u64,
    pub organ: SearchIndexOrgan,
    pub status: SearchIndexStatus,
    pub source_refs: Vec<String>,
    pub focused_commands: Vec<String>,
    pub required_invariants: Vec<String>,
    pub retrieval_lanes: Vec<SearchRetrievalLane>,
    pub rank_policies: Vec<SearchRankPolicy>,
    pub authority_policy: SearchAuthorityPolicy,
    pub upstream_body_read_freshness_required: bool,
    pub external_content_fts_trigger_required: bool,
    pub external_content_rebuild_fallback_required: bool,
    pub query_parser_fallback_required: bool,
    pub rrf_k_parity_required: bool,
    pub bm25_rank_convention_required: bool,
    pub recency_half_life_policy_required: bool,
    pub vault_scope_filter_required: bool,
    pub graph_evidence_digest_required: bool,
    pub turbovec_allowlist_before_rank_required: bool,
    pub gemma_qat_replay_search_freshness_required: bool,
    pub kv_cache_lineage_salt_required: bool,
    pub no_raw_query_in_artifact: bool,
    pub no_raw_body_in_artifact: bool,
    pub no_raw_snippet_in_artifact: bool,
    pub no_hidden_chain: bool,
    pub no_hidden_search_authority: bool,
    pub no_hidden_eidos_authority: bool,
    pub no_hidden_turbovec_authority: bool,
    pub no_provider_call: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub product_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub db_bytes_opened: u64,
    pub body_bytes_read: u64,
    pub snippet_bytes_embedded: u64,
    pub model_runtime_bytes_loaded: u64,
    pub cache_bytes_reused: u64,
    pub provider_calls_made: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
}

impl SearchIndexReleaseBlockerCard {
    pub fn from_family(family_id: &str, issue_count: u64) -> Result<Self, SearchIndexError> {
        validate_token("family_id", family_id)?;
        if family_id != "search_index" {
            return Err(SearchIndexError::WrongFamily(family_id.to_string()));
        }
        if issue_count == 0 {
            return Err(SearchIndexError::ZeroIssueCount);
        }
        Ok(Self {
            family_id: family_id.to_string(),
            issue_count,
            organ: SearchIndexOrgan::SearchIndex,
            status: SearchIndexStatus::RedReleaseBlocker,
            source_refs: REQUIRED_SOURCE_REFS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            focused_commands: vec![
                "xcodebuild test -only-testing:EpistemosTests/SearchIndexTests".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/SearchIndexServiceIntegrationTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/RRFFusionQueryTests".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/ReadableBlocksIndexTests".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/ReadableBlocksProjectorTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/QueryRuntimeTests".to_string(),
            ],
            required_invariants: REQUIRED_INVARIANTS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            retrieval_lanes: vec![
                SearchRetrievalLane::PageFts,
                SearchRetrievalLane::ReadableBlockFts,
                SearchRetrievalLane::RrfFusion,
                SearchRetrievalLane::GraphEvidence,
                SearchRetrievalLane::EidosPrior,
                SearchRetrievalLane::TurbovecCache,
                SearchRetrievalLane::QueryRuntimeFixture,
            ],
            rank_policies: vec![
                SearchRankPolicy::Bm25,
                SearchRankPolicy::RrfK,
                SearchRankPolicy::RecencyHalfLife,
                SearchRankPolicy::VaultScopeFilter,
                SearchRankPolicy::AbstainOnStaleIndex,
            ],
            authority_policy: SearchAuthorityPolicy::EvidenceOnly,
            upstream_body_read_freshness_required: true,
            external_content_fts_trigger_required: true,
            external_content_rebuild_fallback_required: true,
            query_parser_fallback_required: true,
            rrf_k_parity_required: true,
            bm25_rank_convention_required: true,
            recency_half_life_policy_required: true,
            vault_scope_filter_required: true,
            graph_evidence_digest_required: true,
            turbovec_allowlist_before_rank_required: true,
            gemma_qat_replay_search_freshness_required: true,
            kv_cache_lineage_salt_required: true,
            no_raw_query_in_artifact: true,
            no_raw_body_in_artifact: true,
            no_raw_snippet_in_artifact: true,
            no_hidden_chain: true,
            no_hidden_search_authority: true,
            no_hidden_eidos_authority: true,
            no_hidden_turbovec_authority: true,
            no_provider_call: true,
            l2_green_claimed: false,
            l3_green_claimed: false,
            product_green_claimed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
            db_bytes_opened: 0,
            body_bytes_read: 0,
            snippet_bytes_embedded: 0,
            model_runtime_bytes_loaded: 0,
            cache_bytes_reused: 0,
            provider_calls_made: 0,
            rollback_ref: "rollback:search_index_release_blocker_card".to_string(),
            run_event_log_ref: "run_event_log:search_index_release_blocker_card".to_string(),
            answer_packet_ref: "answer_packet:search_index_release_blocker_card".to_string(),
        })
    }

    pub fn validate(&self) -> Result<(), SearchIndexError> {
        validate_token("family_id", &self.family_id)?;
        if self.family_id != "search_index"
            || self.issue_count == 0
            || self.organ != SearchIndexOrgan::SearchIndex
            || self.status != SearchIndexStatus::RedReleaseBlocker
        {
            return Err(SearchIndexError::CardHeaderBroken);
        }
        validate_unique_exact_set("source_refs", &self.source_refs, &REQUIRED_SOURCE_REFS)?;
        validate_unique_exact_set(
            "required_invariants",
            &self.required_invariants,
            &REQUIRED_INVARIANTS,
        )?;
        validate_focused_commands(&self.focused_commands)?;
        validate_exact_enum_set(
            "retrieval_lanes",
            &self.retrieval_lanes,
            &[
                SearchRetrievalLane::PageFts,
                SearchRetrievalLane::ReadableBlockFts,
                SearchRetrievalLane::RrfFusion,
                SearchRetrievalLane::GraphEvidence,
                SearchRetrievalLane::EidosPrior,
                SearchRetrievalLane::TurbovecCache,
                SearchRetrievalLane::QueryRuntimeFixture,
            ],
        )?;
        validate_exact_enum_set(
            "rank_policies",
            &self.rank_policies,
            &[
                SearchRankPolicy::Bm25,
                SearchRankPolicy::RrfK,
                SearchRankPolicy::RecencyHalfLife,
                SearchRankPolicy::VaultScopeFilter,
                SearchRankPolicy::AbstainOnStaleIndex,
            ],
        )?;
        for value in [
            &self.rollback_ref,
            &self.run_event_log_ref,
            &self.answer_packet_ref,
        ] {
            validate_token("proof_ref", value)?;
        }
        if self.authority_policy != SearchAuthorityPolicy::EvidenceOnly
            || !self.upstream_body_read_freshness_required
            || !self.external_content_fts_trigger_required
            || !self.external_content_rebuild_fallback_required
            || !self.query_parser_fallback_required
            || !self.rrf_k_parity_required
            || !self.bm25_rank_convention_required
            || !self.recency_half_life_policy_required
            || !self.vault_scope_filter_required
            || !self.graph_evidence_digest_required
            || !self.turbovec_allowlist_before_rank_required
            || !self.gemma_qat_replay_search_freshness_required
            || !self.kv_cache_lineage_salt_required
            || !self.no_raw_query_in_artifact
            || !self.no_raw_body_in_artifact
            || !self.no_raw_snippet_in_artifact
            || !self.no_hidden_chain
            || !self.no_hidden_search_authority
            || !self.no_hidden_eidos_authority
            || !self.no_hidden_turbovec_authority
            || !self.no_provider_call
            || self.l2_green_claimed
            || self.l3_green_claimed
            || self.product_green_claimed
            || self.live_dense_70b_claimed
            || self.ssd_as_ram_claimed
            || self.db_bytes_opened != 0
            || self.body_bytes_read != 0
            || self.snippet_bytes_embedded != 0
            || self.model_runtime_bytes_loaded != 0
            || self.cache_bytes_reused != 0
            || self.provider_calls_made != 0
        {
            return Err(SearchIndexError::PromotionBoundaryBroken);
        }
        Ok(())
    }
}

// UAS: uas:search-index-release-blocker-card:metrics
// Plane: Verification.
// Residency: aggregate search freshness source-card metrics only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SearchIndexMetrics {
    pub issue_count: u64,
    pub source_ref_count: usize,
    pub focused_command_count: usize,
    pub invariant_count: usize,
    pub retrieval_lane_count: usize,
    pub rank_policy_count: usize,
    pub db_bytes_opened: u64,
    pub body_bytes_read: u64,
    pub snippet_bytes_embedded: u64,
    pub model_runtime_bytes_loaded: u64,
    pub cache_bytes_reused: u64,
    pub provider_calls_made: u64,
}

// UAS: uas:search-index-release-blocker-card:witness
// Plane: Verification.
// Residency: metadata-only search freshness source-card witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SearchIndexReleaseBlockerWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_ref: String,
    pub family_source_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_next_cursor: String,
    pub card: SearchIndexReleaseBlockerCard,
    pub metrics: SearchIndexMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl SearchIndexReleaseBlockerWitness {
    pub fn new(
        upstream_ref: &str,
        family_source_ref: &str,
        upstream_overall_pass: bool,
        upstream_next_cursor: &str,
        family_id: &str,
        issue_count: u64,
    ) -> Result<Self, SearchIndexError> {
        validate_upstream_ref(upstream_ref)?;
        validate_family_source_ref(family_source_ref)?;
        validate_token("upstream_next_cursor", upstream_next_cursor)?;
        if !upstream_overall_pass {
            return Err(SearchIndexError::UpstreamNotPassed);
        }
        if upstream_next_cursor != SEARCH_INDEX_RELEASE_BLOCKER_CARD_CURSOR {
            return Err(SearchIndexError::WrongUpstreamCursor(
                upstream_next_cursor.to_string(),
            ));
        }
        let card = SearchIndexReleaseBlockerCard::from_family(family_id, issue_count)?;
        card.validate()?;
        let metrics = SearchIndexMetrics {
            issue_count: card.issue_count,
            source_ref_count: card.source_refs.len(),
            focused_command_count: card.focused_commands.len(),
            invariant_count: card.required_invariants.len(),
            retrieval_lane_count: card.retrieval_lanes.len(),
            rank_policy_count: card.rank_policies.len(),
            db_bytes_opened: card.db_bytes_opened,
            body_bytes_read: card.body_bytes_read,
            snippet_bytes_embedded: card.snippet_bytes_embedded,
            model_runtime_bytes_loaded: card.model_runtime_bytes_loaded,
            cache_bytes_reused: card.cache_bytes_reused,
            provider_calls_made: card.provider_calls_made,
        };
        let address = search_index_address(
            upstream_ref,
            family_source_ref,
            upstream_overall_pass,
            upstream_next_cursor,
            &card,
            &metrics,
        );
        Ok(Self {
            falsifier_id: SEARCH_INDEX_RELEASE_BLOCKER_CARD_ID.to_string(),
            cursor: SEARCH_INDEX_RELEASE_BLOCKER_CARD_CURSOR.to_string(),
            next_cursor: SEARCH_INDEX_RELEASE_BLOCKER_CARD_NEXT_CURSOR.to_string(),
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

    pub fn validate(&self) -> Result<(), SearchIndexError> {
        if self.falsifier_id != SEARCH_INDEX_RELEASE_BLOCKER_CARD_ID
            || self.cursor != SEARCH_INDEX_RELEASE_BLOCKER_CARD_CURSOR
            || self.next_cursor != SEARCH_INDEX_RELEASE_BLOCKER_CARD_NEXT_CURSOR
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(SearchIndexError::WitnessHeaderBroken);
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
            return Err(SearchIndexError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_search_index_source_refs() -> &'static [&'static str] {
    &REQUIRED_SOURCE_REFS
}

pub fn required_search_index_invariants() -> &'static [&'static str] {
    &REQUIRED_INVARIANTS
}

fn search_index_address(
    upstream_ref: &str,
    family_source_ref: &str,
    upstream_overall_pass: bool,
    upstream_next_cursor: &str,
    card: &SearchIndexReleaseBlockerCard,
    metrics: &SearchIndexMetrics,
) -> String {
    let mut preimage = String::new();
    preimage.push_str(SEARCH_INDEX_RELEASE_BLOCKER_CARD_ID);
    preimage.push_str(SEARCH_INDEX_RELEASE_BLOCKER_CARD_CURSOR);
    preimage.push_str(SEARCH_INDEX_RELEASE_BLOCKER_CARD_NEXT_CURSOR);
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
) -> Result<(), SearchIndexError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(SearchIndexError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    let actual = values.iter().map(String::as_str).collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected {
        return Err(SearchIndexError::MissingRequiredSet {
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
) -> Result<(), SearchIndexError>
where
    T: Copy + Ord + fmt::Debug,
{
    let actual = values.iter().copied().collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected || values.len() != actual.len() {
        return Err(SearchIndexError::BadEnumSet {
            field,
            actual: values.len(),
            expected: required.len(),
        });
    }
    Ok(())
}

fn validate_focused_commands(values: &[String]) -> Result<(), SearchIndexError> {
    if values.len() < 5 || values.len() > 8 {
        return Err(SearchIndexError::BadListLength {
            field: "focused_commands",
            actual: values.len(),
        });
    }
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text("focused_commands", value)?;
        if !seen.insert(value.as_str()) {
            return Err(SearchIndexError::DuplicateValue {
                field: "focused_commands",
                value: value.to_string(),
            });
        }
        if !(value.starts_with("xcodebuild test -only-testing:EpistemosTests/")
            && (value.contains("SearchIndex")
                || value.contains("RRF")
                || value.contains("ReadableBlocks")
                || value.contains("QueryRuntime")))
        {
            return Err(SearchIndexError::BadFocusedCommand);
        }
    }
    Ok(())
}

fn validate_upstream_ref(value: &str) -> Result<(), SearchIndexError> {
    validate_token("upstream_ref", value)?;
    if !value.starts_with("artifact:falsifiers/body_read_checksum_release_blocker_card/")
        || !value.contains("/result.json#F-BodyReadChecksum-ReleaseBlockerCard")
    {
        return Err(SearchIndexError::BadUpstreamRef);
    }
    Ok(())
}

fn validate_family_source_ref(value: &str) -> Result<(), SearchIndexError> {
    validate_token("family_source_ref", value)?;
    if !value.starts_with("artifact:falsifiers/release_audit_failure_family_source_card/")
        || !value.contains("/result.json#search_index")
    {
        return Err(SearchIndexError::BadFamilySourceRef);
    }
    Ok(())
}

fn validate_token(field: &'static str, value: &str) -> Result<(), SearchIndexError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(SearchIndexError::InvalidToken {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_text(field: &'static str, value: &str) -> Result<(), SearchIndexError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(SearchIndexError::InvalidText {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

// UAS: uas:search-index-release-blocker-card:error
// Plane: Verification.
// Residency: fail-closed metadata validation errors.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SearchIndexError {
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

impl fmt::Display for SearchIndexError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{self:?}")
    }
}

impl Error for SearchIndexError {}

#[cfg(test)]
mod tests {
    use super::*;

    fn witness() -> SearchIndexReleaseBlockerWitness {
        SearchIndexReleaseBlockerWitness::new(
            SEARCH_INDEX_UPSTREAM_REF,
            SEARCH_INDEX_FAMILY_SOURCE_REF,
            true,
            SEARCH_INDEX_RELEASE_BLOCKER_CARD_CURSOR,
            "search_index",
            1,
        )
        .expect("valid search index witness")
    }

    #[test]
    fn valid_witness_is_metadata_only_and_stable() {
        let witness = witness();
        assert!(witness.validate().is_ok());
        assert_eq!(witness.card.db_bytes_opened, 0);
        assert_eq!(witness.card.body_bytes_read, 0);
        assert_eq!(witness.card.model_runtime_bytes_loaded, 0);
        assert!(witness.metadata_only);
        assert!(witness.no_product_promotion);
        assert_eq!(
            witness.metrics.source_ref_count,
            required_search_index_source_refs().len()
        );
        assert_eq!(
            witness.metrics.invariant_count,
            required_search_index_invariants().len()
        );
    }

    #[test]
    fn rejects_wrong_family_and_zero_issues() {
        assert!(SearchIndexReleaseBlockerWitness::new(
            SEARCH_INDEX_UPSTREAM_REF,
            SEARCH_INDEX_FAMILY_SOURCE_REF,
            true,
            SEARCH_INDEX_RELEASE_BLOCKER_CARD_CURSOR,
            "body_read_checksum",
            1,
        )
        .is_err());
        assert!(SearchIndexReleaseBlockerWitness::new(
            SEARCH_INDEX_UPSTREAM_REF,
            SEARCH_INDEX_FAMILY_SOURCE_REF,
            true,
            SEARCH_INDEX_RELEASE_BLOCKER_CARD_CURSOR,
            "search_index",
            0,
        )
        .is_err());
    }

    #[test]
    fn rejects_missing_sources_invariants_and_broad_commands() {
        let mut card = witness().card;
        card.source_refs
            .retain(|value| value != "Epistemos/Sync/SearchIndexService.swift");
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.required_invariants
            .retain(|value| value != "rrf_k_parity_required");
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.focused_commands[0] = "xcodebuild test -only-testing:EpistemosTests".to_string();
        assert!(card.validate().is_err());
    }

    #[test]
    fn rejects_hidden_authority_and_false_promotion() {
        let mut card = witness().card;
        card.no_hidden_eidos_authority = false;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.product_green_claimed = true;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.live_dense_70b_claimed = true;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.ssd_as_ram_claimed = true;
        assert!(card.validate().is_err());
    }

    #[test]
    fn rejects_byte_and_provider_leaks() {
        let mut card = witness().card;
        card.db_bytes_opened = 1;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.snippet_bytes_embedded = 1;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.provider_calls_made = 1;
        assert!(card.validate().is_err());
    }
}
