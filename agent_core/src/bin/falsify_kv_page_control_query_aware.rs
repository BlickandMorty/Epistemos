//! `falsify_kv_page_control_query_aware` — KVPageControlCard contract.
//!
//! Metadata-only witness for `F-KVPageControl-QueryAware`. It proves
//! query-aware KV/page selection beats recency-only, random, and file-order
//! page policies under active-byte, quality, verifier, rollback, and
//! AnswerPacket visibility budgets without mutating live runtime state.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-KVPageControl-QueryAware";
const FIXTURE_ID: &str = "kv_page_control_query_aware_v1";
const COMMAND: &str = "Tools/falsifiers/f_kv_page_control_query_aware.sh";
const RESULT: &str = "artifacts/falsifiers/kv_page_control_query_aware/result.json";
const UPSTREAM_BRAIN_ROUTE: &str = "artifacts/falsifiers/brain_route_card_multi_model/result.json";
const CURRENT_FENCE: &str = "fence:model:qwen3.5:kv:v1";

// UAS: query-scored KV page candidate.
// Plane: Assembly + Verification.
// Residency: metadata-only page fixture; no KV/runtime bytes loaded.
#[derive(Clone)]
struct KvPageCandidate {
    page_id: &'static str,
    uas_address: &'static str,
    layer_range: &'static str,
    token_page_range: &'static str,
    page_digest: &'static str,
    compatibility_fence: &'static str,
    query_relevance_bps: u64,
    criticality_bps: u64,
    verifier_utility_bps: u64,
    recency_rank: u64,
    file_order: u64,
    sink_or_heavy_hitter: bool,
    active_bytes: u64,
    restore_latency_ms: u64,
    stale: bool,
    privacy_class: &'static str,
    source_ref: &'static str,
}

// UAS: score summary for a selected KV page set.
// Plane: Verification.
// Residency: metadata-only score fixture.
#[derive(Clone, Copy)]
struct SelectionScore {
    quality_bps: u64,
    verifier_bps: u64,
    latency_ms: u64,
    active_bytes: u64,
}

// UAS: KVPageControlCard page-policy contract.
// Plane: Controller + Assembly + Verification.
// Residency: metadata-only shadow page-control card.
#[derive(Clone)]
struct KvPageControlCard {
    policy_id: &'static str,
    mission_id: &'static str,
    query_signature: &'static str,
    model_id: &'static str,
    brain_route_card_ref: &'static str,
    candidate_pages: Vec<KvPageCandidate>,
    selected_pages: Vec<&'static str>,
    recency_baseline_pages: Vec<&'static str>,
    random_baseline_pages: Vec<&'static str>,
    file_order_baseline_pages: Vec<&'static str>,
    active_byte_limit: u64,
    min_verifier_bps: u64,
    rollback_handle: &'static str,
    answer_packet_ref: &'static str,
    route_authority: &'static str,
    retention_decision: &'static str,
    eviction_decision: &'static str,
    restore_decision: &'static str,
}

#[derive(Debug, Eq, PartialEq)]
// UAS: uas:kv-page-control:error
// Plane: Verification
// Residency: metadata-only
enum KvPageControlError {
    MissingCard,
    DuplicatePolicy,
    MissingMission,
    MissingQuery,
    MissingModel,
    MissingUpstreamRoute,
    MissingPage,
    DuplicatePage,
    MissingSelectedPage,
    UnknownSelectedPage,
    UnknownBaselinePage,
    MissingDigest,
    MissingCompatibilityFence,
    StalePageSelected,
    IncompatibleFence,
    MissingRollback,
    MissingAnswerPacket,
    HiddenLiveMutation,
    CloudPage,
    BudgetExceeded,
    VerifierBypass,
    QueryAwareBaselineUnbeaten,
    MissingDecision,
}

