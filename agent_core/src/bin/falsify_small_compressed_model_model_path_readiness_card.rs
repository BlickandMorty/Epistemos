//! `falsify_small_compressed_model_model_path_readiness_card`
//!
//! Metadata-only witness for
//! `F-SmallCompressedModel-ModelPathReadinessCard`. It binds the selected
//! Gemma 4 E2B QAT GGUF source metadata to the local path-readiness state
//! required before an owner-approved one-token runtime probe can run.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, SmallCompressedHarnessPromotionTier,
    SmallCompressedModelModelPathReadinessCard, SmallCompressedModelModelPathReadinessCardSet,
    SmallCompressedModelPathByteLedger, SmallCompressedModelPathRefs,
    SmallCompressedModelPathStatus, UasAddress,
    SMALL_COMPRESSED_MODEL_MODEL_PATH_READINESS_CARD_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-SmallCompressedModel-ModelPathReadinessCard";
const FIXTURE_ID: &str = "small_compressed_model_model_path_readiness_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_small_compressed_model_model_path_readiness_card.sh";
const RESULT: &str =
    "artifacts/falsifiers/small_compressed_model_model_path_readiness_card/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/small_compressed_model_local_runtime_command_card/result.json";
const CREATED_AT_MS: u64 = 1_779_036_950_000;
const SET_METADATA_BYTES: u64 = 28_000;
const CARD_ID: &str = "gemma4_e2b_qat_gguf_model_path_readiness";
const SELECTED_CANDIDATE_ID: &str = "gemma4_e2b_qat_gguf_harness_preflight";
const MODEL_ID: &str = "google/gemma-4-E2B-it-qat-q4_0-gguf";
const REQUIRED_FILENAME: &str = "gemma-4-E2B_q4_0-it.gguf";
const SOURCE_REVISION: &str = "1894d1fc0a19d86697abd40483f5983c867df03f";
const SOURCE_XET_HASH: &str = "f9eedc0d3f769aa9c59341e9b230f2d6b4726cc355b1f0101b60a524a6584a30";
const SOURCE_ETAG: &str = "f9eedc0d3f769aa9c59341e9b230f2d6b4726cc355b1f0101b60a524a6584a30";
const EXPECTED_MODEL_FILE_BYTES: u64 = 3_349_514_112;

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
        "{FALSIFIER_ID}: overall_pass={} local_path_present_count={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["local_path_present_count"].value,
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
    let (upstream_address, upstream_next_unit) = upstream_command_card_address()?;
    let local_path_present_count = candidate_model_paths()
        .iter()
        .filter(|path| std::fs::symlink_metadata(path).is_ok())
        .count() as u64;
    let card = accepted_card(local_path_present_count)?;
    let card_set = build_set(upstream_address.clone(), vec![card.clone()])?;
    let reversed = build_set(upstream_address, vec![card.clone()])?;
    let metrics = card_set.metrics();
    let red_results = red_fixture_results(&card_set)?;
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_command_card_bound",
            upstream_next_unit == "small_compressed_model_owner_approved_runtime_probe"
                && card_set
                    .upstream_command_card_witness_ref
                    .contains("small_compressed_model_local_runtime_command_card")
                && red_pass(&red_results, "bad_upstream_command_card_ref"),
        ),
        (
            "source_metadata_recorded",
            card.model_id == MODEL_ID
                && card.required_filename == REQUIRED_FILENAME
                && card.source_revision == SOURCE_REVISION
                && card.source_xet_hash == SOURCE_XET_HASH
                && card.source_etag == SOURCE_ETAG
                && metrics.expected_model_file_bytes == EXPECTED_MODEL_FILE_BYTES
                && red_pass(&red_results, "wrong_model_id")
                && red_pass(&red_results, "wrong_required_filename")
                && red_pass(&red_results, "short_source_revision")
                && red_pass(&red_results, "short_source_hash")
                && red_pass(&red_results, "small_expected_bytes"),
        ),
        (
            "local_path_missing_fail_closed",
            card.local_path_status == SmallCompressedModelPathStatus::MissingOrUnverified
                && card.local_model_path.is_none()
                && local_path_present_count == 0
                && metrics.missing_or_unverified_count == 1
                && red_pass(&red_results, "local_model_path_present")
                && red_pass(&red_results, "local_status_present_but_unapproved")
                && red_pass(&red_results, "missing_downloads_scope")
                && red_pass(&red_results, "missing_huggingface_scope"),
        ),
        (
            "owner_and_download_approval_pending",
            card.owner_approval_required
                && !card.owner_approval_granted
                && card.download_approval_required
                && !card.download_approval_granted
                && !card.download_executed
                && !card.command_armed
                && !card.command_executed
                && !card.inference_executed
                && !card.first_token_claimed
                && red_pass(&red_results, "owner_approval_granted")
                && red_pass(&red_results, "download_approval_granted")
                && red_pass(&red_results, "download_executed")
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "inference_executed")
                && red_pass(&red_results, "first_token_claimed"),
        ),
        (
            "byte_ledger_zero_loaded",
            metrics.downloaded_model_bytes == 0
                && metrics.opened_model_bytes == 0
                && metrics.hashed_model_bytes == 0
                && metrics.resident_model_bytes == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "downloaded_model_bytes")
                && red_pass(&red_results, "opened_model_bytes")
                && red_pass(&red_results, "hashed_model_bytes")
                && red_pass(&red_results, "resident_model_bytes")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_call_made"),
        ),
        (
            "proof_surfaces_required",
            card.answer_packet_required
                && card.run_event_log_required
                && card.rollback_required
                && card.cancellation_required
                && card.memory_ledger_required
                && red_pass(&red_results, "missing_answer_packet")
                && red_pass(&red_results, "missing_run_event_log")
                && red_pass(&red_results, "missing_rollback")
                && red_pass(&red_results, "missing_cancellation")
                && red_pass(&red_results, "missing_memory_ledger"),
        ),
        (
            "visibility_required",
            card.source_metadata_visible
                && card.local_path_status_visible
                && card.command_card_visible
                && red_pass(&red_results, "missing_source_metadata_visibility")
                && red_pass(&red_results, "missing_local_path_visibility")
                && red_pass(&red_results, "missing_command_card_visibility"),
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
                && red_pass(&red_results, "server_sidecar_default_allowed")
                && red_pass(&red_results, "route_policy_mutated")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "proof_ref_prefixes_required",
            red_pass(&red_results, "bad_source_model_ref")
                && red_pass(&red_results, "bad_model_path_ref")
                && red_pass(&red_results, "bad_owner_approval_ref")
                && red_pass(&red_results, "bad_download_approval_ref")
                && red_pass(&red_results, "bad_command_card_ref")
                && red_pass(&red_results, "bad_memory_ledger_ref")
                && red_pass(&red_results, "bad_route_caveat_ref"),
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
            red_pass(&red_results, "card_source_metadata_budget_exceeded")
                && red_pass(&red_results, "card_path_metadata_budget_exceeded")
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
        "model_path_card_count",
        metrics.card_count,
        "==",
        1,
        "cards",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "local_path_present_count",
        local_path_present_count,
        "==",
        0,
        "paths",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "local_search_scope_count",
        metrics.local_search_scope_count,
        ">=",
        4,
        "scopes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "expected_model_file_bytes",
        metrics.expected_model_file_bytes,
        "==",
        EXPECTED_MODEL_FILE_BYTES,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_count",
        red_results.len() as u64,
        ">=",
        45,
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
        "downloaded_model_bytes",
        metrics.downloaded_model_bytes,
        "==",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "opened_model_bytes",
        metrics.opened_model_bytes,
        "==",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hashed_model_bytes",
        metrics.hashed_model_bytes,
        "==",
        0,
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

    insert_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_path_set_address",
        card_set.set_address.to_string(),
        "starts_with",
        "small_compressed_model_model_path_readiness_card:",
        "uas_address",
    );
    insert_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "selected_model_id",
        card.model_id.clone(),
        "==",
        MODEL_ID,
        "model_id",
    );
    insert_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "required_model_filename",
        card.required_filename.clone(),
        "==",
        REQUIRED_FILENAME,
        "filename",
    );
    insert_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_revision",
        card.source_revision.clone(),
        "==",
        SOURCE_REVISION,
        "revision",
    );
    insert_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_xet_hash",
        card.source_xet_hash.clone(),
        "==",
        SOURCE_XET_HASH,
        "hash",
    );
    insert_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_research_to_build_unit",
        SMALL_COMPRESSED_MODEL_MODEL_PATH_READINESS_CARD_NEXT_CURSOR.to_string(),
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
        notes: "Builds F-SmallCompressedModel-ModelPathReadinessCard from the local GGUF command card. Scope is research-to-build T1/L1 metadata only: the Gemma 4 E2B QAT GGUF source revision, Xet hash, expected file bytes, and local search scopes are recorded; the local model path is missing or unverified; owner/download approval remains pending; no download, model open, hash, command, inference, provider, L2, or L3 claim is executed or promoted.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_command_card_address() -> Result<(UasAddress, String), Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream local runtime command card has not passed".into());
    }
    let address = value
        .pointer("/measurements/command_card_set_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("missing upstream command_card_set_address measurement")?;
    let next_unit = value
        .pointer("/measurements/next_research_to_build_unit/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("missing upstream next_research_to_build_unit measurement")?;
    Ok((UasAddress::from_str(address)?, next_unit.to_string()))
}

fn build_set(
    upstream_command_card_set_address: UasAddress,
    cards: Vec<SmallCompressedModelModelPathReadinessCard>,
) -> Result<SmallCompressedModelModelPathReadinessCardSet, Box<dyn std::error::Error>> {
    Ok(
        SmallCompressedModelModelPathReadinessCardSet::from_command_card(
            upstream_command_card_set_address,
            "artifact:small_compressed_model_local_runtime_command_card:result",
            CARD_ID,
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

fn accepted_card(
    local_path_present_count: u64,
) -> Result<SmallCompressedModelModelPathReadinessCard, Box<dyn std::error::Error>> {
    if local_path_present_count != 0 {
        return Err("selected Gemma 4 E2B GGUF file is already present in a checked local scope; owner-approved path witness required instead".into());
    }
    Ok(SmallCompressedModelModelPathReadinessCard {
        card_id: CARD_ID.to_string(),
        selected_candidate_id: SELECTED_CANDIDATE_ID.to_string(),
        model_id: MODEL_ID.to_string(),
        required_filename: REQUIRED_FILENAME.to_string(),
        source_revision: SOURCE_REVISION.to_string(),
        source_xet_hash: SOURCE_XET_HASH.to_string(),
        source_etag: SOURCE_ETAG.to_string(),
        local_path_status: SmallCompressedModelPathStatus::MissingOrUnverified,
        local_model_path: None,
        local_search_scopes: local_search_scopes(),
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: SmallCompressedHarnessPromotionTier::T1L1Metadata,
        bytes: SmallCompressedModelPathByteLedger::missing_metadata_only(
            EXPECTED_MODEL_FILE_BYTES,
            source_metadata_bytes(),
            local_path_metadata_bytes(),
        ),
        refs: refs(CARD_ID),
        user_visible_summary: "Gemma 4 E2B QAT GGUF source metadata is recorded as a buildable small-compressed-model target, but the local model path is missing or unverified. No download, model open, hash, runtime command, provider fallback, hidden route, first-token, L2, L3, MAS, dense 70B, or SSD-as-RAM claim is permitted until owner approval and a separate runtime witness exist.".to_string(),
        source_metadata_visible: true,
        local_path_status_visible: true,
        command_card_visible: true,
        owner_approval_required: true,
        owner_approval_granted: false,
        download_approval_required: true,
        download_approval_granted: false,
        download_executed: false,
        command_armed: false,
        command_executed: false,
        inference_executed: false,
        first_token_claimed: false,
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

fn refs(id: &str) -> SmallCompressedModelPathRefs {
    SmallCompressedModelPathRefs {
        upstream_command_card_ref:
            "artifact:small_compressed_model_local_runtime_command_card:result".to_string(),
        source_model_ref: format!("source:model:gemma4-e2b-qat-gguf:{SOURCE_REVISION}"),
        model_path_ref: format!("model_path:missing_or_unverified:{id}"),
        owner_approval_ref: format!("owner_approval:pending:{id}"),
        download_approval_ref: format!("download_approval:pending:{id}"),
        command_card_ref: format!("command_card:small_compressed_local_runtime:{id}"),
        answer_packet_ref: format!("answer_packet:small_compressed_model_path:{id}"),
        run_event_log_ref: format!("run_event_log:small_compressed_model_path:{id}"),
        rollback_ref: format!("rollback:small_compressed_model_path:{id}"),
        cancellation_ref: format!("cancel:small_compressed_model_path:{id}"),
        memory_ledger_ref: format!("memory_ledger:small_compressed_model_path:{id}"),
        route_caveat_ref: format!("route_caveat:small_compressed_model_path:{id}"),
    }
}

fn local_search_scopes() -> Vec<String> {
    vec![
        "/Users/jojo/Downloads".to_string(),
        "/Users/jojo/.cache/huggingface/hub".to_string(),
        "/Users/jojo/.cache/lm-studio".to_string(),
        "/Users/jojo/.ollama".to_string(),
    ]
}

fn candidate_model_paths() -> Vec<PathBuf> {
    vec![
        PathBuf::from(format!("/Users/jojo/Downloads/{REQUIRED_FILENAME}")),
        PathBuf::from(format!(
            "/Users/jojo/.cache/huggingface/hub/models--google--gemma-4-E2B-it-qat-q4_0-gguf/snapshots/{SOURCE_REVISION}/{REQUIRED_FILENAME}"
        )),
        PathBuf::from(format!(
            "/Users/jojo/.cache/lm-studio/models/google/gemma-4-E2B-it-qat-q4_0-gguf/{REQUIRED_FILENAME}"
        )),
    ]
}

fn source_metadata_bytes() -> u64 {
    [
        MODEL_ID,
        REQUIRED_FILENAME,
        SOURCE_REVISION,
        SOURCE_XET_HASH,
        SOURCE_ETAG,
    ]
    .iter()
    .map(|value| value.len() as u64)
    .sum::<u64>()
    .max(1)
}

fn local_path_metadata_bytes() -> u64 {
    local_search_scopes()
        .iter()
        .map(|scope| {
            std::fs::symlink_metadata(scope)
                .map(|metadata| metadata.len())
                .unwrap_or(0)
                .saturating_add(scope.len() as u64)
        })
        .sum::<u64>()
        .max(1)
}

fn red_fixture_results(
    set: &SmallCompressedModelModelPathReadinessCardSet,
) -> Result<Vec<(String, bool)>, Box<dyn std::error::Error>> {
    let mut results = Vec::new();
    let upstream = set.upstream_command_card_set_address.clone();

    let reject_card = |name: &str,
                       mutate: fn(&mut SmallCompressedModelModelPathReadinessCard)|
     -> Result<(String, bool), Box<dyn std::error::Error>> {
        let mut card = accepted_card(0)?;
        mutate(&mut card);
        Ok((
            name.to_string(),
            build_set(upstream.clone(), vec![card]).is_err(),
        ))
    };

    type CardMutation = fn(&mut SmallCompressedModelModelPathReadinessCard);
    let mutations: &[(&str, CardMutation)] = &[
        ("wrong_model_id", |card| {
            card.model_id = "other/model".to_string()
        }),
        ("wrong_required_filename", |card| {
            card.required_filename = "other.gguf".to_string();
        }),
        ("short_source_revision", |card| {
            card.source_revision = "short".to_string();
        }),
        ("short_source_hash", |card| {
            card.source_xet_hash = "short".to_string();
        }),
        ("small_expected_bytes", |card| {
            card.bytes.expected_model_file_bytes = 1_000_000;
        }),
        ("local_model_path_present", |card| {
            card.local_model_path =
                Some("/Users/jojo/Downloads/gemma-4-E2B_q4_0-it.gguf".to_string());
        }),
        ("local_status_present_but_unapproved", |card| {
            card.local_path_status = SmallCompressedModelPathStatus::PresentButUnapproved;
        }),
        ("missing_downloads_scope", |card| {
            card.local_search_scopes
                .retain(|scope| !scope.contains("/Users/jojo/Downloads"));
        }),
        ("missing_huggingface_scope", |card| {
            card.local_search_scopes
                .retain(|scope| !scope.contains(".cache/huggingface"));
        }),
        ("owner_approval_granted", |card| {
            card.owner_approval_granted = true;
        }),
        ("download_approval_granted", |card| {
            card.download_approval_granted = true;
        }),
        ("download_executed", |card| card.download_executed = true),
        ("command_armed", |card| card.command_armed = true),
        ("command_executed", |card| card.command_executed = true),
        ("inference_executed", |card| card.inference_executed = true),
        ("first_token_claimed", |card| {
            card.first_token_claimed = true;
        }),
        ("downloaded_model_bytes", |card| {
            card.bytes.downloaded_model_bytes = 1;
        }),
        ("opened_model_bytes", |card| {
            card.bytes.opened_model_bytes = 1;
        }),
        ("hashed_model_bytes", |card| {
            card.bytes.hashed_model_bytes = 1;
        }),
        ("resident_model_bytes", |card| {
            card.bytes.resident_model_bytes = 1;
        }),
        ("model_bytes_loaded", |card| {
            card.bytes.model_bytes_loaded = 1;
        }),
        ("runtime_bytes_loaded", |card| {
            card.bytes.runtime_bytes_loaded = 1;
        }),
        ("provider_call_made", |card| {
            card.bytes.provider_calls_made = 1;
        }),
        ("missing_answer_packet", |card| {
            card.answer_packet_required = false;
        }),
        ("missing_run_event_log", |card| {
            card.run_event_log_required = false;
        }),
        ("missing_rollback", |card| card.rollback_required = false),
        ("missing_cancellation", |card| {
            card.cancellation_required = false;
        }),
        ("missing_memory_ledger", |card| {
            card.memory_ledger_required = false;
        }),
        ("missing_source_metadata_visibility", |card| {
            card.source_metadata_visible = false;
        }),
        ("missing_local_path_visibility", |card| {
            card.local_path_status_visible = false;
        }),
        ("missing_command_card_visibility", |card| {
            card.command_card_visible = false;
        }),
        ("mas_product_build", |card| {
            card.product_build = ProductBuild::Mas;
        }),
        ("pro_live_status", |card| card.pro_status = ProStatus::Live),
        ("promotion_tier_t2", |card| {
            card.promotion_tier = SmallCompressedHarnessPromotionTier::T2L2Route;
        }),
        ("quality_claim", |card| card.quality_claimed = true),
        ("l2_capability_claim", |card| {
            card.l2_capability_claimed = true;
        }),
        ("l3_wrv_claim", |card| card.l3_wrv_claimed = true),
        ("mas_readiness_claim", |card| {
            card.mas_readiness_claimed = true;
        }),
        ("hidden_cloud_fallback", |card| {
            card.hidden_cloud_fallback_allowed = true;
        }),
        ("hidden_route_authority", |card| {
            card.hidden_route_authority_allowed = true;
        }),
        ("provider_fallback", |card| {
            card.provider_fallback_allowed = true;
        }),
        ("server_sidecar_default_allowed", |card| {
            card.server_sidecar_default_allowed = true;
        }),
        ("route_policy_mutated", |card| {
            card.route_policy_mutated = true;
        }),
        ("live_dense_70b_claim", |card| {
            card.live_dense_70b_claimed = true;
        }),
        ("ssd_as_ram_claim", |card| card.ssd_as_ram_claimed = true),
        ("bad_source_model_ref", |card| {
            card.refs.source_model_ref = "source:model:wrong".to_string();
        }),
        ("bad_model_path_ref", |card| {
            card.refs.model_path_ref = "model:path".to_string();
        }),
        ("bad_owner_approval_ref", |card| {
            card.refs.owner_approval_ref = "owner:approved".to_string();
        }),
        ("bad_download_approval_ref", |card| {
            card.refs.download_approval_ref = "download:approved".to_string();
        }),
        ("bad_command_card_ref", |card| {
            card.refs.command_card_ref = "command_card:wrong".to_string();
        }),
        ("bad_memory_ledger_ref", |card| {
            card.refs.memory_ledger_ref = "memory:wrong".to_string();
        }),
        ("bad_route_caveat_ref", |card| {
            card.refs.route_caveat_ref = "route:wrong".to_string();
        }),
        ("card_source_metadata_budget_exceeded", |card| {
            card.bytes.source_metadata_bytes_read = 65 * 1024;
        }),
        ("card_path_metadata_budget_exceeded", |card| {
            card.bytes.local_path_metadata_bytes_read = 65 * 1024;
        }),
    ];
    for (name, mutate) in mutations {
        results.push(reject_card(name, *mutate)?);
    }

    let card = accepted_card(0)?;
    results.push((
        "bad_upstream_command_card_ref".to_string(),
        SmallCompressedModelModelPathReadinessCardSet::from_command_card(
            upstream.clone(),
            "artifact:wrong",
            CARD_ID,
            vec![card.clone()],
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            SET_METADATA_BYTES,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
        .is_err(),
    ));
    results.push((
        "set_missing_layer_separation".to_string(),
        SmallCompressedModelModelPathReadinessCardSet::from_command_card(
            upstream.clone(),
            "artifact:small_compressed_model_local_runtime_command_card:result",
            CARD_ID,
            vec![card.clone()],
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
        SmallCompressedModelModelPathReadinessCardSet::from_command_card(
            upstream.clone(),
            "artifact:small_compressed_model_local_runtime_command_card:result",
            CARD_ID,
            vec![card.clone()],
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
        SmallCompressedModelModelPathReadinessCardSet::from_command_card(
            upstream.clone(),
            "artifact:small_compressed_model_local_runtime_command_card:result",
            CARD_ID,
            vec![card.clone()],
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
        SmallCompressedModelModelPathReadinessCardSet::from_command_card(
            upstream,
            "artifact:small_compressed_model_local_runtime_command_card:result",
            CARD_ID,
            vec![card],
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
