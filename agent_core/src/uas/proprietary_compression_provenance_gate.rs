//! Proprietary compression provenance gate.
//!
//! This primitive turns TurboVec/QAT/fork-mining research into an executable
//! source-card gate. It allows aggressive quarantine research while blocking
//! copied code, hidden route authority, model/runtime bytes, and product claims
//! until later witnesses promote the work.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashMap, HashSet};
use std::fmt;

use crate::uas::construction_card::{pro_status_preimage, product_build_preimage};
use crate::uas::{
    ModelInventoryCandidateSet, ProStatus, ProductBuild, SourceSignalGraph, UasAddress, UasKind,
};

pub const PROPRIETARY_COMPRESSION_PROVENANCE_GATE_CURSOR: &str =
    "proprietary_compression_provenance_gate";
pub const PROPRIETARY_COMPRESSION_PROVENANCE_GATE_NEXT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";

const FALSIFIER_PREFIX: &str = "falsifier:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const MAX_GATE_METADATA_BYTES: u64 = 768 * 1024;
const MAX_QUARANTINE_SOURCE_BYTES: u64 = 2 * 1024 * 1024;

// UAS: uas:proprietary-compression:source-kind
// Plane: State + Verification
// Residency: metadata-only source taxonomy; not import permission by itself.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ProprietaryCompressionSourceKind {
    Repo,
    Fork,
    Paper,
    Blog,
    ModelCard,
    RuntimePackage,
    LocalCanon,
    BenchmarkReport,
}

// UAS: uas:proprietary-compression:license-class
// Plane: Verification
// Residency: metadata-only license classification for provenance routing.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ProprietaryCompressionLicenseClass {
    Permissive,
    Copyleft,
    Unclear,
    NoLicense,
    ResearchPaper,
    ModelLicense,
    InternalCanon,
}

// UAS: uas:proprietary-compression:import-mode
// Plane: Controller + Verification
// Residency: metadata-only import decision; no code is imported by this gate.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ProprietaryCompressionImportMode {
    DirectImport,
    AdapterWrap,
    QuarantineReference,
    CleanRoomRewrite,
    ResearchOnly,
}

// UAS: uas:proprietary-compression:allowed-action
// Plane: Controller + Verification
// Residency: metadata-only action class before build-graph entry is allowed.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ProprietaryCompressionAllowedAction {
    VendorOrAdaptWithAttribution,
    AdapterOnly,
    QuarantineInspectBenchmark,
    CleanRoomImplement,
    SourceCardPriorOnly,
    NegativeFixtureOnly,
}

// UAS: uas:proprietary-compression:behavior-kind
// Plane: Assembly + Verification
// Residency: extracted motifs/tests only; not copied implementation bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ProprietaryCompressionBehaviorKind {
    ApiShape,
    ParserBehavior,
    CacheLogic,
    BenchmarkHarness,
    TestFixture,
    FailureCase,
    QuantizationMath,
    VectorIndexing,
    RuntimeLane,
    MemoryAssumption,
}

// UAS: uas:proprietary-compression:behavior
// Plane: Assembly + Verification
// Residency: source-derived behavior summary; verbatim code stays blocked.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProprietaryCompressionExtractedBehavior {
    pub behavior_id: String,
    pub kind: ProprietaryCompressionBehaviorKind,
    pub summary_ref: String,
    pub evidence_ref: String,
    pub uses_verbatim_code: bool,
}

// UAS: uas:proprietary-compression:byte-scope
// Plane: Verification
// Residency: metadata/quarantine source bytes only; no model/index/runtime bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProprietaryCompressionByteScope {
    pub metadata_bytes_read: u64,
    pub quarantine_source_bytes_inspected: u64,
    pub copied_product_file_count: u64,
    pub model_bytes_loaded: u64,
    pub index_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

impl ProprietaryCompressionByteScope {
    pub fn metadata_only(metadata_bytes_read: u64, quarantine_source_bytes_inspected: u64) -> Self {
        Self {
            metadata_bytes_read,
            quarantine_source_bytes_inspected,
            copied_product_file_count: 0,
            model_bytes_loaded: 0,
            index_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
        }
    }
}

// UAS: uas:proprietary-compression:proof-refs
// Plane: Verification
// Residency: visible proof handles for rollback, RunEventLog, and AnswerPacket.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProprietaryCompressionProofRefs {
    pub falsifier_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence_ref: String,
}

// UAS: uas:proprietary-compression:source-overlay
// Plane: State + Assembly + Controller + Verification
// Residency: quarantine/provenance overlay; never hidden route authority.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProprietaryCompressionSourceOverlay {
    pub overlay_id: String,
    pub source_id: String,
    pub source_digest: String,
    pub source_kind: ProprietaryCompressionSourceKind,
    pub source_locator: String,
    pub observed_at_utc: String,
    pub license_class: ProprietaryCompressionLicenseClass,
    pub import_mode: ProprietaryCompressionImportMode,
    pub allowed_action: ProprietaryCompressionAllowedAction,
    pub dependency_count: u64,
    pub transitive_unknown_dependency_count: u64,
    pub benchmark_claim_count: u64,
    pub extracted_behaviors: Vec<ProprietaryCompressionExtractedBehavior>,
    pub local_test_plan_ref: Option<String>,
    pub quarantine_ref: Option<String>,
    pub clean_room_note_ref: Option<String>,
    pub attribution_ref: Option<String>,
    pub model_inventory_candidate_ref: Option<String>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub byte_scope: ProprietaryCompressionByteScope,
    pub proof_refs: ProprietaryCompressionProofRefs,
}

// UAS: uas:proprietary-compression:gate
// Plane: State + Assembly + Controller + Verification
// Residency: metadata-only gate over compression research sources.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProprietaryCompressionProvenanceGate {
    pub gate_address: UasAddress,
    pub source_graph_address: UasAddress,
    pub model_inventory_address: UasAddress,
    pub overlays: Vec<ProprietaryCompressionSourceOverlay>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub route_authority_blocked: bool,
    pub product_promotion_blocked: bool,
    pub build_graph_contamination_blocked: bool,
}

// UAS: uas:proprietary-compression:metrics
// Plane: Verification
// Residency: derived counters for metadata-only falsifier artifacts.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProprietaryCompressionProvenanceMetrics {
    pub overlay_count: u64,
    pub source_kind_count: u64,
    pub license_class_count: u64,
    pub import_mode_count: u64,
    pub allowed_action_count: u64,
    pub behavior_kind_count: u64,
    pub behavior_count: u64,
    pub model_inventory_binding_count: u64,
    pub benchmark_claim_count: u64,
    pub local_test_plan_count: u64,
    pub quarantine_ref_count: u64,
    pub clean_room_note_count: u64,
    pub attribution_ref_count: u64,
    pub metadata_bytes_read: u64,
    pub quarantine_source_bytes_inspected: u64,
    pub copied_product_file_count: u64,
    pub model_bytes_loaded: u64,
    pub index_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub transitive_unknown_dependency_count: u64,
}

