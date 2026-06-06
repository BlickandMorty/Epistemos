//! `falsify_turbovec_real_adapter_owner_approved_native_dry_run_probe`
//!
//! Metadata-only witness for
//! `F-TurboVec-RealAdapterOwnerApprovedNativeDryRunProbe`. It consumes the
//! native-link absence preflight and records an owner-approval command envelope
//! for a future dry run while proving no approval, arming, execution, build,
//! link, product mutation, route mutation, or model/runtime byte load occurs.

use std::collections::BTreeMap;
use std::fs;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, TurboVecNativeDryRunApprovalStatus, TurboVecNativeDryRunByteLedger,
    TurboVecNativeDryRunCommandCard, TurboVecNativeDryRunCommandKind, TurboVecNativeDryRunPolicy,
    TurboVecNativeDryRunProofRefs, TurboVecNativeDryRunTier,
    TurboVecRealAdapterOwnerApprovedNativeDryRunProbeSet, UasAddress, UasKind,
    TURBOVEC_REAL_ADAPTER_NATIVE_LINK_ABSENCE_PREFLIGHT_NEXT_CURSOR,
    TURBOVEC_REAL_ADAPTER_OWNER_APPROVED_NATIVE_DRY_RUN_CURSOR,
    TURBOVEC_REAL_ADAPTER_OWNER_APPROVED_NATIVE_DRY_RUN_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-TurboVec-RealAdapterOwnerApprovedNativeDryRunProbe";
