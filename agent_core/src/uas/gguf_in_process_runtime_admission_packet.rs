//! GGUF in-process runtime admission packet.
//!
//! This primitive turns Pass 177 into a metadata-only admission witness for the
//! local GGUF / llama.cpp in-process lane. It binds source pins, local code
//! anchors, owner-path manifest policy, byte envelopes, digest policies,
//! cancellation, rollback, RunEventLog, AnswerPacket, and abstention without
//! opening model files, loading runtime bytes, starting a server, or arming a
//! command.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{ProStatus, ProductBuild, UasAddress, UasKind};

pub const GGUF_IN_PROCESS_RUNTIME_ADMISSION_PACKET_ID: &str =
    "F-GGUFInProcessRuntimeAdmissionPacket";
pub const GGUF_IN_PROCESS_RUNTIME_ADMISSION_PACKET_CURSOR: &str =
    "gguf_in_process_runtime_admission_packet";
pub const GGUF_IN_PROCESS_RUNTIME_ADMISSION_PACKET_NEXT_CURSOR: &str =
    "runtime_lane_admission_matrix_qat_litert_gguf_mlx";

const LLAMA_REPO: &str = "https://github.com/ggml-org/llama.cpp";
const LLAMA_RELEASE: &str = "b6871";
const LLAMA_COMMIT: &str = "9a3ea68";
const LLAMA_XCFRAMEWORK_URL: &str =
    "https://github.com/ggml-org/llama.cpp/releases/download/b6871/llama-b6871-xcframework.zip";
const LLAMA_XCFRAMEWORK_CHECKSUM: &str =
    "ac657d70112efadbf5cd1db5c4f67eea94ca38556ada9e7442d5a5a461010d6f";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const ABSTENTION_PREFIX: &str = "abstain:";
const OWNER_MANIFEST_PREFIX: &str = "owner_path_manifest:";
const SHA256_PREFIX: &str = "sha256:";
const MAX_PACKET_METADATA_BYTES: u64 = 160 * 1024;
const MAX_SET_METADATA_BYTES: u64 = 256 * 1024;

// UAS: uas:gguf-in-process-runtime-admission:manifest-status
// Plane: State + Verification.
// Residency: owner path policy only; no path bytes are read.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GgufOwnerPathManifestStatus {
    Absent,
    Pending,
    Approved,
}

// UAS: uas:gguf-in-process-runtime-admission:code-anchor
// Plane: Verification.
// Residency: source-path identity only; no source tree bytes are opened here.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GgufLocalCodeAnchor {
    LocalGgufClient,
    GgufSessionBridge,
    GgufRuntimeBridgePackage,
    LocalGgufClientTests,
    BackendRuntimeContract,
    RuntimeRouter,
    RuntimeExecutor,
    RuntimeLanesSection,
}

// UAS: uas:gguf-in-process-runtime-admission:proof-refs
// Plane: Verification.
// Residency: visible proof handles only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GgufAdmissionProofRefs {
    pub owner_path_manifest_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub focused_tests_ref: String,
}

// UAS: uas:gguf-in-process-runtime-admission:byte-envelope
// Plane: Verification.
// Residency: declared envelope only; selected bytes remain unopened.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GgufAdmissionByteEnvelope {
    pub selected_bytes_declared: u64,
    pub resident_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub model_files_opened: u64,
    pub cache_index_bytes_opened: u64,
    pub provider_calls_made: u64,
    pub command_armed_count: u64,
    pub server_start_count: u64,
    pub product_files_copied: u64,
}

impl GgufAdmissionByteEnvelope {
    pub fn metadata_only() -> Self {
        Self {
            selected_bytes_declared: 0,
            resident_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            model_files_opened: 0,
            cache_index_bytes_opened: 0,
            provider_calls_made: 0,
            command_armed_count: 0,
            server_start_count: 0,
            product_files_copied: 0,
        }
    }
}

