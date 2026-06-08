//! KV cache identity, salt, and offload proof packet.
//!
//! This primitive turns Pass 128 cache/offload research into a metadata-only
//! witness. It proves future KV reuse must bind source freshness, tokenizer and
//! tool schema identity, cache salt, block ancestry, offload budgets, rollback,
//! RunEventLog, and AnswerPacket before it can influence RuntimeRouter/System G.
//! It opens no model, KV, cache, runtime, provider, source-tree, or product
//! bytes.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::uas::{ProStatus, ProductBuild, UasAddress, UasKind};

pub const KV_CACHE_IDENTITY_SALT_OFFLOAD_PROOF_PACKET_ID: &str =
    "F-KVCacheIdentitySaltAndOffloadProofPacket";
pub const KV_CACHE_IDENTITY_SALT_OFFLOAD_PROOF_PACKET_CURSOR: &str =
    "kv_cache_identity_salt_offload_proof_packet";
pub const KV_CACHE_IDENTITY_SALT_OFFLOAD_PROOF_PACKET_NEXT_CURSOR: &str =
    "llama_cpp_slot_prompt_cache_command_card";

const HTTPS_PREFIX: &str = "https://";
const SHA256_PREFIX: &str = "sha256:";
const BLOCK_PREFIX: &str = "kv_block:";
const CACHE_ROOT_PREFIX: &str = "cache_root:";
const DENIED_PREFIX: &str = "denied:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const ABSTENTION_PREFIX: &str = "abstain:";
const CAVEAT_PREFIX: &str = "caveat:";
const MAX_PACKET_METADATA_BYTES: u64 = 384 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 96 * 1024;

// UAS: uas:kv-cache-identity-packet:source
// Plane: State + Verification.
// Residency: source-card motif only; no runtime lane is opened here.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KvCacheIdentitySource {
    VllmPrefixCaching,
    LmcacheLocalStorage,
    LlamaCppSlotPromptCache,
    KTransformersExpertCache,
    KiviAsymmetricKv,
}

// UAS: uas:kv-cache-identity-packet:runtime-lane
// Plane: Controller.
// Residency: candidate lane label; not a product route claim.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KvCacheIdentityRuntimeLane {
    MetadataOnly,
    LlamaCppCommandCard,
    VllmResearchServer,
    LmcacheResearchDaemon,
    KTransformersResearch,
    KiviResearch,
}

// UAS: uas:kv-cache-identity-packet:offload-tier
// Plane: Assembly + Verification.
// Residency: declared cache tier; remote remains denied in this witness.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KvOffloadTier {
    HotResident,
    CpuCache,
    LocalDisk,
    RemoteDenied,
    NoOffload,
}

// UAS: uas:kv-cache-identity-packet:proof-refs
// Plane: Verification.
// Residency: visible proof handles only; no bytes are loaded.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvCacheIdentityProofRefs {
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub cache_caveat_ref: String,
}

// UAS: uas:kv-cache-identity-packet:byte-ledger
// Plane: Verification.
// Residency: metadata-only byte boundary; loaded/opened bytes must stay zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvCacheIdentityByteLedger {
    pub hot_resident_bytes: u64,
    pub cpu_cache_bytes: u64,
    pub local_disk_cache_bytes: u64,
    pub remote_cache_bytes: u64,
    pub model_bytes_loaded: u64,
    pub kv_bytes_loaded: u64,
    pub cache_bytes_opened: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

impl KvCacheIdentityByteLedger {
    pub fn metadata_only(
        hot_resident_bytes: u64,
        cpu_cache_bytes: u64,
        local_disk_cache_bytes: u64,
    ) -> Self {
        Self {
            hot_resident_bytes,
            cpu_cache_bytes,
            local_disk_cache_bytes,
            remote_cache_bytes: 0,
            model_bytes_loaded: 0,
            kv_bytes_loaded: 0,
            cache_bytes_opened: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
        }
    }
}

