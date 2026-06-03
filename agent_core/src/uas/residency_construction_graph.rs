//! Dry-run construction graph for Research Construction Engine residency plans.
//!
//! This is a metadata-only planner surface. It scores candidate assemblies
//! against byte, verifier, incompatibility, and cold-miss constraints without
//! waking model bytes, touching mmap files, running MLX/Metal, or mutating live
//! route policy.

use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet, HashSet};

use crate::uas::{UasAddress, UasKind};

const GRAPH_UAS_KIND: &str = "residency_construction_graph";
const UNIT_UAS_KIND: &str = "residency_construction_unit";
const MAX_SCORE_BPS: u16 = 10_000;

// UAS: uas/research-construction/budget
// Plane: RuntimePlane::Controller
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ResidencyConstructionBudget {
    pub hot_uma_bytes: u64,
    pub warm_uma_bytes: u64,
    pub cold_ssd_bytes: u64,
    pub max_cold_misses: u64,
    pub max_cold_stall_ms: u64,
}

impl ResidencyConstructionBudget {
    pub fn m2_pro_dry_run() -> Self {
        Self {
            hot_uma_bytes: 512 * 1024 * 1024,
            warm_uma_bytes: 1024 * 1024 * 1024,
            cold_ssd_bytes: 4 * 1024 * 1024 * 1024,
            max_cold_misses: 8,
            max_cold_stall_ms: 250,
        }
    }
}

// UAS: uas/research-construction/unit
// Plane: RuntimePlane::Assembly
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ResidencyConstructionUnit {
    pub unit_id: String,
    pub unit_address: UasAddress,
    pub source_card_id: String,
    pub hot_bytes: u64,
    pub warm_bytes: u64,
    pub cold_bytes: u64,
    pub quality_bps: u16,
    pub evidence_validity_bps: u16,
    pub verifier_bps: u16,
    pub rollback_ref: String,
}

impl ResidencyConstructionUnit {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        unit_id: impl Into<String>,
        source_card_id: impl Into<String>,
        hot_bytes: u64,
        warm_bytes: u64,
        cold_bytes: u64,
        quality_bps: u16,
        evidence_validity_bps: u16,
        verifier_bps: u16,
        rollback_ref: impl Into<String>,
        created_at_ms: u64,
    ) -> Result<Self, ResidencyConstructionGraphError> {
        let unit_id = unit_id.into();
        let source_card_id = source_card_id.into();
        let rollback_ref = rollback_ref.into();
        validate_nonempty("unit_id", &unit_id)?;
        validate_nonempty("source_card_id", &source_card_id)?;
        validate_nonempty("rollback_ref", &rollback_ref)?;
        validate_score("quality_bps", quality_bps)?;
        validate_score("evidence_validity_bps", evidence_validity_bps)?;
        validate_score("verifier_bps", verifier_bps)?;
        if hot_bytes == 0 && warm_bytes == 0 && cold_bytes == 0 {
            return Err(ResidencyConstructionGraphError::EmptyUnitBytes {
                unit_id: unit_id.clone(),
            });
        }
        let preimage = format!(
            "{UNIT_UAS_KIND}\n{unit_id}\n{source_card_id}\n{hot_bytes}:{warm_bytes}:{cold_bytes}\n{quality_bps}:{evidence_validity_bps}:{verifier_bps}\n{rollback_ref}"
        );
        Ok(Self {
            unit_id,
            unit_address: UasAddress::new(
                UasKind::Other(UNIT_UAS_KIND.to_string()),
                preimage.as_bytes(),
                created_at_ms,
            ),
            source_card_id,
            hot_bytes,
            warm_bytes,
            cold_bytes,
            quality_bps,
            evidence_validity_bps,
            verifier_bps,
            rollback_ref,
        })
    }

    fn raw_score_bps(&self) -> u32 {
        u32::from(self.quality_bps)
            + u32::from(self.evidence_validity_bps)
            + u32::from(self.verifier_bps)
    }
}

