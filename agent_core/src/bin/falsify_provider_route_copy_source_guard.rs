//! `falsify_provider_route_copy_source_guard`.
//!
//! Metadata-only witness for `F-ProviderRoute-CopySourceGuard`. It proves
//! provider/GGUF/KV/70B route language stays copy/source-only after the default
//! MLX deferral witness: no provider calls, prompt-level manifests, product
//! promotion, hidden cloud fallback, route-policy mutation, or L2/L3 promotion.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

#[cfg(test)]
use agent_core::falsifier_artifacts::axes::PROVIDER_ROUTE_COPY_SOURCE_GUARD_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, ProviderRouteCopyClaim, ProviderRouteCopySourceError,
    ProviderRouteCopySourceGuard, ProviderRouteCopySurface, ProviderRouteSourceKind,
    PROVIDER_ROUTE_COPY_SOURCE_GUARD_CURSOR, PROVIDER_ROUTE_COPY_SOURCE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-ProviderRoute-CopySourceGuard";
const FIXTURE_ID: &str = "provider_route_copy_source_guard_v1";
const COMMAND: &str = "Tools/falsifiers/f_provider_route_copy_source_guard.sh";
const RESULT: &str = "artifacts/falsifiers/provider_route_copy_source_guard/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const DEFERRAL_PATH: &str =
    "artifacts/falsifiers/large_model_provider_reference_deferred_by_mlx_route/result.json";
const LIVING_INDEX_PATH: &str = "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md";
const LATTICE_HTML_PATH: &str = "artifacts/lattice-coordinate-explainer/index.html";
/// The terminal release-audit cursor the architecture-pending-work guard and
/// capability-ceiling kernel advance to once every side-ladder unit (including
/// provider-route-copy) is done. The `*_or_advanced` axes accept it so the
/// guard keeps passing as work legitimately progresses past provider-route-copy
/// (the failure mode that matters is a regression to an earlier cursor, not a
/// forward advance to the release-audit endgame).
const ADVANCED_RELEASE_AUDIT_CURSOR: &str =
    "release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes";
const MIN_SURFACE_COUNT: u64 = 2;
const MIN_CLAIM_COUNT: u64 = 4;
const MIN_SOURCE_KIND_COUNT: u64 = 4;
const MIN_SURFACE_MARKERS: u64 = 10;
const MIN_FORBIDDEN_PROMOTIONS: u64 = 10;
const MAX_COPY_METADATA_BYTES: u64 = 96 * 1024;

#[derive(Debug)]
// UAS: uas:provider-route-copy-source-guard:witness-error
// Plane: Verification
// Residency: metadata-only witness rejection taxonomy.
enum ProviderRouteCopyWitnessError {
    Primitive(ProviderRouteCopySourceError),
    Io(String),
}

impl std::fmt::Display for ProviderRouteCopyWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for ProviderRouteCopyWitnessError {}

