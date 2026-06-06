//! TurboVec real-adapter clean-room adapter-plan probe.
//!
//! This primitive converts source-carded TurboVec motifs into an
//! Epistemos-owned adapter plan. It is research-to-build only: the plan can
//! shape later Eidos/AppColdStore shadow replay and working-set compiler work,
//! but it cannot import upstream code, add dependencies, probe native links,
//! run benchmarks, open index bytes, inject model context, mutate routes, or
//! claim product capability.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild, TurboVecIndexOrgan, UasAddress, UasKind};

pub const TURBOVEC_REAL_ADAPTER_CLEAN_ROOM_ADAPTER_PLAN_CURSOR: &str =
    "turbovec_quarantine_real_adapter_clean_room_adapter_plan_probe";
pub const TURBOVEC_REAL_ADAPTER_CLEAN_ROOM_ADAPTER_PLAN_NEXT_CURSOR: &str =
    "turbovec_quarantine_real_adapter_exact_baseline_shadow_replay_probe";

const MOTIF_CARD_WITNESS_REF: &str =
    "artifact:turbovec_real_adapter_motif_extraction_card_probe:result";
const MOTIF_CARD_ADDRESS_PREFIX: &str = "turbovec_real_adapter_motif_extraction_card_probe:";
const PINNED_REVISION: &str = "efe29a184986cbf562a9847c2ac52a2990bfaca2";
const SOURCE_URL: &str = "https://github.com/RyanCodrai/turbovec";
const PLAN_REF_PREFIX: &str = "clean_room_plan:turbovec-adapter:";
const MOTIF_REF_PREFIX: &str = "motif:turbovec-real-adapter:";
const SOURCE_CARD_REF_PREFIX: &str = "source_card:turbovec-motif-extraction:";
const NO_PRODUCT_GRAPH_REF_PREFIX: &str = "no_product_graph:turbovec-clean-room-adapter:";
const ROLLBACK_REF_PREFIX: &str = "rollback:turbovec-clean-room-adapter:";
const RUN_EVENT_LOG_REF_PREFIX: &str = "run_event_log:turbovec-clean-room-adapter:";
const ANSWER_PACKET_REF_PREFIX: &str = "answer_packet:turbovec-clean-room-adapter:";
const COMPATIBILITY_REF_PREFIX: &str = "compat:turbovec-clean-room-adapter:";
const SHADOW_REPLAY_REF_PREFIX: &str = "shadow_replay:turbovec-clean-room-adapter:";
const BASELINE_REF_PREFIX: &str = "exact_baseline:turbovec-clean-room-adapter:";
const MAX_METADATA_BYTES: u64 = 256 * 1024;
const UPSTREAM_MOTIF_SOURCE_BYTES: u64 = 184_472;
const MIN_PLAN_STEP_COUNT: usize = 9;
const MIN_COMPONENT_COUNT: usize = 8;
const MIN_REQUIRED_MOTIF_LINKS: usize = 10;
const MIN_VISIBLE_SUMMARY_BYTES: usize = 560;

// UAS: uas:turbovec-clean-room-adapter-plan:status
// Plane: Verification
// Residency: adapter plan promotion boundary.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecAdapterPlanStatus {
    CleanRoomPlanOnly,
    BuildCandidate,
    RuntimeCandidate,
}

// UAS: uas:turbovec-clean-room-adapter-plan:tier
// Plane: Verification
// Residency: tier discipline for adapter planning.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecAdapterPlanTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:turbovec-clean-room-adapter-plan:component
// Plane: State + Assembly + Controller + Verification
// Residency: adapter-plan component that must be witnessed before build.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecAdapterPlanComponent {
    UasExternalIdMap,
    FilterBeforeRankPipeline,
    BufferBackedIoBoundary,
    VersionedRebuildFence,
    ExactBaselineShadowReplay,
    PrivacyLatencyAbstention,
    CancellationRollbackLease,
    AnswerPacketCaveat,
    NoNativeLinkDefault,
    LargeModelWorkingSetCompiler,
}

// UAS: uas:turbovec-clean-room-adapter-plan:step
// Plane: State + Assembly + Controller + Verification
// Residency: clean-room adapter-plan step; no executable adapter code.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecAdapterPlanStep {
    pub step_id: String,
    pub component: TurboVecAdapterPlanComponent,
    pub organ: TurboVecIndexOrgan,
    pub source_motif_ids: Vec<String>,
    pub plan_ref: String,
    pub interface_summary: String,
    pub invariant: String,
    pub forbidden_action: String,
    pub runtime_proof_required: String,
    pub user_visible_proof_required: String,
    pub rollback_ref: String,
    pub no_upstream_source_import: bool,
    pub no_product_dependency: bool,
    pub no_native_link_probe: bool,
    pub no_benchmark_authority: bool,
    pub no_route_authority: bool,
    pub no_model_context_injection: bool,
}

