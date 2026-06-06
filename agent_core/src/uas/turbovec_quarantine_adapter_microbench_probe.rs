//! TurboVec quarantine adapter microbench probe.
//!
//! This primitive is the first tiny harness-shaped step after the runtime
//! shadow benchmark plan. It remains synthetic and non-authoritative: no
//! TurboVec crate is imported, no product index is opened, no model bytes are
//! loaded, and no route/context mutation is allowed.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild, TurboVecIndexOrgan, UasAddress, UasKind};

pub const TURBOVEC_QUARANTINE_ADAPTER_MICROBENCH_CURSOR: &str =
    "turbovec_quarantine_adapter_microbench_probe";
pub const TURBOVEC_QUARANTINE_ADAPTER_MICROBENCH_NEXT_CURSOR: &str =
    "turbovec_quarantine_real_adapter_owner_approval_probe";

const UPSTREAM_WITNESS_REF: &str = "artifact:turbovec_runtime_shadow_benchmark_plan:result";
const FALSIFIER_PREFIX: &str = "falsifier:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const FALLBACK_PREFIX: &str = "fallback:";
const MICROBENCH_REASON_PREFIX: &str = "microbench:";
const PROVENANCE_PREFIX: &str = "provenance:";
const ALLOWLIST_PREFIX: &str = "allowlist:";
const EXACT_BASELINE_PREFIX: &str = "exact_baseline:";
const MAX_METADATA_BYTES: u64 = 512 * 1024;
const MAX_FIXTURE_BYTES: u64 = 192 * 1024;
const MIN_VECTOR_DIMENSION: u64 = 8;
const MAX_VECTOR_DIMENSION: u64 = 4096;
const MAX_VECTOR_COUNT: u64 = 4096;
const MAX_TOP_K: u64 = 50;

// UAS: uas:turbovec-quarantine-microbench:status
// Plane: Verification
// Residency: synthetic quarantine harness status only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecQuarantineMicrobenchStatus {
    SyntheticHarnessOnly,
    Blocked,
    ApprovedOnlyByLaterWitness,
}

// UAS: uas:turbovec-quarantine-microbench:tier
// Plane: Verification
// Residency: this witness permits T0/T1 only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecQuarantineMicrobenchPromotionTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:turbovec-quarantine-microbench:adapter-mode
// Plane: Assembly + Verification
// Residency: import mode for this probe.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecQuarantineAdapterMode {
    SyntheticHarnessOnly,
    QuarantineReference,
    AdapterWrap,
    DirectImport,
    ProductIntegrated,
}

// UAS: uas:turbovec-quarantine-microbench:scenario
// Plane: Verification
// Residency: tiny deterministic microbench case class.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecQuarantineMicrobenchScenario {
    WarmApproxWin,
    ColdExactFallback,
    RecallLossFallback,
    CancellationFallback,
    EmptyAllowlistVisible,
    AdapterPanicFallback,
}

// UAS: uas:turbovec-quarantine-microbench:decision
// Plane: Controller + Verification
// Residency: non-authoritative evidence decision.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecQuarantineMicrobenchDecision {
    RecordNonAuthoritativeWin,
    ExactFallback,
    RecallFallback,
    CancelFallback,
    EmptyVisible,
    PanicFallback,
}

// UAS: uas:turbovec-quarantine-microbench:case
// Plane: Assembly + Controller + Verification
// Residency: synthetic tiny microbench; no product/model bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecQuarantineMicrobenchCase {
    pub case_id: String,
    pub scenario: TurboVecQuarantineMicrobenchScenario,
    pub query_uas_address: UasAddress,
    pub deterministic_seed: u64,
    pub vector_dimension: u64,
    pub vector_count: u64,
    pub top_k: u64,
    pub allowlist_count: u64,
    pub exact_baseline_ref: String,
    pub allowlist_proof_ref: String,
    pub exact_top1_uas_ref: String,
    pub adapter_top1_uas_ref: String,
    pub exact_recall_at_k_micros: u64,
    pub adapter_recall_at_k_micros: u64,
    pub recall_floor_micros: u64,
    pub max_allowed_recall_delta_micros: u64,
    pub predicted_p50_latency_micros: u64,
    pub predicted_p95_latency_micros: u64,
    pub predicted_p99_latency_micros: u64,
    pub latency_budget_micros: u64,
    pub timeout_micros: u64,
    pub cancellation_deadline_micros: u64,
    pub synthetic_vector_bytes: u64,
    pub synthetic_scratch_bytes: u64,
    pub synthetic_total_bytes: u64,
    pub memory_budget_bytes: u64,
    pub memory_headroom_bytes: i64,
    pub decision: TurboVecQuarantineMicrobenchDecision,
    pub non_authoritative_output: bool,
    pub adapter_panic_caught: bool,
    pub fallback_reason_ref: Option<String>,
    pub fallback_route_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub route_mutation_allowed: bool,
    pub model_context_injected: bool,
}

impl TurboVecQuarantineMicrobenchCase {
    pub fn recompute_totals(&mut self) {
        self.synthetic_total_bytes = self
            .synthetic_vector_bytes
            .saturating_add(self.synthetic_scratch_bytes);
        self.memory_headroom_bytes =
            self.memory_budget_bytes as i64 - self.synthetic_total_bytes as i64;
    }

    pub fn latency_fits(&self) -> bool {
        self.predicted_p95_latency_micros <= self.latency_budget_micros
            && self.predicted_p99_latency_micros <= self.timeout_micros
    }

    pub fn memory_fits(&self) -> bool {
        self.memory_headroom_bytes >= 0
    }

    pub fn recall_delta_micros(&self) -> u64 {
        self.exact_recall_at_k_micros
            .saturating_sub(self.adapter_recall_at_k_micros)
    }

    pub fn recall_fits(&self) -> bool {
        self.adapter_recall_at_k_micros >= self.recall_floor_micros
            && self.recall_delta_micros() <= self.max_allowed_recall_delta_micros
    }

    pub fn non_authoritative_win_allowed(&self) -> bool {
        self.latency_fits() && self.memory_fits() && self.recall_fits()
    }
}

