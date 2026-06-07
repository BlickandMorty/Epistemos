//! `falsify_kv_source_card_fork_and_daemon_boundary`
//!
//! Metadata-only witness for `F-KVSourceCard-ForkAndDaemonBoundary`. It
//! consumes the `F-KVRuntimeSourceCard` source-card artifact and classifies
//! server/daemon/distributed/command/research KV runtime motifs before any of
//! them can affect RuntimeRouter/System G. No repositories are cloned, no
//! commands execute, and no model/KV/runtime/index bytes are opened.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::KV_SOURCE_CARD_FORK_AND_DAEMON_BOUNDARY_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    CompressedModelPromotionTier, KvBoundaryByteScope, KvBoundaryClassification,
    KvBoundaryDecision, KvBoundaryProofRefs, KvBoundaryRuntimeShape,
    KvSourceCardForkDaemonBoundaryPlan, ProStatus, ProductBuild,
    KV_SOURCE_CARD_FORK_AND_DAEMON_BOUNDARY_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-KVSourceCard-ForkAndDaemonBoundary";
const FIXTURE_ID: &str = "kv_source_card_fork_and_daemon_boundary_v1";
const COMMAND: &str = "Tools/falsifiers/f_kv_source_card_fork_and_daemon_boundary.sh";
const RESULT: &str = "artifacts/falsifiers/kv_source_card_fork_and_daemon_boundary/result.json";
const CREATED_AT_MS: u64 = 1_779_140_000_000;
const PLAN_METADATA_BYTES: u64 = 128_000;
const UPSTREAM_REF: &str =
    "artifact:falsifiers/kv_runtime_source_card/result.json#F-KVRuntimeSourceCard";
