//! Small compressed-model local runtime command card.
//!
//! This primitive records the local GGUF command inventory needed after the
//! owner-approval gate, while keeping model load, command arming, provider
//! fallback, and product promotion fail-closed.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, SmallCompressedHarnessPromotionTier, UasAddress, UasKind,
};

pub const SMALL_COMPRESSED_MODEL_LOCAL_RUNTIME_COMMAND_CARD_CURSOR: &str =
    "small_compressed_model_local_runtime_command_card";
pub const SMALL_COMPRESSED_MODEL_LOCAL_RUNTIME_COMMAND_CARD_NEXT_CURSOR: &str =
    "small_compressed_model_owner_approved_runtime_probe";

const UPSTREAM_OWNER_GATE_PREFIX: &str =
    "artifact:small_compressed_model_owner_approval_runtime_gate:";
const MODEL_PATH_PREFIX: &str = "model_path:pending_owner_approval:";
const COMMAND_LEDGER_PREFIX: &str = "command_ledger:small_compressed_local_runtime:";
const LOCAL_VERSION_PREFIX: &str = "local_version:llama.cpp:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:small_compressed_local_runtime:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:small_compressed_local_runtime:";
const ROLLBACK_PREFIX: &str = "rollback:small_compressed_local_runtime:";
const CANCELLATION_PREFIX: &str = "cancel:small_compressed_local_runtime:";
const MEMORY_LEDGER_PREFIX: &str = "memory_ledger:small_compressed_local_runtime:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:small_compressed_local_runtime:";
const DENIED_SIDE_CAR_PREFIX: &str = "denied_sidecar:";
const ROUTE_CAVEAT_PREFIX: &str = "route_caveat:small_compressed_local_runtime:";
const MAX_SET_METADATA_BYTES: u64 = 128 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 64 * 1024;
const MIN_VISIBLE_SUMMARY_BYTES: usize = 160;
const SELECTED_E2B_CANDIDATE: &str = "gemma4_e2b_qat_gguf_harness_preflight";
const E2B_MODEL_ID: &str = "google/gemma-4-E2B-it-qat-q4_0-gguf";
const LLAMA_CLI_PATH: &str = "/opt/homebrew/bin/llama-cli";
const LLAMA_SERVER_PATH: &str = "/opt/homebrew/bin/llama-server";

// UAS: uas:small-compressed-local-runtime-command:role
// Plane: Controller
// Residency: command inventory only; command execution is a later witness.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SmallCompressedLocalRuntimeCommandRole {
    DirectLlamaCli,
    DeniedLlamaServerSidecar,
}

// UAS: uas:small-compressed-local-runtime-command:byte-ledger
// Plane: Verification
// Residency: path metadata only; model/runtime/provider byte counts stay zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedLocalRuntimeCommandByteLedger {
    pub path_metadata_bytes_read: u64,
    pub opened_model_bytes: u64,
    pub opened_runtime_bytes: u64,
    pub resident_model_bytes: u64,
    pub resident_runtime_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

impl SmallCompressedLocalRuntimeCommandByteLedger {
    pub fn metadata_only(path_metadata_bytes_read: u64) -> Self {
        Self {
            path_metadata_bytes_read,
            opened_model_bytes: 0,
            opened_runtime_bytes: 0,
            resident_model_bytes: 0,
            resident_runtime_bytes: 0,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
        }
    }
}

// UAS: uas:small-compressed-local-runtime-command:refs
// Plane: Verification
// Residency: refs required before owner-approved execution can be armed.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedLocalRuntimeCommandRefs {
    pub upstream_owner_gate_ref: String,
    pub model_path_ref: String,
    pub command_ledger_ref: String,
    pub local_version_ref: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub rollback_ref: String,
    pub cancellation_ref: String,
    pub memory_ledger_ref: String,
    pub compatibility_fence_ref: String,
    pub denied_sidecar_ref: String,
    pub route_caveat_ref: String,
}

