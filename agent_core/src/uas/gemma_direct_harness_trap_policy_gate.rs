//! Gemma direct harness trap-policy gate.
//!
//! This primitive hardens the first future Gemma direct-file runtime proof
//! against convenience-path drift. It is metadata-only: no command is armed, no
//! model path is opened, no server/cache/provider route is used, and no product
//! route or default is promoted.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_ID,
};

pub const GEMMA_DIRECT_HARNESS_TRAP_POLICY_GATE_ID: &str = "F-GemmaDirectHarnessTrapPolicyGate";
pub const GEMMA_DIRECT_HARNESS_TRAP_POLICY_GATE_CURSOR: &str =
    "gemma_direct_harness_trap_policy_gate";
pub const GEMMA_DIRECT_HARNESS_TRAP_POLICY_GATE_NEXT_CURSOR: &str =
    "gemma_direct_harness_first_runtime_proof_receipt_gate";
pub const GEMMA_DIRECT_HARNESS_TRAP_POLICY_GATE_UPSTREAM_REF: &str = "artifact:falsifiers/gemma_direct_harness_first_runtime_proof_command_card/result.json#F-GemmaDirectHarnessFirstRuntimeProofCommandCard";

const UPSTREAM_COMMAND_CARD_PREFIX: &str =
    "artifact:falsifiers/gemma_direct_harness_first_runtime_proof_command_card/";
const ARTIFACT_ROOT_PREFIX: &str = "artifacts/falsifiers/gemma_direct_harness_trap_policy_gate/";
const POLICY_ID: &str = "gemma-direct-harness-trap-policy-v1";
const RUNTIME_LANE: &str = "gemma-direct-harness-llama-cpp-gguf-pro-gated";
const MAX_METADATA_BYTES: u64 = 384 * 1024;

const REQUIRED_POLICY_FIELDS: &[&str] = &[
    "upstream_command_card_digest",
    "owner_approval_digest",
    "selected_model_uas_address",
    "model_file_sha256",
    "model_file_byte_count",
    "redacted_model_path_digest",
    "llama_cli_binary_sha256",
    "llama_cli_version_digest",
    "offline_flag_digest",
    "local_model_flag_digest",
    "text_only_prompt_digest",
    "bounded_context_digest",
    "bounded_predict_digest",
    "timeout_digest",
    "cancellation_digest",
    "redacted_stdio_digest",
    "no_network_digest",
    "no_server_digest",
    "no_hf_cache_digest",
    "no_mtp_drafter_digest",
    "no_mmproj_digest",
    "no_mlx_substitution_digest",
    "no_litert_substitution_digest",
    "no_provider_digest",
    "rollback_ref",
    "run_event_log_ref",
    "answer_packet_ref",
    "abstention_ref",
    "non_promotion_digest",
];

const ALLOWED_RUNTIME_SHAPES: &[&str] = &[
    "llama-cli",
    "--offline",
    "-m",
    "owner-approved-local-gguf",
    "text-only-synthetic-prompt",
    "bounded-context",
    "bounded-predict",
    "fixed-seed",
    "timeout",
    "cancellation",
    "redacted-stdio-digests",
    "run-event-log",
    "answer-packet",
    "rollback",
];

const DENIED_RUNTIME_SHAPES: &[&str] = &[
    "-hf",
    "--hf-repo",
    "--hf-file",
    "--hf-token",
    "hf-cache",
    "url-or-model-repo",
    "llama-server",
    "--host",
    "--port",
    "--api-key",
    "openai-compatible-endpoint",
    "ollama",
    "lm-studio",
    "docker",
    "mtp",
    "draft-model",
    "drafter",
    "mmproj",
    "image-input",
    "multimodal",
    "mlx-folder",
    "litert-bundle",
    "safetensors",
    "provider-env",
    "unbounded-context",
    "unbounded-predict",
    "runtime-router-mutation",
    "system-g-mutation",
    "default-model-mutation",
];

const DENIED_FILE_CLASSES: &[&str] = &[
    "unapproved-mmproj",
    "unapproved-mlx-folder",
    "unapproved-litertlm",
    "unapproved-safetensors",
    "hf-cache-directory",
    "provider-manifest",
    "remote-model-repo",
    "raw-owner-path-log",
];

// UAS: uas:gemma-direct-harness-trap-policy-gate:status
// Plane: Controller + Verification.
// Residency: trap-policy metadata only; zero runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaDirectHarnessTrapPolicyGateStatus {
    TrapPolicyContractOnly,
}

