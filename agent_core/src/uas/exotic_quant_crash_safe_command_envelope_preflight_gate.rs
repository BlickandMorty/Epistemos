//! Exotic quant crash-safe command-envelope preflight gate.
//!
//! This primitive consumes owner path byte-envelope preflight cards and turns
//! them into unarmed command/API/kernel envelopes before any dry run, first
//! token, file open, provider call, or product-route claim can begin. It is
//! metadata-only: commands are represented as inert vectors, not shell strings,
//! and every runtime/model/provider byte counter remains zero.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::uas::{
    canonical_owner_path_byte_envelope_preflight_cards, expected_owner_path_manifest_model_ids,
    CompressedModelPromotionTier, HardwareTier, ModelCatalogRuntimeLane,
    OwnerPathByteEnvelopePreflightCard, ProStatus, ProductBuild, UasAddress, UasKind,
};

pub const EXOTIC_QUANT_CRASH_SAFE_COMMAND_ENVELOPE_PREFLIGHT_GATE_CURSOR: &str =
    "exotic_quant_crash_safe_command_envelope_preflight_gate";
pub const EXOTIC_QUANT_CRASH_SAFE_COMMAND_ENVELOPE_PREFLIGHT_GATE_NEXT_CURSOR: &str =
    "exotic_quant_owner_approved_dry_run_transcript_preflight_gate";

const UPSTREAM_BYTE_ENVELOPE_PREFIX: &str =
    "artifact:falsifiers/exotic_quant_owner_path_byte_envelope_preflight_gate/";
const SOURCE_PIN_CARD_PREFIX: &str = "source_pin_card:exotic_quant:";
const MODEL_REVISION_PREFIX: &str = "model_revision:exotic_quant:";
const SELECTED_FILE_PREFIX: &str = "selected_file:exotic_quant:";
const BYTE_ENVELOPE_PREFIX: &str = "byte_envelope:owner_path_preflight:exotic_quant:";
const COMMAND_ENVELOPE_PREFIX: &str = "command_envelope:crash_safe:exotic_quant:";
const DOWNLOAD_POLICY_PREFIX: &str = "download_policy:deny_remote:exotic_quant:";
const ENV_POLICY_PREFIX: &str = "env_policy:credential_redaction:exotic_quant:";
const OUTPUT_POLICY_PREFIX: &str = "output_policy:redacted_bounded:exotic_quant:";
const TIMEOUT_POLICY_PREFIX: &str = "timeout_policy:abortable:exotic_quant:";
const CANCELLATION_PREFIX: &str = "cancellation:exotic_quant_command:";
const TEARDOWN_PREFIX: &str = "teardown:exotic_quant_command:";
const ROLLBACK_PREFIX: &str = "rollback:exotic_quant_command:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:exotic_quant_command:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:exotic_quant_command:";
const ABSTENTION_PREFIX: &str = "abstention:exotic_quant_command:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:exotic_quant_command:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:exotic_quant_command:";
const MIN_VISIBLE_SUMMARY_BYTES: usize = 220;
const MAX_LEDGER_METADATA_BYTES: u64 = 768 * 1024;
const MAX_CARD_METADATA_BYTES: u64 = 128 * 1024;

const FORBIDDEN_ARGS: &[&str] = &[
    "--hf-repo",
    "-hf",
    "-hfr",
    "--hf-file",
    "-hff",
    "--model-url",
    "-mu",
    "--docker-repo",
    "-dr",
    "--hf-token",
    "-hft",
    "--server",
    "--conversation",
    "--mmap",
    "--mlock",
    "--trust-remote-code",
    "trust_remote_code=True",
];

const FORBIDDEN_ENV: &[&str] = &[
    "HF_TOKEN",
    "HUGGINGFACE_HUB_TOKEN",
    "OPENAI_API_KEY",
    "ANTHROPIC_API_KEY",
    "PERPLEXITY_API_KEY",
    "DYLD_INSERT_LIBRARIES",
    "LD_PRELOAD",
    "PYTHONPATH",
    "NODE_OPTIONS",
];

// UAS: uas:exotic-quant-command-envelope:surface
// Plane: Controller
// Residency: command/API/kernel intent only; no process or loader is started.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CrashSafeCommandSurface {
    LlamaCppGgufCli,
    TransformersPythonQuarantine,
    ServerOnlyDenied,
}

// UAS: uas:exotic-quant-command-envelope:state
// Plane: Verification
// Residency: fail-closed state before any owner-approved dry run.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CrashSafeCommandEnvelopeState {
    MacCandidateUnarmedOwnerApprovalRequired,
    ServerOnlyCommandDenied,
}

// UAS: uas:exotic-quant-command-envelope:policy
// Plane: Controller + Verification
// Residency: inert command metadata; every live surface remains denied.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CrashSafeCommandPolicy {
    pub args_vectorized: bool,
    pub shell_string_denied: bool,
    pub cwd_policy_bound: bool,
    pub env_allowlist_bound: bool,
    pub forbidden_env_bound: bool,
    pub remote_download_flags_denied: bool,
    pub hf_token_env_denied: bool,
    pub network_denied: bool,
    pub server_sidecar_denied: bool,
    pub one_token_budget_bound: bool,
    pub context_batch_budget_bound: bool,
    pub kv_cache_policy_bound: bool,
    pub cache_ram_policy_bound: bool,
    pub mmap_fit_claim_denied: bool,
    pub mlock_fit_claim_denied: bool,
    pub stdout_stderr_policy_bound: bool,
    pub output_byte_limit_bound: bool,
    pub timeout_bound: bool,
    pub cancellation_bound: bool,
    pub teardown_bound: bool,
    pub owner_approval_required: bool,
    pub dry_run_only: bool,
    pub no_command_execution: bool,
    pub rollback_bound: bool,
    pub run_event_log_bound: bool,
    pub answer_packet_bound: bool,
    pub artifact_format_matches_lane: bool,
    pub model_revision_bound: bool,
    pub selected_file_bound: bool,
    pub mmproj_policy_visible: bool,
    pub issue_failure_refs_red_only: bool,
}

impl CrashSafeCommandPolicy {
    pub fn unarmed_mac_candidate() -> Self {
        Self {
            args_vectorized: true,
            shell_string_denied: true,
            cwd_policy_bound: true,
            env_allowlist_bound: true,
            forbidden_env_bound: true,
            remote_download_flags_denied: true,
            hf_token_env_denied: true,
            network_denied: true,
            server_sidecar_denied: true,
            one_token_budget_bound: true,
            context_batch_budget_bound: true,
            kv_cache_policy_bound: true,
            cache_ram_policy_bound: true,
            mmap_fit_claim_denied: true,
            mlock_fit_claim_denied: true,
            stdout_stderr_policy_bound: true,
            output_byte_limit_bound: true,
            timeout_bound: true,
            cancellation_bound: true,
            teardown_bound: true,
            owner_approval_required: true,
            dry_run_only: true,
            no_command_execution: true,
            rollback_bound: true,
            run_event_log_bound: true,
            answer_packet_bound: true,
            artifact_format_matches_lane: true,
            model_revision_bound: true,
            selected_file_bound: true,
            mmproj_policy_visible: true,
            issue_failure_refs_red_only: true,
        }
    }

