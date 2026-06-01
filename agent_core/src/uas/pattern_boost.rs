//! Dry-run assembly genomes for Residency PatternBoost.
//!
//! These records are metadata-only. They describe a candidate UAS-addressed
//! assembly for offline/idle discovery, but they do not wake model bytes,
//! mutate live routing policy, mmap files, or run inference.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;

use crate::uas::{
    construction_card::{pro_status_preimage, product_build_preimage},
    ByteRange, ProStatus, ProductBuild, ResidencyTier, UasAddress, UasKind,
};

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AssemblyPageRun {
    pub source_uri: String,
    pub byte_range: ByteRange,
}

impl AssemblyPageRun {
    pub fn new(
        source_uri: impl Into<String>,
        byte_start: u64,
        byte_len: u64,
    ) -> Result<Self, UasAssemblyGenomeError> {
        let source_uri = source_uri.into();
        let byte_range = ByteRange::new(byte_start, byte_len)
            .map_err(|_| UasAssemblyGenomeError::InvalidPageRun)?;
        Ok(Self {
            source_uri,
            byte_range,
        })
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct UasAssemblyGenome {
    pub genome_address: UasAddress,
    pub mission_family: String,
    pub route_card_ref: UasAddress,
    pub runtime_route_id: String,
    pub selected_weight_pages: Vec<UasAddress>,
    pub selected_kv_pages: Vec<UasAddress>,
    pub selected_adapter_slices: Vec<UasAddress>,
    pub selected_evidence_pages: Vec<UasAddress>,
    pub selected_verifier_lanes: Vec<String>,
    pub sparse_attention_pattern: String,
    pub depth_policy: String,
    pub transport_page_runs: Vec<AssemblyPageRun>,
    pub codec_plan: Vec<String>,
    pub cache_reuse_keys: Vec<String>,
    pub pause_resume_points: Vec<String>,
    pub fallback_route: String,
    pub rollback_ref: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub residency_status: ResidencyTier,
}

impl UasAssemblyGenome {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        mission_family: impl Into<String>,
        route_card_ref: UasAddress,
        runtime_route_id: impl Into<String>,
        selected_weight_pages: Vec<UasAddress>,
        selected_kv_pages: Vec<UasAddress>,
        selected_adapter_slices: Vec<UasAddress>,
        selected_evidence_pages: Vec<UasAddress>,
        selected_verifier_lanes: Vec<String>,
        sparse_attention_pattern: impl Into<String>,
        depth_policy: impl Into<String>,
        transport_page_runs: Vec<AssemblyPageRun>,
        codec_plan: Vec<String>,
        cache_reuse_keys: Vec<String>,
        pause_resume_points: Vec<String>,
        fallback_route: impl Into<String>,
        rollback_ref: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        residency_status: ResidencyTier,
        created_at_ms: u64,
    ) -> Result<Self, UasAssemblyGenomeError> {
        validate_patternboost_status(&product_build, &pro_status, residency_status)?;

        let mission_family = mission_family.into();
        let runtime_route_id = runtime_route_id.into();
        let sparse_attention_pattern = sparse_attention_pattern.into();
        let depth_policy = depth_policy.into();
        let fallback_route = fallback_route.into();
        let rollback_ref = rollback_ref.into();
        validate_nonempty("mission_family", &mission_family)?;
        validate_nonempty("runtime_route_id", &runtime_route_id)?;
        validate_nonempty("sparse_attention_pattern", &sparse_attention_pattern)?;
        validate_nonempty("depth_policy", &depth_policy)?;
        validate_nonempty("fallback_route", &fallback_route)?;
        validate_nonempty("rollback_ref", &rollback_ref)?;

        if selected_weight_pages.is_empty()
            && selected_kv_pages.is_empty()
            && selected_adapter_slices.is_empty()
            && selected_evidence_pages.is_empty()
        {
            return Err(UasAssemblyGenomeError::MissingUasSupport);
        }

        let selected_weight_pages = canonicalize_addresses(
            "selected_weight_pages",
            selected_weight_pages,
            UasAddressClass::WeightPage,
        )?;
        let selected_kv_pages = canonicalize_addresses(
            "selected_kv_pages",
            selected_kv_pages,
            UasAddressClass::KvPage,
        )?;
        let selected_adapter_slices = canonicalize_addresses(
            "selected_adapter_slices",
            selected_adapter_slices,
            UasAddressClass::AdapterSlice,
        )?;
        let selected_evidence_pages = canonicalize_addresses(
            "selected_evidence_pages",
            selected_evidence_pages,
            UasAddressClass::EvidencePage,
        )?;
        let selected_verifier_lanes = canonicalize_strings(
            "selected_verifier_lanes",
            selected_verifier_lanes,
            UasAssemblyGenomeError::MissingVerifierLane,
        )?;
        let codec_plan = canonicalize_strings(
            "codec_plan",
            codec_plan,
            UasAssemblyGenomeError::MissingCodecPlan,
        )?;
        let cache_reuse_keys = canonicalize_strings(
            "cache_reuse_keys",
            cache_reuse_keys,
            UasAssemblyGenomeError::MissingCacheReuseKey,
        )?;
        let pause_resume_points = canonicalize_strings(
            "pause_resume_points",
            pause_resume_points,
            UasAssemblyGenomeError::MissingPauseResumePoint,
        )?;
        let transport_page_runs = canonicalize_page_runs(transport_page_runs)?;

        let genome_address = Self::address(
            &mission_family,
            &route_card_ref,
            &runtime_route_id,
            &selected_weight_pages,
            &selected_kv_pages,
            &selected_adapter_slices,
            &selected_evidence_pages,
            &selected_verifier_lanes,
            &sparse_attention_pattern,
            &depth_policy,
            &transport_page_runs,
            &codec_plan,
            &cache_reuse_keys,
            &pause_resume_points,
            &fallback_route,
            &rollback_ref,
            &product_build,
            &pro_status,
            residency_status,
            created_at_ms,
        );

        Ok(Self {
            genome_address,
            mission_family,
            route_card_ref,
            runtime_route_id,
            selected_weight_pages,
            selected_kv_pages,
            selected_adapter_slices,
            selected_evidence_pages,
            selected_verifier_lanes,
            sparse_attention_pattern,
            depth_policy,
            transport_page_runs,
            codec_plan,
            cache_reuse_keys,
            pause_resume_points,
            fallback_route,
            rollback_ref,
            product_build,
            pro_status,
            residency_status,
        })
    }

    pub fn validate_shape(&self) -> Result<(), UasAssemblyGenomeError> {
        let recomputed = Self::new(
            self.mission_family.clone(),
            self.route_card_ref.clone(),
            self.runtime_route_id.clone(),
            self.selected_weight_pages.clone(),
            self.selected_kv_pages.clone(),
            self.selected_adapter_slices.clone(),
            self.selected_evidence_pages.clone(),
            self.selected_verifier_lanes.clone(),
            self.sparse_attention_pattern.clone(),
            self.depth_policy.clone(),
            self.transport_page_runs.clone(),
            self.codec_plan.clone(),
            self.cache_reuse_keys.clone(),
            self.pause_resume_points.clone(),
            self.fallback_route.clone(),
            self.rollback_ref.clone(),
            self.product_build.clone(),
            self.pro_status.clone(),
            self.residency_status,
            self.genome_address.created_at_ms,
        )?;
        if recomputed != *self {
            return Err(UasAssemblyGenomeError::GenomeAddressMismatch);
        }
        Ok(())
    }

    #[allow(clippy::too_many_arguments)]
    fn address(
        mission_family: &str,
        route_card_ref: &UasAddress,
        runtime_route_id: &str,
        selected_weight_pages: &[UasAddress],
        selected_kv_pages: &[UasAddress],
        selected_adapter_slices: &[UasAddress],
        selected_evidence_pages: &[UasAddress],
        selected_verifier_lanes: &[String],
        sparse_attention_pattern: &str,
        depth_policy: &str,
        transport_page_runs: &[AssemblyPageRun],
        codec_plan: &[String],
        cache_reuse_keys: &[String],
        pause_resume_points: &[String],
        fallback_route: &str,
        rollback_ref: &str,
        product_build: &ProductBuild,
        pro_status: &ProStatus,
        residency_status: ResidencyTier,
        created_at_ms: u64,
    ) -> UasAddress {
        let mut preimage = String::new();
        preimage.push_str("uas_assembly_genome_v1\n");
        push_string_preimage(&mut preimage, "mission_family", mission_family);
        push_string_preimage(&mut preimage, "route_card_ref", &route_card_ref.to_string());
        push_string_preimage(&mut preimage, "runtime_route_id", runtime_route_id);
        push_address_list_preimage(
            &mut preimage,
            "selected_weight_pages",
            selected_weight_pages,
        );
        push_address_list_preimage(&mut preimage, "selected_kv_pages", selected_kv_pages);
        push_address_list_preimage(
            &mut preimage,
            "selected_adapter_slices",
            selected_adapter_slices,
        );
        push_address_list_preimage(
            &mut preimage,
            "selected_evidence_pages",
            selected_evidence_pages,
        );
        push_string_list_preimage(
            &mut preimage,
            "selected_verifier_lanes",
            selected_verifier_lanes,
        );
        push_string_preimage(
            &mut preimage,
            "sparse_attention_pattern",
            sparse_attention_pattern,
        );
        push_string_preimage(&mut preimage, "depth_policy", depth_policy);
        push_page_run_preimage(&mut preimage, transport_page_runs);
        push_string_list_preimage(&mut preimage, "codec_plan", codec_plan);
        push_string_list_preimage(&mut preimage, "cache_reuse_keys", cache_reuse_keys);
        push_string_list_preimage(&mut preimage, "pause_resume_points", pause_resume_points);
        push_string_preimage(&mut preimage, "fallback_route", fallback_route);
        push_string_preimage(&mut preimage, "rollback_ref", rollback_ref);
        push_string_preimage(
            &mut preimage,
            "product_build",
            product_build_preimage(product_build),
        );
        push_string_preimage(&mut preimage, "pro_status", pro_status_preimage(pro_status));
        push_string_preimage(
            &mut preimage,
            "residency_status",
            residency_status.wire_tag(),
        );

        UasAddress::new(
            UasKind::Other("uas_assembly_genome".to_string()),
            preimage.as_bytes(),
            created_at_ms,
        )
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum UasAssemblyGenomeError {
    MissingMissionFamily,
    MissingRuntimeRoute,
    MissingUasSupport,
    MissingVerifierLane,
    MissingSparseAttentionPattern,
    MissingDepthPolicy,
    MissingTransportPageRun,
    MissingCodecPlan,
    MissingCacheReuseKey,
    MissingPauseResumePoint,
    MissingFallbackRoute,
    MissingRollback,
    FieldHasSurroundingWhitespace {
        field: &'static str,
    },
    FieldContainsControlCharacter {
        field: &'static str,
    },
    InvalidPageRun,
    ProductBuildStatusMismatch,
    DuplicateAddress {
        field: &'static str,
    },
    DuplicateString {
        field: &'static str,
    },
    InvalidUasKind {
        field: &'static str,
        actual_kind: String,
    },
    GenomeAddressMismatch,
}

impl std::fmt::Display for UasAssemblyGenomeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::MissingMissionFamily => write!(f, "mission_family is required"),
            Self::MissingRuntimeRoute => write!(f, "runtime_route_id is required"),
            Self::MissingUasSupport => write!(
                f,
                "at least one selected UAS support object is required"
            ),
            Self::MissingVerifierLane => write!(f, "selected_verifier_lanes is required"),
            Self::MissingSparseAttentionPattern => {
                write!(f, "sparse_attention_pattern is required")
            }
            Self::MissingDepthPolicy => write!(f, "depth_policy is required"),
            Self::MissingTransportPageRun => write!(f, "transport_page_runs is required"),
            Self::MissingCodecPlan => write!(f, "codec_plan is required"),
            Self::MissingCacheReuseKey => write!(f, "cache_reuse_keys is required"),
            Self::MissingPauseResumePoint => write!(f, "pause_resume_points is required"),
            Self::MissingFallbackRoute => write!(f, "fallback_route is required"),
            Self::MissingRollback => write!(f, "rollback_ref is required"),
            Self::FieldHasSurroundingWhitespace { field } => {
                write!(f, "{field} must not contain leading or trailing whitespace")
            }
            Self::FieldContainsControlCharacter { field } => {
                write!(f, "{field} must not contain control characters")
            }
            Self::InvalidPageRun => write!(f, "transport page run is invalid"),
            Self::ProductBuildStatusMismatch => write!(
                f,
                "Residency PatternBoost genomes must stay Pro Research / capability-ceiling metadata"
            ),
            Self::DuplicateAddress { field } => {
                write!(f, "{field} must not contain duplicate UAS addresses")
            }
            Self::DuplicateString { field } => {
                write!(f, "{field} must not contain duplicate values")
            }
            Self::InvalidUasKind { field, actual_kind } => {
                write!(f, "{field} contains unsupported UAS kind {actual_kind}")
            }
            Self::GenomeAddressMismatch => write!(
                f,
                "genome_address no longer matches the deterministic genome preimage"
            ),
        }
    }
}