// UAS: uas:turbovec-quarantine-microbench:policy
// Plane: Controller + Verification
// Residency: fail-closed quarantine microbench policy.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecQuarantineMicrobenchPolicy {
    pub upstream_shadow_plan_required: bool,
    pub synthetic_fixture_only: bool,
    pub deterministic_seed_required: bool,
    pub quarantine_reference_required_before_external_code: bool,
    pub direct_import_forbidden: bool,
    pub product_integration_forbidden: bool,
    pub exact_baseline_required: bool,
    pub allowlist_before_rank_required: bool,
    pub panic_containment_required: bool,
    pub cancellation_required: bool,
    pub non_authoritative_output_required: bool,
    pub route_mutation_forbidden: bool,
    pub model_context_injection_forbidden: bool,
    pub fallback_required_for_loss: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub compatibility_fence_required: bool,
    pub product_bytes_forbidden: bool,
}

impl TurboVecQuarantineMicrobenchPolicy {
    pub fn fail_closed() -> Self {
        Self {
            upstream_shadow_plan_required: true,
            synthetic_fixture_only: true,
            deterministic_seed_required: true,
            quarantine_reference_required_before_external_code: true,
            direct_import_forbidden: true,
            product_integration_forbidden: true,
            exact_baseline_required: true,
            allowlist_before_rank_required: true,
            panic_containment_required: true,
            cancellation_required: true,
            non_authoritative_output_required: true,
            route_mutation_forbidden: true,
            model_context_injection_forbidden: true,
            fallback_required_for_loss: true,
            rollback_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            compatibility_fence_required: true,
            product_bytes_forbidden: true,
        }
    }
}

// UAS: uas:turbovec-quarantine-microbench:byte-ledger
// Plane: Verification
// Residency: synthetic fixture byte proof boundary.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecQuarantineMicrobenchByteLedger {
    pub metadata_bytes_read: u64,
    pub fixture_bytes_read: u64,
    pub synthetic_vector_bytes: u64,
    pub synthetic_scratch_bytes: u64,
    pub opened_product_index_bytes: u64,
    pub loaded_product_index_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub copied_product_file_count: u64,
    pub imported_external_crate_count: u64,
    pub quarantined_external_code_bytes: u64,
}

impl TurboVecQuarantineMicrobenchByteLedger {
    pub fn synthetic_only(
        metadata_bytes_read: u64,
        fixture_bytes_read: u64,
        synthetic_vector_bytes: u64,
        synthetic_scratch_bytes: u64,
    ) -> Result<Self, TurboVecQuarantineMicrobenchError> {
        if metadata_bytes_read > MAX_METADATA_BYTES || fixture_bytes_read > MAX_FIXTURE_BYTES {
            return Err(TurboVecQuarantineMicrobenchError::MetadataBudgetExceeded {
                metadata_bytes_read,
                fixture_bytes_read,
            });
        }
        Ok(Self {
            metadata_bytes_read,
            fixture_bytes_read,
            synthetic_vector_bytes,
            synthetic_scratch_bytes,
            opened_product_index_bytes: 0,
            loaded_product_index_bytes: 0,
            model_bytes_loaded: 0,
            runtime_model_bytes_loaded: 0,
            provider_calls_made: 0,
            copied_product_file_count: 0,
            imported_external_crate_count: 0,
            quarantined_external_code_bytes: 0,
        })
    }

    pub fn synthetic_total_bytes(&self) -> u64 {
        self.synthetic_vector_bytes
            .saturating_add(self.synthetic_scratch_bytes)
    }
}

// UAS: uas:turbovec-quarantine-microbench:proof-refs
// Plane: Verification
// Residency: visible witness surfaces for non-promotion.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecQuarantineMicrobenchProofRefs {
    pub falsifier_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
    pub provenance_ref: String,
}

// UAS: uas:turbovec-quarantine-microbench:probe
// Plane: Assembly + Controller + Verification
// Residency: synthetic quarantine microbench probe.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecQuarantineAdapterMicrobenchProbe {
    pub probe_id: String,
    pub upstream_shadow_address: UasAddress,
    pub upstream_shadow_witness_ref: String,
    pub status: TurboVecQuarantineMicrobenchStatus,
    pub promotion_tier: TurboVecQuarantineMicrobenchPromotionTier,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub adapter_mode: TurboVecQuarantineAdapterMode,
    pub organs: Vec<TurboVecIndexOrgan>,
    pub policy: TurboVecQuarantineMicrobenchPolicy,
    pub cases: Vec<TurboVecQuarantineMicrobenchCase>,
    pub byte_ledger: TurboVecQuarantineMicrobenchByteLedger,
    pub proof_refs: TurboVecQuarantineMicrobenchProofRefs,
    pub hidden_route_authority: bool,
    pub product_capability_promoted: bool,
    pub live_large_model_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:turbovec-quarantine-microbench:probe-set
// Plane: Verification
// Residency: deterministic set-level witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecQuarantineAdapterMicrobenchProbeSet {
    pub set_address: UasAddress,
    pub upstream_shadow_address: UasAddress,
    pub upstream_shadow_witness_ref: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub status: TurboVecQuarantineMicrobenchStatus,
    pub promotion_tier: TurboVecQuarantineMicrobenchPromotionTier,
    pub probes: Vec<TurboVecQuarantineAdapterMicrobenchProbe>,
    pub metadata_bytes_read: u64,
    pub fixture_bytes_read: u64,
    pub product_capability_promoted: bool,
}

// UAS: uas:turbovec-quarantine-microbench:metrics
// Plane: Verification
// Residency: derived counters for artifact axes.
#[derive(Clone, Debug, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct TurboVecQuarantineMicrobenchMetrics {
    pub probe_count: u64,
    pub case_count: u64,
    pub warm_approx_win_count: u64,
    pub cold_exact_fallback_count: u64,
    pub recall_loss_fallback_count: u64,
    pub cancellation_fallback_count: u64,
    pub empty_allowlist_count: u64,
    pub panic_fallback_count: u64,
    pub non_authoritative_win_count: u64,
    pub fallback_case_count: u64,
    pub missing_reason_count: u64,
    pub adapter_panic_caught_count: u64,
    pub route_mutation_count: u64,
    pub model_context_injection_count: u64,
    pub max_vector_dimension: u64,
    pub max_vector_count: u64,
    pub max_predicted_p99_latency_micros: u64,
    pub max_synthetic_total_bytes: u64,
    pub min_memory_headroom_bytes: i64,
    pub max_recall_delta_micros: u64,
    pub opened_product_index_bytes: u64,
    pub loaded_product_index_bytes: u64,
    pub model_bytes_loaded: u64,
    pub runtime_model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub copied_product_file_count: u64,
    pub imported_external_crate_count: u64,
    pub quarantined_external_code_bytes: u64,
}