    pub fn server_denied() -> Self {
        let mut policy = Self::unarmed_mac_candidate();
        policy.owner_approval_required = false;
        policy.artifact_format_matches_lane = true;
        policy
    }

    fn proves_crash_safe_preflight(&self) -> bool {
        self.args_vectorized
            && self.shell_string_denied
            && self.cwd_policy_bound
            && self.env_allowlist_bound
            && self.forbidden_env_bound
            && self.remote_download_flags_denied
            && self.hf_token_env_denied
            && self.network_denied
            && self.server_sidecar_denied
            && self.one_token_budget_bound
            && self.context_batch_budget_bound
            && self.kv_cache_policy_bound
            && self.cache_ram_policy_bound
            && self.mmap_fit_claim_denied
            && self.mlock_fit_claim_denied
            && self.stdout_stderr_policy_bound
            && self.output_byte_limit_bound
            && self.timeout_bound
            && self.cancellation_bound
            && self.teardown_bound
            && self.dry_run_only
            && self.no_command_execution
            && self.rollback_bound
            && self.run_event_log_bound
            && self.answer_packet_bound
            && self.artifact_format_matches_lane
            && self.model_revision_bound
            && self.selected_file_bound
            && self.mmproj_policy_visible
            && self.issue_failure_refs_red_only
    }
}

// UAS: uas:exotic-quant-command-envelope:byte-ledger
// Plane: Verification
// Residency: command templates are metadata; live bytes stay zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CrashSafeCommandByteLedger {
    pub metadata_bytes_read: u64,
    pub command_template_bytes_serialized: u64,
    pub owner_manifest_bytes_read: u64,
    pub owner_path_bytes_read: u64,
    pub local_file_bytes_read: u64,
    pub command_execution_count: u64,
    pub stdout_bytes_captured: u64,
    pub stderr_bytes_captured: u64,
    pub token_bytes_captured: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub network_calls_made: u64,
    pub source_tree_bytes_read: u64,
    pub product_bytes_copied: u64,
    pub benchmark_runs: u64,
}

impl CrashSafeCommandByteLedger {
    pub fn metadata_only(metadata_bytes_read: u64, command_template_bytes_serialized: u64) -> Self {
        Self {
            metadata_bytes_read,
            command_template_bytes_serialized,
            owner_manifest_bytes_read: 0,
            owner_path_bytes_read: 0,
            local_file_bytes_read: 0,
            command_execution_count: 0,
            stdout_bytes_captured: 0,
            stderr_bytes_captured: 0,
            token_bytes_captured: 0,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            network_calls_made: 0,
            source_tree_bytes_read: 0,
            product_bytes_copied: 0,
            benchmark_runs: 0,
        }
    }
}

// UAS: uas:exotic-quant-command-envelope:refs
// Plane: Verification
// Residency: visible proof refs before owner-approved dry run.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CrashSafeCommandProofRefs {
    pub upstream_byte_envelope_ref: String,
    pub source_pin_card_ref: String,
    pub model_revision_ref: String,
    pub selected_file_ref: String,
    pub byte_envelope_ref: String,
    pub command_envelope_ref: String,
    pub download_policy_ref: String,
    pub env_policy_ref: String,
    pub output_policy_ref: String,
    pub timeout_policy_ref: String,
    pub cancellation_ref: String,
    pub teardown_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub sovereign_gate_ref: String,
    pub compatibility_fence_ref: String,
}

// UAS: uas:exotic-quant-command-envelope:card
// Plane: Controller + Verification
// Residency: unarmed per-row command envelope before runtime proof.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CrashSafeCommandEnvelopeCard {
    pub gate_id: String,
    pub model_id: String,
    pub source_pin_card_id: String,
    pub selected_artifact_path: String,
    pub hardware_tier: HardwareTier,
    pub runtime_lane: ModelCatalogRuntimeLane,
    pub surface: CrashSafeCommandSurface,
    pub state: CrashSafeCommandEnvelopeState,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub argv_template: Vec<String>,
    pub forbidden_args: Vec<String>,
    pub forbidden_env: Vec<String>,
    pub issue_failure_refs: Vec<String>,
    pub policy: CrashSafeCommandPolicy,
    pub byte_ledger: CrashSafeCommandByteLedger,
    pub proof_refs: CrashSafeCommandProofRefs,
    pub user_visible_summary: String,
    pub byte_envelope_current_hardware_denied: bool,
    pub command_envelope_visible: bool,
    pub command_armed: bool,
    pub command_executable: bool,
    pub dry_run_serialized: bool,
    pub owner_approval_present: bool,
    pub runtime_probe_allowed: bool,
    pub runtime_deferred: bool,
    pub local_artifact_verified: bool,
    pub shell_string_present: bool,
    pub remote_download_allowed: bool,
    pub hf_token_env_allowed: bool,
    pub network_allowed: bool,
    pub server_sidecar_allowed: bool,
    pub mmap_fit_claim: bool,
    pub mlock_fit_claim: bool,
    pub output_unbounded: bool,
    pub timeout_missing: bool,
    pub cancellation_missing: bool,
    pub teardown_missing: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub abstention_required: bool,
    pub mas_allowed: bool,
    pub product_route_enabled: bool,
    pub app_default_claim: bool,
    pub product_winner_claim: bool,
    pub route_policy_mutated: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub patternboost_live_authority: bool,
    pub lattice_live_authority: bool,
    pub eidos_live_authority: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub l2_l3_promotion_claim: bool,
    pub source_import_allowed: bool,
    pub benchmark_as_fit_proof: bool,
}

// UAS: uas:exotic-quant-command-envelope:ledger
// Plane: Controller + Verification
// Residency: metadata-only command preflight set.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CrashSafeCommandEnvelopeLedger {
    pub ledger_address: UasAddress,
    pub upstream_byte_envelope_gate_address: UasAddress,
    pub upstream_byte_envelope_gate_ref: String,
    pub cards: Vec<CrashSafeCommandEnvelopeCard>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub metadata_bytes: u64,
    pub command_envelope_preflight_compiled: bool,
    pub commands_unarmed: bool,
    pub dry_run_only: bool,
    pub runtime_deferred: bool,
    pub l1_l2_l3_separated: bool,
    pub product_promotion_blocked: bool,
    pub next_cursor: String,
}