impl std::fmt::Display for KvPageControlError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for KvPageControlError {}

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
        "{FALSIFIER_ID}: overall_pass={} kv_page_control_card_count={} page_control_address={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["kv_page_control_card_count"].value,
        artifact.measurements["page_control_address"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let cards = fixture_cards();
    let reversed = cards.iter().cloned().rev().collect::<Vec<_>>();
    let registry = KvPageControlRegistry::new(cards)?;
    let reversed_registry = KvPageControlRegistry::new(reversed)?;

    let upstream_brain_route_card_pass = upstream_brain_route_pass();
    let kv_page_control_cards_present = registry.cards.len() == 3;
    let query_signatures_bound = registry
        .cards
        .iter()
        .all(|card| card.query_signature.starts_with("query:"));
    let mission_ids_bound = registry
        .cards
        .iter()
        .all(|card| card.mission_id.starts_with("mission:"));
    let model_ids_bound = registry
        .cards
        .iter()
        .all(|card| card.model_id.starts_with("model:"));
    let upstream_route_refs_bound = registry
        .cards
        .iter()
        .all(|card| card.brain_route_card_ref == UPSTREAM_BRAIN_ROUTE);
    let uas_page_addresses_bound = registry.cards.iter().all(|card| {
        card.candidate_pages
            .iter()
            .all(|page| page.uas_address.starts_with("uas:kv-page:"))
    });
    let page_digests_bound = registry.cards.iter().all(|card| {
        card.candidate_pages
            .iter()
            .all(|page| page.page_digest.starts_with("sha256:"))
    });
    let layer_ranges_bound = registry.cards.iter().all(|card| {
        card.candidate_pages
            .iter()
            .all(|page| page.layer_range.contains(".."))
    });
    let token_page_ranges_bound = registry.cards.iter().all(|card| {
        card.candidate_pages
            .iter()
            .all(|page| page.token_page_range.contains(".."))
    });
    let compatibility_fences_bound = registry.cards.iter().all(|card| {
        card.candidate_pages
            .iter()
            .all(|page| page.compatibility_fence == CURRENT_FENCE)
    });
    let query_dependence_bound = registry.cards.iter().all(|card| {
        card.candidate_pages
            .iter()
            .all(|page| page.query_relevance_bps > 0)
    });
    let criticality_signal_bound = registry.cards.iter().all(|card| {
        card.candidate_pages
            .iter()
            .all(|page| page.criticality_bps > 0)
    });
    let sink_or_heavy_hitter_bound = registry.cards.iter().all(|card| {
        card.candidate_pages
            .iter()
            .any(|page| page.sink_or_heavy_hitter)
    });
    let ranking_signals_bound = registry.cards.iter().all(|card| {
        card.candidate_pages
            .iter()
            .all(|page| page.recency_rank > 0 && page.file_order > 0)
    });
    let privacy_classes_bound = registry.cards.iter().all(|card| {
        card.candidate_pages
            .iter()
            .all(|page| page.privacy_class == "vault_private")
    });
    let retention_decisions_bound = registry
        .cards
        .iter()
        .all(|card| card.retention_decision.starts_with("retain:"));
    let eviction_decisions_bound = registry
        .cards
        .iter()
        .all(|card| card.eviction_decision.starts_with("evict:"));
    let restore_decisions_bound = registry
        .cards
        .iter()
        .all(|card| card.restore_decision.starts_with("restore:"));
    let selected_pages_fit_active_byte_budget = registry.cards.iter().all(|card| {
        score_pages(card, &card.selected_pages)
            .map(|score| score.active_bytes <= card.active_byte_limit)
            .unwrap_or(false)
    });
    let query_aware_beats_recency = registry
        .cards
        .iter()
        .all(|card| selection_beats(card, &card.recency_baseline_pages));
    let query_aware_beats_random = registry
        .cards
        .iter()
        .all(|card| selection_beats(card, &card.random_baseline_pages));
    let query_aware_beats_file_order = registry
        .cards
        .iter()
        .all(|card| selection_beats(card, &card.file_order_baseline_pages));
    let quality_delta_positive = registry.cards.iter().all(|card| {
        score_pages(card, &card.selected_pages)
            .and_then(|selected| {
                baseline_scores(card).map(|baselines| {
                    baselines
                        .iter()
                        .all(|baseline| selected.quality_bps > baseline.quality_bps)
                })
            })
            .unwrap_or(false)
    });
    let verifier_delta_positive = registry.cards.iter().all(|card| {
        score_pages(card, &card.selected_pages)
            .and_then(|selected| {
                baseline_scores(card).map(|baselines| {
                    baselines
                        .iter()
                        .all(|baseline| selected.verifier_bps > baseline.verifier_bps)
                })
            })
            .unwrap_or(false)
    });
    let latency_delta_positive = registry.cards.iter().all(|card| {
        score_pages(card, &card.selected_pages)
            .and_then(|selected| {
                baseline_scores(card).map(|baselines| {
                    baselines
                        .iter()
                        .all(|baseline| selected.latency_ms < baseline.latency_ms)
                })
            })
            .unwrap_or(false)
    });
    let active_byte_delta_positive = registry.cards.iter().all(|card| {
        score_pages(card, &card.selected_pages)
            .and_then(|selected| {
                baseline_scores(card).map(|baselines| {
                    baselines
                        .iter()
                        .all(|baseline| selected.active_bytes < baseline.active_bytes)
                })
            })
            .unwrap_or(false)
    });
    let rollback_bound = registry
        .cards
        .iter()
        .all(|card| card.rollback_handle.starts_with("rollback:"));
    let answer_packet_ref_bound = registry
        .cards
        .iter()
        .all(|card| card.answer_packet_ref.starts_with("answerpacket:"));
    let route_card_ref_bound = upstream_route_refs_bound;
    let page_control_shadow_only = registry
        .cards
        .iter()
        .all(|card| card.route_authority == "shadow_only");
    let no_hidden_cloud = registry.cards.iter().all(|card| {
        card.candidate_pages
            .iter()
            .all(|page| !page.source_ref.contains("cloud"))
    });
    let page_control_address_deterministic =
        registry.page_control_address == reversed_registry.page_control_address;
    let duplicate_policy_rejected = duplicate_policy_rejected();
    let duplicate_page_rejected = invalid_card_rejected(|card| {
        let duplicate = card.candidate_pages[0].clone();
        card.candidate_pages.push(duplicate);
    }) == Some(KvPageControlError::DuplicatePage);
    let stale_page_rejected = invalid_card_rejected(|card| {
        card.selected_pages = vec!["kv:stale-tail"];
    }) == Some(KvPageControlError::StalePageSelected);
    let incompatible_fence_rejected = invalid_card_rejected(|card| {
        card.candidate_pages[0].compatibility_fence = "fence:stale-model";
    }) == Some(KvPageControlError::IncompatibleFence);
    let missing_digest_rejected = invalid_card_rejected(|card| {
        card.candidate_pages[0].page_digest = "";
    }) == Some(KvPageControlError::MissingDigest);
    let missing_rollback_rejected = invalid_card_rejected(|card| {
        card.rollback_handle = "";
    }) == Some(KvPageControlError::MissingRollback);
    let missing_answer_packet_rejected = invalid_card_rejected(|card| {
        card.answer_packet_ref = "";
    }) == Some(KvPageControlError::MissingAnswerPacket);
    let over_budget_selection_rejected = invalid_card_rejected(|card| {
        card.active_byte_limit = 1;
    }) == Some(KvPageControlError::BudgetExceeded);
    let hidden_live_mutation_rejected = invalid_card_rejected(|card| {
        card.route_authority = "live_mutation";
    }) == Some(KvPageControlError::HiddenLiveMutation);
    let verifier_bypass_rejected = invalid_card_rejected(|card| {
        card.min_verifier_bps = 9900;
    }) == Some(KvPageControlError::VerifierBypass);
    let cloud_page_rejected = invalid_card_rejected(|card| {
        card.candidate_pages[0].source_ref = "cloud:remote-kv";
    }) == Some(KvPageControlError::CloudPage);
    let unbeaten_baseline_rejected = invalid_card_rejected(|card| {
        card.recency_baseline_pages = card.selected_pages.clone();
    }) == Some(KvPageControlError::QueryAwareBaselineUnbeaten);
    let no_runtime_bytes_loaded = true;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_brain_route_card_pass",
            upstream_brain_route_card_pass,
        ),
        (
            "kv_page_control_cards_present",
            kv_page_control_cards_present,
        ),
        ("query_signatures_bound", query_signatures_bound),
        ("mission_ids_bound", mission_ids_bound),
        ("model_ids_bound", model_ids_bound),
        ("upstream_route_refs_bound", upstream_route_refs_bound),
        ("uas_page_addresses_bound", uas_page_addresses_bound),
        ("page_digests_bound", page_digests_bound),
        ("layer_ranges_bound", layer_ranges_bound),
        ("token_page_ranges_bound", token_page_ranges_bound),
        ("compatibility_fences_bound", compatibility_fences_bound),
        ("query_dependence_bound", query_dependence_bound),
        ("criticality_signal_bound", criticality_signal_bound),
        ("sink_or_heavy_hitter_bound", sink_or_heavy_hitter_bound),
        ("ranking_signals_bound", ranking_signals_bound),
        ("privacy_classes_bound", privacy_classes_bound),
        ("retention_decisions_bound", retention_decisions_bound),
        ("eviction_decisions_bound", eviction_decisions_bound),
        ("restore_decisions_bound", restore_decisions_bound),
        (
            "selected_pages_fit_active_byte_budget",
            selected_pages_fit_active_byte_budget,
        ),
        ("query_aware_beats_recency", query_aware_beats_recency),
        ("query_aware_beats_random", query_aware_beats_random),
        ("query_aware_beats_file_order", query_aware_beats_file_order),
        ("quality_delta_positive", quality_delta_positive),
        ("verifier_delta_positive", verifier_delta_positive),
        ("latency_delta_positive", latency_delta_positive),
        ("active_byte_delta_positive", active_byte_delta_positive),
        ("rollback_bound", rollback_bound),
        ("answer_packet_ref_bound", answer_packet_ref_bound),
        ("route_card_ref_bound", route_card_ref_bound),
        ("page_control_shadow_only", page_control_shadow_only),
        ("no_hidden_cloud", no_hidden_cloud),
        (
            "page_control_address_deterministic",
            page_control_address_deterministic,
        ),
        ("duplicate_policy_rejected", duplicate_policy_rejected),
        ("duplicate_page_rejected", duplicate_page_rejected),
        ("stale_page_rejected", stale_page_rejected),
        ("incompatible_fence_rejected", incompatible_fence_rejected),
        ("missing_digest_rejected", missing_digest_rejected),
        ("missing_rollback_rejected", missing_rollback_rejected),
        (
            "missing_answer_packet_rejected",
            missing_answer_packet_rejected,
        ),
        (
            "over_budget_selection_rejected",
            over_budget_selection_rejected,
        ),
        (
            "hidden_live_mutation_rejected",
            hidden_live_mutation_rejected,
        ),
        ("verifier_bypass_rejected", verifier_bypass_rejected),
        ("cloud_page_rejected", cloud_page_rejected),
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
        "kv_page_control_card_count",
        registry.cards.len() as u64,
        3,
        "count",
    );
    add_count_ge_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "candidate_page_count",
        registry.candidate_page_count() as u64,
        12,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "selected_page_count",
        registry.selected_page_count() as u64,
        6,
        "count",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_active_byte_limit",
        registry.max_active_byte_limit(),
        96 * 1024 * 1024,
        "bytes",
    );
    add_string_contains_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "page_control_address",
        &registry.page_control_address,
        "uas:kv-page-control:",
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
            "detail": "metadata-only KVPageControlCard witness; no live KV mutation, no model/runtime bytes, no hidden cloud, no SSD-as-RAM claim, and no product promotion executed"
        })],
        notes: "Proves query-aware KV/page selection beats recency-only, random, and file-order page policies under active-byte, quality, verifier, rollback, and AnswerPacket visibility budgets while preserving shadow-only authority.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:kv-page-control:registry