pub fn canonical_kv_cache_identity_cards() -> Vec<KvCacheIdentityCard> {
    vec![
        canonical_card(
            "vllm_prefix_caching",
            KvCacheIdentitySource::VllmPrefixCaching,
            "https://docs.vllm.ai/en/stable/design/prefix_caching/",
            KvCacheIdentityRuntimeLane::VllmResearchServer,
            vec![KvOffloadTier::HotResident, KvOffloadTier::RemoteDenied],
            "denied:remote-cache-not-product",
        ),
        canonical_card(
            "lmcache_local_storage",
            KvCacheIdentitySource::LmcacheLocalStorage,
            "https://docs.lmcache.ai/kv_cache/storage_backends/local_storage.html",
            KvCacheIdentityRuntimeLane::LmcacheResearchDaemon,
            vec![KvOffloadTier::CpuCache, KvOffloadTier::LocalDisk],
            "cache_root:artifacts/kv-cache/lmcache-local|denied:remote-cache",
        ),
        canonical_card(
            "llama_cpp_slot_prompt_cache",
            KvCacheIdentitySource::LlamaCppSlotPromptCache,
            "https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md",
            KvCacheIdentityRuntimeLane::LlamaCppCommandCard,
            vec![KvOffloadTier::LocalDisk],
            "cache_root:artifacts/kv-cache/llama-cpp-slot",
        ),
        canonical_card(
            "ktransformers_expert_cache",
            KvCacheIdentitySource::KTransformersExpertCache,
            "https://github.com/kvcache-ai/ktransformers",
            KvCacheIdentityRuntimeLane::KTransformersResearch,
            vec![KvOffloadTier::CpuCache, KvOffloadTier::LocalDisk],
            "cache_root:artifacts/kv-cache/ktransformers|denied:remote-cache",
        ),
        canonical_card(
            "kivi_asymmetric_kv",
            KvCacheIdentitySource::KiviAsymmetricKv,
            "https://arxiv.org/abs/2402.02750",
            KvCacheIdentityRuntimeLane::KiviResearch,
            vec![KvOffloadTier::NoOffload],
            "denied:runtime-cache-until-softmax-stability",
        ),
    ]
}

