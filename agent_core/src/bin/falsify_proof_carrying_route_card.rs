//! `falsify_proof_carrying_route_card` — proof route-card contract gate.
//!
//! Metadata-only witness for `F-ProofCarryingRouteCard`. It proves route cards
//! bind route intent, pre/postconditions, budgets, transition rules, rollback,
//! proof/model-check artifacts, pinned toolchains, and AnswerPacket visibility
//! before route execution may cite them.

use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder,
    ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-ProofCarryingRouteCard";
const FIXTURE_ID: &str = "proof_carrying_route_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_proof_carrying_route_card.sh";
const RESULT: &str = "artifacts/falsifiers/proof_carrying_route_card/result.json";

#[derive(Clone)]
struct BudgetInvariant {
    active_byte_limit: u64,
    kv_byte_limit: u64,
    cold_io_byte_limit: u64,
    max_active_byte_increase: u64,
}

#[derive(Clone)]
struct RouteTransition {
    from_state: &'static str,
    to_state: &'static str,
    transition_kind: &'static str,
}

#[derive(Clone)]
struct ProofCarryingRouteCard {
    route_id: &'static str,
    mission_id: &'static str,
    preconditions: Vec<&'static str>,
    postconditions: Vec<&'static str>,
    budget: BudgetInvariant,
    state_transition: RouteTransition,
    allowed_mutations: Vec<&'static str>,
    rollback_handle: &'static str,
    proof_artifact_or_model_check_artifact: &'static str,
    kernel_or_toolchain_version: &'static str,
    answer_packet_ref: &'static str,
    answer_packet_fields: Vec<&'static str>,
}

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
        "{FALSIFIER_ID}: overall_pass={} route_card_count={} route_card_address={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["route_card_count"].value,
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
    let fixture = fixture_route_cards();
    let registry = RouteCardRegistry::new(fixture.clone())?;
    let reversed = RouteCardRegistry::new(fixture.iter().cloned().rev().collect())?;

    let route_cards_present = registry.cards.len() == 3;
    let route_ids_bound = registry
        .cards
        .iter()
        .all(|card| card.route_id.starts_with("route:"));
    let mission_ids_bound = registry
        .cards
        .iter()
        .all(|card| card.mission_id.starts_with("mission:"));
    let preconditions_bound = registry
        .cards
        .iter()
        .all(|card| !card.preconditions.is_empty() && card.preconditions.iter().all(nonempty));
    let postconditions_bound = registry
        .cards
        .iter()
        .all(|card| !card.postconditions.is_empty() && card.postconditions.iter().all(nonempty));
    let budget_invariants_bound = registry.cards.iter().all(|card| {
        card.budget.active_byte_limit > 0
            && card.budget.kv_byte_limit > 0
            && card.budget.cold_io_byte_limit > 0
            && card.budget.max_active_byte_increase == 0
    });
    let state_transition_bound = registry.cards.iter().all(|card| {
        !card.state_transition.from_state.is_empty()
            && !card.state_transition.to_state.is_empty()
            && matches!(
                card.state_transition.transition_kind,
                "monotonic" | "explicitly_reversible"
            )
    });
    let allowed_mutations_bound = registry.cards.iter().all(|card| {
        !card.allowed_mutations.is_empty()
            && card
                .allowed_mutations
                .iter()
                .all(|mutation| mutation.starts_with("allowed:"))
    });
    let rollback_handle_bound = registry
        .cards
        .iter()
        .all(|card| card.rollback_handle.starts_with("rollback:"));
    let proof_or_model_check_artifact_bound = registry.cards.iter().all(|card| {
        card.proof_artifact_or_model_check_artifact
            .starts_with("artifacts/")
            || card
                .proof_artifact_or_model_check_artifact
                .starts_with("docs/falsifiers/")
    });
    let pinned_toolchain_version_bound = registry.cards.iter().all(|card| {
        card.kernel_or_toolchain_version.starts_with("pinned:")
            && card.kernel_or_toolchain_version.contains("sha256:")
            && !card.kernel_or_toolchain_version.contains("latest")
    });
    let answer_packet_ref_bound = registry
        .cards
        .iter()
        .all(|card| card.answer_packet_ref.starts_with("answerpacket:"));
    let answer_packet_required_fields_bound = registry.cards.iter().all(|card| {
        let fields = card
            .answer_packet_fields
            .iter()
            .copied()
            .collect::<BTreeSet<_>>();
        [
            "route_id",
            "mission_id",
            "proof_ref",
            "rollback_handle",
            "budget_invariants",
        ]
        .iter()
        .all(|field| fields.contains(field))
    });
    let route_schema_complete = registry.cards.iter().all(card_is_valid);
    let route_card_address_deterministic =
        registry.route_card_address == reversed.route_card_address;
    let duplicate_route_card_rejected = duplicate_route_card_rejected();
    let missing_preconditions_rejected = invalid_card_rejected(|card| {
        card.preconditions.clear();
    });
    let missing_postconditions_rejected = invalid_card_rejected(|card| {
        card.postconditions.clear();
    });
    let missing_rollback_rejected = invalid_card_rejected(|card| {
        card.rollback_handle = "";
    });
    let missing_artifact_ref_rejected = invalid_card_rejected(|card| {
        card.proof_artifact_or_model_check_artifact = "";
    });
    let unpinned_toolchain_rejected = invalid_card_rejected(|card| {
        card.kernel_or_toolchain_version = "latest";
    });
    let missing_answer_packet_rejected = invalid_card_rejected(|card| {
        card.answer_packet_ref = "";
    });
    let budget_increase_rejected = invalid_card_rejected(|card| {
        card.budget.max_active_byte_increase = 1;
    });
    let hidden_live_mutation_rejected = invalid_card_rejected(|card| {
        card.allowed_mutations.push("live_hidden_route_mutation");
    });
    let no_runtime_bytes_loaded = true;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        ("proof_route_cards_present", route_cards_present),
        ("route_ids_bound", route_ids_bound),
        ("mission_ids_bound", mission_ids_bound),
        ("preconditions_bound", preconditions_bound),
        ("postconditions_bound", postconditions_bound),
        ("budget_invariants_bound", budget_invariants_bound),
        ("state_transition_bound", state_transition_bound),
        ("allowed_mutations_bound", allowed_mutations_bound),
        ("rollback_handle_bound", rollback_handle_bound),
        (
            "proof_or_model_check_artifact_bound",
            proof_or_model_check_artifact_bound,
        ),
        (
            "pinned_toolchain_version_bound",
            pinned_toolchain_version_bound,
        ),
        ("answer_packet_ref_bound", answer_packet_ref_bound),
        (
            "answer_packet_required_fields_bound",
            answer_packet_required_fields_bound,
        ),
        ("route_schema_complete", route_schema_complete),
        (
            "route_card_address_deterministic",
            route_card_address_deterministic,
        ),
        (
            "duplicate_route_card_rejected",
            duplicate_route_card_rejected,
        ),
        (
            "missing_preconditions_rejected",
            missing_preconditions_rejected,
        ),
        (
            "missing_postconditions_rejected",
            missing_postconditions_rejected,
        ),
        ("missing_rollback_rejected", missing_rollback_rejected),
        (
            "missing_artifact_ref_rejected",
            missing_artifact_ref_rejected,
        ),
        ("unpinned_toolchain_rejected", unpinned_toolchain_rejected),
        (
            "missing_answer_packet_rejected",
            missing_answer_packet_rejected,
        ),
        ("budget_increase_rejected", budget_increase_rejected),
        (
            "hidden_live_mutation_rejected",
            hidden_live_mutation_rejected,
        ),
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

    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_card_count",
        registry.cards.len() as u64,
        3,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_active_byte_limit",
        registry.max_active_byte_limit(),
        512 * 1024 * 1024,
        "<=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_cold_io_byte_limit",
        registry.max_cold_io_byte_limit(),
        1024 * 1024 * 1024,
        "<=",
    );
    measurements.insert(
        "route_card_address".to_string(),
        Measurement {
            value: serde_json::Value::String(registry.route_card_address.clone()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "route_card_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "route_card_address".to_string(),
        !registry.route_card_address.is_empty(),
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
            "detail": "metadata-only proof route-card registry; no Lean runtime, live route mutation, model bytes, or product promotion executed"
        })],
        notes: "Proves proof-carrying route cards bind route contracts, rollback, pinned proof/toolchain identity, and AnswerPacket fields before route execution may cite them.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