// UAS: uas:turbovec-clean-room-adapter-plan:policy
// Plane: Controller + Verification
// Residency: fail-closed clean-room adapter policy.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecAdapterPlanPolicy {
    pub upstream_motif_cards_bound: bool,
    pub clean_room_rewrite_only: bool,
    pub source_card_trace_required: bool,
    pub no_verbatim_source: bool,
    pub no_direct_import: bool,
    pub no_adapter_wrap: bool,
    pub no_product_dependency: bool,
    pub no_native_link_default: bool,
    pub no_adapter_build: bool,
    pub no_benchmark_authority: bool,
    pub no_runtime_execution: bool,
    pub no_route_authority: bool,
    pub no_model_context_injection: bool,
    pub exact_baseline_required_before_quality: bool,
    pub shadow_replay_required_before_live_route: bool,
    pub rollback_required: bool,
    pub answer_packet_required: bool,
}

impl TurboVecAdapterPlanPolicy {
    pub fn fail_closed() -> Self {
        Self {
            upstream_motif_cards_bound: true,
            clean_room_rewrite_only: true,
            source_card_trace_required: true,
            no_verbatim_source: true,
            no_direct_import: true,
            no_adapter_wrap: true,
            no_product_dependency: true,
            no_native_link_default: true,
            no_adapter_build: true,
            no_benchmark_authority: true,
            no_runtime_execution: true,
            no_route_authority: true,
            no_model_context_injection: true,
            exact_baseline_required_before_quality: true,
            shadow_replay_required_before_live_route: true,
            rollback_required: true,
            answer_packet_required: true,
        }
    }
}

// UAS: uas:turbovec-clean-room-adapter-plan:byte-ledger
// Plane: Verification
// Residency: metadata-only byte accounting for clean-room adapter planning.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecAdapterPlanByteLedger {
    pub upstream_motif_source_bytes_cited: u64,
    pub additional_raw_source_bytes_inspected: u64,
    pub adapter_plan_metadata_bytes: u64,
    pub product_files_copied: u64,
    pub product_dependencies_added: u64,
    pub native_link_probe_count: u64,
    pub adapter_build_count: u64,
    pub benchmark_run_count: u64,
    pub index_bytes_opened: u64,
    pub model_bytes_loaded: u64,
    pub runtime_model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub route_mutation_count: u64,
    pub model_context_injection_count: u64,
}

impl TurboVecAdapterPlanByteLedger {
    pub fn metadata_only() -> Self {
        Self {
            upstream_motif_source_bytes_cited: UPSTREAM_MOTIF_SOURCE_BYTES,
            additional_raw_source_bytes_inspected: 0,
            adapter_plan_metadata_bytes: 48 * 1024,
            product_files_copied: 0,
            product_dependencies_added: 0,
            native_link_probe_count: 0,
            adapter_build_count: 0,
            benchmark_run_count: 0,
            index_bytes_opened: 0,
            model_bytes_loaded: 0,
            runtime_model_bytes_loaded: 0,
            provider_calls_made: 0,
            route_mutation_count: 0,
            model_context_injection_count: 0,
        }
    }
}

// UAS: uas:turbovec-clean-room-adapter-plan:proof-refs
// Plane: Verification
// Residency: visible proof handles for adapter-plan promotion.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecAdapterPlanProofRefs {
    pub source_card_ref: String,
    pub no_product_graph_ref: String,
    pub exact_baseline_ref: String,
    pub shadow_replay_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
    pub visible_summary: String,
}

// UAS: uas:turbovec-clean-room-adapter-plan:set
// Plane: State + Assembly + Controller + Verification
// Residency: metadata-only clean-room adapter-plan witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRealAdapterCleanRoomAdapterPlanProbeSet {
    pub upstream_motif_card_witness_ref: String,
    pub upstream_motif_card_address: UasAddress,
    pub source_url: String,
    pub pinned_revision: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub status: TurboVecAdapterPlanStatus,
    pub tier: TurboVecAdapterPlanTier,
    pub organs: Vec<TurboVecIndexOrgan>,
    pub steps: Vec<TurboVecAdapterPlanStep>,
    pub policy: TurboVecAdapterPlanPolicy,
    pub proof_refs: TurboVecAdapterPlanProofRefs,
    pub byte_ledger: TurboVecAdapterPlanByteLedger,
    pub product_capability_promoted: bool,
    pub route_mutation_allowed: bool,
    pub model_context_injected: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub live_large_model_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub set_address: UasAddress,
}

