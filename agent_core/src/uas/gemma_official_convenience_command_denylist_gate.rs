//! Gemma official convenience-command denylist gate.
//!
//! Official model cards and runtime guides are source evidence, not Epistemos
//! runtime proof. This metadata-only gate keeps convenience commands like
//! `llama-cli -hf`, `llama-server`, and LiteRT-LM `serve` from being promoted
//! as local artifact receipts, route admission, or user-facing Gemma capability.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, UasAddress, UasKind, GEMMA_LOCAL_ARTIFACT_ACQUISITION_RECEIPT_GATE_ID,
};

pub const GEMMA_OFFICIAL_CONVENIENCE_COMMAND_DENYLIST_GATE_ID: &str =
    "F-GemmaOfficialConvenienceCommandDenylistGate";
pub const GEMMA_OFFICIAL_CONVENIENCE_COMMAND_DENYLIST_GATE_CURSOR: &str =
    "gemma_official_convenience_command_denylist_gate";
pub const GEMMA_OFFICIAL_CONVENIENCE_COMMAND_DENYLIST_GATE_NEXT_CURSOR: &str =
    "gemma_direct_harness_owner_approved_first_runtime_execution_probe";
pub const GEMMA_OFFICIAL_CONVENIENCE_COMMAND_DENYLIST_GATE_UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_local_artifact_acquisition_receipt_gate/result.json#F-GemmaLocalArtifactAcquisitionReceiptGate";

const UPSTREAM_PREFIX: &str = "artifact:falsifiers/gemma_local_artifact_acquisition_receipt_gate/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_official_convenience_command_denylist_gate/";
const GATE_ID: &str = "gemma-official-convenience-command-denylist-gate-v1";
const MAX_METADATA_BYTES: u64 = 96 * 1024;
const CREATED_AT_MS: u64 = 1_779_938_400_000;

const OFFICIAL_SOURCE_REFS: &[&str] = &[
    "https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf",
    "https://huggingface.co/google/gemma-4-E4B-it-qat-q4_0-gguf",
    "https://developers.googleblog.com/gemma-4-12b-the-developer-guide/",
    "https://deepmind.google/models/gemma/gemma-4/",
];

const DENIED_CONVENIENCE_COMMANDS: &[&str] = &[
    "llama_cli_hf_remote_fetch",
    "llama_server_hf_remote_fetch",
    "llama_server_local_endpoint_as_proof",
    "litert_lm_serve_as_proof",
    "ollama_run_hf_as_proof",
    "lm_studio_import_as_proof",
    "pi_or_hermes_endpoint_as_proof",
    "hf_cache_path_as_local_artifact_identity",
];

const REQUIRED_REPLACEMENT_PROOFS: &[&str] = &[
    "owner_approval_ref",
    "selected_source_card_ref",
    "acquisition_receipt_ref",
    "local_file_sha256",
    "local_file_byte_count",
    "tool_version_digest",
    "direct_local_file_argv",
    "network_disabled_for_runtime_probe",
    "server_disabled_for_runtime_probe",
    "timeout_cancel_teardown_ref",
    "run_event_log_ref",
    "answer_packet_ref",
    "rollback_ref",
    "same_fixture_replay_before_admission",
];

const REQUIRED_REJECTION_POLICIES: &[&str] = &[
    "missing_upstream_receipt_gate",
    "missing_official_source_ref",
    "duplicate_official_source_ref",
    "missing_denied_convenience_command",
    "duplicate_denied_convenience_command",
    "missing_replacement_proof",
    "duplicate_replacement_proof",
    "missing_rejection_policy",
    "official_card_as_runtime_proof",
    "hf_command_as_receipt",
    "server_as_route_admission",
    "litert_serve_as_product_default",
    "endpoint_as_system_g_admission",
    "hf_cache_path_as_local_identity",
    "raw_path_or_token_leak",
    "network_allowed_for_probe",
    "command_armed",
    "command_executed",
    "server_started",
    "model_bytes_loaded",
    "runtime_bytes_loaded",
    "provider_called",
    "route_mutated",
    "hidden_authority",
    "missing_rollback",
    "missing_run_event_log",
    "missing_answer_packet",
    "l2_l3_t4_or_live_gemma_claim",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
];

