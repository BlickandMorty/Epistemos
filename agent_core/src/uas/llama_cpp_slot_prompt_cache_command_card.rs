//! Llama.cpp slot prompt-cache command card.
//!
//! This primitive turns Pass 130 into a metadata-only command-card witness for
//! llama.cpp server slot prompt-cache save/restore/erase. It binds endpoint
//! shape, slot id policy, cache-root policy, cache identity digests, rollback,
//! RunEventLog, AnswerPacket, and abstention without starting a server,
//! arming a command, or opening prompt-cache/model/KV/runtime bytes.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, UasAddress, UasKind, KV_CACHE_IDENTITY_SALT_OFFLOAD_PROOF_PACKET_ID,
};

pub const LLAMA_CPP_SLOT_PROMPT_CACHE_COMMAND_CARD_ID: &str =
    "F-LlamaCppSlotPromptCacheCommandCard";
pub const LLAMA_CPP_SLOT_PROMPT_CACHE_COMMAND_CARD_CURSOR: &str =
    "llama_cpp_slot_prompt_cache_command_card";
pub const LLAMA_CPP_SLOT_PROMPT_CACHE_COMMAND_CARD_NEXT_CURSOR: &str =
    "kivi_asymmetric_kv_stability_source_card";

const SOURCE_URL: &str = "https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md";
const ENDPOINT_TEMPLATE: &str = "/slots/{id_slot}?action=<save|restore|erase>";
const CACHE_ROOT_SCOPE: &str = "cache_root:artifacts/kv-cache/llama-cpp-slot";
const PARENT_ARTIFACT: &str =
    "artifacts/falsifiers/kv_cache_identity_salt_offload_proof_packet/result.json";
const SHA256_PREFIX: &str = "sha256:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const ABSTENTION_PREFIX: &str = "abstain:";
const OWNER_APPROVAL_PREFIX: &str = "owner_approval:";
const MAX_SET_METADATA_BYTES: u64 = 160 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 96 * 1024;

// UAS: uas:llama-cpp-slot-prompt-cache:action
// Plane: Controller.
// Residency: endpoint action label only; no HTTP call is made.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LlamaCppSlotCacheAction {
    Save,
    Restore,
    Erase,
}

// UAS: uas:llama-cpp-slot-prompt-cache:expected-field
// Plane: Verification.
// Residency: response metadata names only; no response bytes are captured.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LlamaCppSlotCacheExpectedField {
    IdSlot,
    Filename,
    NSaved,
    NWritten,
    NRestored,
    NRead,
    NErased,
    SaveMs,
    RestoreMs,
}

// UAS: uas:llama-cpp-slot-prompt-cache:proof-refs
// Plane: Verification.
// Residency: visible proof handles only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LlamaCppSlotCacheProofRefs {
    pub owner_approval_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
}

// UAS: uas:llama-cpp-slot-prompt-cache:byte-ledger
// Plane: Verification.
// Residency: zero-byte metadata boundary for the witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LlamaCppSlotCacheByteLedger {
    pub prompt_cache_file_bytes_opened: u64,
    pub model_bytes_loaded: u64,
    pub kv_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub source_tree_bytes_opened: u64,
    pub product_bytes_opened: u64,
    pub command_armed_count: u64,
    pub server_start_count: u64,
}

impl LlamaCppSlotCacheByteLedger {
    pub fn metadata_only() -> Self {
        Self {
            prompt_cache_file_bytes_opened: 0,
            model_bytes_loaded: 0,
            kv_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            source_tree_bytes_opened: 0,
            product_bytes_opened: 0,
            command_armed_count: 0,
            server_start_count: 0,
        }
    }
}