// UAS: uas/research-construction/coactivation-edge
// Plane: RuntimePlane::Assembly
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CoactivationEdge {
    pub from_unit_id: String,
    pub to_unit_id: String,
    pub affinity_bps: u16,
}

impl CoactivationEdge {
    pub fn new(
        from_unit_id: impl Into<String>,
        to_unit_id: impl Into<String>,
        affinity_bps: u16,
    ) -> Result<Self, ResidencyConstructionGraphError> {
        let from_unit_id = from_unit_id.into();
        let to_unit_id = to_unit_id.into();
        validate_nonempty("unit_id", &from_unit_id)?;
        validate_nonempty("unit_id", &to_unit_id)?;
        validate_score("affinity_bps", affinity_bps)?;
        Ok(Self {
            from_unit_id,
            to_unit_id,
            affinity_bps,
        })
    }
}

// UAS: uas/research-construction/incompatibility-edge
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct IncompatibilityEdge {
    pub left_unit_id: String,
    pub right_unit_id: String,
    pub reason: String,
}

impl IncompatibilityEdge {
    pub fn new(
        left_unit_id: impl Into<String>,
        right_unit_id: impl Into<String>,
        reason: impl Into<String>,
    ) -> Result<Self, ResidencyConstructionGraphError> {
        let left_unit_id = left_unit_id.into();
        let right_unit_id = right_unit_id.into();
        let reason = reason.into();
        validate_nonempty("unit_id", &left_unit_id)?;
        validate_nonempty("unit_id", &right_unit_id)?;
        validate_nonempty("incompatibility_reason", &reason)?;
        Ok(Self {
            left_unit_id,
            right_unit_id,
            reason,
        })
    }
}

// UAS: uas/research-construction/verifier-edge
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct VerifierEdge {
    pub unit_id: String,
    pub verifier_id: String,
    pub verifier_score_bps: u16,
}

impl VerifierEdge {
    pub fn new(
        unit_id: impl Into<String>,
        verifier_id: impl Into<String>,
        verifier_score_bps: u16,
    ) -> Result<Self, ResidencyConstructionGraphError> {
        let unit_id = unit_id.into();
        let verifier_id = verifier_id.into();
        validate_nonempty("unit_id", &unit_id)?;
        validate_nonempty("verifier_id", &verifier_id)?;
        validate_score("verifier_score_bps", verifier_score_bps)?;
        Ok(Self {
            unit_id,
            verifier_id,
            verifier_score_bps,
        })
    }
}

// UAS: uas/research-construction/cold-miss
// Plane: RuntimePlane::Episodic
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ColdMissRecord {
    pub unit_id: String,
    pub miss_count: u64,
    pub stall_ms: u64,
}

impl ColdMissRecord {
    pub fn new(
        unit_id: impl Into<String>,
        miss_count: u64,
        stall_ms: u64,
    ) -> Result<Self, ResidencyConstructionGraphError> {
        let unit_id = unit_id.into();
        validate_nonempty("unit_id", &unit_id)?;
        Ok(Self {
            unit_id,
            miss_count,
            stall_ms,
        })
    }
}

// UAS: uas/research-construction/assembly-score
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AssemblyScore {
    pub selected_unit_ids: Vec<String>,
    pub rejected_unit_ids: Vec<String>,
    pub hot_resident_bytes: u64,
    pub warm_bytes: u64,
    pub cold_bytes: u64,
    pub cold_miss_count: u64,
    pub cold_stall_ms: u64,
    pub quality_bps: u16,
    pub evidence_validity_bps: u16,
    pub verifier_bps: u16,
    pub score_bps: u16,
}

// UAS: uas/research-construction/graph
// Plane: RuntimePlane::Assembly
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ResidencyConstructionGraph {
    pub graph_address: UasAddress,
    pub task_signature: String,
    pub candidate_units: Vec<ResidencyConstructionUnit>,
    pub coactivation_edges: Vec<CoactivationEdge>,
    pub incompatibility_edges: Vec<IncompatibilityEdge>,
    pub verifier_edges: Vec<VerifierEdge>,
    pub cold_miss_history: Vec<ColdMissRecord>,
    pub budget: ResidencyConstructionBudget,
    pub assembly_score: AssemblyScore,
}

