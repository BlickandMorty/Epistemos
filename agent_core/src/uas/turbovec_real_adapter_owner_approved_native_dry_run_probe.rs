//! TurboVec real-adapter owner-approved native dry-run probe.
//!
//! This primitive prepares the future owner-approved native dry run without
//! executing it. It records visible command cards, approval state, cleanup and
//! rollback obligations, and byte budgets while proving owner approval is still
//! pending and every build/link/runtime/product path remains unarmed.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild, TurboVecIndexOrgan, UasAddress, UasKind};

pub const TURBOVEC_REAL_ADAPTER_OWNER_APPROVED_NATIVE_DRY_RUN_CURSOR: &str =
    "turbovec_quarantine_real_adapter_owner_approved_native_dry_run_probe";
pub const TURBOVEC_REAL_ADAPTER_OWNER_APPROVED_NATIVE_DRY_RUN_NEXT_CURSOR: &str =
    "turbovec_quarantine_real_adapter_native_dry_run_execution_probe";

const UPSTREAM_WITNESS_REF: &str =
    "artifact:turbovec_real_adapter_native_link_absence_preflight_probe:result";
const UPSTREAM_ADDRESS_PREFIX: &str = "turbovec_real_adapter_native_link_absence_preflight_probe:";
const OWNER_APPROVAL_PREFIX: &str = "owner_approval:pending:turbovec-native-dry-run:";
const COMMAND_CARD_PREFIX: &str = "command_card:turbovec-native-dry-run:";
const QUARANTINE_PATH_PREFIX: &str = "quarantine_path:turbovec-native-dry-run:";
const NATIVE_LINK_REF_PREFIX: &str = "native_link:turbovec-preflight:";
const ROLLBACK_REF_PREFIX: &str = "rollback:turbovec-native-dry-run:";
const RUN_EVENT_LOG_REF_PREFIX: &str = "run_event_log:turbovec-native-dry-run:";
const ANSWER_PACKET_REF_PREFIX: &str = "answer_packet:turbovec-native-dry-run:";
const COMPATIBILITY_REF_PREFIX: &str = "compat:turbovec-native-dry-run:";
const CLEANUP_REF_PREFIX: &str = "cleanup:turbovec-native-dry-run:";
const PINNED_REVISION: &str = "efe29a184986cbf562a9847c2ac52a2990bfaca2";
const SOURCE_URL: &str = "https://github.com/RyanCodrai/turbovec";
const MAX_METADATA_BYTES: u64 = 1024 * 1024;
const MIN_COMMAND_CARDS: usize = 8;
const MIN_VISIBLE_SUMMARY_BYTES: usize = 240;

// UAS: uas:turbovec-native-dry-run:approval-status
// Plane: Controller + Verification.
// Residency: pending approval only; execution belongs to a later witness.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecNativeDryRunApprovalStatus {
    PendingOwnerApproval,
    OwnerApprovedForSeparateExecutionWitness,
    Blocked,
}

// UAS: uas:turbovec-native-dry-run:tier
// Plane: Verification.
// Residency: T1/L1 proof only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecNativeDryRunTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:turbovec-native-dry-run:command-kind
// Plane: Controller + Verification.
// Residency: command-card class for future owner-approved dry run.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecNativeDryRunCommandKind {
    CargoMetadataTemplate,
    CargoCheckTemplate,
    BuildScriptAudit,
    TargetBlasAudit,
    PythonExtensionAudit,
    ProductGraphRecheck,
    CleanupLease,
    AnswerPacketReview,
}

// UAS: uas:turbovec-native-dry-run:command-card
// Plane: Controller + Verification.
// Residency: visible unarmed command envelope; no command is executed here.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecNativeDryRunCommandCard {
    pub card_id: String,
    pub kind: TurboVecNativeDryRunCommandKind,
    pub command_template: String,
    pub command_card_ref: String,
    pub quarantine_path_ref: String,
    pub native_link_ref: String,
    pub owner_approval_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
    pub cleanup_ref: String,
    pub visible_summary: String,
    pub command_visible: bool,
    pub owner_approval_required: bool,
    pub owner_approval_granted: bool,
    pub command_armed: bool,
    pub command_executed: bool,
    pub build_script_execution_allowed: bool,
    pub cargo_build_allowed: bool,
    pub linker_allowed: bool,
    pub dynamic_library_load_allowed: bool,
    pub python_extension_build_allowed: bool,
    pub product_dependency_allowed: bool,
    pub product_route_mutation_allowed: bool,
    pub benchmark_authority_allowed: bool,
    pub cleanup_required: bool,
}