impl ProprietaryCompressionProvenanceGate {
    #[allow(clippy::too_many_arguments)]
    pub fn from_sources(
        graph: &SourceSignalGraph,
        inventory: &ModelInventoryCandidateSet,
        mut overlays: Vec<ProprietaryCompressionSourceOverlay>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        route_authority_blocked: bool,
        product_promotion_blocked: bool,
        build_graph_contamination_blocked: bool,
        created_at_ms: u64,
    ) -> Result<Self, ProprietaryCompressionProvenanceError> {
        overlays.sort_by(|a, b| a.overlay_id.cmp(&b.overlay_id));
        validate_gate_inputs(
            graph,
            inventory,
            &overlays,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            route_authority_blocked,
            product_promotion_blocked,
            build_graph_contamination_blocked,
        )?;
        let gate_address = gate_address(
            &graph.graph_address,
            &inventory.inventory_address,
            &overlays,
            &product_build,
            &pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            route_authority_blocked,
            product_promotion_blocked,
            build_graph_contamination_blocked,
            created_at_ms,
        );
        Ok(Self {
            gate_address,
            source_graph_address: graph.graph_address.clone(),
            model_inventory_address: inventory.inventory_address.clone(),
            overlays,
            product_build,
            pro_status,
            metadata_bytes,
            l1_l2_l3_separated,
            route_authority_blocked,
            product_promotion_blocked,
            build_graph_contamination_blocked,
        })
    }

    pub fn metrics(&self) -> ProprietaryCompressionProvenanceMetrics {
        let mut source_kinds = BTreeSet::new();
        let mut license_classes = BTreeSet::new();
        let mut import_modes = BTreeSet::new();
        let mut allowed_actions = BTreeSet::new();
        let mut behavior_kinds = BTreeSet::new();

        for overlay in &self.overlays {
            source_kinds.insert(overlay.source_kind);
            license_classes.insert(overlay.license_class);
            import_modes.insert(overlay.import_mode);
            allowed_actions.insert(overlay.allowed_action);
            for behavior in &overlay.extracted_behaviors {
                behavior_kinds.insert(behavior.kind);
            }
        }

        ProprietaryCompressionProvenanceMetrics {
            overlay_count: self.overlays.len() as u64,
            source_kind_count: source_kinds.len() as u64,
            license_class_count: license_classes.len() as u64,
            import_mode_count: import_modes.len() as u64,
            allowed_action_count: allowed_actions.len() as u64,
            behavior_kind_count: behavior_kinds.len() as u64,
            behavior_count: self
                .overlays
                .iter()
                .map(|overlay| overlay.extracted_behaviors.len() as u64)
                .sum(),
            model_inventory_binding_count: self
                .overlays
                .iter()
                .filter(|overlay| overlay.model_inventory_candidate_ref.is_some())
                .count() as u64,
            benchmark_claim_count: self
                .overlays
                .iter()
                .map(|overlay| overlay.benchmark_claim_count)
                .sum(),
            local_test_plan_count: self
                .overlays
                .iter()
                .filter(|overlay| overlay.local_test_plan_ref.is_some())
                .count() as u64,
            quarantine_ref_count: self
                .overlays
                .iter()
                .filter(|overlay| overlay.quarantine_ref.is_some())
                .count() as u64,
            clean_room_note_count: self
                .overlays
                .iter()
                .filter(|overlay| overlay.clean_room_note_ref.is_some())
                .count() as u64,
            attribution_ref_count: self
                .overlays
                .iter()
                .filter(|overlay| overlay.attribution_ref.is_some())
                .count() as u64,
            metadata_bytes_read: self
                .overlays
                .iter()
                .map(|overlay| overlay.byte_scope.metadata_bytes_read)
                .sum(),
            quarantine_source_bytes_inspected: self
                .overlays
                .iter()
                .map(|overlay| overlay.byte_scope.quarantine_source_bytes_inspected)
                .sum(),
            copied_product_file_count: self
                .overlays
                .iter()
                .map(|overlay| overlay.byte_scope.copied_product_file_count)
                .sum(),
            model_bytes_loaded: self
                .overlays
                .iter()
                .map(|overlay| overlay.byte_scope.model_bytes_loaded)
                .sum(),
            index_bytes_loaded: self
                .overlays
                .iter()
                .map(|overlay| overlay.byte_scope.index_bytes_loaded)
                .sum(),
            runtime_bytes_loaded: self
                .overlays
                .iter()
                .map(|overlay| overlay.byte_scope.runtime_bytes_loaded)
                .sum(),
            provider_calls_made: self
                .overlays
                .iter()
                .map(|overlay| overlay.byte_scope.provider_calls_made)
                .sum(),
            transitive_unknown_dependency_count: self
                .overlays
                .iter()
                .map(|overlay| overlay.transitive_unknown_dependency_count)
                .sum(),
        }
    }

    pub fn address(&self) -> String {
        self.gate_address.to_string()
    }
}

// UAS: uas:proprietary-compression:error
// Plane: Verification
// Residency: fail-closed rejection taxonomy before build/runtime promotion.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ProprietaryCompressionProvenanceError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    EmptyOverlaySet,
    SourceGraphMismatch,
    DuplicateOverlayId(String),
    DuplicateSourceId(String),
    DuplicateBehaviorId(String),
    DuplicateLocator(String),
    UnknownSourceId(String),
    BlockedSourceId(String),
    SourceDigestMismatch(String),
    UnknownModelInventoryCandidate(String),
    ModelInventorySourceMismatch(String),
    MissingProofRef {
        overlay_id: String,
        field: &'static str,
    },
    BadProofRefPrefix {
        overlay_id: String,
        field: &'static str,
    },
    MissingBehavior(String),
    VerbatimCodeUsed(String),
    NoLicenseDirectImport(String),
    UnclearLicenseDirectImport(String),
    CopyleftDirectImport(String),
    UnsafeAdapterLicense(String),
    DirectImportMissingAttribution(String),
    DirectImportMissingTestPlan(String),
    AdapterMissingTestPlan(String),
    MissingQuarantineRef(String),
    MissingCleanRoomNote(String),
    BenchmarkWithoutLocalTestPlan(String),
    UnknownTransitiveDependency(String),
    ProductFileCopied(String),
    NonzeroModelBytes(String),
    NonzeroIndexBytes(String),
    NonzeroRuntimeBytes(String),
    ProviderCallMade(String),
    HiddenRouteAuthority(String),
    HiddenCloudFallback(String),
    Dense70BLiveClaim(String),
    SsdAsRamClaim(String),
    ProductGreenFromResearch(String),
    MasLiveFromResearch(String),
    MissingLayerSeparation,
    MetadataBudgetExceeded,
    QuarantineBudgetExceeded,
}