impl ResidencyConstructionGraph {
    pub fn score(
        task_signature: impl Into<String>,
        candidate_units: Vec<ResidencyConstructionUnit>,
        coactivation_edges: Vec<CoactivationEdge>,
        incompatibility_edges: Vec<IncompatibilityEdge>,
        verifier_edges: Vec<VerifierEdge>,
        cold_miss_history: Vec<ColdMissRecord>,
        budget: ResidencyConstructionBudget,
        created_at_ms: u64,
    ) -> Result<Self, ResidencyConstructionGraphError> {
        let task_signature = task_signature.into();
        validate_nonempty("task_signature", &task_signature)?;
        if candidate_units.is_empty() {
            return Err(ResidencyConstructionGraphError::MissingCandidateUnit);
        }

        let candidate_units = canonicalize_units(candidate_units)?;
        let coactivation_edges = canonicalize_coactivation_edges(coactivation_edges);
        let incompatibility_edges = canonicalize_incompatibility_edges(incompatibility_edges);
        let verifier_edges = canonicalize_verifier_edges(verifier_edges);
        let cold_miss_history = canonicalize_cold_miss_history(cold_miss_history);
        validate_references(
            &candidate_units,
            &coactivation_edges,
            &incompatibility_edges,
            &verifier_edges,
            &cold_miss_history,
        )?;
        let assembly_score = compute_assembly_score(
            &candidate_units,
            &coactivation_edges,
            &incompatibility_edges,
            &verifier_edges,
            &cold_miss_history,
            &budget,
        )?;
        let graph_address = graph_address(
            &task_signature,
            &candidate_units,
            &coactivation_edges,
            &incompatibility_edges,
            &verifier_edges,
            &cold_miss_history,
            &budget,
            &assembly_score,
            created_at_ms,
        );

        Ok(Self {
            graph_address,
            task_signature,
            candidate_units,
            coactivation_edges,
            incompatibility_edges,
            verifier_edges,
            cold_miss_history,
            budget,
            assembly_score,
        })
    }
}

// UAS: uas/research-construction/error
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ResidencyConstructionGraphError {
    MissingTaskSignature,
    MissingCandidateUnit,
    MissingRollback { unit_id: String },
    EmptyUnitBytes { unit_id: String },
    DuplicateUnitId { unit_id: String },
    UnknownUnitReference { unit_id: String },
    ScoreOutOfRange { field: &'static str },
    FieldHasSurroundingWhitespace { field: &'static str },
    FieldContainsControlCharacter { field: &'static str },
    BudgetExceeded { unit_id: String },
    NoValidAssembly,
}

impl std::fmt::Display for ResidencyConstructionGraphError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::MissingTaskSignature => write!(f, "task_signature is required"),
            Self::MissingCandidateUnit => write!(f, "at least one candidate unit is required"),
            Self::MissingRollback { unit_id } => {
                write!(f, "unit {unit_id} requires a rollback reference")
            }
            Self::EmptyUnitBytes { unit_id } => {
                write!(f, "unit {unit_id} must declare at least one byte")
            }
            Self::DuplicateUnitId { unit_id } => write!(f, "duplicate unit id: {unit_id}"),
            Self::UnknownUnitReference { unit_id } => {
                write!(f, "edge or history references unknown unit id: {unit_id}")
            }
            Self::ScoreOutOfRange { field } => write!(f, "{field} must be <= 10000 bps"),
            Self::FieldHasSurroundingWhitespace { field } => {
                write!(f, "{field} must not contain leading or trailing whitespace")
            }
            Self::FieldContainsControlCharacter { field } => {
                write!(f, "{field} must not contain control characters")
            }
            Self::BudgetExceeded { unit_id } => write!(f, "unit {unit_id} exceeds budget"),
            Self::NoValidAssembly => write!(f, "no valid assembly could be selected"),
        }
    }
}