impl TurboVecNativeDryRunCommandCard {
    pub fn is_pending_and_unarmed(&self) -> bool {
        !self.card_id.trim().is_empty()
            && !self.command_template.trim().is_empty()
            && !self.command_template.contains("sudo")
            && !self.command_template.contains("rm -rf")
            && self.command_card_ref.starts_with(COMMAND_CARD_PREFIX)
            && self.quarantine_path_ref.starts_with(QUARANTINE_PATH_PREFIX)
            && self.native_link_ref.starts_with(NATIVE_LINK_REF_PREFIX)
            && self.owner_approval_ref.starts_with(OWNER_APPROVAL_PREFIX)
            && self.rollback_ref.starts_with(ROLLBACK_REF_PREFIX)
            && self.run_event_log_ref.starts_with(RUN_EVENT_LOG_REF_PREFIX)
            && self.answer_packet_ref.starts_with(ANSWER_PACKET_REF_PREFIX)
            && self
                .compatibility_fence_ref
                .starts_with(COMPATIBILITY_REF_PREFIX)
            && self.cleanup_ref.starts_with(CLEANUP_REF_PREFIX)
            && self.visible_summary.len() >= MIN_VISIBLE_SUMMARY_BYTES
            && self.visible_summary.contains("owner approval")
            && self.visible_summary.contains("unarmed")
            && self.command_visible
            && self.owner_approval_required
            && !self.owner_approval_granted
            && !self.command_armed
            && !self.command_executed
            && !self.build_script_execution_allowed
            && !self.cargo_build_allowed
            && !self.linker_allowed
            && !self.dynamic_library_load_allowed
            && !self.python_extension_build_allowed
            && !self.product_dependency_allowed
            && !self.product_route_mutation_allowed
            && !self.benchmark_authority_allowed
            && self.cleanup_required
    }
}

// UAS: uas:turbovec-native-dry-run:policy
// Plane: Controller + Verification.
// Residency: fail-closed policy before any dry-run execution.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecNativeDryRunPolicy {
    pub upstream_native_link_preflight_required: bool,
    pub owner_approval_required: bool,
    pub owner_approval_must_be_pending: bool,
    pub command_cards_required: bool,
    pub command_unarmed_required: bool,
    pub execution_denied: bool,
    pub build_script_execution_denied: bool,
    pub cargo_build_denied: bool,
    pub linker_invocation_denied: bool,
    pub dynamic_library_load_denied: bool,
    pub python_extension_build_denied: bool,
    pub product_dependency_denied: bool,
    pub route_mutation_denied: bool,
    pub benchmark_authority_denied: bool,
    pub cleanup_required: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub compatibility_fence_required: bool,
    pub no_model_runtime_provider_bytes: bool,
    pub no_product_capability_promotion: bool,
}

impl TurboVecNativeDryRunPolicy {
    pub fn fail_closed() -> Self {
        Self {
            upstream_native_link_preflight_required: true,
            owner_approval_required: true,
            owner_approval_must_be_pending: true,
            command_cards_required: true,
            command_unarmed_required: true,
            execution_denied: true,
            build_script_execution_denied: true,
            cargo_build_denied: true,
            linker_invocation_denied: true,
            dynamic_library_load_denied: true,
            python_extension_build_denied: true,
            product_dependency_denied: true,
            route_mutation_denied: true,
            benchmark_authority_denied: true,
            cleanup_required: true,
            rollback_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            compatibility_fence_required: true,
            no_model_runtime_provider_bytes: true,
            no_product_capability_promotion: true,
        }
    }
}

// UAS: uas:turbovec-native-dry-run:byte-ledger
// Plane: Verification.
// Residency: metadata-only command envelope; all live-byte counters remain zero.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecNativeDryRunByteLedger {
    pub upstream_preflight_artifact_bytes_read: u64,
    pub command_card_metadata_bytes: u64,
    pub planned_quarantine_bytes: u64,
    pub raw_turbovec_source_bytes_read: u64,
    pub fetched_repo_bytes: u64,
    pub cloned_repo_bytes: u64,
    pub copied_product_file_count: u64,
    pub product_dependency_count: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub build_script_exec_count: u64,
    pub cargo_build_invocation_count: u64,
    pub linker_invocation_count: u64,
    pub dynamic_library_load_count: u64,
    pub python_build_invocation_count: u64,
    pub benchmark_run_count: u64,
    pub index_bytes_opened: u64,
    pub model_bytes_loaded: u64,
    pub runtime_model_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