// UAS: uas:gguf-in-process-runtime-admission:packet
// Plane: Assembly + Controller + Verification.
// Residency: unarmed lane admission metadata; no model/runtime bytes are read.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GgufInProcessRuntimeAdmissionPacket {
    pub packet_id: String,
    pub lane_id: String,
    pub runtime_kind: String,
    pub source_repo_url: String,
    pub llama_release_pin: String,
    pub llama_commit_ref: String,
    pub binary_target_url: String,
    pub binary_checksum: String,
    pub direct_distribution_review_required: bool,
    pub local_code_anchors: Vec<GgufLocalCodeAnchor>,
    pub owner_path_manifest_status: GgufOwnerPathManifestStatus,
    pub raw_owner_path_stored: bool,
    pub selected_model_path_policy: String,
    pub context_window_cap_tokens: u32,
    pub batch_cap_tokens: u32,
    pub thread_cap: u32,
    pub kv_budget_ref: String,
    pub app_headroom_ref: String,
    pub chat_template_digest_policy: String,
    pub tool_schema_digest_policy: String,
    pub cache_salt_policy: String,
    pub prompt_trim_policy_ref: String,
    pub backend_launch_contract_ref: String,
    pub sanitized_agent_event_ref: String,
    pub cancellation_ref: String,
    pub teardown_ref: String,
    pub proof_refs: GgufAdmissionProofRefs,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_bytes: u64,
    pub byte_envelope: GgufAdmissionByteEnvelope,
    pub metadata_only: bool,
    pub owner_approval_pending: bool,
    pub command_envelope_unarmed: bool,
    pub runtime_probe_deferred: bool,
    pub route_abstention_required: bool,
    pub mmap_mlock_gpu_fit_claim: bool,
    pub metal_support_fit_claim: bool,
    pub server_slot_cache_confused_with_in_process: bool,
    pub raw_prompt_logged: bool,
    pub raw_output_logged: bool,
    pub raw_token_logged: bool,
    pub hidden_route_authority: bool,
    pub mas_promoted: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:gguf-in-process-runtime-admission:set
// Plane: State + Verification.
// Residency: metadata-only packet set.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GgufInProcessRuntimeAdmissionPacketSet {
    pub set_address: UasAddress,
    pub packet: GgufInProcessRuntimeAdmissionPacket,
    pub metadata_bytes: u64,
    pub metadata_only: bool,
    pub no_model_files_opened: bool,
    pub no_runtime_bytes_loaded: bool,
    pub no_command_armed: bool,
    pub product_promotion_blocked: bool,
}

// UAS: uas:gguf-in-process-runtime-admission:metrics
// Plane: Verification.
// Residency: derived counters for falsifier axes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GgufInProcessRuntimeAdmissionMetrics {
    pub packet_count: u64,
    pub local_code_anchor_count: u64,
    pub selected_bytes_declared: u64,
    pub resident_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub model_files_opened: u64,
    pub cache_index_bytes_opened: u64,
    pub provider_calls_made: u64,
    pub command_armed_count: u64,
    pub server_start_count: u64,
    pub product_files_copied: u64,
    pub owner_approval_pending_count: u64,
    pub raw_owner_path_stored_count: u64,
    pub route_abstention_required_count: u64,
    pub mmap_mlock_gpu_fit_claim_count: u64,
    pub metal_support_fit_claim_count: u64,
    pub server_slot_cache_confusion_count: u64,
    pub raw_prompt_logged_count: u64,
    pub raw_output_logged_count: u64,
    pub raw_token_logged_count: u64,
    pub hidden_route_authority_count: u64,
    pub mas_promotion_count: u64,
    pub l2_green_claim_count: u64,
    pub l3_green_claim_count: u64,
    pub live_dense_70b_claim_count: u64,
    pub ssd_as_ram_claim_count: u64,
}

impl GgufInProcessRuntimeAdmissionPacketSet {
    pub fn new(
        mut packet: GgufInProcessRuntimeAdmissionPacket,
        metadata_bytes: u64,
        created_at_ms: u64,
    ) -> Result<Self, GgufInProcessRuntimeAdmissionError> {
        validate_packet(&packet)?;
        if metadata_bytes == 0 || metadata_bytes > MAX_SET_METADATA_BYTES {
            return Err(GgufInProcessRuntimeAdmissionError::MetadataBudget);
        }
        packet.local_code_anchors.sort();
        let preimage = set_preimage(&packet, metadata_bytes);
        Ok(Self {
            set_address: UasAddress::new(
                UasKind::Other(GGUF_IN_PROCESS_RUNTIME_ADMISSION_PACKET_CURSOR.to_string()),
                preimage.as_bytes(),
                created_at_ms,
            ),
            packet,
            metadata_bytes,
            metadata_only: true,
            no_model_files_opened: true,
            no_runtime_bytes_loaded: true,
            no_command_armed: true,
            product_promotion_blocked: true,
        })
    }

