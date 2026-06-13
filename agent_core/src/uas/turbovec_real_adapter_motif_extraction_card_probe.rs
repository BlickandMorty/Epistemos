//! TurboVec real-adapter motif-extraction card probe.
//!
//! This primitive converts bounded TurboVec source inspection into clean-room
//! motif cards for Epistemos architecture work. It is research-to-build only:
//! motif cards may shape future Eidos/AppColdStore tests and adapter plans, but
//! they cannot import upstream code, build native links, run benchmarks as
//! authority, inject model context, mutate routes, or claim product capability.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild, TurboVecIndexOrgan, UasAddress, UasKind};

pub const TURBOVEC_REAL_ADAPTER_MOTIF_EXTRACTION_CARD_CURSOR: &str =
    "turbovec_quarantine_real_adapter_motif_extraction_card_probe";
pub const TURBOVEC_REAL_ADAPTER_MOTIF_EXTRACTION_CARD_NEXT_CURSOR: &str =
    "turbovec_quarantine_real_adapter_clean_room_adapter_plan_probe";

const SOURCE_INSPECTION_POLICY_WITNESS_REF: &str =
    "artifact:turbovec_real_adapter_source_inspection_policy_probe:result";
const SOURCE_INSPECTION_POLICY_PREFIX: &str =
    "turbovec_real_adapter_source_inspection_policy_probe:";
const PINNED_REVISION: &str = "efe29a184986cbf562a9847c2ac52a2990bfaca2";
const SOURCE_URL: &str = "https://github.com/RyanCodrai/turbovec";
const RAW_URL_PREFIX: &str = "https://raw.githubusercontent.com/RyanCodrai/turbovec/efe29a184986cbf562a9847c2ac52a2990bfaca2/";
const ISSUE_URL_PREFIX: &str = "https://github.com/RyanCodrai/turbovec/issues/";
const PR_URL_PREFIX: &str = "https://github.com/RyanCodrai/turbovec/pull/";
const FORK_URL_PREFIX: &str = "https://github.com/";
const PROVENANCE_REF_PREFIX: &str = "provenance:turbovec-motif-extraction:";
const CLEAN_ROOM_REF_PREFIX: &str = "clean_room:turbovec-motif-extraction:";
const SOURCE_CARD_REF_PREFIX: &str = "source_card:turbovec-motif-extraction:";
const FORK_SWEEP_REF_PREFIX: &str = "fork_sweep:turbovec-motif-extraction:";
const NO_PRODUCT_GRAPH_REF_PREFIX: &str = "no_product_graph:turbovec-motif-extraction:";
const ROLLBACK_REF_PREFIX: &str = "rollback:turbovec-motif-extraction:";
const RUN_EVENT_LOG_REF_PREFIX: &str = "run_event_log:turbovec-motif-extraction:";
const ANSWER_PACKET_REF_PREFIX: &str = "answer_packet:turbovec-motif-extraction:";
const COMPATIBILITY_REF_PREFIX: &str = "compat:turbovec-motif-extraction:";
const BENCHMARK_CAVEAT_REF_PREFIX: &str = "benchmark_caveat:turbovec-motif-extraction:";
const MAX_SOURCE_BYTES_INSPECTED: u64 = 196_608;
const SELECTED_SOURCE_BYTES_INSPECTED: u64 = 184_472;
const MIN_MOTIF_COUNT: usize = 10;
const MIN_MOTIF_CLASS_COUNT: usize = 8;
const MIN_REQUIRED_SOURCE_PATHS: usize = 8;
const MIN_VISIBLE_SUMMARY_BYTES: usize = 520;

// UAS: uas:turbovec-real-adapter-motif-extraction-card:status
// Plane: Verification
// Residency: motif card promotion boundary.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecMotifExtractionStatus {
    MotifCardsOnly,
    AdapterPlanCandidate,
    RuntimeCandidate,
}

// UAS: uas:turbovec-real-adapter-motif-extraction-card:tier
// Plane: Verification
// Residency: tier discipline for motif extraction.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecMotifExtractionTier {
    T0Research,
    T1L1Metadata,
    T2L2Route,
    T3L3Wrv,
    T4BuildGreen,
    T5FullSegment,
}

// UAS: uas:turbovec-real-adapter-motif-extraction-card:motif-class
// Plane: Assembly + Controller + Verification
// Residency: clean-room motif class extracted from allowed source rows.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecMotifClass {
    ApiShape,
    StableExternalId,
    FilterBeforeRank,
    LazyPreparedCache,
    InputValidation,
    CrashSafeIo,
    BenchmarkCaveat,
    SwiftBindingRisk,
    ForkDrift,
    LargeModelWorkingSet,
}

// UAS: uas:turbovec-real-adapter-motif-extraction-card:output-mode
// Plane: Verification
// Residency: allowed clean-room output form.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TurboVecMotifOutputMode {
    SourceCard,
    BehaviorSpec,
    TestInvariant,
    BenchmarkCaveat,
    ForkDelta,
    ArchitectureFusion,
}

// UAS: uas:turbovec-real-adapter-motif-extraction-card:card
// Plane: State + Assembly + Controller + Verification
// Residency: clean-room motif card.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecMotifCard {
    pub motif_id: String,
    pub source_path: String,
    pub motif_class: TurboVecMotifClass,
    pub output_mode: TurboVecMotifOutputMode,
    pub source_refs: Vec<String>,
    pub clean_room_summary: String,
    pub epistemos_fusion: String,
    pub required_falsifier: String,
    pub runtime_proof_required: String,
    pub user_visible_proof_required: String,
    pub rollback_ref: String,
    pub source_bytes_inspected: u64,
    pub no_verbatim_source: bool,
    pub no_product_import: bool,
    pub no_route_authority: bool,
    pub benchmark_authority_denied: bool,
    pub privacy_risk: String,
    pub stability_risk: String,
    pub provenance_risk: String,
}

