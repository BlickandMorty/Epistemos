//! KV offload tier budget envelope.
//!
//! Metadata-only source-card envelope for LMCache/vLLM/KVSwap-style KV
//! offload. It binds hot/CPU/local-disk/remote-denied tiers, app headroom,
//! cleanup, teardown, rollback, RunEventLog, and AnswerPacket before offload
//! research can influence RuntimeRouter/System G.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{ProStatus, ProductBuild, UasAddress, UasKind};

pub const KV_OFFLOAD_TIER_BUDGET_ENVELOPE_ID: &str = "F-KVOffloadTierBudgetEnvelope";
pub const KV_OFFLOAD_TIER_BUDGET_ENVELOPE_CURSOR: &str = "kv_offload_tier_budget_envelope";
pub const KV_OFFLOAD_TIER_BUDGET_ENVELOPE_NEXT_CURSOR: &str = "kv_cache_lineage_deletion_fence";

const UPSTREAM_KIVI_CARD: &str = "F-KIVIAsymmetricKVStabilitySourceCard";
const UPSTREAM_KIVI_ARTIFACT: &str =
    "artifacts/falsifiers/kivi_asymmetric_kv_stability_source_card/result.json";
const SHA256_PREFIX: &str = "sha256:";
const CACHE_ROOT_PREFIX: &str = "cache_root:";
const DENIED_PREFIX: &str = "denied:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const ABSTENTION_PREFIX: &str = "abstain:";
const CAVEAT_PREFIX: &str = "caveat:";
const MAX_ENVELOPE_METADATA_BYTES: u64 = 192 * 1024;
const MAX_PLAN_METADATA_BYTES: u64 = 96 * 1024;

// UAS: uas:kv-offload-tier-budget:source
// Plane: State + Verification.
// Residency: source-card motif only; no runtime lane is opened.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KvOffloadBudgetSource {
    LmcacheLocalStorage,
    LmcacheArchitecture,
    VllmOffloadingConnector,
    VllmPagedAttention,
    KiviAsymmetricKv,
    KvSwapDiskAware,
}

// UAS: uas:kv-offload-tier-budget:tier
// Plane: Assembly.
// Residency: declared cache tier, not loaded bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KvOffloadBudgetTier {
    HotResidentUma,
    CpuPinnedCache,
    LocalDiskCache,
    RemoteDenied,
}

// UAS: uas:kv-offload-tier-budget:lane
// Plane: Controller.
// Residency: candidate lane label only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KvOffloadRuntimeLane {
    MetadataOnly,
    LlamaCppCommandCard,
    LmcacheQuarantineDaemon,
    VllmResearchServer,
    CustomMetalResearch,
}

// UAS: uas:kv-offload-tier-budget:proof-refs
// Plane: Verification.
// Residency: visible proof handles only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvOffloadBudgetProofRefs {
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub caveat_ref: String,
}

// UAS: uas:kv-offload-tier-budget:byte-ledger
// Plane: Verification.
// Residency: byte accounting; loaded/opened bytes must stay zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvOffloadBudgetByteLedger {
    pub declared_hot_resident_bytes: u64,
    pub declared_cpu_cache_bytes: u64,
    pub declared_local_disk_cache_bytes: u64,
    pub declared_remote_cache_bytes: u64,
    pub declared_runtime_workspace_bytes: u64,
    pub declared_app_headroom_bytes: u64,
    pub model_bytes_loaded: u64,
    pub kv_bytes_loaded: u64,
    pub cache_bytes_opened: u64,
    pub runtime_bytes_loaded: u64,
    pub source_tree_bytes_opened: u64,
    pub benchmark_bytes_opened: u64,
    pub product_bytes_opened: u64,
    pub provider_calls_made: u64,
}