impl std::error::Error for ResidencyConstructionGraphError {}

fn canonicalize_units(
    units: Vec<ResidencyConstructionUnit>,
) -> Result<Vec<ResidencyConstructionUnit>, ResidencyConstructionGraphError> {
    let mut seen = HashSet::new();
    let mut canonical = Vec::with_capacity(units.len());
    for unit in units {
        if !seen.insert(unit.unit_id.clone()) {
            return Err(ResidencyConstructionGraphError::DuplicateUnitId {
                unit_id: unit.unit_id,
            });
        }
        if unit.rollback_ref.trim().is_empty() {
            return Err(ResidencyConstructionGraphError::MissingRollback {
                unit_id: unit.unit_id,
            });
        }
        canonical.push(unit);
    }
    canonical.sort_by(|a, b| a.unit_id.cmp(&b.unit_id));
    Ok(canonical)
}

fn canonicalize_coactivation_edges(mut edges: Vec<CoactivationEdge>) -> Vec<CoactivationEdge> {
    for edge in &mut edges {
        if edge.from_unit_id > edge.to_unit_id {
            std::mem::swap(&mut edge.from_unit_id, &mut edge.to_unit_id);
        }
    }
    edges.sort_by(|a, b| {
        (&a.from_unit_id, &a.to_unit_id, a.affinity_bps).cmp(&(
            &b.from_unit_id,
            &b.to_unit_id,
            b.affinity_bps,
        ))
    });
    edges.dedup();
    edges
}

fn canonicalize_incompatibility_edges(
    mut edges: Vec<IncompatibilityEdge>,
) -> Vec<IncompatibilityEdge> {
    for edge in &mut edges {
        if edge.left_unit_id > edge.right_unit_id {
            std::mem::swap(&mut edge.left_unit_id, &mut edge.right_unit_id);
        }
    }
    edges.sort_by(|a, b| {
        (&a.left_unit_id, &a.right_unit_id, &a.reason).cmp(&(
            &b.left_unit_id,
            &b.right_unit_id,
            &b.reason,
        ))
    });
    edges.dedup();
    edges
}

fn canonicalize_verifier_edges(mut edges: Vec<VerifierEdge>) -> Vec<VerifierEdge> {
    edges.sort_by(|a, b| {
        (&a.unit_id, &a.verifier_id, a.verifier_score_bps).cmp(&(
            &b.unit_id,
            &b.verifier_id,
            b.verifier_score_bps,
        ))
    });
    edges.dedup();
    edges
}

fn canonicalize_cold_miss_history(mut history: Vec<ColdMissRecord>) -> Vec<ColdMissRecord> {
    history.sort_by(|a, b| {
        (&a.unit_id, a.miss_count, a.stall_ms).cmp(&(&b.unit_id, b.miss_count, b.stall_ms))
    });
    history.dedup();
    history
}

fn validate_references(
    units: &[ResidencyConstructionUnit],
    coactivation_edges: &[CoactivationEdge],
    incompatibility_edges: &[IncompatibilityEdge],
    verifier_edges: &[VerifierEdge],
    cold_miss_history: &[ColdMissRecord],
) -> Result<(), ResidencyConstructionGraphError> {
    let unit_ids = units
        .iter()
        .map(|unit| unit.unit_id.as_str())
        .collect::<HashSet<_>>();
    for edge in coactivation_edges {
        require_unit(&unit_ids, &edge.from_unit_id)?;
        require_unit(&unit_ids, &edge.to_unit_id)?;
    }
    for edge in incompatibility_edges {
        require_unit(&unit_ids, &edge.left_unit_id)?;
        require_unit(&unit_ids, &edge.right_unit_id)?;
    }
    for edge in verifier_edges {
        require_unit(&unit_ids, &edge.unit_id)?;
    }
    for record in cold_miss_history {
        require_unit(&unit_ids, &record.unit_id)?;
    }
    Ok(())
}