// UAS: uas:gemma-official-convenience-command-denylist-gate:spec
// Plane: Controller + Verification.
// Residency: source-card policy only; zero command/model/runtime bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaOfficialConvenienceCommandDenylistGate {
    pub upstream_receipt_gate_ref: String,
    pub upstream_receipt_gate_id: String,
    pub artifact_root_prefix: String,
    pub gate_id: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub official_source_refs: Vec<String>,
    pub denied_convenience_commands: Vec<String>,
    pub required_replacement_proofs: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub official_card_counts_as_runtime_proof: bool,
    pub convenience_command_counts_as_receipt: bool,
    pub server_counts_as_route_admission: bool,
    pub endpoint_counts_as_system_g_admission: bool,
    pub hf_cache_path_counts_as_local_identity: bool,
    pub raw_path_or_token_bytes_allowed: bool,
    pub network_allowed_for_runtime_probe: bool,
    pub command_armed: bool,
    pub command_executed: bool,
    pub server_started: bool,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub runtime_router_mutation_allowed: bool,
    pub system_g_mutation_allowed: bool,
    pub settings_default_mutation_allowed: bool,
    pub hidden_route_authority: bool,
    pub hidden_eidos_authority: bool,
    pub hidden_lattice_authority: bool,
    pub hidden_patternboost_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_required: bool,
    pub l2_l3_t4_claim: bool,
    pub live_gemma_claim: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub metadata_bytes: u64,
    pub next_cursor: String,
}

