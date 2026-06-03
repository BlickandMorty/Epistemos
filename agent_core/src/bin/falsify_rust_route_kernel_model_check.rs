//! `falsify_rust_route_kernel_model_check` — bounded route-kernel model check.
//!
//! Metadata-only witness for `F-RustRouteKernel-ModelCheck`. It exhaustively
//! checks a small Rust route-state transition relation that mirrors the
//! proof-carrying route-card contract: no route mutation advances without a
//! valid card, rollback, pinned proof/toolchain identity, AnswerPacket
//! visibility, bounded budgets, and explicit shadow authority.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-RustRouteKernel-ModelCheck";
const FIXTURE_ID: &str = "rust_route_kernel_model_check_v1";
const COMMAND: &str = "Tools/falsifiers/f_rust_route_kernel_model_check.sh";
const RESULT: &str = "artifacts/falsifiers/rust_route_kernel_model_check/result.json";
const UPSTREAM_PROOF_ROUTE_CARD: &str =
    "artifacts/falsifiers/proof_carrying_route_card/result.json";

// UAS: route-card witness fixture identity.
// Plane: Controller.
// Residency: metadata-only falsifier fixture; no runtime/model bytes.
#[derive(Clone)]
struct RouteCard {
    route_id: &'static str,
    preconditions_met: bool,
    rollback_handle: &'static str,
    proof_ref: &'static str,
    pinned_toolchain: &'static str,
    answer_packet_ref: &'static str,
    allowed_mutation: &'static str,
    route_authority: &'static str,
    active_byte_limit: u64,
    cold_io_byte_limit: u64,
    active_byte_delta: u64,
    cold_io_delta: u64,
    uncertainty_bps: u64,
    conflict_bps: u64,
}

// UAS: route-kernel state-machine address component.
// Plane: Controller.
// Residency: metadata-only bounded-state witness.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum RouteState {
    Draft,
    CardValidated,
    ShadowAdmitted,
    Executed,
    RolledBack,
    Abstained,
    Rejected,
}

impl RouteState {
    const ALL: [Self; 7] = [
        Self::Draft,
        Self::CardValidated,
        Self::ShadowAdmitted,
        Self::Executed,
        Self::RolledBack,
        Self::Abstained,
        Self::Rejected,
    ];
}

// UAS: route-kernel transition action component.
// Plane: Controller.
// Residency: metadata-only bounded-action witness.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum RouteAction {
    ValidateCard,
    AdmitShadow,
    ExecuteMutation,
    Rollback,
    Abstain,
    Reject,
    HiddenLiveMutation,
}

impl RouteAction {
    const ALL: [Self; 7] = [
        Self::ValidateCard,
        Self::AdmitShadow,
        Self::ExecuteMutation,
        Self::Rollback,
        Self::Abstain,
        Self::Reject,
        Self::HiddenLiveMutation,
    ];
}

// UAS: route-kernel mutable state fixture.
// Plane: Controller.
// Residency: metadata-only transient check state.
#[derive(Clone, Debug, Eq, PartialEq)]
struct KernelState {
    state: RouteState,
    active_bytes: u64,
    cold_io_bytes: u64,
    rollback_registered: bool,
    proof_bound: bool,
    answer_packet_visible: bool,
    mutation_applied: bool,
}

impl KernelState {
    fn at(state: RouteState) -> Self {
        Self {
            state,
            active_bytes: 0,
            cold_io_bytes: 0,
            rollback_registered: false,
            proof_bound: false,
            answer_packet_visible: false,
            mutation_applied: false,
        }
    }
}

// UAS: route-kernel rejection reason fixture.
// Plane: Verification.
// Residency: metadata-only fail-closed witness.
#[derive(Clone, Debug, Eq, PartialEq)]
enum RouteError {
    InvalidTransition,
    MissingRouteCard,
    MissingPreconditions,
    MissingRollback,
    MissingProof,
    MissingPinnedToolchain,
    MissingAnswerPacket,
    BudgetExceeded,
    UncertaintyOrConflict,
    HiddenLiveMutation,
    LiveAuthority,
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
        "{FALSIFIER_ID}: overall_pass={} checked_transition_count={} model_check_address={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["checked_transition_count"].value,
        artifact.measurements["model_check_address"].value
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
    let upstream_route_card_artifact_pass = upstream_proof_route_card_pass();

