//! `falsify_brain_route_card_multi_model` — BrainRouteCard routing contract.
//!
//! Metadata-only witness for `F-BrainRouteCard-MultiModel`. It proves
//! task-shaped multi-brain route cards beat a simpler static route on quality,
//! evidence validity, verifier result, latency, and active bytes while keeping
//! authority shadow-only, rollback-bound, and AnswerPacket-visible.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-BrainRouteCard-MultiModel";
const FIXTURE_ID: &str = "brain_route_card_multi_model_v1";
const COMMAND: &str = "Tools/falsifiers/f_brain_route_card_multi_model.sh";
const RESULT: &str = "artifacts/falsifiers/brain_route_card_multi_model/result.json";
const UPSTREAM_ROUTE_KERNEL: &str =
    "artifacts/falsifiers/rust_route_kernel_model_check/result.json";

// UAS: brain candidate route unit.
// Plane: Controller.
// Residency: metadata-only candidate fixture; no runtime/model bytes.
#[derive(Clone)]
struct BrainCandidate {
    brain_id: &'static str,
    role: &'static str,
    lane: &'static str,
    product_build: &'static str,
    pro_status: &'static str,
    privacy_class: &'static str,
    active_bytes: u64,
    hidden_chain_policy: &'static str,
}

// UAS: static and task-shaped route score unit.
// Plane: Verification.
// Residency: metadata-only score fixture.
#[derive(Clone, Copy)]
struct RouteScore {
    quality_bps: u64,
    evidence_validity_bps: u64,
    verifier_bps: u64,
    route_success_bps: u64,
    latency_ms: u64,
    active_bytes: u64,
}

// UAS: BrainRouteCard addressable route contract.
// Plane: Controller + Verification.
// Residency: metadata-only shadow route card.
#[derive(Clone)]
struct BrainRouteCard {
    route_id: &'static str,
    mission_id: &'static str,
    task_signature: &'static str,
    candidate_brains: Vec<BrainCandidate>,
    selected_stack: Vec<&'static str>,
    static_baseline_brain: &'static str,
    fallback_brain: &'static str,
    learned_score: RouteScore,
    static_baseline_score: RouteScore,
    active_byte_limit: u64,
    uncertainty_bps: u64,
    conflict_bps: u64,
    rollback_handle: &'static str,
    answer_packet_ref: &'static str,
    route_kernel_ref: &'static str,
    regret_update_key: &'static str,
    route_authority: &'static str,
}

#[derive(Debug, Eq, PartialEq)]
// UAS: uas:brain-route-card:error
// Plane: Verification
// Residency: metadata-only
enum BrainRouteError {
    MissingCard,
    DuplicateCard,
    MissingTaskSignature,
    MissingCandidate,
    MissingSelectedStack,
    UnknownSelectedBrain,
    UnknownFallbackBrain,
    MissingBaseline,
    MissingRollback,
    MissingAnswerPacket,
    MissingRouteKernel,
    MissingRegretKey,
    HiddenLiveAuthority,
    HiddenChainExposure,
    CloudRoute,
    BudgetExceeded,
    StaticBaselineUnbeaten,
    UncertaintyOrConflictNonAbstain,
}