impl From<ProviderRouteCopySourceError> for ProviderRouteCopyWitnessError {
    fn from(value: ProviderRouteCopySourceError) -> Self {
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
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, ProviderRouteCopyWitnessError> {
    let evidence = EvidenceSnapshot::read()?;
    let guard = fixture_guard()?;
    let metrics = guard.metrics();
    let address = guard.address();
    let mut reversed_claims = guard.claims.clone();
    reversed_claims.reverse();
    let deterministic = ProviderRouteCopySourceGuard::new(guard.surfaces.clone(), reversed_claims)?
        .address()
        == address;
    let invalid_axes = invalid_fixture_axes()?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let bool_axes = [
        ("upstream_deferral_pass", evidence.deferral_overall_pass),
        (
            "guard_cursor_provider_route_copy_or_advanced",
            evidence.guard_next_existing_work == PROVIDER_ROUTE_COPY_SOURCE_GUARD_CURSOR
                || evidence.guard_next_existing_work == PROVIDER_ROUTE_COPY_SOURCE_NEXT_CURSOR
                || evidence.guard_next_existing_work == ADVANCED_RELEASE_AUDIT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_provider_route_copy_or_advanced",
            evidence.capability_next_bottleneck == PROVIDER_ROUTE_COPY_SOURCE_GUARD_CURSOR
                || evidence.capability_next_bottleneck == PROVIDER_ROUTE_COPY_SOURCE_NEXT_CURSOR
                || evidence.capability_next_bottleneck == ADVANCED_RELEASE_AUDIT_CURSOR,
        ),
        (
            "living_index_surface_scan_pass",
            guard.surfaces.iter().any(|surface| {
                surface.surface_id == "living_index"
                    && surface
                        .required_markers
                        .iter()
                        .all(|marker| !marker.is_empty() && surface.observed_text.contains(marker))
            }),
        ),
        (
            "lattice_html_surface_scan_pass",
            guard.surfaces.iter().any(|surface| {
                surface.surface_id == "lattice_html"
                    && surface
                        .required_markers
                        .iter()
                        .all(|marker| !marker.is_empty() && surface.observed_text.contains(marker))
            }),
        ),
        (
            "forbidden_promotions_absent",
            guard.surfaces.iter().all(|surface| {
                surface
                    .forbidden_promotions
                    .iter()
                    .all(|marker| marker.is_empty() || !surface.observed_text.contains(marker))
            }),
        ),
        (
            "north_star_present",
            guard.surfaces.iter().all(|surface| {
                surface
                    .observed_text
                    .contains("Epistemos is a local cognitive substrate")
                    && surface
                        .observed_text
                        .contains("no claim promotes without visible proof")
            }),
        ),
        (
            "l1_l2_l3_separation_bound",
            guard.claims.iter().all(|claim| claim.l1_l2_l3_separated),
        ),
        (
            "copy_claims_bound",
            guard
                .claims
                .iter()
                .all(|claim| !claim.claim_id.is_empty() && !claim.copy_text.is_empty()),
        ),
        (
            "source_kinds_bound",
            metrics.source_kind_count >= MIN_SOURCE_KIND_COUNT,
        ),
        (
            "evidence_refs_bound",
            guard.claims.iter().all(|claim| {
                claim
                    .evidence_refs
                    .iter()
                    .any(|reference| reference.starts_with("falsifier:"))
                    && claim
                        .evidence_refs
                        .iter()
                        .any(|reference| reference.starts_with("artifact:"))
            }),
        ),
        (
            "admission_bound",
            guard
                .claims
                .iter()
                .all(|claim| claim.admission_ref.starts_with("admission:")),
        ),
        (
            "rollback_bound",
            guard
                .claims
                .iter()
                .all(|claim| claim.rollback_ref.starts_with("rollback:")),
        ),
        (
            "run_event_log_bound",
            guard
                .claims
                .iter()
                .all(|claim| claim.run_event_log_ref.starts_with("run_event_log:")),
        ),
        (
            "answer_packet_ref_bound",
            guard
                .claims
                .iter()
                .all(|claim| claim.answer_packet_ref.starts_with("answer_packet:")),
        ),
        (
            "compatibility_fence_bound",
            guard
                .claims
                .iter()
                .all(|claim| claim.compatibility_fence.starts_with("compat:")),
        ),
        (
            "product_build_bound",
            guard
                .claims
                .iter()
                .all(|claim| claim.product_build == ProductBuild::Pro),
        ),
        (
            "pro_status_bound",
            guard
                .claims
                .iter()
                .all(|claim| claim.pro_status == ProStatus::ResearchCandidate),
        ),
        (
            "route_authority_copy_source_only",
            guard
                .claims
                .iter()
                .all(|claim| claim.route_authority == "copy_source_only"),
        ),
        ("no_provider_call", metrics.provider_call_count == 0),
        (
            "no_prompt_manifest_created",
            metrics.prompt_manifest_count == 0,
        ),
        (
            "no_hidden_cloud_fallback",
            guard
                .claims
                .iter()
                .all(|claim| !claim.hidden_cloud_fallback),
        ),
        (
            "no_product_route_promotion",
            guard
                .claims
                .iter()
                .all(|claim| !claim.product_route_promoted),
        ),
        (
            "no_source_laundering_to_capability",
            guard
                .claims
                .iter()
                .all(|claim| !claim.source_laundered_to_capability),
        ),
        (
            "no_route_policy_mutation",
            guard.claims.iter().all(|claim| !claim.route_policy_mutated),
        ),
        (
            "no_hidden_route_authority",
            guard
                .claims
                .iter()
                .all(|claim| !claim.hidden_route_authority),
        ),
        (
            "no_hidden_chain",
            guard.claims.iter().all(|claim| !claim.hidden_chain_exposed),
        ),
        ("no_runtime_bytes_loaded", metrics.runtime_bytes_loaded == 0),
        ("no_model_bytes_loaded", metrics.model_bytes_loaded == 0),
        (
            "metadata_bound",
            metrics.max_metadata_bytes <= MAX_COPY_METADATA_BYTES,
        ),
        (
            "copy_text_bound",
            metrics.max_copy_text_bytes <= MAX_COPY_METADATA_BYTES,
        ),
        (
            "provider_route_copy_source_address_deterministic",
            deterministic,
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
    for (axis, passed) in invalid_axes {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            passed,
        );
    }
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "surface_count",
        metrics.surface_count,
        MIN_SURFACE_COUNT,
        "surfaces",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "claim_count",
        metrics.claim_count,
        MIN_CLAIM_COUNT,
        "claims",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_kind_count",
        metrics.source_kind_count,
        MIN_SOURCE_KIND_COUNT,
        "kinds",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "surface_marker_count",
        metrics.surface_marker_count,
        ">=",
        MIN_SURFACE_MARKERS,
        "markers",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "forbidden_promotion_count",
        metrics.forbidden_promotion_count,
        ">=",
        MIN_FORBIDDEN_PROMOTIONS,
        "strings",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "provider_call_count",
        metrics.provider_call_count,
        "<=",
        0,
        "calls",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prompt_manifest_count",
        metrics.prompt_manifest_count,
        "<=",
        0,
        "manifests",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_bytes_loaded",
        metrics.runtime_bytes_loaded,
        "<=",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_bytes_loaded",
        metrics.model_bytes_loaded,
        "<=",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_copy_text_bytes",
        metrics.max_copy_text_bytes,
        "<=",
        MAX_COPY_METADATA_BYTES,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_metadata_bytes",
        metrics.max_metadata_bytes,
        "<=",
        MAX_COPY_METADATA_BYTES,
        "bytes",
    );
    measurements.insert(
        "provider_route_copy_source_address".to_string(),
        Measurement {
            value: serde_json::Value::String(address.clone()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "provider_route_copy_source_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::Value::String(
                "uas:provider-route-copy-source-guard:sha256:".to_string(),
            ),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "provider_route_copy_source_address".to_string(),
        address.starts_with("uas:provider-route-copy-source-guard:sha256:"),
    );

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
            "kind": "metadata_only_provider_route_copy_source_guard",
            "detail": "Copy/source witness only; proves Living Index and lattice HTML keep provider/70B/KV claims L1-only with L2/L3 unpromoted and no route/runtime mutation."
        })],
        notes: "Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof. F-ProviderRoute-CopySourceGuard is metadata-only and scans the Living Index plus lattice HTML to keep provider-reference, KV-Direct, 70B, and practical MLX route copy source-only after large-model deferral.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();
    Ok(artifact)
}

