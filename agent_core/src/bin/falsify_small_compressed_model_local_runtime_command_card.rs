//! `falsify_small_compressed_model_local_runtime_command_card`
//!
//! Metadata-only witness for
//! `F-SmallCompressedModel-LocalRuntimeCommandCard`. It binds the selected E2B
//! QAT GGUF candidate to visible local GGUF command inventory without arming a
//! command, opening a model path, starting llama.cpp, or promoting L2/L3.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, SmallCompressedHarnessPromotionTier,
    SmallCompressedLocalRuntimeCommandByteLedger, SmallCompressedLocalRuntimeCommandRefs,
    SmallCompressedLocalRuntimeCommandRole, SmallCompressedModelLocalRuntimeCommandCard,
    SmallCompressedModelLocalRuntimeCommandCardSet, UasAddress,
    SMALL_COMPRESSED_MODEL_LOCAL_RUNTIME_COMMAND_CARD_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-SmallCompressedModel-LocalRuntimeCommandCard";
const FIXTURE_ID: &str = "small_compressed_model_local_runtime_command_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_small_compressed_model_local_runtime_command_card.sh";
const RESULT: &str =
    "artifacts/falsifiers/small_compressed_model_local_runtime_command_card/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/small_compressed_model_owner_approval_runtime_gate/result.json";