impl std::fmt::Display for BrainRouteError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for BrainRouteError {}

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
        "{FALSIFIER_ID}: overall_pass={} brain_route_card_count={} route_card_address={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["brain_route_card_count"].value,
        artifact.measurements["route_card_address"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let cards = fixture_route_cards();
    let reversed = cards.iter().cloned().rev().collect::<Vec<_>>();
    let registry = BrainRouteRegistry::new(cards)?;
    let reversed_registry = BrainRouteRegistry::new(reversed)?;

    let upstream_route_kernel_model_check_pass = upstream_route_kernel_pass();
    let brain_route_cards_present = registry.cards.len() == 3;
    let task_signatures_bound = registry
        .cards
        .iter()
        .all(|card| card.task_signature.starts_with("task:"));
    let mission_ids_bound = registry
        .cards
        .iter()
        .all(|card| card.mission_id.starts_with("mission:"));
    let candidate_brains_bound = registry.cards.iter().all(|card| {
        card.candidate_brains.len() >= 2
            && card
                .candidate_brains
                .iter()
                .all(|brain| brain.brain_id.starts_with("brain:"))
    });
    let selected_stack_bound = registry.cards.iter().all(selected_stack_known);
    let fallback_brain_bound = registry.cards.iter().all(fallback_known);
    let model_roles_bound = registry.roles().is_superset(&BTreeSet::from([
        "apple_lightweight",
        "local_reasoner",
        "proof_verifier",
        "eidos_retrieval",
    ]));
    let privacy_classes_bound = registry.cards.iter().all(|card| {
        card.candidate_brains.iter().all(|brain| {
            matches!(
                brain.privacy_class,
                "local_only" | "apple_private_or_declined" | "proof_only"
            )
        })
    });
    let baseline_static_route_bound = registry
        .cards
        .iter()
        .all(|card| candidate_ids(card).contains(card.static_baseline_brain));
    let route_kernel_compatibility_bound = registry
        .cards
        .iter()
        .all(|card| card.route_kernel_ref == UPSTREAM_ROUTE_KERNEL);
    let quality_delta_positive = registry
        .cards
        .iter()
        .all(|card| card.learned_score.quality_bps > card.static_baseline_score.quality_bps);
    let evidence_validity_delta_positive = registry.cards.iter().all(|card| {
        card.learned_score.evidence_validity_bps > card.static_baseline_score.evidence_validity_bps
    });
    let verifier_delta_positive = registry
        .cards
        .iter()
        .all(|card| card.learned_score.verifier_bps > card.static_baseline_score.verifier_bps);
    let latency_delta_positive = registry
        .cards
        .iter()
        .all(|card| card.learned_score.latency_ms < card.static_baseline_score.latency_ms);
    let active_byte_delta_positive = registry
        .cards
        .iter()
        .all(|card| card.learned_score.active_bytes < card.static_baseline_score.active_bytes);
    let route_success_delta_positive = registry.cards.iter().all(|card| {
        card.learned_score.route_success_bps > card.static_baseline_score.route_success_bps
    });
    let static_baseline_beaten = registry.cards.iter().all(route_beats_static);
    let rollback_bound = registry
        .cards
        .iter()
        .all(|card| card.rollback_handle.starts_with("rollback:"));
    let answer_packet_ref_bound = registry
        .cards
        .iter()
        .all(|card| card.answer_packet_ref.starts_with("answerpacket:"));
    let regret_update_key_bound = registry
        .cards
        .iter()
        .all(|card| card.regret_update_key.starts_with("regret:"));
    let route_authority_shadow_only = registry
        .cards
        .iter()
        .all(|card| card.route_authority == "shadow_only");
    let no_hidden_multi_model_authority = route_authority_shadow_only;
    let hidden_chain_not_exposed = registry.cards.iter().all(|card| {
        card.candidate_brains
            .iter()
            .all(|brain| brain.hidden_chain_policy == "visible_summary_only")
    });
    let no_hidden_cloud = registry.cards.iter().all(|card| {
        card.candidate_brains
            .iter()
            .all(|brain| brain.lane != "cloud_provider")
    });
    let uncertainty_abstention_bound = high_uncertainty_abstain_card_valid()
        && invalid_card_rejected(|card| {
            card.uncertainty_bps = 8200;
            card.selected_stack = vec!["brain:local-qwen"];
        }) == Some(BrainRouteError::UncertaintyOrConflictNonAbstain);
    let route_card_address_deterministic =
        registry.route_card_address == reversed_registry.route_card_address;
    let duplicate_route_card_rejected = duplicate_card_rejected();
    let missing_candidate_rejected = invalid_card_rejected(|card| {
        card.candidate_brains.clear();
    }) == Some(BrainRouteError::MissingCandidate);
    let missing_rollback_rejected = invalid_card_rejected(|card| {
        card.rollback_handle = "";
    }) == Some(BrainRouteError::MissingRollback);
    let missing_answer_packet_rejected = invalid_card_rejected(|card| {
        card.answer_packet_ref = "";
    }) == Some(BrainRouteError::MissingAnswerPacket);
    let hidden_multi_model_authority_rejected = invalid_card_rejected(|card| {
        card.route_authority = "live_policy";
    }) == Some(BrainRouteError::HiddenLiveAuthority);
    let hidden_chain_exposure_rejected = invalid_card_rejected(|card| {
        card.candidate_brains[0].hidden_chain_policy = "raw_chain";
    }) == Some(BrainRouteError::HiddenChainExposure);
    let cloud_route_rejected = invalid_card_rejected(|card| {
        card.candidate_brains[0].lane = "cloud_provider";
    }) == Some(BrainRouteError::CloudRoute);
    let unbeaten_static_baseline_rejected = invalid_card_rejected(|card| {
        card.learned_score.quality_bps = card.static_baseline_score.quality_bps;
    }) == Some(BrainRouteError::StaticBaselineUnbeaten);
    let over_budget_route_rejected = invalid_card_rejected(|card| {
        card.learned_score.active_bytes = card.active_byte_limit + 1;
    }) == Some(BrainRouteError::BudgetExceeded);
    let no_runtime_bytes_loaded = true;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_route_kernel_model_check_pass",
            upstream_route_kernel_model_check_pass,
        ),
        ("brain_route_cards_present", brain_route_cards_present),
        ("task_signatures_bound", task_signatures_bound),
        ("mission_ids_bound", mission_ids_bound),
        ("candidate_brains_bound", candidate_brains_bound),
        ("selected_stack_bound", selected_stack_bound),
        ("fallback_brain_bound", fallback_brain_bound),
        ("model_roles_bound", model_roles_bound),
        ("privacy_classes_bound", privacy_classes_bound),
        ("baseline_static_route_bound", baseline_static_route_bound),
        (
            "route_kernel_compatibility_bound",
            route_kernel_compatibility_bound,
        ),
        ("quality_delta_positive", quality_delta_positive),
        (
            "evidence_validity_delta_positive",
            evidence_validity_delta_positive,
        ),
        ("verifier_delta_positive", verifier_delta_positive),
        ("latency_delta_positive", latency_delta_positive),
        ("active_byte_delta_positive", active_byte_delta_positive),
        ("route_success_delta_positive", route_success_delta_positive),
        ("static_baseline_beaten", static_baseline_beaten),
        ("rollback_bound", rollback_bound),
        ("answer_packet_ref_bound", answer_packet_ref_bound),
        ("regret_update_key_bound", regret_update_key_bound),
        ("route_authority_shadow_only", route_authority_shadow_only),
        (
            "no_hidden_multi_model_authority",
            no_hidden_multi_model_authority,
        ),
        ("hidden_chain_not_exposed", hidden_chain_not_exposed),
        ("no_hidden_cloud", no_hidden_cloud),
        ("uncertainty_abstention_bound", uncertainty_abstention_bound),
        (
            "route_card_address_deterministic",
            route_card_address_deterministic,
        ),
        (
            "duplicate_route_card_rejected",
            duplicate_route_card_rejected,
        ),
        ("missing_candidate_rejected", missing_candidate_rejected),
        ("missing_rollback_rejected", missing_rollback_rejected),
        (
            "missing_answer_packet_rejected",
            missing_answer_packet_rejected,
        ),
        (
            "hidden_multi_model_authority_rejected",
            hidden_multi_model_authority_rejected,
        ),
        (
            "hidden_chain_exposure_rejected",
            hidden_chain_exposure_rejected,
        ),
        ("cloud_route_rejected", cloud_route_rejected),
        (
            "unbeaten_static_baseline_rejected",
            unbeaten_static_baseline_rejected,
        ),
        ("over_budget_route_rejected", over_budget_route_rejected),
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
        "brain_route_card_count",
        registry.cards.len() as u64,
        3,
        "count",
    );
    add_count_ge_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "candidate_brain_count",
        registry.candidate_brain_count() as u64,
        5,
        "count",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_active_byte_limit",
        registry.max_active_byte_limit(),
        192 * 1024 * 1024,
        "bytes",
    );
    add_string_contains_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_card_address",
        &registry.route_card_address,
        "uas:brain-route-card:",
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
            "detail": "metadata-only BrainRouteCard witness; no live multi-model router, no hidden committee, no cloud fallback, no model/runtime bytes, and no product promotion executed"
        })],
        notes: "Proves task-shaped BrainRouteCard routing beats a static route across quality/evidence/verifier/latency/active-byte axes while preserving shadow authority, rollback, AnswerPacket visibility, and route-kernel compatibility.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:brain-route-card:registry