fn require_unit(
    unit_ids: &HashSet<&str>,
    unit_id: &str,
) -> Result<(), ResidencyConstructionGraphError> {
    if unit_ids.contains(unit_id) {
        Ok(())
    } else {
        Err(ResidencyConstructionGraphError::UnknownUnitReference {
            unit_id: unit_id.to_string(),
        })
    }
}

fn compute_assembly_score(
    units: &[ResidencyConstructionUnit],
    coactivation_edges: &[CoactivationEdge],
    incompatibility_edges: &[IncompatibilityEdge],
    verifier_edges: &[VerifierEdge],
    cold_miss_history: &[ColdMissRecord],
    budget: &ResidencyConstructionBudget,
) -> Result<AssemblyScore, ResidencyConstructionGraphError> {
    let verifier_bonus_by_unit =
        verifier_edges
            .iter()
            .fold(BTreeMap::<&str, u32>::new(), |mut by_unit, edge| {
                *by_unit.entry(edge.unit_id.as_str()).or_default() +=
                    u32::from(edge.verifier_score_bps);
                by_unit
            });
    let cold_history_by_unit = cold_miss_history.iter().fold(
        BTreeMap::<&str, (u64, u64)>::new(),
        |mut by_unit, record| {
            let entry = by_unit.entry(record.unit_id.as_str()).or_default();
            entry.0 += record.miss_count;
            entry.1 += record.stall_ms;
            by_unit
        },
    );
    let affinity_by_pair = coactivation_edges.iter().fold(
        BTreeMap::<(&str, &str), u32>::new(),
        |mut by_pair, edge| {
            by_pair.insert(
                (edge.from_unit_id.as_str(), edge.to_unit_id.as_str()),
                u32::from(edge.affinity_bps),
            );
            by_pair
        },
    );
    let incompatible_pairs = incompatibility_edges
        .iter()
        .map(|edge| (edge.left_unit_id.as_str(), edge.right_unit_id.as_str()))
        .collect::<BTreeSet<_>>();
    let mut ranked = units
        .iter()
        .map(|unit| {
            let verifier_bonus = verifier_bonus_by_unit
                .get(unit.unit_id.as_str())
                .copied()
                .unwrap_or_default();
            let (misses, stall_ms) = cold_history_by_unit
                .get(unit.unit_id.as_str())
                .copied()
                .unwrap_or_default();
            let cold_penalty = (misses * 50 + stall_ms / 10).min(10_000) as u32;
            let score = unit
                .raw_score_bps()
                .saturating_add(verifier_bonus)
                .saturating_sub(cold_penalty);
            (unit, score)
        })
        .collect::<Vec<_>>();
    ranked.sort_by(|(left_unit, left_score), (right_unit, right_score)| {
        right_score
            .cmp(left_score)
            .then_with(|| left_unit.unit_id.cmp(&right_unit.unit_id))
    });

    let mut selected = Vec::<&ResidencyConstructionUnit>::with_capacity(units.len());
    let mut rejected_unit_ids = Vec::new();
    let mut hot = 0_u64;
    let mut warm = 0_u64;
    let mut cold = 0_u64;
    let mut misses = 0_u64;
    let mut stall = 0_u64;

    for (unit, _) in ranked {
        if unit.hot_bytes > budget.hot_uma_bytes
            || unit.warm_bytes > budget.warm_uma_bytes
            || unit.cold_bytes > budget.cold_ssd_bytes
        {
            rejected_unit_ids.push(unit.unit_id.clone());
            continue;
        }
        let next_hot = hot.saturating_add(unit.hot_bytes);
        let next_warm = warm.saturating_add(unit.warm_bytes);
        let next_cold = cold.saturating_add(unit.cold_bytes);
        let (unit_misses, unit_stall) = cold_history_by_unit
            .get(unit.unit_id.as_str())
            .copied()
            .unwrap_or_default();
        let next_misses = misses.saturating_add(unit_misses);
        let next_stall = stall.saturating_add(unit_stall);
        if next_hot > budget.hot_uma_bytes
            || next_warm > budget.warm_uma_bytes
            || next_cold > budget.cold_ssd_bytes
            || next_misses > budget.max_cold_misses
            || next_stall > budget.max_cold_stall_ms
            || conflicts(unit.unit_id.as_str(), &selected, &incompatible_pairs)
        {
            rejected_unit_ids.push(unit.unit_id.clone());
            continue;
        }
        selected.push(unit);
        hot = next_hot;
        warm = next_warm;
        cold = next_cold;
        misses = next_misses;
        stall = next_stall;
    }

    if selected.is_empty() {
        return Err(ResidencyConstructionGraphError::NoValidAssembly);
    }

    let selected_unit_ids = selected
        .iter()
        .map(|unit| unit.unit_id.clone())
        .collect::<Vec<_>>();
    let selected_id_set = selected_unit_ids
        .iter()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    let mut affinity_bonus = 0_u32;
    for left in &selected_id_set {
        for right in &selected_id_set {
            if left >= right {
                continue;
            }
            affinity_bonus += affinity_by_pair
                .get(&(*left, *right))
                .copied()
                .unwrap_or_default();
        }
    }
    let count = selected.len() as u32;
    let quality = selected
        .iter()
        .map(|unit| u32::from(unit.quality_bps))
        .sum::<u32>()
        / count;
    let evidence = selected
        .iter()
        .map(|unit| u32::from(unit.evidence_validity_bps))
        .sum::<u32>()
        / count;
    let verifier = selected
        .iter()
        .map(|unit| u32::from(unit.verifier_bps))
        .sum::<u32>()
        / count;
    let score =
        ((quality + evidence + verifier + affinity_bonus) / 3).min(u32::from(MAX_SCORE_BPS));
    rejected_unit_ids.sort();
    rejected_unit_ids.dedup();

    Ok(AssemblyScore {
        selected_unit_ids,
        rejected_unit_ids,
        hot_resident_bytes: hot,
        warm_bytes: warm,
        cold_bytes: cold,
        cold_miss_count: misses,
        cold_stall_ms: stall,
        quality_bps: quality as u16,
        evidence_validity_bps: evidence as u16,
        verifier_bps: verifier as u16,
        score_bps: score as u16,
    })
}

