//! `falsify_product_route_review`.
//!
//! Metadata-only witness for `F-ProductRouteReview`. It proves the
//! `ready_for_product_route_review` cursor produces an honest review packet:
//! red routes stay red, MAS copy stays safe, L2/L3 do not promote, and any
//! next runtime work must be a separate small-model harness plan.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::COLD_PANIC_FALLBACK_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, ProductRouteRedRoute, ProductRouteReviewDecision,
    ProductRouteReviewError, ProductRouteReviewPacket, ProductRouteReviewSurface,
    PRODUCT_ROUTE_REVIEW_CURSOR, PRODUCT_ROUTE_REVIEW_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-ProductRouteReview";
const ADVANCED_RELEASE_AUDIT_CURSOR: &str =
    "release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes";
const FIXTURE_ID: &str = "product_route_review_v1";
const COMMAND: &str = "Tools/falsifiers/f_product_route_review.sh";
const RESULT: &str = "artifacts/falsifiers/product_route_review/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const COLD_PANIC_PATH: &str = "artifacts/falsifiers/cold_panic_fallback/result.json";
const LIVING_INDEX_PATH: &str = "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md";
const LATTICE_HTML_PATH: &str = "artifacts/lattice-coordinate-explainer/index.html";
const MIN_SURFACE_COUNT: u64 = 2;
const MIN_RED_ROUTE_COUNT: u64 = 4;
const MIN_REQUIRED_RED_ROUTE_COUNT: u64 = 4;
const MIN_DECISION_COUNT: u64 = 3;
const MIN_WITNESS_REF_COUNT: u64 = 8;
const MAX_METADATA_BYTES: u64 = 256 * 1024;

#[derive(Debug)]
// UAS: uas:product-route-review:witness-error
// Plane: Verification
// Residency: metadata-only product-route review rejection taxonomy.
enum ProductRouteReviewWitnessError {
    Primitive(ProductRouteReviewError),
    Io(String),
}

impl std::fmt::Display for ProductRouteReviewWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for ProductRouteReviewWitnessError {}

