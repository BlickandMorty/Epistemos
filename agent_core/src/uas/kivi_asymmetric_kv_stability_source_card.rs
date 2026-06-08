//! KIVI asymmetric KV stability source card.
//!
//! This primitive turns KIVI/asymmetric low-bit KV research into a
//! metadata-only stability source-card witness. It binds primary source facts,
//! K/V axis asymmetry, residual full-precision requirements, backend caveats,
//! quality-cliff proof slots, rollback, RunEventLog, AnswerPacket, and
//! abstention without importing CUDA/Python code, quantizing KV, or opening
//! model/runtime bytes.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{ProStatus, ProductBuild, UasAddress, UasKind};

pub const KIVI_ASYMMETRIC_KV_STABILITY_SOURCE_CARD_ID: &str =
    "F-KIVIAsymmetricKVStabilitySourceCard";
pub const KIVI_ASYMMETRIC_KV_STABILITY_SOURCE_CARD_CURSOR: &str =
    "kivi_asymmetric_kv_stability_source_card";
pub const KIVI_ASYMMETRIC_KV_STABILITY_SOURCE_CARD_NEXT_CURSOR: &str =
    "kv_offload_tier_budget_envelope";

const ARXIV_URL: &str = "https://arxiv.org/abs/2402.02750";
const GITHUB_URL: &str = "https://github.com/jy-yuan/KIVI";
const UPSTREAM_LLAMA_CPP_CARD: &str = "F-LlamaCppSlotPromptCacheCommandCard";
const UPSTREAM_LLAMA_CPP_ARTIFACT: &str =
    "artifacts/falsifiers/llama_cpp_slot_prompt_cache_command_card/result.json";
const SHA256_PREFIX: &str = "sha256:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const ABSTENTION_PREFIX: &str = "abstain:";
const CAVEAT_PREFIX: &str = "caveat:";
const MAX_SET_METADATA_BYTES: u64 = 192 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 128 * 1024;

// UAS: uas:kivi-stability-source:kv-axis
// Plane: Assembly + Verification.
// Residency: source-card quantization axis only; no KV bytes are quantized.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KiviKvAxisPolicy {
    KeyPerChannel,
    ValuePerToken,
}

// UAS: uas:kivi-stability-source:proof-slot
// Plane: Verification.
// Residency: required future proof surface; not executed here.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KiviStabilityProofSlot {
    SoftmaxDrift,
    AttentionOutlier,
    LongContextRecall,
    ReasoningQuality,
    CodingQuality,
    LatencyAndMemory,
    BackendCompatibility,
    RollbackReplay,
}

// UAS: uas:kivi-stability-source:backend
// Plane: Controller.
// Residency: backend classification only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KiviBackendLane {
    CudaResearch,
    TransformersInspired,
    AppleSiliconUnproven,
    RuntimeRouterDenied,
}

// UAS: uas:kivi-stability-source:proof-refs
// Plane: Verification.
// Residency: visible proof handles only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KiviStabilityProofRefs {
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub caveat_ref: String,
}

// UAS: uas:kivi-stability-source:byte-ledger
// Plane: Verification.
// Residency: zero-byte boundary.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KiviStabilityByteLedger {
    pub model_bytes_loaded: u64,
    pub kv_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub source_tree_bytes_opened: u64,
    pub cuda_kernel_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub benchmark_bytes_opened: u64,
    pub product_bytes_opened: u64,
}

impl KiviStabilityByteLedger {
    pub fn metadata_only() -> Self {
        Self {
            model_bytes_loaded: 0,
            kv_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            source_tree_bytes_opened: 0,
            cuda_kernel_bytes_loaded: 0,
            provider_calls_made: 0,
            benchmark_bytes_opened: 0,
            product_bytes_opened: 0,
        }
    }
}