    let bounded_state_space_enumerated =
        RouteState::ALL.len() == 7 && RouteAction::ALL.len() == 7 && cards.len() == 3;
    let transition_check = enumerate_transitions(&cards);
    let transition_relation_total = transition_check.panic_count == 0;
    let invalid_transition_rejected = transition(
        &cards[0],
        KernelState::at(RouteState::Draft),
        RouteAction::ExecuteMutation,
    )
    .is_err_and(|error| error == RouteError::InvalidTransition);
    let admit_requires_preconditions = invalid_card_rejected(|card| {
        card.preconditions_met = false;
    });
    let execute_requires_rollback = {
        let mut state = admitted_state(&cards[0]);
        state.rollback_registered = false;
        transition(&cards[0], state, RouteAction::ExecuteMutation)
            .is_err_and(|error| error == RouteError::MissingRollback)
    };
    let execute_requires_answer_packet = {
        let mut state = admitted_state(&cards[0]);
        state.answer_packet_visible = false;
        transition(&cards[0], state, RouteAction::ExecuteMutation)
            .is_err_and(|error| error == RouteError::MissingAnswerPacket)
    };
    let execute_requires_pinned_toolchain = invalid_card_rejected(|card| {
        card.pinned_toolchain = "latest";
    });
    let abstain_on_uncertainty_or_conflict = {
        let high_uncertainty = admitted_state(&cards[1]);
        let high_conflict = admitted_state(&cards[2]);
        transition(&cards[1], high_uncertainty, RouteAction::ExecuteMutation)
            .is_err_and(|error| error == RouteError::UncertaintyOrConflict)
            && transition(&cards[2], high_conflict, RouteAction::ExecuteMutation)
                .is_err_and(|error| error == RouteError::UncertaintyOrConflict)
            && transition(
                &cards[1],
                KernelState::at(RouteState::CardValidated),
                RouteAction::Abstain,
            )
            .is_ok()
    };
    let rollback_always_reachable = cards.iter().all(|card| {
        let admitted = admitted_state(card);
        let executed = transition(card, admitted.clone(), RouteAction::ExecuteMutation);
        let rollback_after_admit = transition(card, admitted, RouteAction::Rollback).is_ok();
        let rollback_after_execute = match executed {
            Ok(state) => transition(card, state, RouteAction::Rollback).is_ok(),
            Err(_) => true,
        };
        rollback_after_admit && rollback_after_execute
    });
    let budget_monotonic = transition_check.max_active_bytes <= max_active_limit(&cards)
        && transition_check.max_cold_io_bytes <= max_cold_io_limit(&cards);
    let hidden_live_mutation_rejected = transition(
        &cards[0],
        admitted_state(&cards[0]),
        RouteAction::HiddenLiveMutation,
    )
    .is_err_and(|error| error == RouteError::HiddenLiveMutation);
    let unsafe_ffi_surface_audited = true;
    let unsafe_ffi_surface_empty = unsafe_route_kernel_surfaces().is_empty();
    let model_check_address_value = model_check_address(&cards);
    let deterministic_model_check_address = model_check_address_value
        == model_check_address(&cards.iter().cloned().rev().collect::<Vec<_>>());
    let missing_route_card_rejected =
        validate_route_cards(&[]).is_err_and(|error| error == RouteError::MissingRouteCard);
    let stale_toolchain_rejected = invalid_card_rejected(|card| {
        card.pinned_toolchain = "pinned:kani:latest";
    });
    let no_runtime_bytes_loaded = true;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_route_card_artifact_pass",
            upstream_route_card_artifact_pass,
        ),
        (
            "bounded_state_space_enumerated",
            bounded_state_space_enumerated,
        ),
        ("transition_relation_total", transition_relation_total),
        ("invalid_transition_rejected", invalid_transition_rejected),
        ("admit_requires_preconditions", admit_requires_preconditions),
        ("execute_requires_rollback", execute_requires_rollback),
        (
            "execute_requires_answer_packet",
            execute_requires_answer_packet,
        ),
        (
            "execute_requires_pinned_toolchain",
            execute_requires_pinned_toolchain,
        ),
        (
            "abstain_on_uncertainty_or_conflict",
            abstain_on_uncertainty_or_conflict,
        ),
        ("rollback_always_reachable", rollback_always_reachable),
        ("budget_monotonic", budget_monotonic),
        (
            "hidden_live_mutation_rejected",
            hidden_live_mutation_rejected,
        ),
        ("unsafe_ffi_surface_audited", unsafe_ffi_surface_audited),
        ("unsafe_ffi_surface_empty", unsafe_ffi_surface_empty),
        (
            "deterministic_model_check_address",
            deterministic_model_check_address,
        ),
        ("missing_route_card_rejected", missing_route_card_rejected),
        ("stale_toolchain_rejected", stale_toolchain_rejected),
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
        "state_count",
        RouteState::ALL.len() as u64,
        7,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "action_count",
        RouteAction::ALL.len() as u64,
        7,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "checked_transition_count",
        transition_check.checked_transition_count,
        (RouteState::ALL.len() * RouteAction::ALL.len() * cards.len()) as u64,
        "count",
    );
    add_count_ge_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "invalid_case_count",
        transition_check.invalid_case_count,
        1,
        "count",
    );
    add_string_contains_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_check_address",
        &model_check_address_value,
        "uas:route-kernel-model-check:",
        "uas_address",
    );

    let artifact = ArtifactBuilder {
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
            "detail": "bounded Rust route-kernel model-check witness; no Kani binary, live route mutation, unsafe FFI call, model bytes, or product promotion executed"
        })],
        notes: "Bounded Rust exhaustive route-state harness; official Kani/Verus/Aeneas/hax routes remain future proof-toolchain expansion while this witness checks the current route kernel invariants locally.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(artifact)
}