const FIXTURE_ID: &str = "turbovec_real_adapter_owner_approved_native_dry_run_probe_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_turbovec_real_adapter_owner_approved_native_dry_run_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_owner_approved_native_dry_run_probe/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_native_link_absence_preflight_probe/result.json";
const PINNED_REVISION: &str = "efe29a184986cbf562a9847c2ac52a2990bfaca2";
const RED_FIXTURE_FLOOR: u64 = 48;

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
        if let Err(error) = fs::create_dir_all(parent) {
            eprintln!("failed to create artifact directory: {error}");
            return std::process::ExitCode::from(2);
        }
    }
    let mut file = match fs::File::create(&path) {
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
        "{FALSIFIER_ID}: overall_pass={} command_cards={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["command_card_count"].value,
        artifact.measurements["red_fixture_rejection_count"].value,
        artifact.measurements["next_research_to_build_unit"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let upstream = upstream_native_link_preflight_address()?;
    let cards = command_cards();
    let ledger = byte_ledger()?;
    let set = build_set(
        upstream.clone(),
        cards.clone(),
        policy(),
        proof_refs(),
        ledger.clone(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecNativeDryRunApprovalStatus::PendingOwnerApproval,
        TurboVecNativeDryRunTier::T1L1Metadata,
        false,
        false,
        false,
        false,
        false,
        false,
    )?;
    let reversed = build_set(
        upstream.clone(),
        cards.into_iter().rev().collect(),
        policy(),
        proof_refs(),
        ledger,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecNativeDryRunApprovalStatus::PendingOwnerApproval,
        TurboVecNativeDryRunTier::T1L1Metadata,
        false,
        false,
        false,
        false,
        false,
        false,
    )?;
    let metrics = set.metrics();
    let red_results = red_fixture_results(&upstream, &set.command_cards, &set.byte_ledger);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_native_link_preflight_bound",
            set.upstream_native_link_preflight_witness_ref
                == "artifact:turbovec_real_adapter_native_link_absence_preflight_probe:result"
                && set
                    .upstream_native_link_preflight_address
                    .to_string()
                    .starts_with("turbovec_real_adapter_native_link_absence_preflight_probe:")
                && red_pass(&red_results, "bad_upstream_preflight"),
        ),
        (
            "command_card_envelope_visible",
            metrics.command_card_count >= 8
                && metrics.command_visible_count == metrics.command_card_count
                && metrics.owner_approval_required_count == metrics.command_card_count
                && metrics.cleanup_required_count == metrics.command_card_count
                && metrics.cargo_metadata_template_count >= 1
                && metrics.cargo_check_template_count >= 1
                && metrics.build_script_audit_count >= 1
                && metrics.target_blas_audit_count >= 1
                && metrics.python_extension_audit_count >= 1
                && metrics.product_graph_recheck_count >= 1
                && red_pass(&red_results, "remove_cargo_metadata")
                && red_pass(&red_results, "remove_cargo_check")
                && red_pass(&red_results, "remove_build_script")
                && red_pass(&red_results, "remove_python_extension")
                && red_pass(&red_results, "remove_product_graph")
                && red_pass(&red_results, "hide_command")
                && red_pass(&red_results, "bad_command_ref")
                && red_pass(&red_results, "bad_quarantine_ref"),
        ),
        (
            "owner_approval_pending_unarmed",
            metrics.owner_approval_granted_count == 0
                && metrics.command_armed_count == 0
                && metrics.command_executed_count == 0
                && metrics.card_command_armed_count == 0
                && metrics.card_command_executed_count == 0
                && red_pass(&red_results, "owner_approval_granted")
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "ledger_command_armed")
                && red_pass(&red_results, "ledger_command_executed"),
        ),
        (
            "no_native_build_link_or_python_execution",
            metrics.build_script_exec_count == 0
                && metrics.cargo_build_invocation_count == 0
                && metrics.linker_invocation_count == 0
                && metrics.dynamic_library_load_count == 0
                && metrics.python_build_invocation_count == 0
                && red_pass(&red_results, "allow_build_script")
                && red_pass(&red_results, "allow_cargo_build")
                && red_pass(&red_results, "allow_linker")
                && red_pass(&red_results, "allow_dylib")
                && red_pass(&red_results, "allow_python_build")
                && red_pass(&red_results, "ledger_build_script")
                && red_pass(&red_results, "ledger_cargo_build")
                && red_pass(&red_results, "ledger_linker")
                && red_pass(&red_results, "ledger_dylib")
                && red_pass(&red_results, "ledger_python_build"),
        ),
        (
            "no_product_route_or_benchmark_authority",
            metrics.copied_product_file_count == 0
                && metrics.product_dependency_count == 0
                && metrics.benchmark_run_count == 0
                && metrics.route_mutation_count == 0
                && red_pass(&red_results, "allow_product_dependency")
                && red_pass(&red_results, "allow_route_mutation")
                && red_pass(&red_results, "allow_benchmark_authority")
                && red_pass(&red_results, "ledger_product_copy")
                && red_pass(&red_results, "ledger_product_dependency")
                && red_pass(&red_results, "ledger_benchmark"),
        ),
        (
            "proof_surfaces_required",
            set.proof_refs
                .owner_approval_ref
                .starts_with("owner_approval:pending:turbovec-native-dry-run:")
                && set
                    .proof_refs
                    .command_card_ref
                    .starts_with("command_card:turbovec-native-dry-run:")
                && set
                    .proof_refs
                    .rollback_ref
                    .starts_with("rollback:turbovec-native-dry-run:")
                && set
                    .proof_refs
                    .run_event_log_ref
                    .starts_with("run_event_log:turbovec-native-dry-run:")
                && set
                    .proof_refs
                    .answer_packet_ref
                    .starts_with("answer_packet:turbovec-native-dry-run:")
                && set.proof_refs.visible_summary.contains("AnswerPacket")
                && red_pass(&red_results, "bad_owner_ref")
                && red_pass(&red_results, "bad_rollback_ref")
                && red_pass(&red_results, "bad_run_event_log_ref")
                && red_pass(&red_results, "bad_answer_packet_ref")
                && red_pass(&red_results, "bad_cleanup_ref")
                && red_pass(&red_results, "short_visible_summary"),
        ),
        (
            "product_and_large_model_claims_rejected",
            metrics.raw_turbovec_source_bytes_read == 0
                && metrics.fetched_repo_bytes == 0
                && metrics.cloned_repo_bytes == 0
                && metrics.index_bytes_opened == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_model_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && metrics.product_capability_promoted_count == 0
                && metrics.hidden_authority_count == 0
                && metrics.live_large_model_claim_count == 0
                && metrics.ssd_as_ram_claim_count == 0
                && red_pass(&red_results, "raw_source_read")
                && red_pass(&red_results, "fetch_repo")
                && red_pass(&red_results, "clone_repo")
                && red_pass(&red_results, "index_bytes")
                && red_pass(&red_results, "model_bytes")
                && red_pass(&red_results, "provider_call")
                && red_pass(&red_results, "product_promotion")
                && red_pass(&red_results, "hidden_authority")
                && red_pass(&red_results, "live_large_model")
                && red_pass(&red_results, "ssd_as_ram"),
        ),
        (
            "reversed_order_address_deterministic",
            set.set_address == reversed.set_address,
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

    for (name, actual, expected, operator, unit) in [
        (
            "command_card_count",
            metrics.command_card_count,
            8,
            ">=",
            "count",
        ),
        (
            "command_visible_count",
            metrics.command_visible_count,
            metrics.command_card_count,
            "==",
            "count",
        ),
        (
            "owner_approval_granted_count",
            metrics.owner_approval_granted_count,
            0,
            "==",
            "count",
        ),
        (
            "command_armed_count",
            metrics.command_armed_count + metrics.card_command_armed_count,
            0,
            "==",
            "count",
        ),
        (
            "command_executed_count",
            metrics.command_executed_count + metrics.card_command_executed_count,
            0,
            "==",
            "count",
        ),
        (
            "linker_invocation_count",
            metrics.linker_invocation_count,
            0,
            "==",
            "count",
        ),
        (
            "model_bytes_loaded",
            metrics.model_bytes_loaded + metrics.runtime_model_bytes_loaded,
            0,
            "==",
            "bytes",
        ),
        (
            "planned_quarantine_bytes",
            metrics.planned_quarantine_bytes,
            1,
            ">=",
            "bytes",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            RED_FIXTURE_FLOOR,
            ">=",
            "count",
        ),
    ] {
        add_u64_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            actual,
            operator,
            expected,
            unit,
        );
    }

    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "pinned_revision",
        PINNED_REVISION,
        PINNED_REVISION,
        "sha",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "owner_approved_native_dry_run_address",
        &set.set_address.to_string(),
        "turbovec_real_adapter_owner_approved_native_dry_run_probe:",
        "uas_address",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_research_to_build_unit",
        TURBOVEC_REAL_ADAPTER_OWNER_APPROVED_NATIVE_DRY_RUN_NEXT_CURSOR,
        TURBOVEC_REAL_ADAPTER_OWNER_APPROVED_NATIVE_DRY_RUN_NEXT_CURSOR,
        "cursor",
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
        anomalies: vec![serde_json::json!({
            "kind": "metadata_owner_approval_pending_scope",
            "detail": "Owner-approved native dry-run command envelope only. Owner approval is pending; no command is armed or executed; no build.rs, Cargo build, linker, dynamic-library load, Python extension build, benchmark, product dependency, route mutation, model/runtime/provider byte, or L2/L3 promotion occurs."
        })],
        notes: "Builds F-TurboVec-RealAdapterOwnerApprovedNativeDryRunProbe as a T1/L1 metadata command-envelope witness after native-link absence preflight. It prepares the future owner-approved dry run while proving approval is pending and every build/link/runtime/product route remains unarmed.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_native_link_preflight_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream native-link absence preflight has not passed".into());
    }
    if value
        .pointer("/measurements/next_research_to_build_unit/value")
        .and_then(serde_json::Value::as_str)
        != Some(TURBOVEC_REAL_ADAPTER_OWNER_APPROVED_NATIVE_DRY_RUN_CURSOR)
        || TURBOVEC_REAL_ADAPTER_NATIVE_LINK_ABSENCE_PREFLIGHT_NEXT_CURSOR
            != TURBOVEC_REAL_ADAPTER_OWNER_APPROVED_NATIVE_DRY_RUN_CURSOR
    {
        return Err("upstream native-link witness does not point at dry-run probe".into());
    }
    for axis in [
        "/pass_per_axis/upstream_product_graph_bound",
        "/pass_per_axis/native_link_surfaces_blocked",
        "/pass_per_axis/no_native_link_execution_bytes",
        "/pass_per_axis/no_product_dependency_or_route_mutation",
        "/pass_per_axis/proof_surfaces_required",
        "/pass_per_axis/product_and_large_model_claims_rejected",
    ] {
        if value.pointer(axis).and_then(serde_json::Value::as_bool) != Some(true) {
            return Err(format!("upstream native-link axis {axis} did not pass").into());
        }
    }
    let address = value
        .pointer("/measurements/native_link_absence_preflight_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("missing native_link_absence_preflight_address")?;
    Ok(UasAddress::from_str(address)?)
}