impl From<ProductRouteReviewError> for ProductRouteReviewWitnessError {
    fn from(value: ProductRouteReviewError) -> Self {
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
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, ProductRouteReviewWitnessError> {
    let evidence = EvidenceSnapshot::read()?;
    let packet = fixture_packet(&evidence)?;
    let metrics = packet.metrics();
    let address = packet.address();
    let mut reversed = packet.red_routes.clone();
    reversed.reverse();
    let deterministic = ProductRouteReviewPacket::new(
        packet.review_id.clone(),
        packet.guard_next_existing_work.clone(),
        packet.capability_route_status.clone(),
        packet.capability_next_bottleneck.clone(),
        packet.product_build.clone(),
        packet.pro_status.clone(),
        packet.route_authority.clone(),
        packet.admission_ref.clone(),
        packet.scope_rex_ref.clone(),
        packet.sovereign_gate_ref.clone(),
        packet.compatibility_fence.clone(),
        packet.run_event_log_ref.clone(),
        packet.decisions.clone(),
        packet.surfaces.clone(),
        reversed,
        packet.metadata_bytes,
        packet.l1_l2_l3_separated,
        packet.mas_overclaim_attempted,
        packet.l2_green_claimed,
        packet.l3_green_claimed,
        packet.hidden_route_authority,
        packet.route_policy_mutated,
        packet.gate_bypass,
        packet.answer_packet_suppressed,
        packet.hidden_chain_exposed,
        packet.hidden_cloud_fallback,
        packet.live_transport_promoted,
        packet.live_70b_promoted,
        packet.runtime_bytes_loaded,
        packet.model_bytes_loaded,
        packet.transport_runtime_bytes_loaded,
    )?
    .address()
        == address;
    let invalid_axes = invalid_fixture_axes(&evidence)?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let bool_axes = [
        (
            "upstream_cold_panic_fallback_pass",
            evidence.cold_panic_pass,
        ),
        (
            "guard_cursor_product_route_review_or_advanced",
            evidence.guard_next_existing_work == PRODUCT_ROUTE_REVIEW_CURSOR
                || evidence.guard_next_existing_work == PRODUCT_ROUTE_REVIEW_NEXT_CURSOR
                || evidence.guard_next_existing_work == ADVANCED_RELEASE_AUDIT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_product_review_or_advanced",
            evidence.capability_next_bottleneck == PRODUCT_ROUTE_REVIEW_CURSOR
                || evidence.capability_next_bottleneck == PRODUCT_ROUTE_REVIEW_NEXT_CURSOR
                || evidence.capability_next_bottleneck == ADVANCED_RELEASE_AUDIT_CURSOR,
        ),
        (
            "product_status_research_only",
            packet.product_build == ProductBuild::Pro
                && packet.pro_status == ProStatus::ResearchCandidate,
        ),
        (
            "route_authority_review_packet_only",
            packet.route_authority == "product_route_review_packet_only",
        ),
        (
            "living_index_surface_scan_pass",
            packet.surfaces.iter().any(|surface| {
                surface.surface_id == "living_index"
                    && surface.observed_text.contains(PRODUCT_ROUTE_REVIEW_CURSOR)
                    && surface
                        .observed_text
                        .contains("vault_research_route_with_packetized_mitigation")
            }),
        ),
        (
            "lattice_html_surface_scan_pass",
            packet.surfaces.iter().any(|surface| {
                surface.surface_id == "lattice_html"
                    && surface.observed_text.contains(PRODUCT_ROUTE_REVIEW_CURSOR)
                    && surface
                        .observed_text
                        .contains("vault_research_route_with_packetized_mitigation")
            }),
        ),
        (
            "north_star_present",
            packet.surfaces.iter().all(|surface| {
                surface
                    .observed_text
                    .contains("Epistemos is a local cognitive substrate")
                    && surface
                        .observed_text
                        .contains("no claim promotes without visible proof")
            }),
        ),
        (
            "forbidden_promotions_absent",
            packet.surfaces.iter().all(|surface| {
                surface
                    .forbidden_markers
                    .iter()
                    .all(|marker| !surface.observed_text.contains(marker))
            }),
        ),
        (
            "required_red_routes_bound",
            metrics.required_red_route_count >= MIN_REQUIRED_RED_ROUTE_COUNT,
        ),
        (
            "red_routes_l1_l2_l3_separated",
            packet
                .red_routes
                .iter()
                .all(|route| route.l1_l2_l3_separated),
        ),
        (
            "red_routes_not_promoted",
            packet
                .red_routes
                .iter()
                .all(|route| !route.promotion_allowed && !route.product_copy_allowed),
        ),
        (
            "runtime_probe_separate_from_promotion",
            packet.red_routes.iter().all(|route| {
                !route.runtime_probe_allowed || route.route_id == "small_model_runtime_harness"
            }),
        ),
        (
            "witness_refs_bound",
            metrics.witness_ref_count >= MIN_WITNESS_REF_COUNT,
        ),
        (
            "answer_packet_refs_bound",
            packet
                .red_routes
                .iter()
                .all(|route| route.answer_packet_ref.starts_with("answer_packet:")),
        ),
        (
            "rollback_refs_bound",
            packet
                .red_routes
                .iter()
                .all(|route| route.rollback_ref.starts_with("rollback:")),
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
            packet.compatibility_fence.starts_with("compat:"),
        ),
        (
            "run_event_log_bound",
            packet.run_event_log_ref.starts_with("run_event_log:"),
        ),
        (
            "review_decisions_bound",
            packet
                .decisions
                .contains(&ProductRouteReviewDecision::KeepResearchGated)
                && packet
                    .decisions
                    .contains(&ProductRouteReviewDecision::PreserveMasFloor)
                && packet
                    .decisions
                    .contains(&ProductRouteReviewDecision::RequestSmallModelHarnessPlan),
        ),
        ("l1_l2_l3_separation_bound", packet.l1_l2_l3_separated),
        ("no_mas_overclaim", !packet.mas_overclaim_attempted),
        ("no_l2_green_claim", !packet.l2_green_claimed),
        ("no_l3_green_claim", !packet.l3_green_claimed),
        ("no_hidden_route_authority", !packet.hidden_route_authority),
        ("no_route_policy_mutation", !packet.route_policy_mutated),
        ("no_gate_bypass", !packet.gate_bypass),
        (
            "no_answer_packet_suppression",
            !packet.answer_packet_suppressed,
        ),
        ("no_hidden_chain", !packet.hidden_chain_exposed),
        ("no_hidden_cloud_fallback", !packet.hidden_cloud_fallback),
        (
            "no_live_transport_promotion",
            !packet.live_transport_promoted,
        ),
        ("no_live_70b_promotion", !packet.live_70b_promoted),
        ("no_runtime_bytes_loaded", packet.runtime_bytes_loaded == 0),
        ("no_model_bytes_loaded", packet.model_bytes_loaded == 0),
        (
            "no_transport_runtime_bytes_loaded",
            packet.transport_runtime_bytes_loaded == 0,
        ),
        (
            "metadata_bound",
            packet.metadata_bytes <= MAX_METADATA_BYTES,
        ),
        ("product_route_review_address_deterministic", deterministic),
    ];
    for (name, passed) in bool_axes {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            passed,
        );
    }
    for (name, passed) in invalid_axes {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            passed,
        );
    }

    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "surface_count",
        metrics.surface_count,
        MIN_SURFACE_COUNT,
        "count",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_route_count",
        metrics.red_route_count,
        MIN_RED_ROUTE_COUNT,
        "count",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "required_red_route_count",
        metrics.required_red_route_count,
        MIN_REQUIRED_RED_ROUTE_COUNT,
        "count",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "decision_count",
        metrics.decision_count,
        MIN_DECISION_COUNT,
        "count",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "witness_ref_count",
        metrics.witness_ref_count,
        MIN_WITNESS_REF_COUNT,
        "count",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_probe_allowed_count",
        metrics.runtime_probe_allowed_count,
        0,
        "count",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "promotion_allowed_count",
        metrics.promotion_allowed_count,
        0,
        "count",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "product_copy_allowed_count",
        metrics.product_copy_allowed_count,
        0,
        "count",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_bytes_loaded",
        metrics.runtime_bytes_loaded,
        0,
        "bytes",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_bytes_loaded",
        metrics.model_bytes_loaded,
        0,
        "bytes",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "transport_runtime_bytes_loaded",
        metrics.transport_runtime_bytes_loaded,
        0,
        "bytes",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metadata_bytes",
        metrics.metadata_bytes,
        MAX_METADATA_BYTES,
        "bytes",
    );
    measurements.insert(
        "product_route_review_address".to_string(),
        Measurement {
            value: serde_json::Value::String(address),
            unit: "address".to_string(),
        },
    );
    measurements.insert(
        "next_safe_unit".to_string(),
        Measurement {
            value: serde_json::Value::String(PRODUCT_ROUTE_REVIEW_NEXT_CURSOR.to_string()),
            unit: "cursor".to_string(),
        },
    );

    let mut anomalies = Vec::new();
    if evidence.capability_overall_pass {
        anomalies.push(serde_json::json!({
            "kind": "unexpected_l2_green",
            "detail": "Product route review expected the capability kernel to stay red until live runtime/user-facing evidence exists."
        }));
    } else {
        anomalies.push(serde_json::json!({
            "kind": "l2_l3_not_promoted",
            "detail": "Product route review passes only as L1 metadata. Capability route remains vault_research_route_with_packetized_mitigation and L3 product runtime is unchanged."
        }));
    }
    anomalies.push(serde_json::json!({
        "kind": "next_safe_unit",
        "detail": PRODUCT_ROUTE_REVIEW_NEXT_CURSOR
    }));

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
        notes: "metadata-only F-ProductRouteReview witness: confirms the L1 review packet sees red routes, keeps MAS/Pro and L1/L2/L3 separated, refuses live 70B/ColdStream/KV promotion, and points next work at a separate small-model runtime harness safety plan."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