fn conflicts(
    unit_id: &str,
    selected: &[&ResidencyConstructionUnit],
    incompatible_pairs: &BTreeSet<(&str, &str)>,
) -> bool {
    selected.iter().any(|selected_unit| {
        let selected_id = selected_unit.unit_id.as_str();
        if unit_id < selected_id {
            incompatible_pairs.contains(&(unit_id, selected_id))
        } else {
            incompatible_pairs.contains(&(selected_id, unit_id))
        }
    })
}

#[allow(clippy::too_many_arguments)]
fn graph_address(
    task_signature: &str,
    units: &[ResidencyConstructionUnit],
    coactivation_edges: &[CoactivationEdge],
    incompatibility_edges: &[IncompatibilityEdge],
    verifier_edges: &[VerifierEdge],
    cold_miss_history: &[ColdMissRecord],
    budget: &ResidencyConstructionBudget,
    score: &AssemblyScore,
    created_at_ms: u64,
) -> UasAddress {
    let mut preimage = String::new();
    preimage.push_str("residency_construction_graph_v1\n");
    preimage.push_str(task_signature);
    preimage.push('\n');
    for unit in units {
        preimage.push_str(&format!(
            "unit:{}:{}:{}:{}:{}:{}:{}:{}:{}\n",
            unit.unit_id,
            unit.source_card_id,
            unit.hot_bytes,
            unit.warm_bytes,
            unit.cold_bytes,
            unit.quality_bps,
            unit.evidence_validity_bps,
            unit.verifier_bps,
            unit.rollback_ref
        ));
    }
    for edge in coactivation_edges {
        preimage.push_str(&format!(
            "co:{}:{}:{}\n",
            edge.from_unit_id, edge.to_unit_id, edge.affinity_bps
        ));
    }
    for edge in incompatibility_edges {
        preimage.push_str(&format!(
            "in:{}:{}:{}\n",
            edge.left_unit_id, edge.right_unit_id, edge.reason
        ));
    }
    for edge in verifier_edges {
        preimage.push_str(&format!(
            "ve:{}:{}:{}\n",
            edge.unit_id, edge.verifier_id, edge.verifier_score_bps
        ));
    }
    for record in cold_miss_history {
        preimage.push_str(&format!(
            "cm:{}:{}:{}\n",
            record.unit_id, record.miss_count, record.stall_ms
        ));
    }
    preimage.push_str(&format!(
        "budget:{}:{}:{}:{}:{}\n",
        budget.hot_uma_bytes,
        budget.warm_uma_bytes,
        budget.cold_ssd_bytes,
        budget.max_cold_misses,
        budget.max_cold_stall_ms
    ));
    preimage.push_str(&format!(
        "score:{}:{}:{}:{}:{}:{}:{}:{}:{}\n",
        score.selected_unit_ids.join(","),
        score.rejected_unit_ids.join(","),
        score.hot_resident_bytes,
        score.warm_bytes,
        score.cold_bytes,
        score.cold_miss_count,
        score.cold_stall_ms,
        score.quality_bps,
        score.score_bps
    ));
    UasAddress::new(
        UasKind::Other(GRAPH_UAS_KIND.to_string()),
        preimage.as_bytes(),
        created_at_ms,
    )
}

