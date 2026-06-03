//! Cold assembly plans for 70B-lite constructive residency.
//!
//! This is a metadata-only admission surface. It composes the construction
//! graph, coactivation tiles, and proof-carrying leases into one bounded plan
//! that can be compared against dense-local, RAG-only, and static-route
//! baselines without waking model bytes or mutating live route policy.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};

use crate::uas::{CoactivationTile, ProofCarryingResidencyLease, UasAddress, UasKind};

const PLAN_UAS_KIND: &str = "cold_assembly_plan_70b_lite";
const FALLBACK_PREFIX: &str = "fallback:";
const ROLLBACK_PREFIX: &str = "rollback:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const BASELINE_NAMES: [&str; 3] = ["dense_local", "rag_only", "static_route"];

// UAS: uas/research-construction/cold-assembly-tile-role
// Plane: RuntimePlane::Assembly
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ColdAssemblyTileRole {
    Active,
    Warm,
    Cold,
}

// UAS: uas/research-construction/cold-assembly-tile-ref
// Plane: RuntimePlane::Assembly
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ColdAssemblyTileRef {
    pub tile_id: String,
    pub tile_address: UasAddress,
    pub role: ColdAssemblyTileRole,
    pub bytes: u64,
    pub kv_bytes: u64,
    pub adapter_bytes: u64,
}

impl ColdAssemblyTileRef {
    pub fn from_tile(
        tile: &CoactivationTile,
        role: ColdAssemblyTileRole,
        kv_bytes: u64,
        adapter_bytes: u64,
    ) -> Result<Self, ColdAssemblyPlanError> {
        if kv_bytes > tile.prefetch_cost_bytes || adapter_bytes > tile.prefetch_cost_bytes {
            return Err(ColdAssemblyPlanError::TileByteAccountingOverrun {
                tile_id: tile.tile_id.clone(),
            });
        }
        Ok(Self {
            tile_id: tile.tile_id.clone(),
            tile_address: tile.tile_address.clone(),
            role,
            bytes: tile.prefetch_cost_bytes,
            kv_bytes,
            adapter_bytes,
        })
    }
}

// UAS: uas/research-construction/cold-assembly-baseline
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ColdAssemblyBaseline {
    pub name: String,
    pub quality_bps: u16,
    pub evidence_validity_bps: u16,
    pub verifier_bps: u16,
    pub active_executed_bytes: u64,
    pub peak_rss_estimate_bytes: u64,
    pub cold_miss_count: u64,
    pub cold_stall_ms: u64,
    pub hidden_cloud: bool,
    pub dense_resident_overclaim: bool,
}

impl ColdAssemblyBaseline {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        name: impl Into<String>,
        quality_bps: u16,
        evidence_validity_bps: u16,
        verifier_bps: u16,
        active_executed_bytes: u64,
        peak_rss_estimate_bytes: u64,
        cold_miss_count: u64,
        cold_stall_ms: u64,
        hidden_cloud: bool,
        dense_resident_overclaim: bool,
    ) -> Result<Self, ColdAssemblyPlanError> {
        let name = name.into();
        validate_nonempty("baseline_name", &name)?;
        validate_score("quality_bps", quality_bps)?;
        validate_score("evidence_validity_bps", evidence_validity_bps)?;
        validate_score("verifier_bps", verifier_bps)?;
        Ok(Self {
            name,
            quality_bps,
            evidence_validity_bps,
            verifier_bps,
            active_executed_bytes,
            peak_rss_estimate_bytes,
            cold_miss_count,
            cold_stall_ms,
            hidden_cloud,
            dense_resident_overclaim,
        })
    }

    pub fn score_bps(&self) -> u16 {
        ((u32::from(self.quality_bps)
            + u32::from(self.evidence_validity_bps)
            + u32::from(self.verifier_bps))
            / 3) as u16
    }
}