#[derive(Debug)]
// UAS: uas:product-route-review:evidence-snapshot
// Plane: Verification
// Residency: metadata-only upstream artifact and S0 surface reader.
struct EvidenceSnapshot {
    cold_panic_pass: bool,
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
    living_index_text: String,
    lattice_html_text: String,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, ProductRouteReviewWitnessError> {
        let cold_panic = read_json(Path::new(COLD_PANIC_PATH))?;
        let guard = read_json(Path::new(GUARD_PATH))?;
        let capability = read_json(Path::new(CAPABILITY_PATH))?;
        Ok(Self {
            cold_panic_pass: artifact_all_axes_true(&cold_panic, COLD_PANIC_FALLBACK_AXES),
            guard_next_existing_work: measurement_string(&guard, "next_existing_work")
                .unwrap_or_else(|| "missing_guard_next_existing_work".to_string()),
            capability_overall_pass: artifact_overall_pass(&capability),
            capability_route_status: measurement_string(&capability, "route_status")
                .unwrap_or_else(|| "missing_capability_route_status".to_string()),
            capability_next_bottleneck: measurement_string(&capability, "next_bottleneck")
                .unwrap_or_else(|| "missing_capability_next_bottleneck".to_string()),
            living_index_text: read_text(Path::new(LIVING_INDEX_PATH))?,
            lattice_html_text: read_text(Path::new(LATTICE_HTML_PATH))?,
        })
    }
}

