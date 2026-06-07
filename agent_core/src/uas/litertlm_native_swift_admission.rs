//! LiteRT-LM native Swift admission card.
//!
//! This primitive source-cards Google's LiteRT-LM Swift/macOS package before
//! it can influence `RuntimeRouter` / System G. It is metadata-only: no
//! package, binary, model, runtime, provider, or server bytes are downloaded,
//! linked, loaded, or executed here.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fmt;

use crate::uas::construction_card::{pro_status_preimage, product_build_preimage};
use crate::uas::{ProStatus, ProductBuild, UasAddress, UasKind};

pub const LITERTLM_NATIVE_SWIFT_ADMISSION_CURSOR: &str = "litertlm_native_swift_admission";
pub const LITERTLM_NATIVE_SWIFT_ADMISSION_NEXT_CURSOR: &str =
    "gemma4_mtp_drafter_compatibility_card";

const HTTPS_PREFIX: &str = "https://";
const FALSIFIER_PREFIX: &str = "falsifier:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const ADMISSION_PREFIX: &str = "admission:";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const COMPATIBILITY_PREFIX: &str = "compat:";
const BINARY_PROVENANCE_PREFIX: &str = "binary_provenance:";
const MAS_PRO_PREFIX: &str = "mas_pro:";
const MAX_CARD_METADATA_BYTES: u64 = 128 * 1024;
const MAX_SET_METADATA_BYTES: u64 = 256 * 1024;

// UAS: uas:litertlm-native-swift-admission:platform
// Plane: Controller + Verification
// Residency: platform metadata only; not a product route.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LiteRtSwiftPlatform {
    Ios,
    Macos,
}

// UAS: uas:litertlm-native-swift-admission:mas-verdict
// Plane: Verification
// Residency: MAS boundary for prebuilt binaries and unsafe linker flags.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LiteRtMasVerdict {
    DeniedUntilBinaryReview,
    DeniedServerSidecar,
    RequiresSandboxReview,
    MasEligibleAfterWitness,
}

// UAS: uas:litertlm-native-swift-admission:byte-scope
// Plane: Verification
// Residency: metadata-only source-card accounting.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LiteRtSwiftByteScope {
    pub metadata_bytes_read: u64,
    pub package_bytes_downloaded: u64,
    pub binary_asset_bytes_downloaded: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub product_files_copied: u64,
}

impl LiteRtSwiftByteScope {
    pub fn metadata_only(metadata_bytes_read: u64) -> Self {
        Self {
            metadata_bytes_read,
            package_bytes_downloaded: 0,
            binary_asset_bytes_downloaded: 0,
            runtime_bytes_loaded: 0,
            model_bytes_loaded: 0,
            provider_calls_made: 0,
            product_files_copied: 0,
        }
    }
}

// UAS: uas:litertlm-native-swift-admission:binary-target
// Plane: Verification
// Residency: source-carded binary target; zip is not fetched here.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LiteRtSwiftBinaryTarget {
    pub name: String,
    pub platform: LiteRtSwiftPlatform,
    pub url: String,
    pub checksum: String,
    pub release_tag: String,
    pub declared_asset_bytes: u64,
}

// UAS: uas:litertlm-native-swift-admission:proof-refs
// Plane: Verification
// Residency: visible proof handles before downstream route influence.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LiteRtSwiftAdmissionProofRefs {
    pub falsifier_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub admission_ref: String,
    pub scope_rex_ref: String,
    pub sovereign_gate_ref: String,
    pub compatibility_fence_ref: String,
    pub binary_provenance_ref: String,
    pub mas_pro_boundary_ref: String,
}