impl fmt::Display for ProprietaryCompressionProvenanceError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptyOverlaySet => write!(f, "missing provenance overlays"),
            Self::SourceGraphMismatch => write!(f, "model inventory is not bound to source graph"),
            Self::DuplicateOverlayId(id) => write!(f, "duplicate overlay id `{id}`"),
            Self::DuplicateSourceId(id) => write!(f, "duplicate source id `{id}`"),
            Self::DuplicateBehaviorId(id) => write!(f, "duplicate behavior id `{id}`"),
            Self::DuplicateLocator(locator) => write!(f, "duplicate locator `{locator}`"),
            Self::UnknownSourceId(id) => write!(f, "unknown source id `{id}`"),
            Self::BlockedSourceId(id) => write!(f, "blocked source id `{id}`"),
            Self::SourceDigestMismatch(id) => write!(f, "source digest mismatch for `{id}`"),
            Self::UnknownModelInventoryCandidate(id) => {
                write!(f, "unknown model inventory candidate `{id}`")
            }
            Self::ModelInventorySourceMismatch(id) => {
                write!(f, "model inventory candidate source mismatch for `{id}`")
            }
            Self::MissingProofRef { overlay_id, field } => {
                write!(f, "overlay `{overlay_id}` missing proof ref `{field}`")
            }
            Self::BadProofRefPrefix { overlay_id, field } => {
                write!(
                    f,
                    "overlay `{overlay_id}` has bad proof ref prefix `{field}`"
                )
            }
            Self::MissingBehavior(id) => write!(f, "overlay `{id}` has no extracted behaviors"),
            Self::VerbatimCodeUsed(id) => write!(f, "overlay `{id}` used verbatim code"),
            Self::NoLicenseDirectImport(id) => {
                write!(f, "overlay `{id}` direct-imported no-license source")
            }
            Self::UnclearLicenseDirectImport(id) => {
                write!(f, "overlay `{id}` direct-imported unclear-license source")
            }
            Self::CopyleftDirectImport(id) => {
                write!(f, "overlay `{id}` direct-imported copyleft source")
            }
            Self::UnsafeAdapterLicense(id) => {
                write!(f, "overlay `{id}` adapter-wrapped unsafe license")
            }
            Self::DirectImportMissingAttribution(id) => {
                write!(f, "overlay `{id}` missing direct-import attribution")
            }
            Self::DirectImportMissingTestPlan(id) => {
                write!(f, "overlay `{id}` missing direct-import test plan")
            }
            Self::AdapterMissingTestPlan(id) => {
                write!(f, "overlay `{id}` missing adapter test plan")
            }
            Self::MissingQuarantineRef(id) => write!(f, "overlay `{id}` missing quarantine ref"),
            Self::MissingCleanRoomNote(id) => write!(f, "overlay `{id}` missing clean-room note"),
            Self::BenchmarkWithoutLocalTestPlan(id) => {
                write!(f, "overlay `{id}` benchmark claim lacks local test plan")
            }
            Self::UnknownTransitiveDependency(id) => {
                write!(f, "overlay `{id}` has unknown transitive dependencies")
            }
            Self::ProductFileCopied(id) => write!(f, "overlay `{id}` copied product files"),
            Self::NonzeroModelBytes(id) => write!(f, "overlay `{id}` loaded model bytes"),
            Self::NonzeroIndexBytes(id) => write!(f, "overlay `{id}` loaded index bytes"),
            Self::NonzeroRuntimeBytes(id) => write!(f, "overlay `{id}` loaded runtime bytes"),
            Self::ProviderCallMade(id) => write!(f, "overlay `{id}` made provider calls"),
            Self::HiddenRouteAuthority(id) => write!(f, "overlay `{id}` hid route authority"),
            Self::HiddenCloudFallback(id) => write!(f, "overlay `{id}` hid cloud fallback"),
            Self::Dense70BLiveClaim(id) => write!(f, "overlay `{id}` claimed live dense 70B"),
            Self::SsdAsRamClaim(id) => write!(f, "overlay `{id}` claimed SSD as RAM"),
            Self::ProductGreenFromResearch(id) => {
                write!(f, "overlay `{id}` promoted research to product green")
            }
            Self::MasLiveFromResearch(id) => write!(f, "overlay `{id}` leaked into MAS Live"),
            Self::MissingLayerSeparation => write!(f, "missing L1/L2/L3 separation"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
            Self::QuarantineBudgetExceeded => write!(f, "quarantine source budget exceeded"),
        }
    }
}

impl std::error::Error for ProprietaryCompressionProvenanceError {}

fn validate_gate_inputs(
    graph: &SourceSignalGraph,
    inventory: &ModelInventoryCandidateSet,
    overlays: &[ProprietaryCompressionSourceOverlay],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    route_authority_blocked: bool,
    product_promotion_blocked: bool,
    build_graph_contamination_blocked: bool,
) -> Result<(), ProprietaryCompressionProvenanceError> {
    if overlays.is_empty() {
        return Err(ProprietaryCompressionProvenanceError::EmptyOverlaySet);
    }
    if metadata_bytes > MAX_GATE_METADATA_BYTES {
        return Err(ProprietaryCompressionProvenanceError::MetadataBudgetExceeded);
    }
    if inventory.source_graph_address != graph.graph_address {
        return Err(ProprietaryCompressionProvenanceError::SourceGraphMismatch);
    }
    if *product_build != ProductBuild::Pro || *pro_status != ProStatus::ResearchCandidate {
        return Err(
            ProprietaryCompressionProvenanceError::ProductGreenFromResearch("gate".to_string()),
        );
    }
    if !l1_l2_l3_separated
        || !route_authority_blocked
        || !product_promotion_blocked
        || !build_graph_contamination_blocked
    {
        return Err(ProprietaryCompressionProvenanceError::MissingLayerSeparation);
    }

    let accepted_sources = graph
        .source_cards
        .iter()
        .map(|card| (card.source_id.as_str(), card.digest.as_str()))
        .collect::<HashMap<_, _>>();
    let rejected_sources = graph
        .rejected_source_ids
        .iter()
        .map(String::as_str)
        .collect::<HashSet<_>>();
    let inventory_candidates = inventory
        .cards
        .iter()
        .map(|card| (card.candidate_id.as_str(), card.source_id.as_str()))
        .collect::<HashMap<_, _>>();

    let mut overlay_ids = HashSet::new();
    let mut source_ids = HashSet::new();
    let mut locators = HashSet::new();

    for overlay in overlays {
        validate_overlay_common(overlay)?;
        if !overlay_ids.insert(overlay.overlay_id.as_str()) {
            return Err(ProprietaryCompressionProvenanceError::DuplicateOverlayId(
                overlay.overlay_id.clone(),
            ));
        }
        if !source_ids.insert(overlay.source_id.as_str()) {
            return Err(ProprietaryCompressionProvenanceError::DuplicateSourceId(
                overlay.source_id.clone(),
            ));
        }
        if !locators.insert(overlay.source_locator.as_str()) {
            return Err(ProprietaryCompressionProvenanceError::DuplicateLocator(
                overlay.source_locator.clone(),
            ));
        }
        if rejected_sources.contains(overlay.source_id.as_str()) {
            return Err(ProprietaryCompressionProvenanceError::BlockedSourceId(
                overlay.source_id.clone(),
            ));
        }
        let Some(expected_digest) = accepted_sources.get(overlay.source_id.as_str()) else {
            return Err(ProprietaryCompressionProvenanceError::UnknownSourceId(
                overlay.source_id.clone(),
            ));
        };
        if *expected_digest != overlay.source_digest {
            return Err(ProprietaryCompressionProvenanceError::SourceDigestMismatch(
                overlay.overlay_id.clone(),
            ));
        }
        if let Some(candidate_ref) = overlay.model_inventory_candidate_ref.as_deref() {
            let Some(source_id) = inventory_candidates.get(candidate_ref) else {
                return Err(
                    ProprietaryCompressionProvenanceError::UnknownModelInventoryCandidate(
                        candidate_ref.to_string(),
                    ),
                );
            };
            if *source_id != overlay.source_id {
                return Err(
                    ProprietaryCompressionProvenanceError::ModelInventorySourceMismatch(
                        overlay.overlay_id.clone(),
                    ),
                );
            }
        }
        validate_import_mode(overlay)?;
        validate_byte_scope(overlay)?;
        reject_forbidden_claims(overlay)?;
    }

    Ok(())
}