fn fixture_packet(
    evidence: &EvidenceSnapshot,
) -> Result<ProductRouteReviewPacket, ProductRouteReviewWitnessError> {
    Ok(ProductRouteReviewPacket::new(
        "product_route_review_2026_06_05",
        evidence.guard_next_existing_work.clone(),
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "product_route_review_packet_only",
        "admission:scope-rex-sovereign-gate:product-route-review",
        "scope_rex:product-route-review",
        "sovereign_gate:product-route-review",
        "compat:product-route-review:v1",
        "run_event_log:product-route-review",
        review_decisions(),
        review_surfaces(evidence)?,
        red_routes()?,
        80 * 1024,
        true,
        false,
        false,
        false,
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
        0,
    )?)
}

fn review_decisions() -> BTreeSet<ProductRouteReviewDecision> {
    BTreeSet::from([
        ProductRouteReviewDecision::KeepResearchGated,
        ProductRouteReviewDecision::PreserveMasFloor,
        ProductRouteReviewDecision::RequestSmallModelHarnessPlan,
    ])
}

fn review_surfaces(
    evidence: &EvidenceSnapshot,
) -> Result<Vec<ProductRouteReviewSurface>, ProductRouteReviewWitnessError> {
    let required = vec![
        "Epistemos is a local cognitive substrate".to_string(),
        "no claim promotes without visible proof".to_string(),
        PRODUCT_ROUTE_REVIEW_CURSOR.to_string(),
        "vault_research_route_with_packetized_mitigation".to_string(),
        "L3 user-facing/product runtime is unchanged".to_string(),
    ];
    let forbidden = vec![
        "MAS ships live 70B".to_string(),
        "live ColdStream product ready".to_string(),
        "dense 70B is live".to_string(),
        "KV-Direct 128K is product-ready".to_string(),
        "SSD = RAM".to_string(),
        "hidden cloud fallback allowed".to_string(),
        "uses hidden cloud fallback".to_string(),
    ];
    Ok(vec![
        ProductRouteReviewSurface::new(
            "living_index",
            LIVING_INDEX_PATH,
            required.clone(),
            forbidden.clone(),
            evidence.living_index_text.clone(),
        )?,
        ProductRouteReviewSurface::new(
            "lattice_html",
            LATTICE_HTML_PATH,
            required,
            forbidden,
            evidence.lattice_html_text.clone(),
        )?,
    ])
}

fn red_routes() -> Result<Vec<ProductRouteRedRoute>, ProductRouteReviewWitnessError> {
    Ok(vec![
        red_route(
            "kv_direct_128k",
            "F-KV-Direct-Gate",
            "artifacts/falsifiers/kv_direct_gate/result.json",
            "128K KV-Direct stays opt-in research until live 100-prompt 128K logits, metrics, and spill traces pass.",
        )?,
        red_route(
            "live_sparse_70b",
            "F-70B-Local-Cocktail-Lite",
            "artifacts/falsifiers/70b_local_cocktail_lite/result.json",
            "Live sparse 70B remains Pro Research/Vault; metadata cold-assembly wins do not become a local 70B product route.",
        )?,
        red_route(
            "dense_70b_runtime",
            "F-LargeModelProviderReference-DeferredByMlxRoute",
            "artifacts/falsifiers/large_model_provider_reference_deferred_by_mlx_route/result.json",
            "Dense 70B runtime is deferred by the practical MLX route; no provider reference, dense RAM, or MAS product claim promotes.",
        )?,
        red_route(
            "live_coldstream_transport",
            "F-ColdPanicFallback",
            "artifacts/falsifiers/cold_panic_fallback/result.json",
            "ColdStream has L1 transport safety witnesses, but no live p99 benchmark or user-facing runtime promotion has landed.",
        )?,
    ])
}