// UAS: uas:litertlm-native-swift-admission:card
// Plane: State + Controller + Verification
// Residency: metadata-only admission card for LiteRT-LM Swift/macOS.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LiteRtNativeSwiftAdmissionCard {
    pub card_id: String,
    pub repo_url: String,
    pub package_url: String,
    pub swift_doc_url: String,
    pub release_url: String,
    pub license_spdx: String,
    pub release_tag: String,
    pub repo_pushed_at: String,
    pub binary_targets: Vec<LiteRtSwiftBinaryTarget>,
    pub unsafe_linker_flags: Vec<String>,
    pub swift_package_signal: bool,
    pub native_macos_signal: bool,
    pub metal_gpu_signal: bool,
    pub tool_use_signal: bool,
    pub multimodal_signal: bool,
    pub openai_server_signal: bool,
    pub server_sidecar_default_denied: bool,
    pub prebuilt_binary_review_required: bool,
    pub unsafe_linker_review_required: bool,
    pub cancellation_witness_required: bool,
    pub tool_schema_witness_required: bool,
    pub answer_packet_witness_required: bool,
    pub rollback_witness_required: bool,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub mas_verdict: LiteRtMasVerdict,
    pub byte_scope: LiteRtSwiftByteScope,
    pub proof_refs: LiteRtSwiftAdmissionProofRefs,
    pub product_dependency_imported: bool,
    pub package_resolved: bool,
    pub binary_downloaded: bool,
    pub runtime_loaded: bool,
    pub model_loaded: bool,
    pub l2_l3_promotion_claim: bool,
    pub live_dense_70b_claim: bool,
    pub hidden_route_authority: bool,
}

// UAS: uas:litertlm-native-swift-admission:set
// Plane: State + Controller + Verification
// Residency: metadata-only admission set; feeds MTP and lane-tournament gates.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LiteRtNativeSwiftAdmissionSet {
    pub set_address: UasAddress,
    pub cards: Vec<LiteRtNativeSwiftAdmissionCard>,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub mas_default_denied: bool,
    pub product_import_blocked: bool,
    pub server_sidecar_blocked: bool,
    pub hidden_authority_blocked: bool,
    pub product_promotion_blocked: bool,
}

// UAS: uas:litertlm-native-swift-admission:metrics
// Plane: Verification
// Residency: derived counters for falsifier axes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LiteRtNativeSwiftAdmissionMetrics {
    pub card_count: u64,
    pub binary_target_count: u64,
    pub platform_count: u64,
    pub unsafe_linker_flag_count: u64,
    pub declared_binary_asset_bytes: u64,
    pub metadata_bytes_read: u64,
    pub package_bytes_downloaded: u64,
    pub binary_asset_bytes_downloaded: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub product_files_copied: u64,
    pub product_dependency_imported_count: u64,
    pub package_resolved_count: u64,
    pub binary_downloaded_count: u64,
    pub runtime_loaded_count: u64,
    pub model_loaded_count: u64,
    pub l2_l3_promotion_claim_count: u64,
    pub live_dense_70b_claim_count: u64,
    pub hidden_route_authority_count: u64,
}

impl LiteRtNativeSwiftAdmissionSet {
    pub fn new(
        mut cards: Vec<LiteRtNativeSwiftAdmissionCard>,
        metadata_bytes: u64,
        created_at_ms: u64,
    ) -> Result<Self, LiteRtNativeSwiftAdmissionError> {
        validate_cards(&cards, metadata_bytes)?;
        cards.sort_by(|a, b| a.card_id.cmp(&b.card_id));
        let preimage = set_preimage(&cards, metadata_bytes);
        Ok(Self {
            set_address: UasAddress::new(
                UasKind::Other("litertlm_native_swift_admission".to_string()),
                preimage.as_bytes(),
                created_at_ms,
            ),
            cards,
            metadata_bytes,
            l1_l2_l3_separated: true,
            mas_default_denied: true,
            product_import_blocked: true,
            server_sidecar_blocked: true,
            hidden_authority_blocked: true,
            product_promotion_blocked: true,
        })
    }

