//! KV cache lineage deletion fence.
//!
//! Metadata-only source-card fence for persistent KV/prompt-cache reuse. It
//! binds source freshness, prompt/runtime identity, cache salt, privacy scope,
//! tombstone/purge policy, rollback, RunEventLog, and AnswerPacket before
//! cache state can influence RuntimeRouter/System G.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{ProStatus, ProductBuild, UasAddress, UasKind};

pub const KV_CACHE_LINEAGE_DELETION_FENCE_ID: &str = "F-KVCacheLineageDeletionFence";
pub const KV_CACHE_LINEAGE_DELETION_FENCE_CURSOR: &str = "kv_cache_lineage_deletion_fence";
pub const KV_CACHE_LINEAGE_DELETION_FENCE_NEXT_CURSOR: &str =
    "same_fixture_runtime_replay_envelope";

const UPSTREAM_OFFLOAD_CARD: &str = "F-KVOffloadTierBudgetEnvelope";
const UPSTREAM_OFFLOAD_ARTIFACT: &str =
    "artifacts/falsifiers/kv_offload_tier_budget_envelope/result.json";
const SHA256_PREFIX: &str = "sha256:";
const SCOPE_PREFIX: &str = "scope:";
const TRUST_PREFIX: &str = "trust_group:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const ABSTENTION_PREFIX: &str = "abstain:";
const TOMBSTONE_PREFIX: &str = "tombstone:";
const PURGE_PREFIX: &str = "purge:";
const CAVEAT_PREFIX: &str = "caveat:";
const MAX_FENCE_METADATA_BYTES: u64 = 192 * 1024;
const MAX_PLAN_METADATA_BYTES: u64 = 96 * 1024;

// UAS: uas:kv-cache-lineage-deletion:source
// Plane: State + Verification.
// Residency: source-card motif only; no cache bytes are opened.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KvCacheLineageSource {
    VllmPrefixCaching,
    LmcacheLocalStorage,
    LlamaCppSlotPromptCache,
    PromptCacheModule,
    AgentMemoryKv,
    EpistemosBodyReadFreshness,
}

// UAS: uas:kv-cache-lineage-deletion:boundary
// Plane: State.
// Residency: identity component that must match before reuse.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KvCacheLineageBoundary {
    SourceBodyDigest,
    SearchResultDigest,
    PromptDigest,
    TokenizerDigest,
    ChatTemplateDigest,
    ToolSchemaDigest,
    ModelRevisionDigest,
    AdapterDigest,
    CacheSalt,
    PrivacyScope,
}

// UAS: uas:kv-cache-lineage-deletion:lifecycle
// Plane: State + Verification.
// Residency: metadata lifecycle state only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KvCacheLineageLifecycle {
    Active,
    Tombstoned,
    Purged,
}

// UAS: uas:kv-cache-lineage-deletion:proof-refs
// Plane: Verification.
// Residency: visible proof handles only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvCacheLineageProofRefs {
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub tombstone_ref: String,
    pub purge_ref: String,
    pub caveat_ref: String,
}

// UAS: uas:kv-cache-lineage-deletion:byte-ledger
// Plane: Verification.
// Residency: byte accounting; all opened/loaded bytes must remain zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvCacheLineageByteLedger {
    pub kv_bytes_loaded: u64,
    pub cache_bytes_opened: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub source_tree_bytes_opened: u64,
    pub benchmark_bytes_opened: u64,
    pub product_bytes_opened: u64,
    pub provider_calls_made: u64,
}

impl KvCacheLineageByteLedger {
    pub fn metadata_only() -> Self {
        Self {
            kv_bytes_loaded: 0,
            cache_bytes_opened: 0,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            source_tree_bytes_opened: 0,
            benchmark_bytes_opened: 0,
            product_bytes_opened: 0,
            provider_calls_made: 0,
        }
    }
}

