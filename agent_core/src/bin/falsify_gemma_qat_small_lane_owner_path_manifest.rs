//! `falsify_gemma_qat_small_lane_owner_path_manifest`
//!
//! Metadata-only witness for `F-GemmaQATSmallLaneOwnerPathManifest`. It defines
//! the owner path-manifest contract for the Gemma 4 E2B/E4B QAT warmup lanes
//! without opening paths, hashing files, running GGUF/LiteRT/MLX, or promoting
//! Gemma to L2/L3 product capability.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_QAT_SMALL_LANE_OWNER_PATH_MANIFEST_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    canonical_gemma_qat_small_lane_owner_path_manifest_cards, GemmaQatSmallLaneManifestAction,
    GemmaQatSmallLaneManifestState, GemmaQatSmallLaneOwnerPathManifestCard,
    GemmaQatSmallLaneOwnerPathManifestLedger, GEMMA_QAT_SMALL_LANE_OWNER_PATH_MANIFEST_ID,
    GEMMA_QAT_SMALL_LANE_OWNER_PATH_MANIFEST_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = GEMMA_QAT_SMALL_LANE_OWNER_PATH_MANIFEST_ID;
const FIXTURE_ID: &str = "gemma_qat_small_lane_owner_path_manifest_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_qat_small_lane_owner_path_manifest.sh";
const RESULT: &str = "artifacts/falsifiers/gemma_qat_small_lane_owner_path_manifest/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_main_family_policy_source_card/result.json";
const UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_main_family_policy_source_card/result.json#F-GemmaMainFamilyPolicySourceCard";
const CREATED_AT_MS: u64 = 1_779_210_800_000;
const LEDGER_METADATA_BYTES: u64 = 72_000;

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
        "{FALSIFIER_ID}: overall_pass={} manifest_card_count={} owner_manifest_bytes_read_total={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["manifest_card_count"].value,
        artifact.measurements["owner_manifest_bytes_read_total"].value,
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
    let (upstream_pass, upstream_address) = upstream_policy_card()?;
    let cards = canonical_gemma_qat_small_lane_owner_path_manifest_cards(UPSTREAM_REF);
    let ledger = build_ledger(upstream_address.clone(), cards.clone())?;
    let reversed = build_ledger(upstream_address, cards.iter().cloned().rev().collect())?;
    let metrics = ledger.metrics();
    let red_results = red_fixture_results(&cards);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_gemma_policy_card_pass", upstream_pass),
        (
            "accepted_small_lane_manifest_pack_present",
            has_card(&cards, "gemma4_e2b_qat_owner_path_manifest")
                && has_card(&cards, "gemma4_e4b_qat_owner_path_manifest"),
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
            "source_revision_filename_and_xet_bound",
            cards.iter().all(|card| {
                card.source_revision_ref.starts_with("hf_revision:")
                    && card.selected_filename_ref.starts_with("hf_file:")
                    && card.selected_filename_ref.ends_with(".gguf")
                    && card.xet_or_lfs_ref.starts_with("hf_xet_or_lfs:")
                    && card
                        .source_locator
                        .starts_with("https://huggingface.co/google/")
            }) && red_pass(&red_results, "bad_source_revision")
                && red_pass(&red_results, "bad_selected_filename")
                && red_pass(&red_results, "bad_source_locator"),
        ),
        (
            "manifest_contract_fields_required",
            cards.iter().all(|card| card.required_fields.no_promotion)
                && cards
                    .iter()
                    .all(|card| card.required_fields.no_raw_path_storage)
                && red_pass(&red_results, "missing_required_manifest_field"),
        ),
        (
            "owner_manifest_absent_zero_bytes",
            metrics.owner_manifest_present_count == 0
                && metrics.owner_signature_present_count == 0
                && metrics.owner_approval_granted_count == 0
                && metrics.owner_manifest_bytes_read_total == 0
                && red_pass(&red_results, "owner_manifest_present")
                && red_pass(&red_results, "owner_approval_granted")
                && red_pass(&red_results, "owner_manifest_bytes_read"),
        ),
        (
            "raw_and_canonical_path_bytes_absent",
            metrics.raw_owner_path_stored_count == 0
                && metrics.canonical_path_bound_count == 0
                && metrics.raw_owner_path_bytes_stored_total == 0
                && metrics.canonical_path_bytes_stored_total == 0
                && red_pass(&red_results, "raw_owner_path_stored")
                && red_pass(&red_results, "canonical_path_bound")
                && red_pass(&red_results, "raw_path_bytes_stored"),
        ),
        (
            "path_canonicalization_deferred",
            ledger.path_canonicalization_deferred
                && metrics.path_canonicalization_attempts_total == 0
                && red_pass(&red_results, "path_canonicalization_attempt"),
        ),
        (
            "file_access_and_hashing_disallowed",
            ledger.file_access_disallowed
                && metrics.file_open_allowed_count == 0
                && metrics.file_hash_allowed_count == 0
                && metrics.local_path_open_attempts_total == 0
                && metrics.file_stat_calls_total == 0
                && metrics.file_hash_attempts_total == 0
                && metrics.symlink_resolution_attempts_total == 0
                && red_pass(&red_results, "file_open_allowed")
                && red_pass(&red_results, "file_hash_attempt"),
        ),
        (
            "runtime_lanes_declared_but_unarmed",
            metrics.gguf_lane_count == 2
                && metrics.litert_lane_count == 2
                && metrics.command_envelope_armed_count == 0
                && metrics.command_execution_count_total == 0
                && metrics.runtime_probe_allowed_count == 0
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "runtime_probe_allowed"),
        ),
        (
            "zero_model_runtime_provider_bytes",
            metrics.model_bytes_loaded_total == 0
                && metrics.runtime_bytes_loaded_total == 0
                && metrics.provider_calls_made_total == 0
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "provider_calls_made"),
        ),
        (
            "proof_surfaces_bound",
            cards.iter().all(|card| {
                card.proof_refs
                    .manifest_schema_ref
                    .starts_with("owner_manifest_schema:")
                    && card.proof_refs.path_policy_ref.starts_with("path_policy:")
                    && card.proof_refs.byte_plan_ref.starts_with("byte_plan:")
                    && card
                        .proof_refs
                        .command_envelope_ref
                        .starts_with("command_envelope:")
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
                        .compatibility_fence_ref
                        .starts_with("compat:")
            }) && red_pass(&red_results, "bad_proof_ref"),
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
            "no_mas_l2_l3_product_or_large_model_claim",
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
            "manifest_ledger_address_deterministic",
            ledger.ledger_address == reversed.ledger_address,
        ),
        (
            "next_cursor_bound",
            GEMMA_QAT_SMALL_LANE_OWNER_PATH_MANIFEST_NEXT_CURSOR
                == "gemma_qat_byte_kv_app_envelope_preflight",
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
        ("manifest_card_count", metrics.card_count, "==", 2, "cards"),
        ("gguf_lane_count", metrics.gguf_lane_count, "==", 2, "lanes"),
        (
            "litert_lane_count",
            metrics.litert_lane_count,
            "==",
            2,
            "lanes",
        ),
        (
            "declared_file_bytes_total",
            metrics.declared_file_bytes_total,
            "==",
            12_091_583_309,
            "bytes",
        ),
        (
            "owner_manifest_bytes_read_total",
            metrics.owner_manifest_bytes_read_total,
            "==",
            0,
            "bytes",
        ),
        (
            "raw_owner_path_bytes_stored_total",
            metrics.raw_owner_path_bytes_stored_total,
            "==",
            0,
            "bytes",
        ),
        (
            "canonical_path_bytes_stored_total",
            metrics.canonical_path_bytes_stored_total,
            "==",
            0,
            "bytes",
        ),
        (
            "path_canonicalization_attempts_total",
            metrics.path_canonicalization_attempts_total,
            "==",
            0,
            "attempts",
        ),
        (
            "local_path_open_attempts_total",
            metrics.local_path_open_attempts_total,
            "==",
            0,
            "attempts",
        ),
        (
            "file_hash_attempts_total",
            metrics.file_hash_attempts_total,
            "==",
            0,
            "attempts",
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
            "metadata_bytes_read_total",
            metrics.metadata_bytes_read_total,
            "<=",
            256 * 1024,
            "bytes",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            ">=",
            23,
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
        "gemma_small_lane_manifest_address",
        &ledger.ledger_address.to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_QAT_SMALL_LANE_OWNER_PATH_MANIFEST_NEXT_CURSOR,
        "gemma_qat_byte_kv_app_envelope_preflight",
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
        notes: "metadata-only F-GemmaQATSmallLaneOwnerPathManifest: defines the owner path-manifest contract for Gemma 4 E2B/E4B QAT warmup lanes while reading zero owner manifest bytes, storing zero raw/canonical path bytes, canonicalizing zero paths, opening/statting/hashing zero files, arming zero commands, loading zero model/runtime/provider bytes, and making no MAS/L2/L3/user-facing promotion. It does not prove local artifact availability, owner approval, path safety, byte-envelope fit, first token, quality, Swift MLX loader support, LiteRT app embedding, or Gemma as the live main app model.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_policy_card() -> Result<(bool, String), Box<dyn std::error::Error>> {
    if !Path::new(UPSTREAM_RESULT).exists() {
        return Ok((false, "missing-upstream-policy-address".to_string()));
    }
    let value: serde_json::Value = serde_json::from_slice(&std::fs::read(UPSTREAM_RESULT)?)?;
    let pass = value
        .get("overall_pass")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);
    let address = value
        .pointer("/measurements/gemma_family_policy_address/value")
        .and_then(|v| v.as_str())
        .unwrap_or("missing-upstream-policy-address")
        .to_string();
    Ok((pass, address))
}