impl TurboVecNativeDryRunByteLedger {
    pub fn metadata_only(
        upstream_preflight_artifact_bytes_read: u64,
        command_card_metadata_bytes: u64,
        planned_quarantine_bytes: u64,
    ) -> Result<Self, TurboVecNativeDryRunError> {
        if upstream_preflight_artifact_bytes_read
            + command_card_metadata_bytes
            + planned_quarantine_bytes
            > MAX_METADATA_BYTES
        {
            return Err(TurboVecNativeDryRunError::MetadataBudgetExceeded);
        }
        Ok(Self {
            upstream_preflight_artifact_bytes_read,
            command_card_metadata_bytes,
            planned_quarantine_bytes,
            raw_turbovec_source_bytes_read: 0,
            fetched_repo_bytes: 0,
            cloned_repo_bytes: 0,
            copied_product_file_count: 0,
            product_dependency_count: 0,
            command_armed_count: 0,
            command_executed_count: 0,
            build_script_exec_count: 0,
            cargo_build_invocation_count: 0,
            linker_invocation_count: 0,
            dynamic_library_load_count: 0,
            python_build_invocation_count: 0,
            benchmark_run_count: 0,
            index_bytes_opened: 0,
            model_bytes_loaded: 0,
            runtime_model_bytes_loaded: 0,
            provider_calls_made: 0,
        })
    }
}

// UAS: uas:turbovec-native-dry-run:proof-refs
// Plane: Verification.
// Residency: visible proof handles for a pending dry-run envelope.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecNativeDryRunProofRefs {
    pub upstream_native_link_preflight_ref: String,
    pub owner_approval_ref: String,
    pub command_card_ref: String,
    pub quarantine_path_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
    pub cleanup_ref: String,
    pub visible_summary: String,
}

// UAS: uas:turbovec-native-dry-run:set
// Plane: State + Controller + Verification.
// Residency: deterministic pending owner-approved native dry-run envelope.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRealAdapterOwnerApprovedNativeDryRunProbeSet {
    pub upstream_native_link_preflight_witness_ref: String,
    pub upstream_native_link_preflight_address: UasAddress,
    pub source_url: String,
    pub pinned_revision: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub approval_status: TurboVecNativeDryRunApprovalStatus,
    pub tier: TurboVecNativeDryRunTier,
    pub organs: Vec<TurboVecIndexOrgan>,
    pub command_cards: Vec<TurboVecNativeDryRunCommandCard>,
    pub policy: TurboVecNativeDryRunPolicy,
    pub proof_refs: TurboVecNativeDryRunProofRefs,
    pub byte_ledger: TurboVecNativeDryRunByteLedger,
    pub product_capability_promoted: bool,
    pub route_mutation_allowed: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub live_large_model_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub set_address: UasAddress,
}

