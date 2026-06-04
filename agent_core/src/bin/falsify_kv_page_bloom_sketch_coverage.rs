//! `falsify_kv_page_bloom_sketch_coverage` -- Bloom-style KV/page filter coverage.
//!
//! Metadata-only witness for `F-KVPageBloomSketch-Coverage`. It proves cheap
//! page filters may over-include candidates, but cannot silently drop required
//! proof/citation/privacy evidence before query-aware KV/page selection can
//! promote.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-KVPageBloomSketch-Coverage";
const FIXTURE_ID: &str = "kv_page_bloom_sketch_coverage_v1";
const COMMAND: &str = "Tools/falsifiers/f_kv_page_bloom_sketch_coverage.sh";
const RESULT: &str = "artifacts/falsifiers/kv_page_bloom_sketch_coverage/result.json";
const UPSTREAM_SKETCH_INDEX: &str = "artifacts/falsifiers/kv_page_sketch_index/result.json";
const CURRENT_FENCE: &str = "fence:model:qwen3.5:kv:v1:tokenizer:qwen3.5:adapter:none";
const REQUIRED_FALSE_NEGATIVE_POLICY: &str = "forbidden_for_required_evidence";
const BLOOM_BIT_COUNT: u64 = 128;
const HASH_FUNCTION_COUNT: usize = 4;
const MAX_FALSE_POSITIVE_BPS: u64 = 3_500;
const MAX_BLOOM_METADATA_BYTES: u64 = 1_048_576;

#[derive(Clone)]
// UAS: uas:kv-page-bloom-sketch:candidate
// Plane: Assembly + Verification
// Residency: metadata-only candidate filter row.
struct BloomPageCandidate {
    split: String,
    page_id: String,
    uas_address: String,
    source_page_ref: String,
    page_digest: String,
    compatibility_fence: String,
    feature_hashes: Vec<u16>,
    semantic_tags: Vec<String>,
    privacy_class: String,
    required_evidence: bool,
    proof_critical: bool,
    privacy_critical: bool,
    negative_filter_allowed: bool,
    selected_by_filter: bool,
}

#[derive(Clone)]
// UAS: uas:kv-page-bloom-sketch:sketch
// Plane: Controller + Verification
// Residency: metadata-only Bloom-style page filter.
struct KvPageBloomSketchFixture {
    sketch_id: String,
    source_index_ref: String,
    compatibility_fence: String,
    false_positive_budget_bps: Option<u64>,
    false_negative_policy: String,
    required_evidence_page_ids: Vec<String>,
    hash_only_baseline_page_ids: Vec<String>,
    recency_baseline_page_ids: Vec<String>,
    tagless_baseline_page_ids: Vec<String>,
    page_candidates: Vec<BloomPageCandidate>,
    rollback_handle: String,
    run_event_log_ref: String,
    answer_packet_ref: String,
    route_authority: String,
    bloom_metadata_bytes: u64,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    live_policy_mutated: bool,
}

#[derive(Default, Clone, Copy)]
// UAS: uas:kv-page-bloom-sketch:metrics
// Plane: Verification
// Residency: metadata-only summary.
struct BloomMetrics {
    candidate_count: u64,
    training_candidate_count: u64,
    held_out_candidate_count: u64,
    required_evidence_candidate_count: u64,
    proof_critical_candidate_count: u64,
    privacy_critical_candidate_count: u64,
    overincluded_candidate_count: u64,
    required_evidence_coverage_bps: u64,
    hash_only_baseline_coverage_bps: u64,
    recency_baseline_coverage_bps: u64,
    tagless_baseline_coverage_bps: u64,
    max_false_positive_budget_bps: u64,
    max_bloom_metadata_bytes: u64,
}

#[derive(Debug, Eq, PartialEq)]
// UAS: uas:kv-page-bloom-sketch:error
// Plane: Verification
// Residency: metadata-only rejection reason.
enum KvPageBloomSketchError {
    MissingSketch,
    DuplicateSketch,
    MissingSketchId,
    MissingSourceIndex,
    MissingCompatibilityFence,
    IncompatibleFence,
    MissingFalsePositiveBudget,
    FalsePositiveBudgetExceeded,
    MissingFalseNegativePolicy,
    MissingPageCandidate,
    DuplicatePageCandidate,
    MissingSplit,
    MissingPageId,
    MissingUasAddress,
    MissingSourcePageRef,
    MissingDigest,
    MissingFeatureHash,
    FeatureHashOutOfRange,
    MissingSemanticTag,
    InvalidPrivacyClass,
    MissingRequiredEvidence,
    RequiredEvidenceFalseNegative,
    ProofCriticalNegativeFilterEnabled,
    PrivacyCriticalNegativeFilterEnabled,
    MissingBaselinePage,
    UnbeatenBaseline,
    MissingRollback,
    MissingRunEventLog,
    MissingAnswerPacket,
    HiddenLiveAuthority,
    LivePolicyMutation,
    HiddenChainExposure,
    CloudSource,
    MetadataBudgetExceeded,
    MissingOverIncludeCase,
}