impl KvOffloadBudgetByteLedger {
    pub fn metadata_only() -> Self {
        Self {
            declared_hot_resident_bytes: 2 * 1024 * 1024 * 1024,
            declared_cpu_cache_bytes: 4 * 1024 * 1024 * 1024,
            declared_local_disk_cache_bytes: 8 * 1024 * 1024 * 1024,
            declared_remote_cache_bytes: 0,
            declared_runtime_workspace_bytes: 512 * 1024 * 1024,
            declared_app_headroom_bytes: 4 * 1024 * 1024 * 1024,
            model_bytes_loaded: 0,
            kv_bytes_loaded: 0,
            cache_bytes_opened: 0,
            runtime_bytes_loaded: 0,
            source_tree_bytes_opened: 0,
            benchmark_bytes_opened: 0,
            product_bytes_opened: 0,
            provider_calls_made: 0,
        }
    }
}

// UAS: uas:kv-offload-tier-budget:plan
// Plane: Assembly + Controller + Verification.
// Residency: metadata-only budget plan; not a live cache.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvOffloadTierBudgetPlan {
    pub plan_id: String,
    pub upstream_falsifier_id: String,
    pub upstream_artifact_path: String,
    pub source_refs: Vec<KvOffloadBudgetSource>,
    pub source_ref_digest: String,
    pub runtime_lane: KvOffloadRuntimeLane,
    pub tiers: Vec<KvOffloadBudgetTier>,
    pub byte_ledger: KvOffloadBudgetByteLedger,
    pub chunk_size_tokens: u32,
    pub cpu_tier_primary_gateway_required: bool,
    pub local_disk_async_put_required: bool,
    pub local_disk_prefetch_requires_cpu_cache: bool,
    pub local_disk_cache_root: String,
    pub remote_tiers_denied: bool,
    pub remote_tier_denial_ref: String,
    pub eviction_policy: String,
    pub cleanup_policy: String,
    pub teardown_policy: String,
    pub cache_miss_policy: String,
    pub compatibility_fence_ref: String,
    pub privacy_class: String,
    pub proof_refs: KvOffloadBudgetProofRefs,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_bytes: u64,
    pub model_fit_claimed: bool,
    pub local_disk_as_ram_claimed: bool,
    pub route_authority_allowed: bool,
    pub hidden_cache_authority: bool,
    pub remote_cache_allowed: bool,
    pub command_armed: bool,
    pub server_started: bool,
    pub raw_prompt_logged: bool,
    pub raw_token_logged: bool,
    pub mas_promoted: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
}

// UAS: uas:kv-offload-tier-budget:envelope
// Plane: State + Verification.
// Residency: metadata-only witness envelope.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvOffloadTierBudgetEnvelope {
    pub envelope_address: UasAddress,
    pub plan: KvOffloadTierBudgetPlan,
    pub metadata_bytes: u64,
    pub metadata_only: bool,
    pub no_runtime_execution: bool,
    pub product_promotion_blocked: bool,
}

// UAS: uas:kv-offload-tier-budget:metrics
// Plane: Verification.
// Residency: derived counters for artifact axes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvOffloadTierBudgetMetrics {
    pub plan_count: u64,
    pub source_ref_count: u64,
    pub tier_count: u64,
    pub declared_hot_resident_bytes: u64,
    pub declared_cpu_cache_bytes: u64,
    pub declared_local_disk_cache_bytes: u64,
    pub declared_remote_cache_bytes: u64,
    pub declared_runtime_workspace_bytes: u64,
    pub declared_app_headroom_bytes: u64,
    pub model_bytes_loaded: u64,
    pub kv_bytes_loaded: u64,
    pub cache_bytes_opened: u64,
    pub runtime_bytes_loaded: u64,
    pub source_tree_bytes_opened: u64,
    pub benchmark_bytes_opened: u64,
    pub product_bytes_opened: u64,
    pub provider_calls_made: u64,
    pub model_fit_claim_count: u64,
    pub local_disk_as_ram_claim_count: u64,
    pub route_authority_allowed_count: u64,
    pub hidden_cache_authority_count: u64,
    pub remote_cache_allowed_count: u64,
    pub command_armed_count: u64,
    pub server_started_count: u64,
    pub raw_prompt_logged_count: u64,
    pub raw_token_logged_count: u64,
    pub mas_promotion_count: u64,
    pub l2_green_claim_count: u64,
    pub l3_green_claim_count: u64,
    pub live_dense_70b_claim_count: u64,
}