fn canonical_card(
    card_id: &str,
    source: KvCacheIdentitySource,
    source_url: &str,
    runtime_lane: KvCacheIdentityRuntimeLane,
    offload_tiers: Vec<KvOffloadTier>,
    path_scope: &str,
) -> KvCacheIdentityCard {
    KvCacheIdentityCard {
        card_id: card_id.to_string(),
        source,
        source_url: source_url.to_string(),
        runtime_lane,
        source_freshness_digest: format!("sha256:source-{card_id}"),
        search_freshness_digest: "sha256:search-freshness-pass128".to_string(),
        prompt_assembly_digest: "sha256:prompt-assembly-pass128".to_string(),
        tokenizer_digest: "sha256:tokenizer-pass128".to_string(),
        chat_template_digest: "sha256:chat-template-pass128".to_string(),
        tool_schema_digest: "sha256:tool-schema-pass128".to_string(),
        model_id: "metadata-only-cache-identity-fixture".to_string(),
        model_revision: "source-card-only".to_string(),
        selected_artifact_digest: format!("sha256:selected-artifact-{card_id}"),
        runtime_version: "metadata-only".to_string(),
        block_hash: format!("kv_block:{card_id}:child"),
        parent_block_hash: format!("kv_block:{card_id}:parent"),
        block_token_range_digest: format!("sha256:block-token-range-{card_id}"),
        cache_salt_digest: format!("sha256:cache-salt-{card_id}"),
        trust_group_id: format!("trust_group:{card_id}"),
        adapter_ids_digest: format!("sha256:adapter-ids-{card_id}"),
        modality_hash_digest: format!("sha256:modality-hash-{card_id}"),
        kv_dtype_k: if source == KvCacheIdentitySource::KiviAsymmetricKv {
            "per_channel_2bit_k".to_string()
        } else {
            "metadata_only_k".to_string()
        },
        kv_dtype_v: if source == KvCacheIdentitySource::KiviAsymmetricKv {
            "per_token_2bit_v".to_string()
        } else {
            "metadata_only_v".to_string()
        },
        kv_quant_profile: if source == KvCacheIdentitySource::KiviAsymmetricKv {
            "kivi_asymmetric_source_card".to_string()
        } else {
            "not_quantized_metadata_only".to_string()
        },
        layer_range: "all_layers_metadata_only".to_string(),
        head_layout: "source_card_head_layout_required".to_string(),
        position_encoding_policy: "source_card_position_policy_required".to_string(),
        offload_tiers,
        chunk_size_tokens: 256,
        eviction_policy: "policy:lru-or-abstain".to_string(),
        prefetch_policy: "policy:prefetch-requires-owner-approved-runtime".to_string(),
        path_scope: path_scope.to_string(),
        cleanup_policy: "policy:delete-cache-on-rollback".to_string(),
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        metadata_bytes: 24_000,
        byte_ledger: KvCacheIdentityByteLedger::metadata_only(0, 0, 0),
        proof_refs: KvCacheIdentityProofRefs {
            rollback_ref: format!("rollback:{card_id}"),
            run_event_log_ref: format!("run_event_log:{card_id}"),
            answer_packet_ref: format!("answer_packet:{card_id}"),
            abstention_ref: format!("abstain:{card_id}:metadata-only"),
            cache_caveat_ref: format!("caveat:{card_id}:no-runtime-cache-reuse"),
        },
        cache_reuse_allowed: false,
        cache_reuse_visible: true,
        hidden_cache_authority: false,
        remote_cache_product_authority: false,
        raw_prompt_logged: false,
        raw_token_logged: false,
        server_started: false,
        command_armed: false,
        l2_green_claimed: false,
        l3_green_claimed: false,
        live_dense_70b_claimed: false,
        ssd_as_ram_claimed: false,
    }
}

// UAS: uas:kv-cache-identity-packet:card
// Plane: State + Assembly + Controller + Verification.
// Residency: cache/offload source-card; it cannot authorize live reuse.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvCacheIdentityCard {
    pub card_id: String,
    pub source: KvCacheIdentitySource,
    pub source_url: String,
    pub runtime_lane: KvCacheIdentityRuntimeLane,
    pub source_freshness_digest: String,
    pub search_freshness_digest: String,
    pub prompt_assembly_digest: String,
    pub tokenizer_digest: String,
    pub chat_template_digest: String,
    pub tool_schema_digest: String,
    pub model_id: String,
    pub model_revision: String,
    pub selected_artifact_digest: String,
    pub runtime_version: String,
    pub block_hash: String,
    pub parent_block_hash: String,
    pub block_token_range_digest: String,
    pub cache_salt_digest: String,
    pub trust_group_id: String,
    pub adapter_ids_digest: String,
    pub modality_hash_digest: String,
    pub kv_dtype_k: String,
    pub kv_dtype_v: String,
    pub kv_quant_profile: String,
    pub layer_range: String,
    pub head_layout: String,
    pub position_encoding_policy: String,
    pub offload_tiers: Vec<KvOffloadTier>,
    pub chunk_size_tokens: u64,
    pub eviction_policy: String,
    pub prefetch_policy: String,
    pub path_scope: String,
    pub cleanup_policy: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_bytes: u64,
    pub byte_ledger: KvCacheIdentityByteLedger,
    pub proof_refs: KvCacheIdentityProofRefs,
    pub cache_reuse_allowed: bool,
    pub cache_reuse_visible: bool,
    pub hidden_cache_authority: bool,
    pub remote_cache_product_authority: bool,
    pub raw_prompt_logged: bool,
    pub raw_token_logged: bool,
    pub server_started: bool,
    pub command_armed: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:kv-cache-identity-packet:packet