struct RouteCardRegistry {
    cards: Vec<ProofCarryingRouteCard>,
    route_card_address: String,
}

impl RouteCardRegistry {
    fn new(mut cards: Vec<ProofCarryingRouteCard>) -> Result<Self, &'static str> {
        let mut seen = BTreeSet::new();
        for card in &cards {
            if !seen.insert(card.route_id) {
                return Err("duplicate route id");
            }
            if !card_is_valid(card) {
                return Err("invalid proof-carrying route card");
            }
        }
        cards.sort_by(|a, b| a.route_id.cmp(b.route_id));
        let route_card_address = route_card_address(&cards);
        Ok(Self {
            cards,
            route_card_address,
        })
    }

    fn max_active_byte_limit(&self) -> u64 {
        self.cards
            .iter()
            .map(|card| card.budget.active_byte_limit)
            .max()
            .unwrap_or(0)
    }

    fn max_cold_io_byte_limit(&self) -> u64 {
        self.cards
            .iter()
            .map(|card| card.budget.cold_io_byte_limit)
            .max()
            .unwrap_or(0)
    }
}

fn fixture_route_cards() -> Vec<ProofCarryingRouteCard> {
    vec![
        card(
            "route:cold-assembly-verify",
            "mission:adversarial-note-cold-assembly",
            vec![
                "artifact:meta_breakthrough_card_registry:pass",
                "artifact:cold_assembly_plan_70b_lite:pass",
                "lease:proof_carrying_residency_lease:pass",
            ],
            vec![
                "answerpacket:route-proof-visible",
                "route-status:shadow-approved",
            ],
            256 * 1024 * 1024,
            64 * 1024 * 1024,
            512 * 1024 * 1024,
            "cold-assembly-shadow-planned",
            "cold-assembly-proof-visible",
            "explicitly_reversible",
            vec!["allowed:shadow_route_card", "allowed:answer_packet_append"],
            "rollback:proof-route-cold-assembly",
            "artifacts/falsifiers/cold_assembly_plan_70b_lite/result.json",
            "pinned:lean4:sha256:route-card-schema-v1",
            "answerpacket:cold-assembly-route-proof",
        ),
        card(
            "route:lattice-abstain",
            "mission:uncertain-route-abstention",
            vec![
                "artifact:lattice_state_controller:pass",
                "uncertainty:above-abstention-threshold",
            ],
            vec![
                "route-status:abstained",
                "answerpacket:abstention-reason-visible",
            ],
            64 * 1024 * 1024,
            16 * 1024 * 1024,
            128 * 1024 * 1024,
            "lattice-controller-evaluated",
            "route-abstained",
            "monotonic",
            vec!["allowed:answer_packet_append"],
            "rollback:proof-route-abstain",
            "artifacts/falsifiers/lattice_state_controller/result.json",
            "pinned:kani:sha256:lattice-route-check-v1",
            "answerpacket:lattice-abstention-proof",
        ),
        card(
            "route:swiftlm-source-intake",
            "mission:source-mined-motif-only",
            vec![
                "artifact:swiftlm_source_intake:pass",
                "no-code-import:true",
                "no-product-dependency:true",
            ],
            vec![
                "route-status:source-card-only",
                "answerpacket:source-caveat-visible",
            ],
            32 * 1024 * 1024,
            8 * 1024 * 1024,
            32 * 1024 * 1024,
            "source-intake-reviewed",
            "source-card-visible",
            "monotonic",
            vec!["allowed:source_card_append", "allowed:answer_packet_append"],
            "rollback:proof-route-source-intake",
            "artifacts/falsifiers/swiftlm_source_intake/result.json",
            "pinned:verus:sha256:source-intake-route-v1",
            "answerpacket:swiftlm-source-proof",
        ),
    ]
}