    pub fn metrics(&self) -> LiteRtNativeSwiftAdmissionMetrics {
        let mut platforms = HashSet::new();
        let mut binary_target_count = 0_u64;
        let mut unsafe_linker_flag_count = 0_u64;
        let mut declared_binary_asset_bytes = 0_u64;
        let mut metadata_bytes_read = 0_u64;
        let mut package_bytes_downloaded = 0_u64;
        let mut binary_asset_bytes_downloaded = 0_u64;
        let mut runtime_bytes_loaded = 0_u64;
        let mut model_bytes_loaded = 0_u64;
        let mut provider_calls_made = 0_u64;
        let mut product_files_copied = 0_u64;
        let mut product_dependency_imported_count = 0_u64;
        let mut package_resolved_count = 0_u64;
        let mut binary_downloaded_count = 0_u64;
        let mut runtime_loaded_count = 0_u64;
        let mut model_loaded_count = 0_u64;
        let mut l2_l3_promotion_claim_count = 0_u64;
        let mut live_dense_70b_claim_count = 0_u64;
        let mut hidden_route_authority_count = 0_u64;

        for card in &self.cards {
            binary_target_count += card.binary_targets.len() as u64;
            unsafe_linker_flag_count += card.unsafe_linker_flags.len() as u64;
            metadata_bytes_read += card.byte_scope.metadata_bytes_read;
            package_bytes_downloaded += card.byte_scope.package_bytes_downloaded;
            binary_asset_bytes_downloaded += card.byte_scope.binary_asset_bytes_downloaded;
            runtime_bytes_loaded += card.byte_scope.runtime_bytes_loaded;
            model_bytes_loaded += card.byte_scope.model_bytes_loaded;
            provider_calls_made += card.byte_scope.provider_calls_made;
            product_files_copied += card.byte_scope.product_files_copied;
            product_dependency_imported_count += card.product_dependency_imported as u64;
            package_resolved_count += card.package_resolved as u64;
            binary_downloaded_count += card.binary_downloaded as u64;
            runtime_loaded_count += card.runtime_loaded as u64;
            model_loaded_count += card.model_loaded as u64;
            l2_l3_promotion_claim_count += card.l2_l3_promotion_claim as u64;
            live_dense_70b_claim_count += card.live_dense_70b_claim as u64;
            hidden_route_authority_count += card.hidden_route_authority as u64;
            for target in &card.binary_targets {
                platforms.insert(target.platform);
                declared_binary_asset_bytes += target.declared_asset_bytes;
            }
        }

        LiteRtNativeSwiftAdmissionMetrics {
            card_count: self.cards.len() as u64,
            binary_target_count,
            platform_count: platforms.len() as u64,
            unsafe_linker_flag_count,
            declared_binary_asset_bytes,
            metadata_bytes_read,
            package_bytes_downloaded,
            binary_asset_bytes_downloaded,
            runtime_bytes_loaded,
            model_bytes_loaded,
            provider_calls_made,
            product_files_copied,
            product_dependency_imported_count,
            package_resolved_count,
            binary_downloaded_count,
            runtime_loaded_count,
            model_loaded_count,
            l2_l3_promotion_claim_count,
            live_dense_70b_claim_count,
            hidden_route_authority_count,
        }
    }
}