impl TurboVecQuarantineAdapterMicrobenchProbeSet {
    pub fn from_probes(
        upstream_shadow_address: UasAddress,
        mut probes: Vec<TurboVecQuarantineAdapterMicrobenchProbe>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        status: TurboVecQuarantineMicrobenchStatus,
        promotion_tier: TurboVecQuarantineMicrobenchPromotionTier,
        metadata_bytes_read: u64,
        fixture_bytes_read: u64,
        product_capability_promoted: bool,
    ) -> Result<Self, TurboVecQuarantineMicrobenchError> {
        probes.sort_by(|left, right| left.probe_id.cmp(&right.probe_id));
        validate_set_inputs(
            &upstream_shadow_address,
            &probes,
            &product_build,
            &pro_status,
            &status,
            &promotion_tier,
            metadata_bytes_read,
            fixture_bytes_read,
            product_capability_promoted,
        )?;
        for probe in &probes {
            validate_probe(probe, &upstream_shadow_address)?;
        }
        let set_address =
            deterministic_set_address(&probes, metadata_bytes_read, fixture_bytes_read);
        Ok(Self {
            set_address,
            upstream_shadow_address,
            upstream_shadow_witness_ref: UPSTREAM_WITNESS_REF.to_string(),
            product_build,
            pro_status,
            status,
            promotion_tier,
            probes,
            metadata_bytes_read,
            fixture_bytes_read,
            product_capability_promoted,
        })
    }

    pub fn metrics(&self) -> TurboVecQuarantineMicrobenchMetrics {
        let mut metrics = TurboVecQuarantineMicrobenchMetrics {
            probe_count: self.probes.len() as u64,
            min_memory_headroom_bytes: i64::MAX,
            ..TurboVecQuarantineMicrobenchMetrics::default()
        };
        for probe in &self.probes {
            metrics.opened_product_index_bytes += probe.byte_ledger.opened_product_index_bytes;
            metrics.loaded_product_index_bytes += probe.byte_ledger.loaded_product_index_bytes;
            metrics.model_bytes_loaded += probe.byte_ledger.model_bytes_loaded;
            metrics.runtime_model_bytes_loaded += probe.byte_ledger.runtime_model_bytes_loaded;
            metrics.provider_calls_made += probe.byte_ledger.provider_calls_made;
            metrics.copied_product_file_count += probe.byte_ledger.copied_product_file_count;
            metrics.imported_external_crate_count +=
                probe.byte_ledger.imported_external_crate_count;
            metrics.quarantined_external_code_bytes +=
                probe.byte_ledger.quarantined_external_code_bytes;
            for case in &probe.cases {
                metrics.case_count += 1;
                metrics.max_vector_dimension =
                    metrics.max_vector_dimension.max(case.vector_dimension);
                metrics.max_vector_count = metrics.max_vector_count.max(case.vector_count);
                metrics.max_predicted_p99_latency_micros = metrics
                    .max_predicted_p99_latency_micros
                    .max(case.predicted_p99_latency_micros);
                metrics.max_synthetic_total_bytes = metrics
                    .max_synthetic_total_bytes
                    .max(case.synthetic_total_bytes);
                metrics.min_memory_headroom_bytes = metrics
                    .min_memory_headroom_bytes
                    .min(case.memory_headroom_bytes);
                metrics.max_recall_delta_micros = metrics
                    .max_recall_delta_micros
                    .max(case.recall_delta_micros());
                match case.scenario {
                    TurboVecQuarantineMicrobenchScenario::WarmApproxWin => {
                        metrics.warm_approx_win_count += 1
                    }
                    TurboVecQuarantineMicrobenchScenario::ColdExactFallback => {
                        metrics.cold_exact_fallback_count += 1
                    }
                    TurboVecQuarantineMicrobenchScenario::RecallLossFallback => {
                        metrics.recall_loss_fallback_count += 1
                    }
                    TurboVecQuarantineMicrobenchScenario::CancellationFallback => {
                        metrics.cancellation_fallback_count += 1
                    }
                    TurboVecQuarantineMicrobenchScenario::EmptyAllowlistVisible => {
                        metrics.empty_allowlist_count += 1
                    }
                    TurboVecQuarantineMicrobenchScenario::AdapterPanicFallback => {
                        metrics.panic_fallback_count += 1
                    }
                }
                if matches!(
                    case.decision,
                    TurboVecQuarantineMicrobenchDecision::RecordNonAuthoritativeWin
                ) {
                    metrics.non_authoritative_win_count += 1;
                } else {
                    metrics.fallback_case_count += 1;
                    if case.fallback_reason_ref.is_none() {
                        metrics.missing_reason_count += 1;
                    }
                }
                if case.adapter_panic_caught {
                    metrics.adapter_panic_caught_count += 1;
                }
                if case.route_mutation_allowed {
                    metrics.route_mutation_count += 1;
                }
                if case.model_context_injected {
                    metrics.model_context_injection_count += 1;
                }
            }
        }
        if metrics.min_memory_headroom_bytes == i64::MAX {
            metrics.min_memory_headroom_bytes = 0;
        }
        metrics
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: TurboVecQuarantineAdapterMicrobenchProbe validation error.
// Plane: Verification.
// Residency: Synthetic-only diagnostic; no model/product bytes.
pub enum TurboVecQuarantineMicrobenchError {
    BadUpstreamCursor,
    MissingUpstreamShadowPlan,
    EmptyProbes,
    DuplicateProbeId(String),
    BadProductBuild(ProductBuild),
    BadProStatus(ProStatus),
    BadStatus(TurboVecQuarantineMicrobenchStatus),
    BadPromotionTier(TurboVecQuarantineMicrobenchPromotionTier),
    MetadataBudgetExceeded {
        metadata_bytes_read: u64,
        fixture_bytes_read: u64,
    },
    SetPromotionAllowed,
    BadAdapterMode(TurboVecQuarantineAdapterMode),
    MissingField {
        field: &'static str,
        probe_id: String,
    },
    BadPrefix {
        field: &'static str,
        value: String,
        expected: &'static str,
    },
    InvalidOrgans(String),
    InvalidPolicy(String),
    EmptyCases(String),
    DuplicateCaseId(String),
    MissingCaseCoverage(String),
    InvalidCase {
        case_id: String,
        reason: String,
    },
    ProductBytesLoaded(String),
    HiddenAuthority(String),
    ProductPromotionAllowed(String),
    LiveLargeModelClaimed(String),
    SsdAsRamClaimed(String),
}

impl fmt::Display for TurboVecQuarantineMicrobenchError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamCursor => write!(f, "bad upstream shadow benchmark cursor"),
            Self::MissingUpstreamShadowPlan => write!(f, "missing upstream shadow benchmark plan"),
            Self::EmptyProbes => write!(f, "TurboVec quarantine microbench set is empty"),
            Self::DuplicateProbeId(id) => write!(f, "duplicate microbench probe id `{id}`"),
            Self::BadProductBuild(build) => write!(f, "bad product build: {build:?}"),
            Self::BadProStatus(status) => write!(f, "bad ProStatus: {status:?}"),
            Self::BadStatus(status) => write!(f, "bad microbench status: {status:?}"),
            Self::BadPromotionTier(tier) => write!(f, "bad microbench tier: {tier:?}"),
            Self::MetadataBudgetExceeded {
                metadata_bytes_read,
                fixture_bytes_read,
            } => write!(
                f,
                "metadata budget exceeded: metadata={metadata_bytes_read} fixture={fixture_bytes_read}"
            ),
            Self::SetPromotionAllowed => write!(f, "microbench set promoted capability"),
            Self::BadAdapterMode(mode) => write!(f, "bad adapter mode for this probe: {mode:?}"),
            Self::MissingField { field, probe_id } => {
                write!(f, "probe `{probe_id}` missing field `{field}`")
            }
            Self::BadPrefix {
                field,
                value,
                expected,
            } => write!(
                f,
                "field `{field}` value `{value}` must start with `{expected}`"
            ),
            Self::InvalidOrgans(id) => write!(f, "probe `{id}` missing required organs"),
            Self::InvalidPolicy(reason) => write!(f, "invalid microbench policy: {reason}"),
            Self::EmptyCases(id) => write!(f, "probe `{id}` has no cases"),
            Self::DuplicateCaseId(id) => write!(f, "duplicate microbench case id `{id}`"),
            Self::MissingCaseCoverage(id) => {
                write!(f, "probe `{id}` missing scenario coverage")
            }
            Self::InvalidCase { case_id, reason } => {
                write!(f, "invalid microbench case `{case_id}`: {reason}")
            }
            Self::ProductBytesLoaded(id) => write!(
                f,
                "probe `{id}` opened/imported product, model, provider, or external code bytes"
            ),
            Self::HiddenAuthority(id) => write!(f, "probe `{id}` allows hidden route authority"),
            Self::ProductPromotionAllowed(id) => write!(f, "probe `{id}` promoted capability"),
            Self::LiveLargeModelClaimed(id) => {
                write!(f, "probe `{id}` claimed live large-model capability")
            }
            Self::SsdAsRamClaimed(id) => write!(f, "probe `{id}` claimed SSD as RAM"),
        }
    }
}