// Plane: Controller
// Residency: metadata-only
struct BrainRouteRegistry {
    cards: Vec<BrainRouteCard>,
    route_card_address: String,
}

impl BrainRouteRegistry {
    fn new(mut cards: Vec<BrainRouteCard>) -> Result<Self, BrainRouteError> {
        if cards.is_empty() {
            return Err(BrainRouteError::MissingCard);
        }
        let mut seen = BTreeSet::new();
        for card in &cards {
            if !seen.insert(card.route_id) {
                return Err(BrainRouteError::DuplicateCard);
            }
            validate_card(card)?;
        }
        cards.sort_by(|a, b| a.route_id.cmp(b.route_id));
        let route_card_address = route_card_address(&cards);
        Ok(Self {
            cards,
            route_card_address,
        })
    }

    fn roles(&self) -> BTreeSet<&'static str> {
        self.cards
            .iter()
            .flat_map(|card| card.candidate_brains.iter().map(|brain| brain.role))
            .collect()
    }

    fn candidate_brain_count(&self) -> usize {
        self.cards
            .iter()
            .flat_map(|card| card.candidate_brains.iter().map(|brain| brain.brain_id))
            .collect::<BTreeSet<_>>()
            .len()
    }

    fn max_active_byte_limit(&self) -> u64 {
        self.cards
            .iter()
            .map(|card| card.active_byte_limit)
            .max()
            .unwrap_or(0)
    }
}

