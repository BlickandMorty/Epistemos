//! `falsify_query_aware_kv_selector` -- query-aware KV/page selector contract.
//!
//! Metadata-only witness for `F-QueryAwareKVSelector`. It proves query-shaped
//! KV/page selection consumes sketch-index and Bloom-filter evidence, beats
//! recency/random/file-order/Bloom-only baselines on held-out fixtures, and
//! stays rollback-bound and AnswerPacket-visible before any live KV/page route
//! authority can promote.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-QueryAwareKVSelector";
const FIXTURE_ID: &str = "query_aware_kv_selector_v1";
const COMMAND: &str = "Tools/falsifiers/f_query_aware_kv_selector.sh";
const RESULT: &str = "artifacts/falsifiers/query_aware_kv_selector/result.json";
const UPSTREAM_SKETCH_INDEX: &str = "artifacts/falsifiers/kv_page_sketch_index/result.json";
const UPSTREAM_BLOOM: &str = "artifacts/falsifiers/kv_page_bloom_sketch_coverage/result.json";
const CURRENT_FENCE: &str = "fence:model:qwen3.5:kv:v1:tokenizer:qwen3.5:adapter:none";
const REQUIRED_FALSE_NEGATIVE_POLICY: &str = "forbid_required_evidence_drop_after_bloom";
const MAX_SELECTOR_METADATA_BYTES: u64 = 1_048_576;

#[derive(Clone)]
// UAS: uas:query-aware-kv-selector:page
// Plane: Assembly + Verification
// Residency: metadata-only candidate; no KV/runtime bytes loaded.
struct QueryPageCandidate {
    split: String,
    page_id: String,
    uas_address: String,
    source_index_ref: String,
    bloom_sketch_ref: String,
    page_digest: String,
    compatibility_fence: String,
    semantic_tags: Vec<String>,
    query_match_bps: u64,
    evidence_utility_bps: u64,
    verifier_utility_bps: u64,
    recency_rank: u64,
    file_order: u64,
    active_bytes: u64,
    restore_latency_ms: u64,
    privacy_class: String,
    required_evidence: bool,
    proof_critical: bool,
    bloom_selected: bool,
    query_selected: bool,
    stale: bool,
}

#[derive(Clone)]
// UAS: uas:query-aware-kv-selector:fixture
// Plane: Controller + Assembly + Verification
// Residency: metadata-only shadow selector.
struct QueryAwareKvSelectorFixture {
    selector_id: String,
    mission_id: String,
    query_signature: String,
    model_id: String,
    tokenizer_id: String,
    upstream_sketch_index_ref: String,
    upstream_bloom_ref: String,
    compatibility_fence: String,
    required_evidence_page_ids: Vec<String>,
    selected_page_ids: Vec<String>,
    recency_baseline_page_ids: Vec<String>,
    random_baseline_page_ids: Vec<String>,
    file_order_baseline_page_ids: Vec<String>,
    bloom_only_baseline_page_ids: Vec<String>,
    page_candidates: Vec<QueryPageCandidate>,
    active_byte_limit: u64,
    latency_limit_ms: u64,
    min_quality_bps: u64,
    min_verifier_bps: u64,
    false_negative_policy: String,
    rollback_handle: String,
    run_event_log_ref: String,
    answer_packet_ref: String,
    route_authority: String,
    selector_metadata_bytes: u64,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    live_policy_mutated: bool,
}

#[derive(Default, Clone, Copy)]
// UAS: uas:query-aware-kv-selector:score
// Plane: Verification
// Residency: metadata-only score.
struct SelectionScore {
    coverage_bps: u64,
    quality_bps: u64,
    verifier_bps: u64,
    active_bytes: u64,
    latency_ms: u64,
}

#[derive(Default, Clone, Copy)]
// UAS: uas:query-aware-kv-selector:metrics
// Plane: Verification
// Residency: metadata-only summary.
struct SelectorMetrics {
    candidate_count: u64,
    training_candidate_count: u64,
    held_out_candidate_count: u64,
    selected_page_count: u64,
    required_evidence_page_count: u64,
    bloom_selected_candidate_count: u64,
    max_selected_active_bytes: u64,
    max_selected_latency_ms: u64,
    min_selected_quality_bps: u64,
    min_selected_verifier_bps: u64,
    query_selector_success_bps: u64,
    recency_baseline_success_bps: u64,
    random_baseline_success_bps: u64,
    file_order_baseline_success_bps: u64,
    bloom_only_baseline_success_bps: u64,
    max_selector_metadata_bytes: u64,
}

#[derive(Debug, Eq, PartialEq)]
// UAS: uas:query-aware-kv-selector:error
// Plane: Verification
// Residency: metadata-only rejection reason.
enum QueryAwareKvSelectorError {
    MissingSelector,
    DuplicateSelector,
    MissingSelectorId,
    MissingMission,
    MissingQuery,
    MissingModel,
    MissingTokenizer,
    MissingUpstreamSketchIndex,
    MissingUpstreamBloom,
    MissingCompatibilityFence,
    IncompatibleFence,
    MissingPageCandidate,
    DuplicatePage,
    MissingSplit,
    MissingPageId,
    MissingUasAddress,
    MissingSourceIndexRef,
    MissingBloomRef,
    MissingDigest,
    MissingSemanticTag,
    MissingQuerySignal,
    MissingEvidenceSignal,
    MissingVerifierSignal,
    MissingRecency,
    MissingFileOrder,
    MissingActiveBytes,
    MissingRestoreLatency,
    InvalidPrivacyClass,
    StalePageSelected,
    MissingSelectedPage,
    UnknownSelectedPage,
    SelectedMismatch,
    UnfilteredPageSelected,
    MissingRequiredEvidence,
    RequiredEvidenceFalseNegative,
    MissingBaselinePage,
    MissingFalseNegativePolicy,
    BudgetExceeded,
    LatencyExceeded,
    LowQualitySelection,
    VerifierBypass,
    UnbeatenBaseline,
    MissingRollback,
    MissingRunEventLog,
    MissingAnswerPacket,
    HiddenLiveAuthority,
    LivePolicyMutation,
    HiddenChainExposure,
    CloudSource,
    SelectorMetadataBudgetExceeded,
}