    pub fn metrics(&self) -> GgufInProcessRuntimeAdmissionMetrics {
        let packet = &self.packet;
        GgufInProcessRuntimeAdmissionMetrics {
            packet_count: 1,
            local_code_anchor_count: unique_anchor_count(&packet.local_code_anchors),
            selected_bytes_declared: packet.byte_envelope.selected_bytes_declared,
            resident_bytes_loaded: packet.byte_envelope.resident_bytes_loaded,
            runtime_bytes_loaded: packet.byte_envelope.runtime_bytes_loaded,
            model_files_opened: packet.byte_envelope.model_files_opened,
            cache_index_bytes_opened: packet.byte_envelope.cache_index_bytes_opened,
            provider_calls_made: packet.byte_envelope.provider_calls_made,
            command_armed_count: packet.byte_envelope.command_armed_count,
            server_start_count: packet.byte_envelope.server_start_count,
            product_files_copied: packet.byte_envelope.product_files_copied,
            owner_approval_pending_count: u64::from(packet.owner_approval_pending),
            raw_owner_path_stored_count: u64::from(packet.raw_owner_path_stored),
            route_abstention_required_count: u64::from(packet.route_abstention_required),
            mmap_mlock_gpu_fit_claim_count: u64::from(packet.mmap_mlock_gpu_fit_claim),
            metal_support_fit_claim_count: u64::from(packet.metal_support_fit_claim),
            server_slot_cache_confusion_count: u64::from(
                packet.server_slot_cache_confused_with_in_process,
            ),
            raw_prompt_logged_count: u64::from(packet.raw_prompt_logged),
            raw_output_logged_count: u64::from(packet.raw_output_logged),
            raw_token_logged_count: u64::from(packet.raw_token_logged),
            hidden_route_authority_count: u64::from(packet.hidden_route_authority),
            mas_promotion_count: u64::from(packet.mas_promoted),
            l2_green_claim_count: u64::from(packet.l2_green_claimed),
            l3_green_claim_count: u64::from(packet.l3_green_claimed),
            live_dense_70b_claim_count: u64::from(packet.live_dense_70b_claimed),
            ssd_as_ram_claim_count: u64::from(packet.ssd_as_ram_claimed),
        }
    }
}

pub fn canonical_gguf_in_process_runtime_admission_packet() -> GgufInProcessRuntimeAdmissionPacket {
    GgufInProcessRuntimeAdmissionPacket {
        packet_id: GGUF_IN_PROCESS_RUNTIME_ADMISSION_PACKET_CURSOR.to_string(),
        lane_id: "gguf_in_process".to_string(),
        runtime_kind: "gguf".to_string(),
        source_repo_url: LLAMA_REPO.to_string(),
        llama_release_pin: LLAMA_RELEASE.to_string(),
        llama_commit_ref: LLAMA_COMMIT.to_string(),
        binary_target_url: LLAMA_XCFRAMEWORK_URL.to_string(),
        binary_checksum: LLAMA_XCFRAMEWORK_CHECKSUM.to_string(),
        direct_distribution_review_required: true,
        local_code_anchors: vec![
            GgufLocalCodeAnchor::LocalGgufClient,
            GgufLocalCodeAnchor::GgufSessionBridge,
            GgufLocalCodeAnchor::GgufRuntimeBridgePackage,
            GgufLocalCodeAnchor::LocalGgufClientTests,
            GgufLocalCodeAnchor::BackendRuntimeContract,
            GgufLocalCodeAnchor::RuntimeRouter,
            GgufLocalCodeAnchor::RuntimeExecutor,
            GgufLocalCodeAnchor::RuntimeLanesSection,
        ],
        owner_path_manifest_status: GgufOwnerPathManifestStatus::Pending,
        raw_owner_path_stored: false,
        selected_model_path_policy: "policy:canonical-owner-manifest-no-raw-path-no-file-open"
            .to_string(),
        context_window_cap_tokens: 16_384,
        batch_cap_tokens: 512,
        thread_cap: 8,
        kv_budget_ref: "kv_budget:pending:gguf-in-process".to_string(),
        app_headroom_ref: "app_headroom:pending:gguf-in-process".to_string(),
        chat_template_digest_policy: "sha256:chat-template-policy-gguf-admission".to_string(),
        tool_schema_digest_policy: "sha256:tool-schema-policy-gguf-soft-guidance".to_string(),
        cache_salt_policy: "sha256:cache-salt-policy-gguf-admission".to_string(),
        prompt_trim_policy_ref: "prompt_trim:LocalMLXClient.trimForLocalRuntime".to_string(),
        backend_launch_contract_ref: "backend_contract:BackendRuntimeControlPlane.generate"
            .to_string(),
        sanitized_agent_event_ref: "agent_event:LocalGGUFClientTests.sanitized".to_string(),
        cancellation_ref: "cancel:LocalGGUFClient.stream+GGUFSessionBridge.task".to_string(),
        teardown_ref: "teardown:GGUFSessionBridge.SessionResources.deinit".to_string(),
        proof_refs: GgufAdmissionProofRefs {
            owner_path_manifest_ref: "owner_path_manifest:pending:gguf-in-process".to_string(),
            rollback_ref: "rollback:gguf-in-process-runtime-admission".to_string(),
            run_event_log_ref: "run_event_log:gguf-in-process-runtime-admission".to_string(),
            answer_packet_ref: "answer_packet:gguf-in-process-runtime-admission".to_string(),
            abstention_ref: "abstain:gguf-in-process-runtime-admission:metadata-only".to_string(),
            focused_tests_ref: "focused_tests:EpistemosTests/LocalGGUFClientTests.swift"
                .to_string(),
        },
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        metadata_bytes: 72_000,
        byte_envelope: GgufAdmissionByteEnvelope::metadata_only(),
        metadata_only: true,
        owner_approval_pending: true,
        command_envelope_unarmed: true,
        runtime_probe_deferred: true,
        route_abstention_required: true,
        mmap_mlock_gpu_fit_claim: false,
        metal_support_fit_claim: false,
        server_slot_cache_confused_with_in_process: false,
        raw_prompt_logged: false,
        raw_output_logged: false,
        raw_token_logged: false,
        hidden_route_authority: false,
        mas_promoted: false,
        l2_green_claimed: false,
        l3_green_claimed: false,
        live_dense_70b_claimed: false,
        ssd_as_ram_claimed: false,
    }
}