#[allow(clippy::too_many_arguments)]
fn card(
    route_id: &'static str,
    mission_id: &'static str,
    preconditions: Vec<&'static str>,
    postconditions: Vec<&'static str>,
    active_byte_limit: u64,
    kv_byte_limit: u64,
    cold_io_byte_limit: u64,
    from_state: &'static str,
    to_state: &'static str,
    transition_kind: &'static str,
    allowed_mutations: Vec<&'static str>,
    rollback_handle: &'static str,
    proof_artifact_or_model_check_artifact: &'static str,
    kernel_or_toolchain_version: &'static str,
    answer_packet_ref: &'static str,
) -> ProofCarryingRouteCard {
    ProofCarryingRouteCard {
        route_id,
        mission_id,
        preconditions,
        postconditions,
        budget: BudgetInvariant {
            active_byte_limit,
            kv_byte_limit,
            cold_io_byte_limit,
            max_active_byte_increase: 0,
        },
        state_transition: RouteTransition {
            from_state,
            to_state,
            transition_kind,
        },
        allowed_mutations,
        rollback_handle,
        proof_artifact_or_model_check_artifact,
        kernel_or_toolchain_version,
        answer_packet_ref,
        answer_packet_fields: vec![
            "route_id",
            "mission_id",
            "proof_ref",
            "rollback_handle",
            "budget_invariants",
        ],
    }
}

