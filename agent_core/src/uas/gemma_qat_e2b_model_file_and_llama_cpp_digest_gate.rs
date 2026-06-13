//! Gemma QAT E2B model-file and llama.cpp digest gate.
//!
//! This primitive binds the digest requirements for the first future
//! owner-approved Gemma E2B GGUF/llama.cpp probe. It still does not read an
//! owner path manifest, hash a local model file, inspect a local llama.cpp
//! binary, arm a command, run inference, or promote Gemma into System G.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    GemmaFamilyRuntimeLane, ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_QAT_E2B_EXPECTED_FILE_BYTES, GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_ID,
    GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_UPSTREAM_REF, GEMMA_QAT_E2B_SOURCE_REVISION,
    GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH, GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME,
    GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID,
};

pub const GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_ID: &str =
    "F-GemmaQATE2BModelFileAndLlamaCppDigestGate";
pub const GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_CURSOR: &str =
    "gemma_qat_e2b_model_file_and_llama_cpp_digest_gate";
pub const GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_NEXT_CURSOR: &str =
    "gemma_qat_e2b_owner_approved_first_token_runtime_probe";
pub const GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_UPSTREAM_REF: &str = "artifact:falsifiers/gemma_qat_e2b_owner_path_manifest_digest_gate/result.json#F-GemmaQATE2BOwnerPathManifestDigestGate";

const UPSTREAM_OWNER_MANIFEST_PREFIX: &str =
    "artifact:falsifiers/gemma_qat_e2b_owner_path_manifest_digest_gate/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_qat_e2b_model_file_and_llama_cpp_digest_gate/";
const DIGEST_CARD_ID: &str = "gemma-e2b-gguf-model-file-llama-cpp-digest-contract";
const MAX_METADATA_BYTES: u64 = 224 * 1024;

const REQUIRED_DIGEST_FIELDS: &[&str] = &[
    "owner_manifest_digest",
    "canonical_path_digest",
    "model_id",
    "source_revision",
    "required_filename",
    "expected_file_size_bytes",
    "model_file_sha256",
    "model_file_size_bytes",
    "model_file_xet_pointer_digest",
    "llama_cpp_binary_path_digest",
    "llama_cpp_binary_sha256",
    "llama_cpp_version_digest",
    "llama_cpp_build_config_digest",
    "command_template_digest",
    "required_command_args_digest",
    "forbidden_command_args_digest",
    "offline_mode_digest",
    "privacy_redaction_policy_digest",
    "memory_probe_plan_digest",
    "timeout_cancel_digest",
    "rollback_digest",
    "run_event_log_digest",
    "answer_packet_digest",
    "abstention_digest",
];

const REQUIRED_REJECTION_POLICIES: &[&str] = &[
    "missing_upstream_owner_manifest_digest_gate",
    "owner_approval_laundered",
    "raw_path_retained",
    "canonical_path_retained",
    "path_canonicalization_attempted",
    "file_stat_attempted",
    "file_hash_attempted",
    "model_file_opened",
    "model_digest_claimed_from_remote_listing",
    "llama_cpp_binary_opened",
    "llama_cpp_version_executed",
    "command_template_hidden",
    "command_armed",
    "command_executed",
    "hf_download_enabled",
    "server_mode_enabled",
    "mmap_stress_enabled",
    "provider_route_enabled",
    "wrong_model_id",
    "wrong_filename",
    "wrong_expected_file_bytes",
    "wrong_source_revision",
    "wrong_runtime_lane",
    "missing_model_digest_requirement",
    "missing_llama_cpp_digest_requirement",
    "missing_version_digest_requirement",
    "missing_command_template_digest_requirement",
    "missing_memory_probe_plan",
    "runtime_router_mutation",
    "system_g_mutation",
    "hidden_route_authority",
    "hidden_eidos_authority",
    "hidden_lattice_authority",
    "hidden_patternboost_authority",
    "hidden_cloud_fallback",
    "mas_l2_l3_promotion",
    "gemma_default_promotion",
    "e4b_or_12b_bypass",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
];

const REQUIRED_COMMAND_ARGS: &[&str] = &[
    "/opt/homebrew/bin/llama-cli",
    "model:<OWNER_APPROVED_E2B_GGUF_PATH>",
    "prompt:<SYNTHETIC_NON_USER_PROMPT>",
    "predict:1",
    "ctx-size:512",
    "batch-size:32",
    "ubatch-size:32",
    "temp:0",
    "seed:0",
    "--no-conversation",
    "--single-turn",
    "--simple-io",
    "--no-display-prompt",
    "--log-disable",
];