// Plane: State + Assembly + Controller + Verification.
// Residency: metadata-only envelope for cache identity/offload proof.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvCacheIdentitySaltOffloadProofPacket {
    pub packet_address: UasAddress,
    pub cards: Vec<KvCacheIdentityCard>,
    pub metadata_bytes: u64,
    pub metadata_only: bool,
    pub no_runtime_execution: bool,
    pub no_cache_bytes_opened: bool,
    pub no_model_bytes_loaded: bool,
    pub l1_l2_l3_separated: bool,
    pub product_promotion_blocked: bool,
    pub hidden_cache_authority_blocked: bool,
}

// UAS: uas:kv-cache-identity-packet:metrics
// Plane: Verification.
// Residency: derived counters for artifact axes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvCacheIdentityMetrics {
    pub card_count: u64,
    pub source_count: u64,
    pub runtime_lane_count: u64,
    pub offload_tier_count: u64,
    pub local_disk_tier_count: u64,
    pub remote_denied_tier_count: u64,
    pub prompt_digest_count: u64,
    pub tokenizer_digest_count: u64,
    pub tool_schema_digest_count: u64,
    pub cache_salt_digest_count: u64,
    pub trust_group_count: u64,
    pub model_bytes_loaded: u64,
    pub kv_bytes_loaded: u64,
    pub cache_bytes_opened: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub remote_cache_bytes: u64,
    pub cache_reuse_allowed_count: u64,
    pub hidden_cache_authority_count: u64,
    pub raw_prompt_logged_count: u64,
    pub raw_token_logged_count: u64,
    pub server_started_count: u64,
    pub command_armed_count: u64,
    pub l2_green_claim_count: u64,
    pub l3_green_claim_count: u64,
    pub live_dense_70b_claim_count: u64,
    pub ssd_as_ram_claim_count: u64,
}

impl KvCacheIdentitySaltOffloadProofPacket {
    pub fn new(
        mut cards: Vec<KvCacheIdentityCard>,
        metadata_bytes: u64,
        created_at_ms: u64,
    ) -> Result<Self, KvCacheIdentityError> {
        validate_packet_inputs(&cards, metadata_bytes)?;
        cards.sort_by(|a, b| a.card_id.cmp(&b.card_id));
        let preimage = packet_preimage(&cards, metadata_bytes);
        let packet = Self {
            packet_address: UasAddress::new(
                UasKind::Other(KV_CACHE_IDENTITY_SALT_OFFLOAD_PROOF_PACKET_CURSOR.to_string()),
                preimage.as_bytes(),
                created_at_ms,
            ),
            cards,
            metadata_bytes,
            metadata_only: true,
            no_runtime_execution: true,
            no_cache_bytes_opened: true,
            no_model_bytes_loaded: true,
            l1_l2_l3_separated: true,
            product_promotion_blocked: true,
            hidden_cache_authority_blocked: true,
        };
        Ok(packet)
    }