// UAS: uas:exotic-quant-command-envelope:metrics
// Plane: Verification
// Residency: derived command-envelope counts and zero-byte counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CrashSafeCommandEnvelopeMetrics {
    pub gate_card_count: u64,
    pub mac_candidate_unarmed_count: u64,
    pub server_only_denied_count: u64,
    pub llama_cpp_gguf_cli_count: u64,
    pub transformers_quarantine_count: u64,
    pub args_vectorized_count: u64,
    pub shell_string_denied_count: u64,
    pub remote_download_denied_count: u64,
    pub hf_token_env_denied_count: u64,
    pub output_limit_bound_count: u64,
    pub timeout_bound_count: u64,
    pub cancellation_bound_count: u64,
    pub teardown_bound_count: u64,
    pub rollback_run_event_answer_packet_count: u64,
    pub forbidden_arg_count: u64,
    pub forbidden_env_count: u64,
    pub issue_failure_ref_count: u64,
    pub command_template_bytes_serialized_total: u64,
    pub command_execution_count_total: u64,
    pub stdout_bytes_captured_total: u64,
    pub stderr_bytes_captured_total: u64,
    pub token_bytes_captured_total: u64,
    pub model_bytes_loaded_total: u64,
    pub runtime_bytes_loaded_total: u64,
    pub provider_calls_made_total: u64,
    pub network_calls_made_total: u64,
    pub source_tree_bytes_read_total: u64,
    pub product_bytes_copied_total: u64,
    pub benchmark_runs_total: u64,
}

impl CrashSafeCommandEnvelopeLedger {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        upstream_byte_envelope_gate_address: UasAddress,
        upstream_byte_envelope_gate_ref: impl Into<String>,
        mut cards: Vec<CrashSafeCommandEnvelopeCard>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        promotion_tier: CompressedModelPromotionTier,
        metadata_bytes: u64,
        command_envelope_preflight_compiled: bool,
        commands_unarmed: bool,
        dry_run_only: bool,
        runtime_deferred: bool,
        l1_l2_l3_separated: bool,
        product_promotion_blocked: bool,
        next_cursor: impl Into<String>,
        created_at_ms: u64,
    ) -> Result<Self, CrashSafeCommandEnvelopeError> {
        cards.sort_by(|a, b| a.gate_id.cmp(&b.gate_id));
        let upstream_byte_envelope_gate_ref = upstream_byte_envelope_gate_ref.into();
        let next_cursor = next_cursor.into();
        validate_ledger(
            &upstream_byte_envelope_gate_address,
            &upstream_byte_envelope_gate_ref,
            &cards,
            &product_build,
            &pro_status,
            &promotion_tier,
            metadata_bytes,
            command_envelope_preflight_compiled,
            commands_unarmed,
            dry_run_only,
            runtime_deferred,
            l1_l2_l3_separated,
            product_promotion_blocked,
            &next_cursor,
        )?;
        let preimage = ledger_preimage(
            &upstream_byte_envelope_gate_address,
            &upstream_byte_envelope_gate_ref,
            &cards,
            metadata_bytes,
            command_envelope_preflight_compiled,
            commands_unarmed,
            &next_cursor,
        );
        let ledger_address = UasAddress::new(
            UasKind::Other(
                EXOTIC_QUANT_CRASH_SAFE_COMMAND_ENVELOPE_PREFLIGHT_GATE_CURSOR.to_string(),
            ),
            preimage.as_bytes(),
            created_at_ms,
        );
        Ok(Self {
            ledger_address,
            upstream_byte_envelope_gate_address,
            upstream_byte_envelope_gate_ref,
            cards,
            product_build,
            pro_status,
            promotion_tier,
            metadata_bytes,
            command_envelope_preflight_compiled,
            commands_unarmed,
            dry_run_only,
            runtime_deferred,
            l1_l2_l3_separated,
            product_promotion_blocked,
            next_cursor,
        })
    }

    pub fn metrics(&self) -> CrashSafeCommandEnvelopeMetrics {
        let mut metrics = CrashSafeCommandEnvelopeMetrics {
            gate_card_count: self.cards.len() as u64,
            mac_candidate_unarmed_count: 0,
            server_only_denied_count: 0,
            llama_cpp_gguf_cli_count: 0,
            transformers_quarantine_count: 0,
            args_vectorized_count: 0,
            shell_string_denied_count: 0,
            remote_download_denied_count: 0,
            hf_token_env_denied_count: 0,
            output_limit_bound_count: 0,
            timeout_bound_count: 0,
            cancellation_bound_count: 0,
            teardown_bound_count: 0,
            rollback_run_event_answer_packet_count: 0,
            forbidden_arg_count: 0,
            forbidden_env_count: 0,
            issue_failure_ref_count: 0,
            command_template_bytes_serialized_total: 0,
            command_execution_count_total: 0,
            stdout_bytes_captured_total: 0,
            stderr_bytes_captured_total: 0,
            token_bytes_captured_total: 0,
            model_bytes_loaded_total: 0,
            runtime_bytes_loaded_total: 0,
            provider_calls_made_total: 0,
            network_calls_made_total: 0,
            source_tree_bytes_read_total: 0,
            product_bytes_copied_total: 0,
            benchmark_runs_total: 0,
        };
        for card in &self.cards {
            if card.state == CrashSafeCommandEnvelopeState::MacCandidateUnarmedOwnerApprovalRequired
            {
                metrics.mac_candidate_unarmed_count += 1;
            }
            if card.state == CrashSafeCommandEnvelopeState::ServerOnlyCommandDenied {
                metrics.server_only_denied_count += 1;
            }
            if card.surface == CrashSafeCommandSurface::LlamaCppGgufCli {
                metrics.llama_cpp_gguf_cli_count += 1;
            }
            if card.surface == CrashSafeCommandSurface::TransformersPythonQuarantine {
                metrics.transformers_quarantine_count += 1;
            }
            if card.policy.args_vectorized {
                metrics.args_vectorized_count += 1;
            }
            if card.policy.shell_string_denied && !card.shell_string_present {
                metrics.shell_string_denied_count += 1;
            }
            if card.policy.remote_download_flags_denied && !card.remote_download_allowed {
                metrics.remote_download_denied_count += 1;
            }
            if card.policy.hf_token_env_denied && !card.hf_token_env_allowed {
                metrics.hf_token_env_denied_count += 1;
            }
            if card.policy.output_byte_limit_bound && !card.output_unbounded {
                metrics.output_limit_bound_count += 1;
            }
            if card.policy.timeout_bound && !card.timeout_missing {
                metrics.timeout_bound_count += 1;
            }
            if card.policy.cancellation_bound && !card.cancellation_missing {
                metrics.cancellation_bound_count += 1;
            }
            if card.policy.teardown_bound && !card.teardown_missing {
                metrics.teardown_bound_count += 1;
            }
            if card.rollback_required && card.run_event_log_required && card.answer_packet_required
            {
                metrics.rollback_run_event_answer_packet_count += 1;
            }
            metrics.forbidden_arg_count += card.forbidden_args.len() as u64;
            metrics.forbidden_env_count += card.forbidden_env.len() as u64;
            metrics.issue_failure_ref_count += card.issue_failure_refs.len() as u64;
            metrics.command_template_bytes_serialized_total +=
                card.byte_ledger.command_template_bytes_serialized;
            metrics.command_execution_count_total += card.byte_ledger.command_execution_count;
            metrics.stdout_bytes_captured_total += card.byte_ledger.stdout_bytes_captured;
            metrics.stderr_bytes_captured_total += card.byte_ledger.stderr_bytes_captured;
            metrics.token_bytes_captured_total += card.byte_ledger.token_bytes_captured;
            metrics.model_bytes_loaded_total += card.byte_ledger.model_bytes_loaded;
            metrics.runtime_bytes_loaded_total += card.byte_ledger.runtime_bytes_loaded;
            metrics.provider_calls_made_total += card.byte_ledger.provider_calls_made;
            metrics.network_calls_made_total += card.byte_ledger.network_calls_made;
            metrics.source_tree_bytes_read_total += card.byte_ledger.source_tree_bytes_read;
            metrics.product_bytes_copied_total += card.byte_ledger.product_bytes_copied;
            metrics.benchmark_runs_total += card.byte_ledger.benchmark_runs;
        }
        metrics
    }
}