const UPSTREAM_RESULT: &str = "artifacts/falsifiers/kv_runtime_source_card/result.json";

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
        "{FALSIFIER_ID}: overall_pass={} decision_count={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["kv_boundary_decision_count"].value,
        artifact.measurements["red_fixture_rejection_count"].value,
        artifact.measurements["next_cursor"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let upstream_pass = upstream_kv_runtime_source_card_pass();
    let decisions = accepted_decisions();
    let plan = build_plan(decisions.clone())?;
    let reversed = build_plan(decisions.iter().cloned().rev().collect())?;
    let metrics = plan.metrics();
    let red_results = red_fixture_results(&decisions);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        ("upstream_kv_runtime_source_card_pass", upstream_pass),
        (
            "accepted_boundary_pack_present",
            has_source(&decisions, "vllm_paged_attention")
                && has_source(&decisions, "lmcache_reusable_kv")
                && has_source(&decisions, "sglang_hicache_radix")
                && has_source(&decisions, "ktransformers_heterogeneous_prefix")
                && has_source(&decisions, "flexllmgen_offload_optimizer")
                && has_source(&decisions, "powerinfer_activation_locality")
                && has_source(&decisions, "kivi_asymmetric_kv")
                && has_source(&decisions, "transformers_quantized_cache")
                && has_source(&decisions, "llamacpp_prompt_cache"),
        ),
        (
            "every_source_card_classified",
            metrics.source_card_count == 9
                && metrics.decision_count == 9
                && metrics.classification_count >= 4,
        ),
        (
            "server_daemon_quarantined",
            metrics.quarantine_server_daemon_count >= 2
                && metrics.server_or_daemon_count >= 2
                && red_pass(&red_results, "server_as_product")
                && red_pass(&red_results, "daemon_as_command"),
        ),
        (
            "remote_distributed_denied",
            metrics.remote_or_distributed_denied_count >= 1
                && metrics.remote_or_distributed_count >= 1
                && red_pass(&red_results, "remote_as_local"),
        ),
        (
            "owner_approved_command_unarmed",
            metrics.owner_approved_command_count == 1
                && red_pass(&red_results, "owner_command_armed")
                && red_pass(&red_results, "owner_command_executed"),
        ),
        (
            "research_only_not_product",
            metrics.research_only_count >= 5 && red_pass(&red_results, "research_only_product"),
        ),
        (
            "mas_pro_boundary_bound",
            plan.product_build == ProductBuild::Pro
                && plan.pro_status == ProStatus::ResearchCandidate
                && red_pass(&red_results, "mas_live_server"),
        ),
        (
            "no_product_runtime_or_route",
            plan.product_route_blocked
                && red_pass(&red_results, "product_route_enabled")
                && red_pass(&red_results, "l2_l3_promotion_claim"),
        ),
        (
            "zero_model_kv_runtime_provider_source_product_bytes",
            metrics.model_bytes_loaded == 0
                && metrics.kv_bytes_loaded == 0
                && metrics.index_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.source_tree_bytes_read == 0
                && metrics.provider_calls_made == 0
                && metrics.product_files_copied == 0
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "kv_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "source_tree_bytes_read")
                && red_pass(&red_results, "provider_call_made")
                && red_pass(&red_results, "product_file_copied"),
        ),
        (
            "zero_command_and_benchmark_execution",
            metrics.command_executions == 0
                && metrics.benchmark_runs == 0
                && red_pass(&red_results, "command_execution")
                && red_pass(&red_results, "benchmark_run"),
        ),
        (
            "hidden_authority_rejected",
            plan.hidden_authority_blocked
                && red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "hidden_cache_authority"),
        ),
        (
            "no_l2_l3_live70b_ssd",
            red_pass(&red_results, "l2_l3_promotion_claim")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "proof_refs_bound",
            decisions.iter().all(|decision| {
                decision.proof_refs.falsifier_ref.starts_with("falsifier:")
                    && decision.proof_refs.rollback_ref.starts_with("rollback:")
                    && decision
                        .proof_refs
                        .run_event_log_ref
                        .starts_with("run_event_log:")
                    && decision
                        .proof_refs
                        .answer_packet_ref
                        .starts_with("answer_packet:")
                    && decision
                        .proof_refs
                        .compatibility_fence_ref
                        .starts_with("compat:")
                    && decision
                        .proof_refs
                        .privacy_policy_ref
                        .starts_with("privacy:")
                    && decision
                        .proof_refs
                        .mas_pro_boundary_ref
                        .starts_with("mas_pro:")
                    && decision.proof_refs.boundary_ref.starts_with("boundary:")
            }) && red_pass(&red_results, "bad_proof_ref_prefix"),
        ),
        (
            "plan_address_deterministic",
            plan.plan_address == reversed.plan_address,
        ),
        (
            "next_cursor_bound",
            KV_SOURCE_CARD_FORK_AND_DAEMON_BOUNDARY_NEXT_CURSOR
                == "hardware_tiered_model_catalog_source_card",
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
        "kv_boundary_decision_count",
        metrics.decision_count,
        ">=",
        9,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "classification_count",
        metrics.classification_count,
        ">=",
        4,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_shape_count",
        metrics.runtime_shape_count,
        ">=",
        6,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "quarantine_server_daemon_count",
        metrics.quarantine_server_daemon_count,
        ">=",
        2,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "remote_denied_count",
        metrics.remote_or_distributed_denied_count,
        ">=",
        1,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "owner_command_count",
        metrics.owner_approved_command_count,
        "==",
        1,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "research_only_count",
        metrics.research_only_count,
        ">=",
        5,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_count",
        red_results.len() as u64,
        ">=",
        24,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_rejection_count",
        red_fixture_rejection_count,
        "==",
        red_results.len() as u64,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metadata_bytes_read",
        metrics.metadata_bytes_read,
        "<=",
        128 * 1024,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "plan_metadata_bytes",
        PLAN_METADATA_BYTES,
        "<=",
        384 * 1024,
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
        "command_executions",
        metrics.command_executions,
        "==",
        0,
        "count",
    );

    measurements.insert(
        "kv_boundary_address".to_string(),
        Measurement {
            value: serde_json::json!(plan.address()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "kv_boundary_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("kv_source_card_fork_and_daemon_boundary:"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "kv_boundary_address".to_string(),
        plan.address()
            .starts_with("kv_source_card_fork_and_daemon_boundary:")
            && plan.address().contains('@'),
    );
    measurements.insert(
        "next_cursor".to_string(),
        Measurement {
            value: serde_json::json!(KV_SOURCE_CARD_FORK_AND_DAEMON_BOUNDARY_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_cursor".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!("hardware_tiered_model_catalog_source_card"),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        KV_SOURCE_CARD_FORK_AND_DAEMON_BOUNDARY_NEXT_CURSOR
            == "hardware_tiered_model_catalog_source_card",
    );

    for axis in KV_SOURCE_CARD_FORK_AND_DAEMON_BOUNDARY_AXES {
        pass_per_axis.entry((*axis).to_string()).or_insert(false);
    }

    let artifact = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: ArtifactKind::PrimaryWitness,
        command: COMMAND.to_string(),
        commit_sha: current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Primary,
        anomalies: vec![serde_json::json!({
            "kind": "scope_guard",
            "detail": "metadata-only KV fork/daemon boundary; no repository clone, source-tree read, command execution, benchmark, daemon, server, provider call, product copy, model bytes, KV bytes, runtime bytes, or L2/L3 promotion"
        })],
        notes: "Builds F-KVSourceCard-ForkAndDaemonBoundary from F-KVRuntimeSourceCard. Server and daemon motifs stay quarantine references, remote/distributed motifs are denied from local product routes, llama.cpp prompt-cache command work remains owner-approval-pending and unarmed, and research-only motifs cannot become hidden route or cache authority.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(artifact)
}

fn upstream_kv_runtime_source_card_pass() -> bool {
    let Ok(bytes) = read_repo_relative(UPSTREAM_RESULT) else {
        return false;
    };
    let Ok(value) = serde_json::from_slice::<serde_json::Value>(&bytes) else {
        return false;
    };
    value
        .get("falsifier_id")
        .and_then(serde_json::Value::as_str)
        == Some("F-KVRuntimeSourceCard")
        && value
            .get("overall_pass")
            .and_then(serde_json::Value::as_bool)
            == Some(true)
}

fn read_repo_relative(path: &str) -> std::io::Result<Vec<u8>> {
    let path = Path::new(path);
    for candidate in [PathBuf::from(path), PathBuf::from("..").join(path)] {
        if candidate.exists() {
            return std::fs::read(candidate);
        }
    }
    std::fs::read(path)
}

fn build_plan(
    decisions: Vec<KvBoundaryDecision>,
) -> Result<KvSourceCardForkDaemonBoundaryPlan, agent_core::uas::KvBoundaryError> {
    KvSourceCardForkDaemonBoundaryPlan::new(
        UPSTREAM_REF,
        decisions,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        CompressedModelPromotionTier::T1L1Metadata,
        PLAN_METADATA_BYTES,
        true,
        true,
        true,
        true,
        true,
        true,
        CREATED_AT_MS,
    )
}

fn has_source(decisions: &[KvBoundaryDecision], source_card_id: &str) -> bool {
    decisions
        .iter()
        .any(|decision| decision.source_card_id == source_card_id)
}

fn red_pass(results: &[(&'static str, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(result_name, _)| *result_name == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

fn red_fixture_results(decisions: &[KvBoundaryDecision]) -> Vec<(&'static str, bool)> {
    vec![
        ("empty_plan", build_plan(Vec::new()).is_err()),
        (
            "duplicate_decision_id",
            reject_decisions(decisions, |decisions| {
                decisions[1].decision_id = decisions[0].decision_id.clone()
            }),
        ),
        (
            "duplicate_source_card_id",
            reject_decisions(decisions, |decisions| {
                decisions[1].source_card_id = decisions[0].source_card_id.clone()
            }),
        ),
        (
            "unknown_source_card_id",
            reject_decisions(decisions, |decisions| {
                decisions[0].source_card_id = "unknown_kv_runtime".to_string()
            }),
        ),
        (
            "bad_upstream_ref",
            KvSourceCardForkDaemonBoundaryPlan::new(
                "artifact:falsifiers/unknown/result.json",
                decisions.to_vec(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                CompressedModelPromotionTier::T1L1Metadata,
                PLAN_METADATA_BYTES,
                true,
                true,
                true,
                true,
                true,
                true,
                CREATED_AT_MS,
            )
            .is_err(),
        ),
        (
            "server_as_product",
            reject_decisions(decisions, |decisions| {
                decisions[0].classification = KvBoundaryClassification::ProductEligibleInProcess
            }),
        ),
        (
            "daemon_as_command",
            reject_decisions(decisions, |decisions| {
                decisions[1].classification = KvBoundaryClassification::OwnerApprovedCommand;
                decisions[1].owner_approval_ref =
                    Some("owner_approval:pending:lmcache".to_string());
            }),
        ),
        (
            "remote_as_local",
            reject_decisions(decisions, |decisions| {
                decisions[2].classification = KvBoundaryClassification::OwnerApprovedCommand;
                decisions[2].owner_approval_ref = Some("owner_approval:pending:sglang".to_string());
            }),
        ),
        (
            "owner_command_armed",
            reject_source(decisions, "llamacpp_prompt_cache", |decision| {
                decision.command_armed = true
            }),
        ),
        (
            "owner_command_executed",
            reject_source(decisions, "llamacpp_prompt_cache", |decision| {
                decision.command_executed = true
            }),
        ),
        (
            "owner_command_missing_approval",
            reject_source(decisions, "llamacpp_prompt_cache", |decision| {
                decision.owner_approval_ref = None
            }),
        ),
        (
            "research_only_product",
            reject_source(decisions, "kivi_asymmetric_kv", |decision| {
                decision.product_route_enabled = true
            }),
        ),
        (
            "product_route_enabled",
            reject_decisions(decisions, |decisions| {
                decisions[4].product_route_enabled = true
            }),
        ),
        (
            "mas_live_server",
            reject_decisions(decisions, |decisions| decisions[0].mas_eligible_live = true),
        ),
        (
            "hidden_route_authority",
            reject_decisions(decisions, |decisions| {
                decisions[3].hidden_route_authority = true
            }),
        ),
        (
            "hidden_cache_authority",
            reject_decisions(decisions, |decisions| {
                decisions[3].hidden_cache_authority = true
            }),
        ),
        (
            "model_bytes_loaded",
            reject_decisions(decisions, |decisions| {
                decisions[0].byte_scope.model_bytes_loaded = 1
            }),
        ),
        (
            "kv_bytes_loaded",
            reject_decisions(decisions, |decisions| {
                decisions[0].byte_scope.kv_bytes_loaded = 1
            }),
        ),
        (
            "runtime_bytes_loaded",
            reject_decisions(decisions, |decisions| {
                decisions[0].byte_scope.runtime_bytes_loaded = 1
            }),
        ),
        (
            "index_bytes_loaded",
            reject_decisions(decisions, |decisions| {
                decisions[0].byte_scope.index_bytes_loaded = 1
            }),
        ),
        (
            "source_tree_bytes_read",
            reject_decisions(decisions, |decisions| {
                decisions[0].byte_scope.source_tree_bytes_read = 1
            }),
        ),
        (
            "provider_call_made",
            reject_decisions(decisions, |decisions| {
                decisions[0].byte_scope.provider_calls_made = 1
            }),
        ),
        (
            "product_file_copied",
            reject_decisions(decisions, |decisions| {
                decisions[0].byte_scope.product_files_copied = 1
            }),
        ),
        (
            "command_execution",
            reject_decisions(decisions, |decisions| {
                decisions[8].byte_scope.command_executions = 1
            }),
        ),
        (
            "benchmark_run",
            reject_decisions(decisions, |decisions| {
                decisions[4].byte_scope.benchmark_runs = 1
            }),
        ),
        (
            "l2_l3_promotion_claim",
            reject_decisions(decisions, |decisions| {
                decisions[0].l2_l3_promotion_claim = true
            }),
        ),
        (
            "live_dense_70b_claim",
            reject_decisions(decisions, |decisions| {
                decisions[0].live_dense_70b_claim = true
            }),
        ),
        (
            "ssd_as_ram_claim",
            reject_decisions(decisions, |decisions| decisions[0].ssd_as_ram_claim = true),
        ),
        (
            "bad_proof_ref_prefix",
            reject_decisions(decisions, |decisions| {
                decisions[0].proof_refs.boundary_ref = "kv-boundary:hidden".to_string()
            }),
        ),
        (
            "metadata_budget_exceeded",
            reject_decisions(decisions, |decisions| {
                decisions[0].byte_scope.metadata_bytes_read = 49 * 1024
            }),
        ),
        (
            "plan_metadata_budget_exceeded",
            KvSourceCardForkDaemonBoundaryPlan::new(
                UPSTREAM_REF,
                decisions.to_vec(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                CompressedModelPromotionTier::T1L1Metadata,
                385 * 1024,
                true,
                true,
                true,
                true,
                true,
                true,
                CREATED_AT_MS,
            )
            .is_err(),
        ),
        (
            "layer_separation_missing",
            KvSourceCardForkDaemonBoundaryPlan::new(
                UPSTREAM_REF,
                decisions.to_vec(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                CompressedModelPromotionTier::T1L1Metadata,
                PLAN_METADATA_BYTES,
                false,
                true,
                true,
                true,
                true,
                true,
                CREATED_AT_MS,
            )
            .is_err(),
        ),
        (
            "pro_live_status_rejected",
            KvSourceCardForkDaemonBoundaryPlan::new(
                UPSTREAM_REF,
                decisions.to_vec(),
                ProductBuild::Pro,
                ProStatus::Live,
                CompressedModelPromotionTier::T1L1Metadata,
                PLAN_METADATA_BYTES,
                true,
                true,
                true,
                true,
                true,
                true,
                CREATED_AT_MS,
            )
            .is_err(),
        ),
    ]
}

fn reject_decisions(
    decisions: &[KvBoundaryDecision],
    mutate: impl FnOnce(&mut Vec<KvBoundaryDecision>),
) -> bool {
    let mut mutated = decisions.to_vec();
    mutate(&mut mutated);
    build_plan(mutated).is_err()
}

fn reject_source(
    decisions: &[KvBoundaryDecision],
    source_card_id: &str,
    mutate: impl FnOnce(&mut KvBoundaryDecision),
) -> bool {
    let mut mutated = decisions.to_vec();
    if let Some(decision) = mutated
        .iter_mut()
        .find(|decision| decision.source_card_id == source_card_id)
    {
        mutate(decision);
    }
    build_plan(mutated).is_err()
}

fn accepted_decisions() -> Vec<KvBoundaryDecision> {
    vec![
        decision(
            "vllm_paged_attention",
            KvBoundaryRuntimeShape::ServerFramework,
            KvBoundaryClassification::QuarantineServerDaemon,
            true,
            false,
            None,
        ),
        decision(
            "lmcache_reusable_kv",
            KvBoundaryRuntimeShape::DaemonCacheLayer,
            KvBoundaryClassification::QuarantineServerDaemon,
            true,
            false,
            None,
        ),
        decision(
            "sglang_hicache_radix",
            KvBoundaryRuntimeShape::DistributedCluster,
            KvBoundaryClassification::RemoteOrDistributedDenied,
            false,
            true,
            None,
        ),
        decision(
            "ktransformers_heterogeneous_prefix",
            KvBoundaryRuntimeShape::PythonRuntime,
            KvBoundaryClassification::ResearchOnly,
            false,
            false,
            None,
        ),
        decision(
            "flexllmgen_offload_optimizer",
            KvBoundaryRuntimeShape::PythonRuntime,
            KvBoundaryClassification::ResearchOnly,
            false,
            false,
            None,
        ),
        decision(
            "powerinfer_activation_locality",
            KvBoundaryRuntimeShape::CppRuntime,
            KvBoundaryClassification::ResearchOnly,
            false,
            false,
            None,
        ),
        decision(
            "kivi_asymmetric_kv",
            KvBoundaryRuntimeShape::MetadataOnly,
            KvBoundaryClassification::ResearchOnly,
            false,
            false,
            None,
        ),
        decision(
            "transformers_quantized_cache",
            KvBoundaryRuntimeShape::PythonRuntime,
            KvBoundaryClassification::ResearchOnly,
            false,
            false,
            None,
        ),
        decision(
            "llamacpp_prompt_cache",
            KvBoundaryRuntimeShape::CliCommand,
            KvBoundaryClassification::OwnerApprovedCommand,
            false,
            false,
            Some("owner_approval:pending:llamacpp-prompt-cache"),
        ),
    ]
}

fn decision(
    source_card_id: &str,
    runtime_shape: KvBoundaryRuntimeShape,
    classification: KvBoundaryClassification,
    server_or_daemon: bool,
    remote_or_distributed: bool,
    owner_approval_ref: Option<&str>,
) -> KvBoundaryDecision {
    KvBoundaryDecision {
        decision_id: format!("boundary:{source_card_id}"),
        source_card_id: source_card_id.to_string(),
        upstream_project_ref: format!("source_card:{source_card_id}"),
        runtime_shape,
        classification,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
        owner_approval_ref: owner_approval_ref.map(str::to_string),
        command_armed: false,
        command_executed: false,
        server_or_daemon,
        remote_or_distributed,
        product_route_enabled: false,
        mas_eligible_live: false,
        hidden_route_authority: false,
        hidden_cache_authority: false,
        l2_l3_promotion_claim: false,
        live_dense_70b_claim: false,
        ssd_as_ram_claim: false,
        byte_scope: KvBoundaryByteScope::metadata_only(8_192),
        proof_refs: KvBoundaryProofRefs {
            falsifier_ref: format!(
                "falsifier:F-KVSourceCard-ForkAndDaemonBoundary:{source_card_id}"
            ),
            rollback_ref: format!("rollback:kv-boundary:{source_card_id}"),
            run_event_log_ref: format!("run_event_log:kv-boundary:{source_card_id}"),
            answer_packet_ref: format!("answer_packet:kv-boundary:{source_card_id}"),
            compatibility_fence_ref: format!("compat:kv-boundary:{source_card_id}"),
            privacy_policy_ref: format!("privacy:kv-boundary:{source_card_id}"),
            mas_pro_boundary_ref: format!("mas_pro:kv-boundary:{source_card_id}"),
            boundary_ref: format!("boundary:kv-source-card:{source_card_id}"),
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepted_fixture_pack_builds() {
        let plan = build_plan(accepted_decisions()).expect("accepted fixture should build");
        let metrics = plan.metrics();
        assert_eq!(metrics.decision_count, 9);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(metrics.command_executions, 0);
    }

    #[test]
    fn declared_axes_are_emitted() {
        let artifact = build_artifact().expect("artifact should build");
        for axis in KV_SOURCE_CARD_FORK_AND_DAEMON_BOUNDARY_AXES {
            assert!(
                artifact.pass_per_axis.contains_key(*axis),
                "missing axis {axis}"
            );
        }
    }
}