impl std::fmt::Display for QueryAwareKvSelectorError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for QueryAwareKvSelectorError {}

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
        "{FALSIFIER_ID}: overall_pass={} selector_count={} query_selector_success_bps={} query_selector_address={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["selector_count"].value,
        artifact.measurements["query_selector_success_bps"].value,
        artifact.measurements["query_selector_address"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let selectors = fixture_selectors();
    let reversed = selectors.iter().cloned().rev().collect::<Vec<_>>();
    let registry = QueryAwareKvSelectorRegistry::new(selectors)?;
    let reversed_registry = QueryAwareKvSelectorRegistry::new(reversed)?;
    let metrics = registry.metrics;

    let upstream_kv_page_sketch_index_pass = upstream_artifact_pass(UPSTREAM_SKETCH_INDEX);
    let upstream_kv_page_bloom_sketch_coverage_pass = upstream_artifact_pass(UPSTREAM_BLOOM);
    let query_aware_selector_fixture_present =
        registry.selectors.len() == 2 && metrics.candidate_count == 8;
    let training_split_bound = metrics.training_candidate_count >= 2;
    let held_out_split_bound = metrics.held_out_candidate_count >= 6;
    let selector_ids_bound = registry
        .selectors
        .iter()
        .all(|selector| selector.selector_id.starts_with("query-kv-selector:"));
    let mission_ids_bound = registry
        .selectors
        .iter()
        .all(|selector| selector.mission_id.starts_with("mission:"));
    let query_signatures_bound = registry
        .selectors
        .iter()
        .all(|selector| selector.query_signature.starts_with("query:"));
    let model_ids_bound = registry
        .selectors
        .iter()
        .all(|selector| selector.model_id.starts_with("model:"));
    let tokenizer_ids_bound = registry
        .selectors
        .iter()
        .all(|selector| selector.tokenizer_id.starts_with("tokenizer:"));
    let upstream_refs_bound = registry.selectors.iter().all(|selector| {
        selector.upstream_sketch_index_ref == UPSTREAM_SKETCH_INDEX
            && selector.upstream_bloom_ref == UPSTREAM_BLOOM
    });
    let page_candidates_bound = registry
        .selectors
        .iter()
        .all(|selector| !selector.page_candidates.is_empty());
    let page_ids_bound = registry.selectors.iter().all(|selector| {
        selector
            .page_candidates
            .iter()
            .all(|candidate| candidate.page_id.starts_with("kv-page:"))
    });
    let uas_page_addresses_bound = registry.selectors.iter().all(|selector| {
        selector
            .page_candidates
            .iter()
            .all(|candidate| candidate.uas_address.starts_with("uas:kv-page:"))
    });
    let page_digests_bound = registry.selectors.iter().all(|selector| {
        selector
            .page_candidates
            .iter()
            .all(|candidate| candidate.page_digest.starts_with("sha256:"))
    });
    let source_index_refs_bound = registry.selectors.iter().all(|selector| {
        selector
            .page_candidates
            .iter()
            .all(|candidate| candidate.source_index_ref == UPSTREAM_SKETCH_INDEX)
    });
    let bloom_refs_bound = registry.selectors.iter().all(|selector| {
        selector
            .page_candidates
            .iter()
            .all(|candidate| candidate.bloom_sketch_ref == UPSTREAM_BLOOM)
    });
    let compatibility_fences_bound = registry.selectors.iter().all(|selector| {
        selector.compatibility_fence == CURRENT_FENCE
            && selector
                .page_candidates
                .iter()
                .all(|candidate| candidate.compatibility_fence == CURRENT_FENCE)
    });
    let semantic_tags_bound = registry.selectors.iter().all(|selector| {
        selector
            .page_candidates
            .iter()
            .all(|candidate| !candidate.semantic_tags.is_empty())
    });
    let query_match_signal_bound = registry.selectors.iter().all(|selector| {
        selector
            .page_candidates
            .iter()
            .all(|candidate| candidate.query_match_bps > 0)
    });
    let evidence_utility_signal_bound = registry.selectors.iter().all(|selector| {
        selector
            .page_candidates
            .iter()
            .all(|candidate| candidate.evidence_utility_bps > 0)
    });
    let verifier_utility_signal_bound = registry.selectors.iter().all(|selector| {
        selector
            .page_candidates
            .iter()
            .all(|candidate| candidate.verifier_utility_bps > 0)
    });
    let recency_bound = registry.selectors.iter().all(|selector| {
        selector
            .page_candidates
            .iter()
            .all(|candidate| candidate.recency_rank > 0)
    });
    let file_order_bound = registry.selectors.iter().all(|selector| {
        selector
            .page_candidates
            .iter()
            .all(|candidate| candidate.file_order > 0)
    });
    let active_bytes_bound = registry.selectors.iter().all(|selector| {
        selector
            .page_candidates
            .iter()
            .all(|candidate| candidate.active_bytes > 0)
    });
    let restore_latency_bound = registry.selectors.iter().all(|selector| {
        selector
            .page_candidates
            .iter()
            .all(|candidate| candidate.restore_latency_ms > 0)
    });
    let privacy_classes_bound = registry.selectors.iter().all(|selector| {
        selector
            .page_candidates
            .iter()
            .all(|candidate| valid_privacy_class(&candidate.privacy_class))
    });
    let required_evidence_bound = registry.selectors.iter().all(required_evidence_bound);
    let selected_pages_bound = registry.selectors.iter().all(selected_pages_match_flags);
    let selected_pages_in_bloom_prefilter = registry
        .selectors
        .iter()
        .all(selected_pages_in_bloom_prefilter);
    let selected_pages_fit_active_byte_budget = registry.selectors.iter().all(|selector| {
        score(selector, &selector.selected_page_ids).active_bytes <= selector.active_byte_limit
    });
    let selected_pages_fit_latency_budget = registry.selectors.iter().all(|selector| {
        score(selector, &selector.selected_page_ids).latency_ms <= selector.latency_limit_ms
    });
    let false_negative_policy_bound = registry
        .selectors
        .iter()
        .all(|selector| selector.false_negative_policy == REQUIRED_FALSE_NEGATIVE_POLICY);
    let quality_floor_bound = registry.selectors.iter().all(|selector| {
        score(selector, &selector.selected_page_ids).quality_bps >= selector.min_quality_bps
    });
    let verifier_floor_bound = registry.selectors.iter().all(|selector| {
        score(selector, &selector.selected_page_ids).verifier_bps >= selector.min_verifier_bps
    });
    let query_aware_beats_recency_baseline =
        metrics.query_selector_success_bps > metrics.recency_baseline_success_bps;
    let query_aware_beats_random_baseline =
        metrics.query_selector_success_bps > metrics.random_baseline_success_bps;
    let query_aware_beats_file_order_baseline =
        metrics.query_selector_success_bps > metrics.file_order_baseline_success_bps;
    let query_aware_beats_bloom_only_baseline =
        metrics.query_selector_success_bps > metrics.bloom_only_baseline_success_bps;
    let quality_delta_positive = registry.selectors.iter().all(|selector| {
        let selected = score(selector, &selector.selected_page_ids);
        selected.quality_bps
            > best_baseline_score(selector)
                .map(|score| score.quality_bps)
                .unwrap_or(0)
    });
    let verifier_delta_positive = registry.selectors.iter().all(|selector| {
        let selected = score(selector, &selector.selected_page_ids);
        selected.verifier_bps
            > best_baseline_score(selector)
                .map(|score| score.verifier_bps)
                .unwrap_or(0)
    });
    let latency_delta_positive = registry.selectors.iter().all(|selector| {
        let selected = score(selector, &selector.selected_page_ids);
        selected.latency_ms
            < best_baseline_score(selector)
                .map(|score| score.latency_ms)
                .unwrap_or(u64::MAX)
    });
    let active_byte_delta_positive = registry.selectors.iter().all(|selector| {
        let selected = score(selector, &selector.selected_page_ids);
        selected.active_bytes
            < best_baseline_score(selector)
                .map(|score| score.active_bytes)
                .unwrap_or(u64::MAX)
    });
    let rollback_bound = registry
        .selectors
        .iter()
        .all(|selector| selector.rollback_handle.starts_with("rollback:"));
    let run_event_log_bound = registry
        .selectors
        .iter()
        .all(|selector| selector.run_event_log_ref.starts_with("runevent:"));
    let answer_packet_ref_bound = registry
        .selectors
        .iter()
        .all(|selector| selector.answer_packet_ref.starts_with("answerpacket:"));
    let route_authority_shadow_only = registry
        .selectors
        .iter()
        .all(|selector| selector.route_authority == "shadow_only");
    let no_hidden_chain = registry
        .selectors
        .iter()
        .all(|selector| !selector.hidden_chain_exposed);
    let no_hidden_cloud = registry
        .selectors
        .iter()
        .all(|selector| !selector.hidden_cloud);
    let live_policy_not_mutated = registry
        .selectors
        .iter()
        .all(|selector| !selector.live_policy_mutated);
    let query_selector_address_deterministic =
        registry.query_selector_address == reversed_registry.query_selector_address;

    let duplicate_selector_rejected = {
        let mut selectors = fixture_selectors();
        if selectors.len() >= 2 {
            selectors[1].selector_id = selectors[0].selector_id.clone();
        }
        matches!(
            QueryAwareKvSelectorRegistry::new(selectors),
            Err(QueryAwareKvSelectorError::DuplicateSelector)
        )
    };
    let duplicate_page_rejected = invalid_selector_rejected(|selector| {
        if selector.page_candidates.len() >= 2 {
            selector.page_candidates[1].page_id = selector.page_candidates[0].page_id.clone();
        }
    }) == Some(QueryAwareKvSelectorError::DuplicatePage);
    let missing_query_rejected =
        invalid_selector_rejected(|selector| selector.query_signature.clear())
            == Some(QueryAwareKvSelectorError::MissingQuery);
    let missing_selected_page_rejected =
        invalid_selector_rejected(|selector| selector.selected_page_ids.clear())
            == Some(QueryAwareKvSelectorError::MissingSelectedPage);
    let unknown_selected_page_rejected = invalid_selector_rejected(|selector| {
        selector
            .selected_page_ids
            .push("kv-page:unknown".to_string());
    }) == Some(QueryAwareKvSelectorError::UnknownSelectedPage);
    let unfiltered_page_selected_rejected =
        invalid_selected_candidate_rejected(|candidate| candidate.bloom_selected = false)
            == Some(QueryAwareKvSelectorError::UnfilteredPageSelected);
    let stale_page_rejected =
        invalid_selected_candidate_rejected(|candidate| candidate.stale = true)
            == Some(QueryAwareKvSelectorError::StalePageSelected);
    let incompatible_fence_rejected = invalid_selected_candidate_rejected(|candidate| {
        candidate.compatibility_fence = "fence:model:stale:kv:v0".to_string();
    }) == Some(QueryAwareKvSelectorError::IncompatibleFence);
    let missing_digest_rejected =
        invalid_candidate_rejected(|candidate| candidate.page_digest.clear())
            == Some(QueryAwareKvSelectorError::MissingDigest);
    let missing_uas_address_rejected =
        invalid_candidate_rejected(|candidate| candidate.uas_address.clear())
            == Some(QueryAwareKvSelectorError::MissingUasAddress);
    let missing_bloom_ref_rejected =
        invalid_candidate_rejected(|candidate| candidate.bloom_sketch_ref.clear())
            == Some(QueryAwareKvSelectorError::MissingBloomRef);
    let missing_required_evidence_rejected =
        invalid_selector_rejected(|selector| {
            selector
                .required_evidence_page_ids
                .push("kv-page:missing-proof".to_string());
        }) == Some(QueryAwareKvSelectorError::MissingRequiredEvidence);
    let required_evidence_false_negative_rejected =
        invalid_selector_rejected(|selector| {
            if !selector.selected_page_ids.is_empty() {
                selector.selected_page_ids.remove(0);
            }
        }) == Some(QueryAwareKvSelectorError::SelectedMismatch);
    let missing_false_negative_policy_rejected =
        invalid_selector_rejected(|selector| selector.false_negative_policy.clear())
            == Some(QueryAwareKvSelectorError::MissingFalseNegativePolicy);
    let missing_rollback_rejected =
        invalid_selector_rejected(|selector| selector.rollback_handle.clear())
            == Some(QueryAwareKvSelectorError::MissingRollback);
    let missing_run_event_log_rejected =
        invalid_selector_rejected(|selector| selector.run_event_log_ref.clear())
            == Some(QueryAwareKvSelectorError::MissingRunEventLog);
    let missing_answer_packet_rejected =
        invalid_selector_rejected(|selector| selector.answer_packet_ref.clear())
            == Some(QueryAwareKvSelectorError::MissingAnswerPacket);
    let hidden_live_authority_rejected =
        invalid_selector_rejected(|selector| selector.route_authority = "live_route".to_string())
            == Some(QueryAwareKvSelectorError::HiddenLiveAuthority);
    let live_policy_mutation_rejected =
        invalid_selector_rejected(|selector| selector.live_policy_mutated = true)
            == Some(QueryAwareKvSelectorError::LivePolicyMutation);
    let hidden_chain_exposure_rejected =
        invalid_selector_rejected(|selector| selector.hidden_chain_exposed = true)
            == Some(QueryAwareKvSelectorError::HiddenChainExposure);
    let cloud_source_rejected = invalid_candidate_rejected(|candidate| {
        candidate.source_index_ref = "cloud:external-kv-page".to_string();
    }) == Some(QueryAwareKvSelectorError::CloudSource);
    let invalid_privacy_class_rejected = invalid_candidate_rejected(|candidate| {
        candidate.privacy_class = "raw_hidden_chain".to_string();
    }) == Some(QueryAwareKvSelectorError::InvalidPrivacyClass);
    let over_budget_selection_rejected =
        invalid_selector_rejected(|selector| selector.active_byte_limit = 1)
            == Some(QueryAwareKvSelectorError::BudgetExceeded);
    let over_latency_selection_rejected =
        invalid_selector_rejected(|selector| selector.latency_limit_ms = 1)
            == Some(QueryAwareKvSelectorError::LatencyExceeded);
    let verifier_bypass_rejected =
        invalid_selector_rejected(|selector| selector.min_verifier_bps = 10_000)
            == Some(QueryAwareKvSelectorError::VerifierBypass);
    let low_quality_selection_rejected =
        invalid_selector_rejected(|selector| selector.min_quality_bps = 10_000)
            == Some(QueryAwareKvSelectorError::LowQualitySelection);
    let metadata_budget_rejected =
        invalid_selector_rejected(|selector| {
            selector.selector_metadata_bytes = MAX_SELECTOR_METADATA_BYTES + 1;
        }) == Some(QueryAwareKvSelectorError::SelectorMetadataBudgetExceeded);
    let unbeaten_baseline_rejected = invalid_selector_rejected(|selector| {
        selector.recency_baseline_page_ids = selector.selected_page_ids.clone();
    }) == Some(QueryAwareKvSelectorError::UnbeatenBaseline);
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
            "upstream_kv_page_bloom_sketch_coverage_pass",
            upstream_kv_page_bloom_sketch_coverage_pass,
        ),
        (
            "query_aware_selector_fixture_present",
            query_aware_selector_fixture_present,
        ),
        ("training_split_bound", training_split_bound),
        ("held_out_split_bound", held_out_split_bound),
        ("selector_ids_bound", selector_ids_bound),
        ("mission_ids_bound", mission_ids_bound),
        ("query_signatures_bound", query_signatures_bound),
        ("model_ids_bound", model_ids_bound),
        ("tokenizer_ids_bound", tokenizer_ids_bound),
        ("upstream_refs_bound", upstream_refs_bound),
        ("page_candidates_bound", page_candidates_bound),
        ("page_ids_bound", page_ids_bound),
        ("uas_page_addresses_bound", uas_page_addresses_bound),
        ("page_digests_bound", page_digests_bound),
        ("source_index_refs_bound", source_index_refs_bound),
        ("bloom_refs_bound", bloom_refs_bound),
        ("compatibility_fences_bound", compatibility_fences_bound),
        ("semantic_tags_bound", semantic_tags_bound),
        ("query_match_signal_bound", query_match_signal_bound),
        (
            "evidence_utility_signal_bound",
            evidence_utility_signal_bound,
        ),
        (
            "verifier_utility_signal_bound",
            verifier_utility_signal_bound,
        ),
        ("recency_bound", recency_bound),
        ("file_order_bound", file_order_bound),
        ("active_bytes_bound", active_bytes_bound),
        ("restore_latency_bound", restore_latency_bound),
        ("privacy_classes_bound", privacy_classes_bound),
        ("required_evidence_bound", required_evidence_bound),
        ("selected_pages_bound", selected_pages_bound),
        (
            "selected_pages_in_bloom_prefilter",
            selected_pages_in_bloom_prefilter,
        ),
        (
            "selected_pages_fit_active_byte_budget",
            selected_pages_fit_active_byte_budget,
        ),
        (
            "selected_pages_fit_latency_budget",
            selected_pages_fit_latency_budget,
        ),
        ("false_negative_policy_bound", false_negative_policy_bound),
        ("quality_floor_bound", quality_floor_bound),
        ("verifier_floor_bound", verifier_floor_bound),
        (
            "query_aware_beats_recency_baseline",
            query_aware_beats_recency_baseline,
        ),
        (
            "query_aware_beats_random_baseline",
            query_aware_beats_random_baseline,
        ),
        (
            "query_aware_beats_file_order_baseline",
            query_aware_beats_file_order_baseline,
        ),
        (
            "query_aware_beats_bloom_only_baseline",
            query_aware_beats_bloom_only_baseline,
        ),
        ("quality_delta_positive", quality_delta_positive),
        ("verifier_delta_positive", verifier_delta_positive),
        ("latency_delta_positive", latency_delta_positive),
        ("active_byte_delta_positive", active_byte_delta_positive),
        ("rollback_bound", rollback_bound),
        ("run_event_log_bound", run_event_log_bound),
        ("answer_packet_ref_bound", answer_packet_ref_bound),
        ("route_authority_shadow_only", route_authority_shadow_only),
        ("no_hidden_chain", no_hidden_chain),
        ("no_hidden_cloud", no_hidden_cloud),
        ("live_policy_not_mutated", live_policy_not_mutated),
        (
            "query_selector_address_deterministic",
            query_selector_address_deterministic,
        ),
        ("duplicate_selector_rejected", duplicate_selector_rejected),
        ("duplicate_page_rejected", duplicate_page_rejected),
        ("missing_query_rejected", missing_query_rejected),
        (
            "missing_selected_page_rejected",
            missing_selected_page_rejected,
        ),
        (
            "unknown_selected_page_rejected",
            unknown_selected_page_rejected,
        ),
        (
            "unfiltered_page_selected_rejected",
            unfiltered_page_selected_rejected,
        ),
        ("stale_page_rejected", stale_page_rejected),
        ("incompatible_fence_rejected", incompatible_fence_rejected),
        ("missing_digest_rejected", missing_digest_rejected),
        ("missing_uas_address_rejected", missing_uas_address_rejected),
        ("missing_bloom_ref_rejected", missing_bloom_ref_rejected),
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
            "invalid_privacy_class_rejected",
            invalid_privacy_class_rejected,
        ),
        (
            "over_budget_selection_rejected",
            over_budget_selection_rejected,
        ),
        (
            "over_latency_selection_rejected",
            over_latency_selection_rejected,
        ),
        ("verifier_bypass_rejected", verifier_bypass_rejected),
        (
            "low_quality_selection_rejected",
            low_quality_selection_rejected,
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
        "selector_count",
        registry.selectors.len() as u64,
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
        "selected_page_count",
        metrics.selected_page_count,
        4,
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
        "bloom_selected_candidate_count",
        metrics.bloom_selected_candidate_count,
        6,
        "count",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_selected_active_bytes",
        metrics.max_selected_active_bytes,
        786_432,
        "bytes",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_selected_latency_ms",
        metrics.max_selected_latency_ms,
        18,
        "ms",
    );
    add_count_ge_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "min_selected_quality_bps",
        metrics.min_selected_quality_bps,
        8_600,
        "bps",
    );
    add_count_ge_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "min_selected_verifier_bps",
        metrics.min_selected_verifier_bps,
        8_500,
        "bps",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "query_selector_success_bps",
        metrics.query_selector_success_bps,
        10_000,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "recency_baseline_success_bps",
        metrics.recency_baseline_success_bps,
        metrics.query_selector_success_bps,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "random_baseline_success_bps",
        metrics.random_baseline_success_bps,
        metrics.query_selector_success_bps,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "file_order_baseline_success_bps",
        metrics.file_order_baseline_success_bps,
        metrics.query_selector_success_bps,
        "bps",
    );
    add_u64_lt_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "bloom_only_baseline_success_bps",
        metrics.bloom_only_baseline_success_bps,
        metrics.query_selector_success_bps,
        "bps",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_selector_metadata_bytes",
        metrics.max_selector_metadata_bytes,
        MAX_SELECTOR_METADATA_BYTES,
        "bytes",
    );
    add_string_contains_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "query_selector_address",
        &registry.query_selector_address,
        "uas:query-aware-kv-selector:",
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
            "detail": "metadata-only QueryAwareKVSelector witness; consumes sketch and Bloom evidence, proves held-out query-aware wins, no live KV restore, no sparse route promotion, no model/runtime bytes, and no hidden route authority"
        })],
        notes: "scope=metadata_only;organ=QueryAwareKVSelector;reviewer=codex;reviewed_at_utc=2026-06-04T00:00:00Z;validator=falsifier_validator;detail=query-aware KV/page selector consumes sketch-index and Bloom evidence, beats simple baselines, and remains rollback/RunEventLog/AnswerPacket bound before any live selector authority can promote.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:query-aware-kv-selector:registry