// UAS: uas:exotic-quant-command-envelope:error
// Plane: Verification
// Residency: every error fails closed before owner-approved dry run.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CrashSafeCommandEnvelopeError {
    EmptyLedger,
    BadUpstreamByteEnvelopeRef,
    BadLedgerState,
    BadNextCursor,
    MetadataBudgetExceeded,
    DuplicateGateId(String),
    DuplicateModelId(String),
    DuplicateSourcePinCardId(String),
    MissingExpectedModel(&'static str),
    UnknownModelId(String),
    BadExpectedSurface(String),
    BadPolicy(String),
    BadArgv(String),
    BadForbiddenList(String),
    BadByteLedger(String),
    BadText(String),
    BadPrefix(String),
    RuntimeAuthority(String),
    ProductPromotion(String),
    HiddenAuthority(String),
    SourceContamination(String),
    MissingProofSurface(String),
}

impl fmt::Display for CrashSafeCommandEnvelopeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyLedger => write!(f, "crash-safe command-envelope ledger is empty"),
            Self::BadUpstreamByteEnvelopeRef => write!(f, "bad upstream byte-envelope ref"),
            Self::BadLedgerState => write!(f, "command-envelope ledger state is invalid"),
            Self::BadNextCursor => write!(f, "command-envelope ledger has bad cursor"),
            Self::MetadataBudgetExceeded => write!(f, "command-envelope metadata budget exceeded"),
            Self::DuplicateGateId(id) => write!(f, "duplicate gate id `{id}`"),
            Self::DuplicateModelId(id) => write!(f, "duplicate model id `{id}`"),
            Self::DuplicateSourcePinCardId(id) => write!(f, "duplicate source-pin id `{id}`"),
            Self::MissingExpectedModel(id) => write!(f, "missing expected model `{id}`"),
            Self::UnknownModelId(id) => write!(f, "unknown model `{id}`"),
            Self::BadExpectedSurface(id) => write!(f, "bad command surface on `{id}`"),
            Self::BadPolicy(id) => write!(f, "bad command policy on `{id}`"),
            Self::BadArgv(id) => write!(f, "bad argv template on `{id}`"),
            Self::BadForbiddenList(id) => write!(f, "bad forbidden list on `{id}`"),
            Self::BadByteLedger(id) => write!(f, "bad byte ledger on `{id}`"),
            Self::BadText(id) => write!(f, "bad text field on `{id}`"),
            Self::BadPrefix(id) => write!(f, "bad proof-ref prefix on `{id}`"),
            Self::RuntimeAuthority(id) => write!(f, "runtime authority attempted by `{id}`"),
            Self::ProductPromotion(id) => write!(f, "product promotion attempted by `{id}`"),
            Self::HiddenAuthority(id) => write!(f, "hidden authority attempted by `{id}`"),
            Self::SourceContamination(id) => write!(f, "source contamination attempted by `{id}`"),
            Self::MissingProofSurface(id) => write!(f, "missing proof surface on `{id}`"),
        }
    }
}

impl std::error::Error for CrashSafeCommandEnvelopeError {}

#[allow(clippy::too_many_arguments)]
fn validate_ledger(
    upstream_byte_envelope_gate_address: &UasAddress,
    upstream_byte_envelope_gate_ref: &str,
    cards: &[CrashSafeCommandEnvelopeCard],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    promotion_tier: &CompressedModelPromotionTier,
    metadata_bytes: u64,
    command_envelope_preflight_compiled: bool,
    commands_unarmed: bool,
    dry_run_only: bool,
    runtime_deferred: bool,
    l1_l2_l3_separated: bool,
    product_promotion_blocked: bool,
    next_cursor: &str,
) -> Result<(), CrashSafeCommandEnvelopeError> {
    if upstream_byte_envelope_gate_address
        .to_string()
        .trim()
        .is_empty()
        || !upstream_byte_envelope_gate_ref.starts_with(UPSTREAM_BYTE_ENVELOPE_PREFIX)
    {
        return Err(CrashSafeCommandEnvelopeError::BadUpstreamByteEnvelopeRef);
    }
    if cards.is_empty() {
        return Err(CrashSafeCommandEnvelopeError::EmptyLedger);
    }
    if metadata_bytes == 0 || metadata_bytes > MAX_LEDGER_METADATA_BYTES {
        return Err(CrashSafeCommandEnvelopeError::MetadataBudgetExceeded);
    }
    if product_build != &ProductBuild::Pro
        || pro_status != &ProStatus::ResearchCandidate
        || promotion_tier != &CompressedModelPromotionTier::T1L1Metadata
        || !command_envelope_preflight_compiled
        || !commands_unarmed
        || !dry_run_only
        || !runtime_deferred
        || !l1_l2_l3_separated
        || !product_promotion_blocked
    {
        return Err(CrashSafeCommandEnvelopeError::BadLedgerState);
    }
    if next_cursor != EXOTIC_QUANT_CRASH_SAFE_COMMAND_ENVELOPE_PREFLIGHT_GATE_NEXT_CURSOR {
        return Err(CrashSafeCommandEnvelopeError::BadNextCursor);
    }

    let mut gate_ids = HashSet::new();
    let mut model_ids = HashSet::new();
    let mut source_pin_ids = HashSet::new();
    for card in cards {
        validate_card(card)?;
        if !gate_ids.insert(card.gate_id.clone()) {
            return Err(CrashSafeCommandEnvelopeError::DuplicateGateId(
                card.gate_id.clone(),
            ));
        }
        if !model_ids.insert(card.model_id.clone()) {
            return Err(CrashSafeCommandEnvelopeError::DuplicateModelId(
                card.model_id.clone(),
            ));
        }
        if !source_pin_ids.insert(card.source_pin_card_id.clone()) {
            return Err(CrashSafeCommandEnvelopeError::DuplicateSourcePinCardId(
                card.source_pin_card_id.clone(),
            ));
        }
    }
    for expected in expected_owner_path_manifest_model_ids() {
        if !model_ids.contains(expected) {
            return Err(CrashSafeCommandEnvelopeError::MissingExpectedModel(
                expected,
            ));
        }
    }
    Ok(())
}