const CREATED_AT_MS: u64 = 1_779_036_100_000;
const SET_METADATA_BYTES: u64 = 36_000;
const SELECTED_CARD_ID: &str = "gemma4_e2b_qat_gguf_llama_cli_command_card";
const SERVER_CARD_ID: &str = "gemma4_e2b_qat_gguf_llama_server_denied_sidecar_card";
const SELECTED_CANDIDATE_ID: &str = "gemma4_e2b_qat_gguf_harness_preflight";
const MODEL_ID: &str = "google/gemma-4-E2B-it-qat-q4_0-gguf";
const LLAMA_CLI_PATH: &str = "/opt/homebrew/bin/llama-cli";
const LLAMA_SERVER_PATH: &str = "/opt/homebrew/bin/llama-server";
const LOCAL_VERSION_REF: &str =
    "local_version:llama.cpp:9370:aa50b2c2a:darwin_arm64:no_model_load:2026_06_06";

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
        "{FALSIFIER_ID}: overall_pass={} command_card_count={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["command_card_count"].value,
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
    let (upstream_address, upstream_selected_gate) = upstream_owner_gate_address()?;
    let cards = accepted_cards()?;
    let card_set = build_set(upstream_address.clone(), SELECTED_CARD_ID, cards.clone())?;
    let reversed = build_set(
        upstream_address,
        SELECTED_CARD_ID,
        cards.iter().cloned().rev().collect(),
    )?;
    let metrics = card_set.metrics();
    let red_results = red_fixture_results(&card_set)?;
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;
    let selected_card = selected(&cards).ok_or("selected command card missing")?;
    let server_card = cards
        .iter()
        .find(|card| card.card_id == SERVER_CARD_ID)
        .ok_or("server command card missing")?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_owner_gate_bound",
            upstream_selected_gate == "gemma4_e2b_qat_gguf_owner_approval_runtime_gate"
                && card_set
                    .upstream_owner_gate_witness_ref
                    .contains("small_compressed_model_owner_approval_runtime_gate"),
        ),
        (
            "selected_direct_cli_visible",
            selected_card.command_role == SmallCompressedLocalRuntimeCommandRole::DirectLlamaCli
                && selected_card.command_path == LLAMA_CLI_PATH
                && selected_card.command_path_present
                && red_pass(&red_results, "selected_server_sidecar")
                && red_pass(&red_results, "missing_cli_path")
                && red_pass(&red_results, "bad_cli_path"),
        ),
        (
            "server_sidecar_denied_by_default",
            server_card.command_role
                == SmallCompressedLocalRuntimeCommandRole::DeniedLlamaServerSidecar
                && server_card.command_path == LLAMA_SERVER_PATH
                && server_card.command_path_present
                && !server_card.server_sidecar_default_allowed
                && red_pass(&red_results, "server_sidecar_default_allowed")
                && red_pass(&red_results, "server_denial_ref_missing"),
        ),
        (
            "owner_approval_pending_fail_closed",
            cards.iter().all(|card| {
                card.owner_approval_required
                    && !card.owner_approval_granted
                    && !card.command_armed
                    && !card.command_executed
                    && !card.inference_executed
            }) && red_pass(&red_results, "owner_approval_granted")
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "inference_executed"),
        ),
        (
            "model_path_and_token_claims_blocked",
            cards.iter().all(|card| {
                !card.model_file_opened
                    && !card.first_token_claimed
                    && !card.retained_token_digest_recorded
            }) && red_pass(&red_results, "model_file_opened")
                && red_pass(&red_results, "first_token_claimed")
                && red_pass(&red_results, "retained_token_digest_recorded"),
        ),
        (
            "byte_ledger_zero_loaded",
            metrics.opened_model_bytes == 0
                && metrics.opened_runtime_bytes == 0
                && metrics.resident_model_bytes == 0
                && metrics.resident_runtime_bytes == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "opened_model_bytes")
                && red_pass(&red_results, "opened_runtime_bytes")
                && red_pass(&red_results, "resident_model_bytes")
                && red_pass(&red_results, "resident_runtime_bytes")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_call_made"),
        ),
        (
            "proof_surfaces_required",
            cards.iter().all(|card| {
                card.answer_packet_required
                    && card.run_event_log_required
                    && card.rollback_required
                    && card.cancellation_required
                    && card.memory_ledger_required
            }) && red_pass(&red_results, "missing_answer_packet")
                && red_pass(&red_results, "missing_run_event_log")
                && red_pass(&red_results, "missing_rollback")
                && red_pass(&red_results, "missing_cancellation")
                && red_pass(&red_results, "missing_memory_ledger"),
        ),
        (
            "visibility_required",
            cards.iter().all(|card| {
                card.command_visible
                    && card.model_path_status_visible
                    && card.command_ledger_visible
                    && card.denied_sidecar_visible
            }) && red_pass(&red_results, "missing_command_visibility")
                && red_pass(&red_results, "missing_model_path_visibility")
                && red_pass(&red_results, "missing_command_ledger_visibility")
                && red_pass(&red_results, "missing_denied_sidecar_visibility"),
        ),
        (
            "product_promotion_rejected",
            red_pass(&red_results, "mas_product_build")
                && red_pass(&red_results, "pro_live_status")
                && red_pass(&red_results, "promotion_tier_t2")
                && red_pass(&red_results, "quality_claim")
                && red_pass(&red_results, "l2_capability_claim")
                && red_pass(&red_results, "l3_wrv_claim")
                && red_pass(&red_results, "mas_readiness_claim"),
        ),
        (
            "hidden_authority_and_fallback_rejected",
            red_pass(&red_results, "hidden_cloud_fallback")
                && red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "provider_fallback")
                && red_pass(&red_results, "route_policy_mutated")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "proof_ref_prefixes_required",
            red_pass(&red_results, "bad_upstream_owner_gate_ref")
                && red_pass(&red_results, "bad_model_path_ref")
                && red_pass(&red_results, "bad_command_ledger_ref")
                && red_pass(&red_results, "bad_local_version_ref")
                && red_pass(&red_results, "bad_compatibility_fence_ref"),
        ),
        (
            "set_address_deterministic",
            card_set.set_address == reversed.set_address,
        ),
        (
            "layer_separation_required",
            card_set.l1_l2_l3_separated
                && card_set.runtime_deferred
                && card_set.product_promotion_blocked
                && red_pass(&red_results, "set_missing_layer_separation")
                && red_pass(&red_results, "set_runtime_not_deferred")
                && red_pass(&red_results, "set_product_promotion_allowed"),
        ),
        (
            "metadata_budget_enforced",
            red_pass(&red_results, "card_metadata_budget_exceeded")
                && red_pass(&red_results, "set_metadata_budget_exceeded"),
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
        "command_card_count",
        metrics.command_card_count,
        "==",
        2,
        "cards",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "direct_cli_card_count",
        metrics.direct_cli_card_count,
        "==",
        1,
        "cards",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "denied_server_sidecar_count",
        metrics.denied_server_sidecar_count,
        "==",
        1,
        "cards",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "present_command_path_count",
        metrics.present_command_path_count,
        "==",
        2,
        "paths",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_count",
        red_results.len() as u64,
        ">=",
        35,
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

    insert_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "command_card_set_address",
        card_set.set_address.to_string(),
        "starts_with",
        "small_compressed_model_local_runtime_command_card:",
        "uas_address",
    );
    insert_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "selected_command_path",
        selected_card.command_path.clone(),
        "==",
        LLAMA_CLI_PATH,
        "path",
    );
    insert_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "selected_resolved_path",
        selected_card.resolved_path.clone(),
        "contains",
        "llama-cli",
        "path",
    );
    insert_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "local_version_ref",
        selected_card.refs.local_version_ref.clone(),
        "starts_with",
        "local_version:llama.cpp:9370",
        "ref",
    );
    insert_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_research_to_build_unit",
        SMALL_COMPRESSED_MODEL_LOCAL_RUNTIME_COMMAND_CARD_NEXT_CURSOR.to_string(),
        "==",
        "small_compressed_model_owner_approved_runtime_probe",
        "cursor",
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
        anomalies: Vec::new(),
        notes: "Builds F-SmallCompressedModel-LocalRuntimeCommandCard from the owner-approval gate. Scope is research-to-build T1/L1 metadata only: local llama-cli and llama-server command paths are inventoried, llama-cli is the only direct future command lane, llama-server is denied by default, owner approval remains pending, model path remains pending, and no command, model, runtime, provider, L2, or L3 capability is executed or promoted.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_owner_gate_address() -> Result<(UasAddress, String), Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream owner-approval runtime gate has not passed".into());
    }
    let address = value
        .pointer("/measurements/gate_set_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("missing upstream gate_set_address measurement")?;
    let selected_gate = value
        .pointer("/measurements/selected_gate_id/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("missing upstream selected_gate_id measurement")?;
    Ok((UasAddress::from_str(address)?, selected_gate.to_string()))
}

fn build_set(
    upstream_owner_gate_set_address: UasAddress,
    selected_card_id: &str,
    cards: Vec<SmallCompressedModelLocalRuntimeCommandCard>,
) -> Result<SmallCompressedModelLocalRuntimeCommandCardSet, Box<dyn std::error::Error>> {
    Ok(
        SmallCompressedModelLocalRuntimeCommandCardSet::from_owner_gate(
            upstream_owner_gate_set_address,
            "artifact:small_compressed_model_owner_approval_runtime_gate:result",
            selected_card_id,
            cards,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            SET_METADATA_BYTES,
            true,
            true,
            true,
            CREATED_AT_MS,
        )?,
    )
}

fn accepted_cards(
) -> Result<Vec<SmallCompressedModelLocalRuntimeCommandCard>, Box<dyn std::error::Error>> {
    Ok(vec![
        command_card(
            SELECTED_CARD_ID,
            SmallCompressedLocalRuntimeCommandRole::DirectLlamaCli,
            LLAMA_CLI_PATH,
        )?,
        command_card(
            SERVER_CARD_ID,
            SmallCompressedLocalRuntimeCommandRole::DeniedLlamaServerSidecar,
            LLAMA_SERVER_PATH,
        )?,
    ])
}

fn command_card(
    card_id: &str,
    command_role: SmallCompressedLocalRuntimeCommandRole,
    command_path: &str,
) -> Result<SmallCompressedModelLocalRuntimeCommandCard, Box<dyn std::error::Error>> {
    let path = Path::new(command_path);
    let metadata = std::fs::symlink_metadata(path)?;
    let resolved_path = std::fs::read_link(path)
        .map(|target| target.display().to_string())
        .unwrap_or_else(|_| command_path.to_string());
    let path_metadata_bytes_read = metadata.len().saturating_add(command_path.len() as u64);
    let denied_sidecar = match command_role {
        SmallCompressedLocalRuntimeCommandRole::DirectLlamaCli => "llama-server-not-selected",
        SmallCompressedLocalRuntimeCommandRole::DeniedLlamaServerSidecar => "llama-server",
    };
    Ok(SmallCompressedModelLocalRuntimeCommandCard {
        card_id: card_id.to_string(),
        selected_candidate_id: SELECTED_CANDIDATE_ID.to_string(),
        model_id: MODEL_ID.to_string(),
        command_role,
        command_path: command_path.to_string(),
        resolved_path,
        command_path_present: true,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: SmallCompressedHarnessPromotionTier::T1L1Metadata,
        bytes: SmallCompressedLocalRuntimeCommandByteLedger::metadata_only(
            path_metadata_bytes_read.max(1),
        ),
        refs: SmallCompressedLocalRuntimeCommandRefs {
            upstream_owner_gate_ref:
                "artifact:small_compressed_model_owner_approval_runtime_gate:result".to_string(),
            model_path_ref: format!("model_path:pending_owner_approval:{card_id}"),
            command_ledger_ref: format!("command_ledger:small_compressed_local_runtime:{card_id}"),
            local_version_ref: LOCAL_VERSION_REF.to_string(),
            answer_packet_ref: format!("answer_packet:small_compressed_local_runtime:{card_id}"),
            run_event_log_ref: format!("run_event_log:small_compressed_local_runtime:{card_id}"),
            rollback_ref: format!("rollback:small_compressed_local_runtime:{card_id}"),
            cancellation_ref: format!("cancel:small_compressed_local_runtime:{card_id}"),
            memory_ledger_ref: format!("memory_ledger:small_compressed_local_runtime:{card_id}"),
            compatibility_fence_ref: format!("compat:small_compressed_local_runtime:{card_id}"),
            denied_sidecar_ref: format!("denied_sidecar:{denied_sidecar}:{card_id}"),
            route_caveat_ref: format!("route_caveat:small_compressed_local_runtime:{card_id}"),
        },
        user_visible_summary: "Local GGUF runtime command inventory is visible for the selected Gemma 4 E2B QAT GGUF candidate, but owner approval is pending, the model path remains pending, llama-server is denied by default, and no command, inference, model byte, provider route, L2, or L3 claim is armed.".to_string(),
        command_visible: true,
        model_path_status_visible: true,
        command_ledger_visible: true,
        denied_sidecar_visible: true,
        owner_approval_required: true,
        owner_approval_granted: false,
        command_armed: false,
        command_executed: false,
        inference_executed: false,
        model_file_opened: false,
        first_token_claimed: false,
        retained_token_digest_recorded: false,
        quality_claimed: false,
        l2_capability_claimed: false,
        l3_wrv_claimed: false,
        mas_readiness_claimed: false,
        answer_packet_required: true,
        run_event_log_required: true,
        rollback_required: true,
        cancellation_required: true,
        memory_ledger_required: true,
        route_policy_mutated: false,
        hidden_cloud_fallback_allowed: false,
        hidden_route_authority_allowed: false,
        provider_fallback_allowed: false,
        server_sidecar_default_allowed: false,
        live_dense_70b_claimed: false,
        ssd_as_ram_claimed: false,
    })
}

fn red_fixture_results(
    set: &SmallCompressedModelLocalRuntimeCommandCardSet,
) -> Result<Vec<(String, bool)>, Box<dyn std::error::Error>> {
    let mut results = Vec::new();
    let upstream = set.upstream_owner_gate_set_address.clone();

    let reject_card = |name: &str,
                       mutate: fn(&mut SmallCompressedModelLocalRuntimeCommandCard)|
     -> Result<(String, bool), Box<dyn std::error::Error>> {
        let mut cards = accepted_cards()?;
        mutate(&mut cards[0]);
        Ok((
            name.to_string(),
            build_set(upstream.clone(), SELECTED_CARD_ID, cards).is_err(),
        ))
    };

    type CardMutation = fn(&mut SmallCompressedModelLocalRuntimeCommandCard);
    let mutations: &[(&str, CardMutation)] = &[
        (
            "missing_cli_path",
            |card: &mut SmallCompressedModelLocalRuntimeCommandCard| {
                card.command_path_present = false;
            },
        ),
        ("bad_cli_path", |card| {
            card.command_path = "/usr/bin/false".to_string();
        }),
        ("owner_approval_granted", |card| {
            card.owner_approval_granted = true
        }),
        ("command_armed", |card| card.command_armed = true),
        ("command_executed", |card| card.command_executed = true),
        ("inference_executed", |card| card.inference_executed = true),
        ("model_file_opened", |card| card.model_file_opened = true),
        ("first_token_claimed", |card| {
            card.first_token_claimed = true
        }),
        ("retained_token_digest_recorded", |card| {
            card.retained_token_digest_recorded = true;
        }),
        ("opened_model_bytes", |card| {
            card.bytes.opened_model_bytes = 1
        }),
        ("opened_runtime_bytes", |card| {
            card.bytes.opened_runtime_bytes = 1
        }),
        ("resident_model_bytes", |card| {
            card.bytes.resident_model_bytes = 1
        }),
        ("resident_runtime_bytes", |card| {
            card.bytes.resident_runtime_bytes = 1
        }),
        ("model_bytes_loaded", |card| {
            card.bytes.model_bytes_loaded = 1
        }),
        ("runtime_bytes_loaded", |card| {
            card.bytes.runtime_bytes_loaded = 1
        }),
        ("provider_call_made", |card| {
            card.bytes.provider_calls_made = 1
        }),
        ("missing_answer_packet", |card| {
            card.answer_packet_required = false
        }),
        ("missing_run_event_log", |card| {
            card.run_event_log_required = false
        }),
        ("missing_rollback", |card| card.rollback_required = false),
        ("missing_cancellation", |card| {
            card.cancellation_required = false
        }),
        ("missing_memory_ledger", |card| {
            card.memory_ledger_required = false
        }),
        ("missing_command_visibility", |card| {
            card.command_visible = false
        }),
        ("missing_model_path_visibility", |card| {
            card.model_path_status_visible = false
        }),
        ("missing_command_ledger_visibility", |card| {
            card.command_ledger_visible = false
        }),
        ("missing_denied_sidecar_visibility", |card| {
            card.denied_sidecar_visible = false
        }),
        ("mas_product_build", |card| {
            card.product_build = ProductBuild::Mas
        }),
        ("pro_live_status", |card| card.pro_status = ProStatus::Live),
        ("promotion_tier_t2", |card| {
            card.promotion_tier = SmallCompressedHarnessPromotionTier::T2L2Route;
        }),
        ("quality_claim", |card| card.quality_claimed = true),
        ("l2_capability_claim", |card| {
            card.l2_capability_claimed = true
        }),
        ("l3_wrv_claim", |card| card.l3_wrv_claimed = true),
        ("mas_readiness_claim", |card| {
            card.mas_readiness_claimed = true
        }),
        ("hidden_cloud_fallback", |card| {
            card.hidden_cloud_fallback_allowed = true
        }),
        ("hidden_route_authority", |card| {
            card.hidden_route_authority_allowed = true
        }),
        ("provider_fallback", |card| {
            card.provider_fallback_allowed = true
        }),
        ("route_policy_mutated", |card| {
            card.route_policy_mutated = true
        }),
        ("live_dense_70b_claim", |card| {
            card.live_dense_70b_claimed = true
        }),
        ("ssd_as_ram_claim", |card| card.ssd_as_ram_claimed = true),
        ("bad_upstream_owner_gate_ref", |card| {
            card.refs.upstream_owner_gate_ref = "artifact:wrong".to_string();
        }),
        ("bad_model_path_ref", |card| {
            card.refs.model_path_ref = "model:path".to_string()
        }),
        ("bad_command_ledger_ref", |card| {
            card.refs.command_ledger_ref = "command_ledger:wrong".to_string();
        }),
        ("bad_local_version_ref", |card| {
            card.refs.local_version_ref = "local_version:other".to_string();
        }),
        ("bad_compatibility_fence_ref", |card| {
            card.refs.compatibility_fence_ref = "compat:wrong".to_string();
        }),
        ("card_metadata_budget_exceeded", |card| {
            card.bytes.path_metadata_bytes_read = 65 * 1024;
        }),
    ];
    for (name, mutate) in mutations {
        results.push(reject_card(name, *mutate)?);
    }

    let mut cards = accepted_cards()?;
    cards[0].card_id = SERVER_CARD_ID.to_string();
    results.push((
        "duplicate_card_id".to_string(),
        build_set(upstream.clone(), SELECTED_CARD_ID, cards).is_err(),
    ));

    let cards = accepted_cards()?;
    results.push((
        "selected_server_sidecar".to_string(),
        build_set(upstream.clone(), SERVER_CARD_ID, cards).is_err(),
    ));

    let mut cards = accepted_cards()?;
    cards[1].server_sidecar_default_allowed = true;
    results.push((
        "server_sidecar_default_allowed".to_string(),
        build_set(upstream.clone(), SELECTED_CARD_ID, cards).is_err(),
    ));

    let mut cards = accepted_cards()?;
    cards[1].refs.denied_sidecar_ref = "denied_sidecar:missing".to_string();
    results.push((
        "server_denial_ref_missing".to_string(),
        build_set(upstream.clone(), SELECTED_CARD_ID, cards).is_err(),
    ));

    let cards = accepted_cards()?;
    results.push((
        "set_missing_layer_separation".to_string(),
        SmallCompressedModelLocalRuntimeCommandCardSet::from_owner_gate(
            upstream.clone(),
            "artifact:small_compressed_model_owner_approval_runtime_gate:result",
            SELECTED_CARD_ID,
            cards.clone(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            SET_METADATA_BYTES,
            false,
            true,
            true,
            CREATED_AT_MS,
        )
        .is_err(),
    ));
    results.push((
        "set_runtime_not_deferred".to_string(),
        SmallCompressedModelLocalRuntimeCommandCardSet::from_owner_gate(
            upstream.clone(),
            "artifact:small_compressed_model_owner_approval_runtime_gate:result",
            SELECTED_CARD_ID,
            cards.clone(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            SET_METADATA_BYTES,
            true,
            false,
            true,
            CREATED_AT_MS,
        )
        .is_err(),
    ));
    results.push((
        "set_product_promotion_allowed".to_string(),
        SmallCompressedModelLocalRuntimeCommandCardSet::from_owner_gate(
            upstream.clone(),
            "artifact:small_compressed_model_owner_approval_runtime_gate:result",
            SELECTED_CARD_ID,
            cards.clone(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            SET_METADATA_BYTES,
            true,
            true,
            false,
            CREATED_AT_MS,
        )
        .is_err(),
    ));
    results.push((
        "set_metadata_budget_exceeded".to_string(),
        SmallCompressedModelLocalRuntimeCommandCardSet::from_owner_gate(
            upstream,
            "artifact:small_compressed_model_owner_approval_runtime_gate:result",
            SELECTED_CARD_ID,
            cards,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            129 * 1024,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
        .is_err(),
    ));

    Ok(results)
}

fn selected(
    cards: &[SmallCompressedModelLocalRuntimeCommandCard],
) -> Option<&SmallCompressedModelLocalRuntimeCommandCard> {
    cards.iter().find(|card| card.card_id == SELECTED_CARD_ID)
}

fn red_pass(red_results: &[(String, bool)], name: &str) -> bool {
    red_results
        .iter()
        .find(|(fixture, _)| fixture == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

fn insert_string_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: String,
    operator: &str,
    threshold: &str,
    unit: &str,
) {
    let pass = match operator {
        "==" => value == threshold,
        "starts_with" => value.starts_with(threshold),
        "contains" => value.contains(threshold),
        _ => false,
    };
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::json!(value),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::json!(threshold),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), pass);
}
