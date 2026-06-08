//! `falsify_kv_cache_lineage_deletion_fence`
//!
//! Metadata-only witness for `F-KVCacheLineageDeletionFence`. It binds KV
//! cache reuse to lineage, privacy scope, tombstone/purge proof, rollback,
//! RunEventLog, AnswerPacket, and no-promotion boundaries without opening
//! cache, KV, model, runtime, source, benchmark, or product bytes.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    canonical_kv_cache_lineage_deletion_plan, KvCacheLineageBoundary, KvCacheLineageDeletionError,
    KvCacheLineageDeletionFence, KvCacheLineageDeletionPlan, KvCacheLineageLifecycle,
    KV_CACHE_LINEAGE_DELETION_FENCE_CURSOR, KV_CACHE_LINEAGE_DELETION_FENCE_ID,
    KV_CACHE_LINEAGE_DELETION_FENCE_NEXT_CURSOR, KV_OFFLOAD_TIER_BUDGET_ENVELOPE_ID,
};

const FALSIFIER_ID: &str = KV_CACHE_LINEAGE_DELETION_FENCE_ID;
const COMMAND: &str = "Tools/falsifiers/f_kv_cache_lineage_deletion_fence.sh";
const RESULT: &str = "artifacts/falsifiers/kv_cache_lineage_deletion_fence/result.json";
const FIXTURE_ID: &str = "kv_cache_lineage_deletion_fence_v1";
const CREATED_AT_MS: u64 = 1_779_331_200_000;
const FENCE_METADATA_BYTES: u64 = 128_000;
const UPSTREAM_RESULT: &str = "artifacts/falsifiers/kv_offload_tier_budget_envelope/result.json";

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
        "{FALSIFIER_ID}: overall_pass={} source_ref_count={} boundary_count={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["source_ref_count"].value,
        artifact.measurements["boundary_count"].value,
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
    let plan = canonical_kv_cache_lineage_deletion_plan();
    let fence = build_fence(plan.clone())?;
    let mut reversed = plan.clone();
    reversed.source_refs.reverse();
    reversed.boundaries.reverse();
    reversed.lifecycle_states.reverse();
    let reversed = build_fence(reversed)?;
    let metrics = fence.metrics();
    let red_results = red_fixture_results();
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        ("upstream_kv_offload_envelope_passed", upstream_present),
        (
            "source_refs_bound",
            metrics.source_ref_count == 6 && plan.source_ref_digest.starts_with("sha256:"),
        ),
        (
            "lineage_boundaries_bound",
            metrics.boundary_count == 10
                && plan
                    .boundaries
                    .contains(&KvCacheLineageBoundary::SourceBodyDigest)
                && plan
                    .boundaries
                    .contains(&KvCacheLineageBoundary::SearchResultDigest)
                && plan
                    .boundaries
                    .contains(&KvCacheLineageBoundary::PromptDigest)
                && plan
                    .boundaries
                    .contains(&KvCacheLineageBoundary::TokenizerDigest)
                && plan
                    .boundaries
                    .contains(&KvCacheLineageBoundary::ChatTemplateDigest)
                && plan
                    .boundaries
                    .contains(&KvCacheLineageBoundary::ToolSchemaDigest)
                && plan
                    .boundaries
                    .contains(&KvCacheLineageBoundary::ModelRevisionDigest)
                && plan
                    .boundaries
                    .contains(&KvCacheLineageBoundary::AdapterDigest)
                && plan.boundaries.contains(&KvCacheLineageBoundary::CacheSalt)
                && plan
                    .boundaries
                    .contains(&KvCacheLineageBoundary::PrivacyScope)
                && plan.boundary_digest.starts_with("sha256:"),
        ),
        (
            "lifecycle_bound",
            metrics.lifecycle_state_count == 3
                && plan
                    .lifecycle_states
                    .contains(&KvCacheLineageLifecycle::Active)
                && plan
                    .lifecycle_states
                    .contains(&KvCacheLineageLifecycle::Tombstoned)
                && plan
                    .lifecycle_states
                    .contains(&KvCacheLineageLifecycle::Purged),
        ),
        (
            "identity_digests_bound",
            [
                &plan.source_body_digest,
                &plan.search_result_digest,
                &plan.prompt_digest,
                &plan.tokenizer_digest,
                &plan.chat_template_digest,
                &plan.tool_schema_digest,
                &plan.model_revision_digest,
                &plan.adapter_digest,
                &plan.cache_salt_digest,
            ]
            .iter()
            .all(|digest| digest.starts_with("sha256:")),
        ),
        (
            "privacy_scope_and_allowlist_bound",
            plan.privacy_scope_ref.starts_with("scope:")
                && plan.trust_group_ref.starts_with("trust_group:")
                && plan.allowlist_before_reuse,
        ),
        (
            "stale_and_identity_drift_reuse_denied",
            plan.stale_source_reuse_denied && plan.identity_drift_reuse_denied,
        ),
        (
            "tombstone_purge_and_visible_deletion_bound",
            plan.tombstone_blocks_reuse && plan.purge_deletes_material && plan.deletion_is_visible,
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
                && plan.proof_refs.tombstone_ref.starts_with("tombstone:")
                && plan.proof_refs.purge_ref.starts_with("purge:")
                && plan.proof_refs.caveat_ref.starts_with("caveat:"),
        ),
        (
            "zero_loaded_or_opened_bytes",
            metrics.kv_bytes_loaded == 0
                && metrics.cache_bytes_opened == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.source_tree_bytes_opened == 0
                && metrics.benchmark_bytes_opened == 0
                && metrics.product_bytes_opened == 0
                && metrics.provider_calls_made == 0,
        ),
        (
            "no_cache_quality_fit_or_route_authority_claim",
            metrics.cache_hit_quality_claim_count == 0
                && metrics.cache_hit_model_fit_claim_count == 0
                && metrics.route_authority_count == 0
                && metrics.hidden_cache_authority_count == 0,
        ),
        (
            "no_command_server_or_raw_logs",
            metrics.command_armed_count == 0
                && metrics.server_started_count == 0
                && metrics.raw_prompt_logged_count == 0
                && metrics.raw_token_logged_count == 0,
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
            "lineage_fence_address_deterministic",
            fence.fence_address == reversed.fence_address,
        ),
        (
            "next_cursor_bound",
            KV_CACHE_LINEAGE_DELETION_FENCE_NEXT_CURSOR == "same_fixture_runtime_replay_envelope",
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
        (
            "boundary_count",
            metrics.boundary_count,
            "==",
            10,
            "boundaries",
        ),
        (
            "lifecycle_state_count",
            metrics.lifecycle_state_count,
            "==",
            3,
            "states",
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
        "lineage_fence_address".to_string(),
        Measurement {
            value: serde_json::json!(fence.fence_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "lineage_fence_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!(format!("{KV_CACHE_LINEAGE_DELETION_FENCE_CURSOR}:")),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "lineage_fence_address".to_string(),
        fence
            .fence_address
            .to_string()
            .starts_with(&format!("{KV_CACHE_LINEAGE_DELETION_FENCE_CURSOR}:")),
    );

    measurements.insert(
        "next_cursor".to_string(),
        Measurement {
            value: serde_json::json!(KV_CACHE_LINEAGE_DELETION_FENCE_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_cursor".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!("same_fixture_runtime_replay_envelope"),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        KV_CACHE_LINEAGE_DELETION_FENCE_NEXT_CURSOR == "same_fixture_runtime_replay_envelope",
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
        notes: "Builds F-KVCacheLineageDeletionFence as a metadata-only Pass 134 cache-lineage witness. Scope is T1/L1 only: vLLM prefix-cache salt/hash, LMCache local storage, llama.cpp slot save/restore/erase, prompt-cache, Agent Memory, and Epistemos body-read freshness motifs are fused into source/search/prompt/tokenizer/template/tool/model/adapter/salt/privacy boundaries, tombstone/purge proof, rollback, RunEventLog, AnswerPacket, abstention, zero KV/cache/model/runtime/source/benchmark/product/provider bytes, no command, no server, no hidden authority, no cache-hit quality/fit claim, no L2/L3/product/live-70B claim, and no SSD-as-RAM claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn build_fence(
    plan: KvCacheLineageDeletionPlan,
) -> Result<KvCacheLineageDeletionFence, KvCacheLineageDeletionError> {
    KvCacheLineageDeletionFence::new(plan, FENCE_METADATA_BYTES, CREATED_AT_MS)
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
        .is_some_and(|id| id == KV_OFFLOAD_TIER_BUDGET_ENVELOPE_ID)
        && value
            .get("overall_pass")
            .and_then(|value| value.as_bool())
            .unwrap_or(false)
}

fn red_pass(mutator: impl FnOnce(&mut KvCacheLineageDeletionPlan)) -> bool {
    let mut plan = canonical_kv_cache_lineage_deletion_plan();
    mutator(&mut plan);
    build_fence(plan).is_err()
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
            "missing_source_body_boundary_rejected",
            red_pass(|p| {
                p.boundaries
                    .retain(|b| *b != KvCacheLineageBoundary::SourceBodyDigest)
            }),
        ),
        (
            "missing_search_boundary_rejected",
            red_pass(|p| {
                p.boundaries
                    .retain(|b| *b != KvCacheLineageBoundary::SearchResultDigest)
            }),
        ),
        (
            "missing_prompt_boundary_rejected",
            red_pass(|p| {
                p.boundaries
                    .retain(|b| *b != KvCacheLineageBoundary::PromptDigest)
            }),
        ),
        (
            "missing_tokenizer_boundary_rejected",
            red_pass(|p| {
                p.boundaries
                    .retain(|b| *b != KvCacheLineageBoundary::TokenizerDigest)
            }),
        ),
        (
            "missing_template_boundary_rejected",
            red_pass(|p| {
                p.boundaries
                    .retain(|b| *b != KvCacheLineageBoundary::ChatTemplateDigest)
            }),
        ),
        (
            "missing_tool_schema_boundary_rejected",
            red_pass(|p| {
                p.boundaries
                    .retain(|b| *b != KvCacheLineageBoundary::ToolSchemaDigest)
            }),
        ),
        (
            "missing_model_boundary_rejected",
            red_pass(|p| {
                p.boundaries
                    .retain(|b| *b != KvCacheLineageBoundary::ModelRevisionDigest)
            }),
        ),
        (
            "missing_adapter_boundary_rejected",
            red_pass(|p| {
                p.boundaries
                    .retain(|b| *b != KvCacheLineageBoundary::AdapterDigest)
            }),
        ),
        (
            "missing_cache_salt_boundary_rejected",
            red_pass(|p| {
                p.boundaries
                    .retain(|b| *b != KvCacheLineageBoundary::CacheSalt)
            }),
        ),
        (
            "missing_privacy_scope_boundary_rejected",
            red_pass(|p| {
                p.boundaries
                    .retain(|b| *b != KvCacheLineageBoundary::PrivacyScope)
            }),
        ),
        (
            "bad_boundary_digest_rejected",
            red_pass(|p| p.boundary_digest = "bad".to_string()),
        ),
        (
            "missing_active_state_rejected",
            red_pass(|p| {
                p.lifecycle_states
                    .retain(|s| *s != KvCacheLineageLifecycle::Active)
            }),
        ),
        (
            "missing_tombstoned_state_rejected",
            red_pass(|p| {
                p.lifecycle_states
                    .retain(|s| *s != KvCacheLineageLifecycle::Tombstoned)
            }),
        ),
        (
            "missing_purged_state_rejected",
            red_pass(|p| {
                p.lifecycle_states
                    .retain(|s| *s != KvCacheLineageLifecycle::Purged)
            }),
        ),
        (
            "missing_source_body_digest_rejected",
            red_pass(|p| p.source_body_digest.clear()),
        ),
        (
            "missing_search_digest_rejected",
            red_pass(|p| p.search_result_digest.clear()),
        ),
        (
            "missing_prompt_digest_rejected",
            red_pass(|p| p.prompt_digest.clear()),
        ),
        (
            "missing_tokenizer_digest_rejected",
            red_pass(|p| p.tokenizer_digest.clear()),
        ),
        (
            "missing_template_digest_rejected",
            red_pass(|p| p.chat_template_digest.clear()),
        ),
        (
            "missing_tool_schema_digest_rejected",
            red_pass(|p| p.tool_schema_digest.clear()),
        ),
        (
            "missing_model_digest_rejected",
            red_pass(|p| p.model_revision_digest.clear()),
        ),
        (
            "missing_adapter_digest_rejected",
            red_pass(|p| p.adapter_digest.clear()),
        ),
        (
            "missing_cache_salt_digest_rejected",
            red_pass(|p| p.cache_salt_digest.clear()),
        ),
        (
            "missing_privacy_scope_ref_rejected",
            red_pass(|p| p.privacy_scope_ref.clear()),
        ),
        (
            "missing_trust_group_ref_rejected",
            red_pass(|p| p.trust_group_ref.clear()),
        ),
        (
            "missing_allowlist_rejected",
            red_pass(|p| p.allowlist_before_reuse = false),
        ),
        (
            "stale_source_reuse_rejected",
            red_pass(|p| p.stale_source_reuse_denied = false),
        ),
        (
            "identity_drift_reuse_rejected",
            red_pass(|p| p.identity_drift_reuse_denied = false),
        ),
        (
            "missing_tombstone_policy_rejected",
            red_pass(|p| p.tombstone_blocks_reuse = false),
        ),
        (
            "missing_purge_policy_rejected",
            red_pass(|p| p.purge_deletes_material = false),
        ),
        (
            "hidden_deletion_rejected",
            red_pass(|p| p.deletion_is_visible = false),
        ),
        (
            "missing_rollback_rejected",
            red_pass(|p| p.proof_refs.rollback_ref.clear()),
        ),
        (
            "missing_run_event_log_rejected",
            red_pass(|p| p.proof_refs.run_event_log_ref.clear()),
        ),
        (
            "missing_answer_packet_rejected",
            red_pass(|p| p.proof_refs.answer_packet_ref.clear()),
        ),
        (
            "missing_abstention_rejected",
            red_pass(|p| p.proof_refs.abstention_ref.clear()),
        ),
        (
            "missing_tombstone_ref_rejected",
            red_pass(|p| p.proof_refs.tombstone_ref.clear()),
        ),
        (
            "missing_purge_ref_rejected",
            red_pass(|p| p.proof_refs.purge_ref.clear()),
        ),
        (
            "missing_caveat_rejected",
            red_pass(|p| p.proof_refs.caveat_ref.clear()),
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
            "model_bytes_loaded_rejected",
            red_pass(|p| p.byte_ledger.model_bytes_loaded = 1),
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
            "product_bytes_opened_rejected",
            red_pass(|p| p.byte_ledger.product_bytes_opened = 1),
        ),
        (
            "provider_call_rejected",
            red_pass(|p| p.byte_ledger.provider_calls_made = 1),
        ),
        (
            "cache_hit_quality_claim_rejected",
            red_pass(|p| p.cache_hit_quality_claimed = true),
        ),
        (
            "cache_hit_model_fit_claim_rejected",
            red_pass(|p| p.cache_hit_model_fit_claimed = true),
        ),
        (
            "restored_cache_route_authority_rejected",
            red_pass(|p| p.restored_cache_route_authority = true),
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
            "ssd_as_ram_claim_rejected",
            red_pass(|p| p.ssd_as_ram_claimed = true),
        ),
        ("metadata_budget_rejected", {
            let plan = canonical_kv_cache_lineage_deletion_plan();
            KvCacheLineageDeletionFence::new(plan, 300_000, CREATED_AT_MS).is_err()
        }),
    ]
}