// UAS: uas:turbovec-real-adapter-motif-extraction-card:policy
// Plane: Controller + Verification
// Residency: fail-closed policy for motif cards.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecMotifExtractionPolicy {
    pub upstream_policy_bound: bool,
    pub clean_room_only: bool,
    pub source_cards_required: bool,
    pub no_verbatim_source: bool,
    pub no_product_import: bool,
    pub no_product_dependency: bool,
    pub no_native_link_probe: bool,
    pub no_adapter_build: bool,
    pub no_benchmark_authority: bool,
    pub no_runtime_execution: bool,
    pub no_route_authority: bool,
    pub no_model_context_injection: bool,
    pub fork_deltas_non_authoritative: bool,
    pub rollback_required: bool,
    pub answer_packet_required: bool,
}

impl TurboVecMotifExtractionPolicy {
    pub fn fail_closed() -> Self {
        Self {
            upstream_policy_bound: true,
            clean_room_only: true,
            source_cards_required: true,
            no_verbatim_source: true,
            no_product_import: true,
            no_product_dependency: true,
            no_native_link_probe: true,
            no_adapter_build: true,
            no_benchmark_authority: true,
            no_runtime_execution: true,
            no_route_authority: true,
            no_model_context_injection: true,
            fork_deltas_non_authoritative: true,
            rollback_required: true,
            answer_packet_required: true,
        }
    }
}

// UAS: uas:turbovec-real-adapter-motif-extraction-card:byte-ledger
// Plane: Verification
// Residency: selected source-inspection bytes and zero product/runtime bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecMotifExtractionByteLedger {
    pub selected_raw_source_bytes_inspected: u64,
    pub max_raw_source_bytes_allowed: u64,
    pub issue_and_fork_metadata_bytes_read: u64,
    pub source_archive_bytes_fetched: u64,
    pub quarantine_source_bytes_written: u64,
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

impl TurboVecMotifExtractionByteLedger {
    pub fn selected_source_only() -> Self {
        Self {
            selected_raw_source_bytes_inspected: SELECTED_SOURCE_BYTES_INSPECTED,
            max_raw_source_bytes_allowed: MAX_SOURCE_BYTES_INSPECTED,
            issue_and_fork_metadata_bytes_read: 32 * 1024,
            source_archive_bytes_fetched: 0,
            quarantine_source_bytes_written: 0,
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

// UAS: uas:turbovec-real-adapter-motif-extraction-card:proof-refs
// Plane: Verification
// Residency: visible proof surfaces for motif cards.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecMotifExtractionProofRefs {
    pub source_inspection_policy_ref: String,
    pub provenance_ref: String,
    pub clean_room_ref: String,
    pub source_card_ref: String,
    pub fork_sweep_ref: String,
    pub no_product_graph_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
    pub benchmark_caveat_ref: String,
    pub visible_summary: String,
}

// UAS: uas:turbovec-real-adapter-motif-extraction-card:set
// Plane: State + Assembly + Controller + Verification
// Residency: complete motif-card witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurboVecRealAdapterMotifExtractionCardProbeSet {
    pub set_address: UasAddress,
    pub upstream_source_inspection_policy_address: UasAddress,
    pub upstream_source_inspection_policy_witness_ref: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub status: TurboVecMotifExtractionStatus,
    pub promotion_tier: TurboVecMotifExtractionTier,
    pub organs: Vec<TurboVecIndexOrgan>,
    pub source_url: String,
    pub pinned_revision: String,
    pub motif_cards: Vec<TurboVecMotifCard>,
    pub policy: TurboVecMotifExtractionPolicy,
    pub proof_refs: TurboVecMotifExtractionProofRefs,
    pub byte_ledger: TurboVecMotifExtractionByteLedger,
    pub product_capability_promoted: bool,
    pub route_mutation_allowed: bool,
    pub model_context_injected: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub live_large_model_claimed: bool,
    pub ssd_as_ram_claimed: bool,
}

// UAS: uas:turbovec-real-adapter-motif-extraction-card:metrics
// Plane: Verification
// Residency: aggregate motif counters.
#[derive(Clone, Debug, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct TurboVecMotifExtractionMetrics {
    pub motif_count: u64,
    pub motif_class_count: u64,
    pub required_source_path_count: u64,
    pub source_ref_count: u64,
    pub api_shape_count: u64,
    pub stable_external_id_count: u64,
    pub filter_before_rank_count: u64,
    pub input_validation_count: u64,
    pub benchmark_caveat_count: u64,
    pub fork_delta_count: u64,
    pub large_model_working_set_count: u64,
    pub selected_raw_source_bytes_inspected: u64,
    pub max_raw_source_bytes_allowed: u64,
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

impl TurboVecRealAdapterMotifExtractionCardProbeSet {
    #[allow(clippy::too_many_arguments)]
    pub fn from_parts(
        upstream_source_inspection_policy_address: UasAddress,
        mut motif_cards: Vec<TurboVecMotifCard>,
        policy: TurboVecMotifExtractionPolicy,
        proof_refs: TurboVecMotifExtractionProofRefs,
        byte_ledger: TurboVecMotifExtractionByteLedger,
        product_build: ProductBuild,
        pro_status: ProStatus,
        status: TurboVecMotifExtractionStatus,
        promotion_tier: TurboVecMotifExtractionTier,
        organs: Vec<TurboVecIndexOrgan>,
        product_capability_promoted: bool,
        route_mutation_allowed: bool,
        model_context_injected: bool,
        hidden_route_authority: bool,
        hidden_cloud_fallback_allowed: bool,
        live_large_model_claimed: bool,
        ssd_as_ram_claimed: bool,
    ) -> Result<Self, TurboVecMotifExtractionError> {
        motif_cards.sort_by(|left, right| left.motif_id.cmp(&right.motif_id));
        validate_set_inputs(
            &upstream_source_inspection_policy_address,
            &motif_cards,
            &policy,
            &proof_refs,
            &byte_ledger,
            &product_build,
            &pro_status,
            &status,
            &promotion_tier,
            &organs,
            product_capability_promoted,
            route_mutation_allowed,
            model_context_injected,
            hidden_route_authority,
            hidden_cloud_fallback_allowed,
            live_large_model_claimed,
            ssd_as_ram_claimed,
        )?;
        let set_address = deterministic_set_address(&motif_cards);
        Ok(Self {
            set_address,
            upstream_source_inspection_policy_address,
            upstream_source_inspection_policy_witness_ref: SOURCE_INSPECTION_POLICY_WITNESS_REF
                .to_string(),
            product_build,
            pro_status,
            status,
            promotion_tier,
            organs,
            source_url: SOURCE_URL.to_string(),
            pinned_revision: PINNED_REVISION.to_string(),
            motif_cards,
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
        })
    }