fn validate_overlay_common(
    overlay: &ProprietaryCompressionSourceOverlay,
) -> Result<(), ProprietaryCompressionProvenanceError> {
    for (field, value) in [
        ("overlay_id", overlay.overlay_id.as_str()),
        ("source_id", overlay.source_id.as_str()),
        ("source_digest", overlay.source_digest.as_str()),
        ("source_locator", overlay.source_locator.as_str()),
        ("observed_at_utc", overlay.observed_at_utc.as_str()),
    ] {
        validate_nonempty(field, value)?;
    }
    validate_optional_text(
        "local_test_plan_ref",
        overlay.local_test_plan_ref.as_deref(),
    )?;
    validate_optional_text("quarantine_ref", overlay.quarantine_ref.as_deref())?;
    validate_optional_text(
        "clean_room_note_ref",
        overlay.clean_room_note_ref.as_deref(),
    )?;
    validate_optional_text("attribution_ref", overlay.attribution_ref.as_deref())?;
    validate_optional_text(
        "model_inventory_candidate_ref",
        overlay.model_inventory_candidate_ref.as_deref(),
    )?;
    if overlay.product_build != ProductBuild::Pro {
        return Err(ProprietaryCompressionProvenanceError::MasLiveFromResearch(
            overlay.overlay_id.clone(),
        ));
    }
    if overlay.pro_status != ProStatus::ResearchCandidate {
        return Err(
            ProprietaryCompressionProvenanceError::ProductGreenFromResearch(
                overlay.overlay_id.clone(),
            ),
        );
    }
    if overlay.extracted_behaviors.is_empty() {
        return Err(ProprietaryCompressionProvenanceError::MissingBehavior(
            overlay.overlay_id.clone(),
        ));
    }
    let mut behavior_ids = HashSet::new();
    for behavior in &overlay.extracted_behaviors {
        validate_behavior(&overlay.overlay_id, behavior)?;
        if !behavior_ids.insert(behavior.behavior_id.as_str()) {
            return Err(ProprietaryCompressionProvenanceError::DuplicateBehaviorId(
                behavior.behavior_id.clone(),
            ));
        }
    }
    validate_proof_refs(&overlay.overlay_id, &overlay.proof_refs)?;
    Ok(())
}

fn validate_behavior(
    overlay_id: &str,
    behavior: &ProprietaryCompressionExtractedBehavior,
) -> Result<(), ProprietaryCompressionProvenanceError> {
    for (field, value) in [
        ("behavior_id", behavior.behavior_id.as_str()),
        ("summary_ref", behavior.summary_ref.as_str()),
        ("evidence_ref", behavior.evidence_ref.as_str()),
    ] {
        validate_nonempty(field, value)?;
    }
    if behavior.uses_verbatim_code {
        return Err(ProprietaryCompressionProvenanceError::VerbatimCodeUsed(
            overlay_id.to_string(),
        ));
    }
    Ok(())
}

fn validate_import_mode(
    overlay: &ProprietaryCompressionSourceOverlay,
) -> Result<(), ProprietaryCompressionProvenanceError> {
    let overlay_id = overlay.overlay_id.clone();
    if overlay.benchmark_claim_count > 0 && overlay.local_test_plan_ref.is_none() {
        return Err(
            ProprietaryCompressionProvenanceError::BenchmarkWithoutLocalTestPlan(overlay_id),
        );
    }
    if overlay.transitive_unknown_dependency_count > 0
        && matches!(
            overlay.import_mode,
            ProprietaryCompressionImportMode::DirectImport
                | ProprietaryCompressionImportMode::AdapterWrap
        )
    {
        return Err(
            ProprietaryCompressionProvenanceError::UnknownTransitiveDependency(
                overlay.overlay_id.clone(),
            ),
        );
    }

    match overlay.import_mode {
        ProprietaryCompressionImportMode::DirectImport => validate_direct_import(overlay),
        ProprietaryCompressionImportMode::AdapterWrap => validate_adapter_wrap(overlay),
        ProprietaryCompressionImportMode::QuarantineReference => {
            if overlay.quarantine_ref.is_none() {
                return Err(ProprietaryCompressionProvenanceError::MissingQuarantineRef(
                    overlay.overlay_id.clone(),
                ));
            }
            if !matches!(
                overlay.allowed_action,
                ProprietaryCompressionAllowedAction::QuarantineInspectBenchmark
                    | ProprietaryCompressionAllowedAction::NegativeFixtureOnly
            ) {
                return Err(
                    ProprietaryCompressionProvenanceError::ProductGreenFromResearch(
                        overlay.overlay_id.clone(),
                    ),
                );
            }
            Ok(())
        }
        ProprietaryCompressionImportMode::CleanRoomRewrite => {
            if overlay.clean_room_note_ref.is_none() {
                return Err(ProprietaryCompressionProvenanceError::MissingCleanRoomNote(
                    overlay.overlay_id.clone(),
                ));
            }
            if license_needs_quarantine(overlay.license_class) && overlay.quarantine_ref.is_none() {
                return Err(ProprietaryCompressionProvenanceError::MissingQuarantineRef(
                    overlay.overlay_id.clone(),
                ));
            }
            if overlay.allowed_action != ProprietaryCompressionAllowedAction::CleanRoomImplement {
                return Err(
                    ProprietaryCompressionProvenanceError::ProductGreenFromResearch(
                        overlay.overlay_id.clone(),
                    ),
                );
            }
            Ok(())
        }
        ProprietaryCompressionImportMode::ResearchOnly => {
            if license_needs_quarantine(overlay.license_class) && overlay.quarantine_ref.is_none() {
                return Err(ProprietaryCompressionProvenanceError::MissingQuarantineRef(
                    overlay.overlay_id.clone(),
                ));
            }
            if !matches!(
                overlay.allowed_action,
                ProprietaryCompressionAllowedAction::SourceCardPriorOnly
                    | ProprietaryCompressionAllowedAction::NegativeFixtureOnly
            ) {
                return Err(
                    ProprietaryCompressionProvenanceError::ProductGreenFromResearch(
                        overlay.overlay_id.clone(),
                    ),
                );
            }
            Ok(())
        }
    }
}