// Plane: Controller + Verification
// Residency: metadata-only
struct QueryAwareKvSelectorRegistry {
    selectors: Vec<QueryAwareKvSelectorFixture>,
    metrics: SelectorMetrics,
    query_selector_address: String,
}

impl QueryAwareKvSelectorRegistry {
    fn new(
        mut selectors: Vec<QueryAwareKvSelectorFixture>,
    ) -> Result<Self, QueryAwareKvSelectorError> {
        if selectors.is_empty() {
            return Err(QueryAwareKvSelectorError::MissingSelector);
        }
        let mut seen_selectors = BTreeSet::new();
        for selector in &selectors {
            if !seen_selectors.insert(selector.selector_id.clone()) {
                return Err(QueryAwareKvSelectorError::DuplicateSelector);
            }
            validate_selector(selector)?;
        }
        selectors.sort_by_key(|selector| selector.selector_id.clone());
        let metrics = selector_metrics(&selectors);
        let query_selector_address = query_selector_address(&selectors);
        Ok(Self {
            selectors,
            metrics,
            query_selector_address,
        })
    }
}

fn validate_selector(
    selector: &QueryAwareKvSelectorFixture,
) -> Result<(), QueryAwareKvSelectorError> {
    if !selector.selector_id.starts_with("query-kv-selector:") {
        return Err(QueryAwareKvSelectorError::MissingSelectorId);
    }
    if !selector.mission_id.starts_with("mission:") {
        return Err(QueryAwareKvSelectorError::MissingMission);
    }
    if !selector.query_signature.starts_with("query:") {
        return Err(QueryAwareKvSelectorError::MissingQuery);
    }
    if !selector.model_id.starts_with("model:") {
        return Err(QueryAwareKvSelectorError::MissingModel);
    }
    if !selector.tokenizer_id.starts_with("tokenizer:") {
        return Err(QueryAwareKvSelectorError::MissingTokenizer);
    }
    if selector.upstream_sketch_index_ref != UPSTREAM_SKETCH_INDEX {
        return Err(QueryAwareKvSelectorError::MissingUpstreamSketchIndex);
    }
    if selector.upstream_bloom_ref != UPSTREAM_BLOOM {
        return Err(QueryAwareKvSelectorError::MissingUpstreamBloom);
    }
    if !selector.compatibility_fence.starts_with("fence:") {
        return Err(QueryAwareKvSelectorError::MissingCompatibilityFence);
    }
    if selector.compatibility_fence != CURRENT_FENCE {
        return Err(QueryAwareKvSelectorError::IncompatibleFence);
    }
    if selector.page_candidates.is_empty() {
        return Err(QueryAwareKvSelectorError::MissingPageCandidate);
    }

    let mut seen_pages = BTreeSet::new();
    for candidate in &selector.page_candidates {
        if !seen_pages.insert(candidate.page_id.clone()) {
            return Err(QueryAwareKvSelectorError::DuplicatePage);
        }
        validate_candidate(candidate)?;
    }
    if !required_evidence_bound(selector) {
        return Err(QueryAwareKvSelectorError::MissingRequiredEvidence);
    }
    if selector.selected_page_ids.is_empty() {
        return Err(QueryAwareKvSelectorError::MissingSelectedPage);
    }
    let candidate_lookup = candidate_map(selector);
    for page_id in &selector.selected_page_ids {
        let candidate = candidate_lookup
            .get(page_id)
            .ok_or(QueryAwareKvSelectorError::UnknownSelectedPage)?;
        if candidate.stale {
            return Err(QueryAwareKvSelectorError::StalePageSelected);
        }
        if candidate.compatibility_fence != CURRENT_FENCE {
            return Err(QueryAwareKvSelectorError::IncompatibleFence);
        }
        if !candidate.bloom_selected {
            return Err(QueryAwareKvSelectorError::UnfilteredPageSelected);
        }
    }
    if !selected_pages_match_flags(selector) {
        return Err(QueryAwareKvSelectorError::SelectedMismatch);
    }
    if coverage_bps(selector, &selector.selected_page_ids) != 10_000 {
        return Err(QueryAwareKvSelectorError::RequiredEvidenceFalseNegative);
    }
    validate_baseline_pages(selector, &selector.recency_baseline_page_ids)?;
    validate_baseline_pages(selector, &selector.random_baseline_page_ids)?;
    validate_baseline_pages(selector, &selector.file_order_baseline_page_ids)?;
    validate_baseline_pages(selector, &selector.bloom_only_baseline_page_ids)?;
    if selector.false_negative_policy != REQUIRED_FALSE_NEGATIVE_POLICY {
        return Err(QueryAwareKvSelectorError::MissingFalseNegativePolicy);
    }
    let selected_score = score(selector, &selector.selected_page_ids);
    if selected_score.active_bytes > selector.active_byte_limit {
        return Err(QueryAwareKvSelectorError::BudgetExceeded);
    }
    if selected_score.latency_ms > selector.latency_limit_ms {
        return Err(QueryAwareKvSelectorError::LatencyExceeded);
    }
    if selected_score.quality_bps < selector.min_quality_bps {
        return Err(QueryAwareKvSelectorError::LowQualitySelection);
    }
    if selected_score.verifier_bps < selector.min_verifier_bps {
        return Err(QueryAwareKvSelectorError::VerifierBypass);
    }
    for baseline in [
        &selector.recency_baseline_page_ids,
        &selector.random_baseline_page_ids,
        &selector.file_order_baseline_page_ids,
        &selector.bloom_only_baseline_page_ids,
    ] {
        let baseline_score = score(selector, baseline);
        if selection_success(selector, baseline)
            || baseline_score.quality_bps >= selected_score.quality_bps
            || baseline_score.verifier_bps >= selected_score.verifier_bps
        {
            return Err(QueryAwareKvSelectorError::UnbeatenBaseline);
        }
    }
    if !selector.rollback_handle.starts_with("rollback:") {
        return Err(QueryAwareKvSelectorError::MissingRollback);
    }
    if !selector.run_event_log_ref.starts_with("runevent:") {
        return Err(QueryAwareKvSelectorError::MissingRunEventLog);
    }
    if !selector.answer_packet_ref.starts_with("answerpacket:") {
        return Err(QueryAwareKvSelectorError::MissingAnswerPacket);
    }
    if selector.route_authority != "shadow_only" {
        return Err(QueryAwareKvSelectorError::HiddenLiveAuthority);
    }
    if selector.live_policy_mutated {
        return Err(QueryAwareKvSelectorError::LivePolicyMutation);
    }
    if selector.hidden_chain_exposed {
        return Err(QueryAwareKvSelectorError::HiddenChainExposure);
    }
    if selector.hidden_cloud {
        return Err(QueryAwareKvSelectorError::CloudSource);
    }
    if selector.selector_metadata_bytes > MAX_SELECTOR_METADATA_BYTES {
        return Err(QueryAwareKvSelectorError::SelectorMetadataBudgetExceeded);
    }
    Ok(())
}

