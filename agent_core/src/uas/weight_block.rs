//! Weight-block manifest for the addressable neural substrate.
//!
//! This is the first source-level ABI for the AetherLink/OAS intake:
//! model bytes on SSD become UAS-addressed substrate objects before any
//! 65K/128K/70B runtime probe is allowed to touch Metal/MLX.
//!
//! Scope guard: this describes and validates model-file byte ranges. It does
//! not decode weights, run inference, or prove the 70B route.

use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use std::io::{Read, Seek, SeekFrom};

use crate::uas::{ResidencyTier, UasAddress, UasKind};

pub const GIB: u64 = 1024 * 1024 * 1024;
pub const RANGE_HASH_CHUNK_BYTES: usize = 64 * 1024;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct ByteRange {
    pub start: u64,
    pub len: u64,
}

impl ByteRange {
    pub fn new(start: u64, len: u64) -> Result<Self, WeightBlockManifestError> {
        if len == 0 {
            return Err(WeightBlockManifestError::EmptyByteRange);
        }
        start
            .checked_add(len)
            .ok_or(WeightBlockManifestError::ByteRangeOverflow)?;
        Ok(Self { start, len })
    }

    pub fn end_exclusive(&self) -> u64 {
        self.start + self.len
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum WeightBlockEncoding {
    DenseFp16,
    DenseBf16,
    DenseFp32,
    Int8,
    FourBit,
    Nf4,
    Ternary,
    Sherry125,
    LeechVq,
    ResidualIsland,
    Other(String),
}

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum WeightBlockIrChart {
    Eml,
    Geometry,
    Scan,
    Operator,
    Info,
    Tropical,
    OpaqueWithWitness,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum WeightBlockResidencyClass {
    HotUma,
    WarmCompressedUma,
    ColdMmapSsd,
    ExternalCandidate,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct WeightBlockManifest {
    pub model_id: String,
    pub source_uri: String,
    pub byte_range: ByteRange,
    pub content_hash_hex: String,
    pub uas_address: UasAddress,
    pub encoding: WeightBlockEncoding,
    pub residency_class: WeightBlockResidencyClass,
    pub residency_tier: ResidencyTier,
    pub ir_chart: WeightBlockIrChart,
    pub wbo_budget_nats: f32,
    pub verifier: String,
    pub rollback_reference: Option<UasAddress>,
}

impl WeightBlockManifest {
    #[allow(clippy::too_many_arguments)]
    pub fn from_bytes(
        model_id: impl Into<String>,
        source_uri: impl Into<String>,
        byte_start: u64,
        bytes: &[u8],
        created_at_ms: u64,
        encoding: WeightBlockEncoding,
        residency_class: WeightBlockResidencyClass,
        ir_chart: WeightBlockIrChart,
        wbo_budget_nats: f32,
        verifier: impl Into<String>,
        rollback_reference: Option<UasAddress>,
    ) -> Result<Self, WeightBlockManifestError> {
        let model_id = model_id.into();
        let source_uri = source_uri.into();
        let verifier = verifier.into();
        Self::validate_fields(&model_id, &source_uri, &verifier, wbo_budget_nats)?;
        let byte_range = ByteRange::new(byte_start, bytes.len() as u64)?;
        let hash = blake3::hash(bytes);
        Self::from_validated_hash(
            model_id,
            source_uri,
            byte_range,
            hash,
            created_at_ms,
            encoding,
            residency_class,
            ir_chart,
            wbo_budget_nats,
            verifier,
            rollback_reference,
        )
    }

    #[allow(clippy::too_many_arguments)]
    pub fn from_known_hash_hex(
        model_id: impl Into<String>,
        source_uri: impl Into<String>,
        byte_start: u64,
        byte_len: u64,
        content_hash_hex: impl AsRef<str>,
        created_at_ms: u64,
        encoding: WeightBlockEncoding,
        residency_class: WeightBlockResidencyClass,
        ir_chart: WeightBlockIrChart,
        wbo_budget_nats: f32,
        verifier: impl Into<String>,
        rollback_reference: Option<UasAddress>,
    ) -> Result<Self, WeightBlockManifestError> {
        let model_id = model_id.into();
        let source_uri = source_uri.into();
        let verifier = verifier.into();
        Self::validate_fields(&model_id, &source_uri, &verifier, wbo_budget_nats)?;
        let byte_range = ByteRange::new(byte_start, byte_len)?;
        let hash = blake3::Hash::from_hex(content_hash_hex.as_ref())
            .map_err(|_| WeightBlockManifestError::InvalidContentHash)?;
        Self::from_validated_hash(
            model_id,
            source_uri,
            byte_range,
            hash,
            created_at_ms,
            encoding,
            residency_class,
            ir_chart,
            wbo_budget_nats,
            verifier,
            rollback_reference,
        )
    }

    #[allow(clippy::too_many_arguments)]
    pub fn from_reader_range<R: Read + Seek>(
        model_id: impl Into<String>,
        source_uri: impl Into<String>,
        reader: &mut R,
        byte_start: u64,
        byte_len: u64,
        max_bytes_to_hash: u64,
        created_at_ms: u64,
        encoding: WeightBlockEncoding,
        residency_class: WeightBlockResidencyClass,
        ir_chart: WeightBlockIrChart,
        wbo_budget_nats: f32,
        verifier: impl Into<String>,
        rollback_reference: Option<UasAddress>,
    ) -> Result<Self, WeightBlockManifestError> {
        let model_id = model_id.into();
        let source_uri = source_uri.into();
        let verifier = verifier.into();
        Self::validate_fields(&model_id, &source_uri, &verifier, wbo_budget_nats)?;
        let byte_range = ByteRange::new(byte_start, byte_len)?;
        if byte_len > max_bytes_to_hash {
            return Err(WeightBlockManifestError::RangeHashLimitExceeded {
                requested: byte_len,
                max: max_bytes_to_hash,
            });
        }

        reader.seek(SeekFrom::Start(byte_start)).map_err(|error| {
            WeightBlockManifestError::RangeHashIo {
                kind: format!("{:?}", error.kind()),
            }
        })?;
        let hash = hash_reader_range(reader, byte_len)?;

        Self::from_validated_hash(
            model_id,
            source_uri,
            byte_range,
            hash,
            created_at_ms,
            encoding,
            residency_class,
            ir_chart,
            wbo_budget_nats,
            verifier,
            rollback_reference,
        )
    }

    #[allow(clippy::too_many_arguments)]
    fn from_validated_hash(
        model_id: String,
        source_uri: String,
        byte_range: ByteRange,
        hash: blake3::Hash,
        created_at_ms: u64,
        encoding: WeightBlockEncoding,
        residency_class: WeightBlockResidencyClass,
        ir_chart: WeightBlockIrChart,
        wbo_budget_nats: f32,
        verifier: String,
        rollback_reference: Option<UasAddress>,
    ) -> Result<Self, WeightBlockManifestError> {
        let uas_address = UasAddress::from_hash(UasKind::ModelComponent, hash, created_at_ms);
        let residency_tier = match residency_class {
            WeightBlockResidencyClass::HotUma | WeightBlockResidencyClass::WarmCompressedUma => {
                ResidencyTier::VerifiedFloor
            }
            WeightBlockResidencyClass::ColdMmapSsd
            | WeightBlockResidencyClass::ExternalCandidate => ResidencyTier::CapabilityCeiling,
        };

        Ok(Self {
            model_id,
            source_uri,
            byte_range,
            content_hash_hex: hash.to_hex().to_string(),
            uas_address,
            encoding,
            residency_class,
            residency_tier,
            ir_chart,
            wbo_budget_nats,
            verifier,
            rollback_reference,
        })
    }

    fn validate_fields(
        model_id: &str,
        source_uri: &str,
        verifier: &str,
        wbo_budget_nats: f32,
    ) -> Result<(), WeightBlockManifestError> {
        if model_id.trim().is_empty() {
            return Err(WeightBlockManifestError::MissingModelId);
        }
        if source_uri.trim().is_empty() {
            return Err(WeightBlockManifestError::MissingSourceUri);
        }
        if verifier.trim().is_empty() {
            return Err(WeightBlockManifestError::MissingVerifier);
        }
        if !wbo_budget_nats.is_finite() || wbo_budget_nats < 0.0 {
            return Err(WeightBlockManifestError::InvalidWboBudget);
        }
        Ok(())
    }

    pub fn is_cold_ssd_candidate(&self) -> bool {
        matches!(self.residency_class, WeightBlockResidencyClass::ColdMmapSsd)
    }

    pub fn requires_dense_reference(&self) -> bool {
        !matches!(
            self.encoding,
            WeightBlockEncoding::DenseFp16 | WeightBlockEncoding::DenseBf16
        )
    }

    pub fn canonical_lattice_codec(&self) -> &'static str {
        match &self.encoding {
            WeightBlockEncoding::DenseFp16
            | WeightBlockEncoding::DenseBf16
            | WeightBlockEncoding::DenseFp32 => "exact-hot",
            WeightBlockEncoding::Int8 | WeightBlockEncoding::FourBit => "babai-gptq-nearest-plane",
            WeightBlockEncoding::Nf4 => "nf4-ssd-oracle",
            WeightBlockEncoding::Ternary | WeightBlockEncoding::Sherry125 => {
                "sherry-3-of-4-ternary"
            }
            WeightBlockEncoding::LeechVq => "nested-leech-24",
            WeightBlockEncoding::ResidualIsland => "lattice-wyner-ziv-residual",
            WeightBlockEncoding::Other(_) => "opaque-with-witness",
        }
    }
}

pub fn hash_reader_range<R: Read>(
    reader: &mut R,
    byte_len: u64,
) -> Result<blake3::Hash, WeightBlockManifestError> {
    let mut hasher = blake3::Hasher::new();
    let mut remaining = byte_len;
    let mut buffer = [0_u8; RANGE_HASH_CHUNK_BYTES];
    while remaining > 0 {
        let take = remaining.min(RANGE_HASH_CHUNK_BYTES as u64) as usize;
        let chunk = &mut buffer[..take];
        reader
            .read_exact(chunk)
            .map_err(|error| WeightBlockManifestError::RangeHashIo {
                kind: format!("{:?}", error.kind()),
            })?;
        hasher.update(chunk);
        remaining -= take as u64;
    }
    Ok(hasher.finalize())
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ResidencyBudget {
    pub hot_uma_bytes: u64,
    pub warm_compressed_uma_bytes: u64,
    pub cold_mmap_ssd_bytes: u64,
    pub wbo_budget_nats: f32,
    pub max_blocks: usize,
}

impl ResidencyBudget {
    pub fn new(
        hot_uma_bytes: u64,
        warm_compressed_uma_bytes: u64,
        cold_mmap_ssd_bytes: u64,
        wbo_budget_nats: f32,
        max_blocks: usize,
    ) -> Result<Self, ResidencyPlanError> {
        if !wbo_budget_nats.is_finite() || wbo_budget_nats < 0.0 {
            return Err(ResidencyPlanError::InvalidBudget);
        }
        if max_blocks == 0 {
            return Err(ResidencyPlanError::InvalidBudget);
        }
        Ok(Self {
            hot_uma_bytes,
            warm_compressed_uma_bytes,
            cold_mmap_ssd_bytes,
            wbo_budget_nats,
            max_blocks,
        })
    }

    /// Conservative M2 Pro 16 GB dry-run floor. The 16 GB machine is not a
    /// 16 GB model heap; the OS, app, MLX/Metal runtime, and UI need margin.
    pub const fn m2_pro_16gb_safety_floor() -> Self {
        Self {
            hot_uma_bytes: 12 * GIB,
            warm_compressed_uma_bytes: 2 * GIB,
            cold_mmap_ssd_bytes: 256 * GIB,
            wbo_budget_nats: 0.25,
            max_blocks: 8192,
        }
    }
}

#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct ResidencyPlanTotals {
    pub hot_uma_bytes: u64,
    pub warm_compressed_uma_bytes: u64,
    pub cold_mmap_ssd_bytes: u64,
    pub total_addressed_bytes: u64,
    pub active_runtime_bytes: u64,
    pub wbo_budget_nats: f32,
    pub block_count: usize,
    pub cold_block_count: usize,
    pub external_candidate_count: usize,
    pub dense_reference_required_count: usize,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ResidencyPlanStatus {
    FitForDryRun,
    RejectedBeforeRuntime,
}

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ResidencyPlanViolation {
    EmptyActiveSet,
    TooManyBlocks {
        actual: usize,
        max: usize,
    },
    MixedModelIds,
    DuplicateUasAddress {
        address: String,
    },
    HotUmaBudgetExceeded {
        actual: u64,
        max: u64,
    },
    WarmCompressedUmaBudgetExceeded {
        actual: u64,
        max: u64,
    },
    ColdMmapSsdBudgetExceeded {
        actual: u64,
        max: u64,
    },
    WboBudgetExceeded {
        actual_millis: u32,
        max_millis: u32,
    },
    DenseReferenceMissing {
        address: String,
    },
    RollbackReferenceKindMismatch {
        address: String,
        actual_kind: String,
    },
    ExternalCandidateRequiresQuarantine {
        address: String,
    },
    OverlappingByteRange {
        source_uri: String,
        first_start: u64,
        first_end: u64,
        second_start: u64,
        second_end: u64,
    },
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ResidencyPlan {
    pub plan_address: UasAddress,
    pub model_id: String,
    pub blocks: Vec<WeightBlockManifest>,
    pub budget: ResidencyBudget,
    pub totals: ResidencyPlanTotals,
    pub status: ResidencyPlanStatus,
    pub violations: Vec<ResidencyPlanViolation>,
    pub effective_residency_tier: ResidencyTier,
}

impl ResidencyPlan {
    pub fn evaluate(
        blocks: impl IntoIterator<Item = WeightBlockManifest>,
        budget: ResidencyBudget,
        created_at_ms: u64,
    ) -> Self {
        let mut blocks: Vec<_> = blocks.into_iter().collect();
        blocks.sort_by(|a, b| {
            (
                a.model_id.as_str(),
                a.source_uri.as_str(),
                a.byte_range.start,
                a.uas_address.to_string(),
            )
                .cmp(&(
                    b.model_id.as_str(),
                    b.source_uri.as_str(),
                    b.byte_range.start,
                    b.uas_address.to_string(),
                ))
        });

        let mut totals = ResidencyPlanTotals {
            block_count: blocks.len(),
            ..ResidencyPlanTotals::default()
        };
        let mut violations = Vec::new();
        let mut model_ids = HashSet::new();
        let mut seen_addresses = HashSet::new();
        let mut last_range_by_source_uri: HashMap<String, ByteRange> = HashMap::new();
        let mut effective_residency_tier = ResidencyTier::VerifiedFloor;

        if blocks.is_empty() {
            violations.push(ResidencyPlanViolation::EmptyActiveSet);
        }
        if blocks.len() > budget.max_blocks {
            violations.push(ResidencyPlanViolation::TooManyBlocks {
                actual: blocks.len(),
                max: budget.max_blocks,
            });
        }

        for block in &blocks {
            model_ids.insert(block.model_id.as_str());
            let address = block.uas_address.to_string();
            if !seen_addresses.insert(address.clone()) {
                violations.push(ResidencyPlanViolation::DuplicateUasAddress { address });
            }
            if let Some(previous) = last_range_by_source_uri.get(&block.source_uri) {
                if block.byte_range.start < previous.end_exclusive() {
                    violations.push(ResidencyPlanViolation::OverlappingByteRange {
                        source_uri: block.source_uri.clone(),
                        first_start: previous.start,
                        first_end: previous.end_exclusive(),
                        second_start: block.byte_range.start,
                        second_end: block.byte_range.end_exclusive(),
                    });
                }
            }
            last_range_by_source_uri
                .entry(block.source_uri.clone())
                .and_modify(|previous| {
                    if block.byte_range.end_exclusive() > previous.end_exclusive() {
                        *previous = block.byte_range;
                    }
                })
                .or_insert(block.byte_range);
            if block.residency_tier == ResidencyTier::CapabilityCeiling {
                effective_residency_tier = ResidencyTier::CapabilityCeiling;
            }
            totals.wbo_budget_nats += block.wbo_budget_nats;
            totals.total_addressed_bytes = totals
                .total_addressed_bytes
                .saturating_add(block.byte_range.len);
            match block.residency_class {
                WeightBlockResidencyClass::HotUma => {
                    totals.hot_uma_bytes = totals.hot_uma_bytes.saturating_add(block.byte_range.len)
                }
                WeightBlockResidencyClass::WarmCompressedUma => {
                    totals.warm_compressed_uma_bytes = totals
                        .warm_compressed_uma_bytes
                        .saturating_add(block.byte_range.len)
                }
                WeightBlockResidencyClass::ColdMmapSsd => {
                    totals.cold_mmap_ssd_bytes = totals
                        .cold_mmap_ssd_bytes
                        .saturating_add(block.byte_range.len);
                    totals.cold_block_count += 1;
                }
                WeightBlockResidencyClass::ExternalCandidate => {
                    totals.external_candidate_count += 1;
                    violations.push(
                        ResidencyPlanViolation::ExternalCandidateRequiresQuarantine {
                            address: block.uas_address.to_string(),
                        },
                    );
                }
            }
            if block.requires_dense_reference() {
                totals.dense_reference_required_count += 1;
                match block.rollback_reference.as_ref() {
                    None => {
                        violations.push(ResidencyPlanViolation::DenseReferenceMissing {
                            address: block.uas_address.to_string(),
                        });
                    }
                    Some(reference) if reference.kind != UasKind::ModelComponent => {
                        violations.push(ResidencyPlanViolation::RollbackReferenceKindMismatch {
                            address: reference.to_string(),
                            actual_kind: reference.kind.wire_tag().into_owned(),
                        });
                    }
                    Some(_) => {}
                }
            }
        }

        totals.active_runtime_bytes = totals
            .hot_uma_bytes
            .saturating_add(totals.warm_compressed_uma_bytes);

        if model_ids.len() > 1 {
            violations.push(ResidencyPlanViolation::MixedModelIds);
        }
        if totals.hot_uma_bytes > budget.hot_uma_bytes {
            violations.push(ResidencyPlanViolation::HotUmaBudgetExceeded {
                actual: totals.hot_uma_bytes,
                max: budget.hot_uma_bytes,
            });
        }
        if totals.warm_compressed_uma_bytes > budget.warm_compressed_uma_bytes {
            violations.push(ResidencyPlanViolation::WarmCompressedUmaBudgetExceeded {
                actual: totals.warm_compressed_uma_bytes,
                max: budget.warm_compressed_uma_bytes,
            });
        }
        if totals.cold_mmap_ssd_bytes > budget.cold_mmap_ssd_bytes {
            violations.push(ResidencyPlanViolation::ColdMmapSsdBudgetExceeded {
                actual: totals.cold_mmap_ssd_bytes,
                max: budget.cold_mmap_ssd_bytes,
            });
        }
        if totals.wbo_budget_nats > budget.wbo_budget_nats {
            violations.push(ResidencyPlanViolation::WboBudgetExceeded {
                actual_millis: (totals.wbo_budget_nats * 1000.0).round() as u32,
                max_millis: (budget.wbo_budget_nats * 1000.0).round() as u32,
            });
        }

        let status = if violations.is_empty() {
            ResidencyPlanStatus::FitForDryRun
        } else {
            ResidencyPlanStatus::RejectedBeforeRuntime
        };
        let model_id = if model_ids.len() == 1 {
            blocks
                .first()
                .map(|b| b.model_id.clone())
                .unwrap_or_else(|| "empty".to_string())
        } else if blocks.is_empty() {
            "empty".to_string()
        } else {
            "mixed".to_string()
        };
        let plan_address = Self::plan_address(&blocks, &budget, created_at_ms);

        Self {
            plan_address,
            model_id,
            blocks,
            budget,
            totals,
            status,
            violations,
            effective_residency_tier,
        }
    }

    pub fn active_set_can_enter_runtime(&self) -> bool {
        self.status == ResidencyPlanStatus::FitForDryRun
    }

    fn plan_address(
        blocks: &[WeightBlockManifest],
        budget: &ResidencyBudget,
        created_at_ms: u64,
    ) -> UasAddress {
        let mut preimage = String::new();
        preimage.push_str("residency_plan_v1\n");
        preimage.push_str(&format!(
            "{}:{}:{}:{}:{}\n",
            budget.hot_uma_bytes,
            budget.warm_compressed_uma_bytes,
            budget.cold_mmap_ssd_bytes,
            (budget.wbo_budget_nats * 1000.0).round() as u32,
            budget.max_blocks
        ));
        for block in blocks {
            preimage.push_str(&format!(
                "{}|{}|{}|{}|{}|{}\n",
                block.model_id,
                block.source_uri,
                block.byte_range.start,
                block.byte_range.len,
                block.uas_address,
                block.canonical_lattice_codec()
            ));
        }
        UasAddress::new(
            UasKind::Other("residency_plan".to_string()),
            preimage.as_bytes(),
            created_at_ms,
        )
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ResidencyPlanError {
    InvalidBudget,
}

impl std::fmt::Display for ResidencyPlanError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ResidencyPlanError::InvalidBudget => {
                write!(
                    f,
                    "residency budget must have finite non-negative WBO and at least one block"
                )
            }
        }
    }
}

impl std::error::Error for ResidencyPlanError {}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum WeightBlockManifestError {
    MissingModelId,
    MissingSourceUri,
    MissingVerifier,
    InvalidContentHash,
    RangeHashLimitExceeded { requested: u64, max: u64 },
    RangeHashIo { kind: String },
    EmptyByteRange,
    ByteRangeOverflow,
    InvalidWboBudget,
}

impl std::fmt::Display for WeightBlockManifestError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            WeightBlockManifestError::MissingModelId => write!(f, "model_id is required"),
            WeightBlockManifestError::MissingSourceUri => write!(f, "source_uri is required"),
            WeightBlockManifestError::MissingVerifier => write!(f, "verifier is required"),
            WeightBlockManifestError::InvalidContentHash => {
                write!(f, "content_hash_hex must be a valid BLAKE3 hex hash")
            }
            WeightBlockManifestError::RangeHashLimitExceeded { requested, max } => {
                write!(
                    f,
                    "range hash requested {requested} bytes but max_bytes_to_hash is {max}"
                )
            }
            WeightBlockManifestError::RangeHashIo { kind } => {
                write!(f, "range hashing IO failed with {kind}")
            }
            WeightBlockManifestError::EmptyByteRange => write!(f, "byte range must be non-empty"),
            WeightBlockManifestError::ByteRangeOverflow => write!(f, "byte range overflows u64"),
            WeightBlockManifestError::InvalidWboBudget => {
                write!(f, "wbo_budget_nats must be finite and non-negative")
            }
        }
    }
}

impl std::error::Error for WeightBlockManifestError {}

#[cfg(test)]
mod tests {
    use super::*;