// UAS: uas:small-compressed-local-runtime-command:card
// Plane: Controller + Verification
// Residency: local command inventory only, not an inference route.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedModelLocalRuntimeCommandCard {
    pub card_id: String,
    pub selected_candidate_id: String,
    pub model_id: String,
    pub command_role: SmallCompressedLocalRuntimeCommandRole,
    pub command_path: String,
    pub resolved_path: String,
    pub command_path_present: bool,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: SmallCompressedHarnessPromotionTier,
    pub bytes: SmallCompressedLocalRuntimeCommandByteLedger,
    pub refs: SmallCompressedLocalRuntimeCommandRefs,
    pub user_visible_summary: String,
    pub command_visible: bool,
    pub model_path_status_visible: bool,
    pub command_ledger_visible: bool,
    pub denied_sidecar_visible: bool,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub command_armed: bool,
    pub command_executed: bool,
    pub inference_executed: bool,
    pub model_file_opened: bool,
    pub first_token_claimed: bool,
    pub retained_token_digest_recorded: bool,
    pub quality_claimed: bool,
    pub l2_capability_claimed: bool,
    pub l3_wrv_claimed: bool,
    pub mas_readiness_claimed: bool,
    pub answer_packet_required: bool,
    pub run_event_log_required: bool,
    pub rollback_required: bool,
    pub cancellation_required: bool,
    pub memory_ledger_required: bool,
    pub route_policy_mutated: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub hidden_route_authority_allowed: bool,
    pub provider_fallback_allowed: bool,
    pub server_sidecar_default_allowed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:small-compressed-local-runtime-command:set
// Plane: Controller + Verification
// Residency: command inventory set bound to owner-approval gate witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedModelLocalRuntimeCommandCardSet {
    pub set_address: UasAddress,
    pub upstream_owner_gate_set_address: UasAddress,
    pub upstream_owner_gate_witness_ref: String,
    pub selected_card_id: String,
    pub cards: Vec<SmallCompressedModelLocalRuntimeCommandCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub runtime_deferred: bool,
    pub product_promotion_blocked: bool,
}

// UAS: uas:small-compressed-local-runtime-command:metrics
// Plane: Verification
// Residency: derived command inventory counts.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmallCompressedLocalRuntimeCommandMetrics {
    pub command_card_count: u64,
    pub direct_cli_card_count: u64,
    pub denied_server_sidecar_count: u64,
    pub present_command_path_count: u64,
    pub path_metadata_bytes_read: u64,
    pub opened_model_bytes: u64,
    pub opened_runtime_bytes: u64,
    pub resident_model_bytes: u64,
    pub resident_runtime_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