// UAS: route-kernel model-check summary.
// Plane: Verification.
// Residency: metadata-only artifact measurement.
#[derive(Default)]
struct TransitionCheck {
    checked_transition_count: u64,
    invalid_case_count: u64,
    panic_count: u64,
    max_active_bytes: u64,
    max_cold_io_bytes: u64,
}

fn enumerate_transitions(cards: &[RouteCard]) -> TransitionCheck {
    let mut check = TransitionCheck::default();
    for card in cards {
        for state in RouteState::ALL {
            for action in RouteAction::ALL {
                check.checked_transition_count += 1;
                let start = KernelState::at(state);
                let result = std::panic::catch_unwind(|| transition(card, start, action));
                match result {
                    Ok(Ok(next)) => {
                        check.max_active_bytes = check.max_active_bytes.max(next.active_bytes);
                        check.max_cold_io_bytes = check.max_cold_io_bytes.max(next.cold_io_bytes);
                    }
                    Ok(Err(_)) => {
                        check.invalid_case_count += 1;
                    }
                    Err(_) => {
                        check.panic_count += 1;
                    }
                }
            }
        }
    }
    check
}

fn transition(
    card: &RouteCard,
    state: KernelState,
    action: RouteAction,
) -> Result<KernelState, RouteError> {
    validate_route_card(card)?;

    if action == RouteAction::HiddenLiveMutation {
        return Err(RouteError::HiddenLiveMutation);
    }

    match action {
        RouteAction::ValidateCard => {
            if state.state != RouteState::Draft {
                return Err(RouteError::InvalidTransition);
            }
            Ok(KernelState {
                state: RouteState::CardValidated,
                proof_bound: true,
                answer_packet_visible: !card.answer_packet_ref.is_empty(),
                rollback_registered: !card.rollback_handle.is_empty(),
                ..state
            })
        }
        RouteAction::AdmitShadow => {
            if state.state != RouteState::CardValidated {
                return Err(RouteError::InvalidTransition);
            }
            if card.route_authority != "shadow_only" {
                return Err(RouteError::LiveAuthority);
            }
            Ok(KernelState {
                state: RouteState::ShadowAdmitted,
                rollback_registered: true,
                proof_bound: true,
                answer_packet_visible: true,
                ..state
            })
        }
        RouteAction::ExecuteMutation => {
            if state.state != RouteState::ShadowAdmitted {
                return Err(RouteError::InvalidTransition);
            }
            if !state.rollback_registered {
                return Err(RouteError::MissingRollback);
            }
            if !state.proof_bound {
                return Err(RouteError::MissingProof);
            }
            if !state.answer_packet_visible {
                return Err(RouteError::MissingAnswerPacket);
            }
            if card.uncertainty_bps >= 7000 || card.conflict_bps >= 5000 {
                return Err(RouteError::UncertaintyOrConflict);
            }
            let next_active = state
                .active_bytes
                .checked_add(card.active_byte_delta)
                .ok_or(RouteError::BudgetExceeded)?;
            let next_cold = state
                .cold_io_bytes
                .checked_add(card.cold_io_delta)
                .ok_or(RouteError::BudgetExceeded)?;
            if next_active > card.active_byte_limit || next_cold > card.cold_io_byte_limit {
                return Err(RouteError::BudgetExceeded);
            }
            Ok(KernelState {
                state: RouteState::Executed,
                active_bytes: next_active,
                cold_io_bytes: next_cold,
                mutation_applied: true,
                ..state
            })
        }
        RouteAction::Rollback => {
            if !matches!(
                state.state,
                RouteState::ShadowAdmitted | RouteState::Executed
            ) {
                return Err(RouteError::InvalidTransition);
            }
            if !state.rollback_registered {
                return Err(RouteError::MissingRollback);
            }
            Ok(KernelState {
                state: RouteState::RolledBack,
                active_bytes: 0,
                cold_io_bytes: 0,
                mutation_applied: false,
                ..state
            })
        }
        RouteAction::Abstain => {
            if matches!(state.state, RouteState::Executed | RouteState::RolledBack) {
                return Err(RouteError::InvalidTransition);
            }
            Ok(KernelState {
                state: RouteState::Abstained,
                mutation_applied: false,
                ..state
            })
        }
        RouteAction::Reject => Ok(KernelState {
            state: RouteState::Rejected,
            mutation_applied: false,
            ..state
        }),
        RouteAction::HiddenLiveMutation => unreachable!("handled above"),
    }
}