    fn rollback_reference() -> UasAddress {
        UasAddress::new(UasKind::ModelComponent, b"dense-reference", 7)
    }

    fn manifest(
        name: &str,
        byte_start: u64,
        bytes: &[u8],
        encoding: WeightBlockEncoding,
        residency_class: WeightBlockResidencyClass,
        rollback_reference: Option<UasAddress>,
    ) -> WeightBlockManifest {
        WeightBlockManifest::from_bytes(
            "mlx-community/Qwen3-Coder-Next-4bit",
            format!("file:///models/qwen3/{name}.safetensors"),
            byte_start,
            bytes,
            1_779_000_000_000,
            encoding,
            residency_class,
            WeightBlockIrChart::OpaqueWithWitness,
            0.02,
            "dense_reference_d_kl",
            rollback_reference,
        )
        .expect("manifest should build")
    }

    #[test]
    fn cold_weight_block_manifest_is_uas_addressed_and_capability_ceiling() {
        let manifest = WeightBlockManifest::from_bytes(
            "mlx-community/Qwen3-Coder-Next-4bit",
            "file:///models/qwen3/model.safetensors",
            4096,
            b"deterministic-weight-block",
            1_779_000_000_000,
            WeightBlockEncoding::Nf4,
            WeightBlockResidencyClass::ColdMmapSsd,
            WeightBlockIrChart::OpaqueWithWitness,
            0.05,
            "dense_reference_d_kl",
            None,
        )
        .expect("manifest should build");

        assert_eq!(manifest.uas_address.kind, UasKind::ModelComponent);
        assert_eq!(manifest.byte_range.end_exclusive(), 4096 + 26);
        assert_eq!(manifest.residency_tier, ResidencyTier::CapabilityCeiling);
        assert!(manifest.is_cold_ssd_candidate());
        assert!(manifest.requires_dense_reference());
    }

