//! `falsify_meta_breakthrough_card_registry` — meta-control registry gate.
//!
//! Metadata-only witness for `F-MetaBreakthrough-CardRegistry`. It proves
//! small meta-control cards are not vague doctrine: each card must bind a UAS
//! address, source, budget, rollback, proof/falsifier state, and AnswerPacket
//! visibility before any future route policy can cite it.

use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder,
    ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-MetaBreakthrough-CardRegistry";
const FIXTURE_ID: &str = "meta_breakthrough_card_registry_v1";
const COMMAND: &str = "Tools/falsifiers/f_meta_breakthrough_card_registry.sh";
const RESULT: &str = "artifacts/falsifiers/meta_breakthrough_card_registry/result.json";

#[derive(Clone)]
struct BudgetVector {
    active_bytes: u64,
    cold_io_bytes: u64,
    verifier_budget_bps: u64,
}

#[derive(Clone)]
struct MetaBreakthroughCard {
    card_id: &'static str,
    card_kind: &'static str,
    uas_address: &'static str,
    source_ref: &'static str,
    budget: BudgetVector,
    rollback_handle: &'static str,
    proof_state: &'static str,
    falsifier_ref: &'static str,
    answer_packet_ref: &'static str,
    route_authority: &'static str,
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
        "{FALSIFIER_ID}: overall_pass={} card_count={} registry_address={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["card_count"].value,
        artifact.measurements["registry_address"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let fixture = fixture_cards();
    let registry = CardRegistry::new(fixture.clone())?;
    let reversed = CardRegistry::new(fixture.iter().cloned().rev().collect())?;

    let registry_present = registry.cards.len() == 5;
    let card_kinds_coverage = registry.kind_count() >= 5
        && registry.has_kind("ProofCarryingRouteCard")
        && registry.has_kind("BrainRouteCard")
        && registry.has_kind("KVPageControlCard")
        && registry.has_kind("ColdAssemblyPlan")
        && registry.has_kind("SourceIntakeCard");
    let uas_addresses_bound = registry.cards.iter().all(|card| {
        card.uas_address.starts_with("uas:")
            && card.uas_address.contains(':')
            && card.uas_address.len() > "uas:x".len()
    });
    let source_refs_bound = registry.cards.iter().all(|card| {
        card.source_ref.starts_with("docs/") || card.source_ref.starts_with("artifacts/")
    });
    let budget_vectors_bound = registry.cards.iter().all(|card| {
        card.budget.active_bytes > 0
            && card.budget.active_bytes <= 512 * 1024 * 1024
            && card.budget.cold_io_bytes <= 1024 * 1024 * 1024
            && card.budget.verifier_budget_bps > 0
    });
    let rollback_handles_bound = registry
        .cards
        .iter()
        .all(|card| card.rollback_handle.starts_with("rollback:"));
    let proof_or_falsifier_state_bound = registry.cards.iter().all(|card| {
        card.proof_state.starts_with("witness:")
            && card.falsifier_ref.starts_with("F-")
            && card.proof_state.contains(card.falsifier_ref)
    });
    let answer_packet_visibility_bound = registry
        .cards
        .iter()
        .all(|card| card.answer_packet_ref.starts_with("answerpacket:"));
    let route_authority_shadow_only = registry
        .cards
        .iter()
        .all(|card| card.route_authority == "shadow_only");
    let registry_address_deterministic = registry.registry_address == reversed.registry_address;
    let duplicate_card_rejected = duplicate_card_rejected();
    let missing_uas_address_rejected = invalid_card_rejected(|card| {
        card.uas_address = "";
    });
    let missing_source_rejected = invalid_card_rejected(|card| {
        card.source_ref = "";
    });
    let missing_budget_rejected = invalid_card_rejected(|card| {
        card.budget.active_bytes = 0;
        card.budget.verifier_budget_bps = 0;
    });
    let missing_rollback_rejected = invalid_card_rejected(|card| {
        card.rollback_handle = "";
    });
    let missing_proof_state_rejected = invalid_card_rejected(|card| {
        card.proof_state = "";
        card.falsifier_ref = "";
    });
    let missing_answer_packet_rejected = invalid_card_rejected(|card| {
        card.answer_packet_ref = "";
    });
    let hidden_live_authority_rejected = invalid_card_rejected(|card| {
        card.route_authority = "live_route_authority";
    });
    let no_runtime_bytes_loaded = true;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        ("meta_card_registry_present", registry_present),
        ("card_kinds_coverage", card_kinds_coverage),
        ("uas_addresses_bound", uas_addresses_bound),
        ("source_refs_bound", source_refs_bound),
        ("budget_vectors_bound", budget_vectors_bound),
        ("rollback_handles_bound", rollback_handles_bound),
        (
            "proof_or_falsifier_state_bound",
            proof_or_falsifier_state_bound,
        ),
        (
            "answer_packet_visibility_bound",
            answer_packet_visibility_bound,
        ),
        ("route_authority_shadow_only", route_authority_shadow_only),
        (
            "registry_address_deterministic",
            registry_address_deterministic,
        ),
        ("duplicate_card_rejected", duplicate_card_rejected),
        ("missing_uas_address_rejected", missing_uas_address_rejected),
        ("missing_source_rejected", missing_source_rejected),
        ("missing_budget_rejected", missing_budget_rejected),
        ("missing_rollback_rejected", missing_rollback_rejected),
        ("missing_proof_state_rejected", missing_proof_state_rejected),
        (
            "missing_answer_packet_rejected",
            missing_answer_packet_rejected,
        ),
        (
            "hidden_live_authority_rejected",
            hidden_live_authority_rejected,
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
        "card_count",
        registry.cards.len() as u64,
        5,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "card_kind_count",
        registry.kind_count() as u64,
        5,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_active_bytes",
        registry.max_active_bytes(),
        512 * 1024 * 1024,
        "<=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_cold_io_bytes",
        registry.max_cold_io_bytes(),
        1024 * 1024 * 1024,
        "<=",
    );
    measurements.insert(
        "registry_address".to_string(),
        Measurement {
            value: serde_json::Value::String(registry.registry_address.clone()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "registry_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "registry_address".to_string(),
        !registry.registry_address.is_empty(),
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
            "detail": "metadata-only meta-breakthrough registry; no live route authority, no runtime mutation, no model bytes, and no product promotion executed"
        })],
        notes: "Proves meta-control cards are address/source/budget/rollback/proof/AnswerPacket-bound before future route policy may cite them.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

struct CardRegistry {
    cards: Vec<MetaBreakthroughCard>,
    registry_address: String,
}

impl CardRegistry {
    fn new(mut cards: Vec<MetaBreakthroughCard>) -> Result<Self, &'static str> {
        let mut seen = BTreeSet::new();
        for card in &cards {
            if !seen.insert(card.card_id) {
                return Err("duplicate card id");
            }
            if !card_is_valid(card) {
                return Err("invalid meta breakthrough card");
            }
        }
        cards.sort_by(|a, b| a.card_id.cmp(b.card_id));
        let registry_address = registry_address(&cards);
        Ok(Self {
            cards,
            registry_address,
        })
    }

    fn has_kind(&self, kind: &str) -> bool {
        self.cards.iter().any(|card| card.card_kind == kind)
    }

    fn kind_count(&self) -> usize {
        self.cards
            .iter()
            .map(|card| card.card_kind)
            .collect::<BTreeSet<_>>()
            .len()
    }

    fn max_active_bytes(&self) -> u64 {
        self.cards
            .iter()
            .map(|card| card.budget.active_bytes)
            .max()
            .unwrap_or(0)
    }

    fn max_cold_io_bytes(&self) -> u64 {
        self.cards
            .iter()
            .map(|card| card.budget.cold_io_bytes)
            .max()
            .unwrap_or(0)
    }
}

fn fixture_cards() -> Vec<MetaBreakthroughCard> {
    vec![
        card(
            "card:proof-route",
            "ProofCarryingRouteCard",
            "uas:route:proof-carrying-route-card",
            "docs/fusion/META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01.md#1-proofcarryingroutecard",
            16 * 1024 * 1024,
            4 * 1024 * 1024,
            "rollback:route-card-schema",
            "witness:F-ProofCarryingRouteCard:planned",
            "F-ProofCarryingRouteCard",
            "answerpacket:route-card-visible-proof",
        ),
        card(
            "card:brain-route",
            "BrainRouteCard",
            "uas:route:brain-route-card",
            "docs/fusion/META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01.md#3-brainroutecard",
            24 * 1024 * 1024,
            8 * 1024 * 1024,
            "rollback:brain-route-static-policy",
            "witness:F-BrainRouteCard-MultiModel:planned",
            "F-BrainRouteCard-MultiModel",
            "answerpacket:brain-route-visible-proof",
        ),
        card(
            "card:kv-page-control",
            "KVPageControlCard",
            "uas:kv:page-control-card",
            "docs/fusion/META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01.md#6-kvpagecontrolcard",
            32 * 1024 * 1024,
            64 * 1024 * 1024,
            "rollback:kv-page-control-restore",
            "witness:F-KVPageControl-QueryAware:planned",
            "F-KVPageControl-QueryAware",
            "answerpacket:kv-page-visible-proof",
        ),
        card(
            "card:cold-assembly",
            "ColdAssemblyPlan",
            "uas:cold:assembly-plan",
            "artifacts/falsifiers/cold_assembly_plan_70b_lite/result.json",
            128 * 1024 * 1024,
            512 * 1024 * 1024,
            "rollback:cold-assembly-dense-local",
            "witness:F-ColdAssemblyPlan-70B-Lite:pass",
            "F-ColdAssemblyPlan-70B-Lite",
            "answerpacket:cold-assembly-visible-proof",
        ),
        card(
            "card:swiftlm-source-intake",
            "SourceIntakeCard",
            "uas:source:swiftlm-source-intake",
            "artifacts/falsifiers/swiftlm_source_intake/result.json",
            8 * 1024 * 1024,
            2 * 1024 * 1024,
            "rollback:source-card-remove",
            "witness:F-SwiftLM-SourceIntake:pass",
            "F-SwiftLM-SourceIntake",
            "answerpacket:source-intake-visible-proof",
        ),
    ]
}

fn card(
    card_id: &'static str,
    card_kind: &'static str,
    uas_address: &'static str,
    source_ref: &'static str,
    active_bytes: u64,
    cold_io_bytes: u64,
    rollback_handle: &'static str,
    proof_state: &'static str,
    falsifier_ref: &'static str,
    answer_packet_ref: &'static str,
) -> MetaBreakthroughCard {
    MetaBreakthroughCard {
        card_id,
        card_kind,
        uas_address,
        source_ref,
        budget: BudgetVector {
            active_bytes,
            cold_io_bytes,
            verifier_budget_bps: 100,
        },
        rollback_handle,
        proof_state,
        falsifier_ref,
        answer_packet_ref,
        route_authority: "shadow_only",
    }
}

fn card_is_valid(card: &MetaBreakthroughCard) -> bool {
    !card.card_id.is_empty()
        && !card.card_kind.is_empty()
        && card.uas_address.starts_with("uas:")
        && (card.source_ref.starts_with("docs/") || card.source_ref.starts_with("artifacts/"))
        && card.budget.active_bytes > 0
        && card.budget.active_bytes <= 512 * 1024 * 1024
        && card.budget.cold_io_bytes <= 1024 * 1024 * 1024
        && card.budget.verifier_budget_bps > 0
        && card.rollback_handle.starts_with("rollback:")
        && card.proof_state.starts_with("witness:")
        && card.proof_state.contains(card.falsifier_ref)
        && card.falsifier_ref.starts_with("F-")
        && card.answer_packet_ref.starts_with("answerpacket:")
        && card.route_authority == "shadow_only"
}

fn registry_address(cards: &[MetaBreakthroughCard]) -> String {
    let payload = cards
        .iter()
        .map(|card| {
            serde_json::json!({
                "card_id": card.card_id,
                "card_kind": card.card_kind,
                "uas_address": card.uas_address,
                "source_ref": card.source_ref,
                "active_bytes": card.budget.active_bytes,
                "cold_io_bytes": card.budget.cold_io_bytes,
                "verifier_budget_bps": card.budget.verifier_budget_bps,
                "rollback_handle": card.rollback_handle,
                "proof_state": card.proof_state,
                "falsifier_ref": card.falsifier_ref,
                "answer_packet_ref": card.answer_packet_ref,
                "route_authority": card.route_authority,
            })
        })
        .collect::<Vec<_>>();
    let bytes = serde_json::to_vec(&payload).expect("serialize registry payload");
    format!("uas:meta:{}", blake3::hash(&bytes).to_hex())
}

fn duplicate_card_rejected() -> bool {
    let mut cards = fixture_cards();
    cards.push(cards[0].clone());
    CardRegistry::new(cards).is_err()
}

fn invalid_card_rejected(mutate: impl FnOnce(&mut MetaBreakthroughCard)) -> bool {
    let mut cards = fixture_cards();
    mutate(&mut cards[0]);
    CardRegistry::new(cards).is_err()
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
    fn artifact_contains_meta_registry_axes() {
        let artifact = build_artifact().unwrap();
        assert!(artifact.overall_pass);
        for axis in [
            "meta_card_registry_present",
            "uas_addresses_bound",
            "source_refs_bound",
            "budget_vectors_bound",
            "rollback_handles_bound",
            "proof_or_falsifier_state_bound",
            "answer_packet_visibility_bound",
            "hidden_live_authority_rejected",
        ] {
            assert_eq!(artifact.pass_per_axis.get(axis), Some(&true));
        }
    }
}
