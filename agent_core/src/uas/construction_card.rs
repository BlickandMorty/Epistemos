//! Construction cards for Research Construction Engine dry-runs.
//!
//! A card records the Erdos / Parameter Golf invariant in executable schema
//! form: problem -> lift chart -> projection -> witness -> budget ->
//! falsifier -> rollback. It is intentionally metadata-only.

use serde::{Deserialize, Serialize};

use crate::uas::{
    weight_block::{is_valid_wbo_budget_nats, weight_block_ir_chart_preimage},
    ResidencyPlan, ResidencyPlanStatus, UasAddress, UasKind, WeightBlockIrChart,
};

const RANGE_HASH_FALSIFIER_ID: &str = "F-WeightBlockRangeHash-DryRun";
const RESIDENCY_PLAN_FALSIFIER_ID: &str = "F-ResidencyPlan-DryRun";

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ConstructionTier {
    Mas,
    Pro,
    Vault,
    ResearchConstruction,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ConstructionBudget {
    pub hot_uma_bytes: u64,
    pub warm_compressed_uma_bytes: u64,
    pub cold_mmap_ssd_bytes: u64,
    pub wbo_budget_nats: f32,
    pub copy_budget: u64,
}

impl ConstructionBudget {
    pub fn from_residency_plan(plan: &ResidencyPlan, copy_budget: u64) -> Self {
        Self {
            hot_uma_bytes: plan.totals.hot_uma_bytes,
            warm_compressed_uma_bytes: plan.totals.warm_compressed_uma_bytes,
            cold_mmap_ssd_bytes: plan.totals.cold_mmap_ssd_bytes,
            wbo_budget_nats: plan.totals.wbo_budget_nats,
            copy_budget,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ConstructionCard {
    pub card_address: UasAddress,
    pub problem_card: String,
    pub lift_charts: Vec<WeightBlockIrChart>,
    pub projection_packet: String,
    pub witness: String,
    pub budget: ConstructionBudget,
    pub falsifier_id: String,
    #[serde(default)]
    pub upstream_falsifier_ids: Vec<String>,
    pub rollback_reference: String,
    pub tier: ConstructionTier,
    pub residency_plan_address: Option<UasAddress>,
}

impl ConstructionCard {
    #[allow(clippy::too_many_arguments)]
    pub fn from_residency_plan(
        problem_card: impl Into<String>,
        projection_packet: impl Into<String>,
        witness: impl Into<String>,
        falsifier_id: impl Into<String>,
        rollback_reference: impl Into<String>,
        tier: ConstructionTier,
        plan: &ResidencyPlan,
        copy_budget: u64,
        created_at_ms: u64,
    ) -> Result<Self, ConstructionCardError> {
        if plan.status != ResidencyPlanStatus::FitForDryRun {
            return Err(ConstructionCardError::PlanRejected);
        }
        let lift_charts = unique_lift_charts(plan);
        let budget = ConstructionBudget::from_residency_plan(plan, copy_budget);
        Self::new_with_upstreams(
            problem_card,
            lift_charts,
            projection_packet,
            witness,
            budget,
            falsifier_id,
            vec![
                RANGE_HASH_FALSIFIER_ID.to_string(),
                RESIDENCY_PLAN_FALSIFIER_ID.to_string(),
            ],
            rollback_reference,
            tier,
            Some(plan.plan_address.clone()),
            created_at_ms,
        )
    }

    #[allow(clippy::too_many_arguments)]
    pub fn new(
        problem_card: impl Into<String>,
        lift_charts: Vec<WeightBlockIrChart>,
        projection_packet: impl Into<String>,
        witness: impl Into<String>,
        budget: ConstructionBudget,
        falsifier_id: impl Into<String>,
        rollback_reference: impl Into<String>,
        tier: ConstructionTier,
        residency_plan_address: Option<UasAddress>,
        created_at_ms: u64,
    ) -> Result<Self, ConstructionCardError> {
        Self::new_with_upstreams(
            problem_card,
            lift_charts,
            projection_packet,
            witness,
            budget,
            falsifier_id,
            Vec::new(),
            rollback_reference,
            tier,
            residency_plan_address,
            created_at_ms,
        )
    }

    #[allow(clippy::too_many_arguments)]
    fn new_with_upstreams(
        problem_card: impl Into<String>,
        lift_charts: Vec<WeightBlockIrChart>,
        projection_packet: impl Into<String>,
        witness: impl Into<String>,
        budget: ConstructionBudget,
        falsifier_id: impl Into<String>,
        upstream_falsifier_ids: Vec<String>,
        rollback_reference: impl Into<String>,
        tier: ConstructionTier,
        residency_plan_address: Option<UasAddress>,
        created_at_ms: u64,
    ) -> Result<Self, ConstructionCardError> {
        let problem_card = problem_card.into();
        let projection_packet = projection_packet.into();
        let witness = witness.into();
        let falsifier_id = falsifier_id.into();
        let rollback_reference = rollback_reference.into();
        validate_nonempty("problem_card", &problem_card)?;
        validate_nonempty("projection_packet", &projection_packet)?;
        validate_nonempty("witness", &witness)?;
        validate_nonempty("falsifier_id", &falsifier_id)?;
        validate_nonempty("rollback_reference", &rollback_reference)?;
        if lift_charts.is_empty() {
            return Err(ConstructionCardError::MissingLiftChart);
        }
        if !is_valid_wbo_budget_nats(budget.wbo_budget_nats) {
            return Err(ConstructionCardError::InvalidBudget);
        }
        let card_address = Self::address(
            &problem_card,
            &lift_charts,
            &projection_packet,
            &witness,
            &budget,
            &falsifier_id,
            &upstream_falsifier_ids,
            &rollback_reference,
            &tier,
            residency_plan_address.as_ref(),
            created_at_ms,
        );

        Ok(Self {
            card_address,
            problem_card,
            lift_charts,
            projection_packet,
            witness,
            budget,
            falsifier_id,
            upstream_falsifier_ids,
            rollback_reference,
            tier,
            residency_plan_address,
        })
    }

    #[allow(clippy::too_many_arguments)]
    fn address(
        problem_card: &str,
        lift_charts: &[WeightBlockIrChart],
        projection_packet: &str,
        witness: &str,
        budget: &ConstructionBudget,
        falsifier_id: &str,
        upstream_falsifier_ids: &[String],
        rollback_reference: &str,
        tier: &ConstructionTier,
        residency_plan_address: Option<&UasAddress>,
        created_at_ms: u64,
    ) -> UasAddress {
        let mut preimage = String::new();
        preimage.push_str("construction_card_v1\n");
        preimage.push_str(problem_card);
        preimage.push('\n');
        for chart in lift_charts {
            preimage.push_str(weight_block_ir_chart_preimage(chart));
            preimage.push('\n');
        }
        preimage.push_str(projection_packet);
        preimage.push('\n');
        preimage.push_str(witness);
        preimage.push('\n');
        preimage.push_str(&format!(
            "{}:{}:{}:{}:{}\n",
            budget.hot_uma_bytes,
            budget.warm_compressed_uma_bytes,
            budget.cold_mmap_ssd_bytes,
            (budget.wbo_budget_nats * 1000.0).round() as u32,
            budget.copy_budget
        ));
        preimage.push_str(falsifier_id);
        preimage.push('\n');
        for upstream in upstream_falsifier_ids {
            preimage.push_str(upstream);
            preimage.push('\n');
        }
        preimage.push_str(rollback_reference);
        preimage.push('\n');
        preimage.push_str(construction_tier_preimage(tier));
        preimage.push('\n');
        if let Some(address) = residency_plan_address {
            preimage.push_str(&address.to_string());
        }
        UasAddress::new(
            UasKind::Other("construction_card".to_string()),
            preimage.as_bytes(),
            created_at_ms,
        )
    }
}

fn construction_tier_preimage(tier: &ConstructionTier) -> &'static str {
    match tier {
        ConstructionTier::Mas => "mas",
        ConstructionTier::Pro => "pro",
        ConstructionTier::Vault => "vault",
        ConstructionTier::ResearchConstruction => "research_construction",
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ConstructionCardError {
    MissingProblemCard,
    MissingLiftChart,
    MissingProjectionPacket,
    MissingWitness,
    MissingFalsifier,
    MissingRollback,
    FieldHasSurroundingWhitespace { field: &'static str },
    FieldContainsControlCharacter { field: &'static str },
    InvalidBudget,
    PlanRejected,
}

impl std::fmt::Display for ConstructionCardError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::MissingProblemCard => write!(f, "problem_card is required"),
            Self::MissingLiftChart => write!(f, "at least one lift chart is required"),
            Self::MissingProjectionPacket => write!(f, "projection_packet is required"),
            Self::MissingWitness => write!(f, "witness is required"),
            Self::MissingFalsifier => write!(f, "falsifier_id is required"),
            Self::MissingRollback => write!(f, "rollback_reference is required"),
            Self::FieldHasSurroundingWhitespace { field } => {
                write!(f, "{field} must not contain leading or trailing whitespace")
            }
            Self::FieldContainsControlCharacter { field } => {
                write!(f, "{field} must not contain control characters")
            }
            Self::InvalidBudget => write!(f, "construction budget is invalid"),
            Self::PlanRejected => write!(f, "residency plan must be FitForDryRun"),
        }
    }
}

impl std::error::Error for ConstructionCardError {}

fn validate_nonempty(field: &'static str, value: &str) -> Result<(), ConstructionCardError> {
    if value.trim().is_empty() {
        return Err(missing_field_error(field));
    }
    if value.trim() != value {
        return Err(ConstructionCardError::FieldHasSurroundingWhitespace { field });
    }
    if value.chars().any(char::is_control) {
        return Err(ConstructionCardError::FieldContainsControlCharacter { field });
    }
    Ok(())
}

fn missing_field_error(field: &'static str) -> ConstructionCardError {
    match field {
        "problem_card" => ConstructionCardError::MissingProblemCard,
        "projection_packet" => ConstructionCardError::MissingProjectionPacket,
        "witness" => ConstructionCardError::MissingWitness,
        "falsifier_id" => ConstructionCardError::MissingFalsifier,
        "rollback_reference" => ConstructionCardError::MissingRollback,
        _ => ConstructionCardError::InvalidBudget,
    }
}

fn unique_lift_charts(plan: &ResidencyPlan) -> Vec<WeightBlockIrChart> {
    let mut charts = Vec::new();
    for block in &plan.blocks {
        if !charts.contains(&block.ir_chart) {
            charts.push(block.ir_chart.clone());
        }
    }
    charts
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::weight_block::MAX_WBO_BUDGET_NATS;
    use crate::uas::{
        ResidencyBudget, WeightBlockEncoding, WeightBlockIrChart, WeightBlockManifest,
        WeightBlockResidencyClass,
    };

    fn rollback_reference() -> UasAddress {
        UasAddress::new(UasKind::ModelComponent, b"dense-reference", 7)
    }

    fn fit_plan() -> ResidencyPlan {
        let hot = WeightBlockManifest::from_bytes(
            "local/70b",
            "file:///models/70b/hot.safetensors",
            0,
            b"hot",
            1,
            WeightBlockEncoding::DenseBf16,
            WeightBlockResidencyClass::HotUma,
            WeightBlockIrChart::Scan,
            0.0,
            "bit_exact",
            None,
        )
        .unwrap();
        let cold = WeightBlockManifest::from_bytes(
            "local/70b",
            "file:///models/70b/cold.safetensors",
            128,
            b"cold",
            1,
            WeightBlockEncoding::Nf4,
            WeightBlockResidencyClass::ColdMmapSsd,
            WeightBlockIrChart::OpaqueWithWitness,
            0.01,
            "dense_reference",
            Some(rollback_reference()),
        )
        .unwrap();
        ResidencyPlan::evaluate(
            [hot, cold],
            ResidencyBudget::new(64, 64, 64, 0.10, 8).unwrap(),
            9,
        )
    }

    #[test]
    fn construction_card_binds_passed_residency_plan() {
        let plan = fit_plan();
        let card = ConstructionCard::from_residency_plan(
            "fit 70b-shaped active set without runtime load",
            "active_assembly_packet",
            "F-ResidencyPlan-DryRun/result.json",
            "F-ResidencyPlan-DryRun",
            "dense_reference_path",
            ConstructionTier::ResearchConstruction,
            &plan,
            0,
            10,
        )
        .unwrap();

        assert_eq!(card.residency_plan_address, Some(plan.plan_address));
        assert_eq!(
            card.upstream_falsifier_ids,
            vec![
                "F-WeightBlockRangeHash-DryRun".to_string(),
                "F-ResidencyPlan-DryRun".to_string()
            ]
        );
        assert_eq!(card.budget.cold_mmap_ssd_bytes, 4);
        assert_eq!(
            card.lift_charts,
            vec![
                WeightBlockIrChart::OpaqueWithWitness,
                WeightBlockIrChart::Scan
            ]
        );
        assert_eq!(
            card.card_address.kind,
            UasKind::Other("construction_card".to_string())
        );
    }

    #[test]
    fn construction_card_refuses_rejected_plan() {
        let rejected = ResidencyPlan::evaluate(
            Vec::<WeightBlockManifest>::new(),
            ResidencyBudget::new(64, 64, 64, 0.10, 8).unwrap(),
            9,
        );
        let err = ConstructionCard::from_residency_plan(
            "empty",
            "projection",
            "witness",
            "F-Test",
            "rollback",
            ConstructionTier::ResearchConstruction,
            &rejected,
            0,
            10,
        )
        .unwrap_err();

        assert_eq!(err, ConstructionCardError::PlanRejected);
    }

    #[test]
    fn construction_card_requires_all_doctrine_fields() {
        let err = ConstructionCard::new(
            "",
            vec![WeightBlockIrChart::Scan],
            "projection",
            "witness",
            ConstructionBudget {
                hot_uma_bytes: 0,
                warm_compressed_uma_bytes: 0,
                cold_mmap_ssd_bytes: 0,
                wbo_budget_nats: 0.0,
                copy_budget: 0,
            },
            "F-Test",
            "rollback",
            ConstructionTier::ResearchConstruction,
            None,
            10,
        )
        .unwrap_err();

        assert_eq!(err, ConstructionCardError::MissingProblemCard);
    }

    #[test]
    fn construction_card_rejects_noncanonical_preimage_fields() {
        let budget = ConstructionBudget {
            hot_uma_bytes: 0,
            warm_compressed_uma_bytes: 0,
            cold_mmap_ssd_bytes: 0,
            wbo_budget_nats: 0.0,
            copy_budget: 0,
        };

        let spaced = ConstructionCard::new(
            " problem ",
            vec![WeightBlockIrChart::Scan],
            "projection",
            "witness",
            budget.clone(),
            "F-Test",
            "rollback",
            ConstructionTier::ResearchConstruction,
            None,
            10,
        )
        .unwrap_err();
        let controlled = ConstructionCard::new(
            "problem",
            vec![WeightBlockIrChart::Scan],
            "projection\npacket",
            "witness",
            budget,
            "F-Test",
            "rollback",
            ConstructionTier::ResearchConstruction,
            None,
            10,
        )
        .unwrap_err();

        assert_eq!(
            spaced,
            ConstructionCardError::FieldHasSurroundingWhitespace {
                field: "problem_card"
            }
        );
        assert_eq!(
            controlled,
            ConstructionCardError::FieldContainsControlCharacter {
                field: "projection_packet"
            }
        );
    }

    #[test]
    fn construction_card_rejects_wbo_budget_above_residency_ceiling() {
        let err = ConstructionCard::new(
            "problem",
            vec![WeightBlockIrChart::Scan],
            "projection",
            "witness",
            ConstructionBudget {
                hot_uma_bytes: 0,
                warm_compressed_uma_bytes: 0,
                cold_mmap_ssd_bytes: 0,
                wbo_budget_nats: MAX_WBO_BUDGET_NATS + 1.0,
                copy_budget: 0,
            },
            "F-Test",
            "rollback",
            ConstructionTier::ResearchConstruction,
            None,
            10,
        )
        .unwrap_err();

        assert_eq!(err, ConstructionCardError::InvalidBudget);
    }

    #[test]
    fn construction_card_address_uses_stable_wire_labels() {
        let budget = ConstructionBudget {
            hot_uma_bytes: 1,
            warm_compressed_uma_bytes: 2,
            cold_mmap_ssd_bytes: 3,
            wbo_budget_nats: 0.01,
            copy_budget: 4,
        };

        let card = ConstructionCard::new(
            "problem",
            vec![WeightBlockIrChart::OpaqueWithWitness],
            "projection",
            "witness",
            budget,
            "F-Test",
            "rollback",
            ConstructionTier::ResearchConstruction,
            None,
            10,
        )
        .unwrap();
        let expected_preimage = concat!(
            "construction_card_v1\n",
            "problem\n",
            "opaque_with_witness\n",
            "projection\n",
            "witness\n",
            "1:2:3:10:4\n",
            "F-Test\n",
            "rollback\n",
            "research_construction\n"
        );
        let expected = UasAddress::new(
            UasKind::Other("construction_card".to_string()),
            expected_preimage.as_bytes(),
            10,
        );

        assert_eq!(card.card_address, expected);
    }
}