fn fixture_guard() -> Result<ProviderRouteCopySourceGuard, ProviderRouteCopyWitnessError> {
    let living = read_text(LIVING_INDEX_PATH)?;
    let lattice = read_text(LATTICE_HTML_PATH)?;
    let surfaces = vec![
        ProviderRouteCopySurface::new(
            "living_index",
            LIVING_INDEX_PATH,
            vec![
                "Epistemos is a local cognitive substrate".to_string(),
                "no claim promotes without visible proof".to_string(),
                "provider_route_copy_source_guard".to_string(),
                "F-LargeModelProviderReference-DeferredByMlxRoute".to_string(),
                "metadata-only".to_string(),
                "L2 remains".to_string(),
                "L3 user-facing/product runtime is unchanged".to_string(),
            ],
            forbidden_promotions(),
            living,
        )?,
        ProviderRouteCopySurface::new(
            "lattice_html",
            LATTICE_HTML_PATH,
            vec![
                "epistemos-artifact-cursor\" content=\"small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe".to_string(),
                "Epistemos is a local cognitive substrate".to_string(),
                "no claim promotes without visible proof".to_string(),
                "LargeModelProviderReferenceDeferral".to_string(),
                "ProviderRouteCopySourceGuard".to_string(),
                "metadata-only".to_string(),
                "L2 remains".to_string(),
                "product runtime is unchanged".to_string(),
            ],
            forbidden_promotions(),
            lattice,
        )?,
    ];
    let claims = vec![
        copy_claim(
            "provider-reference-copy",
            "living_index",
            ProviderRouteSourceKind::ProviderReference,
            "Provider/fp16 references stay deferred; metadata-only; L2 remains red; L3 product runtime is unchanged.",
        )?,
        copy_claim(
            "kv-direct-copy",
            "living_index",
            ProviderRouteSourceKind::KvDirect,
            "KV-Direct 128K shard work stays deferred; metadata-only; L2 remains red; L3 product runtime is unchanged.",
        )?,
        copy_claim(
            "cold-assembly-copy",
            "lattice_html",
            ProviderRouteSourceKind::ColdAssembly,
            "Cold assembly remains architecture evidence; metadata-only; L2 remains red; L3 product runtime is unchanged.",
        )?,
        copy_claim(
            "practical-mlx-copy",
            "lattice_html",
            ProviderRouteSourceKind::PracticalMlx,
            "Practical MLX remains the active local route; metadata-only; L2 remains red; L3 product runtime is unchanged.",
        )?,
    ];
    Ok(ProviderRouteCopySourceGuard::new(surfaces, claims)?)
}