impl TurboVecRealAdapterOwnerApprovedNativeDryRunProbeSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_parts(
        upstream_native_link_preflight_address: UasAddress,
        command_cards: Vec<TurboVecNativeDryRunCommandCard>,
        policy: TurboVecNativeDryRunPolicy,
        proof_refs: TurboVecNativeDryRunProofRefs,
        byte_ledger: TurboVecNativeDryRunByteLedger,
        product_build: ProductBuild,
        pro_status: ProStatus,
        approval_status: TurboVecNativeDryRunApprovalStatus,
        tier: TurboVecNativeDryRunTier,
        product_capability_promoted: bool,
        route_mutation_allowed: bool,
        hidden_route_authority: bool,
        hidden_cloud_fallback_allowed: bool,
        live_large_model_claimed: bool,
        ssd_as_ram_claimed: bool,
    ) -> Result<Self, TurboVecNativeDryRunError> {
        let mut sorted_cards = command_cards;
        sorted_cards.sort_by(|left, right| left.card_id.cmp(&right.card_id));
        let mut set = Self {
            upstream_native_link_preflight_witness_ref: UPSTREAM_WITNESS_REF.to_string(),
            upstream_native_link_preflight_address,
            source_url: SOURCE_URL.to_string(),
            pinned_revision: PINNED_REVISION.to_string(),
            product_build,
            pro_status,
            approval_status,
            tier,
            organs: vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            command_cards: sorted_cards,
            policy,
            proof_refs,
            byte_ledger,
            product_capability_promoted,
            route_mutation_allowed,
            hidden_route_authority,
            hidden_cloud_fallback_allowed,
            live_large_model_claimed,
            ssd_as_ram_claimed,
            set_address: UasAddress::new(
                UasKind::Other(
                    "turbovec_real_adapter_owner_approved_native_dry_run_probe".to_string(),
                ),
                b"pending",
                1_779_042_311_000,
            ),
        };
        set.validate()?;
        let digest = owner_approved_native_dry_run_digest(&set);
        set.set_address = UasAddress::new(
            UasKind::Other("turbovec_real_adapter_owner_approved_native_dry_run_probe".to_string()),
            digest.as_bytes(),
            1_779_042_311_000,
        );
        Ok(set)
    }

    pub fn metrics(&self) -> TurboVecNativeDryRunMetrics {
        let mut metrics = TurboVecNativeDryRunMetrics {
            command_card_count: self.command_cards.len() as u64,
            upstream_preflight_artifact_bytes_read: self
                .byte_ledger
                .upstream_preflight_artifact_bytes_read,
            command_card_metadata_bytes: self.byte_ledger.command_card_metadata_bytes,
            planned_quarantine_bytes: self.byte_ledger.planned_quarantine_bytes,
            raw_turbovec_source_bytes_read: self.byte_ledger.raw_turbovec_source_bytes_read,
            fetched_repo_bytes: self.byte_ledger.fetched_repo_bytes,
            cloned_repo_bytes: self.byte_ledger.cloned_repo_bytes,
            copied_product_file_count: self.byte_ledger.copied_product_file_count,
            product_dependency_count: self.byte_ledger.product_dependency_count,
            command_armed_count: self.byte_ledger.command_armed_count,
            command_executed_count: self.byte_ledger.command_executed_count,
            build_script_exec_count: self.byte_ledger.build_script_exec_count,
            cargo_build_invocation_count: self.byte_ledger.cargo_build_invocation_count,
            linker_invocation_count: self.byte_ledger.linker_invocation_count,
            dynamic_library_load_count: self.byte_ledger.dynamic_library_load_count,
            python_build_invocation_count: self.byte_ledger.python_build_invocation_count,
            benchmark_run_count: self.byte_ledger.benchmark_run_count,
            index_bytes_opened: self.byte_ledger.index_bytes_opened,
            model_bytes_loaded: self.byte_ledger.model_bytes_loaded,
            runtime_model_bytes_loaded: self.byte_ledger.runtime_model_bytes_loaded,
            provider_calls_made: self.byte_ledger.provider_calls_made,
            product_capability_promoted_count: u64::from(self.product_capability_promoted),
            route_mutation_count: u64::from(self.route_mutation_allowed),
            hidden_authority_count: u64::from(
                self.hidden_route_authority || self.hidden_cloud_fallback_allowed,
            ),
            live_large_model_claim_count: u64::from(self.live_large_model_claimed),
            ssd_as_ram_claim_count: u64::from(self.ssd_as_ram_claimed),
            ..TurboVecNativeDryRunMetrics::default()
        };
        for card in &self.command_cards {
            if card.command_visible {
                metrics.command_visible_count += 1;
            }
            if card.owner_approval_required {
                metrics.owner_approval_required_count += 1;
            }
            if card.owner_approval_granted {
                metrics.owner_approval_granted_count += 1;
            }
            if card.command_armed {
                metrics.card_command_armed_count += 1;
            }
            if card.command_executed {
                metrics.card_command_executed_count += 1;
            }
            if card.cleanup_required {
                metrics.cleanup_required_count += 1;
            }
            if matches!(
                card.kind,
                TurboVecNativeDryRunCommandKind::CargoMetadataTemplate
            ) {
                metrics.cargo_metadata_template_count += 1;
            }
            if matches!(
                card.kind,
                TurboVecNativeDryRunCommandKind::CargoCheckTemplate
            ) {
                metrics.cargo_check_template_count += 1;
            }
            if matches!(card.kind, TurboVecNativeDryRunCommandKind::BuildScriptAudit) {
                metrics.build_script_audit_count += 1;
            }
            if matches!(card.kind, TurboVecNativeDryRunCommandKind::TargetBlasAudit) {
                metrics.target_blas_audit_count += 1;
            }
            if matches!(
                card.kind,
                TurboVecNativeDryRunCommandKind::PythonExtensionAudit
            ) {
                metrics.python_extension_audit_count += 1;
            }
            if matches!(
                card.kind,
                TurboVecNativeDryRunCommandKind::ProductGraphRecheck
            ) {
                metrics.product_graph_recheck_count += 1;
            }
        }
        metrics
    }

    fn validate(&self) -> Result<(), TurboVecNativeDryRunError> {
        if self.upstream_native_link_preflight_witness_ref != UPSTREAM_WITNESS_REF
            || !self
                .upstream_native_link_preflight_address
                .to_string()
                .starts_with(UPSTREAM_ADDRESS_PREFIX)
        {
            return Err(TurboVecNativeDryRunError::UpstreamPreflightNotBound);
        }
        if self.source_url != SOURCE_URL || self.pinned_revision != PINNED_REVISION {
            return Err(TurboVecNativeDryRunError::BadSourceIdentity);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::ResearchCandidate
            || self.approval_status != TurboVecNativeDryRunApprovalStatus::PendingOwnerApproval
            || self.tier != TurboVecNativeDryRunTier::T1L1Metadata
        {
            return Err(TurboVecNativeDryRunError::PromotionBoundaryViolation);
        }
        validate_cards(&self.command_cards)?;
        validate_policy(&self.policy)?;
        validate_proofs(&self.proof_refs)?;
        validate_byte_ledger(&self.byte_ledger)?;
        if self.product_capability_promoted
            || self.route_mutation_allowed
            || self.hidden_route_authority
            || self.hidden_cloud_fallback_allowed
            || self.live_large_model_claimed
            || self.ssd_as_ram_claimed
        {
            return Err(TurboVecNativeDryRunError::PromotionBoundaryViolation);
        }
        let metrics = self.metrics();
        if metrics.command_visible_count != metrics.command_card_count
            || metrics.owner_approval_required_count != metrics.command_card_count
            || metrics.owner_approval_granted_count > 0
            || metrics.card_command_armed_count > 0
            || metrics.card_command_executed_count > 0
            || metrics.cleanup_required_count != metrics.command_card_count
        {
            return Err(TurboVecNativeDryRunError::CommandEnvelopeViolation);
        }
        Ok(())
    }
}