impl KvOffloadTierBudgetEnvelope {
    pub fn new(
        mut plan: KvOffloadTierBudgetPlan,
        metadata_bytes: u64,
        created_at_ms: u64,
    ) -> Result<Self, KvOffloadTierBudgetError> {
        validate_plan(&plan)?;
        if metadata_bytes == 0 || metadata_bytes > MAX_ENVELOPE_METADATA_BYTES {
            return Err(KvOffloadTierBudgetError::MetadataBudget);
        }
        plan.source_refs.sort();
        plan.tiers.sort();
        let preimage = envelope_preimage(&plan, metadata_bytes);
        Ok(Self {
            envelope_address: UasAddress::new(
                UasKind::Other(KV_OFFLOAD_TIER_BUDGET_ENVELOPE_CURSOR.to_string()),
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

    pub fn metrics(&self) -> KvOffloadTierBudgetMetrics {
        let plan = &self.plan;
        let ledger = &plan.byte_ledger;
        KvOffloadTierBudgetMetrics {
            plan_count: 1,
            source_ref_count: unique_source_ref_count(&plan.source_refs),
            tier_count: unique_tier_count(&plan.tiers),
            declared_hot_resident_bytes: ledger.declared_hot_resident_bytes,
            declared_cpu_cache_bytes: ledger.declared_cpu_cache_bytes,
            declared_local_disk_cache_bytes: ledger.declared_local_disk_cache_bytes,
            declared_remote_cache_bytes: ledger.declared_remote_cache_bytes,
            declared_runtime_workspace_bytes: ledger.declared_runtime_workspace_bytes,
            declared_app_headroom_bytes: ledger.declared_app_headroom_bytes,
            model_bytes_loaded: ledger.model_bytes_loaded,
            kv_bytes_loaded: ledger.kv_bytes_loaded,
            cache_bytes_opened: ledger.cache_bytes_opened,
            runtime_bytes_loaded: ledger.runtime_bytes_loaded,
            source_tree_bytes_opened: ledger.source_tree_bytes_opened,
            benchmark_bytes_opened: ledger.benchmark_bytes_opened,
            product_bytes_opened: ledger.product_bytes_opened,
            provider_calls_made: ledger.provider_calls_made,
            model_fit_claim_count: u64::from(plan.model_fit_claimed),
            local_disk_as_ram_claim_count: u64::from(plan.local_disk_as_ram_claimed),
            route_authority_allowed_count: u64::from(plan.route_authority_allowed),
            hidden_cache_authority_count: u64::from(plan.hidden_cache_authority),
            remote_cache_allowed_count: u64::from(plan.remote_cache_allowed),
            command_armed_count: u64::from(plan.command_armed),
            server_started_count: u64::from(plan.server_started),
            raw_prompt_logged_count: u64::from(plan.raw_prompt_logged),
            raw_token_logged_count: u64::from(plan.raw_token_logged),
            mas_promotion_count: u64::from(plan.mas_promoted),
            l2_green_claim_count: u64::from(plan.l2_green_claimed),
            l3_green_claim_count: u64::from(plan.l3_green_claimed),
            live_dense_70b_claim_count: u64::from(plan.live_dense_70b_claimed),
        }
    }
}

pub fn canonical_kv_offload_tier_budget_plan() -> KvOffloadTierBudgetPlan {
    KvOffloadTierBudgetPlan {
        plan_id: "kv_offload_tier_budget_envelope".to_string(),
        upstream_falsifier_id: UPSTREAM_KIVI_CARD.to_string(),
        upstream_artifact_path: UPSTREAM_KIVI_ARTIFACT.to_string(),
        source_refs: vec![
            KvOffloadBudgetSource::LmcacheLocalStorage,
            KvOffloadBudgetSource::LmcacheArchitecture,
            KvOffloadBudgetSource::VllmOffloadingConnector,
            KvOffloadBudgetSource::VllmPagedAttention,
            KvOffloadBudgetSource::KiviAsymmetricKv,
            KvOffloadBudgetSource::KvSwapDiskAware,
        ],
        source_ref_digest: "sha256:kv-offload-tier-budget-pass133".to_string(),
        runtime_lane: KvOffloadRuntimeLane::MetadataOnly,
        tiers: vec![
            KvOffloadBudgetTier::HotResidentUma,
            KvOffloadBudgetTier::CpuPinnedCache,
            KvOffloadBudgetTier::LocalDiskCache,
            KvOffloadBudgetTier::RemoteDenied,
        ],
        byte_ledger: KvOffloadBudgetByteLedger::metadata_only(),
        chunk_size_tokens: 256,
        cpu_tier_primary_gateway_required: true,
        local_disk_async_put_required: true,
        local_disk_prefetch_requires_cpu_cache: true,
        local_disk_cache_root: "cache_root:artifacts/kv-cache/offload-tier-budget".to_string(),
        remote_tiers_denied: true,
        remote_tier_denial_ref: "denied:remote-kv-cache-not-local-product".to_string(),
        eviction_policy: "policy:lru-or-abstain".to_string(),
        cleanup_policy: "cleanup:delete-local-cache-on-rollback-or-owner-purge".to_string(),
        teardown_policy: "teardown:cancel-prefetch-drop-open-handles-zeroize-ledger".to_string(),
        cache_miss_policy: "cache_miss:abstain-or-recompute-visible".to_string(),
        compatibility_fence_ref: "compatibility:kv-cache-identity-salt-offload-proof-packet"
            .to_string(),
        privacy_class: "local_private_redacted_metadata_only".to_string(),
        proof_refs: KvOffloadBudgetProofRefs {
            rollback_ref: "rollback:kv-offload-tier-budget-envelope".to_string(),
            run_event_log_ref: "run_event_log:kv-offload-tier-budget-envelope".to_string(),
            answer_packet_ref: "answer_packet:kv-offload-tier-budget-envelope".to_string(),
            abstention_ref: "abstain:kv-offload-tier-budget-envelope:metadata-only".to_string(),
            caveat_ref: "caveat:kv-offload:no-runtime-byte-proof".to_string(),
        },
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        metadata_bytes: 72_000,
        model_fit_claimed: false,
        local_disk_as_ram_claimed: false,
        route_authority_allowed: false,
        hidden_cache_authority: false,
        remote_cache_allowed: false,
        command_armed: false,
        server_started: false,
        raw_prompt_logged: false,
        raw_token_logged: false,
        mas_promoted: false,
        l2_green_claimed: false,
        l3_green_claimed: false,
        live_dense_70b_claimed: false,
    }
}

// UAS: uas:kv-offload-tier-budget:error
// Plane: Verification.
// Residency: validation failure only.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum KvOffloadTierBudgetError {
    MetadataBudget,
    InvalidPlan(String),
    UnsafeClaim(String),
}

impl fmt::Display for KvOffloadTierBudgetError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MetadataBudget => write!(f, "KV offload metadata budget invalid"),
            Self::InvalidPlan(reason) => write!(f, "invalid KV offload plan: {reason}"),
            Self::UnsafeClaim(reason) => write!(f, "unsafe KV offload claim: {reason}"),
        }
    }
}