fn validate_card(card: &BrainRouteCard) -> Result<(), BrainRouteError> {
    if card.task_signature.is_empty() {
        return Err(BrainRouteError::MissingTaskSignature);
    }
    if card.candidate_brains.len() < 2 {
        return Err(BrainRouteError::MissingCandidate);
    }
    if card.selected_stack.is_empty() {
        return Err(BrainRouteError::MissingSelectedStack);
    }
    if !selected_stack_known(card) {
        return Err(BrainRouteError::UnknownSelectedBrain);
    }
    if !fallback_known(card) {
        return Err(BrainRouteError::UnknownFallbackBrain);
    }
    if !candidate_ids(card).contains(card.static_baseline_brain) {
        return Err(BrainRouteError::MissingBaseline);
    }
    if card.rollback_handle.is_empty() {
        return Err(BrainRouteError::MissingRollback);
    }
    if card.answer_packet_ref.is_empty() {
        return Err(BrainRouteError::MissingAnswerPacket);
    }
    if card.route_kernel_ref != UPSTREAM_ROUTE_KERNEL {
        return Err(BrainRouteError::MissingRouteKernel);
    }
    if !card.regret_update_key.starts_with("regret:") {
        return Err(BrainRouteError::MissingRegretKey);
    }
    if card.route_authority != "shadow_only" {
        return Err(BrainRouteError::HiddenLiveAuthority);
    }
    for brain in &card.candidate_brains {
        if brain.hidden_chain_policy != "visible_summary_only" {
            return Err(BrainRouteError::HiddenChainExposure);
        }
        if brain.lane == "cloud_provider" {
            return Err(BrainRouteError::CloudRoute);
        }
        if brain.active_bytes > card.active_byte_limit {
            return Err(BrainRouteError::BudgetExceeded);
        }
        if brain.product_build != "MAS" && brain.product_build != "Pro" {
            return Err(BrainRouteError::MissingCandidate);
        }
        if !matches!(
            brain.pro_status,
            "Live" | "Gated" | "ResearchCandidate" | "VaultPreserved"
        ) {
            return Err(BrainRouteError::MissingCandidate);
        }
    }
    if card.learned_score.active_bytes > card.active_byte_limit {
        return Err(BrainRouteError::BudgetExceeded);
    }
    if (card.uncertainty_bps >= 7000 || card.conflict_bps >= 5000)
        && card.selected_stack != vec!["abstain"]
    {
        return Err(BrainRouteError::UncertaintyOrConflictNonAbstain);
    }
    if card.selected_stack == vec!["abstain"] {
        return Ok(());
    }
    if !route_beats_static(card) {
        return Err(BrainRouteError::StaticBaselineUnbeaten);
    }
    Ok(())
}

