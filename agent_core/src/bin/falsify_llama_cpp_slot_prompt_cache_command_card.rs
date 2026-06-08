//! `falsify_llama_cpp_slot_prompt_cache_command_card`
//!
//! Metadata-only witness for `F-LlamaCppSlotPromptCacheCommandCard`. It builds
//! an unarmed llama.cpp slot prompt-cache command card without starting a
//! server, executing a command, or opening prompt-cache/model/KV/runtime bytes.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    canonical_llama_cpp_slot_prompt_cache_command_card, LlamaCppSlotCacheAction,
    LlamaCppSlotPromptCacheCommandCard, LlamaCppSlotPromptCacheCommandCardSet,
    LlamaCppSlotPromptCacheError, KV_CACHE_IDENTITY_SALT_OFFLOAD_PROOF_PACKET_ID,
    LLAMA_CPP_SLOT_PROMPT_CACHE_COMMAND_CARD_CURSOR, LLAMA_CPP_SLOT_PROMPT_CACHE_COMMAND_CARD_ID,
    LLAMA_CPP_SLOT_PROMPT_CACHE_COMMAND_CARD_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = LLAMA_CPP_SLOT_PROMPT_CACHE_COMMAND_CARD_ID;
const COMMAND: &str = "Tools/falsifiers/f_llama_cpp_slot_prompt_cache_command_card.sh";
const RESULT: &str = "artifacts/falsifiers/llama_cpp_slot_prompt_cache_command_card/result.json";
const FIXTURE_ID: &str = "llama_cpp_slot_prompt_cache_command_card_v1";
const CREATED_AT_MS: u64 = 1_779_158_400_000;
const SET_METADATA_BYTES: u64 = 96_000;
const PARENT_RESULT: &str =
    "artifacts/falsifiers/kv_cache_identity_salt_offload_proof_packet/result.json";

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
        "{FALSIFIER_ID}: overall_pass={} action_count={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["action_count"].value,
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
    let parent_present = parent_artifact_passes(Path::new(PARENT_RESULT));
    let card = canonical_llama_cpp_slot_prompt_cache_command_card();
    let set = build_set(card.clone())?;
    let mut reversed = card.clone();
    reversed.actions.reverse();
    reversed.expected_fields.reverse();
    let reversed = build_set(reversed)?;
    let metrics = set.metrics();
    let red_results = red_fixture_results();
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        ("parent_kv_cache_identity_packet_passed", parent_present),
        (
            "slot_endpoint_actions_bound",
            metrics.action_count == 3
                && card.actions.contains(&LlamaCppSlotCacheAction::Save)
                && card.actions.contains(&LlamaCppSlotCacheAction::Restore)
                && card.actions.contains(&LlamaCppSlotCacheAction::Erase)
                && card.endpoint_template == "/slots/{id_slot}?action=<save|restore|erase>",
        ),
        (
            "source_and_parent_bound",
            card.parent_falsifier_id == KV_CACHE_IDENTITY_SALT_OFFLOAD_PROOF_PACKET_ID
                && card.parent_artifact_path == PARENT_RESULT
                && card
                    .source_url
                    .starts_with("https://github.com/ggml-org/llama.cpp/")
                && card.source_retrieval_digest.starts_with("sha256:"),
        ),
        (
            "slot_filename_and_path_policy_bound",
            card.slot_id_min == 0
                && card.slot_id_max > 0
                && card.filename_example == "slot_save_file.bin"
                && card.filename_policy.starts_with("policy:basename-only")
                && card
                    .slot_save_path_scope
                    .starts_with("cache_root:artifacts/kv-cache/llama-cpp-slot"),
        ),
        (
            "cache_identity_digests_bound",
            card.session_id_digest.starts_with("sha256:")
                && card.prompt_digest.starts_with("sha256:")
                && card.tokenizer_digest.starts_with("sha256:")
                && card.chat_template_digest.starts_with("sha256:")
                && card.tool_schema_digest.starts_with("sha256:")
                && card.model_artifact_digest.starts_with("sha256:")
                && card.adapter_modality_digest.starts_with("sha256:")
                && card.cache_salt_digest.starts_with("sha256:"),
        ),
        (
            "response_metadata_fields_bound",
            metrics.expected_field_count == 9,
        ),
        (
            "proof_refs_and_deletion_policy_bound",
            card.proof_refs
                .owner_approval_ref
                .starts_with("owner_approval:")
                && card.proof_refs.rollback_ref.starts_with("rollback:")
                && card
                    .proof_refs
                    .run_event_log_ref
                    .starts_with("run_event_log:")
                && card
                    .proof_refs
                    .answer_packet_ref
                    .starts_with("answer_packet:")
                && card.proof_refs.abstention_ref.starts_with("abstain:")
                && card.deletion_policy.contains("erase-cache-on-rollback"),
        ),
        (
            "owner_approval_pending_and_command_unarmed",
            metrics.owner_approval_pending_count == 1
                && card.command_envelope_unarmed
                && card.server_start_denied
                && metrics.command_armed_count == 0
                && metrics.server_start_count == 0,
        ),
        (
            "zero_loaded_or_opened_bytes",
            metrics.prompt_cache_file_bytes_opened == 0
                && metrics.model_bytes_loaded == 0
                && metrics.kv_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && metrics.source_tree_bytes_opened == 0
                && metrics.product_bytes_opened == 0,
        ),
        (
            "no_raw_logs_hidden_authority_or_quality_laundering",
            metrics.raw_prompt_logged_count == 0
                && metrics.raw_token_logged_count == 0
                && metrics.stdout_stderr_captured_count == 0
                && metrics.hidden_route_authority_count == 0
                && metrics.cache_file_presence_quality_claim_count == 0
                && metrics.restored_cache_model_fit_claim_count == 0,
        ),
        (
            "no_mas_l2_l3_live_70b_or_ssd_as_ram_claim",
            metrics.mas_promotion_count == 0
                && metrics.l2_green_claim_count == 0
                && metrics.l3_green_claim_count == 0
                && metrics.live_dense_70b_claim_count == 0
                && metrics.ssd_as_ram_claim_count == 0,
        ),
        (
            "command_card_address_deterministic",
            set.set_address == reversed.set_address,
        ),
        (
            "next_cursor_bound",
            LLAMA_CPP_SLOT_PROMPT_CACHE_COMMAND_CARD_NEXT_CURSOR
                == "kivi_asymmetric_kv_stability_source_card",
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

    for (name, pass) in &red_results {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            *pass,
        );
    }

    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "card_count",
        metrics.card_count,
        "==",
        1,
        "cards",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "action_count",
        metrics.action_count,
        "==",
        3,
        "actions",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "expected_field_count",
        metrics.expected_field_count,
        "==",
        9,
        "fields",
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
        "prompt_cache_file_bytes_opened",
        metrics.prompt_cache_file_bytes_opened,
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

    measurements.insert(
        "command_card_address".to_string(),
        Measurement {
            value: serde_json::json!(set.set_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "command_card_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!(format!(
                "{LLAMA_CPP_SLOT_PROMPT_CACHE_COMMAND_CARD_CURSOR}:"
            )),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "command_card_address".to_string(),
        set.set_address.to_string().starts_with(&format!(
            "{LLAMA_CPP_SLOT_PROMPT_CACHE_COMMAND_CARD_CURSOR}:"
        )),
    );

    measurements.insert(
        "next_cursor".to_string(),
        Measurement {
            value: serde_json::json!(LLAMA_CPP_SLOT_PROMPT_CACHE_COMMAND_CARD_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_cursor".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!("kivi_asymmetric_kv_stability_source_card"),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        LLAMA_CPP_SLOT_PROMPT_CACHE_COMMAND_CARD_NEXT_CURSOR
            == "kivi_asymmetric_kv_stability_source_card",
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
        notes: "Builds F-LlamaCppSlotPromptCacheCommandCard as a metadata-only Pass 130 command-card witness. Scope is T1/L1 only: official llama.cpp slot save/restore/erase endpoint shape, slot id, basename/path-root policy, parent KV cache identity packet, cache salt, prompt/tokenizer/template/tool-schema/model digests, rollback, RunEventLog, AnswerPacket, abstention, deletion policy, owner approval pending, unarmed command envelope, denied server start, zero prompt-cache/model/KV/runtime/provider/product bytes, no MAS/L2/L3/product/live-70B/SSD-as-RAM claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn build_set(
    card: LlamaCppSlotPromptCacheCommandCard,
) -> Result<LlamaCppSlotPromptCacheCommandCardSet, LlamaCppSlotPromptCacheError> {
    LlamaCppSlotPromptCacheCommandCardSet::new(card, SET_METADATA_BYTES, CREATED_AT_MS)
}

fn parent_artifact_passes(path: &Path) -> bool {
    let Ok(bytes) = std::fs::read(path) else {
        return false;
    };
    let Ok(value) = serde_json::from_slice::<serde_json::Value>(&bytes) else {
        return false;
    };
    value
        .get("falsifier_id")
        .and_then(|value| value.as_str())
        .is_some_and(|id| id == KV_CACHE_IDENTITY_SALT_OFFLOAD_PROOF_PACKET_ID)
        && value
            .get("overall_pass")
            .and_then(|value| value.as_bool())
            .unwrap_or(false)
}

fn red_pass(mutator: impl FnOnce(&mut LlamaCppSlotPromptCacheCommandCard)) -> bool {
    let mut card = canonical_llama_cpp_slot_prompt_cache_command_card();
    mutator(&mut card);
    build_set(card).is_err()
}

fn red_fixture_results() -> Vec<(&'static str, bool)> {
    vec![
        (
            "missing_parent_packet_rejected",
            red_pass(|card| card.parent_falsifier_id.clear()),
        ),
        (
            "missing_source_url_rejected",
            red_pass(|card| card.source_url.clear()),
        ),
        (
            "missing_action_rejected",
            red_pass(|card| {
                card.actions.pop();
            }),
        ),
        (
            "invalid_endpoint_template_rejected",
            red_pass(|card| card.endpoint_template = "/completion".to_string()),
        ),
        (
            "invalid_slot_bounds_rejected",
            red_pass(|card| card.slot_id_max = 0),
        ),
        (
            "filename_path_escape_rejected",
            red_pass(|card| card.filename_example = "../slot.bin".to_string()),
        ),
        (
            "filename_absolute_path_rejected",
            red_pass(|card| card.filename_example = "/tmp/slot.bin".to_string()),
        ),
        (
            "filename_shell_metachar_rejected",
            red_pass(|card| card.filename_example = "slot;rm.bin".to_string()),
        ),
        (
            "filename_hidden_rejected",
            red_pass(|card| card.filename_example = ".slot.bin".to_string()),
        ),
        (
            "cache_root_escape_rejected",
            red_pass(|card| card.slot_save_path_scope = "/tmp/slots".to_string()),
        ),
        (
            "missing_prompt_digest_rejected",
            red_pass(|card| card.prompt_digest.clear()),
        ),
        (
            "missing_tokenizer_digest_rejected",
            red_pass(|card| card.tokenizer_digest.clear()),
        ),
        (
            "missing_tool_schema_digest_rejected",
            red_pass(|card| card.tool_schema_digest.clear()),
        ),
        (
            "missing_cache_salt_rejected",
            red_pass(|card| card.cache_salt_digest.clear()),
        ),
        (
            "missing_response_field_rejected",
            red_pass(|card| {
                card.expected_fields.pop();
            }),
        ),
        (
            "missing_rollback_rejected",
            red_pass(|card| card.proof_refs.rollback_ref.clear()),
        ),
        (
            "missing_answer_packet_rejected",
            red_pass(|card| card.proof_refs.answer_packet_ref.clear()),
        ),
        (
            "owner_approval_not_pending_rejected",
            red_pass(|card| card.owner_approval_pending = false),
        ),
        (
            "command_armed_rejected",
            red_pass(|card| card.command_envelope_unarmed = false),
        ),
        (
            "server_start_allowed_rejected",
            red_pass(|card| card.server_start_denied = false),
        ),
        (
            "prompt_cache_bytes_opened_rejected",
            red_pass(|card| card.byte_ledger.prompt_cache_file_bytes_opened = 1),
        ),
        (
            "model_bytes_loaded_rejected",
            red_pass(|card| card.byte_ledger.model_bytes_loaded = 1),
        ),
        (
            "command_armed_count_rejected",
            red_pass(|card| card.byte_ledger.command_armed_count = 1),
        ),
        (
            "raw_prompt_log_rejected",
            red_pass(|card| card.raw_prompt_logged = true),
        ),
        (
            "stdout_stderr_capture_rejected",
            red_pass(|card| card.stdout_stderr_captured = true),
        ),
        (
            "hidden_route_authority_rejected",
            red_pass(|card| card.hidden_route_authority = true),
        ),
        (
            "cache_file_presence_quality_claim_rejected",
            red_pass(|card| card.cache_file_presence_quality_claim = true),
        ),
        (
            "restored_cache_model_fit_claim_rejected",
            red_pass(|card| card.restored_cache_model_fit_claim = true),
        ),
        (
            "mas_promotion_rejected",
            red_pass(|card| card.mas_promoted = true),
        ),
        (
            "l2_green_claim_rejected",
            red_pass(|card| card.l2_green_claimed = true),
        ),
        (
            "l3_green_claim_rejected",
            red_pass(|card| card.l3_green_claimed = true),
        ),
        (
            "live_dense_70b_claim_rejected",
            red_pass(|card| card.live_dense_70b_claimed = true),
        ),
        (
            "ssd_as_ram_claim_rejected",
            red_pass(|card| card.ssd_as_ram_claimed = true),
        ),
    ]
}
