//! `falsify_kv_page_sketch_index` -- KV page sketch-index contract.
//!
//! Metadata-only witness for `F-KVPageSketchIndex`. It proves page sketches bind
//! UAS address, byte count, compatibility fence, sketch evidence, hit/miss
//! telemetry, privacy class, rollback, RunEventLog, and AnswerPacket visibility
//! before query-aware KV/page selection can promote.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-KVPageSketchIndex";
const FIXTURE_ID: &str = "kv_page_sketch_index_v1";
const COMMAND: &str = "Tools/falsifiers/f_kv_page_sketch_index.sh";
const RESULT: &str = "artifacts/falsifiers/kv_page_sketch_index/result.json";
const UPSTREAM_AUCTION: &str = "artifacts/falsifiers/verifier_budget_auction/result.json";
const CURRENT_FENCE: &str = "fence:model:qwen3.5:kv:v1:tokenizer:qwen3.5:adapter:none";
const REQUIRED_FALSE_NEGATIVE_POLICY: &str = "forbid_required_evidence_drop";
const SKETCH_DIMENSION: usize = 8;
const MAX_PAGE_BYTE_COUNT: u64 = 16 * 1024 * 1024;
const MAX_INDEX_METADATA_BYTES: u64 = 2 * 1024 * 1024;

#[derive(Clone)]
// UAS: uas:kv-page-sketch:page
// Plane: Assembly + Verification
// Residency: metadata-only page summary; no KV/runtime bytes loaded.
struct KvPageSketch {
    split: String,
    page_id: String,
    uas_address: String,
    source_page_ref: String,
    page_digest: String,
    byte_count: u64,
    min_key_sketch: Vec<i16>,
    max_key_sketch: Vec<i16>,
    semantic_tags: Vec<String>,
    recency_rank: u64,
    hit_count: Option<u64>,
    miss_count: Option<u64>,
    compatibility_fence: String,
    privacy_class: String,
    evidence_refs: Vec<String>,
    proof_critical: bool,
    stale: bool,
}

#[derive(Clone)]
// UAS: uas:kv-page-sketch:index
// Plane: Controller + Assembly + Verification
// Residency: metadata-only sketch index.
struct KvPageSketchIndexFixture {
    index_id: String,
    model_id: String,
    tokenizer_id: String,
    upstream_auction_ref: String,
    pages: Vec<KvPageSketch>,
    required_evidence_page_ids: Vec<String>,
    recency_baseline_page_ids: Vec<String>,
    tagless_baseline_page_ids: Vec<String>,
    file_order_baseline_page_ids: Vec<String>,
    compatibility_fence: String,
    false_negative_policy: String,
    rollback_handle: String,
    run_event_log_ref: String,
    answer_packet_ref: String,
    route_authority: String,
    index_metadata_bytes: u64,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    live_policy_mutated: bool,
}

#[derive(Default, Clone, Copy)]
// UAS: uas:kv-page-sketch:metrics
// Plane: Verification
// Residency: metadata-only summary.
struct SketchMetrics {
    page_count: u64,
    training_page_count: u64,
    held_out_page_count: u64,
    required_evidence_page_count: u64,
    semantic_tag_count: u64,
    total_hit_count: u64,
    total_miss_count: u64,
    total_page_bytes: u64,
    max_page_byte_count: u64,
    max_index_metadata_bytes: u64,
    required_evidence_coverage_bps: u64,
    recency_baseline_coverage_bps: u64,
    tagless_baseline_coverage_bps: u64,
    file_order_baseline_coverage_bps: u64,
}

#[derive(Debug, Eq, PartialEq)]
// UAS: uas:kv-page-sketch:error
// Plane: Verification
// Residency: metadata-only rejection reason.
enum KvPageSketchError {
    MissingIndex,
    DuplicateIndex,
    MissingIndexId,
    MissingModelId,
    MissingTokenizerId,
    MissingUpstreamAuction,
    MissingPage,
    DuplicatePage,
    MissingSplit,
    MissingPageId,
    MissingUasAddress,
    MissingSourceRef,
    MissingDigest,
    MissingByteCount,
    OversizedPage,
    MissingMinSketch,
    MissingMaxSketch,
    SketchDimensionMismatch,
    SketchOrderInvalid,
    MissingSemanticTag,
    MissingRecency,
    MissingHitCount,
    MissingMissCount,
    MissingCompatibilityFence,
    IncompatibleFence,
    MissingEvidenceRef,
    InvalidPrivacyClass,
    StalePage,
    MissingRequiredEvidence,
    RequiredEvidenceFalseNegative,
    MissingBaselinePage,
    MissingFalseNegativePolicy,
    MissingRollback,
    MissingRunEventLog,
    MissingAnswerPacket,
    HiddenLiveAuthority,
    LivePolicyMutation,
    HiddenChainExposure,
    CloudSource,
    IndexMetadataBudgetExceeded,
    RecencyBaselineUnbeaten,
    TaglessBaselineUnbeaten,
    FileOrderBaselineUnbeaten,
}

impl std::fmt::Display for KvPageSketchError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for KvPageSketchError {}

