//! AppColdStore route-card metadata for non-executing ColdStore plans.
//!
//! This maps a passed `ResidencyPlan` into durable atlas, regenerable warm
//! cache, and hot runway manifest rows. It does not mmap bytes, warm caches,
//! allocate model buffers, or run inference.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;

use crate::eidos::EidosRoutePrior;
use crate::uas::{
    construction_card::{pro_status_preimage, product_build_preimage},
    ByteRange, ProStatus, ProductBuild, ResidencyPlan, ResidencyPlanStatus, ResidencyTier,
    UasAddress, UasKind, WeightBlockManifest, WeightBlockResidencyClass,
};

const APP_COLD_STORE_LAYOUT_FALSIFIER_ID: &str = "F-AppColdStore-Layout";
const PARAM_ROUTE_CARD_ADMISSION_FALSIFIER_ID: &str = "F-ParamRouteCard-Admission";
const EIDOS_NEURAL_ROUTE_PRIOR_FALSIFIER_ID: &str = "F-Eidos-NeuralRoute-Prior";
const REBUILD_WARM_CACHE_FROM_DURABLE_ATLAS: &str = "rebuild_warm_cache_from_durable_atlas";

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
    pub dry_run_copy_count: u64,
    pub runtime_model_peak_uma_bytes: u64,
    pub dry_run_ssd_read_bytes: u64,
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
        validate_residency_plan_snapshot(plan)?;

        let task_signature = task_signature.into();
        let rollback_reference = rollback_reference.into();
        let cache_rebuild_policy = cache_rebuild_policy.into();
        validate_nonempty("task_signature", &task_signature)?;
        validate_nonempty("rollback_reference", &rollback_reference)?;
        validate_nonempty("cache_rebuild_policy", &cache_rebuild_policy)?;
        validate_cache_rebuild_policy(&cache_rebuild_policy)?;
        if verifier_stack.is_empty() {
            return Err(AppColdStoreRouteCardError::MissingVerifier);
        }
        let mut seen_verifiers = HashSet::new();
        for verifier in &verifier_stack {
            validate_nonempty("verifier_stack", verifier)?;
            if !seen_verifiers.insert(verifier.as_str()) {
                return Err(AppColdStoreRouteCardError::DuplicateVerifier {
                    verifier: verifier.clone(),
                });
            }
        }
        let mut verifier_stack = verifier_stack;
        verifier_stack.sort();
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
            if !verifier_stack
                .iter()
                .any(|verifier| verifier == EIDOS_NEURAL_ROUTE_PRIOR_FALSIFIER_ID)
            {
                return Err(AppColdStoreRouteCardError::MissingEidosNeuralRoutePriorVerifier);
            }
            validate_eidos_route_prior(&task_signature, &verifier_stack, prior)?;
        }

        let residency_status = plan.effective_residency_tier;
        validate_build_status(&product_build, &pro_status, residency_status)?;

        let mut durable_units = Vec::new();
        let mut warm_cache_units = Vec::new();
        let mut hot_runway_units = Vec::new();
        for block in &plan.blocks {
            validate_app_cold_store_source_uri(&block.source_uri)?;
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
        if plan.totals.active_runtime_bytes == 0 {
            return Err(AppColdStoreRouteCardError::MissingActiveRuntimeBytes);
        }
        if hot_runway_units.is_empty() {
            return Err(AppColdStoreRouteCardError::MissingHotRunway);
        }
        if let Some(prior) = &eidos_route_prior {
            validate_eidos_route_prior_support_binding(
                prior,
                &durable_units,
                &warm_cache_units,
                &hot_runway_units,
            )?;
        }

        let totals = AppColdStoreRouteCardTotals {
            durable_atlas_bytes: plan.totals.cold_mmap_ssd_bytes,
            warm_cache_bytes: plan.totals.warm_compressed_uma_bytes,
            hot_runway_bytes: plan.totals.hot_uma_bytes,
            total_addressed_bytes: plan.totals.total_addressed_bytes,
            active_runtime_bytes: plan.totals.active_runtime_bytes,
            runtime_model_bytes_loaded: 0,
            dry_run_copy_count: 0,
            runtime_model_peak_uma_bytes: 0,
            dry_run_ssd_read_bytes: 0,
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
            "{}:{}:{}:{}:{}:{}:{}:{}:{}\n",
            totals.durable_atlas_bytes,
            totals.warm_cache_bytes,
            totals.hot_runway_bytes,
            totals.total_addressed_bytes,
            totals.active_runtime_bytes,
            totals.runtime_model_bytes_loaded,
            totals.dry_run_copy_count,
            totals.runtime_model_peak_uma_bytes,
            totals.dry_run_ssd_read_bytes
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
    preimage.push(':');
    preimage.push_str(&values.len().to_string());
    preimage.push('\n');
    for value in values {
        preimage.push_str(&value.len().to_string());
        preimage.push(':');
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

fn validate_residency_plan_snapshot(
    plan: &ResidencyPlan,
) -> Result<(), AppColdStoreRouteCardError> {
    let recomputed = ResidencyPlan::evaluate(
        plan.blocks.clone(),
        plan.budget.clone(),
        plan.plan_address.created_at_ms,
    );
    if recomputed != *plan {
        return Err(AppColdStoreRouteCardError::PlanShapeDrift);
    }
    Ok(())
}

fn validate_eidos_route_prior(
    task_signature: &str,
    verifier_stack: &[String],
    prior: &EidosRoutePrior,
) -> Result<(), AppColdStoreRouteCardError> {
    prior
        .validate_shape()
        .map_err(|error| AppColdStoreRouteCardError::InvalidRoutePriorShape {
            reason: error.to_string(),
        })?;
    if prior.confidence <= 0.0 {
        return Err(AppColdStoreRouteCardError::RoutePriorConfidenceTooLow);
    }
    if prior.task_signature != task_signature {
        return Err(AppColdStoreRouteCardError::RoutePriorTaskMismatch);
    }
    if prior.evidence_ids.is_empty() {
        return Err(AppColdStoreRouteCardError::MissingRoutePriorEvidence);
    }
    if prior.likely_verifiers.is_empty() {
        return Err(AppColdStoreRouteCardError::MissingRoutePriorVerifier);
    }
    if prior.likely_weight_page_families.is_empty() {
        return Err(AppColdStoreRouteCardError::MissingRoutePriorSupport);
    }
    for verifier in &prior.likely_verifiers {
        if !verifier_stack.iter().any(|bound| bound == verifier) {
            return Err(AppColdStoreRouteCardError::UnboundRoutePriorVerifier {
                verifier: verifier.clone(),
            });
        }
    }
    Ok(())
}

fn validate_eidos_route_prior_support_binding(
    prior: &EidosRoutePrior,
    durable_units: &[AppColdStoreUnit],
    warm_cache_units: &[AppColdStoreUnit],
    hot_runway_units: &[AppColdStoreUnit],
) -> Result<(), AppColdStoreRouteCardError> {
    for support in &prior.likely_weight_page_families {
        let matches = durable_units
            .iter()
            .chain(warm_cache_units.iter())
            .chain(hot_runway_units.iter())
            .filter(|unit| route_prior_support_matches_unit(support, unit))
            .count();
        match matches {
            0 => {
                return Err(AppColdStoreRouteCardError::UnboundRoutePriorSupport {
                    support: support.clone(),
                });
            }
            1 => {}
            matches => {
                return Err(AppColdStoreRouteCardError::AmbiguousRoutePriorSupport {
                    support: support.clone(),
                    matches,
                });
            }
        }
    }
    Ok(())
}

fn route_prior_support_matches_unit(support: &str, unit: &AppColdStoreUnit) -> bool {
    let Some(support) = support.strip_prefix("weight_page:") else {
        return false;
    };
    let unit_address = unit.uas_address.to_string();
    if let Some(address) = support.strip_prefix("uas:") {
        return address == unit_address;
    }
    if let Some(source_uri) = support.strip_prefix("source:") {
        return source_uri == unit.source_uri.as_str();
    }
    if let Some(content_hash_hex) = support.strip_prefix("hash:") {
        return content_hash_hex == unit.content_hash_hex.as_str();
    }

    false
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

fn validate_cache_rebuild_policy(policy: &str) -> Result<(), AppColdStoreRouteCardError> {
    if policy != REBUILD_WARM_CACHE_FROM_DURABLE_ATLAS {
        return Err(AppColdStoreRouteCardError::UnsupportedCacheRebuildPolicy {
            policy: policy.to_string(),
        });
    }
    Ok(())
}

fn validate_app_cold_store_source_uri(source_uri: &str) -> Result<(), AppColdStoreRouteCardError> {
    if has_source_uri_payload(source_uri, "file:///")
        || has_source_uri_payload(source_uri, "app-support://")
        || has_source_uri_payload(source_uri, "app-group://")
    {
        return Ok(());
    }
    Err(AppColdStoreRouteCardError::UnsupportedSourceUri {
        source_uri: source_uri.to_string(),
    })
}

fn has_source_uri_payload(source_uri: &str, prefix: &str) -> bool {
    source_uri
        .strip_prefix(prefix)
        .is_some_and(local_source_uri_payload_is_safe)
}

fn local_source_uri_payload_is_safe(payload: &str) -> bool {
    if payload.is_empty() {
        return false;
    }
    if contains_percent_encoded_path_separator(payload) {
        return false;
    }
    let Some(decoded_payload) = percent_decode_uri_payload(payload) else {
        return false;
    };
    if decoded_payload.contains('%') {
        return false;
    }
    if decoded_payload.chars().any(char::is_control) {
        return false;
    }
    if decoded_payload.contains('\\') {
        return false;
    }
    if decoded_payload.chars().any(|ch| ch == '?' || ch == '#') {
        return false;
    }
    if decoded_payload.starts_with('/') || decoded_payload.starts_with('\\') {
        return false;
    }
    if decoded_payload.is_empty()
        || decoded_payload.ends_with('/')
        || decoded_payload.ends_with('\\')
    {
        return false;
    }
    !decoded_payload
        .split(|ch| ch == '/' || ch == '\\')
        .any(|segment| segment.is_empty() || segment == "." || segment == "..")
}

fn contains_percent_encoded_path_separator(value: &str) -> bool {
    let bytes = value.as_bytes();
    let mut index = 0;

    while index + 2 < bytes.len() {
        if bytes[index] == b'%' {
            let high = bytes[index + 1].to_ascii_lowercase();
            let low = bytes[index + 2].to_ascii_lowercase();
            if (high == b'2' && low == b'f') || (high == b'5' && low == b'c') {
                return true;
            }
        }
        index += 1;
    }

    false
}

fn percent_decode_uri_payload(value: &str) -> Option<String> {
    let bytes = value.as_bytes();
    let mut decoded = Vec::with_capacity(bytes.len());
    let mut index = 0;

    while index < bytes.len() {
        if bytes[index] == b'%' {
            let high = bytes.get(index + 1).copied().and_then(hex_nibble)?;
            let low = bytes.get(index + 2).copied().and_then(hex_nibble)?;
            decoded.push((high << 4) | low);
            index += 3;
        } else {
            decoded.push(bytes[index]);
            index += 1;
        }
    }

    String::from_utf8(decoded).ok()
}

fn hex_nibble(byte: u8) -> Option<u8> {
    match byte {
        b'0'..=b'9' => Some(byte - b'0'),
        b'a'..=b'f' => Some(byte - b'a' + 10),
        b'A'..=b'F' => Some(byte - b'A' + 10),
        _ => None,
    }
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
    UnsupportedCacheRebuildPolicy { policy: String },
    PlanRejected,
    PlanShapeDrift,
    MissingAppColdStoreLayoutVerifier,
    MissingParamRouteCardAdmissionVerifier,
    MissingEidosNeuralRoutePriorVerifier,
    MissingActiveRuntimeBytes,
    MissingHotRunway,
    ProductBuildStatusMismatch,
    ProductBuildResidencyMismatch,
    WarmCacheRequiresDurableAtlas,
    MissingDurableAtlas,
    DuplicateVerifier { verifier: String },
    RoutePriorTaskMismatch,
    InvalidRoutePriorShape { reason: String },
    RoutePriorConfidenceTooLow,
    MissingRoutePriorEvidence,
    MissingRoutePriorVerifier,
    MissingRoutePriorSupport,
    UnboundRoutePriorVerifier { verifier: String },
    UnboundRoutePriorSupport { support: String },
    AmbiguousRoutePriorSupport { support: String, matches: usize },
    UnsupportedSourceUri { source_uri: String },
}

impl std::fmt::Display for AppColdStoreRouteCardError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::MissingTaskSignature => write!(f, "task_signature is required"),
            Self::MissingVerifier => write!(f, "at least one verifier is required"),
            Self::MissingRollback => write!(f, "rollback_reference is required"),
            Self::MissingCacheRebuildPolicy => write!(f, "cache_rebuild_policy is required"),
            Self::UnsupportedCacheRebuildPolicy { policy } => write!(
                f,
                "AppColdStore route-card cache rebuild policy is unsupported: {policy}"
            ),
            Self::FieldHasSurroundingWhitespace { field } => {
                write!(f, "{field} must not contain leading or trailing whitespace")
            }
            Self::FieldContainsControlCharacter { field } => {
                write!(f, "{field} must not contain control characters")
            }
            Self::PlanRejected => write!(f, "residency plan must be FitForDryRun"),
            Self::PlanShapeDrift => write!(
                f,
                "residency plan fields no longer match the verified dry-run snapshot"
            ),
            Self::MissingAppColdStoreLayoutVerifier => write!(
                f,
                "AppColdStore route cards must bind F-AppColdStore-Layout in verifier_stack"
            ),
            Self::MissingParamRouteCardAdmissionVerifier => write!(
                f,
                "AppColdStore route cards must bind F-ParamRouteCard-Admission in verifier_stack"
            ),
            Self::MissingEidosNeuralRoutePriorVerifier => write!(
                f,
                "AppColdStore route cards with Eidos priors must bind F-Eidos-NeuralRoute-Prior in verifier_stack"
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
            Self::MissingActiveRuntimeBytes => write!(
                f,
                "AppColdStore route cards require a non-zero active runtime byte plan"
            ),
            Self::MissingHotRunway => write!(
                f,
                "AppColdStore route cards require at least one hot runway unit"
            ),
            Self::DuplicateVerifier { verifier } => {
                write!(f, "AppColdStore route-card verifier was duplicated: {verifier}")
            }
            Self::RoutePriorTaskMismatch => write!(
                f,
                "EidosRoutePrior task_signature must match the AppColdStore route card task_signature"
            ),
            Self::InvalidRoutePriorShape { reason } => write!(
                f,
                "EidosRoutePrior failed route-card shape validation: {reason}"
            ),
            Self::RoutePriorConfidenceTooLow => write!(
                f,
                "EidosRoutePrior confidence must be positive for AppColdStore route-card admission"
            ),
            Self::MissingRoutePriorEvidence => write!(
                f,
                "EidosRoutePrior must carry at least one closed evidence id for AppColdStore route-card admission"
            ),
            Self::MissingRoutePriorVerifier => write!(
                f,
                "EidosRoutePrior must carry at least one likely verifier for AppColdStore route-card admission"
            ),
            Self::MissingRoutePriorSupport => write!(
                f,
                "EidosRoutePrior must carry at least one weight-page support hint for AppColdStore route-card admission"
            ),
            Self::UnboundRoutePriorVerifier { verifier } => write!(
                f,
                "EidosRoutePrior likely verifier is not bound in the AppColdStore route-card verifier stack: {verifier}"
            ),
            Self::UnboundRoutePriorSupport { support } => write!(
                f,
                "EidosRoutePrior weight-page support hint is not bound to an AppColdStore route-card unit: {support}"
            ),
            Self::AmbiguousRoutePriorSupport { support, matches } => write!(
                f,
                "EidosRoutePrior weight-page support hint must bind exactly one AppColdStore route-card unit, got {matches} matches for {support}"
            ),
            Self::UnsupportedSourceUri { source_uri } => write!(
                f,
                "AppColdStore route-card units require local app-owned or file-backed source URIs, got {source_uri}"
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

    fn route_prior_verifier_stack() -> Vec<String> {
        let mut stack = verifier_stack();
        stack.push("F-Eidos-NeuralRoute-Prior".to_string());
        stack
    }

    fn cold_weight_page_source_hint() -> String {
        "weight_page:source:file:///models/cold-atlas/cold-weight-page.safetensors".to_string()
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
        eidos_prior_with_why(
            likely_verifiers,
            likely_adapter_families,
            likely_kv_regions,
            likely_weight_page_families,
            confidence,
            vec!["Eidos matched cited vault evidence and route priors".to_string()],
        )
    }

    fn eidos_prior_with_why(
        likely_verifiers: Vec<String>,
        likely_adapter_families: Vec<String>,
        likely_kv_regions: Vec<String>,
        likely_weight_page_families: Vec<String>,
        confidence: f32,
        why_matched: Vec<String>,
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
            why_matched,
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
        assert_eq!(card.totals.dry_run_copy_count, 0);
        assert_eq!(card.totals.runtime_model_peak_uma_bytes, 0);
        assert_eq!(card.totals.dry_run_ssd_read_bytes, 0);
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
    fn app_cold_store_route_card_rejects_mutated_residency_plan_snapshot() {
        let mut plan = fit_plan();
        plan.blocks[0].content_hash_hex = blake3::hash(b"tampered-after-plan").to_hex().to_string();
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

        assert_eq!(err, AppColdStoreRouteCardError::PlanShapeDrift);
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
    fn app_cold_store_route_card_address_is_stable_for_verifier_stack_order() {
        let plan = fit_plan();
        let first_stack = vec![
            "F-AppColdStore-Layout".to_string(),
            "F-ParamRouteCard-Admission".to_string(),
            "F-Eidos-NeuralRoute-Prior".to_string(),
        ];
        let second_stack = vec![
            "F-Eidos-NeuralRoute-Prior".to_string(),
            "F-ParamRouteCard-Admission".to_string(),
            "F-AppColdStore-Layout".to_string(),
        ];

        let first = AppColdStoreRouteCard::from_residency_plan(
            "deep_research:neural_importance_atlas",
            first_stack,
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            99,
        )
        .expect("first verifier stack order should build");
        let second = AppColdStoreRouteCard::from_residency_plan(
            "deep_research:neural_importance_atlas",
            second_stack,
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            99,
        )
        .expect("second verifier stack order should build");

        assert_eq!(first.card_address, second.card_address);
        assert_eq!(first.verifier_stack, second.verifier_stack);
    }

    #[test]
    fn app_cold_store_route_card_rejects_duplicate_verifiers() {
        let plan = fit_plan();
        let mut duplicate_stack = verifier_stack();
        duplicate_stack.push("F-AppColdStore-Layout".to_string());

        let err = AppColdStoreRouteCard::from_residency_plan(
            "deep_research:neural_importance_atlas",
            duplicate_stack,
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
            AppColdStoreRouteCardError::DuplicateVerifier {
                verifier: "F-AppColdStore-Layout".to_string()
            }
        );
    }

    #[test]
    fn app_cold_store_route_card_rejects_unknown_cache_rebuild_policy() {
        let plan = fit_plan();
        let policy = "trust_existing_warm_cache_without_durable_rebuild";

        let err = AppColdStoreRouteCard::from_residency_plan(
            "deep_research:neural_importance_atlas",
            verifier_stack(),
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            policy,
            99,
        )
        .unwrap_err();

        assert_eq!(
            err,
            AppColdStoreRouteCardError::UnsupportedCacheRebuildPolicy {
                policy: policy.to_string()
            }
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
    fn app_cold_store_route_card_rejects_network_backed_durable_sources() {
        let hot = block(
            "hot-controller",
            0,
            512,
            WeightBlockEncoding::DenseBf16,
            WeightBlockResidencyClass::HotUma,
            None,
        );
        let cold = WeightBlockManifest::from_known_hash_hex(
            "local/cold-atlas-fixture",
            "https://example.invalid/model.safetensors",
            2048,
            4096,
            blake3::hash(b"network-backed-cold-page").to_hex().as_str(),
            1_779_000_000_000,
            WeightBlockEncoding::Nf4,
            WeightBlockResidencyClass::ColdMmapSsd,
            WeightBlockIrChart::OpaqueWithWitness,
            0.02,
            "F-AppColdStore-Layout",
            Some(rollback_reference()),
        )
        .expect("generic weight manifests may describe external source URIs");
        let budget = ResidencyBudget::new(GIB, 0, 8 * GIB, 0.25, 16).unwrap();
        let plan = ResidencyPlan::evaluate([hot, cold], budget, 42);
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
            AppColdStoreRouteCardError::UnsupportedSourceUri {
                source_uri: "https://example.invalid/model.safetensors".to_string()
            }
        );
    }

    #[test]
    fn app_cold_store_route_card_rejects_host_or_relative_file_source_uris() {
        for source_uri in [
            "file://remote-host/models/cold-atlas/model.safetensors",
            "file://model.safetensors",
        ] {
            let hot = block(
                "hot-controller",
                0,
                512,
                WeightBlockEncoding::DenseBf16,
                WeightBlockResidencyClass::HotUma,
                None,
            );
            let cold = WeightBlockManifest::from_known_hash_hex(
                "local/cold-atlas-fixture",
                source_uri,
                2048,
                4096,
                blake3::hash(source_uri.as_bytes()).to_hex().as_str(),
                1_779_000_000_000,
                WeightBlockEncoding::Nf4,
                WeightBlockResidencyClass::ColdMmapSsd,
                WeightBlockIrChart::OpaqueWithWitness,
                0.02,
                "F-AppColdStore-Layout",
                Some(rollback_reference()),
            )
            .expect("generic weight manifests may describe source URI candidates");
            let budget = ResidencyBudget::new(GIB, 0, 8 * GIB, 0.25, 16).unwrap();
            let plan = ResidencyPlan::evaluate([hot, cold], budget, 42);
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
                AppColdStoreRouteCardError::UnsupportedSourceUri {
                    source_uri: source_uri.to_string()
                }
            );
        }
    }

    #[test]
    fn app_cold_store_route_card_rejects_empty_app_owned_source_uri() {
        let hot = block(
            "hot-controller",
            0,
            512,
            WeightBlockEncoding::DenseBf16,
            WeightBlockResidencyClass::HotUma,
            None,
        );
        let cold = WeightBlockManifest::from_known_hash_hex(
            "local/cold-atlas-fixture",
            "app-support://",
            2048,
            4096,
            blake3::hash(b"empty-app-owned-source-uri")
                .to_hex()
                .as_str(),
            1_779_000_000_000,
            WeightBlockEncoding::Nf4,
            WeightBlockResidencyClass::ColdMmapSsd,
            WeightBlockIrChart::OpaqueWithWitness,
            0.02,
            "F-AppColdStore-Layout",
            Some(rollback_reference()),
        )
        .expect("generic weight manifests may describe scheme-shaped source URIs");
        let budget = ResidencyBudget::new(GIB, 0, 8 * GIB, 0.25, 16).unwrap();
        let plan = ResidencyPlan::evaluate([hot, cold], budget, 42);
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
            AppColdStoreRouteCardError::UnsupportedSourceUri {
                source_uri: "app-support://".to_string()
            }
        );
    }

    #[test]
    fn app_cold_store_route_card_rejects_parent_directory_source_uri_segments() {
        for source_uri in [
            "file:///models/cold-atlas/../outside/model.safetensors",
            "app-support://Models/coldstore/../outside/model.safetensors",
            "app-group://Shared/coldstore/%2e%2e/outside/model.safetensors",
        ] {
            let hot = block(
                "hot-controller",
                0,
                512,
                WeightBlockEncoding::DenseBf16,
                WeightBlockResidencyClass::HotUma,
                None,
            );
            let cold = WeightBlockManifest::from_known_hash_hex(
                "local/cold-atlas-fixture",
                source_uri,
                2048,
                4096,
                blake3::hash(source_uri.as_bytes()).to_hex().as_str(),
                1_779_000_000_000,
                WeightBlockEncoding::Nf4,
                WeightBlockResidencyClass::ColdMmapSsd,
                WeightBlockIrChart::OpaqueWithWitness,
                0.02,
                "F-AppColdStore-Layout",
                Some(rollback_reference()),
            )
            .expect("generic weight manifests may describe source URI candidates");
            let budget = ResidencyBudget::new(GIB, 0, 8 * GIB, 0.25, 16).unwrap();
            let plan = ResidencyPlan::evaluate([hot, cold], budget, 42);
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
                AppColdStoreRouteCardError::UnsupportedSourceUri {
                    source_uri: source_uri.to_string()
                }
            );
        }
    }

    #[test]
    fn app_cold_store_route_card_rejects_percent_encoded_path_separators() {
        for source_uri in [
            "file:///models/cold-atlas/%2foutside/model.safetensors",
            "app-support://Models/coldstore/%5coutside/model.safetensors",
            "app-group://Shared/coldstore/inside%2f%2fnested/model.safetensors",
        ] {
            let hot = block(
                "hot-controller",
                0,
                512,
                WeightBlockEncoding::DenseBf16,
                WeightBlockResidencyClass::HotUma,
                None,
            );
            let cold = WeightBlockManifest::from_known_hash_hex(
                "local/cold-atlas-fixture",
                source_uri,
                2048,
                4096,
                blake3::hash(source_uri.as_bytes()).to_hex().as_str(),
                1_779_000_000_000,
                WeightBlockEncoding::Nf4,
                WeightBlockResidencyClass::ColdMmapSsd,
                WeightBlockIrChart::OpaqueWithWitness,
                0.02,
                "F-AppColdStore-Layout",
                Some(rollback_reference()),
            )
            .expect("generic weight manifests may describe source URI candidates");
            let budget = ResidencyBudget::new(GIB, 0, 8 * GIB, 0.25, 16).unwrap();
            let plan = ResidencyPlan::evaluate([hot, cold], budget, 42);
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
                AppColdStoreRouteCardError::UnsupportedSourceUri {
                    source_uri: source_uri.to_string()
                }
            );
        }
    }

    #[test]
    fn app_cold_store_route_card_rejects_percent_encoded_internal_source_uri_separators() {
        for source_uri in [
            "file:///models%2fcold-atlas/model.safetensors",
            "app-support://Models%2fcoldstore/model.safetensors",
            "app-group://Shared%5ccoldstore/model.safetensors",
        ] {
            let hot = block(
                "hot-controller",
                0,
                512,
                WeightBlockEncoding::DenseBf16,
                WeightBlockResidencyClass::HotUma,
                None,
            );
            let cold = WeightBlockManifest::from_known_hash_hex(
                "local/cold-atlas-fixture",
                source_uri,
                2048,
                4096,
                blake3::hash(source_uri.as_bytes()).to_hex().as_str(),
                1_779_000_000_000,
                WeightBlockEncoding::Nf4,
                WeightBlockResidencyClass::ColdMmapSsd,
                WeightBlockIrChart::OpaqueWithWitness,
                0.02,
                "F-AppColdStore-Layout",
                Some(rollback_reference()),
            )
            .expect("generic weight manifests may describe source URI candidates");
            let budget = ResidencyBudget::new(GIB, 0, 8 * GIB, 0.25, 16).unwrap();
            let plan = ResidencyPlan::evaluate([hot, cold], budget, 42);
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
                AppColdStoreRouteCardError::UnsupportedSourceUri {
                    source_uri: source_uri.to_string()
                }
            );
        }
    }

    #[test]
    fn app_cold_store_route_card_rejects_double_encoded_source_uri_separators() {
        for source_uri in [
            "file:///models%252fcold-atlas/model.safetensors",
            "app-support://Models%255ccoldstore/model.safetensors",
            "app-group://Shared/coldstore/%252e%252e/outside/model.safetensors",
        ] {
            let hot = block(
                "hot-controller",
                0,
                512,
                WeightBlockEncoding::DenseBf16,
                WeightBlockResidencyClass::HotUma,
                None,
            );
            let cold = WeightBlockManifest::from_known_hash_hex(
                "local/cold-atlas-fixture",
                source_uri,
                2048,
                4096,
                blake3::hash(source_uri.as_bytes()).to_hex().as_str(),
                1_779_000_000_000,
                WeightBlockEncoding::Nf4,
                WeightBlockResidencyClass::ColdMmapSsd,
                WeightBlockIrChart::OpaqueWithWitness,
                0.02,
                "F-AppColdStore-Layout",
                Some(rollback_reference()),
            )
            .expect("generic weight manifests may describe source URI candidates");
            let budget = ResidencyBudget::new(GIB, 0, 8 * GIB, 0.25, 16).unwrap();
            let plan = ResidencyPlan::evaluate([hot, cold], budget, 42);
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
                AppColdStoreRouteCardError::UnsupportedSourceUri {
                    source_uri: source_uri.to_string()
                }
            );
        }
    }

    #[test]
    fn app_cold_store_route_card_rejects_literal_backslash_source_uri_separators() {
        for source_uri in [
            "file:///models\\cold-atlas/model.safetensors",
            "app-support://Models\\coldstore/model.safetensors",
            "app-group://Shared\\coldstore/model.safetensors",
        ] {
            let hot = block(
                "hot-controller",
                0,
                512,
                WeightBlockEncoding::DenseBf16,
                WeightBlockResidencyClass::HotUma,
                None,
            );
            let cold = WeightBlockManifest::from_known_hash_hex(
                "local/cold-atlas-fixture",
                source_uri,
                2048,
                4096,
                blake3::hash(source_uri.as_bytes()).to_hex().as_str(),
                1_779_000_000_000,
                WeightBlockEncoding::Nf4,
                WeightBlockResidencyClass::ColdMmapSsd,
                WeightBlockIrChart::OpaqueWithWitness,
                0.02,
                "F-AppColdStore-Layout",
                Some(rollback_reference()),
            )
            .expect("generic weight manifests may describe source URI candidates");
            let budget = ResidencyBudget::new(GIB, 0, 8 * GIB, 0.25, 16).unwrap();
            let plan = ResidencyPlan::evaluate([hot, cold], budget, 42);
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
                AppColdStoreRouteCardError::UnsupportedSourceUri {
                    source_uri: source_uri.to_string()
                }
            );
        }
    }

    #[test]
    fn app_cold_store_route_card_rejects_percent_encoded_leading_source_uri_separators() {
        for source_uri in [
            "file:///%2fmodels/cold-atlas/model.safetensors",
            "app-support://%2fModels/coldstore/model.safetensors",
            "app-group://%5cShared/coldstore/model.safetensors",
        ] {
            let hot = block(
                "hot-controller",
                0,
                512,
                WeightBlockEncoding::DenseBf16,
                WeightBlockResidencyClass::HotUma,
                None,
            );
            let cold = WeightBlockManifest::from_known_hash_hex(
                "local/cold-atlas-fixture",
                source_uri,
                2048,
                4096,
                blake3::hash(source_uri.as_bytes()).to_hex().as_str(),
                1_779_000_000_000,
                WeightBlockEncoding::Nf4,
                WeightBlockResidencyClass::ColdMmapSsd,
                WeightBlockIrChart::OpaqueWithWitness,
                0.02,
                "F-AppColdStore-Layout",
                Some(rollback_reference()),
            )
            .expect("generic weight manifests may describe source URI candidates");
            let budget = ResidencyBudget::new(GIB, 0, 8 * GIB, 0.25, 16).unwrap();
            let plan = ResidencyPlan::evaluate([hot, cold], budget, 42);
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
                AppColdStoreRouteCardError::UnsupportedSourceUri {
                    source_uri: source_uri.to_string()
                }
            );
        }
    }

    #[test]
    fn app_cold_store_route_card_rejects_percent_encoded_control_source_uri() {
        for source_uri in [
            "file:///models/cold-atlas/%00/model.safetensors",
            "app-support://Models/coldstore/%1f/model.safetensors",
            "app-group://Shared/coldstore/%7f/model.safetensors",
        ] {
            let hot = block(
                "hot-controller",
                0,
                512,
                WeightBlockEncoding::DenseBf16,
                WeightBlockResidencyClass::HotUma,
                None,
            );
            let cold = WeightBlockManifest::from_known_hash_hex(
                "local/cold-atlas-fixture",
                source_uri,
                2048,
                4096,
                blake3::hash(source_uri.as_bytes()).to_hex().as_str(),
                1_779_000_000_000,
                WeightBlockEncoding::Nf4,
                WeightBlockResidencyClass::ColdMmapSsd,
                WeightBlockIrChart::OpaqueWithWitness,
                0.02,
                "F-AppColdStore-Layout",
                Some(rollback_reference()),
            )
            .expect("generic weight manifests may describe source URI candidates");
            let budget = ResidencyBudget::new(GIB, 0, 8 * GIB, 0.25, 16).unwrap();
            let plan = ResidencyPlan::evaluate([hot, cold], budget, 42);
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
                AppColdStoreRouteCardError::UnsupportedSourceUri {
                    source_uri: source_uri.to_string()
                }
            );
        }
    }

    #[test]
    fn app_cold_store_route_card_rejects_source_uri_queries_and_fragments() {
        for source_uri in [
            "file:///models/cold-atlas/model.safetensors?profile=debug",
            "app-support://Models/coldstore/model.safetensors#mutable-ref",
            "app-group://Shared/coldstore/model%3Fname.safetensors",
        ] {
            let hot = block(
                "hot-controller",
                0,
                512,
                WeightBlockEncoding::DenseBf16,
                WeightBlockResidencyClass::HotUma,
                None,
            );
            let cold = WeightBlockManifest::from_known_hash_hex(
                "local/cold-atlas-fixture",
                source_uri,
                2048,
                4096,
                blake3::hash(source_uri.as_bytes()).to_hex().as_str(),
                1_779_000_000_000,
                WeightBlockEncoding::Nf4,
                WeightBlockResidencyClass::ColdMmapSsd,
                WeightBlockIrChart::OpaqueWithWitness,
                0.02,
                "F-AppColdStore-Layout",
                Some(rollback_reference()),
            )
            .expect("generic weight manifests may describe source URI candidates");
            let budget = ResidencyBudget::new(GIB, 0, 8 * GIB, 0.25, 16).unwrap();
            let plan = ResidencyPlan::evaluate([hot, cold], budget, 42);
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
                AppColdStoreRouteCardError::UnsupportedSourceUri {
                    source_uri: source_uri.to_string()
                }
            );
        }
    }

    #[test]
    fn app_cold_store_route_card_rejects_trailing_source_uri_separators() {
        for source_uri in [
            "file:///models/cold-atlas/model.safetensors/",
            "app-support://Models/coldstore/model.safetensors/",
            "app-group://Shared/coldstore/model.safetensors\\",
        ] {
            let hot = block(
                "hot-controller",
                0,
                512,
                WeightBlockEncoding::DenseBf16,
                WeightBlockResidencyClass::HotUma,
                None,
            );
            let cold = WeightBlockManifest::from_known_hash_hex(
                "local/cold-atlas-fixture",
                source_uri,
                2048,
                4096,
                blake3::hash(source_uri.as_bytes()).to_hex().as_str(),
                1_779_000_000_000,
                WeightBlockEncoding::Nf4,
                WeightBlockResidencyClass::ColdMmapSsd,
                WeightBlockIrChart::OpaqueWithWitness,
                0.02,
                "F-AppColdStore-Layout",
                Some(rollback_reference()),
            )
            .expect("generic weight manifests may describe source URI candidates");
            let budget = ResidencyBudget::new(GIB, 0, 8 * GIB, 0.25, 16).unwrap();
            let plan = ResidencyPlan::evaluate([hot, cold], budget, 42);
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
                AppColdStoreRouteCardError::UnsupportedSourceUri {
                    source_uri: source_uri.to_string()
                }
            );
        }
    }

    #[test]
    fn app_cold_store_route_card_rejects_durable_only_plan_without_active_bytes() {
        let cold = block(
            "durable-only-weight-page",
            0,
            4096,
            WeightBlockEncoding::Nf4,
            WeightBlockResidencyClass::ColdMmapSsd,
            Some(rollback_reference()),
        );
        let budget = ResidencyBudget::new(0, 0, 8 * GIB, 0.25, 16).unwrap();
        let plan = ResidencyPlan::evaluate([cold], budget, 42);
        assert_eq!(plan.status, ResidencyPlanStatus::FitForDryRun);
        assert_eq!(plan.totals.active_runtime_bytes, 0);

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

        assert_eq!(err, AppColdStoreRouteCardError::MissingActiveRuntimeBytes);
    }

    #[test]
    fn app_cold_store_route_card_rejects_warm_active_plan_without_hot_runway() {
        let warm = block(
            "warm-active-no-hot-runway",
            0,
            256,
            WeightBlockEncoding::Sherry125,
            WeightBlockResidencyClass::WarmCompressedUma,
            Some(rollback_reference()),
        );
        let cold = block(
            "durable-without-hot-runway",
            1024,
            4096,
            WeightBlockEncoding::Nf4,
            WeightBlockResidencyClass::ColdMmapSsd,
            Some(rollback_reference()),
        );
        let budget = ResidencyBudget::new(0, GIB, 8 * GIB, 0.25, 16).unwrap();
        let plan = ResidencyPlan::evaluate([warm, cold], budget, 42);
        assert_eq!(plan.status, ResidencyPlanStatus::FitForDryRun);
        assert_eq!(plan.totals.hot_uma_bytes, 0);
        assert!(plan.totals.active_runtime_bytes > 0);

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

        assert_eq!(err, AppColdStoreRouteCardError::MissingHotRunway);
    }

    #[test]
    fn eidos_route_prior_binds_to_card_without_waking_model_bytes() {
        let plan = fit_plan();
        let prior = eidos_prior(
            vec!["F-AppColdStore-Layout".to_string()],
            vec!["adapter:research_synthesis".to_string()],
            vec!["kv:neural_importance_intro".to_string()],
            vec![cold_weight_page_source_hint()],
            0.82,
        )
        .expect("valid Eidos prior should build");

        let card = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            route_prior_verifier_stack(),
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
            vec![cold_weight_page_source_hint()],
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
    fn eidos_route_prior_likely_verifiers_must_be_bound_by_route_card() {
        let plan = fit_plan();
        let prior = eidos_prior(
            vec!["F-Eidos-PostValidation-Repair".to_string()],
            vec!["adapter:research_synthesis".to_string()],
            Vec::new(),
            vec![cold_weight_page_source_hint()],
            0.82,
        )
        .expect("valid Eidos prior should build");

        let err = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            route_prior_verifier_stack(),
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
            AppColdStoreRouteCardError::UnboundRoutePriorVerifier {
                verifier: "F-Eidos-PostValidation-Repair".to_string()
            }
        );
    }

    #[test]
    fn eidos_route_prior_requires_routeable_neural_support_hint() {
        let plan = fit_plan();
        let prior = eidos_prior(
            vec!["F-AppColdStore-Layout".to_string()],
            Vec::new(),
            Vec::new(),
            Vec::new(),
            0.82,
        )
        .expect("verifier-only Eidos prior is shape-valid before route-card admission");

        let err = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            route_prior_verifier_stack(),
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
    fn eidos_route_prior_for_app_cold_store_requires_weight_page_hint() {
        let plan = fit_plan();
        let prior = eidos_prior(
            vec!["F-AppColdStore-Layout".to_string()],
            vec!["adapter:research_synthesis".to_string()],
            vec!["kv:neural_importance_intro".to_string()],
            Vec::new(),
            0.82,
        )
        .expect("adapter/KV prior is shape-valid before AppColdStore admission");

        let err = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            route_prior_verifier_stack(),
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
    fn eidos_route_prior_weight_page_hint_must_bind_route_card_unit() {
        let plan = fit_plan();
        let prior = eidos_prior(
            vec!["F-AppColdStore-Layout".to_string()],
            vec!["adapter:research_synthesis".to_string()],
            Vec::new(),
            vec![
                "weight_page:source:file:///models/cold-atlas/not-in-plan.safetensors".to_string(),
            ],
            0.82,
        )
        .expect("source-shaped support hint is route-prior valid before card admission");

        let err = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            route_prior_verifier_stack(),
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
            AppColdStoreRouteCardError::UnboundRoutePriorSupport {
                support: "weight_page:source:file:///models/cold-atlas/not-in-plan.safetensors"
                    .to_string()
            }
        );
    }

    #[test]
    fn eidos_route_prior_weight_page_hint_must_bind_specific_route_card_unit() {
        let plan = fit_plan();

        for broad_hint in [
            "weight_page:model:local/cold-atlas-fixture",
            "weight_page:codec:nf4-ssd-oracle",
        ] {
            let prior = eidos_prior(
                vec!["F-AppColdStore-Layout".to_string()],
                vec!["adapter:research_synthesis".to_string()],
                Vec::new(),
                vec![broad_hint.to_string()],
                0.82,
            )
            .expect("broad support hints are route-prior valid before card admission");

            let err = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
                "deep_research:neural_importance_atlas",
                route_prior_verifier_stack(),
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
                AppColdStoreRouteCardError::UnboundRoutePriorSupport {
                    support: broad_hint.to_string()
                }
            );
        }
    }

    #[test]
    fn eidos_route_prior_source_hint_must_not_bind_multiple_route_card_units() {
        let shared_source_uri = "file:///models/cold-atlas/shared-source.safetensors";
        let hot = block(
            "hot-controller",
            0,
            512,
            WeightBlockEncoding::DenseBf16,
            WeightBlockResidencyClass::HotUma,
            None,
        );
        let first_cold = WeightBlockManifest::from_known_hash_hex(
            "local/cold-atlas-fixture",
            shared_source_uri,
            2048,
            1024,
            blake3::hash(b"first-shared-source-page").to_hex().as_str(),
            1_779_000_000_000,
            WeightBlockEncoding::Nf4,
            WeightBlockResidencyClass::ColdMmapSsd,
            WeightBlockIrChart::OpaqueWithWitness,
            0.02,
            "F-AppColdStore-Layout",
            Some(rollback_reference()),
        )
        .expect("first shared-source block should build");
        let second_cold = WeightBlockManifest::from_known_hash_hex(
            "local/cold-atlas-fixture",
            shared_source_uri,
            4096,
            1024,
            blake3::hash(b"second-shared-source-page").to_hex().as_str(),
            1_779_000_000_000,
            WeightBlockEncoding::Nf4,
            WeightBlockResidencyClass::ColdMmapSsd,
            WeightBlockIrChart::OpaqueWithWitness,
            0.02,
            "F-AppColdStore-Layout",
            Some(rollback_reference()),
        )
        .expect("second shared-source block should build");
        let budget = ResidencyBudget::new(GIB, 0, 8 * GIB, 0.25, 16).unwrap();
        let plan = ResidencyPlan::evaluate([hot, first_cold, second_cold], budget, 42);
        assert_eq!(plan.status, ResidencyPlanStatus::FitForDryRun);

        let source_hint = format!("weight_page:source:{shared_source_uri}");
        let prior = eidos_prior(
            vec!["F-AppColdStore-Layout".to_string()],
            vec!["adapter:research_synthesis".to_string()],
            Vec::new(),
            vec![source_hint.clone()],
            0.82,
        )
        .expect("source-shaped support hint is route-prior valid before card admission");

        let err = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            route_prior_verifier_stack(),
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
            AppColdStoreRouteCardError::AmbiguousRoutePriorSupport {
                support: source_hint,
                matches: 2
            }
        );
    }

    #[test]
    fn eidos_route_prior_weight_page_hint_requires_explicit_binding_prefix() {
        let plan = fit_plan();
        let raw_source_hint = "source:file:///models/cold-atlas/cold-weight-page.safetensors";
        let prior = eidos_prior(
            vec!["F-AppColdStore-Layout".to_string()],
            vec!["adapter:research_synthesis".to_string()],
            Vec::new(),
            vec![raw_source_hint.to_string()],
            0.82,
        )
        .expect("raw support hint is route-prior valid before card admission");

        let err = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            route_prior_verifier_stack(),
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
            AppColdStoreRouteCardError::UnboundRoutePriorSupport {
                support: raw_source_hint.to_string()
            }
        );
    }

    #[test]
    fn eidos_route_prior_can_bind_weight_page_hint_by_uas_prefix() {
        let plan = fit_plan();
        let cold_address = plan
            .blocks
            .iter()
            .find(|block| block.residency_class == WeightBlockResidencyClass::ColdMmapSsd)
            .expect("fixture carries a durable cold page")
            .uas_address
            .to_string();
        let prior = eidos_prior(
            vec!["F-AppColdStore-Layout".to_string()],
            vec!["adapter:research_synthesis".to_string()],
            Vec::new(),
            vec![format!("weight_page:uas:{cold_address}")],
            0.82,
        )
        .expect("UAS-prefixed support hint is route-prior valid before card admission");

        let card = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            route_prior_verifier_stack(),
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            Some(prior),
            99,
        )
        .expect("UAS-prefixed support hint should bind the durable AppColdStore unit");

        assert_eq!(card.durable_units[0].uas_address.to_string(), cold_address);
    }

    #[test]
    fn eidos_route_prior_can_bind_weight_page_hint_by_hash_prefix() {
        let plan = fit_plan();
        let cold_hash = plan
            .blocks
            .iter()
            .find(|block| block.residency_class == WeightBlockResidencyClass::ColdMmapSsd)
            .expect("fixture carries a durable cold page")
            .content_hash_hex
            .clone();
        let prior = eidos_prior(
            vec!["F-AppColdStore-Layout".to_string()],
            vec!["adapter:research_synthesis".to_string()],
            Vec::new(),
            vec![format!("weight_page:hash:{cold_hash}")],
            0.82,
        )
        .expect("hash-prefixed support hint is route-prior valid before card admission");

        let card = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            route_prior_verifier_stack(),
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            Some(prior),
            99,
        )
        .expect("hash-prefixed support hint should bind the durable AppColdStore unit");

        assert_eq!(card.durable_units[0].content_hash_hex, cold_hash);
        assert_eq!(card.totals.runtime_model_bytes_loaded, 0);
    }

    #[test]
    fn eidos_route_prior_requires_likely_verifier_hint() {
        let plan = fit_plan();
        let prior = eidos_prior(
            Vec::new(),
            vec!["adapter:research_synthesis".to_string()],
            Vec::new(),
            vec![cold_weight_page_source_hint()],
            0.82,
        )
        .expect("support-bearing Eidos prior is shape-valid before route-card admission");

        let err = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            route_prior_verifier_stack(),
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            Some(prior),
            99,
        )
        .unwrap_err();

        assert_eq!(err, AppColdStoreRouteCardError::MissingRoutePriorVerifier);
    }

    #[test]
    fn eidos_route_prior_requires_neural_route_prior_falsifier() {
        let plan = fit_plan();
        let prior = eidos_prior(
            vec!["F-AppColdStore-Layout".to_string()],
            vec!["adapter:research_synthesis".to_string()],
            Vec::new(),
            vec![cold_weight_page_source_hint()],
            0.82,
        )
        .expect("valid Eidos prior should build");

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

        assert_eq!(
            err,
            AppColdStoreRouteCardError::MissingEidosNeuralRoutePriorVerifier
        );
    }

    #[test]
    fn eidos_route_prior_with_zero_confidence_cannot_admit_route_card() {
        let plan = fit_plan();
        let prior = eidos_prior(
            vec!["F-AppColdStore-Layout".to_string()],
            vec!["adapter:research_synthesis".to_string()],
            Vec::new(),
            vec![cold_weight_page_source_hint()],
            0.0,
        )
        .expect("zero is shape-valid before route-card admission");

        let err = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            route_prior_verifier_stack(),
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            Some(prior),
            99,
        )
        .unwrap_err();

        assert_eq!(err, AppColdStoreRouteCardError::RoutePriorConfidenceTooLow);
    }

    #[test]
    fn eidos_route_prior_rejects_unbounded_confidence_and_empty_support() {
        let err = eidos_prior(Vec::new(), Vec::new(), Vec::new(), Vec::new(), 1.01).unwrap_err();
        assert!(matches!(
            err,
            crate::eidos::EidosRoutePriorError::InvalidConfidence(v) if v == 1.01
        ));

        let plan = fit_plan();
        let prior = eidos_prior(
            vec!["F-AppColdStore-Layout".to_string()],
            Vec::new(),
            Vec::new(),
            Vec::new(),
            0.5,
        )
        .expect("Eidos prior may exist before AppColdStore support validation");
        let err = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            route_prior_verifier_stack(),
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
            vec![cold_weight_page_source_hint()],
            0.64,
            vec!["Eidos matched task meaning without closed evidence".to_string()],
        )
        .expect("Eidos can form optional-citation priors before route-card admission");

        let err = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            route_prior_verifier_stack(),
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

    #[test]
    fn app_cold_store_route_card_revalidates_mutated_eidos_route_prior_shape() {
        let plan = fit_plan();
        let mut nonfinite_prior = eidos_prior(
            vec!["F-AppColdStore-Layout".to_string()],
            vec!["adapter:research_synthesis".to_string()],
            Vec::new(),
            vec![cold_weight_page_source_hint()],
            0.82,
        )
        .expect("valid Eidos prior should build");
        nonfinite_prior.confidence = f32::NAN;

        let nonfinite_err = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            route_prior_verifier_stack(),
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            Some(nonfinite_prior),
            99,
        )
        .unwrap_err();

        assert!(matches!(
            nonfinite_err,
            AppColdStoreRouteCardError::InvalidRoutePriorShape { ref reason }
                if reason.contains("confidence")
        ));

        let mut empty_why_prior = eidos_prior(
            vec!["F-AppColdStore-Layout".to_string()],
            vec!["adapter:research_synthesis".to_string()],
            Vec::new(),
            vec![cold_weight_page_source_hint()],
            0.82,
        )
        .expect("valid Eidos prior should build");
        empty_why_prior.why_matched.clear();

        let empty_why_err = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            route_prior_verifier_stack(),
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            Some(empty_why_prior),
            99,
        )
        .unwrap_err();

        assert!(matches!(
            empty_why_err,
            AppColdStoreRouteCardError::InvalidRoutePriorShape { ref reason }
                if reason.contains("why_matched")
        ));
    }

    #[test]
    fn eidos_route_prior_card_address_separates_prior_list_fields() {
        let plan = fit_plan();
        let packet = eidos_packet();
        let domain_prior = EidosRoutePrior::from_packet(
            &packet,
            "deep_research:neural_importance_atlas",
            vec![eidos_chunk_id("vault://note/neural-importance")],
            EidosCitationNeed::Required,
            vec!["contradiction".to_string()],
            Vec::new(),
            vec!["F-AppColdStore-Layout".to_string()],
            vec!["adapter:research_synthesis".to_string()],
            Vec::new(),
            vec![cold_weight_page_source_hint()],
            0.82,
            vec!["Eidos matched cited vault evidence and route priors".to_string()],
        )
        .expect("domain prior should build");
        let contradiction_prior = EidosRoutePrior::from_packet(
            &packet,
            "deep_research:neural_importance_atlas",
            vec![eidos_chunk_id("vault://note/neural-importance")],
            EidosCitationNeed::Required,
            Vec::new(),
            vec!["contradiction".to_string()],
            vec!["F-AppColdStore-Layout".to_string()],
            vec!["adapter:research_synthesis".to_string()],
            Vec::new(),
            vec![cold_weight_page_source_hint()],
            0.82,
            vec!["Eidos matched cited vault evidence and route priors".to_string()],
        )
        .expect("contradiction prior should build");

        let domain_card = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            route_prior_verifier_stack(),
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            Some(domain_prior),
            99,
        )
        .expect("domain route prior should be admitted to the manifest card");
        let contradiction_card = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            route_prior_verifier_stack(),
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            Some(contradiction_prior),
            99,
        )
        .expect("contradiction route prior should be admitted to the manifest card");

        assert_ne!(
            domain_card.card_address, contradiction_card.card_address,
            "route-card identity must bind which Eidos prior field carried a hint"
        );
    }

    #[test]
    fn eidos_route_prior_card_address_binds_why_matched() {
        let plan = fit_plan();
        let first_prior = eidos_prior_with_why(
            vec!["F-AppColdStore-Layout".to_string()],
            vec!["adapter:research_synthesis".to_string()],
            Vec::new(),
            vec![cold_weight_page_source_hint()],
            0.82,
            vec!["Eidos matched closed citation evidence".to_string()],
        )
        .expect("first route prior should build");
        let second_prior = eidos_prior_with_why(
            vec!["F-AppColdStore-Layout".to_string()],
            vec!["adapter:research_synthesis".to_string()],
            Vec::new(),
            vec![cold_weight_page_source_hint()],
            0.82,
            vec!["Eidos found a contradiction hint for the same support".to_string()],
        )
        .expect("second route prior should build");

        let first_card = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            route_prior_verifier_stack(),
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            Some(first_prior),
            99,
        )
        .expect("first route prior should be admitted to the manifest card");
        let second_card = AppColdStoreRouteCard::from_residency_plan_with_eidos_prior(
            "deep_research:neural_importance_atlas",
            route_prior_verifier_stack(),
            "rollback:raw-installed-snapshot",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            &plan,
            "rebuild_warm_cache_from_durable_atlas",
            Some(second_prior),
            99,
        )
        .expect("second route prior should be admitted to the manifest card");

        assert_ne!(
            first_card.card_address, second_card.card_address,
            "route-card identity must bind Eidos why_matched so route priors stay explainable"
        );
    }
}