// UAS: uas:gemma-direct-harness-trap-policy-gate:spec
// Plane: Controller + Verification.
// Residency: future direct local GGUF proof trap policy only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessTrapPolicyGate {
    pub upstream_command_card_ref: String,
    pub upstream_command_card_id: String,
    pub artifact_root_prefix: String,
    pub policy_id: String,
    pub runtime_lane: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_policy_fields: Vec<String>,
    pub allowed_runtime_shapes: Vec<String>,
    pub denied_runtime_shapes: Vec<String>,
    pub denied_file_classes: Vec<String>,
    pub owner_approval_required: bool,
    pub text_only_required: bool,
    pub direct_local_file_required: bool,
    pub offline_required: bool,
    pub no_server_required: bool,
    pub no_network_required: bool,
    pub no_hf_cache_required: bool,
    pub no_mtp_drafter_required: bool,
    pub no_mmproj_required: bool,
    pub no_mlx_loader_assumption: bool,
    pub no_litert_assumption: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub abstention_required: bool,
    pub command_armed: bool,
    pub command_executed: bool,
    pub process_spawned: bool,
    pub server_started: bool,
    pub network_allowed: bool,
    pub hub_cache_allowed: bool,
    pub provider_route_allowed: bool,
    pub model_file_opened: bool,
    pub mmproj_opened: bool,
    pub mlx_folder_opened: bool,
    pub litert_bundle_opened: bool,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub raw_path_bytes: u64,
    pub raw_prompt_bytes: u64,
    pub raw_output_bytes: u64,
    pub runtime_router_mutation_allowed: bool,
    pub system_g_mutation_allowed: bool,
    pub settings_or_default_mutation_allowed: bool,
    pub hidden_route_authority: bool,
    pub hidden_eidos_authority: bool,
    pub hidden_lattice_authority: bool,
    pub hidden_patternboost_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub quality_claimed: bool,
    pub l2_capability_effect: bool,
    pub l3_wrv_effect: bool,
    pub t4_build_green_effect: bool,
    pub live_gemma_default_claim: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub metadata_bytes: u64,
    pub status: GemmaDirectHarnessTrapPolicyGateStatus,
    pub next_cursor: String,
}