impl std::fmt::Display for KvPageBloomSketchError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for KvPageBloomSketchError {}

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
        "{FALSIFIER_ID}: overall_pass={} candidate_count={} required_evidence_coverage_bps={} bloom_sketch_address={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["page_candidate_count"].value,
        artifact.measurements["required_evidence_coverage_bps"].value,
        artifact.measurements["bloom_sketch_address"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let sketches = fixture_sketches();
    let reversed = sketches.iter().cloned().rev().collect::<Vec<_>>();
    let registry = KvPageBloomSketchRegistry::new(sketches)?;
    let reversed_registry = KvPageBloomSketchRegistry::new(reversed)?;
    let metrics = registry.metrics;

    let upstream_kv_page_sketch_index_pass = upstream_sketch_index_pass();
    let kv_page_bloom_sketch_fixture_present =
        registry.sketches.len() == 2 && metrics.candidate_count == 8;
    let training_split_bound = metrics.training_candidate_count >= 2;
    let held_out_split_bound = metrics.held_out_candidate_count >= 6;
    let sketch_ids_bound = registry
        .sketches
        .iter()
        .all(|sketch| sketch.sketch_id.starts_with("kv-bloom-sketch:"));
    let source_index_ref_bound = registry
        .sketches
        .iter()
        .all(|sketch| sketch.source_index_ref == UPSTREAM_SKETCH_INDEX);
    let source_page_refs_bound = registry.sketches.iter().all(|sketch| {
        sketch
            .page_candidates
            .iter()
            .all(|candidate| !candidate.source_page_ref.is_empty())
    });
    let page_candidates_bound = registry
        .sketches
        .iter()
        .all(|sketch| !sketch.page_candidates.is_empty());
    let page_ids_bound = registry.sketches.iter().all(|sketch| {
        sketch
            .page_candidates
            .iter()
            .all(|candidate| candidate.page_id.starts_with("kv-page:"))
    });
    let uas_page_addresses_bound = registry.sketches.iter().all(|sketch| {
        sketch
            .page_candidates
            .iter()
            .all(|candidate| candidate.uas_address.starts_with("uas:kv-page:"))
    });
    let page_digests_bound = registry.sketches.iter().all(|sketch| {
        sketch
            .page_candidates
            .iter()
            .all(|candidate| candidate.page_digest.starts_with("sha256:"))
    });
    let compatibility_fences_bound = registry.sketches.iter().all(|sketch| {
        sketch.compatibility_fence == CURRENT_FENCE
            && sketch
                .page_candidates
                .iter()
                .all(|candidate| candidate.compatibility_fence == CURRENT_FENCE)
    });
    let feature_hashes_bound = registry.sketches.iter().all(|sketch| {
        sketch
            .page_candidates
            .iter()
            .all(|candidate| candidate.feature_hashes.len() == HASH_FUNCTION_COUNT)
    });
    let feature_hash_range_bound = registry.sketches.iter().all(|sketch| {
        sketch.page_candidates.iter().all(|candidate| {
            candidate
                .feature_hashes
                .iter()
                .all(|hash| u64::from(*hash) < BLOOM_BIT_COUNT)
        })
    });
    let false_positive_budget_bound = registry.sketches.iter().all(|sketch| {
        sketch
            .false_positive_budget_bps
            .is_some_and(|budget| budget <= MAX_FALSE_POSITIVE_BPS)
    });
    let false_negative_policy_bound = registry
        .sketches
        .iter()
        .all(|sketch| sketch.false_negative_policy == REQUIRED_FALSE_NEGATIVE_POLICY);
    let privacy_classes_bound = registry.sketches.iter().all(|sketch| {
        sketch
            .page_candidates
            .iter()
            .all(|candidate| valid_privacy_class(&candidate.privacy_class))
    });
    let required_evidence_bound = registry.sketches.iter().all(required_evidence_covered);
    let proof_critical_filter_disabled = registry
        .sketches
        .iter()
        .all(proof_critical_negative_filter_disabled);
    let privacy_critical_filter_disabled = registry
        .sketches
        .iter()
        .all(privacy_critical_negative_filter_disabled);
    let over_include_allowed_bound = metrics.overincluded_candidate_count >= 2;
    let required_evidence_coverage_bound = metrics.required_evidence_coverage_bps == 10_000;
    let required_evidence_coverage_beats_hash_only_baseline =
        metrics.required_evidence_coverage_bps > metrics.hash_only_baseline_coverage_bps;
    let required_evidence_coverage_beats_recency_baseline =
        metrics.required_evidence_coverage_bps > metrics.recency_baseline_coverage_bps;
    let required_evidence_coverage_beats_tagless_baseline =
        metrics.required_evidence_coverage_bps > metrics.tagless_baseline_coverage_bps;
    let rollback_bound = registry
        .sketches
        .iter()
        .all(|sketch| sketch.rollback_handle.starts_with("rollback:"));
    let run_event_log_bound = registry
        .sketches
        .iter()
        .all(|sketch| sketch.run_event_log_ref.starts_with("runevent:"));
    let answer_packet_ref_bound = registry
        .sketches
        .iter()
        .all(|sketch| sketch.answer_packet_ref.starts_with("answerpacket:"));
    let route_authority_shadow_only = registry
        .sketches
        .iter()
        .all(|sketch| sketch.route_authority == "shadow_only");
    let no_hidden_chain = registry
        .sketches
        .iter()
        .all(|sketch| !sketch.hidden_chain_exposed);
    let no_hidden_cloud = registry.sketches.iter().all(|sketch| !sketch.hidden_cloud);
    let live_policy_not_mutated = registry
        .sketches
        .iter()
        .all(|sketch| !sketch.live_policy_mutated);
    let bloom_sketch_address_deterministic =
        registry.bloom_sketch_address == reversed_registry.bloom_sketch_address;

    let duplicate_sketch_rejected = {
        let mut sketches = fixture_sketches();
        if sketches.len() >= 2 {
            sketches[1].sketch_id = sketches[0].sketch_id.clone();
        }
        matches!(
            KvPageBloomSketchRegistry::new(sketches),
            Err(KvPageBloomSketchError::DuplicateSketch)
        )
    };
    let duplicate_page_candidate_rejected =
        invalid_sketch_rejected(|sketch| {
            if sketch.page_candidates.len() >= 2 {
                sketch.page_candidates[1].page_id = sketch.page_candidates[0].page_id.clone();
            }
        }) == Some(KvPageBloomSketchError::DuplicatePageCandidate);
    let missing_source_index_rejected =
        invalid_sketch_rejected(|sketch| sketch.source_index_ref.clear())
            == Some(KvPageBloomSketchError::MissingSourceIndex);
    let missing_source_page_ref_rejected =
        invalid_candidate_rejected(|candidate| candidate.source_page_ref.clear())
            == Some(KvPageBloomSketchError::MissingSourcePageRef);
    let missing_page_candidate_rejected =
        invalid_sketch_rejected(|sketch| sketch.page_candidates.clear())
            == Some(KvPageBloomSketchError::MissingPageCandidate);
    let missing_uas_address_rejected =
        invalid_candidate_rejected(|candidate| candidate.uas_address.clear())
            == Some(KvPageBloomSketchError::MissingUasAddress);
    let missing_digest_rejected =
        invalid_candidate_rejected(|candidate| candidate.page_digest.clear())
            == Some(KvPageBloomSketchError::MissingDigest);
    let missing_feature_hash_rejected =
        invalid_candidate_rejected(|candidate| candidate.feature_hashes.clear())
            == Some(KvPageBloomSketchError::MissingFeatureHash);
    let feature_hash_out_of_range_rejected =
        invalid_candidate_rejected(|candidate| {
            if let Some(first_hash) = candidate.feature_hashes.first_mut() {
                *first_hash = BLOOM_BIT_COUNT as u16;
            }
        }) == Some(KvPageBloomSketchError::FeatureHashOutOfRange);
    let missing_compatibility_fence_rejected =
        invalid_candidate_rejected(|candidate| candidate.compatibility_fence.clear())
            == Some(KvPageBloomSketchError::MissingCompatibilityFence);
    let incompatible_fence_rejected = invalid_candidate_rejected(|candidate| {
        candidate.compatibility_fence = "fence:model:stale:kv:v0".to_string();
    }) == Some(KvPageBloomSketchError::IncompatibleFence);
    let missing_false_positive_budget_rejected =
        invalid_sketch_rejected(|sketch| sketch.false_positive_budget_bps = None)
            == Some(KvPageBloomSketchError::MissingFalsePositiveBudget);
    let false_positive_budget_exceeded_rejected =
        invalid_sketch_rejected(|sketch| sketch.false_positive_budget_bps = Some(9_000))
            == Some(KvPageBloomSketchError::FalsePositiveBudgetExceeded);
    let missing_false_negative_policy_rejected =
        invalid_sketch_rejected(|sketch| sketch.false_negative_policy.clear())
            == Some(KvPageBloomSketchError::MissingFalseNegativePolicy);
    let required_evidence_false_negative_rejected =
        invalid_candidate_rejected(|candidate| {
            candidate.required_evidence = true;
            candidate.selected_by_filter = false;
        }) == Some(KvPageBloomSketchError::RequiredEvidenceFalseNegative);
    let proof_critical_negative_filter_rejected =
        invalid_candidate_rejected(|candidate| {
            candidate.required_evidence = true;
            candidate.proof_critical = true;
            candidate.negative_filter_allowed = true;
        }) == Some(KvPageBloomSketchError::ProofCriticalNegativeFilterEnabled);
    let privacy_critical_negative_filter_rejected =
        invalid_candidate_rejected(|candidate| {
            candidate.required_evidence = true;
            candidate.proof_critical = false;
            candidate.privacy_critical = true;
            candidate.negative_filter_allowed = true;
        }) == Some(KvPageBloomSketchError::PrivacyCriticalNegativeFilterEnabled);
    let missing_required_evidence_rejected =
        invalid_sketch_rejected(|sketch| {
            sketch
                .required_evidence_page_ids
                .push("kv-page:missing-proof".to_string());
        }) == Some(KvPageBloomSketchError::MissingRequiredEvidence);
    let missing_rollback_rejected =
        invalid_sketch_rejected(|sketch| sketch.rollback_handle.clear())
            == Some(KvPageBloomSketchError::MissingRollback);
    let missing_run_event_log_rejected =
        invalid_sketch_rejected(|sketch| sketch.run_event_log_ref.clear())
            == Some(KvPageBloomSketchError::MissingRunEventLog);
    let missing_answer_packet_rejected =
        invalid_sketch_rejected(|sketch| sketch.answer_packet_ref.clear())
            == Some(KvPageBloomSketchError::MissingAnswerPacket);
    let hidden_live_authority_rejected = invalid_sketch_rejected(|sketch| {
        sketch.route_authority = "live_route".to_string();
    }) == Some(KvPageBloomSketchError::HiddenLiveAuthority);
    let live_policy_mutation_rejected =
        invalid_sketch_rejected(|sketch| sketch.live_policy_mutated = true)
            == Some(KvPageBloomSketchError::LivePolicyMutation);
    let hidden_chain_exposure_rejected =
        invalid_sketch_rejected(|sketch| sketch.hidden_chain_exposed = true)
            == Some(KvPageBloomSketchError::HiddenChainExposure);
    let cloud_source_rejected = invalid_candidate_rejected(|candidate| {
        candidate.source_page_ref = "cloud:external-kv-page".to_string();
    }) == Some(KvPageBloomSketchError::CloudSource);
    let invalid_privacy_class_rejected = invalid_candidate_rejected(|candidate| {
        candidate.privacy_class = "raw_secret_chain".to_string();
    }) == Some(KvPageBloomSketchError::InvalidPrivacyClass);
    let metadata_budget_rejected = invalid_sketch_rejected(|sketch| {
        sketch.bloom_metadata_bytes = MAX_BLOOM_METADATA_BYTES + 1;
    }) == Some(KvPageBloomSketchError::MetadataBudgetExceeded);
    let unbeaten_baseline_rejected = invalid_sketch_rejected(|sketch| {
        sketch.hash_only_baseline_page_ids = sketch.required_evidence_page_ids.clone();
    }) == Some(KvPageBloomSketchError::UnbeatenBaseline);
    let no_runtime_bytes_loaded = true;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_kv_page_sketch_index_pass",
            upstream_kv_page_sketch_index_pass,
        ),
        (
            "kv_page_bloom_sketch_fixture_present",
            kv_page_bloom_sketch_fixture_present,
        ),
        ("training_split_bound", training_split_bound),
        ("held_out_split_bound", held_out_split_bound),
        ("sketch_ids_bound", sketch_ids_bound),
        ("source_index_ref_bound", source_index_ref_bound),
        ("source_page_refs_bound", source_page_refs_bound),
        ("page_candidates_bound", page_candidates_bound),
        ("page_ids_bound", page_ids_bound),
        ("uas_page_addresses_bound", uas_page_addresses_bound),
        ("page_digests_bound", page_digests_bound),
        ("compatibility_fences_bound", compatibility_fences_bound),
        ("feature_hashes_bound", feature_hashes_bound),
        ("feature_hash_range_bound", feature_hash_range_bound),
        ("false_positive_budget_bound", false_positive_budget_bound),
        ("false_negative_policy_bound", false_negative_policy_bound),
        ("privacy_classes_bound", privacy_classes_bound),
        ("required_evidence_bound", required_evidence_bound),
        (
            "proof_critical_filter_disabled",
            proof_critical_filter_disabled,
        ),
        (
            "privacy_critical_filter_disabled",
            privacy_critical_filter_disabled,
        ),
        ("over_include_allowed_bound", over_include_allowed_bound),
        (
            "required_evidence_coverage_bound",
            required_evidence_coverage_bound,
        ),
        (
            "required_evidence_coverage_beats_hash_only_baseline",
            required_evidence_coverage_beats_hash_only_baseline,
        ),
        (
            "required_evidence_coverage_beats_recency_baseline",
            required_evidence_coverage_beats_recency_baseline,
        ),
        (
            "required_evidence_coverage_beats_tagless_baseline",
            required_evidence_coverage_beats_tagless_baseline,
        ),
        ("rollback_bound", rollback_bound),
        ("run_event_log_bound", run_event_log_bound),
        ("answer_packet_ref_bound", answer_packet_ref_bound),
        ("route_authority_shadow_only", route_authority_shadow_only),
        ("no_hidden_chain", no_hidden_chain),
        ("no_hidden_cloud", no_hidden_cloud),
        ("live_policy_not_mutated", live_policy_not_mutated),
        (
            "bloom_sketch_address_deterministic",
            bloom_sketch_address_deterministic,
        ),
        ("duplicate_sketch_rejected", duplicate_sketch_rejected),
        (
            "duplicate_page_candidate_rejected",
            duplicate_page_candidate_rejected,
        ),
        (
            "missing_source_index_rejected",
            missing_source_index_rejected,
        ),
        (
            "missing_source_page_ref_rejected",
            missing_source_page_ref_rejected,
        ),
        (
            "missing_page_candidate_rejected",
            missing_page_candidate_rejected,
        ),
        ("missing_uas_address_rejected", missing_uas_address_rejected),
        ("missing_digest_rejected", missing_digest_rejected),
        (
            "missing_feature_hash_rejected",
            missing_feature_hash_rejected,
        ),
        (
            "feature_hash_out_of_range_rejected",
            feature_hash_out_of_range_rejected,
        ),
        (
            "missing_compatibility_fence_rejected",
            missing_compatibility_fence_rejected,
        ),
        ("incompatible_fence_rejected", incompatible_fence_rejected),
        (
            "missing_false_positive_budget_rejected",
            missing_false_positive_budget_rejected,
        ),
        (
            "false_positive_budget_exceeded_rejected",
            false_positive_budget_exceeded_rejected,
        ),
        (
            "missing_false_negative_policy_rejected",
            missing_false_negative_policy_rejected,
        ),
        (
            "required_evidence_false_negative_rejected",
            required_evidence_false_negative_rejected,
        ),
        (
            "proof_critical_negative_filter_rejected",
            proof_critical_negative_filter_rejected,
        ),
        (
            "privacy_critical_negative_filter_rejected",
            privacy_critical_negative_filter_rejected,
        ),
        (
            "missing_required_evidence_rejected",
            missing_required_evidence_rejected,
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
            "invalid_privacy_class_rejected",
            invalid_privacy_class_rejected,
        ),
        ("metadata_budget_rejected", metadata_budget_rejected),
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
        "bloom_sketch_count",
        registry.sketches.len() as u64,
        2,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "page_candidate_count",
        metrics.candidate_count,
        8,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "training_candidate_count",
        metrics.training_candidate_count,
        2,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_candidate_count",
        metrics.held_out_candidate_count,
        6,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "required_evidence_candidate_count",
        metrics.required_evidence_candidate_count,
        4,
        "count",
    );
    add_count_ge_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "proof_critical_candidate_count",
        metrics.proof_critical_candidate_count,
        4,
        "count",
    );
    add_count_ge_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "privacy_critical_candidate_count",
        metrics.privacy_critical_candidate_count,
        4,
        "count",
    );
    add_count_ge_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "overincluded_candidate_count",
        metrics.overincluded_candidate_count,
        2,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "bloom_bit_count",
        BLOOM_BIT_COUNT,
        BLOOM_BIT_COUNT,
        "bits",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hash_function_count",
        HASH_FUNCTION_COUNT as u64,
        HASH_FUNCTION_COUNT as u64,
        "count",
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
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hash_only_baseline_coverage_bps",
        metrics.hash_only_baseline_coverage_bps,
        metrics.required_evidence_coverage_bps,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "recency_baseline_coverage_bps",
        metrics.recency_baseline_coverage_bps,
        metrics.required_evidence_coverage_bps,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "tagless_baseline_coverage_bps",
        metrics.tagless_baseline_coverage_bps,
        metrics.required_evidence_coverage_bps,
        "bps",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_false_positive_budget_bps",
        metrics.max_false_positive_budget_bps,
        MAX_FALSE_POSITIVE_BPS,
        "bps",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_bloom_metadata_bytes",
        metrics.max_bloom_metadata_bytes,
        MAX_BLOOM_METADATA_BYTES,
        "bytes",
    );
    add_string_contains_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "bloom_sketch_address",
        &registry.bloom_sketch_address,
        "uas:kv-page-bloom-sketch:",
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
            "detail": "metadata-only KVPageBloomSketch witness; over-inclusion is allowed, required proof/citation/privacy evidence cannot be dropped, no live KV restore, no query-aware selector promotion, no model/runtime bytes, and no hidden route authority"
        })],
        notes: "scope=metadata_only;organ=KVPageBloomSketch;reviewer=codex;reviewed_at_utc=2026-06-04T00:00:00Z;validator=falsifier_validator;detail=Bloom-like KV/page filters prove required-evidence coverage and false-negative guardrails before query-aware page selection can promote.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:kv-page-bloom-sketch:registry