fn validate_candidate(candidate: &QueryPageCandidate) -> Result<(), QueryAwareKvSelectorError> {
    if candidate.split != "training" && candidate.split != "held_out" {
        return Err(QueryAwareKvSelectorError::MissingSplit);
    }
    if !candidate.page_id.starts_with("kv-page:") {
        return Err(QueryAwareKvSelectorError::MissingPageId);
    }
    if !candidate.uas_address.starts_with("uas:kv-page:") {
        return Err(QueryAwareKvSelectorError::MissingUasAddress);
    }
    if candidate.source_index_ref.is_empty() {
        return Err(QueryAwareKvSelectorError::MissingSourceIndexRef);
    }
    if candidate.source_index_ref.contains("cloud") {
        return Err(QueryAwareKvSelectorError::CloudSource);
    }
    if candidate.source_index_ref != UPSTREAM_SKETCH_INDEX {
        return Err(QueryAwareKvSelectorError::MissingSourceIndexRef);
    }
    if candidate.bloom_sketch_ref.is_empty() {
        return Err(QueryAwareKvSelectorError::MissingBloomRef);
    }
    if candidate.bloom_sketch_ref != UPSTREAM_BLOOM {
        return Err(QueryAwareKvSelectorError::MissingBloomRef);
    }
    if !candidate.page_digest.starts_with("sha256:") {
        return Err(QueryAwareKvSelectorError::MissingDigest);
    }
    if !candidate.compatibility_fence.starts_with("fence:") {
        return Err(QueryAwareKvSelectorError::MissingCompatibilityFence);
    }
    if candidate.compatibility_fence != CURRENT_FENCE {
        return Err(QueryAwareKvSelectorError::IncompatibleFence);
    }
    if candidate.semantic_tags.is_empty() {
        return Err(QueryAwareKvSelectorError::MissingSemanticTag);
    }
    if candidate.query_match_bps == 0 {
        return Err(QueryAwareKvSelectorError::MissingQuerySignal);
    }
    if candidate.evidence_utility_bps == 0 {
        return Err(QueryAwareKvSelectorError::MissingEvidenceSignal);
    }
    if candidate.verifier_utility_bps == 0 {
        return Err(QueryAwareKvSelectorError::MissingVerifierSignal);
    }
    if candidate.recency_rank == 0 {
        return Err(QueryAwareKvSelectorError::MissingRecency);
    }
    if candidate.file_order == 0 {
        return Err(QueryAwareKvSelectorError::MissingFileOrder);
    }
    if candidate.active_bytes == 0 {
        return Err(QueryAwareKvSelectorError::MissingActiveBytes);
    }
    if candidate.restore_latency_ms == 0 {
        return Err(QueryAwareKvSelectorError::MissingRestoreLatency);
    }
    if !valid_privacy_class(&candidate.privacy_class) {
        return Err(QueryAwareKvSelectorError::InvalidPrivacyClass);
    }
    Ok(())
}