// UAS: uas:kivi-stability-source:card
// Plane: Assembly + Controller + Verification.
// Residency: KIVI source-card only; no route authority.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KiviAsymmetricKvStabilitySourceCard {
    pub card_id: String,
    pub upstream_falsifier_id: String,
    pub upstream_artifact_path: String,
    pub arxiv_url: String,
    pub github_url: String,
    pub source_retrieval_digest: String,
    pub arxiv_version: String,
    pub venue: String,
    pub repo_license: String,
    pub implementation_language: String,
    pub backend_lanes: Vec<KiviBackendLane>,
    pub kv_axis_policies: Vec<KiviKvAxisPolicy>,
    pub k_bits: u8,
    pub v_bits: u8,
    pub group_size_required: bool,
    pub residual_length_required: bool,
    pub residual_full_precision_required: bool,
    pub residual_dtype: String,
    pub tuning_free_claim_source_carded: bool,
    pub quality_preservation_claim_caveated: bool,
    pub memory_reduction_claim_caveated: bool,
    pub throughput_claim_caveated: bool,
    pub apple_silicon_runtime_unproven: bool,
    pub proof_slots: Vec<KiviStabilityProofSlot>,
    pub proof_refs: KiviStabilityProofRefs,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_bytes: u64,
    pub byte_ledger: KiviStabilityByteLedger,
    pub direct_import_allowed: bool,
    pub clean_room_rewrite_required: bool,
    pub route_authority_allowed: bool,
    pub hidden_cache_authority: bool,
    pub raw_prompt_logged: bool,
    pub raw_token_logged: bool,
    pub low_bit_kv_live_claimed: bool,
    pub quality_green_claimed: bool,
    pub memory_fit_claimed: bool,
    pub mas_promoted: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:kivi-stability-source:set
// Plane: State + Verification.
// Residency: metadata-only witness envelope.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KiviAsymmetricKvStabilitySourceCardSet {
    pub set_address: UasAddress,
    pub card: KiviAsymmetricKvStabilitySourceCard,
    pub metadata_bytes: u64,
    pub metadata_only: bool,
    pub no_runtime_execution: bool,
    pub no_kv_quantization: bool,
    pub product_promotion_blocked: bool,
}

// UAS: uas:kivi-stability-source:metrics
// Plane: Verification.
// Residency: derived counters for artifact axes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KiviAsymmetricKvStabilityMetrics {
    pub card_count: u64,
    pub backend_lane_count: u64,
    pub kv_axis_policy_count: u64,
    pub proof_slot_count: u64,
    pub model_bytes_loaded: u64,
    pub kv_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub source_tree_bytes_opened: u64,
    pub cuda_kernel_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub benchmark_bytes_opened: u64,
    pub product_bytes_opened: u64,
    pub direct_import_allowed_count: u64,
    pub route_authority_allowed_count: u64,
    pub hidden_cache_authority_count: u64,
    pub raw_prompt_logged_count: u64,
    pub raw_token_logged_count: u64,
    pub low_bit_kv_live_claim_count: u64,
    pub quality_green_claim_count: u64,
    pub memory_fit_claim_count: u64,
    pub mas_promotion_count: u64,
    pub l2_green_claim_count: u64,
    pub l3_green_claim_count: u64,
    pub live_dense_70b_claim_count: u64,
    pub ssd_as_ram_claim_count: u64,
}

impl KiviAsymmetricKvStabilitySourceCardSet {
    pub fn new(
        mut card: KiviAsymmetricKvStabilitySourceCard,
        metadata_bytes: u64,
        created_at_ms: u64,
    ) -> Result<Self, KiviAsymmetricKvStabilityError> {
        validate_card(&card)?;
        if metadata_bytes == 0 || metadata_bytes > MAX_SET_METADATA_BYTES {
            return Err(KiviAsymmetricKvStabilityError::MetadataBudget);
        }
        card.backend_lanes.sort();
        card.kv_axis_policies.sort();
        card.proof_slots.sort();
        let preimage = set_preimage(&card, metadata_bytes);
        Ok(Self {
            set_address: UasAddress::new(
                UasKind::Other(KIVI_ASYMMETRIC_KV_STABILITY_SOURCE_CARD_CURSOR.to_string()),
                preimage.as_bytes(),
                created_at_ms,
            ),
            card,
            metadata_bytes,
            metadata_only: true,
            no_runtime_execution: true,
            no_kv_quantization: true,
            product_promotion_blocked: true,
        })
    }