fn red_route(
    route_id: &str,
    falsifier_id: &str,
    artifact_path: &str,
    summary: &str,
) -> Result<ProductRouteRedRoute, ProductRouteReviewWitnessError> {
    Ok(ProductRouteRedRoute::new(
        route_id,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "red_research_gated",
        format!("{route_id} requires separate live/runtime evidence before promotion"),
        vec![
            format!("falsifier:{falsifier_id}"),
            format!("artifact:{artifact_path}"),
        ],
        format!("rollback:{route_id}:keep-research-gated"),
        format!("answer_packet:{route_id}:product-route-review"),
        format!("{summary} L1/L2/L3 remain separated and product runtime is unchanged."),
        true,
        false,
        false,
        false,
    )?)
}

fn invalid_fixture_axes(
    evidence: &EvidenceSnapshot,
) -> Result<Vec<(&'static str, bool)>, ProductRouteReviewWitnessError> {
    let packet = fixture_packet(evidence)?;
    let mut missing_route = packet.red_routes.clone();
    missing_route.retain(|route| route.route_id != "kv_direct_128k");
    let mut forbidden_text = evidence.living_index_text.clone();
    forbidden_text.push_str(" MAS ships live 70B");
    let invalid_surface = ProductRouteReviewSurface::new(
        "living_index",
        LIVING_INDEX_PATH,
        vec!["Epistemos is a local cognitive substrate".to_string()],
        vec!["MAS ships live 70B".to_string()],
        forbidden_text,
    )
    .is_err();
    let product_promotion = ProductRouteRedRoute::new(
        "kv_direct_128k",
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "red_research_gated",
        "blocked until live evidence exists",
        vec![
            "falsifier:F-KV-Direct-Gate".to_string(),
            "artifact:artifacts/falsifiers/kv_direct_gate/result.json".to_string(),
        ],
        "rollback:kv-direct:keep-gated",
        "answer_packet:kv-direct:review",
        "KV-Direct remains red and product runtime is unchanged until live evidence passes.",
        true,
        true,
        false,
        false,
    )
    .is_err();
    let missing_witness = ProductRouteRedRoute::new(
        "kv_direct_128k",
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "red_research_gated",
        "blocked until live evidence exists",
        vec!["artifact:artifacts/falsifiers/kv_direct_gate/result.json".to_string()],
        "rollback:kv-direct:keep-gated",
        "answer_packet:kv-direct:review",
        "KV-Direct remains red and product runtime is unchanged until live evidence passes.",
        true,
        false,
        false,
        false,
    )
    .is_err();
    Ok(vec![
        (
            "missing_required_red_route_rejected",
            packet_with(
                evidence,
                Some(missing_route),
                None,
                None,
                None,
                None,
                None,
                None,
            )?
            .is_err(),
        ),
        ("forbidden_surface_marker_rejected", invalid_surface),
        ("product_promotion_rejected", product_promotion),
        ("missing_witness_ref_rejected", missing_witness),
        (
            "mas_overclaim_rejected",
            packet_with(evidence, None, Some(true), None, None, None, None, None)?.is_err(),
        ),
        (
            "l2_green_claim_rejected",
            packet_with(evidence, None, None, Some(true), None, None, None, None)?.is_err(),
        ),
        (
            "l3_green_claim_rejected",
            packet_with(evidence, None, None, None, Some(true), None, None, None)?.is_err(),
        ),
        (
            "hidden_authority_rejected",
            packet_with(evidence, None, None, None, None, Some(true), None, None)?.is_err(),
        ),
        (
            "runtime_bytes_rejected",
            packet_with(evidence, None, None, None, None, None, Some(1), None)?.is_err(),
        ),
        (
            "model_bytes_rejected",
            packet_with(evidence, None, None, None, None, None, None, Some(1))?.is_err(),
        ),
        (
            "metadata_budget_rejected",
            ProductRouteReviewPacket::new(
                "product_route_review_2026_06_05",
                evidence.guard_next_existing_work.clone(),
                evidence.capability_route_status.clone(),
                evidence.capability_next_bottleneck.clone(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                "product_route_review_packet_only",
                "admission:scope-rex-sovereign-gate:product-route-review",
                "scope_rex:product-route-review",
                "sovereign_gate:product-route-review",
                "compat:product-route-review:v1",
                "run_event_log:product-route-review",
                review_decisions(),
                review_surfaces(evidence)?,
                red_routes()?,
                MAX_METADATA_BYTES + 1,
                true,
                false,
                false,
                false,
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
                0,
            )
            .is_err(),
        ),
    ])
}

#[allow(clippy::too_many_arguments)]
fn packet_with(
    evidence: &EvidenceSnapshot,
    red_routes_override: Option<Vec<ProductRouteRedRoute>>,
    mas_overclaim: Option<bool>,
    l2_green: Option<bool>,
    l3_green: Option<bool>,
    hidden_authority: Option<bool>,
    runtime_bytes: Option<u64>,
    model_bytes: Option<u64>,
) -> Result<Result<ProductRouteReviewPacket, ProductRouteReviewError>, ProductRouteReviewWitnessError>
{
    Ok(ProductRouteReviewPacket::new(
        "product_route_review_2026_06_05",
        evidence.guard_next_existing_work.clone(),
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "product_route_review_packet_only",
        "admission:scope-rex-sovereign-gate:product-route-review",
        "scope_rex:product-route-review",
        "sovereign_gate:product-route-review",
        "compat:product-route-review:v1",
        "run_event_log:product-route-review",
        review_decisions(),
        review_surfaces(evidence)?,
        red_routes_override.unwrap_or(red_routes()?),
        80 * 1024,
        true,
        mas_overclaim.unwrap_or(false),
        l2_green.unwrap_or(false),
        l3_green.unwrap_or(false),
        hidden_authority.unwrap_or(false),
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        runtime_bytes.unwrap_or(0),
        model_bytes.unwrap_or(0),
        0,
    ))
}

fn add_min_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    min: u64,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::from(actual),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: ">=".to_string(),
            value: serde_json::Value::from(min),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual >= min);
}