// UAS: uas/research-construction/cold-assembly-plan
// Plane: RuntimePlane::Assembly
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ColdAssemblyPlan {
    pub plan_address: UasAddress,
    pub mission_id: String,
    pub construction_graph_ref: UasAddress,
    pub tile_refs: Vec<ColdAssemblyTileRef>,
    pub hot_bytes: u64,
    pub warm_bytes: u64,
    pub cold_bytes: u64,
    pub active_executed_bytes: u64,
    pub kv_bytes: u64,
    pub adapter_bytes: u64,
    pub peak_rss_estimate_bytes: u64,
    pub cold_miss_count: u64,
    pub cold_stall_ms: u64,
    pub prefetch_order: Vec<String>,
    pub skipped_cold_tile_ids: Vec<String>,
    pub proof_carrying_residency_leases: Vec<ProofCarryingResidencyLease>,
    pub verifier_stack: Vec<String>,
    pub fallback_route: String,
    pub rollback_ref: String,
    pub answer_packet_ref: String,
    pub quality_bps: u16,
    pub evidence_validity_bps: u16,
    pub verifier_bps: u16,
    pub baselines: Vec<ColdAssemblyBaseline>,
}

impl ColdAssemblyPlan {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        mission_id: impl Into<String>,
        construction_graph_ref: UasAddress,
        tile_refs: Vec<ColdAssemblyTileRef>,
        prefetch_order: Vec<String>,
        skipped_cold_tile_ids: Vec<String>,
        proof_carrying_residency_leases: Vec<ProofCarryingResidencyLease>,
        verifier_stack: Vec<String>,
        fallback_route: impl Into<String>,
        rollback_ref: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        quality_bps: u16,
        evidence_validity_bps: u16,
        verifier_bps: u16,
        baselines: Vec<ColdAssemblyBaseline>,
        created_at_ms: u64,
    ) -> Result<Self, ColdAssemblyPlanError> {
        let mission_id = mission_id.into();
        let fallback_route = fallback_route.into();
        let rollback_ref = rollback_ref.into();
        let answer_packet_ref = answer_packet_ref.into();
        validate_nonempty("mission_id", &mission_id)?;
        validate_nonempty("fallback_route", &fallback_route)?;
        validate_nonempty("rollback_ref", &rollback_ref)?;
        validate_nonempty("answer_packet_ref", &answer_packet_ref)?;
        if !fallback_route.starts_with(FALLBACK_PREFIX) {
            return Err(ColdAssemblyPlanError::InvalidFallbackRoute);
        }
        if !rollback_ref.starts_with(ROLLBACK_PREFIX) {
            return Err(ColdAssemblyPlanError::MissingRollback);
        }
        if !answer_packet_ref.starts_with(ANSWER_PACKET_PREFIX) {
            return Err(ColdAssemblyPlanError::MissingAnswerPacketRef);
        }
        validate_score("quality_bps", quality_bps)?;
        validate_score("evidence_validity_bps", evidence_validity_bps)?;
        validate_score("verifier_bps", verifier_bps)?;
        let tile_refs = canonicalize_tile_refs(tile_refs)?;
        let prefetch_order = canonicalize_strings("prefetch_order", prefetch_order)?;
        let skipped_cold_tile_ids =
            canonicalize_strings("skipped_cold_tile_ids", skipped_cold_tile_ids)?;
        let verifier_stack = canonicalize_strings("verifier_stack", verifier_stack)?;
        if verifier_stack.is_empty() {
            return Err(ColdAssemblyPlanError::MissingVerifierStack);
        }
        let proof_carrying_residency_leases = canonicalize_leases(proof_carrying_residency_leases)?;
        if proof_carrying_residency_leases.is_empty() {
            return Err(ColdAssemblyPlanError::MissingProofLease);
        }
        let baselines = canonicalize_baselines(baselines)?;
        let byte_totals = byte_totals(&tile_refs);
        if byte_totals.hot_bytes == 0 || byte_totals.cold_bytes == 0 {
            return Err(ColdAssemblyPlanError::MissingHotOrColdTiles);
        }
        validate_cold_wake_coverage(&tile_refs, &prefetch_order, &skipped_cold_tile_ids)?;
        validate_lease_coverage(&tile_refs, &proof_carrying_residency_leases)?;

        let peak_rss_estimate_bytes = byte_totals.hot_bytes
            + byte_totals.warm_bytes
            + byte_totals.kv_bytes
            + byte_totals.adapter_bytes;
        let cold_miss_count = skipped_cold_tile_ids.len() as u64;
        let cold_stall_ms = cold_miss_count * 7;
        let active_executed_bytes =
            byte_totals.hot_bytes + byte_totals.kv_bytes + byte_totals.adapter_bytes;

        let plan = Self {
            plan_address: plan_address(
                &mission_id,
                &construction_graph_ref,
                &tile_refs,
                &prefetch_order,
                &skipped_cold_tile_ids,
                &proof_carrying_residency_leases,
                &verifier_stack,
                &fallback_route,
                &rollback_ref,
                &answer_packet_ref,
                quality_bps,
                evidence_validity_bps,
                verifier_bps,
                &baselines,
                created_at_ms,
            ),
            mission_id,
            construction_graph_ref,
            tile_refs,
            hot_bytes: byte_totals.hot_bytes,
            warm_bytes: byte_totals.warm_bytes,
            cold_bytes: byte_totals.cold_bytes,
            active_executed_bytes,
            kv_bytes: byte_totals.kv_bytes,
            adapter_bytes: byte_totals.adapter_bytes,
            peak_rss_estimate_bytes,
            cold_miss_count,
            cold_stall_ms,
            prefetch_order,
            skipped_cold_tile_ids,
            proof_carrying_residency_leases,
            verifier_stack,
            fallback_route,
            rollback_ref,
            answer_packet_ref,
            quality_bps,
            evidence_validity_bps,
            verifier_bps,
            baselines,
        };
        if !plan.beats_all_baselines() {
            return Err(ColdAssemblyPlanError::BaselineNotBeaten);
        }
        Ok(plan)
    }

    pub fn score_bps(&self) -> u16 {
        ((u32::from(self.quality_bps)
            + u32::from(self.evidence_validity_bps)
            + u32::from(self.verifier_bps))
            / 3) as u16
    }

    pub fn beats_all_baselines(&self) -> bool {
        let plan_score = self.score_bps();
        self.baselines.iter().all(|baseline| {
            plan_score > baseline.score_bps()
                && self.quality_bps > baseline.quality_bps
                && self.evidence_validity_bps > baseline.evidence_validity_bps
                && self.verifier_bps > baseline.verifier_bps
                && self.active_executed_bytes < baseline.active_executed_bytes
                && self.peak_rss_estimate_bytes < baseline.peak_rss_estimate_bytes
                && self.cold_stall_ms < baseline.cold_stall_ms
                && !baseline.hidden_cloud
                && !baseline.dense_resident_overclaim
        })
    }

    pub fn baseline(&self, name: &str) -> Option<&ColdAssemblyBaseline> {
        self.baselines.iter().find(|baseline| baseline.name == name)
    }
}