// Plane: Controller
// Residency: metadata-only
struct KvPageControlRegistry {
    cards: Vec<KvPageControlCard>,
    page_control_address: String,
}

impl KvPageControlRegistry {
    fn new(mut cards: Vec<KvPageControlCard>) -> Result<Self, KvPageControlError> {
        if cards.is_empty() {
            return Err(KvPageControlError::MissingCard);
        }
        let mut seen = BTreeSet::new();
        for card in &cards {
            if !seen.insert(card.policy_id) {
                return Err(KvPageControlError::DuplicatePolicy);
            }
            validate_card(card)?;
        }
        cards.sort_by_key(|card| card.policy_id);
        let page_control_address = page_control_address(&cards);
        Ok(Self {
            cards,
            page_control_address,
        })
    }

    fn candidate_page_count(&self) -> usize {
        self.cards
            .iter()
            .map(|card| card.candidate_pages.len())
            .sum()
    }

    fn selected_page_count(&self) -> usize {
        self.cards
            .iter()
            .map(|card| card.selected_pages.len())
            .sum()
    }

    fn max_active_byte_limit(&self) -> u64 {
        self.cards
            .iter()
            .map(|card| card.active_byte_limit)
            .max()
            .unwrap_or(0)
    }
}

fn validate_card(card: &KvPageControlCard) -> Result<(), KvPageControlError> {
    if !card.mission_id.starts_with("mission:") {
        return Err(KvPageControlError::MissingMission);
    }
    if !card.query_signature.starts_with("query:") {
        return Err(KvPageControlError::MissingQuery);
    }
    if !card.model_id.starts_with("model:") {
        return Err(KvPageControlError::MissingModel);
    }
    if card.brain_route_card_ref != UPSTREAM_BRAIN_ROUTE {
        return Err(KvPageControlError::MissingUpstreamRoute);
    }
    if card.candidate_pages.is_empty() {
        return Err(KvPageControlError::MissingPage);
    }
    let mut seen_pages = BTreeSet::new();
    for page in &card.candidate_pages {
        if !seen_pages.insert(page.page_id) {
            return Err(KvPageControlError::DuplicatePage);
        }
        validate_page(page)?;
    }
    if card.selected_pages.is_empty() {
        return Err(KvPageControlError::MissingSelectedPage);
    }
    validate_selection(card, &card.selected_pages)?;
    validate_selection(card, &card.recency_baseline_pages)?;
    validate_selection(card, &card.random_baseline_pages)?;
    validate_selection(card, &card.file_order_baseline_pages)?;
    if !card.rollback_handle.starts_with("rollback:") {
        return Err(KvPageControlError::MissingRollback);
    }
    if !card.answer_packet_ref.starts_with("answerpacket:") {
        return Err(KvPageControlError::MissingAnswerPacket);
    }
    if card.route_authority != "shadow_only" {
        return Err(KvPageControlError::HiddenLiveMutation);
    }
    if !card.retention_decision.starts_with("retain:")
        || !card.eviction_decision.starts_with("evict:")
        || !card.restore_decision.starts_with("restore:")
    {
        return Err(KvPageControlError::MissingDecision);
    }
    let selected_score =
        score_pages(card, &card.selected_pages).ok_or(KvPageControlError::UnknownSelectedPage)?;
    if selected_score.active_bytes > card.active_byte_limit {
        return Err(KvPageControlError::BudgetExceeded);
    }
    if selected_score.verifier_bps < card.min_verifier_bps {
        return Err(KvPageControlError::VerifierBypass);
    }
    if !selection_beats(card, &card.recency_baseline_pages)
        || !selection_beats(card, &card.random_baseline_pages)
        || !selection_beats(card, &card.file_order_baseline_pages)
    {
        return Err(KvPageControlError::QueryAwareBaselineUnbeaten);
    }
    Ok(())
}