impl std::error::Error for UasAssemblyGenomeError {}

#[derive(Clone, Copy)]
enum UasAddressClass {
    WeightPage,
    KvPage,
    AdapterSlice,
    EvidencePage,
}

fn validate_patternboost_status(
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    residency_status: ResidencyTier,
) -> Result<(), UasAssemblyGenomeError> {
    if product_build != &ProductBuild::Pro
        || pro_status != &ProStatus::ResearchCandidate
        || residency_status != ResidencyTier::CapabilityCeiling
    {
        return Err(UasAssemblyGenomeError::ProductBuildStatusMismatch);
    }
    Ok(())
}

fn validate_nonempty(field: &'static str, value: &str) -> Result<(), UasAssemblyGenomeError> {
    if value.trim().is_empty() {
        return Err(missing_field_error(field));
    }
    if value.trim() != value {
        return Err(UasAssemblyGenomeError::FieldHasSurroundingWhitespace { field });
    }
    if value.chars().any(char::is_control) {
        return Err(UasAssemblyGenomeError::FieldContainsControlCharacter { field });
    }
    Ok(())
}

fn missing_field_error(field: &'static str) -> UasAssemblyGenomeError {
    match field {
        "mission_family" => UasAssemblyGenomeError::MissingMissionFamily,
        "runtime_route_id" => UasAssemblyGenomeError::MissingRuntimeRoute,
        "sparse_attention_pattern" => UasAssemblyGenomeError::MissingSparseAttentionPattern,
        "depth_policy" => UasAssemblyGenomeError::MissingDepthPolicy,
        "fallback_route" => UasAssemblyGenomeError::MissingFallbackRoute,
        "rollback_ref" => UasAssemblyGenomeError::MissingRollback,
        "transport_page_run_source_uri" => UasAssemblyGenomeError::MissingTransportPageRun,
        _ => UasAssemblyGenomeError::MissingUasSupport,
    }
}