// UAS: uas:llama-cpp-slot-prompt-cache:command-card
// Plane: Assembly + Controller + Verification.
// Residency: unarmed endpoint command card; no server or cache file access.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LlamaCppSlotPromptCacheCommandCard {
    pub card_id: String,
    pub parent_falsifier_id: String,
    pub parent_artifact_path: String,
    pub parent_packet_address: String,
    pub source_url: String,
    pub source_retrieval_digest: String,
    pub endpoint_template: String,
    pub actions: Vec<LlamaCppSlotCacheAction>,
    pub slot_id_min: u32,
    pub slot_id_max: u32,
    pub filename_example: String,
    pub filename_policy: String,
    pub slot_save_path_scope: String,
    pub uas_cache_artifact_address: String,
    pub session_id_digest: String,
    pub prompt_digest: String,
    pub tokenizer_digest: String,
    pub chat_template_digest: String,
    pub tool_schema_digest: String,
    pub model_artifact_digest: String,
    pub adapter_modality_digest: String,
    pub cache_salt_digest: String,
    pub expected_fields: Vec<LlamaCppSlotCacheExpectedField>,
    pub deletion_policy: String,
    pub proof_refs: LlamaCppSlotCacheProofRefs,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_bytes: u64,
    pub byte_ledger: LlamaCppSlotCacheByteLedger,
    pub owner_approval_pending: bool,
    pub command_envelope_unarmed: bool,
    pub server_start_denied: bool,
    pub raw_prompt_logged: bool,
    pub raw_token_logged: bool,
    pub stdout_stderr_captured: bool,
    pub hidden_route_authority: bool,
    pub cache_file_presence_quality_claim: bool,
    pub restored_cache_model_fit_claim: bool,
    pub mas_promoted: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:llama-cpp-slot-prompt-cache:card-set
// Plane: State + Verification.
// Residency: metadata-only card set.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LlamaCppSlotPromptCacheCommandCardSet {
    pub set_address: UasAddress,
    pub card: LlamaCppSlotPromptCacheCommandCard,
    pub metadata_bytes: u64,
    pub metadata_only: bool,
    pub no_server_started: bool,
    pub no_command_armed: bool,
    pub no_prompt_cache_bytes_opened: bool,
    pub product_promotion_blocked: bool,
}

// UAS: uas:llama-cpp-slot-prompt-cache:metrics
// Plane: Verification.
// Residency: derived counters for falsifier axes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LlamaCppSlotPromptCacheMetrics {
    pub card_count: u64,
    pub action_count: u64,
    pub expected_field_count: u64,
    pub prompt_cache_file_bytes_opened: u64,
    pub model_bytes_loaded: u64,
    pub kv_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub source_tree_bytes_opened: u64,
    pub product_bytes_opened: u64,
    pub command_armed_count: u64,
    pub server_start_count: u64,
    pub owner_approval_pending_count: u64,
    pub raw_prompt_logged_count: u64,
    pub raw_token_logged_count: u64,
    pub stdout_stderr_captured_count: u64,
    pub hidden_route_authority_count: u64,
    pub cache_file_presence_quality_claim_count: u64,
    pub restored_cache_model_fit_claim_count: u64,
    pub mas_promotion_count: u64,
    pub l2_green_claim_count: u64,
    pub l3_green_claim_count: u64,
    pub live_dense_70b_claim_count: u64,
    pub ssd_as_ram_claim_count: u64,
}

impl LlamaCppSlotPromptCacheCommandCardSet {
    pub fn new(
        mut card: LlamaCppSlotPromptCacheCommandCard,
        metadata_bytes: u64,
        created_at_ms: u64,
    ) -> Result<Self, LlamaCppSlotPromptCacheError> {
        validate_card(&card)?;
        if metadata_bytes == 0 || metadata_bytes > MAX_SET_METADATA_BYTES {
            return Err(LlamaCppSlotPromptCacheError::MetadataBudget);
        }
        card.actions.sort();
        card.expected_fields.sort();
        let preimage = set_preimage(&card, metadata_bytes);
        Ok(Self {
            set_address: UasAddress::new(
                UasKind::Other(LLAMA_CPP_SLOT_PROMPT_CACHE_COMMAND_CARD_CURSOR.to_string()),
                preimage.as_bytes(),
                created_at_ms,
            ),
            card,
            metadata_bytes,
            metadata_only: true,
            no_server_started: true,
            no_command_armed: true,
            no_prompt_cache_bytes_opened: true,
            product_promotion_blocked: true,
        })
    }