    pub fn metrics(&self) -> TurboVecMotifExtractionMetrics {
        let classes: BTreeSet<_> = self
            .motif_cards
            .iter()
            .map(|card| card.motif_class)
            .collect();
        let paths: BTreeSet<_> = self
            .motif_cards
            .iter()
            .map(|card| card.source_path.as_str())
            .collect();
        TurboVecMotifExtractionMetrics {
            motif_count: self.motif_cards.len() as u64,
            motif_class_count: classes.len() as u64,
            required_source_path_count: paths.len() as u64,
            source_ref_count: self
                .motif_cards
                .iter()
                .map(|card| card.source_refs.len() as u64)
                .sum(),
            api_shape_count: count_class(&self.motif_cards, TurboVecMotifClass::ApiShape),
            stable_external_id_count: count_class(
                &self.motif_cards,
                TurboVecMotifClass::StableExternalId,
            ),
            filter_before_rank_count: count_class(
                &self.motif_cards,
                TurboVecMotifClass::FilterBeforeRank,
            ),
            input_validation_count: count_class(
                &self.motif_cards,
                TurboVecMotifClass::InputValidation,
            ),
            benchmark_caveat_count: count_class(
                &self.motif_cards,
                TurboVecMotifClass::BenchmarkCaveat,
            ),
            fork_delta_count: count_class(&self.motif_cards, TurboVecMotifClass::ForkDrift),
            large_model_working_set_count: count_class(
                &self.motif_cards,
                TurboVecMotifClass::LargeModelWorkingSet,
            ),
            selected_raw_source_bytes_inspected: self
                .byte_ledger
                .selected_raw_source_bytes_inspected,
            max_raw_source_bytes_allowed: self.byte_ledger.max_raw_source_bytes_allowed,
            product_files_copied: self.byte_ledger.product_files_copied,
            product_dependencies_added: self.byte_ledger.product_dependencies_added,
            native_link_probe_count: self.byte_ledger.native_link_probe_count,
            adapter_build_count: self.byte_ledger.adapter_build_count,
            benchmark_run_count: self.byte_ledger.benchmark_run_count,
            index_bytes_opened: self.byte_ledger.index_bytes_opened,
            model_bytes_loaded: self.byte_ledger.model_bytes_loaded,
            runtime_model_bytes_loaded: self.byte_ledger.runtime_model_bytes_loaded,
            provider_calls_made: self.byte_ledger.provider_calls_made,
            route_mutation_count: self.byte_ledger.route_mutation_count
                + u64::from(self.route_mutation_allowed),
            model_context_injection_count: self.byte_ledger.model_context_injection_count
                + u64::from(self.model_context_injected),
            hidden_authority_count: u64::from(
                self.hidden_route_authority || self.hidden_cloud_fallback_allowed,
            ),
        }
    }
}

fn count_class(cards: &[TurboVecMotifCard], class: TurboVecMotifClass) -> u64 {
    cards
        .iter()
        .filter(|card| card.motif_class == class)
        .count() as u64
}

// UAS: uas:turbovec-real-adapter-motif-extraction-card:error
// Plane: Verification
// Residency: validation failures for unsafe motif-card states.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TurboVecMotifExtractionError {
    BadUpstreamCursor,
    BadProductBuild(ProductBuild),
    BadProStatus(ProStatus),
    BadStatus(TurboVecMotifExtractionStatus),
    BadPromotionTier(TurboVecMotifExtractionTier),
    InvalidOrgans,
    InvalidMotif(String),
    InvalidPolicy(String),
    InvalidByteLedger(String),
    ProductPromotionAllowed,
    ForbiddenAuthority(String),
    MissingField(&'static str),
    BadPrefix {
        field: &'static str,
        value: String,
        expected: &'static str,
    },
}

impl fmt::Display for TurboVecMotifExtractionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamCursor => {
                write!(f, "upstream source-inspection policy cursor mismatch")
            }
            Self::BadProductBuild(build) => write!(f, "bad product build: {build:?}"),
            Self::BadProStatus(status) => write!(f, "bad pro status: {status:?}"),
            Self::BadStatus(status) => write!(f, "bad motif status: {status:?}"),
            Self::BadPromotionTier(tier) => write!(f, "bad motif tier: {tier:?}"),
            Self::InvalidOrgans => write!(f, "required organs missing or duplicated"),
            Self::InvalidMotif(reason) => write!(f, "invalid motif: {reason}"),
            Self::InvalidPolicy(reason) => write!(f, "invalid policy: {reason}"),
            Self::InvalidByteLedger(reason) => write!(f, "invalid byte ledger: {reason}"),
            Self::ProductPromotionAllowed => write!(f, "product promotion attempted"),
            Self::ForbiddenAuthority(reason) => write!(f, "forbidden authority: {reason}"),
            Self::MissingField(field) => write!(f, "missing field: {field}"),
            Self::BadPrefix {
                field,
                value,
                expected,
            } => write!(f, "{field} `{value}` must start with `{expected}`"),
        }
    }
}