// UAS: uas:litertlm-native-swift-admission:error
// Plane: Verification
// Residency: fail-closed admission validation diagnostics.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum LiteRtNativeSwiftAdmissionError {
    EmptyCardSet,
    MetadataBudgetExceeded,
    DuplicateCardId(String),
    MissingField(&'static str),
    FieldWhitespace(&'static str),
    NonHttpsUrl(String),
    UnsupportedLicense(String),
    MissingIosBinaryTarget,
    MissingMacosBinaryTarget,
    DuplicateBinaryTarget(String),
    BadBinaryChecksum(String),
    BadReleaseTag(String),
    MissingDeclaredAssetBytes(String),
    MissingUnsafeLinkerFlag,
    UnsafeLinkerReviewMissing,
    PrebuiltBinaryReviewMissing,
    MasNotDeniedUntilReview,
    ServerSidecarNotDenied,
    ProductBuildNotPro,
    ProStatusNotResearchCandidate,
    MissingCancellationWitness,
    MissingToolSchemaWitness,
    MissingAnswerPacketWitness,
    MissingRollbackWitness,
    BadProofRefPrefix(&'static str),
    ProductDependencyImported,
    PackageResolved,
    BinaryDownloaded,
    RuntimeLoaded,
    ModelLoaded,
    PackageBytesDownloaded,
    BinaryAssetBytesDownloaded,
    RuntimeBytesLoaded,
    ModelBytesLoaded,
    ProviderCallMade,
    ProductFileCopied,
    L2L3PromotionClaim,
    LiveDense70BClaim,
    HiddenRouteAuthority,
}

impl fmt::Display for LiteRtNativeSwiftAdmissionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyCardSet => write!(f, "LiteRT admission card set is empty"),
            Self::MetadataBudgetExceeded => write!(f, "LiteRT admission metadata budget exceeded"),
            Self::DuplicateCardId(id) => write!(f, "duplicate LiteRT admission card id `{id}`"),
            Self::MissingField(field) => write!(f, "missing required field `{field}`"),
            Self::FieldWhitespace(field) => write!(f, "field `{field}` has surrounding whitespace"),
            Self::NonHttpsUrl(url) => write!(f, "URL `{url}` must use https"),
            Self::UnsupportedLicense(license) => write!(f, "unsupported license `{license}`"),
            Self::MissingIosBinaryTarget => write!(f, "missing iOS binary target"),
            Self::MissingMacosBinaryTarget => write!(f, "missing macOS binary target"),
            Self::DuplicateBinaryTarget(name) => write!(f, "duplicate binary target `{name}`"),
            Self::BadBinaryChecksum(name) => write!(f, "binary target `{name}` has bad checksum"),
            Self::BadReleaseTag(tag) => write!(f, "bad release tag `{tag}`"),
            Self::MissingDeclaredAssetBytes(name) => {
                write!(f, "binary target `{name}` is missing declared asset bytes")
            }
            Self::MissingUnsafeLinkerFlag => write!(f, "unsafe linker flag was not source-carded"),
            Self::UnsafeLinkerReviewMissing => write!(f, "unsafe linker review was not required"),
            Self::PrebuiltBinaryReviewMissing => {
                write!(f, "prebuilt binary review was not required")
            }
            Self::MasNotDeniedUntilReview => write!(f, "MAS verdict must deny until binary review"),
            Self::ServerSidecarNotDenied => write!(
                f,
                "OpenAI-compatible server sidecar was not denied by default"
            ),
            Self::ProductBuildNotPro => {
                write!(f, "LiteRT admission card must stay in Pro build scope")
            }
            Self::ProStatusNotResearchCandidate => {
                write!(f, "LiteRT admission card must stay Pro ResearchCandidate")
            }
            Self::MissingCancellationWitness => {
                write!(f, "missing cancellation witness requirement")
            }
            Self::MissingToolSchemaWitness => write!(f, "missing tool-schema witness requirement"),
            Self::MissingAnswerPacketWitness => {
                write!(f, "missing AnswerPacket witness requirement")
            }
            Self::MissingRollbackWitness => write!(f, "missing rollback witness requirement"),
            Self::BadProofRefPrefix(field) => write!(f, "bad proof ref prefix for `{field}`"),
            Self::ProductDependencyImported => write!(f, "LiteRT product dependency was imported"),
            Self::PackageResolved => write!(f, "LiteRT package was resolved"),
            Self::BinaryDownloaded => write!(f, "LiteRT binary was downloaded"),
            Self::RuntimeLoaded => write!(f, "LiteRT runtime was loaded"),
            Self::ModelLoaded => write!(f, "LiteRT model was loaded"),
            Self::PackageBytesDownloaded => write!(f, "package bytes were downloaded"),
            Self::BinaryAssetBytesDownloaded => write!(f, "binary asset bytes were downloaded"),
            Self::RuntimeBytesLoaded => write!(f, "runtime bytes were loaded"),
            Self::ModelBytesLoaded => write!(f, "model bytes were loaded"),
            Self::ProviderCallMade => write!(f, "provider call was made"),
            Self::ProductFileCopied => write!(f, "product file was copied"),
            Self::L2L3PromotionClaim => write!(f, "L2/L3 promotion was claimed"),
            Self::LiveDense70BClaim => write!(f, "live dense 70B was claimed"),
            Self::HiddenRouteAuthority => write!(f, "hidden route authority was claimed"),
        }
    }
}

impl std::error::Error for LiteRtNativeSwiftAdmissionError {}

fn validate_cards(
    cards: &[LiteRtNativeSwiftAdmissionCard],
    metadata_bytes: u64,
) -> Result<(), LiteRtNativeSwiftAdmissionError> {
    if cards.is_empty() {
        return Err(LiteRtNativeSwiftAdmissionError::EmptyCardSet);
    }
    if metadata_bytes == 0 || metadata_bytes > MAX_SET_METADATA_BYTES {
        return Err(LiteRtNativeSwiftAdmissionError::MetadataBudgetExceeded);
    }

    let mut card_ids = HashSet::new();
    for card in cards {
        if !card_ids.insert(card.card_id.clone()) {
            return Err(LiteRtNativeSwiftAdmissionError::DuplicateCardId(
                card.card_id.clone(),
            ));
        }
        validate_card(card)?;
    }
    Ok(())
}