impl GemmaOfficialConvenienceCommandDenylistGate {
    pub fn canonical() -> Self {
        Self {
            upstream_receipt_gate_ref:
                GEMMA_OFFICIAL_CONVENIENCE_COMMAND_DENYLIST_GATE_UPSTREAM_REF.to_string(),
            upstream_receipt_gate_id: GEMMA_LOCAL_ARTIFACT_ACQUISITION_RECEIPT_GATE_ID.to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            gate_id: GATE_ID.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            official_source_refs: OFFICIAL_SOURCE_REFS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            denied_convenience_commands: DENIED_CONVENIENCE_COMMANDS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            required_replacement_proofs: REQUIRED_REPLACEMENT_PROOFS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            required_rejection_policies: REQUIRED_REJECTION_POLICIES
                .iter()
                .map(|value| value.to_string())
                .collect(),
            official_card_counts_as_runtime_proof: false,
            convenience_command_counts_as_receipt: false,
            server_counts_as_route_admission: false,
            endpoint_counts_as_system_g_admission: false,
            hf_cache_path_counts_as_local_identity: false,
            raw_path_or_token_bytes_allowed: false,
            network_allowed_for_runtime_probe: false,
            command_armed: false,
            command_executed: false,
            server_started: false,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            runtime_router_mutation_allowed: false,
            system_g_mutation_allowed: false,
            settings_default_mutation_allowed: false,
            hidden_route_authority: false,
            hidden_eidos_authority: false,
            hidden_lattice_authority: false,
            hidden_patternboost_authority: false,
            hidden_cloud_fallback: false,
            rollback_ref: "rollback:gemma-official-convenience-command-denylist-gate-v1"
                .to_string(),
            run_event_log_ref: "run_event_log:gemma-official-convenience-command-denylist-gate-v1"
                .to_string(),
            answer_packet_ref: "answer_packet:gemma-official-convenience-command-denylist-gate-v1"
                .to_string(),
            abstention_required: true,
            l2_l3_t4_claim: false,
            live_gemma_claim: false,
            live_dense_70b_claim: false,
            ssd_as_ram_claim: false,
            metadata_bytes: MAX_METADATA_BYTES,
            next_cursor: GEMMA_OFFICIAL_CONVENIENCE_COMMAND_DENYLIST_GATE_NEXT_CURSOR.to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaOfficialConvenienceCommandDenylistGateError> {
        validate_prefix(
            &self.upstream_receipt_gate_ref,
            UPSTREAM_PREFIX,
            "upstream_receipt_gate_ref",
        )?;
        if self.upstream_receipt_gate_id != GEMMA_LOCAL_ARTIFACT_ACQUISITION_RECEIPT_GATE_ID {
            return Err(GemmaOfficialConvenienceCommandDenylistGateError::BadUpstream);
        }
        if self.artifact_root_prefix != ARTIFACT_ROOT_PREFIX || self.gate_id != GATE_ID {
            return Err(GemmaOfficialConvenienceCommandDenylistGateError::BadIdentity);
        }
        if self.product_build != ProductBuild::Pro || self.pro_status != ProStatus::Gated {
            return Err(GemmaOfficialConvenienceCommandDenylistGateError::BadBuildStatus);
        }
        validate_unique_required(
            "official_source",
            &self.official_source_refs,
            OFFICIAL_SOURCE_REFS,
        )?;
        validate_unique_required(
            "denied_convenience_command",
            &self.denied_convenience_commands,
            DENIED_CONVENIENCE_COMMANDS,
        )?;
        validate_unique_required(
            "replacement_proof",
            &self.required_replacement_proofs,
            REQUIRED_REPLACEMENT_PROOFS,
        )?;
        validate_unique_required(
            "rejection_policy",
            &self.required_rejection_policies,
            REQUIRED_REJECTION_POLICIES,
        )?;
        if self.official_card_counts_as_runtime_proof
            || self.convenience_command_counts_as_receipt
            || self.server_counts_as_route_admission
            || self.endpoint_counts_as_system_g_admission
            || self.hf_cache_path_counts_as_local_identity
        {
            return Err(GemmaOfficialConvenienceCommandDenylistGateError::ShortcutPromoted);
        }
        if self.raw_path_or_token_bytes_allowed {
            return Err(GemmaOfficialConvenienceCommandDenylistGateError::PrivateBytesAllowed);
        }
        if self.network_allowed_for_runtime_probe
            || self.command_armed
            || self.command_executed
            || self.server_started
        {
            return Err(GemmaOfficialConvenienceCommandDenylistGateError::RuntimeAction);
        }
        if self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaOfficialConvenienceCommandDenylistGateError::RuntimeBytesLoaded);
        }
        if self.runtime_router_mutation_allowed
            || self.system_g_mutation_allowed
            || self.settings_default_mutation_allowed
        {
            return Err(GemmaOfficialConvenienceCommandDenylistGateError::RouteMutation);
        }
        if self.hidden_route_authority
            || self.hidden_eidos_authority
            || self.hidden_lattice_authority
            || self.hidden_patternboost_authority
            || self.hidden_cloud_fallback
        {
            return Err(GemmaOfficialConvenienceCommandDenylistGateError::HiddenAuthority);
        }
        validate_prefix(&self.rollback_ref, "rollback:", "rollback_ref")?;
        validate_prefix(
            &self.run_event_log_ref,
            "run_event_log:",
            "run_event_log_ref",
        )?;
        validate_prefix(
            &self.answer_packet_ref,
            "answer_packet:",
            "answer_packet_ref",
        )?;
        if !self.abstention_required {
            return Err(GemmaOfficialConvenienceCommandDenylistGateError::AbstentionMissing);
        }
        if self.l2_l3_t4_claim
            || self.live_gemma_claim
            || self.live_dense_70b_claim
            || self.ssd_as_ram_claim
        {
            return Err(GemmaOfficialConvenienceCommandDenylistGateError::PromotionClaim);
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(GemmaOfficialConvenienceCommandDenylistGateError::MetadataTooLarge);
        }
        if self.next_cursor != GEMMA_OFFICIAL_CONVENIENCE_COMMAND_DENYLIST_GATE_NEXT_CURSOR {
            return Err(GemmaOfficialConvenienceCommandDenylistGateError::BadNextCursor);
        }
        Ok(())
    }

    pub fn address(&self) -> UasAddress {
        UasAddress::new(
            UasKind::Other(GEMMA_OFFICIAL_CONVENIENCE_COMMAND_DENYLIST_GATE_CURSOR.to_string()),
            self.gate_id.as_bytes(),
            CREATED_AT_MS,
        )
    }

