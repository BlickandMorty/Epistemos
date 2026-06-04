//! Provider-route copy/source guard contracts.
//!
//! These metadata-only contracts keep provider, cloud, KV-Direct, and 70B
//! route language from becoming hidden product capability or live route
//! authority. They are copy/source witnesses only.

use super::{ProStatus, ProductBuild};
use crate::falsifier_artifacts::sha256_hex;
use std::collections::{BTreeMap, HashSet};

pub const PROVIDER_ROUTE_COPY_SOURCE_GUARD_CURSOR: &str = "provider_route_copy_source_guard";
pub const PROVIDER_ROUTE_COPY_SOURCE_NEXT_CURSOR: &str = "transport_trace_answer_packet";

const MAX_COPY_TEXT_BYTES: u64 = 64 * 1024;

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:provider-route-copy-source-guard:source-kind
// Plane: State + Controller
// Residency: metadata-only source classification; no provider/runtime bytes.
pub enum ProviderRouteSourceKind {
    PracticalMlx,
    ColdAssembly,
    ProviderReference,
    KvDirect,
    ProductRuntime,
}

impl ProviderRouteSourceKind {
    fn tag(&self) -> &'static str {
        match self {
            Self::PracticalMlx => "practical_mlx",
            Self::ColdAssembly => "cold_assembly",
            Self::ProviderReference => "provider_reference",
            Self::KvDirect => "kv_direct",
            Self::ProductRuntime => "product_runtime",
        }
    }
}

#[derive(Clone, Debug)]
// UAS: uas:provider-route-copy-source-guard:copy-claim
// Plane: State + Controller + Verification
// Residency: metadata-only claim card; never a live route policy.
pub struct ProviderRouteCopyClaim {
    pub claim_id: String,
    pub surface_id: String,
    pub source_kind: ProviderRouteSourceKind,
    pub claim_scope: String,
    pub visible_layer_status: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub copy_text: String,
    pub evidence_refs: Vec<String>,
    pub admission_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence: String,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub provider_call_attempted: bool,
    pub prompt_manifest_created: bool,
    pub hidden_cloud_fallback: bool,
    pub product_route_promoted: bool,
    pub source_laundered_to_capability: bool,
    pub route_policy_mutated: bool,
    pub hidden_route_authority: bool,
    pub hidden_chain_exposed: bool,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
}

