//! AppColdStore route-card metadata for non-executing ColdStore plans.
//!
//! This maps a passed `ResidencyPlan` into durable atlas, regenerable warm
//! cache, and hot runway manifest rows. It does not mmap bytes, warm caches,
//! allocate model buffers, or run inference.

use serde::{Deserialize, Serialize};

use crate::eidos::EidosRoutePrior;
use crate::uas::{
    construction_card::{pro_status_preimage, product_build_preimage},
    ByteRange, ProStatus, ProductBuild, ResidencyPlan, ResidencyPlanStatus, ResidencyTier,
    UasAddress, UasKind, WeightBlockManifest, WeightBlockResidencyClass,
};

const APP_COLD_STORE_LAYOUT_FALSIFIER_ID: &str = "F-AppColdStore-Layout";
const PARAM_ROUTE_CARD_ADMISSION_FALSIFIER_ID: &str = "F-ParamRouteCard-Admission";

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AppColdStorePlacement {
    DurableAtlas,
    WarmCache,
    HotRunway,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AppColdStoreUnit {
    pub uas_address: UasAddress,
    pub model_id: String,
    pub source_uri: String,
    pub byte_range: ByteRange,
    pub content_hash_hex: String,
    pub codec: String,
    pub placement: AppColdStorePlacement,
    pub mmap_eligible: bool,
    pub rebuildable_from_durable: bool,
}

impl AppColdStoreUnit {
    fn from_block(block: &WeightBlockManifest, placement: AppColdStorePlacement) -> Self {
        Self {
            uas_address: block.uas_address.clone(),
            model_id: block.model_id.clone(),
            source_uri: block.source_uri.clone(),
            byte_range: block.byte_range,
            content_hash_hex: block.content_hash_hex.clone(),
            codec: block.canonical_lattice_codec().to_string(),
            placement,
            mmap_eligible: matches!(placement, AppColdStorePlacement::DurableAtlas),
            rebuildable_from_durable: matches!(placement, AppColdStorePlacement::WarmCache),
        }
    }
}

#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct AppColdStoreRouteCardTotals {
    pub durable_atlas_bytes: u64,
    pub warm_cache_bytes: u64,
    pub hot_runway_bytes: u64,
    pub total_addressed_bytes: u64,
    pub active_runtime_bytes: u64,
    pub runtime_model_bytes_loaded: u64,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct AppColdStoreRouteCard {
    pub card_address: UasAddress,
    pub task_signature: String,
    pub durable_units: Vec<AppColdStoreUnit>,
    pub warm_cache_units: Vec<AppColdStoreUnit>,
    pub hot_runway_units: Vec<AppColdStoreUnit>,
    pub totals: AppColdStoreRouteCardTotals,
    pub verifier_stack: Vec<String>,
    pub rollback_reference: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub residency_status: ResidencyTier,
    pub residency_plan_address: Option<UasAddress>,
    pub cache_rebuild_policy: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub eidos_route_prior: Option<EidosRoutePrior>,
}

impl AppColdStoreRouteCard {
    #[allow(clippy::too_many_arguments)]
    pub fn from_residency_plan(
        task_signature: impl Into<String>,
        verifier_stack: Vec<String>,
        rollback_reference: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        plan: &ResidencyPlan,
        cache_rebuild_policy: impl Into<String>,
        created_at_ms: u64,
    ) -> Result<Self, AppColdStoreRouteCardError> {
        Self::from_residency_plan_with_eidos_prior(
            task_signature,
            verifier_stack,
            rollback_reference,
            product_build,
            pro_status,
            plan,
            cache_rebuild_policy,
            None,
            created_at_ms,
        )
    }

    #[allow(clippy::too_many_arguments)]
    pub fn from_residency_plan_with_eidos_prior(
        task_signature: impl Into<String>,
        verifier_stack: Vec<String>,
        rollback_reference: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        plan: &ResidencyPlan,
        cache_rebuild_policy: impl Into<String>,
        eidos_route_prior: Option<EidosRoutePrior>,
        created_at_ms: u64,
    ) -> Result<Self, AppColdStoreRouteCardError> {
        if plan.status != ResidencyPlanStatus::FitForDryRun {
            return Err(AppColdStoreRouteCardError::PlanRejected);
        }

        let task_signature = task_signature.into();
        let rollback_reference = rollback_reference.into();
        let cache_rebuild_policy = cache_rebuild_policy.into();
        validate_nonempty("task_signature", &task_signature)?;
        validate_nonempty("rollback_reference", &rollback_reference)?;
        validate_nonempty("cache_rebuild_policy", &cache_rebuild_policy)?;
        if verifier_stack.is_empty() {
            return Err(AppColdStoreRouteCardError::MissingVerifier);
        }
        for verifier in &verifier_stack {
            validate_nonempty("verifier_stack", verifier)?;
        }
        if !verifier_stack
            .iter()
            .any(|verifier| verifier == APP_COLD_STORE_LAYOUT_FALSIFIER_ID)
        {
            return Err(AppColdStoreRouteCardError::MissingAppColdStoreLayoutVerifier);
        }
        if !verifier_stack
            .iter()
            .any(|verifier| verifier == PARAM_ROUTE_CARD_ADMISSION_FALSIFIER_ID)
        {
            return Err(AppColdStoreRouteCardError::MissingParamRouteCardAdmissionVerifier);
        }
        if let Some(prior) = &eidos_route_prior {
            validate_eidos_route_prior(&task_signature, prior)?;
        }

        let residency_status = plan.effective_residency_tier;
        validate_build_status(&product_build, &pro_status, residency_status)?;

        let mut durable_units = Vec::new();
        let mut warm_cache_units = Vec::new();
        let mut hot_runway_units = Vec::new();
        for block in &plan.blocks {
            match block.residency_class {
                WeightBlockResidencyClass::ColdMmapSsd => durable_units.push(
                    AppColdStoreUnit::from_block(block, AppColdStorePlacement::DurableAtlas),
                ),
                WeightBlockResidencyClass::WarmCompressedUma => warm_cache_units.push(
                    AppColdStoreUnit::from_block(block, AppColdStorePlacement::WarmCache),
                ),
                WeightBlockResidencyClass::HotUma => hot_runway_units.push(
                    AppColdStoreUnit::from_block(block, AppColdStorePlacement::HotRunway),
                ),
                WeightBlockResidencyClass::ExternalCandidate => {
                    return Err(AppColdStoreRouteCardError::PlanRejected);
                }
            }
        }
        if !warm_cache_units.is_empty() && durable_units.is_empty() {
            return Err(AppColdStoreRouteCardError::WarmCacheRequiresDurableAtlas);
        }
        if durable_units.is_empty() {
            return Err(AppColdStoreRouteCardError::MissingDurableAtlas);
        }

        let totals = AppColdStoreRouteCardTotals {
            durable_atlas_bytes: plan.totals.cold_mmap_ssd_bytes,
            warm_cache_bytes: plan.totals.warm_compressed_uma_bytes,
            hot_runway_bytes: plan.totals.hot_uma_bytes,
            total_addressed_bytes: plan.totals.total_addressed_bytes,
            active_runtime_bytes: plan.totals.active_runtime_bytes,
            runtime_model_bytes_loaded: 0,
        };
        let residency_plan_address = Some(plan.plan_address.clone());
        let card_address = Self::address(
            &task_signature,
            &durable_units,
            &warm_cache_units,
            &hot_runway_units,
            &totals,
            &verifier_stack,
            &rollback_reference,
            &product_build,
            &pro_status,
            residency_status,
            residency_plan_address.as_ref(),
            &cache_rebuild_policy,
            eidos_route_prior.as_ref(),
            created_at_ms,
        );

        Ok(Self {
            card_address,
            task_signature,
            durable_units,
            warm_cache_units,
            hot_runway_units,
            totals,
            verifier_stack,
            rollback_reference,
            product_build,
            pro_status,
            residency_status,
            residency_plan_address,
            cache_rebuild_policy,
            eidos_route_prior,
        })
    }

    #[allow(clippy::too_many_arguments)]
    fn address(
        task_signature: &str,
        durable_units: &[AppColdStoreUnit],
        warm_cache_units: &[AppColdStoreUnit],
        hot_runway_units: &[AppColdStoreUnit],
        totals: &AppColdStoreRouteCardTotals,
        verifier_stack: &[String],
        rollback_reference: &str,
        product_build: &ProductBuild,
        pro_status: &ProStatus,
        residency_status: ResidencyTier,
        residency_plan_address: Option<&UasAddress>,
        cache_rebuild_policy: &str,
        eidos_route_prior: Option<&EidosRoutePrior>,
        created_at_ms: u64,
    ) -> UasAddress {
        let mut preimage = String::new();
        preimage.push_str("app_cold_store_route_card_v1\n");
        preimage.push_str(task_signature);
        preimage.push('\n');
        push_unit_preimages(&mut preimage, "durable", durable_units);
        push_unit_preimages(&mut preimage, "warm", warm_cache_units);
        push_unit_preimages(&mut preimage, "hot", hot_runway_units);
        preimage.push_str(&format!(
            "{}:{}:{}:{}:{}:{}\n",
            totals.durable_atlas_bytes,
            totals.warm_cache_bytes,
            totals.hot_runway_bytes,
            totals.total_addressed_bytes,
            totals.active_runtime_bytes,
            totals.runtime_model_bytes_loaded
        ));
        for verifier in verifier_stack {
            preimage.push_str(verifier);
            preimage.push('\n');
        }
        preimage.push_str(rollback_reference);
        preimage.push('\n');
        preimage.push_str(product_build_preimage(product_build));
        preimage.push('\n');
        preimage.push_str(pro_status_preimage(pro_status));
        preimage.push('\n');
        preimage.push_str(residency_status.wire_tag());
        preimage.push('\n');
        if let Some(address) = residency_plan_address {
            preimage.push_str(&address.to_string());
        }
        preimage.push('\n');
        preimage.push_str(cache_rebuild_policy);
        preimage.push('\n');
        push_eidos_route_prior_preimage(&mut preimage, eidos_route_prior);
        UasAddress::new(
            UasKind::Other("app_cold_store_route_card".to_string()),
            preimage.as_bytes(),
            created_at_ms,
        )
    }
}

fn push_eidos_route_prior_preimage(preimage: &mut String, prior: Option<&EidosRoutePrior>) {
    let Some(prior) = prior else {
        preimage.push_str("eidos_route_prior:none\n");
        return;
    };

    preimage.push_str("eidos_route_prior:v1\n");
    preimage.push_str(&prior.task_signature);
    preimage.push('\n');
    preimage.push_str(prior.manifest_id.as_str());
    preimage.push('\n');
    for evidence_id in &prior.evidence_ids {
        preimage.push_str(evidence_id.as_str());
        preimage.push('\n');
    }
    preimage.push_str(match prior.citation_need {
        crate::eidos::EidosCitationNeed::None => "citation:none",
        crate::eidos::EidosCitationNeed::Optional => "citation:optional",
        crate::eidos::EidosCitationNeed::Required => "citation:required",
    });
    preimage.push('\n');
    push_prior_list_preimage(preimage, "domain", &prior.domain_tags);
    push_prior_list_preimage(preimage, "contradiction", &prior.contradiction_hints);
    push_prior_list_preimage(preimage, "verifier", &prior.likely_verifiers);
    push_prior_list_preimage(preimage, "adapter", &prior.likely_adapter_families);
    push_prior_list_preimage(preimage, "kv", &prior.likely_kv_regions);
    push_prior_list_preimage(preimage, "weight", &prior.likely_weight_page_families);
    preimage.push_str(&format!("confidence_bits:{}\n", prior.confidence.to_bits()));
    push_prior_list_preimage(preimage, "why", &prior.why_matched);
}

fn push_prior_list_preimage(preimage: &mut String, label: &str, values: &[String]) {
    preimage.push_str(label);
    preimage.push('\n');
    for value in values {
        preimage.push_str(value);
        preimage.push('\n');
    }
}

fn push_unit_preimages(preimage: &mut String, label: &str, units: &[AppColdStoreUnit]) {
    preimage.push_str(label);
    preimage.push('\n');
    for unit in units {
        preimage.push_str(&format!(
            "{}|{}|{}|{}|{}|{}|{}|{}|{}\n",
            unit.uas_address,
            unit.model_id,
            unit.source_uri,
            unit.byte_range.start,
            unit.byte_range.len,
            unit.content_hash_hex,
            unit.codec,
            unit.mmap_eligible,
            unit.rebuildable_from_durable
        ));
    }
}

fn validate_build_status(
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    residency_status: ResidencyTier,
) -> Result<(), AppColdStoreRouteCardError> {
    if product_build == &ProductBuild::Mas
        && matches!(
            pro_status,
            ProStatus::ResearchCandidate | ProStatus::VaultPreserved | ProStatus::Omega
        )
    {
        return Err(AppColdStoreRouteCardError::ProductBuildStatusMismatch);
    }
    if product_build == &ProductBuild::Pro
        && pro_status == &ProStatus::Live
        && residency_status == ResidencyTier::CapabilityCeiling
    {
        return Err(AppColdStoreRouteCardError::ProductBuildStatusMismatch);
    }
    if product_build == &ProductBuild::Mas && !residency_status.ships_to_mas() {
        return Err(AppColdStoreRouteCardError::ProductBuildResidencyMismatch);
    }
    Ok(())
}

fn validate_eidos_route_prior(
    task_signature: &str,
    prior: &EidosRoutePrior,
) -> Result<(), AppColdStoreRouteCardError> {
    if prior.task_signature != task_signature {
        return Err(AppColdStoreRouteCardError::RoutePriorTaskMismatch);
    }
    if prior.evidence_ids.is_empty() {
        return Err(AppColdStoreRouteCardError::MissingRoutePriorEvidence);
    }
    if prior.likely_verifiers.is_empty()
        && prior.likely_adapter_families.is_empty()
        && prior.likely_kv_regions.is_empty()
        && prior.likely_weight_page_families.is_empty()
    {
        return Err(AppColdStoreRouteCardError::MissingRoutePriorSupport);
    }
    Ok(())
}

fn validate_nonempty(field: &'static str, value: &str) -> Result<(), AppColdStoreRouteCardError> {
    if value.trim().is_empty() {
        return Err(missing_field_error(field));
    }
    if value.trim() != value {
        return Err(AppColdStoreRouteCardError::FieldHasSurroundingWhitespace { field });
    }
    if value.chars().any(char::is_control) {
        return Err(AppColdStoreRouteCardError::FieldContainsControlCharacter { field });
    }
    Ok(())
}

fn missing_field_error(field: &'static str) -> AppColdStoreRouteCardError {
    match field {
        "task_signature" => AppColdStoreRouteCardError::MissingTaskSignature,
        "verifier_stack" => AppColdStoreRouteCardError::MissingVerifier,
        "rollback_reference" => AppColdStoreRouteCardError::MissingRollback,
        "cache_rebuild_policy" => AppColdStoreRouteCardError::MissingCacheRebuildPolicy,
        _ => AppColdStoreRouteCardError::MissingTaskSignature,
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum AppColdStoreRouteCardError {
    MissingTaskSignature,
    MissingVerifier,
    MissingRollback,
    MissingCacheRebuildPolicy,
    FieldHasSurroundingWhitespace { field: &'static str },
    FieldContainsControlCharacter { field: &'static str },
    PlanRejected,
    MissingAppColdStoreLayoutVerifier,
    MissingParamRouteCardAdmissionVerifier,
    ProductBuildStatusMismatch,
    ProductBuildResidencyMismatch,
    WarmCacheRequiresDurableAtlas,
    MissingDurableAtlas,
    RoutePriorTaskMismatch,
    MissingRoutePriorEvidence,
    MissingRoutePriorSupport,
}

impl std::fmt::Display for AppColdStoreRouteCardError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::MissingTaskSignature => write!(f, "task_signature is required"),
            Self::MissingVerifier => write!(f, "at least one verifier is required"),
            Self::MissingRollback => write!(f, "rollback_reference is required"),
            Self::MissingCacheRebuildPolicy => write!(f, "cache_rebuild_policy is required"),
            Self::FieldHasSurroundingWhitespace { field } => {
                write!(f, "{field} must not contain leading or trailing whitespace")
            }
            Self::FieldContainsControlCharacter { field } => {
                write!(f, "{field} must not contain control characters")
            }
            Self::PlanRejected => write!(f, "residency plan must be FitForDryRun"),
            Self::MissingAppColdStoreLayoutVerifier => write!(
                f,
                "AppColdStore route cards must bind F-AppColdStore-Layout in verifier_stack"
            ),
            Self::MissingParamRouteCardAdmissionVerifier => write!(
                f,
                "AppColdStore route cards must bind F-ParamRouteCard-Admission in verifier_stack"
            ),
            Self::ProductBuildStatusMismatch => write!(
                f,
                "AppColdStore route card product build, Pro status, and residency status are inconsistent"
            ),
            Self::ProductBuildResidencyMismatch => write!(
                f,
                "MAS build AppColdStore route cards cannot carry non-current-app residency status"
            ),
            Self::WarmCacheRequiresDurableAtlas => write!(
                f,
                "AppColdStore warm cache units require at least one durable atlas unit"
            ),
            Self::MissingDurableAtlas => write!(
                f,
                "AppColdStore route cards require at least one durable atlas unit"
            ),
            Self::RoutePriorTaskMismatch => write!(
                f,
                "EidosRoutePrior task_signature must match the AppColdStore route card task_signature"
            ),
            Self::MissingRoutePriorEvidence => write!(
                f,
                "EidosRoutePrior must carry at least one closed evidence id for AppColdStore route-card admission"
            ),
            Self::MissingRoutePriorSupport => write!(
                f,
                "EidosRoutePrior must carry at least one verifier, adapter, KV, or weight-page support hint"
            ),
        }
    }
}

impl std::error::Error for AppColdStoreRouteCardError {}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::eidos::{
        EidosChunkId, EidosCitationNeed, EidosContextPacket, EidosDocumentId, EidosHit,
        EidosIndexManifestId, EidosProvenance, EidosQuery, EidosRetrievalMode,
        EidosScoreComponents, EidosSourceKind, EidosSpan,
    };
    use crate::uas::{
        ProStatus, ProductBuild, ResidencyBudget, ResidencyPlan, ResidencyPlanStatus,
        ResidencyTier, UasAddress, UasKind, WeightBlockEncoding, WeightBlockIrChart,
        WeightBlockManifest, WeightBlockResidencyClass, GIB,
    };

    fn rollback_reference() -> UasAddress {
        UasAddress::new(UasKind::ModelComponent, b"dense-reference", 7)
    }

    fn verifier_stack() -> Vec<String> {
        vec![
            "F-AppColdStore-Layout".to_string(),
            "F-ParamRouteCard-Admission".to_string(),
        ]
    }

    fn block(
        label: &str,
        byte_start: u64,
        byte_len: u64,
        encoding: WeightBlockEncoding,
        residency_class: WeightBlockResidencyClass,
        rollback_reference: Option<UasAddress>,
    ) -> WeightBlockManifest {
        let hash = blake3::hash(label.as_bytes());
        WeightBlockManifest::from_known_hash_hex(
            "local/cold-atlas-fixture",
            format!("file:///models/cold-atlas/{label}.safetensors"),
            byte_start,
            byte_len,
            hash.to_hex().as_str(),
            1_779_000_000_000,
            encoding,
            residency_class,
            WeightBlockIrChart::OpaqueWithWitness,
            0.02,
            "F-AppColdStore-Layout",
            rollback_reference,
        )
        .expect("fixture manifest should build")
    }

    fn fit_plan() -> ResidencyPlan {
        let dense = block(
            "dense-hot",
            0,
            512,
            WeightBlockEncoding::DenseBf16,
            WeightBlockResidencyClass::HotUma,
            None,
        );
        let warm = block(
            "warm-adapter",
            1024,
            256,
            WeightBlockEncoding::Sherry125,
            WeightBlockResidencyClass::WarmCompressedUma,
            Some(rollback_reference()),
        );
        let cold = block(
            "cold-weight-page",
            2048,
            4096,
            WeightBlockEncoding::Nf4,
            WeightBlockResidencyClass::ColdMmapSsd,
            Some(rollback_reference()),
        );
        let budget = ResidencyBudget::new(2 * GIB, GIB, 8 * GIB, 0.25, 16).unwrap();

        let plan = ResidencyPlan::evaluate([cold, dense, warm], budget, 42);

        assert_eq!(plan.status, ResidencyPlanStatus::FitForDryRun);
        plan
    }

    fn eidos_chunk_id(raw: &str) -> EidosChunkId {
        EidosChunkId::new(raw).expect("fixture chunk id should be non-empty")
    }

    fn eidos_document_id(raw: &str) -> EidosDocumentId {
        EidosDocumentId::new(raw).expect("fixture document id should be non-empty")
    }

    fn eidos_packet() -> EidosContextPacket {
        let manifest_id =
            EidosIndexManifestId::new("manifest:neural-importance").expect("manifest id");
        EidosContextPacket {
            query: EidosQuery::new("neural importance atlas", EidosRetrievalMode::Hybrid, 4),
            manifest_id: manifest_id.clone(),
            hits: vec![EidosHit {
                source_id: eidos_chunk_id("vault://note/neural-importance"),
                document_id: eidos_document_id("vault://note/neural-importance-doc"),
                kind: EidosSourceKind::Note,
                span: Some(EidosSpan {
                    byte_start: 0,
                    byte_end: 32,
                }),
                confidence: 0.82,
                score: EidosScoreComponents {
                    lexical: 0.42,
                    semantic: 0.35,
                    recency: 0.05,
                    graph: 0.0,
                },
                provenance: EidosProvenance {
                    manifest_id,
                    mode: EidosRetrievalMode::Hybrid,
                    retrieved_at_unix_ms: 1_779_000_000_000,
                },
            }],
        }
    }

    fn eidos_prior(
        likely_verifiers: Vec<String>,
        likely_adapter_families: Vec<String>,
        likely_kv_regions: Vec<String>,
        likely_weight_page_families: Vec<String>,
        confidence: f32,
    ) -> Result<EidosRoutePrior, crate::eidos::EidosRoutePriorError> {
        let packet = eidos_packet();
        EidosRoutePrior::from_packet(
            &packet,
            "deep_research:neural_importance_atlas",
            vec![eidos_chunk_id("vault://note/neural-importance")],
            EidosCitationNeed::Required,
            vec!["local_reasoning".to_string()],
            vec!["citation_required".to_string()],
            likely_verifiers,
            likely_adapter_families,
            likely_kv_regions,
            likely_weight_page_families,
            confidence,
            vec!["Eidos matched cited vault evidence and route priors".to_string()],
        )
    }

    #[test]
    fn app_cold_store_route_card_maps_plan_tiers_without_loading_model_bytes() {
        let plan = fit_plan();

        let card = AppColdStoreRouteCard::from_residency_plan(
            "deep_research:neural_importance_atlas",
            verifier_stack(),
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            99,
        )
        .expect("fit dry-run plan should produce a route card");

        assert_eq!(card.product_build, ProductBuild::Pro);
        assert_eq!(card.pro_status, ProStatus::ResearchCandidate);
        assert_eq!(card.residency_status, ResidencyTier::CapabilityCeiling);
        assert_eq!(
            card.residency_plan_address.as_ref(),
            Some(&plan.plan_address)
        );
        assert_eq!(card.hot_runway_units.len(), 1);
        assert_eq!(card.warm_cache_units.len(), 1);
        assert_eq!(card.durable_units.len(), 1);
        assert_eq!(card.totals.hot_runway_bytes, 512);
        assert_eq!(card.totals.warm_cache_bytes, 256);
        assert_eq!(card.totals.durable_atlas_bytes, 4096);
        assert_eq!(card.totals.runtime_model_bytes_loaded, 0);
        assert!(card
            .warm_cache_units
            .iter()
            .all(|unit| unit.rebuildable_from_durable));
    }

    #[test]
    fn app_cold_store_route_card_rejects_failed_residency_plan() {
        let budget = ResidencyBudget::new(1024, 1024, 1024, 0.25, 16).unwrap();
        let rejected = ResidencyPlan::evaluate(Vec::<WeightBlockManifest>::new(), budget, 42);

        let err = AppColdStoreRouteCard::from_residency_plan(
            "deep_research:neural_importance_atlas",
            verifier_stack(),
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &rejected,
            "rebuild_warm_cache_from_durable_atlas",
            99,
        )
        .unwrap_err();

        assert_eq!(err, AppColdStoreRouteCardError::PlanRejected);
    }

    #[test]
    fn app_cold_store_route_card_requires_layout_falsifier() {
        let plan = fit_plan();

        let err = AppColdStoreRouteCard::from_residency_plan(
            "deep_research:neural_importance_atlas",
            vec!["F-ParamRouteCard-Admission".to_string()],
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            99,
        )
        .unwrap_err();

        assert_eq!(
            err,
            AppColdStoreRouteCardError::MissingAppColdStoreLayoutVerifier
        );
    }

    #[test]
    fn app_cold_store_route_card_requires_param_route_card_admission_falsifier() {
        let plan = fit_plan();

        let err = AppColdStoreRouteCard::from_residency_plan(
            "deep_research:neural_importance_atlas",
            vec!["F-AppColdStore-Layout".to_string()],
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            99,
        )
        .unwrap_err();

        assert_eq!(
            err,
            AppColdStoreRouteCardError::MissingParamRouteCardAdmissionVerifier
        );
    }

    #[test]
    fn app_cold_store_route_card_keeps_research_status_out_of_mas() {
        let plan = fit_plan();

        let err = AppColdStoreRouteCard::from_residency_plan(
            "deep_research:neural_importance_atlas",
            verifier_stack(),
            "rollback:raw-installed-snapshot",
            ProductBuild::Mas,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            99,
        )
        .unwrap_err();

        assert_eq!(err, AppColdStoreRouteCardError::ProductBuildStatusMismatch);
    }

    #[test]
    fn app_cold_store_route_card_rejects_warm_cache_without_durable_atlas() {
        let warm = block(
            "warm-adapter-only",
            0,
            256,
            WeightBlockEncoding::Sherry125,
            WeightBlockResidencyClass::WarmCompressedUma,
            Some(rollback_reference()),
        );
        let budget = ResidencyBudget::new(0, GIB, 0, 0.25, 16).unwrap();
        let plan = ResidencyPlan::evaluate([warm], budget, 42);
        assert_eq!(plan.status, ResidencyPlanStatus::FitForDryRun);

        let err = AppColdStoreRouteCard::from_residency_plan(
            "deep_research:neural_importance_atlas",
            verifier_stack(),
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            99,
        )
        .unwrap_err();

        assert_eq!(
            err,
            AppColdStoreRouteCardError::WarmCacheRequiresDurableAtlas
        );
    }

    #[test]
    fn app_cold_store_route_card_rejects_hot_runway_without_durable_atlas() {
        let hot = block(
            "hot-controller-only",
            0,
            512,
            WeightBlockEncoding::DenseBf16,
            WeightBlockResidencyClass::HotUma,
            None,
        );
        let budget = ResidencyBudget::new(GIB, 0, 0, 0.25, 16).unwrap();
        let plan = ResidencyPlan::evaluate([hot], budget, 42);
        assert_eq!(plan.status, ResidencyPlanStatus::FitForDryRun);

        let err = AppColdStoreRouteCard::from_residency_plan(
            "deep_research:neural_importance_atlas",
            verifier_stack(),
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            99,
        )
        .unwrap_err();

        assert_eq!(err, AppColdStoreRouteCardError::MissingDurableAtlas);
    }

    #[test]
    fn eidos_route_prior_binds_to_card_without_waking_model_bytes() {
        let plan = fit_plan();
        let prior = eidos_prior(
            vec!["F-AppColdStore-Layout".to_string()],
            vec!["adapter:research_synthesis".to_string()],
            vec!["kv:neural_importance_intro".to_string()],
            vec!["weight_page:controller".to_string()],
            0.82,
        )
        .expect("valid Eidos prior should build");

        let card = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            verifier_stack(),
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            Some(prior.clone()),
            99,
        )
        .expect("fit dry-run plan plus admitted verifier stack should produce a card");

        assert_eq!(card.eidos_route_prior.as_ref(), Some(&prior));
        assert_eq!(card.totals.runtime_model_bytes_loaded, 0);
        assert_eq!(card.durable_units.len(), 1);
        assert_eq!(card.warm_cache_units.len(), 1);
        assert_eq!(card.hot_runway_units.len(), 1);
    }

    #[test]
    fn eidos_route_prior_does_not_bypass_param_route_card_admission() {
        let plan = fit_plan();
        let prior = eidos_prior(
            vec!["F-AppColdStore-Layout".to_string()],
            Vec::new(),
            Vec::new(),
            vec!["weight_page:controller".to_string()],
            0.7,
        )
        .expect("valid Eidos prior should build");

        let err = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            vec!["F-AppColdStore-Layout".to_string()],
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            Some(prior),
            99,
        )
        .unwrap_err();

        assert_eq!(
            err,
            AppColdStoreRouteCardError::MissingParamRouteCardAdmissionVerifier
        );
    }

    #[test]
    fn eidos_route_prior_rejects_unbounded_confidence_and_empty_support() {
        let err = eidos_prior(Vec::new(), Vec::new(), Vec::new(), Vec::new(), 1.01).unwrap_err();
        assert!(matches!(
            err,
            crate::eidos::EidosRoutePriorError::InvalidConfidence(v) if v == 1.01
        ));

        let plan = fit_plan();
        let prior = eidos_prior(Vec::new(), Vec::new(), Vec::new(), Vec::new(), 0.5)
            .expect("Eidos prior may exist before AppColdStore support validation");
        let err = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            verifier_stack(),
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            Some(prior),
            99,
        )
        .unwrap_err();
        assert_eq!(err, AppColdStoreRouteCardError::MissingRoutePriorSupport);
    }

    #[test]
    fn eidos_route_prior_must_carry_closed_evidence_for_app_cold_store_card() {
        let plan = fit_plan();
        let packet = eidos_packet();
        let prior = EidosRoutePrior::from_packet(
            &packet,
            "deep_research:neural_importance_atlas",
            Vec::new(),
            EidosCitationNeed::Optional,
            vec!["local_reasoning".to_string()],
            Vec::new(),
            vec!["F-AppColdStore-Layout".to_string()],
            vec!["adapter:research_synthesis".to_string()],
            Vec::new(),
            vec!["weight_page:controller".to_string()],
            0.64,
            vec!["Eidos matched task meaning without closed evidence".to_string()],
        )
        .expect("Eidos can form optional-citation priors before route-card admission");

        let err = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            verifier_stack(),
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            Some(prior),
            99,
        )
        .unwrap_err();

        assert_eq!(err, AppColdStoreRouteCardError::MissingRoutePriorEvidence);
    }
}
