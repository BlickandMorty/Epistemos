//! KV source-card fork/daemon boundary.
//!
//! This primitive consumes the metadata-only `F-KVRuntimeSourceCard` lane and
//! classifies fork/runtime motifs before any of them can become product route
//! authority. It does not clone repositories, open source trees, start
//! daemons, execute commands, load model/KV/runtime/index bytes, or promote
//! L2/L3 product capability.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::uas::construction_card::{pro_status_preimage, product_build_preimage};
use crate::uas::{CompressedModelPromotionTier, ProStatus, ProductBuild, UasAddress, UasKind};

pub const KV_SOURCE_CARD_FORK_AND_DAEMON_BOUNDARY_CURSOR: &str =
    "kv_source_card_fork_and_daemon_boundary";
pub const KV_SOURCE_CARD_FORK_AND_DAEMON_BOUNDARY_NEXT_CURSOR: &str =
    "hardware_tiered_model_catalog_source_card";

const UPSTREAM_ARTIFACT_PREFIX: &str = "artifact:falsifiers/kv_runtime_source_card/result.json";
const FALSIFIER_PREFIX: &str = "falsifier:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const COMPAT_PREFIX: &str = "compat:";
const PRIVACY_PREFIX: &str = "privacy:";
const MAS_PRO_PREFIX: &str = "mas_pro:";
const BOUNDARY_PREFIX: &str = "boundary:";
const OWNER_APPROVAL_PENDING_PREFIX: &str = "owner_approval:pending";
const MAX_PLAN_METADATA_BYTES: u64 = 384 * 1024;
const MAX_DECISION_METADATA_BYTES: u64 = 48 * 1024;

const ACCEPTED_SOURCE_CARD_IDS: &[&str] = &[
    "vllm_paged_attention",
    "lmcache_reusable_kv",
    "sglang_hicache_radix",
    "ktransformers_heterogeneous_prefix",
    "flexllmgen_offload_optimizer",
    "powerinfer_activation_locality",
    "kivi_asymmetric_kv",
    "transformers_quantized_cache",
    "llamacpp_prompt_cache",
];

// UAS: uas:kv-boundary:classification
// Plane: Controller + Verification
// Residency: route eligibility class for source-carded KV/runtime motifs.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KvBoundaryClassification {
    ProductEligibleInProcess,
    OwnerApprovedCommand,
    QuarantineServerDaemon,
    RemoteOrDistributedDenied,
    ResearchOnly,
}

// UAS: uas:kv-boundary:runtime-shape
// Plane: Controller
// Residency: observed upstream runtime shape; not an Epistemos execution path.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KvBoundaryRuntimeShape {
    InProcessLibrary,
    CliCommand,
    ServerFramework,
    DaemonCacheLayer,
    DistributedCluster,
    PythonRuntime,
    CppRuntime,
    MetadataOnly,
}

// UAS: uas:kv-boundary:byte-scope
// Plane: Verification
// Residency: metadata-only accounting for boundary decisions.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvBoundaryByteScope {
    pub metadata_bytes_read: u64,
    pub source_tree_bytes_read: u64,
    pub model_bytes_loaded: u64,
    pub kv_bytes_loaded: u64,
    pub index_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub product_files_copied: u64,
    pub command_executions: u64,
    pub benchmark_runs: u64,
}

impl KvBoundaryByteScope {
    pub fn metadata_only(metadata_bytes_read: u64) -> Self {
        Self {
            metadata_bytes_read,
            source_tree_bytes_read: 0,
            model_bytes_loaded: 0,
            kv_bytes_loaded: 0,
            index_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            product_files_copied: 0,
            command_executions: 0,
            benchmark_runs: 0,
        }
    }
}

// UAS: uas:kv-boundary:proof-refs
// Plane: Verification
// Residency: visible proof handles required before downstream citations.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvBoundaryProofRefs {
    pub falsifier_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
    pub privacy_policy_ref: String,
    pub mas_pro_boundary_ref: String,
    pub boundary_ref: String,
}

// UAS: uas:kv-boundary:decision
// Plane: State + Controller + Verification
// Residency: classification of one upstream KV/runtime source card.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvBoundaryDecision {
    pub decision_id: String,
    pub source_card_id: String,
    pub upstream_project_ref: String,
    pub runtime_shape: KvBoundaryRuntimeShape,
    pub classification: KvBoundaryClassification,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub owner_approval_ref: Option<String>,
    pub command_armed: bool,
    pub command_executed: bool,
    pub server_or_daemon: bool,
    pub remote_or_distributed: bool,
    pub product_route_enabled: bool,
    pub mas_eligible_live: bool,
    pub hidden_route_authority: bool,
    pub hidden_cache_authority: bool,
    pub l2_l3_promotion_claim: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub byte_scope: KvBoundaryByteScope,
    pub proof_refs: KvBoundaryProofRefs,
}