impl ProviderRouteCopyClaim {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        claim_id: impl Into<String>,
        surface_id: impl Into<String>,
        source_kind: ProviderRouteSourceKind,
        claim_scope: impl Into<String>,
        visible_layer_status: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        copy_text: impl Into<String>,
        evidence_refs: Vec<String>,
        admission_ref: impl Into<String>,
        rollback_ref: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        compatibility_fence: impl Into<String>,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        provider_call_attempted: bool,
        prompt_manifest_created: bool,
        hidden_cloud_fallback: bool,
        product_route_promoted: bool,
        source_laundered_to_capability: bool,
        route_policy_mutated: bool,
        hidden_route_authority: bool,
        hidden_chain_exposed: bool,
        runtime_bytes_loaded: u64,
        model_bytes_loaded: u64,
    ) -> Result<Self, ProviderRouteCopySourceError> {
        let claim = Self {
            claim_id: claim_id.into(),
            surface_id: surface_id.into(),
            source_kind,
            claim_scope: claim_scope.into(),
            visible_layer_status: visible_layer_status.into(),
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            copy_text: copy_text.into(),
            evidence_refs,
            admission_ref: admission_ref.into(),
            rollback_ref: rollback_ref.into(),
            run_event_log_ref: run_event_log_ref.into(),
            answer_packet_ref: answer_packet_ref.into(),
            compatibility_fence: compatibility_fence.into(),
            metadata_bytes,
            l1_l2_l3_separated,
            provider_call_attempted,
            prompt_manifest_created,
            hidden_cloud_fallback,
            product_route_promoted,
            source_laundered_to_capability,
            route_policy_mutated,
            hidden_route_authority,
            hidden_chain_exposed,
            runtime_bytes_loaded,
            model_bytes_loaded,
        };
        validate_claim(&claim)?;
        Ok(claim)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:provider-route-copy-source-guard:surface
// Plane: State + Verification
// Residency: local source-surface scan; no runtime/model bytes.
pub struct ProviderRouteCopySurface {
    pub surface_id: String,
    pub path: String,
    pub required_markers: Vec<String>,
    pub forbidden_promotions: Vec<String>,
    pub observed_text: String,
}

impl ProviderRouteCopySurface {
    pub fn new(
        surface_id: impl Into<String>,
        path: impl Into<String>,
        required_markers: Vec<String>,
        forbidden_promotions: Vec<String>,
        observed_text: impl Into<String>,
    ) -> Result<Self, ProviderRouteCopySourceError> {
        let surface = Self {
            surface_id: surface_id.into(),
            path: path.into(),
            required_markers,
            forbidden_promotions,
            observed_text: observed_text.into(),
        };
        validate_surface(&surface)?;
        Ok(surface)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:provider-route-copy-source-guard:registry
// Plane: Controller + Verification
// Residency: metadata-only guard registry.
pub struct ProviderRouteCopySourceGuard {
    pub surfaces: Vec<ProviderRouteCopySurface>,
    pub claims: Vec<ProviderRouteCopyClaim>,
}

impl ProviderRouteCopySourceGuard {
    pub fn new(
        surfaces: Vec<ProviderRouteCopySurface>,
        claims: Vec<ProviderRouteCopyClaim>,
    ) -> Result<Self, ProviderRouteCopySourceError> {
        validate_surfaces(&surfaces)?;
        validate_claims(&claims, &surfaces)?;
        Ok(Self { surfaces, claims })
    }

    pub fn metrics(&self) -> ProviderRouteCopySourceMetrics {
        let source_kind_count = self
            .claims
            .iter()
            .map(|claim| claim.source_kind.tag())
            .collect::<HashSet<_>>()
            .len() as u64;
        let surface_marker_count = self
            .surfaces
            .iter()
            .map(|surface| surface.required_markers.len() as u64)
            .sum();
        let forbidden_promotion_count = self
            .surfaces
            .iter()
            .map(|surface| surface.forbidden_promotions.len() as u64)
            .sum();
        let max_copy_text_bytes = self
            .claims
            .iter()
            .map(|claim| claim.copy_text.len() as u64)
            .max()
            .unwrap_or(0);
        let max_metadata_bytes = self
            .claims
            .iter()
            .map(|claim| claim.metadata_bytes)
            .max()
            .unwrap_or(0);
        let provider_call_count = self
            .claims
            .iter()
            .map(|claim| u64::from(claim.provider_call_attempted))
            .sum();
        let prompt_manifest_count = self
            .claims
            .iter()
            .map(|claim| u64::from(claim.prompt_manifest_created))
            .sum();
        let runtime_bytes_loaded = self
            .claims
            .iter()
            .map(|claim| claim.runtime_bytes_loaded)
            .sum();
        let model_bytes_loaded = self
            .claims
            .iter()
            .map(|claim| claim.model_bytes_loaded)
            .sum();
        ProviderRouteCopySourceMetrics {
            surface_count: self.surfaces.len() as u64,
            claim_count: self.claims.len() as u64,
            source_kind_count,
            surface_marker_count,
            forbidden_promotion_count,
            max_copy_text_bytes,
            max_metadata_bytes,
            provider_call_count,
            prompt_manifest_count,
            runtime_bytes_loaded,
            model_bytes_loaded,
        }
    }

    pub fn address(&self) -> String {
        let mut parts = self
            .claims
            .iter()
            .map(|claim| {
                format!(
                    "{}|{}|{}|{}|{}|{}|{}",
                    claim.claim_id,
                    claim.surface_id,
                    claim.source_kind.tag(),
                    claim.claim_scope,
                    claim.visible_layer_status,
                    claim.route_authority,
                    claim.compatibility_fence
                )
            })
            .collect::<Vec<_>>();
        parts.extend(self.surfaces.iter().map(|surface| {
            format!(
                "{}|{}|{}",
                surface.surface_id,
                surface.path,
                surface.required_markers.join(";")
            )
        }));
        parts.sort();
        format!(
            "uas:provider-route-copy-source-guard:{}",
            sha256_hex(parts.join("\n").as_bytes())
        )
    }
}

#[derive(Clone, Debug, Default)]
// UAS: uas:provider-route-copy-source-guard:metrics
// Plane: Verification
// Residency: metadata-only aggregation.
pub struct ProviderRouteCopySourceMetrics {
    pub surface_count: u64,
    pub claim_count: u64,
    pub source_kind_count: u64,
    pub surface_marker_count: u64,
    pub forbidden_promotion_count: u64,
    pub max_copy_text_bytes: u64,
    pub max_metadata_bytes: u64,
    pub provider_call_count: u64,
    pub prompt_manifest_count: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
// UAS: uas:provider-route-copy-source-guard:error
// Plane: Verification
// Residency: rejection taxonomy for copy/source guard.
pub enum ProviderRouteCopySourceError {
    EmptySurface,
    EmptyClaim,
    DuplicateSurface(String),
    DuplicateClaim(String),
    MissingSurfaceRef(String),
    MissingRequiredMarker(String),
    ForbiddenPromotion(String),
    MissingEvidenceRef,
    BadEvidenceRef(String),
    BadAdmissionRef,
    BadRollbackRef,
    BadRunEventLogRef,
    BadAnswerPacketRef,
    BadCompatibilityFence,
    MissingLayerSeparation,
    ProductBuildPromotion,
    ProStatusPromotion,
    BadRouteAuthority,
    CopyTextOverBudget,
    MetadataOverBudget,
    ProviderCallAttempted,
    PromptManifestCreated,
    HiddenCloudFallback,
    ProductRoutePromoted,
    SourceLaunderedToCapability,
    RoutePolicyMutated,
    HiddenRouteAuthority,
    HiddenChainExposed,
    RuntimeBytesLoaded,
    ModelBytesLoaded,
}

impl std::fmt::Display for ProviderRouteCopySourceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::EmptySurface => write!(f, "missing provider-route copy surface"),
            Self::EmptyClaim => write!(f, "missing provider-route copy claim"),
            Self::DuplicateSurface(id) => write!(f, "duplicate copy surface `{id}`"),
            Self::DuplicateClaim(id) => write!(f, "duplicate copy claim `{id}`"),
            Self::MissingSurfaceRef(id) => write!(f, "claim references missing surface `{id}`"),
            Self::MissingRequiredMarker(marker) => {
                write!(f, "copy surface missing required marker `{marker}`")
            }
            Self::ForbiddenPromotion(marker) => {
                write!(f, "copy surface contains forbidden promotion `{marker}`")
            }
            Self::MissingEvidenceRef => write!(f, "copy claim has no evidence refs"),
            Self::BadEvidenceRef(value) => write!(f, "bad evidence ref `{value}`"),
            Self::BadAdmissionRef => write!(f, "bad admission ref"),
            Self::BadRollbackRef => write!(f, "bad rollback ref"),
            Self::BadRunEventLogRef => write!(f, "bad RunEventLog ref"),
            Self::BadAnswerPacketRef => write!(f, "bad AnswerPacket ref"),
            Self::BadCompatibilityFence => write!(f, "bad compatibility fence"),
            Self::MissingLayerSeparation => write!(f, "missing L1/L2/L3 separation"),
            Self::ProductBuildPromotion => write!(f, "copy claim promoted to MAS/product build"),
            Self::ProStatusPromotion => write!(f, "copy claim promoted to Pro Live"),
            Self::BadRouteAuthority => write!(f, "copy claim has route authority"),
            Self::CopyTextOverBudget => write!(f, "copy text over budget"),
            Self::MetadataOverBudget => write!(f, "metadata over budget"),
            Self::ProviderCallAttempted => write!(f, "provider call attempted"),
            Self::PromptManifestCreated => write!(f, "prompt manifest created"),
            Self::HiddenCloudFallback => write!(f, "hidden cloud fallback present"),
            Self::ProductRoutePromoted => write!(f, "product route promoted"),
            Self::SourceLaunderedToCapability => write!(f, "source laundered to capability"),
            Self::RoutePolicyMutated => write!(f, "route policy mutated"),
            Self::HiddenRouteAuthority => write!(f, "hidden route authority present"),
            Self::HiddenChainExposed => write!(f, "hidden chain exposed"),
            Self::RuntimeBytesLoaded => write!(f, "runtime bytes loaded"),
            Self::ModelBytesLoaded => write!(f, "model bytes loaded"),
        }
    }
}

impl std::error::Error for ProviderRouteCopySourceError {}

fn validate_surfaces(
    surfaces: &[ProviderRouteCopySurface],
) -> Result<(), ProviderRouteCopySourceError> {
    if surfaces.is_empty() {
        return Err(ProviderRouteCopySourceError::EmptySurface);
    }
    let mut seen = HashSet::new();
    for surface in surfaces {
        validate_surface(surface)?;
        if !seen.insert(surface.surface_id.clone()) {
            return Err(ProviderRouteCopySourceError::DuplicateSurface(
                surface.surface_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_surface(
    surface: &ProviderRouteCopySurface,
) -> Result<(), ProviderRouteCopySourceError> {
    if surface.surface_id.trim().is_empty()
        || surface.path.trim().is_empty()
        || surface.required_markers.is_empty()
    {
        return Err(ProviderRouteCopySourceError::EmptySurface);
    }
    for marker in &surface.required_markers {
        if marker.trim().is_empty() || !surface.observed_text.contains(marker) {
            return Err(ProviderRouteCopySourceError::MissingRequiredMarker(
                marker.clone(),
            ));
        }
    }
    for marker in &surface.forbidden_promotions {
        if !marker.trim().is_empty() && surface.observed_text.contains(marker) {
            return Err(ProviderRouteCopySourceError::ForbiddenPromotion(
                marker.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_claims(
    claims: &[ProviderRouteCopyClaim],
    surfaces: &[ProviderRouteCopySurface],
) -> Result<(), ProviderRouteCopySourceError> {
    if claims.is_empty() {
        return Err(ProviderRouteCopySourceError::EmptyClaim);
    }
    let surface_ids = surfaces
        .iter()
        .map(|surface| surface.surface_id.as_str())
        .collect::<HashSet<_>>();
    let mut seen = HashSet::new();
    for claim in claims {
        validate_claim(claim)?;
        if !seen.insert(claim.claim_id.clone()) {
            return Err(ProviderRouteCopySourceError::DuplicateClaim(
                claim.claim_id.clone(),
            ));
        }
        if !surface_ids.contains(claim.surface_id.as_str()) {
            return Err(ProviderRouteCopySourceError::MissingSurfaceRef(
                claim.surface_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_claim(claim: &ProviderRouteCopyClaim) -> Result<(), ProviderRouteCopySourceError> {
    if claim.claim_id.trim().is_empty()
        || claim.surface_id.trim().is_empty()
        || claim.claim_scope.trim().is_empty()
        || claim.visible_layer_status.trim().is_empty()
        || claim.copy_text.trim().is_empty()
    {
        return Err(ProviderRouteCopySourceError::EmptyClaim);
    }
    if !claim.l1_l2_l3_separated {
        return Err(ProviderRouteCopySourceError::MissingLayerSeparation);
    }
    if claim.product_build != ProductBuild::Pro {
        return Err(ProviderRouteCopySourceError::ProductBuildPromotion);
    }
    if claim.pro_status != ProStatus::ResearchCandidate {
        return Err(ProviderRouteCopySourceError::ProStatusPromotion);
    }
    if claim.route_authority != "copy_source_only" {
        return Err(ProviderRouteCopySourceError::BadRouteAuthority);
    }
    if !claim.copy_text.contains("metadata-only")
        || !claim.copy_text.contains("L2 remains")
        || !claim.copy_text.contains("L3")
    {
        return Err(ProviderRouteCopySourceError::MissingLayerSeparation);
    }
    if claim.copy_text.len() as u64 > MAX_COPY_TEXT_BYTES {
        return Err(ProviderRouteCopySourceError::CopyTextOverBudget);
    }
    if claim.metadata_bytes > MAX_COPY_TEXT_BYTES {
        return Err(ProviderRouteCopySourceError::MetadataOverBudget);
    }
    if claim.evidence_refs.is_empty() {
        return Err(ProviderRouteCopySourceError::MissingEvidenceRef);
    }
    let mut evidence_by_prefix = BTreeMap::<&str, usize>::new();
    for evidence_ref in &claim.evidence_refs {
        let prefix = evidence_ref
            .split_once(':')
            .map(|(prefix, _)| prefix)
            .unwrap_or("");
        *evidence_by_prefix.entry(prefix).or_default() += 1;
        if !matches!(
            prefix,
            "falsifier" | "artifact" | "living_index" | "lattice_html" | "capability_kernel"
        ) {
            return Err(ProviderRouteCopySourceError::BadEvidenceRef(
                evidence_ref.clone(),
            ));
        }
    }
    for required in ["falsifier", "artifact"] {
        if !evidence_by_prefix.contains_key(required) {
            return Err(ProviderRouteCopySourceError::BadEvidenceRef(
                required.to_string(),
            ));
        }
    }
    if !claim.admission_ref.starts_with("admission:") {
        return Err(ProviderRouteCopySourceError::BadAdmissionRef);
    }
    if !claim.rollback_ref.starts_with("rollback:") {
        return Err(ProviderRouteCopySourceError::BadRollbackRef);
    }
    if !claim.run_event_log_ref.starts_with("run_event_log:") {
        return Err(ProviderRouteCopySourceError::BadRunEventLogRef);
    }
    if !claim.answer_packet_ref.starts_with("answer_packet:") {
        return Err(ProviderRouteCopySourceError::BadAnswerPacketRef);
    }
    if !claim.compatibility_fence.starts_with("compat:") {
        return Err(ProviderRouteCopySourceError::BadCompatibilityFence);
    }
    if claim.provider_call_attempted {
        return Err(ProviderRouteCopySourceError::ProviderCallAttempted);
    }
    if claim.prompt_manifest_created {
        return Err(ProviderRouteCopySourceError::PromptManifestCreated);
    }
    if claim.hidden_cloud_fallback {
        return Err(ProviderRouteCopySourceError::HiddenCloudFallback);
    }
    if claim.product_route_promoted {
        return Err(ProviderRouteCopySourceError::ProductRoutePromoted);
    }
    if claim.source_laundered_to_capability {
        return Err(ProviderRouteCopySourceError::SourceLaunderedToCapability);
    }
    if claim.route_policy_mutated {
        return Err(ProviderRouteCopySourceError::RoutePolicyMutated);
    }
    if claim.hidden_route_authority {
        return Err(ProviderRouteCopySourceError::HiddenRouteAuthority);
    }
    if claim.hidden_chain_exposed {
        return Err(ProviderRouteCopySourceError::HiddenChainExposed);
    }
    if claim.runtime_bytes_loaded > 0 {
        return Err(ProviderRouteCopySourceError::RuntimeBytesLoaded);
    }
    if claim.model_bytes_loaded > 0 {
        return Err(ProviderRouteCopySourceError::ModelBytesLoaded);
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn claim(id: &str) -> ProviderRouteCopyClaim {
        ProviderRouteCopyClaim::new(
            id,
            "living_index",
            ProviderRouteSourceKind::ProviderReference,
            "default_route_copy",
            "L1 only; L2 remains red; L3 unchanged",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "copy_source_only",
            "F-ProviderRoute-CopySourceGuard PASS metadata-only; L2 remains red; L3 product runtime is unchanged.",
            vec![
                "falsifier:F-LargeModelProviderReference-DeferredByMlxRoute".to_string(),
                "artifact:large_model_provider_reference_deferred_by_mlx_route".to_string(),
            ],
            "admission:scope-rex-sovereign-gate:copy-source",
            "rollback:provider-route-copy-source:v1",
            "run_event_log:provider-route-copy-source:v1",
            "answer_packet:provider-route-copy-source:v1",
            "compat:provider-route-copy-source:v1",
            1024,
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
        )
        .expect("claim")
    }

    fn surface() -> ProviderRouteCopySurface {
        ProviderRouteCopySurface::new(
            "living_index",
            "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md",
            vec![
                "provider_route_copy_source_guard".to_string(),
                "L2 remains".to_string(),
                "L3".to_string(),
            ],
            vec!["70B product route is live".to_string()],
            "provider_route_copy_source_guard L2 remains L3 product runtime unchanged",
        )
        .expect("surface")
    }

    #[test]
    fn valid_guard_has_deterministic_address() {
        let guard = ProviderRouteCopySourceGuard::new(vec![surface()], vec![claim("claim-a")])
            .expect("guard");
        let mut reversed = guard.claims.clone();
        reversed.reverse();
        let guard_reversed =
            ProviderRouteCopySourceGuard::new(vec![surface()], reversed).expect("guard");
        assert_eq!(guard.address(), guard_reversed.address());
        assert!(guard
            .address()
            .starts_with("uas:provider-route-copy-source-guard:sha256:"));
    }

    #[test]
    fn rejects_source_laundering_and_product_promotion() {
        let mut bad = claim("claim-a");
        bad.source_laundered_to_capability = true;
        assert_eq!(
            ProviderRouteCopySourceGuard::new(vec![surface()], vec![bad]).unwrap_err(),
            ProviderRouteCopySourceError::SourceLaunderedToCapability
        );

        let mut bad = claim("claim-a");
        bad.product_route_promoted = true;
        assert_eq!(
            ProviderRouteCopySourceGuard::new(vec![surface()], vec![bad]).unwrap_err(),
            ProviderRouteCopySourceError::ProductRoutePromoted
        );
    }

    #[test]
    fn rejects_provider_manifest_runtime_and_route_mutation() {
        let mut bad = claim("claim-a");
        bad.provider_call_attempted = true;
        assert_eq!(
            ProviderRouteCopySourceGuard::new(vec![surface()], vec![bad]).unwrap_err(),
            ProviderRouteCopySourceError::ProviderCallAttempted
        );

        let mut bad = claim("claim-a");
        bad.prompt_manifest_created = true;
        assert_eq!(
            ProviderRouteCopySourceGuard::new(vec![surface()], vec![bad]).unwrap_err(),
            ProviderRouteCopySourceError::PromptManifestCreated
        );

        let mut bad = claim("claim-a");
        bad.route_policy_mutated = true;
        assert_eq!(
            ProviderRouteCopySourceGuard::new(vec![surface()], vec![bad]).unwrap_err(),
            ProviderRouteCopySourceError::RoutePolicyMutated
        );
    }

    #[test]
    fn rejects_surface_drift() {
        let bad_surface = ProviderRouteCopySurface::new(
            "living_index",
            "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md",
            vec!["provider_route_copy_source_guard".to_string()],
            vec!["70B product route is live".to_string()],
            "70B product route is live",
        );
        assert_eq!(
            bad_surface.unwrap_err(),
            ProviderRouteCopySourceError::MissingRequiredMarker(
                "provider_route_copy_source_guard".to_string()
            )
        );

        let bad_surface = ProviderRouteCopySurface::new(
            "living_index",
            "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md",
            vec!["provider_route_copy_source_guard".to_string()],
            vec!["70B product route is live".to_string()],
            "provider_route_copy_source_guard 70B product route is live",
        );
        assert_eq!(
            bad_surface.unwrap_err(),
            ProviderRouteCopySourceError::ForbiddenPromotion(
                "70B product route is live".to_string()
            )
        );
    }
}