fn byte_ledger() -> Result<TurboVecNativeDryRunByteLedger, Box<dyn std::error::Error>> {
    Ok(TurboVecNativeDryRunByteLedger::metadata_only(
        fs::metadata(UPSTREAM_RESULT)?.len(),
        96 * 1024,
        256 * 1024,
    )?)
}

fn build_set(
    upstream: UasAddress,
    cards: Vec<TurboVecNativeDryRunCommandCard>,
    policy: TurboVecNativeDryRunPolicy,
    proof_refs: TurboVecNativeDryRunProofRefs,
    ledger: TurboVecNativeDryRunByteLedger,
    product_build: ProductBuild,
    pro_status: ProStatus,
    approval_status: TurboVecNativeDryRunApprovalStatus,
    tier: TurboVecNativeDryRunTier,
    product_capability_promoted: bool,
    route_mutation_allowed: bool,
    hidden_route_authority: bool,
    hidden_cloud_fallback_allowed: bool,
    live_large_model_claimed: bool,
    ssd_as_ram_claimed: bool,
) -> Result<TurboVecRealAdapterOwnerApprovedNativeDryRunProbeSet, Box<dyn std::error::Error>> {
    Ok(
        TurboVecRealAdapterOwnerApprovedNativeDryRunProbeSet::from_parts(
            upstream,
            cards,
            policy,
            proof_refs,
            ledger,
            product_build,
            pro_status,
            approval_status,
            tier,
            product_capability_promoted,
            route_mutation_allowed,
            hidden_route_authority,
            hidden_cloud_fallback_allowed,
            live_large_model_claimed,
            ssd_as_ram_claimed,
        )?,
    )
}