impl GemmaDirectHarnessTrapPolicyGate {
    pub fn canonical() -> Self {
        Self {
            upstream_command_card_ref: GEMMA_DIRECT_HARNESS_TRAP_POLICY_GATE_UPSTREAM_REF
                .to_string(),
            upstream_command_card_id: GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_ID
                .to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            policy_id: POLICY_ID.to_string(),
            runtime_lane: RUNTIME_LANE.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_policy_fields: REQUIRED_POLICY_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            allowed_runtime_shapes: ALLOWED_RUNTIME_SHAPES
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            denied_runtime_shapes: DENIED_RUNTIME_SHAPES
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            denied_file_classes: DENIED_FILE_CLASSES
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            owner_approval_required: true,
            text_only_required: true,
            direct_local_file_required: true,
            offline_required: true,
            no_server_required: true,
            no_network_required: true,
            no_hf_cache_required: true,
            no_mtp_drafter_required: true,
            no_mmproj_required: true,
            no_mlx_loader_assumption: true,
            no_litert_assumption: true,
            rollback_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            abstention_required: true,
            command_armed: false,
            command_executed: false,
            process_spawned: false,
            server_started: false,
            network_allowed: false,
            hub_cache_allowed: false,
            provider_route_allowed: false,
            model_file_opened: false,
            mmproj_opened: false,
            mlx_folder_opened: false,
            litert_bundle_opened: false,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            raw_path_bytes: 0,
            raw_prompt_bytes: 0,
            raw_output_bytes: 0,
            runtime_router_mutation_allowed: false,
            system_g_mutation_allowed: false,
            settings_or_default_mutation_allowed: false,
            hidden_route_authority: false,
            hidden_eidos_authority: false,
            hidden_lattice_authority: false,
            hidden_patternboost_authority: false,
            hidden_cloud_fallback: false,
            quality_claimed: false,
            l2_capability_effect: false,
            l3_wrv_effect: false,
            t4_build_green_effect: false,
            live_gemma_default_claim: false,
            live_dense_70b_claim: false,
            ssd_as_ram_claim: false,
            metadata_bytes: 256_000,
            status: GemmaDirectHarnessTrapPolicyGateStatus::TrapPolicyContractOnly,
            next_cursor: GEMMA_DIRECT_HARNESS_TRAP_POLICY_GATE_NEXT_CURSOR.to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaDirectHarnessTrapPolicyGateError> {
        if !self
            .upstream_command_card_ref
            .starts_with(UPSTREAM_COMMAND_CARD_PREFIX)
            || self.upstream_command_card_id
                != GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_ID
        {
            return Err(GemmaDirectHarnessTrapPolicyGateError::BadUpstreamRef);
        }
        validate_exact(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact("policy_id", &self.policy_id, POLICY_ID)?;
        validate_exact("runtime_lane", &self.runtime_lane, RUNTIME_LANE)?;
        validate_unique_exact_set(
            "required_policy_fields",
            &self.required_policy_fields,
            REQUIRED_POLICY_FIELDS,
        )?;
        validate_unique_exact_set(
            "allowed_runtime_shapes",
            &self.allowed_runtime_shapes,
            ALLOWED_RUNTIME_SHAPES,
        )?;
        validate_unique_exact_set(
            "denied_runtime_shapes",
            &self.denied_runtime_shapes,
            DENIED_RUNTIME_SHAPES,
        )?;
        validate_unique_exact_set(
            "denied_file_classes",
            &self.denied_file_classes,
            DENIED_FILE_CLASSES,
        )?;
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status != GemmaDirectHarnessTrapPolicyGateStatus::TrapPolicyContractOnly
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(GemmaDirectHarnessTrapPolicyGateError::UnsafeState);
        }
        if !self.owner_approval_required
            || !self.text_only_required
            || !self.direct_local_file_required
            || !self.offline_required
            || !self.no_server_required
            || !self.no_network_required
            || !self.no_hf_cache_required
            || !self.no_mtp_drafter_required
            || !self.no_mmproj_required
            || !self.no_mlx_loader_assumption
            || !self.no_litert_assumption
            || !self.rollback_required
            || !self.run_event_log_required
            || !self.answer_packet_required
            || !self.abstention_required
        {
            return Err(GemmaDirectHarnessTrapPolicyGateError::ProofBoundaryBroken);
        }
        if self.command_armed
            || self.command_executed
            || self.process_spawned
            || self.server_started
            || self.network_allowed
            || self.hub_cache_allowed
            || self.provider_route_allowed
            || self.model_file_opened
            || self.mmproj_opened
            || self.mlx_folder_opened
            || self.litert_bundle_opened
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaDirectHarnessTrapPolicyGateError::RuntimeActionLeak);
        }
        if self.raw_path_bytes != 0 || self.raw_prompt_bytes != 0 || self.raw_output_bytes != 0 {
            return Err(GemmaDirectHarnessTrapPolicyGateError::PrivacyLeak);
        }
        if self.runtime_router_mutation_allowed
            || self.system_g_mutation_allowed
            || self.settings_or_default_mutation_allowed
            || self.hidden_route_authority
            || self.hidden_eidos_authority
            || self.hidden_lattice_authority
            || self.hidden_patternboost_authority
            || self.hidden_cloud_fallback
            || self.quality_claimed
            || self.l2_capability_effect
            || self.l3_wrv_effect
            || self.t4_build_green_effect
            || self.live_gemma_default_claim
            || self.live_dense_70b_claim
            || self.ssd_as_ram_claim
        {
            return Err(GemmaDirectHarnessTrapPolicyGateError::PromotionClaim);
        }
        validate_exact(
            "next_cursor",
            &self.next_cursor,
            GEMMA_DIRECT_HARNESS_TRAP_POLICY_GATE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaDirectHarnessTrapPolicyGateMetrics {
        GemmaDirectHarnessTrapPolicyGateMetrics {
            required_policy_field_count: self.required_policy_fields.len() as u64,
            allowed_runtime_shape_count: self.allowed_runtime_shapes.len() as u64,
            denied_runtime_shape_count: self.denied_runtime_shapes.len() as u64,
            denied_file_class_count: self.denied_file_classes.len() as u64,
            command_armed_count: self.command_armed as u64,
            command_executed_count: self.command_executed as u64,
            process_spawned_count: self.process_spawned as u64,
            server_started_count: self.server_started as u64,
            network_hub_provider_count: (self.network_allowed
                || self.hub_cache_allowed
                || self.provider_route_allowed) as u64,
            file_open_count: (self.model_file_opened
                || self.mmproj_opened
                || self.mlx_folder_opened
                || self.litert_bundle_opened) as u64,
            model_bytes_loaded: self.model_bytes_loaded,
            runtime_bytes_loaded: self.runtime_bytes_loaded,
            provider_calls_made: self.provider_calls_made,
            raw_private_bytes: self.raw_path_bytes + self.raw_prompt_bytes + self.raw_output_bytes,
            mutation_count: (self.runtime_router_mutation_allowed
                || self.system_g_mutation_allowed
                || self.settings_or_default_mutation_allowed) as u64,
            hidden_authority_count: (self.hidden_route_authority
                || self.hidden_eidos_authority
                || self.hidden_lattice_authority
                || self.hidden_patternboost_authority
                || self.hidden_cloud_fallback) as u64,
            promotion_claim_count: (self.quality_claimed
                || self.l2_capability_effect
                || self.l3_wrv_effect
                || self.t4_build_green_effect
                || self.live_gemma_default_claim
                || self.live_dense_70b_claim
                || self.ssd_as_ram_claim) as u64,
        }
    }

    pub fn policy_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(GEMMA_DIRECT_HARNESS_TRAP_POLICY_GATE_CURSOR.to_string()),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut required = self.required_policy_fields.clone();
        required.sort();
        let mut allowed = self.allowed_runtime_shapes.clone();
        allowed.sort();
        let mut denied = self.denied_runtime_shapes.clone();
        denied.sort();
        let mut denied_files = self.denied_file_classes.clone();
        denied_files.sort();
        format!(
            "gemma-direct-harness-trap-policy:v1:{}:{}:{}:{}:{}:{}",
            self.upstream_command_card_ref,
            self.runtime_lane,
            required.join(","),
            allowed.join(","),
            denied.join(","),
            denied_files.join(","),
        )
    }
}

// UAS: uas:gemma-direct-harness-trap-policy-gate:metrics
// Plane: Verification.
// Residency: zero-action trap-policy counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessTrapPolicyGateMetrics {
    pub required_policy_field_count: u64,
    pub allowed_runtime_shape_count: u64,
    pub denied_runtime_shape_count: u64,
    pub denied_file_class_count: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub process_spawned_count: u64,
    pub server_started_count: u64,
    pub network_hub_provider_count: u64,
    pub file_open_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub raw_private_bytes: u64,
    pub mutation_count: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
}

