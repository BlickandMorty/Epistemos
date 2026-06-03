//! Coactivation tile manifests for constructive residency layout.
//!
//! This is a metadata-only UAS primitive. It packs bytes that tend to be useful
//! together and records verifier, byte-range, codec, reuse-horizon, cost, and
//! rollback evidence without moving bytes or mutating live route policy.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;

use crate::uas::{ByteRange, UasAddress, UasKind};

const TILE_UAS_KIND: &str = "coactivation_tile";
const ROLLBACK_PREFIX: &str = "rollback:";
const VERIFIER_PREFIXES: [&str; 2] = ["F-", "verifier:"];

// UAS: uas/research-construction/coactivation-tile-unit-kind
// Plane: RuntimePlane::Assembly
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CoactivationTileUnitKind {
    WeightPage,
    Expert,
    KvPage,
    AdapterSlice,
    EvidenceBundle,
}

// UAS: uas/research-construction/coactivation-tile-unit
// Plane: RuntimePlane::Assembly
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CoactivationTileUnit {
    pub unit_id: String,
    pub unit_kind: CoactivationTileUnitKind,
    pub uas_address: UasAddress,
    pub byte_range: ByteRange,
    pub codec: String,
    pub checksum: String,
    pub expected_reuse_horizon: u64,
    pub verifier_ref: String,
}

impl CoactivationTileUnit {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        unit_id: impl Into<String>,
        unit_kind: CoactivationTileUnitKind,
        uas_address: UasAddress,
        byte_start: u64,
        byte_len: u64,
        codec: impl Into<String>,
        checksum: impl Into<String>,
        expected_reuse_horizon: u64,
        verifier_ref: impl Into<String>,
    ) -> Result<Self, CoactivationTileError> {
        let unit_id = unit_id.into();
        let codec = codec.into();
        let checksum = checksum.into();
        let verifier_ref = verifier_ref.into();
        validate_nonempty("unit_id", &unit_id)?;
        validate_nonempty("codec", &codec)?;
        validate_nonempty("checksum", &checksum)?;
        validate_nonempty("verifier_ref", &verifier_ref)?;
        if expected_reuse_horizon == 0 {
            return Err(CoactivationTileError::InvalidReuseHorizon {
                unit_id: unit_id.clone(),
            });
        }
        if !checksum.starts_with("blake3:") {
            return Err(CoactivationTileError::InvalidChecksum {
                unit_id: unit_id.clone(),
            });
        }
        if !VERIFIER_PREFIXES
            .iter()
            .any(|prefix| verifier_ref.starts_with(prefix))
        {
            return Err(CoactivationTileError::InvalidVerifierRef {
                unit_id: unit_id.clone(),
            });
        }
        let byte_range = ByteRange::new(byte_start, byte_len).map_err(|_| {
            CoactivationTileError::InvalidByteRange {
                unit_id: unit_id.clone(),
            }
        })?;
        Ok(Self {
            unit_id,
            unit_kind,
            uas_address,
            byte_range,
            codec,
            checksum,
            expected_reuse_horizon,
            verifier_ref,
        })
    }
}

// UAS: uas/research-construction/coactivation-tile
// Plane: RuntimePlane::Assembly
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CoactivationTile {
    pub tile_address: UasAddress,
    pub tile_id: String,
    pub model_or_memory_id: String,
    pub units: Vec<CoactivationTileUnit>,
    pub expected_reuse_horizon: u64,
    pub prefetch_cost_bytes: u64,
    pub verifier_history: Vec<String>,
    pub rollback_ref: String,
}