impl TurboVecRealAdapterCleanRoomAdapterPlanProbeSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_parts(
        upstream_motif_card_address: UasAddress,
        steps: Vec<TurboVecAdapterPlanStep>,
        policy: TurboVecAdapterPlanPolicy,
        proof_refs: TurboVecAdapterPlanProofRefs,
        byte_ledger: TurboVecAdapterPlanByteLedger,
        product_build: ProductBuild,
        pro_status: ProStatus,
        status: TurboVecAdapterPlanStatus,
        tier: TurboVecAdapterPlanTier,
        product_capability_promoted: bool,
        route_mutation_allowed: bool,
        model_context_injected: bool,
        hidden_route_authority: bool,
        hidden_cloud_fallback_allowed: bool,
        live_large_model_claimed: bool,
        ssd_as_ram_claimed: bool,
    ) -> Result<Self, TurboVecAdapterPlanError> {
        let mut sorted_steps = steps;
        sorted_steps.sort_by(|left, right| left.step_id.cmp(&right.step_id));
        let organs = vec![
            TurboVecIndexOrgan::Eidos,
            TurboVecIndexOrgan::AppColdStore,
            TurboVecIndexOrgan::SemanticWorkingSetPlan,
            TurboVecIndexOrgan::AnswerPacket,
        ];
        let mut set = Self {
            upstream_motif_card_witness_ref: MOTIF_CARD_WITNESS_REF.to_string(),
            upstream_motif_card_address,
            source_url: SOURCE_URL.to_string(),
            pinned_revision: PINNED_REVISION.to_string(),
            product_build,
            pro_status,
            status,
            tier,
            organs,
            steps: sorted_steps,
            policy,
            proof_refs,
            byte_ledger,
            product_capability_promoted,
            route_mutation_allowed,
            model_context_injected,
            hidden_route_authority,
            hidden_cloud_fallback_allowed,
            live_large_model_claimed,
            ssd_as_ram_claimed,
            set_address: UasAddress::new(
                UasKind::Other("turbovec_real_adapter_clean_room_adapter_plan_probe".to_string()),
                b"pending",
                1_779_040_905_000,
            ),
        };
        set.validate()?;
        let digest = clean_room_adapter_plan_digest(&set);
        set.set_address = UasAddress::new(
            UasKind::Other("turbovec_real_adapter_clean_room_adapter_plan_probe".to_string()),
            digest.as_bytes(),
            1_779_040_905_000,
        );
        Ok(set)
    }

    pub fn metrics(&self) -> TurboVecAdapterPlanMetrics {
        let components = self
            .steps
            .iter()
            .map(|step| step.component)
            .collect::<BTreeSet<_>>();
        let motif_links = self
            .steps
            .iter()
            .flat_map(|step| step.source_motif_ids.iter())
            .collect::<BTreeSet<_>>();
        TurboVecAdapterPlanMetrics {
            plan_step_count: self.steps.len() as u64,
            component_count: components.len() as u64,
            motif_link_count: motif_links.len() as u64,
            buffer_backed_io_step_count: self
                .steps
                .iter()
                .filter(|step| {
                    step.component == TurboVecAdapterPlanComponent::BufferBackedIoBoundary
                })
                .count() as u64,
            exact_baseline_step_count: self
                .steps
                .iter()
                .filter(|step| {
                    step.component == TurboVecAdapterPlanComponent::ExactBaselineShadowReplay
                })
                .count() as u64,
            large_model_working_set_step_count: self
                .steps
                .iter()
                .filter(|step| {
                    step.component == TurboVecAdapterPlanComponent::LargeModelWorkingSetCompiler
                })
                .count() as u64,
            upstream_motif_source_bytes_cited: self.byte_ledger.upstream_motif_source_bytes_cited,
            additional_raw_source_bytes_inspected: self
                .byte_ledger
                .additional_raw_source_bytes_inspected,
            adapter_plan_metadata_bytes: self.byte_ledger.adapter_plan_metadata_bytes,
            product_files_copied: self.byte_ledger.product_files_copied,
            product_dependencies_added: self.byte_ledger.product_dependencies_added,
            native_link_probe_count: self.byte_ledger.native_link_probe_count,
            adapter_build_count: self.byte_ledger.adapter_build_count,
            benchmark_run_count: self.byte_ledger.benchmark_run_count,
            index_bytes_opened: self.byte_ledger.index_bytes_opened,
            model_bytes_loaded: self.byte_ledger.model_bytes_loaded,
            runtime_model_bytes_loaded: self.byte_ledger.runtime_model_bytes_loaded,
            provider_calls_made: self.byte_ledger.provider_calls_made,
            route_mutation_count: self.byte_ledger.route_mutation_count,
            model_context_injection_count: self.byte_ledger.model_context_injection_count,
            hidden_authority_count: u64::from(
                self.hidden_route_authority || self.hidden_cloud_fallback_allowed,
            ),
        }
    }

    fn validate(&self) -> Result<(), TurboVecAdapterPlanError> {
        if self.upstream_motif_card_witness_ref != MOTIF_CARD_WITNESS_REF {
            return Err(TurboVecAdapterPlanError::UpstreamMotifCardNotBound);
        }
        if !self
            .upstream_motif_card_address
            .to_string()
            .starts_with(MOTIF_CARD_ADDRESS_PREFIX)
        {
            return Err(TurboVecAdapterPlanError::UpstreamMotifCardNotBound);
        }
        if self.source_url != SOURCE_URL || self.pinned_revision != PINNED_REVISION {
            return Err(TurboVecAdapterPlanError::BadSourceIdentity);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::ResearchCandidate
            || self.status != TurboVecAdapterPlanStatus::CleanRoomPlanOnly
            || self.tier != TurboVecAdapterPlanTier::T1L1Metadata
        {
            return Err(TurboVecAdapterPlanError::PromotionBoundaryViolation);
        }
        for organ in [
            TurboVecIndexOrgan::Eidos,
            TurboVecIndexOrgan::AppColdStore,
            TurboVecIndexOrgan::SemanticWorkingSetPlan,
            TurboVecIndexOrgan::AnswerPacket,
        ] {
            if !self.organs.contains(&organ) {
                return Err(TurboVecAdapterPlanError::MissingRequiredOrgan(organ));
            }
        }
        self.validate_steps()?;
        self.validate_policy()?;
        self.validate_proofs()?;
        self.validate_bytes()?;
        if self.product_capability_promoted
            || self.route_mutation_allowed
            || self.model_context_injected
            || self.hidden_route_authority
            || self.hidden_cloud_fallback_allowed
            || self.live_large_model_claimed
            || self.ssd_as_ram_claimed
        {
            return Err(TurboVecAdapterPlanError::ClaimBoundaryViolation);
        }
        Ok(())
    }

    fn validate_steps(&self) -> Result<(), TurboVecAdapterPlanError> {
        if self.steps.len() < MIN_PLAN_STEP_COUNT {
            return Err(TurboVecAdapterPlanError::TooFewSteps);
        }
        let mut ids = HashSet::with_capacity(self.steps.len());
        let mut components = BTreeSet::new();
        let mut motif_links = BTreeSet::new();
        for step in &self.steps {
            if !ids.insert(step.step_id.as_str()) {
                return Err(TurboVecAdapterPlanError::DuplicateStepId(
                    step.step_id.clone(),
                ));
            }
            if step.step_id.trim().is_empty()
                || !step.plan_ref.starts_with(PLAN_REF_PREFIX)
                || step.source_motif_ids.is_empty()
                || step.interface_summary.len() < 72
                || step.invariant.len() < 48
                || step.forbidden_action.len() < 32
                || !step.rollback_ref.starts_with(ROLLBACK_REF_PREFIX)
                || !step.runtime_proof_required.contains("shadow")
                || !step.user_visible_proof_required.contains("AnswerPacket")
            {
                return Err(TurboVecAdapterPlanError::InvalidStep(step.step_id.clone()));
            }
            if !step.no_upstream_source_import
                || !step.no_product_dependency
                || !step.no_native_link_probe
                || !step.no_benchmark_authority
                || !step.no_route_authority
                || !step.no_model_context_injection
            {
                return Err(TurboVecAdapterPlanError::UnsafeStep(step.step_id.clone()));
            }
            for motif in &step.source_motif_ids {
                if !motif.starts_with(MOTIF_REF_PREFIX) || motif.len() <= MOTIF_REF_PREFIX.len() {
                    return Err(TurboVecAdapterPlanError::InvalidMotifRef(motif.clone()));
                }
                motif_links.insert(motif.as_str());
            }
            components.insert(step.component);
        }
        for required in [
            TurboVecAdapterPlanComponent::UasExternalIdMap,
            TurboVecAdapterPlanComponent::FilterBeforeRankPipeline,
            TurboVecAdapterPlanComponent::BufferBackedIoBoundary,
            TurboVecAdapterPlanComponent::VersionedRebuildFence,
            TurboVecAdapterPlanComponent::ExactBaselineShadowReplay,
            TurboVecAdapterPlanComponent::PrivacyLatencyAbstention,
            TurboVecAdapterPlanComponent::CancellationRollbackLease,
            TurboVecAdapterPlanComponent::AnswerPacketCaveat,
            TurboVecAdapterPlanComponent::LargeModelWorkingSetCompiler,
        ] {
            if !components.contains(&required) {
                return Err(TurboVecAdapterPlanError::MissingComponent(required));
            }
        }
        if components.len() < MIN_COMPONENT_COUNT || motif_links.len() < MIN_REQUIRED_MOTIF_LINKS {
            return Err(TurboVecAdapterPlanError::InsufficientCoverage);
        }
        Ok(())
    }

    fn validate_policy(&self) -> Result<(), TurboVecAdapterPlanError> {
        let policy = &self.policy;
        if policy.upstream_motif_cards_bound
            && policy.clean_room_rewrite_only
            && policy.source_card_trace_required
            && policy.no_verbatim_source
            && policy.no_direct_import
            && policy.no_adapter_wrap
            && policy.no_product_dependency
            && policy.no_native_link_default
            && policy.no_adapter_build
            && policy.no_benchmark_authority
            && policy.no_runtime_execution
            && policy.no_route_authority
            && policy.no_model_context_injection
            && policy.exact_baseline_required_before_quality
            && policy.shadow_replay_required_before_live_route
            && policy.rollback_required
            && policy.answer_packet_required
        {
            Ok(())
        } else {
            Err(TurboVecAdapterPlanError::UnsafePolicy)
        }
    }

    fn validate_proofs(&self) -> Result<(), TurboVecAdapterPlanError> {
        let refs = &self.proof_refs;
        for (value, prefix) in [
            (&refs.source_card_ref, SOURCE_CARD_REF_PREFIX),
            (&refs.no_product_graph_ref, NO_PRODUCT_GRAPH_REF_PREFIX),
            (&refs.exact_baseline_ref, BASELINE_REF_PREFIX),
            (&refs.shadow_replay_ref, SHADOW_REPLAY_REF_PREFIX),
            (&refs.rollback_ref, ROLLBACK_REF_PREFIX),
            (&refs.run_event_log_ref, RUN_EVENT_LOG_REF_PREFIX),
            (&refs.answer_packet_ref, ANSWER_PACKET_REF_PREFIX),
            (&refs.compatibility_fence_ref, COMPATIBILITY_REF_PREFIX),
        ] {
            if !value.starts_with(prefix) {
                return Err(TurboVecAdapterPlanError::BadProofRef(value.clone()));
            }
        }
        let summary = refs.visible_summary.to_ascii_lowercase();
        if refs.visible_summary.len() < MIN_VISIBLE_SUMMARY_BYTES
            || !summary.contains("clean-room")
            || !summary.contains("large local model")
            || !summary.contains("no hidden route authority")
            || !summary.contains("no live dense 70b")
            || !summary.contains("answerpacket")
        {
            return Err(TurboVecAdapterPlanError::WeakVisibleSummary);
        }
        Ok(())
    }

    fn validate_bytes(&self) -> Result<(), TurboVecAdapterPlanError> {
        let ledger = &self.byte_ledger;
        if ledger.upstream_motif_source_bytes_cited != UPSTREAM_MOTIF_SOURCE_BYTES
            || ledger.additional_raw_source_bytes_inspected != 0
            || ledger.adapter_plan_metadata_bytes == 0
            || ledger.adapter_plan_metadata_bytes > MAX_METADATA_BYTES
            || ledger.product_files_copied != 0
            || ledger.product_dependencies_added != 0
            || ledger.native_link_probe_count != 0
            || ledger.adapter_build_count != 0
            || ledger.benchmark_run_count != 0
            || ledger.index_bytes_opened != 0
            || ledger.model_bytes_loaded != 0
            || ledger.runtime_model_bytes_loaded != 0
            || ledger.provider_calls_made != 0
            || ledger.route_mutation_count != 0
            || ledger.model_context_injection_count != 0
        {
            return Err(TurboVecAdapterPlanError::InvalidByteLedger);
        }
        Ok(())
    }
}