// UAS: uas:kv-boundary:plan
// Plane: State + Controller + Verification
// Residency: metadata-only fork/daemon boundary plan.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvSourceCardForkDaemonBoundaryPlan {
    pub plan_address: UasAddress,
    pub upstream_kv_runtime_source_card_ref: String,
    pub decisions: Vec<KvBoundaryDecision>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub promotion_tier: CompressedModelPromotionTier,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub product_route_blocked: bool,
    pub hidden_authority_blocked: bool,
    pub server_daemon_quarantine_required: bool,
    pub remote_distributed_denied: bool,
    pub owner_approved_commands_unarmed: bool,
}

// UAS: uas:kv-boundary:metrics
// Plane: Verification
// Residency: derived counters for artifact axes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KvBoundaryMetrics {
    pub decision_count: u64,
    pub classification_count: u64,
    pub runtime_shape_count: u64,
    pub source_card_count: u64,
    pub product_eligible_count: u64,
    pub owner_approved_command_count: u64,
    pub quarantine_server_daemon_count: u64,
    pub remote_or_distributed_denied_count: u64,
    pub research_only_count: u64,
    pub server_or_daemon_count: u64,
    pub remote_or_distributed_count: u64,
    pub metadata_bytes_read: u64,
    pub source_tree_bytes_read: u64,
    pub model_bytes_loaded: u64,
    pub kv_bytes_loaded: u64,
    pub index_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub product_files_copied: u64,
    pub command_executions: u64,
    pub benchmark_runs: u64,
}

impl KvSourceCardForkDaemonBoundaryPlan {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        upstream_kv_runtime_source_card_ref: impl Into<String>,
        mut decisions: Vec<KvBoundaryDecision>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        promotion_tier: CompressedModelPromotionTier,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        product_route_blocked: bool,
        hidden_authority_blocked: bool,
        server_daemon_quarantine_required: bool,
        remote_distributed_denied: bool,
        owner_approved_commands_unarmed: bool,
        created_at_ms: u64,
    ) -> Result<Self, KvBoundaryError> {
        let upstream_kv_runtime_source_card_ref = upstream_kv_runtime_source_card_ref.into();
        decisions.sort_by(|a, b| a.decision_id.cmp(&b.decision_id));
        validate_plan_inputs(
            &upstream_kv_runtime_source_card_ref,
            &decisions,
            &product_build,
            &pro_status,
            &promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            product_route_blocked,
            hidden_authority_blocked,
            server_daemon_quarantine_required,
            remote_distributed_denied,
            owner_approved_commands_unarmed,
        )?;
        let plan_address = plan_address(
            &upstream_kv_runtime_source_card_ref,
            &decisions,
            &product_build,
            &pro_status,
            &promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            product_route_blocked,
            hidden_authority_blocked,
            server_daemon_quarantine_required,
            remote_distributed_denied,
            owner_approved_commands_unarmed,
            created_at_ms,
        );
        Ok(Self {
            plan_address,
            upstream_kv_runtime_source_card_ref,
            decisions,
            product_build,
            pro_status,
            promotion_tier,
            metadata_bytes,
            l1_l2_l3_separated,
            product_route_blocked,
            hidden_authority_blocked,
            server_daemon_quarantine_required,
            remote_distributed_denied,
            owner_approved_commands_unarmed,
        })
    }

    pub fn metrics(&self) -> KvBoundaryMetrics {
        let mut classifications = BTreeSet::new();
        let mut runtime_shapes = BTreeSet::new();
        let mut source_cards = BTreeSet::new();
        for decision in &self.decisions {
            classifications.insert(decision.classification);
            runtime_shapes.insert(decision.runtime_shape);
            source_cards.insert(decision.source_card_id.as_str());
        }
        KvBoundaryMetrics {
            decision_count: self.decisions.len() as u64,
            classification_count: classifications.len() as u64,
            runtime_shape_count: runtime_shapes.len() as u64,
            source_card_count: source_cards.len() as u64,
            product_eligible_count: count_class(
                &self.decisions,
                KvBoundaryClassification::ProductEligibleInProcess,
            ),
            owner_approved_command_count: count_class(
                &self.decisions,
                KvBoundaryClassification::OwnerApprovedCommand,
            ),
            quarantine_server_daemon_count: count_class(
                &self.decisions,
                KvBoundaryClassification::QuarantineServerDaemon,
            ),
            remote_or_distributed_denied_count: count_class(
                &self.decisions,
                KvBoundaryClassification::RemoteOrDistributedDenied,
            ),
            research_only_count: count_class(
                &self.decisions,
                KvBoundaryClassification::ResearchOnly,
            ),
            server_or_daemon_count: self
                .decisions
                .iter()
                .filter(|decision| decision.server_or_daemon)
                .count() as u64,
            remote_or_distributed_count: self
                .decisions
                .iter()
                .filter(|decision| decision.remote_or_distributed)
                .count() as u64,
            metadata_bytes_read: self
                .decisions
                .iter()
                .map(|decision| decision.byte_scope.metadata_bytes_read)
                .sum(),
            source_tree_bytes_read: self
                .decisions
                .iter()
                .map(|decision| decision.byte_scope.source_tree_bytes_read)
                .sum(),
            model_bytes_loaded: self
                .decisions
                .iter()
                .map(|decision| decision.byte_scope.model_bytes_loaded)
                .sum(),
            kv_bytes_loaded: self
                .decisions
                .iter()
                .map(|decision| decision.byte_scope.kv_bytes_loaded)
                .sum(),
            index_bytes_loaded: self
                .decisions
                .iter()
                .map(|decision| decision.byte_scope.index_bytes_loaded)
                .sum(),
            runtime_bytes_loaded: self
                .decisions
                .iter()
                .map(|decision| decision.byte_scope.runtime_bytes_loaded)
                .sum(),
            provider_calls_made: self
                .decisions
                .iter()
                .map(|decision| decision.byte_scope.provider_calls_made)
                .sum(),
            product_files_copied: self
                .decisions
                .iter()
                .map(|decision| decision.byte_scope.product_files_copied)
                .sum(),
            command_executions: self
                .decisions
                .iter()
                .map(|decision| decision.byte_scope.command_executions)
                .sum(),
            benchmark_runs: self
                .decisions
                .iter()
                .map(|decision| decision.byte_scope.benchmark_runs)
                .sum(),
        }
    }

    pub fn address(&self) -> String {
        self.plan_address.to_string()
    }
}