    pub fn metrics(&self) -> GemmaOfficialConvenienceCommandDenylistGateMetrics {
        GemmaOfficialConvenienceCommandDenylistGateMetrics {
            official_source_ref_count: self.official_source_refs.len() as u64,
            denied_convenience_command_count: self.denied_convenience_commands.len() as u64,
            replacement_proof_count: self.required_replacement_proofs.len() as u64,
            rejection_policy_count: self.required_rejection_policies.len() as u64,
            shortcut_promotion_count: u64::from(self.official_card_counts_as_runtime_proof)
                + u64::from(self.convenience_command_counts_as_receipt)
                + u64::from(self.server_counts_as_route_admission)
                + u64::from(self.endpoint_counts_as_system_g_admission)
                + u64::from(self.hf_cache_path_counts_as_local_identity),
            private_bytes_allowed_count: u64::from(self.raw_path_or_token_bytes_allowed),
            network_allowed_count: u64::from(self.network_allowed_for_runtime_probe),
            command_armed_count: u64::from(self.command_armed),
            command_executed_count: u64::from(self.command_executed),
            server_started_count: u64::from(self.server_started),
            model_bytes_loaded: self.model_bytes_loaded,
            runtime_bytes_loaded: self.runtime_bytes_loaded,
            provider_calls_made: self.provider_calls_made,
            route_mutation_count: u64::from(self.runtime_router_mutation_allowed)
                + u64::from(self.system_g_mutation_allowed)
                + u64::from(self.settings_default_mutation_allowed),
            hidden_authority_count: u64::from(self.hidden_route_authority)
                + u64::from(self.hidden_eidos_authority)
                + u64::from(self.hidden_lattice_authority)
                + u64::from(self.hidden_patternboost_authority)
                + u64::from(self.hidden_cloud_fallback),
            promotion_claim_count: u64::from(self.l2_l3_t4_claim)
                + u64::from(self.live_gemma_claim)
                + u64::from(self.live_dense_70b_claim)
                + u64::from(self.ssd_as_ram_claim),
            metadata_bytes: self.metadata_bytes,
        }
    }
}

// UAS: uas:gemma-official-convenience-command-denylist-gate:metrics
// Plane: Verification.
// Residency: counters only; no command/model/runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaOfficialConvenienceCommandDenylistGateMetrics {
    pub official_source_ref_count: u64,
    pub denied_convenience_command_count: u64,
    pub replacement_proof_count: u64,
    pub rejection_policy_count: u64,
    pub shortcut_promotion_count: u64,
    pub private_bytes_allowed_count: u64,
    pub network_allowed_count: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub server_started_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub route_mutation_count: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
    pub metadata_bytes: u64,
}

// UAS: uas:gemma-official-convenience-command-denylist-gate:error
// Plane: Verification.
// Residency: validation error only; no external bytes.
#[derive(Debug, PartialEq, Eq)]
pub enum GemmaOfficialConvenienceCommandDenylistGateError {
    EmptyField(&'static str),
    ControlCharacter(&'static str),
    BadPrefix(&'static str),
    MissingRequired(&'static str, &'static str),
    DuplicateValue(&'static str, String),
    BadUpstream,
    BadIdentity,
    BadBuildStatus,
    ShortcutPromoted,
    PrivateBytesAllowed,
    RuntimeAction,
    RuntimeBytesLoaded,
    RouteMutation,
    HiddenAuthority,
    AbstentionMissing,
    PromotionClaim,
    MetadataTooLarge,
    BadNextCursor,
}

impl fmt::Display for GemmaOfficialConvenienceCommandDenylistGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyField(field) => write!(f, "{field} is empty"),
            Self::ControlCharacter(field) => write!(f, "{field} contains control character"),
            Self::BadPrefix(field) => write!(f, "{field} has bad prefix"),
            Self::MissingRequired(kind, value) => write!(f, "{kind} missing {value}"),
            Self::DuplicateValue(kind, value) => write!(f, "{kind} duplicate {value}"),
            Self::BadUpstream => write!(f, "bad upstream"),
            Self::BadIdentity => write!(f, "bad identity"),
            Self::BadBuildStatus => write!(f, "bad build status"),
            Self::ShortcutPromoted => write!(f, "official shortcut promoted"),
            Self::PrivateBytesAllowed => write!(f, "private bytes allowed"),
            Self::RuntimeAction => write!(f, "runtime action occurred"),
            Self::RuntimeBytesLoaded => write!(f, "runtime bytes loaded"),
            Self::RouteMutation => write!(f, "route mutation"),
            Self::HiddenAuthority => write!(f, "hidden authority"),
            Self::AbstentionMissing => write!(f, "abstention missing"),
            Self::PromotionClaim => write!(f, "promotion claim"),
            Self::MetadataTooLarge => write!(f, "metadata too large"),
            Self::BadNextCursor => write!(f, "bad next cursor"),
        }
    }
}

impl std::error::Error for GemmaOfficialConvenienceCommandDenylistGateError {}

pub fn official_gemma_convenience_source_refs() -> &'static [&'static str] {
    OFFICIAL_SOURCE_REFS
}