    #[test]
    fn dense_hot_manifest_still_stays_verified_floor_until_runtime_gate() {
        let manifest = WeightBlockManifest::from_bytes(
            "Qwen/Qwen3-8B-MLX-4bit",
            "file:///models/qwen3/hot-block.safetensors",
            0,
            b"hot-block",
            1,
            WeightBlockEncoding::DenseBf16,
            WeightBlockResidencyClass::HotUma,
            WeightBlockIrChart::Scan,
            0.0,
            "bit_exact_reference",
            None,
        )
        .expect("manifest should build");

        assert_eq!(manifest.residency_tier, ResidencyTier::VerifiedFloor);
        assert!(!manifest.is_cold_ssd_candidate());
        assert!(!manifest.requires_dense_reference());
    }

    #[test]
    fn rejects_empty_or_unbounded_manifest_fields() {
        assert_eq!(
            WeightBlockManifest::from_bytes(
                "",
                "file:///x",
                0,
                b"x",
                0,
                WeightBlockEncoding::Nf4,
                WeightBlockResidencyClass::ColdMmapSsd,
                WeightBlockIrChart::OpaqueWithWitness,
                0.0,
                "verifier",
                None,
            )
            .unwrap_err(),
            WeightBlockManifestError::MissingModelId
        );
        assert_eq!(
            ByteRange::new(u64::MAX, 2).unwrap_err(),
            WeightBlockManifestError::ByteRangeOverflow
        );
        assert_eq!(
            ByteRange::new(0, 0).unwrap_err(),
            WeightBlockManifestError::EmptyByteRange
        );
    }