impl std::error::Error for TurboVecMotifExtractionError {}

#[allow(clippy::too_many_arguments)]
fn validate_set_inputs(
    upstream_source_inspection_policy_address: &UasAddress,
    motif_cards: &[TurboVecMotifCard],
    policy: &TurboVecMotifExtractionPolicy,
    proof_refs: &TurboVecMotifExtractionProofRefs,
    byte_ledger: &TurboVecMotifExtractionByteLedger,
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    status: &TurboVecMotifExtractionStatus,
    promotion_tier: &TurboVecMotifExtractionTier,
    organs: &[TurboVecIndexOrgan],
    product_capability_promoted: bool,
    route_mutation_allowed: bool,
    model_context_injected: bool,
    hidden_route_authority: bool,
    hidden_cloud_fallback_allowed: bool,
    live_large_model_claimed: bool,
    ssd_as_ram_claimed: bool,
) -> Result<(), TurboVecMotifExtractionError> {
    if !upstream_source_inspection_policy_address
        .to_string()
        .starts_with(SOURCE_INSPECTION_POLICY_PREFIX)
    {
        return Err(TurboVecMotifExtractionError::BadUpstreamCursor);
    }
    if product_build != &ProductBuild::Pro {
        return Err(TurboVecMotifExtractionError::BadProductBuild(
            product_build.clone(),
        ));
    }
    if pro_status != &ProStatus::ResearchCandidate {
        return Err(TurboVecMotifExtractionError::BadProStatus(
            pro_status.clone(),
        ));
    }
    if status != &TurboVecMotifExtractionStatus::MotifCardsOnly {
        return Err(TurboVecMotifExtractionError::BadStatus(*status));
    }
    if promotion_tier != &TurboVecMotifExtractionTier::T1L1Metadata {
        return Err(TurboVecMotifExtractionError::BadPromotionTier(
            *promotion_tier,
        ));
    }
    if product_capability_promoted {
        return Err(TurboVecMotifExtractionError::ProductPromotionAllowed);
    }
    if route_mutation_allowed
        || model_context_injected
        || hidden_route_authority
        || hidden_cloud_fallback_allowed
        || live_large_model_claimed
        || ssd_as_ram_claimed
    {
        return Err(TurboVecMotifExtractionError::ForbiddenAuthority(
            "route/context/hidden/cloud/large-model claim attempted".to_string(),
        ));
    }
    validate_organs(organs)?;
    validate_motifs(motif_cards)?;
    validate_policy(policy)?;
    validate_proof_refs(proof_refs)?;
    validate_byte_ledger(byte_ledger)?;
    Ok(())
}

fn validate_organs(organs: &[TurboVecIndexOrgan]) -> Result<(), TurboVecMotifExtractionError> {
    let required = [
        TurboVecIndexOrgan::Eidos,
        TurboVecIndexOrgan::AppColdStore,
        TurboVecIndexOrgan::SemanticWorkingSetPlan,
        TurboVecIndexOrgan::AnswerPacket,
    ];
    let seen: HashSet<_> = organs.iter().copied().collect();
    if seen.len() != organs.len() || required.iter().any(|organ| !seen.contains(organ)) {
        return Err(TurboVecMotifExtractionError::InvalidOrgans);
    }
    Ok(())
}

fn validate_motifs(cards: &[TurboVecMotifCard]) -> Result<(), TurboVecMotifExtractionError> {
    if cards.len() < MIN_MOTIF_COUNT {
        return Err(TurboVecMotifExtractionError::InvalidMotif(
            "motif coverage below floor".to_string(),
        ));
    }
    let mut ids = BTreeSet::new();
    let mut classes = BTreeSet::new();
    let mut paths = BTreeSet::new();
    for card in cards {
        validate_motif(card)?;
        if !ids.insert(card.motif_id.clone()) {
            return Err(TurboVecMotifExtractionError::InvalidMotif(format!(
                "duplicate motif id {}",
                card.motif_id
            )));
        }
        classes.insert(card.motif_class);
        paths.insert(card.source_path.clone());
    }
    if classes.len() < MIN_MOTIF_CLASS_COUNT || paths.len() < MIN_REQUIRED_SOURCE_PATHS {
        return Err(TurboVecMotifExtractionError::InvalidMotif(
            "motif class or source-path diversity below floor".to_string(),
        ));
    }
    for class in required_classes() {
        if !classes.contains(class) {
            return Err(TurboVecMotifExtractionError::InvalidMotif(format!(
                "missing required class {class:?}"
            )));
        }
    }
    Ok(())
}