    pub fn metrics(&self) -> KvCacheIdentityMetrics {
        let mut sources = HashSet::new();
        let mut lanes = HashSet::new();
        let mut tiers = HashSet::new();
        let mut prompt_digests = BTreeSet::new();
        let mut tokenizer_digests = BTreeSet::new();
        let mut tool_schema_digests = BTreeSet::new();
        let mut salt_digests = BTreeSet::new();
        let mut trust_groups = BTreeSet::new();
        let mut metrics = KvCacheIdentityMetrics {
            card_count: self.cards.len() as u64,
            source_count: 0,
            runtime_lane_count: 0,
            offload_tier_count: 0,
            local_disk_tier_count: 0,
            remote_denied_tier_count: 0,
            prompt_digest_count: 0,
            tokenizer_digest_count: 0,
            tool_schema_digest_count: 0,
            cache_salt_digest_count: 0,
            trust_group_count: 0,
            model_bytes_loaded: 0,
            kv_bytes_loaded: 0,
            cache_bytes_opened: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            remote_cache_bytes: 0,
            cache_reuse_allowed_count: 0,
            hidden_cache_authority_count: 0,
            raw_prompt_logged_count: 0,
            raw_token_logged_count: 0,
            server_started_count: 0,
            command_armed_count: 0,
            l2_green_claim_count: 0,
            l3_green_claim_count: 0,
            live_dense_70b_claim_count: 0,
            ssd_as_ram_claim_count: 0,
        };

        for card in &self.cards {
            sources.insert(card.source);
            lanes.insert(card.runtime_lane);
            prompt_digests.insert(card.prompt_assembly_digest.clone());
            tokenizer_digests.insert(card.tokenizer_digest.clone());
            tool_schema_digests.insert(card.tool_schema_digest.clone());
            salt_digests.insert(card.cache_salt_digest.clone());
            trust_groups.insert(card.trust_group_id.clone());
            for tier in &card.offload_tiers {
                tiers.insert(*tier);
                if *tier == KvOffloadTier::LocalDisk {
                    metrics.local_disk_tier_count += 1;
                }
                if *tier == KvOffloadTier::RemoteDenied {
                    metrics.remote_denied_tier_count += 1;
                }
            }
            metrics.model_bytes_loaded += card.byte_ledger.model_bytes_loaded;
            metrics.kv_bytes_loaded += card.byte_ledger.kv_bytes_loaded;
            metrics.cache_bytes_opened += card.byte_ledger.cache_bytes_opened;
            metrics.runtime_bytes_loaded += card.byte_ledger.runtime_bytes_loaded;
            metrics.provider_calls_made += card.byte_ledger.provider_calls_made;
            metrics.remote_cache_bytes += card.byte_ledger.remote_cache_bytes;
            if card.cache_reuse_allowed {
                metrics.cache_reuse_allowed_count += 1;
            }
            if card.hidden_cache_authority {
                metrics.hidden_cache_authority_count += 1;
            }
            if card.raw_prompt_logged {
                metrics.raw_prompt_logged_count += 1;
            }
            if card.raw_token_logged {
                metrics.raw_token_logged_count += 1;
            }
            if card.server_started {
                metrics.server_started_count += 1;
            }
            if card.command_armed {
                metrics.command_armed_count += 1;
            }
            if card.l2_green_claimed {
                metrics.l2_green_claim_count += 1;
            }
            if card.l3_green_claimed {
                metrics.l3_green_claim_count += 1;
            }
            if card.live_dense_70b_claimed {
                metrics.live_dense_70b_claim_count += 1;
            }
            if card.ssd_as_ram_claimed {
                metrics.ssd_as_ram_claim_count += 1;
            }
        }

        metrics.source_count = sources.len() as u64;
        metrics.runtime_lane_count = lanes.len() as u64;
        metrics.offload_tier_count = tiers.len() as u64;
        metrics.prompt_digest_count = prompt_digests.len() as u64;
        metrics.tokenizer_digest_count = tokenizer_digests.len() as u64;
        metrics.tool_schema_digest_count = tool_schema_digests.len() as u64;
        metrics.cache_salt_digest_count = salt_digests.len() as u64;
        metrics.trust_group_count = trust_groups.len() as u64;
        metrics
    }
}

// UAS: uas:kv-cache-identity-packet:error
// Plane: Verification.
// Residency: validation failure only; no runtime side effects.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum KvCacheIdentityError {
    EmptyCards,
    MetadataBudget,
    DuplicateCard(String),
    DuplicateSource(KvCacheIdentitySource),
    MissingSource(KvCacheIdentitySource),
    InvalidCard(String),
    UnsafeClaim(String),
}

impl fmt::Display for KvCacheIdentityError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyCards => write!(f, "KV cache identity packet has no cards"),
            Self::MetadataBudget => write!(f, "KV cache identity metadata budget invalid"),
            Self::DuplicateCard(id) => write!(f, "duplicate KV cache identity card `{id}`"),
            Self::DuplicateSource(source) => {
                write!(f, "duplicate KV cache identity source `{source:?}`")
            }
            Self::MissingSource(source) => {
                write!(f, "missing KV cache identity source `{source:?}`")
            }
            Self::InvalidCard(reason) => write!(f, "invalid KV cache identity card: {reason}"),
            Self::UnsafeClaim(reason) => write!(f, "unsafe KV cache identity claim: {reason}"),
        }
    }
}