impl std::error::Error for KvOffloadTierBudgetError {}

fn validate_plan(plan: &KvOffloadTierBudgetPlan) -> Result<(), KvOffloadTierBudgetError> {
    if !is_clean_id(&plan.plan_id) || plan.metadata_bytes == 0 {
        return Err(KvOffloadTierBudgetError::InvalidPlan(
            "plan id or metadata bytes invalid".to_string(),
        ));
    }
    if plan.metadata_bytes > MAX_PLAN_METADATA_BYTES {
        return Err(KvOffloadTierBudgetError::InvalidPlan(
            "plan metadata budget exceeded".to_string(),
        ));
    }
    if plan.upstream_falsifier_id != UPSTREAM_KIVI_CARD
        || plan.upstream_artifact_path != UPSTREAM_KIVI_ARTIFACT
    {
        return Err(KvOffloadTierBudgetError::InvalidPlan(
            "upstream KIVI source-card witness missing".to_string(),
        ));
    }
    if unique_source_ref_count(&plan.source_refs) != 6 || !starts_sha(&plan.source_ref_digest) {
        return Err(KvOffloadTierBudgetError::InvalidPlan(
            "source refs or digest invalid".to_string(),
        ));
    }
    if plan.runtime_lane != KvOffloadRuntimeLane::MetadataOnly {
        return Err(KvOffloadTierBudgetError::UnsafeClaim(
            "runtime lane must remain metadata-only".to_string(),
        ));
    }
    if unique_tier_count(&plan.tiers) != 4
        || !plan.tiers.contains(&KvOffloadBudgetTier::HotResidentUma)
        || !plan.tiers.contains(&KvOffloadBudgetTier::CpuPinnedCache)
        || !plan.tiers.contains(&KvOffloadBudgetTier::LocalDiskCache)
        || !plan.tiers.contains(&KvOffloadBudgetTier::RemoteDenied)
    {
        return Err(KvOffloadTierBudgetError::InvalidPlan(
            "offload tiers incomplete".to_string(),
        ));
    }
    let ledger = &plan.byte_ledger;
    if ledger.declared_hot_resident_bytes == 0
        || ledger.declared_cpu_cache_bytes == 0
        || ledger.declared_local_disk_cache_bytes == 0
        || ledger.declared_remote_cache_bytes != 0
        || ledger.declared_runtime_workspace_bytes == 0
        || ledger.declared_app_headroom_bytes < 2 * 1024 * 1024 * 1024
    {
        return Err(KvOffloadTierBudgetError::InvalidPlan(
            "declared byte envelope invalid".to_string(),
        ));
    }
    if plan.chunk_size_tokens == 0
        || !plan.cpu_tier_primary_gateway_required
        || !plan.local_disk_async_put_required
        || !plan.local_disk_prefetch_requires_cpu_cache
        || !plan.local_disk_cache_root.starts_with(CACHE_ROOT_PREFIX)
        || !plan.remote_tiers_denied
        || !plan.remote_tier_denial_ref.starts_with(DENIED_PREFIX)
    {
        return Err(KvOffloadTierBudgetError::InvalidPlan(
            "tier policy invalid".to_string(),
        ));
    }
    if !plan.eviction_policy.starts_with("policy:")
        || !plan.cleanup_policy.starts_with("cleanup:")
        || !plan.teardown_policy.starts_with("teardown:")
        || !plan.cache_miss_policy.starts_with("cache_miss:")
        || !plan.compatibility_fence_ref.starts_with("compatibility:")
        || plan.privacy_class.is_empty()
    {
        return Err(KvOffloadTierBudgetError::InvalidPlan(
            "policy refs invalid".to_string(),
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
        || !plan.proof_refs.caveat_ref.starts_with(CAVEAT_PREFIX)
    {
        return Err(KvOffloadTierBudgetError::InvalidPlan(
            "proof refs invalid".to_string(),
        ));
    }
    if plan.product_build != ProductBuild::Pro || plan.pro_status != ProStatus::ResearchCandidate {
        return Err(KvOffloadTierBudgetError::UnsafeClaim(
            "KV offload envelope must remain Pro ResearchCandidate".to_string(),
        ));
    }
    if ledger.model_bytes_loaded != 0
        || ledger.kv_bytes_loaded != 0
        || ledger.cache_bytes_opened != 0
        || ledger.runtime_bytes_loaded != 0
        || ledger.source_tree_bytes_opened != 0
        || ledger.benchmark_bytes_opened != 0
        || ledger.product_bytes_opened != 0
        || ledger.provider_calls_made != 0
    {
        return Err(KvOffloadTierBudgetError::UnsafeClaim(
            "metadata witness cannot load/open model, KV, cache, runtime, source, benchmark, product, or provider bytes".to_string(),
        ));
    }
    if plan.model_fit_claimed
        || plan.local_disk_as_ram_claimed
        || plan.route_authority_allowed
        || plan.hidden_cache_authority
        || plan.remote_cache_allowed
        || plan.command_armed
        || plan.server_started
        || plan.raw_prompt_logged
        || plan.raw_token_logged
        || plan.mas_promoted
        || plan.l2_green_claimed
        || plan.l3_green_claimed
        || plan.live_dense_70b_claimed
    {
        return Err(KvOffloadTierBudgetError::UnsafeClaim(
            "unsafe runtime, route, remote, logging, or promotion claim".to_string(),
        ));
    }
    Ok(())
}

fn unique_source_ref_count(sources: &[KvOffloadBudgetSource]) -> u64 {
    sources.iter().copied().collect::<BTreeSet<_>>().len() as u64
}

fn unique_tier_count(tiers: &[KvOffloadBudgetTier]) -> u64 {
    tiers.iter().copied().collect::<BTreeSet<_>>().len() as u64
}

fn envelope_preimage(plan: &KvOffloadTierBudgetPlan, metadata_bytes: u64) -> String {
    format!(
        "{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
        KV_OFFLOAD_TIER_BUDGET_ENVELOPE_ID,
        plan.upstream_falsifier_id,
        plan.source_ref_digest,
        plan.byte_ledger.declared_hot_resident_bytes,
        plan.byte_ledger.declared_cpu_cache_bytes,
        plan.byte_ledger.declared_local_disk_cache_bytes,
        plan.byte_ledger.declared_app_headroom_bytes,
        plan.proof_refs.rollback_ref,
        plan.proof_refs.answer_packet_ref,
        metadata_bytes
    )
}

fn starts_sha(value: &str) -> bool {
    value.starts_with(SHA256_PREFIX) && value.len() > SHA256_PREFIX.len()
}

fn is_clean_id(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 128
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'_' | b'-' | b':' | b'.'))
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_244_800_000;

    fn build(
        plan: KvOffloadTierBudgetPlan,
    ) -> Result<KvOffloadTierBudgetEnvelope, KvOffloadTierBudgetError> {
        KvOffloadTierBudgetEnvelope::new(plan, 128_000, CREATED_AT_MS)
    }

    #[test]
    fn canonical_envelope_passes_and_is_deterministic() {
        let plan = canonical_kv_offload_tier_budget_plan();
        let first = build(plan.clone()).expect("canonical KV offload envelope should pass");
        let mut shuffled = plan;
        shuffled.source_refs.reverse();
        shuffled.tiers.reverse();
        let second = build(shuffled).expect("shuffled KV offload envelope should pass");
        assert_eq!(first.envelope_address, second.envelope_address);
        let metrics = first.metrics();
        assert_eq!(metrics.source_ref_count, 6);
        assert_eq!(metrics.tier_count, 4);
        assert_eq!(metrics.declared_remote_cache_bytes, 0);
        assert_eq!(metrics.kv_bytes_loaded, 0);
    }

    #[test]
    fn rejects_missing_budget_or_policy() {
        let mut plan = canonical_kv_offload_tier_budget_plan();
        plan.byte_ledger.declared_app_headroom_bytes = 0;
        assert!(build(plan).is_err());

        let mut plan = canonical_kv_offload_tier_budget_plan();
        plan.local_disk_prefetch_requires_cpu_cache = false;
        assert!(build(plan).is_err());

        let mut plan = canonical_kv_offload_tier_budget_plan();
        plan.cleanup_policy.clear();
        assert!(build(plan).is_err());
    }

    #[test]
    fn rejects_runtime_remote_or_promotion_claims() {
        let mut plan = canonical_kv_offload_tier_budget_plan();
        plan.byte_ledger.kv_bytes_loaded = 1;
        assert!(build(plan).is_err());

        let mut plan = canonical_kv_offload_tier_budget_plan();
        plan.remote_cache_allowed = true;
        assert!(build(plan).is_err());

        let mut plan = canonical_kv_offload_tier_budget_plan();
        plan.local_disk_as_ram_claimed = true;
        assert!(build(plan).is_err());

        let mut plan = canonical_kv_offload_tier_budget_plan();
        plan.l3_green_claimed = true;
        assert!(build(plan).is_err());
    }
}