pub fn required_gemma_direct_harness_trap_policy_fields() -> Vec<String> {
    REQUIRED_POLICY_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn allowed_gemma_direct_harness_trap_policy_runtime_shapes() -> Vec<String> {
    ALLOWED_RUNTIME_SHAPES
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn denied_gemma_direct_harness_trap_policy_runtime_shapes() -> Vec<String> {
    DENIED_RUNTIME_SHAPES
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn denied_gemma_direct_harness_trap_policy_file_classes() -> Vec<String> {
    DENIED_FILE_CLASSES
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

// UAS: uas:gemma-direct-harness-trap-policy-gate:error
// Plane: Verification.
// Residency: fail-closed diagnostics only.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaDirectHarnessTrapPolicyGateError {
    BadUpstreamRef,
    DuplicateOrMissingField(&'static str),
    BadField(&'static str),
    UnsafeState,
    ProofBoundaryBroken,
    RuntimeActionLeak,
    PrivacyLeak,
    PromotionClaim,
}

impl fmt::Display for GemmaDirectHarnessTrapPolicyGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamRef => f.write_str("bad upstream command-card reference"),
            Self::DuplicateOrMissingField(field) => {
                write!(f, "duplicate or missing required set: {field}")
            }
            Self::BadField(field) => write!(f, "bad field: {field}"),
            Self::UnsafeState => f.write_str("unsafe Gemma trap-policy state"),
            Self::ProofBoundaryBroken => f.write_str("Gemma trap-policy boundary broken"),
            Self::RuntimeActionLeak => f.write_str("runtime action leak"),
            Self::PrivacyLeak => f.write_str("privacy leak"),
            Self::PromotionClaim => f.write_str("promotion or hidden-authority claim"),
        }
    }
}

impl std::error::Error for GemmaDirectHarnessTrapPolicyGateError {}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaDirectHarnessTrapPolicyGateError> {
    if actual.len() != expected.len() {
        return Err(GemmaDirectHarnessTrapPolicyGateError::DuplicateOrMissingField(field_name));
    }
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual_set.len() != actual.len() || actual_set != expected_set {
        return Err(GemmaDirectHarnessTrapPolicyGateError::DuplicateOrMissingField(field_name));
    }
    Ok(())
}

fn validate_exact(
    field_name: &'static str,
    actual: &str,
    expected: &str,
) -> Result<(), GemmaDirectHarnessTrapPolicyGateError> {
    if actual == expected {
        Ok(())
    } else {
        Err(GemmaDirectHarnessTrapPolicyGateError::BadField(field_name))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_840_000_000;

    #[test]
    fn canonical_trap_policy_validates_zero_actions() {
        let gate = GemmaDirectHarnessTrapPolicyGate::canonical();
        gate.validate()
            .expect("canonical Gemma trap policy should validate");
        let metrics = gate.metrics();
        assert_eq!(metrics.required_policy_field_count, 29);
        assert_eq!(metrics.allowed_runtime_shape_count, 14);
        assert_eq!(metrics.denied_runtime_shape_count, 29);
        assert_eq!(metrics.denied_file_class_count, 8);
        assert_eq!(metrics.command_executed_count, 0);
        assert_eq!(metrics.server_started_count, 0);
        assert_eq!(metrics.network_hub_provider_count, 0);
        assert_eq!(metrics.file_open_count, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(metrics.runtime_bytes_loaded, 0);
        assert_eq!(metrics.raw_private_bytes, 0);
        assert_eq!(metrics.mutation_count, 0);
        assert_eq!(metrics.hidden_authority_count, 0);
        assert_eq!(metrics.promotion_claim_count, 0);
    }

    #[test]
    fn duplicate_sets_are_rejected() {
        let mut gate = GemmaDirectHarnessTrapPolicyGate::canonical();
        gate.denied_runtime_shapes[0] = gate.denied_runtime_shapes[1].clone();
        assert!(matches!(
            gate.validate(),
            Err(
                GemmaDirectHarnessTrapPolicyGateError::DuplicateOrMissingField(
                    "denied_runtime_shapes"
                )
            )
        ));

        let mut gate = GemmaDirectHarnessTrapPolicyGate::canonical();
        gate.allowed_runtime_shapes[0] = gate.allowed_runtime_shapes[1].clone();
        assert!(matches!(
            gate.validate(),
            Err(
                GemmaDirectHarnessTrapPolicyGateError::DuplicateOrMissingField(
                    "allowed_runtime_shapes"
                )
            )
        ));
    }

    #[test]
    fn shortcut_runtime_paths_are_rejected() {
        for mutate in [
            |g: &mut GemmaDirectHarnessTrapPolicyGate| g.server_started = true,
            |g: &mut GemmaDirectHarnessTrapPolicyGate| g.network_allowed = true,
            |g: &mut GemmaDirectHarnessTrapPolicyGate| g.hub_cache_allowed = true,
            |g: &mut GemmaDirectHarnessTrapPolicyGate| g.provider_route_allowed = true,
            |g: &mut GemmaDirectHarnessTrapPolicyGate| g.mmproj_opened = true,
            |g: &mut GemmaDirectHarnessTrapPolicyGate| g.mlx_folder_opened = true,
            |g: &mut GemmaDirectHarnessTrapPolicyGate| g.litert_bundle_opened = true,
        ] {
            let mut gate = GemmaDirectHarnessTrapPolicyGate::canonical();
            mutate(&mut gate);
            assert!(matches!(
                gate.validate(),
                Err(GemmaDirectHarnessTrapPolicyGateError::RuntimeActionLeak)
            ));
        }
    }

    #[test]
    fn deterministic_address_ignores_set_order() {
        let gate = GemmaDirectHarnessTrapPolicyGate::canonical();
        let reordered = GemmaDirectHarnessTrapPolicyGate {
            required_policy_fields: gate.required_policy_fields.iter().cloned().rev().collect(),
            allowed_runtime_shapes: gate.allowed_runtime_shapes.iter().cloned().rev().collect(),
            denied_runtime_shapes: gate.denied_runtime_shapes.iter().cloned().rev().collect(),
            denied_file_classes: gate.denied_file_classes.iter().cloned().rev().collect(),
            ..gate.clone()
        };
        gate.validate().expect("original validates");
        reordered.validate().expect("reordered validates");
        assert_eq!(
            gate.policy_address(CREATED_AT_MS),
            reordered.policy_address(CREATED_AT_MS)
        );
    }
}