// UAS: uas:turbovec-clean-room-adapter-plan:metrics
// Plane: Verification
// Residency: metrics exported into the falsifier artifact.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecAdapterPlanMetrics {
    pub plan_step_count: u64,
    pub component_count: u64,
    pub motif_link_count: u64,
    pub buffer_backed_io_step_count: u64,
    pub exact_baseline_step_count: u64,
    pub large_model_working_set_step_count: u64,
    pub upstream_motif_source_bytes_cited: u64,
    pub additional_raw_source_bytes_inspected: u64,
    pub adapter_plan_metadata_bytes: u64,
    pub product_files_copied: u64,
    pub product_dependencies_added: u64,
    pub native_link_probe_count: u64,
    pub adapter_build_count: u64,
    pub benchmark_run_count: u64,
    pub index_bytes_opened: u64,
    pub model_bytes_loaded: u64,
    pub runtime_model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub route_mutation_count: u64,
    pub model_context_injection_count: u64,
    pub hidden_authority_count: u64,
}

// UAS: uas:turbovec-clean-room-adapter-plan:error
// Plane: Verification
// Residency: validation failures for unsafe adapter-plan states.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TurboVecAdapterPlanError {
    UpstreamMotifCardNotBound,
    BadSourceIdentity,
    PromotionBoundaryViolation,
    MissingRequiredOrgan(TurboVecIndexOrgan),
    TooFewSteps,
    DuplicateStepId(String),
    InvalidStep(String),
    UnsafeStep(String),
    InvalidMotifRef(String),
    MissingComponent(TurboVecAdapterPlanComponent),
    InsufficientCoverage,
    UnsafePolicy,
    BadProofRef(String),
    WeakVisibleSummary,
    InvalidByteLedger,
    ClaimBoundaryViolation,
}