fn validate_motif(card: &TurboVecMotifCard) -> Result<(), TurboVecMotifExtractionError> {
    validate_id(&card.motif_id)?;
    validate_source_path(&card.source_path)?;
    validate_source_refs(card)?;
    if card.clean_room_summary.len() < 90
        || card.epistemos_fusion.len() < 80
        || card.required_falsifier.len() < 8
        || card.runtime_proof_required.len() < 16
        || card.user_visible_proof_required.len() < 16
        || card.privacy_risk.len() < 12
        || card.stability_risk.len() < 12
        || card.provenance_risk.len() < 12
    {
        return Err(TurboVecMotifExtractionError::InvalidMotif(format!(
            "motif {} has weak summary/proof/risk text",
            card.motif_id
        )));
    }
    if card.clean_room_summary.contains("```")
        || card.clean_room_summary.contains("fn ")
        || card.clean_room_summary.contains("impl ")
    {
        return Err(TurboVecMotifExtractionError::InvalidMotif(format!(
            "motif {} may contain verbatim source",
            card.motif_id
        )));
    }
    if !card.rollback_ref.starts_with(ROLLBACK_REF_PREFIX) {
        return Err(TurboVecMotifExtractionError::BadPrefix {
            field: "rollback_ref",
            value: card.rollback_ref.clone(),
            expected: ROLLBACK_REF_PREFIX,
        });
    }
    if card.source_bytes_inspected == 0 || card.source_bytes_inspected > MAX_SOURCE_BYTES_INSPECTED
    {
        return Err(TurboVecMotifExtractionError::InvalidMotif(format!(
            "motif {} has invalid inspected-byte count",
            card.motif_id
        )));
    }
    if !card.no_verbatim_source
        || !card.no_product_import
        || !card.no_route_authority
        || !card.benchmark_authority_denied
    {
        return Err(TurboVecMotifExtractionError::InvalidMotif(format!(
            "motif {} has forbidden authority flag",
            card.motif_id
        )));
    }
    Ok(())
}

fn validate_id(id: &str) -> Result<(), TurboVecMotifExtractionError> {
    if id.is_empty()
        || id.len() > 96
        || !id
            .chars()
            .all(|ch| ch.is_ascii_lowercase() || ch.is_ascii_digit() || ch == '_' || ch == '-')
    {
        return Err(TurboVecMotifExtractionError::InvalidMotif(format!(
            "unsafe motif id {id}"
        )));
    }
    Ok(())
}

fn validate_source_path(path: &str) -> Result<(), TurboVecMotifExtractionError> {
    if path.is_empty()
        || path == "."
        || path.starts_with('/')
        || path.contains("..")
        || path.contains('\\')
        || path.contains("//")
    {
        return Err(TurboVecMotifExtractionError::InvalidMotif(format!(
            "unsafe source path {path}"
        )));
    }
    for forbidden in blocked_source_paths() {
        if path == *forbidden {
            return Err(TurboVecMotifExtractionError::InvalidMotif(format!(
                "blocked source path {path}"
            )));
        }
    }
    if !allowed_source_paths().contains(&path)
        && !path.starts_with("issue/")
        && !path.starts_with("fork/")
        && !path.starts_with("pull/")
    {
        return Err(TurboVecMotifExtractionError::InvalidMotif(format!(
            "unapproved source path {path}"
        )));
    }
    Ok(())
}

fn validate_source_refs(card: &TurboVecMotifCard) -> Result<(), TurboVecMotifExtractionError> {
    if card.source_refs.is_empty() || card.source_refs.len() > 4 {
        return Err(TurboVecMotifExtractionError::InvalidMotif(format!(
            "bad source ref count for {}",
            card.motif_id
        )));
    }
    for source_ref in &card.source_refs {
        let source_ok = source_ref.starts_with(RAW_URL_PREFIX)
            || source_ref.starts_with(ISSUE_URL_PREFIX)
            || source_ref.starts_with(PR_URL_PREFIX)
            || source_ref.starts_with(FORK_URL_PREFIX);
        if !source_ok {
            return Err(TurboVecMotifExtractionError::InvalidMotif(format!(
                "bad source ref for {}",
                card.motif_id
            )));
        }
    }
    Ok(())
}

fn validate_policy(
    policy: &TurboVecMotifExtractionPolicy,
) -> Result<(), TurboVecMotifExtractionError> {
    let valid = policy.upstream_policy_bound
        && policy.clean_room_only
        && policy.source_cards_required
        && policy.no_verbatim_source
        && policy.no_product_import
        && policy.no_product_dependency
        && policy.no_native_link_probe
        && policy.no_adapter_build
        && policy.no_benchmark_authority
        && policy.no_runtime_execution
        && policy.no_route_authority
        && policy.no_model_context_injection
        && policy.fork_deltas_non_authoritative
        && policy.rollback_required
        && policy.answer_packet_required;
    if !valid {
        return Err(TurboVecMotifExtractionError::InvalidPolicy(
            "motif-extraction policy must stay fail-closed".to_string(),
        ));
    }
    Ok(())
}