    #[test]
    fn known_hash_manifest_describes_real_ranges_without_loading_bytes() {
        let hash = blake3::hash(b"large-model-range-prehashed");
        let manifest = WeightBlockManifest::from_known_hash_hex(
            "local/70b-candidate",
            "file:///models/70b/model-00001-of-00008.safetensors",
            8 * GIB,
            2 * GIB,
            hash.to_hex().as_str(),
            99,
            WeightBlockEncoding::LeechVq,
            WeightBlockResidencyClass::ColdMmapSsd,
            WeightBlockIrChart::Geometry,
            0.04,
            "precomputed_range_hash_plus_dense_reference",
            Some(rollback_reference()),
        )
        .expect("known-hash manifest should build");

        assert_eq!(manifest.byte_range.start, 8 * GIB);
        assert_eq!(manifest.byte_range.len, 2 * GIB);
        assert_eq!(manifest.content_hash_hex, hash.to_hex().to_string());
        assert_eq!(manifest.uas_address.hash, hash);
        assert_eq!(manifest.canonical_lattice_codec(), "nested-leech-24");
    }

    #[test]
    fn known_hash_manifest_rejects_invalid_hash_hex() {
        let err = WeightBlockManifest::from_known_hash_hex(
            "local/70b-candidate",
            "file:///models/70b/model.safetensors",
            0,
            1024,
            "not-a-blake3-hash",
            99,
            WeightBlockEncoding::Nf4,
            WeightBlockResidencyClass::ColdMmapSsd,
            WeightBlockIrChart::OpaqueWithWitness,
            0.04,
            "precomputed_range_hash",
            Some(rollback_reference()),
        )
        .unwrap_err();

        assert_eq!(err, WeightBlockManifestError::InvalidContentHash);
    }