fn copy_claim(
    claim_id: &str,
    surface_id: &str,
    kind: ProviderRouteSourceKind,
    copy_text: &str,
) -> Result<ProviderRouteCopyClaim, ProviderRouteCopyWitnessError> {
    Ok(ProviderRouteCopyClaim::new(
        claim_id,
        surface_id,
        kind,
        "default_provider_route_copy",
        "L1 only; L2 remains red; L3 product runtime is unchanged",
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "copy_source_only",
        copy_text,
        vec![
            "falsifier:F-LargeModelProviderReference-DeferredByMlxRoute".to_string(),
            "artifact:large_model_provider_reference_deferred_by_mlx_route".to_string(),
            "living_index:docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md".to_string(),
            "lattice_html:artifacts/lattice-coordinate-explainer/index.html".to_string(),
            "capability_kernel:provider_route_copy_source_guard".to_string(),
        ],
        "admission:scope-rex-sovereign-gate:copy-source-only",
        "rollback:provider-route-copy-source-guard:v1",
        "run_event_log:provider-route-copy-source-guard:v1",
        "answer_packet:provider-route-copy-source-guard:v1",
        "compat:provider-route-copy-source-guard:v1",
        2048,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        0,
        0,
    )?)
}

fn invalid_fixture_axes() -> Result<Vec<(&'static str, bool)>, ProviderRouteCopyWitnessError> {
    let guard = fixture_guard()?;
    let mut axes = Vec::new();
    axes.push((
        "empty_surface_rejected",
        ProviderRouteCopySourceGuard::new(vec![], guard.claims.clone()).is_err(),
    ));
    axes.push((
        "empty_claim_rejected",
        ProviderRouteCopySourceGuard::new(guard.surfaces.clone(), vec![]).is_err(),
    ));
    axes.push(("duplicate_surface_rejected", {
        let mut surfaces = guard.surfaces.clone();
        surfaces.push(surfaces[0].clone());
        ProviderRouteCopySourceGuard::new(surfaces, guard.claims.clone()).is_err()
    }));
    axes.push(("duplicate_claim_rejected", {
        let mut claims = guard.claims.clone();
        claims.push(claims[0].clone());
        ProviderRouteCopySourceGuard::new(guard.surfaces.clone(), claims).is_err()
    }));
    axes.push(("missing_surface_ref_rejected", {
        let mut claims = guard.claims.clone();
        claims[0].surface_id = "missing_surface".to_string();
        ProviderRouteCopySourceGuard::new(guard.surfaces.clone(), claims).is_err()
    }));
    axes.push(("missing_required_marker_rejected", {
        ProviderRouteCopySurface::new(
            "bad_surface",
            LIVING_INDEX_PATH,
            vec!["provider_route_copy_source_guard".to_string()],
            forbidden_promotions(),
            "missing marker text",
        )
        .is_err()
    }));
    axes.push(("forbidden_promotion_rejected", {
        ProviderRouteCopySurface::new(
            "bad_surface",
            LIVING_INDEX_PATH,
            vec!["provider_route_copy_source_guard".to_string()],
            forbidden_promotions(),
            "provider_route_copy_source_guard 70B product route is live",
        )
        .is_err()
    }));
    axes.push((
        "missing_evidence_ref_rejected",
        reject_claim(|claim| claim.evidence_refs.clear()),
    ));
    axes.push((
        "missing_layer_separation_rejected",
        reject_claim(|claim| claim.l1_l2_l3_separated = false),
    ));
    axes.push((
        "mas_product_build_rejected",
        reject_claim(|claim| claim.product_build = ProductBuild::Mas),
    ));
    axes.push((
        "live_pro_status_rejected",
        reject_claim(|claim| claim.pro_status = ProStatus::Live),
    ));
    axes.push((
        "route_authority_rejected",
        reject_claim(|claim| claim.route_authority = "live_route_authority".to_string()),
    ));
    axes.push((
        "provider_call_rejected",
        reject_claim(|claim| claim.provider_call_attempted = true),
    ));
    axes.push((
        "prompt_manifest_rejected",
        reject_claim(|claim| claim.prompt_manifest_created = true),
    ));
    axes.push((
        "hidden_cloud_fallback_rejected",
        reject_claim(|claim| claim.hidden_cloud_fallback = true),
    ));
    axes.push((
        "product_route_promotion_rejected",
        reject_claim(|claim| claim.product_route_promoted = true),
    ));
    axes.push((
        "source_laundering_rejected",
        reject_claim(|claim| claim.source_laundered_to_capability = true),
    ));
    axes.push((
        "route_policy_mutation_rejected",
        reject_claim(|claim| claim.route_policy_mutated = true),
    ));
    axes.push((
        "hidden_route_authority_rejected",
        reject_claim(|claim| claim.hidden_route_authority = true),
    ));
    axes.push((
        "hidden_chain_exposure_rejected",
        reject_claim(|claim| claim.hidden_chain_exposed = true),
    ));
    axes.push((
        "runtime_bytes_rejected",
        reject_claim(|claim| claim.runtime_bytes_loaded = 1),
    ));
    axes.push((
        "model_bytes_rejected",
        reject_claim(|claim| claim.model_bytes_loaded = 1),
    ));
    axes.push((
        "copy_text_budget_rejected",
        reject_claim(|claim| claim.copy_text = "x".repeat((MAX_COPY_METADATA_BYTES + 1) as usize)),
    ));
    axes.push((
        "metadata_budget_rejected",
        reject_claim(|claim| claim.metadata_bytes = MAX_COPY_METADATA_BYTES + 1),
    ));
    Ok(axes)
}