const FORBIDDEN_COMMAND_ARGS: &[&str] = &[
    "--hf-repo",
    "--hf-file",
    "--model-url",
    "--hf-token",
    "--server",
    "--host",
    "--port",
    "--conversation",
    "--mmap",
    "--ctx-size 8192",
    "--predict -1",
];

// UAS: uas:gemma-qat-e2b-model-file-llama-cpp-digest-gate:status
// Plane: Verification.
// Residency: digest requirement only; no model/runtime bytes are read.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatE2bModelFileAndLlamaCppDigestGateStatus {
    DigestRequirementsOnly,
}

// UAS: uas:gemma-qat-e2b-model-file-llama-cpp-digest-gate:spec
// Plane: State + Controller + Verification.
// Residency: future owner-approved model/runtime digest contract.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatE2bModelFileAndLlamaCppDigestGate {
    pub upstream_owner_manifest_digest_gate_ref: String,
    pub upstream_gate_id: String,
    pub upstream_first_token_review_ref: String,
    pub artifact_root_prefix: String,
    pub digest_card_id: String,
    pub selected_model_id: String,
    pub source_revision: String,
    pub required_filename: String,
    pub expected_file_size_bytes: u64,
    pub runtime_lane: GemmaFamilyRuntimeLane,
    pub command_path: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub owner_manifest_digest_bound: bool,
    pub canonical_path_digest_bound: bool,
    pub model_file_digest_required: bool,
    pub model_file_digest_present: bool,
    pub model_file_size_bound: bool,
    pub llama_cpp_binary_digest_required: bool,
    pub llama_cpp_binary_digest_present: bool,
    pub llama_cpp_version_digest_required: bool,
    pub llama_cpp_version_digest_present: bool,
    pub command_template_digest_required: bool,
    pub command_template_visible: bool,
    pub offline_mode_required: bool,
    pub required_command_args: Vec<String>,
    pub forbidden_command_args: Vec<String>,
    pub memory_probe_plan_required: bool,
    pub timeout_cancel_required: bool,
    pub raw_path_bytes_stored: u64,
    pub canonical_path_bytes_stored: u64,
    pub path_canonicalization_attempts: u64,
    pub file_stat_attempts: u64,
    pub file_hash_attempts: u64,
    pub model_file_opened: bool,
    pub llama_cpp_binary_opened: bool,
    pub llama_cpp_version_executions: u64,
    pub command_armed: bool,
    pub command_executed: bool,
    pub hf_download_enabled: bool,
    pub server_mode_enabled: bool,
    pub mmap_stress_enabled: bool,
    pub provider_route_enabled: bool,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub required_digest_fields: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub route_mutation_allowed: bool,
    pub system_g_mutation_allowed: bool,
    pub hidden_route_authority: bool,
    pub hidden_eidos_authority: bool,
    pub hidden_lattice_authority: bool,
    pub hidden_patternboost_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub mas_promoted: bool,
    pub l2_capability_effect: bool,
    pub l3_wrv_effect: bool,
    pub product_route_green: bool,
    pub live_gemma_default_claim: bool,
    pub e4b_or_12b_bypass_allowed: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub rollback_bound: bool,
    pub run_event_log_bound: bool,
    pub answer_packet_bound: bool,
    pub abstention_bound: bool,
    pub metadata_bytes: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub status: GemmaQatE2bModelFileAndLlamaCppDigestGateStatus,
    pub next_cursor: String,
}

