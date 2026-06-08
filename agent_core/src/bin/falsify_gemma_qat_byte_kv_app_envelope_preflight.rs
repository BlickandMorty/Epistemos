//! `falsify_gemma_qat_byte_kv_app_envelope_preflight`
//!
//! Metadata-only witness for `F-GemmaQATByteKVAppEnvelopePreflight`. It binds
//! Gemma 4 E2B/E4B QAT selected bytes, KV cache floors, runtime workspace, app
//! headroom, cancellation, rollback, RunEventLog, AnswerPacket, abstention, and
//! SovereignGate refs before any owner path, local file, command, runtime, or
//! first-token probe can run.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_QAT_BYTE_KV_APP_ENVELOPE_PREFLIGHT_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    canonical_gemma_qat_byte_kv_app_envelope_cards, GemmaQatByteKvAppEnvelopeCard,
    GemmaQatByteKvAppEnvelopeLedger, GEMMA_QAT_BYTE_KV_APP_ENVELOPE_PREFLIGHT_ID,
    GEMMA_QAT_BYTE_KV_APP_ENVELOPE_PREFLIGHT_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = GEMMA_QAT_BYTE_KV_APP_ENVELOPE_PREFLIGHT_ID;
const FIXTURE_ID: &str = "gemma_qat_byte_kv_app_envelope_preflight_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_qat_byte_kv_app_envelope_preflight.sh";
const RESULT: &str = "artifacts/falsifiers/gemma_qat_byte_kv_app_envelope_preflight/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_qat_small_lane_owner_path_manifest/result.json";
const UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_qat_small_lane_owner_path_manifest/result.json#F-GemmaQATSmallLaneOwnerPathManifest";
const CREATED_AT_MS: u64 = 1_779_212_000_000;
const LEDGER_METADATA_BYTES: u64 = 84_000;

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
        "{FALSIFIER_ID}: overall_pass={} card_count={} selected_artifact_bytes_total={} planned_total_envelope_bytes={} model_bytes_loaded_total={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["envelope_card_count"].value,
        artifact.measurements["selected_artifact_bytes_total"].value,
        artifact.measurements["planned_total_envelope_bytes"].value,
        artifact.measurements["model_bytes_loaded_total"].value,
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
    let (upstream_pass, upstream_address) = upstream_manifest()?;
    let cards = canonical_gemma_qat_byte_kv_app_envelope_cards(UPSTREAM_REF);
    let ledger = build_ledger(upstream_address.clone(), cards.clone())?;
    let reversed = build_ledger(upstream_address, cards.iter().cloned().rev().collect())?;
    let metrics = ledger.metrics();
    let red_results = red_fixture_results(&cards);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_gemma_manifest_pass", upstream_pass),
        (
            "accepted_e2b_e4b_envelope_pack_present",
            has_card(&cards, "gemma4_e2b_qat_byte_kv_app_envelope")
                && has_card(&cards, "gemma4_e4b_qat_byte_kv_app_envelope"),
        ),
        (
            "only_e2b_e4b_small_lanes_allowed",
            metrics.card_count == 2
                && cards
                    .iter()
                    .all(|card| card.model_id.contains("E2B") || card.model_id.contains("E4B"))
                && red_pass(&red_results, "twelve_b_inserted")
                && red_pass(&red_results, "duplicate_model_id"),
        ),
        (
            "selected_artifact_bytes_bound",
            metrics.selected_artifact_bytes_total == 12_091_583_309
                && red_pass(&red_results, "bad_selected_bytes")
                && red_pass(&red_results, "selected_bytes_resident_claim"),
        ),
        (
            "kv_runtime_app_headroom_bound",
            metrics.kv_cache_floor_bytes_total == 1_342_177_280
                && metrics.runtime_workspace_bytes_total == 1_879_048_192
                && metrics.app_headroom_bytes_total == 8_589_934_592
                && red_pass(&red_results, "missing_kv_cache_floor")
                && red_pass(&red_results, "missing_runtime_workspace")
                && red_pass(&red_results, "missing_app_headroom"),
        ),
        (
            "total_envelope_recomputed",
            metrics.planned_total_envelope_bytes == 24_104_069_965
                && red_pass(&red_results, "total_envelope_mismatch"),
        ),
        (
            "m2pro_candidate_not_fit_claim",
            metrics.probe_candidate_count == 2
                && metrics.tight_candidate_count == 1
                && red_pass(&red_results, "e4b_missing_fresh_memory_sample")
                && red_pass(&red_results, "m2pro_fit_claim_missing_caveat"),
        ),
        (
            "owner_approval_and_redacted_probe_required",
            ledger.owner_approval_required
                && ledger.redacted_first_token_probe_required
                && metrics.owner_approval_granted_count == 0
                && metrics.first_token_claim_count == 0
                && metrics.first_token_attempts_total == 0
                && red_pass(&red_results, "owner_approval_granted")
                && red_pass(&red_results, "first_token_claimed")
                && red_pass(&red_results, "first_token_attempted"),
        ),
        (
            "proof_surfaces_bound",
            cards.iter().all(|card| {
                card.proof_refs
                    .upstream_manifest_ref
                    .starts_with("artifact:")
                    && card
                        .proof_refs
                        .byte_envelope_ref
                        .starts_with("byte_envelope:")
                    && card.proof_refs.kv_cache_ref.starts_with("kv_cache_floor:")
                    && card
                        .proof_refs
                        .runtime_workspace_ref
                        .starts_with("runtime_workspace:")
                    && card
                        .proof_refs
                        .app_headroom_ref
                        .starts_with("app_headroom:")
                    && card
                        .proof_refs
                        .cancellation_ref
                        .starts_with("cancellation:")
                    && card.proof_refs.rollback_ref.starts_with("rollback:")
                    && card
                        .proof_refs
                        .run_event_log_ref
                        .starts_with("run_event_log:")
                    && card
                        .proof_refs
                        .answer_packet_ref
                        .starts_with("answer_packet:")
                    && card.proof_refs.abstention_ref.starts_with("abstention:")
                    && card
                        .proof_refs
                        .sovereign_gate_ref
                        .starts_with("sovereign_gate:")
                    && card
                        .proof_refs
                        .compatibility_fence_ref
                        .starts_with("compat:")
            }) && red_pass(&red_results, "bad_proof_ref"),
        ),
        (
            "file_path_command_runtime_blocked",
            metrics.owner_manifest_present_count == 0
                && metrics.local_artifact_verified_count == 0
                && metrics.path_canonicalization_allowed_count == 0
                && metrics.file_access_allowed_count == 0
                && metrics.file_hash_allowed_count == 0
                && metrics.command_envelope_armed_count == 0
                && metrics.runtime_probe_allowed_count == 0
                && red_pass(&red_results, "owner_manifest_present")
                && red_pass(&red_results, "local_artifact_verified")
                && red_pass(&red_results, "path_canonicalization_allowed")
                && red_pass(&red_results, "file_access_allowed")
                && red_pass(&red_results, "file_hash_attempted")
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "runtime_probe_allowed"),
        ),
        (
            "zero_model_runtime_provider_benchmark_bytes",
            metrics.owner_manifest_bytes_read_total == 0
                && metrics.owner_path_bytes_read_total == 0
                && metrics.local_file_bytes_read_total == 0
                && metrics.selected_artifact_bytes_resident_total == 0
                && metrics.kv_cache_bytes_allocated_total == 0
                && metrics.runtime_workspace_bytes_allocated_total == 0
                && metrics.app_memory_bytes_reserved_total == 0
                && metrics.command_execution_count_total == 0
                && metrics.model_bytes_loaded_total == 0
                && metrics.runtime_bytes_loaded_total == 0
                && metrics.provider_calls_made_total == 0
                && metrics.benchmark_runs_total == 0
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "benchmark_run"),
        ),
        (
            "no_route_mutation_or_hidden_authority",
            metrics.route_mutation_allowed_count == 0
                && metrics.hidden_cloud_fallback_count == 0
                && metrics.hidden_route_authority_count == 0
                && red_pass(&red_results, "route_mutation_allowed")
                && red_pass(&red_results, "hidden_route_authority"),
        ),
        (
            "no_mas_l2_l3_product_or_70b_claim",
            metrics.mas_promotion_count == 0
                && metrics.l2_green_claim_count == 0
                && metrics.l3_green_claim_count == 0
                && metrics.product_capability_claim_count == 0
                && metrics.live_dense_70b_claim_count == 0
                && metrics.ssd_as_ram_claim_count == 0
                && red_pass(&red_results, "mas_l2_l3_product_claim")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "envelope_ledger_address_deterministic",
            ledger.ledger_address == reversed.ledger_address,
        ),
        (
            "next_cursor_bound",
            GEMMA_QAT_BYTE_KV_APP_ENVELOPE_PREFLIGHT_NEXT_CURSOR
                == "gemma_qat_redacted_first_token_probe",
        ),
    ] {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            passed,
        );
    }

    for (name, value, operator, expected, unit) in [
        ("envelope_card_count", metrics.card_count, "==", 2, "cards"),
        ("gguf_lane_count", metrics.gguf_lane_count, "==", 2, "lanes"),
        (
            "litert_lane_count",
            metrics.litert_lane_count,
            "==",
            2,
            "lanes",
        ),
        (
            "selected_artifact_bytes_total",
            metrics.selected_artifact_bytes_total,
            "==",
            12_091_583_309,
            "bytes",
        ),
        (
            "kv_cache_floor_bytes_total",
            metrics.kv_cache_floor_bytes_total,
            "==",
            1_342_177_280,
            "bytes",
        ),
        (
            "runtime_workspace_bytes_total",
            metrics.runtime_workspace_bytes_total,
            "==",
            1_879_048_192,
            "bytes",
        ),
        (
            "app_headroom_bytes_total",
            metrics.app_headroom_bytes_total,
            "==",
            8_589_934_592,
            "bytes",
        ),
        (
            "planned_total_envelope_bytes",
            metrics.planned_total_envelope_bytes,
            "==",
            24_104_069_965,
            "bytes",
        ),
        (
            "probe_candidate_count",
            metrics.probe_candidate_count,
            "==",
            2,
            "cards",
        ),
        (
            "tight_candidate_count",
            metrics.tight_candidate_count,
            "==",
            1,
            "cards",
        ),
        (
            "owner_manifest_bytes_read_total",
            metrics.owner_manifest_bytes_read_total,
            "==",
            0,
            "bytes",
        ),
        (
            "local_file_bytes_read_total",
            metrics.local_file_bytes_read_total,
            "==",
            0,
            "bytes",
        ),
        (
            "command_execution_count_total",
            metrics.command_execution_count_total,
            "==",
            0,
            "commands",
        ),
        (
            "model_bytes_loaded_total",
            metrics.model_bytes_loaded_total,
            "==",
            0,
            "bytes",
        ),
        (
            "runtime_bytes_loaded_total",
            metrics.runtime_bytes_loaded_total,
            "==",
            0,
            "bytes",
        ),
        (
            "provider_calls_made_total",
            metrics.provider_calls_made_total,
            "==",
            0,
            "calls",
        ),
        (
            "first_token_attempts_total",
            metrics.first_token_attempts_total,
            "==",
            0,
            "attempts",
        ),
        (
            "metadata_bytes_read_total",
            metrics.metadata_bytes_read_total,
            "<=",
            320 * 1024,
            "bytes",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            ">=",
            31,
            "fixtures",
        ),
    ] {
        add_u64_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            value,
            operator,
            expected,
            unit,
        );
    }

    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "gemma_byte_kv_app_envelope_address",
        &ledger.ledger_address.to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_QAT_BYTE_KV_APP_ENVELOPE_PREFLIGHT_NEXT_CURSOR,
        "gemma_qat_redacted_first_token_probe",
    );

    assert_axis_coverage(&measurements);

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
        notes: "metadata-only F-GemmaQATByteKVAppEnvelopePreflight: binds Gemma 4 E2B/E4B QAT selected artifact bytes, KV cache floors, runtime workspace, app headroom, fresh-memory-sample caveats, cancellation, rollback, RunEventLog, AnswerPacket, abstention, SovereignGate, and the next redacted first-token probe while opening zero paths/files, arming zero commands, loading zero model/runtime/provider bytes, allocating zero KV/workspace bytes, and making no MAS/L2/L3/user-facing or 70B live claim. It does not prove local artifact availability, path safety, first token, quality, Swift MLX loader support, LiteRT embedding, or Gemma as the live default app model.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_manifest() -> Result<(bool, String), Box<dyn std::error::Error>> {
    if !Path::new(UPSTREAM_RESULT).exists() {
        return Ok((false, "missing-upstream-manifest-address".to_string()));
    }
    let value: serde_json::Value = serde_json::from_slice(&std::fs::read(UPSTREAM_RESULT)?)?;
    let pass = value
        .get("overall_pass")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);
    let address = value
        .pointer("/measurements/gemma_small_lane_manifest_address/value")
        .and_then(|v| v.as_str())
        .unwrap_or("missing-upstream-manifest-address")
        .to_string();
    Ok((pass, address))
}