fn canonicalize_addresses(
    field: &'static str,
    mut addresses: Vec<UasAddress>,
    address_class: UasAddressClass,
) -> Result<Vec<UasAddress>, UasAssemblyGenomeError> {
    for address in &addresses {
        validate_address_kind(field, address, address_class)?;
    }
    addresses.sort_by_key(|address| address.to_string());
    let mut seen = HashSet::new();
    for address in &addresses {
        if !seen.insert(address.to_string()) {
            return Err(UasAssemblyGenomeError::DuplicateAddress { field });
        }
    }
    Ok(addresses)
}

fn validate_address_kind(
    field: &'static str,
    address: &UasAddress,
    address_class: UasAddressClass,
) -> Result<(), UasAssemblyGenomeError> {
    let valid = match address_class {
        UasAddressClass::WeightPage => matches!(address.kind, UasKind::ModelComponent),
        UasAddressClass::KvPage => matches!(address.kind, UasKind::KvPage),
        UasAddressClass::AdapterSlice => match &address.kind {
            UasKind::ModelComponent => true,
            UasKind::Other(tag) => tag == "adapter_slice",
            _ => false,
        },
        UasAddressClass::EvidencePage => matches!(
            address.kind,
            UasKind::VaultNote | UasKind::GraphNode | UasKind::Claim
        ),
    };
    if !valid {
        return Err(UasAssemblyGenomeError::InvalidUasKind {
            field,
            actual_kind: address.kind.wire_tag().to_string(),
        });
    }
    Ok(())
}