fn validate_direct_import(
    overlay: &ProprietaryCompressionSourceOverlay,
) -> Result<(), ProprietaryCompressionProvenanceError> {
    match overlay.license_class {
        ProprietaryCompressionLicenseClass::Permissive
        | ProprietaryCompressionLicenseClass::InternalCanon => {}
        ProprietaryCompressionLicenseClass::NoLicense => {
            return Err(
                ProprietaryCompressionProvenanceError::NoLicenseDirectImport(
                    overlay.overlay_id.clone(),
                ),
            );
        }
        ProprietaryCompressionLicenseClass::Unclear => {
            return Err(
                ProprietaryCompressionProvenanceError::UnclearLicenseDirectImport(
                    overlay.overlay_id.clone(),
                ),
            );
        }
        ProprietaryCompressionLicenseClass::Copyleft => {
            return Err(ProprietaryCompressionProvenanceError::CopyleftDirectImport(
                overlay.overlay_id.clone(),
            ));
        }
        ProprietaryCompressionLicenseClass::ResearchPaper
        | ProprietaryCompressionLicenseClass::ModelLicense => {
            return Err(
                ProprietaryCompressionProvenanceError::ProductGreenFromResearch(
                    overlay.overlay_id.clone(),
                ),
            );
        }
    }
    if overlay.allowed_action != ProprietaryCompressionAllowedAction::VendorOrAdaptWithAttribution {
        return Err(
            ProprietaryCompressionProvenanceError::ProductGreenFromResearch(
                overlay.overlay_id.clone(),
            ),
        );
    }
    if overlay.attribution_ref.is_none() {
        return Err(
            ProprietaryCompressionProvenanceError::DirectImportMissingAttribution(
                overlay.overlay_id.clone(),
            ),
        );
    }
    if overlay.local_test_plan_ref.is_none() {
        return Err(
            ProprietaryCompressionProvenanceError::DirectImportMissingTestPlan(
                overlay.overlay_id.clone(),
            ),
        );
    }
    Ok(())
}

fn validate_adapter_wrap(
    overlay: &ProprietaryCompressionSourceOverlay,
) -> Result<(), ProprietaryCompressionProvenanceError> {
    if !matches!(
        overlay.license_class,
        ProprietaryCompressionLicenseClass::Permissive
            | ProprietaryCompressionLicenseClass::ModelLicense
            | ProprietaryCompressionLicenseClass::InternalCanon
    ) {
        return Err(ProprietaryCompressionProvenanceError::UnsafeAdapterLicense(
            overlay.overlay_id.clone(),
        ));
    }
    if overlay.allowed_action != ProprietaryCompressionAllowedAction::AdapterOnly {
        return Err(
            ProprietaryCompressionProvenanceError::ProductGreenFromResearch(
                overlay.overlay_id.clone(),
            ),
        );
    }
    if overlay.local_test_plan_ref.is_none() {
        return Err(
            ProprietaryCompressionProvenanceError::AdapterMissingTestPlan(
                overlay.overlay_id.clone(),
            ),
        );
    }
    Ok(())
}

fn validate_byte_scope(
    overlay: &ProprietaryCompressionSourceOverlay,
) -> Result<(), ProprietaryCompressionProvenanceError> {
    if overlay.byte_scope.metadata_bytes_read > MAX_GATE_METADATA_BYTES {
        return Err(ProprietaryCompressionProvenanceError::MetadataBudgetExceeded);
    }
    if overlay.byte_scope.quarantine_source_bytes_inspected > MAX_QUARANTINE_SOURCE_BYTES {
        return Err(ProprietaryCompressionProvenanceError::QuarantineBudgetExceeded);
    }
    if overlay.byte_scope.copied_product_file_count > 0 {
        return Err(ProprietaryCompressionProvenanceError::ProductFileCopied(
            overlay.overlay_id.clone(),
        ));
    }
    if overlay.byte_scope.model_bytes_loaded > 0 {
        return Err(ProprietaryCompressionProvenanceError::NonzeroModelBytes(
            overlay.overlay_id.clone(),
        ));
    }
    if overlay.byte_scope.index_bytes_loaded > 0 {
        return Err(ProprietaryCompressionProvenanceError::NonzeroIndexBytes(
            overlay.overlay_id.clone(),
        ));
    }
    if overlay.byte_scope.runtime_bytes_loaded > 0 {
        return Err(ProprietaryCompressionProvenanceError::NonzeroRuntimeBytes(
            overlay.overlay_id.clone(),
        ));
    }
    if overlay.byte_scope.provider_calls_made > 0 {
        return Err(ProprietaryCompressionProvenanceError::ProviderCallMade(
            overlay.overlay_id.clone(),
        ));
    }
    Ok(())
}

fn validate_proof_refs(
    overlay_id: &str,
    proof_refs: &ProprietaryCompressionProofRefs,
) -> Result<(), ProprietaryCompressionProvenanceError> {
    for (field, value, prefix) in [
        (
            "falsifier_ref",
            proof_refs.falsifier_ref.as_str(),
            FALSIFIER_PREFIX,
        ),
        (
            "rollback_ref",
            proof_refs.rollback_ref.as_str(),
            ROLLBACK_PREFIX,
        ),
        (
            "run_event_log_ref",
            proof_refs.run_event_log_ref.as_str(),
            RUN_EVENT_LOG_PREFIX,
        ),
        (
            "answer_packet_ref",
            proof_refs.answer_packet_ref.as_str(),
            ANSWER_PACKET_PREFIX,
        ),
        (
            "compatibility_fence_ref",
            proof_refs.compatibility_fence_ref.as_str(),
            COMPATIBILITY_FENCE_PREFIX,
        ),
    ] {
        validate_nonempty(field, value).map_err(|_| {
            ProprietaryCompressionProvenanceError::MissingProofRef {
                overlay_id: overlay_id.to_string(),
                field,
            }
        })?;
        if !value.starts_with(prefix) {
            return Err(ProprietaryCompressionProvenanceError::BadProofRefPrefix {
                overlay_id: overlay_id.to_string(),
                field,
            });
        }
    }
    Ok(())
}