fn validate_card(
    card: &LiteRtNativeSwiftAdmissionCard,
) -> Result<(), LiteRtNativeSwiftAdmissionError> {
    required(&card.card_id, "card_id")?;
    required(&card.repo_url, "repo_url")?;
    required(&card.package_url, "package_url")?;
    required(&card.swift_doc_url, "swift_doc_url")?;
    required(&card.release_url, "release_url")?;
    required(&card.license_spdx, "license_spdx")?;
    required(&card.release_tag, "release_tag")?;
    required(&card.repo_pushed_at, "repo_pushed_at")?;
    for url in [
        &card.repo_url,
        &card.package_url,
        &card.swift_doc_url,
        &card.release_url,
    ] {
        require_https(url)?;
    }
    if card.license_spdx != "Apache-2.0" {
        return Err(LiteRtNativeSwiftAdmissionError::UnsupportedLicense(
            card.license_spdx.clone(),
        ));
    }
    if !card.release_tag.starts_with('v') || !card.release_tag[1..].contains('.') {
        return Err(LiteRtNativeSwiftAdmissionError::BadReleaseTag(
            card.release_tag.clone(),
        ));
    }
    if card.byte_scope.metadata_bytes_read == 0
        || card.byte_scope.metadata_bytes_read > MAX_CARD_METADATA_BYTES
    {
        return Err(LiteRtNativeSwiftAdmissionError::MetadataBudgetExceeded);
    }

    validate_binary_targets(&card.binary_targets)?;
    if card.unsafe_linker_flags.is_empty() {
        return Err(LiteRtNativeSwiftAdmissionError::MissingUnsafeLinkerFlag);
    }
    if !card.unsafe_linker_review_required {
        return Err(LiteRtNativeSwiftAdmissionError::UnsafeLinkerReviewMissing);
    }
    if !card.prebuilt_binary_review_required {
        return Err(LiteRtNativeSwiftAdmissionError::PrebuiltBinaryReviewMissing);
    }
    if card.mas_verdict != LiteRtMasVerdict::DeniedUntilBinaryReview {
        return Err(LiteRtNativeSwiftAdmissionError::MasNotDeniedUntilReview);
    }
    if !card.server_sidecar_default_denied {
        return Err(LiteRtNativeSwiftAdmissionError::ServerSidecarNotDenied);
    }
    if card.product_build != ProductBuild::Pro {
        return Err(LiteRtNativeSwiftAdmissionError::ProductBuildNotPro);
    }
    if card.pro_status != ProStatus::ResearchCandidate {
        return Err(LiteRtNativeSwiftAdmissionError::ProStatusNotResearchCandidate);
    }
    if !card.cancellation_witness_required {
        return Err(LiteRtNativeSwiftAdmissionError::MissingCancellationWitness);
    }
    if !card.tool_schema_witness_required {
        return Err(LiteRtNativeSwiftAdmissionError::MissingToolSchemaWitness);
    }
    if !card.answer_packet_witness_required {
        return Err(LiteRtNativeSwiftAdmissionError::MissingAnswerPacketWitness);
    }
    if !card.rollback_witness_required {
        return Err(LiteRtNativeSwiftAdmissionError::MissingRollbackWitness);
    }
    validate_proof_refs(&card.proof_refs)?;
    validate_zero_scope(card)?;
    Ok(())
}

