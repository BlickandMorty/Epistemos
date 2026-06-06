//! `falsify_qat_model_route_card_memory_preflight`
//!
//! Metadata-only witness for `F-QAT-ModelRouteCard-MemoryPreflight`. It turns
//! Gemma QAT runtime candidate cards into route-card memory preflights with
//! explicit byte accounting, abstention, rollback, RunEventLog, and AnswerPacket
//! requirements before any compressed-model dry-run is allowed.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, QatModelRouteCardMemoryPreflight, QatModelRouteCardMemoryPreflightSet,
    QatRouteAdmission, QatRouteMemoryBudget, QatRoutePromotionTier, QatRouteProofRefs,
    QatRouteRuntimeLane, UasAddress,
};

const FALSIFIER_ID: &str = "F-QAT-ModelRouteCard-MemoryPreflight";
const FIXTURE_ID: &str = "qat_model_route_card_memory_preflight_v1";
const COMMAND: &str = "Tools/falsifiers/f_qat_model_route_card_memory_preflight.sh";
const RESULT: &str = "artifacts/falsifiers/qat_model_route_card_memory_preflight/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_qat_local_runtime_candidate_card/result.json";
const CREATED_AT_MS: u64 = 1_779_034_700_000;
const SET_METADATA_BYTES: u64 = 72_000;
const GIB: u64 = 1_073_741_824;
const MIB: u64 = 1_048_576;
const UMA_BUDGET_BYTES: u64 = 16 * GIB;
const RESERVED_SYSTEM_BYTES: u64 = 4 * GIB;

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
        "{FALSIFIER_ID}: overall_pass={} route_card_count={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["accepted_route_card_count"].value,
        artifact.measurements["red_fixture_rejection_count"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let upstream = upstream_candidate_set_address()?;
    let route_cards = accepted_route_cards();
    let preflight_set = build_set(upstream.clone(), route_cards.clone())?;
    let reversed = build_set(upstream, route_cards.iter().cloned().rev().collect())?;
    let metrics = preflight_set.metrics();
    let red_results = red_fixture_results(&preflight_set);
    let accepted_route_card_count = route_cards.len() as u64;
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_gemma_qat_candidate_card_bound",
            preflight_set
                .upstream_candidate_witness_ref
                .contains("gemma_qat_local_runtime_candidate_card"),
        ),
        (
            "accepted_route_pack_present",
            has_route(&route_cards, "gemma4_e2b_qat_gguf_route_preflight")
                && has_route(&route_cards, "gemma4_e4b_qat_gguf_route_preflight")
                && has_route(&route_cards, "gemma4_12b_qat_gguf_route_preflight")
                && has_route(&route_cards, "gemma4_31b_qat_gguf_vault_route_preflight"),
        ),
        (
            "small_qat_dry_run_admissions_present",
            metrics.dry_run_admission_count >= 2
                && has_admitted(&route_cards, "gemma4_e2b_qat_gguf_route_preflight")
                && has_admitted(&route_cards, "gemma4_e4b_qat_gguf_route_preflight"),
        ),
        (
            "twelve_b_abstains_on_16gb_profile",
            route_cards.iter().any(|card| {
                card.route_card_id == "gemma4_12b_qat_gguf_route_preflight"
                    && card.admission == QatRouteAdmission::AbstainInsufficientHeadroom
                    && card.memory.headroom_bytes < 0
            }) && red_pass(&red_results, "twelve_b_false_dry_run_admit"),
        ),
        (
            "thirty_one_b_vault_only_on_16gb_profile",
            route_cards.iter().any(|card| {
                card.route_card_id == "gemma4_31b_qat_gguf_vault_route_preflight"
                    && card.admission == QatRouteAdmission::VaultOnly
                    && card.pro_status == ProStatus::VaultPreserved
            }) && red_pass(&red_results, "thirty_one_b_non_vault_admit"),
        ),
        (
            "admission_matches_headroom",
            route_cards.iter().all(|card| match card.admission {
                QatRouteAdmission::AdmitForDryRun => card.memory.headroom_bytes >= 0,
                QatRouteAdmission::AbstainInsufficientHeadroom => card.memory.headroom_bytes < 0,
                QatRouteAdmission::VaultOnly => card.memory.headroom_bytes < 0,
                QatRouteAdmission::BlockedMissingLoader
                | QatRouteAdmission::BlockedUnsupportedLane => true,
            }) && red_pass(&red_results, "false_admission_negative_headroom")
                && red_pass(&red_results, "false_abstention_positive_headroom"),
        ),
        (
            "byte_accounting_consistent",
            route_cards.iter().all(|card| {
                card.memory.total_predicted_route_bytes
                    == card.memory.predicted_resident_bytes
                        + card.memory.predicted_kv_cache_bytes
                        + card.memory.predicted_scratch_bytes
                    && card.memory.available_for_route_bytes
                        == card.memory.uma_budget_bytes - card.memory.reserved_system_bytes
                    && card.memory.headroom_bytes
                        == card.memory.available_for_route_bytes as i64
                            - card.memory.total_predicted_route_bytes as i64
            }) && red_pass(&red_results, "bad_total_predicted_route_bytes")
                && red_pass(&red_results, "bad_available_route_bytes")
                && red_pass(&red_results, "bad_headroom_bytes"),
        ),
        (
            "resident_bytes_not_file_size",
            route_cards
                .iter()
                .all(|card| card.memory.predicted_resident_bytes > card.memory.declared_file_bytes)
                && red_pass(&red_results, "file_size_as_resident_memory")
                && red_pass(&red_results, "resident_equals_declared_file"),
        ),
        (
            "rollback_log_answer_packet_required",
            route_cards.iter().all(|card| {
                card.rollback_required && card.run_event_log_required && card.answer_packet_required
            }) && red_pass(&red_results, "missing_rollback")
                && red_pass(&red_results, "missing_run_event_log")
                && red_pass(&red_results, "missing_answer_packet")
                && red_pass(&red_results, "bad_answer_packet_prefix"),
        ),
        (
            "cancellation_and_timeout_required",
            route_cards.iter().all(|card| {
                card.memory.timeout_ms > 0
                    && card.memory.cancellation_deadline_ms > 0
                    && card.memory.cancellation_deadline_ms <= card.memory.timeout_ms
            }) && red_pass(&red_results, "zero_timeout")
                && red_pass(&red_results, "zero_cancellation")
                && red_pass(&red_results, "cancellation_exceeds_timeout"),
        ),
        (
            "runtime_deferred_required",
            red_pass(&red_results, "runtime_not_deferred")
                && red_pass(&red_results, "swift_mlx_loader_claim"),
        ),
        (
            "product_promotion_rejected",
            red_pass(&red_results, "mas_product_build")
                && red_pass(&red_results, "pro_live_status")
                && red_pass(&red_results, "promotion_tier_t2")
                && red_pass(&red_results, "first_token_claim")
                && red_pass(&red_results, "quality_claim")
                && red_pass(&red_results, "mas_readiness_claim"),
        ),
        (
            "hidden_authority_rejected",
            red_pass(&red_results, "hidden_cloud_fallback")
                && red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "zero_model_bytes_loaded",
            metrics.model_bytes_loaded == 0 && red_pass(&red_results, "model_bytes_loaded"),
        ),
        (
            "zero_runtime_bytes_loaded",
            metrics.runtime_bytes_loaded == 0 && red_pass(&red_results, "runtime_bytes_loaded"),
        ),
        (
            "zero_provider_calls",
            metrics.provider_calls_made == 0 && red_pass(&red_results, "provider_call_made"),
        ),
        (
            "set_address_deterministic",
            preflight_set.set_address == reversed.set_address,
        ),
        (
            "layer_separation_required",
            red_pass(&red_results, "set_missing_layer_separation"),
        ),
        (
            "metadata_budget_enforced",
            red_pass(&red_results, "metadata_budget_exceeded")
                && red_pass(&red_results, "route_metadata_budget_exceeded"),
        ),
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
        "accepted_route_card_count",
        accepted_route_card_count,
        ">=",
        4,
        "cards",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "dry_run_admission_count",
        metrics.dry_run_admission_count,
        ">=",
        2,
        "cards",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "abstention_count",
        metrics.abstention_count,
        ">=",
        1,
        "cards",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "vault_only_count",
        metrics.vault_only_count,
        ">=",
        1,
        "cards",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_count",
        red_results.len() as u64,
        ">=",
        30,
        "fixtures",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_rejection_count",
        red_fixture_rejection_count,
        "==",
        red_results.len() as u64,
        "fixtures",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "declared_file_bytes_total",
        metrics.declared_file_bytes_total,
        ">",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "predicted_resident_bytes_total",
        metrics.predicted_resident_bytes_total,
        ">",
        metrics.declared_file_bytes_total,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "admitted_total_predicted_route_bytes",
        metrics.admitted_total_predicted_route_bytes,
        "<=",
        (UMA_BUDGET_BYTES - RESERVED_SYSTEM_BYTES) * metrics.dry_run_admission_count.max(1),
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_bytes_loaded",
        metrics.model_bytes_loaded,
        "==",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_bytes_loaded",
        metrics.runtime_bytes_loaded,
        "==",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "provider_calls_made",
        metrics.provider_calls_made,
        "==",
        0,
        "calls",
    );

    measurements.insert(
        "minimum_headroom_bytes".to_string(),
        Measurement {
            value: serde_json::json!(metrics.minimum_headroom_bytes),
            unit: "bytes".to_string(),
        },
    );
    thresholds.insert(
        "minimum_headroom_bytes".to_string(),
        AcceptanceThreshold {
            operator: "<".to_string(),
            value: serde_json::json!(0),
            unit: "bytes".to_string(),
        },
    );
    pass_per_axis.insert(
        "minimum_headroom_bytes".to_string(),
        metrics.minimum_headroom_bytes < 0,
    );
    measurements.insert(
        "route_preflight_set_address".to_string(),
        Measurement {
            value: serde_json::json!(preflight_set.set_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "route_preflight_set_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("qat_model_route_card_memory_preflight:"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "route_preflight_set_address".to_string(),
        preflight_set
            .set_address
            .to_string()
            .starts_with("qat_model_route_card_memory_preflight:"),
    );
    measurements.insert(
        "next_research_to_build_unit".to_string(),
        Measurement {
            value: serde_json::json!("compressed_route_answer_packet_dry_run"),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_research_to_build_unit".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!("compressed_route_answer_packet_dry_run"),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert("next_research_to_build_unit".to_string(), true);

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
        anomalies: Vec::new(),
        notes: "Builds F-QAT-ModelRouteCard-MemoryPreflight from the Gemma QAT candidate-card witness. Scope is T1/L1 metadata only: E2B/E4B may proceed to later dry-run packetization on the declared 16 GB UMA profile; 12B abstains for insufficient headroom; 31B remains vault-only. This witness loads zero model/runtime bytes, makes zero provider calls, and proves no first token, quality, Swift MLX loader, MAS readiness, or product capability.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_candidate_set_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream Gemma QAT candidate-card witness has not passed".into());
    }
    let address = value
        .pointer("/measurements/candidate_set_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("missing upstream candidate_set_address measurement")?;
    Ok(UasAddress::from_str(address)?)
}

fn build_set(
    upstream_candidate_set_address: UasAddress,
    route_cards: Vec<QatModelRouteCardMemoryPreflight>,
) -> Result<QatModelRouteCardMemoryPreflightSet, Box<dyn std::error::Error>> {
    Ok(QatModelRouteCardMemoryPreflightSet::from_candidate_set(
        upstream_candidate_set_address,
        "artifact:gemma_qat_local_runtime_candidate_card:result",
        route_cards,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        SET_METADATA_BYTES,
        true,
        true,
        true,
        CREATED_AT_MS,
    )?)
}

fn accepted_route_cards() -> Vec<QatModelRouteCardMemoryPreflight> {
    vec![
        route_card(RouteSpec {
            route_card_id: "gemma4_e2b_qat_gguf_route_preflight",
            upstream_card_id: "gemma4_e2b_qat_gguf_candidate",
            model_id: "google/gemma-4-E2B-it-qat-q4_0-gguf",
            admission: QatRouteAdmission::AdmitForDryRun,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: QatRoutePromotionTier::T1L1Metadata,
            declared_file_bytes: 4_628_569_635,
            resident_bytes: 5 * GIB,
            kv_bytes: 512 * MIB,
            scratch_bytes: 256 * MIB,
            abstention_reason: None,
        }),
        route_card(RouteSpec {
            route_card_id: "gemma4_e4b_qat_gguf_route_preflight",
            upstream_card_id: "gemma4_e4b_qat_gguf_candidate",
            model_id: "google/gemma-4-E4B-it-qat-q4_0-gguf",
            admission: QatRouteAdmission::AdmitForDryRun,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: QatRoutePromotionTier::T1L1Metadata,
            declared_file_bytes: 7_463_013_674,
            resident_bytes: 8 * GIB,
            kv_bytes: 768 * MIB,
            scratch_bytes: 384 * MIB,
            abstention_reason: None,
        }),
        route_card(RouteSpec {
            route_card_id: "gemma4_12b_qat_gguf_route_preflight",
            upstream_card_id: "gemma4_12b_qat_gguf_candidate",
            model_id: "google/gemma-4-12B-it-qat-q4_0-gguf",
            admission: QatRouteAdmission::AbstainInsufficientHeadroom,
            pro_status: ProStatus::Gated,
            promotion_tier: QatRoutePromotionTier::T1L1Metadata,
            declared_file_bytes: 11_907_350_576,
            resident_bytes: 13 * GIB,
            kv_bytes: GIB,
            scratch_bytes: 512 * MIB,
            abstention_reason: Some("abstain:insufficient_16gb_uma_headroom_no_runtime_probe"),
        }),
        route_card(RouteSpec {
            route_card_id: "gemma4_31b_qat_gguf_vault_route_preflight",
            upstream_card_id: "gemma4_31b_qat_gguf_vault_candidate",
            model_id: "google/gemma-4-31B-it-qat-q4_0-gguf",
            admission: QatRouteAdmission::VaultOnly,
            pro_status: ProStatus::VaultPreserved,
            promotion_tier: QatRoutePromotionTier::T0Research,
            declared_file_bytes: 30_697_345_596,
            resident_bytes: 32 * GIB,
            kv_bytes: 2 * GIB,
            scratch_bytes: GIB,
            abstention_reason: Some("abstain:vault_only_large_candidate_no_runtime_probe"),
        }),
    ]
}

// UAS: uas:qat-route-preflight:fixture-spec
// Plane: Verification
// Residency: falsifier fixture metadata; not product/runtime configuration.
struct RouteSpec {
    route_card_id: &'static str,
    upstream_card_id: &'static str,
    model_id: &'static str,
    admission: QatRouteAdmission,
    pro_status: ProStatus,
    promotion_tier: QatRoutePromotionTier,
    declared_file_bytes: u64,
    resident_bytes: u64,
    kv_bytes: u64,
    scratch_bytes: u64,
    abstention_reason: Option<&'static str>,
}

fn route_card(spec: RouteSpec) -> QatModelRouteCardMemoryPreflight {
    QatModelRouteCardMemoryPreflight {
        route_card_id: spec.route_card_id.to_string(),
        upstream_candidate_card_ref: format!("gemma_qat_candidate:{}", spec.upstream_card_id),
        model_id: spec.model_id.to_string(),
        runtime_lane: QatRouteRuntimeLane::GgufLlamaCpp,
        admission: spec.admission,
        product_build: ProductBuild::Pro,
        pro_status: spec.pro_status,
        promotion_tier: spec.promotion_tier,
        hardware_profile_ref: "hardware:apple_silicon_m2_pro_16gb_uma_200gbps".to_string(),
        route_caveat_ref: "route_caveat:metadata_preflight_no_runtime_bytes_or_quality_claim"
            .to_string(),
        abstention_reason_ref: spec.abstention_reason.map(str::to_string),
        memory: QatRouteMemoryBudget::metadata_only(
            spec.declared_file_bytes,
            spec.resident_bytes,
            spec.kv_bytes,
            spec.scratch_bytes,
            UMA_BUDGET_BYTES,
            RESERVED_SYSTEM_BYTES,
            30_000,
            5_000,
            22_000,
        ),
        proof_refs: proof_refs(spec.route_card_id),
        rollback_required: true,
        run_event_log_required: true,
        answer_packet_required: true,
        l1_l2_l3_separated: true,
        runtime_deferred: true,
        product_promotion_blocked: true,
        file_size_treated_as_resident_memory: false,
        first_token_claimed: false,
        quality_claimed: false,
        swift_mlx_loader_proven: false,
        mtp_speedup_claimed: false,
        mas_readiness_claimed: false,
        live_dense_70b_claimed: false,
        ssd_as_ram_claimed: false,
        hidden_cloud_fallback_allowed: false,
        hidden_route_authority_allowed: false,
    }
}

fn proof_refs(id: &str) -> QatRouteProofRefs {
    QatRouteProofRefs {
        falsifier_ref: format!("falsifier:F-QAT-ModelRouteCard-MemoryPreflight:{id}"),
        rollback_ref: format!("rollback:qat_route_preflight:{id}"),
        run_event_log_ref: format!("run_event_log:qat_route_preflight:{id}"),
        answer_packet_ref: format!("answer_packet:qat_route_preflight:{id}"),
        compatibility_fence_ref: format!("compat:qat_route_preflight:{id}"),
    }
}

fn red_fixture_results(set: &QatModelRouteCardMemoryPreflightSet) -> Vec<(&'static str, bool)> {
    let mut results = Vec::new();
    let base_cards = set.route_cards.clone();
    let upstream = set.upstream_candidate_set_address.clone();

    let mut push_card =
        |name: &'static str, mutate: fn(&mut Vec<QatModelRouteCardMemoryPreflight>)| {
            let mut cards = base_cards.clone();
            mutate(&mut cards);
            results.push((name, build_set(upstream.clone(), cards).is_err()));
        };

    push_card("duplicate_route_card_id", |cards| {
        cards[1].route_card_id = cards[0].route_card_id.clone()
    });
    push_card("duplicate_model_runtime", |cards| {
        cards[1].model_id = cards[0].model_id.clone()
    });
    push_card("bad_upstream_candidate_ref", |cards| {
        cards[0].upstream_candidate_card_ref = "model_card:bad".to_string()
    });
    push_card("missing_hardware_profile", |cards| {
        cards[0].hardware_profile_ref.clear()
    });
    push_card("bad_route_caveat", |cards| {
        cards[0].route_caveat_ref = "caveat:bad".to_string()
    });
    push_card("zero_declared_file_bytes", |cards| {
        cards[0].memory.declared_file_bytes = 0
    });
    push_card("resident_equals_declared_file", |cards| {
        cards[0].memory.predicted_resident_bytes = cards[0].memory.declared_file_bytes
    });
    push_card("zero_kv_floor", |cards| {
        cards[0].memory.predicted_kv_cache_bytes = 0
    });
    push_card("bad_total_predicted_route_bytes", |cards| {
        cards[0].memory.total_predicted_route_bytes = cards[0]
            .memory
            .total_predicted_route_bytes
            .saturating_add(1)
    });
    push_card("bad_available_route_bytes", |cards| {
        cards[0].memory.available_for_route_bytes =
            cards[0].memory.available_for_route_bytes.saturating_add(1)
    });
    push_card("bad_headroom_bytes", |cards| {
        cards[0].memory.headroom_bytes += 1
    });
    push_card("zero_timeout", |cards| cards[0].memory.timeout_ms = 0);
    push_card("zero_cancellation", |cards| {
        cards[0].memory.cancellation_deadline_ms = 0
    });
    push_card("cancellation_exceeds_timeout", |cards| {
        cards[0].memory.cancellation_deadline_ms = cards[0].memory.timeout_ms + 1
    });
    push_card("model_bytes_loaded", |cards| {
        cards[0].memory.model_bytes_loaded = 1
    });
    push_card("runtime_bytes_loaded", |cards| {
        cards[0].memory.runtime_bytes_loaded = 1
    });
    push_card("provider_call_made", |cards| {
        cards[0].memory.provider_calls_made = 1
    });
    push_card("false_admission_negative_headroom", |cards| {
        if let Some(card) = cards
            .iter_mut()
            .find(|card| card.model_id.contains("-12B-"))
        {
            card.admission = QatRouteAdmission::AdmitForDryRun;
            card.abstention_reason_ref = None;
            card.pro_status = ProStatus::ResearchCandidate;
        }
    });
    push_card("false_abstention_positive_headroom", |cards| {
        if let Some(card) = cards
            .iter_mut()
            .find(|card| card.model_id.contains("-E2B-"))
        {
            card.admission = QatRouteAdmission::AbstainInsufficientHeadroom;
            card.abstention_reason_ref =
                Some("abstain:pretend_no_headroom_despite_positive_budget".to_string());
        }
    });
    push_card("twelve_b_false_dry_run_admit", |cards| {
        if let Some(card) = cards
            .iter_mut()
            .find(|card| card.model_id.contains("-12B-"))
        {
            card.admission = QatRouteAdmission::AdmitForDryRun;
            card.abstention_reason_ref = None;
            card.memory.uma_budget_bytes = 64 * GIB;
            card.memory.reserved_system_bytes = 4 * GIB;
            card.memory.available_for_route_bytes = 60 * GIB;
            card.memory.headroom_bytes = card.memory.available_for_route_bytes as i64
                - card.memory.total_predicted_route_bytes as i64;
        }
    });
    push_card("thirty_one_b_non_vault_admit", |cards| {
        if let Some(card) = cards
            .iter_mut()
            .find(|card| card.model_id.contains("-31B-"))
        {
            card.admission = QatRouteAdmission::AdmitForDryRun;
            card.abstention_reason_ref = None;
            card.pro_status = ProStatus::ResearchCandidate;
            card.memory.uma_budget_bytes = 128 * GIB;
            card.memory.reserved_system_bytes = 8 * GIB;
            card.memory.available_for_route_bytes = 120 * GIB;
            card.memory.headroom_bytes = card.memory.available_for_route_bytes as i64
                - card.memory.total_predicted_route_bytes as i64;
        }
    });
    push_card("missing_abstention_reason", |cards| {
        if let Some(card) = cards
            .iter_mut()
            .find(|card| card.admission == QatRouteAdmission::AbstainInsufficientHeadroom)
        {
            card.abstention_reason_ref = None;
        }
    });
    push_card("missing_rollback", |cards| {
        cards[0].rollback_required = false
    });
    push_card("missing_run_event_log", |cards| {
        cards[0].run_event_log_required = false
    });
    push_card("missing_answer_packet", |cards| {
        cards[0].answer_packet_required = false
    });
    push_card("bad_answer_packet_prefix", |cards| {
        cards[0].proof_refs.answer_packet_ref = "packet:bad".to_string()
    });
    push_card("runtime_not_deferred", |cards| {
        cards[0].runtime_deferred = false
    });
    push_card("swift_mlx_loader_claim", |cards| {
        cards[0].runtime_lane = QatRouteRuntimeLane::MlxSwiftCandidate;
        cards[0].swift_mlx_loader_proven = true;
    });
    push_card("file_size_as_resident_memory", |cards| {
        cards[0].file_size_treated_as_resident_memory = true
    });
    push_card("first_token_claim", |cards| {
        cards[0].first_token_claimed = true
    });
    push_card("quality_claim", |cards| cards[0].quality_claimed = true);
    push_card("mas_readiness_claim", |cards| {
        cards[0].mas_readiness_claimed = true
    });
    push_card("mas_product_build", |cards| {
        cards[0].product_build = ProductBuild::Mas
    });
    push_card("pro_live_status", |cards| {
        cards[0].pro_status = ProStatus::Live
    });
    push_card("promotion_tier_t2", |cards| {
        cards[0].promotion_tier = QatRoutePromotionTier::T2L2Route
    });
    push_card("hidden_cloud_fallback", |cards| {
        cards[0].hidden_cloud_fallback_allowed = true
    });
    push_card("hidden_route_authority", |cards| {
        cards[0].hidden_route_authority_allowed = true
    });
    push_card("live_dense_70b_claim", |cards| {
        cards[0].live_dense_70b_claimed = true
    });
    push_card("ssd_as_ram_claim", |cards| {
        cards[0].ssd_as_ram_claimed = true
    });
    push_card("route_metadata_budget_exceeded", |cards| {
        cards[0].memory.metadata_bytes_read = 120_000
    });

    let set_level = [
        (
            "set_missing_layer_separation",
            build_set_with_flags(
                upstream.clone(),
                base_cards.clone(),
                false,
                true,
                true,
                SET_METADATA_BYTES,
            )
            .is_err(),
        ),
        (
            "set_runtime_not_deferred",
            build_set_with_flags(
                upstream.clone(),
                base_cards.clone(),
                true,
                false,
                true,
                SET_METADATA_BYTES,
            )
            .is_err(),
        ),
        (
            "set_product_promotion_allowed",
            build_set_with_flags(
                upstream.clone(),
                base_cards.clone(),
                true,
                true,
                false,
                SET_METADATA_BYTES,
            )
            .is_err(),
        ),
        (
            "metadata_budget_exceeded",
            build_set_with_flags(upstream, base_cards, true, true, true, 600 * 1024).is_err(),
        ),
    ];
    results.extend(set_level);
    results
}

fn build_set_with_flags(
    upstream_candidate_set_address: UasAddress,
    route_cards: Vec<QatModelRouteCardMemoryPreflight>,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
    metadata_bytes: u64,
) -> Result<QatModelRouteCardMemoryPreflightSet, Box<dyn std::error::Error>> {
    Ok(QatModelRouteCardMemoryPreflightSet::from_candidate_set(
        upstream_candidate_set_address,
        "artifact:gemma_qat_local_runtime_candidate_card:result",
        route_cards,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        metadata_bytes,
        l1_l2_l3_separated,
        runtime_deferred,
        product_promotion_blocked,
        CREATED_AT_MS,
    )?)
}

fn has_route(cards: &[QatModelRouteCardMemoryPreflight], id: &str) -> bool {
    cards.iter().any(|card| card.route_card_id == id)
}

fn has_admitted(cards: &[QatModelRouteCardMemoryPreflight], id: &str) -> bool {
    cards.iter().any(|card| {
        card.route_card_id == id
            && card.admission == QatRouteAdmission::AdmitForDryRun
            && card.memory.headroom_bytes >= 0
    })
}

fn red_pass(results: &[(&'static str, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(candidate, _)| *candidate == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}