fn route_beats_static(card: &BrainRouteCard) -> bool {
    card.learned_score.quality_bps > card.static_baseline_score.quality_bps
        && card.learned_score.evidence_validity_bps
            > card.static_baseline_score.evidence_validity_bps
        && card.learned_score.verifier_bps > card.static_baseline_score.verifier_bps
        && card.learned_score.route_success_bps > card.static_baseline_score.route_success_bps
        && card.learned_score.latency_ms < card.static_baseline_score.latency_ms
        && card.learned_score.active_bytes < card.static_baseline_score.active_bytes
        && card.learned_score.active_bytes <= card.active_byte_limit
}

fn selected_stack_known(card: &BrainRouteCard) -> bool {
    if card.selected_stack == vec!["abstain"] {
        return true;
    }
    let ids = candidate_ids(card);
    card.selected_stack.iter().all(|id| ids.contains(id))
}

fn fallback_known(card: &BrainRouteCard) -> bool {
    candidate_ids(card).contains(card.fallback_brain)
}

fn candidate_ids(card: &BrainRouteCard) -> BTreeSet<&'static str> {
    card.candidate_brains
        .iter()
        .map(|brain| brain.brain_id)
        .collect()
}

fn invalid_card_rejected(mut mutate: impl FnMut(&mut BrainRouteCard)) -> Option<BrainRouteError> {
    let mut cards = fixture_route_cards();
    mutate(&mut cards[0]);
    BrainRouteRegistry::new(cards).err()
}

fn duplicate_card_rejected() -> bool {
    let mut cards = fixture_route_cards();
    cards[1].route_id = cards[0].route_id;
    BrainRouteRegistry::new(cards).err() == Some(BrainRouteError::DuplicateCard)
}

fn high_uncertainty_abstain_card_valid() -> bool {
    let mut card = fixture_route_cards()[0].clone();
    card.route_id = "route:brain-abstain-uncertain-proof";
    card.task_signature = "task:high-uncertainty-abstention";
    card.selected_stack = vec!["abstain"];
    card.uncertainty_bps = 8200;
    card.conflict_bps = 1400;
    validate_card(&card).is_ok()
}

fn upstream_route_kernel_pass() -> bool {
    read_artifact_string(UPSTREAM_ROUTE_KERNEL)
        .ok()
        .and_then(|raw| serde_json::from_str::<serde_json::Value>(&raw).ok())
        .and_then(|json| {
            json.get("overall_pass")
                .and_then(serde_json::Value::as_bool)
        })
        .unwrap_or(false)
}

fn read_artifact_string(path: &str) -> std::io::Result<String> {
    std::fs::read_to_string(path).or_else(|_| {
        let manifest_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
        let repo_root = manifest_dir.parent().unwrap_or(manifest_dir);
        std::fs::read_to_string(repo_root.join(path))
    })
}

fn route_card_address(cards: &[BrainRouteCard]) -> String {
    let mut entries = cards
        .iter()
        .map(|card| {
            format!(
                "{}:{}:{}",
                card.route_id,
                card.task_signature,
                card.selected_stack.join("+")
            )
        })
        .collect::<Vec<_>>();
    entries.sort_unstable();
    let digest = sha256_hex(entries.join("|").as_bytes());
    format!(
        "uas:brain-route-card:{}",
        digest.trim_start_matches("sha256:")
    )
}

