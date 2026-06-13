//! `falsify_small_model_runtime_harness_fresh_product_runtime_answer_packet_probe`.
//!
//! This witness packetizes the fresh product-runtime live sidecar into the
//! real Rust AnswerPacket schema plus a dense RunEventLog. It performs no new
//! inference and opens no model bytes.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

#[cfg(test)]
use agent_core::falsifier_artifacts::axes::SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_ANSWER_PACKET_PROBE_AXES;
use agent_core::falsifier_artifacts::axes::SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::provenance::ledger::{Claim, ClaimId, ClaimKind};
use agent_core::scope_rex::answer_packet::{AttentionMode, SemanticDeltaId, VrmLabel};
use agent_core::scope_rex::produce::{produce_turn_completion_packet, TurnCompletionInputs};
use agent_core::uas::{
    redacted_fresh_product_runtime_run_event_log,
    required_fresh_product_runtime_answer_packet_probe_phases, ProStatus, ProductBuild,
    SmallModelFreshProductRuntimeAnswerPacketPacket,
    SmallModelFreshProductRuntimeAnswerPacketProbeError,
    SmallModelFreshProductRuntimeAnswerPacketProbeWitness,
    SmallModelFreshProductRuntimeAnswerPacketSurface,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_ANSWER_PACKET_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_ANSWER_PACKET_PROBE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-SmallModelRuntimeHarnessFreshProductRuntimeAnswerPacketProbe";
const FIXTURE_ID: &str = "small_model_runtime_harness_fresh_product_runtime_answer_packet_probe_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_small_model_runtime_harness_fresh_product_runtime_answer_packet_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_answer_packet_probe/result.json";
const ANSWER_PACKET_SIDECAR: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_answer_packet_probe/answer_packet.json";
const RUN_EVENT_LOG_SIDECAR: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_answer_packet_probe/run_event_log.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const FRESH_LIVE_PROBE_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_live_probe/result.json";
const LIVE_PROBE_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_live_probe/live_probe.json";
const LIVING_INDEX_PATH: &str = "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md";
const LATTICE_HTML_PATH: &str = "artifacts/lattice-coordinate-explainer/index.html";
const CREATED_AT_MS: i64 = 1_779_552_000_000;
const MIN_PACKET_COUNT: u64 = 1;
const MIN_CLAIM_COUNT: u64 = 2;
const MIN_LOG_ENTRY_COUNT: u64 = 2;
const MAX_PACKETIZATION_BYTES: u64 = 0;
const MAX_METADATA_BYTES: u64 = 512 * 1024;

#[derive(Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-answer-packet-probe:witness-error
// Plane: Verification
// Residency: fresh product-runtime packetization rejection taxonomy.
enum AnswerPacketWitnessError {
    Primitive(SmallModelFreshProductRuntimeAnswerPacketProbeError),
    Io(String),
    Json(String),
}

impl std::fmt::Display for AnswerPacketWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) | Self::Json(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for AnswerPacketWitnessError {}

impl From<SmallModelFreshProductRuntimeAnswerPacketProbeError> for AnswerPacketWitnessError {
    fn from(value: SmallModelFreshProductRuntimeAnswerPacketProbeError) -> Self {
        Self::Primitive(value)
    }
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
        "{FALSIFIER_ID}: overall_pass={} artifact={RESULT}",
        artifact.overall_pass
    );
    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, AnswerPacketWitnessError> {
    let evidence = EvidenceSnapshot::read()?;
    let (witness, answer_packet_bytes, run_event_log_bytes) = fixture_witness(&evidence)?;
    write_sidecar(Path::new(ANSWER_PACKET_SIDECAR), &answer_packet_bytes)?;
    write_sidecar(Path::new(RUN_EVENT_LOG_SIDECAR), &run_event_log_bytes)?;

    let metrics = witness.metrics();
    let address = witness.address();
    let mut reversed_packets = witness.packets.clone();
    reversed_packets.reverse();
    let deterministic = SmallModelFreshProductRuntimeAnswerPacketProbeWitness::new(
        "small-model-fresh-product-runtime-answer-packet-probe",
        "artifact:small_model_runtime_harness_fresh_product_runtime_live_probe:result",
        witness.guard_next_existing_work.clone(),
        witness.capability_route_status.clone(),
        witness.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::Gated,
        "fresh_product_runtime_packetized_visible_proof_only",
        reversed_packets,
        witness.surfaces.clone(),
        witness.metadata_bytes,
        true,
        false,
        false,
        false,
    )?
    .address()
        == address;
    let invalid_axes = invalid_fixture_axes(&evidence)?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let packet = &witness.packets[0];
    let bool_axes = [
        ("upstream_fresh_product_runtime_live_probe_pass", evidence.fresh_live_pass),
        (
            "guard_cursor_answer_packet_or_advanced",
            evidence.guard_next_existing_work
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_ANSWER_PACKET_PROBE_CURSOR
                || evidence.guard_next_existing_work
                    == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_ANSWER_PACKET_PROBE_NEXT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_answer_packet_or_advanced",
            evidence.capability_next_bottleneck
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_ANSWER_PACKET_PROBE_CURSOR
                || evidence.capability_next_bottleneck
                    == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_ANSWER_PACKET_PROBE_NEXT_CURSOR,
        ),
        (
            "product_status_gated",
            witness.product_build == ProductBuild::Pro && witness.pro_status == ProStatus::Gated,
        ),
        (
            "route_authority_packetized_proof_only",
            witness.route_authority == "fresh_product_runtime_packetized_visible_proof_only",
        ),
        (
            "answer_packet_sidecar_bound",
            Path::new(ANSWER_PACKET_SIDECAR).exists()
                && packet.packet_json_ref.starts_with("answer_packet_json:"),
        ),
        (
            "run_event_log_sidecar_bound",
            Path::new(RUN_EVENT_LOG_SIDECAR).exists()
                && packet.run_event_log_ref.starts_with("run_event_log:"),
        ),
        (
            "answer_packet_schema_round_trip",
            serde_json::from_slice::<agent_core::scope_rex::answer_packet::AnswerPacket>(
                &answer_packet_bytes,
            )
            .is_ok(),
        ),
        (
            "answer_packet_id_bound",
            packet.answer_packet.id.0 == packet.answer_packet_ref,
        ),
        (
            "witnessed_state_bound",
            packet.witnessed_state_ref.starts_with("witnessed_state:")
                && packet.answer_packet.witnessed_state_ref.0 == packet.witnessed_state_ref,
        ),
        (
            "mutation_envelope_no_mutation_bound",
            packet
                .mutation_envelope_ref
                .starts_with("mutation_envelope:no_mutation:")
                && packet.answer_packet.mutation_envelope_ref.0 == packet.mutation_envelope_ref,
        ),
        (
            "semantic_delta_redacted_token_bound",
            packet
                .semantic_delta_ref
                .starts_with("semantic_delta:redacted_first_token:")
                && packet
                    .answer_packet
                    .semantic_delta_ref
                    .as_ref()
                    .map(|delta| delta.0.as_str())
                    == Some(packet.semantic_delta_ref.as_str()),
        ),
        (
            "packet_claims_bound",
            packet.answer_packet.claims.len() >= MIN_CLAIM_COUNT as usize,
        ),
        (
            "packet_claim_kinds_bound",
            packet
                .answer_packet
                .claims
                .iter()
                .any(|claim| claim.kind == ClaimKind::Empirical)
                && packet
                    .answer_packet
                    .claims
                    .iter()
                    .any(|claim| claim.kind == ClaimKind::CodeInvariant),
        ),
        (
            "packet_claims_active",
            packet
                .answer_packet
                .claims
                .iter()
                .all(|claim| claim.status == agent_core::provenance::ledger::ClaimStatus::Active),
        ),
        (
            "attention_mode_dynamic_bound",
            packet.answer_packet.attention_mode == AttentionMode::Dynamic,
        ),
        (
            "no_static_fallback_ack_on_dynamic",
            packet.answer_packet.attention_mode_claims_are_consistent()
                && !packet
                    .answer_packet
                    .claims
                    .iter()
                    .any(|claim| claim.kind == ClaimKind::StaticFallbackAcknowledged),
        ),
        (
            "ui_label_not_verified_overclaim",
            packet.answer_packet.ui_label != VrmLabel::Verified,
        ),
        (
            "residency_signal_neutral_bound",
            packet.answer_packet.residency_signals.len() == 1
                && (packet.answer_packet.residency_signals[0].verification_score - 0.5).abs()
                    < f32::EPSILON,
        ),
        (
            "run_event_log_dense",
            packet.run_event_log.validate_ordinal_density().is_ok(),
        ),
        (
            "run_event_log_root_bound",
            packet
                .run_event_log_root_ref
                .starts_with("run_event_log_root:")
                && packet.run_event_log_root_ref
                    == format!(
                        "run_event_log_root:{}",
                        packet.run_event_log.root_hash().to_hex()
                    ),
        ),
        (
            "run_event_log_stop_end_turn",
            packet.run_event_log.stop_count() == 1
                && packet.run_event_log.last_stop_event()
                    == Some(agent_core::agent_runtime_v2::StopReason::EndTurn),
        ),
        (
            "run_event_log_no_errors",
            packet.run_event_log.error_count() == 0,
        ),
        (
            "redacted_final_text_bound",
            String::from_utf8_lossy(&run_event_log_bytes).contains("[redacted-first-token:"),
        ),
        (
            "fresh_live_probe_sidecar_bound",
            packet.live_probe_sidecar_ref.starts_with(
                "artifact:small_model_runtime_harness_fresh_product_runtime_live_probe:live_probe:",
            ),
        ),
        (
            "fresh_live_sidecar_token_redacted",
            evidence.live_probe.first_token_observed
                && evidence.live_probe.output_token_count == 1
                && !evidence.live_probe.raw_token_text_retained.unwrap_or(false)
                && evidence.live_probe.first_token_preview.is_none(),
        ),
        (
            "prompt_hash_bound",
            evidence.live_probe.prompt_sha256.starts_with("sha256:")
                && !evidence.live_probe.prompt_contains_user_data,
        ),
        (
            "token_digest_bound",
            packet.token_digest_ref == evidence.live_probe.first_token_sha256
                || packet.token_digest_ref
                    == format!(
                        "token_sha256:{}",
                        evidence
                            .live_probe
                            .first_token_sha256
                            .trim_start_matches("sha256:")
                    ),
        ),
        (
            "rollback_bound",
            packet.rollback_ref.starts_with("rollback:"),
        ),
        (
            "admission_bound",
            packet.admission_ref.starts_with("admission:"),
        ),
        (
            "scope_rex_bound",
            packet.scope_rex_ref.starts_with("scope_rex:"),
        ),
        (
            "sovereign_gate_bound",
            packet.sovereign_gate_ref.starts_with("sovereign_gate:"),
        ),
        (
            "compatibility_fence_bound",
            packet.compatibility_fence_ref.starts_with("compat:"),
        ),
        (
            "cancellation_bound",
            packet.cancellation_ref.starts_with("cancel:"),
        ),
        (
            "privacy_fence_bound",
            packet.privacy_ref.starts_with("privacy:"),
        ),
        (
            "budget_refs_bound",
            packet.budget_ref.starts_with("budget:"),
        ),
        (
            "required_phases_bound",
            metrics.phase_count == required_fresh_product_runtime_answer_packet_probe_phases().len() as u64,
        ),
        (
            "living_index_surface_scan_pass",
            witness
                .surfaces
                .iter()
                .any(|surface| surface.surface_id == "living_index"),
        ),
        (
            "lattice_html_surface_scan_pass",
            witness
                .surfaces
                .iter()
                .any(|surface| surface.surface_id == "lattice_html"),
        ),
        (
            "north_star_present",
            evidence
                .living_index
                .contains("Epistemos is a local cognitive substrate")
                && evidence
                    .lattice_html
                    .contains("Epistemos is a local cognitive substrate"),
        ),
        (
            "forbidden_runtime_claims_absent",
            !evidence
                .living_index
                .contains("small model runtime is product-live")
                && !evidence
                    .lattice_html
                    .contains("small model runtime is product-live")
                && !evidence.living_index.contains("live 70B is done")
                && !evidence.lattice_html.contains("live 70B is done"),
        ),
        ("l1_l2_l3_separation_bound", witness.l1_l2_l3_separated),
        (
            "mas_floor_preserved",
            witness.product_build == ProductBuild::Pro && !witness.mas_overclaim_attempted,
        ),
        ("no_l2_green_claim", !witness.l2_green_claimed),
        ("no_l3_green_claim", !witness.l3_green_claimed),
        (
            "no_hidden_route_authority",
            !packet.hidden_route_authority_attempted,
        ),
        (
            "no_route_policy_mutation",
            !packet.route_policy_mutation_attempted,
        ),
        ("no_gate_bypass", !packet.gate_bypass_attempted),
        (
            "no_answer_packet_suppression",
            !packet.answer_packet_suppressed,
        ),
        ("no_hidden_chain", !packet.hidden_chain_exposed),
        (
            "no_hidden_cloud_fallback",
            !packet.hidden_cloud_fallback_allowed,
        ),
        (
            "no_app_path_subprocess_spawn",
            !packet.subprocess_spawned_in_app_path,
        ),
        (
            "no_autogenous_kernel_attempt",
            !packet.autogenous_kernel_attempted,
        ),
        ("no_70b_probe_attempt", !packet.seventy_b_probe_attempted),
        (
            "no_long_context_shard_probe",
            !packet.long_context_shard_probe_attempted,
        ),
        ("no_mutation_committed", !packet.committed_mutation),
        (
            "upstream_runtime_bytes_loaded_nonzero",
            packet.upstream_runtime_bytes_loaded > 0,
        ),
        (
            "upstream_model_bytes_loaded_nonzero",
            packet.upstream_model_bytes_loaded > 0,
        ),
        (
            "no_new_runtime_bytes_loaded",
            packet.packetization_runtime_bytes_loaded == 0,
        ),
        (
            "no_new_model_bytes_loaded",
            packet.packetization_model_bytes_loaded == 0,
        ),
        (
            "metadata_bound",
            witness.metadata_bytes <= MAX_METADATA_BYTES,
        ),
        (
            "small_model_runtime_harness_fresh_product_runtime_answer_packet_probe_address_deterministic",
            deterministic,
        ),
        (
            "missing_fresh_live_artifact_rejected",
            invalid_axes.missing_fresh_live_artifact_rejected,
        ),
        (
            "missing_sidecar_rejected",
            invalid_axes.missing_sidecar_rejected,
        ),
        (
            "missing_answer_packet_rejected",
            invalid_axes.missing_answer_packet_rejected,
        ),
        (
            "missing_run_event_log_rejected",
            invalid_axes.missing_run_event_log_rejected,
        ),
        (
            "missing_run_event_log_root_rejected",
            invalid_axes.missing_run_event_log_root_rejected,
        ),
        (
            "missing_packet_json_rejected",
            invalid_axes.missing_packet_json_rejected,
        ),
        (
            "missing_witnessed_state_rejected",
            invalid_axes.missing_witnessed_state_rejected,
        ),
        (
            "missing_mutation_envelope_rejected",
            invalid_axes.missing_mutation_envelope_rejected,
        ),
        (
            "missing_semantic_delta_rejected",
            invalid_axes.missing_semantic_delta_rejected,
        ),
        (
            "missing_claim_rejected",
            invalid_axes.missing_claim_rejected,
        ),
        (
            "missing_code_invariant_claim_rejected",
            invalid_axes.missing_code_invariant_claim_rejected,
        ),
        (
            "inactive_claim_rejected",
            invalid_axes.inactive_claim_rejected,
        ),
        (
            "static_fallback_contradiction_rejected",
            invalid_axes.static_fallback_contradiction_rejected,
        ),
        (
            "verified_label_overclaim_rejected",
            invalid_axes.verified_label_overclaim_rejected,
        ),
        (
            "missing_residency_signal_rejected",
            invalid_axes.missing_residency_signal_rejected,
        ),
        (
            "non_neutral_residency_signal_rejected",
            invalid_axes.non_neutral_residency_signal_rejected,
        ),
        (
            "run_event_log_missing_stop_rejected",
            invalid_axes.run_event_log_missing_stop_rejected,
        ),
        (
            "run_event_log_error_rejected",
            invalid_axes.run_event_log_error_rejected,
        ),
        (
            "run_event_log_root_mismatch_rejected",
            invalid_axes.run_event_log_root_mismatch_rejected,
        ),
        (
            "redacted_final_text_missing_rejected",
            invalid_axes.redacted_final_text_missing_rejected,
        ),
        (
            "token_text_retained_rejected",
            invalid_axes.token_text_retained_rejected,
        ),
        (
            "prompt_user_data_rejected",
            invalid_axes.prompt_user_data_rejected,
        ),
        (
            "new_runtime_bytes_rejected",
            invalid_axes.new_runtime_bytes_rejected,
        ),
        (
            "new_model_bytes_rejected",
            invalid_axes.new_model_bytes_rejected,
        ),
        (
            "upstream_runtime_bytes_missing_rejected",
            invalid_axes.upstream_runtime_bytes_missing_rejected,
        ),
        (
            "upstream_model_bytes_missing_rejected",
            invalid_axes.upstream_model_bytes_missing_rejected,
        ),
        (
            "mutation_committed_rejected",
            invalid_axes.mutation_committed_rejected,
        ),
        (
            "route_policy_mutation_rejected",
            invalid_axes.route_policy_mutation_rejected,
        ),
        ("gate_bypass_rejected", invalid_axes.gate_bypass_rejected),
        (
            "answer_packet_suppression_rejected",
            invalid_axes.answer_packet_suppression_rejected,
        ),
        (
            "hidden_authority_rejected",
            invalid_axes.hidden_authority_rejected,
        ),
        ("hidden_chain_rejected", invalid_axes.hidden_chain_rejected),
        ("hidden_cloud_rejected", invalid_axes.hidden_cloud_rejected),
        (
            "app_path_subprocess_rejected",
            invalid_axes.app_path_subprocess_rejected,
        ),
        (
            "autogenous_kernel_rejected",
            invalid_axes.autogenous_kernel_rejected,
        ),
        (
            "seventy_b_probe_rejected",
            invalid_axes.seventy_b_probe_rejected,
        ),
        (
            "long_context_shard_probe_rejected",
            invalid_axes.long_context_shard_probe_rejected,
        ),
        (
            "mas_overclaim_rejected",
            invalid_axes.mas_overclaim_rejected,
        ),
        (
            "l2_green_claim_rejected",
            invalid_axes.l2_green_claim_rejected,
        ),
        (
            "l3_green_claim_rejected",
            invalid_axes.l3_green_claim_rejected,
        ),
        (
            "metadata_budget_rejected",
            invalid_axes.metadata_budget_rejected,
        ),
    ];
    for (axis, passed) in bool_axes {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            passed,
        );
    }

    let count_axes = [
        (
            "packet_count",
            metrics.packet_count,
            MIN_PACKET_COUNT,
            "count",
        ),
        ("surface_count", metrics.surface_count, 2, "count"),
        (
            "phase_count",
            metrics.phase_count,
            required_fresh_product_runtime_answer_packet_probe_phases().len() as u64,
            "count",
        ),
        ("claim_count", metrics.claim_count, MIN_CLAIM_COUNT, "count"),
        (
            "residency_signal_count",
            metrics.residency_signal_count,
            1,
            "count",
        ),
        (
            "run_event_log_entry_count",
            metrics.run_event_log_entry_count,
            MIN_LOG_ENTRY_COUNT,
            "count",
        ),
        (
            "run_event_log_stop_count",
            metrics.run_event_log_stop_count,
            1,
            "count",
        ),
        (
            "packetization_runtime_bytes_loaded",
            metrics.packetization_runtime_bytes_loaded,
            MAX_PACKETIZATION_BYTES,
            "bytes",
        ),
        (
            "packetization_model_bytes_loaded",
            metrics.packetization_model_bytes_loaded,
            MAX_PACKETIZATION_BYTES,
            "bytes",
        ),
    ];
    for (axis, value, threshold, unit) in count_axes {
        add_count_eq_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            value,
            threshold,
            unit,
        );
    }
    measurements.insert(
        "metadata_bytes".to_string(),
        Measurement {
            value: serde_json::json!(witness.metadata_bytes),
            unit: "bytes".to_string(),
        },
    );
    pass_per_axis.insert(
        "metadata_bytes".to_string(),
        witness.metadata_bytes <= MAX_METADATA_BYTES,
    );
    thresholds.insert(
        "metadata_bytes".to_string(),
        AcceptanceThreshold {
            operator: "<=".to_string(),
            value: serde_json::json!(MAX_METADATA_BYTES),
            unit: "bytes".to_string(),
        },
    );
    measurements.insert(
        "upstream_runtime_bytes_loaded".to_string(),
        Measurement {
            value: serde_json::json!(metrics.upstream_runtime_bytes_loaded),
            unit: "bytes".to_string(),
        },
    );
    pass_per_axis.insert(
        "upstream_runtime_bytes_loaded".to_string(),
        metrics.upstream_runtime_bytes_loaded > 0,
    );
    thresholds.insert(
        "upstream_runtime_bytes_loaded".to_string(),
        AcceptanceThreshold {
            operator: ">".to_string(),
            value: serde_json::json!(0),
            unit: "bytes".to_string(),
        },
    );
    measurements.insert(
        "upstream_model_bytes_loaded".to_string(),
        Measurement {
            value: serde_json::json!(metrics.upstream_model_bytes_loaded),
            unit: "bytes".to_string(),
        },
    );
    pass_per_axis.insert(
        "upstream_model_bytes_loaded".to_string(),
        metrics.upstream_model_bytes_loaded > 0,
    );
    thresholds.insert(
        "upstream_model_bytes_loaded".to_string(),
        AcceptanceThreshold {
            operator: ">".to_string(),
            value: serde_json::json!(0),
            unit: "bytes".to_string(),
        },
    );
    measurements.insert(
        "small_model_runtime_harness_fresh_product_runtime_answer_packet_probe_address".to_string(),
        Measurement {
            value: serde_json::json!(address),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "small_model_runtime_harness_fresh_product_runtime_answer_packet_probe_address".to_string(),
        deterministic,
    );
    thresholds.insert(
        "small_model_runtime_harness_fresh_product_runtime_answer_packet_probe_address".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: measurements
                .get(
                    "small_model_runtime_harness_fresh_product_runtime_answer_packet_probe_address",
                )
                .map(|measurement| measurement.value.clone())
                .unwrap_or_else(|| serde_json::json!("")),
            unit: "sha256".to_string(),
        },
    );
    measurements.insert(
        "next_cursor".to_string(),
        Measurement {
            value: serde_json::json!(
                SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_ANSWER_PACKET_PROBE_NEXT_CURSOR
            ),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert("next_cursor".to_string(), true);
    thresholds.insert(
        "next_cursor".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(
                SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_ANSWER_PACKET_PROBE_NEXT_CURSOR
            ),
            unit: "cursor".to_string(),
        },
    );

    let anomalies = vec![serde_json::json!({
        "kind": "small_model_answer_packet_l1_runtime_packetized_only",
        "detail": "The fresh product-runtime sidecar is packetized into a real Rust AnswerPacket and dense RunEventLog with redacted token text, no new runtime/model bytes, rollback, admission, privacy, budget, and L1/L2/L3 separation. This advances L1 only; L2 capability and L3 product WRV remain red."
    })];

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
        anomalies,
        notes: "L1 F-SmallModelRuntimeHarnessFreshProductRuntimeAnswerPacketProbe: packetizes the Qwen3-4B fresh product-runtime sidecar through real AnswerPacket + RunEventLog proof only; no new inference, no new model bytes, no MAS/product route, no 70B, no 128K shard, no hidden cloud, and no L2/L3 promotion."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn fixture_witness(
    evidence: &EvidenceSnapshot,
) -> Result<
    (
        SmallModelFreshProductRuntimeAnswerPacketProbeWitness,
        Vec<u8>,
        Vec<u8>,
    ),
    AnswerPacketWitnessError,
> {
    let token_digest_ref = format!(
        "token_sha256:{}",
        evidence
            .live_probe
            .first_token_sha256
            .trim_start_matches("sha256:")
    );
    let mut answer_packet = produce_turn_completion_packet(TurnCompletionInputs {
        packet_id: "answer_packet:qwen3_4b:fresh-product-runtime:packetized".to_string(),
        stop_reason: "end_turn".to_string(),
        output_tokens: 1,
        attention_mode: AttentionMode::Dynamic,
        vrm_label: VrmLabel::PlausibleButUnverified,
        witnessed_state_id: "witnessed_state:fresh_product_runtime:qwen3_4b:packetized".to_string(),
        mutation_envelope_id: "mutation_envelope:no_mutation:qwen3_4b:packetized".to_string(),
        created_at_ms: CREATED_AT_MS,
    })
    .with_semantic_delta(SemanticDeltaId::new(format!(
        "semantic_delta:redacted_first_token:qwen3_4b:{}",
        token_digest_ref.trim_start_matches("token_sha256:")
    )))
    .push_claim(
        Claim::new(
            ClaimId::new("qwen3_4b_fresh_product_runtime_packetized_code_invariant"),
            "raw token text is redacted; retained evidence is token hash plus bounded sidecar metadata",
            CREATED_AT_MS,
        )
        .with_kind(ClaimKind::CodeInvariant),
    );
    answer_packet.residency_signals.truncate(1);

    let answer_packet_bytes = serde_json::to_vec(&answer_packet).map_err(|error| {
        AnswerPacketWitnessError::Json(format!("failed to encode AnswerPacket: {error}"))
    })?;
    let packet_sha = agent_core::falsifier_artifacts::sha256_hex(&answer_packet_bytes);
    let run_event_log = redacted_fresh_product_runtime_run_event_log(&token_digest_ref);
    let run_event_log_bytes = serde_json::to_vec(&run_event_log).map_err(|error| {
        AnswerPacketWitnessError::Json(format!("failed to encode RunEventLog: {error}"))
    })?;
    let packet = SmallModelFreshProductRuntimeAnswerPacketPacket::new(
        "small_model_fresh_product_runtime_answer_packet_probe_packet",
        "artifact:small_model_runtime_harness_fresh_product_runtime_live_probe:result",
        format!("artifact:small_model_runtime_harness_fresh_product_runtime_live_probe:live_probe:{packet_sha}"),
        answer_packet.id.0.clone(),
        "run_event_log:qwen3_4b:fresh-product-runtime-answer-packet",
        format!("run_event_log_root:{}", run_event_log.root_hash().to_hex()),
        format!("answer_packet_json:{packet_sha}"),
        answer_packet.witnessed_state_ref.0.clone(),
        answer_packet.mutation_envelope_ref.0.clone(),
        answer_packet
            .semantic_delta_ref
            .as_ref()
            .ok_or_else(|| {
                AnswerPacketWitnessError::Json("missing semantic delta after build".to_string())
            })?
            .0
            .clone(),
        "rollback:qwen3_4b:no-mutation-packetization",
        "admission:qwen3_4b:answer-packet-runtime-probe",
        "scope_rex:qwen3_4b:fresh-product-runtime-answer-packet",
        "sovereign_gate:qwen3_4b:research-candidate",
        "compat:qwen3_4b:mlx-small-answer-packet-v1",
        "cancel:qwen3_4b:packetization-only",
        "privacy:qwen3_4b:local-only-redacted-token",
        "budget:qwen3_4b:packetization-zero-runtime-bytes",
        token_digest_ref,
        required_fresh_product_runtime_answer_packet_probe_phases().to_vec(),
        answer_packet,
        run_event_log,
        packet_sha,
        evidence.live_probe.fresh_product_runtime_bytes_loaded,
        evidence.live_probe.fresh_product_model_bytes_loaded,
    )?;
    let witness = SmallModelFreshProductRuntimeAnswerPacketProbeWitness::new(
        "small-model-fresh-product-runtime-answer-packet-probe",
        "artifact:small_model_runtime_harness_fresh_product_runtime_live_probe:result",
        evidence.guard_next_existing_work.clone(),
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::Gated,
        "fresh_product_runtime_packetized_visible_proof_only",
        vec![packet],
        vec![
            surface(
                "living_index",
                LIVING_INDEX_PATH,
                evidence.living_index.clone(),
                vec![
                    "Epistemos is a local cognitive substrate".to_string(),
                    "small_model_runtime_harness_fresh_product_runtime_answer_packet_probe"
                        .to_string(),
                    "AnswerPacket".to_string(),
                    "RunEventLog".to_string(),
                ],
            )?,
            surface(
                "lattice_html",
                LATTICE_HTML_PATH,
                evidence.lattice_html.clone(),
                vec![
                    "Epistemos is a local cognitive substrate".to_string(),
                    "small_model_runtime_harness_fresh_product_runtime_answer_packet_probe"
                        .to_string(),
                    "F-SmallModelRuntimeHarnessFreshProductRuntimeLiveProbe".to_string(),
                ],
            )?,
        ],
        u64::try_from(answer_packet_bytes.len() + run_event_log_bytes.len()).unwrap_or(u64::MAX),
        true,
        false,
        false,
        false,
    )?;
    Ok((witness, answer_packet_bytes, run_event_log_bytes))
}

fn surface(
    surface_id: &str,
    path: &str,
    observed_text: String,
    required_markers: Vec<String>,
) -> Result<SmallModelFreshProductRuntimeAnswerPacketSurface, AnswerPacketWitnessError> {
    Ok(SmallModelFreshProductRuntimeAnswerPacketSurface::new(
        surface_id,
        path,
        observed_text,
        required_markers,
        vec![
            "small model runtime is product-live".to_string(),
            "live 70B is done".to_string(),
            "fresh product-runtime packetization makes L2 green".to_string(),
            "raw first token retained".to_string(),
            "hidden cloud fallback is allowed".to_string(),
        ],
    )?)
}

#[derive(Clone)]
// UAS: Aggregates upstream fresh live-probe and canon evidence for the AnswerPacket packetization probe.
// Plane: Verification.
// Residency: Reads fresh product-runtime sidecars and docs only; no new model/runtime bytes are opened.
struct EvidenceSnapshot {
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
    fresh_live_pass: bool,
    live_probe: LiveProbeSidecar,
    living_index: String,
    lattice_html: String,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, AnswerPacketWitnessError> {
        let guard = read_json(Path::new(GUARD_PATH))?;
        let capability = read_json(Path::new(CAPABILITY_PATH))?;
        let fresh_live = read_json(Path::new(FRESH_LIVE_PROBE_PATH))?;
        Ok(Self {
            guard_next_existing_work: measurement_string(&guard, "next_existing_work")
                .unwrap_or_else(|| "unset".to_string()),
            capability_overall_pass: capability
                .get("overall_pass")
                .and_then(serde_json::Value::as_bool)
                .unwrap_or(false),
            capability_route_status: measurement_string(&capability, "route_status")
                .unwrap_or_else(|| "unset".to_string()),
            capability_next_bottleneck: measurement_string(&capability, "next_bottleneck")
                .unwrap_or_else(|| "unset".to_string()),
            fresh_live_pass: artifact_all_axes_true(
                &fresh_live,
                SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_AXES,
            ),
            live_probe: read_sidecar(Path::new(LIVE_PROBE_PATH))?,
            living_index: read_text(Path::new(LIVING_INDEX_PATH))?,
            lattice_html: read_text(Path::new(LATTICE_HTML_PATH))?,
        })
    }
}

#[derive(Clone, Debug)]
// UAS: Fresh redacted sidecar schema consumed by the AnswerPacket runtime probe.
// Plane: Verification.
// Residency: CurrentApp fresh product-runtime bytes are inherited as evidence, not reloaded.
struct LiveProbeSidecar {
    prompt_sha256: String,
    prompt_contains_user_data: bool,
    first_token_observed: bool,
    output_token_count: u32,
    first_token_sha256: String,
    raw_token_text_retained: Option<bool>,
    first_token_preview: Option<String>,
    fresh_product_model_bytes_loaded: u64,
    fresh_product_runtime_bytes_loaded: u64,
}

fn read_sidecar(path: &Path) -> Result<LiveProbeSidecar, AnswerPacketWitnessError> {
    let value = read_json(path)?;
    Ok(LiveProbeSidecar {
        prompt_sha256: json_string(&value, "prompt_sha256")?,
        prompt_contains_user_data: json_bool(&value, "prompt_contains_user_data")?,
        first_token_observed: json_bool(&value, "first_token_observed")?,
        output_token_count: json_u64(&value, "output_token_count")? as u32,
        first_token_sha256: json_string(&value, "first_token_sha256")?,
        raw_token_text_retained: value
            .get("raw_token_text_retained")
            .and_then(serde_json::Value::as_bool),
        first_token_preview: value
            .get("first_token_preview")
            .and_then(serde_json::Value::as_str)
            .map(ToOwned::to_owned),
        fresh_product_model_bytes_loaded: json_u64(&value, "fresh_product_model_bytes_loaded")?,
        fresh_product_runtime_bytes_loaded: json_u64(&value, "fresh_product_runtime_bytes_loaded")?,
    })
}

#[derive(Default)]
// UAS: Negative-fixture ledger proving malformed fresh product-runtime packet evidence rejects.
// Plane: Verification.
// Residency: Validator-only fixtures; no runtime/model bytes are loaded.
struct InvalidAxes {
    missing_fresh_live_artifact_rejected: bool,
    missing_sidecar_rejected: bool,
    missing_answer_packet_rejected: bool,
    missing_run_event_log_rejected: bool,
    missing_run_event_log_root_rejected: bool,
    missing_packet_json_rejected: bool,
    missing_witnessed_state_rejected: bool,
    missing_mutation_envelope_rejected: bool,
    missing_semantic_delta_rejected: bool,
    missing_claim_rejected: bool,
    missing_code_invariant_claim_rejected: bool,
    inactive_claim_rejected: bool,
    static_fallback_contradiction_rejected: bool,
    verified_label_overclaim_rejected: bool,
    missing_residency_signal_rejected: bool,
    non_neutral_residency_signal_rejected: bool,
    run_event_log_missing_stop_rejected: bool,
    run_event_log_error_rejected: bool,
    run_event_log_root_mismatch_rejected: bool,
    redacted_final_text_missing_rejected: bool,
    token_text_retained_rejected: bool,
    prompt_user_data_rejected: bool,
    new_runtime_bytes_rejected: bool,
    new_model_bytes_rejected: bool,
    upstream_runtime_bytes_missing_rejected: bool,
    upstream_model_bytes_missing_rejected: bool,
    mutation_committed_rejected: bool,
    route_policy_mutation_rejected: bool,
    gate_bypass_rejected: bool,
    answer_packet_suppression_rejected: bool,
    hidden_authority_rejected: bool,
    hidden_chain_rejected: bool,
    hidden_cloud_rejected: bool,
    app_path_subprocess_rejected: bool,
    autogenous_kernel_rejected: bool,
    seventy_b_probe_rejected: bool,
    long_context_shard_probe_rejected: bool,
    mas_overclaim_rejected: bool,
    l2_green_claim_rejected: bool,
    l3_green_claim_rejected: bool,
    metadata_budget_rejected: bool,
}

fn invalid_fixture_axes(
    evidence: &EvidenceSnapshot,
) -> Result<InvalidAxes, AnswerPacketWitnessError> {
    let (witness, _, _) = fixture_witness(evidence)?;
    let mutate_packet = |mutator: fn(&mut SmallModelFreshProductRuntimeAnswerPacketPacket)| {
        let mut packet = witness.packets[0].clone();
        mutator(&mut packet);
        packet.validate().is_err()
    };
    let mutate_witness =
        |mutator: fn(&mut SmallModelFreshProductRuntimeAnswerPacketProbeWitness)| {
            let mut candidate = witness.clone();
            mutator(&mut candidate);
            candidate.validate().is_err()
        };
    Ok(InvalidAxes {
        missing_fresh_live_artifact_rejected: mutate_packet(|packet| {
            packet.fresh_live_artifact_ref.clear();
        }),
        missing_sidecar_rejected: mutate_packet(|packet| {
            packet.live_probe_sidecar_ref.clear();
        }),
        missing_answer_packet_rejected: mutate_packet(|packet| {
            packet.answer_packet_ref.clear();
        }),
        missing_run_event_log_rejected: mutate_packet(|packet| {
            packet.run_event_log_ref.clear();
        }),
        missing_run_event_log_root_rejected: mutate_packet(|packet| {
            packet.run_event_log_root_ref.clear();
        }),
        missing_packet_json_rejected: mutate_packet(|packet| {
            packet.packet_json_ref.clear();
        }),
        missing_witnessed_state_rejected: mutate_packet(|packet| {
            packet.witnessed_state_ref.clear();
        }),
        missing_mutation_envelope_rejected: mutate_packet(|packet| {
            packet.mutation_envelope_ref.clear();
        }),
        missing_semantic_delta_rejected: mutate_packet(|packet| {
            packet.semantic_delta_ref.clear();
        }),
        missing_claim_rejected: mutate_packet(|packet| {
            packet.answer_packet.claims.clear();
            packet.packet_json_sha256 = "sha256:stale".to_string();
        }),
        missing_code_invariant_claim_rejected: mutate_packet(|packet| {
            packet
                .answer_packet
                .claims
                .retain(|claim| claim.kind != ClaimKind::CodeInvariant);
            packet.packet_json_sha256 = "sha256:stale".to_string();
        }),
        inactive_claim_rejected: mutate_packet(|packet| {
            if let Some(claim) = packet.answer_packet.claims.first_mut() {
                claim.status = agent_core::provenance::ledger::ClaimStatus::Retracted;
            }
            packet.packet_json_sha256 = "sha256:stale".to_string();
        }),
        static_fallback_contradiction_rejected: mutate_packet(|packet| {
            packet.answer_packet = packet.answer_packet.clone().push_claim(
                Claim::new(
                    ClaimId::new("bad-static-fallback"),
                    "static fallback acknowledged despite dynamic attention",
                    CREATED_AT_MS,
                )
                .with_kind(ClaimKind::StaticFallbackAcknowledged),
            );
            packet.packet_json_sha256 = "sha256:stale".to_string();
        }),
        verified_label_overclaim_rejected: mutate_packet(|packet| {
            packet.answer_packet.ui_label = VrmLabel::Verified;
            packet.packet_json_sha256 = "sha256:stale".to_string();
        }),
        missing_residency_signal_rejected: mutate_packet(|packet| {
            packet.answer_packet.residency_signals.clear();
            packet.packet_json_sha256 = "sha256:stale".to_string();
        }),
        non_neutral_residency_signal_rejected: mutate_packet(|packet| {
            if let Some(signal) = packet.answer_packet.residency_signals.first_mut() {
                signal.privacy = 1.0;
            }
            packet.packet_json_sha256 = "sha256:stale".to_string();
        }),
        run_event_log_missing_stop_rejected: mutate_packet(|packet| {
            let mut log = agent_core::agent_runtime_v2::run_event_log::RunEventLog::new();
            log.append_event(agent_core::agent_runtime_v2::event::AgentEvent::FinalText {
                text: format!("[redacted-first-token:{}]", packet.token_digest_ref),
            });
            packet.run_event_log = log;
            packet.run_event_log_root_ref = format!(
                "run_event_log_root:{}",
                packet.run_event_log.root_hash().to_hex()
            );
        }),
        run_event_log_error_rejected: mutate_packet(|packet| {
            let mut log = redacted_fresh_product_runtime_run_event_log(&packet.token_digest_ref);
            log.append_event(agent_core::agent_runtime_v2::event::AgentEvent::error(
                agent_core::agent_runtime_v2::event::AgentEventErrorKind::Provider,
                "provider error",
            ));
            packet.run_event_log = log;
            packet.run_event_log_root_ref = format!(
                "run_event_log_root:{}",
                packet.run_event_log.root_hash().to_hex()
            );
        }),
        run_event_log_root_mismatch_rejected: mutate_packet(|packet| {
            packet.run_event_log_root_ref = "run_event_log_root:stale".to_string();
        }),
        redacted_final_text_missing_rejected: mutate_packet(|packet| {
            let mut log = agent_core::agent_runtime_v2::run_event_log::RunEventLog::new();
            log.append_event(agent_core::agent_runtime_v2::event::AgentEvent::FinalText {
                text: "[redacted-first-token:missing]".to_string(),
            });
            log.append_event(agent_core::agent_runtime_v2::event::AgentEvent::Stop {
                reason: agent_core::agent_runtime_v2::StopReason::EndTurn,
            });
            packet.run_event_log = log;
            packet.run_event_log_root_ref = format!(
                "run_event_log_root:{}",
                packet.run_event_log.root_hash().to_hex()
            );
        }),
        token_text_retained_rejected: mutate_packet(|packet| {
            packet.raw_token_text_retained = true;
        }),
        prompt_user_data_rejected: mutate_packet(|packet| {
            packet.prompt_contains_user_data = true;
        }),
        new_runtime_bytes_rejected: mutate_packet(|packet| {
            packet.packetization_runtime_bytes_loaded = 1;
        }),
        new_model_bytes_rejected: mutate_packet(|packet| {
            packet.packetization_model_bytes_loaded = 1;
        }),
        upstream_runtime_bytes_missing_rejected: mutate_packet(|packet| {
            packet.upstream_runtime_bytes_loaded = 0;
        }),
        upstream_model_bytes_missing_rejected: mutate_packet(|packet| {
            packet.upstream_model_bytes_loaded = 0;
        }),
        mutation_committed_rejected: mutate_packet(|packet| {
            packet.committed_mutation = true;
        }),
        route_policy_mutation_rejected: mutate_packet(|packet| {
            packet.route_policy_mutation_attempted = true;
        }),
        gate_bypass_rejected: mutate_packet(|packet| {
            packet.gate_bypass_attempted = true;
        }),
        answer_packet_suppression_rejected: mutate_packet(|packet| {
            packet.answer_packet_suppressed = true;
        }),
        hidden_authority_rejected: mutate_packet(|packet| {
            packet.hidden_route_authority_attempted = true;
        }),
        hidden_chain_rejected: mutate_packet(|packet| {
            packet.hidden_chain_exposed = true;
        }),
        hidden_cloud_rejected: mutate_packet(|packet| {
            packet.hidden_cloud_fallback_allowed = true;
        }),
        app_path_subprocess_rejected: mutate_packet(|packet| {
            packet.subprocess_spawned_in_app_path = true;
        }),
        autogenous_kernel_rejected: mutate_packet(|packet| {
            packet.autogenous_kernel_attempted = true;
        }),
        seventy_b_probe_rejected: mutate_packet(|packet| {
            packet.seventy_b_probe_attempted = true;
        }),
        long_context_shard_probe_rejected: mutate_packet(|packet| {
            packet.long_context_shard_probe_attempted = true;
        }),
        mas_overclaim_rejected: mutate_witness(|candidate| {
            candidate.mas_overclaim_attempted = true;
        }),
        l2_green_claim_rejected: mutate_witness(|candidate| {
            candidate.l2_green_claimed = true;
        }),
        l3_green_claim_rejected: mutate_witness(|candidate| {
            candidate.l3_green_claimed = true;
        }),
        metadata_budget_rejected: mutate_witness(|candidate| {
            candidate.metadata_bytes = MAX_METADATA_BYTES + 1;
        }),
    })
}

fn write_sidecar(path: &Path, bytes: &[u8]) -> Result<(), AnswerPacketWitnessError> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|error| {
            AnswerPacketWitnessError::Io(format!("failed to create sidecar dir: {error}"))
        })?;
    }
    std::fs::write(path, bytes)
        .map_err(|error| AnswerPacketWitnessError::Io(format!("failed to write sidecar: {error}")))
}