// UAS: uas:turbovec-native-dry-run:metrics
// Plane: Verification.
// Residency: derived counts for falsifier axes.
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecNativeDryRunMetrics {
    pub command_card_count: u64,
    pub command_visible_count: u64,
    pub owner_approval_required_count: u64,
    pub owner_approval_granted_count: u64,
    pub cleanup_required_count: u64,
    pub cargo_metadata_template_count: u64,
    pub cargo_check_template_count: u64,
    pub build_script_audit_count: u64,
    pub target_blas_audit_count: u64,
    pub python_extension_audit_count: u64,
    pub product_graph_recheck_count: u64,
    pub upstream_preflight_artifact_bytes_read: u64,
    pub command_card_metadata_bytes: u64,
    pub planned_quarantine_bytes: u64,
    pub raw_turbovec_source_bytes_read: u64,
    pub fetched_repo_bytes: u64,
    pub cloned_repo_bytes: u64,
    pub copied_product_file_count: u64,
    pub product_dependency_count: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub card_command_armed_count: u64,
    pub card_command_executed_count: u64,
    pub build_script_exec_count: u64,
    pub cargo_build_invocation_count: u64,
    pub linker_invocation_count: u64,
    pub dynamic_library_load_count: u64,
    pub python_build_invocation_count: u64,
    pub benchmark_run_count: u64,
    pub index_bytes_opened: u64,
    pub model_bytes_loaded: u64,
    pub runtime_model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub product_capability_promoted_count: u64,
    pub route_mutation_count: u64,
    pub hidden_authority_count: u64,
    pub live_large_model_claim_count: u64,
    pub ssd_as_ram_claim_count: u64,
}

// UAS: uas:turbovec-native-dry-run:error
// Plane: Verification.
// Residency: fail-closed validation errors.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TurboVecNativeDryRunError {
    UpstreamPreflightNotBound,
    BadSourceIdentity,
    PromotionBoundaryViolation,
    MissingCommandCards,
    DuplicateCommandCard,
    BadCommandCard(String),
    MissingRequiredCommandKind,
    PolicyNotFailClosed,
    ProofRefsMissing,
    MetadataBudgetExceeded,
    RuntimeOrModelBytesDetected,
    NativeExecutionDetected,
    CommandEnvelopeViolation,
}

impl fmt::Display for TurboVecNativeDryRunError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::UpstreamPreflightNotBound => write!(formatter, "upstream preflight not bound"),
            Self::BadSourceIdentity => write!(formatter, "bad TurboVec source identity"),
            Self::PromotionBoundaryViolation => write!(formatter, "promotion boundary violation"),
            Self::MissingCommandCards => write!(formatter, "missing command cards"),
            Self::DuplicateCommandCard => write!(formatter, "duplicate command card"),
            Self::BadCommandCard(id) => write!(formatter, "bad command card {id}"),
            Self::MissingRequiredCommandKind => write!(formatter, "missing command kind"),
            Self::PolicyNotFailClosed => write!(formatter, "policy is not fail-closed"),
            Self::ProofRefsMissing => write!(formatter, "proof refs missing"),
            Self::MetadataBudgetExceeded => write!(formatter, "metadata budget exceeded"),
            Self::RuntimeOrModelBytesDetected => write!(formatter, "runtime/model bytes detected"),
            Self::NativeExecutionDetected => write!(formatter, "native execution detected"),
            Self::CommandEnvelopeViolation => write!(formatter, "command envelope violation"),
        }
    }
}