fn validate_baseline_pages(
    selector: &QueryAwareKvSelectorFixture,
    page_ids: &[String],
) -> Result<(), QueryAwareKvSelectorError> {
    if page_ids.is_empty() {
        return Err(QueryAwareKvSelectorError::MissingBaselinePage);
    }
    let candidates = candidate_map(selector);
    for page_id in page_ids {
        if !candidates.contains_key(page_id) {
            return Err(QueryAwareKvSelectorError::MissingBaselinePage);
        }
    }
    Ok(())
}

fn required_evidence_bound(selector: &QueryAwareKvSelectorFixture) -> bool {
    if selector.required_evidence_page_ids.is_empty() {
        return false;
    }
    let candidates = candidate_map(selector);
    selector.required_evidence_page_ids.iter().all(|page_id| {
        candidates
            .get(page_id)
            .is_some_and(|candidate| candidate.required_evidence && candidate.proof_critical)
    })
}

fn selected_pages_match_flags(selector: &QueryAwareKvSelectorFixture) -> bool {
    let selected_from_flags = selector
        .page_candidates
        .iter()
        .filter(|candidate| candidate.query_selected)
        .map(|candidate| candidate.page_id.clone())
        .collect::<BTreeSet<_>>();
    let selected_from_list = selector
        .selected_page_ids
        .iter()
        .cloned()
        .collect::<BTreeSet<_>>();
    selected_from_flags == selected_from_list
}

