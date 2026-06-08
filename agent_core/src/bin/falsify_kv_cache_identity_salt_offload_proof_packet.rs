//! `falsify_kv_cache_identity_salt_offload_proof_packet`
//!
//! Metadata-only witness for `F-KVCacheIdentitySaltAndOffloadProofPacket`. It
//! builds the Pass 128 cache identity, salt, and offload packet without opening
//! model, KV, cache, runtime, provider, source-tree, product, or benchmark
//! bytes.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    canonical_kv_cache_identity_cards, KvCacheIdentityCard, KvCacheIdentityError,
    KvCacheIdentitySaltOffloadProofPacket, KV_CACHE_IDENTITY_SALT_OFFLOAD_PROOF_PACKET_CURSOR,
    KV_CACHE_IDENTITY_SALT_OFFLOAD_PROOF_PACKET_ID,
    KV_CACHE_IDENTITY_SALT_OFFLOAD_PROOF_PACKET_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = KV_CACHE_IDENTITY_SALT_OFFLOAD_PROOF_PACKET_ID;
const COMMAND: &str = "Tools/falsifiers/f_kv_cache_identity_salt_offload_proof_packet.sh";
const RESULT: &str = "artifacts/falsifiers/kv_cache_identity_salt_offload_proof_packet/result.json";
const FIXTURE_ID: &str = "kv_cache_identity_salt_offload_proof_packet_v1";
const CREATED_AT_MS: u64 = 1_779_072_000_000;
const PACKET_METADATA_BYTES: u64 = 192_000;

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
        "{FALSIFIER_ID}: overall_pass={} card_count={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["card_count"].value,
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
    let cards = canonical_kv_cache_identity_cards();
    let packet = build_packet(cards.clone())?;
    let reversed = KvCacheIdentitySaltOffloadProofPacket::new(
        cards.iter().cloned().rev().collect(),
        PACKET_METADATA_BYTES,
        CREATED_AT_MS,
    )?;
    let metrics = packet.metrics();
    let red_results = red_fixture_results();
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "accepted_source_cards_present",
            metrics.card_count == 5
                && metrics.source_count == 5
                && metrics.runtime_lane_count == 5
                && has_card(&cards, "vllm_prefix_caching")
                && has_card(&cards, "lmcache_local_storage")
                && has_card(&cards, "llama_cpp_slot_prompt_cache")
                && has_card(&cards, "ktransformers_expert_cache")
                && has_card(&cards, "kivi_asymmetric_kv"),
        ),
        (
            "source_prompt_tokenizer_tool_identity_bound",
            metrics.prompt_digest_count == 1
                && metrics.tokenizer_digest_count == 1
                && metrics.tool_schema_digest_count == 1
                && cards.iter().all(|card| {
                    card.source_freshness_digest.starts_with("sha256:")
                        && card.search_freshness_digest.starts_with("sha256:")
                        && card.chat_template_digest.starts_with("sha256:")
                }),
        ),
        (
            "block_parent_salt_extras_bound",
            metrics.cache_salt_digest_count == 5
                && metrics.trust_group_count == 5
                && cards.iter().all(|card| {
                    card.block_hash.starts_with("kv_block:")
                        && card.parent_block_hash.starts_with("kv_block:")
                        && card.block_token_range_digest.starts_with("sha256:")
                        && card.adapter_ids_digest.starts_with("sha256:")
                        && card.modality_hash_digest.starts_with("sha256:")
                }),
        ),
        (
            "offload_tier_budget_bound",
            metrics.offload_tier_count >= 4
                && metrics.local_disk_tier_count >= 3
                && metrics.remote_denied_tier_count >= 1
                && metrics.remote_cache_bytes == 0
                && cards.iter().all(|card| {
                    card.chunk_size_tokens > 0
                        && !card.eviction_policy.is_empty()
                        && !card.prefetch_policy.is_empty()
                        && !card.cleanup_policy.is_empty()
                }),
        ),
        (
            "proof_refs_and_visibility_bound",
            cards.iter().all(|card| {
                card.cache_reuse_visible
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
                    && card.proof_refs.cache_caveat_ref.starts_with("caveat:")
            }),
        ),
        (
            "zero_loaded_bytes_and_no_provider",
            metrics.model_bytes_loaded == 0
                && metrics.kv_bytes_loaded == 0
                && metrics.cache_bytes_opened == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0,
        ),
        (
            "no_runtime_command_or_server",
            metrics.server_started_count == 0 && metrics.command_armed_count == 0,
        ),
        (
            "no_hidden_cache_or_raw_logs",
            metrics.cache_reuse_allowed_count == 0
                && metrics.hidden_cache_authority_count == 0
                && metrics.raw_prompt_logged_count == 0
                && metrics.raw_token_logged_count == 0,
        ),
        (
            "no_l2_l3_live_70b_or_ssd_as_ram_claim",
            metrics.l2_green_claim_count == 0
                && metrics.l3_green_claim_count == 0
                && metrics.live_dense_70b_claim_count == 0
                && metrics.ssd_as_ram_claim_count == 0,
        ),
        (
            "packet_address_deterministic",
            packet.packet_address == reversed.packet_address,
        ),
        (
            "next_cursor_bound",
            KV_CACHE_IDENTITY_SALT_OFFLOAD_PROOF_PACKET_NEXT_CURSOR
                == "llama_cpp_slot_prompt_cache_command_card",
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
        5,
        "cards",
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
        "cache_bytes_opened",
        metrics.cache_bytes_opened,
        "==",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_bytes_loaded",
        metrics.kv_bytes_loaded,
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

    measurements.insert(
        "kv_cache_identity_packet_address".to_string(),
        Measurement {
            value: serde_json::json!(packet.packet_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "kv_cache_identity_packet_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!(format!(
                "{KV_CACHE_IDENTITY_SALT_OFFLOAD_PROOF_PACKET_CURSOR}:"
            )),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "kv_cache_identity_packet_address".to_string(),
        packet.packet_address.to_string().starts_with(&format!(
            "{KV_CACHE_IDENTITY_SALT_OFFLOAD_PROOF_PACKET_CURSOR}:"
        )),
    );

    measurements.insert(
        "next_cursor".to_string(),
        Measurement {
            value: serde_json::json!(KV_CACHE_IDENTITY_SALT_OFFLOAD_PROOF_PACKET_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_cursor".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!("llama_cpp_slot_prompt_cache_command_card"),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        KV_CACHE_IDENTITY_SALT_OFFLOAD_PROOF_PACKET_NEXT_CURSOR
            == "llama_cpp_slot_prompt_cache_command_card",
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
        notes: "Builds F-KVCacheIdentitySaltAndOffloadProofPacket as a metadata-only Pass 128 packet. Scope is T1/L1 only: source/search freshness, tokenizer/template/tool-schema digests, block parent hashes, cache salts, offload tiers, path scopes, rollback, RunEventLog, AnswerPacket, abstention, zero model/KV/cache/runtime/provider bytes, no server, no command, no L2/L3/product/live-70B/SSD-as-RAM claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn build_packet(
    cards: Vec<KvCacheIdentityCard>,
) -> Result<KvCacheIdentitySaltOffloadProofPacket, KvCacheIdentityError> {
    KvCacheIdentitySaltOffloadProofPacket::new(cards, PACKET_METADATA_BYTES, CREATED_AT_MS)
}

fn has_card(cards: &[KvCacheIdentityCard], card_id: &str) -> bool {
    cards.iter().any(|card| card.card_id == card_id)
}

fn red_pass(mutator: impl FnOnce(&mut Vec<KvCacheIdentityCard>)) -> bool {
    let mut cards = canonical_kv_cache_identity_cards();
    mutator(&mut cards);
    build_packet(cards).is_err()
}

fn red_fixture_results() -> Vec<(&'static str, bool)> {
    vec![
        ("missing_required_source_rejected", {
            let mut cards = canonical_kv_cache_identity_cards();
            cards.pop();
            build_packet(cards).is_err()
        }),
        ("duplicate_source_rejected", {
            let mut cards = canonical_kv_cache_identity_cards();
            cards[1].source = cards[0].source;
            build_packet(cards).is_err()
        }),
        (
            "missing_source_freshness_rejected",
            red_pass(|cards| cards[0].source_freshness_digest.clear()),
        ),
        (
            "missing_prompt_digest_rejected",
            red_pass(|cards| cards[0].prompt_assembly_digest.clear()),
        ),
        (
            "missing_tokenizer_digest_rejected",
            red_pass(|cards| cards[0].tokenizer_digest.clear()),
        ),
        (
            "missing_tool_schema_digest_rejected",
            red_pass(|cards| cards[0].tool_schema_digest.clear()),
        ),
        (
            "missing_parent_block_hash_rejected",
            red_pass(|cards| cards[0].parent_block_hash.clear()),
        ),
        (
            "missing_cache_salt_rejected",
            red_pass(|cards| cards[0].cache_salt_digest.clear()),
        ),
        (
            "missing_adapter_extras_rejected",
            red_pass(|cards| cards[0].adapter_ids_digest.clear()),
        ),
        (
            "kv_dtype_mismatch_rejected",
            red_pass(|cards| cards[0].kv_dtype_k.clear()),
        ),
        (
            "local_disk_path_escape_rejected",
            red_pass(|cards| cards[1].path_scope = "/tmp/kvcache".to_string()),
        ),
        (
            "remote_cache_bytes_rejected",
            red_pass(|cards| cards[0].byte_ledger.remote_cache_bytes = 1),
        ),
        (
            "cache_reuse_allowed_rejected",
            red_pass(|cards| cards[0].cache_reuse_allowed = true),
        ),
        (
            "hidden_cache_authority_rejected",
            red_pass(|cards| cards[0].hidden_cache_authority = true),
        ),
        (
            "raw_prompt_log_rejected",
            red_pass(|cards| cards[0].raw_prompt_logged = true),
        ),
        (
            "raw_token_log_rejected",
            red_pass(|cards| cards[0].raw_token_logged = true),
        ),
        (
            "server_started_rejected",
            red_pass(|cards| cards[0].server_started = true),
        ),
        (
            "command_armed_rejected",
            red_pass(|cards| cards[0].command_armed = true),
        ),
        (
            "l2_green_claim_rejected",
            red_pass(|cards| cards[0].l2_green_claimed = true),
        ),
        (
            "l3_green_claim_rejected",
            red_pass(|cards| cards[0].l3_green_claimed = true),
        ),
        (
            "live_dense_70b_claim_rejected",
            red_pass(|cards| cards[0].live_dense_70b_claimed = true),
        ),
        (
            "ssd_as_ram_claim_rejected",
            red_pass(|cards| cards[0].ssd_as_ram_claimed = true),
        ),
        (
            "model_bytes_loaded_rejected",
            red_pass(|cards| cards[0].byte_ledger.model_bytes_loaded = 1),
        ),
        (
            "kv_bytes_loaded_rejected",
            red_pass(|cards| cards[0].byte_ledger.kv_bytes_loaded = 1),
        ),
        (
            "cache_bytes_opened_rejected",
            red_pass(|cards| cards[0].byte_ledger.cache_bytes_opened = 1),
        ),
    ]
}