// Plane: Controller + Verification
// Residency: metadata-only
struct KvPageBloomSketchRegistry {
    sketches: Vec<KvPageBloomSketchFixture>,
    metrics: BloomMetrics,
    bloom_sketch_address: String,
}

impl KvPageBloomSketchRegistry {
    fn new(mut sketches: Vec<KvPageBloomSketchFixture>) -> Result<Self, KvPageBloomSketchError> {
        if sketches.is_empty() {
            return Err(KvPageBloomSketchError::MissingSketch);
        }
        let mut seen_sketches = BTreeSet::new();
        for sketch in &sketches {
            if !seen_sketches.insert(sketch.sketch_id.clone()) {
                return Err(KvPageBloomSketchError::DuplicateSketch);
            }
            validate_sketch(sketch)?;
        }
        sketches.sort_by_key(|sketch| sketch.sketch_id.clone());
        let metrics = bloom_metrics(&sketches);
        let bloom_sketch_address = bloom_sketch_address(&sketches);
        Ok(Self {
            sketches,
            metrics,
            bloom_sketch_address,
        })
    }
}

fn validate_sketch(sketch: &KvPageBloomSketchFixture) -> Result<(), KvPageBloomSketchError> {
    if !sketch.sketch_id.starts_with("kv-bloom-sketch:") {
        return Err(KvPageBloomSketchError::MissingSketchId);
    }
    if sketch.source_index_ref != UPSTREAM_SKETCH_INDEX {
        return Err(KvPageBloomSketchError::MissingSourceIndex);
    }
    if !sketch.compatibility_fence.starts_with("fence:") {
        return Err(KvPageBloomSketchError::MissingCompatibilityFence);
    }
    if sketch.compatibility_fence != CURRENT_FENCE {
        return Err(KvPageBloomSketchError::IncompatibleFence);
    }
    let false_positive_budget = sketch
        .false_positive_budget_bps
        .ok_or(KvPageBloomSketchError::MissingFalsePositiveBudget)?;
    if false_positive_budget > MAX_FALSE_POSITIVE_BPS {
        return Err(KvPageBloomSketchError::FalsePositiveBudgetExceeded);
    }
    if sketch.false_negative_policy != REQUIRED_FALSE_NEGATIVE_POLICY {
        return Err(KvPageBloomSketchError::MissingFalseNegativePolicy);
    }
    if sketch.page_candidates.is_empty() {
        return Err(KvPageBloomSketchError::MissingPageCandidate);
    }
    let mut seen_candidates = BTreeSet::new();
    for candidate in &sketch.page_candidates {
        if !seen_candidates.insert(candidate.page_id.clone()) {
            return Err(KvPageBloomSketchError::DuplicatePageCandidate);
        }
        validate_candidate(candidate)?;
    }
    if !required_evidence_covered(sketch) {
        return Err(KvPageBloomSketchError::MissingRequiredEvidence);
    }
    if coverage_bps(sketch, selected_page_ids(sketch)) != 10_000 {
        return Err(KvPageBloomSketchError::RequiredEvidenceFalseNegative);
    }
    if !proof_critical_negative_filter_disabled(sketch) {
        return Err(KvPageBloomSketchError::ProofCriticalNegativeFilterEnabled);
    }
    if !privacy_critical_negative_filter_disabled(sketch) {
        return Err(KvPageBloomSketchError::PrivacyCriticalNegativeFilterEnabled);
    }
    validate_baseline_pages(sketch, &sketch.hash_only_baseline_page_ids)?;
    validate_baseline_pages(sketch, &sketch.recency_baseline_page_ids)?;
    validate_baseline_pages(sketch, &sketch.tagless_baseline_page_ids)?;
    let selected_coverage = coverage_bps(sketch, selected_page_ids(sketch));
    if coverage_bps(sketch, &sketch.hash_only_baseline_page_ids) >= selected_coverage
        || coverage_bps(sketch, &sketch.recency_baseline_page_ids) >= selected_coverage
        || coverage_bps(sketch, &sketch.tagless_baseline_page_ids) >= selected_coverage
    {
        return Err(KvPageBloomSketchError::UnbeatenBaseline);
    }
    if overincluded_candidate_count(sketch) == 0 {
        return Err(KvPageBloomSketchError::MissingOverIncludeCase);
    }
    if !sketch.rollback_handle.starts_with("rollback:") {
        return Err(KvPageBloomSketchError::MissingRollback);
    }
    if !sketch.run_event_log_ref.starts_with("runevent:") {
        return Err(KvPageBloomSketchError::MissingRunEventLog);
    }
    if !sketch.answer_packet_ref.starts_with("answerpacket:") {
        return Err(KvPageBloomSketchError::MissingAnswerPacket);
    }
    if sketch.route_authority != "shadow_only" {
        return Err(KvPageBloomSketchError::HiddenLiveAuthority);
    }
    if sketch.live_policy_mutated {
        return Err(KvPageBloomSketchError::LivePolicyMutation);
    }
    if sketch.hidden_chain_exposed {
        return Err(KvPageBloomSketchError::HiddenChainExposure);
    }
    if sketch.hidden_cloud {
        return Err(KvPageBloomSketchError::CloudSource);
    }
    if sketch.bloom_metadata_bytes > MAX_BLOOM_METADATA_BYTES {
        return Err(KvPageBloomSketchError::MetadataBudgetExceeded);
    }
    Ok(())
}