fn validate_binary_targets(
    targets: &[LiteRtSwiftBinaryTarget],
) -> Result<(), LiteRtNativeSwiftAdmissionError> {
    let mut names = HashSet::new();
    let mut has_ios = false;
    let mut has_macos = false;
    for target in targets {
        required(&target.name, "binary_target.name")?;
        required(&target.url, "binary_target.url")?;
        required(&target.checksum, "binary_target.checksum")?;
        required(&target.release_tag, "binary_target.release_tag")?;
        require_https(&target.url)?;
        if !names.insert(target.name.clone()) {
            return Err(LiteRtNativeSwiftAdmissionError::DuplicateBinaryTarget(
                target.name.clone(),
            ));
        }
        if target.checksum.len() != 64 || !target.checksum.chars().all(|ch| ch.is_ascii_hexdigit())
        {
            return Err(LiteRtNativeSwiftAdmissionError::BadBinaryChecksum(
                target.name.clone(),
            ));
        }
        if !target.release_tag.starts_with('v') {
            return Err(LiteRtNativeSwiftAdmissionError::BadReleaseTag(
                target.release_tag.clone(),
            ));
        }
        if target.declared_asset_bytes == 0 {
            return Err(LiteRtNativeSwiftAdmissionError::MissingDeclaredAssetBytes(
                target.name.clone(),
            ));
        }
        match target.platform {
            LiteRtSwiftPlatform::Ios => has_ios = true,
            LiteRtSwiftPlatform::Macos => has_macos = true,
        }
    }
    if !has_ios {
        return Err(LiteRtNativeSwiftAdmissionError::MissingIosBinaryTarget);
    }
    if !has_macos {
        return Err(LiteRtNativeSwiftAdmissionError::MissingMacosBinaryTarget);
    }
    Ok(())
}

fn validate_proof_refs(
    refs: &LiteRtSwiftAdmissionProofRefs,
) -> Result<(), LiteRtNativeSwiftAdmissionError> {
    for (field, value, prefix) in [
        ("falsifier_ref", &refs.falsifier_ref, FALSIFIER_PREFIX),
        ("rollback_ref", &refs.rollback_ref, ROLLBACK_PREFIX),
        (
            "run_event_log_ref",
            &refs.run_event_log_ref,
            RUN_EVENT_LOG_PREFIX,
        ),
        (
            "answer_packet_ref",
            &refs.answer_packet_ref,
            ANSWER_PACKET_PREFIX,
        ),
        ("admission_ref", &refs.admission_ref, ADMISSION_PREFIX),
        ("scope_rex_ref", &refs.scope_rex_ref, SCOPE_REX_PREFIX),
        (
            "sovereign_gate_ref",
            &refs.sovereign_gate_ref,
            SOVEREIGN_GATE_PREFIX,
        ),
        (
            "compatibility_fence_ref",
            &refs.compatibility_fence_ref,
            COMPATIBILITY_PREFIX,
        ),
        (
            "binary_provenance_ref",
            &refs.binary_provenance_ref,
            BINARY_PROVENANCE_PREFIX,
        ),
        (
            "mas_pro_boundary_ref",
            &refs.mas_pro_boundary_ref,
            MAS_PRO_PREFIX,
        ),
    ] {
        required(value, field)?;
        if !value.starts_with(prefix) {
            return Err(LiteRtNativeSwiftAdmissionError::BadProofRefPrefix(field));
        }
    }
    Ok(())
}

fn validate_zero_scope(
    card: &LiteRtNativeSwiftAdmissionCard,
) -> Result<(), LiteRtNativeSwiftAdmissionError> {
    if card.product_dependency_imported {
        return Err(LiteRtNativeSwiftAdmissionError::ProductDependencyImported);
    }
    if card.package_resolved {
        return Err(LiteRtNativeSwiftAdmissionError::PackageResolved);
    }
    if card.binary_downloaded {
        return Err(LiteRtNativeSwiftAdmissionError::BinaryDownloaded);
    }
    if card.runtime_loaded {
        return Err(LiteRtNativeSwiftAdmissionError::RuntimeLoaded);
    }
    if card.model_loaded {
        return Err(LiteRtNativeSwiftAdmissionError::ModelLoaded);
    }
    if card.byte_scope.package_bytes_downloaded != 0 {
        return Err(LiteRtNativeSwiftAdmissionError::PackageBytesDownloaded);
    }
    if card.byte_scope.binary_asset_bytes_downloaded != 0 {
        return Err(LiteRtNativeSwiftAdmissionError::BinaryAssetBytesDownloaded);
    }
    if card.byte_scope.runtime_bytes_loaded != 0 {
        return Err(LiteRtNativeSwiftAdmissionError::RuntimeBytesLoaded);
    }
    if card.byte_scope.model_bytes_loaded != 0 {
        return Err(LiteRtNativeSwiftAdmissionError::ModelBytesLoaded);
    }
    if card.byte_scope.provider_calls_made != 0 {
        return Err(LiteRtNativeSwiftAdmissionError::ProviderCallMade);
    }
    if card.byte_scope.product_files_copied != 0 {
        return Err(LiteRtNativeSwiftAdmissionError::ProductFileCopied);
    }
    if card.l2_l3_promotion_claim {
        return Err(LiteRtNativeSwiftAdmissionError::L2L3PromotionClaim);
    }
    if card.live_dense_70b_claim {
        return Err(LiteRtNativeSwiftAdmissionError::LiveDense70BClaim);
    }
    if card.hidden_route_authority {
        return Err(LiteRtNativeSwiftAdmissionError::HiddenRouteAuthority);
    }
    Ok(())
}