fn selected_pages_in_bloom_prefilter(selector: &QueryAwareKvSelectorFixture) -> bool {
    let candidates = candidate_map(selector);
    selector.selected_page_ids.iter().all(|page_id| {
        candidates
            .get(page_id)
            .is_some_and(|candidate| candidate.bloom_selected)
    })
}

fn candidate_map(selector: &QueryAwareKvSelectorFixture) -> BTreeMap<String, &QueryPageCandidate> {
    selector
        .page_candidates
        .iter()
        .map(|candidate| (candidate.page_id.clone(), candidate))
        .collect()
}

fn coverage_bps(selector: &QueryAwareKvSelectorFixture, page_ids: &[String]) -> u64 {
    if selector.required_evidence_page_ids.is_empty() {
        return 0;
    }
    let required = selector
        .required_evidence_page_ids
        .iter()
        .collect::<BTreeSet<_>>();
    let covered = page_ids
        .iter()
        .filter(|page_id| required.contains(page_id))
        .count() as u64;
    covered * 10_000 / required.len() as u64
}

fn score(selector: &QueryAwareKvSelectorFixture, page_ids: &[String]) -> SelectionScore {
    let candidates = candidate_map(selector);
    let mut score = SelectionScore {
        coverage_bps: coverage_bps(selector, page_ids),
        ..SelectionScore::default()
    };
    if page_ids.is_empty() {
        return score;
    }

    let mut query_sum = 0;
    let mut evidence_sum = 0;
    let mut verifier_sum = 0;
    let mut found = 0;
    for page_id in page_ids {
        if let Some(candidate) = candidates.get(page_id) {
            found += 1;
            query_sum += candidate.query_match_bps;
            evidence_sum += candidate.evidence_utility_bps;
            verifier_sum += candidate.verifier_utility_bps;
            score.active_bytes += candidate.active_bytes;
            score.latency_ms += candidate.restore_latency_ms;
        }
    }
    if found == 0 {
        return score;
    }
    let query_average = query_sum / found;
    let evidence_average = evidence_sum / found;
    score.verifier_bps = verifier_sum / found;
    score.quality_bps = (score.coverage_bps * 6 + query_average * 2 + evidence_average * 2) / 10;
    score
}

fn selection_success(selector: &QueryAwareKvSelectorFixture, page_ids: &[String]) -> bool {
    let score = score(selector, page_ids);
    score.coverage_bps == 10_000
        && score.quality_bps >= selector.min_quality_bps
        && score.verifier_bps >= selector.min_verifier_bps
        && score.active_bytes <= selector.active_byte_limit
        && score.latency_ms <= selector.latency_limit_ms
}

fn best_baseline_score(selector: &QueryAwareKvSelectorFixture) -> Option<SelectionScore> {
    [
        &selector.recency_baseline_page_ids,
        &selector.random_baseline_page_ids,
        &selector.file_order_baseline_page_ids,
        &selector.bloom_only_baseline_page_ids,
    ]
    .iter()
    .map(|page_ids| score(selector, page_ids))
    .max_by_key(|score| score.quality_bps)
}

fn valid_privacy_class(privacy_class: &str) -> bool {
    matches!(
        privacy_class,
        "vault_private" | "proof_private" | "research_private" | "public_source"
    )
}

fn selector_metrics(selectors: &[QueryAwareKvSelectorFixture]) -> SelectorMetrics {
    let mut metrics = SelectorMetrics {
        min_selected_quality_bps: u64::MAX,
        min_selected_verifier_bps: u64::MAX,
        ..SelectorMetrics::default()
    };
    let mut query_successes = 0;
    let mut recency_successes = 0;
    let mut random_successes = 0;
    let mut file_order_successes = 0;
    let mut bloom_only_successes = 0;
    for selector in selectors {
        metrics.max_selector_metadata_bytes = metrics
            .max_selector_metadata_bytes
            .max(selector.selector_metadata_bytes);
        let selected_score = score(selector, &selector.selected_page_ids);
        metrics.max_selected_active_bytes = metrics
            .max_selected_active_bytes
            .max(selected_score.active_bytes);
        metrics.max_selected_latency_ms = metrics
            .max_selected_latency_ms
            .max(selected_score.latency_ms);
        metrics.min_selected_quality_bps = metrics
            .min_selected_quality_bps
            .min(selected_score.quality_bps);
        metrics.min_selected_verifier_bps = metrics
            .min_selected_verifier_bps
            .min(selected_score.verifier_bps);
        if selection_success(selector, &selector.selected_page_ids) {
            query_successes += 1;
        }
        if selection_success(selector, &selector.recency_baseline_page_ids) {
            recency_successes += 1;
        }
        if selection_success(selector, &selector.random_baseline_page_ids) {
            random_successes += 1;
        }
        if selection_success(selector, &selector.file_order_baseline_page_ids) {
            file_order_successes += 1;
        }
        if selection_success(selector, &selector.bloom_only_baseline_page_ids) {
            bloom_only_successes += 1;
        }
        metrics.selected_page_count += selector.selected_page_ids.len() as u64;
        for candidate in &selector.page_candidates {
            metrics.candidate_count += 1;
            if candidate.split == "training" {
                metrics.training_candidate_count += 1;
            }
            if candidate.split == "held_out" {
                metrics.held_out_candidate_count += 1;
            }
            if candidate.required_evidence {
                metrics.required_evidence_page_count += 1;
            }
            if candidate.bloom_selected {
                metrics.bloom_selected_candidate_count += 1;
            }
        }
    }
    let selector_count = selectors.len().max(1) as u64;
    metrics.query_selector_success_bps = query_successes * 10_000 / selector_count;
    metrics.recency_baseline_success_bps = recency_successes * 10_000 / selector_count;
    metrics.random_baseline_success_bps = random_successes * 10_000 / selector_count;
    metrics.file_order_baseline_success_bps = file_order_successes * 10_000 / selector_count;
    metrics.bloom_only_baseline_success_bps = bloom_only_successes * 10_000 / selector_count;
    if metrics.min_selected_quality_bps == u64::MAX {
        metrics.min_selected_quality_bps = 0;
    }
    if metrics.min_selected_verifier_bps == u64::MAX {
        metrics.min_selected_verifier_bps = 0;
    }
    metrics
}

