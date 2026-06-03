//! Schema-only Semantic Working-Set compiler dry-run.
//!
//! This is the June 1 `JUNE1-PATTERNBOOST-LOCK` bridge from mission-shaped
//! planning into UAS-addressed support sets. It does not wake model bytes,
//! mmap files, mutate route policy, run MLX/Metal, or promote PatternBoost.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};

use crate::uas::{ByteRange, ProStatus, ProductBuild, ResidencyTier, UasAddress, UasKind};

const PLAN_UAS_KIND: &str = "semantic_working_set_plan";
const QUERY_UAS_KIND: &str = "task_working_set_query";
const ROLLBACK_PREFIX: &str = "rollback:";
const FALLBACK_ROUTE_PREFIXES: [&str; 2] = ["runtime_router:fallback_", "runtime_router:static_"];

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PrivacyClass {
    LocalPrivate,
    VaultPrivate,
    PublicResearch,
}

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EvidenceNeed {
    None,
    ClosedCitation,
    SourcePanel,
    VerifierBacked,
}

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VerifierNeed {
    None,
    Schema,
    Test,
    Lean,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SourceSignalType {
    Bookmark,
    Repo,
    Paper,
    Doc,
    XBookmark,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SourceNoPoisonStatus {
    Clear,
    Blocked,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceCard {
    pub source_id: String,
    pub source_type: SourceSignalType,
    pub locator: String,
    pub digest: String,
    pub credibility_rank: u8,
    pub license_or_usage_note: String,
    pub privacy_class: PrivacyClass,
    pub no_poison_status: SourceNoPoisonStatus,
    pub route_affinities: Vec<String>,
}

impl SourceCard {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        source_id: impl Into<String>,
        source_type: SourceSignalType,
        locator: impl Into<String>,
        digest: impl Into<String>,
        credibility_rank: u8,
        license_or_usage_note: impl Into<String>,
        privacy_class: PrivacyClass,
        no_poison_status: SourceNoPoisonStatus,
        route_affinities: Vec<String>,
    ) -> Result<Self, SemanticWorkingSetError> {
        let source_id = source_id.into();
        let locator = locator.into();
        let digest = digest.into();
        let license_or_usage_note = license_or_usage_note.into();
        validate_nonempty("source_id", &source_id)?;
        validate_nonempty("source_locator", &locator)?;
        validate_nonempty("source_digest", &digest)?;
        validate_nonempty("license_or_usage_note", &license_or_usage_note)?;
        if !is_blake3_digest(&digest) {
            return Err(SemanticWorkingSetError::InvalidSourceDigest { source_id });
        }
        if credibility_rank == 0 {
            return Err(SemanticWorkingSetError::InvalidCredibilityRank { source_id });
        }
        let route_affinities = canonicalize_strings(
            "route_affinities",
            route_affinities,
            SemanticWorkingSetError::MissingRouteAffinity,
        )?;
        Ok(Self {
            source_id,
            source_type,
            locator,
            digest,
            credibility_rank,
            license_or_usage_note,
            privacy_class,
            no_poison_status,
            route_affinities,
        })
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceSignalEdge {
    pub from_source_id: String,
    pub to_source_id: String,
    pub relation: String,
}

impl SourceSignalEdge {
    pub fn new(
        from_source_id: impl Into<String>,
        to_source_id: impl Into<String>,
        relation: impl Into<String>,
    ) -> Result<Self, SemanticWorkingSetError> {
        let from_source_id = from_source_id.into();
        let to_source_id = to_source_id.into();
        let relation = relation.into();
        validate_nonempty("source_id", &from_source_id)?;
        validate_nonempty("source_id", &to_source_id)?;
        validate_nonempty("source_relation", &relation)?;
        Ok(Self {
            from_source_id,
            to_source_id,
            relation,
        })
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceSignalGraph {
    pub graph_address: UasAddress,
    pub source_cards: Vec<SourceCard>,
    pub edges: Vec<SourceSignalEdge>,
    pub route_affinities: Vec<String>,
    pub rejected_source_ids: Vec<String>,
}

impl SourceSignalGraph {
    pub fn intake(
        source_cards: Vec<SourceCard>,
        edges: Vec<SourceSignalEdge>,
        created_at_ms: u64,
    ) -> Result<Self, SemanticWorkingSetError> {
        if source_cards.is_empty() {
            return Err(SemanticWorkingSetError::MissingSourceCard);
        }

        let mut accepted = Vec::with_capacity(source_cards.len());
        let mut rejected_source_ids = Vec::new();
        let mut seen_ids = HashSet::new();
        let mut route_affinity_set = BTreeSet::new();

        for card in source_cards {
            if !seen_ids.insert(card.source_id.clone()) {
                return Err(SemanticWorkingSetError::DuplicateSourceId {
                    source_id: card.source_id,
                });
            }
            if card.no_poison_status == SourceNoPoisonStatus::Blocked {
                rejected_source_ids.push(card.source_id);
                continue;
            }
            for route in &card.route_affinities {
                route_affinity_set.insert(route.clone());
            }
            accepted.push(card);
        }

        if accepted.is_empty() {
            return Err(SemanticWorkingSetError::MissingSourceCard);
        }

        accepted.sort_by(|a, b| a.source_id.cmp(&b.source_id));
        rejected_source_ids.sort();
        let accepted_ids = accepted
            .iter()
            .map(|card| card.source_id.as_str())
            .collect::<HashSet<_>>();
        let rejected_ids = rejected_source_ids
            .iter()
            .map(String::as_str)
            .collect::<HashSet<_>>();
        let mut accepted_edges = Vec::with_capacity(edges.len());
        for edge in edges {
            let from_accepted = accepted_ids.contains(edge.from_source_id.as_str());
            let to_accepted = accepted_ids.contains(edge.to_source_id.as_str());
            if from_accepted && to_accepted {
                accepted_edges.push(edge);
                continue;
            }
            let touches_rejected = rejected_ids.contains(edge.from_source_id.as_str())
                || rejected_ids.contains(edge.to_source_id.as_str());
            if touches_rejected {
                continue;
            }
            return Err(SemanticWorkingSetError::UnknownSourceEdgeEndpoint {
                from_source_id: edge.from_source_id,
                to_source_id: edge.to_source_id,
            });
        }
        accepted_edges.sort_by(|a, b| {
            (&a.from_source_id, &a.to_source_id, &a.relation).cmp(&(
                &b.from_source_id,
                &b.to_source_id,
                &b.relation,
            ))
        });
        accepted_edges.dedup();
        let route_affinities = route_affinity_set.into_iter().collect::<Vec<_>>();
        let graph_address = source_signal_graph_address(
            &accepted,
            &accepted_edges,
            &route_affinities,
            &rejected_source_ids,
            created_at_ms,
        );

        Ok(Self {
            graph_address,
            source_cards: accepted,
            edges: accepted_edges,
            route_affinities,
            rejected_source_ids,
        })
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum WorkingSetStorageTier {
    Hot,
    Warm,
    Cold,
    RemoteReference,
    Unavailable,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum WorkingSetUnitKind {
    EvidencePage,
    KvPage,
    AdapterSlice,
    WeightPage,
    Kernel,
    VerifierLane,
    ScratchBuffer,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TaskWorkingSetQuery {
    pub query_address: UasAddress,
    pub mission_id: String,
    pub task_signature: String,
    pub source_signal_refs: Vec<String>,
    pub privacy_class: PrivacyClass,
    pub deadline_ms: u64,
    pub quality_target_millis: u32,
    pub evidence_need: EvidenceNeed,
    pub verifier_need: VerifierNeed,
    pub max_hot_bytes: u64,
    pub max_kv_bytes: u64,
    pub max_cold_io_bytes: u64,
    pub max_adapter_bytes: u64,
    pub max_evidence_bytes: u64,
    pub max_verifier_bytes: u64,
    pub max_scratch_bytes: u64,
}

impl TaskWorkingSetQuery {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        mission_id: impl Into<String>,
        task_signature: impl Into<String>,
        source_signal_refs: Vec<String>,
        privacy_class: PrivacyClass,
        deadline_ms: u64,
        quality_target_millis: u32,
        evidence_need: EvidenceNeed,
        verifier_need: VerifierNeed,
        max_hot_bytes: u64,
        max_kv_bytes: u64,
        max_cold_io_bytes: u64,
        max_adapter_bytes: u64,
        max_evidence_bytes: u64,
        max_verifier_bytes: u64,
        max_scratch_bytes: u64,
        created_at_ms: u64,
    ) -> Result<Self, SemanticWorkingSetError> {
        let mission_id = mission_id.into();
        let task_signature = task_signature.into();
        validate_nonempty("mission_id", &mission_id)?;
        validate_nonempty("task_signature", &task_signature)?;
        if deadline_ms == 0 || quality_target_millis == 0 {
            return Err(SemanticWorkingSetError::InvalidQueryBudget);
        }
        if max_hot_bytes == 0 || max_kv_bytes == 0 || max_cold_io_bytes == 0 {
            return Err(SemanticWorkingSetError::InvalidQueryBudget);
        }

        let source_signal_refs = canonicalize_strings(
            "source_signal_refs",
            source_signal_refs,
            SemanticWorkingSetError::MissingSourceSignalRef,
        )?;
        let query_address = query_address(
            &mission_id,
            &task_signature,
            &source_signal_refs,
            &privacy_class,
            deadline_ms,
            quality_target_millis,
            &evidence_need,
            &verifier_need,
            max_hot_bytes,
            max_kv_bytes,
            max_cold_io_bytes,
            max_adapter_bytes,
            max_evidence_bytes,
            max_verifier_bytes,
            max_scratch_bytes,
            created_at_ms,
        );

        Ok(Self {
            query_address,
            mission_id,
            task_signature,
            source_signal_refs,
            privacy_class,
            deadline_ms,
            quality_target_millis,
            evidence_need,
            verifier_need,
            max_hot_bytes,
            max_kv_bytes,
            max_cold_io_bytes,
            max_adapter_bytes,
            max_evidence_bytes,
            max_verifier_bytes,
            max_scratch_bytes,
        })
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SemanticWorkingSetUnit {
    pub semantic_unit_id: String,
    pub unit_kind: WorkingSetUnitKind,
    pub uas_address: UasAddress,
    pub storage_tier: WorkingSetStorageTier,
    pub byte_range: ByteRange,
    pub codec: String,
    pub checksum: String,
    pub compatibility_fence: String,
    pub prefetch_priority: u32,
    pub lease_or_expiry: String,
}

impl SemanticWorkingSetUnit {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        semantic_unit_id: impl Into<String>,
        unit_kind: WorkingSetUnitKind,
        uas_address: UasAddress,
        storage_tier: WorkingSetStorageTier,
        byte_start: u64,
        byte_len: u64,
        codec: impl Into<String>,
        checksum: impl Into<String>,
        compatibility_fence: impl Into<String>,
        prefetch_priority: u32,
        lease_or_expiry: impl Into<String>,
    ) -> Result<Self, SemanticWorkingSetError> {
        let semantic_unit_id = semantic_unit_id.into();
        let codec = codec.into();
        let checksum = checksum.into();
        let compatibility_fence = compatibility_fence.into();
        let lease_or_expiry = lease_or_expiry.into();
        validate_nonempty("semantic_unit_id", &semantic_unit_id)?;
        validate_nonempty("codec", &codec)?;
        validate_nonempty("checksum", &checksum)?;
        validate_nonempty("compatibility_fence", &compatibility_fence)?;
        validate_nonempty("lease_or_expiry", &lease_or_expiry)?;
        if !checksum.starts_with("blake3:") {
            return Err(SemanticWorkingSetError::InvalidChecksum {
                unit_id: semantic_unit_id,
            });
        }
        if !compatibility_fence.starts_with("compat:") {
            return Err(SemanticWorkingSetError::InvalidCompatibilityFence {
                unit_id: semantic_unit_id,
            });
        }
        let byte_range = ByteRange::new(byte_start, byte_len)
            .map_err(|_| SemanticWorkingSetError::InvalidByteRange)?;
        Ok(Self {
            semantic_unit_id,
            unit_kind,
            uas_address,
            storage_tier,
            byte_range,
            codec,
            checksum,
            compatibility_fence,
            prefetch_priority,
            lease_or_expiry,
        })
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ResidencyPageTableEntry {
    pub semantic_unit_id: String,
    pub uas_address: UasAddress,
    pub storage_tier: WorkingSetStorageTier,
    pub byte_range: ByteRange,
    pub codec: String,
    pub compatibility_fence: String,
    pub prefetch_priority: u32,
    pub lease_or_expiry: String,
    pub checksum: String,
}

impl From<&SemanticWorkingSetUnit> for ResidencyPageTableEntry {
    fn from(unit: &SemanticWorkingSetUnit) -> Self {
        Self {
            semantic_unit_id: unit.semantic_unit_id.clone(),
            uas_address: unit.uas_address.clone(),
            storage_tier: unit.storage_tier,
            byte_range: unit.byte_range,
            codec: unit.codec.clone(),
            compatibility_fence: unit.compatibility_fence.clone(),
            prefetch_priority: unit.prefetch_priority,
            lease_or_expiry: unit.lease_or_expiry.clone(),
            checksum: unit.checksum.clone(),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct PrefetchWindow {
    pub route_id: String,
    pub ordered_units: Vec<UasAddress>,
    pub trigger_event: String,
    pub max_parallel_reads: u32,
    pub max_bytes: u64,
    pub cancellation_rule: String,
    pub fallback_on_miss: String,
    pub measurement_ref: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KVByteBudgetCard {
    pub model_id: String,
    pub context_tokens: u32,
    pub kv_codec: String,
    pub kv_bytes_predicted: u64,
    pub kv_bytes_observed: u64,
    pub prompt_cache_hit_tokens: u32,
    pub prompt_cache_miss_tokens: u32,
    pub quality_caveat: String,
}

impl KVByteBudgetCard {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        model_id: impl Into<String>,
        context_tokens: u32,
        kv_codec: impl Into<String>,
        kv_bytes_predicted: u64,
        kv_bytes_observed: u64,
        prompt_cache_hit_tokens: u32,
        prompt_cache_miss_tokens: u32,
        quality_caveat: impl Into<String>,
    ) -> Result<Self, SemanticWorkingSetError> {
        let model_id = model_id.into();
        let kv_codec = kv_codec.into();
        let quality_caveat = quality_caveat.into();
        validate_nonempty("model_id", &model_id)?;
        validate_nonempty("kv_codec", &kv_codec)?;
        validate_nonempty("quality_caveat", &quality_caveat)?;
        if context_tokens == 0 || kv_bytes_predicted == 0 {
            return Err(SemanticWorkingSetError::InvalidKvBudget);
        }
        Ok(Self {
            model_id,
            context_tokens,
            kv_codec,
            kv_bytes_predicted,
            kv_bytes_observed,
            prompt_cache_hit_tokens,
            prompt_cache_miss_tokens,
            quality_caveat,
        })
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct MmapResidencyFence {
    pub file_id: String,
    pub byte_range: ByteRange,
    pub mapped: bool,
    pub touched: bool,
    pub resident_estimate: u64,
    pub major_faults: u64,
    pub minor_faults: u64,
    pub copy_count: u64,
    pub pass_or_fail: bool,
}

impl MmapResidencyFence {
    pub fn evaluate(
        file_id: impl Into<String>,
        byte_start: u64,
        byte_len: u64,
        mapped: bool,
        touched: bool,
        resident_estimate: u64,
        major_faults: u64,
        minor_faults: u64,
        copy_count: u64,
        counted_hot_bytes: u64,
    ) -> Result<Self, SemanticWorkingSetError> {
        let file_id = file_id.into();
        validate_nonempty("file_id", &file_id)?;
        let byte_range = ByteRange::new(byte_start, byte_len)
            .map_err(|_| SemanticWorkingSetError::InvalidByteRange)?;
        let pass_or_fail = if counted_hot_bytes == 0 {
            true
        } else {
            mapped && touched && resident_estimate >= counted_hot_bytes
        };
        Ok(Self {
            file_id,
            byte_range,
            mapped,
            touched,
            resident_estimate,
            major_faults,
            minor_faults,
            copy_count,
            pass_or_fail,
        })
    }
}

#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct WorkingSetTotals {
    pub hot_bytes: u64,
    pub warm_bytes: u64,
    pub cold_bytes: u64,
    pub active_executed_bytes: u64,
    pub kv_bytes: u64,
    pub adapter_bytes: u64,
    pub evidence_bytes: u64,
    pub verifier_bytes: u64,
    pub scratch_bytes: u64,
    pub cold_io_bytes: u64,
    pub cold_miss_count: u32,
    pub cold_stall_ms: u64,
    pub prompt_cache_hit_tokens: u32,
    pub prompt_cache_miss_tokens: u32,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SemanticWorkingSetPlanStatus {
    FitForDryRun,
    RejectedBeforeRuntime,
}

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SemanticWorkingSetViolation {
    EmptySelectedUnits,
    DuplicateSemanticUnitId { unit_id: String },
    DuplicateUasAddress { address: String },
    HotBudgetExceeded { actual: u64, max: u64 },
    KvBudgetExceeded { actual: u64, max: u64 },
    ColdIoBudgetExceeded { actual: u64, max: u64 },
    AdapterBudgetExceeded { actual: u64, max: u64 },
    EvidenceBudgetExceeded { actual: u64, max: u64 },
    VerifierBudgetExceeded { actual: u64, max: u64 },
    ScratchBudgetExceeded { actual: u64, max: u64 },
    UnavailableUnitSelected { unit_id: String },
    MissingRollback,
    HiddenLiveRouteAuthority { route_id: String },
    ProductBuildStatusMismatch,
    MmapMappedButNotResident,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SemanticWorkingSetPlan {
    pub plan_address: UasAddress,
    pub query: TaskWorkingSetQuery,
    pub selected_units: Vec<SemanticWorkingSetUnit>,
    pub rejected_units: Vec<String>,
    pub page_table: Vec<ResidencyPageTableEntry>,
    pub prefetch_window: PrefetchWindow,
    pub kv_budget: KVByteBudgetCard,
    pub mmap_fence: MmapResidencyFence,
    pub totals: WorkingSetTotals,
    pub status: SemanticWorkingSetPlanStatus,
    pub violations: Vec<SemanticWorkingSetViolation>,
    pub fallback_route: String,
    pub rollback_ref: String,
    pub run_event_log_visibility: String,
    pub answer_packet_visibility: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub residency_status: ResidencyTier,
}

impl SemanticWorkingSetPlan {
    #[allow(clippy::too_many_arguments)]
    pub fn compile_dry_run(
        query: TaskWorkingSetQuery,
        selected_units: Vec<SemanticWorkingSetUnit>,
        kv_budget: KVByteBudgetCard,
        mmap_fence: MmapResidencyFence,
        fallback_route: impl Into<String>,
        rollback_ref: impl Into<String>,
        run_event_log_visibility: impl Into<String>,
        answer_packet_visibility: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        residency_status: ResidencyTier,
        created_at_ms: u64,
    ) -> Result<Self, SemanticWorkingSetError> {
        let fallback_route = fallback_route.into();
        let rollback_ref = rollback_ref.into();
        let run_event_log_visibility = run_event_log_visibility.into();
        let answer_packet_visibility = answer_packet_visibility.into();
        validate_nonempty("fallback_route", &fallback_route)?;
        validate_nonempty("rollback_ref", &rollback_ref)?;
        validate_nonempty("run_event_log_visibility", &run_event_log_visibility)?;
        validate_nonempty("answer_packet_visibility", &answer_packet_visibility)?;

        let mut selected_units = selected_units;
        selected_units.sort_by(|a, b| {
            (
                a.semantic_unit_id.as_str(),
                a.uas_address.to_string(),
                a.byte_range.start,
            )
                .cmp(&(
                    b.semantic_unit_id.as_str(),
                    b.uas_address.to_string(),
                    b.byte_range.start,
                ))
        });

        let mut totals = WorkingSetTotals {
            kv_bytes: kv_budget.kv_bytes_predicted,
            prompt_cache_hit_tokens: kv_budget.prompt_cache_hit_tokens,
            prompt_cache_miss_tokens: kv_budget.prompt_cache_miss_tokens,
            ..WorkingSetTotals::default()
        };
        let mut violations = Vec::new();
        let mut rejected_units = Vec::new();
        let mut seen_unit_ids = HashSet::new();
        let mut seen_addresses = HashSet::new();

        if selected_units.is_empty() {
            violations.push(SemanticWorkingSetViolation::EmptySelectedUnits);
        }

        for unit in &selected_units {
            if !seen_unit_ids.insert(unit.semantic_unit_id.clone()) {
                violations.push(SemanticWorkingSetViolation::DuplicateSemanticUnitId {
                    unit_id: unit.semantic_unit_id.clone(),
                });
            }
            if !seen_addresses.insert(unit.uas_address.to_string()) {
                violations.push(SemanticWorkingSetViolation::DuplicateUasAddress {
                    address: unit.uas_address.to_string(),
                });
            }
            if unit.storage_tier == WorkingSetStorageTier::Unavailable {
                rejected_units.push(unit.semantic_unit_id.clone());
                violations.push(SemanticWorkingSetViolation::UnavailableUnitSelected {
                    unit_id: unit.semantic_unit_id.clone(),
                });
            }
            add_unit_bytes(unit, &mut totals)?;
        }

        totals.active_executed_bytes = checked_add(totals.hot_bytes, totals.warm_bytes)?;
        totals.cold_io_bytes = totals.cold_bytes;
        totals.cold_miss_count = selected_units
            .iter()
            .filter(|unit| unit.storage_tier == WorkingSetStorageTier::Cold)
            .count() as u32;
        totals.cold_stall_ms = u64::from(totals.cold_miss_count) * 4;

        if totals.hot_bytes > query.max_hot_bytes {
            violations.push(SemanticWorkingSetViolation::HotBudgetExceeded {
                actual: totals.hot_bytes,
                max: query.max_hot_bytes,
            });
        }
        if totals.kv_bytes > query.max_kv_bytes {
            violations.push(SemanticWorkingSetViolation::KvBudgetExceeded {
                actual: totals.kv_bytes,
                max: query.max_kv_bytes,
            });
        }
        if totals.cold_io_bytes > query.max_cold_io_bytes {
            violations.push(SemanticWorkingSetViolation::ColdIoBudgetExceeded {
                actual: totals.cold_io_bytes,
                max: query.max_cold_io_bytes,
            });
        }
        if totals.adapter_bytes > query.max_adapter_bytes {
            violations.push(SemanticWorkingSetViolation::AdapterBudgetExceeded {
                actual: totals.adapter_bytes,
                max: query.max_adapter_bytes,
            });
        }
        if totals.evidence_bytes > query.max_evidence_bytes {
            violations.push(SemanticWorkingSetViolation::EvidenceBudgetExceeded {
                actual: totals.evidence_bytes,
                max: query.max_evidence_bytes,
            });
        }
        if totals.verifier_bytes > query.max_verifier_bytes {
            violations.push(SemanticWorkingSetViolation::VerifierBudgetExceeded {
                actual: totals.verifier_bytes,
                max: query.max_verifier_bytes,
            });
        }
        if totals.scratch_bytes > query.max_scratch_bytes {
            violations.push(SemanticWorkingSetViolation::ScratchBudgetExceeded {
                actual: totals.scratch_bytes,
                max: query.max_scratch_bytes,
            });
        }
        if !fallback_route_is_shadowed(&fallback_route) {
            violations.push(SemanticWorkingSetViolation::HiddenLiveRouteAuthority {
                route_id: fallback_route.clone(),
            });
        }
        if !rollback_ref.starts_with(ROLLBACK_PREFIX) {
            violations.push(SemanticWorkingSetViolation::MissingRollback);
        }
        if product_build != ProductBuild::Pro
            || pro_status != ProStatus::ResearchCandidate
            || residency_status != ResidencyTier::CapabilityCeiling
        {
            violations.push(SemanticWorkingSetViolation::ProductBuildStatusMismatch);
        }
        if !mmap_fence.pass_or_fail {
            violations.push(SemanticWorkingSetViolation::MmapMappedButNotResident);
        }

        let page_table: Vec<_> = selected_units.iter().map(Into::into).collect();
        let prefetch_window = prefetch_window_for(
            &fallback_route,
            &selected_units,
            totals.cold_io_bytes,
            &run_event_log_visibility,
        );
        let status = if violations.is_empty() {
            SemanticWorkingSetPlanStatus::FitForDryRun
        } else {
            SemanticWorkingSetPlanStatus::RejectedBeforeRuntime
        };
        let plan_address = plan_address(
            &query,
            &selected_units,
            &prefetch_window,
            &kv_budget,
            &mmap_fence,
            &fallback_route,
            &rollback_ref,
            &run_event_log_visibility,
            &answer_packet_visibility,
            &product_build,
            &pro_status,
            residency_status,
            created_at_ms,
        );

        Ok(Self {
            plan_address,
            query,
            selected_units,
            rejected_units,
            page_table,
            prefetch_window,
            kv_budget,
            mmap_fence,
            totals,
            status,
            violations,
            fallback_route,
            rollback_ref,
            run_event_log_visibility,
            answer_packet_visibility,
            product_build,
            pro_status,
            residency_status,
        })
    }

    pub fn can_enter_runtime(&self) -> bool {
        self.status == SemanticWorkingSetPlanStatus::FitForDryRun
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SemanticWorkingSetError {
    MissingMissionId,
    MissingTaskSignature,
    MissingSourceCard,
    MissingSourceId,
    MissingSourceSignalRef,
    MissingSourceLocator,
    MissingSourceDigest,
    MissingLicenseOrUsageNote,
    MissingRouteAffinity,
    MissingSourceRelation,
    MissingSemanticUnitId,
    MissingCodec,
    MissingChecksum,
    MissingCompatibilityFence,
    MissingLeaseOrExpiry,
    MissingModelId,
    MissingKvCodec,
    MissingQualityCaveat,
    MissingFileId,
    MissingFallbackRoute,
    MissingRollbackRef,
    MissingRunEventLogVisibility,
    MissingAnswerPacketVisibility,
    FieldHasSurroundingWhitespace {
        field: &'static str,
    },
    FieldContainsControlCharacter {
        field: &'static str,
    },
    InvalidQueryBudget,
    InvalidByteRange,
    InvalidChecksum {
        unit_id: String,
    },
    InvalidCompatibilityFence {
        unit_id: String,
    },
    InvalidSourceDigest {
        source_id: String,
    },
    InvalidCredibilityRank {
        source_id: String,
    },
    DuplicateSourceId {
        source_id: String,
    },
    UnknownSourceEdgeEndpoint {
        from_source_id: String,
        to_source_id: String,
    },
    InvalidKvBudget,
    ByteTotalOverflow,
}

impl std::fmt::Display for SemanticWorkingSetError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::MissingMissionId => write!(f, "mission_id is required"),
            Self::MissingTaskSignature => write!(f, "task_signature is required"),
            Self::MissingSourceCard => write!(f, "at least one source card is required"),
            Self::MissingSourceId => write!(f, "source_id is required"),
            Self::MissingSourceSignalRef => write!(f, "source_signal_refs are required"),
            Self::MissingSourceLocator => write!(f, "source locator is required"),
            Self::MissingSourceDigest => write!(f, "source digest is required"),
            Self::MissingLicenseOrUsageNote => {
                write!(f, "source license_or_usage_note is required")
            }
            Self::MissingRouteAffinity => write!(f, "route_affinities are required"),
            Self::MissingSourceRelation => write!(f, "source relation is required"),
            Self::MissingSemanticUnitId => write!(f, "semantic_unit_id is required"),
            Self::MissingCodec => write!(f, "codec is required"),
            Self::MissingChecksum => write!(f, "checksum is required"),
            Self::MissingCompatibilityFence => write!(f, "compatibility_fence is required"),
            Self::MissingLeaseOrExpiry => write!(f, "lease_or_expiry is required"),
            Self::MissingModelId => write!(f, "model_id is required"),
            Self::MissingKvCodec => write!(f, "kv_codec is required"),
            Self::MissingQualityCaveat => write!(f, "quality_caveat is required"),
            Self::MissingFileId => write!(f, "file_id is required"),
            Self::MissingFallbackRoute => write!(f, "fallback_route is required"),
            Self::MissingRollbackRef => write!(f, "rollback_ref is required"),
            Self::MissingRunEventLogVisibility => write!(f, "run_event_log_visibility is required"),
            Self::MissingAnswerPacketVisibility => {
                write!(f, "answer_packet_visibility is required")
            }
            Self::FieldHasSurroundingWhitespace { field } => {
                write!(f, "{field} must not contain surrounding whitespace")
            }
            Self::FieldContainsControlCharacter { field } => {
                write!(f, "{field} must not contain control characters")
            }
            Self::InvalidQueryBudget => write!(f, "query budgets must be positive"),
            Self::InvalidByteRange => write!(f, "byte range must be non-empty and non-overflowing"),
            Self::InvalidChecksum { unit_id } => {
                write!(f, "{unit_id} checksum must use blake3:<hex> form")
            }
            Self::InvalidCompatibilityFence { unit_id } => {
                write!(f, "{unit_id} compatibility fence must use compat:<id> form")
            }
            Self::InvalidSourceDigest { source_id } => {
                write!(f, "{source_id} digest must use blake3:<64hex> form")
            }
            Self::InvalidCredibilityRank { source_id } => {
                write!(f, "{source_id} credibility rank must be nonzero")
            }
            Self::DuplicateSourceId { source_id } => {
                write!(f, "duplicate source_id `{source_id}`")
            }
            Self::UnknownSourceEdgeEndpoint {
                from_source_id,
                to_source_id,
            } => write!(
                f,
                "source edge `{from_source_id}` -> `{to_source_id}` references an unknown source"
            ),
            Self::InvalidKvBudget => write!(f, "KV budget must carry non-empty positive values"),
            Self::ByteTotalOverflow => write!(f, "working-set byte total overflowed"),
        }
    }
}

impl std::error::Error for SemanticWorkingSetError {}

fn add_unit_bytes(
    unit: &SemanticWorkingSetUnit,
    totals: &mut WorkingSetTotals,
) -> Result<(), SemanticWorkingSetError> {
    match unit.storage_tier {
        WorkingSetStorageTier::Hot => {
            totals.hot_bytes = checked_add(totals.hot_bytes, unit.byte_range.len)?;
        }
        WorkingSetStorageTier::Warm => {
            totals.warm_bytes = checked_add(totals.warm_bytes, unit.byte_range.len)?;
        }
        WorkingSetStorageTier::Cold => {
            totals.cold_bytes = checked_add(totals.cold_bytes, unit.byte_range.len)?;
        }
        WorkingSetStorageTier::RemoteReference | WorkingSetStorageTier::Unavailable => {}
    }
    match unit.unit_kind {
        WorkingSetUnitKind::KvPage => {
            totals.kv_bytes = checked_add(totals.kv_bytes, unit.byte_range.len)?;
        }
        WorkingSetUnitKind::AdapterSlice => {
            totals.adapter_bytes = checked_add(totals.adapter_bytes, unit.byte_range.len)?;
        }
        WorkingSetUnitKind::EvidencePage => {
            totals.evidence_bytes = checked_add(totals.evidence_bytes, unit.byte_range.len)?;
        }
        WorkingSetUnitKind::VerifierLane => {
            totals.verifier_bytes = checked_add(totals.verifier_bytes, unit.byte_range.len)?;
        }
        WorkingSetUnitKind::ScratchBuffer => {
            totals.scratch_bytes = checked_add(totals.scratch_bytes, unit.byte_range.len)?;
        }
        WorkingSetUnitKind::WeightPage | WorkingSetUnitKind::Kernel => {}
    }
    Ok(())
}

fn checked_add(left: u64, right: u64) -> Result<u64, SemanticWorkingSetError> {
    left.checked_add(right)
        .ok_or(SemanticWorkingSetError::ByteTotalOverflow)
}

fn prefetch_window_for(
    route_id: &str,
    units: &[SemanticWorkingSetUnit],
    max_bytes: u64,
    visibility_ref: &str,
) -> PrefetchWindow {
    let mut cold_units: Vec<_> = units
        .iter()
        .filter(|unit| unit.storage_tier == WorkingSetStorageTier::Cold)
        .collect();
    cold_units.sort_by(|a, b| {
        b.prefetch_priority
            .cmp(&a.prefetch_priority)
            .then_with(|| a.semantic_unit_id.cmp(&b.semantic_unit_id))
    });
    PrefetchWindow {
        route_id: route_id.to_string(),
        ordered_units: cold_units
            .into_iter()
            .map(|unit| unit.uas_address.clone())
            .collect(),
        trigger_event: "before_prefill".to_string(),
        max_parallel_reads: 2,
        max_bytes,
        cancellation_rule: "cancel_on_route_change".to_string(),
        fallback_on_miss: route_id.to_string(),
        measurement_ref: visibility_ref.to_string(),
    }
}

fn query_address(
    mission_id: &str,
    task_signature: &str,
    source_signal_refs: &[String],
    privacy_class: &PrivacyClass,
    deadline_ms: u64,
    quality_target_millis: u32,
    evidence_need: &EvidenceNeed,
    verifier_need: &VerifierNeed,
    max_hot_bytes: u64,
    max_kv_bytes: u64,
    max_cold_io_bytes: u64,
    max_adapter_bytes: u64,
    max_evidence_bytes: u64,
    max_verifier_bytes: u64,
    max_scratch_bytes: u64,
    created_at_ms: u64,
) -> UasAddress {
    let mut preimage = String::new();
    preimage.push_str("task_working_set_query_v1\n");
    push_preimage(&mut preimage, "mission_id", mission_id);
    push_preimage(&mut preimage, "task_signature", task_signature);
    push_string_list_preimage(&mut preimage, "source_signal_refs", source_signal_refs);
    push_preimage(
        &mut preimage,
        "privacy_class",
        &format!("{privacy_class:?}"),
    );
    push_preimage(&mut preimage, "deadline_ms", &deadline_ms.to_string());
    push_preimage(
        &mut preimage,
        "quality_target_millis",
        &quality_target_millis.to_string(),
    );
    push_preimage(
        &mut preimage,
        "evidence_need",
        &format!("{evidence_need:?}"),
    );
    push_preimage(
        &mut preimage,
        "verifier_need",
        &format!("{verifier_need:?}"),
    );
    push_preimage(&mut preimage, "max_hot_bytes", &max_hot_bytes.to_string());
    push_preimage(&mut preimage, "max_kv_bytes", &max_kv_bytes.to_string());
    push_preimage(
        &mut preimage,
        "max_cold_io_bytes",
        &max_cold_io_bytes.to_string(),
    );
    push_preimage(
        &mut preimage,
        "max_adapter_bytes",
        &max_adapter_bytes.to_string(),
    );
    push_preimage(
        &mut preimage,
        "max_evidence_bytes",
        &max_evidence_bytes.to_string(),
    );
    push_preimage(
        &mut preimage,
        "max_verifier_bytes",
        &max_verifier_bytes.to_string(),
    );
    push_preimage(
        &mut preimage,
        "max_scratch_bytes",
        &max_scratch_bytes.to_string(),
    );
    UasAddress::new(
        UasKind::Other(QUERY_UAS_KIND.to_string()),
        preimage.as_bytes(),
        created_at_ms,
    )
}

fn source_signal_graph_address(
    source_cards: &[SourceCard],
    edges: &[SourceSignalEdge],
    route_affinities: &[String],
    rejected_source_ids: &[String],
    created_at_ms: u64,
) -> UasAddress {
    let mut preimage = String::new();
    preimage.push_str("source_signal_graph_v1\n");
    for card in source_cards {
        push_preimage(&mut preimage, "source_id", &card.source_id);
        push_preimage(
            &mut preimage,
            "source_type",
            &format!("{:?}", card.source_type),
        );
        push_preimage(&mut preimage, "locator", &card.locator);
        push_preimage(&mut preimage, "digest", &card.digest);
        push_preimage(
            &mut preimage,
            "credibility_rank",
            &card.credibility_rank.to_string(),
        );
        push_preimage(
            &mut preimage,
            "license_or_usage_note",
            &card.license_or_usage_note,
        );
        push_preimage(
            &mut preimage,
            "privacy_class",
            &format!("{:?}", card.privacy_class),
        );
        push_preimage(
            &mut preimage,
            "no_poison_status",
            &format!("{:?}", card.no_poison_status),
        );
        for route in &card.route_affinities {
            push_preimage(&mut preimage, "route_affinity", route);
        }
    }
    for edge in edges {
        push_preimage(&mut preimage, "edge_from", &edge.from_source_id);
        push_preimage(&mut preimage, "edge_to", &edge.to_source_id);
        push_preimage(&mut preimage, "edge_relation", &edge.relation);
    }
    push_string_list_preimage(&mut preimage, "route_affinities", route_affinities);
    push_string_list_preimage(&mut preimage, "rejected_source_ids", rejected_source_ids);
    UasAddress::new(
        UasKind::Other("source_signal_graph".to_string()),
        preimage.as_bytes(),
        created_at_ms,
    )
}

#[allow(clippy::too_many_arguments)]
fn plan_address(
    query: &TaskWorkingSetQuery,
    selected_units: &[SemanticWorkingSetUnit],
    prefetch_window: &PrefetchWindow,
    kv_budget: &KVByteBudgetCard,
    mmap_fence: &MmapResidencyFence,
    fallback_route: &str,
    rollback_ref: &str,
    run_event_log_visibility: &str,
    answer_packet_visibility: &str,
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    residency_status: ResidencyTier,
    created_at_ms: u64,
) -> UasAddress {
    let mut preimage = String::new();
    preimage.push_str("semantic_working_set_plan_v1\n");
    push_preimage(
        &mut preimage,
        "query_address",
        &query.query_address.to_string(),
    );
    for unit in selected_units {
        push_preimage(&mut preimage, "semantic_unit_id", &unit.semantic_unit_id);
        push_preimage(&mut preimage, "unit_kind", &format!("{:?}", unit.unit_kind));
        push_preimage(&mut preimage, "uas_address", &unit.uas_address.to_string());
        push_preimage(
            &mut preimage,
            "storage_tier",
            &format!("{:?}", unit.storage_tier),
        );
        push_preimage(
            &mut preimage,
            "byte_range",
            &format!("{}:{}", unit.byte_range.start, unit.byte_range.len),
        );
        push_preimage(&mut preimage, "codec", &unit.codec);
        push_preimage(&mut preimage, "checksum", &unit.checksum);
        push_preimage(
            &mut preimage,
            "compatibility_fence",
            &unit.compatibility_fence,
        );
        push_preimage(
            &mut preimage,
            "prefetch_priority",
            &unit.prefetch_priority.to_string(),
        );
        push_preimage(&mut preimage, "lease_or_expiry", &unit.lease_or_expiry);
    }
    push_preimage(&mut preimage, "prefetch_route", &prefetch_window.route_id);
    for ordered in &prefetch_window.ordered_units {
        push_preimage(&mut preimage, "prefetch_unit", &ordered.to_string());
    }
    push_preimage(&mut preimage, "kv_model_id", &kv_budget.model_id);
    push_preimage(
        &mut preimage,
        "kv_bytes_predicted",
        &kv_budget.kv_bytes_predicted.to_string(),
    );
    push_preimage(&mut preimage, "mmap_file_id", &mmap_fence.file_id);
    push_preimage(&mut preimage, "fallback_route", fallback_route);
    push_preimage(&mut preimage, "rollback_ref", rollback_ref);
    push_preimage(
        &mut preimage,
        "run_event_log_visibility",
        run_event_log_visibility,
    );
    push_preimage(
        &mut preimage,
        "answer_packet_visibility",
        answer_packet_visibility,
    );
    push_preimage(
        &mut preimage,
        "product_build",
        &format!("{product_build:?}"),
    );
    push_preimage(&mut preimage, "pro_status", &format!("{pro_status:?}"));
    push_preimage(
        &mut preimage,
        "residency_status",
        residency_status.wire_tag(),
    );
    UasAddress::new(
        UasKind::Other(PLAN_UAS_KIND.to_string()),
        preimage.as_bytes(),
        created_at_ms,
    )
}

fn validate_nonempty(field: &'static str, value: &str) -> Result<(), SemanticWorkingSetError> {
    if value.trim().is_empty() {
        return Err(missing_field_error(field));
    }
    if value.trim() != value {
        return Err(SemanticWorkingSetError::FieldHasSurroundingWhitespace { field });
    }
    if value.chars().any(char::is_control) {
        return Err(SemanticWorkingSetError::FieldContainsControlCharacter { field });
    }
    Ok(())
}

fn is_blake3_digest(value: &str) -> bool {
    let Some(hex) = value.strip_prefix("blake3:") else {
        return false;
    };
    hex.len() == 64
        && hex
            .bytes()
            .all(|byte| matches!(byte, b'0'..=b'9' | b'a'..=b'f'))
}

fn missing_field_error(field: &'static str) -> SemanticWorkingSetError {
    match field {
        "mission_id" => SemanticWorkingSetError::MissingMissionId,
        "task_signature" => SemanticWorkingSetError::MissingTaskSignature,
        "source_id" => SemanticWorkingSetError::MissingSourceId,
        "source_signal_refs" => SemanticWorkingSetError::MissingSourceSignalRef,
        "source_locator" => SemanticWorkingSetError::MissingSourceLocator,
        "source_digest" => SemanticWorkingSetError::MissingSourceDigest,
        "license_or_usage_note" => SemanticWorkingSetError::MissingLicenseOrUsageNote,
        "route_affinities" => SemanticWorkingSetError::MissingRouteAffinity,
        "source_relation" => SemanticWorkingSetError::MissingSourceRelation,
        "semantic_unit_id" => SemanticWorkingSetError::MissingSemanticUnitId,
        "codec" => SemanticWorkingSetError::MissingCodec,
        "checksum" => SemanticWorkingSetError::MissingChecksum,
        "compatibility_fence" => SemanticWorkingSetError::MissingCompatibilityFence,
        "lease_or_expiry" => SemanticWorkingSetError::MissingLeaseOrExpiry,
        "model_id" => SemanticWorkingSetError::MissingModelId,
        "kv_codec" => SemanticWorkingSetError::MissingKvCodec,
        "quality_caveat" => SemanticWorkingSetError::MissingQualityCaveat,
        "file_id" => SemanticWorkingSetError::MissingFileId,
        "fallback_route" => SemanticWorkingSetError::MissingFallbackRoute,
        "rollback_ref" => SemanticWorkingSetError::MissingRollbackRef,
        "run_event_log_visibility" => SemanticWorkingSetError::MissingRunEventLogVisibility,
        "answer_packet_visibility" => SemanticWorkingSetError::MissingAnswerPacketVisibility,
        _ => SemanticWorkingSetError::InvalidQueryBudget,
    }
}

fn canonicalize_strings(
    field: &'static str,
    mut values: Vec<String>,
    missing: SemanticWorkingSetError,
) -> Result<Vec<String>, SemanticWorkingSetError> {
    if values.is_empty() {
        return Err(missing);
    }
    for value in &values {
        validate_nonempty(field, value)?;
    }
    values.sort();
    values.dedup();
    Ok(values)
}

fn fallback_route_is_shadowed(route_id: &str) -> bool {
    FALLBACK_ROUTE_PREFIXES
        .iter()
        .any(|prefix| route_id.starts_with(prefix))
}

fn push_preimage(preimage: &mut String, key: &str, value: &str) {
    preimage.push_str(key);
    preimage.push('=');
    preimage.push_str(&value.len().to_string());
    preimage.push(':');
    preimage.push_str(value);
    preimage.push('\n');
}

fn push_string_list_preimage(preimage: &mut String, key: &str, values: &[String]) {
    push_preimage(preimage, key, &values.len().to_string());
    for value in values {
        push_preimage(preimage, key, value);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_000_000_000;

    #[test]
    fn source_signal_graph_intake_is_order_stable_and_rejects_poison() {
        let cards = fixture_source_cards();
        let edges = vec![
            SourceSignalEdge::new(
                "source:bookmark:karpathy-autoresearch",
                "source:repo:agent-loop",
                "supports",
            )
            .unwrap(),
            SourceSignalEdge::new(
                "source:repo:agent-loop",
                "source:paper:working-set",
                "implements_motif",
            )
            .unwrap(),
            SourceSignalEdge::new(
                "source:paper:working-set",
                "source:doc:semantic-working-set",
                "grounds",
            )
            .unwrap(),
            SourceSignalEdge::new(
                "source:x:kv-cache-thread",
                "source:doc:semantic-working-set",
                "suggests_route_prior",
            )
            .unwrap(),
            SourceSignalEdge::new(
                "source:poison:prompt-injection",
                "source:doc:semantic-working-set",
                "must_not_promote",
            )
            .unwrap(),
        ];
        let graph = SourceSignalGraph::intake(cards.clone(), edges.clone(), CREATED_AT_MS).unwrap();
        let reversed = SourceSignalGraph::intake(
            cards.into_iter().rev().collect(),
            edges.into_iter().rev().collect(),
            CREATED_AT_MS,
        )
        .unwrap();

        assert_eq!(graph.graph_address, reversed.graph_address);
        assert_eq!(graph.source_cards.len(), 5);
        assert_eq!(
            graph
                .source_cards
                .iter()
                .map(|card| card.source_id.as_str())
                .collect::<Vec<_>>(),
            vec![
                "source:bookmark:karpathy-autoresearch",
                "source:doc:semantic-working-set",
                "source:paper:working-set",
                "source:repo:agent-loop",
                "source:x:kv-cache-thread",
            ]
        );
        assert_eq!(
            graph.rejected_source_ids,
            vec!["source:poison:prompt-injection"]
        );
        assert_eq!(
            graph.route_affinities,
            vec![
                "autoresearch",
                "evidence_routing",
                "semantic_working_set",
                "verification",
            ]
        );
        assert_eq!(graph.edges.len(), 4);
        assert!(!graph.edges.iter().any(|edge| {
            edge.from_source_id == "source:poison:prompt-injection"
                || edge.to_source_id == "source:poison:prompt-injection"
        }));

        let source_types = graph
            .source_cards
            .iter()
            .map(|card| card.source_type)
            .collect::<HashSet<_>>();
        assert!(source_types.contains(&SourceSignalType::Bookmark));
        assert!(source_types.contains(&SourceSignalType::Repo));
        assert!(source_types.contains(&SourceSignalType::Paper));
        assert!(source_types.contains(&SourceSignalType::Doc));
        assert!(source_types.contains(&SourceSignalType::XBookmark));
    }

    #[test]
    fn source_signal_graph_rejects_duplicate_and_unknown_edge_sources() {
        let duplicate = vec![
            source_card(
                "source:doc:semantic-working-set",
                SourceSignalType::Doc,
                "docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md",
                "semantic-working-set-doc",
                1,
                PrivacyClass::VaultPrivate,
                SourceNoPoisonStatus::Clear,
                &["semantic_working_set"],
            ),
            source_card(
                "source:doc:semantic-working-set",
                SourceSignalType::Doc,
                "docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md",
                "semantic-working-set-doc-duplicate",
                2,
                PrivacyClass::VaultPrivate,
                SourceNoPoisonStatus::Clear,
                &["semantic_working_set"],
            ),
        ];
        let duplicate_error =
            SourceSignalGraph::intake(duplicate, Vec::new(), CREATED_AT_MS).unwrap_err();
        assert!(matches!(
            duplicate_error,
            SemanticWorkingSetError::DuplicateSourceId { .. }
        ));

        let unknown_edge_error = SourceSignalGraph::intake(
            fixture_source_cards(),
            vec![SourceSignalEdge::new(
                "source:doc:semantic-working-set",
                "source:missing",
                "references",
            )
            .unwrap()],
            CREATED_AT_MS,
        )
        .unwrap_err();
        assert!(matches!(
            unknown_edge_error,
            SemanticWorkingSetError::UnknownSourceEdgeEndpoint { .. }
        ));
    }

    #[test]
    fn source_cards_reject_bad_digest_rank_and_empty_affinity() {
        let bad_digest = SourceCard::new(
            "source:bad-digest",
            SourceSignalType::Doc,
            "docs/bad.md",
            "blake3:ABC",
            1,
            "fixture only",
            PrivacyClass::VaultPrivate,
            SourceNoPoisonStatus::Clear,
            vec!["semantic_working_set".to_string()],
        )
        .unwrap_err();
        assert!(matches!(
            bad_digest,
            SemanticWorkingSetError::InvalidSourceDigest { .. }
        ));

        let bad_rank = SourceCard::new(
            "source:bad-rank",
            SourceSignalType::Doc,
            "docs/bad.md",
            digest("bad-rank"),
            0,
            "fixture only",
            PrivacyClass::VaultPrivate,
            SourceNoPoisonStatus::Clear,
            vec!["semantic_working_set".to_string()],
        )
        .unwrap_err();
        assert!(matches!(
            bad_rank,
            SemanticWorkingSetError::InvalidCredibilityRank { .. }
        ));

        let empty_affinity = SourceCard::new(
            "source:empty-affinity",
            SourceSignalType::Doc,
            "docs/bad.md",
            digest("empty-affinity"),
            1,
            "fixture only",
            PrivacyClass::VaultPrivate,
            SourceNoPoisonStatus::Clear,
            Vec::new(),
        )
        .unwrap_err();
        assert!(matches!(
            empty_affinity,
            SemanticWorkingSetError::MissingRouteAffinity
        ));
    }

    #[test]
    fn task_working_set_query_is_order_stable_and_budget_gated() {
        let query = task_query_with_sources(
            vec![
                "source:doc:semantic-working-set".to_string(),
                "source:bookmark:karpathy-autoresearch".to_string(),
                "source:doc:semantic-working-set".to_string(),
            ],
            PrivacyClass::VaultPrivate,
            2 * 1024 * 1024,
            4 * 1024 * 1024,
        );
        let canonical = task_query_with_sources(
            vec![
                "source:bookmark:karpathy-autoresearch".to_string(),
                "source:doc:semantic-working-set".to_string(),
            ],
            PrivacyClass::VaultPrivate,
            2 * 1024 * 1024,
            4 * 1024 * 1024,
        );
        let public = task_query_with_sources(
            vec![
                "source:bookmark:karpathy-autoresearch".to_string(),
                "source:doc:semantic-working-set".to_string(),
            ],
            PrivacyClass::PublicResearch,
            2 * 1024 * 1024,
            4 * 1024 * 1024,
        );

        assert_eq!(query.query_address, canonical.query_address);
        assert_eq!(
            query.source_signal_refs,
            vec![
                "source:bookmark:karpathy-autoresearch",
                "source:doc:semantic-working-set",
            ]
        );
        assert_ne!(query.query_address, public.query_address);

        let empty_sources = TaskWorkingSetQuery::new(
            "mission-local-research",
            "retrieve-verify-answer",
            Vec::new(),
            PrivacyClass::VaultPrivate,
            1200,
            850,
            EvidenceNeed::ClosedCitation,
            VerifierNeed::Schema,
            2 * 1024 * 1024,
            4 * 1024 * 1024,
            4 * 1024 * 1024,
            1024 * 1024,
            1024 * 1024,
            1024 * 1024,
            1024 * 1024,
            CREATED_AT_MS,
        )
        .unwrap_err();
        assert!(matches!(
            empty_sources,
            SemanticWorkingSetError::MissingSourceSignalRef
        ));

        let zero_budget = TaskWorkingSetQuery::new(
            "mission-local-research",
            "retrieve-verify-answer",
            vec!["source:doc:semantic-working-set".to_string()],
            PrivacyClass::VaultPrivate,
            1200,
            850,
            EvidenceNeed::ClosedCitation,
            VerifierNeed::Schema,
            0,
            4 * 1024 * 1024,
            4 * 1024 * 1024,
            1024 * 1024,
            1024 * 1024,
            1024 * 1024,
            1024 * 1024,
            CREATED_AT_MS,
        )
        .unwrap_err();
        assert!(matches!(
            zero_budget,
            SemanticWorkingSetError::InvalidQueryBudget
        ));
    }

    #[test]
    fn semantic_working_set_plan_is_order_stable_and_research_only() {
        let query = fixture_query(2 * 1024 * 1024, 4 * 1024 * 1024);
        let mut units = vec![
            unit(
                "weight",
                WorkingSetUnitKind::WeightPage,
                UasKind::ModelComponent,
                WorkingSetStorageTier::Cold,
                0,
                1024 * 1024,
                90,
            ),
            unit(
                "evidence",
                WorkingSetUnitKind::EvidencePage,
                UasKind::VaultNote,
                WorkingSetStorageTier::Hot,
                0,
                64 * 1024,
                10,
            ),
        ];
        let plan = compile(query.clone(), units.clone());
        units.reverse();
        let reversed = compile(query, units);

        assert_eq!(plan.status, SemanticWorkingSetPlanStatus::FitForDryRun);
        assert_eq!(plan.plan_address, reversed.plan_address);
        assert_eq!(plan.product_build, ProductBuild::Pro);
        assert_eq!(plan.pro_status, ProStatus::ResearchCandidate);
        assert_eq!(plan.residency_status, ResidencyTier::CapabilityCeiling);
        assert!(plan.can_enter_runtime());
    }

    #[test]
    fn plan_rejects_hot_and_kv_budget_before_runtime() {
        let query = fixture_query(32 * 1024, 64 * 1024);
        let units = vec![unit(
            "kv-hot",
            WorkingSetUnitKind::KvPage,
            UasKind::KvPage,
            WorkingSetStorageTier::Hot,
            0,
            128 * 1024,
            10,
        )];
        let plan = compile(query, units);

        assert_eq!(
            plan.status,
            SemanticWorkingSetPlanStatus::RejectedBeforeRuntime
        );
        assert!(plan.violations.iter().any(|violation| matches!(
            violation,
            SemanticWorkingSetViolation::HotBudgetExceeded { .. }
        )));
        assert!(plan.violations.iter().any(|violation| matches!(
            violation,
            SemanticWorkingSetViolation::KvBudgetExceeded { .. }
        )));
        assert!(!plan.can_enter_runtime());
    }

    #[test]
    fn page_table_units_require_checksum_and_compatibility_fence() {
        let bad_checksum = SemanticWorkingSetUnit::new(
            "evidence",
            WorkingSetUnitKind::EvidencePage,
            address(UasKind::VaultNote, b"evidence"),
            WorkingSetStorageTier::Hot,
            0,
            1024,
            "utf8",
            "sha256:not-canonical",
            "compat:vault-note-v1",
            1,
            "lease:dry-run",
        )
        .unwrap_err();
        assert!(matches!(
            bad_checksum,
            SemanticWorkingSetError::InvalidChecksum { .. }
        ));

        let bad_fence = SemanticWorkingSetUnit::new(
            "evidence",
            WorkingSetUnitKind::EvidencePage,
            address(UasKind::VaultNote, b"evidence"),
            WorkingSetStorageTier::Hot,
            0,
            1024,
            "utf8",
            "blake3:abc",
            "missing-prefix",
            1,
            "lease:dry-run",
        )
        .unwrap_err();
        assert!(matches!(
            bad_fence,
            SemanticWorkingSetError::InvalidCompatibilityFence { .. }
        ));
    }

    #[test]
    fn mmap_fence_never_counts_mapped_untouched_range_as_hot() {
        let fence = MmapResidencyFence::evaluate(
            "model.gguf",
            0,
            1024 * 1024,
            true,
            false,
            0,
            0,
            0,
            0,
            64 * 1024,
        )
        .unwrap();
        assert!(!fence.pass_or_fail);

        let plan = SemanticWorkingSetPlan::compile_dry_run(
            fixture_query(2 * 1024 * 1024, 4 * 1024 * 1024),
            vec![unit(
                "weight",
                WorkingSetUnitKind::WeightPage,
                UasKind::ModelComponent,
                WorkingSetStorageTier::Hot,
                0,
                64 * 1024,
                1,
            )],
            fixture_kv_budget(),
            fence,
            "runtime_router:fallback_static_route",
            "rollback:semantic-working-set",
            "run_event_log:semantic-working-set",
            "answer_packet:semantic-working-set",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            ResidencyTier::CapabilityCeiling,
            CREATED_AT_MS,
        )
        .unwrap();

        assert!(plan.violations.iter().any(|violation| matches!(
            violation,
            SemanticWorkingSetViolation::MmapMappedButNotResident
        )));
    }

    #[test]
    fn kv_budget_is_reported_separately_from_weight_bytes() {
        let plan = compile(
            fixture_query(2 * 1024 * 1024, 4 * 1024 * 1024),
            vec![
                unit(
                    "weight",
                    WorkingSetUnitKind::WeightPage,
                    UasKind::ModelComponent,
                    WorkingSetStorageTier::Cold,
                    0,
                    1024 * 1024,
                    90,
                ),
                unit(
                    "kv",
                    WorkingSetUnitKind::KvPage,
                    UasKind::KvPage,
                    WorkingSetStorageTier::Warm,
                    0,
                    512 * 1024,
                    60,
                ),
            ],
        );

        assert_eq!(plan.totals.cold_bytes, 1024 * 1024);
        assert_eq!(plan.totals.kv_bytes, 768 * 1024);
        assert_eq!(plan.kv_budget.prompt_cache_hit_tokens, 128);
        assert_eq!(plan.kv_budget.prompt_cache_miss_tokens, 32);
        assert_eq!(plan.prefetch_window.ordered_units.len(), 1);
    }

    fn compile(
        query: TaskWorkingSetQuery,
        units: Vec<SemanticWorkingSetUnit>,
    ) -> SemanticWorkingSetPlan {
        SemanticWorkingSetPlan::compile_dry_run(
            query,
            units,
            fixture_kv_budget(),
            MmapResidencyFence::evaluate(
                "model.gguf",
                0,
                1024 * 1024,
                true,
                true,
                1024 * 1024,
                0,
                1,
                0,
                0,
            )
            .unwrap(),
            "runtime_router:fallback_static_route",
            "rollback:semantic-working-set",
            "run_event_log:semantic-working-set",
            "answer_packet:semantic-working-set",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            ResidencyTier::CapabilityCeiling,
            CREATED_AT_MS,
        )
        .unwrap()
    }

    fn fixture_query(max_hot_bytes: u64, max_kv_bytes: u64) -> TaskWorkingSetQuery {
        task_query_with_sources(
            vec![
                "source:docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md".to_string(),
                "source:docs/falsifiers/F-SEMANTIC-WORKING-SET-COMPILER-BUNDLE_2026_06_01.md"
                    .to_string(),
            ],
            PrivacyClass::VaultPrivate,
            max_hot_bytes,
            max_kv_bytes,
        )
    }

    fn task_query_with_sources(
        source_signal_refs: Vec<String>,
        privacy_class: PrivacyClass,
        max_hot_bytes: u64,
        max_kv_bytes: u64,
    ) -> TaskWorkingSetQuery {
        TaskWorkingSetQuery::new(
            "mission-local-research",
            "retrieve-verify-answer",
            source_signal_refs,
            privacy_class,
            1200,
            850,
            EvidenceNeed::ClosedCitation,
            VerifierNeed::Schema,
            max_hot_bytes,
            max_kv_bytes,
            4 * 1024 * 1024,
            1024 * 1024,
            1024 * 1024,
            1024 * 1024,
            1024 * 1024,
            CREATED_AT_MS,
        )
        .unwrap()
    }

    fn fixture_kv_budget() -> KVByteBudgetCard {
        KVByteBudgetCard::new(
            "local/qwen-working-set-fixture",
            4096,
            "kivi-q4-dry-run",
            256 * 1024,
            256 * 1024,
            128,
            32,
            "dry-run fixture; no KV page loaded",
        )
        .unwrap()
    }

    fn unit(
        id: &str,
        kind: WorkingSetUnitKind,
        uas_kind: UasKind,
        tier: WorkingSetStorageTier,
        byte_start: u64,
        byte_len: u64,
        priority: u32,
    ) -> SemanticWorkingSetUnit {
        SemanticWorkingSetUnit::new(
            id,
            kind,
            address(uas_kind, id.as_bytes()),
            tier,
            byte_start,
            byte_len,
            "fixture-codec",
            format!("blake3:{}", blake3::hash(id.as_bytes()).to_hex()),
            "compat:semantic-working-set-v1",
            priority,
            "lease:dry-run",
        )
        .unwrap()
    }

    fn address(kind: UasKind, bytes: &[u8]) -> UasAddress {
        UasAddress::new(kind, bytes, CREATED_AT_MS)
    }

    fn fixture_source_cards() -> Vec<SourceCard> {
        vec![
            source_card(
                "source:bookmark:karpathy-autoresearch",
                SourceSignalType::Bookmark,
                "arc://bookmark/karpathy-autoresearch",
                "karpathy-autoresearch-bookmark",
                1,
                PrivacyClass::LocalPrivate,
                SourceNoPoisonStatus::Clear,
                &["autoresearch", "semantic_working_set"],
            ),
            source_card(
                "source:repo:agent-loop",
                SourceSignalType::Repo,
                "https://github.com/fixture/agent-loop",
                "agent-loop-repo",
                2,
                PrivacyClass::PublicResearch,
                SourceNoPoisonStatus::Clear,
                &["autoresearch", "verification"],
            ),
            source_card(
                "source:paper:working-set",
                SourceSignalType::Paper,
                "paper://denning-working-set-model",
                "denning-working-set-paper",
                1,
                PrivacyClass::PublicResearch,
                SourceNoPoisonStatus::Clear,
                &["semantic_working_set"],
            ),
            source_card(
                "source:doc:semantic-working-set",
                SourceSignalType::Doc,
                "docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md",
                "semantic-working-set-doc",
                1,
                PrivacyClass::VaultPrivate,
                SourceNoPoisonStatus::Clear,
                &["semantic_working_set", "evidence_routing"],
            ),
            source_card(
                "source:x:kv-cache-thread",
                SourceSignalType::XBookmark,
                "x-bookmark://fixture/kv-cache-thread",
                "kv-cache-x-thread",
                3,
                PrivacyClass::LocalPrivate,
                SourceNoPoisonStatus::Clear,
                &["semantic_working_set", "verification"],
            ),
            source_card(
                "source:poison:prompt-injection",
                SourceSignalType::Bookmark,
                "arc://bookmark/prompt-injection-fixture",
                "prompt-injection-fixture",
                5,
                PrivacyClass::LocalPrivate,
                SourceNoPoisonStatus::Blocked,
                &["semantic_working_set"],
            ),
        ]
    }

    fn source_card(
        source_id: &str,
        source_type: SourceSignalType,
        locator: &str,
        digest_seed: &str,
        credibility_rank: u8,
        privacy_class: PrivacyClass,
        no_poison_status: SourceNoPoisonStatus,
        route_affinities: &[&str],
    ) -> SourceCard {
        SourceCard::new(
            source_id,
            source_type,
            locator,
            digest(digest_seed),
            credibility_rank,
            "fixture-only source; motif mining permitted, no raw merge",
            privacy_class,
            no_poison_status,
            route_affinities
                .iter()
                .map(|route| (*route).to_string())
                .collect(),
        )
        .unwrap()
    }

    fn digest(seed: &str) -> String {
        format!("blake3:{}", blake3::hash(seed.as_bytes()).to_hex())
    }
}