impl SmallCompressedModelLocalRuntimeCommandCardSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_owner_gate(
        upstream_owner_gate_set_address: UasAddress,
        upstream_owner_gate_witness_ref: impl Into<String>,
        selected_card_id: impl Into<String>,
        mut cards: Vec<SmallCompressedModelLocalRuntimeCommandCard>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        runtime_deferred: bool,
        product_promotion_blocked: bool,
        created_at_ms: u64,
    ) -> Result<Self, SmallCompressedLocalRuntimeCommandCardError> {
        cards.sort_by(|a, b| a.card_id.cmp(&b.card_id));
        let witness_ref = upstream_owner_gate_witness_ref.into();
        let selected_card_id = selected_card_id.into();
        validate_set_inputs(
            &upstream_owner_gate_set_address,
            &witness_ref,
            &selected_card_id,
            &cards,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        )?;
        let preimage = command_card_set_preimage(
            &upstream_owner_gate_set_address,
            &witness_ref,
            &selected_card_id,
            &cards,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        );
        let set_address = UasAddress::new(
            UasKind::Other(SMALL_COMPRESSED_MODEL_LOCAL_RUNTIME_COMMAND_CARD_CURSOR.to_string()),
            preimage.as_bytes(),
            created_at_ms,
        );
        Ok(Self {
            set_address,
            upstream_owner_gate_set_address,
            upstream_owner_gate_witness_ref: witness_ref,
            selected_card_id,
            cards,
            product_build,
            pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            runtime_deferred,
            product_promotion_blocked,
        })
    }

    pub fn metrics(&self) -> SmallCompressedLocalRuntimeCommandMetrics {
        let mut metrics = SmallCompressedLocalRuntimeCommandMetrics {
            command_card_count: self.cards.len() as u64,
            direct_cli_card_count: 0,
            denied_server_sidecar_count: 0,
            present_command_path_count: 0,
            path_metadata_bytes_read: 0,
            opened_model_bytes: 0,
            opened_runtime_bytes: 0,
            resident_model_bytes: 0,
            resident_runtime_bytes: 0,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
        };
        for card in &self.cards {
            match card.command_role {
                SmallCompressedLocalRuntimeCommandRole::DirectLlamaCli => {
                    metrics.direct_cli_card_count += 1;
                }
                SmallCompressedLocalRuntimeCommandRole::DeniedLlamaServerSidecar => {
                    metrics.denied_server_sidecar_count += 1;
                }
            }
            if card.command_path_present {
                metrics.present_command_path_count += 1;
            }
            metrics.path_metadata_bytes_read = metrics
                .path_metadata_bytes_read
                .saturating_add(card.bytes.path_metadata_bytes_read);
            metrics.opened_model_bytes = metrics
                .opened_model_bytes
                .saturating_add(card.bytes.opened_model_bytes);
            metrics.opened_runtime_bytes = metrics
                .opened_runtime_bytes
                .saturating_add(card.bytes.opened_runtime_bytes);
            metrics.resident_model_bytes = metrics
                .resident_model_bytes
                .saturating_add(card.bytes.resident_model_bytes);
            metrics.resident_runtime_bytes = metrics
                .resident_runtime_bytes
                .saturating_add(card.bytes.resident_runtime_bytes);
            metrics.model_bytes_loaded = metrics
                .model_bytes_loaded
                .saturating_add(card.bytes.model_bytes_loaded);
            metrics.runtime_bytes_loaded = metrics
                .runtime_bytes_loaded
                .saturating_add(card.bytes.runtime_bytes_loaded);
            metrics.provider_calls_made = metrics
                .provider_calls_made
                .saturating_add(card.bytes.provider_calls_made);
        }
        metrics
    }
}

// UAS: uas:small-compressed-local-runtime-command:error
// Plane: Verification
// Residency: validation error only; no command or model bytes.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SmallCompressedLocalRuntimeCommandCardError {
    InvalidSet(String),
    InvalidCard(String),
}

impl fmt::Display for SmallCompressedLocalRuntimeCommandCardError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidSet(message) => write!(f, "invalid command-card set: {message}"),
            Self::InvalidCard(message) => write!(f, "invalid command card: {message}"),
        }
    }
}

impl std::error::Error for SmallCompressedLocalRuntimeCommandCardError {}