    pub fn metrics(&self) -> LlamaCppSlotPromptCacheMetrics {
        let card = &self.card;
        LlamaCppSlotPromptCacheMetrics {
            card_count: 1,
            action_count: unique_action_count(&card.actions),
            expected_field_count: unique_expected_field_count(&card.expected_fields),
            prompt_cache_file_bytes_opened: card.byte_ledger.prompt_cache_file_bytes_opened,
            model_bytes_loaded: card.byte_ledger.model_bytes_loaded,
            kv_bytes_loaded: card.byte_ledger.kv_bytes_loaded,
            runtime_bytes_loaded: card.byte_ledger.runtime_bytes_loaded,
            provider_calls_made: card.byte_ledger.provider_calls_made,
            source_tree_bytes_opened: card.byte_ledger.source_tree_bytes_opened,
            product_bytes_opened: card.byte_ledger.product_bytes_opened,
            command_armed_count: card.byte_ledger.command_armed_count,
            server_start_count: card.byte_ledger.server_start_count,
            owner_approval_pending_count: u64::from(card.owner_approval_pending),
            raw_prompt_logged_count: u64::from(card.raw_prompt_logged),
            raw_token_logged_count: u64::from(card.raw_token_logged),
            stdout_stderr_captured_count: u64::from(card.stdout_stderr_captured),
            hidden_route_authority_count: u64::from(card.hidden_route_authority),
            cache_file_presence_quality_claim_count: u64::from(
                card.cache_file_presence_quality_claim,
            ),
            restored_cache_model_fit_claim_count: u64::from(card.restored_cache_model_fit_claim),
            mas_promotion_count: u64::from(card.mas_promoted),
            l2_green_claim_count: u64::from(card.l2_green_claimed),
            l3_green_claim_count: u64::from(card.l3_green_claimed),
            live_dense_70b_claim_count: u64::from(card.live_dense_70b_claimed),
            ssd_as_ram_claim_count: u64::from(card.ssd_as_ram_claimed),
        }
    }
}

pub fn canonical_llama_cpp_slot_prompt_cache_command_card() -> LlamaCppSlotPromptCacheCommandCard {
    LlamaCppSlotPromptCacheCommandCard {
        card_id: "llama_cpp_slot_prompt_cache_command_card".to_string(),
        parent_falsifier_id: KV_CACHE_IDENTITY_SALT_OFFLOAD_PROOF_PACKET_ID.to_string(),
        parent_artifact_path: PARENT_ARTIFACT.to_string(),
        parent_packet_address: "kv_cache_identity_salt_offload_proof_packet:190f70b5238f764552e25ef5e3d086afff42d30ee4c9824c098fe4098b7027eb@1779072000000".to_string(),
        source_url: SOURCE_URL.to_string(),
        source_retrieval_digest: "sha256:llama-cpp-server-readme-pass130".to_string(),
        endpoint_template: ENDPOINT_TEMPLATE.to_string(),
        actions: vec![
            LlamaCppSlotCacheAction::Save,
            LlamaCppSlotCacheAction::Restore,
            LlamaCppSlotCacheAction::Erase,
        ],
        slot_id_min: 0,
        slot_id_max: 1024,
        filename_example: "slot_save_file.bin".to_string(),
        filename_policy: "policy:basename-only-dot-bin-no-hidden-no-shell-no-path".to_string(),
        slot_save_path_scope: CACHE_ROOT_SCOPE.to_string(),
        uas_cache_artifact_address: "uas:appcoldstore:llama-cpp-slot-prompt-cache".to_string(),
        session_id_digest: "sha256:session-id-redacted-pass130".to_string(),
        prompt_digest: "sha256:prompt-redacted-pass130".to_string(),
        tokenizer_digest: "sha256:tokenizer-pass130".to_string(),
        chat_template_digest: "sha256:chat-template-pass130".to_string(),
        tool_schema_digest: "sha256:tool-schema-pass130".to_string(),
        model_artifact_digest: "sha256:model-artifact-pass130".to_string(),
        adapter_modality_digest: "sha256:adapter-modality-pass130".to_string(),
        cache_salt_digest: "sha256:cache-salt-pass130".to_string(),
        expected_fields: vec![
            LlamaCppSlotCacheExpectedField::IdSlot,
            LlamaCppSlotCacheExpectedField::Filename,
            LlamaCppSlotCacheExpectedField::NSaved,
            LlamaCppSlotCacheExpectedField::NWritten,
            LlamaCppSlotCacheExpectedField::NRestored,
            LlamaCppSlotCacheExpectedField::NRead,
            LlamaCppSlotCacheExpectedField::NErased,
            LlamaCppSlotCacheExpectedField::SaveMs,
            LlamaCppSlotCacheExpectedField::RestoreMs,
        ],
        deletion_policy: "policy:erase-cache-on-rollback-and-owner-purge".to_string(),
        proof_refs: LlamaCppSlotCacheProofRefs {
            owner_approval_ref: "owner_approval:pending:llama-cpp-slot-cache".to_string(),
            rollback_ref: "rollback:llama-cpp-slot-cache-command-card".to_string(),
            run_event_log_ref: "run_event_log:llama-cpp-slot-cache-command-card".to_string(),
            answer_packet_ref: "answer_packet:llama-cpp-slot-cache-command-card".to_string(),
            abstention_ref: "abstain:llama-cpp-slot-cache-command-card:metadata-only".to_string(),
        },
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        metadata_bytes: 48_000,
        byte_ledger: LlamaCppSlotCacheByteLedger::metadata_only(),
        owner_approval_pending: true,
        command_envelope_unarmed: true,
        server_start_denied: true,
        raw_prompt_logged: false,
        raw_token_logged: false,
        stdout_stderr_captured: false,
        hidden_route_authority: false,
        cache_file_presence_quality_claim: false,
        restored_cache_model_fit_claim: false,
        mas_promoted: false,
        l2_green_claimed: false,
        l3_green_claimed: false,
        live_dense_70b_claimed: false,
        ssd_as_ram_claimed: false,
    }
}