fn command_cards() -> Vec<TurboVecNativeDryRunCommandCard> {
    vec![
        card(
            "cargo_metadata_template",
            TurboVecNativeDryRunCommandKind::CargoMetadataTemplate,
            "cargo metadata --locked --manifest-path ${QUARANTINE_ROOT}/Cargo.toml --format-version 1",
        ),
        card(
            "cargo_check_template",
            TurboVecNativeDryRunCommandKind::CargoCheckTemplate,
            "cargo check --locked --no-default-features --manifest-path ${QUARANTINE_ROOT}/Cargo.toml",
        ),
        card(
            "build_rs_audit",
            TurboVecNativeDryRunCommandKind::BuildScriptAudit,
            "inspect build.rs plan only; do not execute build script",
        ),
        card(
            "target_blas_audit",
            TurboVecNativeDryRunCommandKind::TargetBlasAudit,
            "inspect macOS Accelerate and Linux OpenBLAS link plan only",
        ),
        card(
            "python_extension_audit",
            TurboVecNativeDryRunCommandKind::PythonExtensionAudit,
            "inspect PyO3/maturin/numpy extension plan only; do not build wheel",
        ),
        card(
            "product_graph_recheck",
            TurboVecNativeDryRunCommandKind::ProductGraphRecheck,
            "rerun product graph no-contamination and route/context source scans",
        ),
        card(
            "cleanup_lease",
            TurboVecNativeDryRunCommandKind::CleanupLease,
            "cleanup quarantine temp outputs and tombstone failed dry-run attempt",
        ),
        card(
            "answer_packet_review",
            TurboVecNativeDryRunCommandKind::AnswerPacketReview,
            "emit AnswerPacket caveat: native dry run remains pending owner approval",
        ),
    ]
}