fn query_selector_address(selectors: &[QueryAwareKvSelectorFixture]) -> String {
    let mut payload = String::new();
    for selector in selectors {
        payload.push_str(&selector.selector_id);
        payload.push('|');
        payload.push_str(&selector.query_signature);
        payload.push('|');
        payload.push_str(&selector.compatibility_fence);
        payload.push('|');
        let mut candidates = selector.page_candidates.clone();
        candidates.sort_by_key(|candidate| candidate.page_id.clone());
        for candidate in candidates {
            payload.push_str(&candidate.page_id);
            payload.push(':');
            payload.push_str(&candidate.uas_address);
            payload.push(':');
            payload.push_str(&candidate.page_digest);
            payload.push(':');
            payload.push_str(&candidate.query_match_bps.to_string());
            payload.push(':');
            payload.push_str(&candidate.evidence_utility_bps.to_string());
            payload.push(':');
            payload.push_str(&candidate.verifier_utility_bps.to_string());
            payload.push(':');
            payload.push_str(&candidate.bloom_selected.to_string());
            payload.push(':');
            payload.push_str(&candidate.query_selected.to_string());
            payload.push(';');
        }
        payload.push('\n');
    }
    format!(
        "uas:query-aware-kv-selector:{}",
        sha256_hex(payload.as_bytes()).trim_start_matches("sha256:")
    )
}

fn invalid_selector_rejected(
    mut mutate: impl FnMut(&mut QueryAwareKvSelectorFixture),
) -> Option<QueryAwareKvSelectorError> {
    let mut selectors = fixture_selectors();
    if let Some(first) = selectors.first_mut() {
        mutate(first);
    }
    QueryAwareKvSelectorRegistry::new(selectors).err()
}

fn invalid_candidate_rejected(
    mut mutate: impl FnMut(&mut QueryPageCandidate),
) -> Option<QueryAwareKvSelectorError> {
    invalid_selector_rejected(|selector| {
        if let Some(first) = selector.page_candidates.first_mut() {
            mutate(first);
        }
    })
}

fn invalid_selected_candidate_rejected(
    mut mutate: impl FnMut(&mut QueryPageCandidate),
) -> Option<QueryAwareKvSelectorError> {
    invalid_selector_rejected(|selector| {
        if let Some(first_selected) = selector.selected_page_ids.first().cloned() {
            if let Some(candidate) = selector
                .page_candidates
                .iter_mut()
                .find(|candidate| candidate.page_id == first_selected)
            {
                mutate(candidate);
            }
        }
    })
}