// UAS: uas:llama-cpp-slot-prompt-cache:error
// Plane: Verification.
// Residency: validation failure only; no runtime side effects.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum LlamaCppSlotPromptCacheError {
    MetadataBudget,
    InvalidCard(String),
    UnsafeClaim(String),
}

impl fmt::Display for LlamaCppSlotPromptCacheError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MetadataBudget => {
                write!(f, "llama.cpp slot command-card metadata budget invalid")
            }
            Self::InvalidCard(reason) => {
                write!(f, "invalid llama.cpp slot command card: {reason}")
            }
            Self::UnsafeClaim(reason) => {
                write!(f, "unsafe llama.cpp slot command-card claim: {reason}")
            }
        }
    }
}

impl std::error::Error for LlamaCppSlotPromptCacheError {}

fn validate_card(
    card: &LlamaCppSlotPromptCacheCommandCard,
) -> Result<(), LlamaCppSlotPromptCacheError> {
    if !is_clean_id(&card.card_id) || card.metadata_bytes == 0 {
        return Err(LlamaCppSlotPromptCacheError::InvalidCard(
            "card id or metadata bytes invalid".to_string(),
        ));
    }
    if card.metadata_bytes > MAX_CARD_METADATA_BYTES {
        return Err(LlamaCppSlotPromptCacheError::InvalidCard(
            "card metadata budget exceeded".to_string(),
        ));
    }
    if card.parent_falsifier_id != KV_CACHE_IDENTITY_SALT_OFFLOAD_PROOF_PACKET_ID {
        return Err(LlamaCppSlotPromptCacheError::InvalidCard(
            "parent cache identity packet missing".to_string(),
        ));
    }
    if card.parent_artifact_path != PARENT_ARTIFACT
        || !card
            .parent_packet_address
            .starts_with("kv_cache_identity_salt_offload_proof_packet:")
    {
        return Err(LlamaCppSlotPromptCacheError::InvalidCard(
            "parent artifact path or address invalid".to_string(),
        ));
    }
    if card.source_url != SOURCE_URL || !starts_sha(&card.source_retrieval_digest) {
        return Err(LlamaCppSlotPromptCacheError::InvalidCard(
            "source URL or retrieval digest invalid".to_string(),
        ));
    }
    if card.endpoint_template != ENDPOINT_TEMPLATE {
        return Err(LlamaCppSlotPromptCacheError::InvalidCard(
            "endpoint template invalid".to_string(),
        ));
    }
    if unique_action_count(&card.actions) != 3
        || !card.actions.contains(&LlamaCppSlotCacheAction::Save)
        || !card.actions.contains(&LlamaCppSlotCacheAction::Restore)
        || !card.actions.contains(&LlamaCppSlotCacheAction::Erase)
    {
        return Err(LlamaCppSlotPromptCacheError::InvalidCard(
            "save, restore, and erase actions required".to_string(),
        ));
    }
    if card.slot_id_min != 0 || card.slot_id_max == 0 || card.slot_id_max > 4096 {
        return Err(LlamaCppSlotPromptCacheError::InvalidCard(
            "slot id bounds invalid".to_string(),
        ));
    }
    if !safe_prompt_cache_filename(&card.filename_example)
        || !card.filename_policy.starts_with("policy:basename-only")
        || card.slot_save_path_scope != CACHE_ROOT_SCOPE
    {
        return Err(LlamaCppSlotPromptCacheError::InvalidCard(
            "filename or cache-root policy invalid".to_string(),
        ));
    }
    if !card
        .uas_cache_artifact_address
        .starts_with("uas:appcoldstore:")
    {
        return Err(LlamaCppSlotPromptCacheError::InvalidCard(
            "UAS cache artifact address invalid".to_string(),
        ));
    }
    for digest in [
        &card.session_id_digest,
        &card.prompt_digest,
        &card.tokenizer_digest,
        &card.chat_template_digest,
        &card.tool_schema_digest,
        &card.model_artifact_digest,
        &card.adapter_modality_digest,
        &card.cache_salt_digest,
    ] {
        if !starts_sha(digest) {
            return Err(LlamaCppSlotPromptCacheError::InvalidCard(
                "identity digest missing".to_string(),
            ));
        }
    }
    if unique_expected_field_count(&card.expected_fields) != 9 {
        return Err(LlamaCppSlotPromptCacheError::InvalidCard(
            "expected response fields incomplete".to_string(),
        ));
    }
    if !is_clean_text(&card.deletion_policy)
        || !card.deletion_policy.contains("erase-cache-on-rollback")
        || !card
            .proof_refs
            .owner_approval_ref
            .starts_with(OWNER_APPROVAL_PREFIX)
        || !card.proof_refs.rollback_ref.starts_with(ROLLBACK_PREFIX)
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
    {
        return Err(LlamaCppSlotPromptCacheError::InvalidCard(
            "proof refs or deletion policy invalid".to_string(),
        ));
    }
    if card.product_build != ProductBuild::Pro || card.pro_status != ProStatus::ResearchCandidate {
        return Err(LlamaCppSlotPromptCacheError::UnsafeClaim(
            "command card must remain Pro ResearchCandidate".to_string(),
        ));
    }
    if !card.owner_approval_pending || !card.command_envelope_unarmed || !card.server_start_denied {
        return Err(LlamaCppSlotPromptCacheError::UnsafeClaim(
            "owner approval pending, unarmed command, and denied server start required".to_string(),
        ));
    }
    if card.byte_ledger.prompt_cache_file_bytes_opened != 0
        || card.byte_ledger.model_bytes_loaded != 0
        || card.byte_ledger.kv_bytes_loaded != 0
        || card.byte_ledger.runtime_bytes_loaded != 0
        || card.byte_ledger.provider_calls_made != 0
        || card.byte_ledger.source_tree_bytes_opened != 0
        || card.byte_ledger.product_bytes_opened != 0
        || card.byte_ledger.command_armed_count != 0
        || card.byte_ledger.server_start_count != 0
    {
        return Err(LlamaCppSlotPromptCacheError::UnsafeClaim(
            "metadata witness cannot open bytes, arm commands, or start server".to_string(),
        ));
    }
    for (flag, reason) in [
        (card.raw_prompt_logged, "raw prompt logging"),
        (card.raw_token_logged, "raw token logging"),
        (card.stdout_stderr_captured, "stdout/stderr capture"),
        (card.hidden_route_authority, "hidden route authority"),
        (
            card.cache_file_presence_quality_claim,
            "cache file presence as quality proof",
        ),
        (
            card.restored_cache_model_fit_claim,
            "restored cache as model-fit proof",
        ),
        (card.mas_promoted, "MAS promotion"),
        (card.l2_green_claimed, "L2 promotion"),
        (card.l3_green_claimed, "L3 promotion"),
        (card.live_dense_70b_claimed, "live dense 70B claim"),
        (card.ssd_as_ram_claimed, "SSD-as-RAM claim"),
    ] {
        if flag {
            return Err(LlamaCppSlotPromptCacheError::UnsafeClaim(
                reason.to_string(),
            ));
        }
    }
    Ok(())
}