impl std::error::Error for KvCacheIdentityError {}

fn validate_packet_inputs(
    cards: &[KvCacheIdentityCard],
    metadata_bytes: u64,
) -> Result<(), KvCacheIdentityError> {
    if cards.is_empty() {
        return Err(KvCacheIdentityError::EmptyCards);
    }
    if metadata_bytes == 0 || metadata_bytes > MAX_PACKET_METADATA_BYTES {
        return Err(KvCacheIdentityError::MetadataBudget);
    }

    let mut card_ids = HashSet::new();
    let mut sources = HashSet::new();
    for card in cards {
        validate_card(card)?;
        if !card_ids.insert(card.card_id.clone()) {
            return Err(KvCacheIdentityError::DuplicateCard(card.card_id.clone()));
        }
        if !sources.insert(card.source) {
            return Err(KvCacheIdentityError::DuplicateSource(card.source));
        }
    }

    for source in [
        KvCacheIdentitySource::VllmPrefixCaching,
        KvCacheIdentitySource::LmcacheLocalStorage,
        KvCacheIdentitySource::LlamaCppSlotPromptCache,
        KvCacheIdentitySource::KTransformersExpertCache,
        KvCacheIdentitySource::KiviAsymmetricKv,
    ] {
        if !sources.contains(&source) {
            return Err(KvCacheIdentityError::MissingSource(source));
        }
    }
    Ok(())
}