fn validate_nonempty(
    field: &'static str,
    value: &str,
) -> Result<(), ResidencyConstructionGraphError> {
    if value.trim().is_empty() {
        return match field {
            "task_signature" => Err(ResidencyConstructionGraphError::MissingTaskSignature),
            "rollback_ref" => Err(ResidencyConstructionGraphError::MissingRollback {
                unit_id: "unknown".to_string(),
            }),
            _ => Err(ResidencyConstructionGraphError::FieldContainsControlCharacter { field }),
        };
    }
    if value.trim() != value {
        return Err(ResidencyConstructionGraphError::FieldHasSurroundingWhitespace { field });
    }
    if value.chars().any(char::is_control) {
        return Err(ResidencyConstructionGraphError::FieldContainsControlCharacter { field });
    }
    Ok(())
}

fn validate_score(field: &'static str, value: u16) -> Result<(), ResidencyConstructionGraphError> {
    if value > MAX_SCORE_BPS {
        Err(ResidencyConstructionGraphError::ScoreOutOfRange { field })
    } else {
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_000_000_000;

    fn unit(id: &str, hot: u64, warm: u64, cold: u64, quality: u16) -> ResidencyConstructionUnit {
        ResidencyConstructionUnit::new(
            id,
            format!("source:{id}"),
            hot,
            warm,
            cold,
            quality,
            8_000,
            8_000,
            format!("rollback:{id}"),
            CREATED_AT_MS,
        )
        .unwrap()
    }

    fn graph() -> ResidencyConstructionGraph {
        ResidencyConstructionGraph::score(
            "task:adversarial-note-research",
            vec![
                unit("verifier_lane", 32, 0, 0, 8_200),
                unit("giant_dense_body", 1024, 0, 0, 9_900),
                unit("evidence_core", 64, 0, 128, 8_600),
            ],
            vec![CoactivationEdge::new("evidence_core", "verifier_lane", 900).unwrap()],
            vec![IncompatibilityEdge::new(
                "giant_dense_body",
                "evidence_core",
                "dense body violates active-byte budget",
            )
            .unwrap()],
            vec![
                VerifierEdge::new("evidence_core", "verifier:eidos", 900).unwrap(),
                VerifierEdge::new("verifier_lane", "verifier:lean-schema", 600).unwrap(),
            ],
            vec![
                ColdMissRecord::new("evidence_core", 1, 12).unwrap(),
                ColdMissRecord::new("verifier_lane", 0, 0).unwrap(),
            ],
            ResidencyConstructionBudget {
                hot_uma_bytes: 128,
                warm_uma_bytes: 0,
                cold_ssd_bytes: 256,
                max_cold_misses: 2,
                max_cold_stall_ms: 25,
            },
            CREATED_AT_MS,
        )
        .unwrap()
    }

    #[test]
    fn construction_graph_scores_deterministically_and_rejects_invalid_units() {
        let graph = graph();
        let reversed = ResidencyConstructionGraph::score(
            "task:adversarial-note-research",
            graph.candidate_units.iter().cloned().rev().collect(),
            graph.coactivation_edges.iter().cloned().rev().collect(),
            graph.incompatibility_edges.iter().cloned().rev().collect(),
            graph.verifier_edges.iter().cloned().rev().collect(),
            graph.cold_miss_history.iter().cloned().rev().collect(),
            graph.budget.clone(),
            CREATED_AT_MS,
        )
        .unwrap();

        assert_eq!(graph.graph_address, reversed.graph_address);
        assert_eq!(
            graph.assembly_score.selected_unit_ids,
            vec!["evidence_core", "verifier_lane"]
        );
        assert_eq!(
            graph.assembly_score.rejected_unit_ids,
            vec!["giant_dense_body"]
        );
        assert_eq!(graph.assembly_score.hot_resident_bytes, 96);
        assert_eq!(graph.assembly_score.cold_miss_count, 1);
        assert!(graph.assembly_score.score_bps >= 8_000);
    }

    #[test]
    fn construction_graph_rejects_unknown_edge_references() {
        let err = ResidencyConstructionGraph::score(
            "task:bad-edge",
            vec![unit("evidence_core", 64, 0, 0, 8_000)],
            vec![CoactivationEdge::new("evidence_core", "missing", 100).unwrap()],
            vec![],
            vec![],
            vec![],
            ResidencyConstructionBudget::m2_pro_dry_run(),
            CREATED_AT_MS,
        )
        .unwrap_err();

        assert_eq!(
            err,
            ResidencyConstructionGraphError::UnknownUnitReference {
                unit_id: "missing".to_string()
            }
        );
    }

    #[test]
    fn construction_graph_requires_rollback_and_bytes() {
        let missing_rollback = ResidencyConstructionUnit::new(
            "unit",
            "source:unit",
            1,
            0,
            0,
            8_000,
            8_000,
            8_000,
            "",
            CREATED_AT_MS,
        )
        .unwrap_err();
        let empty_bytes = ResidencyConstructionUnit::new(
            "unit",
            "source:unit",
            0,
            0,
            0,
            8_000,
            8_000,
            8_000,
            "rollback:unit",
            CREATED_AT_MS,
        )
        .unwrap_err();

        assert!(matches!(
            missing_rollback,
            ResidencyConstructionGraphError::MissingRollback { .. }
        ));
        assert_eq!(
            empty_bytes,
            ResidencyConstructionGraphError::EmptyUnitBytes {
                unit_id: "unit".to_string()
            }
        );
    }

    #[test]
    fn construction_graph_rejects_when_every_candidate_exceeds_budget() {
        let err = ResidencyConstructionGraph::score(
            "task:no-fit",
            vec![unit("too_large", 256, 0, 0, 8_000)],
            vec![],
            vec![],
            vec![],
            vec![],
            ResidencyConstructionBudget {
                hot_uma_bytes: 1,
                warm_uma_bytes: 0,
                cold_ssd_bytes: 0,
                max_cold_misses: 0,
                max_cold_stall_ms: 0,
            },
            CREATED_AT_MS,
        )
        .unwrap_err();

        assert_eq!(err, ResidencyConstructionGraphError::NoValidAssembly);
    }
}