fn validate_proof_refs(
    proof_refs: &TurboVecMotifExtractionProofRefs,
) -> Result<(), TurboVecMotifExtractionError> {
    for (field, value, expected) in [
        (
            "source_inspection_policy_ref",
            proof_refs.source_inspection_policy_ref.as_str(),
            SOURCE_INSPECTION_POLICY_WITNESS_REF,
        ),
        (
            "provenance_ref",
            proof_refs.provenance_ref.as_str(),
            PROVENANCE_REF_PREFIX,
        ),
        (
            "clean_room_ref",
            proof_refs.clean_room_ref.as_str(),
            CLEAN_ROOM_REF_PREFIX,
        ),
        (
            "source_card_ref",
            proof_refs.source_card_ref.as_str(),
            SOURCE_CARD_REF_PREFIX,
        ),
        (
            "fork_sweep_ref",
            proof_refs.fork_sweep_ref.as_str(),
            FORK_SWEEP_REF_PREFIX,
        ),
        (
            "no_product_graph_ref",
            proof_refs.no_product_graph_ref.as_str(),
            NO_PRODUCT_GRAPH_REF_PREFIX,
        ),
        (
            "rollback_ref",
            proof_refs.rollback_ref.as_str(),
            ROLLBACK_REF_PREFIX,
        ),
        (
            "run_event_log_ref",
            proof_refs.run_event_log_ref.as_str(),
            RUN_EVENT_LOG_REF_PREFIX,
        ),
        (
            "answer_packet_ref",
            proof_refs.answer_packet_ref.as_str(),
            ANSWER_PACKET_REF_PREFIX,
        ),
        (
            "compatibility_fence_ref",
            proof_refs.compatibility_fence_ref.as_str(),
            COMPATIBILITY_REF_PREFIX,
        ),
        (
            "benchmark_caveat_ref",
            proof_refs.benchmark_caveat_ref.as_str(),
            BENCHMARK_CAVEAT_REF_PREFIX,
        ),
    ] {
        if value.is_empty() {
            return Err(TurboVecMotifExtractionError::MissingField(field));
        }
        if field == "source_inspection_policy_ref" {
            if value != expected {
                return Err(TurboVecMotifExtractionError::BadPrefix {
                    field,
                    value: value.to_string(),
                    expected,
                });
            }
        } else if !value.starts_with(expected) {
            return Err(TurboVecMotifExtractionError::BadPrefix {
                field,
                value: value.to_string(),
                expected,
            });
        }
    }
    if proof_refs.visible_summary.len() < MIN_VISIBLE_SUMMARY_BYTES
        || !proof_refs.visible_summary.contains("large local model")
        || !proof_refs.visible_summary.contains("clean-room")
        || !proof_refs
            .visible_summary
            .contains("no hidden route authority")
        || !proof_refs.visible_summary.contains("no live dense 70B")
    {
        return Err(TurboVecMotifExtractionError::MissingField(
            "visible_summary",
        ));
    }
    Ok(())
}

fn validate_byte_ledger(
    byte_ledger: &TurboVecMotifExtractionByteLedger,
) -> Result<(), TurboVecMotifExtractionError> {
    if byte_ledger.selected_raw_source_bytes_inspected == 0
        || byte_ledger.max_raw_source_bytes_allowed != MAX_SOURCE_BYTES_INSPECTED
        || byte_ledger.selected_raw_source_bytes_inspected
            > byte_ledger.max_raw_source_bytes_allowed
        || byte_ledger.issue_and_fork_metadata_bytes_read == 0
    {
        return Err(TurboVecMotifExtractionError::InvalidByteLedger(
            "source inspection bytes must be bounded and nonzero".to_string(),
        ));
    }
    let zero_fields = [
        byte_ledger.source_archive_bytes_fetched,
        byte_ledger.quarantine_source_bytes_written,
        byte_ledger.product_files_copied,
        byte_ledger.product_dependencies_added,
        byte_ledger.native_link_probe_count,
        byte_ledger.adapter_build_count,
        byte_ledger.benchmark_run_count,
        byte_ledger.index_bytes_opened,
        byte_ledger.model_bytes_loaded,
        byte_ledger.runtime_model_bytes_loaded,
        byte_ledger.provider_calls_made,
        byte_ledger.route_mutation_count,
        byte_ledger.model_context_injection_count,
    ];
    if zero_fields.iter().any(|value| *value != 0) {
        return Err(TurboVecMotifExtractionError::InvalidByteLedger(
            "product/runtime/model/route bytes or actions must remain zero".to_string(),
        ));
    }
    Ok(())
}

fn required_classes() -> &'static [TurboVecMotifClass] {
    &[
        TurboVecMotifClass::ApiShape,
        TurboVecMotifClass::StableExternalId,
        TurboVecMotifClass::FilterBeforeRank,
        TurboVecMotifClass::InputValidation,
        TurboVecMotifClass::CrashSafeIo,
        TurboVecMotifClass::BenchmarkCaveat,
        TurboVecMotifClass::SwiftBindingRisk,
        TurboVecMotifClass::LargeModelWorkingSet,
    ]
}

fn allowed_source_paths() -> &'static [&'static str] {
    &[
        "LICENSE",
        "README.md",
        "Cargo.toml",
        "turbovec/Cargo.toml",
        "turbovec-python/Cargo.toml",
        "turbovec-python/pyproject.toml",
        "docs/api.md",
        "turbovec/src/lib.rs",
        "turbovec/src/search.rs",
        "turbovec/src/id_map.rs",
        "turbovec/src/io.rs",
        "turbovec/tests/filtering.rs",
        "turbovec/tests/input_validation.rs",
        "benchmarks/suite/recall_d1536_4bit.py",
        "benchmarks/suite/speed_d1536_4bit_arm_mt.py",
    ]
}

fn blocked_source_paths() -> &'static [&'static str] {
    &[
        ".cargo/config.toml",
        "turbovec/build.rs",
        "benchmarks/rabitq_poc/recall_grid.png",
        "turbovec-python/README.md",
        "examples/downstream-smoke/Cargo.toml",
        "turbovec-python/python/turbovec/llama_index.py",
    ]
}

fn deterministic_set_address(cards: &[TurboVecMotifCard]) -> UasAddress {
    let digest = motif_extraction_digest_from_cards(cards);
    UasAddress::new(
        UasKind::Other("turbovec_real_adapter_motif_extraction_card_probe".to_string()),
        digest.as_bytes(),
        1_779_040_904_000,
    )
}

fn motif_extraction_digest_from_cards(cards: &[TurboVecMotifCard]) -> String {
    let mut rows: Vec<String> = cards
        .iter()
        .map(|card| {
            format!(
                "{}|{:?}|{}|{}|{}|{}",
                card.motif_id,
                card.motif_class,
                card.source_path,
                card.required_falsifier,
                card.source_bytes_inspected,
                card.epistemos_fusion
            )
        })
        .collect();
    rows.sort();
    sha256_hex(rows.join("\n").as_bytes())
}