impl GemmaQatE2bModelFileAndLlamaCppDigestGate {
    pub fn canonical(upstream_owner_manifest_digest_gate_ref: impl Into<String>) -> Self {
        Self {
            upstream_owner_manifest_digest_gate_ref: upstream_owner_manifest_digest_gate_ref.into(),
            upstream_gate_id: GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_ID.to_string(),
            upstream_first_token_review_ref:
                GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_UPSTREAM_REF.to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            digest_card_id: DIGEST_CARD_ID.to_string(),
            selected_model_id: GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID.to_string(),
            source_revision: GEMMA_QAT_E2B_SOURCE_REVISION.to_string(),
            required_filename: GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME.to_string(),
            expected_file_size_bytes: GEMMA_QAT_E2B_EXPECTED_FILE_BYTES,
            runtime_lane: GemmaFamilyRuntimeLane::GgufLlamaCpp,
            command_path: GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            owner_approval_required: true,
            owner_approval_granted: false,
            owner_manifest_digest_bound: true,
            canonical_path_digest_bound: true,
            model_file_digest_required: true,
            model_file_digest_present: false,
            model_file_size_bound: true,
            llama_cpp_binary_digest_required: true,
            llama_cpp_binary_digest_present: false,
            llama_cpp_version_digest_required: true,
            llama_cpp_version_digest_present: false,
            command_template_digest_required: true,
            command_template_visible: true,
            offline_mode_required: true,
            required_command_args: REQUIRED_COMMAND_ARGS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            forbidden_command_args: FORBIDDEN_COMMAND_ARGS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            memory_probe_plan_required: true,
            timeout_cancel_required: true,
            raw_path_bytes_stored: 0,
            canonical_path_bytes_stored: 0,
            path_canonicalization_attempts: 0,
            file_stat_attempts: 0,
            file_hash_attempts: 0,
            model_file_opened: false,
            llama_cpp_binary_opened: false,
            llama_cpp_version_executions: 0,
            command_armed: false,
            command_executed: false,
            hf_download_enabled: false,
            server_mode_enabled: false,
            mmap_stress_enabled: false,
            provider_route_enabled: false,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            required_digest_fields: REQUIRED_DIGEST_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_rejection_policies: REQUIRED_REJECTION_POLICIES
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            route_mutation_allowed: false,
            system_g_mutation_allowed: false,
            hidden_route_authority: false,
            hidden_eidos_authority: false,
            hidden_lattice_authority: false,
            hidden_patternboost_authority: false,
            hidden_cloud_fallback: false,
            mas_promoted: false,
            l2_capability_effect: false,
            l3_wrv_effect: false,
            product_route_green: false,
            live_gemma_default_claim: false,
            e4b_or_12b_bypass_allowed: false,
            live_dense_70b_claim: false,
            ssd_as_ram_claim: false,
            rollback_bound: true,
            run_event_log_bound: true,
            answer_packet_bound: true,
            abstention_bound: true,
            metadata_bytes: 112_000,
            rollback_ref: "rollback:gemma_qat_e2b_model_file_and_llama_cpp_digest_gate".to_string(),
            run_event_log_ref: "run_event_log:gemma_qat_e2b_model_file_and_llama_cpp_digest_gate"
                .to_string(),
            answer_packet_ref: "answer_packet:gemma_qat_e2b_model_file_and_llama_cpp_digest_gate"
                .to_string(),
            abstention_ref: "abstention:gemma_qat_e2b_model_file_and_llama_cpp_digest_gate"
                .to_string(),
            status: GemmaQatE2bModelFileAndLlamaCppDigestGateStatus::DigestRequirementsOnly,
            next_cursor: GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_NEXT_CURSOR.to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaQatE2bModelFileAndLlamaCppDigestGateError> {
        if !self
            .upstream_owner_manifest_digest_gate_ref
            .starts_with(UPSTREAM_OWNER_MANIFEST_PREFIX)
            || self.upstream_gate_id != GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_ID
        {
            return Err(GemmaQatE2bModelFileAndLlamaCppDigestGateError::BadUpstreamRef);
        }
        validate_exact(
            "upstream_first_token_review_ref",
            &self.upstream_first_token_review_ref,
            GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_UPSTREAM_REF,
        )?;
        validate_prefix(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact("digest_card_id", &self.digest_card_id, DIGEST_CARD_ID)?;
        validate_unique_exact_set(
            "required_digest_fields",
            &self.required_digest_fields,
            REQUIRED_DIGEST_FIELDS,
        )?;
        validate_unique_exact_set(
            "required_rejection_policies",
            &self.required_rejection_policies,
            REQUIRED_REJECTION_POLICIES,
        )?;
        validate_unique_exact_set(
            "required_command_args",
            &self.required_command_args,
            REQUIRED_COMMAND_ARGS,
        )?;
        validate_unique_exact_set(
            "forbidden_command_args",
            &self.forbidden_command_args,
            FORBIDDEN_COMMAND_ARGS,
        )?;
        if self.selected_model_id != GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID
            || self.source_revision != GEMMA_QAT_E2B_SOURCE_REVISION
            || self.required_filename != GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME
            || self.expected_file_size_bytes != GEMMA_QAT_E2B_EXPECTED_FILE_BYTES
            || self.runtime_lane != GemmaFamilyRuntimeLane::GgufLlamaCpp
            || self.command_path != GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH
        {
            return Err(GemmaQatE2bModelFileAndLlamaCppDigestGateError::BadSelectedLane);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status
                != GemmaQatE2bModelFileAndLlamaCppDigestGateStatus::DigestRequirementsOnly
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(GemmaQatE2bModelFileAndLlamaCppDigestGateError::UnsafeState);
        }
        if !self.owner_approval_required
            || self.owner_approval_granted
            || !self.owner_manifest_digest_bound
            || !self.canonical_path_digest_bound
            || !self.model_file_digest_required
            || self.model_file_digest_present
            || !self.model_file_size_bound
            || !self.llama_cpp_binary_digest_required
            || self.llama_cpp_binary_digest_present
            || !self.llama_cpp_version_digest_required
            || self.llama_cpp_version_digest_present
            || !self.command_template_digest_required
            || !self.command_template_visible
            || !self.offline_mode_required
            || !self.memory_probe_plan_required
            || !self.timeout_cancel_required
        {
            return Err(GemmaQatE2bModelFileAndLlamaCppDigestGateError::DigestBoundaryBroken);
        }
        if self.raw_path_bytes_stored != 0
            || self.canonical_path_bytes_stored != 0
            || self.path_canonicalization_attempts != 0
            || self.file_stat_attempts != 0
            || self.file_hash_attempts != 0
            || self.model_file_opened
            || self.llama_cpp_binary_opened
            || self.llama_cpp_version_executions != 0
        {
            return Err(GemmaQatE2bModelFileAndLlamaCppDigestGateError::PathOrFileLeak);
        }
        if self.command_armed
            || self.command_executed
            || self.hf_download_enabled
            || self.server_mode_enabled
            || self.mmap_stress_enabled
            || self.provider_route_enabled
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaQatE2bModelFileAndLlamaCppDigestGateError::ExecutionLeak);
        }
        if self.route_mutation_allowed
            || self.system_g_mutation_allowed
            || self.hidden_route_authority
            || self.hidden_eidos_authority
            || self.hidden_lattice_authority
            || self.hidden_patternboost_authority
            || self.hidden_cloud_fallback
            || self.mas_promoted
            || self.l2_capability_effect
            || self.l3_wrv_effect
            || self.product_route_green
            || self.live_gemma_default_claim
            || self.e4b_or_12b_bypass_allowed
            || self.live_dense_70b_claim
            || self.ssd_as_ram_claim
        {
            return Err(GemmaQatE2bModelFileAndLlamaCppDigestGateError::PromotionClaim);
        }
        if !self.rollback_bound
            || !self.run_event_log_bound
            || !self.answer_packet_bound
            || !self.abstention_bound
        {
            return Err(GemmaQatE2bModelFileAndLlamaCppDigestGateError::ProofBoundaryBroken);
        }
        validate_prefix("rollback_ref", &self.rollback_ref, "rollback:")?;
        validate_prefix(
            "run_event_log_ref",
            &self.run_event_log_ref,
            "run_event_log:",
        )?;
        validate_prefix(
            "answer_packet_ref",
            &self.answer_packet_ref,
            "answer_packet:",
        )?;
        validate_prefix("abstention_ref", &self.abstention_ref, "abstention:")?;
        validate_exact(
            "next_cursor",
            &self.next_cursor,
            GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaQatE2bModelFileAndLlamaCppDigestGateMetrics {
        GemmaQatE2bModelFileAndLlamaCppDigestGateMetrics {
            required_digest_field_count: self.required_digest_fields.len() as u64,
            required_rejection_policy_count: self.required_rejection_policies.len() as u64,
            required_command_arg_count: self.required_command_args.len() as u64,
            forbidden_command_arg_count: self.forbidden_command_args.len() as u64,
            owner_approval_granted_count: self.owner_approval_granted as u64,
            model_file_digest_present_count: self.model_file_digest_present as u64,
            llama_cpp_binary_digest_present_count: self.llama_cpp_binary_digest_present as u64,
            llama_cpp_version_digest_present_count: self.llama_cpp_version_digest_present as u64,
            raw_path_bytes_stored: self.raw_path_bytes_stored,
            canonical_path_bytes_stored: self.canonical_path_bytes_stored,
            path_canonicalization_attempts: self.path_canonicalization_attempts,
            file_stat_attempts: self.file_stat_attempts,
            file_hash_attempts: self.file_hash_attempts,
            model_file_opened_count: self.model_file_opened as u64,
            llama_cpp_binary_opened_count: self.llama_cpp_binary_opened as u64,
            llama_cpp_version_executions: self.llama_cpp_version_executions,
            command_armed_count: self.command_armed as u64,
            command_executed_count: self.command_executed as u64,
            model_bytes_loaded: self.model_bytes_loaded,
            runtime_bytes_loaded: self.runtime_bytes_loaded,
            provider_calls_made: self.provider_calls_made,
            forbidden_runtime_surface_count: (self.hf_download_enabled as u64)
                + (self.server_mode_enabled as u64)
                + (self.mmap_stress_enabled as u64)
                + (self.provider_route_enabled as u64),
            hidden_authority_count: (self.hidden_route_authority
                || self.hidden_eidos_authority
                || self.hidden_lattice_authority
                || self.hidden_patternboost_authority
                || self.hidden_cloud_fallback) as u64,
            promotion_claim_count: (self.mas_promoted
                || self.l2_capability_effect
                || self.l3_wrv_effect
                || self.product_route_green
                || self.live_gemma_default_claim
                || self.e4b_or_12b_bypass_allowed
                || self.live_dense_70b_claim
                || self.ssd_as_ram_claim) as u64,
        }
    }

    pub fn digest_gate_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_CURSOR.to_string()),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut fields = self.required_digest_fields.clone();
        fields.sort();
        let mut policies = self.required_rejection_policies.clone();
        policies.sort();
        let mut args = self.required_command_args.clone();
        args.sort();
        format!(
            "gemma-e2b-model-file-llama-cpp-digest-gate:v1:{}:{}:{}:{}:{}:{}:{}:{}:{}",
            self.upstream_owner_manifest_digest_gate_ref,
            self.selected_model_id,
            self.source_revision,
            self.required_filename,
            self.expected_file_size_bytes,
            self.command_path,
            fields.join(","),
            policies.join(","),
            args.join(","),
        )
    }
}

// UAS: uas:gemma-qat-e2b-model-file-llama-cpp-digest-gate:metrics
// Plane: Verification.
// Residency: digest-requirement counters and zero-action ledger.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatE2bModelFileAndLlamaCppDigestGateMetrics {
    pub required_digest_field_count: u64,
    pub required_rejection_policy_count: u64,
    pub required_command_arg_count: u64,
    pub forbidden_command_arg_count: u64,
    pub owner_approval_granted_count: u64,
    pub model_file_digest_present_count: u64,
    pub llama_cpp_binary_digest_present_count: u64,
    pub llama_cpp_version_digest_present_count: u64,
    pub raw_path_bytes_stored: u64,
    pub canonical_path_bytes_stored: u64,
    pub path_canonicalization_attempts: u64,
    pub file_stat_attempts: u64,
    pub file_hash_attempts: u64,
    pub model_file_opened_count: u64,
    pub llama_cpp_binary_opened_count: u64,
    pub llama_cpp_version_executions: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub forbidden_runtime_surface_count: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
}