    #[test]
    fn reader_range_manifest_hashes_bounded_slice_without_full_load() {
        let bytes = b"prefix:bounded-range:tail".to_vec();
        let expected_hash = blake3::hash(b"bounded-range");
        let mut reader = std::io::Cursor::new(bytes);

        let manifest = WeightBlockManifest::from_reader_range(
            "local/range-hash-candidate",
            "file:///models/range/model.safetensors",
            &mut reader,
            7,
            13,
            64,
            123,
            WeightBlockEncoding::Nf4,
            WeightBlockResidencyClass::ColdMmapSsd,
            WeightBlockIrChart::OpaqueWithWitness,
            0.01,
            "bounded_range_hash",
            Some(rollback_reference()),
        )
        .expect("bounded range manifest should build");

        assert_eq!(manifest.byte_range.start, 7);
        assert_eq!(manifest.byte_range.len, 13);
        assert_eq!(manifest.uas_address.hash, expected_hash);
        assert_eq!(
            manifest.content_hash_hex,
            expected_hash.to_hex().to_string()
        );
    }

    #[test]
    fn reader_range_manifest_rejects_over_limit_before_reading() {
        let mut reader = std::io::Cursor::new(b"small".to_vec());
        let err = WeightBlockManifest::from_reader_range(
            "local/range-hash-candidate",
            "file:///models/range/model.safetensors",
            &mut reader,
            0,
            1024,
            16,
            123,
            WeightBlockEncoding::Nf4,
            WeightBlockResidencyClass::ColdMmapSsd,
            WeightBlockIrChart::OpaqueWithWitness,
            0.01,
            "bounded_range_hash",
            Some(rollback_reference()),
        )
        .unwrap_err();

        assert_eq!(
            err,
            WeightBlockManifestError::RangeHashLimitExceeded {
                requested: 1024,
                max: 16
            }
        );
    }