// UAS: uas:kv-cache-lineage-deletion:plan
// Plane: State + Controller + Verification.
// Residency: metadata-only reuse fence; not a live cache.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvCacheLineageDeletionPlan {
    pub plan_id: String,
    pub upstream_falsifier_id: String,
    pub upstream_artifact_path: String,
    pub source_refs: Vec<KvCacheLineageSource>,
    pub source_ref_digest: String,
    pub boundaries: Vec<KvCacheLineageBoundary>,
    pub boundary_digest: String,
    pub lifecycle_states: Vec<KvCacheLineageLifecycle>,
    pub source_body_digest: String,
    pub search_result_digest: String,
    pub prompt_digest: String,
    pub tokenizer_digest: String,
    pub chat_template_digest: String,
    pub tool_schema_digest: String,
    pub model_revision_digest: String,
    pub adapter_digest: String,
    pub cache_salt_digest: String,
    pub privacy_scope_ref: String,
    pub trust_group_ref: String,
    pub allowlist_before_reuse: bool,
    pub stale_source_reuse_denied: bool,
    pub identity_drift_reuse_denied: bool,
    pub tombstone_blocks_reuse: bool,
    pub purge_deletes_material: bool,
    pub deletion_is_visible: bool,
    pub cache_hit_quality_claimed: bool,
    pub cache_hit_model_fit_claimed: bool,
    pub restored_cache_route_authority: bool,
    pub hidden_cache_authority: bool,
    pub command_armed: bool,
    pub server_started: bool,
    pub raw_prompt_logged: bool,
    pub raw_token_logged: bool,
    pub byte_ledger: KvCacheLineageByteLedger,
    pub proof_refs: KvCacheLineageProofRefs,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_bytes: u64,
    pub mas_promoted: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:kv-cache-lineage-deletion:fence
// Plane: Verification.
// Residency: metadata-only witness envelope.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvCacheLineageDeletionFence {
    pub fence_address: UasAddress,
    pub plan: KvCacheLineageDeletionPlan,
    pub metadata_bytes: u64,
    pub metadata_only: bool,
    pub no_runtime_execution: bool,
    pub product_promotion_blocked: bool,
}

// UAS: uas:kv-cache-lineage-deletion:metrics
// Plane: Verification.
// Residency: derived counters for artifact axes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvCacheLineageDeletionMetrics {
    pub plan_count: u64,
    pub source_ref_count: u64,
    pub boundary_count: u64,
    pub lifecycle_state_count: u64,
    pub kv_bytes_loaded: u64,
    pub cache_bytes_opened: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub source_tree_bytes_opened: u64,
    pub benchmark_bytes_opened: u64,
    pub product_bytes_opened: u64,
    pub provider_calls_made: u64,
    pub cache_hit_quality_claim_count: u64,
    pub cache_hit_model_fit_claim_count: u64,
    pub route_authority_count: u64,
    pub hidden_cache_authority_count: u64,
    pub command_armed_count: u64,
    pub server_started_count: u64,
    pub raw_prompt_logged_count: u64,
    pub raw_token_logged_count: u64,
    pub mas_promotion_count: u64,
    pub l2_green_claim_count: u64,
    pub l3_green_claim_count: u64,
    pub live_dense_70b_claim_count: u64,
    pub ssd_as_ram_claim_count: u64,
}

impl KvCacheLineageDeletionFence {
    pub fn new(
        mut plan: KvCacheLineageDeletionPlan,
        metadata_bytes: u64,
        created_at_ms: u64,
    ) -> Result<Self, KvCacheLineageDeletionError> {
        validate_plan(&plan)?;
        if metadata_bytes == 0 || metadata_bytes > MAX_FENCE_METADATA_BYTES {
            return Err(KvCacheLineageDeletionError::MetadataBudget);
        }
        plan.source_refs.sort();
        plan.boundaries.sort();
        plan.lifecycle_states.sort();
        let preimage = fence_preimage(&plan, metadata_bytes);
        Ok(Self {
            fence_address: UasAddress::new(
                UasKind::Other(KV_CACHE_LINEAGE_DELETION_FENCE_CURSOR.to_string()),
                preimage.as_bytes(),
                created_at_ms,
            ),
            plan,
            metadata_bytes,
            metadata_only: true,
            no_runtime_execution: true,
            product_promotion_blocked: true,
        })
    }