// UAS: uas/research-construction/cold-assembly-byte-totals
// Plane: RuntimePlane::Assembly
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, Default, PartialEq, Eq)]
struct ByteTotals {
    hot_bytes: u64,
    warm_bytes: u64,
    cold_bytes: u64,
    kv_bytes: u64,
    adapter_bytes: u64,
}

// UAS: uas/research-construction/cold-assembly-plan-error
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ColdAssemblyPlanError {
    MissingMissionId,
    MissingTileRef,
    MissingHotOrColdTiles,
    MissingProofLease,
    MissingVerifierStack,
    MissingFallbackRoute,
    MissingRollback,
    MissingAnswerPacketRef,
    InvalidFallbackRoute,
    InvalidBaselineSet,
    DuplicateTileId { tile_id: String },
    DuplicateLeaseUnitId { unit_id: String },
    DuplicateBaseline { name: String },
    UnknownColdTileInPrefetch { tile_id: String },
    ColdTileWakeUnaccounted { tile_id: String },
    MissingLeaseForColdUnit { unit_id: String },
    TileByteAccountingOverrun { tile_id: String },
    ScoreOutOfRange { field: &'static str },
    BaselineNotBeaten,
    FieldHasSurroundingWhitespace { field: &'static str },
    FieldContainsControlCharacter { field: &'static str },
}

impl std::fmt::Display for ColdAssemblyPlanError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::MissingMissionId => write!(f, "mission_id is required"),
            Self::MissingTileRef => write!(f, "at least one tile ref is required"),
            Self::MissingHotOrColdTiles => write!(f, "active and cold tile refs are required"),
            Self::MissingProofLease => write!(f, "at least one proof-carrying lease is required"),
            Self::MissingVerifierStack => write!(f, "verifier_stack is required"),
            Self::MissingFallbackRoute => write!(f, "fallback_route is required"),
            Self::MissingRollback => write!(f, "rollback_ref is required"),
            Self::MissingAnswerPacketRef => write!(f, "answer_packet_ref is required"),
            Self::InvalidFallbackRoute => {
                write!(f, "fallback_route must use the fallback: prefix")
            }
            Self::InvalidBaselineSet => write!(
                f,
                "baselines must contain dense_local, rag_only, and static_route"
            ),
            Self::DuplicateTileId { tile_id } => write!(f, "duplicate tile id: {tile_id}"),
            Self::DuplicateLeaseUnitId { unit_id } => {
                write!(f, "duplicate proof lease unit id: {unit_id}")
            }
            Self::DuplicateBaseline { name } => write!(f, "duplicate baseline: {name}"),
            Self::UnknownColdTileInPrefetch { tile_id } => {
                write!(f, "prefetch or skip references unknown cold tile {tile_id}")
            }
            Self::ColdTileWakeUnaccounted { tile_id } => {
                write!(f, "cold tile {tile_id} must be scheduled or skipped")
            }
            Self::MissingLeaseForColdUnit { unit_id } => {
                write!(f, "cold unit {unit_id} needs proof-carrying lease")
            }
            Self::TileByteAccountingOverrun { tile_id } => {
                write!(f, "tile {tile_id} has invalid byte subaccounting")
            }
            Self::ScoreOutOfRange { field } => write!(f, "{field} must be <= 10000 bps"),
            Self::BaselineNotBeaten => write!(f, "plan does not beat every baseline"),
            Self::FieldHasSurroundingWhitespace { field } => {
                write!(f, "{field} must not contain leading or trailing whitespace")
            }
            Self::FieldContainsControlCharacter { field } => {
                write!(f, "{field} must not contain control characters")
            }
        }
    }
}