    #[test]
    fn reader_range_manifest_surfaces_short_reader() {
        let mut reader = std::io::Cursor::new(b"short".to_vec());
        let err = WeightBlockManifest::from_reader_range(
            "local/range-hash-candidate",
            "file:///models/range/model.safetensors",
            &mut reader,
            0,
            32,
            64,
            123,
            WeightBlockEncoding::Nf4,
            WeightBlockResidencyClass::ColdMmapSsd,
            WeightBlockIrChart::OpaqueWithWitness,
            0.01,
            "bounded_range_hash",
            Some(rollback_reference()),
        )
        .unwrap_err();

        assert_eq!(
            err,
            WeightBlockManifestError::RangeHashIo {
                kind: "UnexpectedEof".to_string()
            }
        );
    }

    #[test]
    fn residency_plan_fits_without_touching_runtime() {
        let hot = manifest(
            "hot",
            0,
            b"hot-dense-block",
            WeightBlockEncoding::DenseBf16,
            WeightBlockResidencyClass::HotUma,
            None,
        );
        let cold = manifest(
            "cold",
            1_048_576,
            b"cold-nf4-block",
            WeightBlockEncoding::Nf4,
            WeightBlockResidencyClass::ColdMmapSsd,
            Some(rollback_reference()),
        );
        let budget = ResidencyBudget::new(1024, 1024, 4096, 0.10, 16).unwrap();

        let plan = ResidencyPlan::evaluate([hot.clone(), cold.clone()], budget.clone(), 42);
        let reversed = ResidencyPlan::evaluate([cold, hot], budget, 42);

        assert!(plan.active_set_can_enter_runtime());
        assert_eq!(plan.status, ResidencyPlanStatus::FitForDryRun);
        assert_eq!(plan.totals.block_count, 2);
        assert_eq!(plan.totals.hot_uma_bytes, 15);
        assert_eq!(plan.totals.cold_mmap_ssd_bytes, 14);
        assert_eq!(plan.totals.active_runtime_bytes, 15);
        assert_eq!(plan.totals.dense_reference_required_count, 1);
        assert_eq!(
            plan.effective_residency_tier,
            ResidencyTier::CapabilityCeiling
        );
        assert_eq!(plan.plan_address, reversed.plan_address);
    }

