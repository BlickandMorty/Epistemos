//! `falsify_kv_offload_tier_budget_envelope`
//!
//! Metadata-only witness for `F-KVOffloadTierBudgetEnvelope`. It binds KV
//! offload tier byte budgets, cleanup, rollback, RunEventLog, AnswerPacket,
//! and remote-denial policy without opening KV/cache/model/runtime bytes.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    canonical_kv_offload_tier_budget_plan, KvOffloadBudgetTier, KvOffloadRuntimeLane,
    KvOffloadTierBudgetEnvelope, KvOffloadTierBudgetError, KvOffloadTierBudgetPlan,
    KIVI_ASYMMETRIC_KV_STABILITY_SOURCE_CARD_ID, KV_OFFLOAD_TIER_BUDGET_ENVELOPE_CURSOR,
    KV_OFFLOAD_TIER_BUDGET_ENVELOPE_ID, KV_OFFLOAD_TIER_BUDGET_ENVELOPE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = KV_OFFLOAD_TIER_BUDGET_ENVELOPE_ID;
const COMMAND: &str = "Tools/falsifiers/f_kv_offload_tier_budget_envelope.sh";
const RESULT: &str = "artifacts/falsifiers/kv_offload_tier_budget_envelope/result.json";
const FIXTURE_ID: &str = "kv_offload_tier_budget_envelope_v1";
const CREATED_AT_MS: u64 = 1_779_244_800_000;
const ENVELOPE_METADATA_BYTES: u64 = 128_000;
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/kivi_asymmetric_kv_stability_source_card/result.json";

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
        "{FALSIFIER_ID}: overall_pass={} source_ref_count={} tier_count={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["source_ref_count"].value,
        artifact.measurements["tier_count"].value,
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
    let upstream_present = upstream_artifact_passes(Path::new(UPSTREAM_RESULT));
    let plan = canonical_kv_offload_tier_budget_plan();
    let envelope = build_envelope(plan.clone())?;
    let mut reversed = plan.clone();
    reversed.source_refs.reverse();
    reversed.tiers.reverse();
    let reversed = build_envelope(reversed)?;
    let metrics = envelope.metrics();
    let red_results = red_fixture_results();
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        ("upstream_kivi_source_card_passed", upstream_present),
        (
            "source_refs_bound",
            metrics.source_ref_count == 6 && plan.source_ref_digest.starts_with("sha256:"),
        ),
        (
            "tier_set_bound",
            metrics.tier_count == 4
                && plan.tiers.contains(&KvOffloadBudgetTier::HotResidentUma)
                && plan.tiers.contains(&KvOffloadBudgetTier::CpuPinnedCache)
                && plan.tiers.contains(&KvOffloadBudgetTier::LocalDiskCache)
                && plan.tiers.contains(&KvOffloadBudgetTier::RemoteDenied),
        ),
        (
            "byte_envelope_bound",
            metrics.declared_hot_resident_bytes > 0
                && metrics.declared_cpu_cache_bytes > 0
                && metrics.declared_local_disk_cache_bytes > 0
                && metrics.declared_runtime_workspace_bytes > 0
                && metrics.declared_app_headroom_bytes >= 2 * 1024 * 1024 * 1024
                && metrics.declared_remote_cache_bytes == 0,
        ),
        (
            "cpu_gateway_and_prefetch_policy_bound",
            plan.cpu_tier_primary_gateway_required
                && plan.local_disk_async_put_required
                && plan.local_disk_prefetch_requires_cpu_cache
                && plan.local_disk_cache_root.starts_with("cache_root:"),
        ),
        (
            "remote_tier_denied",
            plan.remote_tiers_denied
                && plan.remote_tier_denial_ref.starts_with("denied:")
                && metrics.remote_cache_allowed_count == 0,
        ),
        (
            "cleanup_teardown_cache_miss_bound",
            plan.eviction_policy.starts_with("policy:")
                && plan.cleanup_policy.starts_with("cleanup:")
                && plan.teardown_policy.starts_with("teardown:")
                && plan.cache_miss_policy.starts_with("cache_miss:")
                && plan.compatibility_fence_ref.starts_with("compatibility:"),
        ),
        (
            "proof_refs_bound",
            plan.proof_refs.rollback_ref.starts_with("rollback:")
                && plan
                    .proof_refs
                    .run_event_log_ref
                    .starts_with("run_event_log:")
                && plan
                    .proof_refs
                    .answer_packet_ref
                    .starts_with("answer_packet:")
                && plan.proof_refs.abstention_ref.starts_with("abstain:")
                && plan.proof_refs.caveat_ref.starts_with("caveat:"),
        ),
        (
            "zero_loaded_or_opened_bytes",
            metrics.model_bytes_loaded == 0
                && metrics.kv_bytes_loaded == 0
                && metrics.cache_bytes_opened == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.source_tree_bytes_opened == 0
                && metrics.benchmark_bytes_opened == 0
                && metrics.product_bytes_opened == 0
                && metrics.provider_calls_made == 0,
        ),
        (
            "no_runtime_command_or_hidden_authority",
            plan.runtime_lane == KvOffloadRuntimeLane::MetadataOnly
                && metrics.command_armed_count == 0
                && metrics.server_started_count == 0
                && metrics.route_authority_allowed_count == 0
                && metrics.hidden_cache_authority_count == 0,
        ),
        (
            "no_fit_disk_as_ram_or_raw_log_claim",
            metrics.model_fit_claim_count == 0
                && metrics.local_disk_as_ram_claim_count == 0
                && metrics.raw_prompt_logged_count == 0
                && metrics.raw_token_logged_count == 0,
        ),
        (
            "no_mas_l2_l3_live_70b_claim",
            metrics.mas_promotion_count == 0
                && metrics.l2_green_claim_count == 0
                && metrics.l3_green_claim_count == 0
                && metrics.live_dense_70b_claim_count == 0,
        ),
        (
            "offload_envelope_address_deterministic",
            envelope.envelope_address == reversed.envelope_address,
        ),
        (
            "next_cursor_bound",
            KV_OFFLOAD_TIER_BUDGET_ENVELOPE_NEXT_CURSOR == "kv_cache_lineage_deletion_fence",
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

    for (name, value, op, threshold, unit) in [
        ("plan_count", metrics.plan_count, "==", 1, "plans"),
        (
            "source_ref_count",
            metrics.source_ref_count,
            "==",
            6,
            "sources",
        ),
        ("tier_count", metrics.tier_count, "==", 4, "tiers"),
        (
            "declared_hot_resident_bytes",
            metrics.declared_hot_resident_bytes,
            ">",
            0,
            "bytes",
        ),
        (
            "declared_cpu_cache_bytes",
            metrics.declared_cpu_cache_bytes,
            ">",
            0,
            "bytes",
        ),
        (
            "declared_local_disk_cache_bytes",
            metrics.declared_local_disk_cache_bytes,
            ">",
            0,
            "bytes",
        ),
        (
            "declared_app_headroom_bytes",
            metrics.declared_app_headroom_bytes,
            ">=",
            2 * 1024 * 1024 * 1024,
            "bytes",
        ),
        (
            "declared_remote_cache_bytes",
            metrics.declared_remote_cache_bytes,
            "==",
            0,
            "bytes",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            "==",
            red_results.len() as u64,
            "fixtures",
        ),
        ("kv_bytes_loaded", metrics.kv_bytes_loaded, "==", 0, "bytes"),
        (
            "cache_bytes_opened",
            metrics.cache_bytes_opened,
            "==",
            0,
            "bytes",
        ),
        (
            "runtime_bytes_loaded",
            metrics.runtime_bytes_loaded,
            "==",
            0,
            "bytes",
        ),
    ] {
        add_u64_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            value,
            op,
            threshold,
            unit,
        );
    }

    measurements.insert(
        "offload_envelope_address".to_string(),
        Measurement {
            value: serde_json::json!(envelope.envelope_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "offload_envelope_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!(format!("{KV_OFFLOAD_TIER_BUDGET_ENVELOPE_CURSOR}:")),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "offload_envelope_address".to_string(),
        envelope
            .envelope_address
            .to_string()
            .starts_with(&format!("{KV_OFFLOAD_TIER_BUDGET_ENVELOPE_CURSOR}:")),
    );

    measurements.insert(
        "next_cursor".to_string(),
        Measurement {
            value: serde_json::json!(KV_OFFLOAD_TIER_BUDGET_ENVELOPE_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_cursor".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!("kv_cache_lineage_deletion_fence"),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        KV_OFFLOAD_TIER_BUDGET_ENVELOPE_NEXT_CURSOR == "kv_cache_lineage_deletion_fence",
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
        notes: "Builds F-KVOffloadTierBudgetEnvelope as a metadata-only Pass 133 budget witness. Scope is T1/L1 only: LMCache/vLLM/KVSwap/KIVI source facts are fused into explicit hot/CPU/local-disk/remote-denied tier budgets, app headroom, cleanup, teardown, cache-miss policy, rollback, RunEventLog, AnswerPacket, abstention, zero KV/cache/model/runtime/source/benchmark/product bytes, no command, no server, no hidden authority, no local-disk-as-RAM, no L2/L3/product/live-70B claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn build_envelope(
    plan: KvOffloadTierBudgetPlan,
) -> Result<KvOffloadTierBudgetEnvelope, KvOffloadTierBudgetError> {
    KvOffloadTierBudgetEnvelope::new(plan, ENVELOPE_METADATA_BYTES, CREATED_AT_MS)
}

fn upstream_artifact_passes(path: &Path) -> bool {
    let Ok(bytes) = std::fs::read(path) else {
        return false;
    };
    let Ok(value) = serde_json::from_slice::<serde_json::Value>(&bytes) else {
        return false;
    };
    value
        .get("falsifier_id")
        .and_then(|value| value.as_str())
        .is_some_and(|id| id == KIVI_ASYMMETRIC_KV_STABILITY_SOURCE_CARD_ID)
        && value
            .get("overall_pass")
            .and_then(|value| value.as_bool())
            .unwrap_or(false)
}

fn red_pass(mutator: impl FnOnce(&mut KvOffloadTierBudgetPlan)) -> bool {
    let mut plan = canonical_kv_offload_tier_budget_plan();
    mutator(&mut plan);
    build_envelope(plan).is_err()
}

fn red_fixture_results() -> Vec<(&'static str, bool)> {
    vec![
        (
            "missing_upstream_rejected",
            red_pass(|p| p.upstream_falsifier_id.clear()),
        ),
        (
            "missing_source_refs_rejected",
            red_pass(|p| {
                p.source_refs.pop();
            }),
        ),
        (
            "bad_source_digest_rejected",
            red_pass(|p| p.source_ref_digest = "bad".to_string()),
        ),
        (
            "runtime_lane_rejected",
            red_pass(|p| p.runtime_lane = KvOffloadRuntimeLane::VllmResearchServer),
        ),
        (
            "missing_hot_tier_rejected",
            red_pass(|p| {
                p.tiers
                    .retain(|t| *t != KvOffloadBudgetTier::HotResidentUma)
            }),
        ),
        (
            "missing_cpu_tier_rejected",
            red_pass(|p| {
                p.tiers
                    .retain(|t| *t != KvOffloadBudgetTier::CpuPinnedCache)
            }),
        ),
        (
            "missing_disk_tier_rejected",
            red_pass(|p| {
                p.tiers
                    .retain(|t| *t != KvOffloadBudgetTier::LocalDiskCache)
            }),
        ),
        (
            "missing_remote_denial_tier_rejected",
            red_pass(|p| p.tiers.retain(|t| *t != KvOffloadBudgetTier::RemoteDenied)),
        ),
        (
            "zero_hot_budget_rejected",
            red_pass(|p| p.byte_ledger.declared_hot_resident_bytes = 0),
        ),
        (
            "zero_cpu_budget_rejected",
            red_pass(|p| p.byte_ledger.declared_cpu_cache_bytes = 0),
        ),
        (
            "zero_disk_budget_rejected",
            red_pass(|p| p.byte_ledger.declared_local_disk_cache_bytes = 0),
        ),
        (
            "remote_budget_rejected",
            red_pass(|p| p.byte_ledger.declared_remote_cache_bytes = 1),
        ),
        (
            "missing_app_headroom_rejected",
            red_pass(|p| p.byte_ledger.declared_app_headroom_bytes = 0),
        ),
        (
            "missing_workspace_budget_rejected",
            red_pass(|p| p.byte_ledger.declared_runtime_workspace_bytes = 0),
        ),
        (
            "zero_chunk_size_rejected",
            red_pass(|p| p.chunk_size_tokens = 0),
        ),
        (
            "missing_cpu_gateway_rejected",
            red_pass(|p| p.cpu_tier_primary_gateway_required = false),
        ),
        (
            "missing_async_put_rejected",
            red_pass(|p| p.local_disk_async_put_required = false),
        ),
        (
            "missing_prefetch_cpu_cache_rejected",
            red_pass(|p| p.local_disk_prefetch_requires_cpu_cache = false),
        ),
        (
            "bad_cache_root_rejected",
            red_pass(|p| p.local_disk_cache_root = "/tmp/cache".to_string()),
        ),
        (
            "remote_allowed_rejected",
            red_pass(|p| {
                p.remote_tiers_denied = false;
                p.remote_cache_allowed = true;
            }),
        ),
        (
            "missing_eviction_policy_rejected",
            red_pass(|p| p.eviction_policy.clear()),
        ),
        (
            "missing_cleanup_policy_rejected",
            red_pass(|p| p.cleanup_policy.clear()),
        ),
        (
            "missing_teardown_policy_rejected",
            red_pass(|p| p.teardown_policy.clear()),
        ),
        (
            "missing_cache_miss_policy_rejected",
            red_pass(|p| p.cache_miss_policy.clear()),
        ),
        (
            "missing_compatibility_fence_rejected",
            red_pass(|p| p.compatibility_fence_ref.clear()),
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
            "kv_bytes_loaded_rejected",
            red_pass(|p| p.byte_ledger.kv_bytes_loaded = 1),
        ),
        (
            "cache_bytes_opened_rejected",
            red_pass(|p| p.byte_ledger.cache_bytes_opened = 1),
        ),
        (
            "runtime_bytes_loaded_rejected",
            red_pass(|p| p.byte_ledger.runtime_bytes_loaded = 1),
        ),
        (
            "source_tree_bytes_opened_rejected",
            red_pass(|p| p.byte_ledger.source_tree_bytes_opened = 1),
        ),
        (
            "benchmark_bytes_opened_rejected",
            red_pass(|p| p.byte_ledger.benchmark_bytes_opened = 1),
        ),
        (
            "model_fit_claim_rejected",
            red_pass(|p| p.model_fit_claimed = true),
        ),
        (
            "local_disk_as_ram_claim_rejected",
            red_pass(|p| p.local_disk_as_ram_claimed = true),
        ),
        (
            "route_authority_rejected",
            red_pass(|p| p.route_authority_allowed = true),
        ),
        (
            "hidden_cache_authority_rejected",
            red_pass(|p| p.hidden_cache_authority = true),
        ),
        (
            "command_armed_rejected",
            red_pass(|p| p.command_armed = true),
        ),
        (
            "server_started_rejected",
            red_pass(|p| p.server_started = true),
        ),
        (
            "raw_prompt_log_rejected",
            red_pass(|p| p.raw_prompt_logged = true),
        ),
        (
            "raw_token_log_rejected",
            red_pass(|p| p.raw_token_logged = true),
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
            "metadata_budget_rejected",
            KvOffloadTierBudgetEnvelope::new(
                canonical_kv_offload_tier_budget_plan(),
                193 * 1024,
                CREATED_AT_MS,
            )
            .is_err(),
        ),
        (
            "byte_ledger_product_open_rejected",
            red_pass(|p| p.byte_ledger.product_bytes_opened = 1),
        ),
        (
            "provider_call_rejected",
            red_pass(|p| p.byte_ledger.provider_calls_made = 1),
        ),
    ]
}