    pub fn metrics(&self) -> KvCacheLineageDeletionMetrics {
        let plan = &self.plan;
        let ledger = &plan.byte_ledger;
        KvCacheLineageDeletionMetrics {
            plan_count: 1,
            source_ref_count: unique_source_ref_count(&plan.source_refs),
            boundary_count: unique_boundary_count(&plan.boundaries),
            lifecycle_state_count: unique_lifecycle_state_count(&plan.lifecycle_states),
            kv_bytes_loaded: ledger.kv_bytes_loaded,
            cache_bytes_opened: ledger.cache_bytes_opened,
            model_bytes_loaded: ledger.model_bytes_loaded,
            runtime_bytes_loaded: ledger.runtime_bytes_loaded,
            source_tree_bytes_opened: ledger.source_tree_bytes_opened,
            benchmark_bytes_opened: ledger.benchmark_bytes_opened,
            product_bytes_opened: ledger.product_bytes_opened,
            provider_calls_made: ledger.provider_calls_made,
            cache_hit_quality_claim_count: u64::from(plan.cache_hit_quality_claimed),
            cache_hit_model_fit_claim_count: u64::from(plan.cache_hit_model_fit_claimed),
            route_authority_count: u64::from(plan.restored_cache_route_authority),
            hidden_cache_authority_count: u64::from(plan.hidden_cache_authority),
            command_armed_count: u64::from(plan.command_armed),
            server_started_count: u64::from(plan.server_started),
            raw_prompt_logged_count: u64::from(plan.raw_prompt_logged),
            raw_token_logged_count: u64::from(plan.raw_token_logged),
            mas_promotion_count: u64::from(plan.mas_promoted),
            l2_green_claim_count: u64::from(plan.l2_green_claimed),
            l3_green_claim_count: u64::from(plan.l3_green_claimed),
            live_dense_70b_claim_count: u64::from(plan.live_dense_70b_claimed),
            ssd_as_ram_claim_count: u64::from(plan.ssd_as_ram_claimed),
        }
    }
}