    pub fn metrics(&self) -> KiviAsymmetricKvStabilityMetrics {
        let card = &self.card;
        KiviAsymmetricKvStabilityMetrics {
            card_count: 1,
            backend_lane_count: unique_backend_lane_count(&card.backend_lanes),
            kv_axis_policy_count: unique_kv_axis_policy_count(&card.kv_axis_policies),
            proof_slot_count: unique_proof_slot_count(&card.proof_slots),
            model_bytes_loaded: card.byte_ledger.model_bytes_loaded,
            kv_bytes_loaded: card.byte_ledger.kv_bytes_loaded,
            runtime_bytes_loaded: card.byte_ledger.runtime_bytes_loaded,
            source_tree_bytes_opened: card.byte_ledger.source_tree_bytes_opened,
            cuda_kernel_bytes_loaded: card.byte_ledger.cuda_kernel_bytes_loaded,
            provider_calls_made: card.byte_ledger.provider_calls_made,
            benchmark_bytes_opened: card.byte_ledger.benchmark_bytes_opened,
            product_bytes_opened: card.byte_ledger.product_bytes_opened,
            direct_import_allowed_count: u64::from(card.direct_import_allowed),
            route_authority_allowed_count: u64::from(card.route_authority_allowed),
            hidden_cache_authority_count: u64::from(card.hidden_cache_authority),
            raw_prompt_logged_count: u64::from(card.raw_prompt_logged),
            raw_token_logged_count: u64::from(card.raw_token_logged),
            low_bit_kv_live_claim_count: u64::from(card.low_bit_kv_live_claimed),
            quality_green_claim_count: u64::from(card.quality_green_claimed),
            memory_fit_claim_count: u64::from(card.memory_fit_claimed),
            mas_promotion_count: u64::from(card.mas_promoted),
            l2_green_claim_count: u64::from(card.l2_green_claimed),
            l3_green_claim_count: u64::from(card.l3_green_claimed),
            live_dense_70b_claim_count: u64::from(card.live_dense_70b_claimed),
            ssd_as_ram_claim_count: u64::from(card.ssd_as_ram_claimed),
        }
    }
}

pub fn canonical_kivi_asymmetric_kv_stability_source_card() -> KiviAsymmetricKvStabilitySourceCard {
    KiviAsymmetricKvStabilitySourceCard {
        card_id: "kivi_asymmetric_kv_stability_source_card".to_string(),
        upstream_falsifier_id: UPSTREAM_LLAMA_CPP_CARD.to_string(),
        upstream_artifact_path: UPSTREAM_LLAMA_CPP_ARTIFACT.to_string(),
        arxiv_url: ARXIV_URL.to_string(),
        github_url: GITHUB_URL.to_string(),
        source_retrieval_digest: "sha256:kivi-arxiv-github-pass132".to_string(),
        arxiv_version: "v2-2024-07-25".to_string(),
        venue: "ICML2024".to_string(),
        repo_license: "MIT".to_string(),
        implementation_language: "Python+Cuda".to_string(),
        backend_lanes: vec![
            KiviBackendLane::CudaResearch,
            KiviBackendLane::TransformersInspired,
            KiviBackendLane::AppleSiliconUnproven,
            KiviBackendLane::RuntimeRouterDenied,
        ],
        kv_axis_policies: vec![
            KiviKvAxisPolicy::KeyPerChannel,
            KiviKvAxisPolicy::ValuePerToken,
        ],
        k_bits: 2,
        v_bits: 2,
        group_size_required: true,
        residual_length_required: true,
        residual_full_precision_required: true,
        residual_dtype: "fp16".to_string(),
        tuning_free_claim_source_carded: true,
        quality_preservation_claim_caveated: true,
        memory_reduction_claim_caveated: true,
        throughput_claim_caveated: true,
        apple_silicon_runtime_unproven: true,
        proof_slots: vec![
            KiviStabilityProofSlot::SoftmaxDrift,
            KiviStabilityProofSlot::AttentionOutlier,
            KiviStabilityProofSlot::LongContextRecall,
            KiviStabilityProofSlot::ReasoningQuality,
            KiviStabilityProofSlot::CodingQuality,
            KiviStabilityProofSlot::LatencyAndMemory,
            KiviStabilityProofSlot::BackendCompatibility,
            KiviStabilityProofSlot::RollbackReplay,
        ],
        proof_refs: KiviStabilityProofRefs {
            rollback_ref: "rollback:kivi-asymmetric-kv-stability".to_string(),
            run_event_log_ref: "run_event_log:kivi-asymmetric-kv-stability".to_string(),
            answer_packet_ref: "answer_packet:kivi-asymmetric-kv-stability".to_string(),
            abstention_ref: "abstain:kivi-asymmetric-kv-stability:metadata-only".to_string(),
            caveat_ref: "caveat:kivi-asymmetric-kv:no-apple-silicon-runtime-proof".to_string(),
        },
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        metadata_bytes: 64_000,
        byte_ledger: KiviStabilityByteLedger::metadata_only(),
        direct_import_allowed: false,
        clean_room_rewrite_required: true,
        route_authority_allowed: false,
        hidden_cache_authority: false,
        raw_prompt_logged: false,
        raw_token_logged: false,
        low_bit_kv_live_claimed: false,
        quality_green_claimed: false,
        memory_fit_claimed: false,
        mas_promoted: false,
        l2_green_claimed: false,
        l3_green_claimed: false,
        live_dense_70b_claimed: false,
        ssd_as_ram_claimed: false,
    }
}