fn canonicalize_strings(
    field: &'static str,
    mut values: Vec<String>,
    missing_error: UasAssemblyGenomeError,
) -> Result<Vec<String>, UasAssemblyGenomeError> {
    if values.is_empty() {
        return Err(missing_error);
    }
    for value in &values {
        if value.trim().is_empty() {
            return Err(missing_error.clone());
        }
        if value.trim() != value {
            return Err(UasAssemblyGenomeError::FieldHasSurroundingWhitespace { field });
        }
        if value.chars().any(char::is_control) {
            return Err(UasAssemblyGenomeError::FieldContainsControlCharacter { field });
        }
    }
    values.sort();
    let mut seen = HashSet::new();
    for value in &values {
        if !seen.insert(value.as_str()) {
            return Err(UasAssemblyGenomeError::DuplicateString { field });
        }
    }
    Ok(values)
}

fn canonicalize_page_runs(
    mut page_runs: Vec<AssemblyPageRun>,
) -> Result<Vec<AssemblyPageRun>, UasAssemblyGenomeError> {
    if page_runs.is_empty() {
        return Err(UasAssemblyGenomeError::MissingTransportPageRun);
    }
    for page_run in &page_runs {
        validate_nonempty("transport_page_run_source_uri", &page_run.source_uri)?;
        if page_run.byte_range.len == 0
            || page_run
                .byte_range
                .start
                .checked_add(page_run.byte_range.len)
                .is_none()
        {
            return Err(UasAssemblyGenomeError::InvalidPageRun);
        }
    }
    page_runs.sort_by(|left, right| {
        left.source_uri
            .cmp(&right.source_uri)
            .then(left.byte_range.start.cmp(&right.byte_range.start))
            .then(left.byte_range.len.cmp(&right.byte_range.len))
    });
    let mut seen = HashSet::new();
    for page_run in &page_runs {
        let key = format!(
            "{}:{}:{}",
            page_run.source_uri, page_run.byte_range.start, page_run.byte_range.len
        );
        if !seen.insert(key) {
            return Err(UasAssemblyGenomeError::DuplicateString {
                field: "transport_page_runs",
            });
        }
    }
    Ok(page_runs)
}