fn card(
    id: &str,
    kind: TurboVecNativeDryRunCommandKind,
    command_template: &str,
) -> TurboVecNativeDryRunCommandCard {
    TurboVecNativeDryRunCommandCard {
        card_id: id.to_string(),
        kind,
        command_template: command_template.to_string(),
        command_card_ref: format!("command_card:turbovec-native-dry-run:{id}"),
        quarantine_path_ref: format!("quarantine_path:turbovec-native-dry-run:{id}"),
        native_link_ref: format!("native_link:turbovec-preflight:{id}"),
        owner_approval_ref: format!("owner_approval:pending:turbovec-native-dry-run:{id}"),
        rollback_ref: format!("rollback:turbovec-native-dry-run:{id}"),
        run_event_log_ref: format!("run_event_log:turbovec-native-dry-run:{id}"),
        answer_packet_ref: format!("answer_packet:turbovec-native-dry-run:{id}"),
        compatibility_fence_ref: format!("compat:turbovec-native-dry-run:{id}"),
        cleanup_ref: format!("cleanup:turbovec-native-dry-run:{id}"),
        visible_summary: "TurboVec native dry-run command card is visible but unarmed; it requires explicit owner approval, cleanup, rollback, RunEventLog, AnswerPacket, and compatibility fence proof before any future command can run. This card cannot execute build scripts, Cargo builds, linkers, dynamic libraries, Python extensions, product dependencies, route mutations, benchmarks, model bytes, or L2/L3 capability.".to_string(),
        command_visible: true,
        owner_approval_required: true,
        owner_approval_granted: false,
        command_armed: false,
        command_executed: false,
        build_script_execution_allowed: false,
        cargo_build_allowed: false,
        linker_allowed: false,
        dynamic_library_load_allowed: false,
        python_extension_build_allowed: false,
        product_dependency_allowed: false,
        product_route_mutation_allowed: false,
        benchmark_authority_allowed: false,
        cleanup_required: true,
    }
}

fn policy() -> TurboVecNativeDryRunPolicy {
    TurboVecNativeDryRunPolicy::fail_closed()
}

fn proof_refs() -> TurboVecNativeDryRunProofRefs {
    TurboVecNativeDryRunProofRefs {
        upstream_native_link_preflight_ref:
            "artifact:turbovec_real_adapter_native_link_absence_preflight_probe:result"
                .to_string(),
        owner_approval_ref: "owner_approval:pending:turbovec-native-dry-run:set".to_string(),
        command_card_ref: "command_card:turbovec-native-dry-run:set".to_string(),
        quarantine_path_ref: "quarantine_path:turbovec-native-dry-run:set".to_string(),
        rollback_ref: "rollback:turbovec-native-dry-run:set".to_string(),
        run_event_log_ref: "run_event_log:turbovec-native-dry-run:set".to_string(),
        answer_packet_ref: "answer_packet:turbovec-native-dry-run:set".to_string(),
        compatibility_fence_ref: "compat:turbovec-native-dry-run:set".to_string(),
        cleanup_ref: "cleanup:turbovec-native-dry-run:set".to_string(),
        visible_summary: "TurboVec native dry-run command envelope requires explicit owner approval and remains unarmed. The envelope records command cards, quarantine path, cleanup, rollback, RunEventLog, AnswerPacket, compatibility fence, no execution, no model/runtime/provider bytes, no product dependency, no route mutation, and no L2/L3 promotion.".to_string(),
    }
}