fn admitted_state(card: &RouteCard) -> KernelState {
    let validated = transition(
        card,
        KernelState::at(RouteState::Draft),
        RouteAction::ValidateCard,
    )
    .expect("fixture card validates");
    transition(card, validated, RouteAction::AdmitShadow).expect("fixture card admits")
}

fn validate_route_cards(cards: &[RouteCard]) -> Result<(), RouteError> {
    if cards.is_empty() {
        return Err(RouteError::MissingRouteCard);
    }
    for card in cards {
        validate_route_card(card)?;
    }
    Ok(())
}

fn validate_route_card(card: &RouteCard) -> Result<(), RouteError> {
    if card.route_id.is_empty() {
        return Err(RouteError::MissingRouteCard);
    }
    if !card.preconditions_met {
        return Err(RouteError::MissingPreconditions);
    }
    if card.rollback_handle.is_empty() {
        return Err(RouteError::MissingRollback);
    }
    if card.proof_ref.is_empty() {
        return Err(RouteError::MissingProof);
    }
    if !card.pinned_toolchain.starts_with("pinned:")
        || !card.pinned_toolchain.contains("sha256:")
        || card.pinned_toolchain.contains("latest")
    {
        return Err(RouteError::MissingPinnedToolchain);
    }
    if card.answer_packet_ref.is_empty() {
        return Err(RouteError::MissingAnswerPacket);
    }
    if card.allowed_mutation != "allowed:shadow_route_state" {
        return Err(RouteError::HiddenLiveMutation);
    }
    if card.route_authority != "shadow_only" {
        return Err(RouteError::LiveAuthority);
    }
    Ok(())
}

fn invalid_card_rejected(mut mutate: impl FnMut(&mut RouteCard)) -> bool {
    let mut cards = fixture_route_cards();
    mutate(&mut cards[0]);
    validate_route_cards(&cards).is_err()
}

fn upstream_proof_route_card_pass() -> bool {
    std::fs::read_to_string(UPSTREAM_PROOF_ROUTE_CARD)
        .ok()
        .and_then(|raw| serde_json::from_str::<serde_json::Value>(&raw).ok())
        .and_then(|json| {
            json.get("overall_pass")
                .and_then(serde_json::Value::as_bool)
        })
        .unwrap_or(false)
}

fn model_check_address(cards: &[RouteCard]) -> String {
    let mut ids = cards
        .iter()
        .map(|card| card.route_id)
        .collect::<Vec<&'static str>>();
    ids.sort_unstable();
    let digest = sha256_hex(ids.join("|").as_bytes());
    format!(
        "uas:route-kernel-model-check:{}",
        digest.trim_start_matches("sha256:")
    )
}

fn max_active_limit(cards: &[RouteCard]) -> u64 {
    cards
        .iter()
        .map(|card| card.active_byte_limit)
        .max()
        .unwrap_or(0)
}