impl fmt::Display for TurboVecAdapterPlanError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            TurboVecAdapterPlanError::UpstreamMotifCardNotBound => {
                write!(f, "upstream TurboVec motif-card witness is not bound")
            }
            TurboVecAdapterPlanError::BadSourceIdentity => {
                write!(f, "source URL or pinned revision does not match canon")
            }
            TurboVecAdapterPlanError::PromotionBoundaryViolation => {
                write!(f, "clean-room adapter plan attempted product/T2+ promotion")
            }
            TurboVecAdapterPlanError::MissingRequiredOrgan(organ) => {
                write!(f, "missing required organ {organ:?}")
            }
            TurboVecAdapterPlanError::TooFewSteps => write!(f, "adapter plan has too few steps"),
            TurboVecAdapterPlanError::DuplicateStepId(id) => {
                write!(f, "duplicate adapter-plan step id {id}")
            }
            TurboVecAdapterPlanError::InvalidStep(id) => {
                write!(f, "invalid adapter-plan step {id}")
            }
            TurboVecAdapterPlanError::UnsafeStep(id) => {
                write!(f, "unsafe adapter-plan step {id}")
            }
            TurboVecAdapterPlanError::InvalidMotifRef(value) => {
                write!(f, "invalid motif ref {value}")
            }
            TurboVecAdapterPlanError::MissingComponent(component) => {
                write!(f, "missing adapter-plan component {component:?}")
            }
            TurboVecAdapterPlanError::InsufficientCoverage => {
                write!(f, "adapter plan lacks motif/component coverage")
            }
            TurboVecAdapterPlanError::UnsafePolicy => {
                write!(f, "clean-room adapter policy is not fail-closed")
            }
            TurboVecAdapterPlanError::BadProofRef(value) => {
                write!(f, "bad clean-room adapter proof ref {value}")
            }
            TurboVecAdapterPlanError::WeakVisibleSummary => {
                write!(f, "visible summary lacks required caveats")
            }
            TurboVecAdapterPlanError::InvalidByteLedger => {
                write!(f, "adapter plan byte ledger violates metadata-only scope")
            }
            TurboVecAdapterPlanError::ClaimBoundaryViolation => {
                write!(
                    f,
                    "adapter plan attempted hidden authority or product claim"
                )
            }
        }
    }
}