fn reject_forbidden_claims(
    overlay: &ProprietaryCompressionSourceOverlay,
) -> Result<(), ProprietaryCompressionProvenanceError> {
    let mut fields = vec![
        overlay.overlay_id.as_str(),
        overlay.source_id.as_str(),
        overlay.source_locator.as_str(),
        overlay.observed_at_utc.as_str(),
    ];
    fields.extend(overlay.local_test_plan_ref.as_deref());
    fields.extend(overlay.quarantine_ref.as_deref());
    fields.extend(overlay.clean_room_note_ref.as_deref());
    fields.extend(overlay.attribution_ref.as_deref());
    fields.extend(overlay.model_inventory_candidate_ref.as_deref());
    for behavior in &overlay.extracted_behaviors {
        fields.push(behavior.summary_ref.as_str());
        fields.push(behavior.evidence_ref.as_str());
    }

    for field in fields {
        let lower = field.to_ascii_lowercase();
        if lower.contains("live-dense-70b") || lower.contains("dense-70b-live") {
            return Err(ProprietaryCompressionProvenanceError::Dense70BLiveClaim(
                overlay.overlay_id.clone(),
            ));
        }
        if lower.contains("ssd-as-ram") {
            return Err(ProprietaryCompressionProvenanceError::SsdAsRamClaim(
                overlay.overlay_id.clone(),
            ));
        }
        if lower.contains("hidden-cloud") || lower.contains("cloud-fallback-default") {
            return Err(ProprietaryCompressionProvenanceError::HiddenCloudFallback(
                overlay.overlay_id.clone(),
            ));
        }
        if lower.contains("hidden-route-authority")
            || lower.contains("default-live-router")
            || lower.contains("live-router-authority")
        {
            return Err(ProprietaryCompressionProvenanceError::HiddenRouteAuthority(
                overlay.overlay_id.clone(),
            ));
        }
        if lower.contains("product-green") || lower.contains("green-product") {
            return Err(
                ProprietaryCompressionProvenanceError::ProductGreenFromResearch(
                    overlay.overlay_id.clone(),
                ),
            );
        }
    }
    Ok(())
}

fn license_needs_quarantine(license: ProprietaryCompressionLicenseClass) -> bool {
    matches!(
        license,
        ProprietaryCompressionLicenseClass::Copyleft
            | ProprietaryCompressionLicenseClass::Unclear
            | ProprietaryCompressionLicenseClass::NoLicense
    )
}

fn gate_address(
    graph_address: &UasAddress,
    inventory_address: &UasAddress,
    overlays: &[ProprietaryCompressionSourceOverlay],
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    metadata_bytes: u64,
    l1_l2_l3_separated: bool,
    route_authority_blocked: bool,
    product_promotion_blocked: bool,
    build_graph_contamination_blocked: bool,
    created_at_ms: u64,
) -> UasAddress {
    let mut preimage = String::new();
    preimage.push_str("proprietary_compression_provenance_gate_v1\n");
    preimage.push_str(&graph_address.to_string());
    preimage.push('\n');
    preimage.push_str(&inventory_address.to_string());
    preimage.push('\n');
    for overlay in overlays {
        push_overlay_preimage(&mut preimage, overlay);
    }
    preimage.push_str(product_build_preimage(product_build));
    preimage.push('\n');
    preimage.push_str(pro_status_preimage(pro_status));
    preimage.push('\n');
    preimage.push_str(&format!(
        "{metadata_bytes}:{l1_l2_l3_separated}:{route_authority_blocked}:{product_promotion_blocked}:{build_graph_contamination_blocked}\n"
    ));
    UasAddress::new(
        UasKind::Other("proprietary_compression_provenance_gate".to_string()),
        preimage.as_bytes(),
        created_at_ms,
    )
}

fn push_overlay_preimage(preimage: &mut String, overlay: &ProprietaryCompressionSourceOverlay) {
    preimage.push_str(&overlay.overlay_id);
    preimage.push('\n');
    preimage.push_str(&overlay.source_id);
    preimage.push('\n');
    preimage.push_str(&overlay.source_digest);
    preimage.push('\n');
    preimage.push_str(&format!(
        "{:?}:{:?}:{:?}:{:?}:{:?}:{}:{}:{}\n",
        overlay.source_kind,
        overlay.license_class,
        overlay.import_mode,
        overlay.allowed_action,
        overlay.product_build,
        overlay.dependency_count,
        overlay.transitive_unknown_dependency_count,
        overlay.benchmark_claim_count
    ));
    for behavior in &overlay.extracted_behaviors {
        preimage.push_str(&format!(
            "{}:{:?}:{}:{}:{}\n",
            behavior.behavior_id,
            behavior.kind,
            behavior.summary_ref,
            behavior.evidence_ref,
            behavior.uses_verbatim_code
        ));
    }
    for value in [
        overlay.source_locator.as_str(),
        overlay.observed_at_utc.as_str(),
        overlay.local_test_plan_ref.as_deref().unwrap_or(""),
        overlay.quarantine_ref.as_deref().unwrap_or(""),
        overlay.clean_room_note_ref.as_deref().unwrap_or(""),
        overlay.attribution_ref.as_deref().unwrap_or(""),
        overlay
            .model_inventory_candidate_ref
            .as_deref()
            .unwrap_or(""),
        overlay.proof_refs.falsifier_ref.as_str(),
        overlay.proof_refs.rollback_ref.as_str(),
        overlay.proof_refs.run_event_log_ref.as_str(),
        overlay.proof_refs.answer_packet_ref.as_str(),
        overlay.proof_refs.compatibility_fence_ref.as_str(),
    ] {
        preimage.push_str(value);
        preimage.push('\n');
    }
}