fn build_ledger(
    upstream_manifest_address: String,
    cards: Vec<GemmaQatByteKvAppEnvelopeCard>,
) -> Result<GemmaQatByteKvAppEnvelopeLedger, agent_core::uas::GemmaQatByteKvAppEnvelopeError> {
    GemmaQatByteKvAppEnvelopeLedger::new(
        upstream_manifest_address,
        UPSTREAM_REF,
        cards,
        LEDGER_METADATA_BYTES,
        CREATED_AT_MS,
    )
}

fn has_card(cards: &[GemmaQatByteKvAppEnvelopeCard], id: &str) -> bool {
    cards.iter().any(|card| card.card_id == id)
}

fn red_fixture_results(cards: &[GemmaQatByteKvAppEnvelopeCard]) -> Vec<(&'static str, bool)> {
    vec![
        (
            "twelve_b_inserted",
            reject_first(cards, |card| {
                card.model_id = "google/gemma-4-12B-it-qat-q4_0-gguf".to_string()
            }),
        ),
        (
            "duplicate_model_id",
            reject_set(cards, |bad| bad[1].model_id = bad[0].model_id.clone()),
        ),
        (
            "bad_selected_bytes",
            reject_first(cards, |card| card.byte_plan.selected_artifact_bytes = 1),
        ),
        (
            "selected_bytes_resident_claim",
            reject_first(cards, |card| {
                card.selected_bytes_become_resident_claim = true
            }),
        ),
        (
            "missing_kv_cache_floor",
            reject_first(cards, |card| card.byte_plan.kv_cache_floor_bytes = 0),
        ),
        (
            "missing_runtime_workspace",
            reject_first(cards, |card| card.byte_plan.runtime_workspace_bytes = 0),
        ),
        (
            "missing_app_headroom",
            reject_first(cards, |card| card.byte_plan.app_headroom_bytes = 0),
        ),
        (
            "total_envelope_mismatch",
            reject_first(cards, |card| {
                card.byte_plan.planned_total_envelope_bytes = card
                    .byte_plan
                    .planned_total_envelope_bytes
                    .saturating_add(1)
            }),
        ),
        (
            "e4b_missing_fresh_memory_sample",
            reject_set(cards, |bad| {
                bad[1]
                    .byte_plan
                    .tight_candidate_requires_fresh_memory_sample = false
            }),
        ),
        (
            "m2pro_fit_claim_missing_caveat",
            reject_first(cards, |card| {
                card.policy.current_m2pro_16gb_probe_candidate_not_fit_claim = false
            }),
        ),
        (
            "owner_approval_granted",
            reject_first(cards, |card| card.owner_approval_granted = true),
        ),
        (
            "first_token_claimed",
            reject_first(cards, |card| card.first_token_claimed = true),
        ),
        (
            "first_token_attempted",
            reject_first(cards, |card| card.byte_ledger.first_token_attempts = 1),
        ),
        (
            "bad_proof_ref",
            reject_first(cards, |card| {
                card.proof_refs.answer_packet_ref = "missing".to_string()
            }),
        ),
        (
            "owner_manifest_present",
            reject_first(cards, |card| card.owner_manifest_present = true),
        ),
        (
            "local_artifact_verified",
            reject_first(cards, |card| card.local_artifact_verified = true),
        ),
        (
            "path_canonicalization_allowed",
            reject_first(cards, |card| card.path_canonicalization_allowed = true),
        ),
        (
            "file_access_allowed",
            reject_first(cards, |card| card.file_access_allowed = true),
        ),
        (
            "file_hash_attempted",
            reject_first(cards, |card| card.byte_ledger.file_hash_attempts = 1),
        ),
        (
            "command_armed",
            reject_first(cards, |card| card.command_envelope_armed = true),
        ),
        (
            "runtime_probe_allowed",
            reject_first(cards, |card| card.runtime_probe_allowed = true),
        ),
        (
            "model_bytes_loaded",
            reject_first(cards, |card| card.byte_ledger.model_bytes_loaded = 1),
        ),
        (
            "runtime_bytes_loaded",
            reject_first(cards, |card| card.byte_ledger.runtime_bytes_loaded = 1),
        ),
        (
            "benchmark_run",
            reject_first(cards, |card| card.byte_ledger.benchmark_runs = 1),
        ),
        (
            "route_mutation_allowed",
            reject_first(cards, |card| card.route_mutation_allowed = true),
        ),
        (
            "hidden_route_authority",
            reject_first(cards, |card| card.hidden_route_authority_allowed = true),
        ),
        (
            "mas_l2_l3_product_claim",
            reject_first(cards, |card| {
                card.mas_promoted = true;
                card.l2_green_claimed = true;
                card.l3_green_claimed = true;
                card.product_capability_claimed = true;
            }),
        ),
        (
            "live_dense_70b_claim",
            reject_first(cards, |card| card.live_dense_70b_claimed = true),
        ),
        (
            "ssd_as_ram_claim",
            reject_first(cards, |card| card.ssd_as_ram_claimed = true),
        ),
        (
            "metadata_budget_exceeded",
            reject_first(cards, |card| {
                card.byte_ledger.metadata_bytes_read = 512 * 1024
            }),
        ),
        (
            "bad_upstream_ref",
            reject_first(cards, |card| {
                card.upstream_manifest_ref = "artifact:wrong".to_string()
            }),
        ),
        (
            "missing_litert_lane",
            reject_first(cards, |card| {
                card.runtime_lanes
                    .retain(|lane| *lane != agent_core::uas::GemmaFamilyRuntimeLane::LiteRtLm)
            }),
        ),
        (
            "quality_claimed",
            reject_first(cards, |card| card.quality_claimed = true),
        ),
    ]
}

