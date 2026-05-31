//! AppColdStore route-card metadata for non-executing ColdStore plans.
//!
//! This maps a passed `ResidencyPlan` into durable atlas, regenerable warm
//! cache, and hot runway manifest rows. It does not mmap bytes, warm caches,
//! allocate model buffers, or run inference.

use serde::{Deserialize, Serialize};

use crate::uas::{
    construction_card::{pro_status_preimage, product_build_preimage},
    ByteRange, ProStatus, ProductBuild, ResidencyPlan, ResidencyPlanStatus, ResidencyTier,
    UasAddress, UasKind, WeightBlockManifest, WeightBlockResidencyClass,
};

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
        UasAddress::new(
            UasKind::Other("app_cold_store_route_card".to_string()),
            preimage.as_bytes(),
            created_at_ms,
        )
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
    ProductBuildStatusMismatch,
    ProductBuildResidencyMismatch,
    WarmCacheRequiresDurableAtlas,
    MissingDurableAtlas,
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
        }
    }
}

impl std::error::Error for AppColdStoreRouteCardError {}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::{
        ProStatus, ProductBuild, ResidencyBudget, ResidencyPlan, ResidencyPlanStatus,
        ResidencyTier, UasAddress, UasKind, WeightBlockEncoding, WeightBlockIrChart,
        WeightBlockManifest, WeightBlockResidencyClass, GIB,
    };

    fn rollback_reference() -> UasAddress {
        UasAddress::new(UasKind::ModelComponent, b"dense-reference", 7)
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

    #[test]
    fn app_cold_store_route_card_maps_plan_tiers_without_loading_model_bytes() {
        let plan = fit_plan();

        let card = AppColdStoreRouteCard::from_residency_plan(
            "deep_research:neural_importance_atlas",
            vec!["F-AppColdStore-Layout".to_string()],
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
            vec!["F-AppColdStore-Layout".to_string()],
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
    fn app_cold_store_route_card_keeps_research_status_out_of_mas() {
        let plan = fit_plan();

        let err = AppColdStoreRouteCard::from_residency_plan(
            "deep_research:neural_importance_atlas",
            vec!["F-AppColdStore-Layout".to_string()],
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
            vec!["F-AppColdStore-Layout".to_string()],
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
}