fn reject_claim(mut mutate: impl FnMut(&mut ProviderRouteCopyClaim)) -> bool {
    let Ok(guard) = fixture_guard() else {
        return false;
    };
    let mut claims = guard.claims;
    mutate(&mut claims[0]);
    ProviderRouteCopySourceGuard::new(guard.surfaces, claims).is_err()
}

fn forbidden_promotions() -> Vec<String> {
    [
        "70B product route is live",
        "dense 70B runs locally today",
        "provider route is live by default",
        "cloud fallback is enabled",
        "hidden cloud fallback is enabled",
        "KV-Direct 128K is product-ready",
        "PatternBoost is live route authority",
        "SSD = RAM",
        "weights live on SSD as hot RAM",
        "no L2/L3 proof required",
    ]
    .iter()
    .map(|value| value.to_string())
    .collect()
}

// UAS: uas:provider-route-copy-source-guard:evidence-snapshot
// Plane: Verification
// Residency: metadata-only guard/capability/deferral evidence reader.
struct EvidenceSnapshot {
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
    deferral_overall_pass: bool,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, ProviderRouteCopyWitnessError> {
        let guard = read_json(GUARD_PATH)?;
        let capability = read_json(CAPABILITY_PATH)?;
        let deferral = read_json(DEFERRAL_PATH)?;
        Ok(Self {
            guard_next_existing_work: measurement_string(&guard, "next_existing_work")
                .unwrap_or_default(),
            capability_overall_pass: bool_field(&capability, "overall_pass"),
            capability_route_status: measurement_string(&capability, "route_status")
                .unwrap_or_default(),
            capability_next_bottleneck: measurement_string(&capability, "next_bottleneck")
                .unwrap_or_default(),
            deferral_overall_pass: bool_field(&deferral, "overall_pass"),
        })
    }
}