fn required(value: &str, field: &'static str) -> Result<(), LiteRtNativeSwiftAdmissionError> {
    if value.is_empty() {
        return Err(LiteRtNativeSwiftAdmissionError::MissingField(field));
    }
    if value.trim() != value {
        return Err(LiteRtNativeSwiftAdmissionError::FieldWhitespace(field));
    }
    Ok(())
}

fn require_https(url: &str) -> Result<(), LiteRtNativeSwiftAdmissionError> {
    if !url.starts_with(HTTPS_PREFIX) {
        return Err(LiteRtNativeSwiftAdmissionError::NonHttpsUrl(
            url.to_string(),
        ));
    }
    Ok(())
}

fn set_preimage(cards: &[LiteRtNativeSwiftAdmissionCard], metadata_bytes: u64) -> String {
    let mut preimage = format!("metadata_bytes={metadata_bytes}|");
    for card in cards {
        preimage.push_str(&card.card_id);
        preimage.push('|');
        preimage.push_str(&card.package_url);
        preimage.push('|');
        preimage.push_str(&card.release_tag);
        preimage.push('|');
        preimage.push_str(product_build_preimage(&card.product_build));
        preimage.push('|');
        preimage.push_str(pro_status_preimage(&card.pro_status));
        preimage.push('|');
        for target in &card.binary_targets {
            preimage.push_str(&target.name);
            preimage.push(':');
            preimage.push_str(&target.checksum);
            preimage.push(':');
            preimage.push_str(&target.declared_asset_bytes.to_string());
            preimage.push('|');
        }
    }
    preimage
}

#[cfg(test)]
mod tests {
    use super::*;