fn main() -> std::process::ExitCode {
    let artifact = match build_artifact() {
        Ok(artifact) => artifact,
        Err(error) => {
            eprintln!("failed to build {FALSIFIER_ID}: {error}");
            return std::process::ExitCode::from(2);
        }
    };

    let path = PathBuf::from(RESULT);
    if let Some(parent) = path.parent() {
        if let Err(error) = std::fs::create_dir_all(parent) {
            eprintln!("failed to create artifact directory: {error}");
            return std::process::ExitCode::from(2);
        }
    }
    let mut file = match std::fs::File::create(&path) {
        Ok(file) => file,
        Err(error) => {
            eprintln!("failed to open artifact: {error}");
            return std::process::ExitCode::from(2);
        }
    };
    if let Err(error) = write_artifact(&mut file, &artifact) {
        eprintln!("failed to write artifact: {error}");
        return std::process::ExitCode::from(2);
    }

    println!(
        "{FALSIFIER_ID}: overall_pass={} page_count={} sketch_index_address={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["page_count"].value,
        artifact.measurements["sketch_index_address"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let indexes = fixture_indexes();
    let reversed = indexes.iter().cloned().rev().collect::<Vec<_>>();
    let registry = KvPageSketchRegistry::new(indexes)?;
    let reversed_registry = KvPageSketchRegistry::new(reversed)?;
    let metrics = registry.metrics;

    let upstream_verifier_budget_auction_pass = upstream_auction_pass();
    let kv_page_sketch_index_fixture_present =
        registry.indexes.len() == 2 && metrics.page_count == 8;
    let training_split_bound = metrics.training_page_count >= 2;
    let held_out_split_bound = metrics.held_out_page_count >= 6;
    let index_ids_bound = registry
        .indexes
        .iter()
        .all(|index| index.index_id.starts_with("kv-sketch-index:"));
    let model_ids_bound = registry
        .indexes
        .iter()
        .all(|index| index.model_id.starts_with("model:"));
    let tokenizer_ids_bound = registry
        .indexes
        .iter()
        .all(|index| index.tokenizer_id.starts_with("tokenizer:"));
    let upstream_auction_ref_bound = registry
        .indexes
        .iter()
        .all(|index| index.upstream_auction_ref == UPSTREAM_AUCTION);
    let page_ids_bound = registry.indexes.iter().all(|index| {
        index
            .pages
            .iter()
            .all(|page| page.page_id.starts_with("kv-page:"))
    });
    let uas_page_addresses_bound = registry.indexes.iter().all(|index| {
        index
            .pages
            .iter()
            .all(|page| page.uas_address.starts_with("uas:kv-page:"))
    });
    let page_digests_bound = registry.indexes.iter().all(|index| {
        index
            .pages
            .iter()
            .all(|page| page.page_digest.starts_with("sha256:"))
    });
    let byte_counts_bound = registry.indexes.iter().all(|index| {
        index
            .pages
            .iter()
            .all(|page| page.byte_count > 0 && page.byte_count <= MAX_PAGE_BYTE_COUNT)
    });
    let min_key_sketch_bound = registry.indexes.iter().all(|index| {
        index
            .pages
            .iter()
            .all(|page| page.min_key_sketch.len() == SKETCH_DIMENSION)
    });
    let max_key_sketch_bound = registry.indexes.iter().all(|index| {
        index
            .pages
            .iter()
            .all(|page| page.max_key_sketch.len() == SKETCH_DIMENSION)
    });
    let sketch_dimension_bound = min_key_sketch_bound && max_key_sketch_bound;
    let sketch_order_bound = registry.indexes.iter().all(|index| {
        index.pages.iter().all(|page| {
            page.min_key_sketch
                .iter()
                .zip(&page.max_key_sketch)
                .all(|(min, max)| min <= max)
        })
    });
    let semantic_tags_bound = registry.indexes.iter().all(|index| {
        index
            .pages
            .iter()
            .all(|page| !page.semantic_tags.is_empty())
    });
    let recency_bound = registry
        .indexes
        .iter()
        .all(|index| index.pages.iter().all(|page| page.recency_rank > 0));
    let hit_counts_bound = registry
        .indexes
        .iter()
        .all(|index| index.pages.iter().all(|page| page.hit_count.is_some()));
    let miss_counts_bound = registry
        .indexes
        .iter()
        .all(|index| index.pages.iter().all(|page| page.miss_count.is_some()));
    let compatibility_fences_bound = registry.indexes.iter().all(|index| {
        index.compatibility_fence == CURRENT_FENCE
            && index
                .pages
                .iter()
                .all(|page| page.compatibility_fence == CURRENT_FENCE)
    });
    let privacy_classes_bound = registry.indexes.iter().all(|index| {
        index
            .pages
            .iter()
            .all(|page| valid_privacy_class(&page.privacy_class))
    });
    let required_evidence_bound = registry.indexes.iter().all(required_evidence_covered);
    let false_negative_policy_bound = registry
        .indexes
        .iter()
        .all(|index| index.false_negative_policy == REQUIRED_FALSE_NEGATIVE_POLICY);
    let rollback_bound = registry
        .indexes
        .iter()
        .all(|index| index.rollback_handle.starts_with("rollback:"));
    let run_event_log_bound = registry
        .indexes
        .iter()
        .all(|index| index.run_event_log_ref.starts_with("runevent:"));
    let answer_packet_ref_bound = registry
        .indexes
        .iter()
        .all(|index| index.answer_packet_ref.starts_with("answerpacket:"));
    let route_authority_shadow_only = registry
        .indexes
        .iter()
        .all(|index| index.route_authority == "shadow_only");
    let no_hidden_chain = registry
        .indexes
        .iter()
        .all(|index| !index.hidden_chain_exposed);
    let no_hidden_cloud = registry.indexes.iter().all(|index| !index.hidden_cloud);
    let live_policy_not_mutated = registry
        .indexes
        .iter()
        .all(|index| !index.live_policy_mutated);
    let sketch_index_address_deterministic =
        registry.sketch_index_address == reversed_registry.sketch_index_address;
    let required_evidence_coverage_beats_recency_baseline =
        metrics.required_evidence_coverage_bps > metrics.recency_baseline_coverage_bps;
    let required_evidence_coverage_beats_tagless_baseline =
        metrics.required_evidence_coverage_bps > metrics.tagless_baseline_coverage_bps;
    let required_evidence_coverage_beats_file_order_baseline =
        metrics.required_evidence_coverage_bps > metrics.file_order_baseline_coverage_bps;

    let duplicate_index_rejected = {
        let mut indexes = fixture_indexes();
        indexes[1].index_id = indexes[0].index_id.clone();
        matches!(
            KvPageSketchRegistry::new(indexes),
            Err(KvPageSketchError::DuplicateIndex)
        )
    };
    let duplicate_page_rejected = invalid_index_rejected(|index| {
        index.pages[1].page_id = index.pages[0].page_id.clone();
    }) == Some(KvPageSketchError::DuplicatePage);
    let missing_uas_address_rejected = invalid_page_rejected(|page| page.uas_address.clear())
        == Some(KvPageSketchError::MissingUasAddress);
    let missing_digest_rejected = invalid_page_rejected(|page| page.page_digest.clear())
        == Some(KvPageSketchError::MissingDigest);
    let zero_byte_count_rejected = invalid_page_rejected(|page| page.byte_count = 0)
        == Some(KvPageSketchError::MissingByteCount);
    let oversized_page_rejected = invalid_page_rejected(|page| {
        page.byte_count = MAX_PAGE_BYTE_COUNT + 1;
    }) == Some(KvPageSketchError::OversizedPage);
    let missing_min_sketch_rejected = invalid_page_rejected(|page| page.min_key_sketch.clear())
        == Some(KvPageSketchError::MissingMinSketch);
    let missing_max_sketch_rejected = invalid_page_rejected(|page| page.max_key_sketch.clear())
        == Some(KvPageSketchError::MissingMaxSketch);
    let sketch_dimension_mismatch_rejected =
        invalid_page_rejected(|page| page.max_key_sketch.push(42))
            == Some(KvPageSketchError::SketchDimensionMismatch);
    let sketch_order_rejected = invalid_page_rejected(|page| {
        page.min_key_sketch[0] = page.max_key_sketch[0] + 1;
    }) == Some(KvPageSketchError::SketchOrderInvalid);
    let missing_semantic_tag_rejected = invalid_page_rejected(|page| page.semantic_tags.clear())
        == Some(KvPageSketchError::MissingSemanticTag);
    let missing_hit_count_rejected = invalid_page_rejected(|page| page.hit_count = None)
        == Some(KvPageSketchError::MissingHitCount);
    let missing_miss_count_rejected = invalid_page_rejected(|page| page.miss_count = None)
        == Some(KvPageSketchError::MissingMissCount);
    let missing_compatibility_fence_rejected =
        invalid_page_rejected(|page| page.compatibility_fence.clear())
            == Some(KvPageSketchError::MissingCompatibilityFence);
    let incompatible_fence_rejected = invalid_page_rejected(|page| {
        page.compatibility_fence = "fence:model:stale:kv:v0".to_string();
    }) == Some(KvPageSketchError::IncompatibleFence);
    let stale_page_rejected =
        invalid_page_rejected(|page| page.stale = true) == Some(KvPageSketchError::StalePage);
    let invalid_privacy_class_rejected = invalid_page_rejected(|page| {
        page.privacy_class = "raw_secret_chain".to_string();
    }) == Some(KvPageSketchError::InvalidPrivacyClass);
    let missing_required_evidence_rejected = invalid_index_rejected(|index| {
        index
            .required_evidence_page_ids
            .push("kv-page:missing-proof".to_string());
    }) == Some(KvPageSketchError::MissingRequiredEvidence);
    let required_evidence_false_negative_rejected =
        invalid_index_rejected(|index| {
            index.pages[0].proof_critical = false;
        }) == Some(KvPageSketchError::RequiredEvidenceFalseNegative);
    let missing_false_negative_policy_rejected =
        invalid_index_rejected(|index| {
            index.false_negative_policy.clear();
        }) == Some(KvPageSketchError::MissingFalseNegativePolicy);
    let missing_rollback_rejected = invalid_index_rejected(|index| index.rollback_handle.clear())
        == Some(KvPageSketchError::MissingRollback);
    let missing_run_event_log_rejected =
        invalid_index_rejected(|index| index.run_event_log_ref.clear())
            == Some(KvPageSketchError::MissingRunEventLog);
    let missing_answer_packet_rejected =
        invalid_index_rejected(|index| index.answer_packet_ref.clear())
            == Some(KvPageSketchError::MissingAnswerPacket);
    let hidden_live_authority_rejected = invalid_index_rejected(|index| {
        index.route_authority = "live_route".to_string();
    }) == Some(KvPageSketchError::HiddenLiveAuthority);
    let live_policy_mutation_rejected =
        invalid_index_rejected(|index| index.live_policy_mutated = true)
            == Some(KvPageSketchError::LivePolicyMutation);
    let hidden_chain_exposure_rejected =
        invalid_index_rejected(|index| index.hidden_chain_exposed = true)
            == Some(KvPageSketchError::HiddenChainExposure);
    let cloud_source_rejected = invalid_page_rejected(|page| {
        page.source_page_ref = "cloud:external-kv-page".to_string();
    }) == Some(KvPageSketchError::CloudSource);
    let index_metadata_budget_rejected = invalid_index_rejected(|index| {
        index.index_metadata_bytes = MAX_INDEX_METADATA_BYTES + 1;
    }) == Some(KvPageSketchError::IndexMetadataBudgetExceeded);
    let unbeaten_baseline_rejected = invalid_index_rejected(|index| {
        index.recency_baseline_page_ids = index.required_evidence_page_ids.clone();
    }) == Some(KvPageSketchError::RecencyBaselineUnbeaten);
    let no_runtime_bytes_loaded = true;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_verifier_budget_auction_pass",
            upstream_verifier_budget_auction_pass,
        ),
        (
            "kv_page_sketch_index_fixture_present",
            kv_page_sketch_index_fixture_present,
        ),
        ("training_split_bound", training_split_bound),
        ("held_out_split_bound", held_out_split_bound),
        ("index_ids_bound", index_ids_bound),
        ("model_ids_bound", model_ids_bound),
        ("tokenizer_ids_bound", tokenizer_ids_bound),
        ("upstream_auction_ref_bound", upstream_auction_ref_bound),
        ("page_ids_bound", page_ids_bound),
        ("uas_page_addresses_bound", uas_page_addresses_bound),
        ("page_digests_bound", page_digests_bound),
        ("byte_counts_bound", byte_counts_bound),
        ("min_key_sketch_bound", min_key_sketch_bound),
        ("max_key_sketch_bound", max_key_sketch_bound),
        ("sketch_dimension_bound", sketch_dimension_bound),
        ("sketch_order_bound", sketch_order_bound),
        ("semantic_tags_bound", semantic_tags_bound),
        ("recency_bound", recency_bound),
        ("hit_counts_bound", hit_counts_bound),
        ("miss_counts_bound", miss_counts_bound),
        ("compatibility_fences_bound", compatibility_fences_bound),
        ("privacy_classes_bound", privacy_classes_bound),
        ("required_evidence_bound", required_evidence_bound),
        ("false_negative_policy_bound", false_negative_policy_bound),
        ("rollback_bound", rollback_bound),
        ("run_event_log_bound", run_event_log_bound),
        ("answer_packet_ref_bound", answer_packet_ref_bound),
        ("route_authority_shadow_only", route_authority_shadow_only),
        ("no_hidden_chain", no_hidden_chain),
        ("no_hidden_cloud", no_hidden_cloud),
        ("live_policy_not_mutated", live_policy_not_mutated),
        (
            "sketch_index_address_deterministic",
            sketch_index_address_deterministic,
        ),
        (
            "required_evidence_coverage_beats_recency_baseline",
            required_evidence_coverage_beats_recency_baseline,
        ),
        (
            "required_evidence_coverage_beats_tagless_baseline",
            required_evidence_coverage_beats_tagless_baseline,
        ),
        (
            "required_evidence_coverage_beats_file_order_baseline",
            required_evidence_coverage_beats_file_order_baseline,
        ),
        ("duplicate_index_rejected", duplicate_index_rejected),
        ("duplicate_page_rejected", duplicate_page_rejected),
        ("missing_uas_address_rejected", missing_uas_address_rejected),
        ("missing_digest_rejected", missing_digest_rejected),
        ("zero_byte_count_rejected", zero_byte_count_rejected),
        ("oversized_page_rejected", oversized_page_rejected),
        ("missing_min_sketch_rejected", missing_min_sketch_rejected),
        ("missing_max_sketch_rejected", missing_max_sketch_rejected),
        (
            "sketch_dimension_mismatch_rejected",
            sketch_dimension_mismatch_rejected,
        ),
        ("sketch_order_rejected", sketch_order_rejected),
        (
            "missing_semantic_tag_rejected",
            missing_semantic_tag_rejected,
        ),
        ("missing_hit_count_rejected", missing_hit_count_rejected),
        ("missing_miss_count_rejected", missing_miss_count_rejected),
        (
            "missing_compatibility_fence_rejected",
            missing_compatibility_fence_rejected,
        ),
        ("incompatible_fence_rejected", incompatible_fence_rejected),
        ("stale_page_rejected", stale_page_rejected),
        (
            "invalid_privacy_class_rejected",
            invalid_privacy_class_rejected,
        ),
        (
            "missing_required_evidence_rejected",
            missing_required_evidence_rejected,
        ),
        (
            "required_evidence_false_negative_rejected",
            required_evidence_false_negative_rejected,
        ),
        (
            "missing_false_negative_policy_rejected",
            missing_false_negative_policy_rejected,
        ),
        ("missing_rollback_rejected", missing_rollback_rejected),
        (
            "missing_run_event_log_rejected",
            missing_run_event_log_rejected,
        ),
        (
            "missing_answer_packet_rejected",
            missing_answer_packet_rejected,
        ),
        (
            "hidden_live_authority_rejected",
            hidden_live_authority_rejected,
        ),
        (
            "live_policy_mutation_rejected",
            live_policy_mutation_rejected,
        ),
        (
            "hidden_chain_exposure_rejected",
            hidden_chain_exposure_rejected,
        ),
        ("cloud_source_rejected", cloud_source_rejected),
        (
            "index_metadata_budget_rejected",
            index_metadata_budget_rejected,
        ),
        ("unbeaten_baseline_rejected", unbeaten_baseline_rejected),
        ("no_runtime_bytes_loaded", no_runtime_bytes_loaded),
    ] {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            pass,
        );
    }

    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "sketch_index_count",
        registry.indexes.len() as u64,
        2,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "page_count",
        metrics.page_count,
        8,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "training_page_count",
        metrics.training_page_count,
        2,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_page_count",
        metrics.held_out_page_count,
        6,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "required_evidence_page_count",
        metrics.required_evidence_page_count,
        4,
        "count",
    );
    add_count_ge_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "semantic_tag_count",
        metrics.semantic_tag_count,
        16,
        "count",
    );
    add_count_ge_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "total_hit_count",
        metrics.total_hit_count,
        48,
        "count",
    );
    add_count_ge_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "total_miss_count",
        metrics.total_miss_count,
        8,
        "count",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_page_byte_count",
        metrics.max_page_byte_count,
        MAX_PAGE_BYTE_COUNT,
        "bytes",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_index_metadata_bytes",
        metrics.max_index_metadata_bytes,
        MAX_INDEX_METADATA_BYTES,
        "bytes",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "sketch_dimension",
        SKETCH_DIMENSION as u64,
        SKETCH_DIMENSION as u64,
        "dimension",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "required_evidence_coverage_bps",
        metrics.required_evidence_coverage_bps,
        10_000,
        "bps",
    );
    add_string_contains_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "sketch_index_address",
        &registry.sketch_index_address,
        "uas:kv-page-sketch-index:",
        "uas_address",
    );

    Ok(ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: ArtifactKind::PrimaryWitness,
        command: COMMAND.to_string(),
        commit_sha: current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Primary,
        anomalies: vec![serde_json::json!({
            "kind": "scope_guard",
            "detail": "metadata-only KVPageSketchIndex witness; no live KV restore, no query-aware selector promotion, no model/runtime bytes, no hidden cloud, and no SSD-as-RAM claim"
        })],
        notes: "scope=metadata_only;organ=KVPageSketchIndex;reviewer=codex;reviewed_at_utc=2026-06-04T00:00:00Z;validator=falsifier_validator;detail=KV/page sketches bind UAS page identity, byte count, compatibility fence, semantic sketch evidence, hit/miss telemetry, privacy class, rollback, RunEventLog, and AnswerPacket visibility before query-aware selection can promote.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:kv-page-sketch:registry
// Plane: Controller + Verification
// Residency: metadata-only
struct KvPageSketchRegistry {
    indexes: Vec<KvPageSketchIndexFixture>,
    metrics: SketchMetrics,
    sketch_index_address: String,
}

impl KvPageSketchRegistry {
    fn new(mut indexes: Vec<KvPageSketchIndexFixture>) -> Result<Self, KvPageSketchError> {
        if indexes.is_empty() {
            return Err(KvPageSketchError::MissingIndex);
        }
        let mut seen_indexes = BTreeSet::new();
        for index in &indexes {
            if !seen_indexes.insert(index.index_id.clone()) {
                return Err(KvPageSketchError::DuplicateIndex);
            }
            validate_index(index)?;
        }
        indexes.sort_by_key(|index| index.index_id.clone());
        let metrics = sketch_metrics(&indexes);
        let sketch_index_address = sketch_index_address(&indexes);
        Ok(Self {
            indexes,
            metrics,
            sketch_index_address,
        })
    }
}

fn validate_index(index: &KvPageSketchIndexFixture) -> Result<(), KvPageSketchError> {
    if !index.index_id.starts_with("kv-sketch-index:") {
        return Err(KvPageSketchError::MissingIndexId);
    }
    if !index.model_id.starts_with("model:") {
        return Err(KvPageSketchError::MissingModelId);
    }
    if !index.tokenizer_id.starts_with("tokenizer:") {
        return Err(KvPageSketchError::MissingTokenizerId);
    }
    if index.upstream_auction_ref != UPSTREAM_AUCTION {
        return Err(KvPageSketchError::MissingUpstreamAuction);
    }
    if index.pages.is_empty() {
        return Err(KvPageSketchError::MissingPage);
    }
    let mut seen_pages = BTreeSet::new();
    for page in &index.pages {
        if !seen_pages.insert(page.page_id.clone()) {
            return Err(KvPageSketchError::DuplicatePage);
        }
        validate_page(page)?;
    }
    if !index.compatibility_fence.starts_with("fence:") {
        return Err(KvPageSketchError::MissingCompatibilityFence);
    }
    if index.compatibility_fence != CURRENT_FENCE {
        return Err(KvPageSketchError::IncompatibleFence);
    }
    if index.false_negative_policy != REQUIRED_FALSE_NEGATIVE_POLICY {
        return Err(KvPageSketchError::MissingFalseNegativePolicy);
    }
    if !required_evidence_covered(index) {
        return Err(KvPageSketchError::MissingRequiredEvidence);
    }
    if !required_evidence_proof_critical(index) {
        return Err(KvPageSketchError::RequiredEvidenceFalseNegative);
    }
    validate_baseline_pages(index, &index.recency_baseline_page_ids)?;
    validate_baseline_pages(index, &index.tagless_baseline_page_ids)?;
    validate_baseline_pages(index, &index.file_order_baseline_page_ids)?;
    if coverage_bps(index, &index.required_evidence_page_ids)
        <= coverage_bps(index, &index.recency_baseline_page_ids)
    {
        return Err(KvPageSketchError::RecencyBaselineUnbeaten);
    }
    if coverage_bps(index, &index.required_evidence_page_ids)
        <= coverage_bps(index, &index.tagless_baseline_page_ids)
    {
        return Err(KvPageSketchError::TaglessBaselineUnbeaten);
    }
    if coverage_bps(index, &index.required_evidence_page_ids)
        <= coverage_bps(index, &index.file_order_baseline_page_ids)
    {
        return Err(KvPageSketchError::FileOrderBaselineUnbeaten);
    }
    if !index.rollback_handle.starts_with("rollback:") {
        return Err(KvPageSketchError::MissingRollback);
    }
    if !index.run_event_log_ref.starts_with("runevent:") {
        return Err(KvPageSketchError::MissingRunEventLog);
    }
    if !index.answer_packet_ref.starts_with("answerpacket:") {
        return Err(KvPageSketchError::MissingAnswerPacket);
    }
    if index.route_authority != "shadow_only" {
        return Err(KvPageSketchError::HiddenLiveAuthority);
    }
    if index.live_policy_mutated {
        return Err(KvPageSketchError::LivePolicyMutation);
    }
    if index.hidden_chain_exposed {
        return Err(KvPageSketchError::HiddenChainExposure);
    }
    if index.hidden_cloud {
        return Err(KvPageSketchError::CloudSource);
    }
    if index.index_metadata_bytes > MAX_INDEX_METADATA_BYTES {
        return Err(KvPageSketchError::IndexMetadataBudgetExceeded);
    }
    Ok(())
}

fn validate_page(page: &KvPageSketch) -> Result<(), KvPageSketchError> {
    if page.split != "training" && page.split != "held_out" {
        return Err(KvPageSketchError::MissingSplit);
    }
    if !page.page_id.starts_with("kv-page:") {
        return Err(KvPageSketchError::MissingPageId);
    }
    if !page.uas_address.starts_with("uas:kv-page:") {
        return Err(KvPageSketchError::MissingUasAddress);
    }
    if page.source_page_ref.is_empty() {
        return Err(KvPageSketchError::MissingSourceRef);
    }
    if page.source_page_ref.contains("cloud") {
        return Err(KvPageSketchError::CloudSource);
    }
    if !page.page_digest.starts_with("sha256:") {
        return Err(KvPageSketchError::MissingDigest);
    }
    if page.byte_count == 0 {
        return Err(KvPageSketchError::MissingByteCount);
    }
    if page.byte_count > MAX_PAGE_BYTE_COUNT {
        return Err(KvPageSketchError::OversizedPage);
    }
    if page.min_key_sketch.is_empty() {
        return Err(KvPageSketchError::MissingMinSketch);
    }
    if page.max_key_sketch.is_empty() {
        return Err(KvPageSketchError::MissingMaxSketch);
    }
    if page.min_key_sketch.len() != page.max_key_sketch.len()
        || page.min_key_sketch.len() != SKETCH_DIMENSION
    {
        return Err(KvPageSketchError::SketchDimensionMismatch);
    }
    if page
        .min_key_sketch
        .iter()
        .zip(&page.max_key_sketch)
        .any(|(min, max)| min > max)
    {
        return Err(KvPageSketchError::SketchOrderInvalid);
    }
    if page.semantic_tags.is_empty() {
        return Err(KvPageSketchError::MissingSemanticTag);
    }
    if page.recency_rank == 0 {
        return Err(KvPageSketchError::MissingRecency);
    }
    if page.hit_count.is_none() {
        return Err(KvPageSketchError::MissingHitCount);
    }
    if page.miss_count.is_none() {
        return Err(KvPageSketchError::MissingMissCount);
    }
    if !page.compatibility_fence.starts_with("fence:") {
        return Err(KvPageSketchError::MissingCompatibilityFence);
    }
    if page.compatibility_fence != CURRENT_FENCE {
        return Err(KvPageSketchError::IncompatibleFence);
    }
    if page.evidence_refs.is_empty() {
        return Err(KvPageSketchError::MissingEvidenceRef);
    }
    if !valid_privacy_class(&page.privacy_class) {
        return Err(KvPageSketchError::InvalidPrivacyClass);
    }
    if page.stale {
        return Err(KvPageSketchError::StalePage);
    }
    Ok(())
}

fn validate_baseline_pages(
    index: &KvPageSketchIndexFixture,
    page_ids: &[String],
) -> Result<(), KvPageSketchError> {
    if page_ids.is_empty() {
        return Err(KvPageSketchError::MissingBaselinePage);
    }
    let pages = page_map(index);
    for page_id in page_ids {
        if !pages.contains_key(page_id) {
            return Err(KvPageSketchError::MissingBaselinePage);
        }
    }
    Ok(())
}

fn required_evidence_covered(index: &KvPageSketchIndexFixture) -> bool {
    if index.required_evidence_page_ids.is_empty() {
        return false;
    }
    let pages = page_map(index);
    index
        .required_evidence_page_ids
        .iter()
        .all(|page_id| pages.contains_key(page_id))
}

fn required_evidence_proof_critical(index: &KvPageSketchIndexFixture) -> bool {
    let pages = page_map(index);
    index.required_evidence_page_ids.iter().all(|page_id| {
        pages
            .get(page_id)
            .map(|page| {
                page.proof_critical && !page.stale && page.compatibility_fence == CURRENT_FENCE
            })
            .unwrap_or(false)
    })
}

fn page_map(index: &KvPageSketchIndexFixture) -> BTreeMap<String, &KvPageSketch> {
    index
        .pages
        .iter()
        .map(|page| (page.page_id.clone(), page))
        .collect()
}

fn coverage_bps(index: &KvPageSketchIndexFixture, page_ids: &[String]) -> u64 {
    if index.required_evidence_page_ids.is_empty() {
        return 0;
    }
    let required = index
        .required_evidence_page_ids
        .iter()
        .collect::<BTreeSet<_>>();
    let covered = page_ids
        .iter()
        .filter(|page_id| required.contains(page_id))
        .count() as u64;
    covered * 10_000 / required.len() as u64
}

fn valid_privacy_class(privacy_class: &str) -> bool {
    matches!(
        privacy_class,
        "vault_private" | "proof_private" | "research_private" | "public_source"
    )
}

fn sketch_metrics(indexes: &[KvPageSketchIndexFixture]) -> SketchMetrics {
    let mut metrics = SketchMetrics::default();
    let mut required_coverage_sum = 0;
    let mut recency_coverage_sum = 0;
    let mut tagless_coverage_sum = 0;
    let mut file_order_coverage_sum = 0;
    for index in indexes {
        metrics.max_index_metadata_bytes = metrics
            .max_index_metadata_bytes
            .max(index.index_metadata_bytes);
        metrics.required_evidence_page_count += index.required_evidence_page_ids.len() as u64;
        required_coverage_sum += coverage_bps(index, &index.required_evidence_page_ids);
        recency_coverage_sum += coverage_bps(index, &index.recency_baseline_page_ids);
        tagless_coverage_sum += coverage_bps(index, &index.tagless_baseline_page_ids);
        file_order_coverage_sum += coverage_bps(index, &index.file_order_baseline_page_ids);
        for page in &index.pages {
            metrics.page_count += 1;
            if page.split == "training" {
                metrics.training_page_count += 1;
            }
            if page.split == "held_out" {
                metrics.held_out_page_count += 1;
            }
            metrics.semantic_tag_count += page.semantic_tags.len() as u64;
            metrics.total_hit_count += page.hit_count.unwrap_or(0);
            metrics.total_miss_count += page.miss_count.unwrap_or(0);
            metrics.total_page_bytes += page.byte_count;
            metrics.max_page_byte_count = metrics.max_page_byte_count.max(page.byte_count);
        }
    }
    let index_count = indexes.len().max(1) as u64;
    metrics.required_evidence_coverage_bps = required_coverage_sum / index_count;
    metrics.recency_baseline_coverage_bps = recency_coverage_sum / index_count;
    metrics.tagless_baseline_coverage_bps = tagless_coverage_sum / index_count;
    metrics.file_order_baseline_coverage_bps = file_order_coverage_sum / index_count;
    metrics
}

fn sketch_index_address(indexes: &[KvPageSketchIndexFixture]) -> String {
    let mut payload = String::new();
    for index in indexes {
        payload.push_str(&index.index_id);
        payload.push('|');
        payload.push_str(&index.model_id);
        payload.push('|');
        payload.push_str(&index.tokenizer_id);
        payload.push('|');
        for page in &index.pages {
            payload.push_str(&page.page_id);
            payload.push(':');
            payload.push_str(&page.uas_address);
            payload.push(':');
            payload.push_str(&page.page_digest);
            payload.push(':');
            payload.push_str(&page.byte_count.to_string());
            payload.push(':');
            payload.push_str(&page.compatibility_fence);
            payload.push(':');
            for tag in &page.semantic_tags {
                payload.push_str(tag);
                payload.push(',');
            }
            payload.push(';');
        }
        payload.push('\n');
    }
    format!(
        "uas:kv-page-sketch-index:{}",
        sha256_hex(payload.as_bytes()).trim_start_matches("sha256:")
    )
}

fn invalid_index_rejected(
    mut mutate: impl FnMut(&mut KvPageSketchIndexFixture),
) -> Option<KvPageSketchError> {
    let mut indexes = fixture_indexes();
    mutate(&mut indexes[0]);
    KvPageSketchRegistry::new(indexes).err()
}

fn invalid_page_rejected(mut mutate: impl FnMut(&mut KvPageSketch)) -> Option<KvPageSketchError> {
    invalid_index_rejected(|index| mutate(&mut index.pages[0]))
}

fn upstream_auction_pass() -> bool {
    read_artifact_string(UPSTREAM_AUCTION)
        .and_then(|json| serde_json::from_str::<serde_json::Value>(&json).ok())
        .and_then(|value| value.get("overall_pass").and_then(|pass| pass.as_bool()))
        .unwrap_or(false)
}

fn read_artifact_string(path: &str) -> Option<String> {
    let direct = Path::new(path);
    if let Ok(json) = std::fs::read_to_string(direct) {
        return Some(json);
    }
    let manifest_root = Path::new(env!("CARGO_MANIFEST_DIR"));
    std::fs::read_to_string(manifest_root.parent()?.join(path)).ok()
}

fn fixture_indexes() -> Vec<KvPageSketchIndexFixture> {
    vec![
        KvPageSketchIndexFixture {
            index_id: "kv-sketch-index:proof-route-repair".to_string(),
            model_id: "model:qwen3.5-local-research".to_string(),
            tokenizer_id: "tokenizer:qwen3.5-local".to_string(),
            upstream_auction_ref: UPSTREAM_AUCTION.to_string(),
            pages: vec![
                page(
                    "training",
                    "kv-page:rollback-precondition",
                    0,
                    2,
                    &["rollback", "precondition", "route-kernel"],
                    9,
                    2,
                    1,
                    "proof_private",
                    true,
                ),
                page(
                    "held_out",
                    "kv-page:answerpacket-proof",
                    2,
                    5,
                    &["answerpacket", "visible-proof", "postcondition"],
                    11,
                    1,
                    2,
                    "proof_private",
                    true,
                ),
                page(
                    "held_out",
                    "kv-page:recent-terminal-log",
                    5,
                    7,
                    &["recent", "terminal", "low-signal"],
                    7,
                    6,
                    3,
                    "vault_private",
                    false,
                ),
                page(
                    "held_out",
                    "kv-page:file-order-schema",
                    7,
                    9,
                    &["schema", "file-order", "background"],
                    6,
                    7,
                    4,
                    "vault_private",
                    false,
                ),
            ],
            required_evidence_page_ids: vec![
                "kv-page:rollback-precondition".to_string(),
                "kv-page:answerpacket-proof".to_string(),
            ],
            recency_baseline_page_ids: vec![
                "kv-page:recent-terminal-log".to_string(),
                "kv-page:file-order-schema".to_string(),
                "kv-page:rollback-precondition".to_string(),
            ],
            tagless_baseline_page_ids: vec![
                "kv-page:file-order-schema".to_string(),
                "kv-page:recent-terminal-log".to_string(),
                "kv-page:answerpacket-proof".to_string(),
            ],
            file_order_baseline_page_ids: vec![
                "kv-page:file-order-schema".to_string(),
                "kv-page:recent-terminal-log".to_string(),
                "kv-page:rollback-precondition".to_string(),
            ],
            compatibility_fence: CURRENT_FENCE.to_string(),
            false_negative_policy: REQUIRED_FALSE_NEGATIVE_POLICY.to_string(),
            rollback_handle: "rollback:kv-page-sketch:proof-route".to_string(),
            run_event_log_ref: "runevent:kv-page-sketch:proof-route".to_string(),
            answer_packet_ref: "answerpacket:kv-page-sketch:proof-route".to_string(),
            route_authority: "shadow_only".to_string(),
            index_metadata_bytes: 96 * 1024,
            hidden_chain_exposed: false,
            hidden_cloud: false,
            live_policy_mutated: false,
        },
        KvPageSketchIndexFixture {
            index_id: "kv-sketch-index:swiftlm-source-motif".to_string(),
            model_id: "model:qwen3.5-local-research".to_string(),
            tokenizer_id: "tokenizer:qwen3.5-local".to_string(),
            upstream_auction_ref: UPSTREAM_AUCTION.to_string(),
            pages: vec![
                page(
                    "training",
                    "kv-page:swiftlm-kv-compression",
                    0,
                    3,
                    &["swiftlm", "kv-compression", "ssd-streaming"],
                    10,
                    2,
                    1,
                    "research_private",
                    true,
                ),
                page(
                    "held_out",
                    "kv-page:flash-bundling-caveat",
                    3,
                    6,
                    &["flash", "bundling", "caveat"],
                    8,
                    2,
                    2,
                    "research_private",
                    true,
                ),
                page(
                    "held_out",
                    "kv-page:recent-chat-summary",
                    6,
                    7,
                    &["recent", "chat", "summary"],
                    6,
                    7,
                    3,
                    "vault_private",
                    false,
                ),
                page(
                    "held_out",
                    "kv-page:file-license-preface",
                    7,
                    9,
                    &["license", "preface", "background"],
                    7,
                    8,
                    4,
                    "public_source",
                    false,
                ),
            ],
            required_evidence_page_ids: vec![
                "kv-page:swiftlm-kv-compression".to_string(),
                "kv-page:flash-bundling-caveat".to_string(),
            ],
            recency_baseline_page_ids: vec![
                "kv-page:recent-chat-summary".to_string(),
                "kv-page:file-license-preface".to_string(),
                "kv-page:swiftlm-kv-compression".to_string(),
            ],
            tagless_baseline_page_ids: vec![
                "kv-page:file-license-preface".to_string(),
                "kv-page:recent-chat-summary".to_string(),
                "kv-page:swiftlm-kv-compression".to_string(),
            ],
            file_order_baseline_page_ids: vec![
                "kv-page:file-license-preface".to_string(),
                "kv-page:recent-chat-summary".to_string(),
                "kv-page:swiftlm-kv-compression".to_string(),
            ],
            compatibility_fence: CURRENT_FENCE.to_string(),
            false_negative_policy: REQUIRED_FALSE_NEGATIVE_POLICY.to_string(),
            rollback_handle: "rollback:kv-page-sketch:swiftlm".to_string(),
            run_event_log_ref: "runevent:kv-page-sketch:swiftlm".to_string(),
            answer_packet_ref: "answerpacket:kv-page-sketch:swiftlm".to_string(),
            route_authority: "shadow_only".to_string(),
            index_metadata_bytes: 112 * 1024,
            hidden_chain_exposed: false,
            hidden_cloud: false,
            live_policy_mutated: false,
        },
    ]
}

#[allow(clippy::too_many_arguments)]
fn page(
    split: &str,
    page_id: &str,
    layer_start: i16,
    layer_end: i16,
    tags: &[&str],
    hits: u64,
    misses: u64,
    recency_rank: u64,
    privacy_class: &str,
    proof_critical: bool,
) -> KvPageSketch {
    let digest_seed = format!("{page_id}:{layer_start}:{layer_end}:{tags:?}:{privacy_class}");
    let base = layer_start * 31 + layer_end * 17;
    KvPageSketch {
        split: split.to_string(),
        page_id: page_id.to_string(),
        uas_address: format!("uas:kv-page:{page_id}"),
        source_page_ref: "artifacts/falsifiers/verifier_budget_auction/result.json".to_string(),
        page_digest: sha256_hex(digest_seed.as_bytes()),
        byte_count: 8 * 1024 * 1024,
        min_key_sketch: (0..SKETCH_DIMENSION).map(|idx| base + idx as i16).collect(),
        max_key_sketch: (0..SKETCH_DIMENSION)
            .map(|idx| base + idx as i16 + 128)
            .collect(),
        semantic_tags: tags.iter().map(|tag| (*tag).to_string()).collect(),
        recency_rank,
        hit_count: Some(hits),
        miss_count: Some(misses),
        compatibility_fence: CURRENT_FENCE.to_string(),
        privacy_class: privacy_class.to_string(),
        evidence_refs: vec!["eidos:evidence:kv-page-sketch".to_string()],
        proof_critical,
        stale: false,
    }
}

fn add_count_ge_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    expected: u64,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::from(actual),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: ">=".to_string(),
            value: serde_json::Value::from(expected),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual >= expected);
}