impl CoactivationTile {
    pub fn new(
        tile_id: impl Into<String>,
        model_or_memory_id: impl Into<String>,
        units: Vec<CoactivationTileUnit>,
        verifier_history: Vec<String>,
        rollback_ref: impl Into<String>,
        created_at_ms: u64,
    ) -> Result<Self, CoactivationTileError> {
        let tile_id = tile_id.into();
        let model_or_memory_id = model_or_memory_id.into();
        let rollback_ref = rollback_ref.into();
        validate_nonempty("tile_id", &tile_id)?;
        validate_nonempty("model_or_memory_id", &model_or_memory_id)?;
        validate_nonempty("rollback_ref", &rollback_ref)?;
        if !rollback_ref.starts_with(ROLLBACK_PREFIX) {
            return Err(CoactivationTileError::MissingRollback {
                tile_id: tile_id.clone(),
            });
        }
        if units.is_empty() {
            return Err(CoactivationTileError::MissingUnit {
                tile_id: tile_id.clone(),
            });
        }
        let verifier_history = canonicalize_verifier_history(verifier_history)?;
        let units = canonicalize_units(units)?;
        let expected_reuse_horizon = units
            .iter()
            .map(|unit| unit.expected_reuse_horizon)
            .max()
            .unwrap_or_default();
        let prefetch_cost_bytes = units.iter().map(|unit| unit.byte_range.len).sum::<u64>();
        let tile_address = tile_address(
            &tile_id,
            &model_or_memory_id,
            &units,
            expected_reuse_horizon,
            prefetch_cost_bytes,
            &verifier_history,
            &rollback_ref,
            created_at_ms,
        );

        Ok(Self {
            tile_address,
            tile_id,
            model_or_memory_id,
            units,
            expected_reuse_horizon,
            prefetch_cost_bytes,
            verifier_history,
            rollback_ref,
        })
    }
}

// UAS: uas/research-construction/coactivation-tile-error
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CoactivationTileError {
    MissingTileId,
    MissingModelOrMemoryId,
    MissingRollback { tile_id: String },
    MissingUnit { tile_id: String },
    DuplicateUnitId { unit_id: String },
    InvalidByteRange { unit_id: String },
    InvalidChecksum { unit_id: String },
    InvalidReuseHorizon { unit_id: String },
    InvalidVerifierRef { unit_id: String },
    FieldHasSurroundingWhitespace { field: &'static str },
    FieldContainsControlCharacter { field: &'static str },
}

impl std::fmt::Display for CoactivationTileError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::MissingTileId => write!(f, "tile_id is required"),
            Self::MissingModelOrMemoryId => write!(f, "model_or_memory_id is required"),
            Self::MissingRollback { tile_id } => write!(f, "tile {tile_id} requires rollback"),
            Self::MissingUnit { tile_id } => write!(f, "tile {tile_id} requires at least one unit"),
            Self::DuplicateUnitId { unit_id } => write!(f, "duplicate tile unit id: {unit_id}"),
            Self::InvalidByteRange { unit_id } => {
                write!(f, "unit {unit_id} has invalid byte range")
            }
            Self::InvalidChecksum { unit_id } => {
                write!(f, "unit {unit_id} requires a blake3 checksum")
            }
            Self::InvalidReuseHorizon { unit_id } => {
                write!(f, "unit {unit_id} requires nonzero reuse horizon")
            }
            Self::InvalidVerifierRef { unit_id } => {
                write!(f, "unit {unit_id} requires a verifier reference")
            }
            Self::FieldHasSurroundingWhitespace { field } => {
                write!(f, "{field} must not contain leading or trailing whitespace")
            }
            Self::FieldContainsControlCharacter { field } => {
                write!(f, "{field} must not contain control characters")
            }
        }
    }
}

impl std::error::Error for CoactivationTileError {}

fn canonicalize_units(
    mut units: Vec<CoactivationTileUnit>,
) -> Result<Vec<CoactivationTileUnit>, CoactivationTileError> {
    let mut seen = HashSet::new();
    for unit in &units {
        if !seen.insert(unit.unit_id.clone()) {
            return Err(CoactivationTileError::DuplicateUnitId {
                unit_id: unit.unit_id.clone(),
            });
        }
    }
    units.sort_by(|left, right| left.unit_id.cmp(&right.unit_id));
    Ok(units)
}

fn canonicalize_verifier_history(
    verifier_history: Vec<String>,
) -> Result<Vec<String>, CoactivationTileError> {
    let mut canonical = Vec::with_capacity(verifier_history.len());
    let mut seen = HashSet::new();
    for verifier in verifier_history {
        validate_nonempty("verifier_history", &verifier)?;
        if !VERIFIER_PREFIXES
            .iter()
            .any(|prefix| verifier.starts_with(prefix))
        {
            return Err(CoactivationTileError::InvalidVerifierRef { unit_id: verifier });
        }
        if seen.insert(verifier.clone()) {
            canonical.push(verifier);
        }
    }
    if canonical.is_empty() {
        return Err(CoactivationTileError::InvalidVerifierRef {
            unit_id: "verifier_history".to_string(),
        });
    }
    canonical.sort();
    Ok(canonical)
}