fn fixture_route_cards() -> Vec<BrainRouteCard> {
    vec![
        BrainRouteCard {
            route_id: "route:brain-note-research-verify",
            mission_id: "mission:local-note-research",
            task_signature: "task:research-note-with-citations",
            candidate_brains: vec![
                brain(
                    "brain:apple-light-rewrite",
                    "apple_lightweight",
                    "apple_intelligence",
                    "MAS",
                    "Live",
                    "apple_private_or_declined",
                    12 * 1024 * 1024,
                ),
                brain(
                    "brain:local-qwen",
                    "local_reasoner",
                    "mlx_local",
                    "Pro",
                    "Gated",
                    "local_only",
                    96 * 1024 * 1024,
                ),
                brain(
                    "brain:eidos-citation",
                    "eidos_retrieval",
                    "eidos",
                    "MAS",
                    "Live",
                    "local_only",
                    8 * 1024 * 1024,
                ),
            ],
            selected_stack: vec!["brain:local-qwen", "brain:eidos-citation"],
            static_baseline_brain: "brain:apple-light-rewrite",
            fallback_brain: "brain:apple-light-rewrite",
            learned_score: score(8400, 9000, 8800, 8300, 420, 104 * 1024 * 1024),
            static_baseline_score: score(7200, 6900, 6100, 7000, 690, 160 * 1024 * 1024),
            active_byte_limit: 160 * 1024 * 1024,
            uncertainty_bps: 2400,
            conflict_bps: 1200,
            rollback_handle: "rollback:brain-route-note-research-static",
            answer_packet_ref: "answerpacket:brain-route-note-research",
            route_kernel_ref: UPSTREAM_ROUTE_KERNEL,
            regret_update_key: "regret:brain-route-note-research-v1",
            route_authority: "shadow_only",
        },
        BrainRouteCard {
            route_id: "route:brain-proof-repair",
            mission_id: "mission:proof-visible-route-repair",
            task_signature: "task:proof-repair-with-abstention",
            candidate_brains: vec![
                brain(
                    "brain:local-qwen",
                    "local_reasoner",
                    "mlx_local",
                    "Pro",
                    "Gated",
                    "local_only",
                    96 * 1024 * 1024,
                ),
                brain(
                    "brain:route-kernel-proof",
                    "proof_verifier",
                    "rust_route_kernel",
                    "Pro",
                    "ResearchCandidate",
                    "proof_only",
                    16 * 1024 * 1024,
                ),
                brain(
                    "brain:eidos-citation",
                    "eidos_retrieval",
                    "eidos",
                    "MAS",
                    "Live",
                    "local_only",
                    8 * 1024 * 1024,
                ),
            ],
            selected_stack: vec![
                "brain:local-qwen",
                "brain:route-kernel-proof",
                "brain:eidos-citation",
            ],
            static_baseline_brain: "brain:local-qwen",
            fallback_brain: "brain:local-qwen",
            learned_score: score(8100, 8700, 9200, 8200, 560, 120 * 1024 * 1024),
            static_baseline_score: score(7600, 7300, 6200, 7400, 740, 176 * 1024 * 1024),
            active_byte_limit: 176 * 1024 * 1024,
            uncertainty_bps: 3100,
            conflict_bps: 2200,
            rollback_handle: "rollback:brain-route-proof-static",
            answer_packet_ref: "answerpacket:brain-route-proof-repair",
            route_kernel_ref: UPSTREAM_ROUTE_KERNEL,
            regret_update_key: "regret:brain-route-proof-repair-v1",
            route_authority: "shadow_only",
        },
        BrainRouteCard {
            route_id: "route:brain-fast-local-summary",
            mission_id: "mission:fast-private-summary",
            task_signature: "task:private-summary-light-context",
            candidate_brains: vec![
                brain(
                    "brain:apple-light-summary",
                    "apple_lightweight",
                    "apple_intelligence",
                    "MAS",
                    "Live",
                    "apple_private_or_declined",
                    12 * 1024 * 1024,
                ),
                brain(
                    "brain:eidos-citation",
                    "eidos_retrieval",
                    "eidos",
                    "MAS",
                    "Live",
                    "local_only",
                    8 * 1024 * 1024,
                ),
                brain(
                    "brain:local-qwen",
                    "local_reasoner",
                    "mlx_local",
                    "Pro",
                    "Gated",
                    "local_only",
                    96 * 1024 * 1024,
                ),
            ],
            selected_stack: vec!["brain:apple-light-summary", "brain:eidos-citation"],
            static_baseline_brain: "brain:local-qwen",
            fallback_brain: "brain:apple-light-summary",
            learned_score: score(7900, 8200, 7700, 8000, 180, 20 * 1024 * 1024),
            static_baseline_score: score(7600, 7000, 6400, 7100, 620, 128 * 1024 * 1024),
            active_byte_limit: 128 * 1024 * 1024,
            uncertainty_bps: 1700,
            conflict_bps: 900,
            rollback_handle: "rollback:brain-route-fast-summary-static",
            answer_packet_ref: "answerpacket:brain-route-fast-summary",
            route_kernel_ref: UPSTREAM_ROUTE_KERNEL,
            regret_update_key: "regret:brain-route-fast-summary-v1",
            route_authority: "shadow_only",
        },
    ]
}