fn push_string_preimage(preimage: &mut String, label: &str, value: &str) {
    preimage.push_str(label);
    preimage.push(':');
    preimage.push_str(&value.len().to_string());
    preimage.push(':');
    preimage.push_str(value);
    preimage.push('\n');
}

fn push_string_list_preimage(preimage: &mut String, label: &str, values: &[String]) {
    preimage.push_str(label);
    preimage.push(':');
    preimage.push_str(&values.len().to_string());
    preimage.push('\n');
    for value in values {
        push_string_preimage(preimage, "item", value);
    }
}

fn push_address_list_preimage(preimage: &mut String, label: &str, values: &[UasAddress]) {
    preimage.push_str(label);
    preimage.push(':');
    preimage.push_str(&values.len().to_string());
    preimage.push('\n');
    for value in values {
        push_string_preimage(preimage, "address", &value.to_string());
    }
}

fn push_page_run_preimage(preimage: &mut String, page_runs: &[AssemblyPageRun]) {
    preimage.push_str("transport_page_runs:");
    preimage.push_str(&page_runs.len().to_string());
    preimage.push('\n');
    for page_run in page_runs {
        push_string_preimage(preimage, "source_uri", &page_run.source_uri);
        preimage.push_str("range:");
        preimage.push_str(&page_run.byte_range.start.to_string());
        preimage.push(':');
        preimage.push_str(&page_run.byte_range.len.to_string());
        preimage.push('\n');
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn addr(kind: UasKind, label: &[u8]) -> UasAddress {
        UasAddress::new(kind, label, 7)
    }

    fn route_card_ref() -> UasAddress {
        addr(
            UasKind::Other("app_cold_store_route_card".to_string()),
            b"route-card",
        )
    }

    fn page_run(label: &str, start: u64) -> AssemblyPageRun {
        AssemblyPageRun::new(format!("file:///coldstore/{label}.epwp"), start, 128)
            .expect("page run fixture should be valid")
    }

    fn genome_with_order(
        weights: Vec<UasAddress>,
        kv: Vec<UasAddress>,
        evidence: Vec<UasAddress>,
        verifier_lanes: Vec<String>,
        page_runs: Vec<AssemblyPageRun>,
        created_at_ms: u64,
    ) -> UasAssemblyGenome {
        UasAssemblyGenome::new(
            "citation_heavy_research",
            route_card_ref(),
            "runtime_router:shadow_patternboost_route",
            weights,
            kv,
            vec![addr(UasKind::ModelComponent, b"adapter-citation")],
            evidence,
            verifier_lanes,
            "query_aware_sparse_attention_v0",
            "depth_budget_gate_shadow_v0",
            page_runs,
            vec!["nf4".to_string(), "dense_bf16".to_string()],
            vec!["kv:research-prefix".to_string()],
            vec!["kv_restore_before_decode".to_string()],
            "runtime_router:fallback_static_route",
            "rollback:static_route_policy",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            ResidencyTier::CapabilityCeiling,
            created_at_ms,
        )
        .expect("genome fixture should build")
    }

    #[test]
    fn uas_assembly_genome_digest_is_order_stable_and_round_trips() {
        let a = genome_with_order(
            vec![
                addr(UasKind::ModelComponent, b"weight-b"),
                addr(UasKind::ModelComponent, b"weight-a"),
            ],
            vec![
                addr(UasKind::KvPage, b"kv-b"),
                addr(UasKind::KvPage, b"kv-a"),
            ],
            vec![
                addr(UasKind::VaultNote, b"evidence-b"),
                addr(UasKind::VaultNote, b"evidence-a"),
            ],
            vec![
                "F-ParamRouteCard-Admission".to_string(),
                "F-Eidos".to_string(),
            ],
            vec![page_run("b", 128), page_run("a", 0)],
            42,
        );
        let b = genome_with_order(
            vec![
                addr(UasKind::ModelComponent, b"weight-a"),
                addr(UasKind::ModelComponent, b"weight-b"),
            ],
            vec![
                addr(UasKind::KvPage, b"kv-a"),
                addr(UasKind::KvPage, b"kv-b"),
            ],
            vec![
                addr(UasKind::VaultNote, b"evidence-a"),
                addr(UasKind::VaultNote, b"evidence-b"),
            ],
            vec![
                "F-Eidos".to_string(),
                "F-ParamRouteCard-Admission".to_string(),
            ],
            vec![page_run("a", 0), page_run("b", 128)],
            42,
        );

        assert_eq!(a.genome_address, b.genome_address);

        let json = serde_json::to_string(&a).expect("genome should serialize");
        let parsed: UasAssemblyGenome =
            serde_json::from_str(&json).expect("genome should deserialize");
        assert_eq!(parsed, a);
        parsed
            .validate_shape()
            .expect("round-tripped genome should validate");
    }

    #[test]
    fn uas_assembly_genome_rejects_missing_uas_support() {
        let err = UasAssemblyGenome::new(
            "citation_heavy_research",
            route_card_ref(),
            "runtime_router:shadow_patternboost_route",
            Vec::new(),
            Vec::new(),
            Vec::new(),
            Vec::new(),
            vec!["F-ParamRouteCard-Admission".to_string()],
            "query_aware_sparse_attention_v0",
            "depth_budget_gate_shadow_v0",
            vec![page_run("a", 0)],
            vec!["nf4".to_string()],
            vec!["kv:research-prefix".to_string()],
            vec!["kv_restore_before_decode".to_string()],
            "runtime_router:fallback_static_route",
            "rollback:static_route_policy",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            ResidencyTier::CapabilityCeiling,
            42,
        )
        .unwrap_err();

        assert_eq!(err, UasAssemblyGenomeError::MissingUasSupport);
    }

    #[test]
    fn uas_assembly_genome_rejects_missing_runtime_identity() {
        let err = UasAssemblyGenome::new(
            "citation_heavy_research",
            route_card_ref(),
            "",
            vec![addr(UasKind::ModelComponent, b"weight-a")],
            Vec::new(),
            Vec::new(),
            Vec::new(),
            vec!["F-ParamRouteCard-Admission".to_string()],
            "query_aware_sparse_attention_v0",
            "depth_budget_gate_shadow_v0",
            vec![page_run("a", 0)],
            vec!["nf4".to_string()],
            vec!["kv:research-prefix".to_string()],
            vec!["kv_restore_before_decode".to_string()],
            "runtime_router:fallback_static_route",
            "rollback:static_route_policy",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            ResidencyTier::CapabilityCeiling,
            42,
        )
        .unwrap_err();

        assert_eq!(err, UasAssemblyGenomeError::MissingRuntimeRoute);
    }

    #[test]
    fn uas_assembly_genome_rejects_live_or_mas_promotion() {
        let err = UasAssemblyGenome::new(
            "citation_heavy_research",
            route_card_ref(),
            "runtime_router:shadow_patternboost_route",
            vec![addr(UasKind::ModelComponent, b"weight-a")],
            Vec::new(),
            Vec::new(),
            Vec::new(),
            vec!["F-ParamRouteCard-Admission".to_string()],
            "query_aware_sparse_attention_v0",
            "depth_budget_gate_shadow_v0",
            vec![page_run("a", 0)],
            vec!["nf4".to_string()],
            vec!["kv:research-prefix".to_string()],
            vec!["kv_restore_before_decode".to_string()],
            "runtime_router:fallback_static_route",
            "rollback:static_route_policy",
            ProductBuild::Mas,
            ProStatus::Live,
            ResidencyTier::CurrentApp,
            42,
        )
        .unwrap_err();

        assert_eq!(err, UasAssemblyGenomeError::ProductBuildStatusMismatch);
    }

    #[test]
    fn uas_assembly_genome_address_binds_transport_page_runs() {
        let mut genome = genome_with_order(
            vec![addr(UasKind::ModelComponent, b"weight-a")],
            Vec::new(),
            Vec::new(),
            vec!["F-ParamRouteCard-Admission".to_string()],
            vec![page_run("a", 0)],
            42,
        );
        genome.transport_page_runs[0].byte_range =
            ByteRange::new(0, 256).expect("mutated byte range should be valid");

        let err = genome.validate_shape().unwrap_err();

        assert_eq!(err, UasAssemblyGenomeError::GenomeAddressMismatch);
    }
}