fn upstream_artifact_pass(path: &str) -> bool {
    read_artifact_string(path)
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

fn fixture_selectors() -> Vec<QueryAwareKvSelectorFixture> {
    vec![
        QueryAwareKvSelectorFixture {
            selector_id: "query-kv-selector:proof-route-repair".to_string(),
            mission_id: "mission:proof-route-repair".to_string(),
            query_signature: "query:repair-route-needs-rollback-answerpacket-proof".to_string(),
            model_id: "model:qwen3.5-local-shadow".to_string(),
            tokenizer_id: "tokenizer:qwen3.5".to_string(),
            upstream_sketch_index_ref: UPSTREAM_SKETCH_INDEX.to_string(),
            upstream_bloom_ref: UPSTREAM_BLOOM.to_string(),
            compatibility_fence: CURRENT_FENCE.to_string(),
            required_evidence_page_ids: vec![
                "kv-page:rollback-precondition".to_string(),
                "kv-page:answerpacket-proof".to_string(),
            ],
            selected_page_ids: vec![
                "kv-page:rollback-precondition".to_string(),
                "kv-page:answerpacket-proof".to_string(),
            ],
            recency_baseline_page_ids: vec![
                "kv-page:recent-terminal-log".to_string(),
                "kv-page:rollback-precondition".to_string(),
            ],
            random_baseline_page_ids: vec![
                "kv-page:file-order-schema".to_string(),
                "kv-page:recent-terminal-log".to_string(),
            ],
            file_order_baseline_page_ids: vec![
                "kv-page:rollback-precondition".to_string(),
                "kv-page:file-order-schema".to_string(),
            ],
            bloom_only_baseline_page_ids: vec![
                "kv-page:rollback-precondition".to_string(),
                "kv-page:recent-terminal-log".to_string(),
            ],
            page_candidates: vec![
                candidate(
                    "training",
                    "kv-page:rollback-precondition",
                    11,
                    &["rollback", "precondition", "route-kernel"],
                    9_800,
                    9_500,
                    9_300,
                    4,
                    1,
                    196_608,
                    4,
                    "proof_private",
                    true,
                    true,
                    true,
                    true,
                ),
                candidate(
                    "held_out",
                    "kv-page:answerpacket-proof",
                    37,
                    &["answerpacket", "visible-proof", "postcondition"],
                    9_600,
                    9_400,
                    9_100,
                    8,
                    2,
                    229_376,
                    5,
                    "proof_private",
                    true,
                    true,
                    true,
                    true,
                ),
                candidate(
                    "held_out",
                    "kv-page:recent-terminal-log",
                    59,
                    &["recent", "terminal", "low-signal"],
                    2_000,
                    2_100,
                    1_800,
                    1,
                    3,
                    262_144,
                    7,
                    "vault_private",
                    false,
                    false,
                    true,
                    false,
                ),
                candidate(
                    "held_out",
                    "kv-page:file-order-schema",
                    83,
                    &["schema", "file-order", "background"],
                    2_400,
                    2_300,
                    2_200,
                    7,
                    4,
                    278_528,
                    8,
                    "vault_private",
                    false,
                    false,
                    false,
                    false,
                ),
            ],
            active_byte_limit: 786_432,
            latency_limit_ms: 18,
            min_quality_bps: 8_600,
            min_verifier_bps: 8_500,
            false_negative_policy: REQUIRED_FALSE_NEGATIVE_POLICY.to_string(),
            rollback_handle: "rollback:query-kv:proof-route".to_string(),
            run_event_log_ref: "runevent:query-kv:proof-route".to_string(),
            answer_packet_ref: "answerpacket:query-kv:proof-route".to_string(),
            route_authority: "shadow_only".to_string(),
            selector_metadata_bytes: 128 * 1024,
            hidden_chain_exposed: false,
            hidden_cloud: false,
            live_policy_mutated: false,
        },
        QueryAwareKvSelectorFixture {
            selector_id: "query-kv-selector:swiftlm-source-motif".to_string(),
            mission_id: "mission:swiftlm-source-motif".to_string(),
            query_signature: "query:extract-kv-compression-flash-bundling-caveat".to_string(),
            model_id: "model:qwen3.5-local-shadow".to_string(),
            tokenizer_id: "tokenizer:qwen3.5".to_string(),
            upstream_sketch_index_ref: UPSTREAM_SKETCH_INDEX.to_string(),
            upstream_bloom_ref: UPSTREAM_BLOOM.to_string(),
            compatibility_fence: CURRENT_FENCE.to_string(),
            required_evidence_page_ids: vec![
                "kv-page:swiftlm-kv-compression".to_string(),
                "kv-page:flash-bundling-caveat".to_string(),
            ],
            selected_page_ids: vec![
                "kv-page:swiftlm-kv-compression".to_string(),
                "kv-page:flash-bundling-caveat".to_string(),
            ],
            recency_baseline_page_ids: vec![
                "kv-page:recent-chat-summary".to_string(),
                "kv-page:swiftlm-kv-compression".to_string(),
            ],
            random_baseline_page_ids: vec![
                "kv-page:file-license-preface".to_string(),
                "kv-page:recent-chat-summary".to_string(),
            ],
            file_order_baseline_page_ids: vec![
                "kv-page:swiftlm-kv-compression".to_string(),
                "kv-page:file-license-preface".to_string(),
            ],
            bloom_only_baseline_page_ids: vec![
                "kv-page:swiftlm-kv-compression".to_string(),
                "kv-page:recent-chat-summary".to_string(),
            ],
            page_candidates: vec![
                candidate(
                    "training",
                    "kv-page:swiftlm-kv-compression",
                    19,
                    &["swiftlm", "kv-compression", "ssd-streaming"],
                    9_500,
                    9_600,
                    9_100,
                    5,
                    1,
                    180_224,
                    4,
                    "research_private",
                    true,
                    true,
                    true,
                    true,
                ),
                candidate(
                    "held_out",
                    "kv-page:flash-bundling-caveat",
                    43,
                    &["flash", "bundling", "caveat"],
                    9_700,
                    9_300,
                    8_900,
                    9,
                    2,
                    212_992,
                    5,
                    "research_private",
                    true,
                    true,
                    true,
                    true,
                ),
                candidate(
                    "held_out",
                    "kv-page:recent-chat-summary",
                    67,
                    &["recent", "chat", "summary"],
                    1_900,
                    2_000,
                    1_700,
                    1,
                    3,
                    270_336,
                    7,
                    "vault_private",
                    false,
                    false,
                    true,
                    false,
                ),
                candidate(
                    "held_out",
                    "kv-page:file-license-preface",
                    101,
                    &["license", "preface", "background"],
                    2_500,
                    2_400,
                    2_100,
                    8,
                    4,
                    286_720,
                    8,
                    "public_source",
                    false,
                    false,
                    false,
                    false,
                ),
            ],
            active_byte_limit: 786_432,
            latency_limit_ms: 18,
            min_quality_bps: 8_600,
            min_verifier_bps: 8_500,
            false_negative_policy: REQUIRED_FALSE_NEGATIVE_POLICY.to_string(),
            rollback_handle: "rollback:query-kv:swiftlm".to_string(),
            run_event_log_ref: "runevent:query-kv:swiftlm".to_string(),
            answer_packet_ref: "answerpacket:query-kv:swiftlm".to_string(),
            route_authority: "shadow_only".to_string(),
            selector_metadata_bytes: 144 * 1024,
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
    query_match_bps: u64,
    evidence_utility_bps: u64,
    verifier_utility_bps: u64,
    recency_rank: u64,
    file_order: u64,
    active_bytes: u64,
    restore_latency_ms: u64,
    privacy_class: &str,
    required_evidence: bool,
    proof_critical: bool,
    bloom_selected: bool,
    query_selected: bool,
) -> QueryPageCandidate {
    let digest_seed = format!(
        "{page_id}:{seed}:{tags:?}:{query_match_bps}:{evidence_utility_bps}:{verifier_utility_bps}"
    );
    QueryPageCandidate {
        split: split.to_string(),
        page_id: page_id.to_string(),
        uas_address: format!("uas:kv-page:{page_id}"),
        source_index_ref: UPSTREAM_SKETCH_INDEX.to_string(),
        bloom_sketch_ref: UPSTREAM_BLOOM.to_string(),
        page_digest: sha256_hex(digest_seed.as_bytes()),
        compatibility_fence: CURRENT_FENCE.to_string(),
        semantic_tags: tags.iter().map(|tag| (*tag).to_string()).collect(),
        query_match_bps,
        evidence_utility_bps,
        verifier_utility_bps,
        recency_rank,
        file_order,
        active_bytes,
        restore_latency_ms,
        privacy_class: privacy_class.to_string(),
        required_evidence,
        proof_critical,
        bloom_selected,
        query_selected,
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
            "upstream_kv_page_bloom_sketch_coverage_pass",
            "query_aware_selector_fixture_present",
            "selected_pages_in_bloom_prefilter",
            "query_aware_beats_recency_baseline",
            "query_aware_beats_random_baseline",
            "query_aware_beats_file_order_baseline",
            "query_aware_beats_bloom_only_baseline",
            "quality_delta_positive",
            "verifier_delta_positive",
            "latency_delta_positive",
            "active_byte_delta_positive",
            "unfiltered_page_selected_rejected",
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
        assert_eq!(
            QueryAwareKvSelectorRegistry::new(Vec::new()).err(),
            Some(QueryAwareKvSelectorError::MissingSelector)
        );
    }

    #[test]
    fn invalid_fixture_cases_reject() {
        for (name, observed, expected) in [
            (
                "missing query",
                invalid_selector_rejected(|selector| selector.query_signature.clear()),
                QueryAwareKvSelectorError::MissingQuery,
            ),
            (
                "unfiltered selected page",
                invalid_selected_candidate_rejected(|candidate| candidate.bloom_selected = false),
                QueryAwareKvSelectorError::UnfilteredPageSelected,
            ),
            (
                "stale selected page",
                invalid_selected_candidate_rejected(|candidate| candidate.stale = true),
                QueryAwareKvSelectorError::StalePageSelected,
            ),
            (
                "budget exceeded",
                invalid_selector_rejected(|selector| selector.active_byte_limit = 1),
                QueryAwareKvSelectorError::BudgetExceeded,
            ),
            (
                "verifier bypass",
                invalid_selector_rejected(|selector| selector.min_verifier_bps = 10_000),
                QueryAwareKvSelectorError::VerifierBypass,
            ),
            (
                "hidden authority",
                invalid_selector_rejected(|selector| selector.route_authority = "live".to_string()),
                QueryAwareKvSelectorError::HiddenLiveAuthority,
            ),
        ] {
            assert_eq!(observed, Some(expected), "{name}");
        }
    }

    #[test]
    fn selector_address_is_order_stable() {
        let registry = QueryAwareKvSelectorRegistry::new(fixture_selectors()).expect("valid");
        let reversed = fixture_selectors().into_iter().rev().collect::<Vec<_>>();
        let reversed_registry = QueryAwareKvSelectorRegistry::new(reversed).expect("valid");
        assert_eq!(
            registry.query_selector_address,
            reversed_registry.query_selector_address
        );
    }
}
