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
const SOURCE_TO_RESIDENCY_PATCH_UAS_KIND: &str = "source_to_residency_patch";
const COLD_FAULT_TRACE_UAS_KIND: &str = "cold_fault_trace";
const LAYOUT_PATCH_UAS_KIND: &str = "layout_patch";
const WORKING_SET_ORACLE_UAS_KIND: &str = "working_set_oracle_card";
const ROLLBACK_PREFIX: &str = "rollback:";
const HELD_OUT_PREFIX: &str = "held_out:";
const ABSTAIN_PREFIX: &str = "abstain:";
const FALSIFIER_PREFIX: &str = "F-";
const MAX_SOURCE_PROMOTION_CREDIBILITY_RANK: u8 = 3;
const MAX_LAYOUT_PATCH_STORAGE_WEAR_COST: u64 = 128 * 1024;
const MAX_SCORE_BPS: u16 = 10_000;
const MIN_ORACLE_CONFIDENCE_BPS: u16 = 6_000;
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
pub enum SourceToResidencyPatchKind {
    Layout,
    Cache,
    Route,
    Prompt,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SourceToResidencyPromotionStatus {
    ShadowCandidate,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceToResidencyPatch {
    pub patch_address: UasAddress,
    pub source_graph_address: UasAddress,
    pub source_id: String,
    pub source_digest: String,
    pub patch_kind: SourceToResidencyPatchKind,
    pub proposed_unit_or_policy: String,
    pub affected_organs: Vec<String>,
    pub import_gate: String,
    pub falsifier_required: String,
    pub rollback_ref: String,
    pub promotion_status: SourceToResidencyPromotionStatus,
}

impl SourceToResidencyPatch {
    #[allow(clippy::too_many_arguments)]
    pub fn from_source_signal(
        graph: &SourceSignalGraph,
        source_id: impl Into<String>,
        expected_digest: impl Into<String>,
        patch_kind: SourceToResidencyPatchKind,
        proposed_unit_or_policy: impl Into<String>,
        affected_organs: Vec<String>,
        import_gate: impl Into<String>,
        falsifier_required: impl Into<String>,
        rollback_ref: impl Into<String>,
        created_at_ms: u64,
    ) -> Result<Self, SemanticWorkingSetError> {
        let source_id = source_id.into();
        let expected_digest = expected_digest.into();
        let proposed_unit_or_policy = proposed_unit_or_policy.into();
        let import_gate = import_gate.into();
        let falsifier_required = falsifier_required.into();
        let rollback_ref = rollback_ref.into();
        validate_nonempty("source_id", &source_id)?;
        validate_nonempty("source_digest", &expected_digest)?;
        validate_nonempty("proposed_unit_or_policy", &proposed_unit_or_policy)?;
        validate_nonempty("import_gate", &import_gate)?;
        validate_nonempty("falsifier_required", &falsifier_required)?;
        validate_nonempty("rollback_ref", &rollback_ref)?;
        if !falsifier_required.starts_with(FALSIFIER_PREFIX) {
            return Err(SemanticWorkingSetError::SourcePromotionBlocked {
                source_id,
                reason: "missing_falsifier_gate".to_string(),
            });
        }
        if !rollback_ref.starts_with(ROLLBACK_PREFIX) {
            return Err(SemanticWorkingSetError::SourcePromotionBlocked {
                source_id,
                reason: "missing_rollback".to_string(),
            });
        }
        let affected_organs = canonicalize_strings(
            "affected_organs",
            affected_organs,
            SemanticWorkingSetError::MissingAffectedOrgan,
        )?;

        if graph
            .rejected_source_ids
            .iter()
            .any(|rejected| rejected == &source_id)
        {
            return Err(SemanticWorkingSetError::SourcePromotionBlocked {
                source_id,
                reason: "blocked_no_poison_status".to_string(),
            });
        }
        let card = graph
            .source_cards
            .iter()
            .find(|card| card.source_id == source_id)
            .ok_or_else(|| SemanticWorkingSetError::SourcePromotionBlocked {
                source_id: source_id.clone(),
                reason: "unknown_source".to_string(),
            })?;
        if card.digest != expected_digest {
            return Err(SemanticWorkingSetError::SourcePromotionBlocked {
                source_id,
                reason: "stale_or_corrupted_digest".to_string(),
            });
        }
        if card.privacy_class != PrivacyClass::PublicResearch {
            return Err(SemanticWorkingSetError::SourcePromotionBlocked {
                source_id,
                reason: "private_source_not_promotable".to_string(),
            });
        }
        if card.credibility_rank > MAX_SOURCE_PROMOTION_CREDIBILITY_RANK {
            return Err(SemanticWorkingSetError::SourcePromotionBlocked {
                source_id,
                reason: "low_credibility_source".to_string(),
            });
        }
        if source_license_blocks_promotion(&card.license_or_usage_note) {
            return Err(SemanticWorkingSetError::SourcePromotionBlocked {
                source_id,
                reason: "license_or_usage_blocks_promotion".to_string(),
            });
        }
        if card.no_poison_status != SourceNoPoisonStatus::Clear {
            return Err(SemanticWorkingSetError::SourcePromotionBlocked {
                source_id,
                reason: "blocked_no_poison_status".to_string(),
            });
        }

        let patch_address = source_to_residency_patch_address(
            &graph.graph_address,
            card,
            patch_kind,
            &proposed_unit_or_policy,
            &affected_organs,
            &import_gate,
            &falsifier_required,
            &rollback_ref,
            created_at_ms,
        );
        Ok(Self {
            patch_address,
            source_graph_address: graph.graph_address.clone(),
            source_id: card.source_id.clone(),
            source_digest: card.digest.clone(),
            patch_kind,
            proposed_unit_or_policy,
            affected_organs,
            import_gate,
            falsifier_required,
            rollback_ref,
            promotion_status: SourceToResidencyPromotionStatus::ShadowCandidate,
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
pub struct ColdFaultTrace {
    pub trace_address: UasAddress,
    pub mission_id: String,
    pub missing_unit: UasAddress,
    pub expected_unit: UasAddress,
    pub stall_ms: u64,
    pub cold_io_bytes: u64,
    pub fallback_used: String,
    pub answer_effect: String,
    pub source_or_cache_cause: String,
    pub next_layout_patch: String,
}

impl ColdFaultTrace {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        mission_id: impl Into<String>,
        missing_unit: UasAddress,
        expected_unit: UasAddress,
        stall_ms: u64,
        cold_io_bytes: u64,
        fallback_used: impl Into<String>,
        answer_effect: impl Into<String>,
        source_or_cache_cause: impl Into<String>,
        next_layout_patch: impl Into<String>,
        created_at_ms: u64,
    ) -> Result<Self, SemanticWorkingSetError> {
        let mission_id = mission_id.into();
        let fallback_used = fallback_used.into();
        let answer_effect = answer_effect.into();
        let source_or_cache_cause = source_or_cache_cause.into();
        let next_layout_patch = next_layout_patch.into();
        validate_nonempty("mission_id", &mission_id)?;
        validate_nonempty("fallback_route", &fallback_used)?;
        validate_nonempty("answer_effect", &answer_effect)?;
        validate_nonempty("source_or_cache_cause", &source_or_cache_cause)?;
        validate_nonempty("next_layout_patch", &next_layout_patch)?;
        if stall_ms == 0 || cold_io_bytes == 0 {
            return Err(SemanticWorkingSetError::ColdFaultLearningRejected {
                reason: "zero_stall_or_cold_io".to_string(),
            });
        }
        let trace_address = cold_fault_trace_address(
            &mission_id,
            &missing_unit,
            &expected_unit,
            stall_ms,
            cold_io_bytes,
            &fallback_used,
            &answer_effect,
            &source_or_cache_cause,
            &next_layout_patch,
            created_at_ms,
        );
        Ok(Self {
            trace_address,
            mission_id,
            missing_unit,
            expected_unit,
            stall_ms,
            cold_io_bytes,
            fallback_used,
            answer_effect,
            source_or_cache_cause,
            next_layout_patch,
        })
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LayoutPatchPromotionStatus {
    ShadowCandidate,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LayoutPatch {
    pub patch_address: UasAddress,
    pub patch_id: String,
    pub target_layout: String,
    pub baseline_layout: String,
    pub changed_tiles: Vec<String>,
    pub expected_cold_miss_delta: i64,
    pub observed_cold_miss_delta: i64,
    pub storage_wear_cost: u64,
    pub rollback_ref: String,
    pub held_out_metrics_ref: String,
    pub promotion_status: LayoutPatchPromotionStatus,
    pub production_mutation: bool,
    pub trace_addresses: Vec<UasAddress>,
}

impl LayoutPatch {
    #[allow(clippy::too_many_arguments)]
    pub fn from_repeated_cold_faults(
        patch_id: impl Into<String>,
        traces: Vec<ColdFaultTrace>,
        target_layout: impl Into<String>,
        baseline_layout: impl Into<String>,
        changed_tiles: Vec<String>,
        expected_cold_miss_delta: i64,
        observed_cold_miss_delta: i64,
        storage_wear_cost: u64,
        rollback_ref: impl Into<String>,
        held_out_metrics_ref: impl Into<String>,
        production_mutation: bool,
        created_at_ms: u64,
    ) -> Result<Self, SemanticWorkingSetError> {
        let patch_id = patch_id.into();
        let target_layout = target_layout.into();
        let baseline_layout = baseline_layout.into();
        let rollback_ref = rollback_ref.into();
        let held_out_metrics_ref = held_out_metrics_ref.into();
        validate_nonempty("patch_id", &patch_id)?;
        validate_nonempty("target_layout", &target_layout)?;
        validate_nonempty("baseline_layout", &baseline_layout)?;
        validate_nonempty("rollback_ref", &rollback_ref)?;
        validate_nonempty("held_out_metrics_ref", &held_out_metrics_ref)?;
        let changed_tiles = canonicalize_strings(
            "changed_tiles",
            changed_tiles,
            SemanticWorkingSetError::MissingChangedTile,
        )?;
        if traces.len() < 2 {
            return Err(SemanticWorkingSetError::ColdFaultLearningRejected {
                reason: "repeated_misses_required".to_string(),
            });
        }
        if expected_cold_miss_delta >= 0 || observed_cold_miss_delta >= 0 {
            return Err(SemanticWorkingSetError::ColdFaultLearningRejected {
                reason: "held_out_improvement_required".to_string(),
            });
        }
        if storage_wear_cost > MAX_LAYOUT_PATCH_STORAGE_WEAR_COST {
            return Err(SemanticWorkingSetError::ColdFaultLearningRejected {
                reason: "storage_wear_cost_unbounded".to_string(),
            });
        }
        if !rollback_ref.starts_with(ROLLBACK_PREFIX) {
            return Err(SemanticWorkingSetError::ColdFaultLearningRejected {
                reason: "missing_rollback".to_string(),
            });
        }
        if !held_out_metrics_ref.starts_with(HELD_OUT_PREFIX) {
            return Err(SemanticWorkingSetError::ColdFaultLearningRejected {
                reason: "held_out_metrics_required".to_string(),
            });
        }
        if production_mutation {
            return Err(SemanticWorkingSetError::ColdFaultLearningRejected {
                reason: "production_mutation_forbidden".to_string(),
            });
        }
        let mut trace_addresses = traces
            .iter()
            .map(|trace| trace.trace_address.clone())
            .collect::<Vec<_>>();
        trace_addresses.sort_by_key(|address| address.to_string());
        let patch_address = layout_patch_address(
            &patch_id,
            &target_layout,
            &baseline_layout,
            &changed_tiles,
            expected_cold_miss_delta,
            observed_cold_miss_delta,
            storage_wear_cost,
            &rollback_ref,
            &held_out_metrics_ref,
            &trace_addresses,
            created_at_ms,
        );
        Ok(Self {
            patch_address,
            patch_id,
            target_layout,
            baseline_layout,
            changed_tiles,
            expected_cold_miss_delta,
            observed_cold_miss_delta,
            storage_wear_cost,
            rollback_ref,
            held_out_metrics_ref,
            promotion_status: LayoutPatchPromotionStatus::ShadowCandidate,
            production_mutation,
            trace_addresses,
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

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct WorkingSetOracleScore {
    pub quality_bps: u16,
    pub evidence_validity_bps: u16,
    pub cold_misses: u64,
    pub active_bytes: u64,
}

impl WorkingSetOracleScore {
    pub fn new(
        quality_bps: u16,
        evidence_validity_bps: u16,
        cold_misses: u64,
        active_bytes: u64,
    ) -> Result<Self, SemanticWorkingSetError> {
        if quality_bps > MAX_SCORE_BPS || evidence_validity_bps > MAX_SCORE_BPS {
            return Err(SemanticWorkingSetError::WorkingSetOracleRejected {
                reason: "score_out_of_range".to_string(),
            });
        }
        Ok(Self {
            quality_bps,
            evidence_validity_bps,
            cold_misses,
            active_bytes,
        })
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct WorkingSetOracleBaselineScore {
    pub policy_id: String,
    pub score: WorkingSetOracleScore,
}

impl WorkingSetOracleBaselineScore {
    pub fn new(
        policy_id: impl Into<String>,
        score: WorkingSetOracleScore,
    ) -> Result<Self, SemanticWorkingSetError> {
        let policy_id = policy_id.into();
        validate_nonempty("baseline_policy", &policy_id)?;
        Ok(Self { policy_id, score })
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum WorkingSetOracleStatus {
    BeatsBaselines,
    Abstained,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct WorkingSetOracleCard {
    pub oracle_address: UasAddress,
    pub oracle_id: String,
    pub inputs: Vec<String>,
    pub predicted_units: Vec<UasAddress>,
    pub confidence_bps: u16,
    pub abstain_condition: String,
    pub baseline_policies: Vec<WorkingSetOracleBaselineScore>,
    pub held_out_score: WorkingSetOracleScore,
    pub regret_update_key: String,
    pub status: WorkingSetOracleStatus,
}

impl WorkingSetOracleCard {
    #[allow(clippy::too_many_arguments)]
    pub fn evaluate(
        oracle_id: impl Into<String>,
        inputs: Vec<String>,
        predicted_units: Vec<UasAddress>,
        confidence_bps: u16,
        abstain_condition: impl Into<String>,
        baseline_policies: Vec<WorkingSetOracleBaselineScore>,
        held_out_score: WorkingSetOracleScore,
        regret_update_key: impl Into<String>,
        created_at_ms: u64,
    ) -> Result<Self, SemanticWorkingSetError> {
        let oracle_id = oracle_id.into();
        let abstain_condition = abstain_condition.into();
        let regret_update_key = regret_update_key.into();
        validate_nonempty("oracle_id", &oracle_id)?;
        validate_nonempty("abstain_condition", &abstain_condition)?;
        validate_nonempty("regret_update_key", &regret_update_key)?;
        if confidence_bps > MAX_SCORE_BPS {
            return Err(SemanticWorkingSetError::WorkingSetOracleRejected {
                reason: "confidence_out_of_range".to_string(),
            });
        }
        if !abstain_condition.starts_with(ABSTAIN_PREFIX) {
            return Err(SemanticWorkingSetError::WorkingSetOracleRejected {
                reason: "named_abstain_condition_required".to_string(),
            });
        }
        let inputs = canonicalize_strings(
            "oracle_inputs",
            inputs,
            SemanticWorkingSetError::MissingOracleInput,
        )?;
        if predicted_units.is_empty() {
            return Err(SemanticWorkingSetError::MissingPredictedUnit);
        }
        let mut predicted_units = predicted_units;
        predicted_units.sort_by_key(|address| address.to_string());
        predicted_units.dedup();
        if baseline_policies.is_empty() {
            return Err(SemanticWorkingSetError::MissingBaselinePolicy);
        }
        let mut baseline_policies = baseline_policies;
        baseline_policies.sort_by(|left, right| left.policy_id.cmp(&right.policy_id));
        let mut seen_policy_ids = HashSet::new();
        for policy in &baseline_policies {
            validate_nonempty("baseline_policy", &policy.policy_id)?;
            if !seen_policy_ids.insert(policy.policy_id.clone()) {
                return Err(SemanticWorkingSetError::WorkingSetOracleRejected {
                    reason: "duplicate_baseline_policy".to_string(),
                });
            }
        }

        let beats_baselines = oracle_score_beats_baselines(&held_out_score, &baseline_policies);
        let status = if confidence_bps >= MIN_ORACLE_CONFIDENCE_BPS && beats_baselines {
            WorkingSetOracleStatus::BeatsBaselines
        } else {
            WorkingSetOracleStatus::Abstained
        };
        if status == WorkingSetOracleStatus::Abstained
            && abstain_condition.len() <= ABSTAIN_PREFIX.len()
        {
            return Err(SemanticWorkingSetError::WorkingSetOracleRejected {
                reason: "empty_abstain_reason".to_string(),
            });
        }
        let oracle_address = working_set_oracle_address(
            &oracle_id,
            &inputs,
            &predicted_units,
            confidence_bps,
            &abstain_condition,
            &baseline_policies,
            &held_out_score,
            &regret_update_key,
            status,
            created_at_ms,
        );
        Ok(Self {
            oracle_address,
            oracle_id,
            inputs,
            predicted_units,
            confidence_bps,
            abstain_condition,
            baseline_policies,
            held_out_score,
            regret_update_key,
            status,
        })
    }
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
    pub compatibility_failures: Vec<String>,
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
            compatibility_failures: Vec::new(),
        })
    }

    pub fn with_compatibility_failures(
        mut self,
        failures: Vec<String>,
    ) -> Result<Self, SemanticWorkingSetError> {
        self.compatibility_failures = canonicalize_strings(
            "compatibility_failure",
            failures,
            SemanticWorkingSetError::InvalidKvBudget,
        )?;
        Ok(self)
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
    MissingAffectedOrgan,
    MissingChangedTile,
    MissingOracleInput,
    MissingPredictedUnit,
    MissingBaselinePolicy,
    MissingRegretUpdateKey,
    MissingAbstainCondition,
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
    SourcePromotionBlocked {
        source_id: String,
        reason: String,
    },
    ColdFaultLearningRejected {
        reason: String,
    },
    WorkingSetOracleRejected {
        reason: String,
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
            Self::MissingAffectedOrgan => write!(f, "affected_organs are required"),
            Self::MissingChangedTile => write!(f, "changed_tiles are required"),
            Self::MissingOracleInput => write!(f, "oracle_inputs are required"),
            Self::MissingPredictedUnit => write!(f, "predicted_units are required"),
            Self::MissingBaselinePolicy => write!(f, "baseline_policy is required"),
            Self::MissingRegretUpdateKey => write!(f, "regret_update_key is required"),
            Self::MissingAbstainCondition => write!(f, "abstain_condition is required"),
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
            Self::SourcePromotionBlocked { source_id, reason } => {
                write!(
                    f,
                    "{source_id} cannot promote source-to-residency patch: {reason}"
                )
            }
            Self::ColdFaultLearningRejected { reason } => {
                write!(f, "cold-fault learning rejected: {reason}")
            }
            Self::WorkingSetOracleRejected { reason } => {
                write!(f, "working-set oracle rejected: {reason}")
            }
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
fn source_to_residency_patch_address(
    graph_address: &UasAddress,
    card: &SourceCard,
    patch_kind: SourceToResidencyPatchKind,
    proposed_unit_or_policy: &str,
    affected_organs: &[String],
    import_gate: &str,
    falsifier_required: &str,
    rollback_ref: &str,
    created_at_ms: u64,
) -> UasAddress {
    let mut preimage = String::new();
    preimage.push_str("source_to_residency_patch_v1\n");
    push_preimage(
        &mut preimage,
        "source_graph_address",
        &graph_address.to_string(),
    );
    push_preimage(&mut preimage, "source_id", &card.source_id);
    push_preimage(&mut preimage, "source_digest", &card.digest);
    push_preimage(&mut preimage, "patch_kind", &format!("{:?}", patch_kind));
    push_preimage(
        &mut preimage,
        "proposed_unit_or_policy",
        proposed_unit_or_policy,
    );
    push_string_list_preimage(&mut preimage, "affected_organs", affected_organs);
    push_preimage(&mut preimage, "import_gate", import_gate);
    push_preimage(&mut preimage, "falsifier_required", falsifier_required);
    push_preimage(&mut preimage, "rollback_ref", rollback_ref);
    UasAddress::new(
        UasKind::Other(SOURCE_TO_RESIDENCY_PATCH_UAS_KIND.to_string()),
        preimage.as_bytes(),
        created_at_ms,
    )
}

fn source_license_blocks_promotion(license_or_usage_note: &str) -> bool {
    let lower = license_or_usage_note.to_ascii_lowercase();
    lower.contains("license-blocked")
        || lower.contains("usage-blocked")
        || lower.contains("forbid")
        || lower.contains("no residency")
        || lower.contains("do not promote")
}

#[allow(clippy::too_many_arguments)]
fn cold_fault_trace_address(
    mission_id: &str,
    missing_unit: &UasAddress,
    expected_unit: &UasAddress,
    stall_ms: u64,
    cold_io_bytes: u64,
    fallback_used: &str,
    answer_effect: &str,
    source_or_cache_cause: &str,
    next_layout_patch: &str,
    created_at_ms: u64,
) -> UasAddress {
    let mut preimage = String::new();
    preimage.push_str("cold_fault_trace_v1\n");
    push_preimage(&mut preimage, "mission_id", mission_id);
    push_preimage(&mut preimage, "missing_unit", &missing_unit.to_string());
    push_preimage(&mut preimage, "expected_unit", &expected_unit.to_string());
    push_preimage(&mut preimage, "stall_ms", &stall_ms.to_string());
    push_preimage(&mut preimage, "cold_io_bytes", &cold_io_bytes.to_string());
    push_preimage(&mut preimage, "fallback_used", fallback_used);
    push_preimage(&mut preimage, "answer_effect", answer_effect);
    push_preimage(
        &mut preimage,
        "source_or_cache_cause",
        source_or_cache_cause,
    );
    push_preimage(&mut preimage, "next_layout_patch", next_layout_patch);
    UasAddress::new(
        UasKind::Other(COLD_FAULT_TRACE_UAS_KIND.to_string()),
        preimage.as_bytes(),
        created_at_ms,
    )
}

#[allow(clippy::too_many_arguments)]
fn layout_patch_address(
    patch_id: &str,
    target_layout: &str,
    baseline_layout: &str,
    changed_tiles: &[String],
    expected_cold_miss_delta: i64,
    observed_cold_miss_delta: i64,
    storage_wear_cost: u64,
    rollback_ref: &str,
    held_out_metrics_ref: &str,
    trace_addresses: &[UasAddress],
    created_at_ms: u64,
) -> UasAddress {
    let mut preimage = String::new();
    preimage.push_str("layout_patch_v1\n");
    push_preimage(&mut preimage, "patch_id", patch_id);
    push_preimage(&mut preimage, "target_layout", target_layout);
    push_preimage(&mut preimage, "baseline_layout", baseline_layout);
    push_string_list_preimage(&mut preimage, "changed_tiles", changed_tiles);
    push_preimage(
        &mut preimage,
        "expected_cold_miss_delta",
        &expected_cold_miss_delta.to_string(),
    );
    push_preimage(
        &mut preimage,
        "observed_cold_miss_delta",
        &observed_cold_miss_delta.to_string(),
    );
    push_preimage(
        &mut preimage,
        "storage_wear_cost",
        &storage_wear_cost.to_string(),
    );
    push_preimage(&mut preimage, "rollback_ref", rollback_ref);
    push_preimage(&mut preimage, "held_out_metrics_ref", held_out_metrics_ref);
    for trace_address in trace_addresses {
        push_preimage(&mut preimage, "trace_address", &trace_address.to_string());
    }
    UasAddress::new(
        UasKind::Other(LAYOUT_PATCH_UAS_KIND.to_string()),
        preimage.as_bytes(),
        created_at_ms,
    )
}

fn oracle_score_beats_baselines(
    held_out_score: &WorkingSetOracleScore,
    baseline_policies: &[WorkingSetOracleBaselineScore],
) -> bool {
    baseline_policies.iter().all(|baseline| {
        held_out_score.quality_bps > baseline.score.quality_bps
            && held_out_score.evidence_validity_bps > baseline.score.evidence_validity_bps
            && held_out_score.cold_misses < baseline.score.cold_misses
            && held_out_score.active_bytes < baseline.score.active_bytes
    })
}

#[allow(clippy::too_many_arguments)]
fn working_set_oracle_address(
    oracle_id: &str,
    inputs: &[String],
    predicted_units: &[UasAddress],
    confidence_bps: u16,
    abstain_condition: &str,
    baseline_policies: &[WorkingSetOracleBaselineScore],
    held_out_score: &WorkingSetOracleScore,
    regret_update_key: &str,
    status: WorkingSetOracleStatus,
    created_at_ms: u64,
) -> UasAddress {
    let mut preimage = String::new();
    preimage.push_str("working_set_oracle_card_v1\n");
    push_preimage(&mut preimage, "oracle_id", oracle_id);
    push_string_list_preimage(&mut preimage, "inputs", inputs);
    for predicted_unit in predicted_units {
        push_preimage(&mut preimage, "predicted_unit", &predicted_unit.to_string());
    }
    push_preimage(&mut preimage, "confidence_bps", &confidence_bps.to_string());
    push_preimage(&mut preimage, "abstain_condition", abstain_condition);
    for baseline in baseline_policies {
        push_preimage(&mut preimage, "baseline_policy", &baseline.policy_id);
        push_preimage(
            &mut preimage,
            "baseline_quality_bps",
            &baseline.score.quality_bps.to_string(),
        );
        push_preimage(
            &mut preimage,
            "baseline_evidence_validity_bps",
            &baseline.score.evidence_validity_bps.to_string(),
        );
        push_preimage(
            &mut preimage,
            "baseline_cold_misses",
            &baseline.score.cold_misses.to_string(),
        );
        push_preimage(
            &mut preimage,
            "baseline_active_bytes",
            &baseline.score.active_bytes.to_string(),
        );
    }
    push_preimage(
        &mut preimage,
        "held_out_quality_bps",
        &held_out_score.quality_bps.to_string(),
    );
    push_preimage(
        &mut preimage,
        "held_out_evidence_validity_bps",
        &held_out_score.evidence_validity_bps.to_string(),
    );
    push_preimage(
        &mut preimage,
        "held_out_cold_misses",
        &held_out_score.cold_misses.to_string(),
    );
    push_preimage(
        &mut preimage,
        "held_out_active_bytes",
        &held_out_score.active_bytes.to_string(),
    );
    push_preimage(&mut preimage, "regret_update_key", regret_update_key);
    push_preimage(&mut preimage, "status", &format!("{:?}", status));
    UasAddress::new(
        UasKind::Other(WORKING_SET_ORACLE_UAS_KIND.to_string()),
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
        "kv_context_tokens",
        &kv_budget.context_tokens.to_string(),
    );
    push_preimage(&mut preimage, "kv_codec", &kv_budget.kv_codec);
    push_preimage(
        &mut preimage,
        "kv_bytes_predicted",
        &kv_budget.kv_bytes_predicted.to_string(),
    );
    push_preimage(
        &mut preimage,
        "kv_bytes_observed",
        &kv_budget.kv_bytes_observed.to_string(),
    );
    push_preimage(
        &mut preimage,
        "prompt_cache_hit_tokens",
        &kv_budget.prompt_cache_hit_tokens.to_string(),
    );
    push_preimage(
        &mut preimage,
        "prompt_cache_miss_tokens",
        &kv_budget.prompt_cache_miss_tokens.to_string(),
    );
    push_preimage(&mut preimage, "quality_caveat", &kv_budget.quality_caveat);
    for failure in &kv_budget.compatibility_failures {
        push_preimage(&mut preimage, "kv_compatibility_failure", failure);
    }
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
        "affected_organs" => SemanticWorkingSetError::MissingAffectedOrgan,
        "changed_tiles" => SemanticWorkingSetError::MissingChangedTile,
        "oracle_inputs" => SemanticWorkingSetError::MissingOracleInput,
        "baseline_policy" => SemanticWorkingSetError::MissingBaselinePolicy,
        "regret_update_key" => SemanticWorkingSetError::MissingRegretUpdateKey,
        "abstain_condition" => SemanticWorkingSetError::MissingAbstainCondition,
        "semantic_unit_id" => SemanticWorkingSetError::MissingSemanticUnitId,
        "codec" => SemanticWorkingSetError::MissingCodec,
        "checksum" => SemanticWorkingSetError::MissingChecksum,
        "compatibility_fence" => SemanticWorkingSetError::MissingCompatibilityFence,
        "lease_or_expiry" => SemanticWorkingSetError::MissingLeaseOrExpiry,
        "model_id" => SemanticWorkingSetError::MissingModelId,
        "kv_codec" => SemanticWorkingSetError::MissingKvCodec,
        "quality_caveat" => SemanticWorkingSetError::MissingQualityCaveat,
        "compatibility_failure" => SemanticWorkingSetError::InvalidKvBudget,
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
    fn source_to_residency_patch_rejects_poison_private_stale_license_and_low_credibility() {
        let mut cards = fixture_source_cards();
        cards.push(source_card_with_usage(
            "source:repo:license-blocked",
            SourceSignalType::Repo,
            "https://github.com/fixture/license-blocked",
            "license-blocked-repo",
            1,
            "license-blocked: no residency promotion",
            PrivacyClass::PublicResearch,
            SourceNoPoisonStatus::Clear,
            &["semantic_working_set"],
        ));
        cards.push(source_card_with_usage(
            "source:paper:low-credibility",
            SourceSignalType::Paper,
            "paper://low-credibility",
            "low-credibility-paper",
            9,
            "fixture-only source; motif mining permitted, no raw merge",
            PrivacyClass::PublicResearch,
            SourceNoPoisonStatus::Clear,
            &["semantic_working_set"],
        ));
        let graph = SourceSignalGraph::intake(cards, Vec::new(), CREATED_AT_MS).unwrap();
        let public_source = graph
            .source_cards
            .iter()
            .find(|card| card.source_id == "source:paper:working-set")
            .unwrap();
        let patch = SourceToResidencyPatch::from_source_signal(
            &graph,
            &public_source.source_id,
            &public_source.digest,
            SourceToResidencyPatchKind::Layout,
            "layout:working-set-tile",
            vec!["app_cold_store".to_string(), "runtime_router".to_string()],
            "source:no-poison+license+digest+privacy+credibility",
            "F-SourceToResidency-NoPoison",
            "rollback:source-to-residency",
            CREATED_AT_MS,
        )
        .unwrap();
        assert_eq!(patch.source_graph_address, graph.graph_address);
        assert_eq!(
            patch.promotion_status,
            SourceToResidencyPromotionStatus::ShadowCandidate
        );
        assert_eq!(
            patch.affected_organs,
            vec!["app_cold_store".to_string(), "runtime_router".to_string()]
        );

        let stale = SourceToResidencyPatch::from_source_signal(
            &graph,
            &public_source.source_id,
            digest("changed-source"),
            SourceToResidencyPatchKind::Layout,
            "layout:working-set-tile",
            vec!["app_cold_store".to_string()],
            "source:no-poison+license+digest+privacy+credibility",
            "F-SourceToResidency-NoPoison",
            "rollback:source-to-residency",
            CREATED_AT_MS,
        )
        .unwrap_err();
        assert!(matches!(
            stale,
            SemanticWorkingSetError::SourcePromotionBlocked { .. }
        ));

        for source_id in [
            "source:poison:prompt-injection",
            "source:doc:semantic-working-set",
            "source:repo:license-blocked",
            "source:paper:low-credibility",
        ] {
            let digest = graph
                .source_cards
                .iter()
                .find(|card| card.source_id == source_id)
                .map(|card| card.digest.clone())
                .unwrap_or_else(|| digest("prompt-injection-fixture"));
            let blocked = SourceToResidencyPatch::from_source_signal(
                &graph,
                source_id,
                digest,
                SourceToResidencyPatchKind::Route,
                "route:source-derived-policy",
                vec!["runtime_router".to_string()],
                "source:no-poison+license+digest+privacy+credibility",
                "F-SourceToResidency-NoPoison",
                "rollback:source-to-residency",
                CREATED_AT_MS,
            )
            .unwrap_err();
            assert!(matches!(
                blocked,
                SemanticWorkingSetError::SourcePromotionBlocked { .. }
            ));
        }
    }

    #[test]
    fn cold_fault_traces_generate_shadow_layout_patch_only_with_held_out_improvement() {
        let traces = fixture_cold_fault_traces();
        let reversed = traces.iter().cloned().rev().collect::<Vec<_>>();
        let patch = fixture_layout_patch(traces.clone()).unwrap();
        let reversed_patch = fixture_layout_patch(reversed).unwrap();
        assert_eq!(patch.patch_address, reversed_patch.patch_address);
        assert_eq!(patch.trace_addresses.len(), 2);
        assert_eq!(patch.expected_cold_miss_delta, -2);
        assert_eq!(patch.observed_cold_miss_delta, -1);
        assert_eq!(
            patch.promotion_status,
            LayoutPatchPromotionStatus::ShadowCandidate
        );
        assert!(!patch.production_mutation);
        assert!(patch.rollback_ref.starts_with("rollback:"));
        assert!(patch.held_out_metrics_ref.starts_with("held_out:"));

        let single_trace = fixture_layout_patch(vec![traces[0].clone()]).unwrap_err();
        assert!(matches!(
            single_trace,
            SemanticWorkingSetError::ColdFaultLearningRejected { .. }
        ));

        let no_improvement = LayoutPatch::from_repeated_cold_faults(
            "layout-patch:no-improvement",
            traces.clone(),
            "layout:coactivated",
            "layout:file-order",
            vec!["tile:module-5".to_string()],
            0,
            0,
            4096,
            "rollback:cold-fault-layout",
            "held_out:module-5",
            false,
            CREATED_AT_MS,
        )
        .unwrap_err();
        assert!(matches!(
            no_improvement,
            SemanticWorkingSetError::ColdFaultLearningRejected { .. }
        ));

        let live_mutation = LayoutPatch::from_repeated_cold_faults(
            "layout-patch:live-mutation",
            traces,
            "layout:coactivated",
            "layout:file-order",
            vec!["tile:module-5".to_string()],
            -2,
            -1,
            4096,
            "rollback:cold-fault-layout",
            "held_out:module-5",
            true,
            CREATED_AT_MS,
        )
        .unwrap_err();
        assert!(matches!(
            live_mutation,
            SemanticWorkingSetError::ColdFaultLearningRejected { .. }
        ));

        let zero_stall = ColdFaultTrace::new(
            "mission:module-5",
            address(UasKind::ModelComponent, b"missing"),
            address(UasKind::ModelComponent, b"expected"),
            0,
            64 * 1024,
            "runtime_router:fallback_static_route",
            "answer_delayed",
            "source:prefetch-window-miss",
            "layout-patch:module-5",
            CREATED_AT_MS,
        )
        .unwrap_err();
        assert!(matches!(
            zero_stall,
            SemanticWorkingSetError::ColdFaultLearningRejected { .. }
        ));
    }

    #[test]
    fn working_set_oracle_beats_baselines_or_abstains_with_reason() {
        let inputs = vec![
            "mission:module-5-adversarial-thinking".to_string(),
            "source:doc:semantic-working-set".to_string(),
        ];
        let predicted_units = vec![
            address(UasKind::ModelComponent, b"module-5-evidence"),
            address(UasKind::ModelComponent, b"module-5-kv"),
        ];
        let baselines = fixture_oracle_baselines();
        let held_out = oracle_score(9400, 9600, 0, 192 * 1024);
        let card = WorkingSetOracleCard::evaluate(
            "oracle:semantic-working-set-v1",
            inputs.clone(),
            predicted_units.clone(),
            8100,
            "abstain:confidence_below_0.60_or_baseline_loss",
            baselines.clone(),
            held_out,
            "regret:semantic-working-set-v1",
            CREATED_AT_MS,
        )
        .unwrap();
        let reversed = WorkingSetOracleCard::evaluate(
            "oracle:semantic-working-set-v1",
            inputs.into_iter().rev().collect(),
            predicted_units.into_iter().rev().collect(),
            8100,
            "abstain:confidence_below_0.60_or_baseline_loss",
            baselines.into_iter().rev().collect(),
            held_out,
            "regret:semantic-working-set-v1",
            CREATED_AT_MS,
        )
        .unwrap();
        assert_eq!(card.oracle_address, reversed.oracle_address);
        assert_eq!(card.status, WorkingSetOracleStatus::BeatsBaselines);
        assert_eq!(card.baseline_policies.len(), 3);
        assert_eq!(card.predicted_units.len(), 2);

        let low_confidence = WorkingSetOracleCard::evaluate(
            "oracle:semantic-working-set-v1",
            vec!["mission:module-5-adversarial-thinking".to_string()],
            vec![address(UasKind::ModelComponent, b"module-5-kv")],
            5100,
            "abstain:low_confidence",
            fixture_oracle_baselines(),
            held_out,
            "regret:semantic-working-set-v1",
            CREATED_AT_MS,
        )
        .unwrap();
        assert_eq!(low_confidence.status, WorkingSetOracleStatus::Abstained);

        let non_beating = WorkingSetOracleCard::evaluate(
            "oracle:semantic-working-set-v1",
            vec!["mission:module-5-adversarial-thinking".to_string()],
            vec![address(UasKind::ModelComponent, b"module-5-kv")],
            8100,
            "abstain:baseline_loss",
            fixture_oracle_baselines(),
            oracle_score(7000, 7200, 2, 768 * 1024),
            "regret:semantic-working-set-v1",
            CREATED_AT_MS,
        )
        .unwrap();
        assert_eq!(non_beating.status, WorkingSetOracleStatus::Abstained);

        let missing_abstain = WorkingSetOracleCard::evaluate(
            "oracle:semantic-working-set-v1",
            vec!["mission:module-5-adversarial-thinking".to_string()],
            vec![address(UasKind::ModelComponent, b"module-5-kv")],
            8100,
            "",
            fixture_oracle_baselines(),
            held_out,
            "regret:semantic-working-set-v1",
            CREATED_AT_MS,
        )
        .unwrap_err();
        assert!(matches!(
            missing_abstain,
            SemanticWorkingSetError::MissingAbstainCondition
        ));

        let empty_inputs = WorkingSetOracleCard::evaluate(
            "oracle:semantic-working-set-v1",
            Vec::new(),
            vec![address(UasKind::ModelComponent, b"module-5-kv")],
            8100,
            "abstain:baseline_loss",
            fixture_oracle_baselines(),
            held_out,
            "regret:semantic-working-set-v1",
            CREATED_AT_MS,
        )
        .unwrap_err();
        assert!(matches!(
            empty_inputs,
            SemanticWorkingSetError::MissingOracleInput
        ));

        let empty_predicted = WorkingSetOracleCard::evaluate(
            "oracle:semantic-working-set-v1",
            vec!["mission:module-5-adversarial-thinking".to_string()],
            Vec::new(),
            8100,
            "abstain:baseline_loss",
            fixture_oracle_baselines(),
            held_out,
            "regret:semantic-working-set-v1",
            CREATED_AT_MS,
        )
        .unwrap_err();
        assert!(matches!(
            empty_predicted,
            SemanticWorkingSetError::MissingPredictedUnit
        ));

        let no_baselines = WorkingSetOracleCard::evaluate(
            "oracle:semantic-working-set-v1",
            vec!["mission:module-5-adversarial-thinking".to_string()],
            vec![address(UasKind::ModelComponent, b"module-5-kv")],
            8100,
            "abstain:baseline_loss",
            Vec::new(),
            held_out,
            "regret:semantic-working-set-v1",
            CREATED_AT_MS,
        )
        .unwrap_err();
        assert!(matches!(
            no_baselines,
            SemanticWorkingSetError::MissingBaselinePolicy
        ));

        let bad_confidence = WorkingSetOracleCard::evaluate(
            "oracle:semantic-working-set-v1",
            vec!["mission:module-5-adversarial-thinking".to_string()],
            vec![address(UasKind::ModelComponent, b"module-5-kv")],
            10_001,
            "abstain:baseline_loss",
            fixture_oracle_baselines(),
            held_out,
            "regret:semantic-working-set-v1",
            CREATED_AT_MS,
        )
        .unwrap_err();
        assert!(matches!(
            bad_confidence,
            SemanticWorkingSetError::WorkingSetOracleRejected { .. }
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
    fn residency_page_table_entries_round_trip_selected_units() {
        let plan = compile(
            fixture_query(2 * 1024 * 1024, 4 * 1024 * 1024),
            vec![
                unit(
                    "evidence",
                    WorkingSetUnitKind::EvidencePage,
                    UasKind::VaultNote,
                    WorkingSetStorageTier::Hot,
                    0,
                    64 * 1024,
                    10,
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
                unit(
                    "weight",
                    WorkingSetUnitKind::WeightPage,
                    UasKind::ModelComponent,
                    WorkingSetStorageTier::Cold,
                    1024 * 1024,
                    1024 * 1024,
                    90,
                ),
            ],
        );

        assert_eq!(plan.page_table.len(), plan.selected_units.len());
        for (unit, entry) in plan.selected_units.iter().zip(&plan.page_table) {
            assert_eq!(entry.semantic_unit_id, unit.semantic_unit_id);
            assert_eq!(entry.uas_address, unit.uas_address);
            assert_eq!(entry.storage_tier, unit.storage_tier);
            assert_eq!(entry.byte_range, unit.byte_range);
            assert_eq!(entry.codec, unit.codec);
            assert_eq!(entry.checksum, unit.checksum);
            assert_eq!(entry.compatibility_fence, unit.compatibility_fence);
            assert_eq!(entry.lease_or_expiry, unit.lease_or_expiry);
            assert_eq!(entry.prefetch_priority, unit.prefetch_priority);
        }
    }

    #[test]
    fn prefetch_window_orders_cold_units_by_priority() {
        let plan = compile(
            fixture_query(2 * 1024 * 1024, 4 * 1024 * 1024),
            vec![
                unit(
                    "cold-low",
                    WorkingSetUnitKind::WeightPage,
                    UasKind::ModelComponent,
                    WorkingSetStorageTier::Cold,
                    0,
                    64 * 1024,
                    10,
                ),
                unit(
                    "hot-evidence",
                    WorkingSetUnitKind::EvidencePage,
                    UasKind::VaultNote,
                    WorkingSetStorageTier::Hot,
                    0,
                    64 * 1024,
                    1,
                ),
                unit(
                    "cold-high",
                    WorkingSetUnitKind::WeightPage,
                    UasKind::ModelComponent,
                    WorkingSetStorageTier::Cold,
                    64 * 1024,
                    64 * 1024,
                    90,
                ),
            ],
        );

        assert_eq!(plan.prefetch_window.ordered_units.len(), 2);
        assert_eq!(
            plan.prefetch_window.ordered_units,
            vec![
                address(UasKind::ModelComponent, b"cold-high"),
                address(UasKind::ModelComponent, b"cold-low"),
            ]
        );
        assert_eq!(plan.prefetch_window.max_bytes, 128 * 1024);
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
    fn mmap_fence_distinguishes_mapping_touch_residency_and_copy_count() {
        let passing = MmapResidencyFence::evaluate(
            "model.gguf",
            0,
            64 * 1024,
            true,
            true,
            64 * 1024,
            1,
            2,
            3,
            64 * 1024,
        )
        .unwrap();
        assert!(passing.pass_or_fail);
        assert_eq!(passing.major_faults, 1);
        assert_eq!(passing.minor_faults, 2);
        assert_eq!(passing.copy_count, 3);

        let under_resident = MmapResidencyFence::evaluate(
            "model.gguf",
            0,
            64 * 1024,
            true,
            true,
            32 * 1024,
            0,
            0,
            0,
            64 * 1024,
        )
        .unwrap();
        assert!(!under_resident.pass_or_fail);

        let cold_only =
            MmapResidencyFence::evaluate("model.gguf", 0, 64 * 1024, false, false, 0, 0, 0, 0, 0)
                .unwrap();
        assert!(cold_only.pass_or_fail);

        let bad_range = MmapResidencyFence::evaluate("model.gguf", 0, 0, true, true, 0, 0, 0, 0, 0)
            .unwrap_err();
        assert!(matches!(
            bad_range,
            SemanticWorkingSetError::InvalidByteRange
        ));
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
        assert!(plan.kv_budget.compatibility_failures.is_empty());
        assert_eq!(plan.prefetch_window.ordered_units.len(), 1);

        let incompatible = fixture_kv_budget()
            .with_compatibility_failures(vec![
                "rope-scale-mismatch".to_string(),
                "prefix-digest-mismatch".to_string(),
            ])
            .unwrap();
        assert_eq!(
            incompatible.compatibility_failures,
            vec![
                "prefix-digest-mismatch".to_string(),
                "rope-scale-mismatch".to_string()
            ]
        );
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

    fn fixture_cold_fault_traces() -> Vec<ColdFaultTrace> {
        vec![
            cold_fault_trace("missing-weight-a", "expected-weight-a", 18, 64 * 1024),
            cold_fault_trace("missing-weight-b", "expected-weight-b", 22, 64 * 1024),
        ]
    }

    fn cold_fault_trace(
        missing_unit: &str,
        expected_unit: &str,
        stall_ms: u64,
        cold_io_bytes: u64,
    ) -> ColdFaultTrace {
        ColdFaultTrace::new(
            "mission:module-5-adversarial-thinking",
            address(UasKind::ModelComponent, missing_unit.as_bytes()),
            address(UasKind::ModelComponent, expected_unit.as_bytes()),
            stall_ms,
            cold_io_bytes,
            "runtime_router:fallback_static_route",
            "answer_delayed_not_wrong",
            "source:prefetch-window-miss",
            "layout-patch:module-5-coactivation",
            CREATED_AT_MS,
        )
        .unwrap()
    }

    fn fixture_layout_patch(
        traces: Vec<ColdFaultTrace>,
    ) -> Result<LayoutPatch, SemanticWorkingSetError> {
        LayoutPatch::from_repeated_cold_faults(
            "layout-patch:module-5-coactivation",
            traces,
            "layout:module-5-coactivated",
            "layout:file-order",
            vec!["tile:module-5".to_string(), "tile:assessment".to_string()],
            -2,
            -1,
            4096,
            "rollback:cold-fault-layout",
            "held_out:module-5-fixtures",
            false,
            CREATED_AT_MS,
        )
    }

    fn fixture_oracle_baselines() -> Vec<WorkingSetOracleBaselineScore> {
        vec![
            oracle_baseline("baseline:file-order", 7200, 7800, 2, 512 * 1024),
            oracle_baseline("baseline:recency", 8000, 8200, 1, 384 * 1024),
            oracle_baseline("baseline:random", 6600, 7000, 2, 448 * 1024),
        ]
    }

    fn oracle_baseline(
        policy_id: &str,
        quality_bps: u16,
        evidence_validity_bps: u16,
        cold_misses: u64,
        active_bytes: u64,
    ) -> WorkingSetOracleBaselineScore {
        WorkingSetOracleBaselineScore::new(
            policy_id,
            oracle_score(
                quality_bps,
                evidence_validity_bps,
                cold_misses,
                active_bytes,
            ),
        )
        .unwrap()
    }

    fn oracle_score(
        quality_bps: u16,
        evidence_validity_bps: u16,
        cold_misses: u64,
        active_bytes: u64,
    ) -> WorkingSetOracleScore {
        WorkingSetOracleScore::new(
            quality_bps,
            evidence_validity_bps,
            cold_misses,
            active_bytes,
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

    #[allow(clippy::too_many_arguments)]
    fn source_card_with_usage(
        source_id: &str,
        source_type: SourceSignalType,
        locator: &str,
        digest_seed: &str,
        credibility_rank: u8,
        license_or_usage_note: &str,
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
            license_or_usage_note,
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