impl std::error::Error for ColdAssemblyPlanError {}

fn canonicalize_tile_refs(
    mut tile_refs: Vec<ColdAssemblyTileRef>,
) -> Result<Vec<ColdAssemblyTileRef>, ColdAssemblyPlanError> {
    if tile_refs.is_empty() {
        return Err(ColdAssemblyPlanError::MissingTileRef);
    }
    let mut seen = HashSet::new();
    for tile in &tile_refs {
        validate_nonempty("tile_id", &tile.tile_id)?;
        if !seen.insert(tile.tile_id.clone()) {
            return Err(ColdAssemblyPlanError::DuplicateTileId {
                tile_id: tile.tile_id.clone(),
            });
        }
    }
    tile_refs.sort_by(|left, right| left.tile_id.cmp(&right.tile_id));
    Ok(tile_refs)
}

fn canonicalize_strings(
    field: &'static str,
    values: Vec<String>,
) -> Result<Vec<String>, ColdAssemblyPlanError> {
    let mut canonical = Vec::with_capacity(values.len());
    let mut seen = HashSet::new();
    for value in values {
        validate_nonempty(field, &value)?;
        if seen.insert(value.clone()) {
            canonical.push(value);
        }
    }
    canonical.sort();
    Ok(canonical)
}

fn canonicalize_leases(
    mut leases: Vec<ProofCarryingResidencyLease>,
) -> Result<Vec<ProofCarryingResidencyLease>, ColdAssemblyPlanError> {
    let mut seen = HashSet::new();
    for lease in &leases {
        if !seen.insert(lease.unit_id.clone()) {
            return Err(ColdAssemblyPlanError::DuplicateLeaseUnitId {
                unit_id: lease.unit_id.clone(),
            });
        }
    }
    leases.sort_by(|left, right| left.unit_id.cmp(&right.unit_id));
    Ok(leases)
}