// UAS: uas:kv-boundary:error
// Plane: Verification
// Residency: fail-closed boundary rejection taxonomy.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum KvBoundaryError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    BadUpstreamArtifactRef,
    EmptyDecisionSet,
    DuplicateDecisionId(String),
    DuplicateSourceCardId(String),
    UnknownSourceCardId(String),
    ProductPromotionFromResearch(String),
    MissingLayerSeparation,
    BadProofRefPrefix {
        decision_id: String,
        field: &'static str,
    },
    ServerDaemonNotQuarantined(String),
    RemoteDistributedNotDenied(String),
    OwnerCommandMissingApproval(String),
    OwnerCommandArmed(String),
    OwnerCommandExecuted(String),
    ResearchOnlyProductRoute(String),
    ProductEligibleHasRemoteOrDaemon(String),
    MasLiveClaim(String),
    HiddenRouteAuthority(String),
    HiddenCacheAuthority(String),
    NonzeroSourceTreeBytes(String),
    NonzeroModelBytes(String),
    NonzeroKvBytes(String),
    NonzeroIndexBytes(String),
    NonzeroRuntimeBytes(String),
    ProviderCallMade(String),
    ProductFileCopied(String),
    CommandExecuted(String),
    BenchmarkRun(String),
    L2L3PromotionClaim(String),
    LiveDense70BClaim(String),
    SsdAsRamClaim(String),
    MetadataBudgetExceeded,
}