fn unique_action_count(actions: &[LlamaCppSlotCacheAction]) -> u64 {
    actions.iter().copied().collect::<BTreeSet<_>>().len() as u64
}

fn unique_expected_field_count(fields: &[LlamaCppSlotCacheExpectedField]) -> u64 {
    fields.iter().copied().collect::<BTreeSet<_>>().len() as u64
}

fn set_preimage(card: &LlamaCppSlotPromptCacheCommandCard, metadata_bytes: u64) -> String {
    format!(
        "{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
        LLAMA_CPP_SLOT_PROMPT_CACHE_COMMAND_CARD_ID,
        card.parent_packet_address,
        card.source_retrieval_digest,
        card.endpoint_template,
        card.filename_policy,
        card.slot_save_path_scope,
        card.cache_salt_digest,
        card.proof_refs.rollback_ref,
        card.proof_refs.answer_packet_ref,
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

fn is_clean_text(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 256
        && !value.contains('\n')
        && !value.contains('\r')
        && !value.contains('\0')
}

fn safe_prompt_cache_filename(value: &str) -> bool {
    if value.is_empty()
        || value.len() > 96
        || value.starts_with('.')
        || value.contains('/')
        || value.contains('\\')
        || value.contains("..")
        || !value.ends_with(".bin")
    {
        return false;
    }
    value
        .bytes()
        .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'_' | b'-' | b'.'))
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_158_400_000;

    fn build(
        card: LlamaCppSlotPromptCacheCommandCard,
    ) -> Result<LlamaCppSlotPromptCacheCommandCardSet, LlamaCppSlotPromptCacheError> {
        LlamaCppSlotPromptCacheCommandCardSet::new(card, 96_000, CREATED_AT_MS)
    }

    #[test]
    fn canonical_card_passes_and_is_deterministic() {
        let card = canonical_llama_cpp_slot_prompt_cache_command_card();
        let first = build(card.clone()).expect("canonical command card should pass");
        let mut shuffled = card;
        shuffled.actions.reverse();
        shuffled.expected_fields.reverse();
        let second = build(shuffled).expect("shuffled canonical command card should pass");
        assert_eq!(first.set_address, second.set_address);
        let metrics = first.metrics();
        assert_eq!(metrics.action_count, 3);
        assert_eq!(metrics.expected_field_count, 9);
        assert_eq!(metrics.prompt_cache_file_bytes_opened, 0);
        assert_eq!(metrics.server_start_count, 0);
    }

    #[test]
    fn rejects_path_escape_and_unsafe_filename() {
        let mut card = canonical_llama_cpp_slot_prompt_cache_command_card();
        card.filename_example = "../slot.bin".to_string();
        assert!(build(card).is_err());

        let mut card = canonical_llama_cpp_slot_prompt_cache_command_card();
        card.slot_save_path_scope = "/tmp/slot-cache".to_string();
        assert!(build(card).is_err());
    }

    #[test]
    fn rejects_runtime_or_promotion_claims() {
        let mut card = canonical_llama_cpp_slot_prompt_cache_command_card();
        card.byte_ledger.command_armed_count = 1;
        assert!(build(card).is_err());

        let mut card = canonical_llama_cpp_slot_prompt_cache_command_card();
        card.restored_cache_model_fit_claim = true;
        assert!(build(card).is_err());

        let mut card = canonical_llama_cpp_slot_prompt_cache_command_card();
        card.l3_green_claimed = true;
        assert!(build(card).is_err());
    }
}