fn canonicalize_baselines(
    mut baselines: Vec<ColdAssemblyBaseline>,
) -> Result<Vec<ColdAssemblyBaseline>, ColdAssemblyPlanError> {
    let mut seen = BTreeSet::new();
    for baseline in &baselines {
        if !seen.insert(baseline.name.clone()) {
            return Err(ColdAssemblyPlanError::DuplicateBaseline {
                name: baseline.name.clone(),
            });
        }
    }
    if BASELINE_NAMES.iter().any(|name| !seen.contains(*name)) {
        return Err(ColdAssemblyPlanError::InvalidBaselineSet);
    }
    baselines.sort_by(|left, right| left.name.cmp(&right.name));
    Ok(baselines)
}

fn byte_totals(tile_refs: &[ColdAssemblyTileRef]) -> ByteTotals {
    let mut totals = ByteTotals::default();
    for tile in tile_refs {
        match tile.role {
            ColdAssemblyTileRole::Active => totals.hot_bytes += tile.bytes,
            ColdAssemblyTileRole::Warm => totals.warm_bytes += tile.bytes,
            ColdAssemblyTileRole::Cold => totals.cold_bytes += tile.bytes,
        }
        totals.kv_bytes += tile.kv_bytes;
        totals.adapter_bytes += tile.adapter_bytes;
    }
    totals
}

fn validate_cold_wake_coverage(
    tile_refs: &[ColdAssemblyTileRef],
    prefetch_order: &[String],
    skipped_cold_tile_ids: &[String],
) -> Result<(), ColdAssemblyPlanError> {
    let cold_tile_ids = tile_refs
        .iter()
        .filter(|tile| tile.role == ColdAssemblyTileRole::Cold)
        .map(|tile| tile.tile_id.as_str())
        .collect::<BTreeSet<_>>();
    let scheduled = prefetch_order
        .iter()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    let skipped = skipped_cold_tile_ids
        .iter()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    for tile_id in scheduled.iter().chain(skipped.iter()) {
        if !cold_tile_ids.contains(tile_id) {
            return Err(ColdAssemblyPlanError::UnknownColdTileInPrefetch {
                tile_id: (*tile_id).to_string(),
            });
        }
    }
    for tile_id in cold_tile_ids {
        if !scheduled.contains(tile_id) && !skipped.contains(tile_id) {
            return Err(ColdAssemblyPlanError::ColdTileWakeUnaccounted {
                tile_id: tile_id.to_string(),
            });
        }
    }
    Ok(())
}