fn validate_card(card: &KvCacheIdentityCard) -> Result<(), KvCacheIdentityError> {
    if !is_clean_id(&card.card_id) || card.metadata_bytes == 0 {
        return Err(KvCacheIdentityError::InvalidCard(
            "card id or metadata bytes invalid".to_string(),
        ));
    }
    if card.metadata_bytes > MAX_CARD_METADATA_BYTES {
        return Err(KvCacheIdentityError::InvalidCard(
            "card metadata budget exceeded".to_string(),
        ));
    }
    if !card.source_url.starts_with(HTTPS_PREFIX)
        || !starts_sha(&card.source_freshness_digest)
        || !starts_sha(&card.search_freshness_digest)
        || !starts_sha(&card.prompt_assembly_digest)
        || !starts_sha(&card.tokenizer_digest)
        || !starts_sha(&card.chat_template_digest)
        || !starts_sha(&card.tool_schema_digest)
        || !starts_sha(&card.selected_artifact_digest)
    {
        return Err(KvCacheIdentityError::InvalidCard(
            "source or freshness digests invalid".to_string(),
        ));
    }
    if !is_clean_text(&card.model_id)
        || !is_clean_text(&card.model_revision)
        || !is_clean_text(&card.runtime_version)
    {
        return Err(KvCacheIdentityError::InvalidCard(
            "model/runtime identity invalid".to_string(),
        ));
    }
    if !card.block_hash.starts_with(BLOCK_PREFIX)
        || !card.parent_block_hash.starts_with(BLOCK_PREFIX)
        || !starts_sha(&card.block_token_range_digest)
        || !starts_sha(&card.cache_salt_digest)
        || !is_clean_id(&card.trust_group_id)
        || !starts_sha(&card.adapter_ids_digest)
        || !starts_sha(&card.modality_hash_digest)
    {
        return Err(KvCacheIdentityError::InvalidCard(
            "cache block identity, salt, or extras invalid".to_string(),
        ));
    }
    if !is_clean_id(&card.kv_dtype_k)
        || !is_clean_id(&card.kv_dtype_v)
        || !is_clean_id(&card.kv_quant_profile)
        || !is_clean_text(&card.layer_range)
        || !is_clean_text(&card.head_layout)
        || !is_clean_text(&card.position_encoding_policy)
    {
        return Err(KvCacheIdentityError::InvalidCard(
            "KV dtype/layout identity invalid".to_string(),
        ));
    }
    if card.offload_tiers.is_empty() || card.chunk_size_tokens == 0 {
        return Err(KvCacheIdentityError::InvalidCard(
            "offload tiers or chunk size missing".to_string(),
        ));
    }
    if !is_clean_text(&card.eviction_policy)
        || !is_clean_text(&card.prefetch_policy)
        || !is_clean_text(&card.cleanup_policy)
    {
        return Err(KvCacheIdentityError::InvalidCard(
            "offload policies invalid".to_string(),
        ));
    }
    if card.offload_tiers.contains(&KvOffloadTier::LocalDisk)
        && !card.path_scope.starts_with(CACHE_ROOT_PREFIX)
    {
        return Err(KvCacheIdentityError::InvalidCard(
            "local disk cache path is not owner-scoped".to_string(),
        ));
    }
    if card.offload_tiers.contains(&KvOffloadTier::RemoteDenied)
        && !card.path_scope.contains(DENIED_PREFIX)
        && card.byte_ledger.remote_cache_bytes != 0
    {
        return Err(KvCacheIdentityError::InvalidCard(
            "remote cache is not explicitly denied".to_string(),
        ));
    }
    if !card.proof_refs.rollback_ref.starts_with(ROLLBACK_PREFIX)
        || !card
            .proof_refs
            .run_event_log_ref
            .starts_with(RUN_EVENT_LOG_PREFIX)
        || !card
            .proof_refs
            .answer_packet_ref
            .starts_with(ANSWER_PACKET_PREFIX)
        || !card
            .proof_refs
            .abstention_ref
            .starts_with(ABSTENTION_PREFIX)
        || !card.proof_refs.cache_caveat_ref.starts_with(CAVEAT_PREFIX)
    {
        return Err(KvCacheIdentityError::InvalidCard(
            "visible proof refs invalid".to_string(),
        ));
    }
    if card.byte_ledger.model_bytes_loaded != 0
        || card.byte_ledger.kv_bytes_loaded != 0
        || card.byte_ledger.cache_bytes_opened != 0
        || card.byte_ledger.runtime_bytes_loaded != 0
        || card.byte_ledger.provider_calls_made != 0
        || card.byte_ledger.remote_cache_bytes != 0
    {
        return Err(KvCacheIdentityError::UnsafeClaim(
            "runtime/cache/provider bytes must remain zero".to_string(),
        ));
    }
    if card.cache_reuse_allowed
        || !card.cache_reuse_visible
        || card.hidden_cache_authority
        || card.remote_cache_product_authority
        || card.raw_prompt_logged
        || card.raw_token_logged
        || card.server_started
        || card.command_armed
        || card.l2_green_claimed
        || card.l3_green_claimed
        || card.live_dense_70b_claimed
        || card.ssd_as_ram_claimed
    {
        return Err(KvCacheIdentityError::UnsafeClaim(
            "cache reuse, hidden authority, byte leak, or promotion claim rejected".to_string(),
        ));
    }
    if card.product_build != ProductBuild::Pro
        || !matches!(
            card.pro_status,
            ProStatus::ResearchCandidate | ProStatus::Gated
        )
    {
        return Err(KvCacheIdentityError::UnsafeClaim(
            "KV cache proof packet is Pro Research/Gated only".to_string(),
        ));
    }
    Ok(())
}