pub fn motif_extraction_digest(set: &TurboVecRealAdapterMotifExtractionCardProbeSet) -> String {
    motif_extraction_digest_from_cards(&set.motif_cards)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn upstream() -> UasAddress {
        UasAddress::new(
            UasKind::Other("turbovec_real_adapter_source_inspection_policy_probe".to_string()),
            b"source-inspection-policy-test",
            1_779_040_903_000,
        )
    }

    fn card(id: &str, path: &str, class: TurboVecMotifClass) -> TurboVecMotifCard {
        TurboVecMotifCard {
            motif_id: id.to_string(),
            source_path: path.to_string(),
            motif_class: class,
            output_mode: match class {
                TurboVecMotifClass::BenchmarkCaveat => TurboVecMotifOutputMode::BenchmarkCaveat,
                TurboVecMotifClass::ForkDrift => TurboVecMotifOutputMode::ForkDelta,
                TurboVecMotifClass::InputValidation => TurboVecMotifOutputMode::TestInvariant,
                TurboVecMotifClass::LargeModelWorkingSet => TurboVecMotifOutputMode::ArchitectureFusion,
                _ => TurboVecMotifOutputMode::BehaviorSpec,
            },
            source_refs: vec![format!("{RAW_URL_PREFIX}{path}")],
            clean_room_summary: format!("Clean-room motif {id} paraphrases behavior from {path} without source text and keeps benchmark or API observations as non-authoritative architecture evidence."),
            epistemos_fusion: "Feeds Eidos/AppColdStore and SemanticWorkingSetPlan test design for large local model context selection while preserving no hidden route authority.".to_string(),
            required_falsifier: format!("F-TurboVec-Motif-{id}"),
            runtime_proof_required: "Shadow replay against exact AppColdStore baseline before any runtime route use.".to_string(),
            user_visible_proof_required: "AnswerPacket caveat plus RunEventLog row before any user-facing claim.".to_string(),
            rollback_ref: format!("{ROLLBACK_REF_PREFIX}{id}"),
            source_bytes_inspected: 12_000,
            no_verbatim_source: true,
            no_product_import: true,
            no_route_authority: true,
            benchmark_authority_denied: true,
            privacy_risk: "Allowed-set leakage if filter-before-rank is bypassed.".to_string(),
            stability_risk: "Adapter panic or stale cache if motif becomes code without proof.".to_string(),
            provenance_risk: "Fork drift can make source-card evidence stale.".to_string(),
        }
    }

    fn cards() -> Vec<TurboVecMotifCard> {
        vec![
            card(
                "api_shape_index_types",
                "docs/api.md",
                TurboVecMotifClass::ApiShape,
            ),
            card(
                "stable_external_ids",
                "turbovec/src/id_map.rs",
                TurboVecMotifClass::StableExternalId,
            ),
            card(
                "filter_before_rank",
                "turbovec/tests/filtering.rs",
                TurboVecMotifClass::FilterBeforeRank,
            ),
            card(
                "lazy_prepare_cache",
                "turbovec/src/lib.rs",
                TurboVecMotifClass::LazyPreparedCache,
            ),
            card(
                "invalid_input_rejection",
                "turbovec/tests/input_validation.rs",
                TurboVecMotifClass::InputValidation,
            ),
            card(
                "format_version_rebuild",
                "turbovec/src/io.rs",
                TurboVecMotifClass::CrashSafeIo,
            ),
            card(
                "benchmark_caveat_recall",
                "benchmarks/suite/recall_d1536_4bit.py",
                TurboVecMotifClass::BenchmarkCaveat,
            ),
            card(
                "swift_binding_risk",
                "issue/86",
                TurboVecMotifClass::SwiftBindingRisk,
            ),
            card(
                "fork_drift_watch",
                "fork/AKHtun/turbovec-wecos",
                TurboVecMotifClass::ForkDrift,
            ),
            card(
                "large_model_working_set",
                "README.md",
                TurboVecMotifClass::LargeModelWorkingSet,
            ),
        ]
    }

    fn proof_refs() -> TurboVecMotifExtractionProofRefs {
        TurboVecMotifExtractionProofRefs {
            source_inspection_policy_ref: SOURCE_INSPECTION_POLICY_WITNESS_REF.to_string(),
            provenance_ref: format!("{PROVENANCE_REF_PREFIX}source-card-pack"),
            clean_room_ref: format!("{CLEAN_ROOM_REF_PREFIX}no-verbatim"),
            source_card_ref: format!("{SOURCE_CARD_REF_PREFIX}motif-pack"),
            fork_sweep_ref: format!("{FORK_SWEEP_REF_PREFIX}public-forks"),
            no_product_graph_ref: format!("{NO_PRODUCT_GRAPH_REF_PREFIX}no-import"),
            rollback_ref: format!("{ROLLBACK_REF_PREFIX}motif-pack"),
            run_event_log_ref: format!("{RUN_EVENT_LOG_REF_PREFIX}motif-pack"),
            answer_packet_ref: format!("{ANSWER_PACKET_REF_PREFIX}motif-pack"),
            compatibility_fence_ref: format!("{COMPATIBILITY_REF_PREFIX}motif-pack"),
            benchmark_caveat_ref: format!("{BENCHMARK_CAVEAT_REF_PREFIX}motif-pack"),
            visible_summary: "clean-room TurboVec motif extraction for large local model working sets. It records paraphrased source-card motifs for Eidos/AppColdStore and SemanticWorkingSetPlan with no hidden route authority, no live dense 70B claim, no product import, no runtime execution, no benchmark authority, rollback, RunEventLog, AnswerPacket visibility, and compatibility fences before any route or user-facing surface can cite the motifs. The motifs can shape future falsifiers and adapter cards only; they cannot choose RuntimeRouter/System G routes, inject context into Gemma/QAT/Qwen/Granite lanes, or stand in for measured compressed-retrieval quality.".to_string(),
        }
    }

    fn accepted(
    ) -> Result<TurboVecRealAdapterMotifExtractionCardProbeSet, TurboVecMotifExtractionError> {
        TurboVecRealAdapterMotifExtractionCardProbeSet::from_parts(
            upstream(),
            cards(),
            TurboVecMotifExtractionPolicy::fail_closed(),
            proof_refs(),
            TurboVecMotifExtractionByteLedger::selected_source_only(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecMotifExtractionStatus::MotifCardsOnly,
            TurboVecMotifExtractionTier::T1L1Metadata,
            vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
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
    fn accepts_clean_room_motif_pack() {
        let set = accepted().expect("accepted motif pack");
        let metrics = set.metrics();
        assert_eq!(metrics.motif_count, 10);
        assert!(metrics.motif_class_count >= MIN_MOTIF_CLASS_COUNT as u64);
        assert_eq!(metrics.product_files_copied, 0);
        assert!(metrics.selected_raw_source_bytes_inspected <= MAX_SOURCE_BYTES_INSPECTED);
    }

    #[test]
    fn address_is_deterministic_when_motifs_reordered() {
        let mut reversed = cards();
        reversed.reverse();
        let left = accepted().expect("accepted motif pack");
        let right = TurboVecRealAdapterMotifExtractionCardProbeSet::from_parts(
            upstream(),
            reversed,
            TurboVecMotifExtractionPolicy::fail_closed(),
            proof_refs(),
            TurboVecMotifExtractionByteLedger::selected_source_only(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecMotifExtractionStatus::MotifCardsOnly,
            TurboVecMotifExtractionTier::T1L1Metadata,
            vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        )
        .expect("reordered motif pack");
        assert_eq!(left.set_address, right.set_address);
        assert_eq!(
            motif_extraction_digest(&left),
            motif_extraction_digest(&right)
        );
    }

    #[test]
    fn rejects_product_import_and_hidden_route_authority() {
        let mut bad_cards = cards();
        bad_cards[0].no_product_import = false;
        assert!(TurboVecRealAdapterMotifExtractionCardProbeSet::from_parts(
            upstream(),
            bad_cards,
            TurboVecMotifExtractionPolicy::fail_closed(),
            proof_refs(),
            TurboVecMotifExtractionByteLedger::selected_source_only(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecMotifExtractionStatus::MotifCardsOnly,
            TurboVecMotifExtractionTier::T1L1Metadata,
            vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            false,
            true,
            false,
            true,
            false,
            false,
            false,
        )
        .is_err());
    }

    #[test]
    fn rejects_blocked_paths_and_byte_overflow() {
        let mut bad_cards = cards();
        bad_cards[0].source_path = "turbovec/build.rs".to_string();
        assert!(TurboVecRealAdapterMotifExtractionCardProbeSet::from_parts(
            upstream(),
            bad_cards,
            TurboVecMotifExtractionPolicy::fail_closed(),
            proof_refs(),
            TurboVecMotifExtractionByteLedger::selected_source_only(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecMotifExtractionStatus::MotifCardsOnly,
            TurboVecMotifExtractionTier::T1L1Metadata,
            vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        )
        .is_err());

        let mut ledger = TurboVecMotifExtractionByteLedger::selected_source_only();
        ledger.selected_raw_source_bytes_inspected = MAX_SOURCE_BYTES_INSPECTED + 1;
        assert!(TurboVecRealAdapterMotifExtractionCardProbeSet::from_parts(
            upstream(),
            cards(),
            TurboVecMotifExtractionPolicy::fail_closed(),
            proof_refs(),
            ledger,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecMotifExtractionStatus::MotifCardsOnly,
            TurboVecMotifExtractionTier::T1L1Metadata,
            vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        )
        .is_err());
    }

    #[test]
    fn rejects_missing_class_diversity_and_bad_upstream() {
        let mut bad_cards = cards();
        bad_cards.retain(|card| card.motif_class != TurboVecMotifClass::InputValidation);
        assert!(TurboVecRealAdapterMotifExtractionCardProbeSet::from_parts(
            upstream(),
            bad_cards,
            TurboVecMotifExtractionPolicy::fail_closed(),
            proof_refs(),
            TurboVecMotifExtractionByteLedger::selected_source_only(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecMotifExtractionStatus::MotifCardsOnly,
            TurboVecMotifExtractionTier::T1L1Metadata,
            vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        )
        .is_err());

        let bad_upstream = UasAddress::new(UasKind::Other("wrong_cursor".to_string()), b"abc", 1);
        assert!(TurboVecRealAdapterMotifExtractionCardProbeSet::from_parts(
            bad_upstream,
            cards(),
            TurboVecMotifExtractionPolicy::fail_closed(),
            proof_refs(),
            TurboVecMotifExtractionByteLedger::selected_source_only(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecMotifExtractionStatus::MotifCardsOnly,
            TurboVecMotifExtractionTier::T1L1Metadata,
            vec![
                TurboVecIndexOrgan::Eidos,
                TurboVecIndexOrgan::AppColdStore,
                TurboVecIndexOrgan::SemanticWorkingSetPlan,
                TurboVecIndexOrgan::AnswerPacket,
            ],
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        )
        .is_err());
    }
}