fn build_ledger(
    upstream_policy_address: String,
    cards: Vec<GemmaQatSmallLaneOwnerPathManifestCard>,
) -> Result<
    GemmaQatSmallLaneOwnerPathManifestLedger,
    agent_core::uas::GemmaQatSmallLaneOwnerPathManifestError,
> {
    GemmaQatSmallLaneOwnerPathManifestLedger::new(
        upstream_policy_address,
        UPSTREAM_REF,
        cards,
        LEDGER_METADATA_BYTES,
        CREATED_AT_MS,
    )
}

fn has_card(cards: &[GemmaQatSmallLaneOwnerPathManifestCard], id: &str) -> bool {
    cards.iter().any(|card| card.card_id == id)
}

fn red_fixture_results(
    cards: &[GemmaQatSmallLaneOwnerPathManifestCard],
) -> Vec<(&'static str, bool)> {
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
            "bad_source_revision",
            reject_first(cards, |card| {
                card.source_revision_ref = "branch:main".to_string()
            }),
        ),
        (
            "bad_selected_filename",
            reject_first(cards, |card| {
                card.selected_filename_ref = "hf_file:model.bin".to_string()
            }),
        ),
        (
            "bad_source_locator",
            reject_first(cards, |card| {
                card.source_locator = "file:///tmp/model.gguf".to_string()
            }),
        ),
        (
            "missing_required_manifest_field",
            reject_first(cards, |card| {
                card.required_fields.no_raw_path_storage = false
            }),
        ),
        (
            "owner_manifest_present",
            reject_first(cards, |card| card.owner_manifest_present = true),
        ),
        (
            "owner_approval_granted",
            reject_first(cards, |card| card.owner_approval_granted = true),
        ),
        (
            "owner_manifest_bytes_read",
            reject_first(cards, |card| card.byte_ledger.owner_manifest_bytes_read = 1),
        ),
        (
            "raw_owner_path_stored",
            reject_first(cards, |card| card.raw_owner_path_stored = true),
        ),
        (
            "canonical_path_bound",
            reject_first(cards, |card| card.canonical_path_bound = true),
        ),
        (
            "raw_path_bytes_stored",
            reject_first(cards, |card| {
                card.byte_ledger.raw_owner_path_bytes_stored = 1
            }),
        ),
        (
            "path_canonicalization_attempt",
            reject_first(cards, |card| {
                card.byte_ledger.path_canonicalization_attempts = 1
            }),
        ),
        (
            "file_open_allowed",
            reject_first(cards, |card| card.file_open_allowed = true),
        ),
        (
            "file_hash_attempt",
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
            "provider_calls_made",
            reject_first(cards, |card| card.byte_ledger.provider_calls_made = 1),
        ),
        (
            "bad_proof_ref",
            reject_first(cards, |card| {
                card.proof_refs.answer_packet_ref = "missing".to_string()
            }),
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
        ("unsafe_ledger_state", {
            let mut good = build_ledger(
                "gemma_main_family_policy_source_card:fixture".to_string(),
                cards.to_vec(),
            )
            .expect("good ledger");
            good.file_access_disallowed = false;
            good.validate().is_err()
        }),
        ("metadata_budget_exceeded", {
            let mut bad = cards.to_vec();
            bad[0].byte_ledger.metadata_bytes_read = 512 * 1024;
            build_ledger(
                "gemma_main_family_policy_source_card:fixture".to_string(),
                bad,
            )
            .is_err()
        }),
        (
            "wrong_manifest_state",
            reject_first(cards, |card| {
                card.state = GemmaQatSmallLaneManifestState::OwnerManifestApproved
            }),
        ),
        (
            "wrong_action",
            reject_first(cards, |card| {
                card.action = GemmaQatSmallLaneManifestAction::AllowRuntimeProbe
            }),
        ),
    ]
}

fn red_pass(results: &[(&'static str, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(candidate, _)| *candidate == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

fn reject_set(
    cards: &[GemmaQatSmallLaneOwnerPathManifestCard],
    mutate: impl FnOnce(&mut Vec<GemmaQatSmallLaneOwnerPathManifestCard>),
) -> bool {
    let mut bad = cards.to_vec();
    mutate(&mut bad);
    build_ledger(
        "gemma_main_family_policy_source_card:fixture".to_string(),
        bad,
    )
    .is_err()
}

fn reject_first(
    cards: &[GemmaQatSmallLaneOwnerPathManifestCard],
    mutate: impl FnOnce(&mut GemmaQatSmallLaneOwnerPathManifestCard),
) -> bool {
    reject_set(cards, |bad| mutate(&mut bad[0]))
}

fn add_text_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: &str,
    expected: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(actual.to_string()),
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
            !actual.trim().is_empty()
        } else {
            actual == expected
        },
    );
}

fn assert_axis_coverage(measurements: &BTreeMap<String, Measurement>) {
    for axis in GEMMA_QAT_SMALL_LANE_OWNER_PATH_MANIFEST_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing artifact axis {axis}"
        );
    }
}