fn add_max_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    max: u64,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::from(actual),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "<=".to_string(),
            value: serde_json::Value::from(max),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual <= max);
}

fn artifact_all_axes_true(value: &serde_json::Value, required_axes: &[&str]) -> bool {
    if !artifact_overall_pass(value) {
        return false;
    }
    required_axes.iter().all(|axis| {
        value
            .get("pass_per_axis")
            .and_then(|axes| axes.get(*axis))
            .and_then(|axis_value| axis_value.as_bool())
            .unwrap_or(false)
    })
}

fn artifact_overall_pass(value: &serde_json::Value) -> bool {
    value
        .get("overall_pass")
        .and_then(|pass| pass.as_bool())
        .unwrap_or(false)
}

fn measurement_string(value: &serde_json::Value, key: &str) -> Option<String> {
    value
        .get("measurements")?
        .get(key)?
        .get("value")?
        .as_str()
        .map(str::to_string)
}

fn read_json(path: &Path) -> Result<serde_json::Value, ProductRouteReviewWitnessError> {
    let content = read_text(path)?;
    serde_json::from_str(&content).map_err(|error| {
        ProductRouteReviewWitnessError::Io(format!("failed to parse {}: {error}", path.display()))
    })
}

fn read_text(path: &Path) -> Result<String, ProductRouteReviewWitnessError> {
    std::fs::read_to_string(path).map_err(|error| {
        ProductRouteReviewWitnessError::Io(format!("failed to read {}: {error}", path.display()))
    })
}

#[cfg(test)]
mod tests {
    #[test]
    fn axis_contract_matches_schema() {
        let axis_set = agent_core::falsifier_artifacts::axes::PRODUCT_ROUTE_REVIEW_AXES
            .iter()
            .copied()
            .collect::<std::collections::BTreeSet<_>>();
        assert!(axis_set.contains("required_red_routes_bound"));
        assert!(axis_set.contains("no_l2_green_claim"));
        assert!(axis_set.contains("product_route_review_address_deterministic"));
    }
}