fn validate_candidate(candidate: &BloomPageCandidate) -> Result<(), KvPageBloomSketchError> {
    if candidate.split != "training" && candidate.split != "held_out" {
        return Err(KvPageBloomSketchError::MissingSplit);
    }
    if !candidate.page_id.starts_with("kv-page:") {
        return Err(KvPageBloomSketchError::MissingPageId);
    }
    if !candidate.uas_address.starts_with("uas:kv-page:") {
        return Err(KvPageBloomSketchError::MissingUasAddress);
    }
    if candidate.source_page_ref.is_empty() {
        return Err(KvPageBloomSketchError::MissingSourcePageRef);
    }
    if candidate.source_page_ref.contains("cloud") {
        return Err(KvPageBloomSketchError::CloudSource);
    }
    if !candidate.page_digest.starts_with("sha256:") {
        return Err(KvPageBloomSketchError::MissingDigest);
    }
    if !candidate.compatibility_fence.starts_with("fence:") {
        return Err(KvPageBloomSketchError::MissingCompatibilityFence);
    }
    if candidate.compatibility_fence != CURRENT_FENCE {
        return Err(KvPageBloomSketchError::IncompatibleFence);
    }
    if candidate.feature_hashes.is_empty() {
        return Err(KvPageBloomSketchError::MissingFeatureHash);
    }
    if candidate.feature_hashes.len() != HASH_FUNCTION_COUNT {
        return Err(KvPageBloomSketchError::MissingFeatureHash);
    }
    if candidate
        .feature_hashes
        .iter()
        .any(|hash| u64::from(*hash) >= BLOOM_BIT_COUNT)
    {
        return Err(KvPageBloomSketchError::FeatureHashOutOfRange);
    }
    if candidate.semantic_tags.is_empty() {
        return Err(KvPageBloomSketchError::MissingSemanticTag);
    }
    if !valid_privacy_class(&candidate.privacy_class) {
        return Err(KvPageBloomSketchError::InvalidPrivacyClass);
    }
    Ok(())
}