impl std::error::Error for TurboVecNativeDryRunError {}

fn validate_cards(
    cards: &[TurboVecNativeDryRunCommandCard],
) -> Result<(), TurboVecNativeDryRunError> {
    if cards.len() < MIN_COMMAND_CARDS {
        return Err(TurboVecNativeDryRunError::MissingCommandCards);
    }
    let mut ids = BTreeSet::new();
    let mut kinds = BTreeSet::new();
    for card in cards {
        if !ids.insert(card.card_id.as_str()) {
            return Err(TurboVecNativeDryRunError::DuplicateCommandCard);
        }
        kinds.insert(card.kind);
        if !card.is_pending_and_unarmed() {
            return Err(TurboVecNativeDryRunError::BadCommandCard(
                card.card_id.clone(),
            ));
        }
    }
    for required in [
        TurboVecNativeDryRunCommandKind::CargoMetadataTemplate,
        TurboVecNativeDryRunCommandKind::CargoCheckTemplate,
        TurboVecNativeDryRunCommandKind::BuildScriptAudit,
        TurboVecNativeDryRunCommandKind::TargetBlasAudit,
        TurboVecNativeDryRunCommandKind::PythonExtensionAudit,
        TurboVecNativeDryRunCommandKind::ProductGraphRecheck,
        TurboVecNativeDryRunCommandKind::CleanupLease,
        TurboVecNativeDryRunCommandKind::AnswerPacketReview,
    ] {
        if !kinds.contains(&required) {
            return Err(TurboVecNativeDryRunError::MissingRequiredCommandKind);
        }
    }
    Ok(())
}

fn validate_policy(policy: &TurboVecNativeDryRunPolicy) -> Result<(), TurboVecNativeDryRunError> {
    if policy.upstream_native_link_preflight_required
        && policy.owner_approval_required
        && policy.owner_approval_must_be_pending
        && policy.command_cards_required
        && policy.command_unarmed_required
        && policy.execution_denied
        && policy.build_script_execution_denied
        && policy.cargo_build_denied
        && policy.linker_invocation_denied
        && policy.dynamic_library_load_denied
        && policy.python_extension_build_denied
        && policy.product_dependency_denied
        && policy.route_mutation_denied
        && policy.benchmark_authority_denied
        && policy.cleanup_required
        && policy.rollback_required
        && policy.run_event_log_required
        && policy.answer_packet_required
        && policy.compatibility_fence_required
        && policy.no_model_runtime_provider_bytes
        && policy.no_product_capability_promotion
    {
        Ok(())
    } else {
        Err(TurboVecNativeDryRunError::PolicyNotFailClosed)
    }
}

fn validate_proofs(refs: &TurboVecNativeDryRunProofRefs) -> Result<(), TurboVecNativeDryRunError> {
    if refs.upstream_native_link_preflight_ref == UPSTREAM_WITNESS_REF
        && refs.owner_approval_ref.starts_with(OWNER_APPROVAL_PREFIX)
        && refs.command_card_ref.starts_with(COMMAND_CARD_PREFIX)
        && refs.quarantine_path_ref.starts_with(QUARANTINE_PATH_PREFIX)
        && refs.rollback_ref.starts_with(ROLLBACK_REF_PREFIX)
        && refs.run_event_log_ref.starts_with(RUN_EVENT_LOG_REF_PREFIX)
        && refs.answer_packet_ref.starts_with(ANSWER_PACKET_REF_PREFIX)
        && refs
            .compatibility_fence_ref
            .starts_with(COMPATIBILITY_REF_PREFIX)
        && refs.cleanup_ref.starts_with(CLEANUP_REF_PREFIX)
        && refs.visible_summary.len() >= MIN_VISIBLE_SUMMARY_BYTES
        && refs.visible_summary.contains("owner approval")
        && refs.visible_summary.contains("AnswerPacket")
        && refs.visible_summary.contains("L2/L3")
    {
        Ok(())
    } else {
        Err(TurboVecNativeDryRunError::ProofRefsMissing)
    }
}