pub fn canonical_kv_cache_lineage_deletion_plan() -> KvCacheLineageDeletionPlan {
    KvCacheLineageDeletionPlan {
        plan_id: "kv_cache_lineage_deletion_fence".to_string(),
        upstream_falsifier_id: UPSTREAM_OFFLOAD_CARD.to_string(),
        upstream_artifact_path: UPSTREAM_OFFLOAD_ARTIFACT.to_string(),
        source_refs: vec![
            KvCacheLineageSource::VllmPrefixCaching,
            KvCacheLineageSource::LmcacheLocalStorage,
            KvCacheLineageSource::LlamaCppSlotPromptCache,
            KvCacheLineageSource::PromptCacheModule,
            KvCacheLineageSource::AgentMemoryKv,
            KvCacheLineageSource::EpistemosBodyReadFreshness,
        ],
        source_ref_digest: "sha256:kv-cache-lineage-source-pass134".to_string(),
        boundaries: vec![
            KvCacheLineageBoundary::SourceBodyDigest,
            KvCacheLineageBoundary::SearchResultDigest,
            KvCacheLineageBoundary::PromptDigest,
            KvCacheLineageBoundary::TokenizerDigest,
            KvCacheLineageBoundary::ChatTemplateDigest,
            KvCacheLineageBoundary::ToolSchemaDigest,
            KvCacheLineageBoundary::ModelRevisionDigest,
            KvCacheLineageBoundary::AdapterDigest,
            KvCacheLineageBoundary::CacheSalt,
            KvCacheLineageBoundary::PrivacyScope,
        ],
        boundary_digest:
            "sha256:source-search-prompt-tokenizer-template-tool-model-adapter-salt-scope"
                .to_string(),
        lifecycle_states: vec![
            KvCacheLineageLifecycle::Active,
            KvCacheLineageLifecycle::Tombstoned,
            KvCacheLineageLifecycle::Purged,
        ],
        source_body_digest: "sha256:managed-body-sequence".to_string(),
        search_result_digest: "sha256:eidos-search-rrf-result".to_string(),
        prompt_digest: "sha256:canonical-prompt-packet".to_string(),
        tokenizer_digest: "sha256:tokenizer-revision".to_string(),
        chat_template_digest: "sha256:chat-template-revision".to_string(),
        tool_schema_digest: "sha256:tool-schema-revision".to_string(),
        model_revision_digest: "sha256:model-revision".to_string(),
        adapter_digest: "sha256:adapter-or-none".to_string(),
        cache_salt_digest: "sha256:trust-scoped-cache-salt".to_string(),
        privacy_scope_ref: "scope:local-note-private".to_string(),
        trust_group_ref: "trust_group:single-owner-local-vault".to_string(),
        allowlist_before_reuse: true,
        stale_source_reuse_denied: true,
        identity_drift_reuse_denied: true,
        tombstone_blocks_reuse: true,
        purge_deletes_material: true,
        deletion_is_visible: true,
        cache_hit_quality_claimed: false,
        cache_hit_model_fit_claimed: false,
        restored_cache_route_authority: false,
        hidden_cache_authority: false,
        command_armed: false,
        server_started: false,
        raw_prompt_logged: false,
        raw_token_logged: false,
        byte_ledger: KvCacheLineageByteLedger::metadata_only(),
        proof_refs: KvCacheLineageProofRefs {
            rollback_ref: "rollback:kv-cache-lineage-deletion-fence".to_string(),
            run_event_log_ref: "run_event_log:kv-cache-lineage-deletion-fence".to_string(),
            answer_packet_ref: "answer_packet:kv-cache-lineage-deletion-fence".to_string(),
            abstention_ref: "abstain:kv-cache-lineage-deletion-fence:metadata-only".to_string(),
            tombstone_ref: "tombstone:kv-cache-reuse-blocked-after-source-delete".to_string(),
            purge_ref: "purge:kv-cache-material-delete-or-zeroize-required".to_string(),
            caveat_ref: "caveat:cache-hit-is-not-quality-or-fit-proof".to_string(),
        },
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        metadata_bytes: 74_000,
        mas_promoted: false,
        l2_green_claimed: false,
        l3_green_claimed: false,
        live_dense_70b_claimed: false,
        ssd_as_ram_claimed: false,
    }
}

// UAS: uas:kv-cache-lineage-deletion:error
// Plane: Verification.
// Residency: validation failure only.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum KvCacheLineageDeletionError {
    MetadataBudget,
    InvalidPlan(String),
    UnsafeClaim(String),
}

impl fmt::Display for KvCacheLineageDeletionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MetadataBudget => write!(f, "KV cache lineage metadata budget invalid"),
            Self::InvalidPlan(reason) => write!(f, "invalid KV cache lineage plan: {reason}"),
            Self::UnsafeClaim(reason) => write!(f, "unsafe KV cache lineage claim: {reason}"),
        }
    }
}

impl std::error::Error for KvCacheLineageDeletionError {}