// UAS: uas:gguf-in-process-runtime-admission:error
// Plane: Verification.
// Residency: validation failure only; no runtime side effects.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GgufInProcessRuntimeAdmissionError {
    MetadataBudget,
    InvalidPacket(String),
    UnsafeClaim(String),
}

impl fmt::Display for GgufInProcessRuntimeAdmissionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MetadataBudget => write!(f, "GGUF admission metadata budget invalid"),
            Self::InvalidPacket(reason) => write!(f, "invalid GGUF admission packet: {reason}"),
            Self::UnsafeClaim(reason) => write!(f, "unsafe GGUF admission claim: {reason}"),
        }
    }
}

impl std::error::Error for GgufInProcessRuntimeAdmissionError {}

fn validate_packet(
    packet: &GgufInProcessRuntimeAdmissionPacket,
) -> Result<(), GgufInProcessRuntimeAdmissionError> {
    if !is_clean_id(&packet.packet_id) || packet.metadata_bytes == 0 {
        return Err(GgufInProcessRuntimeAdmissionError::InvalidPacket(
            "packet id or metadata bytes invalid".to_string(),
        ));
    }
    if packet.metadata_bytes > MAX_PACKET_METADATA_BYTES {
        return Err(GgufInProcessRuntimeAdmissionError::InvalidPacket(
            "packet metadata budget exceeded".to_string(),
        ));
    }
    if packet.lane_id != "gguf_in_process" || packet.runtime_kind != "gguf" {
        return Err(GgufInProcessRuntimeAdmissionError::InvalidPacket(
            "lane or runtime kind invalid".to_string(),
        ));
    }
    if packet.source_repo_url != LLAMA_REPO
        || packet.llama_release_pin != LLAMA_RELEASE
        || packet.llama_commit_ref != LLAMA_COMMIT
        || packet.binary_target_url != LLAMA_XCFRAMEWORK_URL
        || packet.binary_checksum != LLAMA_XCFRAMEWORK_CHECKSUM
    {
        return Err(GgufInProcessRuntimeAdmissionError::InvalidPacket(
            "llama.cpp source pin or binary checksum invalid".to_string(),
        ));
    }
    if !packet.direct_distribution_review_required {
        return Err(GgufInProcessRuntimeAdmissionError::UnsafeClaim(
            "direct distribution review must be required".to_string(),
        ));
    }
    if unique_anchor_count(&packet.local_code_anchors) != 8 {
        return Err(GgufInProcessRuntimeAdmissionError::InvalidPacket(
            "all local code anchors are required".to_string(),
        ));
    }
    if packet.owner_path_manifest_status != GgufOwnerPathManifestStatus::Pending
        && packet.owner_path_manifest_status != GgufOwnerPathManifestStatus::Absent
    {
        return Err(GgufInProcessRuntimeAdmissionError::UnsafeClaim(
            "metadata admission cannot mark owner manifest approved".to_string(),
        ));
    }
    if packet.raw_owner_path_stored
        || !packet
            .selected_model_path_policy
            .starts_with("policy:canonical-owner-manifest")
    {
        return Err(GgufInProcessRuntimeAdmissionError::UnsafeClaim(
            "raw owner path storage or unsafe path policy".to_string(),
        ));
    }
    if packet.context_window_cap_tokens == 0
        || packet.context_window_cap_tokens > 16_384
        || packet.batch_cap_tokens == 0
        || packet.batch_cap_tokens > 512
        || packet.thread_cap == 0
        || packet.thread_cap > 8
    {
        return Err(GgufInProcessRuntimeAdmissionError::InvalidPacket(
            "context, batch, or thread caps invalid".to_string(),
        ));
    }
    if !starts_with_prefix(&packet.kv_budget_ref, "kv_budget:")
        || !starts_with_prefix(&packet.app_headroom_ref, "app_headroom:")
        || !starts_sha(&packet.chat_template_digest_policy)
        || !starts_sha(&packet.tool_schema_digest_policy)
        || !starts_sha(&packet.cache_salt_policy)
        || !starts_with_prefix(&packet.prompt_trim_policy_ref, "prompt_trim:")
        || !starts_with_prefix(&packet.backend_launch_contract_ref, "backend_contract:")
        || !starts_with_prefix(&packet.sanitized_agent_event_ref, "agent_event:")
        || !starts_with_prefix(&packet.cancellation_ref, "cancel:")
        || !starts_with_prefix(&packet.teardown_ref, "teardown:")
    {
        return Err(GgufInProcessRuntimeAdmissionError::InvalidPacket(
            "policy or lifecycle refs invalid".to_string(),
        ));
    }
    if !packet
        .proof_refs
        .owner_path_manifest_ref
        .starts_with(OWNER_MANIFEST_PREFIX)
        || !packet.proof_refs.rollback_ref.starts_with(ROLLBACK_PREFIX)
        || !packet
            .proof_refs
            .run_event_log_ref
            .starts_with(RUN_EVENT_LOG_PREFIX)
        || !packet
            .proof_refs
            .answer_packet_ref
            .starts_with(ANSWER_PACKET_PREFIX)
        || !packet
            .proof_refs
            .abstention_ref
            .starts_with(ABSTENTION_PREFIX)
        || !packet
            .proof_refs
            .focused_tests_ref
            .starts_with("focused_tests:")
    {
        return Err(GgufInProcessRuntimeAdmissionError::InvalidPacket(
            "proof refs invalid".to_string(),
        ));
    }
    if packet.product_build != ProductBuild::Pro
        || packet.pro_status != ProStatus::ResearchCandidate
    {
        return Err(GgufInProcessRuntimeAdmissionError::UnsafeClaim(
            "GGUF admission must remain Pro ResearchCandidate".to_string(),
        ));
    }
    if !packet.metadata_only
        || !packet.owner_approval_pending
        || !packet.command_envelope_unarmed
        || !packet.runtime_probe_deferred
        || !packet.route_abstention_required
    {
        return Err(GgufInProcessRuntimeAdmissionError::UnsafeClaim(
            "metadata-only owner-pending unarmed deferred abstention required".to_string(),
        ));
    }
    if packet.byte_envelope.selected_bytes_declared != 0
        || packet.byte_envelope.resident_bytes_loaded != 0
        || packet.byte_envelope.runtime_bytes_loaded != 0
        || packet.byte_envelope.model_files_opened != 0
        || packet.byte_envelope.cache_index_bytes_opened != 0
        || packet.byte_envelope.provider_calls_made != 0
        || packet.byte_envelope.command_armed_count != 0
        || packet.byte_envelope.server_start_count != 0
        || packet.byte_envelope.product_files_copied != 0
    {
        return Err(GgufInProcessRuntimeAdmissionError::UnsafeClaim(
            "metadata admission cannot select/open/load/copy bytes or arm commands".to_string(),
        ));
    }
    for (flag, reason) in [
        (
            packet.mmap_mlock_gpu_fit_claim,
            "mmap/mlock/GPU as fit proof",
        ),
        (packet.metal_support_fit_claim, "Metal support as fit proof"),
        (
            packet.server_slot_cache_confused_with_in_process,
            "server slot cache confused with in-process lane",
        ),
        (packet.raw_prompt_logged, "raw prompt logging"),
        (packet.raw_output_logged, "raw output logging"),
        (packet.raw_token_logged, "raw token logging"),
        (packet.hidden_route_authority, "hidden route authority"),
        (packet.mas_promoted, "MAS promotion"),
        (packet.l2_green_claimed, "L2 promotion"),
        (packet.l3_green_claimed, "L3 promotion"),
        (packet.live_dense_70b_claimed, "live dense 70B claim"),
        (packet.ssd_as_ram_claimed, "SSD-as-RAM claim"),
    ] {
        if flag {
            return Err(GgufInProcessRuntimeAdmissionError::UnsafeClaim(
                reason.to_string(),
            ));
        }
    }
    Ok(())
}

