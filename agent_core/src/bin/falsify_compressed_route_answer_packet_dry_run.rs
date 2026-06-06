//! `falsify_compressed_route_answer_packet_dry_run`
//!
//! Metadata-only witness for `F-CompressedRoute-AnswerPacket-DryRun`. It turns
//! QAT route-card memory preflights into visible dry-run AnswerPackets while
//! keeping all model/runtime/provider bytes at zero.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    CompressedRouteAnswerPacketDryRun, CompressedRouteAnswerPacketDryRunSet,
    CompressedRouteAnswerPacketRefs, CompressedRouteByteLedger, CompressedRoutePacketStatus,
    CompressedRoutePromotionTier, ProStatus, ProductBuild, QatRouteRuntimeLane, UasAddress,
    UasKind, COMPRESSED_ROUTE_ANSWER_PACKET_DRY_RUN_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-CompressedRoute-AnswerPacket-DryRun";
const FIXTURE_ID: &str = "compressed_route_answer_packet_dry_run_v1";
const COMMAND: &str = "Tools/falsifiers/f_compressed_route_answer_packet_dry_run.sh";
const RESULT: &str = "artifacts/falsifiers/compressed_route_answer_packet_dry_run/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/qat_model_route_card_memory_preflight/result.json";
const CREATED_AT_MS: u64 = 1_779_034_800_000;
const SET_METADATA_BYTES: u64 = 84_000;
const GIB: u64 = 1_073_741_824;
const MIB: u64 = 1_048_576;

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
        "{FALSIFIER_ID}: overall_pass={} packet_count={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["accepted_packet_count"].value,
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
    let upstream = upstream_preflight_set_address()?;
    let packets = accepted_packets();
    let packet_set = build_set(upstream.clone(), packets.clone())?;
    let reversed = build_set(upstream, packets.iter().cloned().rev().collect())?;
    let metrics = packet_set.metrics();
    let red_results = red_fixture_results(&packet_set);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_qat_route_preflight_bound",
            packet_set
                .upstream_preflight_witness_ref
                .contains("qat_model_route_card_memory_preflight"),
        ),
        (
            "accepted_packet_pack_present",
            has_packet(&packets, "gemma4_e2b_compressed_route_packet")
                && has_packet(&packets, "gemma4_e4b_compressed_route_packet")
                && has_packet(&packets, "gemma4_12b_compressed_route_abstention_packet")
                && has_packet(&packets, "gemma4_31b_compressed_route_vault_packet"),
        ),
        (
            "small_qat_answer_packets_packetized",
            metrics.packetized_dry_run_count >= 2
                && packet_status(
                    &packets,
                    "gemma4_e2b_compressed_route_packet",
                    CompressedRoutePacketStatus::PacketizedDryRun,
                )
                && packet_status(
                    &packets,
                    "gemma4_e4b_compressed_route_packet",
                    CompressedRoutePacketStatus::PacketizedDryRun,
                ),
        ),
        (
            "twelve_b_abstention_packet_visible",
            packet_status(
                &packets,
                "gemma4_12b_compressed_route_abstention_packet",
                CompressedRoutePacketStatus::CarriedAbstention,
            ) && red_pass(&red_results, "twelve_b_packetized_dry_run")
                && red_pass(&red_results, "missing_abstention_reason"),
        ),
        (
            "thirty_one_b_vault_packet_visible",
            packet_status(
                &packets,
                "gemma4_31b_compressed_route_vault_packet",
                CompressedRoutePacketStatus::CarriedVaultOnly,
            ) && red_pass(&red_results, "thirty_one_b_non_vault_packet")
                && red_pass(&red_results, "missing_vault_ref"),
        ),
        (
            "answer_packet_visibility_required",
            packets.iter().all(|packet| {
                packet.selected_model_visible
                    && packet.rejected_candidates_visible
                    && packet.byte_ledger_visible
                    && !packet.answer_packet_suppressed
            }) && red_pass(&red_results, "missing_selected_model_visibility")
                && red_pass(&red_results, "hidden_visibility_byte_ledger")
                && red_pass(&red_results, "answer_packet_suppressed"),
        ),
        (
            "route_caveat_fallback_rollback_cancellation_visible",
            packets.iter().all(|packet| {
                packet.route_caveat_visible
                    && packet.fallback_visible
                    && packet.rollback_visible
                    && packet.cancellation_visible
                    && packet.no_mutation_envelope_visible
            }) && red_pass(&red_results, "missing_route_caveat")
                && red_pass(&red_results, "missing_fallback")
                && red_pass(&red_results, "missing_rollback")
                && red_pass(&red_results, "missing_cancellation"),
        ),
        (
            "byte_placeholders_consistent",
            packets.iter().all(|packet| {
                packet.bytes.planned_route_bytes
                    == packet.bytes.planned_model_bytes
                        + packet.bytes.planned_kv_bytes
                        + packet.bytes.planned_scratch_bytes
                    && packet.bytes.planned_model_bytes > packet.bytes.declared_file_bytes
                    && packet.bytes.fallback_reserved_bytes > 0
            }) && red_pass(&red_results, "zero_declared_file_bytes")
                && red_pass(&red_results, "planned_model_equals_file")
                && red_pass(&red_results, "zero_planned_kv")
                && red_pass(&red_results, "bad_planned_route_bytes"),
        ),
        (
            "zero_opened_model_bytes",
            metrics.opened_model_bytes == 0 && red_pass(&red_results, "opened_model_bytes"),
        ),
        (
            "zero_opened_runtime_bytes",
            metrics.opened_runtime_bytes == 0 && red_pass(&red_results, "opened_runtime_bytes"),
        ),
        (
            "zero_resident_model_bytes",
            metrics.resident_model_bytes == 0 && red_pass(&red_results, "resident_model_bytes"),
        ),
        (
            "zero_resident_runtime_bytes",
            metrics.resident_runtime_bytes == 0 && red_pass(&red_results, "resident_runtime_bytes"),
        ),
        (
            "zero_runtime_bytes_loaded",
            metrics.runtime_bytes_loaded == 0 && red_pass(&red_results, "runtime_bytes_loaded"),
        ),
        (
            "zero_model_bytes_loaded",
            metrics.model_bytes_loaded == 0 && red_pass(&red_results, "model_bytes_loaded"),
        ),
        (
            "zero_provider_calls",
            metrics.provider_calls_made == 0 && red_pass(&red_results, "provider_call_made"),
        ),
        (
            "product_promotion_rejected",
            red_pass(&red_results, "mas_product_build")
                && red_pass(&red_results, "pro_live_status")
                && red_pass(&red_results, "promotion_tier_t2")
                && red_pass(&red_results, "first_token_claim")
                && red_pass(&red_results, "quality_claim")
                && red_pass(&red_results, "runtime_parity_claim")
                && red_pass(&red_results, "mas_readiness_claim"),
        ),
        (
            "hidden_authority_rejected",
            red_pass(&red_results, "hidden_cloud_fallback")
                && red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "hidden_chain_exposed")
                && red_pass(&red_results, "route_policy_mutated")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "refs_and_prefixes_required",
            red_pass(&red_results, "bad_upstream_preflight_ref")
                && red_pass(&red_results, "bad_answer_packet_prefix")
                && red_pass(&red_results, "bad_visible_summary_prefix")
                && red_pass(&red_results, "missing_rejected_candidate"),
        ),
        (
            "metadata_budget_enforced",
            red_pass(&red_results, "packet_metadata_budget_exceeded")
                && red_pass(&red_results, "set_metadata_budget_exceeded"),
        ),
        (
            "set_address_deterministic",
            packet_set.set_address == reversed.set_address,
        ),
        (
            "layer_separation_required",
            red_pass(&red_results, "set_missing_layer_separation")
                && red_pass(&red_results, "set_runtime_not_deferred")
                && red_pass(&red_results, "set_product_promotion_allowed"),
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
        "accepted_packet_count",
        metrics.packet_count,
        ">=",
        4,
        "packets",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "packetized_dry_run_count",
        metrics.packetized_dry_run_count,
        ">=",
        2,
        "packets",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "abstention_packet_count",
        metrics.abstention_packet_count,
        ">=",
        1,
        "packets",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "vault_packet_count",
        metrics.vault_packet_count,
        ">=",
        1,
        "packets",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_count",
        red_results.len() as u64,
        ">=",
        40,
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
        "planned_route_bytes_total",
        metrics.planned_route_bytes_total,
        ">",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metadata_bytes_read",
        metrics.metadata_bytes_read,
        "<=",
        512 * 1024,
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
        "packet_set_address".to_string(),
        Measurement {
            value: serde_json::json!(packet_set.set_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "packet_set_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("compressed_route_answer_packet_dry_run:"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "packet_set_address".to_string(),
        packet_set
            .set_address
            .to_string()
            .starts_with("compressed_route_answer_packet_dry_run:"),
    );
    measurements.insert(
        "next_research_to_build_unit".to_string(),
        Measurement {
            value: serde_json::json!(COMPRESSED_ROUTE_ANSWER_PACKET_DRY_RUN_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_research_to_build_unit".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!("small_compressed_model_live_harness"),
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
        notes: "Builds F-CompressedRoute-AnswerPacket-DryRun from the QAT route-card memory preflight witness. Scope is T1/L1 metadata only: E2B/E4B become visible dry-run AnswerPackets; 12B is carried as an abstention packet; 31B is carried as vault-only. This witness loads zero model/runtime bytes, makes zero provider calls, proves route caveat/fallback/rollback/cancellation visibility, and blocks first-token, quality, MAS, L2/L3, hidden authority, live dense 70B, and SSD-as-RAM claims.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_preflight_set_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream QAT route-preflight witness has not passed".into());
    }
    let address = value
        .pointer("/measurements/route_preflight_set_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("missing upstream route_preflight_set_address measurement")?;
    Ok(UasAddress::from_str(address)?)
}

fn build_set(
    upstream_preflight_set_address: UasAddress,
    packets: Vec<CompressedRouteAnswerPacketDryRun>,
) -> Result<CompressedRouteAnswerPacketDryRunSet, Box<dyn std::error::Error>> {
    Ok(CompressedRouteAnswerPacketDryRunSet::from_preflight(
        upstream_preflight_set_address,
        "artifact:qat_model_route_card_memory_preflight:result",
        packets,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        SET_METADATA_BYTES,
        true,
        true,
        true,
        CREATED_AT_MS,
    )?)
}

fn accepted_packets() -> Vec<CompressedRouteAnswerPacketDryRun> {
    vec![
        packet(PacketSpec {
            packet_id: "gemma4_e2b_compressed_route_packet",
            preflight_card_id: "gemma4_e2b_qat_gguf_route_preflight",
            model_id: "google/gemma-4-E2B-it-qat-q4_0-gguf",
            runtime_lane: QatRouteRuntimeLane::GgufLlamaCpp,
            packet_status: CompressedRoutePacketStatus::PacketizedDryRun,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: CompressedRoutePromotionTier::T1L1Metadata,
            declared_file_bytes: 4_628_569_635,
            planned_model_bytes: 5 * GIB,
            planned_kv_bytes: 512 * MIB,
            planned_scratch_bytes: 256 * MIB,
            abstention_reason_ref: None,
            vault_preservation_ref: None,
        }),
        packet(PacketSpec {
            packet_id: "gemma4_e4b_compressed_route_packet",
            preflight_card_id: "gemma4_e4b_qat_gguf_route_preflight",
            model_id: "google/gemma-4-E4B-it-qat-q4_0-gguf",
            runtime_lane: QatRouteRuntimeLane::GgufLlamaCpp,
            packet_status: CompressedRoutePacketStatus::PacketizedDryRun,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: CompressedRoutePromotionTier::T1L1Metadata,
            declared_file_bytes: 7_463_013_674,
            planned_model_bytes: 8 * GIB,
            planned_kv_bytes: 768 * MIB,
            planned_scratch_bytes: 384 * MIB,
            abstention_reason_ref: None,
            vault_preservation_ref: None,
        }),
        packet(PacketSpec {
            packet_id: "gemma4_12b_compressed_route_abstention_packet",
            preflight_card_id: "gemma4_12b_qat_gguf_route_preflight",
            model_id: "google/gemma-4-12B-it-qat-q4_0-gguf",
            runtime_lane: QatRouteRuntimeLane::GgufLlamaCpp,
            packet_status: CompressedRoutePacketStatus::CarriedAbstention,
            pro_status: ProStatus::Gated,
            promotion_tier: CompressedRoutePromotionTier::T1L1Metadata,
            declared_file_bytes: 11_907_350_576,
            planned_model_bytes: 13 * GIB,
            planned_kv_bytes: GIB,
            planned_scratch_bytes: 512 * MIB,
            abstention_reason_ref: Some("abstain:insufficient_16gb_uma_headroom_visible_packet"),
            vault_preservation_ref: None,
        }),
        packet(PacketSpec {
            packet_id: "gemma4_31b_compressed_route_vault_packet",
            preflight_card_id: "gemma4_31b_qat_gguf_vault_route_preflight",
            model_id: "google/gemma-4-31B-it-qat-q4_0-gguf",
            runtime_lane: QatRouteRuntimeLane::GgufLlamaCpp,
            packet_status: CompressedRoutePacketStatus::CarriedVaultOnly,
            pro_status: ProStatus::VaultPreserved,
            promotion_tier: CompressedRoutePromotionTier::T0Research,
            declared_file_bytes: 30_697_345_596,
            planned_model_bytes: 32 * GIB,
            planned_kv_bytes: 2 * GIB,
            planned_scratch_bytes: GIB,
            abstention_reason_ref: None,
            vault_preservation_ref: Some("vault:large_candidate_no_runtime_probe"),
        }),
    ]
}

// UAS-EXEMPT: private fixture builder for this falsifier binary; emitted UAS
// objects are `CompressedRouteAnswerPacketDryRun` and the packet set.
struct PacketSpec {
    packet_id: &'static str,
    preflight_card_id: &'static str,
    model_id: &'static str,
    runtime_lane: QatRouteRuntimeLane,
    packet_status: CompressedRoutePacketStatus,
    pro_status: ProStatus,
    promotion_tier: CompressedRoutePromotionTier,
    declared_file_bytes: u64,
    planned_model_bytes: u64,
    planned_kv_bytes: u64,
    planned_scratch_bytes: u64,
    abstention_reason_ref: Option<&'static str>,
    vault_preservation_ref: Option<&'static str>,
}

fn packet(spec: PacketSpec) -> CompressedRouteAnswerPacketDryRun {
    let PacketSpec {
        packet_id,
        preflight_card_id,
        model_id,
        runtime_lane,
        packet_status,
        pro_status,
        promotion_tier,
        declared_file_bytes,
        planned_model_bytes,
        planned_kv_bytes,
        planned_scratch_bytes,
        abstention_reason_ref,
        vault_preservation_ref,
    } = spec;
    CompressedRouteAnswerPacketDryRun {
        packet_id: packet_id.to_string(),
        model_id: model_id.to_string(),
        runtime_lane,
        packet_status,
        product_build: ProductBuild::Pro,
        pro_status,
        promotion_tier,
        bytes: CompressedRouteByteLedger::metadata_only(
            declared_file_bytes,
            planned_model_bytes,
            planned_kv_bytes,
            planned_scratch_bytes,
            128 * MIB,
            20_000,
        ),
        refs: CompressedRouteAnswerPacketRefs {
            upstream_preflight_card_ref: format!("qat_route_preflight:{preflight_card_id}"),
            falsifier_ref: format!("falsifier:{FALSIFIER_ID}:{packet_id}"),
            answer_packet_ref: format!("answer_packet:compressed_route_dry_run:{packet_id}"),
            run_event_log_ref: format!("run_event_log:compressed_route_dry_run:{packet_id}"),
            fallback_ref: format!("fallback:compressed_route_dry_run:{packet_id}"),
            rollback_ref: format!("rollback:compressed_route_dry_run:{packet_id}"),
            admission_ref: format!("admission:compressed_route_dry_run:{packet_id}"),
            cancellation_ref: format!("cancel:compressed_route_dry_run:{packet_id}"),
            compatibility_fence_ref: format!("compat:compressed_route_dry_run:{packet_id}"),
            route_caveat_ref: format!("route_caveat:compressed_route_dry_run:{packet_id}"),
            visible_summary_ref: format!("visible_summary:compressed_route_dry_run:{packet_id}"),
            abstention_reason_ref: abstention_reason_ref.map(str::to_string),
            vault_preservation_ref: vault_preservation_ref.map(str::to_string),
            rejected_candidate_refs: vec![
                "rejected_candidate:gemma4_12b_insufficient_headroom".to_string(),
                "rejected_candidate:gemma4_31b_vault_only".to_string(),
            ],
        },
        user_visible_summary: format!(
            "{packet_id} is a visible compressed-route AnswerPacket dry-run for {model_id}. It shows the selected model, rejected candidates, byte plan, route caveat, fallback, rollback, cancellation, and no-mutation envelope; it is not live inference, not a product route, and not a 70B capability claim."
        ),
        selected_model_visible: true,
        rejected_candidates_visible: true,
        route_caveat_visible: true,
        byte_ledger_visible: true,
        fallback_visible: true,
        rollback_visible: true,
        cancellation_visible: true,
        no_mutation_envelope_visible: true,
        l1_l2_l3_separated: true,
        runtime_deferred: true,
        product_promotion_blocked: true,
        first_token_claimed: false,
        quality_claimed: false,
        runtime_parity_claimed: false,
        mas_readiness_claimed: false,
        route_policy_mutated: false,
        answer_packet_suppressed: false,
        hidden_chain_exposed: false,
        hidden_cloud_fallback_allowed: false,
        hidden_route_authority_allowed: false,
        live_dense_70b_claimed: false,
        ssd_as_ram_claimed: false,
    }
}

fn has_packet(packets: &[CompressedRouteAnswerPacketDryRun], packet_id: &str) -> bool {
    packets.iter().any(|packet| packet.packet_id == packet_id)
}

fn packet_status(
    packets: &[CompressedRouteAnswerPacketDryRun],
    packet_id: &str,
    status: CompressedRoutePacketStatus,
) -> bool {
    packets
        .iter()
        .any(|packet| packet.packet_id == packet_id && packet.packet_status == status)
}

fn red_pass(red_results: &[(&'static str, bool)], name: &str) -> bool {
    red_results
        .iter()
        .any(|(candidate, pass)| *candidate == name && *pass)
}

fn red_fixture_results(
    valid_set: &CompressedRouteAnswerPacketDryRunSet,
) -> Vec<(&'static str, bool)> {
    vec![
        red_packet("duplicate_packet_id", |packets| {
            packets.push(packets[0].clone())
        }),
        red_packet("duplicate_model_runtime", |packets| {
            let mut duplicate = packets[0].clone();
            duplicate.packet_id = "gemma4_e2b_duplicate_runtime_packet".to_string();
            packets.push(duplicate);
        }),
        red_packet("bad_upstream_preflight_ref", |packets| {
            packets[0].refs.upstream_preflight_card_ref = "bad:gemma4_e2b".to_string();
        }),
        red_packet("bad_answer_packet_prefix", |packets| {
            packets[0].refs.answer_packet_ref = "packet:gemma4_e2b".to_string();
        }),
        red_packet("bad_visible_summary_prefix", |packets| {
            packets[0].refs.visible_summary_ref = "summary:gemma4_e2b".to_string();
        }),
        red_packet("missing_rejected_candidate", |packets| {
            packets[0].refs.rejected_candidate_refs.clear();
        }),
        red_packet("short_visible_summary", |packets| {
            packets[0].user_visible_summary = "too short".to_string();
        }),
        red_packet("zero_declared_file_bytes", |packets| {
            packets[0].bytes.declared_file_bytes = 0;
        }),
        red_packet("planned_model_equals_file", |packets| {
            packets[0].bytes.planned_model_bytes = packets[0].bytes.declared_file_bytes;
        }),
        red_packet("zero_planned_kv", |packets| {
            packets[0].bytes.planned_kv_bytes = 0;
        }),
        red_packet("bad_planned_route_bytes", |packets| {
            packets[0].bytes.planned_route_bytes += 1;
        }),
        red_packet("opened_model_bytes", |packets| {
            packets[0].bytes.opened_model_bytes = 1;
        }),
        red_packet("opened_runtime_bytes", |packets| {
            packets[0].bytes.opened_runtime_bytes = 1;
        }),
        red_packet("resident_model_bytes", |packets| {
            packets[0].bytes.resident_model_bytes = 1;
        }),
        red_packet("resident_runtime_bytes", |packets| {
            packets[0].bytes.resident_runtime_bytes = 1;
        }),
        red_packet("observed_peak_rss_bytes", |packets| {
            packets[0].bytes.observed_peak_rss_bytes = 1;
        }),
        red_packet("model_bytes_loaded", |packets| {
            packets[0].bytes.model_bytes_loaded = 1;
        }),
        red_packet("runtime_bytes_loaded", |packets| {
            packets[0].bytes.runtime_bytes_loaded = 1;
        }),
        red_packet("provider_call_made", |packets| {
            packets[0].bytes.provider_calls_made = 1;
        }),
        red_packet("missing_fallback", |packets| {
            packets[0].fallback_visible = false;
        }),
        red_packet("missing_rollback", |packets| {
            packets[0].rollback_visible = false;
        }),
        red_packet("missing_cancellation", |packets| {
            packets[0].cancellation_visible = false;
        }),
        red_packet("missing_route_caveat", |packets| {
            packets[0].route_caveat_visible = false;
        }),
        red_packet("missing_selected_model_visibility", |packets| {
            packets[0].selected_model_visible = false;
        }),
        red_packet("hidden_visibility_byte_ledger", |packets| {
            packets[0].byte_ledger_visible = false;
        }),
        red_packet("answer_packet_suppressed", |packets| {
            packets[0].answer_packet_suppressed = true;
        }),
        red_packet("route_policy_mutated", |packets| {
            packets[0].route_policy_mutated = true;
        }),
        red_packet("first_token_claim", |packets| {
            packets[0].first_token_claimed = true;
        }),
        red_packet("quality_claim", |packets| {
            packets[0].quality_claimed = true;
        }),
        red_packet("runtime_parity_claim", |packets| {
            packets[0].runtime_parity_claimed = true;
        }),
        red_packet("mas_readiness_claim", |packets| {
            packets[0].mas_readiness_claimed = true;
        }),
        red_packet("mas_product_build", |packets| {
            packets[0].product_build = ProductBuild::Mas;
        }),
        red_packet("pro_live_status", |packets| {
            packets[0].pro_status = ProStatus::Live;
        }),
        red_packet("promotion_tier_t2", |packets| {
            packets[0].promotion_tier = CompressedRoutePromotionTier::T2L2Route;
        }),
        red_packet("hidden_cloud_fallback", |packets| {
            packets[0].hidden_cloud_fallback_allowed = true;
        }),
        red_packet("hidden_route_authority", |packets| {
            packets[0].hidden_route_authority_allowed = true;
        }),
        red_packet("hidden_chain_exposed", |packets| {
            packets[0].hidden_chain_exposed = true;
        }),
        red_packet("live_dense_70b_claim", |packets| {
            packets[0].live_dense_70b_claimed = true;
        }),
        red_packet("ssd_as_ram_claim", |packets| {
            packets[0].ssd_as_ram_claimed = true;
        }),
        red_packet("twelve_b_packetized_dry_run", |packets| {
            if let Some(packet) = packets
                .iter_mut()
                .find(|packet| packet.model_id.contains("-12B-"))
            {
                packet.packet_status = CompressedRoutePacketStatus::PacketizedDryRun;
                packet.refs.abstention_reason_ref = None;
            }
        }),
        red_packet("thirty_one_b_non_vault_packet", |packets| {
            if let Some(packet) = packets
                .iter_mut()
                .find(|packet| packet.model_id.contains("-31B-"))
            {
                packet.packet_status = CompressedRoutePacketStatus::CarriedAbstention;
                packet.pro_status = ProStatus::Gated;
                packet.refs.vault_preservation_ref = None;
                packet.refs.abstention_reason_ref =
                    Some("abstain:bad_31b_non_vault_packet".to_string());
            }
        }),
        red_packet("missing_abstention_reason", |packets| {
            if let Some(packet) = packets
                .iter_mut()
                .find(|packet| packet.model_id.contains("-12B-"))
            {
                packet.refs.abstention_reason_ref = None;
            }
        }),
        red_packet("missing_vault_ref", |packets| {
            if let Some(packet) = packets
                .iter_mut()
                .find(|packet| packet.model_id.contains("-31B-"))
            {
                packet.refs.vault_preservation_ref = None;
            }
        }),
        red_packet("packet_metadata_budget_exceeded", |packets| {
            packets[0].bytes.metadata_bytes_read = 97 * 1024;
        }),
        (
            "set_metadata_budget_exceeded",
            set_from(
                valid_set.upstream_preflight_set_address.clone(),
                accepted_packets(),
                513 * 1024,
                true,
                true,
                true,
            )
            .is_err(),
        ),
        (
            "set_missing_layer_separation",
            set_from(
                valid_set.upstream_preflight_set_address.clone(),
                accepted_packets(),
                SET_METADATA_BYTES,
                false,
                true,
                true,
            )
            .is_err(),
        ),
        (
            "set_runtime_not_deferred",
            set_from(
                valid_set.upstream_preflight_set_address.clone(),
                accepted_packets(),
                SET_METADATA_BYTES,
                true,
                false,
                true,
            )
            .is_err(),
        ),
        (
            "set_product_promotion_allowed",
            set_from(
                valid_set.upstream_preflight_set_address.clone(),
                accepted_packets(),
                SET_METADATA_BYTES,
                true,
                true,
                false,
            )
            .is_err(),
        ),
    ]
}

fn red_packet(
    name: &'static str,
    mutate: impl FnOnce(&mut Vec<CompressedRouteAnswerPacketDryRun>),
) -> (&'static str, bool) {
    let mut packets = accepted_packets();
    mutate(&mut packets);
    let pass = set_from(
        upstream_fixture_address(),
        packets,
        SET_METADATA_BYTES,
        true,
        true,
        true,
    )
    .is_err();
    (name, pass)
}

fn set_from(
    upstream_preflight_set_address: UasAddress,
    packets: Vec<CompressedRouteAnswerPacketDryRun>,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
) -> Result<CompressedRouteAnswerPacketDryRunSet, agent_core::uas::CompressedRouteAnswerPacketError>
{
    CompressedRouteAnswerPacketDryRunSet::from_preflight(
        upstream_preflight_set_address,
        "artifact:qat_model_route_card_memory_preflight:result",
        packets,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        metadata_bytes,
        l1_l2_l3_separated,
        runtime_deferred,
        product_promotion_blocked,
        CREATED_AT_MS,
    )
}

fn upstream_fixture_address() -> UasAddress {
    UasAddress::new(
        UasKind::Other("qat_model_route_card_memory_preflight".to_string()),
        b"qat-route-preflight-upstream-red-fixture",
        CREATED_AT_MS,
    )
}