#[allow(clippy::too_many_arguments)]
fn validate_set_inputs(
    upstream_owner_gate_set_address: &UasAddress,
    upstream_owner_gate_witness_ref: &str,
    selected_card_id: &str,
    cards: &[SmallCompressedModelLocalRuntimeCommandCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> Result<(), SmallCompressedLocalRuntimeCommandCardError> {
    if upstream_owner_gate_set_address.to_string().is_empty() {
        return Err(SmallCompressedLocalRuntimeCommandCardError::InvalidSet(
            "upstream owner-gate address is empty".to_string(),
        ));
    }
    if !upstream_owner_gate_witness_ref.starts_with(UPSTREAM_OWNER_GATE_PREFIX) {
        return Err(SmallCompressedLocalRuntimeCommandCardError::InvalidSet(
            "upstream owner-gate witness ref must bind the owner gate".to_string(),
        ));
    }
    if selected_card_id.is_empty() {
        return Err(SmallCompressedLocalRuntimeCommandCardError::InvalidSet(
            "selected card id is empty".to_string(),
        ));
    }
    if cards.len() != 2 {
        return Err(SmallCompressedLocalRuntimeCommandCardError::InvalidSet(
            "expected direct CLI and denied server sidecar cards".to_string(),
        ));
    }
    if *product_build != ProductBuild::Pro || *pro_status != ProStatus::ResearchCandidate {
        return Err(SmallCompressedLocalRuntimeCommandCardError::InvalidSet(
            "command-card set must remain Pro ResearchCandidate".to_string(),
        ));
    }
    if metadata_bytes == 0 || metadata_bytes > MAX_SET_METADATA_BYTES {
        return Err(SmallCompressedLocalRuntimeCommandCardError::InvalidSet(
            "set metadata budget is invalid".to_string(),
        ));
    }
    if !l1_l2_l3_separated || !runtime_deferred || !product_promotion_blocked {
        return Err(SmallCompressedLocalRuntimeCommandCardError::InvalidSet(
            "L1/L2/L3 separation, runtime deferral, and product block are required".to_string(),
        ));
    }

    let mut ids = HashSet::with_capacity(cards.len());
    let mut direct_cli_count = 0;
    let mut denied_server_count = 0;
    let mut selected_seen = false;
    for card in cards {
        validate_card(card)?;
        if !ids.insert(card.card_id.as_str()) {
            return Err(SmallCompressedLocalRuntimeCommandCardError::InvalidSet(
                "duplicate command-card id".to_string(),
            ));
        }
        match card.command_role {
            SmallCompressedLocalRuntimeCommandRole::DirectLlamaCli => direct_cli_count += 1,
            SmallCompressedLocalRuntimeCommandRole::DeniedLlamaServerSidecar => {
                denied_server_count += 1;
            }
        }
        if card.card_id == selected_card_id {
            selected_seen = true;
            if card.command_role != SmallCompressedLocalRuntimeCommandRole::DirectLlamaCli {
                return Err(SmallCompressedLocalRuntimeCommandCardError::InvalidSet(
                    "selected command card must be the direct llama-cli card".to_string(),
                ));
            }
        }
    }
    if direct_cli_count != 1 || denied_server_count != 1 || !selected_seen {
        return Err(SmallCompressedLocalRuntimeCommandCardError::InvalidSet(
            "exactly one direct CLI card, one denied server card, and one selected card are required"
                .to_string(),
        ));
    }
    Ok(())
}

fn validate_card(
    card: &SmallCompressedModelLocalRuntimeCommandCard,
) -> Result<(), SmallCompressedLocalRuntimeCommandCardError> {
    if card.card_id.trim().is_empty() {
        return Err(SmallCompressedLocalRuntimeCommandCardError::InvalidCard(
            "card id is empty".to_string(),
        ));
    }
    if card.selected_candidate_id != SELECTED_E2B_CANDIDATE || card.model_id != E2B_MODEL_ID {
        return Err(SmallCompressedLocalRuntimeCommandCardError::InvalidCard(
            "only the selected E2B QAT GGUF candidate is allowed".to_string(),
        ));
    }
    let expected_path = match card.command_role {
        SmallCompressedLocalRuntimeCommandRole::DirectLlamaCli => LLAMA_CLI_PATH,
        SmallCompressedLocalRuntimeCommandRole::DeniedLlamaServerSidecar => LLAMA_SERVER_PATH,
    };
    if card.command_path != expected_path || !card.command_path_present {
        return Err(SmallCompressedLocalRuntimeCommandCardError::InvalidCard(
            "expected local command path is not visible".to_string(),
        ));
    }
    if card.resolved_path.trim().is_empty() {
        return Err(SmallCompressedLocalRuntimeCommandCardError::InvalidCard(
            "resolved command path is empty".to_string(),
        ));
    }
    if card.product_build != ProductBuild::Pro
        || card.pro_status != ProStatus::ResearchCandidate
        || card.promotion_tier != SmallCompressedHarnessPromotionTier::T1L1Metadata
    {
        return Err(SmallCompressedLocalRuntimeCommandCardError::InvalidCard(
            "command card must remain T1/L1 Pro ResearchCandidate".to_string(),
        ));
    }
    if card.bytes.path_metadata_bytes_read == 0
        || card.bytes.path_metadata_bytes_read > MAX_CARD_METADATA_BYTES
        || card.bytes.opened_model_bytes != 0
        || card.bytes.opened_runtime_bytes != 0
        || card.bytes.resident_model_bytes != 0
        || card.bytes.resident_runtime_bytes != 0
        || card.bytes.model_bytes_loaded != 0
        || card.bytes.runtime_bytes_loaded != 0
        || card.bytes.provider_calls_made != 0
    {
        return Err(SmallCompressedLocalRuntimeCommandCardError::InvalidCard(
            "command card must be metadata-only with zero model/runtime/provider bytes".to_string(),
        ));
    }
    if !card
        .refs
        .upstream_owner_gate_ref
        .starts_with(UPSTREAM_OWNER_GATE_PREFIX)
        || !card.refs.model_path_ref.starts_with(MODEL_PATH_PREFIX)
        || !card
            .refs
            .command_ledger_ref
            .starts_with(COMMAND_LEDGER_PREFIX)
        || !card
            .refs
            .local_version_ref
            .starts_with(LOCAL_VERSION_PREFIX)
        || !card
            .refs
            .answer_packet_ref
            .starts_with(ANSWER_PACKET_PREFIX)
        || !card
            .refs
            .run_event_log_ref
            .starts_with(RUN_EVENT_LOG_PREFIX)
        || !card.refs.rollback_ref.starts_with(ROLLBACK_PREFIX)
        || !card.refs.cancellation_ref.starts_with(CANCELLATION_PREFIX)
        || !card
            .refs
            .memory_ledger_ref
            .starts_with(MEMORY_LEDGER_PREFIX)
        || !card
            .refs
            .compatibility_fence_ref
            .starts_with(COMPATIBILITY_FENCE_PREFIX)
        || !card
            .refs
            .denied_sidecar_ref
            .starts_with(DENIED_SIDE_CAR_PREFIX)
        || !card.refs.route_caveat_ref.starts_with(ROUTE_CAVEAT_PREFIX)
    {
        return Err(SmallCompressedLocalRuntimeCommandCardError::InvalidCard(
            "proof refs must use command-card prefixes".to_string(),
        ));
    }
    if card.user_visible_summary.len() < MIN_VISIBLE_SUMMARY_BYTES
        || !card.command_visible
        || !card.model_path_status_visible
        || !card.command_ledger_visible
        || !card.denied_sidecar_visible
    {
        return Err(SmallCompressedLocalRuntimeCommandCardError::InvalidCard(
            "command, model-path, ledger, and denied-sidecar visibility are required".to_string(),
        ));
    }
    if !card.owner_approval_required
        || card.owner_approval_granted
        || card.command_armed
        || card.command_executed
        || card.inference_executed
        || card.model_file_opened
        || card.first_token_claimed
        || card.retained_token_digest_recorded
    {
        return Err(SmallCompressedLocalRuntimeCommandCardError::InvalidCard(
            "owner approval must remain pending and runtime execution must remain blocked"
                .to_string(),
        ));
    }
    if !card.answer_packet_required
        || !card.run_event_log_required
        || !card.rollback_required
        || !card.cancellation_required
        || !card.memory_ledger_required
    {
        return Err(SmallCompressedLocalRuntimeCommandCardError::InvalidCard(
            "proof surfaces are required before any runtime probe".to_string(),
        ));
    }
    if card.quality_claimed
        || card.l2_capability_claimed
        || card.l3_wrv_claimed
        || card.mas_readiness_claimed
        || card.route_policy_mutated
        || card.hidden_cloud_fallback_allowed
        || card.hidden_route_authority_allowed
        || card.provider_fallback_allowed
        || card.server_sidecar_default_allowed
        || card.live_dense_70b_claimed
        || card.ssd_as_ram_claimed
    {
        return Err(SmallCompressedLocalRuntimeCommandCardError::InvalidCard(
            "product promotion, hidden authority, provider fallback, sidecar default, and 70B overclaim are forbidden".to_string(),
        ));
    }
    if card.command_role == SmallCompressedLocalRuntimeCommandRole::DeniedLlamaServerSidecar
        && !card.refs.denied_sidecar_ref.contains("llama-server")
    {
        return Err(SmallCompressedLocalRuntimeCommandCardError::InvalidCard(
            "server sidecar denial must be visible".to_string(),
        ));
    }
    Ok(())
}

fn command_card_set_preimage(
    upstream_owner_gate_set_address: &UasAddress,
    upstream_owner_gate_witness_ref: &str,
    selected_card_id: &str,
    cards: &[SmallCompressedModelLocalRuntimeCommandCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> String {
    let mut preimage = format!(
        "{}\n{}\n{}\n{}\n{:?}\n{}\n{}\n{}\n{}\n",
        upstream_owner_gate_set_address,
        upstream_owner_gate_witness_ref,
        selected_card_id,
        product_build_preimage(product_build),
        pro_status,
        metadata_bytes,
        l1_l2_l3_separated,
        runtime_deferred,
        product_promotion_blocked
    );
    for card in cards {
        let fields = [
            card.card_id.clone(),
            card.selected_candidate_id.clone(),
            card.model_id.clone(),
            format!("{:?}", card.command_role),
            card.command_path.clone(),
            card.resolved_path.clone(),
            card.command_path_present.to_string(),
            product_build_preimage(&card.product_build).to_string(),
            format!("{:?}", card.pro_status),
            format!("{:?}", card.promotion_tier),
            card.bytes.path_metadata_bytes_read.to_string(),
            card.bytes.opened_model_bytes.to_string(),
            card.bytes.opened_runtime_bytes.to_string(),
            card.bytes.resident_model_bytes.to_string(),
            card.bytes.resident_runtime_bytes.to_string(),
            card.bytes.model_bytes_loaded.to_string(),
            card.bytes.runtime_bytes_loaded.to_string(),
            card.bytes.provider_calls_made.to_string(),
            card.refs.upstream_owner_gate_ref.clone(),
            card.refs.model_path_ref.clone(),
            card.refs.command_ledger_ref.clone(),
            card.refs.local_version_ref.clone(),
            card.refs.answer_packet_ref.clone(),
            card.refs.run_event_log_ref.clone(),
            card.refs.rollback_ref.clone(),
            card.refs.cancellation_ref.clone(),
            card.refs.memory_ledger_ref.clone(),
            card.refs.compatibility_fence_ref.clone(),
            card.refs.denied_sidecar_ref.clone(),
            card.refs.route_caveat_ref.clone(),
            card.command_visible.to_string(),
            card.model_path_status_visible.to_string(),
            card.command_ledger_visible.to_string(),
            card.denied_sidecar_visible.to_string(),
            card.owner_approval_required.to_string(),
            card.owner_approval_granted.to_string(),
            card.command_armed.to_string(),
            card.command_executed.to_string(),
            card.inference_executed.to_string(),
            card.model_file_opened.to_string(),
            card.first_token_claimed.to_string(),
            card.retained_token_digest_recorded.to_string(),
            card.quality_claimed.to_string(),
            card.l2_capability_claimed.to_string(),
            card.l3_wrv_claimed.to_string(),
            card.mas_readiness_claimed.to_string(),
            card.answer_packet_required.to_string(),
            card.run_event_log_required.to_string(),
            card.rollback_required.to_string(),
            card.cancellation_required.to_string(),
            card.memory_ledger_required.to_string(),
            card.route_policy_mutated.to_string(),
            card.hidden_cloud_fallback_allowed.to_string(),
            card.hidden_route_authority_allowed.to_string(),
            card.provider_fallback_allowed.to_string(),
            card.server_sidecar_default_allowed.to_string(),
            card.live_dense_70b_claimed.to_string(),
            card.ssd_as_ram_claimed.to_string(),
            card.user_visible_summary.clone(),
        ];
        preimage.push_str(&fields.join("\n"));
        preimage.push('\n');
    }
    preimage
}

fn product_build_preimage(product_build: &ProductBuild) -> &'static str {
    match product_build {
        ProductBuild::Mas => "mas",
        ProductBuild::Pro => "pro",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_036_000_000;

    fn upstream_address() -> UasAddress {
        UasAddress::new(
            UasKind::Other("small_compressed_model_owner_approval_runtime_gate".to_string()),
            b"small-compressed-local-runtime-command-upstream",
            CREATED_AT_MS,
        )
    }

    fn refs(id: &str, denied: &str) -> SmallCompressedLocalRuntimeCommandRefs {
        SmallCompressedLocalRuntimeCommandRefs {
            upstream_owner_gate_ref:
                "artifact:small_compressed_model_owner_approval_runtime_gate:result".to_string(),
            model_path_ref: format!("model_path:pending_owner_approval:{id}"),
            command_ledger_ref: format!("command_ledger:small_compressed_local_runtime:{id}"),
            local_version_ref: "local_version:llama.cpp:9370:aa50b2c2a:darwin_arm64:no_model_load"
                .to_string(),
            answer_packet_ref: format!("answer_packet:small_compressed_local_runtime:{id}"),
            run_event_log_ref: format!("run_event_log:small_compressed_local_runtime:{id}"),
            rollback_ref: format!("rollback:small_compressed_local_runtime:{id}"),
            cancellation_ref: format!("cancel:small_compressed_local_runtime:{id}"),
            memory_ledger_ref: format!("memory_ledger:small_compressed_local_runtime:{id}"),
            compatibility_fence_ref: format!("compat:small_compressed_local_runtime:{id}"),
            denied_sidecar_ref: format!("denied_sidecar:{denied}:{id}"),
            route_caveat_ref: format!("route_caveat:small_compressed_local_runtime:{id}"),
        }
    }

    fn card(
        card_id: &str,
        role: SmallCompressedLocalRuntimeCommandRole,
        path: &str,
        denied: &str,
    ) -> SmallCompressedModelLocalRuntimeCommandCard {
        SmallCompressedModelLocalRuntimeCommandCard {
            card_id: card_id.to_string(),
            selected_candidate_id: SELECTED_E2B_CANDIDATE.to_string(),
            model_id: E2B_MODEL_ID.to_string(),
            command_role: role,
            command_path: path.to_string(),
            resolved_path: format!("../Cellar/llama.cpp/9370/bin/{}", path.rsplit('/').next().unwrap_or("llama-cli")),
            command_path_present: true,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: SmallCompressedHarnessPromotionTier::T1L1Metadata,
            bytes: SmallCompressedLocalRuntimeCommandByteLedger::metadata_only(4096),
            refs: refs(card_id, denied),
            user_visible_summary: "Local GGUF runtime command inventory is visible for the selected Gemma 4 E2B QAT GGUF candidate, but owner approval is pending, the model path remains pending, llama-server is denied by default, and no command, inference, model byte, provider route, L2, or L3 claim is armed.".to_string(),
            command_visible: true,
            model_path_status_visible: true,
            command_ledger_visible: true,
            denied_sidecar_visible: true,
            owner_approval_required: true,
            owner_approval_granted: false,
            command_armed: false,
            command_executed: false,
            inference_executed: false,
            model_file_opened: false,
            first_token_claimed: false,
            retained_token_digest_recorded: false,
            quality_claimed: false,
            l2_capability_claimed: false,
            l3_wrv_claimed: false,
            mas_readiness_claimed: false,
            answer_packet_required: true,
            run_event_log_required: true,
            rollback_required: true,
            cancellation_required: true,
            memory_ledger_required: true,
            route_policy_mutated: false,
            hidden_cloud_fallback_allowed: false,
            hidden_route_authority_allowed: false,
            provider_fallback_allowed: false,
            server_sidecar_default_allowed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
        }
    }

    fn cli_card() -> SmallCompressedModelLocalRuntimeCommandCard {
        card(
            "gemma4_e2b_qat_gguf_llama_cli_command_card",
            SmallCompressedLocalRuntimeCommandRole::DirectLlamaCli,
            LLAMA_CLI_PATH,
            "llama-server",
        )
    }

    fn server_card() -> SmallCompressedModelLocalRuntimeCommandCard {
        card(
            "gemma4_e2b_qat_gguf_llama_server_denied_sidecar_card",
            SmallCompressedLocalRuntimeCommandRole::DeniedLlamaServerSidecar,
            LLAMA_SERVER_PATH,
            "llama-server",
        )
    }

    fn card_set(
        cards: Vec<SmallCompressedModelLocalRuntimeCommandCard>,
    ) -> Result<
        SmallCompressedModelLocalRuntimeCommandCardSet,
        SmallCompressedLocalRuntimeCommandCardError,
    > {
        SmallCompressedModelLocalRuntimeCommandCardSet::from_owner_gate(
            upstream_address(),
            "artifact:small_compressed_model_owner_approval_runtime_gate:result",
            "gemma4_e2b_qat_gguf_llama_cli_command_card",
            cards,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            24_000,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
    }

    #[test]
    fn accepts_visible_cli_and_denied_server_cards_deterministically() {
        let first = card_set(vec![server_card(), cli_card()]).expect("cards should validate");
        let second = card_set(vec![cli_card(), server_card()]).expect("cards should validate");
        assert_eq!(first.set_address, second.set_address);
        assert_eq!(first.metrics().direct_cli_card_count, 1);
        assert_eq!(first.metrics().denied_server_sidecar_count, 1);
        assert_eq!(first.metrics().model_bytes_loaded, 0);
    }

    #[test]
    fn rejects_missing_command_or_bad_path() {
        let mut bad = cli_card();
        bad.command_path_present = false;
        assert!(card_set(vec![bad, server_card()]).is_err());

        let mut bad = cli_card();
        bad.command_path = "/usr/bin/false".to_string();
        assert!(card_set(vec![bad, server_card()]).is_err());
    }

    #[test]
    fn rejects_owner_approval_execution_and_token_claims() {
        let mut bad = cli_card();
        bad.owner_approval_granted = true;
        assert!(card_set(vec![bad, server_card()]).is_err());

        let mut bad = cli_card();
        bad.command_executed = true;
        assert!(card_set(vec![bad, server_card()]).is_err());

        let mut bad = cli_card();
        bad.first_token_claimed = true;
        assert!(card_set(vec![bad, server_card()]).is_err());
    }

    #[test]
    fn rejects_provider_fallback_sidecar_default_and_product_claims() {
        let mut bad = cli_card();
        bad.provider_fallback_allowed = true;
        assert!(card_set(vec![bad, server_card()]).is_err());

        let mut bad = server_card();
        bad.server_sidecar_default_allowed = true;
        assert!(card_set(vec![cli_card(), bad]).is_err());

        let mut bad = cli_card();
        bad.l2_capability_claimed = true;
        assert!(card_set(vec![bad, server_card()]).is_err());
    }

    #[test]
    fn rejects_loaded_bytes_and_missing_proof_refs() {
        let mut bad = cli_card();
        bad.bytes.model_bytes_loaded = 1;
        assert!(card_set(vec![bad, server_card()]).is_err());

        let mut bad = cli_card();
        bad.refs.answer_packet_ref = "missing".to_string();
        assert!(card_set(vec![bad, server_card()]).is_err());
    }
}