fn red_fixture_results(
    upstream: &UasAddress,
    cards: &[TurboVecNativeDryRunCommandCard],
    ledger: &TurboVecNativeDryRunByteLedger,
) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    let wrong_upstream = UasAddress::new(
        UasKind::Other("other_native_link_preflight".to_string()),
        b"bad-upstream",
        1,
    );
    results.push((
        "bad_upstream_preflight".to_string(),
        build_set(
            wrong_upstream,
            cards.to_vec(),
            policy(),
            proof_refs(),
            ledger.clone(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecNativeDryRunApprovalStatus::PendingOwnerApproval,
            TurboVecNativeDryRunTier::T1L1Metadata,
            false,
            false,
            false,
            false,
            false,
            false,
        )
        .is_err(),
    ));

    for (name, mutation) in card_mutations() {
        let mut bad_cards = cards.to_vec();
        mutation(&mut bad_cards);
        results.push((
            name.to_string(),
            build_set(
                upstream.clone(),
                bad_cards,
                policy(),
                proof_refs(),
                ledger.clone(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecNativeDryRunApprovalStatus::PendingOwnerApproval,
                TurboVecNativeDryRunTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
            )
            .is_err(),
        ));
    }
    for (name, mutation) in policy_mutations() {
        let mut bad_policy = policy();
        mutation(&mut bad_policy);
        results.push((
            name.to_string(),
            build_set(
                upstream.clone(),
                cards.to_vec(),
                bad_policy,
                proof_refs(),
                ledger.clone(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecNativeDryRunApprovalStatus::PendingOwnerApproval,
                TurboVecNativeDryRunTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
            )
            .is_err(),
        ));
    }
    for (name, mutation) in proof_mutations() {
        let mut bad_refs = proof_refs();
        mutation(&mut bad_refs);
        results.push((
            name.to_string(),
            build_set(
                upstream.clone(),
                cards.to_vec(),
                policy(),
                bad_refs,
                ledger.clone(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecNativeDryRunApprovalStatus::PendingOwnerApproval,
                TurboVecNativeDryRunTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
            )
            .is_err(),
        ));
    }
    for (name, mutation) in ledger_mutations() {
        let mut bad_ledger = ledger.clone();
        mutation(&mut bad_ledger);
        results.push((
            name.to_string(),
            build_set(
                upstream.clone(),
                cards.to_vec(),
                policy(),
                proof_refs(),
                bad_ledger,
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecNativeDryRunApprovalStatus::PendingOwnerApproval,
                TurboVecNativeDryRunTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
            )
            .is_err(),
        ));
    }
    for (name, build, status, tier, approval_status, flag) in claim_cases() {
        results.push((
            name.to_string(),
            build_set(
                upstream.clone(),
                cards.to_vec(),
                policy(),
                proof_refs(),
                ledger.clone(),
                build,
                status,
                approval_status,
                tier,
                matches!(flag, ClaimFlag::ProductPromotion),
                matches!(flag, ClaimFlag::RouteMutation),
                matches!(flag, ClaimFlag::HiddenAuthority),
                matches!(flag, ClaimFlag::HiddenCloud),
                matches!(flag, ClaimFlag::LiveLargeModel),
                matches!(flag, ClaimFlag::SsdAsRam),
            )
            .is_err(),
        ));
    }
    results
}

type CardMutation = fn(&mut Vec<TurboVecNativeDryRunCommandCard>);

fn card_mutations() -> Vec<(&'static str, CardMutation)> {
    vec![
        ("remove_cargo_metadata", |cards| {
            cards.retain(|card| card.kind != TurboVecNativeDryRunCommandKind::CargoMetadataTemplate)
        }),
        ("remove_cargo_check", |cards| {
            cards.retain(|card| card.kind != TurboVecNativeDryRunCommandKind::CargoCheckTemplate)
        }),
        ("remove_build_script", |cards| {
            cards.retain(|card| card.kind != TurboVecNativeDryRunCommandKind::BuildScriptAudit)
        }),
        ("remove_python_extension", |cards| {
            cards.retain(|card| card.kind != TurboVecNativeDryRunCommandKind::PythonExtensionAudit)
        }),
        ("remove_product_graph", |cards| {
            cards.retain(|card| card.kind != TurboVecNativeDryRunCommandKind::ProductGraphRecheck)
        }),
        ("hide_command", |cards| {
            mutate_card(cards, "cargo_metadata_template", |card| {
                card.command_visible = false
            })
        }),
        ("bad_command_ref", |cards| {
            mutate_card(cards, "cargo_metadata_template", |card| {
                card.command_card_ref = "bad:command".to_string()
            })
        }),
        ("bad_quarantine_ref", |cards| {
            mutate_card(cards, "cargo_metadata_template", |card| {
                card.quarantine_path_ref = "bad:quarantine".to_string()
            })
        }),
        ("owner_approval_granted", |cards| {
            mutate_card(cards, "cargo_metadata_template", |card| {
                card.owner_approval_granted = true
            })
        }),
        ("command_armed", |cards| {
            mutate_card(cards, "cargo_metadata_template", |card| {
                card.command_armed = true
            })
        }),
        ("command_executed", |cards| {
            mutate_card(cards, "cargo_metadata_template", |card| {
                card.command_executed = true
            })
        }),
        ("allow_build_script", |cards| {
            mutate_card(cards, "build_rs_audit", |card| {
                card.build_script_execution_allowed = true
            })
        }),
        ("allow_cargo_build", |cards| {
            mutate_card(cards, "cargo_check_template", |card| {
                card.cargo_build_allowed = true
            })
        }),
        ("allow_linker", |cards| {
            mutate_card(cards, "target_blas_audit", |card| {
                card.linker_allowed = true
            })
        }),
        ("allow_dylib", |cards| {
            mutate_card(cards, "python_extension_audit", |card| {
                card.dynamic_library_load_allowed = true
            })
        }),
        ("allow_python_build", |cards| {
            mutate_card(cards, "python_extension_audit", |card| {
                card.python_extension_build_allowed = true
            })
        }),
        ("allow_product_dependency", |cards| {
            mutate_card(cards, "product_graph_recheck", |card| {
                card.product_dependency_allowed = true
            })
        }),
        ("allow_route_mutation", |cards| {
            mutate_card(cards, "product_graph_recheck", |card| {
                card.product_route_mutation_allowed = true
            })
        }),
        ("allow_benchmark_authority", |cards| {
            mutate_card(cards, "answer_packet_review", |card| {
                card.benchmark_authority_allowed = true
            })
        }),
        ("dangerous_command", |cards| {
            mutate_card(cards, "cleanup_lease", |card| {
                card.command_template = "sudo rm -rf /".to_string()
            })
        }),
        ("short_card_summary", |cards| {
            mutate_card(cards, "cleanup_lease", |card| {
                card.visible_summary = "short owner approval unarmed".to_string()
            })
        }),
    ]
}

fn mutate_card(
    cards: &mut [TurboVecNativeDryRunCommandCard],
    card_id: &str,
    mutation: impl FnOnce(&mut TurboVecNativeDryRunCommandCard),
) {
    if let Some(card) = cards.iter_mut().find(|card| card.card_id == card_id) {
        mutation(card);
    }
}

type PolicyMutation = fn(&mut TurboVecNativeDryRunPolicy);

fn policy_mutations() -> Vec<(&'static str, PolicyMutation)> {
    vec![
        ("policy_owner", |policy| {
            policy.owner_approval_required = false
        }),
        ("policy_unarmed", |policy| {
            policy.command_unarmed_required = false
        }),
        ("policy_execution", |policy| policy.execution_denied = false),
        ("policy_linker", |policy| {
            policy.linker_invocation_denied = false
        }),
        ("policy_product_dep", |policy| {
            policy.product_dependency_denied = false
        }),
        ("policy_answer_packet", |policy| {
            policy.answer_packet_required = false
        }),
    ]
}

type ProofMutation = fn(&mut TurboVecNativeDryRunProofRefs);

fn proof_mutations() -> Vec<(&'static str, ProofMutation)> {
    vec![
        ("bad_owner_ref", |refs| {
            refs.owner_approval_ref = "bad:owner".to_string()
        }),
        ("bad_rollback_ref", |refs| {
            refs.rollback_ref = "bad:rollback".to_string()
        }),
        ("bad_run_event_log_ref", |refs| {
            refs.run_event_log_ref = "bad:log".to_string()
        }),
        ("bad_answer_packet_ref", |refs| {
            refs.answer_packet_ref = "bad:packet".to_string()
        }),
        ("bad_cleanup_ref", |refs| {
            refs.cleanup_ref = "bad:cleanup".to_string()
        }),
        ("short_visible_summary", |refs| {
            refs.visible_summary = "short owner approval".to_string()
        }),
    ]
}

type LedgerMutation = fn(&mut TurboVecNativeDryRunByteLedger);

fn ledger_mutations() -> Vec<(&'static str, LedgerMutation)> {
    vec![
        ("ledger_command_armed", |ledger| {
            ledger.command_armed_count = 1
        }),
        ("ledger_command_executed", |ledger| {
            ledger.command_executed_count = 1
        }),
        ("ledger_build_script", |ledger| {
            ledger.build_script_exec_count = 1
        }),
        ("ledger_cargo_build", |ledger| {
            ledger.cargo_build_invocation_count = 1
        }),
        ("ledger_linker", |ledger| ledger.linker_invocation_count = 1),
        ("ledger_dylib", |ledger| {
            ledger.dynamic_library_load_count = 1
        }),
        ("ledger_python_build", |ledger| {
            ledger.python_build_invocation_count = 1
        }),
        ("ledger_product_copy", |ledger| {
            ledger.copied_product_file_count = 1
        }),
        ("ledger_product_dependency", |ledger| {
            ledger.product_dependency_count = 1
        }),
        ("ledger_benchmark", |ledger| ledger.benchmark_run_count = 1),
        ("raw_source_read", |ledger| {
            ledger.raw_turbovec_source_bytes_read = 1
        }),
        ("fetch_repo", |ledger| ledger.fetched_repo_bytes = 1),
        ("clone_repo", |ledger| ledger.cloned_repo_bytes = 1),
        ("index_bytes", |ledger| ledger.index_bytes_opened = 1),
        ("model_bytes", |ledger| ledger.model_bytes_loaded = 1),
        ("provider_call", |ledger| ledger.provider_calls_made = 1),
    ]
}

#[derive(Clone, Copy)]
// UAS: TurboVec native dry-run claim red-fixture selector.
// Plane: Verification.
// Residency: metadata-only claim mutation selector; no product mutation occurs.
enum ClaimFlag {
    ProductPromotion,
    RouteMutation,
    HiddenAuthority,
    HiddenCloud,
    LiveLargeModel,
    SsdAsRam,
    None,
}

fn claim_cases() -> Vec<(
    &'static str,
    ProductBuild,
    ProStatus,
    TurboVecNativeDryRunTier,
    TurboVecNativeDryRunApprovalStatus,
    ClaimFlag,
)> {
    vec![
        (
            "product_promotion",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecNativeDryRunTier::T1L1Metadata,
            TurboVecNativeDryRunApprovalStatus::PendingOwnerApproval,
            ClaimFlag::ProductPromotion,
        ),
        (
            "route_mutation",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecNativeDryRunTier::T1L1Metadata,
            TurboVecNativeDryRunApprovalStatus::PendingOwnerApproval,
            ClaimFlag::RouteMutation,
        ),
        (
            "hidden_authority",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecNativeDryRunTier::T1L1Metadata,
            TurboVecNativeDryRunApprovalStatus::PendingOwnerApproval,
            ClaimFlag::HiddenAuthority,
        ),
        (
            "hidden_cloud",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecNativeDryRunTier::T1L1Metadata,
            TurboVecNativeDryRunApprovalStatus::PendingOwnerApproval,
            ClaimFlag::HiddenCloud,
        ),
        (
            "live_large_model",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecNativeDryRunTier::T1L1Metadata,
            TurboVecNativeDryRunApprovalStatus::PendingOwnerApproval,
            ClaimFlag::LiveLargeModel,
        ),
        (
            "ssd_as_ram",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecNativeDryRunTier::T1L1Metadata,
            TurboVecNativeDryRunApprovalStatus::PendingOwnerApproval,
            ClaimFlag::SsdAsRam,
        ),
        (
            "bad_approval_status",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecNativeDryRunTier::T1L1Metadata,
            TurboVecNativeDryRunApprovalStatus::OwnerApprovedForSeparateExecutionWitness,
            ClaimFlag::None,
        ),
        (
            "bad_build_mas",
            ProductBuild::Mas,
            ProStatus::ResearchCandidate,
            TurboVecNativeDryRunTier::T1L1Metadata,
            TurboVecNativeDryRunApprovalStatus::PendingOwnerApproval,
            ClaimFlag::None,
        ),
        (
            "bad_status_live",
            ProductBuild::Pro,
            ProStatus::Live,
            TurboVecNativeDryRunTier::T1L1Metadata,
            TurboVecNativeDryRunApprovalStatus::PendingOwnerApproval,
            ClaimFlag::None,
        ),
        (
            "bad_tier_t2",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecNativeDryRunTier::T2L2Route,
            TurboVecNativeDryRunApprovalStatus::PendingOwnerApproval,
            ClaimFlag::None,
        ),
    ]
}

fn red_pass(results: &[(String, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(candidate, _)| candidate == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

fn add_string_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: &str,
    expected: &str,
    unit: &str,
) {
    let pass = if name.ends_with("_address") {
        actual.starts_with(expected)
    } else {
        actual == expected
    };
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(actual.to_string()),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: if name.ends_with("_address") {
                "starts_with".to_string()
            } else {
                "==".to_string()
            },
            value: serde_json::Value::String(expected.to_string()),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), pass);
}