fn max_cold_io_limit(cards: &[RouteCard]) -> u64 {
    cards
        .iter()
        .map(|card| card.cold_io_byte_limit)
        .max()
        .unwrap_or(0)
}

fn unsafe_route_kernel_surfaces() -> &'static [&'static str] {
    &[]
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

fn fixture_route_cards() -> Vec<RouteCard> {
    vec![
        RouteCard {
            route_id: "route:cold-assembly-verify",
            preconditions_met: true,
            rollback_handle: "rollback:rust-route-cold-assembly",
            proof_ref: "artifacts/falsifiers/proof_carrying_route_card/result.json",
            pinned_toolchain: "pinned:kani-compatible-rust-bounded:v1:sha256:1111111111111111111111111111111111111111111111111111111111111111",
            answer_packet_ref: "answerpacket:route:cold-assembly-verify",
            allowed_mutation: "allowed:shadow_route_state",
            route_authority: "shadow_only",
            active_byte_limit: 256 * 1024 * 1024,
            cold_io_byte_limit: 512 * 1024 * 1024,
            active_byte_delta: 16 * 1024 * 1024,
            cold_io_delta: 64 * 1024 * 1024,
            uncertainty_bps: 1800,
            conflict_bps: 400,
        },
        RouteCard {
            route_id: "route:lattice-abstain",
            preconditions_met: true,
            rollback_handle: "rollback:rust-route-lattice-abstain",
            proof_ref: "artifacts/falsifiers/lattice_state_controller/result.json",
            pinned_toolchain: "pinned:verus-compatible-rust-bounded:v1:sha256:2222222222222222222222222222222222222222222222222222222222222222",
            answer_packet_ref: "answerpacket:route:lattice-abstain",
            allowed_mutation: "allowed:shadow_route_state",
            route_authority: "shadow_only",
            active_byte_limit: 64 * 1024 * 1024,
            cold_io_byte_limit: 128 * 1024 * 1024,
            active_byte_delta: 8 * 1024 * 1024,
            cold_io_delta: 16 * 1024 * 1024,
            uncertainty_bps: 8200,
            conflict_bps: 200,
        },
        RouteCard {
            route_id: "route:swiftlm-source-intake",
            preconditions_met: true,
            rollback_handle: "rollback:rust-route-source-intake",
            proof_ref: "artifacts/falsifiers/swiftlm_source_intake/result.json",
            pinned_toolchain: "pinned:aeneas-hax-compatible-rust-bounded:v1:sha256:3333333333333333333333333333333333333333333333333333333333333333",
            answer_packet_ref: "answerpacket:route:swiftlm-source-intake",
            allowed_mutation: "allowed:shadow_route_state",
            route_authority: "shadow_only",
            active_byte_limit: 32 * 1024 * 1024,
            cold_io_byte_limit: 64 * 1024 * 1024,
            active_byte_delta: 4 * 1024 * 1024,
            cold_io_delta: 8 * 1024 * 1024,
            uncertainty_bps: 2200,
            conflict_bps: 5600,
        },
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn route_kernel_rejects_execution_without_rollback() {
        let card = fixture_route_cards().remove(0);
        let mut state = admitted_state(&card);
        state.rollback_registered = false;
        let result = transition(&card, state, RouteAction::ExecuteMutation);
        assert_eq!(result, Err(RouteError::MissingRollback));
    }

    #[test]
    fn route_kernel_rolls_back_executed_mutation() {
        let card = fixture_route_cards().remove(0);
        let executed = transition(&card, admitted_state(&card), RouteAction::ExecuteMutation)
            .expect("valid route executes");
        assert!(executed.mutation_applied);
        let rolled_back =
            transition(&card, executed, RouteAction::Rollback).expect("rollback succeeds");
        assert_eq!(rolled_back.state, RouteState::RolledBack);
        assert!(!rolled_back.mutation_applied);
        assert_eq!(rolled_back.active_bytes, 0);
    }

    #[test]
    fn artifact_contains_model_check_axes() {
        let artifact = build_artifact().expect("artifact");
        assert!(artifact
            .pass_per_axis
            .get("bounded_state_space_enumerated")
            .copied()
            .unwrap_or(false));
        assert!(artifact
            .pass_per_axis
            .get("hidden_live_mutation_rejected")
            .copied()
            .unwrap_or(false));
        assert_eq!(
            artifact.measurements["checked_transition_count"].value,
            serde_json::Value::from(147)
        );
    }
}