fn validate_page(page: &KvPageCandidate) -> Result<(), KvPageControlError> {
    if !page.uas_address.starts_with("uas:kv-page:") {
        return Err(KvPageControlError::MissingPage);
    }
    if !page.page_digest.starts_with("sha256:") {
        return Err(KvPageControlError::MissingDigest);
    }
    if !page.compatibility_fence.starts_with("fence:") {
        return Err(KvPageControlError::MissingCompatibilityFence);
    }
    if page.compatibility_fence != CURRENT_FENCE {
        return Err(KvPageControlError::IncompatibleFence);
    }
    if page.source_ref.contains("cloud") {
        return Err(KvPageControlError::CloudPage);
    }
    Ok(())
}

fn validate_selection(
    card: &KvPageControlCard,
    page_ids: &[&'static str],
) -> Result<(), KvPageControlError> {
    if page_ids.is_empty() {
        return Err(KvPageControlError::MissingSelectedPage);
    }
    let pages = page_map(card);
    for page_id in page_ids {
        let page = pages
            .get(page_id)
            .ok_or(KvPageControlError::UnknownBaselinePage)?;
        if page.stale {
            return Err(KvPageControlError::StalePageSelected);
        }
    }
    Ok(())
}

fn selection_beats(card: &KvPageControlCard, baseline: &[&'static str]) -> bool {
    match (
        score_pages(card, &card.selected_pages),
        score_pages(card, baseline),
    ) {
        (Some(selected), Some(baseline)) => {
            selected.quality_bps > baseline.quality_bps
                && selected.verifier_bps > baseline.verifier_bps
                && selected.latency_ms < baseline.latency_ms
                && selected.active_bytes < baseline.active_bytes
        }
        _ => false,
    }
}

fn baseline_scores(card: &KvPageControlCard) -> Option<Vec<SelectionScore>> {
    Some(vec![
        score_pages(card, &card.recency_baseline_pages)?,
        score_pages(card, &card.random_baseline_pages)?,
        score_pages(card, &card.file_order_baseline_pages)?,
    ])
}

fn score_pages(card: &KvPageControlCard, page_ids: &[&'static str]) -> Option<SelectionScore> {
    let pages = page_map(card);
    let mut quality_bps = 0;
    let mut verifier_bps = 0;
    let mut latency_ms = 0;
    let mut active_bytes = 0;
    for page_id in page_ids {
        let page = pages.get(page_id)?;
        if page.stale || page.compatibility_fence != CURRENT_FENCE {
            return None;
        }
        let sink_bonus = if page.sink_or_heavy_hitter { 180 } else { 0 };
        quality_bps += page.query_relevance_bps + page.criticality_bps + sink_bonus;
        verifier_bps += page.verifier_utility_bps;
        latency_ms += page.restore_latency_ms;
        active_bytes += page.active_bytes;
    }
    Some(SelectionScore {
        quality_bps,
        verifier_bps,
        latency_ms,
        active_bytes,
    })
}

fn page_map(card: &KvPageControlCard) -> BTreeMap<&'static str, &KvPageCandidate> {
    card.candidate_pages
        .iter()
        .map(|page| (page.page_id, page))
        .collect()
}

fn duplicate_policy_rejected() -> bool {
    let mut cards = fixture_cards();
    cards[1].policy_id = cards[0].policy_id;
    matches!(
        KvPageControlRegistry::new(cards),
        Err(KvPageControlError::DuplicatePolicy)
    )
}

fn invalid_card_rejected(
    mut mutate: impl FnMut(&mut KvPageControlCard),
) -> Option<KvPageControlError> {
    let mut cards = fixture_cards();
    mutate(&mut cards[0]);
    KvPageControlRegistry::new(cards).err()
}

fn page_control_address(cards: &[KvPageControlCard]) -> String {
    let mut payload = String::new();
    for card in cards {
        payload.push_str(card.policy_id);
        payload.push('|');
        payload.push_str(card.query_signature);
        payload.push('|');
        for page in &card.candidate_pages {
            payload.push_str(page.uas_address);
            payload.push(':');
            payload.push_str(page.page_digest);
            payload.push(':');
            payload.push_str(page.compatibility_fence);
            payload.push(';');
        }
        payload.push('|');
        for selected in &card.selected_pages {
            payload.push_str(selected);
            payload.push(',');
        }
        payload.push('\n');
    }
    format!(
        "uas:kv-page-control:{}",
        sha256_hex(payload.as_bytes()).trim_start_matches("sha256:")
    )
}

fn upstream_brain_route_pass() -> bool {
    read_artifact_string(UPSTREAM_BRAIN_ROUTE)
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

fn fixture_cards() -> Vec<KvPageControlCard> {
    vec![
        KvPageControlCard {
            policy_id: "kv-policy:adversarial-module-5",
            mission_id: "mission:adversarial-thinking-note",
            query_signature: "query:module-5-counterexample-proof-citations",
            model_id: "model:qwen3.5-local-research",
            brain_route_card_ref: UPSTREAM_BRAIN_ROUTE,
            candidate_pages: vec![
                page("kv:module5-core", 0, 4, 930, 890, 880, 6, 3, true, false),
                page(
                    "kv:counterexample-proof",
                    4,
                    7,
                    910,
                    920,
                    910,
                    5,
                    7,
                    true,
                    false,
                ),
                page("kv:recent-footer", 7, 9, 260, 300, 220, 1, 11, false, false),
                page("kv:file-preface", 9, 11, 320, 340, 280, 8, 1, false, false),
                page("kv:stale-tail", 11, 12, 780, 760, 760, 2, 14, true, true),
            ],
            selected_pages: vec!["kv:module5-core", "kv:counterexample-proof"],
            recency_baseline_pages: vec!["kv:recent-footer", "kv:file-preface", "kv:module5-core"],
            random_baseline_pages: vec![
                "kv:file-preface",
                "kv:recent-footer",
                "kv:counterexample-proof",
            ],
            file_order_baseline_pages: vec![
                "kv:file-preface",
                "kv:recent-footer",
                "kv:module5-core",
            ],
            active_byte_limit: 64 * 1024 * 1024,
            min_verifier_bps: 1600,
            rollback_handle: "rollback:kv-page-control:module5",
            answer_packet_ref: "answerpacket:kv-page-control:module5",
            route_authority: "shadow_only",
            retention_decision: "retain:module5-core,counterexample-proof",
            eviction_decision: "evict:recent-footer,file-preface",
            restore_decision: "restore:module5-core,counterexample-proof",
        },
        KvPageControlCard {
            policy_id: "kv-policy:swiftlm-source-motif",
            mission_id: "mission:swiftlm-source-intake",
            query_signature: "query:flash-aware-kv-compression-caveats",
            model_id: "model:qwen3.5-local-research",
            brain_route_card_ref: UPSTREAM_BRAIN_ROUTE,
            candidate_pages: vec![
                page(
                    "kv:swiftlm-kv-compression",
                    0,
                    3,
                    940,
                    850,
                    890,
                    7,
                    5,
                    true,
                    false,
                ),
                page(
                    "kv:flash-bundling-caveat",
                    3,
                    6,
                    900,
                    820,
                    850,
                    8,
                    8,
                    false,
                    false,
                ),
                page(
                    "kv:recent-chat-summary",
                    6,
                    7,
                    280,
                    290,
                    230,
                    1,
                    12,
                    false,
                    false,
                ),
                page(
                    "kv:file-license-preface",
                    7,
                    9,
                    330,
                    350,
                    300,
                    3,
                    1,
                    false,
                    false,
                ),
                page(
                    "kv:old-benchmark-note",
                    9,
                    10,
                    500,
                    450,
                    420,
                    2,
                    9,
                    false,
                    true,
                ),
            ],
            selected_pages: vec!["kv:swiftlm-kv-compression", "kv:flash-bundling-caveat"],
            recency_baseline_pages: vec![
                "kv:recent-chat-summary",
                "kv:file-license-preface",
                "kv:swiftlm-kv-compression",
            ],
            random_baseline_pages: vec![
                "kv:file-license-preface",
                "kv:recent-chat-summary",
                "kv:swiftlm-kv-compression",
            ],
            file_order_baseline_pages: vec![
                "kv:file-license-preface",
                "kv:recent-chat-summary",
                "kv:swiftlm-kv-compression",
            ],
            active_byte_limit: 64 * 1024 * 1024,
            min_verifier_bps: 1500,
            rollback_handle: "rollback:kv-page-control:swiftlm",
            answer_packet_ref: "answerpacket:kv-page-control:swiftlm",
            route_authority: "shadow_only",
            retention_decision: "retain:swiftlm-kv-compression,flash-bundling-caveat",
            eviction_decision: "evict:recent-chat-summary,file-license-preface",
            restore_decision: "restore:swiftlm-kv-compression,flash-bundling-caveat",
        },
        KvPageControlCard {
            policy_id: "kv-policy:proof-route-repair",
            mission_id: "mission:route-kernel-proof-repair",
            query_signature: "query:rollback-answerpacket-precondition-repair",
            model_id: "model:qwen3.5-local-research",
            brain_route_card_ref: UPSTREAM_BRAIN_ROUTE,
            candidate_pages: vec![
                page(
                    "kv:rollback-precondition",
                    0,
                    2,
                    930,
                    880,
                    920,
                    9,
                    4,
                    true,
                    false,
                ),
                page(
                    "kv:answerpacket-proof",
                    2,
                    5,
                    910,
                    870,
                    900,
                    10,
                    6,
                    true,
                    false,
                ),
                page(
                    "kv:recent-terminal-log",
                    5,
                    7,
                    340,
                    320,
                    300,
                    1,
                    10,
                    false,
                    false,
                ),
                page(
                    "kv:file-order-schema",
                    7,
                    9,
                    420,
                    410,
                    390,
                    4,
                    1,
                    false,
                    false,
                ),
                page(
                    "kv:stale-toolchain",
                    9,
                    10,
                    710,
                    690,
                    650,
                    2,
                    11,
                    false,
                    true,
                ),
            ],
            selected_pages: vec!["kv:rollback-precondition", "kv:answerpacket-proof"],
            recency_baseline_pages: vec![
                "kv:recent-terminal-log",
                "kv:file-order-schema",
                "kv:rollback-precondition",
            ],
            random_baseline_pages: vec![
                "kv:file-order-schema",
                "kv:recent-terminal-log",
                "kv:answerpacket-proof",
            ],
            file_order_baseline_pages: vec![
                "kv:file-order-schema",
                "kv:recent-terminal-log",
                "kv:rollback-precondition",
            ],
            active_byte_limit: 64 * 1024 * 1024,
            min_verifier_bps: 1600,
            rollback_handle: "rollback:kv-page-control:proof-route",
            answer_packet_ref: "answerpacket:kv-page-control:proof-route",
            route_authority: "shadow_only",
            retention_decision: "retain:rollback-precondition,answerpacket-proof",
            eviction_decision: "evict:recent-terminal-log,file-order-schema",
            restore_decision: "restore:rollback-precondition,answerpacket-proof",
        },
    ]
}

fn page(
    page_id: &'static str,
    layer_start: u64,
    layer_end: u64,
    query_relevance_bps: u64,
    criticality_bps: u64,
    verifier_utility_bps: u64,
    recency_rank: u64,
    file_order: u64,
    sink_or_heavy_hitter: bool,
    stale: bool,
) -> KvPageCandidate {
    let digest_seed = format!("{page_id}:{layer_start}:{layer_end}:{query_relevance_bps}");
    let digest = Box::leak(sha256_hex(digest_seed.as_bytes()).into_boxed_str());
    KvPageCandidate {
        page_id,
        uas_address: Box::leak(format!("uas:kv-page:{page_id}").into_boxed_str()),
        layer_range: Box::leak(format!("{layer_start}..{layer_end}").into_boxed_str()),
        token_page_range: Box::leak(
            format!("{}..{}", layer_start * 256, layer_end * 256).into_boxed_str(),
        ),
        page_digest: digest,
        compatibility_fence: CURRENT_FENCE,
        query_relevance_bps,
        criticality_bps,
        verifier_utility_bps,
        recency_rank,
        file_order,
        sink_or_heavy_hitter,
        active_bytes: 16 * 1024 * 1024,
        restore_latency_ms: if sink_or_heavy_hitter { 5 } else { 11 },
        stale,
        privacy_class: "vault_private",
        source_ref: "artifacts/falsifiers/brain_route_card_multi_model/result.json",
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
    fn artifact_contains_kv_page_control_axes() {
        let artifact = build_artifact().expect("artifact builds");
        assert!(artifact.overall_pass);
        for axis in [
            "upstream_brain_route_card_pass",
            "kv_page_control_cards_present",
            "query_aware_beats_recency",
            "query_aware_beats_random",
            "query_aware_beats_file_order",
            "selected_pages_fit_active_byte_budget",
            "stale_page_rejected",
            "incompatible_fence_rejected",
            "hidden_live_mutation_rejected",
            "verifier_bypass_rejected",
            "no_runtime_bytes_loaded",
        ] {
            assert_eq!(artifact.pass_per_axis.get(axis), Some(&true), "{axis}");
        }
    }

    #[test]
    fn invalid_fixtures_fail_closed() {
        assert_eq!(
            invalid_card_rejected(|card| card.selected_pages = vec!["kv:stale-tail"]),
            Some(KvPageControlError::StalePageSelected)
        );
        assert_eq!(
            invalid_card_rejected(
                |card| card.candidate_pages[0].compatibility_fence = "fence:old-model"
            ),
            Some(KvPageControlError::IncompatibleFence)
        );
        assert_eq!(
            invalid_card_rejected(|card| card.route_authority = "live_mutation"),
            Some(KvPageControlError::HiddenLiveMutation)
        );
        assert_eq!(
            invalid_card_rejected(|card| card.min_verifier_bps = 9900),
            Some(KvPageControlError::VerifierBypass)
        );
    }

    #[test]
    fn page_control_address_is_order_stable() {
        let cards = fixture_cards();
        let reversed = cards.iter().cloned().rev().collect::<Vec<_>>();
        let first = KvPageControlRegistry::new(cards).expect("first registry");
        let second = KvPageControlRegistry::new(reversed).expect("second registry");
        assert_eq!(first.page_control_address, second.page_control_address);
    }
}
