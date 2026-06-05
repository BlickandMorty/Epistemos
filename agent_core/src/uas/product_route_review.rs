//! Product route review packet.
//!
//! This metadata-only witness sits at `ready_for_product_route_review`. It
//! does not promote L2/L3. It proves the architecture cursor can enter a
//! product-route review with visible red routes, rollback/admission evidence,
//! MAS/Pro separation, and no hidden live-runtime claim.

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild};

pub const PRODUCT_ROUTE_REVIEW_CURSOR: &str = "ready_for_product_route_review";
pub const PRODUCT_ROUTE_REVIEW_NEXT_CURSOR: &str = "small_model_runtime_harness_safety_plan";

const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ROLLBACK_PREFIX: &str = "rollback:";
const ADMISSION_PREFIX: &str = "admission:";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const FALSIFIER_PREFIX: &str = "falsifier:";
const ARTIFACT_PREFIX: &str = "artifact:";
const REQUIRED_ROUTE_IDS: [&str; 4] = [
    "kv_direct_128k",
    "live_sparse_70b",
    "dense_70b_runtime",
    "live_coldstream_transport",
];
const MIN_SURFACE_TEXT_BYTES: usize = 256;
const MAX_METADATA_BYTES: u64 = 256 * 1024;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:product-route-review:decision
// Plane: Controller + Verification
// Residency: metadata-only review decision; no live route authority.
pub enum ProductRouteReviewDecision {
    KeepResearchGated,
    PreserveMasFloor,
    RequestSmallModelHarnessPlan,
}