fn validate_lease_coverage(
    tile_refs: &[ColdAssemblyTileRef],
    leases: &[ProofCarryingResidencyLease],
) -> Result<(), ColdAssemblyPlanError> {
    let lease_unit_ids = leases
        .iter()
        .map(|lease| lease.unit_id.as_str())
        .collect::<BTreeSet<_>>();
    for tile in tile_refs {
        if tile.role != ColdAssemblyTileRole::Cold {
            continue;
        }
        if !lease_unit_ids.contains(tile.tile_id.as_str()) {
            return Err(ColdAssemblyPlanError::MissingLeaseForColdUnit {
                unit_id: tile.tile_id.clone(),
            });
        }
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn plan_address(
    mission_id: &str,
    graph_ref: &UasAddress,
    tile_refs: &[ColdAssemblyTileRef],
    prefetch_order: &[String],
    skipped_cold_tile_ids: &[String],
    leases: &[ProofCarryingResidencyLease],
    verifier_stack: &[String],
    fallback_route: &str,
    rollback_ref: &str,
    answer_packet_ref: &str,
    quality_bps: u16,
    evidence_validity_bps: u16,
    verifier_bps: u16,
    baselines: &[ColdAssemblyBaseline],
    created_at_ms: u64,
) -> UasAddress {
    let mut preimage = String::new();
    preimage.push_str("cold_assembly_plan_70b_lite_v1\n");
    push_preimage(&mut preimage, "mission_id", mission_id);
    push_preimage(&mut preimage, "graph_ref", &graph_ref.to_string());
    for tile in tile_refs {
        push_preimage(
            &mut preimage,
            "tile",
            &format!(
                "{}:{}:{}:{}:{}:{}",
                tile.tile_id,
                tile.tile_address,
                role_wire(tile.role),
                tile.bytes,
                tile.kv_bytes,
                tile.adapter_bytes
            ),
        );
    }
    push_preimage(&mut preimage, "prefetch_order", &prefetch_order.join(","));
    push_preimage(
        &mut preimage,
        "skipped_cold_tile_ids",
        &skipped_cold_tile_ids.join(","),
    );
    for lease in leases {
        push_preimage(
            &mut preimage,
            "lease",
            &format!("{}:{}", lease.unit_id, lease.lease_address),
        );
    }
    push_preimage(&mut preimage, "verifier_stack", &verifier_stack.join(","));
    push_preimage(&mut preimage, "fallback_route", fallback_route);
    push_preimage(&mut preimage, "rollback_ref", rollback_ref);
    push_preimage(&mut preimage, "answer_packet_ref", answer_packet_ref);
    push_preimage(&mut preimage, "quality_bps", &quality_bps.to_string());
    push_preimage(
        &mut preimage,
        "evidence_validity_bps",
        &evidence_validity_bps.to_string(),
    );
    push_preimage(&mut preimage, "verifier_bps", &verifier_bps.to_string());
    for baseline in baselines {
        push_preimage(
            &mut preimage,
            "baseline",
            &format!(
                "{}:{}:{}:{}:{}:{}:{}:{}:{}:{}",
                baseline.name,
                baseline.quality_bps,
                baseline.evidence_validity_bps,
                baseline.verifier_bps,
                baseline.active_executed_bytes,
                baseline.peak_rss_estimate_bytes,
                baseline.cold_miss_count,
                baseline.cold_stall_ms,
                baseline.hidden_cloud,
                baseline.dense_resident_overclaim
            ),
        );
    }
    UasAddress::new(
        UasKind::Other(PLAN_UAS_KIND.to_string()),
        preimage.as_bytes(),
        created_at_ms,
    )
}

fn push_preimage(preimage: &mut String, key: &str, value: &str) {
    preimage.push_str(key);
    preimage.push('=');
    preimage.push_str(value);
    preimage.push('\n');
}

fn role_wire(role: ColdAssemblyTileRole) -> &'static str {
    match role {
        ColdAssemblyTileRole::Active => "active",
        ColdAssemblyTileRole::Warm => "warm",
        ColdAssemblyTileRole::Cold => "cold",
    }
}

fn validate_nonempty(field: &'static str, value: &str) -> Result<(), ColdAssemblyPlanError> {
    if value.trim().is_empty() {
        return match field {
            "mission_id" => Err(ColdAssemblyPlanError::MissingMissionId),
            "fallback_route" => Err(ColdAssemblyPlanError::MissingFallbackRoute),
            "rollback_ref" => Err(ColdAssemblyPlanError::MissingRollback),
            "answer_packet_ref" => Err(ColdAssemblyPlanError::MissingAnswerPacketRef),
            _ => Err(ColdAssemblyPlanError::FieldContainsControlCharacter { field }),
        };
    }
    if value.trim() != value {
        return Err(ColdAssemblyPlanError::FieldHasSurroundingWhitespace { field });
    }
    if value.chars().any(char::is_control) {
        return Err(ColdAssemblyPlanError::FieldContainsControlCharacter { field });
    }
    Ok(())
}

fn validate_score(field: &'static str, value: u16) -> Result<(), ColdAssemblyPlanError> {
    if value > 10_000 {
        Err(ColdAssemblyPlanError::ScoreOutOfRange { field })
    } else {
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::{CoactivationTileUnit, CoactivationTileUnitKind, UasKind};

    const CREATED_AT_MS: u64 = 1_779_300_000_000;

    fn tile(tile_id: &str, role: ColdAssemblyTileRole, bytes: u64) -> ColdAssemblyTileRef {
        let tile = CoactivationTile::new(
            tile_id,
            "memory:70b-lite-fixture",
            vec![CoactivationTileUnit::new(
                tile_id,
                CoactivationTileUnitKind::EvidenceBundle,
                UasAddress::new(UasKind::KvPage, tile_id.as_bytes(), CREATED_AT_MS),
                0,
                bytes,
                "raw",
                "blake3:fixture",
                100,
                "F-ColdAssemblyPlan-70B-Lite",
            )
            .unwrap()],
            vec!["F-ColdAssemblyPlan-70B-Lite".to_string()],
            "rollback:tile",
            CREATED_AT_MS,
        )
        .unwrap();
        ColdAssemblyTileRef::from_tile(&tile, role, 1024.min(bytes), 0).unwrap()
    }

    fn lease(unit_id: &str) -> ProofCarryingResidencyLease {
        ProofCarryingResidencyLease::new(
            unit_id,
            UasAddress::new(UasKind::KvPage, unit_id.as_bytes(), CREATED_AT_MS),
            "cold assembly needs this unit",
            1024,
            9000,
            "F-ProofCarryingResidencyLease",
            "fallback:skip",
            "rollback:drop",
            CREATED_AT_MS,
            1000,
        )
        .unwrap()
    }

    fn baselines() -> Vec<ColdAssemblyBaseline> {
        vec![
            ColdAssemblyBaseline::new(
                "dense_local",
                8200,
                8100,
                8000,
                1_000_000,
                900_000,
                6,
                120,
                false,
                false,
            )
            .unwrap(),
            ColdAssemblyBaseline::new(
                "rag_only", 7600, 7400, 6900, 300_000, 250_000, 5, 100, false, false,
            )
            .unwrap(),
            ColdAssemblyBaseline::new(
                "static_route",
                7900,
                7800,
                7300,
                500_000,
                400_000,
                4,
                80,
                false,
                false,
            )
            .unwrap(),
        ]
    }

    fn plan() -> ColdAssemblyPlan {
        ColdAssemblyPlan::new(
            "mission:70b-lite",
            UasAddress::new(
                UasKind::Other("residency_graph".to_string()),
                b"graph",
                CREATED_AT_MS,
            ),
            vec![
                tile(
                    "unit:hot-controller",
                    ColdAssemblyTileRole::Active,
                    64 * 1024,
                ),
                tile("unit:warm-adapter", ColdAssemblyTileRole::Warm, 16 * 1024),
                tile("unit:cold-evidence", ColdAssemblyTileRole::Cold, 32 * 1024),
                tile("unit:verifier-lane", ColdAssemblyTileRole::Cold, 8 * 1024),
            ],
            vec![
                "unit:cold-evidence".to_string(),
                "unit:verifier-lane".to_string(),
            ],
            vec![],
            vec![lease("unit:cold-evidence"), lease("unit:verifier-lane")],
            vec!["F-ProofCarryingResidencyLease".to_string()],
            "fallback:rag-only-abstain",
            "rollback:restore-hot-controller",
            "answer_packet:70b-lite-plan",
            8800,
            8750,
            8600,
            baselines(),
            CREATED_AT_MS,
        )
        .unwrap()
    }

    #[test]
    fn cold_assembly_plan_beats_baselines() {
        let plan = plan();
        assert!(plan.beats_all_baselines());
        assert_eq!(plan.cold_miss_count, 0);
        assert_eq!(plan.proof_carrying_residency_leases.len(), 2);
    }

    #[test]
    fn cold_assembly_plan_address_is_deterministic() {
        let first = plan();
        let second = plan();
        assert_eq!(first.plan_address, second.plan_address);
    }

    #[test]
    fn cold_assembly_plan_requires_cold_wake_coverage() {
        let error = ColdAssemblyPlan::new(
            "mission:bad",
            UasAddress::new(
                UasKind::Other("residency_graph".to_string()),
                b"graph",
                CREATED_AT_MS,
            ),
            vec![
                tile(
                    "unit:hot-controller",
                    ColdAssemblyTileRole::Active,
                    64 * 1024,
                ),
                tile("unit:cold-evidence", ColdAssemblyTileRole::Cold, 32 * 1024),
            ],
            vec![],
            vec![],
            vec![lease("unit:cold-evidence")],
            vec!["F-ProofCarryingResidencyLease".to_string()],
            "fallback:rag-only-abstain",
            "rollback:restore-hot-controller",
            "answer_packet:bad",
            8800,
            8750,
            8600,
            baselines(),
            CREATED_AT_MS,
        )
        .expect_err("unscheduled cold tile should fail");
        assert!(matches!(
            error,
            ColdAssemblyPlanError::ColdTileWakeUnaccounted { .. }
        ));
    }

    #[test]
    fn cold_assembly_plan_requires_proof_lease_for_cold_unit() {
        let error = ColdAssemblyPlan::new(
            "mission:bad",
            UasAddress::new(
                UasKind::Other("residency_graph".to_string()),
                b"graph",
                CREATED_AT_MS,
            ),
            vec![
                tile(
                    "unit:hot-controller",
                    ColdAssemblyTileRole::Active,
                    64 * 1024,
                ),
                tile("unit:cold-evidence", ColdAssemblyTileRole::Cold, 32 * 1024),
            ],
            vec!["unit:cold-evidence".to_string()],
            vec![],
            vec![],
            vec!["F-ProofCarryingResidencyLease".to_string()],
            "fallback:rag-only-abstain",
            "rollback:restore-hot-controller",
            "answer_packet:bad",
            8800,
            8750,
            8600,
            baselines(),
            CREATED_AT_MS,
        )
        .expect_err("missing lease should fail");
        assert!(matches!(error, ColdAssemblyPlanError::MissingProofLease));
    }

    #[test]
    fn cold_assembly_plan_rejects_unbeaten_baseline() {
        let mut baselines = baselines();
        baselines.retain(|baseline| baseline.name != "dense_local");
        baselines.push(
            ColdAssemblyBaseline::new(
                "dense_local",
                9900,
                9900,
                9900,
                1_000_000,
                900_000,
                6,
                120,
                false,
                false,
            )
            .unwrap(),
        );
        let error = ColdAssemblyPlan::new(
            "mission:bad",
            UasAddress::new(
                UasKind::Other("residency_graph".to_string()),
                b"graph",
                CREATED_AT_MS,
            ),
            vec![
                tile(
                    "unit:hot-controller",
                    ColdAssemblyTileRole::Active,
                    64 * 1024,
                ),
                tile("unit:cold-evidence", ColdAssemblyTileRole::Cold, 32 * 1024),
            ],
            vec!["unit:cold-evidence".to_string()],
            vec![],
            vec![lease("unit:cold-evidence")],
            vec!["F-ProofCarryingResidencyLease".to_string()],
            "fallback:rag-only-abstain",
            "rollback:restore-hot-controller",
            "answer_packet:bad",
            8800,
            8750,
            8600,
            baselines,
            CREATED_AT_MS,
        )
        .expect_err("unbeaten strong baseline should fail comparison");
        assert!(matches!(error, ColdAssemblyPlanError::BaselineNotBeaten));
    }
}