// UAS: uas:kivi-stability-source:error
// Plane: Verification.
// Residency: validation failure only.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum KiviAsymmetricKvStabilityError {
    MetadataBudget,
    InvalidCard(String),
    UnsafeClaim(String),
}

impl fmt::Display for KiviAsymmetricKvStabilityError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MetadataBudget => write!(f, "KIVI stability metadata budget invalid"),
            Self::InvalidCard(reason) => write!(f, "invalid KIVI stability card: {reason}"),
            Self::UnsafeClaim(reason) => write!(f, "unsafe KIVI stability claim: {reason}"),
        }
    }
}

impl std::error::Error for KiviAsymmetricKvStabilityError {}

fn validate_card(
    card: &KiviAsymmetricKvStabilitySourceCard,
) -> Result<(), KiviAsymmetricKvStabilityError> {
    if !is_clean_id(&card.card_id) || card.metadata_bytes == 0 {
        return Err(KiviAsymmetricKvStabilityError::InvalidCard(
            "card id or metadata bytes invalid".to_string(),
        ));
    }
    if card.metadata_bytes > MAX_CARD_METADATA_BYTES {
        return Err(KiviAsymmetricKvStabilityError::InvalidCard(
            "card metadata budget exceeded".to_string(),
        ));
    }
    if card.upstream_falsifier_id != UPSTREAM_LLAMA_CPP_CARD
        || card.upstream_artifact_path != UPSTREAM_LLAMA_CPP_ARTIFACT
    {
        return Err(KiviAsymmetricKvStabilityError::InvalidCard(
            "upstream command-card witness missing".to_string(),
        ));
    }
    if card.arxiv_url != ARXIV_URL
        || card.github_url != GITHUB_URL
        || !starts_sha(&card.source_retrieval_digest)
        || card.arxiv_version != "v2-2024-07-25"
        || card.venue != "ICML2024"
        || card.repo_license != "MIT"
    {
        return Err(KiviAsymmetricKvStabilityError::InvalidCard(
            "primary source facts invalid".to_string(),
        ));
    }
    if !card.implementation_language.contains("Cuda")
        || unique_backend_lane_count(&card.backend_lanes) != 4
        || !card
            .backend_lanes
            .contains(&KiviBackendLane::AppleSiliconUnproven)
        || !card
            .backend_lanes
            .contains(&KiviBackendLane::RuntimeRouterDenied)
    {
        return Err(KiviAsymmetricKvStabilityError::InvalidCard(
            "backend caveats invalid".to_string(),
        ));
    }
    if unique_kv_axis_policy_count(&card.kv_axis_policies) != 2
        || !card
            .kv_axis_policies
            .contains(&KiviKvAxisPolicy::KeyPerChannel)
        || !card
            .kv_axis_policies
            .contains(&KiviKvAxisPolicy::ValuePerToken)
        || card.k_bits != 2
        || card.v_bits != 2
    {
        return Err(KiviAsymmetricKvStabilityError::InvalidCard(
            "asymmetric 2-bit K/V policy invalid".to_string(),
        ));
    }
    if !card.group_size_required
        || !card.residual_length_required
        || !card.residual_full_precision_required
        || card.residual_dtype != "fp16"
    {
        return Err(KiviAsymmetricKvStabilityError::InvalidCard(
            "group size or residual full-precision policy missing".to_string(),
        ));
    }
    if !card.tuning_free_claim_source_carded
        || !card.quality_preservation_claim_caveated
        || !card.memory_reduction_claim_caveated
        || !card.throughput_claim_caveated
        || !card.apple_silicon_runtime_unproven
    {
        return Err(KiviAsymmetricKvStabilityError::UnsafeClaim(
            "source claims must be caveated and Apple Silicon runtime unproven".to_string(),
        ));
    }
    if unique_proof_slot_count(&card.proof_slots) != 8 {
        return Err(KiviAsymmetricKvStabilityError::InvalidCard(
            "stability proof slots incomplete".to_string(),
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
        || !card.proof_refs.caveat_ref.starts_with(CAVEAT_PREFIX)
    {
        return Err(KiviAsymmetricKvStabilityError::InvalidCard(
            "proof refs invalid".to_string(),
        ));
    }
    if card.product_build != ProductBuild::Pro || card.pro_status != ProStatus::ResearchCandidate {
        return Err(KiviAsymmetricKvStabilityError::UnsafeClaim(
            "KIVI card must remain Pro ResearchCandidate".to_string(),
        ));
    }
    if card.byte_ledger.model_bytes_loaded != 0
        || card.byte_ledger.kv_bytes_loaded != 0
        || card.byte_ledger.runtime_bytes_loaded != 0
        || card.byte_ledger.source_tree_bytes_opened != 0
        || card.byte_ledger.cuda_kernel_bytes_loaded != 0
        || card.byte_ledger.provider_calls_made != 0
        || card.byte_ledger.benchmark_bytes_opened != 0
        || card.byte_ledger.product_bytes_opened != 0
    {
        return Err(KiviAsymmetricKvStabilityError::UnsafeClaim(
            "metadata witness cannot load/open model, KV, runtime, source, benchmark, or product bytes"
                .to_string(),
        ));
    }
    if card.direct_import_allowed
        || !card.clean_room_rewrite_required
        || card.route_authority_allowed
        || card.hidden_cache_authority
        || card.raw_prompt_logged
        || card.raw_token_logged
        || card.low_bit_kv_live_claimed
        || card.quality_green_claimed
        || card.memory_fit_claimed
        || card.mas_promoted
        || card.l2_green_claimed
        || card.l3_green_claimed
        || card.live_dense_70b_claimed
        || card.ssd_as_ram_claimed
    {
        return Err(KiviAsymmetricKvStabilityError::UnsafeClaim(
            "unsafe import, route, logging, quality, memory, or promotion claim".to_string(),
        ));
    }
    Ok(())
}

fn unique_backend_lane_count(lanes: &[KiviBackendLane]) -> u64 {
    lanes.iter().copied().collect::<BTreeSet<_>>().len() as u64
}

fn unique_kv_axis_policy_count(policies: &[KiviKvAxisPolicy]) -> u64 {
    policies.iter().copied().collect::<BTreeSet<_>>().len() as u64
}

fn unique_proof_slot_count(slots: &[KiviStabilityProofSlot]) -> u64 {
    slots.iter().copied().collect::<BTreeSet<_>>().len() as u64
}

fn set_preimage(card: &KiviAsymmetricKvStabilitySourceCard, metadata_bytes: u64) -> String {
    format!(
        "{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
        KIVI_ASYMMETRIC_KV_STABILITY_SOURCE_CARD_ID,
        card.upstream_falsifier_id,
        card.source_retrieval_digest,
        card.arxiv_version,
        card.k_bits,
        card.v_bits,
        card.residual_dtype,
        card.proof_refs.rollback_ref,
        card.proof_refs.answer_packet_ref,
        card.proof_refs.caveat_ref,
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

    const CREATED_AT_MS: u64 = 1_779_158_400_000;

    fn build(
        card: KiviAsymmetricKvStabilitySourceCard,
    ) -> Result<KiviAsymmetricKvStabilitySourceCardSet, KiviAsymmetricKvStabilityError> {
        KiviAsymmetricKvStabilitySourceCardSet::new(card, 112_000, CREATED_AT_MS)
    }

    #[test]
    fn canonical_card_passes_and_is_deterministic() {
        let card = canonical_kivi_asymmetric_kv_stability_source_card();
        let first = build(card.clone()).expect("canonical KIVI card should pass");
        let mut shuffled = card;
        shuffled.backend_lanes.reverse();
        shuffled.kv_axis_policies.reverse();
        shuffled.proof_slots.reverse();
        let second = build(shuffled).expect("shuffled KIVI card should pass");
        assert_eq!(first.set_address, second.set_address);
        let metrics = first.metrics();
        assert_eq!(metrics.backend_lane_count, 4);
        assert_eq!(metrics.kv_axis_policy_count, 2);
        assert_eq!(metrics.proof_slot_count, 8);
        assert_eq!(metrics.kv_bytes_loaded, 0);
    }

    #[test]
    fn rejects_missing_axis_or_residual_policy() {
        let mut card = canonical_kivi_asymmetric_kv_stability_source_card();
        card.kv_axis_policies
            .retain(|policy| *policy != KiviKvAxisPolicy::KeyPerChannel);
        assert!(build(card).is_err());

        let mut card = canonical_kivi_asymmetric_kv_stability_source_card();
        card.residual_full_precision_required = false;
        assert!(build(card).is_err());
    }

    #[test]
    fn rejects_runtime_or_promotion_claims() {
        let mut card = canonical_kivi_asymmetric_kv_stability_source_card();
        card.byte_ledger.kv_bytes_loaded = 1;
        assert!(build(card).is_err());

        let mut card = canonical_kivi_asymmetric_kv_stability_source_card();
        card.low_bit_kv_live_claimed = true;
        assert!(build(card).is_err());

        let mut card = canonical_kivi_asymmetric_kv_stability_source_card();
        card.l3_green_claimed = true;
        assert!(build(card).is_err());
    }
}