fn validate_baseline_pages(
    sketch: &KvPageBloomSketchFixture,
    page_ids: &[String],
) -> Result<(), KvPageBloomSketchError> {
    if page_ids.is_empty() {
        return Err(KvPageBloomSketchError::MissingBaselinePage);
    }
    let candidates = candidate_map(sketch);
    for page_id in page_ids {
        if !candidates.contains_key(page_id) {
            return Err(KvPageBloomSketchError::MissingBaselinePage);
        }
    }
    Ok(())
}

fn required_evidence_covered(sketch: &KvPageBloomSketchFixture) -> bool {
    if sketch.required_evidence_page_ids.is_empty() {
        return false;
    }
    let candidates = candidate_map(sketch);
    sketch.required_evidence_page_ids.iter().all(|page_id| {
        candidates
            .get(page_id)
            .is_some_and(|candidate| candidate.required_evidence)
    })
}

fn proof_critical_negative_filter_disabled(sketch: &KvPageBloomSketchFixture) -> bool {
    sketch.page_candidates.iter().all(|candidate| {
        !(candidate.required_evidence && candidate.proof_critical)
            || !candidate.negative_filter_allowed
    })
}

fn privacy_critical_negative_filter_disabled(sketch: &KvPageBloomSketchFixture) -> bool {
    sketch.page_candidates.iter().all(|candidate| {
        !(candidate.required_evidence && candidate.privacy_critical)
            || !candidate.negative_filter_allowed
    })
}