fn validate_card(card: &CrashSafeCommandEnvelopeCard) -> Result<(), CrashSafeCommandEnvelopeError> {
    for text in [
        &card.gate_id,
        &card.model_id,
        &card.source_pin_card_id,
        &card.selected_artifact_path,
        &card.user_visible_summary,
    ] {
        validate_text(text, &card.gate_id)?;
    }
    if card.user_visible_summary.len() < MIN_VISIBLE_SUMMARY_BYTES {
        return Err(CrashSafeCommandEnvelopeError::MissingProofSurface(
            card.gate_id.clone(),
        ));
    }
    if !expected_owner_path_manifest_model_ids()
        .iter()
        .any(|expected| expected == &card.model_id)
    {
        return Err(CrashSafeCommandEnvelopeError::UnknownModelId(
            card.model_id.clone(),
        ));
    }
    validate_refs(card)?;
    validate_expected_surface(card)?;
    validate_policy(card)?;
    validate_argv(card)?;
    validate_byte_ledger(card)?;
    validate_boundaries(card)?;
    validate_proof_surfaces(card)?;
    Ok(())
}

fn validate_expected_surface(
    card: &CrashSafeCommandEnvelopeCard,
) -> Result<(), CrashSafeCommandEnvelopeError> {
    let mac_candidate = is_mac_candidate_source_pin(&card.source_pin_card_id);
    if mac_candidate {
        if card.state != CrashSafeCommandEnvelopeState::MacCandidateUnarmedOwnerApprovalRequired
            || card.surface == CrashSafeCommandSurface::ServerOnlyDenied
            || !card.policy.owner_approval_required
            || !card.dry_run_serialized
            || card.argv_template.is_empty()
        {
            return Err(CrashSafeCommandEnvelopeError::BadExpectedSurface(
                card.gate_id.clone(),
            ));
        }
    } else if card.state != CrashSafeCommandEnvelopeState::ServerOnlyCommandDenied
        || card.surface != CrashSafeCommandSurface::ServerOnlyDenied
        || card.policy.owner_approval_required
        || !card.argv_template.is_empty()
    {
        return Err(CrashSafeCommandEnvelopeError::BadExpectedSurface(
            card.gate_id.clone(),
        ));
    }
    if !card.byte_envelope_current_hardware_denied
        || !card.command_envelope_visible
        || card.command_armed
        || card.command_executable
        || card.owner_approval_present
        || card.runtime_probe_allowed
        || !card.runtime_deferred
        || card.local_artifact_verified
    {
        return Err(CrashSafeCommandEnvelopeError::RuntimeAuthority(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_policy(
    card: &CrashSafeCommandEnvelopeCard,
) -> Result<(), CrashSafeCommandEnvelopeError> {
    if !card.policy.proves_crash_safe_preflight()
        || card.remote_download_allowed
        || card.hf_token_env_allowed
        || card.network_allowed
        || card.server_sidecar_allowed
        || card.mmap_fit_claim
        || card.mlock_fit_claim
        || card.output_unbounded
        || card.timeout_missing
        || card.cancellation_missing
        || card.teardown_missing
    {
        return Err(CrashSafeCommandEnvelopeError::BadPolicy(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_argv(card: &CrashSafeCommandEnvelopeCard) -> Result<(), CrashSafeCommandEnvelopeError> {
    let mac_candidate = is_mac_candidate_source_pin(&card.source_pin_card_id);
    if mac_candidate {
        if card.argv_template.len() < 4
            || !card
                .argv_template
                .iter()
                .any(|arg| arg == "<OWNER_APPROVED_MODEL_PATH>")
        {
            return Err(CrashSafeCommandEnvelopeError::BadArgv(card.gate_id.clone()));
        }
        if card.surface == CrashSafeCommandSurface::LlamaCppGgufCli {
            for required in [
                "--offline",
                "--predict",
                "1",
                "--ctx-size",
                "512",
                "--simple-io",
                "--no-display-prompt",
                "--no-mmap",
                "--log-disable",
            ] {
                if !card.argv_template.iter().any(|arg| arg == required) {
                    return Err(CrashSafeCommandEnvelopeError::BadArgv(card.gate_id.clone()));
                }
            }
        }
    }
    if card.shell_string_present
        || card
            .argv_template
            .iter()
            .any(|arg| arg.contains('\n') || arg.contains('\0'))
        || card
            .argv_template
            .iter()
            .any(|arg| FORBIDDEN_ARGS.contains(&arg.as_str()))
    {
        return Err(CrashSafeCommandEnvelopeError::BadArgv(card.gate_id.clone()));
    }
    if !FORBIDDEN_ARGS
        .iter()
        .all(|arg| card.forbidden_args.iter().any(|candidate| candidate == arg))
        || !FORBIDDEN_ENV
            .iter()
            .all(|env| card.forbidden_env.iter().any(|candidate| candidate == env))
    {
        return Err(CrashSafeCommandEnvelopeError::BadForbiddenList(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_refs(card: &CrashSafeCommandEnvelopeCard) -> Result<(), CrashSafeCommandEnvelopeError> {
    let expected_refs = [
        (
            &card.proof_refs.upstream_byte_envelope_ref,
            UPSTREAM_BYTE_ENVELOPE_PREFIX,
        ),
        (&card.proof_refs.source_pin_card_ref, SOURCE_PIN_CARD_PREFIX),
        (&card.proof_refs.model_revision_ref, MODEL_REVISION_PREFIX),
        (&card.proof_refs.selected_file_ref, SELECTED_FILE_PREFIX),
        (&card.proof_refs.byte_envelope_ref, BYTE_ENVELOPE_PREFIX),
        (
            &card.proof_refs.command_envelope_ref,
            COMMAND_ENVELOPE_PREFIX,
        ),
        (&card.proof_refs.download_policy_ref, DOWNLOAD_POLICY_PREFIX),
        (&card.proof_refs.env_policy_ref, ENV_POLICY_PREFIX),
        (&card.proof_refs.output_policy_ref, OUTPUT_POLICY_PREFIX),
        (&card.proof_refs.timeout_policy_ref, TIMEOUT_POLICY_PREFIX),
        (&card.proof_refs.cancellation_ref, CANCELLATION_PREFIX),
        (&card.proof_refs.teardown_ref, TEARDOWN_PREFIX),
        (&card.proof_refs.rollback_ref, ROLLBACK_PREFIX),
        (&card.proof_refs.run_event_log_ref, RUN_EVENT_LOG_PREFIX),
        (&card.proof_refs.answer_packet_ref, ANSWER_PACKET_PREFIX),
        (&card.proof_refs.abstention_ref, ABSTENTION_PREFIX),
        (&card.proof_refs.sovereign_gate_ref, SOVEREIGN_GATE_PREFIX),
        (
            &card.proof_refs.compatibility_fence_ref,
            COMPATIBILITY_FENCE_PREFIX,
        ),
    ];
    for (value, prefix) in expected_refs {
        if !value.starts_with(prefix) {
            return Err(CrashSafeCommandEnvelopeError::BadPrefix(
                card.gate_id.clone(),
            ));
        }
    }
    for value in [
        &card.proof_refs.source_pin_card_ref,
        &card.proof_refs.model_revision_ref,
        &card.proof_refs.selected_file_ref,
        &card.proof_refs.byte_envelope_ref,
        &card.proof_refs.command_envelope_ref,
        &card.proof_refs.download_policy_ref,
        &card.proof_refs.env_policy_ref,
        &card.proof_refs.output_policy_ref,
        &card.proof_refs.timeout_policy_ref,
        &card.proof_refs.cancellation_ref,
        &card.proof_refs.teardown_ref,
        &card.proof_refs.rollback_ref,
        &card.proof_refs.run_event_log_ref,
        &card.proof_refs.answer_packet_ref,
        &card.proof_refs.abstention_ref,
        &card.proof_refs.sovereign_gate_ref,
        &card.proof_refs.compatibility_fence_ref,
    ] {
        if !value.ends_with(&card.source_pin_card_id) {
            return Err(CrashSafeCommandEnvelopeError::BadPrefix(
                card.gate_id.clone(),
            ));
        }
    }
    for value in &card.issue_failure_refs {
        if !(value.starts_with("https://github.com/") || value.starts_with("source:")) {
            return Err(CrashSafeCommandEnvelopeError::BadPrefix(
                card.gate_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_byte_ledger(
    card: &CrashSafeCommandEnvelopeCard,
) -> Result<(), CrashSafeCommandEnvelopeError> {
    let ledger = &card.byte_ledger;
    if ledger.metadata_bytes_read == 0
        || ledger.metadata_bytes_read > MAX_CARD_METADATA_BYTES
        || ledger.command_template_bytes_serialized > MAX_CARD_METADATA_BYTES
    {
        return Err(CrashSafeCommandEnvelopeError::BadByteLedger(
            card.gate_id.clone(),
        ));
    }
    if is_mac_candidate_source_pin(&card.source_pin_card_id)
        && ledger.command_template_bytes_serialized == 0
    {
        return Err(CrashSafeCommandEnvelopeError::BadByteLedger(
            card.gate_id.clone(),
        ));
    }
    if ledger.owner_manifest_bytes_read != 0
        || ledger.owner_path_bytes_read != 0
        || ledger.local_file_bytes_read != 0
        || ledger.command_execution_count != 0
        || ledger.stdout_bytes_captured != 0
        || ledger.stderr_bytes_captured != 0
        || ledger.token_bytes_captured != 0
        || ledger.model_bytes_loaded != 0
        || ledger.runtime_bytes_loaded != 0
        || ledger.provider_calls_made != 0
        || ledger.network_calls_made != 0
        || ledger.source_tree_bytes_read != 0
        || ledger.product_bytes_copied != 0
        || ledger.benchmark_runs != 0
    {
        return Err(CrashSafeCommandEnvelopeError::BadByteLedger(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_boundaries(
    card: &CrashSafeCommandEnvelopeCard,
) -> Result<(), CrashSafeCommandEnvelopeError> {
    if card.product_build != ProductBuild::Pro
        || card.pro_status != ProStatus::ResearchCandidate
        || card.promotion_tier != CompressedModelPromotionTier::T1L1Metadata
        || card.mas_allowed
        || card.product_route_enabled
        || card.app_default_claim
        || card.product_winner_claim
        || card.l2_l3_promotion_claim
    {
        return Err(CrashSafeCommandEnvelopeError::ProductPromotion(
            card.gate_id.clone(),
        ));
    }
    if card.route_policy_mutated
        || card.hidden_route_authority
        || card.hidden_cloud_fallback
        || card.patternboost_live_authority
        || card.lattice_live_authority
        || card.eidos_live_authority
    {
        return Err(CrashSafeCommandEnvelopeError::HiddenAuthority(
            card.gate_id.clone(),
        ));
    }
    if card.live_dense_70b_claim
        || card.ssd_as_ram_claim
        || card.source_import_allowed
        || card.benchmark_as_fit_proof
    {
        return Err(CrashSafeCommandEnvelopeError::SourceContamination(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_proof_surfaces(
    card: &CrashSafeCommandEnvelopeCard,
) -> Result<(), CrashSafeCommandEnvelopeError> {
    if !card.rollback_required
        || !card.run_event_log_required
        || !card.answer_packet_required
        || !card.abstention_required
    {
        return Err(CrashSafeCommandEnvelopeError::MissingProofSurface(
            card.gate_id.clone(),
        ));
    }
    Ok(())
}

fn validate_text(value: &str, gate_id: &str) -> Result<(), CrashSafeCommandEnvelopeError> {
    if value.trim().is_empty() || value.contains('\0') || value.chars().any(char::is_control) {
        return Err(CrashSafeCommandEnvelopeError::BadText(gate_id.to_string()));
    }
    Ok(())
}

fn ledger_preimage(
    upstream_byte_envelope_gate_address: &UasAddress,
    upstream_byte_envelope_gate_ref: &str,
    cards: &[CrashSafeCommandEnvelopeCard],
    metadata_bytes: u64,
    command_envelope_preflight_compiled: bool,
    commands_unarmed: bool,
    next_cursor: &str,
) -> String {
    let mut preimage = format!(
        "{upstream_byte_envelope_gate_address}\n{upstream_byte_envelope_gate_ref}\n{metadata_bytes}\n{command_envelope_preflight_compiled}\n{commands_unarmed}\n{next_cursor}\n"
    );
    for card in cards {
        preimage.push_str(&card.gate_id);
        preimage.push('|');
        preimage.push_str(&card.model_id);
        preimage.push('|');
        preimage.push_str(&card.source_pin_card_id);
        preimage.push('|');
        preimage.push_str(&format!(
            "{:?}|{:?}|{}\n",
            card.surface,
            card.state,
            card.argv_template.len()
        ));
    }
    preimage
}

pub fn canonical_crash_safe_command_envelope_cards(
    upstream_byte_envelope_ref: &str,
) -> Vec<CrashSafeCommandEnvelopeCard> {
    canonical_owner_path_byte_envelope_preflight_cards(upstream_byte_envelope_ref)
        .into_iter()
        .map(|card| canonical_card_from_byte_envelope(&card, upstream_byte_envelope_ref))
        .collect()
}

fn canonical_card_from_byte_envelope(
    byte_card: &OwnerPathByteEnvelopePreflightCard,
    upstream_byte_envelope_ref: &str,
) -> CrashSafeCommandEnvelopeCard {
    let source_pin = &byte_card.source_pin_card_id;
    let mac_candidate = is_mac_candidate_source_pin(source_pin);
    let surface = command_surface_for_source_pin(source_pin);
    let argv_template = argv_template_for_surface(surface);
    let template_bytes = argv_template
        .iter()
        .map(|arg| arg.len() as u64)
        .sum::<u64>();
    CrashSafeCommandEnvelopeCard {
        gate_id: format!("{source_pin}_crash_safe_command_envelope_preflight"),
        model_id: byte_card.model_id.clone(),
        source_pin_card_id: source_pin.clone(),
        selected_artifact_path: byte_card.selected_artifact_path.clone(),
        hardware_tier: byte_card.hardware_tier,
        runtime_lane: byte_card.runtime_lane,
        surface,
        state: if mac_candidate {
            CrashSafeCommandEnvelopeState::MacCandidateUnarmedOwnerApprovalRequired
        } else {
            CrashSafeCommandEnvelopeState::ServerOnlyCommandDenied
        },
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
        argv_template,
        forbidden_args: FORBIDDEN_ARGS
            .iter()
            .map(|value| (*value).to_string())
            .collect(),
        forbidden_env: FORBIDDEN_ENV
            .iter()
            .map(|value| (*value).to_string())
            .collect(),
        issue_failure_refs: issue_refs_for_surface(surface),
        policy: if mac_candidate {
            CrashSafeCommandPolicy::unarmed_mac_candidate()
        } else {
            CrashSafeCommandPolicy::server_denied()
        },
        byte_ledger: CrashSafeCommandByteLedger::metadata_only(64_000, template_bytes),
        proof_refs: CrashSafeCommandProofRefs {
            upstream_byte_envelope_ref: upstream_byte_envelope_ref.to_string(),
            source_pin_card_ref: format!("{SOURCE_PIN_CARD_PREFIX}{source_pin}"),
            model_revision_ref: format!("{MODEL_REVISION_PREFIX}{source_pin}"),
            selected_file_ref: format!("{SELECTED_FILE_PREFIX}{source_pin}"),
            byte_envelope_ref: format!("{BYTE_ENVELOPE_PREFIX}{source_pin}"),
            command_envelope_ref: format!("{COMMAND_ENVELOPE_PREFIX}{source_pin}"),
            download_policy_ref: format!("{DOWNLOAD_POLICY_PREFIX}{source_pin}"),
            env_policy_ref: format!("{ENV_POLICY_PREFIX}{source_pin}"),
            output_policy_ref: format!("{OUTPUT_POLICY_PREFIX}{source_pin}"),
            timeout_policy_ref: format!("{TIMEOUT_POLICY_PREFIX}{source_pin}"),
            cancellation_ref: format!("{CANCELLATION_PREFIX}{source_pin}"),
            teardown_ref: format!("{TEARDOWN_PREFIX}{source_pin}"),
            rollback_ref: format!("{ROLLBACK_PREFIX}{source_pin}"),
            run_event_log_ref: format!("{RUN_EVENT_LOG_PREFIX}{source_pin}"),
            answer_packet_ref: format!("{ANSWER_PACKET_PREFIX}{source_pin}"),
            abstention_ref: format!("{ABSTENTION_PREFIX}{source_pin}"),
            sovereign_gate_ref: format!("{SOVEREIGN_GATE_PREFIX}{source_pin}"),
            compatibility_fence_ref: format!("{COMPATIBILITY_FENCE_PREFIX}{source_pin}"),
        },
        user_visible_summary: format!(
            "Crash-safe command-envelope preflight for {} serializes only an inert vector command/API plan after byte-envelope denial, blocks remote downloads, provider tokens, server sidecars, mmap/mlock fit claims, unbounded output, and missing timeout/cancellation/teardown, requires rollback, RunEventLog, AnswerPacket, abstention, and owner-approved dry-run proof before any runtime. It advances L1 metadata only.",
            byte_card.model_id
        ),
        byte_envelope_current_hardware_denied: byte_card.current_m2pro_16gb_denied,
        command_envelope_visible: true,
        command_armed: false,
        command_executable: false,
        dry_run_serialized: mac_candidate,
        owner_approval_present: false,
        runtime_probe_allowed: false,
        runtime_deferred: true,
        local_artifact_verified: false,
        shell_string_present: false,
        remote_download_allowed: false,
        hf_token_env_allowed: false,
        network_allowed: false,
        server_sidecar_allowed: false,
        mmap_fit_claim: false,
        mlock_fit_claim: false,
        output_unbounded: false,
        timeout_missing: false,
        cancellation_missing: false,
        teardown_missing: false,
        rollback_required: true,
        run_event_log_required: true,
        answer_packet_required: true,
        abstention_required: true,
        mas_allowed: false,
        product_route_enabled: false,
        app_default_claim: false,
        product_winner_claim: false,
        route_policy_mutated: false,
        hidden_route_authority: false,
        hidden_cloud_fallback: false,
        patternboost_live_authority: false,
        lattice_live_authority: false,
        eidos_live_authority: false,
        live_dense_70b_claim: false,
        ssd_as_ram_claim: false,
        l2_l3_promotion_claim: false,
        source_import_allowed: false,
        benchmark_as_fit_proof: false,
    }
}

fn command_surface_for_source_pin(source_pin: &str) -> CrashSafeCommandSurface {
    match source_pin {
        "qwopus27b_tq3_4s" | "qwopus_moe_35b_a3b_apex_mini" => {
            CrashSafeCommandSurface::LlamaCppGgufCli
        }
        "qwopus27b_hlwq_q5" => CrashSafeCommandSurface::TransformersPythonQuarantine,
        _ => CrashSafeCommandSurface::ServerOnlyDenied,
    }
}

fn argv_template_for_surface(surface: CrashSafeCommandSurface) -> Vec<String> {
    match surface {
        CrashSafeCommandSurface::LlamaCppGgufCli => [
            "llama-cli",
            "--offline",
            "--model",
            "<OWNER_APPROVED_MODEL_PATH>",
            "--prompt",
            "<SYNTHETIC_NON_USER_PROMPT>",
            "--predict",
            "1",
            "--ctx-size",
            "512",
            "--batch-size",
            "32",
            "--ubatch-size",
            "32",
            "--temp",
            "0",
            "--seed",
            "0",
            "--no-conversation",
            "--single-turn",
            "--simple-io",
            "--no-display-prompt",
            "--no-mmap",
            "--log-disable",
        ]
        .iter()
        .map(|value| (*value).to_string())
        .collect(),
        CrashSafeCommandSurface::TransformersPythonQuarantine => [
            "python",
            "-m",
            "epistemos_quarantine.transformers_one_token_probe",
            "--local-files-only",
            "--model",
            "<OWNER_APPROVED_MODEL_PATH>",
            "--prompt-hash",
            "<SYNTHETIC_NON_USER_PROMPT_SHA256>",
            "--max-new-tokens",
            "1",
            "--no-trust-remote-code",
            "--redact-output",
        ]
        .iter()
        .map(|value| (*value).to_string())
        .collect(),
        CrashSafeCommandSurface::ServerOnlyDenied => Vec::new(),
    }
}

fn issue_refs_for_surface(surface: CrashSafeCommandSurface) -> Vec<String> {
    let mut refs = vec![
        "source:docs/fusion/LARGE_MODEL_KEYWORD_RESEARCH_ATLAS_2026_06_07.md#pass85".to_string(),
        "source:docs/fusion/DEEP_RESEARCH_BREAKTHROUGH_SYNTHESIS_2026_06_06.md#pass86".to_string(),
    ];
    match surface {
        CrashSafeCommandSurface::LlamaCppGgufCli => {
            refs.extend([
                "https://github.com/ggml-org/llama.cpp/issues/23855".to_string(),
                "https://github.com/ggml-org/llama.cpp/issues/24139".to_string(),
                "https://github.com/ggml-org/llama.cpp/issues/23072".to_string(),
            ]);
        }
        CrashSafeCommandSurface::TransformersPythonQuarantine => {
            refs.extend([
                "https://github.com/huggingface/transformers".to_string(),
                "https://github.com/ml-explore/mlx-lm".to_string(),
            ]);
        }
        CrashSafeCommandSurface::ServerOnlyDenied => {
            refs.extend([
                "https://github.com/google-ai-edge/LiteRT-LM/issues/2407".to_string(),
                "https://github.com/ml-explore/mlx-swift-lm/issues/177".to_string(),
            ]);
        }
    }
    refs
}

fn is_mac_candidate_source_pin(source_pin: &str) -> bool {
    matches!(
        source_pin,
        "qwopus27b_tq3_4s" | "qwopus27b_hlwq_q5" | "qwopus_moe_35b_a3b_apex_mini"
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    const UPSTREAM_REF: &str = "artifact:falsifiers/exotic_quant_owner_path_byte_envelope_preflight_gate/result.json#F-ExoticQuantOwnerPathByteEnvelopePreflightGate";

    fn ledger_from_cards(
        cards: Vec<CrashSafeCommandEnvelopeCard>,
    ) -> Result<CrashSafeCommandEnvelopeLedger, CrashSafeCommandEnvelopeError> {
        CrashSafeCommandEnvelopeLedger::new(
            UasAddress::new(
                UasKind::Other("upstream_byte_envelope_gate".to_string()),
                b"owner_path_byte_envelope_preflight",
                1_779_551_000_000,
            ),
            UPSTREAM_REF,
            cards,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            CompressedModelPromotionTier::T1L1Metadata,
            360_000,
            true,
            true,
            true,
            true,
            true,
            true,
            EXOTIC_QUANT_CRASH_SAFE_COMMAND_ENVELOPE_PREFLIGHT_GATE_NEXT_CURSOR,
            1_779_551_000_000,
        )
    }

    #[test]
    fn accepts_unarmed_command_envelopes_without_runtime_bytes() {
        let cards = canonical_crash_safe_command_envelope_cards(UPSTREAM_REF);
        let ledger = ledger_from_cards(cards).expect("canonical ledger should validate");
        let metrics = ledger.metrics();
        assert_eq!(metrics.gate_card_count, 5);
        assert_eq!(metrics.mac_candidate_unarmed_count, 3);
        assert_eq!(metrics.server_only_denied_count, 2);
        assert_eq!(metrics.llama_cpp_gguf_cli_count, 2);
        assert_eq!(metrics.transformers_quarantine_count, 1);
        assert_eq!(metrics.command_execution_count_total, 0);
        assert_eq!(metrics.model_bytes_loaded_total, 0);
        assert_eq!(metrics.runtime_bytes_loaded_total, 0);
        assert_eq!(
            ledger.next_cursor,
            EXOTIC_QUANT_CRASH_SAFE_COMMAND_ENVELOPE_PREFLIGHT_GATE_NEXT_CURSOR
        );
    }

    #[test]
    fn rejects_shell_or_remote_download_authority() {
        let mut cards = canonical_crash_safe_command_envelope_cards(UPSTREAM_REF);
        cards[0].shell_string_present = true;
        assert!(matches!(
            ledger_from_cards(cards),
            Err(CrashSafeCommandEnvelopeError::BadArgv(_))
                | Err(CrashSafeCommandEnvelopeError::BadPolicy(_))
        ));

        let mut cards = canonical_crash_safe_command_envelope_cards(UPSTREAM_REF);
        cards[0].remote_download_allowed = true;
        assert!(matches!(
            ledger_from_cards(cards),
            Err(CrashSafeCommandEnvelopeError::BadPolicy(_))
        ));
    }

    #[test]
    fn rejects_command_execution_and_output_capture() {
        let mut cards = canonical_crash_safe_command_envelope_cards(UPSTREAM_REF);
        cards[0].command_armed = true;
        assert!(matches!(
            ledger_from_cards(cards),
            Err(CrashSafeCommandEnvelopeError::RuntimeAuthority(_))
        ));

        let mut cards = canonical_crash_safe_command_envelope_cards(UPSTREAM_REF);
        cards[0].byte_ledger.stdout_bytes_captured = 1;
        assert!(matches!(
            ledger_from_cards(cards),
            Err(CrashSafeCommandEnvelopeError::BadByteLedger(_))
        ));
    }

    #[test]
    fn deterministic_address_after_sorting() {
        let cards = canonical_crash_safe_command_envelope_cards(UPSTREAM_REF);
        let mut reversed = cards.clone();
        reversed.reverse();
        let first = ledger_from_cards(cards).expect("first ledger");
        let second = ledger_from_cards(reversed).expect("second ledger");
        assert_eq!(first.ledger_address, second.ledger_address);
    }
}