fn artifact_all_axes_true(value: &serde_json::Value, axes: &[&str]) -> bool {
    value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        == Some(true)
        && axes.iter().all(|axis| {
            value
                .get("pass_per_axis")
                .and_then(|axes| axes.get(*axis))
                .and_then(serde_json::Value::as_bool)
                == Some(true)
        })
}

fn measurement_string(value: &serde_json::Value, key: &str) -> Option<String> {
    value
        .get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(serde_json::Value::as_str)
        .map(ToOwned::to_owned)
}

fn read_json(path: &Path) -> Result<serde_json::Value, AnswerPacketWitnessError> {
    let text = read_text(path)?;
    serde_json::from_str(&text).map_err(|error| {
        AnswerPacketWitnessError::Json(format!("failed to parse {}: {error}", path.display()))
    })
}

fn read_text(path: &Path) -> Result<String, AnswerPacketWitnessError> {
    std::fs::read_to_string(path).map_err(|error| {
        AnswerPacketWitnessError::Io(format!("failed to read {}: {error}", path.display()))
    })
}

fn json_string(
    value: &serde_json::Value,
    key: &'static str,
) -> Result<String, AnswerPacketWitnessError> {
    value
        .get(key)
        .and_then(serde_json::Value::as_str)
        .map(ToOwned::to_owned)
        .ok_or_else(|| AnswerPacketWitnessError::Json(format!("missing string field `{key}`")))
}

fn json_bool(
    value: &serde_json::Value,
    key: &'static str,
) -> Result<bool, AnswerPacketWitnessError> {
    value
        .get(key)
        .and_then(serde_json::Value::as_bool)
        .ok_or_else(|| AnswerPacketWitnessError::Json(format!("missing bool field `{key}`")))
}

fn json_u64(value: &serde_json::Value, key: &'static str) -> Result<u64, AnswerPacketWitnessError> {
    value
        .get(key)
        .and_then(serde_json::Value::as_u64)
        .ok_or_else(|| AnswerPacketWitnessError::Json(format!("missing u64 field `{key}`")))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn declared_axes_have_no_duplicates() {
        let mut seen = std::collections::BTreeSet::new();
        for axis in SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_ANSWER_PACKET_PROBE_AXES {
            assert!(seen.insert(*axis), "duplicate axis {axis}");
        }
    }
}