fn unique_anchor_count(anchors: &[GgufLocalCodeAnchor]) -> u64 {
    anchors.iter().copied().collect::<BTreeSet<_>>().len() as u64
}

fn set_preimage(packet: &GgufInProcessRuntimeAdmissionPacket, metadata_bytes: u64) -> String {
    format!(
        "{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
        GGUF_IN_PROCESS_RUNTIME_ADMISSION_PACKET_ID,
        packet.lane_id,
        packet.llama_release_pin,
        packet.llama_commit_ref,
        packet.binary_checksum,
        packet.selected_model_path_policy,
        packet.chat_template_digest_policy,
        packet.tool_schema_digest_policy,
        packet.proof_refs.rollback_ref,
        metadata_bytes
    )
}

fn starts_sha(value: &str) -> bool {
    value.starts_with(SHA256_PREFIX) && value.len() > SHA256_PREFIX.len()
}

fn starts_with_prefix(value: &str, prefix: &str) -> bool {
    value.starts_with(prefix) && value.len() > prefix.len()
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
        packet: GgufInProcessRuntimeAdmissionPacket,
    ) -> Result<GgufInProcessRuntimeAdmissionPacketSet, GgufInProcessRuntimeAdmissionError> {
        GgufInProcessRuntimeAdmissionPacketSet::new(packet, 128_000, CREATED_AT_MS)
    }

    #[test]
    fn canonical_packet_passes_and_is_deterministic() {
        let packet = canonical_gguf_in_process_runtime_admission_packet();
        let first = build(packet.clone()).expect("canonical GGUF admission packet should pass");
        let mut shuffled = packet;
        shuffled.local_code_anchors.reverse();
        let second = build(shuffled).expect("shuffled canonical packet should pass");
        assert_eq!(first.set_address, second.set_address);
        let metrics = first.metrics();
        assert_eq!(metrics.local_code_anchor_count, 8);
        assert_eq!(metrics.model_files_opened, 0);
        assert_eq!(metrics.runtime_bytes_loaded, 0);
        assert_eq!(metrics.owner_approval_pending_count, 1);
    }

    #[test]
    fn rejects_owner_manifest_smuggling_and_raw_path_storage() {
        let mut approved = canonical_gguf_in_process_runtime_admission_packet();
        approved.owner_path_manifest_status = GgufOwnerPathManifestStatus::Approved;
        assert!(build(approved).is_err());

        let mut raw_path = canonical_gguf_in_process_runtime_admission_packet();
        raw_path.raw_owner_path_stored = true;
        assert!(build(raw_path).is_err());
    }

    #[test]
    fn rejects_byte_or_command_activation() {
        let mut bytes = canonical_gguf_in_process_runtime_admission_packet();
        bytes.byte_envelope.model_files_opened = 1;
        assert!(build(bytes).is_err());

        let mut command = canonical_gguf_in_process_runtime_admission_packet();
        command.command_envelope_unarmed = false;
        assert!(build(command).is_err());
    }

    #[test]
    fn rejects_fit_laundering_and_route_promotion() {
        let mut fit = canonical_gguf_in_process_runtime_admission_packet();
        fit.metal_support_fit_claim = true;
        assert!(build(fit).is_err());

        let mut l2 = canonical_gguf_in_process_runtime_admission_packet();
        l2.l2_green_claimed = true;
        assert!(build(l2).is_err());
    }
}