fn reject_first(
    cards: &[GemmaQatByteKvAppEnvelopeCard],
    mutate: impl FnOnce(&mut GemmaQatByteKvAppEnvelopeCard),
) -> bool {
    let mut bad = cards.to_vec();
    if let Some(card) = bad.first_mut() {
        mutate(card);
    }
    build_ledger("uas:gemma-qatsmall-manifest:red".to_string(), bad).is_err()
}

fn reject_set(
    cards: &[GemmaQatByteKvAppEnvelopeCard],
    mutate: impl FnOnce(&mut Vec<GemmaQatByteKvAppEnvelopeCard>),
) -> bool {
    let mut bad = cards.to_vec();
    mutate(&mut bad);
    build_ledger("uas:gemma-qatsmall-manifest:red".to_string(), bad).is_err()
}

fn red_pass(red_results: &[(&'static str, bool)], name: &str) -> bool {
    red_results
        .iter()
        .find(|(fixture, _)| *fixture == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

fn add_text_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: &str,
    expected: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(value.to_string()),
            unit: "text".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::String(expected.to_string()),
            unit: "text".to_string(),
        },
    );
    pass_per_axis.insert(
        name.to_string(),
        if expected == "non_empty" {
            !value.trim().is_empty()
        } else {
            value == expected
        },
    );
}

fn assert_axis_coverage(measurements: &BTreeMap<String, Measurement>) {
    let missing = GEMMA_QAT_BYTE_KV_APP_ENVELOPE_PREFLIGHT_AXES
        .iter()
        .filter(|axis| !measurements.contains_key(**axis))
        .copied()
        .collect::<Vec<_>>();
    assert!(
        missing.is_empty(),
        "missing Gemma QAT byte/KV/app envelope axes: {missing:?}"
    );
}