fn tile_address(
    tile_id: &str,
    model_or_memory_id: &str,
    units: &[CoactivationTileUnit],
    expected_reuse_horizon: u64,
    prefetch_cost_bytes: u64,
    verifier_history: &[String],
    rollback_ref: &str,
    created_at_ms: u64,
) -> UasAddress {
    let mut preimage = String::new();
    preimage.push_str("coactivation_tile_v1\n");
    preimage.push_str(tile_id);
    preimage.push('\n');
    preimage.push_str(model_or_memory_id);
    preimage.push('\n');
    for unit in units {
        preimage.push_str(&format!(
            "unit:{}:{:?}:{}:{}:{}:{}:{}:{}\n",
            unit.unit_id,
            unit.unit_kind,
            unit.uas_address,
            unit.byte_range.start,
            unit.byte_range.len,
            unit.codec,
            unit.checksum,
            unit.verifier_ref
        ));
    }
    preimage.push_str(&format!(
        "tile:{expected_reuse_horizon}:{prefetch_cost_bytes}:{}:{rollback_ref}",
        verifier_history.join(",")
    ));
    UasAddress::new(
        UasKind::Other(TILE_UAS_KIND.to_string()),
        preimage.as_bytes(),
        created_at_ms,
    )
}

fn validate_nonempty(field: &'static str, value: &str) -> Result<(), CoactivationTileError> {
    if value.trim().is_empty() {
        return match field {
            "tile_id" => Err(CoactivationTileError::MissingTileId),
            "model_or_memory_id" => Err(CoactivationTileError::MissingModelOrMemoryId),
            "rollback_ref" => Err(CoactivationTileError::MissingRollback {
                tile_id: "unknown".to_string(),
            }),
            _ => Err(CoactivationTileError::FieldContainsControlCharacter { field }),
        };
    }
    if value.trim() != value {
        return Err(CoactivationTileError::FieldHasSurroundingWhitespace { field });
    }
    if value.chars().any(char::is_control) {
        return Err(CoactivationTileError::FieldContainsControlCharacter { field });
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_000_000_000;

    fn unit(id: &str, start: u64, len: u64) -> CoactivationTileUnit {
        CoactivationTileUnit::new(
            id,
            CoactivationTileUnitKind::EvidenceBundle,
            UasAddress::new(
                UasKind::Other("evidence_bundle".to_string()),
                id.as_bytes(),
                CREATED_AT_MS,
            ),
            start,
            len,
            "raw",
            format!("blake3:{id}"),
            100,
            "F-ResidencyConstructionGraph",
        )
        .expect("valid tile unit")
    }

    #[test]
    fn coactivation_tile_address_is_deterministic() {
        let tile = CoactivationTile::new(
            "tile:claim-core",
            "memory:research",
            vec![unit("b", 64, 32), unit("a", 0, 32)],
            vec!["F-ResidencyConstructionGraph".to_string()],
            "rollback:tile-layout",
            CREATED_AT_MS,
        )
        .expect("valid tile");
        let reversed = CoactivationTile::new(
            "tile:claim-core",
            "memory:research",
            vec![unit("a", 0, 32), unit("b", 64, 32)],
            vec!["F-ResidencyConstructionGraph".to_string()],
            "rollback:tile-layout",
            CREATED_AT_MS,
        )
        .expect("valid tile");

        assert_eq!(tile.tile_address, reversed.tile_address);
        assert_eq!(tile.prefetch_cost_bytes, 64);
    }

    #[test]
    fn coactivation_tile_rejects_missing_rollback_and_bad_units() {
        let missing_rollback = CoactivationTile::new(
            "tile:bad",
            "memory:research",
            vec![unit("a", 0, 32)],
            vec!["F-ResidencyConstructionGraph".to_string()],
            "",
            CREATED_AT_MS,
        )
        .expect_err("missing rollback should reject");
        let bad_unit = CoactivationTileUnit::new(
            "unit:bad",
            CoactivationTileUnitKind::KvPage,
            UasAddress::new(UasKind::KvPage, b"bad", CREATED_AT_MS),
            0,
            0,
            "raw",
            "blake3:bad",
            1,
            "F-ResidencyConstructionGraph",
        )
        .expect_err("empty byte range should reject");

        assert!(matches!(
            missing_rollback,
            CoactivationTileError::MissingRollback { .. }
        ));
        assert_eq!(
            bad_unit,
            CoactivationTileError::InvalidByteRange {
                unit_id: "unit:bad".to_string()
            }
        );
    }
}
