//! `falsify_gguf_in_process_runtime_admission_packet`
//!
//! Metadata-only witness for `F-GGUFInProcessRuntimeAdmissionPacket`. It builds
//! the local GGUF / llama.cpp in-process admission packet without opening model
//! files, loading runtime bytes, starting a server, or arming a command.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    canonical_gguf_in_process_runtime_admission_packet, GgufInProcessRuntimeAdmissionError,
    GgufInProcessRuntimeAdmissionPacket, GgufInProcessRuntimeAdmissionPacketSet,
    GGUF_IN_PROCESS_RUNTIME_ADMISSION_PACKET_CURSOR, GGUF_IN_PROCESS_RUNTIME_ADMISSION_PACKET_ID,
    GGUF_IN_PROCESS_RUNTIME_ADMISSION_PACKET_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = GGUF_IN_PROCESS_RUNTIME_ADMISSION_PACKET_ID;
const COMMAND: &str = "Tools/falsifiers/f_gguf_in_process_runtime_admission_packet.sh";
const RESULT: &str = "artifacts/falsifiers/gguf_in_process_runtime_admission_packet/result.json";
const FIXTURE_ID: &str = "gguf_in_process_runtime_admission_packet_v1";
const CREATED_AT_MS: u64 = 1_779_244_800_000;
const SET_METADATA_BYTES: u64 = 128_000;

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
        "{FALSIFIER_ID}: overall_pass={} local_code_anchor_count={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["local_code_anchor_count"].value,
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
    let packet = canonical_gguf_in_process_runtime_admission_packet();
    let set = build_set(packet.clone())?;
    let mut reversed = packet.clone();
    reversed.local_code_anchors.reverse();
    let reversed = build_set(reversed)?;
    let metrics = set.metrics();
    let red_results = red_fixture_results();
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "source_pin_and_binary_checksum_bound",
            packet.source_repo_url == "https://github.com/ggml-org/llama.cpp"
                && packet.llama_release_pin == "b6871"
                && packet.llama_commit_ref == "9a3ea68"
                && packet
                    .binary_target_url
                    .contains("llama-b6871-xcframework.zip")
                && packet.binary_checksum
                    == "ac657d70112efadbf5cd1db5c4f67eea94ca38556ada9e7442d5a5a461010d6f",
        ),
        (
            "local_code_anchors_bound",
            metrics.local_code_anchor_count == 8,
        ),
        (
            "owner_path_manifest_pending_and_raw_path_denied",
            metrics.owner_approval_pending_count == 1
                && metrics.raw_owner_path_stored_count == 0
                && packet.selected_model_path_policy.contains("no-raw-path")
                && packet
                    .proof_refs
                    .owner_path_manifest_ref
                    .starts_with("owner_path_manifest:"),
        ),
        (
            "byte_envelope_zero_and_no_file_open",
            metrics.selected_bytes_declared == 0
                && metrics.resident_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.model_files_opened == 0
                && metrics.cache_index_bytes_opened == 0
                && metrics.provider_calls_made == 0
                && metrics.product_files_copied == 0,
        ),
        (
            "command_and_server_unarmed",
            packet.command_envelope_unarmed
                && metrics.command_armed_count == 0
                && metrics.server_start_count == 0,
        ),
        (
            "context_batch_thread_caps_bound",
            packet.context_window_cap_tokens == 16_384
                && packet.batch_cap_tokens == 512
                && packet.thread_cap == 8,
        ),
        (
            "digest_and_budget_policies_bound",
            packet.kv_budget_ref.starts_with("kv_budget:")
                && packet.app_headroom_ref.starts_with("app_headroom:")
                && packet.chat_template_digest_policy.starts_with("sha256:")
                && packet.tool_schema_digest_policy.starts_with("sha256:")
                && packet.cache_salt_policy.starts_with("sha256:"),
        ),
        (
            "lifecycle_and_backend_contract_refs_bound",
            packet.prompt_trim_policy_ref.starts_with("prompt_trim:")
                && packet
                    .backend_launch_contract_ref
                    .starts_with("backend_contract:")
                && packet.sanitized_agent_event_ref.starts_with("agent_event:")
                && packet.cancellation_ref.starts_with("cancel:")
                && packet.teardown_ref.starts_with("teardown:"),
        ),
        (
            "rollback_run_event_answer_packet_and_abstention_bound",
            packet.proof_refs.rollback_ref.starts_with("rollback:")
                && packet
                    .proof_refs
                    .run_event_log_ref
                    .starts_with("run_event_log:")
                && packet
                    .proof_refs
                    .answer_packet_ref
                    .starts_with("answer_packet:")
                && packet.proof_refs.abstention_ref.starts_with("abstain:")
                && metrics.route_abstention_required_count == 1,
        ),
        (
            "metadata_only_runtime_probe_deferred",
            packet.metadata_only && packet.runtime_probe_deferred,
        ),
        (
            "no_fit_laundering_or_server_cache_confusion",
            metrics.mmap_mlock_gpu_fit_claim_count == 0
                && metrics.metal_support_fit_claim_count == 0
                && metrics.server_slot_cache_confusion_count == 0,
        ),
        (
            "no_raw_logs_hidden_authority_or_promotion",
            metrics.raw_prompt_logged_count == 0
                && metrics.raw_output_logged_count == 0
                && metrics.raw_token_logged_count == 0
                && metrics.hidden_route_authority_count == 0
                && metrics.mas_promotion_count == 0
                && metrics.l2_green_claim_count == 0
                && metrics.l3_green_claim_count == 0
                && metrics.live_dense_70b_claim_count == 0
                && metrics.ssd_as_ram_claim_count == 0,
        ),
        (
            "admission_packet_address_deterministic",
            set.set_address == reversed.set_address,
        ),
        (
            "next_cursor_bound",
            GGUF_IN_PROCESS_RUNTIME_ADMISSION_PACKET_NEXT_CURSOR
                == "runtime_lane_admission_matrix_qat_litert_gguf_mlx",
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
        "packet_count",
        metrics.packet_count,
        "==",
        1,
        "packets",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "local_code_anchor_count",
        metrics.local_code_anchor_count,
        "==",
        8,
        "anchors",
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
        "model_files_opened",
        metrics.model_files_opened,
        "==",
        0,
        "files",
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
        "admission_packet_address".to_string(),
        Measurement {
            value: serde_json::json!(set.set_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "admission_packet_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!(format!(
                "{GGUF_IN_PROCESS_RUNTIME_ADMISSION_PACKET_CURSOR}:"
            )),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "admission_packet_address".to_string(),
        set.set_address.to_string().starts_with(&format!(
            "{GGUF_IN_PROCESS_RUNTIME_ADMISSION_PACKET_CURSOR}:"
        )),
    );

    measurements.insert(
        "next_cursor".to_string(),
        Measurement {
            value: serde_json::json!(GGUF_IN_PROCESS_RUNTIME_ADMISSION_PACKET_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_cursor".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!("runtime_lane_admission_matrix_qat_litert_gguf_mlx"),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        GGUF_IN_PROCESS_RUNTIME_ADMISSION_PACKET_NEXT_CURSOR
            == "runtime_lane_admission_matrix_qat_litert_gguf_mlx",
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
        notes: "Builds F-GGUFInProcessRuntimeAdmissionPacket as a metadata-only Pass 177 witness. Scope is T1/L1 only: local GGUF / llama.cpp in-process lane source pin, binary checksum, code anchors, owner path-manifest policy, zero selected/opened/loaded bytes, context/KV/app-headroom policies, chat-template/tool-schema/cache-salt digests, cancellation, teardown, rollback, RunEventLog, AnswerPacket, abstention, sanitized AgentEvent test refs, no fit laundering, no server-cache confusion, no MAS/L2/L3/live-70B/SSD-as-RAM claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn build_set(
    packet: GgufInProcessRuntimeAdmissionPacket,
) -> Result<GgufInProcessRuntimeAdmissionPacketSet, GgufInProcessRuntimeAdmissionError> {
    GgufInProcessRuntimeAdmissionPacketSet::new(packet, SET_METADATA_BYTES, CREATED_AT_MS)
}

fn red_pass(mutator: impl FnOnce(&mut GgufInProcessRuntimeAdmissionPacket)) -> bool {
    let mut packet = canonical_gguf_in_process_runtime_admission_packet();
    mutator(&mut packet);
    build_set(packet).is_err()
}

fn red_fixture_results() -> Vec<(&'static str, bool)> {
    vec![
        (
            "missing_source_repo_rejected",
            red_pass(|p| p.source_repo_url.clear()),
        ),
        (
            "wrong_release_pin_rejected",
            red_pass(|p| p.llama_release_pin = "latest".to_string()),
        ),
        (
            "wrong_commit_ref_rejected",
            red_pass(|p| p.llama_commit_ref = "main".to_string()),
        ),
        (
            "wrong_binary_checksum_rejected",
            red_pass(|p| p.binary_checksum = "sha256:bad".to_string()),
        ),
        (
            "distribution_review_missing_rejected",
            red_pass(|p| p.direct_distribution_review_required = false),
        ),
        (
            "missing_code_anchor_rejected",
            red_pass(|p| {
                p.local_code_anchors.pop();
            }),
        ),
        (
            "approved_owner_manifest_rejected",
            red_pass(|p| {
                p.owner_path_manifest_status =
                    agent_core::uas::GgufOwnerPathManifestStatus::Approved;
            }),
        ),
        (
            "raw_owner_path_stored_rejected",
            red_pass(|p| p.raw_owner_path_stored = true),
        ),
        (
            "unsafe_path_policy_rejected",
            red_pass(|p| p.selected_model_path_policy = "/Users/jojo/model.gguf".to_string()),
        ),
        (
            "selected_bytes_declared_rejected",
            red_pass(|p| p.byte_envelope.selected_bytes_declared = 1),
        ),
        (
            "resident_bytes_loaded_rejected",
            red_pass(|p| p.byte_envelope.resident_bytes_loaded = 1),
        ),
        (
            "runtime_bytes_loaded_rejected",
            red_pass(|p| p.byte_envelope.runtime_bytes_loaded = 1),
        ),
        (
            "model_file_open_rejected",
            red_pass(|p| p.byte_envelope.model_files_opened = 1),
        ),
        (
            "cache_index_open_rejected",
            red_pass(|p| p.byte_envelope.cache_index_bytes_opened = 1),
        ),
        (
            "provider_call_rejected",
            red_pass(|p| p.byte_envelope.provider_calls_made = 1),
        ),
        (
            "command_armed_count_rejected",
            red_pass(|p| p.byte_envelope.command_armed_count = 1),
        ),
        (
            "server_start_count_rejected",
            red_pass(|p| p.byte_envelope.server_start_count = 1),
        ),
        (
            "product_copy_rejected",
            red_pass(|p| p.byte_envelope.product_files_copied = 1),
        ),
        (
            "unbounded_context_rejected",
            red_pass(|p| p.context_window_cap_tokens = 131_072),
        ),
        (
            "unbounded_batch_rejected",
            red_pass(|p| p.batch_cap_tokens = 2048),
        ),
        (
            "missing_kv_budget_rejected",
            red_pass(|p| p.kv_budget_ref.clear()),
        ),
        (
            "missing_app_headroom_rejected",
            red_pass(|p| p.app_headroom_ref.clear()),
        ),
        (
            "missing_chat_template_digest_rejected",
            red_pass(|p| p.chat_template_digest_policy.clear()),
        ),
        (
            "missing_tool_schema_digest_rejected",
            red_pass(|p| p.tool_schema_digest_policy.clear()),
        ),
        (
            "missing_cache_salt_rejected",
            red_pass(|p| p.cache_salt_policy.clear()),
        ),
        (
            "missing_cancellation_rejected",
            red_pass(|p| p.cancellation_ref.clear()),
        ),
        (
            "missing_rollback_rejected",
            red_pass(|p| p.proof_refs.rollback_ref.clear()),
        ),
        (
            "missing_answer_packet_rejected",
            red_pass(|p| p.proof_refs.answer_packet_ref.clear()),
        ),
        (
            "metadata_only_false_rejected",
            red_pass(|p| p.metadata_only = false),
        ),
        (
            "owner_approval_not_pending_rejected",
            red_pass(|p| p.owner_approval_pending = false),
        ),
        (
            "command_envelope_armed_rejected",
            red_pass(|p| p.command_envelope_unarmed = false),
        ),
        (
            "runtime_probe_not_deferred_rejected",
            red_pass(|p| p.runtime_probe_deferred = false),
        ),
        (
            "abstention_missing_rejected",
            red_pass(|p| p.route_abstention_required = false),
        ),
        (
            "mmap_fit_claim_rejected",
            red_pass(|p| p.mmap_mlock_gpu_fit_claim = true),
        ),
        (
            "metal_fit_claim_rejected",
            red_pass(|p| p.metal_support_fit_claim = true),
        ),
        (
            "server_cache_confusion_rejected",
            red_pass(|p| p.server_slot_cache_confused_with_in_process = true),
        ),
        (
            "raw_prompt_log_rejected",
            red_pass(|p| p.raw_prompt_logged = true),
        ),
        (
            "raw_output_log_rejected",
            red_pass(|p| p.raw_output_logged = true),
        ),
        (
            "raw_token_log_rejected",
            red_pass(|p| p.raw_token_logged = true),
        ),
        (
            "hidden_route_authority_rejected",
            red_pass(|p| p.hidden_route_authority = true),
        ),
        (
            "mas_promotion_rejected",
            red_pass(|p| p.mas_promoted = true),
        ),
        (
            "l2_green_claim_rejected",
            red_pass(|p| p.l2_green_claimed = true),
        ),
        (
            "l3_green_claim_rejected",
            red_pass(|p| p.l3_green_claimed = true),
        ),
        (
            "live_dense_70b_claim_rejected",
            red_pass(|p| p.live_dense_70b_claimed = true),
        ),
        (
            "ssd_as_ram_claim_rejected",
            red_pass(|p| p.ssd_as_ram_claimed = true),
        ),
    ]
}