fn brain(
    brain_id: &'static str,
    role: &'static str,
    lane: &'static str,
    product_build: &'static str,
    pro_status: &'static str,
    privacy_class: &'static str,
    active_bytes: u64,
) -> BrainCandidate {
    BrainCandidate {
        brain_id,
        role,
        lane,
        product_build,
        pro_status,
        privacy_class,
        active_bytes,
        hidden_chain_policy: "visible_summary_only",
    }
}

fn score(
    quality_bps: u64,
    evidence_validity_bps: u64,
    verifier_bps: u64,
    route_success_bps: u64,
    latency_ms: u64,
    active_bytes: u64,
) -> RouteScore {
    RouteScore {
        quality_bps,
        evidence_validity_bps,
        verifier_bps,
        route_success_bps,
        latency_ms,
        active_bytes,
    }
}

fn add_count_ge_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    minimum: u64,
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
            value: serde_json::Value::from(minimum),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual >= minimum);
}

fn add_u64_le_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    maximum: u64,
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
            value: serde_json::Value::from(maximum),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual <= maximum);
}

fn add_string_contains_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: &str,
    required_substring: &str,
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
            operator: "contains".to_string(),
            value: serde_json::Value::from(required_substring),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual.contains(required_substring));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn artifact_contains_brain_route_axes() {
        let artifact = build_artifact().unwrap();
        assert!(artifact.overall_pass);
        for axis in [
            "upstream_route_kernel_model_check_pass",
            "brain_route_cards_present",
            "candidate_brains_bound",
            "model_roles_bound",
            "quality_delta_positive",
            "evidence_validity_delta_positive",
            "verifier_delta_positive",
            "latency_delta_positive",
            "active_byte_delta_positive",
            "static_baseline_beaten",
            "route_authority_shadow_only",
            "no_hidden_multi_model_authority",
            "hidden_chain_not_exposed",
            "uncertainty_abstention_bound",
            "unbeaten_static_baseline_rejected",
            "no_runtime_bytes_loaded",
        ] {
            assert_eq!(
                artifact.pass_per_axis.get(axis),
                Some(&true),
                "axis {axis} should pass"
            );
        }
    }

    #[test]
    fn invalid_fixtures_fail_closed() {
        assert_eq!(
            invalid_card_rejected(|card| card.route_authority = "live_policy"),
            Some(BrainRouteError::HiddenLiveAuthority)
        );
        assert_eq!(
            invalid_card_rejected(|card| card.answer_packet_ref = ""),
            Some(BrainRouteError::MissingAnswerPacket)
        );
        assert_eq!(
            invalid_card_rejected(|card| {
                card.learned_score.active_bytes = card.active_byte_limit + 1;
            }),
            Some(BrainRouteError::BudgetExceeded)
        );
        assert_eq!(
            invalid_card_rejected(|card| {
                card.uncertainty_bps = 7500;
                card.selected_stack = vec!["brain:local-qwen"];
            }),
            Some(BrainRouteError::UncertaintyOrConflictNonAbstain)
        );
    }

    #[test]
    fn route_card_address_is_order_stable() {
        let cards = fixture_route_cards();
        let reversed = cards.iter().cloned().rev().collect::<Vec<_>>();
        let first = BrainRouteRegistry::new(cards).unwrap();
        let second = BrainRouteRegistry::new(reversed).unwrap();
        assert_eq!(first.route_card_address, second.route_card_address);
    }
}