    fn accepted_card() -> LiteRtNativeSwiftAdmissionCard {
        LiteRtNativeSwiftAdmissionCard {
            card_id: "litertlm_v0_13_1_swift_package_admission".to_string(),
            repo_url: "https://github.com/google-ai-edge/LiteRT-LM".to_string(),
            package_url: "https://github.com/google-ai-edge/LiteRT-LM/blob/main/Package.swift"
                .to_string(),
            swift_doc_url: "https://ai.google.dev/edge/litert-lm/swift".to_string(),
            release_url: "https://github.com/google-ai-edge/LiteRT-LM/releases/tag/v0.13.1"
                .to_string(),
            license_spdx: "Apache-2.0".to_string(),
            release_tag: "v0.13.1".to_string(),
            repo_pushed_at: "2026-06-06T04:28:05Z".to_string(),
            binary_targets: vec![
                LiteRtSwiftBinaryTarget {
                    name: "CLiteRTLM".to_string(),
                    platform: LiteRtSwiftPlatform::Ios,
                    url: "https://github.com/google-ai-edge/LiteRT-LM/releases/download/v0.13.1/CLiteRTLM.xcframework.zip".to_string(),
                    checksum: "7ff01c42106b754748b5dd3036a4a57161b25ebf523e705bebc1219061852362".to_string(),
                    release_tag: "v0.13.1".to_string(),
                    declared_asset_bytes: 80_754_584,
                },
                LiteRtSwiftBinaryTarget {
                    name: "CLiteRTLM_mac".to_string(),
                    platform: LiteRtSwiftPlatform::Macos,
                    url: "https://github.com/google-ai-edge/LiteRT-LM/releases/download/v0.13.1/CLiteRTLM_mac.xcframework.zip".to_string(),
                    checksum: "ec9ffe230dc39117a7fc8933b1cc15910454027fee6d3041534ab7cf17313981".to_string(),
                    release_tag: "v0.13.1".to_string(),
                    declared_asset_bytes: 42_920_515,
                },
            ],
            unsafe_linker_flags: vec!["-Xlinker".to_string(), "-all_load".to_string()],
            swift_package_signal: true,
            native_macos_signal: true,
            metal_gpu_signal: true,
            tool_use_signal: true,
            multimodal_signal: true,
            openai_server_signal: true,
            server_sidecar_default_denied: true,
            prebuilt_binary_review_required: true,
            unsafe_linker_review_required: true,
            cancellation_witness_required: true,
            tool_schema_witness_required: true,
            answer_packet_witness_required: true,
            rollback_witness_required: true,
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::ResearchCandidate,
            mas_verdict: LiteRtMasVerdict::DeniedUntilBinaryReview,
            byte_scope: LiteRtSwiftByteScope::metadata_only(64_000),
            proof_refs: LiteRtSwiftAdmissionProofRefs {
                falsifier_ref: "falsifier:F-LiteRTLM-NativeSwiftAdmission".to_string(),
                rollback_ref: "rollback:litertlm-admission-default-off".to_string(),
                run_event_log_ref: "run_event_log:litertlm-admission-source-card".to_string(),
                answer_packet_ref: "answer_packet:litertlm-admission-visible-caveat".to_string(),
                admission_ref: "admission:scope-rex-litertlm-native-swift".to_string(),
                scope_rex_ref: "scope_rex:litertlm-native-swift-deny-by-default".to_string(),
                sovereign_gate_ref: "sovereign_gate:litertlm-mas-pro-boundary".to_string(),
                compatibility_fence_ref: "compat:litertlm-v0-13-1-swift-package".to_string(),
                binary_provenance_ref: "binary_provenance:litertlm-v0-13-1-xcframeworks".to_string(),
                mas_pro_boundary_ref: "mas_pro:litertlm-pro-research-only".to_string(),
            },
            product_dependency_imported: false,
            package_resolved: false,
            binary_downloaded: false,
            runtime_loaded: false,
            model_loaded: false,
            l2_l3_promotion_claim: false,
            live_dense_70b_claim: false,
            hidden_route_authority: false,
        }
    }

    #[test]
    fn accepted_card_builds_metadata_only_set() {
        let set = LiteRtNativeSwiftAdmissionSet::new(vec![accepted_card()], 80_000, 1).unwrap();
        let metrics = set.metrics();
        assert_eq!(metrics.card_count, 1);
        assert_eq!(metrics.binary_target_count, 2);
        assert_eq!(metrics.platform_count, 2);
        assert_eq!(metrics.runtime_bytes_loaded, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert!(set.mas_default_denied);
    }

    #[test]
    fn missing_macos_binary_target_rejects() {
        let mut card = accepted_card();
        card.binary_targets
            .retain(|target| target.platform != LiteRtSwiftPlatform::Macos);
        let err = LiteRtNativeSwiftAdmissionSet::new(vec![card], 80_000, 1).unwrap_err();
        assert_eq!(
            err,
            LiteRtNativeSwiftAdmissionError::MissingMacosBinaryTarget
        );
    }

    #[test]
    fn unsafe_linker_review_is_required() {
        let mut card = accepted_card();
        card.unsafe_linker_review_required = false;
        let err = LiteRtNativeSwiftAdmissionSet::new(vec![card], 80_000, 1).unwrap_err();
        assert_eq!(
            err,
            LiteRtNativeSwiftAdmissionError::UnsafeLinkerReviewMissing
        );
    }

    #[test]
    fn mas_live_promotion_rejects() {
        let mut card = accepted_card();
        card.product_build = ProductBuild::Mas;
        let err = LiteRtNativeSwiftAdmissionSet::new(vec![card], 80_000, 1).unwrap_err();
        assert_eq!(err, LiteRtNativeSwiftAdmissionError::ProductBuildNotPro);
    }

    #[test]
    fn runtime_bytes_reject() {
        let mut card = accepted_card();
        card.byte_scope.runtime_bytes_loaded = 1;
        let err = LiteRtNativeSwiftAdmissionSet::new(vec![card], 80_000, 1).unwrap_err();
        assert_eq!(err, LiteRtNativeSwiftAdmissionError::RuntimeBytesLoaded);
    }
}