fn validate_byte_ledger(
    ledger: &TurboVecNativeDryRunByteLedger,
) -> Result<(), TurboVecNativeDryRunError> {
    if ledger.upstream_preflight_artifact_bytes_read
        + ledger.command_card_metadata_bytes
        + ledger.planned_quarantine_bytes
        > MAX_METADATA_BYTES
    {
        return Err(TurboVecNativeDryRunError::MetadataBudgetExceeded);
    }
    if ledger.raw_turbovec_source_bytes_read > 0
        || ledger.fetched_repo_bytes > 0
        || ledger.cloned_repo_bytes > 0
        || ledger.index_bytes_opened > 0
        || ledger.model_bytes_loaded > 0
        || ledger.runtime_model_bytes_loaded > 0
        || ledger.provider_calls_made > 0
    {
        return Err(TurboVecNativeDryRunError::RuntimeOrModelBytesDetected);
    }
    if ledger.copied_product_file_count > 0
        || ledger.product_dependency_count > 0
        || ledger.command_armed_count > 0
        || ledger.command_executed_count > 0
        || ledger.build_script_exec_count > 0
        || ledger.cargo_build_invocation_count > 0
        || ledger.linker_invocation_count > 0
        || ledger.dynamic_library_load_count > 0
        || ledger.python_build_invocation_count > 0
        || ledger.benchmark_run_count > 0
    {
        return Err(TurboVecNativeDryRunError::NativeExecutionDetected);
    }
    Ok(())
}