impl fmt::Display for KvBoundaryError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::BadUpstreamArtifactRef => write!(f, "bad upstream KV runtime source-card ref"),
            Self::EmptyDecisionSet => write!(f, "missing KV boundary decisions"),
            Self::DuplicateDecisionId(id) => write!(f, "duplicate decision id `{id}`"),
            Self::DuplicateSourceCardId(id) => write!(f, "duplicate source card id `{id}`"),
            Self::UnknownSourceCardId(id) => write!(f, "unknown source card id `{id}`"),
            Self::ProductPromotionFromResearch(id) => {
                write!(f, "decision `{id}` promoted research to product")
            }
            Self::MissingLayerSeparation => write!(f, "missing L1/L2/L3 boundary flags"),
            Self::BadProofRefPrefix { decision_id, field } => {
                write!(f, "decision `{decision_id}` has bad proof ref `{field}`")
            }
            Self::ServerDaemonNotQuarantined(id) => {
                write!(f, "decision `{id}` did not quarantine server/daemon source")
            }
            Self::RemoteDistributedNotDenied(id) => {
                write!(f, "decision `{id}` did not deny remote/distributed source")
            }
            Self::OwnerCommandMissingApproval(id) => {
                write!(f, "decision `{id}` missing pending owner approval")
            }
            Self::OwnerCommandArmed(id) => write!(f, "decision `{id}` armed a command"),
            Self::OwnerCommandExecuted(id) => write!(f, "decision `{id}` executed a command"),
            Self::ResearchOnlyProductRoute(id) => {
                write!(f, "decision `{id}` enabled research-only product route")
            }
            Self::ProductEligibleHasRemoteOrDaemon(id) => {
                write!(
                    f,
                    "decision `{id}` marked remote/server/daemon product eligible"
                )
            }
            Self::MasLiveClaim(id) => write!(f, "decision `{id}` claimed MAS live eligibility"),
            Self::HiddenRouteAuthority(id) => write!(f, "decision `{id}` hid route authority"),
            Self::HiddenCacheAuthority(id) => write!(f, "decision `{id}` hid cache authority"),
            Self::NonzeroSourceTreeBytes(id) => write!(f, "decision `{id}` read source bytes"),
            Self::NonzeroModelBytes(id) => write!(f, "decision `{id}` loaded model bytes"),
            Self::NonzeroKvBytes(id) => write!(f, "decision `{id}` loaded KV bytes"),
            Self::NonzeroIndexBytes(id) => write!(f, "decision `{id}` loaded index bytes"),
            Self::NonzeroRuntimeBytes(id) => write!(f, "decision `{id}` loaded runtime bytes"),
            Self::ProviderCallMade(id) => write!(f, "decision `{id}` made provider calls"),
            Self::ProductFileCopied(id) => write!(f, "decision `{id}` copied product files"),
            Self::CommandExecuted(id) => write!(f, "decision `{id}` executed command bytes"),
            Self::BenchmarkRun(id) => write!(f, "decision `{id}` ran benchmarks"),
            Self::L2L3PromotionClaim(id) => write!(f, "decision `{id}` claimed L2/L3 promotion"),
            Self::LiveDense70BClaim(id) => write!(f, "decision `{id}` claimed live dense 70B"),
            Self::SsdAsRamClaim(id) => write!(f, "decision `{id}` claimed SSD as RAM"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for KvBoundaryError {}

#[allow(clippy::too_many_arguments)]
fn validate_plan_inputs(
    upstream_ref: &str,
    decisions: &[KvBoundaryDecision],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    promotion_tier: &CompressedModelPromotionTier,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    product_route_blocked: bool,
    hidden_authority_blocked: bool,
    server_daemon_quarantine_required: bool,
    remote_distributed_denied: bool,
    owner_approved_commands_unarmed: bool,
) -> Result<(), KvBoundaryError> {
    if !upstream_ref.starts_with(UPSTREAM_ARTIFACT_PREFIX) {
        return Err(KvBoundaryError::BadUpstreamArtifactRef);
    }
    if decisions.is_empty() {
        return Err(KvBoundaryError::EmptyDecisionSet);
    }
    if metadata_bytes > MAX_PLAN_METADATA_BYTES {
        return Err(KvBoundaryError::MetadataBudgetExceeded);
    }
    if *product_build != ProductBuild::Pro
        || !matches!(pro_status, ProStatus::ResearchCandidate | ProStatus::Gated)
        || !matches!(
            promotion_tier,
            CompressedModelPromotionTier::T0Research | CompressedModelPromotionTier::T1L1Metadata
        )
    {
        return Err(KvBoundaryError::ProductPromotionFromResearch(
            "plan".to_string(),
        ));
    }
    if !l1_l2_l3_separated
        || !product_route_blocked
        || !hidden_authority_blocked
        || !server_daemon_quarantine_required
        || !remote_distributed_denied
        || !owner_approved_commands_unarmed
    {
        return Err(KvBoundaryError::MissingLayerSeparation);
    }

    let accepted = ACCEPTED_SOURCE_CARD_IDS
        .iter()
        .copied()
        .collect::<HashSet<_>>();
    let mut decision_ids = HashSet::new();
    let mut source_card_ids = HashSet::new();
    for decision in decisions {
        validate_decision_common(decision)?;
        if !decision_ids.insert(decision.decision_id.clone()) {
            return Err(KvBoundaryError::DuplicateDecisionId(
                decision.decision_id.clone(),
            ));
        }
        if !source_card_ids.insert(decision.source_card_id.clone()) {
            return Err(KvBoundaryError::DuplicateSourceCardId(
                decision.source_card_id.clone(),
            ));
        }
        if !accepted.contains(decision.source_card_id.as_str()) {
            return Err(KvBoundaryError::UnknownSourceCardId(
                decision.source_card_id.clone(),
            ));
        }
        validate_classification(decision)?;
        validate_byte_scope(decision)?;
        reject_forbidden_claims(decision)?;
    }
    Ok(())
}

fn validate_decision_common(decision: &KvBoundaryDecision) -> Result<(), KvBoundaryError> {
    for (field, value) in [
        ("decision_id", decision.decision_id.as_str()),
        ("source_card_id", decision.source_card_id.as_str()),
        (
            "upstream_project_ref",
            decision.upstream_project_ref.as_str(),
        ),
    ] {
        validate_nonempty(field, value)?;
    }
    if let Some(owner_approval_ref) = &decision.owner_approval_ref {
        validate_nonempty("owner_approval_ref", owner_approval_ref)?;
    }
    if decision.product_build != ProductBuild::Pro
        || !matches!(
            decision.pro_status,
            ProStatus::ResearchCandidate | ProStatus::Gated
        )
        || !matches!(
            decision.promotion_tier,
            CompressedModelPromotionTier::T0Research | CompressedModelPromotionTier::T1L1Metadata
        )
    {
        return Err(KvBoundaryError::ProductPromotionFromResearch(
            decision.decision_id.clone(),
        ));
    }
    validate_proof_refs(&decision.decision_id, &decision.proof_refs)?;
    Ok(())
}

fn validate_classification(decision: &KvBoundaryDecision) -> Result<(), KvBoundaryError> {
    let server_or_daemon_shape = matches!(
        decision.runtime_shape,
        KvBoundaryRuntimeShape::ServerFramework | KvBoundaryRuntimeShape::DaemonCacheLayer
    );
    let remote_shape = matches!(
        decision.runtime_shape,
        KvBoundaryRuntimeShape::DistributedCluster
    );
    if server_or_daemon_shape
        && (decision.classification != KvBoundaryClassification::QuarantineServerDaemon
            || !decision.server_or_daemon)
    {
        return Err(KvBoundaryError::ServerDaemonNotQuarantined(
            decision.decision_id.clone(),
        ));
    }
    if remote_shape
        && (decision.classification != KvBoundaryClassification::RemoteOrDistributedDenied
            || !decision.remote_or_distributed)
    {
        return Err(KvBoundaryError::RemoteDistributedNotDenied(
            decision.decision_id.clone(),
        ));
    }
    if decision.classification == KvBoundaryClassification::RemoteOrDistributedDenied
        && !decision.remote_or_distributed
    {
        return Err(KvBoundaryError::RemoteDistributedNotDenied(
            decision.decision_id.clone(),
        ));
    }
    if decision.classification == KvBoundaryClassification::OwnerApprovedCommand {
        let Some(owner_approval_ref) = decision.owner_approval_ref.as_deref() else {
            return Err(KvBoundaryError::OwnerCommandMissingApproval(
                decision.decision_id.clone(),
            ));
        };
        if !owner_approval_ref.starts_with(OWNER_APPROVAL_PENDING_PREFIX) {
            return Err(KvBoundaryError::OwnerCommandMissingApproval(
                decision.decision_id.clone(),
            ));
        }
        if decision.command_armed {
            return Err(KvBoundaryError::OwnerCommandArmed(
                decision.decision_id.clone(),
            ));
        }
        if decision.command_executed {
            return Err(KvBoundaryError::OwnerCommandExecuted(
                decision.decision_id.clone(),
            ));
        }
    }
    if decision.classification == KvBoundaryClassification::ResearchOnly
        && decision.product_route_enabled
    {
        return Err(KvBoundaryError::ResearchOnlyProductRoute(
            decision.decision_id.clone(),
        ));
    }
    if decision.classification == KvBoundaryClassification::ProductEligibleInProcess
        && (decision.server_or_daemon || decision.remote_or_distributed)
    {
        return Err(KvBoundaryError::ProductEligibleHasRemoteOrDaemon(
            decision.decision_id.clone(),
        ));
    }
    if decision.mas_eligible_live {
        return Err(KvBoundaryError::MasLiveClaim(decision.decision_id.clone()));
    }
    Ok(())
}

fn validate_byte_scope(decision: &KvBoundaryDecision) -> Result<(), KvBoundaryError> {
    if decision.byte_scope.metadata_bytes_read > MAX_DECISION_METADATA_BYTES {
        return Err(KvBoundaryError::MetadataBudgetExceeded);
    }
    if decision.byte_scope.source_tree_bytes_read != 0 {
        return Err(KvBoundaryError::NonzeroSourceTreeBytes(
            decision.decision_id.clone(),
        ));
    }
    if decision.byte_scope.model_bytes_loaded != 0 {
        return Err(KvBoundaryError::NonzeroModelBytes(
            decision.decision_id.clone(),
        ));
    }
    if decision.byte_scope.kv_bytes_loaded != 0 {
        return Err(KvBoundaryError::NonzeroKvBytes(
            decision.decision_id.clone(),
        ));
    }
    if decision.byte_scope.index_bytes_loaded != 0 {
        return Err(KvBoundaryError::NonzeroIndexBytes(
            decision.decision_id.clone(),
        ));
    }
    if decision.byte_scope.runtime_bytes_loaded != 0 {
        return Err(KvBoundaryError::NonzeroRuntimeBytes(
            decision.decision_id.clone(),
        ));
    }
    if decision.byte_scope.provider_calls_made != 0 {
        return Err(KvBoundaryError::ProviderCallMade(
            decision.decision_id.clone(),
        ));
    }
    if decision.byte_scope.product_files_copied != 0 {
        return Err(KvBoundaryError::ProductFileCopied(
            decision.decision_id.clone(),
        ));
    }
    if decision.byte_scope.command_executions != 0 {
        return Err(KvBoundaryError::CommandExecuted(
            decision.decision_id.clone(),
        ));
    }
    if decision.byte_scope.benchmark_runs != 0 {
        return Err(KvBoundaryError::BenchmarkRun(decision.decision_id.clone()));
    }
    Ok(())
}

fn reject_forbidden_claims(decision: &KvBoundaryDecision) -> Result<(), KvBoundaryError> {
    if decision.product_route_enabled {
        return Err(KvBoundaryError::ProductPromotionFromResearch(
            decision.decision_id.clone(),
        ));
    }
    if decision.hidden_route_authority {
        return Err(KvBoundaryError::HiddenRouteAuthority(
            decision.decision_id.clone(),
        ));
    }
    if decision.hidden_cache_authority {
        return Err(KvBoundaryError::HiddenCacheAuthority(
            decision.decision_id.clone(),
        ));
    }
    if decision.l2_l3_promotion_claim {
        return Err(KvBoundaryError::L2L3PromotionClaim(
            decision.decision_id.clone(),
        ));
    }
    if decision.live_dense_70b_claim {
        return Err(KvBoundaryError::LiveDense70BClaim(
            decision.decision_id.clone(),
        ));
    }
    if decision.ssd_as_ram_claim {
        return Err(KvBoundaryError::SsdAsRamClaim(decision.decision_id.clone()));
    }
    Ok(())
}

fn validate_proof_refs(
    decision_id: &str,
    proof_refs: &KvBoundaryProofRefs,
) -> Result<(), KvBoundaryError> {
    for (field, value, prefix) in [
        (
            "falsifier_ref",
            proof_refs.falsifier_ref.as_str(),
            FALSIFIER_PREFIX,
        ),
        (
            "rollback_ref",
            proof_refs.rollback_ref.as_str(),
            ROLLBACK_PREFIX,
        ),
        (
            "run_event_log_ref",
            proof_refs.run_event_log_ref.as_str(),
            RUN_EVENT_LOG_PREFIX,
        ),
        (
            "answer_packet_ref",
            proof_refs.answer_packet_ref.as_str(),
            ANSWER_PACKET_PREFIX,
        ),
        (
            "compatibility_fence_ref",
            proof_refs.compatibility_fence_ref.as_str(),
            COMPAT_PREFIX,
        ),
        (
            "privacy_policy_ref",
            proof_refs.privacy_policy_ref.as_str(),
            PRIVACY_PREFIX,
        ),
        (
            "mas_pro_boundary_ref",
            proof_refs.mas_pro_boundary_ref.as_str(),
            MAS_PRO_PREFIX,
        ),
        (
            "boundary_ref",
            proof_refs.boundary_ref.as_str(),
            BOUNDARY_PREFIX,
        ),
    ] {
        validate_nonempty(field, value)?;
        if !value.starts_with(prefix) {
            return Err(KvBoundaryError::BadProofRefPrefix {
                decision_id: decision_id.to_string(),
                field,
            });
        }
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn plan_address(
    upstream_ref: &str,
    decisions: &[KvBoundaryDecision],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    promotion_tier: &CompressedModelPromotionTier,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    product_route_blocked: bool,
    hidden_authority_blocked: bool,
    server_daemon_quarantine_required: bool,
    remote_distributed_denied: bool,
    owner_approved_commands_unarmed: bool,
    created_at_ms: u64,
) -> UasAddress {
    let mut preimage = String::new();
    preimage.push_str(KV_SOURCE_CARD_FORK_AND_DAEMON_BOUNDARY_CURSOR);
    preimage.push('\n');
    preimage.push_str(upstream_ref);
    preimage.push('\n');
    preimage.push_str(product_build_preimage(product_build));
    preimage.push('\n');
    preimage.push_str(pro_status_preimage(pro_status));
    preimage.push('\n');
    preimage.push_str(&format!("{promotion_tier:?}\n{metadata_bytes}\n"));
    for flag in [
        l1_l2_l3_separated,
        product_route_blocked,
        hidden_authority_blocked,
        server_daemon_quarantine_required,
        remote_distributed_denied,
        owner_approved_commands_unarmed,
    ] {
        preimage.push_str(if flag { "true" } else { "false" });
        preimage.push('\n');
    }
    for decision in decisions {
        push_decision_preimage(&mut preimage, decision);
    }
    UasAddress::new(
        UasKind::Other(KV_SOURCE_CARD_FORK_AND_DAEMON_BOUNDARY_CURSOR.to_string()),
        preimage.as_bytes(),
        created_at_ms,
    )
}

fn push_decision_preimage(preimage: &mut String, decision: &KvBoundaryDecision) {
    preimage.push_str(&decision.decision_id);
    preimage.push('|');
    preimage.push_str(&decision.source_card_id);
    preimage.push('|');
    preimage.push_str(&decision.upstream_project_ref);
    preimage.push('|');
    preimage.push_str(&format!(
        "{:?}|{:?}|{:?}|{:?}",
        decision.runtime_shape,
        decision.classification,
        decision.pro_status,
        decision.promotion_tier
    ));
    preimage.push('|');
    preimage.push_str(decision.owner_approval_ref.as_deref().unwrap_or("none"));
    preimage.push('|');
    for flag in [
        decision.command_armed,
        decision.command_executed,
        decision.server_or_daemon,
        decision.remote_or_distributed,
        decision.product_route_enabled,
        decision.mas_eligible_live,
        decision.hidden_route_authority,
        decision.hidden_cache_authority,
        decision.l2_l3_promotion_claim,
        decision.live_dense_70b_claim,
        decision.ssd_as_ram_claim,
    ] {
        preimage.push_str(if flag { "true," } else { "false," });
    }
    preimage.push('\n');
}

fn count_class(decisions: &[KvBoundaryDecision], classification: KvBoundaryClassification) -> u64 {
    decisions
        .iter()
        .filter(|decision| decision.classification == classification)
        .count() as u64
}

fn validate_nonempty(field: &'static str, value: &str) -> Result<(), KvBoundaryError> {
    if value.is_empty() {
        return Err(KvBoundaryError::MissingField(field));
    }
    if value.trim() != value {
        return Err(KvBoundaryError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(char::is_control) {
        return Err(KvBoundaryError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_140_000_000;
    const UPSTREAM_REF: &str = "artifact:falsifiers/kv_runtime_source_card/result.json#sha256:test";

    #[test]
    fn accepted_plan_is_deterministic_and_metadata_only() {
        let decisions = fixture_decisions();
        let plan = build_plan(decisions.clone()).expect("valid plan");
        let reversed = build_plan(decisions.into_iter().rev().collect()).expect("valid plan");
        let metrics = plan.metrics();

        assert_eq!(plan.plan_address, reversed.plan_address);
        assert_eq!(
            metrics.decision_count,
            ACCEPTED_SOURCE_CARD_IDS.len() as u64
        );
        assert_eq!(
            metrics.source_card_count,
            ACCEPTED_SOURCE_CARD_IDS.len() as u64
        );
        assert_eq!(metrics.runtime_bytes_loaded, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(metrics.kv_bytes_loaded, 0);
        assert!(plan
            .address()
            .starts_with("kv_source_card_fork_and_daemon_boundary:"));
    }

    #[test]
    fn duplicate_source_card_id_rejects() {
        assert!(reject_decisions(|decisions| {
            decisions[1].source_card_id = decisions[0].source_card_id.clone();
        }));
    }

    #[test]
    fn server_cannot_be_product_eligible() {
        assert!(reject_decisions(|decisions| {
            decisions[0].classification = KvBoundaryClassification::ProductEligibleInProcess;
        }));
    }

    #[test]
    fn remote_cannot_be_owner_command_or_local() {
        assert!(reject_decisions(|decisions| {
            let remote = decisions
                .iter_mut()
                .find(|decision| decision.source_card_id == "sglang_hicache_radix")
                .expect("remote card");
            remote.classification = KvBoundaryClassification::OwnerApprovedCommand;
            remote.owner_approval_ref = Some("owner_approval:pending:sglang".to_string());
        }));
    }

    #[test]
    fn owner_command_cannot_be_armed_or_executed() {
        assert!(reject_decisions(|decisions| {
            let command = decisions
                .iter_mut()
                .find(|decision| decision.source_card_id == "llamacpp_prompt_cache")
                .expect("command card");
            command.command_armed = true;
        }));
        assert!(reject_decisions(|decisions| {
            let command = decisions
                .iter_mut()
                .find(|decision| decision.source_card_id == "llamacpp_prompt_cache")
                .expect("command card");
            command.command_executed = true;
        }));
    }

    #[test]
    fn hidden_authority_rejects() {
        assert!(reject_decisions(|decisions| {
            decisions[2].hidden_route_authority = true;
        }));
        assert!(reject_decisions(|decisions| {
            decisions[2].hidden_cache_authority = true;
        }));
    }

    #[test]
    fn bad_proof_prefix_rejects() {
        assert!(reject_decisions(|decisions| {
            decisions[0].proof_refs.answer_packet_ref = "packet:hidden".to_string();
        }));
    }

    fn reject_decisions(mutate: impl FnOnce(&mut Vec<KvBoundaryDecision>)) -> bool {
        let mut decisions = fixture_decisions();
        mutate(&mut decisions);
        build_plan(decisions).is_err()
    }

    fn build_plan(
        decisions: Vec<KvBoundaryDecision>,
    ) -> Result<KvSourceCardForkDaemonBoundaryPlan, KvBoundaryError> {
        KvSourceCardForkDaemonBoundaryPlan::new(
            UPSTREAM_REF,
            decisions,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            CompressedModelPromotionTier::T1L1Metadata,
            128_000,
            true,
            true,
            true,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
    }

    fn fixture_decisions() -> Vec<KvBoundaryDecision> {
        vec![
            decision(
                "vllm_paged_attention",
                KvBoundaryRuntimeShape::ServerFramework,
                KvBoundaryClassification::QuarantineServerDaemon,
                true,
                false,
                None,
            ),
            decision(
                "lmcache_reusable_kv",
                KvBoundaryRuntimeShape::DaemonCacheLayer,
                KvBoundaryClassification::QuarantineServerDaemon,
                true,
                false,
                None,
            ),
            decision(
                "sglang_hicache_radix",
                KvBoundaryRuntimeShape::DistributedCluster,
                KvBoundaryClassification::RemoteOrDistributedDenied,
                false,
                true,
                None,
            ),
            decision(
                "ktransformers_heterogeneous_prefix",
                KvBoundaryRuntimeShape::PythonRuntime,
                KvBoundaryClassification::ResearchOnly,
                false,
                false,
                None,
            ),
            decision(
                "flexllmgen_offload_optimizer",
                KvBoundaryRuntimeShape::PythonRuntime,
                KvBoundaryClassification::ResearchOnly,
                false,
                false,
                None,
            ),
            decision(
                "powerinfer_activation_locality",
                KvBoundaryRuntimeShape::CppRuntime,
                KvBoundaryClassification::ResearchOnly,
                false,
                false,
                None,
            ),
            decision(
                "kivi_asymmetric_kv",
                KvBoundaryRuntimeShape::MetadataOnly,
                KvBoundaryClassification::ResearchOnly,
                false,
                false,
                None,
            ),
            decision(
                "transformers_quantized_cache",
                KvBoundaryRuntimeShape::PythonRuntime,
                KvBoundaryClassification::ResearchOnly,
                false,
                false,
                None,
            ),
            decision(
                "llamacpp_prompt_cache",
                KvBoundaryRuntimeShape::CliCommand,
                KvBoundaryClassification::OwnerApprovedCommand,
                false,
                false,
                Some("owner_approval:pending:llamacpp-prompt-cache"),
            ),
        ]
    }

    fn decision(
        source_card_id: &str,
        runtime_shape: KvBoundaryRuntimeShape,
        classification: KvBoundaryClassification,
        server_or_daemon: bool,
        remote_or_distributed: bool,
        owner_approval_ref: Option<&str>,
    ) -> KvBoundaryDecision {
        KvBoundaryDecision {
            decision_id: format!("boundary:{source_card_id}"),
            source_card_id: source_card_id.to_string(),
            upstream_project_ref: format!("source_card:{source_card_id}"),
            runtime_shape,
            classification,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
            owner_approval_ref: owner_approval_ref.map(str::to_string),
            command_armed: false,
            command_executed: false,
            server_or_daemon,
            remote_or_distributed,
            product_route_enabled: false,
            mas_eligible_live: false,
            hidden_route_authority: false,
            hidden_cache_authority: false,
            l2_l3_promotion_claim: false,
            live_dense_70b_claim: false,
            ssd_as_ram_claim: false,
            byte_scope: KvBoundaryByteScope::metadata_only(8_192),
            proof_refs: KvBoundaryProofRefs {
                falsifier_ref: format!(
                    "falsifier:F-KVSourceCard-ForkAndDaemonBoundary:{source_card_id}"
                ),
                rollback_ref: format!("rollback:kv-boundary:{source_card_id}"),
                run_event_log_ref: format!("run_event_log:kv-boundary:{source_card_id}"),
                answer_packet_ref: format!("answer_packet:kv-boundary:{source_card_id}"),
                compatibility_fence_ref: format!("compat:kv-boundary:{source_card_id}"),
                privacy_policy_ref: format!("privacy:kv-boundary:{source_card_id}"),
                mas_pro_boundary_ref: format!("mas_pro:kv-boundary:{source_card_id}"),
                boundary_ref: format!("boundary:kv-source-card:{source_card_id}"),
            },
        }
    }
}