fn card_is_valid(card: &ProofCarryingRouteCard) -> bool {
    !card.route_id.is_empty()
        && card.route_id.starts_with("route:")
        && !card.mission_id.is_empty()
        && card.mission_id.starts_with("mission:")
        && !card.preconditions.is_empty()
        && card.preconditions.iter().all(nonempty)
        && !card.postconditions.is_empty()
        && card.postconditions.iter().all(nonempty)
        && card.budget.active_byte_limit > 0
        && card.budget.active_byte_limit <= 512 * 1024 * 1024
        && card.budget.kv_byte_limit > 0
        && card.budget.cold_io_byte_limit > 0
        && card.budget.cold_io_byte_limit <= 1024 * 1024 * 1024
        && card.budget.max_active_byte_increase == 0
        && !card.state_transition.from_state.is_empty()
        && !card.state_transition.to_state.is_empty()
        && matches!(
            card.state_transition.transition_kind,
            "monotonic" | "explicitly_reversible"
        )
        && !card.allowed_mutations.is_empty()
        && card
            .allowed_mutations
            .iter()
            .all(|mutation| mutation.starts_with("allowed:"))
        && card.rollback_handle.starts_with("rollback:")
        && (card
            .proof_artifact_or_model_check_artifact
            .starts_with("artifacts/")
            || card
                .proof_artifact_or_model_check_artifact
                .starts_with("docs/falsifiers/"))
        && card.kernel_or_toolchain_version.starts_with("pinned:")
        && card.kernel_or_toolchain_version.contains("sha256:")
        && !card.kernel_or_toolchain_version.contains("latest")
        && card.answer_packet_ref.starts_with("answerpacket:")
        && answer_packet_fields_complete(&card.answer_packet_fields)
}

fn answer_packet_fields_complete(fields: &[&str]) -> bool {
    let fields = fields.iter().copied().collect::<BTreeSet<_>>();
    [
        "route_id",
        "mission_id",
        "proof_ref",
        "rollback_handle",
        "budget_invariants",
    ]
    .iter()
    .all(|field| fields.contains(field))
}

fn nonempty(value: &&'static str) -> bool {
    !value.is_empty()
}

fn route_card_address(cards: &[ProofCarryingRouteCard]) -> String {
    let payload = cards
        .iter()
        .map(|card| {
            serde_json::json!({
                "route_id": card.route_id,
                "mission_id": card.mission_id,
                "preconditions": card.preconditions,
                "postconditions": card.postconditions,
                "active_byte_limit": card.budget.active_byte_limit,
                "kv_byte_limit": card.budget.kv_byte_limit,
                "cold_io_byte_limit": card.budget.cold_io_byte_limit,
                "max_active_byte_increase": card.budget.max_active_byte_increase,
                "from_state": card.state_transition.from_state,
                "to_state": card.state_transition.to_state,
                "transition_kind": card.state_transition.transition_kind,
                "allowed_mutations": card.allowed_mutations,
                "rollback_handle": card.rollback_handle,
                "proof_artifact_or_model_check_artifact": card.proof_artifact_or_model_check_artifact,
                "kernel_or_toolchain_version": card.kernel_or_toolchain_version,
                "answer_packet_ref": card.answer_packet_ref,
                "answer_packet_fields": card.answer_packet_fields,
            })
        })
        .collect::<Vec<_>>();
    let bytes = serde_json::to_vec(&payload).expect("serialize route-card payload");
    format!("uas:route-card:{}", blake3::hash(&bytes).to_hex())
}

fn duplicate_route_card_rejected() -> bool {
    let mut cards = fixture_route_cards();
    cards.push(cards[0].clone());
    RouteCardRegistry::new(cards).is_err()
}

fn invalid_card_rejected(mutate: impl FnOnce(&mut ProofCarryingRouteCard)) -> bool {
    let mut cards = fixture_route_cards();
    mutate(&mut cards[0]);
    RouteCardRegistry::new(cards).is_err()
}

fn add_bool_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    pass: bool,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::Bool(pass),
            unit: "bool".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "bool".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), pass);
}

fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    expected: u64,
    operator: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(actual)),
            unit: "count".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(expected)),
            unit: "count".to_string(),
        },
    );
    pass_per_axis.insert(
        name.to_string(),
        match operator {
            "<=" => actual <= expected,
            ">=" => actual >= expected,
            "==" => actual == expected,
            _ => false,
        },
    );
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn artifact_contains_route_card_contract_axes() {
        let artifact = build_artifact().unwrap();
        assert!(artifact.overall_pass);
        for axis in [
            "proof_route_cards_present",
            "preconditions_bound",
            "postconditions_bound",
            "rollback_handle_bound",
            "proof_or_model_check_artifact_bound",
            "pinned_toolchain_version_bound",
            "answer_packet_ref_bound",
            "missing_preconditions_rejected",
            "missing_rollback_rejected",
            "missing_artifact_ref_rejected",
            "unpinned_toolchain_rejected",
        ] {
            assert_eq!(artifact.pass_per_axis.get(axis), Some(&true));
        }
    }
}