pub fn owner_approved_native_dry_run_digest(
    set: &TurboVecRealAdapterOwnerApprovedNativeDryRunProbeSet,
) -> String {
    let cards: Vec<_> = set
        .command_cards
        .iter()
        .map(|card| {
            (
                card.card_id.as_str(),
                card.kind,
                card.command_template.as_str(),
                card.command_card_ref.as_str(),
                card.quarantine_path_ref.as_str(),
                card.owner_approval_ref.as_str(),
                card.command_visible,
                card.owner_approval_required,
                card.owner_approval_granted,
                card.command_armed,
                card.command_executed,
            )
        })
        .collect();
    let payload = serde_json::json!({
        "source_url": set.source_url,
        "pinned_revision": set.pinned_revision,
        "upstream": set.upstream_native_link_preflight_address.to_string(),
        "cards": cards,
        "policy": set.policy,
        "proof_refs": set.proof_refs,
        "byte_ledger": set.byte_ledger,
        "product_build": set.product_build,
        "pro_status": set.pro_status,
        "approval_status": set.approval_status,
        "tier": set.tier,
    });
    sha256_hex(payload.to_string().as_bytes())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn upstream() -> UasAddress {
        UasAddress::new(
            UasKind::Other("turbovec_real_adapter_native_link_absence_preflight_probe".to_string()),
            b"native-link-preflight",
            1,
        )
    }

    fn card(id: &str, kind: TurboVecNativeDryRunCommandKind) -> TurboVecNativeDryRunCommandCard {
        TurboVecNativeDryRunCommandCard {
            card_id: id.to_string(),
            kind,
            command_template: format!("dry-run-template:{id} --unarmed --no-exec"),
            command_card_ref: format!("command_card:turbovec-native-dry-run:{id}"),
            quarantine_path_ref: format!("quarantine_path:turbovec-native-dry-run:{id}"),
            native_link_ref: format!("native_link:turbovec-preflight:{id}"),
            owner_approval_ref: format!("owner_approval:pending:turbovec-native-dry-run:{id}"),
            rollback_ref: format!("rollback:turbovec-native-dry-run:{id}"),
            run_event_log_ref: format!("run_event_log:turbovec-native-dry-run:{id}"),
            answer_packet_ref: format!("answer_packet:turbovec-native-dry-run:{id}"),
            compatibility_fence_ref: format!("compat:turbovec-native-dry-run:{id}"),
            cleanup_ref: format!("cleanup:turbovec-native-dry-run:{id}"),
            visible_summary: "This TurboVec native dry-run command card is visible but unarmed, requires explicit owner approval, carries rollback, RunEventLog, AnswerPacket, cleanup, compatibility fence, and does not execute build scripts, linkers, Python extensions, product routes, or L2/L3 capability.".to_string(),
            command_visible: true,
            owner_approval_required: true,
            owner_approval_granted: false,
            command_armed: false,
            command_executed: false,
            build_script_execution_allowed: false,
            cargo_build_allowed: false,
            linker_allowed: false,
            dynamic_library_load_allowed: false,
            python_extension_build_allowed: false,
            product_dependency_allowed: false,
            product_route_mutation_allowed: false,
            benchmark_authority_allowed: false,
            cleanup_required: true,
        }
    }

    fn cards() -> Vec<TurboVecNativeDryRunCommandCard> {
        vec![
            card(
                "cargo_metadata",
                TurboVecNativeDryRunCommandKind::CargoMetadataTemplate,
            ),
            card(
                "cargo_check",
                TurboVecNativeDryRunCommandKind::CargoCheckTemplate,
            ),
            card(
                "build_rs",
                TurboVecNativeDryRunCommandKind::BuildScriptAudit,
            ),
            card(
                "target_blas",
                TurboVecNativeDryRunCommandKind::TargetBlasAudit,
            ),
            card(
                "python_extension",
                TurboVecNativeDryRunCommandKind::PythonExtensionAudit,
            ),
            card(
                "product_graph",
                TurboVecNativeDryRunCommandKind::ProductGraphRecheck,
            ),
            card("cleanup", TurboVecNativeDryRunCommandKind::CleanupLease),
            card(
                "answer_packet",
                TurboVecNativeDryRunCommandKind::AnswerPacketReview,
            ),
        ]
    }

    fn proof_refs() -> TurboVecNativeDryRunProofRefs {
        TurboVecNativeDryRunProofRefs {
            upstream_native_link_preflight_ref: UPSTREAM_WITNESS_REF.to_string(),
            owner_approval_ref: "owner_approval:pending:turbovec-native-dry-run:set".to_string(),
            command_card_ref: "command_card:turbovec-native-dry-run:set".to_string(),
            quarantine_path_ref: "quarantine_path:turbovec-native-dry-run:set".to_string(),
            rollback_ref: "rollback:turbovec-native-dry-run:set".to_string(),
            run_event_log_ref: "run_event_log:turbovec-native-dry-run:set".to_string(),
            answer_packet_ref: "answer_packet:turbovec-native-dry-run:set".to_string(),
            compatibility_fence_ref: "compat:turbovec-native-dry-run:set".to_string(),
            cleanup_ref: "cleanup:turbovec-native-dry-run:set".to_string(),
            visible_summary: "TurboVec native dry-run command envelope requires explicit owner approval and keeps every command unarmed until a separate owner-approved execution witness exists. The proof packet carries cleanup, rollback, RunEventLog, AnswerPacket, compatibility fence, no native build or linker execution, no product route mutation, and no L2/L3 promotion from this L1 metadata-only gate.".to_string(),
        }
    }

    fn set_with_cards(
        cards: Vec<TurboVecNativeDryRunCommandCard>,
    ) -> Result<TurboVecRealAdapterOwnerApprovedNativeDryRunProbeSet, TurboVecNativeDryRunError>
    {
        TurboVecRealAdapterOwnerApprovedNativeDryRunProbeSet::from_parts(
            upstream(),
            cards,
            TurboVecNativeDryRunPolicy::fail_closed(),
            proof_refs(),
            TurboVecNativeDryRunByteLedger::metadata_only(512, 512, 4096)?,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecNativeDryRunApprovalStatus::PendingOwnerApproval,
            TurboVecNativeDryRunTier::T1L1Metadata,
            false,
            false,
            false,
            false,
            false,
            false,
        )
    }

    #[test]
    fn accepts_pending_unarmed_command_envelope() {
        let set = set_with_cards(cards()).expect("pending dry-run envelope should pass");
        let metrics = set.metrics();
        assert_eq!(metrics.command_card_count, 8);
        assert_eq!(metrics.command_executed_count, 0);
        assert_eq!(metrics.owner_approval_granted_count, 0);
    }

    #[test]
    fn address_is_deterministic_when_cards_reordered() {
        let forward = set_with_cards(cards()).expect("forward cards should pass");
        let mut reversed = cards();
        reversed.reverse();
        let reversed = set_with_cards(reversed).expect("reversed cards should pass");
        assert_eq!(forward.set_address, reversed.set_address);
    }

    #[test]
    fn rejects_owner_approval_or_execution() {
        let mut owner_granted_cards = cards();
        owner_granted_cards[0].owner_approval_granted = true;
        assert!(matches!(
            set_with_cards(owner_granted_cards),
            Err(TurboVecNativeDryRunError::BadCommandCard(_))
        ));
        let mut executed_cards = cards();
        executed_cards[0].command_executed = true;
        assert!(matches!(
            set_with_cards(executed_cards),
            Err(TurboVecNativeDryRunError::BadCommandCard(_))
        ));
    }

    #[test]
    fn rejects_runtime_bytes_and_promotion() {
        let result = TurboVecRealAdapterOwnerApprovedNativeDryRunProbeSet::from_parts(
            upstream(),
            cards(),
            TurboVecNativeDryRunPolicy::fail_closed(),
            proof_refs(),
            TurboVecNativeDryRunByteLedger {
                model_bytes_loaded: 1,
                ..TurboVecNativeDryRunByteLedger::metadata_only(512, 512, 4096).expect("ledger")
            },
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecNativeDryRunApprovalStatus::PendingOwnerApproval,
            TurboVecNativeDryRunTier::T1L1Metadata,
            true,
            false,
            false,
            false,
            false,
            false,
        );
        assert!(result.is_err());
    }
}