impl ProductRouteReviewDecision {
    fn tag(&self) -> &'static str {
        match self {
            Self::KeepResearchGated => "keep_research_gated",
            Self::PreserveMasFloor => "preserve_mas_floor",
            Self::RequestSmallModelHarnessPlan => "request_small_model_harness_plan",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:product-route-review:error
// Plane: Verification
// Residency: metadata-only rejection taxonomy.
pub enum ProductRouteReviewError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    EmptySurface,
    EmptyRedRoute,
    EmptyDecision,
    DuplicateSurface(String),
    DuplicateRedRoute(String),
    MissingRequiredRoute(&'static str),
    MissingRequiredMarker(String),
    ForbiddenMarker(String),
    MissingWitnessRef(String),
    MissingAnswerPacket(String),
    MissingRunEventLog,
    MissingRollback(String),
    MissingAdmission,
    MissingScopeRex,
    MissingSovereignGate,
    MissingCompatibilityFence,
    MissingLayerSeparation,
    MissingUserVisibleSummary(String),
    MissingReviewDecision(&'static str),
    ProductStatusMismatch,
    CapabilityStatusMismatch,
    GuardCursorMismatch,
    ProductPromotionAttempted(String),
    MasOverclaimAttempted,
    L2GreenClaimAttempted,
    L3GreenClaimAttempted,
    HiddenRouteAuthority,
    RoutePolicyMutation,
    GateBypass,
    AnswerPacketSuppression,
    HiddenChainExposure,
    HiddenCloudFallback,
    LiveTransportPromotion,
    LiveSeventyBPromotion,
    RuntimeBytesLoaded,
    ModelBytesLoaded,
    TransportRuntimeBytesLoaded,
    MetadataBudgetExceeded,
}

impl fmt::Display for ProductRouteReviewError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptySurface => write!(f, "missing product route review surface"),
            Self::EmptyRedRoute => write!(f, "missing red product route"),
            Self::EmptyDecision => write!(f, "missing product route review decision"),
            Self::DuplicateSurface(id) => write!(f, "duplicate review surface `{id}`"),
            Self::DuplicateRedRoute(id) => write!(f, "duplicate red route `{id}`"),
            Self::MissingRequiredRoute(id) => write!(f, "missing required red route `{id}`"),
            Self::MissingRequiredMarker(marker) => write!(f, "missing marker `{marker}`"),
            Self::ForbiddenMarker(marker) => write!(f, "forbidden marker `{marker}`"),
            Self::MissingWitnessRef(id) => write!(f, "red route `{id}` missing witness ref"),
            Self::MissingAnswerPacket(id) => write!(f, "red route `{id}` missing AnswerPacket"),
            Self::MissingRunEventLog => write!(f, "missing RunEventLog ref"),
            Self::MissingRollback(id) => write!(f, "red route `{id}` missing rollback ref"),
            Self::MissingAdmission => write!(f, "missing admission ref"),
            Self::MissingScopeRex => write!(f, "missing SCOPE-Rex ref"),
            Self::MissingSovereignGate => write!(f, "missing SovereignGate ref"),
            Self::MissingCompatibilityFence => write!(f, "missing compatibility fence"),
            Self::MissingLayerSeparation => write!(f, "missing L1/L2/L3 separation"),
            Self::MissingUserVisibleSummary(id) => {
                write!(f, "red route `{id}` missing user-visible summary")
            }
            Self::MissingReviewDecision(decision) => {
                write!(f, "missing review decision `{decision}`")
            }
            Self::ProductStatusMismatch => write!(f, "review product status mismatch"),
            Self::CapabilityStatusMismatch => write!(f, "capability route status mismatch"),
            Self::GuardCursorMismatch => write!(f, "guard cursor mismatch"),
            Self::ProductPromotionAttempted(id) => {
                write!(f, "red route `{id}` attempted product promotion")
            }
            Self::MasOverclaimAttempted => write!(f, "MAS overclaim attempted"),
            Self::L2GreenClaimAttempted => write!(f, "L2 green claim attempted"),
            Self::L3GreenClaimAttempted => write!(f, "L3 green claim attempted"),
            Self::HiddenRouteAuthority => write!(f, "hidden route authority attempted"),
            Self::RoutePolicyMutation => write!(f, "route policy mutation attempted"),
            Self::GateBypass => write!(f, "gate bypass attempted"),
            Self::AnswerPacketSuppression => write!(f, "AnswerPacket suppression attempted"),
            Self::HiddenChainExposure => write!(f, "hidden chain exposure attempted"),
            Self::HiddenCloudFallback => write!(f, "hidden cloud fallback attempted"),
            Self::LiveTransportPromotion => write!(f, "live transport promotion attempted"),
            Self::LiveSeventyBPromotion => write!(f, "live 70B promotion attempted"),
            Self::RuntimeBytesLoaded => write!(f, "metadata witness loaded runtime bytes"),
            Self::ModelBytesLoaded => write!(f, "metadata witness loaded model bytes"),
            Self::TransportRuntimeBytesLoaded => {
                write!(f, "metadata witness loaded transport runtime bytes")
            }
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for ProductRouteReviewError {}

#[derive(Clone, Debug)]
// UAS: uas:product-route-review:red-route
// Plane: Controller + Verification
// Residency: metadata-only route status card.
pub struct ProductRouteRedRoute {
    pub route_id: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_status: String,
    pub blocker: String,
    pub witness_refs: Vec<String>,
    pub rollback_ref: String,
    pub answer_packet_ref: String,
    pub user_visible_summary: String,
    pub l1_l2_l3_separated: bool,
    pub promotion_allowed: bool,
    pub runtime_probe_allowed: bool,
    pub product_copy_allowed: bool,
}

impl ProductRouteRedRoute {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        route_id: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_status: impl Into<String>,
        blocker: impl Into<String>,
        witness_refs: Vec<String>,
        rollback_ref: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        user_visible_summary: impl Into<String>,
        l1_l2_l3_separated: bool,
        promotion_allowed: bool,
        runtime_probe_allowed: bool,
        product_copy_allowed: bool,
    ) -> Result<Self, ProductRouteReviewError> {
        let route = Self {
            route_id: route_id.into(),
            product_build,
            pro_status,
            route_status: route_status.into(),
            blocker: blocker.into(),
            witness_refs,
            rollback_ref: rollback_ref.into(),
            answer_packet_ref: answer_packet_ref.into(),
            user_visible_summary: user_visible_summary.into(),
            l1_l2_l3_separated,
            promotion_allowed,
            runtime_probe_allowed,
            product_copy_allowed,
        };
        validate_red_route(&route)?;
        Ok(route)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:product-route-review:surface
// Plane: State + Verification
// Residency: local documentation surface scan; no runtime bytes.
pub struct ProductRouteReviewSurface {
    pub surface_id: String,
    pub path: String,
    pub required_markers: Vec<String>,
    pub forbidden_markers: Vec<String>,
    pub observed_text: String,
}

impl ProductRouteReviewSurface {
    pub fn new(
        surface_id: impl Into<String>,
        path: impl Into<String>,
        required_markers: Vec<String>,
        forbidden_markers: Vec<String>,
        observed_text: impl Into<String>,
    ) -> Result<Self, ProductRouteReviewError> {
        let surface = Self {
            surface_id: surface_id.into(),
            path: path.into(),
            required_markers,
            forbidden_markers,
            observed_text: observed_text.into(),
        };
        validate_surface(&surface)?;
        Ok(surface)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:product-route-review:packet
// Plane: Controller + Verification
// Residency: metadata-only review packet.
pub struct ProductRouteReviewPacket {
    pub review_id: String,
    pub guard_next_existing_work: String,
    pub capability_route_status: String,
    pub capability_next_bottleneck: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub admission_ref: String,
    pub scope_rex_ref: String,
    pub sovereign_gate_ref: String,
    pub compatibility_fence: String,
    pub run_event_log_ref: String,
    pub decisions: BTreeSet<ProductRouteReviewDecision>,
    pub surfaces: Vec<ProductRouteReviewSurface>,
    pub red_routes: Vec<ProductRouteRedRoute>,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub mas_overclaim_attempted: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub hidden_route_authority: bool,
    pub route_policy_mutated: bool,
    pub gate_bypass: bool,
    pub answer_packet_suppressed: bool,
    pub hidden_chain_exposed: bool,
    pub hidden_cloud_fallback: bool,
    pub live_transport_promoted: bool,
    pub live_70b_promoted: bool,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub transport_runtime_bytes_loaded: u64,
}

impl ProductRouteReviewPacket {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        review_id: impl Into<String>,
        guard_next_existing_work: impl Into<String>,
        capability_route_status: impl Into<String>,
        capability_next_bottleneck: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        admission_ref: impl Into<String>,
        scope_rex_ref: impl Into<String>,
        sovereign_gate_ref: impl Into<String>,
        compatibility_fence: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        decisions: BTreeSet<ProductRouteReviewDecision>,
        surfaces: Vec<ProductRouteReviewSurface>,
        red_routes: Vec<ProductRouteRedRoute>,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        mas_overclaim_attempted: bool,
        l2_green_claimed: bool,
        l3_green_claimed: bool,
        hidden_route_authority: bool,
        route_policy_mutated: bool,
        gate_bypass: bool,
        answer_packet_suppressed: bool,
        hidden_chain_exposed: bool,
        hidden_cloud_fallback: bool,
        live_transport_promoted: bool,
        live_70b_promoted: bool,
        runtime_bytes_loaded: u64,
        model_bytes_loaded: u64,
        transport_runtime_bytes_loaded: u64,
    ) -> Result<Self, ProductRouteReviewError> {
        let packet = Self {
            review_id: review_id.into(),
            guard_next_existing_work: guard_next_existing_work.into(),
            capability_route_status: capability_route_status.into(),
            capability_next_bottleneck: capability_next_bottleneck.into(),
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            admission_ref: admission_ref.into(),
            scope_rex_ref: scope_rex_ref.into(),
            sovereign_gate_ref: sovereign_gate_ref.into(),
            compatibility_fence: compatibility_fence.into(),
            run_event_log_ref: run_event_log_ref.into(),
            decisions,
            surfaces,
            red_routes,
            metadata_bytes,
            l1_l2_l3_separated,
            mas_overclaim_attempted,
            l2_green_claimed,
            l3_green_claimed,
            hidden_route_authority,
            route_policy_mutated,
            gate_bypass,
            answer_packet_suppressed,
            hidden_chain_exposed,
            hidden_cloud_fallback,
            live_transport_promoted,
            live_70b_promoted,
            runtime_bytes_loaded,
            model_bytes_loaded,
            transport_runtime_bytes_loaded,
        };
        validate_packet(&packet)?;
        Ok(packet)
    }

    pub fn metrics(&self) -> ProductRouteReviewMetrics {
        let red_route_ids = self
            .red_routes
            .iter()
            .map(|route| route.route_id.as_str())
            .collect::<HashSet<_>>();
        ProductRouteReviewMetrics {
            surface_count: self.surfaces.len() as u64,
            red_route_count: self.red_routes.len() as u64,
            required_red_route_count: REQUIRED_ROUTE_IDS
                .iter()
                .filter(|id| red_route_ids.contains(**id))
                .count() as u64,
            decision_count: self.decisions.len() as u64,
            witness_ref_count: self
                .red_routes
                .iter()
                .map(|route| route.witness_refs.len() as u64)
                .sum(),
            runtime_probe_allowed_count: self
                .red_routes
                .iter()
                .map(|route| u64::from(route.runtime_probe_allowed))
                .sum(),
            promotion_allowed_count: self
                .red_routes
                .iter()
                .map(|route| u64::from(route.promotion_allowed))
                .sum(),
            product_copy_allowed_count: self
                .red_routes
                .iter()
                .map(|route| u64::from(route.product_copy_allowed))
                .sum(),
            runtime_bytes_loaded: self.runtime_bytes_loaded,
            model_bytes_loaded: self.model_bytes_loaded,
            transport_runtime_bytes_loaded: self.transport_runtime_bytes_loaded,
            metadata_bytes: self.metadata_bytes,
        }
    }

    pub fn address(&self) -> String {
        let mut route_parts = self
            .red_routes
            .iter()
            .map(|route| {
                format!(
                    "{}|{}|{}|{}|{}|{}",
                    route.route_id,
                    route.route_status,
                    route.blocker,
                    route.rollback_ref,
                    route.answer_packet_ref,
                    route.user_visible_summary
                )
            })
            .collect::<Vec<_>>();
        route_parts.sort();
        let mut surface_parts = self
            .surfaces
            .iter()
            .map(|surface| format!("{}|{}", surface.surface_id, surface.path))
            .collect::<Vec<_>>();
        surface_parts.sort();
        let mut decision_parts = self
            .decisions
            .iter()
            .map(ProductRouteReviewDecision::tag)
            .collect::<Vec<_>>();
        decision_parts.sort();
        let preimage = format!(
            "{}|{}|{}|{}|{}|{}",
            self.review_id,
            self.guard_next_existing_work,
            self.capability_route_status,
            route_parts.join(";"),
            surface_parts.join(";"),
            decision_parts.join(";")
        );
        let digest = sha256_hex(preimage.as_bytes());
        format!("uas:product-route-review:sha256:{digest}")
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:product-route-review:metrics
// Plane: Verification
// Residency: metadata-only review metrics.
pub struct ProductRouteReviewMetrics {
    pub surface_count: u64,
    pub red_route_count: u64,
    pub required_red_route_count: u64,
    pub decision_count: u64,
    pub witness_ref_count: u64,
    pub runtime_probe_allowed_count: u64,
    pub promotion_allowed_count: u64,
    pub product_copy_allowed_count: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub transport_runtime_bytes_loaded: u64,
    pub metadata_bytes: u64,
}

fn validate_packet(packet: &ProductRouteReviewPacket) -> Result<(), ProductRouteReviewError> {
    validate_token("review_id", &packet.review_id)?;
    validate_token("guard_next_existing_work", &packet.guard_next_existing_work)?;
    validate_token("capability_route_status", &packet.capability_route_status)?;
    validate_token(
        "capability_next_bottleneck",
        &packet.capability_next_bottleneck,
    )?;
    validate_token("route_authority", &packet.route_authority)?;
    validate_prefixed("admission_ref", &packet.admission_ref, ADMISSION_PREFIX)?;
    validate_prefixed("scope_rex_ref", &packet.scope_rex_ref, SCOPE_REX_PREFIX)?;
    validate_prefixed(
        "sovereign_gate_ref",
        &packet.sovereign_gate_ref,
        SOVEREIGN_GATE_PREFIX,
    )?;
    validate_prefixed(
        "compatibility_fence",
        &packet.compatibility_fence,
        COMPATIBILITY_FENCE_PREFIX,
    )?;
    validate_prefixed(
        "run_event_log_ref",
        &packet.run_event_log_ref,
        RUN_EVENT_LOG_PREFIX,
    )
    .map_err(|_| ProductRouteReviewError::MissingRunEventLog)?;
    if packet.guard_next_existing_work != PRODUCT_ROUTE_REVIEW_CURSOR
        && packet.guard_next_existing_work != PRODUCT_ROUTE_REVIEW_NEXT_CURSOR
    {
        return Err(ProductRouteReviewError::GuardCursorMismatch);
    }
    if packet.capability_next_bottleneck != PRODUCT_ROUTE_REVIEW_CURSOR
        && packet.capability_next_bottleneck != PRODUCT_ROUTE_REVIEW_NEXT_CURSOR
    {
        return Err(ProductRouteReviewError::CapabilityStatusMismatch);
    }
    if packet.capability_route_status != "vault_research_route_with_packetized_mitigation" {
        return Err(ProductRouteReviewError::CapabilityStatusMismatch);
    }
    if packet.product_build != ProductBuild::Pro
        || packet.pro_status != ProStatus::ResearchCandidate
    {
        return Err(ProductRouteReviewError::ProductStatusMismatch);
    }
    if packet.route_authority != "product_route_review_packet_only" {
        return Err(ProductRouteReviewError::ProductStatusMismatch);
    }
    if packet.surfaces.is_empty() {
        return Err(ProductRouteReviewError::EmptySurface);
    }
    if packet.red_routes.is_empty() {
        return Err(ProductRouteReviewError::EmptyRedRoute);
    }
    if packet.decisions.is_empty() {
        return Err(ProductRouteReviewError::EmptyDecision);
    }
    validate_surfaces(&packet.surfaces)?;
    validate_red_routes(&packet.red_routes)?;
    require_decision(packet, ProductRouteReviewDecision::KeepResearchGated)?;
    require_decision(packet, ProductRouteReviewDecision::PreserveMasFloor)?;
    require_decision(
        packet,
        ProductRouteReviewDecision::RequestSmallModelHarnessPlan,
    )?;
    if !packet.l1_l2_l3_separated
        || packet
            .red_routes
            .iter()
            .any(|route| !route.l1_l2_l3_separated)
    {
        return Err(ProductRouteReviewError::MissingLayerSeparation);
    }
    if packet.mas_overclaim_attempted {
        return Err(ProductRouteReviewError::MasOverclaimAttempted);
    }
    if packet.l2_green_claimed {
        return Err(ProductRouteReviewError::L2GreenClaimAttempted);
    }
    if packet.l3_green_claimed {
        return Err(ProductRouteReviewError::L3GreenClaimAttempted);
    }
    if packet.hidden_route_authority {
        return Err(ProductRouteReviewError::HiddenRouteAuthority);
    }
    if packet.route_policy_mutated {
        return Err(ProductRouteReviewError::RoutePolicyMutation);
    }
    if packet.gate_bypass {
        return Err(ProductRouteReviewError::GateBypass);
    }
    if packet.answer_packet_suppressed {
        return Err(ProductRouteReviewError::AnswerPacketSuppression);
    }
    if packet.hidden_chain_exposed {
        return Err(ProductRouteReviewError::HiddenChainExposure);
    }
    if packet.hidden_cloud_fallback {
        return Err(ProductRouteReviewError::HiddenCloudFallback);
    }
    if packet.live_transport_promoted {
        return Err(ProductRouteReviewError::LiveTransportPromotion);
    }
    if packet.live_70b_promoted {
        return Err(ProductRouteReviewError::LiveSeventyBPromotion);
    }
    if packet.runtime_bytes_loaded > 0 {
        return Err(ProductRouteReviewError::RuntimeBytesLoaded);
    }
    if packet.model_bytes_loaded > 0 {
        return Err(ProductRouteReviewError::ModelBytesLoaded);
    }
    if packet.transport_runtime_bytes_loaded > 0 {
        return Err(ProductRouteReviewError::TransportRuntimeBytesLoaded);
    }
    if packet.metadata_bytes > MAX_METADATA_BYTES {
        return Err(ProductRouteReviewError::MetadataBudgetExceeded);
    }
    Ok(())
}

fn require_decision(
    packet: &ProductRouteReviewPacket,
    decision: ProductRouteReviewDecision,
) -> Result<(), ProductRouteReviewError> {
    if packet.decisions.contains(&decision) {
        return Ok(());
    }
    Err(ProductRouteReviewError::MissingReviewDecision(
        decision.tag(),
    ))
}

fn validate_surfaces(
    surfaces: &[ProductRouteReviewSurface],
) -> Result<(), ProductRouteReviewError> {
    let mut ids = HashSet::with_capacity(surfaces.len());
    for surface in surfaces {
        validate_surface(surface)?;
        if !ids.insert(surface.surface_id.as_str()) {
            return Err(ProductRouteReviewError::DuplicateSurface(
                surface.surface_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_surface(surface: &ProductRouteReviewSurface) -> Result<(), ProductRouteReviewError> {
    validate_token("surface_id", &surface.surface_id)?;
    validate_path("path", &surface.path)?;
    if surface.observed_text.len() < MIN_SURFACE_TEXT_BYTES {
        return Err(ProductRouteReviewError::MissingField("observed_text"));
    }
    for marker in &surface.required_markers {
        validate_marker(marker)?;
        if !surface.observed_text.contains(marker) {
            return Err(ProductRouteReviewError::MissingRequiredMarker(
                marker.clone(),
            ));
        }
    }
    for marker in &surface.forbidden_markers {
        validate_marker(marker)?;
        if surface.observed_text.contains(marker) {
            return Err(ProductRouteReviewError::ForbiddenMarker(marker.clone()));
        }
    }
    Ok(())
}

fn validate_red_routes(routes: &[ProductRouteRedRoute]) -> Result<(), ProductRouteReviewError> {
    let mut ids = HashSet::with_capacity(routes.len());
    for route in routes {
        validate_red_route(route)?;
        if !ids.insert(route.route_id.as_str()) {
            return Err(ProductRouteReviewError::DuplicateRedRoute(
                route.route_id.clone(),
            ));
        }
    }
    for required in REQUIRED_ROUTE_IDS {
        if !ids.contains(required) {
            return Err(ProductRouteReviewError::MissingRequiredRoute(required));
        }
    }
    Ok(())
}

fn validate_red_route(route: &ProductRouteRedRoute) -> Result<(), ProductRouteReviewError> {
    validate_token("route_id", &route.route_id)?;
    validate_token("route_status", &route.route_status)?;
    validate_text("blocker", &route.blocker)?;
    validate_text("user_visible_summary", &route.user_visible_summary)?;
    validate_prefixed("rollback_ref", &route.rollback_ref, ROLLBACK_PREFIX)
        .map_err(|_| ProductRouteReviewError::MissingRollback(route.route_id.clone()))?;
    validate_prefixed(
        "answer_packet_ref",
        &route.answer_packet_ref,
        ANSWER_PACKET_PREFIX,
    )
    .map_err(|_| ProductRouteReviewError::MissingAnswerPacket(route.route_id.clone()))?;
    if route.product_build != ProductBuild::Pro || route.pro_status != ProStatus::ResearchCandidate
    {
        return Err(ProductRouteReviewError::ProductStatusMismatch);
    }
    if route.route_status != "red_research_gated" && route.route_status != "deferred_research_gated"
    {
        return Err(ProductRouteReviewError::CapabilityStatusMismatch);
    }
    if route.witness_refs.is_empty()
        || !route
            .witness_refs
            .iter()
            .any(|reference| reference.starts_with(FALSIFIER_PREFIX))
        || !route
            .witness_refs
            .iter()
            .any(|reference| reference.starts_with(ARTIFACT_PREFIX))
    {
        return Err(ProductRouteReviewError::MissingWitnessRef(
            route.route_id.clone(),
        ));
    }
    if route.user_visible_summary.len() < 64 {
        return Err(ProductRouteReviewError::MissingUserVisibleSummary(
            route.route_id.clone(),
        ));
    }
    if !route.l1_l2_l3_separated {
        return Err(ProductRouteReviewError::MissingLayerSeparation);
    }
    if route.promotion_allowed || route.product_copy_allowed {
        return Err(ProductRouteReviewError::ProductPromotionAttempted(
            route.route_id.clone(),
        ));
    }
    Ok(())
}

fn validate_token(field: &'static str, value: &str) -> Result<(), ProductRouteReviewError> {
    validate_nonempty(field, value)?;
    if value != value.trim() {
        return Err(ProductRouteReviewError::FieldHasSurroundingWhitespace(
            field,
        ));
    }
    if value.chars().any(char::is_control) {
        return Err(ProductRouteReviewError::FieldContainsControlCharacter(
            field,
        ));
    }
    Ok(())
}

fn validate_path(field: &'static str, value: &str) -> Result<(), ProductRouteReviewError> {
    validate_text(field, value)?;
    if value.contains('\0') {
        return Err(ProductRouteReviewError::FieldContainsControlCharacter(
            field,
        ));
    }
    Ok(())
}

fn validate_text(field: &'static str, value: &str) -> Result<(), ProductRouteReviewError> {
    validate_nonempty(field, value)?;
    if value.trim().is_empty() {
        return Err(ProductRouteReviewError::MissingField(field));
    }
    Ok(())
}

fn validate_marker(value: &str) -> Result<(), ProductRouteReviewError> {
    validate_nonempty("marker", value)?;
    if value.chars().any(char::is_control) {
        return Err(ProductRouteReviewError::FieldContainsControlCharacter(
            "marker",
        ));
    }
    Ok(())
}

fn validate_prefixed(
    field: &'static str,
    value: &str,
    prefix: &str,
) -> Result<(), ProductRouteReviewError> {
    validate_token(field, value)?;
    if !value.starts_with(prefix) {
        return Err(match field {
            "admission_ref" => ProductRouteReviewError::MissingAdmission,
            "scope_rex_ref" => ProductRouteReviewError::MissingScopeRex,
            "sovereign_gate_ref" => ProductRouteReviewError::MissingSovereignGate,
            "compatibility_fence" => ProductRouteReviewError::MissingCompatibilityFence,
            _ => ProductRouteReviewError::MissingField(field),
        });
    }
    Ok(())
}

fn validate_nonempty(field: &'static str, value: &str) -> Result<(), ProductRouteReviewError> {
    if value.is_empty() {
        return Err(ProductRouteReviewError::MissingField(field));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn surface(id: &str) -> ProductRouteReviewSurface {
        ProductRouteReviewSurface::new(
            id,
            format!("docs/{id}.md"),
            vec![
                "Epistemos is a local cognitive substrate".to_string(),
                PRODUCT_ROUTE_REVIEW_CURSOR.to_string(),
                "vault_research_route_with_packetized_mitigation".to_string(),
                "no claim promotes without visible proof".to_string(),
            ],
            vec!["MAS ships live 70B".to_string(), "live ColdStream product ready".to_string()],
            "Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof. ready_for_product_route_review vault_research_route_with_packetized_mitigation L1/L2/L3 remain separated."
                .to_string(),
        )
        .unwrap()
    }

    fn red_route(id: &str) -> ProductRouteRedRoute {
        ProductRouteRedRoute::new(
            id,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "red_research_gated",
            format!("{id} remains red until a live runtime/witness gate passes"),
            vec![
                format!("falsifier:F-{id}"),
                format!("artifact:artifacts/falsifiers/{id}/result.json"),
            ],
            format!("rollback:{id}:keep-gated"),
            format!("answer_packet:{id}:review"),
            format!("{id} is visible as a red research route; L1 metadata may pass, but L2 capability and L3 product runtime remain unpromoted until live evidence passes."),
            true,
            false,
            false,
            false,
        )
        .unwrap()
    }

    fn packet() -> ProductRouteReviewPacket {
        ProductRouteReviewPacket::new(
            "product_route_review_2026_06_05",
            PRODUCT_ROUTE_REVIEW_CURSOR,
            "vault_research_route_with_packetized_mitigation",
            PRODUCT_ROUTE_REVIEW_CURSOR,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "product_route_review_packet_only",
            "admission:scope-rex-sovereign-gate:product-route-review",
            "scope_rex:product-route-review",
            "sovereign_gate:product-route-review",
            "compat:product-route-review:v1",
            "run_event_log:product-route-review",
            BTreeSet::from([
                ProductRouteReviewDecision::KeepResearchGated,
                ProductRouteReviewDecision::PreserveMasFloor,
                ProductRouteReviewDecision::RequestSmallModelHarnessPlan,
            ]),
            vec![surface("living_index"), surface("lattice_html")],
            REQUIRED_ROUTE_IDS.iter().map(|id| red_route(id)).collect(),
            64 * 1024,
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
        .unwrap()
    }

    #[test]
    fn valid_review_packet_preserves_red_routes() {
        let packet = packet();
        let metrics = packet.metrics();
        assert_eq!(metrics.surface_count, 2);
        assert_eq!(metrics.required_red_route_count, 4);
        assert_eq!(metrics.promotion_allowed_count, 0);
        assert_eq!(metrics.runtime_bytes_loaded, 0);
        assert!(packet.address().starts_with("uas:product-route-review:"));
    }

    #[test]
    fn deterministic_address_ignores_route_order() {
        let packet = packet();
        let address = packet.address();
        let mut routes = packet.red_routes.clone();
        routes.reverse();
        let reordered = ProductRouteReviewPacket::new(
            packet.review_id,
            packet.guard_next_existing_work,
            packet.capability_route_status,
            packet.capability_next_bottleneck,
            packet.product_build,
            packet.pro_status,
            packet.route_authority,
            packet.admission_ref,
            packet.scope_rex_ref,
            packet.sovereign_gate_ref,
            packet.compatibility_fence,
            packet.run_event_log_ref,
            packet.decisions,
            packet.surfaces,
            routes,
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
        )
        .unwrap();
        assert_eq!(address, reordered.address());
    }

    #[test]
    fn rejects_false_l2_l3_and_mas_promotions() {
        let mut l2_packet = packet();
        l2_packet.l2_green_claimed = true;
        assert!(matches!(
            validate_packet(&l2_packet),
            Err(ProductRouteReviewError::L2GreenClaimAttempted)
        ));
        let mut l3_packet = packet();
        l3_packet.l3_green_claimed = true;
        assert!(matches!(
            validate_packet(&l3_packet),
            Err(ProductRouteReviewError::L3GreenClaimAttempted)
        ));
        let mut mas_packet = packet();
        mas_packet.mas_overclaim_attempted = true;
        assert!(matches!(
            validate_packet(&mas_packet),
            Err(ProductRouteReviewError::MasOverclaimAttempted)
        ));
    }

    #[test]
    fn rejects_missing_red_routes_and_product_copy() {
        let mut packet = packet();
        packet.red_routes.pop();
        assert!(matches!(
            validate_packet(&packet),
            Err(ProductRouteReviewError::MissingRequiredRoute(_))
        ));
        let mut route = red_route("kv_direct_128k");
        route.product_copy_allowed = true;
        assert!(matches!(
            validate_red_route(&route),
            Err(ProductRouteReviewError::ProductPromotionAttempted(_))
        ));
    }

    #[test]
    fn rejects_surface_and_runtime_edge_cases() {
        let mut bad_surface = surface("living_index");
        bad_surface
            .observed_text
            .push_str(" live ColdStream product ready ");
        assert!(matches!(
            validate_surface(&bad_surface),
            Err(ProductRouteReviewError::ForbiddenMarker(_))
        ));
        let mut runtime_packet = packet();
        runtime_packet.runtime_bytes_loaded = 1;
        assert!(matches!(
            validate_packet(&runtime_packet),
            Err(ProductRouteReviewError::RuntimeBytesLoaded)
        ));
        let mut authority_packet = packet();
        authority_packet.hidden_route_authority = true;
        assert!(matches!(
            validate_packet(&authority_packet),
            Err(ProductRouteReviewError::HiddenRouteAuthority)
        ));
    }
}