fn validate_plan(plan: &KvCacheLineageDeletionPlan) -> Result<(), KvCacheLineageDeletionError> {
    if !is_clean_id(&plan.plan_id) || plan.metadata_bytes == 0 {
        return Err(KvCacheLineageDeletionError::InvalidPlan(
            "plan id or metadata bytes invalid".to_string(),
        ));
    }
    if plan.metadata_bytes > MAX_PLAN_METADATA_BYTES {
        return Err(KvCacheLineageDeletionError::InvalidPlan(
            "plan metadata budget exceeded".to_string(),
        ));
    }
    if plan.upstream_falsifier_id != UPSTREAM_OFFLOAD_CARD
        || plan.upstream_artifact_path != UPSTREAM_OFFLOAD_ARTIFACT
    {
        return Err(KvCacheLineageDeletionError::InvalidPlan(
            "upstream KV offload witness missing".to_string(),
        ));
    }
    if unique_source_ref_count(&plan.source_refs) != 6 || !starts_sha(&plan.source_ref_digest) {
        return Err(KvCacheLineageDeletionError::InvalidPlan(
            "source refs or digest invalid".to_string(),
        ));
    }
    if unique_boundary_count(&plan.boundaries) != 10 || !starts_sha(&plan.boundary_digest) {
        return Err(KvCacheLineageDeletionError::InvalidPlan(
            "lineage boundaries incomplete".to_string(),
        ));
    }
    if !plan
        .lifecycle_states
        .contains(&KvCacheLineageLifecycle::Active)
        || !plan
            .lifecycle_states
            .contains(&KvCacheLineageLifecycle::Tombstoned)
        || !plan
            .lifecycle_states
            .contains(&KvCacheLineageLifecycle::Purged)
    {
        return Err(KvCacheLineageDeletionError::InvalidPlan(
            "cache lifecycle states incomplete".to_string(),
        ));
    }
    for digest in [
        &plan.source_body_digest,
        &plan.search_result_digest,
        &plan.prompt_digest,
        &plan.tokenizer_digest,
        &plan.chat_template_digest,
        &plan.tool_schema_digest,
        &plan.model_revision_digest,
        &plan.adapter_digest,
        &plan.cache_salt_digest,
    ] {
        if !starts_sha(digest) {
            return Err(KvCacheLineageDeletionError::InvalidPlan(
                "lineage digest missing".to_string(),
            ));
        }
    }
    if !plan.privacy_scope_ref.starts_with(SCOPE_PREFIX)
        || !plan.trust_group_ref.starts_with(TRUST_PREFIX)
        || !plan.allowlist_before_reuse
        || !plan.stale_source_reuse_denied
        || !plan.identity_drift_reuse_denied
    {
        return Err(KvCacheLineageDeletionError::InvalidPlan(
            "privacy or drift fence invalid".to_string(),
        ));
    }
    if !plan.tombstone_blocks_reuse || !plan.purge_deletes_material || !plan.deletion_is_visible {
        return Err(KvCacheLineageDeletionError::InvalidPlan(
            "deletion lifecycle fence invalid".to_string(),
        ));
    }
    if !plan.proof_refs.rollback_ref.starts_with(ROLLBACK_PREFIX)
        || !plan
            .proof_refs
            .run_event_log_ref
            .starts_with(RUN_EVENT_LOG_PREFIX)
        || !plan
            .proof_refs
            .answer_packet_ref
            .starts_with(ANSWER_PACKET_PREFIX)
        || !plan
            .proof_refs
            .abstention_ref
            .starts_with(ABSTENTION_PREFIX)
        || !plan.proof_refs.tombstone_ref.starts_with(TOMBSTONE_PREFIX)
        || !plan.proof_refs.purge_ref.starts_with(PURGE_PREFIX)
        || !plan.proof_refs.caveat_ref.starts_with(CAVEAT_PREFIX)
    {
        return Err(KvCacheLineageDeletionError::InvalidPlan(
            "proof refs invalid".to_string(),
        ));
    }
    if plan.product_build != ProductBuild::Pro || plan.pro_status != ProStatus::ResearchCandidate {
        return Err(KvCacheLineageDeletionError::UnsafeClaim(
            "KV cache lineage fence must remain Pro ResearchCandidate".to_string(),
        ));
    }
    let ledger = &plan.byte_ledger;
    if ledger.kv_bytes_loaded != 0
        || ledger.cache_bytes_opened != 0
        || ledger.model_bytes_loaded != 0
        || ledger.runtime_bytes_loaded != 0
        || ledger.source_tree_bytes_opened != 0
        || ledger.benchmark_bytes_opened != 0
        || ledger.product_bytes_opened != 0
        || ledger.provider_calls_made != 0
    {
        return Err(KvCacheLineageDeletionError::UnsafeClaim(
            "metadata witness cannot load/open KV, cache, model, runtime, source, benchmark, product, or provider bytes".to_string(),
        ));
    }
    if plan.cache_hit_quality_claimed
        || plan.cache_hit_model_fit_claimed
        || plan.restored_cache_route_authority
        || plan.hidden_cache_authority
        || plan.command_armed
        || plan.server_started
        || plan.raw_prompt_logged
        || plan.raw_token_logged
        || plan.mas_promoted
        || plan.l2_green_claimed
        || plan.l3_green_claimed
        || plan.live_dense_70b_claimed
        || plan.ssd_as_ram_claimed
    {
        return Err(KvCacheLineageDeletionError::UnsafeClaim(
            "unsafe cache, runtime, logging, promotion, live-70B, or SSD-as-RAM claim".to_string(),
        ));
    }
    Ok(())
}