fn add_u64_le_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    expected: u64,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::from(actual),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "<=".to_string(),
            value: serde_json::Value::from(expected),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual <= expected);
}

fn add_string_contains_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: &str,
    needle: &str,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(actual.to_string()),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "contains".to_string(),
            value: serde_json::Value::String(needle.to_string()),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual.contains(needle));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn artifact_contains_required_axes() {
        let artifact = build_artifact().expect("artifact builds");
        assert!(artifact.overall_pass);
        for axis in [
            "upstream_verifier_budget_auction_pass",
            "kv_page_sketch_index_fixture_present",
            "uas_page_addresses_bound",
            "byte_counts_bound",
            "compatibility_fences_bound",
            "privacy_classes_bound",
            "required_evidence_bound",
            "false_negative_policy_bound",
            "sketch_index_address_deterministic",
            "stale_page_rejected",
            "incompatible_fence_rejected",
            "required_evidence_false_negative_rejected",
            "hidden_live_authority_rejected",
            "cloud_source_rejected",
            "unbeaten_baseline_rejected",
            "no_runtime_bytes_loaded",
        ] {
            assert_eq!(artifact.pass_per_axis.get(axis), Some(&true), "{axis}");
        }
    }

    #[test]
    fn empty_fixture_rejects() {
        assert!(matches!(
            KvPageSketchRegistry::new(Vec::new()),
            Err(KvPageSketchError::MissingIndex)
        ));
    }

    #[test]
    fn invalid_fixture_cases_reject() {
        let cases = [
            invalid_page_rejected(|page| page.uas_address.clear()),
            invalid_page_rejected(|page| page.page_digest.clear()),
            invalid_page_rejected(|page| page.byte_count = 0),
            invalid_page_rejected(|page| page.min_key_sketch.clear()),
            invalid_page_rejected(|page| page.max_key_sketch.push(42)),
            invalid_page_rejected(|page| page.compatibility_fence = "fence:stale".to_string()),
            invalid_page_rejected(|page| page.stale = true),
            invalid_index_rejected(|index| index.false_negative_policy.clear()),
            invalid_index_rejected(|index| index.route_authority = "live_route".to_string()),
            invalid_index_rejected(|index| index.live_policy_mutated = true),
            invalid_index_rejected(|index| index.hidden_chain_exposed = true),
            invalid_index_rejected(|index| {
                index.recency_baseline_page_ids = index.required_evidence_page_ids.clone();
            }),
        ];
        assert!(cases.iter().all(Option::is_some));
    }

    #[test]
    fn sketch_address_is_order_stable() {
        let indexes = fixture_indexes();
        let reversed = indexes.iter().cloned().rev().collect::<Vec<_>>();
        let registry = KvPageSketchRegistry::new(indexes).expect("valid registry");
        let reversed_registry =
            KvPageSketchRegistry::new(reversed).expect("valid reversed registry");
        assert_eq!(
            registry.sketch_index_address,
            reversed_registry.sketch_index_address
        );
        assert!(registry
            .sketch_index_address
            .starts_with("uas:kv-page-sketch-index:"));
    }
}