pub fn denied_gemma_official_convenience_commands() -> &'static [&'static str] {
    DENIED_CONVENIENCE_COMMANDS
}

pub fn required_gemma_convenience_replacement_proofs() -> &'static [&'static str] {
    REQUIRED_REPLACEMENT_PROOFS
}

pub fn required_gemma_convenience_rejection_policies() -> &'static [&'static str] {
    REQUIRED_REJECTION_POLICIES
}

fn validate_unique_required(
    kind: &'static str,
    values: &[String],
    required: &'static [&'static str],
) -> Result<(), GemmaOfficialConvenienceCommandDenylistGateError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_clean(kind, value)?;
        if !seen.insert(value.as_str()) {
            return Err(
                GemmaOfficialConvenienceCommandDenylistGateError::DuplicateValue(
                    kind,
                    value.clone(),
                ),
            );
        }
        if !required.contains(&value.as_str()) {
            return Err(
                GemmaOfficialConvenienceCommandDenylistGateError::DuplicateValue(
                    kind,
                    value.clone(),
                ),
            );
        }
    }
    for required_value in required {
        if !seen.contains(required_value) {
            return Err(
                GemmaOfficialConvenienceCommandDenylistGateError::MissingRequired(
                    kind,
                    required_value,
                ),
            );
        }
    }
    Ok(())
}

fn validate_clean(
    field: &'static str,
    value: &str,
) -> Result<(), GemmaOfficialConvenienceCommandDenylistGateError> {
    if value.trim().is_empty() {
        return Err(GemmaOfficialConvenienceCommandDenylistGateError::EmptyField(field));
    }
    if value.chars().any(|ch| ch.is_control()) {
        return Err(GemmaOfficialConvenienceCommandDenylistGateError::ControlCharacter(field));
    }
    Ok(())
}

fn validate_prefix(
    value: &str,
    prefix: &'static str,
    field: &'static str,
) -> Result<(), GemmaOfficialConvenienceCommandDenylistGateError> {
    validate_clean(field, value)?;
    if !value.starts_with(prefix) {
        return Err(GemmaOfficialConvenienceCommandDenylistGateError::BadPrefix(
            field,
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_gate_validates() {
        let gate = GemmaOfficialConvenienceCommandDenylistGate::canonical();
        gate.validate().expect("canonical denylist gate");
        assert_eq!(gate.metrics().official_source_ref_count, 4);
        assert_eq!(gate.metrics().denied_convenience_command_count, 8);
    }

    #[test]
    fn rejects_hf_command_as_receipt() {
        let mut gate = GemmaOfficialConvenienceCommandDenylistGate::canonical();
        gate.convenience_command_counts_as_receipt = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            GemmaOfficialConvenienceCommandDenylistGateError::ShortcutPromoted
        );
    }

    #[test]
    fn rejects_server_route_admission() {
        let mut gate = GemmaOfficialConvenienceCommandDenylistGate::canonical();
        gate.server_counts_as_route_admission = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            GemmaOfficialConvenienceCommandDenylistGateError::ShortcutPromoted
        );
    }

    #[test]
    fn rejects_network_probe() {
        let mut gate = GemmaOfficialConvenienceCommandDenylistGate::canonical();
        gate.network_allowed_for_runtime_probe = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            GemmaOfficialConvenienceCommandDenylistGateError::RuntimeAction
        );
    }

    #[test]
    fn address_is_deterministic() {
        assert_eq!(
            GemmaOfficialConvenienceCommandDenylistGate::canonical().address(),
            GemmaOfficialConvenienceCommandDenylistGate::canonical().address()
        );
    }
}