    #[test]
    fn residency_plan_rejects_missing_reference_and_budget_overflow() {
        let cold = manifest(
            "cold",
            0,
            b"cold-nf4-block-too-large",
            WeightBlockEncoding::Nf4,
            WeightBlockResidencyClass::ColdMmapSsd,
            None,
        );
        let budget = ResidencyBudget::new(1, 1, 4, 0.01, 16).unwrap();

        let plan = ResidencyPlan::evaluate([cold], budget, 42);

        assert!(!plan.active_set_can_enter_runtime());
        assert_eq!(plan.status, ResidencyPlanStatus::RejectedBeforeRuntime);
        assert!(plan
            .violations
            .iter()
            .any(|v| matches!(v, ResidencyPlanViolation::DenseReferenceMissing { .. })));
        assert!(plan
            .violations
            .iter()
            .any(|v| matches!(v, ResidencyPlanViolation::ColdMmapSsdBudgetExceeded { .. })));
        assert!(plan
            .violations
            .iter()
            .any(|v| matches!(v, ResidencyPlanViolation::WboBudgetExceeded { .. })));
    }

    #[test]
    fn residency_plan_rejects_non_model_component_rollback_reference() {
        let non_model_rollback = UasAddress::new(UasKind::AnswerPacket, b"answer-packet", 7);
        let cold = manifest(
            "cold",
            0,
            b"cold-nf4-block",
            WeightBlockEncoding::Nf4,
            WeightBlockResidencyClass::ColdMmapSsd,
            Some(non_model_rollback),
        );
        let budget = ResidencyBudget::new(1024, 1024, 4096, 0.10, 16).unwrap();

        let plan = ResidencyPlan::evaluate([cold], budget, 42);

        assert_eq!(plan.status, ResidencyPlanStatus::RejectedBeforeRuntime);
        assert!(plan.violations.iter().any(|v| {
            matches!(
                v,
                ResidencyPlanViolation::RollbackReferenceKindMismatch {
                    actual_kind,
                    ..
                } if actual_kind == "answer_packet"
            )
        }));
    }