impl std::error::Error for TurboVecAdapterPlanError {}

pub fn clean_room_adapter_plan_digest(
    set: &TurboVecRealAdapterCleanRoomAdapterPlanProbeSet,
) -> String {
    let mut steps = set.steps.clone();
    steps.sort_by(|left, right| left.step_id.cmp(&right.step_id));
    sha256_hex(
        serde_json::to_string(&serde_json::json!({
            "upstream_motif_card_witness_ref": set.upstream_motif_card_witness_ref,
            "upstream_motif_card_address": set.upstream_motif_card_address.to_string(),
            "source_url": set.source_url,
            "pinned_revision": set.pinned_revision,
            "product_build": set.product_build,
            "pro_status": set.pro_status,
            "status": set.status,
            "tier": set.tier,
            "organs": set.organs,
            "steps": steps,
            "policy": set.policy,
            "proof_refs": set.proof_refs,
            "byte_ledger": set.byte_ledger,
            "product_capability_promoted": set.product_capability_promoted,
            "route_mutation_allowed": set.route_mutation_allowed,
            "model_context_injected": set.model_context_injected,
            "hidden_route_authority": set.hidden_route_authority,
            "hidden_cloud_fallback_allowed": set.hidden_cloud_fallback_allowed,
            "live_large_model_claimed": set.live_large_model_claimed,
            "ssd_as_ram_claimed": set.ssd_as_ram_claimed,
        }))
        .unwrap_or_default()
        .as_bytes(),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::str::FromStr;

    fn upstream() -> UasAddress {
        UasAddress::from_str(
            "turbovec_real_adapter_motif_extraction_card_probe:e1f5f570c45811e2e4323c2517120ead82ec8248a2f5c04e9b68dfa023e03610@1779040904000",
        )
        .expect("valid motif-card address")
    }

    fn step(id: &str, component: TurboVecAdapterPlanComponent) -> TurboVecAdapterPlanStep {
        TurboVecAdapterPlanStep {
            step_id: id.to_string(),
            component,
            organ: match component {
                TurboVecAdapterPlanComponent::UasExternalIdMap
                | TurboVecAdapterPlanComponent::VersionedRebuildFence
                | TurboVecAdapterPlanComponent::BufferBackedIoBoundary => {
                    TurboVecIndexOrgan::AppColdStore
                }
                TurboVecAdapterPlanComponent::AnswerPacketCaveat => TurboVecIndexOrgan::AnswerPacket,
                TurboVecAdapterPlanComponent::LargeModelWorkingSetCompiler => {
                    TurboVecIndexOrgan::SemanticWorkingSetPlan
                }
                _ => TurboVecIndexOrgan::Eidos,
            },
            source_motif_ids: vec![
                format!("{MOTIF_REF_PREFIX}{id}:primary"),
                format!("{MOTIF_REF_PREFIX}{id}:secondary"),
            ],
            plan_ref: format!("{PLAN_REF_PREFIX}{id}"),
            interface_summary: format!(
                "{id} clean-room interface specifies Epistemos-owned fields and tests for a rebuildable compressed retrieval adapter without copying upstream source or linking native code."
            ),
            invariant: format!(
                "{id} invariant requires UAS-addressed state, reversible proof, and fail-closed behavior before any route or runtime can cite the adapter."
            ),
            forbidden_action: format!(
                "{id} forbids product import, dependency insertion, benchmark authority, native-link probing, hidden route authority, and model-context injection."
            ),
            runtime_proof_required:
                "exact-baseline shadow replay and cancellation/rollback transcript required".to_string(),
            user_visible_proof_required:
                "AnswerPacket visible caveat with rejected candidates, byte ledger, rollback, and source refs required".to_string(),
            rollback_ref: format!("{ROLLBACK_REF_PREFIX}{id}"),
            no_upstream_source_import: true,
            no_product_dependency: true,
            no_native_link_probe: true,
            no_benchmark_authority: true,
            no_route_authority: true,
            no_model_context_injection: true,
        }
    }

    fn steps() -> Vec<TurboVecAdapterPlanStep> {
        vec![
            step(
                "uas_external_id_map",
                TurboVecAdapterPlanComponent::UasExternalIdMap,
            ),
            step(
                "filter_before_rank_pipeline",
                TurboVecAdapterPlanComponent::FilterBeforeRankPipeline,
            ),
            step(
                "buffer_backed_io_boundary",
                TurboVecAdapterPlanComponent::BufferBackedIoBoundary,
            ),
            step(
                "versioned_rebuild_fence",
                TurboVecAdapterPlanComponent::VersionedRebuildFence,
            ),
            step(
                "exact_baseline_shadow_replay",
                TurboVecAdapterPlanComponent::ExactBaselineShadowReplay,
            ),
            step(
                "privacy_latency_abstention",
                TurboVecAdapterPlanComponent::PrivacyLatencyAbstention,
            ),
            step(
                "cancellation_rollback_lease",
                TurboVecAdapterPlanComponent::CancellationRollbackLease,
            ),
            step(
                "answer_packet_caveat",
                TurboVecAdapterPlanComponent::AnswerPacketCaveat,
            ),
            step(
                "large_model_working_set_compiler",
                TurboVecAdapterPlanComponent::LargeModelWorkingSetCompiler,
            ),
            step(
                "no_native_link_default",
                TurboVecAdapterPlanComponent::NoNativeLinkDefault,
            ),
        ]
    }

    fn proofs() -> TurboVecAdapterPlanProofRefs {
        TurboVecAdapterPlanProofRefs {
            source_card_ref: format!("{SOURCE_CARD_REF_PREFIX}adapter-plan"),
            no_product_graph_ref: format!("{NO_PRODUCT_GRAPH_REF_PREFIX}adapter-plan"),
            exact_baseline_ref: format!("{BASELINE_REF_PREFIX}adapter-plan"),
            shadow_replay_ref: format!("{SHADOW_REPLAY_REF_PREFIX}adapter-plan"),
            rollback_ref: format!("{ROLLBACK_REF_PREFIX}adapter-plan"),
            run_event_log_ref: format!("{RUN_EVENT_LOG_REF_PREFIX}adapter-plan"),
            answer_packet_ref: format!("{ANSWER_PACKET_REF_PREFIX}adapter-plan"),
            compatibility_fence_ref: format!("{COMPATIBILITY_REF_PREFIX}adapter-plan"),
            visible_summary: "This clean-room adapter plan keeps TurboVec-derived motifs as Epistemos-owned design constraints for large local model working sets. It requires UAS stable IDs, filter-before-rank privacy, buffer-backed I/O, versioned rebuilds, exact-baseline shadow replay, cancellation, rollback, RunEventLog, and AnswerPacket caveats. It has no hidden route authority, no live dense 70B claim, no native-link build, no benchmark authority, no source import, no product dependency, and no model-context injection before later witnesses prove runtime behavior. It is intentionally plan-only, keeps compressed retrieval subordinate to Eidos/AppColdStore truth, and makes every future quality claim wait for held-out replay plus visible fallback."
                .to_string(),
        }
    }

    fn accepted(
    ) -> Result<TurboVecRealAdapterCleanRoomAdapterPlanProbeSet, TurboVecAdapterPlanError> {
        TurboVecRealAdapterCleanRoomAdapterPlanProbeSet::from_parts(
            upstream(),
            steps(),
            TurboVecAdapterPlanPolicy::fail_closed(),
            proofs(),
            TurboVecAdapterPlanByteLedger::metadata_only(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
            TurboVecAdapterPlanTier::T1L1Metadata,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        )
    }

    #[test]
    fn accepts_clean_room_adapter_plan() {
        let set = accepted().expect("accepted adapter plan");
        let metrics = set.metrics();
        assert_eq!(metrics.plan_step_count, 10);
        assert!(metrics.component_count >= 9);
        assert_eq!(metrics.additional_raw_source_bytes_inspected, 0);
        assert_eq!(metrics.product_dependencies_added, 0);
        assert_eq!(metrics.route_mutation_count, 0);
    }

    #[test]
    fn address_is_deterministic_when_steps_reordered() {
        let left = accepted().expect("accepted adapter plan");
        let mut reversed_steps = steps();
        reversed_steps.reverse();
        let right = TurboVecRealAdapterCleanRoomAdapterPlanProbeSet::from_parts(
            upstream(),
            reversed_steps,
            TurboVecAdapterPlanPolicy::fail_closed(),
            proofs(),
            TurboVecAdapterPlanByteLedger::metadata_only(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
            TurboVecAdapterPlanTier::T1L1Metadata,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        )
        .expect("reordered adapter plan");
        assert_eq!(left.set_address, right.set_address);
        assert_eq!(
            clean_room_adapter_plan_digest(&left),
            clean_room_adapter_plan_digest(&right)
        );
    }

    #[test]
    fn rejects_product_import_and_hidden_authority() {
        let mut bad_steps = steps();
        bad_steps[0].no_upstream_source_import = false;
        assert!(matches!(
            TurboVecRealAdapterCleanRoomAdapterPlanProbeSet::from_parts(
                upstream(),
                bad_steps,
                TurboVecAdapterPlanPolicy::fail_closed(),
                proofs(),
                TurboVecAdapterPlanByteLedger::metadata_only(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
                TurboVecAdapterPlanTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
            ),
            Err(TurboVecAdapterPlanError::UnsafeStep(_))
        ));

        assert!(matches!(
            TurboVecRealAdapterCleanRoomAdapterPlanProbeSet::from_parts(
                upstream(),
                steps(),
                TurboVecAdapterPlanPolicy::fail_closed(),
                proofs(),
                TurboVecAdapterPlanByteLedger::metadata_only(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
                TurboVecAdapterPlanTier::T1L1Metadata,
                false,
                true,
                false,
                true,
                false,
                false,
                false,
            ),
            Err(TurboVecAdapterPlanError::ClaimBoundaryViolation)
        ));
    }

    #[test]
    fn rejects_runtime_bytes_and_bad_promotion() {
        let mut ledger = TurboVecAdapterPlanByteLedger::metadata_only();
        ledger.adapter_build_count = 1;
        assert!(matches!(
            TurboVecRealAdapterCleanRoomAdapterPlanProbeSet::from_parts(
                upstream(),
                steps(),
                TurboVecAdapterPlanPolicy::fail_closed(),
                proofs(),
                ledger,
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
                TurboVecAdapterPlanTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
            ),
            Err(TurboVecAdapterPlanError::InvalidByteLedger)
        ));

        assert!(matches!(
            TurboVecRealAdapterCleanRoomAdapterPlanProbeSet::from_parts(
                upstream(),
                steps(),
                TurboVecAdapterPlanPolicy::fail_closed(),
                proofs(),
                TurboVecAdapterPlanByteLedger::metadata_only(),
                ProductBuild::Mas,
                ProStatus::ResearchCandidate,
                TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
                TurboVecAdapterPlanTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
            ),
            Err(TurboVecAdapterPlanError::PromotionBoundaryViolation)
        ));
    }

    #[test]
    fn rejects_missing_component_and_bad_upstream() {
        let mut fewer_steps = steps();
        fewer_steps.retain(|step| {
            step.component != TurboVecAdapterPlanComponent::ExactBaselineShadowReplay
        });
        assert!(matches!(
            TurboVecRealAdapterCleanRoomAdapterPlanProbeSet::from_parts(
                upstream(),
                fewer_steps,
                TurboVecAdapterPlanPolicy::fail_closed(),
                proofs(),
                TurboVecAdapterPlanByteLedger::metadata_only(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
                TurboVecAdapterPlanTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
            ),
            Err(TurboVecAdapterPlanError::MissingComponent(
                TurboVecAdapterPlanComponent::ExactBaselineShadowReplay
            ))
        ));

        let bad_upstream = UasAddress::new(UasKind::Other("wrong_cursor".to_string()), b"abc", 1);
        assert!(matches!(
            TurboVecRealAdapterCleanRoomAdapterPlanProbeSet::from_parts(
                bad_upstream,
                steps(),
                TurboVecAdapterPlanPolicy::fail_closed(),
                proofs(),
                TurboVecAdapterPlanByteLedger::metadata_only(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecAdapterPlanStatus::CleanRoomPlanOnly,
                TurboVecAdapterPlanTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
            ),
            Err(TurboVecAdapterPlanError::UpstreamMotifCardNotBound)
        ));
    }
}