fn unique_source_ref_count(sources: &[KvCacheLineageSource]) -> u64 {
    sources.iter().copied().collect::<BTreeSet<_>>().len() as u64
}

fn unique_boundary_count(boundaries: &[KvCacheLineageBoundary]) -> u64 {
    boundaries.iter().copied().collect::<BTreeSet<_>>().len() as u64
}

fn unique_lifecycle_state_count(states: &[KvCacheLineageLifecycle]) -> u64 {
    states.iter().copied().collect::<BTreeSet<_>>().len() as u64
}

fn fence_preimage(plan: &KvCacheLineageDeletionPlan, metadata_bytes: u64) -> String {
    format!(
        "{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
        KV_CACHE_LINEAGE_DELETION_FENCE_ID,
        plan.upstream_falsifier_id,
        plan.source_ref_digest,
        plan.boundary_digest,
        plan.source_body_digest,
        plan.prompt_digest,
        plan.model_revision_digest,
        plan.cache_salt_digest,
        plan.proof_refs.tombstone_ref,
        plan.proof_refs.answer_packet_ref,
        metadata_bytes
    )
}

fn starts_sha(value: &str) -> bool {
    value.starts_with(SHA256_PREFIX) && value.len() > SHA256_PREFIX.len()
}

fn is_clean_id(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 96
        && value
            .chars()
            .all(|ch| ch.is_ascii_lowercase() || ch.is_ascii_digit() || ch == '_' || ch == '-')
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_331_200_000;

    #[test]
    fn canonical_plan_builds_deterministic_fence() {
        let plan = canonical_kv_cache_lineage_deletion_plan();
        let fence = KvCacheLineageDeletionFence::new(plan.clone(), 128_000, CREATED_AT_MS).unwrap();
        let mut shuffled = plan;
        shuffled.source_refs.reverse();
        shuffled.boundaries.reverse();
        shuffled.lifecycle_states.reverse();
        let shuffled = KvCacheLineageDeletionFence::new(shuffled, 128_000, CREATED_AT_MS).unwrap();

        assert_eq!(fence.fence_address, shuffled.fence_address);
        assert!(fence.metadata_only);
        assert!(fence.no_runtime_execution);
        assert!(fence.product_promotion_blocked);
    }

    #[test]
    fn rejects_stale_source_reuse() {
        let mut plan = canonical_kv_cache_lineage_deletion_plan();
        plan.stale_source_reuse_denied = false;
        assert!(KvCacheLineageDeletionFence::new(plan, 128_000, CREATED_AT_MS).is_err());
    }

    #[test]
    fn rejects_missing_tombstone_and_purge() {
        let mut plan = canonical_kv_cache_lineage_deletion_plan();
        plan.tombstone_blocks_reuse = false;
        assert!(KvCacheLineageDeletionFence::new(plan, 128_000, CREATED_AT_MS).is_err());

        let mut plan = canonical_kv_cache_lineage_deletion_plan();
        plan.proof_refs.purge_ref.clear();
        assert!(KvCacheLineageDeletionFence::new(plan, 128_000, CREATED_AT_MS).is_err());
    }

    #[test]
    fn rejects_cache_bytes_or_promotion_claims() {
        let mut plan = canonical_kv_cache_lineage_deletion_plan();
        plan.byte_ledger.cache_bytes_opened = 1;
        assert!(KvCacheLineageDeletionFence::new(plan, 128_000, CREATED_AT_MS).is_err());

        let mut plan = canonical_kv_cache_lineage_deletion_plan();
        plan.l3_green_claimed = true;
        assert!(KvCacheLineageDeletionFence::new(plan, 128_000, CREATED_AT_MS).is_err());
    }
}