    #[test]
    fn residency_plan_rejects_mixed_models_and_duplicates() {
        let first = manifest(
            "same",
            0,
            b"same-bytes",
            WeightBlockEncoding::DenseBf16,
            WeightBlockResidencyClass::HotUma,
            None,
        );
        let mut second = first.clone();
        second.model_id = "other/model".to_string();
        let budget = ResidencyBudget::new(1024, 1024, 1024, 0.10, 16).unwrap();

        let plan = ResidencyPlan::evaluate([first, second], budget, 42);

        assert!(plan
            .violations
            .contains(&ResidencyPlanViolation::MixedModelIds));
        assert!(plan
            .violations
            .iter()
            .any(|v| matches!(v, ResidencyPlanViolation::DuplicateUasAddress { .. })));
    }

    #[test]
    fn canonical_codec_names_cover_sherry_and_leech_routes() {
        let sherry = manifest(
            "sherry",
            0,
            b"sherry-block",
            WeightBlockEncoding::Sherry125,
            WeightBlockResidencyClass::WarmCompressedUma,
            Some(rollback_reference()),
        );
        let leech = manifest(
            "leech",
            64,
            b"leech-block",
            WeightBlockEncoding::LeechVq,
            WeightBlockResidencyClass::WarmCompressedUma,
            Some(rollback_reference()),
        );

        assert_eq!(sherry.canonical_lattice_codec(), "sherry-3-of-4-ternary");
        assert_eq!(leech.canonical_lattice_codec(), "nested-leech-24");
    }

    #[test]
    fn residency_plan_rejects_overlapping_ranges_for_same_source_uri() {
        let first = WeightBlockManifest::from_known_hash_hex(
            "local/70b-candidate",
            "file:///models/70b/model-00001-of-00008.safetensors",
            0,
            1024,
            blake3::hash(b"first-range").to_hex().as_str(),
            99,
            WeightBlockEncoding::Nf4,
            WeightBlockResidencyClass::ColdMmapSsd,
            WeightBlockIrChart::OpaqueWithWitness,
            0.01,
            "precomputed_range_hash_plus_dense_reference",
            Some(rollback_reference()),
        )
        .expect("first known-hash manifest should build");
        let overlapping = WeightBlockManifest::from_known_hash_hex(
            "local/70b-candidate",
            "file:///models/70b/model-00001-of-00008.safetensors",
            512,
            1024,
            blake3::hash(b"overlapping-range").to_hex().as_str(),
            99,
            WeightBlockEncoding::Nf4,
            WeightBlockResidencyClass::ColdMmapSsd,
            WeightBlockIrChart::OpaqueWithWitness,
            0.01,
            "precomputed_range_hash_plus_dense_reference",
            Some(rollback_reference()),
        )
        .expect("overlapping known-hash manifest should build");

        let plan = ResidencyPlan::evaluate(
            [first, overlapping],
            ResidencyBudget::m2_pro_16gb_safety_floor(),
            42,
        );

        assert_eq!(plan.status, ResidencyPlanStatus::RejectedBeforeRuntime);
        assert!(plan.violations.iter().any(|v| {
            matches!(
                v,
                ResidencyPlanViolation::OverlappingByteRange {
                    source_uri,
                    first_start: 0,
                    first_end: 1024,
                    second_start: 512,
                    second_end: 1536,
                } if source_uri == "file:///models/70b/model-00001-of-00008.safetensors"
            )
        }));
    }

    #[test]
    fn residency_plan_allows_adjacent_ranges_for_same_source_uri() {
        let first = WeightBlockManifest::from_known_hash_hex(
            "local/70b-candidate",
            "file:///models/70b/model-00001-of-00008.safetensors",
            0,
            1024,
            blake3::hash(b"first-adjacent-range").to_hex().as_str(),
            99,
            WeightBlockEncoding::Nf4,
            WeightBlockResidencyClass::ColdMmapSsd,
            WeightBlockIrChart::OpaqueWithWitness,
            0.01,
            "precomputed_range_hash_plus_dense_reference",
            Some(rollback_reference()),
        )
        .expect("first known-hash manifest should build");
        let adjacent = WeightBlockManifest::from_known_hash_hex(
            "local/70b-candidate",
            "file:///models/70b/model-00001-of-00008.safetensors",
            1024,
            2048,
            blake3::hash(b"second-adjacent-range").to_hex().as_str(),
            99,
            WeightBlockEncoding::Nf4,
            WeightBlockResidencyClass::ColdMmapSsd,
            WeightBlockIrChart::OpaqueWithWitness,
            0.01,
            "precomputed_range_hash_plus_dense_reference",
            Some(rollback_reference()),
        )
        .expect("adjacent known-hash manifest should build");

        let plan = ResidencyPlan::evaluate(
            [adjacent, first],
            ResidencyBudget::m2_pro_16gb_safety_floor(),
            42,
        );

        assert_eq!(plan.status, ResidencyPlanStatus::FitForDryRun);
        assert!(!plan
            .violations
            .iter()
            .any(|v| matches!(v, ResidencyPlanViolation::OverlappingByteRange { .. })));
    }
}