fn read_text(path: &'static str) -> Result<String, ProviderRouteCopyWitnessError> {
    let resolved = resolve_artifact_path(path);
    std::fs::read_to_string(&resolved).map_err(|error| {
        ProviderRouteCopyWitnessError::Io(format!("failed to read {}: {error}", resolved.display()))
    })
}

fn read_json(path: &'static str) -> Result<serde_json::Value, ProviderRouteCopyWitnessError> {
    let text = read_text(path)?;
    serde_json::from_str(&text).map_err(|error| {
        ProviderRouteCopyWitnessError::Io(format!("failed to parse {path}: {error}"))
    })
}

fn resolve_artifact_path(path: &'static str) -> PathBuf {
    let direct = PathBuf::from(path);
    if direct.exists() {
        return direct;
    }
    Path::new("..").join(path)
}

fn bool_field(value: &serde_json::Value, key: &str) -> bool {
    value
        .get(key)
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
}

fn measurement_string(value: &serde_json::Value, key: &str) -> Option<String> {
    value
        .get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(serde_json::Value::as_str)
        .map(str::to_string)
}

fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    actual: u64,
    operator: &str,
    expected: u64,
    unit: &str,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::from(actual),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::from(expected),
            unit: unit.to_string(),
        },
    );
    let passed = match operator {
        ">=" => actual >= expected,
        "<=" => actual <= expected,
        "<" => actual < expected,
        ">" => actual > expected,
        "==" => actual == expected,
        _ => false,
    };
    pass_per_axis.insert(axis.to_string(), passed);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn valid_artifact_passes() {
        let artifact = build_artifact().expect("artifact");
        assert!(artifact.overall_pass);
        assert_eq!(artifact.falsifier_id, FALSIFIER_ID);
    }

    #[test]
    fn artifact_contains_shared_axes() {
        let artifact = build_artifact().expect("artifact");
        for axis in PROVIDER_ROUTE_COPY_SOURCE_GUARD_AXES {
            assert!(
                artifact.pass_per_axis.contains_key(*axis),
                "missing axis {axis}"
            );
        }
    }

    #[test]
    fn invalid_axes_are_true() {
        let artifact = build_artifact().expect("artifact");
        for axis in [
            "forbidden_promotion_rejected",
            "provider_call_rejected",
            "prompt_manifest_rejected",
            "product_route_promotion_rejected",
            "source_laundering_rejected",
            "route_policy_mutation_rejected",
            "hidden_route_authority_rejected",
            "runtime_bytes_rejected",
            "model_bytes_rejected",
        ] {
            assert_eq!(
                artifact.pass_per_axis.get(axis).copied(),
                Some(true),
                "{axis}"
            );
        }
    }

    #[test]
    fn address_is_deterministic_under_claim_order() {
        let guard = fixture_guard().expect("guard");
        let address = guard.address();
        let mut claims = guard.claims.clone();
        claims.reverse();
        let reversed =
            ProviderRouteCopySourceGuard::new(guard.surfaces.clone(), claims).expect("reversed");
        assert_eq!(address, reversed.address());
        assert!(address.starts_with("uas:provider-route-copy-source-guard:sha256:"));
    }

    #[test]
    fn source_surface_guard_reads_living_index_and_lattice() {
        let guard = fixture_guard().expect("guard");
        assert_eq!(guard.surfaces.len(), 2);
        assert!(guard
            .surfaces
            .iter()
            .any(|surface| surface.surface_id == "living_index"));
        assert!(guard
            .surfaces
            .iter()
            .any(|surface| surface.surface_id == "lattice_html"));
    }
}