fn packet_preimage(cards: &[KvCacheIdentityCard], metadata_bytes: u64) -> String {
    let mut preimage = format!(
        "{}|metadata={metadata_bytes}|next={}",
        KV_CACHE_IDENTITY_SALT_OFFLOAD_PROOF_PACKET_ID,
        KV_CACHE_IDENTITY_SALT_OFFLOAD_PROOF_PACKET_NEXT_CURSOR
    );
    for card in cards {
        preimage.push_str(&format!(
            "|{}|{:?}|{:?}|{}|{}|{}|{}|{}|{}|{}|{}",
            card.card_id,
            card.source,
            card.runtime_lane,
            card.source_freshness_digest,
            card.prompt_assembly_digest,
            card.tokenizer_digest,
            card.tool_schema_digest,
            card.block_hash,
            card.parent_block_hash,
            card.cache_salt_digest,
            card.path_scope,
        ));
    }
    preimage
}

fn starts_sha(value: &str) -> bool {
    value.starts_with(SHA256_PREFIX) && is_clean_text(value)
}

fn is_clean_id(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 128
        && value
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, '_' | '-' | ':' | '.'))
}

fn is_clean_text(value: &str) -> bool {
    !value.trim().is_empty()
        && value.len() <= 512
        && !value
            .chars()
            .any(|c| c.is_control() || matches!(c, '\n' | '\r' | '\t'))
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_072_000_000;

    #[test]
    fn canonical_packet_validates_and_is_deterministic() {
        let packet = build_packet(canonical_kv_cache_identity_cards())
            .expect("canonical packet must validate");
        let reversed = build_packet(
            canonical_kv_cache_identity_cards()
                .into_iter()
                .rev()
                .collect(),
        )
        .expect("reversed packet must validate");
        let metrics = packet.metrics();
        assert_eq!(packet.packet_address, reversed.packet_address);
        assert_eq!(metrics.card_count, 5);
        assert_eq!(metrics.source_count, 5);
        assert_eq!(metrics.cache_salt_digest_count, 5);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(metrics.cache_reuse_allowed_count, 0);
    }

    #[test]
    fn rejects_missing_required_source() {
        let mut cards = canonical_kv_cache_identity_cards();
        cards.pop();
        assert!(matches!(
            build_packet(cards),
            Err(KvCacheIdentityError::MissingSource(
                KvCacheIdentitySource::KiviAsymmetricKv
            ))
        ));
    }

    #[test]
    fn rejects_unsalted_or_cross_schema_cache() {
        let mut cards = canonical_kv_cache_identity_cards();
        cards[0].cache_salt_digest.clear();
        assert!(build_packet(cards).is_err());

        let mut cards = canonical_kv_cache_identity_cards();
        cards[1].tool_schema_digest.clear();
        assert!(build_packet(cards).is_err());
    }

    #[test]
    fn rejects_path_escape_and_remote_cache_bytes() {
        let mut cards = canonical_kv_cache_identity_cards();
        cards[1].path_scope = "/tmp/kvcache".to_string();
        assert!(build_packet(cards).is_err());

        let mut cards = canonical_kv_cache_identity_cards();
        cards[0].byte_ledger.remote_cache_bytes = 1;
        assert!(build_packet(cards).is_err());
    }

    #[test]
    fn rejects_runtime_or_promotion_claims() {
        for mutate in [
            |card: &mut KvCacheIdentityCard| card.cache_reuse_allowed = true,
            |card: &mut KvCacheIdentityCard| card.hidden_cache_authority = true,
            |card: &mut KvCacheIdentityCard| card.raw_prompt_logged = true,
            |card: &mut KvCacheIdentityCard| card.server_started = true,
            |card: &mut KvCacheIdentityCard| card.l2_green_claimed = true,
            |card: &mut KvCacheIdentityCard| card.live_dense_70b_claimed = true,
            |card: &mut KvCacheIdentityCard| card.ssd_as_ram_claimed = true,
        ] {
            let mut cards = canonical_kv_cache_identity_cards();
            mutate(&mut cards[0]);
            assert!(build_packet(cards).is_err());
        }
    }

    fn build_packet(
        cards: Vec<KvCacheIdentityCard>,
    ) -> Result<KvCacheIdentitySaltOffloadProofPacket, KvCacheIdentityError> {
        KvCacheIdentitySaltOffloadProofPacket::new(cards, 192_000, CREATED_AT_MS)
    }
}