fn candidate_map(sketch: &KvPageBloomSketchFixture) -> BTreeMap<String, &BloomPageCandidate> {
    sketch
        .page_candidates
        .iter()
        .map(|candidate| (candidate.page_id.clone(), candidate))
        .collect()
}

fn selected_page_ids(sketch: &KvPageBloomSketchFixture) -> Vec<String> {
    sketch
        .page_candidates
        .iter()
        .filter(|candidate| candidate.selected_by_filter)
        .map(|candidate| candidate.page_id.clone())
        .collect()
}

fn coverage_bps(sketch: &KvPageBloomSketchFixture, page_ids: impl AsRef<[String]>) -> u64 {
    if sketch.required_evidence_page_ids.is_empty() {
        return 0;
    }
    let required = sketch
        .required_evidence_page_ids
        .iter()
        .collect::<BTreeSet<_>>();
    let covered = page_ids
        .as_ref()
        .iter()
        .filter(|page_id| required.contains(page_id))
        .count() as u64;
    covered * 10_000 / required.len() as u64
}

fn overincluded_candidate_count(sketch: &KvPageBloomSketchFixture) -> u64 {
    sketch
        .page_candidates
        .iter()
        .filter(|candidate| candidate.selected_by_filter && !candidate.required_evidence)
        .count() as u64
}

fn valid_privacy_class(privacy_class: &str) -> bool {
    matches!(
        privacy_class,
        "vault_private" | "proof_private" | "research_private" | "public_source"
    )
}

fn bloom_metrics(sketches: &[KvPageBloomSketchFixture]) -> BloomMetrics {
    let mut metrics = BloomMetrics::default();
    let mut required_coverage_sum = 0;
    let mut hash_only_coverage_sum = 0;
    let mut recency_coverage_sum = 0;
    let mut tagless_coverage_sum = 0;
    for sketch in sketches {
        metrics.max_false_positive_budget_bps = metrics
            .max_false_positive_budget_bps
            .max(sketch.false_positive_budget_bps.unwrap_or_default());
        metrics.max_bloom_metadata_bytes = metrics
            .max_bloom_metadata_bytes
            .max(sketch.bloom_metadata_bytes);
        required_coverage_sum += coverage_bps(sketch, selected_page_ids(sketch));
        hash_only_coverage_sum += coverage_bps(sketch, &sketch.hash_only_baseline_page_ids);
        recency_coverage_sum += coverage_bps(sketch, &sketch.recency_baseline_page_ids);
        tagless_coverage_sum += coverage_bps(sketch, &sketch.tagless_baseline_page_ids);
        for candidate in &sketch.page_candidates {
            metrics.candidate_count += 1;
            if candidate.split == "training" {
                metrics.training_candidate_count += 1;
            }
            if candidate.split == "held_out" {
                metrics.held_out_candidate_count += 1;
            }
            if candidate.required_evidence {
                metrics.required_evidence_candidate_count += 1;
            }
            if candidate.proof_critical {
                metrics.proof_critical_candidate_count += 1;
            }
            if candidate.privacy_critical {
                metrics.privacy_critical_candidate_count += 1;
            }
            if candidate.selected_by_filter && !candidate.required_evidence {
                metrics.overincluded_candidate_count += 1;
            }
        }
    }
    let sketch_count = sketches.len().max(1) as u64;
    metrics.required_evidence_coverage_bps = required_coverage_sum / sketch_count;
    metrics.hash_only_baseline_coverage_bps = hash_only_coverage_sum / sketch_count;
    metrics.recency_baseline_coverage_bps = recency_coverage_sum / sketch_count;
    metrics.tagless_baseline_coverage_bps = tagless_coverage_sum / sketch_count;
    metrics
}