impl std::error::Error for TurboVecQuarantineMicrobenchError {}

fn validate_set_inputs(
    upstream_shadow_address: &UasAddress,
    probes: &[TurboVecQuarantineAdapterMicrobenchProbe],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    status: &TurboVecQuarantineMicrobenchStatus,
    promotion_tier: &TurboVecQuarantineMicrobenchPromotionTier,
    metadata_bytes_read: u64,
    fixture_bytes_read: u64,
    product_capability_promoted: bool,
) -> Result<(), TurboVecQuarantineMicrobenchError> {
    if !matches!(
        upstream_shadow_address.kind,
        UasKind::Other(ref tag) if tag == "turbovec_runtime_shadow_benchmark_plan"
    ) {
        return Err(TurboVecQuarantineMicrobenchError::BadUpstreamCursor);
    }
    if probes.is_empty() {
        return Err(TurboVecQuarantineMicrobenchError::EmptyProbes);
    }
    if metadata_bytes_read > MAX_METADATA_BYTES || fixture_bytes_read > MAX_FIXTURE_BYTES {
        return Err(TurboVecQuarantineMicrobenchError::MetadataBudgetExceeded {
            metadata_bytes_read,
            fixture_bytes_read,
        });
    }
    if product_capability_promoted {
        return Err(TurboVecQuarantineMicrobenchError::SetPromotionAllowed);
    }
    if !matches!(product_build, ProductBuild::Pro) {
        return Err(TurboVecQuarantineMicrobenchError::BadProductBuild(
            product_build.clone(),
        ));
    }
    if !matches!(pro_status, ProStatus::ResearchCandidate) {
        return Err(TurboVecQuarantineMicrobenchError::BadProStatus(
            pro_status.clone(),
        ));
    }
    if !matches!(
        status,
        TurboVecQuarantineMicrobenchStatus::SyntheticHarnessOnly
    ) {
        return Err(TurboVecQuarantineMicrobenchError::BadStatus(*status));
    }
    if !matches!(
        promotion_tier,
        TurboVecQuarantineMicrobenchPromotionTier::T1L1Metadata
    ) {
        return Err(TurboVecQuarantineMicrobenchError::BadPromotionTier(
            *promotion_tier,
        ));
    }
    let mut ids = HashSet::with_capacity(probes.len());
    for probe in probes {
        if !ids.insert(probe.probe_id.clone()) {
            return Err(TurboVecQuarantineMicrobenchError::DuplicateProbeId(
                probe.probe_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_probe(
    probe: &TurboVecQuarantineAdapterMicrobenchProbe,
    upstream_shadow_address: &UasAddress,
) -> Result<(), TurboVecQuarantineMicrobenchError> {
    require_nonempty(&probe.probe_id, "probe_id", &probe.probe_id)?;
    if probe.upstream_shadow_address != *upstream_shadow_address {
        return Err(TurboVecQuarantineMicrobenchError::MissingUpstreamShadowPlan);
    }
    require_prefix(
        "upstream_shadow_witness_ref",
        &probe.upstream_shadow_witness_ref,
        UPSTREAM_WITNESS_REF,
    )?;
    if !matches!(probe.product_build, ProductBuild::Pro) {
        return Err(TurboVecQuarantineMicrobenchError::BadProductBuild(
            probe.product_build.clone(),
        ));
    }
    if !matches!(probe.pro_status, ProStatus::ResearchCandidate) {
        return Err(TurboVecQuarantineMicrobenchError::BadProStatus(
            probe.pro_status.clone(),
        ));
    }
    if !matches!(
        probe.status,
        TurboVecQuarantineMicrobenchStatus::SyntheticHarnessOnly
    ) {
        return Err(TurboVecQuarantineMicrobenchError::BadStatus(probe.status));
    }
    if !matches!(
        probe.promotion_tier,
        TurboVecQuarantineMicrobenchPromotionTier::T1L1Metadata
    ) {
        return Err(TurboVecQuarantineMicrobenchError::BadPromotionTier(
            probe.promotion_tier,
        ));
    }
    if !matches!(
        probe.adapter_mode,
        TurboVecQuarantineAdapterMode::SyntheticHarnessOnly
    ) {
        return Err(TurboVecQuarantineMicrobenchError::BadAdapterMode(
            probe.adapter_mode,
        ));
    }
    validate_organs(probe)?;
    validate_policy(&probe.policy)?;
    validate_cases(probe)?;
    validate_byte_ledger(probe)?;
    validate_proof_refs(&probe.probe_id, &probe.proof_refs)?;
    if probe.hidden_route_authority {
        return Err(TurboVecQuarantineMicrobenchError::HiddenAuthority(
            probe.probe_id.clone(),
        ));
    }
    if probe.product_capability_promoted {
        return Err(TurboVecQuarantineMicrobenchError::ProductPromotionAllowed(
            probe.probe_id.clone(),
        ));
    }
    if probe.live_large_model_claimed {
        return Err(TurboVecQuarantineMicrobenchError::LiveLargeModelClaimed(
            probe.probe_id.clone(),
        ));
    }
    if probe.ssd_as_ram_claimed {
        return Err(TurboVecQuarantineMicrobenchError::SsdAsRamClaimed(
            probe.probe_id.clone(),
        ));
    }
    Ok(())
}

fn validate_organs(
    probe: &TurboVecQuarantineAdapterMicrobenchProbe,
) -> Result<(), TurboVecQuarantineMicrobenchError> {
    let organs: HashSet<TurboVecIndexOrgan> = probe.organs.iter().copied().collect();
    for required in [
        TurboVecIndexOrgan::Eidos,
        TurboVecIndexOrgan::AppColdStore,
        TurboVecIndexOrgan::SemanticWorkingSetPlan,
        TurboVecIndexOrgan::AnswerPacket,
    ] {
        if !organs.contains(&required) {
            return Err(TurboVecQuarantineMicrobenchError::InvalidOrgans(
                probe.probe_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_policy(
    policy: &TurboVecQuarantineMicrobenchPolicy,
) -> Result<(), TurboVecQuarantineMicrobenchError> {
    if !policy.upstream_shadow_plan_required
        || !policy.synthetic_fixture_only
        || !policy.deterministic_seed_required
        || !policy.quarantine_reference_required_before_external_code
        || !policy.direct_import_forbidden
        || !policy.product_integration_forbidden
        || !policy.exact_baseline_required
        || !policy.allowlist_before_rank_required
        || !policy.panic_containment_required
        || !policy.cancellation_required
        || !policy.non_authoritative_output_required
        || !policy.route_mutation_forbidden
        || !policy.model_context_injection_forbidden
        || !policy.fallback_required_for_loss
        || !policy.rollback_required
        || !policy.run_event_log_required
        || !policy.answer_packet_required
        || !policy.compatibility_fence_required
        || !policy.product_bytes_forbidden
    {
        return Err(TurboVecQuarantineMicrobenchError::InvalidPolicy(
            "required fail-closed policy bit missing".to_string(),
        ));
    }
    Ok(())
}

fn validate_cases(
    probe: &TurboVecQuarantineAdapterMicrobenchProbe,
) -> Result<(), TurboVecQuarantineMicrobenchError> {
    if probe.cases.is_empty() {
        return Err(TurboVecQuarantineMicrobenchError::EmptyCases(
            probe.probe_id.clone(),
        ));
    }
    let kinds: HashSet<TurboVecQuarantineMicrobenchScenario> =
        probe.cases.iter().map(|case| case.scenario).collect();
    for required in [
        TurboVecQuarantineMicrobenchScenario::WarmApproxWin,
        TurboVecQuarantineMicrobenchScenario::ColdExactFallback,
        TurboVecQuarantineMicrobenchScenario::RecallLossFallback,
        TurboVecQuarantineMicrobenchScenario::CancellationFallback,
        TurboVecQuarantineMicrobenchScenario::EmptyAllowlistVisible,
        TurboVecQuarantineMicrobenchScenario::AdapterPanicFallback,
    ] {
        if !kinds.contains(&required) {
            return Err(TurboVecQuarantineMicrobenchError::MissingCaseCoverage(
                probe.probe_id.clone(),
            ));
        }
    }
    let mut ids = HashSet::with_capacity(probe.cases.len());
    for case in &probe.cases {
        if !ids.insert(case.case_id.clone()) {
            return Err(TurboVecQuarantineMicrobenchError::DuplicateCaseId(
                case.case_id.clone(),
            ));
        }
        validate_case(case)?;
    }
    Ok(())
}

fn validate_case(
    case: &TurboVecQuarantineMicrobenchCase,
) -> Result<(), TurboVecQuarantineMicrobenchError> {
    require_nonempty(&case.case_id, "case_id", &case.case_id)?;
    for (field, value, prefix) in [
        (
            "exact_baseline_ref",
            &case.exact_baseline_ref,
            EXACT_BASELINE_PREFIX,
        ),
        (
            "allowlist_proof_ref",
            &case.allowlist_proof_ref,
            ALLOWLIST_PREFIX,
        ),
        (
            "fallback_route_ref",
            &case.fallback_route_ref,
            FALLBACK_PREFIX,
        ),
        ("rollback_ref", &case.rollback_ref, ROLLBACK_PREFIX),
        (
            "run_event_log_ref",
            &case.run_event_log_ref,
            RUN_EVENT_LOG_PREFIX,
        ),
        (
            "answer_packet_ref",
            &case.answer_packet_ref,
            ANSWER_PACKET_PREFIX,
        ),
    ] {
        require_prefix(field, value, prefix)?;
    }
    require_nonempty(
        &case.exact_top1_uas_ref,
        "exact_top1_uas_ref",
        &case.case_id,
    )?;
    require_nonempty(
        &case.adapter_top1_uas_ref,
        "adapter_top1_uas_ref",
        &case.case_id,
    )?;
    if case.deterministic_seed == 0 {
        return invalid_case(case, "deterministic seed is required");
    }
    if !(MIN_VECTOR_DIMENSION..=MAX_VECTOR_DIMENSION).contains(&case.vector_dimension) {
        return invalid_case(case, "vector dimension outside supported synthetic range");
    }
    if case.vector_count == 0 || case.vector_count > MAX_VECTOR_COUNT {
        return invalid_case(case, "vector count outside supported synthetic range");
    }
    if case.top_k == 0 || case.top_k > MAX_TOP_K {
        return invalid_case(case, "top_k must be in 1..=50");
    }
    if case.allowlist_count > case.vector_count {
        return invalid_case(case, "allowlist count exceeds vector count");
    }
    if matches!(
        case.scenario,
        TurboVecQuarantineMicrobenchScenario::EmptyAllowlistVisible
    ) && case.allowlist_count != 0
    {
        return invalid_case(case, "empty allowlist scenario must have zero allowed IDs");
    }
    if !matches!(
        case.scenario,
        TurboVecQuarantineMicrobenchScenario::EmptyAllowlistVisible
    ) && case.allowlist_count == 0
    {
        return invalid_case(case, "non-empty scenario requires at least one allowed ID");
    }
    if case.exact_recall_at_k_micros > 1_000_000
        || case.adapter_recall_at_k_micros > 1_000_000
        || case.recall_floor_micros < 850_000
        || case.recall_floor_micros > 1_000_000
    {
        return invalid_case(case, "recall micros must stay inside exact-baseline bounds");
    }
    if case.predicted_p50_latency_micros == 0
        || case.predicted_p95_latency_micros == 0
        || case.predicted_p99_latency_micros == 0
        || case.predicted_p50_latency_micros > case.predicted_p95_latency_micros
        || case.predicted_p95_latency_micros > case.predicted_p99_latency_micros
    {
        return invalid_case(case, "latency percentiles must be nonzero and ordered");
    }
    if case.latency_budget_micros == 0
        || case.timeout_micros == 0
        || case.cancellation_deadline_micros == 0
        || case.memory_budget_bytes == 0
    {
        return invalid_case(
            case,
            "latency, timeout, cancellation, and memory budgets are required",
        );
    }
    if case.cancellation_deadline_micros > case.timeout_micros {
        return invalid_case(case, "cancellation deadline must not exceed timeout");
    }
    if case
        .synthetic_vector_bytes
        .saturating_add(case.synthetic_scratch_bytes)
        != case.synthetic_total_bytes
    {
        return invalid_case(case, "synthetic byte total is inconsistent");
    }
    if case.route_mutation_allowed {
        return invalid_case(case, "microbench allows route mutation");
    }
    if case.model_context_injected {
        return invalid_case(case, "microbench injects model context");
    }
    if !case.non_authoritative_output {
        return invalid_case(case, "microbench output must be non-authoritative");
    }
    match case.decision {
        TurboVecQuarantineMicrobenchDecision::RecordNonAuthoritativeWin => {
            if !matches!(
                case.scenario,
                TurboVecQuarantineMicrobenchScenario::WarmApproxWin
            ) {
                return invalid_case(case, "only warm approximate win may record first win");
            }
            if !case.non_authoritative_win_allowed() || case.fallback_reason_ref.is_some() {
                return invalid_case(case, "non-authoritative win lacks budget/recall support");
            }
        }
        TurboVecQuarantineMicrobenchDecision::ExactFallback => {
            require_fallback_reason(case)?;
            if !matches!(
                case.scenario,
                TurboVecQuarantineMicrobenchScenario::ColdExactFallback
            ) {
                return invalid_case(case, "exact fallback scenario mismatch");
            }
        }
        TurboVecQuarantineMicrobenchDecision::RecallFallback => {
            require_fallback_reason(case)?;
            if case.recall_fits() {
                return invalid_case(
                    case,
                    "recall fallback requires below-floor or high-delta recall",
                );
            }
        }
        TurboVecQuarantineMicrobenchDecision::CancelFallback => {
            require_fallback_reason(case)?;
            if case.latency_fits() {
                return invalid_case(case, "cancellation fallback needs timeout pressure");
            }
        }
        TurboVecQuarantineMicrobenchDecision::EmptyVisible => {
            require_fallback_reason(case)?;
            if case.allowlist_count != 0 {
                return invalid_case(case, "empty visible fallback cannot have allowed IDs");
            }
        }
        TurboVecQuarantineMicrobenchDecision::PanicFallback => {
            require_fallback_reason(case)?;
            if !case.adapter_panic_caught {
                return invalid_case(case, "panic fallback must catch adapter panic/error");
            }
        }
    }
    Ok(())
}

fn require_fallback_reason(
    case: &TurboVecQuarantineMicrobenchCase,
) -> Result<(), TurboVecQuarantineMicrobenchError> {
    let Some(reason) = case.fallback_reason_ref.as_ref() else {
        return invalid_case(case, "fallback reason is required");
    };
    if !reason.starts_with(MICROBENCH_REASON_PREFIX) {
        return invalid_case(case, "fallback reason prefix is invalid");
    }
    Ok(())
}

fn validate_byte_ledger(
    probe: &TurboVecQuarantineAdapterMicrobenchProbe,
) -> Result<(), TurboVecQuarantineMicrobenchError> {
    if probe.byte_ledger.metadata_bytes_read > MAX_METADATA_BYTES
        || probe.byte_ledger.fixture_bytes_read > MAX_FIXTURE_BYTES
    {
        return Err(TurboVecQuarantineMicrobenchError::MetadataBudgetExceeded {
            metadata_bytes_read: probe.byte_ledger.metadata_bytes_read,
            fixture_bytes_read: probe.byte_ledger.fixture_bytes_read,
        });
    }
    if probe.byte_ledger.opened_product_index_bytes > 0
        || probe.byte_ledger.loaded_product_index_bytes > 0
        || probe.byte_ledger.model_bytes_loaded > 0
        || probe.byte_ledger.runtime_model_bytes_loaded > 0
        || probe.byte_ledger.provider_calls_made > 0
        || probe.byte_ledger.copied_product_file_count > 0
        || probe.byte_ledger.imported_external_crate_count > 0
        || probe.byte_ledger.quarantined_external_code_bytes > 0
    {
        return Err(TurboVecQuarantineMicrobenchError::ProductBytesLoaded(
            probe.probe_id.clone(),
        ));
    }
    Ok(())
}

fn validate_proof_refs(
    probe_id: &str,
    refs: &TurboVecQuarantineMicrobenchProofRefs,
) -> Result<(), TurboVecQuarantineMicrobenchError> {
    let id = probe_id.to_string();
    for (field, value, prefix) in [
        ("falsifier_ref", &refs.falsifier_ref, FALSIFIER_PREFIX),
        ("rollback_ref", &refs.rollback_ref, ROLLBACK_PREFIX),
        (
            "run_event_log_ref",
            &refs.run_event_log_ref,
            RUN_EVENT_LOG_PREFIX,
        ),
        (
            "answer_packet_ref",
            &refs.answer_packet_ref,
            ANSWER_PACKET_PREFIX,
        ),
        (
            "compatibility_fence_ref",
            &refs.compatibility_fence_ref,
            COMPATIBILITY_FENCE_PREFIX,
        ),
        ("provenance_ref", &refs.provenance_ref, PROVENANCE_PREFIX),
    ] {
        if value.trim().is_empty() {
            return Err(TurboVecQuarantineMicrobenchError::MissingField {
                field,
                probe_id: id,
            });
        }
        require_prefix(field, value, prefix)?;
    }
    Ok(())
}

fn invalid_case(
    case: &TurboVecQuarantineMicrobenchCase,
    reason: &str,
) -> Result<(), TurboVecQuarantineMicrobenchError> {
    Err(TurboVecQuarantineMicrobenchError::InvalidCase {
        case_id: case.case_id.clone(),
        reason: reason.to_string(),
    })
}

fn require_nonempty(
    value: &str,
    field: &'static str,
    probe_id: &str,
) -> Result<(), TurboVecQuarantineMicrobenchError> {
    if value.trim().is_empty() {
        return Err(TurboVecQuarantineMicrobenchError::MissingField {
            field,
            probe_id: probe_id.to_string(),
        });
    }
    Ok(())
}

fn require_prefix(
    field: &'static str,
    value: &str,
    expected: &'static str,
) -> Result<(), TurboVecQuarantineMicrobenchError> {
    if !value.starts_with(expected) {
        return Err(TurboVecQuarantineMicrobenchError::BadPrefix {
            field,
            value: value.to_string(),
            expected,
        });
    }
    Ok(())
}

fn deterministic_set_address(
    probes: &[TurboVecQuarantineAdapterMicrobenchProbe],
    metadata_bytes_read: u64,
    fixture_bytes_read: u64,
) -> UasAddress {
    let mut parts = Vec::with_capacity(probes.len() + 2);
    parts.push(format!("metadata={metadata_bytes_read}"));
    parts.push(format!("fixture={fixture_bytes_read}"));
    for probe in probes {
        parts.push(format!(
            "{}:{}:{}:{}",
            probe.probe_id,
            probe.upstream_shadow_address,
            probe.byte_ledger.synthetic_total_bytes(),
            probe.cases.len()
        ));
    }
    parts.sort();
    let digest = sha256_hex(parts.join("|").as_bytes());
    UasAddress::new(
        UasKind::Other("turbovec_quarantine_adapter_microbench_probe".to_string()),
        digest.as_bytes(),
        1_779_040_200_000,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn upstream() -> UasAddress {
        UasAddress::new(
            UasKind::Other("turbovec_runtime_shadow_benchmark_plan".to_string()),
            b"upstream",
            1_779_040_200_000,
        )
    }

    fn case(
        id: &str,
        scenario: TurboVecQuarantineMicrobenchScenario,
        decision: TurboVecQuarantineMicrobenchDecision,
    ) -> TurboVecQuarantineMicrobenchCase {
        let mut case = TurboVecQuarantineMicrobenchCase {
            case_id: id.to_string(),
            scenario,
            query_uas_address: UasAddress::new(
                UasKind::Other("turbovec_quarantine_microbench_query".to_string()),
                id.as_bytes(),
                1_779_040_200_000,
            ),
            deterministic_seed: 7,
            vector_dimension: 64,
            vector_count: 96,
            top_k: 8,
            allowlist_count: 64,
            exact_baseline_ref: format!("exact_baseline:turbovec-quarantine:{id}"),
            allowlist_proof_ref: format!("allowlist:turbovec-quarantine:{id}"),
            exact_top1_uas_ref: format!("uas:exact:{id}"),
            adapter_top1_uas_ref: format!("uas:adapter:{id}"),
            exact_recall_at_k_micros: 960_000,
            adapter_recall_at_k_micros: 940_000,
            recall_floor_micros: 900_000,
            max_allowed_recall_delta_micros: 80_000,
            predicted_p50_latency_micros: 1_200,
            predicted_p95_latency_micros: 4_000,
            predicted_p99_latency_micros: 8_000,
            latency_budget_micros: 6_000,
            timeout_micros: 12_000,
            cancellation_deadline_micros: 9_000,
            synthetic_vector_bytes: 24_576,
            synthetic_scratch_bytes: 16_384,
            synthetic_total_bytes: 0,
            memory_budget_bytes: 96 * 1024,
            memory_headroom_bytes: 0,
            decision,
            non_authoritative_output: true,
            adapter_panic_caught: false,
            fallback_reason_ref: None,
            fallback_route_ref: format!("fallback:turbovec-quarantine:{id}"),
            rollback_ref: format!("rollback:turbovec-quarantine:{id}"),
            run_event_log_ref: format!("run_event_log:turbovec-quarantine:{id}"),
            answer_packet_ref: format!("answer_packet:turbovec-quarantine:{id}"),
            route_mutation_allowed: false,
            model_context_injected: false,
        };
        match decision {
            TurboVecQuarantineMicrobenchDecision::RecordNonAuthoritativeWin => {}
            TurboVecQuarantineMicrobenchDecision::ExactFallback => {
                case.fallback_reason_ref = Some(format!("microbench:exact:{id}"));
            }
            TurboVecQuarantineMicrobenchDecision::RecallFallback => {
                case.adapter_recall_at_k_micros = 720_000;
                case.fallback_reason_ref = Some(format!("microbench:recall:{id}"));
            }
            TurboVecQuarantineMicrobenchDecision::CancelFallback => {
                case.predicted_p99_latency_micros = 20_000;
                case.fallback_reason_ref = Some(format!("microbench:cancel:{id}"));
            }
            TurboVecQuarantineMicrobenchDecision::EmptyVisible => {
                case.allowlist_count = 0;
                case.vector_count = 1;
                case.fallback_reason_ref = Some(format!("microbench:empty:{id}"));
            }
            TurboVecQuarantineMicrobenchDecision::PanicFallback => {
                case.adapter_panic_caught = true;
                case.fallback_reason_ref = Some(format!("microbench:panic:{id}"));
            }
        }
        case.recompute_totals();
        case
    }

    fn probe(upstream: UasAddress) -> TurboVecQuarantineAdapterMicrobenchProbe {
        TurboVecQuarantineAdapterMicrobenchProbe {
            probe_id: "quarantine_microbench".to_string(),
            upstream_shadow_address: upstream,
            upstream_shadow_witness_ref: UPSTREAM_WITNESS_REF.to_string(),
            status: TurboVecQuarantineMicrobenchStatus::SyntheticHarnessOnly,
            promotion_tier: TurboVecQuarantineMicrobenchPromotionTier::T1L1Metadata,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            adapter_mode: TurboVecQuarantineAdapterMode::SyntheticHarnessOnly,
            organs: vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            policy: TurboVecQuarantineMicrobenchPolicy::fail_closed(),
            cases: vec![
                case(
                    "warm",
                    TurboVecQuarantineMicrobenchScenario::WarmApproxWin,
                    TurboVecQuarantineMicrobenchDecision::RecordNonAuthoritativeWin,
                ),
                case(
                    "cold",
                    TurboVecQuarantineMicrobenchScenario::ColdExactFallback,
                    TurboVecQuarantineMicrobenchDecision::ExactFallback,
                ),
                case(
                    "recall",
                    TurboVecQuarantineMicrobenchScenario::RecallLossFallback,
                    TurboVecQuarantineMicrobenchDecision::RecallFallback,
                ),
                case(
                    "cancel",
                    TurboVecQuarantineMicrobenchScenario::CancellationFallback,
                    TurboVecQuarantineMicrobenchDecision::CancelFallback,
                ),
                case(
                    "empty",
                    TurboVecQuarantineMicrobenchScenario::EmptyAllowlistVisible,
                    TurboVecQuarantineMicrobenchDecision::EmptyVisible,
                ),
                case(
                    "panic",
                    TurboVecQuarantineMicrobenchScenario::AdapterPanicFallback,
                    TurboVecQuarantineMicrobenchDecision::PanicFallback,
                ),
            ],
            byte_ledger: TurboVecQuarantineMicrobenchByteLedger::synthetic_only(
                32_000, 28_000, 48_000, 24_000,
            )
            .unwrap(),
            proof_refs: TurboVecQuarantineMicrobenchProofRefs {
                falsifier_ref: "falsifier:F-TurboVec-QuarantineAdapterMicrobenchProbe".to_string(),
                rollback_ref: "rollback:turbovec-quarantine:probe".to_string(),
                run_event_log_ref: "run_event_log:turbovec-quarantine:probe".to_string(),
                answer_packet_ref: "answer_packet:turbovec-quarantine:probe".to_string(),
                compatibility_fence_ref: "compat:turbovec-quarantine:probe".to_string(),
                provenance_ref: "provenance:turbovec-quarantine:synthetic-only".to_string(),
            },
            hidden_route_authority: false,
            product_capability_promoted: false,
            live_large_model_claimed: false,
            ssd_as_ram_claimed: false,
        }
    }

    fn set(
        probes: Vec<TurboVecQuarantineAdapterMicrobenchProbe>,
    ) -> Result<TurboVecQuarantineAdapterMicrobenchProbeSet, TurboVecQuarantineMicrobenchError>
    {
        TurboVecQuarantineAdapterMicrobenchProbeSet::from_probes(
            upstream(),
            probes,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecQuarantineMicrobenchStatus::SyntheticHarnessOnly,
            TurboVecQuarantineMicrobenchPromotionTier::T1L1Metadata,
            32_000,
            28_000,
            false,
        )
    }

    #[test]
    fn accepts_quarantine_microbench_and_deterministic_address() {
        let accepted = probe(upstream());
        let first = set(vec![accepted.clone()]).unwrap();
        let second = set(vec![accepted]).unwrap();
        assert_eq!(first.set_address, second.set_address);
        let metrics = first.metrics();
        assert_eq!(metrics.case_count, 6);
        assert_eq!(metrics.non_authoritative_win_count, 1);
        assert_eq!(metrics.fallback_case_count, 5);
        assert_eq!(metrics.adapter_panic_caught_count, 1);
    }

    #[test]
    fn rejects_direct_import_or_external_code_bytes() {
        let mut bad = probe(upstream());
        bad.adapter_mode = TurboVecQuarantineAdapterMode::DirectImport;
        assert!(set(vec![bad]).is_err());

        let mut bad = probe(upstream());
        bad.byte_ledger.imported_external_crate_count = 1;
        assert!(set(vec![bad]).is_err());
    }

    #[test]
    fn rejects_route_context_and_product_promotion() {
        let mut bad = probe(upstream());
        bad.cases[0].route_mutation_allowed = true;
        assert!(set(vec![bad]).is_err());

        let mut bad = probe(upstream());
        bad.product_capability_promoted = true;
        assert!(set(vec![bad]).is_err());
    }

    #[test]
    fn rejects_recall_laundering_and_missing_panic_containment() {
        let mut bad = probe(upstream());
        bad.cases[2].adapter_recall_at_k_micros = 940_000;
        assert!(set(vec![bad]).is_err());

        let mut bad = probe(upstream());
        bad.cases[5].adapter_panic_caught = false;
        assert!(set(vec![bad]).is_err());
    }
}