pub fn required_gemma_qat_e2b_model_file_and_llama_cpp_digest_fields() -> Vec<String> {
    REQUIRED_DIGEST_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_qat_e2b_model_file_and_llama_cpp_rejection_policies() -> Vec<String> {
    REQUIRED_REJECTION_POLICIES
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

// UAS: uas:gemma-qat-e2b-model-file-llama-cpp-digest-gate:error
// Plane: Verification.
// Residency: fail-closed digest-gate diagnostics.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaQatE2bModelFileAndLlamaCppDigestGateError {
    BadUpstreamRef,
    BadSelectedLane,
    DuplicateOrMissingField(&'static str),
    BadField(&'static str),
    UnsafeState,
    DigestBoundaryBroken,
    PathOrFileLeak,
    ExecutionLeak,
    PromotionClaim,
    ProofBoundaryBroken,
}

impl fmt::Display for GemmaQatE2bModelFileAndLlamaCppDigestGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamRef => f.write_str("bad upstream owner-manifest digest reference"),
            Self::BadSelectedLane => f.write_str("bad selected Gemma E2B llama.cpp lane"),
            Self::DuplicateOrMissingField(field) => {
                write!(f, "duplicate or missing required set: {field}")
            }
            Self::BadField(field) => write!(f, "bad field: {field}"),
            Self::UnsafeState => f.write_str("unsafe digest-gate state"),
            Self::DigestBoundaryBroken => f.write_str("digest boundary broken"),
            Self::PathOrFileLeak => f.write_str("path or file leak"),
            Self::ExecutionLeak => f.write_str("execution leak"),
            Self::PromotionClaim => f.write_str("promotion or hidden-authority claim"),
            Self::ProofBoundaryBroken => f.write_str("proof boundary broken"),
        }
    }
}