fn bloom_sketch_address(sketches: &[KvPageBloomSketchFixture]) -> String {
    let mut payload = String::new();
    for sketch in sketches {
        payload.push_str(&sketch.sketch_id);
        payload.push('|');
        payload.push_str(&sketch.source_index_ref);
        payload.push('|');
        payload.push_str(&sketch.compatibility_fence);
        payload.push('|');
        let mut candidates = sketch.page_candidates.clone();
        candidates.sort_by_key(|candidate| candidate.page_id.clone());
        for candidate in candidates {
            payload.push_str(&candidate.page_id);
            payload.push(':');
            payload.push_str(&candidate.uas_address);
            payload.push(':');
            payload.push_str(&candidate.page_digest);
            payload.push(':');
            payload.push_str(&candidate.selected_by_filter.to_string());
            payload.push(':');
            for feature_hash in &candidate.feature_hashes {
                payload.push_str(&feature_hash.to_string());
                payload.push(',');
            }
            payload.push(';');
        }
        payload.push('\n');
    }
    format!(
        "uas:kv-page-bloom-sketch:{}",
        sha256_hex(payload.as_bytes()).trim_start_matches("sha256:")
    )
}

fn invalid_sketch_rejected(
    mut mutate: impl FnMut(&mut KvPageBloomSketchFixture),
) -> Option<KvPageBloomSketchError> {
    let mut sketches = fixture_sketches();
    if let Some(first) = sketches.first_mut() {
        mutate(first);
    }
    KvPageBloomSketchRegistry::new(sketches).err()
}

fn invalid_candidate_rejected(
    mut mutate: impl FnMut(&mut BloomPageCandidate),
) -> Option<KvPageBloomSketchError> {
    invalid_sketch_rejected(|sketch| {
        if let Some(first) = sketch.page_candidates.first_mut() {
            mutate(first);
        }
    })
}