fn validate_nonempty(
    field: &'static str,
    value: &str,
) -> Result<(), ProprietaryCompressionProvenanceError> {
    if value.trim().is_empty() {
        return Err(ProprietaryCompressionProvenanceError::MissingField(field));
    }
    if value.trim() != value {
        return Err(ProprietaryCompressionProvenanceError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(char::is_control) {
        return Err(ProprietaryCompressionProvenanceError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

fn validate_optional_text(
    field: &'static str,
    value: Option<&str>,
) -> Result<(), ProprietaryCompressionProvenanceError> {
    if let Some(value) = value {
        validate_nonempty(field, value)?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::{
        ModelInventoryByteScope, ModelInventoryCandidateCard, ModelInventoryClaimLimit,
        ModelInventoryEvidenceKind, ModelInventoryHashClaim, ModelInventoryMetadataStatus,
        ModelInventoryProofRefs, PrivacyClass, SourceCard, SourceNoPoisonStatus, SourceSignalType,
    };

    const CREATED_AT_MS: u64 = 1_779_031_000_000;

    fn source_graph() -> SourceSignalGraph {
        SourceSignalGraph::intake(
            [
                source_card("source:repo:turbovec", SourceNoPoisonStatus::Clear),
                source_card("source:paper:turboquant", SourceNoPoisonStatus::Clear),
                source_card("source:blog:gemma4-qat", SourceNoPoisonStatus::Clear),
                source_card(
                    "source:package:litert-lm-swift",
                    SourceNoPoisonStatus::Clear,
                ),
                source_card("source:local:canon-qwen3", SourceNoPoisonStatus::Clear),
                source_card("source:fork:no-license-poc", SourceNoPoisonStatus::Clear),
                source_card("source:blocked:poison", SourceNoPoisonStatus::Blocked),
            ]
            .into_iter()
            .collect::<Result<Vec<_>, _>>()
            .expect("source cards should build"),
            Vec::new(),
            CREATED_AT_MS,
        )
        .expect("source graph should intake")
    }

    fn source_card(
        source_id: &str,
        no_poison_status: SourceNoPoisonStatus,
    ) -> Result<SourceCard, crate::uas::SemanticWorkingSetError> {
        SourceCard::new(
            source_id,
            SourceSignalType::Doc,
            format!("fixture://{source_id}"),
            digest(source_id),
            1,
            "fixture-only source card for provenance gate",
            PrivacyClass::PublicResearch,
            no_poison_status,
            vec!["proprietary_compression".to_string()],
        )
    }

    fn inventory(graph: &SourceSignalGraph) -> ModelInventoryCandidateSet {
        let cards = vec![
            inventory_card(graph, "model_candidate_qwen3", "source:local:canon-qwen3"),
            inventory_card(
                graph,
                "runtime_candidate_litert",
                "source:package:litert-lm-swift",
            ),
        ];
        ModelInventoryCandidateSet::from_source_graph(
            graph,
            cards,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            24_000,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
        .expect("inventory should validate")
    }

    fn inventory_card(
        graph: &SourceSignalGraph,
        candidate_id: &str,
        source_id: &str,
    ) -> ModelInventoryCandidateCard {
        ModelInventoryCandidateCard {
            candidate_id: candidate_id.to_string(),
            source_id: source_id.to_string(),
            source_digest: digest_for(graph, source_id),
            model_or_package_id: candidate_id.to_string(),
            evidence_kind: ModelInventoryEvidenceKind::PackageManifest,
            metadata_status: ModelInventoryMetadataStatus::DependencyProvenanceOnly,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            claim_limit: ModelInventoryClaimLimit::DependencyProvenanceOnly,
            evidence_locator: format!("fixture://inventory/{candidate_id}"),
            revision_ref: None,
            hash_claim: ModelInventoryHashClaim::None,
            loader_caveat_ref: None,
            route_hint_ref: None,
            sidecar_policy: None,
            byte_scope: ModelInventoryByteScope::metadata_only(512, 0),
            proof_refs: ModelInventoryProofRefs {
                falsifier_ref: format!("falsifier:model-inventory:{candidate_id}"),
                rollback_ref: format!("rollback:model-inventory:{candidate_id}"),
                run_event_log_ref: format!("run_event_log:model-inventory:{candidate_id}"),
                answer_packet_ref: format!("answer_packet:model-inventory:{candidate_id}"),
                compatibility_fence_ref: format!("compat:model-inventory:{candidate_id}"),
            },
            source_observed_at_utc: Some("2026-06-06T00:00:00Z".to_string()),
        }
    }

    fn overlays(graph: &SourceSignalGraph) -> Vec<ProprietaryCompressionSourceOverlay> {
        vec![
            overlay(
                graph,
                "direct_permissive_local_canon",
                "source:local:canon-qwen3",
                ProprietaryCompressionSourceKind::LocalCanon,
                ProprietaryCompressionLicenseClass::InternalCanon,
                ProprietaryCompressionImportMode::DirectImport,
                ProprietaryCompressionAllowedAction::VendorOrAdaptWithAttribution,
                Some("test-plan:local-canon"),
                None,
                None,
                Some("attribution:internal-canon"),
                Some("model_candidate_qwen3"),
            ),
            overlay(
                graph,
                "adapter_litert_model_license",
                "source:package:litert-lm-swift",
                ProprietaryCompressionSourceKind::RuntimePackage,
                ProprietaryCompressionLicenseClass::ModelLicense,
                ProprietaryCompressionImportMode::AdapterWrap,
                ProprietaryCompressionAllowedAction::AdapterOnly,
                Some("test-plan:litert-adapter"),
                None,
                None,
                None,
                Some("runtime_candidate_litert"),
            ),
            overlay(
                graph,
                "quarantine_turbovec_repo",
                "source:repo:turbovec",
                ProprietaryCompressionSourceKind::Repo,
                ProprietaryCompressionLicenseClass::Unclear,
                ProprietaryCompressionImportMode::QuarantineReference,
                ProprietaryCompressionAllowedAction::QuarantineInspectBenchmark,
                Some("test-plan:turbovec-quarantine"),
                Some("quarantine:turbovec"),
                None,
                None,
                None,
            ),
            overlay(
                graph,
                "clean_room_turboquant_math",
                "source:paper:turboquant",
                ProprietaryCompressionSourceKind::Paper,
                ProprietaryCompressionLicenseClass::ResearchPaper,
                ProprietaryCompressionImportMode::CleanRoomRewrite,
                ProprietaryCompressionAllowedAction::CleanRoomImplement,
                Some("test-plan:turboquant-math"),
                None,
                Some("clean-room:turboquant-math"),
                None,
                None,
            ),
            overlay(
                graph,
                "research_only_gemma4_qat",
                "source:blog:gemma4-qat",
                ProprietaryCompressionSourceKind::Blog,
                ProprietaryCompressionLicenseClass::ResearchPaper,
                ProprietaryCompressionImportMode::ResearchOnly,
                ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
                None,
                None,
                None,
                None,
                None,
            ),
            overlay(
                graph,
                "negative_fixture_no_license_fork",
                "source:fork:no-license-poc",
                ProprietaryCompressionSourceKind::Fork,
                ProprietaryCompressionLicenseClass::NoLicense,
                ProprietaryCompressionImportMode::ResearchOnly,
                ProprietaryCompressionAllowedAction::NegativeFixtureOnly,
                None,
                Some("quarantine:no-license-fork"),
                None,
                None,
                None,
            ),
        ]
    }

    #[allow(clippy::too_many_arguments)]
    fn overlay(
        graph: &SourceSignalGraph,
        overlay_id: &str,
        source_id: &str,
        source_kind: ProprietaryCompressionSourceKind,
        license_class: ProprietaryCompressionLicenseClass,
        import_mode: ProprietaryCompressionImportMode,
        allowed_action: ProprietaryCompressionAllowedAction,
        local_test_plan_ref: Option<&str>,
        quarantine_ref: Option<&str>,
        clean_room_note_ref: Option<&str>,
        attribution_ref: Option<&str>,
        model_inventory_candidate_ref: Option<&str>,
    ) -> ProprietaryCompressionSourceOverlay {
        ProprietaryCompressionSourceOverlay {
            overlay_id: overlay_id.to_string(),
            source_id: source_id.to_string(),
            source_digest: digest_for(graph, source_id),
            source_kind,
            source_locator: format!("fixture://provenance/{source_id}"),
            observed_at_utc: "2026-06-06T00:00:00Z".to_string(),
            license_class,
            import_mode,
            allowed_action,
            dependency_count: 3,
            transitive_unknown_dependency_count: 0,
            benchmark_claim_count: u64::from(local_test_plan_ref.is_some()),
            extracted_behaviors: vec![behavior(
                &format!("{overlay_id}:api-shape"),
                ProprietaryCompressionBehaviorKind::ApiShape,
            )],
            local_test_plan_ref: local_test_plan_ref.map(str::to_string),
            quarantine_ref: quarantine_ref.map(str::to_string),
            clean_room_note_ref: clean_room_note_ref.map(str::to_string),
            attribution_ref: attribution_ref.map(str::to_string),
            model_inventory_candidate_ref: model_inventory_candidate_ref.map(str::to_string),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            byte_scope: ProprietaryCompressionByteScope::metadata_only(512, 1024),
            proof_refs: proof_refs(overlay_id),
        }
    }

    fn behavior(
        behavior_id: &str,
        kind: ProprietaryCompressionBehaviorKind,
    ) -> ProprietaryCompressionExtractedBehavior {
        ProprietaryCompressionExtractedBehavior {
            behavior_id: behavior_id.to_string(),
            kind,
            summary_ref: format!("summary:{behavior_id}"),
            evidence_ref: format!("evidence:{behavior_id}"),
            uses_verbatim_code: false,
        }
    }

    fn proof_refs(overlay_id: &str) -> ProprietaryCompressionProofRefs {
        ProprietaryCompressionProofRefs {
            falsifier_ref: format!("falsifier:proprietary-compression:{overlay_id}"),
            rollback_ref: format!("rollback:proprietary-compression:{overlay_id}"),
            run_event_log_ref: format!("run_event_log:proprietary-compression:{overlay_id}"),
            answer_packet_ref: format!("answer_packet:proprietary-compression:{overlay_id}"),
            compatibility_fence_ref: format!("compat:proprietary-compression:{overlay_id}"),
        }
    }

    fn gate_is_err(
        graph: &SourceSignalGraph,
        inventory: &ModelInventoryCandidateSet,
        overlays: Vec<ProprietaryCompressionSourceOverlay>,
    ) -> bool {
        ProprietaryCompressionProvenanceGate::from_sources(
            graph,
            inventory,
            overlays,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            64_000,
            true,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
        .is_err()
    }

    fn digest_for(graph: &SourceSignalGraph, source_id: &str) -> String {
        graph
            .source_cards
            .iter()
            .find(|card| card.source_id == source_id)
            .map(|card| card.digest.clone())
            .unwrap_or_else(|| digest(source_id))
    }

    fn digest(seed: &str) -> String {
        format!("blake3:{}", blake3::hash(seed.as_bytes()).to_hex())
    }

    #[test]
    fn accepted_gate_is_order_stable_and_research_only() {
        let graph = source_graph();
        let inventory = inventory(&graph);
        let overlays = overlays(&graph);
        let gate = ProprietaryCompressionProvenanceGate::from_sources(
            &graph,
            &inventory,
            overlays.clone(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            64_000,
            true,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
        .expect("gate should accept safe provenance overlays");
        let reversed = ProprietaryCompressionProvenanceGate::from_sources(
            &graph,
            &inventory,
            overlays.into_iter().rev().collect(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            64_000,
            true,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
        .expect("reversed gate should accept safe provenance overlays");

        assert_eq!(gate.gate_address, reversed.gate_address);
        assert_eq!(gate.metrics().model_inventory_binding_count, 2);
        assert_eq!(gate.metrics().model_bytes_loaded, 0);
        assert_eq!(gate.metrics().runtime_bytes_loaded, 0);
    }

    #[test]
    fn rejects_no_license_direct_import() {
        let graph = source_graph();
        let inventory = inventory(&graph);
        let mut overlays = overlays(&graph);
        let overlay = overlays
            .iter_mut()
            .find(|overlay| overlay.overlay_id == "negative_fixture_no_license_fork")
            .expect("fixture present");
        overlay.import_mode = ProprietaryCompressionImportMode::DirectImport;
        overlay.allowed_action = ProprietaryCompressionAllowedAction::VendorOrAdaptWithAttribution;
        overlay.attribution_ref = Some("attribution:bad".to_string());
        overlay.local_test_plan_ref = Some("test-plan:bad".to_string());

        assert!(gate_is_err(&graph, &inventory, overlays));
    }

    #[test]
    fn rejects_benchmark_laundering_without_local_test_plan() {
        let graph = source_graph();
        let inventory = inventory(&graph);
        let mut overlays = overlays(&graph);
        overlays[0].benchmark_claim_count = 1;
        overlays[0].local_test_plan_ref = None;

        assert!(gate_is_err(&graph, &inventory, overlays));
    }

    #[test]
    fn rejects_verbatim_code_mining() {
        let graph = source_graph();
        let inventory = inventory(&graph);
        let mut overlays = overlays(&graph);
        overlays[0].extracted_behaviors[0].uses_verbatim_code = true;

        assert!(gate_is_err(&graph, &inventory, overlays));
    }

    #[test]
    fn rejects_hidden_route_authority_claim() {
        let graph = source_graph();
        let inventory = inventory(&graph);
        let mut overlays = overlays(&graph);
        overlays[0]
            .source_locator
            .push_str(":hidden-route-authority");

        assert!(gate_is_err(&graph, &inventory, overlays));
    }

    #[test]
    fn rejects_unknown_model_inventory_binding() {
        let graph = source_graph();
        let inventory = inventory(&graph);
        let mut overlays = overlays(&graph);
        overlays[0].model_inventory_candidate_ref = Some("missing-candidate".to_string());

        assert!(gate_is_err(&graph, &inventory, overlays));
    }
}