impl std::error::Error for GemmaQatE2bModelFileAndLlamaCppDigestGateError {}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaQatE2bModelFileAndLlamaCppDigestGateError> {
    if actual.len() != expected.len() {
        return Err(
            GemmaQatE2bModelFileAndLlamaCppDigestGateError::DuplicateOrMissingField(field_name),
        );
    }
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual_set.len() != actual.len() || actual_set != expected_set {
        return Err(
            GemmaQatE2bModelFileAndLlamaCppDigestGateError::DuplicateOrMissingField(field_name),
        );
    }
    Ok(())
}

fn validate_prefix(
    field_name: &'static str,
    actual: &str,
    expected_prefix: &str,
) -> Result<(), GemmaQatE2bModelFileAndLlamaCppDigestGateError> {
    if actual.starts_with(expected_prefix) {
        Ok(())
    } else {
        Err(GemmaQatE2bModelFileAndLlamaCppDigestGateError::BadField(
            field_name,
        ))
    }
}

fn validate_exact(
    field_name: &'static str,
    actual: &str,
    expected: &str,
) -> Result<(), GemmaQatE2bModelFileAndLlamaCppDigestGateError> {
    if actual == expected {
        Ok(())
    } else {
        Err(GemmaQatE2bModelFileAndLlamaCppDigestGateError::BadField(
            field_name,
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_398_000_000;

    #[test]
    fn canonical_digest_gate_validates_zero_runtime_actions() {
        let gate = GemmaQatE2bModelFileAndLlamaCppDigestGate::canonical(
            GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_UPSTREAM_REF,
        );
        gate.validate().expect("canonical gate should validate");
        let metrics = gate.metrics();
        assert_eq!(metrics.required_digest_field_count, 24);
        assert_eq!(metrics.required_rejection_policy_count, 40);
        assert_eq!(metrics.model_file_opened_count, 0);
        assert_eq!(metrics.llama_cpp_binary_opened_count, 0);
        assert_eq!(metrics.command_executed_count, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(metrics.runtime_bytes_loaded, 0);
        assert_eq!(metrics.hidden_authority_count, 0);
        assert_eq!(metrics.promotion_claim_count, 0);
    }

    #[test]
    fn missing_digest_fields_are_rejected() {
        let mut gate = GemmaQatE2bModelFileAndLlamaCppDigestGate::canonical(
            GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_UPSTREAM_REF,
        );
        gate.required_digest_fields.pop();
        assert!(matches!(
            gate.validate(),
            Err(
                GemmaQatE2bModelFileAndLlamaCppDigestGateError::DuplicateOrMissingField(
                    "required_digest_fields"
                )
            )
        ));
    }

    #[test]
    fn file_command_and_promotion_actions_are_rejected() {
        let mutations: Vec<Box<dyn Fn(&mut GemmaQatE2bModelFileAndLlamaCppDigestGate)>> = vec![
            Box::new(|gate| gate.file_hash_attempts = 1),
            Box::new(|gate| gate.model_file_opened = true),
            Box::new(|gate| gate.llama_cpp_binary_opened = true),
            Box::new(|gate| gate.command_armed = true),
            Box::new(|gate| gate.hf_download_enabled = true),
            Box::new(|gate| gate.product_route_green = true),
        ];
        for mutate in mutations {
            let mut gate = GemmaQatE2bModelFileAndLlamaCppDigestGate::canonical(
                GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_UPSTREAM_REF,
            );
            mutate(&mut gate);
            assert!(gate.validate().is_err());
        }
    }

    #[test]
    fn digest_gate_address_is_order_deterministic() {
        let gate = GemmaQatE2bModelFileAndLlamaCppDigestGate::canonical(
            GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_UPSTREAM_REF,
        );
        let reversed = GemmaQatE2bModelFileAndLlamaCppDigestGate {
            required_digest_fields: gate.required_digest_fields.iter().cloned().rev().collect(),
            required_rejection_policies: gate
                .required_rejection_policies
                .iter()
                .cloned()
                .rev()
                .collect(),
            required_command_args: gate.required_command_args.iter().cloned().rev().collect(),
            ..gate.clone()
        };
        gate.validate().expect("canonical gate should validate");
        reversed.validate().expect("reversed sets should validate");
        assert_eq!(
            gate.digest_gate_address(CREATED_AT_MS),
            reversed.digest_gate_address(CREATED_AT_MS)
        );
    }
}