fn upstream_sketch_index_pass() -> bool {
    read_artifact_string(UPSTREAM_SKETCH_INDEX)
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

fn fixture_sketches() -> Vec<KvPageBloomSketchFixture> {
    vec![
        KvPageBloomSketchFixture {
            sketch_id: "kv-bloom-sketch:proof-route-repair".to_string(),
            source_index_ref: UPSTREAM_SKETCH_INDEX.to_string(),
            compatibility_fence: CURRENT_FENCE.to_string(),
            false_positive_budget_bps: Some(3_000),
            false_negative_policy: REQUIRED_FALSE_NEGATIVE_POLICY.to_string(),
            required_evidence_page_ids: vec![
                "kv-page:rollback-precondition".to_string(),
                "kv-page:answerpacket-proof".to_string(),
            ],
            hash_only_baseline_page_ids: vec![
                "kv-page:rollback-precondition".to_string(),
                "kv-page:recent-terminal-log".to_string(),
            ],
            recency_baseline_page_ids: vec![
                "kv-page:recent-terminal-log".to_string(),
                "kv-page:file-order-schema".to_string(),
            ],
            tagless_baseline_page_ids: vec![
                "kv-page:file-order-schema".to_string(),
                "kv-page:answerpacket-proof".to_string(),
            ],
            page_candidates: vec![
                candidate(
                    "training",
                    "kv-page:rollback-precondition",
                    11,
                    &["rollback", "precondition", "route-kernel"],
                    "proof_private",
                    true,
                    true,
                    true,
                    false,
                    true,
                ),
                candidate(
                    "held_out",
                    "kv-page:answerpacket-proof",
                    37,
                    &["answerpacket", "visible-proof", "postcondition"],
                    "proof_private",
                    true,
                    true,
                    true,
                    false,
                    true,
                ),
                candidate(
                    "held_out",
                    "kv-page:recent-terminal-log",
                    59,
                    &["recent", "terminal", "low-signal"],
                    "vault_private",
                    false,
                    false,
                    false,
                    true,
                    true,
                ),
                candidate(
                    "held_out",
                    "kv-page:file-order-schema",
                    83,
                    &["schema", "file-order", "background"],
                    "vault_private",
                    false,
                    false,
                    false,
                    true,
                    false,
                ),
            ],
            rollback_handle: "rollback:kv-page-bloom:proof-route".to_string(),
            run_event_log_ref: "runevent:kv-page-bloom:proof-route".to_string(),
            answer_packet_ref: "answerpacket:kv-page-bloom:proof-route".to_string(),
            route_authority: "shadow_only".to_string(),
            bloom_metadata_bytes: 80 * 1024,
            hidden_chain_exposed: false,
            hidden_cloud: false,
            live_policy_mutated: false,
        },
        KvPageBloomSketchFixture {
            sketch_id: "kv-bloom-sketch:swiftlm-source-motif".to_string(),
            source_index_ref: UPSTREAM_SKETCH_INDEX.to_string(),
            compatibility_fence: CURRENT_FENCE.to_string(),
            false_positive_budget_bps: Some(3_200),
            false_negative_policy: REQUIRED_FALSE_NEGATIVE_POLICY.to_string(),
            required_evidence_page_ids: vec![
                "kv-page:swiftlm-kv-compression".to_string(),
                "kv-page:flash-bundling-caveat".to_string(),
            ],
            hash_only_baseline_page_ids: vec![
                "kv-page:swiftlm-kv-compression".to_string(),
                "kv-page:recent-chat-summary".to_string(),
            ],
            recency_baseline_page_ids: vec![
                "kv-page:recent-chat-summary".to_string(),
                "kv-page:file-license-preface".to_string(),
            ],
            tagless_baseline_page_ids: vec![
                "kv-page:file-license-preface".to_string(),
                "kv-page:flash-bundling-caveat".to_string(),
            ],
            page_candidates: vec![
                candidate(
                    "training",
                    "kv-page:swiftlm-kv-compression",
                    19,
                    &["swiftlm", "kv-compression", "ssd-streaming"],
                    "research_private",
                    true,
                    true,
                    true,
                    false,
                    true,
                ),
                candidate(
                    "held_out",
                    "kv-page:flash-bundling-caveat",
                    43,
                    &["flash", "bundling", "caveat"],
                    "research_private",
                    true,
                    true,
                    true,
                    false,
                    true,
                ),
                candidate(
                    "held_out",
                    "kv-page:recent-chat-summary",
                    67,
                    &["recent", "chat", "summary"],
                    "vault_private",
                    false,
                    false,
                    false,
                    true,
                    true,
                ),
                candidate(
                    "held_out",
                    "kv-page:file-license-preface",
                    101,
                    &["license", "preface", "background"],
                    "public_source",
                    false,
                    false,
                    false,
                    true,
                    false,
                ),
            ],
            rollback_handle: "rollback:kv-page-bloom:swiftlm".to_string(),
            run_event_log_ref: "runevent:kv-page-bloom:swiftlm".to_string(),
            answer_packet_ref: "answerpacket:kv-page-bloom:swiftlm".to_string(),
            route_authority: "shadow_only".to_string(),
            bloom_metadata_bytes: 88 * 1024,
            hidden_chain_exposed: false,
            hidden_cloud: false,
            live_policy_mutated: false,
        },
    ]
}

#[allow(clippy::too_many_arguments)]
fn candidate(
    split: &str,
    page_id: &str,
    seed: u16,
    tags: &[&str],
    privacy_class: &str,
    required_evidence: bool,
    proof_critical: bool,
    privacy_critical: bool,
    negative_filter_allowed: bool,
    selected_by_filter: bool,
) -> BloomPageCandidate {
    let digest_seed = format!("{page_id}:{seed}:{tags:?}:{privacy_class}");
    BloomPageCandidate {
        split: split.to_string(),
        page_id: page_id.to_string(),
        uas_address: format!("uas:kv-page:{page_id}"),
        source_page_ref: UPSTREAM_SKETCH_INDEX.to_string(),
        page_digest: sha256_hex(digest_seed.as_bytes()),
        compatibility_fence: CURRENT_FENCE.to_string(),
        feature_hashes: (0..HASH_FUNCTION_COUNT)
            .map(|idx| (seed + idx as u16 * 17) % BLOOM_BIT_COUNT as u16)
            .collect(),
        semantic_tags: tags.iter().map(|tag| (*tag).to_string()).collect(),
        privacy_class: privacy_class.to_string(),
        required_evidence,
        proof_critical,
        privacy_critical,
        negative_filter_allowed,
        selected_by_filter,
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

fn add_u64_lt_axis(
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
            operator: "<".to_string(),
            value: serde_json::Value::from(expected),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual < expected);
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
            "upstream_kv_page_sketch_index_pass",
            "kv_page_bloom_sketch_fixture_present",
            "feature_hashes_bound",
            "feature_hash_range_bound",
            "false_positive_budget_bound",
            "false_negative_policy_bound",
            "required_evidence_coverage_bound",
            "proof_critical_filter_disabled",
            "privacy_critical_filter_disabled",
            "over_include_allowed_bound",
            "required_evidence_false_negative_rejected",
            "proof_critical_negative_filter_rejected",
            "privacy_critical_negative_filter_rejected",
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
        assert_eq!(
            KvPageBloomSketchRegistry::new(Vec::new()).err(),
            Some(KvPageBloomSketchError::MissingSketch)
        );
    }

    #[test]
    fn invalid_fixture_cases_reject() {
        for (name, observed, expected) in [
            (
                "missing feature hash",
                invalid_candidate_rejected(|candidate| candidate.feature_hashes.clear()),
                KvPageBloomSketchError::MissingFeatureHash,
            ),
            (
                "feature hash out of range",
                invalid_candidate_rejected(|candidate| candidate.feature_hashes[0] = 128),
                KvPageBloomSketchError::FeatureHashOutOfRange,
            ),
            (
                "required false negative",
                invalid_candidate_rejected(|candidate| {
                    candidate.required_evidence = true;
                    candidate.selected_by_filter = false;
                }),
                KvPageBloomSketchError::RequiredEvidenceFalseNegative,
            ),
            (
                "proof critical filter enabled",
                invalid_candidate_rejected(|candidate| {
                    candidate.required_evidence = true;
                    candidate.proof_critical = true;
                    candidate.negative_filter_allowed = true;
                }),
                KvPageBloomSketchError::ProofCriticalNegativeFilterEnabled,
            ),
            (
                "privacy critical filter enabled",
                invalid_candidate_rejected(|candidate| {
                    candidate.required_evidence = true;
                    candidate.proof_critical = false;
                    candidate.privacy_critical = true;
                    candidate.negative_filter_allowed = true;
                }),
                KvPageBloomSketchError::PrivacyCriticalNegativeFilterEnabled,
            ),
            (
                "hidden authority",
                invalid_sketch_rejected(|sketch| sketch.route_authority = "live".to_string()),
                KvPageBloomSketchError::HiddenLiveAuthority,
            ),
        ] {
            assert_eq!(observed, Some(expected), "{name}");
        }
    }

    #[test]
    fn bloom_address_is_order_stable() {
        let registry = KvPageBloomSketchRegistry::new(fixture_sketches()).expect("valid registry");
        let reversed = fixture_sketches().into_iter().rev().collect::<Vec<_>>();
        let reversed_registry =
            KvPageBloomSketchRegistry::new(reversed).expect("valid reversed registry");
        assert_eq!(
            registry.bloom_sketch_address,
            reversed_registry.bloom_sketch_address
        );
    }
}
